// file: src/main.zig
// This is a single-file, dependency-light, first-principles
// 3d/visual debugger. Written to help me with work and home projects.
// I would like for this to be a reusable frontent debugger for arbitrary
// backend data. This is not a general purpose GUI or engine solution, and
// should provide basic primitives for things as I see it. There are generic
// 2D/3D primitives, initially rendering in software directly through Linux
// interfaces. Naive implementation does not target a wide range of GPU's.
//
// A usage example would be a backend or disposable adapter that translates
// domain data such as MAVLink, SDR, LiDAR, video, RTSP, recordings,
// path-planning, ADS-B, networking transport, network connections,
// custom binary protocols, memory access and buffers, shared memory access,
// interrupts, and other primitive structures into a set of cohesive visual
// primitives for the purpose of debugging discrepancies that may seem correct
// until visual runtime inspection. The core should display these primitives
// without needing to understand their domain specific meanings.
//
// Initial Scope / Goals to help with Telemetry at Work
// ----------------------------------------------------
//   * Keep the visualization core independent of MAVLink, SDR, LiDAR, video,
//     and every other telemetry source. I plug/point my backend here.
//   * Provide generic primitives: scalar values, text/logs, time series,
//     Point2D, Point3D, polylines, meshes, image frames, GeoPoint, GeoPath,
//     point clouds, colors, and transforms.
//   * Remain frontend-only. Algorithms, radio processing, networking, control,
//     decoding, and backend state ownership stay outside the visualizer.
//   * Run on low-end 64-bit Linux/ARM64 or Linux/X86_64 devices with bounded
//     memory: no Qt, SDL, GLFW, raylib, Vulkan, X11, Wayland, Cesium dependencies.
//   * Render from first principles into a CPU pixel buffer and present through
//     the Linux framebuffer. A headless PPM path is included for development.
//   * Should extend the PPM to a custom pixel map format that assigns an
//     arbitrary array of value/type information on a per pixel basis using
//     simd primitives.
//   * Be useful with no map and no particular adapter. The procedural world
//     view is optional visual context rather than the center of the program.
//   * Keep adapters disposable. Deleting every MAVLink-specific or SDR-specific
//     line from a future integration must leave a valid telemetry debugger.
//   * Avoid unbounded growth. Scene collections, logs, series, and point clouds
//     have explicit limits suitable for small devices. I should set hard
//     bounded limits at first to identify problem domains and force minimal
//     scope.
//
// Prototype scope
// ---------------
//   * Direct /dev/fb0 presentation with 16/24/32-bit framebuffer conversion.
//   * Raw terminal keyboard input and optional /dev/input/mice input.
//   * A generic in-memory scene API usable by future embedded adapters.
//   * A low-rate UDP text adapter for quick debugging and a synthetic demo.
//   * Overview, map, 3D, plot, image, scalar, and log visualization.
//   * Software 2D rasterization and a depth-buffered 3D point/line/triangle
//     renderer.
//
// The UDP text adapter is intentionally not the high-bandwidth architecture.
// It is convenient for scalars, paths, and debug markers. Video and large point
// clouds should eventually arrive through memfd/shared memory, SCM_RIGHTS, or a
// purpose-built binary protocol, then populate the same Scene API.
//
// Build with Zig 0.17.0:
//
//     zig build test             // Compile and run all tests
//     zig build                  // Test, compile, and install
//     zig build install          // Test, compile, and install
//     zig build run --           // Install and run locally
//
// Run on a dedicated Linux framebuffer console:
//
//     sudo ./zig-out/bin/3dbg --fb /dev/fb0 --mouse /dev/input/mice --udp 7777
//
// Render one headless frame for inspection:
//
//     zig build run -- --ppm 3dbg.ppm --frames 1 --size 1280x720
//
// UDP protocol, one or more newline-separated commands per datagram:
//
//     scalar NAME VALUE UNIT AARRGGBB
//     series NAME VALUE UNIT AARRGGBB
//     log LEVEL MESSAGE...
//     p2 ID X Y SIZE AARRGGBB LABEL...
//     label2 ID X Y AARRGGBB TEXT...
//     p3 ID X Y Z SIZE AARRGGBB LABEL...
//     geo ID LAT LON ALT HEADING AARRGGBB LABEL...
//     cloud_clear
//     cloud X Y Z SIZE AARRGGBB
//     clear all|p2|p3|geo|cloud|series|logs
//     view overview|map|scene|plots|image
//
// Coordinate conventions:
//   * Point2D/Text2D positions are normalized around the view center; -1..+1
//     spans most of the panel in each axis.
//   * Point3D, meshes, polylines, and point clouds use adapter-defined local
//     units; use one unit per meter when metric scale matters.
//   * GeoPoint/GeoPath use latitude/longitude degrees and altitude meters.
//   * Wire colors use AARRGGBB or RRGGBB text; image pixels use ARGB u32.
//
// Examples:
//
//     printf 'series rf_power -42.5 dBm FF49CFFF\n' | nc -u 127.0.0.1 7777
//     printf 'geo 7 29.7604 -95.3698 420 90 FF49CFFF UAV-7\n' | nc -u 127.0.0.1 7777

const std = @import("std");
const builtin = @import("builtin");
const c = std.c;
const linux = std.os.linux;
const pi: f64 = std.math.pi;
const rad_per_deg: f64 = std.math.rad_per_deg;

// limitations right now
comptime {
    if (builtin.os.tag != .linux)
        @compileError("3dbg currently provides a Linux framebuffer platform backend");
    if (@sizeOf(usize) != 8)
        @compileError("3dbg currently requires a 64-bit Linux userspace");
    if (builtin.cpu.arch.endian() != .little)
        @compileError("the prototype framebuffer and socket ABI currently target little-endian Linux");
}

// framebuffer
const fb = struct {
    pub const GET_VSCREENINFO: c_int = 0x4600;
    pub const GET_FSCREENINFO: c_int = 0x4602;

    pub const Bitfield = extern struct {
        offset: u32,
        length: u32,
        msb_right: u32,
    };

    pub const VarScreenInfo = extern struct {
        xres: u32,
        yres: u32,
        xres_virtual: u32,
        yres_virtual: u32,
        xoffset: u32,
        yoffset: u32,
        bits_per_pixel: u32,
        grayscale: u32,
        red: Bitfield,
        green: Bitfield,
        blue: Bitfield,
        transp: Bitfield,
        nonstd: u32,
        activate: u32,
        height: u32,
        width: u32,
        accel_flags: u32,
        pixclock: u32,
        left_margin: u32,
        right_margin: u32,
        upper_margin: u32,
        lower_margin: u32,
        hsync_len: u32,
        vsync_len: u32,
        sync: u32,
        vmode: u32,
        rotate: u32,
        colorspace: u32,
        reserved: [4]u32,
    };

    pub const FixScreenInfo = extern struct {
        id: [16]u8,
        smem_start: c_ulong,
        smem_len: u32,
        type: u32,
        type_aux: u32,
        visual: u32,
        xpanstep: u16,
        ypanstep: u16,
        ywrapstep: u16,
        line_length: u32,
        mmio_start: c_ulong,
        mmio_len: u32,
        accel: u32,
        capabilities: u16,
        reserved: [2]u16,
    };
};

fn FixedText(comptime capacity: usize) type {
    return struct {
        const Self = @This();

        bytes: [capacity]u8 = @splat(0),
        len: u16 = 0,

        pub fn set(self: *Self, text: []const u8) void {
            const count = @min(text.len, capacity);
            if (count > 0) @memcpy(self.bytes[0..count], text[0..count]);
            if (count < capacity) @memset(self.bytes[count..], 0);
            self.len = @intCast(count);
        }

        pub fn from(text: []const u8) Self {
            var result: Self = .{};
            result.set(text);
            return result;
        }

        pub fn slice(self: *const Self) []const u8 {
            return self.bytes[0..@as(usize, self.len)];
        }

        pub fn eql(self: *const Self, text: []const u8) bool {
            return std.mem.eql(u8, self.slice(), text);
        }
    };
}
pub const Name = FixedText(32);
pub const Unit = FixedText(16);
pub const Label = FixedText(64);
pub const Message = FixedText(192);

pub const Pos2 = @Vector(2, f32); // Continuous 2D position
pub const Pos3 = @Vector(3, f32); // Continuous 3D position

pub const Coord2 = @Vector(2, i32); // Integer 2D coordinates
pub const Coord3 = @Vector(3, i32); // Integer 3D coordinates

// (x,y) - top left pixel position in screen coordinates
// (j,k) - vector for directional width and height, relative to coordinate sys.
pub const Rect = [2]Coord2;

// (x,y,z) - Same as x,y for Rect, but added z depth to determine which
// geometry is in front
pub const ScreenVertex = @Vector(3, f32);

pub const Color = @Vector(4, u8); // rgba

const palette = struct {
    const background = Color{ 8, 12, 18, 255 };
    const panel = Color{ 17, 26, 36, 255 };
    const panel_alt = Color{ 24, 37, 50, 255 };
    const border = Color{ 58, 82, 103, 255 };
    const text = Color{ 224, 234, 242, 255 };
    const muted = Color{ 133, 153, 168, 255 };
    const accent = Color{ 73, 207, 255, 255 };
    const good = Color{ 78, 220, 132, 255 };
    const warning = Color{ 255, 188, 75, 255 };
    const danger = Color{ 255, 82, 93, 255 };
    const ocean = Color{ 20, 54, 80, 255 };
    const land = Color{ 61, 78, 61, 255 };
    const grid = Color{ 80, 116, 138, 120 };
    const axis_x = Color{ 255, 88, 88, 255 };
    const axis_y = Color{ 88, 230, 124, 255 };
    const axis_z = Color{ 83, 153, 255, 255 };
};

const Canvas = struct {
    allocator: std.mem.Allocator,
    width: usize,
    height: usize,
    pixels: []u32,
    depth: []f32,
    clip: Rect,

    fn init(allocator: std.mem.Allocator, width: usize, height: usize) !Canvas {
        if (width < 320 or height < 240 or width > 8192 or height > 8192) return error.InvalidSize;
        const pixel_buffer = try allocator.alloc(u32, width * height);
        errdefer allocator.free(pixel_buffer);
        const depth_buffer = try allocator.alloc(f32, width * height);
        return .{
            .allocator = allocator,
            .width = width,
            .height = height,
            .pixels = pixel_buffer,
            .depth = depth_buffer,
            .clip = .{ .{ 0, 0 }, .{ @intCast(width), @intCast(height) } },
        };
    }

    fn deinit(self: *Canvas) void {
        self.allocator.free(self.depth);
        self.allocator.free(self.pixels);
        self.* = undefined;
    }

    fn setClip(self: *Canvas, rect: Rect) void {
        const extent: Coord2 = .{ @intCast(self.width), @intCast(self.height) };
        const zero: Coord2 = @splat(0);
        const start = std.math.clamp(rect[0], zero, extent);
        const end = std.math.clamp(rect[0] + rect[1], zero, extent);
        self.clip = .{ start, @max(zero, end - start) };
    }

    fn resetClip(self: *Canvas) void {
        self.clip = .{ .{ 0, 0 }, .{ @intCast(self.width), @intCast(self.height) } };
    }

    fn clear(self: *Canvas, color: Color) void {
        @memset(self.pixels, argb(color));
    }

    fn clearDepth(self: *Canvas) void {
        @memset(self.depth, std.math.inf(f32));
    }

    fn blend(dst: u32, color: Color) u32 {
        if (color[3] == 255) return argb(color);
        if (color[3] == 0) return dst;
        const inv: u32 = 255 - @as(u32, color[3]);
        const dr = (dst >> 16) & 0xff;
        const dg = (dst >> 8) & 0xff;
        const db = dst & 0xff;
        const r = (@as(u32, color[0]) * @as(u32, color[3]) + dr * inv) / 255;
        const g = (@as(u32, color[1]) * @as(u32, color[3]) + dg * inv) / 255;
        const b = (@as(u32, color[2]) * @as(u32, color[3]) + db * inv) / 255;
        return 0xff00_0000 | (r << 16) | (g << 8) | b;
    }

    fn putPixel(self: *Canvas, x: i32, y: i32, color: Color) void {
        if (x < self.clip[0][0] or y < self.clip[0][1] or
            x >= self.clip[0][0] + self.clip[1][0] or y >= self.clip[0][1] + self.clip[1][1]) return;
        const index = @as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x));
        self.pixels[index] = blend(self.pixels[index], color);
    }

    fn putDepthPixel(self: *Canvas, x: i32, y: i32, depth_value: f32, color: Color) void {
        if (x < self.clip[0][0] or y < self.clip[0][1] or
            x >= self.clip[0][0] + self.clip[1][0] or y >= self.clip[0][1] + self.clip[1][1]) return;
        const index = @as(usize, @intCast(y)) * self.width + @as(usize, @intCast(x));
        if (depth_value >= self.depth[index]) return;
        self.depth[index] = depth_value;
        self.pixels[index] = blend(self.pixels[index], color);
    }

    fn fillRect(self: *Canvas, rect: Rect, color: Color) void {
        const x0 = @max(rect[0][0], self.clip[0][0]);
        const y0 = @max(rect[0][1], self.clip[0][1]);
        const x1 = @min(rect[0][0] + rect[1][0], self.clip[0][0] + self.clip[1][0]);
        const y1 = @min(rect[0][1] + rect[1][1], self.clip[0][1] + self.clip[1][1]);
        if (x1 <= x0 or y1 <= y0) return;
        var y = y0;
        while (y < y1) : (y += 1) {
            const row_start = @as(usize, @intCast(y)) * self.width;
            const row = self.pixels[row_start + @as(usize, @intCast(x0)) .. row_start + @as(usize, @intCast(x1))];
            if (color[3] == 255) {
                @memset(row, argb(color));
            } else {
                for (row) |*pixel| pixel.* = blend(pixel.*, color);
            }
        }
    }

    fn strokeRect(self: *Canvas, rect: Rect, color: Color) void {
        self.line(.{ rect[0][0], rect[0][1] }, .{ rect[0][0] + rect[1][0] - 1, rect[0][1] }, color, 1);
        self.line(.{ rect[0][0], rect[0][1] + rect[1][1] - 1 }, .{ rect[0][0] + rect[1][0] - 1, rect[0][1] + rect[1][1] - 1 }, color, 1);
        self.line(.{ rect[0][0], rect[0][1] }, .{ rect[0][0], rect[0][1] + rect[1][1] - 1 }, color, 1);
        self.line(.{ rect[0][0] + rect[1][0] - 1, rect[0][1] }, .{ rect[0][0] + rect[1][0] - 1, rect[0][1] + rect[1][1] - 1 }, color, 1);
    }

    fn line(self: *Canvas, start: Coord2, end: Coord2, color: Color, width_value: i32) void {
        var x0 = start[0];
        var y0 = start[1];
        const x1 = end[0];
        const y1 = end[1];
        const dx: i32 = if (x1 >= x0) x1 - x0 else x0 - x1;
        const sx: i32 = if (x0 < x1) 1 else -1;
        const dy: i32 = -(if (y1 >= y0) y1 - y0 else y0 - y1);
        const sy: i32 = if (y0 < y1) 1 else -1;
        var err = dx + dy;
        const radius: i32 = @max(0, @divTrunc(width_value - 1, 2));
        while (true) {
            if (radius == 0) self.putPixel(x0, y0, color) else self.fillCircle(.{ x0, y0 }, radius, color);
            if (x0 == x1 and y0 == y1) break;
            const e2 = 2 * err;
            if (e2 >= dy) {
                err += dy;
                x0 += sx;
            }
            if (e2 <= dx) {
                err += dx;
                y0 += sy;
            }
        }
    }

    fn depthLine(self: *Canvas, a: ScreenVertex, b: ScreenVertex, color: Color, width_value: i32) void {
        const dx = b[0] - a[0];
        const dy = b[1] - a[1];
        const steps_float = @max(@abs(dx), @abs(dy));
        const steps: i32 = @max(1, @as(i32, @intFromFloat(@ceil(steps_float))));
        const radius: i32 = @max(0, @divTrunc(width_value - 1, 2));
        var index: i32 = 0;
        while (index <= steps) : (index += 1) {
            const t = @as(f32, @floatFromInt(index)) / @as(f32, @floatFromInt(steps));
            const x: i32 = @intFromFloat(a[0] + dx * t);
            const y: i32 = @intFromFloat(a[1] + dy * t);
            const depth_value = a[2] + (b[2] - a[2]) * t;
            var oy: i32 = -radius;
            while (oy <= radius) : (oy += 1) {
                var ox: i32 = -radius;
                while (ox <= radius) : (ox += 1) {
                    if (ox * ox + oy * oy <= radius * radius) self.putDepthPixel(x + ox, y + oy, depth_value, color);
                }
            }
            if (radius == 0) self.putDepthPixel(x, y, depth_value, color);
        }
    }

    fn fillCircle(self: *Canvas, center: Coord2, radius: i32, color: Color) void {
        if (radius <= 0) {
            self.putPixel(center[0], center[1], color);
            return;
        }
        var y: i32 = -radius;
        while (y <= radius) : (y += 1) {
            const inside = radius * radius - y * y;
            const span: i32 = @intFromFloat(@sqrt(@as(f64, @floatFromInt(@max(0, inside)))));
            self.fillRect(.{ .{ center[0] - span, center[1] + y }, .{ span * 2 + 1, 1 } }, color);
        }
    }

    fn depthCircle(self: *Canvas, center: Coord2, radius: i32, depth_value: f32, color: Color) void {
        const actual_radius: i32 = @max(0, radius);
        var y: i32 = -actual_radius;
        while (y <= actual_radius) : (y += 1) {
            var x: i32 = -actual_radius;
            while (x <= actual_radius) : (x += 1) {
                if (x * x + y * y <= actual_radius * actual_radius)
                    self.putDepthPixel(center[0] + x, center[1] + y, depth_value, color);
            }
        }
    }

    fn circle(self: *Canvas, center: Coord2, radius: i32, color: Color) void {
        if (radius <= 0) return;
        var x = radius;
        var y: i32 = 0;
        var error_value: i32 = 1 - radius;
        while (x >= y) {
            const points = [_]Coord2{
                .{ center[0] + x, center[1] + y },
                .{ center[0] + y, center[1] + x },
                .{ center[0] - y, center[1] + x },
                .{ center[0] - x, center[1] + y },
                .{ center[0] - x, center[1] - y },
                .{ center[0] - y, center[1] - x },
                .{ center[0] + y, center[1] - x },
                .{ center[0] + x, center[1] - y },
            };
            for (points) |point| self.putPixel(point[0], point[1], color);
            y += 1;
            if (error_value < 0) {
                error_value += 2 * y + 1;
            } else {
                x -= 1;
                error_value += 2 * (y - x) + 1;
            }
        }
    }

    fn fillTriangle(self: *Canvas, a: Coord2, b: Coord2, d: Coord2, color: Color) void {
        var points = [_]Coord2{ a, b, d };
        if (points[1][1] < points[0][1]) std.mem.swap(Coord2, &points[0], &points[1]);
        if (points[2][1] < points[0][1]) std.mem.swap(Coord2, &points[0], &points[2]);
        if (points[2][1] < points[1][1]) std.mem.swap(Coord2, &points[1], &points[2]);
        const p0 = points[0];
        const p1 = points[1];
        const p2 = points[2];
        if (p0[1] == p2[1]) return;
        var y = @max(p0[1], self.clip[0][1]);
        const y_end = @min(p2[1], self.clip[0][1] + self.clip[1][1] - 1);
        while (y <= y_end) : (y += 1) {
            const long_t = @as(f64, @floatFromInt(y - p0[1])) / @as(f64, @floatFromInt(p2[1] - p0[1]));
            const long_x = @as(f64, @floatFromInt(p0[0])) + @as(f64, @floatFromInt(p2[0] - p0[0])) * long_t;
            const short_x = if (y < p1[1] and p1[1] != p0[1])
                @as(f64, @floatFromInt(p0[0])) + @as(f64, @floatFromInt(p1[0] - p0[0])) *
                    (@as(f64, @floatFromInt(y - p0[1])) / @as(f64, @floatFromInt(p1[1] - p0[1])))
            else if (p2[1] != p1[1])
                @as(f64, @floatFromInt(p1[0])) + @as(f64, @floatFromInt(p2[0] - p1[0])) *
                    (@as(f64, @floatFromInt(y - p1[1])) / @as(f64, @floatFromInt(p2[1] - p1[1])))
            else
                @as(f64, @floatFromInt(p1[0]));
            const left: i32 = @intFromFloat(@floor(@min(long_x, short_x)));
            const right: i32 = @intFromFloat(@ceil(@max(long_x, short_x)));
            self.fillRect(.{ .{ left, y }, .{ right - left + 1, 1 } }, color);
        }
    }

    fn edge(a: ScreenVertex, b: ScreenVertex, x: f32, y: f32) f32 {
        return (x - a[0]) * (b[1] - a[1]) - (y - a[1]) * (b[0] - a[0]);
    }

    fn depthTriangle(self: *Canvas, a: ScreenVertex, b: ScreenVertex, d: ScreenVertex, color: Color) void {
        const area = edge(a, b, d[0], d[1]);
        if (@abs(area) < 0.000001) return;
        const min_x: i32 = @max(self.clip[0][0], @as(i32, @intFromFloat(@floor(@min(a[0], @min(b[0], d[0]))))));
        const max_x: i32 = @min(self.clip[0][0] + self.clip[1][0] - 1, @as(i32, @intFromFloat(@ceil(@max(a[0], @max(b[0], d[0]))))));
        const min_y: i32 = @max(self.clip[0][1], @as(i32, @intFromFloat(@floor(@min(a[1], @min(b[1], d[1]))))));
        const max_y: i32 = @min(self.clip[0][1] + self.clip[1][1] - 1, @as(i32, @intFromFloat(@ceil(@max(a[1], @max(b[1], d[1]))))));
        var y = min_y;
        while (y <= max_y) : (y += 1) {
            var x = min_x;
            while (x <= max_x) : (x += 1) {
                const px = @as(f32, @floatFromInt(x)) + 0.5;
                const py = @as(f32, @floatFromInt(y)) + 0.5;
                const w0 = edge(b, d, px, py) / area;
                const w1 = edge(d, a, px, py) / area;
                const w2 = edge(a, b, px, py) / area;
                if (w0 >= 0 and w1 >= 0 and w2 >= 0) {
                    const depth_value = a[2] * w0 + b[2] * w1 + d[2] * w2;
                    self.putDepthPixel(x, y, depth_value, color);
                }
            }
        }
    }

    fn fillPolygon(self: *Canvas, points: []const Coord2, color: Color, scratch: []i32) void {
        if (points.len < 3 or scratch.len < points.len) return;
        var min_y = points[0][1];
        var max_y = points[0][1];
        for (points[1..]) |point| {
            min_y = @min(min_y, point[1]);
            max_y = @max(max_y, point[1]);
        }
        min_y = @max(min_y, self.clip[0][1]);
        max_y = @min(max_y, self.clip[0][1] + self.clip[1][1] - 1);
        var y = min_y;
        while (y <= max_y) : (y += 1) {
            var count: usize = 0;
            var previous = points[points.len - 1];
            for (points) |current| {
                if ((previous[1] <= y and current[1] > y) or (current[1] <= y and previous[1] > y)) {
                    const numerator = @as(i64, current[0] - previous[0]) * @as(i64, y - previous[1]);
                    const denominator = current[1] - previous[1];
                    scratch[count] = previous[0] + @as(i32, @intCast(@divTrunc(numerator, @as(i64, denominator))));
                    count += 1;
                }
                previous = current;
            }
            std.mem.sort(i32, scratch[0..count], {}, std.sort.asc(i32));
            var index: usize = 0;
            while (index + 1 < count) : (index += 2) {
                const left = scratch[index];
                const right = scratch[index + 1];
                self.fillRect(.{ .{ left, y }, .{ right - left + 1, 1 } }, color);
            }
        }
    }

    fn glyph(character: u8) [5]u8 {
        const ch = std.ascii.toUpper(character);
        return switch (ch) {
            '0' => .{ 0x3e, 0x51, 0x49, 0x45, 0x3e },
            '1' => .{ 0x00, 0x42, 0x7f, 0x40, 0x00 },
            '2' => .{ 0x42, 0x61, 0x51, 0x49, 0x46 },
            '3' => .{ 0x21, 0x41, 0x45, 0x4b, 0x31 },
            '4' => .{ 0x18, 0x14, 0x12, 0x7f, 0x10 },
            '5' => .{ 0x27, 0x45, 0x45, 0x45, 0x39 },
            '6' => .{ 0x3c, 0x4a, 0x49, 0x49, 0x30 },
            '7' => .{ 0x01, 0x71, 0x09, 0x05, 0x03 },
            '8' => .{ 0x36, 0x49, 0x49, 0x49, 0x36 },
            '9' => .{ 0x06, 0x49, 0x49, 0x29, 0x1e },
            'A' => .{ 0x7e, 0x11, 0x11, 0x11, 0x7e },
            'B' => .{ 0x7f, 0x49, 0x49, 0x49, 0x36 },
            'C' => .{ 0x3e, 0x41, 0x41, 0x41, 0x22 },
            'D' => .{ 0x7f, 0x41, 0x41, 0x22, 0x1c },
            'E' => .{ 0x7f, 0x49, 0x49, 0x49, 0x41 },
            'F' => .{ 0x7f, 0x09, 0x09, 0x09, 0x01 },
            'G' => .{ 0x3e, 0x41, 0x49, 0x49, 0x7a },
            'H' => .{ 0x7f, 0x08, 0x08, 0x08, 0x7f },
            'I' => .{ 0x00, 0x41, 0x7f, 0x41, 0x00 },
            'J' => .{ 0x20, 0x40, 0x41, 0x3f, 0x01 },
            'K' => .{ 0x7f, 0x08, 0x14, 0x22, 0x41 },
            'L' => .{ 0x7f, 0x40, 0x40, 0x40, 0x40 },
            'M' => .{ 0x7f, 0x02, 0x0c, 0x02, 0x7f },
            'N' => .{ 0x7f, 0x04, 0x08, 0x10, 0x7f },
            'O' => .{ 0x3e, 0x41, 0x41, 0x41, 0x3e },
            'P' => .{ 0x7f, 0x09, 0x09, 0x09, 0x06 },
            'Q' => .{ 0x3e, 0x41, 0x51, 0x21, 0x5e },
            'R' => .{ 0x7f, 0x09, 0x19, 0x29, 0x46 },
            'S' => .{ 0x46, 0x49, 0x49, 0x49, 0x31 },
            'T' => .{ 0x01, 0x01, 0x7f, 0x01, 0x01 },
            'U' => .{ 0x3f, 0x40, 0x40, 0x40, 0x3f },
            'V' => .{ 0x1f, 0x20, 0x40, 0x20, 0x1f },
            'W' => .{ 0x3f, 0x40, 0x38, 0x40, 0x3f },
            'X' => .{ 0x63, 0x14, 0x08, 0x14, 0x63 },
            'Y' => .{ 0x07, 0x08, 0x70, 0x08, 0x07 },
            'Z' => .{ 0x61, 0x51, 0x49, 0x45, 0x43 },
            '-' => .{ 0x08, 0x08, 0x08, 0x08, 0x08 },
            '_' => .{ 0x40, 0x40, 0x40, 0x40, 0x40 },
            '.' => .{ 0x00, 0x60, 0x60, 0x00, 0x00 },
            ',' => .{ 0x00, 0x40, 0x20, 0x00, 0x00 },
            ':' => .{ 0x00, 0x36, 0x36, 0x00, 0x00 },
            ';' => .{ 0x00, 0x56, 0x36, 0x00, 0x00 },
            '/' => .{ 0x20, 0x10, 0x08, 0x04, 0x02 },
            '\\' => .{ 0x02, 0x04, 0x08, 0x10, 0x20 },
            '+' => .{ 0x08, 0x08, 0x3e, 0x08, 0x08 },
            '=' => .{ 0x14, 0x14, 0x14, 0x14, 0x14 },
            '%' => .{ 0x62, 0x64, 0x08, 0x13, 0x23 },
            '(' => .{ 0x00, 0x1c, 0x22, 0x41, 0x00 },
            ')' => .{ 0x00, 0x41, 0x22, 0x1c, 0x00 },
            '[' => .{ 0x00, 0x7f, 0x41, 0x41, 0x00 },
            ']' => .{ 0x00, 0x41, 0x41, 0x7f, 0x00 },
            '<' => .{ 0x08, 0x14, 0x22, 0x41, 0x00 },
            '>' => .{ 0x00, 0x41, 0x22, 0x14, 0x08 },
            '!' => .{ 0x00, 0x00, 0x5f, 0x00, 0x00 },
            '?' => .{ 0x02, 0x01, 0x51, 0x09, 0x06 },
            '#' => .{ 0x14, 0x7f, 0x14, 0x7f, 0x14 },
            '*' => .{ 0x14, 0x08, 0x3e, 0x08, 0x14 },
            '|' => .{ 0x00, 0x00, 0x7f, 0x00, 0x00 },
            ' ' => .{ 0, 0, 0, 0, 0 },
            else => .{ 0x7f, 0x41, 0x5d, 0x41, 0x7f },
        };
    }

    fn textWidth(_: *const Canvas, text: []const u8, scale_value: i32) i32 {
        return @as(i32, @intCast(text.len)) * 6 * scale_value;
    }

    fn drawText(self: *Canvas, origin: Coord2, text: []const u8, scale_value: i32, color: Color) void {
        var x = origin[0];
        for (text) |character| {
            const bits = glyph(character);
            for (bits, 0..) |column, column_index| {
                var row: usize = 0;
                while (row < 7) : (row += 1) {
                    if ((column & (@as(u8, 1) << @intCast(row))) != 0) {
                        self.fillRect(.{ .{ x + @as(i32, @intCast(column_index)) * scale_value, origin[1] + @as(i32, @intCast(row)) * scale_value }, .{ scale_value, scale_value } }, color);
                    }
                }
            }
            x += 6 * scale_value;
        }
    }

    fn drawImageNearest(self: *Canvas, destination: Rect, source_width: usize, source_height: usize, pixels: []const u32) void {
        if (source_width == 0 or source_height == 0 or pixels.len < source_width * source_height) return;
        const x0 = @max(destination[0][0], self.clip[0][0]);
        const y0 = @max(destination[0][1], self.clip[0][1]);
        const x1 = @min(destination[0][0] + destination[1][0], self.clip[0][0] + self.clip[1][0]);
        const y1 = @min(destination[0][1] + destination[1][1], self.clip[0][1] + self.clip[1][1]);
        if (x1 <= x0 or y1 <= y0) return;
        var y = y0;
        while (y < y1) : (y += 1) {
            const source_y: usize = @intCast(std.math.clamp(@divTrunc((y - destination[0][1]) * @as(i32, @intCast(source_height)), @max(1, destination[1][1])), 0, @as(i32, @intCast(source_height)) - 1));
            var x = x0;
            while (x < x1) : (x += 1) {
                const source_x: usize = @intCast(std.math.clamp(@divTrunc((x - destination[0][0]) * @as(i32, @intCast(source_width)), @max(1, destination[1][0])), 0, @as(i32, @intCast(source_width)) - 1));
                self.putPixel(x, y, fromArgb(pixels[source_y * source_width + source_x]));
            }
        }
    }
};

fn argb(self: Color) u32 {
    return (@as(u32, self[3]) << 24) |
        (@as(u32, self[0]) << 16) |
        (@as(u32, self[1]) << 8) |
        @as(u32, self[2]);
}

fn fromArgb(value: u32) Color {
    return .{ @truncate(value >> 16), @truncate(value >> 8), @truncate(value), @truncate(value >> 24) };
}

fn shade(color: Color, multiplier: f32) Color {
    const factor = std.math.clamp(multiplier, 0.0, 2.0);
    const channels: @Vector(4, f32) = @floatFromInt(color);
    const factors: @Vector(4, f32) = .{ factor, factor, factor, 1 };
    return @intFromFloat(std.math.clamp(channels * factors, @as(@Vector(4, f32), @splat(0)), @as(@Vector(4, f32), @splat(255))));
}

test "colors, shading and blending" {
    try std.testing.expectEqual(@as(u32, 0x7812_3456), argb(.{ 0x12, 0x34, 0x56, 0x78 }));
    try std.testing.expectEqual(Color{ 0x12, 0x34, 0x56, 0x78 }, fromArgb(0x7812_3456));
    try std.testing.expectEqual(Color{ 50, 100, 125, 77 }, shade(.{ 100, 200, 250, 77 }, 0.5));
    try std.testing.expectEqual(Color{ 200, 255, 255, 77 }, shade(.{ 100, 200, 250, 77 }, 3));
    try std.testing.expectEqual(Color{ 0, 0, 0, 77 }, shade(.{ 100, 200, 250, 77 }, -1));
    try std.testing.expectEqual(@as(u32, 0xff12_3456), Canvas.blend(0xff12_3456, .{ 255, 0, 0, 0 }));
    try std.testing.expectEqual(@as(u32, 0xffff_0000), Canvas.blend(0xff12_3456, .{ 255, 0, 0, 255 }));
    try std.testing.expectEqual(@as(u32, 0xff80_0000), Canvas.blend(0xff00_0000, .{ 255, 0, 0, 128 }));
}

pub const Transform = struct {
    translation: Pos3 = @splat(0),
    rotation_deg: Pos3 = @splat(0),
    scale: Pos3 = @splat(1),
};

fn dot(a: Pos3, b: Pos3) f32 {
    return @reduce(.Add, a * b);
}

fn cross(a: Pos3, b: Pos3) Pos3 {
    return .{
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    };
}

fn length(v: Pos3) f32 {
    return @sqrt(dot(v, v));
}

fn normalize(v: Pos3) Pos3 {
    const len = length(v);
    if (len <= 0.000001) return @splat(0);
    return v / @as(Pos3, @splat(len));
}

fn finiteVector(v: anytype) bool {
    inline for (0..@typeInfo(@TypeOf(v)).vector.len) |i| {
        if (!std.math.isFinite(v[i])) return false;
    }
    return true;
}

fn finiteTransform(t: Transform) bool {
    return finiteVector(t.translation) and
        finiteVector(t.rotation_deg) and
        finiteVector(t.scale);
}

fn parseFiniteFloat(comptime T: type, text: []const u8) !T {
    const value = try std.fmt.parseFloat(T, text);
    if (!std.math.isFinite(value)) return error.NonFiniteNumber;
    return value;
}

fn contains(rect: Rect, point: Coord2) bool {
    return @reduce(.And, point >= rect[0]) and @reduce(.And, point < rect[0] + rect[1]);
}

fn inset(rect: Rect, amount: i32) Rect {
    return .{ rect[0] + @as(Coord2, @splat(amount)), @max(@as(Coord2, @splat(0)), rect[1] - @as(Coord2, @splat(amount * 2))) };
}

const Framebuffer = struct {
    fd: c_int,
    mapped: []u8,
    width: usize,
    height: usize,
    stride: usize,
    xoffset: usize,
    yoffset: usize,
    bits_per_pixel: u32,
    red: fb.Bitfield,
    green: fb.Bitfield,
    blue: fb.Bitfield,
    transp: fb.Bitfield,

    fn open(path: []const u8) !Framebuffer {
        var path_buffer: [4096]u8 = undefined;
        const path_z = try std.mem.printSentinel(&path_buffer, "{s}", .{path}, 0);
        const file_descriptor = c.open(path_z.ptr, .{ .ACCMODE = .RDWR, .CLOEXEC = true });
        if (file_descriptor < 0) return error.OpenFramebufferFailed;
        errdefer _ = c.close(file_descriptor);

        var variable: fb.VarScreenInfo = undefined;
        var fixed: fb.FixScreenInfo = undefined;
        if (c.ioctl(file_descriptor, fb.GET_VSCREENINFO, &variable) != 0) return error.FramebufferInfoFailed;
        if (c.ioctl(file_descriptor, fb.GET_FSCREENINFO, &fixed) != 0) return error.FramebufferInfoFailed;
        std.log.info(
            "framebuffer {s}: visible={d}x{d}, virtual={d}x{d}, offset={d},{d}, bpp={d}, stride={d}",
            .{
                path,
                variable.xres,
                variable.yres,
                variable.xres_virtual,
                variable.yres_virtual,
                variable.xoffset,
                variable.yoffset,
                variable.bits_per_pixel,
                fixed.line_length,
            },
        );
        if (fixed.type != 0 or fixed.visual != 2 or variable.nonstd != 0 or variable.grayscale != 0 or
            (variable.bits_per_pixel != 16 and variable.bits_per_pixel != 24 and variable.bits_per_pixel != 32))
            return error.UnsupportedFramebufferFormat;
        inline for (.{ variable.red, variable.green, variable.blue, variable.transp }) |field| {
            if (field.length > 32 or field.offset > 32 or field.offset + field.length > variable.bits_per_pixel or field.msb_right != 0)
                return error.UnsupportedFramebufferFormat;
        }
        if (variable.xres < 320 or variable.yres < 240)
            return error.FramebufferTooSmall;

        const map_length = @as(usize, fixed.smem_len);
        if (map_length == 0) return error.InvalidFramebufferMemory;
        const address = c.mmap(null, map_length, .{ .READ = true, .WRITE = true }, .{ .TYPE = .SHARED }, file_descriptor, 0);
        if (address == c.MAP_FAILED) return error.MapFramebufferFailed;

        return .{
            .fd = file_descriptor,
            .mapped = @as([*]u8, @ptrCast(address))[0..map_length],
            .width = @intCast(variable.xres),
            .height = @intCast(variable.yres),
            .stride = @intCast(fixed.line_length),
            .xoffset = @intCast(variable.xoffset),
            .yoffset = @intCast(variable.yoffset),
            .bits_per_pixel = variable.bits_per_pixel,
            .red = variable.red,
            .green = variable.green,
            .blue = variable.blue,
            .transp = variable.transp,
        };
    }

    fn close(self: *Framebuffer) void {
        _ = c.munmap(@ptrCast(@alignCast(self.mapped.ptr)), self.mapped.len);
        _ = c.close(self.fd);
        self.* = undefined;
    }

    fn encodeChannel(value: u8, field: fb.Bitfield) u32 {
        if (field.length == 0) return 0;
        const max_value = (@as(u64, 1) << @intCast(field.length)) - 1;
        return @as(u32, @intCast((@as(u64, value) * max_value + 127) / 255)) << @intCast(field.offset);
    }

    fn canDirectCopy(self: *const Framebuffer, canvas: *const Canvas) bool {
        const row_bytes = canvas.width * @sizeOf(u32);
        const x_bytes = self.xoffset * @sizeOf(u32);
        const last_row = (self.yoffset + canvas.height - 1) * self.stride;

        return self.bits_per_pixel == 32 and
            canvas.width <= self.width and
            canvas.height <= self.height and
            x_bytes + row_bytes <= self.stride and
            last_row + x_bytes + row_bytes <= self.mapped.len and
            self.red.offset == 16 and self.red.length == 8 and
            self.green.offset == 8 and self.green.length == 8 and
            self.blue.offset == 0 and self.blue.length == 8 and
            (self.transp.length == 0 or
                (self.transp.offset == 24 and self.transp.length == 8));
    }

    fn present(self: *Framebuffer, canvas: *const Canvas) void {
        if (self.canDirectCopy(canvas)) {
            const source = std.mem.sliceAsBytes(canvas.pixels);
            const row_bytes = canvas.width * @sizeOf(u32);

            if (self.stride == row_bytes and
                self.xoffset == 0 and self.yoffset == 0)
            {
                @memcpy(self.mapped[0..source.len], source);
            } else {
                for (0..canvas.height) |y| {
                    const src_offset = y * row_bytes;
                    const dst_offset =
                        (y + self.yoffset) * self.stride +
                        self.xoffset * @sizeOf(u32);

                    @memcpy(
                        self.mapped[dst_offset..][0..row_bytes],
                        source[src_offset..][0..row_bytes],
                    );
                }
            }

            return;
        }

        const copy_width = @min(self.width, canvas.width);
        const copy_height = @min(self.height, canvas.height);
        const bytes_per_pixel: usize = @intCast(self.bits_per_pixel / 8);
        var y: usize = 0;
        while (y < copy_height) : (y += 1) {
            var x: usize = 0;
            while (x < copy_width) : (x += 1) {
                const color = fromArgb(canvas.pixels[y * canvas.width + x]);
                const native = encodeChannel(color[0], self.red) | encodeChannel(color[1], self.green) |
                    encodeChannel(color[2], self.blue) | encodeChannel(color[3], self.transp);
                const offset = (y + self.yoffset) * self.stride +
                    (x + self.xoffset) * bytes_per_pixel;
                if (offset + bytes_per_pixel > self.mapped.len) continue;
                self.mapped[offset] = @truncate(native);
                if (bytes_per_pixel > 1) self.mapped[offset + 1] = @truncate(native >> 8);
                if (bytes_per_pixel > 2) self.mapped[offset + 2] = @truncate(native >> 16);
                if (bytes_per_pixel > 3) self.mapped[offset + 3] = @truncate(native >> 24);
            }
        }
    }
};

const Terminal = struct {
    fd: c_int = 0,
    active: bool = false,
    saved: linux.termios = undefined,
    saved_flags: c_int = 0,

    fn enter(self: *Terminal) void {
        self.saved = std.mem.zeroes(linux.termios);
        if (linux.tcgetattr(self.fd, &self.saved) != 0) return;
        const flags = c.fcntl(self.fd, c.F.GETFL);
        if (flags < 0) return;
        self.saved_flags = flags;
        var raw = self.saved;
        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.cc[@backingInt(linux.V.MIN)] = 0;
        raw.cc[@backingInt(linux.V.TIME)] = 0;
        if (linux.tcsetattr(self.fd, .NOW, &raw) != 0) return;
        var nonblocking: c.O = @bitCast(self.saved_flags);
        nonblocking.NONBLOCK = true;
        if (c.fcntl(self.fd, c.F.SETFL, @as(c_int, @bitCast(nonblocking))) < 0) {
            _ = linux.tcsetattr(self.fd, .NOW, &self.saved);
            return;
        }
        self.active = true;
    }

    fn leave(self: *Terminal) void {
        if (!self.active) return;
        _ = linux.tcsetattr(self.fd, .NOW, &self.saved);
        _ = c.fcntl(self.fd, c.F.SETFL, self.saved_flags);
        self.active = false;
    }

    fn readKey(self: *Terminal) ?u8 {
        if (!self.active) return null;
        var byte: [1]u8 = undefined;
        return if (c.read(self.fd, &byte, 1) == 1) byte[0] else null;
    }
};

const Mouse = struct {
    fd: c_int = -1,
    position: Coord2 = @splat(0),
    delta: Coord2 = @splat(0),
    left: bool = false,
    right: bool = false,
    left_pressed: bool = false,
    left_released: bool = false,
    right_pressed: bool = false,
    right_released: bool = false,

    fn open(self: *Mouse, path: []const u8, width: usize, height: usize) void {
        var path_buffer: [4096]u8 = undefined;
        const path_z = std.mem.printSentinel(&path_buffer, "{s}", .{path}, 0) catch return;
        self.fd = c.open(path_z.ptr, .{ .ACCMODE = .RDONLY, .NONBLOCK = true, .CLOEXEC = true });
        if (self.fd < 0) {
            std.log.err("could not open mouse device: {s}", .{path});
            return;
        }
        self.position = .{ @intCast(width / 2), @intCast(height / 2) };
    }

    fn close(self: *Mouse) void {
        if (self.fd >= 0) _ = c.close(self.fd);
        self.fd = -1;
    }

    fn update(self: *Mouse, width: usize, height: usize) void {
        self.delta = @splat(0);
        self.left_pressed = false;
        self.left_released = false;
        self.right_pressed = false;
        self.right_released = false;
        if (self.fd < 0) return;

        var buffer: [192]u8 = undefined;
        while (true) {
            const received = c.read(self.fd, &buffer, buffer.len);
            if (received <= 0) break;
            var index: usize = 0;
            while (index + 2 < @as(usize, @intCast(received))) : (index += 3) {
                const flags = buffer[index];
                const new_left = (flags & 0x01) != 0;
                const new_right = (flags & 0x02) != 0;
                if (new_left and !self.left) self.left_pressed = true;
                if (!new_left and self.left) self.left_released = true;
                if (new_right and !self.right) self.right_pressed = true;
                if (!new_right and self.right) self.right_released = true;
                self.left = new_left;
                self.right = new_right;
                const packet_dx: i32 = @intCast(@as(i8, @bitCast(buffer[index + 1])));
                const packet_dy: i32 = -@as(i32, @intCast(@as(i8, @bitCast(buffer[index + 2]))));
                self.delta[0] += packet_dx;
                self.delta[1] += packet_dy;
                self.position[0] += packet_dx;
                self.position[1] += packet_dy;
                self.position[0] = std.math.clamp(self.position[0], 0, @as(i32, @intCast(width)) - 1);
                self.position[1] = std.math.clamp(self.position[1], 0, @as(i32, @intCast(height)) - 1);
            }
        }
    }
};

const max_scalars: usize = 64;
const max_series: usize = 16;
const max_points_2d: usize = 4096;
const max_texts_2d: usize = 256;
const max_points_3d: usize = 4096;
const max_cloud_points: usize = 65_536;
const max_path_vertices: usize = 32_768;
const max_mesh_vertices: usize = 65_536;
const max_mesh_indices: usize = 196_608;
const max_logs: usize = 128;
const series_capacity: usize = 512;
const max_image_pixels: usize = 8_388_608;
const max_normalized_2d: f32 = 16.0;
const max_primitive_size: f32 = 128.0;
const max_line_width: f32 = 64.0;

pub const ScalarValue = struct {
    name: Name,
    unit: Unit,
    value: f64,
    color: Color,
    updated_at: f64,
};

pub const Point2D = struct {
    id: u32,
    position: Pos2,
    size: f32 = 4,
    color: Color = palette.accent,
    label: Label = .{},
    updated_at: f64 = 0,
};

pub const Text2D = struct {
    id: u32,
    position: Pos2,
    text: Message,
    color: Color = palette.text,
    updated_at: f64 = 0,
};

pub const Point3D = struct {
    id: u32,
    position: Pos3,
    size: f32 = 3,
    color: Color = palette.accent,
    label: Label = .{},
    updated_at: f64 = 0,
};

pub const PointCloud = struct {
    points: []const Point3D,
};

pub const GeoPoint = struct {
    id: u32,
    latitude_deg: f64,
    longitude_deg: f64,
    altitude_meters: f64 = 0,
    heading_deg: f64 = 0,
    color: Color = palette.accent,
    label: Label = .{},
    updated_at: f64 = 0,
};

pub const Polyline2D = struct {
    id: u32,
    first_vertex: usize,
    vertex_count: usize,
    width: f32,
    color: Color,
};

pub const Polyline3D = struct {
    id: u32,
    first_vertex: usize,
    vertex_count: usize,
    width: f32,
    color: Color,
};

pub const GeoPath = struct {
    id: u32,
    first_vertex: usize,
    vertex_count: usize,
    width: f32,
    color: Color,
};

pub const MeshVertex = struct {
    position: Pos3,
    color: Color = palette.accent,
};

pub const Mesh = struct {
    id: u32,
    first_vertex: usize,
    vertex_count: usize,
    first_index: usize,
    index_count: usize,
    transform: Transform = .{},
    color: Color = palette.accent,
    wireframe: bool = false,
};

pub const LogLevel = enum {
    trace,
    info,
    warning,
    err,

    fn color(self: LogLevel) Color {
        return switch (self) {
            .trace => palette.muted,
            .info => palette.text,
            .warning => palette.warning,
            .err => palette.danger,
        };
    }

    fn label(self: LogLevel) []const u8 {
        return switch (self) {
            .trace => "TRACE",
            .info => "INFO",
            .warning => "WARN",
            .err => "ERROR",
        };
    }
};

pub const LogRecord = struct {
    level: LogLevel,
    message: Message,
    time_seconds: f64,
};

pub const Series = struct {
    name: Name,
    unit: Unit,
    color: Color,
    values: [series_capacity]f32 = undefined,
    times: [series_capacity]f64 = undefined,
    start: usize = 0,
    len: usize = 0,
    updated_at: f64 = 0,

    fn push(self: *Series, time_seconds: f64, value: f32) void {
        if (self.len < series_capacity) {
            const index = (self.start + self.len) % series_capacity;
            self.values[index] = value;
            self.times[index] = time_seconds;
            self.len += 1;
        } else {
            self.values[self.start] = value;
            self.times[self.start] = time_seconds;
            self.start = (self.start + 1) % series_capacity;
        }
        self.updated_at = time_seconds;
    }

    fn valueAt(self: *const Series, logical_index: usize) f32 {
        return self.values[(self.start + logical_index) % series_capacity];
    }

    fn timeAt(self: *const Series, logical_index: usize) f64 {
        return self.times[(self.start + logical_index) % series_capacity];
    }
};

pub const ImageFrame = struct {
    pixels: std.ArrayList(u32) = .empty,
    width: usize = 0,
    height: usize = 0,
    updated_at: f64 = 0,

    fn deinit(self: *ImageFrame, allocator: std.mem.Allocator) void {
        self.pixels.deinit(allocator);
        self.* = .{};
    }

    pub fn setArgb(
        self: *ImageFrame,
        allocator: std.mem.Allocator,
        width: usize,
        height: usize,
        pixels: []const u32,
        updated_at: f64,
    ) !void {
        if (width == 0 or height == 0) return error.InvalidImage;
        if (width > 4096 or height > 4096) return error.ImageTooLarge;
        const pixel_count = width * height;
        if (pixel_count > max_image_pixels) return error.ImageTooLarge;
        if (pixels.len < pixel_count) return error.InvalidImage;
        try self.pixels.resize(allocator, pixel_count);
        @memcpy(self.pixels.items, pixels[0..pixel_count]);
        self.width = width;
        self.height = height;
        self.updated_at = updated_at;
    }
};

pub const Scene = struct {
    allocator: std.mem.Allocator,
    scalars: std.ArrayList(ScalarValue) = .empty,
    series: std.ArrayList(Series) = .empty,
    points_2d: std.ArrayList(Point2D) = .empty,
    texts_2d: std.ArrayList(Text2D) = .empty,
    points_3d: std.ArrayList(Point3D) = .empty,
    cloud_points: std.ArrayList(Point3D) = .empty,
    polyline_2d_vertices: std.ArrayList(Pos2) = .empty,
    polylines_2d: std.ArrayList(Polyline2D) = .empty,
    polyline_3d_vertices: std.ArrayList(Pos3) = .empty,
    polylines_3d: std.ArrayList(Polyline3D) = .empty,
    geo_points: std.ArrayList(GeoPoint) = .empty,
    geo_path_vertices: std.ArrayList(GeoPoint) = .empty,
    geo_paths: std.ArrayList(GeoPath) = .empty,
    mesh_vertices: std.ArrayList(MeshVertex) = .empty,
    mesh_indices: std.ArrayList(u32) = .empty,
    meshes: std.ArrayList(Mesh) = .empty,
    logs: [max_logs]LogRecord = undefined,
    log_start: usize = 0,
    log_len: usize = 0,
    image: ImageFrame = .{},

    pub fn init(allocator: std.mem.Allocator) !Scene {
        var result = Scene{ .allocator = allocator };
        errdefer result.deinit();
        try result.scalars.ensureTotalCapacity(allocator, 16);
        try result.series.ensureTotalCapacity(allocator, 8);
        try result.points_2d.ensureTotalCapacity(allocator, 128);
        try result.texts_2d.ensureTotalCapacity(allocator, 32);
        try result.points_3d.ensureTotalCapacity(allocator, 128);
        try result.cloud_points.ensureTotalCapacity(allocator, 4096);
        try result.geo_points.ensureTotalCapacity(allocator, 64);
        try result.mesh_vertices.ensureTotalCapacity(allocator, 1024);
        try result.mesh_indices.ensureTotalCapacity(allocator, 3072);
        return result;
    }

    pub fn deinit(self: *Scene) void {
        self.image.deinit(self.allocator);
        self.meshes.deinit(self.allocator);
        self.mesh_indices.deinit(self.allocator);
        self.mesh_vertices.deinit(self.allocator);
        self.geo_paths.deinit(self.allocator);
        self.geo_path_vertices.deinit(self.allocator);
        self.geo_points.deinit(self.allocator);
        self.polylines_3d.deinit(self.allocator);
        self.polyline_3d_vertices.deinit(self.allocator);
        self.polylines_2d.deinit(self.allocator);
        self.polyline_2d_vertices.deinit(self.allocator);
        self.cloud_points.deinit(self.allocator);
        self.points_3d.deinit(self.allocator);
        self.texts_2d.deinit(self.allocator);
        self.points_2d.deinit(self.allocator);
        self.series.deinit(self.allocator);
        self.scalars.deinit(self.allocator);
        self.* = undefined;
    }

    pub fn upsertScalar(
        self: *Scene,
        name: []const u8,
        value: f64,
        unit: []const u8,
        color: Color,
        updated_at: f64,
    ) !void {
        if (!std.math.isFinite(value) or !std.math.isFinite(updated_at))
            return error.InvalidNumericValue;
        for (self.scalars.items) |*item| {
            if (item.name.eql(name)) {
                item.value = value;
                item.unit.set(unit);
                item.color = color;
                item.updated_at = updated_at;
                return;
            }
        }
        if (self.scalars.items.len >= max_scalars) return error.SceneLimit;
        try self.scalars.append(self.allocator, .{
            .name = Name.from(name),
            .unit = Unit.from(unit),
            .value = value,
            .color = color,
            .updated_at = updated_at,
        });
    }

    pub fn pushSeries(
        self: *Scene,
        name: []const u8,
        value: f32,
        unit: []const u8,
        color: Color,
        updated_at: f64,
    ) !void {
        if (!std.math.isFinite(value) or !std.math.isFinite(updated_at))
            return error.InvalidNumericValue;
        for (self.series.items) |*item| {
            if (item.name.eql(name)) {
                item.unit.set(unit);
                item.color = color;
                item.push(updated_at, value);
                return;
            }
        }
        if (self.series.items.len >= max_series) return error.SceneLimit;
        var item = Series{
            .name = Name.from(name),
            .unit = Unit.from(unit),
            .color = color,
        };
        item.push(updated_at, value);
        try self.series.append(self.allocator, item);
    }

    pub fn log(self: *Scene, level: LogLevel, text: []const u8, time_seconds: f64) void {
        const record = LogRecord{
            .level = level,
            .message = Message.from(text),
            .time_seconds = time_seconds,
        };
        if (self.log_len < max_logs) {
            self.logs[(self.log_start + self.log_len) % max_logs] = record;
            self.log_len += 1;
        } else {
            self.logs[self.log_start] = record;
            self.log_start = (self.log_start + 1) % max_logs;
        }
    }

    pub fn upsertPoint2D(self: *Scene, point: Point2D) !void {
        if (!finiteVector(point.position) or
            @abs(point.position[0]) > max_normalized_2d or
            @abs(point.position[1]) > max_normalized_2d or
            !std.math.isFinite(point.size) or
            !std.math.isFinite(point.updated_at) or
            point.size < 0 or point.size > max_primitive_size)
            return error.InvalidNumericValue;
        for (self.points_2d.items) |*item| {
            if (item.id == point.id) {
                item.* = point;
                return;
            }
        }
        if (self.points_2d.items.len >= max_points_2d) return error.SceneLimit;
        try self.points_2d.append(self.allocator, point);
    }

    pub fn upsertText2D(self: *Scene, item_value: Text2D) !void {
        if (!finiteVector(item_value.position) or
            @abs(item_value.position[0]) > max_normalized_2d or
            @abs(item_value.position[1]) > max_normalized_2d or
            !std.math.isFinite(item_value.updated_at))
            return error.InvalidNumericValue;
        for (self.texts_2d.items) |*item| {
            if (item.id == item_value.id) {
                item.* = item_value;
                return;
            }
        }
        if (self.texts_2d.items.len >= max_texts_2d) return error.SceneLimit;
        try self.texts_2d.append(self.allocator, item_value);
    }

    pub fn upsertPoint3D(self: *Scene, point: Point3D) !void {
        if (!finiteVector(point.position) or !std.math.isFinite(point.size) or
            !std.math.isFinite(point.updated_at) or
            point.size < 0 or point.size > max_primitive_size)
            return error.InvalidNumericValue;
        for (self.points_3d.items) |*item| {
            if (item.id == point.id) {
                item.* = point;
                return;
            }
        }
        if (self.points_3d.items.len >= max_points_3d) return error.SceneLimit;
        try self.points_3d.append(self.allocator, point);
    }

    pub fn upsertGeoPoint(self: *Scene, point: GeoPoint) !void {
        if (!std.math.isFinite(point.latitude_deg) or
            !std.math.isFinite(point.longitude_deg) or
            !std.math.isFinite(point.altitude_meters) or
            !std.math.isFinite(point.heading_deg) or
            !std.math.isFinite(point.updated_at) or
            point.latitude_deg < -90 or point.latitude_deg > 90)
            return error.InvalidNumericValue;
        for (self.geo_points.items) |*item| {
            if (item.id == point.id) {
                item.* = point;
                return;
            }
        }
        if (self.geo_points.items.len >= max_points_2d) return error.SceneLimit;
        try self.geo_points.append(self.allocator, point);
    }

    pub fn replacePointCloud(self: *Scene, cloud: PointCloud) !void {
        if (cloud.points.len > max_cloud_points) return error.SceneLimit;
        for (cloud.points) |point| {
            if (!finiteVector(point.position) or !std.math.isFinite(point.size) or
                !std.math.isFinite(point.updated_at) or
                point.size < 0 or point.size > max_primitive_size)
                return error.InvalidNumericValue;
        }
        self.cloud_points.clearRetainingCapacity();
        try self.cloud_points.appendSlice(self.allocator, cloud.points);
    }

    pub fn clearCloud(self: *Scene) void {
        self.cloud_points.clearRetainingCapacity();
    }

    pub fn appendCloudPoint(self: *Scene, point: Point3D) !void {
        if (!finiteVector(point.position) or !std.math.isFinite(point.size) or
            !std.math.isFinite(point.updated_at) or
            point.size < 0 or point.size > max_primitive_size)
            return error.InvalidNumericValue;
        if (self.cloud_points.items.len >= max_cloud_points) return error.SceneLimit;
        try self.cloud_points.append(self.allocator, point);
    }

    pub fn addPolyline2D(self: *Scene, id: u32, points: []const Pos2, width: f32, color: Color) !void {
        if (points.len < 2 or !std.math.isFinite(width) or
            width <= 0 or width > max_line_width) return error.InvalidPolyline;
        for (points) |point| {
            if (!finiteVector(point) or
                @abs(point[0]) > max_normalized_2d or
                @abs(point[1]) > max_normalized_2d)
                return error.InvalidNumericValue;
        }
        if (self.polyline_2d_vertices.items.len + points.len > max_path_vertices) return error.SceneLimit;
        const first = self.polyline_2d_vertices.items.len;
        try self.polyline_2d_vertices.appendSlice(self.allocator, points);
        try self.polylines_2d.append(self.allocator, .{
            .id = id,
            .first_vertex = first,
            .vertex_count = points.len,
            .width = width,
            .color = color,
        });
    }

    pub fn addPolyline3D(self: *Scene, id: u32, points: []const Pos3, width: f32, color: Color) !void {
        if (points.len < 2 or !std.math.isFinite(width) or
            width <= 0 or width > max_line_width) return error.InvalidPolyline;
        for (points) |point| if (!finiteVector(point)) return error.InvalidNumericValue;
        if (self.polyline_3d_vertices.items.len + points.len > max_path_vertices) return error.SceneLimit;
        const first = self.polyline_3d_vertices.items.len;
        try self.polyline_3d_vertices.appendSlice(self.allocator, points);
        try self.polylines_3d.append(self.allocator, .{
            .id = id,
            .first_vertex = first,
            .vertex_count = points.len,
            .width = width,
            .color = color,
        });
    }

    pub fn addGeoPath(self: *Scene, id: u32, points: []const GeoPoint, width: f32, color: Color) !void {
        if (points.len < 2 or !std.math.isFinite(width) or
            width <= 0 or width > max_line_width) return error.InvalidPolyline;
        for (points) |point| {
            if (!std.math.isFinite(point.latitude_deg) or
                !std.math.isFinite(point.longitude_deg) or
                !std.math.isFinite(point.altitude_meters) or
                point.latitude_deg < -90 or point.latitude_deg > 90)
                return error.InvalidNumericValue;
        }
        if (self.geo_path_vertices.items.len + points.len > max_path_vertices) return error.SceneLimit;
        const first = self.geo_path_vertices.items.len;
        try self.geo_path_vertices.appendSlice(self.allocator, points);
        try self.geo_paths.append(self.allocator, .{
            .id = id,
            .first_vertex = first,
            .vertex_count = points.len,
            .width = width,
            .color = color,
        });
    }

    pub fn addMesh(
        self: *Scene,
        id: u32,
        vertices: []const MeshVertex,
        indices: []const u32,
        transform: Transform,
        color: Color,
        wireframe: bool,
    ) !void {
        if (vertices.len == 0 or indices.len < 3 or indices.len % 3 != 0 or
            !finiteTransform(transform)) return error.InvalidMesh;
        for (vertices) |vertex| if (!finiteVector(vertex.position)) return error.InvalidNumericValue;
        if (self.mesh_vertices.items.len + vertices.len > max_mesh_vertices or
            self.mesh_indices.items.len + indices.len > max_mesh_indices) return error.SceneLimit;
        for (indices) |index| {
            const local_index: usize = @intCast(index);
            if (local_index >= vertices.len) return error.InvalidMesh;
        }
        const first_vertex = self.mesh_vertices.items.len;
        const first_index = self.mesh_indices.items.len;
        try self.mesh_vertices.appendSlice(self.allocator, vertices);
        for (indices) |index| {
            const local_index: usize = @intCast(index);
            try self.mesh_indices.append(self.allocator, @intCast(first_vertex + local_index));
        }
        try self.meshes.append(self.allocator, .{
            .id = id,
            .first_vertex = first_vertex,
            .vertex_count = vertices.len,
            .first_index = first_index,
            .index_count = indices.len,
            .transform = transform,
            .color = color,
            .wireframe = wireframe,
        });
    }

    pub fn clear(self: *Scene, target: []const u8) void {
        if (std.mem.eql(u8, target, "all")) {
            self.scalars.clearRetainingCapacity();
            self.series.clearRetainingCapacity();
            self.points_2d.clearRetainingCapacity();
            self.texts_2d.clearRetainingCapacity();
            self.points_3d.clearRetainingCapacity();
            self.cloud_points.clearRetainingCapacity();
            self.polyline_2d_vertices.clearRetainingCapacity();
            self.polylines_2d.clearRetainingCapacity();
            self.polyline_3d_vertices.clearRetainingCapacity();
            self.polylines_3d.clearRetainingCapacity();
            self.geo_points.clearRetainingCapacity();
            self.geo_path_vertices.clearRetainingCapacity();
            self.geo_paths.clearRetainingCapacity();
            self.mesh_vertices.clearRetainingCapacity();
            self.mesh_indices.clearRetainingCapacity();
            self.meshes.clearRetainingCapacity();
            self.log_start = 0;
            self.log_len = 0;
            self.image.width = 0;
            self.image.height = 0;
        } else if (std.mem.eql(u8, target, "p2")) {
            self.points_2d.clearRetainingCapacity();
            self.texts_2d.clearRetainingCapacity();
            self.polyline_2d_vertices.clearRetainingCapacity();
            self.polylines_2d.clearRetainingCapacity();
        } else if (std.mem.eql(u8, target, "p3")) {
            self.points_3d.clearRetainingCapacity();
            self.polyline_3d_vertices.clearRetainingCapacity();
            self.polylines_3d.clearRetainingCapacity();
            self.mesh_vertices.clearRetainingCapacity();
            self.mesh_indices.clearRetainingCapacity();
            self.meshes.clearRetainingCapacity();
        } else if (std.mem.eql(u8, target, "geo")) {
            self.geo_points.clearRetainingCapacity();
            self.geo_path_vertices.clearRetainingCapacity();
            self.geo_paths.clearRetainingCapacity();
        } else if (std.mem.eql(u8, target, "cloud")) {
            self.cloud_points.clearRetainingCapacity();
        } else if (std.mem.eql(u8, target, "series")) {
            self.series.clearRetainingCapacity();
            self.scalars.clearRetainingCapacity();
        } else if (std.mem.eql(u8, target, "logs")) {
            self.log_start = 0;
            self.log_len = 0;
        }
    }
};

pub const View = enum {
    overview,
    map,
    scene,
    plots,
    image,

    fn label(self: View) []const u8 {
        return switch (self) {
            .overview => "OVERVIEW",
            .map => "MAP",
            .scene => "3D SCENE",
            .plots => "PLOTS",
            .image => "IMAGE",
        };
    }
};

fn parseColor(text: []const u8) !Color {
    if (text.len != 6 and text.len != 8) return error.InvalidColor;
    const value = try std.fmt.parseInt(u32, text, 16);
    return if (text.len == 6)
        fromArgb(0xff00_0000 | value)
    else
        fromArgb(value);
}

fn parseLogLevel(text: []const u8) LogLevel {
    if (std.ascii.eqlIgnoreCase(text, "trace")) return .trace;
    if (std.ascii.eqlIgnoreCase(text, "warn") or std.ascii.eqlIgnoreCase(text, "warning")) return .warning;
    if (std.ascii.eqlIgnoreCase(text, "error") or std.ascii.eqlIgnoreCase(text, "err")) return .err;
    return .info;
}

fn parseView(text: []const u8) ?View {
    if (std.ascii.eqlIgnoreCase(text, "overview")) return .overview;
    if (std.ascii.eqlIgnoreCase(text, "map")) return .map;
    if (std.ascii.eqlIgnoreCase(text, "scene") or std.ascii.eqlIgnoreCase(text, "3d")) return .scene;
    if (std.ascii.eqlIgnoreCase(text, "plots") or std.ascii.eqlIgnoreCase(text, "plot")) return .plots;
    if (std.ascii.eqlIgnoreCase(text, "image") or std.ascii.eqlIgnoreCase(text, "video")) return .image;
    return null;
}

const UdpAdapter = struct {
    fd: c_int = -1,
    packets_received: u64 = 0,
    bytes_received: u64 = 0,
    commands_received: u64 = 0,
    parse_errors: u64 = 0,
    last_packet_at: f64 = 0,
    requested_view: ?View = null,

    fn open(port: u16) !UdpAdapter {
        const socket_fd = c.socket(c.AF.INET, c.SOCK.DGRAM | c.SOCK.NONBLOCK | c.SOCK.CLOEXEC, 0);
        if (socket_fd < 0) return error.OpenUdpFailed;
        errdefer _ = c.close(socket_fd);
        const local: c.sockaddr.in = .{ .port = std.mem.nativeToBig(u16, port), .addr = 0 };
        if (c.bind(socket_fd, @ptrCast(&local), @sizeOf(c.sockaddr.in)) != 0) return error.BindUdpFailed;
        return .{ .fd = socket_fd };
    }

    fn close(self: *UdpAdapter) void {
        if (self.fd >= 0) _ = c.close(self.fd);
        self.fd = -1;
    }

    fn nextToken(iterator: anytype) ![]const u8 {
        return iterator.next() orelse error.MissingField;
    }

    fn processLine(self: *UdpAdapter, scene: *Scene, line_input: []const u8, now: f64) !void {
        const line = std.mem.trim(u8, line_input, " \t\r");
        if (line.len == 0 or line[0] == '#') return;
        var tokens = std.mem.tokenizeAny(u8, line, " \t\r");
        const command = tokens.next() orelse return;

        if (std.mem.eql(u8, command, "scalar")) {
            const name = try nextToken(&tokens);
            const value = try parseFiniteFloat(f64, try nextToken(&tokens));
            const unit = try nextToken(&tokens);
            const color = try parseColor(try nextToken(&tokens));
            try scene.upsertScalar(name, value, unit, color, now);
        } else if (std.mem.eql(u8, command, "series")) {
            const name = try nextToken(&tokens);
            const value = try parseFiniteFloat(f32, try nextToken(&tokens));
            const unit = try nextToken(&tokens);
            const color = try parseColor(try nextToken(&tokens));
            try scene.pushSeries(name, value, unit, color, now);
        } else if (std.mem.eql(u8, command, "log") or std.mem.eql(u8, command, "text")) {
            const level = parseLogLevel(try nextToken(&tokens));
            const message = std.mem.trim(u8, tokens.rest(), " \t\r");
            scene.log(level, message, now);
        } else if (std.mem.eql(u8, command, "p2")) {
            const id = try std.fmt.parseInt(u32, try nextToken(&tokens), 10);
            const x = try parseFiniteFloat(f32, try nextToken(&tokens));
            const y = try parseFiniteFloat(f32, try nextToken(&tokens));
            const size = try parseFiniteFloat(f32, try nextToken(&tokens));
            const color = try parseColor(try nextToken(&tokens));
            const label = std.mem.trim(u8, tokens.rest(), " \t\r");
            try scene.upsertPoint2D(.{
                .id = id,
                .position = .{ x, y },
                .size = size,
                .color = color,
                .label = Label.from(label),
                .updated_at = now,
            });
        } else if (std.mem.eql(u8, command, "label2")) {
            const id = try std.fmt.parseInt(u32, try nextToken(&tokens), 10);
            const x = try parseFiniteFloat(f32, try nextToken(&tokens));
            const y = try parseFiniteFloat(f32, try nextToken(&tokens));
            const color = try parseColor(try nextToken(&tokens));
            const text = std.mem.trim(u8, tokens.rest(), " \t\r");
            try scene.upsertText2D(.{
                .id = id,
                .position = .{ x, y },
                .text = Message.from(text),
                .color = color,
                .updated_at = now,
            });
        } else if (std.mem.eql(u8, command, "p3")) {
            const id = try std.fmt.parseInt(u32, try nextToken(&tokens), 10);
            const x = try parseFiniteFloat(f32, try nextToken(&tokens));
            const y = try parseFiniteFloat(f32, try nextToken(&tokens));
            const z = try parseFiniteFloat(f32, try nextToken(&tokens));
            const size = try parseFiniteFloat(f32, try nextToken(&tokens));
            const color = try parseColor(try nextToken(&tokens));
            const label = std.mem.trim(u8, tokens.rest(), " \t\r");
            try scene.upsertPoint3D(.{
                .id = id,
                .position = .{ x, y, z },
                .size = size,
                .color = color,
                .label = Label.from(label),
                .updated_at = now,
            });
        } else if (std.mem.eql(u8, command, "geo")) {
            const id = try std.fmt.parseInt(u32, try nextToken(&tokens), 10);
            const latitude = try parseFiniteFloat(f64, try nextToken(&tokens));
            const longitude = try parseFiniteFloat(f64, try nextToken(&tokens));
            const altitude = try parseFiniteFloat(f64, try nextToken(&tokens));
            const heading = try parseFiniteFloat(f64, try nextToken(&tokens));
            const color = try parseColor(try nextToken(&tokens));
            const label = std.mem.trim(u8, tokens.rest(), " \t\r");
            try scene.upsertGeoPoint(.{
                .id = id,
                .latitude_deg = latitude,
                .longitude_deg = longitude,
                .altitude_meters = altitude,
                .heading_deg = heading,
                .color = color,
                .label = Label.from(label),
                .updated_at = now,
            });
        } else if (std.mem.eql(u8, command, "cloud_clear")) {
            scene.clearCloud();
        } else if (std.mem.eql(u8, command, "cloud")) {
            const x = try parseFiniteFloat(f32, try nextToken(&tokens));
            const y = try parseFiniteFloat(f32, try nextToken(&tokens));
            const z = try parseFiniteFloat(f32, try nextToken(&tokens));
            const size = try parseFiniteFloat(f32, try nextToken(&tokens));
            const color = try parseColor(try nextToken(&tokens));
            try scene.appendCloudPoint(.{
                .id = @intCast(scene.cloud_points.items.len),
                .position = .{ x, y, z },
                .size = size,
                .color = color,
                .updated_at = now,
            });
        } else if (std.mem.eql(u8, command, "clear")) {
            scene.clear(try nextToken(&tokens));
        } else if (std.mem.eql(u8, command, "view")) {
            self.requested_view = parseView(try nextToken(&tokens)) orelse return error.InvalidView;
        } else {
            return error.UnknownCommand;
        }
        self.commands_received += 1;
    }

    fn update(self: *UdpAdapter, scene: *Scene, now: f64) void {
        if (self.fd < 0) return;
        var buffer: [65_507]u8 = undefined;
        while (true) {
            const count = c.recvfrom(self.fd, &buffer, buffer.len, c.MSG.DONTWAIT, null, null);
            if (count <= 0) break;
            const bytes = buffer[0..@intCast(count)];
            self.packets_received += 1;
            self.bytes_received += @intCast(count);
            self.last_packet_at = now;
            var lines = std.mem.splitScalar(u8, bytes, '\n');
            while (lines.next()) |line| {
                self.processLine(scene, line, now) catch {
                    self.parse_errors += 1;
                };
            }
        }
    }
};

const DemoAdapter = struct {
    allocator: std.mem.Allocator,
    image_pixels: std.ArrayList(u32) = .empty,
    initialized: bool = false,
    last_series_at: f64 = -1,
    last_image_at: f64 = -1,
    last_log_second: i64 = -1,
    track: [256]GeoPoint = undefined,
    track_start: usize = 0,
    track_len: usize = 0,
    last_track_at: f64 = -1,

    fn init(allocator: std.mem.Allocator) DemoAdapter {
        return .{ .allocator = allocator };
    }

    fn deinit(self: *DemoAdapter) void {
        self.image_pixels.deinit(self.allocator);
        self.* = undefined;
    }

    fn appendTrack(self: *DemoAdapter, point: GeoPoint) void {
        if (self.track_len < self.track.len) {
            self.track[(self.track_start + self.track_len) % self.track.len] = point;
            self.track_len += 1;
        } else {
            self.track[self.track_start] = point;
            self.track_start = (self.track_start + 1) % self.track.len;
        }
    }

    fn rebuildGeoPath(self: *DemoAdapter, scene: *Scene) void {
        scene.geo_path_vertices.clearRetainingCapacity();
        scene.geo_paths.clearRetainingCapacity();
        if (self.track_len < 2) return;
        var temporary: [256]GeoPoint = undefined;
        var index: usize = 0;
        while (index < self.track_len) : (index += 1)
            temporary[index] = self.track[(self.track_start + index) % self.track.len];
        scene.addGeoPath(1, temporary[0..self.track_len], 2.0, palette.accent) catch {};
    }

    fn installMesh(scene: *Scene) void {
        const vertices = [_]MeshVertex{
            .{ .position = .{ -1, -1, -1 } },
            .{ .position = .{ 1, -1, -1 } },
            .{ .position = .{ 1, 1, -1 } },
            .{ .position = .{ -1, 1, -1 } },
            .{ .position = .{ -1, -1, 1 } },
            .{ .position = .{ 1, -1, 1 } },
            .{ .position = .{ 1, 1, 1 } },
            .{ .position = .{ -1, 1, 1 } },
        };
        const indices = [_]u32{
            0, 2, 1, 0, 3, 2,
            4, 5, 6, 4, 6, 7,
            0, 1, 5, 0, 5, 4,
            2, 3, 7, 2, 7, 6,
            1, 2, 6, 1, 6, 5,
            3, 0, 4, 3, 4, 7,
        };
        scene.addMesh(1, &vertices, &indices, .{
            .translation = .{ 0, 0, 0 },
            .rotation_deg = .{ 20, 30, 0 },
            .scale = .{ 1.2, 0.6, 1.2 },
        }, Color{ 94, 182, 255, 255 }, false) catch {};
    }

    fn setup(self: *DemoAdapter, scene: *Scene, now: f64) void {
        if (self.initialized) return;
        self.initialized = true;
        scene.log(.info, "demo adapter online; UDP adapter remains available on the configured port", now);
        scene.log(.trace, "generic primitives are independent of MAVLink, SDR, LiDAR, and video", now);
        scene.addPolyline2D(1, &.{
            .{ -1.0, -0.4 },
            .{ -0.5, 0.3 },
            .{ 0.1, -0.2 },
            .{ 0.8, 0.5 },
        }, 2.0, palette.warning) catch {};
        scene.addPolyline3D(1, &.{
            .{ -3, 0, -2 },
            .{ -1, 1, 0 },
            .{ 1, 0.5, 1 },
            .{ 3, 1.5, 2 },
        }, 2.0, palette.good) catch {};
        installMesh(scene);
    }

    fn updateImage(self: *DemoAdapter, scene: *Scene, now: f64) void {
        if (self.last_image_at >= 0 and now - self.last_image_at < 0.2) return;
        self.last_image_at = now;
        const width: usize = 160;
        const height: usize = 90;
        self.image_pixels.resize(self.allocator, width * height) catch return;
        var y: usize = 0;
        while (y < height) : (y += 1) {
            var x: usize = 0;
            while (x < width) : (x += 1) {
                const wave = @sin(@as(f64, @floatFromInt(x)) * 0.08 + now * 1.7) *
                    @cos(@as(f64, @floatFromInt(y)) * 0.11 - now * 0.9);
                const value: u8 = @intFromFloat(std.math.clamp((wave * 0.5 + 0.5) * 255.0, 0, 255));
                const r: u8 = @intCast((x * 255) / width);
                const g: u8 = value;
                const b: u8 = @intCast((y * 255) / height);
                const color: Color = Color{ r, g, b, 255 };
                self.image_pixels.items[y * width + x] = argb(color);
            }
        }
        scene.image.setArgb(self.allocator, width, height, self.image_pixels.items, now) catch {};
    }

    fn update(self: *DemoAdapter, scene: *Scene, now: f64) void {
        self.setup(scene, now);
        scene.upsertScalar("demo_time", now, "s", palette.accent, now) catch {};
        scene.upsertScalar("point_count", @as(f64, @floatFromInt(scene.cloud_points.items.len)), "pts", palette.good, now) catch {};
        scene.upsertScalar("synthetic_rf", -52.0 + @sin(now * 0.7) * 9.0, "dBm", palette.warning, now) catch {};

        if (self.last_series_at < 0 or now - self.last_series_at >= 0.05) {
            self.last_series_at = now;
            scene.pushSeries("rf_power", @floatCast(-55.0 + @sin(now * 1.4) * 12.0 + @sin(now * 7.0) * 2.0), "dBm", palette.warning, now) catch {};
            scene.pushSeries("latency", @floatCast(11.0 + @sin(now * 0.5) * 4.0 + @abs(@sin(now * 3.3)) * 3.0), "ms", palette.accent, now) catch {};
            scene.pushSeries("queue", @floatCast(28.0 + @sin(now * 0.25) * 18.0), "items", palette.good, now) catch {};
        }

        const latitude = 29.7604 + @sin(now * 0.035) * 0.055;
        const longitude = -95.3698 + @cos(now * 0.035) * 0.075;
        const heading = @mod(now * 18.0, 360.0);
        const vehicle = GeoPoint{
            .id = 1,
            .latitude_deg = latitude,
            .longitude_deg = longitude,
            .altitude_meters = 420.0 + @sin(now * 0.31) * 75.0,
            .heading_deg = heading,
            .color = palette.accent,
            .label = Label.from("DEMO TRACK"),
            .updated_at = now,
        };
        scene.upsertGeoPoint(vehicle) catch {};
        if (self.last_track_at < 0 or now - self.last_track_at >= 0.2) {
            self.last_track_at = now;
            self.appendTrack(vehicle);
            self.rebuildGeoPath(scene);
        }

        scene.upsertPoint2D(.{
            .id = 1,
            .position = .{ @floatCast(@sin(now * 0.8)), @floatCast(@cos(now * 1.1)) },
            .size = 6,
            .color = palette.accent,
            .label = Label.from("2D MARKER"),
            .updated_at = now,
        }) catch {};
        scene.upsertText2D(.{
            .id = 1,
            .position = .{ -0.92, 0.82 },
            .text = Message.from("ADAPTER OUTPUT -> GENERIC 2D PRIMITIVE"),
            .color = palette.muted,
            .updated_at = now,
        }) catch {};
        scene.upsertPoint3D(.{
            .id = 1,
            .position = .{ @floatCast(@sin(now) * 2.5), 1.5, @floatCast(@cos(now) * 2.5) },
            .size = 6,
            .color = palette.warning,
            .label = Label.from("TARGET"),
            .updated_at = now,
        }) catch {};

        scene.clearCloud();
        const count: usize = 900;
        var index: usize = 0;
        while (index < count) : (index += 1) {
            const fraction = @as(f64, @floatFromInt(index)) / @as(f64, @floatFromInt(count));
            const angle = fraction * pi * 18.0 + now * 0.22;
            const radius = 0.8 + fraction * 3.2;
            const vertical = (fraction - 0.5) * 4.0 + @sin(angle * 0.7) * 0.35;
            const intensity = @as(u8, @intFromFloat(std.math.clamp(fraction * 255.0, 0, 255)));
            scene.appendCloudPoint(.{
                .id = @intCast(index),
                .position = .{ @floatCast(@cos(angle) * radius), @floatCast(vertical), @floatCast(@sin(angle) * radius) },
                .size = 2,
                .color = .{ intensity, 210, 255 - intensity, 255 },
                .updated_at = now,
            }) catch break;
        }

        const second: i64 = @intFromFloat(@floor(now));
        if (second != self.last_log_second and @mod(second, 5) == 0) {
            self.last_log_second = second;
            var buffer: [128]u8 = undefined;
            const message = std.mem.print(&buffer, "demo tick {d}: scene remains adapter-independent", .{second}) catch "demo tick";
            scene.log(.info, message, now);
        }
        self.updateImage(scene, now);
    }
};

const GeoCoord = struct { latitude: f64, longitude: f64 };

const MapCamera = struct {
    center_latitude: f64 = 20.0,
    center_longitude: f64 = 0.0,
    zoom: f64 = 1.0,

    fn reset(self: *MapCamera) void {
        self.* = .{};
    }

    fn wrapLongitude(value: f64) f64 {
        return std.math.wrap(value, 180.0);
    }

    fn project(self: MapCamera, viewport: Rect, latitude: f64, longitude: f64) Coord2 {
        const delta_longitude = wrapLongitude(longitude - self.center_longitude);
        const world_width = @as(f64, @floatFromInt(viewport[1][0])) * self.zoom;
        const world_height = @as(f64, @floatFromInt(viewport[1][1])) * self.zoom;
        return .{ viewport[0][0] + @divTrunc(viewport[1][0], 2) + @as(i32, @intFromFloat(delta_longitude / 360.0 * world_width)), viewport[0][1] + @divTrunc(viewport[1][1], 2) - @as(i32, @intFromFloat((latitude - self.center_latitude) / 180.0 * world_height)) };
    }

    fn panPixels(self: *MapCamera, dx: i32, dy: i32, viewport: Rect) void {
        if (viewport[1][0] <= 0 or viewport[1][1] <= 0) return;
        self.center_longitude = wrapLongitude(self.center_longitude -
            @as(f64, @floatFromInt(dx)) * 360.0 /
                (@as(f64, @floatFromInt(viewport[1][0])) * self.zoom));
        self.center_latitude = std.math.clamp(self.center_latitude +
            @as(f64, @floatFromInt(dy)) * 180.0 /
                (@as(f64, @floatFromInt(viewport[1][1])) * self.zoom), -85.0, 85.0);
    }

    fn changeZoom(self: *MapCamera, factor: f64) void {
        self.zoom = std.math.clamp(self.zoom * factor, 0.75, 4096.0);
    }
};

const Camera3D = struct {
    target: Pos3 = @splat(0),
    yaw: f32 = 0.75,
    pitch: f32 = 0.35,
    distance: f32 = 12.0,
    fov_deg: f32 = 55.0,

    fn reset(self: *Camera3D) void {
        self.* = .{};
    }

    fn orbit(self: *Camera3D, dx: i32, dy: i32) void {
        self.yaw += @as(f32, @floatFromInt(dx)) * 0.008;
        self.pitch = std.math.clamp(self.pitch + @as(f32, @floatFromInt(dy)) * 0.008, -1.45, 1.45);
    }

    fn pan(self: *Camera3D, dx: i32, dy: i32) void {
        const scale_value = self.distance * 0.0015;
        const right = Pos3{ @cos(self.yaw), 0, -@sin(self.yaw) };
        const up = Pos3{ 0, 1, 0 };
        self.target += right * @as(Pos3, @splat(-@as(f32, @floatFromInt(dx)) * scale_value));
        self.target += up * @as(Pos3, @splat(@as(f32, @floatFromInt(dy)) * scale_value));
    }

    fn zoom(self: *Camera3D, factor: f32) void {
        self.distance = std.math.clamp(self.distance * factor, 0.1, 100_000.0);
    }

    fn position(self: Camera3D) Pos3 {
        const cp = @cos(self.pitch);
        return self.target + Pos3{
            @sin(self.yaw) * cp * self.distance,
            @sin(self.pitch) * self.distance,
            @cos(self.yaw) * cp * self.distance,
        };
    }

    fn project(self: Camera3D, viewport: Rect, world: Pos3) ?ScreenVertex {
        if (!finiteVector(world)) return null;
        const camera_position = self.position();
        const forward = normalize(self.target - camera_position);
        var right = normalize(cross(forward, .{ 0, 1, 0 }));
        if (length(right) < 0.001) right = .{ 1, 0, 0 };
        const up = normalize(cross(right, forward));
        const relative = world - camera_position;
        const depth_value = dot(relative, forward);
        if (!std.math.isFinite(depth_value) or depth_value <= 0.01) return null;
        const focal = @as(f32, @floatFromInt(viewport[1][1])) * 0.5 /
            @tan(self.fov_deg * @as(f32, @floatCast(rad_per_deg)) * 0.5);
        const screen_x = @as(f32, @floatFromInt(viewport[0][0] + @divTrunc(viewport[1][0], 2))) +
            dot(relative, right) / depth_value * focal;
        const screen_y = @as(f32, @floatFromInt(viewport[0][1] + @divTrunc(viewport[1][1], 2))) -
            dot(relative, up) / depth_value * focal;
        if (!std.math.isFinite(screen_x) or !std.math.isFinite(screen_y) or
            @abs(screen_x) > 1_000_000 or @abs(screen_y) > 1_000_000) return null;
        return .{ screen_x, screen_y, depth_value };
    }
};

fn rotateEuler(point: Pos3, rotation_deg: Pos3) Pos3 {
    const radians = std.math.degreesToRadians(rotation_deg);
    const cs = @cos(radians);
    const sn = @sin(radians);
    var p = point;
    p = .{ p[0], p[1] * cs[0] - p[2] * sn[0], p[1] * sn[0] + p[2] * cs[0] };
    p = .{ p[0] * cs[1] + p[2] * sn[1], p[1], -p[0] * sn[1] + p[2] * cs[1] };
    return .{ p[0] * cs[2] - p[1] * sn[2], p[0] * sn[2] + p[1] * cs[2], p[2] };
}

fn applyTransform(point: Pos3, transform: Transform) Pos3 {
    return rotateEuler(point * transform.scale, transform.rotation_deg) + transform.translation;
}

const north_america = [_]GeoCoord{
    .{ .latitude = 72, .longitude = -165 }, .{ .latitude = 70, .longitude = -130 },
    .{ .latitude = 58, .longitude = -115 }, .{ .latitude = 50, .longitude = -85 },
    .{ .latitude = 47, .longitude = -62 },  .{ .latitude = 28, .longitude = -78 },
    .{ .latitude = 15, .longitude = -93 },  .{ .latitude = 20, .longitude = -112 },
    .{ .latitude = 42, .longitude = -125 }, .{ .latitude = 58, .longitude = -145 },
};
const south_america = [_]GeoCoord{
    .{ .latitude = 13, .longitude = -81 },  .{ .latitude = 7, .longitude = -60 },
    .{ .latitude = -12, .longitude = -35 }, .{ .latitude = -35, .longitude = -52 },
    .{ .latitude = -56, .longitude = -68 }, .{ .latitude = -25, .longitude = -80 },
};
const europe_asia = [_]GeoCoord{
    .{ .latitude = 70, .longitude = -10 }, .{ .latitude = 72, .longitude = 45 },
    .{ .latitude = 68, .longitude = 135 }, .{ .latitude = 52, .longitude = 170 },
    .{ .latitude = 35, .longitude = 140 }, .{ .latitude = 10, .longitude = 105 },
    .{ .latitude = 8, .longitude = 75 },   .{ .latitude = 30, .longitude = 50 },
    .{ .latitude = 35, .longitude = 20 },  .{ .latitude = 45, .longitude = -8 },
};
const africa = [_]GeoCoord{
    .{ .latitude = 36, .longitude = -17 }, .{ .latitude = 32, .longitude = 33 },
    .{ .latitude = 10, .longitude = 52 },  .{ .latitude = -35, .longitude = 20 },
    .{ .latitude = -30, .longitude = 12 }, .{ .latitude = 5, .longitude = -17 },
};
const australia = [_]GeoCoord{
    .{ .latitude = -11, .longitude = 113 }, .{ .latitude = -10, .longitude = 153 },
    .{ .latitude = -39, .longitude = 147 }, .{ .latitude = -35, .longitude = 114 },
};
const greenland = [_]GeoCoord{
    .{ .latitude = 83, .longitude = -73 }, .{ .latitude = 81, .longitude = -12 },
    .{ .latitude = 60, .longitude = -42 }, .{ .latitude = 60, .longitude = -60 },
};

fn drawPanel(canvas: *Canvas, rect: Rect, title: []const u8) Rect {
    canvas.fillRect(rect, palette.panel);
    canvas.strokeRect(rect, palette.border);
    canvas.fillRect(.{ .{ rect[0][0], rect[0][1] }, .{ rect[1][0], 24 } }, palette.panel_alt);
    canvas.drawText(.{ rect[0][0] + 8, rect[0][1] + 8 }, title, 1, palette.accent);
    return .{ rect[0] + Coord2{ 6, 28 }, @max(@as(Coord2, @splat(0)), rect[1] - Coord2{ 12, 34 }) };
}

fn drawContinent(canvas: *Canvas, camera: MapCamera, viewport: Rect, coordinates: []const GeoCoord) void {
    var points: [64]Coord2 = undefined;
    if (coordinates.len > points.len) return;
    for (coordinates, 0..) |coordinate, index|
        points[index] = camera.project(viewport, coordinate.latitude, coordinate.longitude);
    var scratch: [64]i32 = undefined;
    canvas.fillPolygon(points[0..coordinates.len], palette.land, &scratch);
    var index: usize = 1;
    while (index < coordinates.len) : (index += 1)
        canvas.line(points[index - 1], points[index], palette.border, 1);
    canvas.line(points[coordinates.len - 1], points[0], palette.border, 1);
}

fn drawMap(canvas: *Canvas, scene: *const Scene, camera: MapCamera, outer: Rect) void {
    const viewport = drawPanel(canvas, outer, "GEOGRAPHIC CONTEXT");
    if (@reduce(.Or, viewport[1] <= @as(Coord2, @splat(0)))) return;
    canvas.setClip(viewport);
    canvas.fillRect(viewport, palette.ocean);
    drawContinent(canvas, camera, viewport, &north_america);
    drawContinent(canvas, camera, viewport, &south_america);
    drawContinent(canvas, camera, viewport, &europe_asia);
    drawContinent(canvas, camera, viewport, &africa);
    drawContinent(canvas, camera, viewport, &australia);
    drawContinent(canvas, camera, viewport, &greenland);

    var longitude: i32 = -180;
    while (longitude <= 180) : (longitude += 30) {
        const a = camera.project(viewport, -85, @floatFromInt(longitude));
        const b = camera.project(viewport, 85, @floatFromInt(longitude));
        canvas.line(a, b, palette.grid, 1);
    }
    var latitude: i32 = -60;
    while (latitude <= 60) : (latitude += 30) {
        var longitude_step: i32 = -180;
        var previous = camera.project(viewport, @floatFromInt(latitude), @floatFromInt(longitude_step));
        longitude_step += 10;
        while (longitude_step <= 180) : (longitude_step += 10) {
            const current = camera.project(viewport, @floatFromInt(latitude), @floatFromInt(longitude_step));
            if (@abs(current[0] - previous[0]) < viewport[1][0]) canvas.line(previous, current, palette.grid, 1);
            previous = current;
        }
    }

    for (scene.geo_paths.items) |path| {
        const vertices = scene.geo_path_vertices.items[path.first_vertex .. path.first_vertex + path.vertex_count];
        var index: usize = 1;
        var previous = camera.project(viewport, vertices[0].latitude_deg, vertices[0].longitude_deg);
        while (index < vertices.len) : (index += 1) {
            const current = camera.project(viewport, vertices[index].latitude_deg, vertices[index].longitude_deg);
            canvas.line(previous, current, path.color, @max(1, @as(i32, @intFromFloat(path.width))));
            previous = current;
        }
    }

    for (scene.geo_points.items) |item| {
        const center = camera.project(viewport, item.latitude_deg, item.longitude_deg);
        const heading = item.heading_deg * rad_per_deg;
        const forward = Coord2{ center[0] + @as(i32, @intFromFloat(@sin(heading) * 12.0)), center[1] - @as(i32, @intFromFloat(@cos(heading) * 12.0)) };
        const left = Coord2{ center[0] + @as(i32, @intFromFloat(@sin(heading - 2.35) * 8.0)), center[1] - @as(i32, @intFromFloat(@cos(heading - 2.35) * 8.0)) };
        const right = Coord2{ center[0] + @as(i32, @intFromFloat(@sin(heading + 2.35) * 8.0)), center[1] - @as(i32, @intFromFloat(@cos(heading + 2.35) * 8.0)) };
        canvas.fillTriangle(forward, left, right, item.color);
        canvas.circle(center, 14, palette.background);
        const label = item.label.slice();
        if (label.len > 0) canvas.drawText(.{ center[0] + 16, center[1] - 3 }, label, 1, palette.text);
    }
    canvas.resetClip();
}

fn draw2DScene(canvas: *Canvas, scene: *const Scene, outer: Rect) void {
    const viewport = drawPanel(canvas, outer, "GENERIC 2D");
    if (@reduce(.Or, viewport[1] <= @as(Coord2, @splat(0)))) return;
    canvas.setClip(viewport);
    canvas.fillRect(viewport, Color{ 10, 18, 27, 255 });
    const center = Coord2{ viewport[0][0] + @divTrunc(viewport[1][0], 2), viewport[0][1] + @divTrunc(viewport[1][1], 2) };
    canvas.line(.{ viewport[0][0], center[1] }, .{ viewport[0][0] + viewport[1][0], center[1] }, palette.grid, 1);
    canvas.line(.{ center[0], viewport[0][1] }, .{ center[0], viewport[0][1] + viewport[1][1] }, palette.grid, 1);

    for (scene.polylines_2d.items) |path| {
        const vertices = scene.polyline_2d_vertices.items[path.first_vertex .. path.first_vertex + path.vertex_count];
        var index: usize = 1;
        var previous = Coord2{ center[0] + @as(i32, @intFromFloat(vertices[0][0] * @as(f32, @floatFromInt(viewport[1][0])) * 0.42)), center[1] - @as(i32, @intFromFloat(vertices[0][1] * @as(f32, @floatFromInt(viewport[1][1])) * 0.42)) };
        while (index < vertices.len) : (index += 1) {
            const current = Coord2{ center[0] + @as(i32, @intFromFloat(vertices[index][0] * @as(f32, @floatFromInt(viewport[1][0])) * 0.42)), center[1] - @as(i32, @intFromFloat(vertices[index][1] * @as(f32, @floatFromInt(viewport[1][1])) * 0.42)) };
            canvas.line(previous, current, path.color, @max(1, @as(i32, @intFromFloat(path.width))));
            previous = current;
        }
    }

    for (scene.points_2d.items) |item| {
        const point = Coord2{ center[0] + @as(i32, @intFromFloat(item.position[0] * @as(f32, @floatFromInt(viewport[1][0])) * 0.42)), center[1] - @as(i32, @intFromFloat(item.position[1] * @as(f32, @floatFromInt(viewport[1][1])) * 0.42)) };
        canvas.fillCircle(point, @max(2, @as(i32, @intFromFloat(item.size))), item.color);
        if (item.label.len > 0) canvas.drawText(.{ point[0] + 8, point[1] - 3 }, item.label.slice(), 1, palette.text);
    }
    for (scene.texts_2d.items) |item| {
        const point = Coord2{ center[0] + @as(i32, @intFromFloat(item.position[0] * @as(f32, @floatFromInt(viewport[1][0])) * 0.42)), center[1] - @as(i32, @intFromFloat(item.position[1] * @as(f32, @floatFromInt(viewport[1][1])) * 0.42)) };
        canvas.drawText(point, item.text.slice(), 1, item.color);
    }
    canvas.resetClip();
}

fn drawGrid3D(canvas: *Canvas, camera: Camera3D, viewport: Rect) void {
    var index: i32 = -10;
    while (index <= 10) : (index += 1) {
        const color = if (index == 0) palette.border else Color{ 43, 57, 68, 255 };
        const a = camera.project(viewport, .{ @floatFromInt(index), 0, -10 });
        const b = camera.project(viewport, .{ @floatFromInt(index), 0, 10 });
        if (a != null and b != null) canvas.depthLine(a.?, b.?, color, 1);
        const d = camera.project(viewport, .{ -10, 0, @floatFromInt(index) });
        const e = camera.project(viewport, .{ 10, 0, @floatFromInt(index) });
        if (d != null and e != null) canvas.depthLine(d.?, e.?, color, 1);
    }
    const origin = camera.project(viewport, @splat(0));
    const x_axis = camera.project(viewport, .{ 3, 0, 0 });
    const y_axis = camera.project(viewport, .{ 0, 3, 0 });
    const z_axis = camera.project(viewport, .{ 0, 0, 3 });
    if (origin != null and x_axis != null) canvas.depthLine(origin.?, x_axis.?, palette.axis_x, 3);
    if (origin != null and y_axis != null) canvas.depthLine(origin.?, y_axis.?, palette.axis_y, 3);
    if (origin != null and z_axis != null) canvas.depthLine(origin.?, z_axis.?, palette.axis_z, 3);
}

fn drawScene3D(canvas: *Canvas, scene: *const Scene, camera: Camera3D, outer: Rect) void {
    const viewport = drawPanel(canvas, outer, "GENERIC 3D / POINT CLOUD");
    if (@reduce(.Or, viewport[1] <= @as(Coord2, @splat(0)))) return;
    canvas.setClip(viewport);
    canvas.fillRect(viewport, Color{ 7, 12, 18, 255 });
    canvas.clearDepth();
    drawGrid3D(canvas, camera, viewport);

    const light = normalize(.{ 0.4, 1.0, 0.25 });
    for (scene.meshes.items) |mesh| {
        var index: usize = 0;
        while (index + 2 < mesh.index_count) : (index += 3) {
            const ia: usize = @intCast(scene.mesh_indices.items[mesh.first_index + index]);
            const ib: usize = @intCast(scene.mesh_indices.items[mesh.first_index + index + 1]);
            const ic: usize = @intCast(scene.mesh_indices.items[mesh.first_index + index + 2]);
            const wa = applyTransform(scene.mesh_vertices.items[ia].position, mesh.transform);
            const wb = applyTransform(scene.mesh_vertices.items[ib].position, mesh.transform);
            const wc = applyTransform(scene.mesh_vertices.items[ic].position, mesh.transform);
            const pa = camera.project(viewport, wa) orelse continue;
            const pb = camera.project(viewport, wb) orelse continue;
            const pc = camera.project(viewport, wc) orelse continue;
            if (mesh.wireframe) {
                canvas.depthLine(pa, pb, mesh.color, 1);
                canvas.depthLine(pb, pc, mesh.color, 1);
                canvas.depthLine(pc, pa, mesh.color, 1);
            } else {
                const normal = normalize(cross(wb - wa, wc - wa));
                const intensity = 0.25 + @abs(dot(normal, light)) * 0.75;
                canvas.depthTriangle(pa, pb, pc, shade(mesh.color, intensity));
            }
        }
    }

    for (scene.polylines_3d.items) |path| {
        const vertices = scene.polyline_3d_vertices.items[path.first_vertex .. path.first_vertex + path.vertex_count];
        var index: usize = 1;
        var previous = camera.project(viewport, vertices[0]);
        while (index < vertices.len) : (index += 1) {
            const current = camera.project(viewport, vertices[index]);
            if (previous != null and current != null)
                canvas.depthLine(previous.?, current.?, path.color, @max(1, @as(i32, @intFromFloat(path.width))));
            previous = current;
        }
    }

    for (scene.cloud_points.items) |item| {
        const projected = camera.project(viewport, item.position) orelse continue;
        const radius = std.math.clamp(@as(i32, @intFromFloat(item.size)), 1, 6);
        canvas.depthCircle(.{ @intFromFloat(projected[0]), @intFromFloat(projected[1]) }, radius, projected[2], item.color);
    }
    for (scene.points_3d.items) |item| {
        const projected = camera.project(viewport, item.position) orelse continue;
        const radius = std.math.clamp(@as(i32, @intFromFloat(item.size)), 2, 16);
        const point = Coord2{ @intFromFloat(projected[0]), @intFromFloat(projected[1]) };
        canvas.depthCircle(point, radius, projected[2], item.color);
        if (item.label.len > 0) canvas.drawText(.{ point[0] + radius + 4, point[1] - 3 }, item.label.slice(), 1, palette.text);
    }
    canvas.resetClip();
}

fn drawScalars(canvas: *Canvas, scene: *const Scene, outer: Rect) void {
    const viewport = drawPanel(canvas, outer, "SCALARS");
    if (@reduce(.Or, viewport[1] <= @as(Coord2, @splat(0)))) return;
    var y = viewport[0][1] + 2;
    var buffer: [128]u8 = undefined;
    for (scene.scalars.items[0..@min(scene.scalars.items.len, 12)]) |item| {
        const text = std.mem.print(&buffer, "{s}: {d:.3} {s}", .{ item.name.slice(), item.value, item.unit.slice() }) catch continue;
        canvas.drawText(.{ viewport[0][0] + 4, y }, text, 1, item.color);
        y += 16;
        if (y + 8 >= viewport[0][1] + viewport[1][1]) break;
    }
    if (scene.scalars.items.len == 0)
        canvas.drawText(.{ viewport[0][0] + 4, y }, "NO SCALARS", 1, palette.muted);
}

fn drawPlots(canvas: *Canvas, scene: *const Scene, outer: Rect) void {
    const viewport = drawPanel(canvas, outer, "TIME SERIES");
    if (@reduce(.Or, viewport[1] <= @as(Coord2, @splat(0)))) return;
    canvas.setClip(viewport);
    canvas.fillRect(viewport, Color{ 9, 15, 22, 255 });
    var line_index: usize = 0;
    while (line_index <= 4) : (line_index += 1) {
        const y = viewport[0][1] + @as(i32, @intCast((@as(usize, @intCast(viewport[1][1])) * line_index) / 4));
        canvas.line(.{ viewport[0][0], y }, .{ viewport[0][0] + viewport[1][0], y }, palette.grid, 1);
    }

    const visible_series = @min(scene.series.items.len, 4);
    var series_index: usize = 0;
    while (series_index < visible_series) : (series_index += 1) {
        const item = &scene.series.items[series_index];
        if (item.len < 2) continue;
        var minimum = item.valueAt(0);
        var maximum = minimum;
        var index: usize = 1;
        while (index < item.len) : (index += 1) {
            minimum = @min(minimum, item.valueAt(index));
            maximum = @max(maximum, item.valueAt(index));
        }
        if (@abs(maximum - minimum) < 0.00001) {
            minimum -= 1;
            maximum += 1;
        }
        var previous: ?Coord2 = null;
        index = 0;
        while (index < item.len) : (index += 1) {
            const x = viewport[0][0] + @as(i32, @intCast((@as(usize, @intCast(@max(1, viewport[1][0] - 1))) * index) / @max(@as(usize, 1), item.len - 1)));
            const normalized = (item.valueAt(index) - minimum) / (maximum - minimum);
            const y = viewport[0][1] + viewport[1][1] - 1 - @as(i32, @intFromFloat(normalized * @as(f32, @floatFromInt(@max(1, viewport[1][1] - 1)))));
            const current = Coord2{ x, y };
            if (previous) |last| canvas.line(last, current, item.color, 2);
            previous = current;
        }
        var label_buffer: [96]u8 = undefined;
        const label = std.mem.print(&label_buffer, "{s} {d:.2}{s}", .{ item.name.slice(), item.valueAt(item.len - 1), item.unit.slice() }) catch "SERIES";
        canvas.drawText(.{ viewport[0][0] + 6, viewport[0][1] + 5 + @as(i32, @intCast(series_index)) * 14 }, label, 1, item.color);
    }
    if (visible_series == 0)
        canvas.drawText(.{ viewport[0][0] + 6, viewport[0][1] + 6 }, "NO SERIES", 1, palette.muted);
    canvas.resetClip();
}

fn drawImage(canvas: *Canvas, scene: *const Scene, outer: Rect) void {
    const viewport = drawPanel(canvas, outer, "IMAGE FRAME");
    if (@reduce(.Or, viewport[1] <= @as(Coord2, @splat(0)))) return;
    canvas.fillRect(viewport, Color{ 5, 8, 12, 255 });
    if (scene.image.width == 0 or scene.image.height == 0) {
        canvas.drawText(.{ viewport[0][0] + 8, viewport[0][1] + 8 }, "NO IMAGE FRAME", 1, palette.muted);
        return;
    }
    const source_aspect = @as(f64, @floatFromInt(scene.image.width)) / @as(f64, @floatFromInt(scene.image.height));
    const destination_aspect = @as(f64, @floatFromInt(@max(1, viewport[1][0]))) / @as(f64, @floatFromInt(@max(1, viewport[1][1])));
    var destination = viewport;
    if (source_aspect > destination_aspect) {
        destination[1][1] = @intFromFloat(@as(f64, @floatFromInt(viewport[1][0])) / source_aspect);
        destination[0][1] += @divTrunc(viewport[1][1] - destination[1][1], 2);
    } else {
        destination[1][0] = @intFromFloat(@as(f64, @floatFromInt(viewport[1][1])) * source_aspect);
        destination[0][0] += @divTrunc(viewport[1][0] - destination[1][0], 2);
    }
    canvas.drawImageNearest(destination, scene.image.width, scene.image.height, scene.image.pixels.items);
    canvas.strokeRect(destination, palette.border);
}

fn drawLogs(canvas: *Canvas, scene: *const Scene, outer: Rect) void {
    const viewport = drawPanel(canvas, outer, "LOG / DIAGNOSTICS");
    if (@reduce(.Or, viewport[1] <= @as(Coord2, @splat(0)))) return;
    const rows: usize = @intCast(@max(1, @divTrunc(viewport[1][1], 15)));
    const count = @min(scene.log_len, rows);
    var row: usize = 0;
    var buffer: [256]u8 = undefined;
    while (row < count) : (row += 1) {
        const logical = scene.log_len - count + row;
        const record = scene.logs[(scene.log_start + logical) % max_logs];
        const text = std.mem.print(&buffer, "[{d:.2}] {s}: {s}", .{ record.time_seconds, record.level.label(), record.message.slice() }) catch continue;
        canvas.drawText(.{ viewport[0][0] + 4, viewport[0][1] + @as(i32, @intCast(row)) * 15 }, text[0..@min(text.len, 120)], 1, record.level.color());
    }
    if (count == 0) canvas.drawText(.{ viewport[0][0] + 4, viewport[0][1] }, "NO LOG MESSAGES", 1, palette.muted);
}

const Layout = struct {
    top: Rect,
    content: Rect,
    logs: Rect,
    map: Rect,
    scene: Rect,
    two_d: Rect,
    scalars: Rect,
    plots: Rect,
    image: Rect,
};

fn buildLayout(width: usize, height: usize, view: View) Layout {
    const screen_w: i32 = @intCast(width);
    const screen_h: i32 = @intCast(height);
    const top_height: i32 = 34;
    const log_height: i32 = std.math.clamp(@divTrunc(screen_h, 5), 96, 170);
    const top = Rect{ .{ 0, 0 }, .{ screen_w, top_height } };
    const logs = Rect{ .{ 6, screen_h - log_height - 6 }, .{ screen_w - 12, log_height } };
    const content = Rect{ .{ 6, top_height + 6 }, .{ screen_w - 12, logs[0][1] - top_height - 12 } };
    const gap: i32 = 6;

    if (view == .overview) {
        const desired_right = std.math.clamp(@divTrunc(content[1][0], 3), 180, 420);
        const right_width = @min(desired_right, @max(120, @divTrunc(content[1][0] - gap, 2)));
        const left_width = content[1][0] - right_width - gap;
        const left_half = @divTrunc(content[1][1] - gap, 2);
        const right_third = @divTrunc(content[1][1] - gap * 2, 3);
        return .{
            .top = top,
            .content = content,
            .logs = logs,
            .map = .{ .{ content[0][0], content[0][1] }, .{ left_width, left_half } },
            .scene = .{ .{ content[0][0], content[0][1] + left_half + gap }, .{ left_width, content[1][1] - left_half - gap } },
            .scalars = .{ .{ content[0][0] + left_width + gap, content[0][1] }, .{ right_width, right_third } },
            .plots = .{ .{ content[0][0] + left_width + gap, content[0][1] + right_third + gap }, .{ right_width, right_third } },
            .two_d = .{ .{ content[0][0] + left_width + gap, content[0][1] + (right_third + gap) * 2 }, .{ right_width, content[1][1] - (right_third + gap) * 2 } },
            .image = .{ .{ 0, 0 }, .{ 0, 0 } },
        };
    }

    if (view == .plots) {
        return .{
            .top = top,
            .content = content,
            .logs = logs,
            .map = .{ .{ 0, 0 }, .{ 0, 0 } },
            .scene = .{ .{ 0, 0 }, .{ 0, 0 } },
            .two_d = .{ .{ 0, 0 }, .{ 0, 0 } },
            .scalars = .{ .{ 0, 0 }, .{ 0, 0 } },
            .plots = content,
            .image = .{ .{ 0, 0 }, .{ 0, 0 } },
        };
    }

    if (view == .image) {
        return .{
            .top = top,
            .content = content,
            .logs = logs,
            .map = .{ .{ 0, 0 }, .{ 0, 0 } },
            .scene = .{ .{ 0, 0 }, .{ 0, 0 } },
            .two_d = .{ .{ 0, 0 }, .{ 0, 0 } },
            .scalars = .{ .{ 0, 0 }, .{ 0, 0 } },
            .plots = .{ .{ 0, 0 }, .{ 0, 0 } },
            .image = content,
        };
    }

    const desired_side = std.math.clamp(@divTrunc(content[1][0], 4), 180, 380);
    const side_width = @min(desired_side, @max(120, @divTrunc(content[1][0] - gap, 2)));
    const primary = Rect{ .{ content[0][0], content[0][1] }, .{ content[1][0] - side_width - gap, content[1][1] } };
    const side_x = primary[0][0] + primary[1][0] + gap;
    const side_half = @divTrunc(content[1][1] - gap, 2);
    return .{
        .top = top,
        .content = content,
        .logs = logs,
        .map = if (view == .map) primary else .{ .{ 0, 0 }, .{ 0, 0 } },
        .scene = if (view == .scene) primary else .{ .{ 0, 0 }, .{ 0, 0 } },
        .two_d = .{ .{ 0, 0 }, .{ 0, 0 } },
        .scalars = .{ .{ side_x, content[0][1] }, .{ side_width, side_half } },
        .plots = .{ .{ side_x, content[0][1] + side_half + gap }, .{ side_width, content[1][1] - side_half - gap } },
        .image = .{ .{ 0, 0 }, .{ 0, 0 } },
    };
}

const App = struct {
    running: bool = true,
    view: View = .overview,
    map_camera: MapCamera = .{},
    camera_3d: Camera3D = .{},
    fps_smoothed: f64 = 0,
    frame_ms: f64 = 0,
    frame_index: u64 = 0,

    fn reset(self: *App) void {
        self.map_camera.reset();
        self.camera_3d.reset();
    }

    fn keyboard(self: *App, key: u8) void {
        switch (key) {
            27, 'q', 'Q' => self.running = false,
            '1' => self.view = .overview,
            '2' => self.view = .map,
            '3' => self.view = .scene,
            '4' => self.view = .plots,
            '5' => self.view = .image,
            'r', 'R' => self.reset(),
            '+', '=' => switch (self.view) {
                .map => self.map_camera.changeZoom(1.25),
                .scene => self.camera_3d.zoom(0.8),
                else => {},
            },
            '-', '_' => switch (self.view) {
                .map => self.map_camera.changeZoom(0.8),
                .scene => self.camera_3d.zoom(1.25),
                else => {},
            },
            'w', 'W' => switch (self.view) {
                .map => self.map_camera.center_latitude = std.math.clamp(self.map_camera.center_latitude + 4.0 / self.map_camera.zoom, -85, 85),
                .scene => self.camera_3d.target[1] += self.camera_3d.distance * 0.03,
                else => {},
            },
            's', 'S' => switch (self.view) {
                .map => self.map_camera.center_latitude = std.math.clamp(self.map_camera.center_latitude - 4.0 / self.map_camera.zoom, -85, 85),
                .scene => self.camera_3d.target[1] -= self.camera_3d.distance * 0.03,
                else => {},
            },
            'a', 'A' => switch (self.view) {
                .map => self.map_camera.center_longitude = MapCamera.wrapLongitude(self.map_camera.center_longitude - 6.0 / self.map_camera.zoom),
                .scene => self.camera_3d.yaw -= 0.08,
                else => {},
            },
            'd', 'D' => switch (self.view) {
                .map => self.map_camera.center_longitude = MapCamera.wrapLongitude(self.map_camera.center_longitude + 6.0 / self.map_camera.zoom),
                .scene => self.camera_3d.yaw += 0.08,
                else => {},
            },
            else => {},
        }
    }

    fn mouseInput(self: *App, mouse: *const Mouse, layout: Layout) void {
        const cursor = mouse.position;
        var active_view = self.view;
        if (self.view == .overview) {
            if (contains(layout.map, cursor)) active_view = .map else if (contains(layout.scene, cursor)) active_view = .scene;
        }
        if (mouse.left) {
            switch (active_view) {
                .map => self.map_camera.panPixels(mouse.delta[0], mouse.delta[1], inset(layout.map, 6)),
                .scene => self.camera_3d.orbit(mouse.delta[0], mouse.delta[1]),
                else => {},
            }
        }
        if (mouse.right and active_view == .scene) self.camera_3d.pan(mouse.delta[0], mouse.delta[1]);
    }

    fn updateTiming(self: *App, dt: f64) void {
        const fps = if (dt > 0) 1.0 / dt else 0;
        self.fps_smoothed = if (self.fps_smoothed == 0) fps else self.fps_smoothed * 0.92 + fps * 0.08;
        self.frame_ms = dt * 1000.0;
        self.frame_index +%= 1;
    }

    fn drawStatus(self: *App, canvas: *Canvas, scene: *const Scene, udp: *const UdpAdapter, rect: Rect) void {
        canvas.fillRect(rect, palette.panel);
        canvas.fillRect(.{ .{ 0, rect[0][1] + rect[1][1] - 1 }, .{ rect[1][0], 1 } }, palette.border);
        canvas.drawText(.{ 10, 10 }, "3DBG", 2, palette.accent);
        var buffer: [256]u8 = undefined;
        const summary = std.mem.print(&buffer, "{s}  {d:.1} FPS  {d:.2} MS  UDP {d} PKT/{d} ERR  P2 {d} P3 {d}+{d} GEO {d}", .{
            self.view.label(),         self.fps_smoothed,            self.frame_ms,
            udp.packets_received,      udp.parse_errors,             scene.points_2d.items.len,
            scene.points_3d.items.len, scene.cloud_points.items.len, scene.geo_points.items.len,
        }) catch "STATUS";
        canvas.drawText(.{ 135, 13 }, summary, 1, palette.text);
        if (rect[1][0] >= 1100) {
            const help = "1 OVERVIEW  2 MAP  3 3D  4 PLOTS  5 IMAGE  +/- ZOOM  WASD  R RESET  Q QUIT";
            const help_x = @max(10, rect[1][0] - canvas.textWidth(help, 1) - 10);
            canvas.drawText(.{ help_x, 13 }, help, 1, palette.muted);
        }
    }

    fn render(self: *App, canvas: *Canvas, scene: *const Scene, udp: *const UdpAdapter, mouse: Coord2) void {
        const layout = buildLayout(canvas.width, canvas.height, self.view);
        canvas.clear(palette.background);
        self.drawStatus(canvas, scene, udp, layout.top);
        switch (self.view) {
            .overview => {
                drawMap(canvas, scene, self.map_camera, layout.map);
                drawScene3D(canvas, scene, self.camera_3d, layout.scene);
                drawScalars(canvas, scene, layout.scalars);
                drawPlots(canvas, scene, layout.plots);
                draw2DScene(canvas, scene, layout.two_d);
            },
            .map => {
                drawMap(canvas, scene, self.map_camera, layout.map);
                drawScalars(canvas, scene, layout.scalars);
                drawPlots(canvas, scene, layout.plots);
            },
            .scene => {
                drawScene3D(canvas, scene, self.camera_3d, layout.scene);
                drawScalars(canvas, scene, layout.scalars);
                drawPlots(canvas, scene, layout.plots);
            },
            .plots => drawPlots(canvas, scene, layout.plots),
            .image => drawImage(canvas, scene, layout.image),
        }
        drawLogs(canvas, scene, layout.logs);
        canvas.line(.{ mouse[0] - 6, mouse[1] }, .{ mouse[0] + 6, mouse[1] }, palette.text, 1);
        canvas.line(.{ mouse[0], mouse[1] - 6 }, .{ mouse[0], mouse[1] + 6 }, palette.text, 1);
    }
};

const Config = struct {
    framebuffer_path: ?[]const u8 = "/dev/fb0",
    mouse_path: ?[]const u8 = null,
    ppm_path: ?[]const u8 = null,
    width: usize = 1280,
    height: usize = 720,
    udp_port: u16 = 7777,
    fps: f64 = 30.0,
    frames: usize = 0,
    demo: bool = true,
    size_explicit: bool = false,
};

fn printUsage(program_name: []const u8) void {
    std.debug.print(
        \\Usage: {s} [options]
        \\
        \\  --fb PATH        Linux framebuffer, default /dev/fb0
        \\  --mouse PATH     Optional mousedev path, e.g. /dev/input/mice
        \\  --udp PORT       Generic text-adapter UDP port, default 7777
        \\  --fps N          Frame limit, default 30
        \\  --no-demo        Disable the built-in synthetic adapter
        \\  --ppm PATH       Headless mode; write final frame as PPM
        \\  --size WxH       Headless canvas size, default 1280x720
        \\  --frames N       Headless frames, default 1 when --ppm is used
        \\  -h, --help       Show this message
        \\
        \\Keyboard: 1-5 views, +/- zoom, WASD navigation, R reset, Q quit.
        \\
    , .{program_name});
}

fn requireValue(args: []const [:0]const u8, index: *usize, option: []const u8) ![]const u8 {
    index.* += 1;
    if (index.* >= args.len) {
        std.log.err("missing value after {s}", .{option});
        return error.MissingOptionValue;
    }
    return args[index.*];
}

fn parseSize(text: []const u8) !struct { width: usize, height: usize } {
    const separator = std.mem.findScalar(u8, text, 'x') orelse
        std.mem.findScalar(u8, text, 'X') orelse return error.InvalidSize;
    const width = try std.fmt.parseInt(usize, text[0..separator], 10);
    const height = try std.fmt.parseInt(usize, text[separator + 1 ..], 10);
    if (width < 320 or height < 240 or width > 8192 or height > 8192) return error.InvalidSize;
    return .{ .width = width, .height = height };
}

fn parseConfig(args: []const [:0]const u8, config: *Config) !bool {
    var index: usize = 1;
    while (index < args.len) : (index += 1) {
        const argument: []const u8 = args[index];
        if (std.mem.eql(u8, argument, "-h") or std.mem.eql(u8, argument, "--help")) {
            printUsage(args[0]);
            return false;
        } else if (std.mem.eql(u8, argument, "--fb")) {
            config.framebuffer_path = try requireValue(args, &index, argument);
        } else if (std.mem.eql(u8, argument, "--mouse")) {
            config.mouse_path = try requireValue(args, &index, argument);
        } else if (std.mem.eql(u8, argument, "--udp")) {
            config.udp_port = try std.fmt.parseInt(u16, try requireValue(args, &index, argument), 10);
        } else if (std.mem.eql(u8, argument, "--fps")) {
            config.fps = try std.fmt.parseFloat(f64, try requireValue(args, &index, argument));
        } else if (std.mem.eql(u8, argument, "--no-demo")) {
            config.demo = false;
        } else if (std.mem.eql(u8, argument, "--ppm")) {
            config.ppm_path = try requireValue(args, &index, argument);
            config.framebuffer_path = null;
        } else if (std.mem.eql(u8, argument, "--size")) {
            const size = try parseSize(try requireValue(args, &index, argument));
            config.width = size.width;
            config.height = size.height;
            config.size_explicit = true;
        } else if (std.mem.eql(u8, argument, "--frames")) {
            config.frames = try std.fmt.parseInt(usize, try requireValue(args, &index, argument), 10);
        } else {
            std.log.err("unknown option: {s}", .{argument});
            return error.UnknownOption;
        }
    }
    if (!std.math.isFinite(config.fps) or config.fps < 1 or config.fps > 240) return error.InvalidFps;
    if (config.ppm_path != null and config.frames == 0) config.frames = 1;
    return true;
}

fn writePpm(io: std.Io, path: []const u8, canvas: *const Canvas, allocator: std.mem.Allocator) !void {
    const file = try std.Io.Dir.cwd().createFile(io, path, .{});
    defer file.close(io);
    var header_buffer: [128]u8 = undefined;
    const header = try std.mem.print(&header_buffer, "P6\n{d} {d}\n255\n", .{ canvas.width, canvas.height });
    try file.writeStreamingAll(io, header);
    const row = try allocator.alloc(u8, canvas.width * 3);
    defer allocator.free(row);
    for (0..canvas.height) |y| {
        for (canvas.pixels[y * canvas.width ..][0..canvas.width], 0..) |pixel, x| {
            row[x * 3] = @truncate(pixel >> 16);
            row[x * 3 + 1] = @truncate(pixel >> 8);
            row[x * 3 + 2] = @truncate(pixel);
        }
        try file.writeStreamingAll(io, row);
    }
}

pub fn main(init: std.process.Init) !void {
    const arena = init.arena.allocator();
    const args = try init.minimal.args.toSlice(arena);
    var config: Config = .{};
    if (!try parseConfig(args, &config)) return;

    var framebuffer_storage: ?Framebuffer = null;
    if (config.framebuffer_path) |path| framebuffer_storage = try Framebuffer.open(path);
    defer {
        if (framebuffer_storage) |*framebuffer| framebuffer.close();
    }

    const width = if (framebuffer_storage) |framebuffer|
        @min(framebuffer.width, if (config.size_explicit) config.width else framebuffer.width)
    else
        config.width;
    const height = if (framebuffer_storage) |framebuffer|
        @min(framebuffer.height, if (config.size_explicit) config.height else framebuffer.height)
    else
        config.height;
    var canvas = try Canvas.init(init.gpa, width, height);
    defer canvas.deinit();

    var scene = try Scene.init(init.gpa);
    defer scene.deinit();
    var udp = try UdpAdapter.open(config.udp_port);
    defer udp.close();
    var demo = DemoAdapter.init(init.gpa);
    defer demo.deinit();

    var terminal: Terminal = .{};
    if (framebuffer_storage != null) terminal.enter();
    defer terminal.leave();
    var mouse: Mouse = .{};
    if (config.mouse_path) |path| mouse.open(path, width, height);
    defer mouse.close();

    var app: App = .{};
    var previous_time = std.Io.Clock.Timestamp.now(init.io, .awake);
    const frame_duration: std.Io.Clock.Duration = .{
        .raw = .fromNanoseconds(@intFromFloat(1_000_000_000.0 / config.fps)),
        .clock = .awake,
    };
    var rendered_frames: usize = 0;
    var render_total_ms: f64 = 0;
    var present_total_ms: f64 = 0;
    var perf_frames: usize = 0;
    scene.log(.info, "3dbg initialized: generic scene, software renderer, Linux platform backend", @as(f64, @floatFromInt(previous_time.raw.nanoseconds)) / 1_000_000_000.0);
    std.log.info("3dbg: {d}x{d}, UDP {d}, {s}", .{
        width,
        height,
        config.udp_port,
        if (framebuffer_storage != null) "framebuffer output" else "headless PPM output",
    });
    if (framebuffer_storage) |*framebuffer| {
        std.log.info("framebuffer direct ARGB32 copy: {s}", .{
            if (framebuffer.canDirectCopy(&canvas)) "enabled" else "disabled",
        });
    }
    while (app.running) {
        const frame_start = std.Io.Clock.Timestamp.now(init.io, .awake);
        const now = @as(f64, @floatFromInt(frame_start.raw.nanoseconds)) / 1_000_000_000.0;
        const dt = @max(@as(f64, @floatFromInt(previous_time.durationTo(frame_start).raw.nanoseconds)) / 1_000_000_000.0, 0.0001);
        previous_time = frame_start;

        udp.update(&scene, now);
        if (udp.requested_view) |requested| {
            app.view = requested;
            udp.requested_view = null;
        }
        if (config.demo) demo.update(&scene, now);

        mouse.update(width, height);
        while (terminal.readKey()) |key| app.keyboard(key);
        const layout = buildLayout(width, height, app.view);
        app.mouseInput(&mouse, layout);
        if (rendered_frames > 0) app.updateTiming(dt);
        const render_start = std.Io.Clock.Timestamp.now(init.io, .awake);
        app.render(&canvas, &scene, &udp, mouse.position);

        const present_start = std.Io.Clock.Timestamp.now(init.io, .awake);
        if (framebuffer_storage) |*framebuffer| framebuffer.present(&canvas);
        const present_end = std.Io.Clock.Timestamp.now(init.io, .awake);

        render_total_ms += @as(
            f64,
            @floatFromInt(render_start.durationTo(present_start).raw.nanoseconds),
        ) / 1_000_000.0;

        present_total_ms += @as(
            f64,
            @floatFromInt(present_start.durationTo(present_end).raw.nanoseconds),
        ) / 1_000_000.0;

        perf_frames += 1;

        if (perf_frames == 120) {
            std.log.info("frame timing: render={d:.2}ms present={d:.2}ms", .{
                render_total_ms / 120.0,
                present_total_ms / 120.0,
            });

            render_total_ms = 0;
            present_total_ms = 0;
            perf_frames = 0;
        }
        rendered_frames += 1;
        if (config.frames > 0 and rendered_frames >= config.frames) break;
        try frame_start.addDuration(frame_duration).wait(init.io);
    }

    if (config.ppm_path) |path| {
        try writePpm(init.io, path, &canvas, init.gpa);
        std.log.info("wrote final frame to {s}", .{path});
    }
}

test "fixed text truncates and compares" {
    const text = Name.from("abcdefghijklmnopqrstuvwxyz-0123456789");
    try std.testing.expectEqual(@as(usize, 32), text.slice().len);
    try std.testing.expect(text.eql("abcdefghijklmnopqrstuvwxyz-01234"));
}

test "ARGB color parsing" {
    try std.testing.expectEqual(Color{ 0x49, 0xcf, 0xff, 0xff }, try parseColor("FF49CFFF"));
    try std.testing.expectEqual(Color{ 0x49, 0xcf, 0xff, 0xff }, try parseColor("49CFFF"));
}

test "generic UDP commands populate the scene" {
    var scene = try Scene.init(std.testing.allocator);
    defer scene.deinit();
    var adapter: UdpAdapter = .{};
    try adapter.processLine(&scene, "scalar voltage 12.6 V FF49CFFF", 1.0);
    try adapter.processLine(&scene, "series latency 4.5 ms FFFFBC4B", 1.0);
    try adapter.processLine(&scene, "p3 7 1 2 3 4 FF4EDC84 target", 1.0);
    try adapter.processLine(&scene, "geo 9 29.7604 -95.3698 420 90 FF49CFFF aircraft", 1.0);
    try std.testing.expectEqual(@as(usize, 1), scene.scalars.items.len);
    try std.testing.expectEqual(@as(usize, 1), scene.series.items.len);
    try std.testing.expectEqual(@as(usize, 1), scene.points_3d.items.len);
    try std.testing.expectEqual(@as(usize, 1), scene.geo_points.items.len);
    try std.testing.expectApproxEqAbs(@as(f64, 12.6), scene.scalars.items[0].value, 0.0001);
}

test "map projection puts its center in the viewport center" {
    const camera = MapCamera{ .center_latitude = 29.7604, .center_longitude = -95.3698, .zoom = 3 };
    const viewport = Rect{ .{ 20, 30 }, .{ 800, 400 } };
    const point = camera.project(viewport, 29.7604, -95.3698);
    try std.testing.expectEqual(@as(i32, 420), point[0]);
    try std.testing.expectEqual(@as(i32, 230), point[1]);
}

test "3D projection keeps target in the viewport center" {
    const camera: Camera3D = .{};
    const viewport = Rect{ .{ 10, 20 }, .{ 640, 480 } };
    const projected = camera.project(viewport, camera.target) orelse return error.ExpectedProjection;
    try std.testing.expectApproxEqAbs(@as(f32, 330), projected[0], 0.01);
    try std.testing.expectApproxEqAbs(@as(f32, 260), projected[1], 0.01);
    try std.testing.expect(projected[2] > 0);
}

test "series uses a bounded ring" {
    var item = Series{
        .name = Name.from("ring"),
        .unit = Unit.from("u"),
        .color = palette.accent,
    };
    var index: usize = 0;
    while (index < series_capacity + 10) : (index += 1)
        item.push(@as(f64, @floatFromInt(index)), @as(f32, @floatFromInt(index)));
    try std.testing.expectEqual(series_capacity, item.len);
    try std.testing.expectApproxEqAbs(@as(f32, 10), item.valueAt(0), 0.001);
}

// Unit, integration, and executable smoke tests.
//
// Run all tests:
//   zig build test
//
// Standalone equivalent:
//   zig test src/main.zig -lc
//
// No root, external map data, netcat, monitor, or image viewer is required.
// Files and child executables stay in std.testing.tmpDir and are removed.
//
// Optional read-only framebuffer hardware test:
//   DBG_TEST_FB=/dev/fb0 zig build test
//
// The hardware test is skipped when DBG_TEST_FB is unset.
// All other tests run normally.
//
// zig build test supplies ZIG_EXE; standalone tests use ZIG_EXE or zig on PATH.
// Kernel terminal structures are deliberately paired with linux.tc* calls.

fn testPpm(dir: std.Io.Dir, path: []const u8, width: usize, height: usize, pixels: ?[]const u32) !void {
    const io = std.testing.io;
    var header_buffer: [128]u8 = undefined;
    const header = try std.mem.print(&header_buffer, "P6\n{d} {d}\n255\n", .{ width, height });
    const expected_len = header.len + width * height * 3;
    const bytes = try dir.readFileAlloc(io, path, std.testing.allocator, .limited(expected_len + 1));
    defer std.testing.allocator.free(bytes);
    try std.testing.expectEqual(expected_len, bytes.len);
    try std.testing.expectEqualSlices(u8, header, bytes[0..header.len]);
    if (pixels) |expected| {
        try std.testing.expectEqual(width * height, expected.len);
        for (expected, 0..) |pixel, i| {
            const rgb = [3]u8{ @truncate(pixel >> 16), @truncate(pixel >> 8), @truncate(pixel) };
            try std.testing.expectEqualSlices(u8, &rgb, bytes[header.len + i * 3 ..][0..3]);
        }
    } else {
        // Require different RGB pixels, not merely different bytes in a solid color.
        var varied = false;
        var i = header.len + 3;
        while (i < bytes.len) : (i += 3) {
            if (!std.mem.eql(u8, bytes[header.len..][0..3], bytes[i..][0..3])) {
                varied = true;
                break;
            }
        }
        try std.testing.expect(varied);
    }
}

fn testProcess(dir: std.Io.Dir, argv: []const []const u8, seconds: i64, expected_error: ?[]const u8) !void {
    const io = std.testing.io;
    const result = try std.process.run(std.testing.allocator, io, .{
        .argv = argv,
        .cwd = .{ .dir = dir },
        .stdout_limit = .limited(1024 * 1024),
        .stderr_limit = .limited(1024 * 1024),
        .timeout = .{ .deadline = .fromNow(io, .{ .raw = .fromSeconds(seconds), .clock = .awake }) },
    });
    defer std.testing.allocator.free(result.stdout);
    defer std.testing.allocator.free(result.stderr);
    // A signal/crash is not a successful rejection of invalid arguments.
    const exited = switch (result.term) {
        .exited => |code| if (expected_error != null) code != 0 else code == 0,
        else => false,
    };
    if (!exited) {
        std.debug.print("\nchild {s}: {f}\n{s}{s}\n", .{ argv[0], result.term, result.stdout, result.stderr });
        return error.ChildResultUnexpected;
    }
    if (expected_error) |name| {
        if (std.mem.find(u8, result.stderr, name) == null) {
            std.debug.print("\nexpected child error {s}:\n{s}\n", .{ name, result.stderr });
            return error.ChildErrorUnexpected;
        }
    }
}

fn testReadable(fd: c_int) !void {
    var descriptors = [_]c.pollfd{.{ .fd = fd, .events = c.POLL.IN, .revents = 0 }};
    if (c.poll(&descriptors, 1, 2000) != 1 or descriptors[0].revents & c.POLL.IN == 0)
        return error.InputNotReady;
}

fn testDatagram(sender: c_int, receiver: c_int, bytes: []const u8) !void {
    var address: c.sockaddr.in = .{ .port = 0, .addr = 0 };
    var size: c.socklen_t = @sizeOf(c.sockaddr.in);
    try std.testing.expectEqual(@as(c_int, 0), c.getsockname(receiver, @ptrCast(&address), &size));
    try std.testing.expect(address.port != 0);
    address.addr = std.mem.nativeToBig(u32, 0x7f00_0001);
    try std.testing.expectEqual(@as(isize, @intCast(bytes.len)), c.sendto(sender, bytes.ptr, bytes.len, 0, @ptrCast(&address), size));
    try testReadable(receiver);
}

test "clipping, rectangles and line rasterization" {
    var canvas = try Canvas.init(std.testing.allocator, 320, 240);
    defer canvas.deinit();
    canvas.clear(.{ 0, 0, 0, 255 });
    const clip = Rect{ .{ 10, 20 }, .{ 4, 3 } };
    try std.testing.expect(contains(clip, .{ 10, 20 }));
    try std.testing.expect(!contains(clip, .{ 14, 20 }));
    try std.testing.expect(!contains(clip, .{ 10, 23 }));
    try std.testing.expectEqualDeep(Rect{ .{ 11, 21 }, .{ 2, 1 } }, inset(clip, 1));
    canvas.setClip(clip);
    canvas.fillRect(.{ .{ -20, -20 }, .{ 400, 300 } }, .{ 255, 0, 0, 255 });
    for (canvas.pixels, 0..) |pixel, i| {
        const p: Coord2 = .{ @intCast(i % canvas.width), @intCast(i / canvas.width) };
        try std.testing.expectEqual(@as(u32, if (contains(clip, p)) 0xffff_0000 else 0xff00_0000), pixel);
    }
    canvas.resetClip();
    canvas.line(.{ -10, 0 }, .{ 10, 0 }, .{ 0, 255, 0, 255 }, 1);
    for (canvas.pixels[0..11]) |pixel| try std.testing.expectEqual(@as(u32, 0xff00_ff00), pixel);
    canvas.setClip(.{ .{ 400, 400 }, .{ 20, 20 } });
    try std.testing.expectEqual(Coord2{ 0, 0 }, canvas.clip[1]);
    canvas.fillRect(.{ .{ 0, 0 }, .{ 320, 240 } }, .{ 255, 255, 255, 255 });
    try std.testing.expectEqual(@as(u32, 0xff00_0000), canvas.pixels[30 * 320 + 30]);
}

test "depth tests for points, lines, circles and triangles" {
    var canvas = try Canvas.init(std.testing.allocator, 320, 240);
    defer canvas.deinit();
    canvas.clear(.{ 0, 0, 0, 255 });
    canvas.clearDepth();
    canvas.putDepthPixel(20, 20, 5, .{ 255, 0, 0, 255 });
    canvas.putDepthPixel(20, 20, 8, .{ 0, 255, 0, 255 });
    try std.testing.expectEqual(@as(u32, 0xffff_0000), canvas.pixels[20 * 320 + 20]);
    canvas.putDepthPixel(20, 20, 2, .{ 0, 0, 255, 255 });
    try std.testing.expectEqual(@as(u32, 0xff00_00ff), canvas.pixels[20 * 320 + 20]);
    canvas.depthLine(.{ 30, 30, 4 }, .{ 40, 30, 4 }, .{ 0, 255, 0, 255 }, 3);
    try std.testing.expectEqual(@as(f32, 4), canvas.depth[30 * 320 + 35]);
    canvas.depthCircle(.{ 35, 30 }, 2, 3, .{ 255, 0, 0, 255 });
    try std.testing.expectEqual(@as(f32, 3), canvas.depth[30 * 320 + 35]);
    canvas.depthTriangle(.{ 60, 60, 2 }, .{ 80, 60, 2 }, .{ 60, 80, 2 }, .{ 255, 255, 255, 255 });
    try std.testing.expectEqual(@as(u32, 0xffff_ffff), canvas.pixels[65 * 320 + 65]);
    try std.testing.expectApproxEqAbs(@as(f32, 2), canvas.depth[65 * 320 + 65], 0.00001);
    canvas.fillCircle(.{ 100, 100 }, 0, .{ 255, 0, 0, 255 });
    try std.testing.expectEqual(@as(u32, 0xffff_0000), canvas.pixels[100 * 320 + 100]);
}

test "nearest-neighbor image scaling" {
    var canvas = try Canvas.init(std.testing.allocator, 320, 240);
    defer canvas.deinit();
    canvas.clear(.{ 0, 0, 0, 255 });
    const image = [_]u32{ 0xffff_0000, 0xff00_ff00, 0xff00_00ff, 0xffff_ffff };
    canvas.drawImageNearest(.{ .{ 10, 10 }, .{ 4, 4 } }, 2, 2, &image);
    for (0..4) |y| for (0..4) |x| {
        try std.testing.expectEqual(image[(y / 2) * 2 + x / 2], canvas.pixels[(y + 10) * 320 + x + 10]);
    };
    canvas.drawImageNearest(.{ .{ 10, 10 }, .{ 4, 4 } }, 0, 0, &.{});
    try std.testing.expectEqual(image[0], canvas.pixels[10 * 320 + 10]);
}

test "transform order and projection rejection" {
    const point = applyTransform(.{ 1, 0, 0 }, .{
        .translation = .{ 10, 20, 30 },
        .rotation_deg = .{ 0, 0, 90 },
        .scale = .{ 2, 3, 4 },
    });
    inline for (0..3) |i| try std.testing.expectApproxEqAbs((Pos3{ 10, 22, 30 })[i], point[i], 0.0001);
    const camera: Camera3D = .{};
    const viewport = Rect{ .{ 0, 0 }, .{ 320, 240 } };
    try std.testing.expect(camera.project(viewport, camera.position()) == null);
    try std.testing.expect(camera.project(viewport, .{ std.math.nan(f32), 0, 0 }) == null);
    try std.testing.expectEqual(@as(f64, -179), MapCamera.wrapLongitude(181));
    try std.testing.expectEqual(@as(f64, 179), MapCamera.wrapLongitude(-181));
}

test "scene updates reject invalid values without replacing good data" {
    var scene = try Scene.init(std.testing.allocator);
    defer scene.deinit();
    const good: Point3D = .{ .id = 7, .position = .{ 1, 2, 3 }, .updated_at = 1 };
    try scene.upsertPoint3D(good);
    var changed = good;
    changed.position = .{ 4, 5, 6 };
    try scene.upsertPoint3D(changed);
    try std.testing.expectEqual(@as(usize, 1), scene.points_3d.items.len);
    try std.testing.expectEqual(changed.position, scene.points_3d.items[0].position);
    changed.position[0] = std.math.inf(f32);
    try std.testing.expectError(error.InvalidNumericValue, scene.upsertPoint3D(changed));
    try std.testing.expectEqual(Pos3{ 4, 5, 6 }, scene.points_3d.items[0].position);
    try std.testing.expectError(error.NonFiniteNumber, parseFiniteFloat(f64, "nan"));
    try std.testing.expectError(error.NonFiniteNumber, parseFiniteFloat(f64, "inf"));
    try std.testing.expectError(error.InvalidNumericValue, scene.upsertGeoPoint(.{ .id = 1, .latitude_deg = 91, .longitude_deg = 0 }));
    try std.testing.expectError(error.InvalidNumericValue, scene.upsertPoint2D(.{ .id = 1, .position = .{ 100, 0 } }));
    try std.testing.expectError(error.InvalidImage, scene.image.setArgb(std.testing.allocator, 2, 2, &.{0}, 0));
}

test "bounded scene and log storage" {
    var scene = try Scene.init(std.testing.allocator);
    defer scene.deinit();
    for (0..max_scalars) |i| {
        var buf: [32]u8 = undefined;
        const name = try std.mem.print(&buf, "scalar-{d}", .{i});
        try scene.upsertScalar(name, @floatFromInt(i), "u", palette.text, 1);
    }
    try std.testing.expectError(error.SceneLimit, scene.upsertScalar("overflow", 0, "u", palette.text, 1));
    try scene.upsertScalar("scalar-0", 42, "u", palette.text, 2);
    try std.testing.expectEqual(@as(usize, max_scalars), scene.scalars.items.len);
    try std.testing.expectEqual(@as(f64, 42), scene.scalars.items[0].value);
    for (0..max_logs + 5) |i| scene.log(.info, "bounded", @floatFromInt(i));
    try std.testing.expectEqual(@as(usize, max_logs), scene.log_len);
    try std.testing.expectEqual(@as(f64, 5), scene.logs[scene.log_start].time_seconds);
    scene.clear("all");
    try std.testing.expectEqual(@as(usize, 0), scene.scalars.items.len);
    try std.testing.expectEqual(@as(usize, 0), scene.log_len);
    try std.testing.expectError(error.OutOfMemory, Scene.init(std.testing.failing_allocator));
    try std.testing.expectError(error.OutOfMemory, Canvas.init(std.testing.failing_allocator, 320, 240));
}

test "all views render both empty and populated scenes" {
    var scene = try Scene.init(std.testing.allocator);
    defer scene.deinit();
    const udp: UdpAdapter = .{};
    for ([_]Coord2{ .{ 320, 240 }, .{ 640, 480 }, .{ 1280, 720 } }) |size| {
        var canvas = try Canvas.init(std.testing.allocator, @intCast(size[0]), @intCast(size[1]));
        defer canvas.deinit();
        scene.clear("all");
        var demo = DemoAdapter.init(std.testing.allocator);
        defer demo.deinit();
        for ([_]bool{ false, true }) |populated| {
            if (populated) {
                demo.setup(&scene, 1);
                demo.update(&scene, 1);
                demo.update(&scene, 1.25);
                try std.testing.expect(scene.cloud_points.items.len > 0);
                try std.testing.expect(scene.meshes.items.len > 0);
                try std.testing.expect(scene.series.items.len > 0);
            }
            for ([_]View{ .overview, .map, .scene, .plots, .image }) |view| {
                var app = App{ .view = view };
                app.render(&canvas, &scene, &udp, .{ 2, 2 });
                try std.testing.expect(!std.mem.allEqual(u32, canvas.pixels, argb(palette.background)));
                for (canvas.pixels) |pixel| try std.testing.expectEqual(@as(u32, 255), pixel >> 24);
            }
        }
    }
}

test "keyboard and mouse change views and cameras" {
    var app: App = .{};
    for ([_]View{ .overview, .map, .scene, .plots, .image }, 0..) |view, i| {
        app.keyboard(@as(u8, '1') + @as(u8, @intCast(i)));
        try std.testing.expectEqual(view, app.view);
    }
    app.keyboard('2');
    app.keyboard('+');
    try std.testing.expect(app.map_camera.zoom > 1);
    app.keyboard('w');
    try std.testing.expect(app.map_camera.center_latitude > 20);
    app.keyboard('3');
    const distance = app.camera_3d.distance;
    app.keyboard('+');
    try std.testing.expect(app.camera_3d.distance < distance);
    const layout = buildLayout(640, 480, .scene);
    var mouse = Mouse{ .position = .{ 100, 100 }, .delta = .{ 5, 4 }, .left = true };
    const yaw = app.camera_3d.yaw;
    app.mouseInput(&mouse, layout);
    try std.testing.expect(app.camera_3d.yaw != yaw);
    mouse.left = false;
    mouse.right = true;
    app.mouseInput(&mouse, layout);
    try std.testing.expect(@reduce(.Or, app.camera_3d.target != @as(Pos3, @splat(0))));
    app.keyboard('r');
    try std.testing.expectEqualDeep(Camera3D{}, app.camera_3d);
    try std.testing.expectEqualDeep(MapCamera{}, app.map_camera);
    app.updateTiming(0.02);
    try std.testing.expectApproxEqAbs(@as(f64, 50), app.fps_smoothed, 0.001);
    app.keyboard('q');
    try std.testing.expect(!app.running);
}

test "command-line headless configuration" {
    var config: Config = .{};
    const args = [_][:0]const u8{ "3dbg", "--ppm", "frame.ppm", "--size", "640x480", "--frames", "3", "--fps", "60", "--udp", "0", "--no-demo" };
    try std.testing.expect(try parseConfig(&args, &config));
    try std.testing.expect(config.framebuffer_path == null);
    try std.testing.expect(!config.demo);
    try std.testing.expectEqual(@as(usize, 3), config.frames);
    try std.testing.expectEqual(@as(usize, 640), config.width);
    try std.testing.expectEqual(@as(usize, 480), config.height);
    try std.testing.expectEqual(@as(u16, 0), config.udp_port);
    try std.testing.expectEqual(@as(f64, 60), config.fps);
    try std.testing.expectError(error.InvalidSize, parseSize("0x240"));
    try std.testing.expectError(error.InvalidSize, parseSize("8193x240"));
    const bad = [_][:0]const u8{ "3dbg", "--fps", "nan" };
    try std.testing.expectError(error.InvalidFps, parseConfig(&bad, &config));
}

test "real PPM file matches every rendered RGB pixel" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var dir_buffer: [4096]u8 = undefined;
    const dir_len = try tmp.dir.realPath(std.testing.io, &dir_buffer);
    var path_buffer: [4096]u8 = undefined;
    const path = try std.mem.print(&path_buffer, "{s}/image.ppm", .{dir_buffer[0..dir_len]});
    var canvas = try Canvas.init(std.testing.allocator, 320, 240);
    defer canvas.deinit();
    for (canvas.pixels, 0..) |*pixel, i| pixel.* = argb(.{ @truncate(i), @truncate(i / 320), 0x0a, 255 });
    // Start with a larger existing file: createFile must truncate it.
    const old = try std.testing.allocator.alloc(u8, 320 * 240 * 4);
    defer std.testing.allocator.free(old);
    @memset(old, 0xa5);
    try tmp.dir.writeFile(std.testing.io, .{ .sub_path = "image.ppm", .data = old });
    try writePpm(std.testing.io, path, &canvas, std.testing.allocator);
    try testPpm(tmp.dir, "image.ppm", 320, 240, canvas.pixels);
}

test "real UDP socket to scene to rendered PPM" {
    var udp = try UdpAdapter.open(0);
    defer udp.close();
    const socket_flags = c.fcntl(udp.fd, c.F.GETFL);
    try std.testing.expect(socket_flags >= 0);
    try std.testing.expect(@as(c.O, @bitCast(socket_flags)).NONBLOCK);
    const sender = c.socket(c.AF.INET, c.SOCK.DGRAM | c.SOCK.CLOEXEC | c.SOCK.NONBLOCK, 0);
    if (sender < 0) return error.OpenTestSocketFailed;
    defer _ = c.close(sender);
    var scene = try Scene.init(std.testing.allocator);
    defer scene.deinit();
    const payload =
        "scalar voltage 12.6 V FF49CFFF\n" ++
        "series latency 4.5 ms FFFFBC4B\n" ++
        "series latency 8.0 ms FFFFBC4B\n" ++
        "p3 7 0 0 0 4 FF4EDC84 TARGET\n" ++
        "geo 9 29.7604 -95.3698 420 90 FF49CFFF AIRCRAFT\n" ++
        "log info received over a real UDP socket\n" ++
        "not_a_command\n" ++
        "scalar voltage nan V FF49CFFF\n" ++
        "view scene\n";
    try testDatagram(sender, udp.fd, payload);
    udp.update(&scene, 1);
    try std.testing.expectEqual(@as(u64, 1), udp.packets_received);
    try std.testing.expectEqual(@as(u64, payload.len), udp.bytes_received);
    try std.testing.expectEqual(@as(u64, 7), udp.commands_received);
    try std.testing.expectEqual(@as(u64, 2), udp.parse_errors);
    try std.testing.expectEqual(@as(?View, .scene), udp.requested_view);
    try std.testing.expectApproxEqAbs(@as(f64, 12.6), scene.scalars.items[0].value, 0.0001);
    try std.testing.expectEqual(@as(usize, 2), scene.series.items[0].len);
    try std.testing.expectEqual(@as(usize, 1), scene.points_3d.items.len);
    const update = "p3 7 1 2 3 4 FF4EDC84 MOVED\n";
    try testDatagram(sender, udp.fd, update);
    udp.update(&scene, 2);
    try std.testing.expectEqual(@as(u64, 2), udp.packets_received);
    try std.testing.expectEqual(@as(usize, 1), scene.points_3d.items.len);
    try std.testing.expectEqual(Pos3{ 1, 2, 3 }, scene.points_3d.items[0].position);
    try std.testing.expectEqual(@as(u64, 8), udp.commands_received);
    try std.testing.expectEqual(@as(f64, 2), udp.last_packet_at);
    udp.update(&scene, 3); // Empty nonblocking socket must return promptly.
    try std.testing.expectEqual(@as(u64, 2), udp.packets_received);

    var canvas = try Canvas.init(std.testing.allocator, 640, 480);
    defer canvas.deinit();
    var app = App{ .view = udp.requested_view.? };
    app.render(&canvas, &scene, &udp, .{ 0, 0 });
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    var dir_buffer: [4096]u8 = undefined;
    const dir_len = try tmp.dir.realPath(std.testing.io, &dir_buffer);
    var path_buffer: [4096]u8 = undefined;
    const path = try std.mem.print(&path_buffer, "{s}/telemetry.ppm", .{dir_buffer[0..dir_len]});
    try writePpm(std.testing.io, path, &canvas, std.testing.allocator);
    try testPpm(tmp.dir, "telemetry.ppm", 640, 480, canvas.pixels);
}

test "framebuffer 16, 24 and 32 bit packing, stride and offsets" {
    var canvas = try Canvas.init(std.testing.allocator, 320, 240);
    defer canvas.deinit();
    canvas.clear(.{ 0, 0, 0, 255 });
    canvas.pixels[0] = 0xffff_0000;
    canvas.pixels[1] = 0xff00_ff00;
    canvas.pixels[320] = 0xff00_00ff;
    canvas.pixels[321] = 0xffff_ffff;
    for ([_]u32{ 16, 24, 32 }) |bpp| {
        var storage: [128]u8 = @splat(0xa5);
        var expected = storage;
        const bytes: usize = @intCast(bpp / 8);
        const stride = 2 * bytes + 9;
        var frame = Framebuffer{
            .fd = -1,
            .mapped = storage[8..120],
            .width = 2,
            .height = 2,
            .stride = stride,
            .xoffset = 1,
            .yoffset = 1,
            .bits_per_pixel = bpp,
            .red = .{ .offset = if (bpp == 16) 11 else 16, .length = if (bpp == 16) 5 else 8, .msb_right = 0 },
            .green = .{ .offset = if (bpp == 16) 5 else 8, .length = if (bpp == 16) 6 else 8, .msb_right = 0 },
            .blue = .{ .offset = 0, .length = if (bpp == 16) 5 else 8, .msb_right = 0 },
            .transp = .{ .offset = if (bpp == 32) 24 else 0, .length = if (bpp == 32) 8 else 0, .msb_right = 0 },
        };
        const packed_pixels: [4]u32 = if (bpp == 16)
            .{ 0xf800, 0x07e0, 0x001f, 0xffff }
        else
            .{ 0xffff_0000, 0xff00_ff00, 0xff00_00ff, 0xffff_ffff };
        for (packed_pixels, 0..) |pixel, i| {
            const offset = 8 + (i / 2 + 1) * stride + (i % 2 + 1) * bytes;
            for (0..bytes) |byte| expected[offset + byte] = @truncate(pixel >> @as(u5, @intCast(byte * 8)));
        }
        frame.present(&canvas);
        try std.testing.expectEqualSlices(u8, &expected, &storage);
        @memset(&storage, 0xa5);
        frame.mapped = storage[8 .. 8 + stride + bytes + bytes - 1];
        frame.present(&canvas); // First complete pixel cannot fit; no byte may be touched.
        try std.testing.expect(std.mem.allEqual(u8, &storage, 0xa5));
    }
}

test "framebuffer rejects a non-framebuffer device" {
    try std.testing.expectError(error.FramebufferInfoFailed, Framebuffer.open("/dev/null"));
}

test "synthetic mouse packets use the real nonblocking reader" {
    var pipe: [2]c_int = undefined;
    try std.testing.expectEqual(@as(c_int, 0), c.pipe2(&pipe, .{ .NONBLOCK = true, .CLOEXEC = true }));
    defer _ = c.close(pipe[1]);
    var mouse = Mouse{ .fd = pipe[0], .position = .{ 20, 20 } };
    defer mouse.close();
    const press = [_]u8{ 0x09, 5, 3 };
    try std.testing.expectEqual(@as(isize, 3), c.write(pipe[1], &press, press.len));
    mouse.update(64, 64);
    try std.testing.expectEqual(Coord2{ 25, 17 }, mouse.position);
    try std.testing.expectEqual(Coord2{ 5, -3 }, mouse.delta);
    try std.testing.expect(mouse.left and mouse.left_pressed);
    mouse.update(64, 64);
    try std.testing.expectEqual(@as(Coord2, @splat(0)), mouse.delta);
    try std.testing.expect(mouse.left and !mouse.left_pressed);
    const right = [_]u8{ 0x0a, 0, 0 };
    try std.testing.expectEqual(@as(isize, 3), c.write(pipe[1], &right, right.len));
    mouse.update(64, 64);
    try std.testing.expect(mouse.left_released and mouse.right_pressed and mouse.right and !mouse.left);
    const move = [_]u8{ 0x18, 0x80, 0x7f };
    try std.testing.expectEqual(@as(isize, 3), c.write(pipe[1], &move, move.len));
    mouse.update(64, 64);
    try std.testing.expectEqual(Coord2{ 0, 0 }, mouse.position);
    try std.testing.expect(mouse.right_released);
    mouse.close();
    try std.testing.expectEqual(@as(c_int, -1), mouse.fd);
}

test "terminal raw mode, keyboard bytes and restoration on a private PTY" {
    const master = c.open("/dev/ptmx", .{ .ACCMODE = .RDWR, .NOCTTY = true, .CLOEXEC = true, .NONBLOCK = true });
    if (master < 0) return error.OpenPseudoTerminalFailed;
    defer _ = c.close(master);
    var unlocked: c_int = 0;
    try std.testing.expectEqual(@as(c_int, 0), c.ioctl(master, @as(c_int, @bitCast(@as(u32, linux.T.IOCSPTLCK))), &unlocked));
    var number: c_uint = 0;
    try std.testing.expectEqual(@as(c_int, 0), c.ioctl(master, @as(c_int, @bitCast(@as(u32, linux.T.IOCGPTN))), &number));
    var path_buffer: [64]u8 = undefined;
    const path = try std.mem.printSentinel(&path_buffer, "/dev/pts/{d}", .{number}, 0);
    const slave = c.open(path.ptr, .{ .ACCMODE = .RDWR, .NOCTTY = true, .CLOEXEC = true });
    if (slave < 0) return error.OpenPseudoTerminalFailed;
    defer _ = c.close(slave);
    var original: linux.termios = std.mem.zeroes(linux.termios);
    try std.testing.expectEqual(@as(usize, 0), linux.tcgetattr(slave, &original));
    const original_flags = c.fcntl(slave, c.F.GETFL);
    try std.testing.expect(original_flags >= 0);
    var terminal = Terminal{ .fd = slave };
    defer terminal.leave();
    terminal.enter();
    try std.testing.expect(terminal.active);
    var raw: linux.termios = std.mem.zeroes(linux.termios);
    try std.testing.expectEqual(@as(usize, 0), linux.tcgetattr(slave, &raw));
    try std.testing.expect(!raw.lflag.ECHO and !raw.lflag.ICANON);
    try std.testing.expectEqual(@as(u8, 0), raw.cc[@backingInt(linux.V.MIN)]);
    try std.testing.expectEqual(@as(u8, 0), raw.cc[@backingInt(linux.V.TIME)]);
    const flags: c.O = @bitCast(c.fcntl(slave, c.F.GETFL));
    try std.testing.expect(flags.NONBLOCK);
    try std.testing.expect(terminal.readKey() == null);
    try std.testing.expectEqual(@as(isize, 1), c.write(master, "3", 1));
    try testReadable(slave);
    try std.testing.expectEqual(@as(?u8, '3'), terminal.readKey());
    terminal.leave();
    var restored: linux.termios = std.mem.zeroes(linux.termios);
    try std.testing.expectEqual(@as(usize, 0), linux.tcgetattr(slave, &restored));
    try std.testing.expectEqualDeep(original, restored);
    try std.testing.expectEqual(original_flags, c.fcntl(slave, c.F.GETFL));
    try std.testing.expect(!terminal.active);
    try std.testing.expect(terminal.readKey() == null);
}

test "monotonic frame deadline actually waits" {
    const io = std.testing.io;
    const start = std.Io.Clock.Timestamp.now(io, .awake);
    const interval: std.Io.Clock.Duration = .{ .raw = .fromMilliseconds(2), .clock = .awake };
    try start.addDuration(interval).wait(io);
    const elapsed = start.untilNow(io).raw.nanoseconds;
    try std.testing.expect(elapsed >= interval.raw.nanoseconds);
    // No upper time bound: loaded machines may legitimately wake up late.
}

test "build current source and run headless commands" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const io = std.testing.io;
    try tmp.dir.writeFile(io, .{ .sub_path = "main.zig", .data = @embedFile("main.zig") });
    const zig_exe = std.testing.environ.getPosix("ZIG_EXE") orelse "zig";
    try testProcess(tmp.dir, &.{ zig_exe, "build-exe", "main.zig", "-lc", "-femit-bin=viewer-test" }, 180, null);
    try testProcess(tmp.dir, &.{ "./viewer-test", "--help" }, 10, null);
    try testProcess(tmp.dir, &.{ "./viewer-test", "--ppm", "demo.ppm", "--frames", "1", "--size", "1280x720", "--udp", "0" }, 30, null);
    try testPpm(tmp.dir, "demo.ppm", 1280, 720, null);
    const start = std.Io.Clock.Timestamp.now(io, .awake);
    try testProcess(tmp.dir, &.{ "./viewer-test", "--ppm", "empty.ppm", "--frames", "3", "--fps", "30", "--size", "640x480", "--udp", "0", "--no-demo" }, 30, null);
    try std.testing.expect(start.untilNow(io).raw.nanoseconds >= 60_000_000);
    try testPpm(tmp.dir, "empty.ppm", 640, 480, null);
    try testProcess(tmp.dir, &.{ "./viewer-test", "--fps", "0" }, 10, "InvalidFps");
    try testProcess(tmp.dir, &.{ "./viewer-test", "--size", "0x0" }, 10, "InvalidSize");
    try testProcess(tmp.dir, &.{ "./viewer-test", "--unknown" }, 10, "UnknownOption");
    try testProcess(tmp.dir, &.{ "./viewer-test", "--frames" }, 10, "MissingOptionValue");
}

test "optional read-only framebuffer metadata probe" {
    const path = std.testing.environ.getPosix("DBG_TEST_FB") orelse return error.SkipZigTest;
    const fd = c.open(path.ptr, .{ .ACCMODE = .RDONLY, .CLOEXEC = true });
    if (fd < 0) return error.OpenFramebufferProbeFailed;
    defer _ = c.close(fd);
    var variable: fb.VarScreenInfo = undefined;
    var fixed: fb.FixScreenInfo = undefined;
    try std.testing.expectEqual(@as(c_int, 0), c.ioctl(fd, fb.GET_VSCREENINFO, &variable));
    try std.testing.expectEqual(@as(c_int, 0), c.ioctl(fd, fb.GET_FSCREENINFO, &fixed));
    try std.testing.expectEqual(@as(u32, 0), fixed.type);
    try std.testing.expectEqual(@as(u32, 2), fixed.visual);
    try std.testing.expect(variable.nonstd == 0 and variable.grayscale == 0);
    try std.testing.expect(variable.bits_per_pixel == 16 or variable.bits_per_pixel == 24 or variable.bits_per_pixel == 32);
    try std.testing.expect(variable.xres >= 320 and variable.yres >= 240);
    inline for (.{ variable.red, variable.green, variable.blue, variable.transp }) |field| {
        try std.testing.expect(field.length <= 32 and field.offset <= 32);
        try std.testing.expect(field.offset + field.length <= variable.bits_per_pixel and field.msb_right == 0);
    }
    const row_bytes = (@as(u64, variable.xoffset) + variable.xres) * (variable.bits_per_pixel / 8);
    const last_row = (@as(u64, variable.yoffset) + variable.yres - 1) * fixed.line_length;
    try std.testing.expect(row_bytes <= fixed.line_length);
    try std.testing.expect(last_row + row_bytes <= fixed.smem_len);
    std.debug.print("\nframebuffer {s}: {d}x{d}, {d} bpp, stride {d}, memory {d} bytes (read-only probe)\n", .{
        path, variable.xres, variable.yres, variable.bits_per_pixel, fixed.line_length, fixed.smem_len,
    });
}
