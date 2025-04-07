const std = @import("std");
const zeltlager_data = @import("zeltlager_data.zig");
const logging = @import("logging.zig");
pub var version: u16 = 0;
pub extern fn wasm_websocket_write(ptr: [*]const u8, len: usize) void;
pub const messagetype = enum(u8) {
    zeltchange,
    grab,
    drop,
    anwesend,
    abwesend,
    update,
    forcedrop,
    multichange,
    rst_anwesenheit,
    whole_state,
};
pub fn grab(i: usize) void {
    const websocket_message: [3]u8 = .{
        @intFromEnum(messagetype.grab),
        @truncate(i >> 8),
        @truncate(i),
    };
    wasm_websocket_write((&websocket_message).ptr, websocket_message.len);
}
pub fn drop(i: usize) void {
    const websocket_message: [3]u8 = .{
        @intFromEnum(messagetype.drop),
        @truncate(i >> 8),
        @truncate(i),
    };
    wasm_websocket_write((&websocket_message).ptr, websocket_message.len);
}
pub fn zeltchange(i: usize, from: usize, to: usize) void {
    const websocket_message: [7]u8 = .{
        @intFromEnum(messagetype.zeltchange),
        @truncate(i >> 8),
        @truncate(i),
        @truncate(from),
        @truncate(to),
        0,
        0,
    };
    wasm_websocket_write((&websocket_message).ptr, websocket_message.len);
}
fn rcv_grab(message: []const u8) void {
    logging.log("grabbed {}\n", .{(@as(u16, message[0]) << 8) + message[1]}) catch return;
}
fn rcv_drop(message: []const u8) void {
    logging.log("dropped {}\n", .{(@as(u16, message[0]) << 8) + message[1]}) catch return;
}

fn rcv_zeltchange(message: []const u8) void {
    if (message.len < 5) {
        logging.log("message to short !!!\n", .{}) catch return;
        return;
    }
    var tid: u16 = message[0]; // + (message[2]);
    tid = (tid << 8) + message[1];
    const from: u8 = message[2];
    const to: u8 = message[3];
    for (&zeltlager_data.teilnehmer_list) |*t| {
        if (tid == t.*.id and from == t.*.Zelte_id) {
            t.*.Zelte_id = to;
            zeltlager_data.zelte[to].teilnehmer[zeltlager_data.zelte[to].n_teilnehmer] = t.*.id;
            zeltlager_data.zelte[to].n_teilnehmer += 1;
            if (std.mem.indexOfScalar(u32, &zeltlager_data.zelte[from].teilnehmer, t.*.id)) |zt_index| {
                for (zt_index..zeltlager_data.zelte[from].n_teilnehmer - 1) |i| {
                    zeltlager_data.zelte[from].teilnehmer[i] = zeltlager_data.zelte[from].teilnehmer[i + 1];
                }
            }
            zeltlager_data.zelte[from].n_teilnehmer -= 1;
        }
    }
}
const handler_functions: [10]*const fn (message: []const u8) void = .{ rcv_zeltchange, rcv_grab, rcv_drop, rcv_drop, rcv_drop, rcv_drop, rcv_drop, rcv_drop, rcv_drop, rcv_drop };

pub fn receive(message: []const u8) void {
    handler_functions[message[0]](message[1..]);
}
