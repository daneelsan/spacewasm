pub inline fn add(comptime T: type, a: T, b: T) T {
    var result: T = undefined;
    const carry_bit = @boolToInt(@addWithOverflow(T, a, b, &result));
    result += carry_bit;
    return result;
}

pub inline fn sub(comptime T: type, a: T, b: T) T {
    return add(T, a, ~b);
}

pub inline fn sign(comptime T: type, x: T) T {
    comptime var sign_shift = @typeInfo(T).Int.bits - 1;
    return (x >> sign_shift);
}
