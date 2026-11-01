const std = @import("std");

pub const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const Error = error{
    SqliteOpen,
    SqliteExec,
    SqlitePrepare,
    SqliteStep,
    SqliteBind,
};

pub const Db = struct {
    handle: *c.sqlite3,
    allocator: std.mem.Allocator,

    pub fn open(allocator: std.mem.Allocator, path: []const u8) !Db {
        const zpath = try allocator.dupeZ(u8, path);
        defer allocator.free(zpath);

        var db_opt: ?*c.sqlite3 = null;

        const flags = c.SQLITE_OPEN_READWRITE | c.SQLITE_OPEN_CREATE;

        const rc = c.sqlite3_open_v2(zpath, &db_opt, flags, null);
        if (rc != c.SQLITE_OK or db_opt == null) {
            if (db_opt) |db| _ = c.sqlite3_close_v2(db);
            return error.SqliteOpen;
        }

        return .{ .handle = db_opt.?, .allocator = allocator };
    }

    pub fn close(self: *Db) void {
        _ = c.sqlite3_close_v2(self.handle);
    }

    fn errmsg(self: *Db) []const u8 {
        const z = c.sqlite3_errmsg(self.handle);
        return std.mem.span(@as([*:0]const u8, z));
    }

    pub fn exec(self: *Db, sql: []const u8) !void {
        const zsql: [:0]u8 = try self.allocator.dupeZ(u8, sql);
        defer self.allocator.free(zsql);

        // sqlite3_exec expects char** => [*c][*c]u8
        var err_ptr: [*c]u8 = null;

        const rc = c.sqlite3_exec(self.handle, zsql.ptr, null, null, &err_ptr);
        if (rc != c.SQLITE_OK) {
            defer if (err_ptr != null) c.sqlite3_free(err_ptr);

            const msg: []const u8 = if (err_ptr != null)
                std.mem.span(@as([*:0]const u8, @ptrCast(err_ptr)))
            else
                self.errmsg();

            std.log.err("sqlite exec rc={d}: {s}", .{ rc, msg });
            return error.SqliteExec;
        }
    }

    pub fn prepare(self: *Db, sql: []const u8) !Stmt {
        var stmt_opt: ?*c.sqlite3_stmt = null;
        const rc = c.sqlite3_prepare_v2(
            self.handle,
            sql.ptr,
            @as(c_int, @intCast(sql.len)),
            &stmt_opt,
            null,
        );
        if (rc != c.SQLITE_OK or stmt_opt == null) {
            std.log.err("sqlite prepare rc={d}: {s}", .{ rc, self.errmsg() });
            return error.SqlitePrepare;
        }
        return .{ .db = self, .stmt = stmt_opt.? };
    }
};

pub const Step = enum { row, done };

pub const Stmt = struct {
    db: *Db,
    stmt: *c.sqlite3_stmt,

    pub fn finalize(self: *Stmt) void {
        _ = c.sqlite3_finalize(self.stmt);
    }

    pub fn reset(self: *Stmt) void {
        _ = c.sqlite3_reset(self.stmt);
        _ = c.sqlite3_clear_bindings(self.stmt);
    }

    pub fn step(self: *Stmt) !Step {
        const rc = c.sqlite3_step(self.stmt);
        return switch (rc) {
            c.SQLITE_ROW => .row,
            c.SQLITE_DONE => .done,
            else => {
                std.log.err("sqlite step rc={d}: {s}", .{ rc, self.db.errmsg() });
                return error.SqliteStep;
            },
        };
    }

    pub fn bindText(self: *Stmt, idx: c_int, text: []const u8) !void {
        // Passing NULL destructor => SQLITE_STATIC (safe if text lives until step())
        const rc = c.sqlite3_bind_text(
            self.stmt,
            idx,
            text.ptr,
            @as(c_int, @intCast(text.len)),
            null,
        );
        if (rc != c.SQLITE_OK) return error.SqliteBind;
    }

    pub fn bindInt64(self: *Stmt, idx: c_int, v: i64) !void {
        const rc = c.sqlite3_bind_int64(self.stmt, idx, v);
        if (rc != c.SQLITE_OK) return error.SqliteBind;
    }

    pub fn bindDouble(self: *Stmt, idx: c_int, v: f64) !void {
        const rc = c.sqlite3_bind_double(self.stmt, idx, v);
        if (rc != c.SQLITE_OK) return error.SqliteBind;
    }

    pub fn columnText(self: *Stmt, col: c_int) []const u8 {
        const p = c.sqlite3_column_text(self.stmt, col);
        if (p == null) return "";
        const n = c.sqlite3_column_bytes(self.stmt, col);
        return @as([*]const u8, @ptrCast(p))[0..@as(usize, @intCast(n))];
    }

    pub fn columnInt64(self: *Stmt, col: c_int) i64 {
        return c.sqlite3_column_int64(self.stmt, col);
    }

    pub fn columnDouble(self: *Stmt, col: c_int) f64 {
        return c.sqlite3_column_double(self.stmt, col);
    }

    pub fn columnIsNull(self: *Stmt, col: c_int) bool {
        return c.sqlite3_column_type(self.stmt, col) == c.SQLITE_NULL;
    }
};
