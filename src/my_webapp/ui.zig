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
var filterinput: []u8 = undefined;
pub var teilnehmer_show_buf: [0x1000]u16 = undefined;
pub var teilnehmer_show_list: []u16=teilnehmer_show_buf[0..0];
pub var tent_widgets: [56]*dvui.BoxWidget = undefined;
var fbox_width:usize = 0;
var rowlen:usize = 0;
var content_width: usize = 0;
var side_padding: usize = 0;
var left_side: usize = 0;
var right_side: usize = 0;


//var rowlen: usize = 0;
var n_evts: u16 = 0;
var scrollbox_y: usize = 0;
const colors: struct {
    selected_teilnehmer: Options.ColorOrName,
    selected_hovered_teilnehmer: Options.ColorOrName,
    selected_tent: Options.ColorOrName,
    selected_hovered_tent: Options.ColorOrName,
    room_mate: Options.ColorOrName,
    hovered: Options.ColorOrName,

    pressed: Options.ColorOrName,
} = .{
    .selected_teilnehmer = .{.color= .{ .r = 0xa0, .g = 0xa0, .b = 0, .a = 0xff }},
    .selected_hovered_teilnehmer = .{.color= .{ .r = 0xc0, .g = 0xc0, .b = 0x30, .a = 0xff }},
    .selected_tent = .{.color= .{ .r = 0x0, .g = 0x80, .b = 0xc0, .a = 0xff }},
    .selected_hovered_tent = .{.color= .{ .r = 0x20, .g = 0xc0, .b = 0xe0, .a = 0xff }},
    .hovered = .{.color= .{ .r = 0x90, .g = 0x90, .b = 0x90, .a = 0xff }},
    .room_mate = .{.color= .{ .r = 0x60, .g = 0x60, .b = 0x60, .a = 0xff }},
    .pressed = .{.color= .{ .r = 0xa0, .g = 0xa0, .b = 0xe0, .a = 0xff }},
};



const teilnehmer_icons: [8][]const u8 = .{ entypo.m1, entypo.m2, entypo.m3, entypo.m4, entypo.w1, entypo.w2, entypo.w3, entypo.w4 };
const tent_icons: [9][]const u8 = .{entypo.home, entypo.tent_m1, entypo.tent_m2, entypo.tent_m3, entypo.tent_m4, entypo.tent_w1, entypo.tent_w2, entypo.tent_w3, entypo.tent_w4 };
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
var last_hovered_t: u16 = 0xffff;
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
const teilnehmerstring = "alex fischer";
var only_female = false;
var only_male = false;

const g = struct {
    var dir_entry: usize = 0;
    var strings = [3][]const u8{ "zelt", "vorname", "nachname" };
    var indices = [3]u4{0,1,2};
};
var dir: [3] i2 = .{1, 1, 1};
pub fn zelt_sort (lhs: u16, rhs: u16) isize {
    return @as(isize, 0) + Zeltlager_Data.teilnehmer_list[lhs].Zelte_id - Zeltlager_Data.teilnehmer_list[rhs].Zelte_id;

}
pub fn vorname_sort (lhs: u16, rhs: u16) isize{
    const t1 = Zeltlager_Data.teilnehmer_list[lhs];
    const t2 = Zeltlager_Data.teilnehmer_list[rhs];
    const len = if (t1.vorname.len < t2.vorname.len) t1.vorname.len else t2.vorname.len;
    for (Zeltlager_Data.teilnehmer_list[lhs].vorname[0..len], Zeltlager_Data.teilnehmer_list[rhs].vorname[0..len]) |c1, c2|{
        if (c1 != c2) return @as(isize, 0) + c1 - c2;
    }
    return 0;
}
pub fn nachname_sort (lhs: u16, rhs: u16) isize{
    const t1 = Zeltlager_Data.teilnehmer_list[lhs];
    const t2 = Zeltlager_Data.teilnehmer_list[rhs];
    const len = if (t1.nachname.len < t2.nachname.len) t1.nachname.len else t2.nachname.len;
    for (Zeltlager_Data.teilnehmer_list[lhs].nachname[0..len], Zeltlager_Data.teilnehmer_list[rhs].nachname[0..len]) |c1, c2|{
        if (c1 != c2) return @as(isize, 0) + c1 - c2;
    }
    return 0;
}
const sort_funcs: [3]* const fn(u16,u16) isize = .{zelt_sort,vorname_sort,nachname_sort};
pub fn lessThanFunction(_: u16,lhs: u16, rhs: u16) bool {
    for (g.indices) |i| {
        const diff = sort_funcs[i](lhs,rhs);
        if (diff != 0) return diff * dir[i] < 0;
    }
    return false;
}
pub fn update_filter() !void {
    for (0..filterinput.len) |c| {
        if (filterinput[c] >= 'A' and filterinput[c] <= 'Z' or
            filterinput[c] == "Ä"[1] or filterinput[c] == "Ö"[1] or filterinput[c] == "Ü"[1]) filterinput[c] |= 0x20;
    }
    var i_2: u16 = 0;
////    logging.log("n_teilnehmer: {} ", .{Zeltlager_Data.n_teilnehmer}) catch unreachable;
    for (0..Zeltlager_Data.n_teilnehmer) |teilnehmer_i| {
        const teilnehmer = Zeltlager_Data.teilnehmer_list[teilnehmer_i];

        if ((only_male and teilnehmer.geschlecht[0] == 'w') or
            (only_female and teilnehmer.geschlecht[0] == 'm')) continue;
        if (woche < 6 and teilnehmer.startwoche != woche) continue;

        if (filterinput.len > 0){
            var name_buf: [128]u8 = undefined;
            var name = try std.fmt.bufPrint(&name_buf, "{s} {s}", .{ teilnehmer.vorname, teilnehmer.nachname });
            for (0..name.len) |c| {
                if (name[c] >= 'A' and name[c] <= 'Z' or
                    name[c] == "Ä"[1] or name[c] == "Ö"[1] or name[c] == "Ü"[1]) name[c] |= 0x20;
            }
            if (std.mem.count(u8, name, filterinput) == 0) continue;
        }
        teilnehmer_show_buf[i_2] = @intCast(teilnehmer_i);
        i_2 += 1;
// //       logging.log("i_2: {} ", .{i_2}) catch unreachable;
//  //      logging.log("teilnehmer_i {} ", .{teilnehmer_i}) catch unreachable;
    }
    teilnehmer_show_list.len = i_2;
    std.mem.sort(u16,teilnehmer_show_list,@as(u16,0),lessThanFunction);
////    logging.log("tsll: {} ", .{teilnehmer_show_list.len}) catch unreachable;
}


fn reorderListsSimple() !void {
    var removed_idx: ?usize = null;
    var insert_before_idx: ?usize = null;

    const scroll = try dvui.scrollArea(@src(), .{ .horizontal = .auto }, .{.expand=.horizontal});
    defer scroll.deinit();

    // reorder widget must wrap entire list
    const reorder = try dvui.reorder(@src(), .{ .min_size_content = .{ .w = 120 }, .background = true, .border = dvui.Rect.all(1), .padding = dvui.Rect.all(4) });
    defer reorder.deinit();

    // this box determines layout of list - could be any layout widget
    var vbox = try dvui.box(@src(), .horizontal, .{ .expand = .both });
    defer vbox.deinit();

    for (g.indices[0..g.indices.len], 0..) |i_2, i| {

        // make a reorderable for each entry in the list
        var reorderable = try reorder.reorderable(@src(), .{}, .{ .id_extra = i, .expand = .horizontal, .min_size_content = dvui.Options.sizeM(4, 1) });
        defer reorderable.deinit();

        if (reorderable.removed()) {
            removed_idx = i; // this entry is being dragged
        } else if (reorderable.insertBefore()) {
            insert_before_idx = i; // this entry was dropped onto
        }

        // actual content of the list entry
        var hbox = try dvui.box(@src(), .horizontal, .{ .expand = .both, .border = dvui.Rect.all(1), .background = true, .color_fill = .{ .name = .fill_window }, .padding = .{.y=0,.h=0}, .id_extra = i });
        defer hbox.deinit();
        
        var bw = dvui.ButtonWidget.init(@src(), .{}, .{ .padding = .{ .y = 1, .h = 1 }, .margin = .{ .h = 0, .y = 0 }, .expand = .vertical, .background = true , .id_extra = i , .gravity_x=0, .color_fill = .{.name=.fill}});
        try bw.install();
        bw.processEvents();
        try bw.drawBackground();
        try bw.drawFocus();
        if (bw.clicked()) {
            dir[i_2] = -dir[i_2];
            try update_filter();
            refresh = true;
        }
        _ = try dvui.icon(@src(), "down", if (dir[i_2] < 0) entypo.chevron_with_circle_up else entypo.chevron_with_circle_down, .{ .gravity_x = 0.0, .gravity_y = 0.5, .expand=.ratio});
        bw.deinit();
        try dvui.label(@src(), "{s}", .{g.strings[i_2]}, .{});

        // this helper shows the triple-line icon, detects the start of a drag,
        // and hands off the drag to the ReorderWidget
        const init_opts: dvui.ReorderWidget.draggableInitOptions = .{.reorderable= reorderable};
    loop: for (dvui.events()) |*e| {
        if (!hbox.matchEvent(e))
            continue;

        switch (e.evt) {
            .mouse => |me| {
                if (me.action == .press and me.button.pointer()) {
                    e.handled = true;
                    dvui.captureMouse(hbox.wd.id);
                    const reo_top_left: ?dvui.Point = if (init_opts.reorderable) |reo| reo.wd.rectScale().r.topLeft() else null;
                    const top_left: ?dvui.Point = init_opts.top_left orelse reo_top_left;
                    dvui.dragPreStart(me.p, .{ .offset = (top_left orelse hbox.wd.rectScale().r.topLeft()).diff(me.p) });
                } else if (me.action == .motion) {
                    if (dvui.captured(hbox.wd.id)) {
                        e.handled = true;
                        if (dvui.dragging(me.p)) |_| {
                            //ret = me.p;
                            if (init_opts.reorderable) |reo| {
                                reo.reorder.dragStart(reo.wd.id, me.p); // reorder grabs capture
                            }
                            break :loop;
                        }
                    }
                }
            },
            else => {},
        }
    }
    }

    // show a final slot that allows dropping an entry at the end of the list
    if (try reorder.finalSlot()) {
        insert_before_idx = g.indices.len; // entry was dropped into the final slot
    }

    // returns true if the slice was reordered
    if (dvui.ReorderWidget.reorderSlice(u4, &g.indices, removed_idx, insert_before_idx)) {
        try update_filter();
    }
}

fn my_checkbox(src: std.builtin.SourceLocation, target: u32, label_str: ?[]const u8, opts: Options) !bool {
    const options = dvui.checkbox_defaults.override(opts);
    var ret = false;

    var bw = dvui.ButtonWidget.init(src, .{}, options.strip().override(options));

    try bw.install();
    bw.processEvents();
    // don't call button drawBackground(), it wouldn't do anything anyway because we stripped the options so no border/background
    // don't call button drawFocus(), we don't want a focus ring around the label
    defer bw.deinit();

    if (bw.clicked()) {
        Zeltlager_Data.anwesenheit_bitwise ^= @as(u4096,1) << @truncate(target);
        ret = true;
    }

    var b = try dvui.box(@src(), .horizontal, options.strip().override(.{ .expand = .both }));
    defer b.deinit();

    const check_size = options.fontGet().textHeight();
    const s = try dvui.spacer(@src(), dvui.Size.all(check_size), .{ .gravity_x = 0.5, .gravity_y = 0.5 });

    const rs = s.borderRectScale();

    if (bw.wd.visible()) {
        try dvui.checkmark((Zeltlager_Data.anwesenheit_bitwise >> @truncate(target)) & 1 == 1, bw.focused(), rs, bw.pressed(), bw.hovered(), options);
    }

    if (label_str) |str| {
        _ = try dvui.spacer(@src(), .{ .w = dvui.checkbox_defaults.paddingGet().w }, .{});
        try dvui.labelNoFmt(@src(), str, options.strip().override(.{ .gravity_x = 0.5, .gravity_y = 0.5 }));
    }

    return ret;
}


fn teilnehmer_element(src: std.builtin.SourceLocation, index: u16, id_extra: u8, opts: Options) !void {
    var extra: u32 = index;
    extra = extra << 12;
    extra = extra + id_extra << 2;
    const teilnehmer = Zeltlager_Data.teilnehmer_list[index];
    const col: Options.ColorOrName =
        if (clicked_t.i == index) (if (hovered_t.i == index or teilnehmer.Zelte_id == hovered_tent) colors.selected_hovered_teilnehmer
            else colors.selected_teilnehmer
        )
//        else if (teilnehmer.Zelte_id == clicked_tent) colors.selected_tent 
        else if (hovered_t.i == index) colors.hovered 
        else if (id_extra == 1 and teilnehmer.Zelte_id == hovered_tent) colors.hovered 
        else if (id_extra == 1 and hovered_t.i < 0xffff and Zeltlager_Data.teilnehmer_list[hovered_t.i].Zelte_id == teilnehmer.Zelte_id and Zeltlager_Data.teilnehmer_list[hovered_t.i].startwoche == teilnehmer.startwoche) colors.room_mate 
        else if (grabbed_t.i == index) colors.pressed 
        else .{ .name = .fill };
    var default_opts: Options = .{
        .padding = .{ .x = 2 },
        .color_fill = col,
        .id_extra = extra + 0,
        .background = true,
        .expand = .horizontal,
        .border = dvui.Rect.all(2),
        .color_border = if (teilnehmer.Zelte_id == clicked_tent) colors.selected_tent else .{.name=.fill},
         
    };
    const options = default_opts.override(opts);
    const labelbox = try dvui.box(src, .horizontal, options);
//  const evts = dvui.events();
//  for (evts) |*e| {
//      if (!dvui.eventMatchSimple(e, labelbox.data())) {
//          continue;
//      }
//       
//      switch (e.evt) {
//          .mouse => |me| {
//              hovered_tent = 0xffff;
//              draggedover_tent = 0xffff;
// 
//              mousex = me.p.x;
//              mousey = me.p.y;
//              //            const i:u16 = @as(u16,@intFromFloat((mousex - 10) / 36)) + @as(u16,@intFromFloat((mousey-80) / 36))*12;
// 
//              if (me.action == .press) {
//                  e.handled = true;
//                  //dvui.captureMouse(dbox.data().id);
//                  if (hovered_t.i < index) {
//                      //dvui.refresh(null,@src(),mainbox.data().id);
//                      refresh = true;
//                  }
//                  grabbed_t = .{ .i = index, .id = teilnehmer.id };
// 
//                  hovered_t = no_t;
// 
//                  mousex = me.p.x;
//                  mousey = me.p.y;
//              } else if (me.action == .release) {
//                  e.handled = true;
//                  if (dragged_t.i != no_t.i) {
//                      const tid = teilnehmer.id;
//                      websocket.drop(tid);
//                      dragged_t = no_t;
//                  }
//                  if (grabbed_t.i < index) {
//                      //dvui.refresh(null,@src(),mainbox.data().id);
//                      refresh = true;
//                  }
//                  if (grabbed_t.i == index) {
//                      clicked_t = if (clicked_t.i == index) no_t else grabbed_t;
//                      //dvui.refresh(null,@src(),mainbox.data().id);
//                      refresh = true;
//                  }
//                  grabbed_t = no_t;
//                  last_hovered_t = @intCast(hovered_t.i);
//                  hovered_t = .{ .i = index, .id = Zeltlager_Data.teilnehmer_list[index].id };
//                  //dvui.captureMouse(null);
//              } else if (me.action == .position) {
//                  e.handled = true;
//                  if (grabbed_t.i == no_t.i) {
//                      if (hovered_t.i < index) {
//                      //dvui.refresh(null,@src(),mainbox.data().id);
//                      refresh = true;
//                      }
//                      last_hovered_t = @intCast(hovered_t.i);
//                      hovered_t.i = index;
//                      if (last_hovered_t < 0xffff and Zeltlager_Data.teilnehmer_list[last_hovered_t].Zelte_id != Zeltlager_Data.teilnehmer_list[hovered_t.i].Zelte_id) 
//                      //dvui.refresh(null, @src(), mainbox.data().id);
//                      refresh = true;
//                  }
//                  mousex = me.p.x;
//                  mousey = me.p.y;
//              } else if (me.action == .motion) {
//                  if (grabbed_t.i != no_t.i and dragged_t.i == no_t.i) {
//                      dragged_t = grabbed_t;
//                      websocket.grab(dragged_t.id);
//                  }
//              }
//          },
//          else => {},
//      }
//  }

    _ = try dvui.icon(src, "", teilnehmer_icons[teilnehmer.altersgruppe - 1], .{ .margin=.{.x=5,.y=5,.w=5,.h=5}, .expand = .ratio, .id_extra = extra + 1, .gravity_y = 0.5 });
    if (id_extra == 0 or open) _ = try dvui.label(src, "{s} {s}", .{ teilnehmer.vorname, teilnehmer.nachname }, .{ .id_extra = extra + 2, .expand = .horizontal, .background = false });
    //_ = try dvui.label(src, fmt, data, .{
    //    .id_extra = 2,
    //    .padding = .{ .x = 5, .y = 2, .h = 2 },
    //});
    labelbox.deinit();
//    return labelbox;
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
        const evts = dvui.events();
        for (evts) |*e| {
            if (!dvui.eventMatchSimple(e, te.data())) {
                continue;
            }
            if (e.evt == .key) {
                filterinput = te.text[0..te.len];
                try update_filter();
            }
        }
        te.deinit();

        var bf = dvui.ButtonWidget.init(@src(), .{}, .{ .padding = .{ .y = 1, .h = 1 }, .margin = .{ .h = 0, .y = 0 }, .expand = .horizontal, .background = true });
        try bf.install();
        bf.processEvents();
        try bf.drawBackground();
        try bf.drawFocus();
        var col: Options.ColorOrName = if (only_female) colors.selected_teilnehmer else .{ .name = .text };
        if (bf.clicked()) {
            only_male = false;
            only_female = !only_female;
            try update_filter();
        }
        _ = try dvui.icon(@src(), "", entypo.female, .{ .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 }, .margin = .{ .x = 2, .y = 2, .w = 2, .h = 2 }, .color_text = col, .background = true, .border = dvui.Rect.all(0.8) });
        bf.deinit();
        var bm = dvui.ButtonWidget.init(@src(), .{}, .{ .padding = .{ .y = 1, .h = 1 }, .margin = .{ .h = 0, .y = 0 }, .expand = .horizontal, .background = true });
        try bm.install();
        bm.processEvents();
        try bm.drawBackground();
        try bm.drawFocus();
        col = if (only_male) colors.selected_teilnehmer else .{ .name = .text };
        if (bm.clicked()) {
            only_female = false;
            only_male = !only_male;
            try update_filter();
        }
        _ = try dvui.icon(@src(), "", entypo.male, .{ .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 }, .margin = .{ .x = 2, .y = 2, .w = 2, .h = 2 }, .color_text = col, .background = true, .border = dvui.Rect.all(0.8) });
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
            }, .{}, .{ .id_extra = i, .border = dvui.Rect.all(0.8), .background=true })) {
                woche = @truncate(i);
            try update_filter();
            }
        }
        
        if (try dvui.button(@src(), "ansicht", .{}, .{ .border = dvui.Rect.all(0.8), .background = true })) {
            open = !open;
        }

        _ = try dvui.label(@src(), "n_evts: {}, frame: {}, dir: {} {} {}, version: {}", .{ n_evts, framenr, dir[0],dir[1],dir[2] , websocket.version}, .{});
    }
    try reorderListsSimple();
    {
        //        var scrollbox = try dvui.paned(@src(), .{ .direction = .vertical, .collapsed_size = paned_collapsed_width }, .{ .expand = .both, .background = true, .min_size_content = .{ .h = 100 }, .border = dvui.Rect.all(1) });
        var scrollbox = try dvui.box(@src(), .vertical, .{ .expand = .both, .background = true, .min_size_content = .{ .h = 100 }, .border = dvui.Rect.all(1) });
        if (scrollbox_y == 0) scrollbox_y = @as(usize,@intFromFloat(scrollbox.wd.rect.y));
        
        //        scrollbox.split_ratio = if (clicked_t.i == 0xffff) 0.9 else 0.5;
        defer scrollbox.deinit();
        if (teilnehmer_show_list.len == 0) return;
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
                    const content_size: dvui.Size = if (open) .{.w = 200, .h=50} else .{.w=50,.h=50};
                   const evts = dvui.events();
                  for (evts) |*e| {
                      if (!dvui.eventMatchSimple(e, fbox.data())) {
                          continue;
                      }
                      n_evts+=1;
                      if (e.evt == .mouse) {
                          {
                              hovered_tent = 0xffff;
                              draggedover_tent = 0xffff;
                              e.handled = (dragged_t.i == no_t.i);

                              fbox_width = @as(usize,@intFromFloat(fbox.wd.rect.w));
                              rowlen = (fbox_width-6) / 56;
                              content_width = rowlen * 56;
                              side_padding =  fbox_width - content_width;
                              left_side = side_padding / 2 - 6 ;
                              right_side = content_width - left_side;

                              switch (e.evt.mouse.action) {
                                  .press => {
                                      grabbed_t = .{ .i = hovered_t.i, .id = Zeltlager_Data.teilnehmer_list[hovered_t.i].id };
                                      hovered_t = grabbed_t;
                                  },
                                  .release => {
                                      if (dragged_t.i != no_t.i) {
                                          websocket.drop(dragged_t.i);
                                          dragged_t = no_t;
                                      }
                                      if (grabbed_t.i == hovered_t.i) {
                                          clicked_t = if (clicked_t.i == hovered_t.i) no_t else grabbed_t;
                                      }
                                      grabbed_t = no_t;
                                      const mx: usize = @intFromFloat(e.evt.mouse.p.x);
                                      const my: usize = @intFromFloat(e.evt.mouse.p.y);
                                      const grid_x_pos: usize = if (mx < left_side + 50) 0 else if (mx > right_side ) rowlen - 1 else (mx - left_side - 50) / 56;

                                      hovered_t.i = teilnehmer_show_list[grid_x_pos + (my-scrollbox_y) / 56 * rowlen];
                                  },
                                  .motion => {
                                     if (grabbed_t.i != no_t.i and dragged_t.i == no_t.i) {
                                         dragged_t = grabbed_t;
                                         websocket.grab(dragged_t.id);
                                         e.handled = true;
                                     } else {
                                         
                                          const mx: usize = @intFromFloat(e.evt.mouse.p.x);
                                          const my: usize = @intFromFloat(e.evt.mouse.p.y);
                                      const grid_x_pos: usize = if (mx < left_side + 50) 0 else if (mx > right_side ) rowlen - 1 else (mx - left_side - 50) / 56;
                                         hovered_t.i = teilnehmer_show_list[grid_x_pos + (my-scrollbox_y) / 56 * rowlen];
                                     }
                                  },
                                 .wheel_y => {
                                   e.handled = false;
                                 },
                                  else => {}
                              }

                             }
                      }
                  }


                    for (teilnehmer_show_list) |teilnehmer_i| {
                        _ = try teilnehmer_element(@src(), @intCast(teilnehmer_i), 1, .{ .max_size_content = .{.w=200,.h=50}, .min_size_content = content_size});
                        //te.deinit();
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
                var room_mates_box = try dvui.box(@src(), .vertical, .{ .expand = .both, .gravity_x = 1, .background = true, .padding = .{ .h = 5 }, .margin = .{ .y = 5, .h = 5 }, .border = dvui.Rect.all(1), .color_border = 
                    if (clicked_tent == teilnehmer.Zelte_id) colors.selected_tent else .{.name=.fill}});
                if (teilnehmer.Zelte_id < 55) {
                    for (Zeltlager_Data.zelte[teilnehmer.*.startwoche][teilnehmer.*.Zelte_id].teilnehmer[0..Zeltlager_Data.zelte[teilnehmer.*.startwoche][teilnehmer.*.Zelte_id].n_teilnehmer]) |tid| {
                        _ = try teilnehmer_element(@src(), @intCast(tid-1), 0, .{.border=dvui.Rect.all(0)});
                    }
                }
                room_mates_box.deinit();
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

    const active_i: u32 = if (grabbed_t.i < 0xffff) grabbed_t.i else hovered_t.i;
    //if (active_i < no_t.i) hovered_tent = Zeltlager_Data.teilnehmer_list[active_i].Zelte_id;
    for (1..56) |i| {
        const occupation = Zeltlager_Data.zelte[woche][i].n_teilnehmer;
        const col2: dvui.Options.ColorOrName =
            if (clicked_tent == i) (if (
                hovered_tent == i) colors.selected_hovered_tent
                else colors.selected_tent )
            else if (draggedover_tent == i and occupation == 7) .{ .name = .err } 
            else if (hovered_tent == i or draggedover_tent == i) colors.hovered 
            else if (active_i < no_t.i and Zeltlager_Data.teilnehmer_list[active_i].Zelte_id == i) colors.hovered else .{ .name = .fill };

        var labelbox = try dvui.box(@src(), .vertical, .{ .id_extra = i, .margin = .{ .x = 4, .y = 4 }, .border = dvui.Rect.all(2),
            .color_border = if (clicked_t.i < 0xffff and Zeltlager_Data.teilnehmer_list[clicked_t.i].Zelte_id == i) colors.selected_teilnehmer else null

            , .color_fill = col2, .background = true });
        tent_widgets[i] = labelbox;
        defer labelbox.deinit();
        {
            var tenticonbox = try dvui.box(@src(), .vertical, .{ .id_extra = i, .margin = .{ .x = 4, .y = 4 }, .background = false });
            defer tenticonbox.deinit();
            if (occupation == 0){
                _ = try dvui.icon(@src(), "", entypo.home, .{
                    .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 },
                    .min_size_content = .{ .h = 40 },
                });
            }else {
                _ = try dvui.icon(@src(), "", tent_icons[
                    Zeltlager_Data.teilnehmer_list[Zeltlager_Data.zelte[woche][i].teilnehmer[0]-1].altersgruppe
                ], .{
                    .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 },
                    .min_size_content = .{ .h = 40 },
                });
            }
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
                    //hovered_t.i = 0xffff;
                    e.handled = true;
                    if (me.action == .press) {
                        clicked_tent = if (clicked_tent == i) 0xffff else i;
                    } else if (me.action == .position) {
                        mousex = me.p.x;
                        mousey = me.p.y;
                        if (hovered_tent != i) {
                           // //refresh = true;
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
                        ////refresh = true;
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

        var tentmember = try dvui.box(@src(), .vertical, .{ .margin = .{ .w = 20 }, .border = dvui.Rect.all(1), .color_border = colors.selected_tent , .background = true});
        defer tentmember.deinit();

        for (Zeltlager_Data.zelte[woche][clicked_tent].teilnehmer[0..Zeltlager_Data.zelte[woche][clicked_tent].n_teilnehmer]) |tid| {
            var box = try dvui.box(@src(), .horizontal, .{ .id_extra = tid, .expand=.horizontal });
            defer box.deinit();
            if(try my_checkbox(@src(), tid, "", .{})){
                websocket.anwesenheit(@truncate(tid),(Zeltlager_Data.anwesenheit_bitwise >> @truncate(tid)) & 1 == 1);
            }
            _ = try teilnehmer_element(@src(), @intCast(tid-1), 0, .{.border=dvui.Rect.all(0)});
        }
    }
    if (hovered_tent < 55 and hovered_tent != clicked_tent) {
        var tentmember = try dvui.box(@src(), .vertical, .{ .border = dvui.Rect.all(1), .background = true });
        defer tentmember.deinit();
        for (Zeltlager_Data.zelte[woche][hovered_tent].teilnehmer[0..Zeltlager_Data.zelte[woche][hovered_tent].n_teilnehmer]) |tid| {
            var box = try dvui.box(@src(), .horizontal, .{ .id_extra = tid });
            defer box.deinit();
            _ = try my_checkbox(@src(), tid, "", .{});
            _ = try teilnehmer_element(@src(), @intCast(tid-1), 0, .{});
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
//        //      logging.log("{s}: {}\n", .{a.bezeichnung, a.n_teilnehmer}) catch unreachable;
        const box = try dvui.box(@src(), .vertical, .{ .id_extra = a.key, .margin = .{ .x = 3, .y = 3, .w = 2, .h = 2 }, .padding = .{ .x = 1, .y = 1, .w = 1, .h = 1 }, .border = dvui.Rect.all(1), .background = true });
        defer box.deinit();
        _ = try dvui.label(@src(), "{s} ({c})", .{ a.bezeichnung, a.key }, .{ .font_style = .title_3, .id_extra = a.key, .expand = .horizontal, .background = false });
        for (a.teilnehmer[0..a.n_teilnehmer]) |tid| {
            _ = try teilnehmer_element(@src(), @intCast(tid-1), a.key, .{});
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
        console_text.deinit();
        console.deinit();
    }
    {
        var paned = try dvui.paned(@src(), .{ .direction = .horizontal, .collapsed_size = paned_collapsed_width }, .{ .expand = .both, .background = true, .min_size_content = .{ .h = 100 } });
        defer paned.deinit();
        try teilnehmer_pane();
        const right_box = try dvui.box(@src(), .vertical, .{ .expand = .both });
        const tabbar = try dvui.box(@src(), .horizontal, .{ .expand = .horizontal, .gravity_y = 1 });
        var col: Options.ColorOrName = if (view_mode == 0) colors.selected_tent else .{ .name = .text };

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

        col = if (view_mode == 1) colors.selected_teilnehmer else .{ .name = .text };
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
        for (evts) |*e| {
            if (!dvui.eventMatchSimple(e, paned.data())) {
                continue;
            }

            e.handled = true;

            switch (e.evt) {
                .mouse => |me| {
                    switch (me.action)
                    {
                        .release => {
                            if (dragged_t.i < no_t.i) {
                                const tid = Zeltlager_Data.teilnehmer_list[dragged_t.i].id;
                                websocket.drop(tid);
                                dragged_t = no_t;
                            }
                            grabbed_t = no_t;
                            //hovered_t = no_t;
                            hovered_tent = 0xffff;

                            refresh = true;
                            break;
                        } ,
                        .position => {
                            mousex = me.p.x;
                            mousey = me.p.y;
                            hovered_tent = 0xffff;
                            //hovered_t = no_t;
                        },
                        .motion => {
                            if (grabbed_t.i < no_t.i and dragged_t.i == no_t.i) {
                                dragged_t = grabbed_t;
                                const tid = Zeltlager_Data.teilnehmer_list[dragged_t.i].id;
                                websocket.grab(tid);
                            }
                        }, 
                        else => {},
                    }
                },
                else => {},
            }
        }
    }

    const evts = dvui.events();
    for (evts) |*e| {
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
    }
    if (dragged_t.i < no_t.i) {
        const mainbox_rect = mainbox.wd.rect;
        const teilnehmer = Zeltlager_Data.teilnehmer_list[dragged_t.i];
        const r: dvui.Rect = .{ .x = mousex - mainbox_rect.x - 80, .y = mousey - mainbox_rect.y - 80 , .w = 80, .h = 80 };
        _ = try dvui.icon(@src(), "bla", teilnehmer_icons[teilnehmer.altersgruppe-1], .{ .rect = r, .padding = .{ .x = 5, .y = 5, .w = 5, .h = 5 }, .min_size_content = .{ .h = 40 }, .color_fill = colors.pressed, .background = true });
    }

    if (refresh) {
        refresh = false;
        dvui.refresh(null, @src(), mainbox.data().id);
    }
}
