const PDP1 = @This();

//-- struct fields -------------------------------------------------------------

//---- Machine State -----------------------------------------------------------
ctc: usize = 0,
@"xct.cycle": bool = false,

//---- Processor State ---------------------------------------------------------

/// Run
/// RUN< >
run: bool = false,
/// Accumulator
/// AC\Accumulator<0:17>
ac: u18 = 0,
/// Input-Output Register
/// IO\Input.Output.Register<0:17>
io: u18 = 0,
/// Program Counter
/// PC\Program.Counter<6:17>
pc: u12 = 0,
/// Program Flags
/// PF\Program.Flags<1:6>
pf: u6 = 0,
/// Overflow
/// OV\Overflow< >
ov: u1 = 0,
/// Instruction Register
/// IR\Instruction.Register<0:4>
ir: u5 = 0,
/// Memory Buffer Register
/// MB\Memory.Buffer<0:17>
mb: u18 = 0,
/// Memory Address Register
/// MA\Memory.Address<6:17>
ma: u12 = 0,

//---- Memory State ------------------------------------------------------------
/// Core Memory
/// M\Memory[0:4095]<0:17>
mem: [mem_size]u18 = [_]u18{0} ** mem_size,

//---- Console State -----------------------------------------------------------
/// Test Word Switches
/// TWS\Test.Word.Switches<0:17>
tws: u18 = 0,
/// Sense Switches
/// SS\Sense.Switches<1:6>
ss: u6 = 0,
/// Address Switches
/// AS\Address.Switches<0:15>
as: u16 = 0,

//---- I/O State -----------------------------------------------------------
control: u18 = 0, // TODO: rename me

//---- Debugger State ----------------------------------------------------------
steps: usize = 0,

//-- imports -------------------------------------------------------------------

const OnesComplement = @import("OnesComplement.zig");

const JS = @import("JS.zig");

const std = @import("std");

//-- constants -----------------------------------------------------------------

pub const mem_size: usize = 4096;

pub const screen_width: usize = 550;
pub const screen_height: usize = 550;

const sign_mask = 0o400000;

const fs_test = [_]u6{ 0o00, 0o40, 0o20, 0o10, 0o04, 0o02, 0o01, 0o77 };

const shift_count = blk: {
    @setEvalBranchQuota(8000);
    const map_len = 0o1000;
    var map: [map_len]u5 = undefined;
    for (&map, 0..) |*value, i| {
        var mask = i;
        var count: u5 = 0;
        while (mask != 0) : (mask >>= 1) {
            count += mask & 1; // count number of 1's in `i`
        }
        value.* = count;
    }
    break :blk map;
};

const Instruction = enum(u5) {
    AND = 0o01, // Logical AND
    IOR = 0o02, // Inclusive OR
    XOR = 0o03, // Exclusive OR
    XCT = 0o04, // Execute
    CAL_JDA = 0o07, // Call Subroutine - Jump and Deposit Accumulator
    LAC = 0o10, // Load Accumulator
    LIO = 0o11, // Load In-Out Register
    DAC = 0o12, // Deposit Accumulator
    DAP = 0o13, // Deposit Address Part
    DIP = 0o14, // Deposit Instruction Part
    DIO = 0o15, // Deposit In-Out Register
    DZM = 0o16, // Deposit Zero in Memory
    ADD = 0o20, // Add
    SUB = 0o21, // Subtract
    IDX = 0o22, // Index
    ISP = 0o23, // Index and Skip if Positive
    SAD = 0o24, // Skip if Accumulator and Y differ
    SAS = 0o25, // Skip if Accumulator and Y are the same
    MUS = 0o26, // Multiply Step
    DIS = 0o27, // Divide Step
    JMP = 0o30, // Jump
    JSP = 0o31, // Jump and Save Program Counter
    SKP = 0o32, // Skip Group
    SFT = 0o33, // Shift Group
    LAW = 0o34, // Load Accumulator with N
    IOT = 0o35, // In-Out Transfer Group
    OPR = 0o37, // Operate Group
    _,

    pub inline fn toString(self: Instruction) [:0]const u8 {
        return @tagName(self);
    }

    pub inline fn toInstruction(opcode: u5) Instruction {
        return @as(Instruction, @enumFromInt(opcode));
    }

    pub inline fn y(word: u18) u12 {
        return @truncate(word);
    }

    pub inline fn ib(word: u18) u1 {
        return bitGet(word, 12);
    }
};

//-- functions -----------------------------------------------------------------

pub fn reset(self: *PDP1) void {
    self.run = false;
    self.ac = 0;
    self.io = 0;
    self.pc = 0;
    self.pf = 0;
    self.ov = 0;
    self.ir = 0;
    self.mb = 0;
    self.ma = 0;
}

pub fn frame(self: *PDP1) void {
    JS.Screen.clear();
    while (self.pc != 0o2051) {
        self.step();
    }
    self.step();
    while (self.pc != 0o2051) {
        self.step();
    }
    self.step();
}

pub fn step(self: *PDP1) void {
    if (!self.run) {
        return;
    }

    // debugState(self);
    self.steps += 1;

    if (self.@"xct.cycle") {
        self.@"xct.cycle" = false;
    } else {
        self.ma = self.pc;
        self.read();
        self.pc +%= 1;
    }
    self.execute();
}

fn read(self: *PDP1) void {
    self.ctc += 5;
    self.mb = self.mem[self.ma];
}

fn write(self: *PDP1) void {
    self.ctc += 5;
    self.mem[self.ma] = self.mb;
}

fn execute(self: *PDP1) void {
    self.ir = getIR(self.mb);
    switch (Instruction.toInstruction(self.ir)) {
        .AND => {
            // The bits of C(Y) operate on the corresponding bits of the
            // Accumulator to form the logical AND. The result is left in the
            // Accumulator. The C(Y) are unaffected by this instruction.
            self.ea();
            self.read();
            self.ac &= self.mb;
        },
        .IOR => {
            // The bits of C(Y) operate on the corresponding bits of the
            // Accumulator to form the inclusive OR. The result is left in the
            // Accumulator. The C(Y) are unaffected by this order.
            self.ea();
            self.read();
            self.ac |= self.mb;
        },
        .XOR => {
            // The bits of C(Y) operate on the corresponding bits of the
            // Accumulator to form the exclusive OR. The result is left in the
            // Accumulator. The C(Y) are unaffected by this order.
            self.ea();
            self.read();
            self.ac ^= self.mb;
        },
        .XCT => {
            // TODO: xct_max and xct_count

            // The instruction located in register Y is executed.
            // The Program Counter remains unchanged (unless a jump or skip
            // were executed). If a skip instruction is executed (by xct y),
            // the next instruction to be executed will be taken from the
            // address of the xct y plus one or the address of the xct y plus
            // two depending on the skip condition. Execute may be indirectly
            // addressed, and the instruction being executed may use indirect
            // addressing. An xct instruction may execute other xct commands.
            self.ea();
            self.read();
            self.@"xct.cycle" = true;
        },
        .CAL_JDA => {
            if (Instruction.ib(self.mb) == 1) {
                self.ma = Instruction.y(self.mb);
            } else {
                self.ma = 0o0100;
            }
            self.mb = self.ac;
            self.write();
            self.ac = (@as(u18, self.ov) << 17) | self.pc;
            self.pc = self.ma +% 1;
        },
        .LAC => {
            // The C(Y) are placed in the Accumulator.
            // The C(Y) are unchanged.
            // The original C(AC) are lost.
            self.ea();
            self.read();
            self.ac = self.mb;
        },
        .LIO => {
            // The C(Y) are placed in the In-Out Register.
            // The C(Y) are unchanged.
            // The original C(IO) are lost.
            self.ea();
            self.read();
            self.io = self.mb;
        },
        .DAC => {
            // The C(AC) replace the C(Y) in the memory.
            // The C(AC) are left unchanged by this instruction.
            // The original C(Y) are lost.
            self.ea();
            self.mb = self.ac;
            self.write();
        },
        .DAP => {
            // Bits 6 through 17 of the Accumulator replace the corresponding
            // digits of memory register Y.
            // C(AC) are unchanged as are the contents of Bits 0 through 5 of Y.
            // The original contents of Bits 6 through 17 of Y are lost.
            self.ea();
            self.read();
            self.mb = (self.mb & 0o770000) | (self.ac & 0o007777);
            self.write();
        },
        .DIP => {
            // Bits 0 through 5 of the Accumulator replace the corresponding
            // digits of memory register Y.
            // The Accumulator is unchanged as are Bits 6 through 17 of Y.
            // The original contents of Bits 0 through 5 of Y are lost.
            self.ea();
            self.read();
            self.mb = (self.ac & 0o770000) | (self.mb & 0o007777);
            self.write();
        },
        .DIO => {
            // The C(IO) replace the C(Y) in the memory.
            // The C(IO) are left unchanged by this instruction.
            // The original C(Y) are lost.
            self.ea();
            self.mb = self.io;
            self.write();
        },
        .DZM => {
            // Clears (sets equal to plus zero) the contents of register Y.
            self.ea();
            self.mb = 0;
            self.write();
        },
        .ADD => {
            // The new C(AC) are the sum of C(Y) and the original C(AC).
            // The C(Y) are unchanged.
            // The addition is performed with 1's complement arithmetic.
            // If the sum of two like-signed numbers yields a result of the
            // opposite sign, the overflow flip-flop will be set (see Skip Group
            // instructions). A result of minus zero is changed to plus zero.
            self.ea();
            self.read();

            const ac_sign = OnesComplement.sign(u18, self.ac);
            const mb_sign = OnesComplement.sign(u18, self.mb);

            self.ac = OnesComplement.add(u18, self.ac, self.mb);
            const res_sign = OnesComplement.sign(u18, self.ac);

            if ((ac_sign == mb_sign) and (res_sign != ac_sign)) {
                self.ov = 1;
            }

            if (self.ac == 0o777777) {
                self.ac = 0;
            }
        },
        .SUB => {
            // The new C(AC) are the original C(AC) minus the C(Y).
            // The C(Y) are unchanged.
            // The subtraction is performed using 1's complement arithmetic.
            // When two unlike-signed numbers are subtracted, the sign of the
            // result must agree with the sign of the original Accumulator,
            // or overflow flip-flop will be set (see Skip Group instructions).
            // A result of minus zero can exist in one instance only: (-0)-(+0) = (-0)
            self.ea();
            self.read();

            const ac_sign = OnesComplement.sign(u18, self.ac);
            const mb_sign = OnesComplement.sign(u18, self.mb);

            self.ac = OnesComplement.sub(u18, self.ac, self.mb);
            const res_sign = OnesComplement.sign(u18, self.ac);

            if ((ac_sign != mb_sign) and (res_sign != ac_sign)) {
                self.ov = 1;
            }
        },
        .IDX => {
            // The C(Y) are replaced by C(Y) + 1 which are left in the
            // Accumulator. The previous C(AC) are lost. Overflow is not
            // indicated. If the original C(Y) equals the integer, -1, the
            // result after indexing is plus zero.
            self.ea();
            self.read();
            self.ac = OnesComplement.add(u18, self.mb, 1);
            if (self.ac == 0o777777) {
                self.ac = 0;
            }
            self.mb = self.ac;
            self.write();
        },
        .ISP => {
            // The C(Y) are replaced by C(Y) + 1 which are left in the
            // Accumulator. The previous C(AC) are lost. If, after the addition,
            // the Accumulator is positive, the Program Counter is advanced
            // one extra position and the next instruction in sequence is
            // skipped. Overflow is not indicated. If the original C(Y) equals
            // the integer, -1, the result after indexing is plus zero and the
            // skip takes place.
            self.ea();
            self.read();
            self.ac = OnesComplement.add(u18, self.mb, 1);
            if (self.ac == 0o777777) {
                self.ac = 0;
            }
            if (getSign(self.ac) == 0) {
                self.pc +%= 1;
            }
            self.mb = self.ac;
            self.write();
        },
        .SAD => {
            // The C(Y) are compared with the C(AC).
            // If the two numbers are different, the Program Counter is indexed
            // one extra position and the next instruction in the sequence is
            // skipped. The C(AC) and the C(Y) are unaffected by this operation.
            self.ea();
            self.read();
            if (self.ac != self.mb) {
                self.pc +%= 1;
            }
        },
        .SAS => {
            // The C(Y) are compared with the C(AC).
            // If the two numbers are identical, the Program Counter is indexed
            // one extra position and the next instruction in the sequence is
            // skipped. The C(AC) and the C(Y) are unaffected by this operation.
            self.ea();
            self.read();
            if (self.ac == self.mb) {
                self.pc +%= 1;
            }
        },
        .MUS => {
            // If Bit 17 of the In-Out Register is a ONE, the C(Y) are added to C(AC).
            // If IO Bit 17 is ZERO, the addition does not take place.
            // In either case, the C(AC) and C(IO) are rotated right one place.
            // AC Bit 0 is made ZERO by this rotate.
            // This instruction is used in the multiply subroutine.
            self.ea();
            self.read();
            if (bitTest(self.io, 0)) {
                self.ac = OnesComplement.add(u18, self.ac, self.mb);
            }
            self.io = ((self.ac & 1) << 17) | (self.io >> 1);
            self.ac >>= 1;
        },
        .DIS => {
            // The Accumulator and the In-Out Register are rotated left one
            // place. IO Bit 17 receives the complement of AC Bit 0. If IO Bit
            // 17 is ONE, the C(Y) are subtracted from C(AC).
            // If IO Bit 17 is ZERO, C(Y) + 1 are added to C(AC).
            // This instruction is used in the divide subroutine.
            // A result of minus zero is changed to plus zero.
            self.ea();
            self.read();
            const acl = self.ac >> 17;
            self.ac = (self.ac << 1) | (self.io >> 17);
            self.io = (self.io << 1) | (acl ^ 1);
            if (acl == 0) {
                self.ac = OnesComplement.add(u18, ~self.ac, self.mb);
                self.ac = ~self.ac;
            } else {
                self.ac = OnesComplement.add(u18, self.ac, self.mb +% 1);
            }
            if (self.ac == 0o777777) {
                self.ac = 0;
            }
        },
        .JMP => {
            // The next instruction executed will be taken from Memory Register Y.
            // The Program Counter is reset to Memory Address Y.
            // The original contents of the Program Counter are lost.
            self.ea();
            self.pc = self.ma;
        },
        .JSP => {
            // The contents of the Program Counter are transferred to bits 6
            // through 17 of the AC. The state of the overflow flip-flop is
            // transferred to bit zero, the condition of the Extend flip-flop
            // to bit 1, and the contents of the Extended Program Counter to
            // bits 2, 3, 4, and 5 of the AC. When the transfer takes place, the
            // Program Counter holds the address of the instruction following
            // the jsp. The Program Counter is then reset to Address Y.
            // The next instruction executed will be taken from Memory Register Y.
            // The original C(AC) are lost.
            self.ea();
            self.ac = (@as(u18, self.ov) << 17) | self.pc;
            self.pc = self.ma;
        },
        .SKP => {
            const v = (self.mb >> 3) & 0o07; // sense switches
            const t = self.mb & 0o07; // program flags
            var skip =
                // SZA
                (bitTest(self.mb, 6) and (self.ac == 0)) or
                // SPA
                (bitTest(self.mb, 7) and (getSign(self.ac) == 0)) or
                // SMA
                (bitTest(self.mb, 8) and (getSign(self.ac) == 1)) or
                // SZO
                (bitTest(self.mb, 9) and (self.ov == 0)) or
                // SPI
                (bitTest(self.mb, 10) and (getSign(self.io) == 0)) or
                // SZS
                ((v > 0) and ((self.ss & fs_test[v]) == 0)) or
                // SZF
                ((t > 0) and ((self.pf & fs_test[t]) == 0));

            if (Instruction.ib(self.mb) == 1) {
                skip = !skip;
            }
            if (skip) {
                self.pc +%= 1;
            }
            if (bitTest(self.mb, 9)) {
                self.ov = 0; // SZO clears OV
            }
        },
        .SFT => {
            const sc = shift_count[self.mb & 0o0777];
            switch ((self.mb >> 9) & 0o017) {
                0o001 => { // RAL
                    self.ac = (self.ac << sc) | (self.ac >> (18 - sc));
                },
                0o002 => { // RIL
                    self.io = (self.io << sc) | (self.io >> (18 - sc));
                },
                0o003 => { // RCL
                    const t = self.ac;
                    self.ac = (self.ac << sc) | (self.io >> (18 - sc));
                    self.io = (self.io << sc) | (t >> (18 - sc));
                },
                0o005 => { // SAL
                    const t: u18 = if (getSign(self.ac) == 1) 0o777777 else 0;
                    self.ac = (self.ac & 0o400000) | ((self.ac << sc) & 0o377777) | (t >> (18 - sc));
                },
                0o006 => { // SIL
                    const t: u18 = if (getSign(self.io) == 1) 0o777777 else 0;
                    self.io = (self.io & 0o400000) | ((self.io << sc) & 0o377777) | (t >> (18 - sc));
                },
                0o007 => { // SCL
                    const t: u18 = if (getSign(self.ac) == 1) 0o777777 else 0;
                    self.ac = (self.ac & 0o400000) | ((self.ac << sc) & 0o377777) | (self.io >> (18 - sc));
                    self.io = (self.io << sc) | (t >> (18 - sc));
                },
                0o011 => { // RAR
                    self.ac = (self.ac >> sc) | (self.ac << (18 - sc));
                },
                0o012 => { // RIR
                    self.io = (self.io >> sc) | (self.io << (18 - sc));
                },
                0o013 => { // RCR
                    const t = self.io;
                    self.io = (self.io >> sc) | (self.ac << (18 - sc));
                    self.ac = (self.ac >> sc) | (t << (18 - sc));
                },
                0o015 => { // SAR
                    const t: u18 = if (getSign(self.ac) == 1) 0o777777 else 0;
                    self.ac = (self.ac >> sc) | (t << (18 - sc));
                },
                0o016 => { // SIR
                    const t: u18 = if (getSign(self.io) == 1) 0o777777 else 0;
                    self.io = (self.io >> sc) | (t << (18 - sc));
                },
                0o017 => { // SCR
                    const t: u18 = if (getSign(self.ac) == 1) 0o777777 else 0;
                    self.io = (self.io >> sc) | (self.ac << (18 - sc));
                    self.ac = (self.ac >> sc) | (t << (18 - sc));
                },
                else => {
                    JS.Console.logError("unrecognized SFT 0o{o:0>4} at 0o{o:0>4}\n", .{ self.mb, self.pc -% 1 });
                },
            }
        },
        .LAW => {
            // The number in the memory address bits of the instruction word is
            // placed in the Accumulator. If the indirect address bit is ONE,
            // (-N) is put in the Accumulator.
            if (Instruction.ib(self.mb) == 1) {
                self.ac = ~(self.mb & 0o007777);
            } else {
                self.ac = self.mb & 0o007777;
            }
        },
        .IOT => {
            const dev = self.mb & 0o77; // get dev addr
            switch (dev) {
                0o00 => {
                    // I/O wait
                },
                0o07 => {
                    self.dpy();
                },
                0o11 => {
                    self.io = self.control;
                },
                else => {
                    JS.Console.logError("unrecognized IOT 0o{o:0>2} at 0o{o:0>4}\n", .{ dev, self.pc -% 1 });
                },
            }
        },
        .OPR => {
            // TODO: verify order of microinstructions

            if (bitTest(self.mb, 11)) {
                // CLI
                self.io = 0;
            }
            if (bitTest(self.mb, 7)) {
                // CLA
                self.ac = 0;
            }
            if (bitTest(self.mb, 10)) {
                // LAT
                self.ac |= self.tws;
            }
            if (bitTest(self.mb, 6)) {
                // LAP
                self.ac = (@as(u18, self.ov) << 17) | self.pc;
            }
            if (bitTest(self.mb, 9)) {
                // CMA
                self.ac = ~self.ac;
            }
            if (bitTest(self.mb, 3)) {
                // STF
                self.pf |= fs_test[self.mb & 0o07];
            } else {
                // CLF
                self.pf &= ~fs_test[self.mb & 0o07];
            }
            if (bitTest(self.mb, 8)) {
                // HLT
                self.run = false;
            }
        },
        _ => {
            JS.Console.logError("undefined opcode 0o{o:0>2} at 0o{o:04}\n", .{ self.ir, self.pc -% 1 });
        },
    }
}

inline fn getIR(word: u18) u5 {
    return @truncate((word >> 13));
}

fn ea(self: *PDP1) void {
    while (true) {
        self.ma = Instruction.y(self.mb);
        if (Instruction.ib(self.mb) == 0) {
            return;
        }
        self.read();
    }
}

//-- I/O -----------------------------------------------------------------

fn dpy(self: *PDP1) void {
    const width: f32 = @floatFromInt(screen_width);
    const height: f32 = @floatFromInt(screen_height);

    // (a + 0o400000) / 0o777777 puts `a` in the 0..1 range
    const x_normal = @as(f32, @floatFromInt(self.ac +% 0o400000)) / @as(f32, 0o777777);
    const y_normal = @as(f32, @floatFromInt(self.io +% 0o400000)) / @as(f32, 0o777777);

    const x = x_normal * width;
    const y = y_normal * height;
    JS.Screen.point(x, y);
}

fn getKeyMask(key: u8) ?u18 {
    return switch (key) {
        // 1st player
        'w' => 0o000001,
        's' => 0o000002,
        'a' => 0o000004,
        'd' => 0o000010,
        // 2nd player
        'i' => 0o040000,
        'k' => 0o100000,
        'j' => 0o200000,
        'l' => 0o400000,
        else => null,
    };
}

pub fn handleKeyDown(self: *PDP1, key: u8) void {
    if (getKeyMask(key)) |mask| {
        self.control |= mask;
    }
}

pub fn handleKeyUp(self: *PDP1, key: u8) void {
    if (getKeyMask(key)) |mask| {
        self.control &= ~mask;
    }
}

//-- debugging -----------------------------------------------------------------

pub fn debugState(self: *PDP1) void {
    JS.Console.log("steps: {} | ir: {o:0>2} | pc: {o:0>4} | ov: {} | ac: {o:0>6} | io: {o:0>6} | ma: {o:0>4} | mb: {o:0>6}\n", .{
        self.steps,
        self.ir,
        self.pc,
        self.ov,
        self.ac,
        self.io,
        self.ma,
        self.mb,
    });
}

//-- utilities -----------------------------------------------------------------

inline fn sameSign(a: u18, b: u18) bool {
    return getSign(a) == getSign(b);
}

inline fn getSign(word: u18) u18 {
    return bitGet(word, 17);
}

inline fn bitTest(word: u18, b: u5) bool {
    return bitGet(word, b) == 1;
}

inline fn bitGet(word: u18, b: u5) u1 {
    std.debug.assert(b <= 17);
    return @truncate((word >> b) & 1);
}
