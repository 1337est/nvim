//! Nostrum: local task planning and journaling backed by SQLite.
//! Consolidated from the former main.zig, root.zig, and sqlite.zig.
const std = @import("std");

// -----------------------------------------------------------------------------
// Application entry point
// -----------------------------------------------------------------------------

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    var db = try sqlite.Db.open(gpa, "sqlite/nostrum.db");
    defer db.close();

    // Schema creation if it doesn't exist
    try db.exec(
        \\PRAGMA foreign_keys = ON;
        \\
        \\CREATE TABLE IF NOT EXISTS meta (
        \\  key   TEXT     PRIMARY KEY,
        \\  value INTEGER NOT NULL
        \\);
        \\INSERT OR IGNORE INTO meta(key, value) VALUES ('last_day', 0);
        \\
        \\CREATE TABLE IF NOT EXISTS tasks (
        \\  id             INTEGER PRIMARY KEY,
        \\  name           TEXT NOT NULL,
        \\  category       TEXT NOT NULL CHECK(category IN ('D','W','M','Q','Y')),
        \\  weight_per_day REAL NOT NULL,
        \\  cycle_days     INTEGER NOT NULL CHECK(cycle_days > 0),
        \\  weight         REAL NOT NULL DEFAULT 0,
        \\  enabled        INTEGER NOT NULL DEFAULT 1,
        \\  start_day      INTEGER NOT NULL DEFAULT 0,
        \\  due_day        INTEGER NOT NULL DEFAULT 0,
        \\  completed_day  INTEGER,
        \\  next_due_day   INTEGER NOT NULL DEFAULT 0,
        \\  UNIQUE(category, name)
        \\);
        \\
        \\CREATE VIEW IF NOT EXISTS tasks_daily     AS SELECT * FROM tasks WHERE category='D';
        \\CREATE VIEW IF NOT EXISTS tasks_weekly    AS SELECT * FROM tasks WHERE category='W';
        \\CREATE VIEW IF NOT EXISTS tasks_monthly   AS SELECT * FROM tasks WHERE category='M';
        \\CREATE VIEW IF NOT EXISTS tasks_quarterly AS SELECT * FROM tasks WHERE category='Q';
        \\CREATE VIEW IF NOT EXISTS tasks_yearly    AS SELECT * FROM tasks WHERE category='Y';
    );

    // CLI args
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    // One time import command for reading planner/tasks/template/*.txt
    // Run: zig build run-nostrum -- import
    const requested_import = (args.len >= 2 and std.mem.eql(u8, args[1], "import"));
    const empty_db = (try tasksCount(&db)) == 0;
    if (requested_import or empty_db) {
        try importTasksFromTxt(&db, gpa);
        if (requested_import) {
            std.debug.print("Imported planner/tasks/template/*.txt into sqlite/nostrum.db\n", .{});
        }
    }

    // Mark task done:
    // Run: zig build run-nostrum -- done 4
    if (args.len >= 3 and std.mem.eql(u8, args[1], "done")) {
        const id = try std.fmt.parseInt(i64, args[2], 10);
        try markTaskDone(&db, id);
        std.debug.print("Marked task id={d} done (weight reset to 0)\n", .{id});
        return;
    }

    // Normal run:
    // 1) apply missed-day increments
    try bumpWeightsToToday(&db);

    // 2) compute today's date for filename/header
    var date_buf: [8]u8 = undefined;
    const ymd = todayYYYYMMDD(&date_buf);

    // 3) load tasks from DB (no txt reads anymore)
    var tasks = try loadDueTasksFromDb(gpa, &db);
    defer freeTasks(gpa, &tasks);
    if (tasks.items.len == 0) {
        std.debug.print("No tasks due.\n", .{});
    }

    // 4) render + output
    const frame = try renderTasksFrame(gpa, ymd, tasks.items);
    defer gpa.free(frame);

    var stdout_buf: [64 * 1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;

    try stdout.writeAll(frame);
    try stdout.flush();

    // 5) write to journal
    try writeJournalFile(ymd, frame);
}

// -----------------------------------------------------------------------------
// Task model, scheduling, parsing, and journaling
// -----------------------------------------------------------------------------

pub const Category = enum {
    daily,
    weekly,
    monthly,
    quarterly,
    yearly,

    pub fn letter(self: Category) u8 {
        return switch (self) {
            .daily => 'D',
            .weekly => 'W',
            .monthly => 'M',
            .quarterly => 'Q',
            .yearly => 'Y',
        };
    }
};

pub const Task = struct {
    id: i64 = 0, // DB primary key (0 when loaded from txt)
    name: []const u8, // owned by allocator
    weight: f32, // first number in "w/d"
    cycle_days: u32, // second number in "w/d"
    category: Category, // D,W,M,Q,Y
    due_day: i64 = 0, // initial due date
    completed_day: ?i64 = null, // completed date
    next_due_day: i64 = 0, // next time this task is due
};

// -----------------------------------------------------------------------
// TIME LOGIC
// -----------------------------------------------------------------------

/// Convert unix seconds (UTC) to "YYYYMMDD" (UTC)
pub fn yyyymmddFromUnixSeconds(buf: *[8]u8, unix_seconds: u64) []const u8 {
    const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = unix_seconds };
    const yd = epoch_seconds.getEpochDay().calculateYearDay();
    const md = yd.calculateMonthDay();

    const year: u16 = yd.year;
    const month: u8 = @as(u8, @backingInt(md.month)); // 1..12
    const day: u8 = @as(u8, @intCast(md.day_index + 1)); // 1..31

    // Exactly 8 chars: YYYYMMDD
    _ = std.fmt.bufPrint(buf, "{d:0>4}{d:0>2}{d:0>2}", .{ year, month, day }) catch unreachable;
    return buf[0..8];
}

pub fn yyyymmddFromEpochDay(buf: *[8]u8, epoch_day: u64) []const u8 {
    const secs_per_day: u64 = @as(u64, std.time.epoch.secs_per_day);
    const unix_seconds: u64 = epoch_day * secs_per_day;
    return yyyymmddFromUnixSeconds(buf, unix_seconds);
}

/// Current date "YYYYMMDD" in UTC
pub fn todayYYYYMMDD(buf: *[8]u8) []const u8 {
    const ts: i64 = std.time.timestamp(); // seconds since 1970-01-01 UTC
    const unix_seconds: u64 = if (ts <= 0) 0 else @as(u64, @intCast(ts));
    return yyyymmddFromUnixSeconds(buf, unix_seconds);
}

/// Compute "today day index" (UTC "days" since epoch), stored in meta.last_day
pub fn todayEpochDayUTC() u64 {
    const ts: i64 = std.time.timestamp(); // seconds since 1970-01-01 UTC
    const unix_seconds: u64 = if (ts <= 0) 0 else @as(u64, @intCast(ts));
    const epoch_seconds = std.time.epoch.EpochSeconds{ .secs = unix_seconds };
    return @as(u64, @intCast(epoch_seconds.getEpochDay().day));
}

// -----------------------------------------------------------------------
// TESTS for TIME LOGIC
// -----------------------------------------------------------------------

test "yyyymmddFromUnixSeconds epoch" {
    var buf: [8]u8 = undefined;

    // 1970-01-01
    try std.testing.expectEqualStrings("19700101", yyyymmddFromUnixSeconds(&buf, 0));

    // 1970-12-31 23:59:59 is still 1970-12-31
    try std.testing.expectEqualStrings("19701231", yyyymmddFromUnixSeconds(&buf, 31_535_999));
}

// -----------------------------------------------------------------------
// BASIC LOGIC
// -----------------------------------------------------------------------

fn parseWeightCycle(s: []const u8) !struct { weight: f32, cycle_days: u32 } {
    // expects like "0.33/1" or "1/90"
    var it = std.mem.splitScalar(u8, s, '/');
    const w_str = it.next() orelse return error.BadFormat;
    const d_str = it.next() orelse return error.BadFormat;

    const w = try std.fmt.parseFloat(f32, w_str);
    const d = try std.fmt.parseInt(u32, d_str, 10);
    if (d == 0) return error.BadFormat;

    return .{ .weight = w, .cycle_days = d };
}

fn parseAndAppendLine(
    gpa: std.mem.Allocator,
    category: Category,
    line: []const u8,
    list: *std.ArrayList(Task),
) !void {
    // Expected: "<Name> <weight>/<days>"
    var parts = std.mem.tokenizeAny(u8, line, " \t");
    const name_raw = parts.next() orelse return;
    const iter_raw = parts.next() orelse return;

    const parsed = try parseWeightCycle(iter_raw);

    const name = try gpa.dupe(u8, name_raw);
    errdefer gpa.free(name);

    try list.append(gpa, .{
        .id = 0,
        .name = name,
        .weight = parsed.weight,
        .cycle_days = parsed.cycle_days,
        .category = category,
    });
}

pub fn loadTasksFromFile(
    gpa: std.mem.Allocator,
    category: Category,
    path: []const u8,
) !std.ArrayList(Task) {
    var list: std.ArrayList(Task) = .empty;

    var file = std.fs.cwd().openFile(path, .{}) catch |e| {
        // TODO: Missing weekly/yearly/etc is OK for now.
        if (e == error.FileNotFound) return list;
        return e;
    };
    defer file.close();

    const data = try file.readToEndAlloc(gpa, 1 << 20);
    defer gpa.free(data);

    var lines = std.mem.splitScalar(u8, data, '\n');

    // Optional header line: "Name iteration/cycle"
    if (lines.next()) |first| {
        const trimmed = std.mem.trim(u8, first, " \t\r");
        if (trimmed.len != 0 and !std.mem.startsWith(u8, trimmed, "Name")) {
            try parseAndAppendLine(gpa, category, trimmed, &list);
        }
    }

    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (trimmed.len == 0) continue;
        try parseAndAppendLine(gpa, category, trimmed, &list);
    }

    return list;
}

pub fn freeTasks(gpa: std.mem.Allocator, tasks: *std.ArrayList(Task)) void {
    for (tasks.items) |t| gpa.free(t.name);
    tasks.deinit(gpa);
}

fn taskN(weight: f32, cycle_days: u32) u32 {
    // Matches floor(w / d) using what's in the txt files
    const d = @as(f32, @floatFromInt(cycle_days));
    return @as(u32, @intFromFloat(@floor(weight / d)));
}

pub fn renderTasksFrame(
    gpa: std.mem.Allocator,
    ymd: []const u8,
    all_tasks: []const Task,
) ![]u8 {
    var out: std.ArrayList(u8) = .empty;
    errdefer out.deinit(gpa);

    const w = out.writer(gpa);

    try w.print("Tasks\n{s}\n\n", .{ymd});

    // precedence: Yearly -> Daily
    const order = [_]Category{ .yearly, .quarterly, .monthly, .weekly, .daily };

    inline for (order) |cat| {
        var any = false;
        for (all_tasks) |t| {
            if (t.category != cat) continue;
            any = true;

            const n = taskN(t.weight, t.cycle_days);

            var due_buf: [8]u8 = undefined;
            var comp_buf: [8]u8 = undefined;
            var next_buf: [8]u8 = undefined;

            const due_str = if (t.due_day > 0)
                yyyymmddFromEpochDay(&due_buf, @as(u64, @intCast(t.due_day)))
            else
                "--------";

            const comp_str = if (t.completed_day) |cd|
                yyyymmddFromEpochDay(&comp_buf, @as(u64, @intCast(cd)))
            else
                "--------";

            const next_str = if (t.next_due_day > 0)
                yyyymmddFromEpochDay(&next_buf, @as(u64, @intCast(t.next_due_day)))
            else
                "--------";

            try w.print(
                "{c}{d} - [ ] ({d}) {s:<32} {s} : {s} : {s}\n",
                .{ cat.letter(), n, t.id, t.name, due_str, comp_str, next_str },
            );
        }
        if (any) try w.writeByte('\n');
    }

    return out.toOwnedSlice(gpa);
}

pub fn writeJournalFile(ymd: []const u8, content: []const u8) !void {
    // TODO: make sure this is a certain path instead of just cwd
    try std.fs.cwd().makePath("journals");

    var filename_buf: [64]u8 = undefined;
    const path = try std.fmt.bufPrint(&filename_buf, "planner/tasks/{s}.md", .{ymd});

    var file = try std.fs.cwd().createFile(path, .{ .truncate = true });
    defer file.close();

    try file.writeAll(content);
}

fn daysUntilWeight(target_weight: f64, weight_per_day: f64) i64 {
    // weight_per_day is CHECKed > 0 in schema, so divide is safe.
    const days_f = std.math.ceil(target_weight / weight_per_day);
    return @as(i64, @intFromFloat(days_f));
}

// -----------------------------------------------------------------------
// TESTS for BASIC LOGIC
// -----------------------------------------------------------------------

// -----------------------------------------------------------------------
// SQL LOGIC
// -----------------------------------------------------------------------

fn categorySql(cat: Category) []const u8 {
    // Static strings => safe with SQLITE_STATIC bind.
    return switch (cat) {
        .daily => "D",
        .weekly => "W",
        .monthly => "M",
        .quarterly => "Q",
        .yearly => "Y",
    };
}

fn importTasksFileIntoDb(
    db: *sqlite.Db,
    gpa: std.mem.Allocator,
    category: Category,
    path: []const u8,
) !void {
    // Reuse existing parser
    var list = try loadTasksFromFile(gpa, category, path);
    defer freeTasks(gpa, &list);

    // UPSERT:
    // - inserts new tasks
    // - updates config fields if they change in text file
    // - DOES NOT overwrite `weight` (state) for existing tasks
    var stmt = try db.prepare(
        \\INSERT INTO tasks(name, category, weight_per_day, cycle_days, enabled)
        \\VALUES(?1, ?2, ?3, ?4, 1)
        \\ON CONFLICT(category, name) DO UPDATE SET
        \\  weight_per_day = excluded.weight_per_day,
        \\  cycle_days     = excluded.cycle_days,
        \\  enabled        = excluded.enabled;
    );
    defer stmt.finalize();

    const cat_txt = categorySql(category);

    for (list.items) |t| {
        stmt.reset();

        try stmt.bindText(1, t.name);
        try stmt.bindText(2, cat_txt);
        try stmt.bindDouble(3, @as(f64, t.weight)); // t.weight == weight_per_day from file
        try stmt.bindInt64(4, @as(i64, t.cycle_days));

        _ = try stmt.step(); // expect .done
    }
}

/// Import/sync all tasks from planner/tasks/template/*.txt into SQLite.
///
/// This is safe to call every run.
/// It updates task config fields but preserves per-task `weight` state.
pub fn importTasksFromTxt(db: *sqlite.Db, gpa: std.mem.Allocator) !void {
    try db.exec("BEGIN IMMEDIATE;");
    errdefer db.exec("ROLLBACK;") catch {};

    // Optional but useful: mirror files -> DB by disabling everything first,
    // then re-enabling tasks that still exist in the txt files.
    // If you don’t want that behavior, delete this line.
    try db.exec("UPDATE tasks SET enabled = 0;");

    try importTasksFileIntoDb(db, gpa, .daily, "planner/tasks/template/daily.txt");
    try importTasksFileIntoDb(db, gpa, .weekly, "planner/tasks/template/weekly.txt");
    try importTasksFileIntoDb(db, gpa, .monthly, "planner/tasks/template/monthly.txt");
    try importTasksFileIntoDb(db, gpa, .quarterly, "planner/tasks/template/quarterly.txt");
    try importTasksFileIntoDb(db, gpa, .yearly, "planner/tasks/template/yearly.txt");

    try db.exec("COMMIT;");
}

fn getLastDay(db: *sqlite.Db) !i64 {
    var stmt = try db.prepare("SELECT value FROM meta WHERE key='last_day';");
    defer stmt.finalize();

    switch (try stmt.step()) {
        .row => return stmt.columnInt64(0),
        .done => return 0,
    }
}

pub fn bumpWeightsToToday(db: *sqlite.Db) !void {
    const today_day_u64 = todayEpochDayUTC();
    const today_day: i64 = @as(i64, @intCast(today_day_u64));

    var last_day: i64 = try getLastDay(db);

    // First-run behavior:
    // If last_day == 0 (fresh DB), treat it as "yesterday" so today's run counts as 1 day elapsed
    // This makes daily tasks due immediately on first run.
    if (last_day == 0 and today_day > 0) {
        last_day = today_day - 1;
    }

    const delta: i64 = today_day - last_day;
    if (delta < 0) {
        // If clock went backwards, clamp meta to today to avoid negative deltas forever.
        var fix = try db.prepare("UPDATE meta SET value?1 WHERE key='last_day';");
        defer fix.finalize();
        try fix.bindInt64(1, today_day);
        _ = try fix.step();
        return;
    }

    try db.exec("BEGIN IMMEDIATE;");
    errdefer db.exec("ROLLBACK;") catch {};

    if (delta > 0) {
        // 1) weight += weight_per_day * delta_days
        var upd = try db.prepare("UPDATE tasks SET weight = weight + (weight_per_day * ?1) WHERE enabled = 1;");
        defer upd.finalize();
        try upd.bindInt64(1, delta);
        _ = try upd.step();

        // 2) last_day = today
        var upd_meta = try db.prepare("UPDATE meta SET value = ?1 WHERE key='last_day';");
        defer upd_meta.finalize();
        try upd_meta.bindInt64(1, today_day);
        _ = try upd_meta.step();
    }

    // 3) initialize start_day for new tasks
    // If delta > 0: start_day = today - delta (so weight matches elapsed days)
    // If delta == 0: start_day = today
    const start_init = if (delta > 0) (today_day - delta) else today_day;

    var init = try db.prepare("UPDATE tasks SET start_day = ?1 WHERE start_day = 0;");
    try init.bindInt64(1, start_init);
    _ = try init.step();

    // 4) recompute due_date / next_due_day
    try recomputeDueFields(db);

    try db.exec("COMMIT;");
}

fn categoryFromDb(cat: []const u8) !Category {
    if (cat.len == 0) return error.BadCategory;
    return switch (cat[0]) {
        'D' => .daily,
        'W' => .weekly,
        'M' => .monthly,
        'Q' => .quarterly,
        'Y' => .yearly,
        else => error.BadCategory,
    };
}

pub fn loadTasksFromDb(gpa: std.mem.Allocator, db: *sqlite.Db) !std.ArrayList(Task) {
    var list: std.ArrayList(Task) = .empty;

    // Order in precedence: Y -> Q -> M -> W -> D, then by name
    var stmt = try db.prepare(
        \\SELECT id, name, category, weight, cycle_days
        \\FROM tasks
        \\WHERE enabled = 1
        \\ORDER BY
        \\  CASE category
        \\    WHEN 'Y' THEN 0
        \\    WHEN 'Q' THEN 1
        \\    WHEN 'M' THEN 2
        \\    WHEN 'W' THEN 3
        \\    WHEN 'D' THEN 4
        \\    ELSE 5
        \\  END,
        \\  name;
    );
    defer stmt.finalize();

    while (true) {
        switch (try stmt.step()) {
            .row => {
                const id = stmt.columnInt64(0);
                const name_txt = stmt.columnText(1);
                const cat_txt = stmt.columnText(2);
                const weight_db = stmt.columnDouble(3);
                const cycle_db = stmt.columnInt64(4);

                const name = try gpa.dupe(u8, name_txt);
                errdefer gpa.free(name);

                try list.append(gpa, .{
                    .id = id,
                    .name = name,
                    .category = try categoryFromDb(cat_txt),
                    .weight = @as(f32, @floatCast(weight_db)),
                    .cycle_days = @as(u32, @intCast(cycle_db)),
                });
            },
            .done => break,
        }
    }

    return list;
}

pub fn loadDueTasksFromDb(gpa: std.mem.Allocator, db: *sqlite.Db) !std.ArrayList(Task) {
    var list: std.ArrayList(Task) = .empty;

    var stmt = try db.prepare(
        \\SELECT id, name, category, weight, cycle_days, due_day, completed_day, next_due_day
        \\FROM tasks
        \\WHERE enabled = 1
        \\  AND weight >= CAST(cycle_days AS REAL)
        \\ORDER BY
        \\  CASE category
        \\    WHEN 'Y' THEN 0
        \\    WHEN 'Q' THEN 1
        \\    WHEN 'M' THEN 2
        \\    WHEN 'W' THEN 3
        \\    WHEN 'D' THEN 4
        \\    ELSE 5
        \\  END,
        \\  (weight / CAST(cycle_days AS REAL)) DESC,
        \\  weight DESC,
        \\  name ASC;
    );
    defer stmt.finalize();

    while (true) {
        switch (try stmt.step()) {
            .row => {
                const id = stmt.columnInt64(0);
                const name_txt = stmt.columnText(1);
                const cat_txt = stmt.columnText(2);
                const weight_db = stmt.columnDouble(3);
                const cycle_db = stmt.columnInt64(4);
                const due_day = stmt.columnInt64(5);
                const completed_day: ?i64 = if (stmt.columnIsNull(6))
                    null
                else
                    stmt.columnInt64(6);
                const next_due_day = stmt.columnInt64(7);
                const name = try gpa.dupe(u8, name_txt);
                errdefer gpa.free(name);

                try list.append(gpa, .{
                    .id = id,
                    .name = name,
                    .category = try categoryFromDb(cat_txt),
                    .weight = @as(f32, @floatCast(weight_db)),
                    .cycle_days = @as(u32, @intCast(cycle_db)),
                    .due_day = due_day,
                    .completed_day = completed_day,
                    .next_due_day = next_due_day,
                });
            },
            .done => break,
        }
    }

    return list;
}

fn recomputeDueFields(db: *sqlite.Db) !void {
    var sel = try db.prepare(
        \\SELECT id, start_day, weight_per_day, cycle_days, weight
        \\FROM tasks
        \\WHERE enabled = 1;
    );
    defer sel.finalize();

    var upd = try db.prepare(
        \\UPDATE tasks
        \\SET due_day = ?1,
        \\    next_due_day = ?2
        \\WHERE id = ?3;
    );
    defer upd.finalize();

    while (true) {
        switch (try sel.step()) {
            .row => {
                const id = sel.columnInt64(0);
                const start_day = sel.columnInt64(1);
                const wpd = sel.columnDouble(2);
                const cycle_days_i64 = sel.columnInt64(3);
                const weight = sel.columnDouble(4);

                if (start_day == 0) continue; // not initialized yet

                const cycle_days_f = @as(f64, @floatFromInt(cycle_days_i64));

                // initial due day (k=1)
                const d1 = daysUntilWeight(cycle_days_f, wpd);
                const due_day = start_day + d1;

                // N = floor(weight / cycle_days)
                const n_f = @floor(weight / cycle_days_f);
                const n: i64 = if (n_f < 0) 0 else @as(i64, @intFromFloat(n_f));

                // next due is k = (N+1)
                const next_weight = @as(f64, @floatFromInt(n + 1)) * cycle_days_f;
                const dn = daysUntilWeight(next_weight, wpd);
                const next_due_day = start_day + dn;

                upd.reset();
                try upd.bindInt64(1, due_day);
                try upd.bindInt64(2, next_due_day);
                try upd.bindInt64(3, id);
                _ = try upd.step();
            },
            .done => break,
        }
    }
}

pub fn markTaskDone(db: *sqlite.Db, task_id: i64) !void {
    const today_day: i64 = @as(i64, @intCast(todayEpochDayUTC()));

    // Need weight_per_day and cycle_days to compute the next due date after reset
    var sel = try db.prepare("SELECT weight_per_day, cycle_days FROM tasks WHERE id = ?1;");
    defer sel.finalize();
    try sel.bindInt64(1, task_id);

    if ((try sel.step()) != .row) return; // no such task

    const wpd = sel.columnDouble(0);
    const cycle_days_i64 = sel.columnInt64(1);
    const cycle_days_f = @as(f64, @floatFromInt(cycle_days_i64));

    const d1 = daysUntilWeight(cycle_days_f, wpd);
    const due_day = today_day + d1;
    const next_due_day = due_day; // after reset, N=0

    var upd = try db.prepare(
        \\UPDATE tasks
        \\SET weight = 0,
        \\    completed_day = ?1,
        \\    start_day = ?1,
        \\    due_day = ?2,
        \\    next_due_day = ?3
        \\WHERE id = ?4;
    );
    defer upd.finalize();

    try upd.bindInt64(1, today_day);
    try upd.bindInt64(2, due_day);
    try upd.bindInt64(3, next_due_day);
    try upd.bindInt64(4, task_id);
    _ = try upd.step();
}

pub fn tasksCount(db: *sqlite.Db) !i64 {
    var stmt = try db.prepare("SELECT COUNT(*) FROM tasks;");
    defer stmt.finalize();

    switch (try stmt.step()) {
        .row => return stmt.columnInt64(0),
        .done => return 0,
    }
}

// -----------------------------------------------------------------------
// TESTS for SQL LOGIC
// -----------------------------------------------------------------------

// -----------------------------------------------------------------------------
// SQLite interface
// -----------------------------------------------------------------------------

pub const sqlite = struct {
    // Minimal SQLite C ABI, replacing @cImport in Zig 0.17.0.
    // The linker must supply these symbols (sqlite3.c or -lsqlite3).
    pub const c = struct {
        pub const sqlite3 = opaque {};
        pub const sqlite3_stmt = opaque {};

        pub const SQLITE_OK: c_int = 0;
        pub const SQLITE_ROW: c_int = 100;
        pub const SQLITE_DONE: c_int = 101;
        pub const SQLITE_NULL: c_int = 5;
        pub const SQLITE_OPEN_READWRITE: c_int = 0x00000002;
        pub const SQLITE_OPEN_CREATE: c_int = 0x00000004;

        const ExecCallback = *const fn (
            ?*anyopaque,
            c_int,
            [*c][*c]u8,
            [*c][*c]u8,
        ) callconv(.c) c_int;
        const Destructor = *const fn (?*anyopaque) callconv(.c) void;

        pub extern fn sqlite3_open_v2(
            filename: [*:0]const u8,
            db: *?*sqlite3,
            flags: c_int,
            vfs: ?[*:0]const u8,
        ) c_int;
        pub extern fn sqlite3_close_v2(db: *sqlite3) c_int;
        pub extern fn sqlite3_errmsg(db: *sqlite3) [*:0]const u8;
        pub extern fn sqlite3_exec(
            db: *sqlite3,
            sql: [*:0]const u8,
            callback: ?ExecCallback,
            context: ?*anyopaque,
            err_msg: *[*c]u8,
        ) c_int;
        pub extern fn sqlite3_free(ptr: [*c]u8) void;
        pub extern fn sqlite3_prepare_v2(
            db: *sqlite3,
            sql: [*]const u8,
            sql_len: c_int,
            stmt: *?*sqlite3_stmt,
            tail: ?*[*c]const u8,
        ) c_int;
        pub extern fn sqlite3_finalize(stmt: *sqlite3_stmt) c_int;
        pub extern fn sqlite3_reset(stmt: *sqlite3_stmt) c_int;
        pub extern fn sqlite3_clear_bindings(stmt: *sqlite3_stmt) c_int;
        pub extern fn sqlite3_step(stmt: *sqlite3_stmt) c_int;
        pub extern fn sqlite3_bind_text(
            stmt: *sqlite3_stmt,
            index: c_int,
            text: [*]const u8,
            text_len: c_int,
            destructor: ?Destructor,
        ) c_int;
        pub extern fn sqlite3_bind_int64(stmt: *sqlite3_stmt, index: c_int, value: i64) c_int;
        pub extern fn sqlite3_bind_double(stmt: *sqlite3_stmt, index: c_int, value: f64) c_int;
        pub extern fn sqlite3_column_text(stmt: *sqlite3_stmt, column: c_int) [*c]const u8;
        pub extern fn sqlite3_column_bytes(stmt: *sqlite3_stmt, column: c_int) c_int;
        pub extern fn sqlite3_column_int64(stmt: *sqlite3_stmt, column: c_int) i64;
        pub extern fn sqlite3_column_double(stmt: *sqlite3_stmt, column: c_int) f64;
        pub extern fn sqlite3_column_type(stmt: *sqlite3_stmt, column: c_int) c_int;
    };

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
};
