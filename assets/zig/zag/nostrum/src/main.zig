const std = @import("std");
const nostrum = @import("nostrum");

pub fn main() !void {
    var gpa_state = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa_state.deinit();
    const gpa = gpa_state.allocator();

    const sqlite = nostrum.sqlite;
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
    // Run: zig build run -- import
    const requested_import = (args.len >= 2 and std.mem.eql(u8, args[1], "import"));
    const empty_db = (try nostrum.tasksCount(&db)) == 0;
    if (requested_import or empty_db) {
        try nostrum.importTasksFromTxt(&db, gpa);
        if (requested_import) {
            std.debug.print("Imported planner/tasks/template/*.txt into sqlite/nostrum.db\n", .{});
        }
    }

    // Mark task done:
    // Run: zig build run -- done 4
    if (args.len >= 3 and std.mem.eql(u8, args[1], "done")) {
        const id = try std.fmt.parseInt(i64, args[2], 10);
        try nostrum.markTaskDone(&db, id);
        std.debug.print("Marked task id={d} done (weight reset to 0)\n", .{id});
        return;
    }

    // Normal run:
    // 1) apply missed-day increments
    try nostrum.bumpWeightsToToday(&db);

    // 2) compute today's date for filename/header
    var date_buf: [8]u8 = undefined;
    const ymd = nostrum.todayYYYYMMDD(&date_buf);

    // 3) load tasks from DB (no txt reads anymore)
    var tasks = try nostrum.loadDueTasksFromDb(gpa, &db);
    defer nostrum.freeTasks(gpa, &tasks);
    if (tasks.items.len == 0) {
        std.debug.print("No tasks due.\n", .{});
    }

    // 4) render + output
    const frame = try nostrum.renderTasksFrame(gpa, ymd, tasks.items);
    defer gpa.free(frame);

    var stdout_buf: [64 * 1024]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buf);
    const stdout = &stdout_writer.interface;

    try stdout.writeAll(frame);
    try stdout.flush();

    // 5) write to journal
    try nostrum.writeJournalFile(ymd, frame);
}
