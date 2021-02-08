#include <memory>
#include <catch2/catch.hpp>
#include <fce/cpu.hpp>
#include <fce/memory.hpp>

using namespace fce;

TEST_CASE("Flags", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const [op, mask, after] = GENERATE(table<u8, u8, bool>({
        { 0x18, 0b0000'0001, false},    // CLC
        { 0x38, 0b0000'0001, true },    // SEC
        { 0x58, 0b0000'0100, false},    // CLI
        { 0x78, 0b0000'0100, true },    // SEI
        { 0xB8, 0b0100'0000, false},    // CLV
        { 0xD8, 0b0000'1000, false},    // CLD
        { 0xF8, 0b0000'1000, true },    // SED
    }));
    memory->set(0x8000, op);

    auto const before = GENERATE(true, false);
    cpu.p((cpu.p() & ~mask) | (before ? mask : 0));

    auto const old_p = cpu.p();
    auto const old_cycles = cpu.cycles();
    cpu.step();

    REQUIRE(cpu.pc() == 0x8001);
    REQUIRE(cpu.cycles() - old_cycles == 2);
    REQUIRE(bool(cpu.p() & mask) == after);
    REQUIRE_FALSE((cpu.p() ^ old_p) & ~mask);
}
