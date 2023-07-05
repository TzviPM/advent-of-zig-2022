const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

fn TInput(comptime A: Allocator) type {
    return ArrayList(Rucksack(A));
}
const TResult = u32;

const String = []const u8;
const RucksackError = error{ UnbalancedRucksack, InvalidRucksack, InvalidType };

fn run(comptime A: Allocator, input: TInput(A)) RucksackError!TResult {
    std.log.debug("The priority of the item type that appears in both compartments of each rucksack is:", .{});
    var result: TResult = 0;
    for (input.items) |rs| {
        const common = try rs.getCommon();
        const priority = try getPriority(common);
        std.log.debug("{d} ({c})", .{ priority, common });
        result += priority;
    }
    std.log.debug("The sum of these is {d}.", .{result});
    return result;
}

fn getPriority(ch: u8) RucksackError!u8 {
    if (ch >= 'a' and ch <= 'z') {
        return (ch - 'a') + 1;
    }
    if (ch >= 'A' and ch <= 'Z') {
        return (ch - 'A') + 27;
    }
    return RucksackError.InvalidType;
}

const PrioritySet = struct {
    bits: u52,

    const Self = @This();

    fn new() Self {
        return Self{
            .bits = 0,
        };
    }

    fn hash(ch: u8) !u52 {
        const priority = try getPriority(ch);
        return @as(u52, 1) << @truncate(u6, priority - 1);
    }

    fn add(self: *Self, ch: u8) !void {
        self.bits |= try hash(ch);
    }

    fn has(self: Self, ch: u8) !bool {
        return (self.bits & try hash(ch)) != 0;
    }
};

fn Rucksack(comptime allocator: Allocator) type {
    return struct {
        mem: []u8,
        c1: String,
        c2: String,

        const Self = @This();

        fn init(string: String) !Self {
            if (string.len % 2 != 0) {
                return RucksackError.UnbalancedRucksack;
            }
            const length = string.len / 2;

            var rs: Self = undefined;

            rs.mem = try allocator.alloc(u8, string.len);
            std.mem.copy(u8, rs.mem, string);

            rs.c1 = rs.mem[0..length];
            rs.c2 = rs.mem[length..];

            return rs;
        }

        fn deinit(self: Self) void {
            allocator.free(self.mem);
        }

        fn getCommon(self: Self) RucksackError!u8 {
            var ps = PrioritySet.new();
            for (self.c1) |ch| {
                try ps.add(ch);
            }
            return for (self.c2) |ch| {
                if (try ps.has(ch)) {
                    break ch;
                }
            } else RucksackError.InvalidRucksack;
        }

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            try writer.print("| {s} | {s} |", .{ self.c1, self.c2 });
        }
    };
}

/// This is the program entry point. The intention is to
/// process I/O here and delegate to `run`.
pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    var buffer: [128]u8 = undefined;

    const HeapRucksack = Rucksack(std.heap.page_allocator);

    // initialize input
    var input = ArrayList(HeapRucksack).init(std.heap.page_allocator);
    defer input.deinit();
    defer for (input.items) |rs| {
        rs.deinit();
    };

    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |value| {
        // We trim the line's contents to remove any trailing '\r' chars
        const line = std.mem.trimRight(u8, value[0..], "\r");

        if (line.len == 0) {
            continue;
        }

        // Process line
        const rs = try HeapRucksack.init(line);
        try input.append(rs);
    }

    std.log.debug("Input received:", .{});
    for (input.items) |rs| {
        std.log.debug("{s}", .{rs});
    }

    const result = try run(std.heap.page_allocator, input);
    std.log.info("The sum of all priorities is {d}", .{result});
}

test "sample input" {
    const expect = std.testing.expect;
    const eql = std.mem.eql;

    const TestRucksack = Rucksack(std.testing.allocator);

    var sampleInput: TInput(std.testing.allocator) = ArrayList(TestRucksack).init(std.testing.allocator);
    defer sampleInput.deinit();
    defer for (sampleInput.items) |rs| {
        rs.deinit();
    };

    const rs1 = try TestRucksack.init("vJrwpWtwJgWrhcsFMMfFFhFp");
    try expect(eql(u8, rs1.c1, "vJrwpWtwJgWr"));
    try expect(eql(u8, rs1.c2, "hcsFMMfFFhFp"));
    try sampleInput.append(rs1);

    const rs2 = try TestRucksack.init("jqHRNqRjqzjGDLGLrsFMfFZSrLrFZsSL");
    try sampleInput.append(rs2);

    const rs3 = try TestRucksack.init("PmmdzqPrVvPwwTWBwg");
    try sampleInput.append(rs3);

    const rs4 = try TestRucksack.init("wMqvLMZHhHMvwLHjbvcjnnSBnvTQFn");
    try sampleInput.append(rs4);

    const rs5 = try TestRucksack.init("ttgJtRGJQctTZtZT");
    try sampleInput.append(rs5);

    const rs6 = try TestRucksack.init("CrZsJsPPZsGzwwsLwLmpwMDw");
    try sampleInput.append(rs6);

    const expectedResult: TResult = 157;

    const actualResult: TResult = try run(sampleInput);

    try expect(actualResult == expectedResult);
}
