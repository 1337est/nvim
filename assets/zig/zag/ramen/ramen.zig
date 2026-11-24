const std = @import("std");

pub const epoll = struct {
    pub const Token = u64;

    pub const Ready = struct {
        token: Token,
        events: u32,
    };

    pub const Poller = struct {
        fd: std.os.linux.fd_t,

        pub fn init() !Poller {
            const result = std.os.linux.epoll_create1(std.os.linux.EPOLL.CLOEXEC);
            return switch (std.os.linux.errno(result)) {
                .SUCCESS => .{
                    .fd = @intCast(result),
                },
                else => |err| std.posix.unexpectedErrno(err),
            };
        }

        pub fn deinit(self: *Poller) void {
            if (self.fd >= 0) {
                _ = std.os.linux.close(self.fd);
            }
            self.* = undefined;
        }

        pub fn add(self: *Poller, fd: std.os.linux.fd_t, token: Token, events: u32) !void {
            var event: std.os.linux.epoll_event = .{
                .events = events,
                .data = .{
                    .u64 = token,
                },
            };
            try control(self.fd, std.os.linux.EPOLL.CTL_ADD, fd, &event);
        }

        pub fn modify(self: *Poller, fd: std.os.linux.fd_t, token: Token, events: u32) !void {
            var event: std.os.linux.epoll_event = .{
                .events = events,
                .data = .{
                    .u64 = token,
                },
            };
            try control(self.fd, std.os.linux.EPOLL.CTL_MOD, fd, &event);
        }

        pub fn remove(self: *Poller, fd: std.os.linux.fd_t) !void {
            try control(self.fd, std.os.linux.EPOLL.CTL_DEL, fd, null);
        }

        pub fn wait(self: *Poller, output: []Ready, timeout_ms: i32) !usize {
            if (output.len == 0) {
                return 0;
            }

            var raw: [256]std.os.linux.epoll_event = undefined;
            const count_limit = @min(
                output.len,
                raw.len,
            );

            const result = std.os.linux.epoll_wait(
                self.fd,
                raw[0..count_limit].ptr,
                @intCast(count_limit),
                timeout_ms,
            );

            const count: usize = switch (std.os.linux.errno(result)) {
                .SUCCESS => @intCast(result),
                .INTR => return 0,
                else => |err| return std.posix.unexpectedErrno(err),
            };

            for (raw[0..count], 0..) |event, index| {
                output[index] = .{
                    .token = event.data.u64,
                    .events = event.events,
                };
            }
            return count;
        }
    };

    fn control(
        epoll_fd: std.os.linux.fd_t,
        operation: u32,
        fd: std.os.linux.fd_t,
        event: ?*std.os.linux.epoll_event,
    ) !void {
        const result = std.os.linux.epoll_ctl(epoll_fd, operation, fd, event);
        switch (std.os.linux.errno(result)) {
            .SUCCESS => return,
            else => |err| return std.posix.unexpectedErrno(err),
        }
    }
};

pub const eventfd = struct {
    pub const Options = struct {
        nonblocking: bool = true,
        close_on_exec: bool = true,
        semaphore: bool = false,
    };

    pub fn create(initial_value: u32, options: Options) !std.os.linux.fd_t {
        var flags: u32 = 0;
        if (options.nonblocking) flags |= std.os.linux.EFD.NONBLOCK;
        if (options.close_on_exec) flags |= std.os.linux.EFD.CLOEXEC;
        if (options.semaphore) flags |= std.os.linux.EFD.SEMAPHORE;

        const result = std.os.linux.eventfd(initial_value, flags);
        return switch (std.os.linux.errno(result)) {
            .SUCCESS => @intCast(result),
            else => |err| std.posix.unexpectedErrno(err),
        };
    }

    pub fn signal(fd: std.os.linux.fd_t, count: u64) !void {
        if (count == 0) return;
        var value = count;
        const bytes = std.mem.asBytes(&value);
        var offset: usize = 0;
        while (offset < bytes.len) {
            const result = std.os.linux.write(fd, bytes[offset..].ptr, bytes.len - offset);
            switch (std.os.linux.errno(result)) {
                .SUCCESS => offset += @intCast(result),
                .INTR => continue,
                .AGAIN => return error.CounterWouldBlock,
                else => |err| return std.posix.unexpectedErrno(err),
            }
        }
    }

    pub fn read(fd: std.os.linux.fd_t) !?u64 {
        var value: u64 = 0;
        const bytes = std.mem.asBytes(&value);
        var offset: usize = 0;
        while (offset < bytes.len) {
            const result = std.os.linux.read(fd, bytes[offset..].ptr, bytes.len - offset);
            switch (std.os.linux.errno(result)) {
                .SUCCESS => {
                    if (result == 0) return error.UnexpectedEndOfFile;
                    offset += @intCast(result);
                },
                .INTR => continue,
                .AGAIN => return null,
                else => |err| return std.posix.unexpectedErrno(err),
            }
        }
        return value;
    }

    pub fn wait(fd: std.os.linux.fd_t) !u64 {
        while (true) {
            if (try read(fd)) |count| return count;
            var descriptor = [_]std.posix.pollfd{.{
                .fd = fd,
                .events = std.posix.POLL.IN,
                .revents = 0,
            }};
            _ = try std.posix.poll(&descriptor, -1);
        }
    }

    pub fn close(fd: std.os.linux.fd_t) void {
        if (fd >= 0) _ = std.os.linux.close(fd);
    }
};

pub const memfd = struct {
    pub const Access = enum {
        read_only,
        read_write,
    };

    pub const CreateOptions = struct {
        close_on_exec: bool = true,
        allow_sealing: bool = true,
    };

    pub fn create(name: [:0]const u8, size: usize, options: CreateOptions) !std.os.linux.fd_t {
        var flags: u32 = 0;
        if (options.close_on_exec) flags |= std.os.linux.MFD.CLOEXEC;
        if (options.allow_sealing) flags |= std.os.linux.MFD.ALLOW_SEALING;

        const result = std.os.linux.memfd_create(name.ptr, flags);
        const fd: std.os.linux.fd_t = switch (std.os.linux.errno(result)) {
            .SUCCESS => @intCast(result),
            else => |err| return std.posix.unexpectedErrno(err),
        };
        errdefer _ = std.os.linux.close(fd);
        try resize(fd, size);
        return fd;
    }

    pub fn createNamed(name: []const u8, options: CreateOptions) !std.os.linux.fd_t {
        var buffer: [256]u8 = undefined;
        if (name.len + 1 > buffer.len) return error.NameTooLong;
        @memcpy(buffer[0..name.len], name);
        buffer[name.len] = 0;
        return create(buffer[0..name.len :0], 0, options);
    }

    pub fn resize(fd: std.os.linux.fd_t, size: usize) !void {
        const result = std.os.linux.ftruncate(fd, @intCast(size));
        switch (std.os.linux.errno(result)) {
            .SUCCESS => return,
            else => |err| return std.posix.unexpectedErrno(err),
        }
    }

    pub fn map(fd: std.os.linux.fd_t, size: usize, access: Access) ![]align(std.heap.page_size_min) u8 {
        if (access == .read_write) try resize(fd, size);
        const protection: std.os.linux.PROT = switch (access) {
            .read_only => .{ .READ = true },
            .read_write => .{ .READ = true, .WRITE = true },
        };
        const address = std.os.linux.mmap(
            null,
            size,
            protection,
            .{ .TYPE = .SHARED },
            fd,
            0,
        );
        switch (std.os.linux.errno(address)) {
            .SUCCESS => return @as(
                [*]align(std.heap.page_size_min) u8,
                @ptrFromInt(address),
            )[0..size],
            else => |err| return std.posix.unexpectedErrno(err),
        }
    }

    pub fn mapReadOnly(fd: std.os.linux.fd_t, size: usize) ![]align(std.heap.page_size_min) u8 {
        return map(fd, size, .read_only);
    }

    pub fn mapReadWrite(fd: std.os.linux.fd_t, size: usize) ![]align(std.heap.page_size_min) u8 {
        return map(fd, size, .read_write);
    }

    pub fn unmap(memory: []align(std.heap.page_size_min) u8) !void {
        const result = std.os.linux.munmap(memory.ptr, memory.len);
        switch (std.os.linux.errno(result)) {
            .SUCCESS => return,
            else => |err| return std.posix.unexpectedErrno(err),
        }
    }

    pub fn addSeals(fd: std.os.linux.fd_t, seals: u32) !void {
        const result = std.os.linux.fcntl(fd, std.os.linux.F.ADD_SEALS, seals);
        switch (std.os.linux.errno(result)) {
            .SUCCESS => return,
            else => |err| return std.posix.unexpectedErrno(err),
        }
    }

    pub fn duplicate(fd: std.os.linux.fd_t) !std.os.linux.fd_t {
        return std.posix.dup(fd);
    }

    pub fn close(fd: std.os.linux.fd_t) void {
        if (fd >= 0) _ = std.os.linux.close(fd);
    }
};

pub const socket = struct {
    pub const DatagramOptions = struct {
        reuse_address: bool = true,
        reuse_port: bool = false,
        nonblocking: bool = true,
        close_on_exec: bool = true,
        receive_buffer_size: ?c_int = 1024 * 1024,
        send_buffer_size: ?c_int = null,
        allow_broadcast: bool = false,
    };

    pub const DatagramSocket = struct {
        fd: std.os.linux.fd_t,
        local_address: std.Io.net.Ip4Address,

        pub fn open(local_address: std.Io.net.Ip4Address, options: DatagramOptions) !DatagramSocket {
            var socket_type: u32 = std.os.linux.SOCK.DGRAM;
            if (options.nonblocking) socket_type |= std.os.linux.SOCK.NONBLOCK;
            if (options.close_on_exec) socket_type |= std.os.linux.SOCK.CLOEXEC;

            const result = std.os.linux.socket(std.os.linux.AF.INET, socket_type, std.os.linux.IPPROTO.UDP);
            const fd: std.os.linux.fd_t = switch (std.os.linux.errno(result)) {
                .SUCCESS => @intCast(result),
                else => |err| return std.posix.unexpectedErrno(err),
            };
            errdefer _ = std.os.linux.close(fd);

            const yes: c_int = 1;
            if (options.reuse_address) {
                try std.posix.setsockopt(fd, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, std.mem.asBytes(&yes));
            }
            if (options.reuse_port and @hasDecl(std.posix.SO, "REUSEPORT")) {
                try std.posix.setsockopt(fd, std.posix.SOL.SOCKET, std.posix.SO.REUSEPORT, std.mem.asBytes(&yes));
            }
            if (options.allow_broadcast) {
                try std.posix.setsockopt(fd, std.posix.SOL.SOCKET, std.posix.SO.BROADCAST, std.mem.asBytes(&yes));
            }
            if (options.receive_buffer_size) |size| {
                try std.posix.setsockopt(fd, std.posix.SOL.SOCKET, std.posix.SO.RCVBUF, std.mem.asBytes(&size));
            }
            if (options.send_buffer_size) |size| {
                try std.posix.setsockopt(fd, std.posix.SOL.SOCKET, std.posix.SO.SNDBUF, std.mem.asBytes(&size));
            }

            const socket_address = toSockaddr(local_address);
            const bind_result = std.os.linux.bind(
                fd,
                @ptrCast(&socket_address),
                @sizeOf(std.os.linux.sockaddr.in),
            );
            switch (std.os.linux.errno(bind_result)) {
                .SUCCESS => {},
                else => |err| return std.posix.unexpectedErrno(err),
            }

            return .{ .fd = fd, .local_address = local_address };
        }

        pub fn bindAny(port: u16, options: DatagramOptions) !DatagramSocket {
            return open(.unspecified(port), options);
        }

        pub fn deinit(self: *DatagramSocket) void {
            if (self.fd >= 0) _ = std.os.linux.close(self.fd);
            self.* = undefined;
        }

        pub fn sendTo(self: *DatagramSocket, destination: std.Io.net.Ip4Address, bytes: []const u8) !usize {
            const address = toSockaddr(destination);
            const result = std.os.linux.sendto(
                self.fd,
                bytes.ptr,
                bytes.len,
                0,
                @ptrCast(&address),
                @sizeOf(std.os.linux.sockaddr.in),
            );
            return switch (std.os.linux.errno(result)) {
                .SUCCESS => @intCast(result),
                .INTR => self.sendTo(destination, bytes),
                .AGAIN => error.WouldBlock,
                else => |err| std.posix.unexpectedErrno(err),
            };
        }

        pub fn receiveFrom(
            self: *DatagramSocket,
            buffer: []u8,
            source: *std.Io.net.Ip4Address,
        ) !?usize {
            var address: std.os.linux.sockaddr.in = undefined;
            var address_length: std.os.linux.socklen_t = @sizeOf(std.os.linux.sockaddr.in);
            const result = std.os.linux.recvfrom(
                self.fd,
                buffer.ptr,
                buffer.len,
                0,
                @ptrCast(&address),
                &address_length,
            );
            return switch (std.os.linux.errno(result)) {
                .SUCCESS => blk: {
                    source.* = fromSockaddr(address);
                    break :blk @intCast(result);
                },
                .INTR, .AGAIN => null,
                .CONNRESET => error.ConnectionResetByPeer,
                .NETDOWN => error.NetworkDown,
                .NOMEM, .NOBUFS => error.SystemResources,
                else => |err| std.posix.unexpectedErrno(err),
            };
        }
    };

    pub fn toSockaddr(address: std.Io.net.Ip4Address) std.os.linux.sockaddr.in {
        return .{
            .family = std.os.linux.AF.INET,
            .port = @byteSwap(address.port),
            .addr = @bitCast(address.bytes),
            .zero = @splat(0),
        };
    }

    pub fn fromSockaddr(address: std.os.linux.sockaddr.in) std.Io.net.Ip4Address {
        return .{
            .bytes = @bitCast(address.addr),
            .port = @byteSwap(address.port),
        };
    }
};

pub const unix = struct {
    pub const max_passed_descriptor_count: usize = 8;
    const max_control_bytes: usize = cmsgSpace(max_passed_descriptor_count * @sizeOf(std.os.linux.fd_t));

    pub const PeerCredentials = extern struct {
        pid: u32,
        uid: u32,
        gid: u32,
    };

    const LinuxPeerCredentials = extern struct {
        pid: std.os.linux.pid_t,
        uid: std.os.linux.uid_t,
        gid: std.os.linux.gid_t,
    };

    pub const ReceivedDescriptors = struct {
        values: [max_passed_descriptor_count]std.os.linux.fd_t = @splat(-1),
        count: usize = 0,

        pub fn slice(self: *ReceivedDescriptors) []std.os.linux.fd_t {
            return self.values[0..self.count];
        }

        pub fn closeAll(self: *ReceivedDescriptors) void {
            for (self.values[0..self.count]) |fd| {
                if (fd >= 0)
                    _ = std.os.linux.close(fd);
            }
            self.* = .{};
        }
    };

    pub const Listener = struct {
        fd: std.os.linux.fd_t,
        path: []const u8,

        /// Configuration for a Unix domain socket listener.
        pub const ListenerOptions = struct {
            /// Maximum number of pending connections waiting to be accepted.
            backlog: u31 = 128,

            /// Recursively create missing parent directories before binding the socket.
            /// Existing directories are preserved and are not removed during cleanup.
            path_create: bool = false,

            /// Permissions for newly created parent directories.
            /// Subject to the process umask. Existing directories are not modified.
            path_mode: std.os.linux.mode_t = 0o750,

            /// Optional user ID assigned to the socket after binding.
            /// Null retains the ownership assigned when the socket is created.
            socket_owner: ?std.os.linux.uid_t = null,

            /// Optional group ID assigned to the socket after binding.
            /// Null retains the group assigned when the socket is created.
            socket_group: ?std.os.linux.gid_t = null,

            /// Permissions applied to the socket after binding.
            /// Independent of path_mode and the process umask.
            socket_mode: std.os.linux.mode_t = 0o770,
        };

        pub fn init(path: []const u8, options: ListenerOptions) !Listener {
            if (options.path_create) try createParentPath(path, options.path_mode);
            try unlink(path);

            const fd = try createSeqpacketSocket();
            errdefer _ = std.os.linux.close(fd);

            const address = try makeAddress(path);

            const bind_result = std.os.linux.bind(
                fd,
                @ptrCast(&address),
                addressLength(path),
            );

            switch (std.os.linux.errno(bind_result)) {
                .SUCCESS => {},
                else => |err| return std.posix.unexpectedErrno(err),
            }
            errdefer unlink(path) catch {};

            try setPathMetadata(path, options.socket_owner, options.socket_group, options.socket_mode);
            const listen_result = std.os.linux.listen(fd, options.backlog);

            switch (std.os.linux.errno(listen_result)) {
                .SUCCESS => {},
                else => |err| return std.posix.unexpectedErrno(err),
            }

            return .{
                .fd = fd,
                .path = path,
            };
        }

        pub fn deinit(self: *Listener) void {
            if (self.fd >= 0) _ = std.os.linux.close(self.fd);
            unlink(self.path) catch {};
            self.* = undefined;
        }

        pub fn accept(self: *Listener) !Connection {
            while (true) {
                const result = std.os.linux.accept4(
                    self.fd,
                    null,
                    null,
                    std.os.linux.SOCK.CLOEXEC,
                );
                switch (std.os.linux.errno(result)) {
                    .SUCCESS => return .{ .fd = @intCast(result) },
                    .INTR => continue,
                    .AGAIN => return error.WouldBlock,
                    else => |err| return std.posix.unexpectedErrno(err),
                }
            }
        }
    };

    pub const Connection = struct {
        fd: std.os.linux.fd_t,

        pub fn connect(path: []const u8) !Connection {
            const fd = try createSeqpacketSocket();
            errdefer _ = std.os.linux.close(fd);
            const address = try makeAddress(path);
            const result = std.os.linux.connect(fd, @ptrCast(&address), addressLength(path));
            switch (std.os.linux.errno(result)) {
                .SUCCESS => return .{ .fd = fd },
                .NOENT => return error.SocketNotFound,
                .CONNREFUSED => return error.ConnectionRefused,
                else => |err| return std.posix.unexpectedErrno(err),
            }
        }

        pub fn deinit(self: *Connection) void {
            if (self.fd >= 0) _ = std.os.linux.close(self.fd);
            self.* = undefined;
        }

        pub fn credentials(self: *Connection) !PeerCredentials {
            var creds: LinuxPeerCredentials = undefined;
            var length: std.os.linux.socklen_t = @sizeOf(LinuxPeerCredentials);
            const result = std.os.linux.getsockopt(
                self.fd,
                std.os.linux.SOL.SOCKET,
                std.os.linux.SO.PEERCRED,
                @ptrCast(&creds),
                &length,
            );
            switch (std.os.linux.errno(result)) {
                .SUCCESS => return .{
                    .pid = @intCast(creds.pid),
                    .uid = creds.uid,
                    .gid = creds.gid,
                },
                else => |err| return std.posix.unexpectedErrno(err),
            }
        }

        pub fn send(self: *Connection, bytes: []const u8, descriptors: []const std.os.linux.fd_t) !void {
            if (descriptors.len > max_passed_descriptor_count) {
                return error.TooManyDescriptors;
            }
            var iov = std.posix.iovec_const{ .base = bytes.ptr, .len = bytes.len };
            var control: [max_control_bytes]u8 align(@alignOf(std.os.linux.cmsghdr)) = @splat(0);
            var message: std.os.linux.msghdr_const = .{
                .name = null,
                .namelen = 0,
                .iov = @ptrCast(&iov),
                .iovlen = 1,
                .control = null,
                .controllen = 0,
                .flags = 0,
            };

            if (descriptors.len != 0) {
                const bytes_len = descriptors.len * @sizeOf(std.os.linux.fd_t);
                message.control = &control;
                message.controllen = cmsgSpace(bytes_len);
                const header: *std.os.linux.cmsghdr = @ptrCast(@alignCast(&control));
                header.level = std.os.linux.SOL.SOCKET;
                header.type = std.os.linux.SCM.RIGHTS;
                header.len = cmsgLen(bytes_len);
                const payload: [*]u8 = @ptrCast(header);
                @memcpy(
                    payload[cmsgDataOffset()..][0..bytes_len],
                    std.mem.sliceAsBytes(descriptors),
                );
            }

            var sent: usize = 0;
            while (sent < bytes.len) {
                iov.base = bytes[sent..].ptr;
                iov.len = bytes.len - sent;
                const result = std.os.linux.sendmsg(self.fd, &message, std.os.linux.MSG.NOSIGNAL);
                switch (std.os.linux.errno(result)) {
                    .SUCCESS => {
                        sent += @intCast(result);
                        message.control = null;
                        message.controllen = 0;
                    },
                    .INTR => continue,
                    .PIPE => return error.BrokenPipe,
                    else => |err| return std.posix.unexpectedErrno(err),
                }
            }
        }

        pub fn receive(self: *Connection, bytes: []u8, descriptors: *ReceivedDescriptors) !usize {
            descriptors.* = .{};
            var iov = std.posix.iovec{ .base = bytes.ptr, .len = bytes.len };
            var control: [max_control_bytes]u8 align(@alignOf(std.os.linux.cmsghdr)) = undefined;
            var message: std.os.linux.msghdr = .{
                .name = null,
                .namelen = 0,
                .iov = @ptrCast(&iov),
                .iovlen = 1,
                .control = &control,
                .controllen = control.len,
                .flags = 0,
            };

            while (true) {
                const result = std.os.linux.recvmsg(self.fd, &message, std.os.linux.MSG.CMSG_CLOEXEC);
                switch (std.os.linux.errno(result)) {
                    .SUCCESS => {
                        if (result == 0) return error.ConnectionClosed;
                        try parseDescriptors(&message, descriptors);
                        return @intCast(result);
                    },
                    .INTR => continue,
                    .AGAIN => return error.WouldBlock,
                    .CONNRESET => return error.ConnectionResetByPeer,
                    else => |err| return std.posix.unexpectedErrno(err),
                }
            }
        }

        pub fn exchange(
            self: *Connection,
            request: []const u8,
            send_descriptors: []const std.os.linux.fd_t,
            response: []u8,
            received_descriptors: []std.os.linux.fd_t,
        ) !usize {
            try self.send(request, send_descriptors);
            var received: ReceivedDescriptors = .{};
            errdefer received.closeAll();
            const size = try self.receive(response, &received);
            if (size != response.len) return error.TruncatedMessage;
            if (received.count > received_descriptors.len) {
                return error.DescriptorBufferTooSmall;
            }
            @memcpy(received_descriptors[0..received.count], received.values[0..received.count]);
            return received.count;
        }
    };

    pub fn unlink(path: []const u8) !void {
        var buffer: [std.os.linux.PATH_MAX]u8 = undefined;
        if (path.len + 1 > buffer.len) return error.NameTooLong;
        @memcpy(buffer[0..path.len], path);
        buffer[path.len] = 0;
        const result = std.os.linux.unlink(@ptrCast(&buffer));
        switch (std.os.linux.errno(result)) {
            .SUCCESS, .NOENT => return,
            else => |err| return std.posix.unexpectedErrno(err),
        }
    }

    pub fn cmsgAlign(length: usize) usize {
        const alignment: usize = @sizeOf(usize);
        return (length + alignment - 1) & ~(alignment - 1);
    }

    pub fn cmsgDataOffset() usize {
        return cmsgAlign(@sizeOf(std.os.linux.cmsghdr));
    }

    pub fn cmsgLen(payload_bytes: usize) usize {
        return cmsgDataOffset() + payload_bytes;
    }

    pub fn cmsgSpace(payload_bytes: usize) usize {
        return cmsgDataOffset() + cmsgAlign(payload_bytes);
    }

    fn createSeqpacketSocket() !std.os.linux.fd_t {
        const result = std.os.linux.socket(
            std.os.linux.AF.UNIX,
            std.os.linux.SOCK.SEQPACKET | std.os.linux.SOCK.CLOEXEC,
            0,
        );
        return switch (std.os.linux.errno(result)) {
            .SUCCESS => @intCast(result),
            else => |err| std.posix.unexpectedErrno(err),
        };
    }

    fn makeAddress(path: []const u8) !std.os.linux.sockaddr.un {
        if (path.len >= @sizeOf(@FieldType(std.os.linux.sockaddr.un, "path"))) {
            return error.NameTooLong;
        }
        var address: std.os.linux.sockaddr.un = .{
            .family = std.os.linux.AF.UNIX,
            .path = @splat(0),
        };
        @memcpy(address.path[0..path.len], path);
        return address;
    }

    fn createParentPath(
        socket_path: []const u8,
        mode: std.os.linux.mode_t,
    ) !void {
        const parent = std.fs.path.dirname(socket_path) orelse return;

        var buffer: [std.os.linux.PATH_MAX]u8 = undefined;
        if (parent.len + 1 > buffer.len) return error.NameTooLong;

        @memcpy(buffer[0..parent.len], parent);
        buffer[parent.len] = 0;

        for (0..parent.len + 1) |i| {
            if (i == 0 or (i < parent.len and parent[i] != '/')) continue;

            const original = buffer[i];
            buffer[i] = 0;

            const result = std.os.linux.mkdir(@ptrCast(&buffer), mode);
            buffer[i] = original;

            switch (std.os.linux.errno(result)) {
                .SUCCESS, .EXIST => {},
                .ACCES => return error.AccessDenied,
                .PERM => return error.PermissionDenied,
                .NOTDIR => return error.NotDir,
                else => |err| return std.posix.unexpectedErrno(err),
            }
        }
    }

    fn addressLength(path: []const u8) std.os.linux.socklen_t {
        return @intCast(@offsetOf(std.os.linux.sockaddr.un, "path") + path.len + 1);
    }

    fn parseDescriptors(
        message: *const std.os.linux.msghdr,
        output: *ReceivedDescriptors,
    ) !void {
        var offset: usize = 0;
        const control: [*]const u8 = @ptrCast(message.control orelse return);
        while (offset + @sizeOf(std.os.linux.cmsghdr) <= message.controllen) {
            const header: *const std.os.linux.cmsghdr = @ptrCast(@alignCast(control + offset));
            if (header.len < cmsgDataOffset()) return error.InvalidControlMessage;
            const payload_bytes = header.len - cmsgDataOffset();
            if (header.level == std.os.linux.SOL.SOCKET and header.type == std.os.linux.SCM.RIGHTS) {
                if (payload_bytes % @sizeOf(std.os.linux.fd_t) != 0) {
                    return error.InvalidDescriptorPayload;
                }
                const count = payload_bytes / @sizeOf(std.os.linux.fd_t);
                if (output.count + count > output.values.len) {
                    return error.TooManyDescriptors;
                }
                const source = control[offset + cmsgDataOffset() ..][0..payload_bytes];
                const values = std.mem.bytesAsSlice(std.os.linux.fd_t, source);
                @memcpy(output.values[output.count..][0..count], values);
                output.count += count;
            }
            offset += cmsgAlign(header.len);
        }
    }

    fn setPathMetadata(
        path: []const u8,
        owner: ?std.os.linux.uid_t,
        group: ?std.os.linux.gid_t,
        mode: std.os.linux.mode_t,
    ) !void {
        var buffer: [std.os.linux.PATH_MAX]u8 = undefined;

        if (path.len + 1 > buffer.len) {
            return error.NameTooLong;
        }

        @memcpy(buffer[0..path.len], path);
        buffer[path.len] = 0;

        const path_z: [*:0]const u8 = @ptrCast(&buffer);

        if (owner != null or group != null) {
            const uid = owner orelse ~@as(std.os.linux.uid_t, 0);
            const gid = group orelse ~@as(std.os.linux.gid_t, 0);
            const result = std.os.linux.chown(path_z, uid, gid);

            switch (std.os.linux.errno(result)) {
                .SUCCESS => {},
                .ACCES => return error.AccessDenied,
                .PERM => return error.PermissionDenied,
                else => |err| return std.posix.unexpectedErrno(err),
            }
        }

        const chmod_result = std.os.linux.chmod(path_z, mode);

        switch (std.os.linux.errno(chmod_result)) {
            .SUCCESS => {},
            .ACCES => return error.AccessDenied,
            .PERM => return error.PermissionDenied,
            else => |err| return std.posix.unexpectedErrno(err),
        }
    }
};
