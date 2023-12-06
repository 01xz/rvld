const InputFile = @This();

const std = @import("std");
const elf = std.elf;

const Allocator = std.mem.Allocator;
const MappedFile = @import("MappedFile.zig");
const Ehdr = elf.Elf64_Ehdr;
const Shdr = elf.Elf64_Shdr;
const Sym = elf.Elf64_Sym;

allocator: Allocator,

mapped_file: MappedFile,

shdrs: []Shdr = undefined,
syms: []Sym = undefined,

shstrtab: []u8 = undefined,
symstrtab: []u8 = undefined,

first_global: i64 = undefined,

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

    var input_file: InputFile = .{
        .allocator = allocator,
        .mapped_file = mapped_file,
    };

    const shdr_offset = ehdr_ptr.e_shoff;

    const shdr_begin = std.mem.bytesAsValue(Shdr, mapped_file.data[shdr_offset..][0..shdr_size]);

    input_file.shdrs = blk: {
        const shdr_num = if (ehdr_ptr.e_shnum == 0)
            shdr_begin.sh_size
        else
            ehdr_ptr.e_shnum;
        break :blk try input_file.read(Shdr, shdr_offset, shdr_num);
    };

    input_file.shstrtab = blk: {
        const shstrndx = if (ehdr_ptr.e_shstrndx == std.math.maxInt(@TypeOf(ehdr_ptr.e_shstrndx)))
            shdr_begin.sh_link
        else
            ehdr_ptr.e_shstrndx;
        break :blk try input_file.readBytesFromSectionIndex(shstrndx);
    };

    return input_file;
}

pub fn deinit(self: *InputFile) void {
    self.allocator.free(self.shstrtab);
    self.shstrtab = undefined;

    self.allocator.free(self.shdrs);
    self.shdrs = undefined;

    self.mapped_file.unmap();
}

fn read(self: *InputFile, comptime T: type, offset: u64, num: u64) ![]T {
    const size = @sizeOf(T);

    if (self.mapped_file.size < offset + num * size) {
        return error.ReadOutOfRange;
    }

    var out = try self.allocator.alloc(T, num);

    for (out, 0..) |*ptr, i| {
        const offset_i = offset + i * size;
        ptr.* = std.mem.bytesToValue(T, self.mapped_file.data[offset_i..][0..size]);
    }

    return out;
}

fn readBytesFromSection(self: *InputFile, shdr_ptr: *const Shdr) ![]u8 {
    const offset = shdr_ptr.sh_offset;
    const size = shdr_ptr.sh_size;

    if (self.mapped_file.size < offset + size) {
        return error.CorruptedElfFile;
    }

    var dest = try self.allocator.alloc(u8, size);
    std.mem.copy(u8, dest, self.mapped_file.data[offset..][0..size]);

    return dest;
}

fn readBytesFromSectionIndex(self: *InputFile, i: u32) ![]u8 {
    return try self.readBytesFromSection(&self.shdrs[i]);
}

fn findSection(self: *const InputFile, sh_type: u32) !*Shdr {
    for (self.shdrs) |*shdr_ptr| {
        if (shdr_ptr.sh_type == sh_type) return shdr_ptr;
    }
    return error.UnableToFind;
}

fn readSyms(self: *InputFile, shdr_ptr: *const Shdr) ![]Sym {
    const sym_size = @sizeOf(Sym);
    const sym_offset = shdr_ptr.sh_offset;
    const sym_num = shdr_ptr.sh_size / sym_size;
    return try self.read(Sym, sym_offset, sym_num);
}

pub fn parse(self: *InputFile) !void {
    const symtab_shdr_ptr = try self.findSection(elf.SHT_SYMTAB);
    self.first_global = symtab_shdr_ptr.sh_info;
    self.syms = try self.readSyms(symtab_shdr_ptr);
    self.symstrtab = try self.readBytesFromSectionIndex(symtab_shdr_ptr.sh_link);
}

pub fn parseClean(self: *InputFile) void {
    self.allocator.free(self.symstrtab);
    self.symstrtab = undefined;

    self.allocator.free(self.syms);
    self.syms = undefined;
}
