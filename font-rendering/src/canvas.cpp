#include "canvas.hpp"

#include <algorithm>
#include <cerrno>
#include <cstdio>
#include <cstring>

#include <fmt/core.h>
#include <spdlog/spdlog.h>

#include "utils.hpp"

// make life easier with RAII
template<> struct DeleterOf<FILE *> { void operator()(FILE *v) { std::fclose(v); } };
using FilePtr = std::unique_ptr<FILE, DeleterOf<FILE *>>;

static inline auto blend(uint8_t bg, Color color)
{
    auto const a = static_cast<double>(bg) / 255;
    auto const b = static_cast<double>(color.gray) / 255;
    return static_cast<uint8_t>(std::clamp(a * (1 - color.alpha) + b * color.alpha, 0.0, 1.0) * 255);
}

Canvas::Canvas(size_t width, size_t height)
    : width_{width}, height_{height}
    , buffer_(width * height)
    , translate_x_{0}, translate_y_{0}
{
    this->clear(Color{});
}

auto Canvas::pitch() const
{
    return width_;
}

void Canvas::fill_rect(int x, int y, int w, int h, Color color)
{
    x += translate_x_;
    y += translate_y_;
    assert(w >= 0 && h >= 0);

    for (int i = 0; i < h; i++) {
        if (i + y < 0) {
            continue;
        }
        if (i + y >= height_) {
            break;
        }
        auto const line = buffer_.data() + (i + y) * this->pitch();
        for (int j = 0; j < w; j++) {
            if (j + x < 0) {
                continue;
            }
            if (j + x >= width_) {
                break;
            }
            auto const pixel = line + (j + x);
            *pixel = blend(*pixel, color);
        }
    }
}

void Canvas::blend_alpha(int x, int y,
                         uint8_t const *data,
                         size_t width, size_t height,
                         size_t pitch,
                         Color color)
{
    x += translate_x_;
    y += translate_y_;

    for (size_t src_y = 0; src_y < height; src_y++) {
        auto const dst_y = y + static_cast<int>(src_y);
        if (dst_y < 0) {
            continue;
        }
        if (dst_y >= height_) {
            break;
        }

        auto const *src_line = data + pitch * src_y;
        auto       *dst_line = buffer_.data() + this->pitch() * dst_y;
        for (size_t src_x = 0; src_x < width; src_x++) {
            auto const dst_x = x + static_cast<int>(src_x);
            if (dst_x < 0) {
                continue;
            }
            if (dst_x >= width_) {
                break;
            }

            color.alpha = src_line[src_x] / 255.0;
            dst_line[dst_x] = blend(dst_line[dst_x], color);
        }
    }
}

void Canvas::clear(Color color)
{
    color.alpha = 1.0;
    this->fill_rect(-translate_x_, -translate_y_, width_, height_, color);
}

void Canvas::draw_horizontal_line(int y, Color color)
{
    this->fill_rect(-translate_x_, y, width_, 1, color);
}

void Canvas::draw_vertical_line(int x, Color color)
{
    this->fill_rect(x, -translate_y_, 1, height_, color);
}

void Canvas::save_pgm(std::string const& path) const
{
    FilePtr file;
    {
        FILE *raw = std::fopen(path.c_str(), "wb");
        if (raw == nullptr) {
            spdlog::error("fopen {} failed: {}", path, std::strerror(errno));
            return;
        }
        file.reset(raw);
    }

    auto const header = fmt::format("P5\n{} {}\n{}\n", width_, height_, 0xFF);
    if (std::fwrite(header.data(), header.size(), 1, file.get()) != 1) {
        spdlog::error("fwrite failed to write header");
    }
    if (std::fwrite(buffer_.data(), buffer_.size(), 1, file.get()) != 1) {
        spdlog::error("fwrite failed to write pixels");
    }
}
