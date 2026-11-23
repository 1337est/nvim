const std = @import("std");
const display = @import("display.zig");
const wl = @import("wayland");
const wlr = @import("wlr-layer-shell-unstable-v1");
const font = @import("bar/font.zig");
const net = @import("bar/net.zig");

// ── Protocol aliases ───────────────────────────────────────────────
const Compositor = wl.wl_compositor;
const Surface = wl.wl_surface;
const Shm = wl.wl_shm;
const ShmPool = wl.wl_shm_pool;
const WlBuffer = wl.wl_buffer;
const Output = wl.wl_output;
const LayerShell = wlr.zwlr_layer_shell_v1;
const LayerSurface = wlr.zwlr_layer_surface_v1;

// ── libc / Linux ───────────────────────────────────────────────────
const PROT_READ: c_int = 0x1;
const PROT_WRITE: c_int = 0x2;
const MAP_SHARED: c_int = 0x01;
const MAP_FAILED: ?*anyopaque = @ptrFromInt(std.math.maxInt(usize));

extern "c" fn mmap(?*anyopaque, usize, c_int, c_int, c_int, c_long) ?*anyopaque;
extern "c" fn munmap(?*anyopaque, usize) c_int;
extern "c" fn close(c_int) c_int;

const POLLIN: c_short = 0x0001;
const pollfd = extern struct { fd: c_int, events: c_short, revents: c_short };
extern "c" fn poll(fds: [*]pollfd, nfds: c_ulong, timeout: c_int) c_int;

const CLOCK_REALTIME: c_int = 0;
const TFD_CLOEXEC: c_int = 0o2000000;
const timespec = extern struct { tv_sec: c_long, tv_nsec: c_long };
const itimerspec = extern struct { it_interval: timespec, it_value: timespec };
extern "c" fn timerfd_create(c_int, c_int) c_int;
extern "c" fn timerfd_settime(c_int, c_int, *const itimerspec, ?*itimerspec) c_int;

const time_t = c_long;
const tm = extern struct {
    tm_sec: c_int,
    tm_min: c_int,
    tm_hour: c_int,
    tm_mday: c_int,
    tm_mon: c_int,
    tm_year: c_int,
    tm_wday: c_int,
    tm_yday: c_int,
    tm_isdst: c_int,
    tm_gmtoff: c_long,
    tm_zone: ?[*:0]const u8,
};
extern "c" fn time(?*time_t) time_t;
extern "c" fn localtime_r(*const time_t, *tm) ?*tm;
extern "c" fn read(c_int, [*]u8, usize) isize;

// shm fd: memfd_create + ftruncate + seal (was glue.c's tb_create_shm_fd)
const MFD_CLOEXEC: c_uint = 0x0001;
const MFD_ALLOW_SEALING: c_uint = 0x0002;
const F_ADD_SEALS: c_int = 1033;
const F_SEAL_SHRINK: c_int = 0x0002;
const off_t = c_long;
extern "c" fn memfd_create(name: [*:0]const u8, flags: c_uint) c_int;
extern "c" fn ftruncate(fd: c_int, length: off_t) c_int;
extern "c" fn fcntl(fd: c_int, cmd: c_int, ...) c_int;

fn createShmFd(size: usize) c_int {
    const fd = memfd_create("tinybar-shm", MFD_CLOEXEC | MFD_ALLOW_SEALING);
    if (fd < 0) return -1;
    if (ftruncate(fd, @intCast(size)) < 0) {
        _ = close(fd);
        return -1;
    }
    _ = fcntl(fd, F_ADD_SEALS, F_SEAL_SHRINK);
    return fd;
}

// ── Constants ──────────────────────────────────────────────────────
const BAR_HEIGHT: u32 = 32;
const TARGET_OUTPUT_NAMES = [_][]const u8{ "DP-1", "HDMI-A-1" };
const MAX_BARS = TARGET_OUTPUT_NAMES.len;

const COLOR_ONLINE: u32 = 0x0000FF00;
const COLOR_OFFLINE: u32 = 0x00FF0000;
const COLOR_TEXT: u32 = 0x00000000;

// ── Per-output bar instance ────────────────────────────────────────
const Buffer = struct {
    fd: c_int = -1,
    mapping: ?*anyopaque = null,
    size_bytes: usize = 0,
    pool: u32 = 0,
    wl_buf: u32 = 0,
    busy: bool = false,
};

const BarInstance = struct {
    output: u32 = 0,
    name: [32]u8 = @splat(0),
    name_len: usize = 0,
    mode_width: i32 = 0,
    mode_height: i32 = 0,
    mode_refresh: i32 = 0,

    surface: u32 = 0,
    layer_surface: u32 = 0,
    configured_width: u32 = 0,
    configured_height: u32 = 0,
    has_configured: bool = false,

    buffers: [2]Buffer = .{ Buffer{}, Buffer{} },

    last_fp_buf: [256]u8 = undefined,
    last_fp_len: usize = 0,
    last_fp_valid: bool = false,

    pub fn nameSlice(self: *const BarInstance) []const u8 {
        return self.name[0..self.name_len];
    }
};

// ── Global state ───────────────────────────────────────────────────
const State = struct {
    compositor: u32 = 0,
    shm: u32 = 0,
    layer_shell: u32 = 0,

    discovered_outputs: [16]u32 = @splat(0),
    discovered_count: usize = 0,
    discovered_names: [16][32]u8 = @splat(@splat(0)),
    discovered_name_lens: [16]usize = @splat(0),
    discovered_widths: [16]i32 = @splat(0),
    discovered_heights: [16]i32 = @splat(0),
    discovered_refreshes: [16]i32 = @splat(0),

    bars: [MAX_BARS]BarInstance = .{ BarInstance{}, BarInstance{} },
    bar_active: [MAX_BARS]bool = .{ false, false },
};

var state: State = .{};
var prev_net: net.Sample = .{};

// ── Output events ──────────────────────────────────────────────────
fn onOutput(_: *display.Display, _: u32, data: ?*anyopaque, opcode: u16, payload: []const u8) void {
    const idx: usize = @intFromPtr(data);
    if (idx >= state.discovered_outputs.len) return;
    switch (opcode) {
        Output.event.mode => {
            const flags = display.readU32(payload[0..4]);
            if (flags & Output.mode.current == 0) return;
            state.discovered_widths[idx] = display.readI32(payload[4..8]);
            state.discovered_heights[idx] = display.readI32(payload[8..12]);
            state.discovered_refreshes[idx] = display.readI32(payload[12..16]);
        },
        Output.event.name => {
            const s = display.readString(payload);
            const dst = &state.discovered_names[idx];
            const copy_len = @min(s.str.len, dst.len);
            @memcpy(dst[0..copy_len], s.str[0..copy_len]);
            state.discovered_name_lens[idx] = copy_len;
        },
        else => {}, // geometry, done, scale, description
    }
}

// ── Layer surface events ───────────────────────────────────────────
fn onLayerSurface(d: *display.Display, _: u32, data: ?*anyopaque, opcode: u16, payload: []const u8) void {
    const bar: *BarInstance = @ptrCast(@alignCast(data.?));
    switch (opcode) {
        LayerSurface.event.configure => {
            const serial = display.readU32(payload[0..4]);
            bar.configured_width = display.readU32(payload[4..8]);
            bar.configured_height = display.readU32(payload[8..12]);
            var w = display.MsgWriter{};
            w.putU32(serial);
            d.send(bar.layer_surface, LayerSurface.request.ack_configure, w.data()) catch {};
            bar.has_configured = true;
        },
        LayerSurface.event.closed => {
            std.debug.print("layer surface closed by compositor\n", .{});
            std.process.exit(0);
        },
        else => {},
    }
}

// ── Buffer release ─────────────────────────────────────────────────
fn onBufferRelease(_: *display.Display, _: u32, data: ?*anyopaque, opcode: u16, _: []const u8) void {
    if (opcode != WlBuffer.event.release) return;
    const packed_idx: usize = @intFromPtr(data); // (bar_idx << 1) | buf_idx
    const bar_idx = packed_idx >> 1;
    const buf_idx = packed_idx & 1;
    if (bar_idx >= state.bars.len) return;
    if (buf_idx >= state.bars[bar_idx].buffers.len) return;
    state.bars[bar_idx].buffers[buf_idx].busy = false;
}

// ── Time ───────────────────────────────────────────────────────────
fn formatNow(buf: *[19]u8) []const u8 {
    var t: time_t = undefined;
    _ = time(&t);
    var local: tm = undefined;
    _ = localtime_r(&t, &local);
    const year: u32 = @intCast(@as(i64, local.tm_year) + 1900);
    const month: u32 = @intCast(local.tm_mon + 1);
    const day: u32 = @intCast(local.tm_mday);
    const hour: u32 = @intCast(local.tm_hour);
    const minute: u32 = @intCast(local.tm_min);
    const second: u32 = @intCast(local.tm_sec);
    _ = std.fmt.bufPrint(buf, "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}", .{
        year, month, day, hour, minute, second,
    }) catch unreachable;
    return buf[0..19];
}

// ── Buffer allocation and rendering ────────────────────────────────
fn allocBuffer(d: *display.Display, bar_idx: usize, buf_idx: usize) !void {
    const bar = &state.bars[bar_idx];
    const width = bar.configured_width;
    const height = bar.configured_height;
    const stride: u32 = width * 4;
    const size_bytes: usize = @as(usize, stride) * @as(usize, height);

    const fd = createShmFd(size_bytes);
    if (fd < 0) return error.ShmFdFailed;
    errdefer _ = close(fd);

    const mapping = mmap(null, size_bytes, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    if (mapping == MAP_FAILED or mapping == null) return error.MmapFailed;
    errdefer _ = munmap(mapping, size_bytes);

    // wl_shm.create_pool(id, fd, size) — fd rides in the cmsg; body is id+size.
    const pool_id = d.allocId("wl_shm_pool", null, null);
    errdefer d.freeId(pool_id);
    {
        var w = display.MsgWriter{};
        w.putU32(pool_id);
        w.putI32(@intCast(size_bytes));
        try d.sendWithFd(state.shm, Shm.request.create_pool, w.data(), fd);
    }

    // wl_shm_pool.create_buffer(id, offset, width, height, stride, format)
    const packed_idx: usize = (bar_idx << 1) | buf_idx;
    const buf_id = d.allocId("wl_buffer", onBufferRelease, @ptrFromInt(packed_idx));
    errdefer d.freeId(buf_id);
    {
        var w = display.MsgWriter{};
        w.putU32(buf_id);
        w.putI32(0); // offset
        w.putI32(@intCast(width));
        w.putI32(@intCast(height));
        w.putI32(@intCast(stride));
        w.putU32(Shm.format.xrgb8888);
        try d.send(pool_id, ShmPool.request.create_buffer, w.data());
    }

    bar.buffers[buf_idx] = .{
        .fd = fd,
        .mapping = mapping,
        .size_bytes = size_bytes,
        .pool = pool_id,
        .wl_buf = buf_id,
        .busy = false,
    };
}

fn renderInto(
    bar: *BarInstance,
    buf: *Buffer,
    bg_color: u32,
    clock_str: []const u8,
    title_str: []const u8,
    net_str: []const u8,
) void {
    const width = bar.configured_width;
    const height = bar.configured_height;
    const pixels: [*]u32 = @ptrCast(@alignCast(buf.mapping.?));
    const pixel_count = buf.size_bytes / 4;

    var i: usize = 0;
    while (i < pixel_count) : (i += 1) {
        pixels[i] = bg_color;
    }

    const text_y: i32 = 8;
    font.drawText(pixels, width, width, height, 8, text_y, clock_str, COLOR_TEXT);

    const title_width: i32 = @intCast(title_str.len * font.GLYPH_WIDTH);
    const title_x: i32 = @divTrunc(@as(i32, @intCast(width)), 2) - @divTrunc(title_width, 2);
    font.drawText(pixels, width, width, height, title_x, text_y, title_str, COLOR_TEXT);

    const net_text_width: i32 = @intCast(net_str.len * font.GLYPH_WIDTH);
    const net_x: i32 = @as(i32, @intCast(width)) - net_text_width - 8;
    font.drawText(pixels, width, width, height, net_x, text_y, net_str, COLOR_TEXT);
}

fn drawBar(d: *display.Display, bar_idx: usize, snap: net.Snapshot) !void {
    if (!state.bar_active[bar_idx]) return;
    const bar = &state.bars[bar_idx];
    if (!bar.has_configured) return;

    var clock_buf: [19]u8 = undefined;
    const clock_str = formatNow(&clock_buf);

    var title_buf: [64]u8 = undefined;
    const title_str = std.fmt.bufPrint(
        &title_buf,
        "{s} {d}x{d}@{d}Hz",
        .{ bar.nameSlice(), bar.mode_width, bar.mode_height, @divTrunc(bar.mode_refresh, 1000) },
    ) catch return;

    var net_buf: [128]u8 = undefined;
    const net_str = net.formatSnapshot(&net_buf, snap);

    const bg_color: u32 = if (snap.online) COLOR_ONLINE else COLOR_OFFLINE;

    var fp_buf: [256]u8 = undefined;
    const fp = std.fmt.bufPrint(
        &fp_buf,
        "{x}|{s}|{s}|{s}",
        .{ bg_color, clock_str, title_str, net_str },
    ) catch return;

    if (bar.last_fp_valid and
        bar.last_fp_len == fp.len and
        std.mem.eql(u8, bar.last_fp_buf[0..bar.last_fp_len], fp))
    {
        return;
    }

    var buf_idx_opt: ?usize = null;
    for (bar.buffers, 0..) |b, i| {
        if (!b.busy) {
            buf_idx_opt = i;
            break;
        }
    }
    const buf_idx = buf_idx_opt orelse {
        std.debug.print("warn: bar {d} both buffers busy, skipping\n", .{bar_idx});
        return;
    };

    if (bar.buffers[buf_idx].wl_buf == 0) {
        try allocBuffer(d, bar_idx, buf_idx);
    }

    const buf = &bar.buffers[buf_idx];
    renderInto(bar, buf, bg_color, clock_str, title_str, net_str);

    @memcpy(bar.last_fp_buf[0..fp.len], fp);
    bar.last_fp_len = fp.len;
    bar.last_fp_valid = true;

    buf.busy = true;
    // wl_surface.attach(buffer, 0, 0)
    {
        var w = display.MsgWriter{};
        w.putU32(buf.wl_buf);
        w.putI32(0);
        w.putI32(0);
        try d.send(bar.surface, Surface.request.attach, w.data());
    }
    // wl_surface.damage_buffer(0, 0, width, height)
    {
        var w = display.MsgWriter{};
        w.putI32(0);
        w.putI32(0);
        w.putI32(@intCast(bar.configured_width));
        w.putI32(@intCast(bar.configured_height));
        try d.send(bar.surface, Surface.request.damage_buffer, w.data());
    }
    // wl_surface.commit
    try d.send(bar.surface, Surface.request.commit, &.{});
}

fn drawAll(d: *display.Display) !void {
    const snap = net.sample(&prev_net);
    for (0..state.bars.len) |i| {
        try drawBar(d, i, snap);
    }
}

// ── main ───────────────────────────────────────────────────────────
pub fn main(init: std.process.Init) !void {
    const environ = init.minimal.environ;
    const runtime_dir = environ.getPosix("XDG_RUNTIME_DIR") orelse return error.NoRuntimeDir;
    const wl_display = environ.getPosix("WAYLAND_DISPLAY");

    var client = display.Display.connect(runtime_dir, wl_display) catch {
        std.debug.print("error: failed to connect to wayland display\n", .{});
        return error.NoDisplay;
    };
    defer client.disconnect();

    const registry_id = try client.getRegistry();
    var registry = display.Registry{};
    try client.roundtrip(&registry);

    const comp_g = registry.find("wl_compositor") orelse {
        std.debug.print("error: no wl_compositor\n", .{});
        return error.MissingGlobal;
    };
    state.compositor = try client.bind(registry_id, comp_g.name, "wl_compositor", @min(comp_g.version, 4), null);

    const shm_g = registry.find("wl_shm") orelse {
        std.debug.print("error: no wl_shm\n", .{});
        return error.MissingGlobal;
    };
    state.shm = try client.bind(registry_id, shm_g.name, "wl_shm", 1, null);

    const ls_g = registry.find("zwlr_layer_shell_v1") orelse {
        std.debug.print("error: no zwlr_layer_shell_v1\n", .{});
        return error.MissingGlobal;
    };
    state.layer_shell = try client.bind(registry_id, ls_g.name, "zwlr_layer_shell_v1", @min(ls_g.version, 4), null);

    // Bind every wl_output; onOutput fills the discovered_* arrays.
    for (registry.list()) |g| {
        if (!std.mem.eql(u8, g.interface, "wl_output")) continue;
        if (state.discovered_count >= state.discovered_outputs.len) break;
        const idx = state.discovered_count;
        const oid = try client.bind(registry_id, g.name, "wl_output", @min(g.version, 4), onOutput);
        client.setData(oid, @ptrFromInt(idx));
        state.discovered_outputs[idx] = oid;
        state.discovered_count += 1;
    }

    // Second roundtrip: receive each output's mode/name events.
    try client.roundtrip(&registry);

    for (0..state.discovered_count) |di| {
        std.debug.print("output {d}: '{s}' {d}x{d}\n", .{
            di,                          state.discovered_names[di][0..state.discovered_name_lens[di]],
            state.discovered_widths[di], state.discovered_heights[di],
        });
    }

    // Match discovered outputs to TARGET_OUTPUT_NAMES.
    var any_match = false;
    for (TARGET_OUTPUT_NAMES, 0..) |target, bar_idx| {
        var found: ?usize = null;
        for (0..state.discovered_count) |di| {
            const dn = state.discovered_names[di][0..state.discovered_name_lens[di]];
            if (std.mem.eql(u8, dn, target)) {
                found = di;
                break;
            }
        }
        if (found) |di| {
            const bar = &state.bars[bar_idx];
            bar.output = state.discovered_outputs[di];
            const name_len = state.discovered_name_lens[di];
            @memcpy(bar.name[0..name_len], state.discovered_names[di][0..name_len]);
            bar.name_len = name_len;
            bar.mode_width = state.discovered_widths[di];
            bar.mode_height = state.discovered_heights[di];
            bar.mode_refresh = state.discovered_refreshes[di];
            state.bar_active[bar_idx] = true;
            any_match = true;
            std.debug.print("found {s}: {d}x{d}@{d}Hz\n", .{
                target, bar.mode_width, bar.mode_height, @divTrunc(bar.mode_refresh, 1000),
            });
        } else {
            std.debug.print("warn: target output {s} not present\n", .{target});
        }
    }
    if (!any_match) {
        std.debug.print("error: no target outputs were found\n", .{});
        return error.NoTargetOutputs;
    }

    // Create surface + layer surface for each active bar.
    for (0..state.bars.len) |i| {
        if (!state.bar_active[i]) continue;
        const bar = &state.bars[i];

        bar.surface = client.allocId("wl_surface", null, null);
        {
            var w = display.MsgWriter{};
            w.putU32(bar.surface);
            try client.send(state.compositor, Compositor.request.create_surface, w.data());
        }

        bar.layer_surface = client.allocId("zwlr_layer_surface_v1", onLayerSurface, bar);
        {
            var w = display.MsgWriter{};
            w.putU32(bar.layer_surface);
            w.putU32(bar.surface);
            w.putU32(bar.output);
            w.putU32(LayerShell.layer.top);
            w.putString("tinybar");
            try client.send(state.layer_shell, LayerShell.request.get_layer_surface, w.data());
        }

        {
            var w = display.MsgWriter{};
            w.putU32(0);
            w.putU32(BAR_HEIGHT);
            try client.send(bar.layer_surface, LayerSurface.request.set_size, w.data());
        }
        {
            var w = display.MsgWriter{};
            w.putU32(LayerSurface.anchor.top | LayerSurface.anchor.left | LayerSurface.anchor.right);
            try client.send(bar.layer_surface, LayerSurface.request.set_anchor, w.data());
        }
        {
            var w = display.MsgWriter{};
            w.putI32(@intCast(BAR_HEIGHT));
            try client.send(bar.layer_surface, LayerSurface.request.set_exclusive_zone, w.data());
        }
        try client.send(bar.surface, Surface.request.commit, &.{});
    }

    // Wait for the first configure on each active bar.
    while (true) {
        var all_ready = true;
        for (0..state.bars.len) |i| {
            if (!state.bar_active[i]) continue;
            if (!state.bars[i].has_configured) {
                all_ready = false;
                break;
            }
        }
        if (all_ready) break;
        try client.dispatch();
    }

    try drawAll(&client);

    // 1 Hz timer.
    const tfd = timerfd_create(CLOCK_REALTIME, TFD_CLOEXEC);
    if (tfd < 0) return error.TimerFdFailed;
    defer _ = close(tfd);

    var ts: itimerspec = .{
        .it_interval = .{ .tv_sec = 1, .tv_nsec = 0 },
        .it_value = .{ .tv_sec = 1, .tv_nsec = 0 },
    };
    if (timerfd_settime(tfd, 0, &ts, null) < 0) return error.TimerSetFailed;

    var fds = [_]pollfd{
        .{ .fd = client.fd, .events = POLLIN, .revents = 0 },
        .{ .fd = tfd, .events = POLLIN, .revents = 0 },
    };

    std.debug.print("event loop started\n", .{});

    while (true) {
        fds[0].revents = 0;
        fds[1].revents = 0;
        const n = poll(&fds, fds.len, -1);
        if (n < 0) return error.PollFailed;

        if (fds[0].revents & POLLIN != 0) {
            client.dispatchPending() catch return error.DispatchFailed;
        }
        if (fds[1].revents & POLLIN != 0) {
            var tbuf: [8]u8 = undefined;
            _ = read(tfd, &tbuf, tbuf.len);
            try drawAll(&client);
        }
    }
}
