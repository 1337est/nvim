//! Sockman 0.0.1 - Protocol ABI and Procedural API.
//! Target source dialect: Zig 0.17.0-dev.1460+9a9d8adda.
//! Initial development release. Version 0.1.0 marks the first usable minor release.
//!
//! OVERVIEW
//! - Defines a shared protocol for Daemons, Namespaces, Streams, and Objects.
//! - Provides binary-compatible records, shared-memory layouts, message framing,
//!   identity management, permissions, and procedural operations.
//! - Supports independent implementations communicating through a common ABI.
//! - Separates protocol definitions from runtime implementation and execution.
//! - Does not prescribe a particular transport, event loop, or process architecture.
//! - Multiple Daemons may operate independently, each with its own AddressSpace.
//!
//! IMPLEMENTATION MODEL
//! - Daemon implementations own their AddressSpace, allocation, registration,
//!   authorization, synchronization, request execution, and resource reclamation.
//! - Namespace implementations establish logical domains, identities, and access
//!   relationships within a Daemon.
//! - Stream implementations produce, consume, and manage application-defined data
//!   and behavior within their registered Namespace.
//! - Objects are passive data records belonging to exactly one Stream.
//! - Implementations may operate in separate processes while sharing protocol
//!   identities, handles, permissions, and data through their Daemon.
//! - Implementors supply all OS integration, allocation, I/O, transport,
//!   scheduling, command execution, and application-specific behavior.
//! - The ABI/API contains no std/builtin imports, allocator, OS handles,
//!   global runtime state, or process-local pointers in transmitted records.
//!
//! ENTITY / IDENTITY MODEL
//! - One Daemon descriptor anchors each AddressSpace and its lifetime epoch.
//! - Namespace identity.id is nonzero and unique within its Daemon.
//! - Stream identity.id is nonzero and unique within its Namespace.
//! - Object identity.id is its Stream-local slot, 0..255, including zero.
//! - Names are descriptive and are not required to be unique.
//! - Namespace and Stream logical identities are not physical table indices.
//! - Handles identify runtime slots and include generation information.
//! - Handles are local to their Daemon and invalid across incompatible lifetimes.
//! - The implementor explicitly initializes the Daemon; the protocol does not
//!   implicitly create Namespaces, Streams, or Objects.
//!
//! ADDRESS SPACE / OBJECT MAPPING
//! - Each Daemon owns an independent AddressSpace containing entity metadata
//!   and 256 MiB of fixed-capacity Object data storage.
//! - Up to 8 Namespaces and 256 globally indexed Streams exist per Daemon.
//! - Each Stream slot owns 256 Object slots and a fixed 1-MiB data region.
//! - Each Object slot provides 4096 bytes of storage.
//! - Object storage is addressed through validated offsets, not wire pointers.
//! - Handle(Object): [generation:16][global Stream slot:8][Object slot:8].
//! - global_object_index = (stream_slot << 8) | object_slot.
//! - ObjectAddress.offset = global_object_index << 12, relative to object_data.
//! - Stream slots are global; Namespace membership is stored in Stream.namespace.
//! - Object.stream preserves the complete parent Stream handle and generation.
//! - Object generation and Stream generation are independent.
//! - Releasing an Object advances its slot generation or retires it at 0xffff.
//! - Object generations and retired slots survive reuse of their Stream slot.
//! - Object data pages are initialized when allocated, not when the entire
//!   AddressSpace is initialized.
//!
//! ABI PROFILE
//! - Requires LP64, 8-bit bytes, little endian, and 8-byte u64 alignment.
//! - Extern records follow the native target C layout.
//! - The wire format is not cross-endian or architecture-independent serialization.
//! - C-compatible records use explicitly sized fields and reserved storage.
//! - C headers use matching-width integers rather than C enums or bitfields.
//! - ObjectSet contains four u64 words representing 256 Stream-local Object slots.
//! - Reserved fields must be zero when transmitted and validated when received.
//! - Zig methods, generics, error unions, and local procedural state are API
//!   helpers rather than independently exported C ABI functions.
//!
//! PROCEDURAL API
//! - Provides initialization, discovery, acquisition, reading, writing,
//!   publication, subscription, administration, control, and release operations.
//! - Session and Call maintain process-local connection and operation state.
//! - Procedural functions prepare, validate, assemble, and interpret messages.
//! - Preparing an operation does not execute it or modify authoritative state.
//! - The caller owns all Session, Call, message, and reassembly storage.
//! - The caller supplies transport operations and executes prepared exchanges.
//! - Typed Object operations require supported fixed-layout representations;
//!   byte-oriented operations support application-defined serialized data.
//! - Protocol validation establishes representation correctness, not authority.
//!
//! AUTHORITY / PERMISSIONS
//! - The Daemon implementation is authoritative for allocation, identity
//!   uniqueness, access grants, resource lifetime, and operation authorization.
//! - Namespaces and Streams may establish explicitly authorized relationships
//!   with other Namespaces, Streams, and Daemons.
//! - Permission lists represent access relationships, not owned-child inventories.
//! - Access to a container does not implicitly authorize unrelated descendants.
//! - ObjectSet selects Object slots but does not grant access or establish
//!   transactional boundaries.
//! - Acquire establishes session-scoped access; it does not create permissions.
//! - Control carries application-defined commands to an authorized target.
//! - The target implementor is responsible for command execution and completion.
//! - Objects cannot initiate protocol Requests or Events.
//!
//! SYNCHRONIZATION / CONCURRENCY
//! - Implementors synchronize all shared table access, Object data access,
//!   allocation, publication, and reclamation.
//! - Generations and revisions identify state; they are not synchronization
//!   primitives, locks, leases, or memory barriers.
//! - Broker-serialized reads and writes provide the baseline access model.
//! - Shared-memory mapping does not independently grant read or write authority.
//! - A whole-arena mapping does not provide per-Object memory isolation.
//! - Direct memory access requires explicit authorization and synchronization
//!   guarantees supplied by the implementation.
//!
//! SESSION / TRANSPORT
//! - Bootstrap uses operation=.none, empty endpoints, and zero session/epoch.
//! - Successful bootstrap establishes a Daemon identity, session, epoch,
//!   and the corresponding AddressSpace layout.
//! - The documented local descriptor-passing transport attaches one arena fd
//!   to a successful bootstrap response and no other response.
//! - Transport establishment, authentication, descriptor passing, memory mapping,
//!   and connection lifecycle management belong to the implementor.
//! - Subsequent operations require a valid session, epoch, and target handle.
//! - Empty Request.from identifies the authenticated connection, not authority.
//! - Clients cannot impersonate the Daemon through Request.from.
//! - Disconnects and epoch changes invalidate associated handles and caches.
//!
//! MESSAGING / DELIVERY
//! - Messages contain versioned headers, typed bodies, and bounded payloads.
//! - Transport implementations must preserve reliable, ordered frame delivery.
//! - Fragmented messages must be completely reassembled before execution.
//! - Each complete Request produces exactly one complete Response.
//! - Responses identify operation results; successful control completion means
//!   the target operation has completed, not merely been queued.
//! - Writes update Object contents and revisions; publication is explicit.
//! - Subscriptions select events and Objects independently of authorization.
//! - Events are coalescible state-change notifications, not command results.
//! - Events do not provide durable replay, reliable update history, or snapshots.
//! - Automatic replay, exactly-once execution, persistence, and crash recovery
//!   are not guaranteed by the protocol.
//! - Implementors may provide additional guarantees without changing the ABI.
const Sockman = @This();

/// Fixed protocol layout, not runtime-tunable allocation options.
pub const Layout = struct {
    pub const name_bytes: usize = 64;
    pub const namespace_capacity: usize = 8;
    pub const streams_per_namespace: usize = 32;
    pub const stream_capacity: usize = 256;
    pub const objects_per_stream: usize = 256;
    pub const object_capacity: usize = stream_capacity * objects_per_stream;
    pub const object_bytes: usize = 4096;
    pub const stream_bytes: usize = objects_per_stream * object_bytes;
    pub const object_data_bytes: usize = object_capacity * object_bytes; // 256 MiB per Daemon
};

/// "SKMN" in this protocol's little-endian byte representation.
pub const Magic = extern struct {
    value: u32 = 0x4E_4D_4B_53,
};

pub const Version = extern struct {
    major: u8 = 0,
    minor: u8 = 0,
    patch: u8 = 1,
    reserved: u8 = 0,
};

/// Response codes, not values stored in identity or handle fields.
/// Unknown values survive decoding; 0x1000..0xffff are application codes.
pub const Code = enum(u16) {
    ok = 0,
    invalid = 1,
    unsupported = 2,
    not_found = 3,
    already_exists = 4,
    permission_denied = 5,
    busy = 6,
    internal_error = 7,
    resource_exhausted = 8,
    _,
};

/// Exactly one action per Request. Its numeric value is its permission bit.
pub const Operation = enum(u16) {
    none = 0, // bootstrap only
    discover = 1 << 0,
    acquire = 1 << 1,
    read = 1 << 2,
    write = 1 << 3,
    subscribe = 1 << 4,
    control = 1 << 5,
    administer = 1 << 6,
    publish = 1 << 7,
    create = 1 << 8,
    release = 1 << 9,
    _,

    /// Requires exactly one currently supported permission-bearing operation.
    pub fn valid(self: Operation) error{InvalidOperation}!void {
        const value = @backingInt(self);
        if (value == 0 or (value & (value - 1)) != 0 or
            (value & ~@as(u16, 0x03ff)) != 0) return error.InvalidOperation;
    }
};

pub const Permission = struct {
    pub const none: u16 = 0;
    pub const read_only: u16 = add(none, .{ .discover, .acquire, .read, .subscribe });
    pub const producer: u16 = add(none, .{ .discover, .read, .write, .publish });
    pub const all: u16 = add(none, .{
        .discover, .acquire,    .read,    .write,  .subscribe,
        .control,  .administer, .publish, .create, .release,
    });

    pub fn add(permissions: u16, comptime operations: anytype) u16 {
        var result = permissions;
        inline for (operations) |operation| {
            const typed: Operation = operation;
            result |= @backingInt(typed);
        }
        return result;
    }

    pub fn remove(permissions: u16, comptime operations: anytype) u16 {
        var result = permissions;
        inline for (operations) |operation| {
            const typed: Operation = operation;
            result &= ~@backingInt(typed);
        }
        return result;
    }

    pub fn contains(permissions: u16, operation: Operation) bool {
        operation.valid() catch return false;
        return (permissions & @backingInt(operation)) == @backingInt(operation);
    }

    pub fn init(
        comptime From: type,
        comptime To: type,
        from: Handle(From),
        to: Handle(To),
        permissions: u16,
    ) PermissionInit(From, To) {
        return .{ .from = from, .to = to, .permissions = permissions };
    }
};

pub fn PermissionInit(comptime From: type, comptime To: type) type {
    return extern struct {
        pub const from_type = From;
        pub const to_type = To;
        from: Handle(From) = .{},
        to: Handle(To) = .{},
        permissions: u16 = Permission.none,
        reserved: u16 = 0,
    };
}

/// Runtime entity kinds. Daemon is a singleton slot in each AddressSpace.
pub const HandleType = enum(u16) {
    none = 0,
    daemon = 1,
    namespace = 2,
    stream = 3,
    object = 4,
    _,
};

/// Typed runtime reference, never a logical identity or a process-local pointer.
/// All handles: upper 16 bits = slot generation; lower 16 bits = table index.
/// Object handles: lower 16 bits = [Stream slot:8][local Object slot:8].
pub fn Handle(comptime T: type) type {
    return extern struct {
        const Self = @This();
        pub const target_type = T;
        value: u32 = 0,

        /// Structural construction only. Does not look up or allocate a slot.
        pub fn init(index_value: u16, generation_value: u16) Self {
            if (generation_value == 0 or @as(usize, index_value) >= tableCapacity(T)) return .{};
            return .{ .value = (@as(u32, generation_value) << 16) | index_value };
        }

        /// generation_value belongs to the Object SLOT, not its parent Stream.
        pub fn initObject(stream: Handle(Stream), object_index: u8, generation_value: u16) Self {
            if (T != Object) @compileError("initObject is only available for Handle(Object)");
            if (!stream.valid()) return .{};
            return init((stream.index() << 8) | @as(u16, object_index), generation_value);
        }

        pub fn index(self: Self) u16 {
            return @truncate(self.value);
        }

        pub fn generation(self: Self) u16 {
            return @truncate(self.value >> 16);
        }

        /// Shape only: generation is nonzero and table index is in range.
        pub fn valid(self: Self) bool {
            return self.generation() != 0 and @as(usize, self.index()) < tableCapacity(T);
        }

        pub fn streamIndex(self: Self) u8 {
            if (T != Object) @compileError("streamIndex is only available for Handle(Object)");
            return @truncate(self.value >> 8);
        }

        pub fn objectIndex(self: Self) u8 {
            if (T != Object) @compileError("objectIndex is only available for Handle(Object)");
            return @truncate(self.value);
        }
    };
}

pub const HandleReference = extern struct {
    type: HandleType = .none,
    reserved: u16 = 0,
    handle: u32 = 0,

    pub fn init(comptime T: type, value: Handle(T)) HandleReference {
        return .{ .type = handleType(T), .handle = value.value };
    }

    pub fn empty(self: HandleReference) bool {
        return self.type == .none and self.reserved == 0 and self.handle == 0;
    }

    /// Returns true for structurally valid references; not a live-slot check.
    pub fn valid(self: HandleReference) bool {
        if (self.reserved != 0 or (self.handle >> 16) == 0) return false;
        const index = self.handle & 0xffff;
        return switch (self.type) {
            .daemon => index == 0,
            .namespace => index < Layout.namespace_capacity,
            .stream => index < Layout.stream_capacity,
            .object => true, // all 16-bit Object table indices are representable
            else => false,
        };
    }

    pub fn typed(self: HandleReference, comptime T: type) ?Handle(T) {
        if (self.type != handleType(T) or !self.valid()) return null;
        return .{ .value = self.handle };
    }
};

/// 256 Stream-local Object selectors, represented as four C-compatible words.
/// Bit i selects Object identity/index i, NOT a global Object slot or a handle.
/// The owning Stream handle, including its generation, supplies the scope.
pub const ObjectSet = extern struct {
    words: [4]u64 = @splat(0),

    pub const none: ObjectSet = .{};
    pub const all: ObjectSet = .{ .words = @splat(~@as(u64, 0)) };

    /// Compile-time tuple/array of u8 indices or explicitly typed enum values.
    /// Example: ObjectSet.init(.{ Objects.foo, Objects.bar, @as(u8, 255) }).
    pub fn init(comptime indices: anytype) ObjectSet {
        return none.add(indices);
    }

    pub fn add(self: ObjectSet, comptime indices: anytype) ObjectSet {
        var result = self;
        inline for (indices) |index| result.set(objectIndexValue(index));
        return result;
    }

    pub fn remove(self: ObjectSet, comptime indices: anytype) ObjectSet {
        var result = self;
        inline for (indices) |index| result.unset(objectIndexValue(index));
        return result;
    }

    /// Runtime single-bit updates. Caller synchronizes shared instances.
    pub fn set(self: *ObjectSet, index: u8) void {
        const shift: u6 = @truncate(index);
        self.words[index >> 6] |= @as(u64, 1) << shift;
    }

    pub fn unset(self: *ObjectSet, index: u8) void {
        const shift: u6 = @truncate(index);
        self.words[index >> 6] &= ~(@as(u64, 1) << shift);
    }

    pub fn contains(self: ObjectSet, index: u8) bool {
        const shift: u6 = @truncate(index);
        return (self.words[index >> 6] & (@as(u64, 1) << shift)) != 0;
    }

    pub fn isEmpty(self: ObjectSet) bool {
        return (self.words[0] | self.words[1] | self.words[2] | self.words[3]) == 0;
    }

    pub fn eql(self: ObjectSet, other: ObjectSet) bool {
        for (self.words, other.words) |a, b| if (a != b) return false;
        return true;
    }

    pub fn intersects(self: ObjectSet, other: ObjectSet) bool {
        for (self.words, other.words) |a, b| if ((a & b) != 0) return true;
        return false;
    }

    pub fn containsAll(self: ObjectSet, other: ObjectSet) bool {
        for (self.words, other.words) |a, b| if ((a & b) != b) return false;
        return true;
    }

    pub fn unionWith(self: ObjectSet, other: ObjectSet) ObjectSet {
        var result: ObjectSet = .{};
        for (&result.words, self.words, other.words) |*out, a, b| out.* = a | b;
        return result;
    }

    pub fn intersection(self: ObjectSet, other: ObjectSet) ObjectSet {
        var result: ObjectSet = .{};
        for (&result.words, self.words, other.words) |*out, a, b| out.* = a & b;
        return result;
    }

    pub fn difference(self: ObjectSet, other: ObjectSet) ObjectSet {
        var result: ObjectSet = .{};
        for (&result.words, self.words, other.words) |*out, a, b| out.* = a & ~b;
        return result;
    }

    pub fn count(self: ObjectSet) u16 {
        var total: u16 = 0;
        for (self.words) |word| total += @as(u16, @popCount(word));
        return total;
    }

    pub fn iterator(self: ObjectSet) Iterator {
        return .{ .words = self.words };
    }

    /// Visits selected indices in ascending order. Iterates a local copy.
    pub const Iterator = struct {
        words: [4]u64,
        word_index: usize = 0,

        pub fn next(self: *Iterator) ?u8 {
            while (self.word_index < self.words.len) {
                const word = self.words[self.word_index];
                if (word != 0) {
                    const bit: usize = @intCast(@ctz(word));
                    self.words[self.word_index] = word & (word - 1);
                    return @intCast(self.word_index * 64 + bit);
                }
                self.word_index += 1;
            }
            return null;
        }
    };
};

/// Fixed-capacity movable metadata. Never use for handle-addressed entity slots.
pub fn List(comptime T: type, comptime max_capacity: usize) type {
    if (max_capacity > 65535) @compileError("List capacity exceeds u16 length");
    return extern struct {
        const Self = @This();
        pub const capacity: usize = max_capacity;
        len: u16 = 0,
        reserved: [6]u8 = @splat(0),
        items: [max_capacity]T = @splat(.{}),

        pub fn valid(self: *const Self) bool {
            return self.len <= max_capacity and zeroBytes(&self.reserved);
        }

        /// Caller validates metadata and holds lifetime/concurrency protection.
        pub fn slice(self: *Self) []T {
            return self.items[0..self.len];
        }

        pub fn sliceConst(self: *const Self) []const T {
            return self.items[0..self.len];
        }

        pub fn append(self: *Self, item: T) bool {
            const index: usize = self.len;
            if (index >= max_capacity) return false;
            self.items[index] = item;
            self.len += 1;
            return true;
        }

        pub fn swapRemove(self: *Self, index: usize) ?T {
            const len: usize = self.len;
            if (len > max_capacity or index >= len) return null;
            const removed = self.items[index];
            self.items[index] = self.items[len - 1];
            self.items[len - 1] = .{};
            self.len -= 1;
            return removed;
        }

        pub fn clear(self: *Self) void {
            self.items = @splat(.{});
            self.len = 0;
        }
    };
}

/// Daemon/Namespace/Stream IDs are nonzero and scoped by their parent.
/// Object IDs equal the local Object slot: 0..255, including zero.
/// All identities use the same representation, but validity depends on entity kind.
pub const Identity = extern struct {
    id: u64 = 0,
    name: [Layout.name_bytes]u8 = @splat(0),

    /// Creates a zero-padded name. Use validFor() for entity-specific ID rules.
    pub fn init(id: u64, name: []const u8) ?Identity {
        if (name.len > Layout.name_bytes) return null;
        var result: Identity = .{ .id = id };
        @memcpy(result.name[0..name.len], name);
        return result;
    }

    pub fn validFor(self: Identity, kind: HandleType) bool {
        return switch (kind) {
            .daemon, .namespace, .stream => self.id != 0,
            .object => self.id < Layout.objects_per_stream,
            else => false,
        };
    }
};

/// Shared Sockman Daemon descriptor. Runtime/process-local state is not stored here.
/// The host explicitly initializes this singleton before admitting connections.
/// Daemon slot 0 has its own nonzero generation; epoch scopes the entire arena.
pub const Daemon = extern struct {
    identity: Identity = .{},
    epoch: u64 = 0,
    pid: u64 = 0,

    pub fn valid(self: *const Daemon) bool {
        return self.identity.validFor(.daemon) and self.epoch != 0 and self.pid != 0;
    }
};

/// Namespace identity is unique within its Daemon, not across all daemons.
/// The lists below are explicit access grants, NOT child inventories.
pub const Namespace = extern struct {
    identity: Identity = .{},
    daemon: Handle(Daemon) = .{},
    reserved: u32 = 0,
    daemons: List(PermissionInit(@This(), Daemon), 1) = .{},
    reserved2: u32 = 0,
    namespaces: List(PermissionInit(@This(), @This()), 8) = .{},
    streams: List(PermissionInit(@This(), Stream), 32) = .{},
    pid: u64 = 0,
};

/// Stream identity is unique within its Namespace.
/// Its GLOBAL table slot selects its fixed 256-Object / 1-MiB region.
pub const Stream = extern struct {
    identity: Identity = .{},
    namespace: Handle(Namespace) = .{},
    reserved: u32 = 0,
    daemons: List(PermissionInit(@This(), Daemon), 1) = .{},
    reserved2: u32 = 0,
    namespaces: List(PermissionInit(@This(), Namespace), 8) = .{},
    streams: List(PermissionInit(@This(), @This()), 32) = .{},
    objects: List(PermissionInit(@This(), Object), 256) = .{},
    pid: u64 = 0,
};

/// Object identity.id equals its Stream-local slot, 0..255.
/// Full parent handles must agree with the fixed physical slot assignment.
pub const Object = extern struct {
    identity: Identity = .{},
    namespace: Handle(Namespace) = .{},
    stream: Handle(Stream) = .{},
    format: Format = .bytes,
    size: u16 = 0,
    min_size: u16 = 0,
    max_size: u16 = Layout.object_bytes,
    pid: u64 = 0,
    revision: u64 = 0, // broker-owned; not a seqlock
    published_at_ns: i64 = 0,

    pub const Format = enum(u16) {
        bytes = 0,
        unsigned = 1,
        signed = 2,
        float = 3,
        text = 4,
        _, // application interpretation; bytes remain opaque to the broker
    };
};

/// Offset into AddressSpace.object_data. Offset zero is a VALID address.
/// Bits 27..20 = Stream slot; 19..12 = Object slot; 11..0 = byte offset.
pub const ObjectAddress = extern struct {
    offset: u32 = 0,

    pub fn init(stream_index: u8, object_index: u8, byte_offset: u16) ?ObjectAddress {
        if (byte_offset >= Layout.object_bytes) return null;
        return .{ .offset = (@as(u32, stream_index) << 20) |
            (@as(u32, object_index) << 12) | @as(u32, byte_offset) };
    }

    /// Structural address calculation only. AddressSpace.objectAddress also
    /// validates live Object and full parent generations.
    pub fn fromHandle(handle: Handle(Object)) ?ObjectAddress {
        if (!handle.valid()) return null;
        return .{ .offset = @as(u32, handle.index()) << 12 };
    }

    pub fn valid(self: ObjectAddress) bool {
        return self.offset < Layout.object_data_bytes;
    }

    /// Validate arbitrary wire addresses before extracting components.
    pub fn streamIndex(self: ObjectAddress) u8 {
        return @truncate(self.offset >> 20);
    }

    pub fn objectIndex(self: ObjectAddress) u8 {
        return @truncate(self.offset >> 12);
    }

    pub fn byteOffset(self: ObjectAddress) u12 {
        return @truncate(self.offset);
    }
};

pub const SlotState = enum(u16) {
    free = 0,
    active = 1,
    retired = 2,
    _,
};

/// Never move a Slot. Preserve generations even when its parent is destroyed.
/// Retire exhausted generations instead of wrapping them back to 1.
pub fn Slot(comptime T: type) type {
    return extern struct {
        generation: u16 = 0,
        state: SlotState = .free,
        reserved: u32 = 0,
        value: T = .{},
    };
}

/// Stable storage. get/getConst check this slot only, not ownership or parents.
/// Prefer AddressSpace.get* when validating a complete entity relationship.
pub fn Table(comptime T: type, comptime max_capacity: usize) type {
    if (max_capacity > 65536) @compileError("Table capacity exceeds u16 handle index");
    return extern struct {
        const Self = @This();
        pub const capacity: usize = max_capacity;
        slots: [max_capacity]Slot(T) = @splat(.{}),

        pub fn get(self: *Self, handle: Handle(T)) ?*T {
            return @constCast(self.getConst(handle) orelse return null);
        }

        pub fn getConst(self: *const Self, handle: Handle(T)) ?*const T {
            if (!handle.valid()) return null;
            const index: usize = handle.index();
            if (index >= max_capacity) return null;
            const slot = &self.slots[index];
            if (slot.reserved != 0 or slot.state != .active or
                slot.generation != handle.generation()) return null;
            return &slot.value;
        }
    };
}

/// One Daemon shared-memory arena: entity catalog plus 256 MiB Object storage.
/// Multiple Daemons may exist as independent arenas when more capacity is needed.
/// Host initializes all metadata before Daemon runtime initialization.
/// Do not eagerly initialize object_data; zero each Object page on creation.
pub const AddressSpace = extern struct {
    daemon: Slot(Daemon),
    namespaces: Table(Namespace, Layout.namespace_capacity),
    streams: Table(Stream, Layout.stream_capacity),
    objects: Table(Object, Layout.object_capacity),
    data_padding: [data_padding_bytes]u8,
    object_data: [Layout.object_capacity][Layout.object_bytes]u8,

    pub const data_padding_bytes: usize = (4096 - ((@sizeOf(Slot(Daemon)) +
        @sizeOf(Table(Namespace, Layout.namespace_capacity)) +
        @sizeOf(Table(Stream, Layout.stream_capacity)) +
        @sizeOf(Table(Object, Layout.object_capacity))) % 4096)) % 4096;

    /// All get/find/contains methods require external synchronization.
    /// Returning a pointer neither pins lifetime nor grants access.
    pub fn daemonHandle(self: *const AddressSpace) ?Handle(Daemon) {
        const handle = Handle(Daemon).init(0, self.daemon.generation);
        _ = self.getDaemonConst(handle) orelse return null;
        return handle;
    }

    pub fn getDaemonConst(self: *const AddressSpace, handle: Handle(Daemon)) ?*const Daemon {
        if (!handle.valid() or self.daemon.state != .active or self.daemon.reserved != 0 or
            self.daemon.generation != handle.generation() or !self.daemon.value.valid()) return null;
        return &self.daemon.value;
    }

    pub fn getDaemon(self: *AddressSpace, handle: Handle(Daemon)) ?*Daemon {
        return @constCast(self.getDaemonConst(handle) orelse return null);
    }

    pub fn getNamespaceConst(self: *const AddressSpace, handle: Handle(Namespace)) ?*const Namespace {
        const value = self.namespaces.getConst(handle) orelse return null;
        if (!value.identity.validFor(.namespace) or value.reserved != 0 or value.reserved2 != 0 or value.pid == 0) return null;
        _ = self.getDaemonConst(value.daemon) orelse return null;
        return value;
    }

    pub fn getNamespace(self: *AddressSpace, handle: Handle(Namespace)) ?*Namespace {
        return @constCast(self.getNamespaceConst(handle) orelse return null);
    }

    pub fn getStreamConst(self: *const AddressSpace, handle: Handle(Stream)) ?*const Stream {
        const value = self.streams.getConst(handle) orelse return null;
        if (!value.identity.validFor(.stream) or value.reserved != 0 or value.reserved2 != 0 or value.pid == 0) return null;
        _ = self.getNamespaceConst(value.namespace) orelse return null;
        return value;
    }

    pub fn getStream(self: *AddressSpace, handle: Handle(Stream)) ?*Stream {
        return @constCast(self.getStreamConst(handle) orelse return null);
    }

    pub fn getObjectConst(self: *const AddressSpace, handle: Handle(Object)) ?*const Object {
        const value = self.objects.getConst(handle) orelse return null;
        if (!value.identity.validFor(.object) or value.identity.id != handle.objectIndex() or
            !value.stream.valid() or value.stream.index() != handle.streamIndex() or
            value.pid == 0 or value.revision == 0 or value.min_size > value.max_size or
            value.max_size > Layout.object_bytes or value.size < value.min_size or
            value.size > value.max_size) return null;
        const parent = self.getStreamConst(value.stream) orelse return null;
        if (parent.namespace.value != value.namespace.value) return null;
        return value;
    }

    pub fn getObject(self: *AddressSpace, handle: Handle(Object)) ?*Object {
        return @constCast(self.getObjectConst(handle) orelse return null);
    }

    pub fn exists(self: *const AddressSpace, reference: HandleReference) bool {
        if (!reference.valid()) return false;
        return switch (reference.type) {
            .daemon => self.getDaemonConst(.{ .value = reference.handle }) != null,
            .namespace => self.getNamespaceConst(.{ .value = reference.handle }) != null,
            .stream => self.getStreamConst(.{ .value = reference.handle }) != null,
            .object => self.getObjectConst(.{ .value = reference.handle }) != null,
            else => false,
        };
    }

    pub fn findNamespace(self: *const AddressSpace, parent: Handle(Daemon), id: u64) ?Handle(Namespace) {
        if (id == 0) return null;
        _ = self.getDaemonConst(parent) orelse return null;
        for (&self.namespaces.slots, 0..) |*slot, index| {
            if (slot.state != .active or slot.value.identity.id != id or
                slot.value.daemon.value != parent.value) continue;
            const handle = Handle(Namespace).init(@intCast(index), slot.generation);
            _ = self.getNamespaceConst(handle) orelse continue;
            return handle;
        }
        return null;
    }

    pub fn findStream(self: *const AddressSpace, parent: Handle(Namespace), id: u64) ?Handle(Stream) {
        if (id == 0) return null;
        _ = self.getNamespaceConst(parent) orelse return null;
        for (&self.streams.slots, 0..) |*slot, index| {
            if (slot.state != .active or slot.value.identity.id != id or
                slot.value.namespace.value != parent.value) continue;
            const handle = Handle(Stream).init(@intCast(index), slot.generation);
            _ = self.getStreamConst(handle) orelse continue;
            return handle;
        }
        return null;
    }

    /// O(1) local Object lookup: no scan, list lookup or ID hash table.
    pub fn findObject(self: *const AddressSpace, parent: Handle(Stream), local_index: u8) ?Handle(Object) {
        _ = self.getStreamConst(parent) orelse return null;
        const index = (parent.index() << 8) | @as(u16, local_index);
        const slot = &self.objects.slots[index];
        const handle = Handle(Object).init(index, slot.generation);
        const value = self.getObjectConst(handle) orelse return null;
        if (value.stream.value != parent.value) return null;
        return handle;
    }

    pub fn objectAddress(self: *const AddressSpace, handle: Handle(Object)) ?ObjectAddress {
        _ = self.getObjectConst(handle) orelse return null;
        return ObjectAddress.fromHandle(handle);
    }

    /// Topology check, not permission inheritance. Both entities must be live.
    pub fn contains(self: *const AddressSpace, scope: HandleReference, subject: HandleReference) bool {
        if (!self.exists(scope) or !self.exists(subject)) return false;
        if (sameReference(scope, subject)) return true;
        if (scope.type == .daemon) return true; // this arena has exactly one Daemon
        return switch (subject.type) {
            .stream => scope.type == .namespace and
                self.getStreamConst(.{ .value = subject.handle }).?.namespace.value == scope.handle,
            .object => blk: {
                const value = self.getObjectConst(.{ .value = subject.handle }).?;
                break :blk switch (scope.type) {
                    .namespace => value.namespace.value == scope.handle,
                    .stream => value.stream.value == scope.handle,
                    else => false,
                };
            },
            else => false,
        };
    }
};

/// One action against an explicit target. Bootstrap alone has empty endpoints.
/// Parameter records and any trailing bytes are carried in Message.payload.
pub const Request = extern struct {
    operation: Operation = .none,
    reserved: u16 = 0,
    from: HandleReference = .{},
    to: HandleReference = .{},

    /// Enumerate direct children of Request.to:
    ///   .namespace -> Daemon; .stream -> Namespace; .object -> Stream.
    /// Object cursors are LOCAL Object indices; Stream cursors are global slots.
    /// match_id=1 performs an exact scoped ID lookup, including Object ID zero.
    /// match_id=0 requires id=0 and does not filter by ID.
    /// A nonempty zero-padded name is an additional exact filter.
    /// cursor=0/revision=0 starts. Continue with next_cursor/revision until zero.
    /// A catalog revision change requires restarting the scan.
    pub const Discover = extern struct {
        type: HandleType = .none,
        permissions: u16 = 0,
        limit: u16 = 32,
        match_id: u16 = 0,
        cursor: u32 = 0,
        reserved: u32 = 0,
        id: u64 = 0,
        name: [Layout.name_bytes]u8 = @splat(0),
        revision: u64 = 0,
    };

    /// The parent is Request.to. Daemon creation is host-only.
    /// Namespace -> Daemon; Stream -> Namespace; Object -> Stream.
    /// Object identity.id selects EXACTLY that local slot, with no auto-allocation
    /// elsewhere. Occupied -> already_exists; retired -> resource_exhausted.
    /// The runtime checks Namespace/Stream uniqueness within the full parent.
    /// Object starts with zero-filled data, size=min_size, revision=1.
    /// Creation does not install grants; use administer separately.
    pub const Create = extern struct {
        type: HandleType = .none,
        format: Object.Format = .bytes,
        min_size: u16 = 0,
        max_size: u16 = Layout.object_bytes,
        identity: Identity = .{},
    };

    /// Session-scoped access association. Requested rights must already be granted.
    /// Idempotent for (connection, from, to); this never creates authority.
    pub const Acquire = extern struct {
        permissions: u16 = @backingInt(Operation.read),
        reserved: [6]u8 = @splat(0),
    };

    /// descriptor returns the selected Daemon/Namespace/Stream/Object record.
    /// data returns only Object bytes. length=0 means all remaining live bytes.
    /// revision=0 accepts current data; otherwise a mismatch returns busy.
    pub const Read = extern struct {
        mode: Mode = .data,
        reserved: u16 = 0,
        offset: u16 = 0,
        length: u16 = 0,
        revision: u64 = 0,
        pub const Mode = enum(u16) { descriptor = 0, data = 1, _ };
    };

    /// Followed by bytes copied at offset. size is the final Object size.
    /// Zero exposed gaps/truncated bytes and increment revision after the entire
    /// request is accepted. expected_revision=0 is unconditional. Publish separately.
    pub const Write = extern struct {
        offset: u16 = 0,
        size: u16 = 0,
        reserved: u32 = 0,
        expected_revision: u64 = 0,
    };

    /// Object revision=0 selects current revision; nonzero must match.
    /// published_at_ns=0 asks the broker for Unix/wall-clock nanoseconds.
    /// Publishing a container is only an aggregate hint, not a child transaction.
    pub const Publish = extern struct {
        revision: u64 = 0,
        published_at_ns: i64 = 0,
    };

    /// One filter per (connection, from, to); enabled=0 removes the filter.
    /// For a Stream, objects selects LOCAL Object slots, including future creations
    /// or replacements in those slots while this Stream handle remains alive.
    /// include_scope controls events about Request.to itself, independently.
    /// Example: objects={foo,bar}, include_scope=0 selects only those child Objects.
    /// Daemon/Namespace/Object subscriptions require objects=ObjectSet.all.
    /// Daemon/Namespace scopes cover descendants; an Object scope covers itself.
    /// Selection is not authorization. Check grants for every delivered event.
    /// after_revision is an initial freshness hint, not replay or a cross-object
    /// revision ordering. Unsubscribe ignores filters; reserved must still be zero.
    pub const Subscribe = extern struct {
        events: u16 = @backingInt(Operation.publish),
        enabled: u16 = 1,
        include_scope: u16 = 1,
        reserved: u16 = 0,
        after_revision: u64 = 0,
        objects: ObjectSet = .all,

        /// Selection only. Caller still checks subscribe/discover permissions.
        /// For release events, evaluate BEFORE invalidating the subject slot.
        pub fn matches(
            self: *const Subscribe,
            arena: *const AddressSpace,
            scope: HandleReference,
            subject: HandleReference,
            operation: Operation,
        ) bool {
            if (self.enabled != 1 or !Permission.contains(self.events, operation) or
                !arena.contains(scope, subject)) return false;
            if (sameReference(scope, subject)) return self.include_scope == 1;
            if (scope.type == .stream and subject.type == .object) {
                const handle = subject.typed(Object) orelse return false;
                return self.objects.contains(handle.objectIndex());
            }
            return true;
        }
    };

    /// Opaque application command sent to the target's owner. .ok means completed,
    /// not merely queued. The host must provide actual routing/completion handling.
    pub const Control = extern struct {
        command: u32 = 0,
        reserved: u32 = 0,
    };

    /// Grantor=Request.from, target=Request.to, grantee=Namespace or Stream.
    /// Daemon grants are stored in the grantee's daemons list. A grant to a
    /// container does not silently grant unrelated descendant operations.
    pub const Administer = extern struct {
        grantee: HandleReference = .{},
        permissions: u16 = 0,
        mode: Mode = .replace,
        reserved: u32 = 0,
        pub const Mode = enum(u16) { replace = 0, add = 1, remove = 2, _ };
    };

    /// access drops the caller's association, even after revocation.
    /// entity destroys a non-Daemon entity; a parent with live children is busy.
    /// Destroy Object slots without resetting generations on Stream reuse.
    pub const Release = extern struct {
        mode: Mode = .entity,
        reserved: [6]u8 = @splat(0),
        pub const Mode = enum(u16) { access = 0, entity = 1, _ };
    };

    /// Representation validation only. Requires the FULL reassembled payload.
    pub fn validate(self: *const Request, payload: []const u8) Code {
        if (self.reserved != 0 or payload.len > Message.max_transfer_bytes) return .invalid;
        if (!self.from.empty() and (!self.from.valid() or
            (self.from.type != .namespace and self.from.type != .stream))) return .invalid;
        if (!self.to.empty() and !self.to.valid()) return .invalid;

        if (self.operation == .none) {
            return if (self.from.empty() and self.to.empty() and payload.len == 0) .ok else .invalid;
        }
        self.operation.valid() catch return .invalid;
        if (self.to.empty()) return .invalid;

        switch (self.operation) {
            .discover => {
                if (payload.len != @sizeOf(Discover)) return .invalid;
                const p = loadValue(Discover, payload);
                if (p.reserved != 0 or p.match_id > 1) return .invalid;
                const cap = discoveryCapacity(p.type) orelse return .unsupported;
                if (self.to.type != parentType(p.type)) return .invalid;
                if (p.limit == 0 or p.limit > Response.max_discovery_items or p.cursor >= cap) return .invalid;
                if ((p.permissions & ~Permission.all) != 0) return .unsupported;
                if (p.match_id == 0) {
                    if (p.id != 0) return .invalid;
                } else if (!(Identity{ .id = p.id }).validFor(p.type)) return .invalid;
            },
            .create => {
                if (payload.len != @sizeOf(Create)) return .invalid;
                const p = loadValue(Create, payload);
                if (p.type != .namespace and p.type != .stream and p.type != .object) return .unsupported;
                if (self.to.type != parentType(p.type) or !p.identity.validFor(p.type)) return .invalid;
                if (p.min_size > p.max_size or p.max_size > Layout.object_bytes) return .invalid;
                if (p.type != .object and
                    (p.format != .bytes or p.min_size != 0 or p.max_size != Layout.object_bytes)) return .invalid;
            },
            .acquire => {
                if (payload.len != @sizeOf(Acquire)) return .invalid;
                const p = loadValue(Acquire, payload);
                if (!zeroBytes(&p.reserved) or p.permissions == 0) return .invalid;
                if ((p.permissions & ~Permission.all) != 0) return .unsupported;
            },
            .read => {
                if (payload.len != @sizeOf(Read)) return .invalid;
                const p = loadValue(Read, payload);
                if (p.reserved != 0) return .invalid;
                switch (p.mode) {
                    .descriptor => if (p.offset != 0 or p.length != 0 or p.revision != 0) return .invalid,
                    .data => if (self.to.type != .object or p.offset > Layout.object_bytes or
                        p.length > Layout.object_bytes - @as(usize, p.offset)) return .invalid,
                    else => return .unsupported,
                }
            },
            .write => {
                if (self.to.type != .object or payload.len < @sizeOf(Write)) return .invalid;
                const p = loadValue(Write, payload);
                const n = payload.len - @sizeOf(Write);
                if (p.reserved != 0 or p.size > Layout.object_bytes or p.offset > p.size or
                    n > p.size - p.offset) return .invalid;
            },
            .publish => if (payload.len != @sizeOf(Publish)) return .invalid,
            .subscribe => {
                if (payload.len != @sizeOf(Subscribe)) return .invalid;
                const p = loadValue(Subscribe, payload);
                if (p.reserved != 0 or p.enabled > 1) return .invalid;
                if (p.enabled == 1) {
                    if (p.include_scope > 1 or p.events == 0 or
                        (p.events & ~Message.Event.allowed_operations) != 0) return .invalid;
                    if (self.to.type == .stream) {
                        if (p.include_scope == 0 and p.objects.isEmpty()) return .invalid;
                    } else if (!p.objects.eql(ObjectSet.all)) return .invalid;
                    if (self.to.type == .object and p.include_scope == 0) return .invalid;
                }
            },
            .control => {
                if (self.to.type == .object or payload.len < @sizeOf(Control)) return .invalid;
                if (loadValue(Control, payload).reserved != 0) return .invalid;
            },
            .administer => {
                if (payload.len != @sizeOf(Administer)) return .invalid;
                const p = loadValue(Administer, payload);
                if (p.reserved != 0 or !p.grantee.valid() or
                    (p.grantee.type != .namespace and p.grantee.type != .stream)) return .invalid;
                if ((p.permissions & ~Permission.all) != 0) return .unsupported;
                // Namespace descriptors have no direct Object-grant list.
                if (p.grantee.type == .namespace and self.to.type == .object) return .unsupported;
                switch (p.mode) {
                    .replace, .add, .remove => {},
                    else => return .unsupported,
                }
            },
            .release => {
                if (payload.len != @sizeOf(Release)) return .invalid;
                const p = loadValue(Release, payload);
                if (!zeroBytes(&p.reserved)) return .invalid;
                switch (p.mode) {
                    .access => {},
                    .entity => if (self.to.type == .daemon) return .unsupported,
                    else => return .unsupported,
                }
            },
            else => return .unsupported,
        }
        return .ok;
    }
};

/// One final operation result; Message owns correlation/session/epoch.
/// Error responses leave all result metadata zero, with optional diagnostic bytes.
pub const Response = extern struct {
    operation: Operation = .none,
    code: Code = .ok,
    result: HandleReference = .{},
    permissions: u16 = 0,
    item_count: u16 = 0,
    revision: u64 = 0,
    next_cursor: u32 = 0,
    reserved: u32 = 0,

    /// Successful bootstrap describes the Daemon, not an invented root Namespace.
    /// identity may be checked against an expected Daemon identity by the client.
    /// An identity match does not replace OS/transport authentication.
    pub const Connection = extern struct {
        daemon: HandleReference = .{},
        identity: Identity = .{},
        mapping_size: u64 = @sizeOf(AddressSpace),
        object_data_offset: u64 = @offsetOf(AddressSpace, "object_data"),
        object_bytes: u32 = Layout.object_bytes,
        namespace_capacity: u32 = Layout.namespace_capacity,
        stream_capacity: u32 = Layout.stream_capacity,
        object_capacity: u32 = Layout.object_capacity,
    };

    /// Parent makes scoped identities unambiguous in a discovery result.
    pub const Item = extern struct {
        reference: HandleReference = .{},
        parent: HandleReference = .{},
        identity: Identity = .{},

        pub fn valid(self: *const Item) bool {
            if (!self.reference.valid() or !self.parent.valid() or
                !self.identity.validFor(self.reference.type) or
                self.parent.type != parentType(self.reference.type)) return false;
            if (self.reference.type == .object) {
                const object = self.reference.typed(Object).?;
                const stream = self.parent.typed(Stream).?;
                return object.streamIndex() == stream.index() and
                    object.objectIndex() == self.identity.id;
            }
            return self.reference.type == .namespace or self.reference.type == .stream;
        }
    };
    pub const max_discovery_items: u16 = @intCast(Message.max_payload_bytes / @sizeOf(Item));

    /// Object acquire metadata. Non-Object acquisition has no payload.
    /// address is relative to object_data and does not pin lifetime.
    pub const Access = extern struct {
        address: ObjectAddress = .{},
        size: u16 = 0,
        min_size: u16 = 0,
        max_size: u16 = Layout.object_bytes,
        format: Object.Format = .bytes,
        reserved: u32 = 0,
    };

    pub fn validate(self: *const Response, payload: []const u8) Code {
        if (self.reserved != 0 or payload.len > Message.max_transfer_bytes) return .invalid;
        if (!self.result.empty() and !self.result.valid()) return .invalid;
        if (self.code != .ok) {
            return if (self.result.empty() and self.permissions == 0 and self.item_count == 0 and
                self.revision == 0 and self.next_cursor == 0) .ok else .invalid;
        }
        if (self.operation == .none) {
            if (!self.result.empty() or self.permissions != 0 or self.item_count != 0 or
                self.revision != 0 or self.next_cursor != 0 or payload.len != @sizeOf(Connection)) return .invalid;
            const p = loadValue(Connection, payload);
            if (!p.daemon.valid() or p.daemon.type != .daemon or !p.identity.validFor(.daemon)) return .invalid;
            if (p.mapping_size != @sizeOf(AddressSpace) or
                p.object_data_offset != @offsetOf(AddressSpace, "object_data") or
                p.object_bytes != Layout.object_bytes or p.namespace_capacity != Layout.namespace_capacity or
                p.stream_capacity != Layout.stream_capacity or p.object_capacity != Layout.object_capacity) return .unsupported;
            return .ok;
        }
        self.operation.valid() catch return .invalid;
        if (self.operation != .acquire and self.permissions != 0) return .invalid;
        if (self.operation != .discover and (self.item_count != 0 or self.next_cursor != 0)) return .invalid;
        switch (self.operation) {
            .discover => {
                if (!self.result.empty() or self.revision == 0 or self.item_count > max_discovery_items or
                    self.next_cursor > 255 or payload.len != @as(usize, self.item_count) * @sizeOf(Item)) return .invalid;
                var i: usize = 0;
                while (i < self.item_count) : (i += 1) {
                    const item = loadValue(Item, payload[i * @sizeOf(Item) ..]);
                    if (!item.valid()) return .invalid;
                }
            },
            .acquire => {
                if (self.result.empty() or self.permissions == 0 or (self.permissions & ~Permission.all) != 0) return .invalid;
                if (self.result.type == .object) {
                    if (payload.len != @sizeOf(Access) or self.revision == 0) return .invalid;
                    const p = loadValue(Access, payload);
                    const object = self.result.typed(Object).?;
                    if (p.reserved != 0 or p.min_size > p.max_size or p.max_size > Layout.object_bytes or
                        p.size < p.min_size or p.size > p.max_size or
                        p.address.offset != (@as(u32, object.index()) << 12)) return .invalid;
                } else if (payload.len != 0 or self.revision != 0) return .invalid;
            },
            .read => {
                if (self.result.empty() or payload.len > Message.max_payload_bytes) return .invalid;
            },
            .control => {
                if (self.result.empty() or self.result.type == .object) return .invalid;
            },
            .create => {
                if (self.result.empty() or self.result.type == .daemon or payload.len != 0) return .invalid;
                if (self.result.type == .object) {
                    if (self.revision != 1) return .invalid;
                } else if (self.revision != 0) return .invalid;
            },
            .write => {
                if (self.result.type != .object or payload.len != 0 or self.revision == 0) return .invalid;
            },
            .publish, .subscribe, .administer, .release => {
                if (self.result.empty() or payload.len != 0) return .invalid;
            },
            else => return .unsupported,
        }
        return .ok;
    }

    /// Correlate representation with the complete pending request. Still match
    /// Message request_id/session/epoch independently.
    pub fn validateFor(
        self: *const Response,
        request: *const Request,
        request_payload: []const u8,
        payload: []const u8,
    ) Code {
        const checked = self.validate(payload);
        if (checked != .ok) return checked;
        if (self.operation != request.operation) return .invalid;
        if (self.code != .ok) return .ok;
        if (request.validate(request_payload) != .ok) return .invalid;
        if (request.operation == .none) return .ok;
        if (request.operation == .create) {
            const p = loadValue(Request.Create, request_payload);
            if (self.result.type != p.type) return .invalid;
            if (p.type == .object) {
                const object = self.result.typed(Object).?;
                const stream = request.to.typed(Stream).?;
                if (object.streamIndex() != stream.index() or object.objectIndex() != p.identity.id) return .invalid;
            }
            return .ok;
        }
        if (request.operation == .discover) {
            const p = loadValue(Request.Discover, request_payload);
            const cap = discoveryCapacity(p.type).?;
            if (self.item_count > p.limit or (p.revision != 0 and p.revision != self.revision)) return .invalid;
            if (self.next_cursor != 0 and (self.next_cursor <= p.cursor or self.next_cursor >= cap)) return .invalid;
            var last: ?u32 = null;
            var i: usize = 0;
            while (i < self.item_count) : (i += 1) {
                const item = loadValue(Item, payload[i * @sizeOf(Item) ..]);
                if (item.reference.type != p.type or !sameReference(item.parent, request.to) or
                    (p.match_id == 1 and item.identity.id != p.id) or
                    (!zeroBytes(&p.name) and !eql(u8, &p.name, &item.identity.name))) return .invalid;
                const cursor: u32 = if (p.type == .object)
                    item.reference.handle & 0xff
                else
                    item.reference.handle & 0xffff;
                if (cursor < p.cursor or (self.next_cursor != 0 and cursor >= self.next_cursor)) return .invalid;
                if (last) |previous| if (cursor <= previous) return .invalid;
                last = cursor;
            }
            return .ok;
        }
        if (!sameReference(self.result, request.to)) return .invalid;
        if (request.operation == .read) {
            const p = loadValue(Request.Read, request_payload);
            if (p.mode == .descriptor) {
                const expected = descriptorSize(self.result.type) orelse return .invalid;
                if (payload.len != expected or !descriptorShape(self.result, payload)) return .invalid;
            } else {
                if (payload.len > Layout.object_bytes - @as(usize, p.offset) or self.revision == 0) return .invalid;
                if (p.length != 0 and payload.len != p.length) return .invalid;
                if (p.revision != 0 and p.revision != self.revision) return .invalid;
            }
        }
        if (request.operation == .acquire) {
            if (self.permissions != loadValue(Request.Acquire, request_payload).permissions) return .invalid;
        }
        return .ok;
    }
};

/// Framed transport envelope. Only the selected body and used payload bytes
/// are sent. Never send @sizeOf(Message) bytes indiscriminately.
///
/// encode/decode require non-overlapping source/destination storage.
/// Decoding validates framing, not authorization. After reassembly, validate
/// the Request/Response and then check the authenticated session and tables.
pub const Message = extern struct {
    header: Header = .{},
    body: Body = .{ .raw = @splat(0) },
    payload: [max_payload_bytes]u8 = @splat(0),

    // One frame holds a complete 4096-byte write plus its parameter record.
    pub const max_payload_bytes: usize = Layout.object_bytes + @sizeOf(Request.Write);
    // Bound a logical application command/reply, not an Object's byte capacity.
    pub const max_transfer_bytes: usize = 1024 * 1024;
    pub const max_frame_bytes: usize = @sizeOf(Header) + @sizeOf(Body) + max_payload_bytes;

    pub const Kind = enum(u16) { none = 0, request = 1, response = 2, event = 3, _ };

    pub const Header = extern struct {
        magic: Magic = .{},
        version: Version = .{},
        kind: Kind = .none,
        body_size: u16 = 0,
        payload_size: u32 = 0,
        request_id: u64 = 0,
        session_id: u64 = 0,
        epoch: u64 = 0,
        total_size: u32 = 0,
        fragment_offset: u32 = 0,

        pub fn validate(self: *const Header) Code {
            if (!nativeProfile()) return .unsupported;
            if (self.magic.value != (Magic{}).value) return .invalid;
            const version: Version = .{};
            if (self.version.major != version.major or self.version.minor != version.minor or
                self.version.patch != version.patch) return .unsupported;
            if (self.version.reserved != 0) return .invalid;
            const expected: usize = switch (self.kind) {
                .request => @sizeOf(Request),
                .response => @sizeOf(Response),
                .event => @sizeOf(Event),
                else => return .unsupported,
            };
            if (self.body_size != expected or self.payload_size > max_payload_bytes or
                self.total_size > max_transfer_bytes) return .invalid;
            if (self.fragment_offset > self.total_size or
                self.payload_size > self.total_size - self.fragment_offset) return .invalid;
            if (self.total_size == 0) {
                if (self.payload_size != 0 or self.fragment_offset != 0) return .invalid;
            } else if (self.payload_size == 0) return .invalid;
            if (self.kind == .event) {
                if (self.request_id != 0 or self.session_id == 0 or self.epoch == 0 or
                    self.total_size != 0) return .invalid;
            } else if (self.request_id == 0) return .invalid;
            return .ok;
        }

        pub fn frameSize(self: *const Header) usize {
            return @sizeOf(Header) + @as(usize, self.body_size) + self.payload_size;
        }
    };

    /// Events are hints, not responses. subject can identify a passive Object;
    /// from identifies a Daemon/Namespace/Stream, or is empty for a broker event.
    /// to identifies the subscriber actor, or its connection if empty.
    /// revision is the current object/catalog revision. A release event can
    /// intentionally reference a handle that no longer resolves.
    pub const Event = extern struct {
        operation: Operation = .none,
        reserved: u16 = 0,
        from: HandleReference = .{},
        to: HandleReference = .{},
        subject: HandleReference = .{},
        reserved2: u32 = 0,
        revision: u64 = 0,

        pub const allowed_operations: u16 = Permission.add(0, .{
            .write, .publish, .create, .release, .administer, .control,
        });

        pub fn validate(self: *const Event) Code {
            if (self.reserved != 0 or self.reserved2 != 0) return .invalid;
            if (!self.from.empty() and (!self.from.valid() or self.from.type == .object)) return .invalid;
            if (!self.to.empty() and (!self.to.valid() or
                (self.to.type != .namespace and self.to.type != .stream))) return .invalid;
            if (!self.subject.valid()) return .invalid;
            self.operation.valid() catch return .invalid;

            if ((@backingInt(self.operation) & allowed_operations) == 0) return .unsupported;
            return .ok;
        }
    };

    pub const Body = extern union {
        request: Request,
        response: Response,
        event: Event,
        raw: [@sizeOf(Event)]u8,
    };

    pub fn initRequest(
        self: *Message,
        session_id: u64,
        epoch: u64,
        request_id: u64,
        request: Request,
        data: []const u8,
    ) Code {
        if (data.len > max_payload_bytes) return .resource_exhausted;
        return self.requestFragment(session_id, epoch, request_id, request, data, 0);
    }

    /// For larger application commands, call with offsets 0, then advance by
    /// each generated header.payload_size. full_data remains caller-owned.
    /// All frames repeat the same request body and exchange identifiers.
    pub fn requestFragment(
        self: *Message,
        session_id: u64,
        epoch: u64,
        request_id: u64,
        request: Request,
        full_data: []const u8,
        offset: usize,
    ) Code {
        const checked = request.validate(full_data);
        if (checked != .ok) return checked;
        var result: Message = .{};
        result.header.kind = .request;
        result.header.body_size = @sizeOf(Request);
        result.header.session_id = session_id;
        result.header.epoch = epoch;
        result.header.request_id = request_id;
        result.body.request = request;
        const status = result.fillFragment(full_data, offset);
        if (status != .ok) return status;
        const framed = result.validateFrame();
        if (framed != .ok) return framed;
        self.* = result;
        return .ok;
    }

    pub fn initResponse(
        self: *Message,
        request: *const Message,
        response: Response,
        data: []const u8,
    ) Code {
        if (data.len > max_payload_bytes) return .resource_exhausted;
        return self.responseFragment(request, response, data, 0);
    }

    /// Echoes the operation and correlation context. Application handlers set
    /// code/result/permissions/revision/cursor fields, not Message routing IDs.
    pub fn responseFragment(
        self: *Message,
        request: *const Message,
        response: Response,
        full_data: []const u8,
        offset: usize,
    ) Code {
        if (request.header.kind != .request or request.validateFrame() != .ok) return .invalid;
        var reply = response;
        reply.operation = request.body.request.operation;
        const checked = reply.validate(full_data);
        if (checked != .ok) return checked;
        var result: Message = .{};
        result.header.kind = .response;
        result.header.body_size = @sizeOf(Response);
        result.header.request_id = request.header.request_id;
        result.header.session_id = request.header.session_id;
        result.header.epoch = request.header.epoch;
        result.body.response = reply;
        const status = result.fillFragment(full_data, offset);
        if (status != .ok) return status;
        const framed = result.validateFrame();
        if (framed != .ok) return framed;
        self.* = result;
        return .ok;
    }

    /// Successful bootstrap. The host supplies its live Daemon descriptor and
    /// handle. Session is assigned by the runtime; epoch comes from that descriptor.
    pub fn initConnected(
        self: *Message,
        request: *const Message,
        session_id: u64,
        daemon: Handle(Daemon),
        descriptor: *const Daemon,
    ) Code {
        if (request.header.kind != .request or request.validate() != .ok or
            request.body.request.operation != .none or session_id == 0 or
            !daemon.valid() or !descriptor.valid()) return .invalid;
        var result: Message = .{};
        const info: Response.Connection = .{
            .daemon = HandleReference.init(Daemon, daemon),
            .identity = descriptor.identity,
        };
        result.header.kind = .response;
        result.header.body_size = @sizeOf(Response);
        result.header.request_id = request.header.request_id;
        result.header.session_id = session_id;
        result.header.epoch = descriptor.epoch;
        result.body.response = .{};
        const status = result.fillFragment(bytesOf(Response.Connection, &info), 0);
        if (status != .ok) return status;
        const checked = result.validate();
        if (checked != .ok) return checked;
        self.* = result;
        return .ok;
    }

    pub fn initEvent(self: *Message, session_id: u64, epoch: u64, event: Event) Code {
        const checked = event.validate();
        if (checked != .ok) return checked;
        var result: Message = .{};
        result.header.kind = .event;
        result.header.body_size = @sizeOf(Event);
        result.header.session_id = session_id;
        result.header.epoch = epoch;
        result.body.event = event;
        const framed = result.validateFrame();
        if (framed != .ok) return framed;
        self.* = result;
        return .ok;
    }

    fn fillFragment(self: *Message, full_data: []const u8, offset: usize) Code {
        if (full_data.len > max_transfer_bytes or offset > full_data.len) return .invalid;
        if (full_data.len != 0 and offset == full_data.len) return .invalid;
        const n = @min(full_data.len - offset, max_payload_bytes);
        self.header.total_size = @intCast(full_data.len);
        self.header.fragment_offset = @intCast(offset);
        self.header.payload_size = @intCast(n);
        @memcpy(self.payload[0..n], full_data[offset..][0..n]);
        return .ok;
    }

    /// Frame shape only. A complete operation still needs validate() or assembly.
    pub fn validateFrame(self: *const Message) Code {
        const status = self.header.validate();
        if (status != .ok) return status;
        switch (self.header.kind) {
            .request => {
                if (self.body.request.operation == .none) {
                    if (self.header.session_id != 0 or self.header.epoch != 0 or
                        self.header.total_size != 0) return .invalid;
                } else if (self.header.session_id == 0 or self.header.epoch == 0) return .invalid;
            },
            .response => {
                if (self.body.response.operation == .none and self.body.response.code != .ok) {
                    if ((self.header.session_id == 0) != (self.header.epoch == 0)) return .invalid;
                } else if (self.header.session_id == 0 or self.header.epoch == 0) return .invalid;
            },
            .event => return self.body.event.validate(),
            else => return .unsupported,
        }
        return .ok;
    }

    /// Validate one complete, unfragmented message. busy means use Assembly,
    /// not that the sender's requested operation was executed or rejected.
    pub fn validate(self: *const Message) Code {
        const framed = self.validateFrame();
        if (framed != .ok) return framed;
        if (self.header.fragment_offset != 0 or self.header.total_size != self.header.payload_size)
            return .busy;
        return validateBody(self.header.kind, &self.body, self.payload[0..self.header.payload_size]);
    }

    /// A stream transport reads Header first, checks this, then reads the exact
    /// remaining byte count. It must not allocate from an unchecked wire length.
    pub fn frameSize(prefix: []const u8, size: *usize) Code {
        size.* = 0;
        if (prefix.len < @sizeOf(Header)) return .invalid;
        const header = loadValue(Header, prefix);
        const checked = header.validate();
        if (checked != .ok) return checked;
        size.* = header.frameSize();
        return .ok;
    }

    pub fn encode(self: *const Message, output: []u8, written: *usize) Code {
        written.* = 0;
        const checked = self.validateFrame();
        if (checked != .ok) return checked;
        const n = self.header.frameSize();
        if (output.len < n) return .resource_exhausted;
        const h = @sizeOf(Header);
        const b: usize = self.header.body_size;
        @memcpy(output[0..h], bytesOf(Header, &self.header));
        @memcpy(output[h..][0..b], bodyBytes(self.header.kind, &self.body));
        @memcpy(output[h + b ..][0..self.header.payload_size], self.payload[0..self.header.payload_size]);
        written.* = n;
        return .ok;
    }

    /// Accepts exactly one frame; extra/truncated bytes are rejected.
    /// Copy into aligned storage rather than casting an unaligned receive buffer.
    pub fn decode(self: *Message, input: []const u8) Code {
        var required: usize = 0;
        const checked = frameSize(input, &required);
        if (checked != .ok) return checked;
        if (input.len != required) return .invalid;
        var result: Message = .{};
        result.header = loadValue(Header, input);
        const h = @sizeOf(Header);
        switch (result.header.kind) {
            .request => result.body.request = loadValue(Request, input[h..]),
            .response => result.body.response = loadValue(Response, input[h..]),
            .event => result.body.event = loadValue(Event, input[h..]),
            else => return .unsupported,
        }
        const start = h + result.header.body_size;
        @memcpy(result.payload[0..result.header.payload_size], input[start..]);
        const framed = result.validateFrame();
        if (framed != .ok) return framed;
        self.* = result;
        return .ok;
    }

    /// Bootstrap is the sole exchange allowed to introduce a new session/epoch.
    pub fn isReplyTo(self: *const Message, request: *const Message) bool {
        if (self.header.kind != .response or request.header.kind != .request or
            self.header.request_id != request.header.request_id or
            self.body.response.operation != request.body.request.operation) return false;
        if (request.body.request.operation == .none and self.body.response.code == .ok) {
            return request.header.session_id == 0 and request.header.epoch == 0 and
                self.header.session_id != 0 and self.header.epoch != 0;
        }
        return self.header.session_id == request.header.session_id and
            self.header.epoch == request.header.epoch;
    }
};

/// Caller-owned reassembly workspace, not a transmitted ABI record.
/// One instance per in-flight logical message. No allocation or hidden queue.
/// Complete payloads borrow buffer until reset/reuse. Never execute partial data.
pub const MessageAssembly = struct {
    buffer: []u8,
    header: Message.Header = .{},
    body: Message.Body = .{ .raw = @splat(0) },
    received: usize = 0,
    active: bool = false,

    pub fn init(buffer: []u8) MessageAssembly {
        return .{ .buffer = buffer };
    }

    pub fn reset(self: *MessageAssembly) void {
        self.header = .{};
        self.body = .{ .raw = @splat(0) };
        self.received = 0;
        self.active = false;
    }

    /// ok means the fragment was accepted. Check complete() before dispatch.
    /// Rejects gaps, overlaps and duplicate fragments; retry/dedup is a higher
    /// layer policy, not silent replacement of unacknowledged commands.
    pub fn append(self: *MessageAssembly, frame: *const Message) Code {
        if (self.active and self.complete()) return .busy;
        const status = self.appendChecked(frame);
        if (status != .ok) self.reset();
        return status;
    }

    fn appendChecked(self: *MessageAssembly, frame: *const Message) Code {
        const checked = frame.validateFrame();
        if (checked != .ok) return checked;
        if (self.active and self.complete()) return .busy;
        if (!self.active) {
            if (frame.header.fragment_offset != 0) return .invalid;
            if (frame.header.total_size > self.buffer.len) return .resource_exhausted;
            self.header = frame.header;
            self.body = frame.body;
            self.received = 0;
            self.active = true;
        } else {
            if (self.header.kind != frame.header.kind or
                self.header.request_id != frame.header.request_id or
                self.header.session_id != frame.header.session_id or
                self.header.epoch != frame.header.epoch or
                self.header.total_size != frame.header.total_size or
                !eql(u8, bodyBytes(self.header.kind, &self.body), bodyBytes(frame.header.kind, &frame.body))) return .invalid;
        }
        if (frame.header.fragment_offset != self.received) return .invalid;
        const n: usize = frame.header.payload_size;
        if (n > self.buffer.len - self.received) return .invalid;
        @memcpy(self.buffer[self.received..][0..n], frame.payload[0..n]);
        self.received += n;
        if (self.complete()) {
            const status = validateBody(self.header.kind, &self.body, self.buffer[0..self.received]);
            if (status != .ok) {
                self.reset();
                return status;
            }
        }
        return .ok;
    }

    pub fn complete(self: *const MessageAssembly) bool {
        return self.active and self.received == self.header.total_size;
    }

    pub fn payload(self: *const MessageAssembly) ?[]const u8 {
        if (!self.complete()) return null;
        return self.buffer[0..self.received];
    }
};

/// Local view of an initialized ABI record. The caller owns padding discipline
/// for arbitrary application types; this is not a general-purpose serializer.
pub fn bytesOf(comptime T: type, value: *const T) []const u8 {
    const ptr: [*]const u8 = @ptrCast(value);
    return ptr[0..@sizeOf(T)];
}

/// Size-checked prefix copy. Use the protocol's non-exhaustive enum/extern records,
/// not arbitrary pointers, bools or exhaustive enums from untrusted wire bytes.
pub fn readPayload(comptime T: type, payload: []const u8) ?T {
    if (payload.len < @sizeOf(T)) return null;
    return loadValue(T, payload);
}

pub fn packPayload(comptime T: type, parameters: *const T, data: []const u8, out: []u8) ?[]const u8 {
    if (@sizeOf(T) > out.len or data.len > out.len - @sizeOf(T)) return null;
    @memcpy(out[0..@sizeOf(T)], bytesOf(T, parameters));
    @memcpy(out[@sizeOf(T)..][0..data.len], data);
    return out[0 .. @sizeOf(T) + data.len];
}

pub fn eql(comptime T: type, a: []const T, b: []const T) bool {
    if (a.len != b.len) return false;
    if (a.len == 0 or a.ptr == b.ptr) return true;
    for (a, b) |left, right| if (left != right) return false;
    return true;
}

pub fn intersects(comptime T: type, a: T, b: T) bool {
    return (a & b) != 0;
}

pub fn contains(comptime T: type, a: T, b: T) bool {
    return (a & b) == b;
}

pub fn isEmpty(comptime T: type, a: T) bool {
    return a == 0;
}

fn objectIndexValue(value: anytype) u8 {
    return switch (@typeInfo(@TypeOf(value))) {
        .@"enum" => @intCast(@backingInt(value)),
        .int, .comptime_int => @intCast(value),
        else => @compileError("ObjectSet indices must be integers or typed enum values in 0..255"),
    };
}

fn handleType(comptime T: type) HandleType {
    if (T == Daemon) return .daemon;
    if (T == Namespace) return .namespace;
    if (T == Stream) return .stream;
    if (T == Object) return .object;
    @compileError("unsupported Sockman entity type");
}

fn tableCapacity(comptime T: type) usize {
    return switch (handleType(T)) {
        .daemon => 1,
        .namespace => Layout.namespace_capacity,
        .stream => Layout.stream_capacity,
        .object => Layout.object_capacity,
        else => unreachable,
    };
}

fn parentType(kind: HandleType) HandleType {
    return switch (kind) {
        .namespace => .daemon,
        .stream => .namespace,
        .object => .stream,
        else => .none,
    };
}

fn discoveryCapacity(kind: HandleType) ?u32 {
    return switch (kind) {
        .namespace => Layout.namespace_capacity,
        .stream => Layout.stream_capacity,
        .object => Layout.objects_per_stream,
        else => null,
    };
}

fn descriptorSize(kind: HandleType) ?usize {
    return switch (kind) {
        .daemon => @sizeOf(Daemon),
        .namespace => @sizeOf(Namespace),
        .stream => @sizeOf(Stream),
        .object => @sizeOf(Object),
        else => null,
    };
}

fn loadValue(comptime T: type, input: []const u8) T {
    var result: T = undefined;
    const destination: [*]u8 = @ptrCast(&result);
    @memcpy(destination[0..@sizeOf(T)], input[0..@sizeOf(T)]);
    return result;
}

fn permissionListShape(
    comptime From: type,
    comptime To: type,
    comptime capacity: usize,
    list: *const List(PermissionInit(From, To), capacity),
    owner: HandleReference,
) bool {
    if (!list.valid()) return false;
    for (list.items[0..list.len]) |entry| {
        if (entry.reserved != 0 or entry.from.value != owner.handle or
            !entry.from.valid() or !entry.to.valid() or (entry.permissions & ~Permission.all) != 0) return false;
    }
    return true;
}

/// Representation check for copied descriptors. Runtime validates live ancestors
/// and authorization independently; release-event subjects may already be stale.
fn descriptorShape(reference: HandleReference, payload: []const u8) bool {
    if (!reference.valid()) return false;
    const expected = descriptorSize(reference.type) orelse return false;
    if (payload.len != expected) return false;
    switch (reference.type) {
        .daemon => {
            const p = loadValue(Daemon, payload);
            return p.valid();
        },
        .namespace => {
            const p = loadValue(Namespace, payload);
            return p.identity.validFor(.namespace) and p.pid != 0 and
                p.daemon.valid() and p.reserved == 0 and p.reserved2 == 0 and
                permissionListShape(Namespace, Daemon, 1, &p.daemons, reference) and
                permissionListShape(Namespace, Namespace, 8, &p.namespaces, reference) and
                permissionListShape(Namespace, Stream, 32, &p.streams, reference);
        },
        .stream => {
            const p = loadValue(Stream, payload);
            return p.identity.validFor(.stream) and p.pid != 0 and
                p.namespace.valid() and p.reserved == 0 and p.reserved2 == 0 and
                permissionListShape(Stream, Daemon, 1, &p.daemons, reference) and
                permissionListShape(Stream, Namespace, 8, &p.namespaces, reference) and
                permissionListShape(Stream, Stream, 32, &p.streams, reference) and
                permissionListShape(Stream, Object, 256, &p.objects, reference);
        },
        .object => {
            const p = loadValue(Object, payload);
            const handle = reference.typed(Object).?;
            return p.identity.validFor(.object) and p.identity.id == handle.objectIndex() and
                p.namespace.valid() and p.stream.valid() and p.stream.index() == handle.streamIndex() and
                p.pid != 0 and p.revision != 0 and p.min_size <= p.max_size and
                p.max_size <= Layout.object_bytes and p.size >= p.min_size and p.size <= p.max_size;
        },
        else => return false,
    }
}

fn sameReference(a: HandleReference, b: HandleReference) bool {
    return a.type == b.type and a.handle == b.handle and a.reserved == b.reserved;
}

fn zeroBytes(bytes: []const u8) bool {
    for (bytes) |value| if (value != 0) return false;
    return true;
}

fn nativeProfile() bool {
    if (@sizeOf(usize) != 8 or @sizeOf(c_uint) != 4 or @sizeOf(c_ushort) != 2 or
        @sizeOf(c_ulong) != 8 or @alignOf(u64) != 8) return false;
    const value: u16 = 1;
    const bytes: *const [2]u8 = @ptrCast(&value);
    return bytes[0] == 1;
}

fn bodyBytes(kind: Message.Kind, body: *const Message.Body) []const u8 {
    return switch (kind) {
        .request => bytesOf(Request, &body.request),
        .response => bytesOf(Response, &body.response),
        .event => bytesOf(Message.Event, &body.event),
        else => &.{},
    };
}

fn validateBody(kind: Message.Kind, body: *const Message.Body, payload: []const u8) Code {
    return switch (kind) {
        .request => body.request.validate(payload),
        .response => body.response.validate(payload),
        .event => if (payload.len == 0) body.event.validate() else .invalid,
        else => .unsupported,
    };
}

// =============================================================================
// Procedural API
// =============================================================================
//
// The records below are PROCESS-LOCAL state, not additional wire records.
// A prepare function builds a request. It does not execute an operation.
//
// Caller workflow:
//   prepare -> callFrame -> caller sends -> callFrameSent
//           -> caller receives -> callAccept -> result function
//
// There is no transport, allocator, event loop, clock, OS integration, implicit
// publication, or broker implementation in this API. The caller owns Session,
// Call, both Call buffers, all I/O, and the authoritative request executor.
// Call buffers and Session storage must remain alive and stable until completion.
// Do not copy active state records. Serialize access to each Session and Call.
//
// Existing ABI structs stay flat. No entity wrapper objects, dynamic dispatch,
// function-pointer tables, global state, or per-entity allocations are introduced.

/// Local API failures. A completed operation's remote status stays in Response.code.
pub const ApiError = error{
    InvalidArgument,
    InvalidState,
    BufferTooSmall,
    BufferOverlap,
    InvalidRequest,
    InvalidResponse,
    UnexpectedMessage,
    WrongSession,
    StaleCall,
    RequestIdsExhausted,
    OperationFailed,
    TypeMismatch,
    DaemonMismatch,
    MappingMismatch,
};

/// A location description, not a connection or an OS resource.
/// The caller resolves this before starting the bootstrap exchange.
/// identity requires a caller-provided directory/resolver; it is not an address.
/// Slices are borrowed from caller-owned configuration.
pub const Endpoint = union(enum) {
    path: []const u8,
    environment: struct {
        name: []const u8,
        fallback: ?[]const u8 = null,
    },
    identity: u64,
};

pub const SessionOptions = struct {
    endpoint: Endpoint,
    expected_daemon_id: ?u64 = null,
};

pub const SessionPhase = enum { idle, connecting, connected, retired };

/// One connection lifetime to one Daemon. Owns no OS resource.
/// The generation is local cancellation state, not an arena/handle generation.
/// arena is an optional validated mapping; it grants no synchronization or rights.
/// Retain the same Session address while Calls refer to it.
pub const Session = struct {
    options: SessionOptions,
    phase: SessionPhase = .idle,
    generation: u64 = 1,
    id: u64 = 0,
    epoch: u64 = 0,
    next_request_id: u64 = 1,
    bootstrap_request_id: u64 = 0,
    connection: Response.Connection = .{},
    arena: ?*const AddressSpace = null,
};

pub const CallPhase = enum { idle, ready, waiting, receiving, complete, failed };

/// Complete request/response bookkeeping with caller-owned storage.
/// Request bytes are copied at preparation time and must not change while active.
/// Response slices borrow assembly.buffer until callReset/callInit or buffer reuse.
/// Use a separate Call and buffers for every outstanding logical operation.
/// Commands must still be transmitted in increasing request_id order per Session.
pub const Call = struct {
    phase: CallPhase = .idle,
    session: ?*const Session = null,
    session_generation: u64 = 0,
    daemon_id: u64 = 0,
    request_header: Message.Header = .{},
    request: Request = .{},
    request_buffer: []u8,
    request_size: usize = 0,
    send_offset: usize = 0,
    offered_size: usize = 0,
    frame_offered: bool = false,
    assembly: MessageAssembly,
    response: Response = .{},
    validation_code: Code = .ok,
};

pub const DaemonInitOptions = struct {
    identity: Identity,
    epoch: u64,
    pid: u64,
    generation: u16 = 1,
};

/// HOST-ONLY initialization of a fresh, exclusively owned arena.
/// The caller supplies the identity, epoch and process metadata. No Namespace,
/// Stream or Object is created. Payload pages are left untouched until creation.
/// NEVER call on a live arena or use this to adopt an existing populated arena.
/// The caller must provision fresh/cleared backing bytes before exposing the arena.
pub fn daemonInit(arena: *AddressSpace, options: DaemonInitOptions) ApiError!Handle(Daemon) {
    const descriptor: Daemon = .{
        .identity = options.identity,
        .epoch = options.epoch,
        .pid = options.pid,
    };
    if (!descriptor.valid() or options.generation == 0) return error.InvalidArgument;

    for (&arena.namespaces.slots) |*slot| slot.* = .{};
    for (&arena.streams.slots) |*slot| slot.* = .{};
    for (&arena.objects.slots) |*slot| slot.* = .{};
    @memset(&arena.data_padding, 0);
    arena.daemon = .{
        .generation = options.generation,
        .state = .active,
        .value = descriptor,
    };
    return Handle(Daemon).init(0, options.generation);
}

/// Prepare local state only. Does not resolve Endpoint or open a connection.
/// On reuse, use sessionDisconnect rather than assigning a fresh Session over
/// one still referenced by Calls; that would discard local cancellation history.
pub fn sessionInit(options: SessionOptions) ApiError!Session {
    switch (options.endpoint) {
        .path => |value| if (!apiTextValid(value)) return error.InvalidArgument,
        .environment => |value| {
            if (!apiTextValid(value.name)) return error.InvalidArgument;
            if (value.fallback) |fallback| if (!apiTextValid(fallback)) return error.InvalidArgument;
        },
        .identity => |id| {
            if (id == 0) return error.InvalidArgument;
            if (options.expected_daemon_id) |expected| if (expected != id) return error.InvalidArgument;
        },
    }
    if (options.expected_daemon_id) |id| if (id == 0) return error.InvalidArgument;
    return .{ .options = options };
}

/// Forget local session/mapping metadata and invalidate its existing Calls.
/// Does not close a transport or unmap memory. The caller does those separately.
/// It also does not retract operations already transmitted to the Daemon.
pub fn sessionDisconnect(session: *Session) void {
    session.id = 0;
    session.epoch = 0;
    session.next_request_id = 1;
    session.bootstrap_request_id = 0;
    session.connection = .{};
    session.arena = null;
    if (session.generation == ~@as(u64, 0)) {
        session.phase = .retired;
    } else {
        session.generation += 1;
        session.phase = .idle;
    }
}

/// Create a reusable operation record. Buffers must be separate and nonoverlapping.
/// Sizes are caller-selected. A full Object write needs Message.max_payload_bytes
/// request bytes; larger commands/replies can use Message.max_transfer_bytes.
pub fn callInit(request_buffer: []u8, response_buffer: []u8) ApiError!Call {
    if (apiOverlap(request_buffer, response_buffer)) return error.BufferOverlap;
    return .{
        .request_buffer = request_buffer,
        .assembly = MessageAssembly.init(response_buffer),
    };
}

/// Reuse local storage. Does not cancel a transmitted operation or reuse its ID.
/// A bootstrap abandoned this way also requires sessionDisconnect.
pub fn callReset(call: *Call) void {
    const request_buffer = call.request_buffer;
    const response_buffer = call.assembly.buffer;
    call.* = .{
        .request_buffer = request_buffer,
        .assembly = MessageAssembly.init(response_buffer),
    };
}

/// Prepare the first request on a newly connected transport.
/// Only a validated successful response followed by sessionConnected admits it.
pub fn sessionBootstrap(session: *Session, call: *Call) ApiError!void {
    if (session.phase != .idle) return error.InvalidState;
    try apiPrepare(session, call, .{}, &.{}, &.{});
    session.bootstrap_request_id = call.request_header.request_id;
    session.phase = .connecting;
}

/// Admit a completed bootstrap. The host must already have authenticated the
/// peer and verified the profile's arena attachment (for the local fd profile,
/// exactly one descriptor on success and none on failure).
/// This function checks the bytes and expected identity; it cannot authenticate I/O.
pub fn sessionConnected(session: *Session, call: *const Call) ApiError!void {
    try apiCallSession(session, call);
    if (session.phase != .connecting or call.request.operation != .none or
        call.request_header.request_id != session.bootstrap_request_id) return error.InvalidState;
    try apiSuccess(call, .none);
    const info = readPayload(Response.Connection, call.assembly.payload().?) orelse return error.InvalidResponse;
    if (apiExpectedDaemonId(session)) |expected| {
        if (info.identity.id != expected) return error.DaemonMismatch;
    }
    session.connection = info;
    session.id = call.assembly.header.session_id;
    session.epoch = call.assembly.header.epoch;
    session.bootstrap_request_id = 0;
    session.phase = .connected;
}

/// Validate the caller-provided mapping against the bootstrap. Only metadata is
/// read; caller guarantees correct backing size/alignment and synchronization.
/// Storing this pointer does not grant permission or make mutable reads safe.
pub fn sessionBindArena(session: *Session, arena: *const AddressSpace) ApiError!void {
    if (session.phase != .connected) return error.InvalidState;
    const handle = session.connection.daemon.typed(Daemon) orelse return error.InvalidState;
    const descriptor = arena.getDaemonConst(handle) orelse return error.MappingMismatch;
    if (descriptor.epoch != session.epoch or descriptor.identity.id != session.connection.identity.id or
        !eql(u8, &descriptor.identity.name, &session.connection.identity.name)) return error.MappingMismatch;
    session.arena = arena;
}

/// Prepare any already-defined operation. Copies a complete, unfragmented logical
/// payload into caller storage. Does not dispatch it or mutate the shared catalog.
/// Bootstrap must use sessionBootstrap; all other operations require a live session.
pub fn requestPrepare(session: *Session, call: *Call, request: Request, payload: []const u8) ApiError!void {
    if (request.operation == .none) return error.InvalidArgument;
    try apiPrepare(session, call, request, payload, &.{});
}

/// Produce the next frame without advancing. Repeated calls before callFrameSent
/// produce the same frame, allowing transport backpressure without losing bytes.
/// The caller uses Message.encode and supplies its own send mechanism.
pub fn callFrame(session: *const Session, call: *Call, output: *Message) ApiError!void {
    try apiCallSession(session, call);
    if (call.phase != .ready) return error.InvalidState;
    const status = output.requestFragment(
        call.request_header.session_id,
        call.request_header.epoch,
        call.request_header.request_id,
        call.request,
        call.request_buffer[0..call.request_size],
        call.send_offset,
    );
    if (status != .ok) return error.InvalidRequest;
    call.offered_size = output.header.payload_size;
    call.frame_offered = true;
}

/// Call only after the entire offered frame has actually been transmitted.
/// Partial transport writes must finish before acknowledging this frame.
pub fn callFrameSent(session: *const Session, call: *Call) ApiError!void {
    try apiCallSession(session, call);
    if (call.phase != .ready or !call.frame_offered) return error.InvalidState;
    call.send_offset += call.offered_size;
    call.frame_offered = false;
    if (call.send_offset == call.request_size) call.phase = .waiting;
}

/// Feed one decoded response frame after the request has been fully sent.
/// Success means accepted bytes, NOT successful execution. Check callComplete and
/// then callResult. Events are separate and must be routed to sessionEvent instead.
/// A wrong request/session frame is rejected without consuming the pending reply.
pub fn callAccept(session: *const Session, call: *Call, frame: *const Message) ApiError!void {
    try apiCallSession(session, call);
    if (call.phase != .waiting and call.phase != .receiving) return error.InvalidState;
    if (frame.header.kind != .response) return error.UnexpectedMessage;
    const original: Message = .{ .header = call.request_header, .body = .{ .request = call.request } };
    if (!frame.isReplyTo(&original)) return error.InvalidResponse;
    if (call.request.operation == .none and frame.body.response.code == .ok and
        (frame.header.fragment_offset != 0 or frame.header.total_size != frame.header.payload_size)) return error.InvalidResponse;
    const status = call.assembly.append(frame);
    if (status != .ok) {
        call.validation_code = status;
        call.phase = .failed;
        return error.InvalidResponse;
    }
    call.phase = .receiving;
    if (!call.assembly.complete()) return;
    const result = call.assembly.body.response;
    const checked = result.validateFor(&call.request, call.request_buffer[0..call.request_size], call.assembly.payload().?);
    if (checked != .ok) {
        call.validation_code = checked;
        call.phase = .failed;
        return error.InvalidResponse;
    }
    call.response = result;
    call.phase = .complete;
}

pub fn callComplete(call: *const Call) bool {
    return call.phase == .complete;
}

/// Preserve remote errors as Code, including .busy and application-defined codes.
/// Incomplete/local-error calls are distinguished with ApiError.InvalidState.
pub fn callResult(call: *const Call) ApiError!Code {
    if (!callComplete(call)) return error.InvalidState;
    return call.response.code;
}

/// Borrow completed response bytes, including diagnostic bytes on a failed reply.
/// Use callResult to determine what those bytes mean before interpreting them.
pub fn callPayload(call: *const Call) ApiError![]const u8 {
    if (!callComplete(call)) return error.InvalidState;
    return call.assembly.payload() orelse return error.InvalidState;
}

/// Validate and copy one event. Does not decide which subscriber receives it,
/// change a subscription, validate a live subject, or authorize the event.
/// A release event can legitimately name an already-destroyed Object.
pub fn sessionEvent(session: *const Session, frame: *const Message) ApiError!Message.Event {
    if (session.phase != .connected) return error.InvalidState;
    if (frame.header.kind != .event) return error.UnexpectedMessage;
    if (frame.header.session_id != session.id or frame.header.epoch != session.epoch) return error.WrongSession;
    if (frame.validate() != .ok) return error.InvalidResponse;
    return frame.body.event;
}

// -----------------------------------------------------------------------------
// Entity operations: preparation only; the caller executes each Call.
// -----------------------------------------------------------------------------

pub const NamespaceInitOptions = struct {
    identity: Identity,
    from: HandleReference = .{},
};

pub fn namespaceInit(session: *Session, call: *Call, options: NamespaceInitOptions) ApiError!void {
    try apiRecord(session, call, .{
        .operation = .create,
        .from = options.from,
        .to = session.connection.daemon,
    }, Request.Create{ .type = .namespace, .identity = options.identity });
}

pub const StreamInitOptions = struct {
    namespace: Handle(Namespace),
    identity: Identity,
    from: HandleReference = .{},
};

pub fn streamInit(session: *Session, call: *Call, options: StreamInitOptions) ApiError!void {
    try apiRecord(session, call, .{
        .operation = .create,
        .from = options.from,
        .to = HandleReference.init(Namespace, options.namespace),
    }, Request.Create{ .type = .stream, .identity = options.identity });
}

pub const ObjectInitOptions = struct {
    stream: Handle(Stream),
    identity: Identity,
    from: HandleReference = .{},
};

/// Create one fixed-size, zero-filled Object. Zig field defaults are NOT applied
/// remotely. Follow with objectWrite to supply a value, then publish explicitly.
pub fn objectInit(comptime T: type, session: *Session, call: *Call, options: ObjectInitOptions) ApiError!void {
    comptime apiValueType(T);
    try objectInitBytes(session, call, options, .bytes, @intCast(@sizeOf(T)), @intCast(@sizeOf(T)));
}

pub fn objectInitBytes(
    session: *Session,
    call: *Call,
    options: ObjectInitOptions,
    format: Object.Format,
    min_size: u16,
    max_size: u16,
) ApiError!void {
    try apiRecord(session, call, .{
        .operation = .create,
        .from = options.from,
        .to = HandleReference.init(Stream, options.stream),
    }, Request.Create{
        .type = .object,
        .identity = options.identity,
        .format = format,
        .min_size = min_size,
        .max_size = max_size,
    });
}

/// Extract a created entity's typed handle only after a validated successful reply.
/// T is Namespace, Stream or Object. A Daemon is initialized by the host instead.
pub fn entityCreated(comptime T: type, call: *const Call) ApiError!Handle(T) {
    if (T != Namespace and T != Stream and T != Object) @compileError("entityCreated requires Namespace, Stream or Object");
    try apiSuccess(call, .create);
    const parameters = readPayload(Request.Create, call.request_buffer[0..call.request_size]).?;
    if (parameters.type != handleType(T)) return error.TypeMismatch;
    return call.response.result.typed(T) orelse return error.TypeMismatch;
}

pub const ObjectReadOptions = struct {
    object: Handle(Object),
    from: HandleReference = .{},
    revision: u64 = 0,
};

/// Prepare a typed read. objectReadResult returns T after external execution.
/// Both peers must agree on the same payload type; byte count is not a schema ID.
pub fn objectRead(comptime T: type, session: *Session, call: *Call, options: ObjectReadOptions) ApiError!void {
    comptime apiValueType(T);
    try objectReadBytes(session, call, options, 0, @intCast(@sizeOf(T)));
}

pub fn objectReadBytes(session: *Session, call: *Call, options: ObjectReadOptions, offset: u16, length: u16) ApiError!void {
    try apiRecord(session, call, .{
        .operation = .read,
        .from = options.from,
        .to = HandleReference.init(Object, options.object),
    }, Request.Read{ .mode = .data, .offset = offset, .length = length, .revision = options.revision });
}

pub fn objectReadResult(comptime T: type, call: *const Call) ApiError!T {
    comptime apiValueType(T);
    try apiSuccess(call, .read);
    const parameters = readPayload(Request.Read, call.request_buffer[0..call.request_size]).?;
    if (parameters.mode != .data or call.request.to.type != .object) return error.TypeMismatch;
    const payload = try callPayload(call);
    if (payload.len != @sizeOf(T)) return error.TypeMismatch;
    return loadValue(T, payload);
}

pub const ObjectWriteOptions = struct {
    object: Handle(Object),
    from: HandleReference = .{},
    expected_revision: u64 = 0,
};

/// Copy a fixed-layout value into request storage. Does not write the arena or
/// publish, and does not retain value's pointer after returning.
pub fn objectWrite(comptime T: type, session: *Session, call: *Call, options: ObjectWriteOptions, value: *const T) ApiError!void {
    comptime apiValueType(T);
    try objectWriteBytes(session, call, options, 0, @intCast(@sizeOf(T)), bytesOf(T, value));
}

pub fn objectWriteBytes(
    session: *Session,
    call: *Call,
    options: ObjectWriteOptions,
    offset: u16,
    size: u16,
    data: []const u8,
) ApiError!void {
    const parameters: Request.Write = .{ .offset = offset, .size = size, .expected_revision = options.expected_revision };
    try apiPrepare(session, call, .{
        .operation = .write,
        .from = options.from,
        .to = HandleReference.init(Object, options.object),
    }, bytesOf(Request.Write, &parameters), data);
}

pub const DiscoverOptions = struct {
    parent: HandleReference,
    from: HandleReference = .{},
    query: Request.Discover,
};

pub fn entityDiscover(session: *Session, call: *Call, options: DiscoverOptions) ApiError!void {
    try apiRecord(session, call, .{ .operation = .discover, .from = options.from, .to = options.parent }, options.query);
}

/// Copy discovered Items into caller storage. Revision and next_cursor remain
/// available as call.response.revision and call.response.next_cursor.
pub fn discoveryResult(call: *const Call, items: []Response.Item) ApiError!usize {
    try apiSuccess(call, .discover);
    const count: usize = call.response.item_count;
    if (items.len < count) return error.BufferTooSmall;
    const payload = try callPayload(call);
    for (items[0..count], 0..) |*item, index| item.* = loadValue(Response.Item, payload[index * @sizeOf(Response.Item) ..]);
    return count;
}

pub const TargetOptions = struct {
    target: HandleReference,
    from: HandleReference = .{},
};

pub fn entityAcquire(session: *Session, call: *Call, options: TargetOptions, permissions: u16) ApiError!void {
    try apiRecord(session, call, .{ .operation = .acquire, .from = options.from, .to = options.target }, Request.Acquire{ .permissions = permissions });
}

pub fn objectAccessResult(call: *const Call) ApiError!Response.Access {
    try apiSuccess(call, .acquire);
    if (call.response.result.type != .object) return error.TypeMismatch;
    return readPayload(Response.Access, try callPayload(call)) orelse return error.InvalidResponse;
}

pub fn entityReadDescriptor(session: *Session, call: *Call, options: TargetOptions) ApiError!void {
    try apiRecord(session, call, .{ .operation = .read, .from = options.from, .to = options.target }, Request.Read{ .mode = .descriptor });
}

pub fn descriptorResult(comptime T: type, call: *const Call) ApiError!T {
    const kind = handleType(T);
    try apiSuccess(call, .read);
    const parameters = readPayload(Request.Read, call.request_buffer[0..call.request_size]).?;
    if (parameters.mode != .descriptor or call.response.result.type != kind) return error.TypeMismatch;
    const payload = try callPayload(call);
    if (payload.len != @sizeOf(T)) return error.TypeMismatch;
    return loadValue(T, payload);
}

pub fn entityPublish(session: *Session, call: *Call, options: TargetOptions, parameters: Request.Publish) ApiError!void {
    try apiRecord(session, call, .{ .operation = .publish, .from = options.from, .to = options.target }, parameters);
}

pub const StreamSubscribeOptions = struct {
    stream: Handle(Stream),
    from: HandleReference = .{},
    objects: ObjectSet = .all,
    events: u16 = @backingInt(Operation.publish),
    include_scope: bool = true,
    after_revision: u64 = 0,
};

pub fn streamSubscribe(session: *Session, call: *Call, options: StreamSubscribeOptions) ApiError!void {
    try entitySubscribe(session, call, .{
        .target = HandleReference.init(Stream, options.stream),
        .from = options.from,
    }, .{
        .objects = options.objects,
        .events = options.events,
        .include_scope = @intFromBool(options.include_scope),
        .after_revision = options.after_revision,
    });
}

/// Generic subscription to one Daemon/Namespace/Stream/Object scope.
/// Request.Subscribe validates the appropriate ObjectSet and include_scope rules.
/// The host records the subscription only after actually accepting the request.
pub fn entitySubscribe(session: *Session, call: *Call, options: TargetOptions, parameters: Request.Subscribe) ApiError!void {
    try apiRecord(session, call, .{ .operation = .subscribe, .from = options.from, .to = options.target }, parameters);
}

pub fn entityUnsubscribe(session: *Session, call: *Call, options: TargetOptions) ApiError!void {
    try entitySubscribe(session, call, options, .{ .enabled = 0 });
}

pub fn entityAdminister(session: *Session, call: *Call, options: TargetOptions, parameters: Request.Administer) ApiError!void {
    try apiRecord(session, call, .{ .operation = .administer, .from = options.from, .to = options.target }, parameters);
}

pub fn entityRelease(session: *Session, call: *Call, options: TargetOptions, mode: Request.Release.Mode) ApiError!void {
    try apiRecord(session, call, .{ .operation = .release, .from = options.from, .to = options.target }, Request.Release{ .mode = mode });
}

/// Prepare an opaque command. The caller's executor supplies routing/completion.
/// Commands may use multiple frames, up to Message.max_transfer_bytes total.
pub fn entityControl(session: *Session, call: *Call, options: TargetOptions, command: u32, data: []const u8) ApiError!void {
    const parameters: Request.Control = .{ .command = command };
    try apiPrepare(session, call, .{ .operation = .control, .from = options.from, .to = options.target }, bytesOf(Request.Control, &parameters), data);
}

// -----------------------------------------------------------------------------
// Fixed-layout value gate. Byte-oriented APIs accept explicit serialized bytes.
// -----------------------------------------------------------------------------

/// Conservative typed-copy profile: 8/16/32/64-bit integers, f32/f64, arrays
/// without sentinels, non-exhaustive enums, and pointer-free extern structs with
/// NO implicit padding (use explicit reserved byte fields where needed).
/// This validates representation, not application meaning or data provenance.
pub fn valueTypeSupported(comptime T: type) bool {
    return switch (@typeInfo(T)) {
        .int => |info| info.bits == 8 or info.bits == 16 or info.bits == 32 or info.bits == 64,
        .float => |info| info.bits == 32 or info.bits == 64,
        .array => |info| info.sentinel_ptr == null and valueTypeSupported(info.child),
        .@"enum" => |info| info.mode == .nonexhaustive and valueTypeSupported(info.tag_type),
        .@"struct" => |info| blk: {
            if (info.layout != .@"extern") break :blk false;
            var end: usize = 0;
            inline for (info.field_names, info.field_types, info.field_attrs) |name, Field, attributes| {
                if (attributes.@"comptime" or !valueTypeSupported(Field)) break :blk false;
                if (@offsetOf(T, name) != end) break :blk false;
                end += @sizeOf(Field);
            }
            break :blk end == @sizeOf(T);
        },
        else => false,
    };
}

fn apiValueType(comptime T: type) void {
    if (!valueTypeSupported(T)) @compileError("typed Object API needs a pointer-free fixed-layout type with no implicit padding; otherwise use explicit bytes");
    if (@sizeOf(T) == 0 or @sizeOf(T) > Layout.object_bytes) @compileError("typed Object value must occupy 1..4096 bytes");
}

fn apiPrepare(session: *Session, call: *Call, request: Request, prefix: []const u8, data: []const u8) ApiError!void {
    if (call.phase != .idle) return error.InvalidState;
    if (request.operation == .none) {
        if (session.phase != .idle) return error.InvalidState;
    } else if (session.phase != .connected) return error.InvalidState;
    if (session.next_request_id == 0) return error.RequestIdsExhausted;
    if (prefix.len > Message.max_transfer_bytes or data.len > Message.max_transfer_bytes - prefix.len) return error.InvalidArgument;
    const length = prefix.len + data.len;
    if (length > call.request_buffer.len) return error.BufferTooSmall;
    const target = call.request_buffer[0..length];
    if (apiOverlap(target, prefix) or apiOverlap(target, data)) return error.BufferOverlap;
    @memcpy(target[0..prefix.len], prefix);
    @memcpy(target[prefix.len..], data);

    var first: Message = .{};
    const status = first.requestFragment(session.id, session.epoch, session.next_request_id, request, target, 0);
    if (status != .ok) {
        call.validation_code = status;
        return error.InvalidRequest;
    }
    call.session = session;
    call.session_generation = session.generation;
    call.daemon_id = session.connection.identity.id;
    call.request_header = first.header;
    call.request = request;
    call.request_size = length;
    call.validation_code = .ok;
    call.phase = .ready;
    // Zero permanently exhausts this Session lifetime; never wrap back to 1.
    session.next_request_id +%= 1;
}

fn apiRecord(session: *Session, call: *Call, request: Request, parameters: anytype) ApiError!void {
    const T = @TypeOf(parameters);
    try apiPrepare(session, call, request, bytesOf(T, &parameters), &.{});
}

fn apiCallSession(session: *const Session, call: *const Call) ApiError!void {
    if (call.session != session) return error.WrongSession;
    if (call.session_generation != session.generation) return error.StaleCall;
    if (call.request.operation == .none) {
        if (session.phase != .connecting or session.bootstrap_request_id != call.request_header.request_id) return error.InvalidState;
    } else {
        if (session.phase != .connected) return error.InvalidState;
        if (call.request_header.session_id != session.id or call.request_header.epoch != session.epoch or
            call.daemon_id != session.connection.identity.id) return error.WrongSession;
    }
}

fn apiSuccess(call: *const Call, operation: Operation) ApiError!void {
    if (!callComplete(call)) return error.InvalidState;
    // Result extraction also rejects state forgotten by sessionDisconnect.
    const session = call.session orelse return error.InvalidState;
    if (session.generation != call.session_generation) return error.StaleCall;
    if (call.request.operation != operation or call.response.operation != operation) return error.TypeMismatch;
    if (call.response.code != .ok) return error.OperationFailed;
}

fn apiExpectedDaemonId(session: *const Session) ?u64 {
    if (session.options.expected_daemon_id) |id| return id;
    return switch (session.options.endpoint) {
        .identity => |id| id,
        else => null,
    };
}

fn apiTextValid(text: []const u8) bool {
    if (text.len == 0) return false;
    for (text) |byte| if (byte == 0) return false;
    return true;
}

fn apiOverlap(a: []const u8, b: []const u8) bool {
    if (a.len == 0 or b.len == 0) return false;
    const left = @intFromPtr(a.ptr);
    const right = @intFromPtr(b.ptr);
    return if (left <= right) right - left < a.len else left - right < b.len;
}

// Lock the intended ABI representation. These are not runtime tests or C exports.
comptime {
    if (@sizeOf(usize) != 8 or @alignOf(u64) != 8 or @sizeOf(c_ulong) != 8 or
        @sizeOf(c_uint) != 4 or @sizeOf(c_ushort) != 2)
        @compileError("Sockman ABI 0.0.1 requires the 64-bit LP64 profile");
    if (@sizeOf(Magic) != 4 or @sizeOf(Version) != 4 or @sizeOf(Identity) != 72 or
        @sizeOf(Handle(Object)) != 4 or @sizeOf(HandleReference) != 8 or
        @sizeOf(PermissionInit(Stream, Object)) != 12 or
        @sizeOf(ObjectSet) != 32 or @alignOf(ObjectSet) != 8)
        @compileError("Sockman primitive ABI layout changed");
    if (@sizeOf(Daemon) != 88 or @sizeOf(Namespace) != 608 or
        @sizeOf(Stream) != 3688 or @sizeOf(Object) != 112)
        @compileError("Sockman entity ABI layout changed");
    if (@sizeOf(Request) != 20 or @sizeOf(Response) != 32 or
        @sizeOf(Message.Event) != 40 or @sizeOf(Message.Header) != 48 or
        @sizeOf(Message.Body) != 40)
        @compileError("Sockman message ABI layout changed");
    if (@offsetOf(Message.Header, "request_id") != 16 or
        @offsetOf(Message.Header, "total_size") != 40 or
        @offsetOf(Message, "body") != 48 or @offsetOf(Message, "payload") != 88)
        @compileError("Sockman message field offsets changed");
    if (@sizeOf(Request.Discover) != 96 or @sizeOf(Request.Create) != 80 or
        @sizeOf(Request.Write) != 16 or @sizeOf(Request.Subscribe) != 48 or
        @offsetOf(Request.Subscribe, "objects") != 16 or
        @sizeOf(Response.Connection) != 112 or @sizeOf(Response.Item) != 88 or
        @sizeOf(Response.Access) != 16 or Response.max_discovery_items != 46)
        @compileError("Sockman parameter ABI layout changed");
    if (Layout.object_capacity != 65536 or Layout.stream_bytes != 1048576 or
        Layout.object_data_bytes != 268435456 or
        @offsetOf(AddressSpace, "object_data") % 4096 != 0 or
        @sizeOf(AddressSpace) > 0xffff_ffff)
        @compileError("Sockman arena alignment or address range changed");
    if (@sizeOf(Stream) > Message.max_payload_bytes)
        @compileError("Stream descriptor no longer fits one response frame");
}

// Testing block for importing the sockman test file
test {
    _ = @import("Sockman_test.zig");
}
