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
    defer input_file.deinit();

    for (input_file.shdrs, 0..) |*sh_ptr, i| {
        std.debug.print("section header {d} name is {d}\n", .{ i, sh_ptr.sh_name });
    }

    std.debug.print("shstrtab: {s}\n", .{input_file.shstrtab});

    try input_file.parse();
    defer input_file.parseClean();

    for (input_file.syms, 0..) |*sym_ptr, i| {
        std.debug.print("symbol {d} name is {d}\n", .{ i, sym_ptr.st_name });
    }

    std.debug.print("symstrtab: {s}\n", .{input_file.symstrtab});
}
