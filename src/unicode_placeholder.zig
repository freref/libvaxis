const std = @import("std");
const IoWriter = std.io.Writer;

/// Unicode placeholder character for kitty graphics protocol in tmux
/// This is a Private Use Area character that terminals interpret as an image placeholder
pub const placeholder: []const u8 = "\u{10EEEE}";

/// Diacritics used to encode row and column positions in Unicode placeholders.
/// These are combining characters that don't affect the visual width.
/// The index in this array corresponds to the row/column number.
/// From https://sw.kovidgoyal.net/kitty/_downloads/rowcolumn-diacritics.txt
pub const diacritics = [_][]const u8{
    "\u{0305}", // 0
    "\u{030D}", // 1
    "\u{030E}", // 2
    "\u{0310}", // 3
    "\u{0312}", // 4
    "\u{033D}", // 5
    "\u{033E}", // 6
    "\u{033F}", // 7
    "\u{0346}", // 8
    "\u{034A}", // 9
    "\u{034B}", // 10
    "\u{034C}", // 11
    "\u{0350}", // 12
    "\u{0351}", // 13
    "\u{0352}", // 14
    "\u{0357}", // 15
    "\u{035B}", // 16
    "\u{0363}", // 17
    "\u{0364}", // 18
    "\u{0365}", // 19
    "\u{0366}", // 20
    "\u{0367}", // 21
    "\u{0368}", // 22
    "\u{0369}", // 23
    "\u{036A}", // 24
    "\u{036B}", // 25
    "\u{036C}", // 26
    "\u{036D}", // 27
    "\u{036E}", // 28
    "\u{036F}", // 29
    "\u{0483}", // 30
    "\u{0484}", // 31
    "\u{0485}", // 32
    "\u{0486}", // 33
    "\u{0487}", // 34
    "\u{0592}", // 35
    "\u{0593}", // 36
    "\u{0594}", // 37
    "\u{0595}", // 38
    "\u{0597}", // 39
    "\u{0598}", // 40
    "\u{0599}", // 41
    "\u{059C}", // 42
    "\u{059D}", // 43
    "\u{059E}", // 44
    "\u{059F}", // 45
    "\u{05A0}", // 46
    "\u{05A1}", // 47
    "\u{05A8}", // 48
    "\u{05A9}", // 49
    "\u{05AB}", // 50
    "\u{05AC}", // 51
    "\u{05AF}", // 52
    "\u{05C4}", // 53
    "\u{0610}", // 54
    "\u{0611}", // 55
    "\u{0612}", // 56
    "\u{0613}", // 57
    "\u{0614}", // 58
    "\u{0615}", // 59
    "\u{0616}", // 60
    "\u{0617}", // 61
    "\u{0657}", // 62
    "\u{0658}", // 63
    "\u{0659}", // 64
    "\u{065A}", // 65
    "\u{065B}", // 66
    "\u{065D}", // 67
    "\u{065E}", // 68
    "\u{06D6}", // 69
    "\u{06D7}", // 70
    "\u{06D8}", // 71
    "\u{06D9}", // 72
    "\u{06DA}", // 73
    "\u{06DB}", // 74
    "\u{06DC}", // 75
    "\u{06DF}", // 76
    "\u{06E0}", // 77
    "\u{06E1}", // 78
    "\u{06E2}", // 79
    "\u{06E4}", // 80
    "\u{06E7}", // 81
    "\u{06E8}", // 82
    "\u{06EB}", // 83
    "\u{06EC}", // 84
    "\u{0730}", // 85
    "\u{0732}", // 86
    "\u{0733}", // 87
    "\u{0735}", // 88
    "\u{0736}", // 89
    "\u{073A}", // 90
    "\u{073D}", // 91
    "\u{073F}", // 92
    "\u{0740}", // 93
    "\u{0741}", // 94
    "\u{0743}", // 95
    "\u{0745}", // 96
    "\u{0747}", // 97
    "\u{0749}", // 98
    "\u{074A}", // 99
    "\u{07EB}", // 100
    "\u{07EC}", // 101
    "\u{07ED}", // 102
    "\u{07EE}", // 103
    "\u{07EF}", // 104
    "\u{07F0}", // 105
    "\u{07F1}", // 106
    "\u{07F3}", // 107
    "\u{0816}", // 108
    "\u{0817}", // 109
    "\u{0818}", // 110
    "\u{0819}", // 111
    "\u{081B}", // 112
    "\u{081C}", // 113
    "\u{081D}", // 114
    "\u{081E}", // 115
    "\u{081F}", // 116
    "\u{0820}", // 117
    "\u{0821}", // 118
    "\u{0822}", // 119
    "\u{0823}", // 120
    "\u{0825}", // 121
    "\u{0826}", // 122
    "\u{0827}", // 123
    "\u{0829}", // 124
    "\u{082A}", // 125
    "\u{082B}", // 126
    "\u{082C}", // 127
    "\u{082D}", // 128
    "\u{0951}", // 129
    "\u{0953}", // 130
    "\u{0954}", // 131
    "\u{0F82}", // 132
    "\u{0F83}", // 133
    "\u{0F86}", // 134
    "\u{0F87}", // 135
    "\u{135D}", // 136
    "\u{135E}", // 137
    "\u{135F}", // 138
    "\u{17DD}", // 139
    "\u{193A}", // 140
    "\u{1A17}", // 141
    "\u{1A75}", // 142
    "\u{1A76}", // 143
    "\u{1A77}", // 144
    "\u{1A78}", // 145
    "\u{1A79}", // 146
    "\u{1A7A}", // 147
    "\u{1A7B}", // 148
    "\u{1A7C}", // 149
    "\u{1B6B}", // 150
    "\u{1B6D}", // 151
    "\u{1B6E}", // 152
    "\u{1B6F}", // 153
    "\u{1B70}", // 154
    "\u{1B71}", // 155
    "\u{1B72}", // 156
    "\u{1B73}", // 157
    "\u{1CD0}", // 158
    "\u{1CD1}", // 159
    "\u{1CD2}", // 160
    "\u{1CDA}", // 161
    "\u{1CDB}", // 162
    "\u{1CE0}", // 163
    "\u{1DC0}", // 164
    "\u{1DC1}", // 165
    "\u{1DC3}", // 166
    "\u{1DC4}", // 167
    "\u{1DC5}", // 168
    "\u{1DC6}", // 169
    "\u{1DC7}", // 170
    "\u{1DC8}", // 171
    "\u{1DC9}", // 172
    "\u{1DCB}", // 173
    "\u{1DCC}", // 174
    "\u{1DD1}", // 175
    "\u{1DD2}", // 176
    "\u{1DD3}", // 177
    "\u{1DD4}", // 178
    "\u{1DD5}", // 179
    "\u{1DD6}", // 180
    "\u{1DD7}", // 181
    "\u{1DD8}", // 182
    "\u{1DD9}", // 183
    "\u{1DDA}", // 184
    "\u{1DDB}", // 185
    "\u{1DDC}", // 186
    "\u{1DDD}", // 187
    "\u{1DDE}", // 188
    "\u{1DDF}", // 189
    "\u{1DE0}", // 190
    "\u{1DE1}", // 191
    "\u{1DE2}", // 192
    "\u{1DE3}", // 193
    "\u{1DE4}", // 194
    "\u{1DE5}", // 195
    "\u{1DE6}", // 196
    "\u{1DFE}", // 197
    "\u{20D0}", // 198
    "\u{20D1}", // 199
    "\u{20D4}", // 200
    "\u{20D5}", // 201
    "\u{20D6}", // 202
    "\u{20D7}", // 203
    "\u{20DB}", // 204
    "\u{20DC}", // 205
    "\u{20E1}", // 206
    "\u{20E7}", // 207
    "\u{20E9}", // 208
    "\u{20F0}", // 209
    "\u{2CEF}", // 210
    "\u{2CF0}", // 211
    "\u{2CF1}", // 212
    "\u{2DE0}", // 213
    "\u{2DE1}", // 214
    "\u{2DE2}", // 215
    "\u{2DE3}", // 216
    "\u{2DE4}", // 217
    "\u{2DE5}", // 218
    "\u{2DE6}", // 219
    "\u{2DE7}", // 220
    "\u{2DE8}", // 221
    "\u{2DE9}", // 222
    "\u{2DEA}", // 223
    "\u{2DEB}", // 224
    "\u{2DEC}", // 225
    "\u{2DED}", // 226
    "\u{2DEE}", // 227
    "\u{2DEF}", // 228
    "\u{2DF0}", // 229
    "\u{2DF1}", // 230
    "\u{2DF2}", // 231
    "\u{2DF3}", // 232
    "\u{2DF4}", // 233
    "\u{2DF5}", // 234
    "\u{2DF6}", // 235
    "\u{2DF7}", // 236
    "\u{2DF8}", // 237
    "\u{2DF9}", // 238
    "\u{2DFA}", // 239
    "\u{2DFB}", // 240
    "\u{2DFC}", // 241
    "\u{2DFD}", // 242
    "\u{2DFE}", // 243
    "\u{2DFF}", // 244
    "\u{A66F}", // 245
    "\u{A67C}", // 246
    "\u{A67D}", // 247
    "\u{A6F0}", // 248
    "\u{A6F1}", // 249
    "\u{A8E0}", // 250
    "\u{A8E1}", // 251
    "\u{A8E2}", // 252
    "\u{A8E3}", // 253
    "\u{A8E4}", // 254
    "\u{A8E5}", // 255
    "\u{A8E6}", // 256
    "\u{A8E7}", // 257
    "\u{A8E8}", // 258
    "\u{A8E9}", // 259
    "\u{A8EA}", // 260
    "\u{A8EB}", // 261
    "\u{A8EC}", // 262
    "\u{A8ED}", // 263
    "\u{A8EE}", // 264
    "\u{A8EF}", // 265
    "\u{A8F0}", // 266
    "\u{A8F1}", // 267
    "\u{AAB0}", // 268
    "\u{AAB2}", // 269
    "\u{AAB3}", // 270
    "\u{AAB7}", // 271
    "\u{AAB8}", // 272
    "\u{AABE}", // 273
    "\u{AABF}", // 274
    "\u{AAC1}", // 275
    "\u{FE20}", // 276
    "\u{FE21}", // 277
    "\u{FE22}", // 278
    "\u{FE23}", // 279
    "\u{FE24}", // 280
    "\u{FE25}", // 281
    "\u{FE26}", // 282
    "\u{10A0F}", // 283
    "\u{10A38}", // 284
    "\u{1D185}", // 285
    "\u{1D186}", // 286
    "\u{1D187}", // 287
    "\u{1D188}", // 288
    "\u{1D189}", // 289
    "\u{1D1AA}", // 290
    "\u{1D1AB}", // 291
    "\u{1D1AC}", // 292
    "\u{1D1AD}", // 293
    "\u{1D242}", // 294
    "\u{1D243}", // 295
    "\u{1D244}", // 296
};

/// Get the diacritic for a given row or column index.
/// If the index exceeds the diacritics table size, returns the first diacritic.
pub fn getDiacritic(index: u16) []const u8 {
    if (index < diacritics.len) {
        return diacritics[index];
    }
    return diacritics[0];
}

/// Write a Unicode placeholder cell to the writer.
/// The foreground color should already be set to encode the image ID.
/// row and col are the position within the image placement (0-indexed).
pub fn writePlaceholder(writer: anytype, row: u16, col: u16) !void {
    try writer.writeAll(placeholder);
    try writer.writeAll(getDiacritic(row));
    try writer.writeAll(getDiacritic(col));
}

/// Set the foreground color to encode an image ID (24-bit RGB).
/// The image ID is encoded as: R = (id >> 16) & 0xFF, G = (id >> 8) & 0xFF, B = id & 0xFF
pub fn setForegroundForImageId(writer: anytype, image_id: u32) !void {
    const r: u8 = @truncate((image_id >> 16) & 0xFF);
    const g: u8 = @truncate((image_id >> 8) & 0xFF);
    const b: u8 = @truncate(image_id & 0xFF);
    try writer.print("\x1b[38;2;{d};{d};{d}m", .{ r, g, b });
}

/// Reset the foreground color to default
pub fn resetForeground(writer: anytype) !void {
    try writer.writeAll("\x1b[39m");
}

test "getDiacritic returns valid diacritics" {
    const d0 = getDiacritic(0);
    try std.testing.expectEqualStrings("\u{0305}", d0);

    const d1 = getDiacritic(1);
    try std.testing.expectEqualStrings("\u{030D}", d1);

    // Out of range should return first diacritic
    const d_large = getDiacritic(1000);
    try std.testing.expectEqualStrings("\u{0305}", d_large);
}
