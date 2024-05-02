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

pub fn main() !void {
    var _gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const gpa = _gpa.allocator();
    const args = try std.process.argsAlloc(gpa);
    defer std.process.argsFree(gpa, args);

    const print = std.fs.File.Writer.print;
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    for (args[1..]) |arg| {
        (switch (arg[0]) {
            'A', 'a' => if (av2bv(arg)) |bvid|
                print(stdout, "{s} = {s}\n", .{ bvid, arg })
            else |err|
                err,
            'B', 'b' => if (BV.decode(arg)) |aid|
                print(stdout, "av{d} = {s}\n", .{ aid, arg })
            else |err|
                err,
            else => Error.InvalidInput,
        }) catch |err| {
            try switch (err) {
                Error.InvalidInput => print(stderr, "InvalidInput : {s}\n", .{arg}),
                Error.TooBig => print(stderr, "TooBig : {s}\n", .{arg}),
                else => err,
            };
        };
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
    const Pack = struct {
        aid: u64,
        bvid: []const u8,
    };
    const mem = std.mem;
    const expect = std.testing.expect;
    const eq = std.testing.expectEqual;

    const list = [_]Pack{
        .{ .aid = 1, .bvid = "BV1xx411c7mQ" },
        .{ .aid = 2, .bvid = "BV1xx411c7mD" },
        .{ .aid = 3, .bvid = "BV1xx411c7mS" },
        .{ .aid = 1786632398213095, .bvid = "BV1xxxxxxav1" },
        .{ .aid = 2245227794580184, .bvid = "BV1TypScript" },
        .{ .aid = 2251799813685247, .bvid = "BV1aPPTfmvQq" },

        .{ .aid = 170001, .bvid = "BV17x411w7KC" },
        .{ .aid = 11451419180, .bvid = "BV1gA4v1m7BV" },
        .{ .aid = 1145141919810, .bvid = "BV1B8Ziyo7s2" },
    };
    for (list) |pack| {
        try expect(mem.eql(u8, &try BV.encode(pack.aid), pack.bvid));
        try eq(try BV.decode(pack.bvid), pack.aid);
    }
}
