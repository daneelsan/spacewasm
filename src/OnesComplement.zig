pub inline fn add(comptime T: type, a: T, b: T) T {
    const ov = @addWithOverflow(a, b);
    return ov[0] + ov[1];
}

pub inline fn sub(comptime T: type, a: T, b: T) T {
    return add(T, a, ~b);
}

pub inline fn sign(comptime T: type, x: T) T {
    const sign_shift = @typeInfo(T).int.bits - 1;
    return (x >> sign_shift);
}
