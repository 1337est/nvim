//! Network status sampling. Reads sysfs and procfs via libc syscalls.
//! No std.fs / std.time dependencies; immune to Zig std drift.

const std = @import("std");

// =============================================================================
// libc bindings (private to this file)
// =============================================================================

const O_RDONLY: c_int = 0;
const F_OK: c_int = 0;
const CLOCK_MONOTONIC: c_int = 1;

const timespec = extern struct { tv_sec: c_long, tv_nsec: c_long };

extern "c" fn open(path: [*:0]const u8, flags: c_int) c_int;
extern "c" fn close(fd: c_int) c_int;
extern "c" fn read(fd: c_int, buf: [*]u8, count: usize) isize;
extern "c" fn access(path: [*:0]const u8, mode: c_int) c_int;
extern "c" fn clock_gettime(clk_id: c_int, ts: *timespec) c_int;

/// Build a null-terminated path string in `buf`. Returns null if it doesn't fit.
fn makePathZ(buf: []u8, comptime fmt: []const u8, args: anytype) ?[*:0]const u8 {
    const written = std.fmt.bufPrint(buf, fmt, args) catch return null;
    if (written.len >= buf.len) return null;
    buf[written.len] = 0;
    return @ptrCast(buf.ptr);
}

/// Read up to out_buf.len bytes from path. Returns the populated slice or null.
fn readFileZ(path_z: [*:0]const u8, out_buf: []u8) ?[]u8 {
    const fd = open(path_z, O_RDONLY);
    if (fd < 0) return null;
    defer _ = close(fd);
    const n = read(fd, out_buf.ptr, out_buf.len);
    if (n < 0) return null;
    return out_buf[0..@intCast(n)];
}

fn nanoNow() i128 {
    var ts: timespec = undefined;
    _ = clock_gettime(CLOCK_MONOTONIC, &ts);
    return @as(i128, ts.tv_sec) * 1_000_000_000 + @as(i128, ts.tv_nsec);
}

// =============================================================================
// Public types
// =============================================================================

pub const Sample = struct {
    rx_bytes: u64 = 0,
    tx_bytes: u64 = 0,
    timestamp_ns: i128 = 0,
    iface: [32]u8 = @splat(0),
    iface_len: usize = 0,
};

pub const Snapshot = struct {
    online: bool = false,
    iface_buf: [32]u8 = @splat(0),
    iface_len: usize = 0,
    operstate_buf: [16]u8 = @splat(0),
    operstate_len: usize = 0,
    is_wireless: bool = false,
    signal_pct: u8 = 0,
    down_bps: u64 = 0,
    up_bps: u64 = 0,

    pub fn iface(self: *const Snapshot) []const u8 {
        return self.iface_buf[0..self.iface_len];
    }
    pub fn operstate(self: *const Snapshot) []const u8 {
        return self.operstate_buf[0..self.operstate_len];
    }
};

// =============================================================================
// Sysfs / procfs readers
// =============================================================================

/// Find the interface holding the default route. Returns null if offline.
fn findDefaultIface(out_buf: []u8) ?[]const u8 {
    var read_buf: [4096]u8 = undefined;
    const content = readFileZ("/proc/net/route", &read_buf) orelse return null;

    // Format:
    //   Iface  Destination  Gateway  Flags  RefCnt  Use  Metric  Mask  ...
    //   eth0   00000000     ...
    var lines = std.mem.splitScalar(u8, content, '\n');
    _ = lines.next(); // header
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var fields = std.mem.tokenizeScalar(u8, line, '\t');
        const iface = fields.next() orelse continue;
        const dest = fields.next() orelse continue;
        if (!std.mem.eql(u8, dest, "00000000")) continue;

        if (iface.len > out_buf.len) return null;
        @memcpy(out_buf[0..iface.len], iface);
        return out_buf[0..iface.len];
    }
    return null;
}

fn readOperstate(iface: []const u8, out_buf: []u8) []const u8 {
    var path_buf: [128]u8 = undefined;
    const path_z = makePathZ(&path_buf, "/sys/class/net/{s}/operstate", .{iface}) orelse
        return "unknown";
    const content = readFileZ(path_z, out_buf) orelse return "unknown";
    return std.mem.trim(u8, content, " \n\r\t");
}

fn isWireless(iface: []const u8) bool {
    var path_buf: [128]u8 = undefined;
    const path_z = makePathZ(&path_buf, "/sys/class/net/{s}/wireless", .{iface}) orelse
        return false;
    return access(path_z, F_OK) == 0;
}

/// Read signal level from /proc/net/wireless and convert to percentage.
fn readWifiSignalPct(iface: []const u8) u8 {
    var read_buf: [4096]u8 = undefined;
    const content = readFileZ("/proc/net/wireless", &read_buf) orelse return 0;

    var lines = std.mem.splitScalar(u8, content, '\n');
    _ = lines.next(); // header 1
    _ = lines.next(); // header 2
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        const colon_idx = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const name = std.mem.trim(u8, line[0..colon_idx], " ");
        if (!std.mem.eql(u8, name, iface)) continue;

        var fields = std.mem.tokenizeAny(u8, line[colon_idx + 1 ..], " \t");
        _ = fields.next(); // status
        _ = fields.next(); // link quality
        const level_str = fields.next() orelse return 0;
        const trimmed = std.mem.trimEnd(u8, level_str, ".");
        const dbm = std.fmt.parseInt(i32, trimmed, 10) catch return 0;

        const raw: i32 = 2 * (dbm + 100);
        if (raw <= 0) return 0;
        if (raw >= 100) return 100;
        return @intCast(raw);
    }
    return 0;
}

fn readByteCounters(iface: []const u8) ?struct { rx: u64, tx: u64 } {
    var path_buf: [128]u8 = undefined;
    var read_buf: [32]u8 = undefined;

    const rx_path_z = makePathZ(
        &path_buf,
        "/sys/class/net/{s}/statistics/rx_bytes",
        .{iface},
    ) orelse return null;
    const rx_content = readFileZ(rx_path_z, &read_buf) orelse return null;
    const rx_str = std.mem.trim(u8, rx_content, " \n\r\t");
    const rx = std.fmt.parseInt(u64, rx_str, 10) catch return null;

    const tx_path_z = makePathZ(
        &path_buf,
        "/sys/class/net/{s}/statistics/tx_bytes",
        .{iface},
    ) orelse return null;
    const tx_content = readFileZ(tx_path_z, &read_buf) orelse return null;
    const tx_str = std.mem.trim(u8, tx_content, " \n\r\t");
    const tx = std.fmt.parseInt(u64, tx_str, 10) catch return null;

    return .{ .rx = rx, .tx = tx };
}

// =============================================================================
// Public API
// =============================================================================

pub fn sample(prev: *Sample) Snapshot {
    var snap: Snapshot = .{};

    var iface_buf: [32]u8 = undefined;
    const iface_opt = findDefaultIface(&iface_buf);

    if (iface_opt == null) {
        prev.iface_len = 0;
        snap.online = false;
        return snap;
    }
    const iface_slice = iface_opt.?;

    // Copy iface into snap.
    const iface_copy_len = @min(iface_slice.len, snap.iface_buf.len);
    @memcpy(snap.iface_buf[0..iface_copy_len], iface_slice[0..iface_copy_len]);
    snap.iface_len = iface_copy_len;

    var operstate_buf: [16]u8 = undefined;
    const operstate_slice = readOperstate(iface_slice, &operstate_buf);

    // Copy operstate into snap.
    const op_copy_len = @min(operstate_slice.len, snap.operstate_buf.len);
    @memcpy(snap.operstate_buf[0..op_copy_len], operstate_slice[0..op_copy_len]);
    snap.operstate_len = op_copy_len;

    snap.online = true;
    snap.is_wireless = isWireless(iface_slice);
    snap.signal_pct = if (snap.is_wireless) readWifiSignalPct(iface_slice) else 0;

    const counters = readByteCounters(iface_slice) orelse return snap;

    const now_ns: i128 = nanoNow();

    const same_iface = prev.iface_len == iface_slice.len and
        std.mem.eql(u8, prev.iface[0..prev.iface_len], iface_slice);

    if (same_iface and prev.timestamp_ns > 0) {
        const dt_ns: i128 = now_ns - prev.timestamp_ns;
        if (dt_ns > 0) {
            if (counters.rx >= prev.rx_bytes) {
                const delta = counters.rx - prev.rx_bytes;
                snap.down_bps = @intCast(@divTrunc(@as(i128, @intCast(delta)) * 1_000_000_000, dt_ns));
            }
            if (counters.tx >= prev.tx_bytes) {
                const delta = counters.tx - prev.tx_bytes;
                snap.up_bps = @intCast(@divTrunc(@as(i128, @intCast(delta)) * 1_000_000_000, dt_ns));
            }
        }
    }

    prev.rx_bytes = counters.rx;
    prev.tx_bytes = counters.tx;
    prev.timestamp_ns = now_ns;
    prev.iface_len = iface_slice.len;
    @memcpy(prev.iface[0..iface_slice.len], iface_slice);

    return snap;
}

/// Format bytes-per-second padded to exactly 8 characters wide.
/// Examples: "  12.0B/s", " 1.2KB/s", "12.3MB/s", "999MB/s ".
pub fn formatRate(out_buf: []u8, bps: u64) []const u8 {
    var raw_buf: [16]u8 = undefined;
    const raw = if (bps >= 1024 * 1024) blk: {
        const mb = @as(f64, @floatFromInt(bps)) / (1024.0 * 1024.0);
        break :blk std.fmt.bufPrint(&raw_buf, "{d:.1}MB/s", .{mb}) catch return "?       ";
    } else if (bps >= 1024) blk: {
        const kb = @as(f64, @floatFromInt(bps)) / 1024.0;
        break :blk std.fmt.bufPrint(&raw_buf, "{d:.1}KB/s", .{kb}) catch return "?       ";
    } else blk: {
        break :blk std.fmt.bufPrint(&raw_buf, "{d}B/s", .{bps}) catch return "?       ";
    };

    // Right-align in an 8-char field by left-padding with spaces.
    const field_width: usize = 8;
    if (raw.len >= field_width) {
        // Truncated rate; just return it as-is to fit in out_buf.
        if (raw.len > out_buf.len) return "?       ";
        @memcpy(out_buf[0..raw.len], raw);
        return out_buf[0..raw.len];
    }
    const pad = field_width - raw.len;
    if (out_buf.len < field_width) return "?       ";
    @memset(out_buf[0..pad], ' ');
    @memcpy(out_buf[pad..field_width], raw);
    return out_buf[0..field_width];
}

pub fn formatSnapshot(out_buf: []u8, snap: Snapshot) []const u8 {
    if (!snap.online) {
        return std.fmt.bufPrint(out_buf, "offline", .{}) catch return "?";
    }

    var dn_buf: [16]u8 = undefined;
    var up_buf: [16]u8 = undefined;
    const dn = formatRate(&dn_buf, snap.down_bps);
    const up = formatRate(&up_buf, snap.up_bps);

    if (snap.is_wireless) {
        return std.fmt.bufPrint(
            out_buf,
            "{s} {s} {d}% | dn {s} up {s}",
            .{ snap.iface(), snap.operstate(), snap.signal_pct, dn, up },
        ) catch return "?";
    } else {
        return std.fmt.bufPrint(
            out_buf,
            "{s} {s} | dn {s} up {s}",
            .{ snap.iface(), snap.operstate(), dn, up },
        ) catch return "?";
    }
}
