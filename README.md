# SukiSU Ultra – Xiaomi ysl (Redmi S2 / Redmi Y2)

**UNOFFICIAL PORT**  
This is **NOT an official implementation of SukiSU Ultra or KernelSU**.  
It is **not supported or endorsed** by the KernelSU/SukiSU developers.

---

I can't believe this took a month to finish —  
but yeah, that makes sense since I didn’t even know C.

---

## Device
- Xiaomi Redmi S2 / Redmi Y2 (`ysl`)

## Build
To build the kernel, just run:
```bash
./kernel_build_fixed.sh
```
Does it work?

Yes.
Also no.
It works for me, BUT backup your boot partition(and soul) before using anything I make.

## Status

Root & modules:  working(As far as I tested)

(found solution)LSPosed:  refuses to cooperate and device gets stuck on Redmi boot splash (don’t ask me why)
IMPORTANT!!!
Okay guys, hear me out, to make modules work a lot better, install Magic mount metamodule from kernelSU web, trust me with this no matter if your modules use mount operations or not.
at least that is for me, this is very important, even f you are not using YSL, you might as well try it if you have boot hang problems.


KPM:  doesn’t work without patches (untested, don’t care enough)

## License And Credits
This project is licensed under **GPL-2.0**).
Kernel base: **StormBreaker kernel** for Xiaomi ysl  
Linux kernel and all upstream code remain under **GPL-2.0**
KernelSU / SukiSU code is used under its original license.
