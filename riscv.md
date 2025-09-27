# Registers
## Common registers
There are 33 unprivileged registers: 32 "x" registers as well as pc.
- x0/zero: hardwired zero
- x1/ra (Return Address): where `ret` sends us
- x2/sp (Stack Pointer): address of the top of the stack
- x5-x7/t0-t2: temporary registers
- x8/fp (Frame Pointer): stack frame pointer
- x10-x11/a0-a1: function arguments/return values
- x12-x17/a2-a7: function arguments
- x18-x27/s0-s11: temporary registers (saved across calls)
- x28-x31/t3-t6: temporary registers
- pc/pc (Program Counter): address of next instruction

## Control and Status Registers

# Instructions
## Privileged Instructions
### SRET
Used to return from a trap.
SIE (interrupts enabled) is set to SPIE (previous interrupts enabled), the privilege mode is set to SPP (previous privilege) and SPP is set to U-mode.
