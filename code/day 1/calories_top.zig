const std = @import("std");
const expect = std.testing.expect;

const TNum = u32;

fn MaxCalories(comptime N: usize) type {
    return struct {
        data: [N]TNum,
        const Self = @This();

        fn init() Self {
            var data: [N]TNum = undefined;

            for (data) |_, i| {
                data[i] = 0;
            }

            return Self{
                .data = data,
            };
        }

        fn track(self: *Self, datum: TNum) void {
            var ins: bool = false;
            var tmp: TNum = undefined;
            for (self.data) |*val| {
                if (ins) {
                    const t = val.*;
                    val.* = tmp;
                    tmp = t;
                } else if (datum > val.*) {
                    ins = true;
                    tmp = val.*;
                    val.* = datum;
                }
            }
        }

        fn sum(self: Self) TNum {
            var total: TNum = 0;
            for (self.data) |val| {
                total += val;
            }
            return total;
        }
    };
}

fn calculate_calories(input: [][]TNum) TNum {
    var max_calories = MaxCalories(3).init();
    for (input) |elf_foods| {
        var calories: TNum = 0;
        for (elf_foods) |food| {
            calories += food;
        }
        max_calories.track(calories);
    }

    return max_calories.sum();
}

pub fn main() !void {
    const stdin = std.io.getStdIn();
    defer stdin.close();

    const ArrayList = std.ArrayList;
    const allocator = std.heap.page_allocator;

    var elves_list = ArrayList([]TNum).init(allocator);
    errdefer {
        for (elves_list.items) |elf_slice| {
            allocator.free(elf_slice);
        }
        elves_list.deinit();
    }

    var buffer: [8]u8 = undefined;
    var reader = stdin.reader();

    var elf_list = ArrayList(TNum).init(allocator);
    errdefer elf_list.deinit();

    while (try reader.readUntilDelimiterOrEof(&buffer, '\n')) |value| {
        // We trim the line's contents to remove any trailing '\r' chars
        const line = std.mem.trimRight(u8, value[0..], "\r");

        if (line.len == 0) {
            try elves_list.append(elf_list.toOwnedSlice());
            elf_list = ArrayList(TNum).init(allocator);
            continue;
        }
        // std.debug.print("Received line: {s}\n", .{line});
        var num = try std.fmt.parseUnsigned(TNum, line, 10);
        try elf_list.append(num);
    }

    if (elf_list.items.len > 0) {
        try elves_list.append(elf_list.toOwnedSlice());
    }

    const elves_slice = elves_list.toOwnedSlice();
    defer {
        for (elves_slice) |elf_slice| {
            allocator.free(elf_slice);
        }
        allocator.free(elves_slice);
    }

    var result = calculate_calories(elves_slice);

    std.debug.print("The elf with the most food is carrying {d} calories.", .{result});
}

test "Sample input" {
    const ArrayList = std.ArrayList;
    const test_allocator = std.testing.allocator;

    var list = ArrayList([]TNum).init(test_allocator);
    // defer list.deinit();

    var elf1 = ArrayList(TNum).init(test_allocator);
    // defer elf1.deinit();
    try elf1.append(1000);
    try elf1.append(2000);
    try elf1.append(3000);
    var slice1 = elf1.toOwnedSlice();
    defer test_allocator.free(slice1);
    try list.append(slice1);

    var elf2 = ArrayList(TNum).init(test_allocator);
    // defer elf2.deinit();
    try elf2.append(4000);
    var slice2 = elf2.toOwnedSlice();
    defer test_allocator.free(slice2);
    try list.append(slice2);

    var elf3 = ArrayList(TNum).init(test_allocator);
    // defer elf3.deinit();
    try elf3.append(5000);
    var slice3 = elf3.toOwnedSlice();
    defer test_allocator.free(slice3);
    try list.append(slice3);

    var elf4 = ArrayList(TNum).init(test_allocator);
    // defer elf4.deinit();
    try elf4.append(6000);
    var slice4 = elf4.toOwnedSlice();
    defer test_allocator.free(slice4);
    try list.append(slice4);

    var elf5 = ArrayList(TNum).init(test_allocator);
    // defer elf5.deinit();
    try elf5.append(7000);
    try elf5.append(8000);
    try elf5.append(9000);
    var slice5 = elf5.toOwnedSlice();
    defer test_allocator.free(slice5);
    try list.append(slice5);

    var elf6 = ArrayList(TNum).init(test_allocator);
    // defer elf6.deinit();
    try elf6.append(10_000);
    var slice6 = elf6.toOwnedSlice();
    defer test_allocator.free(slice6);
    try list.append(slice6);

    var elves_slice = list.toOwnedSlice();
    defer test_allocator.free(elves_slice);

    try expect(calculate_calories(elves_slice) == 24000);
}
