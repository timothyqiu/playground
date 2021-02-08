#include "fce/cpu.hpp"
#include <spdlog/spdlog.h>

using CPU = fce::CPU;


CPU::CPU() noexcept
    : CPU{nullptr}
{
}

CPU::CPU(std::shared_ptr<Memory> memory) noexcept
    : s_{0xFD}, memory_{memory}
{
    this->reset();
}

auto CPU::step() noexcept -> void
{
    auto const instruction = this->fetch_next();
    spdlog::trace("instruction {:02X}", instruction);

    auto const col = instruction & 0b0001'1111;
    auto const row = instruction & 0b1110'0000;

    u16 addr, oops_addr;
    u8 imm;

    auto const use_imm = col == 0x09 || col == 0x0B || ((col == 0x00 || col == 0x02) && (row >= 0x80));
    auto const oops_instruction = (col == 0x11 || col == 0x13 || col == 0x19 || col >= 0x1B);

    // IMM #i
    if (use_imm) {
        imm = this->fetch_next();
    }
    // IDX (d,x)
    if (col == 0x01 || col == 0x03) {
        u8 const base = this->fetch_next();
        this->cycle();
        u8 const lo_addr = base + x_;
        u8 const hi_addr = lo_addr + 1;
        u8 const lo = this->get_memory(lo_addr);
        u8 const hi = this->get_memory(hi_addr);
        addr = hi << 8 | lo;
    }
    // ZPG d
    if (0x04 <= col && col <= 0x07) {
        addr = this->fetch_next();
    }
    // ABS a
    if (instruction == 0x20 || (0x0C <= col && col <= 0x0F && instruction != 0x6C)) {
        auto const lo = this->fetch_next();
        auto const hi = this->fetch_next();
        addr = hi << 8 | lo;
    }
    // IND (a)
    if (instruction == 0x6C) {
        auto const lo_addr = this->fetch_next();
        auto const hi_addr = this->fetch_next();
        u16 const ind_addr = hi_addr << 8 | lo_addr;
        u8 const lo = this->get_memory(ind_addr + 0);
        u8 const hi = this->get_memory(ind_addr + 1);
        addr = hi << 8 | lo;
    }
    // IDY (d),y
    if (col == 0x11 || col == 0x13) {
        u8 const lo_addr = this->fetch_next();
        u8 const hi_addr = lo_addr + 1;
        u8 const lo = this->get_memory(lo_addr);
        u8 const hi = this->get_memory(hi_addr);
        u8 const index = y_;
        oops_addr = hi << 8 | u8(lo + index);
        addr = (hi << 8 | lo) + index;
    }
    // ZPX/ZPY d,x
    if (0x14 <= col && col <= 0x17) {
        auto const use_y = (col == 0x16 || col == 0x17) && (row == 0x80 || row == 0xA0);
        auto const index = use_y ? y_ : x_;
        this->cycle();
        addr = u8(this->fetch_next() + index);
    }
    // ABX/ABY a,x
    if (0x19 <= col && col <= 0x1F && (col != 0x1A)) {
        auto const use_y = col <= 0x1B || (col >= 0x1E && (row == 0x80 || row == 0xA0));
        auto const index = use_y ? y_ : x_;
        auto const lo = this->fetch_next();
        auto const hi = this->fetch_next();
        oops_addr = hi << 8 | u8(lo + index);
        addr = (hi << 8 | lo) + index;
    }
    // REL *+d
    if (col == 0x10) {
        auto const offset = this->fetch_next();
        addr = pc_ + offset;
    }

    // END OF ADDRESSING

    // BRK
    if (instruction == 0x00) {
        this->cycle();
        ++pc_;
        this->stack_push(pc_ >> 8);
        this->stack_push(pc_);
        this->stack_push(p_);
        auto const lo = this->get_memory(0xFFFE);
        auto const hi = this->get_memory(0xFFFF);
        pc_ = hi << 8 | lo;
        this->b(true);
    }
    // RTI
    if (instruction == 0x40) {
        this->cycle();
        this->p(this->stack_pull());
        this->cycle();
        auto const lo = this->stack_pull();
        auto const hi = this->stack_pull();
        pc_ = hi << 8 | lo;
    }
    if (col == 0x08) {
        // PHP
        if (row == 0x00) {
            this->cycle();
            auto const m = p_;
            this->stack_push(m);
        }
        // PLP
        if (row == 0x20) {
            this->cycle();
            auto const m = this->stack_pull();
            this->cycle();
            p_ = m;
        }
        // PHA
        if (row == 0x40) {
            this->cycle();
            auto const m = a_;
            this->stack_push(m);
        }
        // PLA
        if (row == 0x60) {
            this->cycle();
            auto const m = this->stack_pull();
            this->cycle();
            a_ = m;
            this->n(m & 0x80);
            this->z(m == 0x00);
        }
        // DEY
        if (row == 0x80) {
            this->cycle();
            u8 const m = y_ - 1;
            y_ = m;
            this->n(m & 0x80);
            this->z(m == 0x00);
        }
        // INY
        if (row == 0xC0) {
            this->cycle();
            u8 const m = y_ + 1;
            y_ = m;
            this->n(m & 0x80);
            this->z(m == 0x00);
        }
        // INX
        if (row == 0xE0) {
            this->cycle();
            u8 const m = x_ + 1;
            x_ = m;
            this->n(m & 0x80);
            this->z(m == 0x00);
        }
    }
    // Branching
    if (col == 0x10) {
        bool const expect = row & 0b10'0000;

        bool actual;
        switch (row) {
        case 0x00:  // BPL  n
        case 0x20:  // BMI  N
            actual = this->n();
            break;
        case 0x40:  // BVC  v
        case 0x60:  // BVS  V
            actual = this->v();
            break;
        case 0x80:  // BCC  c
        case 0xA0:  // BCS  C
            actual = this->c();
            break;
        case 0xC0:  // BNE  z
        case 0xE0:  // BEQ  Z
            actual = this->z();
            break;
        }

        if (actual == expect) {
            this->cycle();
            if ((pc_ ^ addr) & 0xFF00) {
                this->cycle();
            }
            pc_ = addr;
        }
    }
    // Flags
    if (col == 0x18 && row != 0x80) {
        this->cycle();

        switch (row) {
        case 0x00:  this->c(false); break; // CLC
        case 0x20:  this->c(true);  break; // SEC

        case 0x40:  this->i(false); break; // CLI
        case 0x60:  this->i(true);  break; // SEI

        case 0xA0:  this->v(false); break; // CLV

        case 0xC0:  this->d(false); break; // CLD
        case 0xE0:  this->d(true);  break; // SED
        }
    }
    // GREEN
    if (((col & 0b11) == 0b01) && row != 0x80) {
        if (oops_instruction && (addr != oops_addr)) {
            this->get_memory(oops_addr);
        }
        auto const m = use_imm ? imm : this->get_memory(addr);

        u8 result;

        // ORA
        if (row == 0x00) {
            result = a_ | m;
        }
        // AND
        if (row == 0x20) {
            result = a_ & m;
        }
        // EOR
        if (row == 0x40) {
            result = a_ ^ m;
        }
        // ADC
        if (row == 0x60) {
            u16 const sum = a_ + m + c();
            result = sum;
            this->c(result != sum);
            this->v((a_ ^ result) & (m ^ result) & 0x80);
        }
        // LDA
        if (row == 0xA0) {
            result = m;
        }
        // CMP
        if (row == 0xC0) {
            result = a_ - m;
            this->c(s8(a_) >= s8(m));
        }
        // SBC
        if (row == 0xE0) {
            u16 const diff = a_ - m - !c();
            result = diff;
            this->c(result == diff);
            this->v(((a_ ^ result) ^ (m ^ result)) & 0x80);
        }

        if (row != 0xC0) {
            a_ = result;
        }

        this->n(result & 0x80);
        this->z(result == 0x00);
    }
    // BLUE
    if ((col & 0b11) == 0b10) {
        if (col != 0x02 && col != 0x12 && col != 0x1A && row <= 0x60) {
            auto const use_a = (col == 0x0A);
            auto const m = use_a ? a_ : this->get_memory(addr);

            this->cycle();

            u8 result;

            // ASL
            if (row == 0x00) {
                result = m << 1;
                this->c(m & 0x80);
            }
            // ROL
            if (row == 0x20) {
                result = m << 1 | (m & 0x80) >> 7;
                this->c(m & 0x80);
            }
            // LSR
            if (row == 0x40) {
                result = m >> 1;
                this->c(m & 0x01);
            }
            // ROR
            if (row == 0x60) {
                result = m >> 1 | (m & 0x01) << 7;
                this->c(m & 0x01);
            }

            if (use_a) {
                a_ = result;
            } else {
                if (oops_instruction) {
                    this->get_memory(oops_addr);
                }
                this->set_memory(addr, result);
            }

            this->n(result & 0x80);
            this->z(result == 0x00);
        }
        // NOP
        if (instruction == 0xEA) {
            this->cycle();
        }
    }
    // DEX
    if (row == 0xC0 && col == 0x0A) {
        this->cycle();
        u8 const m = x_ - 1;
        x_ = m;
        this->n(m & 0x80);
        this->z(m == 0x00);
    }
    // DEC
    if (row == 0xC0 && (col & 0b00111) == 0b110) {
        auto const m = this->get_memory(addr);
        this->cycle();
        u8 const result = m - 1;
        if (oops_instruction) {
            this->get_memory(oops_addr);
        }
        this->set_memory(addr, result);
        this->n(result & 0x80);
        this->z(result == 0x00);
    }
    // INC
    if (row == 0xE0 && (col & 0b00111) == 0b110) {
        auto const m = this->get_memory(addr);
        this->cycle();
        u8 const result = m + 1;
        if (oops_instruction) {
            this->get_memory(oops_addr);
        }
        this->set_memory(addr, result);
        this->n(result & 0x80);
        this->z(result == 0x00);
    }
    // BIT
    if (row == 0x20 && (col == 0x04 || col == 0x0C)) {
        auto const m = use_imm ? imm : this->get_memory(addr);
        auto const result = a_ & m;
        this->n(result & 0x80);
        this->v(result & 0x40);
        this->z(result == 0x00);
    }
    // JMP
    if (col == 0x0C && (row == 0x40 || row == 0x60)) {
        pc_ = addr;
    }
    // JSR
    if (instruction == 0x20) {
        this->cycle();
        this->stack_push(pc_ >> 8);
        this->stack_push(pc_);
        pc_ = addr;
    }
    // RTS
    if (instruction == 0x60) {
        this->cycle();
        this->cycle();
        this->cycle();
        auto const lo = this->stack_pull();
        auto const hi = this->stack_pull();
        pc_ = hi << 8 | lo;
    }
    // CPX CPY
    if ((row == 0xC0 || row == 0xE0) && (col == 0x00 || col == 0x04 || col == 0x0C)) {
        auto const m = use_imm ? imm : this->get_memory(addr);
        auto const src = (row == 0xC0) ? y_ : x_;
        u8 const result = src - m;
        this->c(s8(src) >= s8(m));
        this->n(result & 0x80);
        this->z(result == 0x00);
    }
    if (row == 0xA0) {
        // LDX
        if ((col & 0b11) == 0b10 && col != 0x0A && col != 0x12 && col != 0x1A) {
            if (oops_instruction && (addr != oops_addr)) {
                this->get_memory(oops_addr);
            }
            auto const m = use_imm ? imm : this->get_memory(addr);
            x_ = m;
            this->n(m & 0x80);
            this->z(m == 0x00);
        }
        // TAX
        if (col == 0x0A) {
            this->cycle();
            auto const m = a_;
            x_ = m;
            this->n(m & 0x80);
            this->z(m == 0x00);
        }
        // TSX
        if (col == 0x1A) {
            this->cycle();
            auto const m = s_;
            x_ = m;
            this->n(m & 0x80);
            this->z(m == 0x00);
        }
        // LDY
        if ((col & 0b11) == 0b00 && col != 0x08 && col != 0x10 && col != 0x18) {
            if (oops_instruction && (addr != oops_addr)) {
                this->get_memory(oops_addr);
            }
            auto const m = use_imm ? imm : this->get_memory(addr);
            y_ = m;
            this->n(m & 0x80);
            this->z(m == 0x00);
        }
        // TAY
        if (col == 0x08) {
            this->cycle();
            auto const m = a_;
            y_ = m;
            this->n(m & 0x80);
            this->z(m == 0x00);
        }
    }
    if (row == 0x80) {
        // STA
        if ((col & 0b11) == 0b01 && col != 0x09) {
            if (oops_instruction) {
                this->get_memory(oops_addr);
            }
            this->set_memory(addr, a_);
        }
        // STX
        if (col == 0x06 || col == 0x0E || col == 0x16) {
            if (oops_instruction) {
                this->get_memory(oops_addr);
            }
            this->set_memory(addr, x_);
        }
        // TXA
        if (col == 0x0A) {
            this->cycle();
            auto const m = x_;
            a_ = m;
            this->n(m & 0x80);
            this->z(m == 0x00);
        }
        // TXS
        if (col == 0x1A) {
            this->cycle();
            auto const m = x_;
            s_ = m;
        }
        // STY
        if (col == 0x04 || col == 0x0C || col == 0x14) {
            if (oops_instruction) {
                this->get_memory(oops_addr);
            }
            this->set_memory(addr, y_);
        }
        // TYA
        if (col == 0x18) {
            this->cycle();
            auto const m = y_;
            a_ = m;
            this->n(m & 0x80);
            this->z(m == 0x00);
        }
    }
}

auto CPU::reset() noexcept -> void
{
    s_ -= 3;
    pc_ = this->get_u16(0xFFFC);
}

auto CPU::get_memory(u16 addr) const noexcept -> u8
{
    this->cycle();

    if (auto lock = memory_.lock()) {
        return lock->get(addr);
    } else {
        return 0x00;
    }
}

auto CPU::set_memory(u16 addr, u8 v) noexcept -> void
{
    this->cycle();

    if (auto lock = memory_.lock()) {
        lock->set(addr, v);
    }
}

auto CPU::get_u16(u16 addr) const noexcept -> u16
{
    auto const lo = this->get_memory(addr);
    auto const hi = this->get_memory(addr + 1);
    return hi << 8 | lo;
}

auto CPU::fetch_next() noexcept -> u8
{
    return this->get_memory(pc_++);
}

auto CPU::cycle() const noexcept -> void
{
    ++cycles_;
}
