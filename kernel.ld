ENTRY(boot)

SECTIONS {
    . = 0x80200000;

    .text : ALIGN(4096) {
        __text = .;
        KEEP(*(.text.boot));
        *(.text .text.*);
        __text_end = .;
    }

    .rodata : ALIGN(4096) {
        __rodata = .;
        *(.rodata .rodata.*);
        __rodata_end = .;
    }

    .data : ALIGN(4096) {
        __data = .;
        *(.data .data.*);
        __data_end = .;
    }

    .bss : ALIGN(4096) {
        __bss = .;
        *(.bss .bss.* .sbss .sbss.*);
        __bss_end = .;
    }

    . = ALIGN(4096);
    __stack_bottom = .;
    . += 128 * 1024; /* 128KB */
    __stack_top = .;

    . = ALIGN(4096);
    __free_ram = .;
    . += 64 * 1024 * 1024; /* 64MB */
    __free_ram_end = .;
}
