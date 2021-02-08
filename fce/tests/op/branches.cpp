#include <memory>
#include <catch2/catch.hpp>
#include <fce/cpu.hpp>
#include <fce/memory.hpp>

using namespace fce;

TEST_CASE("Branch", "[cpu][instruction]") {
    auto memory = std::make_shared<Memory>();
    memory->set(0xFFFC, 0x06);
    memory->set(0xFFFD, 0x00);

    auto cpu = CPU{memory};

    auto const [offset, success, pc, cycles] = GENERATE(table<u8, bool, u16, u16>({
        { 0x50, false, 0x0008, 2 },
        { 0x50, true,  0x0058, 3 },
        { 0xF8, true,  0x0100, 4 },
    }));

    memory->set(0x0007, offset);

    SECTION("BPL") {
        memory->set(0x0006, 0x10);
        cpu.n(!success);
    }
    SECTION("BMI") {
        memory->set(0x0006, 0x30);
        cpu.n(success);
    }
    SECTION("BVC") {
        memory->set(0x0006, 0x50);
        cpu.v(!success);
    }
    SECTION("BVS") {
        memory->set(0x0006, 0x70);
        cpu.v(success);
    }
    SECTION("BCC") {
        memory->set(0x0006, 0x90);
        cpu.c(!success);
    }
    SECTION("BCS") {
        memory->set(0x0006, 0xB0);
        cpu.c(success);
    }
    SECTION("BNE") {
        memory->set(0x0006, 0xD0);
        cpu.z(!success);
    }
    SECTION("BEQ") {
        memory->set(0x0006, 0xF0);
        cpu.z(success);
    }

    auto const old_cycles = cpu.cycles();
    u8 const old_p = cpu.p();

    cpu.step();

    REQUIRE(cpu.pc() == pc);
    REQUIRE(cpu.cycles() - old_cycles == cycles);
    REQUIRE(cpu.p() == old_p);
}
