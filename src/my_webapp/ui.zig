const builtin = @import("builtin");
const std = @import("std");
const dvui = @import("dvui");
const Options = dvui.Options;
const entypo = dvui.entypo;
const logging = @import("logging.zig");
const Zeltlager_Data = @import("zeltlager_data.zig");
const websocket = @import("websocket.zig");
const shared_mem = @import("shared_mem.zig");
var message_buf: [0x100]u8 = undefined;
var console_open: bool = false;
var open = false;
var woche: u3 = 0;
var anwesenheit: [2000]bool = undefined;
const selected_col: Options.ColorOrName = .{ .color = .{ .r = 0xa0, .g = 0xa0, .b = 0, .a = 0xff } };
const teilnehmer_icons: [8][]const u8 = .{ entypo.m1, entypo.m2, entypo.m3, entypo.m4, entypo.w1, entypo.w2, entypo.w3, entypo.w4 };
const icon_fields: [@typeInfo(entypo).@"struct".decls.len][]const u8 = blk: {
    var blah: [@typeInfo(entypo).@"struct".decls.len][]const u8 = undefined;
    for (@typeInfo(entypo).@"struct".decls, 0..) |d, i| {
        blah[i] = @field(entypo, d.name);
    }
    break :blk blah;
};
const icon_names: [@typeInfo(entypo).@"struct".decls.len][]const u8 = blk: {
    var blah: [@typeInfo(entypo).@"struct".decls.len][]const u8 = undefined;
    for (@typeInfo(entypo).@"struct".decls, 0..) |d, i| {
        blah[i] = d.name;
    }
    break :blk blah;
};
const I_Tid = struct { i: u32, id: u32 };
var hovered_t: I_Tid = .{ .i = 0xffff, .id = 0xffff };
var grabbed_t: I_Tid = .{ .i = 0xffff, .id = 0xffff };
var clicked_t: I_Tid = .{ .i = 0xffff, .id = 0xffff };
var dragged_t: I_Tid = .{ .i = 0xffff, .id = 0xffff };
const no_t: I_Tid = .{ .i = 0xffff, .id = 0xffff };
var hovered_tent: usize = 0xffff;
var draggedover_tent: usize = 0xffff;
var clicked_tent: usize = 0xffff;
var view_mode: u4 = 0;
var mousex: f32 = 0;
var mousey: f32 = 0;
var refresh = false;
var mainbox: *dvui.BoxWidget = undefined;
var paned_collapsed_width: f32 = 0.0;
var framenr: u16 = 0;
var filterinput: []u8 = undefined;
const teilnehmerstring = "alex fischer";
var only_female = false;
var only_male = false;
fn get_teilnehmer_by_id(id: u16) *Zeltlager_Data.Teilnehmer {
    for (&Zeltlager_Data.teilnehmer_list) |*t| {
        if (t.*.id == id) return t;
    }
    return &Zeltlager_Data.teilnehmer_list[0];
}
fn get_teilnehmer_index_by_id(id: u16) u16 {
    for (&Zeltlager_Data.teilnehmer_list, 0..) |*t, i| {
        if (t.*.id == id) return @truncate(i);
    }
    return 0;
}

fn teilnehmer_element(src: std.builtin.SourceLocation, index: u16, id_extra: u8) !void {
    var extra: u32 = index;
    extra = extra << 12;
    extra = extra + id_extra << 2;
    const teilnehmer = Zeltlager_Data.teilnehmer_list[index];
    const col: Options.ColorOrName =
        if (clicked_t.i == index) selected_col else if (hovered_t.i == index) .{ .name = .fill_hover } else if (grabbed_t.i == index) .{ .name = .fill_press } else .{ .name = .fill };
    const labelbox = try dvui.box(src, .horizontal, .{
        .margin = .{ .x = 2, .w = 2, .y = 1, .h = 1 },
        .padding = .{ .x = 2 },
        .color_fill = col,
        .id_extra = extra + 0,
        .background = true,
        .expand = .horizontal,
    });
    _ = try dvui.icon(src, "", teilnehmer_icons[teilnehmer.altersgruppe - 1], .{ .id_extra = extra + 1, .gravity_y = 0.5 });
    _ = try dvui.label(src, "{s} {s}", .{ teilnehmer.vorname, teilnehmer.nachname }, .{ .id_extra = extra + 2, .expand = .horizontal, .background = false });
    //_ = try dvui.label(src, fmt, data, .{
    //    .id_extra = 2,
    //    .padding = .{ .x = 5, .y = 2, .h = 2 },
    //});
    const evts = dvui.events();
    for (evts) |*e| {
        if (!dvui.eventMatchSimple(e, labelbox.data())) {
            continue;
        }

        switch (e.evt) {
            .mouse => |me| {
                mousex = me.p.x;
                mousey = me.p.y;
                //            const i:u16 = @as(u16,@intFromFloat((mousex - 10) / 36)) + @as(u16,@intFromFloat((mousey-80) / 36))*12;

                if (me.action == .press) {
                    e.handled = true;
                    //dvui.captureMouse(dbox.data().id);
                    if (hovered_t.i < index) {
                        refresh = true;
                    }
                    grabbed_t = .{ .i = index, .id = teilnehmer.id };

                    hovered_t = no_t;

                    mousex = me.p.x;
                    mousey = me.p.y;
                } else if (me.action == .release) {
                    e.handled = true;
                    if (dragged_t.i != no_t.i) {
                        const tid = teilnehmer.id;
                        websocket.drop(tid);
                        dragged_t = no_t;
                    }
                    if (grabbed_t.i < index) {
                        refresh = true;
                    }
                    if (grabbed_t.i == index) {
                        clicked_t = if (clicked_t.i == index) no_t else grabbed_t;
                        refresh = true;
                    }
                    grabbed_t = no_t;
                    hovered_t = .{ .i = index, .id = Zeltlager_Data.teilnehmer_list[index].id };
                    //dvui.captureMouse(null);
                } else if (me.action == .position) {
                    e.handled = true;
                    if (grabbed_t.i == no_t.i) {
                        if (hovered_t.i < index) {
                            refresh = true;
                        }
                        hovered_t.i = index;
                    }
                    mousex = me.p.x;
                    mousey = me.p.y;
                } else if (me.action == .motion) {
                    if (grabbed_t.i != no_t.i and dragged_t.i == no_t.i) {
                        dragged_t = grabbed_t;
                        websocket.grab(dragged_t.id);
                    }
                }
            },
            else => {},
        }
    }
    labelbox.deinit();
}
pub fn teilnehmer_pane() !void {
    framenr += 1;
    var invalidate = false;
    if (dvui.events().len > 0) invalidate = true;
    var vbox = try dvui.box(@src(), .vertical, .{ .expand = .both, .background = true, .color_fill = .{ .name = .fill_control } });
    defer vbox.deinit();
    {
        var headerbox = try dvui.box(@src(), .horizontal, .{});
        defer headerbox.deinit();
        //        var val: [64]u8 = undefined;
        var te = try dvui.textEntry(@src(), .{}, .{});
        te.deinit();

        var bf = dvui.ButtonWidget.init(@src(), .{}, .{ .padding = .{ .y = 1, .h = 1 }, .margin = .{ .h = 0, .y = 0 }, .expand = .horizontal, .background = true });
        try bf.install();
        bf.processEvents();
        try bf.drawBackground();
        try bf.drawFocus();
        var col: Options.ColorOrName = if (only_female) selected_col else .{ .name = .text };
        if (bf.clicked()) {
            only_male = false;
            only_female = !only_female;
        }
        _ = try dvui.icon(@src(), "", entypo.female, .{ .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 }, .margin = .{ .x = 2, .y = 2, .w = 2, .h = 2 }, .color_text = col, .background = false, .border = dvui.Rect.all(0.8) });
        bf.deinit();
        var bm = dvui.ButtonWidget.init(@src(), .{}, .{ .padding = .{ .y = 1, .h = 1 }, .margin = .{ .h = 0, .y = 0 }, .expand = .horizontal, .background = true });
        try bm.install();
        bm.processEvents();
        try bm.drawBackground();
        try bm.drawFocus();
        col = if (only_male) selected_col else .{ .name = .text };
        if (bm.clicked()) {
            only_female = false;
            only_male = !only_male;
        }
        _ = try dvui.icon(@src(), "", entypo.male, .{ .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 }, .margin = .{ .x = 2, .y = 2, .w = 2, .h = 2 }, .color_text = col, .background = false, .border = dvui.Rect.all(0.8) });
        bm.deinit();

        for (0..7) |i| {
            if (try dvui.button(@src(), switch (i) {
                0 => "1",
                1 => "2",
                2 => "3",
                3 => "4",
                4 => "5",
                5 => "6",
                6 => "alle",
                else => unreachable,
            }, .{}, .{ .id_extra = i, .border = dvui.Rect.all(0.8) })) {
                woche = @truncate(i);
            }
        }
        if (try dvui.button(@src(), "ansicht", .{}, .{ .border = dvui.Rect.all(0.8) })) {
            open = !open;
        }

        _ = try dvui.label(@src(), "frame: {}, version: {}", .{ framenr, websocket.version }, .{});
        filterinput = te.text[0..te.len];
    }
    {
        //        var scrollbox = try dvui.paned(@src(), .{ .direction = .vertical, .collapsed_size = paned_collapsed_width }, .{ .expand = .both, .background = true, .min_size_content = .{ .h = 100 }, .border = dvui.Rect.all(1) });
        var scrollbox = try dvui.box(@src(), .vertical, .{ .expand = .both, .background = true, .min_size_content = .{ .h = 100 }, .border = dvui.Rect.all(1) });
        //        scrollbox.split_ratio = if (clicked_t.i == 0xffff) 0.9 else 0.5;
        defer scrollbox.deinit();
        try teilnehmerinfo_pane();

        {
            var scrollarea = try dvui.scrollArea(@src(), .{}, .{
                .expand = .horizontal,
            });

            defer scrollarea.deinit();
            {

                //    const cache = try dvui.cache(@src(), .{ .invalidate = true }, .{ .expand = .both });
                //     _ = cache.uncached();
                //   defer cache.deinit();
                var tp = try dvui.box(@src(), .vertical, .{ .expand = .horizontal, .background = true, .padding = .{ .x = 40 }, .margin = .{ .w = 10 } });
                defer tp.deinit();
                {
                    var fbox = try dvui.flexbox(@src(), .{}, .{ .gravity_x = 0, .border = dvui.Rect.all(1), .background = true, .padding = .{ .w = 4, .h = 4 }, .expand = .horizontal });
                    defer fbox.deinit();
                    for (0..Zeltlager_Data.n_teilnehmer) |i| {
                        //        for (icon_names, icon_fields, 0..) |name, f, i| {

                        //_ = f;
                        const teilnehmer = Zeltlager_Data.teilnehmer_list[i];
                        if (filterinput.len > 0) {
                            var name_buf: [128]u8 = undefined;
                            var name = try std.fmt.bufPrint(&name_buf, "{s} {s}", .{ teilnehmer.vorname, teilnehmer.nachname });
                            for (0..name.len) |c| {
                                if (name[c] >= 'A' and name[c] <= 'Z' or
                                    name[c] == "Ä"[1] or name[c] == "Ö"[1] or name[c] == "Ü"[1]) name[c] |= 0x20;
                            }
                            for (0..filterinput.len) |c| {
                                if (filterinput[c] >= 'A' and filterinput[c] <= 'Z' or
                                    filterinput[c] == "Ä"[1] or filterinput[c] == "Ö"[1] or filterinput[c] == "Ü"[1]) filterinput[c] |= 0x20;
                            }
                            //for (&filterinput) |*c| c.* &= 0x3f;
                            const contains = std.mem.count(u8, name, filterinput) > 0;

                            //_ = try dvui.label(@src(),"{s} {}",.{vorname, contains},.{});

                            if (!contains) {
                                continue;
                                //hovered_t.i = i;
                            }
                        }
                        if ((only_male and teilnehmer.geschlecht[0] == 'w') or
                            (only_female and teilnehmer.geschlecht[0] == 'm')) continue;
                        if (woche < 6 and teilnehmer.startwoche != woche) continue;
                        const field = if (teilnehmer.altersgruppe > 0 and teilnehmer.altersgruppe < 9)
                            teilnehmer_icons[teilnehmer.altersgruppe - 1]
                        else
                            teilnehmer_icons[0];

                        //            var buf: [100]u8 = undefined;
                        //            const text = try std.fmt.bufPrint(&buf, "entypo.{s}", .{name});
                        const dbox =
                            if (!open) try dvui.box(@src(), .vertical, .{ .min_size_content = .{ .w = 50, .h = 50 }, .max_size_content = .{ .w = 50, .h = 50 }, .id_extra = i }) else try dvui.box(@src(), .horizontal, .{ .min_size_content = .{ .h = 50, .w = 200 }, .max_size_content = .{ .h = 50, .w = 200 }, .expand = .horizontal, .id_extra = i });
                        defer dbox.deinit();
                        const evts = dvui.events();
                        for (evts) |*e| {
                            if (!dvui.eventMatchSimple(e, dbox.data())) {
                                continue;
                            }

                            switch (e.evt) {
                                .mouse => |me| {
                                    mousex = me.p.x;
                                    mousey = me.p.y;
                                    //            const i:u16 = @as(u16,@intFromFloat((mousex - 10) / 36)) + @as(u16,@intFromFloat((mousey-80) / 36))*12;

                                    if (me.action == .press) {
                                        e.handled = true;
                                        //dvui.captureMouse(dbox.data().id);
                                        if (hovered_t.i < i) {
                                            refresh = true;
                                        }
                                        grabbed_t = .{ .i = i, .id = Zeltlager_Data.teilnehmer_list[i].id };

                                        hovered_t = no_t;

                                        mousex = me.p.x;
                                        mousey = me.p.y;
                                    } else if (me.action == .release) {
                                        e.handled = true;
                                        if (dragged_t.i != no_t.i) {
                                            const tid = Zeltlager_Data.teilnehmer_list[dragged_t.i].id;
                                            websocket.drop(tid);
                                            dragged_t = no_t;
                                        }
                                        if (grabbed_t.i < i) {
                                            refresh = true;
                                        }
                                        if (grabbed_t.i == i) {
                                            clicked_t = if (clicked_t.i == i) no_t else grabbed_t;
                                            refresh = true;
                                        }
                                        grabbed_t = no_t;
                                        hovered_t = .{ .i = i, .id = Zeltlager_Data.teilnehmer_list[i].id };
                                        //dvui.captureMouse(null);
                                    } else if (me.action == .position) {
                                        e.handled = true;
                                        if (grabbed_t.i == no_t.i) {
                                            if (hovered_t.i < i) {
                                                refresh = true;
                                            }
                                            hovered_t.i = i;
                                        }
                                        mousex = me.p.x;
                                        mousey = me.p.y;
                                    } else if (me.action == .motion) {
                                        if (grabbed_t.i != no_t.i and dragged_t.i == no_t.i) {
                                            dragged_t = grabbed_t;
                                            websocket.grab(dragged_t.id);
                                        }
                                    }
                                },
                                else => {},
                            }
                        }
                        const col: Options.ColorOrName =
                            if (clicked_t.i == i) selected_col else if (hovered_t.i == i) .{ .name = .fill_hover } else if (grabbed_t.i == i) .{ .name = .fill_press } else .{ .name = .fill };

                        _ = try dvui.icon(@src(), "", field, .{ .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 }, .min_size_content = .{ .h = 45 }, .margin = .{ .x = 2, .y = 2, .w = 2, .h = 2 }, .expand = .ratio, .color_fill = col, .color_fill_hover = .{ .name = .err }, .border = dvui.Rect.all(1), .background = true });
                        if (open) {
                            _ = try dvui.label(@src(), "{s} {s}", .{ teilnehmer.vorname, teilnehmer.nachname }, .{ .gravity_y = 0.5, .expand = .both, .color_fill = col, .background = true });
                        }
                    }
                }
            }
        }
    }
}
inline fn label_with_icon(src: std.builtin.SourceLocation, fmt: []const u8, data: anytype, icon: []const u8, id_extra: usize) !void {
    const labelbox = try dvui.box(src, .horizontal, .{
        .margin = .{ .x = 10 },
        .color_fill = .{ .name = .err },
        .id_extra = id_extra * 3 + 0,
    });
    _ = try dvui.icon(src, "", icon, .{ .id_extra = id_extra * 3 + 1, .gravity_y = 0.5 });
    var tl_caption = try dvui.textLayout(src, .{}, .{ .id_extra = id_extra * 3 + 2, .expand = .horizontal, .background = false });
    try tl_caption.format(fmt, data, .{});
    tl_caption.deinit();
    //_ = try dvui.label(src, fmt, data, .{
    //    .id_extra = 2,
    //    .padding = .{ .x = 5, .y = 2, .h = 2 },
    //});
    labelbox.deinit();
}
pub fn teilnehmerinfo_pane() !void {
    var tinfo = try dvui.box(@src(), .vertical, .{ .gravity_y = 1, .expand = .horizontal, .background = true, .color_fill = .{ .name = .fill_control } });
    const viewed_i = if (clicked_t.i != no_t.i) clicked_t.i else if (grabbed_t.i != no_t.i) grabbed_t.i else if (hovered_t.i != no_t.i) hovered_t.i else no_t.i;
    if (viewed_i < no_t.i) {
        const teilnehmer = &Zeltlager_Data.teilnehmer_list[viewed_i];

        if (clicked_t.i != no_t.i) {
            //    var b = try dvui.button(@src(), .vertical, .{ .expand = .horizontal, .background = true, });
            var bw = dvui.ButtonWidget.init(@src(), .{}, .{ .padding = .{ .y = 1, .h = 1 }, .margin = .{ .h = 0, .y = 0 }, .expand = .horizontal, .background = true });
            try bw.install();
            bw.processEvents();
            try bw.drawBackground();
            try bw.drawFocus();
            _ = try dvui.icon(@src(), "down", entypo.chevron_with_circle_down, .{ .gravity_x = 0.5 });
            if (bw.clicked()) {
                clicked_t = no_t;
                refresh = true;
            }
            bw.deinit();
        }
        const headerbox = try dvui.box(@src(), .horizontal, .{ .expand = .horizontal });
        _ = try dvui.icon(@src(), "", teilnehmer_icons[teilnehmer.altersgruppe - 1], .{ .min_size_content = .{ .h = 45 } });
        _ = try dvui.label(@src(), "{s} {s} {} {} {} {} {}", .{ teilnehmer.*.vorname, teilnehmer.*.nachname, teilnehmer.id, viewed_i, teilnehmer.Zelte_id, teilnehmer.startwoche, teilnehmer.endwoche }, .{ .font_style = .title });
        _ = try dvui.icon(@src(), "", if (teilnehmer.*.schwimmbefaehigung[0] == 'T') entypo.seahorse else entypo.no_seahorse, .{
            .margin = .{
                .w = 0,
            },
            .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 },
            .min_size_content = .{ .h = 40, .w = 40 },
            .gravity_x = 1,
            .background = false,
        });
        _ = try dvui.icon(@src(), "", if (teilnehmer.*.bade_erlaubnis[0] == 'T') entypo.swimming else entypo.no_swimming, .{
            .margin = .{
                .w = 0,
            },
            .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 },
            .min_size_content = .{ .h = 40, .w = 40 },
            .gravity_x = 1,
            .background = false,
        });
        headerbox.deinit();
        if (clicked_t.i < no_t.i) {
            //            var fbox = try dvui.flexbox(@src(), .{}, .{ .gravity_x = 0, .border = dvui.Rect.all(1), .background = true, .padding = .{ .w = 4, .h = 4 }, .expand = .both });
            //           defer fbox.deinit();

            var horizontal_box = try dvui.box(@src(), .horizontal, .{ .expand = .horizontal });
            defer horizontal_box.deinit();
            {
                var left_box = try dvui.box(@src(), .vertical, .{ .expand = .both });
                defer left_box.deinit();
                var details_box1 = try dvui.box(@src(), .vertical, .{ .expand = .horizontal, .gravity_x = 0, .background = true });
                _ = try dvui.label(@src(), "{s}\n{s}", .{ teilnehmer.*.geburtsdatum, teilnehmer.*.anschrift }, .{ .font_style = .title_2 });
                details_box1.deinit();

                var details_box4 = try dvui.box(@src(), .vertical, .{ .expand = .both, .background = true, .padding = .{ .h = 5 }, .margin = .{ .y = 5 } });
                _ = try label_with_icon(@src(), "{s},00 €", .{teilnehmer.*.taschengeld}, entypo.credit, 0);
                var strbuf: [256]u8 = undefined;
                var sbuf_len: usize = 0;
                for (teilnehmer.*.allergien) |c| {
                    const slice = try std.fmt.bufPrint(strbuf[sbuf_len..], "{s}, ", .{switch (c) {
                        'A' => "Gluten",
                        'B' => "Krebstiere",
                        'C' => "Eier",
                        'D' => "Fisch",
                        'E' => "Erdnüsse",
                        'F' => "Soja",
                        'G' => "Milch",

                        'H' => "Schalenfrüchte",
                        'L' => "Sellerie",
                        'M' => "Senf",
                        'N' => "Sesamsamen",
                        'O' => "Sulfite",
                        'P' => "Lupinen",
                        'R' => "Weichtiere",
                        'V' => "Vegan",
                        'W' => "Vegetarisch",
                        else => "",
                    }});
                    sbuf_len += slice.len;
                }
                if (sbuf_len == 0) sbuf_len = 2;
                _ = try label_with_icon(@src(), "{s}", .{strbuf[0 .. sbuf_len - 2]}, entypo.biohazard, 0);
                _ = try label_with_icon(@src(), "{s}", .{teilnehmer.tshirt_groesse}, entypo.shirt, 0);
                _ = try label_with_icon(@src(), "{s}", .{teilnehmer.besonderheiten}, entypo.info, 0);

                details_box4.deinit();
            }
            {
                var right_box = try dvui.box(@src(), .vertical, .{ .padding = .{ .x = 5, .h = 5 }, .gravity_x = 1 });
                defer right_box.deinit();
                var details_box2 = try dvui.box(@src(), .vertical, .{ .expand = .horizontal, .gravity_x = 1, .background = true });
                _ = try dvui.label(@src(), "{s} {s}", .{ teilnehmer.*.anmelder_vorname, teilnehmer.*.anmelder_nachname }, .{ .font_style = .title_3 });
                {
                    const labelbox = try dvui.box(@src(), .horizontal, .{
                        .margin = .{ .x = 10 },
                        .color_fill = .{ .name = .err },
                    });
                    _ = try dvui.icon(@src(), "", entypo.old_phone, .{ .id_extra = 1, .gravity_y = 0.5 });
                    if (try dvui.labelClick(@src(), "{s}", .{teilnehmer.*.anmelder_telefon}, .{
                        .gravity_y = 0.5,
                        .color_text = .{ .color = .{ .r = 0x35, .g = 0x84, .b = 0xe4 } },
                    })) {
                        var buf: [30]u8 = undefined;
                        const slice = try std.fmt.bufPrint(&buf, "{s}{s}", .{ "tel:", teilnehmer.*.anmelder_telefon });
                        try dvui.openURL(slice);
                    }
                    var bf = dvui.ButtonWidget.init(@src(), .{}, .{ .padding = .{ .y = 1, .h = 1 }, .margin = .{ .h = 0, .y = 0 }, .expand = .horizontal, .background = false });
                    try bf.install();
                    bf.processEvents();
                    try bf.drawBackground();
                    try bf.drawFocus();
                    if (bf.clicked()) {
                        _ = try dvui.clipboardTextSet(teilnehmer.anmelder_telefon);
                    }
                    _ = try dvui.icon(@src(), "", entypo.copy, .{ .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 }, .margin = .{ .x = 2, .y = 2, .w = 2, .h = 2 }, .background = false });
                    bf.deinit();
                    labelbox.deinit();
                }
                {
                    const labelbox = try dvui.box(@src(), .horizontal, .{
                        .margin = .{ .x = 10 },
                        .color_fill = .{ .name = .err },
                    });
                    _ = try dvui.icon(@src(), "", entypo.email, .{ .id_extra = 1, .gravity_y = 0.5 });
                    if (try dvui.labelClick(@src(), "{s}", .{teilnehmer.*.anmelder_email}, .{
                        .gravity_y = 0.5,
                        .color_text = .{ .color = .{ .r = 0x35, .g = 0x84, .b = 0xe4 } },
                    })) {
                        var buf: [120]u8 = undefined;
                        const slice = try std.fmt.bufPrint(&buf, "{s}{s}", .{ "mailto:", teilnehmer.*.anmelder_email });
                        try dvui.openURL(slice);
                    }
                    var bf = dvui.ButtonWidget.init(@src(), .{}, .{ .padding = .{ .y = 1, .h = 1 }, .margin = .{ .h = 0, .y = 0 }, .expand = .horizontal, .background = false });
                    try bf.install();
                    bf.processEvents();
                    try bf.drawBackground();
                    try bf.drawFocus();
                    if (bf.clicked()) {
                        _ = try dvui.clipboardTextSet(teilnehmer.anmelder_email);
                    }
                    _ = try dvui.icon(@src(), "", entypo.copy, .{ .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 }, .margin = .{ .x = 2, .y = 2, .w = 2, .h = 2 }, .background = false });
                    bf.deinit();

                    labelbox.deinit();
                }
                details_box2.deinit();
                var details_box3 = try dvui.box(@src(), .vertical, .{ .expand = .both, .gravity_x = 1, .background = true, .padding = .{ .h = 5 }, .margin = .{ .y = 5, .h = 5 } });
                if (teilnehmer.Zelte_id < 55) {
                    for (Zeltlager_Data.zelte[teilnehmer.*.Zelte_id].teilnehmer[0..Zeltlager_Data.zelte[teilnehmer.*.Zelte_id].n_teilnehmer]) |tid| {
                        const index = get_teilnehmer_index_by_id(@truncate(tid));
                        _ = try teilnehmer_element(@src(), index, 1);
                    }
                }
                details_box3.deinit();
            }
        }
        // = try dvui.label(@src(),"{s} {s}",.{teilnehmer.*.vorname, teilnehmer.*.nachname},.{.font_style = .title});

        //            _ = try dvui.label(@src(),"{s}",.{teilnehmer.besonderheiten}, .{.font_style = .title_});
    }

    //const evts = dvui.events();

    //for (evts) |*e| {
    //    if (!dvui.eventMatchSimple(e, tinfo.data())) {
    //        continue;
    //    }
    //    //        e.handled = true;
    //}
    //
    tinfo.deinit();
}

pub fn tent_pane() !void {
    var pane = try dvui.box(@src(), .vertical, .{});
    defer pane.deinit();
    var fbox = try dvui.flexbox(@src(), .{}, .{
        .gravity_x = 0,
        .border = dvui.Rect.all(1),
        .background = true,
        .padding = .{ .w = 4, .h = 4 },
        .expand = .both,
    });

    const active_i: u32 = @intCast(@as(i32, -0xffff) + @as(i32, @intCast(hovered_t.i + grabbed_t.i)));
    if (active_i < no_t.i) hovered_tent = Zeltlager_Data.teilnehmer_list[active_i].Zelte_id;
    for (1..56) |i| {
        const occupation = Zeltlager_Data.zelte[i].n_teilnehmer;
        const col2: dvui.Options.ColorOrName =
            if (clicked_tent == i) selected_col else if (draggedover_tent == i and occupation == 7) .{ .name = .err } else if (hovered_tent == i or draggedover_tent == i) .{ .name = .fill_hover } else if (active_i < no_t.i and Zeltlager_Data.teilnehmer_list[active_i].Zelte_id == i) .{ .name = .fill_hover } else .{ .name = .fill };

        var labelbox = try dvui.box(@src(), .vertical, .{ .id_extra = i, .margin = .{ .x = 4, .y = 4 }, .border = dvui.Rect.all(1), .color_fill = col2, .background = true });

        defer labelbox.deinit();
        {
            var tenticonbox = try dvui.box(@src(), .vertical, .{ .id_extra = i, .margin = .{ .x = 4, .y = 4 }, .background = false });
            defer tenticonbox.deinit();
            _ = try dvui.icon(@src(), "", entypo.home, .{
                .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 },
                .min_size_content = .{ .h = 40 },
            });
            //if (Zeltlager_Data.zelte[i].n_teilnehmer > 0) {
            //    const teilnehmer = get_teilnehmer_by_id(@truncate(Zeltlager_Data.zelte[i].teilnehmer[0]));
            //    var rect = tenticonbox.childRect;
            //    rect.x += 22;
            //    rect.w -= 28;
            //    rect.y -= 50;
            //    //                rect.h += 10;
            //    _ = try dvui.icon(@src(), "", teilnehmer_icons[teilnehmer.altersgruppe - 1], .{
            //        .rect = rect,
            //    });
            //}
        }
        {
            var tentoccupationbox = try dvui.box(@src(), .horizontal, .{ .id_extra = i + 55, .margin = .{ .x = 4, .y = 4 }, .background = true });
            defer tentoccupationbox.deinit();
            const col: dvui.Color = switch (occupation) {
                0...3 => .{ .r = 0xc0, .g = 0x00, .b = 0x00, .a = 0xff },
                4, 7 => .{ .r = 0xc0, .g = 0xc0, .b = 0x20, .a = 0xff },
                else => .{ .r = 0x00, .g = 0xff, .b = 0x80, .a = 0xff },
            };

            for (0..occupation) |j| {
                var b = try dvui.box(@src(), .horizontal, .{ .id_extra = j, .background = true, .margin = .{
                    .w = 3,
                }, .min_size_content = .{ .h = 5, .w = 5 }, .color_fill = .{ .color = col } });
                b.deinit();
            }
            for (occupation..7) |j| {
                var b = try dvui.box(@src(), .horizontal, .{ .id_extra = j, .background = true, .margin = .{
                    .w = 3,
                }, .min_size_content = .{ .h = 5, .w = 5 }, .color_fill = .{ .color = .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xff } } });
                b.deinit();
            }
        }
        const evts = dvui.events();
        for (evts) |*e| {
            if (!dvui.eventMatchSimple(e, labelbox.data())) {
                continue;
            }
            // e.handled= (grabbed_t.i < 0xffff) ;
            //hovered_tent = 0xffff;
            //if (grabbed_t.i < 0xffff) {
            switch (e.evt) {
                .mouse => |me| {
                    e.handled = true;
                    if (me.action == .press) {
                        clicked_tent = if (clicked_tent == i) 0xffff else i;
                    } else if (me.action == .position) {
                        mousex = me.p.x;
                        mousey = me.p.y;
                        if (hovered_tent != i) {
                            refresh = true;
                        }
                        hovered_tent = i;
                        if (grabbed_t.i != no_t.i) draggedover_tent = hovered_t.i;
                    } else if (me.action == .motion) {
                        if (grabbed_t.i != no_t.i and dragged_t.i == no_t.i) {
                            dragged_t.i = grabbed_t.i;
                            const tid = Zeltlager_Data.teilnehmer_list[dragged_t.i].id;
                            websocket.grab(tid);
                        }
                    } else if (me.action == .release) {
                        if (dragged_t.i != no_t.i) {
                            const tid = Zeltlager_Data.teilnehmer_list[dragged_t.i].id;
                            const from = Zeltlager_Data.teilnehmer_list[dragged_t.i].Zelte_id;
                            websocket.zeltchange(tid, from, i);

                            websocket.drop(tid);
                            dragged_t = no_t;
                        }
                        refresh = true;
                        mousex = me.p.x;
                        mousey = me.p.y;
                        hovered_tent = 0xffff;
                        grabbed_t = no_t;
                    }
                },
                else => {},
            }
            //}
        }
    }
    fbox.deinit();
    const member_fbox = try dvui.flexbox(@src(), .{}, .{});

    if (clicked_tent < 0xffff) {
        var tentmember = try dvui.box(@src(), .vertical, .{ .margin = .{ .w = 20 }, .border = dvui.Rect.all(1), .color_border = selected_col });
        defer tentmember.deinit();

        for (Zeltlager_Data.zelte[clicked_tent].teilnehmer[0..Zeltlager_Data.zelte[clicked_tent].n_teilnehmer]) |tid| {
            var box = try dvui.box(@src(), .horizontal, .{ .id_extra = tid });
            defer box.deinit();
            const index = get_teilnehmer_index_by_id(@truncate(tid));
            _ = try dvui.checkbox(@src(), &anwesenheit[index], "", .{});
            _ = try teilnehmer_element(@src(), index, 0);
        }
    }
    if (hovered_tent < 55 and hovered_tent != clicked_tent) {
        var tentmember = try dvui.box(@src(), .vertical, .{ .border = dvui.Rect.all(1) });
        defer tentmember.deinit();
        for (Zeltlager_Data.zelte[hovered_tent].teilnehmer[0..Zeltlager_Data.zelte[hovered_tent].n_teilnehmer]) |tid| {
            var box = try dvui.box(@src(), .horizontal, .{ .id_extra = tid });
            defer box.deinit();
            const index = get_teilnehmer_index_by_id(@truncate(tid));
            _ = try dvui.checkbox(@src(), &anwesenheit[index], "", .{});
            _ = try teilnehmer_element(@src(), index, 0);
        }
    }
    member_fbox.deinit();
}
fn allergies_pane() !void {
    var scrollbox = try dvui.scrollArea(@src(), .{}, .{ .expand = .both });
    defer scrollbox.deinit();
    var fbox = try dvui.flexbox(@src(), .{}, .{ .gravity_x = 0, .padding = .{ .w = 4, .h = 4 }, .expand = .horizontal });
    defer fbox.deinit();
    for (Zeltlager_Data.allergien) |a| {
        //      logging.log("{s}: {}\n", .{a.bezeichnung, a.n_teilnehmer}) catch unreachable;
        const box = try dvui.box(@src(), .vertical, .{ .id_extra = a.key, .margin = .{ .x = 3, .y = 3, .w = 2, .h = 2 }, .padding = .{ .x = 1, .y = 1, .w = 1, .h = 1 }, .border = dvui.Rect.all(1), .background = true });
        defer box.deinit();
        _ = try dvui.label(@src(), "{s} ({c})", .{ a.bezeichnung, a.key }, .{ .font_style = .title_3, .id_extra = a.key, .expand = .horizontal, .background = false });
        for (a.teilnehmer[0..a.n_teilnehmer]) |tid| {
            const index = get_teilnehmer_index_by_id(tid);
            _ = try teilnehmer_element(@src(), index, a.key);
        }
    }
    //   'A' => "Gluten",
    //   'B' => "Krebstiere",
    //   'C' => "Eier",
    //   'D' => "Fisch",
    //   'E' => "Erdnüsse",
    //   'F' => "Soja",
    //   'G' => "Milch",
    //
    //   'H' => "Schalenfrüchte",
    //   'L' => "Sellerie",
    //   'M' => "Senf",
    //   'N' => "Sesamsamen",
    //   'O' => "Sulfite",
    //   'P' => "Lupinen",
    //   'R' => "Weichtiere",
    //   'V' => "Vegan",
    //   'W' => "Vegetarisch",
}
pub fn layout() !void {
    mainbox = try dvui.box(@src(), .vertical, .{ .expand = .both, .background = true });
    defer mainbox.deinit();
    if (console_open) {
        var console = try dvui.scrollArea(@src(), .{}, .{
            .expand = .both,
            .margin = .{ .x = 5, .y = 5, .w = 20, .h = 5 },
            .min_size_content = .{ .h = 100 },
            .max_size_content = .{ .h = 200 },
        });
        console.si.scrollToFraction(.vertical, 1);
        var console_text = try dvui.textLayout(@src(), .{}, .{ .expand = .both, .background = false });
        _ = try console_text.addText(logging.log_buf[0..logging.log_buf_len], .{});
        //    console.scrollinfo.scrollToOffset(.vertical,1000);
        console_text.deinit();
        console.deinit();
    }
    //        var message: []u8 = message_buf[0..0];
    {
        var paned = try dvui.paned(@src(), .{ .direction = .horizontal, .collapsed_size = paned_collapsed_width }, .{ .expand = .both, .background = true, .min_size_content = .{ .h = 100 }, .border = dvui.Rect.all(1) });
        defer paned.deinit();
        //        paned.split_ratio = 2.0/3.0;
        try teilnehmer_pane();
        const right_box = try dvui.box(@src(), .vertical, .{ .expand = .both });
        const tabbar = try dvui.box(@src(), .horizontal, .{ .expand = .horizontal, .gravity_y = 1 });
        var col: Options.ColorOrName = if (view_mode == 0) selected_col else .{ .name = .text };

        var bf0 = dvui.ButtonWidget.init(@src(), .{}, .{ .padding = .{ .y = 1, .h = 1 }, .margin = .{ .h = 0, .y = 0 }, .expand = .horizontal, .background = true });
        try bf0.install();
        bf0.processEvents();
        try bf0.drawBackground();
        try bf0.drawFocus();
        if (bf0.clicked()) {
            view_mode = 0;
        }
        _ = try dvui.icon(@src(), "", entypo.home, .{ .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 }, .margin = .{ .x = 2, .y = 2, .w = 2, .h = 2 }, .color_text = col, .background = false });
        bf0.deinit();
        var bf1 = dvui.ButtonWidget.init(@src(), .{}, .{ .padding = .{ .y = 1, .h = 1 }, .margin = .{ .h = 0, .y = 0 }, .expand = .horizontal, .background = true });
        try bf1.install();
        bf1.processEvents();
        try bf1.drawBackground();
        try bf1.drawFocus();
        if (bf1.clicked()) {
            view_mode = 1;
        }

        col = if (view_mode == 1) selected_col else .{ .name = .text };
        _ = try dvui.icon(@src(), "", entypo.biohazard, .{ .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 }, .margin = .{ .x = 2, .y = 2, .w = 2, .h = 2 }, .color_text = col, .background = false });

        bf1.deinit();
        tabbar.deinit();

        switch (view_mode) {
            0 => try tent_pane(),
            1 => try allergies_pane(),
            else => unreachable,
        }

        right_box.deinit();
        const evts = dvui.events();
        //    if (grabbed_t.i < 0xffff){
        for (evts) |*e| {
            if (!dvui.eventMatchSimple(e, paned.data())) {
                continue;
            }

            e.handled = true;
            switch (e.evt) {
                .mouse => |me| {
                    if (me.action == .release) {
                        if (dragged_t.i < no_t.i) {
                            const tid = Zeltlager_Data.teilnehmer_list[dragged_t.i].id;
                            websocket.drop(tid);
                            dragged_t = no_t;
                        }
                        //                    message= try std.fmt.bufPrint(&message_buf,"drop",.{});
                        //if (grabbed_t.i < 0xffff or hovered_t.i < 0xffff or hovered_tent < 0xffff){
                        grabbed_t = no_t;
                        hovered_t = no_t;
                        hovered_tent = 0xffff;

                        refresh = true;
                        //dragged_t.i = no_t;
                        // }
                    } else if (me.action == .position) {
                        mousex = me.p.x;
                        mousey = me.p.y;
                        hovered_tent = 0xffff;
                        //               refresh =true ;
                        hovered_t = no_t;
                        //}
                    } else if (me.action == .motion) {
                        if (grabbed_t.i < no_t.i and dragged_t.i == no_t.i) {
                            dragged_t = grabbed_t;
                            const tid = Zeltlager_Data.teilnehmer_list[dragged_t.i].id;
                            websocket.grab(tid);
                        }
                    }
                },
                else => {},
            }
            //   }
        }
    }
    //   var si: dvui.ScrollInfo = undefined;

    const evts = dvui.events();
    //    if (grabbed_t.i < 0xffff){
    //    console_open = true;
    for (evts) |*e| {
        //switch (e.evt) {
        //    .key => |ke| {
        //        _ = ke;
        //        switch (e.evt.key.action) {
        if (e.evt == .key and e.evt.key.action == .up) {
            if (e.evt.key.code == dvui.enums.Key.one) {
                e.handled = true;
                console_open = !console_open;
                refresh = true;
                break;
            } else if (e.evt.key.code == dvui.enums.Key.two) {
                shared_mem.config.theme = (shared_mem.config.theme + 1) % 6;
                dvui.themeSet(&dvui.currentWindow().themes.values()[shared_mem.config.theme]);
                e.handled = true;
                refresh = true;
            } else if (e.evt.key.code == dvui.enums.Key.three) {
                dvui.Examples.show_demo_window = !dvui.Examples.show_demo_window;
                e.handled = true;
                refresh = true;
            }
        }
        //            .down => {
        //               if (e.evt.key.matchBind("space")) {
        //               e.handled = true;
        //              console_open = !console_open;
        //             refresh = true;
        //             } else if (e.evt.key.matchBind("a")) {
        //                 e.handled = true;
        //                 console_open = !console_open;
        //                 refresh = true;
        //             } else if (e.evt.key.matchBind("n")) {
        //                 shared_mem.config.theme += 1;
        //                 dvui.themeSet(&dvui.currentWindow().themes.values()[shared_mem.config.theme]);
        //                 e.handled = true;
        //                 refresh = true;
        //             }
        //           },
        //          .up => {},
        //         else => {},
        //    }
        //},
        //else => {},
        //}
        //   }
    }
    if (grabbed_t.i < no_t.i) {
        const r: dvui.Rect = .{ .x = mousex - 70, .y = mousey - 110, .w = 80, .h = 80 };
        _ = try dvui.icon(@src(), icon_names[grabbed_t.i], icon_fields[grabbed_t.i], .{ .rect = r, .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 }, .min_size_content = .{ .h = 40 }, .color_fill = .{ .name = .fill_press }, .background = true });
    }
    //console_open = true;

    if (refresh) {
        refresh = false;
        dvui.refresh(null, @src(), mainbox.data().id);
    }
}
