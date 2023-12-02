const std = @import("std");
const elf = @import("elf.zig");

const InputFile = @This();
const File = std.fs.File;
const Allocator = std.mem.Allocator;

file: *File,
section_headers: []elf.SectionHeader,

pub fn init(file: *File, allocator: Allocator) !InputFile {
    const elf_header_size = @sizeOf(elf.ElfHeader);

    var elf_header_buffer: [elf_header_size]u8 = undefined;

    if (try file.read(&elf_header_buffer) != elf_header_size) {
        return error.FileTooSmall;
    }

    if (!std.mem.eql(u8, elf_header_buffer[0..elf.ELFMAG.len], elf.ELFMAG)) {
        return error.BadElfFile;
    }

    const elf_header_ptr = std.mem.bytesAsValue(elf.ElfHeader, &elf_header_buffer);

    if (elf_header_ptr.e_machine != elf.EM_RISCV or elf_header_ptr.e_ident[elf.EI_CLASS] != elf.ELFCLASS64) {
        return error.NotRV64;
    }

    try file.seekTo(elf_header_ptr.e_shoff);

    const section_header_size = @sizeOf(elf.SectionHeader);

    var section_header_buffer: [section_header_size]u8 = undefined;

    if (try file.read(&section_header_buffer) != section_header_size) {
        return error.FileTooSmall;
    }

    const section_header_ptr = std.mem.bytesAsValue(elf.SectionHeader, &section_header_buffer);

    const section_num = if (elf_header_ptr.e_shnum == 0) section_header_ptr.sh_size else elf_header_ptr.e_shnum;

    var section_headers = try allocator.alloc(elf.SectionHeader, section_num);

    for (section_headers, 0..) |*sh_ptr, i| {
        if (i == 0) {
            sh_ptr.* = section_header_ptr.*;
        } else {
            var buffer: [section_header_size]u8 = undefined;
            if (try file.read(&buffer) != section_header_size) {
                return error.FileTooSmall;
            }
            sh_ptr.* = std.mem.bytesToValue(elf.SectionHeader, &buffer);
        }
    }

    return .{
        .file = file,
        .section_headers = section_headers,
    };
}

pub fn deinit(self: *InputFile, allocator: Allocator) void {
    allocator.free(self.section_headers);
}
