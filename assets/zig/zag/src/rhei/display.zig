const std = @import("std");
const linux = std.os.linux;

fn sysConnect(fd: i32, addr: *const linux.sockaddr.un, len: u32) isize {
    return @bitCast(linux.connect(fd, @ptrCast(addr), len));
}

fn writeU32(buf: []u8, val: u32) void {
    buf[0..4].* = @bitCast(val);
}

pub fn readU32(buf: []const u8) u32 {
    return @bitCast(buf[0..4].*);
}

pub fn readString(buf: []const u8) struct { str: []const u8, consumed: usize } {
    const len = readU32(buf);
    const str = buf[4..][0 .. len - 1];
    const padded = (len + 3) & ~@as(u32, 3);
    return .{ .str = str, .consumed = 4 + padded };
}

pub fn readI32(buf: []const u8) i32 {
    return @bitCast(readU32(buf));
}

// ── Intrusive doubly-linked list (generic) ─────────────────────────

pub const ListLink = struct {
    prev: *ListLink,
    next: *ListLink,

    pub fn init(self: *ListLink) void {
        self.prev = self;
        self.next = self;
    }
    pub fn insertAfter(self: *ListLink, new: *ListLink) void {
        new.prev = self;
        new.next = self.next;
        self.next.prev = new;
        self.next = new;
    }
    pub fn remove(self: *ListLink) void {
        self.prev.next = self.next;
        self.next.prev = self.prev;
        self.prev = self;
        self.next = self;
    }
    pub fn isEmpty(self: *const ListLink) bool {
        return self.next == self;
    }
};

pub fn listInsertBack(head: *ListLink, new_link: *ListLink) void {
    head.prev.insertAfter(new_link);
}

// ── cmsg helpers for fd passing ────────────────────────────────────

const Cmsg = extern struct { len: usize, level: i32, type: i32 };

const CMSG_HDR_SIZE = (@sizeOf(Cmsg) + @alignOf(usize) - 1) & ~@as(usize, @alignOf(usize) - 1);
const CMSG_SPACE = (CMSG_HDR_SIZE + @sizeOf(i32) + @alignOf(usize) - 1) & ~@as(usize, @alignOf(usize) - 1);
const CMSG_LEN = CMSG_HDR_SIZE + @sizeOf(i32);
const SCM_RIGHTS = 1;
const MSG_DONTWAIT: u32 = 0x40;

// ── Wire writer ────────────────────────────────────────────────────

pub const MsgWriter = struct {
    buf: [1024]u8 = undefined,
    pos: usize = 0,

    pub fn putU32(self: *MsgWriter, val: u32) void {
        self.buf[self.pos..][0..4].* = @bitCast(val);
        self.pos += 4;
    }

    pub fn putI32(self: *MsgWriter, val: i32) void {
        self.buf[self.pos..][0..4].* = @bitCast(val);
        self.pos += 4;
    }

    pub fn putString(self: *MsgWriter, str: []const u8) void {
        const len: u32 = @intCast(str.len + 1); // include null
        const padded = (len + 3) & ~@as(u32, 3);
        self.putU32(len);
        @memcpy(self.buf[self.pos..][0..str.len], str);
        self.buf[self.pos + str.len] = 0;
        const pad_start = self.pos + str.len + 1;
        const pad_end = self.pos + padded;
        @memset(self.buf[pad_start..pad_end], 0);
        self.pos += padded;
    }

    pub fn putArray(self: *MsgWriter, bytes: []const u8) void {
        const len: u32 = @intCast(bytes.len);
        const padded = (len + 3) & ~@as(u32, 3);
        self.putU32(len);
        @memcpy(self.buf[self.pos..][0..bytes.len], bytes);
        @memset(self.buf[self.pos + bytes.len ..][0 .. padded - len], 0);
        self.pos += padded;
    }

    pub fn data(self: *MsgWriter) []const u8 {
        return self.buf[0..self.pos];
    }
};

// ── Object table ───────────────────────────────────────────────────

pub const GlobalInfo = struct {
    name: u32,
    interface: []const u8,
    version: u32,
};

// ── Registry: collect globals during roundtrip, find by interface ──
// Copies interface strings out of the dispatch buffer (overwritten on the next
// dispatch), so stored entries stay valid for the Registry's lifetime.
pub const Registry = struct {
    entries: [128]GlobalInfo = undefined,
    count: usize = 0,
    string_buf: [4096]u8 = undefined,
    string_pos: usize = 0,

    fn collect(self: *Registry, info: GlobalInfo) void {
        if (self.count >= self.entries.len) return;
        const dest = self.string_buf[self.string_pos..][0..info.interface.len];
        @memcpy(dest, info.interface);
        self.string_pos += info.interface.len;
        self.entries[self.count] = .{ .name = info.name, .interface = dest, .version = info.version };
        self.count += 1;
    }

    pub fn find(self: *const Registry, interface: []const u8) ?GlobalInfo {
        for (self.entries[0..self.count]) |g| {
            if (std.mem.eql(u8, g.interface, interface)) return g;
        }
        return null;
    }

    pub fn list(self: *const Registry) []const GlobalInfo {
        return self.entries[0..self.count];
    }
};

// Handler receives the object's user data (the C `data` arg), so a
// per-object handler can recover its *Window/*Seat without a side lookup.
pub const EventHandler = *const fn (self: *Display, id: u32, data: ?*anyopaque, opcode: u16, payload: []const u8) void;

pub const ObjectInfo = struct {
    id: u32 = 0,
    interface: []const u8 = "",
    handler: ?EventHandler = null,
    data: ?*anyopaque = null,
};

// Open-addressing map keyed by object id. Holds both client-allocated ids
// (low) and server-allocated ids (>= 0xff000000), and reclaims on free.
// Capacity is for *concurrent* live objects, not total allocated.
const OBJ_CAP = 1 << 12; // 4096
const SlotState = enum(u8) { empty, used, tomb };
const Slot = struct { state: SlotState = .empty, info: ObjectInfo = .{} };

fn hashId(id: u32) usize {
    return (id *% 2654435761) >> (32 - 12); // top 12 bits → [0, 4096)
}

// ── Display (connection + dispatch core) ───────────────────────────

pub const Display = struct {
    fd: i32,
    next_id: u32 = 2,
    objects: [OBJ_CAP]Slot = @splat(.{}),
    buf: [8192]u8 = undefined,
    len: usize = 0,
    pending_fd: i32 = -1,

    registry: ?*Registry = null,
    roundtrip_done: bool = false,

    pub fn connect(runtime_dir: []const u8, wl_name_opt: ?[]const u8) !Display {
        const wl_name = wl_name_opt orelse "wayland-0";

        var addr: linux.sockaddr.un = .{ .family = linux.AF.UNIX, .path = undefined };
        @memset(&addr.path, 0);

        var pos: usize = 0;
        @memcpy(addr.path[pos..][0..runtime_dir.len], runtime_dir);
        pos += runtime_dir.len;
        addr.path[pos] = '/';
        pos += 1;
        @memcpy(addr.path[pos..][0..wl_name.len], wl_name);
        pos += wl_name.len;

        const sock_rc = linux.socket(linux.AF.UNIX, linux.SOCK.STREAM | linux.SOCK.CLOEXEC, 0);
        const sock_fd: i32 = @intCast(@as(isize, @bitCast(sock_rc)));
        if (sock_fd < 0) return error.SocketFailed;

        const addr_len: u32 = @intCast(@offsetOf(linux.sockaddr.un, "path") + pos);
        if (sysConnect(sock_fd, &addr, addr_len) < 0) {
            _ = linux.close(sock_fd);
            return error.ConnectFailed;
        }

        var display = Display{ .fd = sock_fd };
        // Object 1 is always wl_display
        display.registerObject(1, "wl_display", handleDisplay, null);
        return display;
    }

    pub fn disconnect(self: *Display) void {
        _ = linux.close(self.fd);
    }

    // ── Object map ─────────────────────────────────────────────────

    fn putObject(self: *Display, info: ObjectInfo) void {
        var i = hashId(info.id);
        var first_tomb: ?usize = null;
        var probes: usize = 0;
        while (probes < OBJ_CAP) : ({
            i = (i + 1) & (OBJ_CAP - 1);
            probes += 1;
        }) {
            switch (self.objects[i].state) {
                .empty => {
                    const slot = first_tomb orelse i;
                    self.objects[slot] = .{ .state = .used, .info = info };
                    return;
                },
                .tomb => if (first_tomb == null) {
                    first_tomb = i;
                },
                .used => if (self.objects[i].info.id == info.id) {
                    self.objects[i].info = info; // overwrite existing
                    return;
                },
            }
        }
        // Table full — OBJ_CAP must exceed peak concurrent object count.
    }

    fn findObject(self: *Display, id: u32) ?*ObjectInfo {
        var i = hashId(id);
        var probes: usize = 0;
        while (probes < OBJ_CAP) : ({
            i = (i + 1) & (OBJ_CAP - 1);
            probes += 1;
        }) {
            switch (self.objects[i].state) {
                .empty => return null,
                .tomb => {},
                .used => if (self.objects[i].info.id == id) return &self.objects[i].info,
            }
        }
        return null;
    }

    pub fn allocId(self: *Display, interface: []const u8, handler: ?EventHandler, data: ?*anyopaque) u32 {
        const id = self.next_id;
        self.next_id += 1;
        self.putObject(.{ .id = id, .interface = interface, .handler = handler, .data = data });
        return id;
    }

    /// Register a server-allocated id delivered by a new_id event.
    pub fn registerObject(self: *Display, id: u32, interface: []const u8, handler: ?EventHandler, data: ?*anyopaque) void {
        self.putObject(.{ .id = id, .interface = interface, .handler = handler, .data = data });
    }

    pub fn freeId(self: *Display, id: u32) void {
        var i = hashId(id);
        var probes: usize = 0;
        while (probes < OBJ_CAP) : ({
            i = (i + 1) & (OBJ_CAP - 1);
            probes += 1;
        }) {
            switch (self.objects[i].state) {
                .empty => return,
                .tomb => {},
                .used => if (self.objects[i].info.id == id) {
                    self.objects[i].state = .tomb;
                    return;
                },
            }
        }
    }

    pub fn getData(self: *Display, id: u32) ?*anyopaque {
        if (self.findObject(id)) |o| return o.data;
        return null;
    }

    pub fn setData(self: *Display, id: u32, data: ?*anyopaque) void {
        if (self.findObject(id)) |o| o.data = data;
    }

    // ── Wire I/O ───────────────────────────────────────────────────

    pub fn send(self: *Display, object_id: u32, opcode: u16, args: []const u8) !void {
        return self.sendWithFd(object_id, opcode, args, -1);
    }

    pub fn sendWithFd(self: *Display, object_id: u32, opcode: u16, args: []const u8, fd_to_send: i32) !void {
        const size: u32 = @intCast(8 + args.len);
        var hdr: [8]u8 = undefined;
        writeU32(hdr[0..4], object_id);
        writeU32(hdr[4..8], (size << 16) | opcode);

        var iovecs = [2]std.posix.iovec_const{
            .{ .base = &hdr, .len = 8 },
            .{ .base = args.ptr, .len = args.len },
        };
        const iov_len: usize = if (args.len > 0) 2 else 1;

        var cmsg_buf: [CMSG_SPACE]u8 align(@alignOf(Cmsg)) = undefined;

        var msg = std.posix.msghdr_const{
            .name = null,
            .namelen = 0,
            .iov = &iovecs,
            .iovlen = iov_len,
            .control = null,
            .controllen = 0,
            .flags = 0,
        };

        if (fd_to_send >= 0) {
            const cmsg: *Cmsg = @ptrCast(@alignCast(&cmsg_buf));
            cmsg.len = CMSG_LEN;
            cmsg.level = linux.SOL.SOCKET;
            cmsg.type = SCM_RIGHTS;
            const fd_ptr: *i32 = @ptrCast(@alignCast(cmsg_buf[CMSG_HDR_SIZE..]));
            fd_ptr.* = fd_to_send;
            msg.control = &cmsg_buf;
            msg.controllen = CMSG_SPACE;
        }

        const rc: isize = @bitCast(linux.sendmsg(self.fd, &msg, 0));
        if (rc < 0) return error.SendFailed;
    }

    fn recv(self: *Display) !void {
        var iov = [1]std.posix.iovec{
            .{ .base = self.buf[self.len..].ptr, .len = self.buf[self.len..].len },
        };
        var cmsg_buf: [CMSG_SPACE]u8 align(@alignOf(Cmsg)) = undefined;

        var msg = std.posix.msghdr{
            .name = null,
            .namelen = 0,
            .iov = &iov,
            .iovlen = 1,
            .control = &cmsg_buf,
            .controllen = CMSG_SPACE,
            .flags = 0,
        };

        const rc: isize = @bitCast(linux.recvmsg(self.fd, &msg, 0));
        if (rc <= 0) return error.RecvFailed;
        self.len += @intCast(rc);

        if (msg.controllen >= CMSG_HDR_SIZE) {
            const cmsg: *const Cmsg = @ptrCast(@alignCast(msg.control));
            if (cmsg.level == linux.SOL.SOCKET and cmsg.type == SCM_RIGHTS) {
                const fd_ptr: *const i32 = @ptrCast(@alignCast(@as([*]const u8, @ptrCast(msg.control))[CMSG_HDR_SIZE..]));
                self.pending_fd = fd_ptr.*;
            }
        }
    }

    fn consume(self: *Display, size: usize) void {
        const remaining = self.len - size;
        std.mem.copyForwards(u8, self.buf[0..remaining], self.buf[size..self.len]);
        self.len = remaining;
    }

    // ── Generic new-id request ─────────────────────────────────────

    pub fn sendNewId(self: *Display, object_id: u32, opcode: u16, interface: []const u8, handler: ?EventHandler) !u32 {
        const new_id = self.allocId(interface, handler, null);
        var w = MsgWriter{};
        w.putU32(new_id);
        try self.send(object_id, opcode, w.data());
        return new_id;
    }

    // ── Core wl_display / wl_registry requests ─────────────────────

    pub fn getRegistry(self: *Display) !u32 {
        return self.sendNewId(1, 1, "wl_registry", handleRegistry);
    }

    pub fn sync(self: *Display) !u32 {
        return self.sendNewId(1, 0, "wl_callback", handleCallback);
    }

    /// wl_registry.bind (opcode 0) — special wire encoding for untyped new_id
    pub fn bind(self: *Display, registry_id: u32, name: u32, interface: []const u8, version: u32, handler: ?EventHandler) !u32 {
        const new_id = self.allocId(interface, handler, null);
        var w = MsgWriter{};
        w.putU32(name);
        w.putString(interface);
        w.putU32(version);
        w.putU32(new_id);
        try self.send(registry_id, 0, w.data());
        return new_id;
    }

    // ── Event dispatch ─────────────────────────────────────────────

    // Dispatch one complete message already buffered (assumes self.len >= size).
    fn dispatchOne(self: *Display, size: usize) void {
        const sender = readU32(self.buf[0..4]);
        const size_op = readU32(self.buf[4..8]);
        const opcode: u16 = @intCast(size_op & 0xFFFF);
        const payload = self.buf[8..size];
        if (self.findObject(sender)) |obj| {
            if (obj.handler) |handler| {
                handler(self, sender, obj.data, opcode, payload);
            }
        }
        self.consume(size);
    }

    // Blocking: wait for and dispatch exactly one message.
    pub fn dispatch(self: *Display) !void {
        while (self.len < 8) try self.recv();
        const size_op = readU32(self.buf[4..8]);
        const size: usize = size_op >> 16;
        while (self.len < size) try self.recv();
        self.dispatchOne(size);
    }

    // Non-blocking recv (MSG_DONTWAIT). false = nothing available right now;
    // errors only on a real failure or peer close.
    fn recvNonblock(self: *Display) !bool {
        var iov = [1]std.posix.iovec{
            .{ .base = self.buf[self.len..].ptr, .len = self.buf[self.len..].len },
        };
        var cmsg_buf: [CMSG_SPACE]u8 align(@alignOf(Cmsg)) = undefined;
        var msg = std.posix.msghdr{
            .name = null,
            .namelen = 0,
            .iov = &iov,
            .iovlen = 1,
            .control = &cmsg_buf,
            .controllen = CMSG_SPACE,
            .flags = 0,
        };
        const rc: isize = @bitCast(linux.recvmsg(self.fd, &msg, MSG_DONTWAIT));
        if (rc < 0) {
            const e: linux.E = @fromBackingInt(@intCast(@as(u16, @intCast(-rc))));
            switch (e) {
                .AGAIN, .INTR => return false, // nothing available right now
                else => return error.RecvFailed,
            }
        }
        if (rc == 0) return error.RecvFailed; // peer closed
        self.len += @intCast(rc);

        if (msg.controllen >= CMSG_HDR_SIZE) {
            const cmsg: *const Cmsg = @ptrCast(@alignCast(msg.control));
            if (cmsg.level == linux.SOL.SOCKET and cmsg.type == SCM_RIGHTS) {
                const fd_ptr: *const i32 = @ptrCast(@alignCast(@as([*]const u8, @ptrCast(msg.control))[CMSG_HDR_SIZE..]));
                self.pending_fd = fd_ptr.*;
            }
        }
        return true;
    }

    // Non-blocking: drain the socket and dispatch every complete message,
    // returning once no more data is available. Pair with poll() on `fd`.
    pub fn dispatchPending(self: *Display) !void {
        while (true) {
            while (self.len >= 8) {
                const size_op = readU32(self.buf[4..8]);
                const size: usize = size_op >> 16;
                if (self.len < size) break; // partial; wait for more bytes
                self.dispatchOne(size);
            }
            if (!try self.recvNonblock()) return;
        }
    }

    pub fn roundtrip(self: *Display, registry: *Registry) !void {
        self.registry = registry;
        self.roundtrip_done = false;
        _ = try self.sync();

        while (!self.roundtrip_done) {
            try self.dispatch();
        }

        self.registry = null;
    }

    // ── Built-in core event handlers ───────────────────────────────

    fn handleDisplay(self: *Display, _: u32, _: ?*anyopaque, opcode: u16, payload: []const u8) void {
        switch (opcode) {
            0 => {
                // wl_display.error(object_id, code, message)
                const object_id = readU32(payload[0..4]);
                const code = readU32(payload[4..8]);
                const msg = readString(payload[8..]);
                std.debug.print("wl_display.error: object {d}, code {d}: {s}\n", .{ object_id, code, msg.str });
            },
            1 => {
                // wl_display.delete_id(id) — server released this id; free our slot
                const id = readU32(payload[0..4]);
                self.freeId(id);
            },
            else => {},
        }
    }

    fn handleRegistry(self: *Display, _: u32, _: ?*anyopaque, opcode: u16, payload: []const u8) void {
        switch (opcode) {
            0 => {
                // wl_registry.global(name: uint, interface: string, version: uint)
                const name = readU32(payload[0..4]);
                const str = readString(payload[4..]);
                const version = readU32(payload[4 + str.consumed ..][0..4]);
                if (self.registry) |r| {
                    r.collect(.{ .name = name, .interface = str.str, .version = version });
                }
            },
            1 => {}, // global_remove — ignore for now
            else => {},
        }
    }

    fn handleCallback(self: *Display, id: u32, _: ?*anyopaque, opcode: u16, _: []const u8) void {
        if (opcode == 0) {
            self.roundtrip_done = true;
            self.freeId(id);
        }
    }
};
