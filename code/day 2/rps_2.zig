const std = @import("std");
const ArrayList = std.ArrayList;

const ShapeError = error{InvalidShapeChar};
const OutcomeError = error{InvalidOutcomeChar};

const Shape = enum {
    rock,
    paper,
    scissors,
    const Self = @This();

    fn fromChar(ch: u8) ShapeError!Self {
        return switch (ch) {
            'A' => .rock,
            'B' => .paper,
            'C' => .scissors,
            else => ShapeError.InvalidShapeChar,
        };
    }

    fn score(self: Self) u32 {
        return switch (self) {
            .rock => 1,
            .paper => 2,
            .scissors => 3,
        };
    }

    fn beats(self: Self) Self {
        return switch (self) {
            .rock => .scissors,
            .paper => .rock,
            .scissors => .paper,
        };
    }

    fn beaten(self: Self) Self {
        return switch (self) {
            .rock => .paper,
            .paper => .scissors,
            .scissors => .rock,
        };
    }
};

const Outcome = enum {
    win,
    lose,
    tie,
    const Self = @This();

    fn score(self: Self) u32 {
        return switch (self) {
            .win => 6,
            .lose => 0,
            .tie => 3,
        };
    }

    fn fromChar(ch: u8) OutcomeError!Self {
        return switch (ch) {
            'X' => .lose,
            'Y' => .tie,
            'Z' => .win,
            else => OutcomeError.InvalidOutcomeChar,
        };
    }
};

const Turn = struct {
    them: Shape,
    outcome: Outcome,

    const Self = @This();

    fn me(self: Self) Shape {
        return switch (self.outcome) {
            .win => self.them.beaten(),
            .lose => self.them.beats(),
            .tie => self.them,
        };
    }

    fn score(self: Self) u32 {
        return self.me().score() + self.outcome.score();
    }
};

fn calculate_score(turns: ArrayList(Turn)) u32 {
    var total_score: u32 = 0;

    for (turns.items) |turn| {
        total_score += turn.score();
    }

    return total_score;
}

pub fn main() !void {
    var turns = ArrayList(Turn).init(std.heap.page_allocator);

    const stdin = std.io.getStdIn().reader();
    var buffer: [8]u8 = undefined;

    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |value| {
        // We trim the line's contents to remove any trailing '\r' chars
        const line = std.mem.trimRight(u8, value[0..], "\r");

        if (line.len == 0) {
            continue;
        }

        var turn: Turn = undefined;

        var iter = std.mem.split(u8, line, " ");
        turn.them = try Shape.fromChar(iter.next().?[0]);
        turn.outcome = try Outcome.fromChar(iter.next().?[0]);

        try turns.append(turn);
    }

    const score = calculate_score(turns);

    std.log.info("Total score is: {d}", .{score});
}
