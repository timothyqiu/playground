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
    auto pitch() const;

    auto data() -> uint8_t * { return buffer_.data(); }
    auto data() const -> uint8_t const * { return buffer_.data(); }

    void translate(int x, int y) { translate_x_ = x; translate_y_ = y; }

    void fill_rect(int x, int y, int w, int h, Color color);
    void blend_alpha(int x, int y,
                     uint8_t const *data, size_t width, size_t height, size_t pitch,
                     Color color);

    void clear(Color color);
    void draw_horizontal_line(int y, Color color);
    void draw_vertical_line(int x, Color color);

    void save_pgm(std::string const& path) const;

private:
    std::vector<uint8_t> buffer_;
    size_t width_;
    size_t height_;

    int translate_x_;
    int translate_y_;
};

#endif  // APP_CANVAS_HPP_
