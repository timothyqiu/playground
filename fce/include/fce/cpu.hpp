#ifndef FCE_CPU_HPP_
#define FCE_CPU_HPP_

#include <memory>

#include <fce/types.hpp>
#include <fce/memory.hpp>

namespace fce {

class CPU
{
public:
    CPU() noexcept;
    explicit CPU(std::shared_ptr<Memory> memory) noexcept;

    auto reset() noexcept -> void;

    auto step() noexcept -> void;

    // for debug
    auto cycles() const noexcept { return cycles_; }

    auto stack_peek() const noexcept -> u8 { return this->get_memory(0x0100 | u8(s_ + 1)); }
    auto stack_push(u8 v) noexcept -> void { this->set_memory(0x0100 | s_--, v); }
    auto stack_pull() noexcept -> u8 { return this->get_memory(0x0100 | ++s_); }

#define MAKE_REGISTER(type, name)                     \
public:                                               \
    auto name() const noexcept { return name ## _; }  \
    auto name(type v) noexcept { name ## _ = v; }     \
private:                                              \
    type name ## _;

    MAKE_REGISTER(u8, a)    // accumulator
    MAKE_REGISTER(u8, x)    // x index
    MAKE_REGISTER(u8, y)    // y index
    MAKE_REGISTER(u8, s)    // stack pointer
    MAKE_REGISTER(u8, p)    // status flag
    MAKE_REGISTER(u16, pc)  // program counter

#undef MAKE_REGISTER

#define MAKE_FLAG(n, name)                                                    \
public:                                                                       \
    auto name() const noexcept -> bool { return p_ & (1u << n); }                \
    auto name(bool v) noexcept -> void { p_ = (p_ & ~(1u << n)) | u8(v << n); }  \

    MAKE_FLAG(0, c)
    MAKE_FLAG(1, z)
    MAKE_FLAG(2, i)
    MAKE_FLAG(3, d)
    MAKE_FLAG(4, b)
    MAKE_FLAG(6, v)
    MAKE_FLAG(7, n)

#undef MAKE_FLAG

private:
    std::weak_ptr<Memory> memory_;

    mutable u16 cycles_;  // for debug

    auto get_memory(u16 addr) const noexcept -> u8;
    auto set_memory(u16 addr, u8 v) noexcept -> void;

    auto get_u16(u16 addr) const noexcept -> u16;

    auto fetch_next() noexcept -> u8;

    auto cycle() const noexcept -> void;
};

}  // namespace fce

#endif  // FCE_CPU_HPP_
