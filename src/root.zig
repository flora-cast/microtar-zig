const std = @import("std");
const c = @cImport({
    @cInclude("microtar.h");
});

pub const MicroTar = struct {
    tar: c.mtar_t,

    pub fn init(path: [:0]const u8, mode: [:0]const u8) !MicroTar {
        var tar: c.mtar_t = undefined;
        const result = c.mtar_open(&tar, path.ptr, mode.ptr);
        if (result != c.MTAR_ESUCCESS) {
            return error.TarOpenFailed;
        }
        return MicroTar{ .tar = tar };
    }

    pub fn deinit(self: *MicroTar) void {
        _ = c.mtar_close(&self.tar);
    }

    pub fn writeFile(self: *MicroTar, name: [:0]const u8, data: []const u8) !void {
        var result = c.mtar_write_file_header(&self.tar, name.ptr, @intCast(data.len));
        if (result != c.MTAR_ESUCCESS) return error.WriteHeaderFailed;

        result = c.mtar_write_data(&self.tar, data.ptr, @intCast(data.len));
        if (result != c.MTAR_ESUCCESS) return error.WriteDataFailed;
    }

    pub fn writeFileWithAttrs(
        self: *MicroTar,
        name: [:0]const u8,
        data: []const u8,
        mode: u32,
        mtime: u32,
    ) !void {
        var header: c.mtar_header_t = undefined;

        @memset(@as([*]u8, @ptrCast(&header))[0..@sizeOf(c.mtar_header_t)], 0);

        header.mode = @intCast(mode);
        header.size = @intCast(data.len);
        header.mtime = @intCast(mtime);
        header.type = c.MTAR_TREG;

        const name_len = @min(name.len, 100);
        @memcpy(header.name[0..name_len], name[0..name_len]);

        var result = c.mtar_write_header(&self.tar, &header);
        if (result != c.MTAR_ESUCCESS) return error.WriteHeaderFailed;

        result = c.mtar_write_data(&self.tar, data.ptr, @intCast(data.len));
        if (result != c.MTAR_ESUCCESS) return error.WriteDataFailed;
    }

    pub fn addFileFromDisk(self: *MicroTar, source_path: []const u8, tar_path: [:0]const u8) !void {
        const allocator = std.heap.page_allocator;

        const file = try std.fs.cwd().openFile(source_path, .{});
        defer file.close();

        const stat = try file.stat();

        const content = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
        defer allocator.free(content);

        var header: c.mtar_header_t = undefined;
        @memset(@as([*]u8, @ptrCast(&header))[0..@sizeOf(c.mtar_header_t)], 0);

        header.mode = @intCast(stat.mode & 0o777);
        header.size = @intCast(stat.size);
        header.mtime = @intCast(@divFloor(stat.mtime, 1_000_000_000));
        header.type = c.MTAR_TREG;

        const name_len = @min(tar_path.len, 100);
        @memcpy(header.name[0..name_len], tar_path[0..name_len]);

        var result = c.mtar_write_header(&self.tar, &header);
        if (result != c.MTAR_ESUCCESS) return error.WriteHeaderFailed;

        result = c.mtar_write_data(&self.tar, content.ptr, @intCast(content.len));
        if (result != c.MTAR_ESUCCESS) return error.WriteDataFailed;
    }

    pub fn finalize(self: *MicroTar) !void {
        const result = c.mtar_finalize(&self.tar);
        if (result != c.MTAR_ESUCCESS) return error.FinalizeFailed;
    }
};
