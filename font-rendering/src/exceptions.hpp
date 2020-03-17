#ifndef EXCEPTIONS_HPP_
#define EXCEPTIONS_HPP_

#include <stdexcept>

#include <ft2build.h>
#include FT_TYPES_H

class FreeTypeError: public std::runtime_error
{
public:
    explicit FreeTypeError(FT_Error code)
        : runtime_error{"freetype"}
        , code_{code}
    {
    }

    FT_Error code() const { return code_; }

private:
    FT_Error code_;
};

#endif  // EXCEPTIONS_HPP_
