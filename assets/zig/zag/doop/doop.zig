//! Text clipboard bridge: Windows server, Linux/Windows client; Zig 0.17.0.
//! No packages, libc, clipboard helpers, or build.zig. Uses std.Io and Win32.
//! Windows: zig build-exe doop.zig -Osafe -luser32 -lkernel32 -femit-bin=doop.exe
//! Linux:   zig build-exe doop.zig -Osafe -femit-bin=doop
//! Tests:   zig test doop.zig

const std = @import("std");
const builtin = @import("builtin");
const Io = std.Io;
const Allocator = std.mem.Allocator;
const max_payload = 8 * 1024 * 1024; // 8_388_608 characters (100k -> 200k LOC)
const default_port: u16 = 2489;
const timeout_seconds = 10;

const usage =
    \\doop [--port PORT] COMMAND [TEXT]
    \\
    \\  server       Windows only; listen on 127.0.0.1 (foreground).
    \\  copy [TEXT]  Replace the Windows text clipboard; omit TEXT to read stdin.
    \\  paste        Write the Windows text clipboard to stdout (UTF-8, LF).
    \\  ping         Check the server/protocol; prints "pong".
    \\
    \\Options: --port PORT or --port=PORT (default 2489), --help
    \\Use `copy -- "--literal text"` for text beginning with a dash.
    \\Both endpoints are always IPv4 loopback; use SSH RemoteForward remotely.
    \\Text only: valid UTF-8, no embedded NUL, maximum 8 MiB per wire payload.
    \\No Go RPC compatibility, TOML configuration, fallback server, or URL opening.
    \\
;

const Command = enum { server, copy, paste, ping, help };
const Config = struct {
    command: Command = .help,
    port: u16 = default_port,
    text: ?[]const u8 = null,

    fn parse(args: []const [:0]const u8) !Config {
        var result: Config = .{};
        var have_command = false;
        var literal = false;
        var i: usize = 0;
        while (i < args.len) : (i += 1) {
            const arg = args[i];
            if (!literal and std.mem.eql(u8, arg, "--")) {
                literal = true;
            } else if (!literal and (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h"))) {
                return .{ .command = .help };
            } else if (!literal and std.mem.eql(u8, arg, "--port")) {
                i += 1;
                if (i == args.len) return error.MissingPort;
                result.port = try parsePort(args[i]);
            } else if (!literal and std.mem.startsWith(u8, arg, "--port=")) {
                result.port = try parsePort(arg[7..]);
            } else if (!literal and std.mem.startsWith(u8, arg, "-")) {
                return error.UnknownOption;
            } else if (!have_command) {
                result.command = std.meta.stringToEnum(Command, arg) orelse return error.UnknownCommand;
                have_command = true;
            } else {
                if (result.command != .copy or result.text != null) return error.UnexpectedArgument;
                result.text = arg;
            }
        }
        return result;
    }

    fn parsePort(text: []const u8) !u16 {
        const port = std.fmt.parseInt(u16, text, 10) catch return error.InvalidPort;
        if (port == 0) return error.InvalidPort;
        return port;
    }
};

// Header: "LZC1", kind:u8, reserved:[3]u8=0, payload_length:u32 big-endian.
// Request kinds: 1=copy, 2=paste, 3=ping. Response kinds: 0=OK, 255=error.
// Exactly one request/response per TCP connection. No EOF-based framing.
const Wire = struct {
    const copy: u8 = 1;
    const paste: u8 = 2;
    const ping: u8 = 3;
    const ok: u8 = 0;
    const failure: u8 = 255;
    const Frame = struct { kind: u8, payload: []u8 };

    fn header(kind: u8, length: usize) ![12]u8 {
        if (length > max_payload) return error.PayloadTooLarge;
        var bytes: [12]u8 = .{ 'L', 'Z', 'C', '1', kind, 0, 0, 0, 0, 0, 0, 0 };
        std.mem.writeInt(u32, bytes[8..12], @intCast(length), .big);
        return bytes;
    }

    fn write(writer: *Io.Writer, kind: u8, payload: []const u8) !void {
        const bytes = try header(kind, payload.len);
        try writer.writeAll(&bytes);
        try writer.writeAll(payload);
    }

    fn read(gpa: Allocator, reader: *Io.Reader) !Frame {
        var bytes: [12]u8 = undefined;
        try reader.readSliceAll(&bytes);
        if (!std.mem.eql(u8, bytes[0..4], "LZC1")) return error.WrongProtocol;
        if (bytes[5] != 0 or bytes[6] != 0 or bytes[7] != 0) return error.InvalidHeader;
        const length = std.mem.readInt(u32, bytes[8..12], .big);
        if (length > max_payload) return error.PayloadTooLarge;
        const payload = try gpa.alloc(u8, length);
        errdefer gpa.free(payload);
        try reader.readSliceAll(payload);
        return .{ .kind = bytes[4], .payload = payload };
    }
};

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    const config = try Config.parse(args[1..]);
    if (config.command == .help) return Io.File.stdout().writeStreamingAll(init.io, usage);
    if (config.command == .server) {
        if (builtin.os.tag == .windows) {
            return serve(init.io, init.gpa, config.port);
        } else {
            return error.ServerRequiresWindows;
        }
    }

    // Read stdin before starting the network deadline. Reading a terminal ends at EOF.
    var input: ?[]u8 = null;
    defer if (input) |bytes| init.gpa.free(bytes);
    var payload: []const u8 = "";
    if (config.command == .copy) {
        if (config.text) |text| {
            payload = text;
        } else {
            var buffer: [4096]u8 = undefined;
            var reader = Io.File.stdin().readerStreaming(init.io, &buffer);
            input = try reader.interface.allocRemaining(init.gpa, .limited(max_payload));
            payload = input.?;
        }
        try validateText(payload);
    }
    try timed(init.io, client, .{ init.io, init.gpa, config, payload });
}

fn waitForDeadline(io: Io) Io.Cancelable!void {
    try io.sleep(.fromSeconds(timeout_seconds), .awake);
}

// Cancel and join the unfinished task before its stack/resources go out of scope.
fn timed(io: Io, comptime function: anytype, args: anytype) !void {
    const Result = union(enum) { work: anyerror!void, timeout: Io.Cancelable!void };
    var buffer: [2]Result = undefined;
    var select: Io.Select(Result) = .init(io, &buffer);
    defer select.cancelDiscard();
    try select.concurrent(.work, function, args);
    try select.concurrent(.timeout, waitForDeadline, .{io});
    switch (try select.await()) {
        .work => |result| try result,
        .timeout => |result| {
            try result;
            return error.Timeout;
        },
    }
}

fn address(port: u16) Io.net.IpAddress {
    return .{ .ip4 = .{ .bytes = .{ 127, 0, 0, 1 }, .port = port } };
}

fn client(io: Io, gpa: Allocator, config: Config, payload: []const u8) anyerror!void {
    const stream = try address(config.port).connect(io, .{ .mode = .stream });
    defer stream.close(io);
    var read_buffer: [4096]u8 = undefined;
    var write_buffer: [4096]u8 = undefined;
    var reader = stream.reader(io, &read_buffer);
    var writer = stream.writer(io, &write_buffer);
    const kind: u8 = switch (config.command) {
        .copy => Wire.copy,
        .paste => Wire.paste,
        .ping => Wire.ping,
        else => unreachable,
    };
    try Wire.write(&writer.interface, kind, payload);
    try writer.interface.flush();
    const response = try Wire.read(gpa, &reader.interface);
    defer gpa.free(response.payload);
    if (response.kind == Wire.failure) {
        std.debug.print("doop: server: {s}\n", .{response.payload});
        return error.ServerRejectedRequest;
    }
    if (response.kind != Wire.ok) return error.InvalidResponse;
    if (config.command != .copy) try Io.File.stdout().writeStreamingAll(io, response.payload);
}

fn serve(io: Io, gpa: Allocator, port: u16) !void {
    var server = try address(port).listen(io, .{});
    defer server.deinit(io);
    var clipboard: Clipboard = .{};
    try clipboard.init();
    defer clipboard.deinit();
    std.debug.print("doop: Windows clipboard on 127.0.0.1:{d}; Ctrl+C to stop\n", .{port});
    while (true) {
        const stream = try server.accept(io);
        defer stream.close(io);
        timed(io, handleClient, .{ io, gpa, stream, &clipboard }) catch |err| {
            std.debug.print("doop: request failed: {s}\n", .{@errorName(err)});
        };
    }
}

fn handleClient(io: Io, gpa: Allocator, stream: Io.net.Stream, clipboard: *Clipboard) anyerror!void {
    var read_buffer: [4096]u8 = undefined;
    var write_buffer: [4096]u8 = undefined;
    var reader = stream.reader(io, &read_buffer);
    var writer = stream.writer(io, &write_buffer);
    const request = try Wire.read(gpa, &reader.interface);
    defer gpa.free(request.payload);
    const response = dispatch(gpa, clipboard, request) catch |err| {
        try Wire.write(&writer.interface, Wire.failure, @errorName(err));
        return writer.interface.flush();
    };
    defer gpa.free(response);
    try Wire.write(&writer.interface, Wire.ok, response);
    try writer.interface.flush();
}

fn dispatch(gpa: Allocator, clipboard: *Clipboard, request: Wire.Frame) ![]u8 {
    switch (request.kind) {
        Wire.copy => {
            try clipboard.set(gpa, request.payload);
            return gpa.dupe(u8, "");
        },
        Wire.paste => {
            if (request.payload.len != 0) return error.UnexpectedPayload;
            return clipboard.get(gpa);
        },
        Wire.ping => {
            if (request.payload.len != 0) return error.UnexpectedPayload;
            return gpa.dupe(u8, "pong\n");
        },
        else => return error.UnknownOperation,
    }
}

fn validateText(text: []const u8) !void {
    if (text.len > max_payload) return error.PayloadTooLarge;
    if (std.mem.indexOfScalar(u8, text, 0) != null) return error.EmbeddedNul;
    if (!std.unicode.utf8ValidateSlice(text)) return error.InvalidUtf8;
}

// Both CRLF and bare CR are line endings. Never add or remove a final newline.
fn newlines(gpa: Allocator, text: []const u8, crlf: bool) ![]u8 {
    var result: std.ArrayList(u8) = .empty;
    errdefer result.deinit(gpa);
    var i: usize = 0;
    while (i < text.len) : (i += 1) {
        const c = text[i];
        if (c == '\r' or c == '\n') {
            if (c == '\r' and i + 1 < text.len and text[i + 1] == '\n') i += 1;
            if (crlf) try result.append(gpa, '\r');
            try result.append(gpa, '\n');
        } else {
            try result.append(gpa, c);
        }
    }
    return result.toOwnedSlice(gpa);
}

// A dedicated native thread owns a message-only window and pumps messages.
// The TCP/clipboard worker never owns this message loop. CF_UNICODETEXT is
// rendered immediately, so Windows owns its HGLOBAL after SetClipboardData.
const Clipboard = struct {
    window: ?*anyopaque = null,
    ready: ?*anyopaque = null,
    thread: ?*anyopaque = null,
    thread_id: u32 = 0,

    fn init(self: *Clipboard) !void {
        self.ready = Win.CreateEventW(null, 1, 0, null) orelse return error.CreateEventFailed;
        errdefer _ = Win.CloseHandle(self.ready.?);
        self.thread = Win.CreateThread(null, 0, windowMain, self, 0, &self.thread_id) orelse
            return error.CreateThreadFailed;
        // SetEvent/WaitForSingleObject publish `window` to this thread.
        _ = Win.WaitForSingleObject(self.ready.?, Win.infinite);
        if (self.window == null) {
            _ = Win.WaitForSingleObject(self.thread.?, Win.infinite);
            _ = Win.CloseHandle(self.thread.?);
            return error.CreateClipboardWindowFailed;
        }
    }

    fn deinit(self: *Clipboard) void {
        _ = Win.PostThreadMessageW(self.thread_id, Win.wm_quit, 0, 0);
        _ = Win.WaitForSingleObject(self.thread.?, Win.infinite);
        _ = Win.CloseHandle(self.thread.?);
        _ = Win.CloseHandle(self.ready.?);
    }

    fn windowMain(context: ?*anyopaque) callconv(.winapi) u32 {
        const self: *Clipboard = @ptrCast(@alignCast(context.?));
        const class = std.unicode.utf8ToUtf16LeStringLiteral("STATIC");
        const title = std.unicode.utf8ToUtf16LeStringLiteral("doop");
        const message_parent: *anyopaque = @ptrFromInt(@as(usize, @bitCast(@as(isize, -3))));
        self.window = Win.CreateWindowExW(0, class, title, 0, 0, 0, 0, 0, message_parent, null, null, null);
        _ = Win.SetEvent(self.ready.?);
        const window = self.window orelse return 1;
        defer _ = Win.DestroyWindow(window);
        var message: Win.Message = undefined;
        while (Win.GetMessageW(&message, null, 0, 0) > 0) {
            _ = Win.DispatchMessageW(&message);
        }
        return 0;
    }

    fn open(self: *Clipboard) !void {
        // Other Windows applications may temporarily hold the clipboard open.
        for (0..40) |_| {
            if (Win.OpenClipboard(self.window) != 0) return;
            Win.Sleep(10);
        }
        return error.ClipboardBusy;
    }

    fn set(self: *Clipboard, gpa: Allocator, text: []const u8) !void {
        try validateText(text);
        const normalized = try newlines(gpa, text, true);
        defer gpa.free(normalized);
        const wide = try std.unicode.utf8ToUtf16LeAllocZ(gpa, normalized);
        defer gpa.free(wide);
        const memory = Win.GlobalAlloc(Win.gmem_moveable, (wide.len + 1) * @sizeOf(u16)) orelse
            return error.GlobalAllocFailed;
        // Allocation/encoding are completed BEFORE destroying the old clipboard.
        errdefer _ = Win.GlobalFree(memory);
        const locked = Win.GlobalLock(memory) orelse return error.GlobalLockFailed;
        const destination: [*]u16 = @ptrCast(@alignCast(locked));
        @memcpy(destination[0..wide.len], wide);
        destination[wide.len] = 0;
        _ = Win.GlobalUnlock(memory);
        try self.open();
        defer _ = Win.CloseClipboard();
        if (Win.EmptyClipboard() == 0) return error.EmptyClipboardFailed;
        _ = Win.SetClipboardData(Win.cf_unicode_text, memory) orelse return error.SetClipboardFailed;
        // Success transfers memory ownership to Windows. Do not GlobalFree it.
    }

    fn get(self: *Clipboard, gpa: Allocator) ![]u8 {
        try self.open();
        defer _ = Win.CloseClipboard();
        if (Win.IsClipboardFormatAvailable(Win.cf_unicode_text) == 0) return gpa.dupe(u8, "");
        const memory = Win.GetClipboardData(Win.cf_unicode_text) orelse return error.GetClipboardFailed;
        const size = Win.GlobalSize(memory);
        // Allow CRLF expansion and UTF-16 storage, plus allocation rounding.
        if (size < 2) return error.InvalidClipboardData;
        if (size > max_payload * 4 + 64) return error.PayloadTooLarge;
        const locked = Win.GlobalLock(memory) orelse return error.GlobalLockFailed;
        defer _ = Win.GlobalUnlock(memory);
        const words: [*]const u16 = @ptrCast(@alignCast(locked));
        const slice = words[0 .. size / @sizeOf(u16)];
        const length = std.mem.indexOfScalar(u16, slice, 0) orelse return error.UnterminatedClipboardText;
        const utf8 = try std.unicode.utf16LeToUtf8Alloc(gpa, slice[0..length]);
        defer gpa.free(utf8);
        const result = try newlines(gpa, utf8, false);
        errdefer gpa.free(result);
        try validateText(result);
        return result;
    }
};

// Direct operating-system imports. No headers, @cImport, or third-party bindings.
const Win = struct {
    const cf_unicode_text: u32 = 13;
    const gmem_moveable: u32 = 0x0002;
    const wm_quit: u32 = 0x0012;
    const infinite: u32 = 0xffffffff;
    const Message = extern struct {
        hwnd: ?*anyopaque,
        message: u32,
        w_param: usize,
        l_param: isize,
        time: u32,
        x: i32,
        y: i32,
        private: u32,
    };
    extern "user32" fn CreateWindowExW(u32, [*:0]const u16, [*:0]const u16, u32, i32, i32, i32, i32, ?*anyopaque, ?*anyopaque, ?*anyopaque, ?*anyopaque) callconv(.winapi) ?*anyopaque;
    extern "user32" fn DestroyWindow(*anyopaque) callconv(.winapi) i32;
    extern "user32" fn GetMessageW(*Message, ?*anyopaque, u32, u32) callconv(.winapi) i32;
    extern "user32" fn DispatchMessageW(*const Message) callconv(.winapi) isize;
    extern "user32" fn PostThreadMessageW(u32, u32, usize, isize) callconv(.winapi) i32;
    extern "user32" fn OpenClipboard(?*anyopaque) callconv(.winapi) i32;
    extern "user32" fn CloseClipboard() callconv(.winapi) i32;
    extern "user32" fn EmptyClipboard() callconv(.winapi) i32;
    extern "user32" fn SetClipboardData(u32, *anyopaque) callconv(.winapi) ?*anyopaque;
    extern "user32" fn GetClipboardData(u32) callconv(.winapi) ?*anyopaque;
    extern "user32" fn IsClipboardFormatAvailable(u32) callconv(.winapi) i32;
    extern "kernel32" fn GlobalAlloc(u32, usize) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn GlobalFree(*anyopaque) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn GlobalLock(*anyopaque) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn GlobalUnlock(*anyopaque) callconv(.winapi) i32;
    extern "kernel32" fn GlobalSize(*anyopaque) callconv(.winapi) usize;
    extern "kernel32" fn Sleep(u32) callconv(.winapi) void;
    extern "kernel32" fn CreateEventW(?*anyopaque, i32, i32, ?[*:0]const u16) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn SetEvent(*anyopaque) callconv(.winapi) i32;
    extern "kernel32" fn CreateThread(?*anyopaque, usize, *const fn (?*anyopaque) callconv(.winapi) u32, ?*anyopaque, u32, ?*u32) callconv(.winapi) ?*anyopaque;
    extern "kernel32" fn WaitForSingleObject(*anyopaque, u32) callconv(.winapi) u32;
    extern "kernel32" fn CloseHandle(*anyopaque) callconv(.winapi) i32;
};

// Pure tests: do not read or overwrite the actual clipboard.
test "wire golden header and exact frame reads" {
    const gpa = std.testing.allocator;
    const header = try Wire.header(Wire.copy, 3);
    try std.testing.expectEqualSlices(u8, &.{ 'L', 'Z', 'C', '1', 1, 0, 0, 0, 0, 0, 0, 3 }, &header);
    var bytes: [128]u8 = undefined;
    var writer: Io.Writer = .fixed(&bytes);
    try Wire.write(&writer, Wire.copy, "abc");
    try Wire.write(&writer, Wire.paste, "");
    var reader: Io.Reader = .fixed(bytes[0..writer.end]);
    const first = try Wire.read(gpa, &reader);
    defer gpa.free(first.payload);
    try std.testing.expectEqual(Wire.copy, first.kind);
    try std.testing.expectEqualStrings("abc", first.payload);
    const second = try Wire.read(gpa, &reader);
    defer gpa.free(second.payload);
    try std.testing.expectEqual(Wire.paste, second.kind);
    try std.testing.expectEqual(@as(usize, 0), second.payload.len);
}

test "wire rejects wrong magic reserved bits excessive length and truncation" {
    const gpa = std.testing.allocator;
    var bytes = try Wire.header(Wire.copy, 3);
    bytes[0] = 'X';
    var reader: Io.Reader = .fixed(&bytes);
    try std.testing.expectError(error.WrongProtocol, Wire.read(gpa, &reader));
    bytes[0] = 'L';
    bytes[5] = 1;
    reader = .fixed(&bytes);
    try std.testing.expectError(error.InvalidHeader, Wire.read(gpa, &reader));
    bytes[5] = 0;
    reader = .fixed(&bytes);
    try std.testing.expectError(error.EndOfStream, Wire.read(gpa, &reader));
    std.mem.writeInt(u32, bytes[8..12], max_payload + 1, .big);
    reader = .fixed(&bytes);
    try std.testing.expectError(error.PayloadTooLarge, Wire.read(gpa, &reader));
    try std.testing.expectError(error.PayloadTooLarge, Wire.header(1, max_payload + 1));
}

test "Unicode text and newline round trip" {
    const gpa = std.testing.allocator;
    const text = "café λ 😀\nsecond line\n";
    try validateText(text);
    const crlf = try newlines(gpa, text, true);
    defer gpa.free(crlf);
    try std.testing.expectEqualStrings("café λ 😀\r\nsecond line\r\n", crlf);
    const wide = try std.unicode.utf8ToUtf16LeAllocZ(gpa, crlf);
    defer gpa.free(wide);
    const decoded = try std.unicode.utf16LeToUtf8Alloc(gpa, wide);
    defer gpa.free(decoded);
    const lf = try newlines(gpa, decoded, false);
    defer gpa.free(lf);
    try std.testing.expectEqualStrings(text, lf);
    try std.testing.expectError(error.InvalidUtf8, validateText("\xff"));
    try std.testing.expectError(error.EmbeddedNul, validateText("a\x00b"));
}

test "empty clipboard and mixed newline normalization" {
    const gpa = std.testing.allocator;
    const empty = try newlines(gpa, "", true);
    defer gpa.free(empty);
    try std.testing.expectEqualStrings("", empty);
    const lf = try newlines(gpa, "a\rb\r\nc\nd", false);
    defer gpa.free(lf);
    try std.testing.expectEqualStrings("a\nb\nc\nd", lf);
    const crlf = try newlines(gpa, "a\rb\r\nc\nd", true);
    defer gpa.free(crlf);
    try std.testing.expectEqualStrings("a\r\nb\r\nc\r\nd", crlf);
}

test "CLI port forms and empty literal copy" {
    const a = try Config.parse(&.{ "--port=24890", "copy", "" });
    try std.testing.expectEqual(@as(u16, 24890), a.port);
    try std.testing.expectEqualStrings("", a.text.?);
    const b = try Config.parse(&.{ "paste", "--port", "24890" });
    try std.testing.expectEqual(Command.paste, b.command);
    const c = try Config.parse(&.{ "copy", "--", "--literal" });
    try std.testing.expectEqualStrings("--literal", c.text.?);
    try std.testing.expectError(error.InvalidPort, Config.parse(&.{ "--port", "0", "paste" }));
    try std.testing.expectError(error.UnexpectedArgument, Config.parse(&.{ "paste", "extra" }));
}
