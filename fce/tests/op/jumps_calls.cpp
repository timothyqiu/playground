#include <memory>
#include <catch2/catch.hpp>
#include <fce/cpu.hpp>
#include <fce/memory.hpp>

using namespace fce;

TEST_CASE("JMP", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();

    enum {
        OP_ABS = 0x4C,
        OP_IND = 0x6C,
    };

    SECTION("ABS") {
        memory->set(0x8000, OP_ABS);
        memory->set(0x8001, 0xCD);
        memory->set(0x8002, 0xAB);

        cpu.step();

        REQUIRE(cpu.pc() == 0xABCD);
        REQUIRE(cpu.cycles() - old_cycles == 3);
    }
    SECTION("IND") {
        memory->set(0x8000, OP_IND);
        memory->set(0x8001, 0x34);
        memory->set(0x8002, 0x12);
        memory->set(0x1234, 0xCD);
        memory->set(0x1235, 0xAB);

        cpu.step();

        REQUIRE(cpu.pc() == 0xABCD);
        REQUIRE(cpu.cycles() - old_cycles == 5);
    }

    REQUIRE(cpu.p() == old_p);
}

TEST_CASE("JSR", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();

    enum {
        OP_ABS = 0x20,
    };

    SECTION("ABS") {
        memory->set(0x8000, OP_ABS);
        memory->set(0x8001, 0xCD);
        memory->set(0x8002, 0xAB);
        cpu.s(0x44);

        cpu.step();

        REQUIRE(cpu.pc() == 0xABCD);
        REQUIRE(cpu.cycles() - old_cycles == 6);

        REQUIRE(memory->get(0x0144) == 0x80);
        REQUIRE(memory->get(0x0143) == 0x03);
        REQUIRE(cpu.s() == 0x42);
    }

    REQUIRE(cpu.p() == old_p);
}

TEST_CASE("RTS", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x00);
    memory->set(0xFFFD, 0x80);

    auto cpu = CPU{memory};

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();

    enum {
        OP_IMP = 0x60,
    };

    cpu.pc(0xABCD);
    memory->set(0xABCD, OP_IMP);

    cpu.s(0x44);
    memory->set(0x0145, 0x00);
    memory->set(0x0146, 0x80);

    cpu.step();

    REQUIRE(cpu.pc() == 0x8000);
    REQUIRE(cpu.cycles() - old_cycles == 6);
    REQUIRE(cpu.s() == 0x46);
    REQUIRE(cpu.p() == old_p);
}
