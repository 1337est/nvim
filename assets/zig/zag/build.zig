const std = @import("std");

// Named projects required build.zig.zon required zig version
const required_zig_version: []const u8 = "0.17.0";
// Named projects are under zag/{named_projects}/build.zig.zon
const named_projects: []const []const u8 = .{
    "template",
    "zwe",
    "clift",
    "nostrum",
    "rhei",
    "udeploy",
    "wagon",
    "systemd",
    "sockman",
    "ramen",
};
// function for ensuring the zig manifest build.zig.zon .name, matches the
// named project directory
fn manifestNameMatchesDir() void {}

pub fn build(b: *std.Build) void {
    _ = b; // stub
}
