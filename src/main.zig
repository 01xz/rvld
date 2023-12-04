const std = @import("std");
const Inputfile = @import("InputFile.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        return error.IllegalArgs;
    }

    var input_file = try Inputfile.init(args[1], allocator);
    defer input_file.deinit(allocator);

    for (input_file.shdrs, 0..) |*sh_ptr, i| {
        std.debug.print("section header {d} name is {d}\n", .{ i, sh_ptr.sh_name });
    }
}
