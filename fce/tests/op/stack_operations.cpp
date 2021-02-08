#include <memory>
#include <catch2/catch.hpp>
#include <fce/cpu.hpp>
#include <fce/memory.hpp>

using namespace fce;

TEST_CASE("PHA/PLA", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);
    memory->set(0x8000, 0x48);  // PHA
    memory->set(0x8001, 0x68);  // PLA

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const old_s = cpu.s();
    u8 const mask = 0b0111'1101;

    auto const [value, z, n] = GENERATE(table<u8, bool, bool>({
        { 0x00, true, false },
        { 0x01, false, false },
        { 0x80, false, true },
    }));
    cpu.a(value);

    cpu.step();
    REQUIRE(cpu.cycles() - old_cycles == 3);
    REQUIRE(cpu.pc() == 0x8001);
    REQUIRE(cpu.s() == old_s - 1);
    REQUIRE(cpu.p() == old_p);
    REQUIRE(memory->get(0x0100 | old_s) == value);

    cpu.a(~value);
    REQUIRE(cpu.a() != value);

    cpu.step();
    REQUIRE(cpu.cycles() - old_cycles == 3 + 4);
    REQUIRE(cpu.pc() == 0x8002);
    REQUIRE(cpu.a() == value);
    REQUIRE(cpu.s() == old_s);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("PHP/PLP", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);
    memory->set(0x8000, 0x08);  // PHP
    memory->set(0x8001, 0x28);  // PLP

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const old_s = cpu.s();

    cpu.step();
    REQUIRE(cpu.cycles() - old_cycles == 3);
    REQUIRE(cpu.pc() == 0x8001);
    REQUIRE(cpu.s() == old_s - 1);
    REQUIRE(cpu.p() == old_p);
    REQUIRE(memory->get(0x0100 | old_s) == old_p);

    cpu.p(~old_p);
    REQUIRE(cpu.p() != old_p);

    cpu.step();
    REQUIRE(cpu.cycles() - old_cycles == 3 + 4);
    REQUIRE(cpu.pc() == 0x8002);
    REQUIRE(cpu.s() == old_s);
    REQUIRE(cpu.p() == old_p);
}
