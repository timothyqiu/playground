#include <memory>
#include <catch2/catch.hpp>
#include <fce/cpu.hpp>
#include <fce/memory.hpp>

using namespace fce;

TEST_CASE("NOP", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);
    memory->set(0x8000, 0xEA);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();

    cpu.step();

    REQUIRE(cpu.pc() == 0x8001);
    REQUIRE(cpu.cycles() - old_cycles == 2);
    REQUIRE(cpu.p() == old_p);
}

TEST_CASE("BRK/RTI", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);
    memory->set(0x8000, 0x00);  // BRK
    memory->set(0xFFFE, 0xCD);
    memory->set(0xFFFF, 0xAB);
    memory->set(0xABCD, 0x40);  // RTI

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = 0x36;
    cpu.p(old_p);
    u8 const mask = 0b1110'1111;
    cpu.s(0xFD);

    cpu.step();

    REQUIRE(cpu.pc() == 0xABCD);
    REQUIRE(cpu.cycles() - old_cycles == 7);
    REQUIRE(memory->get(0x01FD) == 0x80);
    REQUIRE(memory->get(0x01FC) == 0x02);
    REQUIRE(memory->get(0x01FB) == old_p);
    REQUIRE(cpu.s() == 0xFA);
    REQUIRE(cpu.b());
    REQUIRE((cpu.p() & mask) == (old_p & mask));

    cpu.step();

    REQUIRE(cpu.pc() == 0x8002);
    REQUIRE(cpu.cycles() - old_cycles == 7 + 6);
    REQUIRE(cpu.s() == 0xFD);
    REQUIRE(cpu.p() == old_p);
}
