pub var cli2ser: [0x100]u8 = undefined;
pub var ser2cli: [0x100:0]u8 = undefined;
pub var config: struct {
    theme: u8,
} = .{
    .theme = 0,
};
