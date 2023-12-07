const std = @import("std");

const Context = @import("Context.zig");
const Inputfile = @import("InputFile.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    var args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    var context = Context.init(allocator);
    defer context.deinit();

    try context.parseArgs(args);

    for (context.context_args.library_paths.items) |path| {
        std.debug.print("library path: {s}\n", .{path});
    }

    for (context.context_args.remained.items) |s| {
        std.debug.print("remained: -l{s}\n", .{s});
    }

    for (context.context_args.remained_file.items) |file| {
        std.debug.print("remained file: {s}\n", .{file});
    }
}
