# Disable the generation of compressed instructions.
.option norvc

.section .text.init

.global _start
_start:
    # Hart ID Register
    csrr    t0, mhartid
    bnez    t0, wait_for_interrupt
    # Supervisor Address Translation and Protection Register
    # 0 -> Bare: No translation or protection.
    csrw    satp, zero

# Disable code sequence relaxation.
.option push
.option norelax
    la      gp, _global_pointer
.option pop

    # Set up the stack.
    la      sp, _stack_end

    # Clear the BSS.
    la      a0, _bss_start
    la      a1, _bss_end
bss_clear:
    sd      zero, (a0)
    addi    a0, a0, 8
    bltu    a0, a1, bss_clear

    # We're in Zig!
    tail    zmain

wait_for_interrupt:
    wfi
    j       wait_for_interrupt
