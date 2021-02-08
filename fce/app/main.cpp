#include <memory>
#include <iostream>
#include <spdlog/spdlog.h>
#include <fce/fce.hpp>

class Memory : public fce::Memory
{
public:
    using fce::Memory::set;

    Memory() {
        fce::u16 addr = 0x0000;
        for (auto e : {
            0xa9, 0x00, 0x20, 0x10, 0x00, 0x4c, 0x02, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40,
            0xe8, 0x88, 0xe6, 0x0f, 0x38, 0x69, 0x02, 0x60,
        })
        {
            fce::Memory::set(addr++, e);
        }
        fce::Memory::set(0xFFFC, 0x00);
        fce::Memory::set(0xFFFD, 0x00);
    }

    auto set(fce::u16 addr, fce::u8 v) noexcept -> void override {
        fce::Memory::set(addr, v);

        if (addr == 0x000F) {
            std::cerr << v;
        }
    }
};

int main()
{
    // spdlog::set_level(spdlog::level::trace);

    auto memory = std::make_shared<Memory>();
    fce::CPU cpu{memory};

    for (int i = 0; i < 800; i++) {
        cpu.step();
    }
}
