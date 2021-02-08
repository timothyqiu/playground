#include <memory>
#include <catch2/catch.hpp>
#include <fce/cpu.hpp>
#include <fce/memory.hpp>

using namespace fce;

TEST_CASE("ASL", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1100;

    enum {
        OP_IMP = 0x0A,
        OP_ZPG = 0x06, OP_ZPX = 0x16,
        OP_ABS = 0x0E, OP_ABX = 0x1E,
    };

    auto const [before, after, c, z, n] = GENERATE(table<u8, u8, bool, bool, bool>({
        { 0x01, 0x02, false, false, false}, // 0000_0001 -> 0000_0010      1 ->    2
        { 0x81, 0x02, true,  false, false}, // 1000_0001 -> 0000_0010   -127 ->    2
        { 0x41, 0x82, false, false, true }, // 0100_0001 -> 1000_0010     65 -> -126
        { 0x00, 0x00, false, true,  false}, // 0000_0000 -> 0000_0000      0 ->    0
        { 0x80, 0x00, true,  true,  false}, // 1000_0000 -> 0000_0000   -126 ->    0
    }));

    SECTION("IMP") {
        memory->set(0x8000, OP_IMP);
        cpu.a(before);

        cpu.step();

        REQUIRE(cpu.a() == after);
        REQUIRE(cpu.pc() == 0x8001);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }
    SECTION("ZPG") {
        memory->set(0x8000, OP_ZPG);
        memory->set(0x8001, 0x01);
        memory->set(0x0001, before);

        cpu.step();

        REQUIRE(memory->get(0x0001) == after);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 5);
    }
    SECTION("ZPX") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x00FF },
            { 3, 0x0001 },
        }));
        memory->set(0x8000, OP_ZPX);
        memory->set(0x8001, 0xFE);
        memory->set(addr, before);
        cpu.x(index);

        cpu.step();

        REQUIRE(memory->get(addr) == after);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 6);
    }
    SECTION("ABS") {
        memory->set(0x8000, OP_ABS);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);
        memory->set(0x1234, before);

        cpu.step();

        REQUIRE(memory->get(0x1234) == after);
        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 6);
    }
    SECTION("ABX") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x12FF },
            { 3, 0x1301 },
        }));
        memory->set(0x8000, OP_ABX);
        memory->set(0x8001, 0xFE);
        memory->set(0x8002, 0x12);
        memory->set(addr, before);
        cpu.x(index);

        cpu.step();

        REQUIRE(memory->get(addr) == after);
        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 7);
    }

    REQUIRE(cpu.c() == c);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("LSR", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1100;

    enum {
        OP_IMP = 0x4A,
        OP_ZPG = 0x46, OP_ZPX = 0x56,
        OP_ABS = 0x4E, OP_ABX = 0x5E,
    };

    auto const [before, after, c, z] = GENERATE(table<u8, u8, bool, bool>({
        { 0x80, 0x40, false, false}, // 1000_0000 -> 0100_0000
        { 0x42, 0x21, false, false}, // 0100_0010 -> 0010_0001
        { 0x41, 0x20, true,  false}, // 0100_0001 -> 0010_0000
        { 0x00, 0x00, false, true }, // 0000_0000 -> 0000_0000
        { 0x01, 0x00, true,  true }, // 0000_0001 -> 0000_0000
    }));

    cpu.n(GENERATE(true, false));

    SECTION("IMP") {
        memory->set(0x8000, OP_IMP);
        cpu.a(before);

        cpu.step();

        REQUIRE(cpu.a() == after);
        REQUIRE(cpu.pc() == 0x8001);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }
    SECTION("ZPG") {
        memory->set(0x8000, OP_ZPG);
        memory->set(0x8001, 0x01);
        memory->set(0x0001, before);

        cpu.step();

        REQUIRE(memory->get(0x0001) == after);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 5);
    }
    SECTION("ZPX") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x00FF },
            { 3, 0x0001 },
        }));
        memory->set(0x8000, OP_ZPX);
        memory->set(0x8001, 0xFE);
        memory->set(addr, before);
        cpu.x(index);

        cpu.step();

        REQUIRE(memory->get(addr) == after);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 6);
    }
    SECTION("ABS") {
        memory->set(0x8000, OP_ABS);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);
        memory->set(0x1234, before);

        cpu.step();

        REQUIRE(memory->get(0x1234) == after);
        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 6);
    }
    SECTION("ABX") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x12FF },
            { 3, 0x1301 },
        }));
        memory->set(0x8000, OP_ABX);
        memory->set(0x8001, 0xFE);
        memory->set(0x8002, 0x12);
        memory->set(addr, before);
        cpu.x(index);

        cpu.step();

        REQUIRE(memory->get(addr) == after);
        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 7);
    }

    REQUIRE(cpu.c() == c);
    REQUIRE(cpu.z() == z);
    REQUIRE_FALSE(cpu.n());
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("ROL", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1100;

    enum {
        OP_IMP = 0x2A,
        OP_ZPG = 0x26, OP_ZPX = 0x36,
        OP_ABS = 0x2E, OP_ABX = 0x3E,
    };

    auto const [before, after, c, z, n] = GENERATE(table<u8, u8, bool, bool, bool>({
        { 0x11, 0x22, false, false, false}, // 0001_0001 -> 0010_0010
        { 0x00, 0x00, false, true,  false}, // 0000_0000 -> 0000_0000
        { 0x88, 0x11, true,  false, false}, // 1000_1000 -> 0001_0001
        { 0xC0, 0x81, true,  false, true }, // 1100_0000 -> 1000_0001
        { 0x40, 0x80, false, false, true }, // 0100_0000 -> 1000_0000
    }));

    SECTION("IMP") {
        memory->set(0x8000, OP_IMP);
        cpu.a(before);

        cpu.step();

        REQUIRE(cpu.a() == after);
        REQUIRE(cpu.pc() == 0x8001);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }
    SECTION("ZPG") {
        memory->set(0x8000, OP_ZPG);
        memory->set(0x8001, 0x01);
        memory->set(0x0001, before);

        cpu.step();

        REQUIRE(memory->get(0x0001) == after);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 5);
    }
    SECTION("ZPX") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x00FF },
            { 3, 0x0001 },
        }));
        memory->set(0x8000, OP_ZPX);
        memory->set(0x8001, 0xFE);
        memory->set(addr, before);
        cpu.x(index);

        cpu.step();

        REQUIRE(memory->get(addr) == after);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 6);
    }
    SECTION("ABS") {
        memory->set(0x8000, OP_ABS);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);
        memory->set(0x1234, before);

        cpu.step();

        REQUIRE(memory->get(0x1234) == after);
        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 6);
    }
    SECTION("ABX") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x12FF },
            { 3, 0x1301 },
        }));
        memory->set(0x8000, OP_ABX);
        memory->set(0x8001, 0xFE);
        memory->set(0x8002, 0x12);
        memory->set(addr, before);
        cpu.x(index);

        cpu.step();

        REQUIRE(memory->get(addr) == after);
        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 7);
    }

    REQUIRE(cpu.c() == c);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("ROR", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1100;

    enum {
        OP_IMP = 0x6A,
        OP_ZPG = 0x66, OP_ZPX = 0x76,
        OP_ABS = 0x6E, OP_ABX = 0x7E,
    };

    auto const [before, after, c, z, n] = GENERATE(table<u8, u8, bool, bool, bool>({
        { 0x00, 0x00, false, true,  false },    // 0000_0000 -> 0000_0000
        { 0x01, 0x80, true,  false, true  },    // 0000_0001 -> 1000_0000
        { 0x22, 0x11, false, false, false },    // 0010_0010 -> 0001_0001
        { 0x88, 0x44, false, false, false },    // 1000_1000 -> 0100_0100
    }));

    SECTION("IMP") {
        memory->set(0x8000, OP_IMP);
        cpu.a(before);

        cpu.step();

        REQUIRE(cpu.a() == after);
        REQUIRE(cpu.pc() == 0x8001);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }
    SECTION("ZPG") {
        memory->set(0x8000, OP_ZPG);
        memory->set(0x8001, 0x01);
        memory->set(0x0001, before);

        cpu.step();

        REQUIRE(memory->get(0x0001) == after);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 5);
    }
    SECTION("ZPX") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x00FF },
            { 3, 0x0001 },
        }));
        memory->set(0x8000, OP_ZPX);
        memory->set(0x8001, 0xFE);
        memory->set(addr, before);
        cpu.x(index);

        cpu.step();

        REQUIRE(memory->get(addr) == after);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 6);
    }
    SECTION("ABS") {
        memory->set(0x8000, OP_ABS);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);
        memory->set(0x1234, before);

        cpu.step();

        REQUIRE(memory->get(0x1234) == after);
        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 6);
    }
    SECTION("ABX") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x12FF },
            { 3, 0x1301 },
        }));
        memory->set(0x8000, OP_ABX);
        memory->set(0x8001, 0xFE);
        memory->set(0x8002, 0x12);
        memory->set(addr, before);
        cpu.x(index);

        cpu.step();

        REQUIRE(memory->get(addr) == after);
        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 7);
    }

    REQUIRE(cpu.c() == c);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}
