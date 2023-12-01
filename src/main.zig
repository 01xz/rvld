const std = @import("std");
const elf = @import("elf.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    for (args, 0..) |arg, i| {
        std.debug.print("arg {d}: {s}\n", .{ i, arg });
    }

    // try to open a file
    var file = try std.fs.cwd().openFile(args[1], .{});
    defer file.close();

    const ElfHeaderSize = @sizeOf(elf.ElfHeader);

    var buffer: [ElfHeaderSize]u8 = undefined;

    if (try file.read(&buffer) != ElfHeaderSize) {
        return error.FileTooSmall;
    }

    if (!std.mem.eql(u8, buffer[0..elf.ELFMAG.len], elf.ELFMAG)) {
        return error.BadElfFile;
    }

    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // stdout is for the actual output of your application, for example if you
    // are implementing gzip, then only the compressed bytes should be sent to
    // stdout, not any debugging messages.
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    try stdout.print("Run `zig build test` to run the tests.\n", .{});

    try bw.flush(); // don't forget to flush!
}

test "simple test" {
    var list = std.ArrayList(i32).init(std.testing.allocator);
    defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
    try list.append(42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}
