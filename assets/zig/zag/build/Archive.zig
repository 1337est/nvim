const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());
    if (args.len != 4) return error.InvalidArguments;
    const io = init.io;
    const file = try std.Io.Dir.cwd().openFile(io, args[2], .{});
    defer file.close(io);
    var buffer: [64 * 1024]u8 = undefined;
    var reader = file.reader(io, &buffer);

    if (std.mem.eql(u8, args[1], "verify")) {
        var hash_buffer: [4096]u8 = undefined;
        var hash = std.Io.Writer.Hashing(std.crypto.hash.sha3.Sha3_256).init(&hash_buffer);
        _ = try reader.interface.streamRemaining(&hash.writer);
        try hash.writer.flush();
        const actual = std.fmt.bytesToHex(hash.hasher.finalResult(), .lower);
        if (!std.mem.eql(u8, &actual, args[3])) {
            std.log.err("SHA3-256 mismatch for {s}\nexpected: {s}\nactual:   {s}", .{
                args[2], args[3], actual,
            });
            return error.ArchiveChecksumMismatch;
        }
    } else if (std.mem.eql(u8, args[1], "extract")) {
        try std.Io.Dir.cwd().deleteTree(io, args[3]);
        const out = try std.Io.Dir.cwd().createDirPathOpen(io, args[3], .{});
        defer out.close(io);
        try std.zip.extract(out, &reader, .{});
    } else return error.InvalidArguments;
}
