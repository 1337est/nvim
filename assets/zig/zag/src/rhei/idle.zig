const std = @import("std");
const display = @import("display.zig");
const idle = @import("ext-idle-notify-v1");

const Notifier = idle.ext_idle_notifier_v1;
const Notif = idle.ext_idle_notification_v1;

// ── Config ─────────────────────────────────────────────────────────
// Drop this to a few seconds when testing so you don't wait 10 minutes.
const IDLE_TIMEOUT_MS: u32 = 600 * 1000;

// ── libc (spawn) ───────────────────────────────────────────────────
extern "c" fn execlp(file: [*:0]const u8, arg0: [*:0]const u8, ...) c_int;

// wlopm --<mode> '*' — exec'd directly, so no shell and the '*' (all outputs)
// is passed literally. SIGCHLD is ignored, so children are auto-reaped.
fn runWlopm(mode: [*:0]const u8) void {
    const pid = std.c.fork();
    if (pid < 0) return;

    if (pid == 0) {
        _ = execlp("wlopm", "wlopm", mode, "*", @as(?[*:0]const u8, null));
        std.os.linux.exit_group(127);
    }
}

// ── Idle notification events ───────────────────────────────────────
fn onNotification(_: *display.Display, _: u32, _: ?*anyopaque, opcode: u16, _: []const u8) void {
    switch (opcode) {
        Notif.event.idled => {
            std.debug.print("idle: screens off\n", .{});
            runWlopm("--off");
        },
        Notif.event.resumed => {
            std.debug.print("resumed: screens on\n", .{});
            runWlopm("--on");
        },
        else => {},
    }
}

// get_idle_notification(id, timeout, seat) — request on the notifier; wire
// order new_id, uint, object (confirmed by the glue's (notifier, timeout, seat)).
fn createNotification(d: *display.Display, notifier_id: u32, timeout_ms: u32, seat_id: u32) !u32 {
    const notif_id = d.allocId("ext_idle_notification_v1", onNotification, null);
    var w = display.MsgWriter{};
    w.putU32(notif_id);
    w.putU32(timeout_ms);
    w.putU32(seat_id);
    try d.send(notifier_id, Notifier.request.get_idle_notification, w.data());
    return notif_id;
}

// ── main ───────────────────────────────────────────────────────────
pub fn main(init: std.process.Init) !void {
    const environ = init.minimal.environ;
    const runtime_dir = environ.getPosix("XDG_RUNTIME_DIR") orelse return error.NoRuntimeDir;
    const wl_display = environ.getPosix("WAYLAND_DISPLAY");

    std.posix.sigaction(.CHLD, &.{
        .handler = .{ .handler = std.posix.SIG.IGN },
        .mask = std.posix.sigemptyset(),
        .flags = 0,
    }, null);

    var client = display.Display.connect(runtime_dir, wl_display) catch {
        std.debug.print("error: failed to connect to wayland display\n", .{});
        return error.NoDisplay;
    };
    defer client.disconnect();

    const registry_id = try client.getRegistry();
    var registry = display.Registry{};
    try client.roundtrip(&registry);

    const seat_g = registry.find("wl_seat") orelse {
        std.debug.print("error: no wl_seat advertised\n", .{});
        return error.MissingGlobal;
    };
    const seat_id = try client.bind(registry_id, seat_g.name, "wl_seat", @min(seat_g.version, 7), null);

    const notifier_g = registry.find("ext_idle_notifier_v1") orelse {
        std.debug.print("error: no ext_idle_notifier_v1 advertised (check compositor version)\n", .{});
        return error.MissingGlobal;
    };
    // Bind at v1 — we only use get_idle_notification (op 1); v2 adds the input
    // notification variant we don't need.
    const notifier_id = try client.bind(registry_id, notifier_g.name, "ext_idle_notifier_v1", 1, null);

    _ = try createNotification(&client, notifier_id, IDLE_TIMEOUT_MS, seat_id);

    std.debug.print("idle running, timeout = {d}s\n", .{IDLE_TIMEOUT_MS / 1000});

    while (true) {
        client.dispatch() catch {
            std.debug.print("dispatch error\n", .{});
            return error.DispatchFailed;
        };
    }
}
