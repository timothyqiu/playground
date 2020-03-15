#ifndef APP_CANVAS_HPP_
#define APP_CANVAS_HPP_

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

class Canvas
{
public:
    Canvas(size_t width, size_t height);

    auto width() const { return width_; }
    auto height() const { return height_; }
    auto pitch() const { return width_; }

    auto data() -> uint8_t * { return buffer_.data(); }
    auto data() const -> uint8_t const * { return buffer_.data(); }

    void draw_horizontal_line(int y, uint8_t color);
    void draw_vertical_line(int x, uint8_t color);

    void save_pgm(std::string const& path) const;

private:
    std::vector<uint8_t> buffer_;
    size_t width_;
    size_t height_;
};

#endif  // APP_CANVAS_HPP_
