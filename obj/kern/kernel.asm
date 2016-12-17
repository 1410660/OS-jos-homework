
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
f0100015:	b8 00 d0 11 00       	mov    $0x11d000,%eax
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
f0100034:	bc 00 d0 11 f0       	mov    $0xf011d000,%esp

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
f010004b:	83 3d 00 2f 22 f0 00 	cmpl   $0x0,0xf0222f00
f0100052:	75 46                	jne    f010009a <_panic+0x5a>
		goto dead;
	panicstr = fmt;
f0100054:	89 35 00 2f 22 f0    	mov    %esi,0xf0222f00

	// Be extra sure that the machine is in as reasonable state
	__asm __volatile("cli; cld");
f010005a:	fa                   	cli    
f010005b:	fc                   	cld    

	va_start(ap, fmt);
f010005c:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic on CPU %d at %s:%d: ", cpunum(), file, line);
f010005f:	e8 0f 5c 00 00       	call   f0105c73 <cpunum>
f0100064:	8b 55 0c             	mov    0xc(%ebp),%edx
f0100067:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010006b:	8b 55 08             	mov    0x8(%ebp),%edx
f010006e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100072:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100076:	c7 04 24 80 63 10 f0 	movl   $0xf0106380,(%esp)
f010007d:	e8 fa 3d 00 00       	call   f0103e7c <cprintf>
	vcprintf(fmt, ap);
f0100082:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100086:	89 34 24             	mov    %esi,(%esp)
f0100089:	e8 bb 3d 00 00       	call   f0103e49 <vcprintf>
	cprintf("\n");
f010008e:	c7 04 24 8c 71 10 f0 	movl   $0xf010718c,(%esp)
f0100095:	e8 e2 3d 00 00       	call   f0103e7c <cprintf>
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
f01000af:	b8 04 40 26 f0       	mov    $0xf0264004,%eax
f01000b4:	2d 58 14 22 f0       	sub    $0xf0221458,%eax
f01000b9:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000bd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01000c4:	00 
f01000c5:	c7 04 24 58 14 22 f0 	movl   $0xf0221458,(%esp)
f01000cc:	e8 08 55 00 00       	call   f01055d9 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000d1:	e8 d9 05 00 00       	call   f01006af <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000d6:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000dd:	00 
f01000de:	c7 04 24 ec 63 10 f0 	movl   $0xf01063ec,(%esp)
f01000e5:	e8 92 3d 00 00       	call   f0103e7c <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f01000ea:	e8 d0 13 00 00       	call   f01014bf <mem_init>

	// Lab 3 user environment initialization functions
	env_init();
f01000ef:	e8 c1 34 00 00       	call   f01035b5 <env_init>
	trap_init();
f01000f4:	e8 04 3e 00 00       	call   f0103efd <trap_init>

	// Lab 4 multiprocessor initialization functions
	mp_init();
f01000f9:	e8 5b 58 00 00       	call   f0105959 <mp_init>
	lapic_init();
f01000fe:	66 90                	xchg   %ax,%ax
f0100100:	e8 89 5b 00 00       	call   f0105c8e <lapic_init>

	// Lab 4 multitasking initialization functions
	pic_init();
f0100105:	e8 9f 3c 00 00       	call   f0103da9 <pic_init>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010010a:	83 3d 08 2f 22 f0 07 	cmpl   $0x7,0xf0222f08
f0100111:	77 24                	ja     f0100137 <i386_init+0x8f>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100113:	c7 44 24 0c 00 70 00 	movl   $0x7000,0xc(%esp)
f010011a:	00 
f010011b:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f0100122:	f0 
f0100123:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f010012a:	00 
f010012b:	c7 04 24 07 64 10 f0 	movl   $0xf0106407,(%esp)
f0100132:	e8 09 ff ff ff       	call   f0100040 <_panic>
	void *code;
	struct Cpu *c;

	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);
f0100137:	b8 86 58 10 f0       	mov    $0xf0105886,%eax
f010013c:	2d 0c 58 10 f0       	sub    $0xf010580c,%eax
f0100141:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100145:	c7 44 24 04 0c 58 10 	movl   $0xf010580c,0x4(%esp)
f010014c:	f0 
f010014d:	c7 04 24 00 70 00 f0 	movl   $0xf0007000,(%esp)
f0100154:	e8 cd 54 00 00       	call   f0105626 <memmove>

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100159:	6b 05 c4 33 22 f0 74 	imul   $0x74,0xf02233c4,%eax
f0100160:	05 20 30 22 f0       	add    $0xf0223020,%eax
f0100165:	3d 20 30 22 f0       	cmp    $0xf0223020,%eax
f010016a:	0f 86 a6 00 00 00    	jbe    f0100216 <i386_init+0x16e>
f0100170:	bb 20 30 22 f0       	mov    $0xf0223020,%ebx
		if (c == cpus + cpunum())  // We've started already.
f0100175:	e8 f9 5a 00 00       	call   f0105c73 <cpunum>
f010017a:	6b c0 74             	imul   $0x74,%eax,%eax
f010017d:	05 20 30 22 f0       	add    $0xf0223020,%eax
f0100182:	39 c3                	cmp    %eax,%ebx
f0100184:	74 39                	je     f01001bf <i386_init+0x117>
f0100186:	89 d8                	mov    %ebx,%eax
f0100188:	2d 20 30 22 f0       	sub    $0xf0223020,%eax
			continue;

		// Tell mpentry.S what stack to use 
		mpentry_kstack = percpu_kstacks[c - cpus] + KSTKSIZE;
f010018d:	c1 f8 02             	sar    $0x2,%eax
f0100190:	69 c0 35 c2 72 4f    	imul   $0x4f72c235,%eax,%eax
f0100196:	c1 e0 0f             	shl    $0xf,%eax
f0100199:	8d 80 00 c0 22 f0    	lea    -0xfdd4000(%eax),%eax
f010019f:	a3 04 2f 22 f0       	mov    %eax,0xf0222f04
		// Start the CPU at mpentry_start
		lapic_startap(c->cpu_id, PADDR(code));
f01001a4:	c7 44 24 04 00 70 00 	movl   $0x7000,0x4(%esp)
f01001ab:	00 
f01001ac:	0f b6 03             	movzbl (%ebx),%eax
f01001af:	89 04 24             	mov    %eax,(%esp)
f01001b2:	e8 0f 5c 00 00       	call   f0105dc6 <lapic_startap>
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
f01001c2:	6b 05 c4 33 22 f0 74 	imul   $0x74,0xf02233c4,%eax
f01001c9:	05 20 30 22 f0       	add    $0xf0223020,%eax
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
f01001e4:	c7 04 24 2c ee 18 f0 	movl   $0xf018ee2c,(%esp)
f01001eb:	e8 be 35 00 00       	call   f01037ae <env_create>
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
f0100205:	c7 04 24 37 8a 21 f0 	movl   $0xf0218a37,(%esp)
f010020c:	e8 9d 35 00 00       	call   f01037ae <env_create>
#endif // TEST*

	// Schedule and run the first user environment!
	sched_yield();
f0100211:	e8 2b 45 00 00       	call   f0104741 <sched_yield>
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
f0100223:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100228:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010022d:	77 20                	ja     f010024f <mp_main+0x32>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010022f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100233:	c7 44 24 08 c8 63 10 	movl   $0xf01063c8,0x8(%esp)
f010023a:	f0 
f010023b:	c7 44 24 04 6e 00 00 	movl   $0x6e,0x4(%esp)
f0100242:	00 
f0100243:	c7 04 24 07 64 10 f0 	movl   $0xf0106407,(%esp)
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
f0100257:	e8 17 5a 00 00       	call   f0105c73 <cpunum>
f010025c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100260:	c7 04 24 13 64 10 f0 	movl   $0xf0106413,(%esp)
f0100267:	e8 10 3c 00 00       	call   f0103e7c <cprintf>

	lapic_init();
f010026c:	e8 1d 5a 00 00       	call   f0105c8e <lapic_init>
	env_init_percpu();
f0100271:	e8 15 33 00 00       	call   f010358b <env_init_percpu>
	trap_init_percpu();
f0100276:	e8 25 3c 00 00       	call   f0103ea0 <trap_init_percpu>
	xchg(&thiscpu->cpu_status, CPU_STARTED); // tell boot_aps() we're up
f010027b:	90                   	nop
f010027c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100280:	e8 ee 59 00 00       	call   f0105c73 <cpunum>
f0100285:	6b d0 74             	imul   $0x74,%eax,%edx
f0100288:	81 c2 20 30 22 f0    	add    $0xf0223020,%edx
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
f01002b1:	c7 04 24 29 64 10 f0 	movl   $0xf0106429,(%esp)
f01002b8:	e8 bf 3b 00 00       	call   f0103e7c <cprintf>
	vcprintf(fmt, ap);
f01002bd:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01002c1:	8b 45 10             	mov    0x10(%ebp),%eax
f01002c4:	89 04 24             	mov    %eax,(%esp)
f01002c7:	e8 7d 3b 00 00       	call   f0103e49 <vcprintf>
	cprintf("\n");
f01002cc:	c7 04 24 8c 71 10 f0 	movl   $0xf010718c,(%esp)
f01002d3:	e8 a4 3b 00 00       	call   f0103e7c <cprintf>
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
f010030b:	a1 24 22 22 f0       	mov    0xf0222224,%eax
f0100310:	8d 48 01             	lea    0x1(%eax),%ecx
f0100313:	89 0d 24 22 22 f0    	mov    %ecx,0xf0222224
f0100319:	88 90 20 20 22 f0    	mov    %dl,-0xfdddfe0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f010031f:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100325:	75 0a                	jne    f0100331 <cons_intr+0x35>
			cons.wpos = 0;
f0100327:	c7 05 24 22 22 f0 00 	movl   $0x0,0xf0222224
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
f0100357:	83 0d 00 20 22 f0 40 	orl    $0x40,0xf0222000
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
f010036f:	8b 0d 00 20 22 f0    	mov    0xf0222000,%ecx
f0100375:	89 cb                	mov    %ecx,%ebx
f0100377:	83 e3 40             	and    $0x40,%ebx
f010037a:	83 e0 7f             	and    $0x7f,%eax
f010037d:	85 db                	test   %ebx,%ebx
f010037f:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f0100382:	0f b6 d2             	movzbl %dl,%edx
f0100385:	0f b6 82 a0 65 10 f0 	movzbl -0xfef9a60(%edx),%eax
f010038c:	83 c8 40             	or     $0x40,%eax
f010038f:	0f b6 c0             	movzbl %al,%eax
f0100392:	f7 d0                	not    %eax
f0100394:	21 c1                	and    %eax,%ecx
f0100396:	89 0d 00 20 22 f0    	mov    %ecx,0xf0222000
		return 0;
f010039c:	b8 00 00 00 00       	mov    $0x0,%eax
f01003a1:	e9 9d 00 00 00       	jmp    f0100443 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f01003a6:	8b 0d 00 20 22 f0    	mov    0xf0222000,%ecx
f01003ac:	f6 c1 40             	test   $0x40,%cl
f01003af:	74 0e                	je     f01003bf <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f01003b1:	83 c8 80             	or     $0xffffff80,%eax
f01003b4:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f01003b6:	83 e1 bf             	and    $0xffffffbf,%ecx
f01003b9:	89 0d 00 20 22 f0    	mov    %ecx,0xf0222000
	}

	shift |= shiftcode[data];
f01003bf:	0f b6 d2             	movzbl %dl,%edx
f01003c2:	0f b6 82 a0 65 10 f0 	movzbl -0xfef9a60(%edx),%eax
f01003c9:	0b 05 00 20 22 f0    	or     0xf0222000,%eax
	shift ^= togglecode[data];
f01003cf:	0f b6 8a a0 64 10 f0 	movzbl -0xfef9b60(%edx),%ecx
f01003d6:	31 c8                	xor    %ecx,%eax
f01003d8:	a3 00 20 22 f0       	mov    %eax,0xf0222000

	c = charcode[shift & (CTL | SHIFT)][data];
f01003dd:	89 c1                	mov    %eax,%ecx
f01003df:	83 e1 03             	and    $0x3,%ecx
f01003e2:	8b 0c 8d 80 64 10 f0 	mov    -0xfef9b80(,%ecx,4),%ecx
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
f0100422:	c7 04 24 43 64 10 f0 	movl   $0xf0106443,(%esp)
f0100429:	e8 4e 3a 00 00       	call   f0103e7c <cprintf>
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
f010050c:	0f b7 05 28 22 22 f0 	movzwl 0xf0222228,%eax
f0100513:	66 85 c0             	test   %ax,%ax
f0100516:	0f 84 e5 00 00 00    	je     f0100601 <cons_putc+0x1b8>
			crt_pos--;
f010051c:	83 e8 01             	sub    $0x1,%eax
f010051f:	66 a3 28 22 22 f0    	mov    %ax,0xf0222228
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100525:	0f b7 c0             	movzwl %ax,%eax
f0100528:	66 81 e7 00 ff       	and    $0xff00,%di
f010052d:	83 cf 20             	or     $0x20,%edi
f0100530:	8b 15 2c 22 22 f0    	mov    0xf022222c,%edx
f0100536:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f010053a:	eb 78                	jmp    f01005b4 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f010053c:	66 83 05 28 22 22 f0 	addw   $0x50,0xf0222228
f0100543:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f0100544:	0f b7 05 28 22 22 f0 	movzwl 0xf0222228,%eax
f010054b:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100551:	c1 e8 16             	shr    $0x16,%eax
f0100554:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0100557:	c1 e0 04             	shl    $0x4,%eax
f010055a:	66 a3 28 22 22 f0    	mov    %ax,0xf0222228
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
f0100596:	0f b7 05 28 22 22 f0 	movzwl 0xf0222228,%eax
f010059d:	8d 50 01             	lea    0x1(%eax),%edx
f01005a0:	66 89 15 28 22 22 f0 	mov    %dx,0xf0222228
f01005a7:	0f b7 c0             	movzwl %ax,%eax
f01005aa:	8b 15 2c 22 22 f0    	mov    0xf022222c,%edx
f01005b0:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f01005b4:	66 81 3d 28 22 22 f0 	cmpw   $0x7cf,0xf0222228
f01005bb:	cf 07 
f01005bd:	76 42                	jbe    f0100601 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f01005bf:	a1 2c 22 22 f0       	mov    0xf022222c,%eax
f01005c4:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f01005cb:	00 
f01005cc:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f01005d2:	89 54 24 04          	mov    %edx,0x4(%esp)
f01005d6:	89 04 24             	mov    %eax,(%esp)
f01005d9:	e8 48 50 00 00       	call   f0105626 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f01005de:	8b 15 2c 22 22 f0    	mov    0xf022222c,%edx
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
f01005f9:	66 83 2d 28 22 22 f0 	subw   $0x50,0xf0222228
f0100600:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100601:	8b 0d 30 22 22 f0    	mov    0xf0222230,%ecx
f0100607:	b8 0e 00 00 00       	mov    $0xe,%eax
f010060c:	89 ca                	mov    %ecx,%edx
f010060e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010060f:	0f b7 1d 28 22 22 f0 	movzwl 0xf0222228,%ebx
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
f0100637:	83 3d 34 22 22 f0 00 	cmpl   $0x0,0xf0222234
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
f0100675:	a1 20 22 22 f0       	mov    0xf0222220,%eax
f010067a:	3b 05 24 22 22 f0    	cmp    0xf0222224,%eax
f0100680:	74 26                	je     f01006a8 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f0100682:	8d 50 01             	lea    0x1(%eax),%edx
f0100685:	89 15 20 22 22 f0    	mov    %edx,0xf0222220
f010068b:	0f b6 88 20 20 22 f0 	movzbl -0xfdddfe0(%eax),%ecx
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
f010069c:	c7 05 20 22 22 f0 00 	movl   $0x0,0xf0222220
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
f01006d5:	c7 05 30 22 22 f0 b4 	movl   $0x3b4,0xf0222230
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
f01006ed:	c7 05 30 22 22 f0 d4 	movl   $0x3d4,0xf0222230
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
f01006fc:	8b 0d 30 22 22 f0    	mov    0xf0222230,%ecx
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
f0100721:	89 3d 2c 22 22 f0    	mov    %edi,0xf022222c
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f0100727:	0f b6 d8             	movzbl %al,%ebx
f010072a:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f010072c:	66 89 35 28 22 22 f0 	mov    %si,0xf0222228

static void
kbd_init(void)
{
	// Drain the kbd buffer so that Bochs generates interrupts.
	kbd_intr();
f0100733:	e8 1b ff ff ff       	call   f0100653 <kbd_intr>
	irq_setmask_8259A(irq_mask_8259A & ~(1<<1));
f0100738:	0f b7 05 88 f3 11 f0 	movzwl 0xf011f388,%eax
f010073f:	25 fd ff 00 00       	and    $0xfffd,%eax
f0100744:	89 04 24             	mov    %eax,(%esp)
f0100747:	e8 ee 35 00 00       	call   f0103d3a <irq_setmask_8259A>
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
f0100799:	89 0d 34 22 22 f0    	mov    %ecx,0xf0222234
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
f01007a9:	c7 04 24 4f 64 10 f0 	movl   $0xf010644f,(%esp)
f01007b0:	e8 c7 36 00 00       	call   f0103e7c <cprintf>
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
f01007f6:	c7 44 24 08 a0 66 10 	movl   $0xf01066a0,0x8(%esp)
f01007fd:	f0 
f01007fe:	c7 44 24 04 be 66 10 	movl   $0xf01066be,0x4(%esp)
f0100805:	f0 
f0100806:	c7 04 24 c3 66 10 f0 	movl   $0xf01066c3,(%esp)
f010080d:	e8 6a 36 00 00       	call   f0103e7c <cprintf>
f0100812:	c7 44 24 08 60 67 10 	movl   $0xf0106760,0x8(%esp)
f0100819:	f0 
f010081a:	c7 44 24 04 cc 66 10 	movl   $0xf01066cc,0x4(%esp)
f0100821:	f0 
f0100822:	c7 04 24 c3 66 10 f0 	movl   $0xf01066c3,(%esp)
f0100829:	e8 4e 36 00 00       	call   f0103e7c <cprintf>
f010082e:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f0100835:	f0 
f0100836:	c7 44 24 04 d5 66 10 	movl   $0xf01066d5,0x4(%esp)
f010083d:	f0 
f010083e:	c7 04 24 c3 66 10 f0 	movl   $0xf01066c3,(%esp)
f0100845:	e8 32 36 00 00       	call   f0103e7c <cprintf>
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
f0100857:	c7 04 24 df 66 10 f0 	movl   $0xf01066df,(%esp)
f010085e:	e8 19 36 00 00       	call   f0103e7c <cprintf>
	cprintf(" this is work 1 insert:\n");
f0100863:	c7 04 24 f8 66 10 f0 	movl   $0xf01066f8,(%esp)
f010086a:	e8 0d 36 00 00       	call   f0103e7c <cprintf>
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
f010086f:	c7 44 24 08 0f 00 00 	movl   $0xf,0x8(%esp)
f0100876:	00 
f0100877:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
f010087e:	00 
f010087f:	c7 04 24 b4 67 10 f0 	movl   $0xf01067b4,(%esp)
f0100886:	e8 f1 35 00 00       	call   f0103e7c <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
f010088b:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f0100892:	00 
f0100893:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f010089a:	f0 
f010089b:	c7 04 24 ec 67 10 f0 	movl   $0xf01067ec,(%esp)
f01008a2:	e8 d5 35 00 00       	call   f0103e7c <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01008a7:	c7 44 24 08 67 63 10 	movl   $0x106367,0x8(%esp)
f01008ae:	00 
f01008af:	c7 44 24 04 67 63 10 	movl   $0xf0106367,0x4(%esp)
f01008b6:	f0 
f01008b7:	c7 04 24 14 68 10 f0 	movl   $0xf0106814,(%esp)
f01008be:	e8 b9 35 00 00       	call   f0103e7c <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01008c3:	c7 44 24 08 58 14 22 	movl   $0x221458,0x8(%esp)
f01008ca:	00 
f01008cb:	c7 44 24 04 58 14 22 	movl   $0xf0221458,0x4(%esp)
f01008d2:	f0 
f01008d3:	c7 04 24 38 68 10 f0 	movl   $0xf0106838,(%esp)
f01008da:	e8 9d 35 00 00       	call   f0103e7c <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f01008df:	c7 44 24 08 04 40 26 	movl   $0x264004,0x8(%esp)
f01008e6:	00 
f01008e7:	c7 44 24 04 04 40 26 	movl   $0xf0264004,0x4(%esp)
f01008ee:	f0 
f01008ef:	c7 04 24 5c 68 10 f0 	movl   $0xf010685c,(%esp)
f01008f6:	e8 81 35 00 00       	call   f0103e7c <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f01008fb:	b8 03 44 26 f0       	mov    $0xf0264403,%eax
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
f0100917:	c7 04 24 80 68 10 f0 	movl   $0xf0106880,(%esp)
f010091e:	e8 59 35 00 00       	call   f0103e7c <cprintf>
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
f0100932:	c7 04 24 11 67 10 f0 	movl   $0xf0106711,(%esp)
f0100939:	e8 3e 35 00 00       	call   f0103e7c <cprintf>
	cprintf("\n");
f010093e:	c7 04 24 8c 71 10 f0 	movl   $0xf010718c,(%esp)
f0100945:	e8 32 35 00 00       	call   f0103e7c <cprintf>

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
f01009a1:	c7 04 24 ac 68 10 f0 	movl   $0xf01068ac,(%esp)
f01009a8:	e8 cf 34 00 00       	call   f0103e7c <cprintf>
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
f01009cb:	c7 04 24 e8 68 10 f0 	movl   $0xf01068e8,(%esp)
f01009d2:	e8 a5 34 00 00       	call   f0103e7c <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f01009d7:	c7 04 24 0c 69 10 f0 	movl   $0xf010690c,(%esp)
f01009de:	e8 99 34 00 00       	call   f0103e7c <cprintf>

	if (tf != NULL)
f01009e3:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f01009e7:	74 0b                	je     f01009f4 <monitor+0x32>
		print_trapframe(tf);
f01009e9:	8b 45 08             	mov    0x8(%ebp),%eax
f01009ec:	89 04 24             	mov    %eax,(%esp)
f01009ef:	e8 c0 38 00 00       	call   f01042b4 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f01009f4:	c7 04 24 22 67 10 f0 	movl   $0xf0106722,(%esp)
f01009fb:	e8 00 49 00 00       	call   f0105300 <readline>
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
f0100a2c:	c7 04 24 26 67 10 f0 	movl   $0xf0106726,(%esp)
f0100a33:	e8 41 4b 00 00       	call   f0105579 <strchr>
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
f0100a4e:	c7 04 24 2b 67 10 f0 	movl   $0xf010672b,(%esp)
f0100a55:	e8 22 34 00 00       	call   f0103e7c <cprintf>
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
f0100a7d:	c7 04 24 26 67 10 f0 	movl   $0xf0106726,(%esp)
f0100a84:	e8 f0 4a 00 00       	call   f0105579 <strchr>
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
f0100aa7:	8b 04 85 40 69 10 f0 	mov    -0xfef96c0(,%eax,4),%eax
f0100aae:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100ab2:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100ab5:	89 04 24             	mov    %eax,(%esp)
f0100ab8:	e8 38 4a 00 00       	call   f01054f5 <strcmp>
f0100abd:	85 c0                	test   %eax,%eax
f0100abf:	75 24                	jne    f0100ae5 <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100ac1:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100ac4:	8b 55 08             	mov    0x8(%ebp),%edx
f0100ac7:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100acb:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100ace:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100ad2:	89 34 24             	mov    %esi,(%esp)
f0100ad5:	ff 14 85 48 69 10 f0 	call   *-0xfef96b8(,%eax,4)
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
f0100af4:	c7 04 24 48 67 10 f0 	movl   $0xf0106748,(%esp)
f0100afb:	e8 7c 33 00 00       	call   f0103e7c <cprintf>
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
f0100b27:	83 3d 38 22 22 f0 00 	cmpl   $0x0,0xf0222238
f0100b2e:	75 36                	jne    f0100b66 <boot_alloc+0x46>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100b30:	ba 03 50 26 f0       	mov    $0xf0265003,%edx
f0100b35:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0100b3b:	89 15 38 22 22 f0    	mov    %edx,0xf0222238
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f0100b41:	85 c0                	test   %eax,%eax
f0100b43:	74 19                	je     f0100b5e <boot_alloc+0x3e>
                      result = nextfree;
f0100b45:	8b 1d 38 22 22 f0    	mov    0xf0222238,%ebx
                      nextfree += ROUNDUP(n, PGSIZE);
f0100b4b:	05 ff 0f 00 00       	add    $0xfff,%eax
f0100b50:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100b55:	01 d8                	add    %ebx,%eax
f0100b57:	a3 38 22 22 f0       	mov    %eax,0xf0222238
f0100b5c:	eb 0e                	jmp    f0100b6c <boot_alloc+0x4c>
               } else if (n == 0)
                      result = nextfree;
f0100b5e:	8b 1d 38 22 22 f0    	mov    0xf0222238,%ebx
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
f0100b70:	c7 04 24 64 69 10 f0 	movl   $0xf0106964,(%esp)
f0100b77:	e8 00 33 00 00       	call   f0103e7c <cprintf>
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
f0100b9a:	3b 0d 08 2f 22 f0    	cmp    0xf0222f08,%ecx
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
f0100bac:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f0100bb3:	f0 
f0100bb4:	c7 44 24 04 7f 03 00 	movl   $0x37f,0x4(%esp)
f0100bbb:	00 
f0100bbc:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
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
f0100bfe:	0f 85 a8 03 00 00    	jne    f0100fac <check_page_free_list+0x3b9>
f0100c04:	e9 b5 03 00 00       	jmp    f0100fbe <check_page_free_list+0x3cb>
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
		panic("'page_free_list' is a null pointer!");
f0100c09:	c7 44 24 08 b0 69 10 	movl   $0xf01069b0,0x8(%esp)
f0100c10:	f0 
f0100c11:	c7 44 24 04 ae 02 00 	movl   $0x2ae,0x4(%esp)
f0100c18:	00 
f0100c19:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
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
f0100c33:	2b 15 10 2f 22 f0    	sub    0xf0222f10,%edx
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
f0100c69:	a3 40 22 22 f0       	mov    %eax,0xf0222240
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
f0100c7b:	2b 05 10 2f 22 f0    	sub    0xf0222f10,%eax
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
f0100c95:	3b 15 08 2f 22 f0    	cmp    0xf0222f08,%edx
f0100c9b:	72 20                	jb     f0100cbd <check_page_free_list+0xca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100c9d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100ca1:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f0100ca8:	f0 
f0100ca9:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100cb0:	00 
f0100cb1:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f0100cb8:	e8 83 f3 ff ff       	call   f0100040 <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100cbd:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100cc4:	00 
f0100cc5:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100ccc:	00 
	return (void *)(pa + KERNBASE);
f0100ccd:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100cd2:	89 04 24             	mov    %eax,(%esp)
f0100cd5:	e8 ff 48 00 00       	call   f01055d9 <memset>
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
f0100cea:	89 45 d0             	mov    %eax,-0x30(%ebp)
	cprintf("EXTPHYSMEM belonging to page %d \n",PGNUM(EXTPHYSMEM));
f0100ced:	c7 44 24 04 00 01 00 	movl   $0x100,0x4(%esp)
f0100cf4:	00 
f0100cf5:	c7 04 24 d4 69 10 f0 	movl   $0xf01069d4,(%esp)
f0100cfc:	e8 7b 31 00 00       	call   f0103e7c <cprintf>
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100d01:	8b 1d 40 22 22 f0    	mov    0xf0222240,%ebx
f0100d07:	85 db                	test   %ebx,%ebx
f0100d09:	0f 84 51 02 00 00    	je     f0100f60 <check_page_free_list+0x36d>
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d0f:	a1 10 2f 22 f0       	mov    0xf0222f10,%eax
f0100d14:	39 c3                	cmp    %eax,%ebx
f0100d16:	72 3f                	jb     f0100d57 <check_page_free_list+0x164>
		assert(pp < pages + npages);
f0100d18:	8b 15 08 2f 22 f0    	mov    0xf0222f08,%edx
f0100d1e:	8d 14 d0             	lea    (%eax,%edx,8),%edx
f0100d21:	39 d3                	cmp    %edx,%ebx
f0100d23:	73 63                	jae    f0100d88 <check_page_free_list+0x195>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100d25:	89 de                	mov    %ebx,%esi
f0100d27:	89 df                	mov    %ebx,%edi
f0100d29:	29 c7                	sub    %eax,%edi
f0100d2b:	89 f8                	mov    %edi,%eax
f0100d2d:	a8 07                	test   $0x7,%al
f0100d2f:	0f 85 83 00 00 00    	jne    f0100db8 <check_page_free_list+0x1c5>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100d35:	c1 f8 03             	sar    $0x3,%eax
f0100d38:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100d3b:	85 c0                	test   %eax,%eax
f0100d3d:	0f 84 a3 00 00 00    	je     f0100de6 <check_page_free_list+0x1f3>
		assert(page2pa(pp) != IOPHYSMEM);
f0100d43:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100d48:	0f 85 e7 00 00 00    	jne    f0100e35 <check_page_free_list+0x242>
f0100d4e:	e9 be 00 00 00       	jmp    f0100e11 <check_page_free_list+0x21e>

	first_free_page = (char *) boot_alloc(0);
	cprintf("EXTPHYSMEM belonging to page %d \n",PGNUM(EXTPHYSMEM));
	for (pp = page_free_list; pp; pp = pp->pp_link) {
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d53:	39 c3                	cmp    %eax,%ebx
f0100d55:	73 24                	jae    f0100d7b <check_page_free_list+0x188>
f0100d57:	c7 44 24 0c 0b 71 10 	movl   $0xf010710b,0xc(%esp)
f0100d5e:	f0 
f0100d5f:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0100d66:	f0 
f0100d67:	c7 44 24 04 c9 02 00 	movl   $0x2c9,0x4(%esp)
f0100d6e:	00 
f0100d6f:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0100d76:	e8 c5 f2 ff ff       	call   f0100040 <_panic>
		assert(pp < pages + npages);
f0100d7b:	8b 15 08 2f 22 f0    	mov    0xf0222f08,%edx
f0100d81:	8d 14 d0             	lea    (%eax,%edx,8),%edx
f0100d84:	39 d3                	cmp    %edx,%ebx
f0100d86:	72 24                	jb     f0100dac <check_page_free_list+0x1b9>
f0100d88:	c7 44 24 0c 2c 71 10 	movl   $0xf010712c,0xc(%esp)
f0100d8f:	f0 
f0100d90:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0100d97:	f0 
f0100d98:	c7 44 24 04 ca 02 00 	movl   $0x2ca,0x4(%esp)
f0100d9f:	00 
f0100da0:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0100da7:	e8 94 f2 ff ff       	call   f0100040 <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100dac:	89 de                	mov    %ebx,%esi
f0100dae:	89 d9                	mov    %ebx,%ecx
f0100db0:	29 c1                	sub    %eax,%ecx
f0100db2:	89 c8                	mov    %ecx,%eax
f0100db4:	a8 07                	test   $0x7,%al
f0100db6:	74 24                	je     f0100ddc <check_page_free_list+0x1e9>
f0100db8:	c7 44 24 0c f8 69 10 	movl   $0xf01069f8,0xc(%esp)
f0100dbf:	f0 
f0100dc0:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0100dc7:	f0 
f0100dc8:	c7 44 24 04 cb 02 00 	movl   $0x2cb,0x4(%esp)
f0100dcf:	00 
f0100dd0:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0100dd7:	e8 64 f2 ff ff       	call   f0100040 <_panic>
f0100ddc:	c1 f8 03             	sar    $0x3,%eax
f0100ddf:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100de2:	85 c0                	test   %eax,%eax
f0100de4:	75 24                	jne    f0100e0a <check_page_free_list+0x217>
f0100de6:	c7 44 24 0c 40 71 10 	movl   $0xf0107140,0xc(%esp)
f0100ded:	f0 
f0100dee:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0100df5:	f0 
f0100df6:	c7 44 24 04 ce 02 00 	movl   $0x2ce,0x4(%esp)
f0100dfd:	00 
f0100dfe:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0100e05:	e8 36 f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100e0a:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100e0f:	75 30                	jne    f0100e41 <check_page_free_list+0x24e>
f0100e11:	c7 44 24 0c 51 71 10 	movl   $0xf0107151,0xc(%esp)
f0100e18:	f0 
f0100e19:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0100e20:	f0 
f0100e21:	c7 44 24 04 cf 02 00 	movl   $0x2cf,0x4(%esp)
f0100e28:	00 
f0100e29:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0100e30:	e8 0b f2 ff ff       	call   f0100040 <_panic>
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
f0100e35:	bf 00 00 00 00       	mov    $0x0,%edi
f0100e3a:	c7 45 d4 00 00 00 00 	movl   $0x0,-0x2c(%ebp)
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
f0100e41:	3d 00 f0 0f 00       	cmp    $0xff000,%eax
f0100e46:	75 24                	jne    f0100e6c <check_page_free_list+0x279>
f0100e48:	c7 44 24 0c 2c 6a 10 	movl   $0xf0106a2c,0xc(%esp)
f0100e4f:	f0 
f0100e50:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0100e57:	f0 
f0100e58:	c7 44 24 04 d0 02 00 	movl   $0x2d0,0x4(%esp)
f0100e5f:	00 
f0100e60:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0100e67:	e8 d4 f1 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100e6c:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100e71:	75 24                	jne    f0100e97 <check_page_free_list+0x2a4>
f0100e73:	c7 44 24 0c 6a 71 10 	movl   $0xf010716a,0xc(%esp)
f0100e7a:	f0 
f0100e7b:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0100e82:	f0 
f0100e83:	c7 44 24 04 d1 02 00 	movl   $0x2d1,0x4(%esp)
f0100e8a:	00 
f0100e8b:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0100e92:	e8 a9 f1 ff ff       	call   f0100040 <_panic>
		cprintf("page %d \n",PGNUM(page2pa(pp)));
f0100e97:	c1 e8 0c             	shr    $0xc,%eax
f0100e9a:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100e9e:	c7 04 24 84 71 10 f0 	movl   $0xf0107184,(%esp)
f0100ea5:	e8 d2 2f 00 00       	call   f0103e7c <cprintf>
f0100eaa:	a1 10 2f 22 f0       	mov    0xf0222f10,%eax
f0100eaf:	29 c6                	sub    %eax,%esi
f0100eb1:	c1 fe 03             	sar    $0x3,%esi
f0100eb4:	c1 e6 0c             	shl    $0xc,%esi
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100eb7:	81 fe 00 70 00 00    	cmp    $0x7000,%esi
f0100ebd:	75 24                	jne    f0100ee3 <check_page_free_list+0x2f0>
f0100ebf:	c7 44 24 0c 8e 71 10 	movl   $0xf010718e,0xc(%esp)
f0100ec6:	f0 
f0100ec7:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0100ece:	f0 
f0100ecf:	c7 44 24 04 d3 02 00 	movl   $0x2d3,0x4(%esp)
f0100ed6:	00 
f0100ed7:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0100ede:	e8 5d f1 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
f0100ee3:	81 fe ff ff 0f 00    	cmp    $0xfffff,%esi
f0100ee9:	76 5c                	jbe    f0100f47 <check_page_free_list+0x354>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100eeb:	89 f1                	mov    %esi,%ecx
f0100eed:	c1 e9 0c             	shr    $0xc,%ecx
f0100ef0:	3b 0d 08 2f 22 f0    	cmp    0xf0222f08,%ecx
f0100ef6:	72 20                	jb     f0100f18 <check_page_free_list+0x325>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100ef8:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0100efc:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f0100f03:	f0 
f0100f04:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100f0b:	00 
f0100f0c:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f0100f13:	e8 28 f1 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0100f18:	81 ee 00 00 00 10    	sub    $0x10000000,%esi
f0100f1e:	39 75 d0             	cmp    %esi,-0x30(%ebp)
f0100f21:	76 2a                	jbe    f0100f4d <check_page_free_list+0x35a>
f0100f23:	c7 44 24 0c 50 6a 10 	movl   $0xf0106a50,0xc(%esp)
f0100f2a:	f0 
f0100f2b:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0100f32:	f0 
f0100f33:	c7 44 24 04 d4 02 00 	movl   $0x2d4,0x4(%esp)
f0100f3a:	00 
f0100f3b:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0100f42:	e8 f9 f0 ff ff       	call   f0100040 <_panic>
		// (new test for lab 4)
		

		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
f0100f47:	83 45 d4 01          	addl   $0x1,-0x2c(%ebp)
f0100f4b:	eb 03                	jmp    f0100f50 <check_page_free_list+0x35d>
		else
			++nfree_extmem;
f0100f4d:	83 c7 01             	add    $0x1,%edi
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	cprintf("EXTPHYSMEM belonging to page %d \n",PGNUM(EXTPHYSMEM));
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100f50:	8b 1b                	mov    (%ebx),%ebx
f0100f52:	85 db                	test   %ebx,%ebx
f0100f54:	0f 85 f9 fd ff ff    	jne    f0100d53 <check_page_free_list+0x160>
			++nfree_basemem;
		else
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
f0100f5a:	83 7d d4 00          	cmpl   $0x0,-0x2c(%ebp)
f0100f5e:	7f 24                	jg     f0100f84 <check_page_free_list+0x391>
f0100f60:	c7 44 24 0c ab 71 10 	movl   $0xf01071ab,0xc(%esp)
f0100f67:	f0 
f0100f68:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0100f6f:	f0 
f0100f70:	c7 44 24 04 de 02 00 	movl   $0x2de,0x4(%esp)
f0100f77:	00 
f0100f78:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0100f7f:	e8 bc f0 ff ff       	call   f0100040 <_panic>
	assert(nfree_extmem > 0);
f0100f84:	85 ff                	test   %edi,%edi
f0100f86:	7f 53                	jg     f0100fdb <check_page_free_list+0x3e8>
f0100f88:	c7 44 24 0c bd 71 10 	movl   $0xf01071bd,0xc(%esp)
f0100f8f:	f0 
f0100f90:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0100f97:	f0 
f0100f98:	c7 44 24 04 df 02 00 	movl   $0x2df,0x4(%esp)
f0100f9f:	00 
f0100fa0:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0100fa7:	e8 94 f0 ff ff       	call   f0100040 <_panic>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100fac:	a1 40 22 22 f0       	mov    0xf0222240,%eax
f0100fb1:	85 c0                	test   %eax,%eax
f0100fb3:	0f 85 6c fc ff ff    	jne    f0100c25 <check_page_free_list+0x32>
f0100fb9:	e9 4b fc ff ff       	jmp    f0100c09 <check_page_free_list+0x16>
f0100fbe:	83 3d 40 22 22 f0 00 	cmpl   $0x0,0xf0222240
f0100fc5:	0f 84 3e fc ff ff    	je     f0100c09 <check_page_free_list+0x16>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100fcb:	8b 1d 40 22 22 f0    	mov    0xf0222240,%ebx
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100fd1:	be 00 04 00 00       	mov    $0x400,%esi
f0100fd6:	e9 9e fc ff ff       	jmp    f0100c79 <check_page_free_list+0x86>
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
	assert(nfree_extmem > 0);
}
f0100fdb:	83 c4 3c             	add    $0x3c,%esp
f0100fde:	5b                   	pop    %ebx
f0100fdf:	5e                   	pop    %esi
f0100fe0:	5f                   	pop    %edi
f0100fe1:	5d                   	pop    %ebp
f0100fe2:	c3                   	ret    

f0100fe3 <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0100fe3:	55                   	push   %ebp
f0100fe4:	89 e5                	mov    %esp,%ebp
f0100fe6:	53                   	push   %ebx
f0100fe7:	83 ec 14             	sub    $0x14,%esp
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100fea:	83 3d 08 2f 22 f0 00 	cmpl   $0x0,0xf0222f08
f0100ff1:	0f 84 3e 01 00 00    	je     f0101135 <page_init+0x152>
f0100ff7:	8b 1d 40 22 22 f0    	mov    0xf0222240,%ebx
f0100ffd:	b8 00 00 00 00       	mov    $0x0,%eax
f0101002:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
		pages[i].pp_ref = 0;
f0101009:	89 d1                	mov    %edx,%ecx
f010100b:	03 0d 10 2f 22 f0    	add    0xf0222f10,%ecx
f0101011:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0101017:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f0101019:	03 15 10 2f 22 f0    	add    0xf0222f10,%edx
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f010101f:	83 c0 01             	add    $0x1,%eax
f0101022:	8b 0d 08 2f 22 f0    	mov    0xf0222f08,%ecx
f0101028:	39 c1                	cmp    %eax,%ecx
f010102a:	76 04                	jbe    f0101030 <page_init+0x4d>
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f010102c:	89 d3                	mov    %edx,%ebx
f010102e:	eb d2                	jmp    f0101002 <page_init+0x1f>
f0101030:	89 15 40 22 22 f0    	mov    %edx,0xf0222240
	}

	//remove physical page 0 from page_free_list
             pages[1].pp_link = NULL;
f0101036:	a1 10 2f 22 f0       	mov    0xf0222f10,%eax
f010103b:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101042:	81 f9 a0 00 00 00    	cmp    $0xa0,%ecx
f0101048:	77 1c                	ja     f0101066 <page_init+0x83>
		panic("pa2page called with invalid pa");
f010104a:	c7 44 24 08 98 6a 10 	movl   $0xf0106a98,0x8(%esp)
f0101051:	f0 
f0101052:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101059:	00 
f010105a:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f0101061:	e8 da ef ff ff       	call   f0100040 <_panic>

              //remove continuous pages from page_free_list
              extern char end[];                        //this is an *virtual* address
              struct Page *ppg_start = pa2page((physaddr_t)IOPHYSMEM);                                                //at low *physical* address
              struct Page *ppg_end = pa2page((physaddr_t)((end - KERNBASE) + PGSIZE + sizeof(struct Page)*npages)+sizeof(struct Env)*NENV);    //at high *physical* address
f0101066:	8d 14 cd 04 40 28 00 	lea    0x284004(,%ecx,8),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010106d:	c1 ea 0c             	shr    $0xc,%edx
f0101070:	39 ca                	cmp    %ecx,%edx
f0101072:	72 1c                	jb     f0101090 <page_init+0xad>
		panic("pa2page called with invalid pa");
f0101074:	c7 44 24 08 98 6a 10 	movl   $0xf0106a98,0x8(%esp)
f010107b:	f0 
f010107c:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101083:	00 
f0101084:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f010108b:	e8 b0 ef ff ff       	call   f0100040 <_panic>

              //test output
             //cprintf(">>  ppg_start: %x\tppg_end: %x\n", (int)ppg_start, (int)ppg_end);
               ppg_start--;    ppg_end++;
f0101090:	8d 98 f8 04 00 00    	lea    0x4f8(%eax),%ebx
f0101096:	89 5c d0 08          	mov    %ebx,0x8(%eax,%edx,8)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010109a:	83 f9 07             	cmp    $0x7,%ecx
f010109d:	77 1c                	ja     f01010bb <page_init+0xd8>
		panic("pa2page called with invalid pa");
f010109f:	c7 44 24 08 98 6a 10 	movl   $0xf0106a98,0x8(%esp)
f01010a6:	f0 
f01010a7:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01010ae:	00 
f01010af:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f01010b6:	e8 85 ef ff ff       	call   f0100040 <_panic>
               ppg_end->pp_link = ppg_start;

               //remain the page of mp entry Code
               extern unsigned char mpentry_start[], mpentry_end[];
               ppg_start = pa2page((physaddr_t)MPENTRY_PADDR);      
               ppg_end = pa2page((physaddr_t)(MPENTRY_PADDR+mpentry_end - mpentry_start));  
f01010bb:	ba 86 c8 10 f0       	mov    $0xf010c886,%edx
f01010c0:	81 ea 0c 58 10 f0    	sub    $0xf010580c,%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01010c6:	c1 ea 0c             	shr    $0xc,%edx
f01010c9:	39 d1                	cmp    %edx,%ecx
f01010cb:	77 1c                	ja     f01010e9 <page_init+0x106>
		panic("pa2page called with invalid pa");
f01010cd:	c7 44 24 08 98 6a 10 	movl   $0xf0106a98,0x8(%esp)
f01010d4:	f0 
f01010d5:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01010dc:	00 
f01010dd:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f01010e4:	e8 57 ef ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f01010e9:	8d 1c d0             	lea    (%eax,%edx,8),%ebx
               ppg_start--;    ppg_end++;
f01010ec:	83 c0 30             	add    $0x30,%eax
               ppg_end->pp_link = ppg_start;
f01010ef:	89 43 08             	mov    %eax,0x8(%ebx)

               cprintf("MPENTRY_PADDR_page_start:  %d\n",PGNUM(page2pa(ppg_start)));
f01010f2:	c7 44 24 04 06 00 00 	movl   $0x6,0x4(%esp)
f01010f9:	00 
f01010fa:	c7 04 24 b8 6a 10 f0 	movl   $0xf0106ab8,(%esp)
f0101101:	e8 76 2d 00 00       	call   f0103e7c <cprintf>

               //remain the page of mp entry Code
               extern unsigned char mpentry_start[], mpentry_end[];
               ppg_start = pa2page((physaddr_t)MPENTRY_PADDR);      
               ppg_end = pa2page((physaddr_t)(MPENTRY_PADDR+mpentry_end - mpentry_start));  
               ppg_start--;    ppg_end++;
f0101106:	8d 43 08             	lea    0x8(%ebx),%eax
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101109:	2b 05 10 2f 22 f0    	sub    0xf0222f10,%eax
f010110f:	c1 f8 03             	sar    $0x3,%eax
               ppg_end->pp_link = ppg_start;

               cprintf("MPENTRY_PADDR_page_start:  %d\n",PGNUM(page2pa(ppg_start)));
               cprintf("MPENTRY_PADDR_page_end:  %d\n",PGNUM(page2pa(ppg_end)));
f0101112:	25 ff ff 0f 00       	and    $0xfffff,%eax
f0101117:	89 44 24 04          	mov    %eax,0x4(%esp)
f010111b:	c7 04 24 ce 71 10 f0 	movl   $0xf01071ce,(%esp)
f0101122:	e8 55 2d 00 00       	call   f0103e7c <cprintf>
               cprintf("\n");
f0101127:	c7 04 24 8c 71 10 f0 	movl   $0xf010718c,(%esp)
f010112e:	e8 49 2d 00 00       	call   f0103e7c <cprintf>
f0101133:	eb 11                	jmp    f0101146 <page_init+0x163>
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
	}

	//remove physical page 0 from page_free_list
             pages[1].pp_link = NULL;
f0101135:	a1 10 2f 22 f0       	mov    0xf0222f10,%eax
f010113a:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
f0101141:	e9 04 ff ff ff       	jmp    f010104a <page_init+0x67>
               ppg_end->pp_link = ppg_start;

               cprintf("MPENTRY_PADDR_page_start:  %d\n",PGNUM(page2pa(ppg_start)));
               cprintf("MPENTRY_PADDR_page_end:  %d\n",PGNUM(page2pa(ppg_end)));
               cprintf("\n");
}
f0101146:	83 c4 14             	add    $0x14,%esp
f0101149:	5b                   	pop    %ebx
f010114a:	5d                   	pop    %ebp
f010114b:	c3                   	ret    

f010114c <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
f010114c:	55                   	push   %ebp
f010114d:	89 e5                	mov    %esp,%ebp
f010114f:	53                   	push   %ebx
f0101150:	83 ec 14             	sub    $0x14,%esp
	//test output
              //cprintf(">>  page_alloc() was called!\n");

             if (page_free_list == NULL)
f0101153:	8b 1d 40 22 22 f0    	mov    0xf0222240,%ebx
f0101159:	85 db                	test   %ebx,%ebx
f010115b:	74 69                	je     f01011c6 <page_alloc+0x7a>
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
f010115d:	8b 03                	mov    (%ebx),%eax
f010115f:	a3 40 22 22 f0       	mov    %eax,0xf0222240
    
             if (alloc_flags & ALLOC_ZERO)
                    memset(page2kva(result), 0, PGSIZE);
        
             return result;
f0101164:	89 d8                	mov    %ebx,%eax
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
    
             if (alloc_flags & ALLOC_ZERO)
f0101166:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f010116a:	74 5f                	je     f01011cb <page_alloc+0x7f>
f010116c:	2b 05 10 2f 22 f0    	sub    0xf0222f10,%eax
f0101172:	c1 f8 03             	sar    $0x3,%eax
f0101175:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101178:	89 c2                	mov    %eax,%edx
f010117a:	c1 ea 0c             	shr    $0xc,%edx
f010117d:	3b 15 08 2f 22 f0    	cmp    0xf0222f08,%edx
f0101183:	72 20                	jb     f01011a5 <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101185:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101189:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f0101190:	f0 
f0101191:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101198:	00 
f0101199:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f01011a0:	e8 9b ee ff ff       	call   f0100040 <_panic>
                    memset(page2kva(result), 0, PGSIZE);
f01011a5:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01011ac:	00 
f01011ad:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01011b4:	00 
	return (void *)(pa + KERNBASE);
f01011b5:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01011ba:	89 04 24             	mov    %eax,(%esp)
f01011bd:	e8 17 44 00 00       	call   f01055d9 <memset>
        
             return result;
f01011c2:	89 d8                	mov    %ebx,%eax
f01011c4:	eb 05                	jmp    f01011cb <page_alloc+0x7f>
{
	//test output
              //cprintf(">>  page_alloc() was called!\n");

             if (page_free_list == NULL)
                             return NULL;
f01011c6:	b8 00 00 00 00       	mov    $0x0,%eax
    
             if (alloc_flags & ALLOC_ZERO)
                    memset(page2kva(result), 0, PGSIZE);
        
             return result;
}
f01011cb:	83 c4 14             	add    $0x14,%esp
f01011ce:	5b                   	pop    %ebx
f01011cf:	5d                   	pop    %ebp
f01011d0:	c3                   	ret    

f01011d1 <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct Page *pp)
{
f01011d1:	55                   	push   %ebp
f01011d2:	89 e5                	mov    %esp,%ebp
f01011d4:	8b 45 08             	mov    0x8(%ebp),%eax
	pp->pp_link = page_free_list;
f01011d7:	8b 15 40 22 22 f0    	mov    0xf0222240,%edx
f01011dd:	89 10                	mov    %edx,(%eax)
              page_free_list = pp;
f01011df:	a3 40 22 22 f0       	mov    %eax,0xf0222240
	// Fill this function in
}
f01011e4:	5d                   	pop    %ebp
f01011e5:	c3                   	ret    

f01011e6 <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct Page* pp)
{
f01011e6:	55                   	push   %ebp
f01011e7:	89 e5                	mov    %esp,%ebp
f01011e9:	83 ec 04             	sub    $0x4,%esp
f01011ec:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f01011ef:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f01011f3:	8d 51 ff             	lea    -0x1(%ecx),%edx
f01011f6:	66 89 50 04          	mov    %dx,0x4(%eax)
f01011fa:	66 85 d2             	test   %dx,%dx
f01011fd:	75 08                	jne    f0101207 <page_decref+0x21>
		page_free(pp);
f01011ff:	89 04 24             	mov    %eax,(%esp)
f0101202:	e8 ca ff ff ff       	call   f01011d1 <page_free>
}
f0101207:	c9                   	leave  
f0101208:	c3                   	ret    

f0101209 <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f0101209:	55                   	push   %ebp
f010120a:	89 e5                	mov    %esp,%ebp
f010120c:	56                   	push   %esi
f010120d:	53                   	push   %ebx
f010120e:	83 ec 10             	sub    $0x10,%esp
f0101211:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	// Fill this function in
	//test output
              //cprintf(">>  pgdir_walk() was called!\n");

             pte_t *result;
            if (pgdir[PDX(va)] == (pte_t)NULL) {            //yet to create
f0101214:	89 de                	mov    %ebx,%esi
f0101216:	c1 ee 16             	shr    $0x16,%esi
f0101219:	c1 e6 02             	shl    $0x2,%esi
f010121c:	03 75 08             	add    0x8(%ebp),%esi
f010121f:	8b 06                	mov    (%esi),%eax
f0101221:	85 c0                	test   %eax,%eax
f0101223:	75 76                	jne    f010129b <pgdir_walk+0x92>
                      if (create == 0)
f0101225:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f0101229:	0f 84 d1 00 00 00    	je     f0101300 <pgdir_walk+0xf7>
                                        return NULL;
                     else {
                                        struct Page *tmp = page_alloc(ALLOC_ZERO);
f010122f:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101236:	e8 11 ff ff ff       	call   f010114c <page_alloc>
                                        if (tmp == NULL)
f010123b:	85 c0                	test   %eax,%eax
f010123d:	0f 84 c4 00 00 00    	je     f0101307 <pgdir_walk+0xfe>
                                                  return NULL;                        //failed to alloc
                                        else {
                                                  tmp->pp_ref++;
f0101243:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101248:	89 c2                	mov    %eax,%edx
f010124a:	2b 15 10 2f 22 f0    	sub    0xf0222f10,%edx
f0101250:	c1 fa 03             	sar    $0x3,%edx
f0101253:	c1 e2 0c             	shl    $0xc,%edx
                                                  pgdir[PDX(va)] = page2pa(tmp) | PTE_P | PTE_W |PTE_U;    //save the physical address of newly allocated page in page dir
f0101256:	83 ca 07             	or     $0x7,%edx
f0101259:	89 16                	mov    %edx,(%esi)
f010125b:	2b 05 10 2f 22 f0    	sub    0xf0222f10,%eax
f0101261:	c1 f8 03             	sar    $0x3,%eax
f0101264:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101267:	89 c2                	mov    %eax,%edx
f0101269:	c1 ea 0c             	shr    $0xc,%edx
f010126c:	3b 15 08 2f 22 f0    	cmp    0xf0222f08,%edx
f0101272:	72 20                	jb     f0101294 <pgdir_walk+0x8b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101274:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101278:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f010127f:	f0 
f0101280:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101287:	00 
f0101288:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f010128f:	e8 ac ed ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0101294:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101299:	eb 58                	jmp    f01012f3 <pgdir_walk+0xea>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010129b:	c1 e8 0c             	shr    $0xc,%eax
f010129e:	8b 15 08 2f 22 f0    	mov    0xf0222f08,%edx
f01012a4:	39 d0                	cmp    %edx,%eax
f01012a6:	72 1c                	jb     f01012c4 <pgdir_walk+0xbb>
		panic("pa2page called with invalid pa");
f01012a8:	c7 44 24 08 98 6a 10 	movl   $0xf0106a98,0x8(%esp)
f01012af:	f0 
f01012b0:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01012b7:	00 
f01012b8:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f01012bf:	e8 7c ed ff ff       	call   f0100040 <_panic>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01012c4:	89 c1                	mov    %eax,%ecx
f01012c6:	c1 e1 0c             	shl    $0xc,%ecx
f01012c9:	39 d0                	cmp    %edx,%eax
f01012cb:	72 20                	jb     f01012ed <pgdir_walk+0xe4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01012cd:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01012d1:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f01012d8:	f0 
f01012d9:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01012e0:	00 
f01012e1:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f01012e8:	e8 53 ed ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01012ed:	8d 81 00 00 00 f0    	lea    -0x10000000(%ecx),%eax
                                  }
                 }
               else                        
               result = page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
        
               return &result[PTX(va)];
f01012f3:	c1 eb 0a             	shr    $0xa,%ebx
f01012f6:	81 e3 fc 0f 00 00    	and    $0xffc,%ebx
f01012fc:	01 d8                	add    %ebx,%eax
f01012fe:	eb 0c                	jmp    f010130c <pgdir_walk+0x103>
              //cprintf(">>  pgdir_walk() was called!\n");

             pte_t *result;
            if (pgdir[PDX(va)] == (pte_t)NULL) {            //yet to create
                      if (create == 0)
                                        return NULL;
f0101300:	b8 00 00 00 00       	mov    $0x0,%eax
f0101305:	eb 05                	jmp    f010130c <pgdir_walk+0x103>
                     else {
                                        struct Page *tmp = page_alloc(ALLOC_ZERO);
                                        if (tmp == NULL)
                                                  return NULL;                        //failed to alloc
f0101307:	b8 00 00 00 00       	mov    $0x0,%eax
                 }
               else                        
               result = page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
        
               return &result[PTX(va)];
}
f010130c:	83 c4 10             	add    $0x10,%esp
f010130f:	5b                   	pop    %ebx
f0101310:	5e                   	pop    %esi
f0101311:	5d                   	pop    %ebp
f0101312:	c3                   	ret    

f0101313 <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f0101313:	55                   	push   %ebp
f0101314:	89 e5                	mov    %esp,%ebp
f0101316:	53                   	push   %ebx
f0101317:	83 ec 14             	sub    $0x14,%esp
f010131a:	8b 5d 10             	mov    0x10(%ebp),%ebx
	// Fill this function in
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
f010131d:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101324:	00 
f0101325:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101328:	89 44 24 04          	mov    %eax,0x4(%esp)
f010132c:	8b 45 08             	mov    0x8(%ebp),%eax
f010132f:	89 04 24             	mov    %eax,(%esp)
f0101332:	e8 d2 fe ff ff       	call   f0101209 <pgdir_walk>
              if (pte == NULL)
f0101337:	85 c0                	test   %eax,%eax
f0101339:	74 3a                	je     f0101375 <page_lookup+0x62>
                       return NULL;

             if (pte_store != 0)
f010133b:	85 db                	test   %ebx,%ebx
f010133d:	74 02                	je     f0101341 <page_lookup+0x2e>
                     *pte_store = pte;
f010133f:	89 03                	mov    %eax,(%ebx)

             return pa2page(PTE_ADDR(pte[0]));
f0101341:	8b 00                	mov    (%eax),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101343:	c1 e8 0c             	shr    $0xc,%eax
f0101346:	3b 05 08 2f 22 f0    	cmp    0xf0222f08,%eax
f010134c:	72 1c                	jb     f010136a <page_lookup+0x57>
		panic("pa2page called with invalid pa");
f010134e:	c7 44 24 08 98 6a 10 	movl   $0xf0106a98,0x8(%esp)
f0101355:	f0 
f0101356:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010135d:	00 
f010135e:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f0101365:	e8 d6 ec ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f010136a:	8b 15 10 2f 22 f0    	mov    0xf0222f10,%edx
f0101370:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0101373:	eb 05                	jmp    f010137a <page_lookup+0x67>
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
              if (pte == NULL)
                       return NULL;
f0101375:	b8 00 00 00 00       	mov    $0x0,%eax

             if (pte_store != 0)
                     *pte_store = pte;

             return pa2page(PTE_ADDR(pte[0]));
}
f010137a:	83 c4 14             	add    $0x14,%esp
f010137d:	5b                   	pop    %ebx
f010137e:	5d                   	pop    %ebp
f010137f:	c3                   	ret    

f0101380 <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f0101380:	55                   	push   %ebp
f0101381:	89 e5                	mov    %esp,%ebp
f0101383:	83 ec 08             	sub    $0x8,%esp
	// Flush the entry only if we're modifying the current address space.
	if (!curenv || curenv->env_pgdir == pgdir)
f0101386:	e8 e8 48 00 00       	call   f0105c73 <cpunum>
f010138b:	6b c0 74             	imul   $0x74,%eax,%eax
f010138e:	83 b8 28 30 22 f0 00 	cmpl   $0x0,-0xfddcfd8(%eax)
f0101395:	74 16                	je     f01013ad <tlb_invalidate+0x2d>
f0101397:	e8 d7 48 00 00       	call   f0105c73 <cpunum>
f010139c:	6b c0 74             	imul   $0x74,%eax,%eax
f010139f:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f01013a5:	8b 55 08             	mov    0x8(%ebp),%edx
f01013a8:	39 50 60             	cmp    %edx,0x60(%eax)
f01013ab:	75 06                	jne    f01013b3 <tlb_invalidate+0x33>
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f01013ad:	8b 45 0c             	mov    0xc(%ebp),%eax
f01013b0:	0f 01 38             	invlpg (%eax)
		invlpg(va);
}
f01013b3:	c9                   	leave  
f01013b4:	c3                   	ret    

f01013b5 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f01013b5:	55                   	push   %ebp
f01013b6:	89 e5                	mov    %esp,%ebp
f01013b8:	56                   	push   %esi
f01013b9:	53                   	push   %ebx
f01013ba:	83 ec 20             	sub    $0x20,%esp
f01013bd:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01013c0:	8b 75 0c             	mov    0xc(%ebp),%esi
	// Fill this function in
	//test output
               //cprintf(">>  page_remove() was called!\n");
    
              pte_t *pte;
              struct Page *page = page_lookup(pgdir, va, &pte);
f01013c3:	8d 45 f4             	lea    -0xc(%ebp),%eax
f01013c6:	89 44 24 08          	mov    %eax,0x8(%esp)
f01013ca:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013ce:	89 1c 24             	mov    %ebx,(%esp)
f01013d1:	e8 3d ff ff ff       	call   f0101313 <page_lookup>
    
              if (page != NULL)
f01013d6:	85 c0                	test   %eax,%eax
f01013d8:	74 08                	je     f01013e2 <page_remove+0x2d>
                         page_decref(page);
f01013da:	89 04 24             	mov    %eax,(%esp)
f01013dd:	e8 04 fe ff ff       	call   f01011e6 <page_decref>
        
              pte[0] = 0;
f01013e2:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01013e5:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
              tlb_invalidate(pgdir, va);
f01013eb:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013ef:	89 1c 24             	mov    %ebx,(%esp)
f01013f2:	e8 89 ff ff ff       	call   f0101380 <tlb_invalidate>
}
f01013f7:	83 c4 20             	add    $0x20,%esp
f01013fa:	5b                   	pop    %ebx
f01013fb:	5e                   	pop    %esi
f01013fc:	5d                   	pop    %ebp
f01013fd:	c3                   	ret    

f01013fe <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
{
f01013fe:	55                   	push   %ebp
f01013ff:	89 e5                	mov    %esp,%ebp
f0101401:	57                   	push   %edi
f0101402:	56                   	push   %esi
f0101403:	53                   	push   %ebx
f0101404:	83 ec 1c             	sub    $0x1c,%esp
f0101407:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010140a:	8b 75 10             	mov    0x10(%ebp),%esi
	// Fill this function in
	//test output
                                //cprintf(">>  page_insert() was called!\n");
    
               struct Page *page = page_lookup(pgdir, va, NULL);
f010140d:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101414:	00 
f0101415:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101419:	8b 45 08             	mov    0x8(%ebp),%eax
f010141c:	89 04 24             	mov    %eax,(%esp)
f010141f:	e8 ef fe ff ff       	call   f0101313 <page_lookup>
f0101424:	89 c7                	mov    %eax,%edi
               pte_t *pte;
    
              if (page == pp) {                       //re-insert into the same place
f0101426:	39 d8                	cmp    %ebx,%eax
f0101428:	75 36                	jne    f0101460 <page_insert+0x62>
                            pte = pgdir_walk(pgdir, va, 0);
f010142a:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101431:	00 
f0101432:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101436:	8b 45 08             	mov    0x8(%ebp),%eax
f0101439:	89 04 24             	mov    %eax,(%esp)
f010143c:	e8 c8 fd ff ff       	call   f0101209 <pgdir_walk>
                            pte[0] = page2pa(pp) | perm | PTE_P;
f0101441:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0101444:	83 c9 01             	or     $0x1,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101447:	2b 3d 10 2f 22 f0    	sub    0xf0222f10,%edi
f010144d:	c1 ff 03             	sar    $0x3,%edi
f0101450:	c1 e7 0c             	shl    $0xc,%edi
f0101453:	89 fa                	mov    %edi,%edx
f0101455:	09 ca                	or     %ecx,%edx
f0101457:	89 10                	mov    %edx,(%eax)
                            return 0;
f0101459:	b8 00 00 00 00       	mov    $0x0,%eax
f010145e:	eb 57                	jmp    f01014b7 <page_insert+0xb9>
                          }
    
               if (page != NULL)                       //remove original page if existed
f0101460:	85 c0                	test   %eax,%eax
f0101462:	74 0f                	je     f0101473 <page_insert+0x75>
                        page_remove(pgdir, va);
f0101464:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101468:	8b 45 08             	mov    0x8(%ebp),%eax
f010146b:	89 04 24             	mov    %eax,(%esp)
f010146e:	e8 42 ff ff ff       	call   f01013b5 <page_remove>
        
              pte = pgdir_walk(pgdir, va, 1);
f0101473:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010147a:	00 
f010147b:	89 74 24 04          	mov    %esi,0x4(%esp)
f010147f:	8b 45 08             	mov    0x8(%ebp),%eax
f0101482:	89 04 24             	mov    %eax,(%esp)
f0101485:	e8 7f fd ff ff       	call   f0101209 <pgdir_walk>
              if (pte == NULL)
f010148a:	85 c0                	test   %eax,%eax
f010148c:	74 24                	je     f01014b2 <page_insert+0xb4>
                       return -E_NO_MEM;

              pte[0] = page2pa(pp) | perm | PTE_P;
f010148e:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0101491:	83 c9 01             	or     $0x1,%ecx
f0101494:	89 da                	mov    %ebx,%edx
f0101496:	2b 15 10 2f 22 f0    	sub    0xf0222f10,%edx
f010149c:	c1 fa 03             	sar    $0x3,%edx
f010149f:	c1 e2 0c             	shl    $0xc,%edx
f01014a2:	09 ca                	or     %ecx,%edx
f01014a4:	89 10                	mov    %edx,(%eax)
               pp->pp_ref++;
f01014a6:	66 83 43 04 01       	addw   $0x1,0x4(%ebx)

	return 0; 
f01014ab:	b8 00 00 00 00       	mov    $0x0,%eax
f01014b0:	eb 05                	jmp    f01014b7 <page_insert+0xb9>
               if (page != NULL)                       //remove original page if existed
                        page_remove(pgdir, va);
        
              pte = pgdir_walk(pgdir, va, 1);
              if (pte == NULL)
                       return -E_NO_MEM;
f01014b2:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax

              pte[0] = page2pa(pp) | perm | PTE_P;
               pp->pp_ref++;

	return 0; 
}
f01014b7:	83 c4 1c             	add    $0x1c,%esp
f01014ba:	5b                   	pop    %ebx
f01014bb:	5e                   	pop    %esi
f01014bc:	5f                   	pop    %edi
f01014bd:	5d                   	pop    %ebp
f01014be:	c3                   	ret    

f01014bf <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f01014bf:	55                   	push   %ebp
f01014c0:	89 e5                	mov    %esp,%ebp
f01014c2:	57                   	push   %edi
f01014c3:	56                   	push   %esi
f01014c4:	53                   	push   %ebx
f01014c5:	83 ec 3c             	sub    $0x3c,%esp
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01014c8:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f01014cf:	e8 3c 28 00 00       	call   f0103d10 <mc146818_read>
f01014d4:	89 c3                	mov    %eax,%ebx
f01014d6:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f01014dd:	e8 2e 28 00 00       	call   f0103d10 <mc146818_read>
f01014e2:	c1 e0 08             	shl    $0x8,%eax
f01014e5:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f01014e7:	89 d8                	mov    %ebx,%eax
f01014e9:	c1 e0 0a             	shl    $0xa,%eax
f01014ec:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f01014f2:	85 c0                	test   %eax,%eax
f01014f4:	0f 48 c2             	cmovs  %edx,%eax
f01014f7:	c1 f8 0c             	sar    $0xc,%eax
f01014fa:	a3 44 22 22 f0       	mov    %eax,0xf0222244
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01014ff:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f0101506:	e8 05 28 00 00       	call   f0103d10 <mc146818_read>
f010150b:	89 c3                	mov    %eax,%ebx
f010150d:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f0101514:	e8 f7 27 00 00       	call   f0103d10 <mc146818_read>
f0101519:	c1 e0 08             	shl    $0x8,%eax
f010151c:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f010151e:	89 d8                	mov    %ebx,%eax
f0101520:	c1 e0 0a             	shl    $0xa,%eax
f0101523:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0101529:	85 c0                	test   %eax,%eax
f010152b:	0f 48 c2             	cmovs  %edx,%eax
f010152e:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f0101531:	85 c0                	test   %eax,%eax
f0101533:	74 0e                	je     f0101543 <mem_init+0x84>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f0101535:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f010153b:	89 15 08 2f 22 f0    	mov    %edx,0xf0222f08
f0101541:	eb 0c                	jmp    f010154f <mem_init+0x90>
	else
		npages = npages_basemem;
f0101543:	8b 15 44 22 22 f0    	mov    0xf0222244,%edx
f0101549:	89 15 08 2f 22 f0    	mov    %edx,0xf0222f08

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f010154f:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101552:	c1 e8 0a             	shr    $0xa,%eax
f0101555:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f0101559:	a1 44 22 22 f0       	mov    0xf0222244,%eax
f010155e:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101561:	c1 e8 0a             	shr    $0xa,%eax
f0101564:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f0101568:	a1 08 2f 22 f0       	mov    0xf0222f08,%eax
f010156d:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101570:	c1 e8 0a             	shr    $0xa,%eax
f0101573:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101577:	c7 04 24 d8 6a 10 f0 	movl   $0xf0106ad8,(%esp)
f010157e:	e8 f9 28 00 00       	call   f0103e7c <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);  // first_level pagedir
f0101583:	b8 00 10 00 00       	mov    $0x1000,%eax
f0101588:	e8 93 f5 ff ff       	call   f0100b20 <boot_alloc>
f010158d:	a3 0c 2f 22 f0       	mov    %eax,0xf0222f0c
	memset(kern_pgdir, 0, PGSIZE);
f0101592:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101599:	00 
f010159a:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01015a1:	00 
f01015a2:	89 04 24             	mov    %eax,(%esp)
f01015a5:	e8 2f 40 00 00       	call   f01055d9 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f01015aa:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01015af:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01015b4:	77 20                	ja     f01015d6 <mem_init+0x117>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01015b6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01015ba:	c7 44 24 08 c8 63 10 	movl   $0xf01063c8,0x8(%esp)
f01015c1:	f0 
f01015c2:	c7 44 24 04 96 00 00 	movl   $0x96,0x4(%esp)
f01015c9:	00 
f01015ca:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01015d1:	e8 6a ea ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01015d6:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f01015dc:	83 ca 05             	or     $0x5,%edx
f01015df:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct Page in this
	// array.  'npages' is the number of physical pages in memory.
	// Your code goes here:

	pages = (struct Page *)boot_alloc(npages * sizeof(struct Page)); // allocate npages to record all physical pages in memort using condition
f01015e5:	a1 08 2f 22 f0       	mov    0xf0222f08,%eax
f01015ea:	c1 e0 03             	shl    $0x3,%eax
f01015ed:	e8 2e f5 ff ff       	call   f0100b20 <boot_alloc>
f01015f2:	a3 10 2f 22 f0       	mov    %eax,0xf0222f10


	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.
	envs =  (struct Env *)boot_alloc(NENV * sizeof(struct Env));
f01015f7:	b8 00 f0 01 00       	mov    $0x1f000,%eax
f01015fc:	e8 1f f5 ff ff       	call   f0100b20 <boot_alloc>
f0101601:	a3 48 22 22 f0       	mov    %eax,0xf0222248
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f0101606:	e8 d8 f9 ff ff       	call   f0100fe3 <page_init>

	check_page_free_list(1);
f010160b:	b8 01 00 00 00       	mov    $0x1,%eax
f0101610:	e8 de f5 ff ff       	call   f0100bf3 <check_page_free_list>
	int nfree;
	struct Page *fl;
	char *c;
	int i;

	if (!pages)
f0101615:	83 3d 10 2f 22 f0 00 	cmpl   $0x0,0xf0222f10
f010161c:	75 1c                	jne    f010163a <mem_init+0x17b>
		panic("'pages' is a null pointer!");
f010161e:	c7 44 24 08 eb 71 10 	movl   $0xf01071eb,0x8(%esp)
f0101625:	f0 
f0101626:	c7 44 24 04 f0 02 00 	movl   $0x2f0,0x4(%esp)
f010162d:	00 
f010162e:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101635:	e8 06 ea ff ff       	call   f0100040 <_panic>

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010163a:	a1 40 22 22 f0       	mov    0xf0222240,%eax
f010163f:	85 c0                	test   %eax,%eax
f0101641:	74 10                	je     f0101653 <mem_init+0x194>
f0101643:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;
f0101648:	83 c3 01             	add    $0x1,%ebx

	if (!pages)
		panic("'pages' is a null pointer!");

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010164b:	8b 00                	mov    (%eax),%eax
f010164d:	85 c0                	test   %eax,%eax
f010164f:	75 f7                	jne    f0101648 <mem_init+0x189>
f0101651:	eb 05                	jmp    f0101658 <mem_init+0x199>
f0101653:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101658:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010165f:	e8 e8 fa ff ff       	call   f010114c <page_alloc>
f0101664:	89 c7                	mov    %eax,%edi
f0101666:	85 c0                	test   %eax,%eax
f0101668:	75 24                	jne    f010168e <mem_init+0x1cf>
f010166a:	c7 44 24 0c 06 72 10 	movl   $0xf0107206,0xc(%esp)
f0101671:	f0 
f0101672:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101679:	f0 
f010167a:	c7 44 24 04 f8 02 00 	movl   $0x2f8,0x4(%esp)
f0101681:	00 
f0101682:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101689:	e8 b2 e9 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f010168e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101695:	e8 b2 fa ff ff       	call   f010114c <page_alloc>
f010169a:	89 c6                	mov    %eax,%esi
f010169c:	85 c0                	test   %eax,%eax
f010169e:	75 24                	jne    f01016c4 <mem_init+0x205>
f01016a0:	c7 44 24 0c 1c 72 10 	movl   $0xf010721c,0xc(%esp)
f01016a7:	f0 
f01016a8:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01016af:	f0 
f01016b0:	c7 44 24 04 f9 02 00 	movl   $0x2f9,0x4(%esp)
f01016b7:	00 
f01016b8:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01016bf:	e8 7c e9 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01016c4:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01016cb:	e8 7c fa ff ff       	call   f010114c <page_alloc>
f01016d0:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01016d3:	85 c0                	test   %eax,%eax
f01016d5:	75 24                	jne    f01016fb <mem_init+0x23c>
f01016d7:	c7 44 24 0c 32 72 10 	movl   $0xf0107232,0xc(%esp)
f01016de:	f0 
f01016df:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01016e6:	f0 
f01016e7:	c7 44 24 04 fa 02 00 	movl   $0x2fa,0x4(%esp)
f01016ee:	00 
f01016ef:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01016f6:	e8 45 e9 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f01016fb:	39 f7                	cmp    %esi,%edi
f01016fd:	75 24                	jne    f0101723 <mem_init+0x264>
f01016ff:	c7 44 24 0c 48 72 10 	movl   $0xf0107248,0xc(%esp)
f0101706:	f0 
f0101707:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010170e:	f0 
f010170f:	c7 44 24 04 fd 02 00 	movl   $0x2fd,0x4(%esp)
f0101716:	00 
f0101717:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010171e:	e8 1d e9 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101723:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101726:	39 c6                	cmp    %eax,%esi
f0101728:	74 04                	je     f010172e <mem_init+0x26f>
f010172a:	39 c7                	cmp    %eax,%edi
f010172c:	75 24                	jne    f0101752 <mem_init+0x293>
f010172e:	c7 44 24 0c 14 6b 10 	movl   $0xf0106b14,0xc(%esp)
f0101735:	f0 
f0101736:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010173d:	f0 
f010173e:	c7 44 24 04 fe 02 00 	movl   $0x2fe,0x4(%esp)
f0101745:	00 
f0101746:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010174d:	e8 ee e8 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101752:	8b 15 10 2f 22 f0    	mov    0xf0222f10,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f0101758:	a1 08 2f 22 f0       	mov    0xf0222f08,%eax
f010175d:	c1 e0 0c             	shl    $0xc,%eax
f0101760:	89 f9                	mov    %edi,%ecx
f0101762:	29 d1                	sub    %edx,%ecx
f0101764:	c1 f9 03             	sar    $0x3,%ecx
f0101767:	c1 e1 0c             	shl    $0xc,%ecx
f010176a:	39 c1                	cmp    %eax,%ecx
f010176c:	72 24                	jb     f0101792 <mem_init+0x2d3>
f010176e:	c7 44 24 0c 5a 72 10 	movl   $0xf010725a,0xc(%esp)
f0101775:	f0 
f0101776:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010177d:	f0 
f010177e:	c7 44 24 04 ff 02 00 	movl   $0x2ff,0x4(%esp)
f0101785:	00 
f0101786:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010178d:	e8 ae e8 ff ff       	call   f0100040 <_panic>
f0101792:	89 f1                	mov    %esi,%ecx
f0101794:	29 d1                	sub    %edx,%ecx
f0101796:	c1 f9 03             	sar    $0x3,%ecx
f0101799:	c1 e1 0c             	shl    $0xc,%ecx
	assert(page2pa(pp1) < npages*PGSIZE);
f010179c:	39 c8                	cmp    %ecx,%eax
f010179e:	77 24                	ja     f01017c4 <mem_init+0x305>
f01017a0:	c7 44 24 0c 77 72 10 	movl   $0xf0107277,0xc(%esp)
f01017a7:	f0 
f01017a8:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01017af:	f0 
f01017b0:	c7 44 24 04 00 03 00 	movl   $0x300,0x4(%esp)
f01017b7:	00 
f01017b8:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01017bf:	e8 7c e8 ff ff       	call   f0100040 <_panic>
f01017c4:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01017c7:	29 d1                	sub    %edx,%ecx
f01017c9:	89 ca                	mov    %ecx,%edx
f01017cb:	c1 fa 03             	sar    $0x3,%edx
f01017ce:	c1 e2 0c             	shl    $0xc,%edx
	assert(page2pa(pp2) < npages*PGSIZE);
f01017d1:	39 d0                	cmp    %edx,%eax
f01017d3:	77 24                	ja     f01017f9 <mem_init+0x33a>
f01017d5:	c7 44 24 0c 94 72 10 	movl   $0xf0107294,0xc(%esp)
f01017dc:	f0 
f01017dd:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01017e4:	f0 
f01017e5:	c7 44 24 04 01 03 00 	movl   $0x301,0x4(%esp)
f01017ec:	00 
f01017ed:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01017f4:	e8 47 e8 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f01017f9:	a1 40 22 22 f0       	mov    0xf0222240,%eax
f01017fe:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101801:	c7 05 40 22 22 f0 00 	movl   $0x0,0xf0222240
f0101808:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f010180b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101812:	e8 35 f9 ff ff       	call   f010114c <page_alloc>
f0101817:	85 c0                	test   %eax,%eax
f0101819:	74 24                	je     f010183f <mem_init+0x380>
f010181b:	c7 44 24 0c b1 72 10 	movl   $0xf01072b1,0xc(%esp)
f0101822:	f0 
f0101823:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010182a:	f0 
f010182b:	c7 44 24 04 08 03 00 	movl   $0x308,0x4(%esp)
f0101832:	00 
f0101833:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010183a:	e8 01 e8 ff ff       	call   f0100040 <_panic>

	// free and re-allocate?
	page_free(pp0);
f010183f:	89 3c 24             	mov    %edi,(%esp)
f0101842:	e8 8a f9 ff ff       	call   f01011d1 <page_free>
	page_free(pp1);
f0101847:	89 34 24             	mov    %esi,(%esp)
f010184a:	e8 82 f9 ff ff       	call   f01011d1 <page_free>
	page_free(pp2);
f010184f:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101852:	89 04 24             	mov    %eax,(%esp)
f0101855:	e8 77 f9 ff ff       	call   f01011d1 <page_free>
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f010185a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101861:	e8 e6 f8 ff ff       	call   f010114c <page_alloc>
f0101866:	89 c6                	mov    %eax,%esi
f0101868:	85 c0                	test   %eax,%eax
f010186a:	75 24                	jne    f0101890 <mem_init+0x3d1>
f010186c:	c7 44 24 0c 06 72 10 	movl   $0xf0107206,0xc(%esp)
f0101873:	f0 
f0101874:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010187b:	f0 
f010187c:	c7 44 24 04 0f 03 00 	movl   $0x30f,0x4(%esp)
f0101883:	00 
f0101884:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010188b:	e8 b0 e7 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101890:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101897:	e8 b0 f8 ff ff       	call   f010114c <page_alloc>
f010189c:	89 c7                	mov    %eax,%edi
f010189e:	85 c0                	test   %eax,%eax
f01018a0:	75 24                	jne    f01018c6 <mem_init+0x407>
f01018a2:	c7 44 24 0c 1c 72 10 	movl   $0xf010721c,0xc(%esp)
f01018a9:	f0 
f01018aa:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01018b1:	f0 
f01018b2:	c7 44 24 04 10 03 00 	movl   $0x310,0x4(%esp)
f01018b9:	00 
f01018ba:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01018c1:	e8 7a e7 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01018c6:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018cd:	e8 7a f8 ff ff       	call   f010114c <page_alloc>
f01018d2:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01018d5:	85 c0                	test   %eax,%eax
f01018d7:	75 24                	jne    f01018fd <mem_init+0x43e>
f01018d9:	c7 44 24 0c 32 72 10 	movl   $0xf0107232,0xc(%esp)
f01018e0:	f0 
f01018e1:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01018e8:	f0 
f01018e9:	c7 44 24 04 11 03 00 	movl   $0x311,0x4(%esp)
f01018f0:	00 
f01018f1:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01018f8:	e8 43 e7 ff ff       	call   f0100040 <_panic>
	assert(pp0);
	assert(pp1 && pp1 != pp0);
f01018fd:	39 fe                	cmp    %edi,%esi
f01018ff:	75 24                	jne    f0101925 <mem_init+0x466>
f0101901:	c7 44 24 0c 48 72 10 	movl   $0xf0107248,0xc(%esp)
f0101908:	f0 
f0101909:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101910:	f0 
f0101911:	c7 44 24 04 13 03 00 	movl   $0x313,0x4(%esp)
f0101918:	00 
f0101919:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101920:	e8 1b e7 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101925:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101928:	39 c7                	cmp    %eax,%edi
f010192a:	74 04                	je     f0101930 <mem_init+0x471>
f010192c:	39 c6                	cmp    %eax,%esi
f010192e:	75 24                	jne    f0101954 <mem_init+0x495>
f0101930:	c7 44 24 0c 14 6b 10 	movl   $0xf0106b14,0xc(%esp)
f0101937:	f0 
f0101938:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010193f:	f0 
f0101940:	c7 44 24 04 14 03 00 	movl   $0x314,0x4(%esp)
f0101947:	00 
f0101948:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010194f:	e8 ec e6 ff ff       	call   f0100040 <_panic>
	assert(!page_alloc(0));
f0101954:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010195b:	e8 ec f7 ff ff       	call   f010114c <page_alloc>
f0101960:	85 c0                	test   %eax,%eax
f0101962:	74 24                	je     f0101988 <mem_init+0x4c9>
f0101964:	c7 44 24 0c b1 72 10 	movl   $0xf01072b1,0xc(%esp)
f010196b:	f0 
f010196c:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101973:	f0 
f0101974:	c7 44 24 04 15 03 00 	movl   $0x315,0x4(%esp)
f010197b:	00 
f010197c:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101983:	e8 b8 e6 ff ff       	call   f0100040 <_panic>
f0101988:	89 f0                	mov    %esi,%eax
f010198a:	2b 05 10 2f 22 f0    	sub    0xf0222f10,%eax
f0101990:	c1 f8 03             	sar    $0x3,%eax
f0101993:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101996:	89 c2                	mov    %eax,%edx
f0101998:	c1 ea 0c             	shr    $0xc,%edx
f010199b:	3b 15 08 2f 22 f0    	cmp    0xf0222f08,%edx
f01019a1:	72 20                	jb     f01019c3 <mem_init+0x504>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01019a3:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01019a7:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f01019ae:	f0 
f01019af:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01019b6:	00 
f01019b7:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f01019be:	e8 7d e6 ff ff       	call   f0100040 <_panic>

	// test flags
	memset(page2kva(pp0), 1, PGSIZE);
f01019c3:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01019ca:	00 
f01019cb:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f01019d2:	00 
	return (void *)(pa + KERNBASE);
f01019d3:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01019d8:	89 04 24             	mov    %eax,(%esp)
f01019db:	e8 f9 3b 00 00       	call   f01055d9 <memset>
	page_free(pp0);
f01019e0:	89 34 24             	mov    %esi,(%esp)
f01019e3:	e8 e9 f7 ff ff       	call   f01011d1 <page_free>
	assert((pp = page_alloc(ALLOC_ZERO)));
f01019e8:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01019ef:	e8 58 f7 ff ff       	call   f010114c <page_alloc>
f01019f4:	85 c0                	test   %eax,%eax
f01019f6:	75 24                	jne    f0101a1c <mem_init+0x55d>
f01019f8:	c7 44 24 0c c0 72 10 	movl   $0xf01072c0,0xc(%esp)
f01019ff:	f0 
f0101a00:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101a07:	f0 
f0101a08:	c7 44 24 04 1a 03 00 	movl   $0x31a,0x4(%esp)
f0101a0f:	00 
f0101a10:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101a17:	e8 24 e6 ff ff       	call   f0100040 <_panic>
	assert(pp && pp0 == pp);
f0101a1c:	39 c6                	cmp    %eax,%esi
f0101a1e:	74 24                	je     f0101a44 <mem_init+0x585>
f0101a20:	c7 44 24 0c de 72 10 	movl   $0xf01072de,0xc(%esp)
f0101a27:	f0 
f0101a28:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101a2f:	f0 
f0101a30:	c7 44 24 04 1b 03 00 	movl   $0x31b,0x4(%esp)
f0101a37:	00 
f0101a38:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101a3f:	e8 fc e5 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101a44:	89 f2                	mov    %esi,%edx
f0101a46:	2b 15 10 2f 22 f0    	sub    0xf0222f10,%edx
f0101a4c:	c1 fa 03             	sar    $0x3,%edx
f0101a4f:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101a52:	89 d0                	mov    %edx,%eax
f0101a54:	c1 e8 0c             	shr    $0xc,%eax
f0101a57:	3b 05 08 2f 22 f0    	cmp    0xf0222f08,%eax
f0101a5d:	72 20                	jb     f0101a7f <mem_init+0x5c0>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101a5f:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101a63:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f0101a6a:	f0 
f0101a6b:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101a72:	00 
f0101a73:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f0101a7a:	e8 c1 e5 ff ff       	call   f0100040 <_panic>
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
		assert(c[i] == 0);
f0101a7f:	80 ba 00 00 00 f0 00 	cmpb   $0x0,-0x10000000(%edx)
f0101a86:	75 11                	jne    f0101a99 <mem_init+0x5da>
f0101a88:	8d 82 01 00 00 f0    	lea    -0xfffffff(%edx),%eax
f0101a8e:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0101a94:	80 38 00             	cmpb   $0x0,(%eax)
f0101a97:	74 24                	je     f0101abd <mem_init+0x5fe>
f0101a99:	c7 44 24 0c ee 72 10 	movl   $0xf01072ee,0xc(%esp)
f0101aa0:	f0 
f0101aa1:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101aa8:	f0 
f0101aa9:	c7 44 24 04 1e 03 00 	movl   $0x31e,0x4(%esp)
f0101ab0:	00 
f0101ab1:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101ab8:	e8 83 e5 ff ff       	call   f0100040 <_panic>
f0101abd:	83 c0 01             	add    $0x1,%eax
	memset(page2kva(pp0), 1, PGSIZE);
	page_free(pp0);
	assert((pp = page_alloc(ALLOC_ZERO)));
	assert(pp && pp0 == pp);
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
f0101ac0:	39 d0                	cmp    %edx,%eax
f0101ac2:	75 d0                	jne    f0101a94 <mem_init+0x5d5>
		assert(c[i] == 0);

	// give free list back
	page_free_list = fl;
f0101ac4:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101ac7:	a3 40 22 22 f0       	mov    %eax,0xf0222240

	// free the pages we took
	page_free(pp0);
f0101acc:	89 34 24             	mov    %esi,(%esp)
f0101acf:	e8 fd f6 ff ff       	call   f01011d1 <page_free>
	page_free(pp1);
f0101ad4:	89 3c 24             	mov    %edi,(%esp)
f0101ad7:	e8 f5 f6 ff ff       	call   f01011d1 <page_free>
	page_free(pp2);
f0101adc:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101adf:	89 04 24             	mov    %eax,(%esp)
f0101ae2:	e8 ea f6 ff ff       	call   f01011d1 <page_free>

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101ae7:	a1 40 22 22 f0       	mov    0xf0222240,%eax
f0101aec:	85 c0                	test   %eax,%eax
f0101aee:	74 09                	je     f0101af9 <mem_init+0x63a>
		--nfree;
f0101af0:	83 eb 01             	sub    $0x1,%ebx
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101af3:	8b 00                	mov    (%eax),%eax
f0101af5:	85 c0                	test   %eax,%eax
f0101af7:	75 f7                	jne    f0101af0 <mem_init+0x631>
		--nfree;
	assert(nfree == 0);
f0101af9:	85 db                	test   %ebx,%ebx
f0101afb:	74 24                	je     f0101b21 <mem_init+0x662>
f0101afd:	c7 44 24 0c f8 72 10 	movl   $0xf01072f8,0xc(%esp)
f0101b04:	f0 
f0101b05:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101b0c:	f0 
f0101b0d:	c7 44 24 04 2b 03 00 	movl   $0x32b,0x4(%esp)
f0101b14:	00 
f0101b15:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101b1c:	e8 1f e5 ff ff       	call   f0100040 <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f0101b21:	c7 04 24 34 6b 10 f0 	movl   $0xf0106b34,(%esp)
f0101b28:	e8 4f 23 00 00       	call   f0103e7c <cprintf>
	int i;
	extern pde_t entry_pgdir[];

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101b2d:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b34:	e8 13 f6 ff ff       	call   f010114c <page_alloc>
f0101b39:	89 c3                	mov    %eax,%ebx
f0101b3b:	85 c0                	test   %eax,%eax
f0101b3d:	75 24                	jne    f0101b63 <mem_init+0x6a4>
f0101b3f:	c7 44 24 0c 06 72 10 	movl   $0xf0107206,0xc(%esp)
f0101b46:	f0 
f0101b47:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101b4e:	f0 
f0101b4f:	c7 44 24 04 93 03 00 	movl   $0x393,0x4(%esp)
f0101b56:	00 
f0101b57:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101b5e:	e8 dd e4 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101b63:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b6a:	e8 dd f5 ff ff       	call   f010114c <page_alloc>
f0101b6f:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0101b72:	85 c0                	test   %eax,%eax
f0101b74:	75 24                	jne    f0101b9a <mem_init+0x6db>
f0101b76:	c7 44 24 0c 1c 72 10 	movl   $0xf010721c,0xc(%esp)
f0101b7d:	f0 
f0101b7e:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101b85:	f0 
f0101b86:	c7 44 24 04 94 03 00 	movl   $0x394,0x4(%esp)
f0101b8d:	00 
f0101b8e:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101b95:	e8 a6 e4 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0101b9a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101ba1:	e8 a6 f5 ff ff       	call   f010114c <page_alloc>
f0101ba6:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101ba9:	85 c0                	test   %eax,%eax
f0101bab:	75 24                	jne    f0101bd1 <mem_init+0x712>
f0101bad:	c7 44 24 0c 32 72 10 	movl   $0xf0107232,0xc(%esp)
f0101bb4:	f0 
f0101bb5:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101bbc:	f0 
f0101bbd:	c7 44 24 04 95 03 00 	movl   $0x395,0x4(%esp)
f0101bc4:	00 
f0101bc5:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101bcc:	e8 6f e4 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101bd1:	3b 5d d0             	cmp    -0x30(%ebp),%ebx
f0101bd4:	75 24                	jne    f0101bfa <mem_init+0x73b>
f0101bd6:	c7 44 24 0c 48 72 10 	movl   $0xf0107248,0xc(%esp)
f0101bdd:	f0 
f0101bde:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101be5:	f0 
f0101be6:	c7 44 24 04 98 03 00 	movl   $0x398,0x4(%esp)
f0101bed:	00 
f0101bee:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101bf5:	e8 46 e4 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101bfa:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101bfd:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0101c00:	74 04                	je     f0101c06 <mem_init+0x747>
f0101c02:	39 c3                	cmp    %eax,%ebx
f0101c04:	75 24                	jne    f0101c2a <mem_init+0x76b>
f0101c06:	c7 44 24 0c 14 6b 10 	movl   $0xf0106b14,0xc(%esp)
f0101c0d:	f0 
f0101c0e:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101c15:	f0 
f0101c16:	c7 44 24 04 99 03 00 	movl   $0x399,0x4(%esp)
f0101c1d:	00 
f0101c1e:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101c25:	e8 16 e4 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101c2a:	a1 40 22 22 f0       	mov    0xf0222240,%eax
f0101c2f:	89 45 cc             	mov    %eax,-0x34(%ebp)
	page_free_list = 0;
f0101c32:	c7 05 40 22 22 f0 00 	movl   $0x0,0xf0222240
f0101c39:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f0101c3c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101c43:	e8 04 f5 ff ff       	call   f010114c <page_alloc>
f0101c48:	85 c0                	test   %eax,%eax
f0101c4a:	74 24                	je     f0101c70 <mem_init+0x7b1>
f0101c4c:	c7 44 24 0c b1 72 10 	movl   $0xf01072b1,0xc(%esp)
f0101c53:	f0 
f0101c54:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101c5b:	f0 
f0101c5c:	c7 44 24 04 a0 03 00 	movl   $0x3a0,0x4(%esp)
f0101c63:	00 
f0101c64:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101c6b:	e8 d0 e3 ff ff       	call   f0100040 <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f0101c70:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101c73:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101c77:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101c7e:	00 
f0101c7f:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0101c84:	89 04 24             	mov    %eax,(%esp)
f0101c87:	e8 87 f6 ff ff       	call   f0101313 <page_lookup>
f0101c8c:	85 c0                	test   %eax,%eax
f0101c8e:	74 24                	je     f0101cb4 <mem_init+0x7f5>
f0101c90:	c7 44 24 0c 54 6b 10 	movl   $0xf0106b54,0xc(%esp)
f0101c97:	f0 
f0101c98:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101c9f:	f0 
f0101ca0:	c7 44 24 04 a3 03 00 	movl   $0x3a3,0x4(%esp)
f0101ca7:	00 
f0101ca8:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101caf:	e8 8c e3 ff ff       	call   f0100040 <_panic>

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);
f0101cb4:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101cbb:	00 
f0101cbc:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101cc3:	00 
f0101cc4:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101cc7:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101ccb:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0101cd0:	89 04 24             	mov    %eax,(%esp)
f0101cd3:	e8 26 f7 ff ff       	call   f01013fe <page_insert>
f0101cd8:	85 c0                	test   %eax,%eax
f0101cda:	78 24                	js     f0101d00 <mem_init+0x841>
f0101cdc:	c7 44 24 0c 8c 6b 10 	movl   $0xf0106b8c,0xc(%esp)
f0101ce3:	f0 
f0101ce4:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101ceb:	f0 
f0101cec:	c7 44 24 04 a6 03 00 	movl   $0x3a6,0x4(%esp)
f0101cf3:	00 
f0101cf4:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101cfb:	e8 40 e3 ff ff       	call   f0100040 <_panic>

	// free pp0 and try again: pp0 should be used for page table
	page_free(pp0);
f0101d00:	89 1c 24             	mov    %ebx,(%esp)
f0101d03:	e8 c9 f4 ff ff       	call   f01011d1 <page_free>
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) == 0);
f0101d08:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101d0f:	00 
f0101d10:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101d17:	00 
f0101d18:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101d1b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101d1f:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0101d24:	89 04 24             	mov    %eax,(%esp)
f0101d27:	e8 d2 f6 ff ff       	call   f01013fe <page_insert>
f0101d2c:	85 c0                	test   %eax,%eax
f0101d2e:	74 24                	je     f0101d54 <mem_init+0x895>
f0101d30:	c7 44 24 0c bc 6b 10 	movl   $0xf0106bbc,0xc(%esp)
f0101d37:	f0 
f0101d38:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101d3f:	f0 
f0101d40:	c7 44 24 04 aa 03 00 	movl   $0x3aa,0x4(%esp)
f0101d47:	00 
f0101d48:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101d4f:	e8 ec e2 ff ff       	call   f0100040 <_panic>
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101d54:	8b 35 0c 2f 22 f0    	mov    0xf0222f0c,%esi
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101d5a:	8b 3d 10 2f 22 f0    	mov    0xf0222f10,%edi
f0101d60:	8b 16                	mov    (%esi),%edx
f0101d62:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0101d68:	89 d8                	mov    %ebx,%eax
f0101d6a:	29 f8                	sub    %edi,%eax
f0101d6c:	c1 f8 03             	sar    $0x3,%eax
f0101d6f:	c1 e0 0c             	shl    $0xc,%eax
f0101d72:	39 c2                	cmp    %eax,%edx
f0101d74:	74 24                	je     f0101d9a <mem_init+0x8db>
f0101d76:	c7 44 24 0c ec 6b 10 	movl   $0xf0106bec,0xc(%esp)
f0101d7d:	f0 
f0101d7e:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101d85:	f0 
f0101d86:	c7 44 24 04 ab 03 00 	movl   $0x3ab,0x4(%esp)
f0101d8d:	00 
f0101d8e:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101d95:	e8 a6 e2 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, 0x0) == page2pa(pp1));
f0101d9a:	ba 00 00 00 00       	mov    $0x0,%edx
f0101d9f:	89 f0                	mov    %esi,%eax
f0101da1:	e8 de ed ff ff       	call   f0100b84 <check_va2pa>
f0101da6:	8b 55 d0             	mov    -0x30(%ebp),%edx
f0101da9:	29 fa                	sub    %edi,%edx
f0101dab:	c1 fa 03             	sar    $0x3,%edx
f0101dae:	c1 e2 0c             	shl    $0xc,%edx
f0101db1:	39 d0                	cmp    %edx,%eax
f0101db3:	74 24                	je     f0101dd9 <mem_init+0x91a>
f0101db5:	c7 44 24 0c 14 6c 10 	movl   $0xf0106c14,0xc(%esp)
f0101dbc:	f0 
f0101dbd:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101dc4:	f0 
f0101dc5:	c7 44 24 04 ac 03 00 	movl   $0x3ac,0x4(%esp)
f0101dcc:	00 
f0101dcd:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101dd4:	e8 67 e2 ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0101dd9:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101ddc:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101de1:	74 24                	je     f0101e07 <mem_init+0x948>
f0101de3:	c7 44 24 0c 03 73 10 	movl   $0xf0107303,0xc(%esp)
f0101dea:	f0 
f0101deb:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101df2:	f0 
f0101df3:	c7 44 24 04 ad 03 00 	movl   $0x3ad,0x4(%esp)
f0101dfa:	00 
f0101dfb:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101e02:	e8 39 e2 ff ff       	call   f0100040 <_panic>
	assert(pp0->pp_ref == 1);
f0101e07:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0101e0c:	74 24                	je     f0101e32 <mem_init+0x973>
f0101e0e:	c7 44 24 0c 14 73 10 	movl   $0xf0107314,0xc(%esp)
f0101e15:	f0 
f0101e16:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101e1d:	f0 
f0101e1e:	c7 44 24 04 ae 03 00 	movl   $0x3ae,0x4(%esp)
f0101e25:	00 
f0101e26:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101e2d:	e8 0e e2 ff ff       	call   f0100040 <_panic>

	// should be able to map pp2 at PGSIZE because pp0 is already allocated for page table
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101e32:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101e39:	00 
f0101e3a:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101e41:	00 
f0101e42:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101e45:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101e49:	89 34 24             	mov    %esi,(%esp)
f0101e4c:	e8 ad f5 ff ff       	call   f01013fe <page_insert>
f0101e51:	85 c0                	test   %eax,%eax
f0101e53:	74 24                	je     f0101e79 <mem_init+0x9ba>
f0101e55:	c7 44 24 0c 44 6c 10 	movl   $0xf0106c44,0xc(%esp)
f0101e5c:	f0 
f0101e5d:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101e64:	f0 
f0101e65:	c7 44 24 04 b1 03 00 	movl   $0x3b1,0x4(%esp)
f0101e6c:	00 
f0101e6d:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101e74:	e8 c7 e1 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101e79:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101e7e:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0101e83:	e8 fc ec ff ff       	call   f0100b84 <check_va2pa>
f0101e88:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101e8b:	2b 15 10 2f 22 f0    	sub    0xf0222f10,%edx
f0101e91:	c1 fa 03             	sar    $0x3,%edx
f0101e94:	c1 e2 0c             	shl    $0xc,%edx
f0101e97:	39 d0                	cmp    %edx,%eax
f0101e99:	74 24                	je     f0101ebf <mem_init+0xa00>
f0101e9b:	c7 44 24 0c 80 6c 10 	movl   $0xf0106c80,0xc(%esp)
f0101ea2:	f0 
f0101ea3:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101eaa:	f0 
f0101eab:	c7 44 24 04 b2 03 00 	movl   $0x3b2,0x4(%esp)
f0101eb2:	00 
f0101eb3:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101eba:	e8 81 e1 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101ebf:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101ec2:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101ec7:	74 24                	je     f0101eed <mem_init+0xa2e>
f0101ec9:	c7 44 24 0c 25 73 10 	movl   $0xf0107325,0xc(%esp)
f0101ed0:	f0 
f0101ed1:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101ed8:	f0 
f0101ed9:	c7 44 24 04 b3 03 00 	movl   $0x3b3,0x4(%esp)
f0101ee0:	00 
f0101ee1:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101ee8:	e8 53 e1 ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0101eed:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101ef4:	e8 53 f2 ff ff       	call   f010114c <page_alloc>
f0101ef9:	85 c0                	test   %eax,%eax
f0101efb:	74 24                	je     f0101f21 <mem_init+0xa62>
f0101efd:	c7 44 24 0c b1 72 10 	movl   $0xf01072b1,0xc(%esp)
f0101f04:	f0 
f0101f05:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101f0c:	f0 
f0101f0d:	c7 44 24 04 b6 03 00 	movl   $0x3b6,0x4(%esp)
f0101f14:	00 
f0101f15:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101f1c:	e8 1f e1 ff ff       	call   f0100040 <_panic>

	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101f21:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101f28:	00 
f0101f29:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101f30:	00 
f0101f31:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101f34:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101f38:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0101f3d:	89 04 24             	mov    %eax,(%esp)
f0101f40:	e8 b9 f4 ff ff       	call   f01013fe <page_insert>
f0101f45:	85 c0                	test   %eax,%eax
f0101f47:	74 24                	je     f0101f6d <mem_init+0xaae>
f0101f49:	c7 44 24 0c 44 6c 10 	movl   $0xf0106c44,0xc(%esp)
f0101f50:	f0 
f0101f51:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101f58:	f0 
f0101f59:	c7 44 24 04 b9 03 00 	movl   $0x3b9,0x4(%esp)
f0101f60:	00 
f0101f61:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101f68:	e8 d3 e0 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101f6d:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101f72:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0101f77:	e8 08 ec ff ff       	call   f0100b84 <check_va2pa>
f0101f7c:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101f7f:	2b 15 10 2f 22 f0    	sub    0xf0222f10,%edx
f0101f85:	c1 fa 03             	sar    $0x3,%edx
f0101f88:	c1 e2 0c             	shl    $0xc,%edx
f0101f8b:	39 d0                	cmp    %edx,%eax
f0101f8d:	74 24                	je     f0101fb3 <mem_init+0xaf4>
f0101f8f:	c7 44 24 0c 80 6c 10 	movl   $0xf0106c80,0xc(%esp)
f0101f96:	f0 
f0101f97:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101f9e:	f0 
f0101f9f:	c7 44 24 04 ba 03 00 	movl   $0x3ba,0x4(%esp)
f0101fa6:	00 
f0101fa7:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101fae:	e8 8d e0 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101fb3:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101fb6:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101fbb:	74 24                	je     f0101fe1 <mem_init+0xb22>
f0101fbd:	c7 44 24 0c 25 73 10 	movl   $0xf0107325,0xc(%esp)
f0101fc4:	f0 
f0101fc5:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0101fcc:	f0 
f0101fcd:	c7 44 24 04 bb 03 00 	movl   $0x3bb,0x4(%esp)
f0101fd4:	00 
f0101fd5:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0101fdc:	e8 5f e0 ff ff       	call   f0100040 <_panic>

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));
f0101fe1:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101fe8:	e8 5f f1 ff ff       	call   f010114c <page_alloc>
f0101fed:	85 c0                	test   %eax,%eax
f0101fef:	74 24                	je     f0102015 <mem_init+0xb56>
f0101ff1:	c7 44 24 0c b1 72 10 	movl   $0xf01072b1,0xc(%esp)
f0101ff8:	f0 
f0101ff9:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102000:	f0 
f0102001:	c7 44 24 04 bf 03 00 	movl   $0x3bf,0x4(%esp)
f0102008:	00 
f0102009:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102010:	e8 2b e0 ff ff       	call   f0100040 <_panic>

	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f0102015:	8b 15 0c 2f 22 f0    	mov    0xf0222f0c,%edx
f010201b:	8b 02                	mov    (%edx),%eax
f010201d:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102022:	89 c1                	mov    %eax,%ecx
f0102024:	c1 e9 0c             	shr    $0xc,%ecx
f0102027:	3b 0d 08 2f 22 f0    	cmp    0xf0222f08,%ecx
f010202d:	72 20                	jb     f010204f <mem_init+0xb90>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010202f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102033:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f010203a:	f0 
f010203b:	c7 44 24 04 c2 03 00 	movl   $0x3c2,0x4(%esp)
f0102042:	00 
f0102043:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010204a:	e8 f1 df ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f010204f:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102054:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	assert(pgdir_walk(kern_pgdir, (void*)PGSIZE, 0) == ptep+PTX(PGSIZE));
f0102057:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f010205e:	00 
f010205f:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102066:	00 
f0102067:	89 14 24             	mov    %edx,(%esp)
f010206a:	e8 9a f1 ff ff       	call   f0101209 <pgdir_walk>
f010206f:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0102072:	8d 51 04             	lea    0x4(%ecx),%edx
f0102075:	39 d0                	cmp    %edx,%eax
f0102077:	74 24                	je     f010209d <mem_init+0xbde>
f0102079:	c7 44 24 0c b0 6c 10 	movl   $0xf0106cb0,0xc(%esp)
f0102080:	f0 
f0102081:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102088:	f0 
f0102089:	c7 44 24 04 c3 03 00 	movl   $0x3c3,0x4(%esp)
f0102090:	00 
f0102091:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102098:	e8 a3 df ff ff       	call   f0100040 <_panic>

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
f010209d:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01020a4:	00 
f01020a5:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01020ac:	00 
f01020ad:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01020b0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01020b4:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f01020b9:	89 04 24             	mov    %eax,(%esp)
f01020bc:	e8 3d f3 ff ff       	call   f01013fe <page_insert>
f01020c1:	85 c0                	test   %eax,%eax
f01020c3:	74 24                	je     f01020e9 <mem_init+0xc2a>
f01020c5:	c7 44 24 0c f0 6c 10 	movl   $0xf0106cf0,0xc(%esp)
f01020cc:	f0 
f01020cd:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01020d4:	f0 
f01020d5:	c7 44 24 04 c6 03 00 	movl   $0x3c6,0x4(%esp)
f01020dc:	00 
f01020dd:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01020e4:	e8 57 df ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f01020e9:	8b 35 0c 2f 22 f0    	mov    0xf0222f0c,%esi
f01020ef:	ba 00 10 00 00       	mov    $0x1000,%edx
f01020f4:	89 f0                	mov    %esi,%eax
f01020f6:	e8 89 ea ff ff       	call   f0100b84 <check_va2pa>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01020fb:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f01020fe:	2b 15 10 2f 22 f0    	sub    0xf0222f10,%edx
f0102104:	c1 fa 03             	sar    $0x3,%edx
f0102107:	c1 e2 0c             	shl    $0xc,%edx
f010210a:	39 d0                	cmp    %edx,%eax
f010210c:	74 24                	je     f0102132 <mem_init+0xc73>
f010210e:	c7 44 24 0c 80 6c 10 	movl   $0xf0106c80,0xc(%esp)
f0102115:	f0 
f0102116:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010211d:	f0 
f010211e:	c7 44 24 04 c7 03 00 	movl   $0x3c7,0x4(%esp)
f0102125:	00 
f0102126:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010212d:	e8 0e df ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0102132:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102135:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f010213a:	74 24                	je     f0102160 <mem_init+0xca1>
f010213c:	c7 44 24 0c 25 73 10 	movl   $0xf0107325,0xc(%esp)
f0102143:	f0 
f0102144:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010214b:	f0 
f010214c:	c7 44 24 04 c8 03 00 	movl   $0x3c8,0x4(%esp)
f0102153:	00 
f0102154:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010215b:	e8 e0 de ff ff       	call   f0100040 <_panic>
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U);
f0102160:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102167:	00 
f0102168:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f010216f:	00 
f0102170:	89 34 24             	mov    %esi,(%esp)
f0102173:	e8 91 f0 ff ff       	call   f0101209 <pgdir_walk>
f0102178:	f6 00 04             	testb  $0x4,(%eax)
f010217b:	75 24                	jne    f01021a1 <mem_init+0xce2>
f010217d:	c7 44 24 0c 30 6d 10 	movl   $0xf0106d30,0xc(%esp)
f0102184:	f0 
f0102185:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010218c:	f0 
f010218d:	c7 44 24 04 c9 03 00 	movl   $0x3c9,0x4(%esp)
f0102194:	00 
f0102195:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010219c:	e8 9f de ff ff       	call   f0100040 <_panic>
	assert(kern_pgdir[0] & PTE_U);
f01021a1:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f01021a6:	f6 00 04             	testb  $0x4,(%eax)
f01021a9:	75 24                	jne    f01021cf <mem_init+0xd10>
f01021ab:	c7 44 24 0c 36 73 10 	movl   $0xf0107336,0xc(%esp)
f01021b2:	f0 
f01021b3:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01021ba:	f0 
f01021bb:	c7 44 24 04 ca 03 00 	movl   $0x3ca,0x4(%esp)
f01021c2:	00 
f01021c3:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01021ca:	e8 71 de ff ff       	call   f0100040 <_panic>

	// should not be able to map at PTSIZE because need free page for page table
	assert(page_insert(kern_pgdir, pp0, (void*) PTSIZE, PTE_W) < 0);
f01021cf:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01021d6:	00 
f01021d7:	c7 44 24 08 00 00 40 	movl   $0x400000,0x8(%esp)
f01021de:	00 
f01021df:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01021e3:	89 04 24             	mov    %eax,(%esp)
f01021e6:	e8 13 f2 ff ff       	call   f01013fe <page_insert>
f01021eb:	85 c0                	test   %eax,%eax
f01021ed:	78 24                	js     f0102213 <mem_init+0xd54>
f01021ef:	c7 44 24 0c 64 6d 10 	movl   $0xf0106d64,0xc(%esp)
f01021f6:	f0 
f01021f7:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01021fe:	f0 
f01021ff:	c7 44 24 04 cd 03 00 	movl   $0x3cd,0x4(%esp)
f0102206:	00 
f0102207:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010220e:	e8 2d de ff ff       	call   f0100040 <_panic>

	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
f0102213:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f010221a:	00 
f010221b:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102222:	00 
f0102223:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102226:	89 44 24 04          	mov    %eax,0x4(%esp)
f010222a:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f010222f:	89 04 24             	mov    %eax,(%esp)
f0102232:	e8 c7 f1 ff ff       	call   f01013fe <page_insert>
f0102237:	85 c0                	test   %eax,%eax
f0102239:	74 24                	je     f010225f <mem_init+0xda0>
f010223b:	c7 44 24 0c 9c 6d 10 	movl   $0xf0106d9c,0xc(%esp)
f0102242:	f0 
f0102243:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010224a:	f0 
f010224b:	c7 44 24 04 d0 03 00 	movl   $0x3d0,0x4(%esp)
f0102252:	00 
f0102253:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010225a:	e8 e1 dd ff ff       	call   f0100040 <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f010225f:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102266:	00 
f0102267:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f010226e:	00 
f010226f:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0102274:	89 04 24             	mov    %eax,(%esp)
f0102277:	e8 8d ef ff ff       	call   f0101209 <pgdir_walk>
f010227c:	f6 00 04             	testb  $0x4,(%eax)
f010227f:	74 24                	je     f01022a5 <mem_init+0xde6>
f0102281:	c7 44 24 0c d8 6d 10 	movl   $0xf0106dd8,0xc(%esp)
f0102288:	f0 
f0102289:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102290:	f0 
f0102291:	c7 44 24 04 d1 03 00 	movl   $0x3d1,0x4(%esp)
f0102298:	00 
f0102299:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01022a0:	e8 9b dd ff ff       	call   f0100040 <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f01022a5:	8b 3d 0c 2f 22 f0    	mov    0xf0222f0c,%edi
f01022ab:	ba 00 00 00 00       	mov    $0x0,%edx
f01022b0:	89 f8                	mov    %edi,%eax
f01022b2:	e8 cd e8 ff ff       	call   f0100b84 <check_va2pa>
f01022b7:	89 c6                	mov    %eax,%esi
f01022b9:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01022bc:	2b 05 10 2f 22 f0    	sub    0xf0222f10,%eax
f01022c2:	c1 f8 03             	sar    $0x3,%eax
f01022c5:	c1 e0 0c             	shl    $0xc,%eax
f01022c8:	39 c6                	cmp    %eax,%esi
f01022ca:	74 24                	je     f01022f0 <mem_init+0xe31>
f01022cc:	c7 44 24 0c 10 6e 10 	movl   $0xf0106e10,0xc(%esp)
f01022d3:	f0 
f01022d4:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01022db:	f0 
f01022dc:	c7 44 24 04 d4 03 00 	movl   $0x3d4,0x4(%esp)
f01022e3:	00 
f01022e4:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01022eb:	e8 50 dd ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f01022f0:	ba 00 10 00 00       	mov    $0x1000,%edx
f01022f5:	89 f8                	mov    %edi,%eax
f01022f7:	e8 88 e8 ff ff       	call   f0100b84 <check_va2pa>
f01022fc:	39 c6                	cmp    %eax,%esi
f01022fe:	74 24                	je     f0102324 <mem_init+0xe65>
f0102300:	c7 44 24 0c 3c 6e 10 	movl   $0xf0106e3c,0xc(%esp)
f0102307:	f0 
f0102308:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010230f:	f0 
f0102310:	c7 44 24 04 d5 03 00 	movl   $0x3d5,0x4(%esp)
f0102317:	00 
f0102318:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010231f:	e8 1c dd ff ff       	call   f0100040 <_panic>
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
f0102324:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102327:	66 83 78 04 02       	cmpw   $0x2,0x4(%eax)
f010232c:	74 24                	je     f0102352 <mem_init+0xe93>
f010232e:	c7 44 24 0c 4c 73 10 	movl   $0xf010734c,0xc(%esp)
f0102335:	f0 
f0102336:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010233d:	f0 
f010233e:	c7 44 24 04 d7 03 00 	movl   $0x3d7,0x4(%esp)
f0102345:	00 
f0102346:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010234d:	e8 ee dc ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f0102352:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102355:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f010235a:	74 24                	je     f0102380 <mem_init+0xec1>
f010235c:	c7 44 24 0c 5d 73 10 	movl   $0xf010735d,0xc(%esp)
f0102363:	f0 
f0102364:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010236b:	f0 
f010236c:	c7 44 24 04 d8 03 00 	movl   $0x3d8,0x4(%esp)
f0102373:	00 
f0102374:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010237b:	e8 c0 dc ff ff       	call   f0100040 <_panic>

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);
f0102380:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102387:	e8 c0 ed ff ff       	call   f010114c <page_alloc>
f010238c:	85 c0                	test   %eax,%eax
f010238e:	74 05                	je     f0102395 <mem_init+0xed6>
f0102390:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f0102393:	74 24                	je     f01023b9 <mem_init+0xefa>
f0102395:	c7 44 24 0c 6c 6e 10 	movl   $0xf0106e6c,0xc(%esp)
f010239c:	f0 
f010239d:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01023a4:	f0 
f01023a5:	c7 44 24 04 db 03 00 	movl   $0x3db,0x4(%esp)
f01023ac:	00 
f01023ad:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01023b4:	e8 87 dc ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f01023b9:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01023c0:	00 
f01023c1:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f01023c6:	89 04 24             	mov    %eax,(%esp)
f01023c9:	e8 e7 ef ff ff       	call   f01013b5 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01023ce:	8b 35 0c 2f 22 f0    	mov    0xf0222f0c,%esi
f01023d4:	ba 00 00 00 00       	mov    $0x0,%edx
f01023d9:	89 f0                	mov    %esi,%eax
f01023db:	e8 a4 e7 ff ff       	call   f0100b84 <check_va2pa>
f01023e0:	83 f8 ff             	cmp    $0xffffffff,%eax
f01023e3:	74 24                	je     f0102409 <mem_init+0xf4a>
f01023e5:	c7 44 24 0c 90 6e 10 	movl   $0xf0106e90,0xc(%esp)
f01023ec:	f0 
f01023ed:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01023f4:	f0 
f01023f5:	c7 44 24 04 df 03 00 	movl   $0x3df,0x4(%esp)
f01023fc:	00 
f01023fd:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102404:	e8 37 dc ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102409:	ba 00 10 00 00       	mov    $0x1000,%edx
f010240e:	89 f0                	mov    %esi,%eax
f0102410:	e8 6f e7 ff ff       	call   f0100b84 <check_va2pa>
f0102415:	8b 55 d0             	mov    -0x30(%ebp),%edx
f0102418:	2b 15 10 2f 22 f0    	sub    0xf0222f10,%edx
f010241e:	c1 fa 03             	sar    $0x3,%edx
f0102421:	c1 e2 0c             	shl    $0xc,%edx
f0102424:	39 d0                	cmp    %edx,%eax
f0102426:	74 24                	je     f010244c <mem_init+0xf8d>
f0102428:	c7 44 24 0c 3c 6e 10 	movl   $0xf0106e3c,0xc(%esp)
f010242f:	f0 
f0102430:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102437:	f0 
f0102438:	c7 44 24 04 e0 03 00 	movl   $0x3e0,0x4(%esp)
f010243f:	00 
f0102440:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102447:	e8 f4 db ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f010244c:	8b 45 d0             	mov    -0x30(%ebp),%eax
f010244f:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0102454:	74 24                	je     f010247a <mem_init+0xfbb>
f0102456:	c7 44 24 0c 03 73 10 	movl   $0xf0107303,0xc(%esp)
f010245d:	f0 
f010245e:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102465:	f0 
f0102466:	c7 44 24 04 e1 03 00 	movl   $0x3e1,0x4(%esp)
f010246d:	00 
f010246e:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102475:	e8 c6 db ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f010247a:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010247d:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102482:	74 24                	je     f01024a8 <mem_init+0xfe9>
f0102484:	c7 44 24 0c 5d 73 10 	movl   $0xf010735d,0xc(%esp)
f010248b:	f0 
f010248c:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102493:	f0 
f0102494:	c7 44 24 04 e2 03 00 	movl   $0x3e2,0x4(%esp)
f010249b:	00 
f010249c:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01024a3:	e8 98 db ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
f01024a8:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01024af:	00 
f01024b0:	89 34 24             	mov    %esi,(%esp)
f01024b3:	e8 fd ee ff ff       	call   f01013b5 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01024b8:	8b 35 0c 2f 22 f0    	mov    0xf0222f0c,%esi
f01024be:	ba 00 00 00 00       	mov    $0x0,%edx
f01024c3:	89 f0                	mov    %esi,%eax
f01024c5:	e8 ba e6 ff ff       	call   f0100b84 <check_va2pa>
f01024ca:	83 f8 ff             	cmp    $0xffffffff,%eax
f01024cd:	74 24                	je     f01024f3 <mem_init+0x1034>
f01024cf:	c7 44 24 0c 90 6e 10 	movl   $0xf0106e90,0xc(%esp)
f01024d6:	f0 
f01024d7:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01024de:	f0 
f01024df:	c7 44 24 04 e6 03 00 	movl   $0x3e6,0x4(%esp)
f01024e6:	00 
f01024e7:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01024ee:	e8 4d db ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
f01024f3:	ba 00 10 00 00       	mov    $0x1000,%edx
f01024f8:	89 f0                	mov    %esi,%eax
f01024fa:	e8 85 e6 ff ff       	call   f0100b84 <check_va2pa>
f01024ff:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102502:	74 24                	je     f0102528 <mem_init+0x1069>
f0102504:	c7 44 24 0c b4 6e 10 	movl   $0xf0106eb4,0xc(%esp)
f010250b:	f0 
f010250c:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102513:	f0 
f0102514:	c7 44 24 04 e7 03 00 	movl   $0x3e7,0x4(%esp)
f010251b:	00 
f010251c:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102523:	e8 18 db ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f0102528:	8b 45 d0             	mov    -0x30(%ebp),%eax
f010252b:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102530:	74 24                	je     f0102556 <mem_init+0x1097>
f0102532:	c7 44 24 0c 6e 73 10 	movl   $0xf010736e,0xc(%esp)
f0102539:	f0 
f010253a:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102541:	f0 
f0102542:	c7 44 24 04 e8 03 00 	movl   $0x3e8,0x4(%esp)
f0102549:	00 
f010254a:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102551:	e8 ea da ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f0102556:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102559:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f010255e:	74 24                	je     f0102584 <mem_init+0x10c5>
f0102560:	c7 44 24 0c 5d 73 10 	movl   $0xf010735d,0xc(%esp)
f0102567:	f0 
f0102568:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010256f:	f0 
f0102570:	c7 44 24 04 e9 03 00 	movl   $0x3e9,0x4(%esp)
f0102577:	00 
f0102578:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010257f:	e8 bc da ff ff       	call   f0100040 <_panic>

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);
f0102584:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010258b:	e8 bc eb ff ff       	call   f010114c <page_alloc>
f0102590:	85 c0                	test   %eax,%eax
f0102592:	74 05                	je     f0102599 <mem_init+0x10da>
f0102594:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0102597:	74 24                	je     f01025bd <mem_init+0x10fe>
f0102599:	c7 44 24 0c dc 6e 10 	movl   $0xf0106edc,0xc(%esp)
f01025a0:	f0 
f01025a1:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01025a8:	f0 
f01025a9:	c7 44 24 04 ec 03 00 	movl   $0x3ec,0x4(%esp)
f01025b0:	00 
f01025b1:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01025b8:	e8 83 da ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f01025bd:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01025c4:	e8 83 eb ff ff       	call   f010114c <page_alloc>
f01025c9:	85 c0                	test   %eax,%eax
f01025cb:	74 24                	je     f01025f1 <mem_init+0x1132>
f01025cd:	c7 44 24 0c b1 72 10 	movl   $0xf01072b1,0xc(%esp)
f01025d4:	f0 
f01025d5:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01025dc:	f0 
f01025dd:	c7 44 24 04 ef 03 00 	movl   $0x3ef,0x4(%esp)
f01025e4:	00 
f01025e5:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01025ec:	e8 4f da ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f01025f1:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f01025f6:	8b 08                	mov    (%eax),%ecx
f01025f8:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f01025fe:	89 da                	mov    %ebx,%edx
f0102600:	2b 15 10 2f 22 f0    	sub    0xf0222f10,%edx
f0102606:	c1 fa 03             	sar    $0x3,%edx
f0102609:	c1 e2 0c             	shl    $0xc,%edx
f010260c:	39 d1                	cmp    %edx,%ecx
f010260e:	74 24                	je     f0102634 <mem_init+0x1175>
f0102610:	c7 44 24 0c ec 6b 10 	movl   $0xf0106bec,0xc(%esp)
f0102617:	f0 
f0102618:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010261f:	f0 
f0102620:	c7 44 24 04 f2 03 00 	movl   $0x3f2,0x4(%esp)
f0102627:	00 
f0102628:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010262f:	e8 0c da ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f0102634:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f010263a:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f010263f:	74 24                	je     f0102665 <mem_init+0x11a6>
f0102641:	c7 44 24 0c 14 73 10 	movl   $0xf0107314,0xc(%esp)
f0102648:	f0 
f0102649:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102650:	f0 
f0102651:	c7 44 24 04 f4 03 00 	movl   $0x3f4,0x4(%esp)
f0102658:	00 
f0102659:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102660:	e8 db d9 ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f0102665:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// check pointer arithmetic in pgdir_walk
	page_free(pp0);
f010266b:	89 1c 24             	mov    %ebx,(%esp)
f010266e:	e8 5e eb ff ff       	call   f01011d1 <page_free>
	va = (void*)(PGSIZE * NPDENTRIES + PGSIZE);
	ptep = pgdir_walk(kern_pgdir, va, 1);
f0102673:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010267a:	00 
f010267b:	c7 44 24 04 00 10 40 	movl   $0x401000,0x4(%esp)
f0102682:	00 
f0102683:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0102688:	89 04 24             	mov    %eax,(%esp)
f010268b:	e8 79 eb ff ff       	call   f0101209 <pgdir_walk>
f0102690:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f0102693:	8b 0d 0c 2f 22 f0    	mov    0xf0222f0c,%ecx
f0102699:	8b 51 04             	mov    0x4(%ecx),%edx
f010269c:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01026a2:	8b 3d 08 2f 22 f0    	mov    0xf0222f08,%edi
f01026a8:	89 d6                	mov    %edx,%esi
f01026aa:	c1 ee 0c             	shr    $0xc,%esi
f01026ad:	39 fe                	cmp    %edi,%esi
f01026af:	72 20                	jb     f01026d1 <mem_init+0x1212>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01026b1:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01026b5:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f01026bc:	f0 
f01026bd:	c7 44 24 04 fb 03 00 	movl   $0x3fb,0x4(%esp)
f01026c4:	00 
f01026c5:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01026cc:	e8 6f d9 ff ff       	call   f0100040 <_panic>
	assert(ptep == ptep1 + PTX(va));
f01026d1:	81 ea fc ff ff 0f    	sub    $0xffffffc,%edx
f01026d7:	39 d0                	cmp    %edx,%eax
f01026d9:	74 24                	je     f01026ff <mem_init+0x1240>
f01026db:	c7 44 24 0c 7f 73 10 	movl   $0xf010737f,0xc(%esp)
f01026e2:	f0 
f01026e3:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01026ea:	f0 
f01026eb:	c7 44 24 04 fc 03 00 	movl   $0x3fc,0x4(%esp)
f01026f2:	00 
f01026f3:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01026fa:	e8 41 d9 ff ff       	call   f0100040 <_panic>
	kern_pgdir[PDX(va)] = 0;
f01026ff:	c7 41 04 00 00 00 00 	movl   $0x0,0x4(%ecx)
	pp0->pp_ref = 0;
f0102706:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010270c:	89 d8                	mov    %ebx,%eax
f010270e:	2b 05 10 2f 22 f0    	sub    0xf0222f10,%eax
f0102714:	c1 f8 03             	sar    $0x3,%eax
f0102717:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010271a:	89 c2                	mov    %eax,%edx
f010271c:	c1 ea 0c             	shr    $0xc,%edx
f010271f:	39 d7                	cmp    %edx,%edi
f0102721:	77 20                	ja     f0102743 <mem_init+0x1284>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102723:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102727:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f010272e:	f0 
f010272f:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102736:	00 
f0102737:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f010273e:	e8 fd d8 ff ff       	call   f0100040 <_panic>

	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
f0102743:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010274a:	00 
f010274b:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
f0102752:	00 
	return (void *)(pa + KERNBASE);
f0102753:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102758:	89 04 24             	mov    %eax,(%esp)
f010275b:	e8 79 2e 00 00       	call   f01055d9 <memset>
	page_free(pp0);
f0102760:	89 1c 24             	mov    %ebx,(%esp)
f0102763:	e8 69 ea ff ff       	call   f01011d1 <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f0102768:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010276f:	00 
f0102770:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0102777:	00 
f0102778:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f010277d:	89 04 24             	mov    %eax,(%esp)
f0102780:	e8 84 ea ff ff       	call   f0101209 <pgdir_walk>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102785:	89 da                	mov    %ebx,%edx
f0102787:	2b 15 10 2f 22 f0    	sub    0xf0222f10,%edx
f010278d:	c1 fa 03             	sar    $0x3,%edx
f0102790:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102793:	89 d0                	mov    %edx,%eax
f0102795:	c1 e8 0c             	shr    $0xc,%eax
f0102798:	3b 05 08 2f 22 f0    	cmp    0xf0222f08,%eax
f010279e:	72 20                	jb     f01027c0 <mem_init+0x1301>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01027a0:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01027a4:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f01027ab:	f0 
f01027ac:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01027b3:	00 
f01027b4:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f01027bb:	e8 80 d8 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01027c0:	8d 82 00 00 00 f0    	lea    -0x10000000(%edx),%eax
	ptep = (pte_t *) page2kva(pp0);
f01027c6:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	for(i=0; i<NPTENTRIES; i++)
		assert((ptep[i] & PTE_P) == 0);
f01027c9:	f6 82 00 00 00 f0 01 	testb  $0x1,-0x10000000(%edx)
f01027d0:	75 13                	jne    f01027e5 <mem_init+0x1326>
f01027d2:	8d 82 04 00 00 f0    	lea    -0xffffffc(%edx),%eax
f01027d8:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f01027de:	8b 38                	mov    (%eax),%edi
f01027e0:	83 e7 01             	and    $0x1,%edi
f01027e3:	74 24                	je     f0102809 <mem_init+0x134a>
f01027e5:	c7 44 24 0c 97 73 10 	movl   $0xf0107397,0xc(%esp)
f01027ec:	f0 
f01027ed:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01027f4:	f0 
f01027f5:	c7 44 24 04 06 04 00 	movl   $0x406,0x4(%esp)
f01027fc:	00 
f01027fd:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102804:	e8 37 d8 ff ff       	call   f0100040 <_panic>
f0102809:	83 c0 04             	add    $0x4,%eax
	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
	page_free(pp0);
	pgdir_walk(kern_pgdir, 0x0, 1);
	ptep = (pte_t *) page2kva(pp0);
	for(i=0; i<NPTENTRIES; i++)
f010280c:	39 d0                	cmp    %edx,%eax
f010280e:	75 ce                	jne    f01027de <mem_init+0x131f>
		assert((ptep[i] & PTE_P) == 0);
	kern_pgdir[0] = 0;
f0102810:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0102815:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f010281b:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// give free list back
	page_free_list = fl;
f0102821:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0102824:	a3 40 22 22 f0       	mov    %eax,0xf0222240

	// free the pages we took
	page_free(pp0);
f0102829:	89 1c 24             	mov    %ebx,(%esp)
f010282c:	e8 a0 e9 ff ff       	call   f01011d1 <page_free>
	page_free(pp1);
f0102831:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102834:	89 04 24             	mov    %eax,(%esp)
f0102837:	e8 95 e9 ff ff       	call   f01011d1 <page_free>
	page_free(pp2);
f010283c:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010283f:	89 04 24             	mov    %eax,(%esp)
f0102842:	e8 8a e9 ff ff       	call   f01011d1 <page_free>

	cprintf("check_page() succeeded!\n");
f0102847:	c7 04 24 ae 73 10 f0 	movl   $0xf01073ae,(%esp)
f010284e:	e8 29 16 00 00       	call   f0103e7c <cprintf>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f0102853:	8b 0d 08 2f 22 f0    	mov    0xf0222f08,%ecx
f0102859:	8d 04 cd ff 0f 00 00 	lea    0xfff(,%ecx,8),%eax
f0102860:	89 c2                	mov    %eax,%edx
f0102862:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
f0102868:	39 d0                	cmp    %edx,%eax
f010286a:	0f 84 96 0a 00 00    	je     f0103306 <mem_init+0x1e47>
		page_insert(kern_pgdir, pa2page(PADDR(pages) + i), (void *)(UPAGES + i), PTE_U);
f0102870:	a1 10 2f 22 f0       	mov    0xf0222f10,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102875:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010287a:	76 21                	jbe    f010289d <mem_init+0x13de>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f010287c:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102882:	c1 ea 0c             	shr    $0xc,%edx
f0102885:	39 d1                	cmp    %edx,%ecx
f0102887:	77 62                	ja     f01028eb <mem_init+0x142c>
f0102889:	eb 44                	jmp    f01028cf <mem_init+0x1410>
f010288b:	8d bb 00 10 00 ef    	lea    -0x10fff000(%ebx),%edi
f0102891:	a1 10 2f 22 f0       	mov    0xf0222f10,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102896:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010289b:	77 20                	ja     f01028bd <mem_init+0x13fe>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010289d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01028a1:	c7 44 24 08 c8 63 10 	movl   $0xf01063c8,0x8(%esp)
f01028a8:	f0 
f01028a9:	c7 44 24 04 be 00 00 	movl   $0xbe,0x4(%esp)
f01028b0:	00 
f01028b1:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01028b8:	e8 83 d7 ff ff       	call   f0100040 <_panic>
f01028bd:	8d 94 18 00 10 00 10 	lea    0x10001000(%eax,%ebx,1),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01028c4:	c1 ea 0c             	shr    $0xc,%edx
f01028c7:	39 d6                	cmp    %edx,%esi
f01028c9:	76 04                	jbe    f01028cf <mem_init+0x1410>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f01028cb:	89 cb                	mov    %ecx,%ebx
f01028cd:	eb 2b                	jmp    f01028fa <mem_init+0x143b>
		panic("pa2page called with invalid pa");
f01028cf:	c7 44 24 08 98 6a 10 	movl   $0xf0106a98,0x8(%esp)
f01028d6:	f0 
f01028d7:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01028de:	00 
f01028df:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f01028e6:	e8 55 d7 ff ff       	call   f0100040 <_panic>
		page_insert(kern_pgdir, pa2page(PADDR(pages) + i), (void *)(UPAGES + i), PTE_U);
f01028eb:	b9 00 00 00 ef       	mov    $0xef000000,%ecx
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f01028f0:	bb 00 00 00 00       	mov    $0x0,%ebx
f01028f5:	89 7d d4             	mov    %edi,-0x2c(%ebp)
f01028f8:	89 cf                	mov    %ecx,%edi
		page_insert(kern_pgdir, pa2page(PADDR(pages) + i), (void *)(UPAGES + i), PTE_U);
f01028fa:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f0102901:	00 
f0102902:	89 7c 24 08          	mov    %edi,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102906:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f0102909:	89 44 24 04          	mov    %eax,0x4(%esp)
f010290d:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0102912:	89 04 24             	mov    %eax,(%esp)
f0102915:	e8 e4 ea ff ff       	call   f01013fe <page_insert>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f010291a:	8d 8b 00 10 00 00    	lea    0x1000(%ebx),%ecx
f0102920:	8b 35 08 2f 22 f0    	mov    0xf0222f08,%esi
f0102926:	8d 04 f5 ff 0f 00 00 	lea    0xfff(,%esi,8),%eax
f010292d:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102932:	39 c8                	cmp    %ecx,%eax
f0102934:	0f 87 51 ff ff ff    	ja     f010288b <mem_init+0x13cc>
f010293a:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f010293d:	e9 c4 09 00 00       	jmp    f0103306 <mem_init+0x1e47>
static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102942:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102947:	c1 e8 0c             	shr    $0xc,%eax
f010294a:	39 05 08 2f 22 f0    	cmp    %eax,0xf0222f08
f0102950:	0f 87 36 0a 00 00    	ja     f010338c <mem_init+0x1ecd>
f0102956:	eb 44                	jmp    f010299c <mem_init+0x14dd>
f0102958:	8d 93 00 00 c0 ee    	lea    -0x11400000(%ebx),%edx
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		page_insert(kern_pgdir,pa2page(PADDR(envs)+i),(void *)(UENVS + i),PTE_U);
f010295e:	a1 48 22 22 f0       	mov    0xf0222248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102963:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102968:	77 20                	ja     f010298a <mem_init+0x14cb>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010296a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010296e:	c7 44 24 08 c8 63 10 	movl   $0xf01063c8,0x8(%esp)
f0102975:	f0 
f0102976:	c7 44 24 04 c8 00 00 	movl   $0xc8,0x4(%esp)
f010297d:	00 
f010297e:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102985:	e8 b6 d6 ff ff       	call   f0100040 <_panic>
f010298a:	8d 84 18 00 00 00 10 	lea    0x10000000(%eax,%ebx,1),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102991:	c1 e8 0c             	shr    $0xc,%eax
f0102994:	3b 05 08 2f 22 f0    	cmp    0xf0222f08,%eax
f010299a:	72 1c                	jb     f01029b8 <mem_init+0x14f9>
		panic("pa2page called with invalid pa");
f010299c:	c7 44 24 08 98 6a 10 	movl   $0xf0106a98,0x8(%esp)
f01029a3:	f0 
f01029a4:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01029ab:	00 
f01029ac:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f01029b3:	e8 88 d6 ff ff       	call   f0100040 <_panic>
f01029b8:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f01029bf:	00 
f01029c0:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f01029c4:	8b 15 10 2f 22 f0    	mov    0xf0222f10,%edx
f01029ca:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01029cd:	89 44 24 04          	mov    %eax,0x4(%esp)
f01029d1:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f01029d6:	89 04 24             	mov    %eax,(%esp)
f01029d9:	e8 20 ea ff ff       	call   f01013fe <page_insert>
	// (ie. perm = PTE_U | PTE_P).
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f01029de:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f01029e4:	81 fb 00 f0 01 00    	cmp    $0x1f000,%ebx
f01029ea:	0f 85 68 ff ff ff    	jne    f0102958 <mem_init+0x1499>
f01029f0:	e9 26 09 00 00       	jmp    f010331b <mem_init+0x1e5c>
static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f01029f5:	b8 00 50 11 00       	mov    $0x115000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01029fa:	c1 e8 0c             	shr    $0xc,%eax
f01029fd:	39 05 08 2f 22 f0    	cmp    %eax,0xf0222f08
f0102a03:	0f 87 46 09 00 00    	ja     f010334f <mem_init+0x1e90>
f0102a09:	eb 36                	jmp    f0102a41 <mem_init+0x1582>
f0102a0b:	8d 14 33             	lea    (%ebx,%esi,1),%edx
f0102a0e:	89 f0                	mov    %esi,%eax
f0102a10:	c1 e8 0c             	shr    $0xc,%eax
f0102a13:	3b 05 08 2f 22 f0    	cmp    0xf0222f08,%eax
f0102a19:	72 42                	jb     f0102a5d <mem_init+0x159e>
f0102a1b:	eb 24                	jmp    f0102a41 <mem_init+0x1582>

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102a1d:	c7 44 24 0c 00 50 11 	movl   $0xf0115000,0xc(%esp)
f0102a24:	f0 
f0102a25:	c7 44 24 08 c8 63 10 	movl   $0xf01063c8,0x8(%esp)
f0102a2c:	f0 
f0102a2d:	c7 44 24 04 d5 00 00 	movl   $0xd5,0x4(%esp)
f0102a34:	00 
f0102a35:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102a3c:	e8 ff d5 ff ff       	call   f0100040 <_panic>

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
f0102a41:	c7 44 24 08 98 6a 10 	movl   $0xf0106a98,0x8(%esp)
f0102a48:	f0 
f0102a49:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102a50:	00 
f0102a51:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f0102a58:	e8 e3 d5 ff ff       	call   f0100040 <_panic>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		page_insert(kern_pgdir, pa2page(PADDR(bootstack) + i), (void *)(KSTACKTOP-KSTKSIZE + i), PTE_W);
f0102a5d:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102a64:	00 
f0102a65:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102a69:	8b 15 10 2f 22 f0    	mov    0xf0222f10,%edx
f0102a6f:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102a72:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102a76:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0102a7b:	89 04 24             	mov    %eax,(%esp)
f0102a7e:	e8 7b e9 ff ff       	call   f01013fe <page_insert>
f0102a83:	81 c6 00 10 00 00    	add    $0x1000,%esi
	//     * [KSTACKTOP-PTSIZE, KSTACKTOP-KSTKSIZE) -- not backed; so if
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102a89:	81 fe 00 d0 11 00    	cmp    $0x11d000,%esi
f0102a8f:	0f 85 76 ff ff ff    	jne    f0102a0b <mem_init+0x154c>
f0102a95:	e9 97 08 00 00       	jmp    f0103331 <mem_init+0x1e72>
f0102a9a:	8d b3 00 10 00 f0    	lea    -0xffff000(%ebx),%esi
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W);
f0102aa0:	8b 1d 08 2f 22 f0    	mov    0xf0222f08,%ebx
f0102aa6:	89 df                	mov    %ebx,%edi
f0102aa8:	c1 e7 0c             	shl    $0xc,%edi
f0102aab:	89 c8                	mov    %ecx,%eax
f0102aad:	ba 00 00 00 00       	mov    $0x0,%edx
f0102ab2:	f7 f7                	div    %edi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102ab4:	c1 ea 0c             	shr    $0xc,%edx
f0102ab7:	39 d3                	cmp    %edx,%ebx
f0102ab9:	77 1c                	ja     f0102ad7 <mem_init+0x1618>
		panic("pa2page called with invalid pa");
f0102abb:	c7 44 24 08 98 6a 10 	movl   $0xf0106a98,0x8(%esp)
f0102ac2:	f0 
f0102ac3:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102aca:	00 
f0102acb:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f0102ad2:	e8 69 d5 ff ff       	call   f0100040 <_panic>
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
f0102ad7:	89 cb                	mov    %ecx,%ebx
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W);
f0102ad9:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102ae0:	00 
f0102ae1:	89 74 24 08          	mov    %esi,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102ae5:	a1 10 2f 22 f0       	mov    0xf0222f10,%eax
f0102aea:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f0102aed:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102af1:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0102af6:	89 04 24             	mov    %eax,(%esp)
f0102af9:	e8 00 e9 ff ff       	call   f01013fe <page_insert>
		pa2page(i % (npages*PGSIZE))->pp_ref--;                 //this statement is to keep pp_ref == 0 in page_free_list
f0102afe:	8b 0d 08 2f 22 f0    	mov    0xf0222f08,%ecx
f0102b04:	89 ce                	mov    %ecx,%esi
f0102b06:	c1 e6 0c             	shl    $0xc,%esi
f0102b09:	89 d8                	mov    %ebx,%eax
f0102b0b:	ba 00 00 00 00       	mov    $0x0,%edx
f0102b10:	f7 f6                	div    %esi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102b12:	c1 ea 0c             	shr    $0xc,%edx
f0102b15:	39 d1                	cmp    %edx,%ecx
f0102b17:	77 1c                	ja     f0102b35 <mem_init+0x1676>
		panic("pa2page called with invalid pa");
f0102b19:	c7 44 24 08 98 6a 10 	movl   $0xf0106a98,0x8(%esp)
f0102b20:	f0 
f0102b21:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102b28:	00 
f0102b29:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f0102b30:	e8 0b d5 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0102b35:	a1 10 2f 22 f0       	mov    0xf0222f10,%eax
f0102b3a:	66 83 6c d0 04 01    	subw   $0x1,0x4(%eax,%edx,8)
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
f0102b40:	8d 8b 00 10 00 00    	lea    0x1000(%ebx),%ecx
f0102b46:	81 f9 00 00 00 10    	cmp    $0x10000000,%ecx
f0102b4c:	0f 85 48 ff ff ff    	jne    f0102a9a <mem_init+0x15db>
check_kern_pgdir(void)
{
	uint32_t i, n;
	pde_t *pgdir;

	pgdir = kern_pgdir;
f0102b52:	8b 3d 0c 2f 22 f0    	mov    0xf0222f0c,%edi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
f0102b58:	a1 08 2f 22 f0       	mov    0xf0222f08,%eax
f0102b5d:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0102b60:	8d 04 c5 ff 0f 00 00 	lea    0xfff(,%eax,8),%eax
	for (i = 0; i < n; i += PGSIZE)
f0102b67:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102b6c:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0102b6f:	75 30                	jne    f0102ba1 <mem_init+0x16e2>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102b71:	8b 1d 48 22 22 f0    	mov    0xf0222248,%ebx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102b77:	89 de                	mov    %ebx,%esi
f0102b79:	ba 00 00 c0 ee       	mov    $0xeec00000,%edx
f0102b7e:	89 f8                	mov    %edi,%eax
f0102b80:	e8 ff df ff ff       	call   f0100b84 <check_va2pa>
f0102b85:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102b8b:	0f 86 94 00 00 00    	jbe    f0102c25 <mem_init+0x1766>
f0102b91:	bb 00 00 c0 ee       	mov    $0xeec00000,%ebx
f0102b96:	81 c6 00 00 40 21    	add    $0x21400000,%esi
f0102b9c:	e9 a4 00 00 00       	jmp    f0102c45 <mem_init+0x1786>
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102ba1:	8b 1d 10 2f 22 f0    	mov    0xf0222f10,%ebx
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102ba7:	8d b3 00 00 00 10    	lea    0x10000000(%ebx),%esi
f0102bad:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f0102bb2:	89 f8                	mov    %edi,%eax
f0102bb4:	e8 cb df ff ff       	call   f0100b84 <check_va2pa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102bb9:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102bbf:	77 20                	ja     f0102be1 <mem_init+0x1722>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102bc1:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102bc5:	c7 44 24 08 c8 63 10 	movl   $0xf01063c8,0x8(%esp)
f0102bcc:	f0 
f0102bcd:	c7 44 24 04 43 03 00 	movl   $0x343,0x4(%esp)
f0102bd4:	00 
f0102bd5:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102bdc:	e8 5f d4 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102be1:	ba 00 00 00 00       	mov    $0x0,%edx
f0102be6:	8d 0c 16             	lea    (%esi,%edx,1),%ecx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102be9:	39 c8                	cmp    %ecx,%eax
f0102beb:	74 24                	je     f0102c11 <mem_init+0x1752>
f0102bed:	c7 44 24 0c 00 6f 10 	movl   $0xf0106f00,0xc(%esp)
f0102bf4:	f0 
f0102bf5:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102bfc:	f0 
f0102bfd:	c7 44 24 04 43 03 00 	movl   $0x343,0x4(%esp)
f0102c04:	00 
f0102c05:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102c0c:	e8 2f d4 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102c11:	8d 9a 00 10 00 00    	lea    0x1000(%edx),%ebx
f0102c17:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f0102c1a:	0f 87 bc 07 00 00    	ja     f01033dc <mem_init+0x1f1d>
f0102c20:	e9 4c ff ff ff       	jmp    f0102b71 <mem_init+0x16b2>
f0102c25:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102c29:	c7 44 24 08 c8 63 10 	movl   $0xf01063c8,0x8(%esp)
f0102c30:	f0 
f0102c31:	c7 44 24 04 48 03 00 	movl   $0x348,0x4(%esp)
f0102c38:	00 
f0102c39:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102c40:	e8 fb d3 ff ff       	call   f0100040 <_panic>
f0102c45:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102c48:	39 c2                	cmp    %eax,%edx
f0102c4a:	74 24                	je     f0102c70 <mem_init+0x17b1>
f0102c4c:	c7 44 24 0c 34 6f 10 	movl   $0xf0106f34,0xc(%esp)
f0102c53:	f0 
f0102c54:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102c5b:	f0 
f0102c5c:	c7 44 24 04 48 03 00 	movl   $0x348,0x4(%esp)
f0102c63:	00 
f0102c64:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102c6b:	e8 d0 d3 ff ff       	call   f0100040 <_panic>
f0102c70:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102c76:	81 fb 00 f0 c1 ee    	cmp    $0xeec1f000,%ebx
f0102c7c:	0f 85 4c 07 00 00    	jne    f01033ce <mem_init+0x1f0f>
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102c82:	8b 75 d0             	mov    -0x30(%ebp),%esi
f0102c85:	c1 e6 0c             	shl    $0xc,%esi
f0102c88:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102c8d:	85 f6                	test   %esi,%esi
f0102c8f:	75 07                	jne    f0102c98 <mem_init+0x17d9>
f0102c91:	bb 00 00 00 fe       	mov    $0xfe000000,%ebx
f0102c96:	eb 41                	jmp    f0102cd9 <mem_init+0x181a>
f0102c98:	8d 93 00 00 00 f0    	lea    -0x10000000(%ebx),%edx
		assert(check_va2pa(pgdir, KERNBASE + i) == i);
f0102c9e:	89 f8                	mov    %edi,%eax
f0102ca0:	e8 df de ff ff       	call   f0100b84 <check_va2pa>
f0102ca5:	39 c3                	cmp    %eax,%ebx
f0102ca7:	74 24                	je     f0102ccd <mem_init+0x180e>
f0102ca9:	c7 44 24 0c 68 6f 10 	movl   $0xf0106f68,0xc(%esp)
f0102cb0:	f0 
f0102cb1:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102cb8:	f0 
f0102cb9:	c7 44 24 04 4c 03 00 	movl   $0x34c,0x4(%esp)
f0102cc0:	00 
f0102cc1:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102cc8:	e8 73 d3 ff ff       	call   f0100040 <_panic>
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102ccd:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102cd3:	39 f3                	cmp    %esi,%ebx
f0102cd5:	72 c1                	jb     f0102c98 <mem_init+0x17d9>
f0102cd7:	eb b8                	jmp    f0102c91 <mem_init+0x17d2>
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);
f0102cd9:	89 da                	mov    %ebx,%edx
f0102cdb:	89 f8                	mov    %edi,%eax
f0102cdd:	e8 a2 de ff ff       	call   f0100b84 <check_va2pa>
f0102ce2:	39 c3                	cmp    %eax,%ebx
f0102ce4:	74 24                	je     f0102d0a <mem_init+0x184b>
f0102ce6:	c7 44 24 0c c7 73 10 	movl   $0xf01073c7,0xc(%esp)
f0102ced:	f0 
f0102cee:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102cf5:	f0 
f0102cf6:	c7 44 24 04 50 03 00 	movl   $0x350,0x4(%esp)
f0102cfd:	00 
f0102cfe:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102d05:	e8 36 d3 ff ff       	call   f0100040 <_panic>
	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
f0102d0a:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102d10:	81 fb 00 f0 ff ff    	cmp    $0xfffff000,%ebx
f0102d16:	75 c1                	jne    f0102cd9 <mem_init+0x181a>
f0102d18:	c7 45 d0 00 40 22 f0 	movl   $0xf0224000,-0x30(%ebp)
f0102d1f:	c7 45 cc 00 00 00 00 	movl   $0x0,-0x34(%ebp)
f0102d26:	be 00 80 bf ef       	mov    $0xefbf8000,%esi
f0102d2b:	8d 86 00 80 00 00    	lea    0x8000(%esi),%eax
f0102d31:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0102d34:	89 f2                	mov    %esi,%edx
f0102d36:	89 f8                	mov    %edi,%eax
f0102d38:	e8 47 de ff ff       	call   f0100b84 <check_va2pa>
f0102d3d:	8b 4d d0             	mov    -0x30(%ebp),%ecx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102d40:	81 f9 ff ff ff ef    	cmp    $0xefffffff,%ecx
f0102d46:	77 20                	ja     f0102d68 <mem_init+0x18a9>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102d48:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0102d4c:	c7 44 24 08 c8 63 10 	movl   $0xf01063c8,0x8(%esp)
f0102d53:	f0 
f0102d54:	c7 44 24 04 58 03 00 	movl   $0x358,0x4(%esp)
f0102d5b:	00 
f0102d5c:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102d63:	e8 d8 d2 ff ff       	call   f0100040 <_panic>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102d68:	89 f3                	mov    %esi,%ebx
f0102d6a:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0102d6d:	81 c1 00 c0 62 10    	add    $0x1062c000,%ecx
f0102d73:	89 75 c8             	mov    %esi,-0x38(%ebp)
f0102d76:	89 ce                	mov    %ecx,%esi
f0102d78:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
f0102d7b:	39 d0                	cmp    %edx,%eax
f0102d7d:	74 24                	je     f0102da3 <mem_init+0x18e4>
f0102d7f:	c7 44 24 0c 90 6f 10 	movl   $0xf0106f90,0xc(%esp)
f0102d86:	f0 
f0102d87:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102d8e:	f0 
f0102d8f:	c7 44 24 04 58 03 00 	movl   $0x358,0x4(%esp)
f0102d96:	00 
f0102d97:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102d9e:	e8 9d d2 ff ff       	call   f0100040 <_panic>
f0102da3:	81 c3 00 10 00 00    	add    $0x1000,%ebx

	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102da9:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0102dac:	0f 85 0e 06 00 00    	jne    f01033c0 <mem_init+0x1f01>
f0102db2:	8b 75 c8             	mov    -0x38(%ebp),%esi
f0102db5:	8d 9e 00 80 ff ff    	lea    -0x8000(%esi),%ebx
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
f0102dbb:	89 da                	mov    %ebx,%edx
f0102dbd:	89 f8                	mov    %edi,%eax
f0102dbf:	e8 c0 dd ff ff       	call   f0100b84 <check_va2pa>
f0102dc4:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102dc7:	74 24                	je     f0102ded <mem_init+0x192e>
f0102dc9:	c7 44 24 0c d8 6f 10 	movl   $0xf0106fd8,0xc(%esp)
f0102dd0:	f0 
f0102dd1:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102dd8:	f0 
f0102dd9:	c7 44 24 04 5a 03 00 	movl   $0x35a,0x4(%esp)
f0102de0:	00 
f0102de1:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102de8:	e8 53 d2 ff ff       	call   f0100040 <_panic>
f0102ded:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
f0102df3:	39 f3                	cmp    %esi,%ebx
f0102df5:	75 c4                	jne    f0102dbb <mem_init+0x18fc>
f0102df7:	81 ee 00 00 01 00    	sub    $0x10000,%esi
f0102dfd:	81 45 cc 00 80 01 00 	addl   $0x18000,-0x34(%ebp)
f0102e04:	81 45 d0 00 80 00 00 	addl   $0x8000,-0x30(%ebp)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);

	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
f0102e0b:	81 fe 00 80 b7 ef    	cmp    $0xefb78000,%esi
f0102e11:	0f 85 14 ff ff ff    	jne    f0102d2b <mem_init+0x186c>
f0102e17:	b8 00 00 00 00       	mov    $0x0,%eax
			assert(check_va2pa(pgdir, base + i) == ~0);
	}

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
		switch (i) {
f0102e1c:	8d 90 45 fc ff ff    	lea    -0x3bb(%eax),%edx
f0102e22:	83 fa 03             	cmp    $0x3,%edx
f0102e25:	77 2e                	ja     f0102e55 <mem_init+0x1996>
		case PDX(UVPT):
		case PDX(KSTACKTOP-1):
		case PDX(UPAGES):
		case PDX(UENVS):
			assert(pgdir[i] & PTE_P);
f0102e27:	f6 04 87 01          	testb  $0x1,(%edi,%eax,4)
f0102e2b:	0f 85 aa 00 00 00    	jne    f0102edb <mem_init+0x1a1c>
f0102e31:	c7 44 24 0c e2 73 10 	movl   $0xf01073e2,0xc(%esp)
f0102e38:	f0 
f0102e39:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102e40:	f0 
f0102e41:	c7 44 24 04 64 03 00 	movl   $0x364,0x4(%esp)
f0102e48:	00 
f0102e49:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102e50:	e8 eb d1 ff ff       	call   f0100040 <_panic>
			break;
		default:
			if (i >= PDX(KERNBASE)) {
f0102e55:	3d bf 03 00 00       	cmp    $0x3bf,%eax
f0102e5a:	76 55                	jbe    f0102eb1 <mem_init+0x19f2>
				assert(pgdir[i] & PTE_P);
f0102e5c:	8b 14 87             	mov    (%edi,%eax,4),%edx
f0102e5f:	f6 c2 01             	test   $0x1,%dl
f0102e62:	75 24                	jne    f0102e88 <mem_init+0x19c9>
f0102e64:	c7 44 24 0c e2 73 10 	movl   $0xf01073e2,0xc(%esp)
f0102e6b:	f0 
f0102e6c:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102e73:	f0 
f0102e74:	c7 44 24 04 68 03 00 	movl   $0x368,0x4(%esp)
f0102e7b:	00 
f0102e7c:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102e83:	e8 b8 d1 ff ff       	call   f0100040 <_panic>
				assert(pgdir[i] & PTE_W);
f0102e88:	f6 c2 02             	test   $0x2,%dl
f0102e8b:	75 4e                	jne    f0102edb <mem_init+0x1a1c>
f0102e8d:	c7 44 24 0c f3 73 10 	movl   $0xf01073f3,0xc(%esp)
f0102e94:	f0 
f0102e95:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102e9c:	f0 
f0102e9d:	c7 44 24 04 69 03 00 	movl   $0x369,0x4(%esp)
f0102ea4:	00 
f0102ea5:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102eac:	e8 8f d1 ff ff       	call   f0100040 <_panic>
			} else
				assert(pgdir[i] == 0);
f0102eb1:	83 3c 87 00          	cmpl   $0x0,(%edi,%eax,4)
f0102eb5:	74 24                	je     f0102edb <mem_init+0x1a1c>
f0102eb7:	c7 44 24 0c 04 74 10 	movl   $0xf0107404,0xc(%esp)
f0102ebe:	f0 
f0102ebf:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102ec6:	f0 
f0102ec7:	c7 44 24 04 6b 03 00 	movl   $0x36b,0x4(%esp)
f0102ece:	00 
f0102ecf:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102ed6:	e8 65 d1 ff ff       	call   f0100040 <_panic>
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
	}

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
f0102edb:	83 c0 01             	add    $0x1,%eax
f0102ede:	3d 00 04 00 00       	cmp    $0x400,%eax
f0102ee3:	0f 85 33 ff ff ff    	jne    f0102e1c <mem_init+0x195d>
			} else
				assert(pgdir[i] == 0);
			break;
		}
	}
	cprintf("check_kern_pgdir() succeeded!\n");
f0102ee9:	c7 04 24 fc 6f 10 f0 	movl   $0xf0106ffc,(%esp)
f0102ef0:	e8 87 0f 00 00       	call   f0103e7c <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f0102ef5:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0102efa:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102eff:	77 20                	ja     f0102f21 <mem_init+0x1a62>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102f01:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102f05:	c7 44 24 08 c8 63 10 	movl   $0xf01063c8,0x8(%esp)
f0102f0c:	f0 
f0102f0d:	c7 44 24 04 f1 00 00 	movl   $0xf1,0x4(%esp)
f0102f14:	00 
f0102f15:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102f1c:	e8 1f d1 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0102f21:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0102f26:	0f 22 d8             	mov    %eax,%cr3

	check_page_free_list(0);
f0102f29:	b8 00 00 00 00       	mov    $0x0,%eax
f0102f2e:	e8 c0 dc ff ff       	call   f0100bf3 <check_page_free_list>

static __inline uint32_t
rcr0(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr0,%0" : "=r" (val));
f0102f33:	0f 20 c0             	mov    %cr0,%eax

	// entry.S set the really important flags in cr0 (including enabling
	// paging).  Here we configure the rest of the flags that we care about.
	cr0 = rcr0();
	cr0 |= CR0_PE|CR0_PG|CR0_AM|CR0_WP|CR0_NE|CR0_MP;
	cr0 &= ~(CR0_TS|CR0_EM);
f0102f36:	83 e0 f3             	and    $0xfffffff3,%eax
f0102f39:	0d 23 00 05 80       	or     $0x80050023,%eax
}

static __inline void
lcr0(uint32_t val)
{
	__asm __volatile("movl %0,%%cr0" : : "r" (val));
f0102f3e:	0f 22 c0             	mov    %eax,%cr0
	uintptr_t va;
	int i;

	// check that we can read and write installed pages
	pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0102f41:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102f48:	e8 ff e1 ff ff       	call   f010114c <page_alloc>
f0102f4d:	89 c3                	mov    %eax,%ebx
f0102f4f:	85 c0                	test   %eax,%eax
f0102f51:	75 24                	jne    f0102f77 <mem_init+0x1ab8>
f0102f53:	c7 44 24 0c 06 72 10 	movl   $0xf0107206,0xc(%esp)
f0102f5a:	f0 
f0102f5b:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102f62:	f0 
f0102f63:	c7 44 24 04 21 04 00 	movl   $0x421,0x4(%esp)
f0102f6a:	00 
f0102f6b:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102f72:	e8 c9 d0 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0102f77:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102f7e:	e8 c9 e1 ff ff       	call   f010114c <page_alloc>
f0102f83:	89 c7                	mov    %eax,%edi
f0102f85:	85 c0                	test   %eax,%eax
f0102f87:	75 24                	jne    f0102fad <mem_init+0x1aee>
f0102f89:	c7 44 24 0c 1c 72 10 	movl   $0xf010721c,0xc(%esp)
f0102f90:	f0 
f0102f91:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102f98:	f0 
f0102f99:	c7 44 24 04 22 04 00 	movl   $0x422,0x4(%esp)
f0102fa0:	00 
f0102fa1:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102fa8:	e8 93 d0 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0102fad:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102fb4:	e8 93 e1 ff ff       	call   f010114c <page_alloc>
f0102fb9:	89 c6                	mov    %eax,%esi
f0102fbb:	85 c0                	test   %eax,%eax
f0102fbd:	75 24                	jne    f0102fe3 <mem_init+0x1b24>
f0102fbf:	c7 44 24 0c 32 72 10 	movl   $0xf0107232,0xc(%esp)
f0102fc6:	f0 
f0102fc7:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0102fce:	f0 
f0102fcf:	c7 44 24 04 23 04 00 	movl   $0x423,0x4(%esp)
f0102fd6:	00 
f0102fd7:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0102fde:	e8 5d d0 ff ff       	call   f0100040 <_panic>
	page_free(pp0);
f0102fe3:	89 1c 24             	mov    %ebx,(%esp)
f0102fe6:	e8 e6 e1 ff ff       	call   f01011d1 <page_free>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102feb:	89 f8                	mov    %edi,%eax
f0102fed:	2b 05 10 2f 22 f0    	sub    0xf0222f10,%eax
f0102ff3:	c1 f8 03             	sar    $0x3,%eax
f0102ff6:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102ff9:	89 c2                	mov    %eax,%edx
f0102ffb:	c1 ea 0c             	shr    $0xc,%edx
f0102ffe:	3b 15 08 2f 22 f0    	cmp    0xf0222f08,%edx
f0103004:	72 20                	jb     f0103026 <mem_init+0x1b67>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103006:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010300a:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f0103011:	f0 
f0103012:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103019:	00 
f010301a:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f0103021:	e8 1a d0 ff ff       	call   f0100040 <_panic>
	memset(page2kva(pp1), 1, PGSIZE);
f0103026:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010302d:	00 
f010302e:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f0103035:	00 
	return (void *)(pa + KERNBASE);
f0103036:	2d 00 00 00 10       	sub    $0x10000000,%eax
f010303b:	89 04 24             	mov    %eax,(%esp)
f010303e:	e8 96 25 00 00       	call   f01055d9 <memset>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103043:	89 f0                	mov    %esi,%eax
f0103045:	2b 05 10 2f 22 f0    	sub    0xf0222f10,%eax
f010304b:	c1 f8 03             	sar    $0x3,%eax
f010304e:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103051:	89 c2                	mov    %eax,%edx
f0103053:	c1 ea 0c             	shr    $0xc,%edx
f0103056:	3b 15 08 2f 22 f0    	cmp    0xf0222f08,%edx
f010305c:	72 20                	jb     f010307e <mem_init+0x1bbf>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010305e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103062:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f0103069:	f0 
f010306a:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103071:	00 
f0103072:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f0103079:	e8 c2 cf ff ff       	call   f0100040 <_panic>
	memset(page2kva(pp2), 2, PGSIZE);
f010307e:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0103085:	00 
f0103086:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f010308d:	00 
	return (void *)(pa + KERNBASE);
f010308e:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0103093:	89 04 24             	mov    %eax,(%esp)
f0103096:	e8 3e 25 00 00       	call   f01055d9 <memset>
	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f010309b:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01030a2:	00 
f01030a3:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01030aa:	00 
f01030ab:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01030af:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f01030b4:	89 04 24             	mov    %eax,(%esp)
f01030b7:	e8 42 e3 ff ff       	call   f01013fe <page_insert>
	assert(pp1->pp_ref == 1);
f01030bc:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f01030c1:	74 24                	je     f01030e7 <mem_init+0x1c28>
f01030c3:	c7 44 24 0c 03 73 10 	movl   $0xf0107303,0xc(%esp)
f01030ca:	f0 
f01030cb:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01030d2:	f0 
f01030d3:	c7 44 24 04 28 04 00 	movl   $0x428,0x4(%esp)
f01030da:	00 
f01030db:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01030e2:	e8 59 cf ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
f01030e7:	81 3d 00 10 00 00 01 	cmpl   $0x1010101,0x1000
f01030ee:	01 01 01 
f01030f1:	74 24                	je     f0103117 <mem_init+0x1c58>
f01030f3:	c7 44 24 0c 1c 70 10 	movl   $0xf010701c,0xc(%esp)
f01030fa:	f0 
f01030fb:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0103102:	f0 
f0103103:	c7 44 24 04 29 04 00 	movl   $0x429,0x4(%esp)
f010310a:	00 
f010310b:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0103112:	e8 29 cf ff ff       	call   f0100040 <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f0103117:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f010311e:	00 
f010311f:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0103126:	00 
f0103127:	89 74 24 04          	mov    %esi,0x4(%esp)
f010312b:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0103130:	89 04 24             	mov    %eax,(%esp)
f0103133:	e8 c6 e2 ff ff       	call   f01013fe <page_insert>
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
f0103138:	81 3d 00 10 00 00 02 	cmpl   $0x2020202,0x1000
f010313f:	02 02 02 
f0103142:	74 24                	je     f0103168 <mem_init+0x1ca9>
f0103144:	c7 44 24 0c 40 70 10 	movl   $0xf0107040,0xc(%esp)
f010314b:	f0 
f010314c:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f0103153:	f0 
f0103154:	c7 44 24 04 2b 04 00 	movl   $0x42b,0x4(%esp)
f010315b:	00 
f010315c:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f0103163:	e8 d8 ce ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0103168:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f010316d:	74 24                	je     f0103193 <mem_init+0x1cd4>
f010316f:	c7 44 24 0c 25 73 10 	movl   $0xf0107325,0xc(%esp)
f0103176:	f0 
f0103177:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010317e:	f0 
f010317f:	c7 44 24 04 2c 04 00 	movl   $0x42c,0x4(%esp)
f0103186:	00 
f0103187:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010318e:	e8 ad ce ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f0103193:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f0103198:	74 24                	je     f01031be <mem_init+0x1cff>
f010319a:	c7 44 24 0c 6e 73 10 	movl   $0xf010736e,0xc(%esp)
f01031a1:	f0 
f01031a2:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01031a9:	f0 
f01031aa:	c7 44 24 04 2d 04 00 	movl   $0x42d,0x4(%esp)
f01031b1:	00 
f01031b2:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01031b9:	e8 82 ce ff ff       	call   f0100040 <_panic>
	*(uint32_t *)PGSIZE = 0x03030303U;
f01031be:	c7 05 00 10 00 00 03 	movl   $0x3030303,0x1000
f01031c5:	03 03 03 
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01031c8:	89 f0                	mov    %esi,%eax
f01031ca:	2b 05 10 2f 22 f0    	sub    0xf0222f10,%eax
f01031d0:	c1 f8 03             	sar    $0x3,%eax
f01031d3:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01031d6:	89 c2                	mov    %eax,%edx
f01031d8:	c1 ea 0c             	shr    $0xc,%edx
f01031db:	3b 15 08 2f 22 f0    	cmp    0xf0222f08,%edx
f01031e1:	72 20                	jb     f0103203 <mem_init+0x1d44>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01031e3:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01031e7:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f01031ee:	f0 
f01031ef:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01031f6:	00 
f01031f7:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f01031fe:	e8 3d ce ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
f0103203:	81 b8 00 00 00 f0 03 	cmpl   $0x3030303,-0x10000000(%eax)
f010320a:	03 03 03 
f010320d:	74 24                	je     f0103233 <mem_init+0x1d74>
f010320f:	c7 44 24 0c 64 70 10 	movl   $0xf0107064,0xc(%esp)
f0103216:	f0 
f0103217:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010321e:	f0 
f010321f:	c7 44 24 04 2f 04 00 	movl   $0x42f,0x4(%esp)
f0103226:	00 
f0103227:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010322e:	e8 0d ce ff ff       	call   f0100040 <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f0103233:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f010323a:	00 
f010323b:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0103240:	89 04 24             	mov    %eax,(%esp)
f0103243:	e8 6d e1 ff ff       	call   f01013b5 <page_remove>
	assert(pp2->pp_ref == 0);
f0103248:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f010324d:	74 24                	je     f0103273 <mem_init+0x1db4>
f010324f:	c7 44 24 0c 5d 73 10 	movl   $0xf010735d,0xc(%esp)
f0103256:	f0 
f0103257:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010325e:	f0 
f010325f:	c7 44 24 04 31 04 00 	movl   $0x431,0x4(%esp)
f0103266:	00 
f0103267:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f010326e:	e8 cd cd ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0103273:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0103278:	8b 08                	mov    (%eax),%ecx
f010327a:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103280:	89 da                	mov    %ebx,%edx
f0103282:	2b 15 10 2f 22 f0    	sub    0xf0222f10,%edx
f0103288:	c1 fa 03             	sar    $0x3,%edx
f010328b:	c1 e2 0c             	shl    $0xc,%edx
f010328e:	39 d1                	cmp    %edx,%ecx
f0103290:	74 24                	je     f01032b6 <mem_init+0x1df7>
f0103292:	c7 44 24 0c ec 6b 10 	movl   $0xf0106bec,0xc(%esp)
f0103299:	f0 
f010329a:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01032a1:	f0 
f01032a2:	c7 44 24 04 34 04 00 	movl   $0x434,0x4(%esp)
f01032a9:	00 
f01032aa:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01032b1:	e8 8a cd ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f01032b6:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f01032bc:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f01032c1:	74 24                	je     f01032e7 <mem_init+0x1e28>
f01032c3:	c7 44 24 0c 14 73 10 	movl   $0xf0107314,0xc(%esp)
f01032ca:	f0 
f01032cb:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01032d2:	f0 
f01032d3:	c7 44 24 04 36 04 00 	movl   $0x436,0x4(%esp)
f01032da:	00 
f01032db:	c7 04 24 f1 70 10 f0 	movl   $0xf01070f1,(%esp)
f01032e2:	e8 59 cd ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f01032e7:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// free the pages we took
	page_free(pp0);
f01032ed:	89 1c 24             	mov    %ebx,(%esp)
f01032f0:	e8 dc de ff ff       	call   f01011d1 <page_free>

	cprintf("check_page_installed_pgdir() succeeded!\n");
f01032f5:	c7 04 24 90 70 10 f0 	movl   $0xf0107090,(%esp)
f01032fc:	e8 7b 0b 00 00       	call   f0103e7c <cprintf>
f0103301:	e9 ea 00 00 00       	jmp    f01033f0 <mem_init+0x1f31>
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		page_insert(kern_pgdir,pa2page(PADDR(envs)+i),(void *)(UENVS + i),PTE_U);
f0103306:	a1 48 22 22 f0       	mov    0xf0222248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010330b:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103310:	0f 87 2c f6 ff ff    	ja     f0102942 <mem_init+0x1483>
f0103316:	e9 4f f6 ff ff       	jmp    f010296a <mem_init+0x14ab>
f010331b:	bb 00 50 11 f0       	mov    $0xf0115000,%ebx
f0103320:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0103326:	0f 86 f1 f6 ff ff    	jbe    f0102a1d <mem_init+0x155e>
f010332c:	e9 c4 f6 ff ff       	jmp    f01029f5 <mem_init+0x1536>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103331:	83 3d 08 2f 22 f0 00 	cmpl   $0x0,0xf0222f08
f0103338:	0f 84 7d f7 ff ff    	je     f0102abb <mem_init+0x15fc>
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W);
f010333e:	be 00 00 00 f0       	mov    $0xf0000000,%esi
f0103343:	bb 00 00 00 00       	mov    $0x0,%ebx
f0103348:	89 fa                	mov    %edi,%edx
f010334a:	e9 8a f7 ff ff       	jmp    f0102ad9 <mem_init+0x161a>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		page_insert(kern_pgdir, pa2page(PADDR(bootstack) + i), (void *)(KSTACKTOP-KSTKSIZE + i), PTE_W);
f010334f:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0103356:	00 
f0103357:	c7 44 24 08 00 80 bf 	movl   $0xefbf8000,0x8(%esp)
f010335e:	ef 
		panic("pa2page called with invalid pa");
	return &pages[PGNUM(pa)];
f010335f:	8b 15 10 2f 22 f0    	mov    0xf0222f10,%edx
f0103365:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0103368:	89 44 24 04          	mov    %eax,0x4(%esp)
f010336c:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f0103371:	89 04 24             	mov    %eax,(%esp)
f0103374:	e8 85 e0 ff ff       	call   f01013fe <page_insert>
f0103379:	be 00 60 11 00       	mov    $0x116000,%esi
f010337e:	b8 00 80 bf df       	mov    $0xdfbf8000,%eax
f0103383:	29 d8                	sub    %ebx,%eax
f0103385:	89 c3                	mov    %eax,%ebx
f0103387:	e9 7f f6 ff ff       	jmp    f0102a0b <mem_init+0x154c>
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		page_insert(kern_pgdir,pa2page(PADDR(envs)+i),(void *)(UENVS + i),PTE_U);
f010338c:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f0103393:	00 
f0103394:	c7 44 24 08 00 00 c0 	movl   $0xeec00000,0x8(%esp)
f010339b:	ee 
f010339c:	8b 15 10 2f 22 f0    	mov    0xf0222f10,%edx
f01033a2:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01033a5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01033a9:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
f01033ae:	89 04 24             	mov    %eax,(%esp)
f01033b1:	e8 48 e0 ff ff       	call   f01013fe <page_insert>
	// (ie. perm = PTE_U | PTE_P).
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f01033b6:	bb 00 10 00 00       	mov    $0x1000,%ebx
f01033bb:	e9 98 f5 ff ff       	jmp    f0102958 <mem_init+0x1499>
	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f01033c0:	89 da                	mov    %ebx,%edx
f01033c2:	89 f8                	mov    %edi,%eax
f01033c4:	e8 bb d7 ff ff       	call   f0100b84 <check_va2pa>
f01033c9:	e9 aa f9 ff ff       	jmp    f0102d78 <mem_init+0x18b9>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f01033ce:	89 da                	mov    %ebx,%edx
f01033d0:	89 f8                	mov    %edi,%eax
f01033d2:	e8 ad d7 ff ff       	call   f0100b84 <check_va2pa>
f01033d7:	e9 69 f8 ff ff       	jmp    f0102c45 <mem_init+0x1786>
f01033dc:	81 ea 00 f0 ff 10    	sub    $0x10fff000,%edx
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f01033e2:	89 f8                	mov    %edi,%eax
f01033e4:	e8 9b d7 ff ff       	call   f0100b84 <check_va2pa>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f01033e9:	89 da                	mov    %ebx,%edx
f01033eb:	e9 f6 f7 ff ff       	jmp    f0102be6 <mem_init+0x1727>
	cr0 &= ~(CR0_TS|CR0_EM);
	lcr0(cr0);

	// Some more checks, only possible after kern_pgdir is installed.
	check_page_installed_pgdir();
}
f01033f0:	83 c4 3c             	add    $0x3c,%esp
f01033f3:	5b                   	pop    %ebx
f01033f4:	5e                   	pop    %esi
f01033f5:	5f                   	pop    %edi
f01033f6:	5d                   	pop    %ebp
f01033f7:	c3                   	ret    

f01033f8 <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f01033f8:	55                   	push   %ebp
f01033f9:	89 e5                	mov    %esp,%ebp
f01033fb:	57                   	push   %edi
f01033fc:	56                   	push   %esi
f01033fd:	53                   	push   %ebx
f01033fe:	83 ec 3c             	sub    $0x3c,%esp
f0103401:	8b 7d 08             	mov    0x8(%ebp),%edi
f0103404:	8b 45 0c             	mov    0xc(%ebp),%eax

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
f0103407:	89 c2                	mov    %eax,%edx
f0103409:	03 55 10             	add    0x10(%ebp),%edx
f010340c:	89 55 d0             	mov    %edx,-0x30(%ebp)
f010340f:	39 d0                	cmp    %edx,%eax
f0103411:	73 70                	jae    f0103483 <user_mem_check+0x8b>
f0103413:	89 c3                	mov    %eax,%ebx
f0103415:	89 c6                	mov    %eax,%esi
		pte_t* store=0;
		struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
		if(store!=NULL)
		{
			//cprintf("pte!=NULL %08x\r\n",*store);
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f0103417:	8b 45 14             	mov    0x14(%ebp),%eax
f010341a:	83 c8 01             	or     $0x1,%eax
f010341d:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
	{
		pte_t* store=0;
f0103420:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
		struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
f0103427:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f010342a:	89 44 24 08          	mov    %eax,0x8(%esp)
f010342e:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103432:	8b 47 60             	mov    0x60(%edi),%eax
f0103435:	89 04 24             	mov    %eax,(%esp)
f0103438:	e8 d6 de ff ff       	call   f0101313 <page_lookup>
		if(store!=NULL)
f010343d:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103440:	85 c0                	test   %eax,%eax
f0103442:	74 1b                	je     f010345f <user_mem_check+0x67>
		{
			//cprintf("pte!=NULL %08x\r\n",*store);
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f0103444:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0103447:	89 ca                	mov    %ecx,%edx
f0103449:	23 10                	and    (%eax),%edx
f010344b:	39 d1                	cmp    %edx,%ecx
f010344d:	75 08                	jne    f0103457 <user_mem_check+0x5f>
f010344f:	81 fe 00 00 80 ef    	cmp    $0xef800000,%esi
f0103455:	76 10                	jbe    f0103467 <user_mem_check+0x6f>
			   {
				//cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f0103457:	89 35 3c 22 22 f0    	mov    %esi,0xf022223c
				break;
f010345d:	eb 1d                	jmp    f010347c <user_mem_check+0x84>
			}
			else
			{
				//cprintf("no pte!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f010345f:	89 35 3c 22 22 f0    	mov    %esi,0xf022223c
				break;
f0103465:	eb 15                	jmp    f010347c <user_mem_check+0x84>
			}
		    i=ROUNDDOWN(i,PGSIZE);
f0103467:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
f010346d:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0103473:	89 de                	mov    %ebx,%esi
f0103475:	3b 5d d0             	cmp    -0x30(%ebp),%ebx
f0103478:	72 a6                	jb     f0103420 <user_mem_check+0x28>
f010347a:	eb 0e                	jmp    f010348a <user_mem_check+0x92>
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
			   {
				//cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
				break;
f010347c:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f0103481:	eb 0c                	jmp    f010348f <user_mem_check+0x97>
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
f0103483:	b8 00 00 00 00       	mov    $0x0,%eax
f0103488:	eb 05                	jmp    f010348f <user_mem_check+0x97>
f010348a:	b8 00 00 00 00       	mov    $0x0,%eax
			}
		    i=ROUNDDOWN(i,PGSIZE);
		}

	return flag;
}
f010348f:	83 c4 3c             	add    $0x3c,%esp
f0103492:	5b                   	pop    %ebx
f0103493:	5e                   	pop    %esi
f0103494:	5f                   	pop    %edi
f0103495:	5d                   	pop    %ebp
f0103496:	c3                   	ret    

f0103497 <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f0103497:	55                   	push   %ebp
f0103498:	89 e5                	mov    %esp,%ebp
f010349a:	53                   	push   %ebx
f010349b:	83 ec 14             	sub    $0x14,%esp
f010349e:	8b 5d 08             	mov    0x8(%ebp),%ebx
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
f01034a1:	8b 45 14             	mov    0x14(%ebp),%eax
f01034a4:	83 c8 04             	or     $0x4,%eax
f01034a7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01034ab:	8b 45 10             	mov    0x10(%ebp),%eax
f01034ae:	89 44 24 08          	mov    %eax,0x8(%esp)
f01034b2:	8b 45 0c             	mov    0xc(%ebp),%eax
f01034b5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01034b9:	89 1c 24             	mov    %ebx,(%esp)
f01034bc:	e8 37 ff ff ff       	call   f01033f8 <user_mem_check>
f01034c1:	85 c0                	test   %eax,%eax
f01034c3:	79 24                	jns    f01034e9 <user_mem_assert+0x52>
		cprintf(".%08x. user_mem_check assertion failure for "
f01034c5:	a1 3c 22 22 f0       	mov    0xf022223c,%eax
f01034ca:	89 44 24 08          	mov    %eax,0x8(%esp)
f01034ce:	8b 43 48             	mov    0x48(%ebx),%eax
f01034d1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01034d5:	c7 04 24 bc 70 10 f0 	movl   $0xf01070bc,(%esp)
f01034dc:	e8 9b 09 00 00       	call   f0103e7c <cprintf>
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
f01034e1:	89 1c 24             	mov    %ebx,(%esp)
f01034e4:	e8 ef 06 00 00       	call   f0103bd8 <env_destroy>
	}
}
f01034e9:	83 c4 14             	add    $0x14,%esp
f01034ec:	5b                   	pop    %ebx
f01034ed:	5d                   	pop    %ebp
f01034ee:	c3                   	ret    

f01034ef <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f01034ef:	55                   	push   %ebp
f01034f0:	89 e5                	mov    %esp,%ebp
f01034f2:	56                   	push   %esi
f01034f3:	53                   	push   %ebx
f01034f4:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f01034f7:	85 c0                	test   %eax,%eax
f01034f9:	75 1a                	jne    f0103515 <envid2env+0x26>
		*env_store = curenv;
f01034fb:	e8 73 27 00 00       	call   f0105c73 <cpunum>
f0103500:	6b c0 74             	imul   $0x74,%eax,%eax
f0103503:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f0103509:	8b 55 0c             	mov    0xc(%ebp),%edx
f010350c:	89 02                	mov    %eax,(%edx)
		return 0;
f010350e:	b8 00 00 00 00       	mov    $0x0,%eax
f0103513:	eb 72                	jmp    f0103587 <envid2env+0x98>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f0103515:	89 c3                	mov    %eax,%ebx
f0103517:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
f010351d:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f0103520:	03 1d 48 22 22 f0    	add    0xf0222248,%ebx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f0103526:	83 7b 54 00          	cmpl   $0x0,0x54(%ebx)
f010352a:	74 05                	je     f0103531 <envid2env+0x42>
f010352c:	39 43 48             	cmp    %eax,0x48(%ebx)
f010352f:	74 10                	je     f0103541 <envid2env+0x52>
		*env_store = 0;
f0103531:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103534:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f010353a:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f010353f:	eb 46                	jmp    f0103587 <envid2env+0x98>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f0103541:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f0103545:	74 36                	je     f010357d <envid2env+0x8e>
f0103547:	e8 27 27 00 00       	call   f0105c73 <cpunum>
f010354c:	6b c0 74             	imul   $0x74,%eax,%eax
f010354f:	39 98 28 30 22 f0    	cmp    %ebx,-0xfddcfd8(%eax)
f0103555:	74 26                	je     f010357d <envid2env+0x8e>
f0103557:	8b 73 4c             	mov    0x4c(%ebx),%esi
f010355a:	e8 14 27 00 00       	call   f0105c73 <cpunum>
f010355f:	6b c0 74             	imul   $0x74,%eax,%eax
f0103562:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f0103568:	3b 70 48             	cmp    0x48(%eax),%esi
f010356b:	74 10                	je     f010357d <envid2env+0x8e>
		*env_store = 0;
f010356d:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103570:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f0103576:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f010357b:	eb 0a                	jmp    f0103587 <envid2env+0x98>
	}

	*env_store = e;
f010357d:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103580:	89 18                	mov    %ebx,(%eax)
	return 0;
f0103582:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0103587:	5b                   	pop    %ebx
f0103588:	5e                   	pop    %esi
f0103589:	5d                   	pop    %ebp
f010358a:	c3                   	ret    

f010358b <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f010358b:	55                   	push   %ebp
f010358c:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f010358e:	b8 00 f3 11 f0       	mov    $0xf011f300,%eax
f0103593:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f0103596:	b8 23 00 00 00       	mov    $0x23,%eax
f010359b:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f010359d:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f010359f:	b0 10                	mov    $0x10,%al
f01035a1:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f01035a3:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f01035a5:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f01035a7:	ea ae 35 10 f0 08 00 	ljmp   $0x8,$0xf01035ae
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f01035ae:	b0 00                	mov    $0x0,%al
f01035b0:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f01035b3:	5d                   	pop    %ebp
f01035b4:	c3                   	ret    

f01035b5 <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f01035b5:	55                   	push   %ebp
f01035b6:	89 e5                	mov    %esp,%ebp
f01035b8:	53                   	push   %ebx
f01035b9:	8b 0d 4c 22 22 f0    	mov    0xf022224c,%ecx
f01035bf:	a1 48 22 22 f0       	mov    0xf0222248,%eax
	// Set up envs array
	// LAB 3: Your code here.
	size_t i;
	for (i = 0; i < NENV; i++) {
		envs[i].env_id = 0;
f01035c4:	ba 00 04 00 00       	mov    $0x400,%edx
f01035c9:	89 c3                	mov    %eax,%ebx
f01035cb:	c7 40 48 00 00 00 00 	movl   $0x0,0x48(%eax)
		envs[i].env_link = env_free_list;
f01035d2:	89 48 44             	mov    %ecx,0x44(%eax)
f01035d5:	83 c0 7c             	add    $0x7c,%eax
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
	size_t i;
	for (i = 0; i < NENV; i++) {
f01035d8:	83 ea 01             	sub    $0x1,%edx
f01035db:	74 04                	je     f01035e1 <env_init+0x2c>
		envs[i].env_id = 0;
		envs[i].env_link = env_free_list;
		env_free_list = &envs[i];
f01035dd:	89 d9                	mov    %ebx,%ecx
f01035df:	eb e8                	jmp    f01035c9 <env_init+0x14>
	}
	env_free_list = envs; // this line of code changing like this ugly looks just fit fuck grade sh,too useless
f01035e1:	a1 48 22 22 f0       	mov    0xf0222248,%eax
f01035e6:	a3 4c 22 22 f0       	mov    %eax,0xf022224c
	// Per-CPU part of the initialization
	env_init_percpu();
f01035eb:	e8 9b ff ff ff       	call   f010358b <env_init_percpu>
}
f01035f0:	5b                   	pop    %ebx
f01035f1:	5d                   	pop    %ebp
f01035f2:	c3                   	ret    

f01035f3 <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f01035f3:	55                   	push   %ebp
f01035f4:	89 e5                	mov    %esp,%ebp
f01035f6:	56                   	push   %esi
f01035f7:	53                   	push   %ebx
f01035f8:	83 ec 10             	sub    $0x10,%esp
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
f01035fb:	8b 1d 4c 22 22 f0    	mov    0xf022224c,%ebx
f0103601:	85 db                	test   %ebx,%ebx
f0103603:	0f 84 92 01 00 00    	je     f010379b <env_alloc+0x1a8>
{
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f0103609:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0103610:	e8 37 db ff ff       	call   f010114c <page_alloc>
f0103615:	85 c0                	test   %eax,%eax
f0103617:	0f 84 85 01 00 00    	je     f01037a2 <env_alloc+0x1af>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010361d:	89 c2                	mov    %eax,%edx
f010361f:	2b 15 10 2f 22 f0    	sub    0xf0222f10,%edx
f0103625:	c1 fa 03             	sar    $0x3,%edx
f0103628:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010362b:	89 d1                	mov    %edx,%ecx
f010362d:	c1 e9 0c             	shr    $0xc,%ecx
f0103630:	3b 0d 08 2f 22 f0    	cmp    0xf0222f08,%ecx
f0103636:	72 20                	jb     f0103658 <env_alloc+0x65>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103638:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010363c:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f0103643:	f0 
f0103644:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010364b:	00 
f010364c:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f0103653:	e8 e8 c9 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0103658:	81 ea 00 00 00 10    	sub    $0x10000000,%edx
f010365e:	89 53 60             	mov    %edx,0x60(%ebx)
	//	is an exception -- you need to increment env_pgdir's
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
f0103661:	ba ec 0e 00 00       	mov    $0xeec,%edx
	for(i=PDX(UTOP);i<1024;i++){
		e->env_pgdir[i] = kern_pgdir[i];
f0103666:	8b 0d 0c 2f 22 f0    	mov    0xf0222f0c,%ecx
f010366c:	8b 34 11             	mov    (%ecx,%edx,1),%esi
f010366f:	8b 4b 60             	mov    0x60(%ebx),%ecx
f0103672:	89 34 11             	mov    %esi,(%ecx,%edx,1)
f0103675:	83 c2 04             	add    $0x4,%edx
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
	for(i=PDX(UTOP);i<1024;i++){
f0103678:	81 fa 00 10 00 00    	cmp    $0x1000,%edx
f010367e:	75 e6                	jne    f0103666 <env_alloc+0x73>
		e->env_pgdir[i] = kern_pgdir[i];
	}
	p->pp_ref++;
f0103680:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f0103685:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103688:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010368d:	77 20                	ja     f01036af <env_alloc+0xbc>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010368f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103693:	c7 44 24 08 c8 63 10 	movl   $0xf01063c8,0x8(%esp)
f010369a:	f0 
f010369b:	c7 44 24 04 c6 00 00 	movl   $0xc6,0x4(%esp)
f01036a2:	00 
f01036a3:	c7 04 24 12 74 10 f0 	movl   $0xf0107412,(%esp)
f01036aa:	e8 91 c9 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01036af:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f01036b5:	83 ca 05             	or     $0x5,%edx
f01036b8:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate and set up the page directory for this environment.
	if ((r = env_setup_vm(e)) < 0)
		return r;

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f01036be:	8b 43 48             	mov    0x48(%ebx),%eax
f01036c1:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f01036c6:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f01036cb:	ba 00 10 00 00       	mov    $0x1000,%edx
f01036d0:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f01036d3:	89 da                	mov    %ebx,%edx
f01036d5:	2b 15 48 22 22 f0    	sub    0xf0222248,%edx
f01036db:	c1 fa 02             	sar    $0x2,%edx
f01036de:	69 d2 df 7b ef bd    	imul   $0xbdef7bdf,%edx,%edx
f01036e4:	09 d0                	or     %edx,%eax
f01036e6:	89 43 48             	mov    %eax,0x48(%ebx)

	// Set the basic status variables.
	e->env_parent_id = parent_id;
f01036e9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01036ec:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f01036ef:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f01036f6:	c7 43 54 02 00 00 00 	movl   $0x2,0x54(%ebx)
	e->env_runs = 0;
f01036fd:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f0103704:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f010370b:	00 
f010370c:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0103713:	00 
f0103714:	89 1c 24             	mov    %ebx,(%esp)
f0103717:	e8 bd 1e 00 00       	call   f01055d9 <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f010371c:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f0103722:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f0103728:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f010372e:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f0103735:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)

	// Enable interrupts while in user mode.
	// LAB 4: Your code here.

	// Clear the page fault handler until user installs one.
	e->env_pgfault_upcall = 0;
f010373b:	c7 43 64 00 00 00 00 	movl   $0x0,0x64(%ebx)

	// Also clear the IPC receiving flag.
	e->env_ipc_recving = 0;
f0103742:	c7 43 68 00 00 00 00 	movl   $0x0,0x68(%ebx)

	// commit the allocation
	env_free_list = e->env_link;
f0103749:	8b 43 44             	mov    0x44(%ebx),%eax
f010374c:	a3 4c 22 22 f0       	mov    %eax,0xf022224c
	*newenv_store = e;
f0103751:	8b 45 08             	mov    0x8(%ebp),%eax
f0103754:	89 18                	mov    %ebx,(%eax)

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0103756:	8b 5b 48             	mov    0x48(%ebx),%ebx
f0103759:	e8 15 25 00 00       	call   f0105c73 <cpunum>
f010375e:	6b d0 74             	imul   $0x74,%eax,%edx
f0103761:	b8 00 00 00 00       	mov    $0x0,%eax
f0103766:	83 ba 28 30 22 f0 00 	cmpl   $0x0,-0xfddcfd8(%edx)
f010376d:	74 11                	je     f0103780 <env_alloc+0x18d>
f010376f:	e8 ff 24 00 00       	call   f0105c73 <cpunum>
f0103774:	6b c0 74             	imul   $0x74,%eax,%eax
f0103777:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f010377d:	8b 40 48             	mov    0x48(%eax),%eax
f0103780:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103784:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103788:	c7 04 24 1d 74 10 f0 	movl   $0xf010741d,(%esp)
f010378f:	e8 e8 06 00 00       	call   f0103e7c <cprintf>
	return 0;
f0103794:	b8 00 00 00 00       	mov    $0x0,%eax
f0103799:	eb 0c                	jmp    f01037a7 <env_alloc+0x1b4>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
		return -E_NO_FREE_ENV;
f010379b:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f01037a0:	eb 05                	jmp    f01037a7 <env_alloc+0x1b4>
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f01037a2:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	env_free_list = e->env_link;
	*newenv_store = e;

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}
f01037a7:	83 c4 10             	add    $0x10,%esp
f01037aa:	5b                   	pop    %ebx
f01037ab:	5e                   	pop    %esi
f01037ac:	5d                   	pop    %ebp
f01037ad:	c3                   	ret    

f01037ae <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f01037ae:	55                   	push   %ebp
f01037af:	89 e5                	mov    %esp,%ebp
f01037b1:	57                   	push   %edi
f01037b2:	56                   	push   %esi
f01037b3:	53                   	push   %ebx
f01037b4:	83 ec 3c             	sub    $0x3c,%esp
	// LAB 3: Your code here.
	struct Env * env;
	if(env_alloc(&env,0)==0){
f01037b7:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01037be:	00 
f01037bf:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f01037c2:	89 04 24             	mov    %eax,(%esp)
f01037c5:	e8 29 fe ff ff       	call   f01035f3 <env_alloc>
f01037ca:	85 c0                	test   %eax,%eax
f01037cc:	0f 85 dd 01 00 00    	jne    f01039af <env_create+0x201>
		load_icode(env,binary,size);
f01037d2:	8b 7d e4             	mov    -0x1c(%ebp),%edi
	//  You must also do something with the program's entry point,
	//  to make sure that the environment starts executing there.
	//  What?  (See env_run() and env_pop_tf() below.)

	// LAB 3: Your code here.
	lcr3(PADDR(e->env_pgdir));
f01037d5:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01037d8:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01037dd:	77 20                	ja     f01037ff <env_create+0x51>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01037df:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01037e3:	c7 44 24 08 c8 63 10 	movl   $0xf01063c8,0x8(%esp)
f01037ea:	f0 
f01037eb:	c7 44 24 04 64 01 00 	movl   $0x164,0x4(%esp)
f01037f2:	00 
f01037f3:	c7 04 24 12 74 10 f0 	movl   $0xf0107412,(%esp)
f01037fa:	e8 41 c8 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01037ff:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0103804:	0f 22 d8             	mov    %eax,%cr3
	struct Elf* ELFHDR = (struct Elf *) binary;
	if(ELFHDR->e_magic != ELF_MAGIC)
f0103807:	8b 45 08             	mov    0x8(%ebp),%eax
f010380a:	81 38 7f 45 4c 46    	cmpl   $0x464c457f,(%eax)
f0103810:	74 1c                	je     f010382e <env_create+0x80>
		panic("Invalid ELF format !");
f0103812:	c7 44 24 08 32 74 10 	movl   $0xf0107432,0x8(%esp)
f0103819:	f0 
f010381a:	c7 44 24 04 67 01 00 	movl   $0x167,0x4(%esp)
f0103821:	00 
f0103822:	c7 04 24 12 74 10 f0 	movl   $0xf0107412,(%esp)
f0103829:	e8 12 c8 ff ff       	call   f0100040 <_panic>

	struct Proghdr *ph,*eph;
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
f010382e:	8b 45 08             	mov    0x8(%ebp),%eax
f0103831:	89 c6                	mov    %eax,%esi
f0103833:	03 70 1c             	add    0x1c(%eax),%esi
	eph = ph + ELFHDR->e_phnum;
f0103836:	0f b7 40 2c          	movzwl 0x2c(%eax),%eax
f010383a:	c1 e0 05             	shl    $0x5,%eax
f010383d:	01 f0                	add    %esi,%eax
f010383f:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	for (; ph < eph; ph++) {
f0103842:	39 c6                	cmp    %eax,%esi
f0103844:	0f 83 d2 00 00 00    	jae    f010391c <env_create+0x16e>
		if (ph->p_type == ELF_PROG_LOAD) {
f010384a:	83 3e 01             	cmpl   $0x1,(%esi)
f010384d:	0f 85 bd 00 00 00    	jne    f0103910 <env_create+0x162>
			if (ph->p_filesz > ph->p_memsz)
f0103853:	8b 56 14             	mov    0x14(%esi),%edx
f0103856:	39 56 10             	cmp    %edx,0x10(%esi)
f0103859:	76 1c                	jbe    f0103877 <env_create+0xc9>
				panic("invalid ELF proGhdr header!");
f010385b:	c7 44 24 08 47 74 10 	movl   $0xf0107447,0x8(%esp)
f0103862:	f0 
f0103863:	c7 44 24 04 6f 01 00 	movl   $0x16f,0x4(%esp)
f010386a:	00 
f010386b:	c7 04 24 12 74 10 f0 	movl   $0xf0107412,(%esp)
f0103872:	e8 c9 c7 ff ff       	call   f0100040 <_panic>

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
f0103877:	8b 46 08             	mov    0x8(%esi),%eax
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f010387a:	89 c3                	mov    %eax,%ebx
f010387c:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f0103882:	8d 84 02 ff 0f 00 00 	lea    0xfff(%edx,%eax,1),%eax
f0103889:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f010388e:	39 c3                	cmp    %eax,%ebx
f0103890:	73 59                	jae    f01038eb <env_create+0x13d>
f0103892:	89 75 d0             	mov    %esi,-0x30(%ebp)
f0103895:	89 c6                	mov    %eax,%esi
		p = (struct Page*)page_alloc(1);
f0103897:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f010389e:	e8 a9 d8 ff ff       	call   f010114c <page_alloc>
		if(p==NULL)
f01038a3:	85 c0                	test   %eax,%eax
f01038a5:	75 1c                	jne    f01038c3 <env_create+0x115>
			panic("Memory out!");
f01038a7:	c7 44 24 08 63 74 10 	movl   $0xf0107463,0x8(%esp)
f01038ae:	f0 
f01038af:	c7 44 24 04 29 01 00 	movl   $0x129,0x4(%esp)
f01038b6:	00 
f01038b7:	c7 04 24 12 74 10 f0 	movl   $0xf0107412,(%esp)
f01038be:	e8 7d c7 ff ff       	call   f0100040 <_panic>
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
f01038c3:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01038ca:	00 
f01038cb:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f01038cf:	89 44 24 04          	mov    %eax,0x4(%esp)
f01038d3:	8b 47 60             	mov    0x60(%edi),%eax
f01038d6:	89 04 24             	mov    %eax,(%esp)
f01038d9:	e8 20 db ff ff       	call   f01013fe <page_insert>
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f01038de:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f01038e4:	39 f3                	cmp    %esi,%ebx
f01038e6:	72 af                	jb     f0103897 <env_create+0xe9>
f01038e8:	8b 75 d0             	mov    -0x30(%ebp),%esi
			if (ph->p_filesz > ph->p_memsz)
				panic("invalid ELF proGhdr header!");

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
			//copy to va
			char *va = (char *)(ph->p_va);
f01038eb:	8b 4e 08             	mov    0x8(%esi),%ecx
			size_t i;
			for (i = 0; i < ph->p_filesz; i++)
f01038ee:	83 7e 10 00          	cmpl   $0x0,0x10(%esi)
f01038f2:	74 1c                	je     f0103910 <env_create+0x162>
f01038f4:	b8 00 00 00 00       	mov    $0x0,%eax
f01038f9:	8b 5d 08             	mov    0x8(%ebp),%ebx
				va[i] = binary[ph->p_offset + i];
f01038fc:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f01038ff:	03 56 04             	add    0x4(%esi),%edx
f0103902:	0f b6 12             	movzbl (%edx),%edx
f0103905:	88 14 08             	mov    %dl,(%eax,%ecx,1)

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
			//copy to va
			char *va = (char *)(ph->p_va);
			size_t i;
			for (i = 0; i < ph->p_filesz; i++)
f0103908:	83 c0 01             	add    $0x1,%eax
f010390b:	3b 46 10             	cmp    0x10(%esi),%eax
f010390e:	72 ec                	jb     f01038fc <env_create+0x14e>
		panic("Invalid ELF format !");

	struct Proghdr *ph,*eph;
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
	eph = ph + ELFHDR->e_phnum;
	for (; ph < eph; ph++) {
f0103910:	83 c6 20             	add    $0x20,%esi
f0103913:	39 75 d4             	cmp    %esi,-0x2c(%ebp)
f0103916:	0f 87 2e ff ff ff    	ja     f010384a <env_create+0x9c>
			for (i = 0; i < ph->p_filesz; i++)
				va[i] = binary[ph->p_offset + i];
		}
	}
	//set programe entry
	e->env_tf.tf_eip = ELFHDR->e_entry;
f010391c:	8b 45 08             	mov    0x8(%ebp),%eax
f010391f:	8b 40 18             	mov    0x18(%eax),%eax
f0103922:	89 47 30             	mov    %eax,0x30(%edi)
	// Now map one page for the program's initial stack
	// at virtual address USTACKTOP - PGSIZE.

	// LAB 3: Your code here.
	struct Page* stackPage = (struct Page*)page_alloc(1);
f0103925:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f010392c:	e8 1b d8 ff ff       	call   f010114c <page_alloc>
	if(stackPage == NULL)
f0103931:	85 c0                	test   %eax,%eax
f0103933:	75 1c                	jne    f0103951 <env_create+0x1a3>
		panic("Out of memory!");
f0103935:	c7 44 24 08 6f 74 10 	movl   $0xf010746f,0x8(%esp)
f010393c:	f0 
f010393d:	c7 44 24 04 81 01 00 	movl   $0x181,0x4(%esp)
f0103944:	00 
f0103945:	c7 04 24 12 74 10 f0 	movl   $0xf0107412,(%esp)
f010394c:	e8 ef c6 ff ff       	call   f0100040 <_panic>
	page_insert(e->env_pgdir,stackPage,(void*)USTACKTOP - PGSIZE,PTE_U|PTE_W);
f0103951:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0103958:	00 
f0103959:	c7 44 24 08 00 d0 bf 	movl   $0xeebfd000,0x8(%esp)
f0103960:	ee 
f0103961:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103965:	8b 47 60             	mov    0x60(%edi),%eax
f0103968:	89 04 24             	mov    %eax,(%esp)
f010396b:	e8 8e da ff ff       	call   f01013fe <page_insert>
	lcr3(PADDR(kern_pgdir));
f0103970:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103975:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010397a:	77 20                	ja     f010399c <env_create+0x1ee>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010397c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103980:	c7 44 24 08 c8 63 10 	movl   $0xf01063c8,0x8(%esp)
f0103987:	f0 
f0103988:	c7 44 24 04 83 01 00 	movl   $0x183,0x4(%esp)
f010398f:	00 
f0103990:	c7 04 24 12 74 10 f0 	movl   $0xf0107412,(%esp)
f0103997:	e8 a4 c6 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f010399c:	05 00 00 00 10       	add    $0x10000000,%eax
f01039a1:	0f 22 d8             	mov    %eax,%cr3
{
	// LAB 3: Your code here.
	struct Env * env;
	if(env_alloc(&env,0)==0){
		load_icode(env,binary,size);
		env->env_type = type;
f01039a4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01039a7:	8b 55 10             	mov    0x10(%ebp),%edx
f01039aa:	89 50 50             	mov    %edx,0x50(%eax)
f01039ad:	eb 1c                	jmp    f01039cb <env_create+0x21d>
	}else{
		panic("create env fails !");
f01039af:	c7 44 24 08 7e 74 10 	movl   $0xf010747e,0x8(%esp)
f01039b6:	f0 
f01039b7:	c7 44 24 04 96 01 00 	movl   $0x196,0x4(%esp)
f01039be:	00 
f01039bf:	c7 04 24 12 74 10 f0 	movl   $0xf0107412,(%esp)
f01039c6:	e8 75 c6 ff ff       	call   f0100040 <_panic>
	}
}
f01039cb:	83 c4 3c             	add    $0x3c,%esp
f01039ce:	5b                   	pop    %ebx
f01039cf:	5e                   	pop    %esi
f01039d0:	5f                   	pop    %edi
f01039d1:	5d                   	pop    %ebp
f01039d2:	c3                   	ret    

f01039d3 <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f01039d3:	55                   	push   %ebp
f01039d4:	89 e5                	mov    %esp,%ebp
f01039d6:	57                   	push   %edi
f01039d7:	56                   	push   %esi
f01039d8:	53                   	push   %ebx
f01039d9:	83 ec 2c             	sub    $0x2c,%esp
f01039dc:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f01039df:	e8 8f 22 00 00       	call   f0105c73 <cpunum>
f01039e4:	6b c0 74             	imul   $0x74,%eax,%eax
f01039e7:	39 b8 28 30 22 f0    	cmp    %edi,-0xfddcfd8(%eax)
f01039ed:	75 34                	jne    f0103a23 <env_free+0x50>
		lcr3(PADDR(kern_pgdir));
f01039ef:	a1 0c 2f 22 f0       	mov    0xf0222f0c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01039f4:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01039f9:	77 20                	ja     f0103a1b <env_free+0x48>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01039fb:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01039ff:	c7 44 24 08 c8 63 10 	movl   $0xf01063c8,0x8(%esp)
f0103a06:	f0 
f0103a07:	c7 44 24 04 a8 01 00 	movl   $0x1a8,0x4(%esp)
f0103a0e:	00 
f0103a0f:	c7 04 24 12 74 10 f0 	movl   $0xf0107412,(%esp)
f0103a16:	e8 25 c6 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103a1b:	05 00 00 00 10       	add    $0x10000000,%eax
f0103a20:	0f 22 d8             	mov    %eax,%cr3

	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0103a23:	8b 5f 48             	mov    0x48(%edi),%ebx
f0103a26:	e8 48 22 00 00       	call   f0105c73 <cpunum>
f0103a2b:	6b d0 74             	imul   $0x74,%eax,%edx
f0103a2e:	b8 00 00 00 00       	mov    $0x0,%eax
f0103a33:	83 ba 28 30 22 f0 00 	cmpl   $0x0,-0xfddcfd8(%edx)
f0103a3a:	74 11                	je     f0103a4d <env_free+0x7a>
f0103a3c:	e8 32 22 00 00       	call   f0105c73 <cpunum>
f0103a41:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a44:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f0103a4a:	8b 40 48             	mov    0x48(%eax),%eax
f0103a4d:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103a51:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103a55:	c7 04 24 91 74 10 f0 	movl   $0xf0107491,(%esp)
f0103a5c:	e8 1b 04 00 00       	call   f0103e7c <cprintf>

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103a61:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0103a68:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0103a6b:	89 c8                	mov    %ecx,%eax
f0103a6d:	c1 e0 02             	shl    $0x2,%eax
f0103a70:	89 45 dc             	mov    %eax,-0x24(%ebp)

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f0103a73:	8b 47 60             	mov    0x60(%edi),%eax
f0103a76:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f0103a79:	f7 c6 01 00 00 00    	test   $0x1,%esi
f0103a7f:	0f 84 b7 00 00 00    	je     f0103b3c <env_free+0x169>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f0103a85:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103a8b:	89 f0                	mov    %esi,%eax
f0103a8d:	c1 e8 0c             	shr    $0xc,%eax
f0103a90:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103a93:	3b 05 08 2f 22 f0    	cmp    0xf0222f08,%eax
f0103a99:	72 20                	jb     f0103abb <env_free+0xe8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103a9b:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0103a9f:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f0103aa6:	f0 
f0103aa7:	c7 44 24 04 b7 01 00 	movl   $0x1b7,0x4(%esp)
f0103aae:	00 
f0103aaf:	c7 04 24 12 74 10 f0 	movl   $0xf0107412,(%esp)
f0103ab6:	e8 85 c5 ff ff       	call   f0100040 <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103abb:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103abe:	c1 e0 16             	shl    $0x16,%eax
f0103ac1:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103ac4:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f0103ac9:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f0103ad0:	01 
f0103ad1:	74 17                	je     f0103aea <env_free+0x117>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103ad3:	89 d8                	mov    %ebx,%eax
f0103ad5:	c1 e0 0c             	shl    $0xc,%eax
f0103ad8:	0b 45 e4             	or     -0x1c(%ebp),%eax
f0103adb:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103adf:	8b 47 60             	mov    0x60(%edi),%eax
f0103ae2:	89 04 24             	mov    %eax,(%esp)
f0103ae5:	e8 cb d8 ff ff       	call   f01013b5 <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103aea:	83 c3 01             	add    $0x1,%ebx
f0103aed:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f0103af3:	75 d4                	jne    f0103ac9 <env_free+0xf6>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f0103af5:	8b 47 60             	mov    0x60(%edi),%eax
f0103af8:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103afb:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103b02:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103b05:	3b 05 08 2f 22 f0    	cmp    0xf0222f08,%eax
f0103b0b:	72 1c                	jb     f0103b29 <env_free+0x156>
		panic("pa2page called with invalid pa");
f0103b0d:	c7 44 24 08 98 6a 10 	movl   $0xf0106a98,0x8(%esp)
f0103b14:	f0 
f0103b15:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103b1c:	00 
f0103b1d:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f0103b24:	e8 17 c5 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103b29:	a1 10 2f 22 f0       	mov    0xf0222f10,%eax
f0103b2e:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103b31:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0103b34:	89 04 24             	mov    %eax,(%esp)
f0103b37:	e8 aa d6 ff ff       	call   f01011e6 <page_decref>
	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103b3c:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f0103b40:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f0103b47:	0f 85 1b ff ff ff    	jne    f0103a68 <env_free+0x95>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f0103b4d:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103b50:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103b55:	77 20                	ja     f0103b77 <env_free+0x1a4>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103b57:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103b5b:	c7 44 24 08 c8 63 10 	movl   $0xf01063c8,0x8(%esp)
f0103b62:	f0 
f0103b63:	c7 44 24 04 c5 01 00 	movl   $0x1c5,0x4(%esp)
f0103b6a:	00 
f0103b6b:	c7 04 24 12 74 10 f0 	movl   $0xf0107412,(%esp)
f0103b72:	e8 c9 c4 ff ff       	call   f0100040 <_panic>
	e->env_pgdir = 0;
f0103b77:	c7 47 60 00 00 00 00 	movl   $0x0,0x60(%edi)
	return (physaddr_t)kva - KERNBASE;
f0103b7e:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103b83:	c1 e8 0c             	shr    $0xc,%eax
f0103b86:	3b 05 08 2f 22 f0    	cmp    0xf0222f08,%eax
f0103b8c:	72 1c                	jb     f0103baa <env_free+0x1d7>
		panic("pa2page called with invalid pa");
f0103b8e:	c7 44 24 08 98 6a 10 	movl   $0xf0106a98,0x8(%esp)
f0103b95:	f0 
f0103b96:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103b9d:	00 
f0103b9e:	c7 04 24 fd 70 10 f0 	movl   $0xf01070fd,(%esp)
f0103ba5:	e8 96 c4 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103baa:	8b 15 10 2f 22 f0    	mov    0xf0222f10,%edx
f0103bb0:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f0103bb3:	89 04 24             	mov    %eax,(%esp)
f0103bb6:	e8 2b d6 ff ff       	call   f01011e6 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f0103bbb:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f0103bc2:	a1 4c 22 22 f0       	mov    0xf022224c,%eax
f0103bc7:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f0103bca:	89 3d 4c 22 22 f0    	mov    %edi,0xf022224c
}
f0103bd0:	83 c4 2c             	add    $0x2c,%esp
f0103bd3:	5b                   	pop    %ebx
f0103bd4:	5e                   	pop    %esi
f0103bd5:	5f                   	pop    %edi
f0103bd6:	5d                   	pop    %ebp
f0103bd7:	c3                   	ret    

f0103bd8 <env_destroy>:
// If e was the current env, then runs a new environment (and does not return
// to the caller).
//
void
env_destroy(struct Env *e)
{
f0103bd8:	55                   	push   %ebp
f0103bd9:	89 e5                	mov    %esp,%ebp
f0103bdb:	53                   	push   %ebx
f0103bdc:	83 ec 14             	sub    $0x14,%esp
f0103bdf:	8b 5d 08             	mov    0x8(%ebp),%ebx
	// If e is currently running on other CPUs, we change its state to
	// ENV_DYING. A zombie environment will be freed the next time
	// it traps to the kernel.
	if (e->env_status == ENV_RUNNING && curenv != e) {
f0103be2:	83 7b 54 03          	cmpl   $0x3,0x54(%ebx)
f0103be6:	75 19                	jne    f0103c01 <env_destroy+0x29>
f0103be8:	e8 86 20 00 00       	call   f0105c73 <cpunum>
f0103bed:	6b c0 74             	imul   $0x74,%eax,%eax
f0103bf0:	39 98 28 30 22 f0    	cmp    %ebx,-0xfddcfd8(%eax)
f0103bf6:	74 09                	je     f0103c01 <env_destroy+0x29>
		e->env_status = ENV_DYING;
f0103bf8:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
		return;
f0103bff:	eb 2f                	jmp    f0103c30 <env_destroy+0x58>
	}

	env_free(e);
f0103c01:	89 1c 24             	mov    %ebx,(%esp)
f0103c04:	e8 ca fd ff ff       	call   f01039d3 <env_free>

	if (curenv == e) {
f0103c09:	e8 65 20 00 00       	call   f0105c73 <cpunum>
f0103c0e:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c11:	39 98 28 30 22 f0    	cmp    %ebx,-0xfddcfd8(%eax)
f0103c17:	75 17                	jne    f0103c30 <env_destroy+0x58>
		curenv = NULL;
f0103c19:	e8 55 20 00 00       	call   f0105c73 <cpunum>
f0103c1e:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c21:	c7 80 28 30 22 f0 00 	movl   $0x0,-0xfddcfd8(%eax)
f0103c28:	00 00 00 
		sched_yield();
f0103c2b:	e8 11 0b 00 00       	call   f0104741 <sched_yield>
	}
}
f0103c30:	83 c4 14             	add    $0x14,%esp
f0103c33:	5b                   	pop    %ebx
f0103c34:	5d                   	pop    %ebp
f0103c35:	c3                   	ret    

f0103c36 <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f0103c36:	55                   	push   %ebp
f0103c37:	89 e5                	mov    %esp,%ebp
f0103c39:	53                   	push   %ebx
f0103c3a:	83 ec 14             	sub    $0x14,%esp
	// Record the CPU we are running on for user-space debugging
	curenv->env_cpunum = cpunum();
f0103c3d:	e8 31 20 00 00       	call   f0105c73 <cpunum>
f0103c42:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c45:	8b 98 28 30 22 f0    	mov    -0xfddcfd8(%eax),%ebx
f0103c4b:	e8 23 20 00 00       	call   f0105c73 <cpunum>
f0103c50:	89 43 5c             	mov    %eax,0x5c(%ebx)

	__asm __volatile("movl %0,%%esp\n"
f0103c53:	8b 65 08             	mov    0x8(%ebp),%esp
f0103c56:	61                   	popa   
f0103c57:	07                   	pop    %es
f0103c58:	1f                   	pop    %ds
f0103c59:	83 c4 08             	add    $0x8,%esp
f0103c5c:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f0103c5d:	c7 44 24 08 a7 74 10 	movl   $0xf01074a7,0x8(%esp)
f0103c64:	f0 
f0103c65:	c7 44 24 04 fb 01 00 	movl   $0x1fb,0x4(%esp)
f0103c6c:	00 
f0103c6d:	c7 04 24 12 74 10 f0 	movl   $0xf0107412,(%esp)
f0103c74:	e8 c7 c3 ff ff       	call   f0100040 <_panic>

f0103c79 <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0103c79:	55                   	push   %ebp
f0103c7a:	89 e5                	mov    %esp,%ebp
f0103c7c:	53                   	push   %ebx
f0103c7d:	83 ec 14             	sub    $0x14,%esp
f0103c80:	8b 5d 08             	mov    0x8(%ebp),%ebx

	// Hint: This function loads the new environment's state from
	//	e->env_tf.  Go back through the code you wrote above
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.
	if(curenv!=NULL&& curenv->env_status==ENV_RUNNING)
f0103c83:	e8 eb 1f 00 00       	call   f0105c73 <cpunum>
f0103c88:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c8b:	83 b8 28 30 22 f0 00 	cmpl   $0x0,-0xfddcfd8(%eax)
f0103c92:	74 29                	je     f0103cbd <env_run+0x44>
f0103c94:	e8 da 1f 00 00       	call   f0105c73 <cpunum>
f0103c99:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c9c:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f0103ca2:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0103ca6:	75 15                	jne    f0103cbd <env_run+0x44>
		curenv->env_status = ENV_RUNNABLE;
f0103ca8:	e8 c6 1f 00 00       	call   f0105c73 <cpunum>
f0103cad:	6b c0 74             	imul   $0x74,%eax,%eax
f0103cb0:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f0103cb6:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)

	curenv = e;
f0103cbd:	e8 b1 1f 00 00       	call   f0105c73 <cpunum>
f0103cc2:	6b c0 74             	imul   $0x74,%eax,%eax
f0103cc5:	89 98 28 30 22 f0    	mov    %ebx,-0xfddcfd8(%eax)
	int zero = 0;
	e->env_status = ENV_RUNNING;
f0103ccb:	c7 43 54 03 00 00 00 	movl   $0x3,0x54(%ebx)
	e->env_runs++;
f0103cd2:	83 43 58 01          	addl   $0x1,0x58(%ebx)
	lcr3(PADDR(e->env_pgdir));
f0103cd6:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103cd9:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103cde:	77 20                	ja     f0103d00 <env_run+0x87>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103ce0:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103ce4:	c7 44 24 08 c8 63 10 	movl   $0xf01063c8,0x8(%esp)
f0103ceb:	f0 
f0103cec:	c7 44 24 04 1e 02 00 	movl   $0x21e,0x4(%esp)
f0103cf3:	00 
f0103cf4:	c7 04 24 12 74 10 f0 	movl   $0xf0107412,(%esp)
f0103cfb:	e8 40 c3 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103d00:	05 00 00 00 10       	add    $0x10000000,%eax
f0103d05:	0f 22 d8             	mov    %eax,%cr3
	env_pop_tf(&e->env_tf);
f0103d08:	89 1c 24             	mov    %ebx,(%esp)
f0103d0b:	e8 26 ff ff ff       	call   f0103c36 <env_pop_tf>

f0103d10 <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0103d10:	55                   	push   %ebp
f0103d11:	89 e5                	mov    %esp,%ebp
f0103d13:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103d17:	ba 70 00 00 00       	mov    $0x70,%edx
f0103d1c:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0103d1d:	b2 71                	mov    $0x71,%dl
f0103d1f:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0103d20:	0f b6 c0             	movzbl %al,%eax
}
f0103d23:	5d                   	pop    %ebp
f0103d24:	c3                   	ret    

f0103d25 <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0103d25:	55                   	push   %ebp
f0103d26:	89 e5                	mov    %esp,%ebp
f0103d28:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103d2c:	ba 70 00 00 00       	mov    $0x70,%edx
f0103d31:	ee                   	out    %al,(%dx)
f0103d32:	b2 71                	mov    $0x71,%dl
f0103d34:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103d37:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0103d38:	5d                   	pop    %ebp
f0103d39:	c3                   	ret    

f0103d3a <irq_setmask_8259A>:
		irq_setmask_8259A(irq_mask_8259A);
}

void
irq_setmask_8259A(uint16_t mask)
{
f0103d3a:	55                   	push   %ebp
f0103d3b:	89 e5                	mov    %esp,%ebp
f0103d3d:	56                   	push   %esi
f0103d3e:	53                   	push   %ebx
f0103d3f:	83 ec 10             	sub    $0x10,%esp
f0103d42:	8b 45 08             	mov    0x8(%ebp),%eax
	int i;
	irq_mask_8259A = mask;
f0103d45:	66 a3 88 f3 11 f0    	mov    %ax,0xf011f388
	if (!didinit)
f0103d4b:	83 3d 50 22 22 f0 00 	cmpl   $0x0,0xf0222250
f0103d52:	74 4e                	je     f0103da2 <irq_setmask_8259A+0x68>
f0103d54:	89 c6                	mov    %eax,%esi
f0103d56:	ba 21 00 00 00       	mov    $0x21,%edx
f0103d5b:	ee                   	out    %al,(%dx)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
f0103d5c:	66 c1 e8 08          	shr    $0x8,%ax
f0103d60:	b2 a1                	mov    $0xa1,%dl
f0103d62:	ee                   	out    %al,(%dx)
	cprintf("enabled interrupts:");
f0103d63:	c7 04 24 b3 74 10 f0 	movl   $0xf01074b3,(%esp)
f0103d6a:	e8 0d 01 00 00       	call   f0103e7c <cprintf>
	for (i = 0; i < 16; i++)
f0103d6f:	bb 00 00 00 00       	mov    $0x0,%ebx
		if (~mask & (1<<i))
f0103d74:	0f b7 f6             	movzwl %si,%esi
f0103d77:	f7 d6                	not    %esi
f0103d79:	0f a3 de             	bt     %ebx,%esi
f0103d7c:	73 10                	jae    f0103d8e <irq_setmask_8259A+0x54>
			cprintf(" %d", i);
f0103d7e:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103d82:	c7 04 24 79 79 10 f0 	movl   $0xf0107979,(%esp)
f0103d89:	e8 ee 00 00 00       	call   f0103e7c <cprintf>
	if (!didinit)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
	cprintf("enabled interrupts:");
	for (i = 0; i < 16; i++)
f0103d8e:	83 c3 01             	add    $0x1,%ebx
f0103d91:	83 fb 10             	cmp    $0x10,%ebx
f0103d94:	75 e3                	jne    f0103d79 <irq_setmask_8259A+0x3f>
		if (~mask & (1<<i))
			cprintf(" %d", i);
	cprintf("\n");
f0103d96:	c7 04 24 8c 71 10 f0 	movl   $0xf010718c,(%esp)
f0103d9d:	e8 da 00 00 00       	call   f0103e7c <cprintf>
}
f0103da2:	83 c4 10             	add    $0x10,%esp
f0103da5:	5b                   	pop    %ebx
f0103da6:	5e                   	pop    %esi
f0103da7:	5d                   	pop    %ebp
f0103da8:	c3                   	ret    

f0103da9 <pic_init>:

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
	didinit = 1;
f0103da9:	c7 05 50 22 22 f0 01 	movl   $0x1,0xf0222250
f0103db0:	00 00 00 
f0103db3:	ba 21 00 00 00       	mov    $0x21,%edx
f0103db8:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0103dbd:	ee                   	out    %al,(%dx)
f0103dbe:	b2 a1                	mov    $0xa1,%dl
f0103dc0:	ee                   	out    %al,(%dx)
f0103dc1:	b2 20                	mov    $0x20,%dl
f0103dc3:	b8 11 00 00 00       	mov    $0x11,%eax
f0103dc8:	ee                   	out    %al,(%dx)
f0103dc9:	b2 21                	mov    $0x21,%dl
f0103dcb:	b8 20 00 00 00       	mov    $0x20,%eax
f0103dd0:	ee                   	out    %al,(%dx)
f0103dd1:	b8 04 00 00 00       	mov    $0x4,%eax
f0103dd6:	ee                   	out    %al,(%dx)
f0103dd7:	b8 03 00 00 00       	mov    $0x3,%eax
f0103ddc:	ee                   	out    %al,(%dx)
f0103ddd:	b2 a0                	mov    $0xa0,%dl
f0103ddf:	b8 11 00 00 00       	mov    $0x11,%eax
f0103de4:	ee                   	out    %al,(%dx)
f0103de5:	b2 a1                	mov    $0xa1,%dl
f0103de7:	b8 28 00 00 00       	mov    $0x28,%eax
f0103dec:	ee                   	out    %al,(%dx)
f0103ded:	b8 02 00 00 00       	mov    $0x2,%eax
f0103df2:	ee                   	out    %al,(%dx)
f0103df3:	b8 01 00 00 00       	mov    $0x1,%eax
f0103df8:	ee                   	out    %al,(%dx)
f0103df9:	b2 20                	mov    $0x20,%dl
f0103dfb:	b8 68 00 00 00       	mov    $0x68,%eax
f0103e00:	ee                   	out    %al,(%dx)
f0103e01:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103e06:	ee                   	out    %al,(%dx)
f0103e07:	b2 a0                	mov    $0xa0,%dl
f0103e09:	b8 68 00 00 00       	mov    $0x68,%eax
f0103e0e:	ee                   	out    %al,(%dx)
f0103e0f:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103e14:	ee                   	out    %al,(%dx)
	outb(IO_PIC1, 0x0a);             /* read IRR by default */

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
f0103e15:	0f b7 05 88 f3 11 f0 	movzwl 0xf011f388,%eax
f0103e1c:	66 83 f8 ff          	cmp    $0xffff,%ax
f0103e20:	74 12                	je     f0103e34 <pic_init+0x8b>
static bool didinit;

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
f0103e22:	55                   	push   %ebp
f0103e23:	89 e5                	mov    %esp,%ebp
f0103e25:	83 ec 18             	sub    $0x18,%esp

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
		irq_setmask_8259A(irq_mask_8259A);
f0103e28:	0f b7 c0             	movzwl %ax,%eax
f0103e2b:	89 04 24             	mov    %eax,(%esp)
f0103e2e:	e8 07 ff ff ff       	call   f0103d3a <irq_setmask_8259A>
}
f0103e33:	c9                   	leave  
f0103e34:	f3 c3                	repz ret 

f0103e36 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0103e36:	55                   	push   %ebp
f0103e37:	89 e5                	mov    %esp,%ebp
f0103e39:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0103e3c:	8b 45 08             	mov    0x8(%ebp),%eax
f0103e3f:	89 04 24             	mov    %eax,(%esp)
f0103e42:	e8 76 c9 ff ff       	call   f01007bd <cputchar>
	*cnt++;
}
f0103e47:	c9                   	leave  
f0103e48:	c3                   	ret    

f0103e49 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0103e49:	55                   	push   %ebp
f0103e4a:	89 e5                	mov    %esp,%ebp
f0103e4c:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0103e4f:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0103e56:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103e59:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103e5d:	8b 45 08             	mov    0x8(%ebp),%eax
f0103e60:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103e64:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0103e67:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e6b:	c7 04 24 36 3e 10 f0 	movl   $0xf0103e36,(%esp)
f0103e72:	e8 1d 10 00 00       	call   f0104e94 <vprintfmt>
	return cnt;
}
f0103e77:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0103e7a:	c9                   	leave  
f0103e7b:	c3                   	ret    

f0103e7c <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0103e7c:	55                   	push   %ebp
f0103e7d:	89 e5                	mov    %esp,%ebp
f0103e7f:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0103e82:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0103e85:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e89:	8b 45 08             	mov    0x8(%ebp),%eax
f0103e8c:	89 04 24             	mov    %eax,(%esp)
f0103e8f:	e8 b5 ff ff ff       	call   f0103e49 <vcprintf>
	va_end(ap);

	return cnt;
}
f0103e94:	c9                   	leave  
f0103e95:	c3                   	ret    
f0103e96:	66 90                	xchg   %ax,%ax
f0103e98:	66 90                	xchg   %ax,%ax
f0103e9a:	66 90                	xchg   %ax,%ax
f0103e9c:	66 90                	xchg   %ax,%ax
f0103e9e:	66 90                	xchg   %ax,%ax

f0103ea0 <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f0103ea0:	55                   	push   %ebp
f0103ea1:	89 e5                	mov    %esp,%ebp
	//
	// LAB 4: Your code here:

	// Setup a TSS so that we get the right stack
	// when we trap to the kernel.
	ts.ts_esp0 = KSTACKTOP;
f0103ea3:	c7 05 84 2a 22 f0 00 	movl   $0xefc00000,0xf0222a84
f0103eaa:	00 c0 ef 
	ts.ts_ss0 = GD_KD;
f0103ead:	66 c7 05 88 2a 22 f0 	movw   $0x10,0xf0222a88
f0103eb4:	10 00 

	// Initialize the TSS slot of the gdt.
	gdt[GD_TSS0 >> 3] = SEG16(STS_T32A, (uint32_t) (&ts),
f0103eb6:	66 c7 05 48 f3 11 f0 	movw   $0x68,0xf011f348
f0103ebd:	68 00 
f0103ebf:	b8 80 2a 22 f0       	mov    $0xf0222a80,%eax
f0103ec4:	66 a3 4a f3 11 f0    	mov    %ax,0xf011f34a
f0103eca:	89 c2                	mov    %eax,%edx
f0103ecc:	c1 ea 10             	shr    $0x10,%edx
f0103ecf:	88 15 4c f3 11 f0    	mov    %dl,0xf011f34c
f0103ed5:	c6 05 4e f3 11 f0 40 	movb   $0x40,0xf011f34e
f0103edc:	c1 e8 18             	shr    $0x18,%eax
f0103edf:	a2 4f f3 11 f0       	mov    %al,0xf011f34f
					sizeof(struct Taskstate), 0);
	gdt[GD_TSS0 >> 3].sd_s = 0;
f0103ee4:	c6 05 4d f3 11 f0 89 	movb   $0x89,0xf011f34d
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f0103eeb:	b8 28 00 00 00       	mov    $0x28,%eax
f0103ef0:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f0103ef3:	b8 8a f3 11 f0       	mov    $0xf011f38a,%eax
f0103ef8:	0f 01 18             	lidtl  (%eax)
	// bottom three bits are special; we leave them 0)
	ltr(GD_TSS0);

	// Load the IDT
	lidt(&idt_pd);
}
f0103efb:	5d                   	pop    %ebp
f0103efc:	c3                   	ret    

f0103efd <trap_init>:
}


void
trap_init(void)
{
f0103efd:	55                   	push   %ebp
f0103efe:	89 e5                	mov    %esp,%ebp
	extern struct Segdesc gdt[];
	SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);
f0103f00:	b8 ca 46 10 f0       	mov    $0xf01046ca,%eax
f0103f05:	66 a3 60 22 22 f0    	mov    %ax,0xf0222260
f0103f0b:	66 c7 05 62 22 22 f0 	movw   $0x8,0xf0222262
f0103f12:	08 00 
f0103f14:	c6 05 64 22 22 f0 00 	movb   $0x0,0xf0222264
f0103f1b:	c6 05 65 22 22 f0 8f 	movb   $0x8f,0xf0222265
f0103f22:	c1 e8 10             	shr    $0x10,%eax
f0103f25:	66 a3 66 22 22 f0    	mov    %ax,0xf0222266
	SETGATE(idt[2], 0, GD_KT, nmi_handler, 0);
f0103f2b:	b8 d0 46 10 f0       	mov    $0xf01046d0,%eax
f0103f30:	66 a3 70 22 22 f0    	mov    %ax,0xf0222270
f0103f36:	66 c7 05 72 22 22 f0 	movw   $0x8,0xf0222272
f0103f3d:	08 00 
f0103f3f:	c6 05 74 22 22 f0 00 	movb   $0x0,0xf0222274
f0103f46:	c6 05 75 22 22 f0 8e 	movb   $0x8e,0xf0222275
f0103f4d:	c1 e8 10             	shr    $0x10,%eax
f0103f50:	66 a3 76 22 22 f0    	mov    %ax,0xf0222276
	SETGATE(idt[3], 1, GD_KT, breakpoint_handler, 3);
f0103f56:	b8 d6 46 10 f0       	mov    $0xf01046d6,%eax
f0103f5b:	66 a3 78 22 22 f0    	mov    %ax,0xf0222278
f0103f61:	66 c7 05 7a 22 22 f0 	movw   $0x8,0xf022227a
f0103f68:	08 00 
f0103f6a:	c6 05 7c 22 22 f0 00 	movb   $0x0,0xf022227c
f0103f71:	c6 05 7d 22 22 f0 ef 	movb   $0xef,0xf022227d
f0103f78:	c1 e8 10             	shr    $0x10,%eax
f0103f7b:	66 a3 7e 22 22 f0    	mov    %ax,0xf022227e
	SETGATE(idt[4], 1, GD_KT, overflow_handler, 3);
f0103f81:	b8 dc 46 10 f0       	mov    $0xf01046dc,%eax
f0103f86:	66 a3 80 22 22 f0    	mov    %ax,0xf0222280
f0103f8c:	66 c7 05 82 22 22 f0 	movw   $0x8,0xf0222282
f0103f93:	08 00 
f0103f95:	c6 05 84 22 22 f0 00 	movb   $0x0,0xf0222284
f0103f9c:	c6 05 85 22 22 f0 ef 	movb   $0xef,0xf0222285
f0103fa3:	c1 e8 10             	shr    $0x10,%eax
f0103fa6:	66 a3 86 22 22 f0    	mov    %ax,0xf0222286
	SETGATE(idt[5], 1, GD_KT, bdrgeexceed_handler, 3);
f0103fac:	b8 e2 46 10 f0       	mov    $0xf01046e2,%eax
f0103fb1:	66 a3 88 22 22 f0    	mov    %ax,0xf0222288
f0103fb7:	66 c7 05 8a 22 22 f0 	movw   $0x8,0xf022228a
f0103fbe:	08 00 
f0103fc0:	c6 05 8c 22 22 f0 00 	movb   $0x0,0xf022228c
f0103fc7:	c6 05 8d 22 22 f0 ef 	movb   $0xef,0xf022228d
f0103fce:	c1 e8 10             	shr    $0x10,%eax
f0103fd1:	66 a3 8e 22 22 f0    	mov    %ax,0xf022228e
	SETGATE(idt[6], 1, GD_KT, invalidop_handler, 0);
f0103fd7:	b8 e8 46 10 f0       	mov    $0xf01046e8,%eax
f0103fdc:	66 a3 90 22 22 f0    	mov    %ax,0xf0222290
f0103fe2:	66 c7 05 92 22 22 f0 	movw   $0x8,0xf0222292
f0103fe9:	08 00 
f0103feb:	c6 05 94 22 22 f0 00 	movb   $0x0,0xf0222294
f0103ff2:	c6 05 95 22 22 f0 8f 	movb   $0x8f,0xf0222295
f0103ff9:	c1 e8 10             	shr    $0x10,%eax
f0103ffc:	66 a3 96 22 22 f0    	mov    %ax,0xf0222296
	SETGATE(idt[7], 1, GD_KT, nomathcopro_handler, 0);
f0104002:	b8 ee 46 10 f0       	mov    $0xf01046ee,%eax
f0104007:	66 a3 98 22 22 f0    	mov    %ax,0xf0222298
f010400d:	66 c7 05 9a 22 22 f0 	movw   $0x8,0xf022229a
f0104014:	08 00 
f0104016:	c6 05 9c 22 22 f0 00 	movb   $0x0,0xf022229c
f010401d:	c6 05 9d 22 22 f0 8f 	movb   $0x8f,0xf022229d
f0104024:	c1 e8 10             	shr    $0x10,%eax
f0104027:	66 a3 9e 22 22 f0    	mov    %ax,0xf022229e
	SETGATE(idt[8], 1, GD_KT, dbfault_handler, 0);
f010402d:	b8 f4 46 10 f0       	mov    $0xf01046f4,%eax
f0104032:	66 a3 a0 22 22 f0    	mov    %ax,0xf02222a0
f0104038:	66 c7 05 a2 22 22 f0 	movw   $0x8,0xf02222a2
f010403f:	08 00 
f0104041:	c6 05 a4 22 22 f0 00 	movb   $0x0,0xf02222a4
f0104048:	c6 05 a5 22 22 f0 8f 	movb   $0x8f,0xf02222a5
f010404f:	c1 e8 10             	shr    $0x10,%eax
f0104052:	66 a3 a6 22 22 f0    	mov    %ax,0xf02222a6
	SETGATE(idt[10], 1, GD_KT, invalidTSS_handler, 0);
f0104058:	b8 f8 46 10 f0       	mov    $0xf01046f8,%eax
f010405d:	66 a3 b0 22 22 f0    	mov    %ax,0xf02222b0
f0104063:	66 c7 05 b2 22 22 f0 	movw   $0x8,0xf02222b2
f010406a:	08 00 
f010406c:	c6 05 b4 22 22 f0 00 	movb   $0x0,0xf02222b4
f0104073:	c6 05 b5 22 22 f0 8f 	movb   $0x8f,0xf02222b5
f010407a:	c1 e8 10             	shr    $0x10,%eax
f010407d:	66 a3 b6 22 22 f0    	mov    %ax,0xf02222b6

	SETGATE(idt[11], 1, GD_KT, sgmtnotpresent_handler, 0);
f0104083:	b8 fc 46 10 f0       	mov    $0xf01046fc,%eax
f0104088:	66 a3 b8 22 22 f0    	mov    %ax,0xf02222b8
f010408e:	66 c7 05 ba 22 22 f0 	movw   $0x8,0xf02222ba
f0104095:	08 00 
f0104097:	c6 05 bc 22 22 f0 00 	movb   $0x0,0xf02222bc
f010409e:	c6 05 bd 22 22 f0 8f 	movb   $0x8f,0xf02222bd
f01040a5:	c1 e8 10             	shr    $0x10,%eax
f01040a8:	66 a3 be 22 22 f0    	mov    %ax,0xf02222be
	SETGATE(idt[12], 1, GD_KT, stacksgmtfault_handler, 0);
f01040ae:	b8 00 47 10 f0       	mov    $0xf0104700,%eax
f01040b3:	66 a3 c0 22 22 f0    	mov    %ax,0xf02222c0
f01040b9:	66 c7 05 c2 22 22 f0 	movw   $0x8,0xf02222c2
f01040c0:	08 00 
f01040c2:	c6 05 c4 22 22 f0 00 	movb   $0x0,0xf02222c4
f01040c9:	c6 05 c5 22 22 f0 8f 	movb   $0x8f,0xf02222c5
f01040d0:	c1 e8 10             	shr    $0x10,%eax
f01040d3:	66 a3 c6 22 22 f0    	mov    %ax,0xf02222c6
	SETGATE(idt[14], 1, GD_KT, pagefault_handler, 0);
f01040d9:	b8 08 47 10 f0       	mov    $0xf0104708,%eax
f01040de:	66 a3 d0 22 22 f0    	mov    %ax,0xf02222d0
f01040e4:	66 c7 05 d2 22 22 f0 	movw   $0x8,0xf02222d2
f01040eb:	08 00 
f01040ed:	c6 05 d4 22 22 f0 00 	movb   $0x0,0xf02222d4
f01040f4:	c6 05 d5 22 22 f0 8f 	movb   $0x8f,0xf02222d5
f01040fb:	c1 e8 10             	shr    $0x10,%eax
f01040fe:	66 a3 d6 22 22 f0    	mov    %ax,0xf02222d6
	SETGATE(idt[13], 1, GD_KT, generalprotection_handler, 0);
f0104104:	b8 04 47 10 f0       	mov    $0xf0104704,%eax
f0104109:	66 a3 c8 22 22 f0    	mov    %ax,0xf02222c8
f010410f:	66 c7 05 ca 22 22 f0 	movw   $0x8,0xf02222ca
f0104116:	08 00 
f0104118:	c6 05 cc 22 22 f0 00 	movb   $0x0,0xf02222cc
f010411f:	c6 05 cd 22 22 f0 8f 	movb   $0x8f,0xf02222cd
f0104126:	c1 e8 10             	shr    $0x10,%eax
f0104129:	66 a3 ce 22 22 f0    	mov    %ax,0xf02222ce
	SETGATE(idt[16], 1, GD_KT, FPUerror_handler, 0);
f010412f:	b8 0c 47 10 f0       	mov    $0xf010470c,%eax
f0104134:	66 a3 e0 22 22 f0    	mov    %ax,0xf02222e0
f010413a:	66 c7 05 e2 22 22 f0 	movw   $0x8,0xf02222e2
f0104141:	08 00 
f0104143:	c6 05 e4 22 22 f0 00 	movb   $0x0,0xf02222e4
f010414a:	c6 05 e5 22 22 f0 8f 	movb   $0x8f,0xf02222e5
f0104151:	c1 e8 10             	shr    $0x10,%eax
f0104154:	66 a3 e6 22 22 f0    	mov    %ax,0xf02222e6
	SETGATE(idt[17], 1, GD_KT, alignmentcheck_handler, 0);
f010415a:	b8 12 47 10 f0       	mov    $0xf0104712,%eax
f010415f:	66 a3 e8 22 22 f0    	mov    %ax,0xf02222e8
f0104165:	66 c7 05 ea 22 22 f0 	movw   $0x8,0xf02222ea
f010416c:	08 00 
f010416e:	c6 05 ec 22 22 f0 00 	movb   $0x0,0xf02222ec
f0104175:	c6 05 ed 22 22 f0 8f 	movb   $0x8f,0xf02222ed
f010417c:	c1 e8 10             	shr    $0x10,%eax
f010417f:	66 a3 ee 22 22 f0    	mov    %ax,0xf02222ee
	SETGATE(idt[18],1, GD_KT, machinecheck_handler, 0);
f0104185:	b8 16 47 10 f0       	mov    $0xf0104716,%eax
f010418a:	66 a3 f0 22 22 f0    	mov    %ax,0xf02222f0
f0104190:	66 c7 05 f2 22 22 f0 	movw   $0x8,0xf02222f2
f0104197:	08 00 
f0104199:	c6 05 f4 22 22 f0 00 	movb   $0x0,0xf02222f4
f01041a0:	c6 05 f5 22 22 f0 8f 	movb   $0x8f,0xf02222f5
f01041a7:	c1 e8 10             	shr    $0x10,%eax
f01041aa:	66 a3 f6 22 22 f0    	mov    %ax,0xf02222f6
	SETGATE(idt[19], 1, GD_KT, SIMDFPexception_handler, 0);
f01041b0:	b8 1c 47 10 f0       	mov    $0xf010471c,%eax
f01041b5:	66 a3 f8 22 22 f0    	mov    %ax,0xf02222f8
f01041bb:	66 c7 05 fa 22 22 f0 	movw   $0x8,0xf02222fa
f01041c2:	08 00 
f01041c4:	c6 05 fc 22 22 f0 00 	movb   $0x0,0xf02222fc
f01041cb:	c6 05 fd 22 22 f0 8f 	movb   $0x8f,0xf02222fd
f01041d2:	c1 e8 10             	shr    $0x10,%eax
f01041d5:	66 a3 fe 22 22 f0    	mov    %ax,0xf02222fe
	SETGATE(idt[48], 0, GD_KT, systemcall_handler, 3);
f01041db:	b8 22 47 10 f0       	mov    $0xf0104722,%eax
f01041e0:	66 a3 e0 23 22 f0    	mov    %ax,0xf02223e0
f01041e6:	66 c7 05 e2 23 22 f0 	movw   $0x8,0xf02223e2
f01041ed:	08 00 
f01041ef:	c6 05 e4 23 22 f0 00 	movb   $0x0,0xf02223e4
f01041f6:	c6 05 e5 23 22 f0 ee 	movb   $0xee,0xf02223e5
f01041fd:	c1 e8 10             	shr    $0x10,%eax
f0104200:	66 a3 e6 23 22 f0    	mov    %ax,0xf02223e6
	// LAB 3: Your code here.

	// Per-CPU setup 
	trap_init_percpu();
f0104206:	e8 95 fc ff ff       	call   f0103ea0 <trap_init_percpu>
}
f010420b:	5d                   	pop    %ebp
f010420c:	c3                   	ret    

f010420d <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f010420d:	55                   	push   %ebp
f010420e:	89 e5                	mov    %esp,%ebp
f0104210:	53                   	push   %ebx
f0104211:	83 ec 14             	sub    $0x14,%esp
f0104214:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f0104217:	8b 03                	mov    (%ebx),%eax
f0104219:	89 44 24 04          	mov    %eax,0x4(%esp)
f010421d:	c7 04 24 c7 74 10 f0 	movl   $0xf01074c7,(%esp)
f0104224:	e8 53 fc ff ff       	call   f0103e7c <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f0104229:	8b 43 04             	mov    0x4(%ebx),%eax
f010422c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104230:	c7 04 24 d6 74 10 f0 	movl   $0xf01074d6,(%esp)
f0104237:	e8 40 fc ff ff       	call   f0103e7c <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f010423c:	8b 43 08             	mov    0x8(%ebx),%eax
f010423f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104243:	c7 04 24 e5 74 10 f0 	movl   $0xf01074e5,(%esp)
f010424a:	e8 2d fc ff ff       	call   f0103e7c <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f010424f:	8b 43 0c             	mov    0xc(%ebx),%eax
f0104252:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104256:	c7 04 24 f4 74 10 f0 	movl   $0xf01074f4,(%esp)
f010425d:	e8 1a fc ff ff       	call   f0103e7c <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f0104262:	8b 43 10             	mov    0x10(%ebx),%eax
f0104265:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104269:	c7 04 24 03 75 10 f0 	movl   $0xf0107503,(%esp)
f0104270:	e8 07 fc ff ff       	call   f0103e7c <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0104275:	8b 43 14             	mov    0x14(%ebx),%eax
f0104278:	89 44 24 04          	mov    %eax,0x4(%esp)
f010427c:	c7 04 24 12 75 10 f0 	movl   $0xf0107512,(%esp)
f0104283:	e8 f4 fb ff ff       	call   f0103e7c <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f0104288:	8b 43 18             	mov    0x18(%ebx),%eax
f010428b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010428f:	c7 04 24 21 75 10 f0 	movl   $0xf0107521,(%esp)
f0104296:	e8 e1 fb ff ff       	call   f0103e7c <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f010429b:	8b 43 1c             	mov    0x1c(%ebx),%eax
f010429e:	89 44 24 04          	mov    %eax,0x4(%esp)
f01042a2:	c7 04 24 30 75 10 f0 	movl   $0xf0107530,(%esp)
f01042a9:	e8 ce fb ff ff       	call   f0103e7c <cprintf>
}
f01042ae:	83 c4 14             	add    $0x14,%esp
f01042b1:	5b                   	pop    %ebx
f01042b2:	5d                   	pop    %ebp
f01042b3:	c3                   	ret    

f01042b4 <print_trapframe>:
	lidt(&idt_pd);
}

void
print_trapframe(struct Trapframe *tf)
{
f01042b4:	55                   	push   %ebp
f01042b5:	89 e5                	mov    %esp,%ebp
f01042b7:	56                   	push   %esi
f01042b8:	53                   	push   %ebx
f01042b9:	83 ec 10             	sub    $0x10,%esp
f01042bc:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
f01042bf:	e8 af 19 00 00       	call   f0105c73 <cpunum>
f01042c4:	89 44 24 08          	mov    %eax,0x8(%esp)
f01042c8:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01042cc:	c7 04 24 94 75 10 f0 	movl   $0xf0107594,(%esp)
f01042d3:	e8 a4 fb ff ff       	call   f0103e7c <cprintf>
	print_regs(&tf->tf_regs);
f01042d8:	89 1c 24             	mov    %ebx,(%esp)
f01042db:	e8 2d ff ff ff       	call   f010420d <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f01042e0:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f01042e4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01042e8:	c7 04 24 b2 75 10 f0 	movl   $0xf01075b2,(%esp)
f01042ef:	e8 88 fb ff ff       	call   f0103e7c <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f01042f4:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f01042f8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01042fc:	c7 04 24 c5 75 10 f0 	movl   $0xf01075c5,(%esp)
f0104303:	e8 74 fb ff ff       	call   f0103e7c <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0104308:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f010430b:	83 f8 13             	cmp    $0x13,%eax
f010430e:	77 09                	ja     f0104319 <print_trapframe+0x65>
		return excnames[trapno];
f0104310:	8b 14 85 80 78 10 f0 	mov    -0xfef8780(,%eax,4),%edx
f0104317:	eb 1f                	jmp    f0104338 <print_trapframe+0x84>
	if (trapno == T_SYSCALL)
f0104319:	83 f8 30             	cmp    $0x30,%eax
f010431c:	74 15                	je     f0104333 <print_trapframe+0x7f>
		return "System call";
	if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16)
f010431e:	8d 50 e0             	lea    -0x20(%eax),%edx
		return "Hardware Interrupt";
f0104321:	83 fa 0f             	cmp    $0xf,%edx
f0104324:	ba 4b 75 10 f0       	mov    $0xf010754b,%edx
f0104329:	b9 5e 75 10 f0       	mov    $0xf010755e,%ecx
f010432e:	0f 47 d1             	cmova  %ecx,%edx
f0104331:	eb 05                	jmp    f0104338 <print_trapframe+0x84>
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
		return excnames[trapno];
	if (trapno == T_SYSCALL)
		return "System call";
f0104333:	ba 3f 75 10 f0       	mov    $0xf010753f,%edx
{
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0104338:	89 54 24 08          	mov    %edx,0x8(%esp)
f010433c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104340:	c7 04 24 d8 75 10 f0 	movl   $0xf01075d8,(%esp)
f0104347:	e8 30 fb ff ff       	call   f0103e7c <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f010434c:	3b 1d 60 2a 22 f0    	cmp    0xf0222a60,%ebx
f0104352:	75 19                	jne    f010436d <print_trapframe+0xb9>
f0104354:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104358:	75 13                	jne    f010436d <print_trapframe+0xb9>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f010435a:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f010435d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104361:	c7 04 24 ea 75 10 f0 	movl   $0xf01075ea,(%esp)
f0104368:	e8 0f fb ff ff       	call   f0103e7c <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f010436d:	8b 43 2c             	mov    0x2c(%ebx),%eax
f0104370:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104374:	c7 04 24 f9 75 10 f0 	movl   $0xf01075f9,(%esp)
f010437b:	e8 fc fa ff ff       	call   f0103e7c <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f0104380:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104384:	75 51                	jne    f01043d7 <print_trapframe+0x123>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f0104386:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f0104389:	89 c2                	mov    %eax,%edx
f010438b:	83 e2 01             	and    $0x1,%edx
f010438e:	ba 6d 75 10 f0       	mov    $0xf010756d,%edx
f0104393:	b9 78 75 10 f0       	mov    $0xf0107578,%ecx
f0104398:	0f 45 ca             	cmovne %edx,%ecx
f010439b:	89 c2                	mov    %eax,%edx
f010439d:	83 e2 02             	and    $0x2,%edx
f01043a0:	ba 84 75 10 f0       	mov    $0xf0107584,%edx
f01043a5:	be 8a 75 10 f0       	mov    $0xf010758a,%esi
f01043aa:	0f 44 d6             	cmove  %esi,%edx
f01043ad:	83 e0 04             	and    $0x4,%eax
f01043b0:	b8 8f 75 10 f0       	mov    $0xf010758f,%eax
f01043b5:	be f9 76 10 f0       	mov    $0xf01076f9,%esi
f01043ba:	0f 44 c6             	cmove  %esi,%eax
f01043bd:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01043c1:	89 54 24 08          	mov    %edx,0x8(%esp)
f01043c5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01043c9:	c7 04 24 07 76 10 f0 	movl   $0xf0107607,(%esp)
f01043d0:	e8 a7 fa ff ff       	call   f0103e7c <cprintf>
f01043d5:	eb 0c                	jmp    f01043e3 <print_trapframe+0x12f>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f01043d7:	c7 04 24 8c 71 10 f0 	movl   $0xf010718c,(%esp)
f01043de:	e8 99 fa ff ff       	call   f0103e7c <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f01043e3:	8b 43 30             	mov    0x30(%ebx),%eax
f01043e6:	89 44 24 04          	mov    %eax,0x4(%esp)
f01043ea:	c7 04 24 16 76 10 f0 	movl   $0xf0107616,(%esp)
f01043f1:	e8 86 fa ff ff       	call   f0103e7c <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f01043f6:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f01043fa:	89 44 24 04          	mov    %eax,0x4(%esp)
f01043fe:	c7 04 24 25 76 10 f0 	movl   $0xf0107625,(%esp)
f0104405:	e8 72 fa ff ff       	call   f0103e7c <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f010440a:	8b 43 38             	mov    0x38(%ebx),%eax
f010440d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104411:	c7 04 24 38 76 10 f0 	movl   $0xf0107638,(%esp)
f0104418:	e8 5f fa ff ff       	call   f0103e7c <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f010441d:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f0104421:	74 27                	je     f010444a <print_trapframe+0x196>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f0104423:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0104426:	89 44 24 04          	mov    %eax,0x4(%esp)
f010442a:	c7 04 24 47 76 10 f0 	movl   $0xf0107647,(%esp)
f0104431:	e8 46 fa ff ff       	call   f0103e7c <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f0104436:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f010443a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010443e:	c7 04 24 56 76 10 f0 	movl   $0xf0107656,(%esp)
f0104445:	e8 32 fa ff ff       	call   f0103e7c <cprintf>
	}
}
f010444a:	83 c4 10             	add    $0x10,%esp
f010444d:	5b                   	pop    %ebx
f010444e:	5e                   	pop    %esi
f010444f:	5d                   	pop    %ebp
f0104450:	c3                   	ret    

f0104451 <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f0104451:	55                   	push   %ebp
f0104452:	89 e5                	mov    %esp,%ebp
f0104454:	56                   	push   %esi
f0104455:	53                   	push   %ebx
f0104456:	83 ec 10             	sub    $0x10,%esp
f0104459:	8b 45 08             	mov    0x8(%ebp),%eax
f010445c:	0f 20 d3             	mov    %cr2,%ebx
	uint32_t fault_va;

	// Read processor's CR2 register to find the faulting address
	fault_va = rcr2();
	if((tf->tf_cs & 3)==0) // last three bits 000 means DPL_Kern
f010445f:	f6 40 34 03          	testb  $0x3,0x34(%eax)
f0104463:	75 1c                	jne    f0104481 <page_fault_handler+0x30>
	{
		panic("kernel mode page faults!!");
f0104465:	c7 44 24 08 69 76 10 	movl   $0xf0107669,0x8(%esp)
f010446c:	f0 
f010446d:	c7 44 24 04 3f 01 00 	movl   $0x13f,0x4(%esp)
f0104474:	00 
f0104475:	c7 04 24 83 76 10 f0 	movl   $0xf0107683,(%esp)
f010447c:	e8 bf bb ff ff       	call   f0100040 <_panic>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104481:	8b 70 30             	mov    0x30(%eax),%esi
		curenv->env_id, fault_va, tf->tf_eip);
f0104484:	e8 ea 17 00 00       	call   f0105c73 <cpunum>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104489:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010448d:	89 5c 24 08          	mov    %ebx,0x8(%esp)
		curenv->env_id, fault_va, tf->tf_eip);
f0104491:	6b c0 74             	imul   $0x74,%eax,%eax
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104494:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f010449a:	8b 40 48             	mov    0x48(%eax),%eax
f010449d:	89 44 24 04          	mov    %eax,0x4(%esp)
f01044a1:	c7 04 24 44 78 10 f0 	movl   $0xf0107844,(%esp)
f01044a8:	e8 cf f9 ff ff       	call   f0103e7c <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
	//print_trapframe(tf);
	env_destroy(curenv);
f01044ad:	e8 c1 17 00 00       	call   f0105c73 <cpunum>
f01044b2:	6b c0 74             	imul   $0x74,%eax,%eax
f01044b5:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f01044bb:	89 04 24             	mov    %eax,(%esp)
f01044be:	e8 15 f7 ff ff       	call   f0103bd8 <env_destroy>
}
f01044c3:	83 c4 10             	add    $0x10,%esp
f01044c6:	5b                   	pop    %ebx
f01044c7:	5e                   	pop    %esi
f01044c8:	5d                   	pop    %ebp
f01044c9:	c3                   	ret    

f01044ca <trap>:



void
trap(struct Trapframe *tf)
{
f01044ca:	55                   	push   %ebp
f01044cb:	89 e5                	mov    %esp,%ebp
f01044cd:	57                   	push   %edi
f01044ce:	56                   	push   %esi
f01044cf:	83 ec 20             	sub    $0x20,%esp
f01044d2:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f01044d5:	fc                   	cld    

	// Halt the CPU if some other CPU has called panic()
	extern char *panicstr;
	if (panicstr)
f01044d6:	83 3d 00 2f 22 f0 00 	cmpl   $0x0,0xf0222f00
f01044dd:	74 01                	je     f01044e0 <trap+0x16>
		asm volatile("hlt");
f01044df:	f4                   	hlt    

static __inline uint32_t
read_eflags(void)
{
        uint32_t eflags;
        __asm __volatile("pushfl; popl %0" : "=r" (eflags));
f01044e0:	9c                   	pushf  
f01044e1:	58                   	pop    %eax

	// Check that interrupts are disabled.  If this assertion
	// fails, DO NOT be tempted to fix it by inserting a "cli" in
	// the interrupt path.
	assert(!(read_eflags() & FL_IF));
f01044e2:	f6 c4 02             	test   $0x2,%ah
f01044e5:	74 24                	je     f010450b <trap+0x41>
f01044e7:	c7 44 24 0c 8f 76 10 	movl   $0xf010768f,0xc(%esp)
f01044ee:	f0 
f01044ef:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f01044f6:	f0 
f01044f7:	c7 44 24 04 0b 01 00 	movl   $0x10b,0x4(%esp)
f01044fe:	00 
f01044ff:	c7 04 24 83 76 10 f0 	movl   $0xf0107683,(%esp)
f0104506:	e8 35 bb ff ff       	call   f0100040 <_panic>
	
	cprintf("Incoming TRAP frame at %p\n", tf);
f010450b:	89 74 24 04          	mov    %esi,0x4(%esp)
f010450f:	c7 04 24 a8 76 10 f0 	movl   $0xf01076a8,(%esp)
f0104516:	e8 61 f9 ff ff       	call   f0103e7c <cprintf>

	if ((tf->tf_cs & 3) == 3) {
f010451b:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f010451f:	83 e0 03             	and    $0x3,%eax
f0104522:	66 83 f8 03          	cmp    $0x3,%ax
f0104526:	0f 85 9b 00 00 00    	jne    f01045c7 <trap+0xfd>
		// Trapped from user mode.
		// Acquire the big kernel lock before doing any
		// serious kernel work.
		// LAB 4: Your code here.
		assert(curenv);
f010452c:	e8 42 17 00 00       	call   f0105c73 <cpunum>
f0104531:	6b c0 74             	imul   $0x74,%eax,%eax
f0104534:	83 b8 28 30 22 f0 00 	cmpl   $0x0,-0xfddcfd8(%eax)
f010453b:	75 24                	jne    f0104561 <trap+0x97>
f010453d:	c7 44 24 0c c3 76 10 	movl   $0xf01076c3,0xc(%esp)
f0104544:	f0 
f0104545:	c7 44 24 08 17 71 10 	movl   $0xf0107117,0x8(%esp)
f010454c:	f0 
f010454d:	c7 44 24 04 14 01 00 	movl   $0x114,0x4(%esp)
f0104554:	00 
f0104555:	c7 04 24 83 76 10 f0 	movl   $0xf0107683,(%esp)
f010455c:	e8 df ba ff ff       	call   f0100040 <_panic>

		// Garbage collect if current enviroment is a zombie
		if (curenv->env_status == ENV_DYING) {
f0104561:	e8 0d 17 00 00       	call   f0105c73 <cpunum>
f0104566:	6b c0 74             	imul   $0x74,%eax,%eax
f0104569:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f010456f:	83 78 54 01          	cmpl   $0x1,0x54(%eax)
f0104573:	75 2d                	jne    f01045a2 <trap+0xd8>
			env_free(curenv);
f0104575:	e8 f9 16 00 00       	call   f0105c73 <cpunum>
f010457a:	6b c0 74             	imul   $0x74,%eax,%eax
f010457d:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f0104583:	89 04 24             	mov    %eax,(%esp)
f0104586:	e8 48 f4 ff ff       	call   f01039d3 <env_free>
			curenv = NULL;
f010458b:	e8 e3 16 00 00       	call   f0105c73 <cpunum>
f0104590:	6b c0 74             	imul   $0x74,%eax,%eax
f0104593:	c7 80 28 30 22 f0 00 	movl   $0x0,-0xfddcfd8(%eax)
f010459a:	00 00 00 
			sched_yield();
f010459d:	e8 9f 01 00 00       	call   f0104741 <sched_yield>
		}

		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		curenv->env_tf = *tf;
f01045a2:	e8 cc 16 00 00       	call   f0105c73 <cpunum>
f01045a7:	6b c0 74             	imul   $0x74,%eax,%eax
f01045aa:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f01045b0:	b9 11 00 00 00       	mov    $0x11,%ecx
f01045b5:	89 c7                	mov    %eax,%edi
f01045b7:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f01045b9:	e8 b5 16 00 00       	call   f0105c73 <cpunum>
f01045be:	6b c0 74             	imul   $0x74,%eax,%eax
f01045c1:	8b b0 28 30 22 f0    	mov    -0xfddcfd8(%eax),%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f01045c7:	89 35 60 2a 22 f0    	mov    %esi,0xf0222a60
}
static void
trap_dispatch(struct Trapframe *tf)
{
	// Handle processor exceptions.
	print_trapframe(tf);
f01045cd:	89 34 24             	mov    %esi,(%esp)
f01045d0:	e8 df fc ff ff       	call   f01042b4 <print_trapframe>
	// LAB 3: Your code here.

	// Handle spurious interrupts
	// The hardware sometimes raises these because of noise on the
	// IRQ line or other reasons. We don't care.
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_SPURIOUS) {
f01045d5:	8b 46 28             	mov    0x28(%esi),%eax
f01045d8:	83 f8 27             	cmp    $0x27,%eax
f01045db:	75 19                	jne    f01045f6 <trap+0x12c>
		cprintf("Spurious interrupt on irq 7\n");
f01045dd:	c7 04 24 ca 76 10 f0 	movl   $0xf01076ca,(%esp)
f01045e4:	e8 93 f8 ff ff       	call   f0103e7c <cprintf>
		print_trapframe(tf);
f01045e9:	89 34 24             	mov    %esi,(%esp)
f01045ec:	e8 c3 fc ff ff       	call   f01042b4 <print_trapframe>
f01045f1:	e9 93 00 00 00       	jmp    f0104689 <trap+0x1bf>

	// Handle clock interrupts. Don't forget to acknowledge the
	// interrupt using lapic_eoi() before calling the scheduler!
	// LAB 4: Your code here.

	if(tf->tf_trapno==T_PGFLT)
f01045f6:	83 f8 0e             	cmp    $0xe,%eax
f01045f9:	75 0f                	jne    f010460a <trap+0x140>
	{
		page_fault_handler(tf);
f01045fb:	89 34 24             	mov    %esi,(%esp)
f01045fe:	66 90                	xchg   %ax,%ax
f0104600:	e8 4c fe ff ff       	call   f0104451 <page_fault_handler>
f0104605:	e9 7f 00 00 00       	jmp    f0104689 <trap+0x1bf>
		return;
	}
	if(tf->tf_trapno==T_BRKPT)
f010460a:	83 f8 03             	cmp    $0x3,%eax
f010460d:	75 0a                	jne    f0104619 <trap+0x14f>
	{
		monitor(tf);
f010460f:	89 34 24             	mov    %esi,(%esp)
f0104612:	e8 ab c3 ff ff       	call   f01009c2 <monitor>
f0104617:	eb 70                	jmp    f0104689 <trap+0x1bf>
		return;
	}
	if(tf->tf_trapno==T_SYSCALL)
f0104619:	83 f8 30             	cmp    $0x30,%eax
f010461c:	75 32                	jne    f0104650 <trap+0x186>
	{
		tf->tf_regs.reg_eax=syscall(tf->tf_regs.reg_eax,tf->tf_regs.reg_edx,tf->tf_regs.reg_ecx,tf->tf_regs.reg_ebx,tf->tf_regs.reg_edi,tf->tf_regs.reg_esi);
f010461e:	8b 46 04             	mov    0x4(%esi),%eax
f0104621:	89 44 24 14          	mov    %eax,0x14(%esp)
f0104625:	8b 06                	mov    (%esi),%eax
f0104627:	89 44 24 10          	mov    %eax,0x10(%esp)
f010462b:	8b 46 10             	mov    0x10(%esi),%eax
f010462e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104632:	8b 46 18             	mov    0x18(%esi),%eax
f0104635:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104639:	8b 46 14             	mov    0x14(%esi),%eax
f010463c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104640:	8b 46 1c             	mov    0x1c(%esi),%eax
f0104643:	89 04 24             	mov    %eax,(%esp)
f0104646:	e8 95 01 00 00       	call   f01047e0 <syscall>
f010464b:	89 46 1c             	mov    %eax,0x1c(%esi)
f010464e:	eb 39                	jmp    f0104689 <trap+0x1bf>
	    return;
	}
	// Unexpected trap: The user process or the kernel has a bug.

	if (tf->tf_cs == GD_KT)
f0104650:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f0104655:	75 1c                	jne    f0104673 <trap+0x1a9>
		panic("unhandled trap in kernel");
f0104657:	c7 44 24 08 e7 76 10 	movl   $0xf01076e7,0x8(%esp)
f010465e:	f0 
f010465f:	c7 44 24 04 f3 00 00 	movl   $0xf3,0x4(%esp)
f0104666:	00 
f0104667:	c7 04 24 83 76 10 f0 	movl   $0xf0107683,(%esp)
f010466e:	e8 cd b9 ff ff       	call   f0100040 <_panic>
	else {
		env_destroy(curenv);
f0104673:	e8 fb 15 00 00       	call   f0105c73 <cpunum>
f0104678:	6b c0 74             	imul   $0x74,%eax,%eax
f010467b:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f0104681:	89 04 24             	mov    %eax,(%esp)
f0104684:	e8 4f f5 ff ff       	call   f0103bd8 <env_destroy>
	trap_dispatch(tf);

	// If we made it to this point, then no other environment was
	// scheduled, so we should return to the current environment
	// if doing so makes sense.
	if (curenv && curenv->env_status == ENV_RUNNING)
f0104689:	e8 e5 15 00 00       	call   f0105c73 <cpunum>
f010468e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104691:	83 b8 28 30 22 f0 00 	cmpl   $0x0,-0xfddcfd8(%eax)
f0104698:	74 2a                	je     f01046c4 <trap+0x1fa>
f010469a:	e8 d4 15 00 00       	call   f0105c73 <cpunum>
f010469f:	6b c0 74             	imul   $0x74,%eax,%eax
f01046a2:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f01046a8:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f01046ac:	75 16                	jne    f01046c4 <trap+0x1fa>
		env_run(curenv);
f01046ae:	e8 c0 15 00 00       	call   f0105c73 <cpunum>
f01046b3:	6b c0 74             	imul   $0x74,%eax,%eax
f01046b6:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f01046bc:	89 04 24             	mov    %eax,(%esp)
f01046bf:	e8 b5 f5 ff ff       	call   f0103c79 <env_run>
	else
		sched_yield();
f01046c4:	e8 78 00 00 00       	call   f0104741 <sched_yield>
f01046c9:	90                   	nop

f01046ca <dividezero_handler>:
.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
f01046ca:	6a 00                	push   $0x0
f01046cc:	6a 00                	push   $0x0
f01046ce:	eb 58                	jmp    f0104728 <_alltraps>

f01046d0 <nmi_handler>:
TRAPHANDLER_NOEC(nmi_handler, 0x2)
f01046d0:	6a 00                	push   $0x0
f01046d2:	6a 02                	push   $0x2
f01046d4:	eb 52                	jmp    f0104728 <_alltraps>

f01046d6 <breakpoint_handler>:
TRAPHANDLER_NOEC(breakpoint_handler, 0x3)
f01046d6:	6a 00                	push   $0x0
f01046d8:	6a 03                	push   $0x3
f01046da:	eb 4c                	jmp    f0104728 <_alltraps>

f01046dc <overflow_handler>:
TRAPHANDLER_NOEC(overflow_handler, 0x4)
f01046dc:	6a 00                	push   $0x0
f01046de:	6a 04                	push   $0x4
f01046e0:	eb 46                	jmp    f0104728 <_alltraps>

f01046e2 <bdrgeexceed_handler>:
TRAPHANDLER_NOEC(bdrgeexceed_handler, 0x5)
f01046e2:	6a 00                	push   $0x0
f01046e4:	6a 05                	push   $0x5
f01046e6:	eb 40                	jmp    f0104728 <_alltraps>

f01046e8 <invalidop_handler>:
TRAPHANDLER_NOEC(invalidop_handler, 0x6)
f01046e8:	6a 00                	push   $0x0
f01046ea:	6a 06                	push   $0x6
f01046ec:	eb 3a                	jmp    f0104728 <_alltraps>

f01046ee <nomathcopro_handler>:
TRAPHANDLER_NOEC(nomathcopro_handler, 0x7)
f01046ee:	6a 00                	push   $0x0
f01046f0:	6a 07                	push   $0x7
f01046f2:	eb 34                	jmp    f0104728 <_alltraps>

f01046f4 <dbfault_handler>:
TRAPHANDLER(dbfault_handler, 0x8)
f01046f4:	6a 08                	push   $0x8
f01046f6:	eb 30                	jmp    f0104728 <_alltraps>

f01046f8 <invalidTSS_handler>:
TRAPHANDLER(invalidTSS_handler, 0xA)
f01046f8:	6a 0a                	push   $0xa
f01046fa:	eb 2c                	jmp    f0104728 <_alltraps>

f01046fc <sgmtnotpresent_handler>:
TRAPHANDLER(sgmtnotpresent_handler, 0xB)
f01046fc:	6a 0b                	push   $0xb
f01046fe:	eb 28                	jmp    f0104728 <_alltraps>

f0104700 <stacksgmtfault_handler>:
TRAPHANDLER(stacksgmtfault_handler,0xC)
f0104700:	6a 0c                	push   $0xc
f0104702:	eb 24                	jmp    f0104728 <_alltraps>

f0104704 <generalprotection_handler>:
TRAPHANDLER(generalprotection_handler, 0xD)
f0104704:	6a 0d                	push   $0xd
f0104706:	eb 20                	jmp    f0104728 <_alltraps>

f0104708 <pagefault_handler>:
TRAPHANDLER(pagefault_handler, 0xE)
f0104708:	6a 0e                	push   $0xe
f010470a:	eb 1c                	jmp    f0104728 <_alltraps>

f010470c <FPUerror_handler>:
TRAPHANDLER_NOEC(FPUerror_handler, 0x10)
f010470c:	6a 00                	push   $0x0
f010470e:	6a 10                	push   $0x10
f0104710:	eb 16                	jmp    f0104728 <_alltraps>

f0104712 <alignmentcheck_handler>:
TRAPHANDLER(alignmentcheck_handler, 0x11)
f0104712:	6a 11                	push   $0x11
f0104714:	eb 12                	jmp    f0104728 <_alltraps>

f0104716 <machinecheck_handler>:
TRAPHANDLER_NOEC(machinecheck_handler, 0x12)
f0104716:	6a 00                	push   $0x0
f0104718:	6a 12                	push   $0x12
f010471a:	eb 0c                	jmp    f0104728 <_alltraps>

f010471c <SIMDFPexception_handler>:
TRAPHANDLER_NOEC(SIMDFPexception_handler, 0x13)
f010471c:	6a 00                	push   $0x0
f010471e:	6a 13                	push   $0x13
f0104720:	eb 06                	jmp    f0104728 <_alltraps>

f0104722 <systemcall_handler>:
TRAPHANDLER_NOEC(systemcall_handler, 0x30)
f0104722:	6a 00                	push   $0x0
f0104724:	6a 30                	push   $0x30
f0104726:	eb 00                	jmp    f0104728 <_alltraps>

f0104728 <_alltraps>:
/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
	pushw $0
f0104728:	66 6a 00             	pushw  $0x0
	pushw %ds
f010472b:	66 1e                	pushw  %ds
	pushw $0
f010472d:	66 6a 00             	pushw  $0x0
	pushw %es
f0104730:	66 06                	pushw  %es
	pushal
f0104732:	60                   	pusha  
	pushl %esp
f0104733:	54                   	push   %esp
	movw $(GD_KD),%ax
f0104734:	66 b8 10 00          	mov    $0x10,%ax
	movw %ax,%ds
f0104738:	8e d8                	mov    %eax,%ds
	movw %ax,%es
f010473a:	8e c0                	mov    %eax,%es
	call trap
f010473c:	e8 89 fd ff ff       	call   f01044ca <trap>

f0104741 <sched_yield>:


// Choose a user environment to run and run it.
void
sched_yield(void)
{
f0104741:	55                   	push   %ebp
f0104742:	89 e5                	mov    %esp,%ebp
f0104744:	53                   	push   %ebx
f0104745:	83 ec 14             	sub    $0x14,%esp

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104748:	8b 1d 48 22 22 f0    	mov    0xf0222248,%ebx
f010474e:	89 d8                	mov    %ebx,%eax
	// LAB 4: Your code here.

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0104750:	ba 00 00 00 00       	mov    $0x0,%edx
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104755:	83 78 50 01          	cmpl   $0x1,0x50(%eax)
f0104759:	74 0b                	je     f0104766 <sched_yield+0x25>
		    (envs[i].env_status == ENV_RUNNABLE ||
f010475b:	8b 48 54             	mov    0x54(%eax),%ecx
f010475e:	83 e9 02             	sub    $0x2,%ecx

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104761:	83 f9 01             	cmp    $0x1,%ecx
f0104764:	76 10                	jbe    f0104776 <sched_yield+0x35>
	// LAB 4: Your code here.

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0104766:	83 c2 01             	add    $0x1,%edx
f0104769:	83 c0 7c             	add    $0x7c,%eax
f010476c:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104772:	75 e1                	jne    f0104755 <sched_yield+0x14>
f0104774:	eb 08                	jmp    f010477e <sched_yield+0x3d>
		if (envs[i].env_type != ENV_TYPE_IDLE &&
		    (envs[i].env_status == ENV_RUNNABLE ||
		     envs[i].env_status == ENV_RUNNING))
			break;
	}
	if (i == NENV) {
f0104776:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f010477c:	75 1a                	jne    f0104798 <sched_yield+0x57>
		cprintf("No more runnable environments!\n");
f010477e:	c7 04 24 d0 78 10 f0 	movl   $0xf01078d0,(%esp)
f0104785:	e8 f2 f6 ff ff       	call   f0103e7c <cprintf>
		while (1)
			monitor(NULL);
f010478a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0104791:	e8 2c c2 ff ff       	call   f01009c2 <monitor>
f0104796:	eb f2                	jmp    f010478a <sched_yield+0x49>
	}

	// Run this CPU's idle environment when nothing else is runnable.
	idle = &envs[cpunum()];
f0104798:	e8 d6 14 00 00       	call   f0105c73 <cpunum>
f010479d:	6b c0 7c             	imul   $0x7c,%eax,%eax
f01047a0:	01 c3                	add    %eax,%ebx
	if (!(idle->env_status == ENV_RUNNABLE || idle->env_status == ENV_RUNNING))
f01047a2:	8b 43 54             	mov    0x54(%ebx),%eax
f01047a5:	83 e8 02             	sub    $0x2,%eax
f01047a8:	83 f8 01             	cmp    $0x1,%eax
f01047ab:	76 25                	jbe    f01047d2 <sched_yield+0x91>
		panic("CPU %d: No idle environment!", cpunum());
f01047ad:	e8 c1 14 00 00       	call   f0105c73 <cpunum>
f01047b2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01047b6:	c7 44 24 08 f0 78 10 	movl   $0xf01078f0,0x8(%esp)
f01047bd:	f0 
f01047be:	c7 44 24 04 33 00 00 	movl   $0x33,0x4(%esp)
f01047c5:	00 
f01047c6:	c7 04 24 0d 79 10 f0 	movl   $0xf010790d,(%esp)
f01047cd:	e8 6e b8 ff ff       	call   f0100040 <_panic>
	env_run(idle);
f01047d2:	89 1c 24             	mov    %ebx,(%esp)
f01047d5:	e8 9f f4 ff ff       	call   f0103c79 <env_run>
f01047da:	66 90                	xchg   %ax,%ax
f01047dc:	66 90                	xchg   %ax,%ax
f01047de:	66 90                	xchg   %ax,%ax

f01047e0 <syscall>:
}

// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
f01047e0:	55                   	push   %ebp
f01047e1:	89 e5                	mov    %esp,%ebp
f01047e3:	53                   	push   %ebx
f01047e4:	83 ec 24             	sub    $0x24,%esp
f01047e7:	8b 45 08             	mov    0x8(%ebp),%eax
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
	switch(syscallno){
f01047ea:	83 f8 01             	cmp    $0x1,%eax
f01047ed:	74 66                	je     f0104855 <syscall+0x75>
f01047ef:	83 f8 01             	cmp    $0x1,%eax
f01047f2:	72 11                	jb     f0104805 <syscall+0x25>
f01047f4:	83 f8 02             	cmp    $0x2,%eax
f01047f7:	74 66                	je     f010485f <syscall+0x7f>
f01047f9:	83 f8 03             	cmp    $0x3,%eax
f01047fc:	74 78                	je     f0104876 <syscall+0x96>
f01047fe:	66 90                	xchg   %ax,%ax
f0104800:	e9 03 01 00 00       	jmp    f0104908 <syscall+0x128>
static void
sys_cputs(const char *s, size_t len)
{
	// Check that the user has permission to read memory [s, s+len).
	// Destroy the environment if not.
	user_mem_assert(curenv,s,len,0);
f0104805:	e8 69 14 00 00       	call   f0105c73 <cpunum>
f010480a:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104811:	00 
f0104812:	8b 4d 10             	mov    0x10(%ebp),%ecx
f0104815:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104819:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010481c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104820:	6b c0 74             	imul   $0x74,%eax,%eax
f0104823:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f0104829:	89 04 24             	mov    %eax,(%esp)
f010482c:	e8 66 ec ff ff       	call   f0103497 <user_mem_assert>
	// LAB 3: Your code here.
	// Print the string supplied by the user.
	cprintf("%.*s", len, s);
f0104831:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104834:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104838:	8b 45 10             	mov    0x10(%ebp),%eax
f010483b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010483f:	c7 04 24 1a 79 10 f0 	movl   $0xf010791a,(%esp)
f0104846:	e8 31 f6 ff ff       	call   f0103e7c <cprintf>
	// Return any appropriate return value.
	// LAB 3: Your code here.
	switch(syscallno){
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
f010484b:	b8 00 00 00 00       	mov    $0x0,%eax
f0104850:	e9 b8 00 00 00       	jmp    f010490d <syscall+0x12d>
// Read a character from the system console without blocking.
// Returns the character, or 0 if there is no input waiting.
static int
sys_cgetc(void)
{
	return cons_getc();
f0104855:	e8 0b be ff ff       	call   f0100665 <cons_getc>
	switch(syscallno){
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case(SYS_cgetc):
			return sys_cgetc();
f010485a:	e9 ae 00 00 00       	jmp    f010490d <syscall+0x12d>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f010485f:	90                   	nop
f0104860:	e8 0e 14 00 00       	call   f0105c73 <cpunum>
f0104865:	6b c0 74             	imul   $0x74,%eax,%eax
f0104868:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f010486e:	8b 40 48             	mov    0x48(%eax),%eax
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case(SYS_cgetc):
			return sys_cgetc();
		case(SYS_getenvid):
			return sys_getenvid();
f0104871:	e9 97 00 00 00       	jmp    f010490d <syscall+0x12d>
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104876:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010487d:	00 
f010487e:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0104881:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104885:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104888:	89 04 24             	mov    %eax,(%esp)
f010488b:	e8 5f ec ff ff       	call   f01034ef <envid2env>
		return r;
f0104890:	89 c2                	mov    %eax,%edx
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104892:	85 c0                	test   %eax,%eax
f0104894:	78 6e                	js     f0104904 <syscall+0x124>
		return r;
	if (e == curenv)
f0104896:	e8 d8 13 00 00       	call   f0105c73 <cpunum>
f010489b:	8b 55 f4             	mov    -0xc(%ebp),%edx
f010489e:	6b c0 74             	imul   $0x74,%eax,%eax
f01048a1:	39 90 28 30 22 f0    	cmp    %edx,-0xfddcfd8(%eax)
f01048a7:	75 23                	jne    f01048cc <syscall+0xec>
		cprintf("[%08x] exiting gracefully\n", curenv->env_id);
f01048a9:	e8 c5 13 00 00       	call   f0105c73 <cpunum>
f01048ae:	6b c0 74             	imul   $0x74,%eax,%eax
f01048b1:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f01048b7:	8b 40 48             	mov    0x48(%eax),%eax
f01048ba:	89 44 24 04          	mov    %eax,0x4(%esp)
f01048be:	c7 04 24 1f 79 10 f0 	movl   $0xf010791f,(%esp)
f01048c5:	e8 b2 f5 ff ff       	call   f0103e7c <cprintf>
f01048ca:	eb 28                	jmp    f01048f4 <syscall+0x114>
	else
		cprintf("[%08x] destroying %08x\n", curenv->env_id, e->env_id);
f01048cc:	8b 5a 48             	mov    0x48(%edx),%ebx
f01048cf:	e8 9f 13 00 00       	call   f0105c73 <cpunum>
f01048d4:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f01048d8:	6b c0 74             	imul   $0x74,%eax,%eax
f01048db:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f01048e1:	8b 40 48             	mov    0x48(%eax),%eax
f01048e4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01048e8:	c7 04 24 3a 79 10 f0 	movl   $0xf010793a,(%esp)
f01048ef:	e8 88 f5 ff ff       	call   f0103e7c <cprintf>
	env_destroy(e);
f01048f4:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01048f7:	89 04 24             	mov    %eax,(%esp)
f01048fa:	e8 d9 f2 ff ff       	call   f0103bd8 <env_destroy>
	return 0;
f01048ff:	ba 00 00 00 00       	mov    $0x0,%edx
		case(SYS_cgetc):
			return sys_cgetc();
		case(SYS_getenvid):
			return sys_getenvid();
		case(SYS_env_destroy):
			return sys_env_destroy((envid_t) a1);
f0104904:	89 d0                	mov    %edx,%eax
f0104906:	eb 05                	jmp    f010490d <syscall+0x12d>
		default:
			return -E_INVAL;
f0104908:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
	}
	//panic("syscall not implemented");
}
f010490d:	83 c4 24             	add    $0x24,%esp
f0104910:	5b                   	pop    %ebx
f0104911:	5d                   	pop    %ebp
f0104912:	c3                   	ret    
f0104913:	66 90                	xchg   %ax,%ax
f0104915:	66 90                	xchg   %ax,%ax
f0104917:	66 90                	xchg   %ax,%ax
f0104919:	66 90                	xchg   %ax,%ax
f010491b:	66 90                	xchg   %ax,%ax
f010491d:	66 90                	xchg   %ax,%ax
f010491f:	90                   	nop

f0104920 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0104920:	55                   	push   %ebp
f0104921:	89 e5                	mov    %esp,%ebp
f0104923:	57                   	push   %edi
f0104924:	56                   	push   %esi
f0104925:	53                   	push   %ebx
f0104926:	83 ec 14             	sub    $0x14,%esp
f0104929:	89 45 ec             	mov    %eax,-0x14(%ebp)
f010492c:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f010492f:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0104932:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0104935:	8b 1a                	mov    (%edx),%ebx
f0104937:	8b 01                	mov    (%ecx),%eax
f0104939:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f010493c:	39 c3                	cmp    %eax,%ebx
f010493e:	0f 8f 9a 00 00 00    	jg     f01049de <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f0104944:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f010494b:	8b 45 f0             	mov    -0x10(%ebp),%eax
f010494e:	01 d8                	add    %ebx,%eax
f0104950:	89 c7                	mov    %eax,%edi
f0104952:	c1 ef 1f             	shr    $0x1f,%edi
f0104955:	01 c7                	add    %eax,%edi
f0104957:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0104959:	39 df                	cmp    %ebx,%edi
f010495b:	0f 8c c4 00 00 00    	jl     f0104a25 <stab_binsearch+0x105>
f0104961:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0104964:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104967:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f010496a:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f010496e:	39 f0                	cmp    %esi,%eax
f0104970:	0f 84 b4 00 00 00    	je     f0104a2a <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104976:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f0104978:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f010497b:	39 d8                	cmp    %ebx,%eax
f010497d:	0f 8c a2 00 00 00    	jl     f0104a25 <stab_binsearch+0x105>
f0104983:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f0104987:	83 ea 0c             	sub    $0xc,%edx
f010498a:	39 f1                	cmp    %esi,%ecx
f010498c:	75 ea                	jne    f0104978 <stab_binsearch+0x58>
f010498e:	e9 99 00 00 00       	jmp    f0104a2c <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0104993:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0104996:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f0104998:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f010499b:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01049a2:	eb 2b                	jmp    f01049cf <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f01049a4:	3b 55 0c             	cmp    0xc(%ebp),%edx
f01049a7:	76 14                	jbe    f01049bd <stab_binsearch+0x9d>
			*region_right = m - 1;
f01049a9:	83 e8 01             	sub    $0x1,%eax
f01049ac:	89 45 f0             	mov    %eax,-0x10(%ebp)
f01049af:	8b 7d e0             	mov    -0x20(%ebp),%edi
f01049b2:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01049b4:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01049bb:	eb 12                	jmp    f01049cf <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f01049bd:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01049c0:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f01049c2:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f01049c6:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01049c8:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f01049cf:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f01049d2:	0f 8e 73 ff ff ff    	jle    f010494b <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f01049d8:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f01049dc:	75 0f                	jne    f01049ed <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f01049de:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01049e1:	8b 00                	mov    (%eax),%eax
f01049e3:	83 e8 01             	sub    $0x1,%eax
f01049e6:	8b 75 e0             	mov    -0x20(%ebp),%esi
f01049e9:	89 06                	mov    %eax,(%esi)
f01049eb:	eb 57                	jmp    f0104a44 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f01049ed:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01049f0:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f01049f2:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01049f5:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f01049f7:	39 c8                	cmp    %ecx,%eax
f01049f9:	7e 23                	jle    f0104a1e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f01049fb:	8d 14 40             	lea    (%eax,%eax,2),%edx
f01049fe:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0104a01:	8d 14 97             	lea    (%edi,%edx,4),%edx
f0104a04:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f0104a08:	39 f3                	cmp    %esi,%ebx
f0104a0a:	74 12                	je     f0104a1e <stab_binsearch+0xfe>
		     l--)
f0104a0c:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104a0f:	39 c8                	cmp    %ecx,%eax
f0104a11:	7e 0b                	jle    f0104a1e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0104a13:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f0104a17:	83 ea 0c             	sub    $0xc,%edx
f0104a1a:	39 f3                	cmp    %esi,%ebx
f0104a1c:	75 ee                	jne    f0104a0c <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f0104a1e:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0104a21:	89 06                	mov    %eax,(%esi)
f0104a23:	eb 1f                	jmp    f0104a44 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0104a25:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0104a28:	eb a5                	jmp    f01049cf <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104a2a:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0104a2c:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104a2f:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104a32:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0104a36:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0104a39:	0f 82 54 ff ff ff    	jb     f0104993 <stab_binsearch+0x73>
f0104a3f:	e9 60 ff ff ff       	jmp    f01049a4 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0104a44:	83 c4 14             	add    $0x14,%esp
f0104a47:	5b                   	pop    %ebx
f0104a48:	5e                   	pop    %esi
f0104a49:	5f                   	pop    %edi
f0104a4a:	5d                   	pop    %ebp
f0104a4b:	c3                   	ret    

f0104a4c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0104a4c:	55                   	push   %ebp
f0104a4d:	89 e5                	mov    %esp,%ebp
f0104a4f:	57                   	push   %edi
f0104a50:	56                   	push   %esi
f0104a51:	53                   	push   %ebx
f0104a52:	83 ec 3c             	sub    $0x3c,%esp
f0104a55:	8b 7d 08             	mov    0x8(%ebp),%edi
f0104a58:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0104a5b:	c7 06 52 79 10 f0    	movl   $0xf0107952,(%esi)
	info->eip_line = 0;
f0104a61:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0104a68:	c7 46 08 52 79 10 f0 	movl   $0xf0107952,0x8(%esi)
	info->eip_fn_namelen = 9;
f0104a6f:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0104a76:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0104a79:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0104a80:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f0104a86:	0f 87 ca 00 00 00    	ja     f0104b56 <debuginfo_eip+0x10a>
		const struct UserStabData *usd = (const struct UserStabData *) USTABDATA;

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
f0104a8c:	e8 e2 11 00 00       	call   f0105c73 <cpunum>
f0104a91:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104a98:	00 
f0104a99:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
f0104aa0:	00 
f0104aa1:	c7 44 24 04 00 00 20 	movl   $0x200000,0x4(%esp)
f0104aa8:	00 
f0104aa9:	6b c0 74             	imul   $0x74,%eax,%eax
f0104aac:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f0104ab2:	89 04 24             	mov    %eax,(%esp)
f0104ab5:	e8 3e e9 ff ff       	call   f01033f8 <user_mem_check>
f0104aba:	85 c0                	test   %eax,%eax
f0104abc:	0f 85 12 02 00 00    	jne    f0104cd4 <debuginfo_eip+0x288>
			return -1;
		stabs = usd->stabs;
f0104ac2:	a1 00 00 20 00       	mov    0x200000,%eax
f0104ac7:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f0104aca:	8b 1d 04 00 20 00    	mov    0x200004,%ebx
		stabstr = usd->stabstr;
f0104ad0:	8b 15 08 00 20 00    	mov    0x200008,%edx
f0104ad6:	89 55 d0             	mov    %edx,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f0104ad9:	a1 0c 00 20 00       	mov    0x20000c,%eax
f0104ade:	89 45 cc             	mov    %eax,-0x34(%ebp)

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
f0104ae1:	e8 8d 11 00 00       	call   f0105c73 <cpunum>
f0104ae6:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104aed:	00 
f0104aee:	89 da                	mov    %ebx,%edx
f0104af0:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0104af3:	29 ca                	sub    %ecx,%edx
f0104af5:	c1 fa 02             	sar    $0x2,%edx
f0104af8:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f0104afe:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104b02:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0104b06:	6b c0 74             	imul   $0x74,%eax,%eax
f0104b09:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f0104b0f:	89 04 24             	mov    %eax,(%esp)
f0104b12:	e8 e1 e8 ff ff       	call   f01033f8 <user_mem_check>
f0104b17:	85 c0                	test   %eax,%eax
f0104b19:	0f 85 bc 01 00 00    	jne    f0104cdb <debuginfo_eip+0x28f>
f0104b1f:	e8 4f 11 00 00       	call   f0105c73 <cpunum>
f0104b24:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104b2b:	00 
f0104b2c:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0104b2f:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0104b32:	29 ca                	sub    %ecx,%edx
f0104b34:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104b38:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0104b3c:	6b c0 74             	imul   $0x74,%eax,%eax
f0104b3f:	8b 80 28 30 22 f0    	mov    -0xfddcfd8(%eax),%eax
f0104b45:	89 04 24             	mov    %eax,(%esp)
f0104b48:	e8 ab e8 ff ff       	call   f01033f8 <user_mem_check>
f0104b4d:	85 c0                	test   %eax,%eax
f0104b4f:	74 1f                	je     f0104b70 <debuginfo_eip+0x124>
f0104b51:	e9 8c 01 00 00       	jmp    f0104ce2 <debuginfo_eip+0x296>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f0104b56:	c7 45 cc ee 4f 11 f0 	movl   $0xf0114fee,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f0104b5d:	c7 45 d0 45 1c 11 f0 	movl   $0xf0111c45,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f0104b64:	bb 44 1c 11 f0       	mov    $0xf0111c44,%ebx
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f0104b69:	c7 45 d4 34 7e 10 f0 	movl   $0xf0107e34,-0x2c(%ebp)
		    return -1;
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0104b70:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0104b73:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0104b76:	0f 83 6d 01 00 00    	jae    f0104ce9 <debuginfo_eip+0x29d>
f0104b7c:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f0104b80:	0f 85 6a 01 00 00    	jne    f0104cf0 <debuginfo_eip+0x2a4>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0104b86:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0104b8d:	2b 5d d4             	sub    -0x2c(%ebp),%ebx
f0104b90:	c1 fb 02             	sar    $0x2,%ebx
f0104b93:	69 c3 ab aa aa aa    	imul   $0xaaaaaaab,%ebx,%eax
f0104b99:	83 e8 01             	sub    $0x1,%eax
f0104b9c:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0104b9f:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104ba3:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0104baa:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0104bad:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0104bb0:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0104bb3:	89 d8                	mov    %ebx,%eax
f0104bb5:	e8 66 fd ff ff       	call   f0104920 <stab_binsearch>
	if (lfile == 0)
f0104bba:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104bbd:	85 c0                	test   %eax,%eax
f0104bbf:	0f 84 32 01 00 00    	je     f0104cf7 <debuginfo_eip+0x2ab>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0104bc5:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0104bc8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104bcb:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0104bce:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104bd2:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0104bd9:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0104bdc:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0104bdf:	89 d8                	mov    %ebx,%eax
f0104be1:	e8 3a fd ff ff       	call   f0104920 <stab_binsearch>

	if (lfun <= rfun) {
f0104be6:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f0104be9:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f0104bec:	7f 23                	jg     f0104c11 <debuginfo_eip+0x1c5>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0104bee:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104bf1:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104bf4:	8d 04 87             	lea    (%edi,%eax,4),%eax
f0104bf7:	8b 10                	mov    (%eax),%edx
f0104bf9:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0104bfc:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f0104bff:	39 ca                	cmp    %ecx,%edx
f0104c01:	73 06                	jae    f0104c09 <debuginfo_eip+0x1bd>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0104c03:	03 55 d0             	add    -0x30(%ebp),%edx
f0104c06:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f0104c09:	8b 40 08             	mov    0x8(%eax),%eax
f0104c0c:	89 46 10             	mov    %eax,0x10(%esi)
f0104c0f:	eb 06                	jmp    f0104c17 <debuginfo_eip+0x1cb>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0104c11:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f0104c14:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0104c17:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0104c1e:	00 
f0104c1f:	8b 46 08             	mov    0x8(%esi),%eax
f0104c22:	89 04 24             	mov    %eax,(%esp)
f0104c25:	e8 85 09 00 00       	call   f01055af <strfind>
f0104c2a:	2b 46 08             	sub    0x8(%esi),%eax
f0104c2d:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0104c30:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104c33:	39 fb                	cmp    %edi,%ebx
f0104c35:	7c 5d                	jl     f0104c94 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0104c37:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104c3a:	c1 e0 02             	shl    $0x2,%eax
f0104c3d:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0104c40:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f0104c43:	89 55 c8             	mov    %edx,-0x38(%ebp)
f0104c46:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f0104c4a:	80 fa 84             	cmp    $0x84,%dl
f0104c4d:	74 2d                	je     f0104c7c <debuginfo_eip+0x230>
f0104c4f:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f0104c53:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0104c56:	eb 15                	jmp    f0104c6d <debuginfo_eip+0x221>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0104c58:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0104c5b:	39 fb                	cmp    %edi,%ebx
f0104c5d:	7c 35                	jl     f0104c94 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0104c5f:	89 c1                	mov    %eax,%ecx
f0104c61:	83 e8 0c             	sub    $0xc,%eax
f0104c64:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0104c68:	80 fa 84             	cmp    $0x84,%dl
f0104c6b:	74 0f                	je     f0104c7c <debuginfo_eip+0x230>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0104c6d:	80 fa 64             	cmp    $0x64,%dl
f0104c70:	75 e6                	jne    f0104c58 <debuginfo_eip+0x20c>
f0104c72:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f0104c76:	74 e0                	je     f0104c58 <debuginfo_eip+0x20c>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0104c78:	39 df                	cmp    %ebx,%edi
f0104c7a:	7f 18                	jg     f0104c94 <debuginfo_eip+0x248>
f0104c7c:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104c7f:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104c82:	8b 04 87             	mov    (%edi,%eax,4),%eax
f0104c85:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0104c88:	2b 55 d0             	sub    -0x30(%ebp),%edx
f0104c8b:	39 d0                	cmp    %edx,%eax
f0104c8d:	73 05                	jae    f0104c94 <debuginfo_eip+0x248>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0104c8f:	03 45 d0             	add    -0x30(%ebp),%eax
f0104c92:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0104c94:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0104c97:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0104c9a:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0104c9f:	39 ca                	cmp    %ecx,%edx
f0104ca1:	7d 75                	jge    f0104d18 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
f0104ca3:	8d 42 01             	lea    0x1(%edx),%eax
f0104ca6:	39 c1                	cmp    %eax,%ecx
f0104ca8:	7e 54                	jle    f0104cfe <debuginfo_eip+0x2b2>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0104caa:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104cad:	c1 e2 02             	shl    $0x2,%edx
f0104cb0:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104cb3:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f0104cb8:	75 4b                	jne    f0104d05 <debuginfo_eip+0x2b9>
f0104cba:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f0104cbe:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0104cc2:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0104cc5:	39 c1                	cmp    %eax,%ecx
f0104cc7:	7e 43                	jle    f0104d0c <debuginfo_eip+0x2c0>
f0104cc9:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0104ccc:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0104cd0:	74 ec                	je     f0104cbe <debuginfo_eip+0x272>
f0104cd2:	eb 3f                	jmp    f0104d13 <debuginfo_eip+0x2c7>

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
			return -1;
f0104cd4:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104cd9:	eb 3d                	jmp    f0104d18 <debuginfo_eip+0x2cc>

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
		 {
		    return -1;
f0104cdb:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104ce0:	eb 36                	jmp    f0104d18 <debuginfo_eip+0x2cc>
f0104ce2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104ce7:	eb 2f                	jmp    f0104d18 <debuginfo_eip+0x2cc>
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0104ce9:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104cee:	eb 28                	jmp    f0104d18 <debuginfo_eip+0x2cc>
f0104cf0:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104cf5:	eb 21                	jmp    f0104d18 <debuginfo_eip+0x2cc>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0104cf7:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104cfc:	eb 1a                	jmp    f0104d18 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0104cfe:	b8 00 00 00 00       	mov    $0x0,%eax
f0104d03:	eb 13                	jmp    f0104d18 <debuginfo_eip+0x2cc>
f0104d05:	b8 00 00 00 00       	mov    $0x0,%eax
f0104d0a:	eb 0c                	jmp    f0104d18 <debuginfo_eip+0x2cc>
f0104d0c:	b8 00 00 00 00       	mov    $0x0,%eax
f0104d11:	eb 05                	jmp    f0104d18 <debuginfo_eip+0x2cc>
f0104d13:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0104d18:	83 c4 3c             	add    $0x3c,%esp
f0104d1b:	5b                   	pop    %ebx
f0104d1c:	5e                   	pop    %esi
f0104d1d:	5f                   	pop    %edi
f0104d1e:	5d                   	pop    %ebp
f0104d1f:	c3                   	ret    

f0104d20 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0104d20:	55                   	push   %ebp
f0104d21:	89 e5                	mov    %esp,%ebp
f0104d23:	57                   	push   %edi
f0104d24:	56                   	push   %esi
f0104d25:	53                   	push   %ebx
f0104d26:	83 ec 3c             	sub    $0x3c,%esp
f0104d29:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0104d2c:	89 d7                	mov    %edx,%edi
f0104d2e:	8b 45 08             	mov    0x8(%ebp),%eax
f0104d31:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0104d34:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104d37:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f0104d3a:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0104d3d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0104d42:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0104d45:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0104d48:	39 f1                	cmp    %esi,%ecx
f0104d4a:	72 14                	jb     f0104d60 <printnum+0x40>
f0104d4c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f0104d4f:	76 0f                	jbe    f0104d60 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0104d51:	8b 45 14             	mov    0x14(%ebp),%eax
f0104d54:	8d 70 ff             	lea    -0x1(%eax),%esi
f0104d57:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0104d5a:	85 f6                	test   %esi,%esi
f0104d5c:	7f 60                	jg     f0104dbe <printnum+0x9e>
f0104d5e:	eb 72                	jmp    f0104dd2 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0104d60:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0104d63:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0104d67:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0104d6a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0104d6d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0104d71:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104d75:	8b 44 24 08          	mov    0x8(%esp),%eax
f0104d79:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0104d7d:	89 c3                	mov    %eax,%ebx
f0104d7f:	89 d6                	mov    %edx,%esi
f0104d81:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0104d84:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0104d87:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104d8b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0104d8f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104d92:	89 04 24             	mov    %eax,(%esp)
f0104d95:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0104d98:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104d9c:	e8 3f 13 00 00       	call   f01060e0 <__udivdi3>
f0104da1:	89 d9                	mov    %ebx,%ecx
f0104da3:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104da7:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0104dab:	89 04 24             	mov    %eax,(%esp)
f0104dae:	89 54 24 04          	mov    %edx,0x4(%esp)
f0104db2:	89 fa                	mov    %edi,%edx
f0104db4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104db7:	e8 64 ff ff ff       	call   f0104d20 <printnum>
f0104dbc:	eb 14                	jmp    f0104dd2 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f0104dbe:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104dc2:	8b 45 18             	mov    0x18(%ebp),%eax
f0104dc5:	89 04 24             	mov    %eax,(%esp)
f0104dc8:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0104dca:	83 ee 01             	sub    $0x1,%esi
f0104dcd:	75 ef                	jne    f0104dbe <printnum+0x9e>
f0104dcf:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0104dd2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104dd6:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0104dda:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0104ddd:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0104de0:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104de4:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0104de8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104deb:	89 04 24             	mov    %eax,(%esp)
f0104dee:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0104df1:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104df5:	e8 16 14 00 00       	call   f0106210 <__umoddi3>
f0104dfa:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104dfe:	0f be 80 5c 79 10 f0 	movsbl -0xfef86a4(%eax),%eax
f0104e05:	89 04 24             	mov    %eax,(%esp)
f0104e08:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104e0b:	ff d0                	call   *%eax
}
f0104e0d:	83 c4 3c             	add    $0x3c,%esp
f0104e10:	5b                   	pop    %ebx
f0104e11:	5e                   	pop    %esi
f0104e12:	5f                   	pop    %edi
f0104e13:	5d                   	pop    %ebp
f0104e14:	c3                   	ret    

f0104e15 <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0104e15:	55                   	push   %ebp
f0104e16:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0104e18:	83 fa 01             	cmp    $0x1,%edx
f0104e1b:	7e 0e                	jle    f0104e2b <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f0104e1d:	8b 10                	mov    (%eax),%edx
f0104e1f:	8d 4a 08             	lea    0x8(%edx),%ecx
f0104e22:	89 08                	mov    %ecx,(%eax)
f0104e24:	8b 02                	mov    (%edx),%eax
f0104e26:	8b 52 04             	mov    0x4(%edx),%edx
f0104e29:	eb 22                	jmp    f0104e4d <getuint+0x38>
	else if (lflag)
f0104e2b:	85 d2                	test   %edx,%edx
f0104e2d:	74 10                	je     f0104e3f <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f0104e2f:	8b 10                	mov    (%eax),%edx
f0104e31:	8d 4a 04             	lea    0x4(%edx),%ecx
f0104e34:	89 08                	mov    %ecx,(%eax)
f0104e36:	8b 02                	mov    (%edx),%eax
f0104e38:	ba 00 00 00 00       	mov    $0x0,%edx
f0104e3d:	eb 0e                	jmp    f0104e4d <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f0104e3f:	8b 10                	mov    (%eax),%edx
f0104e41:	8d 4a 04             	lea    0x4(%edx),%ecx
f0104e44:	89 08                	mov    %ecx,(%eax)
f0104e46:	8b 02                	mov    (%edx),%eax
f0104e48:	ba 00 00 00 00       	mov    $0x0,%edx
}
f0104e4d:	5d                   	pop    %ebp
f0104e4e:	c3                   	ret    

f0104e4f <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0104e4f:	55                   	push   %ebp
f0104e50:	89 e5                	mov    %esp,%ebp
f0104e52:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0104e55:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0104e59:	8b 10                	mov    (%eax),%edx
f0104e5b:	3b 50 04             	cmp    0x4(%eax),%edx
f0104e5e:	73 0a                	jae    f0104e6a <sprintputch+0x1b>
		*b->buf++ = ch;
f0104e60:	8d 4a 01             	lea    0x1(%edx),%ecx
f0104e63:	89 08                	mov    %ecx,(%eax)
f0104e65:	8b 45 08             	mov    0x8(%ebp),%eax
f0104e68:	88 02                	mov    %al,(%edx)
}
f0104e6a:	5d                   	pop    %ebp
f0104e6b:	c3                   	ret    

f0104e6c <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0104e6c:	55                   	push   %ebp
f0104e6d:	89 e5                	mov    %esp,%ebp
f0104e6f:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0104e72:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0104e75:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104e79:	8b 45 10             	mov    0x10(%ebp),%eax
f0104e7c:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104e80:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104e83:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104e87:	8b 45 08             	mov    0x8(%ebp),%eax
f0104e8a:	89 04 24             	mov    %eax,(%esp)
f0104e8d:	e8 02 00 00 00       	call   f0104e94 <vprintfmt>
	va_end(ap);
}
f0104e92:	c9                   	leave  
f0104e93:	c3                   	ret    

f0104e94 <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f0104e94:	55                   	push   %ebp
f0104e95:	89 e5                	mov    %esp,%ebp
f0104e97:	57                   	push   %edi
f0104e98:	56                   	push   %esi
f0104e99:	53                   	push   %ebx
f0104e9a:	83 ec 3c             	sub    $0x3c,%esp
f0104e9d:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0104ea0:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0104ea3:	eb 18                	jmp    f0104ebd <vprintfmt+0x29>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f0104ea5:	85 c0                	test   %eax,%eax
f0104ea7:	0f 84 c3 03 00 00    	je     f0105270 <vprintfmt+0x3dc>
				return;
			putch(ch, putdat);
f0104ead:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104eb1:	89 04 24             	mov    %eax,(%esp)
f0104eb4:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0104eb7:	89 f3                	mov    %esi,%ebx
f0104eb9:	eb 02                	jmp    f0104ebd <vprintfmt+0x29>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f0104ebb:	89 f3                	mov    %esi,%ebx
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0104ebd:	8d 73 01             	lea    0x1(%ebx),%esi
f0104ec0:	0f b6 03             	movzbl (%ebx),%eax
f0104ec3:	83 f8 25             	cmp    $0x25,%eax
f0104ec6:	75 dd                	jne    f0104ea5 <vprintfmt+0x11>
f0104ec8:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f0104ecc:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0104ed3:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f0104eda:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0104ee1:	ba 00 00 00 00       	mov    $0x0,%edx
f0104ee6:	eb 1d                	jmp    f0104f05 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104ee8:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f0104eea:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f0104eee:	eb 15                	jmp    f0104f05 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104ef0:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0104ef2:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f0104ef6:	eb 0d                	jmp    f0104f05 <vprintfmt+0x71>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0104ef8:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0104efb:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0104efe:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104f05:	8d 5e 01             	lea    0x1(%esi),%ebx
f0104f08:	0f b6 06             	movzbl (%esi),%eax
f0104f0b:	0f b6 c8             	movzbl %al,%ecx
f0104f0e:	83 e8 23             	sub    $0x23,%eax
f0104f11:	3c 55                	cmp    $0x55,%al
f0104f13:	0f 87 2f 03 00 00    	ja     f0105248 <vprintfmt+0x3b4>
f0104f19:	0f b6 c0             	movzbl %al,%eax
f0104f1c:	ff 24 85 20 7a 10 f0 	jmp    *-0xfef85e0(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0104f23:	8d 41 d0             	lea    -0x30(%ecx),%eax
f0104f26:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0104f29:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f0104f2d:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0104f30:	83 f9 09             	cmp    $0x9,%ecx
f0104f33:	77 50                	ja     f0104f85 <vprintfmt+0xf1>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104f35:	89 de                	mov    %ebx,%esi
f0104f37:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f0104f3a:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f0104f3d:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0104f40:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0104f44:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0104f47:	8d 58 d0             	lea    -0x30(%eax),%ebx
f0104f4a:	83 fb 09             	cmp    $0x9,%ebx
f0104f4d:	76 eb                	jbe    f0104f3a <vprintfmt+0xa6>
f0104f4f:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0104f52:	eb 33                	jmp    f0104f87 <vprintfmt+0xf3>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0104f54:	8b 45 14             	mov    0x14(%ebp),%eax
f0104f57:	8d 48 04             	lea    0x4(%eax),%ecx
f0104f5a:	89 4d 14             	mov    %ecx,0x14(%ebp)
f0104f5d:	8b 00                	mov    (%eax),%eax
f0104f5f:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104f62:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0104f64:	eb 21                	jmp    f0104f87 <vprintfmt+0xf3>
f0104f66:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0104f69:	85 c9                	test   %ecx,%ecx
f0104f6b:	b8 00 00 00 00       	mov    $0x0,%eax
f0104f70:	0f 49 c1             	cmovns %ecx,%eax
f0104f73:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104f76:	89 de                	mov    %ebx,%esi
f0104f78:	eb 8b                	jmp    f0104f05 <vprintfmt+0x71>
f0104f7a:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0104f7c:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f0104f83:	eb 80                	jmp    f0104f05 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104f85:	89 de                	mov    %ebx,%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0104f87:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0104f8b:	0f 89 74 ff ff ff    	jns    f0104f05 <vprintfmt+0x71>
f0104f91:	e9 62 ff ff ff       	jmp    f0104ef8 <vprintfmt+0x64>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0104f96:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104f99:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f0104f9b:	e9 65 ff ff ff       	jmp    f0104f05 <vprintfmt+0x71>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f0104fa0:	8b 45 14             	mov    0x14(%ebp),%eax
f0104fa3:	8d 50 04             	lea    0x4(%eax),%edx
f0104fa6:	89 55 14             	mov    %edx,0x14(%ebp)
f0104fa9:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104fad:	8b 00                	mov    (%eax),%eax
f0104faf:	89 04 24             	mov    %eax,(%esp)
f0104fb2:	ff 55 08             	call   *0x8(%ebp)
			break;
f0104fb5:	e9 03 ff ff ff       	jmp    f0104ebd <vprintfmt+0x29>

		// error message
		case 'e':
			err = va_arg(ap, int);
f0104fba:	8b 45 14             	mov    0x14(%ebp),%eax
f0104fbd:	8d 50 04             	lea    0x4(%eax),%edx
f0104fc0:	89 55 14             	mov    %edx,0x14(%ebp)
f0104fc3:	8b 00                	mov    (%eax),%eax
f0104fc5:	99                   	cltd   
f0104fc6:	31 d0                	xor    %edx,%eax
f0104fc8:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0104fca:	83 f8 08             	cmp    $0x8,%eax
f0104fcd:	7f 0b                	jg     f0104fda <vprintfmt+0x146>
f0104fcf:	8b 14 85 80 7b 10 f0 	mov    -0xfef8480(,%eax,4),%edx
f0104fd6:	85 d2                	test   %edx,%edx
f0104fd8:	75 20                	jne    f0104ffa <vprintfmt+0x166>
				printfmt(putch, putdat, "error %d", err);
f0104fda:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104fde:	c7 44 24 08 74 79 10 	movl   $0xf0107974,0x8(%esp)
f0104fe5:	f0 
f0104fe6:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104fea:	8b 45 08             	mov    0x8(%ebp),%eax
f0104fed:	89 04 24             	mov    %eax,(%esp)
f0104ff0:	e8 77 fe ff ff       	call   f0104e6c <printfmt>
f0104ff5:	e9 c3 fe ff ff       	jmp    f0104ebd <vprintfmt+0x29>
			else
				printfmt(putch, putdat, "%s", p);
f0104ffa:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0104ffe:	c7 44 24 08 29 71 10 	movl   $0xf0107129,0x8(%esp)
f0105005:	f0 
f0105006:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010500a:	8b 45 08             	mov    0x8(%ebp),%eax
f010500d:	89 04 24             	mov    %eax,(%esp)
f0105010:	e8 57 fe ff ff       	call   f0104e6c <printfmt>
f0105015:	e9 a3 fe ff ff       	jmp    f0104ebd <vprintfmt+0x29>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010501a:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f010501d:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0105020:	8b 45 14             	mov    0x14(%ebp),%eax
f0105023:	8d 50 04             	lea    0x4(%eax),%edx
f0105026:	89 55 14             	mov    %edx,0x14(%ebp)
f0105029:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f010502b:	85 c0                	test   %eax,%eax
f010502d:	ba 6d 79 10 f0       	mov    $0xf010796d,%edx
f0105032:	0f 45 d0             	cmovne %eax,%edx
f0105035:	89 55 d0             	mov    %edx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f0105038:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f010503c:	74 04                	je     f0105042 <vprintfmt+0x1ae>
f010503e:	85 f6                	test   %esi,%esi
f0105040:	7f 19                	jg     f010505b <vprintfmt+0x1c7>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0105042:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0105045:	8d 70 01             	lea    0x1(%eax),%esi
f0105048:	0f b6 10             	movzbl (%eax),%edx
f010504b:	0f be c2             	movsbl %dl,%eax
f010504e:	85 c0                	test   %eax,%eax
f0105050:	0f 85 95 00 00 00    	jne    f01050eb <vprintfmt+0x257>
f0105056:	e9 85 00 00 00       	jmp    f01050e0 <vprintfmt+0x24c>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f010505b:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f010505f:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0105062:	89 04 24             	mov    %eax,(%esp)
f0105065:	e8 88 03 00 00       	call   f01053f2 <strnlen>
f010506a:	29 c6                	sub    %eax,%esi
f010506c:	89 f0                	mov    %esi,%eax
f010506e:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0105071:	85 f6                	test   %esi,%esi
f0105073:	7e cd                	jle    f0105042 <vprintfmt+0x1ae>
					putch(padc, putdat);
f0105075:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105079:	89 5d 10             	mov    %ebx,0x10(%ebp)
f010507c:	89 c3                	mov    %eax,%ebx
f010507e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105082:	89 34 24             	mov    %esi,(%esp)
f0105085:	ff 55 08             	call   *0x8(%ebp)
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0105088:	83 eb 01             	sub    $0x1,%ebx
f010508b:	75 f1                	jne    f010507e <vprintfmt+0x1ea>
f010508d:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0105090:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0105093:	eb ad                	jmp    f0105042 <vprintfmt+0x1ae>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f0105095:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0105099:	74 1e                	je     f01050b9 <vprintfmt+0x225>
f010509b:	0f be d2             	movsbl %dl,%edx
f010509e:	83 ea 20             	sub    $0x20,%edx
f01050a1:	83 fa 5e             	cmp    $0x5e,%edx
f01050a4:	76 13                	jbe    f01050b9 <vprintfmt+0x225>
					putch('?', putdat);
f01050a6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01050a9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01050ad:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f01050b4:	ff 55 08             	call   *0x8(%ebp)
f01050b7:	eb 0d                	jmp    f01050c6 <vprintfmt+0x232>
				else
					putch(ch, putdat);
f01050b9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01050bc:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01050c0:	89 04 24             	mov    %eax,(%esp)
f01050c3:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01050c6:	83 ef 01             	sub    $0x1,%edi
f01050c9:	83 c6 01             	add    $0x1,%esi
f01050cc:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f01050d0:	0f be c2             	movsbl %dl,%eax
f01050d3:	85 c0                	test   %eax,%eax
f01050d5:	75 20                	jne    f01050f7 <vprintfmt+0x263>
f01050d7:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f01050da:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01050dd:	8b 5d 10             	mov    0x10(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01050e0:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01050e4:	7f 25                	jg     f010510b <vprintfmt+0x277>
f01050e6:	e9 d2 fd ff ff       	jmp    f0104ebd <vprintfmt+0x29>
f01050eb:	89 7d 0c             	mov    %edi,0xc(%ebp)
f01050ee:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01050f1:	89 5d 10             	mov    %ebx,0x10(%ebp)
f01050f4:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01050f7:	85 db                	test   %ebx,%ebx
f01050f9:	78 9a                	js     f0105095 <vprintfmt+0x201>
f01050fb:	83 eb 01             	sub    $0x1,%ebx
f01050fe:	79 95                	jns    f0105095 <vprintfmt+0x201>
f0105100:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f0105103:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0105106:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0105109:	eb d5                	jmp    f01050e0 <vprintfmt+0x24c>
f010510b:	8b 75 08             	mov    0x8(%ebp),%esi
f010510e:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0105111:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0105114:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105118:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f010511f:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0105121:	83 eb 01             	sub    $0x1,%ebx
f0105124:	75 ee                	jne    f0105114 <vprintfmt+0x280>
f0105126:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0105129:	e9 8f fd ff ff       	jmp    f0104ebd <vprintfmt+0x29>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010512e:	83 fa 01             	cmp    $0x1,%edx
f0105131:	7e 16                	jle    f0105149 <vprintfmt+0x2b5>
		return va_arg(*ap, long long);
f0105133:	8b 45 14             	mov    0x14(%ebp),%eax
f0105136:	8d 50 08             	lea    0x8(%eax),%edx
f0105139:	89 55 14             	mov    %edx,0x14(%ebp)
f010513c:	8b 50 04             	mov    0x4(%eax),%edx
f010513f:	8b 00                	mov    (%eax),%eax
f0105141:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0105144:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0105147:	eb 32                	jmp    f010517b <vprintfmt+0x2e7>
	else if (lflag)
f0105149:	85 d2                	test   %edx,%edx
f010514b:	74 18                	je     f0105165 <vprintfmt+0x2d1>
		return va_arg(*ap, long);
f010514d:	8b 45 14             	mov    0x14(%ebp),%eax
f0105150:	8d 50 04             	lea    0x4(%eax),%edx
f0105153:	89 55 14             	mov    %edx,0x14(%ebp)
f0105156:	8b 30                	mov    (%eax),%esi
f0105158:	89 75 d8             	mov    %esi,-0x28(%ebp)
f010515b:	89 f0                	mov    %esi,%eax
f010515d:	c1 f8 1f             	sar    $0x1f,%eax
f0105160:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0105163:	eb 16                	jmp    f010517b <vprintfmt+0x2e7>
	else
		return va_arg(*ap, int);
f0105165:	8b 45 14             	mov    0x14(%ebp),%eax
f0105168:	8d 50 04             	lea    0x4(%eax),%edx
f010516b:	89 55 14             	mov    %edx,0x14(%ebp)
f010516e:	8b 30                	mov    (%eax),%esi
f0105170:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105173:	89 f0                	mov    %esi,%eax
f0105175:	c1 f8 1f             	sar    $0x1f,%eax
f0105178:	89 45 dc             	mov    %eax,-0x24(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f010517b:	8b 45 d8             	mov    -0x28(%ebp),%eax
f010517e:	8b 55 dc             	mov    -0x24(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f0105181:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0105186:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f010518a:	0f 89 80 00 00 00    	jns    f0105210 <vprintfmt+0x37c>
				putch('-', putdat);
f0105190:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105194:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f010519b:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f010519e:	8b 45 d8             	mov    -0x28(%ebp),%eax
f01051a1:	8b 55 dc             	mov    -0x24(%ebp),%edx
f01051a4:	f7 d8                	neg    %eax
f01051a6:	83 d2 00             	adc    $0x0,%edx
f01051a9:	f7 da                	neg    %edx
			}
			base = 10;
f01051ab:	b9 0a 00 00 00       	mov    $0xa,%ecx
f01051b0:	eb 5e                	jmp    f0105210 <vprintfmt+0x37c>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f01051b2:	8d 45 14             	lea    0x14(%ebp),%eax
f01051b5:	e8 5b fc ff ff       	call   f0104e15 <getuint>
			base = 10;
f01051ba:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f01051bf:	eb 4f                	jmp    f0105210 <vprintfmt+0x37c>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			//putch('X', putdat);
			num = getuint(&ap, lflag);
f01051c1:	8d 45 14             	lea    0x14(%ebp),%eax
f01051c4:	e8 4c fc ff ff       	call   f0104e15 <getuint>
			base = 8;
f01051c9:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f01051ce:	eb 40                	jmp    f0105210 <vprintfmt+0x37c>
			//putch('X', putdat);
			//break;

		// pointer
		case 'p':
			putch('0', putdat);
f01051d0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01051d4:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f01051db:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f01051de:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01051e2:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f01051e9:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f01051ec:	8b 45 14             	mov    0x14(%ebp),%eax
f01051ef:	8d 50 04             	lea    0x4(%eax),%edx
f01051f2:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f01051f5:	8b 00                	mov    (%eax),%eax
f01051f7:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f01051fc:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f0105201:	eb 0d                	jmp    f0105210 <vprintfmt+0x37c>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f0105203:	8d 45 14             	lea    0x14(%ebp),%eax
f0105206:	e8 0a fc ff ff       	call   f0104e15 <getuint>
			base = 16;
f010520b:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f0105210:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105214:	89 74 24 10          	mov    %esi,0x10(%esp)
f0105218:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f010521b:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010521f:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0105223:	89 04 24             	mov    %eax,(%esp)
f0105226:	89 54 24 04          	mov    %edx,0x4(%esp)
f010522a:	89 fa                	mov    %edi,%edx
f010522c:	8b 45 08             	mov    0x8(%ebp),%eax
f010522f:	e8 ec fa ff ff       	call   f0104d20 <printnum>
			break;
f0105234:	e9 84 fc ff ff       	jmp    f0104ebd <vprintfmt+0x29>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0105239:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010523d:	89 0c 24             	mov    %ecx,(%esp)
f0105240:	ff 55 08             	call   *0x8(%ebp)
			break;
f0105243:	e9 75 fc ff ff       	jmp    f0104ebd <vprintfmt+0x29>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0105248:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010524c:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0105253:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f0105256:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f010525a:	0f 84 5b fc ff ff    	je     f0104ebb <vprintfmt+0x27>
f0105260:	89 f3                	mov    %esi,%ebx
f0105262:	83 eb 01             	sub    $0x1,%ebx
f0105265:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f0105269:	75 f7                	jne    f0105262 <vprintfmt+0x3ce>
f010526b:	e9 4d fc ff ff       	jmp    f0104ebd <vprintfmt+0x29>
				/* do nothing */;
			break;
		}
	}
}
f0105270:	83 c4 3c             	add    $0x3c,%esp
f0105273:	5b                   	pop    %ebx
f0105274:	5e                   	pop    %esi
f0105275:	5f                   	pop    %edi
f0105276:	5d                   	pop    %ebp
f0105277:	c3                   	ret    

f0105278 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0105278:	55                   	push   %ebp
f0105279:	89 e5                	mov    %esp,%ebp
f010527b:	83 ec 28             	sub    $0x28,%esp
f010527e:	8b 45 08             	mov    0x8(%ebp),%eax
f0105281:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0105284:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0105287:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f010528b:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f010528e:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0105295:	85 c0                	test   %eax,%eax
f0105297:	74 30                	je     f01052c9 <vsnprintf+0x51>
f0105299:	85 d2                	test   %edx,%edx
f010529b:	7e 2c                	jle    f01052c9 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f010529d:	8b 45 14             	mov    0x14(%ebp),%eax
f01052a0:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01052a4:	8b 45 10             	mov    0x10(%ebp),%eax
f01052a7:	89 44 24 08          	mov    %eax,0x8(%esp)
f01052ab:	8d 45 ec             	lea    -0x14(%ebp),%eax
f01052ae:	89 44 24 04          	mov    %eax,0x4(%esp)
f01052b2:	c7 04 24 4f 4e 10 f0 	movl   $0xf0104e4f,(%esp)
f01052b9:	e8 d6 fb ff ff       	call   f0104e94 <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f01052be:	8b 45 ec             	mov    -0x14(%ebp),%eax
f01052c1:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f01052c4:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01052c7:	eb 05                	jmp    f01052ce <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f01052c9:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f01052ce:	c9                   	leave  
f01052cf:	c3                   	ret    

f01052d0 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f01052d0:	55                   	push   %ebp
f01052d1:	89 e5                	mov    %esp,%ebp
f01052d3:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f01052d6:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f01052d9:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01052dd:	8b 45 10             	mov    0x10(%ebp),%eax
f01052e0:	89 44 24 08          	mov    %eax,0x8(%esp)
f01052e4:	8b 45 0c             	mov    0xc(%ebp),%eax
f01052e7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01052eb:	8b 45 08             	mov    0x8(%ebp),%eax
f01052ee:	89 04 24             	mov    %eax,(%esp)
f01052f1:	e8 82 ff ff ff       	call   f0105278 <vsnprintf>
	va_end(ap);

	return rc;
}
f01052f6:	c9                   	leave  
f01052f7:	c3                   	ret    
f01052f8:	66 90                	xchg   %ax,%ax
f01052fa:	66 90                	xchg   %ax,%ax
f01052fc:	66 90                	xchg   %ax,%ax
f01052fe:	66 90                	xchg   %ax,%ax

f0105300 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0105300:	55                   	push   %ebp
f0105301:	89 e5                	mov    %esp,%ebp
f0105303:	57                   	push   %edi
f0105304:	56                   	push   %esi
f0105305:	53                   	push   %ebx
f0105306:	83 ec 1c             	sub    $0x1c,%esp
f0105309:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f010530c:	85 c0                	test   %eax,%eax
f010530e:	74 10                	je     f0105320 <readline+0x20>
		cprintf("%s", prompt);
f0105310:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105314:	c7 04 24 29 71 10 f0 	movl   $0xf0107129,(%esp)
f010531b:	e8 5c eb ff ff       	call   f0103e7c <cprintf>

	i = 0;
	echoing = iscons(0);
f0105320:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0105327:	e8 b2 b4 ff ff       	call   f01007de <iscons>
f010532c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f010532e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0105333:	e8 95 b4 ff ff       	call   f01007cd <getchar>
f0105338:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f010533a:	85 c0                	test   %eax,%eax
f010533c:	79 17                	jns    f0105355 <readline+0x55>
			cprintf("read error: %e\n", c);
f010533e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105342:	c7 04 24 a4 7b 10 f0 	movl   $0xf0107ba4,(%esp)
f0105349:	e8 2e eb ff ff       	call   f0103e7c <cprintf>
			return NULL;
f010534e:	b8 00 00 00 00       	mov    $0x0,%eax
f0105353:	eb 6d                	jmp    f01053c2 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0105355:	83 f8 7f             	cmp    $0x7f,%eax
f0105358:	74 05                	je     f010535f <readline+0x5f>
f010535a:	83 f8 08             	cmp    $0x8,%eax
f010535d:	75 19                	jne    f0105378 <readline+0x78>
f010535f:	85 f6                	test   %esi,%esi
f0105361:	7e 15                	jle    f0105378 <readline+0x78>
			if (echoing)
f0105363:	85 ff                	test   %edi,%edi
f0105365:	74 0c                	je     f0105373 <readline+0x73>
				cputchar('\b');
f0105367:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f010536e:	e8 4a b4 ff ff       	call   f01007bd <cputchar>
			i--;
f0105373:	83 ee 01             	sub    $0x1,%esi
f0105376:	eb bb                	jmp    f0105333 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0105378:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f010537e:	7f 1c                	jg     f010539c <readline+0x9c>
f0105380:	83 fb 1f             	cmp    $0x1f,%ebx
f0105383:	7e 17                	jle    f010539c <readline+0x9c>
			if (echoing)
f0105385:	85 ff                	test   %edi,%edi
f0105387:	74 08                	je     f0105391 <readline+0x91>
				cputchar(c);
f0105389:	89 1c 24             	mov    %ebx,(%esp)
f010538c:	e8 2c b4 ff ff       	call   f01007bd <cputchar>
			buf[i++] = c;
f0105391:	88 9e 00 2b 22 f0    	mov    %bl,-0xfddd500(%esi)
f0105397:	8d 76 01             	lea    0x1(%esi),%esi
f010539a:	eb 97                	jmp    f0105333 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f010539c:	83 fb 0d             	cmp    $0xd,%ebx
f010539f:	74 05                	je     f01053a6 <readline+0xa6>
f01053a1:	83 fb 0a             	cmp    $0xa,%ebx
f01053a4:	75 8d                	jne    f0105333 <readline+0x33>
			if (echoing)
f01053a6:	85 ff                	test   %edi,%edi
f01053a8:	74 0c                	je     f01053b6 <readline+0xb6>
				cputchar('\n');
f01053aa:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f01053b1:	e8 07 b4 ff ff       	call   f01007bd <cputchar>
			buf[i] = 0;
f01053b6:	c6 86 00 2b 22 f0 00 	movb   $0x0,-0xfddd500(%esi)
			return buf;
f01053bd:	b8 00 2b 22 f0       	mov    $0xf0222b00,%eax
		}
	}
}
f01053c2:	83 c4 1c             	add    $0x1c,%esp
f01053c5:	5b                   	pop    %ebx
f01053c6:	5e                   	pop    %esi
f01053c7:	5f                   	pop    %edi
f01053c8:	5d                   	pop    %ebp
f01053c9:	c3                   	ret    
f01053ca:	66 90                	xchg   %ax,%ax
f01053cc:	66 90                	xchg   %ax,%ax
f01053ce:	66 90                	xchg   %ax,%ax

f01053d0 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f01053d0:	55                   	push   %ebp
f01053d1:	89 e5                	mov    %esp,%ebp
f01053d3:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f01053d6:	80 3a 00             	cmpb   $0x0,(%edx)
f01053d9:	74 10                	je     f01053eb <strlen+0x1b>
f01053db:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f01053e0:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f01053e3:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f01053e7:	75 f7                	jne    f01053e0 <strlen+0x10>
f01053e9:	eb 05                	jmp    f01053f0 <strlen+0x20>
f01053eb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f01053f0:	5d                   	pop    %ebp
f01053f1:	c3                   	ret    

f01053f2 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f01053f2:	55                   	push   %ebp
f01053f3:	89 e5                	mov    %esp,%ebp
f01053f5:	53                   	push   %ebx
f01053f6:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01053f9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01053fc:	85 c9                	test   %ecx,%ecx
f01053fe:	74 1c                	je     f010541c <strnlen+0x2a>
f0105400:	80 3b 00             	cmpb   $0x0,(%ebx)
f0105403:	74 1e                	je     f0105423 <strnlen+0x31>
f0105405:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f010540a:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010540c:	39 ca                	cmp    %ecx,%edx
f010540e:	74 18                	je     f0105428 <strnlen+0x36>
f0105410:	83 c2 01             	add    $0x1,%edx
f0105413:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0105418:	75 f0                	jne    f010540a <strnlen+0x18>
f010541a:	eb 0c                	jmp    f0105428 <strnlen+0x36>
f010541c:	b8 00 00 00 00       	mov    $0x0,%eax
f0105421:	eb 05                	jmp    f0105428 <strnlen+0x36>
f0105423:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0105428:	5b                   	pop    %ebx
f0105429:	5d                   	pop    %ebp
f010542a:	c3                   	ret    

f010542b <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f010542b:	55                   	push   %ebp
f010542c:	89 e5                	mov    %esp,%ebp
f010542e:	53                   	push   %ebx
f010542f:	8b 45 08             	mov    0x8(%ebp),%eax
f0105432:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0105435:	89 c2                	mov    %eax,%edx
f0105437:	83 c2 01             	add    $0x1,%edx
f010543a:	83 c1 01             	add    $0x1,%ecx
f010543d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0105441:	88 5a ff             	mov    %bl,-0x1(%edx)
f0105444:	84 db                	test   %bl,%bl
f0105446:	75 ef                	jne    f0105437 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0105448:	5b                   	pop    %ebx
f0105449:	5d                   	pop    %ebp
f010544a:	c3                   	ret    

f010544b <strcat>:

char *
strcat(char *dst, const char *src)
{
f010544b:	55                   	push   %ebp
f010544c:	89 e5                	mov    %esp,%ebp
f010544e:	53                   	push   %ebx
f010544f:	83 ec 08             	sub    $0x8,%esp
f0105452:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f0105455:	89 1c 24             	mov    %ebx,(%esp)
f0105458:	e8 73 ff ff ff       	call   f01053d0 <strlen>
	strcpy(dst + len, src);
f010545d:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105460:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105464:	01 d8                	add    %ebx,%eax
f0105466:	89 04 24             	mov    %eax,(%esp)
f0105469:	e8 bd ff ff ff       	call   f010542b <strcpy>
	return dst;
}
f010546e:	89 d8                	mov    %ebx,%eax
f0105470:	83 c4 08             	add    $0x8,%esp
f0105473:	5b                   	pop    %ebx
f0105474:	5d                   	pop    %ebp
f0105475:	c3                   	ret    

f0105476 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f0105476:	55                   	push   %ebp
f0105477:	89 e5                	mov    %esp,%ebp
f0105479:	56                   	push   %esi
f010547a:	53                   	push   %ebx
f010547b:	8b 75 08             	mov    0x8(%ebp),%esi
f010547e:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105481:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0105484:	85 db                	test   %ebx,%ebx
f0105486:	74 17                	je     f010549f <strncpy+0x29>
f0105488:	01 f3                	add    %esi,%ebx
f010548a:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f010548c:	83 c1 01             	add    $0x1,%ecx
f010548f:	0f b6 02             	movzbl (%edx),%eax
f0105492:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f0105495:	80 3a 01             	cmpb   $0x1,(%edx)
f0105498:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f010549b:	39 d9                	cmp    %ebx,%ecx
f010549d:	75 ed                	jne    f010548c <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f010549f:	89 f0                	mov    %esi,%eax
f01054a1:	5b                   	pop    %ebx
f01054a2:	5e                   	pop    %esi
f01054a3:	5d                   	pop    %ebp
f01054a4:	c3                   	ret    

f01054a5 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f01054a5:	55                   	push   %ebp
f01054a6:	89 e5                	mov    %esp,%ebp
f01054a8:	57                   	push   %edi
f01054a9:	56                   	push   %esi
f01054aa:	53                   	push   %ebx
f01054ab:	8b 7d 08             	mov    0x8(%ebp),%edi
f01054ae:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01054b1:	8b 75 10             	mov    0x10(%ebp),%esi
f01054b4:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f01054b6:	85 f6                	test   %esi,%esi
f01054b8:	74 34                	je     f01054ee <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f01054ba:	83 fe 01             	cmp    $0x1,%esi
f01054bd:	74 26                	je     f01054e5 <strlcpy+0x40>
f01054bf:	0f b6 0b             	movzbl (%ebx),%ecx
f01054c2:	84 c9                	test   %cl,%cl
f01054c4:	74 23                	je     f01054e9 <strlcpy+0x44>
f01054c6:	83 ee 02             	sub    $0x2,%esi
f01054c9:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f01054ce:	83 c0 01             	add    $0x1,%eax
f01054d1:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f01054d4:	39 f2                	cmp    %esi,%edx
f01054d6:	74 13                	je     f01054eb <strlcpy+0x46>
f01054d8:	83 c2 01             	add    $0x1,%edx
f01054db:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f01054df:	84 c9                	test   %cl,%cl
f01054e1:	75 eb                	jne    f01054ce <strlcpy+0x29>
f01054e3:	eb 06                	jmp    f01054eb <strlcpy+0x46>
f01054e5:	89 f8                	mov    %edi,%eax
f01054e7:	eb 02                	jmp    f01054eb <strlcpy+0x46>
f01054e9:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f01054eb:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f01054ee:	29 f8                	sub    %edi,%eax
}
f01054f0:	5b                   	pop    %ebx
f01054f1:	5e                   	pop    %esi
f01054f2:	5f                   	pop    %edi
f01054f3:	5d                   	pop    %ebp
f01054f4:	c3                   	ret    

f01054f5 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f01054f5:	55                   	push   %ebp
f01054f6:	89 e5                	mov    %esp,%ebp
f01054f8:	8b 4d 08             	mov    0x8(%ebp),%ecx
f01054fb:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f01054fe:	0f b6 01             	movzbl (%ecx),%eax
f0105501:	84 c0                	test   %al,%al
f0105503:	74 15                	je     f010551a <strcmp+0x25>
f0105505:	3a 02                	cmp    (%edx),%al
f0105507:	75 11                	jne    f010551a <strcmp+0x25>
		p++, q++;
f0105509:	83 c1 01             	add    $0x1,%ecx
f010550c:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f010550f:	0f b6 01             	movzbl (%ecx),%eax
f0105512:	84 c0                	test   %al,%al
f0105514:	74 04                	je     f010551a <strcmp+0x25>
f0105516:	3a 02                	cmp    (%edx),%al
f0105518:	74 ef                	je     f0105509 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f010551a:	0f b6 c0             	movzbl %al,%eax
f010551d:	0f b6 12             	movzbl (%edx),%edx
f0105520:	29 d0                	sub    %edx,%eax
}
f0105522:	5d                   	pop    %ebp
f0105523:	c3                   	ret    

f0105524 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0105524:	55                   	push   %ebp
f0105525:	89 e5                	mov    %esp,%ebp
f0105527:	56                   	push   %esi
f0105528:	53                   	push   %ebx
f0105529:	8b 5d 08             	mov    0x8(%ebp),%ebx
f010552c:	8b 55 0c             	mov    0xc(%ebp),%edx
f010552f:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f0105532:	85 f6                	test   %esi,%esi
f0105534:	74 29                	je     f010555f <strncmp+0x3b>
f0105536:	0f b6 03             	movzbl (%ebx),%eax
f0105539:	84 c0                	test   %al,%al
f010553b:	74 30                	je     f010556d <strncmp+0x49>
f010553d:	3a 02                	cmp    (%edx),%al
f010553f:	75 2c                	jne    f010556d <strncmp+0x49>
f0105541:	8d 43 01             	lea    0x1(%ebx),%eax
f0105544:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f0105546:	89 c3                	mov    %eax,%ebx
f0105548:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f010554b:	39 f0                	cmp    %esi,%eax
f010554d:	74 17                	je     f0105566 <strncmp+0x42>
f010554f:	0f b6 08             	movzbl (%eax),%ecx
f0105552:	84 c9                	test   %cl,%cl
f0105554:	74 17                	je     f010556d <strncmp+0x49>
f0105556:	83 c0 01             	add    $0x1,%eax
f0105559:	3a 0a                	cmp    (%edx),%cl
f010555b:	74 e9                	je     f0105546 <strncmp+0x22>
f010555d:	eb 0e                	jmp    f010556d <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f010555f:	b8 00 00 00 00       	mov    $0x0,%eax
f0105564:	eb 0f                	jmp    f0105575 <strncmp+0x51>
f0105566:	b8 00 00 00 00       	mov    $0x0,%eax
f010556b:	eb 08                	jmp    f0105575 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f010556d:	0f b6 03             	movzbl (%ebx),%eax
f0105570:	0f b6 12             	movzbl (%edx),%edx
f0105573:	29 d0                	sub    %edx,%eax
}
f0105575:	5b                   	pop    %ebx
f0105576:	5e                   	pop    %esi
f0105577:	5d                   	pop    %ebp
f0105578:	c3                   	ret    

f0105579 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f0105579:	55                   	push   %ebp
f010557a:	89 e5                	mov    %esp,%ebp
f010557c:	53                   	push   %ebx
f010557d:	8b 45 08             	mov    0x8(%ebp),%eax
f0105580:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105583:	0f b6 18             	movzbl (%eax),%ebx
f0105586:	84 db                	test   %bl,%bl
f0105588:	74 1d                	je     f01055a7 <strchr+0x2e>
f010558a:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f010558c:	38 d3                	cmp    %dl,%bl
f010558e:	75 06                	jne    f0105596 <strchr+0x1d>
f0105590:	eb 1a                	jmp    f01055ac <strchr+0x33>
f0105592:	38 ca                	cmp    %cl,%dl
f0105594:	74 16                	je     f01055ac <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0105596:	83 c0 01             	add    $0x1,%eax
f0105599:	0f b6 10             	movzbl (%eax),%edx
f010559c:	84 d2                	test   %dl,%dl
f010559e:	75 f2                	jne    f0105592 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f01055a0:	b8 00 00 00 00       	mov    $0x0,%eax
f01055a5:	eb 05                	jmp    f01055ac <strchr+0x33>
f01055a7:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01055ac:	5b                   	pop    %ebx
f01055ad:	5d                   	pop    %ebp
f01055ae:	c3                   	ret    

f01055af <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f01055af:	55                   	push   %ebp
f01055b0:	89 e5                	mov    %esp,%ebp
f01055b2:	53                   	push   %ebx
f01055b3:	8b 45 08             	mov    0x8(%ebp),%eax
f01055b6:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f01055b9:	0f b6 18             	movzbl (%eax),%ebx
f01055bc:	84 db                	test   %bl,%bl
f01055be:	74 16                	je     f01055d6 <strfind+0x27>
f01055c0:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f01055c2:	38 d3                	cmp    %dl,%bl
f01055c4:	75 06                	jne    f01055cc <strfind+0x1d>
f01055c6:	eb 0e                	jmp    f01055d6 <strfind+0x27>
f01055c8:	38 ca                	cmp    %cl,%dl
f01055ca:	74 0a                	je     f01055d6 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f01055cc:	83 c0 01             	add    $0x1,%eax
f01055cf:	0f b6 10             	movzbl (%eax),%edx
f01055d2:	84 d2                	test   %dl,%dl
f01055d4:	75 f2                	jne    f01055c8 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f01055d6:	5b                   	pop    %ebx
f01055d7:	5d                   	pop    %ebp
f01055d8:	c3                   	ret    

f01055d9 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f01055d9:	55                   	push   %ebp
f01055da:	89 e5                	mov    %esp,%ebp
f01055dc:	57                   	push   %edi
f01055dd:	56                   	push   %esi
f01055de:	53                   	push   %ebx
f01055df:	8b 7d 08             	mov    0x8(%ebp),%edi
f01055e2:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f01055e5:	85 c9                	test   %ecx,%ecx
f01055e7:	74 36                	je     f010561f <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f01055e9:	f7 c7 03 00 00 00    	test   $0x3,%edi
f01055ef:	75 28                	jne    f0105619 <memset+0x40>
f01055f1:	f6 c1 03             	test   $0x3,%cl
f01055f4:	75 23                	jne    f0105619 <memset+0x40>
		c &= 0xFF;
f01055f6:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f01055fa:	89 d3                	mov    %edx,%ebx
f01055fc:	c1 e3 08             	shl    $0x8,%ebx
f01055ff:	89 d6                	mov    %edx,%esi
f0105601:	c1 e6 18             	shl    $0x18,%esi
f0105604:	89 d0                	mov    %edx,%eax
f0105606:	c1 e0 10             	shl    $0x10,%eax
f0105609:	09 f0                	or     %esi,%eax
f010560b:	09 c2                	or     %eax,%edx
f010560d:	89 d0                	mov    %edx,%eax
f010560f:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f0105611:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0105614:	fc                   	cld    
f0105615:	f3 ab                	rep stos %eax,%es:(%edi)
f0105617:	eb 06                	jmp    f010561f <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0105619:	8b 45 0c             	mov    0xc(%ebp),%eax
f010561c:	fc                   	cld    
f010561d:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f010561f:	89 f8                	mov    %edi,%eax
f0105621:	5b                   	pop    %ebx
f0105622:	5e                   	pop    %esi
f0105623:	5f                   	pop    %edi
f0105624:	5d                   	pop    %ebp
f0105625:	c3                   	ret    

f0105626 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0105626:	55                   	push   %ebp
f0105627:	89 e5                	mov    %esp,%ebp
f0105629:	57                   	push   %edi
f010562a:	56                   	push   %esi
f010562b:	8b 45 08             	mov    0x8(%ebp),%eax
f010562e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105631:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0105634:	39 c6                	cmp    %eax,%esi
f0105636:	73 35                	jae    f010566d <memmove+0x47>
f0105638:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f010563b:	39 d0                	cmp    %edx,%eax
f010563d:	73 2e                	jae    f010566d <memmove+0x47>
		s += n;
		d += n;
f010563f:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0105642:	89 d6                	mov    %edx,%esi
f0105644:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105646:	f7 c6 03 00 00 00    	test   $0x3,%esi
f010564c:	75 13                	jne    f0105661 <memmove+0x3b>
f010564e:	f6 c1 03             	test   $0x3,%cl
f0105651:	75 0e                	jne    f0105661 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0105653:	83 ef 04             	sub    $0x4,%edi
f0105656:	8d 72 fc             	lea    -0x4(%edx),%esi
f0105659:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f010565c:	fd                   	std    
f010565d:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f010565f:	eb 09                	jmp    f010566a <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0105661:	83 ef 01             	sub    $0x1,%edi
f0105664:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0105667:	fd                   	std    
f0105668:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f010566a:	fc                   	cld    
f010566b:	eb 1d                	jmp    f010568a <memmove+0x64>
f010566d:	89 f2                	mov    %esi,%edx
f010566f:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105671:	f6 c2 03             	test   $0x3,%dl
f0105674:	75 0f                	jne    f0105685 <memmove+0x5f>
f0105676:	f6 c1 03             	test   $0x3,%cl
f0105679:	75 0a                	jne    f0105685 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f010567b:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f010567e:	89 c7                	mov    %eax,%edi
f0105680:	fc                   	cld    
f0105681:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0105683:	eb 05                	jmp    f010568a <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0105685:	89 c7                	mov    %eax,%edi
f0105687:	fc                   	cld    
f0105688:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f010568a:	5e                   	pop    %esi
f010568b:	5f                   	pop    %edi
f010568c:	5d                   	pop    %ebp
f010568d:	c3                   	ret    

f010568e <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f010568e:	55                   	push   %ebp
f010568f:	89 e5                	mov    %esp,%ebp
f0105691:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0105694:	8b 45 10             	mov    0x10(%ebp),%eax
f0105697:	89 44 24 08          	mov    %eax,0x8(%esp)
f010569b:	8b 45 0c             	mov    0xc(%ebp),%eax
f010569e:	89 44 24 04          	mov    %eax,0x4(%esp)
f01056a2:	8b 45 08             	mov    0x8(%ebp),%eax
f01056a5:	89 04 24             	mov    %eax,(%esp)
f01056a8:	e8 79 ff ff ff       	call   f0105626 <memmove>
}
f01056ad:	c9                   	leave  
f01056ae:	c3                   	ret    

f01056af <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f01056af:	55                   	push   %ebp
f01056b0:	89 e5                	mov    %esp,%ebp
f01056b2:	57                   	push   %edi
f01056b3:	56                   	push   %esi
f01056b4:	53                   	push   %ebx
f01056b5:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01056b8:	8b 75 0c             	mov    0xc(%ebp),%esi
f01056bb:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01056be:	8d 78 ff             	lea    -0x1(%eax),%edi
f01056c1:	85 c0                	test   %eax,%eax
f01056c3:	74 36                	je     f01056fb <memcmp+0x4c>
		if (*s1 != *s2)
f01056c5:	0f b6 03             	movzbl (%ebx),%eax
f01056c8:	0f b6 0e             	movzbl (%esi),%ecx
f01056cb:	ba 00 00 00 00       	mov    $0x0,%edx
f01056d0:	38 c8                	cmp    %cl,%al
f01056d2:	74 1c                	je     f01056f0 <memcmp+0x41>
f01056d4:	eb 10                	jmp    f01056e6 <memcmp+0x37>
f01056d6:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f01056db:	83 c2 01             	add    $0x1,%edx
f01056de:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f01056e2:	38 c8                	cmp    %cl,%al
f01056e4:	74 0a                	je     f01056f0 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f01056e6:	0f b6 c0             	movzbl %al,%eax
f01056e9:	0f b6 c9             	movzbl %cl,%ecx
f01056ec:	29 c8                	sub    %ecx,%eax
f01056ee:	eb 10                	jmp    f0105700 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01056f0:	39 fa                	cmp    %edi,%edx
f01056f2:	75 e2                	jne    f01056d6 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f01056f4:	b8 00 00 00 00       	mov    $0x0,%eax
f01056f9:	eb 05                	jmp    f0105700 <memcmp+0x51>
f01056fb:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105700:	5b                   	pop    %ebx
f0105701:	5e                   	pop    %esi
f0105702:	5f                   	pop    %edi
f0105703:	5d                   	pop    %ebp
f0105704:	c3                   	ret    

f0105705 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0105705:	55                   	push   %ebp
f0105706:	89 e5                	mov    %esp,%ebp
f0105708:	53                   	push   %ebx
f0105709:	8b 45 08             	mov    0x8(%ebp),%eax
f010570c:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f010570f:	89 c2                	mov    %eax,%edx
f0105711:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0105714:	39 d0                	cmp    %edx,%eax
f0105716:	73 13                	jae    f010572b <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f0105718:	89 d9                	mov    %ebx,%ecx
f010571a:	38 18                	cmp    %bl,(%eax)
f010571c:	75 06                	jne    f0105724 <memfind+0x1f>
f010571e:	eb 0b                	jmp    f010572b <memfind+0x26>
f0105720:	38 08                	cmp    %cl,(%eax)
f0105722:	74 07                	je     f010572b <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f0105724:	83 c0 01             	add    $0x1,%eax
f0105727:	39 d0                	cmp    %edx,%eax
f0105729:	75 f5                	jne    f0105720 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f010572b:	5b                   	pop    %ebx
f010572c:	5d                   	pop    %ebp
f010572d:	c3                   	ret    

f010572e <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f010572e:	55                   	push   %ebp
f010572f:	89 e5                	mov    %esp,%ebp
f0105731:	57                   	push   %edi
f0105732:	56                   	push   %esi
f0105733:	53                   	push   %ebx
f0105734:	8b 55 08             	mov    0x8(%ebp),%edx
f0105737:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010573a:	0f b6 0a             	movzbl (%edx),%ecx
f010573d:	80 f9 09             	cmp    $0x9,%cl
f0105740:	74 05                	je     f0105747 <strtol+0x19>
f0105742:	80 f9 20             	cmp    $0x20,%cl
f0105745:	75 10                	jne    f0105757 <strtol+0x29>
		s++;
f0105747:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010574a:	0f b6 0a             	movzbl (%edx),%ecx
f010574d:	80 f9 09             	cmp    $0x9,%cl
f0105750:	74 f5                	je     f0105747 <strtol+0x19>
f0105752:	80 f9 20             	cmp    $0x20,%cl
f0105755:	74 f0                	je     f0105747 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f0105757:	80 f9 2b             	cmp    $0x2b,%cl
f010575a:	75 0a                	jne    f0105766 <strtol+0x38>
		s++;
f010575c:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f010575f:	bf 00 00 00 00       	mov    $0x0,%edi
f0105764:	eb 11                	jmp    f0105777 <strtol+0x49>
f0105766:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f010576b:	80 f9 2d             	cmp    $0x2d,%cl
f010576e:	75 07                	jne    f0105777 <strtol+0x49>
		s++, neg = 1;
f0105770:	83 c2 01             	add    $0x1,%edx
f0105773:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0105777:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f010577c:	75 15                	jne    f0105793 <strtol+0x65>
f010577e:	80 3a 30             	cmpb   $0x30,(%edx)
f0105781:	75 10                	jne    f0105793 <strtol+0x65>
f0105783:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0105787:	75 0a                	jne    f0105793 <strtol+0x65>
		s += 2, base = 16;
f0105789:	83 c2 02             	add    $0x2,%edx
f010578c:	b8 10 00 00 00       	mov    $0x10,%eax
f0105791:	eb 10                	jmp    f01057a3 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f0105793:	85 c0                	test   %eax,%eax
f0105795:	75 0c                	jne    f01057a3 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0105797:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0105799:	80 3a 30             	cmpb   $0x30,(%edx)
f010579c:	75 05                	jne    f01057a3 <strtol+0x75>
		s++, base = 8;
f010579e:	83 c2 01             	add    $0x1,%edx
f01057a1:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f01057a3:	bb 00 00 00 00       	mov    $0x0,%ebx
f01057a8:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f01057ab:	0f b6 0a             	movzbl (%edx),%ecx
f01057ae:	8d 71 d0             	lea    -0x30(%ecx),%esi
f01057b1:	89 f0                	mov    %esi,%eax
f01057b3:	3c 09                	cmp    $0x9,%al
f01057b5:	77 08                	ja     f01057bf <strtol+0x91>
			dig = *s - '0';
f01057b7:	0f be c9             	movsbl %cl,%ecx
f01057ba:	83 e9 30             	sub    $0x30,%ecx
f01057bd:	eb 20                	jmp    f01057df <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f01057bf:	8d 71 9f             	lea    -0x61(%ecx),%esi
f01057c2:	89 f0                	mov    %esi,%eax
f01057c4:	3c 19                	cmp    $0x19,%al
f01057c6:	77 08                	ja     f01057d0 <strtol+0xa2>
			dig = *s - 'a' + 10;
f01057c8:	0f be c9             	movsbl %cl,%ecx
f01057cb:	83 e9 57             	sub    $0x57,%ecx
f01057ce:	eb 0f                	jmp    f01057df <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f01057d0:	8d 71 bf             	lea    -0x41(%ecx),%esi
f01057d3:	89 f0                	mov    %esi,%eax
f01057d5:	3c 19                	cmp    $0x19,%al
f01057d7:	77 16                	ja     f01057ef <strtol+0xc1>
			dig = *s - 'A' + 10;
f01057d9:	0f be c9             	movsbl %cl,%ecx
f01057dc:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f01057df:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f01057e2:	7d 0f                	jge    f01057f3 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f01057e4:	83 c2 01             	add    $0x1,%edx
f01057e7:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f01057eb:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f01057ed:	eb bc                	jmp    f01057ab <strtol+0x7d>
f01057ef:	89 d8                	mov    %ebx,%eax
f01057f1:	eb 02                	jmp    f01057f5 <strtol+0xc7>
f01057f3:	89 d8                	mov    %ebx,%eax

	if (endptr)
f01057f5:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f01057f9:	74 05                	je     f0105800 <strtol+0xd2>
		*endptr = (char *) s;
f01057fb:	8b 75 0c             	mov    0xc(%ebp),%esi
f01057fe:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f0105800:	f7 d8                	neg    %eax
f0105802:	85 ff                	test   %edi,%edi
f0105804:	0f 44 c3             	cmove  %ebx,%eax
}
f0105807:	5b                   	pop    %ebx
f0105808:	5e                   	pop    %esi
f0105809:	5f                   	pop    %edi
f010580a:	5d                   	pop    %ebp
f010580b:	c3                   	ret    

f010580c <mpentry_start>:
.set PROT_MODE_DSEG, 0x10	# kernel data segment selector

.code16           
.globl mpentry_start
mpentry_start:
	cli            
f010580c:	fa                   	cli    

	xorw    %ax, %ax
f010580d:	31 c0                	xor    %eax,%eax
	movw    %ax, %ds
f010580f:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0105811:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0105813:	8e d0                	mov    %eax,%ss

	lgdt    MPBOOTPHYS(gdtdesc)
f0105815:	0f 01 16             	lgdtl  (%esi)
f0105818:	74 70                	je     f010588a <mpentry_end+0x4>
	movl    %cr0, %eax
f010581a:	0f 20 c0             	mov    %cr0,%eax
	orl     $CR0_PE, %eax
f010581d:	66 83 c8 01          	or     $0x1,%ax
	movl    %eax, %cr0
f0105821:	0f 22 c0             	mov    %eax,%cr0

	ljmpl   $(PROT_MODE_CSEG), $(MPBOOTPHYS(start32))
f0105824:	66 ea 20 70 00 00    	ljmpw  $0x0,$0x7020
f010582a:	08 00                	or     %al,(%eax)

f010582c <start32>:

.code32
start32:
	movw    $(PROT_MODE_DSEG), %ax
f010582c:	66 b8 10 00          	mov    $0x10,%ax
	movw    %ax, %ds
f0105830:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0105832:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0105834:	8e d0                	mov    %eax,%ss
	movw    $0, %ax
f0105836:	66 b8 00 00          	mov    $0x0,%ax
	movw    %ax, %fs
f010583a:	8e e0                	mov    %eax,%fs
	movw    %ax, %gs
f010583c:	8e e8                	mov    %eax,%gs

	# Set up initial page table. We cannot use kern_pgdir yet because
	# we are still running at a low EIP.
	movl    $(RELOC(entry_pgdir)), %eax
f010583e:	b8 00 d0 11 00       	mov    $0x11d000,%eax
	movl    %eax, %cr3
f0105843:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl    %cr0, %eax
f0105846:	0f 20 c0             	mov    %cr0,%eax
	orl     $(CR0_PE|CR0_PG|CR0_WP), %eax
f0105849:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl    %eax, %cr0
f010584e:	0f 22 c0             	mov    %eax,%cr0

	# Switch to the per-cpu stack allocated in mem_init()
	movl    mpentry_kstack, %esp
f0105851:	8b 25 04 2f 22 f0    	mov    0xf0222f04,%esp
	movl    $0x0, %ebp       # nuke frame pointer
f0105857:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Call mp_main().  (Exercise for the reader: why the indirect call?)
	movl    $mp_main, %eax
f010585c:	b8 1d 02 10 f0       	mov    $0xf010021d,%eax
	call    *%eax
f0105861:	ff d0                	call   *%eax

f0105863 <spin>:

	# If mp_main returns (it shouldn't), loop.
spin:
	jmp     spin
f0105863:	eb fe                	jmp    f0105863 <spin>
f0105865:	8d 76 00             	lea    0x0(%esi),%esi

f0105868 <gdt>:
	...
f0105870:	ff                   	(bad)  
f0105871:	ff 00                	incl   (%eax)
f0105873:	00 00                	add    %al,(%eax)
f0105875:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
f010587c:	00 92 cf 00 17 00    	add    %dl,0x1700cf(%edx)

f0105880 <gdtdesc>:
f0105880:	17                   	pop    %ss
f0105881:	00 5c 70 00          	add    %bl,0x0(%eax,%esi,2)
	...

f0105886 <mpentry_end>:
	.word   0x17				# sizeof(gdt) - 1
	.long   MPBOOTPHYS(gdt)			# address gdt

.globl mpentry_end
mpentry_end:
	nop
f0105886:	90                   	nop
f0105887:	66 90                	xchg   %ax,%ax
f0105889:	66 90                	xchg   %ax,%ax
f010588b:	66 90                	xchg   %ax,%ax
f010588d:	66 90                	xchg   %ax,%ax
f010588f:	90                   	nop

f0105890 <mpsearch1>:
}

// Look for an MP structure in the len bytes at physical address addr.
static struct mp *
mpsearch1(physaddr_t a, int len)
{
f0105890:	55                   	push   %ebp
f0105891:	89 e5                	mov    %esp,%ebp
f0105893:	56                   	push   %esi
f0105894:	53                   	push   %ebx
f0105895:	83 ec 10             	sub    $0x10,%esp
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105898:	8b 0d 08 2f 22 f0    	mov    0xf0222f08,%ecx
f010589e:	89 c3                	mov    %eax,%ebx
f01058a0:	c1 eb 0c             	shr    $0xc,%ebx
f01058a3:	39 cb                	cmp    %ecx,%ebx
f01058a5:	72 20                	jb     f01058c7 <mpsearch1+0x37>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01058a7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01058ab:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f01058b2:	f0 
f01058b3:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f01058ba:	00 
f01058bb:	c7 04 24 41 7d 10 f0 	movl   $0xf0107d41,(%esp)
f01058c2:	e8 79 a7 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01058c7:	8d 98 00 00 00 f0    	lea    -0x10000000(%eax),%ebx
	struct mp *mp = KADDR(a), *end = KADDR(a + len);
f01058cd:	01 d0                	add    %edx,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01058cf:	89 c2                	mov    %eax,%edx
f01058d1:	c1 ea 0c             	shr    $0xc,%edx
f01058d4:	39 d1                	cmp    %edx,%ecx
f01058d6:	77 20                	ja     f01058f8 <mpsearch1+0x68>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01058d8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01058dc:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f01058e3:	f0 
f01058e4:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f01058eb:	00 
f01058ec:	c7 04 24 41 7d 10 f0 	movl   $0xf0107d41,(%esp)
f01058f3:	e8 48 a7 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01058f8:	8d b0 00 00 00 f0    	lea    -0x10000000(%eax),%esi

	for (; mp < end; mp++)
f01058fe:	39 f3                	cmp    %esi,%ebx
f0105900:	73 40                	jae    f0105942 <mpsearch1+0xb2>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0105902:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0105909:	00 
f010590a:	c7 44 24 04 51 7d 10 	movl   $0xf0107d51,0x4(%esp)
f0105911:	f0 
f0105912:	89 1c 24             	mov    %ebx,(%esp)
f0105915:	e8 95 fd ff ff       	call   f01056af <memcmp>
f010591a:	85 c0                	test   %eax,%eax
f010591c:	75 17                	jne    f0105935 <mpsearch1+0xa5>
f010591e:	ba 00 00 00 00       	mov    $0x0,%edx
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
		sum += ((uint8_t *)addr)[i];
f0105923:	0f b6 0c 03          	movzbl (%ebx,%eax,1),%ecx
f0105927:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105929:	83 c0 01             	add    $0x1,%eax
f010592c:	83 f8 10             	cmp    $0x10,%eax
f010592f:	75 f2                	jne    f0105923 <mpsearch1+0x93>
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0105931:	84 d2                	test   %dl,%dl
f0105933:	74 14                	je     f0105949 <mpsearch1+0xb9>
static struct mp *
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
f0105935:	83 c3 10             	add    $0x10,%ebx
f0105938:	39 f3                	cmp    %esi,%ebx
f010593a:	72 c6                	jb     f0105902 <mpsearch1+0x72>
f010593c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0105940:	eb 0b                	jmp    f010594d <mpsearch1+0xbd>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
		    sum(mp, sizeof(*mp)) == 0)
			return mp;
	return NULL;
f0105942:	b8 00 00 00 00       	mov    $0x0,%eax
f0105947:	eb 09                	jmp    f0105952 <mpsearch1+0xc2>
f0105949:	89 d8                	mov    %ebx,%eax
f010594b:	eb 05                	jmp    f0105952 <mpsearch1+0xc2>
f010594d:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105952:	83 c4 10             	add    $0x10,%esp
f0105955:	5b                   	pop    %ebx
f0105956:	5e                   	pop    %esi
f0105957:	5d                   	pop    %ebp
f0105958:	c3                   	ret    

f0105959 <mp_init>:
	return conf;
}

void
mp_init(void)
{
f0105959:	55                   	push   %ebp
f010595a:	89 e5                	mov    %esp,%ebp
f010595c:	57                   	push   %edi
f010595d:	56                   	push   %esi
f010595e:	53                   	push   %ebx
f010595f:	83 ec 2c             	sub    $0x2c,%esp
	struct mpconf *conf;
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
f0105962:	c7 05 c0 33 22 f0 20 	movl   $0xf0223020,0xf02233c0
f0105969:	30 22 f0 
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010596c:	83 3d 08 2f 22 f0 00 	cmpl   $0x0,0xf0222f08
f0105973:	75 24                	jne    f0105999 <mp_init+0x40>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105975:	c7 44 24 0c 00 04 00 	movl   $0x400,0xc(%esp)
f010597c:	00 
f010597d:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f0105984:	f0 
f0105985:	c7 44 24 04 6f 00 00 	movl   $0x6f,0x4(%esp)
f010598c:	00 
f010598d:	c7 04 24 41 7d 10 f0 	movl   $0xf0107d41,(%esp)
f0105994:	e8 a7 a6 ff ff       	call   f0100040 <_panic>
	// The BIOS data area lives in 16-bit segment 0x40.
	bda = (uint8_t *) KADDR(0x40 << 4);

	// [MP 4] The 16-bit segment of the EBDA is in the two bytes
	// starting at byte 0x0E of the BDA.  0 if not present.
	if ((p = *(uint16_t *) (bda + 0x0E))) {
f0105999:	0f b7 05 0e 04 00 f0 	movzwl 0xf000040e,%eax
f01059a0:	85 c0                	test   %eax,%eax
f01059a2:	74 16                	je     f01059ba <mp_init+0x61>
		p <<= 4;	// Translate from segment to PA
f01059a4:	c1 e0 04             	shl    $0x4,%eax
		if ((mp = mpsearch1(p, 1024)))
f01059a7:	ba 00 04 00 00       	mov    $0x400,%edx
f01059ac:	e8 df fe ff ff       	call   f0105890 <mpsearch1>
f01059b1:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01059b4:	85 c0                	test   %eax,%eax
f01059b6:	75 3c                	jne    f01059f4 <mp_init+0x9b>
f01059b8:	eb 20                	jmp    f01059da <mp_init+0x81>
			return mp;
	} else {
		// The size of base memory, in KB is in the two bytes
		// starting at 0x13 of the BDA.
		p = *(uint16_t *) (bda + 0x13) * 1024;
f01059ba:	0f b7 05 13 04 00 f0 	movzwl 0xf0000413,%eax
f01059c1:	c1 e0 0a             	shl    $0xa,%eax
		if ((mp = mpsearch1(p - 1024, 1024)))
f01059c4:	2d 00 04 00 00       	sub    $0x400,%eax
f01059c9:	ba 00 04 00 00       	mov    $0x400,%edx
f01059ce:	e8 bd fe ff ff       	call   f0105890 <mpsearch1>
f01059d3:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01059d6:	85 c0                	test   %eax,%eax
f01059d8:	75 1a                	jne    f01059f4 <mp_init+0x9b>
			return mp;
	}
	return mpsearch1(0xF0000, 0x10000);
f01059da:	ba 00 00 01 00       	mov    $0x10000,%edx
f01059df:	b8 00 00 0f 00       	mov    $0xf0000,%eax
f01059e4:	e8 a7 fe ff ff       	call   f0105890 <mpsearch1>
f01059e9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
mpconfig(struct mp **pmp)
{
	struct mpconf *conf;
	struct mp *mp;

	if ((mp = mpsearch()) == 0)
f01059ec:	85 c0                	test   %eax,%eax
f01059ee:	0f 84 5f 02 00 00    	je     f0105c53 <mp_init+0x2fa>
		return NULL;
	if (mp->physaddr == 0 || mp->type != 0) {
f01059f4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01059f7:	8b 70 04             	mov    0x4(%eax),%esi
f01059fa:	85 f6                	test   %esi,%esi
f01059fc:	74 06                	je     f0105a04 <mp_init+0xab>
f01059fe:	80 78 0b 00          	cmpb   $0x0,0xb(%eax)
f0105a02:	74 11                	je     f0105a15 <mp_init+0xbc>
		cprintf("SMP: Default configurations not implemented\n");
f0105a04:	c7 04 24 b4 7b 10 f0 	movl   $0xf0107bb4,(%esp)
f0105a0b:	e8 6c e4 ff ff       	call   f0103e7c <cprintf>
f0105a10:	e9 3e 02 00 00       	jmp    f0105c53 <mp_init+0x2fa>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105a15:	89 f0                	mov    %esi,%eax
f0105a17:	c1 e8 0c             	shr    $0xc,%eax
f0105a1a:	3b 05 08 2f 22 f0    	cmp    0xf0222f08,%eax
f0105a20:	72 20                	jb     f0105a42 <mp_init+0xe9>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105a22:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105a26:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f0105a2d:	f0 
f0105a2e:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f0105a35:	00 
f0105a36:	c7 04 24 41 7d 10 f0 	movl   $0xf0107d41,(%esp)
f0105a3d:	e8 fe a5 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0105a42:	8d 9e 00 00 00 f0    	lea    -0x10000000(%esi),%ebx
		return NULL;
	}
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
f0105a48:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0105a4f:	00 
f0105a50:	c7 44 24 04 56 7d 10 	movl   $0xf0107d56,0x4(%esp)
f0105a57:	f0 
f0105a58:	89 1c 24             	mov    %ebx,(%esp)
f0105a5b:	e8 4f fc ff ff       	call   f01056af <memcmp>
f0105a60:	85 c0                	test   %eax,%eax
f0105a62:	74 11                	je     f0105a75 <mp_init+0x11c>
		cprintf("SMP: Incorrect MP configuration table signature\n");
f0105a64:	c7 04 24 e4 7b 10 f0 	movl   $0xf0107be4,(%esp)
f0105a6b:	e8 0c e4 ff ff       	call   f0103e7c <cprintf>
f0105a70:	e9 de 01 00 00       	jmp    f0105c53 <mp_init+0x2fa>
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0105a75:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0105a79:	66 89 45 e2          	mov    %ax,-0x1e(%ebp)
f0105a7d:	0f b7 f8             	movzwl %ax,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105a80:	85 ff                	test   %edi,%edi
f0105a82:	7e 30                	jle    f0105ab4 <mp_init+0x15b>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105a84:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0105a89:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0105a8e:	0f b6 8c 30 00 00 00 	movzbl -0x10000000(%eax,%esi,1),%ecx
f0105a95:	f0 
f0105a96:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105a98:	83 c0 01             	add    $0x1,%eax
f0105a9b:	39 c7                	cmp    %eax,%edi
f0105a9d:	7f ef                	jg     f0105a8e <mp_init+0x135>
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
		cprintf("SMP: Incorrect MP configuration table signature\n");
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0105a9f:	84 d2                	test   %dl,%dl
f0105aa1:	74 11                	je     f0105ab4 <mp_init+0x15b>
		cprintf("SMP: Bad MP configuration checksum\n");
f0105aa3:	c7 04 24 18 7c 10 f0 	movl   $0xf0107c18,(%esp)
f0105aaa:	e8 cd e3 ff ff       	call   f0103e7c <cprintf>
f0105aaf:	e9 9f 01 00 00       	jmp    f0105c53 <mp_init+0x2fa>
		return NULL;
	}
	if (conf->version != 1 && conf->version != 4) {
f0105ab4:	0f b6 43 06          	movzbl 0x6(%ebx),%eax
f0105ab8:	3c 04                	cmp    $0x4,%al
f0105aba:	74 1e                	je     f0105ada <mp_init+0x181>
f0105abc:	3c 01                	cmp    $0x1,%al
f0105abe:	66 90                	xchg   %ax,%ax
f0105ac0:	74 18                	je     f0105ada <mp_init+0x181>
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
f0105ac2:	0f b6 c0             	movzbl %al,%eax
f0105ac5:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105ac9:	c7 04 24 3c 7c 10 f0 	movl   $0xf0107c3c,(%esp)
f0105ad0:	e8 a7 e3 ff ff       	call   f0103e7c <cprintf>
f0105ad5:	e9 79 01 00 00       	jmp    f0105c53 <mp_init+0x2fa>
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0105ada:	0f b7 73 28          	movzwl 0x28(%ebx),%esi
f0105ade:	0f b7 7d e2          	movzwl -0x1e(%ebp),%edi
f0105ae2:	01 df                	add    %ebx,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105ae4:	85 f6                	test   %esi,%esi
f0105ae6:	7e 19                	jle    f0105b01 <mp_init+0x1a8>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105ae8:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0105aed:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0105af2:	0f b6 0c 07          	movzbl (%edi,%eax,1),%ecx
f0105af6:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105af8:	83 c0 01             	add    $0x1,%eax
f0105afb:	39 c6                	cmp    %eax,%esi
f0105afd:	7f f3                	jg     f0105af2 <mp_init+0x199>
f0105aff:	eb 05                	jmp    f0105b06 <mp_init+0x1ad>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105b01:	ba 00 00 00 00       	mov    $0x0,%edx
	}
	if (conf->version != 1 && conf->version != 4) {
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0105b06:	38 53 2a             	cmp    %dl,0x2a(%ebx)
f0105b09:	74 11                	je     f0105b1c <mp_init+0x1c3>
		cprintf("SMP: Bad MP configuration extended checksum\n");
f0105b0b:	c7 04 24 5c 7c 10 f0 	movl   $0xf0107c5c,(%esp)
f0105b12:	e8 65 e3 ff ff       	call   f0103e7c <cprintf>
f0105b17:	e9 37 01 00 00       	jmp    f0105c53 <mp_init+0x2fa>
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
	if ((conf = mpconfig(&mp)) == 0)
f0105b1c:	85 db                	test   %ebx,%ebx
f0105b1e:	0f 84 2f 01 00 00    	je     f0105c53 <mp_init+0x2fa>
		return;
	ismp = 1;
f0105b24:	c7 05 00 30 22 f0 01 	movl   $0x1,0xf0223000
f0105b2b:	00 00 00 
	lapic = (uint32_t *)conf->lapicaddr;
f0105b2e:	8b 43 24             	mov    0x24(%ebx),%eax
f0105b31:	a3 00 40 26 f0       	mov    %eax,0xf0264000

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0105b36:	8d 7b 2c             	lea    0x2c(%ebx),%edi
f0105b39:	66 83 7b 22 00       	cmpw   $0x0,0x22(%ebx)
f0105b3e:	0f 84 94 00 00 00    	je     f0105bd8 <mp_init+0x27f>
f0105b44:	be 00 00 00 00       	mov    $0x0,%esi
		switch (*p) {
f0105b49:	0f b6 07             	movzbl (%edi),%eax
f0105b4c:	84 c0                	test   %al,%al
f0105b4e:	74 06                	je     f0105b56 <mp_init+0x1fd>
f0105b50:	3c 04                	cmp    $0x4,%al
f0105b52:	77 54                	ja     f0105ba8 <mp_init+0x24f>
f0105b54:	eb 4d                	jmp    f0105ba3 <mp_init+0x24a>
		case MPPROC:
			proc = (struct mpproc *)p;
			if (proc->flags & MPPROC_BOOT)
f0105b56:	f6 47 03 02          	testb  $0x2,0x3(%edi)
f0105b5a:	74 11                	je     f0105b6d <mp_init+0x214>
				bootcpu = &cpus[ncpu];
f0105b5c:	6b 05 c4 33 22 f0 74 	imul   $0x74,0xf02233c4,%eax
f0105b63:	05 20 30 22 f0       	add    $0xf0223020,%eax
f0105b68:	a3 c0 33 22 f0       	mov    %eax,0xf02233c0
			if (ncpu < NCPU) {
f0105b6d:	a1 c4 33 22 f0       	mov    0xf02233c4,%eax
f0105b72:	83 f8 07             	cmp    $0x7,%eax
f0105b75:	7f 13                	jg     f0105b8a <mp_init+0x231>
				cpus[ncpu].cpu_id = ncpu;
f0105b77:	6b d0 74             	imul   $0x74,%eax,%edx
f0105b7a:	88 82 20 30 22 f0    	mov    %al,-0xfddcfe0(%edx)
				ncpu++;
f0105b80:	83 c0 01             	add    $0x1,%eax
f0105b83:	a3 c4 33 22 f0       	mov    %eax,0xf02233c4
f0105b88:	eb 14                	jmp    f0105b9e <mp_init+0x245>
			} else {
				cprintf("SMP: too many CPUs, CPU %d disabled\n",
f0105b8a:	0f b6 47 01          	movzbl 0x1(%edi),%eax
f0105b8e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105b92:	c7 04 24 8c 7c 10 f0 	movl   $0xf0107c8c,(%esp)
f0105b99:	e8 de e2 ff ff       	call   f0103e7c <cprintf>
					proc->apicid);
			}
			p += sizeof(struct mpproc);
f0105b9e:	83 c7 14             	add    $0x14,%edi
			continue;
f0105ba1:	eb 26                	jmp    f0105bc9 <mp_init+0x270>
		case MPBUS:
		case MPIOAPIC:
		case MPIOINTR:
		case MPLINTR:
			p += 8;
f0105ba3:	83 c7 08             	add    $0x8,%edi
			continue;
f0105ba6:	eb 21                	jmp    f0105bc9 <mp_init+0x270>
		default:
			cprintf("mpinit: unknown config type %x\n", *p);
f0105ba8:	0f b6 c0             	movzbl %al,%eax
f0105bab:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105baf:	c7 04 24 b4 7c 10 f0 	movl   $0xf0107cb4,(%esp)
f0105bb6:	e8 c1 e2 ff ff       	call   f0103e7c <cprintf>
			ismp = 0;
f0105bbb:	c7 05 00 30 22 f0 00 	movl   $0x0,0xf0223000
f0105bc2:	00 00 00 
			i = conf->entry;
f0105bc5:	0f b7 73 22          	movzwl 0x22(%ebx),%esi
	if ((conf = mpconfig(&mp)) == 0)
		return;
	ismp = 1;
	lapic = (uint32_t *)conf->lapicaddr;

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0105bc9:	83 c6 01             	add    $0x1,%esi
f0105bcc:	0f b7 43 22          	movzwl 0x22(%ebx),%eax
f0105bd0:	39 f0                	cmp    %esi,%eax
f0105bd2:	0f 87 71 ff ff ff    	ja     f0105b49 <mp_init+0x1f0>
			ismp = 0;
			i = conf->entry;
		}
	}

	bootcpu->cpu_status = CPU_STARTED;
f0105bd8:	a1 c0 33 22 f0       	mov    0xf02233c0,%eax
f0105bdd:	c7 40 04 01 00 00 00 	movl   $0x1,0x4(%eax)
	if (!ismp) {
f0105be4:	83 3d 00 30 22 f0 00 	cmpl   $0x0,0xf0223000
f0105beb:	75 22                	jne    f0105c0f <mp_init+0x2b6>
		// Didn't like what we found; fall back to no MP.
		ncpu = 1;
f0105bed:	c7 05 c4 33 22 f0 01 	movl   $0x1,0xf02233c4
f0105bf4:	00 00 00 
		lapic = NULL;
f0105bf7:	c7 05 00 40 26 f0 00 	movl   $0x0,0xf0264000
f0105bfe:	00 00 00 
		cprintf("SMP: configuration not found, SMP disabled\n");
f0105c01:	c7 04 24 d4 7c 10 f0 	movl   $0xf0107cd4,(%esp)
f0105c08:	e8 6f e2 ff ff       	call   f0103e7c <cprintf>
		return;
f0105c0d:	eb 44                	jmp    f0105c53 <mp_init+0x2fa>
	}
	cprintf("SMP: CPU %d found %d CPU(s)\n", bootcpu->cpu_id,  ncpu);
f0105c0f:	8b 15 c4 33 22 f0    	mov    0xf02233c4,%edx
f0105c15:	89 54 24 08          	mov    %edx,0x8(%esp)
f0105c19:	0f b6 00             	movzbl (%eax),%eax
f0105c1c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105c20:	c7 04 24 5b 7d 10 f0 	movl   $0xf0107d5b,(%esp)
f0105c27:	e8 50 e2 ff ff       	call   f0103e7c <cprintf>

	if (mp->imcrp) {
f0105c2c:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105c2f:	80 78 0c 00          	cmpb   $0x0,0xc(%eax)
f0105c33:	74 1e                	je     f0105c53 <mp_init+0x2fa>
		// [MP 3.2.6.1] If the hardware implements PIC mode,
		// switch to getting interrupts from the LAPIC.
		cprintf("SMP: Setting IMCR to switch from PIC mode to symmetric I/O mode\n");
f0105c35:	c7 04 24 00 7d 10 f0 	movl   $0xf0107d00,(%esp)
f0105c3c:	e8 3b e2 ff ff       	call   f0103e7c <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0105c41:	ba 22 00 00 00       	mov    $0x22,%edx
f0105c46:	b8 70 00 00 00       	mov    $0x70,%eax
f0105c4b:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0105c4c:	b2 23                	mov    $0x23,%dl
f0105c4e:	ec                   	in     (%dx),%al
		outb(0x22, 0x70);   // Select IMCR
		outb(0x23, inb(0x23) | 1);  // Mask external interrupts.
f0105c4f:	83 c8 01             	or     $0x1,%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0105c52:	ee                   	out    %al,(%dx)
	}
}
f0105c53:	83 c4 2c             	add    $0x2c,%esp
f0105c56:	5b                   	pop    %ebx
f0105c57:	5e                   	pop    %esi
f0105c58:	5f                   	pop    %edi
f0105c59:	5d                   	pop    %ebp
f0105c5a:	c3                   	ret    

f0105c5b <lapicw>:

volatile uint32_t *lapic;  // Initialized in mp.c

static void
lapicw(int index, int value)
{
f0105c5b:	55                   	push   %ebp
f0105c5c:	89 e5                	mov    %esp,%ebp
	lapic[index] = value;
f0105c5e:	8b 0d 00 40 26 f0    	mov    0xf0264000,%ecx
f0105c64:	8d 04 81             	lea    (%ecx,%eax,4),%eax
f0105c67:	89 10                	mov    %edx,(%eax)
	lapic[ID];  // wait for write to finish, by reading
f0105c69:	a1 00 40 26 f0       	mov    0xf0264000,%eax
f0105c6e:	8b 40 20             	mov    0x20(%eax),%eax
}
f0105c71:	5d                   	pop    %ebp
f0105c72:	c3                   	ret    

f0105c73 <cpunum>:
	lapicw(TPR, 0);
}

int
cpunum(void)
{
f0105c73:	55                   	push   %ebp
f0105c74:	89 e5                	mov    %esp,%ebp
	if (lapic)
f0105c76:	a1 00 40 26 f0       	mov    0xf0264000,%eax
f0105c7b:	85 c0                	test   %eax,%eax
f0105c7d:	74 08                	je     f0105c87 <cpunum+0x14>
		return lapic[ID] >> 24;
f0105c7f:	8b 40 20             	mov    0x20(%eax),%eax
f0105c82:	c1 e8 18             	shr    $0x18,%eax
f0105c85:	eb 05                	jmp    f0105c8c <cpunum+0x19>
	return 0;
f0105c87:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105c8c:	5d                   	pop    %ebp
f0105c8d:	c3                   	ret    

f0105c8e <lapic_init>:
}

void
lapic_init(void)
{
	if (!lapic) 
f0105c8e:	83 3d 00 40 26 f0 00 	cmpl   $0x0,0xf0264000
f0105c95:	0f 84 0b 01 00 00    	je     f0105da6 <lapic_init+0x118>
	lapic[ID];  // wait for write to finish, by reading
}

void
lapic_init(void)
{
f0105c9b:	55                   	push   %ebp
f0105c9c:	89 e5                	mov    %esp,%ebp
	if (!lapic) 
		return;

	// Enable local APIC; set spurious interrupt vector.
	lapicw(SVR, ENABLE | (IRQ_OFFSET + IRQ_SPURIOUS));
f0105c9e:	ba 27 01 00 00       	mov    $0x127,%edx
f0105ca3:	b8 3c 00 00 00       	mov    $0x3c,%eax
f0105ca8:	e8 ae ff ff ff       	call   f0105c5b <lapicw>

	// The timer repeatedly counts down at bus frequency
	// from lapic[TICR] and then issues an interrupt.  
	// If we cared more about precise timekeeping,
	// TICR would be calibrated using an external time source.
	lapicw(TDCR, X1);
f0105cad:	ba 0b 00 00 00       	mov    $0xb,%edx
f0105cb2:	b8 f8 00 00 00       	mov    $0xf8,%eax
f0105cb7:	e8 9f ff ff ff       	call   f0105c5b <lapicw>
	lapicw(TIMER, PERIODIC | (IRQ_OFFSET + IRQ_TIMER));
f0105cbc:	ba 20 00 02 00       	mov    $0x20020,%edx
f0105cc1:	b8 c8 00 00 00       	mov    $0xc8,%eax
f0105cc6:	e8 90 ff ff ff       	call   f0105c5b <lapicw>
	lapicw(TICR, 10000000); 
f0105ccb:	ba 80 96 98 00       	mov    $0x989680,%edx
f0105cd0:	b8 e0 00 00 00       	mov    $0xe0,%eax
f0105cd5:	e8 81 ff ff ff       	call   f0105c5b <lapicw>
	//
	// According to Intel MP Specification, the BIOS should initialize
	// BSP's local APIC in Virtual Wire Mode, in which 8259A's
	// INTR is virtually connected to BSP's LINTIN0. In this mode,
	// we do not need to program the IOAPIC.
	if (thiscpu != bootcpu)
f0105cda:	e8 94 ff ff ff       	call   f0105c73 <cpunum>
f0105cdf:	6b c0 74             	imul   $0x74,%eax,%eax
f0105ce2:	05 20 30 22 f0       	add    $0xf0223020,%eax
f0105ce7:	39 05 c0 33 22 f0    	cmp    %eax,0xf02233c0
f0105ced:	74 0f                	je     f0105cfe <lapic_init+0x70>
		lapicw(LINT0, MASKED);
f0105cef:	ba 00 00 01 00       	mov    $0x10000,%edx
f0105cf4:	b8 d4 00 00 00       	mov    $0xd4,%eax
f0105cf9:	e8 5d ff ff ff       	call   f0105c5b <lapicw>

	// Disable NMI (LINT1) on all CPUs
	lapicw(LINT1, MASKED);
f0105cfe:	ba 00 00 01 00       	mov    $0x10000,%edx
f0105d03:	b8 d8 00 00 00       	mov    $0xd8,%eax
f0105d08:	e8 4e ff ff ff       	call   f0105c5b <lapicw>

	// Disable performance counter overflow interrupts
	// on machines that provide that interrupt entry.
	if (((lapic[VER]>>16) & 0xFF) >= 4)
f0105d0d:	a1 00 40 26 f0       	mov    0xf0264000,%eax
f0105d12:	8b 40 30             	mov    0x30(%eax),%eax
f0105d15:	c1 e8 10             	shr    $0x10,%eax
f0105d18:	3c 03                	cmp    $0x3,%al
f0105d1a:	76 0f                	jbe    f0105d2b <lapic_init+0x9d>
		lapicw(PCINT, MASKED);
f0105d1c:	ba 00 00 01 00       	mov    $0x10000,%edx
f0105d21:	b8 d0 00 00 00       	mov    $0xd0,%eax
f0105d26:	e8 30 ff ff ff       	call   f0105c5b <lapicw>

	// Map error interrupt to IRQ_ERROR.
	lapicw(ERROR, IRQ_OFFSET + IRQ_ERROR);
f0105d2b:	ba 33 00 00 00       	mov    $0x33,%edx
f0105d30:	b8 dc 00 00 00       	mov    $0xdc,%eax
f0105d35:	e8 21 ff ff ff       	call   f0105c5b <lapicw>

	// Clear error status register (requires back-to-back writes).
	lapicw(ESR, 0);
f0105d3a:	ba 00 00 00 00       	mov    $0x0,%edx
f0105d3f:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0105d44:	e8 12 ff ff ff       	call   f0105c5b <lapicw>
	lapicw(ESR, 0);
f0105d49:	ba 00 00 00 00       	mov    $0x0,%edx
f0105d4e:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0105d53:	e8 03 ff ff ff       	call   f0105c5b <lapicw>

	// Ack any outstanding interrupts.
	lapicw(EOI, 0);
f0105d58:	ba 00 00 00 00       	mov    $0x0,%edx
f0105d5d:	b8 2c 00 00 00       	mov    $0x2c,%eax
f0105d62:	e8 f4 fe ff ff       	call   f0105c5b <lapicw>

	// Send an Init Level De-Assert to synchronize arbitration ID's.
	lapicw(ICRHI, 0);
f0105d67:	ba 00 00 00 00       	mov    $0x0,%edx
f0105d6c:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0105d71:	e8 e5 fe ff ff       	call   f0105c5b <lapicw>
	lapicw(ICRLO, BCAST | INIT | LEVEL);
f0105d76:	ba 00 85 08 00       	mov    $0x88500,%edx
f0105d7b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0105d80:	e8 d6 fe ff ff       	call   f0105c5b <lapicw>
	while(lapic[ICRLO] & DELIVS)
f0105d85:	8b 15 00 40 26 f0    	mov    0xf0264000,%edx
f0105d8b:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f0105d91:	f6 c4 10             	test   $0x10,%ah
f0105d94:	75 f5                	jne    f0105d8b <lapic_init+0xfd>
		;

	// Enable interrupts on the APIC (but not on the processor).
	lapicw(TPR, 0);
f0105d96:	ba 00 00 00 00       	mov    $0x0,%edx
f0105d9b:	b8 20 00 00 00       	mov    $0x20,%eax
f0105da0:	e8 b6 fe ff ff       	call   f0105c5b <lapicw>
}
f0105da5:	5d                   	pop    %ebp
f0105da6:	f3 c3                	repz ret 

f0105da8 <lapic_eoi>:

// Acknowledge interrupt.
void
lapic_eoi(void)
{
	if (lapic)
f0105da8:	83 3d 00 40 26 f0 00 	cmpl   $0x0,0xf0264000
f0105daf:	74 13                	je     f0105dc4 <lapic_eoi+0x1c>
}

// Acknowledge interrupt.
void
lapic_eoi(void)
{
f0105db1:	55                   	push   %ebp
f0105db2:	89 e5                	mov    %esp,%ebp
	if (lapic)
		lapicw(EOI, 0);
f0105db4:	ba 00 00 00 00       	mov    $0x0,%edx
f0105db9:	b8 2c 00 00 00       	mov    $0x2c,%eax
f0105dbe:	e8 98 fe ff ff       	call   f0105c5b <lapicw>
}
f0105dc3:	5d                   	pop    %ebp
f0105dc4:	f3 c3                	repz ret 

f0105dc6 <lapic_startap>:

// Start additional processor running entry code at addr.
// See Appendix B of MultiProcessor Specification.
void
lapic_startap(uint8_t apicid, uint32_t addr)
{
f0105dc6:	55                   	push   %ebp
f0105dc7:	89 e5                	mov    %esp,%ebp
f0105dc9:	56                   	push   %esi
f0105dca:	53                   	push   %ebx
f0105dcb:	83 ec 10             	sub    $0x10,%esp
f0105dce:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105dd1:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105dd4:	ba 70 00 00 00       	mov    $0x70,%edx
f0105dd9:	b8 0f 00 00 00       	mov    $0xf,%eax
f0105dde:	ee                   	out    %al,(%dx)
f0105ddf:	b2 71                	mov    $0x71,%dl
f0105de1:	b8 0a 00 00 00       	mov    $0xa,%eax
f0105de6:	ee                   	out    %al,(%dx)
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105de7:	83 3d 08 2f 22 f0 00 	cmpl   $0x0,0xf0222f08
f0105dee:	75 24                	jne    f0105e14 <lapic_startap+0x4e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105df0:	c7 44 24 0c 67 04 00 	movl   $0x467,0xc(%esp)
f0105df7:	00 
f0105df8:	c7 44 24 08 a4 63 10 	movl   $0xf01063a4,0x8(%esp)
f0105dff:	f0 
f0105e00:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
f0105e07:	00 
f0105e08:	c7 04 24 78 7d 10 f0 	movl   $0xf0107d78,(%esp)
f0105e0f:	e8 2c a2 ff ff       	call   f0100040 <_panic>
	// and the warm reset vector (DWORD based at 40:67) to point at
	// the AP startup code prior to the [universal startup algorithm]."
	outb(IO_RTC, 0xF);  // offset 0xF is shutdown code
	outb(IO_RTC+1, 0x0A);
	wrv = (uint16_t *)KADDR((0x40 << 4 | 0x67));  // Warm reset vector
	wrv[0] = 0;
f0105e14:	66 c7 05 67 04 00 f0 	movw   $0x0,0xf0000467
f0105e1b:	00 00 
	wrv[1] = addr >> 4;
f0105e1d:	89 f0                	mov    %esi,%eax
f0105e1f:	c1 e8 04             	shr    $0x4,%eax
f0105e22:	66 a3 69 04 00 f0    	mov    %ax,0xf0000469

	// "Universal startup algorithm."
	// Send INIT (level-triggered) interrupt to reset other CPU.
	lapicw(ICRHI, apicid << 24);
f0105e28:	c1 e3 18             	shl    $0x18,%ebx
f0105e2b:	89 da                	mov    %ebx,%edx
f0105e2d:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0105e32:	e8 24 fe ff ff       	call   f0105c5b <lapicw>
	lapicw(ICRLO, INIT | LEVEL | ASSERT);
f0105e37:	ba 00 c5 00 00       	mov    $0xc500,%edx
f0105e3c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0105e41:	e8 15 fe ff ff       	call   f0105c5b <lapicw>
	microdelay(200);
	lapicw(ICRLO, INIT | LEVEL);
f0105e46:	ba 00 85 00 00       	mov    $0x8500,%edx
f0105e4b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0105e50:	e8 06 fe ff ff       	call   f0105c5b <lapicw>
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0105e55:	c1 ee 0c             	shr    $0xc,%esi
f0105e58:	81 ce 00 06 00 00    	or     $0x600,%esi
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f0105e5e:	89 da                	mov    %ebx,%edx
f0105e60:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0105e65:	e8 f1 fd ff ff       	call   f0105c5b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0105e6a:	89 f2                	mov    %esi,%edx
f0105e6c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0105e71:	e8 e5 fd ff ff       	call   f0105c5b <lapicw>
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f0105e76:	89 da                	mov    %ebx,%edx
f0105e78:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0105e7d:	e8 d9 fd ff ff       	call   f0105c5b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0105e82:	89 f2                	mov    %esi,%edx
f0105e84:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0105e89:	e8 cd fd ff ff       	call   f0105c5b <lapicw>
		microdelay(200);
	}
}
f0105e8e:	83 c4 10             	add    $0x10,%esp
f0105e91:	5b                   	pop    %ebx
f0105e92:	5e                   	pop    %esi
f0105e93:	5d                   	pop    %ebp
f0105e94:	c3                   	ret    

f0105e95 <lapic_ipi>:

void
lapic_ipi(int vector)
{
f0105e95:	55                   	push   %ebp
f0105e96:	89 e5                	mov    %esp,%ebp
	lapicw(ICRLO, OTHERS | FIXED | vector);
f0105e98:	8b 55 08             	mov    0x8(%ebp),%edx
f0105e9b:	81 ca 00 00 0c 00    	or     $0xc0000,%edx
f0105ea1:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0105ea6:	e8 b0 fd ff ff       	call   f0105c5b <lapicw>
	while (lapic[ICRLO] & DELIVS)
f0105eab:	8b 15 00 40 26 f0    	mov    0xf0264000,%edx
f0105eb1:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f0105eb7:	f6 c4 10             	test   $0x10,%ah
f0105eba:	75 f5                	jne    f0105eb1 <lapic_ipi+0x1c>
		;
}
f0105ebc:	5d                   	pop    %ebp
f0105ebd:	c3                   	ret    

f0105ebe <__spin_initlock>:
}
#endif

void
__spin_initlock(struct spinlock *lk, char *name)
{
f0105ebe:	55                   	push   %ebp
f0105ebf:	89 e5                	mov    %esp,%ebp
f0105ec1:	8b 45 08             	mov    0x8(%ebp),%eax
	lk->locked = 0;
f0105ec4:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
#ifdef DEBUG_SPINLOCK
	lk->name = name;
f0105eca:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105ecd:	89 50 04             	mov    %edx,0x4(%eax)
	lk->cpu = 0;
f0105ed0:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
#endif
}
f0105ed7:	5d                   	pop    %ebp
f0105ed8:	c3                   	ret    

f0105ed9 <spin_lock>:
// Loops (spins) until the lock is acquired.
// Holding a lock for a long time may cause
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
f0105ed9:	55                   	push   %ebp
f0105eda:	89 e5                	mov    %esp,%ebp
f0105edc:	56                   	push   %esi
f0105edd:	53                   	push   %ebx
f0105ede:	83 ec 20             	sub    $0x20,%esp
f0105ee1:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0105ee4:	83 3b 00             	cmpl   $0x0,(%ebx)
f0105ee7:	74 14                	je     f0105efd <spin_lock+0x24>
f0105ee9:	8b 73 08             	mov    0x8(%ebx),%esi
f0105eec:	e8 82 fd ff ff       	call   f0105c73 <cpunum>
f0105ef1:	6b c0 74             	imul   $0x74,%eax,%eax
f0105ef4:	05 20 30 22 f0       	add    $0xf0223020,%eax
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
f0105ef9:	39 c6                	cmp    %eax,%esi
f0105efb:	74 15                	je     f0105f12 <spin_lock+0x39>
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f0105efd:	89 da                	mov    %ebx,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f0105eff:	b8 01 00 00 00       	mov    $0x1,%eax
f0105f04:	f0 87 03             	lock xchg %eax,(%ebx)
f0105f07:	b9 01 00 00 00       	mov    $0x1,%ecx
f0105f0c:	85 c0                	test   %eax,%eax
f0105f0e:	75 2e                	jne    f0105f3e <spin_lock+0x65>
f0105f10:	eb 37                	jmp    f0105f49 <spin_lock+0x70>
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
		panic("CPU %d cannot acquire %s: already holding", cpunum(), lk->name);
f0105f12:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0105f15:	e8 59 fd ff ff       	call   f0105c73 <cpunum>
f0105f1a:	89 5c 24 10          	mov    %ebx,0x10(%esp)
f0105f1e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105f22:	c7 44 24 08 88 7d 10 	movl   $0xf0107d88,0x8(%esp)
f0105f29:	f0 
f0105f2a:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
f0105f31:	00 
f0105f32:	c7 04 24 ec 7d 10 f0 	movl   $0xf0107dec,(%esp)
f0105f39:	e8 02 a1 ff ff       	call   f0100040 <_panic>

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
		asm volatile ("pause");
f0105f3e:	f3 90                	pause  
f0105f40:	89 c8                	mov    %ecx,%eax
f0105f42:	f0 87 02             	lock xchg %eax,(%edx)
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f0105f45:	85 c0                	test   %eax,%eax
f0105f47:	75 f5                	jne    f0105f3e <spin_lock+0x65>
		asm volatile ("pause");

	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
f0105f49:	e8 25 fd ff ff       	call   f0105c73 <cpunum>
f0105f4e:	6b c0 74             	imul   $0x74,%eax,%eax
f0105f51:	05 20 30 22 f0       	add    $0xf0223020,%eax
f0105f56:	89 43 08             	mov    %eax,0x8(%ebx)
	get_caller_pcs(lk->pcs);
f0105f59:	8d 4b 0c             	lea    0xc(%ebx),%ecx

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f0105f5c:	89 e8                	mov    %ebp,%eax
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
f0105f5e:	8d 90 00 00 80 10    	lea    0x10800000(%eax),%edx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0105f64:	81 fa ff ff 7f 0e    	cmp    $0xe7fffff,%edx
f0105f6a:	76 3a                	jbe    f0105fa6 <spin_lock+0xcd>
f0105f6c:	eb 31                	jmp    f0105f9f <spin_lock+0xc6>
		    || ebp >= (uint32_t *)IOMEMBASE)
f0105f6e:	8d 9a 00 00 80 10    	lea    0x10800000(%edx),%ebx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0105f74:	81 fb ff ff 7f 0e    	cmp    $0xe7fffff,%ebx
f0105f7a:	77 12                	ja     f0105f8e <spin_lock+0xb5>
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f0105f7c:	8b 5a 04             	mov    0x4(%edx),%ebx
f0105f7f:	89 1c 81             	mov    %ebx,(%ecx,%eax,4)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f0105f82:	8b 12                	mov    (%edx),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f0105f84:	83 c0 01             	add    $0x1,%eax
f0105f87:	83 f8 0a             	cmp    $0xa,%eax
f0105f8a:	75 e2                	jne    f0105f6e <spin_lock+0x95>
f0105f8c:	eb 27                	jmp    f0105fb5 <spin_lock+0xdc>
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
		pcs[i] = 0;
f0105f8e:	c7 04 81 00 00 00 00 	movl   $0x0,(%ecx,%eax,4)
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
f0105f95:	83 c0 01             	add    $0x1,%eax
f0105f98:	83 f8 09             	cmp    $0x9,%eax
f0105f9b:	7e f1                	jle    f0105f8e <spin_lock+0xb5>
f0105f9d:	eb 16                	jmp    f0105fb5 <spin_lock+0xdc>
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f0105f9f:	b8 00 00 00 00       	mov    $0x0,%eax
f0105fa4:	eb e8                	jmp    f0105f8e <spin_lock+0xb5>
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f0105fa6:	8b 50 04             	mov    0x4(%eax),%edx
f0105fa9:	89 53 0c             	mov    %edx,0xc(%ebx)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f0105fac:	8b 10                	mov    (%eax),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f0105fae:	b8 01 00 00 00       	mov    $0x1,%eax
f0105fb3:	eb b9                	jmp    f0105f6e <spin_lock+0x95>
	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
	get_caller_pcs(lk->pcs);
#endif
}
f0105fb5:	83 c4 20             	add    $0x20,%esp
f0105fb8:	5b                   	pop    %ebx
f0105fb9:	5e                   	pop    %esi
f0105fba:	5d                   	pop    %ebp
f0105fbb:	c3                   	ret    

f0105fbc <spin_unlock>:

// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
f0105fbc:	55                   	push   %ebp
f0105fbd:	89 e5                	mov    %esp,%ebp
f0105fbf:	57                   	push   %edi
f0105fc0:	56                   	push   %esi
f0105fc1:	53                   	push   %ebx
f0105fc2:	83 ec 6c             	sub    $0x6c,%esp
f0105fc5:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0105fc8:	83 3b 00             	cmpl   $0x0,(%ebx)
f0105fcb:	74 18                	je     f0105fe5 <spin_unlock+0x29>
f0105fcd:	8b 73 08             	mov    0x8(%ebx),%esi
f0105fd0:	e8 9e fc ff ff       	call   f0105c73 <cpunum>
f0105fd5:	6b c0 74             	imul   $0x74,%eax,%eax
f0105fd8:	05 20 30 22 f0       	add    $0xf0223020,%eax
// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (!holding(lk)) {
f0105fdd:	39 c6                	cmp    %eax,%esi
f0105fdf:	0f 84 d4 00 00 00    	je     f01060b9 <spin_unlock+0xfd>
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
f0105fe5:	c7 44 24 08 28 00 00 	movl   $0x28,0x8(%esp)
f0105fec:	00 
f0105fed:	8d 43 0c             	lea    0xc(%ebx),%eax
f0105ff0:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105ff4:	8d 45 c0             	lea    -0x40(%ebp),%eax
f0105ff7:	89 04 24             	mov    %eax,(%esp)
f0105ffa:	e8 27 f6 ff ff       	call   f0105626 <memmove>
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
f0105fff:	8b 43 08             	mov    0x8(%ebx),%eax
	if (!holding(lk)) {
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
f0106002:	0f b6 30             	movzbl (%eax),%esi
f0106005:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106008:	e8 66 fc ff ff       	call   f0105c73 <cpunum>
f010600d:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0106011:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0106015:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106019:	c7 04 24 b4 7d 10 f0 	movl   $0xf0107db4,(%esp)
f0106020:	e8 57 de ff ff       	call   f0103e7c <cprintf>
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0106025:	8b 45 c0             	mov    -0x40(%ebp),%eax
f0106028:	85 c0                	test   %eax,%eax
f010602a:	74 71                	je     f010609d <spin_unlock+0xe1>
f010602c:	8d 5d c0             	lea    -0x40(%ebp),%ebx
f010602f:	8d 7d e4             	lea    -0x1c(%ebp),%edi
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
f0106032:	8d 75 a8             	lea    -0x58(%ebp),%esi
f0106035:	89 74 24 04          	mov    %esi,0x4(%esp)
f0106039:	89 04 24             	mov    %eax,(%esp)
f010603c:	e8 0b ea ff ff       	call   f0104a4c <debuginfo_eip>
f0106041:	85 c0                	test   %eax,%eax
f0106043:	78 39                	js     f010607e <spin_unlock+0xc2>
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
f0106045:	8b 03                	mov    (%ebx),%eax
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
f0106047:	89 c2                	mov    %eax,%edx
f0106049:	2b 55 b8             	sub    -0x48(%ebp),%edx
f010604c:	89 54 24 18          	mov    %edx,0x18(%esp)
f0106050:	8b 55 b0             	mov    -0x50(%ebp),%edx
f0106053:	89 54 24 14          	mov    %edx,0x14(%esp)
f0106057:	8b 55 b4             	mov    -0x4c(%ebp),%edx
f010605a:	89 54 24 10          	mov    %edx,0x10(%esp)
f010605e:	8b 55 ac             	mov    -0x54(%ebp),%edx
f0106061:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0106065:	8b 55 a8             	mov    -0x58(%ebp),%edx
f0106068:	89 54 24 08          	mov    %edx,0x8(%esp)
f010606c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106070:	c7 04 24 fc 7d 10 f0 	movl   $0xf0107dfc,(%esp)
f0106077:	e8 00 de ff ff       	call   f0103e7c <cprintf>
f010607c:	eb 12                	jmp    f0106090 <spin_unlock+0xd4>
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
f010607e:	8b 03                	mov    (%ebx),%eax
f0106080:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106084:	c7 04 24 13 7e 10 f0 	movl   $0xf0107e13,(%esp)
f010608b:	e8 ec dd ff ff       	call   f0103e7c <cprintf>
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0106090:	39 fb                	cmp    %edi,%ebx
f0106092:	74 09                	je     f010609d <spin_unlock+0xe1>
f0106094:	83 c3 04             	add    $0x4,%ebx
f0106097:	8b 03                	mov    (%ebx),%eax
f0106099:	85 c0                	test   %eax,%eax
f010609b:	75 98                	jne    f0106035 <spin_unlock+0x79>
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
		}
		panic("spin_unlock");
f010609d:	c7 44 24 08 1b 7e 10 	movl   $0xf0107e1b,0x8(%esp)
f01060a4:	f0 
f01060a5:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
f01060ac:	00 
f01060ad:	c7 04 24 ec 7d 10 f0 	movl   $0xf0107dec,(%esp)
f01060b4:	e8 87 9f ff ff       	call   f0100040 <_panic>
	}

	lk->pcs[0] = 0;
f01060b9:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
	lk->cpu = 0;
f01060c0:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f01060c7:	b8 00 00 00 00       	mov    $0x0,%eax
f01060cc:	f0 87 03             	lock xchg %eax,(%ebx)
	// Paper says that Intel 64 and IA-32 will not move a load
	// after a store. So lock->locked = 0 would work here.
	// The xchg being asm volatile ensures gcc emits it after
	// the above assignments (and after the critical section).
	xchg(&lk->locked, 0);
}
f01060cf:	83 c4 6c             	add    $0x6c,%esp
f01060d2:	5b                   	pop    %ebx
f01060d3:	5e                   	pop    %esi
f01060d4:	5f                   	pop    %edi
f01060d5:	5d                   	pop    %ebp
f01060d6:	c3                   	ret    
f01060d7:	66 90                	xchg   %ax,%ax
f01060d9:	66 90                	xchg   %ax,%ax
f01060db:	66 90                	xchg   %ax,%ax
f01060dd:	66 90                	xchg   %ax,%ax
f01060df:	90                   	nop

f01060e0 <__udivdi3>:
f01060e0:	55                   	push   %ebp
f01060e1:	57                   	push   %edi
f01060e2:	56                   	push   %esi
f01060e3:	83 ec 0c             	sub    $0xc,%esp
f01060e6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01060ea:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f01060ee:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f01060f2:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01060f6:	85 c0                	test   %eax,%eax
f01060f8:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01060fc:	89 ea                	mov    %ebp,%edx
f01060fe:	89 0c 24             	mov    %ecx,(%esp)
f0106101:	75 2d                	jne    f0106130 <__udivdi3+0x50>
f0106103:	39 e9                	cmp    %ebp,%ecx
f0106105:	77 61                	ja     f0106168 <__udivdi3+0x88>
f0106107:	85 c9                	test   %ecx,%ecx
f0106109:	89 ce                	mov    %ecx,%esi
f010610b:	75 0b                	jne    f0106118 <__udivdi3+0x38>
f010610d:	b8 01 00 00 00       	mov    $0x1,%eax
f0106112:	31 d2                	xor    %edx,%edx
f0106114:	f7 f1                	div    %ecx
f0106116:	89 c6                	mov    %eax,%esi
f0106118:	31 d2                	xor    %edx,%edx
f010611a:	89 e8                	mov    %ebp,%eax
f010611c:	f7 f6                	div    %esi
f010611e:	89 c5                	mov    %eax,%ebp
f0106120:	89 f8                	mov    %edi,%eax
f0106122:	f7 f6                	div    %esi
f0106124:	89 ea                	mov    %ebp,%edx
f0106126:	83 c4 0c             	add    $0xc,%esp
f0106129:	5e                   	pop    %esi
f010612a:	5f                   	pop    %edi
f010612b:	5d                   	pop    %ebp
f010612c:	c3                   	ret    
f010612d:	8d 76 00             	lea    0x0(%esi),%esi
f0106130:	39 e8                	cmp    %ebp,%eax
f0106132:	77 24                	ja     f0106158 <__udivdi3+0x78>
f0106134:	0f bd e8             	bsr    %eax,%ebp
f0106137:	83 f5 1f             	xor    $0x1f,%ebp
f010613a:	75 3c                	jne    f0106178 <__udivdi3+0x98>
f010613c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0106140:	39 34 24             	cmp    %esi,(%esp)
f0106143:	0f 86 9f 00 00 00    	jbe    f01061e8 <__udivdi3+0x108>
f0106149:	39 d0                	cmp    %edx,%eax
f010614b:	0f 82 97 00 00 00    	jb     f01061e8 <__udivdi3+0x108>
f0106151:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0106158:	31 d2                	xor    %edx,%edx
f010615a:	31 c0                	xor    %eax,%eax
f010615c:	83 c4 0c             	add    $0xc,%esp
f010615f:	5e                   	pop    %esi
f0106160:	5f                   	pop    %edi
f0106161:	5d                   	pop    %ebp
f0106162:	c3                   	ret    
f0106163:	90                   	nop
f0106164:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106168:	89 f8                	mov    %edi,%eax
f010616a:	f7 f1                	div    %ecx
f010616c:	31 d2                	xor    %edx,%edx
f010616e:	83 c4 0c             	add    $0xc,%esp
f0106171:	5e                   	pop    %esi
f0106172:	5f                   	pop    %edi
f0106173:	5d                   	pop    %ebp
f0106174:	c3                   	ret    
f0106175:	8d 76 00             	lea    0x0(%esi),%esi
f0106178:	89 e9                	mov    %ebp,%ecx
f010617a:	8b 3c 24             	mov    (%esp),%edi
f010617d:	d3 e0                	shl    %cl,%eax
f010617f:	89 c6                	mov    %eax,%esi
f0106181:	b8 20 00 00 00       	mov    $0x20,%eax
f0106186:	29 e8                	sub    %ebp,%eax
f0106188:	89 c1                	mov    %eax,%ecx
f010618a:	d3 ef                	shr    %cl,%edi
f010618c:	89 e9                	mov    %ebp,%ecx
f010618e:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0106192:	8b 3c 24             	mov    (%esp),%edi
f0106195:	09 74 24 08          	or     %esi,0x8(%esp)
f0106199:	89 d6                	mov    %edx,%esi
f010619b:	d3 e7                	shl    %cl,%edi
f010619d:	89 c1                	mov    %eax,%ecx
f010619f:	89 3c 24             	mov    %edi,(%esp)
f01061a2:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01061a6:	d3 ee                	shr    %cl,%esi
f01061a8:	89 e9                	mov    %ebp,%ecx
f01061aa:	d3 e2                	shl    %cl,%edx
f01061ac:	89 c1                	mov    %eax,%ecx
f01061ae:	d3 ef                	shr    %cl,%edi
f01061b0:	09 d7                	or     %edx,%edi
f01061b2:	89 f2                	mov    %esi,%edx
f01061b4:	89 f8                	mov    %edi,%eax
f01061b6:	f7 74 24 08          	divl   0x8(%esp)
f01061ba:	89 d6                	mov    %edx,%esi
f01061bc:	89 c7                	mov    %eax,%edi
f01061be:	f7 24 24             	mull   (%esp)
f01061c1:	39 d6                	cmp    %edx,%esi
f01061c3:	89 14 24             	mov    %edx,(%esp)
f01061c6:	72 30                	jb     f01061f8 <__udivdi3+0x118>
f01061c8:	8b 54 24 04          	mov    0x4(%esp),%edx
f01061cc:	89 e9                	mov    %ebp,%ecx
f01061ce:	d3 e2                	shl    %cl,%edx
f01061d0:	39 c2                	cmp    %eax,%edx
f01061d2:	73 05                	jae    f01061d9 <__udivdi3+0xf9>
f01061d4:	3b 34 24             	cmp    (%esp),%esi
f01061d7:	74 1f                	je     f01061f8 <__udivdi3+0x118>
f01061d9:	89 f8                	mov    %edi,%eax
f01061db:	31 d2                	xor    %edx,%edx
f01061dd:	e9 7a ff ff ff       	jmp    f010615c <__udivdi3+0x7c>
f01061e2:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f01061e8:	31 d2                	xor    %edx,%edx
f01061ea:	b8 01 00 00 00       	mov    $0x1,%eax
f01061ef:	e9 68 ff ff ff       	jmp    f010615c <__udivdi3+0x7c>
f01061f4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01061f8:	8d 47 ff             	lea    -0x1(%edi),%eax
f01061fb:	31 d2                	xor    %edx,%edx
f01061fd:	83 c4 0c             	add    $0xc,%esp
f0106200:	5e                   	pop    %esi
f0106201:	5f                   	pop    %edi
f0106202:	5d                   	pop    %ebp
f0106203:	c3                   	ret    
f0106204:	66 90                	xchg   %ax,%ax
f0106206:	66 90                	xchg   %ax,%ax
f0106208:	66 90                	xchg   %ax,%ax
f010620a:	66 90                	xchg   %ax,%ax
f010620c:	66 90                	xchg   %ax,%ax
f010620e:	66 90                	xchg   %ax,%ax

f0106210 <__umoddi3>:
f0106210:	55                   	push   %ebp
f0106211:	57                   	push   %edi
f0106212:	56                   	push   %esi
f0106213:	83 ec 14             	sub    $0x14,%esp
f0106216:	8b 44 24 28          	mov    0x28(%esp),%eax
f010621a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f010621e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0106222:	89 c7                	mov    %eax,%edi
f0106224:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106228:	8b 44 24 30          	mov    0x30(%esp),%eax
f010622c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0106230:	89 34 24             	mov    %esi,(%esp)
f0106233:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0106237:	85 c0                	test   %eax,%eax
f0106239:	89 c2                	mov    %eax,%edx
f010623b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f010623f:	75 17                	jne    f0106258 <__umoddi3+0x48>
f0106241:	39 fe                	cmp    %edi,%esi
f0106243:	76 4b                	jbe    f0106290 <__umoddi3+0x80>
f0106245:	89 c8                	mov    %ecx,%eax
f0106247:	89 fa                	mov    %edi,%edx
f0106249:	f7 f6                	div    %esi
f010624b:	89 d0                	mov    %edx,%eax
f010624d:	31 d2                	xor    %edx,%edx
f010624f:	83 c4 14             	add    $0x14,%esp
f0106252:	5e                   	pop    %esi
f0106253:	5f                   	pop    %edi
f0106254:	5d                   	pop    %ebp
f0106255:	c3                   	ret    
f0106256:	66 90                	xchg   %ax,%ax
f0106258:	39 f8                	cmp    %edi,%eax
f010625a:	77 54                	ja     f01062b0 <__umoddi3+0xa0>
f010625c:	0f bd e8             	bsr    %eax,%ebp
f010625f:	83 f5 1f             	xor    $0x1f,%ebp
f0106262:	75 5c                	jne    f01062c0 <__umoddi3+0xb0>
f0106264:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0106268:	39 3c 24             	cmp    %edi,(%esp)
f010626b:	0f 87 e7 00 00 00    	ja     f0106358 <__umoddi3+0x148>
f0106271:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106275:	29 f1                	sub    %esi,%ecx
f0106277:	19 c7                	sbb    %eax,%edi
f0106279:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f010627d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106281:	8b 44 24 08          	mov    0x8(%esp),%eax
f0106285:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0106289:	83 c4 14             	add    $0x14,%esp
f010628c:	5e                   	pop    %esi
f010628d:	5f                   	pop    %edi
f010628e:	5d                   	pop    %ebp
f010628f:	c3                   	ret    
f0106290:	85 f6                	test   %esi,%esi
f0106292:	89 f5                	mov    %esi,%ebp
f0106294:	75 0b                	jne    f01062a1 <__umoddi3+0x91>
f0106296:	b8 01 00 00 00       	mov    $0x1,%eax
f010629b:	31 d2                	xor    %edx,%edx
f010629d:	f7 f6                	div    %esi
f010629f:	89 c5                	mov    %eax,%ebp
f01062a1:	8b 44 24 04          	mov    0x4(%esp),%eax
f01062a5:	31 d2                	xor    %edx,%edx
f01062a7:	f7 f5                	div    %ebp
f01062a9:	89 c8                	mov    %ecx,%eax
f01062ab:	f7 f5                	div    %ebp
f01062ad:	eb 9c                	jmp    f010624b <__umoddi3+0x3b>
f01062af:	90                   	nop
f01062b0:	89 c8                	mov    %ecx,%eax
f01062b2:	89 fa                	mov    %edi,%edx
f01062b4:	83 c4 14             	add    $0x14,%esp
f01062b7:	5e                   	pop    %esi
f01062b8:	5f                   	pop    %edi
f01062b9:	5d                   	pop    %ebp
f01062ba:	c3                   	ret    
f01062bb:	90                   	nop
f01062bc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01062c0:	8b 04 24             	mov    (%esp),%eax
f01062c3:	be 20 00 00 00       	mov    $0x20,%esi
f01062c8:	89 e9                	mov    %ebp,%ecx
f01062ca:	29 ee                	sub    %ebp,%esi
f01062cc:	d3 e2                	shl    %cl,%edx
f01062ce:	89 f1                	mov    %esi,%ecx
f01062d0:	d3 e8                	shr    %cl,%eax
f01062d2:	89 e9                	mov    %ebp,%ecx
f01062d4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01062d8:	8b 04 24             	mov    (%esp),%eax
f01062db:	09 54 24 04          	or     %edx,0x4(%esp)
f01062df:	89 fa                	mov    %edi,%edx
f01062e1:	d3 e0                	shl    %cl,%eax
f01062e3:	89 f1                	mov    %esi,%ecx
f01062e5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01062e9:	8b 44 24 10          	mov    0x10(%esp),%eax
f01062ed:	d3 ea                	shr    %cl,%edx
f01062ef:	89 e9                	mov    %ebp,%ecx
f01062f1:	d3 e7                	shl    %cl,%edi
f01062f3:	89 f1                	mov    %esi,%ecx
f01062f5:	d3 e8                	shr    %cl,%eax
f01062f7:	89 e9                	mov    %ebp,%ecx
f01062f9:	09 f8                	or     %edi,%eax
f01062fb:	8b 7c 24 10          	mov    0x10(%esp),%edi
f01062ff:	f7 74 24 04          	divl   0x4(%esp)
f0106303:	d3 e7                	shl    %cl,%edi
f0106305:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106309:	89 d7                	mov    %edx,%edi
f010630b:	f7 64 24 08          	mull   0x8(%esp)
f010630f:	39 d7                	cmp    %edx,%edi
f0106311:	89 c1                	mov    %eax,%ecx
f0106313:	89 14 24             	mov    %edx,(%esp)
f0106316:	72 2c                	jb     f0106344 <__umoddi3+0x134>
f0106318:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f010631c:	72 22                	jb     f0106340 <__umoddi3+0x130>
f010631e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0106322:	29 c8                	sub    %ecx,%eax
f0106324:	19 d7                	sbb    %edx,%edi
f0106326:	89 e9                	mov    %ebp,%ecx
f0106328:	89 fa                	mov    %edi,%edx
f010632a:	d3 e8                	shr    %cl,%eax
f010632c:	89 f1                	mov    %esi,%ecx
f010632e:	d3 e2                	shl    %cl,%edx
f0106330:	89 e9                	mov    %ebp,%ecx
f0106332:	d3 ef                	shr    %cl,%edi
f0106334:	09 d0                	or     %edx,%eax
f0106336:	89 fa                	mov    %edi,%edx
f0106338:	83 c4 14             	add    $0x14,%esp
f010633b:	5e                   	pop    %esi
f010633c:	5f                   	pop    %edi
f010633d:	5d                   	pop    %ebp
f010633e:	c3                   	ret    
f010633f:	90                   	nop
f0106340:	39 d7                	cmp    %edx,%edi
f0106342:	75 da                	jne    f010631e <__umoddi3+0x10e>
f0106344:	8b 14 24             	mov    (%esp),%edx
f0106347:	89 c1                	mov    %eax,%ecx
f0106349:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f010634d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0106351:	eb cb                	jmp    f010631e <__umoddi3+0x10e>
f0106353:	90                   	nop
f0106354:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106358:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f010635c:	0f 82 0f ff ff ff    	jb     f0106271 <__umoddi3+0x61>
f0106362:	e9 1a ff ff ff       	jmp    f0106281 <__umoddi3+0x71>
