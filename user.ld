ENTRY(start)

SECTIONS {
    . = 0x1000000;

    /* Machine code */
    .text :{
        KEEP(*(.text.start));
        *(.text .text.*);
    }

    /* Read-only data */
    .rodata : ALIGN(4) {
        *(.rodata .rodata.*);
    }

    /* Data with initial values */
    .data : ALIGN(4) {
        *(.data .data.*);
    }

    /* Data which should be zeroed at startup */
    .bss : ALIGN(4) {
        *(.bss .bss.* .sbss .sbss.*);

        . = ALIGN(16);
        . += 64 * 1024; /* 64KB */
        __stack_top = .;

        ASSERT(. < 0x1800000, "too large executable");
    }
}
