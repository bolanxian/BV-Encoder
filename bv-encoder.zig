const std = @import("std");

const BASE: u64 = 58;
const MAX: u64 = 1 << 51;
const XOR: u64 = 0x1552356C4CDB;
const table: [58]u8 = "FcwAPNKTMug3GV5Lj7EJnHpWsx4tb8haYeviqBz6rkCy12mUSDQX9RdoZf".*;
const tr: [128]i8 = blk: {
    var _tr = [_]i8{-1} ** 128;
    for (table, 0..) |value, i| {
        _tr[value] = i;
    }
    break :blk _tr;
};

pub const Error = error{
    InvalidInput,
    TooBig,
};

pub fn encode(aid: u64) ![12]u8 {
    if (aid >= MAX) {
        return Error.TooBig;
    }
    var tmp: u64 = (aid | MAX) ^ XOR;
    var x: [9]u8 = "000000000".*;
    for (&x) |*p| {
        p.* = table[tmp % BASE];
        tmp /= BASE;
    }
    if (tmp > 0) {
        unreachable;
    }
    return [12]u8{ 'B', 'V', '1', x[2], x[4], x[6], x[5], x[7], x[3], x[8], x[1], x[0] };
}

pub fn decode(x: []const u8) !u64 {
    try if (x.len != 12)
        Error.InvalidInput;
    try switch (x[0]) {
        'B', 'b' => {},
        else => Error.InvalidInput,
    };
    try switch (x[1]) {
        'V', 'v' => {},
        else => Error.InvalidInput,
    };
    try if (x[2] != '1')
        Error.InvalidInput;

    var tmp: u64 = 0;
    for ([_]u8{ x[9], x[7], x[5], x[6], x[4], x[8], x[3], x[10], x[11] }) |y| {
        try if (y > 127)
            Error.InvalidInput;
        const i = tr[y];
        try if (i < 0)
            Error.InvalidInput;
        tmp = tmp * BASE + @as(u8, @bitCast(i));
    }
    if (tmp >> 51 == 1) {
        const aid = (tmp & (MAX - 1)) ^ XOR;
        return aid;
    }
    return Error.InvalidInput;
}
