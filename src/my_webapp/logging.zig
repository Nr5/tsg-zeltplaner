const std = @import("std");
pub var log_buf: [0x1000]u8 = undefined;
pub var log_buf_len: u16 = 0;
pub inline fn log(fmt: []const u8, data: anytype) !void {
    if (log_buf_len > 0xff) {
        const first_newline = std.mem.indexOfScalar(u8, log_buf[0..log_buf_len], '\n');
        const position = if (first_newline) |fin| fin + 1 else 100;
        std.mem.copyForwards(u8, &log_buf, log_buf[position..]);
        log_buf_len -= @truncate(position);
    }
    const slice = try std.fmt.bufPrint(log_buf[log_buf_len..], fmt, data);
    log_buf_len += @truncate(slice.len);
}
