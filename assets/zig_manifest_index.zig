//! Compatibility entrypoint. The parser is maintained in zwe.zig.
const std = @import("std");
const zwe = @import("zwe.zig");
pub fn main(init: std.process.Init) !void { try zwe.Manifest.run(init, &.{}); }
