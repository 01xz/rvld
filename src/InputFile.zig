const InputFile = @This();

const std = @import("std");
const elf = std.elf;

const MappedFile = @import("MappedFile.zig");
const Ehdr = elf.Elf64_Ehdr;
const Shdr = elf.Elf64_Shdr;
const Allocator = std.mem.Allocator;

mapped_file: MappedFile,
shdrs: []Shdr,
shstrtab: []u8,

pub fn init(path: []const u8, allocator: Allocator) !InputFile {
    const mapped_file = try MappedFile.map(path);

    const ehdr_size = @sizeOf(Ehdr);
    const shdr_size = @sizeOf(Shdr);

    if (mapped_file.size < ehdr_size) {
        return error.FileToolSmall;
    }

    if (!std.mem.eql(u8, mapped_file.data[0..elf.MAGIC.len], elf.MAGIC)) {
        return error.BadElfFile;
    }

    const ehdr_ptr = std.mem.bytesAsValue(Ehdr, mapped_file.data[0..ehdr_size]);

    if (ehdr_ptr.e_machine != elf.EM.RISCV or
        ehdr_ptr.e_ident[elf.EI_CLASS] != elf.ELFCLASS64)
    {
        return error.NotRV64;
    }

    const shdr_begin = std.mem.bytesAsValue(Shdr, mapped_file.data[ehdr_ptr.e_shoff..][0..shdr_size]);

    const shnum = if (ehdr_ptr.e_shnum == 0)
        shdr_begin.sh_size
    else
        ehdr_ptr.e_shnum;

    if (mapped_file.size < ehdr_ptr.e_shoff + shnum * shdr_size) {
        return error.CorruptedElfFile;
    }

    var shdrs = try allocator.alloc(Shdr, shnum);

    for (shdrs, 0..) |*shdr_ptr, i| {
        const sh_offset = ehdr_ptr.e_shoff + i * shdr_size;
        shdr_ptr.* = std.mem.bytesToValue(Shdr, mapped_file.data[sh_offset..][0..shdr_size]);
    }

    const shstrndx = if (ehdr_ptr.e_shstrndx == std.math.maxInt(@TypeOf(ehdr_ptr.e_shstrndx)))
        shdr_begin.sh_link
    else
        ehdr_ptr.e_shstrndx;

    const shstrtab_size = shdrs[shstrndx].sh_size;

    var shstrtab = try allocator.alloc(u8, shstrtab_size);

    const shstrtab_offset = shdrs[shstrndx].sh_offset;
    std.mem.copy(u8, shstrtab, mapped_file.data[shstrtab_offset..][0..shstrtab_size]);

    return .{
        .mapped_file = mapped_file,
        .shdrs = shdrs,
        .shstrtab = shstrtab,
    };
}

pub fn deinit(self: *InputFile, allocator: Allocator) void {
    allocator.free(self.shstrtab);
    self.shstrtab = undefined;

    allocator.free(self.shdrs);
    self.shdrs = undefined;

    self.mapped_file.unmap();
}
