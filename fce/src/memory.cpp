#include "fce/memory.hpp"
#include <spdlog/spdlog.h>

using Memory = fce::Memory;

auto Memory::get(u16 addr) const noexcept -> u8
{
    // TODO: memory mapping
    return cells_[addr];
}

auto Memory::set(u16 addr, u8 v) noexcept -> void
{
    // TODO: memory mapping
    cells_[addr] = v;
}
