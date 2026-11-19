const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const args = try init.minimal.args.toSlice(init.arena.allocator());

    if (args.len < 2) {
        return std.Io.File.stdout().writeStreamingAll(
            init.io,
            "Usage: rhei <wm|bar|idle>\n",
        );
    }

    const cmd = args[1];
    if (std.mem.eql(u8, cmd, "wm")) return @import("rhei/wm.zig").main(init);
    if (std.mem.eql(u8, cmd, "bar")) return @import("rhei/bar.zig").main(init);
    if (std.mem.eql(u8, cmd, "idle")) return @import("rhei/idle.zig").main(init);

    return error.UnknownCommand;
}
