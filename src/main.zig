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
    const tmp_dir_path = "tmp_test_disk";
    try std.fs.cwd().makePath(tmp_dir_path);
    defer std.fs.cwd().deleteTree(tmp_dir_path) catch {};

    const source_path = tmp_dir_path ++ "/test.txt";
    const tar_path = "test.txt";

    {
        const f = try std.fs.cwd().createFile(source_path, .{});
        defer f.close();
        try f.writeAll("Content from disk");
    }

    var tar = try microtar_zig.MicroTar.init("test_from_disk.tar", "w");
    defer tar.deinit();

    std.debug.print("Adding file from disk: {s}\n", .{source_path});
    try tar.addFileFromDisk(source_path, tar_path);

    std.debug.print("Finalizing tar\n", .{});
    try tar.finalize();

    std.debug.print("Done\n", .{});
}

test "add symlink from disk" {
    const allocator = std.testing.allocator;
    const tmp_dir_path = "tmp_test_symlink";
    try std.fs.cwd().makePath(tmp_dir_path);
    defer std.fs.cwd().deleteTree(tmp_dir_path) catch {};

    // Create a regular file
    {
        const f = try std.fs.cwd().createFile(tmp_dir_path ++ "/target.txt", .{});
        defer f.close();
        try f.writeAll("I am the target");
    }

    // Create a symlink
    const result_symlink = try std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "ln", "-s", tmp_dir_path ++ "/target.txt", tmp_dir_path ++ "/link.txt" },
    });
    _ = result_symlink;

    var tar = try microtar_zig.MicroTar.init("test_symlink.tar", "w");
    defer tar.deinit();

    // Add symlink
    std.debug.print("Adding symlink from disk...\n", .{});
    try tar.addFileFromDisk(tmp_dir_path ++ "/link.txt", "link.txt");

    try tar.finalize();

    // Verify tar content using 'tar' command if available
    const result = std.process.Child.run(.{
        .allocator = allocator,
        .argv = &[_][]const u8{ "tar", "-tvf", "test_symlink.tar" },
    }) catch |err| {
        std.debug.print("Failed to run tar command: {}\n", .{err});
        return;
    };
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    std.debug.print("Tar output:\n{s}\n", .{result.stdout});

    // Check if it's a symlink in the output.
    // Tar output for symlink usually looks like: lrwxrwxrwx ... link.txt -> target.txt
    try std.testing.expect(std.mem.indexOf(u8, result.stdout, "link.txt -> target.txt") != null);
}
