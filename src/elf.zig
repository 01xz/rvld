const std = @import("std");

pub const EI_NIDENT = 16;
pub const ELFMAG = "\x7fELF";

pub const EM_RISCV = 243;

pub const EI_CLASS = 4;
pub const ELFCLASSNONE = 0;
pub const ELFCLASS32 = 1;
pub const ELFCLASS64 = 2;
pub const ELFCLASSNUM = 3;

pub const PT_LOAD = 1;

pub const PF_X = 0x1;
pub const PF_W = 0x2;
pub const PF_R = 0x4;

pub const ElfHeader = extern struct {
    e_ident: [EI_NIDENT]u8,
    e_type: u16,
    e_machine: u16,
    e_version: u32,
    e_entry: u64,
    e_phoff: u64,
    e_shoff: u64,
    e_flags: u32,
    e_ehsize: u16,
    e_phentsize: u16,
    e_phnum: u16,
    e_shentsize: u16,
    e_shnum: u16,
    e_shstrndx: u16,
};

pub const ElfProgramHeader = extern struct {
    p_type: u32,
    p_flags: u32,
    p_offset: u64,
    p_vaddr: u64,
    p_paddr: u64,
    p_filesz: u64,
    p_memsz: u64,
    p_align: u64,
};

pub const ElfSectionHeader = extern struct {
    sh_name: u32,
    sh_type: u32,
    sh_flags: u64,
    sh_addr: u64,
    sh_offset: u64,
    sh_size: u64,
    sh_link: u32,
    sh_info: u32,
    sh_addralign: u64,
    sh_entsize: u64,
};

pub const ElfSym = extern struct {
    st_name: u32,
    st_info: u8,
    st_other: u8,
    st_shndx: u16,
    st_value: u64,
    st_size: u64,
};
