const std = @import("std");
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

const GroupSize = 3;

fn TInput(comptime A: Allocator) type {
    return ArrayList(ElfGroup(A, GroupSize));
}
const TResult = u32;

const String = []const u8;
const RucksackError = error{ UnbalancedRucksack, InvalidRucksack, InvalidType, InvalidElfGroup };

fn run(comptime A: Allocator, input: TInput(A)) RucksackError!TResult {
    std.log.debug("The only item type that appears in all three rucksacks is:", .{});
    var result: TResult = 0;
    for (input.items) |eg, i| {
        const common = try eg.getBadge();
        const priority = try getPriority(common);
        std.log.debug("{d} ({c}) for group {d}", .{ priority, common, i + 1 });
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

    fn intersection(self: Self, other: Self) Self {
        return Self{ .bits = self.bits & other.bits };
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

    pub fn format(
        self: Self,
        comptime fmt: []const u8,
        options: std.fmt.FormatOptions,
        writer: anytype,
    ) !void {
        _ = fmt;
        _ = options;

        try writer.writeAll("{");
        var ch: u8 = 'a';
        while (ch <= 'z') : (ch += 1) {
            if (self.has(ch) catch false) {
                try writer.print("{c},", .{ch});
            }
        }
        ch = 'A';
        while (ch <= 'Z') : (ch += 1) {
            if (self.has(ch) catch false) {
                try writer.print("{c},", .{ch});
            }
        }
        try writer.writeAll("}");
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

fn ElfGroup(comptime A: Allocator, comptime N: usize) type {
    return struct {
        const TRuckSack = Rucksack(A);
        rucksacks: []TRuckSack,

        const Self = @This();

        fn init(rucksacks: [N]TRuckSack) !Self {
            var group: Self = undefined;
            group.rucksacks = try A.alloc(TRuckSack, N);
            std.mem.copy(TRuckSack, group.rucksacks, &rucksacks);
            return group;
        }

        fn deinit(self: Self) void {
            for (self.rucksacks) |rs| {
                rs.deinit();
            }
            A.free(self.rucksacks);
        }

        fn getBadge(self: Self) RucksackError!u8 {
            var groupPs = PrioritySet.new();
            for (self.rucksacks[0].mem) |ch| {
                try groupPs.add(ch);
            }
            for (self.rucksacks[1 .. N - 1]) |rs| {
                var elfPs = PrioritySet.new();
                for (rs.mem) |ch| {
                    try elfPs.add(ch);
                }
                groupPs = groupPs.intersection(elfPs);
            }
            return for (self.rucksacks[N - 1].mem) |ch| {
                if (try groupPs.has(ch)) {
                    break ch;
                }
            } else {
                std.log.err("Invalid Elf Group: {s} ({s})", .{ self, groupPs });
                return RucksackError.InvalidElfGroup;
            };
        }

        pub fn format(
            self: Self,
            comptime fmt: []const u8,
            options: std.fmt.FormatOptions,
            writer: anytype,
        ) !void {
            _ = fmt;
            _ = options;

            try writer.writeAll("---\n");
            for (self.rucksacks) |rs| {
                try writer.print("{s}\n", .{rs});
            }
            try writer.writeAll("---");
        }
    };
}

/// This is the program entry point. The intention is to
/// process I/O here and delegate to `run`.
pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    var buffer: [128]u8 = undefined;

    const HeapRucksack = Rucksack(std.heap.page_allocator);
    const HeapElfGroup = ElfGroup(std.heap.page_allocator, GroupSize);

    // initialize input
    var input = ArrayList(HeapElfGroup).init(std.heap.page_allocator);
    defer input.deinit();
    defer for (input.items) |rs| {
        rs.deinit();
    };

    var group: [GroupSize]HeapRucksack = undefined;
    var lineNum: usize = 0;

    errdefer for (group) |rs, i| {
        if (i < lineNum) {
            rs.deinit();
        } else {
            break;
        }
    };

    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |value| {
        // We trim the line's contents to remove any trailing '\r' chars
        const line = std.mem.trimRight(u8, value[0..], "\r");

        if (line.len == 0) {
            continue;
        }

        // Process line
        const rs = try HeapRucksack.init(line);
        group[lineNum] = rs;

        lineNum += 1;
        lineNum %= GroupSize;

        if (lineNum == 0) {
            const elfGroup = try HeapElfGroup.init(group);
            try input.append(elfGroup);
        }
    }

    std.log.debug("Input received:", .{});
    for (input.items) |eg| {
        std.log.debug("{s}", .{eg});
    }

    const result = try run(std.heap.page_allocator, input);
    std.log.info("The sum of all priorities is {d}", .{result});
}

test "sample input" {
    const expect = std.testing.expect;
    const eql = std.mem.eql;

    const TestRucksack = Rucksack(std.testing.allocator);
    const TestElfGroup = ElfGroup(std.testing.allocator, 3);

    var sampleInput: TInput(std.testing.allocator) = ArrayList(TestElfGroup).init(std.testing.allocator);
    defer sampleInput.deinit();
    defer for (sampleInput.items) |eg| {
        eg.deinit();
    };

    const rs1 = try TestRucksack.init("vJrwpWtwJgWrhcsFMMfFFhFp");
    try expect(eql(u8, rs1.c1, "vJrwpWtwJgWr"));
    try expect(eql(u8, rs1.c2, "hcsFMMfFFhFp"));

    const rs2 = try TestRucksack.init("jqHRNqRjqzjGDLGLrsFMfFZSrLrFZsSL");
    const rs3 = try TestRucksack.init("PmmdzqPrVvPwwTWBwg");

    const slice1: [3]TestRucksack = .{ rs1, rs2, rs3 };
    const eg1 = try TestElfGroup.init(slice1);
    try sampleInput.append(eg1);

    const rs4 = try TestRucksack.init("wMqvLMZHhHMvwLHjbvcjnnSBnvTQFn");
    const rs5 = try TestRucksack.init("ttgJtRGJQctTZtZT");
    const rs6 = try TestRucksack.init("CrZsJsPPZsGzwwsLwLmpwMDw");

    const slice2: [3]TestRucksack = .{ rs4, rs5, rs6 };
    const eg2 = try TestElfGroup.init(slice2);
    try sampleInput.append(eg2);

    const expectedResult: TResult = 70;

    const actualResult: TResult = try run(std.testing.allocator, sampleInput);

    try expect(actualResult == expectedResult);
}
