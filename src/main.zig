const std = @import("std");
const microtar_zig = @import("microtar_zig");

test "simple compression" {
    var tar = try microtar_zig.MicroTar.init("test.tar", "w");
    defer tar.deinit();

    const data = "Hello, World!";
    std.debug.print("Writing file with {} bytes\n", .{data.len});

    try tar.writeFile("hello.txt", data);

    std.debug.print("Finalizing tar\n", .{});
    try tar.finalize();

    std.debug.print("Done\n", .{});
}

test "compression with attributes" {
    var tar = try microtar_zig.MicroTar.init("test_with_attrs.tar", "w");
    defer tar.deinit();

    const data = "Hello, World with attributes!";
    std.debug.print("Writing file with {} bytes\n", .{data.len});

    const mode = 0o644; // rw-r--r--
    const mtime = @as(u32, @intCast(std.time.timestamp()));

    try tar.writeFileWithAttrs("hello_with_attrs.txt", data, mode, mtime);

    std.debug.print("Finalizing tar\n", .{});
    try tar.finalize();

    std.debug.print("Done\n", .{});
}

test "add file from disk" {
    var tar = try microtar_zig.MicroTar.init("test_from_disk.tar", "w");
    defer tar.deinit();

    const source_path = "src/root.zig";
    const tar_path = "src/root.zig";

    std.debug.print("Adding file from disk: {s}\n", .{source_path});
    try tar.addFileFromDisk(source_path, tar_path);

    std.debug.print("Finalizing tar\n", .{});
    try tar.finalize();

    std.debug.print("Done\n", .{});
}
