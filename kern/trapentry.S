/* See COPYRIGHT for copyright information. */

#include <inc/mmu.h>
#include <inc/memlayout.h>
#include <inc/trap.h>



###################################################################
# exceptions/interrupts
###################################################################

/* TRAPHANDLER defines a globally-visible function for handling a trap.
 * It pushes a trap number onto the stack, then jumps to _alltraps.
 * Use TRAPHANDLER for traps where the CPU automatically pushes an error code.
 *
 * You shouldn't call a TRAPHANDLER function from C, but you may
 * need to _declare_ one in C (for instance, to get a function pointer
 * during IDT setup).  You can declare the function with
 *   void NAME();
 * where NAME is the argument passed to TRAPHANDLER.
 */
#define TRAPHANDLER(name, num)						\
	.globl name;		/* define global symbol for 'name' */	\
	.type name, @function;	/* symbol type is function */		\
	.align 2;		/* align function definition */		\
	name:			/* function starts here */		\
	pushl $(num);							\
	jmp _alltraps

/* Use TRAPHANDLER_NOEC for traps where the CPU doesn't push an error code.
 * It pushes a 0 in place of the error code, so the trap frame has the same
 * format in either case.
 */
#define TRAPHANDLER_NOEC(name, num)					\
	.globl name;							\
	.type name, @function;						\
	.align 2;							\
	name:								\
	pushl $0;							\
	pushl $(num);							\
	jmp _alltraps

.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
TRAPHANDLER_NOEC(nmi_handler, 0x2)
TRAPHANDLER_NOEC(breakpoint_handler, 0x3)
TRAPHANDLER_NOEC(overflow_handler, 0x4)
TRAPHANDLER_NOEC(bdrgeexceed_handler, 0x5)
TRAPHANDLER_NOEC(invalidop_handler, 0x6)
TRAPHANDLER_NOEC(nomathcopro_handler, 0x7)
TRAPHANDLER(dbfault_handler, 0x8)
TRAPHANDLER(invalidTSS_handler, 0xA)
TRAPHANDLER(sgmtnotpresent_handler, 0xB)
TRAPHANDLER(stacksgmtfault_handler,0xC)
TRAPHANDLER(generalprotection_handler, 0xD)
TRAPHANDLER(pagefault_handler, 0xE)
TRAPHANDLER_NOEC(FPUerror_handler, 0x10)
TRAPHANDLER(alignmentcheck_handler, 0x11)
TRAPHANDLER_NOEC(machinecheck_handler, 0x12)
TRAPHANDLER_NOEC(SIMDFPexception_handler, 0x13)
TRAPHANDLER_NOEC(systemcall_handler, 0x30)
/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
pushw $0
pushw %ds
pushw $0
pushw %es
pushal
pushl %esp
movw $(GD_KD),%ax
movw %ax,%ds
movw %ax,%es
call trap