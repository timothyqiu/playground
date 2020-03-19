#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <map>
#include <memory>
#include <string>
#include <string_view>
#include <type_traits>
#include <vector>

#include <fmt/core.h>
#include <spdlog/spdlog.h>
#include <ft2build.h>
#include FT_FREETYPE_H
#include FT_GLYPH_H

#include "canvas.hpp"
#include "config.hpp"
#include "exceptions.hpp"
#include "utils.hpp"

// FT_Done_XXX may return error, just ignore it...
template<> struct DeleterOf<FT_Library> { void operator()(FT_Library v) { FT_Done_FreeType(v); } };
template<> struct DeleterOf<FT_Face> { void operator()(FT_Face v) { FT_Done_Face(v); } };
template<> struct DeleterOf<FT_Glyph> { void operator()(FT_Glyph v) { FT_Done_Glyph(v); } };

// make life easier with RAII
using LibraryPtr = std::unique_ptr<std::remove_pointer_t<FT_Library>, DeleterOf<FT_Library>>;
using FacePtr = std::unique_ptr<std::remove_pointer_t<FT_Face>, DeleterOf<FT_Face>>;
using GlyphPtr = std::unique_ptr<std::remove_pointer_t<FT_Glyph>, DeleterOf<FT_Glyph>>;

static void dump_face_info(FT_Face face)
{
    fmt::print("           Num Faces: {}\n", face->num_faces);
    fmt::print("          Face Index: {}\n", face->face_index);
    fmt::print("          Num Glyphs: {}\n", face->num_glyphs);
    fmt::print("         Family Name: {}\n", face->family_name);
    fmt::print("          Style Name: {}\n", face->style_name);
    fmt::print("     Num Fixed Sizes: {}\n", face->num_fixed_sizes);
    fmt::print("        Num Charmaps: {}\n", face->num_charmaps);
    fmt::print("        Bounding Box: {},{} - {},{}\n", face->bbox.xMin, face->bbox.yMin, face->bbox.xMax, face->bbox.yMax);
    fmt::print("        Units per EM: {}\n", face->units_per_EM);
    fmt::print("            Ascender: {}\n", face->ascender);
    fmt::print("           Descender: {}\n", face->descender);
    fmt::print("   Max Advance Width: {}\n", face->max_advance_width);
    fmt::print("  Max Advance Height: {}\n", face->max_advance_height);
    fmt::print("  Underline Position: {}\n", face->underline_position);
    fmt::print(" Underline Thickness: {}\n", face->underline_thickness);
}

// Scaled Global Metrics
// No grid-fitting is performed for these values.
static void dump_metrics(FT_Size_Metrics const& metrics)
{
    fmt::print(" X Pixel per EM: {}\n", metrics.x_ppem);
    fmt::print(" Y Pixel per EM: {}\n", metrics.y_ppem);
    fmt::print("        X Scale: {}\n", metrics.x_scale);
    fmt::print("        Y Scale: {}\n", metrics.y_scale);
    fmt::print("       Ascender: {}\n", metrics.ascender);
    fmt::print("      Descender: {}\n", metrics.descender);
    fmt::print("         Height: {}\n", metrics.height);
    fmt::print("    Max Advance: {}\n", metrics.max_advance);
}

int main(int argc, char *argv[])
try {
    Config const config{argc, argv};

    spdlog::set_level(spdlog::level::debug);

    LibraryPtr library;
    {
        FT_Library raw;
        if (auto const error = FT_Init_FreeType(&raw); error) {
            spdlog::error("FT_Init_FreeType error: 0x{:02X}", error);
            throw FreeTypeError{error};
        }
        library.reset(raw);
    }

    FacePtr face;
    {
        FT_Face raw;
        if (auto const error = FT_New_Face(library.get(), config.file.c_str(), 0, &raw); error) {
            spdlog::error("FT_New_Face error: 0x{:02X}", error);
            throw FreeTypeError{error};
        }
        face.reset(raw);
    }

    dump_face_info(face.get());

    // FreeType only supports kerning through the 'kern' table
    bool const has_kerning = FT_HAS_KERNING(face.get());
    spdlog::debug("Kerning via the 'kern' table: {}", has_kerning);
    bool const use_kerning = config.enable_kerning && has_kerning;

    spdlog::debug("Setting pixel size to {}", config.font_pixel_size);
    if (auto const error = FT_Set_Pixel_Sizes(face.get(),
                                              /*width*/config.font_pixel_size,
                                              /*height*/config.font_pixel_size); error)
    {
        spdlog::error("FT_Set_Pixel_Sizes error: 0x{:02X}", error);
        throw FreeTypeError{error};
    }

    dump_metrics(face->size->metrics);

    // 32-bit integer in 26.6 fix point format
    auto const ascender = face->size->metrics.ascender >> 6;
    auto const descender = face->size->metrics.descender >> 6;

    auto const linespace = ascender - descender + config.line_gap;

    // UTF-32
    std::u32string_view const text{U"AV Type 字体*路径😄"};

    int pen_x = 0;
    int pen_y = 0;
    FT_UInt last_index = 0; // the undefined glyph has no kerning with anyone
    size_t num_lines = 1;

    std::vector<FT_Vector> pos(text.size());
    std::map<FT_ULong, GlyphPtr> glyph_cache;
    for (size_t i = 0; i < text.size(); i++) {
        FT_ULong const charcode{text[i]};

        auto const index = FT_Get_Char_Index(face.get(), charcode);
        if (index == 0) {
            spdlog::warn("Glyph undefined for character code: U+{:X}", charcode);
        }

        if (use_kerning && i > 0 && index != 0) {
            FT_Vector delta;

            // error check can be skipped, delta will be 0 on error
            if (auto const error = FT_Get_Kerning(face.get(),
                                                  last_index, index,
                                                  FT_KERNING_DEFAULT,
                                                  &delta); error)
            {
                spdlog::error("FT_Get_Kerning error: 0x{:02X}", error);
            } else if (delta.x != 0 || delta.y != 0) {
                pen_x += (delta.x >> 6);
                pen_y += (delta.y >> 6);
            }
        }
        last_index = index;

        if (glyph_cache.find(charcode) == std::end(glyph_cache)) {
            spdlog::debug("Glyph U+{:X} not in cache, generate", charcode);

            if (auto const error = FT_Load_Glyph(face.get(), index, FT_LOAD_DEFAULT); error) {
                spdlog::error("FT_Load_Glyph error: 0x{:02X}", error);
                throw FreeTypeError{error};
            }

            FT_Glyph raw;
            if (auto const error = FT_Get_Glyph(face->glyph, &raw); error) {
                spdlog::error("FT_Get_Glyph error: 0x{:02X}", error);
                throw FreeTypeError{error};
            }
            glyph_cache[charcode] = GlyphPtr{raw};
        } else {
            spdlog::debug("Glyph U+{:X} already cached", charcode);
        }

        auto const advance_x = face->glyph->advance.x >> 6;
        auto const advance_y = face->glyph->advance.y >> 6;

        assert(advance_y == 0);  // well, we're doing horizontal layout...
        if (config.content_width > 0 && pen_x > 0 && pen_x + advance_x > config.content_width) {
            pen_x = 0;
            pen_y += linespace;

            last_index = 0;
            num_lines++;
        }

        pos[i].x = pen_x;
        pos[i].y = pen_y;

        pen_x += advance_x;
        pen_y += advance_y;
    }

    auto const canvas_height = linespace * num_lines - config.line_gap;

    Canvas canvas{
        config.canvas_padding * 2 + (config.content_width > 0 ? config.content_width : pen_x),
        config.canvas_padding * 2 + canvas_height,
    };
    canvas.clear(Color{0xFF});
    canvas.translate(config.canvas_padding, config.canvas_padding);

    if (config.enable_annotation) {
        for (size_t i = 0; i < num_lines; i++) {
            auto const baseline = ascender + linespace * i;

            canvas.fill_rect(/* x */0,
                             /* y */baseline - ascender,
                             /* w */config.content_width > 0 ? config.content_width : pen_x,
                             /* h */ascender - descender,
                             Color{0xCC, 1.0});

            canvas.draw_horizontal_line(baseline - ascender, Color{0x00, 1.0});  // ascender
            canvas.draw_horizontal_line(baseline, Color{0x00, 1.0});  // baseline
            canvas.draw_horizontal_line(baseline - descender, Color{0x00, 1.0});  // descender
        }
    }

    auto const offset_x = 0;
    auto const offset_y = ascender;

    for (size_t i = 0; i < text.size(); i++) {
        FT_Glyph glyph = glyph_cache[text[i]].get();
        assert(glyph != nullptr);

        if (glyph->format != FT_GLYPH_FORMAT_BITMAP) {
            if (auto const error = FT_Glyph_To_Bitmap(&glyph, FT_RENDER_MODE_NORMAL, nullptr, 0); error) {
                spdlog::error("FT_Glyph_To_Bitmap error: 0x{:02X}", error);
                throw FreeTypeError{error};
            }
        }

        auto const bit = reinterpret_cast<FT_BitmapGlyph>(glyph);

        auto const bitmap_x = offset_x + pos[i].x + bit->left;
        auto const bitmap_y = offset_y + pos[i].y - bit->top;

        auto const& bitmap = bit->bitmap;

        // TODO: support more pixel modes
        if (bitmap.pixel_mode != FT_PIXEL_MODE_GRAY) {
            spdlog::error("Unsupported pixel mode: {}", bitmap.pixel_mode);
            continue;
        }

        if (config.enable_annotation) {
            canvas.fill_rect(bitmap_x, bitmap_y,
                             bitmap.width, bitmap.rows,
                             Color{0x00, 0.3});

            canvas.fill_rect(offset_x + pos[i].x,
                             offset_y + pos[i].y - ascender,
                             1,
                             (ascender - descender),
                             Color{0x00, 0.5});
        }

        canvas.blend_alpha(bitmap_x, bitmap_y,
                           bitmap.buffer, bitmap.width, bitmap.rows, bitmap.pitch,
                           Color{0x00});
    }

    canvas.save_pgm(config.output);
}
catch (FreeTypeError const& e) {
    fmt::print(stderr, "FreeType error 0x{:02X}: {}\n", e.code(), e.what());
    return EXIT_FAILURE;
}
