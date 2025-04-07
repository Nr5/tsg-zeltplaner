const std = @import("std");
const dvui = @import("dvui");
const WebBackend = @import("WebBackend");
const websocket = @import("websocket.zig");
const ui = @import("ui.zig");
const shared_mem = @import("shared_mem.zig");
const zeltlager_data = @import("zeltlager_data.zig");
const logging = @import("logging.zig");
usingnamespace WebBackend.wasm;

const WriteError = error{};
const LogWriter = std.io.Writer(void, WriteError, writeLog);
fn writeLog(_: void, msg: []const u8) WriteError!usize {
    WebBackend.wasm.wasm_log_write(msg.ptr, msg.len);
    return msg.len;
}

pub fn logFn(
    comptime message_level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_txt = switch (message_level) {
        .err => "error",
        .warn => "warning",
        .info => "info",
        .debug => "debug",
    };
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    const msg = level_txt ++ prefix2 ++ format ++ "\n";

    (LogWriter{ .context = {} }).print(msg, args) catch return;
    WebBackend.wasm.wasm_log_flush();
}

pub const std_options: std.Options = .{
    // Overwrite default log handler
    .logFn = logFn,
};

var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_instance.allocator();

var win: dvui.Window = undefined;
var backend: WebBackend = undefined;
var touchPoints: [2]?dvui.Point = [_]?dvui.Point{null} ** 2;
var orig_content_scale: f32 = 1.0;
var initialized = false;
const zig_favicon = @embedFile("src/zig-favicon.png");
var framenr: u16 = 0;

export fn app_init(platform_ptr: [*]const u8, platform_len: usize) i32 {
    const platform = platform_ptr[0..platform_len];
    dvui.log.debug("platform: {s}", .{platform});
    const mac = if (std.mem.indexOf(u8, platform, "Mac") != null) true else false;

    backend = WebBackend.init() catch {
        return 1;
    };
    win = dvui.Window.init(@src(), gpa, backend.backend(), .{ .keybinds = if (mac) .mac else .windows }) catch {
        return 2;
    };

    WebBackend.win = &win;

    orig_content_scale = win.content_scale;

    //ws.init(null, "","");
    return 0;
}

fn apply_config() void {
    dvui.themeSet(&win.themes.values()[shared_mem.config.theme]);
}
export fn app_deinit() void {
    win.deinit();
    backend.deinit();
}

// return number of micros to wait (interrupted by events) for next frame
// return -1 to quit
//
//
export fn version_ptr() [*c]u8 {
    return @ptrCast(&websocket.version);
}
export fn cli2ser_ptr() [*c]u8 {
    return @ptrCast(&shared_mem.cli2ser);
}
export fn ser2cli_ptr() [*c]u8 {
    return @ptrCast(&shared_mem.ser2cli);
}
export fn theme_ptr() [*c]u8 {
    return @ptrCast(&shared_mem.config.theme);
}
export fn strbuf_ptr() [*c]u8 {
    return @ptrCast(&zeltlager_data.strbuf);
}
export fn teilnehmer_ptr() [*c]u8 {
    return @ptrCast(&zeltlager_data.teilnehmer_list);
}
export fn receive_websocket(len: usize) void {
    websocket.receive(shared_mem.ser2cli[0..len]);
}
export fn adjust_ptrs(n_teilnehmer: u32) void {
    for (&zeltlager_data.allergien, 0..) |*a, i| {
        const i_8: u8 = @truncate(i);
        a.bezeichnung = zeltlager_data.Allergien_namen[i];
        a.key = 'A' + i_8;
        if (a.key > 'H') a.key += 3;
        if (a.key > 'P') a.key += 1;
        if (a.key > 'R') a.key += 'V' - 'S';
        a.n_teilnehmer = 0;
    }
    for (&zeltlager_data.zelte) |*z| {
        z.n_teilnehmer = 0;
    }
    const strbuf_addr = @intFromPtr(&zeltlager_data.strbuf);
    zeltlager_data.n_teilnehmer = @truncate(n_teilnehmer);
    logging.log("n_teilnehmer: {}", .{n_teilnehmer}) catch unreachable;
    for (zeltlager_data.teilnehmer_list[0..n_teilnehmer]) |*t| {
        t.*.vorname.ptr += strbuf_addr;
        t.*.nachname.ptr += strbuf_addr;
        t.*.anmelder_vorname.ptr += strbuf_addr;
        t.*.anmelder_nachname.ptr += strbuf_addr;
        t.*.anmelder_email.ptr += strbuf_addr;
        t.*.anmelder_telefon.ptr += strbuf_addr;
        t.*.taschengeld.ptr += strbuf_addr;
        t.*.geburtsdatum.ptr += strbuf_addr;
        t.*.geschlecht.ptr += strbuf_addr;
        t.*.anschrift.ptr += strbuf_addr;
        t.*.tshirt_groesse.ptr += strbuf_addr;
        t.*.bade_erlaubnis.ptr += strbuf_addr;
        t.*.schwimmbefaehigung.ptr += strbuf_addr;
        t.*.allergien.ptr += strbuf_addr;
        t.*.besonderheiten.ptr += strbuf_addr;
        t.*.anwesend.ptr += strbuf_addr;

        if (t.Zelte_id < 56) {
            const zelt = &zeltlager_data.zelte[t.*.Zelte_id];
            zelt.*.teilnehmer[zelt.*.n_teilnehmer] = t.*.id;
            zelt.*.n_teilnehmer += 1;
        }
        if (t.*.allergien.len > 0) {
            //logging.log("{}:  ", .{t.*.id}) catch unreachable;
            for (t.*.allergien) |a| {
                const i: u8 = switch (a) {
                    'A'...'H' => a - 'A',
                    'L'...'P' => a - 'L' + 8,
                    'R' => 13,
                    'V' => 14,
                    'W' => 15,
                    else => 0,
                };

                //logging.log("{} ", .{i}) catch unreachable;
                zeltlager_data.allergien[i].teilnehmer[zeltlager_data.allergien[i].n_teilnehmer] = @truncate(t.*.id);
                zeltlager_data.allergien[i].n_teilnehmer += 1;
            }
            //logging.log("\n", .{}) catch unreachable;
        }
    }
}
export fn js_msg() u8 {
    //    @memcpy(cli2ser[0..5],"hello");
    framenr += 1;
    return 5;
}
export fn store_config() void {
    for (win.themes.values(), 0..) |val, i| {
        if (std.mem.eql(u8, win.theme.name, val.name)) {
            shared_mem.config.theme = @intCast(i);
            break;
        }
    }
}
export fn app_update() i32 {
    return update() catch |err| {
        std.log.err("{!}", .{err});
        const msg = std.fmt.allocPrint(gpa, "{!}", .{err}) catch "allocPrint OOM";
        WebBackend.wasm.wasm_panic(msg.ptr, msg.len);
        return -1;
    };
}

fn update() !i32 {
    const nstime = win.beginWait(backend.hasEvent());

    try win.begin(nstime);
    if (!initialized) {
        apply_config();
        initialized = true;
    }

    // Instead of the backend saving the events and then calling this, the web
    // backend is directly sending the events to dvui
    //try backend.addAllEvents(&win);

    try dvui_frame();
    //try dvui.label(@src(), "test", .{}, .{ .color_text = .{ .color = dvui.Color.white } });

    //var indices: []const u32 = &[_]u32{ 0, 1, 2, 0, 2, 3 };
    //var vtx: []const dvui.Vertex = &[_]dvui.Vertex{
    //    .{ .pos = .{ .x = 100, .y = 150 }, .uv = .{ 0.0, 0.0 }, .col = .{} },
    //    .{ .pos = .{ .x = 200, .y = 150 }, .uv = .{ 1.0, 0.0 }, .col = .{ .g = 0, .b = 0, .a = 200 } },
    //    .{ .pos = .{ .x = 200, .y = 250 }, .uv = .{ 1.0, 1.0 }, .col = .{ .r = 0, .b = 0, .a = 100 } },
    //    .{ .pos = .{ .x = 100, .y = 250 }, .uv = .{ 0.0, 1.0 }, .col = .{ .r = 0, .g = 0 } },
    //};
    //backend.drawClippedTriangles(null, vtx, indices);

    const end_micros = try win.end(.{});

    backend.setCursor(win.cursorRequested());
    backend.textInputRect(win.textInputRequested());

    const wait_event_micros = win.waitTime(end_micros, null);
    return @intCast(@divTrunc(wait_event_micros, 1000));
}

fn dvui_frame() !void {
    //    var new_content_scale: ?f32 = null;
    //    var old_dist: ?f32 = null;
    //   for (dvui.events()) |*e| {
    //       if (e.evt == .mouse and (e.evt.mouse.button == .touch0 or e.evt.mouse.button == .touch1)) {
    //           const idx: usize = if (e.evt.mouse.button == .touch0) 0 else 1;
    //           switch (e.evt.mouse.action) {
    //               .press => {
    //                   touchPoints[idx] = e.evt.mouse.p;
    //               },
    //               .release => {
    //                   touchPoints[idx] = null;
    //               },
    //               .motion => {
    //                   if (touchPoints[0] != null and touchPoints[1] != null) {
    //                       e.handled = true;
    //                       var dx: f32 = undefined;
    //                       var dy: f32 = undefined;
    //
    //                       if (old_dist == null) {
    //                           dx = touchPoints[0].?.x - touchPoints[1].?.x;
    //                           dy = touchPoints[0].?.y - touchPoints[1].?.y;
    //                           old_dist = @sqrt(dx * dx + dy * dy);
    //                       }
    //
    //                       touchPoints[idx] = e.evt.mouse.p;
    //
    //                       dx = touchPoints[0].?.x - touchPoints[1].?.x;
    //                       dy = touchPoints[0].?.y - touchPoints[1].?.y;
    //                       const new_dist: f32 = @sqrt(dx * dx + dy * dy);
    //
    //                       new_content_scale = @max(0.1, win.content_scale * new_dist / old_dist.?);
    //                   }
    //               },
    //               else => {},
    //           }
    //       }
    //   }
    //   const label = if (dvui.Examples.show_demo_window) "Hide Demo Window" else "Show Demo Window 23";
    {
        var box = try dvui.box(@src(), .horizontal, .{});
        defer box.deinit();
        //       if (try dvui.button(@src(), label, .{}, .{})) {
        //           dvui.Examples.show_demo_window = !dvui.Examples.show_demo_window;
        //       }
        //       if (try dvui.Theme.picker(@src(), .{})) {
        //           @memcpy(shared_mem.cli2ser[0.."theme changed".len], "theme changed");
        //       }
    }
    try dvui.Examples.demo();
    try ui.layout();
    //    const websocket_message: [7]u8 = .{ 0, 0, 3, 3, 4, 0, 0 };
    //    wasm_websocket_write((&websocket_message).ptr, websocket_message.len);

    //    if (new_content_scale) |ns| {
    //        win.content_scale = ns;
    //    }
}
