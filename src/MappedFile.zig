const std = @import("std");

const MappedFile = @This();

data: []align(std.mem.page_size) u8,
size: u64,

pub fn map(path: []const u8) !MappedFile {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const size = try file.getEndPos();
    const data = try std.os.mmap(null, @intCast(size), std.os.linux.PROT.READ, std.os.linux.MAP.PRIVATE, file.handle, 0);

    return .{
        .data = data,
        .size = size,
    };
}

pub fn unmap(self: *MappedFile) void {
    std.os.munmap(self.data);
}
