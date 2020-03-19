#ifndef APP_CANVAS_HPP_
#define APP_CANVAS_HPP_

#include <cstddef>
#include <cstdint>
#include <string>
#include <vector>

struct Color
{
    uint8_t gray;
    double alpha;
};

class Canvas
{
public:
    Canvas(size_t width, size_t height);

    auto width() const { return width_; }
    auto height() const { return height_; }
    auto pitch() const { return pitch_; }

    auto data() -> uint8_t * { return buffer_.data(); }
    auto data() const -> uint8_t const * { return buffer_.data(); }

    void translate(int x, int y) { translate_x_ = x; translate_y_ = y; }

    void fill_rect(int x, int y, size_t w, size_t h, Color color);
    void blend_alpha(int x, int y,
                     uint8_t const *data, size_t width, size_t height, int pitch,
                     Color color);

    void clear(Color color);
    void draw_horizontal_line(int y, Color color);
    void draw_vertical_line(int x, Color color);

    void save_pgm(std::string const& path) const;

private:
    std::vector<uint8_t> buffer_;
    size_t const width_;
    size_t const height_;
    int const pitch_;  // should allow negative ones for bottom up data storage

    int translate_x_;
    int translate_y_;
};

#endif  // APP_CANVAS_HPP_
