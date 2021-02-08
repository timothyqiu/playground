#ifndef FCE_MEMORY_HPP_
#define FCE_MEMORY_HPP_

#include <array>
#include <fce/types.hpp>

namespace fce {

class Memory
{
public:
    virtual ~Memory() = default;

    virtual auto get(u16 addr) const noexcept -> u8;
    virtual auto set(u16 addr, u8 v) noexcept -> void;

private:
    std::array<u8, 0x10000> cells_;
};

}  // namespace fce

#endif  // FCE_MEMORY_HPP_
