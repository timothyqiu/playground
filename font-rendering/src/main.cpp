#include <algorithm>
#include <cerrno>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>
#include <type_traits>
#include <vector>

#include <fmt/core.h>
#include <spdlog/spdlog.h>
#include <ft2build.h>
#include FT_FREETYPE_H

#include "canvas.hpp"
#include "config.hpp"
#include "utils.hpp"

// FT_Done_XXX may return error, just ignore it...
template<> struct DeleterOf<FT_Library> { void operator()(FT_Library v) { FT_Done_FreeType(v); } };
template<> struct DeleterOf<FT_Face> { void operator()(FT_Face v) { FT_Done_Face(v); } };

// make life easier with RAII
using LibraryPtr = std::unique_ptr<std::remove_pointer_t<FT_Library>, DeleterOf<FT_Library>>;
using FacePtr = std::unique_ptr<std::remove_pointer_t<FT_Face>, DeleterOf<FT_Face>>;

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

static void draw_bitmap(Canvas& canvas, FT_Bitmap *bitmap, int x, int y)
{
    // TODO: support more pixel modes
    if (bitmap->pixel_mode != FT_PIXEL_MODE_GRAY) {
        spdlog::error("Unsupported pixel mode: {}", bitmap->pixel_mode);
        return;
    }

    double const color = 1.0;
    for (size_t src_y = 0; src_y < bitmap->rows; src_y++) {
        auto const dst_y = y + static_cast<int>(src_y);
        if (dst_y < 0) {
            continue;
        }
        if (dst_y >= canvas.height()) {
            break;
        }

        auto const *src_line = bitmap->buffer + bitmap->pitch * src_y;
        auto       *dst_line = canvas.data() + canvas.pitch() * dst_y;
        for (size_t src_x = 0; src_x < bitmap->width; src_x++) {
            auto const dst_x = x + static_cast<int>(src_x);
            if (dst_x < 0) {
                continue;
            }
            if (dst_x >= canvas.width()) {
                break;
            }

            auto const bg = dst_line[dst_x] / 255.0;
            auto const alpha = src_line[src_x] / 255.0;
            auto const blend = bg * (1 - alpha) + color * alpha;
            dst_line[dst_x] = static_cast<uint8_t>(std::clamp(blend * 255, 0.0, 255.0));
        }
    }
}

int main(int argc, char *argv[])
{
    Config const config{argc, argv};

    spdlog::set_level(spdlog::level::debug);

    LibraryPtr library;
    {
        FT_Library raw;
        if (auto const error = FT_Init_FreeType(&raw); error) {
            spdlog::error("FT_Init_FreeType error: 0x{:02X}", error);
            return EXIT_FAILURE;
        }
        library.reset(raw);
    }

    FacePtr face;
    {
        FT_Face raw;
        if (auto const error = FT_New_Face(library.get(), config.file.c_str(), 0, &raw); error) {
            spdlog::error("FT_New_Face error: 0x{:02X}", error);
            return EXIT_FAILURE;
        }
        face.reset(raw);
    }

    dump_face_info(face.get());

    spdlog::debug("Setting pixel size to {}", config.font_pixel_size);
    if (auto const error = FT_Set_Pixel_Sizes(face.get(),
                                              /*width*/config.font_pixel_size,
                                              /*height*/config.font_pixel_size); error)
    {
        spdlog::error("FT_Set_Pixel_Sizes error: 0x{:02X}", error);
        return EXIT_FAILURE;
    }

    dump_metrics(face->size->metrics);

    // UTF-32
    std::u32string_view const text{U"Type 字体😄"};

    // 32-bit integer in 26.6 fix point format
    auto const ascender = face->size->metrics.ascender >> 6;
    auto const descender = face->size->metrics.descender >> 6;

    Canvas canvas{
        // TODO: measure the texts to get an accurate width
        config.canvas_width ? config.canvas_width : text.size() * config.font_pixel_size,
        static_cast<size_t>(ascender - descender),
    };

    canvas.draw_horizontal_line(ascender, 0x00);  // baseline

    int pen_x = 0;
    int const pen_y = ascender;

    for (FT_ULong const charcode : text) {
        auto const index = FT_Get_Char_Index(face.get(), charcode);
        if (index == 0) {
            spdlog::warn("Glyph undefined for character code: U+{:X}", charcode);
        }
        if (auto const error = FT_Load_Glyph(face.get(), index, FT_LOAD_DEFAULT); error) {
            spdlog::error("FT_Load_Glyph error: 0x{:02X}", error);
            return EXIT_FAILURE;
        }

        if (face->glyph->format != FT_GLYPH_FORMAT_BITMAP) {
            spdlog::debug("Glyph {} not in bitmap format, convert", index);
            if (auto const error = FT_Render_Glyph(face->glyph, FT_RENDER_MODE_NORMAL); error) {
                spdlog::error("FT_Render_Glyph error: 0x{:02X}", error);
                return EXIT_FAILURE;
            }
        }

        draw_bitmap(canvas, &face->glyph->bitmap,
                    pen_x + face->glyph->bitmap_left,
                    pen_y - face->glyph->bitmap_top);

        pen_x += (face->glyph->advance.x >> 6);
        assert(face->glyph->advance.y == 0);

        canvas.draw_vertical_line(pen_x, 0x00);
    }

    canvas.save_pgm(config.output);
}
