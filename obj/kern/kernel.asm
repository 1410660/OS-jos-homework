
obj/kern/kernel：     檔案格式 elf32-i386


Disassembly of section .text:

f0100000 <_start+0xeffffff4>:
.globl		_start
_start = RELOC(entry)

.globl entry
entry:
	movw	$0x1234,0x472			# warm boot
f0100000:	02 b0 ad 1b 00 00    	add    0x1bad(%eax),%dh
f0100006:	00 00                	add    %al,(%eax)
f0100008:	fe 4f 52             	decb   0x52(%edi)
f010000b:	e4 66                	in     $0x66,%al

f010000c <entry>:
f010000c:	66 c7 05 72 04 00 00 	movw   $0x1234,0x472
f0100013:	34 12 
	# physical addresses [0, 4MB).  This 4MB region will be suffice
	# until we set up our real page table in mem_init in lab 2.

	# Load the physical address of entry_pgdir into cr3.  entry_pgdir
	# is defined in entrypgdir.c.
	movl	$(RELOC(entry_pgdir)), %eax
f0100015:	b8 00 e0 11 00       	mov    $0x11e000,%eax
	movl	%eax, %cr3
f010001a:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl	%cr0, %eax
f010001d:	0f 20 c0             	mov    %cr0,%eax
	orl	$(CR0_PE|CR0_PG|CR0_WP), %eax
f0100020:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl	%eax, %cr0
f0100025:	0f 22 c0             	mov    %eax,%cr0

	# Now paging is enabled, but we're still running at a low EIP
	# (why is this okay?).  Jump up above KERNBASE before entering
	# C code.
	mov	$relocated, %eax
f0100028:	b8 2f 00 10 f0       	mov    $0xf010002f,%eax
	jmp	*%eax
f010002d:	ff e0                	jmp    *%eax

f010002f <relocated>:
relocated:

	# Clear the frame pointer register (EBP)
	# so that once we get into debugging C code,
	# stack backtraces will be terminated properly.
	movl	$0x0,%ebp			# nuke frame pointer
f010002f:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Set the stack pointer
	movl	$(bootstacktop),%esp
f0100034:	bc 00 e0 11 f0       	mov    $0xf011e000,%esp

	# now to C code
	call	i386_init
f0100039:	e8 6a 00 00 00       	call   f01000a8 <i386_init>

f010003e <spin>:

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <_panic>:
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void
_panic(const char *file, int line, const char *fmt,...)
{
f0100040:	55                   	push   %ebp
f0100041:	89 e5                	mov    %esp,%ebp
f0100043:	56                   	push   %esi
f0100044:	53                   	push   %ebx
f0100045:	83 ec 10             	sub    $0x10,%esp
f0100048:	8b 75 10             	mov    0x10(%ebp),%esi
	va_list ap;

	if (panicstr)
f010004b:	83 3d 80 3e 22 f0 00 	cmpl   $0x0,0xf0223e80
f0100052:	75 46                	jne    f010009a <_panic+0x5a>
		goto dead;
	panicstr = fmt;
f0100054:	89 35 80 3e 22 f0    	mov    %esi,0xf0223e80

	// Be extra sure that the machine is in as reasonable state
	__asm __volatile("cli; cld");
f010005a:	fa                   	cli    
f010005b:	fc                   	cld    

	va_start(ap, fmt);
f010005c:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic on CPU %d at %s:%d: ", cpunum(), file, line);
f010005f:	e8 cf 5c 00 00       	call   f0105d33 <cpunum>
f0100064:	8b 55 0c             	mov    0xc(%ebp),%edx
f0100067:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010006b:	8b 55 08             	mov    0x8(%ebp),%edx
f010006e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100072:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100076:	c7 04 24 40 64 10 f0 	movl   $0xf0106440,(%esp)
f010007d:	e8 5c 3e 00 00       	call   f0103ede <cprintf>
	vcprintf(fmt, ap);
f0100082:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100086:	89 34 24             	mov    %esi,(%esp)
f0100089:	e8 1d 3e 00 00       	call   f0103eab <vcprintf>
	cprintf("\n");
f010008e:	c7 04 24 ff 74 10 f0 	movl   $0xf01074ff,(%esp)
f0100095:	e8 44 3e 00 00       	call   f0103ede <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f010009a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000a1:	e8 3c 09 00 00       	call   f01009e2 <monitor>
f01000a6:	eb f2                	jmp    f010009a <_panic+0x5a>

f01000a8 <i386_init>:

static void boot_aps(void);

void
i386_init(void)
{
f01000a8:	55                   	push   %ebp
f01000a9:	89 e5                	mov    %esp,%ebp
f01000ab:	53                   	push   %ebx
f01000ac:	83 ec 14             	sub    $0x14,%esp
	extern char edata[], end[];

	// Before doing anything else, complete the ELF loading process.
	// Clear the uninitialized global data (BSS) section of our program.
	// This ensures that all static/global variables start out zero.
	memset(edata, 0, end - edata);
f01000af:	b8 04 50 26 f0       	mov    $0xf0265004,%eax
f01000b4:	2d 58 24 22 f0       	sub    $0xf0222458,%eax
f01000b9:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000bd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01000c4:	00 
f01000c5:	c7 04 24 58 24 22 f0 	movl   $0xf0222458,(%esp)
f01000cc:	e8 c8 55 00 00       	call   f0105699 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000d1:	e8 f9 05 00 00       	call   f01006cf <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000d6:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000dd:	00 
f01000de:	c7 04 24 ac 64 10 f0 	movl   $0xf01064ac,(%esp)
f01000e5:	e8 f4 3d 00 00       	call   f0103ede <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f01000ea:	e8 02 14 00 00       	call   f01014f1 <mem_init>

	// Lab 3 user environment initialization functions
	env_init();
f01000ef:	e8 0a 35 00 00       	call   f01035fe <env_init>
	trap_init();
f01000f4:	e8 90 3e 00 00       	call   f0103f89 <trap_init>

	// Lab 4 multiprocessor initialization functions
	mp_init();
f01000f9:	e8 1b 59 00 00       	call   f0105a19 <mp_init>
	lapic_init();
f01000fe:	66 90                	xchg   %ax,%ax
f0100100:	e8 49 5c 00 00       	call   f0105d4e <lapic_init>

	// Lab 4 multitasking initialization functions
	pic_init();
f0100105:	e8 01 3d 00 00       	call   f0103e0b <pic_init>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f010010a:	c7 04 24 a0 03 12 f0 	movl   $0xf01203a0,(%esp)
f0100111:	e8 83 5e 00 00       	call   f0105f99 <spin_lock>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100116:	83 3d 88 3e 22 f0 07 	cmpl   $0x7,0xf0223e88
f010011d:	77 24                	ja     f0100143 <i386_init+0x9b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010011f:	c7 44 24 0c 00 70 00 	movl   $0x7000,0xc(%esp)
f0100126:	00 
f0100127:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f010012e:	f0 
f010012f:	c7 44 24 04 58 00 00 	movl   $0x58,0x4(%esp)
f0100136:	00 
f0100137:	c7 04 24 c7 64 10 f0 	movl   $0xf01064c7,(%esp)
f010013e:	e8 fd fe ff ff       	call   f0100040 <_panic>
	void *code;
	struct Cpu *c;

	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);
f0100143:	b8 46 59 10 f0       	mov    $0xf0105946,%eax
f0100148:	2d cc 58 10 f0       	sub    $0xf01058cc,%eax
f010014d:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100151:	c7 44 24 04 cc 58 10 	movl   $0xf01058cc,0x4(%esp)
f0100158:	f0 
f0100159:	c7 04 24 00 70 00 f0 	movl   $0xf0007000,(%esp)
f0100160:	e8 81 55 00 00       	call   f01056e6 <memmove>

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100165:	6b 05 c4 43 22 f0 74 	imul   $0x74,0xf02243c4,%eax
f010016c:	05 20 40 22 f0       	add    $0xf0224020,%eax
f0100171:	3d 20 40 22 f0       	cmp    $0xf0224020,%eax
f0100176:	0f 86 a6 00 00 00    	jbe    f0100222 <i386_init+0x17a>
f010017c:	bb 20 40 22 f0       	mov    $0xf0224020,%ebx
		if (c == cpus + cpunum())  // We've started already.
f0100181:	e8 ad 5b 00 00       	call   f0105d33 <cpunum>
f0100186:	6b c0 74             	imul   $0x74,%eax,%eax
f0100189:	05 20 40 22 f0       	add    $0xf0224020,%eax
f010018e:	39 c3                	cmp    %eax,%ebx
f0100190:	74 39                	je     f01001cb <i386_init+0x123>
f0100192:	89 d8                	mov    %ebx,%eax
f0100194:	2d 20 40 22 f0       	sub    $0xf0224020,%eax
			continue;

		// Tell mpentry.S what stack to use 
		mpentry_kstack = percpu_kstacks[c - cpus] + KSTKSIZE;
f0100199:	c1 f8 02             	sar    $0x2,%eax
f010019c:	69 c0 35 c2 72 4f    	imul   $0x4f72c235,%eax,%eax
f01001a2:	c1 e0 0f             	shl    $0xf,%eax
f01001a5:	8d 80 00 d0 22 f0    	lea    -0xfdd3000(%eax),%eax
f01001ab:	a3 84 3e 22 f0       	mov    %eax,0xf0223e84
		// Start the CPU at mpentry_start
		lapic_startap(c->cpu_id, PADDR(code));
f01001b0:	c7 44 24 04 00 70 00 	movl   $0x7000,0x4(%esp)
f01001b7:	00 
f01001b8:	0f b6 03             	movzbl (%ebx),%eax
f01001bb:	89 04 24             	mov    %eax,(%esp)
f01001be:	e8 c3 5c 00 00       	call   f0105e86 <lapic_startap>
		// Wait for the CPU to finish some basic setup in mp_main()
		while(c->cpu_status != CPU_STARTED)
f01001c3:	8b 43 04             	mov    0x4(%ebx),%eax
f01001c6:	83 f8 01             	cmp    $0x1,%eax
f01001c9:	75 f8                	jne    f01001c3 <i386_init+0x11b>
	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f01001cb:	83 c3 74             	add    $0x74,%ebx
f01001ce:	6b 05 c4 43 22 f0 74 	imul   $0x74,0xf02243c4,%eax
f01001d5:	05 20 40 22 f0       	add    $0xf0224020,%eax
f01001da:	39 c3                	cmp    %eax,%ebx
f01001dc:	72 a3                	jb     f0100181 <i386_init+0xd9>
f01001de:	eb 42                	jmp    f0100222 <i386_init+0x17a>
	boot_aps();

	// Should always have idle processes at first.
	int i;
	for (i = 0; i < NCPU; i++){
		ENV_CREATE(user_idle, ENV_TYPE_IDLE);
f01001e0:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01001e7:	00 
f01001e8:	c7 44 24 04 5e 89 00 	movl   $0x895e,0x4(%esp)
f01001ef:	00 
f01001f0:	c7 04 24 2c fe 18 f0 	movl   $0xf018fe2c,(%esp)
f01001f7:	e8 ff 35 00 00       	call   f01037fb <env_create>
	// Starting non-boot CPUs
	boot_aps();

	// Should always have idle processes at first.
	int i;
	for (i = 0; i < NCPU; i++){
f01001fc:	83 eb 01             	sub    $0x1,%ebx
f01001ff:	75 df                	jne    f01001e0 <i386_init+0x138>
#if defined(TEST)
	// Don't touch -- used by grading script!
	ENV_CREATE(TEST, ENV_TYPE_USER);
#else
	// Touch all you want.
	ENV_CREATE(user_primes, ENV_TYPE_USER);
f0100201:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0100208:	00 
f0100209:	c7 44 24 04 21 8a 00 	movl   $0x8a21,0x4(%esp)
f0100210:	00 
f0100211:	c7 04 24 37 9a 21 f0 	movl   $0xf0219a37,(%esp)
f0100218:	e8 de 35 00 00       	call   f01037fb <env_create>
#endif // TEST*

	// Schedule and run the first user environment!
	sched_yield();
f010021d:	e8 dd 45 00 00       	call   f01047ff <sched_yield>
	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100222:	bb 08 00 00 00       	mov    $0x8,%ebx
f0100227:	eb b7                	jmp    f01001e0 <i386_init+0x138>

f0100229 <mp_main>:
}

// Setup code for APs
void
mp_main(void)
{
f0100229:	55                   	push   %ebp
f010022a:	89 e5                	mov    %esp,%ebp
f010022c:	83 ec 18             	sub    $0x18,%esp
	// We are in high EIP now, safe to switch to kern_pgdir 
	lcr3(PADDR(kern_pgdir));
f010022f:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100234:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0100239:	77 20                	ja     f010025b <mp_main+0x32>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010023b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010023f:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f0100246:	f0 
f0100247:	c7 44 24 04 6f 00 00 	movl   $0x6f,0x4(%esp)
f010024e:	00 
f010024f:	c7 04 24 c7 64 10 f0 	movl   $0xf01064c7,(%esp)
f0100256:	e8 e5 fd ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f010025b:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0100260:	0f 22 d8             	mov    %eax,%cr3
	cprintf("SMP: CPU %d starting\n", cpunum());
f0100263:	e8 cb 5a 00 00       	call   f0105d33 <cpunum>
f0100268:	89 44 24 04          	mov    %eax,0x4(%esp)
f010026c:	c7 04 24 d3 64 10 f0 	movl   $0xf01064d3,(%esp)
f0100273:	e8 66 3c 00 00       	call   f0103ede <cprintf>

	lapic_init();
f0100278:	e8 d1 5a 00 00       	call   f0105d4e <lapic_init>
	env_init_percpu();
f010027d:	e8 52 33 00 00       	call   f01035d4 <env_init_percpu>
	trap_init_percpu();
f0100282:	e8 79 3c 00 00       	call   f0103f00 <trap_init_percpu>
	xchg(&thiscpu->cpu_status, CPU_STARTED); // tell boot_aps() we're up
f0100287:	e8 a7 5a 00 00       	call   f0105d33 <cpunum>
f010028c:	6b d0 74             	imul   $0x74,%eax,%edx
f010028f:	81 c2 20 40 22 f0    	add    $0xf0224020,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f0100295:	b8 01 00 00 00       	mov    $0x1,%eax
f010029a:	f0 87 42 04          	lock xchg %eax,0x4(%edx)
f010029e:	c7 04 24 a0 03 12 f0 	movl   $0xf01203a0,(%esp)
f01002a5:	e8 ef 5c 00 00       	call   f0105f99 <spin_lock>
	// to start running processes on this CPU.  But make sure that
	// only one CPU can enter the scheduler at a time!
	//
	// Your code here:
	lock_kernel();
	sched_yield();
f01002aa:	e8 50 45 00 00       	call   f01047ff <sched_yield>

f01002af <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f01002af:	55                   	push   %ebp
f01002b0:	89 e5                	mov    %esp,%ebp
f01002b2:	53                   	push   %ebx
f01002b3:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f01002b6:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f01002b9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01002bc:	89 44 24 08          	mov    %eax,0x8(%esp)
f01002c0:	8b 45 08             	mov    0x8(%ebp),%eax
f01002c3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01002c7:	c7 04 24 e9 64 10 f0 	movl   $0xf01064e9,(%esp)
f01002ce:	e8 0b 3c 00 00       	call   f0103ede <cprintf>
	vcprintf(fmt, ap);
f01002d3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01002d7:	8b 45 10             	mov    0x10(%ebp),%eax
f01002da:	89 04 24             	mov    %eax,(%esp)
f01002dd:	e8 c9 3b 00 00       	call   f0103eab <vcprintf>
	cprintf("\n");
f01002e2:	c7 04 24 ff 74 10 f0 	movl   $0xf01074ff,(%esp)
f01002e9:	e8 f0 3b 00 00       	call   f0103ede <cprintf>
	va_end(ap);
}
f01002ee:	83 c4 14             	add    $0x14,%esp
f01002f1:	5b                   	pop    %ebx
f01002f2:	5d                   	pop    %ebp
f01002f3:	c3                   	ret    
f01002f4:	66 90                	xchg   %ax,%ax
f01002f6:	66 90                	xchg   %ax,%ax
f01002f8:	66 90                	xchg   %ax,%ax
f01002fa:	66 90                	xchg   %ax,%ax
f01002fc:	66 90                	xchg   %ax,%ax
f01002fe:	66 90                	xchg   %ax,%ax

f0100300 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f0100300:	55                   	push   %ebp
f0100301:	89 e5                	mov    %esp,%ebp

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100303:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100308:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f0100309:	a8 01                	test   $0x1,%al
f010030b:	74 08                	je     f0100315 <serial_proc_data+0x15>
f010030d:	b2 f8                	mov    $0xf8,%dl
f010030f:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f0100310:	0f b6 c0             	movzbl %al,%eax
f0100313:	eb 05                	jmp    f010031a <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f0100315:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f010031a:	5d                   	pop    %ebp
f010031b:	c3                   	ret    

f010031c <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f010031c:	55                   	push   %ebp
f010031d:	89 e5                	mov    %esp,%ebp
f010031f:	53                   	push   %ebx
f0100320:	83 ec 04             	sub    $0x4,%esp
f0100323:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f0100325:	eb 2a                	jmp    f0100351 <cons_intr+0x35>
		if (c == 0)
f0100327:	85 d2                	test   %edx,%edx
f0100329:	74 26                	je     f0100351 <cons_intr+0x35>
			continue;
		cons.buf[cons.wpos++] = c;
f010032b:	a1 24 32 22 f0       	mov    0xf0223224,%eax
f0100330:	8d 48 01             	lea    0x1(%eax),%ecx
f0100333:	89 0d 24 32 22 f0    	mov    %ecx,0xf0223224
f0100339:	88 90 20 30 22 f0    	mov    %dl,-0xfddcfe0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f010033f:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100345:	75 0a                	jne    f0100351 <cons_intr+0x35>
			cons.wpos = 0;
f0100347:	c7 05 24 32 22 f0 00 	movl   $0x0,0xf0223224
f010034e:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f0100351:	ff d3                	call   *%ebx
f0100353:	89 c2                	mov    %eax,%edx
f0100355:	83 f8 ff             	cmp    $0xffffffff,%eax
f0100358:	75 cd                	jne    f0100327 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f010035a:	83 c4 04             	add    $0x4,%esp
f010035d:	5b                   	pop    %ebx
f010035e:	5d                   	pop    %ebp
f010035f:	c3                   	ret    

f0100360 <kbd_proc_data>:
f0100360:	ba 64 00 00 00       	mov    $0x64,%edx
f0100365:	ec                   	in     (%dx),%al
{
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
f0100366:	a8 01                	test   $0x1,%al
f0100368:	0f 84 ef 00 00 00    	je     f010045d <kbd_proc_data+0xfd>
f010036e:	b2 60                	mov    $0x60,%dl
f0100370:	ec                   	in     (%dx),%al
f0100371:	89 c2                	mov    %eax,%edx
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f0100373:	3c e0                	cmp    $0xe0,%al
f0100375:	75 0d                	jne    f0100384 <kbd_proc_data+0x24>
		// E0 escape character
		shift |= E0ESC;
f0100377:	83 0d 00 30 22 f0 40 	orl    $0x40,0xf0223000
		return 0;
f010037e:	b8 00 00 00 00       	mov    $0x0,%eax
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100383:	c3                   	ret    
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f0100384:	55                   	push   %ebp
f0100385:	89 e5                	mov    %esp,%ebp
f0100387:	53                   	push   %ebx
f0100388:	83 ec 14             	sub    $0x14,%esp

	if (data == 0xE0) {
		// E0 escape character
		shift |= E0ESC;
		return 0;
	} else if (data & 0x80) {
f010038b:	84 c0                	test   %al,%al
f010038d:	79 37                	jns    f01003c6 <kbd_proc_data+0x66>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f010038f:	8b 0d 00 30 22 f0    	mov    0xf0223000,%ecx
f0100395:	89 cb                	mov    %ecx,%ebx
f0100397:	83 e3 40             	and    $0x40,%ebx
f010039a:	83 e0 7f             	and    $0x7f,%eax
f010039d:	85 db                	test   %ebx,%ebx
f010039f:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f01003a2:	0f b6 d2             	movzbl %dl,%edx
f01003a5:	0f b6 82 60 66 10 f0 	movzbl -0xfef99a0(%edx),%eax
f01003ac:	83 c8 40             	or     $0x40,%eax
f01003af:	0f b6 c0             	movzbl %al,%eax
f01003b2:	f7 d0                	not    %eax
f01003b4:	21 c1                	and    %eax,%ecx
f01003b6:	89 0d 00 30 22 f0    	mov    %ecx,0xf0223000
		return 0;
f01003bc:	b8 00 00 00 00       	mov    $0x0,%eax
f01003c1:	e9 9d 00 00 00       	jmp    f0100463 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f01003c6:	8b 0d 00 30 22 f0    	mov    0xf0223000,%ecx
f01003cc:	f6 c1 40             	test   $0x40,%cl
f01003cf:	74 0e                	je     f01003df <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f01003d1:	83 c8 80             	or     $0xffffff80,%eax
f01003d4:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f01003d6:	83 e1 bf             	and    $0xffffffbf,%ecx
f01003d9:	89 0d 00 30 22 f0    	mov    %ecx,0xf0223000
	}

	shift |= shiftcode[data];
f01003df:	0f b6 d2             	movzbl %dl,%edx
f01003e2:	0f b6 82 60 66 10 f0 	movzbl -0xfef99a0(%edx),%eax
f01003e9:	0b 05 00 30 22 f0    	or     0xf0223000,%eax
	shift ^= togglecode[data];
f01003ef:	0f b6 8a 60 65 10 f0 	movzbl -0xfef9aa0(%edx),%ecx
f01003f6:	31 c8                	xor    %ecx,%eax
f01003f8:	a3 00 30 22 f0       	mov    %eax,0xf0223000

	c = charcode[shift & (CTL | SHIFT)][data];
f01003fd:	89 c1                	mov    %eax,%ecx
f01003ff:	83 e1 03             	and    $0x3,%ecx
f0100402:	8b 0c 8d 40 65 10 f0 	mov    -0xfef9ac0(,%ecx,4),%ecx
f0100409:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f010040d:	0f b6 da             	movzbl %dl,%ebx
	if (shift & CAPSLOCK) {
f0100410:	a8 08                	test   $0x8,%al
f0100412:	74 1b                	je     f010042f <kbd_proc_data+0xcf>
		if ('a' <= c && c <= 'z')
f0100414:	89 da                	mov    %ebx,%edx
f0100416:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f0100419:	83 f9 19             	cmp    $0x19,%ecx
f010041c:	77 05                	ja     f0100423 <kbd_proc_data+0xc3>
			c += 'A' - 'a';
f010041e:	83 eb 20             	sub    $0x20,%ebx
f0100421:	eb 0c                	jmp    f010042f <kbd_proc_data+0xcf>
		else if ('A' <= c && c <= 'Z')
f0100423:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f0100426:	8d 4b 20             	lea    0x20(%ebx),%ecx
f0100429:	83 fa 19             	cmp    $0x19,%edx
f010042c:	0f 46 d9             	cmovbe %ecx,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f010042f:	f7 d0                	not    %eax
f0100431:	89 c2                	mov    %eax,%edx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100433:	89 d8                	mov    %ebx,%eax
			c += 'a' - 'A';
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f0100435:	f6 c2 06             	test   $0x6,%dl
f0100438:	75 29                	jne    f0100463 <kbd_proc_data+0x103>
f010043a:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f0100440:	75 21                	jne    f0100463 <kbd_proc_data+0x103>
		cprintf("Rebooting!\n");
f0100442:	c7 04 24 03 65 10 f0 	movl   $0xf0106503,(%esp)
f0100449:	e8 90 3a 00 00       	call   f0103ede <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010044e:	ba 92 00 00 00       	mov    $0x92,%edx
f0100453:	b8 03 00 00 00       	mov    $0x3,%eax
f0100458:	ee                   	out    %al,(%dx)
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100459:	89 d8                	mov    %ebx,%eax
f010045b:	eb 06                	jmp    f0100463 <kbd_proc_data+0x103>
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
		return -1;
f010045d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100462:	c3                   	ret    
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100463:	83 c4 14             	add    $0x14,%esp
f0100466:	5b                   	pop    %ebx
f0100467:	5d                   	pop    %ebp
f0100468:	c3                   	ret    

f0100469 <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f0100469:	55                   	push   %ebp
f010046a:	89 e5                	mov    %esp,%ebp
f010046c:	57                   	push   %edi
f010046d:	56                   	push   %esi
f010046e:	53                   	push   %ebx
f010046f:	83 ec 1c             	sub    $0x1c,%esp
f0100472:	89 c7                	mov    %eax,%edi

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100474:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100479:	ec                   	in     (%dx),%al
static void
serial_putc(int c)
{
	int i;
	
	for (i = 0;
f010047a:	a8 20                	test   $0x20,%al
f010047c:	75 21                	jne    f010049f <cons_putc+0x36>
f010047e:	bb 00 32 00 00       	mov    $0x3200,%ebx
f0100483:	b9 84 00 00 00       	mov    $0x84,%ecx
f0100488:	be fd 03 00 00       	mov    $0x3fd,%esi
f010048d:	89 ca                	mov    %ecx,%edx
f010048f:	ec                   	in     (%dx),%al
f0100490:	ec                   	in     (%dx),%al
f0100491:	ec                   	in     (%dx),%al
f0100492:	ec                   	in     (%dx),%al
f0100493:	89 f2                	mov    %esi,%edx
f0100495:	ec                   	in     (%dx),%al
f0100496:	a8 20                	test   $0x20,%al
f0100498:	75 05                	jne    f010049f <cons_putc+0x36>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f010049a:	83 eb 01             	sub    $0x1,%ebx
f010049d:	75 ee                	jne    f010048d <cons_putc+0x24>
	     i++)
		delay();
	
	outb(COM1 + COM_TX, c);
f010049f:	89 f8                	mov    %edi,%eax
f01004a1:	0f b6 c0             	movzbl %al,%eax
f01004a4:	89 45 e4             	mov    %eax,-0x1c(%ebp)
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01004a7:	ba f8 03 00 00       	mov    $0x3f8,%edx
f01004ac:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01004ad:	b2 79                	mov    $0x79,%dl
f01004af:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f01004b0:	84 c0                	test   %al,%al
f01004b2:	78 21                	js     f01004d5 <cons_putc+0x6c>
f01004b4:	bb 00 32 00 00       	mov    $0x3200,%ebx
f01004b9:	b9 84 00 00 00       	mov    $0x84,%ecx
f01004be:	be 79 03 00 00       	mov    $0x379,%esi
f01004c3:	89 ca                	mov    %ecx,%edx
f01004c5:	ec                   	in     (%dx),%al
f01004c6:	ec                   	in     (%dx),%al
f01004c7:	ec                   	in     (%dx),%al
f01004c8:	ec                   	in     (%dx),%al
f01004c9:	89 f2                	mov    %esi,%edx
f01004cb:	ec                   	in     (%dx),%al
f01004cc:	84 c0                	test   %al,%al
f01004ce:	78 05                	js     f01004d5 <cons_putc+0x6c>
f01004d0:	83 eb 01             	sub    $0x1,%ebx
f01004d3:	75 ee                	jne    f01004c3 <cons_putc+0x5a>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01004d5:	ba 78 03 00 00       	mov    $0x378,%edx
f01004da:	0f b6 45 e4          	movzbl -0x1c(%ebp),%eax
f01004de:	ee                   	out    %al,(%dx)
f01004df:	b2 7a                	mov    $0x7a,%dl
f01004e1:	b8 0d 00 00 00       	mov    $0xd,%eax
f01004e6:	ee                   	out    %al,(%dx)
f01004e7:	b8 08 00 00 00       	mov    $0x8,%eax
f01004ec:	ee                   	out    %al,(%dx)

static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f01004ed:	89 fa                	mov    %edi,%edx
f01004ef:	81 e2 00 ff ff ff    	and    $0xffffff00,%edx
		c |= 0x0700;
f01004f5:	89 f8                	mov    %edi,%eax
f01004f7:	80 cc 07             	or     $0x7,%ah
f01004fa:	85 d2                	test   %edx,%edx
f01004fc:	0f 44 f8             	cmove  %eax,%edi

	switch (c & 0xff) {
f01004ff:	89 f8                	mov    %edi,%eax
f0100501:	0f b6 c0             	movzbl %al,%eax
f0100504:	83 f8 09             	cmp    $0x9,%eax
f0100507:	74 79                	je     f0100582 <cons_putc+0x119>
f0100509:	83 f8 09             	cmp    $0x9,%eax
f010050c:	7f 0a                	jg     f0100518 <cons_putc+0xaf>
f010050e:	83 f8 08             	cmp    $0x8,%eax
f0100511:	74 19                	je     f010052c <cons_putc+0xc3>
f0100513:	e9 9e 00 00 00       	jmp    f01005b6 <cons_putc+0x14d>
f0100518:	83 f8 0a             	cmp    $0xa,%eax
f010051b:	90                   	nop
f010051c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100520:	74 3a                	je     f010055c <cons_putc+0xf3>
f0100522:	83 f8 0d             	cmp    $0xd,%eax
f0100525:	74 3d                	je     f0100564 <cons_putc+0xfb>
f0100527:	e9 8a 00 00 00       	jmp    f01005b6 <cons_putc+0x14d>
	case '\b':
		if (crt_pos > 0) {
f010052c:	0f b7 05 28 32 22 f0 	movzwl 0xf0223228,%eax
f0100533:	66 85 c0             	test   %ax,%ax
f0100536:	0f 84 e5 00 00 00    	je     f0100621 <cons_putc+0x1b8>
			crt_pos--;
f010053c:	83 e8 01             	sub    $0x1,%eax
f010053f:	66 a3 28 32 22 f0    	mov    %ax,0xf0223228
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100545:	0f b7 c0             	movzwl %ax,%eax
f0100548:	66 81 e7 00 ff       	and    $0xff00,%di
f010054d:	83 cf 20             	or     $0x20,%edi
f0100550:	8b 15 2c 32 22 f0    	mov    0xf022322c,%edx
f0100556:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f010055a:	eb 78                	jmp    f01005d4 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f010055c:	66 83 05 28 32 22 f0 	addw   $0x50,0xf0223228
f0100563:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f0100564:	0f b7 05 28 32 22 f0 	movzwl 0xf0223228,%eax
f010056b:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100571:	c1 e8 16             	shr    $0x16,%eax
f0100574:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0100577:	c1 e0 04             	shl    $0x4,%eax
f010057a:	66 a3 28 32 22 f0    	mov    %ax,0xf0223228
f0100580:	eb 52                	jmp    f01005d4 <cons_putc+0x16b>
		break;
	case '\t':
		cons_putc(' ');
f0100582:	b8 20 00 00 00       	mov    $0x20,%eax
f0100587:	e8 dd fe ff ff       	call   f0100469 <cons_putc>
		cons_putc(' ');
f010058c:	b8 20 00 00 00       	mov    $0x20,%eax
f0100591:	e8 d3 fe ff ff       	call   f0100469 <cons_putc>
		cons_putc(' ');
f0100596:	b8 20 00 00 00       	mov    $0x20,%eax
f010059b:	e8 c9 fe ff ff       	call   f0100469 <cons_putc>
		cons_putc(' ');
f01005a0:	b8 20 00 00 00       	mov    $0x20,%eax
f01005a5:	e8 bf fe ff ff       	call   f0100469 <cons_putc>
		cons_putc(' ');
f01005aa:	b8 20 00 00 00       	mov    $0x20,%eax
f01005af:	e8 b5 fe ff ff       	call   f0100469 <cons_putc>
f01005b4:	eb 1e                	jmp    f01005d4 <cons_putc+0x16b>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f01005b6:	0f b7 05 28 32 22 f0 	movzwl 0xf0223228,%eax
f01005bd:	8d 50 01             	lea    0x1(%eax),%edx
f01005c0:	66 89 15 28 32 22 f0 	mov    %dx,0xf0223228
f01005c7:	0f b7 c0             	movzwl %ax,%eax
f01005ca:	8b 15 2c 32 22 f0    	mov    0xf022322c,%edx
f01005d0:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f01005d4:	66 81 3d 28 32 22 f0 	cmpw   $0x7cf,0xf0223228
f01005db:	cf 07 
f01005dd:	76 42                	jbe    f0100621 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f01005df:	a1 2c 32 22 f0       	mov    0xf022322c,%eax
f01005e4:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f01005eb:	00 
f01005ec:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f01005f2:	89 54 24 04          	mov    %edx,0x4(%esp)
f01005f6:	89 04 24             	mov    %eax,(%esp)
f01005f9:	e8 e8 50 00 00       	call   f01056e6 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f01005fe:	8b 15 2c 32 22 f0    	mov    0xf022322c,%edx
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f0100604:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f0100609:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f010060f:	83 c0 01             	add    $0x1,%eax
f0100612:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f0100617:	75 f0                	jne    f0100609 <cons_putc+0x1a0>
			crt_buf[i] = 0x0700 | ' ';
		crt_pos -= CRT_COLS;
f0100619:	66 83 2d 28 32 22 f0 	subw   $0x50,0xf0223228
f0100620:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100621:	8b 0d 30 32 22 f0    	mov    0xf0223230,%ecx
f0100627:	b8 0e 00 00 00       	mov    $0xe,%eax
f010062c:	89 ca                	mov    %ecx,%edx
f010062e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010062f:	0f b7 1d 28 32 22 f0 	movzwl 0xf0223228,%ebx
f0100636:	8d 71 01             	lea    0x1(%ecx),%esi
f0100639:	89 d8                	mov    %ebx,%eax
f010063b:	66 c1 e8 08          	shr    $0x8,%ax
f010063f:	89 f2                	mov    %esi,%edx
f0100641:	ee                   	out    %al,(%dx)
f0100642:	b8 0f 00 00 00       	mov    $0xf,%eax
f0100647:	89 ca                	mov    %ecx,%edx
f0100649:	ee                   	out    %al,(%dx)
f010064a:	89 d8                	mov    %ebx,%eax
f010064c:	89 f2                	mov    %esi,%edx
f010064e:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f010064f:	83 c4 1c             	add    $0x1c,%esp
f0100652:	5b                   	pop    %ebx
f0100653:	5e                   	pop    %esi
f0100654:	5f                   	pop    %edi
f0100655:	5d                   	pop    %ebp
f0100656:	c3                   	ret    

f0100657 <serial_intr>:
}

void
serial_intr(void)
{
	if (serial_exists)
f0100657:	83 3d 34 32 22 f0 00 	cmpl   $0x0,0xf0223234
f010065e:	74 11                	je     f0100671 <serial_intr+0x1a>
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f0100660:	55                   	push   %ebp
f0100661:	89 e5                	mov    %esp,%ebp
f0100663:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
		cons_intr(serial_proc_data);
f0100666:	b8 00 03 10 f0       	mov    $0xf0100300,%eax
f010066b:	e8 ac fc ff ff       	call   f010031c <cons_intr>
}
f0100670:	c9                   	leave  
f0100671:	f3 c3                	repz ret 

f0100673 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f0100673:	55                   	push   %ebp
f0100674:	89 e5                	mov    %esp,%ebp
f0100676:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f0100679:	b8 60 03 10 f0       	mov    $0xf0100360,%eax
f010067e:	e8 99 fc ff ff       	call   f010031c <cons_intr>
}
f0100683:	c9                   	leave  
f0100684:	c3                   	ret    

f0100685 <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f0100685:	55                   	push   %ebp
f0100686:	89 e5                	mov    %esp,%ebp
f0100688:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f010068b:	e8 c7 ff ff ff       	call   f0100657 <serial_intr>
	kbd_intr();
f0100690:	e8 de ff ff ff       	call   f0100673 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f0100695:	a1 20 32 22 f0       	mov    0xf0223220,%eax
f010069a:	3b 05 24 32 22 f0    	cmp    0xf0223224,%eax
f01006a0:	74 26                	je     f01006c8 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f01006a2:	8d 50 01             	lea    0x1(%eax),%edx
f01006a5:	89 15 20 32 22 f0    	mov    %edx,0xf0223220
f01006ab:	0f b6 88 20 30 22 f0 	movzbl -0xfddcfe0(%eax),%ecx
		if (cons.rpos == CONSBUFSIZE)
			cons.rpos = 0;
		return c;
f01006b2:	89 c8                	mov    %ecx,%eax
	kbd_intr();

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
		c = cons.buf[cons.rpos++];
		if (cons.rpos == CONSBUFSIZE)
f01006b4:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f01006ba:	75 11                	jne    f01006cd <cons_getc+0x48>
			cons.rpos = 0;
f01006bc:	c7 05 20 32 22 f0 00 	movl   $0x0,0xf0223220
f01006c3:	00 00 00 
f01006c6:	eb 05                	jmp    f01006cd <cons_getc+0x48>
		return c;
	}
	return 0;
f01006c8:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01006cd:	c9                   	leave  
f01006ce:	c3                   	ret    

f01006cf <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f01006cf:	55                   	push   %ebp
f01006d0:	89 e5                	mov    %esp,%ebp
f01006d2:	57                   	push   %edi
f01006d3:	56                   	push   %esi
f01006d4:	53                   	push   %ebx
f01006d5:	83 ec 1c             	sub    $0x1c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f01006d8:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f01006df:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f01006e6:	5a a5 
	if (*cp != 0xA55A) {
f01006e8:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f01006ef:	66 3d 5a a5          	cmp    $0xa55a,%ax
f01006f3:	74 11                	je     f0100706 <cons_init+0x37>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f01006f5:	c7 05 30 32 22 f0 b4 	movl   $0x3b4,0xf0223230
f01006fc:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f01006ff:	bf 00 00 0b f0       	mov    $0xf00b0000,%edi
f0100704:	eb 16                	jmp    f010071c <cons_init+0x4d>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f0100706:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f010070d:	c7 05 30 32 22 f0 d4 	movl   $0x3d4,0xf0223230
f0100714:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f0100717:	bf 00 80 0b f0       	mov    $0xf00b8000,%edi
		*cp = was;
		addr_6845 = CGA_BASE;
	}
	
	/* Extract cursor location */
	outb(addr_6845, 14);
f010071c:	8b 0d 30 32 22 f0    	mov    0xf0223230,%ecx
f0100722:	b8 0e 00 00 00       	mov    $0xe,%eax
f0100727:	89 ca                	mov    %ecx,%edx
f0100729:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f010072a:	8d 59 01             	lea    0x1(%ecx),%ebx

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010072d:	89 da                	mov    %ebx,%edx
f010072f:	ec                   	in     (%dx),%al
f0100730:	0f b6 f0             	movzbl %al,%esi
f0100733:	c1 e6 08             	shl    $0x8,%esi
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100736:	b8 0f 00 00 00       	mov    $0xf,%eax
f010073b:	89 ca                	mov    %ecx,%edx
f010073d:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010073e:	89 da                	mov    %ebx,%edx
f0100740:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f0100741:	89 3d 2c 32 22 f0    	mov    %edi,0xf022322c
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f0100747:	0f b6 d8             	movzbl %al,%ebx
f010074a:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f010074c:	66 89 35 28 32 22 f0 	mov    %si,0xf0223228

static void
kbd_init(void)
{
	// Drain the kbd buffer so that Bochs generates interrupts.
	kbd_intr();
f0100753:	e8 1b ff ff ff       	call   f0100673 <kbd_intr>
	irq_setmask_8259A(irq_mask_8259A & ~(1<<1));
f0100758:	0f b7 05 88 03 12 f0 	movzwl 0xf0120388,%eax
f010075f:	25 fd ff 00 00       	and    $0xfffd,%eax
f0100764:	89 04 24             	mov    %eax,(%esp)
f0100767:	e8 30 36 00 00       	call   f0103d9c <irq_setmask_8259A>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010076c:	be fa 03 00 00       	mov    $0x3fa,%esi
f0100771:	b8 00 00 00 00       	mov    $0x0,%eax
f0100776:	89 f2                	mov    %esi,%edx
f0100778:	ee                   	out    %al,(%dx)
f0100779:	b2 fb                	mov    $0xfb,%dl
f010077b:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f0100780:	ee                   	out    %al,(%dx)
f0100781:	bb f8 03 00 00       	mov    $0x3f8,%ebx
f0100786:	b8 0c 00 00 00       	mov    $0xc,%eax
f010078b:	89 da                	mov    %ebx,%edx
f010078d:	ee                   	out    %al,(%dx)
f010078e:	b2 f9                	mov    $0xf9,%dl
f0100790:	b8 00 00 00 00       	mov    $0x0,%eax
f0100795:	ee                   	out    %al,(%dx)
f0100796:	b2 fb                	mov    $0xfb,%dl
f0100798:	b8 03 00 00 00       	mov    $0x3,%eax
f010079d:	ee                   	out    %al,(%dx)
f010079e:	b2 fc                	mov    $0xfc,%dl
f01007a0:	b8 00 00 00 00       	mov    $0x0,%eax
f01007a5:	ee                   	out    %al,(%dx)
f01007a6:	b2 f9                	mov    $0xf9,%dl
f01007a8:	b8 01 00 00 00       	mov    $0x1,%eax
f01007ad:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01007ae:	b2 fd                	mov    $0xfd,%dl
f01007b0:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f01007b1:	3c ff                	cmp    $0xff,%al
f01007b3:	0f 95 c1             	setne  %cl
f01007b6:	0f b6 c9             	movzbl %cl,%ecx
f01007b9:	89 0d 34 32 22 f0    	mov    %ecx,0xf0223234
f01007bf:	89 f2                	mov    %esi,%edx
f01007c1:	ec                   	in     (%dx),%al
f01007c2:	89 da                	mov    %ebx,%edx
f01007c4:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f01007c5:	85 c9                	test   %ecx,%ecx
f01007c7:	75 0c                	jne    f01007d5 <cons_init+0x106>
		cprintf("Serial port does not exist!\n");
f01007c9:	c7 04 24 0f 65 10 f0 	movl   $0xf010650f,(%esp)
f01007d0:	e8 09 37 00 00       	call   f0103ede <cprintf>
}
f01007d5:	83 c4 1c             	add    $0x1c,%esp
f01007d8:	5b                   	pop    %ebx
f01007d9:	5e                   	pop    %esi
f01007da:	5f                   	pop    %edi
f01007db:	5d                   	pop    %ebp
f01007dc:	c3                   	ret    

f01007dd <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f01007dd:	55                   	push   %ebp
f01007de:	89 e5                	mov    %esp,%ebp
f01007e0:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f01007e3:	8b 45 08             	mov    0x8(%ebp),%eax
f01007e6:	e8 7e fc ff ff       	call   f0100469 <cons_putc>
}
f01007eb:	c9                   	leave  
f01007ec:	c3                   	ret    

f01007ed <getchar>:

int
getchar(void)
{
f01007ed:	55                   	push   %ebp
f01007ee:	89 e5                	mov    %esp,%ebp
f01007f0:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f01007f3:	e8 8d fe ff ff       	call   f0100685 <cons_getc>
f01007f8:	85 c0                	test   %eax,%eax
f01007fa:	74 f7                	je     f01007f3 <getchar+0x6>
		/* do nothing */;
	return c;
}
f01007fc:	c9                   	leave  
f01007fd:	c3                   	ret    

f01007fe <iscons>:

int
iscons(int fdnum)
{
f01007fe:	55                   	push   %ebp
f01007ff:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f0100801:	b8 01 00 00 00       	mov    $0x1,%eax
f0100806:	5d                   	pop    %ebp
f0100807:	c3                   	ret    
f0100808:	66 90                	xchg   %ax,%ax
f010080a:	66 90                	xchg   %ax,%ax
f010080c:	66 90                	xchg   %ax,%ax
f010080e:	66 90                	xchg   %ax,%ax

f0100810 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100810:	55                   	push   %ebp
f0100811:	89 e5                	mov    %esp,%ebp
f0100813:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < NCOMMANDS; i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100816:	c7 44 24 08 60 67 10 	movl   $0xf0106760,0x8(%esp)
f010081d:	f0 
f010081e:	c7 44 24 04 7e 67 10 	movl   $0xf010677e,0x4(%esp)
f0100825:	f0 
f0100826:	c7 04 24 83 67 10 f0 	movl   $0xf0106783,(%esp)
f010082d:	e8 ac 36 00 00       	call   f0103ede <cprintf>
f0100832:	c7 44 24 08 20 68 10 	movl   $0xf0106820,0x8(%esp)
f0100839:	f0 
f010083a:	c7 44 24 04 8c 67 10 	movl   $0xf010678c,0x4(%esp)
f0100841:	f0 
f0100842:	c7 04 24 83 67 10 f0 	movl   $0xf0106783,(%esp)
f0100849:	e8 90 36 00 00       	call   f0103ede <cprintf>
f010084e:	c7 44 24 08 48 68 10 	movl   $0xf0106848,0x8(%esp)
f0100855:	f0 
f0100856:	c7 44 24 04 95 67 10 	movl   $0xf0106795,0x4(%esp)
f010085d:	f0 
f010085e:	c7 04 24 83 67 10 f0 	movl   $0xf0106783,(%esp)
f0100865:	e8 74 36 00 00       	call   f0103ede <cprintf>
	return 0;
}
f010086a:	b8 00 00 00 00       	mov    $0x0,%eax
f010086f:	c9                   	leave  
f0100870:	c3                   	ret    

f0100871 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f0100871:	55                   	push   %ebp
f0100872:	89 e5                	mov    %esp,%ebp
f0100874:	83 ec 18             	sub    $0x18,%esp
	extern char entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f0100877:	c7 04 24 9f 67 10 f0 	movl   $0xf010679f,(%esp)
f010087e:	e8 5b 36 00 00       	call   f0103ede <cprintf>
	cprintf(" this is work 1 insert:\n");
f0100883:	c7 04 24 b8 67 10 f0 	movl   $0xf01067b8,(%esp)
f010088a:	e8 4f 36 00 00       	call   f0103ede <cprintf>
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
f010088f:	c7 44 24 08 0f 00 00 	movl   $0xf,0x8(%esp)
f0100896:	00 
f0100897:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
f010089e:	00 
f010089f:	c7 04 24 74 68 10 f0 	movl   $0xf0106874,(%esp)
f01008a6:	e8 33 36 00 00       	call   f0103ede <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
f01008ab:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f01008b2:	00 
f01008b3:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f01008ba:	f0 
f01008bb:	c7 04 24 ac 68 10 f0 	movl   $0xf01068ac,(%esp)
f01008c2:	e8 17 36 00 00       	call   f0103ede <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01008c7:	c7 44 24 08 27 64 10 	movl   $0x106427,0x8(%esp)
f01008ce:	00 
f01008cf:	c7 44 24 04 27 64 10 	movl   $0xf0106427,0x4(%esp)
f01008d6:	f0 
f01008d7:	c7 04 24 d4 68 10 f0 	movl   $0xf01068d4,(%esp)
f01008de:	e8 fb 35 00 00       	call   f0103ede <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01008e3:	c7 44 24 08 58 24 22 	movl   $0x222458,0x8(%esp)
f01008ea:	00 
f01008eb:	c7 44 24 04 58 24 22 	movl   $0xf0222458,0x4(%esp)
f01008f2:	f0 
f01008f3:	c7 04 24 f8 68 10 f0 	movl   $0xf01068f8,(%esp)
f01008fa:	e8 df 35 00 00       	call   f0103ede <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f01008ff:	c7 44 24 08 04 50 26 	movl   $0x265004,0x8(%esp)
f0100906:	00 
f0100907:	c7 44 24 04 04 50 26 	movl   $0xf0265004,0x4(%esp)
f010090e:	f0 
f010090f:	c7 04 24 1c 69 10 f0 	movl   $0xf010691c,(%esp)
f0100916:	e8 c3 35 00 00       	call   f0103ede <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f010091b:	b8 03 54 26 f0       	mov    $0xf0265403,%eax
f0100920:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f0100925:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f010092b:	85 c0                	test   %eax,%eax
f010092d:	0f 48 c2             	cmovs  %edx,%eax
f0100930:	c1 f8 0a             	sar    $0xa,%eax
f0100933:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100937:	c7 04 24 40 69 10 f0 	movl   $0xf0106940,(%esp)
f010093e:	e8 9b 35 00 00       	call   f0103ede <cprintf>
		(end-entry+1023)/1024);
	return 0;
}
f0100943:	b8 00 00 00 00       	mov    $0x0,%eax
f0100948:	c9                   	leave  
f0100949:	c3                   	ret    

f010094a <mon_backtrace>:
int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f010094a:	55                   	push   %ebp
f010094b:	89 e5                	mov    %esp,%ebp
f010094d:	56                   	push   %esi
f010094e:	53                   	push   %ebx
f010094f:	83 ec 40             	sub    $0x40,%esp
	// Your code here
	cprintf("start backtrace\n");
f0100952:	c7 04 24 d1 67 10 f0 	movl   $0xf01067d1,(%esp)
f0100959:	e8 80 35 00 00       	call   f0103ede <cprintf>
	cprintf("\n");
f010095e:	c7 04 24 ff 74 10 f0 	movl   $0xf01074ff,(%esp)
f0100965:	e8 74 35 00 00       	call   f0103ede <cprintf>

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f010096a:	89 e8                	mov    %ebp,%eax
f010096c:	89 c1                	mov    %eax,%ecx
	uint32_t eip;
	uint32_t ebp = read_ebp();
	uint32_t esp;
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
f010096e:	83 f8 ff             	cmp    $0xffffffff,%eax
f0100971:	74 63                	je     f01009d6 <mon_backtrace+0x8c>
		esp = ebp+8;
		eip = *(uint32_t*)(ebp+4);
f0100973:	8b 71 04             	mov    0x4(%ecx),%esi
		if(ebp==0){
			ebp = -1;
f0100976:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
		esp = ebp+8;
		eip = *(uint32_t*)(ebp+4);
		if(ebp==0){
f010097b:	85 c9                	test   %ecx,%ecx
f010097d:	74 02                	je     f0100981 <mon_backtrace+0x37>
			ebp = -1;
		}else{
			ebp = *(uint32_t*)(ebp);
f010097f:	8b 19                	mov    (%ecx),%ebx
		}
		for(i=0;i<5;i++){
f0100981:	b8 00 00 00 00       	mov    $0x0,%eax
		args[i] = *(uint32_t*)(esp+i*4);
f0100986:	8b 54 81 08          	mov    0x8(%ecx,%eax,4),%edx
f010098a:	89 54 85 e4          	mov    %edx,-0x1c(%ebp,%eax,4)
		if(ebp==0){
			ebp = -1;
		}else{
			ebp = *(uint32_t*)(ebp);
		}
		for(i=0;i<5;i++){
f010098e:	83 c0 01             	add    $0x1,%eax
f0100991:	83 f8 05             	cmp    $0x5,%eax
f0100994:	75 f0                	jne    f0100986 <mon_backtrace+0x3c>
		args[i] = *(uint32_t*)(esp+i*4);
	        }
                            cprintf("ebp  %08x   eip %08x   args  %08x  %08x  %08x  %08x  %08x\n",ebp,eip,args[0],args[1],args[2],args[3],args[4]);
f0100996:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0100999:	89 44 24 1c          	mov    %eax,0x1c(%esp)
f010099d:	8b 45 f0             	mov    -0x10(%ebp),%eax
f01009a0:	89 44 24 18          	mov    %eax,0x18(%esp)
f01009a4:	8b 45 ec             	mov    -0x14(%ebp),%eax
f01009a7:	89 44 24 14          	mov    %eax,0x14(%esp)
f01009ab:	8b 45 e8             	mov    -0x18(%ebp),%eax
f01009ae:	89 44 24 10          	mov    %eax,0x10(%esp)
f01009b2:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01009b5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01009b9:	89 74 24 08          	mov    %esi,0x8(%esp)
f01009bd:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01009c1:	c7 04 24 6c 69 10 f0 	movl   $0xf010696c,(%esp)
f01009c8:	e8 11 35 00 00       	call   f0103ede <cprintf>
	uint32_t eip;
	uint32_t ebp = read_ebp();
	uint32_t esp;
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
f01009cd:	83 fb ff             	cmp    $0xffffffff,%ebx
f01009d0:	74 04                	je     f01009d6 <mon_backtrace+0x8c>
f01009d2:	89 d9                	mov    %ebx,%ecx
f01009d4:	eb 9d                	jmp    f0100973 <mon_backtrace+0x29>
                            cprintf("ebp  %08x   eip %08x   args  %08x  %08x  %08x  %08x  %08x\n",ebp,eip,args[0],args[1],args[2],args[3],args[4]);

	}
	
	return 0;
}
f01009d6:	b8 00 00 00 00       	mov    $0x0,%eax
f01009db:	83 c4 40             	add    $0x40,%esp
f01009de:	5b                   	pop    %ebx
f01009df:	5e                   	pop    %esi
f01009e0:	5d                   	pop    %ebp
f01009e1:	c3                   	ret    

f01009e2 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f01009e2:	55                   	push   %ebp
f01009e3:	89 e5                	mov    %esp,%ebp
f01009e5:	57                   	push   %edi
f01009e6:	56                   	push   %esi
f01009e7:	53                   	push   %ebx
f01009e8:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f01009eb:	c7 04 24 a8 69 10 f0 	movl   $0xf01069a8,(%esp)
f01009f2:	e8 e7 34 00 00       	call   f0103ede <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f01009f7:	c7 04 24 cc 69 10 f0 	movl   $0xf01069cc,(%esp)
f01009fe:	e8 db 34 00 00       	call   f0103ede <cprintf>

	if (tf != NULL)
f0100a03:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f0100a07:	74 0b                	je     f0100a14 <monitor+0x32>
		print_trapframe(tf);
f0100a09:	8b 45 08             	mov    0x8(%ebp),%eax
f0100a0c:	89 04 24             	mov    %eax,(%esp)
f0100a0f:	e8 2f 39 00 00       	call   f0104343 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f0100a14:	c7 04 24 e2 67 10 f0 	movl   $0xf01067e2,(%esp)
f0100a1b:	e8 a0 49 00 00       	call   f01053c0 <readline>
f0100a20:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f0100a22:	85 c0                	test   %eax,%eax
f0100a24:	74 ee                	je     f0100a14 <monitor+0x32>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f0100a26:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f0100a2d:	be 00 00 00 00       	mov    $0x0,%esi
f0100a32:	eb 0a                	jmp    f0100a3e <monitor+0x5c>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f0100a34:	c6 03 00             	movb   $0x0,(%ebx)
f0100a37:	89 f7                	mov    %esi,%edi
f0100a39:	8d 5b 01             	lea    0x1(%ebx),%ebx
f0100a3c:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f0100a3e:	0f b6 03             	movzbl (%ebx),%eax
f0100a41:	84 c0                	test   %al,%al
f0100a43:	74 6a                	je     f0100aaf <monitor+0xcd>
f0100a45:	0f be c0             	movsbl %al,%eax
f0100a48:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a4c:	c7 04 24 e6 67 10 f0 	movl   $0xf01067e6,(%esp)
f0100a53:	e8 e1 4b 00 00       	call   f0105639 <strchr>
f0100a58:	85 c0                	test   %eax,%eax
f0100a5a:	75 d8                	jne    f0100a34 <monitor+0x52>
			*buf++ = 0;
		if (*buf == 0)
f0100a5c:	80 3b 00             	cmpb   $0x0,(%ebx)
f0100a5f:	74 4e                	je     f0100aaf <monitor+0xcd>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f0100a61:	83 fe 0f             	cmp    $0xf,%esi
f0100a64:	75 16                	jne    f0100a7c <monitor+0x9a>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f0100a66:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f0100a6d:	00 
f0100a6e:	c7 04 24 eb 67 10 f0 	movl   $0xf01067eb,(%esp)
f0100a75:	e8 64 34 00 00       	call   f0103ede <cprintf>
f0100a7a:	eb 98                	jmp    f0100a14 <monitor+0x32>
			return 0;
		}
		argv[argc++] = buf;
f0100a7c:	8d 7e 01             	lea    0x1(%esi),%edi
f0100a7f:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f0100a83:	0f b6 03             	movzbl (%ebx),%eax
f0100a86:	84 c0                	test   %al,%al
f0100a88:	75 0c                	jne    f0100a96 <monitor+0xb4>
f0100a8a:	eb b0                	jmp    f0100a3c <monitor+0x5a>
			buf++;
f0100a8c:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f0100a8f:	0f b6 03             	movzbl (%ebx),%eax
f0100a92:	84 c0                	test   %al,%al
f0100a94:	74 a6                	je     f0100a3c <monitor+0x5a>
f0100a96:	0f be c0             	movsbl %al,%eax
f0100a99:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a9d:	c7 04 24 e6 67 10 f0 	movl   $0xf01067e6,(%esp)
f0100aa4:	e8 90 4b 00 00       	call   f0105639 <strchr>
f0100aa9:	85 c0                	test   %eax,%eax
f0100aab:	74 df                	je     f0100a8c <monitor+0xaa>
f0100aad:	eb 8d                	jmp    f0100a3c <monitor+0x5a>
			buf++;
	}
	argv[argc] = 0;
f0100aaf:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f0100ab6:	00 

	// Lookup and invoke the command
	if (argc == 0)
f0100ab7:	85 f6                	test   %esi,%esi
f0100ab9:	0f 84 55 ff ff ff    	je     f0100a14 <monitor+0x32>
f0100abf:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100ac4:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f0100ac7:	8b 04 85 00 6a 10 f0 	mov    -0xfef9600(,%eax,4),%eax
f0100ace:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100ad2:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100ad5:	89 04 24             	mov    %eax,(%esp)
f0100ad8:	e8 d8 4a 00 00       	call   f01055b5 <strcmp>
f0100add:	85 c0                	test   %eax,%eax
f0100adf:	75 24                	jne    f0100b05 <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100ae1:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100ae4:	8b 55 08             	mov    0x8(%ebp),%edx
f0100ae7:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100aeb:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100aee:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100af2:	89 34 24             	mov    %esi,(%esp)
f0100af5:	ff 14 85 08 6a 10 f0 	call   *-0xfef95f8(,%eax,4)
		print_trapframe(tf);

	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f0100afc:	85 c0                	test   %eax,%eax
f0100afe:	78 25                	js     f0100b25 <monitor+0x143>
f0100b00:	e9 0f ff ff ff       	jmp    f0100a14 <monitor+0x32>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
f0100b05:	83 c3 01             	add    $0x1,%ebx
f0100b08:	83 fb 03             	cmp    $0x3,%ebx
f0100b0b:	75 b7                	jne    f0100ac4 <monitor+0xe2>
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f0100b0d:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100b10:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100b14:	c7 04 24 08 68 10 f0 	movl   $0xf0106808,(%esp)
f0100b1b:	e8 be 33 00 00       	call   f0103ede <cprintf>
f0100b20:	e9 ef fe ff ff       	jmp    f0100a14 <monitor+0x32>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f0100b25:	83 c4 5c             	add    $0x5c,%esp
f0100b28:	5b                   	pop    %ebx
f0100b29:	5e                   	pop    %esi
f0100b2a:	5f                   	pop    %edi
f0100b2b:	5d                   	pop    %ebp
f0100b2c:	c3                   	ret    

f0100b2d <read_eip>:
// return EIP of caller.
// does not work if inlined.
// putting at the end of the file seems to prevent inlining.
unsigned
read_eip()
{
f0100b2d:	55                   	push   %ebp
f0100b2e:	89 e5                	mov    %esp,%ebp
	uint32_t callerpc;
	__asm __volatile("movl 4(%%ebp), %0" : "=r" (callerpc));
f0100b30:	8b 45 04             	mov    0x4(%ebp),%eax
	return callerpc;
}
f0100b33:	5d                   	pop    %ebp
f0100b34:	c3                   	ret    
f0100b35:	66 90                	xchg   %ax,%ax
f0100b37:	66 90                	xchg   %ax,%ax
f0100b39:	66 90                	xchg   %ax,%ax
f0100b3b:	66 90                	xchg   %ax,%ax
f0100b3d:	66 90                	xchg   %ax,%ax
f0100b3f:	90                   	nop

f0100b40 <boot_alloc>:
// If we're out of memory, boot_alloc should panic.
// This function may ONLY be used during initialization,
// before the page_free_list list has been set up.
static void *
boot_alloc(uint32_t n)
{
f0100b40:	55                   	push   %ebp
f0100b41:	89 e5                	mov    %esp,%ebp
f0100b43:	53                   	push   %ebx
f0100b44:	83 ec 14             	sub    $0x14,%esp
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f0100b47:	83 3d 38 32 22 f0 00 	cmpl   $0x0,0xf0223238
f0100b4e:	75 36                	jne    f0100b86 <boot_alloc+0x46>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100b50:	ba 03 60 26 f0       	mov    $0xf0266003,%edx
f0100b55:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0100b5b:	89 15 38 32 22 f0    	mov    %edx,0xf0223238
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f0100b61:	85 c0                	test   %eax,%eax
f0100b63:	74 19                	je     f0100b7e <boot_alloc+0x3e>
                      result = nextfree;
f0100b65:	8b 1d 38 32 22 f0    	mov    0xf0223238,%ebx
                      nextfree += ROUNDUP(n, PGSIZE);
f0100b6b:	05 ff 0f 00 00       	add    $0xfff,%eax
f0100b70:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100b75:	01 d8                	add    %ebx,%eax
f0100b77:	a3 38 32 22 f0       	mov    %eax,0xf0223238
f0100b7c:	eb 0e                	jmp    f0100b8c <boot_alloc+0x4c>
               } else if (n == 0)
                      result = nextfree;
f0100b7e:	8b 1d 38 32 22 f0    	mov    0xf0223238,%ebx
f0100b84:	eb 06                	jmp    f0100b8c <boot_alloc+0x4c>
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f0100b86:	85 c0                	test   %eax,%eax
f0100b88:	74 f4                	je     f0100b7e <boot_alloc+0x3e>
f0100b8a:	eb d9                	jmp    f0100b65 <boot_alloc+0x25>
                      nextfree += ROUNDUP(n, PGSIZE);
               } else if (n == 0)
                      result = nextfree;
              else
                      result = NULL;
              cprintf(">>  boot_alloc() was called! Entry(virtual address) of new page is: %x\n\n", (int)result);
f0100b8c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100b90:	c7 04 24 24 6a 10 f0 	movl   $0xf0106a24,(%esp)
f0100b97:	e8 42 33 00 00       	call   f0103ede <cprintf>
              return result;
   
	//return NULL;
}
f0100b9c:	89 d8                	mov    %ebx,%eax
f0100b9e:	83 c4 14             	add    $0x14,%esp
f0100ba1:	5b                   	pop    %ebx
f0100ba2:	5d                   	pop    %ebp
f0100ba3:	c3                   	ret    

f0100ba4 <check_va2pa>:
static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
f0100ba4:	89 d1                	mov    %edx,%ecx
f0100ba6:	c1 e9 16             	shr    $0x16,%ecx
	if (!(*pgdir & PTE_P))
f0100ba9:	8b 04 88             	mov    (%eax,%ecx,4),%eax
f0100bac:	a8 01                	test   $0x1,%al
f0100bae:	74 5d                	je     f0100c0d <check_va2pa+0x69>
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
f0100bb0:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100bb5:	89 c1                	mov    %eax,%ecx
f0100bb7:	c1 e9 0c             	shr    $0xc,%ecx
f0100bba:	3b 0d 88 3e 22 f0    	cmp    0xf0223e88,%ecx
f0100bc0:	72 26                	jb     f0100be8 <check_va2pa+0x44>
// this functionality for us!  We define our own version to help check
// the check_kern_pgdir() function; it shouldn't be used elsewhere.

static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
f0100bc2:	55                   	push   %ebp
f0100bc3:	89 e5                	mov    %esp,%ebp
f0100bc5:	83 ec 18             	sub    $0x18,%esp
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100bc8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100bcc:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f0100bd3:	f0 
f0100bd4:	c7 44 24 04 9f 03 00 	movl   $0x39f,0x4(%esp)
f0100bdb:	00 
f0100bdc:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0100be3:	e8 58 f4 ff ff       	call   f0100040 <_panic>

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
f0100be8:	c1 ea 0c             	shr    $0xc,%edx
f0100beb:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f0100bf1:	8b 84 90 00 00 00 f0 	mov    -0x10000000(%eax,%edx,4),%eax
f0100bf8:	89 c2                	mov    %eax,%edx
f0100bfa:	83 e2 01             	and    $0x1,%edx
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
f0100bfd:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100c02:	85 d2                	test   %edx,%edx
f0100c04:	ba ff ff ff ff       	mov    $0xffffffff,%edx
f0100c09:	0f 44 c2             	cmove  %edx,%eax
f0100c0c:	c3                   	ret    
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
f0100c0d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
}
f0100c12:	c3                   	ret    

f0100c13 <check_page_free_list>:
//
// Check that the pages on the page_free_list are reasonable.
//
static void
check_page_free_list(bool only_low_memory)
{
f0100c13:	55                   	push   %ebp
f0100c14:	89 e5                	mov    %esp,%ebp
f0100c16:	57                   	push   %edi
f0100c17:	56                   	push   %esi
f0100c18:	53                   	push   %ebx
f0100c19:	83 ec 4c             	sub    $0x4c,%esp
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100c1c:	85 c0                	test   %eax,%eax
f0100c1e:	0f 85 6a 03 00 00    	jne    f0100f8e <check_page_free_list+0x37b>
f0100c24:	e9 77 03 00 00       	jmp    f0100fa0 <check_page_free_list+0x38d>
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
		panic("'page_free_list' is a null pointer!");
f0100c29:	c7 44 24 08 70 6a 10 	movl   $0xf0106a70,0x8(%esp)
f0100c30:	f0 
f0100c31:	c7 44 24 04 d1 02 00 	movl   $0x2d1,0x4(%esp)
f0100c38:	00 
f0100c39:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0100c40:	e8 fb f3 ff ff       	call   f0100040 <_panic>

	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
f0100c45:	8d 55 d8             	lea    -0x28(%ebp),%edx
f0100c48:	89 55 e0             	mov    %edx,-0x20(%ebp)
f0100c4b:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100c4e:	89 55 e4             	mov    %edx,-0x1c(%ebp)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100c51:	89 c2                	mov    %eax,%edx
f0100c53:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
		for (pp = page_free_list; pp; pp = pp->pp_link) {
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
f0100c59:	f7 c2 00 e0 7f 00    	test   $0x7fe000,%edx
f0100c5f:	0f 95 c2             	setne  %dl
f0100c62:	0f b6 d2             	movzbl %dl,%edx
			*tp[pagetype] = pp;
f0100c65:	8b 4c 95 e0          	mov    -0x20(%ebp,%edx,4),%ecx
f0100c69:	89 01                	mov    %eax,(%ecx)
			tp[pagetype] = &pp->pp_link;
f0100c6b:	89 44 95 e0          	mov    %eax,-0x20(%ebp,%edx,4)
	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
		for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100c6f:	8b 00                	mov    (%eax),%eax
f0100c71:	85 c0                	test   %eax,%eax
f0100c73:	75 dc                	jne    f0100c51 <check_page_free_list+0x3e>
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
			*tp[pagetype] = pp;
			tp[pagetype] = &pp->pp_link;
		}
		*tp[1] = 0;
f0100c75:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100c78:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		*tp[0] = pp2;
f0100c7e:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100c81:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100c84:	89 10                	mov    %edx,(%eax)
		page_free_list = pp1;
f0100c86:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100c89:	a3 40 32 22 f0       	mov    %eax,0xf0223240
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100c8e:	89 c3                	mov    %eax,%ebx
f0100c90:	85 c0                	test   %eax,%eax
f0100c92:	74 6c                	je     f0100d00 <check_page_free_list+0xed>
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100c94:	be 01 00 00 00       	mov    $0x1,%esi
f0100c99:	89 d8                	mov    %ebx,%eax
f0100c9b:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f0100ca1:	c1 f8 03             	sar    $0x3,%eax
f0100ca4:	c1 e0 0c             	shl    $0xc,%eax
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
f0100ca7:	89 c2                	mov    %eax,%edx
f0100ca9:	c1 ea 16             	shr    $0x16,%edx
f0100cac:	39 f2                	cmp    %esi,%edx
f0100cae:	73 4a                	jae    f0100cfa <check_page_free_list+0xe7>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100cb0:	89 c2                	mov    %eax,%edx
f0100cb2:	c1 ea 0c             	shr    $0xc,%edx
f0100cb5:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f0100cbb:	72 20                	jb     f0100cdd <check_page_free_list+0xca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100cbd:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100cc1:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f0100cc8:	f0 
f0100cc9:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100cd0:	00 
f0100cd1:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f0100cd8:	e8 63 f3 ff ff       	call   f0100040 <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100cdd:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100ce4:	00 
f0100ce5:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100cec:	00 
	return (void *)(pa + KERNBASE);
f0100ced:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100cf2:	89 04 24             	mov    %eax,(%esp)
f0100cf5:	e8 9f 49 00 00       	call   f0105699 <memset>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100cfa:	8b 1b                	mov    (%ebx),%ebx
f0100cfc:	85 db                	test   %ebx,%ebx
f0100cfe:	75 99                	jne    f0100c99 <check_page_free_list+0x86>
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
f0100d00:	b8 00 00 00 00       	mov    $0x0,%eax
f0100d05:	e8 36 fe ff ff       	call   f0100b40 <boot_alloc>
f0100d0a:	89 45 c8             	mov    %eax,-0x38(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100d0d:	8b 15 40 32 22 f0    	mov    0xf0223240,%edx
f0100d13:	85 d2                	test   %edx,%edx
f0100d15:	0f 84 27 02 00 00    	je     f0100f42 <check_page_free_list+0x32f>
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d1b:	8b 3d 90 3e 22 f0    	mov    0xf0223e90,%edi
f0100d21:	39 fa                	cmp    %edi,%edx
f0100d23:	72 3f                	jb     f0100d64 <check_page_free_list+0x151>
		assert(pp < pages + npages);
f0100d25:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f0100d2a:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0100d2d:	8d 04 c7             	lea    (%edi,%eax,8),%eax
f0100d30:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100d33:	39 c2                	cmp    %eax,%edx
f0100d35:	73 56                	jae    f0100d8d <check_page_free_list+0x17a>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100d37:	89 7d d0             	mov    %edi,-0x30(%ebp)
f0100d3a:	89 d0                	mov    %edx,%eax
f0100d3c:	29 f8                	sub    %edi,%eax
f0100d3e:	a8 07                	test   $0x7,%al
f0100d40:	75 78                	jne    f0100dba <check_page_free_list+0x1a7>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100d42:	c1 f8 03             	sar    $0x3,%eax
f0100d45:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100d48:	85 c0                	test   %eax,%eax
f0100d4a:	0f 84 98 00 00 00    	je     f0100de8 <check_page_free_list+0x1d5>
		assert(page2pa(pp) != IOPHYSMEM);
f0100d50:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100d55:	0f 85 dc 00 00 00    	jne    f0100e37 <check_page_free_list+0x224>
f0100d5b:	e9 b3 00 00 00       	jmp    f0100e13 <check_page_free_list+0x200>
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d60:	39 d7                	cmp    %edx,%edi
f0100d62:	76 24                	jbe    f0100d88 <check_page_free_list+0x175>
f0100d64:	c7 44 24 0c 87 71 10 	movl   $0xf0107187,0xc(%esp)
f0100d6b:	f0 
f0100d6c:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0100d73:	f0 
f0100d74:	c7 44 24 04 eb 02 00 	movl   $0x2eb,0x4(%esp)
f0100d7b:	00 
f0100d7c:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0100d83:	e8 b8 f2 ff ff       	call   f0100040 <_panic>
		assert(pp < pages + npages);
f0100d88:	3b 55 d4             	cmp    -0x2c(%ebp),%edx
f0100d8b:	72 24                	jb     f0100db1 <check_page_free_list+0x19e>
f0100d8d:	c7 44 24 0c a8 71 10 	movl   $0xf01071a8,0xc(%esp)
f0100d94:	f0 
f0100d95:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0100d9c:	f0 
f0100d9d:	c7 44 24 04 ec 02 00 	movl   $0x2ec,0x4(%esp)
f0100da4:	00 
f0100da5:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0100dac:	e8 8f f2 ff ff       	call   f0100040 <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100db1:	89 d0                	mov    %edx,%eax
f0100db3:	2b 45 d0             	sub    -0x30(%ebp),%eax
f0100db6:	a8 07                	test   $0x7,%al
f0100db8:	74 24                	je     f0100dde <check_page_free_list+0x1cb>
f0100dba:	c7 44 24 0c 94 6a 10 	movl   $0xf0106a94,0xc(%esp)
f0100dc1:	f0 
f0100dc2:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0100dc9:	f0 
f0100dca:	c7 44 24 04 ed 02 00 	movl   $0x2ed,0x4(%esp)
f0100dd1:	00 
f0100dd2:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0100dd9:	e8 62 f2 ff ff       	call   f0100040 <_panic>
f0100dde:	c1 f8 03             	sar    $0x3,%eax
f0100de1:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100de4:	85 c0                	test   %eax,%eax
f0100de6:	75 24                	jne    f0100e0c <check_page_free_list+0x1f9>
f0100de8:	c7 44 24 0c bc 71 10 	movl   $0xf01071bc,0xc(%esp)
f0100def:	f0 
f0100df0:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0100df7:	f0 
f0100df8:	c7 44 24 04 f0 02 00 	movl   $0x2f0,0x4(%esp)
f0100dff:	00 
f0100e00:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0100e07:	e8 34 f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100e0c:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100e11:	75 31                	jne    f0100e44 <check_page_free_list+0x231>
f0100e13:	c7 44 24 0c cd 71 10 	movl   $0xf01071cd,0xc(%esp)
f0100e1a:	f0 
f0100e1b:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0100e22:	f0 
f0100e23:	c7 44 24 04 f1 02 00 	movl   $0x2f1,0x4(%esp)
f0100e2a:	00 
f0100e2b:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0100e32:	e8 09 f2 ff ff       	call   f0100040 <_panic>
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
f0100e37:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100e3c:	be 00 00 00 00       	mov    $0x0,%esi
f0100e41:	89 5d cc             	mov    %ebx,-0x34(%ebp)
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
f0100e44:	3d 00 f0 0f 00       	cmp    $0xff000,%eax
f0100e49:	75 24                	jne    f0100e6f <check_page_free_list+0x25c>
f0100e4b:	c7 44 24 0c c8 6a 10 	movl   $0xf0106ac8,0xc(%esp)
f0100e52:	f0 
f0100e53:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0100e5a:	f0 
f0100e5b:	c7 44 24 04 f2 02 00 	movl   $0x2f2,0x4(%esp)
f0100e62:	00 
f0100e63:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0100e6a:	e8 d1 f1 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100e6f:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100e74:	75 24                	jne    f0100e9a <check_page_free_list+0x287>
f0100e76:	c7 44 24 0c e6 71 10 	movl   $0xf01071e6,0xc(%esp)
f0100e7d:	f0 
f0100e7e:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0100e85:	f0 
f0100e86:	c7 44 24 04 f3 02 00 	movl   $0x2f3,0x4(%esp)
f0100e8d:	00 
f0100e8e:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0100e95:	e8 a6 f1 ff ff       	call   f0100040 <_panic>
f0100e9a:	89 c1                	mov    %eax,%ecx
		//assert((char *) page2kva(pp) >= first_free_page );
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
f0100e9c:	3d ff ff 0f 00       	cmp    $0xfffff,%eax
f0100ea1:	0f 86 07 01 00 00    	jbe    f0100fae <check_page_free_list+0x39b>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100ea7:	89 c3                	mov    %eax,%ebx
f0100ea9:	c1 eb 0c             	shr    $0xc,%ebx
f0100eac:	39 5d c4             	cmp    %ebx,-0x3c(%ebp)
f0100eaf:	77 20                	ja     f0100ed1 <check_page_free_list+0x2be>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100eb1:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100eb5:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f0100ebc:	f0 
f0100ebd:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100ec4:	00 
f0100ec5:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f0100ecc:	e8 6f f1 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0100ed1:	81 e9 00 00 00 10    	sub    $0x10000000,%ecx
f0100ed7:	39 4d c8             	cmp    %ecx,-0x38(%ebp)
f0100eda:	0f 86 de 00 00 00    	jbe    f0100fbe <check_page_free_list+0x3ab>
f0100ee0:	c7 44 24 0c ec 6a 10 	movl   $0xf0106aec,0xc(%esp)
f0100ee7:	f0 
f0100ee8:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0100eef:	f0 
f0100ef0:	c7 44 24 04 f5 02 00 	movl   $0x2f5,0x4(%esp)
f0100ef7:	00 
f0100ef8:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0100eff:	e8 3c f1 ff ff       	call   f0100040 <_panic>
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100f04:	c7 44 24 0c 00 72 10 	movl   $0xf0107200,0xc(%esp)
f0100f0b:	f0 
f0100f0c:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0100f13:	f0 
f0100f14:	c7 44 24 04 f7 02 00 	movl   $0x2f7,0x4(%esp)
f0100f1b:	00 
f0100f1c:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0100f23:	e8 18 f1 ff ff       	call   f0100040 <_panic>

		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
f0100f28:	83 c6 01             	add    $0x1,%esi
f0100f2b:	eb 04                	jmp    f0100f31 <check_page_free_list+0x31e>
		else
			++nfree_extmem;
f0100f2d:	83 45 cc 01          	addl   $0x1,-0x34(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100f31:	8b 12                	mov    (%edx),%edx
f0100f33:	85 d2                	test   %edx,%edx
f0100f35:	0f 85 25 fe ff ff    	jne    f0100d60 <check_page_free_list+0x14d>
f0100f3b:	8b 5d cc             	mov    -0x34(%ebp),%ebx
		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
		else
			++nfree_extmem;
	}
	assert(nfree_basemem > 0);
f0100f3e:	85 f6                	test   %esi,%esi
f0100f40:	7f 24                	jg     f0100f66 <check_page_free_list+0x353>
f0100f42:	c7 44 24 0c 1d 72 10 	movl   $0xf010721d,0xc(%esp)
f0100f49:	f0 
f0100f4a:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0100f51:	f0 
f0100f52:	c7 44 24 04 fe 02 00 	movl   $0x2fe,0x4(%esp)
f0100f59:	00 
f0100f5a:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0100f61:	e8 da f0 ff ff       	call   f0100040 <_panic>
	assert(nfree_extmem > 0);
f0100f66:	85 db                	test   %ebx,%ebx
f0100f68:	7f 74                	jg     f0100fde <check_page_free_list+0x3cb>
f0100f6a:	c7 44 24 0c 2f 72 10 	movl   $0xf010722f,0xc(%esp)
f0100f71:	f0 
f0100f72:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0100f79:	f0 
f0100f7a:	c7 44 24 04 ff 02 00 	movl   $0x2ff,0x4(%esp)
f0100f81:	00 
f0100f82:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0100f89:	e8 b2 f0 ff ff       	call   f0100040 <_panic>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100f8e:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0100f93:	85 c0                	test   %eax,%eax
f0100f95:	0f 85 aa fc ff ff    	jne    f0100c45 <check_page_free_list+0x32>
f0100f9b:	e9 89 fc ff ff       	jmp    f0100c29 <check_page_free_list+0x16>
f0100fa0:	83 3d 40 32 22 f0 00 	cmpl   $0x0,0xf0223240
f0100fa7:	75 25                	jne    f0100fce <check_page_free_list+0x3bb>
f0100fa9:	e9 7b fc ff ff       	jmp    f0100c29 <check_page_free_list+0x16>
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
		assert(page2pa(pp) != EXTPHYSMEM);
		//assert((char *) page2kva(pp) >= first_free_page );
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100fae:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100fb3:	0f 85 6f ff ff ff    	jne    f0100f28 <check_page_free_list+0x315>
f0100fb9:	e9 46 ff ff ff       	jmp    f0100f04 <check_page_free_list+0x2f1>
f0100fbe:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100fc3:	0f 85 64 ff ff ff    	jne    f0100f2d <check_page_free_list+0x31a>
f0100fc9:	e9 36 ff ff ff       	jmp    f0100f04 <check_page_free_list+0x2f1>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100fce:	8b 1d 40 32 22 f0    	mov    0xf0223240,%ebx
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100fd4:	be 00 04 00 00       	mov    $0x400,%esi
f0100fd9:	e9 bb fc ff ff       	jmp    f0100c99 <check_page_free_list+0x86>
		else
			++nfree_extmem;
	}
	assert(nfree_basemem > 0);
	assert(nfree_extmem > 0);
}
f0100fde:	83 c4 4c             	add    $0x4c,%esp
f0100fe1:	5b                   	pop    %ebx
f0100fe2:	5e                   	pop    %esi
f0100fe3:	5f                   	pop    %edi
f0100fe4:	5d                   	pop    %ebp
f0100fe5:	c3                   	ret    

f0100fe6 <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0100fe6:	55                   	push   %ebp
f0100fe7:	89 e5                	mov    %esp,%ebp
f0100fe9:	56                   	push   %esi
f0100fea:	53                   	push   %ebx
f0100feb:	83 ec 10             	sub    $0x10,%esp
	size_t i = 1;
	for (i; i < npages_basemem; i++) {
f0100fee:	8b 35 44 32 22 f0    	mov    0xf0223244,%esi
f0100ff4:	83 fe 01             	cmp    $0x1,%esi
f0100ff7:	76 39                	jbe    f0101032 <page_init+0x4c>
f0100ff9:	8b 1d 40 32 22 f0    	mov    0xf0223240,%ebx
// memory via the page_free_list.
//
void
page_init(void)
{
	size_t i = 1;
f0100fff:	b8 01 00 00 00       	mov    $0x1,%eax
f0101004:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
	for (i; i < npages_basemem; i++) {
		pages[i].pp_ref = 0;
f010100b:	89 d1                	mov    %edx,%ecx
f010100d:	03 0d 90 3e 22 f0    	add    0xf0223e90,%ecx
f0101013:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0101019:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f010101b:	03 15 90 3e 22 f0    	add    0xf0223e90,%edx
//
void
page_init(void)
{
	size_t i = 1;
	for (i; i < npages_basemem; i++) {
f0101021:	83 c0 01             	add    $0x1,%eax
f0101024:	39 f0                	cmp    %esi,%eax
f0101026:	73 04                	jae    f010102c <page_init+0x46>
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f0101028:	89 d3                	mov    %edx,%ebx
f010102a:	eb d8                	jmp    f0101004 <page_init+0x1e>
f010102c:	89 15 40 32 22 f0    	mov    %edx,0xf0223240
	}

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
f0101032:	8b 0d 88 3e 22 f0    	mov    0xf0223e88,%ecx
f0101038:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
f010103d:	8d 84 c8 ff ff 01 10 	lea    0x1001ffff(%eax,%ecx,8),%eax
f0101044:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0101049:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f010104f:	85 c0                	test   %eax,%eax
f0101051:	0f 48 c2             	cmovs  %edx,%eax
f0101054:	c1 f8 0c             	sar    $0xc,%eax
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f0101057:	89 c2                	mov    %eax,%edx
f0101059:	39 c1                	cmp    %eax,%ecx
f010105b:	76 37                	jbe    f0101094 <page_init+0xae>
f010105d:	8b 1d 40 32 22 f0    	mov    0xf0223240,%ebx
f0101063:	c1 e0 03             	shl    $0x3,%eax
		pages[i].pp_ref = 0;
f0101066:	89 c1                	mov    %eax,%ecx
f0101068:	03 0d 90 3e 22 f0    	add    0xf0223e90,%ecx
f010106e:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0101074:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f0101076:	89 c3                	mov    %eax,%ebx
f0101078:	03 1d 90 3e 22 f0    	add    0xf0223e90,%ebx

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f010107e:	83 c2 01             	add    $0x1,%edx
f0101081:	8b 0d 88 3e 22 f0    	mov    0xf0223e88,%ecx
f0101087:	83 c0 08             	add    $0x8,%eax
f010108a:	39 d1                	cmp    %edx,%ecx
f010108c:	77 d8                	ja     f0101066 <page_init+0x80>
f010108e:	89 1d 40 32 22 f0    	mov    %ebx,0xf0223240
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101094:	83 f9 07             	cmp    $0x7,%ecx
f0101097:	77 1c                	ja     f01010b5 <page_init+0xcf>
		panic("pa2page called with invalid pa");
f0101099:	c7 44 24 08 34 6b 10 	movl   $0xf0106b34,0x8(%esp)
f01010a0:	f0 
f01010a1:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01010a8:	00 
f01010a9:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f01010b0:	e8 8b ef ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f01010b5:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
               ppg_end->pp_link = ppg_start;*/

               //remain the page of mp entry Code
               extern unsigned char mpentry_start[], mpentry_end[];
               struct Page *ppg_start = pa2page((physaddr_t)MPENTRY_PADDR);      
               struct Page * ppg_end = pa2page((physaddr_t)(MPENTRY_PADDR+mpentry_end - mpentry_start));  
f01010bb:	b8 46 c9 10 f0       	mov    $0xf010c946,%eax
f01010c0:	2d cc 58 10 f0       	sub    $0xf01058cc,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01010c5:	c1 e8 0c             	shr    $0xc,%eax
f01010c8:	39 c8                	cmp    %ecx,%eax
f01010ca:	72 1c                	jb     f01010e8 <page_init+0x102>
		panic("pa2page called with invalid pa");
f01010cc:	c7 44 24 08 34 6b 10 	movl   $0xf0106b34,0x8(%esp)
f01010d3:	f0 
f01010d4:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01010db:	00 
f01010dc:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f01010e3:	e8 58 ef ff ff       	call   f0100040 <_panic>
               ppg_start--;    ppg_end++;
f01010e8:	8d 4a 30             	lea    0x30(%edx),%ecx
f01010eb:	89 4c c2 08          	mov    %ecx,0x8(%edx,%eax,8)
               ppg_end->pp_link = ppg_start;

              // cprintf("MPENTRY_PADDR_page_start:  %d\n",PGNUM(page2pa(ppg_start)));
               //cprintf("MPENTRY_PADDR_page_end:  %d\n",PGNUM(page2pa(ppg_end)));
               //cprintf("\n");
}
f01010ef:	83 c4 10             	add    $0x10,%esp
f01010f2:	5b                   	pop    %ebx
f01010f3:	5e                   	pop    %esi
f01010f4:	5d                   	pop    %ebp
f01010f5:	c3                   	ret    

f01010f6 <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
f01010f6:	55                   	push   %ebp
f01010f7:	89 e5                	mov    %esp,%ebp
f01010f9:	53                   	push   %ebx
f01010fa:	83 ec 14             	sub    $0x14,%esp
	//test output
              //cprintf(">>  page_alloc() was called!\n");

             if (page_free_list == NULL)
f01010fd:	8b 1d 40 32 22 f0    	mov    0xf0223240,%ebx
f0101103:	85 db                	test   %ebx,%ebx
f0101105:	74 69                	je     f0101170 <page_alloc+0x7a>
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
f0101107:	8b 03                	mov    (%ebx),%eax
f0101109:	a3 40 32 22 f0       	mov    %eax,0xf0223240
    
             if (alloc_flags & ALLOC_ZERO)
                    memset(page2kva(result), 0, PGSIZE);
        
             return result;
f010110e:	89 d8                	mov    %ebx,%eax
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
    
             if (alloc_flags & ALLOC_ZERO)
f0101110:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f0101114:	74 5f                	je     f0101175 <page_alloc+0x7f>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101116:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f010111c:	c1 f8 03             	sar    $0x3,%eax
f010111f:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101122:	89 c2                	mov    %eax,%edx
f0101124:	c1 ea 0c             	shr    $0xc,%edx
f0101127:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f010112d:	72 20                	jb     f010114f <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010112f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101133:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f010113a:	f0 
f010113b:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101142:	00 
f0101143:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f010114a:	e8 f1 ee ff ff       	call   f0100040 <_panic>
                    memset(page2kva(result), 0, PGSIZE);
f010114f:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101156:	00 
f0101157:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010115e:	00 
	return (void *)(pa + KERNBASE);
f010115f:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101164:	89 04 24             	mov    %eax,(%esp)
f0101167:	e8 2d 45 00 00       	call   f0105699 <memset>
        
             return result;
f010116c:	89 d8                	mov    %ebx,%eax
f010116e:	eb 05                	jmp    f0101175 <page_alloc+0x7f>
{
	//test output
              //cprintf(">>  page_alloc() was called!\n");

             if (page_free_list == NULL)
                             return NULL;
f0101170:	b8 00 00 00 00       	mov    $0x0,%eax
    
             if (alloc_flags & ALLOC_ZERO)
                    memset(page2kva(result), 0, PGSIZE);
        
             return result;
}
f0101175:	83 c4 14             	add    $0x14,%esp
f0101178:	5b                   	pop    %ebx
f0101179:	5d                   	pop    %ebp
f010117a:	c3                   	ret    

f010117b <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct Page *pp)
{
f010117b:	55                   	push   %ebp
f010117c:	89 e5                	mov    %esp,%ebp
f010117e:	8b 45 08             	mov    0x8(%ebp),%eax
	pp->pp_link = page_free_list;
f0101181:	8b 15 40 32 22 f0    	mov    0xf0223240,%edx
f0101187:	89 10                	mov    %edx,(%eax)
              page_free_list = pp;
f0101189:	a3 40 32 22 f0       	mov    %eax,0xf0223240
	// Fill this function in
}
f010118e:	5d                   	pop    %ebp
f010118f:	c3                   	ret    

f0101190 <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct Page* pp)
{
f0101190:	55                   	push   %ebp
f0101191:	89 e5                	mov    %esp,%ebp
f0101193:	83 ec 04             	sub    $0x4,%esp
f0101196:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f0101199:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f010119d:	8d 51 ff             	lea    -0x1(%ecx),%edx
f01011a0:	66 89 50 04          	mov    %dx,0x4(%eax)
f01011a4:	66 85 d2             	test   %dx,%dx
f01011a7:	75 08                	jne    f01011b1 <page_decref+0x21>
		page_free(pp);
f01011a9:	89 04 24             	mov    %eax,(%esp)
f01011ac:	e8 ca ff ff ff       	call   f010117b <page_free>
}
f01011b1:	c9                   	leave  
f01011b2:	c3                   	ret    

f01011b3 <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f01011b3:	55                   	push   %ebp
f01011b4:	89 e5                	mov    %esp,%ebp
f01011b6:	56                   	push   %esi
f01011b7:	53                   	push   %ebx
f01011b8:	83 ec 10             	sub    $0x10,%esp
f01011bb:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	// Fill this function in
	//test output
              //cprintf(">>  pgdir_walk() was called!\n");

             pte_t *result;
            if (pgdir[PDX(va)] == (pte_t)NULL) {            //yet to create
f01011be:	89 de                	mov    %ebx,%esi
f01011c0:	c1 ee 16             	shr    $0x16,%esi
f01011c3:	c1 e6 02             	shl    $0x2,%esi
f01011c6:	03 75 08             	add    0x8(%ebp),%esi
f01011c9:	8b 06                	mov    (%esi),%eax
f01011cb:	85 c0                	test   %eax,%eax
f01011cd:	75 76                	jne    f0101245 <pgdir_walk+0x92>
                      if (create == 0)
f01011cf:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f01011d3:	0f 84 d1 00 00 00    	je     f01012aa <pgdir_walk+0xf7>
                                        return NULL;
                     else {
                                        struct Page *tmp = page_alloc(ALLOC_ZERO);
f01011d9:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01011e0:	e8 11 ff ff ff       	call   f01010f6 <page_alloc>
                                        if (tmp == NULL)
f01011e5:	85 c0                	test   %eax,%eax
f01011e7:	0f 84 c4 00 00 00    	je     f01012b1 <pgdir_walk+0xfe>
                                                  return NULL;                        //failed to alloc
                                        else {
                                                  tmp->pp_ref++;
f01011ed:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01011f2:	89 c2                	mov    %eax,%edx
f01011f4:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f01011fa:	c1 fa 03             	sar    $0x3,%edx
f01011fd:	c1 e2 0c             	shl    $0xc,%edx
                                                  pgdir[PDX(va)] = page2pa(tmp) | PTE_P | PTE_W |PTE_U;    //save the physical address of newly allocated page in page dir
f0101200:	83 ca 07             	or     $0x7,%edx
f0101203:	89 16                	mov    %edx,(%esi)
f0101205:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f010120b:	c1 f8 03             	sar    $0x3,%eax
f010120e:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101211:	89 c2                	mov    %eax,%edx
f0101213:	c1 ea 0c             	shr    $0xc,%edx
f0101216:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f010121c:	72 20                	jb     f010123e <pgdir_walk+0x8b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010121e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101222:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f0101229:	f0 
f010122a:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101231:	00 
f0101232:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f0101239:	e8 02 ee ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f010123e:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101243:	eb 58                	jmp    f010129d <pgdir_walk+0xea>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101245:	c1 e8 0c             	shr    $0xc,%eax
f0101248:	8b 15 88 3e 22 f0    	mov    0xf0223e88,%edx
f010124e:	39 d0                	cmp    %edx,%eax
f0101250:	72 1c                	jb     f010126e <pgdir_walk+0xbb>
		panic("pa2page called with invalid pa");
f0101252:	c7 44 24 08 34 6b 10 	movl   $0xf0106b34,0x8(%esp)
f0101259:	f0 
f010125a:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101261:	00 
f0101262:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f0101269:	e8 d2 ed ff ff       	call   f0100040 <_panic>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010126e:	89 c1                	mov    %eax,%ecx
f0101270:	c1 e1 0c             	shl    $0xc,%ecx
f0101273:	39 d0                	cmp    %edx,%eax
f0101275:	72 20                	jb     f0101297 <pgdir_walk+0xe4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101277:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f010127b:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f0101282:	f0 
f0101283:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010128a:	00 
f010128b:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f0101292:	e8 a9 ed ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0101297:	8d 81 00 00 00 f0    	lea    -0x10000000(%ecx),%eax
                                  }
                 }
               else                        
               result = page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
        
               return &result[PTX(va)];
f010129d:	c1 eb 0a             	shr    $0xa,%ebx
f01012a0:	81 e3 fc 0f 00 00    	and    $0xffc,%ebx
f01012a6:	01 d8                	add    %ebx,%eax
f01012a8:	eb 0c                	jmp    f01012b6 <pgdir_walk+0x103>
              //cprintf(">>  pgdir_walk() was called!\n");

             pte_t *result;
            if (pgdir[PDX(va)] == (pte_t)NULL) {            //yet to create
                      if (create == 0)
                                        return NULL;
f01012aa:	b8 00 00 00 00       	mov    $0x0,%eax
f01012af:	eb 05                	jmp    f01012b6 <pgdir_walk+0x103>
                     else {
                                        struct Page *tmp = page_alloc(ALLOC_ZERO);
                                        if (tmp == NULL)
                                                  return NULL;                        //failed to alloc
f01012b1:	b8 00 00 00 00       	mov    $0x0,%eax
                 }
               else                        
               result = page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
        
               return &result[PTX(va)];
}
f01012b6:	83 c4 10             	add    $0x10,%esp
f01012b9:	5b                   	pop    %ebx
f01012ba:	5e                   	pop    %esi
f01012bb:	5d                   	pop    %ebp
f01012bc:	c3                   	ret    

f01012bd <boot_map_region>:
// mapped pages.
//
// Hint: the TA solution uses pgdir_walk
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
f01012bd:	55                   	push   %ebp
f01012be:	89 e5                	mov    %esp,%ebp
f01012c0:	57                   	push   %edi
f01012c1:	56                   	push   %esi
f01012c2:	53                   	push   %ebx
f01012c3:	83 ec 2c             	sub    $0x2c,%esp
	size_t i = 0;
	pte_t * pgEntry;
	for(i;i<(size/PGSIZE);i++){
f01012c6:	c1 e9 0c             	shr    $0xc,%ecx
f01012c9:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
f01012cc:	85 c9                	test   %ecx,%ecx
f01012ce:	74 6d                	je     f010133d <boot_map_region+0x80>
f01012d0:	89 c7                	mov    %eax,%edi
f01012d2:	89 d3                	mov    %edx,%ebx
//
// Hint: the TA solution uses pgdir_walk
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	size_t i = 0;
f01012d4:	be 00 00 00 00       	mov    $0x0,%esi
	for(i;i<(size/PGSIZE);i++){
		pgEntry = pgdir_walk(pgdir,(void*)(va+i*PGSIZE),1);
		if(pgEntry==NULL){
			panic("kern page not allocated!\n");
		}
		(*pgEntry) = PTE_ADDR(pa + PGSIZE * i) | perm | PTE_P;
f01012d9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01012dc:	83 c8 01             	or     $0x1,%eax
f01012df:	89 45 e0             	mov    %eax,-0x20(%ebp)
f01012e2:	8b 45 08             	mov    0x8(%ebp),%eax
f01012e5:	29 d0                	sub    %edx,%eax
f01012e7:	89 45 dc             	mov    %eax,-0x24(%ebp)
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	size_t i = 0;
	pte_t * pgEntry;
	for(i;i<(size/PGSIZE);i++){
		pgEntry = pgdir_walk(pgdir,(void*)(va+i*PGSIZE),1);
f01012ea:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01012f1:	00 
f01012f2:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01012f6:	89 3c 24             	mov    %edi,(%esp)
f01012f9:	e8 b5 fe ff ff       	call   f01011b3 <pgdir_walk>
		if(pgEntry==NULL){
f01012fe:	85 c0                	test   %eax,%eax
f0101300:	75 1c                	jne    f010131e <boot_map_region+0x61>
			panic("kern page not allocated!\n");
f0101302:	c7 44 24 08 40 72 10 	movl   $0xf0107240,0x8(%esp)
f0101309:	f0 
f010130a:	c7 44 24 04 f3 01 00 	movl   $0x1f3,0x4(%esp)
f0101311:	00 
f0101312:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101319:	e8 22 ed ff ff       	call   f0100040 <_panic>
f010131e:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0101321:	8d 14 19             	lea    (%ecx,%ebx,1),%edx
		}
		(*pgEntry) = PTE_ADDR(pa + PGSIZE * i) | perm | PTE_P;
f0101324:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f010132a:	0b 55 e0             	or     -0x20(%ebp),%edx
f010132d:	89 10                	mov    %edx,(%eax)
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	size_t i = 0;
	pte_t * pgEntry;
	for(i;i<(size/PGSIZE);i++){
f010132f:	83 c6 01             	add    $0x1,%esi
f0101332:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0101338:	3b 75 e4             	cmp    -0x1c(%ebp),%esi
f010133b:	75 ad                	jne    f01012ea <boot_map_region+0x2d>
			panic("kern page not allocated!\n");
		}
		(*pgEntry) = PTE_ADDR(pa + PGSIZE * i) | perm | PTE_P;
	}
	// Fill this function in
}
f010133d:	83 c4 2c             	add    $0x2c,%esp
f0101340:	5b                   	pop    %ebx
f0101341:	5e                   	pop    %esi
f0101342:	5f                   	pop    %edi
f0101343:	5d                   	pop    %ebp
f0101344:	c3                   	ret    

f0101345 <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f0101345:	55                   	push   %ebp
f0101346:	89 e5                	mov    %esp,%ebp
f0101348:	53                   	push   %ebx
f0101349:	83 ec 14             	sub    $0x14,%esp
f010134c:	8b 5d 10             	mov    0x10(%ebp),%ebx
	// Fill this function in
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
f010134f:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101356:	00 
f0101357:	8b 45 0c             	mov    0xc(%ebp),%eax
f010135a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010135e:	8b 45 08             	mov    0x8(%ebp),%eax
f0101361:	89 04 24             	mov    %eax,(%esp)
f0101364:	e8 4a fe ff ff       	call   f01011b3 <pgdir_walk>
              if (pte == NULL)
f0101369:	85 c0                	test   %eax,%eax
f010136b:	74 3a                	je     f01013a7 <page_lookup+0x62>
                       return NULL;

             if (pte_store != 0)
f010136d:	85 db                	test   %ebx,%ebx
f010136f:	74 02                	je     f0101373 <page_lookup+0x2e>
                     *pte_store = pte;
f0101371:	89 03                	mov    %eax,(%ebx)

             return pa2page(PTE_ADDR(pte[0]));
f0101373:	8b 00                	mov    (%eax),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101375:	c1 e8 0c             	shr    $0xc,%eax
f0101378:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f010137e:	72 1c                	jb     f010139c <page_lookup+0x57>
		panic("pa2page called with invalid pa");
f0101380:	c7 44 24 08 34 6b 10 	movl   $0xf0106b34,0x8(%esp)
f0101387:	f0 
f0101388:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010138f:	00 
f0101390:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f0101397:	e8 a4 ec ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f010139c:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f01013a2:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01013a5:	eb 05                	jmp    f01013ac <page_lookup+0x67>
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
              if (pte == NULL)
                       return NULL;
f01013a7:	b8 00 00 00 00       	mov    $0x0,%eax

             if (pte_store != 0)
                     *pte_store = pte;

             return pa2page(PTE_ADDR(pte[0]));
}
f01013ac:	83 c4 14             	add    $0x14,%esp
f01013af:	5b                   	pop    %ebx
f01013b0:	5d                   	pop    %ebp
f01013b1:	c3                   	ret    

f01013b2 <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f01013b2:	55                   	push   %ebp
f01013b3:	89 e5                	mov    %esp,%ebp
f01013b5:	83 ec 08             	sub    $0x8,%esp
	// Flush the entry only if we're modifying the current address space.
	if (!curenv || curenv->env_pgdir == pgdir)
f01013b8:	e8 76 49 00 00       	call   f0105d33 <cpunum>
f01013bd:	6b c0 74             	imul   $0x74,%eax,%eax
f01013c0:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f01013c7:	74 16                	je     f01013df <tlb_invalidate+0x2d>
f01013c9:	e8 65 49 00 00       	call   f0105d33 <cpunum>
f01013ce:	6b c0 74             	imul   $0x74,%eax,%eax
f01013d1:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f01013d7:	8b 55 08             	mov    0x8(%ebp),%edx
f01013da:	39 50 60             	cmp    %edx,0x60(%eax)
f01013dd:	75 06                	jne    f01013e5 <tlb_invalidate+0x33>
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f01013df:	8b 45 0c             	mov    0xc(%ebp),%eax
f01013e2:	0f 01 38             	invlpg (%eax)
		invlpg(va);
}
f01013e5:	c9                   	leave  
f01013e6:	c3                   	ret    

f01013e7 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f01013e7:	55                   	push   %ebp
f01013e8:	89 e5                	mov    %esp,%ebp
f01013ea:	56                   	push   %esi
f01013eb:	53                   	push   %ebx
f01013ec:	83 ec 20             	sub    $0x20,%esp
f01013ef:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01013f2:	8b 75 0c             	mov    0xc(%ebp),%esi
	// Fill this function in
	//test output
               //cprintf(">>  page_remove() was called!\n");
    
              pte_t *pte;
              struct Page *page = page_lookup(pgdir, va, &pte);
f01013f5:	8d 45 f4             	lea    -0xc(%ebp),%eax
f01013f8:	89 44 24 08          	mov    %eax,0x8(%esp)
f01013fc:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101400:	89 1c 24             	mov    %ebx,(%esp)
f0101403:	e8 3d ff ff ff       	call   f0101345 <page_lookup>
    
              if (page != NULL)
f0101408:	85 c0                	test   %eax,%eax
f010140a:	74 08                	je     f0101414 <page_remove+0x2d>
                         page_decref(page);
f010140c:	89 04 24             	mov    %eax,(%esp)
f010140f:	e8 7c fd ff ff       	call   f0101190 <page_decref>
        
              pte[0] = 0;
f0101414:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101417:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
              tlb_invalidate(pgdir, va);
f010141d:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101421:	89 1c 24             	mov    %ebx,(%esp)
f0101424:	e8 89 ff ff ff       	call   f01013b2 <tlb_invalidate>
}
f0101429:	83 c4 20             	add    $0x20,%esp
f010142c:	5b                   	pop    %ebx
f010142d:	5e                   	pop    %esi
f010142e:	5d                   	pop    %ebp
f010142f:	c3                   	ret    

f0101430 <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
{
f0101430:	55                   	push   %ebp
f0101431:	89 e5                	mov    %esp,%ebp
f0101433:	57                   	push   %edi
f0101434:	56                   	push   %esi
f0101435:	53                   	push   %ebx
f0101436:	83 ec 1c             	sub    $0x1c,%esp
f0101439:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010143c:	8b 75 10             	mov    0x10(%ebp),%esi
	// Fill this function in
	//test output
                                //cprintf(">>  page_insert() was called!\n");
    
               struct Page *page = page_lookup(pgdir, va, NULL);
f010143f:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101446:	00 
f0101447:	89 74 24 04          	mov    %esi,0x4(%esp)
f010144b:	8b 45 08             	mov    0x8(%ebp),%eax
f010144e:	89 04 24             	mov    %eax,(%esp)
f0101451:	e8 ef fe ff ff       	call   f0101345 <page_lookup>
f0101456:	89 c7                	mov    %eax,%edi
               pte_t *pte;
    
              if (page == pp) {                       //re-insert into the same place
f0101458:	39 d8                	cmp    %ebx,%eax
f010145a:	75 36                	jne    f0101492 <page_insert+0x62>
                            pte = pgdir_walk(pgdir, va, 0);
f010145c:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101463:	00 
f0101464:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101468:	8b 45 08             	mov    0x8(%ebp),%eax
f010146b:	89 04 24             	mov    %eax,(%esp)
f010146e:	e8 40 fd ff ff       	call   f01011b3 <pgdir_walk>
                            pte[0] = page2pa(pp) | perm | PTE_P;
f0101473:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0101476:	83 c9 01             	or     $0x1,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101479:	2b 3d 90 3e 22 f0    	sub    0xf0223e90,%edi
f010147f:	c1 ff 03             	sar    $0x3,%edi
f0101482:	c1 e7 0c             	shl    $0xc,%edi
f0101485:	89 fa                	mov    %edi,%edx
f0101487:	09 ca                	or     %ecx,%edx
f0101489:	89 10                	mov    %edx,(%eax)
                            return 0;
f010148b:	b8 00 00 00 00       	mov    $0x0,%eax
f0101490:	eb 57                	jmp    f01014e9 <page_insert+0xb9>
                          }
    
               if (page != NULL)                       //remove original page if existed
f0101492:	85 c0                	test   %eax,%eax
f0101494:	74 0f                	je     f01014a5 <page_insert+0x75>
                        page_remove(pgdir, va);
f0101496:	89 74 24 04          	mov    %esi,0x4(%esp)
f010149a:	8b 45 08             	mov    0x8(%ebp),%eax
f010149d:	89 04 24             	mov    %eax,(%esp)
f01014a0:	e8 42 ff ff ff       	call   f01013e7 <page_remove>
        
              pte = pgdir_walk(pgdir, va, 1);
f01014a5:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01014ac:	00 
f01014ad:	89 74 24 04          	mov    %esi,0x4(%esp)
f01014b1:	8b 45 08             	mov    0x8(%ebp),%eax
f01014b4:	89 04 24             	mov    %eax,(%esp)
f01014b7:	e8 f7 fc ff ff       	call   f01011b3 <pgdir_walk>
              if (pte == NULL)
f01014bc:	85 c0                	test   %eax,%eax
f01014be:	74 24                	je     f01014e4 <page_insert+0xb4>
                       return -E_NO_MEM;

              pte[0] = page2pa(pp) | perm | PTE_P;
f01014c0:	8b 4d 14             	mov    0x14(%ebp),%ecx
f01014c3:	83 c9 01             	or     $0x1,%ecx
f01014c6:	89 da                	mov    %ebx,%edx
f01014c8:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f01014ce:	c1 fa 03             	sar    $0x3,%edx
f01014d1:	c1 e2 0c             	shl    $0xc,%edx
f01014d4:	09 ca                	or     %ecx,%edx
f01014d6:	89 10                	mov    %edx,(%eax)
               pp->pp_ref++;
f01014d8:	66 83 43 04 01       	addw   $0x1,0x4(%ebx)

	return 0; 
f01014dd:	b8 00 00 00 00       	mov    $0x0,%eax
f01014e2:	eb 05                	jmp    f01014e9 <page_insert+0xb9>
               if (page != NULL)                       //remove original page if existed
                        page_remove(pgdir, va);
        
              pte = pgdir_walk(pgdir, va, 1);
              if (pte == NULL)
                       return -E_NO_MEM;
f01014e4:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax

              pte[0] = page2pa(pp) | perm | PTE_P;
               pp->pp_ref++;

	return 0; 
}
f01014e9:	83 c4 1c             	add    $0x1c,%esp
f01014ec:	5b                   	pop    %ebx
f01014ed:	5e                   	pop    %esi
f01014ee:	5f                   	pop    %edi
f01014ef:	5d                   	pop    %ebp
f01014f0:	c3                   	ret    

f01014f1 <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f01014f1:	55                   	push   %ebp
f01014f2:	89 e5                	mov    %esp,%ebp
f01014f4:	57                   	push   %edi
f01014f5:	56                   	push   %esi
f01014f6:	53                   	push   %ebx
f01014f7:	83 ec 4c             	sub    $0x4c,%esp
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01014fa:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f0101501:	e8 6c 28 00 00       	call   f0103d72 <mc146818_read>
f0101506:	89 c3                	mov    %eax,%ebx
f0101508:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f010150f:	e8 5e 28 00 00       	call   f0103d72 <mc146818_read>
f0101514:	c1 e0 08             	shl    $0x8,%eax
f0101517:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f0101519:	89 d8                	mov    %ebx,%eax
f010151b:	c1 e0 0a             	shl    $0xa,%eax
f010151e:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0101524:	85 c0                	test   %eax,%eax
f0101526:	0f 48 c2             	cmovs  %edx,%eax
f0101529:	c1 f8 0c             	sar    $0xc,%eax
f010152c:	a3 44 32 22 f0       	mov    %eax,0xf0223244
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0101531:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f0101538:	e8 35 28 00 00       	call   f0103d72 <mc146818_read>
f010153d:	89 c3                	mov    %eax,%ebx
f010153f:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f0101546:	e8 27 28 00 00       	call   f0103d72 <mc146818_read>
f010154b:	c1 e0 08             	shl    $0x8,%eax
f010154e:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f0101550:	89 d8                	mov    %ebx,%eax
f0101552:	c1 e0 0a             	shl    $0xa,%eax
f0101555:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f010155b:	85 c0                	test   %eax,%eax
f010155d:	0f 48 c2             	cmovs  %edx,%eax
f0101560:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f0101563:	85 c0                	test   %eax,%eax
f0101565:	74 0e                	je     f0101575 <mem_init+0x84>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f0101567:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f010156d:	89 15 88 3e 22 f0    	mov    %edx,0xf0223e88
f0101573:	eb 0c                	jmp    f0101581 <mem_init+0x90>
	else
		npages = npages_basemem;
f0101575:	8b 15 44 32 22 f0    	mov    0xf0223244,%edx
f010157b:	89 15 88 3e 22 f0    	mov    %edx,0xf0223e88

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f0101581:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101584:	c1 e8 0a             	shr    $0xa,%eax
f0101587:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f010158b:	a1 44 32 22 f0       	mov    0xf0223244,%eax
f0101590:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101593:	c1 e8 0a             	shr    $0xa,%eax
f0101596:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f010159a:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f010159f:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f01015a2:	c1 e8 0a             	shr    $0xa,%eax
f01015a5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01015a9:	c7 04 24 54 6b 10 f0 	movl   $0xf0106b54,(%esp)
f01015b0:	e8 29 29 00 00       	call   f0103ede <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);  // first_level pagedir
f01015b5:	b8 00 10 00 00       	mov    $0x1000,%eax
f01015ba:	e8 81 f5 ff ff       	call   f0100b40 <boot_alloc>
f01015bf:	a3 8c 3e 22 f0       	mov    %eax,0xf0223e8c
	memset(kern_pgdir, 0, PGSIZE);
f01015c4:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01015cb:	00 
f01015cc:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01015d3:	00 
f01015d4:	89 04 24             	mov    %eax,(%esp)
f01015d7:	e8 bd 40 00 00       	call   f0105699 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f01015dc:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01015e1:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01015e6:	77 20                	ja     f0101608 <mem_init+0x117>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01015e8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01015ec:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f01015f3:	f0 
f01015f4:	c7 44 24 04 96 00 00 	movl   $0x96,0x4(%esp)
f01015fb:	00 
f01015fc:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101603:	e8 38 ea ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0101608:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f010160e:	83 ca 05             	or     $0x5,%edx
f0101611:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct Page in this
	// array.  'npages' is the number of physical pages in memory.
	// Your code goes here:

	pages = (struct Page *)boot_alloc(npages * sizeof(struct Page)); // allocate npages to record all physical pages in memort using condition
f0101617:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f010161c:	c1 e0 03             	shl    $0x3,%eax
f010161f:	e8 1c f5 ff ff       	call   f0100b40 <boot_alloc>
f0101624:	a3 90 3e 22 f0       	mov    %eax,0xf0223e90


	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.
	envs =  (struct Env *)boot_alloc(NENV * sizeof(struct Env));
f0101629:	b8 00 f0 01 00       	mov    $0x1f000,%eax
f010162e:	e8 0d f5 ff ff       	call   f0100b40 <boot_alloc>
f0101633:	a3 48 32 22 f0       	mov    %eax,0xf0223248
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f0101638:	e8 a9 f9 ff ff       	call   f0100fe6 <page_init>

	check_page_free_list(1);
f010163d:	b8 01 00 00 00       	mov    $0x1,%eax
f0101642:	e8 cc f5 ff ff       	call   f0100c13 <check_page_free_list>
	int nfree;
	struct Page *fl;
	char *c;
	int i;

	if (!pages)
f0101647:	83 3d 90 3e 22 f0 00 	cmpl   $0x0,0xf0223e90
f010164e:	75 1c                	jne    f010166c <mem_init+0x17b>
		panic("'pages' is a null pointer!");
f0101650:	c7 44 24 08 5a 72 10 	movl   $0xf010725a,0x8(%esp)
f0101657:	f0 
f0101658:	c7 44 24 04 10 03 00 	movl   $0x310,0x4(%esp)
f010165f:	00 
f0101660:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101667:	e8 d4 e9 ff ff       	call   f0100040 <_panic>

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010166c:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0101671:	85 c0                	test   %eax,%eax
f0101673:	74 10                	je     f0101685 <mem_init+0x194>
f0101675:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;
f010167a:	83 c3 01             	add    $0x1,%ebx

	if (!pages)
		panic("'pages' is a null pointer!");

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010167d:	8b 00                	mov    (%eax),%eax
f010167f:	85 c0                	test   %eax,%eax
f0101681:	75 f7                	jne    f010167a <mem_init+0x189>
f0101683:	eb 05                	jmp    f010168a <mem_init+0x199>
f0101685:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f010168a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101691:	e8 60 fa ff ff       	call   f01010f6 <page_alloc>
f0101696:	89 c7                	mov    %eax,%edi
f0101698:	85 c0                	test   %eax,%eax
f010169a:	75 24                	jne    f01016c0 <mem_init+0x1cf>
f010169c:	c7 44 24 0c 75 72 10 	movl   $0xf0107275,0xc(%esp)
f01016a3:	f0 
f01016a4:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01016ab:	f0 
f01016ac:	c7 44 24 04 18 03 00 	movl   $0x318,0x4(%esp)
f01016b3:	00 
f01016b4:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01016bb:	e8 80 e9 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f01016c0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01016c7:	e8 2a fa ff ff       	call   f01010f6 <page_alloc>
f01016cc:	89 c6                	mov    %eax,%esi
f01016ce:	85 c0                	test   %eax,%eax
f01016d0:	75 24                	jne    f01016f6 <mem_init+0x205>
f01016d2:	c7 44 24 0c 8b 72 10 	movl   $0xf010728b,0xc(%esp)
f01016d9:	f0 
f01016da:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01016e1:	f0 
f01016e2:	c7 44 24 04 19 03 00 	movl   $0x319,0x4(%esp)
f01016e9:	00 
f01016ea:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01016f1:	e8 4a e9 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01016f6:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01016fd:	e8 f4 f9 ff ff       	call   f01010f6 <page_alloc>
f0101702:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101705:	85 c0                	test   %eax,%eax
f0101707:	75 24                	jne    f010172d <mem_init+0x23c>
f0101709:	c7 44 24 0c a1 72 10 	movl   $0xf01072a1,0xc(%esp)
f0101710:	f0 
f0101711:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101718:	f0 
f0101719:	c7 44 24 04 1a 03 00 	movl   $0x31a,0x4(%esp)
f0101720:	00 
f0101721:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101728:	e8 13 e9 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f010172d:	39 f7                	cmp    %esi,%edi
f010172f:	75 24                	jne    f0101755 <mem_init+0x264>
f0101731:	c7 44 24 0c b7 72 10 	movl   $0xf01072b7,0xc(%esp)
f0101738:	f0 
f0101739:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101740:	f0 
f0101741:	c7 44 24 04 1d 03 00 	movl   $0x31d,0x4(%esp)
f0101748:	00 
f0101749:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101750:	e8 eb e8 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101755:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101758:	39 c6                	cmp    %eax,%esi
f010175a:	74 04                	je     f0101760 <mem_init+0x26f>
f010175c:	39 c7                	cmp    %eax,%edi
f010175e:	75 24                	jne    f0101784 <mem_init+0x293>
f0101760:	c7 44 24 0c 90 6b 10 	movl   $0xf0106b90,0xc(%esp)
f0101767:	f0 
f0101768:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010176f:	f0 
f0101770:	c7 44 24 04 1e 03 00 	movl   $0x31e,0x4(%esp)
f0101777:	00 
f0101778:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010177f:	e8 bc e8 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101784:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f010178a:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f010178f:	c1 e0 0c             	shl    $0xc,%eax
f0101792:	89 f9                	mov    %edi,%ecx
f0101794:	29 d1                	sub    %edx,%ecx
f0101796:	c1 f9 03             	sar    $0x3,%ecx
f0101799:	c1 e1 0c             	shl    $0xc,%ecx
f010179c:	39 c1                	cmp    %eax,%ecx
f010179e:	72 24                	jb     f01017c4 <mem_init+0x2d3>
f01017a0:	c7 44 24 0c c9 72 10 	movl   $0xf01072c9,0xc(%esp)
f01017a7:	f0 
f01017a8:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01017af:	f0 
f01017b0:	c7 44 24 04 1f 03 00 	movl   $0x31f,0x4(%esp)
f01017b7:	00 
f01017b8:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01017bf:	e8 7c e8 ff ff       	call   f0100040 <_panic>
f01017c4:	89 f1                	mov    %esi,%ecx
f01017c6:	29 d1                	sub    %edx,%ecx
f01017c8:	c1 f9 03             	sar    $0x3,%ecx
f01017cb:	c1 e1 0c             	shl    $0xc,%ecx
	assert(page2pa(pp1) < npages*PGSIZE);
f01017ce:	39 c8                	cmp    %ecx,%eax
f01017d0:	77 24                	ja     f01017f6 <mem_init+0x305>
f01017d2:	c7 44 24 0c e6 72 10 	movl   $0xf01072e6,0xc(%esp)
f01017d9:	f0 
f01017da:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01017e1:	f0 
f01017e2:	c7 44 24 04 20 03 00 	movl   $0x320,0x4(%esp)
f01017e9:	00 
f01017ea:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01017f1:	e8 4a e8 ff ff       	call   f0100040 <_panic>
f01017f6:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01017f9:	29 d1                	sub    %edx,%ecx
f01017fb:	89 ca                	mov    %ecx,%edx
f01017fd:	c1 fa 03             	sar    $0x3,%edx
f0101800:	c1 e2 0c             	shl    $0xc,%edx
	assert(page2pa(pp2) < npages*PGSIZE);
f0101803:	39 d0                	cmp    %edx,%eax
f0101805:	77 24                	ja     f010182b <mem_init+0x33a>
f0101807:	c7 44 24 0c 03 73 10 	movl   $0xf0107303,0xc(%esp)
f010180e:	f0 
f010180f:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101816:	f0 
f0101817:	c7 44 24 04 21 03 00 	movl   $0x321,0x4(%esp)
f010181e:	00 
f010181f:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101826:	e8 15 e8 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f010182b:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0101830:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101833:	c7 05 40 32 22 f0 00 	movl   $0x0,0xf0223240
f010183a:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f010183d:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101844:	e8 ad f8 ff ff       	call   f01010f6 <page_alloc>
f0101849:	85 c0                	test   %eax,%eax
f010184b:	74 24                	je     f0101871 <mem_init+0x380>
f010184d:	c7 44 24 0c 20 73 10 	movl   $0xf0107320,0xc(%esp)
f0101854:	f0 
f0101855:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010185c:	f0 
f010185d:	c7 44 24 04 28 03 00 	movl   $0x328,0x4(%esp)
f0101864:	00 
f0101865:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010186c:	e8 cf e7 ff ff       	call   f0100040 <_panic>

	// free and re-allocate?
	page_free(pp0);
f0101871:	89 3c 24             	mov    %edi,(%esp)
f0101874:	e8 02 f9 ff ff       	call   f010117b <page_free>
	page_free(pp1);
f0101879:	89 34 24             	mov    %esi,(%esp)
f010187c:	e8 fa f8 ff ff       	call   f010117b <page_free>
	page_free(pp2);
f0101881:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101884:	89 04 24             	mov    %eax,(%esp)
f0101887:	e8 ef f8 ff ff       	call   f010117b <page_free>
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f010188c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101893:	e8 5e f8 ff ff       	call   f01010f6 <page_alloc>
f0101898:	89 c6                	mov    %eax,%esi
f010189a:	85 c0                	test   %eax,%eax
f010189c:	75 24                	jne    f01018c2 <mem_init+0x3d1>
f010189e:	c7 44 24 0c 75 72 10 	movl   $0xf0107275,0xc(%esp)
f01018a5:	f0 
f01018a6:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01018ad:	f0 
f01018ae:	c7 44 24 04 2f 03 00 	movl   $0x32f,0x4(%esp)
f01018b5:	00 
f01018b6:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01018bd:	e8 7e e7 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f01018c2:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018c9:	e8 28 f8 ff ff       	call   f01010f6 <page_alloc>
f01018ce:	89 c7                	mov    %eax,%edi
f01018d0:	85 c0                	test   %eax,%eax
f01018d2:	75 24                	jne    f01018f8 <mem_init+0x407>
f01018d4:	c7 44 24 0c 8b 72 10 	movl   $0xf010728b,0xc(%esp)
f01018db:	f0 
f01018dc:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01018e3:	f0 
f01018e4:	c7 44 24 04 30 03 00 	movl   $0x330,0x4(%esp)
f01018eb:	00 
f01018ec:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01018f3:	e8 48 e7 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01018f8:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018ff:	e8 f2 f7 ff ff       	call   f01010f6 <page_alloc>
f0101904:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101907:	85 c0                	test   %eax,%eax
f0101909:	75 24                	jne    f010192f <mem_init+0x43e>
f010190b:	c7 44 24 0c a1 72 10 	movl   $0xf01072a1,0xc(%esp)
f0101912:	f0 
f0101913:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010191a:	f0 
f010191b:	c7 44 24 04 31 03 00 	movl   $0x331,0x4(%esp)
f0101922:	00 
f0101923:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010192a:	e8 11 e7 ff ff       	call   f0100040 <_panic>
	assert(pp0);
	assert(pp1 && pp1 != pp0);
f010192f:	39 fe                	cmp    %edi,%esi
f0101931:	75 24                	jne    f0101957 <mem_init+0x466>
f0101933:	c7 44 24 0c b7 72 10 	movl   $0xf01072b7,0xc(%esp)
f010193a:	f0 
f010193b:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101942:	f0 
f0101943:	c7 44 24 04 33 03 00 	movl   $0x333,0x4(%esp)
f010194a:	00 
f010194b:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101952:	e8 e9 e6 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101957:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010195a:	39 c7                	cmp    %eax,%edi
f010195c:	74 04                	je     f0101962 <mem_init+0x471>
f010195e:	39 c6                	cmp    %eax,%esi
f0101960:	75 24                	jne    f0101986 <mem_init+0x495>
f0101962:	c7 44 24 0c 90 6b 10 	movl   $0xf0106b90,0xc(%esp)
f0101969:	f0 
f010196a:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101971:	f0 
f0101972:	c7 44 24 04 34 03 00 	movl   $0x334,0x4(%esp)
f0101979:	00 
f010197a:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101981:	e8 ba e6 ff ff       	call   f0100040 <_panic>
	assert(!page_alloc(0));
f0101986:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010198d:	e8 64 f7 ff ff       	call   f01010f6 <page_alloc>
f0101992:	85 c0                	test   %eax,%eax
f0101994:	74 24                	je     f01019ba <mem_init+0x4c9>
f0101996:	c7 44 24 0c 20 73 10 	movl   $0xf0107320,0xc(%esp)
f010199d:	f0 
f010199e:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01019a5:	f0 
f01019a6:	c7 44 24 04 35 03 00 	movl   $0x335,0x4(%esp)
f01019ad:	00 
f01019ae:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01019b5:	e8 86 e6 ff ff       	call   f0100040 <_panic>
f01019ba:	89 f0                	mov    %esi,%eax
f01019bc:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f01019c2:	c1 f8 03             	sar    $0x3,%eax
f01019c5:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01019c8:	89 c2                	mov    %eax,%edx
f01019ca:	c1 ea 0c             	shr    $0xc,%edx
f01019cd:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f01019d3:	72 20                	jb     f01019f5 <mem_init+0x504>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01019d5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01019d9:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f01019e0:	f0 
f01019e1:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01019e8:	00 
f01019e9:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f01019f0:	e8 4b e6 ff ff       	call   f0100040 <_panic>

	// test flags
	memset(page2kva(pp0), 1, PGSIZE);
f01019f5:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01019fc:	00 
f01019fd:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f0101a04:	00 
	return (void *)(pa + KERNBASE);
f0101a05:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101a0a:	89 04 24             	mov    %eax,(%esp)
f0101a0d:	e8 87 3c 00 00       	call   f0105699 <memset>
	page_free(pp0);
f0101a12:	89 34 24             	mov    %esi,(%esp)
f0101a15:	e8 61 f7 ff ff       	call   f010117b <page_free>
	assert((pp = page_alloc(ALLOC_ZERO)));
f0101a1a:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101a21:	e8 d0 f6 ff ff       	call   f01010f6 <page_alloc>
f0101a26:	85 c0                	test   %eax,%eax
f0101a28:	75 24                	jne    f0101a4e <mem_init+0x55d>
f0101a2a:	c7 44 24 0c 2f 73 10 	movl   $0xf010732f,0xc(%esp)
f0101a31:	f0 
f0101a32:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101a39:	f0 
f0101a3a:	c7 44 24 04 3a 03 00 	movl   $0x33a,0x4(%esp)
f0101a41:	00 
f0101a42:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101a49:	e8 f2 e5 ff ff       	call   f0100040 <_panic>
	assert(pp && pp0 == pp);
f0101a4e:	39 c6                	cmp    %eax,%esi
f0101a50:	74 24                	je     f0101a76 <mem_init+0x585>
f0101a52:	c7 44 24 0c 4d 73 10 	movl   $0xf010734d,0xc(%esp)
f0101a59:	f0 
f0101a5a:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101a61:	f0 
f0101a62:	c7 44 24 04 3b 03 00 	movl   $0x33b,0x4(%esp)
f0101a69:	00 
f0101a6a:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101a71:	e8 ca e5 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101a76:	89 f2                	mov    %esi,%edx
f0101a78:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0101a7e:	c1 fa 03             	sar    $0x3,%edx
f0101a81:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101a84:	89 d0                	mov    %edx,%eax
f0101a86:	c1 e8 0c             	shr    $0xc,%eax
f0101a89:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0101a8f:	72 20                	jb     f0101ab1 <mem_init+0x5c0>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101a91:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101a95:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f0101a9c:	f0 
f0101a9d:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101aa4:	00 
f0101aa5:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f0101aac:	e8 8f e5 ff ff       	call   f0100040 <_panic>
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
		assert(c[i] == 0);
f0101ab1:	80 ba 00 00 00 f0 00 	cmpb   $0x0,-0x10000000(%edx)
f0101ab8:	75 11                	jne    f0101acb <mem_init+0x5da>
f0101aba:	8d 82 01 00 00 f0    	lea    -0xfffffff(%edx),%eax
f0101ac0:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0101ac6:	80 38 00             	cmpb   $0x0,(%eax)
f0101ac9:	74 24                	je     f0101aef <mem_init+0x5fe>
f0101acb:	c7 44 24 0c 5d 73 10 	movl   $0xf010735d,0xc(%esp)
f0101ad2:	f0 
f0101ad3:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101ada:	f0 
f0101adb:	c7 44 24 04 3e 03 00 	movl   $0x33e,0x4(%esp)
f0101ae2:	00 
f0101ae3:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101aea:	e8 51 e5 ff ff       	call   f0100040 <_panic>
f0101aef:	83 c0 01             	add    $0x1,%eax
	memset(page2kva(pp0), 1, PGSIZE);
	page_free(pp0);
	assert((pp = page_alloc(ALLOC_ZERO)));
	assert(pp && pp0 == pp);
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
f0101af2:	39 d0                	cmp    %edx,%eax
f0101af4:	75 d0                	jne    f0101ac6 <mem_init+0x5d5>
		assert(c[i] == 0);

	// give free list back
	page_free_list = fl;
f0101af6:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101af9:	a3 40 32 22 f0       	mov    %eax,0xf0223240

	// free the pages we took
	page_free(pp0);
f0101afe:	89 34 24             	mov    %esi,(%esp)
f0101b01:	e8 75 f6 ff ff       	call   f010117b <page_free>
	page_free(pp1);
f0101b06:	89 3c 24             	mov    %edi,(%esp)
f0101b09:	e8 6d f6 ff ff       	call   f010117b <page_free>
	page_free(pp2);
f0101b0e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101b11:	89 04 24             	mov    %eax,(%esp)
f0101b14:	e8 62 f6 ff ff       	call   f010117b <page_free>

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101b19:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0101b1e:	85 c0                	test   %eax,%eax
f0101b20:	74 09                	je     f0101b2b <mem_init+0x63a>
		--nfree;
f0101b22:	83 eb 01             	sub    $0x1,%ebx
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101b25:	8b 00                	mov    (%eax),%eax
f0101b27:	85 c0                	test   %eax,%eax
f0101b29:	75 f7                	jne    f0101b22 <mem_init+0x631>
		--nfree;
	assert(nfree == 0);
f0101b2b:	85 db                	test   %ebx,%ebx
f0101b2d:	74 24                	je     f0101b53 <mem_init+0x662>
f0101b2f:	c7 44 24 0c 67 73 10 	movl   $0xf0107367,0xc(%esp)
f0101b36:	f0 
f0101b37:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101b3e:	f0 
f0101b3f:	c7 44 24 04 4b 03 00 	movl   $0x34b,0x4(%esp)
f0101b46:	00 
f0101b47:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101b4e:	e8 ed e4 ff ff       	call   f0100040 <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f0101b53:	c7 04 24 b0 6b 10 f0 	movl   $0xf0106bb0,(%esp)
f0101b5a:	e8 7f 23 00 00       	call   f0103ede <cprintf>
	int i;
	extern pde_t entry_pgdir[];

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101b5f:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b66:	e8 8b f5 ff ff       	call   f01010f6 <page_alloc>
f0101b6b:	89 c3                	mov    %eax,%ebx
f0101b6d:	85 c0                	test   %eax,%eax
f0101b6f:	75 24                	jne    f0101b95 <mem_init+0x6a4>
f0101b71:	c7 44 24 0c 75 72 10 	movl   $0xf0107275,0xc(%esp)
f0101b78:	f0 
f0101b79:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101b80:	f0 
f0101b81:	c7 44 24 04 b3 03 00 	movl   $0x3b3,0x4(%esp)
f0101b88:	00 
f0101b89:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101b90:	e8 ab e4 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101b95:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b9c:	e8 55 f5 ff ff       	call   f01010f6 <page_alloc>
f0101ba1:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101ba4:	85 c0                	test   %eax,%eax
f0101ba6:	75 24                	jne    f0101bcc <mem_init+0x6db>
f0101ba8:	c7 44 24 0c 8b 72 10 	movl   $0xf010728b,0xc(%esp)
f0101baf:	f0 
f0101bb0:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101bb7:	f0 
f0101bb8:	c7 44 24 04 b4 03 00 	movl   $0x3b4,0x4(%esp)
f0101bbf:	00 
f0101bc0:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101bc7:	e8 74 e4 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0101bcc:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101bd3:	e8 1e f5 ff ff       	call   f01010f6 <page_alloc>
f0101bd8:	89 c7                	mov    %eax,%edi
f0101bda:	85 c0                	test   %eax,%eax
f0101bdc:	75 24                	jne    f0101c02 <mem_init+0x711>
f0101bde:	c7 44 24 0c a1 72 10 	movl   $0xf01072a1,0xc(%esp)
f0101be5:	f0 
f0101be6:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101bed:	f0 
f0101bee:	c7 44 24 04 b5 03 00 	movl   $0x3b5,0x4(%esp)
f0101bf5:	00 
f0101bf6:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101bfd:	e8 3e e4 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101c02:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0101c05:	75 24                	jne    f0101c2b <mem_init+0x73a>
f0101c07:	c7 44 24 0c b7 72 10 	movl   $0xf01072b7,0xc(%esp)
f0101c0e:	f0 
f0101c0f:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101c16:	f0 
f0101c17:	c7 44 24 04 b8 03 00 	movl   $0x3b8,0x4(%esp)
f0101c1e:	00 
f0101c1f:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101c26:	e8 15 e4 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101c2b:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f0101c2e:	74 04                	je     f0101c34 <mem_init+0x743>
f0101c30:	39 c3                	cmp    %eax,%ebx
f0101c32:	75 24                	jne    f0101c58 <mem_init+0x767>
f0101c34:	c7 44 24 0c 90 6b 10 	movl   $0xf0106b90,0xc(%esp)
f0101c3b:	f0 
f0101c3c:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101c43:	f0 
f0101c44:	c7 44 24 04 b9 03 00 	movl   $0x3b9,0x4(%esp)
f0101c4b:	00 
f0101c4c:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101c53:	e8 e8 e3 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101c58:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0101c5d:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101c60:	c7 05 40 32 22 f0 00 	movl   $0x0,0xf0223240
f0101c67:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f0101c6a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101c71:	e8 80 f4 ff ff       	call   f01010f6 <page_alloc>
f0101c76:	85 c0                	test   %eax,%eax
f0101c78:	74 24                	je     f0101c9e <mem_init+0x7ad>
f0101c7a:	c7 44 24 0c 20 73 10 	movl   $0xf0107320,0xc(%esp)
f0101c81:	f0 
f0101c82:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101c89:	f0 
f0101c8a:	c7 44 24 04 c0 03 00 	movl   $0x3c0,0x4(%esp)
f0101c91:	00 
f0101c92:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101c99:	e8 a2 e3 ff ff       	call   f0100040 <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f0101c9e:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101ca1:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101ca5:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101cac:	00 
f0101cad:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101cb2:	89 04 24             	mov    %eax,(%esp)
f0101cb5:	e8 8b f6 ff ff       	call   f0101345 <page_lookup>
f0101cba:	85 c0                	test   %eax,%eax
f0101cbc:	74 24                	je     f0101ce2 <mem_init+0x7f1>
f0101cbe:	c7 44 24 0c d0 6b 10 	movl   $0xf0106bd0,0xc(%esp)
f0101cc5:	f0 
f0101cc6:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101ccd:	f0 
f0101cce:	c7 44 24 04 c3 03 00 	movl   $0x3c3,0x4(%esp)
f0101cd5:	00 
f0101cd6:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101cdd:	e8 5e e3 ff ff       	call   f0100040 <_panic>

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);
f0101ce2:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101ce9:	00 
f0101cea:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101cf1:	00 
f0101cf2:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101cf5:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101cf9:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101cfe:	89 04 24             	mov    %eax,(%esp)
f0101d01:	e8 2a f7 ff ff       	call   f0101430 <page_insert>
f0101d06:	85 c0                	test   %eax,%eax
f0101d08:	78 24                	js     f0101d2e <mem_init+0x83d>
f0101d0a:	c7 44 24 0c 08 6c 10 	movl   $0xf0106c08,0xc(%esp)
f0101d11:	f0 
f0101d12:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101d19:	f0 
f0101d1a:	c7 44 24 04 c6 03 00 	movl   $0x3c6,0x4(%esp)
f0101d21:	00 
f0101d22:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101d29:	e8 12 e3 ff ff       	call   f0100040 <_panic>

	// free pp0 and try again: pp0 should be used for page table
	page_free(pp0);
f0101d2e:	89 1c 24             	mov    %ebx,(%esp)
f0101d31:	e8 45 f4 ff ff       	call   f010117b <page_free>
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) == 0);
f0101d36:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101d3d:	00 
f0101d3e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101d45:	00 
f0101d46:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101d49:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101d4d:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101d52:	89 04 24             	mov    %eax,(%esp)
f0101d55:	e8 d6 f6 ff ff       	call   f0101430 <page_insert>
f0101d5a:	85 c0                	test   %eax,%eax
f0101d5c:	74 24                	je     f0101d82 <mem_init+0x891>
f0101d5e:	c7 44 24 0c 38 6c 10 	movl   $0xf0106c38,0xc(%esp)
f0101d65:	f0 
f0101d66:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101d6d:	f0 
f0101d6e:	c7 44 24 04 ca 03 00 	movl   $0x3ca,0x4(%esp)
f0101d75:	00 
f0101d76:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101d7d:	e8 be e2 ff ff       	call   f0100040 <_panic>
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101d82:	8b 35 8c 3e 22 f0    	mov    0xf0223e8c,%esi
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101d88:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
f0101d8d:	89 45 cc             	mov    %eax,-0x34(%ebp)
f0101d90:	8b 16                	mov    (%esi),%edx
f0101d92:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0101d98:	89 d9                	mov    %ebx,%ecx
f0101d9a:	29 c1                	sub    %eax,%ecx
f0101d9c:	89 c8                	mov    %ecx,%eax
f0101d9e:	c1 f8 03             	sar    $0x3,%eax
f0101da1:	c1 e0 0c             	shl    $0xc,%eax
f0101da4:	39 c2                	cmp    %eax,%edx
f0101da6:	74 24                	je     f0101dcc <mem_init+0x8db>
f0101da8:	c7 44 24 0c 68 6c 10 	movl   $0xf0106c68,0xc(%esp)
f0101daf:	f0 
f0101db0:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101db7:	f0 
f0101db8:	c7 44 24 04 cb 03 00 	movl   $0x3cb,0x4(%esp)
f0101dbf:	00 
f0101dc0:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101dc7:	e8 74 e2 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, 0x0) == page2pa(pp1));
f0101dcc:	ba 00 00 00 00       	mov    $0x0,%edx
f0101dd1:	89 f0                	mov    %esi,%eax
f0101dd3:	e8 cc ed ff ff       	call   f0100ba4 <check_va2pa>
f0101dd8:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101ddb:	2b 55 cc             	sub    -0x34(%ebp),%edx
f0101dde:	c1 fa 03             	sar    $0x3,%edx
f0101de1:	c1 e2 0c             	shl    $0xc,%edx
f0101de4:	39 d0                	cmp    %edx,%eax
f0101de6:	74 24                	je     f0101e0c <mem_init+0x91b>
f0101de8:	c7 44 24 0c 90 6c 10 	movl   $0xf0106c90,0xc(%esp)
f0101def:	f0 
f0101df0:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101df7:	f0 
f0101df8:	c7 44 24 04 cc 03 00 	movl   $0x3cc,0x4(%esp)
f0101dff:	00 
f0101e00:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101e07:	e8 34 e2 ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0101e0c:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101e0f:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101e14:	74 24                	je     f0101e3a <mem_init+0x949>
f0101e16:	c7 44 24 0c 72 73 10 	movl   $0xf0107372,0xc(%esp)
f0101e1d:	f0 
f0101e1e:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101e25:	f0 
f0101e26:	c7 44 24 04 cd 03 00 	movl   $0x3cd,0x4(%esp)
f0101e2d:	00 
f0101e2e:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101e35:	e8 06 e2 ff ff       	call   f0100040 <_panic>
	assert(pp0->pp_ref == 1);
f0101e3a:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0101e3f:	74 24                	je     f0101e65 <mem_init+0x974>
f0101e41:	c7 44 24 0c 83 73 10 	movl   $0xf0107383,0xc(%esp)
f0101e48:	f0 
f0101e49:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101e50:	f0 
f0101e51:	c7 44 24 04 ce 03 00 	movl   $0x3ce,0x4(%esp)
f0101e58:	00 
f0101e59:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101e60:	e8 db e1 ff ff       	call   f0100040 <_panic>

	// should be able to map pp2 at PGSIZE because pp0 is already allocated for page table
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101e65:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101e6c:	00 
f0101e6d:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101e74:	00 
f0101e75:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101e79:	89 34 24             	mov    %esi,(%esp)
f0101e7c:	e8 af f5 ff ff       	call   f0101430 <page_insert>
f0101e81:	85 c0                	test   %eax,%eax
f0101e83:	74 24                	je     f0101ea9 <mem_init+0x9b8>
f0101e85:	c7 44 24 0c c0 6c 10 	movl   $0xf0106cc0,0xc(%esp)
f0101e8c:	f0 
f0101e8d:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101e94:	f0 
f0101e95:	c7 44 24 04 d1 03 00 	movl   $0x3d1,0x4(%esp)
f0101e9c:	00 
f0101e9d:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101ea4:	e8 97 e1 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101ea9:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101eae:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101eb3:	e8 ec ec ff ff       	call   f0100ba4 <check_va2pa>
f0101eb8:	89 fa                	mov    %edi,%edx
f0101eba:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0101ec0:	c1 fa 03             	sar    $0x3,%edx
f0101ec3:	c1 e2 0c             	shl    $0xc,%edx
f0101ec6:	39 d0                	cmp    %edx,%eax
f0101ec8:	74 24                	je     f0101eee <mem_init+0x9fd>
f0101eca:	c7 44 24 0c fc 6c 10 	movl   $0xf0106cfc,0xc(%esp)
f0101ed1:	f0 
f0101ed2:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101ed9:	f0 
f0101eda:	c7 44 24 04 d2 03 00 	movl   $0x3d2,0x4(%esp)
f0101ee1:	00 
f0101ee2:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101ee9:	e8 52 e1 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101eee:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0101ef3:	74 24                	je     f0101f19 <mem_init+0xa28>
f0101ef5:	c7 44 24 0c 94 73 10 	movl   $0xf0107394,0xc(%esp)
f0101efc:	f0 
f0101efd:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101f04:	f0 
f0101f05:	c7 44 24 04 d3 03 00 	movl   $0x3d3,0x4(%esp)
f0101f0c:	00 
f0101f0d:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101f14:	e8 27 e1 ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0101f19:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101f20:	e8 d1 f1 ff ff       	call   f01010f6 <page_alloc>
f0101f25:	85 c0                	test   %eax,%eax
f0101f27:	74 24                	je     f0101f4d <mem_init+0xa5c>
f0101f29:	c7 44 24 0c 20 73 10 	movl   $0xf0107320,0xc(%esp)
f0101f30:	f0 
f0101f31:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101f38:	f0 
f0101f39:	c7 44 24 04 d6 03 00 	movl   $0x3d6,0x4(%esp)
f0101f40:	00 
f0101f41:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101f48:	e8 f3 e0 ff ff       	call   f0100040 <_panic>

	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101f4d:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101f54:	00 
f0101f55:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101f5c:	00 
f0101f5d:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101f61:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101f66:	89 04 24             	mov    %eax,(%esp)
f0101f69:	e8 c2 f4 ff ff       	call   f0101430 <page_insert>
f0101f6e:	85 c0                	test   %eax,%eax
f0101f70:	74 24                	je     f0101f96 <mem_init+0xaa5>
f0101f72:	c7 44 24 0c c0 6c 10 	movl   $0xf0106cc0,0xc(%esp)
f0101f79:	f0 
f0101f7a:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101f81:	f0 
f0101f82:	c7 44 24 04 d9 03 00 	movl   $0x3d9,0x4(%esp)
f0101f89:	00 
f0101f8a:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101f91:	e8 aa e0 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101f96:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101f9b:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101fa0:	e8 ff eb ff ff       	call   f0100ba4 <check_va2pa>
f0101fa5:	89 fa                	mov    %edi,%edx
f0101fa7:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0101fad:	c1 fa 03             	sar    $0x3,%edx
f0101fb0:	c1 e2 0c             	shl    $0xc,%edx
f0101fb3:	39 d0                	cmp    %edx,%eax
f0101fb5:	74 24                	je     f0101fdb <mem_init+0xaea>
f0101fb7:	c7 44 24 0c fc 6c 10 	movl   $0xf0106cfc,0xc(%esp)
f0101fbe:	f0 
f0101fbf:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101fc6:	f0 
f0101fc7:	c7 44 24 04 da 03 00 	movl   $0x3da,0x4(%esp)
f0101fce:	00 
f0101fcf:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0101fd6:	e8 65 e0 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101fdb:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0101fe0:	74 24                	je     f0102006 <mem_init+0xb15>
f0101fe2:	c7 44 24 0c 94 73 10 	movl   $0xf0107394,0xc(%esp)
f0101fe9:	f0 
f0101fea:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0101ff1:	f0 
f0101ff2:	c7 44 24 04 db 03 00 	movl   $0x3db,0x4(%esp)
f0101ff9:	00 
f0101ffa:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102001:	e8 3a e0 ff ff       	call   f0100040 <_panic>

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));
f0102006:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010200d:	e8 e4 f0 ff ff       	call   f01010f6 <page_alloc>
f0102012:	85 c0                	test   %eax,%eax
f0102014:	74 24                	je     f010203a <mem_init+0xb49>
f0102016:	c7 44 24 0c 20 73 10 	movl   $0xf0107320,0xc(%esp)
f010201d:	f0 
f010201e:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102025:	f0 
f0102026:	c7 44 24 04 df 03 00 	movl   $0x3df,0x4(%esp)
f010202d:	00 
f010202e:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102035:	e8 06 e0 ff ff       	call   f0100040 <_panic>

	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f010203a:	8b 15 8c 3e 22 f0    	mov    0xf0223e8c,%edx
f0102040:	8b 02                	mov    (%edx),%eax
f0102042:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102047:	89 c1                	mov    %eax,%ecx
f0102049:	c1 e9 0c             	shr    $0xc,%ecx
f010204c:	3b 0d 88 3e 22 f0    	cmp    0xf0223e88,%ecx
f0102052:	72 20                	jb     f0102074 <mem_init+0xb83>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102054:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102058:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f010205f:	f0 
f0102060:	c7 44 24 04 e2 03 00 	movl   $0x3e2,0x4(%esp)
f0102067:	00 
f0102068:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010206f:	e8 cc df ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0102074:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102079:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	assert(pgdir_walk(kern_pgdir, (void*)PGSIZE, 0) == ptep+PTX(PGSIZE));
f010207c:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102083:	00 
f0102084:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f010208b:	00 
f010208c:	89 14 24             	mov    %edx,(%esp)
f010208f:	e8 1f f1 ff ff       	call   f01011b3 <pgdir_walk>
f0102094:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0102097:	8d 51 04             	lea    0x4(%ecx),%edx
f010209a:	39 d0                	cmp    %edx,%eax
f010209c:	74 24                	je     f01020c2 <mem_init+0xbd1>
f010209e:	c7 44 24 0c 2c 6d 10 	movl   $0xf0106d2c,0xc(%esp)
f01020a5:	f0 
f01020a6:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01020ad:	f0 
f01020ae:	c7 44 24 04 e3 03 00 	movl   $0x3e3,0x4(%esp)
f01020b5:	00 
f01020b6:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01020bd:	e8 7e df ff ff       	call   f0100040 <_panic>

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
f01020c2:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01020c9:	00 
f01020ca:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01020d1:	00 
f01020d2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01020d6:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01020db:	89 04 24             	mov    %eax,(%esp)
f01020de:	e8 4d f3 ff ff       	call   f0101430 <page_insert>
f01020e3:	85 c0                	test   %eax,%eax
f01020e5:	74 24                	je     f010210b <mem_init+0xc1a>
f01020e7:	c7 44 24 0c 6c 6d 10 	movl   $0xf0106d6c,0xc(%esp)
f01020ee:	f0 
f01020ef:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01020f6:	f0 
f01020f7:	c7 44 24 04 e6 03 00 	movl   $0x3e6,0x4(%esp)
f01020fe:	00 
f01020ff:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102106:	e8 35 df ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f010210b:	8b 35 8c 3e 22 f0    	mov    0xf0223e8c,%esi
f0102111:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102116:	89 f0                	mov    %esi,%eax
f0102118:	e8 87 ea ff ff       	call   f0100ba4 <check_va2pa>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010211d:	89 fa                	mov    %edi,%edx
f010211f:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0102125:	c1 fa 03             	sar    $0x3,%edx
f0102128:	c1 e2 0c             	shl    $0xc,%edx
f010212b:	39 d0                	cmp    %edx,%eax
f010212d:	74 24                	je     f0102153 <mem_init+0xc62>
f010212f:	c7 44 24 0c fc 6c 10 	movl   $0xf0106cfc,0xc(%esp)
f0102136:	f0 
f0102137:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010213e:	f0 
f010213f:	c7 44 24 04 e7 03 00 	movl   $0x3e7,0x4(%esp)
f0102146:	00 
f0102147:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010214e:	e8 ed de ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0102153:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0102158:	74 24                	je     f010217e <mem_init+0xc8d>
f010215a:	c7 44 24 0c 94 73 10 	movl   $0xf0107394,0xc(%esp)
f0102161:	f0 
f0102162:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102169:	f0 
f010216a:	c7 44 24 04 e8 03 00 	movl   $0x3e8,0x4(%esp)
f0102171:	00 
f0102172:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102179:	e8 c2 de ff ff       	call   f0100040 <_panic>
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U);
f010217e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102185:	00 
f0102186:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f010218d:	00 
f010218e:	89 34 24             	mov    %esi,(%esp)
f0102191:	e8 1d f0 ff ff       	call   f01011b3 <pgdir_walk>
f0102196:	f6 00 04             	testb  $0x4,(%eax)
f0102199:	75 24                	jne    f01021bf <mem_init+0xcce>
f010219b:	c7 44 24 0c ac 6d 10 	movl   $0xf0106dac,0xc(%esp)
f01021a2:	f0 
f01021a3:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01021aa:	f0 
f01021ab:	c7 44 24 04 e9 03 00 	movl   $0x3e9,0x4(%esp)
f01021b2:	00 
f01021b3:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01021ba:	e8 81 de ff ff       	call   f0100040 <_panic>
	assert(kern_pgdir[0] & PTE_U);
f01021bf:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01021c4:	f6 00 04             	testb  $0x4,(%eax)
f01021c7:	75 24                	jne    f01021ed <mem_init+0xcfc>
f01021c9:	c7 44 24 0c a5 73 10 	movl   $0xf01073a5,0xc(%esp)
f01021d0:	f0 
f01021d1:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01021d8:	f0 
f01021d9:	c7 44 24 04 ea 03 00 	movl   $0x3ea,0x4(%esp)
f01021e0:	00 
f01021e1:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01021e8:	e8 53 de ff ff       	call   f0100040 <_panic>

	// should not be able to map at PTSIZE because need free page for page table
	assert(page_insert(kern_pgdir, pp0, (void*) PTSIZE, PTE_W) < 0);
f01021ed:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01021f4:	00 
f01021f5:	c7 44 24 08 00 00 40 	movl   $0x400000,0x8(%esp)
f01021fc:	00 
f01021fd:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0102201:	89 04 24             	mov    %eax,(%esp)
f0102204:	e8 27 f2 ff ff       	call   f0101430 <page_insert>
f0102209:	85 c0                	test   %eax,%eax
f010220b:	78 24                	js     f0102231 <mem_init+0xd40>
f010220d:	c7 44 24 0c e0 6d 10 	movl   $0xf0106de0,0xc(%esp)
f0102214:	f0 
f0102215:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010221c:	f0 
f010221d:	c7 44 24 04 ed 03 00 	movl   $0x3ed,0x4(%esp)
f0102224:	00 
f0102225:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010222c:	e8 0f de ff ff       	call   f0100040 <_panic>

	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
f0102231:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102238:	00 
f0102239:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102240:	00 
f0102241:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102244:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102248:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f010224d:	89 04 24             	mov    %eax,(%esp)
f0102250:	e8 db f1 ff ff       	call   f0101430 <page_insert>
f0102255:	85 c0                	test   %eax,%eax
f0102257:	74 24                	je     f010227d <mem_init+0xd8c>
f0102259:	c7 44 24 0c 18 6e 10 	movl   $0xf0106e18,0xc(%esp)
f0102260:	f0 
f0102261:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102268:	f0 
f0102269:	c7 44 24 04 f0 03 00 	movl   $0x3f0,0x4(%esp)
f0102270:	00 
f0102271:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102278:	e8 c3 dd ff ff       	call   f0100040 <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f010227d:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102284:	00 
f0102285:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f010228c:	00 
f010228d:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102292:	89 04 24             	mov    %eax,(%esp)
f0102295:	e8 19 ef ff ff       	call   f01011b3 <pgdir_walk>
f010229a:	f6 00 04             	testb  $0x4,(%eax)
f010229d:	74 24                	je     f01022c3 <mem_init+0xdd2>
f010229f:	c7 44 24 0c 54 6e 10 	movl   $0xf0106e54,0xc(%esp)
f01022a6:	f0 
f01022a7:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01022ae:	f0 
f01022af:	c7 44 24 04 f1 03 00 	movl   $0x3f1,0x4(%esp)
f01022b6:	00 
f01022b7:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01022be:	e8 7d dd ff ff       	call   f0100040 <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f01022c3:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01022c8:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01022cb:	ba 00 00 00 00       	mov    $0x0,%edx
f01022d0:	e8 cf e8 ff ff       	call   f0100ba4 <check_va2pa>
f01022d5:	89 c6                	mov    %eax,%esi
f01022d7:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01022da:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f01022e0:	c1 f8 03             	sar    $0x3,%eax
f01022e3:	c1 e0 0c             	shl    $0xc,%eax
f01022e6:	39 c6                	cmp    %eax,%esi
f01022e8:	74 24                	je     f010230e <mem_init+0xe1d>
f01022ea:	c7 44 24 0c 8c 6e 10 	movl   $0xf0106e8c,0xc(%esp)
f01022f1:	f0 
f01022f2:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01022f9:	f0 
f01022fa:	c7 44 24 04 f4 03 00 	movl   $0x3f4,0x4(%esp)
f0102301:	00 
f0102302:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102309:	e8 32 dd ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f010230e:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102313:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0102316:	e8 89 e8 ff ff       	call   f0100ba4 <check_va2pa>
f010231b:	39 c6                	cmp    %eax,%esi
f010231d:	74 24                	je     f0102343 <mem_init+0xe52>
f010231f:	c7 44 24 0c b8 6e 10 	movl   $0xf0106eb8,0xc(%esp)
f0102326:	f0 
f0102327:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010232e:	f0 
f010232f:	c7 44 24 04 f5 03 00 	movl   $0x3f5,0x4(%esp)
f0102336:	00 
f0102337:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010233e:	e8 fd dc ff ff       	call   f0100040 <_panic>
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
f0102343:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102346:	66 83 78 04 02       	cmpw   $0x2,0x4(%eax)
f010234b:	74 24                	je     f0102371 <mem_init+0xe80>
f010234d:	c7 44 24 0c bb 73 10 	movl   $0xf01073bb,0xc(%esp)
f0102354:	f0 
f0102355:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010235c:	f0 
f010235d:	c7 44 24 04 f7 03 00 	movl   $0x3f7,0x4(%esp)
f0102364:	00 
f0102365:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010236c:	e8 cf dc ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f0102371:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f0102376:	74 24                	je     f010239c <mem_init+0xeab>
f0102378:	c7 44 24 0c cc 73 10 	movl   $0xf01073cc,0xc(%esp)
f010237f:	f0 
f0102380:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102387:	f0 
f0102388:	c7 44 24 04 f8 03 00 	movl   $0x3f8,0x4(%esp)
f010238f:	00 
f0102390:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102397:	e8 a4 dc ff ff       	call   f0100040 <_panic>

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);
f010239c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01023a3:	e8 4e ed ff ff       	call   f01010f6 <page_alloc>
f01023a8:	85 c0                	test   %eax,%eax
f01023aa:	74 04                	je     f01023b0 <mem_init+0xebf>
f01023ac:	39 c7                	cmp    %eax,%edi
f01023ae:	74 24                	je     f01023d4 <mem_init+0xee3>
f01023b0:	c7 44 24 0c e8 6e 10 	movl   $0xf0106ee8,0xc(%esp)
f01023b7:	f0 
f01023b8:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01023bf:	f0 
f01023c0:	c7 44 24 04 fb 03 00 	movl   $0x3fb,0x4(%esp)
f01023c7:	00 
f01023c8:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01023cf:	e8 6c dc ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f01023d4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01023db:	00 
f01023dc:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01023e1:	89 04 24             	mov    %eax,(%esp)
f01023e4:	e8 fe ef ff ff       	call   f01013e7 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01023e9:	8b 35 8c 3e 22 f0    	mov    0xf0223e8c,%esi
f01023ef:	ba 00 00 00 00       	mov    $0x0,%edx
f01023f4:	89 f0                	mov    %esi,%eax
f01023f6:	e8 a9 e7 ff ff       	call   f0100ba4 <check_va2pa>
f01023fb:	83 f8 ff             	cmp    $0xffffffff,%eax
f01023fe:	74 24                	je     f0102424 <mem_init+0xf33>
f0102400:	c7 44 24 0c 0c 6f 10 	movl   $0xf0106f0c,0xc(%esp)
f0102407:	f0 
f0102408:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010240f:	f0 
f0102410:	c7 44 24 04 ff 03 00 	movl   $0x3ff,0x4(%esp)
f0102417:	00 
f0102418:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010241f:	e8 1c dc ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102424:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102429:	89 f0                	mov    %esi,%eax
f010242b:	e8 74 e7 ff ff       	call   f0100ba4 <check_va2pa>
f0102430:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0102433:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0102439:	c1 fa 03             	sar    $0x3,%edx
f010243c:	c1 e2 0c             	shl    $0xc,%edx
f010243f:	39 d0                	cmp    %edx,%eax
f0102441:	74 24                	je     f0102467 <mem_init+0xf76>
f0102443:	c7 44 24 0c b8 6e 10 	movl   $0xf0106eb8,0xc(%esp)
f010244a:	f0 
f010244b:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102452:	f0 
f0102453:	c7 44 24 04 00 04 00 	movl   $0x400,0x4(%esp)
f010245a:	00 
f010245b:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102462:	e8 d9 db ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0102467:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010246a:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f010246f:	74 24                	je     f0102495 <mem_init+0xfa4>
f0102471:	c7 44 24 0c 72 73 10 	movl   $0xf0107372,0xc(%esp)
f0102478:	f0 
f0102479:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102480:	f0 
f0102481:	c7 44 24 04 01 04 00 	movl   $0x401,0x4(%esp)
f0102488:	00 
f0102489:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102490:	e8 ab db ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f0102495:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f010249a:	74 24                	je     f01024c0 <mem_init+0xfcf>
f010249c:	c7 44 24 0c cc 73 10 	movl   $0xf01073cc,0xc(%esp)
f01024a3:	f0 
f01024a4:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01024ab:	f0 
f01024ac:	c7 44 24 04 02 04 00 	movl   $0x402,0x4(%esp)
f01024b3:	00 
f01024b4:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01024bb:	e8 80 db ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
f01024c0:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01024c7:	00 
f01024c8:	89 34 24             	mov    %esi,(%esp)
f01024cb:	e8 17 ef ff ff       	call   f01013e7 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01024d0:	8b 35 8c 3e 22 f0    	mov    0xf0223e8c,%esi
f01024d6:	ba 00 00 00 00       	mov    $0x0,%edx
f01024db:	89 f0                	mov    %esi,%eax
f01024dd:	e8 c2 e6 ff ff       	call   f0100ba4 <check_va2pa>
f01024e2:	83 f8 ff             	cmp    $0xffffffff,%eax
f01024e5:	74 24                	je     f010250b <mem_init+0x101a>
f01024e7:	c7 44 24 0c 0c 6f 10 	movl   $0xf0106f0c,0xc(%esp)
f01024ee:	f0 
f01024ef:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01024f6:	f0 
f01024f7:	c7 44 24 04 06 04 00 	movl   $0x406,0x4(%esp)
f01024fe:	00 
f01024ff:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102506:	e8 35 db ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
f010250b:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102510:	89 f0                	mov    %esi,%eax
f0102512:	e8 8d e6 ff ff       	call   f0100ba4 <check_va2pa>
f0102517:	83 f8 ff             	cmp    $0xffffffff,%eax
f010251a:	74 24                	je     f0102540 <mem_init+0x104f>
f010251c:	c7 44 24 0c 30 6f 10 	movl   $0xf0106f30,0xc(%esp)
f0102523:	f0 
f0102524:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010252b:	f0 
f010252c:	c7 44 24 04 07 04 00 	movl   $0x407,0x4(%esp)
f0102533:	00 
f0102534:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010253b:	e8 00 db ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f0102540:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102543:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102548:	74 24                	je     f010256e <mem_init+0x107d>
f010254a:	c7 44 24 0c dd 73 10 	movl   $0xf01073dd,0xc(%esp)
f0102551:	f0 
f0102552:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102559:	f0 
f010255a:	c7 44 24 04 08 04 00 	movl   $0x408,0x4(%esp)
f0102561:	00 
f0102562:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102569:	e8 d2 da ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f010256e:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f0102573:	74 24                	je     f0102599 <mem_init+0x10a8>
f0102575:	c7 44 24 0c cc 73 10 	movl   $0xf01073cc,0xc(%esp)
f010257c:	f0 
f010257d:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102584:	f0 
f0102585:	c7 44 24 04 09 04 00 	movl   $0x409,0x4(%esp)
f010258c:	00 
f010258d:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102594:	e8 a7 da ff ff       	call   f0100040 <_panic>

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);
f0102599:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01025a0:	e8 51 eb ff ff       	call   f01010f6 <page_alloc>
f01025a5:	85 c0                	test   %eax,%eax
f01025a7:	74 05                	je     f01025ae <mem_init+0x10bd>
f01025a9:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f01025ac:	74 24                	je     f01025d2 <mem_init+0x10e1>
f01025ae:	c7 44 24 0c 58 6f 10 	movl   $0xf0106f58,0xc(%esp)
f01025b5:	f0 
f01025b6:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01025bd:	f0 
f01025be:	c7 44 24 04 0c 04 00 	movl   $0x40c,0x4(%esp)
f01025c5:	00 
f01025c6:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01025cd:	e8 6e da ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f01025d2:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01025d9:	e8 18 eb ff ff       	call   f01010f6 <page_alloc>
f01025de:	85 c0                	test   %eax,%eax
f01025e0:	74 24                	je     f0102606 <mem_init+0x1115>
f01025e2:	c7 44 24 0c 20 73 10 	movl   $0xf0107320,0xc(%esp)
f01025e9:	f0 
f01025ea:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01025f1:	f0 
f01025f2:	c7 44 24 04 0f 04 00 	movl   $0x40f,0x4(%esp)
f01025f9:	00 
f01025fa:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102601:	e8 3a da ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102606:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f010260b:	8b 08                	mov    (%eax),%ecx
f010260d:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f0102613:	89 da                	mov    %ebx,%edx
f0102615:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f010261b:	c1 fa 03             	sar    $0x3,%edx
f010261e:	c1 e2 0c             	shl    $0xc,%edx
f0102621:	39 d1                	cmp    %edx,%ecx
f0102623:	74 24                	je     f0102649 <mem_init+0x1158>
f0102625:	c7 44 24 0c 68 6c 10 	movl   $0xf0106c68,0xc(%esp)
f010262c:	f0 
f010262d:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102634:	f0 
f0102635:	c7 44 24 04 12 04 00 	movl   $0x412,0x4(%esp)
f010263c:	00 
f010263d:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102644:	e8 f7 d9 ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f0102649:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f010264f:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102654:	74 24                	je     f010267a <mem_init+0x1189>
f0102656:	c7 44 24 0c 83 73 10 	movl   $0xf0107383,0xc(%esp)
f010265d:	f0 
f010265e:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102665:	f0 
f0102666:	c7 44 24 04 14 04 00 	movl   $0x414,0x4(%esp)
f010266d:	00 
f010266e:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102675:	e8 c6 d9 ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f010267a:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// check pointer arithmetic in pgdir_walk
	page_free(pp0);
f0102680:	89 1c 24             	mov    %ebx,(%esp)
f0102683:	e8 f3 ea ff ff       	call   f010117b <page_free>
	va = (void*)(PGSIZE * NPDENTRIES + PGSIZE);
	ptep = pgdir_walk(kern_pgdir, va, 1);
f0102688:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010268f:	00 
f0102690:	c7 44 24 04 00 10 40 	movl   $0x401000,0x4(%esp)
f0102697:	00 
f0102698:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f010269d:	89 04 24             	mov    %eax,(%esp)
f01026a0:	e8 0e eb ff ff       	call   f01011b3 <pgdir_walk>
f01026a5:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01026a8:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f01026ab:	8b 0d 8c 3e 22 f0    	mov    0xf0223e8c,%ecx
f01026b1:	8b 51 04             	mov    0x4(%ecx),%edx
f01026b4:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01026ba:	8b 35 88 3e 22 f0    	mov    0xf0223e88,%esi
f01026c0:	89 d0                	mov    %edx,%eax
f01026c2:	c1 e8 0c             	shr    $0xc,%eax
f01026c5:	39 f0                	cmp    %esi,%eax
f01026c7:	72 20                	jb     f01026e9 <mem_init+0x11f8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01026c9:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01026cd:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f01026d4:	f0 
f01026d5:	c7 44 24 04 1b 04 00 	movl   $0x41b,0x4(%esp)
f01026dc:	00 
f01026dd:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01026e4:	e8 57 d9 ff ff       	call   f0100040 <_panic>
	assert(ptep == ptep1 + PTX(va));
f01026e9:	81 ea fc ff ff 0f    	sub    $0xffffffc,%edx
f01026ef:	39 55 cc             	cmp    %edx,-0x34(%ebp)
f01026f2:	74 24                	je     f0102718 <mem_init+0x1227>
f01026f4:	c7 44 24 0c ee 73 10 	movl   $0xf01073ee,0xc(%esp)
f01026fb:	f0 
f01026fc:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102703:	f0 
f0102704:	c7 44 24 04 1c 04 00 	movl   $0x41c,0x4(%esp)
f010270b:	00 
f010270c:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102713:	e8 28 d9 ff ff       	call   f0100040 <_panic>
	kern_pgdir[PDX(va)] = 0;
f0102718:	c7 41 04 00 00 00 00 	movl   $0x0,0x4(%ecx)
	pp0->pp_ref = 0;
f010271f:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102725:	89 d8                	mov    %ebx,%eax
f0102727:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f010272d:	c1 f8 03             	sar    $0x3,%eax
f0102730:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102733:	89 c2                	mov    %eax,%edx
f0102735:	c1 ea 0c             	shr    $0xc,%edx
f0102738:	39 d6                	cmp    %edx,%esi
f010273a:	77 20                	ja     f010275c <mem_init+0x126b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010273c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102740:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f0102747:	f0 
f0102748:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010274f:	00 
f0102750:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f0102757:	e8 e4 d8 ff ff       	call   f0100040 <_panic>

	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
f010275c:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102763:	00 
f0102764:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
f010276b:	00 
	return (void *)(pa + KERNBASE);
f010276c:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102771:	89 04 24             	mov    %eax,(%esp)
f0102774:	e8 20 2f 00 00       	call   f0105699 <memset>
	page_free(pp0);
f0102779:	89 1c 24             	mov    %ebx,(%esp)
f010277c:	e8 fa e9 ff ff       	call   f010117b <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f0102781:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0102788:	00 
f0102789:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0102790:	00 
f0102791:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102796:	89 04 24             	mov    %eax,(%esp)
f0102799:	e8 15 ea ff ff       	call   f01011b3 <pgdir_walk>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010279e:	89 da                	mov    %ebx,%edx
f01027a0:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f01027a6:	c1 fa 03             	sar    $0x3,%edx
f01027a9:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01027ac:	89 d0                	mov    %edx,%eax
f01027ae:	c1 e8 0c             	shr    $0xc,%eax
f01027b1:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f01027b7:	72 20                	jb     f01027d9 <mem_init+0x12e8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01027b9:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01027bd:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f01027c4:	f0 
f01027c5:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01027cc:	00 
f01027cd:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f01027d4:	e8 67 d8 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01027d9:	8d 82 00 00 00 f0    	lea    -0x10000000(%edx),%eax
	ptep = (pte_t *) page2kva(pp0);
f01027df:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	for(i=0; i<NPTENTRIES; i++)
		assert((ptep[i] & PTE_P) == 0);
f01027e2:	f6 82 00 00 00 f0 01 	testb  $0x1,-0x10000000(%edx)
f01027e9:	75 13                	jne    f01027fe <mem_init+0x130d>
f01027eb:	8d 82 04 00 00 f0    	lea    -0xffffffc(%edx),%eax
f01027f1:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f01027f7:	8b 30                	mov    (%eax),%esi
f01027f9:	83 e6 01             	and    $0x1,%esi
f01027fc:	74 24                	je     f0102822 <mem_init+0x1331>
f01027fe:	c7 44 24 0c 06 74 10 	movl   $0xf0107406,0xc(%esp)
f0102805:	f0 
f0102806:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010280d:	f0 
f010280e:	c7 44 24 04 26 04 00 	movl   $0x426,0x4(%esp)
f0102815:	00 
f0102816:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010281d:	e8 1e d8 ff ff       	call   f0100040 <_panic>
f0102822:	83 c0 04             	add    $0x4,%eax
	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
	page_free(pp0);
	pgdir_walk(kern_pgdir, 0x0, 1);
	ptep = (pte_t *) page2kva(pp0);
	for(i=0; i<NPTENTRIES; i++)
f0102825:	39 d0                	cmp    %edx,%eax
f0102827:	75 ce                	jne    f01027f7 <mem_init+0x1306>
		assert((ptep[i] & PTE_P) == 0);
	kern_pgdir[0] = 0;
f0102829:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f010282e:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f0102834:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// give free list back
	page_free_list = fl;
f010283a:	8b 45 d0             	mov    -0x30(%ebp),%eax
f010283d:	a3 40 32 22 f0       	mov    %eax,0xf0223240

	// free the pages we took
	page_free(pp0);
f0102842:	89 1c 24             	mov    %ebx,(%esp)
f0102845:	e8 31 e9 ff ff       	call   f010117b <page_free>
	page_free(pp1);
f010284a:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010284d:	89 04 24             	mov    %eax,(%esp)
f0102850:	e8 26 e9 ff ff       	call   f010117b <page_free>
	page_free(pp2);
f0102855:	89 3c 24             	mov    %edi,(%esp)
f0102858:	e8 1e e9 ff ff       	call   f010117b <page_free>

	cprintf("check_page() succeeded!\n");
f010285d:	c7 04 24 1d 74 10 f0 	movl   $0xf010741d,(%esp)
f0102864:	e8 75 16 00 00       	call   f0103ede <cprintf>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t to_map_pages;
	to_map_pages = (sizeof(struct Page) * npages - 1) / PGSIZE + 1;
f0102869:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f010286e:	8d 0c c5 ff ff ff ff 	lea    -0x1(,%eax,8),%ecx
f0102875:	c1 e9 0c             	shr    $0xc,%ecx
f0102878:	83 c1 01             	add    $0x1,%ecx
	boot_map_region(kern_pgdir, UPAGES, to_map_pages * PGSIZE, PADDR(pages), PTE_U | PTE_P);
f010287b:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102880:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102885:	77 20                	ja     f01028a7 <mem_init+0x13b6>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102887:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010288b:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f0102892:	f0 
f0102893:	c7 44 24 04 be 00 00 	movl   $0xbe,0x4(%esp)
f010289a:	00 
f010289b:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01028a2:	e8 99 d7 ff ff       	call   f0100040 <_panic>
f01028a7:	c1 e1 0c             	shl    $0xc,%ecx
f01028aa:	c7 44 24 04 05 00 00 	movl   $0x5,0x4(%esp)
f01028b1:	00 
	return (physaddr_t)kva - KERNBASE;
f01028b2:	05 00 00 00 10       	add    $0x10000000,%eax
f01028b7:	89 04 24             	mov    %eax,(%esp)
f01028ba:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f01028bf:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01028c4:	e8 f4 e9 ff ff       	call   f01012bd <boot_map_region>
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	size_t i;
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		page_insert(kern_pgdir,pa2page(PADDR(envs)+i),(void *)(UENVS + i),PTE_U| PTE_P);
f01028c9:	a1 48 32 22 f0       	mov    0xf0223248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01028ce:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01028d3:	76 28                	jbe    f01028fd <mem_init+0x140c>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f01028d5:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01028da:	c1 e8 0c             	shr    $0xc,%eax
f01028dd:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f01028e3:	0f 82 ec 0a 00 00    	jb     f01033d5 <mem_init+0x1ee4>
f01028e9:	eb 44                	jmp    f010292f <mem_init+0x143e>
f01028eb:	8d 93 00 00 c0 ee    	lea    -0x11400000(%ebx),%edx
f01028f1:	a1 48 32 22 f0       	mov    0xf0223248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01028f6:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01028fb:	77 20                	ja     f010291d <mem_init+0x142c>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01028fd:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102901:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f0102908:	f0 
f0102909:	c7 44 24 04 c9 00 00 	movl   $0xc9,0x4(%esp)
f0102910:	00 
f0102911:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102918:	e8 23 d7 ff ff       	call   f0100040 <_panic>
f010291d:	8d 84 18 00 00 00 10 	lea    0x10000000(%eax,%ebx,1),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102924:	c1 e8 0c             	shr    $0xc,%eax
f0102927:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f010292d:	72 1c                	jb     f010294b <mem_init+0x145a>
		panic("pa2page called with invalid pa");
f010292f:	c7 44 24 08 34 6b 10 	movl   $0xf0106b34,0x8(%esp)
f0102936:	f0 
f0102937:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010293e:	00 
f010293f:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f0102946:	e8 f5 d6 ff ff       	call   f0100040 <_panic>
f010294b:	c7 44 24 0c 05 00 00 	movl   $0x5,0xc(%esp)
f0102952:	00 
f0102953:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102957:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f010295d:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102960:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102964:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102969:	89 04 24             	mov    %eax,(%esp)
f010296c:	e8 bf ea ff ff       	call   f0101430 <page_insert>
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	size_t i;
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f0102971:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102977:	81 fb 00 f0 01 00    	cmp    $0x1f000,%ebx
f010297d:	0f 85 68 ff ff ff    	jne    f01028eb <mem_init+0x13fa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102983:	bb 00 60 11 f0       	mov    $0xf0116000,%ebx
f0102988:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f010298e:	76 28                	jbe    f01029b8 <mem_init+0x14c7>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102990:	b8 00 60 11 00       	mov    $0x116000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102995:	c1 e8 0c             	shr    $0xc,%eax
f0102998:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f010299e:	0f 82 f4 09 00 00    	jb     f0103398 <mem_init+0x1ea7>
f01029a4:	eb 36                	jmp    f01029dc <mem_init+0x14eb>
f01029a6:	8d 14 3b             	lea    (%ebx,%edi,1),%edx
f01029a9:	89 f8                	mov    %edi,%eax
f01029ab:	c1 e8 0c             	shr    $0xc,%eax
f01029ae:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f01029b4:	72 42                	jb     f01029f8 <mem_init+0x1507>
f01029b6:	eb 24                	jmp    f01029dc <mem_init+0x14eb>

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01029b8:	c7 44 24 0c 00 60 11 	movl   $0xf0116000,0xc(%esp)
f01029bf:	f0 
f01029c0:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f01029c7:	f0 
f01029c8:	c7 44 24 04 d6 00 00 	movl   $0xd6,0x4(%esp)
f01029cf:	00 
f01029d0:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01029d7:	e8 64 d6 ff ff       	call   f0100040 <_panic>

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
f01029dc:	c7 44 24 08 34 6b 10 	movl   $0xf0106b34,0x8(%esp)
f01029e3:	f0 
f01029e4:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01029eb:	00 
f01029ec:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f01029f3:	e8 48 d6 ff ff       	call   f0100040 <_panic>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		page_insert(kern_pgdir, pa2page(PADDR(bootstack) + i), (void *)(KSTACKTOP-KSTKSIZE + i), PTE_W| PTE_P);
f01029f8:	c7 44 24 0c 03 00 00 	movl   $0x3,0xc(%esp)
f01029ff:	00 
f0102a00:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102a04:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f0102a0a:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102a0d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102a11:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102a16:	89 04 24             	mov    %eax,(%esp)
f0102a19:	e8 12 ea ff ff       	call   f0101430 <page_insert>
f0102a1e:	81 c7 00 10 00 00    	add    $0x1000,%edi
	//     * [KSTACKTOP-PTSIZE, KSTACKTOP-KSTKSIZE) -- not backed; so if
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102a24:	81 ff 00 e0 11 00    	cmp    $0x11e000,%edi
f0102a2a:	0f 85 76 ff ff ff    	jne    f01029a6 <mem_init+0x14b5>
f0102a30:	e9 0e 09 00 00       	jmp    f0103343 <mem_init+0x1e52>
f0102a35:	8d bb 00 10 00 f0    	lea    -0xffff000(%ebx),%edi
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W| PTE_P);
f0102a3b:	8b 1d 88 3e 22 f0    	mov    0xf0223e88,%ebx
f0102a41:	89 de                	mov    %ebx,%esi
f0102a43:	c1 e6 0c             	shl    $0xc,%esi
f0102a46:	89 c8                	mov    %ecx,%eax
f0102a48:	ba 00 00 00 00       	mov    $0x0,%edx
f0102a4d:	f7 f6                	div    %esi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102a4f:	c1 ea 0c             	shr    $0xc,%edx
f0102a52:	39 d3                	cmp    %edx,%ebx
f0102a54:	77 1c                	ja     f0102a72 <mem_init+0x1581>
		panic("pa2page called with invalid pa");
f0102a56:	c7 44 24 08 34 6b 10 	movl   $0xf0106b34,0x8(%esp)
f0102a5d:	f0 
f0102a5e:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102a65:	00 
f0102a66:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f0102a6d:	e8 ce d5 ff ff       	call   f0100040 <_panic>
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
f0102a72:	89 cb                	mov    %ecx,%ebx
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W| PTE_P);
f0102a74:	c7 44 24 0c 03 00 00 	movl   $0x3,0xc(%esp)
f0102a7b:	00 
f0102a7c:	89 7c 24 08          	mov    %edi,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102a80:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
f0102a85:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f0102a88:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102a8c:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102a91:	89 04 24             	mov    %eax,(%esp)
f0102a94:	e8 97 e9 ff ff       	call   f0101430 <page_insert>
		pa2page(i % (npages*PGSIZE))->pp_ref--;                 //this statement is to keep pp_ref == 0 in page_free_list
f0102a99:	8b 0d 88 3e 22 f0    	mov    0xf0223e88,%ecx
f0102a9f:	89 ce                	mov    %ecx,%esi
f0102aa1:	c1 e6 0c             	shl    $0xc,%esi
f0102aa4:	89 d8                	mov    %ebx,%eax
f0102aa6:	ba 00 00 00 00       	mov    $0x0,%edx
f0102aab:	f7 f6                	div    %esi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102aad:	c1 ea 0c             	shr    $0xc,%edx
f0102ab0:	39 d1                	cmp    %edx,%ecx
f0102ab2:	77 1c                	ja     f0102ad0 <mem_init+0x15df>
		panic("pa2page called with invalid pa");
f0102ab4:	c7 44 24 08 34 6b 10 	movl   $0xf0106b34,0x8(%esp)
f0102abb:	f0 
f0102abc:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102ac3:	00 
f0102ac4:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f0102acb:	e8 70 d5 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0102ad0:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
f0102ad5:	66 83 6c d0 04 01    	subw   $0x1,0x4(%eax,%edx,8)
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
f0102adb:	8d 8b 00 10 00 00    	lea    0x1000(%ebx),%ecx
f0102ae1:	81 f9 00 00 00 10    	cmp    $0x10000000,%ecx
f0102ae7:	0f 85 48 ff ff ff    	jne    f0102a35 <mem_init+0x1544>
static void
mem_init_mp(void)
{
	// Create a direct mapping at the top of virtual address space starting
	// at IOMEMBASE for accessing the LAPIC unit using memory-mapped I/O.
	boot_map_region(kern_pgdir, IOMEMBASE, -IOMEMBASE, IOMEM_PADDR, PTE_W);
f0102aed:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102af4:	00 
f0102af5:	c7 04 24 00 00 00 fe 	movl   $0xfe000000,(%esp)
f0102afc:	b9 00 00 00 02       	mov    $0x2000000,%ecx
f0102b01:	ba 00 00 00 fe       	mov    $0xfe000000,%edx
f0102b06:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102b0b:	e8 ad e7 ff ff       	call   f01012bd <boot_map_region>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102b10:	b8 00 50 22 f0       	mov    $0xf0225000,%eax
f0102b15:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102b1a:	0f 87 41 08 00 00    	ja     f0103361 <mem_init+0x1e70>
f0102b20:	eb 0c                	jmp    f0102b2e <mem_init+0x163d>
	physaddr_t cpu_phystk_i;
	uintptr_t cpu_vastk_i;
	size_t va;
	for(i = 0 ; i<NCPU ;i++){
		cpu_vastk_i = KSTACKTOP - i* (KSTKSIZE + KSTKGAP)-KSTKSIZE;
		cpu_phystk_i = PADDR(percpu_kstacks[i]);
f0102b22:	89 d8                	mov    %ebx,%eax
f0102b24:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102b2a:	77 27                	ja     f0102b53 <mem_init+0x1662>
f0102b2c:	eb 05                	jmp    f0102b33 <mem_init+0x1642>
f0102b2e:	b8 00 50 22 f0       	mov    $0xf0225000,%eax
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102b33:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102b37:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f0102b3e:	f0 
f0102b3f:	c7 44 24 04 24 01 00 	movl   $0x124,0x4(%esp)
f0102b46:	00 
f0102b47:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102b4e:	e8 ed d4 ff ff       	call   f0100040 <_panic>
		boot_map_region(kern_pgdir,cpu_vastk_i,KSTKSIZE,cpu_phystk_i,PTE_W);
f0102b53:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102b5a:	00 
f0102b5b:	8d 83 00 00 00 10    	lea    0x10000000(%ebx),%eax
f0102b61:	89 04 24             	mov    %eax,(%esp)
f0102b64:	b9 00 80 00 00       	mov    $0x8000,%ecx
f0102b69:	89 f2                	mov    %esi,%edx
f0102b6b:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102b70:	e8 48 e7 ff ff       	call   f01012bd <boot_map_region>
f0102b75:	81 c3 00 80 00 00    	add    $0x8000,%ebx
f0102b7b:	81 ee 00 00 01 00    	sub    $0x10000,%esi
	// LAB 4: Your code here:
	int i;
	physaddr_t cpu_phystk_i;
	uintptr_t cpu_vastk_i;
	size_t va;
	for(i = 0 ; i<NCPU ;i++){
f0102b81:	39 fb                	cmp    %edi,%ebx
f0102b83:	75 9d                	jne    f0102b22 <mem_init+0x1631>
check_kern_pgdir(void)
{
	uint32_t i, n;
	pde_t *pgdir;

	pgdir = kern_pgdir;
f0102b85:	8b 3d 8c 3e 22 f0    	mov    0xf0223e8c,%edi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
f0102b8b:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f0102b90:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0102b93:	8d 04 c5 ff 0f 00 00 	lea    0xfff(,%eax,8),%eax
	for (i = 0; i < n; i += PGSIZE)
f0102b9a:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102b9f:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0102ba2:	75 30                	jne    f0102bd4 <mem_init+0x16e3>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102ba4:	8b 1d 48 32 22 f0    	mov    0xf0223248,%ebx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102baa:	89 de                	mov    %ebx,%esi
f0102bac:	ba 00 00 c0 ee       	mov    $0xeec00000,%edx
f0102bb1:	89 f8                	mov    %edi,%eax
f0102bb3:	e8 ec df ff ff       	call   f0100ba4 <check_va2pa>
f0102bb8:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102bbe:	0f 86 94 00 00 00    	jbe    f0102c58 <mem_init+0x1767>
f0102bc4:	bb 00 00 c0 ee       	mov    $0xeec00000,%ebx
f0102bc9:	81 c6 00 00 40 21    	add    $0x21400000,%esi
f0102bcf:	e9 a4 00 00 00       	jmp    f0102c78 <mem_init+0x1787>
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102bd4:	8b 1d 90 3e 22 f0    	mov    0xf0223e90,%ebx
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102bda:	8d b3 00 00 00 10    	lea    0x10000000(%ebx),%esi
f0102be0:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f0102be5:	89 f8                	mov    %edi,%eax
f0102be7:	e8 b8 df ff ff       	call   f0100ba4 <check_va2pa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102bec:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102bf2:	77 20                	ja     f0102c14 <mem_init+0x1723>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102bf4:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102bf8:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f0102bff:	f0 
f0102c00:	c7 44 24 04 63 03 00 	movl   $0x363,0x4(%esp)
f0102c07:	00 
f0102c08:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102c0f:	e8 2c d4 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102c14:	ba 00 00 00 00       	mov    $0x0,%edx
f0102c19:	8d 0c 16             	lea    (%esi,%edx,1),%ecx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102c1c:	39 c8                	cmp    %ecx,%eax
f0102c1e:	74 24                	je     f0102c44 <mem_init+0x1753>
f0102c20:	c7 44 24 0c 7c 6f 10 	movl   $0xf0106f7c,0xc(%esp)
f0102c27:	f0 
f0102c28:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102c2f:	f0 
f0102c30:	c7 44 24 04 63 03 00 	movl   $0x363,0x4(%esp)
f0102c37:	00 
f0102c38:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102c3f:	e8 fc d3 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102c44:	8d 9a 00 10 00 00    	lea    0x1000(%edx),%ebx
f0102c4a:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f0102c4d:	0f 87 d2 07 00 00    	ja     f0103425 <mem_init+0x1f34>
f0102c53:	e9 4c ff ff ff       	jmp    f0102ba4 <mem_init+0x16b3>
f0102c58:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102c5c:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f0102c63:	f0 
f0102c64:	c7 44 24 04 68 03 00 	movl   $0x368,0x4(%esp)
f0102c6b:	00 
f0102c6c:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102c73:	e8 c8 d3 ff ff       	call   f0100040 <_panic>
f0102c78:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102c7b:	39 c2                	cmp    %eax,%edx
f0102c7d:	74 24                	je     f0102ca3 <mem_init+0x17b2>
f0102c7f:	c7 44 24 0c b0 6f 10 	movl   $0xf0106fb0,0xc(%esp)
f0102c86:	f0 
f0102c87:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102c8e:	f0 
f0102c8f:	c7 44 24 04 68 03 00 	movl   $0x368,0x4(%esp)
f0102c96:	00 
f0102c97:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102c9e:	e8 9d d3 ff ff       	call   f0100040 <_panic>
f0102ca3:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102ca9:	81 fb 00 f0 c1 ee    	cmp    $0xeec1f000,%ebx
f0102caf:	0f 85 62 07 00 00    	jne    f0103417 <mem_init+0x1f26>
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102cb5:	8b 75 d0             	mov    -0x30(%ebp),%esi
f0102cb8:	c1 e6 0c             	shl    $0xc,%esi
f0102cbb:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102cc0:	85 f6                	test   %esi,%esi
f0102cc2:	75 07                	jne    f0102ccb <mem_init+0x17da>
f0102cc4:	bb 00 00 00 fe       	mov    $0xfe000000,%ebx
f0102cc9:	eb 41                	jmp    f0102d0c <mem_init+0x181b>
f0102ccb:	8d 93 00 00 00 f0    	lea    -0x10000000(%ebx),%edx
		assert(check_va2pa(pgdir, KERNBASE + i) == i);
f0102cd1:	89 f8                	mov    %edi,%eax
f0102cd3:	e8 cc de ff ff       	call   f0100ba4 <check_va2pa>
f0102cd8:	39 c3                	cmp    %eax,%ebx
f0102cda:	74 24                	je     f0102d00 <mem_init+0x180f>
f0102cdc:	c7 44 24 0c e4 6f 10 	movl   $0xf0106fe4,0xc(%esp)
f0102ce3:	f0 
f0102ce4:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102ceb:	f0 
f0102cec:	c7 44 24 04 6c 03 00 	movl   $0x36c,0x4(%esp)
f0102cf3:	00 
f0102cf4:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102cfb:	e8 40 d3 ff ff       	call   f0100040 <_panic>
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102d00:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102d06:	39 f3                	cmp    %esi,%ebx
f0102d08:	72 c1                	jb     f0102ccb <mem_init+0x17da>
f0102d0a:	eb b8                	jmp    f0102cc4 <mem_init+0x17d3>
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);
f0102d0c:	89 da                	mov    %ebx,%edx
f0102d0e:	89 f8                	mov    %edi,%eax
f0102d10:	e8 8f de ff ff       	call   f0100ba4 <check_va2pa>
f0102d15:	39 c3                	cmp    %eax,%ebx
f0102d17:	74 24                	je     f0102d3d <mem_init+0x184c>
f0102d19:	c7 44 24 0c 36 74 10 	movl   $0xf0107436,0xc(%esp)
f0102d20:	f0 
f0102d21:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102d28:	f0 
f0102d29:	c7 44 24 04 70 03 00 	movl   $0x370,0x4(%esp)
f0102d30:	00 
f0102d31:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102d38:	e8 03 d3 ff ff       	call   f0100040 <_panic>
	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
f0102d3d:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102d43:	81 fb 00 f0 ff ff    	cmp    $0xfffff000,%ebx
f0102d49:	75 c1                	jne    f0102d0c <mem_init+0x181b>
f0102d4b:	c7 45 d0 00 50 22 f0 	movl   $0xf0225000,-0x30(%ebp)
f0102d52:	c7 45 cc 00 00 00 00 	movl   $0x0,-0x34(%ebp)
f0102d59:	be 00 80 bf ef       	mov    $0xefbf8000,%esi
f0102d5e:	b8 00 50 22 f0       	mov    $0xf0225000,%eax
f0102d63:	05 00 80 40 20       	add    $0x20408000,%eax
f0102d68:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0102d6b:	8d 86 00 80 00 00    	lea    0x8000(%esi),%eax
f0102d71:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0102d74:	89 f2                	mov    %esi,%edx
f0102d76:	89 f8                	mov    %edi,%eax
f0102d78:	e8 27 de ff ff       	call   f0100ba4 <check_va2pa>
f0102d7d:	8b 4d d0             	mov    -0x30(%ebp),%ecx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102d80:	81 f9 ff ff ff ef    	cmp    $0xefffffff,%ecx
f0102d86:	77 20                	ja     f0102da8 <mem_init+0x18b7>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102d88:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0102d8c:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f0102d93:	f0 
f0102d94:	c7 44 24 04 78 03 00 	movl   $0x378,0x4(%esp)
f0102d9b:	00 
f0102d9c:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102da3:	e8 98 d2 ff ff       	call   f0100040 <_panic>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102da8:	89 f3                	mov    %esi,%ebx
f0102daa:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0102dad:	03 4d c4             	add    -0x3c(%ebp),%ecx
f0102db0:	89 75 c8             	mov    %esi,-0x38(%ebp)
f0102db3:	89 ce                	mov    %ecx,%esi
f0102db5:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
f0102db8:	39 c2                	cmp    %eax,%edx
f0102dba:	74 24                	je     f0102de0 <mem_init+0x18ef>
f0102dbc:	c7 44 24 0c 0c 70 10 	movl   $0xf010700c,0xc(%esp)
f0102dc3:	f0 
f0102dc4:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102dcb:	f0 
f0102dcc:	c7 44 24 04 78 03 00 	movl   $0x378,0x4(%esp)
f0102dd3:	00 
f0102dd4:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102ddb:	e8 60 d2 ff ff       	call   f0100040 <_panic>
f0102de0:	81 c3 00 10 00 00    	add    $0x1000,%ebx

	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102de6:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0102de9:	0f 85 1a 06 00 00    	jne    f0103409 <mem_init+0x1f18>
f0102def:	8b 75 c8             	mov    -0x38(%ebp),%esi
f0102df2:	8d 9e 00 80 ff ff    	lea    -0x8000(%esi),%ebx
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
f0102df8:	89 da                	mov    %ebx,%edx
f0102dfa:	89 f8                	mov    %edi,%eax
f0102dfc:	e8 a3 dd ff ff       	call   f0100ba4 <check_va2pa>
f0102e01:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102e04:	74 24                	je     f0102e2a <mem_init+0x1939>
f0102e06:	c7 44 24 0c 54 70 10 	movl   $0xf0107054,0xc(%esp)
f0102e0d:	f0 
f0102e0e:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102e15:	f0 
f0102e16:	c7 44 24 04 7a 03 00 	movl   $0x37a,0x4(%esp)
f0102e1d:	00 
f0102e1e:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102e25:	e8 16 d2 ff ff       	call   f0100040 <_panic>
f0102e2a:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
f0102e30:	39 f3                	cmp    %esi,%ebx
f0102e32:	75 c4                	jne    f0102df8 <mem_init+0x1907>
f0102e34:	81 ee 00 00 01 00    	sub    $0x10000,%esi
f0102e3a:	81 45 cc 00 80 01 00 	addl   $0x18000,-0x34(%ebp)
f0102e41:	81 45 d0 00 80 00 00 	addl   $0x8000,-0x30(%ebp)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);

	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
f0102e48:	81 fe 00 80 b7 ef    	cmp    $0xefb78000,%esi
f0102e4e:	0f 85 17 ff ff ff    	jne    f0102d6b <mem_init+0x187a>
f0102e54:	b8 00 00 00 00       	mov    $0x0,%eax
			assert(check_va2pa(pgdir, base + i) == ~0);
	}

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
		switch (i) {
f0102e59:	8d 90 45 fc ff ff    	lea    -0x3bb(%eax),%edx
f0102e5f:	83 fa 03             	cmp    $0x3,%edx
f0102e62:	77 2e                	ja     f0102e92 <mem_init+0x19a1>
		case PDX(UVPT):
		case PDX(KSTACKTOP-1):
		case PDX(UPAGES):
		case PDX(UENVS):
			assert(pgdir[i] & PTE_P);
f0102e64:	f6 04 87 01          	testb  $0x1,(%edi,%eax,4)
f0102e68:	0f 85 aa 00 00 00    	jne    f0102f18 <mem_init+0x1a27>
f0102e6e:	c7 44 24 0c 51 74 10 	movl   $0xf0107451,0xc(%esp)
f0102e75:	f0 
f0102e76:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102e7d:	f0 
f0102e7e:	c7 44 24 04 84 03 00 	movl   $0x384,0x4(%esp)
f0102e85:	00 
f0102e86:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102e8d:	e8 ae d1 ff ff       	call   f0100040 <_panic>
			break;
		default:
			if (i >= PDX(KERNBASE)) {
f0102e92:	3d bf 03 00 00       	cmp    $0x3bf,%eax
f0102e97:	76 55                	jbe    f0102eee <mem_init+0x19fd>
				assert(pgdir[i] & PTE_P);
f0102e99:	8b 14 87             	mov    (%edi,%eax,4),%edx
f0102e9c:	f6 c2 01             	test   $0x1,%dl
f0102e9f:	75 24                	jne    f0102ec5 <mem_init+0x19d4>
f0102ea1:	c7 44 24 0c 51 74 10 	movl   $0xf0107451,0xc(%esp)
f0102ea8:	f0 
f0102ea9:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102eb0:	f0 
f0102eb1:	c7 44 24 04 88 03 00 	movl   $0x388,0x4(%esp)
f0102eb8:	00 
f0102eb9:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102ec0:	e8 7b d1 ff ff       	call   f0100040 <_panic>
				assert(pgdir[i] & PTE_W);
f0102ec5:	f6 c2 02             	test   $0x2,%dl
f0102ec8:	75 4e                	jne    f0102f18 <mem_init+0x1a27>
f0102eca:	c7 44 24 0c 62 74 10 	movl   $0xf0107462,0xc(%esp)
f0102ed1:	f0 
f0102ed2:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102ed9:	f0 
f0102eda:	c7 44 24 04 89 03 00 	movl   $0x389,0x4(%esp)
f0102ee1:	00 
f0102ee2:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102ee9:	e8 52 d1 ff ff       	call   f0100040 <_panic>
			} else
				assert(pgdir[i] == 0);
f0102eee:	83 3c 87 00          	cmpl   $0x0,(%edi,%eax,4)
f0102ef2:	74 24                	je     f0102f18 <mem_init+0x1a27>
f0102ef4:	c7 44 24 0c 73 74 10 	movl   $0xf0107473,0xc(%esp)
f0102efb:	f0 
f0102efc:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102f03:	f0 
f0102f04:	c7 44 24 04 8b 03 00 	movl   $0x38b,0x4(%esp)
f0102f0b:	00 
f0102f0c:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102f13:	e8 28 d1 ff ff       	call   f0100040 <_panic>
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
	}

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
f0102f18:	83 c0 01             	add    $0x1,%eax
f0102f1b:	3d 00 04 00 00       	cmp    $0x400,%eax
f0102f20:	0f 85 33 ff ff ff    	jne    f0102e59 <mem_init+0x1968>
			} else
				assert(pgdir[i] == 0);
			break;
		}
	}
	cprintf("check_kern_pgdir() succeeded!\n");
f0102f26:	c7 04 24 78 70 10 f0 	movl   $0xf0107078,(%esp)
f0102f2d:	e8 ac 0f 00 00       	call   f0103ede <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f0102f32:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102f37:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102f3c:	77 20                	ja     f0102f5e <mem_init+0x1a6d>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102f3e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102f42:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f0102f49:	f0 
f0102f4a:	c7 44 24 04 f6 00 00 	movl   $0xf6,0x4(%esp)
f0102f51:	00 
f0102f52:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102f59:	e8 e2 d0 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0102f5e:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0102f63:	0f 22 d8             	mov    %eax,%cr3
	check_page_free_list(0);
f0102f66:	b8 00 00 00 00       	mov    $0x0,%eax
f0102f6b:	e8 a3 dc ff ff       	call   f0100c13 <check_page_free_list>

static __inline uint32_t
rcr0(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr0,%0" : "=r" (val));
f0102f70:	0f 20 c0             	mov    %cr0,%eax
	// entry.S set the really important flags in cr0 (including enabling
	// paging).  Here we configure the rest of the flags that we care about.
	cr0 = rcr0();
	cr0 |= CR0_PE|CR0_PG|CR0_AM|CR0_WP|CR0_NE|CR0_MP;
	cr0 &= ~(CR0_TS|CR0_EM);
f0102f73:	83 e0 f3             	and    $0xfffffff3,%eax
f0102f76:	0d 23 00 05 80       	or     $0x80050023,%eax
}

static __inline void
lcr0(uint32_t val)
{
	__asm __volatile("movl %0,%%cr0" : : "r" (val));
f0102f7b:	0f 22 c0             	mov    %eax,%cr0
	uintptr_t va;
	int i;

	// check that we can read and write installed pages
	pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0102f7e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102f85:	e8 6c e1 ff ff       	call   f01010f6 <page_alloc>
f0102f8a:	89 c3                	mov    %eax,%ebx
f0102f8c:	85 c0                	test   %eax,%eax
f0102f8e:	75 24                	jne    f0102fb4 <mem_init+0x1ac3>
f0102f90:	c7 44 24 0c 75 72 10 	movl   $0xf0107275,0xc(%esp)
f0102f97:	f0 
f0102f98:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102f9f:	f0 
f0102fa0:	c7 44 24 04 41 04 00 	movl   $0x441,0x4(%esp)
f0102fa7:	00 
f0102fa8:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102faf:	e8 8c d0 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0102fb4:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102fbb:	e8 36 e1 ff ff       	call   f01010f6 <page_alloc>
f0102fc0:	89 c7                	mov    %eax,%edi
f0102fc2:	85 c0                	test   %eax,%eax
f0102fc4:	75 24                	jne    f0102fea <mem_init+0x1af9>
f0102fc6:	c7 44 24 0c 8b 72 10 	movl   $0xf010728b,0xc(%esp)
f0102fcd:	f0 
f0102fce:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0102fd5:	f0 
f0102fd6:	c7 44 24 04 42 04 00 	movl   $0x442,0x4(%esp)
f0102fdd:	00 
f0102fde:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f0102fe5:	e8 56 d0 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0102fea:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102ff1:	e8 00 e1 ff ff       	call   f01010f6 <page_alloc>
f0102ff6:	89 c6                	mov    %eax,%esi
f0102ff8:	85 c0                	test   %eax,%eax
f0102ffa:	75 24                	jne    f0103020 <mem_init+0x1b2f>
f0102ffc:	c7 44 24 0c a1 72 10 	movl   $0xf01072a1,0xc(%esp)
f0103003:	f0 
f0103004:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010300b:	f0 
f010300c:	c7 44 24 04 43 04 00 	movl   $0x443,0x4(%esp)
f0103013:	00 
f0103014:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010301b:	e8 20 d0 ff ff       	call   f0100040 <_panic>
	page_free(pp0);
f0103020:	89 1c 24             	mov    %ebx,(%esp)
f0103023:	e8 53 e1 ff ff       	call   f010117b <page_free>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103028:	89 f8                	mov    %edi,%eax
f010302a:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f0103030:	c1 f8 03             	sar    $0x3,%eax
f0103033:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103036:	89 c2                	mov    %eax,%edx
f0103038:	c1 ea 0c             	shr    $0xc,%edx
f010303b:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f0103041:	72 20                	jb     f0103063 <mem_init+0x1b72>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103043:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103047:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f010304e:	f0 
f010304f:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103056:	00 
f0103057:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f010305e:	e8 dd cf ff ff       	call   f0100040 <_panic>
	memset(page2kva(pp1), 1, PGSIZE);
f0103063:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010306a:	00 
f010306b:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f0103072:	00 
	return (void *)(pa + KERNBASE);
f0103073:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0103078:	89 04 24             	mov    %eax,(%esp)
f010307b:	e8 19 26 00 00       	call   f0105699 <memset>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103080:	89 f0                	mov    %esi,%eax
f0103082:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f0103088:	c1 f8 03             	sar    $0x3,%eax
f010308b:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010308e:	89 c2                	mov    %eax,%edx
f0103090:	c1 ea 0c             	shr    $0xc,%edx
f0103093:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f0103099:	72 20                	jb     f01030bb <mem_init+0x1bca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010309b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010309f:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f01030a6:	f0 
f01030a7:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01030ae:	00 
f01030af:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f01030b6:	e8 85 cf ff ff       	call   f0100040 <_panic>
	memset(page2kva(pp2), 2, PGSIZE);
f01030bb:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01030c2:	00 
f01030c3:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f01030ca:	00 
	return (void *)(pa + KERNBASE);
f01030cb:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01030d0:	89 04 24             	mov    %eax,(%esp)
f01030d3:	e8 c1 25 00 00       	call   f0105699 <memset>
	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f01030d8:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01030df:	00 
f01030e0:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01030e7:	00 
f01030e8:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01030ec:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01030f1:	89 04 24             	mov    %eax,(%esp)
f01030f4:	e8 37 e3 ff ff       	call   f0101430 <page_insert>
	assert(pp1->pp_ref == 1);
f01030f9:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f01030fe:	74 24                	je     f0103124 <mem_init+0x1c33>
f0103100:	c7 44 24 0c 72 73 10 	movl   $0xf0107372,0xc(%esp)
f0103107:	f0 
f0103108:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010310f:	f0 
f0103110:	c7 44 24 04 48 04 00 	movl   $0x448,0x4(%esp)
f0103117:	00 
f0103118:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010311f:	e8 1c cf ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
f0103124:	81 3d 00 10 00 00 01 	cmpl   $0x1010101,0x1000
f010312b:	01 01 01 
f010312e:	74 24                	je     f0103154 <mem_init+0x1c63>
f0103130:	c7 44 24 0c 98 70 10 	movl   $0xf0107098,0xc(%esp)
f0103137:	f0 
f0103138:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010313f:	f0 
f0103140:	c7 44 24 04 49 04 00 	movl   $0x449,0x4(%esp)
f0103147:	00 
f0103148:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010314f:	e8 ec ce ff ff       	call   f0100040 <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f0103154:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f010315b:	00 
f010315c:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0103163:	00 
f0103164:	89 74 24 04          	mov    %esi,0x4(%esp)
f0103168:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f010316d:	89 04 24             	mov    %eax,(%esp)
f0103170:	e8 bb e2 ff ff       	call   f0101430 <page_insert>
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
f0103175:	81 3d 00 10 00 00 02 	cmpl   $0x2020202,0x1000
f010317c:	02 02 02 
f010317f:	74 24                	je     f01031a5 <mem_init+0x1cb4>
f0103181:	c7 44 24 0c bc 70 10 	movl   $0xf01070bc,0xc(%esp)
f0103188:	f0 
f0103189:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0103190:	f0 
f0103191:	c7 44 24 04 4b 04 00 	movl   $0x44b,0x4(%esp)
f0103198:	00 
f0103199:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01031a0:	e8 9b ce ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f01031a5:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f01031aa:	74 24                	je     f01031d0 <mem_init+0x1cdf>
f01031ac:	c7 44 24 0c 94 73 10 	movl   $0xf0107394,0xc(%esp)
f01031b3:	f0 
f01031b4:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01031bb:	f0 
f01031bc:	c7 44 24 04 4c 04 00 	movl   $0x44c,0x4(%esp)
f01031c3:	00 
f01031c4:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01031cb:	e8 70 ce ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f01031d0:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f01031d5:	74 24                	je     f01031fb <mem_init+0x1d0a>
f01031d7:	c7 44 24 0c dd 73 10 	movl   $0xf01073dd,0xc(%esp)
f01031de:	f0 
f01031df:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01031e6:	f0 
f01031e7:	c7 44 24 04 4d 04 00 	movl   $0x44d,0x4(%esp)
f01031ee:	00 
f01031ef:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01031f6:	e8 45 ce ff ff       	call   f0100040 <_panic>
	*(uint32_t *)PGSIZE = 0x03030303U;
f01031fb:	c7 05 00 10 00 00 03 	movl   $0x3030303,0x1000
f0103202:	03 03 03 
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103205:	89 f0                	mov    %esi,%eax
f0103207:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f010320d:	c1 f8 03             	sar    $0x3,%eax
f0103210:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103213:	89 c2                	mov    %eax,%edx
f0103215:	c1 ea 0c             	shr    $0xc,%edx
f0103218:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f010321e:	72 20                	jb     f0103240 <mem_init+0x1d4f>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103220:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103224:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f010322b:	f0 
f010322c:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103233:	00 
f0103234:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f010323b:	e8 00 ce ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
f0103240:	81 b8 00 00 00 f0 03 	cmpl   $0x3030303,-0x10000000(%eax)
f0103247:	03 03 03 
f010324a:	74 24                	je     f0103270 <mem_init+0x1d7f>
f010324c:	c7 44 24 0c e0 70 10 	movl   $0xf01070e0,0xc(%esp)
f0103253:	f0 
f0103254:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010325b:	f0 
f010325c:	c7 44 24 04 4f 04 00 	movl   $0x44f,0x4(%esp)
f0103263:	00 
f0103264:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010326b:	e8 d0 cd ff ff       	call   f0100040 <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f0103270:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0103277:	00 
f0103278:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f010327d:	89 04 24             	mov    %eax,(%esp)
f0103280:	e8 62 e1 ff ff       	call   f01013e7 <page_remove>
	assert(pp2->pp_ref == 0);
f0103285:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f010328a:	74 24                	je     f01032b0 <mem_init+0x1dbf>
f010328c:	c7 44 24 0c cc 73 10 	movl   $0xf01073cc,0xc(%esp)
f0103293:	f0 
f0103294:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010329b:	f0 
f010329c:	c7 44 24 04 51 04 00 	movl   $0x451,0x4(%esp)
f01032a3:	00 
f01032a4:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01032ab:	e8 90 cd ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f01032b0:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01032b5:	8b 08                	mov    (%eax),%ecx
f01032b7:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01032bd:	89 da                	mov    %ebx,%edx
f01032bf:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f01032c5:	c1 fa 03             	sar    $0x3,%edx
f01032c8:	c1 e2 0c             	shl    $0xc,%edx
f01032cb:	39 d1                	cmp    %edx,%ecx
f01032cd:	74 24                	je     f01032f3 <mem_init+0x1e02>
f01032cf:	c7 44 24 0c 68 6c 10 	movl   $0xf0106c68,0xc(%esp)
f01032d6:	f0 
f01032d7:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01032de:	f0 
f01032df:	c7 44 24 04 54 04 00 	movl   $0x454,0x4(%esp)
f01032e6:	00 
f01032e7:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f01032ee:	e8 4d cd ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f01032f3:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f01032f9:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f01032fe:	74 24                	je     f0103324 <mem_init+0x1e33>
f0103300:	c7 44 24 0c 83 73 10 	movl   $0xf0107383,0xc(%esp)
f0103307:	f0 
f0103308:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f010330f:	f0 
f0103310:	c7 44 24 04 56 04 00 	movl   $0x456,0x4(%esp)
f0103317:	00 
f0103318:	c7 04 24 6d 71 10 f0 	movl   $0xf010716d,(%esp)
f010331f:	e8 1c cd ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f0103324:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// free the pages we took
	page_free(pp0);
f010332a:	89 1c 24             	mov    %ebx,(%esp)
f010332d:	e8 49 de ff ff       	call   f010117b <page_free>

	cprintf("check_page_installed_pgdir() succeeded!\n");
f0103332:	c7 04 24 0c 71 10 f0 	movl   $0xf010710c,(%esp)
f0103339:	e8 a0 0b 00 00       	call   f0103ede <cprintf>
f010333e:	e9 f6 00 00 00       	jmp    f0103439 <mem_init+0x1f48>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103343:	83 3d 88 3e 22 f0 00 	cmpl   $0x0,0xf0223e88
f010334a:	0f 84 06 f7 ff ff    	je     f0102a56 <mem_init+0x1565>
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W| PTE_P);
f0103350:	bf 00 00 00 f0       	mov    $0xf0000000,%edi
f0103355:	bb 00 00 00 00       	mov    $0x0,%ebx
f010335a:	89 f2                	mov    %esi,%edx
f010335c:	e9 13 f7 ff ff       	jmp    f0102a74 <mem_init+0x1583>
	uintptr_t cpu_vastk_i;
	size_t va;
	for(i = 0 ; i<NCPU ;i++){
		cpu_vastk_i = KSTACKTOP - i* (KSTKSIZE + KSTKGAP)-KSTKSIZE;
		cpu_phystk_i = PADDR(percpu_kstacks[i]);
		boot_map_region(kern_pgdir,cpu_vastk_i,KSTKSIZE,cpu_phystk_i,PTE_W);
f0103361:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0103368:	00 
f0103369:	c7 04 24 00 50 22 00 	movl   $0x225000,(%esp)
f0103370:	b9 00 80 00 00       	mov    $0x8000,%ecx
f0103375:	ba 00 80 bf ef       	mov    $0xefbf8000,%edx
f010337a:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f010337f:	e8 39 df ff ff       	call   f01012bd <boot_map_region>
f0103384:	bb 00 d0 22 f0       	mov    $0xf022d000,%ebx
f0103389:	bf 00 50 26 f0       	mov    $0xf0265000,%edi
f010338e:	be 00 80 be ef       	mov    $0xefbe8000,%esi
f0103393:	e9 8a f7 ff ff       	jmp    f0102b22 <mem_init+0x1631>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		page_insert(kern_pgdir, pa2page(PADDR(bootstack) + i), (void *)(KSTACKTOP-KSTKSIZE + i), PTE_W| PTE_P);
f0103398:	c7 44 24 0c 03 00 00 	movl   $0x3,0xc(%esp)
f010339f:	00 
f01033a0:	c7 44 24 08 00 80 bf 	movl   $0xefbf8000,0x8(%esp)
f01033a7:	ef 
		panic("pa2page called with invalid pa");
	return &pages[PGNUM(pa)];
f01033a8:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f01033ae:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01033b1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01033b5:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01033ba:	89 04 24             	mov    %eax,(%esp)
f01033bd:	e8 6e e0 ff ff       	call   f0101430 <page_insert>
f01033c2:	bf 00 70 11 00       	mov    $0x117000,%edi
f01033c7:	b8 00 80 bf df       	mov    $0xdfbf8000,%eax
f01033cc:	29 d8                	sub    %ebx,%eax
f01033ce:	89 c3                	mov    %eax,%ebx
f01033d0:	e9 d1 f5 ff ff       	jmp    f01029a6 <mem_init+0x14b5>
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	size_t i;
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		page_insert(kern_pgdir,pa2page(PADDR(envs)+i),(void *)(UENVS + i),PTE_U| PTE_P);
f01033d5:	c7 44 24 0c 05 00 00 	movl   $0x5,0xc(%esp)
f01033dc:	00 
f01033dd:	c7 44 24 08 00 00 c0 	movl   $0xeec00000,0x8(%esp)
f01033e4:	ee 
f01033e5:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f01033eb:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01033ee:	89 44 24 04          	mov    %eax,0x4(%esp)
f01033f2:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01033f7:	89 04 24             	mov    %eax,(%esp)
f01033fa:	e8 31 e0 ff ff       	call   f0101430 <page_insert>
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	size_t i;
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f01033ff:	bb 00 10 00 00       	mov    $0x1000,%ebx
f0103404:	e9 e2 f4 ff ff       	jmp    f01028eb <mem_init+0x13fa>
	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0103409:	89 da                	mov    %ebx,%edx
f010340b:	89 f8                	mov    %edi,%eax
f010340d:	e8 92 d7 ff ff       	call   f0100ba4 <check_va2pa>
f0103412:	e9 9e f9 ff ff       	jmp    f0102db5 <mem_init+0x18c4>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0103417:	89 da                	mov    %ebx,%edx
f0103419:	89 f8                	mov    %edi,%eax
f010341b:	e8 84 d7 ff ff       	call   f0100ba4 <check_va2pa>
f0103420:	e9 53 f8 ff ff       	jmp    f0102c78 <mem_init+0x1787>
f0103425:	81 ea 00 f0 ff 10    	sub    $0x10fff000,%edx
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f010342b:	89 f8                	mov    %edi,%eax
f010342d:	e8 72 d7 ff ff       	call   f0100ba4 <check_va2pa>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0103432:	89 da                	mov    %ebx,%edx
f0103434:	e9 e0 f7 ff ff       	jmp    f0102c19 <mem_init+0x1728>
	cr0 &= ~(CR0_TS|CR0_EM);
	lcr0(cr0);

	// Some more checks, only possible after kern_pgdir is installed.
	check_page_installed_pgdir();
}
f0103439:	83 c4 4c             	add    $0x4c,%esp
f010343c:	5b                   	pop    %ebx
f010343d:	5e                   	pop    %esi
f010343e:	5f                   	pop    %edi
f010343f:	5d                   	pop    %ebp
f0103440:	c3                   	ret    

f0103441 <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f0103441:	55                   	push   %ebp
f0103442:	89 e5                	mov    %esp,%ebp
f0103444:	57                   	push   %edi
f0103445:	56                   	push   %esi
f0103446:	53                   	push   %ebx
f0103447:	83 ec 3c             	sub    $0x3c,%esp
f010344a:	8b 7d 08             	mov    0x8(%ebp),%edi
f010344d:	8b 45 0c             	mov    0xc(%ebp),%eax

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
f0103450:	89 c2                	mov    %eax,%edx
f0103452:	03 55 10             	add    0x10(%ebp),%edx
f0103455:	89 55 d0             	mov    %edx,-0x30(%ebp)
f0103458:	39 d0                	cmp    %edx,%eax
f010345a:	73 70                	jae    f01034cc <user_mem_check+0x8b>
f010345c:	89 c3                	mov    %eax,%ebx
f010345e:	89 c6                	mov    %eax,%esi
		pte_t* store=0;
		struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
		if(store!=NULL)
		{
			//cprintf("pte!=NULL %08x\r\n",*store);
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f0103460:	8b 45 14             	mov    0x14(%ebp),%eax
f0103463:	83 c8 01             	or     $0x1,%eax
f0103466:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
	{
		pte_t* store=0;
f0103469:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
		struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
f0103470:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0103473:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103477:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010347b:	8b 47 60             	mov    0x60(%edi),%eax
f010347e:	89 04 24             	mov    %eax,(%esp)
f0103481:	e8 bf de ff ff       	call   f0101345 <page_lookup>
		if(store!=NULL)
f0103486:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103489:	85 c0                	test   %eax,%eax
f010348b:	74 1b                	je     f01034a8 <user_mem_check+0x67>
		{
			//cprintf("pte!=NULL %08x\r\n",*store);
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f010348d:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0103490:	89 ca                	mov    %ecx,%edx
f0103492:	23 10                	and    (%eax),%edx
f0103494:	39 d1                	cmp    %edx,%ecx
f0103496:	75 08                	jne    f01034a0 <user_mem_check+0x5f>
f0103498:	81 fe 00 00 80 ef    	cmp    $0xef800000,%esi
f010349e:	76 10                	jbe    f01034b0 <user_mem_check+0x6f>
			   {
				//cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f01034a0:	89 35 3c 32 22 f0    	mov    %esi,0xf022323c
				break;
f01034a6:	eb 1d                	jmp    f01034c5 <user_mem_check+0x84>
			}
			else
			{
				//cprintf("no pte!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f01034a8:	89 35 3c 32 22 f0    	mov    %esi,0xf022323c
				break;
f01034ae:	eb 15                	jmp    f01034c5 <user_mem_check+0x84>
			}
		    i=ROUNDDOWN(i,PGSIZE);
f01034b0:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
f01034b6:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f01034bc:	89 de                	mov    %ebx,%esi
f01034be:	3b 5d d0             	cmp    -0x30(%ebp),%ebx
f01034c1:	72 a6                	jb     f0103469 <user_mem_check+0x28>
f01034c3:	eb 0e                	jmp    f01034d3 <user_mem_check+0x92>
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
			   {
				//cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
				break;
f01034c5:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f01034ca:	eb 0c                	jmp    f01034d8 <user_mem_check+0x97>
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
f01034cc:	b8 00 00 00 00       	mov    $0x0,%eax
f01034d1:	eb 05                	jmp    f01034d8 <user_mem_check+0x97>
f01034d3:	b8 00 00 00 00       	mov    $0x0,%eax
			}
		    i=ROUNDDOWN(i,PGSIZE);
		}

	return flag;
}
f01034d8:	83 c4 3c             	add    $0x3c,%esp
f01034db:	5b                   	pop    %ebx
f01034dc:	5e                   	pop    %esi
f01034dd:	5f                   	pop    %edi
f01034de:	5d                   	pop    %ebp
f01034df:	c3                   	ret    

f01034e0 <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f01034e0:	55                   	push   %ebp
f01034e1:	89 e5                	mov    %esp,%ebp
f01034e3:	53                   	push   %ebx
f01034e4:	83 ec 14             	sub    $0x14,%esp
f01034e7:	8b 5d 08             	mov    0x8(%ebp),%ebx
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
f01034ea:	8b 45 14             	mov    0x14(%ebp),%eax
f01034ed:	83 c8 04             	or     $0x4,%eax
f01034f0:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01034f4:	8b 45 10             	mov    0x10(%ebp),%eax
f01034f7:	89 44 24 08          	mov    %eax,0x8(%esp)
f01034fb:	8b 45 0c             	mov    0xc(%ebp),%eax
f01034fe:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103502:	89 1c 24             	mov    %ebx,(%esp)
f0103505:	e8 37 ff ff ff       	call   f0103441 <user_mem_check>
f010350a:	85 c0                	test   %eax,%eax
f010350c:	79 24                	jns    f0103532 <user_mem_assert+0x52>
		cprintf(".%08x. user_mem_check assertion failure for "
f010350e:	a1 3c 32 22 f0       	mov    0xf022323c,%eax
f0103513:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103517:	8b 43 48             	mov    0x48(%ebx),%eax
f010351a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010351e:	c7 04 24 38 71 10 f0 	movl   $0xf0107138,(%esp)
f0103525:	e8 b4 09 00 00       	call   f0103ede <cprintf>
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
f010352a:	89 1c 24             	mov    %ebx,(%esp)
f010352d:	e8 fa 06 00 00       	call   f0103c2c <env_destroy>
	}
}
f0103532:	83 c4 14             	add    $0x14,%esp
f0103535:	5b                   	pop    %ebx
f0103536:	5d                   	pop    %ebp
f0103537:	c3                   	ret    

f0103538 <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f0103538:	55                   	push   %ebp
f0103539:	89 e5                	mov    %esp,%ebp
f010353b:	56                   	push   %esi
f010353c:	53                   	push   %ebx
f010353d:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f0103540:	85 c0                	test   %eax,%eax
f0103542:	75 1a                	jne    f010355e <envid2env+0x26>
		*env_store = curenv;
f0103544:	e8 ea 27 00 00       	call   f0105d33 <cpunum>
f0103549:	6b c0 74             	imul   $0x74,%eax,%eax
f010354c:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103552:	8b 55 0c             	mov    0xc(%ebp),%edx
f0103555:	89 02                	mov    %eax,(%edx)
		return 0;
f0103557:	b8 00 00 00 00       	mov    $0x0,%eax
f010355c:	eb 72                	jmp    f01035d0 <envid2env+0x98>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f010355e:	89 c3                	mov    %eax,%ebx
f0103560:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
f0103566:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f0103569:	03 1d 48 32 22 f0    	add    0xf0223248,%ebx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f010356f:	83 7b 54 00          	cmpl   $0x0,0x54(%ebx)
f0103573:	74 05                	je     f010357a <envid2env+0x42>
f0103575:	39 43 48             	cmp    %eax,0x48(%ebx)
f0103578:	74 10                	je     f010358a <envid2env+0x52>
		*env_store = 0;
f010357a:	8b 45 0c             	mov    0xc(%ebp),%eax
f010357d:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f0103583:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0103588:	eb 46                	jmp    f01035d0 <envid2env+0x98>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f010358a:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f010358e:	74 36                	je     f01035c6 <envid2env+0x8e>
f0103590:	e8 9e 27 00 00       	call   f0105d33 <cpunum>
f0103595:	6b c0 74             	imul   $0x74,%eax,%eax
f0103598:	39 98 28 40 22 f0    	cmp    %ebx,-0xfddbfd8(%eax)
f010359e:	74 26                	je     f01035c6 <envid2env+0x8e>
f01035a0:	8b 73 4c             	mov    0x4c(%ebx),%esi
f01035a3:	e8 8b 27 00 00       	call   f0105d33 <cpunum>
f01035a8:	6b c0 74             	imul   $0x74,%eax,%eax
f01035ab:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f01035b1:	3b 70 48             	cmp    0x48(%eax),%esi
f01035b4:	74 10                	je     f01035c6 <envid2env+0x8e>
		*env_store = 0;
f01035b6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01035b9:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f01035bf:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01035c4:	eb 0a                	jmp    f01035d0 <envid2env+0x98>
	}

	*env_store = e;
f01035c6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01035c9:	89 18                	mov    %ebx,(%eax)
	return 0;
f01035cb:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01035d0:	5b                   	pop    %ebx
f01035d1:	5e                   	pop    %esi
f01035d2:	5d                   	pop    %ebp
f01035d3:	c3                   	ret    

f01035d4 <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f01035d4:	55                   	push   %ebp
f01035d5:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f01035d7:	b8 00 03 12 f0       	mov    $0xf0120300,%eax
f01035dc:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f01035df:	b8 23 00 00 00       	mov    $0x23,%eax
f01035e4:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f01035e6:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f01035e8:	b0 10                	mov    $0x10,%al
f01035ea:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f01035ec:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f01035ee:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f01035f0:	ea f7 35 10 f0 08 00 	ljmp   $0x8,$0xf01035f7
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f01035f7:	b0 00                	mov    $0x0,%al
f01035f9:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f01035fc:	5d                   	pop    %ebp
f01035fd:	c3                   	ret    

f01035fe <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f01035fe:	55                   	push   %ebp
f01035ff:	89 e5                	mov    %esp,%ebp
f0103601:	56                   	push   %esi
f0103602:	53                   	push   %ebx
	// Set up envs array
	// LAB 3: Your code here.
	env_free_list = NULL;
	size_t i = NENV - 1;
	while(i+1) {
		envs[i].env_id = 0;
f0103603:	8b 35 48 32 22 f0    	mov    0xf0223248,%esi
f0103609:	8d 86 84 ef 01 00    	lea    0x1ef84(%esi),%eax
f010360f:	ba 00 04 00 00       	mov    $0x400,%edx
f0103614:	b9 00 00 00 00       	mov    $0x0,%ecx
f0103619:	89 c3                	mov    %eax,%ebx
f010361b:	c7 40 48 00 00 00 00 	movl   $0x0,0x48(%eax)
		envs[i].env_link = env_free_list;
f0103622:	89 48 44             	mov    %ecx,0x44(%eax)
f0103625:	83 e8 7c             	sub    $0x7c,%eax
{
	// Set up envs array
	// LAB 3: Your code here.
	env_free_list = NULL;
	size_t i = NENV - 1;
	while(i+1) {
f0103628:	83 ea 01             	sub    $0x1,%edx
f010362b:	74 04                	je     f0103631 <env_init+0x33>
		envs[i].env_id = 0;
		envs[i].env_link = env_free_list;
		env_free_list = &envs[i];
f010362d:	89 d9                	mov    %ebx,%ecx
f010362f:	eb e8                	jmp    f0103619 <env_init+0x1b>
f0103631:	89 35 4c 32 22 f0    	mov    %esi,0xf022324c
		i = i-1;
	}
	//env_free_list = envs; // this line of code changing like this ugly looks just fit fuck grade sh,too useless
	// Per-CPU part of the initialization
	env_init_percpu();
f0103637:	e8 98 ff ff ff       	call   f01035d4 <env_init_percpu>
}
f010363c:	5b                   	pop    %ebx
f010363d:	5e                   	pop    %esi
f010363e:	5d                   	pop    %ebp
f010363f:	c3                   	ret    

f0103640 <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f0103640:	55                   	push   %ebp
f0103641:	89 e5                	mov    %esp,%ebp
f0103643:	56                   	push   %esi
f0103644:	53                   	push   %ebx
f0103645:	83 ec 10             	sub    $0x10,%esp
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list)){
f0103648:	8b 1d 4c 32 22 f0    	mov    0xf022324c,%ebx
f010364e:	85 db                	test   %ebx,%ebx
f0103650:	0f 84 92 01 00 00    	je     f01037e8 <env_alloc+0x1a8>
{
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f0103656:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f010365d:	e8 94 da ff ff       	call   f01010f6 <page_alloc>
f0103662:	85 c0                	test   %eax,%eax
f0103664:	0f 84 85 01 00 00    	je     f01037ef <env_alloc+0x1af>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010366a:	89 c2                	mov    %eax,%edx
f010366c:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0103672:	c1 fa 03             	sar    $0x3,%edx
f0103675:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103678:	89 d1                	mov    %edx,%ecx
f010367a:	c1 e9 0c             	shr    $0xc,%ecx
f010367d:	3b 0d 88 3e 22 f0    	cmp    0xf0223e88,%ecx
f0103683:	72 20                	jb     f01036a5 <env_alloc+0x65>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103685:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0103689:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f0103690:	f0 
f0103691:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103698:	00 
f0103699:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f01036a0:	e8 9b c9 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01036a5:	81 ea 00 00 00 10    	sub    $0x10000000,%edx
f01036ab:	89 53 60             	mov    %edx,0x60(%ebx)
	//	is an exception -- you need to increment env_pgdir's
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
f01036ae:	ba ec 0e 00 00       	mov    $0xeec,%edx
	for(i=PDX(UTOP);i<1024;i++){
		e->env_pgdir[i] = kern_pgdir[i];
f01036b3:	8b 0d 8c 3e 22 f0    	mov    0xf0223e8c,%ecx
f01036b9:	8b 34 11             	mov    (%ecx,%edx,1),%esi
f01036bc:	8b 4b 60             	mov    0x60(%ebx),%ecx
f01036bf:	89 34 11             	mov    %esi,(%ecx,%edx,1)
f01036c2:	83 c2 04             	add    $0x4,%edx
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
	for(i=PDX(UTOP);i<1024;i++){
f01036c5:	81 fa 00 10 00 00    	cmp    $0x1000,%edx
f01036cb:	75 e6                	jne    f01036b3 <env_alloc+0x73>
		e->env_pgdir[i] = kern_pgdir[i];
	}
	p->pp_ref++;
f01036cd:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f01036d2:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01036d5:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01036da:	77 20                	ja     f01036fc <env_alloc+0xbc>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01036dc:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01036e0:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f01036e7:	f0 
f01036e8:	c7 44 24 04 c8 00 00 	movl   $0xc8,0x4(%esp)
f01036ef:	00 
f01036f0:	c7 04 24 81 74 10 f0 	movl   $0xf0107481,(%esp)
f01036f7:	e8 44 c9 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01036fc:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f0103702:	83 ca 05             	or     $0x5,%edx
f0103705:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	if ((r = env_setup_vm(e)) < 0){
		return r;
	}

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f010370b:	8b 43 48             	mov    0x48(%ebx),%eax
f010370e:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f0103713:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f0103718:	ba 00 10 00 00       	mov    $0x1000,%edx
f010371d:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f0103720:	89 da                	mov    %ebx,%edx
f0103722:	2b 15 48 32 22 f0    	sub    0xf0223248,%edx
f0103728:	c1 fa 02             	sar    $0x2,%edx
f010372b:	69 d2 df 7b ef bd    	imul   $0xbdef7bdf,%edx,%edx
f0103731:	09 d0                	or     %edx,%eax
f0103733:	89 43 48             	mov    %eax,0x48(%ebx)

	// Set the basic status variables.
	e->env_parent_id = parent_id;
f0103736:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103739:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f010373c:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f0103743:	c7 43 54 02 00 00 00 	movl   $0x2,0x54(%ebx)
	e->env_runs = 0;
f010374a:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f0103751:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f0103758:	00 
f0103759:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0103760:	00 
f0103761:	89 1c 24             	mov    %ebx,(%esp)
f0103764:	e8 30 1f 00 00       	call   f0105699 <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f0103769:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f010376f:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f0103775:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f010377b:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f0103782:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)

	// Enable interrupts while in user mode.
	// LAB 4: Your code here.

	// Clear the page fault handler until user installs one.
	e->env_pgfault_upcall = 0;
f0103788:	c7 43 64 00 00 00 00 	movl   $0x0,0x64(%ebx)

	// Also clear the IPC receiving flag.
	e->env_ipc_recving = 0;
f010378f:	c7 43 68 00 00 00 00 	movl   $0x0,0x68(%ebx)

	// commit the allocation
	env_free_list = e->env_link;
f0103796:	8b 43 44             	mov    0x44(%ebx),%eax
f0103799:	a3 4c 32 22 f0       	mov    %eax,0xf022324c
	*newenv_store = e;
f010379e:	8b 45 08             	mov    0x8(%ebp),%eax
f01037a1:	89 18                	mov    %ebx,(%eax)

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f01037a3:	8b 5b 48             	mov    0x48(%ebx),%ebx
f01037a6:	e8 88 25 00 00       	call   f0105d33 <cpunum>
f01037ab:	6b d0 74             	imul   $0x74,%eax,%edx
f01037ae:	b8 00 00 00 00       	mov    $0x0,%eax
f01037b3:	83 ba 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%edx)
f01037ba:	74 11                	je     f01037cd <env_alloc+0x18d>
f01037bc:	e8 72 25 00 00       	call   f0105d33 <cpunum>
f01037c1:	6b c0 74             	imul   $0x74,%eax,%eax
f01037c4:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f01037ca:	8b 40 48             	mov    0x48(%eax),%eax
f01037cd:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f01037d1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01037d5:	c7 04 24 8c 74 10 f0 	movl   $0xf010748c,(%esp)
f01037dc:	e8 fd 06 00 00       	call   f0103ede <cprintf>
	return 0;
f01037e1:	b8 00 00 00 00       	mov    $0x0,%eax
f01037e6:	eb 0c                	jmp    f01037f4 <env_alloc+0x1b4>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list)){
		return -E_NO_FREE_ENV;
f01037e8:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f01037ed:	eb 05                	jmp    f01037f4 <env_alloc+0x1b4>
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f01037ef:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	env_free_list = e->env_link;
	*newenv_store = e;

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}
f01037f4:	83 c4 10             	add    $0x10,%esp
f01037f7:	5b                   	pop    %ebx
f01037f8:	5e                   	pop    %esi
f01037f9:	5d                   	pop    %ebp
f01037fa:	c3                   	ret    

f01037fb <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f01037fb:	55                   	push   %ebp
f01037fc:	89 e5                	mov    %esp,%ebp
f01037fe:	57                   	push   %edi
f01037ff:	56                   	push   %esi
f0103800:	53                   	push   %ebx
f0103801:	83 ec 3c             	sub    $0x3c,%esp
	// LAB 3: Your code here.
	struct Env * env;
	int test = env_alloc(&env,0);
f0103804:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010380b:	00 
f010380c:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f010380f:	89 04 24             	mov    %eax,(%esp)
f0103812:	e8 29 fe ff ff       	call   f0103640 <env_alloc>
	if(test==0){
f0103817:	85 c0                	test   %eax,%eax
f0103819:	0f 85 dd 01 00 00    	jne    f01039fc <env_create+0x201>
		load_icode(env,binary,size);
f010381f:	8b 7d e4             	mov    -0x1c(%ebp),%edi
	//  You must also do something with the program's entry point,
	//  to make sure that the environment starts executing there.
	//  What?  (See env_run() and env_pop_tf() below.)

	// LAB 3: Your code here.
	lcr3(PADDR(e->env_pgdir));
f0103822:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103825:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010382a:	77 20                	ja     f010384c <env_create+0x51>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010382c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103830:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f0103837:	f0 
f0103838:	c7 44 24 04 68 01 00 	movl   $0x168,0x4(%esp)
f010383f:	00 
f0103840:	c7 04 24 81 74 10 f0 	movl   $0xf0107481,(%esp)
f0103847:	e8 f4 c7 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f010384c:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0103851:	0f 22 d8             	mov    %eax,%cr3
	struct Elf* ELFHDR = (struct Elf *) binary;
	if(ELFHDR->e_magic != ELF_MAGIC)
f0103854:	8b 45 08             	mov    0x8(%ebp),%eax
f0103857:	81 38 7f 45 4c 46    	cmpl   $0x464c457f,(%eax)
f010385d:	74 1c                	je     f010387b <env_create+0x80>
		panic("Invalid ELF format !");
f010385f:	c7 44 24 08 a1 74 10 	movl   $0xf01074a1,0x8(%esp)
f0103866:	f0 
f0103867:	c7 44 24 04 6b 01 00 	movl   $0x16b,0x4(%esp)
f010386e:	00 
f010386f:	c7 04 24 81 74 10 f0 	movl   $0xf0107481,(%esp)
f0103876:	e8 c5 c7 ff ff       	call   f0100040 <_panic>

	struct Proghdr *ph,*eph;
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
f010387b:	8b 45 08             	mov    0x8(%ebp),%eax
f010387e:	89 c6                	mov    %eax,%esi
f0103880:	03 70 1c             	add    0x1c(%eax),%esi
	eph = ph + ELFHDR->e_phnum;
f0103883:	0f b7 40 2c          	movzwl 0x2c(%eax),%eax
f0103887:	c1 e0 05             	shl    $0x5,%eax
f010388a:	01 f0                	add    %esi,%eax
f010388c:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	for (; ph < eph; ph++) {
f010388f:	39 c6                	cmp    %eax,%esi
f0103891:	0f 83 d2 00 00 00    	jae    f0103969 <env_create+0x16e>
		if (ph->p_type == ELF_PROG_LOAD) {
f0103897:	83 3e 01             	cmpl   $0x1,(%esi)
f010389a:	0f 85 bd 00 00 00    	jne    f010395d <env_create+0x162>
			if (ph->p_filesz > ph->p_memsz)
f01038a0:	8b 56 14             	mov    0x14(%esi),%edx
f01038a3:	39 56 10             	cmp    %edx,0x10(%esi)
f01038a6:	76 1c                	jbe    f01038c4 <env_create+0xc9>
				panic("invalid ELF proGhdr header!");
f01038a8:	c7 44 24 08 b6 74 10 	movl   $0xf01074b6,0x8(%esp)
f01038af:	f0 
f01038b0:	c7 44 24 04 73 01 00 	movl   $0x173,0x4(%esp)
f01038b7:	00 
f01038b8:	c7 04 24 81 74 10 f0 	movl   $0xf0107481,(%esp)
f01038bf:	e8 7c c7 ff ff       	call   f0100040 <_panic>

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
f01038c4:	8b 46 08             	mov    0x8(%esi),%eax
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f01038c7:	89 c3                	mov    %eax,%ebx
f01038c9:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f01038cf:	8d 84 02 ff 0f 00 00 	lea    0xfff(%edx,%eax,1),%eax
f01038d6:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01038db:	39 c3                	cmp    %eax,%ebx
f01038dd:	73 59                	jae    f0103938 <env_create+0x13d>
f01038df:	89 75 d0             	mov    %esi,-0x30(%ebp)
f01038e2:	89 c6                	mov    %eax,%esi
		p = (struct Page*)page_alloc(1);
f01038e4:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01038eb:	e8 06 d8 ff ff       	call   f01010f6 <page_alloc>
		if(p==NULL)
f01038f0:	85 c0                	test   %eax,%eax
f01038f2:	75 1c                	jne    f0103910 <env_create+0x115>
			panic("Memory out!");
f01038f4:	c7 44 24 08 d2 74 10 	movl   $0xf01074d2,0x8(%esp)
f01038fb:	f0 
f01038fc:	c7 44 24 04 2d 01 00 	movl   $0x12d,0x4(%esp)
f0103903:	00 
f0103904:	c7 04 24 81 74 10 f0 	movl   $0xf0107481,(%esp)
f010390b:	e8 30 c7 ff ff       	call   f0100040 <_panic>
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
f0103910:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0103917:	00 
f0103918:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f010391c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103920:	8b 47 60             	mov    0x60(%edi),%eax
f0103923:	89 04 24             	mov    %eax,(%esp)
f0103926:	e8 05 db ff ff       	call   f0101430 <page_insert>
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f010392b:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0103931:	39 f3                	cmp    %esi,%ebx
f0103933:	72 af                	jb     f01038e4 <env_create+0xe9>
f0103935:	8b 75 d0             	mov    -0x30(%ebp),%esi
			if (ph->p_filesz > ph->p_memsz)
				panic("invalid ELF proGhdr header!");

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
			//copy to va
			char *va = (char *)(ph->p_va);
f0103938:	8b 4e 08             	mov    0x8(%esi),%ecx
			size_t i;
			for (i = 0; i < ph->p_filesz; i++)
f010393b:	83 7e 10 00          	cmpl   $0x0,0x10(%esi)
f010393f:	74 1c                	je     f010395d <env_create+0x162>
f0103941:	b8 00 00 00 00       	mov    $0x0,%eax
f0103946:	8b 5d 08             	mov    0x8(%ebp),%ebx
				va[i] = binary[ph->p_offset + i];
f0103949:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f010394c:	03 56 04             	add    0x4(%esi),%edx
f010394f:	0f b6 12             	movzbl (%edx),%edx
f0103952:	88 14 08             	mov    %dl,(%eax,%ecx,1)

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
			//copy to va
			char *va = (char *)(ph->p_va);
			size_t i;
			for (i = 0; i < ph->p_filesz; i++)
f0103955:	83 c0 01             	add    $0x1,%eax
f0103958:	3b 46 10             	cmp    0x10(%esi),%eax
f010395b:	72 ec                	jb     f0103949 <env_create+0x14e>
		panic("Invalid ELF format !");

	struct Proghdr *ph,*eph;
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
	eph = ph + ELFHDR->e_phnum;
	for (; ph < eph; ph++) {
f010395d:	83 c6 20             	add    $0x20,%esi
f0103960:	39 75 d4             	cmp    %esi,-0x2c(%ebp)
f0103963:	0f 87 2e ff ff ff    	ja     f0103897 <env_create+0x9c>
			for (i = 0; i < ph->p_filesz; i++)
				va[i] = binary[ph->p_offset + i];
		}
	}
	//set programe entry
	e->env_tf.tf_eip = ELFHDR->e_entry;
f0103969:	8b 45 08             	mov    0x8(%ebp),%eax
f010396c:	8b 40 18             	mov    0x18(%eax),%eax
f010396f:	89 47 30             	mov    %eax,0x30(%edi)
	// Now map one page for the program's initial stack
	// at virtual address USTACKTOP - PGSIZE.

	// LAB 3: Your code here.
	struct Page* stackPage = (struct Page*)page_alloc(1);
f0103972:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0103979:	e8 78 d7 ff ff       	call   f01010f6 <page_alloc>
	if(stackPage == NULL)
f010397e:	85 c0                	test   %eax,%eax
f0103980:	75 1c                	jne    f010399e <env_create+0x1a3>
		panic("Out of memory!");
f0103982:	c7 44 24 08 de 74 10 	movl   $0xf01074de,0x8(%esp)
f0103989:	f0 
f010398a:	c7 44 24 04 85 01 00 	movl   $0x185,0x4(%esp)
f0103991:	00 
f0103992:	c7 04 24 81 74 10 f0 	movl   $0xf0107481,(%esp)
f0103999:	e8 a2 c6 ff ff       	call   f0100040 <_panic>
	page_insert(e->env_pgdir,stackPage,(void*)USTACKTOP - PGSIZE,PTE_U|PTE_W);
f010399e:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01039a5:	00 
f01039a6:	c7 44 24 08 00 d0 bf 	movl   $0xeebfd000,0x8(%esp)
f01039ad:	ee 
f01039ae:	89 44 24 04          	mov    %eax,0x4(%esp)
f01039b2:	8b 47 60             	mov    0x60(%edi),%eax
f01039b5:	89 04 24             	mov    %eax,(%esp)
f01039b8:	e8 73 da ff ff       	call   f0101430 <page_insert>
	lcr3(PADDR(kern_pgdir));
f01039bd:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01039c2:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01039c7:	77 20                	ja     f01039e9 <env_create+0x1ee>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01039c9:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01039cd:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f01039d4:	f0 
f01039d5:	c7 44 24 04 87 01 00 	movl   $0x187,0x4(%esp)
f01039dc:	00 
f01039dd:	c7 04 24 81 74 10 f0 	movl   $0xf0107481,(%esp)
f01039e4:	e8 57 c6 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01039e9:	05 00 00 00 10       	add    $0x10000000,%eax
f01039ee:	0f 22 d8             	mov    %eax,%cr3
	// LAB 3: Your code here.
	struct Env * env;
	int test = env_alloc(&env,0);
	if(test==0){
		load_icode(env,binary,size);
		env->env_type = type;
f01039f1:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01039f4:	8b 55 10             	mov    0x10(%ebp),%edx
f01039f7:	89 50 50             	mov    %edx,0x50(%eax)
f01039fa:	eb 1c                	jmp    f0103a18 <env_create+0x21d>
	}else{
		panic("create env fails !\n");
f01039fc:	c7 44 24 08 ed 74 10 	movl   $0xf01074ed,0x8(%esp)
f0103a03:	f0 
f0103a04:	c7 44 24 04 9b 01 00 	movl   $0x19b,0x4(%esp)
f0103a0b:	00 
f0103a0c:	c7 04 24 81 74 10 f0 	movl   $0xf0107481,(%esp)
f0103a13:	e8 28 c6 ff ff       	call   f0100040 <_panic>
	}
}
f0103a18:	83 c4 3c             	add    $0x3c,%esp
f0103a1b:	5b                   	pop    %ebx
f0103a1c:	5e                   	pop    %esi
f0103a1d:	5f                   	pop    %edi
f0103a1e:	5d                   	pop    %ebp
f0103a1f:	c3                   	ret    

f0103a20 <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0103a20:	55                   	push   %ebp
f0103a21:	89 e5                	mov    %esp,%ebp
f0103a23:	57                   	push   %edi
f0103a24:	56                   	push   %esi
f0103a25:	53                   	push   %ebx
f0103a26:	83 ec 2c             	sub    $0x2c,%esp
f0103a29:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f0103a2c:	e8 02 23 00 00       	call   f0105d33 <cpunum>
f0103a31:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a34:	39 b8 28 40 22 f0    	cmp    %edi,-0xfddbfd8(%eax)
f0103a3a:	75 34                	jne    f0103a70 <env_free+0x50>
		lcr3(PADDR(kern_pgdir));
f0103a3c:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103a41:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103a46:	77 20                	ja     f0103a68 <env_free+0x48>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103a48:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103a4c:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f0103a53:	f0 
f0103a54:	c7 44 24 04 ad 01 00 	movl   $0x1ad,0x4(%esp)
f0103a5b:	00 
f0103a5c:	c7 04 24 81 74 10 f0 	movl   $0xf0107481,(%esp)
f0103a63:	e8 d8 c5 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103a68:	05 00 00 00 10       	add    $0x10000000,%eax
f0103a6d:	0f 22 d8             	mov    %eax,%cr3

	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0103a70:	8b 5f 48             	mov    0x48(%edi),%ebx
f0103a73:	e8 bb 22 00 00       	call   f0105d33 <cpunum>
f0103a78:	6b d0 74             	imul   $0x74,%eax,%edx
f0103a7b:	b8 00 00 00 00       	mov    $0x0,%eax
f0103a80:	83 ba 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%edx)
f0103a87:	74 11                	je     f0103a9a <env_free+0x7a>
f0103a89:	e8 a5 22 00 00       	call   f0105d33 <cpunum>
f0103a8e:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a91:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103a97:	8b 40 48             	mov    0x48(%eax),%eax
f0103a9a:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103a9e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103aa2:	c7 04 24 01 75 10 f0 	movl   $0xf0107501,(%esp)
f0103aa9:	e8 30 04 00 00       	call   f0103ede <cprintf>

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103aae:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0103ab5:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0103ab8:	89 c8                	mov    %ecx,%eax
f0103aba:	c1 e0 02             	shl    $0x2,%eax
f0103abd:	89 45 dc             	mov    %eax,-0x24(%ebp)

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f0103ac0:	8b 47 60             	mov    0x60(%edi),%eax
f0103ac3:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f0103ac6:	f7 c6 01 00 00 00    	test   $0x1,%esi
f0103acc:	0f 84 b7 00 00 00    	je     f0103b89 <env_free+0x169>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f0103ad2:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103ad8:	89 f0                	mov    %esi,%eax
f0103ada:	c1 e8 0c             	shr    $0xc,%eax
f0103add:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103ae0:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0103ae6:	72 20                	jb     f0103b08 <env_free+0xe8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103ae8:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0103aec:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f0103af3:	f0 
f0103af4:	c7 44 24 04 bc 01 00 	movl   $0x1bc,0x4(%esp)
f0103afb:	00 
f0103afc:	c7 04 24 81 74 10 f0 	movl   $0xf0107481,(%esp)
f0103b03:	e8 38 c5 ff ff       	call   f0100040 <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103b08:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103b0b:	c1 e0 16             	shl    $0x16,%eax
f0103b0e:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103b11:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f0103b16:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f0103b1d:	01 
f0103b1e:	74 17                	je     f0103b37 <env_free+0x117>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103b20:	89 d8                	mov    %ebx,%eax
f0103b22:	c1 e0 0c             	shl    $0xc,%eax
f0103b25:	0b 45 e4             	or     -0x1c(%ebp),%eax
f0103b28:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103b2c:	8b 47 60             	mov    0x60(%edi),%eax
f0103b2f:	89 04 24             	mov    %eax,(%esp)
f0103b32:	e8 b0 d8 ff ff       	call   f01013e7 <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103b37:	83 c3 01             	add    $0x1,%ebx
f0103b3a:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f0103b40:	75 d4                	jne    f0103b16 <env_free+0xf6>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f0103b42:	8b 47 60             	mov    0x60(%edi),%eax
f0103b45:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103b48:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103b4f:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103b52:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0103b58:	72 1c                	jb     f0103b76 <env_free+0x156>
		panic("pa2page called with invalid pa");
f0103b5a:	c7 44 24 08 34 6b 10 	movl   $0xf0106b34,0x8(%esp)
f0103b61:	f0 
f0103b62:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103b69:	00 
f0103b6a:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f0103b71:	e8 ca c4 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103b76:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
f0103b7b:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103b7e:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0103b81:	89 04 24             	mov    %eax,(%esp)
f0103b84:	e8 07 d6 ff ff       	call   f0101190 <page_decref>
	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103b89:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f0103b8d:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f0103b94:	0f 85 1b ff ff ff    	jne    f0103ab5 <env_free+0x95>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f0103b9a:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103b9d:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103ba2:	77 20                	ja     f0103bc4 <env_free+0x1a4>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103ba4:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103ba8:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f0103baf:	f0 
f0103bb0:	c7 44 24 04 ca 01 00 	movl   $0x1ca,0x4(%esp)
f0103bb7:	00 
f0103bb8:	c7 04 24 81 74 10 f0 	movl   $0xf0107481,(%esp)
f0103bbf:	e8 7c c4 ff ff       	call   f0100040 <_panic>
	e->env_pgdir = 0;
f0103bc4:	c7 47 60 00 00 00 00 	movl   $0x0,0x60(%edi)
	return (physaddr_t)kva - KERNBASE;
f0103bcb:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103bd0:	c1 e8 0c             	shr    $0xc,%eax
f0103bd3:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0103bd9:	72 1c                	jb     f0103bf7 <env_free+0x1d7>
		panic("pa2page called with invalid pa");
f0103bdb:	c7 44 24 08 34 6b 10 	movl   $0xf0106b34,0x8(%esp)
f0103be2:	f0 
f0103be3:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103bea:	00 
f0103beb:	c7 04 24 79 71 10 f0 	movl   $0xf0107179,(%esp)
f0103bf2:	e8 49 c4 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103bf7:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f0103bfd:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f0103c00:	89 04 24             	mov    %eax,(%esp)
f0103c03:	e8 88 d5 ff ff       	call   f0101190 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f0103c08:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	env_free_list->env_link = e;
f0103c0f:	a1 4c 32 22 f0       	mov    0xf022324c,%eax
f0103c14:	89 78 44             	mov    %edi,0x44(%eax)
	e->env_link = NULL;
f0103c17:	c7 47 44 00 00 00 00 	movl   $0x0,0x44(%edi)
	//e->env_link = env_free_list;
	env_free_list = e;
f0103c1e:	89 3d 4c 32 22 f0    	mov    %edi,0xf022324c
}
f0103c24:	83 c4 2c             	add    $0x2c,%esp
f0103c27:	5b                   	pop    %ebx
f0103c28:	5e                   	pop    %esi
f0103c29:	5f                   	pop    %edi
f0103c2a:	5d                   	pop    %ebp
f0103c2b:	c3                   	ret    

f0103c2c <env_destroy>:
// If e was the current env, then runs a new environment (and does not return
// to the caller).
//
void
env_destroy(struct Env *e)
{
f0103c2c:	55                   	push   %ebp
f0103c2d:	89 e5                	mov    %esp,%ebp
f0103c2f:	53                   	push   %ebx
f0103c30:	83 ec 14             	sub    $0x14,%esp
f0103c33:	8b 5d 08             	mov    0x8(%ebp),%ebx
	// If e is currently running on other CPUs, we change its state to
	// ENV_DYING. A zombie environment will be freed the next time
	// it traps to the kernel.
	if (e->env_status == ENV_RUNNING && curenv != e) {
f0103c36:	83 7b 54 03          	cmpl   $0x3,0x54(%ebx)
f0103c3a:	75 19                	jne    f0103c55 <env_destroy+0x29>
f0103c3c:	e8 f2 20 00 00       	call   f0105d33 <cpunum>
f0103c41:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c44:	39 98 28 40 22 f0    	cmp    %ebx,-0xfddbfd8(%eax)
f0103c4a:	74 09                	je     f0103c55 <env_destroy+0x29>
		e->env_status = ENV_DYING;
f0103c4c:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
		return;
f0103c53:	eb 2f                	jmp    f0103c84 <env_destroy+0x58>
	}

	env_free(e);
f0103c55:	89 1c 24             	mov    %ebx,(%esp)
f0103c58:	e8 c3 fd ff ff       	call   f0103a20 <env_free>

	if (curenv == e) {
f0103c5d:	e8 d1 20 00 00       	call   f0105d33 <cpunum>
f0103c62:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c65:	39 98 28 40 22 f0    	cmp    %ebx,-0xfddbfd8(%eax)
f0103c6b:	75 17                	jne    f0103c84 <env_destroy+0x58>
		curenv = NULL;
f0103c6d:	e8 c1 20 00 00       	call   f0105d33 <cpunum>
f0103c72:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c75:	c7 80 28 40 22 f0 00 	movl   $0x0,-0xfddbfd8(%eax)
f0103c7c:	00 00 00 
		sched_yield();
f0103c7f:	e8 7b 0b 00 00       	call   f01047ff <sched_yield>
	}
}
f0103c84:	83 c4 14             	add    $0x14,%esp
f0103c87:	5b                   	pop    %ebx
f0103c88:	5d                   	pop    %ebp
f0103c89:	c3                   	ret    

f0103c8a <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f0103c8a:	55                   	push   %ebp
f0103c8b:	89 e5                	mov    %esp,%ebp
f0103c8d:	53                   	push   %ebx
f0103c8e:	83 ec 14             	sub    $0x14,%esp
	// Record the CPU we are running on for user-space debugging
	curenv->env_cpunum = cpunum();
f0103c91:	e8 9d 20 00 00       	call   f0105d33 <cpunum>
f0103c96:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c99:	8b 98 28 40 22 f0    	mov    -0xfddbfd8(%eax),%ebx
f0103c9f:	e8 8f 20 00 00       	call   f0105d33 <cpunum>
f0103ca4:	89 43 5c             	mov    %eax,0x5c(%ebx)

	__asm __volatile("movl %0,%%esp\n"
f0103ca7:	8b 65 08             	mov    0x8(%ebp),%esp
f0103caa:	61                   	popa   
f0103cab:	07                   	pop    %es
f0103cac:	1f                   	pop    %ds
f0103cad:	83 c4 08             	add    $0x8,%esp
f0103cb0:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f0103cb1:	c7 44 24 08 17 75 10 	movl   $0xf0107517,0x8(%esp)
f0103cb8:	f0 
f0103cb9:	c7 44 24 04 02 02 00 	movl   $0x202,0x4(%esp)
f0103cc0:	00 
f0103cc1:	c7 04 24 81 74 10 f0 	movl   $0xf0107481,(%esp)
f0103cc8:	e8 73 c3 ff ff       	call   f0100040 <_panic>

f0103ccd <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0103ccd:	55                   	push   %ebp
f0103cce:	89 e5                	mov    %esp,%ebp
f0103cd0:	53                   	push   %ebx
f0103cd1:	83 ec 14             	sub    $0x14,%esp
f0103cd4:	8b 5d 08             	mov    0x8(%ebp),%ebx

	// Hint: This function loads the new environment's state from
	//	e->env_tf.  Go back through the code you wrote above
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.
	if(curenv!=NULL&& curenv->env_status==ENV_RUNNING)
f0103cd7:	e8 57 20 00 00       	call   f0105d33 <cpunum>
f0103cdc:	6b c0 74             	imul   $0x74,%eax,%eax
f0103cdf:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f0103ce6:	74 29                	je     f0103d11 <env_run+0x44>
f0103ce8:	e8 46 20 00 00       	call   f0105d33 <cpunum>
f0103ced:	6b c0 74             	imul   $0x74,%eax,%eax
f0103cf0:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103cf6:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0103cfa:	75 15                	jne    f0103d11 <env_run+0x44>
		curenv->env_status = ENV_RUNNABLE;
f0103cfc:	e8 32 20 00 00       	call   f0105d33 <cpunum>
f0103d01:	6b c0 74             	imul   $0x74,%eax,%eax
f0103d04:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103d0a:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)

	curenv = e;
f0103d11:	e8 1d 20 00 00       	call   f0105d33 <cpunum>
f0103d16:	6b c0 74             	imul   $0x74,%eax,%eax
f0103d19:	89 98 28 40 22 f0    	mov    %ebx,-0xfddbfd8(%eax)
	int zero = 0;
	e->env_status = ENV_RUNNING;
f0103d1f:	c7 43 54 03 00 00 00 	movl   $0x3,0x54(%ebx)
	e->env_runs++;
f0103d26:	83 43 58 01          	addl   $0x1,0x58(%ebx)
	lcr3(PADDR(e->env_pgdir));
f0103d2a:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103d2d:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103d32:	77 20                	ja     f0103d54 <env_run+0x87>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103d34:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103d38:	c7 44 24 08 88 64 10 	movl   $0xf0106488,0x8(%esp)
f0103d3f:	f0 
f0103d40:	c7 44 24 04 25 02 00 	movl   $0x225,0x4(%esp)
f0103d47:	00 
f0103d48:	c7 04 24 81 74 10 f0 	movl   $0xf0107481,(%esp)
f0103d4f:	e8 ec c2 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103d54:	05 00 00 00 10       	add    $0x10000000,%eax
f0103d59:	0f 22 d8             	mov    %eax,%cr3
}

static inline void
unlock_kernel(void)
{
	spin_unlock(&kernel_lock);
f0103d5c:	c7 04 24 a0 03 12 f0 	movl   $0xf01203a0,(%esp)
f0103d63:	e8 14 23 00 00       	call   f010607c <spin_unlock>

	// Normally we wouldn't need to do this, but QEMU only runs
	// one CPU at a time and has a long time-slice.  Without the
	// pause, this CPU is likely to reacquire the lock before
	// another CPU has even been given a chance to acquire it.
	asm volatile("pause");
f0103d68:	f3 90                	pause  
	unlock_kernel();
	env_pop_tf(&e->env_tf);
f0103d6a:	89 1c 24             	mov    %ebx,(%esp)
f0103d6d:	e8 18 ff ff ff       	call   f0103c8a <env_pop_tf>

f0103d72 <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0103d72:	55                   	push   %ebp
f0103d73:	89 e5                	mov    %esp,%ebp
f0103d75:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103d79:	ba 70 00 00 00       	mov    $0x70,%edx
f0103d7e:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0103d7f:	b2 71                	mov    $0x71,%dl
f0103d81:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0103d82:	0f b6 c0             	movzbl %al,%eax
}
f0103d85:	5d                   	pop    %ebp
f0103d86:	c3                   	ret    

f0103d87 <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0103d87:	55                   	push   %ebp
f0103d88:	89 e5                	mov    %esp,%ebp
f0103d8a:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103d8e:	ba 70 00 00 00       	mov    $0x70,%edx
f0103d93:	ee                   	out    %al,(%dx)
f0103d94:	b2 71                	mov    $0x71,%dl
f0103d96:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103d99:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0103d9a:	5d                   	pop    %ebp
f0103d9b:	c3                   	ret    

f0103d9c <irq_setmask_8259A>:
		irq_setmask_8259A(irq_mask_8259A);
}

void
irq_setmask_8259A(uint16_t mask)
{
f0103d9c:	55                   	push   %ebp
f0103d9d:	89 e5                	mov    %esp,%ebp
f0103d9f:	56                   	push   %esi
f0103da0:	53                   	push   %ebx
f0103da1:	83 ec 10             	sub    $0x10,%esp
f0103da4:	8b 45 08             	mov    0x8(%ebp),%eax
	int i;
	irq_mask_8259A = mask;
f0103da7:	66 a3 88 03 12 f0    	mov    %ax,0xf0120388
	if (!didinit)
f0103dad:	83 3d 50 32 22 f0 00 	cmpl   $0x0,0xf0223250
f0103db4:	74 4e                	je     f0103e04 <irq_setmask_8259A+0x68>
f0103db6:	89 c6                	mov    %eax,%esi
f0103db8:	ba 21 00 00 00       	mov    $0x21,%edx
f0103dbd:	ee                   	out    %al,(%dx)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
f0103dbe:	66 c1 e8 08          	shr    $0x8,%ax
f0103dc2:	b2 a1                	mov    $0xa1,%dl
f0103dc4:	ee                   	out    %al,(%dx)
	cprintf("enabled interrupts:");
f0103dc5:	c7 04 24 23 75 10 f0 	movl   $0xf0107523,(%esp)
f0103dcc:	e8 0d 01 00 00       	call   f0103ede <cprintf>
	for (i = 0; i < 16; i++)
f0103dd1:	bb 00 00 00 00       	mov    $0x0,%ebx
		if (~mask & (1<<i))
f0103dd6:	0f b7 f6             	movzwl %si,%esi
f0103dd9:	f7 d6                	not    %esi
f0103ddb:	0f a3 de             	bt     %ebx,%esi
f0103dde:	73 10                	jae    f0103df0 <irq_setmask_8259A+0x54>
			cprintf(" %d", i);
f0103de0:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103de4:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f0103deb:	e8 ee 00 00 00       	call   f0103ede <cprintf>
	if (!didinit)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
	cprintf("enabled interrupts:");
	for (i = 0; i < 16; i++)
f0103df0:	83 c3 01             	add    $0x1,%ebx
f0103df3:	83 fb 10             	cmp    $0x10,%ebx
f0103df6:	75 e3                	jne    f0103ddb <irq_setmask_8259A+0x3f>
		if (~mask & (1<<i))
			cprintf(" %d", i);
	cprintf("\n");
f0103df8:	c7 04 24 ff 74 10 f0 	movl   $0xf01074ff,(%esp)
f0103dff:	e8 da 00 00 00       	call   f0103ede <cprintf>
}
f0103e04:	83 c4 10             	add    $0x10,%esp
f0103e07:	5b                   	pop    %ebx
f0103e08:	5e                   	pop    %esi
f0103e09:	5d                   	pop    %ebp
f0103e0a:	c3                   	ret    

f0103e0b <pic_init>:

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
	didinit = 1;
f0103e0b:	c7 05 50 32 22 f0 01 	movl   $0x1,0xf0223250
f0103e12:	00 00 00 
f0103e15:	ba 21 00 00 00       	mov    $0x21,%edx
f0103e1a:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0103e1f:	ee                   	out    %al,(%dx)
f0103e20:	b2 a1                	mov    $0xa1,%dl
f0103e22:	ee                   	out    %al,(%dx)
f0103e23:	b2 20                	mov    $0x20,%dl
f0103e25:	b8 11 00 00 00       	mov    $0x11,%eax
f0103e2a:	ee                   	out    %al,(%dx)
f0103e2b:	b2 21                	mov    $0x21,%dl
f0103e2d:	b8 20 00 00 00       	mov    $0x20,%eax
f0103e32:	ee                   	out    %al,(%dx)
f0103e33:	b8 04 00 00 00       	mov    $0x4,%eax
f0103e38:	ee                   	out    %al,(%dx)
f0103e39:	b8 03 00 00 00       	mov    $0x3,%eax
f0103e3e:	ee                   	out    %al,(%dx)
f0103e3f:	b2 a0                	mov    $0xa0,%dl
f0103e41:	b8 11 00 00 00       	mov    $0x11,%eax
f0103e46:	ee                   	out    %al,(%dx)
f0103e47:	b2 a1                	mov    $0xa1,%dl
f0103e49:	b8 28 00 00 00       	mov    $0x28,%eax
f0103e4e:	ee                   	out    %al,(%dx)
f0103e4f:	b8 02 00 00 00       	mov    $0x2,%eax
f0103e54:	ee                   	out    %al,(%dx)
f0103e55:	b8 01 00 00 00       	mov    $0x1,%eax
f0103e5a:	ee                   	out    %al,(%dx)
f0103e5b:	b2 20                	mov    $0x20,%dl
f0103e5d:	b8 68 00 00 00       	mov    $0x68,%eax
f0103e62:	ee                   	out    %al,(%dx)
f0103e63:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103e68:	ee                   	out    %al,(%dx)
f0103e69:	b2 a0                	mov    $0xa0,%dl
f0103e6b:	b8 68 00 00 00       	mov    $0x68,%eax
f0103e70:	ee                   	out    %al,(%dx)
f0103e71:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103e76:	ee                   	out    %al,(%dx)
	outb(IO_PIC1, 0x0a);             /* read IRR by default */

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
f0103e77:	0f b7 05 88 03 12 f0 	movzwl 0xf0120388,%eax
f0103e7e:	66 83 f8 ff          	cmp    $0xffff,%ax
f0103e82:	74 12                	je     f0103e96 <pic_init+0x8b>
static bool didinit;

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
f0103e84:	55                   	push   %ebp
f0103e85:	89 e5                	mov    %esp,%ebp
f0103e87:	83 ec 18             	sub    $0x18,%esp

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
		irq_setmask_8259A(irq_mask_8259A);
f0103e8a:	0f b7 c0             	movzwl %ax,%eax
f0103e8d:	89 04 24             	mov    %eax,(%esp)
f0103e90:	e8 07 ff ff ff       	call   f0103d9c <irq_setmask_8259A>
}
f0103e95:	c9                   	leave  
f0103e96:	f3 c3                	repz ret 

f0103e98 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0103e98:	55                   	push   %ebp
f0103e99:	89 e5                	mov    %esp,%ebp
f0103e9b:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0103e9e:	8b 45 08             	mov    0x8(%ebp),%eax
f0103ea1:	89 04 24             	mov    %eax,(%esp)
f0103ea4:	e8 34 c9 ff ff       	call   f01007dd <cputchar>
	*cnt++;
}
f0103ea9:	c9                   	leave  
f0103eaa:	c3                   	ret    

f0103eab <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0103eab:	55                   	push   %ebp
f0103eac:	89 e5                	mov    %esp,%ebp
f0103eae:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0103eb1:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0103eb8:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103ebb:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103ebf:	8b 45 08             	mov    0x8(%ebp),%eax
f0103ec2:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103ec6:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0103ec9:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103ecd:	c7 04 24 98 3e 10 f0 	movl   $0xf0103e98,(%esp)
f0103ed4:	e8 7b 10 00 00       	call   f0104f54 <vprintfmt>
	return cnt;
}
f0103ed9:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0103edc:	c9                   	leave  
f0103edd:	c3                   	ret    

f0103ede <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0103ede:	55                   	push   %ebp
f0103edf:	89 e5                	mov    %esp,%ebp
f0103ee1:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0103ee4:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0103ee7:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103eeb:	8b 45 08             	mov    0x8(%ebp),%eax
f0103eee:	89 04 24             	mov    %eax,(%esp)
f0103ef1:	e8 b5 ff ff ff       	call   f0103eab <vcprintf>
	va_end(ap);

	return cnt;
}
f0103ef6:	c9                   	leave  
f0103ef7:	c3                   	ret    
f0103ef8:	66 90                	xchg   %ax,%ax
f0103efa:	66 90                	xchg   %ax,%ax
f0103efc:	66 90                	xchg   %ax,%ax
f0103efe:	66 90                	xchg   %ax,%ax

f0103f00 <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f0103f00:	55                   	push   %ebp
f0103f01:	89 e5                	mov    %esp,%ebp
f0103f03:	53                   	push   %ebx
f0103f04:	83 ec 04             	sub    $0x4,%esp
	struct Taskstate* this_ts = &thiscpu->cpu_ts;
f0103f07:	e8 27 1e 00 00       	call   f0105d33 <cpunum>
f0103f0c:	6b d8 74             	imul   $0x74,%eax,%ebx
	int CPUID = cpunum();
f0103f0f:	e8 1f 1e 00 00       	call   f0105d33 <cpunum>

	this_ts->ts_esp0 = KSTACKTOP - CPUID * (KSTKGAP + KSTKSIZE);
f0103f14:	89 c2                	mov    %eax,%edx
f0103f16:	f7 da                	neg    %edx
f0103f18:	c1 e2 10             	shl    $0x10,%edx
f0103f1b:	81 ea 00 00 40 10    	sub    $0x10400000,%edx
f0103f21:	89 93 30 40 22 f0    	mov    %edx,-0xfddbfd0(%ebx)
	this_ts->ts_ss0 = GD_KD;
f0103f27:	66 c7 83 34 40 22 f0 	movw   $0x10,-0xfddbfcc(%ebx)
f0103f2e:	10 00 

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
	struct Taskstate* this_ts = &thiscpu->cpu_ts;
f0103f30:	81 c3 2c 40 22 f0    	add    $0xf022402c,%ebx
	int CPUID = cpunum();

	this_ts->ts_esp0 = KSTACKTOP - CPUID * (KSTKGAP + KSTKSIZE);
	this_ts->ts_ss0 = GD_KD;

	gdt[(GD_TSS0 >> 3) + CPUID] = SEG16(STS_T32A, (uint32_t) (this_ts),
f0103f36:	8d 50 05             	lea    0x5(%eax),%edx
f0103f39:	66 c7 04 d5 20 03 12 	movw   $0x68,-0xfedfce0(,%edx,8)
f0103f40:	f0 68 00 
f0103f43:	66 89 1c d5 22 03 12 	mov    %bx,-0xfedfcde(,%edx,8)
f0103f4a:	f0 
f0103f4b:	89 d9                	mov    %ebx,%ecx
f0103f4d:	c1 e9 10             	shr    $0x10,%ecx
f0103f50:	88 0c d5 24 03 12 f0 	mov    %cl,-0xfedfcdc(,%edx,8)
f0103f57:	c6 04 d5 26 03 12 f0 	movb   $0x40,-0xfedfcda(,%edx,8)
f0103f5e:	40 
f0103f5f:	c1 eb 18             	shr    $0x18,%ebx
f0103f62:	88 1c d5 27 03 12 f0 	mov    %bl,-0xfedfcd9(,%edx,8)
					sizeof(struct Taskstate), 0);
	gdt[(GD_TSS0 >> 3) + CPUID].sd_s = 0;
f0103f69:	c6 04 d5 25 03 12 f0 	movb   $0x89,-0xfedfcdb(,%edx,8)
f0103f70:	89 

	//cprintf("Loading GD_TSS_ %d\n", ((GD_TSS0>>3) + CPUID)<<3);

	ltr(GD_TSS0 + (CPUID << 3));
f0103f71:	8d 04 c5 28 00 00 00 	lea    0x28(,%eax,8),%eax
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f0103f78:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f0103f7b:	b8 8a 03 12 f0       	mov    $0xf012038a,%eax
f0103f80:	0f 01 18             	lidtl  (%eax)
	// bottom three bits are special; we leave them 0)
	ltr(GD_TSS0+(cpu_id<<3));

	// Load the IDT
	lidt(&idt_pd);*/
}
f0103f83:	83 c4 04             	add    $0x4,%esp
f0103f86:	5b                   	pop    %ebx
f0103f87:	5d                   	pop    %ebp
f0103f88:	c3                   	ret    

f0103f89 <trap_init>:
}


void
trap_init(void)
{
f0103f89:	55                   	push   %ebp
f0103f8a:	89 e5                	mov    %esp,%ebp
f0103f8c:	83 ec 08             	sub    $0x8,%esp
	extern struct Segdesc gdt[];
	SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);
f0103f8f:	b8 68 47 10 f0       	mov    $0xf0104768,%eax
f0103f94:	66 a3 60 32 22 f0    	mov    %ax,0xf0223260
f0103f9a:	66 c7 05 62 32 22 f0 	movw   $0x8,0xf0223262
f0103fa1:	08 00 
f0103fa3:	c6 05 64 32 22 f0 00 	movb   $0x0,0xf0223264
f0103faa:	c6 05 65 32 22 f0 8f 	movb   $0x8f,0xf0223265
f0103fb1:	c1 e8 10             	shr    $0x10,%eax
f0103fb4:	66 a3 66 32 22 f0    	mov    %ax,0xf0223266
	SETGATE(idt[2], 0, GD_KT, nmi_handler, 0);
f0103fba:	b8 6e 47 10 f0       	mov    $0xf010476e,%eax
f0103fbf:	66 a3 70 32 22 f0    	mov    %ax,0xf0223270
f0103fc5:	66 c7 05 72 32 22 f0 	movw   $0x8,0xf0223272
f0103fcc:	08 00 
f0103fce:	c6 05 74 32 22 f0 00 	movb   $0x0,0xf0223274
f0103fd5:	c6 05 75 32 22 f0 8e 	movb   $0x8e,0xf0223275
f0103fdc:	c1 e8 10             	shr    $0x10,%eax
f0103fdf:	66 a3 76 32 22 f0    	mov    %ax,0xf0223276
	SETGATE(idt[3], 1, GD_KT, breakpoint_handler, 3);
f0103fe5:	b8 74 47 10 f0       	mov    $0xf0104774,%eax
f0103fea:	66 a3 78 32 22 f0    	mov    %ax,0xf0223278
f0103ff0:	66 c7 05 7a 32 22 f0 	movw   $0x8,0xf022327a
f0103ff7:	08 00 
f0103ff9:	c6 05 7c 32 22 f0 00 	movb   $0x0,0xf022327c
f0104000:	c6 05 7d 32 22 f0 ef 	movb   $0xef,0xf022327d
f0104007:	c1 e8 10             	shr    $0x10,%eax
f010400a:	66 a3 7e 32 22 f0    	mov    %ax,0xf022327e
	SETGATE(idt[4], 1, GD_KT, overflow_handler, 3);
f0104010:	b8 7a 47 10 f0       	mov    $0xf010477a,%eax
f0104015:	66 a3 80 32 22 f0    	mov    %ax,0xf0223280
f010401b:	66 c7 05 82 32 22 f0 	movw   $0x8,0xf0223282
f0104022:	08 00 
f0104024:	c6 05 84 32 22 f0 00 	movb   $0x0,0xf0223284
f010402b:	c6 05 85 32 22 f0 ef 	movb   $0xef,0xf0223285
f0104032:	c1 e8 10             	shr    $0x10,%eax
f0104035:	66 a3 86 32 22 f0    	mov    %ax,0xf0223286
	SETGATE(idt[5], 1, GD_KT, bdrgeexceed_handler, 3);
f010403b:	b8 80 47 10 f0       	mov    $0xf0104780,%eax
f0104040:	66 a3 88 32 22 f0    	mov    %ax,0xf0223288
f0104046:	66 c7 05 8a 32 22 f0 	movw   $0x8,0xf022328a
f010404d:	08 00 
f010404f:	c6 05 8c 32 22 f0 00 	movb   $0x0,0xf022328c
f0104056:	c6 05 8d 32 22 f0 ef 	movb   $0xef,0xf022328d
f010405d:	c1 e8 10             	shr    $0x10,%eax
f0104060:	66 a3 8e 32 22 f0    	mov    %ax,0xf022328e
	SETGATE(idt[6], 1, GD_KT, invalidop_handler, 0);
f0104066:	b8 86 47 10 f0       	mov    $0xf0104786,%eax
f010406b:	66 a3 90 32 22 f0    	mov    %ax,0xf0223290
f0104071:	66 c7 05 92 32 22 f0 	movw   $0x8,0xf0223292
f0104078:	08 00 
f010407a:	c6 05 94 32 22 f0 00 	movb   $0x0,0xf0223294
f0104081:	c6 05 95 32 22 f0 8f 	movb   $0x8f,0xf0223295
f0104088:	c1 e8 10             	shr    $0x10,%eax
f010408b:	66 a3 96 32 22 f0    	mov    %ax,0xf0223296
	SETGATE(idt[7], 1, GD_KT, nomathcopro_handler, 0);
f0104091:	b8 8c 47 10 f0       	mov    $0xf010478c,%eax
f0104096:	66 a3 98 32 22 f0    	mov    %ax,0xf0223298
f010409c:	66 c7 05 9a 32 22 f0 	movw   $0x8,0xf022329a
f01040a3:	08 00 
f01040a5:	c6 05 9c 32 22 f0 00 	movb   $0x0,0xf022329c
f01040ac:	c6 05 9d 32 22 f0 8f 	movb   $0x8f,0xf022329d
f01040b3:	c1 e8 10             	shr    $0x10,%eax
f01040b6:	66 a3 9e 32 22 f0    	mov    %ax,0xf022329e
	SETGATE(idt[8], 1, GD_KT, dbfault_handler, 0);
f01040bc:	b8 92 47 10 f0       	mov    $0xf0104792,%eax
f01040c1:	66 a3 a0 32 22 f0    	mov    %ax,0xf02232a0
f01040c7:	66 c7 05 a2 32 22 f0 	movw   $0x8,0xf02232a2
f01040ce:	08 00 
f01040d0:	c6 05 a4 32 22 f0 00 	movb   $0x0,0xf02232a4
f01040d7:	c6 05 a5 32 22 f0 8f 	movb   $0x8f,0xf02232a5
f01040de:	c1 e8 10             	shr    $0x10,%eax
f01040e1:	66 a3 a6 32 22 f0    	mov    %ax,0xf02232a6
	SETGATE(idt[10], 1, GD_KT, invalidTSS_handler, 0);
f01040e7:	b8 96 47 10 f0       	mov    $0xf0104796,%eax
f01040ec:	66 a3 b0 32 22 f0    	mov    %ax,0xf02232b0
f01040f2:	66 c7 05 b2 32 22 f0 	movw   $0x8,0xf02232b2
f01040f9:	08 00 
f01040fb:	c6 05 b4 32 22 f0 00 	movb   $0x0,0xf02232b4
f0104102:	c6 05 b5 32 22 f0 8f 	movb   $0x8f,0xf02232b5
f0104109:	c1 e8 10             	shr    $0x10,%eax
f010410c:	66 a3 b6 32 22 f0    	mov    %ax,0xf02232b6

	SETGATE(idt[11], 1, GD_KT, sgmtnotpresent_handler, 0);
f0104112:	b8 9a 47 10 f0       	mov    $0xf010479a,%eax
f0104117:	66 a3 b8 32 22 f0    	mov    %ax,0xf02232b8
f010411d:	66 c7 05 ba 32 22 f0 	movw   $0x8,0xf02232ba
f0104124:	08 00 
f0104126:	c6 05 bc 32 22 f0 00 	movb   $0x0,0xf02232bc
f010412d:	c6 05 bd 32 22 f0 8f 	movb   $0x8f,0xf02232bd
f0104134:	c1 e8 10             	shr    $0x10,%eax
f0104137:	66 a3 be 32 22 f0    	mov    %ax,0xf02232be
	SETGATE(idt[12], 1, GD_KT, stacksgmtfault_handler, 0);
f010413d:	b8 9e 47 10 f0       	mov    $0xf010479e,%eax
f0104142:	66 a3 c0 32 22 f0    	mov    %ax,0xf02232c0
f0104148:	66 c7 05 c2 32 22 f0 	movw   $0x8,0xf02232c2
f010414f:	08 00 
f0104151:	c6 05 c4 32 22 f0 00 	movb   $0x0,0xf02232c4
f0104158:	c6 05 c5 32 22 f0 8f 	movb   $0x8f,0xf02232c5
f010415f:	c1 e8 10             	shr    $0x10,%eax
f0104162:	66 a3 c6 32 22 f0    	mov    %ax,0xf02232c6
	SETGATE(idt[14], 1, GD_KT, pagefault_handler, 0);
f0104168:	b8 a6 47 10 f0       	mov    $0xf01047a6,%eax
f010416d:	66 a3 d0 32 22 f0    	mov    %ax,0xf02232d0
f0104173:	66 c7 05 d2 32 22 f0 	movw   $0x8,0xf02232d2
f010417a:	08 00 
f010417c:	c6 05 d4 32 22 f0 00 	movb   $0x0,0xf02232d4
f0104183:	c6 05 d5 32 22 f0 8f 	movb   $0x8f,0xf02232d5
f010418a:	c1 e8 10             	shr    $0x10,%eax
f010418d:	66 a3 d6 32 22 f0    	mov    %ax,0xf02232d6
	SETGATE(idt[13], 1, GD_KT, generalprotection_handler, 0);
f0104193:	b8 a2 47 10 f0       	mov    $0xf01047a2,%eax
f0104198:	66 a3 c8 32 22 f0    	mov    %ax,0xf02232c8
f010419e:	66 c7 05 ca 32 22 f0 	movw   $0x8,0xf02232ca
f01041a5:	08 00 
f01041a7:	c6 05 cc 32 22 f0 00 	movb   $0x0,0xf02232cc
f01041ae:	c6 05 cd 32 22 f0 8f 	movb   $0x8f,0xf02232cd
f01041b5:	c1 e8 10             	shr    $0x10,%eax
f01041b8:	66 a3 ce 32 22 f0    	mov    %ax,0xf02232ce
	SETGATE(idt[16], 1, GD_KT, FPUerror_handler, 0);
f01041be:	b8 aa 47 10 f0       	mov    $0xf01047aa,%eax
f01041c3:	66 a3 e0 32 22 f0    	mov    %ax,0xf02232e0
f01041c9:	66 c7 05 e2 32 22 f0 	movw   $0x8,0xf02232e2
f01041d0:	08 00 
f01041d2:	c6 05 e4 32 22 f0 00 	movb   $0x0,0xf02232e4
f01041d9:	c6 05 e5 32 22 f0 8f 	movb   $0x8f,0xf02232e5
f01041e0:	c1 e8 10             	shr    $0x10,%eax
f01041e3:	66 a3 e6 32 22 f0    	mov    %ax,0xf02232e6
	SETGATE(idt[17], 1, GD_KT, alignmentcheck_handler, 0);
f01041e9:	b8 b0 47 10 f0       	mov    $0xf01047b0,%eax
f01041ee:	66 a3 e8 32 22 f0    	mov    %ax,0xf02232e8
f01041f4:	66 c7 05 ea 32 22 f0 	movw   $0x8,0xf02232ea
f01041fb:	08 00 
f01041fd:	c6 05 ec 32 22 f0 00 	movb   $0x0,0xf02232ec
f0104204:	c6 05 ed 32 22 f0 8f 	movb   $0x8f,0xf02232ed
f010420b:	c1 e8 10             	shr    $0x10,%eax
f010420e:	66 a3 ee 32 22 f0    	mov    %ax,0xf02232ee
	SETGATE(idt[18],1, GD_KT, machinecheck_handler, 0);
f0104214:	b8 b4 47 10 f0       	mov    $0xf01047b4,%eax
f0104219:	66 a3 f0 32 22 f0    	mov    %ax,0xf02232f0
f010421f:	66 c7 05 f2 32 22 f0 	movw   $0x8,0xf02232f2
f0104226:	08 00 
f0104228:	c6 05 f4 32 22 f0 00 	movb   $0x0,0xf02232f4
f010422f:	c6 05 f5 32 22 f0 8f 	movb   $0x8f,0xf02232f5
f0104236:	c1 e8 10             	shr    $0x10,%eax
f0104239:	66 a3 f6 32 22 f0    	mov    %ax,0xf02232f6
	SETGATE(idt[19], 1, GD_KT, SIMDFPexception_handler, 0);
f010423f:	b8 ba 47 10 f0       	mov    $0xf01047ba,%eax
f0104244:	66 a3 f8 32 22 f0    	mov    %ax,0xf02232f8
f010424a:	66 c7 05 fa 32 22 f0 	movw   $0x8,0xf02232fa
f0104251:	08 00 
f0104253:	c6 05 fc 32 22 f0 00 	movb   $0x0,0xf02232fc
f010425a:	c6 05 fd 32 22 f0 8f 	movb   $0x8f,0xf02232fd
f0104261:	c1 e8 10             	shr    $0x10,%eax
f0104264:	66 a3 fe 32 22 f0    	mov    %ax,0xf02232fe
	SETGATE(idt[48], 0, GD_KT, systemcall_handler, 3);
f010426a:	b8 c0 47 10 f0       	mov    $0xf01047c0,%eax
f010426f:	66 a3 e0 33 22 f0    	mov    %ax,0xf02233e0
f0104275:	66 c7 05 e2 33 22 f0 	movw   $0x8,0xf02233e2
f010427c:	08 00 
f010427e:	c6 05 e4 33 22 f0 00 	movb   $0x0,0xf02233e4
f0104285:	c6 05 e5 33 22 f0 ee 	movb   $0xee,0xf02233e5
f010428c:	c1 e8 10             	shr    $0x10,%eax
f010428f:	66 a3 e6 33 22 f0    	mov    %ax,0xf02233e6
	// LAB 3: Your code here.

	// Per-CPU setup 
	trap_init_percpu();
f0104295:	e8 66 fc ff ff       	call   f0103f00 <trap_init_percpu>
}
f010429a:	c9                   	leave  
f010429b:	c3                   	ret    

f010429c <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f010429c:	55                   	push   %ebp
f010429d:	89 e5                	mov    %esp,%ebp
f010429f:	53                   	push   %ebx
f01042a0:	83 ec 14             	sub    $0x14,%esp
f01042a3:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f01042a6:	8b 03                	mov    (%ebx),%eax
f01042a8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01042ac:	c7 04 24 37 75 10 f0 	movl   $0xf0107537,(%esp)
f01042b3:	e8 26 fc ff ff       	call   f0103ede <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f01042b8:	8b 43 04             	mov    0x4(%ebx),%eax
f01042bb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01042bf:	c7 04 24 46 75 10 f0 	movl   $0xf0107546,(%esp)
f01042c6:	e8 13 fc ff ff       	call   f0103ede <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f01042cb:	8b 43 08             	mov    0x8(%ebx),%eax
f01042ce:	89 44 24 04          	mov    %eax,0x4(%esp)
f01042d2:	c7 04 24 55 75 10 f0 	movl   $0xf0107555,(%esp)
f01042d9:	e8 00 fc ff ff       	call   f0103ede <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f01042de:	8b 43 0c             	mov    0xc(%ebx),%eax
f01042e1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01042e5:	c7 04 24 64 75 10 f0 	movl   $0xf0107564,(%esp)
f01042ec:	e8 ed fb ff ff       	call   f0103ede <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f01042f1:	8b 43 10             	mov    0x10(%ebx),%eax
f01042f4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01042f8:	c7 04 24 73 75 10 f0 	movl   $0xf0107573,(%esp)
f01042ff:	e8 da fb ff ff       	call   f0103ede <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0104304:	8b 43 14             	mov    0x14(%ebx),%eax
f0104307:	89 44 24 04          	mov    %eax,0x4(%esp)
f010430b:	c7 04 24 82 75 10 f0 	movl   $0xf0107582,(%esp)
f0104312:	e8 c7 fb ff ff       	call   f0103ede <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f0104317:	8b 43 18             	mov    0x18(%ebx),%eax
f010431a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010431e:	c7 04 24 91 75 10 f0 	movl   $0xf0107591,(%esp)
f0104325:	e8 b4 fb ff ff       	call   f0103ede <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f010432a:	8b 43 1c             	mov    0x1c(%ebx),%eax
f010432d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104331:	c7 04 24 a0 75 10 f0 	movl   $0xf01075a0,(%esp)
f0104338:	e8 a1 fb ff ff       	call   f0103ede <cprintf>
}
f010433d:	83 c4 14             	add    $0x14,%esp
f0104340:	5b                   	pop    %ebx
f0104341:	5d                   	pop    %ebp
f0104342:	c3                   	ret    

f0104343 <print_trapframe>:
	lidt(&idt_pd);*/
}

void
print_trapframe(struct Trapframe *tf)
{
f0104343:	55                   	push   %ebp
f0104344:	89 e5                	mov    %esp,%ebp
f0104346:	56                   	push   %esi
f0104347:	53                   	push   %ebx
f0104348:	83 ec 10             	sub    $0x10,%esp
f010434b:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
f010434e:	e8 e0 19 00 00       	call   f0105d33 <cpunum>
f0104353:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104357:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010435b:	c7 04 24 04 76 10 f0 	movl   $0xf0107604,(%esp)
f0104362:	e8 77 fb ff ff       	call   f0103ede <cprintf>
	print_regs(&tf->tf_regs);
f0104367:	89 1c 24             	mov    %ebx,(%esp)
f010436a:	e8 2d ff ff ff       	call   f010429c <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f010436f:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f0104373:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104377:	c7 04 24 22 76 10 f0 	movl   $0xf0107622,(%esp)
f010437e:	e8 5b fb ff ff       	call   f0103ede <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f0104383:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f0104387:	89 44 24 04          	mov    %eax,0x4(%esp)
f010438b:	c7 04 24 35 76 10 f0 	movl   $0xf0107635,(%esp)
f0104392:	e8 47 fb ff ff       	call   f0103ede <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0104397:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f010439a:	83 f8 13             	cmp    $0x13,%eax
f010439d:	77 09                	ja     f01043a8 <print_trapframe+0x65>
		return excnames[trapno];
f010439f:	8b 14 85 e0 78 10 f0 	mov    -0xfef8720(,%eax,4),%edx
f01043a6:	eb 1f                	jmp    f01043c7 <print_trapframe+0x84>
	if (trapno == T_SYSCALL)
f01043a8:	83 f8 30             	cmp    $0x30,%eax
f01043ab:	74 15                	je     f01043c2 <print_trapframe+0x7f>
		return "System call";
	if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16)
f01043ad:	8d 50 e0             	lea    -0x20(%eax),%edx
		return "Hardware Interrupt";
f01043b0:	83 fa 0f             	cmp    $0xf,%edx
f01043b3:	ba bb 75 10 f0       	mov    $0xf01075bb,%edx
f01043b8:	b9 ce 75 10 f0       	mov    $0xf01075ce,%ecx
f01043bd:	0f 47 d1             	cmova  %ecx,%edx
f01043c0:	eb 05                	jmp    f01043c7 <print_trapframe+0x84>
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
		return excnames[trapno];
	if (trapno == T_SYSCALL)
		return "System call";
f01043c2:	ba af 75 10 f0       	mov    $0xf01075af,%edx
{
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f01043c7:	89 54 24 08          	mov    %edx,0x8(%esp)
f01043cb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01043cf:	c7 04 24 48 76 10 f0 	movl   $0xf0107648,(%esp)
f01043d6:	e8 03 fb ff ff       	call   f0103ede <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f01043db:	3b 1d 60 3a 22 f0    	cmp    0xf0223a60,%ebx
f01043e1:	75 19                	jne    f01043fc <print_trapframe+0xb9>
f01043e3:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f01043e7:	75 13                	jne    f01043fc <print_trapframe+0xb9>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f01043e9:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f01043ec:	89 44 24 04          	mov    %eax,0x4(%esp)
f01043f0:	c7 04 24 5a 76 10 f0 	movl   $0xf010765a,(%esp)
f01043f7:	e8 e2 fa ff ff       	call   f0103ede <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f01043fc:	8b 43 2c             	mov    0x2c(%ebx),%eax
f01043ff:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104403:	c7 04 24 69 76 10 f0 	movl   $0xf0107669,(%esp)
f010440a:	e8 cf fa ff ff       	call   f0103ede <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f010440f:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104413:	75 51                	jne    f0104466 <print_trapframe+0x123>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f0104415:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f0104418:	89 c2                	mov    %eax,%edx
f010441a:	83 e2 01             	and    $0x1,%edx
f010441d:	ba dd 75 10 f0       	mov    $0xf01075dd,%edx
f0104422:	b9 e8 75 10 f0       	mov    $0xf01075e8,%ecx
f0104427:	0f 45 ca             	cmovne %edx,%ecx
f010442a:	89 c2                	mov    %eax,%edx
f010442c:	83 e2 02             	and    $0x2,%edx
f010442f:	ba f4 75 10 f0       	mov    $0xf01075f4,%edx
f0104434:	be fa 75 10 f0       	mov    $0xf01075fa,%esi
f0104439:	0f 44 d6             	cmove  %esi,%edx
f010443c:	83 e0 04             	and    $0x4,%eax
f010443f:	b8 ff 75 10 f0       	mov    $0xf01075ff,%eax
f0104444:	be 69 77 10 f0       	mov    $0xf0107769,%esi
f0104449:	0f 44 c6             	cmove  %esi,%eax
f010444c:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0104450:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104454:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104458:	c7 04 24 77 76 10 f0 	movl   $0xf0107677,(%esp)
f010445f:	e8 7a fa ff ff       	call   f0103ede <cprintf>
f0104464:	eb 0c                	jmp    f0104472 <print_trapframe+0x12f>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f0104466:	c7 04 24 ff 74 10 f0 	movl   $0xf01074ff,(%esp)
f010446d:	e8 6c fa ff ff       	call   f0103ede <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f0104472:	8b 43 30             	mov    0x30(%ebx),%eax
f0104475:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104479:	c7 04 24 86 76 10 f0 	movl   $0xf0107686,(%esp)
f0104480:	e8 59 fa ff ff       	call   f0103ede <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f0104485:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f0104489:	89 44 24 04          	mov    %eax,0x4(%esp)
f010448d:	c7 04 24 95 76 10 f0 	movl   $0xf0107695,(%esp)
f0104494:	e8 45 fa ff ff       	call   f0103ede <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f0104499:	8b 43 38             	mov    0x38(%ebx),%eax
f010449c:	89 44 24 04          	mov    %eax,0x4(%esp)
f01044a0:	c7 04 24 a8 76 10 f0 	movl   $0xf01076a8,(%esp)
f01044a7:	e8 32 fa ff ff       	call   f0103ede <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f01044ac:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f01044b0:	74 27                	je     f01044d9 <print_trapframe+0x196>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f01044b2:	8b 43 3c             	mov    0x3c(%ebx),%eax
f01044b5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01044b9:	c7 04 24 b7 76 10 f0 	movl   $0xf01076b7,(%esp)
f01044c0:	e8 19 fa ff ff       	call   f0103ede <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f01044c5:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f01044c9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01044cd:	c7 04 24 c6 76 10 f0 	movl   $0xf01076c6,(%esp)
f01044d4:	e8 05 fa ff ff       	call   f0103ede <cprintf>
	}
}
f01044d9:	83 c4 10             	add    $0x10,%esp
f01044dc:	5b                   	pop    %ebx
f01044dd:	5e                   	pop    %esi
f01044de:	5d                   	pop    %ebp
f01044df:	c3                   	ret    

f01044e0 <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f01044e0:	55                   	push   %ebp
f01044e1:	89 e5                	mov    %esp,%ebp
f01044e3:	56                   	push   %esi
f01044e4:	53                   	push   %ebx
f01044e5:	83 ec 10             	sub    $0x10,%esp
f01044e8:	8b 45 08             	mov    0x8(%ebp),%eax
f01044eb:	0f 20 d3             	mov    %cr2,%ebx
	uint32_t fault_va;

	// Read processor's CR2 register to find the faulting address
	fault_va = rcr2();
	if((tf->tf_cs & 3)==0) // last three bits 000 means DPL_Kern
f01044ee:	f6 40 34 03          	testb  $0x3,0x34(%eax)
f01044f2:	75 1c                	jne    f0104510 <page_fault_handler+0x30>
	{
		panic("kernel mode page faults!!");
f01044f4:	c7 44 24 08 d9 76 10 	movl   $0xf01076d9,0x8(%esp)
f01044fb:	f0 
f01044fc:	c7 44 24 04 53 01 00 	movl   $0x153,0x4(%esp)
f0104503:	00 
f0104504:	c7 04 24 f3 76 10 f0 	movl   $0xf01076f3,(%esp)
f010450b:	e8 30 bb ff ff       	call   f0100040 <_panic>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104510:	8b 70 30             	mov    0x30(%eax),%esi
		curenv->env_id, fault_va, tf->tf_eip);
f0104513:	e8 1b 18 00 00       	call   f0105d33 <cpunum>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104518:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010451c:	89 5c 24 08          	mov    %ebx,0x8(%esp)
		curenv->env_id, fault_va, tf->tf_eip);
f0104520:	6b c0 74             	imul   $0x74,%eax,%eax
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104523:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104529:	8b 40 48             	mov    0x48(%eax),%eax
f010452c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104530:	c7 04 24 b4 78 10 f0 	movl   $0xf01078b4,(%esp)
f0104537:	e8 a2 f9 ff ff       	call   f0103ede <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
	//print_trapframe(tf);
	env_destroy(curenv);
f010453c:	e8 f2 17 00 00       	call   f0105d33 <cpunum>
f0104541:	6b c0 74             	imul   $0x74,%eax,%eax
f0104544:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010454a:	89 04 24             	mov    %eax,(%esp)
f010454d:	e8 da f6 ff ff       	call   f0103c2c <env_destroy>
}
f0104552:	83 c4 10             	add    $0x10,%esp
f0104555:	5b                   	pop    %ebx
f0104556:	5e                   	pop    %esi
f0104557:	5d                   	pop    %ebp
f0104558:	c3                   	ret    

f0104559 <trap>:



void
trap(struct Trapframe *tf)
{
f0104559:	55                   	push   %ebp
f010455a:	89 e5                	mov    %esp,%ebp
f010455c:	57                   	push   %edi
f010455d:	56                   	push   %esi
f010455e:	83 ec 20             	sub    $0x20,%esp
f0104561:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f0104564:	fc                   	cld    

	// Halt the CPU if some other CPU has called panic()
	extern char *panicstr;
	if (panicstr)
f0104565:	83 3d 80 3e 22 f0 00 	cmpl   $0x0,0xf0223e80
f010456c:	74 01                	je     f010456f <trap+0x16>
		asm volatile("hlt");
f010456e:	f4                   	hlt    

static __inline uint32_t
read_eflags(void)
{
        uint32_t eflags;
        __asm __volatile("pushfl; popl %0" : "=r" (eflags));
f010456f:	9c                   	pushf  
f0104570:	58                   	pop    %eax

	// Check that interrupts are disabled.  If this assertion
	// fails, DO NOT be tempted to fix it by inserting a "cli" in
	// the interrupt path.
	assert(!(read_eflags() & FL_IF));
f0104571:	f6 c4 02             	test   $0x2,%ah
f0104574:	74 24                	je     f010459a <trap+0x41>
f0104576:	c7 44 24 0c ff 76 10 	movl   $0xf01076ff,0xc(%esp)
f010457d:	f0 
f010457e:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f0104585:	f0 
f0104586:	c7 44 24 04 1e 01 00 	movl   $0x11e,0x4(%esp)
f010458d:	00 
f010458e:	c7 04 24 f3 76 10 f0 	movl   $0xf01076f3,(%esp)
f0104595:	e8 a6 ba ff ff       	call   f0100040 <_panic>
	
	cprintf("Incoming TRAP frame at %p\n", tf);
f010459a:	89 74 24 04          	mov    %esi,0x4(%esp)
f010459e:	c7 04 24 18 77 10 f0 	movl   $0xf0107718,(%esp)
f01045a5:	e8 34 f9 ff ff       	call   f0103ede <cprintf>

	if ((tf->tf_cs & 3) == 3) {
f01045aa:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f01045ae:	83 e0 03             	and    $0x3,%eax
f01045b1:	66 83 f8 03          	cmp    $0x3,%ax
f01045b5:	0f 85 a7 00 00 00    	jne    f0104662 <trap+0x109>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f01045bb:	c7 04 24 a0 03 12 f0 	movl   $0xf01203a0,(%esp)
f01045c2:	e8 d2 19 00 00       	call   f0105f99 <spin_lock>
		// Trapped from user mode.
		// Acquire the big kernel lock before doing any
		// serious kernel work.
		// LAB 4: Your code here.
		lock_kernel();
		assert(curenv);
f01045c7:	e8 67 17 00 00       	call   f0105d33 <cpunum>
f01045cc:	6b c0 74             	imul   $0x74,%eax,%eax
f01045cf:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f01045d6:	75 24                	jne    f01045fc <trap+0xa3>
f01045d8:	c7 44 24 0c 33 77 10 	movl   $0xf0107733,0xc(%esp)
f01045df:	f0 
f01045e0:	c7 44 24 08 93 71 10 	movl   $0xf0107193,0x8(%esp)
f01045e7:	f0 
f01045e8:	c7 44 24 04 28 01 00 	movl   $0x128,0x4(%esp)
f01045ef:	00 
f01045f0:	c7 04 24 f3 76 10 f0 	movl   $0xf01076f3,(%esp)
f01045f7:	e8 44 ba ff ff       	call   f0100040 <_panic>

		// Garbage collect if current enviroment is a zombie
		if (curenv->env_status == ENV_DYING) {
f01045fc:	e8 32 17 00 00       	call   f0105d33 <cpunum>
f0104601:	6b c0 74             	imul   $0x74,%eax,%eax
f0104604:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010460a:	83 78 54 01          	cmpl   $0x1,0x54(%eax)
f010460e:	75 2d                	jne    f010463d <trap+0xe4>
			env_free(curenv);
f0104610:	e8 1e 17 00 00       	call   f0105d33 <cpunum>
f0104615:	6b c0 74             	imul   $0x74,%eax,%eax
f0104618:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010461e:	89 04 24             	mov    %eax,(%esp)
f0104621:	e8 fa f3 ff ff       	call   f0103a20 <env_free>
			curenv = NULL;
f0104626:	e8 08 17 00 00       	call   f0105d33 <cpunum>
f010462b:	6b c0 74             	imul   $0x74,%eax,%eax
f010462e:	c7 80 28 40 22 f0 00 	movl   $0x0,-0xfddbfd8(%eax)
f0104635:	00 00 00 
			sched_yield();
f0104638:	e8 c2 01 00 00       	call   f01047ff <sched_yield>
		}

		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		curenv->env_tf = *tf;
f010463d:	e8 f1 16 00 00       	call   f0105d33 <cpunum>
f0104642:	6b c0 74             	imul   $0x74,%eax,%eax
f0104645:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010464b:	b9 11 00 00 00       	mov    $0x11,%ecx
f0104650:	89 c7                	mov    %eax,%edi
f0104652:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f0104654:	e8 da 16 00 00       	call   f0105d33 <cpunum>
f0104659:	6b c0 74             	imul   $0x74,%eax,%eax
f010465c:	8b b0 28 40 22 f0    	mov    -0xfddbfd8(%eax),%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f0104662:	89 35 60 3a 22 f0    	mov    %esi,0xf0223a60
}
static void
trap_dispatch(struct Trapframe *tf)
{
	// Handle processor exceptions.
	print_trapframe(tf);
f0104668:	89 34 24             	mov    %esi,(%esp)
f010466b:	e8 d3 fc ff ff       	call   f0104343 <print_trapframe>
	// LAB 3: Your code here.

	// Handle spurious interrupts
	// The hardware sometimes raises these because of noise on the
	// IRQ line or other reasons. We don't care.
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_SPURIOUS) {
f0104670:	8b 46 28             	mov    0x28(%esi),%eax
f0104673:	83 f8 27             	cmp    $0x27,%eax
f0104676:	75 19                	jne    f0104691 <trap+0x138>
		cprintf("Spurious interrupt on irq 7\n");
f0104678:	c7 04 24 3a 77 10 f0 	movl   $0xf010773a,(%esp)
f010467f:	e8 5a f8 ff ff       	call   f0103ede <cprintf>
		print_trapframe(tf);
f0104684:	89 34 24             	mov    %esi,(%esp)
f0104687:	e8 b7 fc ff ff       	call   f0104343 <print_trapframe>
f010468c:	e9 96 00 00 00       	jmp    f0104727 <trap+0x1ce>

	// Handle clock interrupts. Don't forget to acknowledge the
	// interrupt using lapic_eoi() before calling the scheduler!
	// LAB 4: Your code here.

	if(tf->tf_trapno==T_PGFLT)
f0104691:	83 f8 0e             	cmp    $0xe,%eax
f0104694:	75 0f                	jne    f01046a5 <trap+0x14c>
	{
		page_fault_handler(tf);
f0104696:	89 34 24             	mov    %esi,(%esp)
f0104699:	e8 42 fe ff ff       	call   f01044e0 <page_fault_handler>
f010469e:	66 90                	xchg   %ax,%ax
f01046a0:	e9 82 00 00 00       	jmp    f0104727 <trap+0x1ce>
		return;
	}
	if(tf->tf_trapno==T_BRKPT)
f01046a5:	83 f8 03             	cmp    $0x3,%eax
f01046a8:	75 0d                	jne    f01046b7 <trap+0x15e>
	{
		monitor(tf);
f01046aa:	89 34 24             	mov    %esi,(%esp)
f01046ad:	8d 76 00             	lea    0x0(%esi),%esi
f01046b0:	e8 2d c3 ff ff       	call   f01009e2 <monitor>
f01046b5:	eb 70                	jmp    f0104727 <trap+0x1ce>
		return;
	}
	if(tf->tf_trapno==T_SYSCALL)
f01046b7:	83 f8 30             	cmp    $0x30,%eax
f01046ba:	75 32                	jne    f01046ee <trap+0x195>
	{
		tf->tf_regs.reg_eax=syscall(tf->tf_regs.reg_eax,tf->tf_regs.reg_edx,tf->tf_regs.reg_ecx,tf->tf_regs.reg_ebx,tf->tf_regs.reg_edi,tf->tf_regs.reg_esi);
f01046bc:	8b 46 04             	mov    0x4(%esi),%eax
f01046bf:	89 44 24 14          	mov    %eax,0x14(%esp)
f01046c3:	8b 06                	mov    (%esi),%eax
f01046c5:	89 44 24 10          	mov    %eax,0x10(%esp)
f01046c9:	8b 46 10             	mov    0x10(%esi),%eax
f01046cc:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01046d0:	8b 46 18             	mov    0x18(%esi),%eax
f01046d3:	89 44 24 08          	mov    %eax,0x8(%esp)
f01046d7:	8b 46 14             	mov    0x14(%esi),%eax
f01046da:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046de:	8b 46 1c             	mov    0x1c(%esi),%eax
f01046e1:	89 04 24             	mov    %eax,(%esp)
f01046e4:	e8 b7 01 00 00       	call   f01048a0 <syscall>
f01046e9:	89 46 1c             	mov    %eax,0x1c(%esi)
f01046ec:	eb 39                	jmp    f0104727 <trap+0x1ce>
	    return;
	}
	// Unexpected trap: The user process or the kernel has a bug.

	if (tf->tf_cs == GD_KT)
f01046ee:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f01046f3:	75 1c                	jne    f0104711 <trap+0x1b8>
		panic("unhandled trap in kernel");
f01046f5:	c7 44 24 08 57 77 10 	movl   $0xf0107757,0x8(%esp)
f01046fc:	f0 
f01046fd:	c7 44 24 04 06 01 00 	movl   $0x106,0x4(%esp)
f0104704:	00 
f0104705:	c7 04 24 f3 76 10 f0 	movl   $0xf01076f3,(%esp)
f010470c:	e8 2f b9 ff ff       	call   f0100040 <_panic>
	else {
		env_destroy(curenv);
f0104711:	e8 1d 16 00 00       	call   f0105d33 <cpunum>
f0104716:	6b c0 74             	imul   $0x74,%eax,%eax
f0104719:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010471f:	89 04 24             	mov    %eax,(%esp)
f0104722:	e8 05 f5 ff ff       	call   f0103c2c <env_destroy>
	trap_dispatch(tf);

	// If we made it to this point, then no other environment was
	// scheduled, so we should return to the current environment
	// if doing so makes sense.
	if (curenv && curenv->env_status == ENV_RUNNING)
f0104727:	e8 07 16 00 00       	call   f0105d33 <cpunum>
f010472c:	6b c0 74             	imul   $0x74,%eax,%eax
f010472f:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f0104736:	74 2a                	je     f0104762 <trap+0x209>
f0104738:	e8 f6 15 00 00       	call   f0105d33 <cpunum>
f010473d:	6b c0 74             	imul   $0x74,%eax,%eax
f0104740:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104746:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f010474a:	75 16                	jne    f0104762 <trap+0x209>
		env_run(curenv);
f010474c:	e8 e2 15 00 00       	call   f0105d33 <cpunum>
f0104751:	6b c0 74             	imul   $0x74,%eax,%eax
f0104754:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010475a:	89 04 24             	mov    %eax,(%esp)
f010475d:	e8 6b f5 ff ff       	call   f0103ccd <env_run>
	else
		sched_yield();
f0104762:	e8 98 00 00 00       	call   f01047ff <sched_yield>
f0104767:	90                   	nop

f0104768 <dividezero_handler>:
.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
f0104768:	6a 00                	push   $0x0
f010476a:	6a 00                	push   $0x0
f010476c:	eb 58                	jmp    f01047c6 <_alltraps>

f010476e <nmi_handler>:
TRAPHANDLER_NOEC(nmi_handler, 0x2)
f010476e:	6a 00                	push   $0x0
f0104770:	6a 02                	push   $0x2
f0104772:	eb 52                	jmp    f01047c6 <_alltraps>

f0104774 <breakpoint_handler>:
TRAPHANDLER_NOEC(breakpoint_handler, 0x3)
f0104774:	6a 00                	push   $0x0
f0104776:	6a 03                	push   $0x3
f0104778:	eb 4c                	jmp    f01047c6 <_alltraps>

f010477a <overflow_handler>:
TRAPHANDLER_NOEC(overflow_handler, 0x4)
f010477a:	6a 00                	push   $0x0
f010477c:	6a 04                	push   $0x4
f010477e:	eb 46                	jmp    f01047c6 <_alltraps>

f0104780 <bdrgeexceed_handler>:
TRAPHANDLER_NOEC(bdrgeexceed_handler, 0x5)
f0104780:	6a 00                	push   $0x0
f0104782:	6a 05                	push   $0x5
f0104784:	eb 40                	jmp    f01047c6 <_alltraps>

f0104786 <invalidop_handler>:
TRAPHANDLER_NOEC(invalidop_handler, 0x6)
f0104786:	6a 00                	push   $0x0
f0104788:	6a 06                	push   $0x6
f010478a:	eb 3a                	jmp    f01047c6 <_alltraps>

f010478c <nomathcopro_handler>:
TRAPHANDLER_NOEC(nomathcopro_handler, 0x7)
f010478c:	6a 00                	push   $0x0
f010478e:	6a 07                	push   $0x7
f0104790:	eb 34                	jmp    f01047c6 <_alltraps>

f0104792 <dbfault_handler>:
TRAPHANDLER(dbfault_handler, 0x8)
f0104792:	6a 08                	push   $0x8
f0104794:	eb 30                	jmp    f01047c6 <_alltraps>

f0104796 <invalidTSS_handler>:
TRAPHANDLER(invalidTSS_handler, 0xA)
f0104796:	6a 0a                	push   $0xa
f0104798:	eb 2c                	jmp    f01047c6 <_alltraps>

f010479a <sgmtnotpresent_handler>:
TRAPHANDLER(sgmtnotpresent_handler, 0xB)
f010479a:	6a 0b                	push   $0xb
f010479c:	eb 28                	jmp    f01047c6 <_alltraps>

f010479e <stacksgmtfault_handler>:
TRAPHANDLER(stacksgmtfault_handler,0xC)
f010479e:	6a 0c                	push   $0xc
f01047a0:	eb 24                	jmp    f01047c6 <_alltraps>

f01047a2 <generalprotection_handler>:
TRAPHANDLER(generalprotection_handler, 0xD)
f01047a2:	6a 0d                	push   $0xd
f01047a4:	eb 20                	jmp    f01047c6 <_alltraps>

f01047a6 <pagefault_handler>:
TRAPHANDLER(pagefault_handler, 0xE)
f01047a6:	6a 0e                	push   $0xe
f01047a8:	eb 1c                	jmp    f01047c6 <_alltraps>

f01047aa <FPUerror_handler>:
TRAPHANDLER_NOEC(FPUerror_handler, 0x10)
f01047aa:	6a 00                	push   $0x0
f01047ac:	6a 10                	push   $0x10
f01047ae:	eb 16                	jmp    f01047c6 <_alltraps>

f01047b0 <alignmentcheck_handler>:
TRAPHANDLER(alignmentcheck_handler, 0x11)
f01047b0:	6a 11                	push   $0x11
f01047b2:	eb 12                	jmp    f01047c6 <_alltraps>

f01047b4 <machinecheck_handler>:
TRAPHANDLER_NOEC(machinecheck_handler, 0x12)
f01047b4:	6a 00                	push   $0x0
f01047b6:	6a 12                	push   $0x12
f01047b8:	eb 0c                	jmp    f01047c6 <_alltraps>

f01047ba <SIMDFPexception_handler>:
TRAPHANDLER_NOEC(SIMDFPexception_handler, 0x13)
f01047ba:	6a 00                	push   $0x0
f01047bc:	6a 13                	push   $0x13
f01047be:	eb 06                	jmp    f01047c6 <_alltraps>

f01047c0 <systemcall_handler>:
TRAPHANDLER_NOEC(systemcall_handler, 0x30)
f01047c0:	6a 00                	push   $0x0
f01047c2:	6a 30                	push   $0x30
f01047c4:	eb 00                	jmp    f01047c6 <_alltraps>

f01047c6 <_alltraps>:
/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
	pushw $0
f01047c6:	66 6a 00             	pushw  $0x0
	pushw %ds
f01047c9:	66 1e                	pushw  %ds
	pushw $0
f01047cb:	66 6a 00             	pushw  $0x0
	pushw %es
f01047ce:	66 06                	pushw  %es
	pushal
f01047d0:	60                   	pusha  
	pushl %esp
f01047d1:	54                   	push   %esp
	movw $(GD_KD),%ax
f01047d2:	66 b8 10 00          	mov    $0x10,%ax
	movw %ax,%ds
f01047d6:	8e d8                	mov    %eax,%ds
	movw %ax,%es
f01047d8:	8e c0                	mov    %eax,%es
	call trap
f01047da:	e8 7a fd ff ff       	call   f0104559 <trap>

f01047df <test_func>:

#include <kern/env.h>
#include <kern/pmap.h>
#include <kern/monitor.h>

void test_func(){
f01047df:	55                   	push   %ebp
f01047e0:	89 e5                	mov    %esp,%ebp
f01047e2:	83 ec 18             	sub    $0x18,%esp
	if(cpunum()>1000)
f01047e5:	e8 49 15 00 00       	call   f0105d33 <cpunum>
f01047ea:	3d e8 03 00 00       	cmp    $0x3e8,%eax
f01047ef:	7e 0c                	jle    f01047fd <test_func+0x1e>
		env_run(0);
f01047f1:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01047f8:	e8 d0 f4 ff ff       	call   f0103ccd <env_run>
}
f01047fd:	c9                   	leave  
f01047fe:	c3                   	ret    

f01047ff <sched_yield>:
// Choose a user environment to run and run it.
void
sched_yield(void)
{
f01047ff:	55                   	push   %ebp
f0104800:	89 e5                	mov    %esp,%ebp
f0104802:	53                   	push   %ebx
f0104803:	83 ec 14             	sub    $0x14,%esp

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104806:	8b 1d 48 32 22 f0    	mov    0xf0223248,%ebx
f010480c:	89 d8                	mov    %ebx,%eax
	// LAB 4: Your code here.

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f010480e:	ba 00 00 00 00       	mov    $0x0,%edx
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104813:	83 78 50 01          	cmpl   $0x1,0x50(%eax)
f0104817:	74 0b                	je     f0104824 <sched_yield+0x25>
		    (envs[i].env_status == ENV_RUNNABLE ||
f0104819:	8b 48 54             	mov    0x54(%eax),%ecx
f010481c:	83 e9 02             	sub    $0x2,%ecx

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f010481f:	83 f9 01             	cmp    $0x1,%ecx
f0104822:	76 10                	jbe    f0104834 <sched_yield+0x35>
	// LAB 4: Your code here.

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0104824:	83 c2 01             	add    $0x1,%edx
f0104827:	83 c0 7c             	add    $0x7c,%eax
f010482a:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104830:	75 e1                	jne    f0104813 <sched_yield+0x14>
f0104832:	eb 08                	jmp    f010483c <sched_yield+0x3d>
		if (envs[i].env_type != ENV_TYPE_IDLE &&
		    (envs[i].env_status == ENV_RUNNABLE ||
		     envs[i].env_status == ENV_RUNNING))
			break;
	}
	if (i == NENV) {
f0104834:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f010483a:	75 1a                	jne    f0104856 <sched_yield+0x57>
		cprintf("No more runnable environments!\n");
f010483c:	c7 04 24 30 79 10 f0 	movl   $0xf0107930,(%esp)
f0104843:	e8 96 f6 ff ff       	call   f0103ede <cprintf>
		while (1)
			monitor(NULL);
f0104848:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010484f:	e8 8e c1 ff ff       	call   f01009e2 <monitor>
f0104854:	eb f2                	jmp    f0104848 <sched_yield+0x49>
	}

	// Run this CPU's idle environment when nothing else is runnable.
	idle = &envs[cpunum()];
f0104856:	e8 d8 14 00 00       	call   f0105d33 <cpunum>
f010485b:	6b c0 7c             	imul   $0x7c,%eax,%eax
f010485e:	01 c3                	add    %eax,%ebx
	if (!(idle->env_status == ENV_RUNNABLE || idle->env_status == ENV_RUNNING))
f0104860:	8b 43 54             	mov    0x54(%ebx),%eax
f0104863:	83 e8 02             	sub    $0x2,%eax
f0104866:	83 f8 01             	cmp    $0x1,%eax
f0104869:	76 25                	jbe    f0104890 <sched_yield+0x91>
		panic("CPU %d: No idle environment!", cpunum());
f010486b:	e8 c3 14 00 00       	call   f0105d33 <cpunum>
f0104870:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104874:	c7 44 24 08 50 79 10 	movl   $0xf0107950,0x8(%esp)
f010487b:	f0 
f010487c:	c7 44 24 04 36 00 00 	movl   $0x36,0x4(%esp)
f0104883:	00 
f0104884:	c7 04 24 6d 79 10 f0 	movl   $0xf010796d,(%esp)
f010488b:	e8 b0 b7 ff ff       	call   f0100040 <_panic>
	test_func();
f0104890:	e8 4a ff ff ff       	call   f01047df <test_func>
	env_run(idle);
f0104895:	89 1c 24             	mov    %ebx,(%esp)
f0104898:	e8 30 f4 ff ff       	call   f0103ccd <env_run>
f010489d:	66 90                	xchg   %ax,%ax
f010489f:	90                   	nop

f01048a0 <syscall>:
}

// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
f01048a0:	55                   	push   %ebp
f01048a1:	89 e5                	mov    %esp,%ebp
f01048a3:	53                   	push   %ebx
f01048a4:	83 ec 24             	sub    $0x24,%esp
f01048a7:	8b 45 08             	mov    0x8(%ebp),%eax
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
	switch(syscallno){
f01048aa:	83 f8 01             	cmp    $0x1,%eax
f01048ad:	74 66                	je     f0104915 <syscall+0x75>
f01048af:	83 f8 01             	cmp    $0x1,%eax
f01048b2:	72 11                	jb     f01048c5 <syscall+0x25>
f01048b4:	83 f8 02             	cmp    $0x2,%eax
f01048b7:	74 66                	je     f010491f <syscall+0x7f>
f01048b9:	83 f8 03             	cmp    $0x3,%eax
f01048bc:	74 78                	je     f0104936 <syscall+0x96>
f01048be:	66 90                	xchg   %ax,%ax
f01048c0:	e9 03 01 00 00       	jmp    f01049c8 <syscall+0x128>
static void
sys_cputs(const char *s, size_t len)
{
	// Check that the user has permission to read memory [s, s+len).
	// Destroy the environment if not.
	user_mem_assert(curenv,s,len,0);
f01048c5:	e8 69 14 00 00       	call   f0105d33 <cpunum>
f01048ca:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f01048d1:	00 
f01048d2:	8b 4d 10             	mov    0x10(%ebp),%ecx
f01048d5:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01048d9:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01048dc:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01048e0:	6b c0 74             	imul   $0x74,%eax,%eax
f01048e3:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f01048e9:	89 04 24             	mov    %eax,(%esp)
f01048ec:	e8 ef eb ff ff       	call   f01034e0 <user_mem_assert>
	// LAB 3: Your code here.
	// Print the string supplied by the user.
	cprintf("%.*s", len, s);
f01048f1:	8b 45 0c             	mov    0xc(%ebp),%eax
f01048f4:	89 44 24 08          	mov    %eax,0x8(%esp)
f01048f8:	8b 45 10             	mov    0x10(%ebp),%eax
f01048fb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01048ff:	c7 04 24 7a 79 10 f0 	movl   $0xf010797a,(%esp)
f0104906:	e8 d3 f5 ff ff       	call   f0103ede <cprintf>
	// Return any appropriate return value.
	// LAB 3: Your code here.
	switch(syscallno){
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
f010490b:	b8 00 00 00 00       	mov    $0x0,%eax
f0104910:	e9 b8 00 00 00       	jmp    f01049cd <syscall+0x12d>
// Read a character from the system console without blocking.
// Returns the character, or 0 if there is no input waiting.
static int
sys_cgetc(void)
{
	return cons_getc();
f0104915:	e8 6b bd ff ff       	call   f0100685 <cons_getc>
	switch(syscallno){
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case(SYS_cgetc):
			return sys_cgetc();
f010491a:	e9 ae 00 00 00       	jmp    f01049cd <syscall+0x12d>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f010491f:	90                   	nop
f0104920:	e8 0e 14 00 00       	call   f0105d33 <cpunum>
f0104925:	6b c0 74             	imul   $0x74,%eax,%eax
f0104928:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010492e:	8b 40 48             	mov    0x48(%eax),%eax
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case(SYS_cgetc):
			return sys_cgetc();
		case(SYS_getenvid):
			return sys_getenvid();
f0104931:	e9 97 00 00 00       	jmp    f01049cd <syscall+0x12d>
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104936:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010493d:	00 
f010493e:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0104941:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104945:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104948:	89 04 24             	mov    %eax,(%esp)
f010494b:	e8 e8 eb ff ff       	call   f0103538 <envid2env>
		return r;
f0104950:	89 c2                	mov    %eax,%edx
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104952:	85 c0                	test   %eax,%eax
f0104954:	78 6e                	js     f01049c4 <syscall+0x124>
		return r;
	if (e == curenv)
f0104956:	e8 d8 13 00 00       	call   f0105d33 <cpunum>
f010495b:	8b 55 f4             	mov    -0xc(%ebp),%edx
f010495e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104961:	39 90 28 40 22 f0    	cmp    %edx,-0xfddbfd8(%eax)
f0104967:	75 23                	jne    f010498c <syscall+0xec>
		cprintf("[%08x] exiting gracefully\n", curenv->env_id);
f0104969:	e8 c5 13 00 00       	call   f0105d33 <cpunum>
f010496e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104971:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104977:	8b 40 48             	mov    0x48(%eax),%eax
f010497a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010497e:	c7 04 24 7f 79 10 f0 	movl   $0xf010797f,(%esp)
f0104985:	e8 54 f5 ff ff       	call   f0103ede <cprintf>
f010498a:	eb 28                	jmp    f01049b4 <syscall+0x114>
	else
		cprintf("[%08x] destroying %08x\n", curenv->env_id, e->env_id);
f010498c:	8b 5a 48             	mov    0x48(%edx),%ebx
f010498f:	e8 9f 13 00 00       	call   f0105d33 <cpunum>
f0104994:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0104998:	6b c0 74             	imul   $0x74,%eax,%eax
f010499b:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f01049a1:	8b 40 48             	mov    0x48(%eax),%eax
f01049a4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01049a8:	c7 04 24 9a 79 10 f0 	movl   $0xf010799a,(%esp)
f01049af:	e8 2a f5 ff ff       	call   f0103ede <cprintf>
	env_destroy(e);
f01049b4:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01049b7:	89 04 24             	mov    %eax,(%esp)
f01049ba:	e8 6d f2 ff ff       	call   f0103c2c <env_destroy>
	return 0;
f01049bf:	ba 00 00 00 00       	mov    $0x0,%edx
		case(SYS_cgetc):
			return sys_cgetc();
		case(SYS_getenvid):
			return sys_getenvid();
		case(SYS_env_destroy):
			return sys_env_destroy((envid_t) a1);
f01049c4:	89 d0                	mov    %edx,%eax
f01049c6:	eb 05                	jmp    f01049cd <syscall+0x12d>
		default:
			return -E_INVAL;
f01049c8:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
	}
	//panic("syscall not implemented");
}
f01049cd:	83 c4 24             	add    $0x24,%esp
f01049d0:	5b                   	pop    %ebx
f01049d1:	5d                   	pop    %ebp
f01049d2:	c3                   	ret    
f01049d3:	66 90                	xchg   %ax,%ax
f01049d5:	66 90                	xchg   %ax,%ax
f01049d7:	66 90                	xchg   %ax,%ax
f01049d9:	66 90                	xchg   %ax,%ax
f01049db:	66 90                	xchg   %ax,%ax
f01049dd:	66 90                	xchg   %ax,%ax
f01049df:	90                   	nop

f01049e0 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f01049e0:	55                   	push   %ebp
f01049e1:	89 e5                	mov    %esp,%ebp
f01049e3:	57                   	push   %edi
f01049e4:	56                   	push   %esi
f01049e5:	53                   	push   %ebx
f01049e6:	83 ec 14             	sub    $0x14,%esp
f01049e9:	89 45 ec             	mov    %eax,-0x14(%ebp)
f01049ec:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f01049ef:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f01049f2:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f01049f5:	8b 1a                	mov    (%edx),%ebx
f01049f7:	8b 01                	mov    (%ecx),%eax
f01049f9:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f01049fc:	39 c3                	cmp    %eax,%ebx
f01049fe:	0f 8f 9a 00 00 00    	jg     f0104a9e <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f0104a04:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104a0b:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0104a0e:	01 d8                	add    %ebx,%eax
f0104a10:	89 c7                	mov    %eax,%edi
f0104a12:	c1 ef 1f             	shr    $0x1f,%edi
f0104a15:	01 c7                	add    %eax,%edi
f0104a17:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0104a19:	39 df                	cmp    %ebx,%edi
f0104a1b:	0f 8c c4 00 00 00    	jl     f0104ae5 <stab_binsearch+0x105>
f0104a21:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0104a24:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104a27:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f0104a2a:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f0104a2e:	39 f0                	cmp    %esi,%eax
f0104a30:	0f 84 b4 00 00 00    	je     f0104aea <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104a36:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f0104a38:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0104a3b:	39 d8                	cmp    %ebx,%eax
f0104a3d:	0f 8c a2 00 00 00    	jl     f0104ae5 <stab_binsearch+0x105>
f0104a43:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f0104a47:	83 ea 0c             	sub    $0xc,%edx
f0104a4a:	39 f1                	cmp    %esi,%ecx
f0104a4c:	75 ea                	jne    f0104a38 <stab_binsearch+0x58>
f0104a4e:	e9 99 00 00 00       	jmp    f0104aec <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0104a53:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0104a56:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f0104a58:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0104a5b:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0104a62:	eb 2b                	jmp    f0104a8f <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0104a64:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0104a67:	76 14                	jbe    f0104a7d <stab_binsearch+0x9d>
			*region_right = m - 1;
f0104a69:	83 e8 01             	sub    $0x1,%eax
f0104a6c:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0104a6f:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0104a72:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0104a74:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0104a7b:	eb 12                	jmp    f0104a8f <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0104a7d:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104a80:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f0104a82:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f0104a86:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0104a88:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f0104a8f:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0104a92:	0f 8e 73 ff ff ff    	jle    f0104a0b <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0104a98:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f0104a9c:	75 0f                	jne    f0104aad <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f0104a9e:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104aa1:	8b 00                	mov    (%eax),%eax
f0104aa3:	83 e8 01             	sub    $0x1,%eax
f0104aa6:	8b 75 e0             	mov    -0x20(%ebp),%esi
f0104aa9:	89 06                	mov    %eax,(%esi)
f0104aab:	eb 57                	jmp    f0104b04 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104aad:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104ab0:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0104ab2:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104ab5:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104ab7:	39 c8                	cmp    %ecx,%eax
f0104ab9:	7e 23                	jle    f0104ade <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0104abb:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104abe:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0104ac1:	8d 14 97             	lea    (%edi,%edx,4),%edx
f0104ac4:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f0104ac8:	39 f3                	cmp    %esi,%ebx
f0104aca:	74 12                	je     f0104ade <stab_binsearch+0xfe>
		     l--)
f0104acc:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104acf:	39 c8                	cmp    %ecx,%eax
f0104ad1:	7e 0b                	jle    f0104ade <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0104ad3:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f0104ad7:	83 ea 0c             	sub    $0xc,%edx
f0104ada:	39 f3                	cmp    %esi,%ebx
f0104adc:	75 ee                	jne    f0104acc <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f0104ade:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0104ae1:	89 06                	mov    %eax,(%esi)
f0104ae3:	eb 1f                	jmp    f0104b04 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0104ae5:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0104ae8:	eb a5                	jmp    f0104a8f <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104aea:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0104aec:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104aef:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104af2:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0104af6:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0104af9:	0f 82 54 ff ff ff    	jb     f0104a53 <stab_binsearch+0x73>
f0104aff:	e9 60 ff ff ff       	jmp    f0104a64 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0104b04:	83 c4 14             	add    $0x14,%esp
f0104b07:	5b                   	pop    %ebx
f0104b08:	5e                   	pop    %esi
f0104b09:	5f                   	pop    %edi
f0104b0a:	5d                   	pop    %ebp
f0104b0b:	c3                   	ret    

f0104b0c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0104b0c:	55                   	push   %ebp
f0104b0d:	89 e5                	mov    %esp,%ebp
f0104b0f:	57                   	push   %edi
f0104b10:	56                   	push   %esi
f0104b11:	53                   	push   %ebx
f0104b12:	83 ec 3c             	sub    $0x3c,%esp
f0104b15:	8b 7d 08             	mov    0x8(%ebp),%edi
f0104b18:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0104b1b:	c7 06 b2 79 10 f0    	movl   $0xf01079b2,(%esi)
	info->eip_line = 0;
f0104b21:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0104b28:	c7 46 08 b2 79 10 f0 	movl   $0xf01079b2,0x8(%esi)
	info->eip_fn_namelen = 9;
f0104b2f:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0104b36:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0104b39:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0104b40:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f0104b46:	0f 87 ca 00 00 00    	ja     f0104c16 <debuginfo_eip+0x10a>
		const struct UserStabData *usd = (const struct UserStabData *) USTABDATA;

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
f0104b4c:	e8 e2 11 00 00       	call   f0105d33 <cpunum>
f0104b51:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104b58:	00 
f0104b59:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
f0104b60:	00 
f0104b61:	c7 44 24 04 00 00 20 	movl   $0x200000,0x4(%esp)
f0104b68:	00 
f0104b69:	6b c0 74             	imul   $0x74,%eax,%eax
f0104b6c:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104b72:	89 04 24             	mov    %eax,(%esp)
f0104b75:	e8 c7 e8 ff ff       	call   f0103441 <user_mem_check>
f0104b7a:	85 c0                	test   %eax,%eax
f0104b7c:	0f 85 12 02 00 00    	jne    f0104d94 <debuginfo_eip+0x288>
			return -1;
		stabs = usd->stabs;
f0104b82:	a1 00 00 20 00       	mov    0x200000,%eax
f0104b87:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f0104b8a:	8b 1d 04 00 20 00    	mov    0x200004,%ebx
		stabstr = usd->stabstr;
f0104b90:	8b 15 08 00 20 00    	mov    0x200008,%edx
f0104b96:	89 55 d0             	mov    %edx,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f0104b99:	a1 0c 00 20 00       	mov    0x20000c,%eax
f0104b9e:	89 45 cc             	mov    %eax,-0x34(%ebp)

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
f0104ba1:	e8 8d 11 00 00       	call   f0105d33 <cpunum>
f0104ba6:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104bad:	00 
f0104bae:	89 da                	mov    %ebx,%edx
f0104bb0:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0104bb3:	29 ca                	sub    %ecx,%edx
f0104bb5:	c1 fa 02             	sar    $0x2,%edx
f0104bb8:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f0104bbe:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104bc2:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0104bc6:	6b c0 74             	imul   $0x74,%eax,%eax
f0104bc9:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104bcf:	89 04 24             	mov    %eax,(%esp)
f0104bd2:	e8 6a e8 ff ff       	call   f0103441 <user_mem_check>
f0104bd7:	85 c0                	test   %eax,%eax
f0104bd9:	0f 85 bc 01 00 00    	jne    f0104d9b <debuginfo_eip+0x28f>
f0104bdf:	e8 4f 11 00 00       	call   f0105d33 <cpunum>
f0104be4:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104beb:	00 
f0104bec:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0104bef:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0104bf2:	29 ca                	sub    %ecx,%edx
f0104bf4:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104bf8:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0104bfc:	6b c0 74             	imul   $0x74,%eax,%eax
f0104bff:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104c05:	89 04 24             	mov    %eax,(%esp)
f0104c08:	e8 34 e8 ff ff       	call   f0103441 <user_mem_check>
f0104c0d:	85 c0                	test   %eax,%eax
f0104c0f:	74 1f                	je     f0104c30 <debuginfo_eip+0x124>
f0104c11:	e9 8c 01 00 00       	jmp    f0104da2 <debuginfo_eip+0x296>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f0104c16:	c7 45 cc 88 52 11 f0 	movl   $0xf0115288,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f0104c1d:	c7 45 d0 3d 1e 11 f0 	movl   $0xf0111e3d,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f0104c24:	bb 3c 1e 11 f0       	mov    $0xf0111e3c,%ebx
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f0104c29:	c7 45 d4 94 7e 10 f0 	movl   $0xf0107e94,-0x2c(%ebp)
		    return -1;
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0104c30:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0104c33:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0104c36:	0f 83 6d 01 00 00    	jae    f0104da9 <debuginfo_eip+0x29d>
f0104c3c:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f0104c40:	0f 85 6a 01 00 00    	jne    f0104db0 <debuginfo_eip+0x2a4>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0104c46:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0104c4d:	2b 5d d4             	sub    -0x2c(%ebp),%ebx
f0104c50:	c1 fb 02             	sar    $0x2,%ebx
f0104c53:	69 c3 ab aa aa aa    	imul   $0xaaaaaaab,%ebx,%eax
f0104c59:	83 e8 01             	sub    $0x1,%eax
f0104c5c:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0104c5f:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104c63:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0104c6a:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0104c6d:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0104c70:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0104c73:	89 d8                	mov    %ebx,%eax
f0104c75:	e8 66 fd ff ff       	call   f01049e0 <stab_binsearch>
	if (lfile == 0)
f0104c7a:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104c7d:	85 c0                	test   %eax,%eax
f0104c7f:	0f 84 32 01 00 00    	je     f0104db7 <debuginfo_eip+0x2ab>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0104c85:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0104c88:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104c8b:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0104c8e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104c92:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0104c99:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0104c9c:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0104c9f:	89 d8                	mov    %ebx,%eax
f0104ca1:	e8 3a fd ff ff       	call   f01049e0 <stab_binsearch>

	if (lfun <= rfun) {
f0104ca6:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f0104ca9:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f0104cac:	7f 23                	jg     f0104cd1 <debuginfo_eip+0x1c5>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0104cae:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104cb1:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104cb4:	8d 04 87             	lea    (%edi,%eax,4),%eax
f0104cb7:	8b 10                	mov    (%eax),%edx
f0104cb9:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0104cbc:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f0104cbf:	39 ca                	cmp    %ecx,%edx
f0104cc1:	73 06                	jae    f0104cc9 <debuginfo_eip+0x1bd>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0104cc3:	03 55 d0             	add    -0x30(%ebp),%edx
f0104cc6:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f0104cc9:	8b 40 08             	mov    0x8(%eax),%eax
f0104ccc:	89 46 10             	mov    %eax,0x10(%esi)
f0104ccf:	eb 06                	jmp    f0104cd7 <debuginfo_eip+0x1cb>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0104cd1:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f0104cd4:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0104cd7:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0104cde:	00 
f0104cdf:	8b 46 08             	mov    0x8(%esi),%eax
f0104ce2:	89 04 24             	mov    %eax,(%esp)
f0104ce5:	e8 85 09 00 00       	call   f010566f <strfind>
f0104cea:	2b 46 08             	sub    0x8(%esi),%eax
f0104ced:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0104cf0:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104cf3:	39 fb                	cmp    %edi,%ebx
f0104cf5:	7c 5d                	jl     f0104d54 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0104cf7:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104cfa:	c1 e0 02             	shl    $0x2,%eax
f0104cfd:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0104d00:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f0104d03:	89 55 c8             	mov    %edx,-0x38(%ebp)
f0104d06:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f0104d0a:	80 fa 84             	cmp    $0x84,%dl
f0104d0d:	74 2d                	je     f0104d3c <debuginfo_eip+0x230>
f0104d0f:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f0104d13:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0104d16:	eb 15                	jmp    f0104d2d <debuginfo_eip+0x221>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0104d18:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0104d1b:	39 fb                	cmp    %edi,%ebx
f0104d1d:	7c 35                	jl     f0104d54 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0104d1f:	89 c1                	mov    %eax,%ecx
f0104d21:	83 e8 0c             	sub    $0xc,%eax
f0104d24:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0104d28:	80 fa 84             	cmp    $0x84,%dl
f0104d2b:	74 0f                	je     f0104d3c <debuginfo_eip+0x230>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0104d2d:	80 fa 64             	cmp    $0x64,%dl
f0104d30:	75 e6                	jne    f0104d18 <debuginfo_eip+0x20c>
f0104d32:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f0104d36:	74 e0                	je     f0104d18 <debuginfo_eip+0x20c>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0104d38:	39 df                	cmp    %ebx,%edi
f0104d3a:	7f 18                	jg     f0104d54 <debuginfo_eip+0x248>
f0104d3c:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104d3f:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104d42:	8b 04 87             	mov    (%edi,%eax,4),%eax
f0104d45:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0104d48:	2b 55 d0             	sub    -0x30(%ebp),%edx
f0104d4b:	39 d0                	cmp    %edx,%eax
f0104d4d:	73 05                	jae    f0104d54 <debuginfo_eip+0x248>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0104d4f:	03 45 d0             	add    -0x30(%ebp),%eax
f0104d52:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0104d54:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0104d57:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0104d5a:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0104d5f:	39 ca                	cmp    %ecx,%edx
f0104d61:	7d 75                	jge    f0104dd8 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
f0104d63:	8d 42 01             	lea    0x1(%edx),%eax
f0104d66:	39 c1                	cmp    %eax,%ecx
f0104d68:	7e 54                	jle    f0104dbe <debuginfo_eip+0x2b2>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0104d6a:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104d6d:	c1 e2 02             	shl    $0x2,%edx
f0104d70:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104d73:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f0104d78:	75 4b                	jne    f0104dc5 <debuginfo_eip+0x2b9>
f0104d7a:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f0104d7e:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0104d82:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0104d85:	39 c1                	cmp    %eax,%ecx
f0104d87:	7e 43                	jle    f0104dcc <debuginfo_eip+0x2c0>
f0104d89:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0104d8c:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0104d90:	74 ec                	je     f0104d7e <debuginfo_eip+0x272>
f0104d92:	eb 3f                	jmp    f0104dd3 <debuginfo_eip+0x2c7>

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
			return -1;
f0104d94:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104d99:	eb 3d                	jmp    f0104dd8 <debuginfo_eip+0x2cc>

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
		 {
		    return -1;
f0104d9b:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104da0:	eb 36                	jmp    f0104dd8 <debuginfo_eip+0x2cc>
f0104da2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104da7:	eb 2f                	jmp    f0104dd8 <debuginfo_eip+0x2cc>
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0104da9:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104dae:	eb 28                	jmp    f0104dd8 <debuginfo_eip+0x2cc>
f0104db0:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104db5:	eb 21                	jmp    f0104dd8 <debuginfo_eip+0x2cc>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0104db7:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104dbc:	eb 1a                	jmp    f0104dd8 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0104dbe:	b8 00 00 00 00       	mov    $0x0,%eax
f0104dc3:	eb 13                	jmp    f0104dd8 <debuginfo_eip+0x2cc>
f0104dc5:	b8 00 00 00 00       	mov    $0x0,%eax
f0104dca:	eb 0c                	jmp    f0104dd8 <debuginfo_eip+0x2cc>
f0104dcc:	b8 00 00 00 00       	mov    $0x0,%eax
f0104dd1:	eb 05                	jmp    f0104dd8 <debuginfo_eip+0x2cc>
f0104dd3:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0104dd8:	83 c4 3c             	add    $0x3c,%esp
f0104ddb:	5b                   	pop    %ebx
f0104ddc:	5e                   	pop    %esi
f0104ddd:	5f                   	pop    %edi
f0104dde:	5d                   	pop    %ebp
f0104ddf:	c3                   	ret    

f0104de0 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0104de0:	55                   	push   %ebp
f0104de1:	89 e5                	mov    %esp,%ebp
f0104de3:	57                   	push   %edi
f0104de4:	56                   	push   %esi
f0104de5:	53                   	push   %ebx
f0104de6:	83 ec 3c             	sub    $0x3c,%esp
f0104de9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0104dec:	89 d7                	mov    %edx,%edi
f0104dee:	8b 45 08             	mov    0x8(%ebp),%eax
f0104df1:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0104df4:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104df7:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f0104dfa:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0104dfd:	b9 00 00 00 00       	mov    $0x0,%ecx
f0104e02:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0104e05:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0104e08:	39 f1                	cmp    %esi,%ecx
f0104e0a:	72 14                	jb     f0104e20 <printnum+0x40>
f0104e0c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f0104e0f:	76 0f                	jbe    f0104e20 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0104e11:	8b 45 14             	mov    0x14(%ebp),%eax
f0104e14:	8d 70 ff             	lea    -0x1(%eax),%esi
f0104e17:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0104e1a:	85 f6                	test   %esi,%esi
f0104e1c:	7f 60                	jg     f0104e7e <printnum+0x9e>
f0104e1e:	eb 72                	jmp    f0104e92 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0104e20:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0104e23:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0104e27:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0104e2a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0104e2d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0104e31:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104e35:	8b 44 24 08          	mov    0x8(%esp),%eax
f0104e39:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0104e3d:	89 c3                	mov    %eax,%ebx
f0104e3f:	89 d6                	mov    %edx,%esi
f0104e41:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0104e44:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0104e47:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104e4b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0104e4f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104e52:	89 04 24             	mov    %eax,(%esp)
f0104e55:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0104e58:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104e5c:	e8 3f 13 00 00       	call   f01061a0 <__udivdi3>
f0104e61:	89 d9                	mov    %ebx,%ecx
f0104e63:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104e67:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0104e6b:	89 04 24             	mov    %eax,(%esp)
f0104e6e:	89 54 24 04          	mov    %edx,0x4(%esp)
f0104e72:	89 fa                	mov    %edi,%edx
f0104e74:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104e77:	e8 64 ff ff ff       	call   f0104de0 <printnum>
f0104e7c:	eb 14                	jmp    f0104e92 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f0104e7e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104e82:	8b 45 18             	mov    0x18(%ebp),%eax
f0104e85:	89 04 24             	mov    %eax,(%esp)
f0104e88:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0104e8a:	83 ee 01             	sub    $0x1,%esi
f0104e8d:	75 ef                	jne    f0104e7e <printnum+0x9e>
f0104e8f:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0104e92:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104e96:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0104e9a:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0104e9d:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0104ea0:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104ea4:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0104ea8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104eab:	89 04 24             	mov    %eax,(%esp)
f0104eae:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0104eb1:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104eb5:	e8 16 14 00 00       	call   f01062d0 <__umoddi3>
f0104eba:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104ebe:	0f be 80 bc 79 10 f0 	movsbl -0xfef8644(%eax),%eax
f0104ec5:	89 04 24             	mov    %eax,(%esp)
f0104ec8:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104ecb:	ff d0                	call   *%eax
}
f0104ecd:	83 c4 3c             	add    $0x3c,%esp
f0104ed0:	5b                   	pop    %ebx
f0104ed1:	5e                   	pop    %esi
f0104ed2:	5f                   	pop    %edi
f0104ed3:	5d                   	pop    %ebp
f0104ed4:	c3                   	ret    

f0104ed5 <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0104ed5:	55                   	push   %ebp
f0104ed6:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0104ed8:	83 fa 01             	cmp    $0x1,%edx
f0104edb:	7e 0e                	jle    f0104eeb <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f0104edd:	8b 10                	mov    (%eax),%edx
f0104edf:	8d 4a 08             	lea    0x8(%edx),%ecx
f0104ee2:	89 08                	mov    %ecx,(%eax)
f0104ee4:	8b 02                	mov    (%edx),%eax
f0104ee6:	8b 52 04             	mov    0x4(%edx),%edx
f0104ee9:	eb 22                	jmp    f0104f0d <getuint+0x38>
	else if (lflag)
f0104eeb:	85 d2                	test   %edx,%edx
f0104eed:	74 10                	je     f0104eff <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f0104eef:	8b 10                	mov    (%eax),%edx
f0104ef1:	8d 4a 04             	lea    0x4(%edx),%ecx
f0104ef4:	89 08                	mov    %ecx,(%eax)
f0104ef6:	8b 02                	mov    (%edx),%eax
f0104ef8:	ba 00 00 00 00       	mov    $0x0,%edx
f0104efd:	eb 0e                	jmp    f0104f0d <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f0104eff:	8b 10                	mov    (%eax),%edx
f0104f01:	8d 4a 04             	lea    0x4(%edx),%ecx
f0104f04:	89 08                	mov    %ecx,(%eax)
f0104f06:	8b 02                	mov    (%edx),%eax
f0104f08:	ba 00 00 00 00       	mov    $0x0,%edx
}
f0104f0d:	5d                   	pop    %ebp
f0104f0e:	c3                   	ret    

f0104f0f <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0104f0f:	55                   	push   %ebp
f0104f10:	89 e5                	mov    %esp,%ebp
f0104f12:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0104f15:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0104f19:	8b 10                	mov    (%eax),%edx
f0104f1b:	3b 50 04             	cmp    0x4(%eax),%edx
f0104f1e:	73 0a                	jae    f0104f2a <sprintputch+0x1b>
		*b->buf++ = ch;
f0104f20:	8d 4a 01             	lea    0x1(%edx),%ecx
f0104f23:	89 08                	mov    %ecx,(%eax)
f0104f25:	8b 45 08             	mov    0x8(%ebp),%eax
f0104f28:	88 02                	mov    %al,(%edx)
}
f0104f2a:	5d                   	pop    %ebp
f0104f2b:	c3                   	ret    

f0104f2c <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0104f2c:	55                   	push   %ebp
f0104f2d:	89 e5                	mov    %esp,%ebp
f0104f2f:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0104f32:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0104f35:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104f39:	8b 45 10             	mov    0x10(%ebp),%eax
f0104f3c:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104f40:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104f43:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104f47:	8b 45 08             	mov    0x8(%ebp),%eax
f0104f4a:	89 04 24             	mov    %eax,(%esp)
f0104f4d:	e8 02 00 00 00       	call   f0104f54 <vprintfmt>
	va_end(ap);
}
f0104f52:	c9                   	leave  
f0104f53:	c3                   	ret    

f0104f54 <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f0104f54:	55                   	push   %ebp
f0104f55:	89 e5                	mov    %esp,%ebp
f0104f57:	57                   	push   %edi
f0104f58:	56                   	push   %esi
f0104f59:	53                   	push   %ebx
f0104f5a:	83 ec 3c             	sub    $0x3c,%esp
f0104f5d:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0104f60:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0104f63:	eb 18                	jmp    f0104f7d <vprintfmt+0x29>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f0104f65:	85 c0                	test   %eax,%eax
f0104f67:	0f 84 c3 03 00 00    	je     f0105330 <vprintfmt+0x3dc>
				return;
			putch(ch, putdat);
f0104f6d:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104f71:	89 04 24             	mov    %eax,(%esp)
f0104f74:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0104f77:	89 f3                	mov    %esi,%ebx
f0104f79:	eb 02                	jmp    f0104f7d <vprintfmt+0x29>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f0104f7b:	89 f3                	mov    %esi,%ebx
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0104f7d:	8d 73 01             	lea    0x1(%ebx),%esi
f0104f80:	0f b6 03             	movzbl (%ebx),%eax
f0104f83:	83 f8 25             	cmp    $0x25,%eax
f0104f86:	75 dd                	jne    f0104f65 <vprintfmt+0x11>
f0104f88:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f0104f8c:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0104f93:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f0104f9a:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0104fa1:	ba 00 00 00 00       	mov    $0x0,%edx
f0104fa6:	eb 1d                	jmp    f0104fc5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104fa8:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f0104faa:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f0104fae:	eb 15                	jmp    f0104fc5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104fb0:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0104fb2:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f0104fb6:	eb 0d                	jmp    f0104fc5 <vprintfmt+0x71>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0104fb8:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0104fbb:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0104fbe:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104fc5:	8d 5e 01             	lea    0x1(%esi),%ebx
f0104fc8:	0f b6 06             	movzbl (%esi),%eax
f0104fcb:	0f b6 c8             	movzbl %al,%ecx
f0104fce:	83 e8 23             	sub    $0x23,%eax
f0104fd1:	3c 55                	cmp    $0x55,%al
f0104fd3:	0f 87 2f 03 00 00    	ja     f0105308 <vprintfmt+0x3b4>
f0104fd9:	0f b6 c0             	movzbl %al,%eax
f0104fdc:	ff 24 85 80 7a 10 f0 	jmp    *-0xfef8580(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0104fe3:	8d 41 d0             	lea    -0x30(%ecx),%eax
f0104fe6:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0104fe9:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f0104fed:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0104ff0:	83 f9 09             	cmp    $0x9,%ecx
f0104ff3:	77 50                	ja     f0105045 <vprintfmt+0xf1>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104ff5:	89 de                	mov    %ebx,%esi
f0104ff7:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f0104ffa:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f0104ffd:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0105000:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0105004:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0105007:	8d 58 d0             	lea    -0x30(%eax),%ebx
f010500a:	83 fb 09             	cmp    $0x9,%ebx
f010500d:	76 eb                	jbe    f0104ffa <vprintfmt+0xa6>
f010500f:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0105012:	eb 33                	jmp    f0105047 <vprintfmt+0xf3>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0105014:	8b 45 14             	mov    0x14(%ebp),%eax
f0105017:	8d 48 04             	lea    0x4(%eax),%ecx
f010501a:	89 4d 14             	mov    %ecx,0x14(%ebp)
f010501d:	8b 00                	mov    (%eax),%eax
f010501f:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105022:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0105024:	eb 21                	jmp    f0105047 <vprintfmt+0xf3>
f0105026:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0105029:	85 c9                	test   %ecx,%ecx
f010502b:	b8 00 00 00 00       	mov    $0x0,%eax
f0105030:	0f 49 c1             	cmovns %ecx,%eax
f0105033:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105036:	89 de                	mov    %ebx,%esi
f0105038:	eb 8b                	jmp    f0104fc5 <vprintfmt+0x71>
f010503a:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f010503c:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f0105043:	eb 80                	jmp    f0104fc5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105045:	89 de                	mov    %ebx,%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0105047:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f010504b:	0f 89 74 ff ff ff    	jns    f0104fc5 <vprintfmt+0x71>
f0105051:	e9 62 ff ff ff       	jmp    f0104fb8 <vprintfmt+0x64>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0105056:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105059:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f010505b:	e9 65 ff ff ff       	jmp    f0104fc5 <vprintfmt+0x71>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f0105060:	8b 45 14             	mov    0x14(%ebp),%eax
f0105063:	8d 50 04             	lea    0x4(%eax),%edx
f0105066:	89 55 14             	mov    %edx,0x14(%ebp)
f0105069:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010506d:	8b 00                	mov    (%eax),%eax
f010506f:	89 04 24             	mov    %eax,(%esp)
f0105072:	ff 55 08             	call   *0x8(%ebp)
			break;
f0105075:	e9 03 ff ff ff       	jmp    f0104f7d <vprintfmt+0x29>

		// error message
		case 'e':
			err = va_arg(ap, int);
f010507a:	8b 45 14             	mov    0x14(%ebp),%eax
f010507d:	8d 50 04             	lea    0x4(%eax),%edx
f0105080:	89 55 14             	mov    %edx,0x14(%ebp)
f0105083:	8b 00                	mov    (%eax),%eax
f0105085:	99                   	cltd   
f0105086:	31 d0                	xor    %edx,%eax
f0105088:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f010508a:	83 f8 08             	cmp    $0x8,%eax
f010508d:	7f 0b                	jg     f010509a <vprintfmt+0x146>
f010508f:	8b 14 85 e0 7b 10 f0 	mov    -0xfef8420(,%eax,4),%edx
f0105096:	85 d2                	test   %edx,%edx
f0105098:	75 20                	jne    f01050ba <vprintfmt+0x166>
				printfmt(putch, putdat, "error %d", err);
f010509a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010509e:	c7 44 24 08 d4 79 10 	movl   $0xf01079d4,0x8(%esp)
f01050a5:	f0 
f01050a6:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01050aa:	8b 45 08             	mov    0x8(%ebp),%eax
f01050ad:	89 04 24             	mov    %eax,(%esp)
f01050b0:	e8 77 fe ff ff       	call   f0104f2c <printfmt>
f01050b5:	e9 c3 fe ff ff       	jmp    f0104f7d <vprintfmt+0x29>
			else
				printfmt(putch, putdat, "%s", p);
f01050ba:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01050be:	c7 44 24 08 a5 71 10 	movl   $0xf01071a5,0x8(%esp)
f01050c5:	f0 
f01050c6:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01050ca:	8b 45 08             	mov    0x8(%ebp),%eax
f01050cd:	89 04 24             	mov    %eax,(%esp)
f01050d0:	e8 57 fe ff ff       	call   f0104f2c <printfmt>
f01050d5:	e9 a3 fe ff ff       	jmp    f0104f7d <vprintfmt+0x29>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01050da:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01050dd:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f01050e0:	8b 45 14             	mov    0x14(%ebp),%eax
f01050e3:	8d 50 04             	lea    0x4(%eax),%edx
f01050e6:	89 55 14             	mov    %edx,0x14(%ebp)
f01050e9:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f01050eb:	85 c0                	test   %eax,%eax
f01050ed:	ba cd 79 10 f0       	mov    $0xf01079cd,%edx
f01050f2:	0f 45 d0             	cmovne %eax,%edx
f01050f5:	89 55 d0             	mov    %edx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f01050f8:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f01050fc:	74 04                	je     f0105102 <vprintfmt+0x1ae>
f01050fe:	85 f6                	test   %esi,%esi
f0105100:	7f 19                	jg     f010511b <vprintfmt+0x1c7>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0105102:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0105105:	8d 70 01             	lea    0x1(%eax),%esi
f0105108:	0f b6 10             	movzbl (%eax),%edx
f010510b:	0f be c2             	movsbl %dl,%eax
f010510e:	85 c0                	test   %eax,%eax
f0105110:	0f 85 95 00 00 00    	jne    f01051ab <vprintfmt+0x257>
f0105116:	e9 85 00 00 00       	jmp    f01051a0 <vprintfmt+0x24c>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f010511b:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f010511f:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0105122:	89 04 24             	mov    %eax,(%esp)
f0105125:	e8 88 03 00 00       	call   f01054b2 <strnlen>
f010512a:	29 c6                	sub    %eax,%esi
f010512c:	89 f0                	mov    %esi,%eax
f010512e:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0105131:	85 f6                	test   %esi,%esi
f0105133:	7e cd                	jle    f0105102 <vprintfmt+0x1ae>
					putch(padc, putdat);
f0105135:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105139:	89 5d 10             	mov    %ebx,0x10(%ebp)
f010513c:	89 c3                	mov    %eax,%ebx
f010513e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105142:	89 34 24             	mov    %esi,(%esp)
f0105145:	ff 55 08             	call   *0x8(%ebp)
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0105148:	83 eb 01             	sub    $0x1,%ebx
f010514b:	75 f1                	jne    f010513e <vprintfmt+0x1ea>
f010514d:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0105150:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0105153:	eb ad                	jmp    f0105102 <vprintfmt+0x1ae>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f0105155:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0105159:	74 1e                	je     f0105179 <vprintfmt+0x225>
f010515b:	0f be d2             	movsbl %dl,%edx
f010515e:	83 ea 20             	sub    $0x20,%edx
f0105161:	83 fa 5e             	cmp    $0x5e,%edx
f0105164:	76 13                	jbe    f0105179 <vprintfmt+0x225>
					putch('?', putdat);
f0105166:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105169:	89 44 24 04          	mov    %eax,0x4(%esp)
f010516d:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f0105174:	ff 55 08             	call   *0x8(%ebp)
f0105177:	eb 0d                	jmp    f0105186 <vprintfmt+0x232>
				else
					putch(ch, putdat);
f0105179:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f010517c:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0105180:	89 04 24             	mov    %eax,(%esp)
f0105183:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0105186:	83 ef 01             	sub    $0x1,%edi
f0105189:	83 c6 01             	add    $0x1,%esi
f010518c:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f0105190:	0f be c2             	movsbl %dl,%eax
f0105193:	85 c0                	test   %eax,%eax
f0105195:	75 20                	jne    f01051b7 <vprintfmt+0x263>
f0105197:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f010519a:	8b 7d 0c             	mov    0xc(%ebp),%edi
f010519d:	8b 5d 10             	mov    0x10(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01051a0:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01051a4:	7f 25                	jg     f01051cb <vprintfmt+0x277>
f01051a6:	e9 d2 fd ff ff       	jmp    f0104f7d <vprintfmt+0x29>
f01051ab:	89 7d 0c             	mov    %edi,0xc(%ebp)
f01051ae:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01051b1:	89 5d 10             	mov    %ebx,0x10(%ebp)
f01051b4:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01051b7:	85 db                	test   %ebx,%ebx
f01051b9:	78 9a                	js     f0105155 <vprintfmt+0x201>
f01051bb:	83 eb 01             	sub    $0x1,%ebx
f01051be:	79 95                	jns    f0105155 <vprintfmt+0x201>
f01051c0:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f01051c3:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01051c6:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01051c9:	eb d5                	jmp    f01051a0 <vprintfmt+0x24c>
f01051cb:	8b 75 08             	mov    0x8(%ebp),%esi
f01051ce:	89 5d 10             	mov    %ebx,0x10(%ebp)
f01051d1:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f01051d4:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01051d8:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f01051df:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01051e1:	83 eb 01             	sub    $0x1,%ebx
f01051e4:	75 ee                	jne    f01051d4 <vprintfmt+0x280>
f01051e6:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01051e9:	e9 8f fd ff ff       	jmp    f0104f7d <vprintfmt+0x29>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f01051ee:	83 fa 01             	cmp    $0x1,%edx
f01051f1:	7e 16                	jle    f0105209 <vprintfmt+0x2b5>
		return va_arg(*ap, long long);
f01051f3:	8b 45 14             	mov    0x14(%ebp),%eax
f01051f6:	8d 50 08             	lea    0x8(%eax),%edx
f01051f9:	89 55 14             	mov    %edx,0x14(%ebp)
f01051fc:	8b 50 04             	mov    0x4(%eax),%edx
f01051ff:	8b 00                	mov    (%eax),%eax
f0105201:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0105204:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0105207:	eb 32                	jmp    f010523b <vprintfmt+0x2e7>
	else if (lflag)
f0105209:	85 d2                	test   %edx,%edx
f010520b:	74 18                	je     f0105225 <vprintfmt+0x2d1>
		return va_arg(*ap, long);
f010520d:	8b 45 14             	mov    0x14(%ebp),%eax
f0105210:	8d 50 04             	lea    0x4(%eax),%edx
f0105213:	89 55 14             	mov    %edx,0x14(%ebp)
f0105216:	8b 30                	mov    (%eax),%esi
f0105218:	89 75 d8             	mov    %esi,-0x28(%ebp)
f010521b:	89 f0                	mov    %esi,%eax
f010521d:	c1 f8 1f             	sar    $0x1f,%eax
f0105220:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0105223:	eb 16                	jmp    f010523b <vprintfmt+0x2e7>
	else
		return va_arg(*ap, int);
f0105225:	8b 45 14             	mov    0x14(%ebp),%eax
f0105228:	8d 50 04             	lea    0x4(%eax),%edx
f010522b:	89 55 14             	mov    %edx,0x14(%ebp)
f010522e:	8b 30                	mov    (%eax),%esi
f0105230:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105233:	89 f0                	mov    %esi,%eax
f0105235:	c1 f8 1f             	sar    $0x1f,%eax
f0105238:	89 45 dc             	mov    %eax,-0x24(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f010523b:	8b 45 d8             	mov    -0x28(%ebp),%eax
f010523e:	8b 55 dc             	mov    -0x24(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f0105241:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0105246:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f010524a:	0f 89 80 00 00 00    	jns    f01052d0 <vprintfmt+0x37c>
				putch('-', putdat);
f0105250:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105254:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f010525b:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f010525e:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0105261:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0105264:	f7 d8                	neg    %eax
f0105266:	83 d2 00             	adc    $0x0,%edx
f0105269:	f7 da                	neg    %edx
			}
			base = 10;
f010526b:	b9 0a 00 00 00       	mov    $0xa,%ecx
f0105270:	eb 5e                	jmp    f01052d0 <vprintfmt+0x37c>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f0105272:	8d 45 14             	lea    0x14(%ebp),%eax
f0105275:	e8 5b fc ff ff       	call   f0104ed5 <getuint>
			base = 10;
f010527a:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f010527f:	eb 4f                	jmp    f01052d0 <vprintfmt+0x37c>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			//putch('X', putdat);
			num = getuint(&ap, lflag);
f0105281:	8d 45 14             	lea    0x14(%ebp),%eax
f0105284:	e8 4c fc ff ff       	call   f0104ed5 <getuint>
			base = 8;
f0105289:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f010528e:	eb 40                	jmp    f01052d0 <vprintfmt+0x37c>
			//putch('X', putdat);
			//break;

		// pointer
		case 'p':
			putch('0', putdat);
f0105290:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105294:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f010529b:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f010529e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01052a2:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f01052a9:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f01052ac:	8b 45 14             	mov    0x14(%ebp),%eax
f01052af:	8d 50 04             	lea    0x4(%eax),%edx
f01052b2:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f01052b5:	8b 00                	mov    (%eax),%eax
f01052b7:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f01052bc:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f01052c1:	eb 0d                	jmp    f01052d0 <vprintfmt+0x37c>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f01052c3:	8d 45 14             	lea    0x14(%ebp),%eax
f01052c6:	e8 0a fc ff ff       	call   f0104ed5 <getuint>
			base = 16;
f01052cb:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f01052d0:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f01052d4:	89 74 24 10          	mov    %esi,0x10(%esp)
f01052d8:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f01052db:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01052df:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01052e3:	89 04 24             	mov    %eax,(%esp)
f01052e6:	89 54 24 04          	mov    %edx,0x4(%esp)
f01052ea:	89 fa                	mov    %edi,%edx
f01052ec:	8b 45 08             	mov    0x8(%ebp),%eax
f01052ef:	e8 ec fa ff ff       	call   f0104de0 <printnum>
			break;
f01052f4:	e9 84 fc ff ff       	jmp    f0104f7d <vprintfmt+0x29>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f01052f9:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01052fd:	89 0c 24             	mov    %ecx,(%esp)
f0105300:	ff 55 08             	call   *0x8(%ebp)
			break;
f0105303:	e9 75 fc ff ff       	jmp    f0104f7d <vprintfmt+0x29>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0105308:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010530c:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0105313:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f0105316:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f010531a:	0f 84 5b fc ff ff    	je     f0104f7b <vprintfmt+0x27>
f0105320:	89 f3                	mov    %esi,%ebx
f0105322:	83 eb 01             	sub    $0x1,%ebx
f0105325:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f0105329:	75 f7                	jne    f0105322 <vprintfmt+0x3ce>
f010532b:	e9 4d fc ff ff       	jmp    f0104f7d <vprintfmt+0x29>
				/* do nothing */;
			break;
		}
	}
}
f0105330:	83 c4 3c             	add    $0x3c,%esp
f0105333:	5b                   	pop    %ebx
f0105334:	5e                   	pop    %esi
f0105335:	5f                   	pop    %edi
f0105336:	5d                   	pop    %ebp
f0105337:	c3                   	ret    

f0105338 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0105338:	55                   	push   %ebp
f0105339:	89 e5                	mov    %esp,%ebp
f010533b:	83 ec 28             	sub    $0x28,%esp
f010533e:	8b 45 08             	mov    0x8(%ebp),%eax
f0105341:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0105344:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0105347:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f010534b:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f010534e:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0105355:	85 c0                	test   %eax,%eax
f0105357:	74 30                	je     f0105389 <vsnprintf+0x51>
f0105359:	85 d2                	test   %edx,%edx
f010535b:	7e 2c                	jle    f0105389 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f010535d:	8b 45 14             	mov    0x14(%ebp),%eax
f0105360:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105364:	8b 45 10             	mov    0x10(%ebp),%eax
f0105367:	89 44 24 08          	mov    %eax,0x8(%esp)
f010536b:	8d 45 ec             	lea    -0x14(%ebp),%eax
f010536e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105372:	c7 04 24 0f 4f 10 f0 	movl   $0xf0104f0f,(%esp)
f0105379:	e8 d6 fb ff ff       	call   f0104f54 <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f010537e:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0105381:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0105384:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0105387:	eb 05                	jmp    f010538e <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f0105389:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f010538e:	c9                   	leave  
f010538f:	c3                   	ret    

f0105390 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f0105390:	55                   	push   %ebp
f0105391:	89 e5                	mov    %esp,%ebp
f0105393:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0105396:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f0105399:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010539d:	8b 45 10             	mov    0x10(%ebp),%eax
f01053a0:	89 44 24 08          	mov    %eax,0x8(%esp)
f01053a4:	8b 45 0c             	mov    0xc(%ebp),%eax
f01053a7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01053ab:	8b 45 08             	mov    0x8(%ebp),%eax
f01053ae:	89 04 24             	mov    %eax,(%esp)
f01053b1:	e8 82 ff ff ff       	call   f0105338 <vsnprintf>
	va_end(ap);

	return rc;
}
f01053b6:	c9                   	leave  
f01053b7:	c3                   	ret    
f01053b8:	66 90                	xchg   %ax,%ax
f01053ba:	66 90                	xchg   %ax,%ax
f01053bc:	66 90                	xchg   %ax,%ax
f01053be:	66 90                	xchg   %ax,%ax

f01053c0 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f01053c0:	55                   	push   %ebp
f01053c1:	89 e5                	mov    %esp,%ebp
f01053c3:	57                   	push   %edi
f01053c4:	56                   	push   %esi
f01053c5:	53                   	push   %ebx
f01053c6:	83 ec 1c             	sub    $0x1c,%esp
f01053c9:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f01053cc:	85 c0                	test   %eax,%eax
f01053ce:	74 10                	je     f01053e0 <readline+0x20>
		cprintf("%s", prompt);
f01053d0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01053d4:	c7 04 24 a5 71 10 f0 	movl   $0xf01071a5,(%esp)
f01053db:	e8 fe ea ff ff       	call   f0103ede <cprintf>

	i = 0;
	echoing = iscons(0);
f01053e0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01053e7:	e8 12 b4 ff ff       	call   f01007fe <iscons>
f01053ec:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f01053ee:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f01053f3:	e8 f5 b3 ff ff       	call   f01007ed <getchar>
f01053f8:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f01053fa:	85 c0                	test   %eax,%eax
f01053fc:	79 17                	jns    f0105415 <readline+0x55>
			cprintf("read error: %e\n", c);
f01053fe:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105402:	c7 04 24 04 7c 10 f0 	movl   $0xf0107c04,(%esp)
f0105409:	e8 d0 ea ff ff       	call   f0103ede <cprintf>
			return NULL;
f010540e:	b8 00 00 00 00       	mov    $0x0,%eax
f0105413:	eb 6d                	jmp    f0105482 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0105415:	83 f8 7f             	cmp    $0x7f,%eax
f0105418:	74 05                	je     f010541f <readline+0x5f>
f010541a:	83 f8 08             	cmp    $0x8,%eax
f010541d:	75 19                	jne    f0105438 <readline+0x78>
f010541f:	85 f6                	test   %esi,%esi
f0105421:	7e 15                	jle    f0105438 <readline+0x78>
			if (echoing)
f0105423:	85 ff                	test   %edi,%edi
f0105425:	74 0c                	je     f0105433 <readline+0x73>
				cputchar('\b');
f0105427:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f010542e:	e8 aa b3 ff ff       	call   f01007dd <cputchar>
			i--;
f0105433:	83 ee 01             	sub    $0x1,%esi
f0105436:	eb bb                	jmp    f01053f3 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0105438:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f010543e:	7f 1c                	jg     f010545c <readline+0x9c>
f0105440:	83 fb 1f             	cmp    $0x1f,%ebx
f0105443:	7e 17                	jle    f010545c <readline+0x9c>
			if (echoing)
f0105445:	85 ff                	test   %edi,%edi
f0105447:	74 08                	je     f0105451 <readline+0x91>
				cputchar(c);
f0105449:	89 1c 24             	mov    %ebx,(%esp)
f010544c:	e8 8c b3 ff ff       	call   f01007dd <cputchar>
			buf[i++] = c;
f0105451:	88 9e 80 3a 22 f0    	mov    %bl,-0xfddc580(%esi)
f0105457:	8d 76 01             	lea    0x1(%esi),%esi
f010545a:	eb 97                	jmp    f01053f3 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f010545c:	83 fb 0d             	cmp    $0xd,%ebx
f010545f:	74 05                	je     f0105466 <readline+0xa6>
f0105461:	83 fb 0a             	cmp    $0xa,%ebx
f0105464:	75 8d                	jne    f01053f3 <readline+0x33>
			if (echoing)
f0105466:	85 ff                	test   %edi,%edi
f0105468:	74 0c                	je     f0105476 <readline+0xb6>
				cputchar('\n');
f010546a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0105471:	e8 67 b3 ff ff       	call   f01007dd <cputchar>
			buf[i] = 0;
f0105476:	c6 86 80 3a 22 f0 00 	movb   $0x0,-0xfddc580(%esi)
			return buf;
f010547d:	b8 80 3a 22 f0       	mov    $0xf0223a80,%eax
		}
	}
}
f0105482:	83 c4 1c             	add    $0x1c,%esp
f0105485:	5b                   	pop    %ebx
f0105486:	5e                   	pop    %esi
f0105487:	5f                   	pop    %edi
f0105488:	5d                   	pop    %ebp
f0105489:	c3                   	ret    
f010548a:	66 90                	xchg   %ax,%ax
f010548c:	66 90                	xchg   %ax,%ax
f010548e:	66 90                	xchg   %ax,%ax

f0105490 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0105490:	55                   	push   %ebp
f0105491:	89 e5                	mov    %esp,%ebp
f0105493:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0105496:	80 3a 00             	cmpb   $0x0,(%edx)
f0105499:	74 10                	je     f01054ab <strlen+0x1b>
f010549b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f01054a0:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f01054a3:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f01054a7:	75 f7                	jne    f01054a0 <strlen+0x10>
f01054a9:	eb 05                	jmp    f01054b0 <strlen+0x20>
f01054ab:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f01054b0:	5d                   	pop    %ebp
f01054b1:	c3                   	ret    

f01054b2 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f01054b2:	55                   	push   %ebp
f01054b3:	89 e5                	mov    %esp,%ebp
f01054b5:	53                   	push   %ebx
f01054b6:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01054b9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01054bc:	85 c9                	test   %ecx,%ecx
f01054be:	74 1c                	je     f01054dc <strnlen+0x2a>
f01054c0:	80 3b 00             	cmpb   $0x0,(%ebx)
f01054c3:	74 1e                	je     f01054e3 <strnlen+0x31>
f01054c5:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f01054ca:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01054cc:	39 ca                	cmp    %ecx,%edx
f01054ce:	74 18                	je     f01054e8 <strnlen+0x36>
f01054d0:	83 c2 01             	add    $0x1,%edx
f01054d3:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f01054d8:	75 f0                	jne    f01054ca <strnlen+0x18>
f01054da:	eb 0c                	jmp    f01054e8 <strnlen+0x36>
f01054dc:	b8 00 00 00 00       	mov    $0x0,%eax
f01054e1:	eb 05                	jmp    f01054e8 <strnlen+0x36>
f01054e3:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f01054e8:	5b                   	pop    %ebx
f01054e9:	5d                   	pop    %ebp
f01054ea:	c3                   	ret    

f01054eb <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f01054eb:	55                   	push   %ebp
f01054ec:	89 e5                	mov    %esp,%ebp
f01054ee:	53                   	push   %ebx
f01054ef:	8b 45 08             	mov    0x8(%ebp),%eax
f01054f2:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f01054f5:	89 c2                	mov    %eax,%edx
f01054f7:	83 c2 01             	add    $0x1,%edx
f01054fa:	83 c1 01             	add    $0x1,%ecx
f01054fd:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0105501:	88 5a ff             	mov    %bl,-0x1(%edx)
f0105504:	84 db                	test   %bl,%bl
f0105506:	75 ef                	jne    f01054f7 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0105508:	5b                   	pop    %ebx
f0105509:	5d                   	pop    %ebp
f010550a:	c3                   	ret    

f010550b <strcat>:

char *
strcat(char *dst, const char *src)
{
f010550b:	55                   	push   %ebp
f010550c:	89 e5                	mov    %esp,%ebp
f010550e:	53                   	push   %ebx
f010550f:	83 ec 08             	sub    $0x8,%esp
f0105512:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f0105515:	89 1c 24             	mov    %ebx,(%esp)
f0105518:	e8 73 ff ff ff       	call   f0105490 <strlen>
	strcpy(dst + len, src);
f010551d:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105520:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105524:	01 d8                	add    %ebx,%eax
f0105526:	89 04 24             	mov    %eax,(%esp)
f0105529:	e8 bd ff ff ff       	call   f01054eb <strcpy>
	return dst;
}
f010552e:	89 d8                	mov    %ebx,%eax
f0105530:	83 c4 08             	add    $0x8,%esp
f0105533:	5b                   	pop    %ebx
f0105534:	5d                   	pop    %ebp
f0105535:	c3                   	ret    

f0105536 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f0105536:	55                   	push   %ebp
f0105537:	89 e5                	mov    %esp,%ebp
f0105539:	56                   	push   %esi
f010553a:	53                   	push   %ebx
f010553b:	8b 75 08             	mov    0x8(%ebp),%esi
f010553e:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105541:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0105544:	85 db                	test   %ebx,%ebx
f0105546:	74 17                	je     f010555f <strncpy+0x29>
f0105548:	01 f3                	add    %esi,%ebx
f010554a:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f010554c:	83 c1 01             	add    $0x1,%ecx
f010554f:	0f b6 02             	movzbl (%edx),%eax
f0105552:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f0105555:	80 3a 01             	cmpb   $0x1,(%edx)
f0105558:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f010555b:	39 d9                	cmp    %ebx,%ecx
f010555d:	75 ed                	jne    f010554c <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f010555f:	89 f0                	mov    %esi,%eax
f0105561:	5b                   	pop    %ebx
f0105562:	5e                   	pop    %esi
f0105563:	5d                   	pop    %ebp
f0105564:	c3                   	ret    

f0105565 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f0105565:	55                   	push   %ebp
f0105566:	89 e5                	mov    %esp,%ebp
f0105568:	57                   	push   %edi
f0105569:	56                   	push   %esi
f010556a:	53                   	push   %ebx
f010556b:	8b 7d 08             	mov    0x8(%ebp),%edi
f010556e:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0105571:	8b 75 10             	mov    0x10(%ebp),%esi
f0105574:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0105576:	85 f6                	test   %esi,%esi
f0105578:	74 34                	je     f01055ae <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f010557a:	83 fe 01             	cmp    $0x1,%esi
f010557d:	74 26                	je     f01055a5 <strlcpy+0x40>
f010557f:	0f b6 0b             	movzbl (%ebx),%ecx
f0105582:	84 c9                	test   %cl,%cl
f0105584:	74 23                	je     f01055a9 <strlcpy+0x44>
f0105586:	83 ee 02             	sub    $0x2,%esi
f0105589:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f010558e:	83 c0 01             	add    $0x1,%eax
f0105591:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0105594:	39 f2                	cmp    %esi,%edx
f0105596:	74 13                	je     f01055ab <strlcpy+0x46>
f0105598:	83 c2 01             	add    $0x1,%edx
f010559b:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f010559f:	84 c9                	test   %cl,%cl
f01055a1:	75 eb                	jne    f010558e <strlcpy+0x29>
f01055a3:	eb 06                	jmp    f01055ab <strlcpy+0x46>
f01055a5:	89 f8                	mov    %edi,%eax
f01055a7:	eb 02                	jmp    f01055ab <strlcpy+0x46>
f01055a9:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f01055ab:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f01055ae:	29 f8                	sub    %edi,%eax
}
f01055b0:	5b                   	pop    %ebx
f01055b1:	5e                   	pop    %esi
f01055b2:	5f                   	pop    %edi
f01055b3:	5d                   	pop    %ebp
f01055b4:	c3                   	ret    

f01055b5 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f01055b5:	55                   	push   %ebp
f01055b6:	89 e5                	mov    %esp,%ebp
f01055b8:	8b 4d 08             	mov    0x8(%ebp),%ecx
f01055bb:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f01055be:	0f b6 01             	movzbl (%ecx),%eax
f01055c1:	84 c0                	test   %al,%al
f01055c3:	74 15                	je     f01055da <strcmp+0x25>
f01055c5:	3a 02                	cmp    (%edx),%al
f01055c7:	75 11                	jne    f01055da <strcmp+0x25>
		p++, q++;
f01055c9:	83 c1 01             	add    $0x1,%ecx
f01055cc:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f01055cf:	0f b6 01             	movzbl (%ecx),%eax
f01055d2:	84 c0                	test   %al,%al
f01055d4:	74 04                	je     f01055da <strcmp+0x25>
f01055d6:	3a 02                	cmp    (%edx),%al
f01055d8:	74 ef                	je     f01055c9 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f01055da:	0f b6 c0             	movzbl %al,%eax
f01055dd:	0f b6 12             	movzbl (%edx),%edx
f01055e0:	29 d0                	sub    %edx,%eax
}
f01055e2:	5d                   	pop    %ebp
f01055e3:	c3                   	ret    

f01055e4 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f01055e4:	55                   	push   %ebp
f01055e5:	89 e5                	mov    %esp,%ebp
f01055e7:	56                   	push   %esi
f01055e8:	53                   	push   %ebx
f01055e9:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01055ec:	8b 55 0c             	mov    0xc(%ebp),%edx
f01055ef:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f01055f2:	85 f6                	test   %esi,%esi
f01055f4:	74 29                	je     f010561f <strncmp+0x3b>
f01055f6:	0f b6 03             	movzbl (%ebx),%eax
f01055f9:	84 c0                	test   %al,%al
f01055fb:	74 30                	je     f010562d <strncmp+0x49>
f01055fd:	3a 02                	cmp    (%edx),%al
f01055ff:	75 2c                	jne    f010562d <strncmp+0x49>
f0105601:	8d 43 01             	lea    0x1(%ebx),%eax
f0105604:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f0105606:	89 c3                	mov    %eax,%ebx
f0105608:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f010560b:	39 f0                	cmp    %esi,%eax
f010560d:	74 17                	je     f0105626 <strncmp+0x42>
f010560f:	0f b6 08             	movzbl (%eax),%ecx
f0105612:	84 c9                	test   %cl,%cl
f0105614:	74 17                	je     f010562d <strncmp+0x49>
f0105616:	83 c0 01             	add    $0x1,%eax
f0105619:	3a 0a                	cmp    (%edx),%cl
f010561b:	74 e9                	je     f0105606 <strncmp+0x22>
f010561d:	eb 0e                	jmp    f010562d <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f010561f:	b8 00 00 00 00       	mov    $0x0,%eax
f0105624:	eb 0f                	jmp    f0105635 <strncmp+0x51>
f0105626:	b8 00 00 00 00       	mov    $0x0,%eax
f010562b:	eb 08                	jmp    f0105635 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f010562d:	0f b6 03             	movzbl (%ebx),%eax
f0105630:	0f b6 12             	movzbl (%edx),%edx
f0105633:	29 d0                	sub    %edx,%eax
}
f0105635:	5b                   	pop    %ebx
f0105636:	5e                   	pop    %esi
f0105637:	5d                   	pop    %ebp
f0105638:	c3                   	ret    

f0105639 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f0105639:	55                   	push   %ebp
f010563a:	89 e5                	mov    %esp,%ebp
f010563c:	53                   	push   %ebx
f010563d:	8b 45 08             	mov    0x8(%ebp),%eax
f0105640:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105643:	0f b6 18             	movzbl (%eax),%ebx
f0105646:	84 db                	test   %bl,%bl
f0105648:	74 1d                	je     f0105667 <strchr+0x2e>
f010564a:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f010564c:	38 d3                	cmp    %dl,%bl
f010564e:	75 06                	jne    f0105656 <strchr+0x1d>
f0105650:	eb 1a                	jmp    f010566c <strchr+0x33>
f0105652:	38 ca                	cmp    %cl,%dl
f0105654:	74 16                	je     f010566c <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0105656:	83 c0 01             	add    $0x1,%eax
f0105659:	0f b6 10             	movzbl (%eax),%edx
f010565c:	84 d2                	test   %dl,%dl
f010565e:	75 f2                	jne    f0105652 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0105660:	b8 00 00 00 00       	mov    $0x0,%eax
f0105665:	eb 05                	jmp    f010566c <strchr+0x33>
f0105667:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010566c:	5b                   	pop    %ebx
f010566d:	5d                   	pop    %ebp
f010566e:	c3                   	ret    

f010566f <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f010566f:	55                   	push   %ebp
f0105670:	89 e5                	mov    %esp,%ebp
f0105672:	53                   	push   %ebx
f0105673:	8b 45 08             	mov    0x8(%ebp),%eax
f0105676:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105679:	0f b6 18             	movzbl (%eax),%ebx
f010567c:	84 db                	test   %bl,%bl
f010567e:	74 16                	je     f0105696 <strfind+0x27>
f0105680:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0105682:	38 d3                	cmp    %dl,%bl
f0105684:	75 06                	jne    f010568c <strfind+0x1d>
f0105686:	eb 0e                	jmp    f0105696 <strfind+0x27>
f0105688:	38 ca                	cmp    %cl,%dl
f010568a:	74 0a                	je     f0105696 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f010568c:	83 c0 01             	add    $0x1,%eax
f010568f:	0f b6 10             	movzbl (%eax),%edx
f0105692:	84 d2                	test   %dl,%dl
f0105694:	75 f2                	jne    f0105688 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f0105696:	5b                   	pop    %ebx
f0105697:	5d                   	pop    %ebp
f0105698:	c3                   	ret    

f0105699 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f0105699:	55                   	push   %ebp
f010569a:	89 e5                	mov    %esp,%ebp
f010569c:	57                   	push   %edi
f010569d:	56                   	push   %esi
f010569e:	53                   	push   %ebx
f010569f:	8b 7d 08             	mov    0x8(%ebp),%edi
f01056a2:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f01056a5:	85 c9                	test   %ecx,%ecx
f01056a7:	74 36                	je     f01056df <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f01056a9:	f7 c7 03 00 00 00    	test   $0x3,%edi
f01056af:	75 28                	jne    f01056d9 <memset+0x40>
f01056b1:	f6 c1 03             	test   $0x3,%cl
f01056b4:	75 23                	jne    f01056d9 <memset+0x40>
		c &= 0xFF;
f01056b6:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f01056ba:	89 d3                	mov    %edx,%ebx
f01056bc:	c1 e3 08             	shl    $0x8,%ebx
f01056bf:	89 d6                	mov    %edx,%esi
f01056c1:	c1 e6 18             	shl    $0x18,%esi
f01056c4:	89 d0                	mov    %edx,%eax
f01056c6:	c1 e0 10             	shl    $0x10,%eax
f01056c9:	09 f0                	or     %esi,%eax
f01056cb:	09 c2                	or     %eax,%edx
f01056cd:	89 d0                	mov    %edx,%eax
f01056cf:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f01056d1:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f01056d4:	fc                   	cld    
f01056d5:	f3 ab                	rep stos %eax,%es:(%edi)
f01056d7:	eb 06                	jmp    f01056df <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f01056d9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01056dc:	fc                   	cld    
f01056dd:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f01056df:	89 f8                	mov    %edi,%eax
f01056e1:	5b                   	pop    %ebx
f01056e2:	5e                   	pop    %esi
f01056e3:	5f                   	pop    %edi
f01056e4:	5d                   	pop    %ebp
f01056e5:	c3                   	ret    

f01056e6 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f01056e6:	55                   	push   %ebp
f01056e7:	89 e5                	mov    %esp,%ebp
f01056e9:	57                   	push   %edi
f01056ea:	56                   	push   %esi
f01056eb:	8b 45 08             	mov    0x8(%ebp),%eax
f01056ee:	8b 75 0c             	mov    0xc(%ebp),%esi
f01056f1:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f01056f4:	39 c6                	cmp    %eax,%esi
f01056f6:	73 35                	jae    f010572d <memmove+0x47>
f01056f8:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f01056fb:	39 d0                	cmp    %edx,%eax
f01056fd:	73 2e                	jae    f010572d <memmove+0x47>
		s += n;
		d += n;
f01056ff:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0105702:	89 d6                	mov    %edx,%esi
f0105704:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105706:	f7 c6 03 00 00 00    	test   $0x3,%esi
f010570c:	75 13                	jne    f0105721 <memmove+0x3b>
f010570e:	f6 c1 03             	test   $0x3,%cl
f0105711:	75 0e                	jne    f0105721 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0105713:	83 ef 04             	sub    $0x4,%edi
f0105716:	8d 72 fc             	lea    -0x4(%edx),%esi
f0105719:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f010571c:	fd                   	std    
f010571d:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f010571f:	eb 09                	jmp    f010572a <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0105721:	83 ef 01             	sub    $0x1,%edi
f0105724:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0105727:	fd                   	std    
f0105728:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f010572a:	fc                   	cld    
f010572b:	eb 1d                	jmp    f010574a <memmove+0x64>
f010572d:	89 f2                	mov    %esi,%edx
f010572f:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105731:	f6 c2 03             	test   $0x3,%dl
f0105734:	75 0f                	jne    f0105745 <memmove+0x5f>
f0105736:	f6 c1 03             	test   $0x3,%cl
f0105739:	75 0a                	jne    f0105745 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f010573b:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f010573e:	89 c7                	mov    %eax,%edi
f0105740:	fc                   	cld    
f0105741:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0105743:	eb 05                	jmp    f010574a <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0105745:	89 c7                	mov    %eax,%edi
f0105747:	fc                   	cld    
f0105748:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f010574a:	5e                   	pop    %esi
f010574b:	5f                   	pop    %edi
f010574c:	5d                   	pop    %ebp
f010574d:	c3                   	ret    

f010574e <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f010574e:	55                   	push   %ebp
f010574f:	89 e5                	mov    %esp,%ebp
f0105751:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0105754:	8b 45 10             	mov    0x10(%ebp),%eax
f0105757:	89 44 24 08          	mov    %eax,0x8(%esp)
f010575b:	8b 45 0c             	mov    0xc(%ebp),%eax
f010575e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105762:	8b 45 08             	mov    0x8(%ebp),%eax
f0105765:	89 04 24             	mov    %eax,(%esp)
f0105768:	e8 79 ff ff ff       	call   f01056e6 <memmove>
}
f010576d:	c9                   	leave  
f010576e:	c3                   	ret    

f010576f <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f010576f:	55                   	push   %ebp
f0105770:	89 e5                	mov    %esp,%ebp
f0105772:	57                   	push   %edi
f0105773:	56                   	push   %esi
f0105774:	53                   	push   %ebx
f0105775:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105778:	8b 75 0c             	mov    0xc(%ebp),%esi
f010577b:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f010577e:	8d 78 ff             	lea    -0x1(%eax),%edi
f0105781:	85 c0                	test   %eax,%eax
f0105783:	74 36                	je     f01057bb <memcmp+0x4c>
		if (*s1 != *s2)
f0105785:	0f b6 03             	movzbl (%ebx),%eax
f0105788:	0f b6 0e             	movzbl (%esi),%ecx
f010578b:	ba 00 00 00 00       	mov    $0x0,%edx
f0105790:	38 c8                	cmp    %cl,%al
f0105792:	74 1c                	je     f01057b0 <memcmp+0x41>
f0105794:	eb 10                	jmp    f01057a6 <memcmp+0x37>
f0105796:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f010579b:	83 c2 01             	add    $0x1,%edx
f010579e:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f01057a2:	38 c8                	cmp    %cl,%al
f01057a4:	74 0a                	je     f01057b0 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f01057a6:	0f b6 c0             	movzbl %al,%eax
f01057a9:	0f b6 c9             	movzbl %cl,%ecx
f01057ac:	29 c8                	sub    %ecx,%eax
f01057ae:	eb 10                	jmp    f01057c0 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01057b0:	39 fa                	cmp    %edi,%edx
f01057b2:	75 e2                	jne    f0105796 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f01057b4:	b8 00 00 00 00       	mov    $0x0,%eax
f01057b9:	eb 05                	jmp    f01057c0 <memcmp+0x51>
f01057bb:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01057c0:	5b                   	pop    %ebx
f01057c1:	5e                   	pop    %esi
f01057c2:	5f                   	pop    %edi
f01057c3:	5d                   	pop    %ebp
f01057c4:	c3                   	ret    

f01057c5 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f01057c5:	55                   	push   %ebp
f01057c6:	89 e5                	mov    %esp,%ebp
f01057c8:	53                   	push   %ebx
f01057c9:	8b 45 08             	mov    0x8(%ebp),%eax
f01057cc:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f01057cf:	89 c2                	mov    %eax,%edx
f01057d1:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f01057d4:	39 d0                	cmp    %edx,%eax
f01057d6:	73 13                	jae    f01057eb <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f01057d8:	89 d9                	mov    %ebx,%ecx
f01057da:	38 18                	cmp    %bl,(%eax)
f01057dc:	75 06                	jne    f01057e4 <memfind+0x1f>
f01057de:	eb 0b                	jmp    f01057eb <memfind+0x26>
f01057e0:	38 08                	cmp    %cl,(%eax)
f01057e2:	74 07                	je     f01057eb <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f01057e4:	83 c0 01             	add    $0x1,%eax
f01057e7:	39 d0                	cmp    %edx,%eax
f01057e9:	75 f5                	jne    f01057e0 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f01057eb:	5b                   	pop    %ebx
f01057ec:	5d                   	pop    %ebp
f01057ed:	c3                   	ret    

f01057ee <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f01057ee:	55                   	push   %ebp
f01057ef:	89 e5                	mov    %esp,%ebp
f01057f1:	57                   	push   %edi
f01057f2:	56                   	push   %esi
f01057f3:	53                   	push   %ebx
f01057f4:	8b 55 08             	mov    0x8(%ebp),%edx
f01057f7:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f01057fa:	0f b6 0a             	movzbl (%edx),%ecx
f01057fd:	80 f9 09             	cmp    $0x9,%cl
f0105800:	74 05                	je     f0105807 <strtol+0x19>
f0105802:	80 f9 20             	cmp    $0x20,%cl
f0105805:	75 10                	jne    f0105817 <strtol+0x29>
		s++;
f0105807:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010580a:	0f b6 0a             	movzbl (%edx),%ecx
f010580d:	80 f9 09             	cmp    $0x9,%cl
f0105810:	74 f5                	je     f0105807 <strtol+0x19>
f0105812:	80 f9 20             	cmp    $0x20,%cl
f0105815:	74 f0                	je     f0105807 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f0105817:	80 f9 2b             	cmp    $0x2b,%cl
f010581a:	75 0a                	jne    f0105826 <strtol+0x38>
		s++;
f010581c:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f010581f:	bf 00 00 00 00       	mov    $0x0,%edi
f0105824:	eb 11                	jmp    f0105837 <strtol+0x49>
f0105826:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f010582b:	80 f9 2d             	cmp    $0x2d,%cl
f010582e:	75 07                	jne    f0105837 <strtol+0x49>
		s++, neg = 1;
f0105830:	83 c2 01             	add    $0x1,%edx
f0105833:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0105837:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f010583c:	75 15                	jne    f0105853 <strtol+0x65>
f010583e:	80 3a 30             	cmpb   $0x30,(%edx)
f0105841:	75 10                	jne    f0105853 <strtol+0x65>
f0105843:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0105847:	75 0a                	jne    f0105853 <strtol+0x65>
		s += 2, base = 16;
f0105849:	83 c2 02             	add    $0x2,%edx
f010584c:	b8 10 00 00 00       	mov    $0x10,%eax
f0105851:	eb 10                	jmp    f0105863 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f0105853:	85 c0                	test   %eax,%eax
f0105855:	75 0c                	jne    f0105863 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0105857:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0105859:	80 3a 30             	cmpb   $0x30,(%edx)
f010585c:	75 05                	jne    f0105863 <strtol+0x75>
		s++, base = 8;
f010585e:	83 c2 01             	add    $0x1,%edx
f0105861:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f0105863:	bb 00 00 00 00       	mov    $0x0,%ebx
f0105868:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f010586b:	0f b6 0a             	movzbl (%edx),%ecx
f010586e:	8d 71 d0             	lea    -0x30(%ecx),%esi
f0105871:	89 f0                	mov    %esi,%eax
f0105873:	3c 09                	cmp    $0x9,%al
f0105875:	77 08                	ja     f010587f <strtol+0x91>
			dig = *s - '0';
f0105877:	0f be c9             	movsbl %cl,%ecx
f010587a:	83 e9 30             	sub    $0x30,%ecx
f010587d:	eb 20                	jmp    f010589f <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f010587f:	8d 71 9f             	lea    -0x61(%ecx),%esi
f0105882:	89 f0                	mov    %esi,%eax
f0105884:	3c 19                	cmp    $0x19,%al
f0105886:	77 08                	ja     f0105890 <strtol+0xa2>
			dig = *s - 'a' + 10;
f0105888:	0f be c9             	movsbl %cl,%ecx
f010588b:	83 e9 57             	sub    $0x57,%ecx
f010588e:	eb 0f                	jmp    f010589f <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f0105890:	8d 71 bf             	lea    -0x41(%ecx),%esi
f0105893:	89 f0                	mov    %esi,%eax
f0105895:	3c 19                	cmp    $0x19,%al
f0105897:	77 16                	ja     f01058af <strtol+0xc1>
			dig = *s - 'A' + 10;
f0105899:	0f be c9             	movsbl %cl,%ecx
f010589c:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f010589f:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f01058a2:	7d 0f                	jge    f01058b3 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f01058a4:	83 c2 01             	add    $0x1,%edx
f01058a7:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f01058ab:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f01058ad:	eb bc                	jmp    f010586b <strtol+0x7d>
f01058af:	89 d8                	mov    %ebx,%eax
f01058b1:	eb 02                	jmp    f01058b5 <strtol+0xc7>
f01058b3:	89 d8                	mov    %ebx,%eax

	if (endptr)
f01058b5:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f01058b9:	74 05                	je     f01058c0 <strtol+0xd2>
		*endptr = (char *) s;
f01058bb:	8b 75 0c             	mov    0xc(%ebp),%esi
f01058be:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f01058c0:	f7 d8                	neg    %eax
f01058c2:	85 ff                	test   %edi,%edi
f01058c4:	0f 44 c3             	cmove  %ebx,%eax
}
f01058c7:	5b                   	pop    %ebx
f01058c8:	5e                   	pop    %esi
f01058c9:	5f                   	pop    %edi
f01058ca:	5d                   	pop    %ebp
f01058cb:	c3                   	ret    

f01058cc <mpentry_start>:
.set PROT_MODE_DSEG, 0x10	# kernel data segment selector

.code16           
.globl mpentry_start
mpentry_start:
	cli            
f01058cc:	fa                   	cli    

	xorw    %ax, %ax
f01058cd:	31 c0                	xor    %eax,%eax
	movw    %ax, %ds
f01058cf:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f01058d1:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f01058d3:	8e d0                	mov    %eax,%ss

	lgdt    MPBOOTPHYS(gdtdesc)
f01058d5:	0f 01 16             	lgdtl  (%esi)
f01058d8:	74 70                	je     f010594a <mpentry_end+0x4>
	movl    %cr0, %eax
f01058da:	0f 20 c0             	mov    %cr0,%eax
	orl     $CR0_PE, %eax
f01058dd:	66 83 c8 01          	or     $0x1,%ax
	movl    %eax, %cr0
f01058e1:	0f 22 c0             	mov    %eax,%cr0

	ljmpl   $(PROT_MODE_CSEG), $(MPBOOTPHYS(start32))
f01058e4:	66 ea 20 70 00 00    	ljmpw  $0x0,$0x7020
f01058ea:	08 00                	or     %al,(%eax)

f01058ec <start32>:

.code32
start32:
	movw    $(PROT_MODE_DSEG), %ax
f01058ec:	66 b8 10 00          	mov    $0x10,%ax
	movw    %ax, %ds
f01058f0:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f01058f2:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f01058f4:	8e d0                	mov    %eax,%ss
	movw    $0, %ax
f01058f6:	66 b8 00 00          	mov    $0x0,%ax
	movw    %ax, %fs
f01058fa:	8e e0                	mov    %eax,%fs
	movw    %ax, %gs
f01058fc:	8e e8                	mov    %eax,%gs

	# Set up initial page table. We cannot use kern_pgdir yet because
	# we are still running at a low EIP.
	movl    $(RELOC(entry_pgdir)), %eax
f01058fe:	b8 00 e0 11 00       	mov    $0x11e000,%eax
	movl    %eax, %cr3
f0105903:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl    %cr0, %eax
f0105906:	0f 20 c0             	mov    %cr0,%eax
	orl     $(CR0_PE|CR0_PG|CR0_WP), %eax
f0105909:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl    %eax, %cr0
f010590e:	0f 22 c0             	mov    %eax,%cr0

	# Switch to the per-cpu stack allocated in mem_init()
	movl    mpentry_kstack, %esp
f0105911:	8b 25 84 3e 22 f0    	mov    0xf0223e84,%esp
	movl    $0x0, %ebp       # nuke frame pointer
f0105917:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Call mp_main().  (Exercise for the reader: why the indirect call?)
	movl    $mp_main, %eax
f010591c:	b8 29 02 10 f0       	mov    $0xf0100229,%eax
	call    *%eax
f0105921:	ff d0                	call   *%eax

f0105923 <spin>:

	# If mp_main returns (it shouldn't), loop.
spin:
	jmp     spin
f0105923:	eb fe                	jmp    f0105923 <spin>
f0105925:	8d 76 00             	lea    0x0(%esi),%esi

f0105928 <gdt>:
	...
f0105930:	ff                   	(bad)  
f0105931:	ff 00                	incl   (%eax)
f0105933:	00 00                	add    %al,(%eax)
f0105935:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
f010593c:	00 92 cf 00 17 00    	add    %dl,0x1700cf(%edx)

f0105940 <gdtdesc>:
f0105940:	17                   	pop    %ss
f0105941:	00 5c 70 00          	add    %bl,0x0(%eax,%esi,2)
	...

f0105946 <mpentry_end>:
	.word   0x17				# sizeof(gdt) - 1
	.long   MPBOOTPHYS(gdt)			# address gdt

.globl mpentry_end
mpentry_end:
	nop
f0105946:	90                   	nop
f0105947:	66 90                	xchg   %ax,%ax
f0105949:	66 90                	xchg   %ax,%ax
f010594b:	66 90                	xchg   %ax,%ax
f010594d:	66 90                	xchg   %ax,%ax
f010594f:	90                   	nop

f0105950 <mpsearch1>:
}

// Look for an MP structure in the len bytes at physical address addr.
static struct mp *
mpsearch1(physaddr_t a, int len)
{
f0105950:	55                   	push   %ebp
f0105951:	89 e5                	mov    %esp,%ebp
f0105953:	56                   	push   %esi
f0105954:	53                   	push   %ebx
f0105955:	83 ec 10             	sub    $0x10,%esp
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105958:	8b 0d 88 3e 22 f0    	mov    0xf0223e88,%ecx
f010595e:	89 c3                	mov    %eax,%ebx
f0105960:	c1 eb 0c             	shr    $0xc,%ebx
f0105963:	39 cb                	cmp    %ecx,%ebx
f0105965:	72 20                	jb     f0105987 <mpsearch1+0x37>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105967:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010596b:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f0105972:	f0 
f0105973:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f010597a:	00 
f010597b:	c7 04 24 a1 7d 10 f0 	movl   $0xf0107da1,(%esp)
f0105982:	e8 b9 a6 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0105987:	8d 98 00 00 00 f0    	lea    -0x10000000(%eax),%ebx
	struct mp *mp = KADDR(a), *end = KADDR(a + len);
f010598d:	01 d0                	add    %edx,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010598f:	89 c2                	mov    %eax,%edx
f0105991:	c1 ea 0c             	shr    $0xc,%edx
f0105994:	39 d1                	cmp    %edx,%ecx
f0105996:	77 20                	ja     f01059b8 <mpsearch1+0x68>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105998:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010599c:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f01059a3:	f0 
f01059a4:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f01059ab:	00 
f01059ac:	c7 04 24 a1 7d 10 f0 	movl   $0xf0107da1,(%esp)
f01059b3:	e8 88 a6 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01059b8:	8d b0 00 00 00 f0    	lea    -0x10000000(%eax),%esi

	for (; mp < end; mp++)
f01059be:	39 f3                	cmp    %esi,%ebx
f01059c0:	73 40                	jae    f0105a02 <mpsearch1+0xb2>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f01059c2:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f01059c9:	00 
f01059ca:	c7 44 24 04 b1 7d 10 	movl   $0xf0107db1,0x4(%esp)
f01059d1:	f0 
f01059d2:	89 1c 24             	mov    %ebx,(%esp)
f01059d5:	e8 95 fd ff ff       	call   f010576f <memcmp>
f01059da:	85 c0                	test   %eax,%eax
f01059dc:	75 17                	jne    f01059f5 <mpsearch1+0xa5>
f01059de:	ba 00 00 00 00       	mov    $0x0,%edx
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
		sum += ((uint8_t *)addr)[i];
f01059e3:	0f b6 0c 03          	movzbl (%ebx,%eax,1),%ecx
f01059e7:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f01059e9:	83 c0 01             	add    $0x1,%eax
f01059ec:	83 f8 10             	cmp    $0x10,%eax
f01059ef:	75 f2                	jne    f01059e3 <mpsearch1+0x93>
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f01059f1:	84 d2                	test   %dl,%dl
f01059f3:	74 14                	je     f0105a09 <mpsearch1+0xb9>
static struct mp *
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
f01059f5:	83 c3 10             	add    $0x10,%ebx
f01059f8:	39 f3                	cmp    %esi,%ebx
f01059fa:	72 c6                	jb     f01059c2 <mpsearch1+0x72>
f01059fc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0105a00:	eb 0b                	jmp    f0105a0d <mpsearch1+0xbd>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
		    sum(mp, sizeof(*mp)) == 0)
			return mp;
	return NULL;
f0105a02:	b8 00 00 00 00       	mov    $0x0,%eax
f0105a07:	eb 09                	jmp    f0105a12 <mpsearch1+0xc2>
f0105a09:	89 d8                	mov    %ebx,%eax
f0105a0b:	eb 05                	jmp    f0105a12 <mpsearch1+0xc2>
f0105a0d:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105a12:	83 c4 10             	add    $0x10,%esp
f0105a15:	5b                   	pop    %ebx
f0105a16:	5e                   	pop    %esi
f0105a17:	5d                   	pop    %ebp
f0105a18:	c3                   	ret    

f0105a19 <mp_init>:
	return conf;
}

void
mp_init(void)
{
f0105a19:	55                   	push   %ebp
f0105a1a:	89 e5                	mov    %esp,%ebp
f0105a1c:	57                   	push   %edi
f0105a1d:	56                   	push   %esi
f0105a1e:	53                   	push   %ebx
f0105a1f:	83 ec 2c             	sub    $0x2c,%esp
	struct mpconf *conf;
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
f0105a22:	c7 05 c0 43 22 f0 20 	movl   $0xf0224020,0xf02243c0
f0105a29:	40 22 f0 
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105a2c:	83 3d 88 3e 22 f0 00 	cmpl   $0x0,0xf0223e88
f0105a33:	75 24                	jne    f0105a59 <mp_init+0x40>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105a35:	c7 44 24 0c 00 04 00 	movl   $0x400,0xc(%esp)
f0105a3c:	00 
f0105a3d:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f0105a44:	f0 
f0105a45:	c7 44 24 04 6f 00 00 	movl   $0x6f,0x4(%esp)
f0105a4c:	00 
f0105a4d:	c7 04 24 a1 7d 10 f0 	movl   $0xf0107da1,(%esp)
f0105a54:	e8 e7 a5 ff ff       	call   f0100040 <_panic>
	// The BIOS data area lives in 16-bit segment 0x40.
	bda = (uint8_t *) KADDR(0x40 << 4);

	// [MP 4] The 16-bit segment of the EBDA is in the two bytes
	// starting at byte 0x0E of the BDA.  0 if not present.
	if ((p = *(uint16_t *) (bda + 0x0E))) {
f0105a59:	0f b7 05 0e 04 00 f0 	movzwl 0xf000040e,%eax
f0105a60:	85 c0                	test   %eax,%eax
f0105a62:	74 16                	je     f0105a7a <mp_init+0x61>
		p <<= 4;	// Translate from segment to PA
f0105a64:	c1 e0 04             	shl    $0x4,%eax
		if ((mp = mpsearch1(p, 1024)))
f0105a67:	ba 00 04 00 00       	mov    $0x400,%edx
f0105a6c:	e8 df fe ff ff       	call   f0105950 <mpsearch1>
f0105a71:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0105a74:	85 c0                	test   %eax,%eax
f0105a76:	75 3c                	jne    f0105ab4 <mp_init+0x9b>
f0105a78:	eb 20                	jmp    f0105a9a <mp_init+0x81>
			return mp;
	} else {
		// The size of base memory, in KB is in the two bytes
		// starting at 0x13 of the BDA.
		p = *(uint16_t *) (bda + 0x13) * 1024;
f0105a7a:	0f b7 05 13 04 00 f0 	movzwl 0xf0000413,%eax
f0105a81:	c1 e0 0a             	shl    $0xa,%eax
		if ((mp = mpsearch1(p - 1024, 1024)))
f0105a84:	2d 00 04 00 00       	sub    $0x400,%eax
f0105a89:	ba 00 04 00 00       	mov    $0x400,%edx
f0105a8e:	e8 bd fe ff ff       	call   f0105950 <mpsearch1>
f0105a93:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0105a96:	85 c0                	test   %eax,%eax
f0105a98:	75 1a                	jne    f0105ab4 <mp_init+0x9b>
			return mp;
	}
	return mpsearch1(0xF0000, 0x10000);
f0105a9a:	ba 00 00 01 00       	mov    $0x10000,%edx
f0105a9f:	b8 00 00 0f 00       	mov    $0xf0000,%eax
f0105aa4:	e8 a7 fe ff ff       	call   f0105950 <mpsearch1>
f0105aa9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
mpconfig(struct mp **pmp)
{
	struct mpconf *conf;
	struct mp *mp;

	if ((mp = mpsearch()) == 0)
f0105aac:	85 c0                	test   %eax,%eax
f0105aae:	0f 84 5f 02 00 00    	je     f0105d13 <mp_init+0x2fa>
		return NULL;
	if (mp->physaddr == 0 || mp->type != 0) {
f0105ab4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105ab7:	8b 70 04             	mov    0x4(%eax),%esi
f0105aba:	85 f6                	test   %esi,%esi
f0105abc:	74 06                	je     f0105ac4 <mp_init+0xab>
f0105abe:	80 78 0b 00          	cmpb   $0x0,0xb(%eax)
f0105ac2:	74 11                	je     f0105ad5 <mp_init+0xbc>
		cprintf("SMP: Default configurations not implemented\n");
f0105ac4:	c7 04 24 14 7c 10 f0 	movl   $0xf0107c14,(%esp)
f0105acb:	e8 0e e4 ff ff       	call   f0103ede <cprintf>
f0105ad0:	e9 3e 02 00 00       	jmp    f0105d13 <mp_init+0x2fa>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105ad5:	89 f0                	mov    %esi,%eax
f0105ad7:	c1 e8 0c             	shr    $0xc,%eax
f0105ada:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0105ae0:	72 20                	jb     f0105b02 <mp_init+0xe9>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105ae2:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105ae6:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f0105aed:	f0 
f0105aee:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f0105af5:	00 
f0105af6:	c7 04 24 a1 7d 10 f0 	movl   $0xf0107da1,(%esp)
f0105afd:	e8 3e a5 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0105b02:	8d 9e 00 00 00 f0    	lea    -0x10000000(%esi),%ebx
		return NULL;
	}
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
f0105b08:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0105b0f:	00 
f0105b10:	c7 44 24 04 b6 7d 10 	movl   $0xf0107db6,0x4(%esp)
f0105b17:	f0 
f0105b18:	89 1c 24             	mov    %ebx,(%esp)
f0105b1b:	e8 4f fc ff ff       	call   f010576f <memcmp>
f0105b20:	85 c0                	test   %eax,%eax
f0105b22:	74 11                	je     f0105b35 <mp_init+0x11c>
		cprintf("SMP: Incorrect MP configuration table signature\n");
f0105b24:	c7 04 24 44 7c 10 f0 	movl   $0xf0107c44,(%esp)
f0105b2b:	e8 ae e3 ff ff       	call   f0103ede <cprintf>
f0105b30:	e9 de 01 00 00       	jmp    f0105d13 <mp_init+0x2fa>
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0105b35:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0105b39:	66 89 45 e2          	mov    %ax,-0x1e(%ebp)
f0105b3d:	0f b7 f8             	movzwl %ax,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105b40:	85 ff                	test   %edi,%edi
f0105b42:	7e 30                	jle    f0105b74 <mp_init+0x15b>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105b44:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0105b49:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0105b4e:	0f b6 8c 30 00 00 00 	movzbl -0x10000000(%eax,%esi,1),%ecx
f0105b55:	f0 
f0105b56:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105b58:	83 c0 01             	add    $0x1,%eax
f0105b5b:	39 c7                	cmp    %eax,%edi
f0105b5d:	7f ef                	jg     f0105b4e <mp_init+0x135>
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
		cprintf("SMP: Incorrect MP configuration table signature\n");
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0105b5f:	84 d2                	test   %dl,%dl
f0105b61:	74 11                	je     f0105b74 <mp_init+0x15b>
		cprintf("SMP: Bad MP configuration checksum\n");
f0105b63:	c7 04 24 78 7c 10 f0 	movl   $0xf0107c78,(%esp)
f0105b6a:	e8 6f e3 ff ff       	call   f0103ede <cprintf>
f0105b6f:	e9 9f 01 00 00       	jmp    f0105d13 <mp_init+0x2fa>
		return NULL;
	}
	if (conf->version != 1 && conf->version != 4) {
f0105b74:	0f b6 43 06          	movzbl 0x6(%ebx),%eax
f0105b78:	3c 04                	cmp    $0x4,%al
f0105b7a:	74 1e                	je     f0105b9a <mp_init+0x181>
f0105b7c:	3c 01                	cmp    $0x1,%al
f0105b7e:	66 90                	xchg   %ax,%ax
f0105b80:	74 18                	je     f0105b9a <mp_init+0x181>
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
f0105b82:	0f b6 c0             	movzbl %al,%eax
f0105b85:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105b89:	c7 04 24 9c 7c 10 f0 	movl   $0xf0107c9c,(%esp)
f0105b90:	e8 49 e3 ff ff       	call   f0103ede <cprintf>
f0105b95:	e9 79 01 00 00       	jmp    f0105d13 <mp_init+0x2fa>
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0105b9a:	0f b7 73 28          	movzwl 0x28(%ebx),%esi
f0105b9e:	0f b7 7d e2          	movzwl -0x1e(%ebp),%edi
f0105ba2:	01 df                	add    %ebx,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105ba4:	85 f6                	test   %esi,%esi
f0105ba6:	7e 19                	jle    f0105bc1 <mp_init+0x1a8>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105ba8:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0105bad:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0105bb2:	0f b6 0c 07          	movzbl (%edi,%eax,1),%ecx
f0105bb6:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105bb8:	83 c0 01             	add    $0x1,%eax
f0105bbb:	39 c6                	cmp    %eax,%esi
f0105bbd:	7f f3                	jg     f0105bb2 <mp_init+0x199>
f0105bbf:	eb 05                	jmp    f0105bc6 <mp_init+0x1ad>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105bc1:	ba 00 00 00 00       	mov    $0x0,%edx
	}
	if (conf->version != 1 && conf->version != 4) {
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0105bc6:	38 53 2a             	cmp    %dl,0x2a(%ebx)
f0105bc9:	74 11                	je     f0105bdc <mp_init+0x1c3>
		cprintf("SMP: Bad MP configuration extended checksum\n");
f0105bcb:	c7 04 24 bc 7c 10 f0 	movl   $0xf0107cbc,(%esp)
f0105bd2:	e8 07 e3 ff ff       	call   f0103ede <cprintf>
f0105bd7:	e9 37 01 00 00       	jmp    f0105d13 <mp_init+0x2fa>
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
	if ((conf = mpconfig(&mp)) == 0)
f0105bdc:	85 db                	test   %ebx,%ebx
f0105bde:	0f 84 2f 01 00 00    	je     f0105d13 <mp_init+0x2fa>
		return;
	ismp = 1;
f0105be4:	c7 05 00 40 22 f0 01 	movl   $0x1,0xf0224000
f0105beb:	00 00 00 
	lapic = (uint32_t *)conf->lapicaddr;
f0105bee:	8b 43 24             	mov    0x24(%ebx),%eax
f0105bf1:	a3 00 50 26 f0       	mov    %eax,0xf0265000

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0105bf6:	8d 7b 2c             	lea    0x2c(%ebx),%edi
f0105bf9:	66 83 7b 22 00       	cmpw   $0x0,0x22(%ebx)
f0105bfe:	0f 84 94 00 00 00    	je     f0105c98 <mp_init+0x27f>
f0105c04:	be 00 00 00 00       	mov    $0x0,%esi
		switch (*p) {
f0105c09:	0f b6 07             	movzbl (%edi),%eax
f0105c0c:	84 c0                	test   %al,%al
f0105c0e:	74 06                	je     f0105c16 <mp_init+0x1fd>
f0105c10:	3c 04                	cmp    $0x4,%al
f0105c12:	77 54                	ja     f0105c68 <mp_init+0x24f>
f0105c14:	eb 4d                	jmp    f0105c63 <mp_init+0x24a>
		case MPPROC:
			proc = (struct mpproc *)p;
			if (proc->flags & MPPROC_BOOT)
f0105c16:	f6 47 03 02          	testb  $0x2,0x3(%edi)
f0105c1a:	74 11                	je     f0105c2d <mp_init+0x214>
				bootcpu = &cpus[ncpu];
f0105c1c:	6b 05 c4 43 22 f0 74 	imul   $0x74,0xf02243c4,%eax
f0105c23:	05 20 40 22 f0       	add    $0xf0224020,%eax
f0105c28:	a3 c0 43 22 f0       	mov    %eax,0xf02243c0
			if (ncpu < NCPU) {
f0105c2d:	a1 c4 43 22 f0       	mov    0xf02243c4,%eax
f0105c32:	83 f8 07             	cmp    $0x7,%eax
f0105c35:	7f 13                	jg     f0105c4a <mp_init+0x231>
				cpus[ncpu].cpu_id = ncpu;
f0105c37:	6b d0 74             	imul   $0x74,%eax,%edx
f0105c3a:	88 82 20 40 22 f0    	mov    %al,-0xfddbfe0(%edx)
				ncpu++;
f0105c40:	83 c0 01             	add    $0x1,%eax
f0105c43:	a3 c4 43 22 f0       	mov    %eax,0xf02243c4
f0105c48:	eb 14                	jmp    f0105c5e <mp_init+0x245>
			} else {
				cprintf("SMP: too many CPUs, CPU %d disabled\n",
f0105c4a:	0f b6 47 01          	movzbl 0x1(%edi),%eax
f0105c4e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105c52:	c7 04 24 ec 7c 10 f0 	movl   $0xf0107cec,(%esp)
f0105c59:	e8 80 e2 ff ff       	call   f0103ede <cprintf>
					proc->apicid);
			}
			p += sizeof(struct mpproc);
f0105c5e:	83 c7 14             	add    $0x14,%edi
			continue;
f0105c61:	eb 26                	jmp    f0105c89 <mp_init+0x270>
		case MPBUS:
		case MPIOAPIC:
		case MPIOINTR:
		case MPLINTR:
			p += 8;
f0105c63:	83 c7 08             	add    $0x8,%edi
			continue;
f0105c66:	eb 21                	jmp    f0105c89 <mp_init+0x270>
		default:
			cprintf("mpinit: unknown config type %x\n", *p);
f0105c68:	0f b6 c0             	movzbl %al,%eax
f0105c6b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105c6f:	c7 04 24 14 7d 10 f0 	movl   $0xf0107d14,(%esp)
f0105c76:	e8 63 e2 ff ff       	call   f0103ede <cprintf>
			ismp = 0;
f0105c7b:	c7 05 00 40 22 f0 00 	movl   $0x0,0xf0224000
f0105c82:	00 00 00 
			i = conf->entry;
f0105c85:	0f b7 73 22          	movzwl 0x22(%ebx),%esi
	if ((conf = mpconfig(&mp)) == 0)
		return;
	ismp = 1;
	lapic = (uint32_t *)conf->lapicaddr;

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0105c89:	83 c6 01             	add    $0x1,%esi
f0105c8c:	0f b7 43 22          	movzwl 0x22(%ebx),%eax
f0105c90:	39 f0                	cmp    %esi,%eax
f0105c92:	0f 87 71 ff ff ff    	ja     f0105c09 <mp_init+0x1f0>
			ismp = 0;
			i = conf->entry;
		}
	}

	bootcpu->cpu_status = CPU_STARTED;
f0105c98:	a1 c0 43 22 f0       	mov    0xf02243c0,%eax
f0105c9d:	c7 40 04 01 00 00 00 	movl   $0x1,0x4(%eax)
	if (!ismp) {
f0105ca4:	83 3d 00 40 22 f0 00 	cmpl   $0x0,0xf0224000
f0105cab:	75 22                	jne    f0105ccf <mp_init+0x2b6>
		// Didn't like what we found; fall back to no MP.
		ncpu = 1;
f0105cad:	c7 05 c4 43 22 f0 01 	movl   $0x1,0xf02243c4
f0105cb4:	00 00 00 
		lapic = NULL;
f0105cb7:	c7 05 00 50 26 f0 00 	movl   $0x0,0xf0265000
f0105cbe:	00 00 00 
		cprintf("SMP: configuration not found, SMP disabled\n");
f0105cc1:	c7 04 24 34 7d 10 f0 	movl   $0xf0107d34,(%esp)
f0105cc8:	e8 11 e2 ff ff       	call   f0103ede <cprintf>
		return;
f0105ccd:	eb 44                	jmp    f0105d13 <mp_init+0x2fa>
	}
	cprintf("SMP: CPU %d found %d CPU(s)\n", bootcpu->cpu_id,  ncpu);
f0105ccf:	8b 15 c4 43 22 f0    	mov    0xf02243c4,%edx
f0105cd5:	89 54 24 08          	mov    %edx,0x8(%esp)
f0105cd9:	0f b6 00             	movzbl (%eax),%eax
f0105cdc:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105ce0:	c7 04 24 bb 7d 10 f0 	movl   $0xf0107dbb,(%esp)
f0105ce7:	e8 f2 e1 ff ff       	call   f0103ede <cprintf>

	if (mp->imcrp) {
f0105cec:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105cef:	80 78 0c 00          	cmpb   $0x0,0xc(%eax)
f0105cf3:	74 1e                	je     f0105d13 <mp_init+0x2fa>
		// [MP 3.2.6.1] If the hardware implements PIC mode,
		// switch to getting interrupts from the LAPIC.
		cprintf("SMP: Setting IMCR to switch from PIC mode to symmetric I/O mode\n");
f0105cf5:	c7 04 24 60 7d 10 f0 	movl   $0xf0107d60,(%esp)
f0105cfc:	e8 dd e1 ff ff       	call   f0103ede <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0105d01:	ba 22 00 00 00       	mov    $0x22,%edx
f0105d06:	b8 70 00 00 00       	mov    $0x70,%eax
f0105d0b:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0105d0c:	b2 23                	mov    $0x23,%dl
f0105d0e:	ec                   	in     (%dx),%al
		outb(0x22, 0x70);   // Select IMCR
		outb(0x23, inb(0x23) | 1);  // Mask external interrupts.
f0105d0f:	83 c8 01             	or     $0x1,%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0105d12:	ee                   	out    %al,(%dx)
	}
}
f0105d13:	83 c4 2c             	add    $0x2c,%esp
f0105d16:	5b                   	pop    %ebx
f0105d17:	5e                   	pop    %esi
f0105d18:	5f                   	pop    %edi
f0105d19:	5d                   	pop    %ebp
f0105d1a:	c3                   	ret    

f0105d1b <lapicw>:

volatile uint32_t *lapic;  // Initialized in mp.c

static void
lapicw(int index, int value)
{
f0105d1b:	55                   	push   %ebp
f0105d1c:	89 e5                	mov    %esp,%ebp
	lapic[index] = value;
f0105d1e:	8b 0d 00 50 26 f0    	mov    0xf0265000,%ecx
f0105d24:	8d 04 81             	lea    (%ecx,%eax,4),%eax
f0105d27:	89 10                	mov    %edx,(%eax)
	lapic[ID];  // wait for write to finish, by reading
f0105d29:	a1 00 50 26 f0       	mov    0xf0265000,%eax
f0105d2e:	8b 40 20             	mov    0x20(%eax),%eax
}
f0105d31:	5d                   	pop    %ebp
f0105d32:	c3                   	ret    

f0105d33 <cpunum>:
	lapicw(TPR, 0);
}

int
cpunum(void)
{
f0105d33:	55                   	push   %ebp
f0105d34:	89 e5                	mov    %esp,%ebp
	if (lapic)
f0105d36:	a1 00 50 26 f0       	mov    0xf0265000,%eax
f0105d3b:	85 c0                	test   %eax,%eax
f0105d3d:	74 08                	je     f0105d47 <cpunum+0x14>
		return lapic[ID] >> 24;
f0105d3f:	8b 40 20             	mov    0x20(%eax),%eax
f0105d42:	c1 e8 18             	shr    $0x18,%eax
f0105d45:	eb 05                	jmp    f0105d4c <cpunum+0x19>
	return 0;
f0105d47:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105d4c:	5d                   	pop    %ebp
f0105d4d:	c3                   	ret    

f0105d4e <lapic_init>:
}

void
lapic_init(void)
{
	if (!lapic) 
f0105d4e:	83 3d 00 50 26 f0 00 	cmpl   $0x0,0xf0265000
f0105d55:	0f 84 0b 01 00 00    	je     f0105e66 <lapic_init+0x118>
	lapic[ID];  // wait for write to finish, by reading
}

void
lapic_init(void)
{
f0105d5b:	55                   	push   %ebp
f0105d5c:	89 e5                	mov    %esp,%ebp
	if (!lapic) 
		return;

	// Enable local APIC; set spurious interrupt vector.
	lapicw(SVR, ENABLE | (IRQ_OFFSET + IRQ_SPURIOUS));
f0105d5e:	ba 27 01 00 00       	mov    $0x127,%edx
f0105d63:	b8 3c 00 00 00       	mov    $0x3c,%eax
f0105d68:	e8 ae ff ff ff       	call   f0105d1b <lapicw>

	// The timer repeatedly counts down at bus frequency
	// from lapic[TICR] and then issues an interrupt.  
	// If we cared more about precise timekeeping,
	// TICR would be calibrated using an external time source.
	lapicw(TDCR, X1);
f0105d6d:	ba 0b 00 00 00       	mov    $0xb,%edx
f0105d72:	b8 f8 00 00 00       	mov    $0xf8,%eax
f0105d77:	e8 9f ff ff ff       	call   f0105d1b <lapicw>
	lapicw(TIMER, PERIODIC | (IRQ_OFFSET + IRQ_TIMER));
f0105d7c:	ba 20 00 02 00       	mov    $0x20020,%edx
f0105d81:	b8 c8 00 00 00       	mov    $0xc8,%eax
f0105d86:	e8 90 ff ff ff       	call   f0105d1b <lapicw>
	lapicw(TICR, 10000000); 
f0105d8b:	ba 80 96 98 00       	mov    $0x989680,%edx
f0105d90:	b8 e0 00 00 00       	mov    $0xe0,%eax
f0105d95:	e8 81 ff ff ff       	call   f0105d1b <lapicw>
	//
	// According to Intel MP Specification, the BIOS should initialize
	// BSP's local APIC in Virtual Wire Mode, in which 8259A's
	// INTR is virtually connected to BSP's LINTIN0. In this mode,
	// we do not need to program the IOAPIC.
	if (thiscpu != bootcpu)
f0105d9a:	e8 94 ff ff ff       	call   f0105d33 <cpunum>
f0105d9f:	6b c0 74             	imul   $0x74,%eax,%eax
f0105da2:	05 20 40 22 f0       	add    $0xf0224020,%eax
f0105da7:	39 05 c0 43 22 f0    	cmp    %eax,0xf02243c0
f0105dad:	74 0f                	je     f0105dbe <lapic_init+0x70>
		lapicw(LINT0, MASKED);
f0105daf:	ba 00 00 01 00       	mov    $0x10000,%edx
f0105db4:	b8 d4 00 00 00       	mov    $0xd4,%eax
f0105db9:	e8 5d ff ff ff       	call   f0105d1b <lapicw>

	// Disable NMI (LINT1) on all CPUs
	lapicw(LINT1, MASKED);
f0105dbe:	ba 00 00 01 00       	mov    $0x10000,%edx
f0105dc3:	b8 d8 00 00 00       	mov    $0xd8,%eax
f0105dc8:	e8 4e ff ff ff       	call   f0105d1b <lapicw>

	// Disable performance counter overflow interrupts
	// on machines that provide that interrupt entry.
	if (((lapic[VER]>>16) & 0xFF) >= 4)
f0105dcd:	a1 00 50 26 f0       	mov    0xf0265000,%eax
f0105dd2:	8b 40 30             	mov    0x30(%eax),%eax
f0105dd5:	c1 e8 10             	shr    $0x10,%eax
f0105dd8:	3c 03                	cmp    $0x3,%al
f0105dda:	76 0f                	jbe    f0105deb <lapic_init+0x9d>
		lapicw(PCINT, MASKED);
f0105ddc:	ba 00 00 01 00       	mov    $0x10000,%edx
f0105de1:	b8 d0 00 00 00       	mov    $0xd0,%eax
f0105de6:	e8 30 ff ff ff       	call   f0105d1b <lapicw>

	// Map error interrupt to IRQ_ERROR.
	lapicw(ERROR, IRQ_OFFSET + IRQ_ERROR);
f0105deb:	ba 33 00 00 00       	mov    $0x33,%edx
f0105df0:	b8 dc 00 00 00       	mov    $0xdc,%eax
f0105df5:	e8 21 ff ff ff       	call   f0105d1b <lapicw>

	// Clear error status register (requires back-to-back writes).
	lapicw(ESR, 0);
f0105dfa:	ba 00 00 00 00       	mov    $0x0,%edx
f0105dff:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0105e04:	e8 12 ff ff ff       	call   f0105d1b <lapicw>
	lapicw(ESR, 0);
f0105e09:	ba 00 00 00 00       	mov    $0x0,%edx
f0105e0e:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0105e13:	e8 03 ff ff ff       	call   f0105d1b <lapicw>

	// Ack any outstanding interrupts.
	lapicw(EOI, 0);
f0105e18:	ba 00 00 00 00       	mov    $0x0,%edx
f0105e1d:	b8 2c 00 00 00       	mov    $0x2c,%eax
f0105e22:	e8 f4 fe ff ff       	call   f0105d1b <lapicw>

	// Send an Init Level De-Assert to synchronize arbitration ID's.
	lapicw(ICRHI, 0);
f0105e27:	ba 00 00 00 00       	mov    $0x0,%edx
f0105e2c:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0105e31:	e8 e5 fe ff ff       	call   f0105d1b <lapicw>
	lapicw(ICRLO, BCAST | INIT | LEVEL);
f0105e36:	ba 00 85 08 00       	mov    $0x88500,%edx
f0105e3b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0105e40:	e8 d6 fe ff ff       	call   f0105d1b <lapicw>
	while(lapic[ICRLO] & DELIVS)
f0105e45:	8b 15 00 50 26 f0    	mov    0xf0265000,%edx
f0105e4b:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f0105e51:	f6 c4 10             	test   $0x10,%ah
f0105e54:	75 f5                	jne    f0105e4b <lapic_init+0xfd>
		;

	// Enable interrupts on the APIC (but not on the processor).
	lapicw(TPR, 0);
f0105e56:	ba 00 00 00 00       	mov    $0x0,%edx
f0105e5b:	b8 20 00 00 00       	mov    $0x20,%eax
f0105e60:	e8 b6 fe ff ff       	call   f0105d1b <lapicw>
}
f0105e65:	5d                   	pop    %ebp
f0105e66:	f3 c3                	repz ret 

f0105e68 <lapic_eoi>:

// Acknowledge interrupt.
void
lapic_eoi(void)
{
	if (lapic)
f0105e68:	83 3d 00 50 26 f0 00 	cmpl   $0x0,0xf0265000
f0105e6f:	74 13                	je     f0105e84 <lapic_eoi+0x1c>
}

// Acknowledge interrupt.
void
lapic_eoi(void)
{
f0105e71:	55                   	push   %ebp
f0105e72:	89 e5                	mov    %esp,%ebp
	if (lapic)
		lapicw(EOI, 0);
f0105e74:	ba 00 00 00 00       	mov    $0x0,%edx
f0105e79:	b8 2c 00 00 00       	mov    $0x2c,%eax
f0105e7e:	e8 98 fe ff ff       	call   f0105d1b <lapicw>
}
f0105e83:	5d                   	pop    %ebp
f0105e84:	f3 c3                	repz ret 

f0105e86 <lapic_startap>:

// Start additional processor running entry code at addr.
// See Appendix B of MultiProcessor Specification.
void
lapic_startap(uint8_t apicid, uint32_t addr)
{
f0105e86:	55                   	push   %ebp
f0105e87:	89 e5                	mov    %esp,%ebp
f0105e89:	56                   	push   %esi
f0105e8a:	53                   	push   %ebx
f0105e8b:	83 ec 10             	sub    $0x10,%esp
f0105e8e:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105e91:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105e94:	ba 70 00 00 00       	mov    $0x70,%edx
f0105e99:	b8 0f 00 00 00       	mov    $0xf,%eax
f0105e9e:	ee                   	out    %al,(%dx)
f0105e9f:	b2 71                	mov    $0x71,%dl
f0105ea1:	b8 0a 00 00 00       	mov    $0xa,%eax
f0105ea6:	ee                   	out    %al,(%dx)
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105ea7:	83 3d 88 3e 22 f0 00 	cmpl   $0x0,0xf0223e88
f0105eae:	75 24                	jne    f0105ed4 <lapic_startap+0x4e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105eb0:	c7 44 24 0c 67 04 00 	movl   $0x467,0xc(%esp)
f0105eb7:	00 
f0105eb8:	c7 44 24 08 64 64 10 	movl   $0xf0106464,0x8(%esp)
f0105ebf:	f0 
f0105ec0:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
f0105ec7:	00 
f0105ec8:	c7 04 24 d8 7d 10 f0 	movl   $0xf0107dd8,(%esp)
f0105ecf:	e8 6c a1 ff ff       	call   f0100040 <_panic>
	// and the warm reset vector (DWORD based at 40:67) to point at
	// the AP startup code prior to the [universal startup algorithm]."
	outb(IO_RTC, 0xF);  // offset 0xF is shutdown code
	outb(IO_RTC+1, 0x0A);
	wrv = (uint16_t *)KADDR((0x40 << 4 | 0x67));  // Warm reset vector
	wrv[0] = 0;
f0105ed4:	66 c7 05 67 04 00 f0 	movw   $0x0,0xf0000467
f0105edb:	00 00 
	wrv[1] = addr >> 4;
f0105edd:	89 f0                	mov    %esi,%eax
f0105edf:	c1 e8 04             	shr    $0x4,%eax
f0105ee2:	66 a3 69 04 00 f0    	mov    %ax,0xf0000469

	// "Universal startup algorithm."
	// Send INIT (level-triggered) interrupt to reset other CPU.
	lapicw(ICRHI, apicid << 24);
f0105ee8:	c1 e3 18             	shl    $0x18,%ebx
f0105eeb:	89 da                	mov    %ebx,%edx
f0105eed:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0105ef2:	e8 24 fe ff ff       	call   f0105d1b <lapicw>
	lapicw(ICRLO, INIT | LEVEL | ASSERT);
f0105ef7:	ba 00 c5 00 00       	mov    $0xc500,%edx
f0105efc:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0105f01:	e8 15 fe ff ff       	call   f0105d1b <lapicw>
	microdelay(200);
	lapicw(ICRLO, INIT | LEVEL);
f0105f06:	ba 00 85 00 00       	mov    $0x8500,%edx
f0105f0b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0105f10:	e8 06 fe ff ff       	call   f0105d1b <lapicw>
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0105f15:	c1 ee 0c             	shr    $0xc,%esi
f0105f18:	81 ce 00 06 00 00    	or     $0x600,%esi
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f0105f1e:	89 da                	mov    %ebx,%edx
f0105f20:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0105f25:	e8 f1 fd ff ff       	call   f0105d1b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0105f2a:	89 f2                	mov    %esi,%edx
f0105f2c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0105f31:	e8 e5 fd ff ff       	call   f0105d1b <lapicw>
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f0105f36:	89 da                	mov    %ebx,%edx
f0105f38:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0105f3d:	e8 d9 fd ff ff       	call   f0105d1b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0105f42:	89 f2                	mov    %esi,%edx
f0105f44:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0105f49:	e8 cd fd ff ff       	call   f0105d1b <lapicw>
		microdelay(200);
	}
}
f0105f4e:	83 c4 10             	add    $0x10,%esp
f0105f51:	5b                   	pop    %ebx
f0105f52:	5e                   	pop    %esi
f0105f53:	5d                   	pop    %ebp
f0105f54:	c3                   	ret    

f0105f55 <lapic_ipi>:

void
lapic_ipi(int vector)
{
f0105f55:	55                   	push   %ebp
f0105f56:	89 e5                	mov    %esp,%ebp
	lapicw(ICRLO, OTHERS | FIXED | vector);
f0105f58:	8b 55 08             	mov    0x8(%ebp),%edx
f0105f5b:	81 ca 00 00 0c 00    	or     $0xc0000,%edx
f0105f61:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0105f66:	e8 b0 fd ff ff       	call   f0105d1b <lapicw>
	while (lapic[ICRLO] & DELIVS)
f0105f6b:	8b 15 00 50 26 f0    	mov    0xf0265000,%edx
f0105f71:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f0105f77:	f6 c4 10             	test   $0x10,%ah
f0105f7a:	75 f5                	jne    f0105f71 <lapic_ipi+0x1c>
		;
}
f0105f7c:	5d                   	pop    %ebp
f0105f7d:	c3                   	ret    

f0105f7e <__spin_initlock>:
}
#endif

void
__spin_initlock(struct spinlock *lk, char *name)
{
f0105f7e:	55                   	push   %ebp
f0105f7f:	89 e5                	mov    %esp,%ebp
f0105f81:	8b 45 08             	mov    0x8(%ebp),%eax
	lk->locked = 0;
f0105f84:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
#ifdef DEBUG_SPINLOCK
	lk->name = name;
f0105f8a:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105f8d:	89 50 04             	mov    %edx,0x4(%eax)
	lk->cpu = 0;
f0105f90:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
#endif
}
f0105f97:	5d                   	pop    %ebp
f0105f98:	c3                   	ret    

f0105f99 <spin_lock>:
// Loops (spins) until the lock is acquired.
// Holding a lock for a long time may cause
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
f0105f99:	55                   	push   %ebp
f0105f9a:	89 e5                	mov    %esp,%ebp
f0105f9c:	56                   	push   %esi
f0105f9d:	53                   	push   %ebx
f0105f9e:	83 ec 20             	sub    $0x20,%esp
f0105fa1:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0105fa4:	83 3b 00             	cmpl   $0x0,(%ebx)
f0105fa7:	74 14                	je     f0105fbd <spin_lock+0x24>
f0105fa9:	8b 73 08             	mov    0x8(%ebx),%esi
f0105fac:	e8 82 fd ff ff       	call   f0105d33 <cpunum>
f0105fb1:	6b c0 74             	imul   $0x74,%eax,%eax
f0105fb4:	05 20 40 22 f0       	add    $0xf0224020,%eax
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
f0105fb9:	39 c6                	cmp    %eax,%esi
f0105fbb:	74 15                	je     f0105fd2 <spin_lock+0x39>
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f0105fbd:	89 da                	mov    %ebx,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f0105fbf:	b8 01 00 00 00       	mov    $0x1,%eax
f0105fc4:	f0 87 03             	lock xchg %eax,(%ebx)
f0105fc7:	b9 01 00 00 00       	mov    $0x1,%ecx
f0105fcc:	85 c0                	test   %eax,%eax
f0105fce:	75 2e                	jne    f0105ffe <spin_lock+0x65>
f0105fd0:	eb 37                	jmp    f0106009 <spin_lock+0x70>
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
		panic("CPU %d cannot acquire %s: already holding", cpunum(), lk->name);
f0105fd2:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0105fd5:	e8 59 fd ff ff       	call   f0105d33 <cpunum>
f0105fda:	89 5c 24 10          	mov    %ebx,0x10(%esp)
f0105fde:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105fe2:	c7 44 24 08 e8 7d 10 	movl   $0xf0107de8,0x8(%esp)
f0105fe9:	f0 
f0105fea:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
f0105ff1:	00 
f0105ff2:	c7 04 24 4c 7e 10 f0 	movl   $0xf0107e4c,(%esp)
f0105ff9:	e8 42 a0 ff ff       	call   f0100040 <_panic>

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
		asm volatile ("pause");
f0105ffe:	f3 90                	pause  
f0106000:	89 c8                	mov    %ecx,%eax
f0106002:	f0 87 02             	lock xchg %eax,(%edx)
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f0106005:	85 c0                	test   %eax,%eax
f0106007:	75 f5                	jne    f0105ffe <spin_lock+0x65>
		asm volatile ("pause");

	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
f0106009:	e8 25 fd ff ff       	call   f0105d33 <cpunum>
f010600e:	6b c0 74             	imul   $0x74,%eax,%eax
f0106011:	05 20 40 22 f0       	add    $0xf0224020,%eax
f0106016:	89 43 08             	mov    %eax,0x8(%ebx)
	get_caller_pcs(lk->pcs);
f0106019:	8d 4b 0c             	lea    0xc(%ebx),%ecx

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f010601c:	89 e8                	mov    %ebp,%eax
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
f010601e:	8d 90 00 00 80 10    	lea    0x10800000(%eax),%edx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0106024:	81 fa ff ff 7f 0e    	cmp    $0xe7fffff,%edx
f010602a:	76 3a                	jbe    f0106066 <spin_lock+0xcd>
f010602c:	eb 31                	jmp    f010605f <spin_lock+0xc6>
		    || ebp >= (uint32_t *)IOMEMBASE)
f010602e:	8d 9a 00 00 80 10    	lea    0x10800000(%edx),%ebx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0106034:	81 fb ff ff 7f 0e    	cmp    $0xe7fffff,%ebx
f010603a:	77 12                	ja     f010604e <spin_lock+0xb5>
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f010603c:	8b 5a 04             	mov    0x4(%edx),%ebx
f010603f:	89 1c 81             	mov    %ebx,(%ecx,%eax,4)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f0106042:	8b 12                	mov    (%edx),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f0106044:	83 c0 01             	add    $0x1,%eax
f0106047:	83 f8 0a             	cmp    $0xa,%eax
f010604a:	75 e2                	jne    f010602e <spin_lock+0x95>
f010604c:	eb 27                	jmp    f0106075 <spin_lock+0xdc>
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
		pcs[i] = 0;
f010604e:	c7 04 81 00 00 00 00 	movl   $0x0,(%ecx,%eax,4)
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
f0106055:	83 c0 01             	add    $0x1,%eax
f0106058:	83 f8 09             	cmp    $0x9,%eax
f010605b:	7e f1                	jle    f010604e <spin_lock+0xb5>
f010605d:	eb 16                	jmp    f0106075 <spin_lock+0xdc>
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f010605f:	b8 00 00 00 00       	mov    $0x0,%eax
f0106064:	eb e8                	jmp    f010604e <spin_lock+0xb5>
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f0106066:	8b 50 04             	mov    0x4(%eax),%edx
f0106069:	89 53 0c             	mov    %edx,0xc(%ebx)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f010606c:	8b 10                	mov    (%eax),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f010606e:	b8 01 00 00 00       	mov    $0x1,%eax
f0106073:	eb b9                	jmp    f010602e <spin_lock+0x95>
	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
	get_caller_pcs(lk->pcs);
#endif
}
f0106075:	83 c4 20             	add    $0x20,%esp
f0106078:	5b                   	pop    %ebx
f0106079:	5e                   	pop    %esi
f010607a:	5d                   	pop    %ebp
f010607b:	c3                   	ret    

f010607c <spin_unlock>:

// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
f010607c:	55                   	push   %ebp
f010607d:	89 e5                	mov    %esp,%ebp
f010607f:	57                   	push   %edi
f0106080:	56                   	push   %esi
f0106081:	53                   	push   %ebx
f0106082:	83 ec 6c             	sub    $0x6c,%esp
f0106085:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0106088:	83 3b 00             	cmpl   $0x0,(%ebx)
f010608b:	74 18                	je     f01060a5 <spin_unlock+0x29>
f010608d:	8b 73 08             	mov    0x8(%ebx),%esi
f0106090:	e8 9e fc ff ff       	call   f0105d33 <cpunum>
f0106095:	6b c0 74             	imul   $0x74,%eax,%eax
f0106098:	05 20 40 22 f0       	add    $0xf0224020,%eax
// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (!holding(lk)) {
f010609d:	39 c6                	cmp    %eax,%esi
f010609f:	0f 84 d4 00 00 00    	je     f0106179 <spin_unlock+0xfd>
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
f01060a5:	c7 44 24 08 28 00 00 	movl   $0x28,0x8(%esp)
f01060ac:	00 
f01060ad:	8d 43 0c             	lea    0xc(%ebx),%eax
f01060b0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01060b4:	8d 45 c0             	lea    -0x40(%ebp),%eax
f01060b7:	89 04 24             	mov    %eax,(%esp)
f01060ba:	e8 27 f6 ff ff       	call   f01056e6 <memmove>
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
f01060bf:	8b 43 08             	mov    0x8(%ebx),%eax
	if (!holding(lk)) {
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
f01060c2:	0f b6 30             	movzbl (%eax),%esi
f01060c5:	8b 5b 04             	mov    0x4(%ebx),%ebx
f01060c8:	e8 66 fc ff ff       	call   f0105d33 <cpunum>
f01060cd:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01060d1:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f01060d5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01060d9:	c7 04 24 14 7e 10 f0 	movl   $0xf0107e14,(%esp)
f01060e0:	e8 f9 dd ff ff       	call   f0103ede <cprintf>
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f01060e5:	8b 45 c0             	mov    -0x40(%ebp),%eax
f01060e8:	85 c0                	test   %eax,%eax
f01060ea:	74 71                	je     f010615d <spin_unlock+0xe1>
f01060ec:	8d 5d c0             	lea    -0x40(%ebp),%ebx
f01060ef:	8d 7d e4             	lea    -0x1c(%ebp),%edi
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
f01060f2:	8d 75 a8             	lea    -0x58(%ebp),%esi
f01060f5:	89 74 24 04          	mov    %esi,0x4(%esp)
f01060f9:	89 04 24             	mov    %eax,(%esp)
f01060fc:	e8 0b ea ff ff       	call   f0104b0c <debuginfo_eip>
f0106101:	85 c0                	test   %eax,%eax
f0106103:	78 39                	js     f010613e <spin_unlock+0xc2>
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
f0106105:	8b 03                	mov    (%ebx),%eax
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
f0106107:	89 c2                	mov    %eax,%edx
f0106109:	2b 55 b8             	sub    -0x48(%ebp),%edx
f010610c:	89 54 24 18          	mov    %edx,0x18(%esp)
f0106110:	8b 55 b0             	mov    -0x50(%ebp),%edx
f0106113:	89 54 24 14          	mov    %edx,0x14(%esp)
f0106117:	8b 55 b4             	mov    -0x4c(%ebp),%edx
f010611a:	89 54 24 10          	mov    %edx,0x10(%esp)
f010611e:	8b 55 ac             	mov    -0x54(%ebp),%edx
f0106121:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0106125:	8b 55 a8             	mov    -0x58(%ebp),%edx
f0106128:	89 54 24 08          	mov    %edx,0x8(%esp)
f010612c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106130:	c7 04 24 5c 7e 10 f0 	movl   $0xf0107e5c,(%esp)
f0106137:	e8 a2 dd ff ff       	call   f0103ede <cprintf>
f010613c:	eb 12                	jmp    f0106150 <spin_unlock+0xd4>
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
f010613e:	8b 03                	mov    (%ebx),%eax
f0106140:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106144:	c7 04 24 73 7e 10 f0 	movl   $0xf0107e73,(%esp)
f010614b:	e8 8e dd ff ff       	call   f0103ede <cprintf>
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0106150:	39 fb                	cmp    %edi,%ebx
f0106152:	74 09                	je     f010615d <spin_unlock+0xe1>
f0106154:	83 c3 04             	add    $0x4,%ebx
f0106157:	8b 03                	mov    (%ebx),%eax
f0106159:	85 c0                	test   %eax,%eax
f010615b:	75 98                	jne    f01060f5 <spin_unlock+0x79>
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
		}
		panic("spin_unlock");
f010615d:	c7 44 24 08 7b 7e 10 	movl   $0xf0107e7b,0x8(%esp)
f0106164:	f0 
f0106165:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
f010616c:	00 
f010616d:	c7 04 24 4c 7e 10 f0 	movl   $0xf0107e4c,(%esp)
f0106174:	e8 c7 9e ff ff       	call   f0100040 <_panic>
	}

	lk->pcs[0] = 0;
f0106179:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
	lk->cpu = 0;
f0106180:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f0106187:	b8 00 00 00 00       	mov    $0x0,%eax
f010618c:	f0 87 03             	lock xchg %eax,(%ebx)
	// Paper says that Intel 64 and IA-32 will not move a load
	// after a store. So lock->locked = 0 would work here.
	// The xchg being asm volatile ensures gcc emits it after
	// the above assignments (and after the critical section).
	xchg(&lk->locked, 0);
}
f010618f:	83 c4 6c             	add    $0x6c,%esp
f0106192:	5b                   	pop    %ebx
f0106193:	5e                   	pop    %esi
f0106194:	5f                   	pop    %edi
f0106195:	5d                   	pop    %ebp
f0106196:	c3                   	ret    
f0106197:	66 90                	xchg   %ax,%ax
f0106199:	66 90                	xchg   %ax,%ax
f010619b:	66 90                	xchg   %ax,%ax
f010619d:	66 90                	xchg   %ax,%ax
f010619f:	90                   	nop

f01061a0 <__udivdi3>:
f01061a0:	55                   	push   %ebp
f01061a1:	57                   	push   %edi
f01061a2:	56                   	push   %esi
f01061a3:	83 ec 0c             	sub    $0xc,%esp
f01061a6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01061aa:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f01061ae:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f01061b2:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01061b6:	85 c0                	test   %eax,%eax
f01061b8:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01061bc:	89 ea                	mov    %ebp,%edx
f01061be:	89 0c 24             	mov    %ecx,(%esp)
f01061c1:	75 2d                	jne    f01061f0 <__udivdi3+0x50>
f01061c3:	39 e9                	cmp    %ebp,%ecx
f01061c5:	77 61                	ja     f0106228 <__udivdi3+0x88>
f01061c7:	85 c9                	test   %ecx,%ecx
f01061c9:	89 ce                	mov    %ecx,%esi
f01061cb:	75 0b                	jne    f01061d8 <__udivdi3+0x38>
f01061cd:	b8 01 00 00 00       	mov    $0x1,%eax
f01061d2:	31 d2                	xor    %edx,%edx
f01061d4:	f7 f1                	div    %ecx
f01061d6:	89 c6                	mov    %eax,%esi
f01061d8:	31 d2                	xor    %edx,%edx
f01061da:	89 e8                	mov    %ebp,%eax
f01061dc:	f7 f6                	div    %esi
f01061de:	89 c5                	mov    %eax,%ebp
f01061e0:	89 f8                	mov    %edi,%eax
f01061e2:	f7 f6                	div    %esi
f01061e4:	89 ea                	mov    %ebp,%edx
f01061e6:	83 c4 0c             	add    $0xc,%esp
f01061e9:	5e                   	pop    %esi
f01061ea:	5f                   	pop    %edi
f01061eb:	5d                   	pop    %ebp
f01061ec:	c3                   	ret    
f01061ed:	8d 76 00             	lea    0x0(%esi),%esi
f01061f0:	39 e8                	cmp    %ebp,%eax
f01061f2:	77 24                	ja     f0106218 <__udivdi3+0x78>
f01061f4:	0f bd e8             	bsr    %eax,%ebp
f01061f7:	83 f5 1f             	xor    $0x1f,%ebp
f01061fa:	75 3c                	jne    f0106238 <__udivdi3+0x98>
f01061fc:	8b 74 24 04          	mov    0x4(%esp),%esi
f0106200:	39 34 24             	cmp    %esi,(%esp)
f0106203:	0f 86 9f 00 00 00    	jbe    f01062a8 <__udivdi3+0x108>
f0106209:	39 d0                	cmp    %edx,%eax
f010620b:	0f 82 97 00 00 00    	jb     f01062a8 <__udivdi3+0x108>
f0106211:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0106218:	31 d2                	xor    %edx,%edx
f010621a:	31 c0                	xor    %eax,%eax
f010621c:	83 c4 0c             	add    $0xc,%esp
f010621f:	5e                   	pop    %esi
f0106220:	5f                   	pop    %edi
f0106221:	5d                   	pop    %ebp
f0106222:	c3                   	ret    
f0106223:	90                   	nop
f0106224:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106228:	89 f8                	mov    %edi,%eax
f010622a:	f7 f1                	div    %ecx
f010622c:	31 d2                	xor    %edx,%edx
f010622e:	83 c4 0c             	add    $0xc,%esp
f0106231:	5e                   	pop    %esi
f0106232:	5f                   	pop    %edi
f0106233:	5d                   	pop    %ebp
f0106234:	c3                   	ret    
f0106235:	8d 76 00             	lea    0x0(%esi),%esi
f0106238:	89 e9                	mov    %ebp,%ecx
f010623a:	8b 3c 24             	mov    (%esp),%edi
f010623d:	d3 e0                	shl    %cl,%eax
f010623f:	89 c6                	mov    %eax,%esi
f0106241:	b8 20 00 00 00       	mov    $0x20,%eax
f0106246:	29 e8                	sub    %ebp,%eax
f0106248:	89 c1                	mov    %eax,%ecx
f010624a:	d3 ef                	shr    %cl,%edi
f010624c:	89 e9                	mov    %ebp,%ecx
f010624e:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0106252:	8b 3c 24             	mov    (%esp),%edi
f0106255:	09 74 24 08          	or     %esi,0x8(%esp)
f0106259:	89 d6                	mov    %edx,%esi
f010625b:	d3 e7                	shl    %cl,%edi
f010625d:	89 c1                	mov    %eax,%ecx
f010625f:	89 3c 24             	mov    %edi,(%esp)
f0106262:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106266:	d3 ee                	shr    %cl,%esi
f0106268:	89 e9                	mov    %ebp,%ecx
f010626a:	d3 e2                	shl    %cl,%edx
f010626c:	89 c1                	mov    %eax,%ecx
f010626e:	d3 ef                	shr    %cl,%edi
f0106270:	09 d7                	or     %edx,%edi
f0106272:	89 f2                	mov    %esi,%edx
f0106274:	89 f8                	mov    %edi,%eax
f0106276:	f7 74 24 08          	divl   0x8(%esp)
f010627a:	89 d6                	mov    %edx,%esi
f010627c:	89 c7                	mov    %eax,%edi
f010627e:	f7 24 24             	mull   (%esp)
f0106281:	39 d6                	cmp    %edx,%esi
f0106283:	89 14 24             	mov    %edx,(%esp)
f0106286:	72 30                	jb     f01062b8 <__udivdi3+0x118>
f0106288:	8b 54 24 04          	mov    0x4(%esp),%edx
f010628c:	89 e9                	mov    %ebp,%ecx
f010628e:	d3 e2                	shl    %cl,%edx
f0106290:	39 c2                	cmp    %eax,%edx
f0106292:	73 05                	jae    f0106299 <__udivdi3+0xf9>
f0106294:	3b 34 24             	cmp    (%esp),%esi
f0106297:	74 1f                	je     f01062b8 <__udivdi3+0x118>
f0106299:	89 f8                	mov    %edi,%eax
f010629b:	31 d2                	xor    %edx,%edx
f010629d:	e9 7a ff ff ff       	jmp    f010621c <__udivdi3+0x7c>
f01062a2:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f01062a8:	31 d2                	xor    %edx,%edx
f01062aa:	b8 01 00 00 00       	mov    $0x1,%eax
f01062af:	e9 68 ff ff ff       	jmp    f010621c <__udivdi3+0x7c>
f01062b4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01062b8:	8d 47 ff             	lea    -0x1(%edi),%eax
f01062bb:	31 d2                	xor    %edx,%edx
f01062bd:	83 c4 0c             	add    $0xc,%esp
f01062c0:	5e                   	pop    %esi
f01062c1:	5f                   	pop    %edi
f01062c2:	5d                   	pop    %ebp
f01062c3:	c3                   	ret    
f01062c4:	66 90                	xchg   %ax,%ax
f01062c6:	66 90                	xchg   %ax,%ax
f01062c8:	66 90                	xchg   %ax,%ax
f01062ca:	66 90                	xchg   %ax,%ax
f01062cc:	66 90                	xchg   %ax,%ax
f01062ce:	66 90                	xchg   %ax,%ax

f01062d0 <__umoddi3>:
f01062d0:	55                   	push   %ebp
f01062d1:	57                   	push   %edi
f01062d2:	56                   	push   %esi
f01062d3:	83 ec 14             	sub    $0x14,%esp
f01062d6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01062da:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01062de:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f01062e2:	89 c7                	mov    %eax,%edi
f01062e4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01062e8:	8b 44 24 30          	mov    0x30(%esp),%eax
f01062ec:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f01062f0:	89 34 24             	mov    %esi,(%esp)
f01062f3:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01062f7:	85 c0                	test   %eax,%eax
f01062f9:	89 c2                	mov    %eax,%edx
f01062fb:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01062ff:	75 17                	jne    f0106318 <__umoddi3+0x48>
f0106301:	39 fe                	cmp    %edi,%esi
f0106303:	76 4b                	jbe    f0106350 <__umoddi3+0x80>
f0106305:	89 c8                	mov    %ecx,%eax
f0106307:	89 fa                	mov    %edi,%edx
f0106309:	f7 f6                	div    %esi
f010630b:	89 d0                	mov    %edx,%eax
f010630d:	31 d2                	xor    %edx,%edx
f010630f:	83 c4 14             	add    $0x14,%esp
f0106312:	5e                   	pop    %esi
f0106313:	5f                   	pop    %edi
f0106314:	5d                   	pop    %ebp
f0106315:	c3                   	ret    
f0106316:	66 90                	xchg   %ax,%ax
f0106318:	39 f8                	cmp    %edi,%eax
f010631a:	77 54                	ja     f0106370 <__umoddi3+0xa0>
f010631c:	0f bd e8             	bsr    %eax,%ebp
f010631f:	83 f5 1f             	xor    $0x1f,%ebp
f0106322:	75 5c                	jne    f0106380 <__umoddi3+0xb0>
f0106324:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0106328:	39 3c 24             	cmp    %edi,(%esp)
f010632b:	0f 87 e7 00 00 00    	ja     f0106418 <__umoddi3+0x148>
f0106331:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106335:	29 f1                	sub    %esi,%ecx
f0106337:	19 c7                	sbb    %eax,%edi
f0106339:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f010633d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106341:	8b 44 24 08          	mov    0x8(%esp),%eax
f0106345:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0106349:	83 c4 14             	add    $0x14,%esp
f010634c:	5e                   	pop    %esi
f010634d:	5f                   	pop    %edi
f010634e:	5d                   	pop    %ebp
f010634f:	c3                   	ret    
f0106350:	85 f6                	test   %esi,%esi
f0106352:	89 f5                	mov    %esi,%ebp
f0106354:	75 0b                	jne    f0106361 <__umoddi3+0x91>
f0106356:	b8 01 00 00 00       	mov    $0x1,%eax
f010635b:	31 d2                	xor    %edx,%edx
f010635d:	f7 f6                	div    %esi
f010635f:	89 c5                	mov    %eax,%ebp
f0106361:	8b 44 24 04          	mov    0x4(%esp),%eax
f0106365:	31 d2                	xor    %edx,%edx
f0106367:	f7 f5                	div    %ebp
f0106369:	89 c8                	mov    %ecx,%eax
f010636b:	f7 f5                	div    %ebp
f010636d:	eb 9c                	jmp    f010630b <__umoddi3+0x3b>
f010636f:	90                   	nop
f0106370:	89 c8                	mov    %ecx,%eax
f0106372:	89 fa                	mov    %edi,%edx
f0106374:	83 c4 14             	add    $0x14,%esp
f0106377:	5e                   	pop    %esi
f0106378:	5f                   	pop    %edi
f0106379:	5d                   	pop    %ebp
f010637a:	c3                   	ret    
f010637b:	90                   	nop
f010637c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106380:	8b 04 24             	mov    (%esp),%eax
f0106383:	be 20 00 00 00       	mov    $0x20,%esi
f0106388:	89 e9                	mov    %ebp,%ecx
f010638a:	29 ee                	sub    %ebp,%esi
f010638c:	d3 e2                	shl    %cl,%edx
f010638e:	89 f1                	mov    %esi,%ecx
f0106390:	d3 e8                	shr    %cl,%eax
f0106392:	89 e9                	mov    %ebp,%ecx
f0106394:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106398:	8b 04 24             	mov    (%esp),%eax
f010639b:	09 54 24 04          	or     %edx,0x4(%esp)
f010639f:	89 fa                	mov    %edi,%edx
f01063a1:	d3 e0                	shl    %cl,%eax
f01063a3:	89 f1                	mov    %esi,%ecx
f01063a5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01063a9:	8b 44 24 10          	mov    0x10(%esp),%eax
f01063ad:	d3 ea                	shr    %cl,%edx
f01063af:	89 e9                	mov    %ebp,%ecx
f01063b1:	d3 e7                	shl    %cl,%edi
f01063b3:	89 f1                	mov    %esi,%ecx
f01063b5:	d3 e8                	shr    %cl,%eax
f01063b7:	89 e9                	mov    %ebp,%ecx
f01063b9:	09 f8                	or     %edi,%eax
f01063bb:	8b 7c 24 10          	mov    0x10(%esp),%edi
f01063bf:	f7 74 24 04          	divl   0x4(%esp)
f01063c3:	d3 e7                	shl    %cl,%edi
f01063c5:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01063c9:	89 d7                	mov    %edx,%edi
f01063cb:	f7 64 24 08          	mull   0x8(%esp)
f01063cf:	39 d7                	cmp    %edx,%edi
f01063d1:	89 c1                	mov    %eax,%ecx
f01063d3:	89 14 24             	mov    %edx,(%esp)
f01063d6:	72 2c                	jb     f0106404 <__umoddi3+0x134>
f01063d8:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f01063dc:	72 22                	jb     f0106400 <__umoddi3+0x130>
f01063de:	8b 44 24 0c          	mov    0xc(%esp),%eax
f01063e2:	29 c8                	sub    %ecx,%eax
f01063e4:	19 d7                	sbb    %edx,%edi
f01063e6:	89 e9                	mov    %ebp,%ecx
f01063e8:	89 fa                	mov    %edi,%edx
f01063ea:	d3 e8                	shr    %cl,%eax
f01063ec:	89 f1                	mov    %esi,%ecx
f01063ee:	d3 e2                	shl    %cl,%edx
f01063f0:	89 e9                	mov    %ebp,%ecx
f01063f2:	d3 ef                	shr    %cl,%edi
f01063f4:	09 d0                	or     %edx,%eax
f01063f6:	89 fa                	mov    %edi,%edx
f01063f8:	83 c4 14             	add    $0x14,%esp
f01063fb:	5e                   	pop    %esi
f01063fc:	5f                   	pop    %edi
f01063fd:	5d                   	pop    %ebp
f01063fe:	c3                   	ret    
f01063ff:	90                   	nop
f0106400:	39 d7                	cmp    %edx,%edi
f0106402:	75 da                	jne    f01063de <__umoddi3+0x10e>
f0106404:	8b 14 24             	mov    (%esp),%edx
f0106407:	89 c1                	mov    %eax,%ecx
f0106409:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f010640d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0106411:	eb cb                	jmp    f01063de <__umoddi3+0x10e>
f0106413:	90                   	nop
f0106414:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106418:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f010641c:	0f 82 0f ff ff ff    	jb     f0106331 <__umoddi3+0x61>
f0106422:	e9 1a ff ff ff       	jmp    f0106341 <__umoddi3+0x71>
