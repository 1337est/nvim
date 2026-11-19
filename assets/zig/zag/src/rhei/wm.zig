const std = @import("std");
const allocator = std.heap.c_allocator;

const Wm = @import("river-window-management-v1").river_window_manager_v1;
const Win = @import("river-window-management-v1").river_window_v1;
const Node = @import("river-window-management-v1").river_node_v1;
const RSeat = @import("river-window-management-v1").river_seat_v1;
const RPB = @import("river-window-management-v1").river_pointer_binding_v1;

const XkbBindings = @import("river-xkb-bindings-v1").river_xkb_bindings_v1;
const XkbB = @import("river-xkb-bindings-v1").river_xkb_binding_v1;

const display = @import("display.zig");

// xkbcommon keysyms
const XKB_KEY_Escape: u32 = 0xff1b;

// linux/input-event-codes.h
const BTN_LEFT: u32 = 0x110;
const BTN_RIGHT: u32 = 0x111;

// ── Data ───────────────────────────────────────────────────────────
const Action = union(enum) {
    none,
    spawn: Program,
    close,
    focus_next,
    move,
    resize,
    exit_action,
};

const Program = enum {
    terminal,
    browser,
    // add more here: editor, files, …

    fn command(self: Program) [*:0]const u8 {
        return switch (self) {
            .terminal => "/usr/bin/ghostty",
            .browser => "/usr/bin/qutebrowser",
        };
    }
};

const SeatOp = enum { none, move, resize };

const Window = struct {
    obj: u32,
    node: u32,
    is_new: bool = false,
    closed: bool = false,
    x: i32 = 0,
    y: i32 = 0,
    width: i32 = 0,
    height: i32 = 0,
    pointer_move_requested: ?*Seat = null,
    pointer_resize_requested: ?*Seat = null,
    pointer_resize_edges: u32 = 0,
    link: display.ListLink = undefined,
};

const XkbBinding = struct {
    obj: u32,
    seat: *Seat,
    action: Action,
    link: display.ListLink = undefined,
};

const PointerBinding = struct {
    obj: u32,
    seat: *Seat,
    action: Action,
    link: display.ListLink = undefined,
};

const Seat = struct {
    obj: u32,
    is_new: bool = false,
    removed: bool = false,
    focused: ?*Window = null,
    hovered: ?*Window = null,
    interacted: ?*Window = null,
    xkb_bindings: display.ListLink = undefined,
    pointer_bindings: display.ListLink = undefined,
    pending_action: Action = .none,
    op: SeatOp = .none,
    op_window: ?*Window = null,
    op_start_x: i32 = 0,
    op_start_y: i32 = 0,
    op_dx: i32 = 0,
    op_dy: i32 = 0,
    op_release: bool = false,
    op_start_width: i32 = 0,
    op_start_height: i32 = 0,
    op_edges: u32 = 0,
    link: display.ListLink = undefined,
};

const WindowManager = struct {
    windows: display.ListLink = undefined,
    seats: display.ListLink = undefined,
};

var wm_state: WindowManager = .{};

var wm_id: u32 = 0;
var xkb_bindings_id: u32 = 0;
var layer_shell_id: u32 = 0;

fn windowFromLink(link: *display.ListLink) *Window {
    return @fieldParentPtr("link", link);
}
fn seatFromLink(link: *display.ListLink) *Seat {
    return @fieldParentPtr("link", link);
}
fn xkbBindingFromLink(link: *display.ListLink) *XkbBinding {
    return @fieldParentPtr("link", link);
}
fn pointerBindingFromLink(link: *display.ListLink) *PointerBinding {
    return @fieldParentPtr("link", link);
}

// ── Request wrappers ───────────────────────────────────────────────
fn windowGetNode(d: *display.Display, window_id: u32) !u32 {
    const node_id = d.allocId("river_node_v1", null, null);
    var w = display.MsgWriter{};
    w.putU32(node_id);
    try d.send(window_id, Win.request.get_node, w.data());
    return node_id;
}

fn windowProposeDimensions(d: *display.Display, window_id: u32, width: i32, height: i32) !void {
    var w = display.MsgWriter{};
    w.putI32(width);
    w.putI32(height);
    try d.send(window_id, Win.request.propose_dimensions, w.data());
}

fn windowClose(d: *display.Display, window_id: u32) !void {
    try d.send(window_id, Win.request.close, &.{});
}

fn windowDestroy(d: *display.Display, window_id: u32) !void {
    try d.send(window_id, Win.request.destroy, &.{});
}

fn windowInformResizeStart(d: *display.Display, window_id: u32) !void {
    try d.send(window_id, Win.request.inform_resize_start, &.{});
}

fn windowInformResizeEnd(d: *display.Display, window_id: u32) !void {
    try d.send(window_id, Win.request.inform_resize_end, &.{});
}

fn nodeSetPosition(d: *display.Display, node_id: u32, x: i32, y: i32) !void {
    var w = display.MsgWriter{};
    w.putI32(x);
    w.putI32(y);
    try d.send(node_id, Node.request.set_position, w.data());
}

fn nodePlaceTop(d: *display.Display, node_id: u32) !void {
    try d.send(node_id, Node.request.place_top, &.{});
}

fn seatFocusWindow(d: *display.Display, seat_id: u32, window_id: u32) !void {
    var w = display.MsgWriter{};
    w.putU32(window_id);
    try d.send(seat_id, RSeat.request.focus_window, w.data());
}

fn seatClearFocus(d: *display.Display, seat_id: u32) !void {
    try d.send(seat_id, RSeat.request.clear_focus, &.{});
}

fn seatDestroy(d: *display.Display, seat_id: u32) !void {
    try d.send(seat_id, RSeat.request.destroy, &.{});
}

fn seatOpStartPointer(d: *display.Display, seat_id: u32) !void {
    try d.send(seat_id, RSeat.request.op_start_pointer, &.{});
}

fn seatOpEnd(d: *display.Display, seat_id: u32) !void {
    try d.send(seat_id, RSeat.request.op_end, &.{});
}

fn wmExitSession(d: *display.Display) !void {
    try d.send(wm_id, Wm.request.exit_session, &.{});
}

// ── Window events ──────────────────────────────────────────────────
fn onWindow(d: *display.Display, _: u32, data: ?*anyopaque, opcode: u16, payload: []const u8) void {
    const window: *Window = @ptrCast(@alignCast(data.?));
    switch (opcode) {
        Win.event.closed => window.closed = true,
        Win.event.dimensions => {
            window.width = display.readI32(payload[0..4]);
            window.height = display.readI32(payload[4..8]);
        },
        Win.event.pointer_move_requested => {
            const seat_id = display.readU32(payload[0..4]);
            if (d.getData(seat_id)) |sd| window.pointer_move_requested = @ptrCast(@alignCast(sd));
        },
        Win.event.pointer_resize_requested => {
            const seat_id = display.readU32(payload[0..4]);
            const edges = display.readU32(payload[4..8]);
            if (d.getData(seat_id)) |sd| {
                window.pointer_resize_requested = @ptrCast(@alignCast(sd));
                window.pointer_resize_edges = edges;
            }
        },
        else => {}, // hints, app_id, title, fullscreen/maximize requests — unused
    }
}

fn onWindowCreated(d: *display.Display, window_id: u32) void {
    const node_id = windowGetNode(d, window_id) catch return;
    const window = allocator.create(Window) catch return;
    window.* = .{ .obj = window_id, .node = node_id, .is_new = true };
    window.link.init();
    d.registerObject(window_id, "river_window_v1", onWindow, window);
    display.listInsertBack(&wm_state.windows, &window.link);
    std.debug.print("window created (id={d}, node={d})\n", .{ window_id, node_id });
}

fn windowSetPosition(d: *display.Display, window: *Window, x: i32, y: i32) void {
    nodeSetPosition(d, window.node, x, y) catch {};
    window.x = x;
    window.y = y;
}

fn windowManage(d: *display.Display, window: *Window) void {
    if (window.is_new) {
        window.is_new = false;
        windowSetPosition(d, window, 0, 0);
        windowProposeDimensions(d, window.obj, 0, 0) catch {};
    }
    if (window.pointer_move_requested) |s| {
        seatPointerMove(d, s, window);
        window.pointer_move_requested = null;
    }
    if (window.pointer_resize_requested) |s| {
        seatPointerResize(d, s, window, window.pointer_resize_edges);
        window.pointer_resize_requested = null;
    }
}

fn windowMaybeDestroy(d: *display.Display, window: *Window) void {
    if (!window.closed) return;
    var it: *display.ListLink = wm_state.seats.next;
    while (it != &wm_state.seats) : (it = it.next) {
        const seat = seatFromLink(it);
        if (seat.focused == window) seat.focused = null;
        if (seat.hovered == window) seat.hovered = null;
        if (seat.interacted == window) seat.interacted = null;
        if (seat.op_window == window) {
            seatOpEnd(d, seat.obj) catch {};
            seat.op = .none;
            seat.op_window = null;
        }
    }
    windowDestroy(d, window.obj) catch {};
    d.freeId(window.obj);
    d.freeId(window.node);
    window.link.remove();
    allocator.destroy(window);
}

// ── Xkb binding events ─────────────────────────────────────────────
fn onXkbBinding(_: *display.Display, _: u32, data: ?*anyopaque, opcode: u16, _: []const u8) void {
    const binding: *XkbBinding = @ptrCast(@alignCast(data.?));
    switch (opcode) {
        XkbB.event.pressed => binding.seat.pending_action = binding.action,
        else => {},
    }
}

fn xkbBindingDestroy(d: *display.Display, binding: *XkbBinding) void {
    d.send(binding.obj, XkbB.request.destroy, &.{}) catch {};
    d.freeId(binding.obj);
    binding.link.remove();
    allocator.destroy(binding);
}

fn xkbBindingCreate(d: *display.Display, seat: *Seat, mods: u32, keysym: u32, action: Action) void {
    const binding = allocator.create(XkbBinding) catch return;
    const id = d.allocId("river_xkb_binding_v1", onXkbBinding, binding);
    binding.* = .{ .obj = id, .seat = seat, .action = action };
    binding.link.init();
    // get_xkb_binding(seat, new_id, keysym, mods) — wlroots `onuu`.
    var w = display.MsgWriter{};
    w.putU32(seat.obj);
    w.putU32(id);
    w.putU32(keysym);
    w.putU32(mods);
    d.send(xkb_bindings_id, XkbBindings.request.get_xkb_binding, w.data()) catch {
        allocator.destroy(binding);
        d.freeId(id);
        return;
    };
    d.send(id, XkbB.request.enable, &.{}) catch {};
    display.listInsertBack(&seat.xkb_bindings, &binding.link);
}

// ── Pointer binding events ─────────────────────────────────────────
fn onPointerBinding(_: *display.Display, _: u32, data: ?*anyopaque, opcode: u16, _: []const u8) void {
    const binding: *PointerBinding = @ptrCast(@alignCast(data.?));
    switch (opcode) {
        RPB.event.pressed => binding.seat.pending_action = binding.action,
        else => {},
    }
}

fn pointerBindingDestroy(d: *display.Display, binding: *PointerBinding) void {
    d.send(binding.obj, RPB.request.destroy, &.{}) catch {};
    d.freeId(binding.obj);
    binding.link.remove();
    allocator.destroy(binding);
}

fn pointerBindingCreate(d: *display.Display, seat: *Seat, mods: u32, button: u32, action: Action) void {
    const binding = allocator.create(PointerBinding) catch return;
    const id = d.allocId("river_pointer_binding_v1", onPointerBinding, binding);
    binding.* = .{ .obj = id, .seat = seat, .action = action };
    binding.link.init();
    // get_pointer_binding(new_id, button, mods) — request on the seat (no seat
    // arg); new_id first by the get_xkb_binding precedent. If Super+drag prints
    // nothing, flip the order (this one can fail silently).
    var w = display.MsgWriter{};
    w.putU32(id);
    w.putU32(button);
    w.putU32(mods);
    d.send(seat.obj, RSeat.request.get_pointer_binding, w.data()) catch {
        allocator.destroy(binding);
        d.freeId(id);
        return;
    };
    d.send(id, RPB.request.enable, &.{}) catch {};
    display.listInsertBack(&seat.pointer_bindings, &binding.link);
}

// ── Seat events ────────────────────────────────────────────────────
fn onSeat(d: *display.Display, _: u32, data: ?*anyopaque, opcode: u16, payload: []const u8) void {
    const seat: *Seat = @ptrCast(@alignCast(data.?));
    switch (opcode) {
        RSeat.event.removed => seat.removed = true,
        RSeat.event.pointer_enter => {
            const win_id = display.readU32(payload[0..4]);
            if (d.getData(win_id)) |wd| seat.hovered = @ptrCast(@alignCast(wd));
        },
        RSeat.event.pointer_leave => seat.hovered = null,
        RSeat.event.window_interaction => {
            const win_id = display.readU32(payload[0..4]);
            if (d.getData(win_id)) |wd| seat.interacted = @ptrCast(@alignCast(wd));
        },
        RSeat.event.op_delta => {
            seat.op_dx = display.readI32(payload[0..4]);
            seat.op_dy = display.readI32(payload[4..8]);
        },
        RSeat.event.op_release => seat.op_release = true,
        else => {}, // wl_seat, shell_surface_interaction, pointer_position
    }
}

fn onSeatCreated(d: *display.Display, seat_id: u32) void {
    const seat = allocator.create(Seat) catch return;
    seat.* = .{ .obj = seat_id, .is_new = true };
    seat.link.init();
    seat.xkb_bindings.init();
    seat.pointer_bindings.init();
    d.registerObject(seat_id, "river_seat_v1", onSeat, seat);
    display.listInsertBack(&wm_state.seats, &seat.link);
    std.debug.print("seat created (id={d})\n", .{seat_id});
}

fn seatFocus(d: *display.Display, seat: *Seat, target: ?*Window) void {
    var window = target;
    if (window == null and !wm_state.windows.isEmpty()) {
        window = windowFromLink(wm_state.windows.prev);
    }
    if (seat.focused == window) return;
    if (window) |w| {
        seatFocusWindow(d, seat.obj, w.obj) catch {};
        nodePlaceTop(d, w.node) catch {};
        w.link.remove();
        display.listInsertBack(&wm_state.windows, &w.link);
    } else {
        seatClearFocus(d, seat.obj) catch {};
    }
    seat.focused = window;
}

fn seatPointerMove(d: *display.Display, seat: *Seat, window: *Window) void {
    seatFocus(d, seat, window);
    seatOpStartPointer(d, seat.obj) catch {};
    seat.op = .move;
    seat.op_window = window;
    seat.op_start_x = window.x;
    seat.op_start_y = window.y;
    seat.op_dx = 0;
    seat.op_dy = 0;
    std.debug.print("seat: move start (node={d})\n", .{window.node});
}

fn seatPointerResize(d: *display.Display, seat: *Seat, window: *Window, edges: u32) void {
    seatFocus(d, seat, window);
    windowInformResizeStart(d, window.obj) catch {};
    seatOpStartPointer(d, seat.obj) catch {};
    seat.op = .resize;
    seat.op_window = window;
    seat.op_edges = edges;
    seat.op_start_x = window.x;
    seat.op_start_y = window.y;
    seat.op_start_width = window.width;
    seat.op_start_height = window.height;
    seat.op_dx = 0;
    seat.op_dy = 0;
    std.debug.print("seat: resize start (edges={d})\n", .{edges});
}

// ── Spawn (fork + exec) ────────────────────────────────────────────
// SIG_IGN on SIGCHLD persists across exec, so it must be reset to SIG_DFL in
// the child before execve — otherwise launched programs inherit the ignore
// and can't reap their own children.
fn setSigchld(handler: ?std.posix.Sigaction.handler_fn) void {
    std.posix.sigaction(.CHLD, &.{
        .handler = .{ .handler = handler },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    }, null);
}

fn spawn(program: Program) void {
    const cmd = program.command();
    if (std.c.fork() == 0) {
        setSigchld(std.posix.SIG.DFL); // children manage their own subprocesses
        const argv = [_:null]?[*:0]const u8{ cmd, null };
        const envp: [*:null]const ?[*:0]const u8 = @ptrCast(std.c.environ);
        _ = std.c.execve(cmd, &argv, envp);
        std.os.linux.exit_group(127); // exec failed: kill just this child, no atexit
    }
}

fn seatAction(d: *display.Display, seat: *Seat, action: Action) void {
    switch (action) {
        .none => {},
        .spawn => |program| spawn(program),
        .close => {
            if (seat.focused) |f| windowClose(d, f.obj) catch {};
        },
        .focus_next => {
            if (!wm_state.windows.isEmpty()) {
                seatFocus(d, seat, windowFromLink(wm_state.windows.next));
            }
        },
        .move => {
            if (seat.op == .none) {
                if (seat.hovered) |h| seatPointerMove(d, seat, h);
            }
        },
        .resize => {
            if (seat.op == .none) {
                if (seat.hovered) |h| seatPointerResize(d, seat, h, Win.edges.bottom | Win.edges.right);
            }
        },
        .exit_action => wmExitSession(d) catch {},
    }
}

fn seatManage(d: *display.Display, seat: *Seat) void {
    if (seat.is_new) {
        seat.is_new = false;
        const super = RSeat.modifiers.mod4;
        xkbBindingCreate(d, seat, super, ' ', .{ .spawn = .terminal });
        xkbBindingCreate(d, seat, super, 'b', .{ .spawn = .browser });
        xkbBindingCreate(d, seat, super, 'q', .close);
        xkbBindingCreate(d, seat, super, 'n', .focus_next);
        xkbBindingCreate(d, seat, super, std.ascii.control_code.esc, .exit_action);
        pointerBindingCreate(d, seat, super, BTN_LEFT, .move);
        pointerBindingCreate(d, seat, super, BTN_RIGHT, .resize);
    }

    seatFocus(d, seat, seat.interacted);
    seat.interacted = null;

    seatAction(d, seat, seat.pending_action);
    seat.pending_action = .none;

    switch (seat.op) {
        .none => {},
        .move => {
            if (seat.op_release) {
                seatOpEnd(d, seat.obj) catch {};
                seat.op = .none;
                seat.op_window = null;
            }
        },
        .resize => {
            if (seat.op_release) {
                if (seat.op_window) |w| windowInformResizeEnd(d, w.obj) catch {};
                seatOpEnd(d, seat.obj) catch {};
                seat.op = .none;
                seat.op_window = null;
            } else if (seat.op_window) |w| {
                var width = seat.op_start_width;
                var height = seat.op_start_height;
                if ((seat.op_edges & Win.edges.left) != 0) width -= seat.op_dx;
                if ((seat.op_edges & Win.edges.right) != 0) width += seat.op_dx;
                if ((seat.op_edges & Win.edges.top) != 0) height -= seat.op_dy;
                if ((seat.op_edges & Win.edges.bottom) != 0) height += seat.op_dy;
                windowProposeDimensions(
                    d,
                    w.obj,
                    if (width > 1) width else 1,
                    if (height > 1) height else 1,
                ) catch {};
            }
        },
    }
    seat.op_release = false;
}

fn seatMaybeDestroy(d: *display.Display, seat: *Seat) void {
    if (!seat.removed) return;
    {
        var it: *display.ListLink = seat.xkb_bindings.next;
        while (it != &seat.xkb_bindings) {
            const next = it.next;
            xkbBindingDestroy(d, xkbBindingFromLink(it));
            it = next;
        }
    }
    {
        var it: *display.ListLink = seat.pointer_bindings.next;
        while (it != &seat.pointer_bindings) {
            const next = it.next;
            pointerBindingDestroy(d, pointerBindingFromLink(it));
            it = next;
        }
    }
    seatDestroy(d, seat.obj) catch {};
    d.freeId(seat.obj);
    seat.link.remove();
    allocator.destroy(seat);
}

fn seatRender(d: *display.Display, seat: *Seat) void {
    switch (seat.op) {
        .none => {},
        .move => {
            if (seat.op_window) |w| {
                windowSetPosition(d, w, seat.op_start_x + seat.op_dx, seat.op_start_y + seat.op_dy);
            }
        },
        .resize => {
            if (seat.op_window) |w| {
                var x = seat.op_start_x;
                var y = seat.op_start_y;
                if ((seat.op_edges & Win.edges.left) != 0) x += seat.op_start_width - w.width;
                if ((seat.op_edges & Win.edges.top) != 0) y += seat.op_start_height - w.height;
                windowSetPosition(d, w, x, y);
            }
        },
    }
}

// ── Manager events ─────────────────────────────────────────────────
fn manageStart(d: *display.Display, wm_obj: u32) void {
    {
        var it: *display.ListLink = wm_state.windows.next;
        while (it != &wm_state.windows) {
            const next = it.next;
            windowMaybeDestroy(d, windowFromLink(it));
            it = next;
        }
    }
    {
        var it: *display.ListLink = wm_state.seats.next;
        while (it != &wm_state.seats) {
            const next = it.next;
            seatMaybeDestroy(d, seatFromLink(it));
            it = next;
        }
    }
    {
        var it: *display.ListLink = wm_state.windows.next;
        while (it != &wm_state.windows) : (it = it.next) {
            windowManage(d, windowFromLink(it));
        }
    }
    {
        var it: *display.ListLink = wm_state.seats.next;
        while (it != &wm_state.seats) : (it = it.next) {
            seatManage(d, seatFromLink(it));
        }
    }
    d.send(wm_obj, Wm.request.manage_finish, &.{}) catch {};
}

fn onManager(d: *display.Display, id: u32, _: ?*anyopaque, opcode: u16, payload: []const u8) void {
    switch (opcode) {
        Wm.event.unavailable => {
            std.debug.print("error: another window manager is already running\n", .{});
            std.process.exit(1);
        },
        Wm.event.finished => std.process.exit(0),
        Wm.event.window => onWindowCreated(d, display.readU32(payload[0..4])),
        Wm.event.seat => onSeatCreated(d, display.readU32(payload[0..4])),
        Wm.event.manage_start => manageStart(d, id),
        Wm.event.render_start => {
            var it: *display.ListLink = wm_state.seats.next;
            while (it != &wm_state.seats) : (it = it.next) {
                seatRender(d, seatFromLink(it));
            }
            d.send(id, Wm.request.render_finish, &.{}) catch {};
        },
        else => {}, // output, session_locked/unlocked
    }
}

fn wmInit() void {
    wm_state.windows.init();
    wm_state.seats.init();
}

pub fn main(init: std.process.Init) !void {
    const environ = init.minimal.environ;
    const runtime_dir = environ.getPosix("XDG_RUNTIME_DIR") orelse return error.NoRuntimeDir;
    const wl_display = environ.getPosix("WAYLAND_DISPLAY");

    setSigchld(std.posix.SIG.IGN); // auto-reap spawned children (no zombies)
    wmInit();

    var client = display.Display.connect(runtime_dir, wl_display) catch {
        std.debug.print("failed to connect to wayland display\n", .{});
        return error.NoDisplay;
    };
    defer client.disconnect();

    const registry_id = try client.getRegistry();
    var registry = client.Registry{};
    try client.roundtrip(&registry);

    const wm_g = registry.find("river_window_manager_v1") orelse {
        std.debug.print("river_window_manager_v1 not available\n", .{});
        return error.MissingProtocol;
    };
    if (wm_g.version < 4) {
        std.debug.print("river_window_manager_v1 v{d} too old (need v4)\n", .{wm_g.version});
        return error.MissingProtocol;
    }
    wm_id = try client.bind(registry_id, wm_g.name, "river_window_manager_v1", 4, onManager);

    const xkb_g = registry.find("river_xkb_bindings_v1") orelse {
        std.debug.print("river_xkb_bindings_v1 not available\n", .{});
        return error.MissingProtocol;
    };
    xkb_bindings_id = try client.bind(registry_id, xkb_g.name, "river_xkb_bindings_v1", 2, null);

    if (registry.find("river_layer_shell_v1")) |g|
        layer_shell_id = try client.bind(registry_id, g.name, "river_layer_shell_v1", 1, null);

    std.debug.print("river wm: bound, entering manage loop\n", .{});

    while (true) {
        client.dispatch() catch {
            std.debug.print("dispatch failed (compositor gone?)\n", .{});
            return error.DispatchFailed;
        };
    }
}
