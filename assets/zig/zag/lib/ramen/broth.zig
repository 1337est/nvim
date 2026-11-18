//! Author:     Adrian R. Sanchez
//! Created:    2026-10-16
//! Updated:    2026-10-19 1
//! File:       zag.zig
//!
//! Summary:
//! My personal wrappers and library for the zig programming language
//! to effectively help me write well organized and efficient code.
//! No functions should exist here, and is simply a grouping of things
//! that I find myself using together. Once I get more used to the
//! zig standard library or once it becomes stable, this wrapper
//! can likely go away.

// TODO: I think it would be cool to be able to add the block above to my zig files

const std = @import("std");

/// Date, Time, Timezone
/// Stores time info.
/// - EpochDay can derive Year, Month, and Day
/// - Clock can derive Timestamp and Duration (ns default).
///   It's also better to specify here the type of clock used
///   to derive the time.
pub const Dtz = struct {
    epoch_day: std.time.epoch.EpochDay,
    clock: std.Io.Clock,
    tz: std.tz.Tz, // TODO: Need to look into this to see how it works
};

/// Key, Separator, Value
/// Takes in key value pairs, and formats them to likely configurations
/// Should be able to add take in the k and v and make a kv single unit
/// Should be able to add a kv separator
/// Should be able to add a v separator if v.len > 1
/// Should be able to add a set of quotes around the full set of v's
/// Should be able to remove a set of quotes around a full set of v's
/// Should be able to add a description/comment above a kv if
pub const Ksv = struct {
    k: []const u8, // single key
    kvs: []const u8, // optional key value separator
    v: []const []const u8, // multiple values
    vs: []const u8, // optional value separator
    description: []const u8, // optional description for the kv
};

/// File, Permission, Bytes
/// Handles file access, permissions, and reading or writing bytes.
pub const Fpb = struct {
    path: []const u8, // path of the file or directory (implicit name)
    bytes: ?[]const u8 = null, // file contents, null means not to alter bytes
    permissions: ?std.Io.File.Permissions = null,
    named_owner: ?[]const u8 = null, // optional explicit named owner
    named_group: ?[]const u8 = null, // optional explicit named group
};

/// Target, Build, Deploy
/// Should define a full project at some point?
/// Maybe should include BSP (Build Server Protocol)?
/// Maybe should include CSP (Compiler Server Protocol)?
/// If BSP+CSP inclusion, need to split into 2 (or 3) structs
/// Struct 1: BSP
/// Struct 2: CSP
/// Struct 3: Multiplex BSP + CSP
pub const Tbd = struct {
    target_query: std.Target.Query, // find or define the target via Target.Query
    optimize_mode: ?std.builtin.OptimizeMode = null, // optional optimization mode
    artifact_name: ?[]const u8 = null, // optional artifact name
    artifact_kind: enum { exe, obj, lib, @"test" } = .exe, // artifact type
    semantic_version: std.SemanticVersion, // major, minor, patch
    root_source_file: ?std.Build.LazyPath = null, // optional source file
    display_server: ?enum { x11, wayland } = null, // null means headless
    remote_host: ?[]const u8 = null, // null means local deployment
    deploy_path: ?[]const u8 = null, // optional deployment directory
    modules: []const std.Build.Module.Import = &.{}, // modules attached to this artifact
    files: []const Fpb = &.{}, // files to generate or deploy
};

/// Process, Signal, Environment
pub const Pse = struct {};

/// Bits, Enums, Flags
pub const Bef = struct {};

/// Archive, Compression
pub const Ac = struct {};

/// Array, List, Map
pub const Alm = struct {};

/// Uri, Network, Internet
/// Handles URIs and network communication, including HTTP and HTTPS.
/// Includes downloading data.
pub const Uni = struct {};

/// Serialize, Encode, Decode
/// Serializes and parses structured data; encodes and decodes bytes.
/// Should tokenization and AST go here?
pub const Sed = struct {};
