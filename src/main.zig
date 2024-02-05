const PDP1 = @import("PDP1.zig");
const Spacewar = @import("Spacewar.zig");

const JS = @import("JS.zig");

const std = @import("std");

var pdp1 = PDP1{};

export const screen_width: usize = PDP1.screen_width;
export const screen_height: usize = PDP1.screen_height;

export fn init() void {
    std.mem.copyForwards(u18, pdp1.mem[0..], Spacewar.memory[0..]); // TODO: make this a method
    pdp1.pc = 4;
    pdp1.run = true;
}

export fn frame() void {
    pdp1.frame();
}

export fn step() void {
    pdp1.step();
}

export fn getScreenWidth() usize {
    return PDP1.screen_width;
}

export fn getScreenHeight() usize {
    return PDP1.screen_height;
}

export fn handleKeyDown(key: u8) void {
    // JS.Console.log("keydown > key: {}, control: 0o{o:0>7}\n", .{ key, pdp1.control });
    pdp1.handleKeyDown(key);
}

export fn handleKeyUp(key: u8) void {
    // JS.Console.log("keydown > key: {}, control: 0o{o:0>7}\n", .{ key, pdp1.control });
    pdp1.handleKeyUp(key);
}
