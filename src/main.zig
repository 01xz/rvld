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

    // try to open a file, read only as default
    var file = try std.fs.cwd().openFile(args[1], .{});
    defer file.close();

    const elf_header_size = @sizeOf(elf.ElfHeader);

    var elf_header_buffer: [elf_header_size]u8 = undefined;

    if (try file.read(&elf_header_buffer) != elf_header_size) {
        return error.FileTooSmall;
    }

    if (!std.mem.eql(u8, elf_header_buffer[0..elf.ELFMAG.len], elf.ELFMAG)) {
        return error.BadElfFile;
    }

    const elf_header = std.mem.bytesAsValue(elf.ElfHeader, &elf_header_buffer);

    if (elf_header.e_machine != elf.EM_RISCV or elf_header.e_ident[elf.EI_CLASS] != elf.ELFCLASS64) {
        return error.NotRV64;
    }

    try file.seekTo(elf_header.e_shoff);

    const section_header_size = @sizeOf(elf.ElfSectionHeader);

    var section_header_buffer: [section_header_size]u8 = undefined;

    if (try file.read(&section_header_buffer) != section_header_size) {
        return error.FileTooSmall;
    }

    const section_header_ptr = std.mem.bytesAsValue(elf.ElfSectionHeader, &section_header_buffer);

    const section_num = if (elf_header.e_shnum == 0) section_header_ptr.sh_size else elf_header.e_shnum;

    // std.debug.print("the section number is {d}\n", .{section_num});

    var section_headers = try std.heap.page_allocator.alloc(elf.ElfSectionHeader, section_num);
    defer std.heap.page_allocator.free(section_headers);

    for (section_headers, 0..) |*sh_ptr, i| {
        if (i == 0) {
            sh_ptr.* = section_header_ptr.*;
        } else {
            var buffer: [section_header_size]u8 = undefined;
            if (try file.read(&buffer) != section_header_size) {
                return error.FileTooSmall;
            }
            sh_ptr.* = std.mem.bytesToValue(elf.ElfSectionHeader, &buffer);
        }
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
