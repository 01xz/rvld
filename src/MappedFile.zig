const std = @import("std");

const MappedFile = @This();

data: []u8,
size: u64,

pub fn map(path: []const u8) !MappedFile {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const size = try file.getEndPos();
    const data = try std.os.mmap(null, @intCast(size), std.os.linux.PROT.READ, std.os.linux.MAP.PRIVATE, file.handle, 0);

    return .{
        .data = @alignCast(data),
        .size = size,
    };
}

pub fn unmap(self: *MappedFile) void {
    std.os.munmap(@alignCast(self.data));
    self.data = undefined;
    self.size = undefined;
}
