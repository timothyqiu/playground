OUTPUT_ARCH("riscv")

ENTRY(_start)

SECTIONS
{
    /* https://github.com/qemu/qemu/blob/v9.0.2/hw/riscv/virt.c#L90 */
    . = 0x80000000;

    _kernel_start = .;

    .text : ALIGN(4K) {
        *(.text.init);
        *(.text);
    }

    .rodata : ALIGN(4K) {
        PROVIDE( _global_pointer = . );
        *(.rodata);
    }

    .data : ALIGN(4K) {
        *(.data);
    }

    .bss : ALIGN(4K) {
        PROVIDE( _bss_start = . );
        *(.bss);
        PROVIDE( _bss_end = . );
    }

    PROVIDE( _stack_start = _bss_end );
    PROVIDE( _stack_end = _bss_end + 0x4000 );

    _kernel_end = _stack_end;

    PROVIDE( _heap_start = _kernel_end );
    PROVIDE( _heap_end = _kernel_start + 128M );
}
