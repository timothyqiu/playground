#include <memory>
#include <catch2/catch.hpp>
#include <fce/cpu.hpp>
#include <fce/memory.hpp>

using namespace fce;

TEST_CASE("ADC", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0011'1100;

    auto const [a, operand, carry, result, c, z, v, n] = GENERATE(table<u8, u8, bool, u8, bool, bool, bool, bool>({
        { 0x12, 0x34, false, 0x46, false, false, false, false },    // normal
        { 0x12, 0x34, true,  0x47, false, false, false, false },    // carry
        { 0x00, 0x00, false, 0x00, false, true,  false, false },    // zero
        { 0xFF, 0x02, false, 0x01, true,  false, false, false },    // result carry
        { 0xFF, 0x01, false, 0x00, true,  true,  false, false },    // result carry, zero
        { 0x7F, 0x00, true,  0x80, false, false, true,  true  },    // overflow: 127 + 1 = -128
        { 0x80, 0xFF, false, 0x7F, true,  false, true,  false },    // overflow: -128 + (-1) = 127
    }));
    cpu.a(a);
    cpu.c(carry);

    SECTION("IMM") {
        memory->set(0x8000, 0x69);
        memory->set(0x8001, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }
    SECTION("ZPG") {
        memory->set(0x8000, 0x65);
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
        memory->set(0x8000, 0x75);
        memory->set(0x8001, 0xFE);
        memory->set(addr, operand);
        cpu.x(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABS") {
        memory->set(0x8000, 0x6D);
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
            memory->set(0x8000, 0x7D);
            cpu.x(index);
        }
        SECTION("ABY") {
            memory->set(0x8000, 0x79);
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
        memory->set(0x8000, 0x61);
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
        memory->set(0x8000, 0x71);
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
    REQUIRE(cpu.c() == c);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.v() == v);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("SBC", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0011'1100;

    // c flag in this instruction means 'no borrow'
    auto const [a, operand, carry, result, c, z, v, n] = GENERATE(table<u8, u8, bool, u8, bool, bool, bool, bool>({
        { 0x05, 0x03, true,  0x02, true,  false, false, false },    // 5 - 3 = 2
        { 0x05, 0x06, true,  0xFF, false, false, false, true  },    // 5 - 6 = -1
        { 0x05, 0x05, true,  0x00, true,  true,  false, false },    // 5 - 5 = 0
        { 0x05, 0x04, false, 0x00, true,  true,  false, false },    // 5 - 4 - 1 = 0
        { 0x80, 0x01, true,  0x7F, true,  false, true,  false },    // -128 - 1 = 127(-129)
        { 0x7F, 0xFF, true,  0x80, false, false, true,  true  },    // 127 - (-1) = -128(128)
    }));
    cpu.a(a);
    cpu.c(carry);

    SECTION("IMM") {
        memory->set(0x8000, 0xE9);
        memory->set(0x8001, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }
    SECTION("ZPG") {
        memory->set(0x8000, 0xE5);
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
        memory->set(0x8000, 0xF5);
        memory->set(0x8001, 0xFE);
        memory->set(addr, operand);
        cpu.x(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABS") {
        memory->set(0x8000, 0xED);
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
            memory->set(0x8000, 0xFD);
            cpu.x(index);
        }
        SECTION("ABY") {
            memory->set(0x8000, 0xF9);
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
        memory->set(0x8000, 0xE1);
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
        memory->set(0x8000, 0xF1);
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
    REQUIRE(cpu.c() == c);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.v() == v);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("CMP", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1100;

    enum {
        OP_IMM = 0xC9,
        OP_ZPG = 0xC5, OP_ZPX = 0xD5,
        OP_ABS = 0xCD, OP_ABX = 0xDD, OP_ABY = 0xD9,
        OP_IDX = 0xC1, OP_IDY = 0xD1,
    };

    // a == m: CZn
    // a <  m: cz?
    // a >  m: Cz?
    auto const [a, operand, c, z, n] = GENERATE(table<u8, u8, bool, bool, bool>({
        { 0x05, 0x05, true,  true , false },  // 5 == 5
        { 0x05, 0x06, false, false, true  },  // 5 < 6      5 - 6 = -1
        { 0x80, 0x01, false, false, false },  // -128 < 1   -128 - 1 = +127
        { 0x06, 0x05, true,  false, false },  // 6 > 5      6 - 5 = +1
        { 0x7F, 0xFF, true,  false, true  },  // 127 > -1   127 - -1 = -128
    }));
    cpu.a(a);

    SECTION("IMM") {
        memory->set(0x8000, OP_IMM);
        memory->set(0x8001, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }
    SECTION("ZPG") {
        memory->set(0x8000, OP_ZPG);
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
        memory->set(0x8000, OP_ZPX);
        memory->set(0x8001, 0xFE);
        memory->set(addr, operand);
        cpu.x(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABS") {
        memory->set(0x8000, OP_ABS);
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
            memory->set(0x8000, OP_ABX);
            cpu.x(index);
        }
        SECTION("ABY") {
            memory->set(0x8000, OP_ABY);
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
        memory->set(0x8000, OP_IDX);
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
        memory->set(0x8000, OP_IDY);
        memory->set(0x8001, lo_addr);
        memory->set(lo_addr, 0xFE);
        memory->set(hi_addr, 0x12);
        memory->set(addr, operand);
        cpu.y(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == cycles);
    }

    REQUIRE(cpu.a() == a);
    REQUIRE(cpu.c() == c);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("CPX", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1100;

    enum {
        OP_IMM = 0xE0,
        OP_ZPG = 0xE4,
        OP_ABS = 0xEC,
    };

    // x == m: CZn
    // x <  m: cz?
    // x >  m: Cz?
    auto const [x, operand, c, z, n] = GENERATE(table<u8, u8, bool, bool, bool>({
        { 0x05, 0x05, true,  true , false },  // 5 == 5
        { 0x05, 0x06, false, false, true  },  // 5 < 6      5 - 6 = -1
        { 0x80, 0x01, false, false, false },  // -128 < 1   -128 - 1 = +127
        { 0x06, 0x05, true,  false, false },  // 6 > 5      6 - 5 = +1
        { 0x7F, 0xFF, true,  false, true  },  // 127 > -1   127 - -1 = -128
    }));
    cpu.x(x);

    SECTION("IMM") {
        memory->set(0x8000, OP_IMM);
        memory->set(0x8001, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }
    SECTION("ZPG") {
        memory->set(0x8000, OP_ZPG);
        memory->set(0x8001, 0x01);
        memory->set(0x0001, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 3);
    }
    SECTION("ABS") {
        memory->set(0x8000, OP_ABS);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);
        memory->set(0x1234, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }

    REQUIRE(cpu.x() == x);
    REQUIRE(cpu.c() == c);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("CPY", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1100;

    enum {
        OP_IMM = 0xC0,
        OP_ZPG = 0xC4,
        OP_ABS = 0xCC,
    };

    // y == m: CZn
    // y <  m: cz?
    // y >  m: Cz?
    auto const [y, operand, c, z, n] = GENERATE(table<u8, u8, bool, bool, bool>({
        { 0x05, 0x05, true,  true , false },  // 5 == 5
        { 0x05, 0x06, false, false, true  },  // 5 < 6      5 - 6 = -1
        { 0x80, 0x01, false, false, false },  // -128 < 1   -128 - 1 = +127
        { 0x06, 0x05, true,  false, false },  // 6 > 5      6 - 5 = +1
        { 0x7F, 0xFF, true,  false, true  },  // 127 > -1   127 - -1 = -128
    }));
    cpu.y(y);

    SECTION("IMM") {
        memory->set(0x8000, OP_IMM);
        memory->set(0x8001, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }
    SECTION("ZPG") {
        memory->set(0x8000, OP_ZPG);
        memory->set(0x8001, 0x01);
        memory->set(0x0001, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 3);
    }
    SECTION("ABS") {
        memory->set(0x8000, OP_ABS);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);
        memory->set(0x1234, operand);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }

    REQUIRE(cpu.y() == y);
    REQUIRE(cpu.c() == c);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}
