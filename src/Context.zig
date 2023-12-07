const Context = @This();

const std = @import("std");
const config = @import("config");

const Allocator = std.mem.Allocator;
const StringList = std.ArrayList([:0]const u8);
const ContextArgs = struct {
    output: [:0]const u8,
    library_paths: StringList,
    remained: StringList,
    remained_file: StringList,
};

allocator: Allocator,
context_args: ContextArgs,
version: []const u8 = config.version,

pub fn init(allocator: Allocator) Context {
    return .{
        .allocator = allocator,
        .context_args = .{
            .output = "a.out",
            .library_paths = StringList.init(allocator),
            .remained = StringList.init(allocator),
            .remained_file = StringList.init(allocator),
        },
    };
}

pub fn deinit(self: *Context) void {
    self.context_args.remained_file.deinit();
    self.context_args.remained.deinit();
    self.context_args.library_paths.deinit();
}

pub fn parseArgs(self: *Context, args: [][:0]u8) !void {
    if (args.len < 2) {
        std.debug.print("{s}: no input files\n", .{args[0]});
        std.os.exit(1);
    }

    var i: usize = 1;
    var arg: [:0]const u8 = undefined;
    var arg_head = args[0];

    while (i < args.len) {
        if (readFlag(args[i..], "help", &i) or readFlag(args[i..], "h", &i)) {
            std.debug.print("Usage: {s} [options] file...\n", .{arg_head});
            std.os.exit(0);
        }

        if (readFlag(args[i..], "version", &i) or
            readFlag(args[i..], "v", &i))
        {
            std.debug.print("ld (rvld) {s}\n", .{self.version});
            std.os.exit(0);
        } else if (try readAndParse(args[i..], "output", &i, &arg) or
            try readAndParse(args[i..], "o", &i, &arg))
        {
            self.context_args.output = arg;
            std.debug.print("output: {s}\n", .{self.context_args.output});
        } else if (try readAndParse(args[i..], "m", &i, &arg)) {
            if (!std.mem.eql(u8, arg, "elf64lriscv")) {
                std.debug.print("{s}: unrecognised emulation mode: {s}\n", .{ arg_head, arg });
                std.debug.print("Supported emulations: {s}\n", .{"elf64lriscv"});
                std.os.exit(1);
            }
        } else if (try readAndParse(args[i..], "L", &i, &arg)) {
            try self.context_args.library_paths.append(arg);
        } else if (try readAndParse(args[i..], "l", &i, &arg)) {
            try self.context_args.remained.append(arg);
        } else if (readFlag(args[i..], "static", &i) or
            readFlag(args[i..], "as-needed", &i) or
            readFlag(args[i..], "s", &i) or
            readFlag(args[i..], "no-relax", &i) or
            readFlag(args[i..], "start-group", &i) or
            readFlag(args[i..], "end-group", &i) or
            try readAndParse(args[i..], "sysroot", &i, &arg) or
            try readAndParse(args[i..], "plugin", &i, &arg) or
            try readAndParse(args[i..], "plugin-opt", &i, &arg) or
            try readAndParse(args[i..], "hash-style", &i, &arg) or
            try readAndParse(args[i..], "build-id", &i, &arg))
        {
            // ignored
        } else {
            if (args[i][0] == '-') {
                std.debug.print("{s}: unrecognized option: {s}\n", .{ arg_head, args[i] });
                std.debug.print("{s}: use the --help option for usage information\n", .{arg_head});
                std.os.exit(1);
            } else {
                try self.context_args.remained_file.append(args[i]);
            }
            i += 1;
        }
    }
}

fn readFlag(args: [][:0]const u8, comptime name: [:0]const u8, index: *usize) bool {
    const dashes = if (name.len == 1)
        [_][:0]const u8{"-" ++ name}
    else
        [_][:0]const u8{
            "-" ++ name,
            "--" ++ name,
        };

    inline for (dashes) |opt| {
        if (std.mem.eql(u8, args[0], opt)) {
            index.* += 1;
            return true;
        }
    }

    return false;
}

fn readAndParse(args: [][:0]const u8, comptime name: [:0]const u8, index: *usize, value: *[:0]const u8) !bool {
    const dashes = if (name.len == 1)
        [_][:0]const u8{"-" ++ name}
    else
        [_][:0]const u8{
            "-" ++ name,
            "--" ++ name,
        };

    inline for (dashes) |opt| {
        if (std.mem.eql(u8, args[0], opt)) {
            if (args.len == 1) {
                return error.IllegalArg;
            }
            value.* = args[1];
            index.* += 2;
            return true;
        }
    }

    const dashes_as_prefix = if (name.len == 1)
        [_][:0]const u8{"-" ++ name}
    else
        [_][:0]const u8{
            "-" ++ name ++ "=",
            "--" ++ name ++ "=",
        };

    inline for (dashes_as_prefix) |prefix| {
        if (std.mem.startsWith(u8, args[0], prefix)) {
            value.* = args[0][prefix.len..];
            index.* += 1;
            return true;
        }
    }

    return false;
}
