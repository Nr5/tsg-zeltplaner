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
export fn anwesenheit_ptr() [*c]u8 {
    return @ptrCast(&zeltlager_data.anwesenheit_bitwise); }
export fn receive_websocket(len: usize) void {
    websocket.receive(shared_mem.ser2cli[0..len]);
}
export fn adjust_ptrs(n_teilnehmer: u32) void {
    zeltlager_data.adjust_ptrs(n_teilnehmer);
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

    const end_micros = try win.end(.{});

    backend.setCursor(win.cursorRequested());
    backend.textInputRect(win.textInputRequested());

    const wait_event_micros = win.waitTime(end_micros, null);
    return @intCast(@divTrunc(wait_event_micros, 1000));
}

fn dvui_frame() !void {
    {
        var box = try dvui.box(@src(), .horizontal, .{});
        defer box.deinit();
    }
    try dvui.Examples.demo();
    try ui.layout();
}
