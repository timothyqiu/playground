#ifndef EXCEPTIONS_HPP_
#define EXCEPTIONS_HPP_

#include <stdexcept>

#include <ft2build.h>
#include FT_TYPES_H

class FreeTypeError: public std::exception
{
public:
    explicit FreeTypeError(FT_Error code);

    auto code() const -> FT_Error { return code_; }
    auto what() const noexcept -> char const * override;

private:
    FT_Error code_;

    static auto describe(FT_Error code) noexcept -> char const *;
};

#endif  // EXCEPTIONS_HPP_
