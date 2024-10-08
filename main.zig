const std = @import("std");
const BV = @import("bv-encoder.zig");
const Error = BV.Error;

pub fn av2bv(arg: []const u8) ![12]u8 {
    try if (arg.len < 3 or arg.len > 18)
        Error.InvalidInput;
    try switch (arg[0]) {
        'A', 'a' => {},
        else => Error.InvalidInput,
    };
    try switch (arg[1]) {
        'V', 'v' => {},
        else => Error.InvalidInput,
    };
    try if (arg[2] == '0' and arg.len != 3)
        Error.InvalidInput;

    var aid: u64 = 0;
    for (arg[2..]) |value| {
        aid = aid * 10 + try switch (value) {
            '0'...'9' => value - '0',
            else => Error.InvalidInput,
        };
    }
    return BV.encode(aid);
}

pub fn @"test"(comptime @"type": comptime_int) struct { u64, u64 } {
    var min: u64 = 0;
    var max: u64 = (1 << 51) - 1;
    while (max - min > 1) {
        const new = @divFloor(min + max, 2);
        const encoded = BV.encode(new) catch unreachable;
        (if (switch (@"type") {
            1 => encoded[5] == '4',
            2 => encoded[7] == '1',
            3 => encoded[9] == '7',
            else => @compileError("unreachable"),
        }) &min else &max).* = new;
    }
    return .{ min, max };
}
pub fn @"~"(writer: anytype, arg: []const u8) !void {
    switch (arg[0]) {
        'A', 'a' => try writer.print("{s} = {s}\n", .{ try av2bv(arg), arg }),
        'B', 'b' => try writer.print("av{d} = {s}\n", .{ try BV.decode(arg), arg }),
        '-' => if (arg.len == 1) {
            inline for (1..4) |i| {
                inline for (.{ "min", "max" }, @"test"(i)) |pre, val| {
                    try writer.print("{s} : av{d} = {s}\n", .{ pre, val, BV.encode(val) catch unreachable });
                }
            }
        } else {
            return Error.InvalidInput;
        },
        else => return Error.InvalidInput,
    }
}

pub fn main() !void {
    var _gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = _gpa.allocator();
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var errorList = std.ArrayList(anyerror).init(gpa);
    defer errorList.deinit();

    for (args[1..]) |arg| {
        @"~"(
            stdout,
            arg,
        ) catch |@"error"| switch (@"error") {
            inline Error.InvalidInput, Error.TooBig => |err| {
                try stderr.print("{s} : {s}\n", .{ @errorName(err), arg });
            },
            else => |err| try errorList.append(err),
        };
    }
    for (errorList.items) |err| {
        return err;
    }
}

test "!" {
    const eq = std.testing.expectEqual;

    try eq(av2bv("av01"), Error.InvalidInput);
    try eq(av2bv("av" ++ "9" ** 18), Error.InvalidInput);
    try eq(BV.encode(2251799813685248), Error.TooBig);
    try eq(BV.decode("BV1B8ZiyO7s2"), Error.InvalidInput);
}

test "convert" {
    const Pack = struct { u64, []const u8 };
    const mem = std.mem;
    const expect = std.testing.expect;
    const eq = std.testing.expectEqual;

    const list = [_]Pack{
        .{ 1, "BV1xx411c7mQ" },
        .{ 2, "BV1xx411c7mD" },
        .{ 3, "BV1xx411c7mS" },

        .{ 137438953471, "BV16h4L1b7Bz" },
        .{ 137438953472, "BV1FShH1w7Hk" },
        .{ 2199023255551, "BV1QaMG1x7Uh" },
        .{ 2199023255552, "BV1s24h2g7QT" },
        .{ 70368744177663, "BV1rHNqoM7xg" },
        .{ 70368744177664, "BV1RaJVEZEvi" },

        .{ 1786632398213095, "BV1xxxxxxav1" },
        .{ 2245227794580184, "BV1TypScript" },
        .{ 2251799813685247, "BV1aPPTfmvQq" },

        .{ 170001, "BV17x411w7KC" },
        .{ 11451419180, "BV1gA4v1m7BV" },
        .{ 1145141919810, "BV1B8Ziyo7s2" },
    };
    for (list) |pack| {
        try expect(mem.eql(u8, &try BV.encode(pack.@"0"), pack.@"1"));
        try eq(try BV.decode(pack.@"1"), pack.@"0");
    }
}
