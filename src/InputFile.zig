const InputFile = @This();

const std = @import("std");
const elf = @import("elf.zig");

const Allocator = std.mem.Allocator;
const File = std.fs.File;
const MappedFile = @import("MappedFile.zig");

mapped_file: MappedFile,
section_headers: []elf.SectionHeader,
shstr_tab: []u8,

pub fn init(path: []const u8, allocator: Allocator) !InputFile {
    const mapped_file = try MappedFile.map(path);

    const elf_header_size = @sizeOf(elf.ElfHeader);
    const section_header_size = @sizeOf(elf.SectionHeader);

    if (mapped_file.size < elf_header_size) {
        return error.FileToolSmall;
    }

    if (!std.mem.eql(u8, mapped_file.data[0..elf.ELFMAG.len], elf.ELFMAG)) {
        return error.BadElfFile;
    }

    const elf_header_ptr = std.mem.bytesAsValue(elf.ElfHeader, mapped_file.data[0..elf_header_size]);

    if (elf_header_ptr.e_machine != elf.EM_RISCV or
        elf_header_ptr.e_ident[elf.EI_CLASS] != elf.ELFCLASS64)
    {
        return error.NotRV64;
    }

    const section_header_begin = std.mem.bytesAsValue(elf.SectionHeader, mapped_file.data[elf_header_ptr.e_shoff..][0..section_header_size]);

    const section_num = if (elf_header_ptr.e_shnum == 0)
        section_header_begin.sh_size
    else
        elf_header_ptr.e_shnum;

    if (mapped_file.size < elf_header_ptr.e_shoff + section_num * section_header_size) {
        return error.CorruptedElfFile;
    }

    var section_headers = try allocator.alloc(elf.SectionHeader, section_num);

    for (section_headers, 0..) |*sh_ptr, i| {
        const sh_offset = elf_header_ptr.e_shoff + i * section_header_size;
        sh_ptr.* = std.mem.bytesToValue(elf.SectionHeader, mapped_file.data[sh_offset..][0..section_header_size]);
    }

    const shstrndx = if (elf_header_ptr.e_shstrndx == std.math.maxInt(@TypeOf(elf_header_ptr.e_shstrndx)))
        section_header_begin.sh_link
    else
        elf_header_ptr.e_shstrndx;

    const shstr_tab_size = section_headers[shstrndx].sh_size;

    var shstr_tab = try allocator.alloc(u8, shstr_tab_size);

    const shstr_tab_begin = section_headers[shstrndx].sh_offset;
    std.mem.copy(u8, shstr_tab, mapped_file.data[shstr_tab_begin..][0..shstr_tab_size]);

    return .{
        .mapped_file = mapped_file,
        .section_headers = section_headers,
        .shstr_tab = shstr_tab,
    };
}

pub fn deinit(self: *InputFile, allocator: Allocator) void {
    allocator.free(self.shstr_tab);
    self.shstr_tab = undefined;

    allocator.free(self.section_headers);
    self.section_headers = undefined;

    self.mapped_file.unmap();
}
