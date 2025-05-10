# Unnamed Zig kernel
A small project for me to learn more about kernel dev and Zig.
Loosely based on [OS in 1k lines of C](https://operating-system-in-1000-lines.vercel.app/en/).

# Design decisions
## Idle process
I am not sure how other kernels handle waiting for work, however I decided to use an idle process.
This is a process that is initialized at boot time, and only waits for interruptions in a loop.
It has PID 0, and no userland counterpart.
It will be switched to when no other process is available.
All other processes are spawned because of a userland process.

In the future, this process might do more than just waiting, and could perhaps perform bookkeeping operations.

Implementation detail: as the idle process does not have an userland, and since all kernel memory should be mapped in each process, I decided to perform segmentation of the kernel's virtual memory during initialization of the idle process.
This way, when initializing regular processes, their page table can be initialized by copying the idle process' and mapping their own user space.
