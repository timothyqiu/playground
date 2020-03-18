#include "exceptions.hpp"
#include FT_ERRORS_H

FreeTypeError::FreeTypeError(FT_Error code)
    : code_{code}
{
}

auto FreeTypeError::what() const noexcept -> char const *
{
    return FreeTypeError::describe(code_);
}

auto FreeTypeError::describe(FT_Error code) noexcept -> char const *
{
    // FreeType's special way of using error codes
#undef FTERRORS_H_
#define FT_ERROR_START_LIST     switch (code) {
#define FT_ERRORDEF( e, v, s )  case v: return s;
#define FT_ERROR_END_LIST       }
#include FT_ERRORS_H

    return "(unknown)";
}
