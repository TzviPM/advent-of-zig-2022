const std = @import("std");

// TODO: define input and output types
const TInput = u8;
const TResult = u8;

// TODO: define processing logic
fn run(input: TInput) TResult {
    return input;
}

/// This is the program entry point. The intention is to
/// process I/O here and delegate to `run`.
pub fn main() void {
    const stdin = std.io.getStdIn().reader();
    var buffer: [8]u8 = undefined;

    // initialize input
    var input = 0;

    while (try stdin.readUntilDelimiterOrEof(&buffer, '\n')) |value| {
        // We trim the line's contents to remove any trailing '\r' chars
        const line = std.mem.trimRight(u8, value[0..], "\r");

        if (line.len == 0) {
            continue;
        }

        // TODO: Process line
        input += 1;
    }

    run(input);
}

test "sample input" {
    const expect = std.testing.expect;

    const sampleInput: TInput = 0;
    const expectedResult: TResult = 0;

    const actualResult: TResult = run(sampleInput);

    try expect(actualResult == expectedResult);
}
