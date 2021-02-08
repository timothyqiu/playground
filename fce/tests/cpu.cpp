#include <catch2/catch.hpp>
#include <fce/cpu.hpp>
#include <fce/memory.hpp>

TEST_CASE("Set CPU Flags", "[cpu]") {
    fce::CPU cpu;

    cpu.p(0x00);
    REQUIRE(cpu.p() == 0x00);

    SECTION("C") {
        REQUIRE_FALSE(cpu.c());
        cpu.c(true);
        REQUIRE(cpu.c());
        REQUIRE(cpu.p() == 0b0000'0001);
    }

    SECTION("Z") {
        REQUIRE_FALSE(cpu.z());
        cpu.z(true);
        REQUIRE(cpu.z());
        REQUIRE(cpu.p() == 0b0000'0010);
    }

    SECTION("I") {
        REQUIRE_FALSE(cpu.i());
        cpu.i(true);
        REQUIRE(cpu.i());
        REQUIRE(cpu.p() == 0b0000'0100);
    }

    SECTION("D") {
        REQUIRE_FALSE(cpu.d());
        cpu.d(true);
        REQUIRE(cpu.d());
        REQUIRE(cpu.p() == 0b0000'1000);
    }

    SECTION("B") {
        REQUIRE_FALSE(cpu.b());
        cpu.b(true);
        REQUIRE(cpu.b());
        REQUIRE(cpu.p() == 0b0001'0000);
    }

    SECTION("V") {
        REQUIRE_FALSE(cpu.v());
        cpu.v(true);
        REQUIRE(cpu.v());
        REQUIRE(cpu.p() == 0b0100'0000);
    }

    SECTION("N") {
        REQUIRE_FALSE(cpu.n());
        cpu.n(true);
        REQUIRE(cpu.n());
        REQUIRE(cpu.p() == 0b1000'0000);
    }
}

TEST_CASE("Clear CPU Flags", "[cpu]") {
    fce::CPU cpu;

    cpu.p(0xFF);
    REQUIRE(cpu.p() == 0xFF);

    SECTION("C") {
        REQUIRE(cpu.c());
        cpu.c(false);
        REQUIRE_FALSE(cpu.c());
        REQUIRE(cpu.p() == 0b1111'1110);
    }

    SECTION("Z") {
        REQUIRE(cpu.z());
        cpu.z(false);
        REQUIRE_FALSE(cpu.z());
        REQUIRE(cpu.p() == 0b1111'1101);
    }

    SECTION("I") {
        REQUIRE(cpu.i());
        cpu.i(false);
        REQUIRE_FALSE(cpu.i());
        REQUIRE(cpu.p() == 0b1111'1011);
    }

    SECTION("D") {
        REQUIRE(cpu.d());
        cpu.d(false);
        REQUIRE_FALSE(cpu.d());
        REQUIRE(cpu.p() == 0b1111'0111);
    }

    SECTION("B") {
        REQUIRE(cpu.b());
        cpu.b(false);
        REQUIRE_FALSE(cpu.b());
        REQUIRE(cpu.p() == 0b1110'1111);
    }

    SECTION("V") {
        REQUIRE(cpu.v());
        cpu.v(false);
        REQUIRE_FALSE(cpu.v());
        REQUIRE(cpu.p() == 0b1011'1111);
    }

    SECTION("N") {
        REQUIRE(cpu.n());
        cpu.n(false);
        REQUIRE_FALSE(cpu.n());
        REQUIRE(cpu.p() == 0b0111'1111);
    }
}

TEST_CASE("Startup", "[cpu]") {
    auto memory = std::make_shared<fce::Memory>();

    fce::u16 const target = GENERATE(0x1234, 0xABCD);

    memory->set(0xFFFC, target & 0xFF);
    memory->set(0xFFFD, (target >> 8) & 0xFF);

    fce::CPU cpu{memory};

    REQUIRE(cpu.pc() == target);
}

TEST_CASE("Stack", "[cpu]") {
    auto memory = std::make_shared<fce::Memory>();
    fce::CPU cpu{memory};

    memory->set(0x0100, 0x00);
    memory->set(0x0101, 0x01);
    memory->set(0x0113, 0x13);
    memory->set(0x0114, 0x14);
    memory->set(0x0115, 0x15);
    memory->set(0x0116, 0x16);
    memory->set(0x0117, 0x17);
    memory->set(0x01FF, 0xFF);

    SECTION("Peek") {
        cpu.s(0x15);
        REQUIRE(cpu.stack_peek() == 0x16);
        REQUIRE(cpu.s() == 0x15);
    }
    SECTION("Push") {
        cpu.s(0x15);

        cpu.stack_push(0xAB);
        REQUIRE(cpu.s() == 0x14);
        REQUIRE(memory->get(0x0115) == 0xAB);

        cpu.stack_push(0xCD);
        REQUIRE(cpu.s() == 0x13);
        REQUIRE(memory->get(0x0114) == 0xCD);
    }
    SECTION("Pull") {
        cpu.s(0x15);

        REQUIRE(cpu.stack_pull() == 0x16);
        REQUIRE(cpu.s() == 0x16);

        REQUIRE(cpu.stack_pull() == 0x17);
        REQUIRE(cpu.s() == 0x17);
    }
    SECTION("Push Wrap") {
        cpu.s(0x00);

        cpu.stack_push(0xAB);
        REQUIRE(cpu.s() == 0xFF);
        REQUIRE(memory->get(0x0100) == 0xAB);

        cpu.stack_push(0xCD);
        REQUIRE(cpu.s() == 0xFE);
        REQUIRE(memory->get(0x01FF) == 0xCD);
    }
    SECTION("Pull Wrap") {
        cpu.s(0xFE);

        REQUIRE(cpu.stack_pull() == 0xFF);
        REQUIRE(cpu.s() == 0xFF);

        REQUIRE(cpu.stack_pull() == 0x00);
        REQUIRE(cpu.s() == 0x00);

        REQUIRE(cpu.stack_pull() == 0x01);
        REQUIRE(cpu.s() == 0x01);
    }
}
