const ui = @import("ui.zig");
const logging = @import("logging.zig");
pub const Allergien_namen: [16][]const u8 =
    .{
        "Gluten",
        "Krebstiere",
        "Eier",
        "Fisch",
        "Erdnüsse",
        "Soja",
        "Milch",

        "Schalenfrüchte",
        "Sellerie",
        "Senf",
        "Sesamsamen",
        "Sulfite",
        "Lupinen",
        "Weichtiere",
        "Vegan",
        "Vegetarisch",
    };

pub const Allergie = struct {
    bezeichnung: []const u8,
    key: u8,
    n_teilnehmer: u16 = 0,
    teilnehmer: [0x800]u16,
};
pub const Teilnehmer = struct {
    id: u32,
    vorname: []const u8,
    nachname: []const u8,
    anmelder_vorname: []const u8,
    anmelder_nachname: []const u8,
    anmelder_email: []const u8,
    anmelder_telefon: []const u8,
    taschengeld: []const u8,
    geburtsdatum: []const u8,
    geschlecht: []const u8,
    anschrift: []const u8,
    tshirt_groesse: []const u8,
    bade_erlaubnis: []const u8,
    schwimmbefaehigung: []const u8,
    allergien: []const u8,
    besonderheiten: []const u8,
    anwesend: []const u8,
    Zelte_id: u16,
    altersgruppe: u16,
    startwoche: u16,
    endwoche: u16,
};
pub const Zelt = struct {
    n_teilnehmer: u32 = 0,
    teilnehmer: [7]u32,
};

pub var strbuf: [0x40000]u8 = undefined;
pub var teilnehmer_list: [0x1000]Teilnehmer = undefined;
pub var zelte: [7][56]Zelt = undefined;
pub var n_teilnehmer: u16 = 0;
pub var allergien: [16]Allergie = undefined;
pub var anwesenheit_bitwise: u4096 = 0;
//pub const Data = struct {
//    n_teilnehmer: u16,
//    teilnehmer_list: [1024]Teilnehmer,
//};

//pub var data: Data = .{
//    .n_teilnehmer = 0,
//    .teilnehmer_list = undefined,
//};
pub fn adjust_ptrs(n_teilnehmer_arg: u32) void {
    n_teilnehmer = @truncate(n_teilnehmer_arg);
    ui.teilnehmer_show_list = ui.teilnehmer_show_buf[0..n_teilnehmer];
    for (ui.teilnehmer_show_list, 0..) |*t, i| {
        t.* = @intCast(i);
    }
    for (&allergien, 0..) |*a, i| {
        const i_8: u8 = @truncate(i);
        a.bezeichnung = Allergien_namen[i];
        a.key = 'A' + i_8;
        if (a.key > 'H') a.key += 3;
        if (a.key > 'P') a.key += 1;
        if (a.key > 'R') a.key += 'V' - 'S';
        a.n_teilnehmer = 0;
    }
    for (&zelte) |*zr| {
        for (zr) |*z| z.n_teilnehmer = 0;
    }
    const strbuf_addr = @intFromPtr(&strbuf) - if (comptime @import("builtin").os.tag == .linux or @import("builtin").os.tag == .windows) 1 else 0;
    //logging.log("n_teilnehmer: {}", .{n_teilnehmer}) catch unreachable;
//    if (true) return;
    
//  for (zeltlager_data.strbuf[1..1+512], 0..) |b, bi| {
//      zeltlager_data.anwesenheit[bi*8+0] = (b>>0) & 1 == 1;
//      zeltlager_data.anwesenheit[bi*8+1] = (b>>1) & 1 == 1;
//      zeltlager_data.anwesenheit[bi*8+2] = (b>>2) & 1 == 1;
//      zeltlager_data.anwesenheit[bi*8+3] = (b>>3) & 1 == 1;
//      zeltlager_data.anwesenheit[bi*8+4] = (b>>4) & 1 == 1;
//      zeltlager_data.anwesenheit[bi*8+5] = (b>>5) & 1 == 1;
//      zeltlager_data.anwesenheit[bi*8+6] = (b>>6) & 1 == 1;
//      zeltlager_data.anwesenheit[bi*8+7] = (b>>7) & 1 == 1;
//  }
    logging.log("fst: {}\n",.{teilnehmer_list[0].id}) catch unreachable;
    logging.log("fst: {}\n",.{@intFromPtr(teilnehmer_list[0].vorname.ptr)}) catch unreachable;
    logging.log("fst: {}\n",.{@intFromPtr(teilnehmer_list[0].nachname.ptr)}) catch unreachable;
    logging.log("fst: {}\n",.{@intFromPtr(teilnehmer_list[0].anmelder_vorname.ptr)}) catch unreachable;
    logging.log("fst: {}\n",.{@intFromPtr(teilnehmer_list[0].anmelder_nachname.ptr)}) catch unreachable;
    logging.log("fst: {}\n",.{@intFromPtr(teilnehmer_list[0].anmelder_email.ptr)}) catch unreachable;
    logging.log("fst: {}\n",.{@intFromPtr(teilnehmer_list[0].anmelder_telefon.ptr)}) catch unreachable;
    for (teilnehmer_list[0..n_teilnehmer],0..) |*t,ix| {
        _ = ix;
        //logging.log("ix: {}" , .{ix}) catch unreachable;
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
            const zelt = &zelte[t.*.startwoche][t.*.Zelte_id];
            zelt.*.teilnehmer[zelt.*.n_teilnehmer] = t.*.id;
            zelt.*.n_teilnehmer += 1;
        }
        if (false and t.*.allergien.len > 0) {
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
                allergien[i].teilnehmer[allergien[i].n_teilnehmer] = @truncate(t.*.id);
                allergien[i].n_teilnehmer += 1;
            }
            //logging.log("\n", .{}) catch unreachable;
        }
    }
    ui.update_filter() catch unreachable;
}
