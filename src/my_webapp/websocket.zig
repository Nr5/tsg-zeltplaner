const std = @import("std");
const http = std.http;
const zeltlager_data = @import("zeltlager_data.zig");
const logging = @import("logging.zig");
const ui = @import("ui.zig");
const dvui = @import("dvui");
const Client = @import("client/client.zig").Client;
const proto = @import ("proto.zig");
const sdl_app = @import("sdl-my_webapp.zig");
pub var win: *dvui.Window = undefined;
pub var writerThread: std.Thread = undefined;
pub var readerThread: std.Thread = undefined;
const handler = struct {
pub fn serverMessage(_: *handler, msg: []u8) !void {
    if (false) return error.DivisionByZero;
    handler_functions[msg[0]](msg[1..]);
    dvui.refresh(win, @src(), null);
}
};

var outdatabuf: [0x10000]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(&outdatabuf);
var message_allocator = fba.allocator();

pub var messagebuf: [100][]u8 =undefined;
pub var messagebuf_len: u8 =0;
pub fn readfn() void {
//  const h: handler = undefined;
//  client.readLoop(@constCast(&h)) catch unreachable;
//  if (true) return;
    var reader = &client._reader;
    while(true){
    reader.done(.binary);
    logging.log("10ms" ,.{}) catch unreachable;
    std.time.sleep(10_000_000);
    logging.log("10ms over" ,.{}) catch unreachable;
    logging.log("read_loop\n",.{}) catch unreachable;
    //const h : handler = undefined;
    reader.done(.binary);
//    client.readTimeout(100) catch unreachable;
    const message = client.read() catch {
        logging.log("OH NO, connection was closed\n", .{}) catch unreachable;
        return;
    };
    if  (message) |msg| {
        logging.log("message_type: {s}\n", .{
            switch(msg.type) {
                .binary => "binary", 
                .text => "text",
                .ping => "ping",
                .pong => "pong",
                .close => "close",
            }}
            ) catch unreachable;
        if (msg.type == .binary or msg.type == .text){
        handler_functions[msg.data[0]](msg.data[1..]);
        if (msg.data[0] != @intFromEnum(messagetype.whole_state) and msg.data[0] != @intFromEnum(messagetype.get_pointers)){
        }
        }
        reader.done(.binary);
        if (msg.data[0] == @intFromEnum(messagetype.get_pointers) )return;
    }

    }
}
pub fn writefn() void {
    while (true){
//    logging.log("write_loop",.{}) catch unreachable;
        var i: u8 = 0;
        while (i < messagebuf_len){
        dvui.refresh(win, @src(), null);
            const msg = messagebuf[i];
            if (@import("builtin").os.tag == .linux or @import("builtin").os.tag == .windows) {
                logging.log("write_start\n", .{}) catch unreachable;
                client.writeBin(msg) catch {
                        logging.log("closed\n", .{}) catch unreachable;
                        return;
                };
                logging.log("write_end\n", .{}) catch unreachable;
            } else {
                wasm_websocket_write((&msg).ptr,msg.len);
            }
            i+=1;
        }
        messagebuf_len=0;
        fba.reset();

    std.time.sleep(100_000_000);
    }
}
var gpa1 = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa1.allocator();
var client: Client = undefined;
pub var version: u16 = 0;
var ws_client: http.WebSocket = undefined;
pub extern fn wasm_websocket_write(ptr: [*]const u8, len: usize) void;
pub fn init () !void {
  if (comptime @import("builtin").os.tag == .linux or @import("builtin").os.tag == .windows) {

  // create the client
  client = try Client.init(allocator, .{
    .port = 44520,
    .host = "95.143.172.215",
  });
  // send the initial handshake request
  const request_path = "/";
  try client.handshake(request_path, .{
    .timeout_ms = 10000,
    // Raw headers to send, if any. 
    // A lot of servers require a Host header.
    // Separate multiple headers using \r\n

    .headers = "Host: beepdoop.uber.space:44520",
  });
    writerThread =  try std.Thread.spawn(.{},writefn,.{});
    readerThread =  try std.Thread.spawn(.{},readfn,.{});
}
}
pub fn sdl_websocket_write(ptr: [*]const u8, len: usize) void{
    _ = messagebuf[messagebuf_len] ;
    _ = ptr;
    _ = len;
}
pub fn websocket_write(ptr: [*]const u8, len: usize) void {
    if (@import("builtin").os.tag == .linux or @import("builtin").os.tag == .windows) {
        sdl_websocket_write(ptr,len);
    } else {
        wasm_websocket_write(ptr,len);
    }
}


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
    get_pointers,
    anwesenheit,
};
pub fn grab(i: usize) void {
    messagebuf[messagebuf_len] = message_allocator.alloc(u8, 3) catch unreachable;
    messagebuf[messagebuf_len][0] = @intFromEnum(messagetype.grab);
    messagebuf[messagebuf_len][1] = @truncate(i >> 8);
    messagebuf[messagebuf_len][2] = @truncate(i);
    messagebuf_len += 1;
//    const msg = message_allocator.alloc(u8, 3) catch unreachable;
//    _ = msg;
   // websocket_write((&msg).ptr, msg.len);
}
pub fn drop(i: usize) void {
    messagebuf[messagebuf_len] = message_allocator.alloc(u8, 3) catch unreachable;
    messagebuf[messagebuf_len][0] = @intFromEnum(messagetype.drop);
    messagebuf[messagebuf_len][1] = @truncate(i >> 8);
    messagebuf[messagebuf_len][2] = @truncate(i);
    messagebuf_len += 1;
//    const msg = message_allocator.alloc(u8, 3) catch unreachable;
//    _ = msg;
   // websocket_write((&msg).ptr, msg.len);
}
pub fn zeltchange(i: usize, from: usize, to: usize) void {
    messagebuf[messagebuf_len] = message_allocator.alloc(u8, 7) catch unreachable;
    messagebuf[messagebuf_len][0] = @intFromEnum(messagetype.zeltchange);
    messagebuf[messagebuf_len][1] = @truncate(i >> 8);
    messagebuf[messagebuf_len][2] = @truncate(i);
    messagebuf[messagebuf_len][3] = @truncate(from);
    messagebuf[messagebuf_len][4] = @truncate(to);
    messagebuf[messagebuf_len][5] = 0;
    messagebuf[messagebuf_len][6] = 0;
    messagebuf_len += 1;
   //const websocket_message: [7]u8 = .{
   //    @intFromEnum(messagetype.zeltchange),
   //    @truncate(i >> 8),
   //    @truncate(i),
   //    @truncate(from),
   //    @truncate(to),
   //    0,
   //    0,
   //};
   //websocket_write((&websocket_message).ptr, websocket_message.len);
    
}
pub fn request_state(i: usize) void {
//   const websocket_message: [2]u8 = .{
//       @intFromEnum(messagetype.whole_state),
//       @truncate(i),
//   };
    messagebuf[messagebuf_len] = message_allocator.alloc(u8, 2) catch unreachable;
    messagebuf[messagebuf_len][0] = @intFromEnum(messagetype.whole_state);
    messagebuf[messagebuf_len][1] = @truncate(i);
    messagebuf_len += 1;


 //   websocket_write((&websocket_message).ptr, websocket_message.len);
}
pub fn anwesenheit(i: u16, is_anwesend: bool) void{
    messagebuf[messagebuf_len] = message_allocator.alloc(u8, 3) catch unreachable;
    messagebuf[messagebuf_len][0] = @intFromEnum(if(is_anwesend)messagetype.anwesend else messagetype.abwesend);
    messagebuf[messagebuf_len][1] = @truncate(i >> 8);
    messagebuf[messagebuf_len][2] = @truncate(i);
    messagebuf_len += 1;
//   const websocket_message: [3]u8 = .{
//       @intFromEnum(if(is_anwesend)messagetype.anwesend else messagetype.abwesend),
//       @truncate(i >> 8),
//       @truncate(i),
//   };
//   websocket_write((&websocket_message).ptr, websocket_message.len);
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
            zeltlager_data.zelte[t.*.startwoche][to].teilnehmer[zeltlager_data.zelte[t.*.startwoche][to].n_teilnehmer] = t.*.id;
            zeltlager_data.zelte[t.*.startwoche][to].n_teilnehmer += 1;
            if (std.mem.indexOfScalar(u32, &zeltlager_data.zelte[t.*.startwoche][from].teilnehmer, t.*.id)) |zt_index| {
                for (zt_index..zeltlager_data.zelte[t.*.startwoche][from].n_teilnehmer - 1) |i| {
                    zeltlager_data.zelte[t.*.startwoche][from].teilnehmer[i] = zeltlager_data.zelte[t.*.startwoche][from].teilnehmer[i + 1];
                }
            }
            zeltlager_data.zelte[t.*.startwoche][from].n_teilnehmer -= 1;
        }
    }
    std.mem.sort(u16,ui.teilnehmer_show_list,@as(u16,0),ui.lessThanFunction);
}
fn rcv_anwesend (message: []const u8) void{

    var tid: u16 = message[0]; // + (message[2]);
    tid = (tid << 8) + message[1];
    zeltlager_data.anwesenheit_bitwise |= @as(u4096,1)<<@truncate(tid);
}
fn rcv_abwesend (message: []const u8) void{

    var tid: u16 = message[0]; // + (message[2]);
    tid = (tid << 8) + message[1];
    zeltlager_data.anwesenheit_bitwise &= ~@as(u4096,1)<<@truncate(tid);
}
fn rcv_rst_anwesenheit (_: []const u8) void{
    zeltlager_data.anwesenheit_bitwise = 0;    
}

fn rcv_strbuf (msg: []const u8) void{
    logging.log("get strbuf. len={}\n",.{msg.len}) catch return;
    std.mem.copyForwards(u8, &zeltlager_data.strbuf, msg);
    logging.log("strbuf: {s}\n",.{zeltlager_data.strbuf[0..50]}) catch return;

}
fn rcv_pointers (msg: []const u8 ) void{
    logging.log("get pointers. len={}\n",.{msg.len}) catch return;
    const n_teilnehmer = (msg.len-4) / (35*4);
    //const msg32: *u32 = @ptrCast(msg[4..]);
    logging.log("get pointers. len={}\n",.{msg.len}) catch return;
    var msg32: [0x10000]u32 = undefined;
//    std.mem.copyForwards(u8,@ptrCast(&msg32), msg);
    for (0..n_teilnehmer*35+1)|i|{
        msg32[i] = (msg[i*4+3] + (@as(u32,msg[i*4+1+3]) << 8) + (@as(u32,msg[i*4+2+3]) << 16) + (@as(u32,msg[i*4+3+3]) << 24));
    }
    version = @truncate(msg32[0]);
    for (msg32[0..20])|x|{
        logging.log("msg32{}\n", .{x}) catch unreachable;
    }
    for (msg[0..80])|x|{
        logging.log("msg {}\n", .{x}) catch unreachable;
    }
    for (0..n_teilnehmer) |i| {
        logging.log("t: {}\n", .{i}) catch unreachable;
        zeltlager_data.teilnehmer_list[i].id = msg32[i*35+1];
        zeltlager_data.teilnehmer_list[i].vorname.ptr = @ptrFromInt( msg32[i*35+2]);
        zeltlager_data.teilnehmer_list[i].vorname.len =  msg32[i*35+3];
        zeltlager_data.teilnehmer_list[i].nachname.ptr = @ptrFromInt(msg32[i*35+4]);
        zeltlager_data.teilnehmer_list[i].nachname.len = msg32[i*35+5];
        logging.log("{} {} {} {} {}\n",.{msg32[i*35+1],msg32[i*35+2], msg32[i*35+3], msg32[i*35+4], msg32[i*35+5]}) catch unreachable;
        zeltlager_data.teilnehmer_list[i].anmelder_vorname.ptr = @ptrFromInt( msg32[i*35+6]);
        zeltlager_data.teilnehmer_list[i].anmelder_vorname.len =  msg32[i*35+7];
        zeltlager_data.teilnehmer_list[i].anmelder_nachname.ptr = @ptrFromInt(msg32[i*35+8]);
        zeltlager_data.teilnehmer_list[i].anmelder_nachname.len = msg32[i*35+9];
        zeltlager_data.teilnehmer_list[i].anmelder_email.ptr = @ptrFromInt( msg32[i*35+10]);
        zeltlager_data.teilnehmer_list[i].anmelder_email.len =  msg32[i*35+11];
        zeltlager_data.teilnehmer_list[i].anmelder_telefon.ptr = @ptrFromInt(msg32[i*35+12]);
        zeltlager_data.teilnehmer_list[i].anmelder_telefon.len = msg32[i*35+13];
        zeltlager_data.teilnehmer_list[i].taschengeld.ptr = @ptrFromInt( msg32[i*35+14]);
        zeltlager_data.teilnehmer_list[i].taschengeld.len =  msg32[i*35+15];
        zeltlager_data.teilnehmer_list[i].geburtsdatum.ptr = @ptrFromInt(msg32[i*35+16]);
        zeltlager_data.teilnehmer_list[i].geburtsdatum.len = msg32[i*35+17];
        logging.log("gschl-ptr: {}\n",.{msg32[i*35+18]}) catch unreachable;
        zeltlager_data.teilnehmer_list[i].geschlecht.ptr =@ptrFromInt(msg32[i*35+18]); 
        zeltlager_data.teilnehmer_list[i].geschlecht.len =msg32[i*35+19]; 
        zeltlager_data.teilnehmer_list[i].anschrift.ptr = @ptrFromInt(msg32[i*35+20]); 
        zeltlager_data.teilnehmer_list[i].anschrift.len = msg32[i*35+21]; 
        zeltlager_data.teilnehmer_list[i].tshirt_groesse.ptr = @ptrFromInt( msg32[i*35+22]);
        zeltlager_data.teilnehmer_list[i].tshirt_groesse.len =  msg32[i*35+23];
        zeltlager_data.teilnehmer_list[i].bade_erlaubnis.ptr = @ptrFromInt( msg32[i*35+24]);
        zeltlager_data.teilnehmer_list[i].bade_erlaubnis.len =  msg32[i*35+25];
        zeltlager_data.teilnehmer_list[i].schwimmbefaehigung.ptr = @ptrFromInt(msg32[i*35+26]); 
        zeltlager_data.teilnehmer_list[i].schwimmbefaehigung.len = msg32[i*35+27]; 
        zeltlager_data.teilnehmer_list[i].allergien.ptr = @ptrFromInt( msg32[i*35+28]);
        zeltlager_data.teilnehmer_list[i].allergien.len =  msg32[i*35+29];
        zeltlager_data.teilnehmer_list[i].besonderheiten.ptr = @ptrFromInt(msg32[i*35+30]); 
        zeltlager_data.teilnehmer_list[i].besonderheiten.len = msg32[i*35+31]; 
        zeltlager_data.teilnehmer_list[i].anwesend.ptr = @ptrFromInt( msg32[i*35+32]);
        zeltlager_data.teilnehmer_list[i].anwesend.len =  msg32[i*35+33];

        zeltlager_data.teilnehmer_list[i].Zelte_id     =  @truncate(msg32[i*35+34] & 0xffff);
        zeltlager_data.teilnehmer_list[i].altersgruppe =  @truncate(msg32[i*35+34] >> 16);
        zeltlager_data.teilnehmer_list[i].startwoche =  @truncate(msg32[i*35+35] & 0xffff);
        zeltlager_data.teilnehmer_list[i].endwoche   =  @truncate(msg32[i*35+35] >> 16);
    }

    logging.log("n_teilnehmer={}\n",.{n_teilnehmer}) catch return;
    logging.log("version={}\n",.{msg[3]+(@as(u16,msg[4])<<8)}) catch return;
    for (msg[0..40]) |x| {
        logging.log("{}\n",.{x}) catch return;
    }
    zeltlager_data.adjust_ptrs(@intCast(n_teilnehmer));
    logging.log("{s}",.{zeltlager_data.teilnehmer_list[0].vorname}) catch unreachable;
    logging.log("{s}",.{zeltlager_data.strbuf[1..1+9]}) catch unreachable;
}
fn rcv_anwesenheit (msg: []const u8) void{
    zeltlager_data.anwesenheit_bitwise = 0;
    logging.log("get anwesenheit. len={}\n",.{msg.len}) catch return;
}
const handler_functions: [12]*const fn (message: []const u8) void = .{ rcv_zeltchange, rcv_grab, rcv_drop, rcv_anwesend, rcv_abwesend, rcv_drop, rcv_drop, rcv_drop, rcv_rst_anwesenheit, rcv_strbuf, rcv_pointers, rcv_anwesenheit,  };

pub fn receive(message: []const u8) void {
    handler_functions[message[0]](message[1..]);
}
