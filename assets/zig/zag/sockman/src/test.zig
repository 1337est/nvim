//! Representation tests plus a separate in-memory driver for the procedural API.
//! Replies in API tests are explicitly constructed here, not produced by a broker.
//! These tests do not exercise sockets, shared-memory isolation, or authorization.

const std = @import("std");
const P = @import("Sockman.zig");
const expect = std.testing.expect;
const equal = std.testing.expectEqual;

const Fixture = struct {
    arena: *P.AddressSpace,
    daemon: P.Handle(P.Daemon),
    namespace: P.Handle(P.Namespace),
    stream: P.Handle(P.Stream),
    object: P.Handle(P.Object),

    fn init() !Fixture {
        const arena = try std.heap.page_allocator.create(P.AddressSpace);
        // Touch only metadata and the one data page used by this test fixture.
        arena.daemon = .{};
        for (&arena.namespaces.slots) |*slot| slot.* = .{};
        for (&arena.streams.slots) |*slot| slot.* = .{};
        for (&arena.objects.slots) |*slot| slot.* = .{};
        @memset(&arena.data_padding, 0);
        const daemon = P.Handle(P.Daemon).init(0, 1);
        const namespace = P.Handle(P.Namespace).init(2, 3);
        const stream = P.Handle(P.Stream).init(7, 4);
        const object = P.Handle(P.Object).initObject(stream, 0, 9);
        arena.daemon = .{
            .generation = daemon.generation(),
            .state = .active,
            .value = .{ .identity = P.Identity.init(1, "sockman").?, .epoch = 10, .pid = 100 },
        };
        arena.namespaces.slots[namespace.index()] = .{
            .generation = namespace.generation(),
            .state = .active,
            .value = .{ .identity = P.Identity.init(2, "scope-a").?, .daemon = daemon, .pid = 101 },
        };
        arena.streams.slots[stream.index()] = .{
            .generation = stream.generation(),
            .state = .active,
            .value = .{ .identity = P.Identity.init(50, "source").?, .namespace = namespace, .pid = 101 },
        };
        arena.objects.slots[object.index()] = .{
            .generation = object.generation(),
            .state = .active,
            .value = .{
                .identity = P.Identity.init(0, "foo").?,
                .namespace = namespace,
                .stream = stream,
                .pid = 101,
                .revision = 1,
            },
        };
        @memset(&arena.object_data[object.index()], 0);
        return .{ .arena = arena, .daemon = daemon, .namespace = namespace, .stream = stream, .object = object };
    }

    fn deinit(self: Fixture) void {
        std.heap.page_allocator.destroy(self.arena);
    }
};

fn daemonRef() P.HandleReference {
    return P.HandleReference.init(P.Daemon, P.Handle(P.Daemon).init(0, 1));
}

fn namespaceRef() P.HandleReference {
    return P.HandleReference.init(P.Namespace, P.Handle(P.Namespace).init(2, 3));
}

fn streamRef() P.HandleReference {
    return P.HandleReference.init(P.Stream, P.Handle(P.Stream).init(7, 4));
}

fn objectRef(index: u8) P.HandleReference {
    return P.HandleReference.init(P.Object, P.Handle(P.Object).initObject(streamRef().typed(P.Stream).?, index, 9));
}

fn requestMessage(request: P.Request, payload: []const u8) !P.Message {
    var message: P.Message = .{};
    try equal(P.Code.ok, message.initRequest(7, 10, 1, request, payload));
    return message;
}

test "protocol: identity zero means local Object zero, not empty Namespace" {
    const identity = P.Identity.init(0, "foo").?;
    try expect(identity.validFor(.object));
    try expect(!identity.validFor(.namespace));
    try expect(!identity.validFor(.stream));
    try expect(!identity.validFor(.daemon));
    try expect((P.Identity.init(255, "last").?).validFor(.object));
    try expect(!(P.Identity.init(256, "outside").?).validFor(.object));
    const long_name: [65]u8 = @splat('x');
    try expect(P.Identity.init(1, &long_name) == null);
}

test "protocol: typed handles validate capacity and generation" {
    try expect(!P.Handle(P.Daemon).init(1, 1).valid());
    try expect(!P.Handle(P.Namespace).init(8, 1).valid());
    try expect(!P.Handle(P.Stream).init(256, 1).valid());
    try expect(!P.Handle(P.Object).init(0, 0).valid());
    try expect(P.Handle(P.Object).init(65535, 65535).valid());
    try expect(daemonRef().typed(P.Daemon) != null);
    try expect(daemonRef().typed(P.Namespace) == null);
    var invalid = daemonRef();
    invalid.reserved = 1;
    try expect(!invalid.valid());
    try expect((P.HandleReference{}).empty());
    try expect(!(P.HandleReference{}).valid());
}

test "protocol: exhaustive 256 by 256 Object handle and address mapping" {
    var stream_index: u16 = 0;
    while (stream_index < 256) : (stream_index += 1) {
        const stream = P.Handle(P.Stream).init(stream_index, 11);
        var local_index: u16 = 0;
        while (local_index < 256) : (local_index += 1) {
            const object = P.Handle(P.Object).initObject(stream, @intCast(local_index), 23);
            try equal(@as(u16, 23), object.generation());
            try equal(@as(u8, @intCast(stream_index)), object.streamIndex());
            try equal(@as(u8, @intCast(local_index)), object.objectIndex());
            try equal((stream_index << 8) | local_index, object.index());
            const address = P.ObjectAddress.fromHandle(object).?;
            try equal(@as(u32, object.index()) << 12, address.offset);
            try equal(object.streamIndex(), address.streamIndex());
            try equal(object.objectIndex(), address.objectIndex());
            try equal(@as(u12, 0), address.byteOffset());
        }
    }
    const last = P.ObjectAddress.init(255, 255, 4095).?;
    try equal(@as(u32, 0x0fff_ffff), last.offset);
    try expect(last.valid());
    try expect(P.ObjectAddress.init(0, 0, 4096) == null);
    try expect(!(P.ObjectAddress{ .offset = 0x1000_0000 }).valid());
}

test "protocol: ObjectSet boundary bits and ascending iteration" {
    const indices = [_]u8{ 0, 63, 64, 127, 128, 191, 192, 255 };
    const set = P.ObjectSet.init(indices);
    for (set.words) |word| try equal(@as(u64, 0x8000_0000_0000_0001), word);
    try equal(@as(u16, 8), set.count());
    var iterator = set.iterator();
    for (indices) |index| try equal(@as(?u8, index), iterator.next());
    try expect(iterator.next() == null);
    try equal(@as(u16, 256), P.ObjectSet.all.count());
    try expect(P.ObjectSet.none.isEmpty());
}

test "protocol: ObjectSet compile-time enum inputs and runtime updates" {
    const Objects = enum(u8) { foo = 0, bar = 1, last = 255 };
    var set = P.ObjectSet.init(.{ Objects.foo, Objects.bar });
    set = set.add(.{Objects.last}).remove(.{Objects.bar});
    try expect(set.contains(0) and set.contains(255) and !set.contains(1));
    set.set(127);
    set.unset(0);
    try expect(!set.contains(0) and set.contains(127));
    try equal(@as(u16, 2), set.count());
}

test "protocol: ObjectSet union intersection difference and subset" {
    const a = P.ObjectSet.init(.{ 0, 64, 255 });
    const b = P.ObjectSet.init(.{ 1, 64 });
    try expect(a.intersects(b));
    try expect(a.intersection(b).eql(P.ObjectSet.init(.{64})));
    try expect(a.difference(b).eql(P.ObjectSet.init(.{ 0, 255 })));
    try expect(a.unionWith(b).eql(P.ObjectSet.init(.{ 0, 1, 64, 255 })));
    try expect(P.ObjectSet.all.containsAll(a));
    try expect(!a.containsAll(b));
}

test "protocol: same Stream ID in different Namespaces and Object ID in different Streams" {
    const f = try Fixture.init();
    defer f.deinit();
    const other_ns = P.Handle(P.Namespace).init(3, 1);
    const other_stream = P.Handle(P.Stream).init(8, 2);
    const other_object = P.Handle(P.Object).initObject(other_stream, 0, 5);
    f.arena.namespaces.slots[3] = .{
        .generation = 1,
        .state = .active,
        .value = .{ .identity = P.Identity.init(3, "other").?, .daemon = f.daemon, .pid = 102 },
    };
    f.arena.streams.slots[8] = .{
        .generation = 2,
        .state = .active,
        .value = .{ .identity = P.Identity.init(50, "source").?, .namespace = other_ns, .pid = 102 },
    };
    f.arena.objects.slots[other_object.index()] = .{
        .generation = 5,
        .state = .active,
        .value = .{ .identity = P.Identity.init(0, "foo").?, .namespace = other_ns, .stream = other_stream, .pid = 102, .revision = 1 },
    };
    try equal(f.namespace.value, f.arena.findNamespace(f.daemon, 2).?.value);
    try equal(f.stream.value, f.arena.findStream(f.namespace, 50).?.value);
    try equal(other_stream.value, f.arena.findStream(other_ns, 50).?.value);
    try equal(f.object.value, f.arena.findObject(f.stream, 0).?.value);
    try equal(other_object.value, f.arena.findObject(other_stream, 0).?.value);
    try expect(f.arena.findObject(f.stream, 1) == null);
    try equal(@as(u32, 7 << 20), f.arena.objectAddress(f.object).?.offset);
}

test "protocol: Object resolution rejects wrong physical parent or logical index" {
    const f = try Fixture.init();
    defer f.deinit();
    const value = &f.arena.objects.slots[f.object.index()].value;
    try expect(f.arena.getObjectConst(f.object) != null);
    value.identity.id = 1;
    try expect(f.arena.getObjectConst(f.object) == null);
    value.identity.id = 0;
    value.stream = P.Handle(P.Stream).init(8, 4);
    try expect(f.arena.getObjectConst(f.object) == null);
    value.stream = f.stream;
    value.namespace = P.Handle(P.Namespace).init(3, 3);
    try expect(f.arena.getObjectConst(f.object) == null);
}

test "protocol: parent Stream generation is checked independently of Object generation" {
    const f = try Fixture.init();
    defer f.deinit();
    try expect(f.arena.getObjectConst(f.object) != null);
    f.arena.streams.slots[f.stream.index()].generation += 1;
    try expect(f.arena.getObjectConst(f.object) == null);
    try expect(f.arena.findObject(f.stream, 0) == null);
    const new_stream = P.Handle(P.Stream).init(f.stream.index(), f.stream.generation() + 1);
    try expect(f.arena.findObject(new_stream, 0) == null);
    // Correct replacement: advance the Object slot generation, never reset it.
    const slot = &f.arena.objects.slots[f.object.index()];
    slot.generation += 1;
    slot.value.stream = new_stream;
    try expect(f.arena.getObjectConst(f.object) == null);
    const replacement = f.arena.findObject(new_stream, 0).?;
    try expect(replacement.value != f.object.value);
    try equal(f.object.index(), replacement.index());
}

test "protocol: Daemon and Namespace ancestors must remain live" {
    const f = try Fixture.init();
    defer f.deinit();
    try equal(f.daemon.value, f.arena.daemonHandle().?.value);
    f.arena.namespaces.slots[f.namespace.index()].generation += 1;
    try expect(f.arena.getStreamConst(f.stream) == null);
    f.arena.namespaces.slots[f.namespace.index()].generation -= 1;
    f.arena.daemon.state = .retired;
    try expect(f.arena.daemonHandle() == null);
    try expect(f.arena.getObjectConst(f.object) == null);
}

test "protocol: Create requires the direct parent and exact local Object ID" {
    var p: P.Request.Create = .{ .type = .object, .identity = P.Identity.init(0, "foo").? };
    var r: P.Request = .{ .operation = .create, .to = streamRef() };
    try equal(P.Code.ok, r.validate(P.bytesOf(P.Request.Create, &p)));
    p.identity.id = 256;
    try equal(P.Code.invalid, r.validate(P.bytesOf(P.Request.Create, &p)));
    p.type = .namespace;
    p.identity.id = 2;
    r.to = daemonRef();
    try equal(P.Code.ok, r.validate(P.bytesOf(P.Request.Create, &p)));
    r.to = .{};
    try equal(P.Code.invalid, r.validate(P.bytesOf(P.Request.Create, &p)));
    p.type = .daemon;
    r.to = daemonRef();
    try equal(P.Code.unsupported, r.validate(P.bytesOf(P.Request.Create, &p)));
}

test "protocol: Discover explicitly matches Object zero and limits local cursors" {
    var p: P.Request.Discover = .{ .type = .object, .match_id = 1, .id = 0 };
    const r: P.Request = .{ .operation = .discover, .to = streamRef() };
    try equal(P.Code.ok, r.validate(P.bytesOf(P.Request.Discover, &p)));
    p.cursor = 255;
    try equal(P.Code.ok, r.validate(P.bytesOf(P.Request.Discover, &p)));
    p.cursor = 256;
    try equal(P.Code.invalid, r.validate(P.bytesOf(P.Request.Discover, &p)));
    p.cursor = 0;
    p.match_id = 0;
    p.id = 1;
    try equal(P.Code.invalid, r.validate(P.bytesOf(P.Request.Discover, &p)));
    p.id = 0;
    p.type = .stream;
    try equal(P.Code.invalid, r.validate(P.bytesOf(P.Request.Discover, &p)));
}

test "protocol: discovery Items carry the exact parent and local Object ID" {
    var item: P.Response.Item = .{ .reference = objectRef(0), .parent = streamRef(), .identity = P.Identity.init(0, "foo").? };
    try expect(item.valid());
    const p: P.Request.Discover = .{ .type = .object, .match_id = 1, .id = 0 };
    const r: P.Request = .{ .operation = .discover, .to = streamRef() };
    const response: P.Response = .{ .operation = .discover, .item_count = 1, .revision = 3 };
    try equal(P.Code.ok, response.validateFor(&r, P.bytesOf(P.Request.Discover, &p), P.bytesOf(P.Response.Item, &item)));
    item.parent.handle +%= 1 << 16; // same physical parent slot, wrong parent lifetime
    try expect(item.valid()); // representation alone cannot know live generation
    try equal(P.Code.invalid, response.validateFor(&r, P.bytesOf(P.Request.Discover, &p), P.bytesOf(P.Response.Item, &item)));
    item.parent = streamRef();
    item.identity.id = 1;
    try expect(!item.valid());
}

test "protocol: discovery rejects duplicate or descending local slots" {
    const p: P.Request.Discover = .{ .type = .object };
    const r: P.Request = .{ .operation = .discover, .to = streamRef() };
    const response: P.Response = .{ .operation = .discover, .item_count = 2, .revision = 3 };
    var items = [_]P.Response.Item{
        .{ .reference = objectRef(0), .parent = streamRef(), .identity = P.Identity.init(0, "foo").? },
        .{ .reference = objectRef(1), .parent = streamRef(), .identity = P.Identity.init(1, "bar").? },
    };
    try equal(P.Code.ok, response.validateFor(&r, P.bytesOf(P.Request.Discover, &p), P.bytesOf(@TypeOf(items), &items)));
    items[1] = items[0];
    try equal(P.Code.invalid, response.validateFor(&r, P.bytesOf(P.Request.Discover, &p), P.bytesOf(@TypeOf(items), &items)));
}

test "protocol: subscription ObjectSet selection and scope events are independent" {
    const f = try Fixture.init();
    defer f.deinit();
    var p: P.Request.Subscribe = .{ .include_scope = 0, .objects = P.ObjectSet.init(.{0}) };
    const r: P.Request = .{ .operation = .subscribe, .to = streamRef() };
    try equal(P.Code.ok, r.validate(P.bytesOf(P.Request.Subscribe, &p)));
    try expect(p.matches(f.arena, streamRef(), objectRef(0), .publish));
    try expect(!p.matches(f.arena, streamRef(), streamRef(), .publish));
    try expect(!p.matches(f.arena, streamRef(), objectRef(0), .write));
    p.objects = .none;
    try equal(P.Code.invalid, r.validate(P.bytesOf(P.Request.Subscribe, &p)));
    p.include_scope = 1;
    try equal(P.Code.ok, r.validate(P.bytesOf(P.Request.Subscribe, &p)));
    try expect(p.matches(f.arena, streamRef(), streamRef(), .publish));
    try expect(!p.matches(f.arena, streamRef(), objectRef(0), .publish));
}

test "protocol: non-Stream subscription rejects ambiguous ObjectSet" {
    var p: P.Request.Subscribe = .{ .objects = P.ObjectSet.init(.{0}) };
    const r: P.Request = .{ .operation = .subscribe, .to = namespaceRef() };
    try equal(P.Code.invalid, r.validate(P.bytesOf(P.Request.Subscribe, &p)));
    p.objects = .all;
    try equal(P.Code.ok, r.validate(P.bytesOf(P.Request.Subscribe, &p)));
    p.enabled = 0;
    p.events = 0;
    p.objects = .none;
    try equal(P.Code.ok, r.validate(P.bytesOf(P.Request.Subscribe, &p)));
}

test "protocol: Create response must identify the requested Stream slot and local Object" {
    const p: P.Request.Create = .{ .type = .object, .identity = P.Identity.init(0, "foo").? };
    const r: P.Request = .{ .operation = .create, .to = streamRef() };
    var response: P.Response = .{ .operation = .create, .result = objectRef(0), .revision = 1 };
    try equal(P.Code.ok, response.validateFor(&r, P.bytesOf(P.Request.Create, &p), &.{}));
    response.result = objectRef(1);
    try equal(P.Code.invalid, response.validateFor(&r, P.bytesOf(P.Request.Create, &p), &.{}));
    response.result.handle = (@as(u32, 9) << 16) | (@as(u32, 8) << 8);
    try equal(P.Code.invalid, response.validateFor(&r, P.bytesOf(P.Request.Create, &p), &.{}));
}

test "protocol: bootstrap returns the explicit Daemon descriptor identity and epoch" {
    const descriptor: P.Daemon = .{ .identity = P.Identity.init(22, "broker").?, .epoch = 10, .pid = 100 };
    var request: P.Message = .{};
    try equal(P.Code.ok, request.initRequest(0, 0, 1, .{}, &.{}));
    var response: P.Message = .{};
    try equal(P.Code.ok, response.initConnected(&request, 7, daemonRef().typed(P.Daemon).?, &descriptor));
    try expect(response.isReplyTo(&request));
    try equal(P.Code.ok, response.validate());
    const info = P.readPayload(P.Response.Connection, response.payload[0..response.header.payload_size]).?;
    try equal(P.HandleType.daemon, info.daemon.type);
    try equal(@as(u64, 22), info.identity.id);
    try equal(@as(u64, 10), response.header.epoch);
    try equal(@as(u64, @sizeOf(P.AddressSpace)), info.mapping_size);
}

test "protocol: unknown application response codes survive framing" {
    const unknown: P.Code = @fromBackingInt(@as(u16, 0x1234));
    const p: P.Request.Control = .{ .command = 7 };
    const request = try requestMessage(.{ .operation = .control, .to = streamRef() }, P.bytesOf(P.Request.Control, &p));
    var response: P.Message = .{};
    try equal(P.Code.ok, response.initResponse(&request, .{ .code = unknown }, "diagnostic"));
    var bytes: [P.Message.max_frame_bytes]u8 = undefined;
    var n: usize = 0;
    try equal(P.Code.ok, response.encode(&bytes, &n));
    var decoded: P.Message = .{};
    try equal(P.Code.ok, decoded.decode(bytes[0..n]));
    try equal(P.Code.ok, decoded.validate());
    try equal(@as(u16, 0x1234), @backingInt(decoded.body.response.code));
}

test "protocol: Daemon descriptor reads and Daemon actor restrictions" {
    const f = try Fixture.init();
    defer f.deinit();
    const p: P.Request.Read = .{ .mode = .descriptor };
    var r: P.Request = .{ .operation = .read, .to = daemonRef() };
    const response: P.Response = .{ .operation = .read, .result = daemonRef() };
    try equal(P.Code.ok, response.validateFor(&r, P.bytesOf(P.Request.Read, &p), P.bytesOf(P.Daemon, &f.arena.daemon.value)));
    r.from = daemonRef();
    try equal(P.Code.invalid, r.validate(P.bytesOf(P.Request.Read, &p)));
    const event: P.Message.Event = .{ .operation = .publish, .from = daemonRef(), .subject = daemonRef() };
    try equal(P.Code.ok, event.validate());
}

test "protocol: Object descriptor read checks local identity and physical parent" {
    const f = try Fixture.init();
    defer f.deinit();
    const p: P.Request.Read = .{ .mode = .descriptor };
    const r: P.Request = .{ .operation = .read, .to = objectRef(0) };
    const response: P.Response = .{ .operation = .read, .result = objectRef(0) };
    const value = &f.arena.objects.slots[f.object.index()].value;
    try equal(P.Code.ok, response.validateFor(&r, P.bytesOf(P.Request.Read, &p), P.bytesOf(P.Object, value)));
    value.identity.id = 1;
    try equal(P.Code.invalid, response.validateFor(&r, P.bytesOf(P.Request.Read, &p), P.bytesOf(P.Object, value)));
}

test "protocol: acquire address agrees with deterministic data offset" {
    var access: P.Response.Access = .{ .address = P.ObjectAddress.fromHandle(objectRef(255).typed(P.Object).?).? };
    const response: P.Response = .{
        .operation = .acquire,
        .result = objectRef(255),
        .permissions = @backingInt(P.Operation.read),
        .revision = 1,
    };
    try equal(P.Code.ok, response.validate(P.bytesOf(P.Response.Access, &access)));
    access.address.offset += 1;
    try equal(P.Code.invalid, response.validate(P.bytesOf(P.Response.Access, &access)));
}

test "protocol: complete control request can be reassembled across multiple frames" {
    var payload: [10000]u8 = @splat(0);
    payload[0] = 7; // command; reserved prefix remains zero
    var storage: [10000]u8 = undefined;
    var assembly = P.MessageAssembly.init(&storage);
    const r: P.Request = .{ .operation = .control, .to = streamRef() };
    var offset: usize = 0;
    while (offset < payload.len) {
        var frame: P.Message = .{};
        try equal(P.Code.ok, frame.requestFragment(7, 10, 1, r, &payload, offset));
        var encoded: [P.Message.max_frame_bytes]u8 = undefined;
        var n: usize = 0;
        try equal(P.Code.ok, frame.encode(&encoded, &n));
        var decoded: P.Message = .{};
        try equal(P.Code.ok, decoded.decode(encoded[0..n]));
        try equal(P.Code.ok, assembly.append(&decoded));
        offset += decoded.header.payload_size;
    }
    try expect(assembly.complete());
    try expect(P.eql(u8, &payload, assembly.payload().?));
}

test "protocol: malformed fragment resets partial assembly" {
    const payload: [5000]u8 = @splat(0);
    var storage: [5000]u8 = undefined;
    var assembly = P.MessageAssembly.init(&storage);
    const r: P.Request = .{ .operation = .control, .to = streamRef() };
    var frame: P.Message = .{};
    try equal(P.Code.ok, frame.requestFragment(7, 10, 1, r, &payload, 0));
    try equal(P.Code.ok, assembly.append(&frame));
    const offset = frame.header.payload_size;
    try equal(P.Code.ok, frame.requestFragment(7, 10, 2, r, &payload, offset));
    try equal(P.Code.invalid, assembly.append(&frame));
    try expect(!assembly.active and assembly.received == 0);
}

test "protocol: fragmented response retains Stream control target and correlation" {
    const p: P.Request.Control = .{ .command = 7 };
    const request = try requestMessage(.{ .operation = .control, .to = streamRef() }, P.bytesOf(P.Request.Control, &p));
    const payload: [9000]u8 = @splat(0x5a);
    var storage: [9000]u8 = undefined;
    var assembly = P.MessageAssembly.init(&storage);
    var offset: usize = 0;
    while (offset < payload.len) {
        var frame: P.Message = .{};
        try equal(P.Code.ok, frame.responseFragment(&request, .{ .result = streamRef() }, &payload, offset));
        try expect(frame.isReplyTo(&request));
        try equal(P.Code.ok, assembly.append(&frame));
        offset += frame.header.payload_size;
    }
    try expect(assembly.complete());
    try equal(P.Code.ok, assembly.body.response.validateFor(&request.body.request, P.bytesOf(P.Request.Control, &p), assembly.payload().?));
}

test "protocol: framing rejects old ABI and truncation" {
    var message: P.Message = .{};
    try equal(P.Code.ok, message.initRequest(0, 0, 1, .{}, &.{}));
    var bytes: [P.Message.max_frame_bytes]u8 = undefined;
    var n: usize = 0;
    try equal(P.Code.ok, message.encode(&bytes, &n));
    var decoded: P.Message = .{};
    try equal(P.Code.invalid, decoded.decode(bytes[0 .. n - 1]));
    message.header.version.minor = 5;
    try equal(P.Code.unsupported, message.validateFrame());
}

// -----------------------------------------------------------------------------
// Procedural API usage. The test owns all exchange and execution behavior.
// -----------------------------------------------------------------------------

const expectError = std.testing.expectError;
const Foo = extern struct { a: u32 = 1, b: u32 = 2, c: u32 = 3 };
const Bar = extern struct { x: u8 = '1', y: u8 = '2', z: u8 = '3' };
const Selected = enum(u8) { foo = 0, bar = 1, last = 255 };

fn newSession() !P.Session {
    return P.sessionInit(.{ .endpoint = .{ .identity = 1 } });
}

/// Stand-in for sending: exercises framing/encoding/decoding but performs no I/O.
fn sendPrepared(session: *P.Session, call: *P.Call) !P.Message {
    var first: P.Message = .{};
    var have_first = false;
    while (call.phase == .ready) {
        var frame: P.Message = .{};
        try P.callFrame(session, call, &frame);
        var encoded: [P.Message.max_frame_bytes]u8 = undefined;
        var count: usize = 0;
        try equal(P.Code.ok, frame.encode(&encoded, &count));
        var decoded: P.Message = .{};
        try equal(P.Code.ok, decoded.decode(encoded[0..count]));
        if (!have_first) {
            first = decoded;
            have_first = true;
        }
        try P.callFrameSent(session, call);
    }
    try expect(have_first and call.phase == .waiting);
    return first;
}

fn connectFixture(session: *P.Session, call: *P.Call) !void {
    try P.sessionBootstrap(session, call);
    const request = try sendPrepared(session, call);
    const descriptor: P.Daemon = .{
        .identity = P.Identity.init(1, "sockman").?,
        .epoch = 10,
        .pid = 100,
    };
    var response: P.Message = .{};
    try equal(P.Code.ok, response.initConnected(&request, 7, daemonRef().typed(P.Daemon).?, &descriptor));
    try P.callAccept(session, call, &response);
    try P.sessionConnected(session, call);
    P.callReset(call);
}

/// The caller explicitly supplies the outcome; this is not an executor.
fn completeFixture(session: *P.Session, call: *P.Call, result: P.Response, data: []const u8) !void {
    const request = try sendPrepared(session, call);
    var offset: usize = 0;
    while (true) {
        var frame: P.Message = .{};
        try equal(P.Code.ok, frame.responseFragment(&request, result, data, offset));
        try P.callAccept(session, call, &frame);
        offset += frame.header.payload_size;
        if (offset == data.len) break;
    }
    try expect(P.callComplete(call));
}

test "api: fresh Daemon initialization is explicit and does not touch payload pages" {
    const arena = try std.heap.page_allocator.create(P.AddressSpace);
    defer std.heap.page_allocator.destroy(arena);
    arena.object_data[0][0] = 0xa5;
    const handle = try P.daemonInit(arena, .{
        .identity = P.Identity.init(80, "daemon-a").?,
        .epoch = 123,
        .pid = 500,
        .generation = 6,
    });
    try equal(@as(u16, 6), handle.generation());
    try equal(@as(u64, 80), arena.getDaemonConst(handle).?.identity.id);
    try equal(@as(u8, 0xa5), arena.object_data[0][0]);
    for (arena.namespaces.slots) |slot| try equal(P.SlotState.free, slot.state);
    for (arena.streams.slots) |slot| try equal(P.SlotState.free, slot.state);
    for (arena.objects.slots) |slot| try equal(P.SlotState.free, slot.state);
    try expectError(error.InvalidArgument, P.daemonInit(arena, .{
        .identity = P.Identity.init(0, "invalid").?,
        .epoch = 123,
        .pid = 500,
    }));
    try equal(@as(u64, 80), arena.daemon.value.identity.id);
}

test "api: Endpoint is description only and invalid selection is rejected" {
    const path_session = try P.sessionInit(.{ .endpoint = .{ .path = "selected-endpoint" } });
    try equal(P.SessionPhase.idle, path_session.phase);
    const env_session = try P.sessionInit(.{ .endpoint = .{ .environment = .{ .name = "ENDPOINT", .fallback = "fallback" } } });
    try equal(P.SessionPhase.idle, env_session.phase);
    try expectError(error.InvalidArgument, P.sessionInit(.{ .endpoint = .{ .path = "" } }));
    try expectError(error.InvalidArgument, P.sessionInit(.{ .endpoint = .{ .identity = 0 } }));
    try expectError(error.InvalidArgument, P.sessionInit(.{ .endpoint = .{ .identity = 1 }, .expected_daemon_id = 2 }));
    try expectError(error.InvalidArgument, P.sessionInit(.{ .endpoint = .{ .environment = .{ .name = "" } } }));
}

test "api: bootstrap is prepared sent received and explicitly admitted" {
    var session = try newSession();
    var outgoing: [128]u8 = undefined;
    var incoming: [128]u8 = undefined;
    var call = try P.callInit(&outgoing, &incoming);
    try P.sessionBootstrap(&session, &call);
    try equal(P.SessionPhase.connecting, session.phase);
    try equal(P.CallPhase.ready, call.phase);
    try equal(@as(u64, 0), session.id);
    const request = try sendPrepared(&session, &call);
    const descriptor: P.Daemon = .{ .identity = P.Identity.init(1, "sockman").?, .epoch = 10, .pid = 100 };
    var response: P.Message = .{};
    try equal(P.Code.ok, response.initConnected(&request, 7, daemonRef().typed(P.Daemon).?, &descriptor));
    try P.callAccept(&session, &call, &response);
    try equal(P.SessionPhase.connecting, session.phase);
    try equal(P.Code.ok, try P.callResult(&call));
    try P.sessionConnected(&session, &call);
    try equal(P.SessionPhase.connected, session.phase);
    try equal(@as(u64, 7), session.id);
    try equal(@as(u64, 10), session.epoch);
    try equal(@as(u64, 2), session.next_request_id);
    try expectError(error.InvalidState, P.sessionConnected(&session, &call));
}

test "api: bootstrap rejects a different Daemon identity" {
    var session = try newSession();
    var outgoing: [128]u8 = undefined;
    var incoming: [128]u8 = undefined;
    var call = try P.callInit(&outgoing, &incoming);
    try P.sessionBootstrap(&session, &call);
    const request = try sendPrepared(&session, &call);
    const descriptor: P.Daemon = .{ .identity = P.Identity.init(2, "other").?, .epoch = 10, .pid = 100 };
    var response: P.Message = .{};
    try equal(P.Code.ok, response.initConnected(&request, 7, daemonRef().typed(P.Daemon).?, &descriptor));
    try P.callAccept(&session, &call, &response);
    try expectError(error.DaemonMismatch, P.sessionConnected(&session, &call));
    try equal(P.SessionPhase.connecting, session.phase);
    try equal(@as(u64, 0), session.id);
    P.sessionDisconnect(&session);
    try equal(P.SessionPhase.idle, session.phase);
}

test "api: map binding checks the Daemon identity epoch and handle" {
    const f = try Fixture.init();
    defer f.deinit();
    var session = try newSession();
    var outgoing: [128]u8 = undefined;
    var incoming: [128]u8 = undefined;
    var call = try P.callInit(&outgoing, &incoming);
    try connectFixture(&session, &call);
    try P.sessionBindArena(&session, f.arena);
    try expect(session.arena.? == f.arena);
    f.arena.daemon.value.epoch += 1;
    try expectError(error.MappingMismatch, P.sessionBindArena(&session, f.arena));
    P.sessionDisconnect(&session);
    try expect(session.arena == null);
}

test "api: Namespace Stream and Object creation build scoped requests without allocation" {
    const f = try Fixture.init();
    defer f.deinit();
    var session = try newSession();
    var outgoing: [P.Message.max_payload_bytes]u8 = undefined;
    var incoming: [P.Message.max_payload_bytes]u8 = undefined;
    var call = try P.callInit(&outgoing, &incoming);
    try connectFixture(&session, &call);

    try P.namespaceInit(&session, &call, .{ .identity = P.Identity.init(70, "new-scope").? });
    try equal(P.HandleType.daemon, call.request.to.type);
    try expect(f.arena.findNamespace(f.daemon, 70) == null);
    try expectError(error.InvalidState, P.entityCreated(P.Namespace, &call));
    try completeFixture(&session, &call, .{ .result = namespaceRef() }, &.{});
    try equal(f.namespace.value, (try P.entityCreated(P.Namespace, &call)).value);
    try expectError(error.TypeMismatch, P.entityCreated(P.Stream, &call));
    // The constructed reply above does not mutate the fixture's catalog.
    try expect(f.arena.findNamespace(f.daemon, 70) == null);
    P.callReset(&call);

    try P.streamInit(&session, &call, .{ .namespace = f.namespace, .identity = P.Identity.init(10, "values").? });
    try equal(f.namespace.value, call.request.to.handle);
    try completeFixture(&session, &call, .{ .result = streamRef() }, &.{});
    const stream = try P.entityCreated(P.Stream, &call);
    P.callReset(&call);

    try P.objectInit(Foo, &session, &call, .{ .stream = stream, .identity = P.Identity.init(0, "foo").? });
    const parameters = P.readPayload(P.Request.Create, call.request_buffer[0..call.request_size]).?;
    try equal(@as(u64, 0), parameters.identity.id);
    try equal(@as(u16, @sizeOf(Foo)), parameters.min_size);
    try equal(@as(u16, @sizeOf(Foo)), parameters.max_size);
    try completeFixture(&session, &call, .{ .result = objectRef(0), .revision = 1 }, &.{});
    try equal(@as(u8, 0), (try P.entityCreated(P.Object, &call)).objectIndex());
}

test "api: Object write copies a value and read returns it after a reply" {
    var session = try newSession();
    var outgoing: [P.Message.max_payload_bytes]u8 = undefined;
    var incoming: [P.Message.max_payload_bytes]u8 = undefined;
    var call = try P.callInit(&outgoing, &incoming);
    try connectFixture(&session, &call);
    const object = objectRef(0).typed(P.Object).?;
    var value: Foo = .{};
    try P.objectWrite(Foo, &session, &call, .{ .object = object, .expected_revision = 1 }, &value);
    value.a = 100;
    const stored = P.readPayload(Foo, call.request_buffer[@sizeOf(P.Request.Write)..call.request_size]).?;
    try equal(@as(u32, 1), stored.a);
    try completeFixture(&session, &call, .{ .result = objectRef(0), .revision = 2 }, &.{});
    try equal(P.Code.ok, try P.callResult(&call));
    P.callReset(&call);

    try P.objectRead(Foo, &session, &call, .{ .object = object, .revision = 2 });
    try expectError(error.InvalidState, P.objectReadResult(Foo, &call));
    try completeFixture(&session, &call, .{ .result = objectRef(0), .revision = 2 }, P.bytesOf(Foo, &stored));
    const read_back = try P.objectReadResult(Foo, &call);
    try equal(@as(u32, 6), read_back.a + read_back.b + read_back.c);
    try expectError(error.TypeMismatch, P.objectReadResult(Bar, &call));
}

test "api: remote failures are not reported as successful reads" {
    var session = try newSession();
    var outgoing: [256]u8 = undefined;
    var incoming: [256]u8 = undefined;
    var call = try P.callInit(&outgoing, &incoming);
    try connectFixture(&session, &call);
    try P.objectRead(Foo, &session, &call, .{ .object = objectRef(0).typed(P.Object).? });
    try completeFixture(&session, &call, .{ .code = .permission_denied }, "denied");
    try equal(P.Code.permission_denied, try P.callResult(&call));
    try expect(P.eql(u8, "denied", try P.callPayload(&call)));
    try expectError(error.OperationFailed, P.objectReadResult(Foo, &call));
}

test "api: malformed typed read response fails validation" {
    var session = try newSession();
    var outgoing: [256]u8 = undefined;
    var incoming: [256]u8 = undefined;
    var call = try P.callInit(&outgoing, &incoming);
    try connectFixture(&session, &call);
    try P.objectRead(Foo, &session, &call, .{ .object = objectRef(0).typed(P.Object).? });
    const request = try sendPrepared(&session, &call);
    var response: P.Message = .{};
    try equal(P.Code.ok, response.initResponse(&request, .{ .result = objectRef(0), .revision = 1 }, "x"));
    try expectError(error.InvalidResponse, P.callAccept(&session, &call, &response));
    try equal(P.CallPhase.failed, call.phase);
    try expect(!P.callComplete(&call));
}

test "api: subscription mask selects local indices without installing a subscription" {
    var session = try newSession();
    var outgoing: [256]u8 = undefined;
    var incoming: [256]u8 = undefined;
    var call = try P.callInit(&outgoing, &incoming);
    try connectFixture(&session, &call);
    const selection = P.ObjectSet.init(.{ Selected.foo, Selected.last });
    try P.streamSubscribe(&session, &call, .{
        .stream = streamRef().typed(P.Stream).?,
        .objects = selection,
        .include_scope = false,
    });
    const parameters = P.readPayload(P.Request.Subscribe, call.request_buffer[0..call.request_size]).?;
    try expect(parameters.objects.eql(selection));
    try expect(parameters.objects.contains(0) and parameters.objects.contains(255));
    try expect(!parameters.objects.contains(1));
    try equal(@as(u16, 0), parameters.include_scope);
    try completeFixture(&session, &call, .{ .result = streamRef() }, &.{});
    P.callReset(&call);
    try P.entityUnsubscribe(&session, &call, .{ .target = streamRef() });
    try equal(@as(u16, 0), P.readPayload(P.Request.Subscribe, call.request_buffer[0..call.request_size]).?.enabled);
}

test "api: Object discovery matches ID zero and returns parent scoped data" {
    var session = try newSession();
    var outgoing: [256]u8 = undefined;
    var incoming: [512]u8 = undefined;
    var call = try P.callInit(&outgoing, &incoming);
    try connectFixture(&session, &call);
    try P.entityDiscover(&session, &call, .{
        .parent = streamRef(),
        .query = .{ .type = .object, .match_id = 1, .id = 0 },
    });
    const item: P.Response.Item = .{ .reference = objectRef(0), .parent = streamRef(), .identity = P.Identity.init(0, "foo").? };
    try completeFixture(&session, &call, .{ .item_count = 1, .revision = 5 }, P.bytesOf(P.Response.Item, &item));
    var items: [1]P.Response.Item = undefined;
    try equal(@as(usize, 1), try P.discoveryResult(&call, &items));
    try equal(@as(u64, 0), items[0].identity.id);
    try equal(streamRef().handle, items[0].parent.handle);
    try equal(@as(u64, 5), call.response.revision);
}

test "api: generic acquire descriptor publish administer and release use the same Call" {
    const f = try Fixture.init();
    defer f.deinit();
    var session = try newSession();
    var outgoing: [P.Message.max_payload_bytes]u8 = undefined;
    var incoming: [P.Message.max_payload_bytes]u8 = undefined;
    var call = try P.callInit(&outgoing, &incoming);
    try connectFixture(&session, &call);
    const rights = P.Permission.read_only;
    try P.entityAcquire(&session, &call, .{ .target = objectRef(0) }, rights);
    const access: P.Response.Access = .{ .address = P.ObjectAddress.fromHandle(f.object).? };
    try completeFixture(&session, &call, .{ .result = objectRef(0), .permissions = rights, .revision = 1 }, P.bytesOf(P.Response.Access, &access));
    try equal(access.address.offset, (try P.objectAccessResult(&call)).address.offset);
    P.callReset(&call);

    try P.entityReadDescriptor(&session, &call, .{ .target = daemonRef() });
    try completeFixture(&session, &call, .{ .result = daemonRef() }, P.bytesOf(P.Daemon, &f.arena.daemon.value));
    try equal(@as(u64, 1), (try P.descriptorResult(P.Daemon, &call)).identity.id);
    P.callReset(&call);

    try P.entityPublish(&session, &call, .{ .target = streamRef() }, .{});
    try completeFixture(&session, &call, .{ .result = streamRef(), .revision = 6 }, &.{});
    P.callReset(&call);
    try P.entityAdminister(&session, &call, .{ .target = objectRef(0) }, .{ .grantee = streamRef(), .permissions = rights });
    try completeFixture(&session, &call, .{ .result = objectRef(0), .revision = 7 }, &.{});
    P.callReset(&call);
    try P.entityRelease(&session, &call, .{ .target = objectRef(0) }, .access);
    try completeFixture(&session, &call, .{ .result = objectRef(0) }, &.{});
}

test "api: whole value bytes can be prepared and read without implicit text pointers" {
    var session = try newSession();
    var outgoing: [256]u8 = undefined;
    var incoming: [256]u8 = undefined;
    var call = try P.callInit(&outgoing, &incoming);
    try connectFixture(&session, &call);
    const object = objectRef(1).typed(P.Object).?;
    try P.objectInitBytes(&session, &call, .{ .stream = streamRef().typed(P.Stream).?, .identity = P.Identity.init(1, "bar").? }, .text, 0, 64);
    try completeFixture(&session, &call, .{ .result = objectRef(1), .revision = 1 }, &.{});
    P.callReset(&call);
    const value: Bar = .{};
    try P.objectWrite(Bar, &session, &call, .{ .object = object }, &value);
    try completeFixture(&session, &call, .{ .result = objectRef(1), .revision = 2 }, &.{});
    P.callReset(&call);
    try P.objectReadBytes(&session, &call, .{ .object = object }, 0, 3);
    try completeFixture(&session, &call, .{ .result = objectRef(1), .revision = 2 }, "123");
    try expect(P.eql(u8, "123", try P.callPayload(&call)));
}

test "api: control frames advance only after transmission and responses reassemble" {
    var session = try newSession();
    var outgoing: [12000]u8 = undefined;
    var incoming: [12000]u8 = undefined;
    var call = try P.callInit(&outgoing, &incoming);
    try connectFixture(&session, &call);
    const data: [9000]u8 = @splat(0x5a);
    try P.entityControl(&session, &call, .{ .target = streamRef() }, 7, &data);
    var frame0: P.Message = .{};
    var frame1: P.Message = .{};
    try P.callFrame(&session, &call, &frame0);
    try P.callFrame(&session, &call, &frame1);
    try equal(@as(usize, 0), call.send_offset);
    try equal(frame0.header.payload_size, frame1.header.payload_size);
    try expect(P.eql(u8, frame0.payload[0..frame0.header.payload_size], frame1.payload[0..frame1.header.payload_size]));
    try completeFixture(&session, &call, .{ .result = streamRef() }, &data);
    try expect(P.eql(u8, &data, try P.callPayload(&call)));
}

test "api: events are separate from pending replies and retain scope" {
    var session = try newSession();
    var outgoing: [256]u8 = undefined;
    var incoming: [256]u8 = undefined;
    var call = try P.callInit(&outgoing, &incoming);
    try connectFixture(&session, &call);
    try P.objectRead(Foo, &session, &call, .{ .object = objectRef(0).typed(P.Object).? });
    const request = try sendPrepared(&session, &call);
    var event: P.Message = .{};
    try equal(P.Code.ok, event.initEvent(session.id, session.epoch, .{ .operation = .publish, .subject = objectRef(0), .revision = 2 }));
    try expectError(error.UnexpectedMessage, P.callAccept(&session, &call, &event));
    try equal(P.CallPhase.waiting, call.phase);
    try equal(@as(u64, 2), (try P.sessionEvent(&session, &event)).revision);
    event.header.epoch += 1;
    try expectError(error.WrongSession, P.sessionEvent(&session, &event));
    const value: Foo = .{};
    var response: P.Message = .{};
    try equal(P.Code.ok, response.initResponse(&request, .{ .result = objectRef(0), .revision = 2 }, P.bytesOf(Foo, &value)));
    response.header.request_id += 1;
    try expectError(error.InvalidResponse, P.callAccept(&session, &call, &response));
    response.header.request_id -= 1;
    try P.callAccept(&session, &call, &response);
    try expect(P.callComplete(&call));
}

test "api: Calls cannot be applied to another Session or reused connection lifetime" {
    var session = try newSession();
    const other = try newSession();
    var outgoing: [256]u8 = undefined;
    var incoming: [256]u8 = undefined;
    var call = try P.callInit(&outgoing, &incoming);
    try connectFixture(&session, &call);
    try P.objectRead(Foo, &session, &call, .{ .object = objectRef(0).typed(P.Object).? });
    var frame: P.Message = .{};
    try expectError(error.WrongSession, P.callFrame(&other, &call, &frame));
    P.sessionDisconnect(&session);
    try expectError(error.StaleCall, P.callFrame(&session, &call, &frame));
    try equal(@as(u64, 2), session.generation);
}

test "api: request IDs are consumed once and never wrap back to one" {
    var session = try newSession();
    var outgoing: [256]u8 = undefined;
    var incoming: [256]u8 = undefined;
    var call = try P.callInit(&outgoing, &incoming);
    try connectFixture(&session, &call);
    try expectError(error.InvalidRequest, P.namespaceInit(&session, &call, .{ .identity = .{} }));
    try equal(@as(u64, 2), session.next_request_id);
    session.next_request_id = ~@as(u64, 0);
    try P.namespaceInit(&session, &call, .{ .identity = P.Identity.init(2, "scope").? });
    try equal(@as(u64, 0), session.next_request_id);
    P.callReset(&call);
    try expectError(error.RequestIdsExhausted, P.namespaceInit(&session, &call, .{ .identity = P.Identity.init(2, "scope").? }));
}

test "api: buffer ownership and capacity errors occur before dispatch" {
    var memory: [512]u8 = undefined;
    try expectError(error.BufferOverlap, P.callInit(memory[0..256], memory[128..384]));
    var session = try newSession();
    var call = try P.callInit(memory[0..256], memory[256..]);
    try connectFixture(&session, &call);
    const too_large: [300]u8 = @splat(0);
    try expectError(error.BufferTooSmall, P.entityControl(&session, &call, .{ .target = streamRef() }, 1, &too_large));
    try equal(P.CallPhase.idle, call.phase);
    const p: P.Request.Control = .{ .command = 1 };
    @memcpy(call.request_buffer[0..@sizeOf(P.Request.Control)], P.bytesOf(P.Request.Control, &p));
    try expectError(error.BufferOverlap, P.requestPrepare(&session, &call, .{ .operation = .control, .to = streamRef() }, call.request_buffer[0..@sizeOf(P.Request.Control)]));
}

test "api: typed copy gate rejects process local or padded representations" {
    const Plain = struct { a: u32, b: u32 };
    const Padded = extern struct { a: u8, b: u64 };
    const Explicit = extern struct { a: u8, reserved: [7]u8, b: u64 };
    const Closed = enum(u8) { one = 1 };
    const Open = enum(u8) { one = 1, _ };
    try expect(P.valueTypeSupported(Foo));
    try expect(P.valueTypeSupported(Bar));
    try expect(P.valueTypeSupported(Explicit));
    try expect(P.valueTypeSupported([16]u8));
    try expect(P.valueTypeSupported(Open));
    try expect(!P.valueTypeSupported(Closed));
    try expect(!P.valueTypeSupported(Padded));
    try expect(!P.valueTypeSupported(Plain));
    try expect(!P.valueTypeSupported([]const u8));
    try expect(!P.valueTypeSupported(*const Foo));
    try expect(!P.valueTypeSupported(?u64));
    try expect(!P.valueTypeSupported(bool));
    try expect(!P.valueTypeSupported([3:0]u8));
}
