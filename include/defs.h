#ifndef _DEFS_H
#define _DEFS_H

// Every header file included shall be self-dependent to keep 
// away from "undefined errors" generated by the complier.
// In principle, all the headers should be independent,
// so they can be organized in any order within the including
// queue. However, frankly, that's hard to achieve without proper
// using of #include directive inside the header file itself.

#include "types.h"
#include "x86.h"
#include "kbd.h"
#include "console.h"
#include "memory.h"
#include "pic.h"
#include "trap.h"


// Global Functions & Variables

// trapasm.S
extern uint vectors[];

// trap.c
extern void trap_init(void);
extern void trap(struct trapframe *);

// pic.c
extern void pic_init(void);
extern void pic_enable_irq(uchar);
extern void pic_send_eoi(uchar);

// console.c
extern void console_init(void);
extern void cprintf(void *, int);
extern void console_intr(int);

// kbd.c
extern void kbd_init(void);
extern int kbdgetc(void);
extern void kbd_intr(void);

// mm.c
extern void mm_init(void);
extern uint get_free_page(void);
extern int free_page(uint);

// panic.c
extern void panic(void);

#endif
