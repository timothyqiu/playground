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
{
    this->clear(Color{});
}

void Canvas::clear(Color color)
{
    std::fill(std::begin(buffer_), std::end(buffer_), color.gray);
}

void Canvas::fill_rect(int x, int y, int w, int h, Color color)
{
    if (x < 0) {
        w += x;
        x = 0;
    }
    if (y < 0) {
        h += y;
        y = 0;
    }
    if (x + w > width_) {
        w = width_ - x;
    }
    if (y + h > height_) {
        h = height_ - y;
    }
    if (w == 0 || h == 0) {
        return;
    }

    for (int yy = 0; yy < h; yy++) {
        auto const line = buffer_.data() + (yy + y) * this->pitch();
        for (int xx = 0; xx < w; xx++) {
            auto const pixel = line + (xx + x);
            *pixel = blend(*pixel, color);
        }
    }
}

void Canvas::draw_horizontal_line(int y, Color color)
{
    if (y < 0 || height_ <= y) {
        return;
    }

    auto line = buffer_.data() + this->pitch() * y;
    for (size_t x = 0; x < width_; x++) {
        auto const pixel = line + x;
        *pixel = blend(*pixel, color);
    }
}

void Canvas::draw_vertical_line(int x, Color color)
{
    if (x < 0 || width_ <= x) {
        return;
    }

    for (size_t y = 0; y < height_; y++) {
        auto const line = buffer_.data() + this->pitch() * y;
        auto const pixel = line + x;
        *pixel = blend(*pixel, color);
    }
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
