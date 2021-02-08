#include <memory>
#include <catch2/catch.hpp>
#include <fce/cpu.hpp>
#include <fce/memory.hpp>

using namespace fce;

TEST_CASE("AND", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;

    cpu.a(0xFF);
    auto const [operand, result, z, n] = GENERATE(table<u8, u8, bool, bool>({
        { 0x00, 0x00, true, false },
        { 0x01, 0x01, false, false },
        { 0x80, 0x80, false, true },
    }));

    SECTION("IMM") {
        memory->set(0x8000, 0x29);
        memory->set(0x8001, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }
    SECTION("ZPG") {
        memory->set(0x8000, 0x25);
        memory->set(0x8001, 0x01);
        memory->set(0x0001, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 3);
    }
    SECTION("ZPX") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x00FF },
            { 3, 0x0001 },
        }));
        memory->set(0x8000, 0x35);
        memory->set(0x8001, 0xFE);
        memory->set(addr, operand);
        cpu.x(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABS") {
        memory->set(0x8000, 0x2D);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);
        memory->set(0x1234, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABX/ABY") {
        auto const [index, addr, cycles] = GENERATE(table<u8, u16, u16>({
            { 1, 0x12FF, 4 },
            { 3, 0x1301, 5 },
        }));
        memory->set(0x8001, 0xFE);
        memory->set(0x8002, 0x12);
        memory->set(addr, operand);

        SECTION("ABX") {
            memory->set(0x8000, 0x3D);
            cpu.x(index);
        }
        SECTION("ABY") {
            memory->set(0x8000, 0x39);
            cpu.y(index);
        }

        cpu.step();

        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == cycles);
    }
    SECTION("IDX") {
        auto const [index, lo_addr, hi_addr] = GENERATE(table<u8, u8, u8>({
            { 1, 0xFE, 0xFF },
            { 2, 0xFF, 0x00 },
            { 4, 0x01, 0x02 },
        }));
        memory->set(0x8000, 0x21);
        memory->set(0x8001, 0xFD);
        memory->set(lo_addr, 0x34);
        memory->set(hi_addr, 0x12);
        memory->set(0x1234, operand);
        cpu.x(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 6);
    }
    SECTION("IDY") {
        auto const [lo_addr, hi_addr] = GENERATE(table<u8, u8>({
            { 0xFE, 0xFF },
            { 0xFF, 0x00 },
            { 0x01, 0x02 },
        }));
        auto const [index, addr, cycles] = GENERATE(table<u8, u16, u16>({
            { 1, 0x12FF, 5 },
            { 3, 0x1301, 6 },
        }));
        memory->set(0x8000, 0x31);
        memory->set(0x8001, lo_addr);
        memory->set(lo_addr, 0xFE);
        memory->set(hi_addr, 0x12);
        memory->set(addr, operand);
        cpu.y(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == cycles);
    }

    REQUIRE(cpu.a() == result);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("EOR", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;

    cpu.a(0xFF);
    auto const [operand, result, z, n] = GENERATE(table<u8, u8, bool, bool>({
        { 0xFF, 0x00, true, false },
        { 0xFE, 0x01, false, false },
        { 0x7F, 0x80, false, true },
    }));

    SECTION("IMM") {
        memory->set(0x8000, 0x49);
        memory->set(0x8001, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }
    SECTION("ZPG") {
        memory->set(0x8000, 0x45);
        memory->set(0x8001, 0x01);
        memory->set(0x0001, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 3);
    }
    SECTION("ZPX") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x00FF },
            { 3, 0x0001 },
        }));
        memory->set(0x8000, 0x55);
        memory->set(0x8001, 0xFE);
        memory->set(addr, operand);
        cpu.x(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABS") {
        memory->set(0x8000, 0x4D);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);
        memory->set(0x1234, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABX/ABY") {
        auto const [index, addr, cycles] = GENERATE(table<u8, u16, u16>({
            { 1, 0x12FF, 4 },
            { 3, 0x1301, 5 },
        }));
        memory->set(0x8001, 0xFE);
        memory->set(0x8002, 0x12);
        memory->set(addr, operand);

        SECTION("ABX") {
            memory->set(0x8000, 0x5D);
            cpu.x(index);
        }
        SECTION("ABY") {
            memory->set(0x8000, 0x59);
            cpu.y(index);
        }

        cpu.step();

        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == cycles);
    }
    SECTION("IDX") {
        auto const [index, lo_addr, hi_addr] = GENERATE(table<u8, u8, u8>({
            { 1, 0xFE, 0xFF },
            { 2, 0xFF, 0x00 },
            { 4, 0x01, 0x02 },
        }));
        memory->set(0x8000, 0x41);
        memory->set(0x8001, 0xFD);
        memory->set(lo_addr, 0x34);
        memory->set(hi_addr, 0x12);
        memory->set(0x1234, operand);
        cpu.x(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 6);
    }
    SECTION("IDY") {
        auto const [lo_addr, hi_addr] = GENERATE(table<u8, u8>({
            { 0xFE, 0xFF },
            { 0xFF, 0x00 },
            { 0x01, 0x02 },
        }));
        auto const [index, addr, cycles] = GENERATE(table<u8, u16, u16>({
            { 1, 0x12FF, 5 },
            { 3, 0x1301, 6 },
        }));
        memory->set(0x8000, 0x51);
        memory->set(0x8001, lo_addr);
        memory->set(lo_addr, 0xFE);
        memory->set(hi_addr, 0x12);
        memory->set(addr, operand);
        cpu.y(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == cycles);
    }

    REQUIRE(cpu.a() == result);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("ORA", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;

    cpu.a(0x00);
    auto const [operand, result, z, n] = GENERATE(table<u8, u8, bool, bool>({
        { 0x00, 0x00, true, false },
        { 0x01, 0x01, false, false },
        { 0x80, 0x80, false, true },
    }));

    SECTION("IMM") {
        memory->set(0x8000, 0x09);
        memory->set(0x8001, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }
    SECTION("ZPG") {
        memory->set(0x8000, 0x05);
        memory->set(0x8001, 0x01);
        memory->set(0x0001, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 3);
    }
    SECTION("ZPX") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x00FF },
            { 3, 0x0001 },
        }));
        memory->set(0x8000, 0x15);
        memory->set(0x8001, 0xFE);
        memory->set(addr, operand);
        cpu.x(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABS") {
        memory->set(0x8000, 0x0D);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);
        memory->set(0x1234, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABX/ABY") {
        auto const [index, addr, cycles] = GENERATE(table<u8, u16, u16>({
            { 1, 0x12FF, 4 },
            { 3, 0x1301, 5 },
        }));
        memory->set(0x8001, 0xFE);
        memory->set(0x8002, 0x12);
        memory->set(addr, operand);

        SECTION("ABX") {
            memory->set(0x8000, 0x1D);
            cpu.x(index);
        }
        SECTION("ABY") {
            memory->set(0x8000, 0x19);
            cpu.y(index);
        }

        cpu.step();

        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == cycles);
    }
    SECTION("IDX") {
        auto const [index, lo_addr, hi_addr] = GENERATE(table<u8, u8, u8>({
            { 1, 0xFE, 0xFF },
            { 2, 0xFF, 0x00 },
            { 4, 0x01, 0x02 },
        }));
        memory->set(0x8000, 0x01);
        memory->set(0x8001, 0xFD);
        memory->set(lo_addr, 0x34);
        memory->set(hi_addr, 0x12);
        memory->set(0x1234, operand);
        cpu.x(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 6);
    }
    SECTION("IDY") {
        auto const [lo_addr, hi_addr] = GENERATE(table<u8, u8>({
            { 0xFE, 0xFF },
            { 0xFF, 0x00 },
            { 0x01, 0x02 },
        }));
        auto const [index, addr, cycles] = GENERATE(table<u8, u16, u16>({
            { 1, 0x12FF, 5 },
            { 3, 0x1301, 6 },
        }));
        memory->set(0x8000, 0x11);
        memory->set(0x8001, lo_addr);
        memory->set(lo_addr, 0xFE);
        memory->set(hi_addr, 0x12);
        memory->set(addr, operand);
        cpu.y(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == cycles);
    }

    REQUIRE(cpu.a() == result);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("BIT", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0011'1101;

    u8 const old_a = 0xFF;
    cpu.a(old_a);

    auto const [operand, z, v, n] = GENERATE(table<u8, bool, bool, bool>({
        { 0x00, true, false, false },
        { 0x01, false, false, false },
        { 0x80, false, false, true },
        { 0x40, false, true, false },
        { 0xC0, false, true, true },
    }));

    SECTION("ZPG") {
        memory->set(0x8000, 0x24);
        memory->set(0x8001, 0x01);
        memory->set(0x0001, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 3);
    }
    SECTION("ABS") {
        memory->set(0x8000, 0x2C);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);
        memory->set(0x1234, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }

    REQUIRE(cpu.a() == old_a);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.v() == v);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}
