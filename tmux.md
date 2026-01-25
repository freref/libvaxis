here was my previous attempt that was very messy and didn't work:


File filter
2 changes: 0 additions & 2 deletions 2
src/Image.zig
Viewed
Original file line number 	Diff line number 	Diff line change
@@ -8,8 +8,6 @@ const Window = @import("Window.zig");

const Image = @This();

const transmit_opener = "\x1b_Gf=32,i={d},s={d},v={d},m={d};";

pub const Source = union(enum) {
    path: []const u8,
    mem: []const u8,
160 changes: 113 additions & 47 deletions 160
src/Vaxis.zig
Viewed
Original file line number 	Diff line number 	Diff line change
@@ -30,6 +30,7 @@ const Vaxis = @This();
const log = std.log.scoped(.vaxis);

pub const Capabilities = struct {
    tmux: bool = false,
    kitty_keyboard: bool = false,
    kitty_graphics: bool = false,
    rgb: bool = false,
@@ -255,10 +256,18 @@ pub fn queryTerminal(self: *Vaxis, tty: *IoWriter, timeout_ns: u64) !void {
    try self.enableDetectedFeatures(tty);
}

pub fn handleTmux(self: *Vaxis) void {
    if (builtin.os.tag == .windows) return;
    if (std.posix.getenv("TMUX")) |_| self.caps.tmux = true;
}

/// write queries to the terminal to determine capabilities. This function
/// is only for use with a custom main loop. Call Vaxis.queryTerminal() if
/// you are using Loop.run()
pub fn queryTerminalSend(vx: *Vaxis, tty: *IoWriter) !void {
    vx.handleTmux();
    if (vx.caps.tmux)
        log.debug("detected tmux session", .{});
    vx.queries_done.store(false, .unordered);

    // TODO: re-enable this
@@ -276,7 +285,8 @@ pub fn queryTerminalSend(vx: *Vaxis, tty: *IoWriter) !void {
    // doesn't hurt to blindly use them
    // _ = try tty.write(ctlseqs.decrqm_focus);
    // _ = try tty.write(ctlseqs.decrqm_sync);
    try tty.writeAll(ctlseqs.decrqm_sgr_pixels ++

    const query = (ctlseqs.decrqm_sgr_pixels ++
        ctlseqs.decrqm_unicode ++
        ctlseqs.decrqm_color_scheme ++
        ctlseqs.in_band_resize_set ++
@@ -299,9 +309,17 @@ pub fn queryTerminalSend(vx: *Vaxis, tty: *IoWriter) !void {
        ctlseqs.multi_cursor_query ++
        ctlseqs.cursor_position_request ++
        ctlseqs.xtversion ++
        ctlseqs.csi_u_query ++
        ctlseqs.kitty_graphics_query ++
        ctlseqs.primary_device_attrs);
        ctlseqs.csi_u_query);

    if (vx.caps.tmux) {
        try tty.writeAll(query ++
            ctlseqs.tmux_kitty_graphics_query ++
            ctlseqs.primary_device_attrs);
    } else {
        try tty.writeAll(query ++
            ctlseqs.kitty_graphics_query ++
            ctlseqs.primary_device_attrs);
    }

    try tty.flush();
}
@@ -394,8 +412,13 @@ pub fn render(self: *Vaxis, tty: *IoWriter) !void {
    } = .{};

    // Clear all images
    if (self.caps.kitty_graphics)
        try tty.writeAll(ctlseqs.kitty_graphics_clear);
    if (self.caps.kitty_graphics) {
        if (self.caps.tmux) {
            try tty.writeAll(ctlseqs.tmux_kitty_graphics_clear);
        } else {
            try tty.writeAll(ctlseqs.kitty_graphics_clear);
        }
    }

    // Reset skip flag on all last_screen cells
    for (self.screen_last.buf) |*last_cell| {
@@ -497,10 +520,17 @@ pub fn render(self: *Vaxis, tty: *IoWriter) !void {
        }

        if (cell.image) |img| {
            try tty.print(
                ctlseqs.kitty_graphics_preamble,
                .{img.img_id},
            );
            if (self.caps.tmux) {
                try tty.print(
                    ctlseqs.tmux_kitty_graphics_preamble,
                    .{img.img_id},
                );
            } else {
                try tty.print(
                    ctlseqs.kitty_graphics_preamble,
                    .{img.img_id},
                );
            }
            if (img.options.pixel_offset) |offset| {
                try tty.print(
                    ",X={d},Y={d}",
@@ -526,7 +556,11 @@ pub fn render(self: *Vaxis, tty: *IoWriter) !void {
            if (img.options.z_index) |z| {
                try tty.print(",z={d}", .{z});
            }
            try tty.writeAll(ctlseqs.kitty_graphics_closing);
            if (self.caps.tmux) {
                try tty.writeAll(ctlseqs.tmux_kitty_graphics_closing);
            } else {
                try tty.writeAll(ctlseqs.kitty_graphics_closing);
            }
        }

        // something is different, so let's loop through everything and
@@ -873,7 +907,7 @@ pub fn transmitLocalImagePath(
    medium: Image.TransmitMedium,
    format: Image.TransmitFormat,
) !Image {
    if (!self.caps.kitty_graphics) return error.NoGraphicsCapability;
    if (!self.caps.kitty_graphics and !self.caps.tmux) return error.NoGraphicsCapability;

    defer self.next_img_id += 1;

@@ -930,7 +964,7 @@ pub fn transmitPreEncodedImage(
    height: u16,
    format: Image.TransmitFormat,
) !Image {
    if (!self.caps.kitty_graphics) return error.NoGraphicsCapability;
    if (!self.caps.kitty_graphics and !self.caps.tmux) return error.NoGraphicsCapability;

    defer self.next_img_id += 1;
    const id = self.next_img_id;
@@ -941,34 +975,47 @@ pub fn transmitPreEncodedImage(
        .png => 100,
    };

    log.debug("bytes len {}", .{bytes.len});

    if (bytes.len < 4096) {
        try tty.print(
            "\x1b_Gf={d},s={d},v={d},i={d};{s}\x1b\\",
            .{
                fmt,
                width,
                height,
                id,
                bytes,
            },
        );
        if (self.caps.tmux) {
            try tty.print(
                ctlseqs.tmux_kitty_transmit_one_chunk,
                .{ fmt, width, height, id, bytes },
            );
        } else {
            try tty.print(
                ctlseqs.kitty_transmit_one_chunk,
                .{ fmt, width, height, id, bytes },
            );
        }
    } else {
        var n: usize = 4096;

        try tty.print(
            "\x1b_Gf={d},s={d},v={d},i={d},m=1;{s}\x1b\\",
            .{ fmt, width, height, id, bytes[0..n] },
        );
        if (self.caps.tmux) {
            try tty.print(
                ctlseqs.tmux_kitty_transmit_first_chunk,
                .{ fmt, width, height, id, bytes[0..n] },
            );
        } else {
            try tty.print(
                ctlseqs.kitty_transmit_first_chunk,
                .{ fmt, width, height, id, bytes[0..n] },
            );
        }
        while (n < bytes.len) : (n += 4096) {
            const end: usize = @min(n + 4096, bytes.len);
            const m: u2 = if (end == bytes.len) 0 else 1;
            try tty.print(
                "\x1b_Gm={d};{s}\x1b\\",
                .{
                    m,
                    bytes[n..end],
                },
            );
            if (self.caps.tmux) {
                try tty.print(
                    ctlseqs.tmux_kitty_transmit_data_chunk,
                    .{ m, bytes[n..end] },
                );
            } else {
                try tty.print(
                    ctlseqs.kitty_transmit_data_chunk,
                    .{ m, bytes[n..end] },
                );
            }
        }
    }

@@ -987,7 +1034,7 @@ pub fn transmitImage(
    img: *zigimg.Image,
    format: Image.TransmitFormat,
) !Image {
    if (!self.caps.kitty_graphics) return error.NoGraphicsCapability;
    if (!self.caps.kitty_graphics and !self.caps.tmux) return error.NoGraphicsCapability;

    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();
@@ -1020,7 +1067,7 @@ pub fn loadImage(
    tty: *IoWriter,
    src: Image.Source,
) !Image {
    if (!self.caps.kitty_graphics) return error.NoGraphicsCapability;
    if (!self.caps.kitty_graphics and !self.caps.tmux) return error.NoGraphicsCapability;

    var read_buffer: [1024 * 1024]u8 = undefined; // 1MB buffer
    var img = switch (src) {
@@ -1032,11 +1079,19 @@ pub fn loadImage(
}

/// deletes an image from the terminal's memory
pub fn freeImage(_: Vaxis, tty: *IoWriter, id: u32) void {
    tty.print("\x1b_Ga=d,d=I,i={d};\x1b\\", .{id}) catch |err| {
        log.err("couldn't delete image {d}: {}", .{ id, err });
        return;
    };
pub fn freeImage(self: *Vaxis, tty: *IoWriter, id: u32) void {
    if (self.caps.tmux) {
        tty.print(ctlseqs.tmux_kitty_graphics_free, .{id}) catch |err| {
            log.err("couldn't delete image {d}: {}", .{ id, err });
            return;
        };
    } else {
        tty.print(ctlseqs.kitty_graphics_free, .{id}) catch |err| {
            log.err("couldn't delete image {d}: {}", .{ id, err });
            return;
        };
    }

    tty.flush() catch {};
}

@@ -1194,10 +1249,17 @@ pub fn prettyPrint(self: *Vaxis, tty: *IoWriter) !void {
        }

        if (cell.image) |img| {
            try tty.print(
                ctlseqs.kitty_graphics_preamble,
                .{img.img_id},
            );
            if (self.caps.tmux) {
                try tty.print(
                    ctlseqs.tmux_kitty_graphics_preamble,
                    .{img.img_id},
                );
            } else {
                try tty.print(
                    ctlseqs.kitty_graphics_preamble,
                    .{img.img_id},
                );
            }
            if (img.options.pixel_offset) |offset| {
                try tty.print(
                    ",X={d},Y={d}",
@@ -1223,7 +1285,11 @@ pub fn prettyPrint(self: *Vaxis, tty: *IoWriter) !void {
            if (img.options.z_index) |z| {
                try tty.print(",z={d}", .{z});
            }
            try tty.writeAll(ctlseqs.kitty_graphics_closing);
            if (self.caps.tmux) {
                try tty.writeAll(ctlseqs.tmux_kitty_graphics_closing);
            } else {
                try tty.writeAll(ctlseqs.kitty_graphics_closing);
            }
        }

        // something is different, so let's loop through everything and
31 changes: 31 additions & 0 deletions 31
src/ctlseqs.zig
Viewed
Original file line number 	Diff line number 	Diff line change
@@ -134,9 +134,15 @@ pub const osc52_clipboard_request = "\x1b]52;c;?\x1b\\";

// Kitty graphics
pub const kitty_graphics_clear = "\x1b_Ga=d\x1b\\";
pub const kitty_graphics_free = "\x1b_Ga=d,d=I,i={d};\x1b\\";
pub const kitty_graphics_preamble = "\x1b_Ga=p,i={d}";
pub const kitty_graphics_closing = ",C=1\x1b\\";

// Kitty transmission
pub const kitty_transmit_one_chunk = "\x1b_Gf={d},s={d},v={d},i={d};{s}\x1b\\";
pub const kitty_transmit_first_chunk = "\x1b_Gf={d},s={d},v={d},i={d},m=1;{s}\x1b\\";
pub const kitty_transmit_data_chunk = "\x1b_Gm={d};{s}\x1b\\";

// Color control sequences
pub const osc4_query = "\x1b]4;{d};?\x1b\\"; // color index {d}
pub const osc4_reset = "\x1b]104\x1b\\"; // this resets _all_ color indexes
@@ -149,3 +155,28 @@ pub const osc11_reset = "\x1b]111\x1b\\"; // reset bg to terminal default
pub const osc12_query = "\x1b]12;?\x1b\\"; // cursor color
pub const osc12_set = "\x1b]12;rgb:{x:0>2}{x:0>2}/{x:0>2}{x:0>2}/{x:0>2}{x:0>2}\x1b\\"; // set terminal cursor color
pub const osc12_reset = "\x1b]112\x1b\\"; // reset cursor to terminal default

// Tmux sequences
fn wrapTmux(comptime query: []const u8) []const u8 {
    comptime var buf: []const u8 = "";
    for (query) |c| {
        if (c == '\x1b') {
            buf = buf ++ "\x1b\x1b";
        } else {
            buf = buf ++ [_]u8{c};
        }
    }
    return "\x1bPtmux;" ++ buf ++ "\x1b\\";
}

pub const tmux_kitty_transmit_one_chunk = "\x1bPtmux;\x1b\x1b_Gf={d},s={d},v={d},i={d},q=2;{s}\x1b\\\x1b\\";
pub const tmux_kitty_transmit_first_chunk = "\x1bPtmux;\x1b\x1b_Gf={d},s={d},v={d},i={d},m=1,q=2;{s}\x1b\\\x1b\\";
pub const tmux_kitty_transmit_data_chunk = "\x1bPtmux;\x1b\x1b_Gm={d},q=2;{s}\x1b\\\x1b\\";
pub const tmux_kitty_graphics_preamble = "\x1bPtmux;\x1b\x1b_Ga=p,U=1,q=2,i={d}";
// pub const tmux_kitty_transmit_one_chunk = wrapTmux(kitty_transmit_one_chunk);
// pub const tmux_kitty_transmit_first_chunk = wrapTmux(kitty_transmit_first_chunk);
// pub const tmux_kitty_transmit_data_chunk = wrapTmux(kitty_transmit_data_chunk);
pub const tmux_kitty_graphics_query = wrapTmux(kitty_graphics_query);
pub const tmux_kitty_graphics_clear = wrapTmux(kitty_graphics_clear);
pub const tmux_kitty_graphics_free = wrapTmux(kitty_graphics_free);
pub const tmux_kitty_graphics_closing = ",C=1\x1b\\\x1b\\";
