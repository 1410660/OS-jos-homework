
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
f0100015:	b8 00 a0 11 00       	mov    $0x11a000,%eax
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
f0100034:	bc 00 a0 11 f0       	mov    $0xf011a000,%esp

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
f010004b:	83 3d 00 ff 21 f0 00 	cmpl   $0x0,0xf021ff00
f0100052:	75 46                	jne    f010009a <_panic+0x5a>
		goto dead;
	panicstr = fmt;
f0100054:	89 35 00 ff 21 f0    	mov    %esi,0xf021ff00

	// Be extra sure that the machine is in as reasonable state
	__asm __volatile("cli; cld");
f010005a:	fa                   	cli    
f010005b:	fc                   	cld    

	va_start(ap, fmt);
f010005c:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic on CPU %d at %s:%d: ", cpunum(), file, line);
f010005f:	e8 ef 3d 00 00       	call   f0103e53 <cpunum>
f0100064:	8b 55 0c             	mov    0xc(%ebp),%edx
f0100067:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010006b:	8b 55 08             	mov    0x8(%ebp),%edx
f010006e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100072:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100076:	c7 04 24 60 45 10 f0 	movl   $0xf0104560,(%esp)
f010007d:	e8 df 1f 00 00       	call   f0102061 <cprintf>
	vcprintf(fmt, ap);
f0100082:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100086:	89 34 24             	mov    %esi,(%esp)
f0100089:	e8 a0 1f 00 00       	call   f010202e <vcprintf>
	cprintf("\n");
f010008e:	c7 04 24 2d 46 10 f0 	movl   $0xf010462d,(%esp)
f0100095:	e8 c7 1f 00 00       	call   f0102061 <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f010009a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000a1:	e8 1c 09 00 00       	call   f01009c2 <monitor>
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
f01000af:	b8 04 10 26 f0       	mov    $0xf0261004,%eax
f01000b4:	2d 58 e4 21 f0       	sub    $0xf021e458,%eax
f01000b9:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000bd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01000c4:	00 
f01000c5:	c7 04 24 58 e4 21 f0 	movl   $0xf021e458,(%esp)
f01000cc:	e8 e8 36 00 00       	call   f01037b9 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000d1:	e8 d9 05 00 00       	call   f01006af <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000d6:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000dd:	00 
f01000de:	c7 04 24 cc 45 10 f0 	movl   $0xf01045cc,(%esp)
f01000e5:	e8 77 1f 00 00       	call   f0102061 <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f01000ea:	e8 9a 13 00 00       	call   f0101489 <mem_init>

	// Lab 3 user environment initialization functions
	env_init();
f01000ef:	e8 a6 16 00 00       	call   f010179a <env_init>
	trap_init();
f01000f4:	e8 e4 1f 00 00       	call   f01020dd <trap_init>

	// Lab 4 multiprocessor initialization functions
	mp_init();
f01000f9:	e8 3b 3a 00 00       	call   f0103b39 <mp_init>
	lapic_init();
f01000fe:	66 90                	xchg   %ax,%ax
f0100100:	e8 69 3d 00 00       	call   f0103e6e <lapic_init>

	// Lab 4 multitasking initialization functions
	pic_init();
f0100105:	e8 84 1e 00 00       	call   f0101f8e <pic_init>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010010a:	83 3d 08 ff 21 f0 07 	cmpl   $0x7,0xf021ff08
f0100111:	77 24                	ja     f0100137 <i386_init+0x8f>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100113:	c7 44 24 0c 00 70 00 	movl   $0x7000,0xc(%esp)
f010011a:	00 
f010011b:	c7 44 24 08 84 45 10 	movl   $0xf0104584,0x8(%esp)
f0100122:	f0 
f0100123:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f010012a:	00 
f010012b:	c7 04 24 e7 45 10 f0 	movl   $0xf01045e7,(%esp)
f0100132:	e8 09 ff ff ff       	call   f0100040 <_panic>
	void *code;
	struct Cpu *c;

	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);
f0100137:	b8 66 3a 10 f0       	mov    $0xf0103a66,%eax
f010013c:	2d ec 39 10 f0       	sub    $0xf01039ec,%eax
f0100141:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100145:	c7 44 24 04 ec 39 10 	movl   $0xf01039ec,0x4(%esp)
f010014c:	f0 
f010014d:	c7 04 24 00 70 00 f0 	movl   $0xf0007000,(%esp)
f0100154:	e8 ad 36 00 00       	call   f0103806 <memmove>

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100159:	6b 05 c4 03 22 f0 74 	imul   $0x74,0xf02203c4,%eax
f0100160:	05 20 00 22 f0       	add    $0xf0220020,%eax
f0100165:	3d 20 00 22 f0       	cmp    $0xf0220020,%eax
f010016a:	0f 86 a6 00 00 00    	jbe    f0100216 <i386_init+0x16e>
f0100170:	bb 20 00 22 f0       	mov    $0xf0220020,%ebx
		if (c == cpus + cpunum())  // We've started already.
f0100175:	e8 d9 3c 00 00       	call   f0103e53 <cpunum>
f010017a:	6b c0 74             	imul   $0x74,%eax,%eax
f010017d:	05 20 00 22 f0       	add    $0xf0220020,%eax
f0100182:	39 c3                	cmp    %eax,%ebx
f0100184:	74 39                	je     f01001bf <i386_init+0x117>
f0100186:	89 d8                	mov    %ebx,%eax
f0100188:	2d 20 00 22 f0       	sub    $0xf0220020,%eax
			continue;

		// Tell mpentry.S what stack to use 
		mpentry_kstack = percpu_kstacks[c - cpus] + KSTKSIZE;
f010018d:	c1 f8 02             	sar    $0x2,%eax
f0100190:	69 c0 35 c2 72 4f    	imul   $0x4f72c235,%eax,%eax
f0100196:	c1 e0 0f             	shl    $0xf,%eax
f0100199:	8d 80 00 90 22 f0    	lea    -0xfdd7000(%eax),%eax
f010019f:	a3 04 ff 21 f0       	mov    %eax,0xf021ff04
		// Start the CPU at mpentry_start
		lapic_startap(c->cpu_id, PADDR(code));
f01001a4:	c7 44 24 04 00 70 00 	movl   $0x7000,0x4(%esp)
f01001ab:	00 
f01001ac:	0f b6 03             	movzbl (%ebx),%eax
f01001af:	89 04 24             	mov    %eax,(%esp)
f01001b2:	e8 ef 3d 00 00       	call   f0103fa6 <lapic_startap>
		// Wait for the CPU to finish some basic setup in mp_main()
		while(c->cpu_status != CPU_STARTED)
f01001b7:	8b 43 04             	mov    0x4(%ebx),%eax
f01001ba:	83 f8 01             	cmp    $0x1,%eax
f01001bd:	75 f8                	jne    f01001b7 <i386_init+0x10f>
	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f01001bf:	83 c3 74             	add    $0x74,%ebx
f01001c2:	6b 05 c4 03 22 f0 74 	imul   $0x74,0xf02203c4,%eax
f01001c9:	05 20 00 22 f0       	add    $0xf0220020,%eax
f01001ce:	39 c3                	cmp    %eax,%ebx
f01001d0:	72 a3                	jb     f0100175 <i386_init+0xcd>
f01001d2:	eb 42                	jmp    f0100216 <i386_init+0x16e>
	boot_aps();

	// Should always have idle processes at first.
	int i;
	for (i = 0; i < NCPU; i++)
		ENV_CREATE(user_idle, ENV_TYPE_IDLE);
f01001d4:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01001db:	00 
f01001dc:	c7 44 24 04 5e 89 00 	movl   $0x895e,0x4(%esp)
f01001e3:	00 
f01001e4:	c7 04 24 2c be 18 f0 	movl   $0xf018be2c,(%esp)
f01001eb:	e8 a3 17 00 00       	call   f0101993 <env_create>
	// Starting non-boot CPUs
	boot_aps();

	// Should always have idle processes at first.
	int i;
	for (i = 0; i < NCPU; i++)
f01001f0:	83 eb 01             	sub    $0x1,%ebx
f01001f3:	75 df                	jne    f01001d4 <i386_init+0x12c>
#if defined(TEST)
	// Don't touch -- used by grading script!
	ENV_CREATE(TEST, ENV_TYPE_USER);
#else
	// Touch all you want.
	ENV_CREATE(user_primes, ENV_TYPE_USER);
f01001f5:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01001fc:	00 
f01001fd:	c7 44 24 04 21 8a 00 	movl   $0x8a21,0x4(%esp)
f0100204:	00 
f0100205:	c7 04 24 37 5a 21 f0 	movl   $0xf0215a37,(%esp)
f010020c:	e8 82 17 00 00       	call   f0101993 <env_create>
#endif // TEST*

	// Schedule and run the first user environment!
	sched_yield();
f0100211:	e8 0b 27 00 00       	call   f0102921 <sched_yield>
	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100216:	bb 08 00 00 00       	mov    $0x8,%ebx
f010021b:	eb b7                	jmp    f01001d4 <i386_init+0x12c>

f010021d <mp_main>:
}

// Setup code for APs
void
mp_main(void)
{
f010021d:	55                   	push   %ebp
f010021e:	89 e5                	mov    %esp,%ebp
f0100220:	83 ec 18             	sub    $0x18,%esp
	// We are in high EIP now, safe to switch to kern_pgdir 
	lcr3(PADDR(kern_pgdir));
f0100223:	a1 0c ff 21 f0       	mov    0xf021ff0c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100228:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010022d:	77 20                	ja     f010024f <mp_main+0x32>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010022f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100233:	c7 44 24 08 a8 45 10 	movl   $0xf01045a8,0x8(%esp)
f010023a:	f0 
f010023b:	c7 44 24 04 6e 00 00 	movl   $0x6e,0x4(%esp)
f0100242:	00 
f0100243:	c7 04 24 e7 45 10 f0 	movl   $0xf01045e7,(%esp)
f010024a:	e8 f1 fd ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f010024f:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0100254:	0f 22 d8             	mov    %eax,%cr3
	cprintf("SMP: CPU %d starting\n", cpunum());
f0100257:	e8 f7 3b 00 00       	call   f0103e53 <cpunum>
f010025c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100260:	c7 04 24 f3 45 10 f0 	movl   $0xf01045f3,(%esp)
f0100267:	e8 f5 1d 00 00       	call   f0102061 <cprintf>

	lapic_init();
f010026c:	e8 fd 3b 00 00       	call   f0103e6e <lapic_init>
	env_init_percpu();
f0100271:	e8 fa 14 00 00       	call   f0101770 <env_init_percpu>
	trap_init_percpu();
f0100276:	e8 05 1e 00 00       	call   f0102080 <trap_init_percpu>
	xchg(&thiscpu->cpu_status, CPU_STARTED); // tell boot_aps() we're up
f010027b:	90                   	nop
f010027c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100280:	e8 ce 3b 00 00       	call   f0103e53 <cpunum>
f0100285:	6b d0 74             	imul   $0x74,%eax,%edx
f0100288:	81 c2 20 00 22 f0    	add    $0xf0220020,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f010028e:	b8 01 00 00 00       	mov    $0x1,%eax
f0100293:	f0 87 42 04          	lock xchg %eax,0x4(%edx)
f0100297:	eb fe                	jmp    f0100297 <mp_main+0x7a>

f0100299 <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f0100299:	55                   	push   %ebp
f010029a:	89 e5                	mov    %esp,%ebp
f010029c:	53                   	push   %ebx
f010029d:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f01002a0:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f01002a3:	8b 45 0c             	mov    0xc(%ebp),%eax
f01002a6:	89 44 24 08          	mov    %eax,0x8(%esp)
f01002aa:	8b 45 08             	mov    0x8(%ebp),%eax
f01002ad:	89 44 24 04          	mov    %eax,0x4(%esp)
f01002b1:	c7 04 24 09 46 10 f0 	movl   $0xf0104609,(%esp)
f01002b8:	e8 a4 1d 00 00       	call   f0102061 <cprintf>
	vcprintf(fmt, ap);
f01002bd:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01002c1:	8b 45 10             	mov    0x10(%ebp),%eax
f01002c4:	89 04 24             	mov    %eax,(%esp)
f01002c7:	e8 62 1d 00 00       	call   f010202e <vcprintf>
	cprintf("\n");
f01002cc:	c7 04 24 2d 46 10 f0 	movl   $0xf010462d,(%esp)
f01002d3:	e8 89 1d 00 00       	call   f0102061 <cprintf>
	va_end(ap);
}
f01002d8:	83 c4 14             	add    $0x14,%esp
f01002db:	5b                   	pop    %ebx
f01002dc:	5d                   	pop    %ebp
f01002dd:	c3                   	ret    
f01002de:	66 90                	xchg   %ax,%ax

f01002e0 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f01002e0:	55                   	push   %ebp
f01002e1:	89 e5                	mov    %esp,%ebp

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01002e3:	ba fd 03 00 00       	mov    $0x3fd,%edx
f01002e8:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f01002e9:	a8 01                	test   $0x1,%al
f01002eb:	74 08                	je     f01002f5 <serial_proc_data+0x15>
f01002ed:	b2 f8                	mov    $0xf8,%dl
f01002ef:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f01002f0:	0f b6 c0             	movzbl %al,%eax
f01002f3:	eb 05                	jmp    f01002fa <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f01002f5:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f01002fa:	5d                   	pop    %ebp
f01002fb:	c3                   	ret    

f01002fc <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f01002fc:	55                   	push   %ebp
f01002fd:	89 e5                	mov    %esp,%ebp
f01002ff:	53                   	push   %ebx
f0100300:	83 ec 04             	sub    $0x4,%esp
f0100303:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f0100305:	eb 2a                	jmp    f0100331 <cons_intr+0x35>
		if (c == 0)
f0100307:	85 d2                	test   %edx,%edx
f0100309:	74 26                	je     f0100331 <cons_intr+0x35>
			continue;
		cons.buf[cons.wpos++] = c;
f010030b:	a1 24 f2 21 f0       	mov    0xf021f224,%eax
f0100310:	8d 48 01             	lea    0x1(%eax),%ecx
f0100313:	89 0d 24 f2 21 f0    	mov    %ecx,0xf021f224
f0100319:	88 90 20 f0 21 f0    	mov    %dl,-0xfde0fe0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f010031f:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100325:	75 0a                	jne    f0100331 <cons_intr+0x35>
			cons.wpos = 0;
f0100327:	c7 05 24 f2 21 f0 00 	movl   $0x0,0xf021f224
f010032e:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f0100331:	ff d3                	call   *%ebx
f0100333:	89 c2                	mov    %eax,%edx
f0100335:	83 f8 ff             	cmp    $0xffffffff,%eax
f0100338:	75 cd                	jne    f0100307 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f010033a:	83 c4 04             	add    $0x4,%esp
f010033d:	5b                   	pop    %ebx
f010033e:	5d                   	pop    %ebp
f010033f:	c3                   	ret    

f0100340 <kbd_proc_data>:
f0100340:	ba 64 00 00 00       	mov    $0x64,%edx
f0100345:	ec                   	in     (%dx),%al
{
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
f0100346:	a8 01                	test   $0x1,%al
f0100348:	0f 84 ef 00 00 00    	je     f010043d <kbd_proc_data+0xfd>
f010034e:	b2 60                	mov    $0x60,%dl
f0100350:	ec                   	in     (%dx),%al
f0100351:	89 c2                	mov    %eax,%edx
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f0100353:	3c e0                	cmp    $0xe0,%al
f0100355:	75 0d                	jne    f0100364 <kbd_proc_data+0x24>
		// E0 escape character
		shift |= E0ESC;
f0100357:	83 0d 00 f0 21 f0 40 	orl    $0x40,0xf021f000
		return 0;
f010035e:	b8 00 00 00 00       	mov    $0x0,%eax
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100363:	c3                   	ret    
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f0100364:	55                   	push   %ebp
f0100365:	89 e5                	mov    %esp,%ebp
f0100367:	53                   	push   %ebx
f0100368:	83 ec 14             	sub    $0x14,%esp

	if (data == 0xE0) {
		// E0 escape character
		shift |= E0ESC;
		return 0;
	} else if (data & 0x80) {
f010036b:	84 c0                	test   %al,%al
f010036d:	79 37                	jns    f01003a6 <kbd_proc_data+0x66>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f010036f:	8b 0d 00 f0 21 f0    	mov    0xf021f000,%ecx
f0100375:	89 cb                	mov    %ecx,%ebx
f0100377:	83 e3 40             	and    $0x40,%ebx
f010037a:	83 e0 7f             	and    $0x7f,%eax
f010037d:	85 db                	test   %ebx,%ebx
f010037f:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f0100382:	0f b6 d2             	movzbl %dl,%edx
f0100385:	0f b6 82 80 47 10 f0 	movzbl -0xfefb880(%edx),%eax
f010038c:	83 c8 40             	or     $0x40,%eax
f010038f:	0f b6 c0             	movzbl %al,%eax
f0100392:	f7 d0                	not    %eax
f0100394:	21 c1                	and    %eax,%ecx
f0100396:	89 0d 00 f0 21 f0    	mov    %ecx,0xf021f000
		return 0;
f010039c:	b8 00 00 00 00       	mov    $0x0,%eax
f01003a1:	e9 9d 00 00 00       	jmp    f0100443 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f01003a6:	8b 0d 00 f0 21 f0    	mov    0xf021f000,%ecx
f01003ac:	f6 c1 40             	test   $0x40,%cl
f01003af:	74 0e                	je     f01003bf <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f01003b1:	83 c8 80             	or     $0xffffff80,%eax
f01003b4:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f01003b6:	83 e1 bf             	and    $0xffffffbf,%ecx
f01003b9:	89 0d 00 f0 21 f0    	mov    %ecx,0xf021f000
	}

	shift |= shiftcode[data];
f01003bf:	0f b6 d2             	movzbl %dl,%edx
f01003c2:	0f b6 82 80 47 10 f0 	movzbl -0xfefb880(%edx),%eax
f01003c9:	0b 05 00 f0 21 f0    	or     0xf021f000,%eax
	shift ^= togglecode[data];
f01003cf:	0f b6 8a 80 46 10 f0 	movzbl -0xfefb980(%edx),%ecx
f01003d6:	31 c8                	xor    %ecx,%eax
f01003d8:	a3 00 f0 21 f0       	mov    %eax,0xf021f000

	c = charcode[shift & (CTL | SHIFT)][data];
f01003dd:	89 c1                	mov    %eax,%ecx
f01003df:	83 e1 03             	and    $0x3,%ecx
f01003e2:	8b 0c 8d 60 46 10 f0 	mov    -0xfefb9a0(,%ecx,4),%ecx
f01003e9:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f01003ed:	0f b6 da             	movzbl %dl,%ebx
	if (shift & CAPSLOCK) {
f01003f0:	a8 08                	test   $0x8,%al
f01003f2:	74 1b                	je     f010040f <kbd_proc_data+0xcf>
		if ('a' <= c && c <= 'z')
f01003f4:	89 da                	mov    %ebx,%edx
f01003f6:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f01003f9:	83 f9 19             	cmp    $0x19,%ecx
f01003fc:	77 05                	ja     f0100403 <kbd_proc_data+0xc3>
			c += 'A' - 'a';
f01003fe:	83 eb 20             	sub    $0x20,%ebx
f0100401:	eb 0c                	jmp    f010040f <kbd_proc_data+0xcf>
		else if ('A' <= c && c <= 'Z')
f0100403:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f0100406:	8d 4b 20             	lea    0x20(%ebx),%ecx
f0100409:	83 fa 19             	cmp    $0x19,%edx
f010040c:	0f 46 d9             	cmovbe %ecx,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f010040f:	f7 d0                	not    %eax
f0100411:	89 c2                	mov    %eax,%edx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100413:	89 d8                	mov    %ebx,%eax
			c += 'a' - 'A';
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f0100415:	f6 c2 06             	test   $0x6,%dl
f0100418:	75 29                	jne    f0100443 <kbd_proc_data+0x103>
f010041a:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f0100420:	75 21                	jne    f0100443 <kbd_proc_data+0x103>
		cprintf("Rebooting!\n");
f0100422:	c7 04 24 23 46 10 f0 	movl   $0xf0104623,(%esp)
f0100429:	e8 33 1c 00 00       	call   f0102061 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010042e:	ba 92 00 00 00       	mov    $0x92,%edx
f0100433:	b8 03 00 00 00       	mov    $0x3,%eax
f0100438:	ee                   	out    %al,(%dx)
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100439:	89 d8                	mov    %ebx,%eax
f010043b:	eb 06                	jmp    f0100443 <kbd_proc_data+0x103>
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
		return -1;
f010043d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100442:	c3                   	ret    
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100443:	83 c4 14             	add    $0x14,%esp
f0100446:	5b                   	pop    %ebx
f0100447:	5d                   	pop    %ebp
f0100448:	c3                   	ret    

f0100449 <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f0100449:	55                   	push   %ebp
f010044a:	89 e5                	mov    %esp,%ebp
f010044c:	57                   	push   %edi
f010044d:	56                   	push   %esi
f010044e:	53                   	push   %ebx
f010044f:	83 ec 1c             	sub    $0x1c,%esp
f0100452:	89 c7                	mov    %eax,%edi

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100454:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100459:	ec                   	in     (%dx),%al
static void
serial_putc(int c)
{
	int i;
	
	for (i = 0;
f010045a:	a8 20                	test   $0x20,%al
f010045c:	75 21                	jne    f010047f <cons_putc+0x36>
f010045e:	bb 00 32 00 00       	mov    $0x3200,%ebx
f0100463:	b9 84 00 00 00       	mov    $0x84,%ecx
f0100468:	be fd 03 00 00       	mov    $0x3fd,%esi
f010046d:	89 ca                	mov    %ecx,%edx
f010046f:	ec                   	in     (%dx),%al
f0100470:	ec                   	in     (%dx),%al
f0100471:	ec                   	in     (%dx),%al
f0100472:	ec                   	in     (%dx),%al
f0100473:	89 f2                	mov    %esi,%edx
f0100475:	ec                   	in     (%dx),%al
f0100476:	a8 20                	test   $0x20,%al
f0100478:	75 05                	jne    f010047f <cons_putc+0x36>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f010047a:	83 eb 01             	sub    $0x1,%ebx
f010047d:	75 ee                	jne    f010046d <cons_putc+0x24>
	     i++)
		delay();
	
	outb(COM1 + COM_TX, c);
f010047f:	89 f8                	mov    %edi,%eax
f0100481:	0f b6 c0             	movzbl %al,%eax
f0100484:	89 45 e4             	mov    %eax,-0x1c(%ebp)
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100487:	ba f8 03 00 00       	mov    $0x3f8,%edx
f010048c:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010048d:	b2 79                	mov    $0x79,%dl
f010048f:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f0100490:	84 c0                	test   %al,%al
f0100492:	78 21                	js     f01004b5 <cons_putc+0x6c>
f0100494:	bb 00 32 00 00       	mov    $0x3200,%ebx
f0100499:	b9 84 00 00 00       	mov    $0x84,%ecx
f010049e:	be 79 03 00 00       	mov    $0x379,%esi
f01004a3:	89 ca                	mov    %ecx,%edx
f01004a5:	ec                   	in     (%dx),%al
f01004a6:	ec                   	in     (%dx),%al
f01004a7:	ec                   	in     (%dx),%al
f01004a8:	ec                   	in     (%dx),%al
f01004a9:	89 f2                	mov    %esi,%edx
f01004ab:	ec                   	in     (%dx),%al
f01004ac:	84 c0                	test   %al,%al
f01004ae:	78 05                	js     f01004b5 <cons_putc+0x6c>
f01004b0:	83 eb 01             	sub    $0x1,%ebx
f01004b3:	75 ee                	jne    f01004a3 <cons_putc+0x5a>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01004b5:	ba 78 03 00 00       	mov    $0x378,%edx
f01004ba:	0f b6 45 e4          	movzbl -0x1c(%ebp),%eax
f01004be:	ee                   	out    %al,(%dx)
f01004bf:	b2 7a                	mov    $0x7a,%dl
f01004c1:	b8 0d 00 00 00       	mov    $0xd,%eax
f01004c6:	ee                   	out    %al,(%dx)
f01004c7:	b8 08 00 00 00       	mov    $0x8,%eax
f01004cc:	ee                   	out    %al,(%dx)

static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f01004cd:	89 fa                	mov    %edi,%edx
f01004cf:	81 e2 00 ff ff ff    	and    $0xffffff00,%edx
		c |= 0x0700;
f01004d5:	89 f8                	mov    %edi,%eax
f01004d7:	80 cc 07             	or     $0x7,%ah
f01004da:	85 d2                	test   %edx,%edx
f01004dc:	0f 44 f8             	cmove  %eax,%edi

	switch (c & 0xff) {
f01004df:	89 f8                	mov    %edi,%eax
f01004e1:	0f b6 c0             	movzbl %al,%eax
f01004e4:	83 f8 09             	cmp    $0x9,%eax
f01004e7:	74 79                	je     f0100562 <cons_putc+0x119>
f01004e9:	83 f8 09             	cmp    $0x9,%eax
f01004ec:	7f 0a                	jg     f01004f8 <cons_putc+0xaf>
f01004ee:	83 f8 08             	cmp    $0x8,%eax
f01004f1:	74 19                	je     f010050c <cons_putc+0xc3>
f01004f3:	e9 9e 00 00 00       	jmp    f0100596 <cons_putc+0x14d>
f01004f8:	83 f8 0a             	cmp    $0xa,%eax
f01004fb:	90                   	nop
f01004fc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100500:	74 3a                	je     f010053c <cons_putc+0xf3>
f0100502:	83 f8 0d             	cmp    $0xd,%eax
f0100505:	74 3d                	je     f0100544 <cons_putc+0xfb>
f0100507:	e9 8a 00 00 00       	jmp    f0100596 <cons_putc+0x14d>
	case '\b':
		if (crt_pos > 0) {
f010050c:	0f b7 05 28 f2 21 f0 	movzwl 0xf021f228,%eax
f0100513:	66 85 c0             	test   %ax,%ax
f0100516:	0f 84 e5 00 00 00    	je     f0100601 <cons_putc+0x1b8>
			crt_pos--;
f010051c:	83 e8 01             	sub    $0x1,%eax
f010051f:	66 a3 28 f2 21 f0    	mov    %ax,0xf021f228
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100525:	0f b7 c0             	movzwl %ax,%eax
f0100528:	66 81 e7 00 ff       	and    $0xff00,%di
f010052d:	83 cf 20             	or     $0x20,%edi
f0100530:	8b 15 2c f2 21 f0    	mov    0xf021f22c,%edx
f0100536:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f010053a:	eb 78                	jmp    f01005b4 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f010053c:	66 83 05 28 f2 21 f0 	addw   $0x50,0xf021f228
f0100543:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f0100544:	0f b7 05 28 f2 21 f0 	movzwl 0xf021f228,%eax
f010054b:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100551:	c1 e8 16             	shr    $0x16,%eax
f0100554:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0100557:	c1 e0 04             	shl    $0x4,%eax
f010055a:	66 a3 28 f2 21 f0    	mov    %ax,0xf021f228
f0100560:	eb 52                	jmp    f01005b4 <cons_putc+0x16b>
		break;
	case '\t':
		cons_putc(' ');
f0100562:	b8 20 00 00 00       	mov    $0x20,%eax
f0100567:	e8 dd fe ff ff       	call   f0100449 <cons_putc>
		cons_putc(' ');
f010056c:	b8 20 00 00 00       	mov    $0x20,%eax
f0100571:	e8 d3 fe ff ff       	call   f0100449 <cons_putc>
		cons_putc(' ');
f0100576:	b8 20 00 00 00       	mov    $0x20,%eax
f010057b:	e8 c9 fe ff ff       	call   f0100449 <cons_putc>
		cons_putc(' ');
f0100580:	b8 20 00 00 00       	mov    $0x20,%eax
f0100585:	e8 bf fe ff ff       	call   f0100449 <cons_putc>
		cons_putc(' ');
f010058a:	b8 20 00 00 00       	mov    $0x20,%eax
f010058f:	e8 b5 fe ff ff       	call   f0100449 <cons_putc>
f0100594:	eb 1e                	jmp    f01005b4 <cons_putc+0x16b>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f0100596:	0f b7 05 28 f2 21 f0 	movzwl 0xf021f228,%eax
f010059d:	8d 50 01             	lea    0x1(%eax),%edx
f01005a0:	66 89 15 28 f2 21 f0 	mov    %dx,0xf021f228
f01005a7:	0f b7 c0             	movzwl %ax,%eax
f01005aa:	8b 15 2c f2 21 f0    	mov    0xf021f22c,%edx
f01005b0:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f01005b4:	66 81 3d 28 f2 21 f0 	cmpw   $0x7cf,0xf021f228
f01005bb:	cf 07 
f01005bd:	76 42                	jbe    f0100601 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f01005bf:	a1 2c f2 21 f0       	mov    0xf021f22c,%eax
f01005c4:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f01005cb:	00 
f01005cc:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f01005d2:	89 54 24 04          	mov    %edx,0x4(%esp)
f01005d6:	89 04 24             	mov    %eax,(%esp)
f01005d9:	e8 28 32 00 00       	call   f0103806 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f01005de:	8b 15 2c f2 21 f0    	mov    0xf021f22c,%edx
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f01005e4:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f01005e9:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f01005ef:	83 c0 01             	add    $0x1,%eax
f01005f2:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f01005f7:	75 f0                	jne    f01005e9 <cons_putc+0x1a0>
			crt_buf[i] = 0x0700 | ' ';
		crt_pos -= CRT_COLS;
f01005f9:	66 83 2d 28 f2 21 f0 	subw   $0x50,0xf021f228
f0100600:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100601:	8b 0d 30 f2 21 f0    	mov    0xf021f230,%ecx
f0100607:	b8 0e 00 00 00       	mov    $0xe,%eax
f010060c:	89 ca                	mov    %ecx,%edx
f010060e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010060f:	0f b7 1d 28 f2 21 f0 	movzwl 0xf021f228,%ebx
f0100616:	8d 71 01             	lea    0x1(%ecx),%esi
f0100619:	89 d8                	mov    %ebx,%eax
f010061b:	66 c1 e8 08          	shr    $0x8,%ax
f010061f:	89 f2                	mov    %esi,%edx
f0100621:	ee                   	out    %al,(%dx)
f0100622:	b8 0f 00 00 00       	mov    $0xf,%eax
f0100627:	89 ca                	mov    %ecx,%edx
f0100629:	ee                   	out    %al,(%dx)
f010062a:	89 d8                	mov    %ebx,%eax
f010062c:	89 f2                	mov    %esi,%edx
f010062e:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f010062f:	83 c4 1c             	add    $0x1c,%esp
f0100632:	5b                   	pop    %ebx
f0100633:	5e                   	pop    %esi
f0100634:	5f                   	pop    %edi
f0100635:	5d                   	pop    %ebp
f0100636:	c3                   	ret    

f0100637 <serial_intr>:
}

void
serial_intr(void)
{
	if (serial_exists)
f0100637:	83 3d 34 f2 21 f0 00 	cmpl   $0x0,0xf021f234
f010063e:	74 11                	je     f0100651 <serial_intr+0x1a>
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f0100640:	55                   	push   %ebp
f0100641:	89 e5                	mov    %esp,%ebp
f0100643:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
		cons_intr(serial_proc_data);
f0100646:	b8 e0 02 10 f0       	mov    $0xf01002e0,%eax
f010064b:	e8 ac fc ff ff       	call   f01002fc <cons_intr>
}
f0100650:	c9                   	leave  
f0100651:	f3 c3                	repz ret 

f0100653 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f0100653:	55                   	push   %ebp
f0100654:	89 e5                	mov    %esp,%ebp
f0100656:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f0100659:	b8 40 03 10 f0       	mov    $0xf0100340,%eax
f010065e:	e8 99 fc ff ff       	call   f01002fc <cons_intr>
}
f0100663:	c9                   	leave  
f0100664:	c3                   	ret    

f0100665 <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f0100665:	55                   	push   %ebp
f0100666:	89 e5                	mov    %esp,%ebp
f0100668:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f010066b:	e8 c7 ff ff ff       	call   f0100637 <serial_intr>
	kbd_intr();
f0100670:	e8 de ff ff ff       	call   f0100653 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f0100675:	a1 20 f2 21 f0       	mov    0xf021f220,%eax
f010067a:	3b 05 24 f2 21 f0    	cmp    0xf021f224,%eax
f0100680:	74 26                	je     f01006a8 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f0100682:	8d 50 01             	lea    0x1(%eax),%edx
f0100685:	89 15 20 f2 21 f0    	mov    %edx,0xf021f220
f010068b:	0f b6 88 20 f0 21 f0 	movzbl -0xfde0fe0(%eax),%ecx
		if (cons.rpos == CONSBUFSIZE)
			cons.rpos = 0;
		return c;
f0100692:	89 c8                	mov    %ecx,%eax
	kbd_intr();

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
		c = cons.buf[cons.rpos++];
		if (cons.rpos == CONSBUFSIZE)
f0100694:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f010069a:	75 11                	jne    f01006ad <cons_getc+0x48>
			cons.rpos = 0;
f010069c:	c7 05 20 f2 21 f0 00 	movl   $0x0,0xf021f220
f01006a3:	00 00 00 
f01006a6:	eb 05                	jmp    f01006ad <cons_getc+0x48>
		return c;
	}
	return 0;
f01006a8:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01006ad:	c9                   	leave  
f01006ae:	c3                   	ret    

f01006af <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f01006af:	55                   	push   %ebp
f01006b0:	89 e5                	mov    %esp,%ebp
f01006b2:	57                   	push   %edi
f01006b3:	56                   	push   %esi
f01006b4:	53                   	push   %ebx
f01006b5:	83 ec 1c             	sub    $0x1c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f01006b8:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f01006bf:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f01006c6:	5a a5 
	if (*cp != 0xA55A) {
f01006c8:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f01006cf:	66 3d 5a a5          	cmp    $0xa55a,%ax
f01006d3:	74 11                	je     f01006e6 <cons_init+0x37>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f01006d5:	c7 05 30 f2 21 f0 b4 	movl   $0x3b4,0xf021f230
f01006dc:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f01006df:	bf 00 00 0b f0       	mov    $0xf00b0000,%edi
f01006e4:	eb 16                	jmp    f01006fc <cons_init+0x4d>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f01006e6:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f01006ed:	c7 05 30 f2 21 f0 d4 	movl   $0x3d4,0xf021f230
f01006f4:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f01006f7:	bf 00 80 0b f0       	mov    $0xf00b8000,%edi
		*cp = was;
		addr_6845 = CGA_BASE;
	}
	
	/* Extract cursor location */
	outb(addr_6845, 14);
f01006fc:	8b 0d 30 f2 21 f0    	mov    0xf021f230,%ecx
f0100702:	b8 0e 00 00 00       	mov    $0xe,%eax
f0100707:	89 ca                	mov    %ecx,%edx
f0100709:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f010070a:	8d 59 01             	lea    0x1(%ecx),%ebx

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010070d:	89 da                	mov    %ebx,%edx
f010070f:	ec                   	in     (%dx),%al
f0100710:	0f b6 f0             	movzbl %al,%esi
f0100713:	c1 e6 08             	shl    $0x8,%esi
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100716:	b8 0f 00 00 00       	mov    $0xf,%eax
f010071b:	89 ca                	mov    %ecx,%edx
f010071d:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010071e:	89 da                	mov    %ebx,%edx
f0100720:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f0100721:	89 3d 2c f2 21 f0    	mov    %edi,0xf021f22c
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f0100727:	0f b6 d8             	movzbl %al,%ebx
f010072a:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f010072c:	66 89 35 28 f2 21 f0 	mov    %si,0xf021f228

static void
kbd_init(void)
{
	// Drain the kbd buffer so that Bochs generates interrupts.
	kbd_intr();
f0100733:	e8 1b ff ff ff       	call   f0100653 <kbd_intr>
	irq_setmask_8259A(irq_mask_8259A & ~(1<<1));
f0100738:	0f b7 05 88 c3 11 f0 	movzwl 0xf011c388,%eax
f010073f:	25 fd ff 00 00       	and    $0xfffd,%eax
f0100744:	89 04 24             	mov    %eax,(%esp)
f0100747:	e8 d3 17 00 00       	call   f0101f1f <irq_setmask_8259A>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010074c:	be fa 03 00 00       	mov    $0x3fa,%esi
f0100751:	b8 00 00 00 00       	mov    $0x0,%eax
f0100756:	89 f2                	mov    %esi,%edx
f0100758:	ee                   	out    %al,(%dx)
f0100759:	b2 fb                	mov    $0xfb,%dl
f010075b:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f0100760:	ee                   	out    %al,(%dx)
f0100761:	bb f8 03 00 00       	mov    $0x3f8,%ebx
f0100766:	b8 0c 00 00 00       	mov    $0xc,%eax
f010076b:	89 da                	mov    %ebx,%edx
f010076d:	ee                   	out    %al,(%dx)
f010076e:	b2 f9                	mov    $0xf9,%dl
f0100770:	b8 00 00 00 00       	mov    $0x0,%eax
f0100775:	ee                   	out    %al,(%dx)
f0100776:	b2 fb                	mov    $0xfb,%dl
f0100778:	b8 03 00 00 00       	mov    $0x3,%eax
f010077d:	ee                   	out    %al,(%dx)
f010077e:	b2 fc                	mov    $0xfc,%dl
f0100780:	b8 00 00 00 00       	mov    $0x0,%eax
f0100785:	ee                   	out    %al,(%dx)
f0100786:	b2 f9                	mov    $0xf9,%dl
f0100788:	b8 01 00 00 00       	mov    $0x1,%eax
f010078d:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010078e:	b2 fd                	mov    $0xfd,%dl
f0100790:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f0100791:	3c ff                	cmp    $0xff,%al
f0100793:	0f 95 c1             	setne  %cl
f0100796:	0f b6 c9             	movzbl %cl,%ecx
f0100799:	89 0d 34 f2 21 f0    	mov    %ecx,0xf021f234
f010079f:	89 f2                	mov    %esi,%edx
f01007a1:	ec                   	in     (%dx),%al
f01007a2:	89 da                	mov    %ebx,%edx
f01007a4:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f01007a5:	85 c9                	test   %ecx,%ecx
f01007a7:	75 0c                	jne    f01007b5 <cons_init+0x106>
		cprintf("Serial port does not exist!\n");
f01007a9:	c7 04 24 2f 46 10 f0 	movl   $0xf010462f,(%esp)
f01007b0:	e8 ac 18 00 00       	call   f0102061 <cprintf>
}
f01007b5:	83 c4 1c             	add    $0x1c,%esp
f01007b8:	5b                   	pop    %ebx
f01007b9:	5e                   	pop    %esi
f01007ba:	5f                   	pop    %edi
f01007bb:	5d                   	pop    %ebp
f01007bc:	c3                   	ret    

f01007bd <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f01007bd:	55                   	push   %ebp
f01007be:	89 e5                	mov    %esp,%ebp
f01007c0:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f01007c3:	8b 45 08             	mov    0x8(%ebp),%eax
f01007c6:	e8 7e fc ff ff       	call   f0100449 <cons_putc>
}
f01007cb:	c9                   	leave  
f01007cc:	c3                   	ret    

f01007cd <getchar>:

int
getchar(void)
{
f01007cd:	55                   	push   %ebp
f01007ce:	89 e5                	mov    %esp,%ebp
f01007d0:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f01007d3:	e8 8d fe ff ff       	call   f0100665 <cons_getc>
f01007d8:	85 c0                	test   %eax,%eax
f01007da:	74 f7                	je     f01007d3 <getchar+0x6>
		/* do nothing */;
	return c;
}
f01007dc:	c9                   	leave  
f01007dd:	c3                   	ret    

f01007de <iscons>:

int
iscons(int fdnum)
{
f01007de:	55                   	push   %ebp
f01007df:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f01007e1:	b8 01 00 00 00       	mov    $0x1,%eax
f01007e6:	5d                   	pop    %ebp
f01007e7:	c3                   	ret    
f01007e8:	66 90                	xchg   %ax,%ax
f01007ea:	66 90                	xchg   %ax,%ax
f01007ec:	66 90                	xchg   %ax,%ax
f01007ee:	66 90                	xchg   %ax,%ax

f01007f0 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f01007f0:	55                   	push   %ebp
f01007f1:	89 e5                	mov    %esp,%ebp
f01007f3:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < NCOMMANDS; i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f01007f6:	c7 44 24 08 80 48 10 	movl   $0xf0104880,0x8(%esp)
f01007fd:	f0 
f01007fe:	c7 44 24 04 9e 48 10 	movl   $0xf010489e,0x4(%esp)
f0100805:	f0 
f0100806:	c7 04 24 a3 48 10 f0 	movl   $0xf01048a3,(%esp)
f010080d:	e8 4f 18 00 00       	call   f0102061 <cprintf>
f0100812:	c7 44 24 08 40 49 10 	movl   $0xf0104940,0x8(%esp)
f0100819:	f0 
f010081a:	c7 44 24 04 ac 48 10 	movl   $0xf01048ac,0x4(%esp)
f0100821:	f0 
f0100822:	c7 04 24 a3 48 10 f0 	movl   $0xf01048a3,(%esp)
f0100829:	e8 33 18 00 00       	call   f0102061 <cprintf>
f010082e:	c7 44 24 08 68 49 10 	movl   $0xf0104968,0x8(%esp)
f0100835:	f0 
f0100836:	c7 44 24 04 b5 48 10 	movl   $0xf01048b5,0x4(%esp)
f010083d:	f0 
f010083e:	c7 04 24 a3 48 10 f0 	movl   $0xf01048a3,(%esp)
f0100845:	e8 17 18 00 00       	call   f0102061 <cprintf>
	return 0;
}
f010084a:	b8 00 00 00 00       	mov    $0x0,%eax
f010084f:	c9                   	leave  
f0100850:	c3                   	ret    

f0100851 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f0100851:	55                   	push   %ebp
f0100852:	89 e5                	mov    %esp,%ebp
f0100854:	83 ec 18             	sub    $0x18,%esp
	extern char entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f0100857:	c7 04 24 bf 48 10 f0 	movl   $0xf01048bf,(%esp)
f010085e:	e8 fe 17 00 00       	call   f0102061 <cprintf>
	cprintf(" this is work 1 insert:\n");
f0100863:	c7 04 24 d8 48 10 f0 	movl   $0xf01048d8,(%esp)
f010086a:	e8 f2 17 00 00       	call   f0102061 <cprintf>
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
f010086f:	c7 44 24 08 0f 00 00 	movl   $0xf,0x8(%esp)
f0100876:	00 
f0100877:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
f010087e:	00 
f010087f:	c7 04 24 94 49 10 f0 	movl   $0xf0104994,(%esp)
f0100886:	e8 d6 17 00 00       	call   f0102061 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
f010088b:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f0100892:	00 
f0100893:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f010089a:	f0 
f010089b:	c7 04 24 cc 49 10 f0 	movl   $0xf01049cc,(%esp)
f01008a2:	e8 ba 17 00 00       	call   f0102061 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01008a7:	c7 44 24 08 47 45 10 	movl   $0x104547,0x8(%esp)
f01008ae:	00 
f01008af:	c7 44 24 04 47 45 10 	movl   $0xf0104547,0x4(%esp)
f01008b6:	f0 
f01008b7:	c7 04 24 f4 49 10 f0 	movl   $0xf01049f4,(%esp)
f01008be:	e8 9e 17 00 00       	call   f0102061 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01008c3:	c7 44 24 08 58 e4 21 	movl   $0x21e458,0x8(%esp)
f01008ca:	00 
f01008cb:	c7 44 24 04 58 e4 21 	movl   $0xf021e458,0x4(%esp)
f01008d2:	f0 
f01008d3:	c7 04 24 18 4a 10 f0 	movl   $0xf0104a18,(%esp)
f01008da:	e8 82 17 00 00       	call   f0102061 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f01008df:	c7 44 24 08 04 10 26 	movl   $0x261004,0x8(%esp)
f01008e6:	00 
f01008e7:	c7 44 24 04 04 10 26 	movl   $0xf0261004,0x4(%esp)
f01008ee:	f0 
f01008ef:	c7 04 24 3c 4a 10 f0 	movl   $0xf0104a3c,(%esp)
f01008f6:	e8 66 17 00 00       	call   f0102061 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f01008fb:	b8 03 14 26 f0       	mov    $0xf0261403,%eax
f0100900:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f0100905:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f010090b:	85 c0                	test   %eax,%eax
f010090d:	0f 48 c2             	cmovs  %edx,%eax
f0100910:	c1 f8 0a             	sar    $0xa,%eax
f0100913:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100917:	c7 04 24 60 4a 10 f0 	movl   $0xf0104a60,(%esp)
f010091e:	e8 3e 17 00 00       	call   f0102061 <cprintf>
		(end-entry+1023)/1024);
	return 0;
}
f0100923:	b8 00 00 00 00       	mov    $0x0,%eax
f0100928:	c9                   	leave  
f0100929:	c3                   	ret    

f010092a <mon_backtrace>:
int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f010092a:	55                   	push   %ebp
f010092b:	89 e5                	mov    %esp,%ebp
f010092d:	56                   	push   %esi
f010092e:	53                   	push   %ebx
f010092f:	83 ec 40             	sub    $0x40,%esp
	// Your code here
	cprintf("start backtrace\n");
f0100932:	c7 04 24 f1 48 10 f0 	movl   $0xf01048f1,(%esp)
f0100939:	e8 23 17 00 00       	call   f0102061 <cprintf>
	cprintf("\n");
f010093e:	c7 04 24 2d 46 10 f0 	movl   $0xf010462d,(%esp)
f0100945:	e8 17 17 00 00       	call   f0102061 <cprintf>

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f010094a:	89 e8                	mov    %ebp,%eax
f010094c:	89 c1                	mov    %eax,%ecx
	uint32_t eip;
	uint32_t ebp = read_ebp();
	uint32_t esp;
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
f010094e:	83 f8 ff             	cmp    $0xffffffff,%eax
f0100951:	74 63                	je     f01009b6 <mon_backtrace+0x8c>
		esp = ebp+8;
		eip = *(uint32_t*)(ebp+4);
f0100953:	8b 71 04             	mov    0x4(%ecx),%esi
		if(ebp==0){
			ebp = -1;
f0100956:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
		esp = ebp+8;
		eip = *(uint32_t*)(ebp+4);
		if(ebp==0){
f010095b:	85 c9                	test   %ecx,%ecx
f010095d:	74 02                	je     f0100961 <mon_backtrace+0x37>
			ebp = -1;
		}else{
			ebp = *(uint32_t*)(ebp);
f010095f:	8b 19                	mov    (%ecx),%ebx
		}
		for(i=0;i<5;i++){
f0100961:	b8 00 00 00 00       	mov    $0x0,%eax
		args[i] = *(uint32_t*)(esp+i*4);
f0100966:	8b 54 81 08          	mov    0x8(%ecx,%eax,4),%edx
f010096a:	89 54 85 e4          	mov    %edx,-0x1c(%ebp,%eax,4)
		if(ebp==0){
			ebp = -1;
		}else{
			ebp = *(uint32_t*)(ebp);
		}
		for(i=0;i<5;i++){
f010096e:	83 c0 01             	add    $0x1,%eax
f0100971:	83 f8 05             	cmp    $0x5,%eax
f0100974:	75 f0                	jne    f0100966 <mon_backtrace+0x3c>
		args[i] = *(uint32_t*)(esp+i*4);
	        }
                            cprintf("ebp  %08x   eip %08x   args  %08x  %08x  %08x  %08x  %08x\n",ebp,eip,args[0],args[1],args[2],args[3],args[4]);
f0100976:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0100979:	89 44 24 1c          	mov    %eax,0x1c(%esp)
f010097d:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0100980:	89 44 24 18          	mov    %eax,0x18(%esp)
f0100984:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0100987:	89 44 24 14          	mov    %eax,0x14(%esp)
f010098b:	8b 45 e8             	mov    -0x18(%ebp),%eax
f010098e:	89 44 24 10          	mov    %eax,0x10(%esp)
f0100992:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100995:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100999:	89 74 24 08          	mov    %esi,0x8(%esp)
f010099d:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01009a1:	c7 04 24 8c 4a 10 f0 	movl   $0xf0104a8c,(%esp)
f01009a8:	e8 b4 16 00 00       	call   f0102061 <cprintf>
	uint32_t eip;
	uint32_t ebp = read_ebp();
	uint32_t esp;
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
f01009ad:	83 fb ff             	cmp    $0xffffffff,%ebx
f01009b0:	74 04                	je     f01009b6 <mon_backtrace+0x8c>
f01009b2:	89 d9                	mov    %ebx,%ecx
f01009b4:	eb 9d                	jmp    f0100953 <mon_backtrace+0x29>
                            cprintf("ebp  %08x   eip %08x   args  %08x  %08x  %08x  %08x  %08x\n",ebp,eip,args[0],args[1],args[2],args[3],args[4]);

	}
	
	return 0;
}
f01009b6:	b8 00 00 00 00       	mov    $0x0,%eax
f01009bb:	83 c4 40             	add    $0x40,%esp
f01009be:	5b                   	pop    %ebx
f01009bf:	5e                   	pop    %esi
f01009c0:	5d                   	pop    %ebp
f01009c1:	c3                   	ret    

f01009c2 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f01009c2:	55                   	push   %ebp
f01009c3:	89 e5                	mov    %esp,%ebp
f01009c5:	57                   	push   %edi
f01009c6:	56                   	push   %esi
f01009c7:	53                   	push   %ebx
f01009c8:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f01009cb:	c7 04 24 c8 4a 10 f0 	movl   $0xf0104ac8,(%esp)
f01009d2:	e8 8a 16 00 00       	call   f0102061 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f01009d7:	c7 04 24 ec 4a 10 f0 	movl   $0xf0104aec,(%esp)
f01009de:	e8 7e 16 00 00       	call   f0102061 <cprintf>

	if (tf != NULL)
f01009e3:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f01009e7:	74 0b                	je     f01009f4 <monitor+0x32>
		print_trapframe(tf);
f01009e9:	8b 45 08             	mov    0x8(%ebp),%eax
f01009ec:	89 04 24             	mov    %eax,(%esp)
f01009ef:	e8 a0 1a 00 00       	call   f0102494 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f01009f4:	c7 04 24 02 49 10 f0 	movl   $0xf0104902,(%esp)
f01009fb:	e8 e0 2a 00 00       	call   f01034e0 <readline>
f0100a00:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f0100a02:	85 c0                	test   %eax,%eax
f0100a04:	74 ee                	je     f01009f4 <monitor+0x32>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f0100a06:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f0100a0d:	be 00 00 00 00       	mov    $0x0,%esi
f0100a12:	eb 0a                	jmp    f0100a1e <monitor+0x5c>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f0100a14:	c6 03 00             	movb   $0x0,(%ebx)
f0100a17:	89 f7                	mov    %esi,%edi
f0100a19:	8d 5b 01             	lea    0x1(%ebx),%ebx
f0100a1c:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f0100a1e:	0f b6 03             	movzbl (%ebx),%eax
f0100a21:	84 c0                	test   %al,%al
f0100a23:	74 6a                	je     f0100a8f <monitor+0xcd>
f0100a25:	0f be c0             	movsbl %al,%eax
f0100a28:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a2c:	c7 04 24 06 49 10 f0 	movl   $0xf0104906,(%esp)
f0100a33:	e8 21 2d 00 00       	call   f0103759 <strchr>
f0100a38:	85 c0                	test   %eax,%eax
f0100a3a:	75 d8                	jne    f0100a14 <monitor+0x52>
			*buf++ = 0;
		if (*buf == 0)
f0100a3c:	80 3b 00             	cmpb   $0x0,(%ebx)
f0100a3f:	74 4e                	je     f0100a8f <monitor+0xcd>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f0100a41:	83 fe 0f             	cmp    $0xf,%esi
f0100a44:	75 16                	jne    f0100a5c <monitor+0x9a>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f0100a46:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f0100a4d:	00 
f0100a4e:	c7 04 24 0b 49 10 f0 	movl   $0xf010490b,(%esp)
f0100a55:	e8 07 16 00 00       	call   f0102061 <cprintf>
f0100a5a:	eb 98                	jmp    f01009f4 <monitor+0x32>
			return 0;
		}
		argv[argc++] = buf;
f0100a5c:	8d 7e 01             	lea    0x1(%esi),%edi
f0100a5f:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f0100a63:	0f b6 03             	movzbl (%ebx),%eax
f0100a66:	84 c0                	test   %al,%al
f0100a68:	75 0c                	jne    f0100a76 <monitor+0xb4>
f0100a6a:	eb b0                	jmp    f0100a1c <monitor+0x5a>
			buf++;
f0100a6c:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f0100a6f:	0f b6 03             	movzbl (%ebx),%eax
f0100a72:	84 c0                	test   %al,%al
f0100a74:	74 a6                	je     f0100a1c <monitor+0x5a>
f0100a76:	0f be c0             	movsbl %al,%eax
f0100a79:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a7d:	c7 04 24 06 49 10 f0 	movl   $0xf0104906,(%esp)
f0100a84:	e8 d0 2c 00 00       	call   f0103759 <strchr>
f0100a89:	85 c0                	test   %eax,%eax
f0100a8b:	74 df                	je     f0100a6c <monitor+0xaa>
f0100a8d:	eb 8d                	jmp    f0100a1c <monitor+0x5a>
			buf++;
	}
	argv[argc] = 0;
f0100a8f:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f0100a96:	00 

	// Lookup and invoke the command
	if (argc == 0)
f0100a97:	85 f6                	test   %esi,%esi
f0100a99:	0f 84 55 ff ff ff    	je     f01009f4 <monitor+0x32>
f0100a9f:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100aa4:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f0100aa7:	8b 04 85 20 4b 10 f0 	mov    -0xfefb4e0(,%eax,4),%eax
f0100aae:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100ab2:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100ab5:	89 04 24             	mov    %eax,(%esp)
f0100ab8:	e8 18 2c 00 00       	call   f01036d5 <strcmp>
f0100abd:	85 c0                	test   %eax,%eax
f0100abf:	75 24                	jne    f0100ae5 <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100ac1:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100ac4:	8b 55 08             	mov    0x8(%ebp),%edx
f0100ac7:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100acb:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100ace:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100ad2:	89 34 24             	mov    %esi,(%esp)
f0100ad5:	ff 14 85 28 4b 10 f0 	call   *-0xfefb4d8(,%eax,4)
		print_trapframe(tf);

	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f0100adc:	85 c0                	test   %eax,%eax
f0100ade:	78 25                	js     f0100b05 <monitor+0x143>
f0100ae0:	e9 0f ff ff ff       	jmp    f01009f4 <monitor+0x32>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
f0100ae5:	83 c3 01             	add    $0x1,%ebx
f0100ae8:	83 fb 03             	cmp    $0x3,%ebx
f0100aeb:	75 b7                	jne    f0100aa4 <monitor+0xe2>
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f0100aed:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100af0:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100af4:	c7 04 24 28 49 10 f0 	movl   $0xf0104928,(%esp)
f0100afb:	e8 61 15 00 00       	call   f0102061 <cprintf>
f0100b00:	e9 ef fe ff ff       	jmp    f01009f4 <monitor+0x32>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f0100b05:	83 c4 5c             	add    $0x5c,%esp
f0100b08:	5b                   	pop    %ebx
f0100b09:	5e                   	pop    %esi
f0100b0a:	5f                   	pop    %edi
f0100b0b:	5d                   	pop    %ebp
f0100b0c:	c3                   	ret    

f0100b0d <read_eip>:
// return EIP of caller.
// does not work if inlined.
// putting at the end of the file seems to prevent inlining.
unsigned
read_eip()
{
f0100b0d:	55                   	push   %ebp
f0100b0e:	89 e5                	mov    %esp,%ebp
	uint32_t callerpc;
	__asm __volatile("movl 4(%%ebp), %0" : "=r" (callerpc));
f0100b10:	8b 45 04             	mov    0x4(%ebp),%eax
	return callerpc;
}
f0100b13:	5d                   	pop    %ebp
f0100b14:	c3                   	ret    
f0100b15:	66 90                	xchg   %ax,%ax
f0100b17:	66 90                	xchg   %ax,%ax
f0100b19:	66 90                	xchg   %ax,%ax
f0100b1b:	66 90                	xchg   %ax,%ax
f0100b1d:	66 90                	xchg   %ax,%ax
f0100b1f:	90                   	nop

f0100b20 <boot_alloc>:
// If we're out of memory, boot_alloc should panic.
// This function may ONLY be used during initialization,
// before the page_free_list list has been set up.
static void *
boot_alloc(uint32_t n)
{
f0100b20:	55                   	push   %ebp
f0100b21:	89 e5                	mov    %esp,%ebp
f0100b23:	53                   	push   %ebx
f0100b24:	83 ec 14             	sub    $0x14,%esp
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f0100b27:	83 3d 38 f2 21 f0 00 	cmpl   $0x0,0xf021f238
f0100b2e:	75 36                	jne    f0100b66 <boot_alloc+0x46>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100b30:	ba 03 20 26 f0       	mov    $0xf0262003,%edx
f0100b35:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0100b3b:	89 15 38 f2 21 f0    	mov    %edx,0xf021f238
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f0100b41:	85 c0                	test   %eax,%eax
f0100b43:	74 19                	je     f0100b5e <boot_alloc+0x3e>
                      result = nextfree;
f0100b45:	8b 1d 38 f2 21 f0    	mov    0xf021f238,%ebx
                      nextfree += ROUNDUP(n, PGSIZE);
f0100b4b:	05 ff 0f 00 00       	add    $0xfff,%eax
f0100b50:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100b55:	01 d8                	add    %ebx,%eax
f0100b57:	a3 38 f2 21 f0       	mov    %eax,0xf021f238
f0100b5c:	eb 0e                	jmp    f0100b6c <boot_alloc+0x4c>
               } else if (n == 0)
                      result = nextfree;
f0100b5e:	8b 1d 38 f2 21 f0    	mov    0xf021f238,%ebx
f0100b64:	eb 06                	jmp    f0100b6c <boot_alloc+0x4c>
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f0100b66:	85 c0                	test   %eax,%eax
f0100b68:	74 f4                	je     f0100b5e <boot_alloc+0x3e>
f0100b6a:	eb d9                	jmp    f0100b45 <boot_alloc+0x25>
                      nextfree += ROUNDUP(n, PGSIZE);
               } else if (n == 0)
                      result = nextfree;
              else
                      result = NULL;
              cprintf(">>  boot_alloc() was called! Entry(virtual address) of new page is: %x\n\n", (int)result);
f0100b6c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100b70:	c7 04 24 44 4b 10 f0 	movl   $0xf0104b44,(%esp)
f0100b77:	e8 e5 14 00 00       	call   f0102061 <cprintf>
              return result;
   
	//return NULL;
}
f0100b7c:	89 d8                	mov    %ebx,%eax
f0100b7e:	83 c4 14             	add    $0x14,%esp
f0100b81:	5b                   	pop    %ebx
f0100b82:	5d                   	pop    %ebp
f0100b83:	c3                   	ret    

f0100b84 <check_va2pa>:
static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
f0100b84:	89 d1                	mov    %edx,%ecx
f0100b86:	c1 e9 16             	shr    $0x16,%ecx
	if (!(*pgdir & PTE_P))
f0100b89:	8b 04 88             	mov    (%eax,%ecx,4),%eax
f0100b8c:	a8 01                	test   $0x1,%al
f0100b8e:	74 5d                	je     f0100bed <check_va2pa+0x69>
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
f0100b90:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100b95:	89 c1                	mov    %eax,%ecx
f0100b97:	c1 e9 0c             	shr    $0xc,%ecx
f0100b9a:	3b 0d 08 ff 21 f0    	cmp    0xf021ff08,%ecx
f0100ba0:	72 26                	jb     f0100bc8 <check_va2pa+0x44>
// this functionality for us!  We define our own version to help check
// the check_kern_pgdir() function; it shouldn't be used elsewhere.

static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
f0100ba2:	55                   	push   %ebp
f0100ba3:	89 e5                	mov    %esp,%ebp
f0100ba5:	83 ec 18             	sub    $0x18,%esp
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100ba8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100bac:	c7 44 24 08 84 45 10 	movl   $0xf0104584,0x8(%esp)
f0100bb3:	f0 
f0100bb4:	c7 44 24 04 7d 03 00 	movl   $0x37d,0x4(%esp)
f0100bbb:	00 
f0100bbc:	c7 04 24 e9 4c 10 f0 	movl   $0xf0104ce9,(%esp)
f0100bc3:	e8 78 f4 ff ff       	call   f0100040 <_panic>

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
f0100bc8:	c1 ea 0c             	shr    $0xc,%edx
f0100bcb:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f0100bd1:	8b 84 90 00 00 00 f0 	mov    -0x10000000(%eax,%edx,4),%eax
f0100bd8:	89 c2                	mov    %eax,%edx
f0100bda:	83 e2 01             	and    $0x1,%edx
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
f0100bdd:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100be2:	85 d2                	test   %edx,%edx
f0100be4:	ba ff ff ff ff       	mov    $0xffffffff,%edx
f0100be9:	0f 44 c2             	cmove  %edx,%eax
f0100bec:	c3                   	ret    
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
f0100bed:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
}
f0100bf2:	c3                   	ret    

f0100bf3 <check_page_free_list>:
//
// Check that the pages on the page_free_list are reasonable.
//
static void
check_page_free_list(bool only_low_memory)
{
f0100bf3:	55                   	push   %ebp
f0100bf4:	89 e5                	mov    %esp,%ebp
f0100bf6:	57                   	push   %edi
f0100bf7:	56                   	push   %esi
f0100bf8:	53                   	push   %ebx
f0100bf9:	83 ec 3c             	sub    $0x3c,%esp
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100bfc:	85 c0                	test   %eax,%eax
f0100bfe:	0f 85 7a 03 00 00    	jne    f0100f7e <check_page_free_list+0x38b>
f0100c04:	e9 87 03 00 00       	jmp    f0100f90 <check_page_free_list+0x39d>
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
		panic("'page_free_list' is a null pointer!");
f0100c09:	c7 44 24 08 90 4b 10 	movl   $0xf0104b90,0x8(%esp)
f0100c10:	f0 
f0100c11:	c7 44 24 04 ae 02 00 	movl   $0x2ae,0x4(%esp)
f0100c18:	00 
f0100c19:	c7 04 24 e9 4c 10 f0 	movl   $0xf0104ce9,(%esp)
f0100c20:	e8 1b f4 ff ff       	call   f0100040 <_panic>

	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
f0100c25:	8d 55 d8             	lea    -0x28(%ebp),%edx
f0100c28:	89 55 e0             	mov    %edx,-0x20(%ebp)
f0100c2b:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100c2e:	89 55 e4             	mov    %edx,-0x1c(%ebp)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100c31:	89 c2                	mov    %eax,%edx
f0100c33:	2b 15 10 ff 21 f0    	sub    0xf021ff10,%edx
		for (pp = page_free_list; pp; pp = pp->pp_link) {
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
f0100c39:	f7 c2 00 e0 7f 00    	test   $0x7fe000,%edx
f0100c3f:	0f 95 c2             	setne  %dl
f0100c42:	0f b6 d2             	movzbl %dl,%edx
			*tp[pagetype] = pp;
f0100c45:	8b 4c 95 e0          	mov    -0x20(%ebp,%edx,4),%ecx
f0100c49:	89 01                	mov    %eax,(%ecx)
			tp[pagetype] = &pp->pp_link;
f0100c4b:	89 44 95 e0          	mov    %eax,-0x20(%ebp,%edx,4)
	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
		for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100c4f:	8b 00                	mov    (%eax),%eax
f0100c51:	85 c0                	test   %eax,%eax
f0100c53:	75 dc                	jne    f0100c31 <check_page_free_list+0x3e>
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
			*tp[pagetype] = pp;
			tp[pagetype] = &pp->pp_link;
		}
		*tp[1] = 0;
f0100c55:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100c58:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		*tp[0] = pp2;
f0100c5e:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100c61:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100c64:	89 10                	mov    %edx,(%eax)
		page_free_list = pp1;
f0100c66:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100c69:	a3 40 f2 21 f0       	mov    %eax,0xf021f240
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100c6e:	89 c3                	mov    %eax,%ebx
f0100c70:	85 c0                	test   %eax,%eax
f0100c72:	74 6c                	je     f0100ce0 <check_page_free_list+0xed>
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100c74:	be 01 00 00 00       	mov    $0x1,%esi
f0100c79:	89 d8                	mov    %ebx,%eax
f0100c7b:	2b 05 10 ff 21 f0    	sub    0xf021ff10,%eax
f0100c81:	c1 f8 03             	sar    $0x3,%eax
f0100c84:	c1 e0 0c             	shl    $0xc,%eax
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
f0100c87:	89 c2                	mov    %eax,%edx
f0100c89:	c1 ea 16             	shr    $0x16,%edx
f0100c8c:	39 d6                	cmp    %edx,%esi
f0100c8e:	76 4a                	jbe    f0100cda <check_page_free_list+0xe7>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100c90:	89 c2                	mov    %eax,%edx
f0100c92:	c1 ea 0c             	shr    $0xc,%edx
f0100c95:	3b 15 08 ff 21 f0    	cmp    0xf021ff08,%edx
f0100c9b:	72 20                	jb     f0100cbd <check_page_free_list+0xca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100c9d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100ca1:	c7 44 24 08 84 45 10 	movl   $0xf0104584,0x8(%esp)
f0100ca8:	f0 
f0100ca9:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100cb0:	00 
f0100cb1:	c7 04 24 f5 4c 10 f0 	movl   $0xf0104cf5,(%esp)
f0100cb8:	e8 83 f3 ff ff       	call   f0100040 <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100cbd:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100cc4:	00 
f0100cc5:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100ccc:	00 
	return (void *)(pa + KERNBASE);
f0100ccd:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100cd2:	89 04 24             	mov    %eax,(%esp)
f0100cd5:	e8 df 2a 00 00       	call   f01037b9 <memset>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100cda:	8b 1b                	mov    (%ebx),%ebx
f0100cdc:	85 db                	test   %ebx,%ebx
f0100cde:	75 99                	jne    f0100c79 <check_page_free_list+0x86>
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
f0100ce0:	b8 00 00 00 00       	mov    $0x0,%eax
f0100ce5:	e8 36 fe ff ff       	call   f0100b20 <boot_alloc>
f0100cea:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100ced:	8b 15 40 f2 21 f0    	mov    0xf021f240,%edx
f0100cf3:	85 d2                	test   %edx,%edx
f0100cf5:	0f 84 3b 02 00 00    	je     f0100f36 <check_page_free_list+0x343>
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100cfb:	8b 35 10 ff 21 f0    	mov    0xf021ff10,%esi
f0100d01:	39 f2                	cmp    %esi,%edx
f0100d03:	72 3d                	jb     f0100d42 <check_page_free_list+0x14f>
		assert(pp < pages + npages);
f0100d05:	8b 3d 08 ff 21 f0    	mov    0xf021ff08,%edi
f0100d0b:	8d 04 fe             	lea    (%esi,%edi,8),%eax
f0100d0e:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0100d11:	39 c2                	cmp    %eax,%edx
f0100d13:	73 56                	jae    f0100d6b <check_page_free_list+0x178>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100d15:	89 75 cc             	mov    %esi,-0x34(%ebp)
f0100d18:	89 d0                	mov    %edx,%eax
f0100d1a:	29 f0                	sub    %esi,%eax
f0100d1c:	a8 07                	test   $0x7,%al
f0100d1e:	75 78                	jne    f0100d98 <check_page_free_list+0x1a5>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100d20:	c1 f8 03             	sar    $0x3,%eax
f0100d23:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100d26:	85 c0                	test   %eax,%eax
f0100d28:	0f 84 98 00 00 00    	je     f0100dc6 <check_page_free_list+0x1d3>
		assert(page2pa(pp) != IOPHYSMEM);
f0100d2e:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100d33:	0f 85 dc 00 00 00    	jne    f0100e15 <check_page_free_list+0x222>
f0100d39:	e9 b3 00 00 00       	jmp    f0100df1 <check_page_free_list+0x1fe>
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d3e:	39 d6                	cmp    %edx,%esi
f0100d40:	76 24                	jbe    f0100d66 <check_page_free_list+0x173>
f0100d42:	c7 44 24 0c 03 4d 10 	movl   $0xf0104d03,0xc(%esp)
f0100d49:	f0 
f0100d4a:	c7 44 24 08 0f 4d 10 	movl   $0xf0104d0f,0x8(%esp)
f0100d51:	f0 
f0100d52:	c7 44 24 04 c8 02 00 	movl   $0x2c8,0x4(%esp)
f0100d59:	00 
f0100d5a:	c7 04 24 e9 4c 10 f0 	movl   $0xf0104ce9,(%esp)
f0100d61:	e8 da f2 ff ff       	call   f0100040 <_panic>
		assert(pp < pages + npages);
f0100d66:	3b 55 d0             	cmp    -0x30(%ebp),%edx
f0100d69:	72 24                	jb     f0100d8f <check_page_free_list+0x19c>
f0100d6b:	c7 44 24 0c 24 4d 10 	movl   $0xf0104d24,0xc(%esp)
f0100d72:	f0 
f0100d73:	c7 44 24 08 0f 4d 10 	movl   $0xf0104d0f,0x8(%esp)
f0100d7a:	f0 
f0100d7b:	c7 44 24 04 c9 02 00 	movl   $0x2c9,0x4(%esp)
f0100d82:	00 
f0100d83:	c7 04 24 e9 4c 10 f0 	movl   $0xf0104ce9,(%esp)
f0100d8a:	e8 b1 f2 ff ff       	call   f0100040 <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100d8f:	89 d0                	mov    %edx,%eax
f0100d91:	2b 45 cc             	sub    -0x34(%ebp),%eax
f0100d94:	a8 07                	test   $0x7,%al
f0100d96:	74 24                	je     f0100dbc <check_page_free_list+0x1c9>
f0100d98:	c7 44 24 0c b4 4b 10 	movl   $0xf0104bb4,0xc(%esp)
f0100d9f:	f0 
f0100da0:	c7 44 24 08 0f 4d 10 	movl   $0xf0104d0f,0x8(%esp)
f0100da7:	f0 
f0100da8:	c7 44 24 04 ca 02 00 	movl   $0x2ca,0x4(%esp)
f0100daf:	00 
f0100db0:	c7 04 24 e9 4c 10 f0 	movl   $0xf0104ce9,(%esp)
f0100db7:	e8 84 f2 ff ff       	call   f0100040 <_panic>
f0100dbc:	c1 f8 03             	sar    $0x3,%eax
f0100dbf:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100dc2:	85 c0                	test   %eax,%eax
f0100dc4:	75 24                	jne    f0100dea <check_page_free_list+0x1f7>
f0100dc6:	c7 44 24 0c 38 4d 10 	movl   $0xf0104d38,0xc(%esp)
f0100dcd:	f0 
f0100dce:	c7 44 24 08 0f 4d 10 	movl   $0xf0104d0f,0x8(%esp)
f0100dd5:	f0 
f0100dd6:	c7 44 24 04 cd 02 00 	movl   $0x2cd,0x4(%esp)
f0100ddd:	00 
f0100dde:	c7 04 24 e9 4c 10 f0 	movl   $0xf0104ce9,(%esp)
f0100de5:	e8 56 f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100dea:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100def:	75 2b                	jne    f0100e1c <check_page_free_list+0x229>
f0100df1:	c7 44 24 0c 49 4d 10 	movl   $0xf0104d49,0xc(%esp)
f0100df8:	f0 
f0100df9:	c7 44 24 08 0f 4d 10 	movl   $0xf0104d0f,0x8(%esp)
f0100e00:	f0 
f0100e01:	c7 44 24 04 ce 02 00 	movl   $0x2ce,0x4(%esp)
f0100e08:	00 
f0100e09:	c7 04 24 e9 4c 10 f0 	movl   $0xf0104ce9,(%esp)
f0100e10:	e8 2b f2 ff ff       	call   f0100040 <_panic>
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
f0100e15:	c7 45 c8 00 00 00 00 	movl   $0x0,-0x38(%ebp)
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
f0100e1c:	3d 00 f0 0f 00       	cmp    $0xff000,%eax
f0100e21:	75 24                	jne    f0100e47 <check_page_free_list+0x254>
f0100e23:	c7 44 24 0c e8 4b 10 	movl   $0xf0104be8,0xc(%esp)
f0100e2a:	f0 
f0100e2b:	c7 44 24 08 0f 4d 10 	movl   $0xf0104d0f,0x8(%esp)
f0100e32:	f0 
f0100e33:	c7 44 24 04 cf 02 00 	movl   $0x2cf,0x4(%esp)
f0100e3a:	00 
f0100e3b:	c7 04 24 e9 4c 10 f0 	movl   $0xf0104ce9,(%esp)
f0100e42:	e8 f9 f1 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100e47:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100e4c:	75 24                	jne    f0100e72 <check_page_free_list+0x27f>
f0100e4e:	c7 44 24 0c 62 4d 10 	movl   $0xf0104d62,0xc(%esp)
f0100e55:	f0 
f0100e56:	c7 44 24 08 0f 4d 10 	movl   $0xf0104d0f,0x8(%esp)
f0100e5d:	f0 
f0100e5e:	c7 44 24 04 d0 02 00 	movl   $0x2d0,0x4(%esp)
f0100e65:	00 
f0100e66:	c7 04 24 e9 4c 10 f0 	movl   $0xf0104ce9,(%esp)
f0100e6d:	e8 ce f1 ff ff       	call   f0100040 <_panic>
f0100e72:	89 c1                	mov    %eax,%ecx
		assert(page2pa(pp) < EXTPHYSMEM );
f0100e74:	3d ff ff 0f 00       	cmp    $0xfffff,%eax
f0100e79:	76 24                	jbe    f0100e9f <check_page_free_list+0x2ac>
f0100e7b:	c7 44 24 0c 7c 4d 10 	movl   $0xf0104d7c,0xc(%esp)
f0100e82:	f0 
f0100e83:	c7 44 24 08 0f 4d 10 	movl   $0xf0104d0f,0x8(%esp)
f0100e8a:	f0 
f0100e8b:	c7 44 24 04 d1 02 00 	movl   $0x2d1,0x4(%esp)
f0100e92:	00 
f0100e93:	c7 04 24 e9 4c 10 f0 	movl   $0xf0104ce9,(%esp)
f0100e9a:	e8 a1 f1 ff ff       	call   f0100040 <_panic>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100e9f:	89 c3                	mov    %eax,%ebx
f0100ea1:	c1 eb 0c             	shr    $0xc,%ebx
f0100ea4:	39 df                	cmp    %ebx,%edi
f0100ea6:	77 20                	ja     f0100ec8 <check_page_free_list+0x2d5>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100ea8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100eac:	c7 44 24 08 84 45 10 	movl   $0xf0104584,0x8(%esp)
f0100eb3:	f0 
f0100eb4:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100ebb:	00 
f0100ebc:	c7 04 24 f5 4c 10 f0 	movl   $0xf0104cf5,(%esp)
f0100ec3:	e8 78 f1 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0100ec8:	81 e9 00 00 00 10    	sub    $0x10000000,%ecx
		assert((char *) page2kva(pp) >= first_free_page);
f0100ece:	39 4d d4             	cmp    %ecx,-0x2c(%ebp)
f0100ed1:	76 24                	jbe    f0100ef7 <check_page_free_list+0x304>
f0100ed3:	c7 44 24 0c 0c 4c 10 	movl   $0xf0104c0c,0xc(%esp)
f0100eda:	f0 
f0100edb:	c7 44 24 08 0f 4d 10 	movl   $0xf0104d0f,0x8(%esp)
f0100ee2:	f0 
f0100ee3:	c7 44 24 04 d2 02 00 	movl   $0x2d2,0x4(%esp)
f0100eea:	00 
f0100eeb:	c7 04 24 e9 4c 10 f0 	movl   $0xf0104ce9,(%esp)
f0100ef2:	e8 49 f1 ff ff       	call   f0100040 <_panic>
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100ef7:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100efc:	75 24                	jne    f0100f22 <check_page_free_list+0x32f>
f0100efe:	c7 44 24 0c 95 4d 10 	movl   $0xf0104d95,0xc(%esp)
f0100f05:	f0 
f0100f06:	c7 44 24 08 0f 4d 10 	movl   $0xf0104d0f,0x8(%esp)
f0100f0d:	f0 
f0100f0e:	c7 44 24 04 d4 02 00 	movl   $0x2d4,0x4(%esp)
f0100f15:	00 
f0100f16:	c7 04 24 e9 4c 10 f0 	movl   $0xf0104ce9,(%esp)
f0100f1d:	e8 1e f1 ff ff       	call   f0100040 <_panic>

		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
f0100f22:	83 45 c8 01          	addl   $0x1,-0x38(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100f26:	8b 12                	mov    (%edx),%edx
f0100f28:	85 d2                	test   %edx,%edx
f0100f2a:	0f 85 0e fe ff ff    	jne    f0100d3e <check_page_free_list+0x14b>
			++nfree_basemem;
		else
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
f0100f30:	83 7d c8 00          	cmpl   $0x0,-0x38(%ebp)
f0100f34:	7f 24                	jg     f0100f5a <check_page_free_list+0x367>
f0100f36:	c7 44 24 0c b2 4d 10 	movl   $0xf0104db2,0xc(%esp)
f0100f3d:	f0 
f0100f3e:	c7 44 24 08 0f 4d 10 	movl   $0xf0104d0f,0x8(%esp)
f0100f45:	f0 
f0100f46:	c7 44 24 04 dc 02 00 	movl   $0x2dc,0x4(%esp)
f0100f4d:	00 
f0100f4e:	c7 04 24 e9 4c 10 f0 	movl   $0xf0104ce9,(%esp)
f0100f55:	e8 e6 f0 ff ff       	call   f0100040 <_panic>
	assert(nfree_extmem > 0);
f0100f5a:	c7 44 24 0c c4 4d 10 	movl   $0xf0104dc4,0xc(%esp)
f0100f61:	f0 
f0100f62:	c7 44 24 08 0f 4d 10 	movl   $0xf0104d0f,0x8(%esp)
f0100f69:	f0 
f0100f6a:	c7 44 24 04 dd 02 00 	movl   $0x2dd,0x4(%esp)
f0100f71:	00 
f0100f72:	c7 04 24 e9 4c 10 f0 	movl   $0xf0104ce9,(%esp)
f0100f79:	e8 c2 f0 ff ff       	call   f0100040 <_panic>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100f7e:	a1 40 f2 21 f0       	mov    0xf021f240,%eax
f0100f83:	85 c0                	test   %eax,%eax
f0100f85:	0f 85 9a fc ff ff    	jne    f0100c25 <check_page_free_list+0x32>
f0100f8b:	e9 79 fc ff ff       	jmp    f0100c09 <check_page_free_list+0x16>
f0100f90:	83 3d 40 f2 21 f0 00 	cmpl   $0x0,0xf021f240
f0100f97:	0f 84 6c fc ff ff    	je     f0100c09 <check_page_free_list+0x16>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100f9d:	8b 1d 40 f2 21 f0    	mov    0xf021f240,%ebx
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100fa3:	be 00 04 00 00       	mov    $0x400,%esi
f0100fa8:	e9 cc fc ff ff       	jmp    f0100c79 <check_page_free_list+0x86>

f0100fad <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0100fad:	55                   	push   %ebp
f0100fae:	89 e5                	mov    %esp,%ebp
f0100fb0:	53                   	push   %ebx
f0100fb1:	83 ec 14             	sub    $0x14,%esp
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100fb4:	83 3d 08 ff 21 f0 00 	cmpl   $0x0,0xf021ff08
f0100fbb:	0f 84 3e 01 00 00    	je     f01010ff <page_init+0x152>
f0100fc1:	8b 1d 40 f2 21 f0    	mov    0xf021f240,%ebx
f0100fc7:	b8 00 00 00 00       	mov    $0x0,%eax
f0100fcc:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
		pages[i].pp_ref = 0;
f0100fd3:	89 d1                	mov    %edx,%ecx
f0100fd5:	03 0d 10 ff 21 f0    	add    0xf021ff10,%ecx
f0100fdb:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0100fe1:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f0100fe3:	03 15 10 ff 21 f0    	add    0xf021ff10,%edx
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100fe9:	83 c0 01             	add    $0x1,%eax
f0100fec:	8b 0d 08 ff 21 f0    	mov    0xf021ff08,%ecx
f0100ff2:	39 c1                	cmp    %eax,%ecx
f0100ff4:	76 04                	jbe    f0100ffa <page_init+0x4d>
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f0100ff6:	89 d3                	mov    %edx,%ebx
f0100ff8:	eb d2                	jmp    f0100fcc <page_init+0x1f>
f0100ffa:	89 15 40 f2 21 f0    	mov    %edx,0xf021f240
	}

	//remove physical page 0 from page_free_list
             pages[1].pp_link = NULL;
f0101000:	a1 10 ff 21 f0       	mov    0xf021ff10,%eax
f0101005:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010100c:	81 f9 a0 00 00 00    	cmp    $0xa0,%ecx
f0101012:	77 1c                	ja     f0101030 <page_init+0x83>
		panic("pa2page called with invalid pa");
f0101014:	c7 44 24 08 38 4c 10 	movl   $0xf0104c38,0x8(%esp)
f010101b:	f0 
f010101c:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101023:	00 
f0101024:	c7 04 24 f5 4c 10 f0 	movl   $0xf0104cf5,(%esp)
f010102b:	e8 10 f0 ff ff       	call   f0100040 <_panic>

              //remove continuous pages from page_free_list
              extern char end[];                        //this is an *virtual* address
              struct Page *ppg_start = pa2page((physaddr_t)IOPHYSMEM);                                                //at low *physical* address
              struct Page *ppg_end = pa2page((physaddr_t)((end - KERNBASE) + PGSIZE + sizeof(struct Page)*npages)+sizeof(struct Env)*NENV);    //at high *physical* address
f0101030:	8d 14 cd 04 10 28 00 	lea    0x281004(,%ecx,8),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101037:	c1 ea 0c             	shr    $0xc,%edx
f010103a:	39 ca                	cmp    %ecx,%edx
f010103c:	72 1c                	jb     f010105a <page_init+0xad>
		panic("pa2page called with invalid pa");
f010103e:	c7 44 24 08 38 4c 10 	movl   $0xf0104c38,0x8(%esp)
f0101045:	f0 
f0101046:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010104d:	00 
f010104e:	c7 04 24 f5 4c 10 f0 	movl   $0xf0104cf5,(%esp)
f0101055:	e8 e6 ef ff ff       	call   f0100040 <_panic>

              //test output
             //cprintf(">>  ppg_start: %x\tppg_end: %x\n", (int)ppg_start, (int)ppg_end);
               ppg_start--;    ppg_end++;
f010105a:	8d 98 f8 04 00 00    	lea    0x4f8(%eax),%ebx
f0101060:	89 5c d0 08          	mov    %ebx,0x8(%eax,%edx,8)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101064:	83 f9 07             	cmp    $0x7,%ecx
f0101067:	77 1c                	ja     f0101085 <page_init+0xd8>
		panic("pa2page called with invalid pa");
f0101069:	c7 44 24 08 38 4c 10 	movl   $0xf0104c38,0x8(%esp)
f0101070:	f0 
f0101071:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101078:	00 
f0101079:	c7 04 24 f5 4c 10 f0 	movl   $0xf0104cf5,(%esp)
f0101080:	e8 bb ef ff ff       	call   f0100040 <_panic>
               ppg_end->pp_link = ppg_start;

               //remain the page of mp entry Code
               extern unsigned char mpentry_start[], mpentry_end[];
               ppg_start = pa2page((physaddr_t)MPENTRY_PADDR);      
               ppg_end = pa2page((physaddr_t)(MPENTRY_PADDR+mpentry_end - mpentry_start));  
f0101085:	ba 66 aa 10 f0       	mov    $0xf010aa66,%edx
f010108a:	81 ea ec 39 10 f0    	sub    $0xf01039ec,%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101090:	c1 ea 0c             	shr    $0xc,%edx
f0101093:	39 d1                	cmp    %edx,%ecx
f0101095:	77 1c                	ja     f01010b3 <page_init+0x106>
		panic("pa2page called with invalid pa");
f0101097:	c7 44 24 08 38 4c 10 	movl   $0xf0104c38,0x8(%esp)
f010109e:	f0 
f010109f:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01010a6:	00 
f01010a7:	c7 04 24 f5 4c 10 f0 	movl   $0xf0104cf5,(%esp)
f01010ae:	e8 8d ef ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f01010b3:	8d 1c d0             	lea    (%eax,%edx,8),%ebx
               ppg_start--;    ppg_end++;
f01010b6:	83 c0 30             	add    $0x30,%eax
               ppg_end->pp_link = ppg_start;
f01010b9:	89 43 08             	mov    %eax,0x8(%ebx)

               cprintf("MPENTRY_PADDR_page_start:  %d\n",PGNUM(page2pa(ppg_start)));
f01010bc:	c7 44 24 04 06 00 00 	movl   $0x6,0x4(%esp)
f01010c3:	00 
f01010c4:	c7 04 24 58 4c 10 f0 	movl   $0xf0104c58,(%esp)
f01010cb:	e8 91 0f 00 00       	call   f0102061 <cprintf>

               //remain the page of mp entry Code
               extern unsigned char mpentry_start[], mpentry_end[];
               ppg_start = pa2page((physaddr_t)MPENTRY_PADDR);      
               ppg_end = pa2page((physaddr_t)(MPENTRY_PADDR+mpentry_end - mpentry_start));  
               ppg_start--;    ppg_end++;
f01010d0:	8d 43 08             	lea    0x8(%ebx),%eax
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01010d3:	2b 05 10 ff 21 f0    	sub    0xf021ff10,%eax
f01010d9:	c1 f8 03             	sar    $0x3,%eax
               ppg_end->pp_link = ppg_start;

               cprintf("MPENTRY_PADDR_page_start:  %d\n",PGNUM(page2pa(ppg_start)));
               cprintf("MPENTRY_PADDR_page_end:  %d\n",PGNUM(page2pa(ppg_end)));
f01010dc:	25 ff ff 0f 00       	and    $0xfffff,%eax
f01010e1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01010e5:	c7 04 24 d5 4d 10 f0 	movl   $0xf0104dd5,(%esp)
f01010ec:	e8 70 0f 00 00       	call   f0102061 <cprintf>
               cprintf("\n");
f01010f1:	c7 04 24 2d 46 10 f0 	movl   $0xf010462d,(%esp)
f01010f8:	e8 64 0f 00 00       	call   f0102061 <cprintf>
f01010fd:	eb 11                	jmp    f0101110 <page_init+0x163>
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
	}

	//remove physical page 0 from page_free_list
             pages[1].pp_link = NULL;
f01010ff:	a1 10 ff 21 f0       	mov    0xf021ff10,%eax
f0101104:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
f010110b:	e9 04 ff ff ff       	jmp    f0101014 <page_init+0x67>
               ppg_end->pp_link = ppg_start;

               cprintf("MPENTRY_PADDR_page_start:  %d\n",PGNUM(page2pa(ppg_start)));
               cprintf("MPENTRY_PADDR_page_end:  %d\n",PGNUM(page2pa(ppg_end)));
               cprintf("\n");
}
f0101110:	83 c4 14             	add    $0x14,%esp
f0101113:	5b                   	pop    %ebx
f0101114:	5d                   	pop    %ebp
f0101115:	c3                   	ret    

f0101116 <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
f0101116:	55                   	push   %ebp
f0101117:	89 e5                	mov    %esp,%ebp
f0101119:	53                   	push   %ebx
f010111a:	83 ec 14             	sub    $0x14,%esp
	//test output
              //cprintf(">>  page_alloc() was called!\n");

             if (page_free_list == NULL)
f010111d:	8b 1d 40 f2 21 f0    	mov    0xf021f240,%ebx
f0101123:	85 db                	test   %ebx,%ebx
f0101125:	74 69                	je     f0101190 <page_alloc+0x7a>
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
f0101127:	8b 03                	mov    (%ebx),%eax
f0101129:	a3 40 f2 21 f0       	mov    %eax,0xf021f240
    
             if (alloc_flags & ALLOC_ZERO)
                    memset(page2kva(result), 0, PGSIZE);
        
             return result;
f010112e:	89 d8                	mov    %ebx,%eax
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
    
             if (alloc_flags & ALLOC_ZERO)
f0101130:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f0101134:	74 5f                	je     f0101195 <page_alloc+0x7f>
f0101136:	2b 05 10 ff 21 f0    	sub    0xf021ff10,%eax
f010113c:	c1 f8 03             	sar    $0x3,%eax
f010113f:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101142:	89 c2                	mov    %eax,%edx
f0101144:	c1 ea 0c             	shr    $0xc,%edx
f0101147:	3b 15 08 ff 21 f0    	cmp    0xf021ff08,%edx
f010114d:	72 20                	jb     f010116f <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010114f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101153:	c7 44 24 08 84 45 10 	movl   $0xf0104584,0x8(%esp)
f010115a:	f0 
f010115b:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101162:	00 
f0101163:	c7 04 24 f5 4c 10 f0 	movl   $0xf0104cf5,(%esp)
f010116a:	e8 d1 ee ff ff       	call   f0100040 <_panic>
                    memset(page2kva(result), 0, PGSIZE);
f010116f:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101176:	00 
f0101177:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010117e:	00 
	return (void *)(pa + KERNBASE);
f010117f:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101184:	89 04 24             	mov    %eax,(%esp)
f0101187:	e8 2d 26 00 00       	call   f01037b9 <memset>
        
             return result;
f010118c:	89 d8                	mov    %ebx,%eax
f010118e:	eb 05                	jmp    f0101195 <page_alloc+0x7f>
{
	//test output
              //cprintf(">>  page_alloc() was called!\n");

             if (page_free_list == NULL)
                             return NULL;
f0101190:	b8 00 00 00 00       	mov    $0x0,%eax
    
             if (alloc_flags & ALLOC_ZERO)
                    memset(page2kva(result), 0, PGSIZE);
        
             return result;
}
f0101195:	83 c4 14             	add    $0x14,%esp
f0101198:	5b                   	pop    %ebx
f0101199:	5d                   	pop    %ebp
f010119a:	c3                   	ret    

f010119b <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct Page *pp)
{
f010119b:	55                   	push   %ebp
f010119c:	89 e5                	mov    %esp,%ebp
f010119e:	8b 45 08             	mov    0x8(%ebp),%eax
	pp->pp_link = page_free_list;
f01011a1:	8b 15 40 f2 21 f0    	mov    0xf021f240,%edx
f01011a7:	89 10                	mov    %edx,(%eax)
              page_free_list = pp;
f01011a9:	a3 40 f2 21 f0       	mov    %eax,0xf021f240
	// Fill this function in
}
f01011ae:	5d                   	pop    %ebp
f01011af:	c3                   	ret    

f01011b0 <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct Page* pp)
{
f01011b0:	55                   	push   %ebp
f01011b1:	89 e5                	mov    %esp,%ebp
f01011b3:	83 ec 04             	sub    $0x4,%esp
f01011b6:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f01011b9:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f01011bd:	8d 51 ff             	lea    -0x1(%ecx),%edx
f01011c0:	66 89 50 04          	mov    %dx,0x4(%eax)
f01011c4:	66 85 d2             	test   %dx,%dx
f01011c7:	75 08                	jne    f01011d1 <page_decref+0x21>
		page_free(pp);
f01011c9:	89 04 24             	mov    %eax,(%esp)
f01011cc:	e8 ca ff ff ff       	call   f010119b <page_free>
}
f01011d1:	c9                   	leave  
f01011d2:	c3                   	ret    

f01011d3 <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f01011d3:	55                   	push   %ebp
f01011d4:	89 e5                	mov    %esp,%ebp
f01011d6:	56                   	push   %esi
f01011d7:	53                   	push   %ebx
f01011d8:	83 ec 10             	sub    $0x10,%esp
f01011db:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	// Fill this function in
	//test output
              //cprintf(">>  pgdir_walk() was called!\n");

             pte_t *result;
            if (pgdir[PDX(va)] == (pte_t)NULL) {            //yet to create
f01011de:	89 de                	mov    %ebx,%esi
f01011e0:	c1 ee 16             	shr    $0x16,%esi
f01011e3:	c1 e6 02             	shl    $0x2,%esi
f01011e6:	03 75 08             	add    0x8(%ebp),%esi
f01011e9:	8b 06                	mov    (%esi),%eax
f01011eb:	85 c0                	test   %eax,%eax
f01011ed:	75 76                	jne    f0101265 <pgdir_walk+0x92>
                      if (create == 0)
f01011ef:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f01011f3:	0f 84 d1 00 00 00    	je     f01012ca <pgdir_walk+0xf7>
                                        return NULL;
                     else {
                                        struct Page *tmp = page_alloc(ALLOC_ZERO);
f01011f9:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101200:	e8 11 ff ff ff       	call   f0101116 <page_alloc>
                                        if (tmp == NULL)
f0101205:	85 c0                	test   %eax,%eax
f0101207:	0f 84 c4 00 00 00    	je     f01012d1 <pgdir_walk+0xfe>
                                                  return NULL;                        //failed to alloc
                                        else {
                                                  tmp->pp_ref++;
f010120d:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101212:	89 c2                	mov    %eax,%edx
f0101214:	2b 15 10 ff 21 f0    	sub    0xf021ff10,%edx
f010121a:	c1 fa 03             	sar    $0x3,%edx
f010121d:	c1 e2 0c             	shl    $0xc,%edx
                                                  pgdir[PDX(va)] = page2pa(tmp) | PTE_P | PTE_W |PTE_U;    //save the physical address of newly allocated page in page dir
f0101220:	83 ca 07             	or     $0x7,%edx
f0101223:	89 16                	mov    %edx,(%esi)
f0101225:	2b 05 10 ff 21 f0    	sub    0xf021ff10,%eax
f010122b:	c1 f8 03             	sar    $0x3,%eax
f010122e:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101231:	89 c2                	mov    %eax,%edx
f0101233:	c1 ea 0c             	shr    $0xc,%edx
f0101236:	3b 15 08 ff 21 f0    	cmp    0xf021ff08,%edx
f010123c:	72 20                	jb     f010125e <pgdir_walk+0x8b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010123e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101242:	c7 44 24 08 84 45 10 	movl   $0xf0104584,0x8(%esp)
f0101249:	f0 
f010124a:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101251:	00 
f0101252:	c7 04 24 f5 4c 10 f0 	movl   $0xf0104cf5,(%esp)
f0101259:	e8 e2 ed ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f010125e:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101263:	eb 58                	jmp    f01012bd <pgdir_walk+0xea>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101265:	c1 e8 0c             	shr    $0xc,%eax
f0101268:	8b 15 08 ff 21 f0    	mov    0xf021ff08,%edx
f010126e:	39 d0                	cmp    %edx,%eax
f0101270:	72 1c                	jb     f010128e <pgdir_walk+0xbb>
		panic("pa2page called with invalid pa");
f0101272:	c7 44 24 08 38 4c 10 	movl   $0xf0104c38,0x8(%esp)
f0101279:	f0 
f010127a:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101281:	00 
f0101282:	c7 04 24 f5 4c 10 f0 	movl   $0xf0104cf5,(%esp)
f0101289:	e8 b2 ed ff ff       	call   f0100040 <_panic>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010128e:	89 c1                	mov    %eax,%ecx
f0101290:	c1 e1 0c             	shl    $0xc,%ecx
f0101293:	39 d0                	cmp    %edx,%eax
f0101295:	72 20                	jb     f01012b7 <pgdir_walk+0xe4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101297:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f010129b:	c7 44 24 08 84 45 10 	movl   $0xf0104584,0x8(%esp)
f01012a2:	f0 
f01012a3:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01012aa:	00 
f01012ab:	c7 04 24 f5 4c 10 f0 	movl   $0xf0104cf5,(%esp)
f01012b2:	e8 89 ed ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01012b7:	8d 81 00 00 00 f0    	lea    -0x10000000(%ecx),%eax
                                  }
                 }
               else                        
               result = page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
        
               return &result[PTX(va)];
f01012bd:	c1 eb 0a             	shr    $0xa,%ebx
f01012c0:	81 e3 fc 0f 00 00    	and    $0xffc,%ebx
f01012c6:	01 d8                	add    %ebx,%eax
f01012c8:	eb 0c                	jmp    f01012d6 <pgdir_walk+0x103>
              //cprintf(">>  pgdir_walk() was called!\n");

             pte_t *result;
            if (pgdir[PDX(va)] == (pte_t)NULL) {            //yet to create
                      if (create == 0)
                                        return NULL;
f01012ca:	b8 00 00 00 00       	mov    $0x0,%eax
f01012cf:	eb 05                	jmp    f01012d6 <pgdir_walk+0x103>
                     else {
                                        struct Page *tmp = page_alloc(ALLOC_ZERO);
                                        if (tmp == NULL)
                                                  return NULL;                        //failed to alloc
f01012d1:	b8 00 00 00 00       	mov    $0x0,%eax
                 }
               else                        
               result = page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
        
               return &result[PTX(va)];
}
f01012d6:	83 c4 10             	add    $0x10,%esp
f01012d9:	5b                   	pop    %ebx
f01012da:	5e                   	pop    %esi
f01012db:	5d                   	pop    %ebp
f01012dc:	c3                   	ret    

f01012dd <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f01012dd:	55                   	push   %ebp
f01012de:	89 e5                	mov    %esp,%ebp
f01012e0:	53                   	push   %ebx
f01012e1:	83 ec 14             	sub    $0x14,%esp
f01012e4:	8b 5d 10             	mov    0x10(%ebp),%ebx
	// Fill this function in
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
f01012e7:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01012ee:	00 
f01012ef:	8b 45 0c             	mov    0xc(%ebp),%eax
f01012f2:	89 44 24 04          	mov    %eax,0x4(%esp)
f01012f6:	8b 45 08             	mov    0x8(%ebp),%eax
f01012f9:	89 04 24             	mov    %eax,(%esp)
f01012fc:	e8 d2 fe ff ff       	call   f01011d3 <pgdir_walk>
              if (pte == NULL)
f0101301:	85 c0                	test   %eax,%eax
f0101303:	74 3a                	je     f010133f <page_lookup+0x62>
                       return NULL;

             if (pte_store != 0)
f0101305:	85 db                	test   %ebx,%ebx
f0101307:	74 02                	je     f010130b <page_lookup+0x2e>
                     *pte_store = pte;
f0101309:	89 03                	mov    %eax,(%ebx)

             return pa2page(PTE_ADDR(pte[0]));
f010130b:	8b 00                	mov    (%eax),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010130d:	c1 e8 0c             	shr    $0xc,%eax
f0101310:	3b 05 08 ff 21 f0    	cmp    0xf021ff08,%eax
f0101316:	72 1c                	jb     f0101334 <page_lookup+0x57>
		panic("pa2page called with invalid pa");
f0101318:	c7 44 24 08 38 4c 10 	movl   $0xf0104c38,0x8(%esp)
f010131f:	f0 
f0101320:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101327:	00 
f0101328:	c7 04 24 f5 4c 10 f0 	movl   $0xf0104cf5,(%esp)
f010132f:	e8 0c ed ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0101334:	8b 15 10 ff 21 f0    	mov    0xf021ff10,%edx
f010133a:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f010133d:	eb 05                	jmp    f0101344 <page_lookup+0x67>
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
              if (pte == NULL)
                       return NULL;
f010133f:	b8 00 00 00 00       	mov    $0x0,%eax

             if (pte_store != 0)
                     *pte_store = pte;

             return pa2page(PTE_ADDR(pte[0]));
}
f0101344:	83 c4 14             	add    $0x14,%esp
f0101347:	5b                   	pop    %ebx
f0101348:	5d                   	pop    %ebp
f0101349:	c3                   	ret    

f010134a <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f010134a:	55                   	push   %ebp
f010134b:	89 e5                	mov    %esp,%ebp
f010134d:	83 ec 08             	sub    $0x8,%esp
	// Flush the entry only if we're modifying the current address space.
	if (!curenv || curenv->env_pgdir == pgdir)
f0101350:	e8 fe 2a 00 00       	call   f0103e53 <cpunum>
f0101355:	6b c0 74             	imul   $0x74,%eax,%eax
f0101358:	83 b8 28 00 22 f0 00 	cmpl   $0x0,-0xfddffd8(%eax)
f010135f:	74 16                	je     f0101377 <tlb_invalidate+0x2d>
f0101361:	e8 ed 2a 00 00       	call   f0103e53 <cpunum>
f0101366:	6b c0 74             	imul   $0x74,%eax,%eax
f0101369:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f010136f:	8b 55 08             	mov    0x8(%ebp),%edx
f0101372:	39 50 60             	cmp    %edx,0x60(%eax)
f0101375:	75 06                	jne    f010137d <tlb_invalidate+0x33>
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f0101377:	8b 45 0c             	mov    0xc(%ebp),%eax
f010137a:	0f 01 38             	invlpg (%eax)
		invlpg(va);
}
f010137d:	c9                   	leave  
f010137e:	c3                   	ret    

f010137f <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f010137f:	55                   	push   %ebp
f0101380:	89 e5                	mov    %esp,%ebp
f0101382:	56                   	push   %esi
f0101383:	53                   	push   %ebx
f0101384:	83 ec 20             	sub    $0x20,%esp
f0101387:	8b 5d 08             	mov    0x8(%ebp),%ebx
f010138a:	8b 75 0c             	mov    0xc(%ebp),%esi
	// Fill this function in
	//test output
               //cprintf(">>  page_remove() was called!\n");
    
              pte_t *pte;
              struct Page *page = page_lookup(pgdir, va, &pte);
f010138d:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0101390:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101394:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101398:	89 1c 24             	mov    %ebx,(%esp)
f010139b:	e8 3d ff ff ff       	call   f01012dd <page_lookup>
    
              if (page != NULL)
f01013a0:	85 c0                	test   %eax,%eax
f01013a2:	74 08                	je     f01013ac <page_remove+0x2d>
                         page_decref(page);
f01013a4:	89 04 24             	mov    %eax,(%esp)
f01013a7:	e8 04 fe ff ff       	call   f01011b0 <page_decref>
        
              pte[0] = 0;
f01013ac:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01013af:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
              tlb_invalidate(pgdir, va);
f01013b5:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013b9:	89 1c 24             	mov    %ebx,(%esp)
f01013bc:	e8 89 ff ff ff       	call   f010134a <tlb_invalidate>
}
f01013c1:	83 c4 20             	add    $0x20,%esp
f01013c4:	5b                   	pop    %ebx
f01013c5:	5e                   	pop    %esi
f01013c6:	5d                   	pop    %ebp
f01013c7:	c3                   	ret    

f01013c8 <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
{
f01013c8:	55                   	push   %ebp
f01013c9:	89 e5                	mov    %esp,%ebp
f01013cb:	57                   	push   %edi
f01013cc:	56                   	push   %esi
f01013cd:	53                   	push   %ebx
f01013ce:	83 ec 1c             	sub    $0x1c,%esp
f01013d1:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01013d4:	8b 75 10             	mov    0x10(%ebp),%esi
	// Fill this function in
	//test output
                                //cprintf(">>  page_insert() was called!\n");
    
               struct Page *page = page_lookup(pgdir, va, NULL);
f01013d7:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01013de:	00 
f01013df:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013e3:	8b 45 08             	mov    0x8(%ebp),%eax
f01013e6:	89 04 24             	mov    %eax,(%esp)
f01013e9:	e8 ef fe ff ff       	call   f01012dd <page_lookup>
f01013ee:	89 c7                	mov    %eax,%edi
               pte_t *pte;
    
              if (page == pp) {                       //re-insert into the same place
f01013f0:	39 d8                	cmp    %ebx,%eax
f01013f2:	75 36                	jne    f010142a <page_insert+0x62>
                            pte = pgdir_walk(pgdir, va, 0);
f01013f4:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01013fb:	00 
f01013fc:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101400:	8b 45 08             	mov    0x8(%ebp),%eax
f0101403:	89 04 24             	mov    %eax,(%esp)
f0101406:	e8 c8 fd ff ff       	call   f01011d3 <pgdir_walk>
                            pte[0] = page2pa(pp) | perm | PTE_P;
f010140b:	8b 4d 14             	mov    0x14(%ebp),%ecx
f010140e:	83 c9 01             	or     $0x1,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101411:	2b 3d 10 ff 21 f0    	sub    0xf021ff10,%edi
f0101417:	c1 ff 03             	sar    $0x3,%edi
f010141a:	c1 e7 0c             	shl    $0xc,%edi
f010141d:	89 fa                	mov    %edi,%edx
f010141f:	09 ca                	or     %ecx,%edx
f0101421:	89 10                	mov    %edx,(%eax)
                            return 0;
f0101423:	b8 00 00 00 00       	mov    $0x0,%eax
f0101428:	eb 57                	jmp    f0101481 <page_insert+0xb9>
                          }
    
               if (page != NULL)                       //remove original page if existed
f010142a:	85 c0                	test   %eax,%eax
f010142c:	74 0f                	je     f010143d <page_insert+0x75>
                        page_remove(pgdir, va);
f010142e:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101432:	8b 45 08             	mov    0x8(%ebp),%eax
f0101435:	89 04 24             	mov    %eax,(%esp)
f0101438:	e8 42 ff ff ff       	call   f010137f <page_remove>
        
              pte = pgdir_walk(pgdir, va, 1);
f010143d:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0101444:	00 
f0101445:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101449:	8b 45 08             	mov    0x8(%ebp),%eax
f010144c:	89 04 24             	mov    %eax,(%esp)
f010144f:	e8 7f fd ff ff       	call   f01011d3 <pgdir_walk>
              if (pte == NULL)
f0101454:	85 c0                	test   %eax,%eax
f0101456:	74 24                	je     f010147c <page_insert+0xb4>
                       return -E_NO_MEM;

              pte[0] = page2pa(pp) | perm | PTE_P;
f0101458:	8b 4d 14             	mov    0x14(%ebp),%ecx
f010145b:	83 c9 01             	or     $0x1,%ecx
f010145e:	89 da                	mov    %ebx,%edx
f0101460:	2b 15 10 ff 21 f0    	sub    0xf021ff10,%edx
f0101466:	c1 fa 03             	sar    $0x3,%edx
f0101469:	c1 e2 0c             	shl    $0xc,%edx
f010146c:	09 ca                	or     %ecx,%edx
f010146e:	89 10                	mov    %edx,(%eax)
               pp->pp_ref++;
f0101470:	66 83 43 04 01       	addw   $0x1,0x4(%ebx)

	return 0; 
f0101475:	b8 00 00 00 00       	mov    $0x0,%eax
f010147a:	eb 05                	jmp    f0101481 <page_insert+0xb9>
               if (page != NULL)                       //remove original page if existed
                        page_remove(pgdir, va);
        
              pte = pgdir_walk(pgdir, va, 1);
              if (pte == NULL)
                       return -E_NO_MEM;
f010147c:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax

              pte[0] = page2pa(pp) | perm | PTE_P;
               pp->pp_ref++;

	return 0; 
}
f0101481:	83 c4 1c             	add    $0x1c,%esp
f0101484:	5b                   	pop    %ebx
f0101485:	5e                   	pop    %esi
f0101486:	5f                   	pop    %edi
f0101487:	5d                   	pop    %ebp
f0101488:	c3                   	ret    

f0101489 <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f0101489:	55                   	push   %ebp
f010148a:	89 e5                	mov    %esp,%ebp
f010148c:	53                   	push   %ebx
f010148d:	83 ec 14             	sub    $0x14,%esp
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0101490:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f0101497:	e8 59 0a 00 00       	call   f0101ef5 <mc146818_read>
f010149c:	89 c3                	mov    %eax,%ebx
f010149e:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f01014a5:	e8 4b 0a 00 00       	call   f0101ef5 <mc146818_read>
f01014aa:	c1 e0 08             	shl    $0x8,%eax
f01014ad:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f01014af:	89 d8                	mov    %ebx,%eax
f01014b1:	c1 e0 0a             	shl    $0xa,%eax
f01014b4:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f01014ba:	85 c0                	test   %eax,%eax
f01014bc:	0f 48 c2             	cmovs  %edx,%eax
f01014bf:	c1 f8 0c             	sar    $0xc,%eax
f01014c2:	a3 44 f2 21 f0       	mov    %eax,0xf021f244
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01014c7:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f01014ce:	e8 22 0a 00 00       	call   f0101ef5 <mc146818_read>
f01014d3:	89 c3                	mov    %eax,%ebx
f01014d5:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f01014dc:	e8 14 0a 00 00       	call   f0101ef5 <mc146818_read>
f01014e1:	c1 e0 08             	shl    $0x8,%eax
f01014e4:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f01014e6:	89 d8                	mov    %ebx,%eax
f01014e8:	c1 e0 0a             	shl    $0xa,%eax
f01014eb:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f01014f1:	85 c0                	test   %eax,%eax
f01014f3:	0f 48 c2             	cmovs  %edx,%eax
f01014f6:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f01014f9:	85 c0                	test   %eax,%eax
f01014fb:	74 0e                	je     f010150b <mem_init+0x82>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f01014fd:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f0101503:	89 15 08 ff 21 f0    	mov    %edx,0xf021ff08
f0101509:	eb 0c                	jmp    f0101517 <mem_init+0x8e>
	else
		npages = npages_basemem;
f010150b:	8b 15 44 f2 21 f0    	mov    0xf021f244,%edx
f0101511:	89 15 08 ff 21 f0    	mov    %edx,0xf021ff08

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f0101517:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f010151a:	c1 e8 0a             	shr    $0xa,%eax
f010151d:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f0101521:	a1 44 f2 21 f0       	mov    0xf021f244,%eax
f0101526:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101529:	c1 e8 0a             	shr    $0xa,%eax
f010152c:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f0101530:	a1 08 ff 21 f0       	mov    0xf021ff08,%eax
f0101535:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101538:	c1 e8 0a             	shr    $0xa,%eax
f010153b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010153f:	c7 04 24 78 4c 10 f0 	movl   $0xf0104c78,(%esp)
f0101546:	e8 16 0b 00 00       	call   f0102061 <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);  // first_level pagedir
f010154b:	b8 00 10 00 00       	mov    $0x1000,%eax
f0101550:	e8 cb f5 ff ff       	call   f0100b20 <boot_alloc>
f0101555:	a3 0c ff 21 f0       	mov    %eax,0xf021ff0c
	memset(kern_pgdir, 0, PGSIZE);
f010155a:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101561:	00 
f0101562:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101569:	00 
f010156a:	89 04 24             	mov    %eax,(%esp)
f010156d:	e8 47 22 00 00       	call   f01037b9 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f0101572:	a1 0c ff 21 f0       	mov    0xf021ff0c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101577:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010157c:	77 20                	ja     f010159e <mem_init+0x115>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010157e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101582:	c7 44 24 08 a8 45 10 	movl   $0xf01045a8,0x8(%esp)
f0101589:	f0 
f010158a:	c7 44 24 04 96 00 00 	movl   $0x96,0x4(%esp)
f0101591:	00 
f0101592:	c7 04 24 e9 4c 10 f0 	movl   $0xf0104ce9,(%esp)
f0101599:	e8 a2 ea ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f010159e:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f01015a4:	83 ca 05             	or     $0x5,%edx
f01015a7:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct Page in this
	// array.  'npages' is the number of physical pages in memory.
	// Your code goes here:

	pages = (struct Page *)boot_alloc(npages * sizeof(struct Page)); // allocate npages to record all physical pages in memort using condition
f01015ad:	a1 08 ff 21 f0       	mov    0xf021ff08,%eax
f01015b2:	c1 e0 03             	shl    $0x3,%eax
f01015b5:	e8 66 f5 ff ff       	call   f0100b20 <boot_alloc>
f01015ba:	a3 10 ff 21 f0       	mov    %eax,0xf021ff10


	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.
	envs =  (struct Env *)boot_alloc(NENV * sizeof(struct Env));
f01015bf:	b8 00 f0 01 00       	mov    $0x1f000,%eax
f01015c4:	e8 57 f5 ff ff       	call   f0100b20 <boot_alloc>
f01015c9:	a3 48 f2 21 f0       	mov    %eax,0xf021f248
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f01015ce:	e8 da f9 ff ff       	call   f0100fad <page_init>

	check_page_free_list(1);
f01015d3:	b8 01 00 00 00       	mov    $0x1,%eax
f01015d8:	e8 16 f6 ff ff       	call   f0100bf3 <check_page_free_list>

f01015dd <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f01015dd:	55                   	push   %ebp
f01015de:	89 e5                	mov    %esp,%ebp
f01015e0:	57                   	push   %edi
f01015e1:	56                   	push   %esi
f01015e2:	53                   	push   %ebx
f01015e3:	83 ec 3c             	sub    $0x3c,%esp
f01015e6:	8b 7d 08             	mov    0x8(%ebp),%edi
f01015e9:	8b 45 0c             	mov    0xc(%ebp),%eax

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
f01015ec:	89 c2                	mov    %eax,%edx
f01015ee:	03 55 10             	add    0x10(%ebp),%edx
f01015f1:	89 55 d0             	mov    %edx,-0x30(%ebp)
f01015f4:	39 d0                	cmp    %edx,%eax
f01015f6:	73 70                	jae    f0101668 <user_mem_check+0x8b>
f01015f8:	89 c3                	mov    %eax,%ebx
f01015fa:	89 c6                	mov    %eax,%esi
		pte_t* store=0;
		struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
		if(store!=NULL)
		{
			//cprintf("pte!=NULL %08x\r\n",*store);
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f01015fc:	8b 45 14             	mov    0x14(%ebp),%eax
f01015ff:	83 c8 01             	or     $0x1,%eax
f0101602:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
	{
		pte_t* store=0;
f0101605:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
		struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
f010160c:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f010160f:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101613:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101617:	8b 47 60             	mov    0x60(%edi),%eax
f010161a:	89 04 24             	mov    %eax,(%esp)
f010161d:	e8 bb fc ff ff       	call   f01012dd <page_lookup>
		if(store!=NULL)
f0101622:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0101625:	85 c0                	test   %eax,%eax
f0101627:	74 1b                	je     f0101644 <user_mem_check+0x67>
		{
			//cprintf("pte!=NULL %08x\r\n",*store);
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f0101629:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f010162c:	89 ca                	mov    %ecx,%edx
f010162e:	23 10                	and    (%eax),%edx
f0101630:	39 d1                	cmp    %edx,%ecx
f0101632:	75 08                	jne    f010163c <user_mem_check+0x5f>
f0101634:	81 fe 00 00 80 ef    	cmp    $0xef800000,%esi
f010163a:	76 10                	jbe    f010164c <user_mem_check+0x6f>
			   {
				//cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f010163c:	89 35 3c f2 21 f0    	mov    %esi,0xf021f23c
				break;
f0101642:	eb 1d                	jmp    f0101661 <user_mem_check+0x84>
			}
			else
			{
				//cprintf("no pte!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f0101644:	89 35 3c f2 21 f0    	mov    %esi,0xf021f23c
				break;
f010164a:	eb 15                	jmp    f0101661 <user_mem_check+0x84>
			}
		    i=ROUNDDOWN(i,PGSIZE);
f010164c:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
f0101652:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0101658:	89 de                	mov    %ebx,%esi
f010165a:	3b 5d d0             	cmp    -0x30(%ebp),%ebx
f010165d:	72 a6                	jb     f0101605 <user_mem_check+0x28>
f010165f:	eb 0e                	jmp    f010166f <user_mem_check+0x92>
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
			   {
				//cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
				break;
f0101661:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f0101666:	eb 0c                	jmp    f0101674 <user_mem_check+0x97>
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
f0101668:	b8 00 00 00 00       	mov    $0x0,%eax
f010166d:	eb 05                	jmp    f0101674 <user_mem_check+0x97>
f010166f:	b8 00 00 00 00       	mov    $0x0,%eax
			}
		    i=ROUNDDOWN(i,PGSIZE);
		}

	return flag;
}
f0101674:	83 c4 3c             	add    $0x3c,%esp
f0101677:	5b                   	pop    %ebx
f0101678:	5e                   	pop    %esi
f0101679:	5f                   	pop    %edi
f010167a:	5d                   	pop    %ebp
f010167b:	c3                   	ret    

f010167c <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f010167c:	55                   	push   %ebp
f010167d:	89 e5                	mov    %esp,%ebp
f010167f:	53                   	push   %ebx
f0101680:	83 ec 14             	sub    $0x14,%esp
f0101683:	8b 5d 08             	mov    0x8(%ebp),%ebx
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
f0101686:	8b 45 14             	mov    0x14(%ebp),%eax
f0101689:	83 c8 04             	or     $0x4,%eax
f010168c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101690:	8b 45 10             	mov    0x10(%ebp),%eax
f0101693:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101697:	8b 45 0c             	mov    0xc(%ebp),%eax
f010169a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010169e:	89 1c 24             	mov    %ebx,(%esp)
f01016a1:	e8 37 ff ff ff       	call   f01015dd <user_mem_check>
f01016a6:	85 c0                	test   %eax,%eax
f01016a8:	79 24                	jns    f01016ce <user_mem_assert+0x52>
		cprintf(".%08x. user_mem_check assertion failure for "
f01016aa:	a1 3c f2 21 f0       	mov    0xf021f23c,%eax
f01016af:	89 44 24 08          	mov    %eax,0x8(%esp)
f01016b3:	8b 43 48             	mov    0x48(%ebx),%eax
f01016b6:	89 44 24 04          	mov    %eax,0x4(%esp)
f01016ba:	c7 04 24 b4 4c 10 f0 	movl   $0xf0104cb4,(%esp)
f01016c1:	e8 9b 09 00 00       	call   f0102061 <cprintf>
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
f01016c6:	89 1c 24             	mov    %ebx,(%esp)
f01016c9:	e8 ef 06 00 00       	call   f0101dbd <env_destroy>
	}
}
f01016ce:	83 c4 14             	add    $0x14,%esp
f01016d1:	5b                   	pop    %ebx
f01016d2:	5d                   	pop    %ebp
f01016d3:	c3                   	ret    

f01016d4 <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f01016d4:	55                   	push   %ebp
f01016d5:	89 e5                	mov    %esp,%ebp
f01016d7:	56                   	push   %esi
f01016d8:	53                   	push   %ebx
f01016d9:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f01016dc:	85 c0                	test   %eax,%eax
f01016de:	75 1a                	jne    f01016fa <envid2env+0x26>
		*env_store = curenv;
f01016e0:	e8 6e 27 00 00       	call   f0103e53 <cpunum>
f01016e5:	6b c0 74             	imul   $0x74,%eax,%eax
f01016e8:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f01016ee:	8b 55 0c             	mov    0xc(%ebp),%edx
f01016f1:	89 02                	mov    %eax,(%edx)
		return 0;
f01016f3:	b8 00 00 00 00       	mov    $0x0,%eax
f01016f8:	eb 72                	jmp    f010176c <envid2env+0x98>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f01016fa:	89 c3                	mov    %eax,%ebx
f01016fc:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
f0101702:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f0101705:	03 1d 48 f2 21 f0    	add    0xf021f248,%ebx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f010170b:	83 7b 54 00          	cmpl   $0x0,0x54(%ebx)
f010170f:	74 05                	je     f0101716 <envid2env+0x42>
f0101711:	39 43 48             	cmp    %eax,0x48(%ebx)
f0101714:	74 10                	je     f0101726 <envid2env+0x52>
		*env_store = 0;
f0101716:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101719:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f010171f:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0101724:	eb 46                	jmp    f010176c <envid2env+0x98>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f0101726:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f010172a:	74 36                	je     f0101762 <envid2env+0x8e>
f010172c:	e8 22 27 00 00       	call   f0103e53 <cpunum>
f0101731:	6b c0 74             	imul   $0x74,%eax,%eax
f0101734:	39 98 28 00 22 f0    	cmp    %ebx,-0xfddffd8(%eax)
f010173a:	74 26                	je     f0101762 <envid2env+0x8e>
f010173c:	8b 73 4c             	mov    0x4c(%ebx),%esi
f010173f:	e8 0f 27 00 00       	call   f0103e53 <cpunum>
f0101744:	6b c0 74             	imul   $0x74,%eax,%eax
f0101747:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f010174d:	3b 70 48             	cmp    0x48(%eax),%esi
f0101750:	74 10                	je     f0101762 <envid2env+0x8e>
		*env_store = 0;
f0101752:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101755:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f010175b:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0101760:	eb 0a                	jmp    f010176c <envid2env+0x98>
	}

	*env_store = e;
f0101762:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101765:	89 18                	mov    %ebx,(%eax)
	return 0;
f0101767:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010176c:	5b                   	pop    %ebx
f010176d:	5e                   	pop    %esi
f010176e:	5d                   	pop    %ebp
f010176f:	c3                   	ret    

f0101770 <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f0101770:	55                   	push   %ebp
f0101771:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f0101773:	b8 00 c3 11 f0       	mov    $0xf011c300,%eax
f0101778:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f010177b:	b8 23 00 00 00       	mov    $0x23,%eax
f0101780:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f0101782:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f0101784:	b0 10                	mov    $0x10,%al
f0101786:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f0101788:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f010178a:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f010178c:	ea 93 17 10 f0 08 00 	ljmp   $0x8,$0xf0101793
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f0101793:	b0 00                	mov    $0x0,%al
f0101795:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f0101798:	5d                   	pop    %ebp
f0101799:	c3                   	ret    

f010179a <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f010179a:	55                   	push   %ebp
f010179b:	89 e5                	mov    %esp,%ebp
f010179d:	53                   	push   %ebx
f010179e:	8b 0d 4c f2 21 f0    	mov    0xf021f24c,%ecx
f01017a4:	a1 48 f2 21 f0       	mov    0xf021f248,%eax
	// Set up envs array
	// LAB 3: Your code here.
	size_t i;
	for (i = 0; i < NENV; i++) {
		envs[i].env_id = 0;
f01017a9:	ba 00 04 00 00       	mov    $0x400,%edx
f01017ae:	89 c3                	mov    %eax,%ebx
f01017b0:	c7 40 48 00 00 00 00 	movl   $0x0,0x48(%eax)
		envs[i].env_link = env_free_list;
f01017b7:	89 48 44             	mov    %ecx,0x44(%eax)
f01017ba:	83 c0 7c             	add    $0x7c,%eax
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
	size_t i;
	for (i = 0; i < NENV; i++) {
f01017bd:	83 ea 01             	sub    $0x1,%edx
f01017c0:	74 04                	je     f01017c6 <env_init+0x2c>
		envs[i].env_id = 0;
		envs[i].env_link = env_free_list;
		env_free_list = &envs[i];
f01017c2:	89 d9                	mov    %ebx,%ecx
f01017c4:	eb e8                	jmp    f01017ae <env_init+0x14>
	}
	env_free_list = envs; // this line of code changing like this ugly looks just fit fuck grade sh,too useless
f01017c6:	a1 48 f2 21 f0       	mov    0xf021f248,%eax
f01017cb:	a3 4c f2 21 f0       	mov    %eax,0xf021f24c
	// Per-CPU part of the initialization
	env_init_percpu();
f01017d0:	e8 9b ff ff ff       	call   f0101770 <env_init_percpu>
}
f01017d5:	5b                   	pop    %ebx
f01017d6:	5d                   	pop    %ebp
f01017d7:	c3                   	ret    

f01017d8 <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f01017d8:	55                   	push   %ebp
f01017d9:	89 e5                	mov    %esp,%ebp
f01017db:	56                   	push   %esi
f01017dc:	53                   	push   %ebx
f01017dd:	83 ec 10             	sub    $0x10,%esp
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
f01017e0:	8b 1d 4c f2 21 f0    	mov    0xf021f24c,%ebx
f01017e6:	85 db                	test   %ebx,%ebx
f01017e8:	0f 84 92 01 00 00    	je     f0101980 <env_alloc+0x1a8>
{
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f01017ee:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01017f5:	e8 1c f9 ff ff       	call   f0101116 <page_alloc>
f01017fa:	85 c0                	test   %eax,%eax
f01017fc:	0f 84 85 01 00 00    	je     f0101987 <env_alloc+0x1af>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101802:	89 c2                	mov    %eax,%edx
f0101804:	2b 15 10 ff 21 f0    	sub    0xf021ff10,%edx
f010180a:	c1 fa 03             	sar    $0x3,%edx
f010180d:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101810:	89 d1                	mov    %edx,%ecx
f0101812:	c1 e9 0c             	shr    $0xc,%ecx
f0101815:	3b 0d 08 ff 21 f0    	cmp    0xf021ff08,%ecx
f010181b:	72 20                	jb     f010183d <env_alloc+0x65>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010181d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101821:	c7 44 24 08 84 45 10 	movl   $0xf0104584,0x8(%esp)
f0101828:	f0 
f0101829:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101830:	00 
f0101831:	c7 04 24 f5 4c 10 f0 	movl   $0xf0104cf5,(%esp)
f0101838:	e8 03 e8 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f010183d:	81 ea 00 00 00 10    	sub    $0x10000000,%edx
f0101843:	89 53 60             	mov    %edx,0x60(%ebx)
	//	is an exception -- you need to increment env_pgdir's
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
f0101846:	ba ec 0e 00 00       	mov    $0xeec,%edx
	for(i=PDX(UTOP);i<1024;i++){
		e->env_pgdir[i] = kern_pgdir[i];
f010184b:	8b 0d 0c ff 21 f0    	mov    0xf021ff0c,%ecx
f0101851:	8b 34 11             	mov    (%ecx,%edx,1),%esi
f0101854:	8b 4b 60             	mov    0x60(%ebx),%ecx
f0101857:	89 34 11             	mov    %esi,(%ecx,%edx,1)
f010185a:	83 c2 04             	add    $0x4,%edx
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
	for(i=PDX(UTOP);i<1024;i++){
f010185d:	81 fa 00 10 00 00    	cmp    $0x1000,%edx
f0101863:	75 e6                	jne    f010184b <env_alloc+0x73>
		e->env_pgdir[i] = kern_pgdir[i];
	}
	p->pp_ref++;
f0101865:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f010186a:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010186d:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101872:	77 20                	ja     f0101894 <env_alloc+0xbc>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101874:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101878:	c7 44 24 08 a8 45 10 	movl   $0xf01045a8,0x8(%esp)
f010187f:	f0 
f0101880:	c7 44 24 04 c6 00 00 	movl   $0xc6,0x4(%esp)
f0101887:	00 
f0101888:	c7 04 24 f2 4d 10 f0 	movl   $0xf0104df2,(%esp)
f010188f:	e8 ac e7 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0101894:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f010189a:	83 ca 05             	or     $0x5,%edx
f010189d:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate and set up the page directory for this environment.
	if ((r = env_setup_vm(e)) < 0)
		return r;

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f01018a3:	8b 43 48             	mov    0x48(%ebx),%eax
f01018a6:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f01018ab:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f01018b0:	ba 00 10 00 00       	mov    $0x1000,%edx
f01018b5:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f01018b8:	89 da                	mov    %ebx,%edx
f01018ba:	2b 15 48 f2 21 f0    	sub    0xf021f248,%edx
f01018c0:	c1 fa 02             	sar    $0x2,%edx
f01018c3:	69 d2 df 7b ef bd    	imul   $0xbdef7bdf,%edx,%edx
f01018c9:	09 d0                	or     %edx,%eax
f01018cb:	89 43 48             	mov    %eax,0x48(%ebx)

	// Set the basic status variables.
	e->env_parent_id = parent_id;
f01018ce:	8b 45 0c             	mov    0xc(%ebp),%eax
f01018d1:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f01018d4:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f01018db:	c7 43 54 02 00 00 00 	movl   $0x2,0x54(%ebx)
	e->env_runs = 0;
f01018e2:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f01018e9:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f01018f0:	00 
f01018f1:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01018f8:	00 
f01018f9:	89 1c 24             	mov    %ebx,(%esp)
f01018fc:	e8 b8 1e 00 00       	call   f01037b9 <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f0101901:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f0101907:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f010190d:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f0101913:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f010191a:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)

	// Enable interrupts while in user mode.
	// LAB 4: Your code here.

	// Clear the page fault handler until user installs one.
	e->env_pgfault_upcall = 0;
f0101920:	c7 43 64 00 00 00 00 	movl   $0x0,0x64(%ebx)

	// Also clear the IPC receiving flag.
	e->env_ipc_recving = 0;
f0101927:	c7 43 68 00 00 00 00 	movl   $0x0,0x68(%ebx)

	// commit the allocation
	env_free_list = e->env_link;
f010192e:	8b 43 44             	mov    0x44(%ebx),%eax
f0101931:	a3 4c f2 21 f0       	mov    %eax,0xf021f24c
	*newenv_store = e;
f0101936:	8b 45 08             	mov    0x8(%ebp),%eax
f0101939:	89 18                	mov    %ebx,(%eax)

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f010193b:	8b 5b 48             	mov    0x48(%ebx),%ebx
f010193e:	e8 10 25 00 00       	call   f0103e53 <cpunum>
f0101943:	6b d0 74             	imul   $0x74,%eax,%edx
f0101946:	b8 00 00 00 00       	mov    $0x0,%eax
f010194b:	83 ba 28 00 22 f0 00 	cmpl   $0x0,-0xfddffd8(%edx)
f0101952:	74 11                	je     f0101965 <env_alloc+0x18d>
f0101954:	e8 fa 24 00 00       	call   f0103e53 <cpunum>
f0101959:	6b c0 74             	imul   $0x74,%eax,%eax
f010195c:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0101962:	8b 40 48             	mov    0x48(%eax),%eax
f0101965:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0101969:	89 44 24 04          	mov    %eax,0x4(%esp)
f010196d:	c7 04 24 fd 4d 10 f0 	movl   $0xf0104dfd,(%esp)
f0101974:	e8 e8 06 00 00       	call   f0102061 <cprintf>
	return 0;
f0101979:	b8 00 00 00 00       	mov    $0x0,%eax
f010197e:	eb 0c                	jmp    f010198c <env_alloc+0x1b4>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
		return -E_NO_FREE_ENV;
f0101980:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f0101985:	eb 05                	jmp    f010198c <env_alloc+0x1b4>
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f0101987:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	env_free_list = e->env_link;
	*newenv_store = e;

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}
f010198c:	83 c4 10             	add    $0x10,%esp
f010198f:	5b                   	pop    %ebx
f0101990:	5e                   	pop    %esi
f0101991:	5d                   	pop    %ebp
f0101992:	c3                   	ret    

f0101993 <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f0101993:	55                   	push   %ebp
f0101994:	89 e5                	mov    %esp,%ebp
f0101996:	57                   	push   %edi
f0101997:	56                   	push   %esi
f0101998:	53                   	push   %ebx
f0101999:	83 ec 3c             	sub    $0x3c,%esp
	// LAB 3: Your code here.
	struct Env * env;
	if(env_alloc(&env,0)==0){
f010199c:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01019a3:	00 
f01019a4:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f01019a7:	89 04 24             	mov    %eax,(%esp)
f01019aa:	e8 29 fe ff ff       	call   f01017d8 <env_alloc>
f01019af:	85 c0                	test   %eax,%eax
f01019b1:	0f 85 dd 01 00 00    	jne    f0101b94 <env_create+0x201>
		load_icode(env,binary,size);
f01019b7:	8b 7d e4             	mov    -0x1c(%ebp),%edi
	//  You must also do something with the program's entry point,
	//  to make sure that the environment starts executing there.
	//  What?  (See env_run() and env_pop_tf() below.)

	// LAB 3: Your code here.
	lcr3(PADDR(e->env_pgdir));
f01019ba:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01019bd:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01019c2:	77 20                	ja     f01019e4 <env_create+0x51>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01019c4:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01019c8:	c7 44 24 08 a8 45 10 	movl   $0xf01045a8,0x8(%esp)
f01019cf:	f0 
f01019d0:	c7 44 24 04 64 01 00 	movl   $0x164,0x4(%esp)
f01019d7:	00 
f01019d8:	c7 04 24 f2 4d 10 f0 	movl   $0xf0104df2,(%esp)
f01019df:	e8 5c e6 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01019e4:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f01019e9:	0f 22 d8             	mov    %eax,%cr3
	struct Elf* ELFHDR = (struct Elf *) binary;
	if(ELFHDR->e_magic != ELF_MAGIC)
f01019ec:	8b 45 08             	mov    0x8(%ebp),%eax
f01019ef:	81 38 7f 45 4c 46    	cmpl   $0x464c457f,(%eax)
f01019f5:	74 1c                	je     f0101a13 <env_create+0x80>
		panic("Invalid ELF format !");
f01019f7:	c7 44 24 08 12 4e 10 	movl   $0xf0104e12,0x8(%esp)
f01019fe:	f0 
f01019ff:	c7 44 24 04 67 01 00 	movl   $0x167,0x4(%esp)
f0101a06:	00 
f0101a07:	c7 04 24 f2 4d 10 f0 	movl   $0xf0104df2,(%esp)
f0101a0e:	e8 2d e6 ff ff       	call   f0100040 <_panic>

	struct Proghdr *ph,*eph;
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
f0101a13:	8b 45 08             	mov    0x8(%ebp),%eax
f0101a16:	89 c6                	mov    %eax,%esi
f0101a18:	03 70 1c             	add    0x1c(%eax),%esi
	eph = ph + ELFHDR->e_phnum;
f0101a1b:	0f b7 40 2c          	movzwl 0x2c(%eax),%eax
f0101a1f:	c1 e0 05             	shl    $0x5,%eax
f0101a22:	01 f0                	add    %esi,%eax
f0101a24:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	for (; ph < eph; ph++) {
f0101a27:	39 c6                	cmp    %eax,%esi
f0101a29:	0f 83 d2 00 00 00    	jae    f0101b01 <env_create+0x16e>
		if (ph->p_type == ELF_PROG_LOAD) {
f0101a2f:	83 3e 01             	cmpl   $0x1,(%esi)
f0101a32:	0f 85 bd 00 00 00    	jne    f0101af5 <env_create+0x162>
			if (ph->p_filesz > ph->p_memsz)
f0101a38:	8b 56 14             	mov    0x14(%esi),%edx
f0101a3b:	39 56 10             	cmp    %edx,0x10(%esi)
f0101a3e:	76 1c                	jbe    f0101a5c <env_create+0xc9>
				panic("invalid ELF proGhdr header!");
f0101a40:	c7 44 24 08 27 4e 10 	movl   $0xf0104e27,0x8(%esp)
f0101a47:	f0 
f0101a48:	c7 44 24 04 6f 01 00 	movl   $0x16f,0x4(%esp)
f0101a4f:	00 
f0101a50:	c7 04 24 f2 4d 10 f0 	movl   $0xf0104df2,(%esp)
f0101a57:	e8 e4 e5 ff ff       	call   f0100040 <_panic>

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
f0101a5c:	8b 46 08             	mov    0x8(%esi),%eax
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f0101a5f:	89 c3                	mov    %eax,%ebx
f0101a61:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f0101a67:	8d 84 02 ff 0f 00 00 	lea    0xfff(%edx,%eax,1),%eax
f0101a6e:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0101a73:	39 c3                	cmp    %eax,%ebx
f0101a75:	73 59                	jae    f0101ad0 <env_create+0x13d>
f0101a77:	89 75 d0             	mov    %esi,-0x30(%ebp)
f0101a7a:	89 c6                	mov    %eax,%esi
		p = (struct Page*)page_alloc(1);
f0101a7c:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101a83:	e8 8e f6 ff ff       	call   f0101116 <page_alloc>
		if(p==NULL)
f0101a88:	85 c0                	test   %eax,%eax
f0101a8a:	75 1c                	jne    f0101aa8 <env_create+0x115>
			panic("Memory out!");
f0101a8c:	c7 44 24 08 43 4e 10 	movl   $0xf0104e43,0x8(%esp)
f0101a93:	f0 
f0101a94:	c7 44 24 04 29 01 00 	movl   $0x129,0x4(%esp)
f0101a9b:	00 
f0101a9c:	c7 04 24 f2 4d 10 f0 	movl   $0xf0104df2,(%esp)
f0101aa3:	e8 98 e5 ff ff       	call   f0100040 <_panic>
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
f0101aa8:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0101aaf:	00 
f0101ab0:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0101ab4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101ab8:	8b 47 60             	mov    0x60(%edi),%eax
f0101abb:	89 04 24             	mov    %eax,(%esp)
f0101abe:	e8 05 f9 ff ff       	call   f01013c8 <page_insert>
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f0101ac3:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0101ac9:	39 f3                	cmp    %esi,%ebx
f0101acb:	72 af                	jb     f0101a7c <env_create+0xe9>
f0101acd:	8b 75 d0             	mov    -0x30(%ebp),%esi
			if (ph->p_filesz > ph->p_memsz)
				panic("invalid ELF proGhdr header!");

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
			//copy to va
			char *va = (char *)(ph->p_va);
f0101ad0:	8b 4e 08             	mov    0x8(%esi),%ecx
			size_t i;
			for (i = 0; i < ph->p_filesz; i++)
f0101ad3:	83 7e 10 00          	cmpl   $0x0,0x10(%esi)
f0101ad7:	74 1c                	je     f0101af5 <env_create+0x162>
f0101ad9:	b8 00 00 00 00       	mov    $0x0,%eax
f0101ade:	8b 5d 08             	mov    0x8(%ebp),%ebx
				va[i] = binary[ph->p_offset + i];
f0101ae1:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f0101ae4:	03 56 04             	add    0x4(%esi),%edx
f0101ae7:	0f b6 12             	movzbl (%edx),%edx
f0101aea:	88 14 08             	mov    %dl,(%eax,%ecx,1)

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
			//copy to va
			char *va = (char *)(ph->p_va);
			size_t i;
			for (i = 0; i < ph->p_filesz; i++)
f0101aed:	83 c0 01             	add    $0x1,%eax
f0101af0:	3b 46 10             	cmp    0x10(%esi),%eax
f0101af3:	72 ec                	jb     f0101ae1 <env_create+0x14e>
		panic("Invalid ELF format !");

	struct Proghdr *ph,*eph;
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
	eph = ph + ELFHDR->e_phnum;
	for (; ph < eph; ph++) {
f0101af5:	83 c6 20             	add    $0x20,%esi
f0101af8:	39 75 d4             	cmp    %esi,-0x2c(%ebp)
f0101afb:	0f 87 2e ff ff ff    	ja     f0101a2f <env_create+0x9c>
			for (i = 0; i < ph->p_filesz; i++)
				va[i] = binary[ph->p_offset + i];
		}
	}
	//set programe entry
	e->env_tf.tf_eip = ELFHDR->e_entry;
f0101b01:	8b 45 08             	mov    0x8(%ebp),%eax
f0101b04:	8b 40 18             	mov    0x18(%eax),%eax
f0101b07:	89 47 30             	mov    %eax,0x30(%edi)
	// Now map one page for the program's initial stack
	// at virtual address USTACKTOP - PGSIZE.

	// LAB 3: Your code here.
	struct Page* stackPage = (struct Page*)page_alloc(1);
f0101b0a:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101b11:	e8 00 f6 ff ff       	call   f0101116 <page_alloc>
	if(stackPage == NULL)
f0101b16:	85 c0                	test   %eax,%eax
f0101b18:	75 1c                	jne    f0101b36 <env_create+0x1a3>
		panic("Out of memory!");
f0101b1a:	c7 44 24 08 4f 4e 10 	movl   $0xf0104e4f,0x8(%esp)
f0101b21:	f0 
f0101b22:	c7 44 24 04 81 01 00 	movl   $0x181,0x4(%esp)
f0101b29:	00 
f0101b2a:	c7 04 24 f2 4d 10 f0 	movl   $0xf0104df2,(%esp)
f0101b31:	e8 0a e5 ff ff       	call   f0100040 <_panic>
	page_insert(e->env_pgdir,stackPage,(void*)USTACKTOP - PGSIZE,PTE_U|PTE_W);
f0101b36:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0101b3d:	00 
f0101b3e:	c7 44 24 08 00 d0 bf 	movl   $0xeebfd000,0x8(%esp)
f0101b45:	ee 
f0101b46:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101b4a:	8b 47 60             	mov    0x60(%edi),%eax
f0101b4d:	89 04 24             	mov    %eax,(%esp)
f0101b50:	e8 73 f8 ff ff       	call   f01013c8 <page_insert>
	lcr3(PADDR(kern_pgdir));
f0101b55:	a1 0c ff 21 f0       	mov    0xf021ff0c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101b5a:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101b5f:	77 20                	ja     f0101b81 <env_create+0x1ee>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101b61:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101b65:	c7 44 24 08 a8 45 10 	movl   $0xf01045a8,0x8(%esp)
f0101b6c:	f0 
f0101b6d:	c7 44 24 04 83 01 00 	movl   $0x183,0x4(%esp)
f0101b74:	00 
f0101b75:	c7 04 24 f2 4d 10 f0 	movl   $0xf0104df2,(%esp)
f0101b7c:	e8 bf e4 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0101b81:	05 00 00 00 10       	add    $0x10000000,%eax
f0101b86:	0f 22 d8             	mov    %eax,%cr3
{
	// LAB 3: Your code here.
	struct Env * env;
	if(env_alloc(&env,0)==0){
		load_icode(env,binary,size);
		env->env_type = type;
f0101b89:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0101b8c:	8b 55 10             	mov    0x10(%ebp),%edx
f0101b8f:	89 50 50             	mov    %edx,0x50(%eax)
f0101b92:	eb 1c                	jmp    f0101bb0 <env_create+0x21d>
	}else{
		panic("create env fails !");
f0101b94:	c7 44 24 08 5e 4e 10 	movl   $0xf0104e5e,0x8(%esp)
f0101b9b:	f0 
f0101b9c:	c7 44 24 04 96 01 00 	movl   $0x196,0x4(%esp)
f0101ba3:	00 
f0101ba4:	c7 04 24 f2 4d 10 f0 	movl   $0xf0104df2,(%esp)
f0101bab:	e8 90 e4 ff ff       	call   f0100040 <_panic>
	}
}
f0101bb0:	83 c4 3c             	add    $0x3c,%esp
f0101bb3:	5b                   	pop    %ebx
f0101bb4:	5e                   	pop    %esi
f0101bb5:	5f                   	pop    %edi
f0101bb6:	5d                   	pop    %ebp
f0101bb7:	c3                   	ret    

f0101bb8 <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0101bb8:	55                   	push   %ebp
f0101bb9:	89 e5                	mov    %esp,%ebp
f0101bbb:	57                   	push   %edi
f0101bbc:	56                   	push   %esi
f0101bbd:	53                   	push   %ebx
f0101bbe:	83 ec 2c             	sub    $0x2c,%esp
f0101bc1:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f0101bc4:	e8 8a 22 00 00       	call   f0103e53 <cpunum>
f0101bc9:	6b c0 74             	imul   $0x74,%eax,%eax
f0101bcc:	39 b8 28 00 22 f0    	cmp    %edi,-0xfddffd8(%eax)
f0101bd2:	75 34                	jne    f0101c08 <env_free+0x50>
		lcr3(PADDR(kern_pgdir));
f0101bd4:	a1 0c ff 21 f0       	mov    0xf021ff0c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101bd9:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101bde:	77 20                	ja     f0101c00 <env_free+0x48>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101be0:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101be4:	c7 44 24 08 a8 45 10 	movl   $0xf01045a8,0x8(%esp)
f0101beb:	f0 
f0101bec:	c7 44 24 04 a8 01 00 	movl   $0x1a8,0x4(%esp)
f0101bf3:	00 
f0101bf4:	c7 04 24 f2 4d 10 f0 	movl   $0xf0104df2,(%esp)
f0101bfb:	e8 40 e4 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0101c00:	05 00 00 00 10       	add    $0x10000000,%eax
f0101c05:	0f 22 d8             	mov    %eax,%cr3

	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0101c08:	8b 5f 48             	mov    0x48(%edi),%ebx
f0101c0b:	e8 43 22 00 00       	call   f0103e53 <cpunum>
f0101c10:	6b d0 74             	imul   $0x74,%eax,%edx
f0101c13:	b8 00 00 00 00       	mov    $0x0,%eax
f0101c18:	83 ba 28 00 22 f0 00 	cmpl   $0x0,-0xfddffd8(%edx)
f0101c1f:	74 11                	je     f0101c32 <env_free+0x7a>
f0101c21:	e8 2d 22 00 00       	call   f0103e53 <cpunum>
f0101c26:	6b c0 74             	imul   $0x74,%eax,%eax
f0101c29:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0101c2f:	8b 40 48             	mov    0x48(%eax),%eax
f0101c32:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0101c36:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101c3a:	c7 04 24 71 4e 10 f0 	movl   $0xf0104e71,(%esp)
f0101c41:	e8 1b 04 00 00       	call   f0102061 <cprintf>

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0101c46:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0101c4d:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0101c50:	89 c8                	mov    %ecx,%eax
f0101c52:	c1 e0 02             	shl    $0x2,%eax
f0101c55:	89 45 dc             	mov    %eax,-0x24(%ebp)

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f0101c58:	8b 47 60             	mov    0x60(%edi),%eax
f0101c5b:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f0101c5e:	f7 c6 01 00 00 00    	test   $0x1,%esi
f0101c64:	0f 84 b7 00 00 00    	je     f0101d21 <env_free+0x169>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f0101c6a:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101c70:	89 f0                	mov    %esi,%eax
f0101c72:	c1 e8 0c             	shr    $0xc,%eax
f0101c75:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0101c78:	3b 05 08 ff 21 f0    	cmp    0xf021ff08,%eax
f0101c7e:	72 20                	jb     f0101ca0 <env_free+0xe8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101c80:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0101c84:	c7 44 24 08 84 45 10 	movl   $0xf0104584,0x8(%esp)
f0101c8b:	f0 
f0101c8c:	c7 44 24 04 b7 01 00 	movl   $0x1b7,0x4(%esp)
f0101c93:	00 
f0101c94:	c7 04 24 f2 4d 10 f0 	movl   $0xf0104df2,(%esp)
f0101c9b:	e8 a0 e3 ff ff       	call   f0100040 <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0101ca0:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0101ca3:	c1 e0 16             	shl    $0x16,%eax
f0101ca6:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0101ca9:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f0101cae:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f0101cb5:	01 
f0101cb6:	74 17                	je     f0101ccf <env_free+0x117>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0101cb8:	89 d8                	mov    %ebx,%eax
f0101cba:	c1 e0 0c             	shl    $0xc,%eax
f0101cbd:	0b 45 e4             	or     -0x1c(%ebp),%eax
f0101cc0:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101cc4:	8b 47 60             	mov    0x60(%edi),%eax
f0101cc7:	89 04 24             	mov    %eax,(%esp)
f0101cca:	e8 b0 f6 ff ff       	call   f010137f <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0101ccf:	83 c3 01             	add    $0x1,%ebx
f0101cd2:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f0101cd8:	75 d4                	jne    f0101cae <env_free+0xf6>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f0101cda:	8b 47 60             	mov    0x60(%edi),%eax
f0101cdd:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0101ce0:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101ce7:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0101cea:	3b 05 08 ff 21 f0    	cmp    0xf021ff08,%eax
f0101cf0:	72 1c                	jb     f0101d0e <env_free+0x156>
		panic("pa2page called with invalid pa");
f0101cf2:	c7 44 24 08 38 4c 10 	movl   $0xf0104c38,0x8(%esp)
f0101cf9:	f0 
f0101cfa:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101d01:	00 
f0101d02:	c7 04 24 f5 4c 10 f0 	movl   $0xf0104cf5,(%esp)
f0101d09:	e8 32 e3 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0101d0e:	a1 10 ff 21 f0       	mov    0xf021ff10,%eax
f0101d13:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0101d16:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0101d19:	89 04 24             	mov    %eax,(%esp)
f0101d1c:	e8 8f f4 ff ff       	call   f01011b0 <page_decref>
	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0101d21:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f0101d25:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f0101d2c:	0f 85 1b ff ff ff    	jne    f0101c4d <env_free+0x95>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f0101d32:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101d35:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101d3a:	77 20                	ja     f0101d5c <env_free+0x1a4>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101d3c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101d40:	c7 44 24 08 a8 45 10 	movl   $0xf01045a8,0x8(%esp)
f0101d47:	f0 
f0101d48:	c7 44 24 04 c5 01 00 	movl   $0x1c5,0x4(%esp)
f0101d4f:	00 
f0101d50:	c7 04 24 f2 4d 10 f0 	movl   $0xf0104df2,(%esp)
f0101d57:	e8 e4 e2 ff ff       	call   f0100040 <_panic>
	e->env_pgdir = 0;
f0101d5c:	c7 47 60 00 00 00 00 	movl   $0x0,0x60(%edi)
	return (physaddr_t)kva - KERNBASE;
f0101d63:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101d68:	c1 e8 0c             	shr    $0xc,%eax
f0101d6b:	3b 05 08 ff 21 f0    	cmp    0xf021ff08,%eax
f0101d71:	72 1c                	jb     f0101d8f <env_free+0x1d7>
		panic("pa2page called with invalid pa");
f0101d73:	c7 44 24 08 38 4c 10 	movl   $0xf0104c38,0x8(%esp)
f0101d7a:	f0 
f0101d7b:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101d82:	00 
f0101d83:	c7 04 24 f5 4c 10 f0 	movl   $0xf0104cf5,(%esp)
f0101d8a:	e8 b1 e2 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0101d8f:	8b 15 10 ff 21 f0    	mov    0xf021ff10,%edx
f0101d95:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f0101d98:	89 04 24             	mov    %eax,(%esp)
f0101d9b:	e8 10 f4 ff ff       	call   f01011b0 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f0101da0:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f0101da7:	a1 4c f2 21 f0       	mov    0xf021f24c,%eax
f0101dac:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f0101daf:	89 3d 4c f2 21 f0    	mov    %edi,0xf021f24c
}
f0101db5:	83 c4 2c             	add    $0x2c,%esp
f0101db8:	5b                   	pop    %ebx
f0101db9:	5e                   	pop    %esi
f0101dba:	5f                   	pop    %edi
f0101dbb:	5d                   	pop    %ebp
f0101dbc:	c3                   	ret    

f0101dbd <env_destroy>:
// If e was the current env, then runs a new environment (and does not return
// to the caller).
//
void
env_destroy(struct Env *e)
{
f0101dbd:	55                   	push   %ebp
f0101dbe:	89 e5                	mov    %esp,%ebp
f0101dc0:	53                   	push   %ebx
f0101dc1:	83 ec 14             	sub    $0x14,%esp
f0101dc4:	8b 5d 08             	mov    0x8(%ebp),%ebx
	// If e is currently running on other CPUs, we change its state to
	// ENV_DYING. A zombie environment will be freed the next time
	// it traps to the kernel.
	if (e->env_status == ENV_RUNNING && curenv != e) {
f0101dc7:	83 7b 54 03          	cmpl   $0x3,0x54(%ebx)
f0101dcb:	75 19                	jne    f0101de6 <env_destroy+0x29>
f0101dcd:	e8 81 20 00 00       	call   f0103e53 <cpunum>
f0101dd2:	6b c0 74             	imul   $0x74,%eax,%eax
f0101dd5:	39 98 28 00 22 f0    	cmp    %ebx,-0xfddffd8(%eax)
f0101ddb:	74 09                	je     f0101de6 <env_destroy+0x29>
		e->env_status = ENV_DYING;
f0101ddd:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
		return;
f0101de4:	eb 2f                	jmp    f0101e15 <env_destroy+0x58>
	}

	env_free(e);
f0101de6:	89 1c 24             	mov    %ebx,(%esp)
f0101de9:	e8 ca fd ff ff       	call   f0101bb8 <env_free>

	if (curenv == e) {
f0101dee:	e8 60 20 00 00       	call   f0103e53 <cpunum>
f0101df3:	6b c0 74             	imul   $0x74,%eax,%eax
f0101df6:	39 98 28 00 22 f0    	cmp    %ebx,-0xfddffd8(%eax)
f0101dfc:	75 17                	jne    f0101e15 <env_destroy+0x58>
		curenv = NULL;
f0101dfe:	e8 50 20 00 00       	call   f0103e53 <cpunum>
f0101e03:	6b c0 74             	imul   $0x74,%eax,%eax
f0101e06:	c7 80 28 00 22 f0 00 	movl   $0x0,-0xfddffd8(%eax)
f0101e0d:	00 00 00 
		sched_yield();
f0101e10:	e8 0c 0b 00 00       	call   f0102921 <sched_yield>
	}
}
f0101e15:	83 c4 14             	add    $0x14,%esp
f0101e18:	5b                   	pop    %ebx
f0101e19:	5d                   	pop    %ebp
f0101e1a:	c3                   	ret    

f0101e1b <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f0101e1b:	55                   	push   %ebp
f0101e1c:	89 e5                	mov    %esp,%ebp
f0101e1e:	53                   	push   %ebx
f0101e1f:	83 ec 14             	sub    $0x14,%esp
	// Record the CPU we are running on for user-space debugging
	curenv->env_cpunum = cpunum();
f0101e22:	e8 2c 20 00 00       	call   f0103e53 <cpunum>
f0101e27:	6b c0 74             	imul   $0x74,%eax,%eax
f0101e2a:	8b 98 28 00 22 f0    	mov    -0xfddffd8(%eax),%ebx
f0101e30:	e8 1e 20 00 00       	call   f0103e53 <cpunum>
f0101e35:	89 43 5c             	mov    %eax,0x5c(%ebx)

	__asm __volatile("movl %0,%%esp\n"
f0101e38:	8b 65 08             	mov    0x8(%ebp),%esp
f0101e3b:	61                   	popa   
f0101e3c:	07                   	pop    %es
f0101e3d:	1f                   	pop    %ds
f0101e3e:	83 c4 08             	add    $0x8,%esp
f0101e41:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f0101e42:	c7 44 24 08 87 4e 10 	movl   $0xf0104e87,0x8(%esp)
f0101e49:	f0 
f0101e4a:	c7 44 24 04 fb 01 00 	movl   $0x1fb,0x4(%esp)
f0101e51:	00 
f0101e52:	c7 04 24 f2 4d 10 f0 	movl   $0xf0104df2,(%esp)
f0101e59:	e8 e2 e1 ff ff       	call   f0100040 <_panic>

f0101e5e <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0101e5e:	55                   	push   %ebp
f0101e5f:	89 e5                	mov    %esp,%ebp
f0101e61:	53                   	push   %ebx
f0101e62:	83 ec 14             	sub    $0x14,%esp
f0101e65:	8b 5d 08             	mov    0x8(%ebp),%ebx

	// Hint: This function loads the new environment's state from
	//	e->env_tf.  Go back through the code you wrote above
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.
	if(curenv!=NULL&& curenv->env_status==ENV_RUNNING)
f0101e68:	e8 e6 1f 00 00       	call   f0103e53 <cpunum>
f0101e6d:	6b c0 74             	imul   $0x74,%eax,%eax
f0101e70:	83 b8 28 00 22 f0 00 	cmpl   $0x0,-0xfddffd8(%eax)
f0101e77:	74 29                	je     f0101ea2 <env_run+0x44>
f0101e79:	e8 d5 1f 00 00       	call   f0103e53 <cpunum>
f0101e7e:	6b c0 74             	imul   $0x74,%eax,%eax
f0101e81:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0101e87:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0101e8b:	75 15                	jne    f0101ea2 <env_run+0x44>
		curenv->env_status = ENV_RUNNABLE;
f0101e8d:	e8 c1 1f 00 00       	call   f0103e53 <cpunum>
f0101e92:	6b c0 74             	imul   $0x74,%eax,%eax
f0101e95:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0101e9b:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)

	curenv = e;
f0101ea2:	e8 ac 1f 00 00       	call   f0103e53 <cpunum>
f0101ea7:	6b c0 74             	imul   $0x74,%eax,%eax
f0101eaa:	89 98 28 00 22 f0    	mov    %ebx,-0xfddffd8(%eax)
	int zero = 0;
	e->env_status = ENV_RUNNING;
f0101eb0:	c7 43 54 03 00 00 00 	movl   $0x3,0x54(%ebx)
	e->env_runs++;
f0101eb7:	83 43 58 01          	addl   $0x1,0x58(%ebx)
	lcr3(PADDR(e->env_pgdir));
f0101ebb:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101ebe:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101ec3:	77 20                	ja     f0101ee5 <env_run+0x87>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101ec5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101ec9:	c7 44 24 08 a8 45 10 	movl   $0xf01045a8,0x8(%esp)
f0101ed0:	f0 
f0101ed1:	c7 44 24 04 1e 02 00 	movl   $0x21e,0x4(%esp)
f0101ed8:	00 
f0101ed9:	c7 04 24 f2 4d 10 f0 	movl   $0xf0104df2,(%esp)
f0101ee0:	e8 5b e1 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0101ee5:	05 00 00 00 10       	add    $0x10000000,%eax
f0101eea:	0f 22 d8             	mov    %eax,%cr3
	env_pop_tf(&e->env_tf);
f0101eed:	89 1c 24             	mov    %ebx,(%esp)
f0101ef0:	e8 26 ff ff ff       	call   f0101e1b <env_pop_tf>

f0101ef5 <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0101ef5:	55                   	push   %ebp
f0101ef6:	89 e5                	mov    %esp,%ebp
f0101ef8:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0101efc:	ba 70 00 00 00       	mov    $0x70,%edx
f0101f01:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0101f02:	b2 71                	mov    $0x71,%dl
f0101f04:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0101f05:	0f b6 c0             	movzbl %al,%eax
}
f0101f08:	5d                   	pop    %ebp
f0101f09:	c3                   	ret    

f0101f0a <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0101f0a:	55                   	push   %ebp
f0101f0b:	89 e5                	mov    %esp,%ebp
f0101f0d:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0101f11:	ba 70 00 00 00       	mov    $0x70,%edx
f0101f16:	ee                   	out    %al,(%dx)
f0101f17:	b2 71                	mov    $0x71,%dl
f0101f19:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101f1c:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0101f1d:	5d                   	pop    %ebp
f0101f1e:	c3                   	ret    

f0101f1f <irq_setmask_8259A>:
		irq_setmask_8259A(irq_mask_8259A);
}

void
irq_setmask_8259A(uint16_t mask)
{
f0101f1f:	55                   	push   %ebp
f0101f20:	89 e5                	mov    %esp,%ebp
f0101f22:	56                   	push   %esi
f0101f23:	53                   	push   %ebx
f0101f24:	83 ec 10             	sub    $0x10,%esp
f0101f27:	8b 45 08             	mov    0x8(%ebp),%eax
	int i;
	irq_mask_8259A = mask;
f0101f2a:	66 a3 88 c3 11 f0    	mov    %ax,0xf011c388
	if (!didinit)
f0101f30:	83 3d 50 f2 21 f0 00 	cmpl   $0x0,0xf021f250
f0101f37:	74 4e                	je     f0101f87 <irq_setmask_8259A+0x68>
f0101f39:	89 c6                	mov    %eax,%esi
f0101f3b:	ba 21 00 00 00       	mov    $0x21,%edx
f0101f40:	ee                   	out    %al,(%dx)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
f0101f41:	66 c1 e8 08          	shr    $0x8,%ax
f0101f45:	b2 a1                	mov    $0xa1,%dl
f0101f47:	ee                   	out    %al,(%dx)
	cprintf("enabled interrupts:");
f0101f48:	c7 04 24 93 4e 10 f0 	movl   $0xf0104e93,(%esp)
f0101f4f:	e8 0d 01 00 00       	call   f0102061 <cprintf>
	for (i = 0; i < 16; i++)
f0101f54:	bb 00 00 00 00       	mov    $0x0,%ebx
		if (~mask & (1<<i))
f0101f59:	0f b7 f6             	movzwl %si,%esi
f0101f5c:	f7 d6                	not    %esi
f0101f5e:	0f a3 de             	bt     %ebx,%esi
f0101f61:	73 10                	jae    f0101f73 <irq_setmask_8259A+0x54>
			cprintf(" %d", i);
f0101f63:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101f67:	c7 04 24 59 53 10 f0 	movl   $0xf0105359,(%esp)
f0101f6e:	e8 ee 00 00 00       	call   f0102061 <cprintf>
	if (!didinit)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
	cprintf("enabled interrupts:");
	for (i = 0; i < 16; i++)
f0101f73:	83 c3 01             	add    $0x1,%ebx
f0101f76:	83 fb 10             	cmp    $0x10,%ebx
f0101f79:	75 e3                	jne    f0101f5e <irq_setmask_8259A+0x3f>
		if (~mask & (1<<i))
			cprintf(" %d", i);
	cprintf("\n");
f0101f7b:	c7 04 24 2d 46 10 f0 	movl   $0xf010462d,(%esp)
f0101f82:	e8 da 00 00 00       	call   f0102061 <cprintf>
}
f0101f87:	83 c4 10             	add    $0x10,%esp
f0101f8a:	5b                   	pop    %ebx
f0101f8b:	5e                   	pop    %esi
f0101f8c:	5d                   	pop    %ebp
f0101f8d:	c3                   	ret    

f0101f8e <pic_init>:

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
	didinit = 1;
f0101f8e:	c7 05 50 f2 21 f0 01 	movl   $0x1,0xf021f250
f0101f95:	00 00 00 
f0101f98:	ba 21 00 00 00       	mov    $0x21,%edx
f0101f9d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0101fa2:	ee                   	out    %al,(%dx)
f0101fa3:	b2 a1                	mov    $0xa1,%dl
f0101fa5:	ee                   	out    %al,(%dx)
f0101fa6:	b2 20                	mov    $0x20,%dl
f0101fa8:	b8 11 00 00 00       	mov    $0x11,%eax
f0101fad:	ee                   	out    %al,(%dx)
f0101fae:	b2 21                	mov    $0x21,%dl
f0101fb0:	b8 20 00 00 00       	mov    $0x20,%eax
f0101fb5:	ee                   	out    %al,(%dx)
f0101fb6:	b8 04 00 00 00       	mov    $0x4,%eax
f0101fbb:	ee                   	out    %al,(%dx)
f0101fbc:	b8 03 00 00 00       	mov    $0x3,%eax
f0101fc1:	ee                   	out    %al,(%dx)
f0101fc2:	b2 a0                	mov    $0xa0,%dl
f0101fc4:	b8 11 00 00 00       	mov    $0x11,%eax
f0101fc9:	ee                   	out    %al,(%dx)
f0101fca:	b2 a1                	mov    $0xa1,%dl
f0101fcc:	b8 28 00 00 00       	mov    $0x28,%eax
f0101fd1:	ee                   	out    %al,(%dx)
f0101fd2:	b8 02 00 00 00       	mov    $0x2,%eax
f0101fd7:	ee                   	out    %al,(%dx)
f0101fd8:	b8 01 00 00 00       	mov    $0x1,%eax
f0101fdd:	ee                   	out    %al,(%dx)
f0101fde:	b2 20                	mov    $0x20,%dl
f0101fe0:	b8 68 00 00 00       	mov    $0x68,%eax
f0101fe5:	ee                   	out    %al,(%dx)
f0101fe6:	b8 0a 00 00 00       	mov    $0xa,%eax
f0101feb:	ee                   	out    %al,(%dx)
f0101fec:	b2 a0                	mov    $0xa0,%dl
f0101fee:	b8 68 00 00 00       	mov    $0x68,%eax
f0101ff3:	ee                   	out    %al,(%dx)
f0101ff4:	b8 0a 00 00 00       	mov    $0xa,%eax
f0101ff9:	ee                   	out    %al,(%dx)
	outb(IO_PIC1, 0x0a);             /* read IRR by default */

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
f0101ffa:	0f b7 05 88 c3 11 f0 	movzwl 0xf011c388,%eax
f0102001:	66 83 f8 ff          	cmp    $0xffff,%ax
f0102005:	74 12                	je     f0102019 <pic_init+0x8b>
static bool didinit;

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
f0102007:	55                   	push   %ebp
f0102008:	89 e5                	mov    %esp,%ebp
f010200a:	83 ec 18             	sub    $0x18,%esp

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
		irq_setmask_8259A(irq_mask_8259A);
f010200d:	0f b7 c0             	movzwl %ax,%eax
f0102010:	89 04 24             	mov    %eax,(%esp)
f0102013:	e8 07 ff ff ff       	call   f0101f1f <irq_setmask_8259A>
}
f0102018:	c9                   	leave  
f0102019:	f3 c3                	repz ret 

f010201b <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f010201b:	55                   	push   %ebp
f010201c:	89 e5                	mov    %esp,%ebp
f010201e:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0102021:	8b 45 08             	mov    0x8(%ebp),%eax
f0102024:	89 04 24             	mov    %eax,(%esp)
f0102027:	e8 91 e7 ff ff       	call   f01007bd <cputchar>
	*cnt++;
}
f010202c:	c9                   	leave  
f010202d:	c3                   	ret    

f010202e <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f010202e:	55                   	push   %ebp
f010202f:	89 e5                	mov    %esp,%ebp
f0102031:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0102034:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f010203b:	8b 45 0c             	mov    0xc(%ebp),%eax
f010203e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102042:	8b 45 08             	mov    0x8(%ebp),%eax
f0102045:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102049:	8d 45 f4             	lea    -0xc(%ebp),%eax
f010204c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102050:	c7 04 24 1b 20 10 f0 	movl   $0xf010201b,(%esp)
f0102057:	e8 18 10 00 00       	call   f0103074 <vprintfmt>
	return cnt;
}
f010205c:	8b 45 f4             	mov    -0xc(%ebp),%eax
f010205f:	c9                   	leave  
f0102060:	c3                   	ret    

f0102061 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0102061:	55                   	push   %ebp
f0102062:	89 e5                	mov    %esp,%ebp
f0102064:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0102067:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f010206a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010206e:	8b 45 08             	mov    0x8(%ebp),%eax
f0102071:	89 04 24             	mov    %eax,(%esp)
f0102074:	e8 b5 ff ff ff       	call   f010202e <vcprintf>
	va_end(ap);

	return cnt;
}
f0102079:	c9                   	leave  
f010207a:	c3                   	ret    
f010207b:	66 90                	xchg   %ax,%ax
f010207d:	66 90                	xchg   %ax,%ax
f010207f:	90                   	nop

f0102080 <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f0102080:	55                   	push   %ebp
f0102081:	89 e5                	mov    %esp,%ebp
	//
	// LAB 4: Your code here:

	// Setup a TSS so that we get the right stack
	// when we trap to the kernel.
	ts.ts_esp0 = KSTACKTOP;
f0102083:	c7 05 84 fa 21 f0 00 	movl   $0xefc00000,0xf021fa84
f010208a:	00 c0 ef 
	ts.ts_ss0 = GD_KD;
f010208d:	66 c7 05 88 fa 21 f0 	movw   $0x10,0xf021fa88
f0102094:	10 00 

	// Initialize the TSS slot of the gdt.
	gdt[GD_TSS0 >> 3] = SEG16(STS_T32A, (uint32_t) (&ts),
f0102096:	66 c7 05 48 c3 11 f0 	movw   $0x68,0xf011c348
f010209d:	68 00 
f010209f:	b8 80 fa 21 f0       	mov    $0xf021fa80,%eax
f01020a4:	66 a3 4a c3 11 f0    	mov    %ax,0xf011c34a
f01020aa:	89 c2                	mov    %eax,%edx
f01020ac:	c1 ea 10             	shr    $0x10,%edx
f01020af:	88 15 4c c3 11 f0    	mov    %dl,0xf011c34c
f01020b5:	c6 05 4e c3 11 f0 40 	movb   $0x40,0xf011c34e
f01020bc:	c1 e8 18             	shr    $0x18,%eax
f01020bf:	a2 4f c3 11 f0       	mov    %al,0xf011c34f
					sizeof(struct Taskstate), 0);
	gdt[GD_TSS0 >> 3].sd_s = 0;
f01020c4:	c6 05 4d c3 11 f0 89 	movb   $0x89,0xf011c34d
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f01020cb:	b8 28 00 00 00       	mov    $0x28,%eax
f01020d0:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f01020d3:	b8 8a c3 11 f0       	mov    $0xf011c38a,%eax
f01020d8:	0f 01 18             	lidtl  (%eax)
	// bottom three bits are special; we leave them 0)
	ltr(GD_TSS0);

	// Load the IDT
	lidt(&idt_pd);
}
f01020db:	5d                   	pop    %ebp
f01020dc:	c3                   	ret    

f01020dd <trap_init>:
}


void
trap_init(void)
{
f01020dd:	55                   	push   %ebp
f01020de:	89 e5                	mov    %esp,%ebp
	extern struct Segdesc gdt[];
	SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);
f01020e0:	b8 aa 28 10 f0       	mov    $0xf01028aa,%eax
f01020e5:	66 a3 60 f2 21 f0    	mov    %ax,0xf021f260
f01020eb:	66 c7 05 62 f2 21 f0 	movw   $0x8,0xf021f262
f01020f2:	08 00 
f01020f4:	c6 05 64 f2 21 f0 00 	movb   $0x0,0xf021f264
f01020fb:	c6 05 65 f2 21 f0 8f 	movb   $0x8f,0xf021f265
f0102102:	c1 e8 10             	shr    $0x10,%eax
f0102105:	66 a3 66 f2 21 f0    	mov    %ax,0xf021f266
	SETGATE(idt[2], 0, GD_KT, nmi_handler, 0);
f010210b:	b8 b0 28 10 f0       	mov    $0xf01028b0,%eax
f0102110:	66 a3 70 f2 21 f0    	mov    %ax,0xf021f270
f0102116:	66 c7 05 72 f2 21 f0 	movw   $0x8,0xf021f272
f010211d:	08 00 
f010211f:	c6 05 74 f2 21 f0 00 	movb   $0x0,0xf021f274
f0102126:	c6 05 75 f2 21 f0 8e 	movb   $0x8e,0xf021f275
f010212d:	c1 e8 10             	shr    $0x10,%eax
f0102130:	66 a3 76 f2 21 f0    	mov    %ax,0xf021f276
	SETGATE(idt[3], 1, GD_KT, breakpoint_handler, 3);
f0102136:	b8 b6 28 10 f0       	mov    $0xf01028b6,%eax
f010213b:	66 a3 78 f2 21 f0    	mov    %ax,0xf021f278
f0102141:	66 c7 05 7a f2 21 f0 	movw   $0x8,0xf021f27a
f0102148:	08 00 
f010214a:	c6 05 7c f2 21 f0 00 	movb   $0x0,0xf021f27c
f0102151:	c6 05 7d f2 21 f0 ef 	movb   $0xef,0xf021f27d
f0102158:	c1 e8 10             	shr    $0x10,%eax
f010215b:	66 a3 7e f2 21 f0    	mov    %ax,0xf021f27e
	SETGATE(idt[4], 1, GD_KT, overflow_handler, 3);
f0102161:	b8 bc 28 10 f0       	mov    $0xf01028bc,%eax
f0102166:	66 a3 80 f2 21 f0    	mov    %ax,0xf021f280
f010216c:	66 c7 05 82 f2 21 f0 	movw   $0x8,0xf021f282
f0102173:	08 00 
f0102175:	c6 05 84 f2 21 f0 00 	movb   $0x0,0xf021f284
f010217c:	c6 05 85 f2 21 f0 ef 	movb   $0xef,0xf021f285
f0102183:	c1 e8 10             	shr    $0x10,%eax
f0102186:	66 a3 86 f2 21 f0    	mov    %ax,0xf021f286
	SETGATE(idt[5], 1, GD_KT, bdrgeexceed_handler, 3);
f010218c:	b8 c2 28 10 f0       	mov    $0xf01028c2,%eax
f0102191:	66 a3 88 f2 21 f0    	mov    %ax,0xf021f288
f0102197:	66 c7 05 8a f2 21 f0 	movw   $0x8,0xf021f28a
f010219e:	08 00 
f01021a0:	c6 05 8c f2 21 f0 00 	movb   $0x0,0xf021f28c
f01021a7:	c6 05 8d f2 21 f0 ef 	movb   $0xef,0xf021f28d
f01021ae:	c1 e8 10             	shr    $0x10,%eax
f01021b1:	66 a3 8e f2 21 f0    	mov    %ax,0xf021f28e
	SETGATE(idt[6], 1, GD_KT, invalidop_handler, 0);
f01021b7:	b8 c8 28 10 f0       	mov    $0xf01028c8,%eax
f01021bc:	66 a3 90 f2 21 f0    	mov    %ax,0xf021f290
f01021c2:	66 c7 05 92 f2 21 f0 	movw   $0x8,0xf021f292
f01021c9:	08 00 
f01021cb:	c6 05 94 f2 21 f0 00 	movb   $0x0,0xf021f294
f01021d2:	c6 05 95 f2 21 f0 8f 	movb   $0x8f,0xf021f295
f01021d9:	c1 e8 10             	shr    $0x10,%eax
f01021dc:	66 a3 96 f2 21 f0    	mov    %ax,0xf021f296
	SETGATE(idt[7], 1, GD_KT, nomathcopro_handler, 0);
f01021e2:	b8 ce 28 10 f0       	mov    $0xf01028ce,%eax
f01021e7:	66 a3 98 f2 21 f0    	mov    %ax,0xf021f298
f01021ed:	66 c7 05 9a f2 21 f0 	movw   $0x8,0xf021f29a
f01021f4:	08 00 
f01021f6:	c6 05 9c f2 21 f0 00 	movb   $0x0,0xf021f29c
f01021fd:	c6 05 9d f2 21 f0 8f 	movb   $0x8f,0xf021f29d
f0102204:	c1 e8 10             	shr    $0x10,%eax
f0102207:	66 a3 9e f2 21 f0    	mov    %ax,0xf021f29e
	SETGATE(idt[8], 1, GD_KT, dbfault_handler, 0);
f010220d:	b8 d4 28 10 f0       	mov    $0xf01028d4,%eax
f0102212:	66 a3 a0 f2 21 f0    	mov    %ax,0xf021f2a0
f0102218:	66 c7 05 a2 f2 21 f0 	movw   $0x8,0xf021f2a2
f010221f:	08 00 
f0102221:	c6 05 a4 f2 21 f0 00 	movb   $0x0,0xf021f2a4
f0102228:	c6 05 a5 f2 21 f0 8f 	movb   $0x8f,0xf021f2a5
f010222f:	c1 e8 10             	shr    $0x10,%eax
f0102232:	66 a3 a6 f2 21 f0    	mov    %ax,0xf021f2a6
	SETGATE(idt[10], 1, GD_KT, invalidTSS_handler, 0);
f0102238:	b8 d8 28 10 f0       	mov    $0xf01028d8,%eax
f010223d:	66 a3 b0 f2 21 f0    	mov    %ax,0xf021f2b0
f0102243:	66 c7 05 b2 f2 21 f0 	movw   $0x8,0xf021f2b2
f010224a:	08 00 
f010224c:	c6 05 b4 f2 21 f0 00 	movb   $0x0,0xf021f2b4
f0102253:	c6 05 b5 f2 21 f0 8f 	movb   $0x8f,0xf021f2b5
f010225a:	c1 e8 10             	shr    $0x10,%eax
f010225d:	66 a3 b6 f2 21 f0    	mov    %ax,0xf021f2b6

	SETGATE(idt[11], 1, GD_KT, sgmtnotpresent_handler, 0);
f0102263:	b8 dc 28 10 f0       	mov    $0xf01028dc,%eax
f0102268:	66 a3 b8 f2 21 f0    	mov    %ax,0xf021f2b8
f010226e:	66 c7 05 ba f2 21 f0 	movw   $0x8,0xf021f2ba
f0102275:	08 00 
f0102277:	c6 05 bc f2 21 f0 00 	movb   $0x0,0xf021f2bc
f010227e:	c6 05 bd f2 21 f0 8f 	movb   $0x8f,0xf021f2bd
f0102285:	c1 e8 10             	shr    $0x10,%eax
f0102288:	66 a3 be f2 21 f0    	mov    %ax,0xf021f2be
	SETGATE(idt[12], 1, GD_KT, stacksgmtfault_handler, 0);
f010228e:	b8 e0 28 10 f0       	mov    $0xf01028e0,%eax
f0102293:	66 a3 c0 f2 21 f0    	mov    %ax,0xf021f2c0
f0102299:	66 c7 05 c2 f2 21 f0 	movw   $0x8,0xf021f2c2
f01022a0:	08 00 
f01022a2:	c6 05 c4 f2 21 f0 00 	movb   $0x0,0xf021f2c4
f01022a9:	c6 05 c5 f2 21 f0 8f 	movb   $0x8f,0xf021f2c5
f01022b0:	c1 e8 10             	shr    $0x10,%eax
f01022b3:	66 a3 c6 f2 21 f0    	mov    %ax,0xf021f2c6
	SETGATE(idt[14], 1, GD_KT, pagefault_handler, 0);
f01022b9:	b8 e8 28 10 f0       	mov    $0xf01028e8,%eax
f01022be:	66 a3 d0 f2 21 f0    	mov    %ax,0xf021f2d0
f01022c4:	66 c7 05 d2 f2 21 f0 	movw   $0x8,0xf021f2d2
f01022cb:	08 00 
f01022cd:	c6 05 d4 f2 21 f0 00 	movb   $0x0,0xf021f2d4
f01022d4:	c6 05 d5 f2 21 f0 8f 	movb   $0x8f,0xf021f2d5
f01022db:	c1 e8 10             	shr    $0x10,%eax
f01022de:	66 a3 d6 f2 21 f0    	mov    %ax,0xf021f2d6
	SETGATE(idt[13], 1, GD_KT, generalprotection_handler, 0);
f01022e4:	b8 e4 28 10 f0       	mov    $0xf01028e4,%eax
f01022e9:	66 a3 c8 f2 21 f0    	mov    %ax,0xf021f2c8
f01022ef:	66 c7 05 ca f2 21 f0 	movw   $0x8,0xf021f2ca
f01022f6:	08 00 
f01022f8:	c6 05 cc f2 21 f0 00 	movb   $0x0,0xf021f2cc
f01022ff:	c6 05 cd f2 21 f0 8f 	movb   $0x8f,0xf021f2cd
f0102306:	c1 e8 10             	shr    $0x10,%eax
f0102309:	66 a3 ce f2 21 f0    	mov    %ax,0xf021f2ce
	SETGATE(idt[16], 1, GD_KT, FPUerror_handler, 0);
f010230f:	b8 ec 28 10 f0       	mov    $0xf01028ec,%eax
f0102314:	66 a3 e0 f2 21 f0    	mov    %ax,0xf021f2e0
f010231a:	66 c7 05 e2 f2 21 f0 	movw   $0x8,0xf021f2e2
f0102321:	08 00 
f0102323:	c6 05 e4 f2 21 f0 00 	movb   $0x0,0xf021f2e4
f010232a:	c6 05 e5 f2 21 f0 8f 	movb   $0x8f,0xf021f2e5
f0102331:	c1 e8 10             	shr    $0x10,%eax
f0102334:	66 a3 e6 f2 21 f0    	mov    %ax,0xf021f2e6
	SETGATE(idt[17], 1, GD_KT, alignmentcheck_handler, 0);
f010233a:	b8 f2 28 10 f0       	mov    $0xf01028f2,%eax
f010233f:	66 a3 e8 f2 21 f0    	mov    %ax,0xf021f2e8
f0102345:	66 c7 05 ea f2 21 f0 	movw   $0x8,0xf021f2ea
f010234c:	08 00 
f010234e:	c6 05 ec f2 21 f0 00 	movb   $0x0,0xf021f2ec
f0102355:	c6 05 ed f2 21 f0 8f 	movb   $0x8f,0xf021f2ed
f010235c:	c1 e8 10             	shr    $0x10,%eax
f010235f:	66 a3 ee f2 21 f0    	mov    %ax,0xf021f2ee
	SETGATE(idt[18],1, GD_KT, machinecheck_handler, 0);
f0102365:	b8 f6 28 10 f0       	mov    $0xf01028f6,%eax
f010236a:	66 a3 f0 f2 21 f0    	mov    %ax,0xf021f2f0
f0102370:	66 c7 05 f2 f2 21 f0 	movw   $0x8,0xf021f2f2
f0102377:	08 00 
f0102379:	c6 05 f4 f2 21 f0 00 	movb   $0x0,0xf021f2f4
f0102380:	c6 05 f5 f2 21 f0 8f 	movb   $0x8f,0xf021f2f5
f0102387:	c1 e8 10             	shr    $0x10,%eax
f010238a:	66 a3 f6 f2 21 f0    	mov    %ax,0xf021f2f6
	SETGATE(idt[19], 1, GD_KT, SIMDFPexception_handler, 0);
f0102390:	b8 fc 28 10 f0       	mov    $0xf01028fc,%eax
f0102395:	66 a3 f8 f2 21 f0    	mov    %ax,0xf021f2f8
f010239b:	66 c7 05 fa f2 21 f0 	movw   $0x8,0xf021f2fa
f01023a2:	08 00 
f01023a4:	c6 05 fc f2 21 f0 00 	movb   $0x0,0xf021f2fc
f01023ab:	c6 05 fd f2 21 f0 8f 	movb   $0x8f,0xf021f2fd
f01023b2:	c1 e8 10             	shr    $0x10,%eax
f01023b5:	66 a3 fe f2 21 f0    	mov    %ax,0xf021f2fe
	SETGATE(idt[48], 0, GD_KT, systemcall_handler, 3);
f01023bb:	b8 02 29 10 f0       	mov    $0xf0102902,%eax
f01023c0:	66 a3 e0 f3 21 f0    	mov    %ax,0xf021f3e0
f01023c6:	66 c7 05 e2 f3 21 f0 	movw   $0x8,0xf021f3e2
f01023cd:	08 00 
f01023cf:	c6 05 e4 f3 21 f0 00 	movb   $0x0,0xf021f3e4
f01023d6:	c6 05 e5 f3 21 f0 ee 	movb   $0xee,0xf021f3e5
f01023dd:	c1 e8 10             	shr    $0x10,%eax
f01023e0:	66 a3 e6 f3 21 f0    	mov    %ax,0xf021f3e6
	// LAB 3: Your code here.

	// Per-CPU setup 
	trap_init_percpu();
f01023e6:	e8 95 fc ff ff       	call   f0102080 <trap_init_percpu>
}
f01023eb:	5d                   	pop    %ebp
f01023ec:	c3                   	ret    

f01023ed <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f01023ed:	55                   	push   %ebp
f01023ee:	89 e5                	mov    %esp,%ebp
f01023f0:	53                   	push   %ebx
f01023f1:	83 ec 14             	sub    $0x14,%esp
f01023f4:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f01023f7:	8b 03                	mov    (%ebx),%eax
f01023f9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01023fd:	c7 04 24 a7 4e 10 f0 	movl   $0xf0104ea7,(%esp)
f0102404:	e8 58 fc ff ff       	call   f0102061 <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f0102409:	8b 43 04             	mov    0x4(%ebx),%eax
f010240c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102410:	c7 04 24 b6 4e 10 f0 	movl   $0xf0104eb6,(%esp)
f0102417:	e8 45 fc ff ff       	call   f0102061 <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f010241c:	8b 43 08             	mov    0x8(%ebx),%eax
f010241f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102423:	c7 04 24 c5 4e 10 f0 	movl   $0xf0104ec5,(%esp)
f010242a:	e8 32 fc ff ff       	call   f0102061 <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f010242f:	8b 43 0c             	mov    0xc(%ebx),%eax
f0102432:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102436:	c7 04 24 d4 4e 10 f0 	movl   $0xf0104ed4,(%esp)
f010243d:	e8 1f fc ff ff       	call   f0102061 <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f0102442:	8b 43 10             	mov    0x10(%ebx),%eax
f0102445:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102449:	c7 04 24 e3 4e 10 f0 	movl   $0xf0104ee3,(%esp)
f0102450:	e8 0c fc ff ff       	call   f0102061 <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0102455:	8b 43 14             	mov    0x14(%ebx),%eax
f0102458:	89 44 24 04          	mov    %eax,0x4(%esp)
f010245c:	c7 04 24 f2 4e 10 f0 	movl   $0xf0104ef2,(%esp)
f0102463:	e8 f9 fb ff ff       	call   f0102061 <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f0102468:	8b 43 18             	mov    0x18(%ebx),%eax
f010246b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010246f:	c7 04 24 01 4f 10 f0 	movl   $0xf0104f01,(%esp)
f0102476:	e8 e6 fb ff ff       	call   f0102061 <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f010247b:	8b 43 1c             	mov    0x1c(%ebx),%eax
f010247e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102482:	c7 04 24 10 4f 10 f0 	movl   $0xf0104f10,(%esp)
f0102489:	e8 d3 fb ff ff       	call   f0102061 <cprintf>
}
f010248e:	83 c4 14             	add    $0x14,%esp
f0102491:	5b                   	pop    %ebx
f0102492:	5d                   	pop    %ebp
f0102493:	c3                   	ret    

f0102494 <print_trapframe>:
	lidt(&idt_pd);
}

void
print_trapframe(struct Trapframe *tf)
{
f0102494:	55                   	push   %ebp
f0102495:	89 e5                	mov    %esp,%ebp
f0102497:	56                   	push   %esi
f0102498:	53                   	push   %ebx
f0102499:	83 ec 10             	sub    $0x10,%esp
f010249c:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
f010249f:	e8 af 19 00 00       	call   f0103e53 <cpunum>
f01024a4:	89 44 24 08          	mov    %eax,0x8(%esp)
f01024a8:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01024ac:	c7 04 24 74 4f 10 f0 	movl   $0xf0104f74,(%esp)
f01024b3:	e8 a9 fb ff ff       	call   f0102061 <cprintf>
	print_regs(&tf->tf_regs);
f01024b8:	89 1c 24             	mov    %ebx,(%esp)
f01024bb:	e8 2d ff ff ff       	call   f01023ed <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f01024c0:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f01024c4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01024c8:	c7 04 24 92 4f 10 f0 	movl   $0xf0104f92,(%esp)
f01024cf:	e8 8d fb ff ff       	call   f0102061 <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f01024d4:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f01024d8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01024dc:	c7 04 24 a5 4f 10 f0 	movl   $0xf0104fa5,(%esp)
f01024e3:	e8 79 fb ff ff       	call   f0102061 <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f01024e8:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f01024eb:	83 f8 13             	cmp    $0x13,%eax
f01024ee:	77 09                	ja     f01024f9 <print_trapframe+0x65>
		return excnames[trapno];
f01024f0:	8b 14 85 60 52 10 f0 	mov    -0xfefada0(,%eax,4),%edx
f01024f7:	eb 1f                	jmp    f0102518 <print_trapframe+0x84>
	if (trapno == T_SYSCALL)
f01024f9:	83 f8 30             	cmp    $0x30,%eax
f01024fc:	74 15                	je     f0102513 <print_trapframe+0x7f>
		return "System call";
	if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16)
f01024fe:	8d 50 e0             	lea    -0x20(%eax),%edx
		return "Hardware Interrupt";
f0102501:	83 fa 0f             	cmp    $0xf,%edx
f0102504:	ba 2b 4f 10 f0       	mov    $0xf0104f2b,%edx
f0102509:	b9 3e 4f 10 f0       	mov    $0xf0104f3e,%ecx
f010250e:	0f 47 d1             	cmova  %ecx,%edx
f0102511:	eb 05                	jmp    f0102518 <print_trapframe+0x84>
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
		return excnames[trapno];
	if (trapno == T_SYSCALL)
		return "System call";
f0102513:	ba 1f 4f 10 f0       	mov    $0xf0104f1f,%edx
{
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0102518:	89 54 24 08          	mov    %edx,0x8(%esp)
f010251c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102520:	c7 04 24 b8 4f 10 f0 	movl   $0xf0104fb8,(%esp)
f0102527:	e8 35 fb ff ff       	call   f0102061 <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f010252c:	3b 1d 60 fa 21 f0    	cmp    0xf021fa60,%ebx
f0102532:	75 19                	jne    f010254d <print_trapframe+0xb9>
f0102534:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0102538:	75 13                	jne    f010254d <print_trapframe+0xb9>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f010253a:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f010253d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102541:	c7 04 24 ca 4f 10 f0 	movl   $0xf0104fca,(%esp)
f0102548:	e8 14 fb ff ff       	call   f0102061 <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f010254d:	8b 43 2c             	mov    0x2c(%ebx),%eax
f0102550:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102554:	c7 04 24 d9 4f 10 f0 	movl   $0xf0104fd9,(%esp)
f010255b:	e8 01 fb ff ff       	call   f0102061 <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f0102560:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0102564:	75 51                	jne    f01025b7 <print_trapframe+0x123>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f0102566:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f0102569:	89 c2                	mov    %eax,%edx
f010256b:	83 e2 01             	and    $0x1,%edx
f010256e:	ba 4d 4f 10 f0       	mov    $0xf0104f4d,%edx
f0102573:	b9 58 4f 10 f0       	mov    $0xf0104f58,%ecx
f0102578:	0f 45 ca             	cmovne %edx,%ecx
f010257b:	89 c2                	mov    %eax,%edx
f010257d:	83 e2 02             	and    $0x2,%edx
f0102580:	ba 64 4f 10 f0       	mov    $0xf0104f64,%edx
f0102585:	be 6a 4f 10 f0       	mov    $0xf0104f6a,%esi
f010258a:	0f 44 d6             	cmove  %esi,%edx
f010258d:	83 e0 04             	and    $0x4,%eax
f0102590:	b8 6f 4f 10 f0       	mov    $0xf0104f6f,%eax
f0102595:	be d9 50 10 f0       	mov    $0xf01050d9,%esi
f010259a:	0f 44 c6             	cmove  %esi,%eax
f010259d:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01025a1:	89 54 24 08          	mov    %edx,0x8(%esp)
f01025a5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01025a9:	c7 04 24 e7 4f 10 f0 	movl   $0xf0104fe7,(%esp)
f01025b0:	e8 ac fa ff ff       	call   f0102061 <cprintf>
f01025b5:	eb 0c                	jmp    f01025c3 <print_trapframe+0x12f>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f01025b7:	c7 04 24 2d 46 10 f0 	movl   $0xf010462d,(%esp)
f01025be:	e8 9e fa ff ff       	call   f0102061 <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f01025c3:	8b 43 30             	mov    0x30(%ebx),%eax
f01025c6:	89 44 24 04          	mov    %eax,0x4(%esp)
f01025ca:	c7 04 24 f6 4f 10 f0 	movl   $0xf0104ff6,(%esp)
f01025d1:	e8 8b fa ff ff       	call   f0102061 <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f01025d6:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f01025da:	89 44 24 04          	mov    %eax,0x4(%esp)
f01025de:	c7 04 24 05 50 10 f0 	movl   $0xf0105005,(%esp)
f01025e5:	e8 77 fa ff ff       	call   f0102061 <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f01025ea:	8b 43 38             	mov    0x38(%ebx),%eax
f01025ed:	89 44 24 04          	mov    %eax,0x4(%esp)
f01025f1:	c7 04 24 18 50 10 f0 	movl   $0xf0105018,(%esp)
f01025f8:	e8 64 fa ff ff       	call   f0102061 <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f01025fd:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f0102601:	74 27                	je     f010262a <print_trapframe+0x196>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f0102603:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0102606:	89 44 24 04          	mov    %eax,0x4(%esp)
f010260a:	c7 04 24 27 50 10 f0 	movl   $0xf0105027,(%esp)
f0102611:	e8 4b fa ff ff       	call   f0102061 <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f0102616:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f010261a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010261e:	c7 04 24 36 50 10 f0 	movl   $0xf0105036,(%esp)
f0102625:	e8 37 fa ff ff       	call   f0102061 <cprintf>
	}
}
f010262a:	83 c4 10             	add    $0x10,%esp
f010262d:	5b                   	pop    %ebx
f010262e:	5e                   	pop    %esi
f010262f:	5d                   	pop    %ebp
f0102630:	c3                   	ret    

f0102631 <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f0102631:	55                   	push   %ebp
f0102632:	89 e5                	mov    %esp,%ebp
f0102634:	56                   	push   %esi
f0102635:	53                   	push   %ebx
f0102636:	83 ec 10             	sub    $0x10,%esp
f0102639:	8b 45 08             	mov    0x8(%ebp),%eax
f010263c:	0f 20 d3             	mov    %cr2,%ebx
	uint32_t fault_va;

	// Read processor's CR2 register to find the faulting address
	fault_va = rcr2();
	if((tf->tf_cs & 3)==0) // last three bits 000 means DPL_Kern
f010263f:	f6 40 34 03          	testb  $0x3,0x34(%eax)
f0102643:	75 1c                	jne    f0102661 <page_fault_handler+0x30>
	{
		panic("kernel mode page faults!!");
f0102645:	c7 44 24 08 49 50 10 	movl   $0xf0105049,0x8(%esp)
f010264c:	f0 
f010264d:	c7 44 24 04 3f 01 00 	movl   $0x13f,0x4(%esp)
f0102654:	00 
f0102655:	c7 04 24 63 50 10 f0 	movl   $0xf0105063,(%esp)
f010265c:	e8 df d9 ff ff       	call   f0100040 <_panic>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0102661:	8b 70 30             	mov    0x30(%eax),%esi
		curenv->env_id, fault_va, tf->tf_eip);
f0102664:	e8 ea 17 00 00       	call   f0103e53 <cpunum>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0102669:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010266d:	89 5c 24 08          	mov    %ebx,0x8(%esp)
		curenv->env_id, fault_va, tf->tf_eip);
f0102671:	6b c0 74             	imul   $0x74,%eax,%eax
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0102674:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f010267a:	8b 40 48             	mov    0x48(%eax),%eax
f010267d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102681:	c7 04 24 24 52 10 f0 	movl   $0xf0105224,(%esp)
f0102688:	e8 d4 f9 ff ff       	call   f0102061 <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
	//print_trapframe(tf);
	env_destroy(curenv);
f010268d:	e8 c1 17 00 00       	call   f0103e53 <cpunum>
f0102692:	6b c0 74             	imul   $0x74,%eax,%eax
f0102695:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f010269b:	89 04 24             	mov    %eax,(%esp)
f010269e:	e8 1a f7 ff ff       	call   f0101dbd <env_destroy>
}
f01026a3:	83 c4 10             	add    $0x10,%esp
f01026a6:	5b                   	pop    %ebx
f01026a7:	5e                   	pop    %esi
f01026a8:	5d                   	pop    %ebp
f01026a9:	c3                   	ret    

f01026aa <trap>:



void
trap(struct Trapframe *tf)
{
f01026aa:	55                   	push   %ebp
f01026ab:	89 e5                	mov    %esp,%ebp
f01026ad:	57                   	push   %edi
f01026ae:	56                   	push   %esi
f01026af:	83 ec 20             	sub    $0x20,%esp
f01026b2:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f01026b5:	fc                   	cld    

	// Halt the CPU if some other CPU has called panic()
	extern char *panicstr;
	if (panicstr)
f01026b6:	83 3d 00 ff 21 f0 00 	cmpl   $0x0,0xf021ff00
f01026bd:	74 01                	je     f01026c0 <trap+0x16>
		asm volatile("hlt");
f01026bf:	f4                   	hlt    

static __inline uint32_t
read_eflags(void)
{
        uint32_t eflags;
        __asm __volatile("pushfl; popl %0" : "=r" (eflags));
f01026c0:	9c                   	pushf  
f01026c1:	58                   	pop    %eax

	// Check that interrupts are disabled.  If this assertion
	// fails, DO NOT be tempted to fix it by inserting a "cli" in
	// the interrupt path.
	assert(!(read_eflags() & FL_IF));
f01026c2:	f6 c4 02             	test   $0x2,%ah
f01026c5:	74 24                	je     f01026eb <trap+0x41>
f01026c7:	c7 44 24 0c 6f 50 10 	movl   $0xf010506f,0xc(%esp)
f01026ce:	f0 
f01026cf:	c7 44 24 08 0f 4d 10 	movl   $0xf0104d0f,0x8(%esp)
f01026d6:	f0 
f01026d7:	c7 44 24 04 0b 01 00 	movl   $0x10b,0x4(%esp)
f01026de:	00 
f01026df:	c7 04 24 63 50 10 f0 	movl   $0xf0105063,(%esp)
f01026e6:	e8 55 d9 ff ff       	call   f0100040 <_panic>
	
	cprintf("Incoming TRAP frame at %p\n", tf);
f01026eb:	89 74 24 04          	mov    %esi,0x4(%esp)
f01026ef:	c7 04 24 88 50 10 f0 	movl   $0xf0105088,(%esp)
f01026f6:	e8 66 f9 ff ff       	call   f0102061 <cprintf>

	if ((tf->tf_cs & 3) == 3) {
f01026fb:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f01026ff:	83 e0 03             	and    $0x3,%eax
f0102702:	66 83 f8 03          	cmp    $0x3,%ax
f0102706:	0f 85 9b 00 00 00    	jne    f01027a7 <trap+0xfd>
		// Trapped from user mode.
		// Acquire the big kernel lock before doing any
		// serious kernel work.
		// LAB 4: Your code here.
		assert(curenv);
f010270c:	e8 42 17 00 00       	call   f0103e53 <cpunum>
f0102711:	6b c0 74             	imul   $0x74,%eax,%eax
f0102714:	83 b8 28 00 22 f0 00 	cmpl   $0x0,-0xfddffd8(%eax)
f010271b:	75 24                	jne    f0102741 <trap+0x97>
f010271d:	c7 44 24 0c a3 50 10 	movl   $0xf01050a3,0xc(%esp)
f0102724:	f0 
f0102725:	c7 44 24 08 0f 4d 10 	movl   $0xf0104d0f,0x8(%esp)
f010272c:	f0 
f010272d:	c7 44 24 04 14 01 00 	movl   $0x114,0x4(%esp)
f0102734:	00 
f0102735:	c7 04 24 63 50 10 f0 	movl   $0xf0105063,(%esp)
f010273c:	e8 ff d8 ff ff       	call   f0100040 <_panic>

		// Garbage collect if current enviroment is a zombie
		if (curenv->env_status == ENV_DYING) {
f0102741:	e8 0d 17 00 00       	call   f0103e53 <cpunum>
f0102746:	6b c0 74             	imul   $0x74,%eax,%eax
f0102749:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f010274f:	83 78 54 01          	cmpl   $0x1,0x54(%eax)
f0102753:	75 2d                	jne    f0102782 <trap+0xd8>
			env_free(curenv);
f0102755:	e8 f9 16 00 00       	call   f0103e53 <cpunum>
f010275a:	6b c0 74             	imul   $0x74,%eax,%eax
f010275d:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102763:	89 04 24             	mov    %eax,(%esp)
f0102766:	e8 4d f4 ff ff       	call   f0101bb8 <env_free>
			curenv = NULL;
f010276b:	e8 e3 16 00 00       	call   f0103e53 <cpunum>
f0102770:	6b c0 74             	imul   $0x74,%eax,%eax
f0102773:	c7 80 28 00 22 f0 00 	movl   $0x0,-0xfddffd8(%eax)
f010277a:	00 00 00 
			sched_yield();
f010277d:	e8 9f 01 00 00       	call   f0102921 <sched_yield>
		}

		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		curenv->env_tf = *tf;
f0102782:	e8 cc 16 00 00       	call   f0103e53 <cpunum>
f0102787:	6b c0 74             	imul   $0x74,%eax,%eax
f010278a:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102790:	b9 11 00 00 00       	mov    $0x11,%ecx
f0102795:	89 c7                	mov    %eax,%edi
f0102797:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f0102799:	e8 b5 16 00 00       	call   f0103e53 <cpunum>
f010279e:	6b c0 74             	imul   $0x74,%eax,%eax
f01027a1:	8b b0 28 00 22 f0    	mov    -0xfddffd8(%eax),%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f01027a7:	89 35 60 fa 21 f0    	mov    %esi,0xf021fa60
}
static void
trap_dispatch(struct Trapframe *tf)
{
	// Handle processor exceptions.
	print_trapframe(tf);
f01027ad:	89 34 24             	mov    %esi,(%esp)
f01027b0:	e8 df fc ff ff       	call   f0102494 <print_trapframe>
	// LAB 3: Your code here.

	// Handle spurious interrupts
	// The hardware sometimes raises these because of noise on the
	// IRQ line or other reasons. We don't care.
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_SPURIOUS) {
f01027b5:	8b 46 28             	mov    0x28(%esi),%eax
f01027b8:	83 f8 27             	cmp    $0x27,%eax
f01027bb:	75 19                	jne    f01027d6 <trap+0x12c>
		cprintf("Spurious interrupt on irq 7\n");
f01027bd:	c7 04 24 aa 50 10 f0 	movl   $0xf01050aa,(%esp)
f01027c4:	e8 98 f8 ff ff       	call   f0102061 <cprintf>
		print_trapframe(tf);
f01027c9:	89 34 24             	mov    %esi,(%esp)
f01027cc:	e8 c3 fc ff ff       	call   f0102494 <print_trapframe>
f01027d1:	e9 93 00 00 00       	jmp    f0102869 <trap+0x1bf>

	// Handle clock interrupts. Don't forget to acknowledge the
	// interrupt using lapic_eoi() before calling the scheduler!
	// LAB 4: Your code here.

	if(tf->tf_trapno==T_PGFLT)
f01027d6:	83 f8 0e             	cmp    $0xe,%eax
f01027d9:	75 0f                	jne    f01027ea <trap+0x140>
	{
		page_fault_handler(tf);
f01027db:	89 34 24             	mov    %esi,(%esp)
f01027de:	66 90                	xchg   %ax,%ax
f01027e0:	e8 4c fe ff ff       	call   f0102631 <page_fault_handler>
f01027e5:	e9 7f 00 00 00       	jmp    f0102869 <trap+0x1bf>
		return;
	}
	if(tf->tf_trapno==T_BRKPT)
f01027ea:	83 f8 03             	cmp    $0x3,%eax
f01027ed:	75 0a                	jne    f01027f9 <trap+0x14f>
	{
		monitor(tf);
f01027ef:	89 34 24             	mov    %esi,(%esp)
f01027f2:	e8 cb e1 ff ff       	call   f01009c2 <monitor>
f01027f7:	eb 70                	jmp    f0102869 <trap+0x1bf>
		return;
	}
	if(tf->tf_trapno==T_SYSCALL)
f01027f9:	83 f8 30             	cmp    $0x30,%eax
f01027fc:	75 32                	jne    f0102830 <trap+0x186>
	{
		tf->tf_regs.reg_eax=syscall(tf->tf_regs.reg_eax,tf->tf_regs.reg_edx,tf->tf_regs.reg_ecx,tf->tf_regs.reg_ebx,tf->tf_regs.reg_edi,tf->tf_regs.reg_esi);
f01027fe:	8b 46 04             	mov    0x4(%esi),%eax
f0102801:	89 44 24 14          	mov    %eax,0x14(%esp)
f0102805:	8b 06                	mov    (%esi),%eax
f0102807:	89 44 24 10          	mov    %eax,0x10(%esp)
f010280b:	8b 46 10             	mov    0x10(%esi),%eax
f010280e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102812:	8b 46 18             	mov    0x18(%esi),%eax
f0102815:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102819:	8b 46 14             	mov    0x14(%esi),%eax
f010281c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102820:	8b 46 1c             	mov    0x1c(%esi),%eax
f0102823:	89 04 24             	mov    %eax,(%esp)
f0102826:	e8 95 01 00 00       	call   f01029c0 <syscall>
f010282b:	89 46 1c             	mov    %eax,0x1c(%esi)
f010282e:	eb 39                	jmp    f0102869 <trap+0x1bf>
	    return;
	}
	// Unexpected trap: The user process or the kernel has a bug.

	if (tf->tf_cs == GD_KT)
f0102830:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f0102835:	75 1c                	jne    f0102853 <trap+0x1a9>
		panic("unhandled trap in kernel");
f0102837:	c7 44 24 08 c7 50 10 	movl   $0xf01050c7,0x8(%esp)
f010283e:	f0 
f010283f:	c7 44 24 04 f3 00 00 	movl   $0xf3,0x4(%esp)
f0102846:	00 
f0102847:	c7 04 24 63 50 10 f0 	movl   $0xf0105063,(%esp)
f010284e:	e8 ed d7 ff ff       	call   f0100040 <_panic>
	else {
		env_destroy(curenv);
f0102853:	e8 fb 15 00 00       	call   f0103e53 <cpunum>
f0102858:	6b c0 74             	imul   $0x74,%eax,%eax
f010285b:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102861:	89 04 24             	mov    %eax,(%esp)
f0102864:	e8 54 f5 ff ff       	call   f0101dbd <env_destroy>
	trap_dispatch(tf);

	// If we made it to this point, then no other environment was
	// scheduled, so we should return to the current environment
	// if doing so makes sense.
	if (curenv && curenv->env_status == ENV_RUNNING)
f0102869:	e8 e5 15 00 00       	call   f0103e53 <cpunum>
f010286e:	6b c0 74             	imul   $0x74,%eax,%eax
f0102871:	83 b8 28 00 22 f0 00 	cmpl   $0x0,-0xfddffd8(%eax)
f0102878:	74 2a                	je     f01028a4 <trap+0x1fa>
f010287a:	e8 d4 15 00 00       	call   f0103e53 <cpunum>
f010287f:	6b c0 74             	imul   $0x74,%eax,%eax
f0102882:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102888:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f010288c:	75 16                	jne    f01028a4 <trap+0x1fa>
		env_run(curenv);
f010288e:	e8 c0 15 00 00       	call   f0103e53 <cpunum>
f0102893:	6b c0 74             	imul   $0x74,%eax,%eax
f0102896:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f010289c:	89 04 24             	mov    %eax,(%esp)
f010289f:	e8 ba f5 ff ff       	call   f0101e5e <env_run>
	else
		sched_yield();
f01028a4:	e8 78 00 00 00       	call   f0102921 <sched_yield>
f01028a9:	90                   	nop

f01028aa <dividezero_handler>:
.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
f01028aa:	6a 00                	push   $0x0
f01028ac:	6a 00                	push   $0x0
f01028ae:	eb 58                	jmp    f0102908 <_alltraps>

f01028b0 <nmi_handler>:
TRAPHANDLER_NOEC(nmi_handler, 0x2)
f01028b0:	6a 00                	push   $0x0
f01028b2:	6a 02                	push   $0x2
f01028b4:	eb 52                	jmp    f0102908 <_alltraps>

f01028b6 <breakpoint_handler>:
TRAPHANDLER_NOEC(breakpoint_handler, 0x3)
f01028b6:	6a 00                	push   $0x0
f01028b8:	6a 03                	push   $0x3
f01028ba:	eb 4c                	jmp    f0102908 <_alltraps>

f01028bc <overflow_handler>:
TRAPHANDLER_NOEC(overflow_handler, 0x4)
f01028bc:	6a 00                	push   $0x0
f01028be:	6a 04                	push   $0x4
f01028c0:	eb 46                	jmp    f0102908 <_alltraps>

f01028c2 <bdrgeexceed_handler>:
TRAPHANDLER_NOEC(bdrgeexceed_handler, 0x5)
f01028c2:	6a 00                	push   $0x0
f01028c4:	6a 05                	push   $0x5
f01028c6:	eb 40                	jmp    f0102908 <_alltraps>

f01028c8 <invalidop_handler>:
TRAPHANDLER_NOEC(invalidop_handler, 0x6)
f01028c8:	6a 00                	push   $0x0
f01028ca:	6a 06                	push   $0x6
f01028cc:	eb 3a                	jmp    f0102908 <_alltraps>

f01028ce <nomathcopro_handler>:
TRAPHANDLER_NOEC(nomathcopro_handler, 0x7)
f01028ce:	6a 00                	push   $0x0
f01028d0:	6a 07                	push   $0x7
f01028d2:	eb 34                	jmp    f0102908 <_alltraps>

f01028d4 <dbfault_handler>:
TRAPHANDLER(dbfault_handler, 0x8)
f01028d4:	6a 08                	push   $0x8
f01028d6:	eb 30                	jmp    f0102908 <_alltraps>

f01028d8 <invalidTSS_handler>:
TRAPHANDLER(invalidTSS_handler, 0xA)
f01028d8:	6a 0a                	push   $0xa
f01028da:	eb 2c                	jmp    f0102908 <_alltraps>

f01028dc <sgmtnotpresent_handler>:
TRAPHANDLER(sgmtnotpresent_handler, 0xB)
f01028dc:	6a 0b                	push   $0xb
f01028de:	eb 28                	jmp    f0102908 <_alltraps>

f01028e0 <stacksgmtfault_handler>:
TRAPHANDLER(stacksgmtfault_handler,0xC)
f01028e0:	6a 0c                	push   $0xc
f01028e2:	eb 24                	jmp    f0102908 <_alltraps>

f01028e4 <generalprotection_handler>:
TRAPHANDLER(generalprotection_handler, 0xD)
f01028e4:	6a 0d                	push   $0xd
f01028e6:	eb 20                	jmp    f0102908 <_alltraps>

f01028e8 <pagefault_handler>:
TRAPHANDLER(pagefault_handler, 0xE)
f01028e8:	6a 0e                	push   $0xe
f01028ea:	eb 1c                	jmp    f0102908 <_alltraps>

f01028ec <FPUerror_handler>:
TRAPHANDLER_NOEC(FPUerror_handler, 0x10)
f01028ec:	6a 00                	push   $0x0
f01028ee:	6a 10                	push   $0x10
f01028f0:	eb 16                	jmp    f0102908 <_alltraps>

f01028f2 <alignmentcheck_handler>:
TRAPHANDLER(alignmentcheck_handler, 0x11)
f01028f2:	6a 11                	push   $0x11
f01028f4:	eb 12                	jmp    f0102908 <_alltraps>

f01028f6 <machinecheck_handler>:
TRAPHANDLER_NOEC(machinecheck_handler, 0x12)
f01028f6:	6a 00                	push   $0x0
f01028f8:	6a 12                	push   $0x12
f01028fa:	eb 0c                	jmp    f0102908 <_alltraps>

f01028fc <SIMDFPexception_handler>:
TRAPHANDLER_NOEC(SIMDFPexception_handler, 0x13)
f01028fc:	6a 00                	push   $0x0
f01028fe:	6a 13                	push   $0x13
f0102900:	eb 06                	jmp    f0102908 <_alltraps>

f0102902 <systemcall_handler>:
TRAPHANDLER_NOEC(systemcall_handler, 0x30)
f0102902:	6a 00                	push   $0x0
f0102904:	6a 30                	push   $0x30
f0102906:	eb 00                	jmp    f0102908 <_alltraps>

f0102908 <_alltraps>:
/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
	pushw $0
f0102908:	66 6a 00             	pushw  $0x0
	pushw %ds
f010290b:	66 1e                	pushw  %ds
	pushw $0
f010290d:	66 6a 00             	pushw  $0x0
	pushw %es
f0102910:	66 06                	pushw  %es
	pushal
f0102912:	60                   	pusha  
	pushl %esp
f0102913:	54                   	push   %esp
	movw $(GD_KD),%ax
f0102914:	66 b8 10 00          	mov    $0x10,%ax
	movw %ax,%ds
f0102918:	8e d8                	mov    %eax,%ds
	movw %ax,%es
f010291a:	8e c0                	mov    %eax,%es
	call trap
f010291c:	e8 89 fd ff ff       	call   f01026aa <trap>

f0102921 <sched_yield>:


// Choose a user environment to run and run it.
void
sched_yield(void)
{
f0102921:	55                   	push   %ebp
f0102922:	89 e5                	mov    %esp,%ebp
f0102924:	53                   	push   %ebx
f0102925:	83 ec 14             	sub    $0x14,%esp

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0102928:	8b 1d 48 f2 21 f0    	mov    0xf021f248,%ebx
f010292e:	89 d8                	mov    %ebx,%eax
	// LAB 4: Your code here.

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0102930:	ba 00 00 00 00       	mov    $0x0,%edx
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0102935:	83 78 50 01          	cmpl   $0x1,0x50(%eax)
f0102939:	74 0b                	je     f0102946 <sched_yield+0x25>
		    (envs[i].env_status == ENV_RUNNABLE ||
f010293b:	8b 48 54             	mov    0x54(%eax),%ecx
f010293e:	83 e9 02             	sub    $0x2,%ecx

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0102941:	83 f9 01             	cmp    $0x1,%ecx
f0102944:	76 10                	jbe    f0102956 <sched_yield+0x35>
	// LAB 4: Your code here.

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0102946:	83 c2 01             	add    $0x1,%edx
f0102949:	83 c0 7c             	add    $0x7c,%eax
f010294c:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0102952:	75 e1                	jne    f0102935 <sched_yield+0x14>
f0102954:	eb 08                	jmp    f010295e <sched_yield+0x3d>
		if (envs[i].env_type != ENV_TYPE_IDLE &&
		    (envs[i].env_status == ENV_RUNNABLE ||
		     envs[i].env_status == ENV_RUNNING))
			break;
	}
	if (i == NENV) {
f0102956:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f010295c:	75 1a                	jne    f0102978 <sched_yield+0x57>
		cprintf("No more runnable environments!\n");
f010295e:	c7 04 24 b0 52 10 f0 	movl   $0xf01052b0,(%esp)
f0102965:	e8 f7 f6 ff ff       	call   f0102061 <cprintf>
		while (1)
			monitor(NULL);
f010296a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102971:	e8 4c e0 ff ff       	call   f01009c2 <monitor>
f0102976:	eb f2                	jmp    f010296a <sched_yield+0x49>
	}

	// Run this CPU's idle environment when nothing else is runnable.
	idle = &envs[cpunum()];
f0102978:	e8 d6 14 00 00       	call   f0103e53 <cpunum>
f010297d:	6b c0 7c             	imul   $0x7c,%eax,%eax
f0102980:	01 c3                	add    %eax,%ebx
	if (!(idle->env_status == ENV_RUNNABLE || idle->env_status == ENV_RUNNING))
f0102982:	8b 43 54             	mov    0x54(%ebx),%eax
f0102985:	83 e8 02             	sub    $0x2,%eax
f0102988:	83 f8 01             	cmp    $0x1,%eax
f010298b:	76 25                	jbe    f01029b2 <sched_yield+0x91>
		panic("CPU %d: No idle environment!", cpunum());
f010298d:	e8 c1 14 00 00       	call   f0103e53 <cpunum>
f0102992:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102996:	c7 44 24 08 d0 52 10 	movl   $0xf01052d0,0x8(%esp)
f010299d:	f0 
f010299e:	c7 44 24 04 33 00 00 	movl   $0x33,0x4(%esp)
f01029a5:	00 
f01029a6:	c7 04 24 ed 52 10 f0 	movl   $0xf01052ed,(%esp)
f01029ad:	e8 8e d6 ff ff       	call   f0100040 <_panic>
	env_run(idle);
f01029b2:	89 1c 24             	mov    %ebx,(%esp)
f01029b5:	e8 a4 f4 ff ff       	call   f0101e5e <env_run>
f01029ba:	66 90                	xchg   %ax,%ax
f01029bc:	66 90                	xchg   %ax,%ax
f01029be:	66 90                	xchg   %ax,%ax

f01029c0 <syscall>:
}

// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
f01029c0:	55                   	push   %ebp
f01029c1:	89 e5                	mov    %esp,%ebp
f01029c3:	53                   	push   %ebx
f01029c4:	83 ec 24             	sub    $0x24,%esp
f01029c7:	8b 45 08             	mov    0x8(%ebp),%eax
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
	switch(syscallno){
f01029ca:	83 f8 01             	cmp    $0x1,%eax
f01029cd:	74 66                	je     f0102a35 <syscall+0x75>
f01029cf:	83 f8 01             	cmp    $0x1,%eax
f01029d2:	72 11                	jb     f01029e5 <syscall+0x25>
f01029d4:	83 f8 02             	cmp    $0x2,%eax
f01029d7:	74 66                	je     f0102a3f <syscall+0x7f>
f01029d9:	83 f8 03             	cmp    $0x3,%eax
f01029dc:	74 78                	je     f0102a56 <syscall+0x96>
f01029de:	66 90                	xchg   %ax,%ax
f01029e0:	e9 03 01 00 00       	jmp    f0102ae8 <syscall+0x128>
static void
sys_cputs(const char *s, size_t len)
{
	// Check that the user has permission to read memory [s, s+len).
	// Destroy the environment if not.
	user_mem_assert(curenv,s,len,0);
f01029e5:	e8 69 14 00 00       	call   f0103e53 <cpunum>
f01029ea:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f01029f1:	00 
f01029f2:	8b 4d 10             	mov    0x10(%ebp),%ecx
f01029f5:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01029f9:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01029fc:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0102a00:	6b c0 74             	imul   $0x74,%eax,%eax
f0102a03:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102a09:	89 04 24             	mov    %eax,(%esp)
f0102a0c:	e8 6b ec ff ff       	call   f010167c <user_mem_assert>
	// LAB 3: Your code here.
	// Print the string supplied by the user.
	cprintf("%.*s", len, s);
f0102a11:	8b 45 0c             	mov    0xc(%ebp),%eax
f0102a14:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102a18:	8b 45 10             	mov    0x10(%ebp),%eax
f0102a1b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102a1f:	c7 04 24 fa 52 10 f0 	movl   $0xf01052fa,(%esp)
f0102a26:	e8 36 f6 ff ff       	call   f0102061 <cprintf>
	// Return any appropriate return value.
	// LAB 3: Your code here.
	switch(syscallno){
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
f0102a2b:	b8 00 00 00 00       	mov    $0x0,%eax
f0102a30:	e9 b8 00 00 00       	jmp    f0102aed <syscall+0x12d>
// Read a character from the system console without blocking.
// Returns the character, or 0 if there is no input waiting.
static int
sys_cgetc(void)
{
	return cons_getc();
f0102a35:	e8 2b dc ff ff       	call   f0100665 <cons_getc>
	switch(syscallno){
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case(SYS_cgetc):
			return sys_cgetc();
f0102a3a:	e9 ae 00 00 00       	jmp    f0102aed <syscall+0x12d>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f0102a3f:	90                   	nop
f0102a40:	e8 0e 14 00 00       	call   f0103e53 <cpunum>
f0102a45:	6b c0 74             	imul   $0x74,%eax,%eax
f0102a48:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102a4e:	8b 40 48             	mov    0x48(%eax),%eax
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case(SYS_cgetc):
			return sys_cgetc();
		case(SYS_getenvid):
			return sys_getenvid();
f0102a51:	e9 97 00 00 00       	jmp    f0102aed <syscall+0x12d>
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0102a56:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0102a5d:	00 
f0102a5e:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0102a61:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102a65:	8b 45 0c             	mov    0xc(%ebp),%eax
f0102a68:	89 04 24             	mov    %eax,(%esp)
f0102a6b:	e8 64 ec ff ff       	call   f01016d4 <envid2env>
		return r;
f0102a70:	89 c2                	mov    %eax,%edx
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0102a72:	85 c0                	test   %eax,%eax
f0102a74:	78 6e                	js     f0102ae4 <syscall+0x124>
		return r;
	if (e == curenv)
f0102a76:	e8 d8 13 00 00       	call   f0103e53 <cpunum>
f0102a7b:	8b 55 f4             	mov    -0xc(%ebp),%edx
f0102a7e:	6b c0 74             	imul   $0x74,%eax,%eax
f0102a81:	39 90 28 00 22 f0    	cmp    %edx,-0xfddffd8(%eax)
f0102a87:	75 23                	jne    f0102aac <syscall+0xec>
		cprintf("[%08x] exiting gracefully\n", curenv->env_id);
f0102a89:	e8 c5 13 00 00       	call   f0103e53 <cpunum>
f0102a8e:	6b c0 74             	imul   $0x74,%eax,%eax
f0102a91:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102a97:	8b 40 48             	mov    0x48(%eax),%eax
f0102a9a:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102a9e:	c7 04 24 ff 52 10 f0 	movl   $0xf01052ff,(%esp)
f0102aa5:	e8 b7 f5 ff ff       	call   f0102061 <cprintf>
f0102aaa:	eb 28                	jmp    f0102ad4 <syscall+0x114>
	else
		cprintf("[%08x] destroying %08x\n", curenv->env_id, e->env_id);
f0102aac:	8b 5a 48             	mov    0x48(%edx),%ebx
f0102aaf:	e8 9f 13 00 00       	call   f0103e53 <cpunum>
f0102ab4:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0102ab8:	6b c0 74             	imul   $0x74,%eax,%eax
f0102abb:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102ac1:	8b 40 48             	mov    0x48(%eax),%eax
f0102ac4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102ac8:	c7 04 24 1a 53 10 f0 	movl   $0xf010531a,(%esp)
f0102acf:	e8 8d f5 ff ff       	call   f0102061 <cprintf>
	env_destroy(e);
f0102ad4:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0102ad7:	89 04 24             	mov    %eax,(%esp)
f0102ada:	e8 de f2 ff ff       	call   f0101dbd <env_destroy>
	return 0;
f0102adf:	ba 00 00 00 00       	mov    $0x0,%edx
		case(SYS_cgetc):
			return sys_cgetc();
		case(SYS_getenvid):
			return sys_getenvid();
		case(SYS_env_destroy):
			return sys_env_destroy((envid_t) a1);
f0102ae4:	89 d0                	mov    %edx,%eax
f0102ae6:	eb 05                	jmp    f0102aed <syscall+0x12d>
		default:
			return -E_INVAL;
f0102ae8:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
	}
	//panic("syscall not implemented");
}
f0102aed:	83 c4 24             	add    $0x24,%esp
f0102af0:	5b                   	pop    %ebx
f0102af1:	5d                   	pop    %ebp
f0102af2:	c3                   	ret    
f0102af3:	66 90                	xchg   %ax,%ax
f0102af5:	66 90                	xchg   %ax,%ax
f0102af7:	66 90                	xchg   %ax,%ax
f0102af9:	66 90                	xchg   %ax,%ax
f0102afb:	66 90                	xchg   %ax,%ax
f0102afd:	66 90                	xchg   %ax,%ax
f0102aff:	90                   	nop

f0102b00 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0102b00:	55                   	push   %ebp
f0102b01:	89 e5                	mov    %esp,%ebp
f0102b03:	57                   	push   %edi
f0102b04:	56                   	push   %esi
f0102b05:	53                   	push   %ebx
f0102b06:	83 ec 14             	sub    $0x14,%esp
f0102b09:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0102b0c:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f0102b0f:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0102b12:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0102b15:	8b 1a                	mov    (%edx),%ebx
f0102b17:	8b 01                	mov    (%ecx),%eax
f0102b19:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f0102b1c:	39 c3                	cmp    %eax,%ebx
f0102b1e:	0f 8f 9a 00 00 00    	jg     f0102bbe <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f0102b24:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0102b2b:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0102b2e:	01 d8                	add    %ebx,%eax
f0102b30:	89 c7                	mov    %eax,%edi
f0102b32:	c1 ef 1f             	shr    $0x1f,%edi
f0102b35:	01 c7                	add    %eax,%edi
f0102b37:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0102b39:	39 df                	cmp    %ebx,%edi
f0102b3b:	0f 8c c4 00 00 00    	jl     f0102c05 <stab_binsearch+0x105>
f0102b41:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0102b44:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0102b47:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f0102b4a:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f0102b4e:	39 f0                	cmp    %esi,%eax
f0102b50:	0f 84 b4 00 00 00    	je     f0102c0a <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0102b56:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f0102b58:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0102b5b:	39 d8                	cmp    %ebx,%eax
f0102b5d:	0f 8c a2 00 00 00    	jl     f0102c05 <stab_binsearch+0x105>
f0102b63:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f0102b67:	83 ea 0c             	sub    $0xc,%edx
f0102b6a:	39 f1                	cmp    %esi,%ecx
f0102b6c:	75 ea                	jne    f0102b58 <stab_binsearch+0x58>
f0102b6e:	e9 99 00 00 00       	jmp    f0102c0c <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0102b73:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0102b76:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f0102b78:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0102b7b:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0102b82:	eb 2b                	jmp    f0102baf <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0102b84:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0102b87:	76 14                	jbe    f0102b9d <stab_binsearch+0x9d>
			*region_right = m - 1;
f0102b89:	83 e8 01             	sub    $0x1,%eax
f0102b8c:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0102b8f:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0102b92:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0102b94:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0102b9b:	eb 12                	jmp    f0102baf <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0102b9d:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0102ba0:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f0102ba2:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f0102ba6:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0102ba8:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f0102baf:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0102bb2:	0f 8e 73 ff ff ff    	jle    f0102b2b <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0102bb8:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f0102bbc:	75 0f                	jne    f0102bcd <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f0102bbe:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0102bc1:	8b 00                	mov    (%eax),%eax
f0102bc3:	83 e8 01             	sub    $0x1,%eax
f0102bc6:	8b 75 e0             	mov    -0x20(%ebp),%esi
f0102bc9:	89 06                	mov    %eax,(%esi)
f0102bcb:	eb 57                	jmp    f0102c24 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0102bcd:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0102bd0:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0102bd2:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0102bd5:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0102bd7:	39 c8                	cmp    %ecx,%eax
f0102bd9:	7e 23                	jle    f0102bfe <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0102bdb:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0102bde:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0102be1:	8d 14 97             	lea    (%edi,%edx,4),%edx
f0102be4:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f0102be8:	39 f3                	cmp    %esi,%ebx
f0102bea:	74 12                	je     f0102bfe <stab_binsearch+0xfe>
		     l--)
f0102bec:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0102bef:	39 c8                	cmp    %ecx,%eax
f0102bf1:	7e 0b                	jle    f0102bfe <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0102bf3:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f0102bf7:	83 ea 0c             	sub    $0xc,%edx
f0102bfa:	39 f3                	cmp    %esi,%ebx
f0102bfc:	75 ee                	jne    f0102bec <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f0102bfe:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0102c01:	89 06                	mov    %eax,(%esi)
f0102c03:	eb 1f                	jmp    f0102c24 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0102c05:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0102c08:	eb a5                	jmp    f0102baf <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0102c0a:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0102c0c:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0102c0f:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0102c12:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0102c16:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0102c19:	0f 82 54 ff ff ff    	jb     f0102b73 <stab_binsearch+0x73>
f0102c1f:	e9 60 ff ff ff       	jmp    f0102b84 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0102c24:	83 c4 14             	add    $0x14,%esp
f0102c27:	5b                   	pop    %ebx
f0102c28:	5e                   	pop    %esi
f0102c29:	5f                   	pop    %edi
f0102c2a:	5d                   	pop    %ebp
f0102c2b:	c3                   	ret    

f0102c2c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0102c2c:	55                   	push   %ebp
f0102c2d:	89 e5                	mov    %esp,%ebp
f0102c2f:	57                   	push   %edi
f0102c30:	56                   	push   %esi
f0102c31:	53                   	push   %ebx
f0102c32:	83 ec 3c             	sub    $0x3c,%esp
f0102c35:	8b 7d 08             	mov    0x8(%ebp),%edi
f0102c38:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0102c3b:	c7 06 32 53 10 f0    	movl   $0xf0105332,(%esi)
	info->eip_line = 0;
f0102c41:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0102c48:	c7 46 08 32 53 10 f0 	movl   $0xf0105332,0x8(%esi)
	info->eip_fn_namelen = 9;
f0102c4f:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0102c56:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0102c59:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0102c60:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f0102c66:	0f 87 ca 00 00 00    	ja     f0102d36 <debuginfo_eip+0x10a>
		const struct UserStabData *usd = (const struct UserStabData *) USTABDATA;

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
f0102c6c:	e8 e2 11 00 00       	call   f0103e53 <cpunum>
f0102c71:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0102c78:	00 
f0102c79:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
f0102c80:	00 
f0102c81:	c7 44 24 04 00 00 20 	movl   $0x200000,0x4(%esp)
f0102c88:	00 
f0102c89:	6b c0 74             	imul   $0x74,%eax,%eax
f0102c8c:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102c92:	89 04 24             	mov    %eax,(%esp)
f0102c95:	e8 43 e9 ff ff       	call   f01015dd <user_mem_check>
f0102c9a:	85 c0                	test   %eax,%eax
f0102c9c:	0f 85 12 02 00 00    	jne    f0102eb4 <debuginfo_eip+0x288>
			return -1;
		stabs = usd->stabs;
f0102ca2:	a1 00 00 20 00       	mov    0x200000,%eax
f0102ca7:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f0102caa:	8b 1d 04 00 20 00    	mov    0x200004,%ebx
		stabstr = usd->stabstr;
f0102cb0:	8b 15 08 00 20 00    	mov    0x200008,%edx
f0102cb6:	89 55 d0             	mov    %edx,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f0102cb9:	a1 0c 00 20 00       	mov    0x20000c,%eax
f0102cbe:	89 45 cc             	mov    %eax,-0x34(%ebp)

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
f0102cc1:	e8 8d 11 00 00       	call   f0103e53 <cpunum>
f0102cc6:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0102ccd:	00 
f0102cce:	89 da                	mov    %ebx,%edx
f0102cd0:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0102cd3:	29 ca                	sub    %ecx,%edx
f0102cd5:	c1 fa 02             	sar    $0x2,%edx
f0102cd8:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f0102cde:	89 54 24 08          	mov    %edx,0x8(%esp)
f0102ce2:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0102ce6:	6b c0 74             	imul   $0x74,%eax,%eax
f0102ce9:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102cef:	89 04 24             	mov    %eax,(%esp)
f0102cf2:	e8 e6 e8 ff ff       	call   f01015dd <user_mem_check>
f0102cf7:	85 c0                	test   %eax,%eax
f0102cf9:	0f 85 bc 01 00 00    	jne    f0102ebb <debuginfo_eip+0x28f>
f0102cff:	e8 4f 11 00 00       	call   f0103e53 <cpunum>
f0102d04:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0102d0b:	00 
f0102d0c:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0102d0f:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0102d12:	29 ca                	sub    %ecx,%edx
f0102d14:	89 54 24 08          	mov    %edx,0x8(%esp)
f0102d18:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0102d1c:	6b c0 74             	imul   $0x74,%eax,%eax
f0102d1f:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102d25:	89 04 24             	mov    %eax,(%esp)
f0102d28:	e8 b0 e8 ff ff       	call   f01015dd <user_mem_check>
f0102d2d:	85 c0                	test   %eax,%eax
f0102d2f:	74 1f                	je     f0102d50 <debuginfo_eip+0x124>
f0102d31:	e9 8c 01 00 00       	jmp    f0102ec2 <debuginfo_eip+0x296>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f0102d36:	c7 45 cc 68 14 11 f0 	movl   $0xf0111468,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f0102d3d:	c7 45 d0 0d e1 10 f0 	movl   $0xf010e10d,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f0102d44:	bb 0c e1 10 f0       	mov    $0xf010e10c,%ebx
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f0102d49:	c7 45 d4 14 58 10 f0 	movl   $0xf0105814,-0x2c(%ebp)
		    return -1;
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0102d50:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0102d53:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0102d56:	0f 83 6d 01 00 00    	jae    f0102ec9 <debuginfo_eip+0x29d>
f0102d5c:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f0102d60:	0f 85 6a 01 00 00    	jne    f0102ed0 <debuginfo_eip+0x2a4>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0102d66:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0102d6d:	2b 5d d4             	sub    -0x2c(%ebp),%ebx
f0102d70:	c1 fb 02             	sar    $0x2,%ebx
f0102d73:	69 c3 ab aa aa aa    	imul   $0xaaaaaaab,%ebx,%eax
f0102d79:	83 e8 01             	sub    $0x1,%eax
f0102d7c:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0102d7f:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102d83:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0102d8a:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0102d8d:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0102d90:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0102d93:	89 d8                	mov    %ebx,%eax
f0102d95:	e8 66 fd ff ff       	call   f0102b00 <stab_binsearch>
	if (lfile == 0)
f0102d9a:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0102d9d:	85 c0                	test   %eax,%eax
f0102d9f:	0f 84 32 01 00 00    	je     f0102ed7 <debuginfo_eip+0x2ab>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0102da5:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0102da8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0102dab:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0102dae:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102db2:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0102db9:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0102dbc:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0102dbf:	89 d8                	mov    %ebx,%eax
f0102dc1:	e8 3a fd ff ff       	call   f0102b00 <stab_binsearch>

	if (lfun <= rfun) {
f0102dc6:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f0102dc9:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f0102dcc:	7f 23                	jg     f0102df1 <debuginfo_eip+0x1c5>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0102dce:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0102dd1:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0102dd4:	8d 04 87             	lea    (%edi,%eax,4),%eax
f0102dd7:	8b 10                	mov    (%eax),%edx
f0102dd9:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0102ddc:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f0102ddf:	39 ca                	cmp    %ecx,%edx
f0102de1:	73 06                	jae    f0102de9 <debuginfo_eip+0x1bd>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0102de3:	03 55 d0             	add    -0x30(%ebp),%edx
f0102de6:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f0102de9:	8b 40 08             	mov    0x8(%eax),%eax
f0102dec:	89 46 10             	mov    %eax,0x10(%esi)
f0102def:	eb 06                	jmp    f0102df7 <debuginfo_eip+0x1cb>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0102df1:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f0102df4:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0102df7:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0102dfe:	00 
f0102dff:	8b 46 08             	mov    0x8(%esi),%eax
f0102e02:	89 04 24             	mov    %eax,(%esp)
f0102e05:	e8 85 09 00 00       	call   f010378f <strfind>
f0102e0a:	2b 46 08             	sub    0x8(%esi),%eax
f0102e0d:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0102e10:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0102e13:	39 fb                	cmp    %edi,%ebx
f0102e15:	7c 5d                	jl     f0102e74 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0102e17:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0102e1a:	c1 e0 02             	shl    $0x2,%eax
f0102e1d:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0102e20:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f0102e23:	89 55 c8             	mov    %edx,-0x38(%ebp)
f0102e26:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f0102e2a:	80 fa 84             	cmp    $0x84,%dl
f0102e2d:	74 2d                	je     f0102e5c <debuginfo_eip+0x230>
f0102e2f:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f0102e33:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0102e36:	eb 15                	jmp    f0102e4d <debuginfo_eip+0x221>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0102e38:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0102e3b:	39 fb                	cmp    %edi,%ebx
f0102e3d:	7c 35                	jl     f0102e74 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0102e3f:	89 c1                	mov    %eax,%ecx
f0102e41:	83 e8 0c             	sub    $0xc,%eax
f0102e44:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0102e48:	80 fa 84             	cmp    $0x84,%dl
f0102e4b:	74 0f                	je     f0102e5c <debuginfo_eip+0x230>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0102e4d:	80 fa 64             	cmp    $0x64,%dl
f0102e50:	75 e6                	jne    f0102e38 <debuginfo_eip+0x20c>
f0102e52:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f0102e56:	74 e0                	je     f0102e38 <debuginfo_eip+0x20c>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0102e58:	39 df                	cmp    %ebx,%edi
f0102e5a:	7f 18                	jg     f0102e74 <debuginfo_eip+0x248>
f0102e5c:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0102e5f:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0102e62:	8b 04 87             	mov    (%edi,%eax,4),%eax
f0102e65:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0102e68:	2b 55 d0             	sub    -0x30(%ebp),%edx
f0102e6b:	39 d0                	cmp    %edx,%eax
f0102e6d:	73 05                	jae    f0102e74 <debuginfo_eip+0x248>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0102e6f:	03 45 d0             	add    -0x30(%ebp),%eax
f0102e72:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0102e74:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0102e77:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0102e7a:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0102e7f:	39 ca                	cmp    %ecx,%edx
f0102e81:	7d 75                	jge    f0102ef8 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
f0102e83:	8d 42 01             	lea    0x1(%edx),%eax
f0102e86:	39 c1                	cmp    %eax,%ecx
f0102e88:	7e 54                	jle    f0102ede <debuginfo_eip+0x2b2>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0102e8a:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0102e8d:	c1 e2 02             	shl    $0x2,%edx
f0102e90:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0102e93:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f0102e98:	75 4b                	jne    f0102ee5 <debuginfo_eip+0x2b9>
f0102e9a:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f0102e9e:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0102ea2:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0102ea5:	39 c1                	cmp    %eax,%ecx
f0102ea7:	7e 43                	jle    f0102eec <debuginfo_eip+0x2c0>
f0102ea9:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0102eac:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0102eb0:	74 ec                	je     f0102e9e <debuginfo_eip+0x272>
f0102eb2:	eb 3f                	jmp    f0102ef3 <debuginfo_eip+0x2c7>

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
			return -1;
f0102eb4:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0102eb9:	eb 3d                	jmp    f0102ef8 <debuginfo_eip+0x2cc>

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
		 {
		    return -1;
f0102ebb:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0102ec0:	eb 36                	jmp    f0102ef8 <debuginfo_eip+0x2cc>
f0102ec2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0102ec7:	eb 2f                	jmp    f0102ef8 <debuginfo_eip+0x2cc>
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0102ec9:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0102ece:	eb 28                	jmp    f0102ef8 <debuginfo_eip+0x2cc>
f0102ed0:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0102ed5:	eb 21                	jmp    f0102ef8 <debuginfo_eip+0x2cc>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0102ed7:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0102edc:	eb 1a                	jmp    f0102ef8 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0102ede:	b8 00 00 00 00       	mov    $0x0,%eax
f0102ee3:	eb 13                	jmp    f0102ef8 <debuginfo_eip+0x2cc>
f0102ee5:	b8 00 00 00 00       	mov    $0x0,%eax
f0102eea:	eb 0c                	jmp    f0102ef8 <debuginfo_eip+0x2cc>
f0102eec:	b8 00 00 00 00       	mov    $0x0,%eax
f0102ef1:	eb 05                	jmp    f0102ef8 <debuginfo_eip+0x2cc>
f0102ef3:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0102ef8:	83 c4 3c             	add    $0x3c,%esp
f0102efb:	5b                   	pop    %ebx
f0102efc:	5e                   	pop    %esi
f0102efd:	5f                   	pop    %edi
f0102efe:	5d                   	pop    %ebp
f0102eff:	c3                   	ret    

f0102f00 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0102f00:	55                   	push   %ebp
f0102f01:	89 e5                	mov    %esp,%ebp
f0102f03:	57                   	push   %edi
f0102f04:	56                   	push   %esi
f0102f05:	53                   	push   %ebx
f0102f06:	83 ec 3c             	sub    $0x3c,%esp
f0102f09:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0102f0c:	89 d7                	mov    %edx,%edi
f0102f0e:	8b 45 08             	mov    0x8(%ebp),%eax
f0102f11:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0102f14:	8b 75 0c             	mov    0xc(%ebp),%esi
f0102f17:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f0102f1a:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0102f1d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0102f22:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0102f25:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0102f28:	39 f1                	cmp    %esi,%ecx
f0102f2a:	72 14                	jb     f0102f40 <printnum+0x40>
f0102f2c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f0102f2f:	76 0f                	jbe    f0102f40 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0102f31:	8b 45 14             	mov    0x14(%ebp),%eax
f0102f34:	8d 70 ff             	lea    -0x1(%eax),%esi
f0102f37:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0102f3a:	85 f6                	test   %esi,%esi
f0102f3c:	7f 60                	jg     f0102f9e <printnum+0x9e>
f0102f3e:	eb 72                	jmp    f0102fb2 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0102f40:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0102f43:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0102f47:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0102f4a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0102f4d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0102f51:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102f55:	8b 44 24 08          	mov    0x8(%esp),%eax
f0102f59:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0102f5d:	89 c3                	mov    %eax,%ebx
f0102f5f:	89 d6                	mov    %edx,%esi
f0102f61:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0102f64:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0102f67:	89 54 24 08          	mov    %edx,0x8(%esp)
f0102f6b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0102f6f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0102f72:	89 04 24             	mov    %eax,(%esp)
f0102f75:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102f78:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102f7c:	e8 3f 13 00 00       	call   f01042c0 <__udivdi3>
f0102f81:	89 d9                	mov    %ebx,%ecx
f0102f83:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0102f87:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0102f8b:	89 04 24             	mov    %eax,(%esp)
f0102f8e:	89 54 24 04          	mov    %edx,0x4(%esp)
f0102f92:	89 fa                	mov    %edi,%edx
f0102f94:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0102f97:	e8 64 ff ff ff       	call   f0102f00 <printnum>
f0102f9c:	eb 14                	jmp    f0102fb2 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f0102f9e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102fa2:	8b 45 18             	mov    0x18(%ebp),%eax
f0102fa5:	89 04 24             	mov    %eax,(%esp)
f0102fa8:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0102faa:	83 ee 01             	sub    $0x1,%esi
f0102fad:	75 ef                	jne    f0102f9e <printnum+0x9e>
f0102faf:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0102fb2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102fb6:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0102fba:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0102fbd:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0102fc0:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102fc4:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0102fc8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0102fcb:	89 04 24             	mov    %eax,(%esp)
f0102fce:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102fd1:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102fd5:	e8 16 14 00 00       	call   f01043f0 <__umoddi3>
f0102fda:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102fde:	0f be 80 3c 53 10 f0 	movsbl -0xfefacc4(%eax),%eax
f0102fe5:	89 04 24             	mov    %eax,(%esp)
f0102fe8:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0102feb:	ff d0                	call   *%eax
}
f0102fed:	83 c4 3c             	add    $0x3c,%esp
f0102ff0:	5b                   	pop    %ebx
f0102ff1:	5e                   	pop    %esi
f0102ff2:	5f                   	pop    %edi
f0102ff3:	5d                   	pop    %ebp
f0102ff4:	c3                   	ret    

f0102ff5 <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0102ff5:	55                   	push   %ebp
f0102ff6:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0102ff8:	83 fa 01             	cmp    $0x1,%edx
f0102ffb:	7e 0e                	jle    f010300b <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f0102ffd:	8b 10                	mov    (%eax),%edx
f0102fff:	8d 4a 08             	lea    0x8(%edx),%ecx
f0103002:	89 08                	mov    %ecx,(%eax)
f0103004:	8b 02                	mov    (%edx),%eax
f0103006:	8b 52 04             	mov    0x4(%edx),%edx
f0103009:	eb 22                	jmp    f010302d <getuint+0x38>
	else if (lflag)
f010300b:	85 d2                	test   %edx,%edx
f010300d:	74 10                	je     f010301f <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f010300f:	8b 10                	mov    (%eax),%edx
f0103011:	8d 4a 04             	lea    0x4(%edx),%ecx
f0103014:	89 08                	mov    %ecx,(%eax)
f0103016:	8b 02                	mov    (%edx),%eax
f0103018:	ba 00 00 00 00       	mov    $0x0,%edx
f010301d:	eb 0e                	jmp    f010302d <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f010301f:	8b 10                	mov    (%eax),%edx
f0103021:	8d 4a 04             	lea    0x4(%edx),%ecx
f0103024:	89 08                	mov    %ecx,(%eax)
f0103026:	8b 02                	mov    (%edx),%eax
f0103028:	ba 00 00 00 00       	mov    $0x0,%edx
}
f010302d:	5d                   	pop    %ebp
f010302e:	c3                   	ret    

f010302f <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f010302f:	55                   	push   %ebp
f0103030:	89 e5                	mov    %esp,%ebp
f0103032:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0103035:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0103039:	8b 10                	mov    (%eax),%edx
f010303b:	3b 50 04             	cmp    0x4(%eax),%edx
f010303e:	73 0a                	jae    f010304a <sprintputch+0x1b>
		*b->buf++ = ch;
f0103040:	8d 4a 01             	lea    0x1(%edx),%ecx
f0103043:	89 08                	mov    %ecx,(%eax)
f0103045:	8b 45 08             	mov    0x8(%ebp),%eax
f0103048:	88 02                	mov    %al,(%edx)
}
f010304a:	5d                   	pop    %ebp
f010304b:	c3                   	ret    

f010304c <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f010304c:	55                   	push   %ebp
f010304d:	89 e5                	mov    %esp,%ebp
f010304f:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0103052:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0103055:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103059:	8b 45 10             	mov    0x10(%ebp),%eax
f010305c:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103060:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103063:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103067:	8b 45 08             	mov    0x8(%ebp),%eax
f010306a:	89 04 24             	mov    %eax,(%esp)
f010306d:	e8 02 00 00 00       	call   f0103074 <vprintfmt>
	va_end(ap);
}
f0103072:	c9                   	leave  
f0103073:	c3                   	ret    

f0103074 <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f0103074:	55                   	push   %ebp
f0103075:	89 e5                	mov    %esp,%ebp
f0103077:	57                   	push   %edi
f0103078:	56                   	push   %esi
f0103079:	53                   	push   %ebx
f010307a:	83 ec 3c             	sub    $0x3c,%esp
f010307d:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0103080:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0103083:	eb 18                	jmp    f010309d <vprintfmt+0x29>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f0103085:	85 c0                	test   %eax,%eax
f0103087:	0f 84 c3 03 00 00    	je     f0103450 <vprintfmt+0x3dc>
				return;
			putch(ch, putdat);
f010308d:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103091:	89 04 24             	mov    %eax,(%esp)
f0103094:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0103097:	89 f3                	mov    %esi,%ebx
f0103099:	eb 02                	jmp    f010309d <vprintfmt+0x29>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f010309b:	89 f3                	mov    %esi,%ebx
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f010309d:	8d 73 01             	lea    0x1(%ebx),%esi
f01030a0:	0f b6 03             	movzbl (%ebx),%eax
f01030a3:	83 f8 25             	cmp    $0x25,%eax
f01030a6:	75 dd                	jne    f0103085 <vprintfmt+0x11>
f01030a8:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f01030ac:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f01030b3:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f01030ba:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f01030c1:	ba 00 00 00 00       	mov    $0x0,%edx
f01030c6:	eb 1d                	jmp    f01030e5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01030c8:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f01030ca:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f01030ce:	eb 15                	jmp    f01030e5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01030d0:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f01030d2:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f01030d6:	eb 0d                	jmp    f01030e5 <vprintfmt+0x71>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f01030d8:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01030db:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01030de:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01030e5:	8d 5e 01             	lea    0x1(%esi),%ebx
f01030e8:	0f b6 06             	movzbl (%esi),%eax
f01030eb:	0f b6 c8             	movzbl %al,%ecx
f01030ee:	83 e8 23             	sub    $0x23,%eax
f01030f1:	3c 55                	cmp    $0x55,%al
f01030f3:	0f 87 2f 03 00 00    	ja     f0103428 <vprintfmt+0x3b4>
f01030f9:	0f b6 c0             	movzbl %al,%eax
f01030fc:	ff 24 85 00 54 10 f0 	jmp    *-0xfefac00(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0103103:	8d 41 d0             	lea    -0x30(%ecx),%eax
f0103106:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0103109:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f010310d:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0103110:	83 f9 09             	cmp    $0x9,%ecx
f0103113:	77 50                	ja     f0103165 <vprintfmt+0xf1>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103115:	89 de                	mov    %ebx,%esi
f0103117:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f010311a:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f010311d:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0103120:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0103124:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0103127:	8d 58 d0             	lea    -0x30(%eax),%ebx
f010312a:	83 fb 09             	cmp    $0x9,%ebx
f010312d:	76 eb                	jbe    f010311a <vprintfmt+0xa6>
f010312f:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0103132:	eb 33                	jmp    f0103167 <vprintfmt+0xf3>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0103134:	8b 45 14             	mov    0x14(%ebp),%eax
f0103137:	8d 48 04             	lea    0x4(%eax),%ecx
f010313a:	89 4d 14             	mov    %ecx,0x14(%ebp)
f010313d:	8b 00                	mov    (%eax),%eax
f010313f:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103142:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0103144:	eb 21                	jmp    f0103167 <vprintfmt+0xf3>
f0103146:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0103149:	85 c9                	test   %ecx,%ecx
f010314b:	b8 00 00 00 00       	mov    $0x0,%eax
f0103150:	0f 49 c1             	cmovns %ecx,%eax
f0103153:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103156:	89 de                	mov    %ebx,%esi
f0103158:	eb 8b                	jmp    f01030e5 <vprintfmt+0x71>
f010315a:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f010315c:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f0103163:	eb 80                	jmp    f01030e5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103165:	89 de                	mov    %ebx,%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0103167:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f010316b:	0f 89 74 ff ff ff    	jns    f01030e5 <vprintfmt+0x71>
f0103171:	e9 62 ff ff ff       	jmp    f01030d8 <vprintfmt+0x64>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0103176:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103179:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f010317b:	e9 65 ff ff ff       	jmp    f01030e5 <vprintfmt+0x71>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f0103180:	8b 45 14             	mov    0x14(%ebp),%eax
f0103183:	8d 50 04             	lea    0x4(%eax),%edx
f0103186:	89 55 14             	mov    %edx,0x14(%ebp)
f0103189:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010318d:	8b 00                	mov    (%eax),%eax
f010318f:	89 04 24             	mov    %eax,(%esp)
f0103192:	ff 55 08             	call   *0x8(%ebp)
			break;
f0103195:	e9 03 ff ff ff       	jmp    f010309d <vprintfmt+0x29>

		// error message
		case 'e':
			err = va_arg(ap, int);
f010319a:	8b 45 14             	mov    0x14(%ebp),%eax
f010319d:	8d 50 04             	lea    0x4(%eax),%edx
f01031a0:	89 55 14             	mov    %edx,0x14(%ebp)
f01031a3:	8b 00                	mov    (%eax),%eax
f01031a5:	99                   	cltd   
f01031a6:	31 d0                	xor    %edx,%eax
f01031a8:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f01031aa:	83 f8 08             	cmp    $0x8,%eax
f01031ad:	7f 0b                	jg     f01031ba <vprintfmt+0x146>
f01031af:	8b 14 85 60 55 10 f0 	mov    -0xfefaaa0(,%eax,4),%edx
f01031b6:	85 d2                	test   %edx,%edx
f01031b8:	75 20                	jne    f01031da <vprintfmt+0x166>
				printfmt(putch, putdat, "error %d", err);
f01031ba:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01031be:	c7 44 24 08 54 53 10 	movl   $0xf0105354,0x8(%esp)
f01031c5:	f0 
f01031c6:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01031ca:	8b 45 08             	mov    0x8(%ebp),%eax
f01031cd:	89 04 24             	mov    %eax,(%esp)
f01031d0:	e8 77 fe ff ff       	call   f010304c <printfmt>
f01031d5:	e9 c3 fe ff ff       	jmp    f010309d <vprintfmt+0x29>
			else
				printfmt(putch, putdat, "%s", p);
f01031da:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01031de:	c7 44 24 08 21 4d 10 	movl   $0xf0104d21,0x8(%esp)
f01031e5:	f0 
f01031e6:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01031ea:	8b 45 08             	mov    0x8(%ebp),%eax
f01031ed:	89 04 24             	mov    %eax,(%esp)
f01031f0:	e8 57 fe ff ff       	call   f010304c <printfmt>
f01031f5:	e9 a3 fe ff ff       	jmp    f010309d <vprintfmt+0x29>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01031fa:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01031fd:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0103200:	8b 45 14             	mov    0x14(%ebp),%eax
f0103203:	8d 50 04             	lea    0x4(%eax),%edx
f0103206:	89 55 14             	mov    %edx,0x14(%ebp)
f0103209:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f010320b:	85 c0                	test   %eax,%eax
f010320d:	ba 4d 53 10 f0       	mov    $0xf010534d,%edx
f0103212:	0f 45 d0             	cmovne %eax,%edx
f0103215:	89 55 d0             	mov    %edx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f0103218:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f010321c:	74 04                	je     f0103222 <vprintfmt+0x1ae>
f010321e:	85 f6                	test   %esi,%esi
f0103220:	7f 19                	jg     f010323b <vprintfmt+0x1c7>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0103222:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103225:	8d 70 01             	lea    0x1(%eax),%esi
f0103228:	0f b6 10             	movzbl (%eax),%edx
f010322b:	0f be c2             	movsbl %dl,%eax
f010322e:	85 c0                	test   %eax,%eax
f0103230:	0f 85 95 00 00 00    	jne    f01032cb <vprintfmt+0x257>
f0103236:	e9 85 00 00 00       	jmp    f01032c0 <vprintfmt+0x24c>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f010323b:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f010323f:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103242:	89 04 24             	mov    %eax,(%esp)
f0103245:	e8 88 03 00 00       	call   f01035d2 <strnlen>
f010324a:	29 c6                	sub    %eax,%esi
f010324c:	89 f0                	mov    %esi,%eax
f010324e:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0103251:	85 f6                	test   %esi,%esi
f0103253:	7e cd                	jle    f0103222 <vprintfmt+0x1ae>
					putch(padc, putdat);
f0103255:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0103259:	89 5d 10             	mov    %ebx,0x10(%ebp)
f010325c:	89 c3                	mov    %eax,%ebx
f010325e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103262:	89 34 24             	mov    %esi,(%esp)
f0103265:	ff 55 08             	call   *0x8(%ebp)
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0103268:	83 eb 01             	sub    $0x1,%ebx
f010326b:	75 f1                	jne    f010325e <vprintfmt+0x1ea>
f010326d:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0103270:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0103273:	eb ad                	jmp    f0103222 <vprintfmt+0x1ae>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f0103275:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0103279:	74 1e                	je     f0103299 <vprintfmt+0x225>
f010327b:	0f be d2             	movsbl %dl,%edx
f010327e:	83 ea 20             	sub    $0x20,%edx
f0103281:	83 fa 5e             	cmp    $0x5e,%edx
f0103284:	76 13                	jbe    f0103299 <vprintfmt+0x225>
					putch('?', putdat);
f0103286:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103289:	89 44 24 04          	mov    %eax,0x4(%esp)
f010328d:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f0103294:	ff 55 08             	call   *0x8(%ebp)
f0103297:	eb 0d                	jmp    f01032a6 <vprintfmt+0x232>
				else
					putch(ch, putdat);
f0103299:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f010329c:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01032a0:	89 04 24             	mov    %eax,(%esp)
f01032a3:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01032a6:	83 ef 01             	sub    $0x1,%edi
f01032a9:	83 c6 01             	add    $0x1,%esi
f01032ac:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f01032b0:	0f be c2             	movsbl %dl,%eax
f01032b3:	85 c0                	test   %eax,%eax
f01032b5:	75 20                	jne    f01032d7 <vprintfmt+0x263>
f01032b7:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f01032ba:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01032bd:	8b 5d 10             	mov    0x10(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01032c0:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01032c4:	7f 25                	jg     f01032eb <vprintfmt+0x277>
f01032c6:	e9 d2 fd ff ff       	jmp    f010309d <vprintfmt+0x29>
f01032cb:	89 7d 0c             	mov    %edi,0xc(%ebp)
f01032ce:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01032d1:	89 5d 10             	mov    %ebx,0x10(%ebp)
f01032d4:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01032d7:	85 db                	test   %ebx,%ebx
f01032d9:	78 9a                	js     f0103275 <vprintfmt+0x201>
f01032db:	83 eb 01             	sub    $0x1,%ebx
f01032de:	79 95                	jns    f0103275 <vprintfmt+0x201>
f01032e0:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f01032e3:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01032e6:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01032e9:	eb d5                	jmp    f01032c0 <vprintfmt+0x24c>
f01032eb:	8b 75 08             	mov    0x8(%ebp),%esi
f01032ee:	89 5d 10             	mov    %ebx,0x10(%ebp)
f01032f1:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f01032f4:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01032f8:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f01032ff:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0103301:	83 eb 01             	sub    $0x1,%ebx
f0103304:	75 ee                	jne    f01032f4 <vprintfmt+0x280>
f0103306:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0103309:	e9 8f fd ff ff       	jmp    f010309d <vprintfmt+0x29>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010330e:	83 fa 01             	cmp    $0x1,%edx
f0103311:	7e 16                	jle    f0103329 <vprintfmt+0x2b5>
		return va_arg(*ap, long long);
f0103313:	8b 45 14             	mov    0x14(%ebp),%eax
f0103316:	8d 50 08             	lea    0x8(%eax),%edx
f0103319:	89 55 14             	mov    %edx,0x14(%ebp)
f010331c:	8b 50 04             	mov    0x4(%eax),%edx
f010331f:	8b 00                	mov    (%eax),%eax
f0103321:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103324:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0103327:	eb 32                	jmp    f010335b <vprintfmt+0x2e7>
	else if (lflag)
f0103329:	85 d2                	test   %edx,%edx
f010332b:	74 18                	je     f0103345 <vprintfmt+0x2d1>
		return va_arg(*ap, long);
f010332d:	8b 45 14             	mov    0x14(%ebp),%eax
f0103330:	8d 50 04             	lea    0x4(%eax),%edx
f0103333:	89 55 14             	mov    %edx,0x14(%ebp)
f0103336:	8b 30                	mov    (%eax),%esi
f0103338:	89 75 d8             	mov    %esi,-0x28(%ebp)
f010333b:	89 f0                	mov    %esi,%eax
f010333d:	c1 f8 1f             	sar    $0x1f,%eax
f0103340:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0103343:	eb 16                	jmp    f010335b <vprintfmt+0x2e7>
	else
		return va_arg(*ap, int);
f0103345:	8b 45 14             	mov    0x14(%ebp),%eax
f0103348:	8d 50 04             	lea    0x4(%eax),%edx
f010334b:	89 55 14             	mov    %edx,0x14(%ebp)
f010334e:	8b 30                	mov    (%eax),%esi
f0103350:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0103353:	89 f0                	mov    %esi,%eax
f0103355:	c1 f8 1f             	sar    $0x1f,%eax
f0103358:	89 45 dc             	mov    %eax,-0x24(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f010335b:	8b 45 d8             	mov    -0x28(%ebp),%eax
f010335e:	8b 55 dc             	mov    -0x24(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f0103361:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0103366:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f010336a:	0f 89 80 00 00 00    	jns    f01033f0 <vprintfmt+0x37c>
				putch('-', putdat);
f0103370:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103374:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f010337b:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f010337e:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103381:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103384:	f7 d8                	neg    %eax
f0103386:	83 d2 00             	adc    $0x0,%edx
f0103389:	f7 da                	neg    %edx
			}
			base = 10;
f010338b:	b9 0a 00 00 00       	mov    $0xa,%ecx
f0103390:	eb 5e                	jmp    f01033f0 <vprintfmt+0x37c>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f0103392:	8d 45 14             	lea    0x14(%ebp),%eax
f0103395:	e8 5b fc ff ff       	call   f0102ff5 <getuint>
			base = 10;
f010339a:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f010339f:	eb 4f                	jmp    f01033f0 <vprintfmt+0x37c>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			//putch('X', putdat);
			num = getuint(&ap, lflag);
f01033a1:	8d 45 14             	lea    0x14(%ebp),%eax
f01033a4:	e8 4c fc ff ff       	call   f0102ff5 <getuint>
			base = 8;
f01033a9:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f01033ae:	eb 40                	jmp    f01033f0 <vprintfmt+0x37c>
			//putch('X', putdat);
			//break;

		// pointer
		case 'p':
			putch('0', putdat);
f01033b0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01033b4:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f01033bb:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f01033be:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01033c2:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f01033c9:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f01033cc:	8b 45 14             	mov    0x14(%ebp),%eax
f01033cf:	8d 50 04             	lea    0x4(%eax),%edx
f01033d2:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f01033d5:	8b 00                	mov    (%eax),%eax
f01033d7:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f01033dc:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f01033e1:	eb 0d                	jmp    f01033f0 <vprintfmt+0x37c>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f01033e3:	8d 45 14             	lea    0x14(%ebp),%eax
f01033e6:	e8 0a fc ff ff       	call   f0102ff5 <getuint>
			base = 16;
f01033eb:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f01033f0:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f01033f4:	89 74 24 10          	mov    %esi,0x10(%esp)
f01033f8:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f01033fb:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01033ff:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0103403:	89 04 24             	mov    %eax,(%esp)
f0103406:	89 54 24 04          	mov    %edx,0x4(%esp)
f010340a:	89 fa                	mov    %edi,%edx
f010340c:	8b 45 08             	mov    0x8(%ebp),%eax
f010340f:	e8 ec fa ff ff       	call   f0102f00 <printnum>
			break;
f0103414:	e9 84 fc ff ff       	jmp    f010309d <vprintfmt+0x29>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0103419:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010341d:	89 0c 24             	mov    %ecx,(%esp)
f0103420:	ff 55 08             	call   *0x8(%ebp)
			break;
f0103423:	e9 75 fc ff ff       	jmp    f010309d <vprintfmt+0x29>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0103428:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010342c:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0103433:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f0103436:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f010343a:	0f 84 5b fc ff ff    	je     f010309b <vprintfmt+0x27>
f0103440:	89 f3                	mov    %esi,%ebx
f0103442:	83 eb 01             	sub    $0x1,%ebx
f0103445:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f0103449:	75 f7                	jne    f0103442 <vprintfmt+0x3ce>
f010344b:	e9 4d fc ff ff       	jmp    f010309d <vprintfmt+0x29>
				/* do nothing */;
			break;
		}
	}
}
f0103450:	83 c4 3c             	add    $0x3c,%esp
f0103453:	5b                   	pop    %ebx
f0103454:	5e                   	pop    %esi
f0103455:	5f                   	pop    %edi
f0103456:	5d                   	pop    %ebp
f0103457:	c3                   	ret    

f0103458 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0103458:	55                   	push   %ebp
f0103459:	89 e5                	mov    %esp,%ebp
f010345b:	83 ec 28             	sub    $0x28,%esp
f010345e:	8b 45 08             	mov    0x8(%ebp),%eax
f0103461:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0103464:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0103467:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f010346b:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f010346e:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0103475:	85 c0                	test   %eax,%eax
f0103477:	74 30                	je     f01034a9 <vsnprintf+0x51>
f0103479:	85 d2                	test   %edx,%edx
f010347b:	7e 2c                	jle    f01034a9 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f010347d:	8b 45 14             	mov    0x14(%ebp),%eax
f0103480:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103484:	8b 45 10             	mov    0x10(%ebp),%eax
f0103487:	89 44 24 08          	mov    %eax,0x8(%esp)
f010348b:	8d 45 ec             	lea    -0x14(%ebp),%eax
f010348e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103492:	c7 04 24 2f 30 10 f0 	movl   $0xf010302f,(%esp)
f0103499:	e8 d6 fb ff ff       	call   f0103074 <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f010349e:	8b 45 ec             	mov    -0x14(%ebp),%eax
f01034a1:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f01034a4:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01034a7:	eb 05                	jmp    f01034ae <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f01034a9:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f01034ae:	c9                   	leave  
f01034af:	c3                   	ret    

f01034b0 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f01034b0:	55                   	push   %ebp
f01034b1:	89 e5                	mov    %esp,%ebp
f01034b3:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f01034b6:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f01034b9:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01034bd:	8b 45 10             	mov    0x10(%ebp),%eax
f01034c0:	89 44 24 08          	mov    %eax,0x8(%esp)
f01034c4:	8b 45 0c             	mov    0xc(%ebp),%eax
f01034c7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01034cb:	8b 45 08             	mov    0x8(%ebp),%eax
f01034ce:	89 04 24             	mov    %eax,(%esp)
f01034d1:	e8 82 ff ff ff       	call   f0103458 <vsnprintf>
	va_end(ap);

	return rc;
}
f01034d6:	c9                   	leave  
f01034d7:	c3                   	ret    
f01034d8:	66 90                	xchg   %ax,%ax
f01034da:	66 90                	xchg   %ax,%ax
f01034dc:	66 90                	xchg   %ax,%ax
f01034de:	66 90                	xchg   %ax,%ax

f01034e0 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f01034e0:	55                   	push   %ebp
f01034e1:	89 e5                	mov    %esp,%ebp
f01034e3:	57                   	push   %edi
f01034e4:	56                   	push   %esi
f01034e5:	53                   	push   %ebx
f01034e6:	83 ec 1c             	sub    $0x1c,%esp
f01034e9:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f01034ec:	85 c0                	test   %eax,%eax
f01034ee:	74 10                	je     f0103500 <readline+0x20>
		cprintf("%s", prompt);
f01034f0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01034f4:	c7 04 24 21 4d 10 f0 	movl   $0xf0104d21,(%esp)
f01034fb:	e8 61 eb ff ff       	call   f0102061 <cprintf>

	i = 0;
	echoing = iscons(0);
f0103500:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0103507:	e8 d2 d2 ff ff       	call   f01007de <iscons>
f010350c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f010350e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0103513:	e8 b5 d2 ff ff       	call   f01007cd <getchar>
f0103518:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f010351a:	85 c0                	test   %eax,%eax
f010351c:	79 17                	jns    f0103535 <readline+0x55>
			cprintf("read error: %e\n", c);
f010351e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103522:	c7 04 24 84 55 10 f0 	movl   $0xf0105584,(%esp)
f0103529:	e8 33 eb ff ff       	call   f0102061 <cprintf>
			return NULL;
f010352e:	b8 00 00 00 00       	mov    $0x0,%eax
f0103533:	eb 6d                	jmp    f01035a2 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0103535:	83 f8 7f             	cmp    $0x7f,%eax
f0103538:	74 05                	je     f010353f <readline+0x5f>
f010353a:	83 f8 08             	cmp    $0x8,%eax
f010353d:	75 19                	jne    f0103558 <readline+0x78>
f010353f:	85 f6                	test   %esi,%esi
f0103541:	7e 15                	jle    f0103558 <readline+0x78>
			if (echoing)
f0103543:	85 ff                	test   %edi,%edi
f0103545:	74 0c                	je     f0103553 <readline+0x73>
				cputchar('\b');
f0103547:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f010354e:	e8 6a d2 ff ff       	call   f01007bd <cputchar>
			i--;
f0103553:	83 ee 01             	sub    $0x1,%esi
f0103556:	eb bb                	jmp    f0103513 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0103558:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f010355e:	7f 1c                	jg     f010357c <readline+0x9c>
f0103560:	83 fb 1f             	cmp    $0x1f,%ebx
f0103563:	7e 17                	jle    f010357c <readline+0x9c>
			if (echoing)
f0103565:	85 ff                	test   %edi,%edi
f0103567:	74 08                	je     f0103571 <readline+0x91>
				cputchar(c);
f0103569:	89 1c 24             	mov    %ebx,(%esp)
f010356c:	e8 4c d2 ff ff       	call   f01007bd <cputchar>
			buf[i++] = c;
f0103571:	88 9e 00 fb 21 f0    	mov    %bl,-0xfde0500(%esi)
f0103577:	8d 76 01             	lea    0x1(%esi),%esi
f010357a:	eb 97                	jmp    f0103513 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f010357c:	83 fb 0d             	cmp    $0xd,%ebx
f010357f:	74 05                	je     f0103586 <readline+0xa6>
f0103581:	83 fb 0a             	cmp    $0xa,%ebx
f0103584:	75 8d                	jne    f0103513 <readline+0x33>
			if (echoing)
f0103586:	85 ff                	test   %edi,%edi
f0103588:	74 0c                	je     f0103596 <readline+0xb6>
				cputchar('\n');
f010358a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0103591:	e8 27 d2 ff ff       	call   f01007bd <cputchar>
			buf[i] = 0;
f0103596:	c6 86 00 fb 21 f0 00 	movb   $0x0,-0xfde0500(%esi)
			return buf;
f010359d:	b8 00 fb 21 f0       	mov    $0xf021fb00,%eax
		}
	}
}
f01035a2:	83 c4 1c             	add    $0x1c,%esp
f01035a5:	5b                   	pop    %ebx
f01035a6:	5e                   	pop    %esi
f01035a7:	5f                   	pop    %edi
f01035a8:	5d                   	pop    %ebp
f01035a9:	c3                   	ret    
f01035aa:	66 90                	xchg   %ax,%ax
f01035ac:	66 90                	xchg   %ax,%ax
f01035ae:	66 90                	xchg   %ax,%ax

f01035b0 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f01035b0:	55                   	push   %ebp
f01035b1:	89 e5                	mov    %esp,%ebp
f01035b3:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f01035b6:	80 3a 00             	cmpb   $0x0,(%edx)
f01035b9:	74 10                	je     f01035cb <strlen+0x1b>
f01035bb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f01035c0:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f01035c3:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f01035c7:	75 f7                	jne    f01035c0 <strlen+0x10>
f01035c9:	eb 05                	jmp    f01035d0 <strlen+0x20>
f01035cb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f01035d0:	5d                   	pop    %ebp
f01035d1:	c3                   	ret    

f01035d2 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f01035d2:	55                   	push   %ebp
f01035d3:	89 e5                	mov    %esp,%ebp
f01035d5:	53                   	push   %ebx
f01035d6:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01035d9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01035dc:	85 c9                	test   %ecx,%ecx
f01035de:	74 1c                	je     f01035fc <strnlen+0x2a>
f01035e0:	80 3b 00             	cmpb   $0x0,(%ebx)
f01035e3:	74 1e                	je     f0103603 <strnlen+0x31>
f01035e5:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f01035ea:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01035ec:	39 ca                	cmp    %ecx,%edx
f01035ee:	74 18                	je     f0103608 <strnlen+0x36>
f01035f0:	83 c2 01             	add    $0x1,%edx
f01035f3:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f01035f8:	75 f0                	jne    f01035ea <strnlen+0x18>
f01035fa:	eb 0c                	jmp    f0103608 <strnlen+0x36>
f01035fc:	b8 00 00 00 00       	mov    $0x0,%eax
f0103601:	eb 05                	jmp    f0103608 <strnlen+0x36>
f0103603:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0103608:	5b                   	pop    %ebx
f0103609:	5d                   	pop    %ebp
f010360a:	c3                   	ret    

f010360b <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f010360b:	55                   	push   %ebp
f010360c:	89 e5                	mov    %esp,%ebp
f010360e:	53                   	push   %ebx
f010360f:	8b 45 08             	mov    0x8(%ebp),%eax
f0103612:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0103615:	89 c2                	mov    %eax,%edx
f0103617:	83 c2 01             	add    $0x1,%edx
f010361a:	83 c1 01             	add    $0x1,%ecx
f010361d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0103621:	88 5a ff             	mov    %bl,-0x1(%edx)
f0103624:	84 db                	test   %bl,%bl
f0103626:	75 ef                	jne    f0103617 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0103628:	5b                   	pop    %ebx
f0103629:	5d                   	pop    %ebp
f010362a:	c3                   	ret    

f010362b <strcat>:

char *
strcat(char *dst, const char *src)
{
f010362b:	55                   	push   %ebp
f010362c:	89 e5                	mov    %esp,%ebp
f010362e:	53                   	push   %ebx
f010362f:	83 ec 08             	sub    $0x8,%esp
f0103632:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f0103635:	89 1c 24             	mov    %ebx,(%esp)
f0103638:	e8 73 ff ff ff       	call   f01035b0 <strlen>
	strcpy(dst + len, src);
f010363d:	8b 55 0c             	mov    0xc(%ebp),%edx
f0103640:	89 54 24 04          	mov    %edx,0x4(%esp)
f0103644:	01 d8                	add    %ebx,%eax
f0103646:	89 04 24             	mov    %eax,(%esp)
f0103649:	e8 bd ff ff ff       	call   f010360b <strcpy>
	return dst;
}
f010364e:	89 d8                	mov    %ebx,%eax
f0103650:	83 c4 08             	add    $0x8,%esp
f0103653:	5b                   	pop    %ebx
f0103654:	5d                   	pop    %ebp
f0103655:	c3                   	ret    

f0103656 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f0103656:	55                   	push   %ebp
f0103657:	89 e5                	mov    %esp,%ebp
f0103659:	56                   	push   %esi
f010365a:	53                   	push   %ebx
f010365b:	8b 75 08             	mov    0x8(%ebp),%esi
f010365e:	8b 55 0c             	mov    0xc(%ebp),%edx
f0103661:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0103664:	85 db                	test   %ebx,%ebx
f0103666:	74 17                	je     f010367f <strncpy+0x29>
f0103668:	01 f3                	add    %esi,%ebx
f010366a:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f010366c:	83 c1 01             	add    $0x1,%ecx
f010366f:	0f b6 02             	movzbl (%edx),%eax
f0103672:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f0103675:	80 3a 01             	cmpb   $0x1,(%edx)
f0103678:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f010367b:	39 d9                	cmp    %ebx,%ecx
f010367d:	75 ed                	jne    f010366c <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f010367f:	89 f0                	mov    %esi,%eax
f0103681:	5b                   	pop    %ebx
f0103682:	5e                   	pop    %esi
f0103683:	5d                   	pop    %ebp
f0103684:	c3                   	ret    

f0103685 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f0103685:	55                   	push   %ebp
f0103686:	89 e5                	mov    %esp,%ebp
f0103688:	57                   	push   %edi
f0103689:	56                   	push   %esi
f010368a:	53                   	push   %ebx
f010368b:	8b 7d 08             	mov    0x8(%ebp),%edi
f010368e:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0103691:	8b 75 10             	mov    0x10(%ebp),%esi
f0103694:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0103696:	85 f6                	test   %esi,%esi
f0103698:	74 34                	je     f01036ce <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f010369a:	83 fe 01             	cmp    $0x1,%esi
f010369d:	74 26                	je     f01036c5 <strlcpy+0x40>
f010369f:	0f b6 0b             	movzbl (%ebx),%ecx
f01036a2:	84 c9                	test   %cl,%cl
f01036a4:	74 23                	je     f01036c9 <strlcpy+0x44>
f01036a6:	83 ee 02             	sub    $0x2,%esi
f01036a9:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f01036ae:	83 c0 01             	add    $0x1,%eax
f01036b1:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f01036b4:	39 f2                	cmp    %esi,%edx
f01036b6:	74 13                	je     f01036cb <strlcpy+0x46>
f01036b8:	83 c2 01             	add    $0x1,%edx
f01036bb:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f01036bf:	84 c9                	test   %cl,%cl
f01036c1:	75 eb                	jne    f01036ae <strlcpy+0x29>
f01036c3:	eb 06                	jmp    f01036cb <strlcpy+0x46>
f01036c5:	89 f8                	mov    %edi,%eax
f01036c7:	eb 02                	jmp    f01036cb <strlcpy+0x46>
f01036c9:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f01036cb:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f01036ce:	29 f8                	sub    %edi,%eax
}
f01036d0:	5b                   	pop    %ebx
f01036d1:	5e                   	pop    %esi
f01036d2:	5f                   	pop    %edi
f01036d3:	5d                   	pop    %ebp
f01036d4:	c3                   	ret    

f01036d5 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f01036d5:	55                   	push   %ebp
f01036d6:	89 e5                	mov    %esp,%ebp
f01036d8:	8b 4d 08             	mov    0x8(%ebp),%ecx
f01036db:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f01036de:	0f b6 01             	movzbl (%ecx),%eax
f01036e1:	84 c0                	test   %al,%al
f01036e3:	74 15                	je     f01036fa <strcmp+0x25>
f01036e5:	3a 02                	cmp    (%edx),%al
f01036e7:	75 11                	jne    f01036fa <strcmp+0x25>
		p++, q++;
f01036e9:	83 c1 01             	add    $0x1,%ecx
f01036ec:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f01036ef:	0f b6 01             	movzbl (%ecx),%eax
f01036f2:	84 c0                	test   %al,%al
f01036f4:	74 04                	je     f01036fa <strcmp+0x25>
f01036f6:	3a 02                	cmp    (%edx),%al
f01036f8:	74 ef                	je     f01036e9 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f01036fa:	0f b6 c0             	movzbl %al,%eax
f01036fd:	0f b6 12             	movzbl (%edx),%edx
f0103700:	29 d0                	sub    %edx,%eax
}
f0103702:	5d                   	pop    %ebp
f0103703:	c3                   	ret    

f0103704 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0103704:	55                   	push   %ebp
f0103705:	89 e5                	mov    %esp,%ebp
f0103707:	56                   	push   %esi
f0103708:	53                   	push   %ebx
f0103709:	8b 5d 08             	mov    0x8(%ebp),%ebx
f010370c:	8b 55 0c             	mov    0xc(%ebp),%edx
f010370f:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f0103712:	85 f6                	test   %esi,%esi
f0103714:	74 29                	je     f010373f <strncmp+0x3b>
f0103716:	0f b6 03             	movzbl (%ebx),%eax
f0103719:	84 c0                	test   %al,%al
f010371b:	74 30                	je     f010374d <strncmp+0x49>
f010371d:	3a 02                	cmp    (%edx),%al
f010371f:	75 2c                	jne    f010374d <strncmp+0x49>
f0103721:	8d 43 01             	lea    0x1(%ebx),%eax
f0103724:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f0103726:	89 c3                	mov    %eax,%ebx
f0103728:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f010372b:	39 f0                	cmp    %esi,%eax
f010372d:	74 17                	je     f0103746 <strncmp+0x42>
f010372f:	0f b6 08             	movzbl (%eax),%ecx
f0103732:	84 c9                	test   %cl,%cl
f0103734:	74 17                	je     f010374d <strncmp+0x49>
f0103736:	83 c0 01             	add    $0x1,%eax
f0103739:	3a 0a                	cmp    (%edx),%cl
f010373b:	74 e9                	je     f0103726 <strncmp+0x22>
f010373d:	eb 0e                	jmp    f010374d <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f010373f:	b8 00 00 00 00       	mov    $0x0,%eax
f0103744:	eb 0f                	jmp    f0103755 <strncmp+0x51>
f0103746:	b8 00 00 00 00       	mov    $0x0,%eax
f010374b:	eb 08                	jmp    f0103755 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f010374d:	0f b6 03             	movzbl (%ebx),%eax
f0103750:	0f b6 12             	movzbl (%edx),%edx
f0103753:	29 d0                	sub    %edx,%eax
}
f0103755:	5b                   	pop    %ebx
f0103756:	5e                   	pop    %esi
f0103757:	5d                   	pop    %ebp
f0103758:	c3                   	ret    

f0103759 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f0103759:	55                   	push   %ebp
f010375a:	89 e5                	mov    %esp,%ebp
f010375c:	53                   	push   %ebx
f010375d:	8b 45 08             	mov    0x8(%ebp),%eax
f0103760:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0103763:	0f b6 18             	movzbl (%eax),%ebx
f0103766:	84 db                	test   %bl,%bl
f0103768:	74 1d                	je     f0103787 <strchr+0x2e>
f010376a:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f010376c:	38 d3                	cmp    %dl,%bl
f010376e:	75 06                	jne    f0103776 <strchr+0x1d>
f0103770:	eb 1a                	jmp    f010378c <strchr+0x33>
f0103772:	38 ca                	cmp    %cl,%dl
f0103774:	74 16                	je     f010378c <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0103776:	83 c0 01             	add    $0x1,%eax
f0103779:	0f b6 10             	movzbl (%eax),%edx
f010377c:	84 d2                	test   %dl,%dl
f010377e:	75 f2                	jne    f0103772 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0103780:	b8 00 00 00 00       	mov    $0x0,%eax
f0103785:	eb 05                	jmp    f010378c <strchr+0x33>
f0103787:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010378c:	5b                   	pop    %ebx
f010378d:	5d                   	pop    %ebp
f010378e:	c3                   	ret    

f010378f <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f010378f:	55                   	push   %ebp
f0103790:	89 e5                	mov    %esp,%ebp
f0103792:	53                   	push   %ebx
f0103793:	8b 45 08             	mov    0x8(%ebp),%eax
f0103796:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0103799:	0f b6 18             	movzbl (%eax),%ebx
f010379c:	84 db                	test   %bl,%bl
f010379e:	74 16                	je     f01037b6 <strfind+0x27>
f01037a0:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f01037a2:	38 d3                	cmp    %dl,%bl
f01037a4:	75 06                	jne    f01037ac <strfind+0x1d>
f01037a6:	eb 0e                	jmp    f01037b6 <strfind+0x27>
f01037a8:	38 ca                	cmp    %cl,%dl
f01037aa:	74 0a                	je     f01037b6 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f01037ac:	83 c0 01             	add    $0x1,%eax
f01037af:	0f b6 10             	movzbl (%eax),%edx
f01037b2:	84 d2                	test   %dl,%dl
f01037b4:	75 f2                	jne    f01037a8 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f01037b6:	5b                   	pop    %ebx
f01037b7:	5d                   	pop    %ebp
f01037b8:	c3                   	ret    

f01037b9 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f01037b9:	55                   	push   %ebp
f01037ba:	89 e5                	mov    %esp,%ebp
f01037bc:	57                   	push   %edi
f01037bd:	56                   	push   %esi
f01037be:	53                   	push   %ebx
f01037bf:	8b 7d 08             	mov    0x8(%ebp),%edi
f01037c2:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f01037c5:	85 c9                	test   %ecx,%ecx
f01037c7:	74 36                	je     f01037ff <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f01037c9:	f7 c7 03 00 00 00    	test   $0x3,%edi
f01037cf:	75 28                	jne    f01037f9 <memset+0x40>
f01037d1:	f6 c1 03             	test   $0x3,%cl
f01037d4:	75 23                	jne    f01037f9 <memset+0x40>
		c &= 0xFF;
f01037d6:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f01037da:	89 d3                	mov    %edx,%ebx
f01037dc:	c1 e3 08             	shl    $0x8,%ebx
f01037df:	89 d6                	mov    %edx,%esi
f01037e1:	c1 e6 18             	shl    $0x18,%esi
f01037e4:	89 d0                	mov    %edx,%eax
f01037e6:	c1 e0 10             	shl    $0x10,%eax
f01037e9:	09 f0                	or     %esi,%eax
f01037eb:	09 c2                	or     %eax,%edx
f01037ed:	89 d0                	mov    %edx,%eax
f01037ef:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f01037f1:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f01037f4:	fc                   	cld    
f01037f5:	f3 ab                	rep stos %eax,%es:(%edi)
f01037f7:	eb 06                	jmp    f01037ff <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f01037f9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01037fc:	fc                   	cld    
f01037fd:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f01037ff:	89 f8                	mov    %edi,%eax
f0103801:	5b                   	pop    %ebx
f0103802:	5e                   	pop    %esi
f0103803:	5f                   	pop    %edi
f0103804:	5d                   	pop    %ebp
f0103805:	c3                   	ret    

f0103806 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0103806:	55                   	push   %ebp
f0103807:	89 e5                	mov    %esp,%ebp
f0103809:	57                   	push   %edi
f010380a:	56                   	push   %esi
f010380b:	8b 45 08             	mov    0x8(%ebp),%eax
f010380e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0103811:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0103814:	39 c6                	cmp    %eax,%esi
f0103816:	73 35                	jae    f010384d <memmove+0x47>
f0103818:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f010381b:	39 d0                	cmp    %edx,%eax
f010381d:	73 2e                	jae    f010384d <memmove+0x47>
		s += n;
		d += n;
f010381f:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0103822:	89 d6                	mov    %edx,%esi
f0103824:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0103826:	f7 c6 03 00 00 00    	test   $0x3,%esi
f010382c:	75 13                	jne    f0103841 <memmove+0x3b>
f010382e:	f6 c1 03             	test   $0x3,%cl
f0103831:	75 0e                	jne    f0103841 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0103833:	83 ef 04             	sub    $0x4,%edi
f0103836:	8d 72 fc             	lea    -0x4(%edx),%esi
f0103839:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f010383c:	fd                   	std    
f010383d:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f010383f:	eb 09                	jmp    f010384a <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0103841:	83 ef 01             	sub    $0x1,%edi
f0103844:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0103847:	fd                   	std    
f0103848:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f010384a:	fc                   	cld    
f010384b:	eb 1d                	jmp    f010386a <memmove+0x64>
f010384d:	89 f2                	mov    %esi,%edx
f010384f:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0103851:	f6 c2 03             	test   $0x3,%dl
f0103854:	75 0f                	jne    f0103865 <memmove+0x5f>
f0103856:	f6 c1 03             	test   $0x3,%cl
f0103859:	75 0a                	jne    f0103865 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f010385b:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f010385e:	89 c7                	mov    %eax,%edi
f0103860:	fc                   	cld    
f0103861:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0103863:	eb 05                	jmp    f010386a <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0103865:	89 c7                	mov    %eax,%edi
f0103867:	fc                   	cld    
f0103868:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f010386a:	5e                   	pop    %esi
f010386b:	5f                   	pop    %edi
f010386c:	5d                   	pop    %ebp
f010386d:	c3                   	ret    

f010386e <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f010386e:	55                   	push   %ebp
f010386f:	89 e5                	mov    %esp,%ebp
f0103871:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0103874:	8b 45 10             	mov    0x10(%ebp),%eax
f0103877:	89 44 24 08          	mov    %eax,0x8(%esp)
f010387b:	8b 45 0c             	mov    0xc(%ebp),%eax
f010387e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103882:	8b 45 08             	mov    0x8(%ebp),%eax
f0103885:	89 04 24             	mov    %eax,(%esp)
f0103888:	e8 79 ff ff ff       	call   f0103806 <memmove>
}
f010388d:	c9                   	leave  
f010388e:	c3                   	ret    

f010388f <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f010388f:	55                   	push   %ebp
f0103890:	89 e5                	mov    %esp,%ebp
f0103892:	57                   	push   %edi
f0103893:	56                   	push   %esi
f0103894:	53                   	push   %ebx
f0103895:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0103898:	8b 75 0c             	mov    0xc(%ebp),%esi
f010389b:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f010389e:	8d 78 ff             	lea    -0x1(%eax),%edi
f01038a1:	85 c0                	test   %eax,%eax
f01038a3:	74 36                	je     f01038db <memcmp+0x4c>
		if (*s1 != *s2)
f01038a5:	0f b6 03             	movzbl (%ebx),%eax
f01038a8:	0f b6 0e             	movzbl (%esi),%ecx
f01038ab:	ba 00 00 00 00       	mov    $0x0,%edx
f01038b0:	38 c8                	cmp    %cl,%al
f01038b2:	74 1c                	je     f01038d0 <memcmp+0x41>
f01038b4:	eb 10                	jmp    f01038c6 <memcmp+0x37>
f01038b6:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f01038bb:	83 c2 01             	add    $0x1,%edx
f01038be:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f01038c2:	38 c8                	cmp    %cl,%al
f01038c4:	74 0a                	je     f01038d0 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f01038c6:	0f b6 c0             	movzbl %al,%eax
f01038c9:	0f b6 c9             	movzbl %cl,%ecx
f01038cc:	29 c8                	sub    %ecx,%eax
f01038ce:	eb 10                	jmp    f01038e0 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01038d0:	39 fa                	cmp    %edi,%edx
f01038d2:	75 e2                	jne    f01038b6 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f01038d4:	b8 00 00 00 00       	mov    $0x0,%eax
f01038d9:	eb 05                	jmp    f01038e0 <memcmp+0x51>
f01038db:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01038e0:	5b                   	pop    %ebx
f01038e1:	5e                   	pop    %esi
f01038e2:	5f                   	pop    %edi
f01038e3:	5d                   	pop    %ebp
f01038e4:	c3                   	ret    

f01038e5 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f01038e5:	55                   	push   %ebp
f01038e6:	89 e5                	mov    %esp,%ebp
f01038e8:	53                   	push   %ebx
f01038e9:	8b 45 08             	mov    0x8(%ebp),%eax
f01038ec:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f01038ef:	89 c2                	mov    %eax,%edx
f01038f1:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f01038f4:	39 d0                	cmp    %edx,%eax
f01038f6:	73 13                	jae    f010390b <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f01038f8:	89 d9                	mov    %ebx,%ecx
f01038fa:	38 18                	cmp    %bl,(%eax)
f01038fc:	75 06                	jne    f0103904 <memfind+0x1f>
f01038fe:	eb 0b                	jmp    f010390b <memfind+0x26>
f0103900:	38 08                	cmp    %cl,(%eax)
f0103902:	74 07                	je     f010390b <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f0103904:	83 c0 01             	add    $0x1,%eax
f0103907:	39 d0                	cmp    %edx,%eax
f0103909:	75 f5                	jne    f0103900 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f010390b:	5b                   	pop    %ebx
f010390c:	5d                   	pop    %ebp
f010390d:	c3                   	ret    

f010390e <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f010390e:	55                   	push   %ebp
f010390f:	89 e5                	mov    %esp,%ebp
f0103911:	57                   	push   %edi
f0103912:	56                   	push   %esi
f0103913:	53                   	push   %ebx
f0103914:	8b 55 08             	mov    0x8(%ebp),%edx
f0103917:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010391a:	0f b6 0a             	movzbl (%edx),%ecx
f010391d:	80 f9 09             	cmp    $0x9,%cl
f0103920:	74 05                	je     f0103927 <strtol+0x19>
f0103922:	80 f9 20             	cmp    $0x20,%cl
f0103925:	75 10                	jne    f0103937 <strtol+0x29>
		s++;
f0103927:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010392a:	0f b6 0a             	movzbl (%edx),%ecx
f010392d:	80 f9 09             	cmp    $0x9,%cl
f0103930:	74 f5                	je     f0103927 <strtol+0x19>
f0103932:	80 f9 20             	cmp    $0x20,%cl
f0103935:	74 f0                	je     f0103927 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f0103937:	80 f9 2b             	cmp    $0x2b,%cl
f010393a:	75 0a                	jne    f0103946 <strtol+0x38>
		s++;
f010393c:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f010393f:	bf 00 00 00 00       	mov    $0x0,%edi
f0103944:	eb 11                	jmp    f0103957 <strtol+0x49>
f0103946:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f010394b:	80 f9 2d             	cmp    $0x2d,%cl
f010394e:	75 07                	jne    f0103957 <strtol+0x49>
		s++, neg = 1;
f0103950:	83 c2 01             	add    $0x1,%edx
f0103953:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0103957:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f010395c:	75 15                	jne    f0103973 <strtol+0x65>
f010395e:	80 3a 30             	cmpb   $0x30,(%edx)
f0103961:	75 10                	jne    f0103973 <strtol+0x65>
f0103963:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0103967:	75 0a                	jne    f0103973 <strtol+0x65>
		s += 2, base = 16;
f0103969:	83 c2 02             	add    $0x2,%edx
f010396c:	b8 10 00 00 00       	mov    $0x10,%eax
f0103971:	eb 10                	jmp    f0103983 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f0103973:	85 c0                	test   %eax,%eax
f0103975:	75 0c                	jne    f0103983 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0103977:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0103979:	80 3a 30             	cmpb   $0x30,(%edx)
f010397c:	75 05                	jne    f0103983 <strtol+0x75>
		s++, base = 8;
f010397e:	83 c2 01             	add    $0x1,%edx
f0103981:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f0103983:	bb 00 00 00 00       	mov    $0x0,%ebx
f0103988:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f010398b:	0f b6 0a             	movzbl (%edx),%ecx
f010398e:	8d 71 d0             	lea    -0x30(%ecx),%esi
f0103991:	89 f0                	mov    %esi,%eax
f0103993:	3c 09                	cmp    $0x9,%al
f0103995:	77 08                	ja     f010399f <strtol+0x91>
			dig = *s - '0';
f0103997:	0f be c9             	movsbl %cl,%ecx
f010399a:	83 e9 30             	sub    $0x30,%ecx
f010399d:	eb 20                	jmp    f01039bf <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f010399f:	8d 71 9f             	lea    -0x61(%ecx),%esi
f01039a2:	89 f0                	mov    %esi,%eax
f01039a4:	3c 19                	cmp    $0x19,%al
f01039a6:	77 08                	ja     f01039b0 <strtol+0xa2>
			dig = *s - 'a' + 10;
f01039a8:	0f be c9             	movsbl %cl,%ecx
f01039ab:	83 e9 57             	sub    $0x57,%ecx
f01039ae:	eb 0f                	jmp    f01039bf <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f01039b0:	8d 71 bf             	lea    -0x41(%ecx),%esi
f01039b3:	89 f0                	mov    %esi,%eax
f01039b5:	3c 19                	cmp    $0x19,%al
f01039b7:	77 16                	ja     f01039cf <strtol+0xc1>
			dig = *s - 'A' + 10;
f01039b9:	0f be c9             	movsbl %cl,%ecx
f01039bc:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f01039bf:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f01039c2:	7d 0f                	jge    f01039d3 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f01039c4:	83 c2 01             	add    $0x1,%edx
f01039c7:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f01039cb:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f01039cd:	eb bc                	jmp    f010398b <strtol+0x7d>
f01039cf:	89 d8                	mov    %ebx,%eax
f01039d1:	eb 02                	jmp    f01039d5 <strtol+0xc7>
f01039d3:	89 d8                	mov    %ebx,%eax

	if (endptr)
f01039d5:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f01039d9:	74 05                	je     f01039e0 <strtol+0xd2>
		*endptr = (char *) s;
f01039db:	8b 75 0c             	mov    0xc(%ebp),%esi
f01039de:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f01039e0:	f7 d8                	neg    %eax
f01039e2:	85 ff                	test   %edi,%edi
f01039e4:	0f 44 c3             	cmove  %ebx,%eax
}
f01039e7:	5b                   	pop    %ebx
f01039e8:	5e                   	pop    %esi
f01039e9:	5f                   	pop    %edi
f01039ea:	5d                   	pop    %ebp
f01039eb:	c3                   	ret    

f01039ec <mpentry_start>:
.set PROT_MODE_DSEG, 0x10	# kernel data segment selector

.code16           
.globl mpentry_start
mpentry_start:
	cli            
f01039ec:	fa                   	cli    

	xorw    %ax, %ax
f01039ed:	31 c0                	xor    %eax,%eax
	movw    %ax, %ds
f01039ef:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f01039f1:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f01039f3:	8e d0                	mov    %eax,%ss

	lgdt    MPBOOTPHYS(gdtdesc)
f01039f5:	0f 01 16             	lgdtl  (%esi)
f01039f8:	74 70                	je     f0103a6a <mpentry_end+0x4>
	movl    %cr0, %eax
f01039fa:	0f 20 c0             	mov    %cr0,%eax
	orl     $CR0_PE, %eax
f01039fd:	66 83 c8 01          	or     $0x1,%ax
	movl    %eax, %cr0
f0103a01:	0f 22 c0             	mov    %eax,%cr0

	ljmpl   $(PROT_MODE_CSEG), $(MPBOOTPHYS(start32))
f0103a04:	66 ea 20 70 00 00    	ljmpw  $0x0,$0x7020
f0103a0a:	08 00                	or     %al,(%eax)

f0103a0c <start32>:

.code32
start32:
	movw    $(PROT_MODE_DSEG), %ax
f0103a0c:	66 b8 10 00          	mov    $0x10,%ax
	movw    %ax, %ds
f0103a10:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0103a12:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0103a14:	8e d0                	mov    %eax,%ss
	movw    $0, %ax
f0103a16:	66 b8 00 00          	mov    $0x0,%ax
	movw    %ax, %fs
f0103a1a:	8e e0                	mov    %eax,%fs
	movw    %ax, %gs
f0103a1c:	8e e8                	mov    %eax,%gs

	# Set up initial page table. We cannot use kern_pgdir yet because
	# we are still running at a low EIP.
	movl    $(RELOC(entry_pgdir)), %eax
f0103a1e:	b8 00 a0 11 00       	mov    $0x11a000,%eax
	movl    %eax, %cr3
f0103a23:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl    %cr0, %eax
f0103a26:	0f 20 c0             	mov    %cr0,%eax
	orl     $(CR0_PE|CR0_PG|CR0_WP), %eax
f0103a29:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl    %eax, %cr0
f0103a2e:	0f 22 c0             	mov    %eax,%cr0

	# Switch to the per-cpu stack allocated in mem_init()
	movl    mpentry_kstack, %esp
f0103a31:	8b 25 04 ff 21 f0    	mov    0xf021ff04,%esp
	movl    $0x0, %ebp       # nuke frame pointer
f0103a37:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Call mp_main().  (Exercise for the reader: why the indirect call?)
	movl    $mp_main, %eax
f0103a3c:	b8 1d 02 10 f0       	mov    $0xf010021d,%eax
	call    *%eax
f0103a41:	ff d0                	call   *%eax

f0103a43 <spin>:

	# If mp_main returns (it shouldn't), loop.
spin:
	jmp     spin
f0103a43:	eb fe                	jmp    f0103a43 <spin>
f0103a45:	8d 76 00             	lea    0x0(%esi),%esi

f0103a48 <gdt>:
	...
f0103a50:	ff                   	(bad)  
f0103a51:	ff 00                	incl   (%eax)
f0103a53:	00 00                	add    %al,(%eax)
f0103a55:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
f0103a5c:	00 92 cf 00 17 00    	add    %dl,0x1700cf(%edx)

f0103a60 <gdtdesc>:
f0103a60:	17                   	pop    %ss
f0103a61:	00 5c 70 00          	add    %bl,0x0(%eax,%esi,2)
	...

f0103a66 <mpentry_end>:
	.word   0x17				# sizeof(gdt) - 1
	.long   MPBOOTPHYS(gdt)			# address gdt

.globl mpentry_end
mpentry_end:
	nop
f0103a66:	90                   	nop
f0103a67:	66 90                	xchg   %ax,%ax
f0103a69:	66 90                	xchg   %ax,%ax
f0103a6b:	66 90                	xchg   %ax,%ax
f0103a6d:	66 90                	xchg   %ax,%ax
f0103a6f:	90                   	nop

f0103a70 <mpsearch1>:
}

// Look for an MP structure in the len bytes at physical address addr.
static struct mp *
mpsearch1(physaddr_t a, int len)
{
f0103a70:	55                   	push   %ebp
f0103a71:	89 e5                	mov    %esp,%ebp
f0103a73:	56                   	push   %esi
f0103a74:	53                   	push   %ebx
f0103a75:	83 ec 10             	sub    $0x10,%esp
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103a78:	8b 0d 08 ff 21 f0    	mov    0xf021ff08,%ecx
f0103a7e:	89 c3                	mov    %eax,%ebx
f0103a80:	c1 eb 0c             	shr    $0xc,%ebx
f0103a83:	39 cb                	cmp    %ecx,%ebx
f0103a85:	72 20                	jb     f0103aa7 <mpsearch1+0x37>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103a87:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103a8b:	c7 44 24 08 84 45 10 	movl   $0xf0104584,0x8(%esp)
f0103a92:	f0 
f0103a93:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f0103a9a:	00 
f0103a9b:	c7 04 24 21 57 10 f0 	movl   $0xf0105721,(%esp)
f0103aa2:	e8 99 c5 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0103aa7:	8d 98 00 00 00 f0    	lea    -0x10000000(%eax),%ebx
	struct mp *mp = KADDR(a), *end = KADDR(a + len);
f0103aad:	01 d0                	add    %edx,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103aaf:	89 c2                	mov    %eax,%edx
f0103ab1:	c1 ea 0c             	shr    $0xc,%edx
f0103ab4:	39 d1                	cmp    %edx,%ecx
f0103ab6:	77 20                	ja     f0103ad8 <mpsearch1+0x68>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103ab8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103abc:	c7 44 24 08 84 45 10 	movl   $0xf0104584,0x8(%esp)
f0103ac3:	f0 
f0103ac4:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f0103acb:	00 
f0103acc:	c7 04 24 21 57 10 f0 	movl   $0xf0105721,(%esp)
f0103ad3:	e8 68 c5 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0103ad8:	8d b0 00 00 00 f0    	lea    -0x10000000(%eax),%esi

	for (; mp < end; mp++)
f0103ade:	39 f3                	cmp    %esi,%ebx
f0103ae0:	73 40                	jae    f0103b22 <mpsearch1+0xb2>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0103ae2:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0103ae9:	00 
f0103aea:	c7 44 24 04 31 57 10 	movl   $0xf0105731,0x4(%esp)
f0103af1:	f0 
f0103af2:	89 1c 24             	mov    %ebx,(%esp)
f0103af5:	e8 95 fd ff ff       	call   f010388f <memcmp>
f0103afa:	85 c0                	test   %eax,%eax
f0103afc:	75 17                	jne    f0103b15 <mpsearch1+0xa5>
f0103afe:	ba 00 00 00 00       	mov    $0x0,%edx
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
		sum += ((uint8_t *)addr)[i];
f0103b03:	0f b6 0c 03          	movzbl (%ebx,%eax,1),%ecx
f0103b07:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0103b09:	83 c0 01             	add    $0x1,%eax
f0103b0c:	83 f8 10             	cmp    $0x10,%eax
f0103b0f:	75 f2                	jne    f0103b03 <mpsearch1+0x93>
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0103b11:	84 d2                	test   %dl,%dl
f0103b13:	74 14                	je     f0103b29 <mpsearch1+0xb9>
static struct mp *
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
f0103b15:	83 c3 10             	add    $0x10,%ebx
f0103b18:	39 f3                	cmp    %esi,%ebx
f0103b1a:	72 c6                	jb     f0103ae2 <mpsearch1+0x72>
f0103b1c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0103b20:	eb 0b                	jmp    f0103b2d <mpsearch1+0xbd>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
		    sum(mp, sizeof(*mp)) == 0)
			return mp;
	return NULL;
f0103b22:	b8 00 00 00 00       	mov    $0x0,%eax
f0103b27:	eb 09                	jmp    f0103b32 <mpsearch1+0xc2>
f0103b29:	89 d8                	mov    %ebx,%eax
f0103b2b:	eb 05                	jmp    f0103b32 <mpsearch1+0xc2>
f0103b2d:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0103b32:	83 c4 10             	add    $0x10,%esp
f0103b35:	5b                   	pop    %ebx
f0103b36:	5e                   	pop    %esi
f0103b37:	5d                   	pop    %ebp
f0103b38:	c3                   	ret    

f0103b39 <mp_init>:
	return conf;
}

void
mp_init(void)
{
f0103b39:	55                   	push   %ebp
f0103b3a:	89 e5                	mov    %esp,%ebp
f0103b3c:	57                   	push   %edi
f0103b3d:	56                   	push   %esi
f0103b3e:	53                   	push   %ebx
f0103b3f:	83 ec 2c             	sub    $0x2c,%esp
	struct mpconf *conf;
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
f0103b42:	c7 05 c0 03 22 f0 20 	movl   $0xf0220020,0xf02203c0
f0103b49:	00 22 f0 
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103b4c:	83 3d 08 ff 21 f0 00 	cmpl   $0x0,0xf021ff08
f0103b53:	75 24                	jne    f0103b79 <mp_init+0x40>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103b55:	c7 44 24 0c 00 04 00 	movl   $0x400,0xc(%esp)
f0103b5c:	00 
f0103b5d:	c7 44 24 08 84 45 10 	movl   $0xf0104584,0x8(%esp)
f0103b64:	f0 
f0103b65:	c7 44 24 04 6f 00 00 	movl   $0x6f,0x4(%esp)
f0103b6c:	00 
f0103b6d:	c7 04 24 21 57 10 f0 	movl   $0xf0105721,(%esp)
f0103b74:	e8 c7 c4 ff ff       	call   f0100040 <_panic>
	// The BIOS data area lives in 16-bit segment 0x40.
	bda = (uint8_t *) KADDR(0x40 << 4);

	// [MP 4] The 16-bit segment of the EBDA is in the two bytes
	// starting at byte 0x0E of the BDA.  0 if not present.
	if ((p = *(uint16_t *) (bda + 0x0E))) {
f0103b79:	0f b7 05 0e 04 00 f0 	movzwl 0xf000040e,%eax
f0103b80:	85 c0                	test   %eax,%eax
f0103b82:	74 16                	je     f0103b9a <mp_init+0x61>
		p <<= 4;	// Translate from segment to PA
f0103b84:	c1 e0 04             	shl    $0x4,%eax
		if ((mp = mpsearch1(p, 1024)))
f0103b87:	ba 00 04 00 00       	mov    $0x400,%edx
f0103b8c:	e8 df fe ff ff       	call   f0103a70 <mpsearch1>
f0103b91:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0103b94:	85 c0                	test   %eax,%eax
f0103b96:	75 3c                	jne    f0103bd4 <mp_init+0x9b>
f0103b98:	eb 20                	jmp    f0103bba <mp_init+0x81>
			return mp;
	} else {
		// The size of base memory, in KB is in the two bytes
		// starting at 0x13 of the BDA.
		p = *(uint16_t *) (bda + 0x13) * 1024;
f0103b9a:	0f b7 05 13 04 00 f0 	movzwl 0xf0000413,%eax
f0103ba1:	c1 e0 0a             	shl    $0xa,%eax
		if ((mp = mpsearch1(p - 1024, 1024)))
f0103ba4:	2d 00 04 00 00       	sub    $0x400,%eax
f0103ba9:	ba 00 04 00 00       	mov    $0x400,%edx
f0103bae:	e8 bd fe ff ff       	call   f0103a70 <mpsearch1>
f0103bb3:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0103bb6:	85 c0                	test   %eax,%eax
f0103bb8:	75 1a                	jne    f0103bd4 <mp_init+0x9b>
			return mp;
	}
	return mpsearch1(0xF0000, 0x10000);
f0103bba:	ba 00 00 01 00       	mov    $0x10000,%edx
f0103bbf:	b8 00 00 0f 00       	mov    $0xf0000,%eax
f0103bc4:	e8 a7 fe ff ff       	call   f0103a70 <mpsearch1>
f0103bc9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
mpconfig(struct mp **pmp)
{
	struct mpconf *conf;
	struct mp *mp;

	if ((mp = mpsearch()) == 0)
f0103bcc:	85 c0                	test   %eax,%eax
f0103bce:	0f 84 5f 02 00 00    	je     f0103e33 <mp_init+0x2fa>
		return NULL;
	if (mp->physaddr == 0 || mp->type != 0) {
f0103bd4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103bd7:	8b 70 04             	mov    0x4(%eax),%esi
f0103bda:	85 f6                	test   %esi,%esi
f0103bdc:	74 06                	je     f0103be4 <mp_init+0xab>
f0103bde:	80 78 0b 00          	cmpb   $0x0,0xb(%eax)
f0103be2:	74 11                	je     f0103bf5 <mp_init+0xbc>
		cprintf("SMP: Default configurations not implemented\n");
f0103be4:	c7 04 24 94 55 10 f0 	movl   $0xf0105594,(%esp)
f0103beb:	e8 71 e4 ff ff       	call   f0102061 <cprintf>
f0103bf0:	e9 3e 02 00 00       	jmp    f0103e33 <mp_init+0x2fa>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103bf5:	89 f0                	mov    %esi,%eax
f0103bf7:	c1 e8 0c             	shr    $0xc,%eax
f0103bfa:	3b 05 08 ff 21 f0    	cmp    0xf021ff08,%eax
f0103c00:	72 20                	jb     f0103c22 <mp_init+0xe9>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103c02:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0103c06:	c7 44 24 08 84 45 10 	movl   $0xf0104584,0x8(%esp)
f0103c0d:	f0 
f0103c0e:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f0103c15:	00 
f0103c16:	c7 04 24 21 57 10 f0 	movl   $0xf0105721,(%esp)
f0103c1d:	e8 1e c4 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0103c22:	8d 9e 00 00 00 f0    	lea    -0x10000000(%esi),%ebx
		return NULL;
	}
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
f0103c28:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0103c2f:	00 
f0103c30:	c7 44 24 04 36 57 10 	movl   $0xf0105736,0x4(%esp)
f0103c37:	f0 
f0103c38:	89 1c 24             	mov    %ebx,(%esp)
f0103c3b:	e8 4f fc ff ff       	call   f010388f <memcmp>
f0103c40:	85 c0                	test   %eax,%eax
f0103c42:	74 11                	je     f0103c55 <mp_init+0x11c>
		cprintf("SMP: Incorrect MP configuration table signature\n");
f0103c44:	c7 04 24 c4 55 10 f0 	movl   $0xf01055c4,(%esp)
f0103c4b:	e8 11 e4 ff ff       	call   f0102061 <cprintf>
f0103c50:	e9 de 01 00 00       	jmp    f0103e33 <mp_init+0x2fa>
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0103c55:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0103c59:	66 89 45 e2          	mov    %ax,-0x1e(%ebp)
f0103c5d:	0f b7 f8             	movzwl %ax,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0103c60:	85 ff                	test   %edi,%edi
f0103c62:	7e 30                	jle    f0103c94 <mp_init+0x15b>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0103c64:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0103c69:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0103c6e:	0f b6 8c 30 00 00 00 	movzbl -0x10000000(%eax,%esi,1),%ecx
f0103c75:	f0 
f0103c76:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0103c78:	83 c0 01             	add    $0x1,%eax
f0103c7b:	39 c7                	cmp    %eax,%edi
f0103c7d:	7f ef                	jg     f0103c6e <mp_init+0x135>
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
		cprintf("SMP: Incorrect MP configuration table signature\n");
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0103c7f:	84 d2                	test   %dl,%dl
f0103c81:	74 11                	je     f0103c94 <mp_init+0x15b>
		cprintf("SMP: Bad MP configuration checksum\n");
f0103c83:	c7 04 24 f8 55 10 f0 	movl   $0xf01055f8,(%esp)
f0103c8a:	e8 d2 e3 ff ff       	call   f0102061 <cprintf>
f0103c8f:	e9 9f 01 00 00       	jmp    f0103e33 <mp_init+0x2fa>
		return NULL;
	}
	if (conf->version != 1 && conf->version != 4) {
f0103c94:	0f b6 43 06          	movzbl 0x6(%ebx),%eax
f0103c98:	3c 04                	cmp    $0x4,%al
f0103c9a:	74 1e                	je     f0103cba <mp_init+0x181>
f0103c9c:	3c 01                	cmp    $0x1,%al
f0103c9e:	66 90                	xchg   %ax,%ax
f0103ca0:	74 18                	je     f0103cba <mp_init+0x181>
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
f0103ca2:	0f b6 c0             	movzbl %al,%eax
f0103ca5:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103ca9:	c7 04 24 1c 56 10 f0 	movl   $0xf010561c,(%esp)
f0103cb0:	e8 ac e3 ff ff       	call   f0102061 <cprintf>
f0103cb5:	e9 79 01 00 00       	jmp    f0103e33 <mp_init+0x2fa>
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0103cba:	0f b7 73 28          	movzwl 0x28(%ebx),%esi
f0103cbe:	0f b7 7d e2          	movzwl -0x1e(%ebp),%edi
f0103cc2:	01 df                	add    %ebx,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0103cc4:	85 f6                	test   %esi,%esi
f0103cc6:	7e 19                	jle    f0103ce1 <mp_init+0x1a8>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0103cc8:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0103ccd:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0103cd2:	0f b6 0c 07          	movzbl (%edi,%eax,1),%ecx
f0103cd6:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0103cd8:	83 c0 01             	add    $0x1,%eax
f0103cdb:	39 c6                	cmp    %eax,%esi
f0103cdd:	7f f3                	jg     f0103cd2 <mp_init+0x199>
f0103cdf:	eb 05                	jmp    f0103ce6 <mp_init+0x1ad>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0103ce1:	ba 00 00 00 00       	mov    $0x0,%edx
	}
	if (conf->version != 1 && conf->version != 4) {
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0103ce6:	38 53 2a             	cmp    %dl,0x2a(%ebx)
f0103ce9:	74 11                	je     f0103cfc <mp_init+0x1c3>
		cprintf("SMP: Bad MP configuration extended checksum\n");
f0103ceb:	c7 04 24 3c 56 10 f0 	movl   $0xf010563c,(%esp)
f0103cf2:	e8 6a e3 ff ff       	call   f0102061 <cprintf>
f0103cf7:	e9 37 01 00 00       	jmp    f0103e33 <mp_init+0x2fa>
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
	if ((conf = mpconfig(&mp)) == 0)
f0103cfc:	85 db                	test   %ebx,%ebx
f0103cfe:	0f 84 2f 01 00 00    	je     f0103e33 <mp_init+0x2fa>
		return;
	ismp = 1;
f0103d04:	c7 05 00 00 22 f0 01 	movl   $0x1,0xf0220000
f0103d0b:	00 00 00 
	lapic = (uint32_t *)conf->lapicaddr;
f0103d0e:	8b 43 24             	mov    0x24(%ebx),%eax
f0103d11:	a3 00 10 26 f0       	mov    %eax,0xf0261000

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0103d16:	8d 7b 2c             	lea    0x2c(%ebx),%edi
f0103d19:	66 83 7b 22 00       	cmpw   $0x0,0x22(%ebx)
f0103d1e:	0f 84 94 00 00 00    	je     f0103db8 <mp_init+0x27f>
f0103d24:	be 00 00 00 00       	mov    $0x0,%esi
		switch (*p) {
f0103d29:	0f b6 07             	movzbl (%edi),%eax
f0103d2c:	84 c0                	test   %al,%al
f0103d2e:	74 06                	je     f0103d36 <mp_init+0x1fd>
f0103d30:	3c 04                	cmp    $0x4,%al
f0103d32:	77 54                	ja     f0103d88 <mp_init+0x24f>
f0103d34:	eb 4d                	jmp    f0103d83 <mp_init+0x24a>
		case MPPROC:
			proc = (struct mpproc *)p;
			if (proc->flags & MPPROC_BOOT)
f0103d36:	f6 47 03 02          	testb  $0x2,0x3(%edi)
f0103d3a:	74 11                	je     f0103d4d <mp_init+0x214>
				bootcpu = &cpus[ncpu];
f0103d3c:	6b 05 c4 03 22 f0 74 	imul   $0x74,0xf02203c4,%eax
f0103d43:	05 20 00 22 f0       	add    $0xf0220020,%eax
f0103d48:	a3 c0 03 22 f0       	mov    %eax,0xf02203c0
			if (ncpu < NCPU) {
f0103d4d:	a1 c4 03 22 f0       	mov    0xf02203c4,%eax
f0103d52:	83 f8 07             	cmp    $0x7,%eax
f0103d55:	7f 13                	jg     f0103d6a <mp_init+0x231>
				cpus[ncpu].cpu_id = ncpu;
f0103d57:	6b d0 74             	imul   $0x74,%eax,%edx
f0103d5a:	88 82 20 00 22 f0    	mov    %al,-0xfddffe0(%edx)
				ncpu++;
f0103d60:	83 c0 01             	add    $0x1,%eax
f0103d63:	a3 c4 03 22 f0       	mov    %eax,0xf02203c4
f0103d68:	eb 14                	jmp    f0103d7e <mp_init+0x245>
			} else {
				cprintf("SMP: too many CPUs, CPU %d disabled\n",
f0103d6a:	0f b6 47 01          	movzbl 0x1(%edi),%eax
f0103d6e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d72:	c7 04 24 6c 56 10 f0 	movl   $0xf010566c,(%esp)
f0103d79:	e8 e3 e2 ff ff       	call   f0102061 <cprintf>
					proc->apicid);
			}
			p += sizeof(struct mpproc);
f0103d7e:	83 c7 14             	add    $0x14,%edi
			continue;
f0103d81:	eb 26                	jmp    f0103da9 <mp_init+0x270>
		case MPBUS:
		case MPIOAPIC:
		case MPIOINTR:
		case MPLINTR:
			p += 8;
f0103d83:	83 c7 08             	add    $0x8,%edi
			continue;
f0103d86:	eb 21                	jmp    f0103da9 <mp_init+0x270>
		default:
			cprintf("mpinit: unknown config type %x\n", *p);
f0103d88:	0f b6 c0             	movzbl %al,%eax
f0103d8b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d8f:	c7 04 24 94 56 10 f0 	movl   $0xf0105694,(%esp)
f0103d96:	e8 c6 e2 ff ff       	call   f0102061 <cprintf>
			ismp = 0;
f0103d9b:	c7 05 00 00 22 f0 00 	movl   $0x0,0xf0220000
f0103da2:	00 00 00 
			i = conf->entry;
f0103da5:	0f b7 73 22          	movzwl 0x22(%ebx),%esi
	if ((conf = mpconfig(&mp)) == 0)
		return;
	ismp = 1;
	lapic = (uint32_t *)conf->lapicaddr;

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0103da9:	83 c6 01             	add    $0x1,%esi
f0103dac:	0f b7 43 22          	movzwl 0x22(%ebx),%eax
f0103db0:	39 f0                	cmp    %esi,%eax
f0103db2:	0f 87 71 ff ff ff    	ja     f0103d29 <mp_init+0x1f0>
			ismp = 0;
			i = conf->entry;
		}
	}

	bootcpu->cpu_status = CPU_STARTED;
f0103db8:	a1 c0 03 22 f0       	mov    0xf02203c0,%eax
f0103dbd:	c7 40 04 01 00 00 00 	movl   $0x1,0x4(%eax)
	if (!ismp) {
f0103dc4:	83 3d 00 00 22 f0 00 	cmpl   $0x0,0xf0220000
f0103dcb:	75 22                	jne    f0103def <mp_init+0x2b6>
		// Didn't like what we found; fall back to no MP.
		ncpu = 1;
f0103dcd:	c7 05 c4 03 22 f0 01 	movl   $0x1,0xf02203c4
f0103dd4:	00 00 00 
		lapic = NULL;
f0103dd7:	c7 05 00 10 26 f0 00 	movl   $0x0,0xf0261000
f0103dde:	00 00 00 
		cprintf("SMP: configuration not found, SMP disabled\n");
f0103de1:	c7 04 24 b4 56 10 f0 	movl   $0xf01056b4,(%esp)
f0103de8:	e8 74 e2 ff ff       	call   f0102061 <cprintf>
		return;
f0103ded:	eb 44                	jmp    f0103e33 <mp_init+0x2fa>
	}
	cprintf("SMP: CPU %d found %d CPU(s)\n", bootcpu->cpu_id,  ncpu);
f0103def:	8b 15 c4 03 22 f0    	mov    0xf02203c4,%edx
f0103df5:	89 54 24 08          	mov    %edx,0x8(%esp)
f0103df9:	0f b6 00             	movzbl (%eax),%eax
f0103dfc:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e00:	c7 04 24 3b 57 10 f0 	movl   $0xf010573b,(%esp)
f0103e07:	e8 55 e2 ff ff       	call   f0102061 <cprintf>

	if (mp->imcrp) {
f0103e0c:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103e0f:	80 78 0c 00          	cmpb   $0x0,0xc(%eax)
f0103e13:	74 1e                	je     f0103e33 <mp_init+0x2fa>
		// [MP 3.2.6.1] If the hardware implements PIC mode,
		// switch to getting interrupts from the LAPIC.
		cprintf("SMP: Setting IMCR to switch from PIC mode to symmetric I/O mode\n");
f0103e15:	c7 04 24 e0 56 10 f0 	movl   $0xf01056e0,(%esp)
f0103e1c:	e8 40 e2 ff ff       	call   f0102061 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103e21:	ba 22 00 00 00       	mov    $0x22,%edx
f0103e26:	b8 70 00 00 00       	mov    $0x70,%eax
f0103e2b:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0103e2c:	b2 23                	mov    $0x23,%dl
f0103e2e:	ec                   	in     (%dx),%al
		outb(0x22, 0x70);   // Select IMCR
		outb(0x23, inb(0x23) | 1);  // Mask external interrupts.
f0103e2f:	83 c8 01             	or     $0x1,%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103e32:	ee                   	out    %al,(%dx)
	}
}
f0103e33:	83 c4 2c             	add    $0x2c,%esp
f0103e36:	5b                   	pop    %ebx
f0103e37:	5e                   	pop    %esi
f0103e38:	5f                   	pop    %edi
f0103e39:	5d                   	pop    %ebp
f0103e3a:	c3                   	ret    

f0103e3b <lapicw>:

volatile uint32_t *lapic;  // Initialized in mp.c

static void
lapicw(int index, int value)
{
f0103e3b:	55                   	push   %ebp
f0103e3c:	89 e5                	mov    %esp,%ebp
	lapic[index] = value;
f0103e3e:	8b 0d 00 10 26 f0    	mov    0xf0261000,%ecx
f0103e44:	8d 04 81             	lea    (%ecx,%eax,4),%eax
f0103e47:	89 10                	mov    %edx,(%eax)
	lapic[ID];  // wait for write to finish, by reading
f0103e49:	a1 00 10 26 f0       	mov    0xf0261000,%eax
f0103e4e:	8b 40 20             	mov    0x20(%eax),%eax
}
f0103e51:	5d                   	pop    %ebp
f0103e52:	c3                   	ret    

f0103e53 <cpunum>:
	lapicw(TPR, 0);
}

int
cpunum(void)
{
f0103e53:	55                   	push   %ebp
f0103e54:	89 e5                	mov    %esp,%ebp
	if (lapic)
f0103e56:	a1 00 10 26 f0       	mov    0xf0261000,%eax
f0103e5b:	85 c0                	test   %eax,%eax
f0103e5d:	74 08                	je     f0103e67 <cpunum+0x14>
		return lapic[ID] >> 24;
f0103e5f:	8b 40 20             	mov    0x20(%eax),%eax
f0103e62:	c1 e8 18             	shr    $0x18,%eax
f0103e65:	eb 05                	jmp    f0103e6c <cpunum+0x19>
	return 0;
f0103e67:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0103e6c:	5d                   	pop    %ebp
f0103e6d:	c3                   	ret    

f0103e6e <lapic_init>:
}

void
lapic_init(void)
{
	if (!lapic) 
f0103e6e:	83 3d 00 10 26 f0 00 	cmpl   $0x0,0xf0261000
f0103e75:	0f 84 0b 01 00 00    	je     f0103f86 <lapic_init+0x118>
	lapic[ID];  // wait for write to finish, by reading
}

void
lapic_init(void)
{
f0103e7b:	55                   	push   %ebp
f0103e7c:	89 e5                	mov    %esp,%ebp
	if (!lapic) 
		return;

	// Enable local APIC; set spurious interrupt vector.
	lapicw(SVR, ENABLE | (IRQ_OFFSET + IRQ_SPURIOUS));
f0103e7e:	ba 27 01 00 00       	mov    $0x127,%edx
f0103e83:	b8 3c 00 00 00       	mov    $0x3c,%eax
f0103e88:	e8 ae ff ff ff       	call   f0103e3b <lapicw>

	// The timer repeatedly counts down at bus frequency
	// from lapic[TICR] and then issues an interrupt.  
	// If we cared more about precise timekeeping,
	// TICR would be calibrated using an external time source.
	lapicw(TDCR, X1);
f0103e8d:	ba 0b 00 00 00       	mov    $0xb,%edx
f0103e92:	b8 f8 00 00 00       	mov    $0xf8,%eax
f0103e97:	e8 9f ff ff ff       	call   f0103e3b <lapicw>
	lapicw(TIMER, PERIODIC | (IRQ_OFFSET + IRQ_TIMER));
f0103e9c:	ba 20 00 02 00       	mov    $0x20020,%edx
f0103ea1:	b8 c8 00 00 00       	mov    $0xc8,%eax
f0103ea6:	e8 90 ff ff ff       	call   f0103e3b <lapicw>
	lapicw(TICR, 10000000); 
f0103eab:	ba 80 96 98 00       	mov    $0x989680,%edx
f0103eb0:	b8 e0 00 00 00       	mov    $0xe0,%eax
f0103eb5:	e8 81 ff ff ff       	call   f0103e3b <lapicw>
	//
	// According to Intel MP Specification, the BIOS should initialize
	// BSP's local APIC in Virtual Wire Mode, in which 8259A's
	// INTR is virtually connected to BSP's LINTIN0. In this mode,
	// we do not need to program the IOAPIC.
	if (thiscpu != bootcpu)
f0103eba:	e8 94 ff ff ff       	call   f0103e53 <cpunum>
f0103ebf:	6b c0 74             	imul   $0x74,%eax,%eax
f0103ec2:	05 20 00 22 f0       	add    $0xf0220020,%eax
f0103ec7:	39 05 c0 03 22 f0    	cmp    %eax,0xf02203c0
f0103ecd:	74 0f                	je     f0103ede <lapic_init+0x70>
		lapicw(LINT0, MASKED);
f0103ecf:	ba 00 00 01 00       	mov    $0x10000,%edx
f0103ed4:	b8 d4 00 00 00       	mov    $0xd4,%eax
f0103ed9:	e8 5d ff ff ff       	call   f0103e3b <lapicw>

	// Disable NMI (LINT1) on all CPUs
	lapicw(LINT1, MASKED);
f0103ede:	ba 00 00 01 00       	mov    $0x10000,%edx
f0103ee3:	b8 d8 00 00 00       	mov    $0xd8,%eax
f0103ee8:	e8 4e ff ff ff       	call   f0103e3b <lapicw>

	// Disable performance counter overflow interrupts
	// on machines that provide that interrupt entry.
	if (((lapic[VER]>>16) & 0xFF) >= 4)
f0103eed:	a1 00 10 26 f0       	mov    0xf0261000,%eax
f0103ef2:	8b 40 30             	mov    0x30(%eax),%eax
f0103ef5:	c1 e8 10             	shr    $0x10,%eax
f0103ef8:	3c 03                	cmp    $0x3,%al
f0103efa:	76 0f                	jbe    f0103f0b <lapic_init+0x9d>
		lapicw(PCINT, MASKED);
f0103efc:	ba 00 00 01 00       	mov    $0x10000,%edx
f0103f01:	b8 d0 00 00 00       	mov    $0xd0,%eax
f0103f06:	e8 30 ff ff ff       	call   f0103e3b <lapicw>

	// Map error interrupt to IRQ_ERROR.
	lapicw(ERROR, IRQ_OFFSET + IRQ_ERROR);
f0103f0b:	ba 33 00 00 00       	mov    $0x33,%edx
f0103f10:	b8 dc 00 00 00       	mov    $0xdc,%eax
f0103f15:	e8 21 ff ff ff       	call   f0103e3b <lapicw>

	// Clear error status register (requires back-to-back writes).
	lapicw(ESR, 0);
f0103f1a:	ba 00 00 00 00       	mov    $0x0,%edx
f0103f1f:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0103f24:	e8 12 ff ff ff       	call   f0103e3b <lapicw>
	lapicw(ESR, 0);
f0103f29:	ba 00 00 00 00       	mov    $0x0,%edx
f0103f2e:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0103f33:	e8 03 ff ff ff       	call   f0103e3b <lapicw>

	// Ack any outstanding interrupts.
	lapicw(EOI, 0);
f0103f38:	ba 00 00 00 00       	mov    $0x0,%edx
f0103f3d:	b8 2c 00 00 00       	mov    $0x2c,%eax
f0103f42:	e8 f4 fe ff ff       	call   f0103e3b <lapicw>

	// Send an Init Level De-Assert to synchronize arbitration ID's.
	lapicw(ICRHI, 0);
f0103f47:	ba 00 00 00 00       	mov    $0x0,%edx
f0103f4c:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0103f51:	e8 e5 fe ff ff       	call   f0103e3b <lapicw>
	lapicw(ICRLO, BCAST | INIT | LEVEL);
f0103f56:	ba 00 85 08 00       	mov    $0x88500,%edx
f0103f5b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0103f60:	e8 d6 fe ff ff       	call   f0103e3b <lapicw>
	while(lapic[ICRLO] & DELIVS)
f0103f65:	8b 15 00 10 26 f0    	mov    0xf0261000,%edx
f0103f6b:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f0103f71:	f6 c4 10             	test   $0x10,%ah
f0103f74:	75 f5                	jne    f0103f6b <lapic_init+0xfd>
		;

	// Enable interrupts on the APIC (but not on the processor).
	lapicw(TPR, 0);
f0103f76:	ba 00 00 00 00       	mov    $0x0,%edx
f0103f7b:	b8 20 00 00 00       	mov    $0x20,%eax
f0103f80:	e8 b6 fe ff ff       	call   f0103e3b <lapicw>
}
f0103f85:	5d                   	pop    %ebp
f0103f86:	f3 c3                	repz ret 

f0103f88 <lapic_eoi>:

// Acknowledge interrupt.
void
lapic_eoi(void)
{
	if (lapic)
f0103f88:	83 3d 00 10 26 f0 00 	cmpl   $0x0,0xf0261000
f0103f8f:	74 13                	je     f0103fa4 <lapic_eoi+0x1c>
}

// Acknowledge interrupt.
void
lapic_eoi(void)
{
f0103f91:	55                   	push   %ebp
f0103f92:	89 e5                	mov    %esp,%ebp
	if (lapic)
		lapicw(EOI, 0);
f0103f94:	ba 00 00 00 00       	mov    $0x0,%edx
f0103f99:	b8 2c 00 00 00       	mov    $0x2c,%eax
f0103f9e:	e8 98 fe ff ff       	call   f0103e3b <lapicw>
}
f0103fa3:	5d                   	pop    %ebp
f0103fa4:	f3 c3                	repz ret 

f0103fa6 <lapic_startap>:

// Start additional processor running entry code at addr.
// See Appendix B of MultiProcessor Specification.
void
lapic_startap(uint8_t apicid, uint32_t addr)
{
f0103fa6:	55                   	push   %ebp
f0103fa7:	89 e5                	mov    %esp,%ebp
f0103fa9:	56                   	push   %esi
f0103faa:	53                   	push   %ebx
f0103fab:	83 ec 10             	sub    $0x10,%esp
f0103fae:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0103fb1:	8b 75 0c             	mov    0xc(%ebp),%esi
f0103fb4:	ba 70 00 00 00       	mov    $0x70,%edx
f0103fb9:	b8 0f 00 00 00       	mov    $0xf,%eax
f0103fbe:	ee                   	out    %al,(%dx)
f0103fbf:	b2 71                	mov    $0x71,%dl
f0103fc1:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103fc6:	ee                   	out    %al,(%dx)
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103fc7:	83 3d 08 ff 21 f0 00 	cmpl   $0x0,0xf021ff08
f0103fce:	75 24                	jne    f0103ff4 <lapic_startap+0x4e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103fd0:	c7 44 24 0c 67 04 00 	movl   $0x467,0xc(%esp)
f0103fd7:	00 
f0103fd8:	c7 44 24 08 84 45 10 	movl   $0xf0104584,0x8(%esp)
f0103fdf:	f0 
f0103fe0:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
f0103fe7:	00 
f0103fe8:	c7 04 24 58 57 10 f0 	movl   $0xf0105758,(%esp)
f0103fef:	e8 4c c0 ff ff       	call   f0100040 <_panic>
	// and the warm reset vector (DWORD based at 40:67) to point at
	// the AP startup code prior to the [universal startup algorithm]."
	outb(IO_RTC, 0xF);  // offset 0xF is shutdown code
	outb(IO_RTC+1, 0x0A);
	wrv = (uint16_t *)KADDR((0x40 << 4 | 0x67));  // Warm reset vector
	wrv[0] = 0;
f0103ff4:	66 c7 05 67 04 00 f0 	movw   $0x0,0xf0000467
f0103ffb:	00 00 
	wrv[1] = addr >> 4;
f0103ffd:	89 f0                	mov    %esi,%eax
f0103fff:	c1 e8 04             	shr    $0x4,%eax
f0104002:	66 a3 69 04 00 f0    	mov    %ax,0xf0000469

	// "Universal startup algorithm."
	// Send INIT (level-triggered) interrupt to reset other CPU.
	lapicw(ICRHI, apicid << 24);
f0104008:	c1 e3 18             	shl    $0x18,%ebx
f010400b:	89 da                	mov    %ebx,%edx
f010400d:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0104012:	e8 24 fe ff ff       	call   f0103e3b <lapicw>
	lapicw(ICRLO, INIT | LEVEL | ASSERT);
f0104017:	ba 00 c5 00 00       	mov    $0xc500,%edx
f010401c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0104021:	e8 15 fe ff ff       	call   f0103e3b <lapicw>
	microdelay(200);
	lapicw(ICRLO, INIT | LEVEL);
f0104026:	ba 00 85 00 00       	mov    $0x8500,%edx
f010402b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0104030:	e8 06 fe ff ff       	call   f0103e3b <lapicw>
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0104035:	c1 ee 0c             	shr    $0xc,%esi
f0104038:	81 ce 00 06 00 00    	or     $0x600,%esi
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f010403e:	89 da                	mov    %ebx,%edx
f0104040:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0104045:	e8 f1 fd ff ff       	call   f0103e3b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f010404a:	89 f2                	mov    %esi,%edx
f010404c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0104051:	e8 e5 fd ff ff       	call   f0103e3b <lapicw>
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f0104056:	89 da                	mov    %ebx,%edx
f0104058:	b8 c4 00 00 00       	mov    $0xc4,%eax
f010405d:	e8 d9 fd ff ff       	call   f0103e3b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0104062:	89 f2                	mov    %esi,%edx
f0104064:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0104069:	e8 cd fd ff ff       	call   f0103e3b <lapicw>
		microdelay(200);
	}
}
f010406e:	83 c4 10             	add    $0x10,%esp
f0104071:	5b                   	pop    %ebx
f0104072:	5e                   	pop    %esi
f0104073:	5d                   	pop    %ebp
f0104074:	c3                   	ret    

f0104075 <lapic_ipi>:

void
lapic_ipi(int vector)
{
f0104075:	55                   	push   %ebp
f0104076:	89 e5                	mov    %esp,%ebp
	lapicw(ICRLO, OTHERS | FIXED | vector);
f0104078:	8b 55 08             	mov    0x8(%ebp),%edx
f010407b:	81 ca 00 00 0c 00    	or     $0xc0000,%edx
f0104081:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0104086:	e8 b0 fd ff ff       	call   f0103e3b <lapicw>
	while (lapic[ICRLO] & DELIVS)
f010408b:	8b 15 00 10 26 f0    	mov    0xf0261000,%edx
f0104091:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f0104097:	f6 c4 10             	test   $0x10,%ah
f010409a:	75 f5                	jne    f0104091 <lapic_ipi+0x1c>
		;
}
f010409c:	5d                   	pop    %ebp
f010409d:	c3                   	ret    

f010409e <__spin_initlock>:
}
#endif

void
__spin_initlock(struct spinlock *lk, char *name)
{
f010409e:	55                   	push   %ebp
f010409f:	89 e5                	mov    %esp,%ebp
f01040a1:	8b 45 08             	mov    0x8(%ebp),%eax
	lk->locked = 0;
f01040a4:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
#ifdef DEBUG_SPINLOCK
	lk->name = name;
f01040aa:	8b 55 0c             	mov    0xc(%ebp),%edx
f01040ad:	89 50 04             	mov    %edx,0x4(%eax)
	lk->cpu = 0;
f01040b0:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
#endif
}
f01040b7:	5d                   	pop    %ebp
f01040b8:	c3                   	ret    

f01040b9 <spin_lock>:
// Loops (spins) until the lock is acquired.
// Holding a lock for a long time may cause
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
f01040b9:	55                   	push   %ebp
f01040ba:	89 e5                	mov    %esp,%ebp
f01040bc:	56                   	push   %esi
f01040bd:	53                   	push   %ebx
f01040be:	83 ec 20             	sub    $0x20,%esp
f01040c1:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f01040c4:	83 3b 00             	cmpl   $0x0,(%ebx)
f01040c7:	74 14                	je     f01040dd <spin_lock+0x24>
f01040c9:	8b 73 08             	mov    0x8(%ebx),%esi
f01040cc:	e8 82 fd ff ff       	call   f0103e53 <cpunum>
f01040d1:	6b c0 74             	imul   $0x74,%eax,%eax
f01040d4:	05 20 00 22 f0       	add    $0xf0220020,%eax
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
f01040d9:	39 c6                	cmp    %eax,%esi
f01040db:	74 15                	je     f01040f2 <spin_lock+0x39>
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f01040dd:	89 da                	mov    %ebx,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f01040df:	b8 01 00 00 00       	mov    $0x1,%eax
f01040e4:	f0 87 03             	lock xchg %eax,(%ebx)
f01040e7:	b9 01 00 00 00       	mov    $0x1,%ecx
f01040ec:	85 c0                	test   %eax,%eax
f01040ee:	75 2e                	jne    f010411e <spin_lock+0x65>
f01040f0:	eb 37                	jmp    f0104129 <spin_lock+0x70>
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
		panic("CPU %d cannot acquire %s: already holding", cpunum(), lk->name);
f01040f2:	8b 5b 04             	mov    0x4(%ebx),%ebx
f01040f5:	e8 59 fd ff ff       	call   f0103e53 <cpunum>
f01040fa:	89 5c 24 10          	mov    %ebx,0x10(%esp)
f01040fe:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104102:	c7 44 24 08 68 57 10 	movl   $0xf0105768,0x8(%esp)
f0104109:	f0 
f010410a:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
f0104111:	00 
f0104112:	c7 04 24 cc 57 10 f0 	movl   $0xf01057cc,(%esp)
f0104119:	e8 22 bf ff ff       	call   f0100040 <_panic>

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
		asm volatile ("pause");
f010411e:	f3 90                	pause  
f0104120:	89 c8                	mov    %ecx,%eax
f0104122:	f0 87 02             	lock xchg %eax,(%edx)
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f0104125:	85 c0                	test   %eax,%eax
f0104127:	75 f5                	jne    f010411e <spin_lock+0x65>
		asm volatile ("pause");

	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
f0104129:	e8 25 fd ff ff       	call   f0103e53 <cpunum>
f010412e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104131:	05 20 00 22 f0       	add    $0xf0220020,%eax
f0104136:	89 43 08             	mov    %eax,0x8(%ebx)
	get_caller_pcs(lk->pcs);
f0104139:	8d 4b 0c             	lea    0xc(%ebx),%ecx

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f010413c:	89 e8                	mov    %ebp,%eax
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
f010413e:	8d 90 00 00 80 10    	lea    0x10800000(%eax),%edx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0104144:	81 fa ff ff 7f 0e    	cmp    $0xe7fffff,%edx
f010414a:	76 3a                	jbe    f0104186 <spin_lock+0xcd>
f010414c:	eb 31                	jmp    f010417f <spin_lock+0xc6>
		    || ebp >= (uint32_t *)IOMEMBASE)
f010414e:	8d 9a 00 00 80 10    	lea    0x10800000(%edx),%ebx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0104154:	81 fb ff ff 7f 0e    	cmp    $0xe7fffff,%ebx
f010415a:	77 12                	ja     f010416e <spin_lock+0xb5>
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f010415c:	8b 5a 04             	mov    0x4(%edx),%ebx
f010415f:	89 1c 81             	mov    %ebx,(%ecx,%eax,4)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f0104162:	8b 12                	mov    (%edx),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f0104164:	83 c0 01             	add    $0x1,%eax
f0104167:	83 f8 0a             	cmp    $0xa,%eax
f010416a:	75 e2                	jne    f010414e <spin_lock+0x95>
f010416c:	eb 27                	jmp    f0104195 <spin_lock+0xdc>
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
		pcs[i] = 0;
f010416e:	c7 04 81 00 00 00 00 	movl   $0x0,(%ecx,%eax,4)
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
f0104175:	83 c0 01             	add    $0x1,%eax
f0104178:	83 f8 09             	cmp    $0x9,%eax
f010417b:	7e f1                	jle    f010416e <spin_lock+0xb5>
f010417d:	eb 16                	jmp    f0104195 <spin_lock+0xdc>
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f010417f:	b8 00 00 00 00       	mov    $0x0,%eax
f0104184:	eb e8                	jmp    f010416e <spin_lock+0xb5>
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f0104186:	8b 50 04             	mov    0x4(%eax),%edx
f0104189:	89 53 0c             	mov    %edx,0xc(%ebx)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f010418c:	8b 10                	mov    (%eax),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f010418e:	b8 01 00 00 00       	mov    $0x1,%eax
f0104193:	eb b9                	jmp    f010414e <spin_lock+0x95>
	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
	get_caller_pcs(lk->pcs);
#endif
}
f0104195:	83 c4 20             	add    $0x20,%esp
f0104198:	5b                   	pop    %ebx
f0104199:	5e                   	pop    %esi
f010419a:	5d                   	pop    %ebp
f010419b:	c3                   	ret    

f010419c <spin_unlock>:

// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
f010419c:	55                   	push   %ebp
f010419d:	89 e5                	mov    %esp,%ebp
f010419f:	57                   	push   %edi
f01041a0:	56                   	push   %esi
f01041a1:	53                   	push   %ebx
f01041a2:	83 ec 6c             	sub    $0x6c,%esp
f01041a5:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f01041a8:	83 3b 00             	cmpl   $0x0,(%ebx)
f01041ab:	74 18                	je     f01041c5 <spin_unlock+0x29>
f01041ad:	8b 73 08             	mov    0x8(%ebx),%esi
f01041b0:	e8 9e fc ff ff       	call   f0103e53 <cpunum>
f01041b5:	6b c0 74             	imul   $0x74,%eax,%eax
f01041b8:	05 20 00 22 f0       	add    $0xf0220020,%eax
// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (!holding(lk)) {
f01041bd:	39 c6                	cmp    %eax,%esi
f01041bf:	0f 84 d4 00 00 00    	je     f0104299 <spin_unlock+0xfd>
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
f01041c5:	c7 44 24 08 28 00 00 	movl   $0x28,0x8(%esp)
f01041cc:	00 
f01041cd:	8d 43 0c             	lea    0xc(%ebx),%eax
f01041d0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01041d4:	8d 45 c0             	lea    -0x40(%ebp),%eax
f01041d7:	89 04 24             	mov    %eax,(%esp)
f01041da:	e8 27 f6 ff ff       	call   f0103806 <memmove>
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
f01041df:	8b 43 08             	mov    0x8(%ebx),%eax
	if (!holding(lk)) {
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
f01041e2:	0f b6 30             	movzbl (%eax),%esi
f01041e5:	8b 5b 04             	mov    0x4(%ebx),%ebx
f01041e8:	e8 66 fc ff ff       	call   f0103e53 <cpunum>
f01041ed:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01041f1:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f01041f5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01041f9:	c7 04 24 94 57 10 f0 	movl   $0xf0105794,(%esp)
f0104200:	e8 5c de ff ff       	call   f0102061 <cprintf>
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0104205:	8b 45 c0             	mov    -0x40(%ebp),%eax
f0104208:	85 c0                	test   %eax,%eax
f010420a:	74 71                	je     f010427d <spin_unlock+0xe1>
f010420c:	8d 5d c0             	lea    -0x40(%ebp),%ebx
f010420f:	8d 7d e4             	lea    -0x1c(%ebp),%edi
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
f0104212:	8d 75 a8             	lea    -0x58(%ebp),%esi
f0104215:	89 74 24 04          	mov    %esi,0x4(%esp)
f0104219:	89 04 24             	mov    %eax,(%esp)
f010421c:	e8 0b ea ff ff       	call   f0102c2c <debuginfo_eip>
f0104221:	85 c0                	test   %eax,%eax
f0104223:	78 39                	js     f010425e <spin_unlock+0xc2>
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
f0104225:	8b 03                	mov    (%ebx),%eax
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
f0104227:	89 c2                	mov    %eax,%edx
f0104229:	2b 55 b8             	sub    -0x48(%ebp),%edx
f010422c:	89 54 24 18          	mov    %edx,0x18(%esp)
f0104230:	8b 55 b0             	mov    -0x50(%ebp),%edx
f0104233:	89 54 24 14          	mov    %edx,0x14(%esp)
f0104237:	8b 55 b4             	mov    -0x4c(%ebp),%edx
f010423a:	89 54 24 10          	mov    %edx,0x10(%esp)
f010423e:	8b 55 ac             	mov    -0x54(%ebp),%edx
f0104241:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0104245:	8b 55 a8             	mov    -0x58(%ebp),%edx
f0104248:	89 54 24 08          	mov    %edx,0x8(%esp)
f010424c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104250:	c7 04 24 dc 57 10 f0 	movl   $0xf01057dc,(%esp)
f0104257:	e8 05 de ff ff       	call   f0102061 <cprintf>
f010425c:	eb 12                	jmp    f0104270 <spin_unlock+0xd4>
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
f010425e:	8b 03                	mov    (%ebx),%eax
f0104260:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104264:	c7 04 24 f3 57 10 f0 	movl   $0xf01057f3,(%esp)
f010426b:	e8 f1 dd ff ff       	call   f0102061 <cprintf>
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0104270:	39 fb                	cmp    %edi,%ebx
f0104272:	74 09                	je     f010427d <spin_unlock+0xe1>
f0104274:	83 c3 04             	add    $0x4,%ebx
f0104277:	8b 03                	mov    (%ebx),%eax
f0104279:	85 c0                	test   %eax,%eax
f010427b:	75 98                	jne    f0104215 <spin_unlock+0x79>
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
		}
		panic("spin_unlock");
f010427d:	c7 44 24 08 fb 57 10 	movl   $0xf01057fb,0x8(%esp)
f0104284:	f0 
f0104285:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
f010428c:	00 
f010428d:	c7 04 24 cc 57 10 f0 	movl   $0xf01057cc,(%esp)
f0104294:	e8 a7 bd ff ff       	call   f0100040 <_panic>
	}

	lk->pcs[0] = 0;
f0104299:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
	lk->cpu = 0;
f01042a0:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f01042a7:	b8 00 00 00 00       	mov    $0x0,%eax
f01042ac:	f0 87 03             	lock xchg %eax,(%ebx)
	// Paper says that Intel 64 and IA-32 will not move a load
	// after a store. So lock->locked = 0 would work here.
	// The xchg being asm volatile ensures gcc emits it after
	// the above assignments (and after the critical section).
	xchg(&lk->locked, 0);
}
f01042af:	83 c4 6c             	add    $0x6c,%esp
f01042b2:	5b                   	pop    %ebx
f01042b3:	5e                   	pop    %esi
f01042b4:	5f                   	pop    %edi
f01042b5:	5d                   	pop    %ebp
f01042b6:	c3                   	ret    
f01042b7:	66 90                	xchg   %ax,%ax
f01042b9:	66 90                	xchg   %ax,%ax
f01042bb:	66 90                	xchg   %ax,%ax
f01042bd:	66 90                	xchg   %ax,%ax
f01042bf:	90                   	nop

f01042c0 <__udivdi3>:
f01042c0:	55                   	push   %ebp
f01042c1:	57                   	push   %edi
f01042c2:	56                   	push   %esi
f01042c3:	83 ec 0c             	sub    $0xc,%esp
f01042c6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01042ca:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f01042ce:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f01042d2:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01042d6:	85 c0                	test   %eax,%eax
f01042d8:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01042dc:	89 ea                	mov    %ebp,%edx
f01042de:	89 0c 24             	mov    %ecx,(%esp)
f01042e1:	75 2d                	jne    f0104310 <__udivdi3+0x50>
f01042e3:	39 e9                	cmp    %ebp,%ecx
f01042e5:	77 61                	ja     f0104348 <__udivdi3+0x88>
f01042e7:	85 c9                	test   %ecx,%ecx
f01042e9:	89 ce                	mov    %ecx,%esi
f01042eb:	75 0b                	jne    f01042f8 <__udivdi3+0x38>
f01042ed:	b8 01 00 00 00       	mov    $0x1,%eax
f01042f2:	31 d2                	xor    %edx,%edx
f01042f4:	f7 f1                	div    %ecx
f01042f6:	89 c6                	mov    %eax,%esi
f01042f8:	31 d2                	xor    %edx,%edx
f01042fa:	89 e8                	mov    %ebp,%eax
f01042fc:	f7 f6                	div    %esi
f01042fe:	89 c5                	mov    %eax,%ebp
f0104300:	89 f8                	mov    %edi,%eax
f0104302:	f7 f6                	div    %esi
f0104304:	89 ea                	mov    %ebp,%edx
f0104306:	83 c4 0c             	add    $0xc,%esp
f0104309:	5e                   	pop    %esi
f010430a:	5f                   	pop    %edi
f010430b:	5d                   	pop    %ebp
f010430c:	c3                   	ret    
f010430d:	8d 76 00             	lea    0x0(%esi),%esi
f0104310:	39 e8                	cmp    %ebp,%eax
f0104312:	77 24                	ja     f0104338 <__udivdi3+0x78>
f0104314:	0f bd e8             	bsr    %eax,%ebp
f0104317:	83 f5 1f             	xor    $0x1f,%ebp
f010431a:	75 3c                	jne    f0104358 <__udivdi3+0x98>
f010431c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0104320:	39 34 24             	cmp    %esi,(%esp)
f0104323:	0f 86 9f 00 00 00    	jbe    f01043c8 <__udivdi3+0x108>
f0104329:	39 d0                	cmp    %edx,%eax
f010432b:	0f 82 97 00 00 00    	jb     f01043c8 <__udivdi3+0x108>
f0104331:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0104338:	31 d2                	xor    %edx,%edx
f010433a:	31 c0                	xor    %eax,%eax
f010433c:	83 c4 0c             	add    $0xc,%esp
f010433f:	5e                   	pop    %esi
f0104340:	5f                   	pop    %edi
f0104341:	5d                   	pop    %ebp
f0104342:	c3                   	ret    
f0104343:	90                   	nop
f0104344:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0104348:	89 f8                	mov    %edi,%eax
f010434a:	f7 f1                	div    %ecx
f010434c:	31 d2                	xor    %edx,%edx
f010434e:	83 c4 0c             	add    $0xc,%esp
f0104351:	5e                   	pop    %esi
f0104352:	5f                   	pop    %edi
f0104353:	5d                   	pop    %ebp
f0104354:	c3                   	ret    
f0104355:	8d 76 00             	lea    0x0(%esi),%esi
f0104358:	89 e9                	mov    %ebp,%ecx
f010435a:	8b 3c 24             	mov    (%esp),%edi
f010435d:	d3 e0                	shl    %cl,%eax
f010435f:	89 c6                	mov    %eax,%esi
f0104361:	b8 20 00 00 00       	mov    $0x20,%eax
f0104366:	29 e8                	sub    %ebp,%eax
f0104368:	89 c1                	mov    %eax,%ecx
f010436a:	d3 ef                	shr    %cl,%edi
f010436c:	89 e9                	mov    %ebp,%ecx
f010436e:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0104372:	8b 3c 24             	mov    (%esp),%edi
f0104375:	09 74 24 08          	or     %esi,0x8(%esp)
f0104379:	89 d6                	mov    %edx,%esi
f010437b:	d3 e7                	shl    %cl,%edi
f010437d:	89 c1                	mov    %eax,%ecx
f010437f:	89 3c 24             	mov    %edi,(%esp)
f0104382:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0104386:	d3 ee                	shr    %cl,%esi
f0104388:	89 e9                	mov    %ebp,%ecx
f010438a:	d3 e2                	shl    %cl,%edx
f010438c:	89 c1                	mov    %eax,%ecx
f010438e:	d3 ef                	shr    %cl,%edi
f0104390:	09 d7                	or     %edx,%edi
f0104392:	89 f2                	mov    %esi,%edx
f0104394:	89 f8                	mov    %edi,%eax
f0104396:	f7 74 24 08          	divl   0x8(%esp)
f010439a:	89 d6                	mov    %edx,%esi
f010439c:	89 c7                	mov    %eax,%edi
f010439e:	f7 24 24             	mull   (%esp)
f01043a1:	39 d6                	cmp    %edx,%esi
f01043a3:	89 14 24             	mov    %edx,(%esp)
f01043a6:	72 30                	jb     f01043d8 <__udivdi3+0x118>
f01043a8:	8b 54 24 04          	mov    0x4(%esp),%edx
f01043ac:	89 e9                	mov    %ebp,%ecx
f01043ae:	d3 e2                	shl    %cl,%edx
f01043b0:	39 c2                	cmp    %eax,%edx
f01043b2:	73 05                	jae    f01043b9 <__udivdi3+0xf9>
f01043b4:	3b 34 24             	cmp    (%esp),%esi
f01043b7:	74 1f                	je     f01043d8 <__udivdi3+0x118>
f01043b9:	89 f8                	mov    %edi,%eax
f01043bb:	31 d2                	xor    %edx,%edx
f01043bd:	e9 7a ff ff ff       	jmp    f010433c <__udivdi3+0x7c>
f01043c2:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f01043c8:	31 d2                	xor    %edx,%edx
f01043ca:	b8 01 00 00 00       	mov    $0x1,%eax
f01043cf:	e9 68 ff ff ff       	jmp    f010433c <__udivdi3+0x7c>
f01043d4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01043d8:	8d 47 ff             	lea    -0x1(%edi),%eax
f01043db:	31 d2                	xor    %edx,%edx
f01043dd:	83 c4 0c             	add    $0xc,%esp
f01043e0:	5e                   	pop    %esi
f01043e1:	5f                   	pop    %edi
f01043e2:	5d                   	pop    %ebp
f01043e3:	c3                   	ret    
f01043e4:	66 90                	xchg   %ax,%ax
f01043e6:	66 90                	xchg   %ax,%ax
f01043e8:	66 90                	xchg   %ax,%ax
f01043ea:	66 90                	xchg   %ax,%ax
f01043ec:	66 90                	xchg   %ax,%ax
f01043ee:	66 90                	xchg   %ax,%ax

f01043f0 <__umoddi3>:
f01043f0:	55                   	push   %ebp
f01043f1:	57                   	push   %edi
f01043f2:	56                   	push   %esi
f01043f3:	83 ec 14             	sub    $0x14,%esp
f01043f6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01043fa:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01043fe:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0104402:	89 c7                	mov    %eax,%edi
f0104404:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104408:	8b 44 24 30          	mov    0x30(%esp),%eax
f010440c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0104410:	89 34 24             	mov    %esi,(%esp)
f0104413:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104417:	85 c0                	test   %eax,%eax
f0104419:	89 c2                	mov    %eax,%edx
f010441b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f010441f:	75 17                	jne    f0104438 <__umoddi3+0x48>
f0104421:	39 fe                	cmp    %edi,%esi
f0104423:	76 4b                	jbe    f0104470 <__umoddi3+0x80>
f0104425:	89 c8                	mov    %ecx,%eax
f0104427:	89 fa                	mov    %edi,%edx
f0104429:	f7 f6                	div    %esi
f010442b:	89 d0                	mov    %edx,%eax
f010442d:	31 d2                	xor    %edx,%edx
f010442f:	83 c4 14             	add    $0x14,%esp
f0104432:	5e                   	pop    %esi
f0104433:	5f                   	pop    %edi
f0104434:	5d                   	pop    %ebp
f0104435:	c3                   	ret    
f0104436:	66 90                	xchg   %ax,%ax
f0104438:	39 f8                	cmp    %edi,%eax
f010443a:	77 54                	ja     f0104490 <__umoddi3+0xa0>
f010443c:	0f bd e8             	bsr    %eax,%ebp
f010443f:	83 f5 1f             	xor    $0x1f,%ebp
f0104442:	75 5c                	jne    f01044a0 <__umoddi3+0xb0>
f0104444:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0104448:	39 3c 24             	cmp    %edi,(%esp)
f010444b:	0f 87 e7 00 00 00    	ja     f0104538 <__umoddi3+0x148>
f0104451:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0104455:	29 f1                	sub    %esi,%ecx
f0104457:	19 c7                	sbb    %eax,%edi
f0104459:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f010445d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0104461:	8b 44 24 08          	mov    0x8(%esp),%eax
f0104465:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0104469:	83 c4 14             	add    $0x14,%esp
f010446c:	5e                   	pop    %esi
f010446d:	5f                   	pop    %edi
f010446e:	5d                   	pop    %ebp
f010446f:	c3                   	ret    
f0104470:	85 f6                	test   %esi,%esi
f0104472:	89 f5                	mov    %esi,%ebp
f0104474:	75 0b                	jne    f0104481 <__umoddi3+0x91>
f0104476:	b8 01 00 00 00       	mov    $0x1,%eax
f010447b:	31 d2                	xor    %edx,%edx
f010447d:	f7 f6                	div    %esi
f010447f:	89 c5                	mov    %eax,%ebp
f0104481:	8b 44 24 04          	mov    0x4(%esp),%eax
f0104485:	31 d2                	xor    %edx,%edx
f0104487:	f7 f5                	div    %ebp
f0104489:	89 c8                	mov    %ecx,%eax
f010448b:	f7 f5                	div    %ebp
f010448d:	eb 9c                	jmp    f010442b <__umoddi3+0x3b>
f010448f:	90                   	nop
f0104490:	89 c8                	mov    %ecx,%eax
f0104492:	89 fa                	mov    %edi,%edx
f0104494:	83 c4 14             	add    $0x14,%esp
f0104497:	5e                   	pop    %esi
f0104498:	5f                   	pop    %edi
f0104499:	5d                   	pop    %ebp
f010449a:	c3                   	ret    
f010449b:	90                   	nop
f010449c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01044a0:	8b 04 24             	mov    (%esp),%eax
f01044a3:	be 20 00 00 00       	mov    $0x20,%esi
f01044a8:	89 e9                	mov    %ebp,%ecx
f01044aa:	29 ee                	sub    %ebp,%esi
f01044ac:	d3 e2                	shl    %cl,%edx
f01044ae:	89 f1                	mov    %esi,%ecx
f01044b0:	d3 e8                	shr    %cl,%eax
f01044b2:	89 e9                	mov    %ebp,%ecx
f01044b4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01044b8:	8b 04 24             	mov    (%esp),%eax
f01044bb:	09 54 24 04          	or     %edx,0x4(%esp)
f01044bf:	89 fa                	mov    %edi,%edx
f01044c1:	d3 e0                	shl    %cl,%eax
f01044c3:	89 f1                	mov    %esi,%ecx
f01044c5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01044c9:	8b 44 24 10          	mov    0x10(%esp),%eax
f01044cd:	d3 ea                	shr    %cl,%edx
f01044cf:	89 e9                	mov    %ebp,%ecx
f01044d1:	d3 e7                	shl    %cl,%edi
f01044d3:	89 f1                	mov    %esi,%ecx
f01044d5:	d3 e8                	shr    %cl,%eax
f01044d7:	89 e9                	mov    %ebp,%ecx
f01044d9:	09 f8                	or     %edi,%eax
f01044db:	8b 7c 24 10          	mov    0x10(%esp),%edi
f01044df:	f7 74 24 04          	divl   0x4(%esp)
f01044e3:	d3 e7                	shl    %cl,%edi
f01044e5:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01044e9:	89 d7                	mov    %edx,%edi
f01044eb:	f7 64 24 08          	mull   0x8(%esp)
f01044ef:	39 d7                	cmp    %edx,%edi
f01044f1:	89 c1                	mov    %eax,%ecx
f01044f3:	89 14 24             	mov    %edx,(%esp)
f01044f6:	72 2c                	jb     f0104524 <__umoddi3+0x134>
f01044f8:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f01044fc:	72 22                	jb     f0104520 <__umoddi3+0x130>
f01044fe:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0104502:	29 c8                	sub    %ecx,%eax
f0104504:	19 d7                	sbb    %edx,%edi
f0104506:	89 e9                	mov    %ebp,%ecx
f0104508:	89 fa                	mov    %edi,%edx
f010450a:	d3 e8                	shr    %cl,%eax
f010450c:	89 f1                	mov    %esi,%ecx
f010450e:	d3 e2                	shl    %cl,%edx
f0104510:	89 e9                	mov    %ebp,%ecx
f0104512:	d3 ef                	shr    %cl,%edi
f0104514:	09 d0                	or     %edx,%eax
f0104516:	89 fa                	mov    %edi,%edx
f0104518:	83 c4 14             	add    $0x14,%esp
f010451b:	5e                   	pop    %esi
f010451c:	5f                   	pop    %edi
f010451d:	5d                   	pop    %ebp
f010451e:	c3                   	ret    
f010451f:	90                   	nop
f0104520:	39 d7                	cmp    %edx,%edi
f0104522:	75 da                	jne    f01044fe <__umoddi3+0x10e>
f0104524:	8b 14 24             	mov    (%esp),%edx
f0104527:	89 c1                	mov    %eax,%ecx
f0104529:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f010452d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0104531:	eb cb                	jmp    f01044fe <__umoddi3+0x10e>
f0104533:	90                   	nop
f0104534:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0104538:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f010453c:	0f 82 0f ff ff ff    	jb     f0104451 <__umoddi3+0x61>
f0104542:	e9 1a ff ff ff       	jmp    f0104461 <__umoddi3+0x71>
