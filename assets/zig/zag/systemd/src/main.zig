const std = @import("std");
const zag = @import("zag.zig");

const Systemd = @This();

project_file: zag.Fpb,
install_file: zag.Fpb,
sections: Sections = .{},
require_runtime_directory: bool = false,

pub const Sections = struct {
    unit: ?Unit = null,
    service: ?Service = null,
    install: ?Install = null,
};

pub const Unit = struct {
    description: ?[]const u8 = null,
    wants: []const []const u8 = &.{},
    requires: []const []const u8 = &.{},
    after: []const []const u8 = &.{},
    part_of: []const []const u8 = &.{},
    start_limit_interval_sec: ?u64 = null,
};

pub const Service = struct {
    type: ?[]const u8 = null,
    user: ?[]const u8 = null,
    group: ?[]const u8 = null,
    umask: ?[]const u8 = null,
    working_directory: ?[]const u8 = null,
    runtime_directory: ?[]const u8 = null,
    runtime_directory_mode: ?[]const u8 = null,
    environment_file: ?[]const u8 = null,
    exec_start: ?[]const u8 = null,
    restart: ?[]const u8 = null,
    restart_sec: ?u64 = null,
    timeout_start_sec: ?u64 = null,
    timeout_stop_sec: ?u64 = null,
    limit_nofile: ?u64 = null,
    standard_output: ?[]const u8 = null,
    standard_error: ?[]const u8 = null,
    kill_signal: ?[]const u8 = null,
};

pub const Install = struct {
    wanted_by: []const []const u8 = &.{},
};

pub fn init(b: *std.Build, definition: Systemd, after: ?*std.Build.Step) !Systemd {
    const verification = try definition.validate(b);
    if (after) |step| verification.step.dependOn(step);
    b.getInstallStep().dependOn(&verification.step);
    return definition;
}

pub fn generate(self: Systemd, b: *std.Build) !*std.Build.Step.Run {
    try self.validateDefinition();
    try validateProjectRelativePath(self.project_file.path);

    const bytes = try self.renderAlloc(b.allocator);
    const update = std.Build.Step.UpdateSourceFiles.create(b);
    update.addBytesToSource(bytes, self.project_file.path);

    const verification = try self.validate(b);
    verification.step.dependOn(&update.step);
    return verification;
}

pub fn validate(self: Systemd, b: *std.Build) !*std.Build.Step.Run {
    try self.validateDefinition();
    try self.validateRequiredRuntimeDirectory(b);

    const staged = b.addWriteFiles();
    const name = std.fs.path.basename(self.project_file.path);
    const unit_file = if (self.project_file.bytes != null or self.hasSections())
        staged.add(name, try self.renderAlloc(b.allocator))
    else
        staged.addCopyFile(b.path(self.project_file.path), name);

    if (std.mem.endsWith(u8, name, ".service")) {
        _ = staged.add(
            b.fmt("{s}.d/verify.conf", .{name}),
            "[Service]\nExecStart=\nExecStart=/bin/true\n",
        );
    }

    const verification = b.addSystemCommand(&.{
        "systemd-analyze", "--recursive-errors=no", "verify",
    });
    verification.addFileArg(unit_file);
    verification.has_side_effects = true;
    return verification;
}

pub fn install(self: Systemd, b: *std.Build) !*std.Build.Step.Run {
    const verification = try self.validate(b);
    const install_step = b.addSystemCommand(&.{ "install", "-D", "-m" });

    const mode = if (self.install_file.permissions) |permissions|
        b.fmt("{o}", .{permissions.toMode()})
    else
        "0644";
    install_step.addArg(mode);

    if (self.install_file.named_owner) |owner| {
        install_step.addArgs(&.{ "-o", owner });
    }
    if (self.install_file.named_group) |group| {
        install_step.addArgs(&.{ "-g", group });
    }

    install_step.addArg("--");
    install_step.addFileArg(b.path(self.project_file.path));
    install_step.addArg(self.install_file.path);
    install_step.has_side_effects = true;
    install_step.step.dependOn(&verification.step);
    return install_step;
}

pub fn renderAlloc(self: Systemd, allocator: std.mem.Allocator) ![]u8 {
    try self.validateDefinition();

    if (self.project_file.bytes) |bytes| return allocator.dupe(u8, bytes);
    if (!self.hasSections()) return error.NoGeneratedContent;

    var output: std.ArrayList(u8) = .empty;
    errdefer output.deinit(allocator);

    if (self.sections.unit) |unit| {
        try output.appendSlice(allocator, "[Unit]\n");
        if (unit.description) |v| try line(allocator, &output, "Description", v);
        for (unit.wants) |v| try line(allocator, &output, "Wants", v);
        for (unit.requires) |v| try line(allocator, &output, "Requires", v);
        try joined(allocator, &output, "After", unit.after);
        try joined(allocator, &output, "PartOf", unit.part_of);
        if (unit.start_limit_interval_sec) |v| try number(allocator, &output, "StartLimitIntervalSec", v);
        try output.append(allocator, '\n');
    }

    if (self.sections.service) |service| {
        try output.appendSlice(allocator, "[Service]\n");
        if (service.type) |v| try line(allocator, &output, "Type", v);
        if (service.user) |v| try line(allocator, &output, "User", v);
        if (service.group) |v| try line(allocator, &output, "Group", v);
        if (service.umask) |v| try line(allocator, &output, "UMask", v);
        if (service.working_directory) |v| try line(allocator, &output, "WorkingDirectory", v);
        if (service.runtime_directory) |v| try line(allocator, &output, "RuntimeDirectory", v);
        if (service.runtime_directory_mode) |v| try line(allocator, &output, "RuntimeDirectoryMode", v);
        if (service.environment_file) |v| try line(allocator, &output, "EnvironmentFile", v);
        if (service.exec_start) |v| try line(allocator, &output, "ExecStart", v);
        if (service.restart) |v| try line(allocator, &output, "Restart", v);
        if (service.restart_sec) |v| try number(allocator, &output, "RestartSec", v);
        if (service.timeout_start_sec) |v| try number(allocator, &output, "TimeoutStartSec", v);
        if (service.timeout_stop_sec) |v| try number(allocator, &output, "TimeoutStopSec", v);
        if (service.limit_nofile) |v| try number(allocator, &output, "LimitNOFILE", v);
        if (service.standard_output) |v| try line(allocator, &output, "StandardOutput", v);
        if (service.standard_error) |v| try line(allocator, &output, "StandardError", v);
        if (service.kill_signal) |v| try line(allocator, &output, "KillSignal", v);
        try output.append(allocator, '\n');
    }

    if (self.sections.install) |install_section| {
        try output.appendSlice(allocator, "[Install]\n");
        try joined(allocator, &output, "WantedBy", install_section.wanted_by);
    }

    return output.toOwnedSlice(allocator);
}

fn hasSections(self: Systemd) bool {
    return self.sections.unit != null or
        self.sections.service != null or
        self.sections.install != null;
}

fn validateDefinition(self: Systemd) !void {
    const source = self.project_file.path;
    const destination = self.install_file.path;

    if (source.len == 0 or destination.len == 0) return error.EmptySystemdPath;
    if (std.mem.indexOfAny(u8, source, "\x00\r\n") != null or
        std.mem.indexOfAny(u8, destination, "\x00\r\n") != null)
        return error.InvalidSystemdPath;

    const name = std.fs.path.basename(source);
    if (!std.mem.eql(u8, name, std.fs.path.basename(destination)))
        return error.SystemdUnitNameMismatch;

    const is_service = std.mem.endsWith(u8, name, ".service");
    const is_target = std.mem.endsWith(u8, name, ".target");
    if (!is_service and !is_target) return error.InvalidSystemdUnitExtension;
    if (self.project_file.bytes != null and self.hasSections())
        return error.ConflictingSystemdContents;
    if (is_target and self.sections.service != null)
        return error.TargetHasServiceSection;
    if (is_service and self.project_file.bytes == null and
        self.hasSections() and self.sections.service == null)
        return error.MissingServiceSection;

    if (self.sections.service) |service| {
        if (service.runtime_directory_mode != null and service.runtime_directory == null)
            return error.RunDirectoryDoesntExist;
        if (service.runtime_directory) |directory| {
            validateProjectRelativePath(directory) catch return error.InvalidRuntimeDirectory;
        }
        if (service.runtime_directory_mode) |mode| {
            const value = std.fmt.parseInt(u16, mode, 8) catch return error.InvalidRuntimeDirectoryMode;
            if (mode.len == 0 or value > 0o7777) return error.InvalidRuntimeDirectoryMode;
        }
    }
}

fn validateRequiredRuntimeDirectory(self: Systemd, b: *std.Build) !void {
    if (!self.require_runtime_directory) return;

    b.graph.poisonCache();

    const source = self.project_file.bytes orelse try std.Io.Dir.cwd().readFileAlloc(
        b.graph.io,
        self.project_file.path,
        b.allocator,
        .limited(64 * 1024),
    );

    const key = "RuntimeDirectory=";
    var lines = std.mem.splitScalar(u8, source, '\n');

    while (lines.next()) |raw| {
        const entry = std.mem.trim(u8, raw, " \t\r");
        if (!std.mem.startsWith(u8, entry, key)) continue;

        const name = std.mem.trim(u8, entry[key.len..], " \t");
        if (name.len == 0) return error.RunDirectoryDoesntExist;

        validateProjectRelativePath(name) catch return error.InvalidRuntimeDirectory;
        return;
    }

    return error.RunDirectoryDoesntExist;
}

fn validateProjectRelativePath(path: []const u8) !void {
    if (std.fs.path.isAbsolute(path)) return error.InvalidProjectFilePath;
    var parts = std.mem.splitScalar(u8, path, '/');
    while (parts.next()) |part| {
        if (part.len == 0 or
            std.mem.eql(u8, part, ".") or
            std.mem.eql(u8, part, "..") or
            std.mem.indexOfScalar(u8, part, '\\') != null)
            return error.InvalidProjectFilePath;
    }
}

fn line(allocator: std.mem.Allocator, output: *std.ArrayList(u8), key: []const u8, value: []const u8) !void {
    try validateValue(value);
    try output.appendSlice(allocator, key);
    try output.append(allocator, '=');
    try output.appendSlice(allocator, value);
    try output.append(allocator, '\n');
}

fn number(allocator: std.mem.Allocator, output: *std.ArrayList(u8), key: []const u8, value: u64) !void {
    var buffer: [20]u8 = undefined;
    try line(allocator, output, key, try std.fmt.bufPrint(&buffer, "{d}", .{value}));
}

fn joined(allocator: std.mem.Allocator, output: *std.ArrayList(u8), key: []const u8, values: []const []const u8) !void {
    if (values.len == 0) return;
    try output.appendSlice(allocator, key);
    try output.append(allocator, '=');
    for (values, 0..) |value, index| {
        try validateValue(value);
        if (index != 0) try output.append(allocator, ' ');
        try output.appendSlice(allocator, value);
    }
    try output.append(allocator, '\n');
}

fn validateValue(value: []const u8) !void {
    if (std.mem.indexOfAny(u8, value, "\x00\r\n") != null)
        return error.InvalidSystemdDirectiveValue;
}
