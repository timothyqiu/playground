#include "canvas.hpp"

#include <cerrno>
#include <cstdio>
#include <cstring>

#include <fmt/core.h>
#include <spdlog/spdlog.h>

#include "utils.hpp"

// make life easier with RAII
template<> struct DeleterOf<FILE *> { void operator()(FILE *v) { std::fclose(v); } };
using FilePtr = std::unique_ptr<FILE, DeleterOf<FILE *>>;

Canvas::Canvas(size_t width, size_t height)
    : width_{width}, height_{height}
    , buffer_(width * height, 0xFF / 2)
{
}

void Canvas::draw_horizontal_line(int y, uint8_t color) {
    if (y < 0 || height_ <= y) {
        return;
    }

    auto line = buffer_.data() + width_ * y;
    for (size_t x = 0; x < width_; x++) {
        line[x] = color;
    }
}

void Canvas::draw_vertical_line(int x, uint8_t color) {
    if (x < 0 || width_ <= x) {
        return;
    }

    for (size_t y = 0; y < height_; y++) {
        auto line = buffer_.data() + width_ * y;
        line[x] = color;
    }
}

void Canvas::save_pgm(std::string const& path) const {
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
