#include <memory>
#include <catch2/catch.hpp>
#include <fce/cpu.hpp>
#include <fce/memory.hpp>

using namespace fce;

TEST_CASE("TAX", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);
    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;

    auto const [value, z, n] = GENERATE(table<u8, bool, bool>({
        { 0x00, true, false },
        { 0x01, false, false },
        { 0x80, false, true },
    }));

    cpu.x(0x00);
    cpu.a(value);

    SECTION("IMP") {
        memory->set(0x8000, 0xAA);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8001);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }

    REQUIRE(cpu.x() == value);
    REQUIRE(cpu.a() == value);

    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("TAY", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);
    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;

    auto const [value, z, n] = GENERATE(table<u8, bool, bool>({
        { 0x00, true, false },
        { 0x01, false, false },
        { 0x80, false, true },
    }));

    cpu.y(0x00);
    cpu.a(value);

    SECTION("IMP") {
        memory->set(0x8000, 0xA8);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8001);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }

    REQUIRE(cpu.y() == value);
    REQUIRE(cpu.a() == value);

    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("TXA", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);
    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;

    auto const [value, z, n] = GENERATE(table<u8, bool, bool>({
        { 0x00, true, false },
        { 0x01, false, false },
        { 0x80, false, true },
    }));

    cpu.a(0x00);
    cpu.x(value);

    SECTION("IMP") {
        memory->set(0x8000, 0x8A);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8001);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }

    REQUIRE(cpu.a() == value);
    REQUIRE(cpu.x() == value);

    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("TYA", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);
    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;

    auto const [value, z, n] = GENERATE(table<u8, bool, bool>({
        { 0x00, true, false },
        { 0x01, false, false },
        { 0x80, false, true },
    }));

    cpu.a(0x00);
    cpu.y(value);

    SECTION("IMP") {
        memory->set(0x8000, 0x98);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8001);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }

    REQUIRE(cpu.a() == value);
    REQUIRE(cpu.y() == value);

    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}
