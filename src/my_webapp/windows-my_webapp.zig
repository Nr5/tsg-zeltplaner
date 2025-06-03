const std = @import("std");
const dvui = @import("dvui");
const websocket = @import("websocket.zig");
const ui = @import("ui.zig");
comptime {
    std.debug.assert(dvui.backend_kind == .dx11);
}
const Backend = dvui.backend;

const w = std.os.windows;
const HINSTANCE = w.HINSTANCE;
const LPWSTR = w.LPWSTR;
const INT = w.INT;

const window_icon_png = @embedFile("zig-favicon.png");

var gpa_instance = std.heap.GeneralPurposeAllocator(.{}){};
const gpa = gpa_instance.allocator();

const vsync = true;

var show_dialog_outside_frame: bool = false;

/// This example shows how to use the dvui for a normal application:
/// - dvui renders the whole application
/// - render frames only when needed
pub export fn main(
    instance: HINSTANCE,
    _: ?HINSTANCE,
    _: ?LPWSTR,
    cmd_show: INT,
) void {
    defer _ = gpa_instance.deinit();

    // init dx11 backend (creates and owns OS window)
    var backend = Backend.initWindow(instance, cmd_show, .{
        .allocator = gpa,
        .size = .{ .w = 800.0, .h = 600.0 },
        .min_size = .{ .w = 250.0, .h = 350.0 },
        .vsync = vsync,
        .title = "DVUI DX11 Standalone Example",
        .icon = window_icon_png, // can also call setIconFromFileContent()
    }) catch return;
    defer backend.deinit();

    Backend.setBackend(&backend);

    // init dvui Window (maps onto a single OS window)
    var win = dvui.Window.init(@src(), gpa, backend.backend(), .{}) catch return;
    defer win.deinit();

    Backend.setWindow(&win);
    websocket.win = &win;
    websocket.init() catch unreachable;    
    websocket.request_state(0);

    main_loop: while (true) {
        // This handles the main windows events
        if (Backend.isExitRequested()) {
            break :main_loop;
        }

        // beginWait coordinates with waitTime below to run frames only when needed
        const nstime = win.beginWait(backend.hasEvent());

        // marks the beginning of a frame for dvui, can call dvui functions after this
        win.begin(nstime) catch {};

        // both dvui and dx11 drawing
        gui_frame() catch {};

        // marks end of dvui frame, don't call dvui functions after this
        // - sends all dvui stuff to backend for rendering, must be called before renderPresent()
        _ = win.end(.{}) catch continue;

        // cursor management
        backend.setCursor(win.cursorRequested());

    }
}

fn gui_frame() !void {
    try ui.layout();
}
