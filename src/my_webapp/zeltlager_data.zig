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
pub var zelte: [56]Zelt = undefined;
pub var n_teilnehmer: u16 = 0;
pub var allergien: [16]Allergie = undefined;
//pub const Data = struct {
//    n_teilnehmer: u16,
//    teilnehmer_list: [1024]Teilnehmer,
//};

//pub var data: Data = .{
//    .n_teilnehmer = 0,
//    .teilnehmer_list = undefined,
//};
