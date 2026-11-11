//! View — a small Android text viewer, built with Zig 0.17.0 on Linux x86_64.
//!
//! From the directory containing this file:
//!   zig run view.zig -- build
//!   zig run view.zig -- install
//!   zig test view.zig
//!
//! Build prerequisites and commands are printed by:
//!   zig run view.zig -- help
//!
//! On the phone: select a text file in a file manager, then Open with > View.
//! UTF-8, read-only, monospace, no highlighting or wrapping. Drag in either
//! direction. Markdown is displayed as source. Tabs use four-column stops.
//! The initial size limit is 4 MiB. Change the constants below if desired.
//! Lines wider than 1,000,000 pixels are rejected to avoid TextView's internal
//! layout-width limit causing wrapping. This is far beyond normal code lines.
//! All application code, manifest, and build commands live in this file.
//! Generated files go into zig-out/; keep its signing key for future updates.

const std = @import("std");
const builtin = @import("builtin");

const font_size_sp: f32 = 14;
const tab_columns: usize = 4;
const max_file_bytes: usize = 4 * 1024 * 1024;
const background: u32 = 0xff121212;
const foreground: u32 = 0xffe0e0e0;

// Convert only for display: validate UTF-8, omit a BOM, normalize newlines,
// and expand tabs. Never modify the original file.
fn displayText(allocator: std.mem.Allocator, bytes: []const u8) ![]u16 {
    if (bytes.len > max_file_bytes) return error.FileTooLarge;
    const input = if (std.mem.startsWith(u8, bytes, "\xef\xbb\xbf")) bytes[3..] else bytes;
    var iterator = (try std.unicode.Utf8View.init(input)).iterator();
    var text: std.ArrayList(u16) = .empty;
    errdefer text.deinit(allocator);
    var column: usize = 0;
    var after_cr = false;
    while (iterator.nextCodepoint()) |codepoint| {
        if (codepoint == '\n' and after_cr) {
            after_cr = false;
            continue;
        }
        after_cr = codepoint == '\r';
        switch (codepoint) {
            '\r', '\n' => {
                try text.append(allocator, '\n');
                column = 0;
            },
            '\t' => {
                const spaces = tab_columns - column % tab_columns;
                try text.appendNTimes(allocator, ' ', spaces);
                column += spaces;
            },
            0...8, 11, 12, 14...31 => return error.NotText,
            else => {
                if (codepoint <= 0xffff) {
                    try text.append(allocator, @intCast(codepoint));
                } else {
                    const supplementary = codepoint - 0x10000;
                    try text.appendSlice(allocator, &.{
                        @as(u16, @intCast(0xd800 + (supplementary >> 10))),
                        @as(u16, @intCast(0xdc00 + (supplementary & 0x3ff))),
                    });
                }
                column += 1;
            },
        }
    }
    return text.toOwnedSlice(allocator);
}

comptime {
    if (tab_columns == 0) @compileError("tab_columns must be positive");
    if (builtin.abi == .android)
        @export(&Android.create, .{ .name = "ANativeActivity_onCreate" });
}

const Android = struct {
    const c = @import("android"); // Generated from the NDK by the build driver.
    const allocator = std.heap.c_allocator;

    // Each activity and its detached reader own one reference. The descriptor
    // stays open until both owners finish; a closed fd can never be reused
    // underneath the worker. The worker never uses the activity or UI JNIEnv.
    const State = struct {
        references: std.atomic.Value(u32) = .init(1),
        cancelled: std.atomic.Value(bool) = .init(false),
        completed: std.atomic.Value(bool) = .init(false),
        vm: [*c]c.JavaVM,
        ui_env: [*c]c.JNIEnv,
        view: c.jobject = null,
        resolver: c.jobject = null,
        uri: c.jobject = null,
        result: c.jobject = null,
        event_fd: c_int = -1,

        fn release(self: *State, env: [*c]c.JNIEnv) void {
            if (self.references.fetchSub(1, .acq_rel) != 1) return;
            if (env != null) {
                for ([_]c.jobject{ self.view, self.resolver, self.uri, self.result }) |ref|
                    if (ref != null) env.*.*.DeleteGlobalRef.?(env, ref);
            }
            if (self.event_fd >= 0) _ = c.close(self.event_fd);
            allocator.destroy(self);
        }
    };

    // Use JNI's typed A functions, so every argument has an explicit jvalue
    // representation and no C variadic argument promotion is involved.
    const Jni = struct {
        env: [*c]c.JNIEnv,

        fn check(self: Jni) !void {
            if (self.env.*.*.ExceptionCheck.?(self.env) == 0) return;
            self.env.*.*.ExceptionDescribe.?(self.env);
            self.env.*.*.ExceptionClear.?(self.env);
            return error.JavaException;
        }

        fn class(self: Jni, name: [*:0]const u8) !c.jclass {
            const value = self.env.*.*.FindClass.?(self.env, name);
            try self.check();
            return value orelse error.JavaNull;
        }

        fn string(self: Jni, value: [:0]const u8) !c.jstring {
            const result = self.env.*.*.NewStringUTF.?(self.env, value.ptr);
            try self.check();
            return result orelse error.OutOfMemory;
        }

        fn global(self: Jni, value: c.jobject) !c.jobject {
            if (value == null) return error.JavaNull;
            const result = self.env.*.*.NewGlobalRef.?(self.env, value);
            try self.check();
            return result orelse error.OutOfMemory;
        }

        fn new(self: Jni, name: [*:0]const u8, signature: [*:0]const u8, args: []const c.jvalue) !c.jobject {
            const cls = try self.class(name);
            defer self.env.*.*.DeleteLocalRef.?(self.env, cls);
            const method = self.env.*.*.GetMethodID.?(self.env, cls, "<init>", signature);
            try self.check();
            if (method == null) return error.JavaNull;
            const value = self.env.*.*.NewObjectA.?(self.env, cls, method, values(args));
            try self.check();
            return value orelse error.JavaNull;
        }

        fn call(self: Jni, comptime T: type, object: c.jobject, name: [*:0]const u8, signature: [*:0]const u8, args: []const c.jvalue) !T {
            if (object == null) return error.JavaNull;
            const cls = self.env.*.*.GetObjectClass.?(self.env, object);
            try self.check();
            if (cls == null) return error.JavaNull;
            defer self.env.*.*.DeleteLocalRef.?(self.env, cls);
            const method = self.env.*.*.GetMethodID.?(self.env, cls, name, signature);
            try self.check();
            if (method == null) return error.JavaNull;
            const result = switch (T) {
                void => self.env.*.*.CallVoidMethodA.?(self.env, object, method, values(args)),
                c.jint => self.env.*.*.CallIntMethodA.?(self.env, object, method, values(args)),
                c.jobject => self.env.*.*.CallObjectMethodA.?(self.env, object, method, values(args)),
                else => @compileError("Unsupported JNI return type"),
            };
            try self.check();
            return result;
        }

        fn staticCall(self: Jni, comptime T: type, class_name: [*:0]const u8, name: [*:0]const u8, signature: [*:0]const u8, args: []const c.jvalue) !T {
            const cls = try self.class(class_name);
            defer self.env.*.*.DeleteLocalRef.?(self.env, cls);
            const method = self.env.*.*.GetStaticMethodID.?(self.env, cls, name, signature);
            try self.check();
            if (method == null) return error.JavaNull;
            const result = switch (T) {
                c.jobject => self.env.*.*.CallStaticObjectMethodA.?(self.env, cls, method, values(args)),
                f32 => self.env.*.*.CallStaticFloatMethodA.?(self.env, cls, method, values(args)),
                else => @compileError("Unsupported static JNI return type"),
            };
            try self.check();
            if (T == c.jobject and result == null) return error.JavaNull;
            return result;
        }

        fn floatField(self: Jni, object: c.jobject, name: [*:0]const u8) !f32 {
            if (object == null) return error.JavaNull;
            const cls = self.env.*.*.GetObjectClass.?(self.env, object);
            try self.check();
            if (cls == null) return error.JavaNull;
            defer self.env.*.*.DeleteLocalRef.?(self.env, cls);
            const field = self.env.*.*.GetFieldID.?(self.env, cls, name, "F");
            try self.check();
            if (field == null) return error.JavaNull;
            const result = self.env.*.*.GetFloatField.?(self.env, object, field);
            try self.check();
            return result;
        }

        fn setText(self: Jni, view: c.jobject, text: c.jobject) !void {
            try self.call(void, view, "setText", "(Ljava/lang/CharSequence;)V", &.{.{ .l = text }});
        }

        fn values(args: []const c.jvalue) [*c]const c.jvalue {
            return if (args.len == 0) null else args.ptr;
        }
    };

    fn create(activity: [*c]c.ANativeActivity, _: ?*anyopaque, _: usize) callconv(.c) void {
        const j: Jni = .{ .env = activity.*.env };
        if (j.env.*.*.PushLocalFrame.?(j.env, 64) < 0) {
            j.check() catch {};
            c.ANativeActivity_finish(activity);
            return;
        }
        defer _ = j.env.*.*.PopLocalFrame.?(j.env, null);
        createView(activity, j) catch {
            j.check() catch {};
            c.ANativeActivity_finish(activity);
        };
    }

    fn createView(activity: [*c]c.ANativeActivity, j: Jni) !void {
        const context = activity.*.clazz;
        const window = try j.call(c.jobject, context, "getWindow", "()Landroid/view/Window;", &.{});
        try j.call(void, window, "takeSurface", "(Landroid/view/SurfaceHolder$Callback2;)V", &.{.{ .l = null }});
        try j.call(void, window, "takeInputQueue", "(Landroid/view/InputQueue$Callback;)V", &.{.{ .l = null }});
        try j.call(void, window, "setFormat", "(I)V", &.{.{ .i = -1 }});

        const root = try j.new("android/widget/FrameLayout", "(Landroid/content/Context;)V", &.{.{ .l = context }});
        try j.call(void, root, "setFitsSystemWindows", "(Z)V", &.{.{ .z = 1 }});
        try j.call(void, root, "setBackgroundColor", "(I)V", &.{.{ .i = @bitCast(background) }});
        const view = try j.new("android/widget/TextView", "(Landroid/content/Context;)V", &.{.{ .l = context }});
        const resources = try j.call(c.jobject, context, "getResources", "()Landroid/content/res/Resources;", &.{});
        const metrics = try j.call(c.jobject, resources, "getDisplayMetrics", "()Landroid/util/DisplayMetrics;", &.{});
        const padding: c.jint = @intFromFloat(12 * try j.floatField(metrics, "density") + 0.5);
        try j.call(void, view, "setPadding", "(IIII)V", &.{ .{ .i = padding }, .{ .i = padding }, .{ .i = padding }, .{ .i = padding } });
        try j.call(void, view, "setTextSize", "(F)V", &.{.{ .f = font_size_sp }});
        try j.call(void, view, "setTextColor", "(I)V", &.{.{ .i = @bitCast(foreground) }});
        const typeface = try j.staticCall(c.jobject, "android/graphics/Typeface", "create", "(Ljava/lang/String;I)Landroid/graphics/Typeface;", &.{ .{ .l = try j.string("monospace") }, .{ .i = 0 } });
        try j.call(void, view, "setTypeface", "(Landroid/graphics/Typeface;)V", &.{.{ .l = typeface }});
        try j.call(void, view, "setHorizontallyScrolling", "(Z)V", &.{.{ .z = 1 }});
        const movement = try j.staticCall(c.jobject, "android/text/method/ScrollingMovementMethod", "getInstance", "()Landroid/text/method/MovementMethod;", &.{});
        try j.call(void, view, "setMovementMethod", "(Landroid/text/method/MovementMethod;)V", &.{.{ .l = movement }});
        try j.call(void, view, "setHorizontalScrollBarEnabled", "(Z)V", &.{.{ .z = 1 }});
        try j.call(void, view, "setVerticalScrollBarEnabled", "(Z)V", &.{.{ .z = 1 }});
        // View.addView(View,int,int): fill the inset-adjusted frame.
        try j.call(void, root, "addView", "(Landroid/view/View;II)V", &.{ .{ .l = view }, .{ .i = -1 }, .{ .i = -1 } });
        try j.call(void, context, "setContentView", "(Landroid/view/View;)V", &.{.{ .l = root }});
        try j.setText(view, try j.string("Loading..."));

        const state = try allocator.create(State);
        state.* = .{ .vm = activity.*.vm, .ui_env = j.env };
        errdefer state.release(j.env);
        state.view = try j.global(view);
        activity.*.instance = state;
        activity.*.callbacks.*.onDestroy = destroy;
        startRead(activity, state, j) catch |err| {
            const text = j.string(message(err)) catch return;
            j.setText(view, text) catch {};
        };
    }

    fn startRead(activity: [*c]c.ANativeActivity, state: *State, j: Jni) !void {
        const intent = try j.call(c.jobject, activity.*.clazz, "getIntent", "()Landroid/content/Intent;", &.{});
        const uri = try j.call(c.jobject, intent, "getData", "()Landroid/net/Uri;", &.{});
        if (uri == null) {
            try j.setText(state.view, try j.string("Open a text file in your file manager.\nChoose Open with > View."));
            return;
        }
        state.uri = try j.global(uri);
        state.resolver = try j.global(try j.call(c.jobject, activity.*.clazz, "getContentResolver", "()Landroid/content/ContentResolver;", &.{}));
        state.event_fd = c.eventfd(0, c.EFD_NONBLOCK | c.EFD_CLOEXEC);
        if (state.event_fd < 0) return error.SystemFailure;
        const looper = c.ALooper_forThread() orelse return error.SystemFailure;
        if (c.ALooper_addFd(looper, state.event_fd, c.ALOOPER_POLL_CALLBACK, c.ALOOPER_EVENT_INPUT, ready, state) != 1)
            return error.SystemFailure;
        errdefer _ = c.ALooper_removeFd(looper, state.event_fd);
        _ = state.references.fetchAdd(1, .monotonic);
        var thread: c.pthread_t = undefined;
        if (c.pthread_create(&thread, null, readWorker, state) != 0) {
            state.release(j.env);
            return error.SystemFailure;
        }
        _ = c.pthread_detach(thread);
    }

    fn destroy(activity: [*c]c.ANativeActivity) callconv(.c) void {
        const state: *State = @ptrCast(@alignCast(activity.*.instance orelse return));
        activity.*.instance = null;
        state.cancelled.store(true, .release);
        if (state.event_fd >= 0) _ = c.ALooper_removeFd(c.ALooper_forThread(), state.event_fd);
        // Only the UI thread touches this reference; the reader needs no view.
        if (state.view != null) activity.*.env.*.*.DeleteGlobalRef.?(activity.*.env, state.view);
        state.view = null;
        state.release(activity.*.env);
    }

    fn readWorker(data: ?*anyopaque) callconv(.c) ?*anyopaque {
        const state: *State = @ptrCast(@alignCast(data.?));
        var env: [*c]c.JNIEnv = null;
        const attached = state.vm.*.*.AttachCurrentThread.?(state.vm, &env, null) == c.JNI_OK;
        const vm = state.vm;
        defer if (attached) {
            _ = vm.*.*.DetachCurrentThread.?(vm);
        };
        defer state.release(env);
        if (attached) {
            const j: Jni = .{ .env = env };
            const result = readText(state, j) catch |err| (j.string(message(err)) catch null);
            if (result != null) state.result = j.global(result) catch null;
        }
        state.completed.store(true, .release);
        const signal: u64 = 1;
        while (c.write(state.event_fd, &signal, @sizeOf(u64)) < 0) {
            if (c.__errno().* != c.EINTR) break;
        }
        return null;
    }

    fn readText(state: *State, j: Jni) !c.jobject {
        if (state.cancelled.load(.acquire)) return error.Cancelled;
        const input = try j.call(c.jobject, state.resolver, "openInputStream", "(Landroid/net/Uri;)Ljava/io/InputStream;", &.{.{ .l = state.uri }});
        if (input == null) return error.JavaNull;
        defer j.call(void, input, "close", "()V", &.{}) catch {};
        const buffer = j.env.*.*.NewByteArray.?(j.env, 16384);
        try j.check();
        if (buffer == null) return error.OutOfMemory;
        var bytes: std.ArrayList(u8) = .empty;
        defer bytes.deinit(allocator);
        var chunk: [16384]u8 = undefined;
        while (!state.cancelled.load(.acquire)) {
            const count = try j.call(c.jint, input, "read", "([B)I", &.{.{ .l = buffer }});
            if (count == -1) break;
            if (count <= 0 or count > chunk.len) return error.BadRead;
            const length: usize = @intCast(count);
            if (bytes.items.len + length > max_file_bytes) return error.FileTooLarge;
            j.env.*.*.GetByteArrayRegion.?(j.env, buffer, 0, count, @ptrCast(&chunk));
            try j.check();
            try bytes.appendSlice(allocator, chunk[0..length]);
        }
        if (state.cancelled.load(.acquire)) return error.Cancelled;
        const text = try displayText(allocator, bytes.items);
        defer allocator.free(text);
        const result = j.env.*.*.NewString.?(j.env, text.ptr, @intCast(text.len));
        try j.check();
        return result orelse error.OutOfMemory;
    }

    fn ready(fd: c_int, _: c_int, data: ?*anyopaque) callconv(.c) c_int {
        const state: *State = @ptrCast(@alignCast(data.?));
        var signal: u64 = 0;
        _ = c.read(fd, &signal, @sizeOf(u64));
        if (!state.completed.load(.acquire)) return 1;
        const j: Jni = .{ .env = state.ui_env };
        if (j.env.*.*.PushLocalFrame.?(j.env, 8) < 0) {
            j.check() catch {};
            return 0;
        }
        defer _ = j.env.*.*.PopLocalFrame.?(j.env, null);
        var text = state.result orelse (j.string("Could not load this file.") catch return 0);
        // TextView's no-wrap layout has a finite width. Refuse an extreme line
        // instead of letting Android silently wrap it at that internal limit.
        const paint = j.call(c.jobject, state.view, "getPaint", "()Landroid/text/TextPaint;", &.{}) catch return 0;
        const width = j.staticCall(f32, "android/text/Layout", "getDesiredWidth", "(Ljava/lang/CharSequence;Landroid/text/TextPaint;)F", &.{ .{ .l = text }, .{ .l = paint } }) catch return 0;
        if (!std.math.isFinite(width) or width > 1_000_000)
            text = j.string("A line is too wide for this viewer.\nMaximum line width: 1,000,000 pixels.") catch return 0;
        j.setText(state.view, text) catch {};
        return 0;
    }

    fn message(err: anyerror) [:0]const u8 {
        return switch (err) {
            error.FileTooLarge => std.fmt.comptimePrint("File is too large.\nMaximum: {d} bytes.", .{max_file_bytes}),
            error.InvalidUtf8 => "This file is not valid UTF-8 text.",
            error.NotText => "This file contains binary data\nor unsupported control characters.",
            error.OutOfMemory => "Not enough memory to display this file.",
            error.Cancelled => "Loading cancelled.",
            else => "Could not read this file.\nOpen it again from your file manager.",
        };
    }
};

// On Linux, this same file acts as its own small build/install driver.
pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    const command = if (args.len > 1) args[1] else "build";
    if (args.len > 2) return error.TooManyArguments;
    const zig = init.environ_map.get("VIEW_ZIG") orelse "zig";
    var zig_lib: []const u8 = "";
    if (std.mem.eql(u8, command, "build") or std.mem.eql(u8, command, "install")) {
        const result = try std.process.run(arena, init.io, .{ .argv = &.{ zig, "env" } });
        switch (result.term) {
            .exited => |code| if (code != 0) return error.ZigEnvFailed,
            else => return error.ZigEnvFailed,
        }
        var diagnostics: std.zon.parse.Diagnostics = undefined;
        const env = try std.zon.parse.fromSlice(struct { lib_dir: []const u8, version: []const u8 }, .{
            .gpa = init.gpa,
            .arena = arena,
            .source = try arena.dupeSentinel(u8, result.stdout, 0),
            .diagnostics = &diagnostics,
            .ignore_unknown_fields = true,
        });
        if (!std.mem.eql(u8, env.version, "0.17.0")) {
            std.debug.print("Use Zig 0.17.0; VIEW_ZIG currently selects {s}.\n", .{env.version});
            return error.WrongZigVersion;
        }
        zig_lib = env.lib_dir;
    }
    var child = try std.process.spawn(init.io, .{
        .argv = &.{ "/bin/bash", "-c", build_script, "view", command, zig, zig_lib },
    });
    const term = try child.wait(init.io);
    switch (term) {
        .exited => |code| std.process.exit(code),
        else => std.process.exit(1),
    }
}

const build_script =
    \\set -euo pipefail
    \\case "${1:-build}" in
    \\  help|--help|-h)
    \\    cat <<'HELP'
    \\View: a single-file Zig 0.17.0 Android text viewer.
    \\Commands (run beside view.zig):
    \\  zig run view.zig -- build
    \\  zig run view.zig -- install
    \\  zig test view.zig
    \\Output: zig-out/view.apk
    \\Keep zig-out/view.keystore: it signs subsequent updates to your app.
    \\The install command builds first, then uses adb to install on one USB phone.
    \\
    \\One-time setup on Ubuntu 26.04 x86_64 (Zig 0.17.0 must be on PATH):
    \\  sudo apt update
    \\  sudo apt install openjdk-21-jre-headless curl unzip zip
    \\  export ANDROID_HOME="$HOME/.local/share/android-sdk"
    \\  mkdir -p "$ANDROID_HOME/cmdline-tools"
    \\
    \\If cmdline-tools/latest/bin/sdkmanager is not already installed:
    \\  view_setup="$(mktemp -d)"
    \\  curl -fL https://dl.google.com/android/repository/commandlinetools-linux-16111833_latest.zip -o "$view_setup/tools.zip"
    \\  unzip -q "$view_setup/tools.zip" -d "$view_setup"
    \\  mv "$view_setup/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
    \\
    \\Install the fixed SDK/NDK versions used by this build (accept the SDK
    \\license prompts if you agree to them):
    \\  "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" --sdk_root="$ANDROID_HOME" "platforms;android-36" "build-tools;36.0.0" "ndk;28.2.13676358" "platform-tools"
    \\
    \\On the Pixel: enable Developer options and USB debugging, connect USB,
    \\and accept the computer's debugging prompt before running install.
    \\Alternatively, copy zig-out/view.apk to the phone and open it to install.
    \\
    \\Optional environment overrides:
    \\  VIEW_ZIG          Zig 0.17.0 executable (default: zig)
    \\  ANDROID_HOME      SDK root (default: ~/.local/share/android-sdk)
    \\  VIEW_NDK          NDK root (default: $ANDROID_HOME/ndk/28.2.13676358)
    \\  VIEW_BUILD_TOOLS  SDK build-tools directory (default: 36.0.0)
    \\  VIEW_ANDROID_JAR  Platform android.jar (default: Android 36)
    \\  VIEW_ADB          adb executable (default: SDK platform-tools/adb)
    \\
    \\This is a small-file viewer: UTF-8 text up to 4 MiB, four-column tabs,
    \\basic two-axis drag scrolling, no editing, search, zoom, or formatting.
    \\The file itself contains the font, color, tab, and size-limit constants.
    \\Build references:
    \\  https://developer.android.com/tools/sdkmanager
    \\  https://developer.android.com/tools/aapt2
    \\  https://developer.android.com/guide/practices/page-sizes
    \\HELP
    \\    exit 0 ;;
    \\  build|install) ;;
    \\  *) printf '%s\n' 'Use build, install, or help.' >&2; exit 2 ;;
    \\esac
    \\[[ "$(uname -sm)" == 'Linux x86_64' ]] || { printf '%s\n' 'This build uses the Linux x86_64 Android SDK.' >&2; exit 1; }
    \\[[ -f view.zig ]] || { printf '%s\n' 'Run this command from the directory containing view.zig.' >&2; exit 1; }
    \\zig="$2"
    \\zig_lib="$3"
    \\sdk="${ANDROID_HOME:-$HOME/.local/share/android-sdk}"
    \\ndk="${VIEW_NDK:-$sdk/ndk/28.2.13676358}"
    \\bt="${VIEW_BUILD_TOOLS:-$sdk/build-tools/36.0.0}"
    \\jar="${VIEW_ANDROID_JAR:-$sdk/platforms/android-36/android.jar}"
    \\sysroot="$ndk/toolchains/llvm/prebuilt/linux-x86_64/sysroot"
    \\libs="$sysroot/usr/lib/aarch64-linux-android/26"
    \\for tool in zip java keytool; do
    \\  command -v "$tool" >/dev/null || { printf 'Missing %s; run the Ubuntu setup in help.\n' "$tool" >&2; exit 1; }
    \\done
    \\for path in "$bt/aapt2" "$bt/zipalign" "$bt/apksigner" "$jar" "$libs/libandroid.so" "$sysroot/usr/include/jni.h" "$zig_lib/include/stddef.h"; do
    \\  [[ -f "$path" ]] || { printf 'Missing: %s\nRun: zig run view.zig -- help\n' "$path" >&2; exit 1; }
    \\done
    \\sysroot="$(realpath "$sysroot")"
    \\libs="$sysroot/usr/lib/aarch64-linux-android/26"
    \\source="$(realpath view.zig)"
    \\mkdir -p zig-out/lib/arm64-v8a
    \\out="$(realpath zig-out)"
    \\printf '%s\n' 'Checking text conversion...'
    \\"$zig" test "$source"
    \\cat > "$out/android.h" <<'HEADER'
    \\#include <android/native_activity.h>
    \\#include <android/looper.h>
    \\#include <pthread.h>
    \\#include <sys/eventfd.h>
    \\#include <unistd.h>
    \\#include <errno.h>
    \\HEADER
    \\cat > "$out/android-libc.conf" <<LIBC
    \\include_dir=$sysroot/usr/include
    \\sys_include_dir=$sysroot/usr/include/aarch64-linux-android
    \\crt_dir=$libs
    \\cc_dir=$libs
    \\msvc_lib_dir=
    \\kernel32_lib_dir=
    \\darwin_sdk_dir=
    \\LIBC
    \\printf '%s\n' 'Building Android ARM64 library...'
    \\"$zig" cc -target aarch64-linux-android -D__ANDROID_API__=26 \
    \\  -Wno-macro-redefined -DBIONIC_IOCTL_NO_SIGNEDNESS_OVERLOAD=1 \
    \\  -nostdinc -isystem "$zig_lib/include" \
    \\  -isystem "$sysroot/usr/include" -isystem "$sysroot/usr/include/aarch64-linux-android" \
    \\  -E -P -dD "$out/android.h" -o "$out/android-preprocessed.h"
    \\"$zig" translate-c -target aarch64-linux-android "$out/android-preprocessed.h" > "$out/android.zig"
    \\"$zig" build-lib -target aarch64-linux-android -dynamic -O ReleaseSmall \
    \\  -fPIC -fstrip --name view --libc "$out/android-libc.conf" \
    \\  -L "$libs" -lc -landroid -z max-page-size=16384 -z common-page-size=16384 \
    \\  --dep android -Mroot="$source" -Mandroid="$out/android.zig" \
    \\  -femit-bin="$out/lib/arm64-v8a/libview.so"
    \\cat > "$out/AndroidManifest.xml" <<'MANIFEST'
    \\<?xml version="1.0" encoding="utf-8"?>
    \\<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    \\    package="local.zig.view" android:versionCode="1" android:versionName="0.1.0">
    \\  <uses-sdk android:minSdkVersion="26" android:targetSdkVersion="36" />
    \\  <application android:label="View" android:hasCode="false"
    \\      android:allowBackup="false" android:extractNativeLibs="false"
    \\      android:theme="@android:style/Theme.Material.NoActionBar">
    \\    <activity android:name="android.app.NativeActivity" android:exported="true"
    \\        android:configChanges="orientation|screenSize|keyboardHidden">
    \\      <meta-data android:name="android.app.lib_name" android:value="view" />
    \\      <intent-filter>
    \\        <action android:name="android.intent.action.MAIN" />
    \\        <category android:name="android.intent.category.LAUNCHER" />
    \\      </intent-filter>
    \\      <intent-filter>
    \\        <action android:name="android.intent.action.VIEW" />
    \\        <category android:name="android.intent.category.DEFAULT" />
    \\        <data android:scheme="content" />
    \\        <data android:scheme="file" />
    \\        <data android:mimeType="text/*" />
    \\        <data android:mimeType="application/octet-stream" />
    \\        <data android:mimeType="application/markdown" />
    \\      </intent-filter>
    \\    </activity>
    \\  </application>
    \\</manifest>
    \\MANIFEST
    \\printf '%s\n' 'Packaging and signing APK...'
    \\"$bt/aapt2" link --manifest "$out/AndroidManifest.xml" -I "$jar" -o "$out/unsigned.apk"
    \\(cd "$out" && zip -q -0 unsigned.apk lib/arm64-v8a/libview.so)
    \\"$bt/zipalign" -P 16 -f 4 "$out/unsigned.apk" "$out/aligned.apk"
    \\if [[ ! -f "$out/view.keystore" ]]; then
    \\  (umask 077; keytool -genkeypair -noprompt -keystore "$out/view.keystore" \
    \\    -storetype PKCS12 -storepass android -keypass android -alias view \
    \\    -keyalg RSA -keysize 2048 -validity 10000 -dname 'CN=View Local Build')
    \\fi
    \\"$bt/apksigner" sign --ks "$out/view.keystore" --ks-key-alias view \
    \\  --ks-pass pass:android --key-pass pass:android --out "$out/view.apk" "$out/aligned.apk"
    \\"$bt/apksigner" verify "$out/view.apk"
    \\"$bt/zipalign" -c -P 16 4 "$out/view.apk"
    \\printf '\nBuilt: %s/view.apk\nKeep:  %s/view.keystore (needed to sign future updates)\n' "$out" "$out"
    \\if [[ "$1" == install ]]; then
    \\  adb="${VIEW_ADB:-$sdk/platform-tools/adb}"
    \\  [[ -x "$adb" ]] || adb="$(command -v adb)"
    \\  "$adb" -d install -r "$out/view.apk"
    \\fi
;

test "display preserves Unicode and blank lines, normalizes line endings and tabs" {
    const actual = try displayText(std.testing.allocator, "\xef\xbb\xbfconst x = 1;\r\n\t// café 😀\r\n\nend\r");
    defer std.testing.allocator.free(actual);
    const expected = try std.unicode.utf8ToUtf16LeAlloc(std.testing.allocator, "const x = 1;\n    // café 😀\n\nend\n");
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualSlices(u16, expected, actual);
}

test "tabs advance to column stops and empty files stay empty" {
    const actual = try displayText(std.testing.allocator, "a\tb\n1234\tz");
    defer std.testing.allocator.free(actual);
    const expected = try std.unicode.utf8ToUtf16LeAlloc(std.testing.allocator, "a   b\n1234    z");
    defer std.testing.allocator.free(expected);
    try std.testing.expectEqualSlices(u16, expected, actual);
    const empty = try displayText(std.testing.allocator, "");
    defer std.testing.allocator.free(empty);
    try std.testing.expectEqual(@as(usize, 0), empty.len);
}

test "binary data, invalid UTF-8, and oversized input are rejected" {
    try std.testing.expectError(error.NotText, displayText(std.testing.allocator, "a\x00b"));
    try std.testing.expectError(error.InvalidUtf8, displayText(std.testing.allocator, "\xc0\xaf"));
    const too_large = try std.testing.allocator.alloc(u8, max_file_bytes + 1);
    defer std.testing.allocator.free(too_large);
    try std.testing.expectError(error.FileTooLarge, displayText(std.testing.allocator, too_large));
}
