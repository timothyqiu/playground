#include <memory>
#include <catch2/catch.hpp>
#include <fce/cpu.hpp>
#include <fce/memory.hpp>

using namespace fce;

TEST_CASE("LDA", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);
    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;
    auto const [target, z, n] = GENERATE(table<u8, bool, bool>({
        { 0x00, true, false },
        { 0x01, false, false },
        { 0x80, false, true },
    }));

    SECTION("IMM") {
        memory->set(0x8000, 0xA9);
        memory->set(0x8001, target);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }
    SECTION("ZPG") {
        memory->set(0x8000, 0xA5);
        memory->set(0x8001, 0x01);
        memory->set(0x0001, target);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 3);
    }
    SECTION("ZPX") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x00FF },
            { 3, 0x0001 },
        }));
        memory->set(0x8000, 0xB5);
        memory->set(0x8001, 0xFE);
        memory->set(addr, target);
        cpu.x(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABS") {
        memory->set(0x8000, 0xAD);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);
        memory->set(0x1234, target);

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
        memory->set(addr, target);

        SECTION("ABX") {
            memory->set(0x8000, 0xBD);
            cpu.x(index);
        }
        SECTION("ABY") {
            memory->set(0x8000, 0xB9);
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
        memory->set(0x8000, 0xA1);
        memory->set(0x8001, 0xFD);
        memory->set(lo_addr, 0x34);
        memory->set(hi_addr, 0x12);
        memory->set(0x1234, target);
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
        memory->set(0x8000, 0xB1);
        memory->set(0x8001, lo_addr);
        memory->set(lo_addr, 0xFE);
        memory->set(hi_addr, 0x12);
        memory->set(addr, target);
        cpu.y(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == cycles);
    }

    REQUIRE(cpu.a() == target);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("LDX", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);
    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;
    auto const [target, z, n] = GENERATE(table<u8, bool, bool>({
        { 0x00, true, false },
        { 0x01, false, false },
        { 0x80, false, true },
    }));

    SECTION("IMM") {
        memory->set(0x8000, 0xA2);
        memory->set(0x8001, target);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }
    SECTION("ZPG") {
        memory->set(0x8000, 0xA6);
        memory->set(0x8001, 0x01);
        memory->set(0x0001, target);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 3);
    }
    SECTION("ZPY") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x00FF },
            { 3, 0x0001 },
        }));
        memory->set(0x8000, 0xB6);
        memory->set(0x8001, 0xFE);
        memory->set(addr, target);
        cpu.y(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABS") {
        memory->set(0x8000, 0xAE);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);
        memory->set(0x1234, target);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABY") {
        auto const [index, addr, cycles] = GENERATE(table<u8, u16, u16>({
            { 1, 0x12FF, 4 },
            { 3, 0x1301, 5 },
        }));
        memory->set(0x8000, 0xBE);
        memory->set(0x8001, 0xFE);
        memory->set(0x8002, 0x12);
        memory->set(addr, target);
        cpu.y(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == cycles);
    }

    REQUIRE(cpu.x() == target);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("LDY", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);
    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();
    u8 const mask = 0b0111'1101;
    auto const [target, z, n] = GENERATE(table<u8, bool, bool>({
        { 0x00, true, false },
        { 0x01, false, false },
        { 0x80, false, true },
    }));

    SECTION("IMM") {
        memory->set(0x8000, 0xA0);
        memory->set(0x8001, target);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 2);
    }
    SECTION("ZPG") {
        memory->set(0x8000, 0xA4);
        memory->set(0x8001, 0x01);
        memory->set(0x0001, target);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 3);
    }
    SECTION("ZPX") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x00FF },
            { 3, 0x0001 },
        }));
        memory->set(0x8000, 0xB4);
        memory->set(0x8001, 0xFE);
        memory->set(addr, target);
        cpu.x(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABS") {
        memory->set(0x8000, 0xAC);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);
        memory->set(0x1234, target);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABX") {
        auto const [index, addr, cycles] = GENERATE(table<u8, u16, u16>({
            { 1, 0x12FF, 4 },
            { 3, 0x1301, 5 },
        }));
        memory->set(0x8000, 0xBC);
        memory->set(0x8001, 0xFE);
        memory->set(0x8002, 0x12);
        memory->set(addr, target);
        cpu.x(index);

        cpu.step();

        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == cycles);
    }

    REQUIRE(cpu.y() == target);
    REQUIRE(cpu.z() == z);
    REQUIRE(cpu.n() == n);
    REQUIRE((cpu.p() & mask) == (old_p & mask));
}

TEST_CASE("STA", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);
    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();

    u8 const value = 0x42;
    cpu.a(value);

    SECTION("ZPG") {
        u16 const addr = 0x0001;
        REQUIRE(memory->get(addr) != value);

        memory->set(0x8000, 0x85);
        memory->set(0x8001, addr & 0xFF);

        cpu.step();

        REQUIRE(memory->get(addr) == value);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 3);
    }
    SECTION("ZPX") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x00FF },
            { 3, 0x0001 },
        }));
        REQUIRE(memory->get(addr) != value);

        memory->set(0x8000, 0x95);
        memory->set(0x8001, 0xFE);
        cpu.x(index);

        cpu.step();

        REQUIRE(memory->get(addr) == value);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABS") {
        u16 const addr = 0x1234;
        REQUIRE(memory->get(addr) != value);

        memory->set(0x8000, 0x8D);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);

        cpu.step();

        REQUIRE(memory->get(addr) == value);
        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABX/ABY") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x12FF },
            { 3, 0x1301 },
        }));
        REQUIRE(memory->get(addr) != value);

        memory->set(0x8001, 0xFE);
        memory->set(0x8002, 0x12);

        SECTION("ABX") {
            memory->set(0x8000, 0x9D);
            cpu.x(index);
        }
        SECTION("ABY") {
            memory->set(0x8000, 0x99);
            cpu.y(index);
        }

        cpu.step();

        REQUIRE(memory->get(addr) == value);
        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 5);
    }
    SECTION("IDX") {
        u16 const addr = 0x1234;
        auto const [index, lo_addr, hi_addr] = GENERATE(table<u8, u8, u8>({
            { 1, 0xFE, 0xFF },
            { 2, 0xFF, 0x00 },
            { 4, 0x01, 0x02 },
        }));
        REQUIRE(memory->get(addr) != value);

        memory->set(0x8000, 0x81);
        memory->set(0x8001, 0xFD);
        memory->set(lo_addr, 0x34);
        memory->set(hi_addr, 0x12);
        cpu.x(index);

        cpu.step();

        REQUIRE(memory->get(addr) == value);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 6);
    }
    SECTION("IDY") {
        auto const [lo_addr, hi_addr] = GENERATE(table<u8, u8>({
            { 0xFE, 0xFF },
            { 0xFF, 0x00 },
            { 0x01, 0x02 },
        }));
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x12FF },
            { 3, 0x1301 },
        }));
        REQUIRE(memory->get(addr) != value);

        memory->set(0x8000, 0x91);
        memory->set(0x8001, lo_addr);
        memory->set(lo_addr, 0xFE);
        memory->set(hi_addr, 0x12);
        cpu.y(index);

        cpu.step();

        REQUIRE(memory->get(addr) == value);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 6);
    }

    REQUIRE(cpu.a() == value);
    REQUIRE(cpu.p() == old_p);
}

TEST_CASE("STX", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);
    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();

    u8 const value = 0x42;
    cpu.x(value);

    SECTION("ZPG") {
        u16 const addr = 0x0001;
        REQUIRE(memory->get(addr) != value);

        memory->set(0x8000, 0x86);
        memory->set(0x8001, addr & 0xFF);

        cpu.step();

        REQUIRE(memory->get(addr) == value);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 3);
    }
    SECTION("ZPY") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x00FF },
            { 3, 0x0001 },
        }));
        REQUIRE(memory->get(addr) != value);

        memory->set(0x8000, 0x96);
        memory->set(0x8001, 0xFE);
        cpu.y(index);

        cpu.step();

        REQUIRE(memory->get(addr) == value);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABS") {
        u16 const addr = 0x1234;
        REQUIRE(memory->get(addr) != value);

        memory->set(0x8000, 0x8E);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);

        cpu.step();

        REQUIRE(memory->get(addr) == value);
        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }

    REQUIRE(cpu.x() == value);
    REQUIRE(cpu.p() == old_p);
}

TEST_CASE("STY", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);
    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();

    u8 const value = 0x42;
    cpu.y(value);

    SECTION("ZPG") {
        u16 const addr = 0x0001;
        REQUIRE(memory->get(addr) != value);

        memory->set(0x8000, 0x84);
        memory->set(0x8001, addr & 0xFF);

        cpu.step();

        REQUIRE(memory->get(addr) == value);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 3);
    }
    SECTION("ZPX") {
        auto const [index, addr] = GENERATE(table<u8, u16>({
            { 1, 0x00FF },
            { 3, 0x0001 },
        }));
        REQUIRE(memory->get(addr) != value);

        memory->set(0x8000, 0x94);
        memory->set(0x8001, 0xFE);
        cpu.x(index);

        cpu.step();

        REQUIRE(memory->get(addr) == value);
        REQUIRE(cpu.pc() == 0x8002);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }
    SECTION("ABS") {
        u16 const addr = 0x1234;
        REQUIRE(memory->get(addr) != value);

        memory->set(0x8000, 0x8C);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);

        cpu.step();

        REQUIRE(memory->get(addr) == value);
        REQUIRE(cpu.pc() == 0x8003);
        REQUIRE(cpu.cycles() - old_cycles == 4);
    }

    REQUIRE(cpu.y() == value);
    REQUIRE(cpu.p() == old_p);
}
