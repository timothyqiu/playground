#include <memory>
#include <catch2/catch.hpp>
#include <fce/cpu.hpp>
#include <fce/memory.hpp>

using namespace fce;

TEST_CASE("INC", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;

    enum {
        OP_ZPG = 0xE6, OP_ZPX = 0xF6,
        OP_ABS = 0xEE, OP_ABX = 0xFE,
    };

    auto const [before, after, z, n] = GENERATE(table<u8, u8, bool, bool>({
        { 0x01, 0x02, false, false },   //    0 -> 1        + -> +
        { 0x80, 0x81, false, true  },   // -128 -> -127     - -> -
        { 0xFF, 0x00, true,  false },   //   -1 -> 0        zero
        { 0x7F, 0x80, false, true  },   //  127 -> -128     overflow
    }));

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

    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("INX", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;

    enum {
        OP_IMP = 0xE8,
    };

    auto const [before, after, z, n] = GENERATE(table<u8, u8, bool, bool>({
        { 0x01, 0x02, false, false },   //    0 -> 1        + -> +
        { 0x80, 0x81, false, true  },   // -128 -> -127     - -> -
        { 0xFF, 0x00, true,  false },   //   -1 -> 0        zero
        { 0x7F, 0x80, false, true  },   //  127 -> -128     overflow
    }));

    SECTION("IMP") {
        memory->set(0x8000, OP_IMP);
        cpu.x(before);

        cpu.step();

        REQUIRE(cpu.x() == after);
        REQUIRE(cpu.pc() == 0x8001);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }

    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("INY", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;

    enum {
        OP_IMP = 0xC8,
    };

    auto const [before, after, z, n] = GENERATE(table<u8, u8, bool, bool>({
        { 0x01, 0x02, false, false },   //    0 -> 1        + -> +
        { 0x80, 0x81, false, true  },   // -128 -> -127     - -> -
        { 0xFF, 0x00, true,  false },   //   -1 -> 0        zero
        { 0x7F, 0x80, false, true  },   //  127 -> -128     overflow
    }));

    SECTION("IMP") {
        memory->set(0x8000, OP_IMP);
        cpu.y(before);

        cpu.step();

        REQUIRE(cpu.y() == after);
        REQUIRE(cpu.pc() == 0x8001);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }

    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("DEC", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;

    enum {
        OP_ZPG = 0xC6, OP_ZPX = 0xD6,
        OP_ABS = 0xCE, OP_ABX = 0xDE,
    };

    auto const [before, after, z, n] = GENERATE(table<u8, u8, bool, bool>({
        { 0x80, 0x7F, false, false },   // -128 -> 127  overflow
        { 0x01, 0x00, true,  false },   //    1 -> 0    zero
        { 0x05, 0x04, false, false },   //    5 -> 4    + -> +
        { 0xFF, 0xFE, false, true  },   //   -1 -> -2   - -> -
    }));

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

    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("DEX", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;

    enum {
        OP_IMP = 0xCA,
    };

    auto const [before, after, z, n] = GENERATE(table<u8, u8, bool, bool>({
        { 0x80, 0x7F, false, false },   // -128 -> 127  overflow
        { 0x01, 0x00, true,  false },   //    1 -> 0    zero
        { 0x05, 0x04, false, false },   //    5 -> 4    + -> +
        { 0xFF, 0xFE, false, true  },   //   -1 -> -2   - -> -
    }));

    SECTION("IMP") {
        memory->set(0x8000, OP_IMP);
        cpu.x(before);

        cpu.step();

        REQUIRE(cpu.x() == after);
        REQUIRE(cpu.pc() == 0x8001);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }

    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("DEY", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;

    enum {
        OP_IMP = 0x88,
    };

    auto const [before, after, z, n] = GENERATE(table<u8, u8, bool, bool>({
        { 0x80, 0x7F, false, false },   // -128 -> 127  overflow
        { 0x01, 0x00, true,  false },   //    1 -> 0    zero
        { 0x05, 0x04, false, false },   //    5 -> 4    + -> +
        { 0xFF, 0xFE, false, true  },   //   -1 -> -2   - -> -
    }));

    SECTION("IMP") {
        memory->set(0x8000, OP_IMP);
        cpu.y(before);

        cpu.step();

        REQUIRE(cpu.y() == after);
        REQUIRE(cpu.pc() == 0x8001);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }

    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}
