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

#include "config.hpp"

// FT_Done_XXX may return error, just ignore it...
template<typename T> struct DeleterOf;
template<> struct DeleterOf<FT_Library> { void operator()(FT_Library v) { FT_Done_FreeType(v); } };
template<> struct DeleterOf<FT_Face> { void operator()(FT_Face v) { FT_Done_Face(v); } };
template<> struct DeleterOf<FILE> { void operator()(FILE *v) { std::fclose(v); } };

// make life easier with RAII
using LibraryPtr = std::unique_ptr<std::remove_pointer_t<FT_Library>, DeleterOf<FT_Library>>;
using FacePtr = std::unique_ptr<std::remove_pointer_t<FT_Face>, DeleterOf<FT_Face>>;
using FilePtr = std::unique_ptr<FILE, DeleterOf<FILE>>;

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

static void save_bitmap(FT_Bitmap *bitmap, std::string const& path)
{
    size_t const canvas_width{64};
    size_t const canvas_height{64};
    std::vector<uint8_t> buffer(canvas_width * canvas_height, 0xFF / 2);

    // TODO: support more pixel modes
    if (bitmap->pixel_mode != FT_PIXEL_MODE_GRAY) {
        spdlog::error("Unsupported pixel mode: {}", bitmap->pixel_mode);
        return;
    }

    double const color = 1.0;
    for (size_t y = 0; y < bitmap->rows && y < canvas_height; y++) {
        auto const *src_line = bitmap->buffer + bitmap->pitch * y;
        auto       *dst_line = buffer.data() + canvas_width * y;
        for (size_t x = 0; x < bitmap->width && x < canvas_width; x++) {
            auto const bg = dst_line[x] / 255.0;
            auto const alpha = src_line[x] / 255.0;
            auto const blend = bg * (1 - alpha) + color * alpha;
            dst_line[x] = static_cast<uint8_t>(std::clamp(blend * 255, 0.0, 255.0));
        }
    }

    FilePtr file;
    {
        FILE *raw = std::fopen(path.c_str(), "wb");
        if (raw == nullptr) {
            spdlog::error("fopen {} failed: {}", path, std::strerror(errno));
            return;
        }
        file.reset(raw);
    }

    auto const header = fmt::format("P5\n{} {}\n{}\n", canvas_width, canvas_height, 0xFF);
    if (std::fwrite(header.data(), header.size(), 1, file.get()) != 1) {
        spdlog::error("fwrite failed to write header");
    }
    if (std::fwrite(buffer.data(), buffer.size(), 1, file.get()) != 1) {
        spdlog::error("fwrite failed to write pixels");
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

    spdlog::debug("Setting pixel size to {}", config.pixel_size);
    if (auto const error = FT_Set_Pixel_Sizes(face.get(),
                                              /*width*/config.pixel_size,
                                              /*height*/config.pixel_size); error)
    {
        spdlog::error("FT_Set_Pixel_Sizes error: 0x{:02X}", error);
        return EXIT_FAILURE;
    }

    FT_ULong const charcode{0x90b1};  // UTF-32
    auto const index = FT_Get_Char_Index(face.get(), charcode);
    if (index == 0) {
        spdlog::error("Glyph undefined for character code: U+{:X}", charcode);
        return EXIT_FAILURE;
    }

    if (auto const error = FT_Load_Glyph(face.get(), index, FT_LOAD_DEFAULT); error) {
        spdlog::error("FT_Load_Glyph error: 0x{:02X}", error);
        return EXIT_FAILURE;
    }

    if (face->glyph->format != FT_GLYPH_FORMAT_BITMAP) {
        spdlog::debug("Glyph not in bitmap format, convert");
        if (auto const error = FT_Render_Glyph(face->glyph, FT_RENDER_MODE_NORMAL); error) {
            spdlog::error("FT_Render_Glyph error: 0x{:02X}", error);
            return EXIT_FAILURE;
        }
    }

    save_bitmap(&face->glyph->bitmap, config.output);
}
