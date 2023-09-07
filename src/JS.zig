const std = @import("std");

pub const Imports = struct {
    extern fn jsConsoleLogWrite(ptr: [*]const u8, len: usize) void;
    extern fn jsConsoleLogFlush() void;

    extern fn jsCanvas2DClear() void;
    extern fn jsCanvas2DFillRect(x: usize, y: usize, width: usize, height: usize) void;
};

pub const Console = struct {
    pub const Logger = struct {
        pub const Error = error{};
        pub const Writer = std.io.Writer(void, Error, write);

        fn write(_: void, bytes: []const u8) Error!usize {
            Imports.jsConsoleLogWrite(bytes.ptr, bytes.len);
            return bytes.len;
        }
    };

    const logger = Logger.Writer{ .context = {} };
    pub fn log(comptime format: []const u8, args: anytype) void {
        logger.print(format, args) catch return;
        Imports.jsConsoleLogFlush();
    }

    pub fn logError(comptime format: []const u8, args: anytype) void {
        log("error :" ++ format, args);
    }
};

pub const Screen = struct {
    pub fn clear() void {
        Imports.jsCanvas2DClear();
    }

    pub fn point(x: f32, y: f32) void {
        const ix: usize = @intFromFloat(x);
        const iy: usize = @intFromFloat(y);
        Imports.jsCanvas2DFillRect(ix, iy, 1, 1);
    }
};
