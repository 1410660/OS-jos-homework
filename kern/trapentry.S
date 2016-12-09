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
 * You should not call a TRAPHANDLER function from C, but you may
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

/* Use TRAPHANDLER_NOEC for traps where the CPU does not push an error code.
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
TRAPHANDLER_NOEC(Divide_error,T_DIVIDE);
TRAPHANDLER_NOEC(Debug,T_DEBUG);
TRAPHANDLER_NOEC(Non_MaskableInterrupt,T_NMI );
TRAPHANDLER_NOEC(Breakpoint,T_BRKPT );
TRAPHANDLER_NOEC(Overflow,4);
TRAPHANDLER_NOEC(BOUND_Range_Exceeded,5);
TRAPHANDLER_NOEC(Invalid_Opcode,6);
TRAPHANDLER_NOEC(Device_Not_Available,7);
TRAPHANDLER(Double_Fault,8);
TRAPHANDLER(Invalid_TSS,10);
TRAPHANDLER(Segment_Not_Present,11);
TRAPHANDLER(Stack_Fault,12);
TRAPHANDLER(General_Protection,13);
TRAPHANDLER(Page_Fault,14);
TRAPHANDLER_NOEC(FPU_Floating_Point_Error,16);
TRAPHANDLER(Alignment_Check,17);
TRAPHANDLER_NOEC(Machine_Check,18);
TRAPHANDLER_NOEC(SIMD_Floating_Point_Exception,19);
TRAPHANDLER_NOEC(systemcall_handler,48)


/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
	pushw $0x0
	pushw %ds
	pushw $0x0
	pushw %es 
	
	
	pushal
	pushl %esp
	movw $(GD_KD),%ax
	movw %ax,%ds
	movw %ax,%es
	call trap
