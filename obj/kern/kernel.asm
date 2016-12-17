
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
f010005f:	e8 ff 3c 00 00       	call   f0103d63 <cpunum>
f0100064:	8b 55 0c             	mov    0xc(%ebp),%edx
f0100067:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010006b:	8b 55 08             	mov    0x8(%ebp),%edx
f010006e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100072:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100076:	c7 04 24 60 44 10 f0 	movl   $0xf0104460,(%esp)
f010007d:	e8 f2 1e 00 00       	call   f0101f74 <cprintf>
	vcprintf(fmt, ap);
f0100082:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100086:	89 34 24             	mov    %esi,(%esp)
f0100089:	e8 b3 1e 00 00       	call   f0101f41 <vcprintf>
	cprintf("\n");
f010008e:	c7 04 24 e1 4c 10 f0 	movl   $0xf0104ce1,(%esp)
f0100095:	e8 da 1e 00 00       	call   f0101f74 <cprintf>
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
f01000cc:	e8 f8 35 00 00       	call   f01036c9 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000d1:	e8 d9 05 00 00       	call   f01006af <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000d6:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000dd:	00 
f01000de:	c7 04 24 cc 44 10 f0 	movl   $0xf01044cc,(%esp)
f01000e5:	e8 8a 1e 00 00       	call   f0101f74 <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f01000ea:	e8 e8 0b 00 00       	call   f0100cd7 <mem_init>

	// Lab 3 user environment initialization functions
	env_init();
f01000ef:	e8 b9 15 00 00       	call   f01016ad <env_init>
	trap_init();
f01000f4:	e8 f4 1e 00 00       	call   f0101fed <trap_init>

	// Lab 4 multiprocessor initialization functions
	mp_init();
f01000f9:	e8 4b 39 00 00       	call   f0103a49 <mp_init>
	lapic_init();
f01000fe:	66 90                	xchg   %ax,%ax
f0100100:	e8 79 3c 00 00       	call   f0103d7e <lapic_init>

	// Lab 4 multitasking initialization functions
	pic_init();
f0100105:	e8 97 1d 00 00       	call   f0101ea1 <pic_init>
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
f010011b:	c7 44 24 08 84 44 10 	movl   $0xf0104484,0x8(%esp)
f0100122:	f0 
f0100123:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f010012a:	00 
f010012b:	c7 04 24 e7 44 10 f0 	movl   $0xf01044e7,(%esp)
f0100132:	e8 09 ff ff ff       	call   f0100040 <_panic>
	void *code;
	struct Cpu *c;

	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);
f0100137:	b8 76 39 10 f0       	mov    $0xf0103976,%eax
f010013c:	2d fc 38 10 f0       	sub    $0xf01038fc,%eax
f0100141:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100145:	c7 44 24 04 fc 38 10 	movl   $0xf01038fc,0x4(%esp)
f010014c:	f0 
f010014d:	c7 04 24 00 70 00 f0 	movl   $0xf0007000,(%esp)
f0100154:	e8 bd 35 00 00       	call   f0103716 <memmove>

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100159:	6b 05 c4 03 22 f0 74 	imul   $0x74,0xf02203c4,%eax
f0100160:	05 20 00 22 f0       	add    $0xf0220020,%eax
f0100165:	3d 20 00 22 f0       	cmp    $0xf0220020,%eax
f010016a:	0f 86 a6 00 00 00    	jbe    f0100216 <i386_init+0x16e>
f0100170:	bb 20 00 22 f0       	mov    $0xf0220020,%ebx
		if (c == cpus + cpunum())  // We've started already.
f0100175:	e8 e9 3b 00 00       	call   f0103d63 <cpunum>
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
f01001b2:	e8 ff 3c 00 00       	call   f0103eb6 <lapic_startap>
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
f01001eb:	e8 b6 16 00 00       	call   f01018a6 <env_create>
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
f010020c:	e8 95 16 00 00       	call   f01018a6 <env_create>
#endif // TEST*

	// Schedule and run the first user environment!
	sched_yield();
f0100211:	e8 1b 26 00 00       	call   f0102831 <sched_yield>
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
f0100233:	c7 44 24 08 a8 44 10 	movl   $0xf01044a8,0x8(%esp)
f010023a:	f0 
f010023b:	c7 44 24 04 6e 00 00 	movl   $0x6e,0x4(%esp)
f0100242:	00 
f0100243:	c7 04 24 e7 44 10 f0 	movl   $0xf01044e7,(%esp)
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
f0100257:	e8 07 3b 00 00       	call   f0103d63 <cpunum>
f010025c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100260:	c7 04 24 f3 44 10 f0 	movl   $0xf01044f3,(%esp)
f0100267:	e8 08 1d 00 00       	call   f0101f74 <cprintf>

	lapic_init();
f010026c:	e8 0d 3b 00 00       	call   f0103d7e <lapic_init>
	env_init_percpu();
f0100271:	e8 0d 14 00 00       	call   f0101683 <env_init_percpu>
	trap_init_percpu();
f0100276:	e8 15 1d 00 00       	call   f0101f90 <trap_init_percpu>
	xchg(&thiscpu->cpu_status, CPU_STARTED); // tell boot_aps() we're up
f010027b:	90                   	nop
f010027c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100280:	e8 de 3a 00 00       	call   f0103d63 <cpunum>
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
f01002b1:	c7 04 24 09 45 10 f0 	movl   $0xf0104509,(%esp)
f01002b8:	e8 b7 1c 00 00       	call   f0101f74 <cprintf>
	vcprintf(fmt, ap);
f01002bd:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01002c1:	8b 45 10             	mov    0x10(%ebp),%eax
f01002c4:	89 04 24             	mov    %eax,(%esp)
f01002c7:	e8 75 1c 00 00       	call   f0101f41 <vcprintf>
	cprintf("\n");
f01002cc:	c7 04 24 e1 4c 10 f0 	movl   $0xf0104ce1,(%esp)
f01002d3:	e8 9c 1c 00 00       	call   f0101f74 <cprintf>
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
f0100385:	0f b6 82 80 46 10 f0 	movzbl -0xfefb980(%edx),%eax
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
f01003c2:	0f b6 82 80 46 10 f0 	movzbl -0xfefb980(%edx),%eax
f01003c9:	0b 05 00 f0 21 f0    	or     0xf021f000,%eax
	shift ^= togglecode[data];
f01003cf:	0f b6 8a 80 45 10 f0 	movzbl -0xfefba80(%edx),%ecx
f01003d6:	31 c8                	xor    %ecx,%eax
f01003d8:	a3 00 f0 21 f0       	mov    %eax,0xf021f000

	c = charcode[shift & (CTL | SHIFT)][data];
f01003dd:	89 c1                	mov    %eax,%ecx
f01003df:	83 e1 03             	and    $0x3,%ecx
f01003e2:	8b 0c 8d 60 45 10 f0 	mov    -0xfefbaa0(,%ecx,4),%ecx
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
f0100422:	c7 04 24 23 45 10 f0 	movl   $0xf0104523,(%esp)
f0100429:	e8 46 1b 00 00       	call   f0101f74 <cprintf>
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
f01005d9:	e8 38 31 00 00       	call   f0103716 <memmove>
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
f0100747:	e8 e6 16 00 00       	call   f0101e32 <irq_setmask_8259A>
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
f01007a9:	c7 04 24 2f 45 10 f0 	movl   $0xf010452f,(%esp)
f01007b0:	e8 bf 17 00 00       	call   f0101f74 <cprintf>
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
f01007f6:	c7 44 24 08 80 47 10 	movl   $0xf0104780,0x8(%esp)
f01007fd:	f0 
f01007fe:	c7 44 24 04 9e 47 10 	movl   $0xf010479e,0x4(%esp)
f0100805:	f0 
f0100806:	c7 04 24 a3 47 10 f0 	movl   $0xf01047a3,(%esp)
f010080d:	e8 62 17 00 00       	call   f0101f74 <cprintf>
f0100812:	c7 44 24 08 40 48 10 	movl   $0xf0104840,0x8(%esp)
f0100819:	f0 
f010081a:	c7 44 24 04 ac 47 10 	movl   $0xf01047ac,0x4(%esp)
f0100821:	f0 
f0100822:	c7 04 24 a3 47 10 f0 	movl   $0xf01047a3,(%esp)
f0100829:	e8 46 17 00 00       	call   f0101f74 <cprintf>
f010082e:	c7 44 24 08 68 48 10 	movl   $0xf0104868,0x8(%esp)
f0100835:	f0 
f0100836:	c7 44 24 04 b5 47 10 	movl   $0xf01047b5,0x4(%esp)
f010083d:	f0 
f010083e:	c7 04 24 a3 47 10 f0 	movl   $0xf01047a3,(%esp)
f0100845:	e8 2a 17 00 00       	call   f0101f74 <cprintf>
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
f0100857:	c7 04 24 bf 47 10 f0 	movl   $0xf01047bf,(%esp)
f010085e:	e8 11 17 00 00       	call   f0101f74 <cprintf>
	cprintf(" this is work 1 insert:\n");
f0100863:	c7 04 24 d8 47 10 f0 	movl   $0xf01047d8,(%esp)
f010086a:	e8 05 17 00 00       	call   f0101f74 <cprintf>
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
f010086f:	c7 44 24 08 0f 00 00 	movl   $0xf,0x8(%esp)
f0100876:	00 
f0100877:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
f010087e:	00 
f010087f:	c7 04 24 94 48 10 f0 	movl   $0xf0104894,(%esp)
f0100886:	e8 e9 16 00 00       	call   f0101f74 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
f010088b:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f0100892:	00 
f0100893:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f010089a:	f0 
f010089b:	c7 04 24 cc 48 10 f0 	movl   $0xf01048cc,(%esp)
f01008a2:	e8 cd 16 00 00       	call   f0101f74 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01008a7:	c7 44 24 08 57 44 10 	movl   $0x104457,0x8(%esp)
f01008ae:	00 
f01008af:	c7 44 24 04 57 44 10 	movl   $0xf0104457,0x4(%esp)
f01008b6:	f0 
f01008b7:	c7 04 24 f4 48 10 f0 	movl   $0xf01048f4,(%esp)
f01008be:	e8 b1 16 00 00       	call   f0101f74 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01008c3:	c7 44 24 08 58 e4 21 	movl   $0x21e458,0x8(%esp)
f01008ca:	00 
f01008cb:	c7 44 24 04 58 e4 21 	movl   $0xf021e458,0x4(%esp)
f01008d2:	f0 
f01008d3:	c7 04 24 18 49 10 f0 	movl   $0xf0104918,(%esp)
f01008da:	e8 95 16 00 00       	call   f0101f74 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f01008df:	c7 44 24 08 04 10 26 	movl   $0x261004,0x8(%esp)
f01008e6:	00 
f01008e7:	c7 44 24 04 04 10 26 	movl   $0xf0261004,0x4(%esp)
f01008ee:	f0 
f01008ef:	c7 04 24 3c 49 10 f0 	movl   $0xf010493c,(%esp)
f01008f6:	e8 79 16 00 00       	call   f0101f74 <cprintf>
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
f0100917:	c7 04 24 60 49 10 f0 	movl   $0xf0104960,(%esp)
f010091e:	e8 51 16 00 00       	call   f0101f74 <cprintf>
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
f0100932:	c7 04 24 f1 47 10 f0 	movl   $0xf01047f1,(%esp)
f0100939:	e8 36 16 00 00       	call   f0101f74 <cprintf>
	cprintf("\n");
f010093e:	c7 04 24 e1 4c 10 f0 	movl   $0xf0104ce1,(%esp)
f0100945:	e8 2a 16 00 00       	call   f0101f74 <cprintf>

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
f01009a1:	c7 04 24 8c 49 10 f0 	movl   $0xf010498c,(%esp)
f01009a8:	e8 c7 15 00 00       	call   f0101f74 <cprintf>
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
f01009cb:	c7 04 24 c8 49 10 f0 	movl   $0xf01049c8,(%esp)
f01009d2:	e8 9d 15 00 00       	call   f0101f74 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f01009d7:	c7 04 24 ec 49 10 f0 	movl   $0xf01049ec,(%esp)
f01009de:	e8 91 15 00 00       	call   f0101f74 <cprintf>

	if (tf != NULL)
f01009e3:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f01009e7:	74 0b                	je     f01009f4 <monitor+0x32>
		print_trapframe(tf);
f01009e9:	8b 45 08             	mov    0x8(%ebp),%eax
f01009ec:	89 04 24             	mov    %eax,(%esp)
f01009ef:	e8 b0 19 00 00       	call   f01023a4 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f01009f4:	c7 04 24 02 48 10 f0 	movl   $0xf0104802,(%esp)
f01009fb:	e8 f0 29 00 00       	call   f01033f0 <readline>
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
f0100a2c:	c7 04 24 06 48 10 f0 	movl   $0xf0104806,(%esp)
f0100a33:	e8 31 2c 00 00       	call   f0103669 <strchr>
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
f0100a4e:	c7 04 24 0b 48 10 f0 	movl   $0xf010480b,(%esp)
f0100a55:	e8 1a 15 00 00       	call   f0101f74 <cprintf>
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
f0100a7d:	c7 04 24 06 48 10 f0 	movl   $0xf0104806,(%esp)
f0100a84:	e8 e0 2b 00 00       	call   f0103669 <strchr>
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
f0100aa7:	8b 04 85 20 4a 10 f0 	mov    -0xfefb5e0(,%eax,4),%eax
f0100aae:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100ab2:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100ab5:	89 04 24             	mov    %eax,(%esp)
f0100ab8:	e8 28 2b 00 00       	call   f01035e5 <strcmp>
f0100abd:	85 c0                	test   %eax,%eax
f0100abf:	75 24                	jne    f0100ae5 <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100ac1:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100ac4:	8b 55 08             	mov    0x8(%ebp),%edx
f0100ac7:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100acb:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100ace:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100ad2:	89 34 24             	mov    %esi,(%esp)
f0100ad5:	ff 14 85 28 4a 10 f0 	call   *-0xfefb5d8(,%eax,4)
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
f0100af4:	c7 04 24 28 48 10 f0 	movl   $0xf0104828,(%esp)
f0100afb:	e8 74 14 00 00       	call   f0101f74 <cprintf>
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
f0100b70:	c7 04 24 44 4a 10 f0 	movl   $0xf0104a44,(%esp)
f0100b77:	e8 f8 13 00 00       	call   f0101f74 <cprintf>
              return result;
   
	//return NULL;
}
f0100b7c:	89 d8                	mov    %ebx,%eax
f0100b7e:	83 c4 14             	add    $0x14,%esp
f0100b81:	5b                   	pop    %ebx
f0100b82:	5d                   	pop    %ebp
f0100b83:	c3                   	ret    

f0100b84 <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0100b84:	55                   	push   %ebp
f0100b85:	89 e5                	mov    %esp,%ebp
f0100b87:	56                   	push   %esi
f0100b88:	53                   	push   %ebx
f0100b89:	83 ec 10             	sub    $0x10,%esp
	size_t i = 1;
	for (i; i < npages_basemem; i++) {
f0100b8c:	8b 35 44 f2 21 f0    	mov    0xf021f244,%esi
f0100b92:	83 fe 01             	cmp    $0x1,%esi
f0100b95:	76 39                	jbe    f0100bd0 <page_init+0x4c>
f0100b97:	8b 1d 40 f2 21 f0    	mov    0xf021f240,%ebx
// memory via the page_free_list.
//
void
page_init(void)
{
	size_t i = 1;
f0100b9d:	b8 01 00 00 00       	mov    $0x1,%eax
f0100ba2:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
	for (i; i < npages_basemem; i++) {
		pages[i].pp_ref = 0;
f0100ba9:	89 d1                	mov    %edx,%ecx
f0100bab:	03 0d 10 ff 21 f0    	add    0xf021ff10,%ecx
f0100bb1:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0100bb7:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f0100bb9:	03 15 10 ff 21 f0    	add    0xf021ff10,%edx
//
void
page_init(void)
{
	size_t i = 1;
	for (i; i < npages_basemem; i++) {
f0100bbf:	83 c0 01             	add    $0x1,%eax
f0100bc2:	39 f0                	cmp    %esi,%eax
f0100bc4:	73 04                	jae    f0100bca <page_init+0x46>
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f0100bc6:	89 d3                	mov    %edx,%ebx
f0100bc8:	eb d8                	jmp    f0100ba2 <page_init+0x1e>
f0100bca:	89 15 40 f2 21 f0    	mov    %edx,0xf021f240
	}

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
f0100bd0:	8b 0d 08 ff 21 f0    	mov    0xf021ff08,%ecx
f0100bd6:	a1 10 ff 21 f0       	mov    0xf021ff10,%eax
f0100bdb:	8d 84 c8 ff ff 01 10 	lea    0x1001ffff(%eax,%ecx,8),%eax
f0100be2:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100be7:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0100bed:	85 c0                	test   %eax,%eax
f0100bef:	0f 48 c2             	cmovs  %edx,%eax
f0100bf2:	c1 f8 0c             	sar    $0xc,%eax
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f0100bf5:	89 c2                	mov    %eax,%edx
f0100bf7:	39 c1                	cmp    %eax,%ecx
f0100bf9:	76 37                	jbe    f0100c32 <page_init+0xae>
f0100bfb:	8b 1d 40 f2 21 f0    	mov    0xf021f240,%ebx
f0100c01:	c1 e0 03             	shl    $0x3,%eax
		pages[i].pp_ref = 0;
f0100c04:	89 c1                	mov    %eax,%ecx
f0100c06:	03 0d 10 ff 21 f0    	add    0xf021ff10,%ecx
f0100c0c:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0100c12:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f0100c14:	89 c3                	mov    %eax,%ebx
f0100c16:	03 1d 10 ff 21 f0    	add    0xf021ff10,%ebx

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f0100c1c:	83 c2 01             	add    $0x1,%edx
f0100c1f:	8b 0d 08 ff 21 f0    	mov    0xf021ff08,%ecx
f0100c25:	83 c0 08             	add    $0x8,%eax
f0100c28:	39 d1                	cmp    %edx,%ecx
f0100c2a:	77 d8                	ja     f0100c04 <page_init+0x80>
f0100c2c:	89 1d 40 f2 21 f0    	mov    %ebx,0xf021f240
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100c32:	83 f9 07             	cmp    $0x7,%ecx
f0100c35:	77 1c                	ja     f0100c53 <page_init+0xcf>
		panic("pa2page called with invalid pa");
f0100c37:	c7 44 24 08 90 4a 10 	movl   $0xf0104a90,0x8(%esp)
f0100c3e:	f0 
f0100c3f:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0100c46:	00 
f0100c47:	c7 04 24 29 4c 10 f0 	movl   $0xf0104c29,(%esp)
f0100c4e:	e8 ed f3 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0100c53:	8b 15 10 ff 21 f0    	mov    0xf021ff10,%edx
               ppg_end->pp_link = ppg_start;*/

               //remain the page of mp entry Code
               extern unsigned char mpentry_start[], mpentry_end[];
               struct Page *ppg_start = pa2page((physaddr_t)MPENTRY_PADDR);      
               struct Page * ppg_end = pa2page((physaddr_t)(MPENTRY_PADDR+mpentry_end - mpentry_start));  
f0100c59:	b8 76 a9 10 f0       	mov    $0xf010a976,%eax
f0100c5e:	2d fc 38 10 f0       	sub    $0xf01038fc,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100c63:	c1 e8 0c             	shr    $0xc,%eax
f0100c66:	39 c8                	cmp    %ecx,%eax
f0100c68:	72 1c                	jb     f0100c86 <page_init+0x102>
		panic("pa2page called with invalid pa");
f0100c6a:	c7 44 24 08 90 4a 10 	movl   $0xf0104a90,0x8(%esp)
f0100c71:	f0 
f0100c72:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0100c79:	00 
f0100c7a:	c7 04 24 29 4c 10 f0 	movl   $0xf0104c29,(%esp)
f0100c81:	e8 ba f3 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0100c86:	8d 1c c2             	lea    (%edx,%eax,8),%ebx
               ppg_start--;    ppg_end++;
f0100c89:	83 c2 30             	add    $0x30,%edx
               ppg_end->pp_link = ppg_start;
f0100c8c:	89 53 08             	mov    %edx,0x8(%ebx)

               cprintf("MPENTRY_PADDR_page_start:  %d\n",PGNUM(page2pa(ppg_start)));
f0100c8f:	c7 44 24 04 06 00 00 	movl   $0x6,0x4(%esp)
f0100c96:	00 
f0100c97:	c7 04 24 b0 4a 10 f0 	movl   $0xf0104ab0,(%esp)
f0100c9e:	e8 d1 12 00 00       	call   f0101f74 <cprintf>

               //remain the page of mp entry Code
               extern unsigned char mpentry_start[], mpentry_end[];
               struct Page *ppg_start = pa2page((physaddr_t)MPENTRY_PADDR);      
               struct Page * ppg_end = pa2page((physaddr_t)(MPENTRY_PADDR+mpentry_end - mpentry_start));  
               ppg_start--;    ppg_end++;
f0100ca3:	8d 43 08             	lea    0x8(%ebx),%eax
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100ca6:	2b 05 10 ff 21 f0    	sub    0xf021ff10,%eax
f0100cac:	c1 f8 03             	sar    $0x3,%eax
               ppg_end->pp_link = ppg_start;

               cprintf("MPENTRY_PADDR_page_start:  %d\n",PGNUM(page2pa(ppg_start)));
               cprintf("MPENTRY_PADDR_page_end:  %d\n",PGNUM(page2pa(ppg_end)));
f0100caf:	25 ff ff 0f 00       	and    $0xfffff,%eax
f0100cb4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100cb8:	c7 04 24 37 4c 10 f0 	movl   $0xf0104c37,(%esp)
f0100cbf:	e8 b0 12 00 00       	call   f0101f74 <cprintf>
               cprintf("\n");
f0100cc4:	c7 04 24 e1 4c 10 f0 	movl   $0xf0104ce1,(%esp)
f0100ccb:	e8 a4 12 00 00       	call   f0101f74 <cprintf>
}
f0100cd0:	83 c4 10             	add    $0x10,%esp
f0100cd3:	5b                   	pop    %ebx
f0100cd4:	5e                   	pop    %esi
f0100cd5:	5d                   	pop    %ebp
f0100cd6:	c3                   	ret    

f0100cd7 <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f0100cd7:	55                   	push   %ebp
f0100cd8:	89 e5                	mov    %esp,%ebp
f0100cda:	57                   	push   %edi
f0100cdb:	56                   	push   %esi
f0100cdc:	53                   	push   %ebx
f0100cdd:	83 ec 2c             	sub    $0x2c,%esp
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0100ce0:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f0100ce7:	e8 1c 11 00 00       	call   f0101e08 <mc146818_read>
f0100cec:	89 c3                	mov    %eax,%ebx
f0100cee:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f0100cf5:	e8 0e 11 00 00       	call   f0101e08 <mc146818_read>
f0100cfa:	c1 e0 08             	shl    $0x8,%eax
f0100cfd:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f0100cff:	89 d8                	mov    %ebx,%eax
f0100d01:	c1 e0 0a             	shl    $0xa,%eax
f0100d04:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0100d0a:	85 c0                	test   %eax,%eax
f0100d0c:	0f 48 c2             	cmovs  %edx,%eax
f0100d0f:	c1 f8 0c             	sar    $0xc,%eax
f0100d12:	a3 44 f2 21 f0       	mov    %eax,0xf021f244
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0100d17:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f0100d1e:	e8 e5 10 00 00       	call   f0101e08 <mc146818_read>
f0100d23:	89 c3                	mov    %eax,%ebx
f0100d25:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f0100d2c:	e8 d7 10 00 00       	call   f0101e08 <mc146818_read>
f0100d31:	c1 e0 08             	shl    $0x8,%eax
f0100d34:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f0100d36:	89 d8                	mov    %ebx,%eax
f0100d38:	c1 e0 0a             	shl    $0xa,%eax
f0100d3b:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0100d41:	85 c0                	test   %eax,%eax
f0100d43:	0f 48 c2             	cmovs  %edx,%eax
f0100d46:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f0100d49:	85 c0                	test   %eax,%eax
f0100d4b:	74 0e                	je     f0100d5b <mem_init+0x84>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f0100d4d:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f0100d53:	89 15 08 ff 21 f0    	mov    %edx,0xf021ff08
f0100d59:	eb 0c                	jmp    f0100d67 <mem_init+0x90>
	else
		npages = npages_basemem;
f0100d5b:	8b 15 44 f2 21 f0    	mov    0xf021f244,%edx
f0100d61:	89 15 08 ff 21 f0    	mov    %edx,0xf021ff08

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f0100d67:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0100d6a:	c1 e8 0a             	shr    $0xa,%eax
f0100d6d:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f0100d71:	a1 44 f2 21 f0       	mov    0xf021f244,%eax
f0100d76:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0100d79:	c1 e8 0a             	shr    $0xa,%eax
f0100d7c:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f0100d80:	a1 08 ff 21 f0       	mov    0xf021ff08,%eax
f0100d85:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0100d88:	c1 e8 0a             	shr    $0xa,%eax
f0100d8b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100d8f:	c7 04 24 d0 4a 10 f0 	movl   $0xf0104ad0,(%esp)
f0100d96:	e8 d9 11 00 00       	call   f0101f74 <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);  // first_level pagedir
f0100d9b:	b8 00 10 00 00       	mov    $0x1000,%eax
f0100da0:	e8 7b fd ff ff       	call   f0100b20 <boot_alloc>
f0100da5:	a3 0c ff 21 f0       	mov    %eax,0xf021ff0c
	memset(kern_pgdir, 0, PGSIZE);
f0100daa:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0100db1:	00 
f0100db2:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0100db9:	00 
f0100dba:	89 04 24             	mov    %eax,(%esp)
f0100dbd:	e8 07 29 00 00       	call   f01036c9 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f0100dc2:	a1 0c ff 21 f0       	mov    0xf021ff0c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100dc7:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0100dcc:	77 20                	ja     f0100dee <mem_init+0x117>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0100dce:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100dd2:	c7 44 24 08 a8 44 10 	movl   $0xf01044a8,0x8(%esp)
f0100dd9:	f0 
f0100dda:	c7 44 24 04 96 00 00 	movl   $0x96,0x4(%esp)
f0100de1:	00 
f0100de2:	c7 04 24 54 4c 10 f0 	movl   $0xf0104c54,(%esp)
f0100de9:	e8 52 f2 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0100dee:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f0100df4:	83 ca 05             	or     $0x5,%edx
f0100df7:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct Page in this
	// array.  'npages' is the number of physical pages in memory.
	// Your code goes here:

	pages = (struct Page *)boot_alloc(npages * sizeof(struct Page)); // allocate npages to record all physical pages in memort using condition
f0100dfd:	a1 08 ff 21 f0       	mov    0xf021ff08,%eax
f0100e02:	c1 e0 03             	shl    $0x3,%eax
f0100e05:	e8 16 fd ff ff       	call   f0100b20 <boot_alloc>
f0100e0a:	a3 10 ff 21 f0       	mov    %eax,0xf021ff10


	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.
	envs =  (struct Env *)boot_alloc(NENV * sizeof(struct Env));
f0100e0f:	b8 00 f0 01 00       	mov    $0x1f000,%eax
f0100e14:	e8 07 fd ff ff       	call   f0100b20 <boot_alloc>
f0100e19:	a3 48 f2 21 f0       	mov    %eax,0xf021f248
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f0100e1e:	e8 61 fd ff ff       	call   f0100b84 <page_init>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100e23:	a1 40 f2 21 f0       	mov    0xf021f240,%eax
f0100e28:	85 c0                	test   %eax,%eax
f0100e2a:	75 1c                	jne    f0100e48 <mem_init+0x171>
		panic("'page_free_list' is a null pointer!");
f0100e2c:	c7 44 24 08 0c 4b 10 	movl   $0xf0104b0c,0x8(%esp)
f0100e33:	f0 
f0100e34:	c7 44 24 04 be 02 00 	movl   $0x2be,0x4(%esp)
f0100e3b:	00 
f0100e3c:	c7 04 24 54 4c 10 f0 	movl   $0xf0104c54,(%esp)
f0100e43:	e8 f8 f1 ff ff       	call   f0100040 <_panic>

	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
f0100e48:	8d 55 d8             	lea    -0x28(%ebp),%edx
f0100e4b:	89 55 e0             	mov    %edx,-0x20(%ebp)
f0100e4e:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100e51:	89 55 e4             	mov    %edx,-0x1c(%ebp)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100e54:	89 c2                	mov    %eax,%edx
f0100e56:	2b 15 10 ff 21 f0    	sub    0xf021ff10,%edx
		for (pp = page_free_list; pp; pp = pp->pp_link) {
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
f0100e5c:	f7 c2 00 e0 7f 00    	test   $0x7fe000,%edx
f0100e62:	0f 95 c2             	setne  %dl
f0100e65:	0f b6 d2             	movzbl %dl,%edx
			*tp[pagetype] = pp;
f0100e68:	8b 4c 95 e0          	mov    -0x20(%ebp,%edx,4),%ecx
f0100e6c:	89 01                	mov    %eax,(%ecx)
			tp[pagetype] = &pp->pp_link;
f0100e6e:	89 44 95 e0          	mov    %eax,-0x20(%ebp,%edx,4)
	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
		for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100e72:	8b 00                	mov    (%eax),%eax
f0100e74:	85 c0                	test   %eax,%eax
f0100e76:	75 dc                	jne    f0100e54 <mem_init+0x17d>
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
			*tp[pagetype] = pp;
			tp[pagetype] = &pp->pp_link;
		}
		*tp[1] = 0;
f0100e78:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100e7b:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		*tp[0] = pp2;
f0100e81:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100e84:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100e87:	89 10                	mov    %edx,(%eax)
		page_free_list = pp1;
f0100e89:	8b 5d d8             	mov    -0x28(%ebp),%ebx
f0100e8c:	89 1d 40 f2 21 f0    	mov    %ebx,0xf021f240
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100e92:	85 db                	test   %ebx,%ebx
f0100e94:	74 68                	je     f0100efe <mem_init+0x227>
f0100e96:	89 d8                	mov    %ebx,%eax
f0100e98:	2b 05 10 ff 21 f0    	sub    0xf021ff10,%eax
f0100e9e:	c1 f8 03             	sar    $0x3,%eax
		if (PDX(page2pa(pp)) < pdx_limit)
f0100ea1:	89 c2                	mov    %eax,%edx
f0100ea3:	c1 e2 0c             	shl    $0xc,%edx
f0100ea6:	a9 00 fc 0f 00       	test   $0xffc00,%eax
f0100eab:	75 4b                	jne    f0100ef8 <mem_init+0x221>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100ead:	89 d0                	mov    %edx,%eax
f0100eaf:	c1 e8 0c             	shr    $0xc,%eax
f0100eb2:	3b 05 08 ff 21 f0    	cmp    0xf021ff08,%eax
f0100eb8:	72 20                	jb     f0100eda <mem_init+0x203>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100eba:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100ebe:	c7 44 24 08 84 44 10 	movl   $0xf0104484,0x8(%esp)
f0100ec5:	f0 
f0100ec6:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100ecd:	00 
f0100ece:	c7 04 24 29 4c 10 f0 	movl   $0xf0104c29,(%esp)
f0100ed5:	e8 66 f1 ff ff       	call   f0100040 <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100eda:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100ee1:	00 
f0100ee2:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100ee9:	00 
	return (void *)(pa + KERNBASE);
f0100eea:	81 ea 00 00 00 10    	sub    $0x10000000,%edx
f0100ef0:	89 14 24             	mov    %edx,(%esp)
f0100ef3:	e8 d1 27 00 00       	call   f01036c9 <memset>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100ef8:	8b 1b                	mov    (%ebx),%ebx
f0100efa:	85 db                	test   %ebx,%ebx
f0100efc:	75 98                	jne    f0100e96 <mem_init+0x1bf>
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
f0100efe:	b8 00 00 00 00       	mov    $0x0,%eax
f0100f03:	e8 18 fc ff ff       	call   f0100b20 <boot_alloc>
f0100f08:	89 c7                	mov    %eax,%edi
	cprintf("EXTPHYSMEM belonging to page %d \n",PGNUM(EXTPHYSMEM));
f0100f0a:	c7 44 24 04 00 01 00 	movl   $0x100,0x4(%esp)
f0100f11:	00 
f0100f12:	c7 04 24 30 4b 10 f0 	movl   $0xf0104b30,(%esp)
f0100f19:	e8 56 10 00 00       	call   f0101f74 <cprintf>
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100f1e:	8b 1d 40 f2 21 f0    	mov    0xf021f240,%ebx
f0100f24:	85 db                	test   %ebx,%ebx
f0100f26:	0f 84 35 02 00 00    	je     f0101161 <mem_init+0x48a>
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100f2c:	a1 10 ff 21 f0       	mov    0xf021ff10,%eax
f0100f31:	39 c3                	cmp    %eax,%ebx
f0100f33:	72 3f                	jb     f0100f74 <mem_init+0x29d>
		assert(pp < pages + npages);
f0100f35:	8b 15 08 ff 21 f0    	mov    0xf021ff08,%edx
f0100f3b:	8d 14 d0             	lea    (%eax,%edx,8),%edx
f0100f3e:	39 d3                	cmp    %edx,%ebx
f0100f40:	73 63                	jae    f0100fa5 <mem_init+0x2ce>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100f42:	89 de                	mov    %ebx,%esi
f0100f44:	89 d9                	mov    %ebx,%ecx
f0100f46:	29 c1                	sub    %eax,%ecx
f0100f48:	89 c8                	mov    %ecx,%eax
f0100f4a:	a8 07                	test   $0x7,%al
f0100f4c:	0f 85 83 00 00 00    	jne    f0100fd5 <mem_init+0x2fe>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100f52:	c1 f8 03             	sar    $0x3,%eax
f0100f55:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100f58:	85 c0                	test   %eax,%eax
f0100f5a:	0f 84 a3 00 00 00    	je     f0101003 <mem_init+0x32c>
		assert(page2pa(pp) != IOPHYSMEM);
f0100f60:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100f65:	0f 85 e7 00 00 00    	jne    f0101052 <mem_init+0x37b>
f0100f6b:	e9 be 00 00 00       	jmp    f010102e <mem_init+0x357>

	first_free_page = (char *) boot_alloc(0);
	cprintf("EXTPHYSMEM belonging to page %d \n",PGNUM(EXTPHYSMEM));
	for (pp = page_free_list; pp; pp = pp->pp_link) {
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100f70:	39 d8                	cmp    %ebx,%eax
f0100f72:	76 24                	jbe    f0100f98 <mem_init+0x2c1>
f0100f74:	c7 44 24 0c 60 4c 10 	movl   $0xf0104c60,0xc(%esp)
f0100f7b:	f0 
f0100f7c:	c7 44 24 08 6c 4c 10 	movl   $0xf0104c6c,0x8(%esp)
f0100f83:	f0 
f0100f84:	c7 44 24 04 d9 02 00 	movl   $0x2d9,0x4(%esp)
f0100f8b:	00 
f0100f8c:	c7 04 24 54 4c 10 f0 	movl   $0xf0104c54,(%esp)
f0100f93:	e8 a8 f0 ff ff       	call   f0100040 <_panic>
		assert(pp < pages + npages);
f0100f98:	8b 15 08 ff 21 f0    	mov    0xf021ff08,%edx
f0100f9e:	8d 14 d0             	lea    (%eax,%edx,8),%edx
f0100fa1:	39 d3                	cmp    %edx,%ebx
f0100fa3:	72 24                	jb     f0100fc9 <mem_init+0x2f2>
f0100fa5:	c7 44 24 0c 81 4c 10 	movl   $0xf0104c81,0xc(%esp)
f0100fac:	f0 
f0100fad:	c7 44 24 08 6c 4c 10 	movl   $0xf0104c6c,0x8(%esp)
f0100fb4:	f0 
f0100fb5:	c7 44 24 04 da 02 00 	movl   $0x2da,0x4(%esp)
f0100fbc:	00 
f0100fbd:	c7 04 24 54 4c 10 f0 	movl   $0xf0104c54,(%esp)
f0100fc4:	e8 77 f0 ff ff       	call   f0100040 <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100fc9:	89 de                	mov    %ebx,%esi
f0100fcb:	89 d9                	mov    %ebx,%ecx
f0100fcd:	29 c1                	sub    %eax,%ecx
f0100fcf:	89 c8                	mov    %ecx,%eax
f0100fd1:	a8 07                	test   $0x7,%al
f0100fd3:	74 24                	je     f0100ff9 <mem_init+0x322>
f0100fd5:	c7 44 24 0c 54 4b 10 	movl   $0xf0104b54,0xc(%esp)
f0100fdc:	f0 
f0100fdd:	c7 44 24 08 6c 4c 10 	movl   $0xf0104c6c,0x8(%esp)
f0100fe4:	f0 
f0100fe5:	c7 44 24 04 db 02 00 	movl   $0x2db,0x4(%esp)
f0100fec:	00 
f0100fed:	c7 04 24 54 4c 10 f0 	movl   $0xf0104c54,(%esp)
f0100ff4:	e8 47 f0 ff ff       	call   f0100040 <_panic>
f0100ff9:	c1 f8 03             	sar    $0x3,%eax
f0100ffc:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100fff:	85 c0                	test   %eax,%eax
f0101001:	75 24                	jne    f0101027 <mem_init+0x350>
f0101003:	c7 44 24 0c 95 4c 10 	movl   $0xf0104c95,0xc(%esp)
f010100a:	f0 
f010100b:	c7 44 24 08 6c 4c 10 	movl   $0xf0104c6c,0x8(%esp)
f0101012:	f0 
f0101013:	c7 44 24 04 de 02 00 	movl   $0x2de,0x4(%esp)
f010101a:	00 
f010101b:	c7 04 24 54 4c 10 f0 	movl   $0xf0104c54,(%esp)
f0101022:	e8 19 f0 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0101027:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f010102c:	75 24                	jne    f0101052 <mem_init+0x37b>
f010102e:	c7 44 24 0c a6 4c 10 	movl   $0xf0104ca6,0xc(%esp)
f0101035:	f0 
f0101036:	c7 44 24 08 6c 4c 10 	movl   $0xf0104c6c,0x8(%esp)
f010103d:	f0 
f010103e:	c7 44 24 04 df 02 00 	movl   $0x2df,0x4(%esp)
f0101045:	00 
f0101046:	c7 04 24 54 4c 10 f0 	movl   $0xf0104c54,(%esp)
f010104d:	e8 ee ef ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
f0101052:	3d 00 f0 0f 00       	cmp    $0xff000,%eax
f0101057:	75 24                	jne    f010107d <mem_init+0x3a6>
f0101059:	c7 44 24 0c 88 4b 10 	movl   $0xf0104b88,0xc(%esp)
f0101060:	f0 
f0101061:	c7 44 24 08 6c 4c 10 	movl   $0xf0104c6c,0x8(%esp)
f0101068:	f0 
f0101069:	c7 44 24 04 e0 02 00 	movl   $0x2e0,0x4(%esp)
f0101070:	00 
f0101071:	c7 04 24 54 4c 10 f0 	movl   $0xf0104c54,(%esp)
f0101078:	e8 c3 ef ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f010107d:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0101082:	75 24                	jne    f01010a8 <mem_init+0x3d1>
f0101084:	c7 44 24 0c bf 4c 10 	movl   $0xf0104cbf,0xc(%esp)
f010108b:	f0 
f010108c:	c7 44 24 08 6c 4c 10 	movl   $0xf0104c6c,0x8(%esp)
f0101093:	f0 
f0101094:	c7 44 24 04 e1 02 00 	movl   $0x2e1,0x4(%esp)
f010109b:	00 
f010109c:	c7 04 24 54 4c 10 f0 	movl   $0xf0104c54,(%esp)
f01010a3:	e8 98 ef ff ff       	call   f0100040 <_panic>
		cprintf("page %d \n",PGNUM(page2pa(pp)));
f01010a8:	c1 e8 0c             	shr    $0xc,%eax
f01010ab:	89 44 24 04          	mov    %eax,0x4(%esp)
f01010af:	c7 04 24 d9 4c 10 f0 	movl   $0xf0104cd9,(%esp)
f01010b6:	e8 b9 0e 00 00       	call   f0101f74 <cprintf>
f01010bb:	a1 10 ff 21 f0       	mov    0xf021ff10,%eax
f01010c0:	29 c6                	sub    %eax,%esi
f01010c2:	c1 fe 03             	sar    $0x3,%esi
f01010c5:	c1 e6 0c             	shl    $0xc,%esi
		//assert((char *) page2kva(pp) >= first_free_page );
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
f01010c8:	81 fe ff ff 0f 00    	cmp    $0xfffff,%esi
f01010ce:	76 5b                	jbe    f010112b <mem_init+0x454>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01010d0:	89 f1                	mov    %esi,%ecx
f01010d2:	c1 e9 0c             	shr    $0xc,%ecx
f01010d5:	3b 0d 08 ff 21 f0    	cmp    0xf021ff08,%ecx
f01010db:	72 20                	jb     f01010fd <mem_init+0x426>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01010dd:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01010e1:	c7 44 24 08 84 44 10 	movl   $0xf0104484,0x8(%esp)
f01010e8:	f0 
f01010e9:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01010f0:	00 
f01010f1:	c7 04 24 29 4c 10 f0 	movl   $0xf0104c29,(%esp)
f01010f8:	e8 43 ef ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01010fd:	8d 96 00 00 00 f0    	lea    -0x10000000(%esi),%edx
f0101103:	39 d7                	cmp    %edx,%edi
f0101105:	76 24                	jbe    f010112b <mem_init+0x454>
f0101107:	c7 44 24 0c ac 4b 10 	movl   $0xf0104bac,0xc(%esp)
f010110e:	f0 
f010110f:	c7 44 24 08 6c 4c 10 	movl   $0xf0104c6c,0x8(%esp)
f0101116:	f0 
f0101117:	c7 44 24 04 e4 02 00 	movl   $0x2e4,0x4(%esp)
f010111e:	00 
f010111f:	c7 04 24 54 4c 10 f0 	movl   $0xf0104c54,(%esp)
f0101126:	e8 15 ef ff ff       	call   f0100040 <_panic>
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f010112b:	81 fe 00 70 00 00    	cmp    $0x7000,%esi
f0101131:	75 24                	jne    f0101157 <mem_init+0x480>
f0101133:	c7 44 24 0c e3 4c 10 	movl   $0xf0104ce3,0xc(%esp)
f010113a:	f0 
f010113b:	c7 44 24 08 6c 4c 10 	movl   $0xf0104c6c,0x8(%esp)
f0101142:	f0 
f0101143:	c7 44 24 04 e6 02 00 	movl   $0x2e6,0x4(%esp)
f010114a:	00 
f010114b:	c7 04 24 54 4c 10 f0 	movl   $0xf0104c54,(%esp)
f0101152:	e8 e9 ee ff ff       	call   f0100040 <_panic>
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	cprintf("EXTPHYSMEM belonging to page %d \n",PGNUM(EXTPHYSMEM));
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0101157:	8b 1b                	mov    (%ebx),%ebx
f0101159:	85 db                	test   %ebx,%ebx
f010115b:	0f 85 0f fe ff ff    	jne    f0100f70 <mem_init+0x299>
		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
		else
			++nfree_extmem;
	}
	panic("stop please\n");
f0101161:	c7 44 24 08 00 4d 10 	movl   $0xf0104d00,0x8(%esp)
f0101168:	f0 
f0101169:	c7 44 24 04 ed 02 00 	movl   $0x2ed,0x4(%esp)
f0101170:	00 
f0101171:	c7 04 24 54 4c 10 f0 	movl   $0xf0104c54,(%esp)
f0101178:	e8 c3 ee ff ff       	call   f0100040 <_panic>

f010117d <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
f010117d:	55                   	push   %ebp
f010117e:	89 e5                	mov    %esp,%ebp
f0101180:	53                   	push   %ebx
f0101181:	83 ec 14             	sub    $0x14,%esp
	//test output
              //cprintf(">>  page_alloc() was called!\n");

             if (page_free_list == NULL)
f0101184:	8b 1d 40 f2 21 f0    	mov    0xf021f240,%ebx
f010118a:	85 db                	test   %ebx,%ebx
f010118c:	74 69                	je     f01011f7 <page_alloc+0x7a>
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
f010118e:	8b 03                	mov    (%ebx),%eax
f0101190:	a3 40 f2 21 f0       	mov    %eax,0xf021f240
    
             if (alloc_flags & ALLOC_ZERO)
                    memset(page2kva(result), 0, PGSIZE);
        
             return result;
f0101195:	89 d8                	mov    %ebx,%eax
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
    
             if (alloc_flags & ALLOC_ZERO)
f0101197:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f010119b:	74 5f                	je     f01011fc <page_alloc+0x7f>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010119d:	2b 05 10 ff 21 f0    	sub    0xf021ff10,%eax
f01011a3:	c1 f8 03             	sar    $0x3,%eax
f01011a6:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01011a9:	89 c2                	mov    %eax,%edx
f01011ab:	c1 ea 0c             	shr    $0xc,%edx
f01011ae:	3b 15 08 ff 21 f0    	cmp    0xf021ff08,%edx
f01011b4:	72 20                	jb     f01011d6 <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01011b6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01011ba:	c7 44 24 08 84 44 10 	movl   $0xf0104484,0x8(%esp)
f01011c1:	f0 
f01011c2:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01011c9:	00 
f01011ca:	c7 04 24 29 4c 10 f0 	movl   $0xf0104c29,(%esp)
f01011d1:	e8 6a ee ff ff       	call   f0100040 <_panic>
                    memset(page2kva(result), 0, PGSIZE);
f01011d6:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01011dd:	00 
f01011de:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01011e5:	00 
	return (void *)(pa + KERNBASE);
f01011e6:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01011eb:	89 04 24             	mov    %eax,(%esp)
f01011ee:	e8 d6 24 00 00       	call   f01036c9 <memset>
        
             return result;
f01011f3:	89 d8                	mov    %ebx,%eax
f01011f5:	eb 05                	jmp    f01011fc <page_alloc+0x7f>
{
	//test output
              //cprintf(">>  page_alloc() was called!\n");

             if (page_free_list == NULL)
                             return NULL;
f01011f7:	b8 00 00 00 00       	mov    $0x0,%eax
    
             if (alloc_flags & ALLOC_ZERO)
                    memset(page2kva(result), 0, PGSIZE);
        
             return result;
}
f01011fc:	83 c4 14             	add    $0x14,%esp
f01011ff:	5b                   	pop    %ebx
f0101200:	5d                   	pop    %ebp
f0101201:	c3                   	ret    

f0101202 <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct Page *pp)
{
f0101202:	55                   	push   %ebp
f0101203:	89 e5                	mov    %esp,%ebp
f0101205:	8b 45 08             	mov    0x8(%ebp),%eax
	pp->pp_link = page_free_list;
f0101208:	8b 15 40 f2 21 f0    	mov    0xf021f240,%edx
f010120e:	89 10                	mov    %edx,(%eax)
              page_free_list = pp;
f0101210:	a3 40 f2 21 f0       	mov    %eax,0xf021f240
	// Fill this function in
}
f0101215:	5d                   	pop    %ebp
f0101216:	c3                   	ret    

f0101217 <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct Page* pp)
{
f0101217:	55                   	push   %ebp
f0101218:	89 e5                	mov    %esp,%ebp
f010121a:	83 ec 04             	sub    $0x4,%esp
f010121d:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f0101220:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f0101224:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0101227:	66 89 50 04          	mov    %dx,0x4(%eax)
f010122b:	66 85 d2             	test   %dx,%dx
f010122e:	75 08                	jne    f0101238 <page_decref+0x21>
		page_free(pp);
f0101230:	89 04 24             	mov    %eax,(%esp)
f0101233:	e8 ca ff ff ff       	call   f0101202 <page_free>
}
f0101238:	c9                   	leave  
f0101239:	c3                   	ret    

f010123a <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f010123a:	55                   	push   %ebp
f010123b:	89 e5                	mov    %esp,%ebp
f010123d:	56                   	push   %esi
f010123e:	53                   	push   %ebx
f010123f:	83 ec 10             	sub    $0x10,%esp
f0101242:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	// Fill this function in
	//test output
              //cprintf(">>  pgdir_walk() was called!\n");

             pte_t *result;
            if (pgdir[PDX(va)] == (pte_t)NULL) {            //yet to create
f0101245:	89 de                	mov    %ebx,%esi
f0101247:	c1 ee 16             	shr    $0x16,%esi
f010124a:	c1 e6 02             	shl    $0x2,%esi
f010124d:	03 75 08             	add    0x8(%ebp),%esi
f0101250:	8b 06                	mov    (%esi),%eax
f0101252:	85 c0                	test   %eax,%eax
f0101254:	75 76                	jne    f01012cc <pgdir_walk+0x92>
                      if (create == 0)
f0101256:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f010125a:	0f 84 d1 00 00 00    	je     f0101331 <pgdir_walk+0xf7>
                                        return NULL;
                     else {
                                        struct Page *tmp = page_alloc(ALLOC_ZERO);
f0101260:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101267:	e8 11 ff ff ff       	call   f010117d <page_alloc>
                                        if (tmp == NULL)
f010126c:	85 c0                	test   %eax,%eax
f010126e:	0f 84 c4 00 00 00    	je     f0101338 <pgdir_walk+0xfe>
                                                  return NULL;                        //failed to alloc
                                        else {
                                                  tmp->pp_ref++;
f0101274:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101279:	89 c2                	mov    %eax,%edx
f010127b:	2b 15 10 ff 21 f0    	sub    0xf021ff10,%edx
f0101281:	c1 fa 03             	sar    $0x3,%edx
f0101284:	c1 e2 0c             	shl    $0xc,%edx
                                                  pgdir[PDX(va)] = page2pa(tmp) | PTE_P | PTE_W |PTE_U;    //save the physical address of newly allocated page in page dir
f0101287:	83 ca 07             	or     $0x7,%edx
f010128a:	89 16                	mov    %edx,(%esi)
f010128c:	2b 05 10 ff 21 f0    	sub    0xf021ff10,%eax
f0101292:	c1 f8 03             	sar    $0x3,%eax
f0101295:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101298:	89 c2                	mov    %eax,%edx
f010129a:	c1 ea 0c             	shr    $0xc,%edx
f010129d:	3b 15 08 ff 21 f0    	cmp    0xf021ff08,%edx
f01012a3:	72 20                	jb     f01012c5 <pgdir_walk+0x8b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01012a5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01012a9:	c7 44 24 08 84 44 10 	movl   $0xf0104484,0x8(%esp)
f01012b0:	f0 
f01012b1:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01012b8:	00 
f01012b9:	c7 04 24 29 4c 10 f0 	movl   $0xf0104c29,(%esp)
f01012c0:	e8 7b ed ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01012c5:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01012ca:	eb 58                	jmp    f0101324 <pgdir_walk+0xea>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01012cc:	c1 e8 0c             	shr    $0xc,%eax
f01012cf:	8b 15 08 ff 21 f0    	mov    0xf021ff08,%edx
f01012d5:	39 d0                	cmp    %edx,%eax
f01012d7:	72 1c                	jb     f01012f5 <pgdir_walk+0xbb>
		panic("pa2page called with invalid pa");
f01012d9:	c7 44 24 08 90 4a 10 	movl   $0xf0104a90,0x8(%esp)
f01012e0:	f0 
f01012e1:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01012e8:	00 
f01012e9:	c7 04 24 29 4c 10 f0 	movl   $0xf0104c29,(%esp)
f01012f0:	e8 4b ed ff ff       	call   f0100040 <_panic>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01012f5:	89 c1                	mov    %eax,%ecx
f01012f7:	c1 e1 0c             	shl    $0xc,%ecx
f01012fa:	39 d0                	cmp    %edx,%eax
f01012fc:	72 20                	jb     f010131e <pgdir_walk+0xe4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01012fe:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0101302:	c7 44 24 08 84 44 10 	movl   $0xf0104484,0x8(%esp)
f0101309:	f0 
f010130a:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101311:	00 
f0101312:	c7 04 24 29 4c 10 f0 	movl   $0xf0104c29,(%esp)
f0101319:	e8 22 ed ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f010131e:	8d 81 00 00 00 f0    	lea    -0x10000000(%ecx),%eax
                                  }
                 }
               else                        
               result = page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
        
               return &result[PTX(va)];
f0101324:	c1 eb 0a             	shr    $0xa,%ebx
f0101327:	81 e3 fc 0f 00 00    	and    $0xffc,%ebx
f010132d:	01 d8                	add    %ebx,%eax
f010132f:	eb 0c                	jmp    f010133d <pgdir_walk+0x103>
              //cprintf(">>  pgdir_walk() was called!\n");

             pte_t *result;
            if (pgdir[PDX(va)] == (pte_t)NULL) {            //yet to create
                      if (create == 0)
                                        return NULL;
f0101331:	b8 00 00 00 00       	mov    $0x0,%eax
f0101336:	eb 05                	jmp    f010133d <pgdir_walk+0x103>
                     else {
                                        struct Page *tmp = page_alloc(ALLOC_ZERO);
                                        if (tmp == NULL)
                                                  return NULL;                        //failed to alloc
f0101338:	b8 00 00 00 00       	mov    $0x0,%eax
                 }
               else                        
               result = page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
        
               return &result[PTX(va)];
}
f010133d:	83 c4 10             	add    $0x10,%esp
f0101340:	5b                   	pop    %ebx
f0101341:	5e                   	pop    %esi
f0101342:	5d                   	pop    %ebp
f0101343:	c3                   	ret    

f0101344 <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f0101344:	55                   	push   %ebp
f0101345:	89 e5                	mov    %esp,%ebp
f0101347:	53                   	push   %ebx
f0101348:	83 ec 14             	sub    $0x14,%esp
f010134b:	8b 5d 10             	mov    0x10(%ebp),%ebx
	// Fill this function in
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
f010134e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101355:	00 
f0101356:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101359:	89 44 24 04          	mov    %eax,0x4(%esp)
f010135d:	8b 45 08             	mov    0x8(%ebp),%eax
f0101360:	89 04 24             	mov    %eax,(%esp)
f0101363:	e8 d2 fe ff ff       	call   f010123a <pgdir_walk>
              if (pte == NULL)
f0101368:	85 c0                	test   %eax,%eax
f010136a:	74 3a                	je     f01013a6 <page_lookup+0x62>
                       return NULL;

             if (pte_store != 0)
f010136c:	85 db                	test   %ebx,%ebx
f010136e:	74 02                	je     f0101372 <page_lookup+0x2e>
                     *pte_store = pte;
f0101370:	89 03                	mov    %eax,(%ebx)

             return pa2page(PTE_ADDR(pte[0]));
f0101372:	8b 00                	mov    (%eax),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101374:	c1 e8 0c             	shr    $0xc,%eax
f0101377:	3b 05 08 ff 21 f0    	cmp    0xf021ff08,%eax
f010137d:	72 1c                	jb     f010139b <page_lookup+0x57>
		panic("pa2page called with invalid pa");
f010137f:	c7 44 24 08 90 4a 10 	movl   $0xf0104a90,0x8(%esp)
f0101386:	f0 
f0101387:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010138e:	00 
f010138f:	c7 04 24 29 4c 10 f0 	movl   $0xf0104c29,(%esp)
f0101396:	e8 a5 ec ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f010139b:	8b 15 10 ff 21 f0    	mov    0xf021ff10,%edx
f01013a1:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01013a4:	eb 05                	jmp    f01013ab <page_lookup+0x67>
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
              if (pte == NULL)
                       return NULL;
f01013a6:	b8 00 00 00 00       	mov    $0x0,%eax

             if (pte_store != 0)
                     *pte_store = pte;

             return pa2page(PTE_ADDR(pte[0]));
}
f01013ab:	83 c4 14             	add    $0x14,%esp
f01013ae:	5b                   	pop    %ebx
f01013af:	5d                   	pop    %ebp
f01013b0:	c3                   	ret    

f01013b1 <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f01013b1:	55                   	push   %ebp
f01013b2:	89 e5                	mov    %esp,%ebp
f01013b4:	83 ec 08             	sub    $0x8,%esp
	// Flush the entry only if we're modifying the current address space.
	if (!curenv || curenv->env_pgdir == pgdir)
f01013b7:	e8 a7 29 00 00       	call   f0103d63 <cpunum>
f01013bc:	6b c0 74             	imul   $0x74,%eax,%eax
f01013bf:	83 b8 28 00 22 f0 00 	cmpl   $0x0,-0xfddffd8(%eax)
f01013c6:	74 16                	je     f01013de <tlb_invalidate+0x2d>
f01013c8:	e8 96 29 00 00       	call   f0103d63 <cpunum>
f01013cd:	6b c0 74             	imul   $0x74,%eax,%eax
f01013d0:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f01013d6:	8b 55 08             	mov    0x8(%ebp),%edx
f01013d9:	39 50 60             	cmp    %edx,0x60(%eax)
f01013dc:	75 06                	jne    f01013e4 <tlb_invalidate+0x33>
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f01013de:	8b 45 0c             	mov    0xc(%ebp),%eax
f01013e1:	0f 01 38             	invlpg (%eax)
		invlpg(va);
}
f01013e4:	c9                   	leave  
f01013e5:	c3                   	ret    

f01013e6 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f01013e6:	55                   	push   %ebp
f01013e7:	89 e5                	mov    %esp,%ebp
f01013e9:	56                   	push   %esi
f01013ea:	53                   	push   %ebx
f01013eb:	83 ec 20             	sub    $0x20,%esp
f01013ee:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01013f1:	8b 75 0c             	mov    0xc(%ebp),%esi
	// Fill this function in
	//test output
               //cprintf(">>  page_remove() was called!\n");
    
              pte_t *pte;
              struct Page *page = page_lookup(pgdir, va, &pte);
f01013f4:	8d 45 f4             	lea    -0xc(%ebp),%eax
f01013f7:	89 44 24 08          	mov    %eax,0x8(%esp)
f01013fb:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013ff:	89 1c 24             	mov    %ebx,(%esp)
f0101402:	e8 3d ff ff ff       	call   f0101344 <page_lookup>
    
              if (page != NULL)
f0101407:	85 c0                	test   %eax,%eax
f0101409:	74 08                	je     f0101413 <page_remove+0x2d>
                         page_decref(page);
f010140b:	89 04 24             	mov    %eax,(%esp)
f010140e:	e8 04 fe ff ff       	call   f0101217 <page_decref>
        
              pte[0] = 0;
f0101413:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101416:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
              tlb_invalidate(pgdir, va);
f010141c:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101420:	89 1c 24             	mov    %ebx,(%esp)
f0101423:	e8 89 ff ff ff       	call   f01013b1 <tlb_invalidate>
}
f0101428:	83 c4 20             	add    $0x20,%esp
f010142b:	5b                   	pop    %ebx
f010142c:	5e                   	pop    %esi
f010142d:	5d                   	pop    %ebp
f010142e:	c3                   	ret    

f010142f <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
{
f010142f:	55                   	push   %ebp
f0101430:	89 e5                	mov    %esp,%ebp
f0101432:	57                   	push   %edi
f0101433:	56                   	push   %esi
f0101434:	53                   	push   %ebx
f0101435:	83 ec 1c             	sub    $0x1c,%esp
f0101438:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010143b:	8b 75 10             	mov    0x10(%ebp),%esi
	// Fill this function in
	//test output
                                //cprintf(">>  page_insert() was called!\n");
    
               struct Page *page = page_lookup(pgdir, va, NULL);
f010143e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101445:	00 
f0101446:	89 74 24 04          	mov    %esi,0x4(%esp)
f010144a:	8b 45 08             	mov    0x8(%ebp),%eax
f010144d:	89 04 24             	mov    %eax,(%esp)
f0101450:	e8 ef fe ff ff       	call   f0101344 <page_lookup>
f0101455:	89 c7                	mov    %eax,%edi
               pte_t *pte;
    
              if (page == pp) {                       //re-insert into the same place
f0101457:	39 d8                	cmp    %ebx,%eax
f0101459:	75 36                	jne    f0101491 <page_insert+0x62>
                            pte = pgdir_walk(pgdir, va, 0);
f010145b:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101462:	00 
f0101463:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101467:	8b 45 08             	mov    0x8(%ebp),%eax
f010146a:	89 04 24             	mov    %eax,(%esp)
f010146d:	e8 c8 fd ff ff       	call   f010123a <pgdir_walk>
                            pte[0] = page2pa(pp) | perm | PTE_P;
f0101472:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0101475:	83 c9 01             	or     $0x1,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101478:	2b 3d 10 ff 21 f0    	sub    0xf021ff10,%edi
f010147e:	c1 ff 03             	sar    $0x3,%edi
f0101481:	c1 e7 0c             	shl    $0xc,%edi
f0101484:	89 fa                	mov    %edi,%edx
f0101486:	09 ca                	or     %ecx,%edx
f0101488:	89 10                	mov    %edx,(%eax)
                            return 0;
f010148a:	b8 00 00 00 00       	mov    $0x0,%eax
f010148f:	eb 57                	jmp    f01014e8 <page_insert+0xb9>
                          }
    
               if (page != NULL)                       //remove original page if existed
f0101491:	85 c0                	test   %eax,%eax
f0101493:	74 0f                	je     f01014a4 <page_insert+0x75>
                        page_remove(pgdir, va);
f0101495:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101499:	8b 45 08             	mov    0x8(%ebp),%eax
f010149c:	89 04 24             	mov    %eax,(%esp)
f010149f:	e8 42 ff ff ff       	call   f01013e6 <page_remove>
        
              pte = pgdir_walk(pgdir, va, 1);
f01014a4:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01014ab:	00 
f01014ac:	89 74 24 04          	mov    %esi,0x4(%esp)
f01014b0:	8b 45 08             	mov    0x8(%ebp),%eax
f01014b3:	89 04 24             	mov    %eax,(%esp)
f01014b6:	e8 7f fd ff ff       	call   f010123a <pgdir_walk>
              if (pte == NULL)
f01014bb:	85 c0                	test   %eax,%eax
f01014bd:	74 24                	je     f01014e3 <page_insert+0xb4>
                       return -E_NO_MEM;

              pte[0] = page2pa(pp) | perm | PTE_P;
f01014bf:	8b 4d 14             	mov    0x14(%ebp),%ecx
f01014c2:	83 c9 01             	or     $0x1,%ecx
f01014c5:	89 da                	mov    %ebx,%edx
f01014c7:	2b 15 10 ff 21 f0    	sub    0xf021ff10,%edx
f01014cd:	c1 fa 03             	sar    $0x3,%edx
f01014d0:	c1 e2 0c             	shl    $0xc,%edx
f01014d3:	09 ca                	or     %ecx,%edx
f01014d5:	89 10                	mov    %edx,(%eax)
               pp->pp_ref++;
f01014d7:	66 83 43 04 01       	addw   $0x1,0x4(%ebx)

	return 0; 
f01014dc:	b8 00 00 00 00       	mov    $0x0,%eax
f01014e1:	eb 05                	jmp    f01014e8 <page_insert+0xb9>
               if (page != NULL)                       //remove original page if existed
                        page_remove(pgdir, va);
        
              pte = pgdir_walk(pgdir, va, 1);
              if (pte == NULL)
                       return -E_NO_MEM;
f01014e3:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax

              pte[0] = page2pa(pp) | perm | PTE_P;
               pp->pp_ref++;

	return 0; 
}
f01014e8:	83 c4 1c             	add    $0x1c,%esp
f01014eb:	5b                   	pop    %ebx
f01014ec:	5e                   	pop    %esi
f01014ed:	5f                   	pop    %edi
f01014ee:	5d                   	pop    %ebp
f01014ef:	c3                   	ret    

f01014f0 <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f01014f0:	55                   	push   %ebp
f01014f1:	89 e5                	mov    %esp,%ebp
f01014f3:	57                   	push   %edi
f01014f4:	56                   	push   %esi
f01014f5:	53                   	push   %ebx
f01014f6:	83 ec 3c             	sub    $0x3c,%esp
f01014f9:	8b 7d 08             	mov    0x8(%ebp),%edi
f01014fc:	8b 45 0c             	mov    0xc(%ebp),%eax

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
f01014ff:	89 c2                	mov    %eax,%edx
f0101501:	03 55 10             	add    0x10(%ebp),%edx
f0101504:	89 55 d0             	mov    %edx,-0x30(%ebp)
f0101507:	39 d0                	cmp    %edx,%eax
f0101509:	73 70                	jae    f010157b <user_mem_check+0x8b>
f010150b:	89 c3                	mov    %eax,%ebx
f010150d:	89 c6                	mov    %eax,%esi
		pte_t* store=0;
		struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
		if(store!=NULL)
		{
			//cprintf("pte!=NULL %08x\r\n",*store);
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f010150f:	8b 45 14             	mov    0x14(%ebp),%eax
f0101512:	83 c8 01             	or     $0x1,%eax
f0101515:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
	{
		pte_t* store=0;
f0101518:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
		struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
f010151f:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101522:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101526:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010152a:	8b 47 60             	mov    0x60(%edi),%eax
f010152d:	89 04 24             	mov    %eax,(%esp)
f0101530:	e8 0f fe ff ff       	call   f0101344 <page_lookup>
		if(store!=NULL)
f0101535:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0101538:	85 c0                	test   %eax,%eax
f010153a:	74 1b                	je     f0101557 <user_mem_check+0x67>
		{
			//cprintf("pte!=NULL %08x\r\n",*store);
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f010153c:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f010153f:	89 ca                	mov    %ecx,%edx
f0101541:	23 10                	and    (%eax),%edx
f0101543:	39 d1                	cmp    %edx,%ecx
f0101545:	75 08                	jne    f010154f <user_mem_check+0x5f>
f0101547:	81 fe 00 00 80 ef    	cmp    $0xef800000,%esi
f010154d:	76 10                	jbe    f010155f <user_mem_check+0x6f>
			   {
				//cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f010154f:	89 35 3c f2 21 f0    	mov    %esi,0xf021f23c
				break;
f0101555:	eb 1d                	jmp    f0101574 <user_mem_check+0x84>
			}
			else
			{
				//cprintf("no pte!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f0101557:	89 35 3c f2 21 f0    	mov    %esi,0xf021f23c
				break;
f010155d:	eb 15                	jmp    f0101574 <user_mem_check+0x84>
			}
		    i=ROUNDDOWN(i,PGSIZE);
f010155f:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
f0101565:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f010156b:	89 de                	mov    %ebx,%esi
f010156d:	3b 5d d0             	cmp    -0x30(%ebp),%ebx
f0101570:	72 a6                	jb     f0101518 <user_mem_check+0x28>
f0101572:	eb 0e                	jmp    f0101582 <user_mem_check+0x92>
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
			   {
				//cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
				break;
f0101574:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f0101579:	eb 0c                	jmp    f0101587 <user_mem_check+0x97>
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
f010157b:	b8 00 00 00 00       	mov    $0x0,%eax
f0101580:	eb 05                	jmp    f0101587 <user_mem_check+0x97>
f0101582:	b8 00 00 00 00       	mov    $0x0,%eax
			}
		    i=ROUNDDOWN(i,PGSIZE);
		}

	return flag;
}
f0101587:	83 c4 3c             	add    $0x3c,%esp
f010158a:	5b                   	pop    %ebx
f010158b:	5e                   	pop    %esi
f010158c:	5f                   	pop    %edi
f010158d:	5d                   	pop    %ebp
f010158e:	c3                   	ret    

f010158f <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f010158f:	55                   	push   %ebp
f0101590:	89 e5                	mov    %esp,%ebp
f0101592:	53                   	push   %ebx
f0101593:	83 ec 14             	sub    $0x14,%esp
f0101596:	8b 5d 08             	mov    0x8(%ebp),%ebx
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
f0101599:	8b 45 14             	mov    0x14(%ebp),%eax
f010159c:	83 c8 04             	or     $0x4,%eax
f010159f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01015a3:	8b 45 10             	mov    0x10(%ebp),%eax
f01015a6:	89 44 24 08          	mov    %eax,0x8(%esp)
f01015aa:	8b 45 0c             	mov    0xc(%ebp),%eax
f01015ad:	89 44 24 04          	mov    %eax,0x4(%esp)
f01015b1:	89 1c 24             	mov    %ebx,(%esp)
f01015b4:	e8 37 ff ff ff       	call   f01014f0 <user_mem_check>
f01015b9:	85 c0                	test   %eax,%eax
f01015bb:	79 24                	jns    f01015e1 <user_mem_assert+0x52>
		cprintf(".%08x. user_mem_check assertion failure for "
f01015bd:	a1 3c f2 21 f0       	mov    0xf021f23c,%eax
f01015c2:	89 44 24 08          	mov    %eax,0x8(%esp)
f01015c6:	8b 43 48             	mov    0x48(%ebx),%eax
f01015c9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01015cd:	c7 04 24 f4 4b 10 f0 	movl   $0xf0104bf4,(%esp)
f01015d4:	e8 9b 09 00 00       	call   f0101f74 <cprintf>
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
f01015d9:	89 1c 24             	mov    %ebx,(%esp)
f01015dc:	e8 ef 06 00 00       	call   f0101cd0 <env_destroy>
	}
}
f01015e1:	83 c4 14             	add    $0x14,%esp
f01015e4:	5b                   	pop    %ebx
f01015e5:	5d                   	pop    %ebp
f01015e6:	c3                   	ret    

f01015e7 <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f01015e7:	55                   	push   %ebp
f01015e8:	89 e5                	mov    %esp,%ebp
f01015ea:	56                   	push   %esi
f01015eb:	53                   	push   %ebx
f01015ec:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f01015ef:	85 c0                	test   %eax,%eax
f01015f1:	75 1a                	jne    f010160d <envid2env+0x26>
		*env_store = curenv;
f01015f3:	e8 6b 27 00 00       	call   f0103d63 <cpunum>
f01015f8:	6b c0 74             	imul   $0x74,%eax,%eax
f01015fb:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0101601:	8b 55 0c             	mov    0xc(%ebp),%edx
f0101604:	89 02                	mov    %eax,(%edx)
		return 0;
f0101606:	b8 00 00 00 00       	mov    $0x0,%eax
f010160b:	eb 72                	jmp    f010167f <envid2env+0x98>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f010160d:	89 c3                	mov    %eax,%ebx
f010160f:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
f0101615:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f0101618:	03 1d 48 f2 21 f0    	add    0xf021f248,%ebx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f010161e:	83 7b 54 00          	cmpl   $0x0,0x54(%ebx)
f0101622:	74 05                	je     f0101629 <envid2env+0x42>
f0101624:	39 43 48             	cmp    %eax,0x48(%ebx)
f0101627:	74 10                	je     f0101639 <envid2env+0x52>
		*env_store = 0;
f0101629:	8b 45 0c             	mov    0xc(%ebp),%eax
f010162c:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f0101632:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0101637:	eb 46                	jmp    f010167f <envid2env+0x98>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f0101639:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f010163d:	74 36                	je     f0101675 <envid2env+0x8e>
f010163f:	e8 1f 27 00 00       	call   f0103d63 <cpunum>
f0101644:	6b c0 74             	imul   $0x74,%eax,%eax
f0101647:	39 98 28 00 22 f0    	cmp    %ebx,-0xfddffd8(%eax)
f010164d:	74 26                	je     f0101675 <envid2env+0x8e>
f010164f:	8b 73 4c             	mov    0x4c(%ebx),%esi
f0101652:	e8 0c 27 00 00       	call   f0103d63 <cpunum>
f0101657:	6b c0 74             	imul   $0x74,%eax,%eax
f010165a:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0101660:	3b 70 48             	cmp    0x48(%eax),%esi
f0101663:	74 10                	je     f0101675 <envid2env+0x8e>
		*env_store = 0;
f0101665:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101668:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f010166e:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0101673:	eb 0a                	jmp    f010167f <envid2env+0x98>
	}

	*env_store = e;
f0101675:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101678:	89 18                	mov    %ebx,(%eax)
	return 0;
f010167a:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010167f:	5b                   	pop    %ebx
f0101680:	5e                   	pop    %esi
f0101681:	5d                   	pop    %ebp
f0101682:	c3                   	ret    

f0101683 <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f0101683:	55                   	push   %ebp
f0101684:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f0101686:	b8 00 c3 11 f0       	mov    $0xf011c300,%eax
f010168b:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f010168e:	b8 23 00 00 00       	mov    $0x23,%eax
f0101693:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f0101695:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f0101697:	b0 10                	mov    $0x10,%al
f0101699:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f010169b:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f010169d:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f010169f:	ea a6 16 10 f0 08 00 	ljmp   $0x8,$0xf01016a6
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f01016a6:	b0 00                	mov    $0x0,%al
f01016a8:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f01016ab:	5d                   	pop    %ebp
f01016ac:	c3                   	ret    

f01016ad <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f01016ad:	55                   	push   %ebp
f01016ae:	89 e5                	mov    %esp,%ebp
f01016b0:	53                   	push   %ebx
f01016b1:	8b 0d 4c f2 21 f0    	mov    0xf021f24c,%ecx
f01016b7:	a1 48 f2 21 f0       	mov    0xf021f248,%eax
	// Set up envs array
	// LAB 3: Your code here.
	size_t i;
	for (i = 0; i < NENV; i++) {
		envs[i].env_id = 0;
f01016bc:	ba 00 04 00 00       	mov    $0x400,%edx
f01016c1:	89 c3                	mov    %eax,%ebx
f01016c3:	c7 40 48 00 00 00 00 	movl   $0x0,0x48(%eax)
		envs[i].env_link = env_free_list;
f01016ca:	89 48 44             	mov    %ecx,0x44(%eax)
f01016cd:	83 c0 7c             	add    $0x7c,%eax
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
	size_t i;
	for (i = 0; i < NENV; i++) {
f01016d0:	83 ea 01             	sub    $0x1,%edx
f01016d3:	74 04                	je     f01016d9 <env_init+0x2c>
		envs[i].env_id = 0;
		envs[i].env_link = env_free_list;
		env_free_list = &envs[i];
f01016d5:	89 d9                	mov    %ebx,%ecx
f01016d7:	eb e8                	jmp    f01016c1 <env_init+0x14>
	}
	env_free_list = envs; // this line of code changing like this ugly looks just fit fuck grade sh,too useless
f01016d9:	a1 48 f2 21 f0       	mov    0xf021f248,%eax
f01016de:	a3 4c f2 21 f0       	mov    %eax,0xf021f24c
	// Per-CPU part of the initialization
	env_init_percpu();
f01016e3:	e8 9b ff ff ff       	call   f0101683 <env_init_percpu>
}
f01016e8:	5b                   	pop    %ebx
f01016e9:	5d                   	pop    %ebp
f01016ea:	c3                   	ret    

f01016eb <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f01016eb:	55                   	push   %ebp
f01016ec:	89 e5                	mov    %esp,%ebp
f01016ee:	56                   	push   %esi
f01016ef:	53                   	push   %ebx
f01016f0:	83 ec 10             	sub    $0x10,%esp
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
f01016f3:	8b 1d 4c f2 21 f0    	mov    0xf021f24c,%ebx
f01016f9:	85 db                	test   %ebx,%ebx
f01016fb:	0f 84 92 01 00 00    	je     f0101893 <env_alloc+0x1a8>
{
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f0101701:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101708:	e8 70 fa ff ff       	call   f010117d <page_alloc>
f010170d:	85 c0                	test   %eax,%eax
f010170f:	0f 84 85 01 00 00    	je     f010189a <env_alloc+0x1af>
f0101715:	89 c2                	mov    %eax,%edx
f0101717:	2b 15 10 ff 21 f0    	sub    0xf021ff10,%edx
f010171d:	c1 fa 03             	sar    $0x3,%edx
f0101720:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101723:	89 d1                	mov    %edx,%ecx
f0101725:	c1 e9 0c             	shr    $0xc,%ecx
f0101728:	3b 0d 08 ff 21 f0    	cmp    0xf021ff08,%ecx
f010172e:	72 20                	jb     f0101750 <env_alloc+0x65>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101730:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101734:	c7 44 24 08 84 44 10 	movl   $0xf0104484,0x8(%esp)
f010173b:	f0 
f010173c:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101743:	00 
f0101744:	c7 04 24 29 4c 10 f0 	movl   $0xf0104c29,(%esp)
f010174b:	e8 f0 e8 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0101750:	81 ea 00 00 00 10    	sub    $0x10000000,%edx
f0101756:	89 53 60             	mov    %edx,0x60(%ebx)
	//	is an exception -- you need to increment env_pgdir's
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
f0101759:	ba ec 0e 00 00       	mov    $0xeec,%edx
	for(i=PDX(UTOP);i<1024;i++){
		e->env_pgdir[i] = kern_pgdir[i];
f010175e:	8b 0d 0c ff 21 f0    	mov    0xf021ff0c,%ecx
f0101764:	8b 34 11             	mov    (%ecx,%edx,1),%esi
f0101767:	8b 4b 60             	mov    0x60(%ebx),%ecx
f010176a:	89 34 11             	mov    %esi,(%ecx,%edx,1)
f010176d:	83 c2 04             	add    $0x4,%edx
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
	for(i=PDX(UTOP);i<1024;i++){
f0101770:	81 fa 00 10 00 00    	cmp    $0x1000,%edx
f0101776:	75 e6                	jne    f010175e <env_alloc+0x73>
		e->env_pgdir[i] = kern_pgdir[i];
	}
	p->pp_ref++;
f0101778:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f010177d:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101780:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101785:	77 20                	ja     f01017a7 <env_alloc+0xbc>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101787:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010178b:	c7 44 24 08 a8 44 10 	movl   $0xf01044a8,0x8(%esp)
f0101792:	f0 
f0101793:	c7 44 24 04 c6 00 00 	movl   $0xc6,0x4(%esp)
f010179a:	00 
f010179b:	c7 04 24 0d 4d 10 f0 	movl   $0xf0104d0d,(%esp)
f01017a2:	e8 99 e8 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01017a7:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f01017ad:	83 ca 05             	or     $0x5,%edx
f01017b0:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate and set up the page directory for this environment.
	if ((r = env_setup_vm(e)) < 0)
		return r;

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f01017b6:	8b 43 48             	mov    0x48(%ebx),%eax
f01017b9:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f01017be:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f01017c3:	ba 00 10 00 00       	mov    $0x1000,%edx
f01017c8:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f01017cb:	89 da                	mov    %ebx,%edx
f01017cd:	2b 15 48 f2 21 f0    	sub    0xf021f248,%edx
f01017d3:	c1 fa 02             	sar    $0x2,%edx
f01017d6:	69 d2 df 7b ef bd    	imul   $0xbdef7bdf,%edx,%edx
f01017dc:	09 d0                	or     %edx,%eax
f01017de:	89 43 48             	mov    %eax,0x48(%ebx)

	// Set the basic status variables.
	e->env_parent_id = parent_id;
f01017e1:	8b 45 0c             	mov    0xc(%ebp),%eax
f01017e4:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f01017e7:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f01017ee:	c7 43 54 02 00 00 00 	movl   $0x2,0x54(%ebx)
	e->env_runs = 0;
f01017f5:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f01017fc:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f0101803:	00 
f0101804:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010180b:	00 
f010180c:	89 1c 24             	mov    %ebx,(%esp)
f010180f:	e8 b5 1e 00 00       	call   f01036c9 <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f0101814:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f010181a:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f0101820:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f0101826:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f010182d:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)

	// Enable interrupts while in user mode.
	// LAB 4: Your code here.

	// Clear the page fault handler until user installs one.
	e->env_pgfault_upcall = 0;
f0101833:	c7 43 64 00 00 00 00 	movl   $0x0,0x64(%ebx)

	// Also clear the IPC receiving flag.
	e->env_ipc_recving = 0;
f010183a:	c7 43 68 00 00 00 00 	movl   $0x0,0x68(%ebx)

	// commit the allocation
	env_free_list = e->env_link;
f0101841:	8b 43 44             	mov    0x44(%ebx),%eax
f0101844:	a3 4c f2 21 f0       	mov    %eax,0xf021f24c
	*newenv_store = e;
f0101849:	8b 45 08             	mov    0x8(%ebp),%eax
f010184c:	89 18                	mov    %ebx,(%eax)

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f010184e:	8b 5b 48             	mov    0x48(%ebx),%ebx
f0101851:	e8 0d 25 00 00       	call   f0103d63 <cpunum>
f0101856:	6b d0 74             	imul   $0x74,%eax,%edx
f0101859:	b8 00 00 00 00       	mov    $0x0,%eax
f010185e:	83 ba 28 00 22 f0 00 	cmpl   $0x0,-0xfddffd8(%edx)
f0101865:	74 11                	je     f0101878 <env_alloc+0x18d>
f0101867:	e8 f7 24 00 00       	call   f0103d63 <cpunum>
f010186c:	6b c0 74             	imul   $0x74,%eax,%eax
f010186f:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0101875:	8b 40 48             	mov    0x48(%eax),%eax
f0101878:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f010187c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101880:	c7 04 24 18 4d 10 f0 	movl   $0xf0104d18,(%esp)
f0101887:	e8 e8 06 00 00       	call   f0101f74 <cprintf>
	return 0;
f010188c:	b8 00 00 00 00       	mov    $0x0,%eax
f0101891:	eb 0c                	jmp    f010189f <env_alloc+0x1b4>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
		return -E_NO_FREE_ENV;
f0101893:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f0101898:	eb 05                	jmp    f010189f <env_alloc+0x1b4>
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f010189a:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	env_free_list = e->env_link;
	*newenv_store = e;

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}
f010189f:	83 c4 10             	add    $0x10,%esp
f01018a2:	5b                   	pop    %ebx
f01018a3:	5e                   	pop    %esi
f01018a4:	5d                   	pop    %ebp
f01018a5:	c3                   	ret    

f01018a6 <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f01018a6:	55                   	push   %ebp
f01018a7:	89 e5                	mov    %esp,%ebp
f01018a9:	57                   	push   %edi
f01018aa:	56                   	push   %esi
f01018ab:	53                   	push   %ebx
f01018ac:	83 ec 3c             	sub    $0x3c,%esp
	// LAB 3: Your code here.
	struct Env * env;
	if(env_alloc(&env,0)==0){
f01018af:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01018b6:	00 
f01018b7:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f01018ba:	89 04 24             	mov    %eax,(%esp)
f01018bd:	e8 29 fe ff ff       	call   f01016eb <env_alloc>
f01018c2:	85 c0                	test   %eax,%eax
f01018c4:	0f 85 dd 01 00 00    	jne    f0101aa7 <env_create+0x201>
		load_icode(env,binary,size);
f01018ca:	8b 7d e4             	mov    -0x1c(%ebp),%edi
	//  You must also do something with the program's entry point,
	//  to make sure that the environment starts executing there.
	//  What?  (See env_run() and env_pop_tf() below.)

	// LAB 3: Your code here.
	lcr3(PADDR(e->env_pgdir));
f01018cd:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01018d0:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01018d5:	77 20                	ja     f01018f7 <env_create+0x51>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01018d7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01018db:	c7 44 24 08 a8 44 10 	movl   $0xf01044a8,0x8(%esp)
f01018e2:	f0 
f01018e3:	c7 44 24 04 64 01 00 	movl   $0x164,0x4(%esp)
f01018ea:	00 
f01018eb:	c7 04 24 0d 4d 10 f0 	movl   $0xf0104d0d,(%esp)
f01018f2:	e8 49 e7 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01018f7:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f01018fc:	0f 22 d8             	mov    %eax,%cr3
	struct Elf* ELFHDR = (struct Elf *) binary;
	if(ELFHDR->e_magic != ELF_MAGIC)
f01018ff:	8b 45 08             	mov    0x8(%ebp),%eax
f0101902:	81 38 7f 45 4c 46    	cmpl   $0x464c457f,(%eax)
f0101908:	74 1c                	je     f0101926 <env_create+0x80>
		panic("Invalid ELF format !");
f010190a:	c7 44 24 08 2d 4d 10 	movl   $0xf0104d2d,0x8(%esp)
f0101911:	f0 
f0101912:	c7 44 24 04 67 01 00 	movl   $0x167,0x4(%esp)
f0101919:	00 
f010191a:	c7 04 24 0d 4d 10 f0 	movl   $0xf0104d0d,(%esp)
f0101921:	e8 1a e7 ff ff       	call   f0100040 <_panic>

	struct Proghdr *ph,*eph;
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
f0101926:	8b 45 08             	mov    0x8(%ebp),%eax
f0101929:	89 c6                	mov    %eax,%esi
f010192b:	03 70 1c             	add    0x1c(%eax),%esi
	eph = ph + ELFHDR->e_phnum;
f010192e:	0f b7 40 2c          	movzwl 0x2c(%eax),%eax
f0101932:	c1 e0 05             	shl    $0x5,%eax
f0101935:	01 f0                	add    %esi,%eax
f0101937:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	for (; ph < eph; ph++) {
f010193a:	39 c6                	cmp    %eax,%esi
f010193c:	0f 83 d2 00 00 00    	jae    f0101a14 <env_create+0x16e>
		if (ph->p_type == ELF_PROG_LOAD) {
f0101942:	83 3e 01             	cmpl   $0x1,(%esi)
f0101945:	0f 85 bd 00 00 00    	jne    f0101a08 <env_create+0x162>
			if (ph->p_filesz > ph->p_memsz)
f010194b:	8b 56 14             	mov    0x14(%esi),%edx
f010194e:	39 56 10             	cmp    %edx,0x10(%esi)
f0101951:	76 1c                	jbe    f010196f <env_create+0xc9>
				panic("invalid ELF proGhdr header!");
f0101953:	c7 44 24 08 42 4d 10 	movl   $0xf0104d42,0x8(%esp)
f010195a:	f0 
f010195b:	c7 44 24 04 6f 01 00 	movl   $0x16f,0x4(%esp)
f0101962:	00 
f0101963:	c7 04 24 0d 4d 10 f0 	movl   $0xf0104d0d,(%esp)
f010196a:	e8 d1 e6 ff ff       	call   f0100040 <_panic>

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
f010196f:	8b 46 08             	mov    0x8(%esi),%eax
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f0101972:	89 c3                	mov    %eax,%ebx
f0101974:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f010197a:	8d 84 02 ff 0f 00 00 	lea    0xfff(%edx,%eax,1),%eax
f0101981:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0101986:	39 c3                	cmp    %eax,%ebx
f0101988:	73 59                	jae    f01019e3 <env_create+0x13d>
f010198a:	89 75 d0             	mov    %esi,-0x30(%ebp)
f010198d:	89 c6                	mov    %eax,%esi
		p = (struct Page*)page_alloc(1);
f010198f:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101996:	e8 e2 f7 ff ff       	call   f010117d <page_alloc>
		if(p==NULL)
f010199b:	85 c0                	test   %eax,%eax
f010199d:	75 1c                	jne    f01019bb <env_create+0x115>
			panic("Memory out!");
f010199f:	c7 44 24 08 5e 4d 10 	movl   $0xf0104d5e,0x8(%esp)
f01019a6:	f0 
f01019a7:	c7 44 24 04 29 01 00 	movl   $0x129,0x4(%esp)
f01019ae:	00 
f01019af:	c7 04 24 0d 4d 10 f0 	movl   $0xf0104d0d,(%esp)
f01019b6:	e8 85 e6 ff ff       	call   f0100040 <_panic>
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
f01019bb:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01019c2:	00 
f01019c3:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f01019c7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01019cb:	8b 47 60             	mov    0x60(%edi),%eax
f01019ce:	89 04 24             	mov    %eax,(%esp)
f01019d1:	e8 59 fa ff ff       	call   f010142f <page_insert>
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f01019d6:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f01019dc:	39 f3                	cmp    %esi,%ebx
f01019de:	72 af                	jb     f010198f <env_create+0xe9>
f01019e0:	8b 75 d0             	mov    -0x30(%ebp),%esi
			if (ph->p_filesz > ph->p_memsz)
				panic("invalid ELF proGhdr header!");

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
			//copy to va
			char *va = (char *)(ph->p_va);
f01019e3:	8b 4e 08             	mov    0x8(%esi),%ecx
			size_t i;
			for (i = 0; i < ph->p_filesz; i++)
f01019e6:	83 7e 10 00          	cmpl   $0x0,0x10(%esi)
f01019ea:	74 1c                	je     f0101a08 <env_create+0x162>
f01019ec:	b8 00 00 00 00       	mov    $0x0,%eax
f01019f1:	8b 5d 08             	mov    0x8(%ebp),%ebx
				va[i] = binary[ph->p_offset + i];
f01019f4:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f01019f7:	03 56 04             	add    0x4(%esi),%edx
f01019fa:	0f b6 12             	movzbl (%edx),%edx
f01019fd:	88 14 08             	mov    %dl,(%eax,%ecx,1)

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
			//copy to va
			char *va = (char *)(ph->p_va);
			size_t i;
			for (i = 0; i < ph->p_filesz; i++)
f0101a00:	83 c0 01             	add    $0x1,%eax
f0101a03:	3b 46 10             	cmp    0x10(%esi),%eax
f0101a06:	72 ec                	jb     f01019f4 <env_create+0x14e>
		panic("Invalid ELF format !");

	struct Proghdr *ph,*eph;
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
	eph = ph + ELFHDR->e_phnum;
	for (; ph < eph; ph++) {
f0101a08:	83 c6 20             	add    $0x20,%esi
f0101a0b:	39 75 d4             	cmp    %esi,-0x2c(%ebp)
f0101a0e:	0f 87 2e ff ff ff    	ja     f0101942 <env_create+0x9c>
			for (i = 0; i < ph->p_filesz; i++)
				va[i] = binary[ph->p_offset + i];
		}
	}
	//set programe entry
	e->env_tf.tf_eip = ELFHDR->e_entry;
f0101a14:	8b 45 08             	mov    0x8(%ebp),%eax
f0101a17:	8b 40 18             	mov    0x18(%eax),%eax
f0101a1a:	89 47 30             	mov    %eax,0x30(%edi)
	// Now map one page for the program's initial stack
	// at virtual address USTACKTOP - PGSIZE.

	// LAB 3: Your code here.
	struct Page* stackPage = (struct Page*)page_alloc(1);
f0101a1d:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101a24:	e8 54 f7 ff ff       	call   f010117d <page_alloc>
	if(stackPage == NULL)
f0101a29:	85 c0                	test   %eax,%eax
f0101a2b:	75 1c                	jne    f0101a49 <env_create+0x1a3>
		panic("Out of memory!");
f0101a2d:	c7 44 24 08 6a 4d 10 	movl   $0xf0104d6a,0x8(%esp)
f0101a34:	f0 
f0101a35:	c7 44 24 04 81 01 00 	movl   $0x181,0x4(%esp)
f0101a3c:	00 
f0101a3d:	c7 04 24 0d 4d 10 f0 	movl   $0xf0104d0d,(%esp)
f0101a44:	e8 f7 e5 ff ff       	call   f0100040 <_panic>
	page_insert(e->env_pgdir,stackPage,(void*)USTACKTOP - PGSIZE,PTE_U|PTE_W);
f0101a49:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0101a50:	00 
f0101a51:	c7 44 24 08 00 d0 bf 	movl   $0xeebfd000,0x8(%esp)
f0101a58:	ee 
f0101a59:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101a5d:	8b 47 60             	mov    0x60(%edi),%eax
f0101a60:	89 04 24             	mov    %eax,(%esp)
f0101a63:	e8 c7 f9 ff ff       	call   f010142f <page_insert>
	lcr3(PADDR(kern_pgdir));
f0101a68:	a1 0c ff 21 f0       	mov    0xf021ff0c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101a6d:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101a72:	77 20                	ja     f0101a94 <env_create+0x1ee>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101a74:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101a78:	c7 44 24 08 a8 44 10 	movl   $0xf01044a8,0x8(%esp)
f0101a7f:	f0 
f0101a80:	c7 44 24 04 83 01 00 	movl   $0x183,0x4(%esp)
f0101a87:	00 
f0101a88:	c7 04 24 0d 4d 10 f0 	movl   $0xf0104d0d,(%esp)
f0101a8f:	e8 ac e5 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0101a94:	05 00 00 00 10       	add    $0x10000000,%eax
f0101a99:	0f 22 d8             	mov    %eax,%cr3
{
	// LAB 3: Your code here.
	struct Env * env;
	if(env_alloc(&env,0)==0){
		load_icode(env,binary,size);
		env->env_type = type;
f0101a9c:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0101a9f:	8b 55 10             	mov    0x10(%ebp),%edx
f0101aa2:	89 50 50             	mov    %edx,0x50(%eax)
f0101aa5:	eb 1c                	jmp    f0101ac3 <env_create+0x21d>
	}else{
		panic("create env fails !");
f0101aa7:	c7 44 24 08 79 4d 10 	movl   $0xf0104d79,0x8(%esp)
f0101aae:	f0 
f0101aaf:	c7 44 24 04 96 01 00 	movl   $0x196,0x4(%esp)
f0101ab6:	00 
f0101ab7:	c7 04 24 0d 4d 10 f0 	movl   $0xf0104d0d,(%esp)
f0101abe:	e8 7d e5 ff ff       	call   f0100040 <_panic>
	}
}
f0101ac3:	83 c4 3c             	add    $0x3c,%esp
f0101ac6:	5b                   	pop    %ebx
f0101ac7:	5e                   	pop    %esi
f0101ac8:	5f                   	pop    %edi
f0101ac9:	5d                   	pop    %ebp
f0101aca:	c3                   	ret    

f0101acb <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0101acb:	55                   	push   %ebp
f0101acc:	89 e5                	mov    %esp,%ebp
f0101ace:	57                   	push   %edi
f0101acf:	56                   	push   %esi
f0101ad0:	53                   	push   %ebx
f0101ad1:	83 ec 2c             	sub    $0x2c,%esp
f0101ad4:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f0101ad7:	e8 87 22 00 00       	call   f0103d63 <cpunum>
f0101adc:	6b c0 74             	imul   $0x74,%eax,%eax
f0101adf:	39 b8 28 00 22 f0    	cmp    %edi,-0xfddffd8(%eax)
f0101ae5:	75 34                	jne    f0101b1b <env_free+0x50>
		lcr3(PADDR(kern_pgdir));
f0101ae7:	a1 0c ff 21 f0       	mov    0xf021ff0c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101aec:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101af1:	77 20                	ja     f0101b13 <env_free+0x48>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101af3:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101af7:	c7 44 24 08 a8 44 10 	movl   $0xf01044a8,0x8(%esp)
f0101afe:	f0 
f0101aff:	c7 44 24 04 a8 01 00 	movl   $0x1a8,0x4(%esp)
f0101b06:	00 
f0101b07:	c7 04 24 0d 4d 10 f0 	movl   $0xf0104d0d,(%esp)
f0101b0e:	e8 2d e5 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0101b13:	05 00 00 00 10       	add    $0x10000000,%eax
f0101b18:	0f 22 d8             	mov    %eax,%cr3

	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0101b1b:	8b 5f 48             	mov    0x48(%edi),%ebx
f0101b1e:	e8 40 22 00 00       	call   f0103d63 <cpunum>
f0101b23:	6b d0 74             	imul   $0x74,%eax,%edx
f0101b26:	b8 00 00 00 00       	mov    $0x0,%eax
f0101b2b:	83 ba 28 00 22 f0 00 	cmpl   $0x0,-0xfddffd8(%edx)
f0101b32:	74 11                	je     f0101b45 <env_free+0x7a>
f0101b34:	e8 2a 22 00 00       	call   f0103d63 <cpunum>
f0101b39:	6b c0 74             	imul   $0x74,%eax,%eax
f0101b3c:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0101b42:	8b 40 48             	mov    0x48(%eax),%eax
f0101b45:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0101b49:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101b4d:	c7 04 24 8c 4d 10 f0 	movl   $0xf0104d8c,(%esp)
f0101b54:	e8 1b 04 00 00       	call   f0101f74 <cprintf>

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0101b59:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0101b60:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0101b63:	89 c8                	mov    %ecx,%eax
f0101b65:	c1 e0 02             	shl    $0x2,%eax
f0101b68:	89 45 dc             	mov    %eax,-0x24(%ebp)

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f0101b6b:	8b 47 60             	mov    0x60(%edi),%eax
f0101b6e:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f0101b71:	f7 c6 01 00 00 00    	test   $0x1,%esi
f0101b77:	0f 84 b7 00 00 00    	je     f0101c34 <env_free+0x169>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f0101b7d:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101b83:	89 f0                	mov    %esi,%eax
f0101b85:	c1 e8 0c             	shr    $0xc,%eax
f0101b88:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0101b8b:	3b 05 08 ff 21 f0    	cmp    0xf021ff08,%eax
f0101b91:	72 20                	jb     f0101bb3 <env_free+0xe8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101b93:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0101b97:	c7 44 24 08 84 44 10 	movl   $0xf0104484,0x8(%esp)
f0101b9e:	f0 
f0101b9f:	c7 44 24 04 b7 01 00 	movl   $0x1b7,0x4(%esp)
f0101ba6:	00 
f0101ba7:	c7 04 24 0d 4d 10 f0 	movl   $0xf0104d0d,(%esp)
f0101bae:	e8 8d e4 ff ff       	call   f0100040 <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0101bb3:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0101bb6:	c1 e0 16             	shl    $0x16,%eax
f0101bb9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0101bbc:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f0101bc1:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f0101bc8:	01 
f0101bc9:	74 17                	je     f0101be2 <env_free+0x117>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0101bcb:	89 d8                	mov    %ebx,%eax
f0101bcd:	c1 e0 0c             	shl    $0xc,%eax
f0101bd0:	0b 45 e4             	or     -0x1c(%ebp),%eax
f0101bd3:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101bd7:	8b 47 60             	mov    0x60(%edi),%eax
f0101bda:	89 04 24             	mov    %eax,(%esp)
f0101bdd:	e8 04 f8 ff ff       	call   f01013e6 <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0101be2:	83 c3 01             	add    $0x1,%ebx
f0101be5:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f0101beb:	75 d4                	jne    f0101bc1 <env_free+0xf6>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f0101bed:	8b 47 60             	mov    0x60(%edi),%eax
f0101bf0:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0101bf3:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101bfa:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0101bfd:	3b 05 08 ff 21 f0    	cmp    0xf021ff08,%eax
f0101c03:	72 1c                	jb     f0101c21 <env_free+0x156>
		panic("pa2page called with invalid pa");
f0101c05:	c7 44 24 08 90 4a 10 	movl   $0xf0104a90,0x8(%esp)
f0101c0c:	f0 
f0101c0d:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101c14:	00 
f0101c15:	c7 04 24 29 4c 10 f0 	movl   $0xf0104c29,(%esp)
f0101c1c:	e8 1f e4 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0101c21:	a1 10 ff 21 f0       	mov    0xf021ff10,%eax
f0101c26:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0101c29:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0101c2c:	89 04 24             	mov    %eax,(%esp)
f0101c2f:	e8 e3 f5 ff ff       	call   f0101217 <page_decref>
	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0101c34:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f0101c38:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f0101c3f:	0f 85 1b ff ff ff    	jne    f0101b60 <env_free+0x95>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f0101c45:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101c48:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101c4d:	77 20                	ja     f0101c6f <env_free+0x1a4>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101c4f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101c53:	c7 44 24 08 a8 44 10 	movl   $0xf01044a8,0x8(%esp)
f0101c5a:	f0 
f0101c5b:	c7 44 24 04 c5 01 00 	movl   $0x1c5,0x4(%esp)
f0101c62:	00 
f0101c63:	c7 04 24 0d 4d 10 f0 	movl   $0xf0104d0d,(%esp)
f0101c6a:	e8 d1 e3 ff ff       	call   f0100040 <_panic>
	e->env_pgdir = 0;
f0101c6f:	c7 47 60 00 00 00 00 	movl   $0x0,0x60(%edi)
	return (physaddr_t)kva - KERNBASE;
f0101c76:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101c7b:	c1 e8 0c             	shr    $0xc,%eax
f0101c7e:	3b 05 08 ff 21 f0    	cmp    0xf021ff08,%eax
f0101c84:	72 1c                	jb     f0101ca2 <env_free+0x1d7>
		panic("pa2page called with invalid pa");
f0101c86:	c7 44 24 08 90 4a 10 	movl   $0xf0104a90,0x8(%esp)
f0101c8d:	f0 
f0101c8e:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101c95:	00 
f0101c96:	c7 04 24 29 4c 10 f0 	movl   $0xf0104c29,(%esp)
f0101c9d:	e8 9e e3 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0101ca2:	8b 15 10 ff 21 f0    	mov    0xf021ff10,%edx
f0101ca8:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f0101cab:	89 04 24             	mov    %eax,(%esp)
f0101cae:	e8 64 f5 ff ff       	call   f0101217 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f0101cb3:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f0101cba:	a1 4c f2 21 f0       	mov    0xf021f24c,%eax
f0101cbf:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f0101cc2:	89 3d 4c f2 21 f0    	mov    %edi,0xf021f24c
}
f0101cc8:	83 c4 2c             	add    $0x2c,%esp
f0101ccb:	5b                   	pop    %ebx
f0101ccc:	5e                   	pop    %esi
f0101ccd:	5f                   	pop    %edi
f0101cce:	5d                   	pop    %ebp
f0101ccf:	c3                   	ret    

f0101cd0 <env_destroy>:
// If e was the current env, then runs a new environment (and does not return
// to the caller).
//
void
env_destroy(struct Env *e)
{
f0101cd0:	55                   	push   %ebp
f0101cd1:	89 e5                	mov    %esp,%ebp
f0101cd3:	53                   	push   %ebx
f0101cd4:	83 ec 14             	sub    $0x14,%esp
f0101cd7:	8b 5d 08             	mov    0x8(%ebp),%ebx
	// If e is currently running on other CPUs, we change its state to
	// ENV_DYING. A zombie environment will be freed the next time
	// it traps to the kernel.
	if (e->env_status == ENV_RUNNING && curenv != e) {
f0101cda:	83 7b 54 03          	cmpl   $0x3,0x54(%ebx)
f0101cde:	75 19                	jne    f0101cf9 <env_destroy+0x29>
f0101ce0:	e8 7e 20 00 00       	call   f0103d63 <cpunum>
f0101ce5:	6b c0 74             	imul   $0x74,%eax,%eax
f0101ce8:	39 98 28 00 22 f0    	cmp    %ebx,-0xfddffd8(%eax)
f0101cee:	74 09                	je     f0101cf9 <env_destroy+0x29>
		e->env_status = ENV_DYING;
f0101cf0:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
		return;
f0101cf7:	eb 2f                	jmp    f0101d28 <env_destroy+0x58>
	}

	env_free(e);
f0101cf9:	89 1c 24             	mov    %ebx,(%esp)
f0101cfc:	e8 ca fd ff ff       	call   f0101acb <env_free>

	if (curenv == e) {
f0101d01:	e8 5d 20 00 00       	call   f0103d63 <cpunum>
f0101d06:	6b c0 74             	imul   $0x74,%eax,%eax
f0101d09:	39 98 28 00 22 f0    	cmp    %ebx,-0xfddffd8(%eax)
f0101d0f:	75 17                	jne    f0101d28 <env_destroy+0x58>
		curenv = NULL;
f0101d11:	e8 4d 20 00 00       	call   f0103d63 <cpunum>
f0101d16:	6b c0 74             	imul   $0x74,%eax,%eax
f0101d19:	c7 80 28 00 22 f0 00 	movl   $0x0,-0xfddffd8(%eax)
f0101d20:	00 00 00 
		sched_yield();
f0101d23:	e8 09 0b 00 00       	call   f0102831 <sched_yield>
	}
}
f0101d28:	83 c4 14             	add    $0x14,%esp
f0101d2b:	5b                   	pop    %ebx
f0101d2c:	5d                   	pop    %ebp
f0101d2d:	c3                   	ret    

f0101d2e <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f0101d2e:	55                   	push   %ebp
f0101d2f:	89 e5                	mov    %esp,%ebp
f0101d31:	53                   	push   %ebx
f0101d32:	83 ec 14             	sub    $0x14,%esp
	// Record the CPU we are running on for user-space debugging
	curenv->env_cpunum = cpunum();
f0101d35:	e8 29 20 00 00       	call   f0103d63 <cpunum>
f0101d3a:	6b c0 74             	imul   $0x74,%eax,%eax
f0101d3d:	8b 98 28 00 22 f0    	mov    -0xfddffd8(%eax),%ebx
f0101d43:	e8 1b 20 00 00       	call   f0103d63 <cpunum>
f0101d48:	89 43 5c             	mov    %eax,0x5c(%ebx)

	__asm __volatile("movl %0,%%esp\n"
f0101d4b:	8b 65 08             	mov    0x8(%ebp),%esp
f0101d4e:	61                   	popa   
f0101d4f:	07                   	pop    %es
f0101d50:	1f                   	pop    %ds
f0101d51:	83 c4 08             	add    $0x8,%esp
f0101d54:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f0101d55:	c7 44 24 08 a2 4d 10 	movl   $0xf0104da2,0x8(%esp)
f0101d5c:	f0 
f0101d5d:	c7 44 24 04 fb 01 00 	movl   $0x1fb,0x4(%esp)
f0101d64:	00 
f0101d65:	c7 04 24 0d 4d 10 f0 	movl   $0xf0104d0d,(%esp)
f0101d6c:	e8 cf e2 ff ff       	call   f0100040 <_panic>

f0101d71 <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0101d71:	55                   	push   %ebp
f0101d72:	89 e5                	mov    %esp,%ebp
f0101d74:	53                   	push   %ebx
f0101d75:	83 ec 14             	sub    $0x14,%esp
f0101d78:	8b 5d 08             	mov    0x8(%ebp),%ebx

	// Hint: This function loads the new environment's state from
	//	e->env_tf.  Go back through the code you wrote above
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.
	if(curenv!=NULL&& curenv->env_status==ENV_RUNNING)
f0101d7b:	e8 e3 1f 00 00       	call   f0103d63 <cpunum>
f0101d80:	6b c0 74             	imul   $0x74,%eax,%eax
f0101d83:	83 b8 28 00 22 f0 00 	cmpl   $0x0,-0xfddffd8(%eax)
f0101d8a:	74 29                	je     f0101db5 <env_run+0x44>
f0101d8c:	e8 d2 1f 00 00       	call   f0103d63 <cpunum>
f0101d91:	6b c0 74             	imul   $0x74,%eax,%eax
f0101d94:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0101d9a:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0101d9e:	75 15                	jne    f0101db5 <env_run+0x44>
		curenv->env_status = ENV_RUNNABLE;
f0101da0:	e8 be 1f 00 00       	call   f0103d63 <cpunum>
f0101da5:	6b c0 74             	imul   $0x74,%eax,%eax
f0101da8:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0101dae:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)

	curenv = e;
f0101db5:	e8 a9 1f 00 00       	call   f0103d63 <cpunum>
f0101dba:	6b c0 74             	imul   $0x74,%eax,%eax
f0101dbd:	89 98 28 00 22 f0    	mov    %ebx,-0xfddffd8(%eax)
	int zero = 0;
	e->env_status = ENV_RUNNING;
f0101dc3:	c7 43 54 03 00 00 00 	movl   $0x3,0x54(%ebx)
	e->env_runs++;
f0101dca:	83 43 58 01          	addl   $0x1,0x58(%ebx)
	lcr3(PADDR(e->env_pgdir));
f0101dce:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101dd1:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101dd6:	77 20                	ja     f0101df8 <env_run+0x87>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101dd8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101ddc:	c7 44 24 08 a8 44 10 	movl   $0xf01044a8,0x8(%esp)
f0101de3:	f0 
f0101de4:	c7 44 24 04 1e 02 00 	movl   $0x21e,0x4(%esp)
f0101deb:	00 
f0101dec:	c7 04 24 0d 4d 10 f0 	movl   $0xf0104d0d,(%esp)
f0101df3:	e8 48 e2 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0101df8:	05 00 00 00 10       	add    $0x10000000,%eax
f0101dfd:	0f 22 d8             	mov    %eax,%cr3
	env_pop_tf(&e->env_tf);
f0101e00:	89 1c 24             	mov    %ebx,(%esp)
f0101e03:	e8 26 ff ff ff       	call   f0101d2e <env_pop_tf>

f0101e08 <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0101e08:	55                   	push   %ebp
f0101e09:	89 e5                	mov    %esp,%ebp
f0101e0b:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0101e0f:	ba 70 00 00 00       	mov    $0x70,%edx
f0101e14:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0101e15:	b2 71                	mov    $0x71,%dl
f0101e17:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0101e18:	0f b6 c0             	movzbl %al,%eax
}
f0101e1b:	5d                   	pop    %ebp
f0101e1c:	c3                   	ret    

f0101e1d <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0101e1d:	55                   	push   %ebp
f0101e1e:	89 e5                	mov    %esp,%ebp
f0101e20:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0101e24:	ba 70 00 00 00       	mov    $0x70,%edx
f0101e29:	ee                   	out    %al,(%dx)
f0101e2a:	b2 71                	mov    $0x71,%dl
f0101e2c:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101e2f:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0101e30:	5d                   	pop    %ebp
f0101e31:	c3                   	ret    

f0101e32 <irq_setmask_8259A>:
		irq_setmask_8259A(irq_mask_8259A);
}

void
irq_setmask_8259A(uint16_t mask)
{
f0101e32:	55                   	push   %ebp
f0101e33:	89 e5                	mov    %esp,%ebp
f0101e35:	56                   	push   %esi
f0101e36:	53                   	push   %ebx
f0101e37:	83 ec 10             	sub    $0x10,%esp
f0101e3a:	8b 45 08             	mov    0x8(%ebp),%eax
	int i;
	irq_mask_8259A = mask;
f0101e3d:	66 a3 88 c3 11 f0    	mov    %ax,0xf011c388
	if (!didinit)
f0101e43:	83 3d 50 f2 21 f0 00 	cmpl   $0x0,0xf021f250
f0101e4a:	74 4e                	je     f0101e9a <irq_setmask_8259A+0x68>
f0101e4c:	89 c6                	mov    %eax,%esi
f0101e4e:	ba 21 00 00 00       	mov    $0x21,%edx
f0101e53:	ee                   	out    %al,(%dx)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
f0101e54:	66 c1 e8 08          	shr    $0x8,%ax
f0101e58:	b2 a1                	mov    $0xa1,%dl
f0101e5a:	ee                   	out    %al,(%dx)
	cprintf("enabled interrupts:");
f0101e5b:	c7 04 24 ae 4d 10 f0 	movl   $0xf0104dae,(%esp)
f0101e62:	e8 0d 01 00 00       	call   f0101f74 <cprintf>
	for (i = 0; i < 16; i++)
f0101e67:	bb 00 00 00 00       	mov    $0x0,%ebx
		if (~mask & (1<<i))
f0101e6c:	0f b7 f6             	movzwl %si,%esi
f0101e6f:	f7 d6                	not    %esi
f0101e71:	0f a3 de             	bt     %ebx,%esi
f0101e74:	73 10                	jae    f0101e86 <irq_setmask_8259A+0x54>
			cprintf(" %d", i);
f0101e76:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101e7a:	c7 04 24 79 52 10 f0 	movl   $0xf0105279,(%esp)
f0101e81:	e8 ee 00 00 00       	call   f0101f74 <cprintf>
	if (!didinit)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
	cprintf("enabled interrupts:");
	for (i = 0; i < 16; i++)
f0101e86:	83 c3 01             	add    $0x1,%ebx
f0101e89:	83 fb 10             	cmp    $0x10,%ebx
f0101e8c:	75 e3                	jne    f0101e71 <irq_setmask_8259A+0x3f>
		if (~mask & (1<<i))
			cprintf(" %d", i);
	cprintf("\n");
f0101e8e:	c7 04 24 e1 4c 10 f0 	movl   $0xf0104ce1,(%esp)
f0101e95:	e8 da 00 00 00       	call   f0101f74 <cprintf>
}
f0101e9a:	83 c4 10             	add    $0x10,%esp
f0101e9d:	5b                   	pop    %ebx
f0101e9e:	5e                   	pop    %esi
f0101e9f:	5d                   	pop    %ebp
f0101ea0:	c3                   	ret    

f0101ea1 <pic_init>:

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
	didinit = 1;
f0101ea1:	c7 05 50 f2 21 f0 01 	movl   $0x1,0xf021f250
f0101ea8:	00 00 00 
f0101eab:	ba 21 00 00 00       	mov    $0x21,%edx
f0101eb0:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0101eb5:	ee                   	out    %al,(%dx)
f0101eb6:	b2 a1                	mov    $0xa1,%dl
f0101eb8:	ee                   	out    %al,(%dx)
f0101eb9:	b2 20                	mov    $0x20,%dl
f0101ebb:	b8 11 00 00 00       	mov    $0x11,%eax
f0101ec0:	ee                   	out    %al,(%dx)
f0101ec1:	b2 21                	mov    $0x21,%dl
f0101ec3:	b8 20 00 00 00       	mov    $0x20,%eax
f0101ec8:	ee                   	out    %al,(%dx)
f0101ec9:	b8 04 00 00 00       	mov    $0x4,%eax
f0101ece:	ee                   	out    %al,(%dx)
f0101ecf:	b8 03 00 00 00       	mov    $0x3,%eax
f0101ed4:	ee                   	out    %al,(%dx)
f0101ed5:	b2 a0                	mov    $0xa0,%dl
f0101ed7:	b8 11 00 00 00       	mov    $0x11,%eax
f0101edc:	ee                   	out    %al,(%dx)
f0101edd:	b2 a1                	mov    $0xa1,%dl
f0101edf:	b8 28 00 00 00       	mov    $0x28,%eax
f0101ee4:	ee                   	out    %al,(%dx)
f0101ee5:	b8 02 00 00 00       	mov    $0x2,%eax
f0101eea:	ee                   	out    %al,(%dx)
f0101eeb:	b8 01 00 00 00       	mov    $0x1,%eax
f0101ef0:	ee                   	out    %al,(%dx)
f0101ef1:	b2 20                	mov    $0x20,%dl
f0101ef3:	b8 68 00 00 00       	mov    $0x68,%eax
f0101ef8:	ee                   	out    %al,(%dx)
f0101ef9:	b8 0a 00 00 00       	mov    $0xa,%eax
f0101efe:	ee                   	out    %al,(%dx)
f0101eff:	b2 a0                	mov    $0xa0,%dl
f0101f01:	b8 68 00 00 00       	mov    $0x68,%eax
f0101f06:	ee                   	out    %al,(%dx)
f0101f07:	b8 0a 00 00 00       	mov    $0xa,%eax
f0101f0c:	ee                   	out    %al,(%dx)
	outb(IO_PIC1, 0x0a);             /* read IRR by default */

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
f0101f0d:	0f b7 05 88 c3 11 f0 	movzwl 0xf011c388,%eax
f0101f14:	66 83 f8 ff          	cmp    $0xffff,%ax
f0101f18:	74 12                	je     f0101f2c <pic_init+0x8b>
static bool didinit;

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
f0101f1a:	55                   	push   %ebp
f0101f1b:	89 e5                	mov    %esp,%ebp
f0101f1d:	83 ec 18             	sub    $0x18,%esp

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
		irq_setmask_8259A(irq_mask_8259A);
f0101f20:	0f b7 c0             	movzwl %ax,%eax
f0101f23:	89 04 24             	mov    %eax,(%esp)
f0101f26:	e8 07 ff ff ff       	call   f0101e32 <irq_setmask_8259A>
}
f0101f2b:	c9                   	leave  
f0101f2c:	f3 c3                	repz ret 

f0101f2e <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0101f2e:	55                   	push   %ebp
f0101f2f:	89 e5                	mov    %esp,%ebp
f0101f31:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0101f34:	8b 45 08             	mov    0x8(%ebp),%eax
f0101f37:	89 04 24             	mov    %eax,(%esp)
f0101f3a:	e8 7e e8 ff ff       	call   f01007bd <cputchar>
	*cnt++;
}
f0101f3f:	c9                   	leave  
f0101f40:	c3                   	ret    

f0101f41 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0101f41:	55                   	push   %ebp
f0101f42:	89 e5                	mov    %esp,%ebp
f0101f44:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0101f47:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0101f4e:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101f51:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101f55:	8b 45 08             	mov    0x8(%ebp),%eax
f0101f58:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101f5c:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0101f5f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101f63:	c7 04 24 2e 1f 10 f0 	movl   $0xf0101f2e,(%esp)
f0101f6a:	e8 15 10 00 00       	call   f0102f84 <vprintfmt>
	return cnt;
}
f0101f6f:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101f72:	c9                   	leave  
f0101f73:	c3                   	ret    

f0101f74 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0101f74:	55                   	push   %ebp
f0101f75:	89 e5                	mov    %esp,%ebp
f0101f77:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0101f7a:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0101f7d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101f81:	8b 45 08             	mov    0x8(%ebp),%eax
f0101f84:	89 04 24             	mov    %eax,(%esp)
f0101f87:	e8 b5 ff ff ff       	call   f0101f41 <vcprintf>
	va_end(ap);

	return cnt;
}
f0101f8c:	c9                   	leave  
f0101f8d:	c3                   	ret    
f0101f8e:	66 90                	xchg   %ax,%ax

f0101f90 <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f0101f90:	55                   	push   %ebp
f0101f91:	89 e5                	mov    %esp,%ebp
	//
	// LAB 4: Your code here:

	// Setup a TSS so that we get the right stack
	// when we trap to the kernel.
	ts.ts_esp0 = KSTACKTOP;
f0101f93:	c7 05 84 fa 21 f0 00 	movl   $0xefc00000,0xf021fa84
f0101f9a:	00 c0 ef 
	ts.ts_ss0 = GD_KD;
f0101f9d:	66 c7 05 88 fa 21 f0 	movw   $0x10,0xf021fa88
f0101fa4:	10 00 

	// Initialize the TSS slot of the gdt.
	gdt[GD_TSS0 >> 3] = SEG16(STS_T32A, (uint32_t) (&ts),
f0101fa6:	66 c7 05 48 c3 11 f0 	movw   $0x68,0xf011c348
f0101fad:	68 00 
f0101faf:	b8 80 fa 21 f0       	mov    $0xf021fa80,%eax
f0101fb4:	66 a3 4a c3 11 f0    	mov    %ax,0xf011c34a
f0101fba:	89 c2                	mov    %eax,%edx
f0101fbc:	c1 ea 10             	shr    $0x10,%edx
f0101fbf:	88 15 4c c3 11 f0    	mov    %dl,0xf011c34c
f0101fc5:	c6 05 4e c3 11 f0 40 	movb   $0x40,0xf011c34e
f0101fcc:	c1 e8 18             	shr    $0x18,%eax
f0101fcf:	a2 4f c3 11 f0       	mov    %al,0xf011c34f
					sizeof(struct Taskstate), 0);
	gdt[GD_TSS0 >> 3].sd_s = 0;
f0101fd4:	c6 05 4d c3 11 f0 89 	movb   $0x89,0xf011c34d
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f0101fdb:	b8 28 00 00 00       	mov    $0x28,%eax
f0101fe0:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f0101fe3:	b8 8a c3 11 f0       	mov    $0xf011c38a,%eax
f0101fe8:	0f 01 18             	lidtl  (%eax)
	// bottom three bits are special; we leave them 0)
	ltr(GD_TSS0);

	// Load the IDT
	lidt(&idt_pd);
}
f0101feb:	5d                   	pop    %ebp
f0101fec:	c3                   	ret    

f0101fed <trap_init>:
}


void
trap_init(void)
{
f0101fed:	55                   	push   %ebp
f0101fee:	89 e5                	mov    %esp,%ebp
	extern struct Segdesc gdt[];
	SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);
f0101ff0:	b8 ba 27 10 f0       	mov    $0xf01027ba,%eax
f0101ff5:	66 a3 60 f2 21 f0    	mov    %ax,0xf021f260
f0101ffb:	66 c7 05 62 f2 21 f0 	movw   $0x8,0xf021f262
f0102002:	08 00 
f0102004:	c6 05 64 f2 21 f0 00 	movb   $0x0,0xf021f264
f010200b:	c6 05 65 f2 21 f0 8f 	movb   $0x8f,0xf021f265
f0102012:	c1 e8 10             	shr    $0x10,%eax
f0102015:	66 a3 66 f2 21 f0    	mov    %ax,0xf021f266
	SETGATE(idt[2], 0, GD_KT, nmi_handler, 0);
f010201b:	b8 c0 27 10 f0       	mov    $0xf01027c0,%eax
f0102020:	66 a3 70 f2 21 f0    	mov    %ax,0xf021f270
f0102026:	66 c7 05 72 f2 21 f0 	movw   $0x8,0xf021f272
f010202d:	08 00 
f010202f:	c6 05 74 f2 21 f0 00 	movb   $0x0,0xf021f274
f0102036:	c6 05 75 f2 21 f0 8e 	movb   $0x8e,0xf021f275
f010203d:	c1 e8 10             	shr    $0x10,%eax
f0102040:	66 a3 76 f2 21 f0    	mov    %ax,0xf021f276
	SETGATE(idt[3], 1, GD_KT, breakpoint_handler, 3);
f0102046:	b8 c6 27 10 f0       	mov    $0xf01027c6,%eax
f010204b:	66 a3 78 f2 21 f0    	mov    %ax,0xf021f278
f0102051:	66 c7 05 7a f2 21 f0 	movw   $0x8,0xf021f27a
f0102058:	08 00 
f010205a:	c6 05 7c f2 21 f0 00 	movb   $0x0,0xf021f27c
f0102061:	c6 05 7d f2 21 f0 ef 	movb   $0xef,0xf021f27d
f0102068:	c1 e8 10             	shr    $0x10,%eax
f010206b:	66 a3 7e f2 21 f0    	mov    %ax,0xf021f27e
	SETGATE(idt[4], 1, GD_KT, overflow_handler, 3);
f0102071:	b8 cc 27 10 f0       	mov    $0xf01027cc,%eax
f0102076:	66 a3 80 f2 21 f0    	mov    %ax,0xf021f280
f010207c:	66 c7 05 82 f2 21 f0 	movw   $0x8,0xf021f282
f0102083:	08 00 
f0102085:	c6 05 84 f2 21 f0 00 	movb   $0x0,0xf021f284
f010208c:	c6 05 85 f2 21 f0 ef 	movb   $0xef,0xf021f285
f0102093:	c1 e8 10             	shr    $0x10,%eax
f0102096:	66 a3 86 f2 21 f0    	mov    %ax,0xf021f286
	SETGATE(idt[5], 1, GD_KT, bdrgeexceed_handler, 3);
f010209c:	b8 d2 27 10 f0       	mov    $0xf01027d2,%eax
f01020a1:	66 a3 88 f2 21 f0    	mov    %ax,0xf021f288
f01020a7:	66 c7 05 8a f2 21 f0 	movw   $0x8,0xf021f28a
f01020ae:	08 00 
f01020b0:	c6 05 8c f2 21 f0 00 	movb   $0x0,0xf021f28c
f01020b7:	c6 05 8d f2 21 f0 ef 	movb   $0xef,0xf021f28d
f01020be:	c1 e8 10             	shr    $0x10,%eax
f01020c1:	66 a3 8e f2 21 f0    	mov    %ax,0xf021f28e
	SETGATE(idt[6], 1, GD_KT, invalidop_handler, 0);
f01020c7:	b8 d8 27 10 f0       	mov    $0xf01027d8,%eax
f01020cc:	66 a3 90 f2 21 f0    	mov    %ax,0xf021f290
f01020d2:	66 c7 05 92 f2 21 f0 	movw   $0x8,0xf021f292
f01020d9:	08 00 
f01020db:	c6 05 94 f2 21 f0 00 	movb   $0x0,0xf021f294
f01020e2:	c6 05 95 f2 21 f0 8f 	movb   $0x8f,0xf021f295
f01020e9:	c1 e8 10             	shr    $0x10,%eax
f01020ec:	66 a3 96 f2 21 f0    	mov    %ax,0xf021f296
	SETGATE(idt[7], 1, GD_KT, nomathcopro_handler, 0);
f01020f2:	b8 de 27 10 f0       	mov    $0xf01027de,%eax
f01020f7:	66 a3 98 f2 21 f0    	mov    %ax,0xf021f298
f01020fd:	66 c7 05 9a f2 21 f0 	movw   $0x8,0xf021f29a
f0102104:	08 00 
f0102106:	c6 05 9c f2 21 f0 00 	movb   $0x0,0xf021f29c
f010210d:	c6 05 9d f2 21 f0 8f 	movb   $0x8f,0xf021f29d
f0102114:	c1 e8 10             	shr    $0x10,%eax
f0102117:	66 a3 9e f2 21 f0    	mov    %ax,0xf021f29e
	SETGATE(idt[8], 1, GD_KT, dbfault_handler, 0);
f010211d:	b8 e4 27 10 f0       	mov    $0xf01027e4,%eax
f0102122:	66 a3 a0 f2 21 f0    	mov    %ax,0xf021f2a0
f0102128:	66 c7 05 a2 f2 21 f0 	movw   $0x8,0xf021f2a2
f010212f:	08 00 
f0102131:	c6 05 a4 f2 21 f0 00 	movb   $0x0,0xf021f2a4
f0102138:	c6 05 a5 f2 21 f0 8f 	movb   $0x8f,0xf021f2a5
f010213f:	c1 e8 10             	shr    $0x10,%eax
f0102142:	66 a3 a6 f2 21 f0    	mov    %ax,0xf021f2a6
	SETGATE(idt[10], 1, GD_KT, invalidTSS_handler, 0);
f0102148:	b8 e8 27 10 f0       	mov    $0xf01027e8,%eax
f010214d:	66 a3 b0 f2 21 f0    	mov    %ax,0xf021f2b0
f0102153:	66 c7 05 b2 f2 21 f0 	movw   $0x8,0xf021f2b2
f010215a:	08 00 
f010215c:	c6 05 b4 f2 21 f0 00 	movb   $0x0,0xf021f2b4
f0102163:	c6 05 b5 f2 21 f0 8f 	movb   $0x8f,0xf021f2b5
f010216a:	c1 e8 10             	shr    $0x10,%eax
f010216d:	66 a3 b6 f2 21 f0    	mov    %ax,0xf021f2b6

	SETGATE(idt[11], 1, GD_KT, sgmtnotpresent_handler, 0);
f0102173:	b8 ec 27 10 f0       	mov    $0xf01027ec,%eax
f0102178:	66 a3 b8 f2 21 f0    	mov    %ax,0xf021f2b8
f010217e:	66 c7 05 ba f2 21 f0 	movw   $0x8,0xf021f2ba
f0102185:	08 00 
f0102187:	c6 05 bc f2 21 f0 00 	movb   $0x0,0xf021f2bc
f010218e:	c6 05 bd f2 21 f0 8f 	movb   $0x8f,0xf021f2bd
f0102195:	c1 e8 10             	shr    $0x10,%eax
f0102198:	66 a3 be f2 21 f0    	mov    %ax,0xf021f2be
	SETGATE(idt[12], 1, GD_KT, stacksgmtfault_handler, 0);
f010219e:	b8 f0 27 10 f0       	mov    $0xf01027f0,%eax
f01021a3:	66 a3 c0 f2 21 f0    	mov    %ax,0xf021f2c0
f01021a9:	66 c7 05 c2 f2 21 f0 	movw   $0x8,0xf021f2c2
f01021b0:	08 00 
f01021b2:	c6 05 c4 f2 21 f0 00 	movb   $0x0,0xf021f2c4
f01021b9:	c6 05 c5 f2 21 f0 8f 	movb   $0x8f,0xf021f2c5
f01021c0:	c1 e8 10             	shr    $0x10,%eax
f01021c3:	66 a3 c6 f2 21 f0    	mov    %ax,0xf021f2c6
	SETGATE(idt[14], 1, GD_KT, pagefault_handler, 0);
f01021c9:	b8 f8 27 10 f0       	mov    $0xf01027f8,%eax
f01021ce:	66 a3 d0 f2 21 f0    	mov    %ax,0xf021f2d0
f01021d4:	66 c7 05 d2 f2 21 f0 	movw   $0x8,0xf021f2d2
f01021db:	08 00 
f01021dd:	c6 05 d4 f2 21 f0 00 	movb   $0x0,0xf021f2d4
f01021e4:	c6 05 d5 f2 21 f0 8f 	movb   $0x8f,0xf021f2d5
f01021eb:	c1 e8 10             	shr    $0x10,%eax
f01021ee:	66 a3 d6 f2 21 f0    	mov    %ax,0xf021f2d6
	SETGATE(idt[13], 1, GD_KT, generalprotection_handler, 0);
f01021f4:	b8 f4 27 10 f0       	mov    $0xf01027f4,%eax
f01021f9:	66 a3 c8 f2 21 f0    	mov    %ax,0xf021f2c8
f01021ff:	66 c7 05 ca f2 21 f0 	movw   $0x8,0xf021f2ca
f0102206:	08 00 
f0102208:	c6 05 cc f2 21 f0 00 	movb   $0x0,0xf021f2cc
f010220f:	c6 05 cd f2 21 f0 8f 	movb   $0x8f,0xf021f2cd
f0102216:	c1 e8 10             	shr    $0x10,%eax
f0102219:	66 a3 ce f2 21 f0    	mov    %ax,0xf021f2ce
	SETGATE(idt[16], 1, GD_KT, FPUerror_handler, 0);
f010221f:	b8 fc 27 10 f0       	mov    $0xf01027fc,%eax
f0102224:	66 a3 e0 f2 21 f0    	mov    %ax,0xf021f2e0
f010222a:	66 c7 05 e2 f2 21 f0 	movw   $0x8,0xf021f2e2
f0102231:	08 00 
f0102233:	c6 05 e4 f2 21 f0 00 	movb   $0x0,0xf021f2e4
f010223a:	c6 05 e5 f2 21 f0 8f 	movb   $0x8f,0xf021f2e5
f0102241:	c1 e8 10             	shr    $0x10,%eax
f0102244:	66 a3 e6 f2 21 f0    	mov    %ax,0xf021f2e6
	SETGATE(idt[17], 1, GD_KT, alignmentcheck_handler, 0);
f010224a:	b8 02 28 10 f0       	mov    $0xf0102802,%eax
f010224f:	66 a3 e8 f2 21 f0    	mov    %ax,0xf021f2e8
f0102255:	66 c7 05 ea f2 21 f0 	movw   $0x8,0xf021f2ea
f010225c:	08 00 
f010225e:	c6 05 ec f2 21 f0 00 	movb   $0x0,0xf021f2ec
f0102265:	c6 05 ed f2 21 f0 8f 	movb   $0x8f,0xf021f2ed
f010226c:	c1 e8 10             	shr    $0x10,%eax
f010226f:	66 a3 ee f2 21 f0    	mov    %ax,0xf021f2ee
	SETGATE(idt[18],1, GD_KT, machinecheck_handler, 0);
f0102275:	b8 06 28 10 f0       	mov    $0xf0102806,%eax
f010227a:	66 a3 f0 f2 21 f0    	mov    %ax,0xf021f2f0
f0102280:	66 c7 05 f2 f2 21 f0 	movw   $0x8,0xf021f2f2
f0102287:	08 00 
f0102289:	c6 05 f4 f2 21 f0 00 	movb   $0x0,0xf021f2f4
f0102290:	c6 05 f5 f2 21 f0 8f 	movb   $0x8f,0xf021f2f5
f0102297:	c1 e8 10             	shr    $0x10,%eax
f010229a:	66 a3 f6 f2 21 f0    	mov    %ax,0xf021f2f6
	SETGATE(idt[19], 1, GD_KT, SIMDFPexception_handler, 0);
f01022a0:	b8 0c 28 10 f0       	mov    $0xf010280c,%eax
f01022a5:	66 a3 f8 f2 21 f0    	mov    %ax,0xf021f2f8
f01022ab:	66 c7 05 fa f2 21 f0 	movw   $0x8,0xf021f2fa
f01022b2:	08 00 
f01022b4:	c6 05 fc f2 21 f0 00 	movb   $0x0,0xf021f2fc
f01022bb:	c6 05 fd f2 21 f0 8f 	movb   $0x8f,0xf021f2fd
f01022c2:	c1 e8 10             	shr    $0x10,%eax
f01022c5:	66 a3 fe f2 21 f0    	mov    %ax,0xf021f2fe
	SETGATE(idt[48], 0, GD_KT, systemcall_handler, 3);
f01022cb:	b8 12 28 10 f0       	mov    $0xf0102812,%eax
f01022d0:	66 a3 e0 f3 21 f0    	mov    %ax,0xf021f3e0
f01022d6:	66 c7 05 e2 f3 21 f0 	movw   $0x8,0xf021f3e2
f01022dd:	08 00 
f01022df:	c6 05 e4 f3 21 f0 00 	movb   $0x0,0xf021f3e4
f01022e6:	c6 05 e5 f3 21 f0 ee 	movb   $0xee,0xf021f3e5
f01022ed:	c1 e8 10             	shr    $0x10,%eax
f01022f0:	66 a3 e6 f3 21 f0    	mov    %ax,0xf021f3e6
	// LAB 3: Your code here.

	// Per-CPU setup 
	trap_init_percpu();
f01022f6:	e8 95 fc ff ff       	call   f0101f90 <trap_init_percpu>
}
f01022fb:	5d                   	pop    %ebp
f01022fc:	c3                   	ret    

f01022fd <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f01022fd:	55                   	push   %ebp
f01022fe:	89 e5                	mov    %esp,%ebp
f0102300:	53                   	push   %ebx
f0102301:	83 ec 14             	sub    $0x14,%esp
f0102304:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f0102307:	8b 03                	mov    (%ebx),%eax
f0102309:	89 44 24 04          	mov    %eax,0x4(%esp)
f010230d:	c7 04 24 c2 4d 10 f0 	movl   $0xf0104dc2,(%esp)
f0102314:	e8 5b fc ff ff       	call   f0101f74 <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f0102319:	8b 43 04             	mov    0x4(%ebx),%eax
f010231c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102320:	c7 04 24 d1 4d 10 f0 	movl   $0xf0104dd1,(%esp)
f0102327:	e8 48 fc ff ff       	call   f0101f74 <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f010232c:	8b 43 08             	mov    0x8(%ebx),%eax
f010232f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102333:	c7 04 24 e0 4d 10 f0 	movl   $0xf0104de0,(%esp)
f010233a:	e8 35 fc ff ff       	call   f0101f74 <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f010233f:	8b 43 0c             	mov    0xc(%ebx),%eax
f0102342:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102346:	c7 04 24 ef 4d 10 f0 	movl   $0xf0104def,(%esp)
f010234d:	e8 22 fc ff ff       	call   f0101f74 <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f0102352:	8b 43 10             	mov    0x10(%ebx),%eax
f0102355:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102359:	c7 04 24 fe 4d 10 f0 	movl   $0xf0104dfe,(%esp)
f0102360:	e8 0f fc ff ff       	call   f0101f74 <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0102365:	8b 43 14             	mov    0x14(%ebx),%eax
f0102368:	89 44 24 04          	mov    %eax,0x4(%esp)
f010236c:	c7 04 24 0d 4e 10 f0 	movl   $0xf0104e0d,(%esp)
f0102373:	e8 fc fb ff ff       	call   f0101f74 <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f0102378:	8b 43 18             	mov    0x18(%ebx),%eax
f010237b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010237f:	c7 04 24 1c 4e 10 f0 	movl   $0xf0104e1c,(%esp)
f0102386:	e8 e9 fb ff ff       	call   f0101f74 <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f010238b:	8b 43 1c             	mov    0x1c(%ebx),%eax
f010238e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102392:	c7 04 24 2b 4e 10 f0 	movl   $0xf0104e2b,(%esp)
f0102399:	e8 d6 fb ff ff       	call   f0101f74 <cprintf>
}
f010239e:	83 c4 14             	add    $0x14,%esp
f01023a1:	5b                   	pop    %ebx
f01023a2:	5d                   	pop    %ebp
f01023a3:	c3                   	ret    

f01023a4 <print_trapframe>:
	lidt(&idt_pd);
}

void
print_trapframe(struct Trapframe *tf)
{
f01023a4:	55                   	push   %ebp
f01023a5:	89 e5                	mov    %esp,%ebp
f01023a7:	56                   	push   %esi
f01023a8:	53                   	push   %ebx
f01023a9:	83 ec 10             	sub    $0x10,%esp
f01023ac:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
f01023af:	e8 af 19 00 00       	call   f0103d63 <cpunum>
f01023b4:	89 44 24 08          	mov    %eax,0x8(%esp)
f01023b8:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01023bc:	c7 04 24 8f 4e 10 f0 	movl   $0xf0104e8f,(%esp)
f01023c3:	e8 ac fb ff ff       	call   f0101f74 <cprintf>
	print_regs(&tf->tf_regs);
f01023c8:	89 1c 24             	mov    %ebx,(%esp)
f01023cb:	e8 2d ff ff ff       	call   f01022fd <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f01023d0:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f01023d4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01023d8:	c7 04 24 ad 4e 10 f0 	movl   $0xf0104ead,(%esp)
f01023df:	e8 90 fb ff ff       	call   f0101f74 <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f01023e4:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f01023e8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01023ec:	c7 04 24 c0 4e 10 f0 	movl   $0xf0104ec0,(%esp)
f01023f3:	e8 7c fb ff ff       	call   f0101f74 <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f01023f8:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f01023fb:	83 f8 13             	cmp    $0x13,%eax
f01023fe:	77 09                	ja     f0102409 <print_trapframe+0x65>
		return excnames[trapno];
f0102400:	8b 14 85 80 51 10 f0 	mov    -0xfefae80(,%eax,4),%edx
f0102407:	eb 1f                	jmp    f0102428 <print_trapframe+0x84>
	if (trapno == T_SYSCALL)
f0102409:	83 f8 30             	cmp    $0x30,%eax
f010240c:	74 15                	je     f0102423 <print_trapframe+0x7f>
		return "System call";
	if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16)
f010240e:	8d 50 e0             	lea    -0x20(%eax),%edx
		return "Hardware Interrupt";
f0102411:	83 fa 0f             	cmp    $0xf,%edx
f0102414:	ba 46 4e 10 f0       	mov    $0xf0104e46,%edx
f0102419:	b9 59 4e 10 f0       	mov    $0xf0104e59,%ecx
f010241e:	0f 47 d1             	cmova  %ecx,%edx
f0102421:	eb 05                	jmp    f0102428 <print_trapframe+0x84>
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
		return excnames[trapno];
	if (trapno == T_SYSCALL)
		return "System call";
f0102423:	ba 3a 4e 10 f0       	mov    $0xf0104e3a,%edx
{
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0102428:	89 54 24 08          	mov    %edx,0x8(%esp)
f010242c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102430:	c7 04 24 d3 4e 10 f0 	movl   $0xf0104ed3,(%esp)
f0102437:	e8 38 fb ff ff       	call   f0101f74 <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f010243c:	3b 1d 60 fa 21 f0    	cmp    0xf021fa60,%ebx
f0102442:	75 19                	jne    f010245d <print_trapframe+0xb9>
f0102444:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0102448:	75 13                	jne    f010245d <print_trapframe+0xb9>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f010244a:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f010244d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102451:	c7 04 24 e5 4e 10 f0 	movl   $0xf0104ee5,(%esp)
f0102458:	e8 17 fb ff ff       	call   f0101f74 <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f010245d:	8b 43 2c             	mov    0x2c(%ebx),%eax
f0102460:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102464:	c7 04 24 f4 4e 10 f0 	movl   $0xf0104ef4,(%esp)
f010246b:	e8 04 fb ff ff       	call   f0101f74 <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f0102470:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0102474:	75 51                	jne    f01024c7 <print_trapframe+0x123>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f0102476:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f0102479:	89 c2                	mov    %eax,%edx
f010247b:	83 e2 01             	and    $0x1,%edx
f010247e:	ba 68 4e 10 f0       	mov    $0xf0104e68,%edx
f0102483:	b9 73 4e 10 f0       	mov    $0xf0104e73,%ecx
f0102488:	0f 45 ca             	cmovne %edx,%ecx
f010248b:	89 c2                	mov    %eax,%edx
f010248d:	83 e2 02             	and    $0x2,%edx
f0102490:	ba 7f 4e 10 f0       	mov    $0xf0104e7f,%edx
f0102495:	be 85 4e 10 f0       	mov    $0xf0104e85,%esi
f010249a:	0f 44 d6             	cmove  %esi,%edx
f010249d:	83 e0 04             	and    $0x4,%eax
f01024a0:	b8 8a 4e 10 f0       	mov    $0xf0104e8a,%eax
f01024a5:	be f4 4f 10 f0       	mov    $0xf0104ff4,%esi
f01024aa:	0f 44 c6             	cmove  %esi,%eax
f01024ad:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01024b1:	89 54 24 08          	mov    %edx,0x8(%esp)
f01024b5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01024b9:	c7 04 24 02 4f 10 f0 	movl   $0xf0104f02,(%esp)
f01024c0:	e8 af fa ff ff       	call   f0101f74 <cprintf>
f01024c5:	eb 0c                	jmp    f01024d3 <print_trapframe+0x12f>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f01024c7:	c7 04 24 e1 4c 10 f0 	movl   $0xf0104ce1,(%esp)
f01024ce:	e8 a1 fa ff ff       	call   f0101f74 <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f01024d3:	8b 43 30             	mov    0x30(%ebx),%eax
f01024d6:	89 44 24 04          	mov    %eax,0x4(%esp)
f01024da:	c7 04 24 11 4f 10 f0 	movl   $0xf0104f11,(%esp)
f01024e1:	e8 8e fa ff ff       	call   f0101f74 <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f01024e6:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f01024ea:	89 44 24 04          	mov    %eax,0x4(%esp)
f01024ee:	c7 04 24 20 4f 10 f0 	movl   $0xf0104f20,(%esp)
f01024f5:	e8 7a fa ff ff       	call   f0101f74 <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f01024fa:	8b 43 38             	mov    0x38(%ebx),%eax
f01024fd:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102501:	c7 04 24 33 4f 10 f0 	movl   $0xf0104f33,(%esp)
f0102508:	e8 67 fa ff ff       	call   f0101f74 <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f010250d:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f0102511:	74 27                	je     f010253a <print_trapframe+0x196>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f0102513:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0102516:	89 44 24 04          	mov    %eax,0x4(%esp)
f010251a:	c7 04 24 42 4f 10 f0 	movl   $0xf0104f42,(%esp)
f0102521:	e8 4e fa ff ff       	call   f0101f74 <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f0102526:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f010252a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010252e:	c7 04 24 51 4f 10 f0 	movl   $0xf0104f51,(%esp)
f0102535:	e8 3a fa ff ff       	call   f0101f74 <cprintf>
	}
}
f010253a:	83 c4 10             	add    $0x10,%esp
f010253d:	5b                   	pop    %ebx
f010253e:	5e                   	pop    %esi
f010253f:	5d                   	pop    %ebp
f0102540:	c3                   	ret    

f0102541 <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f0102541:	55                   	push   %ebp
f0102542:	89 e5                	mov    %esp,%ebp
f0102544:	56                   	push   %esi
f0102545:	53                   	push   %ebx
f0102546:	83 ec 10             	sub    $0x10,%esp
f0102549:	8b 45 08             	mov    0x8(%ebp),%eax
f010254c:	0f 20 d3             	mov    %cr2,%ebx
	uint32_t fault_va;

	// Read processor's CR2 register to find the faulting address
	fault_va = rcr2();
	if((tf->tf_cs & 3)==0) // last three bits 000 means DPL_Kern
f010254f:	f6 40 34 03          	testb  $0x3,0x34(%eax)
f0102553:	75 1c                	jne    f0102571 <page_fault_handler+0x30>
	{
		panic("kernel mode page faults!!");
f0102555:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f010255c:	f0 
f010255d:	c7 44 24 04 3f 01 00 	movl   $0x13f,0x4(%esp)
f0102564:	00 
f0102565:	c7 04 24 7e 4f 10 f0 	movl   $0xf0104f7e,(%esp)
f010256c:	e8 cf da ff ff       	call   f0100040 <_panic>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0102571:	8b 70 30             	mov    0x30(%eax),%esi
		curenv->env_id, fault_va, tf->tf_eip);
f0102574:	e8 ea 17 00 00       	call   f0103d63 <cpunum>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0102579:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010257d:	89 5c 24 08          	mov    %ebx,0x8(%esp)
		curenv->env_id, fault_va, tf->tf_eip);
f0102581:	6b c0 74             	imul   $0x74,%eax,%eax
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0102584:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f010258a:	8b 40 48             	mov    0x48(%eax),%eax
f010258d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102591:	c7 04 24 40 51 10 f0 	movl   $0xf0105140,(%esp)
f0102598:	e8 d7 f9 ff ff       	call   f0101f74 <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
	//print_trapframe(tf);
	env_destroy(curenv);
f010259d:	e8 c1 17 00 00       	call   f0103d63 <cpunum>
f01025a2:	6b c0 74             	imul   $0x74,%eax,%eax
f01025a5:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f01025ab:	89 04 24             	mov    %eax,(%esp)
f01025ae:	e8 1d f7 ff ff       	call   f0101cd0 <env_destroy>
}
f01025b3:	83 c4 10             	add    $0x10,%esp
f01025b6:	5b                   	pop    %ebx
f01025b7:	5e                   	pop    %esi
f01025b8:	5d                   	pop    %ebp
f01025b9:	c3                   	ret    

f01025ba <trap>:



void
trap(struct Trapframe *tf)
{
f01025ba:	55                   	push   %ebp
f01025bb:	89 e5                	mov    %esp,%ebp
f01025bd:	57                   	push   %edi
f01025be:	56                   	push   %esi
f01025bf:	83 ec 20             	sub    $0x20,%esp
f01025c2:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f01025c5:	fc                   	cld    

	// Halt the CPU if some other CPU has called panic()
	extern char *panicstr;
	if (panicstr)
f01025c6:	83 3d 00 ff 21 f0 00 	cmpl   $0x0,0xf021ff00
f01025cd:	74 01                	je     f01025d0 <trap+0x16>
		asm volatile("hlt");
f01025cf:	f4                   	hlt    

static __inline uint32_t
read_eflags(void)
{
        uint32_t eflags;
        __asm __volatile("pushfl; popl %0" : "=r" (eflags));
f01025d0:	9c                   	pushf  
f01025d1:	58                   	pop    %eax

	// Check that interrupts are disabled.  If this assertion
	// fails, DO NOT be tempted to fix it by inserting a "cli" in
	// the interrupt path.
	assert(!(read_eflags() & FL_IF));
f01025d2:	f6 c4 02             	test   $0x2,%ah
f01025d5:	74 24                	je     f01025fb <trap+0x41>
f01025d7:	c7 44 24 0c 8a 4f 10 	movl   $0xf0104f8a,0xc(%esp)
f01025de:	f0 
f01025df:	c7 44 24 08 6c 4c 10 	movl   $0xf0104c6c,0x8(%esp)
f01025e6:	f0 
f01025e7:	c7 44 24 04 0b 01 00 	movl   $0x10b,0x4(%esp)
f01025ee:	00 
f01025ef:	c7 04 24 7e 4f 10 f0 	movl   $0xf0104f7e,(%esp)
f01025f6:	e8 45 da ff ff       	call   f0100040 <_panic>
	
	cprintf("Incoming TRAP frame at %p\n", tf);
f01025fb:	89 74 24 04          	mov    %esi,0x4(%esp)
f01025ff:	c7 04 24 a3 4f 10 f0 	movl   $0xf0104fa3,(%esp)
f0102606:	e8 69 f9 ff ff       	call   f0101f74 <cprintf>

	if ((tf->tf_cs & 3) == 3) {
f010260b:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f010260f:	83 e0 03             	and    $0x3,%eax
f0102612:	66 83 f8 03          	cmp    $0x3,%ax
f0102616:	0f 85 9b 00 00 00    	jne    f01026b7 <trap+0xfd>
		// Trapped from user mode.
		// Acquire the big kernel lock before doing any
		// serious kernel work.
		// LAB 4: Your code here.
		assert(curenv);
f010261c:	e8 42 17 00 00       	call   f0103d63 <cpunum>
f0102621:	6b c0 74             	imul   $0x74,%eax,%eax
f0102624:	83 b8 28 00 22 f0 00 	cmpl   $0x0,-0xfddffd8(%eax)
f010262b:	75 24                	jne    f0102651 <trap+0x97>
f010262d:	c7 44 24 0c be 4f 10 	movl   $0xf0104fbe,0xc(%esp)
f0102634:	f0 
f0102635:	c7 44 24 08 6c 4c 10 	movl   $0xf0104c6c,0x8(%esp)
f010263c:	f0 
f010263d:	c7 44 24 04 14 01 00 	movl   $0x114,0x4(%esp)
f0102644:	00 
f0102645:	c7 04 24 7e 4f 10 f0 	movl   $0xf0104f7e,(%esp)
f010264c:	e8 ef d9 ff ff       	call   f0100040 <_panic>

		// Garbage collect if current enviroment is a zombie
		if (curenv->env_status == ENV_DYING) {
f0102651:	e8 0d 17 00 00       	call   f0103d63 <cpunum>
f0102656:	6b c0 74             	imul   $0x74,%eax,%eax
f0102659:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f010265f:	83 78 54 01          	cmpl   $0x1,0x54(%eax)
f0102663:	75 2d                	jne    f0102692 <trap+0xd8>
			env_free(curenv);
f0102665:	e8 f9 16 00 00       	call   f0103d63 <cpunum>
f010266a:	6b c0 74             	imul   $0x74,%eax,%eax
f010266d:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102673:	89 04 24             	mov    %eax,(%esp)
f0102676:	e8 50 f4 ff ff       	call   f0101acb <env_free>
			curenv = NULL;
f010267b:	e8 e3 16 00 00       	call   f0103d63 <cpunum>
f0102680:	6b c0 74             	imul   $0x74,%eax,%eax
f0102683:	c7 80 28 00 22 f0 00 	movl   $0x0,-0xfddffd8(%eax)
f010268a:	00 00 00 
			sched_yield();
f010268d:	e8 9f 01 00 00       	call   f0102831 <sched_yield>
		}

		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		curenv->env_tf = *tf;
f0102692:	e8 cc 16 00 00       	call   f0103d63 <cpunum>
f0102697:	6b c0 74             	imul   $0x74,%eax,%eax
f010269a:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f01026a0:	b9 11 00 00 00       	mov    $0x11,%ecx
f01026a5:	89 c7                	mov    %eax,%edi
f01026a7:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f01026a9:	e8 b5 16 00 00       	call   f0103d63 <cpunum>
f01026ae:	6b c0 74             	imul   $0x74,%eax,%eax
f01026b1:	8b b0 28 00 22 f0    	mov    -0xfddffd8(%eax),%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f01026b7:	89 35 60 fa 21 f0    	mov    %esi,0xf021fa60
}
static void
trap_dispatch(struct Trapframe *tf)
{
	// Handle processor exceptions.
	print_trapframe(tf);
f01026bd:	89 34 24             	mov    %esi,(%esp)
f01026c0:	e8 df fc ff ff       	call   f01023a4 <print_trapframe>
	// LAB 3: Your code here.

	// Handle spurious interrupts
	// The hardware sometimes raises these because of noise on the
	// IRQ line or other reasons. We don't care.
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_SPURIOUS) {
f01026c5:	8b 46 28             	mov    0x28(%esi),%eax
f01026c8:	83 f8 27             	cmp    $0x27,%eax
f01026cb:	75 19                	jne    f01026e6 <trap+0x12c>
		cprintf("Spurious interrupt on irq 7\n");
f01026cd:	c7 04 24 c5 4f 10 f0 	movl   $0xf0104fc5,(%esp)
f01026d4:	e8 9b f8 ff ff       	call   f0101f74 <cprintf>
		print_trapframe(tf);
f01026d9:	89 34 24             	mov    %esi,(%esp)
f01026dc:	e8 c3 fc ff ff       	call   f01023a4 <print_trapframe>
f01026e1:	e9 93 00 00 00       	jmp    f0102779 <trap+0x1bf>

	// Handle clock interrupts. Don't forget to acknowledge the
	// interrupt using lapic_eoi() before calling the scheduler!
	// LAB 4: Your code here.

	if(tf->tf_trapno==T_PGFLT)
f01026e6:	83 f8 0e             	cmp    $0xe,%eax
f01026e9:	75 0f                	jne    f01026fa <trap+0x140>
	{
		page_fault_handler(tf);
f01026eb:	89 34 24             	mov    %esi,(%esp)
f01026ee:	66 90                	xchg   %ax,%ax
f01026f0:	e8 4c fe ff ff       	call   f0102541 <page_fault_handler>
f01026f5:	e9 7f 00 00 00       	jmp    f0102779 <trap+0x1bf>
		return;
	}
	if(tf->tf_trapno==T_BRKPT)
f01026fa:	83 f8 03             	cmp    $0x3,%eax
f01026fd:	75 0a                	jne    f0102709 <trap+0x14f>
	{
		monitor(tf);
f01026ff:	89 34 24             	mov    %esi,(%esp)
f0102702:	e8 bb e2 ff ff       	call   f01009c2 <monitor>
f0102707:	eb 70                	jmp    f0102779 <trap+0x1bf>
		return;
	}
	if(tf->tf_trapno==T_SYSCALL)
f0102709:	83 f8 30             	cmp    $0x30,%eax
f010270c:	75 32                	jne    f0102740 <trap+0x186>
	{
		tf->tf_regs.reg_eax=syscall(tf->tf_regs.reg_eax,tf->tf_regs.reg_edx,tf->tf_regs.reg_ecx,tf->tf_regs.reg_ebx,tf->tf_regs.reg_edi,tf->tf_regs.reg_esi);
f010270e:	8b 46 04             	mov    0x4(%esi),%eax
f0102711:	89 44 24 14          	mov    %eax,0x14(%esp)
f0102715:	8b 06                	mov    (%esi),%eax
f0102717:	89 44 24 10          	mov    %eax,0x10(%esp)
f010271b:	8b 46 10             	mov    0x10(%esi),%eax
f010271e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102722:	8b 46 18             	mov    0x18(%esi),%eax
f0102725:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102729:	8b 46 14             	mov    0x14(%esi),%eax
f010272c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102730:	8b 46 1c             	mov    0x1c(%esi),%eax
f0102733:	89 04 24             	mov    %eax,(%esp)
f0102736:	e8 95 01 00 00       	call   f01028d0 <syscall>
f010273b:	89 46 1c             	mov    %eax,0x1c(%esi)
f010273e:	eb 39                	jmp    f0102779 <trap+0x1bf>
	    return;
	}
	// Unexpected trap: The user process or the kernel has a bug.

	if (tf->tf_cs == GD_KT)
f0102740:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f0102745:	75 1c                	jne    f0102763 <trap+0x1a9>
		panic("unhandled trap in kernel");
f0102747:	c7 44 24 08 e2 4f 10 	movl   $0xf0104fe2,0x8(%esp)
f010274e:	f0 
f010274f:	c7 44 24 04 f3 00 00 	movl   $0xf3,0x4(%esp)
f0102756:	00 
f0102757:	c7 04 24 7e 4f 10 f0 	movl   $0xf0104f7e,(%esp)
f010275e:	e8 dd d8 ff ff       	call   f0100040 <_panic>
	else {
		env_destroy(curenv);
f0102763:	e8 fb 15 00 00       	call   f0103d63 <cpunum>
f0102768:	6b c0 74             	imul   $0x74,%eax,%eax
f010276b:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102771:	89 04 24             	mov    %eax,(%esp)
f0102774:	e8 57 f5 ff ff       	call   f0101cd0 <env_destroy>
	trap_dispatch(tf);

	// If we made it to this point, then no other environment was
	// scheduled, so we should return to the current environment
	// if doing so makes sense.
	if (curenv && curenv->env_status == ENV_RUNNING)
f0102779:	e8 e5 15 00 00       	call   f0103d63 <cpunum>
f010277e:	6b c0 74             	imul   $0x74,%eax,%eax
f0102781:	83 b8 28 00 22 f0 00 	cmpl   $0x0,-0xfddffd8(%eax)
f0102788:	74 2a                	je     f01027b4 <trap+0x1fa>
f010278a:	e8 d4 15 00 00       	call   f0103d63 <cpunum>
f010278f:	6b c0 74             	imul   $0x74,%eax,%eax
f0102792:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102798:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f010279c:	75 16                	jne    f01027b4 <trap+0x1fa>
		env_run(curenv);
f010279e:	e8 c0 15 00 00       	call   f0103d63 <cpunum>
f01027a3:	6b c0 74             	imul   $0x74,%eax,%eax
f01027a6:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f01027ac:	89 04 24             	mov    %eax,(%esp)
f01027af:	e8 bd f5 ff ff       	call   f0101d71 <env_run>
	else
		sched_yield();
f01027b4:	e8 78 00 00 00       	call   f0102831 <sched_yield>
f01027b9:	90                   	nop

f01027ba <dividezero_handler>:
.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
f01027ba:	6a 00                	push   $0x0
f01027bc:	6a 00                	push   $0x0
f01027be:	eb 58                	jmp    f0102818 <_alltraps>

f01027c0 <nmi_handler>:
TRAPHANDLER_NOEC(nmi_handler, 0x2)
f01027c0:	6a 00                	push   $0x0
f01027c2:	6a 02                	push   $0x2
f01027c4:	eb 52                	jmp    f0102818 <_alltraps>

f01027c6 <breakpoint_handler>:
TRAPHANDLER_NOEC(breakpoint_handler, 0x3)
f01027c6:	6a 00                	push   $0x0
f01027c8:	6a 03                	push   $0x3
f01027ca:	eb 4c                	jmp    f0102818 <_alltraps>

f01027cc <overflow_handler>:
TRAPHANDLER_NOEC(overflow_handler, 0x4)
f01027cc:	6a 00                	push   $0x0
f01027ce:	6a 04                	push   $0x4
f01027d0:	eb 46                	jmp    f0102818 <_alltraps>

f01027d2 <bdrgeexceed_handler>:
TRAPHANDLER_NOEC(bdrgeexceed_handler, 0x5)
f01027d2:	6a 00                	push   $0x0
f01027d4:	6a 05                	push   $0x5
f01027d6:	eb 40                	jmp    f0102818 <_alltraps>

f01027d8 <invalidop_handler>:
TRAPHANDLER_NOEC(invalidop_handler, 0x6)
f01027d8:	6a 00                	push   $0x0
f01027da:	6a 06                	push   $0x6
f01027dc:	eb 3a                	jmp    f0102818 <_alltraps>

f01027de <nomathcopro_handler>:
TRAPHANDLER_NOEC(nomathcopro_handler, 0x7)
f01027de:	6a 00                	push   $0x0
f01027e0:	6a 07                	push   $0x7
f01027e2:	eb 34                	jmp    f0102818 <_alltraps>

f01027e4 <dbfault_handler>:
TRAPHANDLER(dbfault_handler, 0x8)
f01027e4:	6a 08                	push   $0x8
f01027e6:	eb 30                	jmp    f0102818 <_alltraps>

f01027e8 <invalidTSS_handler>:
TRAPHANDLER(invalidTSS_handler, 0xA)
f01027e8:	6a 0a                	push   $0xa
f01027ea:	eb 2c                	jmp    f0102818 <_alltraps>

f01027ec <sgmtnotpresent_handler>:
TRAPHANDLER(sgmtnotpresent_handler, 0xB)
f01027ec:	6a 0b                	push   $0xb
f01027ee:	eb 28                	jmp    f0102818 <_alltraps>

f01027f0 <stacksgmtfault_handler>:
TRAPHANDLER(stacksgmtfault_handler,0xC)
f01027f0:	6a 0c                	push   $0xc
f01027f2:	eb 24                	jmp    f0102818 <_alltraps>

f01027f4 <generalprotection_handler>:
TRAPHANDLER(generalprotection_handler, 0xD)
f01027f4:	6a 0d                	push   $0xd
f01027f6:	eb 20                	jmp    f0102818 <_alltraps>

f01027f8 <pagefault_handler>:
TRAPHANDLER(pagefault_handler, 0xE)
f01027f8:	6a 0e                	push   $0xe
f01027fa:	eb 1c                	jmp    f0102818 <_alltraps>

f01027fc <FPUerror_handler>:
TRAPHANDLER_NOEC(FPUerror_handler, 0x10)
f01027fc:	6a 00                	push   $0x0
f01027fe:	6a 10                	push   $0x10
f0102800:	eb 16                	jmp    f0102818 <_alltraps>

f0102802 <alignmentcheck_handler>:
TRAPHANDLER(alignmentcheck_handler, 0x11)
f0102802:	6a 11                	push   $0x11
f0102804:	eb 12                	jmp    f0102818 <_alltraps>

f0102806 <machinecheck_handler>:
TRAPHANDLER_NOEC(machinecheck_handler, 0x12)
f0102806:	6a 00                	push   $0x0
f0102808:	6a 12                	push   $0x12
f010280a:	eb 0c                	jmp    f0102818 <_alltraps>

f010280c <SIMDFPexception_handler>:
TRAPHANDLER_NOEC(SIMDFPexception_handler, 0x13)
f010280c:	6a 00                	push   $0x0
f010280e:	6a 13                	push   $0x13
f0102810:	eb 06                	jmp    f0102818 <_alltraps>

f0102812 <systemcall_handler>:
TRAPHANDLER_NOEC(systemcall_handler, 0x30)
f0102812:	6a 00                	push   $0x0
f0102814:	6a 30                	push   $0x30
f0102816:	eb 00                	jmp    f0102818 <_alltraps>

f0102818 <_alltraps>:
/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
	pushw $0
f0102818:	66 6a 00             	pushw  $0x0
	pushw %ds
f010281b:	66 1e                	pushw  %ds
	pushw $0
f010281d:	66 6a 00             	pushw  $0x0
	pushw %es
f0102820:	66 06                	pushw  %es
	pushal
f0102822:	60                   	pusha  
	pushl %esp
f0102823:	54                   	push   %esp
	movw $(GD_KD),%ax
f0102824:	66 b8 10 00          	mov    $0x10,%ax
	movw %ax,%ds
f0102828:	8e d8                	mov    %eax,%ds
	movw %ax,%es
f010282a:	8e c0                	mov    %eax,%es
	call trap
f010282c:	e8 89 fd ff ff       	call   f01025ba <trap>

f0102831 <sched_yield>:


// Choose a user environment to run and run it.
void
sched_yield(void)
{
f0102831:	55                   	push   %ebp
f0102832:	89 e5                	mov    %esp,%ebp
f0102834:	53                   	push   %ebx
f0102835:	83 ec 14             	sub    $0x14,%esp

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0102838:	8b 1d 48 f2 21 f0    	mov    0xf021f248,%ebx
f010283e:	89 d8                	mov    %ebx,%eax
	// LAB 4: Your code here.

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0102840:	ba 00 00 00 00       	mov    $0x0,%edx
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0102845:	83 78 50 01          	cmpl   $0x1,0x50(%eax)
f0102849:	74 0b                	je     f0102856 <sched_yield+0x25>
		    (envs[i].env_status == ENV_RUNNABLE ||
f010284b:	8b 48 54             	mov    0x54(%eax),%ecx
f010284e:	83 e9 02             	sub    $0x2,%ecx

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0102851:	83 f9 01             	cmp    $0x1,%ecx
f0102854:	76 10                	jbe    f0102866 <sched_yield+0x35>
	// LAB 4: Your code here.

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0102856:	83 c2 01             	add    $0x1,%edx
f0102859:	83 c0 7c             	add    $0x7c,%eax
f010285c:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0102862:	75 e1                	jne    f0102845 <sched_yield+0x14>
f0102864:	eb 08                	jmp    f010286e <sched_yield+0x3d>
		if (envs[i].env_type != ENV_TYPE_IDLE &&
		    (envs[i].env_status == ENV_RUNNABLE ||
		     envs[i].env_status == ENV_RUNNING))
			break;
	}
	if (i == NENV) {
f0102866:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f010286c:	75 1a                	jne    f0102888 <sched_yield+0x57>
		cprintf("No more runnable environments!\n");
f010286e:	c7 04 24 d0 51 10 f0 	movl   $0xf01051d0,(%esp)
f0102875:	e8 fa f6 ff ff       	call   f0101f74 <cprintf>
		while (1)
			monitor(NULL);
f010287a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102881:	e8 3c e1 ff ff       	call   f01009c2 <monitor>
f0102886:	eb f2                	jmp    f010287a <sched_yield+0x49>
	}

	// Run this CPU's idle environment when nothing else is runnable.
	idle = &envs[cpunum()];
f0102888:	e8 d6 14 00 00       	call   f0103d63 <cpunum>
f010288d:	6b c0 7c             	imul   $0x7c,%eax,%eax
f0102890:	01 c3                	add    %eax,%ebx
	if (!(idle->env_status == ENV_RUNNABLE || idle->env_status == ENV_RUNNING))
f0102892:	8b 43 54             	mov    0x54(%ebx),%eax
f0102895:	83 e8 02             	sub    $0x2,%eax
f0102898:	83 f8 01             	cmp    $0x1,%eax
f010289b:	76 25                	jbe    f01028c2 <sched_yield+0x91>
		panic("CPU %d: No idle environment!", cpunum());
f010289d:	e8 c1 14 00 00       	call   f0103d63 <cpunum>
f01028a2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01028a6:	c7 44 24 08 f0 51 10 	movl   $0xf01051f0,0x8(%esp)
f01028ad:	f0 
f01028ae:	c7 44 24 04 33 00 00 	movl   $0x33,0x4(%esp)
f01028b5:	00 
f01028b6:	c7 04 24 0d 52 10 f0 	movl   $0xf010520d,(%esp)
f01028bd:	e8 7e d7 ff ff       	call   f0100040 <_panic>
	env_run(idle);
f01028c2:	89 1c 24             	mov    %ebx,(%esp)
f01028c5:	e8 a7 f4 ff ff       	call   f0101d71 <env_run>
f01028ca:	66 90                	xchg   %ax,%ax
f01028cc:	66 90                	xchg   %ax,%ax
f01028ce:	66 90                	xchg   %ax,%ax

f01028d0 <syscall>:
}

// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
f01028d0:	55                   	push   %ebp
f01028d1:	89 e5                	mov    %esp,%ebp
f01028d3:	53                   	push   %ebx
f01028d4:	83 ec 24             	sub    $0x24,%esp
f01028d7:	8b 45 08             	mov    0x8(%ebp),%eax
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
	switch(syscallno){
f01028da:	83 f8 01             	cmp    $0x1,%eax
f01028dd:	74 66                	je     f0102945 <syscall+0x75>
f01028df:	83 f8 01             	cmp    $0x1,%eax
f01028e2:	72 11                	jb     f01028f5 <syscall+0x25>
f01028e4:	83 f8 02             	cmp    $0x2,%eax
f01028e7:	74 66                	je     f010294f <syscall+0x7f>
f01028e9:	83 f8 03             	cmp    $0x3,%eax
f01028ec:	74 78                	je     f0102966 <syscall+0x96>
f01028ee:	66 90                	xchg   %ax,%ax
f01028f0:	e9 03 01 00 00       	jmp    f01029f8 <syscall+0x128>
static void
sys_cputs(const char *s, size_t len)
{
	// Check that the user has permission to read memory [s, s+len).
	// Destroy the environment if not.
	user_mem_assert(curenv,s,len,0);
f01028f5:	e8 69 14 00 00       	call   f0103d63 <cpunum>
f01028fa:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0102901:	00 
f0102902:	8b 4d 10             	mov    0x10(%ebp),%ecx
f0102905:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0102909:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010290c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0102910:	6b c0 74             	imul   $0x74,%eax,%eax
f0102913:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102919:	89 04 24             	mov    %eax,(%esp)
f010291c:	e8 6e ec ff ff       	call   f010158f <user_mem_assert>
	// LAB 3: Your code here.
	// Print the string supplied by the user.
	cprintf("%.*s", len, s);
f0102921:	8b 45 0c             	mov    0xc(%ebp),%eax
f0102924:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102928:	8b 45 10             	mov    0x10(%ebp),%eax
f010292b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010292f:	c7 04 24 1a 52 10 f0 	movl   $0xf010521a,(%esp)
f0102936:	e8 39 f6 ff ff       	call   f0101f74 <cprintf>
	// Return any appropriate return value.
	// LAB 3: Your code here.
	switch(syscallno){
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
f010293b:	b8 00 00 00 00       	mov    $0x0,%eax
f0102940:	e9 b8 00 00 00       	jmp    f01029fd <syscall+0x12d>
// Read a character from the system console without blocking.
// Returns the character, or 0 if there is no input waiting.
static int
sys_cgetc(void)
{
	return cons_getc();
f0102945:	e8 1b dd ff ff       	call   f0100665 <cons_getc>
	switch(syscallno){
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case(SYS_cgetc):
			return sys_cgetc();
f010294a:	e9 ae 00 00 00       	jmp    f01029fd <syscall+0x12d>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f010294f:	90                   	nop
f0102950:	e8 0e 14 00 00       	call   f0103d63 <cpunum>
f0102955:	6b c0 74             	imul   $0x74,%eax,%eax
f0102958:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f010295e:	8b 40 48             	mov    0x48(%eax),%eax
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case(SYS_cgetc):
			return sys_cgetc();
		case(SYS_getenvid):
			return sys_getenvid();
f0102961:	e9 97 00 00 00       	jmp    f01029fd <syscall+0x12d>
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0102966:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010296d:	00 
f010296e:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0102971:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102975:	8b 45 0c             	mov    0xc(%ebp),%eax
f0102978:	89 04 24             	mov    %eax,(%esp)
f010297b:	e8 67 ec ff ff       	call   f01015e7 <envid2env>
		return r;
f0102980:	89 c2                	mov    %eax,%edx
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0102982:	85 c0                	test   %eax,%eax
f0102984:	78 6e                	js     f01029f4 <syscall+0x124>
		return r;
	if (e == curenv)
f0102986:	e8 d8 13 00 00       	call   f0103d63 <cpunum>
f010298b:	8b 55 f4             	mov    -0xc(%ebp),%edx
f010298e:	6b c0 74             	imul   $0x74,%eax,%eax
f0102991:	39 90 28 00 22 f0    	cmp    %edx,-0xfddffd8(%eax)
f0102997:	75 23                	jne    f01029bc <syscall+0xec>
		cprintf("[%08x] exiting gracefully\n", curenv->env_id);
f0102999:	e8 c5 13 00 00       	call   f0103d63 <cpunum>
f010299e:	6b c0 74             	imul   $0x74,%eax,%eax
f01029a1:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f01029a7:	8b 40 48             	mov    0x48(%eax),%eax
f01029aa:	89 44 24 04          	mov    %eax,0x4(%esp)
f01029ae:	c7 04 24 1f 52 10 f0 	movl   $0xf010521f,(%esp)
f01029b5:	e8 ba f5 ff ff       	call   f0101f74 <cprintf>
f01029ba:	eb 28                	jmp    f01029e4 <syscall+0x114>
	else
		cprintf("[%08x] destroying %08x\n", curenv->env_id, e->env_id);
f01029bc:	8b 5a 48             	mov    0x48(%edx),%ebx
f01029bf:	e8 9f 13 00 00       	call   f0103d63 <cpunum>
f01029c4:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f01029c8:	6b c0 74             	imul   $0x74,%eax,%eax
f01029cb:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f01029d1:	8b 40 48             	mov    0x48(%eax),%eax
f01029d4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01029d8:	c7 04 24 3a 52 10 f0 	movl   $0xf010523a,(%esp)
f01029df:	e8 90 f5 ff ff       	call   f0101f74 <cprintf>
	env_destroy(e);
f01029e4:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01029e7:	89 04 24             	mov    %eax,(%esp)
f01029ea:	e8 e1 f2 ff ff       	call   f0101cd0 <env_destroy>
	return 0;
f01029ef:	ba 00 00 00 00       	mov    $0x0,%edx
		case(SYS_cgetc):
			return sys_cgetc();
		case(SYS_getenvid):
			return sys_getenvid();
		case(SYS_env_destroy):
			return sys_env_destroy((envid_t) a1);
f01029f4:	89 d0                	mov    %edx,%eax
f01029f6:	eb 05                	jmp    f01029fd <syscall+0x12d>
		default:
			return -E_INVAL;
f01029f8:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
	}
	//panic("syscall not implemented");
}
f01029fd:	83 c4 24             	add    $0x24,%esp
f0102a00:	5b                   	pop    %ebx
f0102a01:	5d                   	pop    %ebp
f0102a02:	c3                   	ret    
f0102a03:	66 90                	xchg   %ax,%ax
f0102a05:	66 90                	xchg   %ax,%ax
f0102a07:	66 90                	xchg   %ax,%ax
f0102a09:	66 90                	xchg   %ax,%ax
f0102a0b:	66 90                	xchg   %ax,%ax
f0102a0d:	66 90                	xchg   %ax,%ax
f0102a0f:	90                   	nop

f0102a10 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0102a10:	55                   	push   %ebp
f0102a11:	89 e5                	mov    %esp,%ebp
f0102a13:	57                   	push   %edi
f0102a14:	56                   	push   %esi
f0102a15:	53                   	push   %ebx
f0102a16:	83 ec 14             	sub    $0x14,%esp
f0102a19:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0102a1c:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f0102a1f:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0102a22:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0102a25:	8b 1a                	mov    (%edx),%ebx
f0102a27:	8b 01                	mov    (%ecx),%eax
f0102a29:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f0102a2c:	39 c3                	cmp    %eax,%ebx
f0102a2e:	0f 8f 9a 00 00 00    	jg     f0102ace <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f0102a34:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0102a3b:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0102a3e:	01 d8                	add    %ebx,%eax
f0102a40:	89 c7                	mov    %eax,%edi
f0102a42:	c1 ef 1f             	shr    $0x1f,%edi
f0102a45:	01 c7                	add    %eax,%edi
f0102a47:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0102a49:	39 df                	cmp    %ebx,%edi
f0102a4b:	0f 8c c4 00 00 00    	jl     f0102b15 <stab_binsearch+0x105>
f0102a51:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0102a54:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0102a57:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f0102a5a:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f0102a5e:	39 f0                	cmp    %esi,%eax
f0102a60:	0f 84 b4 00 00 00    	je     f0102b1a <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0102a66:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f0102a68:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0102a6b:	39 d8                	cmp    %ebx,%eax
f0102a6d:	0f 8c a2 00 00 00    	jl     f0102b15 <stab_binsearch+0x105>
f0102a73:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f0102a77:	83 ea 0c             	sub    $0xc,%edx
f0102a7a:	39 f1                	cmp    %esi,%ecx
f0102a7c:	75 ea                	jne    f0102a68 <stab_binsearch+0x58>
f0102a7e:	e9 99 00 00 00       	jmp    f0102b1c <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0102a83:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0102a86:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f0102a88:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0102a8b:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0102a92:	eb 2b                	jmp    f0102abf <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0102a94:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0102a97:	76 14                	jbe    f0102aad <stab_binsearch+0x9d>
			*region_right = m - 1;
f0102a99:	83 e8 01             	sub    $0x1,%eax
f0102a9c:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0102a9f:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0102aa2:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0102aa4:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0102aab:	eb 12                	jmp    f0102abf <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0102aad:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0102ab0:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f0102ab2:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f0102ab6:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0102ab8:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f0102abf:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0102ac2:	0f 8e 73 ff ff ff    	jle    f0102a3b <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0102ac8:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f0102acc:	75 0f                	jne    f0102add <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f0102ace:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0102ad1:	8b 00                	mov    (%eax),%eax
f0102ad3:	83 e8 01             	sub    $0x1,%eax
f0102ad6:	8b 75 e0             	mov    -0x20(%ebp),%esi
f0102ad9:	89 06                	mov    %eax,(%esi)
f0102adb:	eb 57                	jmp    f0102b34 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0102add:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0102ae0:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0102ae2:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0102ae5:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0102ae7:	39 c8                	cmp    %ecx,%eax
f0102ae9:	7e 23                	jle    f0102b0e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0102aeb:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0102aee:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0102af1:	8d 14 97             	lea    (%edi,%edx,4),%edx
f0102af4:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f0102af8:	39 f3                	cmp    %esi,%ebx
f0102afa:	74 12                	je     f0102b0e <stab_binsearch+0xfe>
		     l--)
f0102afc:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0102aff:	39 c8                	cmp    %ecx,%eax
f0102b01:	7e 0b                	jle    f0102b0e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0102b03:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f0102b07:	83 ea 0c             	sub    $0xc,%edx
f0102b0a:	39 f3                	cmp    %esi,%ebx
f0102b0c:	75 ee                	jne    f0102afc <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f0102b0e:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0102b11:	89 06                	mov    %eax,(%esi)
f0102b13:	eb 1f                	jmp    f0102b34 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0102b15:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0102b18:	eb a5                	jmp    f0102abf <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0102b1a:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0102b1c:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0102b1f:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0102b22:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0102b26:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0102b29:	0f 82 54 ff ff ff    	jb     f0102a83 <stab_binsearch+0x73>
f0102b2f:	e9 60 ff ff ff       	jmp    f0102a94 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0102b34:	83 c4 14             	add    $0x14,%esp
f0102b37:	5b                   	pop    %ebx
f0102b38:	5e                   	pop    %esi
f0102b39:	5f                   	pop    %edi
f0102b3a:	5d                   	pop    %ebp
f0102b3b:	c3                   	ret    

f0102b3c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0102b3c:	55                   	push   %ebp
f0102b3d:	89 e5                	mov    %esp,%ebp
f0102b3f:	57                   	push   %edi
f0102b40:	56                   	push   %esi
f0102b41:	53                   	push   %ebx
f0102b42:	83 ec 3c             	sub    $0x3c,%esp
f0102b45:	8b 7d 08             	mov    0x8(%ebp),%edi
f0102b48:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0102b4b:	c7 06 52 52 10 f0    	movl   $0xf0105252,(%esi)
	info->eip_line = 0;
f0102b51:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0102b58:	c7 46 08 52 52 10 f0 	movl   $0xf0105252,0x8(%esi)
	info->eip_fn_namelen = 9;
f0102b5f:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0102b66:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0102b69:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0102b70:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f0102b76:	0f 87 ca 00 00 00    	ja     f0102c46 <debuginfo_eip+0x10a>
		const struct UserStabData *usd = (const struct UserStabData *) USTABDATA;

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
f0102b7c:	e8 e2 11 00 00       	call   f0103d63 <cpunum>
f0102b81:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0102b88:	00 
f0102b89:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
f0102b90:	00 
f0102b91:	c7 44 24 04 00 00 20 	movl   $0x200000,0x4(%esp)
f0102b98:	00 
f0102b99:	6b c0 74             	imul   $0x74,%eax,%eax
f0102b9c:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102ba2:	89 04 24             	mov    %eax,(%esp)
f0102ba5:	e8 46 e9 ff ff       	call   f01014f0 <user_mem_check>
f0102baa:	85 c0                	test   %eax,%eax
f0102bac:	0f 85 12 02 00 00    	jne    f0102dc4 <debuginfo_eip+0x288>
			return -1;
		stabs = usd->stabs;
f0102bb2:	a1 00 00 20 00       	mov    0x200000,%eax
f0102bb7:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f0102bba:	8b 1d 04 00 20 00    	mov    0x200004,%ebx
		stabstr = usd->stabstr;
f0102bc0:	8b 15 08 00 20 00    	mov    0x200008,%edx
f0102bc6:	89 55 d0             	mov    %edx,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f0102bc9:	a1 0c 00 20 00       	mov    0x20000c,%eax
f0102bce:	89 45 cc             	mov    %eax,-0x34(%ebp)

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
f0102bd1:	e8 8d 11 00 00       	call   f0103d63 <cpunum>
f0102bd6:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0102bdd:	00 
f0102bde:	89 da                	mov    %ebx,%edx
f0102be0:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0102be3:	29 ca                	sub    %ecx,%edx
f0102be5:	c1 fa 02             	sar    $0x2,%edx
f0102be8:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f0102bee:	89 54 24 08          	mov    %edx,0x8(%esp)
f0102bf2:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0102bf6:	6b c0 74             	imul   $0x74,%eax,%eax
f0102bf9:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102bff:	89 04 24             	mov    %eax,(%esp)
f0102c02:	e8 e9 e8 ff ff       	call   f01014f0 <user_mem_check>
f0102c07:	85 c0                	test   %eax,%eax
f0102c09:	0f 85 bc 01 00 00    	jne    f0102dcb <debuginfo_eip+0x28f>
f0102c0f:	e8 4f 11 00 00       	call   f0103d63 <cpunum>
f0102c14:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0102c1b:	00 
f0102c1c:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0102c1f:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0102c22:	29 ca                	sub    %ecx,%edx
f0102c24:	89 54 24 08          	mov    %edx,0x8(%esp)
f0102c28:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0102c2c:	6b c0 74             	imul   $0x74,%eax,%eax
f0102c2f:	8b 80 28 00 22 f0    	mov    -0xfddffd8(%eax),%eax
f0102c35:	89 04 24             	mov    %eax,(%esp)
f0102c38:	e8 b3 e8 ff ff       	call   f01014f0 <user_mem_check>
f0102c3d:	85 c0                	test   %eax,%eax
f0102c3f:	74 1f                	je     f0102c60 <debuginfo_eip+0x124>
f0102c41:	e9 8c 01 00 00       	jmp    f0102dd2 <debuginfo_eip+0x296>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f0102c46:	c7 45 cc 6a 11 11 f0 	movl   $0xf011116a,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f0102c4d:	c7 45 d0 59 de 10 f0 	movl   $0xf010de59,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f0102c54:	bb 58 de 10 f0       	mov    $0xf010de58,%ebx
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f0102c59:	c7 45 d4 34 57 10 f0 	movl   $0xf0105734,-0x2c(%ebp)
		    return -1;
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0102c60:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0102c63:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0102c66:	0f 83 6d 01 00 00    	jae    f0102dd9 <debuginfo_eip+0x29d>
f0102c6c:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f0102c70:	0f 85 6a 01 00 00    	jne    f0102de0 <debuginfo_eip+0x2a4>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0102c76:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0102c7d:	2b 5d d4             	sub    -0x2c(%ebp),%ebx
f0102c80:	c1 fb 02             	sar    $0x2,%ebx
f0102c83:	69 c3 ab aa aa aa    	imul   $0xaaaaaaab,%ebx,%eax
f0102c89:	83 e8 01             	sub    $0x1,%eax
f0102c8c:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0102c8f:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102c93:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0102c9a:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0102c9d:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0102ca0:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0102ca3:	89 d8                	mov    %ebx,%eax
f0102ca5:	e8 66 fd ff ff       	call   f0102a10 <stab_binsearch>
	if (lfile == 0)
f0102caa:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0102cad:	85 c0                	test   %eax,%eax
f0102caf:	0f 84 32 01 00 00    	je     f0102de7 <debuginfo_eip+0x2ab>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0102cb5:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0102cb8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0102cbb:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0102cbe:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102cc2:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0102cc9:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0102ccc:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0102ccf:	89 d8                	mov    %ebx,%eax
f0102cd1:	e8 3a fd ff ff       	call   f0102a10 <stab_binsearch>

	if (lfun <= rfun) {
f0102cd6:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f0102cd9:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f0102cdc:	7f 23                	jg     f0102d01 <debuginfo_eip+0x1c5>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0102cde:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0102ce1:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0102ce4:	8d 04 87             	lea    (%edi,%eax,4),%eax
f0102ce7:	8b 10                	mov    (%eax),%edx
f0102ce9:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0102cec:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f0102cef:	39 ca                	cmp    %ecx,%edx
f0102cf1:	73 06                	jae    f0102cf9 <debuginfo_eip+0x1bd>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0102cf3:	03 55 d0             	add    -0x30(%ebp),%edx
f0102cf6:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f0102cf9:	8b 40 08             	mov    0x8(%eax),%eax
f0102cfc:	89 46 10             	mov    %eax,0x10(%esi)
f0102cff:	eb 06                	jmp    f0102d07 <debuginfo_eip+0x1cb>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0102d01:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f0102d04:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0102d07:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0102d0e:	00 
f0102d0f:	8b 46 08             	mov    0x8(%esi),%eax
f0102d12:	89 04 24             	mov    %eax,(%esp)
f0102d15:	e8 85 09 00 00       	call   f010369f <strfind>
f0102d1a:	2b 46 08             	sub    0x8(%esi),%eax
f0102d1d:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0102d20:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0102d23:	39 fb                	cmp    %edi,%ebx
f0102d25:	7c 5d                	jl     f0102d84 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0102d27:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0102d2a:	c1 e0 02             	shl    $0x2,%eax
f0102d2d:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0102d30:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f0102d33:	89 55 c8             	mov    %edx,-0x38(%ebp)
f0102d36:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f0102d3a:	80 fa 84             	cmp    $0x84,%dl
f0102d3d:	74 2d                	je     f0102d6c <debuginfo_eip+0x230>
f0102d3f:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f0102d43:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0102d46:	eb 15                	jmp    f0102d5d <debuginfo_eip+0x221>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0102d48:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0102d4b:	39 fb                	cmp    %edi,%ebx
f0102d4d:	7c 35                	jl     f0102d84 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0102d4f:	89 c1                	mov    %eax,%ecx
f0102d51:	83 e8 0c             	sub    $0xc,%eax
f0102d54:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0102d58:	80 fa 84             	cmp    $0x84,%dl
f0102d5b:	74 0f                	je     f0102d6c <debuginfo_eip+0x230>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0102d5d:	80 fa 64             	cmp    $0x64,%dl
f0102d60:	75 e6                	jne    f0102d48 <debuginfo_eip+0x20c>
f0102d62:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f0102d66:	74 e0                	je     f0102d48 <debuginfo_eip+0x20c>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0102d68:	39 df                	cmp    %ebx,%edi
f0102d6a:	7f 18                	jg     f0102d84 <debuginfo_eip+0x248>
f0102d6c:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0102d6f:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0102d72:	8b 04 87             	mov    (%edi,%eax,4),%eax
f0102d75:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0102d78:	2b 55 d0             	sub    -0x30(%ebp),%edx
f0102d7b:	39 d0                	cmp    %edx,%eax
f0102d7d:	73 05                	jae    f0102d84 <debuginfo_eip+0x248>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0102d7f:	03 45 d0             	add    -0x30(%ebp),%eax
f0102d82:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0102d84:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0102d87:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0102d8a:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0102d8f:	39 ca                	cmp    %ecx,%edx
f0102d91:	7d 75                	jge    f0102e08 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
f0102d93:	8d 42 01             	lea    0x1(%edx),%eax
f0102d96:	39 c1                	cmp    %eax,%ecx
f0102d98:	7e 54                	jle    f0102dee <debuginfo_eip+0x2b2>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0102d9a:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0102d9d:	c1 e2 02             	shl    $0x2,%edx
f0102da0:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0102da3:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f0102da8:	75 4b                	jne    f0102df5 <debuginfo_eip+0x2b9>
f0102daa:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f0102dae:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0102db2:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0102db5:	39 c1                	cmp    %eax,%ecx
f0102db7:	7e 43                	jle    f0102dfc <debuginfo_eip+0x2c0>
f0102db9:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0102dbc:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0102dc0:	74 ec                	je     f0102dae <debuginfo_eip+0x272>
f0102dc2:	eb 3f                	jmp    f0102e03 <debuginfo_eip+0x2c7>

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
			return -1;
f0102dc4:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0102dc9:	eb 3d                	jmp    f0102e08 <debuginfo_eip+0x2cc>

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
		 {
		    return -1;
f0102dcb:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0102dd0:	eb 36                	jmp    f0102e08 <debuginfo_eip+0x2cc>
f0102dd2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0102dd7:	eb 2f                	jmp    f0102e08 <debuginfo_eip+0x2cc>
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0102dd9:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0102dde:	eb 28                	jmp    f0102e08 <debuginfo_eip+0x2cc>
f0102de0:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0102de5:	eb 21                	jmp    f0102e08 <debuginfo_eip+0x2cc>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0102de7:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0102dec:	eb 1a                	jmp    f0102e08 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0102dee:	b8 00 00 00 00       	mov    $0x0,%eax
f0102df3:	eb 13                	jmp    f0102e08 <debuginfo_eip+0x2cc>
f0102df5:	b8 00 00 00 00       	mov    $0x0,%eax
f0102dfa:	eb 0c                	jmp    f0102e08 <debuginfo_eip+0x2cc>
f0102dfc:	b8 00 00 00 00       	mov    $0x0,%eax
f0102e01:	eb 05                	jmp    f0102e08 <debuginfo_eip+0x2cc>
f0102e03:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0102e08:	83 c4 3c             	add    $0x3c,%esp
f0102e0b:	5b                   	pop    %ebx
f0102e0c:	5e                   	pop    %esi
f0102e0d:	5f                   	pop    %edi
f0102e0e:	5d                   	pop    %ebp
f0102e0f:	c3                   	ret    

f0102e10 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0102e10:	55                   	push   %ebp
f0102e11:	89 e5                	mov    %esp,%ebp
f0102e13:	57                   	push   %edi
f0102e14:	56                   	push   %esi
f0102e15:	53                   	push   %ebx
f0102e16:	83 ec 3c             	sub    $0x3c,%esp
f0102e19:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0102e1c:	89 d7                	mov    %edx,%edi
f0102e1e:	8b 45 08             	mov    0x8(%ebp),%eax
f0102e21:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0102e24:	8b 75 0c             	mov    0xc(%ebp),%esi
f0102e27:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f0102e2a:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0102e2d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0102e32:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0102e35:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0102e38:	39 f1                	cmp    %esi,%ecx
f0102e3a:	72 14                	jb     f0102e50 <printnum+0x40>
f0102e3c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f0102e3f:	76 0f                	jbe    f0102e50 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0102e41:	8b 45 14             	mov    0x14(%ebp),%eax
f0102e44:	8d 70 ff             	lea    -0x1(%eax),%esi
f0102e47:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0102e4a:	85 f6                	test   %esi,%esi
f0102e4c:	7f 60                	jg     f0102eae <printnum+0x9e>
f0102e4e:	eb 72                	jmp    f0102ec2 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0102e50:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0102e53:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0102e57:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0102e5a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0102e5d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0102e61:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102e65:	8b 44 24 08          	mov    0x8(%esp),%eax
f0102e69:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0102e6d:	89 c3                	mov    %eax,%ebx
f0102e6f:	89 d6                	mov    %edx,%esi
f0102e71:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0102e74:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0102e77:	89 54 24 08          	mov    %edx,0x8(%esp)
f0102e7b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0102e7f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0102e82:	89 04 24             	mov    %eax,(%esp)
f0102e85:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102e88:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102e8c:	e8 3f 13 00 00       	call   f01041d0 <__udivdi3>
f0102e91:	89 d9                	mov    %ebx,%ecx
f0102e93:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0102e97:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0102e9b:	89 04 24             	mov    %eax,(%esp)
f0102e9e:	89 54 24 04          	mov    %edx,0x4(%esp)
f0102ea2:	89 fa                	mov    %edi,%edx
f0102ea4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0102ea7:	e8 64 ff ff ff       	call   f0102e10 <printnum>
f0102eac:	eb 14                	jmp    f0102ec2 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f0102eae:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102eb2:	8b 45 18             	mov    0x18(%ebp),%eax
f0102eb5:	89 04 24             	mov    %eax,(%esp)
f0102eb8:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0102eba:	83 ee 01             	sub    $0x1,%esi
f0102ebd:	75 ef                	jne    f0102eae <printnum+0x9e>
f0102ebf:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0102ec2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102ec6:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0102eca:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0102ecd:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0102ed0:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102ed4:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0102ed8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0102edb:	89 04 24             	mov    %eax,(%esp)
f0102ede:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102ee1:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102ee5:	e8 16 14 00 00       	call   f0104300 <__umoddi3>
f0102eea:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102eee:	0f be 80 5c 52 10 f0 	movsbl -0xfefada4(%eax),%eax
f0102ef5:	89 04 24             	mov    %eax,(%esp)
f0102ef8:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0102efb:	ff d0                	call   *%eax
}
f0102efd:	83 c4 3c             	add    $0x3c,%esp
f0102f00:	5b                   	pop    %ebx
f0102f01:	5e                   	pop    %esi
f0102f02:	5f                   	pop    %edi
f0102f03:	5d                   	pop    %ebp
f0102f04:	c3                   	ret    

f0102f05 <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0102f05:	55                   	push   %ebp
f0102f06:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0102f08:	83 fa 01             	cmp    $0x1,%edx
f0102f0b:	7e 0e                	jle    f0102f1b <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f0102f0d:	8b 10                	mov    (%eax),%edx
f0102f0f:	8d 4a 08             	lea    0x8(%edx),%ecx
f0102f12:	89 08                	mov    %ecx,(%eax)
f0102f14:	8b 02                	mov    (%edx),%eax
f0102f16:	8b 52 04             	mov    0x4(%edx),%edx
f0102f19:	eb 22                	jmp    f0102f3d <getuint+0x38>
	else if (lflag)
f0102f1b:	85 d2                	test   %edx,%edx
f0102f1d:	74 10                	je     f0102f2f <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f0102f1f:	8b 10                	mov    (%eax),%edx
f0102f21:	8d 4a 04             	lea    0x4(%edx),%ecx
f0102f24:	89 08                	mov    %ecx,(%eax)
f0102f26:	8b 02                	mov    (%edx),%eax
f0102f28:	ba 00 00 00 00       	mov    $0x0,%edx
f0102f2d:	eb 0e                	jmp    f0102f3d <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f0102f2f:	8b 10                	mov    (%eax),%edx
f0102f31:	8d 4a 04             	lea    0x4(%edx),%ecx
f0102f34:	89 08                	mov    %ecx,(%eax)
f0102f36:	8b 02                	mov    (%edx),%eax
f0102f38:	ba 00 00 00 00       	mov    $0x0,%edx
}
f0102f3d:	5d                   	pop    %ebp
f0102f3e:	c3                   	ret    

f0102f3f <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0102f3f:	55                   	push   %ebp
f0102f40:	89 e5                	mov    %esp,%ebp
f0102f42:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0102f45:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0102f49:	8b 10                	mov    (%eax),%edx
f0102f4b:	3b 50 04             	cmp    0x4(%eax),%edx
f0102f4e:	73 0a                	jae    f0102f5a <sprintputch+0x1b>
		*b->buf++ = ch;
f0102f50:	8d 4a 01             	lea    0x1(%edx),%ecx
f0102f53:	89 08                	mov    %ecx,(%eax)
f0102f55:	8b 45 08             	mov    0x8(%ebp),%eax
f0102f58:	88 02                	mov    %al,(%edx)
}
f0102f5a:	5d                   	pop    %ebp
f0102f5b:	c3                   	ret    

f0102f5c <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0102f5c:	55                   	push   %ebp
f0102f5d:	89 e5                	mov    %esp,%ebp
f0102f5f:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0102f62:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0102f65:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102f69:	8b 45 10             	mov    0x10(%ebp),%eax
f0102f6c:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102f70:	8b 45 0c             	mov    0xc(%ebp),%eax
f0102f73:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102f77:	8b 45 08             	mov    0x8(%ebp),%eax
f0102f7a:	89 04 24             	mov    %eax,(%esp)
f0102f7d:	e8 02 00 00 00       	call   f0102f84 <vprintfmt>
	va_end(ap);
}
f0102f82:	c9                   	leave  
f0102f83:	c3                   	ret    

f0102f84 <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f0102f84:	55                   	push   %ebp
f0102f85:	89 e5                	mov    %esp,%ebp
f0102f87:	57                   	push   %edi
f0102f88:	56                   	push   %esi
f0102f89:	53                   	push   %ebx
f0102f8a:	83 ec 3c             	sub    $0x3c,%esp
f0102f8d:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0102f90:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0102f93:	eb 18                	jmp    f0102fad <vprintfmt+0x29>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f0102f95:	85 c0                	test   %eax,%eax
f0102f97:	0f 84 c3 03 00 00    	je     f0103360 <vprintfmt+0x3dc>
				return;
			putch(ch, putdat);
f0102f9d:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102fa1:	89 04 24             	mov    %eax,(%esp)
f0102fa4:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0102fa7:	89 f3                	mov    %esi,%ebx
f0102fa9:	eb 02                	jmp    f0102fad <vprintfmt+0x29>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f0102fab:	89 f3                	mov    %esi,%ebx
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0102fad:	8d 73 01             	lea    0x1(%ebx),%esi
f0102fb0:	0f b6 03             	movzbl (%ebx),%eax
f0102fb3:	83 f8 25             	cmp    $0x25,%eax
f0102fb6:	75 dd                	jne    f0102f95 <vprintfmt+0x11>
f0102fb8:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f0102fbc:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0102fc3:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f0102fca:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0102fd1:	ba 00 00 00 00       	mov    $0x0,%edx
f0102fd6:	eb 1d                	jmp    f0102ff5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0102fd8:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f0102fda:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f0102fde:	eb 15                	jmp    f0102ff5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0102fe0:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0102fe2:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f0102fe6:	eb 0d                	jmp    f0102ff5 <vprintfmt+0x71>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0102fe8:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102feb:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0102fee:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0102ff5:	8d 5e 01             	lea    0x1(%esi),%ebx
f0102ff8:	0f b6 06             	movzbl (%esi),%eax
f0102ffb:	0f b6 c8             	movzbl %al,%ecx
f0102ffe:	83 e8 23             	sub    $0x23,%eax
f0103001:	3c 55                	cmp    $0x55,%al
f0103003:	0f 87 2f 03 00 00    	ja     f0103338 <vprintfmt+0x3b4>
f0103009:	0f b6 c0             	movzbl %al,%eax
f010300c:	ff 24 85 20 53 10 f0 	jmp    *-0xfeface0(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0103013:	8d 41 d0             	lea    -0x30(%ecx),%eax
f0103016:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0103019:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f010301d:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0103020:	83 f9 09             	cmp    $0x9,%ecx
f0103023:	77 50                	ja     f0103075 <vprintfmt+0xf1>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103025:	89 de                	mov    %ebx,%esi
f0103027:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f010302a:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f010302d:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0103030:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0103034:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0103037:	8d 58 d0             	lea    -0x30(%eax),%ebx
f010303a:	83 fb 09             	cmp    $0x9,%ebx
f010303d:	76 eb                	jbe    f010302a <vprintfmt+0xa6>
f010303f:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0103042:	eb 33                	jmp    f0103077 <vprintfmt+0xf3>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0103044:	8b 45 14             	mov    0x14(%ebp),%eax
f0103047:	8d 48 04             	lea    0x4(%eax),%ecx
f010304a:	89 4d 14             	mov    %ecx,0x14(%ebp)
f010304d:	8b 00                	mov    (%eax),%eax
f010304f:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103052:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0103054:	eb 21                	jmp    f0103077 <vprintfmt+0xf3>
f0103056:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0103059:	85 c9                	test   %ecx,%ecx
f010305b:	b8 00 00 00 00       	mov    $0x0,%eax
f0103060:	0f 49 c1             	cmovns %ecx,%eax
f0103063:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103066:	89 de                	mov    %ebx,%esi
f0103068:	eb 8b                	jmp    f0102ff5 <vprintfmt+0x71>
f010306a:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f010306c:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f0103073:	eb 80                	jmp    f0102ff5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103075:	89 de                	mov    %ebx,%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0103077:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f010307b:	0f 89 74 ff ff ff    	jns    f0102ff5 <vprintfmt+0x71>
f0103081:	e9 62 ff ff ff       	jmp    f0102fe8 <vprintfmt+0x64>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0103086:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103089:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f010308b:	e9 65 ff ff ff       	jmp    f0102ff5 <vprintfmt+0x71>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f0103090:	8b 45 14             	mov    0x14(%ebp),%eax
f0103093:	8d 50 04             	lea    0x4(%eax),%edx
f0103096:	89 55 14             	mov    %edx,0x14(%ebp)
f0103099:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010309d:	8b 00                	mov    (%eax),%eax
f010309f:	89 04 24             	mov    %eax,(%esp)
f01030a2:	ff 55 08             	call   *0x8(%ebp)
			break;
f01030a5:	e9 03 ff ff ff       	jmp    f0102fad <vprintfmt+0x29>

		// error message
		case 'e':
			err = va_arg(ap, int);
f01030aa:	8b 45 14             	mov    0x14(%ebp),%eax
f01030ad:	8d 50 04             	lea    0x4(%eax),%edx
f01030b0:	89 55 14             	mov    %edx,0x14(%ebp)
f01030b3:	8b 00                	mov    (%eax),%eax
f01030b5:	99                   	cltd   
f01030b6:	31 d0                	xor    %edx,%eax
f01030b8:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f01030ba:	83 f8 08             	cmp    $0x8,%eax
f01030bd:	7f 0b                	jg     f01030ca <vprintfmt+0x146>
f01030bf:	8b 14 85 80 54 10 f0 	mov    -0xfefab80(,%eax,4),%edx
f01030c6:	85 d2                	test   %edx,%edx
f01030c8:	75 20                	jne    f01030ea <vprintfmt+0x166>
				printfmt(putch, putdat, "error %d", err);
f01030ca:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01030ce:	c7 44 24 08 74 52 10 	movl   $0xf0105274,0x8(%esp)
f01030d5:	f0 
f01030d6:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01030da:	8b 45 08             	mov    0x8(%ebp),%eax
f01030dd:	89 04 24             	mov    %eax,(%esp)
f01030e0:	e8 77 fe ff ff       	call   f0102f5c <printfmt>
f01030e5:	e9 c3 fe ff ff       	jmp    f0102fad <vprintfmt+0x29>
			else
				printfmt(putch, putdat, "%s", p);
f01030ea:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01030ee:	c7 44 24 08 7e 4c 10 	movl   $0xf0104c7e,0x8(%esp)
f01030f5:	f0 
f01030f6:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01030fa:	8b 45 08             	mov    0x8(%ebp),%eax
f01030fd:	89 04 24             	mov    %eax,(%esp)
f0103100:	e8 57 fe ff ff       	call   f0102f5c <printfmt>
f0103105:	e9 a3 fe ff ff       	jmp    f0102fad <vprintfmt+0x29>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010310a:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f010310d:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0103110:	8b 45 14             	mov    0x14(%ebp),%eax
f0103113:	8d 50 04             	lea    0x4(%eax),%edx
f0103116:	89 55 14             	mov    %edx,0x14(%ebp)
f0103119:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f010311b:	85 c0                	test   %eax,%eax
f010311d:	ba 6d 52 10 f0       	mov    $0xf010526d,%edx
f0103122:	0f 45 d0             	cmovne %eax,%edx
f0103125:	89 55 d0             	mov    %edx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f0103128:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f010312c:	74 04                	je     f0103132 <vprintfmt+0x1ae>
f010312e:	85 f6                	test   %esi,%esi
f0103130:	7f 19                	jg     f010314b <vprintfmt+0x1c7>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0103132:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103135:	8d 70 01             	lea    0x1(%eax),%esi
f0103138:	0f b6 10             	movzbl (%eax),%edx
f010313b:	0f be c2             	movsbl %dl,%eax
f010313e:	85 c0                	test   %eax,%eax
f0103140:	0f 85 95 00 00 00    	jne    f01031db <vprintfmt+0x257>
f0103146:	e9 85 00 00 00       	jmp    f01031d0 <vprintfmt+0x24c>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f010314b:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f010314f:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103152:	89 04 24             	mov    %eax,(%esp)
f0103155:	e8 88 03 00 00       	call   f01034e2 <strnlen>
f010315a:	29 c6                	sub    %eax,%esi
f010315c:	89 f0                	mov    %esi,%eax
f010315e:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0103161:	85 f6                	test   %esi,%esi
f0103163:	7e cd                	jle    f0103132 <vprintfmt+0x1ae>
					putch(padc, putdat);
f0103165:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0103169:	89 5d 10             	mov    %ebx,0x10(%ebp)
f010316c:	89 c3                	mov    %eax,%ebx
f010316e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103172:	89 34 24             	mov    %esi,(%esp)
f0103175:	ff 55 08             	call   *0x8(%ebp)
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0103178:	83 eb 01             	sub    $0x1,%ebx
f010317b:	75 f1                	jne    f010316e <vprintfmt+0x1ea>
f010317d:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0103180:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0103183:	eb ad                	jmp    f0103132 <vprintfmt+0x1ae>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f0103185:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0103189:	74 1e                	je     f01031a9 <vprintfmt+0x225>
f010318b:	0f be d2             	movsbl %dl,%edx
f010318e:	83 ea 20             	sub    $0x20,%edx
f0103191:	83 fa 5e             	cmp    $0x5e,%edx
f0103194:	76 13                	jbe    f01031a9 <vprintfmt+0x225>
					putch('?', putdat);
f0103196:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103199:	89 44 24 04          	mov    %eax,0x4(%esp)
f010319d:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f01031a4:	ff 55 08             	call   *0x8(%ebp)
f01031a7:	eb 0d                	jmp    f01031b6 <vprintfmt+0x232>
				else
					putch(ch, putdat);
f01031a9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01031ac:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01031b0:	89 04 24             	mov    %eax,(%esp)
f01031b3:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01031b6:	83 ef 01             	sub    $0x1,%edi
f01031b9:	83 c6 01             	add    $0x1,%esi
f01031bc:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f01031c0:	0f be c2             	movsbl %dl,%eax
f01031c3:	85 c0                	test   %eax,%eax
f01031c5:	75 20                	jne    f01031e7 <vprintfmt+0x263>
f01031c7:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f01031ca:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01031cd:	8b 5d 10             	mov    0x10(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01031d0:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01031d4:	7f 25                	jg     f01031fb <vprintfmt+0x277>
f01031d6:	e9 d2 fd ff ff       	jmp    f0102fad <vprintfmt+0x29>
f01031db:	89 7d 0c             	mov    %edi,0xc(%ebp)
f01031de:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01031e1:	89 5d 10             	mov    %ebx,0x10(%ebp)
f01031e4:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01031e7:	85 db                	test   %ebx,%ebx
f01031e9:	78 9a                	js     f0103185 <vprintfmt+0x201>
f01031eb:	83 eb 01             	sub    $0x1,%ebx
f01031ee:	79 95                	jns    f0103185 <vprintfmt+0x201>
f01031f0:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f01031f3:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01031f6:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01031f9:	eb d5                	jmp    f01031d0 <vprintfmt+0x24c>
f01031fb:	8b 75 08             	mov    0x8(%ebp),%esi
f01031fe:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0103201:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0103204:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103208:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f010320f:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0103211:	83 eb 01             	sub    $0x1,%ebx
f0103214:	75 ee                	jne    f0103204 <vprintfmt+0x280>
f0103216:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0103219:	e9 8f fd ff ff       	jmp    f0102fad <vprintfmt+0x29>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010321e:	83 fa 01             	cmp    $0x1,%edx
f0103221:	7e 16                	jle    f0103239 <vprintfmt+0x2b5>
		return va_arg(*ap, long long);
f0103223:	8b 45 14             	mov    0x14(%ebp),%eax
f0103226:	8d 50 08             	lea    0x8(%eax),%edx
f0103229:	89 55 14             	mov    %edx,0x14(%ebp)
f010322c:	8b 50 04             	mov    0x4(%eax),%edx
f010322f:	8b 00                	mov    (%eax),%eax
f0103231:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103234:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0103237:	eb 32                	jmp    f010326b <vprintfmt+0x2e7>
	else if (lflag)
f0103239:	85 d2                	test   %edx,%edx
f010323b:	74 18                	je     f0103255 <vprintfmt+0x2d1>
		return va_arg(*ap, long);
f010323d:	8b 45 14             	mov    0x14(%ebp),%eax
f0103240:	8d 50 04             	lea    0x4(%eax),%edx
f0103243:	89 55 14             	mov    %edx,0x14(%ebp)
f0103246:	8b 30                	mov    (%eax),%esi
f0103248:	89 75 d8             	mov    %esi,-0x28(%ebp)
f010324b:	89 f0                	mov    %esi,%eax
f010324d:	c1 f8 1f             	sar    $0x1f,%eax
f0103250:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0103253:	eb 16                	jmp    f010326b <vprintfmt+0x2e7>
	else
		return va_arg(*ap, int);
f0103255:	8b 45 14             	mov    0x14(%ebp),%eax
f0103258:	8d 50 04             	lea    0x4(%eax),%edx
f010325b:	89 55 14             	mov    %edx,0x14(%ebp)
f010325e:	8b 30                	mov    (%eax),%esi
f0103260:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0103263:	89 f0                	mov    %esi,%eax
f0103265:	c1 f8 1f             	sar    $0x1f,%eax
f0103268:	89 45 dc             	mov    %eax,-0x24(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f010326b:	8b 45 d8             	mov    -0x28(%ebp),%eax
f010326e:	8b 55 dc             	mov    -0x24(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f0103271:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0103276:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f010327a:	0f 89 80 00 00 00    	jns    f0103300 <vprintfmt+0x37c>
				putch('-', putdat);
f0103280:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103284:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f010328b:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f010328e:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103291:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103294:	f7 d8                	neg    %eax
f0103296:	83 d2 00             	adc    $0x0,%edx
f0103299:	f7 da                	neg    %edx
			}
			base = 10;
f010329b:	b9 0a 00 00 00       	mov    $0xa,%ecx
f01032a0:	eb 5e                	jmp    f0103300 <vprintfmt+0x37c>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f01032a2:	8d 45 14             	lea    0x14(%ebp),%eax
f01032a5:	e8 5b fc ff ff       	call   f0102f05 <getuint>
			base = 10;
f01032aa:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f01032af:	eb 4f                	jmp    f0103300 <vprintfmt+0x37c>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			//putch('X', putdat);
			num = getuint(&ap, lflag);
f01032b1:	8d 45 14             	lea    0x14(%ebp),%eax
f01032b4:	e8 4c fc ff ff       	call   f0102f05 <getuint>
			base = 8;
f01032b9:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f01032be:	eb 40                	jmp    f0103300 <vprintfmt+0x37c>
			//putch('X', putdat);
			//break;

		// pointer
		case 'p':
			putch('0', putdat);
f01032c0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01032c4:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f01032cb:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f01032ce:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01032d2:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f01032d9:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f01032dc:	8b 45 14             	mov    0x14(%ebp),%eax
f01032df:	8d 50 04             	lea    0x4(%eax),%edx
f01032e2:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f01032e5:	8b 00                	mov    (%eax),%eax
f01032e7:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f01032ec:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f01032f1:	eb 0d                	jmp    f0103300 <vprintfmt+0x37c>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f01032f3:	8d 45 14             	lea    0x14(%ebp),%eax
f01032f6:	e8 0a fc ff ff       	call   f0102f05 <getuint>
			base = 16;
f01032fb:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f0103300:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0103304:	89 74 24 10          	mov    %esi,0x10(%esp)
f0103308:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f010330b:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010330f:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0103313:	89 04 24             	mov    %eax,(%esp)
f0103316:	89 54 24 04          	mov    %edx,0x4(%esp)
f010331a:	89 fa                	mov    %edi,%edx
f010331c:	8b 45 08             	mov    0x8(%ebp),%eax
f010331f:	e8 ec fa ff ff       	call   f0102e10 <printnum>
			break;
f0103324:	e9 84 fc ff ff       	jmp    f0102fad <vprintfmt+0x29>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0103329:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010332d:	89 0c 24             	mov    %ecx,(%esp)
f0103330:	ff 55 08             	call   *0x8(%ebp)
			break;
f0103333:	e9 75 fc ff ff       	jmp    f0102fad <vprintfmt+0x29>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0103338:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010333c:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0103343:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f0103346:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f010334a:	0f 84 5b fc ff ff    	je     f0102fab <vprintfmt+0x27>
f0103350:	89 f3                	mov    %esi,%ebx
f0103352:	83 eb 01             	sub    $0x1,%ebx
f0103355:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f0103359:	75 f7                	jne    f0103352 <vprintfmt+0x3ce>
f010335b:	e9 4d fc ff ff       	jmp    f0102fad <vprintfmt+0x29>
				/* do nothing */;
			break;
		}
	}
}
f0103360:	83 c4 3c             	add    $0x3c,%esp
f0103363:	5b                   	pop    %ebx
f0103364:	5e                   	pop    %esi
f0103365:	5f                   	pop    %edi
f0103366:	5d                   	pop    %ebp
f0103367:	c3                   	ret    

f0103368 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0103368:	55                   	push   %ebp
f0103369:	89 e5                	mov    %esp,%ebp
f010336b:	83 ec 28             	sub    $0x28,%esp
f010336e:	8b 45 08             	mov    0x8(%ebp),%eax
f0103371:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0103374:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0103377:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f010337b:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f010337e:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0103385:	85 c0                	test   %eax,%eax
f0103387:	74 30                	je     f01033b9 <vsnprintf+0x51>
f0103389:	85 d2                	test   %edx,%edx
f010338b:	7e 2c                	jle    f01033b9 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f010338d:	8b 45 14             	mov    0x14(%ebp),%eax
f0103390:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103394:	8b 45 10             	mov    0x10(%ebp),%eax
f0103397:	89 44 24 08          	mov    %eax,0x8(%esp)
f010339b:	8d 45 ec             	lea    -0x14(%ebp),%eax
f010339e:	89 44 24 04          	mov    %eax,0x4(%esp)
f01033a2:	c7 04 24 3f 2f 10 f0 	movl   $0xf0102f3f,(%esp)
f01033a9:	e8 d6 fb ff ff       	call   f0102f84 <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f01033ae:	8b 45 ec             	mov    -0x14(%ebp),%eax
f01033b1:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f01033b4:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01033b7:	eb 05                	jmp    f01033be <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f01033b9:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f01033be:	c9                   	leave  
f01033bf:	c3                   	ret    

f01033c0 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f01033c0:	55                   	push   %ebp
f01033c1:	89 e5                	mov    %esp,%ebp
f01033c3:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f01033c6:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f01033c9:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01033cd:	8b 45 10             	mov    0x10(%ebp),%eax
f01033d0:	89 44 24 08          	mov    %eax,0x8(%esp)
f01033d4:	8b 45 0c             	mov    0xc(%ebp),%eax
f01033d7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01033db:	8b 45 08             	mov    0x8(%ebp),%eax
f01033de:	89 04 24             	mov    %eax,(%esp)
f01033e1:	e8 82 ff ff ff       	call   f0103368 <vsnprintf>
	va_end(ap);

	return rc;
}
f01033e6:	c9                   	leave  
f01033e7:	c3                   	ret    
f01033e8:	66 90                	xchg   %ax,%ax
f01033ea:	66 90                	xchg   %ax,%ax
f01033ec:	66 90                	xchg   %ax,%ax
f01033ee:	66 90                	xchg   %ax,%ax

f01033f0 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f01033f0:	55                   	push   %ebp
f01033f1:	89 e5                	mov    %esp,%ebp
f01033f3:	57                   	push   %edi
f01033f4:	56                   	push   %esi
f01033f5:	53                   	push   %ebx
f01033f6:	83 ec 1c             	sub    $0x1c,%esp
f01033f9:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f01033fc:	85 c0                	test   %eax,%eax
f01033fe:	74 10                	je     f0103410 <readline+0x20>
		cprintf("%s", prompt);
f0103400:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103404:	c7 04 24 7e 4c 10 f0 	movl   $0xf0104c7e,(%esp)
f010340b:	e8 64 eb ff ff       	call   f0101f74 <cprintf>

	i = 0;
	echoing = iscons(0);
f0103410:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0103417:	e8 c2 d3 ff ff       	call   f01007de <iscons>
f010341c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f010341e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0103423:	e8 a5 d3 ff ff       	call   f01007cd <getchar>
f0103428:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f010342a:	85 c0                	test   %eax,%eax
f010342c:	79 17                	jns    f0103445 <readline+0x55>
			cprintf("read error: %e\n", c);
f010342e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103432:	c7 04 24 a4 54 10 f0 	movl   $0xf01054a4,(%esp)
f0103439:	e8 36 eb ff ff       	call   f0101f74 <cprintf>
			return NULL;
f010343e:	b8 00 00 00 00       	mov    $0x0,%eax
f0103443:	eb 6d                	jmp    f01034b2 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0103445:	83 f8 7f             	cmp    $0x7f,%eax
f0103448:	74 05                	je     f010344f <readline+0x5f>
f010344a:	83 f8 08             	cmp    $0x8,%eax
f010344d:	75 19                	jne    f0103468 <readline+0x78>
f010344f:	85 f6                	test   %esi,%esi
f0103451:	7e 15                	jle    f0103468 <readline+0x78>
			if (echoing)
f0103453:	85 ff                	test   %edi,%edi
f0103455:	74 0c                	je     f0103463 <readline+0x73>
				cputchar('\b');
f0103457:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f010345e:	e8 5a d3 ff ff       	call   f01007bd <cputchar>
			i--;
f0103463:	83 ee 01             	sub    $0x1,%esi
f0103466:	eb bb                	jmp    f0103423 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0103468:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f010346e:	7f 1c                	jg     f010348c <readline+0x9c>
f0103470:	83 fb 1f             	cmp    $0x1f,%ebx
f0103473:	7e 17                	jle    f010348c <readline+0x9c>
			if (echoing)
f0103475:	85 ff                	test   %edi,%edi
f0103477:	74 08                	je     f0103481 <readline+0x91>
				cputchar(c);
f0103479:	89 1c 24             	mov    %ebx,(%esp)
f010347c:	e8 3c d3 ff ff       	call   f01007bd <cputchar>
			buf[i++] = c;
f0103481:	88 9e 00 fb 21 f0    	mov    %bl,-0xfde0500(%esi)
f0103487:	8d 76 01             	lea    0x1(%esi),%esi
f010348a:	eb 97                	jmp    f0103423 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f010348c:	83 fb 0d             	cmp    $0xd,%ebx
f010348f:	74 05                	je     f0103496 <readline+0xa6>
f0103491:	83 fb 0a             	cmp    $0xa,%ebx
f0103494:	75 8d                	jne    f0103423 <readline+0x33>
			if (echoing)
f0103496:	85 ff                	test   %edi,%edi
f0103498:	74 0c                	je     f01034a6 <readline+0xb6>
				cputchar('\n');
f010349a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f01034a1:	e8 17 d3 ff ff       	call   f01007bd <cputchar>
			buf[i] = 0;
f01034a6:	c6 86 00 fb 21 f0 00 	movb   $0x0,-0xfde0500(%esi)
			return buf;
f01034ad:	b8 00 fb 21 f0       	mov    $0xf021fb00,%eax
		}
	}
}
f01034b2:	83 c4 1c             	add    $0x1c,%esp
f01034b5:	5b                   	pop    %ebx
f01034b6:	5e                   	pop    %esi
f01034b7:	5f                   	pop    %edi
f01034b8:	5d                   	pop    %ebp
f01034b9:	c3                   	ret    
f01034ba:	66 90                	xchg   %ax,%ax
f01034bc:	66 90                	xchg   %ax,%ax
f01034be:	66 90                	xchg   %ax,%ax

f01034c0 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f01034c0:	55                   	push   %ebp
f01034c1:	89 e5                	mov    %esp,%ebp
f01034c3:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f01034c6:	80 3a 00             	cmpb   $0x0,(%edx)
f01034c9:	74 10                	je     f01034db <strlen+0x1b>
f01034cb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f01034d0:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f01034d3:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f01034d7:	75 f7                	jne    f01034d0 <strlen+0x10>
f01034d9:	eb 05                	jmp    f01034e0 <strlen+0x20>
f01034db:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f01034e0:	5d                   	pop    %ebp
f01034e1:	c3                   	ret    

f01034e2 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f01034e2:	55                   	push   %ebp
f01034e3:	89 e5                	mov    %esp,%ebp
f01034e5:	53                   	push   %ebx
f01034e6:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01034e9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01034ec:	85 c9                	test   %ecx,%ecx
f01034ee:	74 1c                	je     f010350c <strnlen+0x2a>
f01034f0:	80 3b 00             	cmpb   $0x0,(%ebx)
f01034f3:	74 1e                	je     f0103513 <strnlen+0x31>
f01034f5:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f01034fa:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01034fc:	39 ca                	cmp    %ecx,%edx
f01034fe:	74 18                	je     f0103518 <strnlen+0x36>
f0103500:	83 c2 01             	add    $0x1,%edx
f0103503:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0103508:	75 f0                	jne    f01034fa <strnlen+0x18>
f010350a:	eb 0c                	jmp    f0103518 <strnlen+0x36>
f010350c:	b8 00 00 00 00       	mov    $0x0,%eax
f0103511:	eb 05                	jmp    f0103518 <strnlen+0x36>
f0103513:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0103518:	5b                   	pop    %ebx
f0103519:	5d                   	pop    %ebp
f010351a:	c3                   	ret    

f010351b <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f010351b:	55                   	push   %ebp
f010351c:	89 e5                	mov    %esp,%ebp
f010351e:	53                   	push   %ebx
f010351f:	8b 45 08             	mov    0x8(%ebp),%eax
f0103522:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0103525:	89 c2                	mov    %eax,%edx
f0103527:	83 c2 01             	add    $0x1,%edx
f010352a:	83 c1 01             	add    $0x1,%ecx
f010352d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0103531:	88 5a ff             	mov    %bl,-0x1(%edx)
f0103534:	84 db                	test   %bl,%bl
f0103536:	75 ef                	jne    f0103527 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0103538:	5b                   	pop    %ebx
f0103539:	5d                   	pop    %ebp
f010353a:	c3                   	ret    

f010353b <strcat>:

char *
strcat(char *dst, const char *src)
{
f010353b:	55                   	push   %ebp
f010353c:	89 e5                	mov    %esp,%ebp
f010353e:	53                   	push   %ebx
f010353f:	83 ec 08             	sub    $0x8,%esp
f0103542:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f0103545:	89 1c 24             	mov    %ebx,(%esp)
f0103548:	e8 73 ff ff ff       	call   f01034c0 <strlen>
	strcpy(dst + len, src);
f010354d:	8b 55 0c             	mov    0xc(%ebp),%edx
f0103550:	89 54 24 04          	mov    %edx,0x4(%esp)
f0103554:	01 d8                	add    %ebx,%eax
f0103556:	89 04 24             	mov    %eax,(%esp)
f0103559:	e8 bd ff ff ff       	call   f010351b <strcpy>
	return dst;
}
f010355e:	89 d8                	mov    %ebx,%eax
f0103560:	83 c4 08             	add    $0x8,%esp
f0103563:	5b                   	pop    %ebx
f0103564:	5d                   	pop    %ebp
f0103565:	c3                   	ret    

f0103566 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f0103566:	55                   	push   %ebp
f0103567:	89 e5                	mov    %esp,%ebp
f0103569:	56                   	push   %esi
f010356a:	53                   	push   %ebx
f010356b:	8b 75 08             	mov    0x8(%ebp),%esi
f010356e:	8b 55 0c             	mov    0xc(%ebp),%edx
f0103571:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0103574:	85 db                	test   %ebx,%ebx
f0103576:	74 17                	je     f010358f <strncpy+0x29>
f0103578:	01 f3                	add    %esi,%ebx
f010357a:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f010357c:	83 c1 01             	add    $0x1,%ecx
f010357f:	0f b6 02             	movzbl (%edx),%eax
f0103582:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f0103585:	80 3a 01             	cmpb   $0x1,(%edx)
f0103588:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f010358b:	39 d9                	cmp    %ebx,%ecx
f010358d:	75 ed                	jne    f010357c <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f010358f:	89 f0                	mov    %esi,%eax
f0103591:	5b                   	pop    %ebx
f0103592:	5e                   	pop    %esi
f0103593:	5d                   	pop    %ebp
f0103594:	c3                   	ret    

f0103595 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f0103595:	55                   	push   %ebp
f0103596:	89 e5                	mov    %esp,%ebp
f0103598:	57                   	push   %edi
f0103599:	56                   	push   %esi
f010359a:	53                   	push   %ebx
f010359b:	8b 7d 08             	mov    0x8(%ebp),%edi
f010359e:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01035a1:	8b 75 10             	mov    0x10(%ebp),%esi
f01035a4:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f01035a6:	85 f6                	test   %esi,%esi
f01035a8:	74 34                	je     f01035de <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f01035aa:	83 fe 01             	cmp    $0x1,%esi
f01035ad:	74 26                	je     f01035d5 <strlcpy+0x40>
f01035af:	0f b6 0b             	movzbl (%ebx),%ecx
f01035b2:	84 c9                	test   %cl,%cl
f01035b4:	74 23                	je     f01035d9 <strlcpy+0x44>
f01035b6:	83 ee 02             	sub    $0x2,%esi
f01035b9:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f01035be:	83 c0 01             	add    $0x1,%eax
f01035c1:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f01035c4:	39 f2                	cmp    %esi,%edx
f01035c6:	74 13                	je     f01035db <strlcpy+0x46>
f01035c8:	83 c2 01             	add    $0x1,%edx
f01035cb:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f01035cf:	84 c9                	test   %cl,%cl
f01035d1:	75 eb                	jne    f01035be <strlcpy+0x29>
f01035d3:	eb 06                	jmp    f01035db <strlcpy+0x46>
f01035d5:	89 f8                	mov    %edi,%eax
f01035d7:	eb 02                	jmp    f01035db <strlcpy+0x46>
f01035d9:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f01035db:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f01035de:	29 f8                	sub    %edi,%eax
}
f01035e0:	5b                   	pop    %ebx
f01035e1:	5e                   	pop    %esi
f01035e2:	5f                   	pop    %edi
f01035e3:	5d                   	pop    %ebp
f01035e4:	c3                   	ret    

f01035e5 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f01035e5:	55                   	push   %ebp
f01035e6:	89 e5                	mov    %esp,%ebp
f01035e8:	8b 4d 08             	mov    0x8(%ebp),%ecx
f01035eb:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f01035ee:	0f b6 01             	movzbl (%ecx),%eax
f01035f1:	84 c0                	test   %al,%al
f01035f3:	74 15                	je     f010360a <strcmp+0x25>
f01035f5:	3a 02                	cmp    (%edx),%al
f01035f7:	75 11                	jne    f010360a <strcmp+0x25>
		p++, q++;
f01035f9:	83 c1 01             	add    $0x1,%ecx
f01035fc:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f01035ff:	0f b6 01             	movzbl (%ecx),%eax
f0103602:	84 c0                	test   %al,%al
f0103604:	74 04                	je     f010360a <strcmp+0x25>
f0103606:	3a 02                	cmp    (%edx),%al
f0103608:	74 ef                	je     f01035f9 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f010360a:	0f b6 c0             	movzbl %al,%eax
f010360d:	0f b6 12             	movzbl (%edx),%edx
f0103610:	29 d0                	sub    %edx,%eax
}
f0103612:	5d                   	pop    %ebp
f0103613:	c3                   	ret    

f0103614 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0103614:	55                   	push   %ebp
f0103615:	89 e5                	mov    %esp,%ebp
f0103617:	56                   	push   %esi
f0103618:	53                   	push   %ebx
f0103619:	8b 5d 08             	mov    0x8(%ebp),%ebx
f010361c:	8b 55 0c             	mov    0xc(%ebp),%edx
f010361f:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f0103622:	85 f6                	test   %esi,%esi
f0103624:	74 29                	je     f010364f <strncmp+0x3b>
f0103626:	0f b6 03             	movzbl (%ebx),%eax
f0103629:	84 c0                	test   %al,%al
f010362b:	74 30                	je     f010365d <strncmp+0x49>
f010362d:	3a 02                	cmp    (%edx),%al
f010362f:	75 2c                	jne    f010365d <strncmp+0x49>
f0103631:	8d 43 01             	lea    0x1(%ebx),%eax
f0103634:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f0103636:	89 c3                	mov    %eax,%ebx
f0103638:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f010363b:	39 f0                	cmp    %esi,%eax
f010363d:	74 17                	je     f0103656 <strncmp+0x42>
f010363f:	0f b6 08             	movzbl (%eax),%ecx
f0103642:	84 c9                	test   %cl,%cl
f0103644:	74 17                	je     f010365d <strncmp+0x49>
f0103646:	83 c0 01             	add    $0x1,%eax
f0103649:	3a 0a                	cmp    (%edx),%cl
f010364b:	74 e9                	je     f0103636 <strncmp+0x22>
f010364d:	eb 0e                	jmp    f010365d <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f010364f:	b8 00 00 00 00       	mov    $0x0,%eax
f0103654:	eb 0f                	jmp    f0103665 <strncmp+0x51>
f0103656:	b8 00 00 00 00       	mov    $0x0,%eax
f010365b:	eb 08                	jmp    f0103665 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f010365d:	0f b6 03             	movzbl (%ebx),%eax
f0103660:	0f b6 12             	movzbl (%edx),%edx
f0103663:	29 d0                	sub    %edx,%eax
}
f0103665:	5b                   	pop    %ebx
f0103666:	5e                   	pop    %esi
f0103667:	5d                   	pop    %ebp
f0103668:	c3                   	ret    

f0103669 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f0103669:	55                   	push   %ebp
f010366a:	89 e5                	mov    %esp,%ebp
f010366c:	53                   	push   %ebx
f010366d:	8b 45 08             	mov    0x8(%ebp),%eax
f0103670:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0103673:	0f b6 18             	movzbl (%eax),%ebx
f0103676:	84 db                	test   %bl,%bl
f0103678:	74 1d                	je     f0103697 <strchr+0x2e>
f010367a:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f010367c:	38 d3                	cmp    %dl,%bl
f010367e:	75 06                	jne    f0103686 <strchr+0x1d>
f0103680:	eb 1a                	jmp    f010369c <strchr+0x33>
f0103682:	38 ca                	cmp    %cl,%dl
f0103684:	74 16                	je     f010369c <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0103686:	83 c0 01             	add    $0x1,%eax
f0103689:	0f b6 10             	movzbl (%eax),%edx
f010368c:	84 d2                	test   %dl,%dl
f010368e:	75 f2                	jne    f0103682 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0103690:	b8 00 00 00 00       	mov    $0x0,%eax
f0103695:	eb 05                	jmp    f010369c <strchr+0x33>
f0103697:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010369c:	5b                   	pop    %ebx
f010369d:	5d                   	pop    %ebp
f010369e:	c3                   	ret    

f010369f <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f010369f:	55                   	push   %ebp
f01036a0:	89 e5                	mov    %esp,%ebp
f01036a2:	53                   	push   %ebx
f01036a3:	8b 45 08             	mov    0x8(%ebp),%eax
f01036a6:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f01036a9:	0f b6 18             	movzbl (%eax),%ebx
f01036ac:	84 db                	test   %bl,%bl
f01036ae:	74 16                	je     f01036c6 <strfind+0x27>
f01036b0:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f01036b2:	38 d3                	cmp    %dl,%bl
f01036b4:	75 06                	jne    f01036bc <strfind+0x1d>
f01036b6:	eb 0e                	jmp    f01036c6 <strfind+0x27>
f01036b8:	38 ca                	cmp    %cl,%dl
f01036ba:	74 0a                	je     f01036c6 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f01036bc:	83 c0 01             	add    $0x1,%eax
f01036bf:	0f b6 10             	movzbl (%eax),%edx
f01036c2:	84 d2                	test   %dl,%dl
f01036c4:	75 f2                	jne    f01036b8 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f01036c6:	5b                   	pop    %ebx
f01036c7:	5d                   	pop    %ebp
f01036c8:	c3                   	ret    

f01036c9 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f01036c9:	55                   	push   %ebp
f01036ca:	89 e5                	mov    %esp,%ebp
f01036cc:	57                   	push   %edi
f01036cd:	56                   	push   %esi
f01036ce:	53                   	push   %ebx
f01036cf:	8b 7d 08             	mov    0x8(%ebp),%edi
f01036d2:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f01036d5:	85 c9                	test   %ecx,%ecx
f01036d7:	74 36                	je     f010370f <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f01036d9:	f7 c7 03 00 00 00    	test   $0x3,%edi
f01036df:	75 28                	jne    f0103709 <memset+0x40>
f01036e1:	f6 c1 03             	test   $0x3,%cl
f01036e4:	75 23                	jne    f0103709 <memset+0x40>
		c &= 0xFF;
f01036e6:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f01036ea:	89 d3                	mov    %edx,%ebx
f01036ec:	c1 e3 08             	shl    $0x8,%ebx
f01036ef:	89 d6                	mov    %edx,%esi
f01036f1:	c1 e6 18             	shl    $0x18,%esi
f01036f4:	89 d0                	mov    %edx,%eax
f01036f6:	c1 e0 10             	shl    $0x10,%eax
f01036f9:	09 f0                	or     %esi,%eax
f01036fb:	09 c2                	or     %eax,%edx
f01036fd:	89 d0                	mov    %edx,%eax
f01036ff:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f0103701:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0103704:	fc                   	cld    
f0103705:	f3 ab                	rep stos %eax,%es:(%edi)
f0103707:	eb 06                	jmp    f010370f <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0103709:	8b 45 0c             	mov    0xc(%ebp),%eax
f010370c:	fc                   	cld    
f010370d:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f010370f:	89 f8                	mov    %edi,%eax
f0103711:	5b                   	pop    %ebx
f0103712:	5e                   	pop    %esi
f0103713:	5f                   	pop    %edi
f0103714:	5d                   	pop    %ebp
f0103715:	c3                   	ret    

f0103716 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0103716:	55                   	push   %ebp
f0103717:	89 e5                	mov    %esp,%ebp
f0103719:	57                   	push   %edi
f010371a:	56                   	push   %esi
f010371b:	8b 45 08             	mov    0x8(%ebp),%eax
f010371e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0103721:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0103724:	39 c6                	cmp    %eax,%esi
f0103726:	73 35                	jae    f010375d <memmove+0x47>
f0103728:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f010372b:	39 d0                	cmp    %edx,%eax
f010372d:	73 2e                	jae    f010375d <memmove+0x47>
		s += n;
		d += n;
f010372f:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0103732:	89 d6                	mov    %edx,%esi
f0103734:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0103736:	f7 c6 03 00 00 00    	test   $0x3,%esi
f010373c:	75 13                	jne    f0103751 <memmove+0x3b>
f010373e:	f6 c1 03             	test   $0x3,%cl
f0103741:	75 0e                	jne    f0103751 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0103743:	83 ef 04             	sub    $0x4,%edi
f0103746:	8d 72 fc             	lea    -0x4(%edx),%esi
f0103749:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f010374c:	fd                   	std    
f010374d:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f010374f:	eb 09                	jmp    f010375a <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0103751:	83 ef 01             	sub    $0x1,%edi
f0103754:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0103757:	fd                   	std    
f0103758:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f010375a:	fc                   	cld    
f010375b:	eb 1d                	jmp    f010377a <memmove+0x64>
f010375d:	89 f2                	mov    %esi,%edx
f010375f:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0103761:	f6 c2 03             	test   $0x3,%dl
f0103764:	75 0f                	jne    f0103775 <memmove+0x5f>
f0103766:	f6 c1 03             	test   $0x3,%cl
f0103769:	75 0a                	jne    f0103775 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f010376b:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f010376e:	89 c7                	mov    %eax,%edi
f0103770:	fc                   	cld    
f0103771:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0103773:	eb 05                	jmp    f010377a <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0103775:	89 c7                	mov    %eax,%edi
f0103777:	fc                   	cld    
f0103778:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f010377a:	5e                   	pop    %esi
f010377b:	5f                   	pop    %edi
f010377c:	5d                   	pop    %ebp
f010377d:	c3                   	ret    

f010377e <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f010377e:	55                   	push   %ebp
f010377f:	89 e5                	mov    %esp,%ebp
f0103781:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0103784:	8b 45 10             	mov    0x10(%ebp),%eax
f0103787:	89 44 24 08          	mov    %eax,0x8(%esp)
f010378b:	8b 45 0c             	mov    0xc(%ebp),%eax
f010378e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103792:	8b 45 08             	mov    0x8(%ebp),%eax
f0103795:	89 04 24             	mov    %eax,(%esp)
f0103798:	e8 79 ff ff ff       	call   f0103716 <memmove>
}
f010379d:	c9                   	leave  
f010379e:	c3                   	ret    

f010379f <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f010379f:	55                   	push   %ebp
f01037a0:	89 e5                	mov    %esp,%ebp
f01037a2:	57                   	push   %edi
f01037a3:	56                   	push   %esi
f01037a4:	53                   	push   %ebx
f01037a5:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01037a8:	8b 75 0c             	mov    0xc(%ebp),%esi
f01037ab:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01037ae:	8d 78 ff             	lea    -0x1(%eax),%edi
f01037b1:	85 c0                	test   %eax,%eax
f01037b3:	74 36                	je     f01037eb <memcmp+0x4c>
		if (*s1 != *s2)
f01037b5:	0f b6 03             	movzbl (%ebx),%eax
f01037b8:	0f b6 0e             	movzbl (%esi),%ecx
f01037bb:	ba 00 00 00 00       	mov    $0x0,%edx
f01037c0:	38 c8                	cmp    %cl,%al
f01037c2:	74 1c                	je     f01037e0 <memcmp+0x41>
f01037c4:	eb 10                	jmp    f01037d6 <memcmp+0x37>
f01037c6:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f01037cb:	83 c2 01             	add    $0x1,%edx
f01037ce:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f01037d2:	38 c8                	cmp    %cl,%al
f01037d4:	74 0a                	je     f01037e0 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f01037d6:	0f b6 c0             	movzbl %al,%eax
f01037d9:	0f b6 c9             	movzbl %cl,%ecx
f01037dc:	29 c8                	sub    %ecx,%eax
f01037de:	eb 10                	jmp    f01037f0 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01037e0:	39 fa                	cmp    %edi,%edx
f01037e2:	75 e2                	jne    f01037c6 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f01037e4:	b8 00 00 00 00       	mov    $0x0,%eax
f01037e9:	eb 05                	jmp    f01037f0 <memcmp+0x51>
f01037eb:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01037f0:	5b                   	pop    %ebx
f01037f1:	5e                   	pop    %esi
f01037f2:	5f                   	pop    %edi
f01037f3:	5d                   	pop    %ebp
f01037f4:	c3                   	ret    

f01037f5 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f01037f5:	55                   	push   %ebp
f01037f6:	89 e5                	mov    %esp,%ebp
f01037f8:	53                   	push   %ebx
f01037f9:	8b 45 08             	mov    0x8(%ebp),%eax
f01037fc:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f01037ff:	89 c2                	mov    %eax,%edx
f0103801:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0103804:	39 d0                	cmp    %edx,%eax
f0103806:	73 13                	jae    f010381b <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f0103808:	89 d9                	mov    %ebx,%ecx
f010380a:	38 18                	cmp    %bl,(%eax)
f010380c:	75 06                	jne    f0103814 <memfind+0x1f>
f010380e:	eb 0b                	jmp    f010381b <memfind+0x26>
f0103810:	38 08                	cmp    %cl,(%eax)
f0103812:	74 07                	je     f010381b <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f0103814:	83 c0 01             	add    $0x1,%eax
f0103817:	39 d0                	cmp    %edx,%eax
f0103819:	75 f5                	jne    f0103810 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f010381b:	5b                   	pop    %ebx
f010381c:	5d                   	pop    %ebp
f010381d:	c3                   	ret    

f010381e <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f010381e:	55                   	push   %ebp
f010381f:	89 e5                	mov    %esp,%ebp
f0103821:	57                   	push   %edi
f0103822:	56                   	push   %esi
f0103823:	53                   	push   %ebx
f0103824:	8b 55 08             	mov    0x8(%ebp),%edx
f0103827:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010382a:	0f b6 0a             	movzbl (%edx),%ecx
f010382d:	80 f9 09             	cmp    $0x9,%cl
f0103830:	74 05                	je     f0103837 <strtol+0x19>
f0103832:	80 f9 20             	cmp    $0x20,%cl
f0103835:	75 10                	jne    f0103847 <strtol+0x29>
		s++;
f0103837:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010383a:	0f b6 0a             	movzbl (%edx),%ecx
f010383d:	80 f9 09             	cmp    $0x9,%cl
f0103840:	74 f5                	je     f0103837 <strtol+0x19>
f0103842:	80 f9 20             	cmp    $0x20,%cl
f0103845:	74 f0                	je     f0103837 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f0103847:	80 f9 2b             	cmp    $0x2b,%cl
f010384a:	75 0a                	jne    f0103856 <strtol+0x38>
		s++;
f010384c:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f010384f:	bf 00 00 00 00       	mov    $0x0,%edi
f0103854:	eb 11                	jmp    f0103867 <strtol+0x49>
f0103856:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f010385b:	80 f9 2d             	cmp    $0x2d,%cl
f010385e:	75 07                	jne    f0103867 <strtol+0x49>
		s++, neg = 1;
f0103860:	83 c2 01             	add    $0x1,%edx
f0103863:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0103867:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f010386c:	75 15                	jne    f0103883 <strtol+0x65>
f010386e:	80 3a 30             	cmpb   $0x30,(%edx)
f0103871:	75 10                	jne    f0103883 <strtol+0x65>
f0103873:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0103877:	75 0a                	jne    f0103883 <strtol+0x65>
		s += 2, base = 16;
f0103879:	83 c2 02             	add    $0x2,%edx
f010387c:	b8 10 00 00 00       	mov    $0x10,%eax
f0103881:	eb 10                	jmp    f0103893 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f0103883:	85 c0                	test   %eax,%eax
f0103885:	75 0c                	jne    f0103893 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0103887:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0103889:	80 3a 30             	cmpb   $0x30,(%edx)
f010388c:	75 05                	jne    f0103893 <strtol+0x75>
		s++, base = 8;
f010388e:	83 c2 01             	add    $0x1,%edx
f0103891:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f0103893:	bb 00 00 00 00       	mov    $0x0,%ebx
f0103898:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f010389b:	0f b6 0a             	movzbl (%edx),%ecx
f010389e:	8d 71 d0             	lea    -0x30(%ecx),%esi
f01038a1:	89 f0                	mov    %esi,%eax
f01038a3:	3c 09                	cmp    $0x9,%al
f01038a5:	77 08                	ja     f01038af <strtol+0x91>
			dig = *s - '0';
f01038a7:	0f be c9             	movsbl %cl,%ecx
f01038aa:	83 e9 30             	sub    $0x30,%ecx
f01038ad:	eb 20                	jmp    f01038cf <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f01038af:	8d 71 9f             	lea    -0x61(%ecx),%esi
f01038b2:	89 f0                	mov    %esi,%eax
f01038b4:	3c 19                	cmp    $0x19,%al
f01038b6:	77 08                	ja     f01038c0 <strtol+0xa2>
			dig = *s - 'a' + 10;
f01038b8:	0f be c9             	movsbl %cl,%ecx
f01038bb:	83 e9 57             	sub    $0x57,%ecx
f01038be:	eb 0f                	jmp    f01038cf <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f01038c0:	8d 71 bf             	lea    -0x41(%ecx),%esi
f01038c3:	89 f0                	mov    %esi,%eax
f01038c5:	3c 19                	cmp    $0x19,%al
f01038c7:	77 16                	ja     f01038df <strtol+0xc1>
			dig = *s - 'A' + 10;
f01038c9:	0f be c9             	movsbl %cl,%ecx
f01038cc:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f01038cf:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f01038d2:	7d 0f                	jge    f01038e3 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f01038d4:	83 c2 01             	add    $0x1,%edx
f01038d7:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f01038db:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f01038dd:	eb bc                	jmp    f010389b <strtol+0x7d>
f01038df:	89 d8                	mov    %ebx,%eax
f01038e1:	eb 02                	jmp    f01038e5 <strtol+0xc7>
f01038e3:	89 d8                	mov    %ebx,%eax

	if (endptr)
f01038e5:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f01038e9:	74 05                	je     f01038f0 <strtol+0xd2>
		*endptr = (char *) s;
f01038eb:	8b 75 0c             	mov    0xc(%ebp),%esi
f01038ee:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f01038f0:	f7 d8                	neg    %eax
f01038f2:	85 ff                	test   %edi,%edi
f01038f4:	0f 44 c3             	cmove  %ebx,%eax
}
f01038f7:	5b                   	pop    %ebx
f01038f8:	5e                   	pop    %esi
f01038f9:	5f                   	pop    %edi
f01038fa:	5d                   	pop    %ebp
f01038fb:	c3                   	ret    

f01038fc <mpentry_start>:
.set PROT_MODE_DSEG, 0x10	# kernel data segment selector

.code16           
.globl mpentry_start
mpentry_start:
	cli            
f01038fc:	fa                   	cli    

	xorw    %ax, %ax
f01038fd:	31 c0                	xor    %eax,%eax
	movw    %ax, %ds
f01038ff:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0103901:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0103903:	8e d0                	mov    %eax,%ss

	lgdt    MPBOOTPHYS(gdtdesc)
f0103905:	0f 01 16             	lgdtl  (%esi)
f0103908:	74 70                	je     f010397a <mpentry_end+0x4>
	movl    %cr0, %eax
f010390a:	0f 20 c0             	mov    %cr0,%eax
	orl     $CR0_PE, %eax
f010390d:	66 83 c8 01          	or     $0x1,%ax
	movl    %eax, %cr0
f0103911:	0f 22 c0             	mov    %eax,%cr0

	ljmpl   $(PROT_MODE_CSEG), $(MPBOOTPHYS(start32))
f0103914:	66 ea 20 70 00 00    	ljmpw  $0x0,$0x7020
f010391a:	08 00                	or     %al,(%eax)

f010391c <start32>:

.code32
start32:
	movw    $(PROT_MODE_DSEG), %ax
f010391c:	66 b8 10 00          	mov    $0x10,%ax
	movw    %ax, %ds
f0103920:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0103922:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0103924:	8e d0                	mov    %eax,%ss
	movw    $0, %ax
f0103926:	66 b8 00 00          	mov    $0x0,%ax
	movw    %ax, %fs
f010392a:	8e e0                	mov    %eax,%fs
	movw    %ax, %gs
f010392c:	8e e8                	mov    %eax,%gs

	# Set up initial page table. We cannot use kern_pgdir yet because
	# we are still running at a low EIP.
	movl    $(RELOC(entry_pgdir)), %eax
f010392e:	b8 00 a0 11 00       	mov    $0x11a000,%eax
	movl    %eax, %cr3
f0103933:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl    %cr0, %eax
f0103936:	0f 20 c0             	mov    %cr0,%eax
	orl     $(CR0_PE|CR0_PG|CR0_WP), %eax
f0103939:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl    %eax, %cr0
f010393e:	0f 22 c0             	mov    %eax,%cr0

	# Switch to the per-cpu stack allocated in mem_init()
	movl    mpentry_kstack, %esp
f0103941:	8b 25 04 ff 21 f0    	mov    0xf021ff04,%esp
	movl    $0x0, %ebp       # nuke frame pointer
f0103947:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Call mp_main().  (Exercise for the reader: why the indirect call?)
	movl    $mp_main, %eax
f010394c:	b8 1d 02 10 f0       	mov    $0xf010021d,%eax
	call    *%eax
f0103951:	ff d0                	call   *%eax

f0103953 <spin>:

	# If mp_main returns (it shouldn't), loop.
spin:
	jmp     spin
f0103953:	eb fe                	jmp    f0103953 <spin>
f0103955:	8d 76 00             	lea    0x0(%esi),%esi

f0103958 <gdt>:
	...
f0103960:	ff                   	(bad)  
f0103961:	ff 00                	incl   (%eax)
f0103963:	00 00                	add    %al,(%eax)
f0103965:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
f010396c:	00 92 cf 00 17 00    	add    %dl,0x1700cf(%edx)

f0103970 <gdtdesc>:
f0103970:	17                   	pop    %ss
f0103971:	00 5c 70 00          	add    %bl,0x0(%eax,%esi,2)
	...

f0103976 <mpentry_end>:
	.word   0x17				# sizeof(gdt) - 1
	.long   MPBOOTPHYS(gdt)			# address gdt

.globl mpentry_end
mpentry_end:
	nop
f0103976:	90                   	nop
f0103977:	66 90                	xchg   %ax,%ax
f0103979:	66 90                	xchg   %ax,%ax
f010397b:	66 90                	xchg   %ax,%ax
f010397d:	66 90                	xchg   %ax,%ax
f010397f:	90                   	nop

f0103980 <mpsearch1>:
}

// Look for an MP structure in the len bytes at physical address addr.
static struct mp *
mpsearch1(physaddr_t a, int len)
{
f0103980:	55                   	push   %ebp
f0103981:	89 e5                	mov    %esp,%ebp
f0103983:	56                   	push   %esi
f0103984:	53                   	push   %ebx
f0103985:	83 ec 10             	sub    $0x10,%esp
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103988:	8b 0d 08 ff 21 f0    	mov    0xf021ff08,%ecx
f010398e:	89 c3                	mov    %eax,%ebx
f0103990:	c1 eb 0c             	shr    $0xc,%ebx
f0103993:	39 cb                	cmp    %ecx,%ebx
f0103995:	72 20                	jb     f01039b7 <mpsearch1+0x37>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103997:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010399b:	c7 44 24 08 84 44 10 	movl   $0xf0104484,0x8(%esp)
f01039a2:	f0 
f01039a3:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f01039aa:	00 
f01039ab:	c7 04 24 41 56 10 f0 	movl   $0xf0105641,(%esp)
f01039b2:	e8 89 c6 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01039b7:	8d 98 00 00 00 f0    	lea    -0x10000000(%eax),%ebx
	struct mp *mp = KADDR(a), *end = KADDR(a + len);
f01039bd:	01 d0                	add    %edx,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01039bf:	89 c2                	mov    %eax,%edx
f01039c1:	c1 ea 0c             	shr    $0xc,%edx
f01039c4:	39 d1                	cmp    %edx,%ecx
f01039c6:	77 20                	ja     f01039e8 <mpsearch1+0x68>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01039c8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01039cc:	c7 44 24 08 84 44 10 	movl   $0xf0104484,0x8(%esp)
f01039d3:	f0 
f01039d4:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f01039db:	00 
f01039dc:	c7 04 24 41 56 10 f0 	movl   $0xf0105641,(%esp)
f01039e3:	e8 58 c6 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01039e8:	8d b0 00 00 00 f0    	lea    -0x10000000(%eax),%esi

	for (; mp < end; mp++)
f01039ee:	39 f3                	cmp    %esi,%ebx
f01039f0:	73 40                	jae    f0103a32 <mpsearch1+0xb2>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f01039f2:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f01039f9:	00 
f01039fa:	c7 44 24 04 51 56 10 	movl   $0xf0105651,0x4(%esp)
f0103a01:	f0 
f0103a02:	89 1c 24             	mov    %ebx,(%esp)
f0103a05:	e8 95 fd ff ff       	call   f010379f <memcmp>
f0103a0a:	85 c0                	test   %eax,%eax
f0103a0c:	75 17                	jne    f0103a25 <mpsearch1+0xa5>
f0103a0e:	ba 00 00 00 00       	mov    $0x0,%edx
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
		sum += ((uint8_t *)addr)[i];
f0103a13:	0f b6 0c 03          	movzbl (%ebx,%eax,1),%ecx
f0103a17:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0103a19:	83 c0 01             	add    $0x1,%eax
f0103a1c:	83 f8 10             	cmp    $0x10,%eax
f0103a1f:	75 f2                	jne    f0103a13 <mpsearch1+0x93>
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0103a21:	84 d2                	test   %dl,%dl
f0103a23:	74 14                	je     f0103a39 <mpsearch1+0xb9>
static struct mp *
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
f0103a25:	83 c3 10             	add    $0x10,%ebx
f0103a28:	39 f3                	cmp    %esi,%ebx
f0103a2a:	72 c6                	jb     f01039f2 <mpsearch1+0x72>
f0103a2c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0103a30:	eb 0b                	jmp    f0103a3d <mpsearch1+0xbd>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
		    sum(mp, sizeof(*mp)) == 0)
			return mp;
	return NULL;
f0103a32:	b8 00 00 00 00       	mov    $0x0,%eax
f0103a37:	eb 09                	jmp    f0103a42 <mpsearch1+0xc2>
f0103a39:	89 d8                	mov    %ebx,%eax
f0103a3b:	eb 05                	jmp    f0103a42 <mpsearch1+0xc2>
f0103a3d:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0103a42:	83 c4 10             	add    $0x10,%esp
f0103a45:	5b                   	pop    %ebx
f0103a46:	5e                   	pop    %esi
f0103a47:	5d                   	pop    %ebp
f0103a48:	c3                   	ret    

f0103a49 <mp_init>:
	return conf;
}

void
mp_init(void)
{
f0103a49:	55                   	push   %ebp
f0103a4a:	89 e5                	mov    %esp,%ebp
f0103a4c:	57                   	push   %edi
f0103a4d:	56                   	push   %esi
f0103a4e:	53                   	push   %ebx
f0103a4f:	83 ec 2c             	sub    $0x2c,%esp
	struct mpconf *conf;
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
f0103a52:	c7 05 c0 03 22 f0 20 	movl   $0xf0220020,0xf02203c0
f0103a59:	00 22 f0 
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103a5c:	83 3d 08 ff 21 f0 00 	cmpl   $0x0,0xf021ff08
f0103a63:	75 24                	jne    f0103a89 <mp_init+0x40>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103a65:	c7 44 24 0c 00 04 00 	movl   $0x400,0xc(%esp)
f0103a6c:	00 
f0103a6d:	c7 44 24 08 84 44 10 	movl   $0xf0104484,0x8(%esp)
f0103a74:	f0 
f0103a75:	c7 44 24 04 6f 00 00 	movl   $0x6f,0x4(%esp)
f0103a7c:	00 
f0103a7d:	c7 04 24 41 56 10 f0 	movl   $0xf0105641,(%esp)
f0103a84:	e8 b7 c5 ff ff       	call   f0100040 <_panic>
	// The BIOS data area lives in 16-bit segment 0x40.
	bda = (uint8_t *) KADDR(0x40 << 4);

	// [MP 4] The 16-bit segment of the EBDA is in the two bytes
	// starting at byte 0x0E of the BDA.  0 if not present.
	if ((p = *(uint16_t *) (bda + 0x0E))) {
f0103a89:	0f b7 05 0e 04 00 f0 	movzwl 0xf000040e,%eax
f0103a90:	85 c0                	test   %eax,%eax
f0103a92:	74 16                	je     f0103aaa <mp_init+0x61>
		p <<= 4;	// Translate from segment to PA
f0103a94:	c1 e0 04             	shl    $0x4,%eax
		if ((mp = mpsearch1(p, 1024)))
f0103a97:	ba 00 04 00 00       	mov    $0x400,%edx
f0103a9c:	e8 df fe ff ff       	call   f0103980 <mpsearch1>
f0103aa1:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0103aa4:	85 c0                	test   %eax,%eax
f0103aa6:	75 3c                	jne    f0103ae4 <mp_init+0x9b>
f0103aa8:	eb 20                	jmp    f0103aca <mp_init+0x81>
			return mp;
	} else {
		// The size of base memory, in KB is in the two bytes
		// starting at 0x13 of the BDA.
		p = *(uint16_t *) (bda + 0x13) * 1024;
f0103aaa:	0f b7 05 13 04 00 f0 	movzwl 0xf0000413,%eax
f0103ab1:	c1 e0 0a             	shl    $0xa,%eax
		if ((mp = mpsearch1(p - 1024, 1024)))
f0103ab4:	2d 00 04 00 00       	sub    $0x400,%eax
f0103ab9:	ba 00 04 00 00       	mov    $0x400,%edx
f0103abe:	e8 bd fe ff ff       	call   f0103980 <mpsearch1>
f0103ac3:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0103ac6:	85 c0                	test   %eax,%eax
f0103ac8:	75 1a                	jne    f0103ae4 <mp_init+0x9b>
			return mp;
	}
	return mpsearch1(0xF0000, 0x10000);
f0103aca:	ba 00 00 01 00       	mov    $0x10000,%edx
f0103acf:	b8 00 00 0f 00       	mov    $0xf0000,%eax
f0103ad4:	e8 a7 fe ff ff       	call   f0103980 <mpsearch1>
f0103ad9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
mpconfig(struct mp **pmp)
{
	struct mpconf *conf;
	struct mp *mp;

	if ((mp = mpsearch()) == 0)
f0103adc:	85 c0                	test   %eax,%eax
f0103ade:	0f 84 5f 02 00 00    	je     f0103d43 <mp_init+0x2fa>
		return NULL;
	if (mp->physaddr == 0 || mp->type != 0) {
f0103ae4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103ae7:	8b 70 04             	mov    0x4(%eax),%esi
f0103aea:	85 f6                	test   %esi,%esi
f0103aec:	74 06                	je     f0103af4 <mp_init+0xab>
f0103aee:	80 78 0b 00          	cmpb   $0x0,0xb(%eax)
f0103af2:	74 11                	je     f0103b05 <mp_init+0xbc>
		cprintf("SMP: Default configurations not implemented\n");
f0103af4:	c7 04 24 b4 54 10 f0 	movl   $0xf01054b4,(%esp)
f0103afb:	e8 74 e4 ff ff       	call   f0101f74 <cprintf>
f0103b00:	e9 3e 02 00 00       	jmp    f0103d43 <mp_init+0x2fa>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103b05:	89 f0                	mov    %esi,%eax
f0103b07:	c1 e8 0c             	shr    $0xc,%eax
f0103b0a:	3b 05 08 ff 21 f0    	cmp    0xf021ff08,%eax
f0103b10:	72 20                	jb     f0103b32 <mp_init+0xe9>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103b12:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0103b16:	c7 44 24 08 84 44 10 	movl   $0xf0104484,0x8(%esp)
f0103b1d:	f0 
f0103b1e:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f0103b25:	00 
f0103b26:	c7 04 24 41 56 10 f0 	movl   $0xf0105641,(%esp)
f0103b2d:	e8 0e c5 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0103b32:	8d 9e 00 00 00 f0    	lea    -0x10000000(%esi),%ebx
		return NULL;
	}
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
f0103b38:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0103b3f:	00 
f0103b40:	c7 44 24 04 56 56 10 	movl   $0xf0105656,0x4(%esp)
f0103b47:	f0 
f0103b48:	89 1c 24             	mov    %ebx,(%esp)
f0103b4b:	e8 4f fc ff ff       	call   f010379f <memcmp>
f0103b50:	85 c0                	test   %eax,%eax
f0103b52:	74 11                	je     f0103b65 <mp_init+0x11c>
		cprintf("SMP: Incorrect MP configuration table signature\n");
f0103b54:	c7 04 24 e4 54 10 f0 	movl   $0xf01054e4,(%esp)
f0103b5b:	e8 14 e4 ff ff       	call   f0101f74 <cprintf>
f0103b60:	e9 de 01 00 00       	jmp    f0103d43 <mp_init+0x2fa>
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0103b65:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0103b69:	66 89 45 e2          	mov    %ax,-0x1e(%ebp)
f0103b6d:	0f b7 f8             	movzwl %ax,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0103b70:	85 ff                	test   %edi,%edi
f0103b72:	7e 30                	jle    f0103ba4 <mp_init+0x15b>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0103b74:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0103b79:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0103b7e:	0f b6 8c 30 00 00 00 	movzbl -0x10000000(%eax,%esi,1),%ecx
f0103b85:	f0 
f0103b86:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0103b88:	83 c0 01             	add    $0x1,%eax
f0103b8b:	39 c7                	cmp    %eax,%edi
f0103b8d:	7f ef                	jg     f0103b7e <mp_init+0x135>
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
		cprintf("SMP: Incorrect MP configuration table signature\n");
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0103b8f:	84 d2                	test   %dl,%dl
f0103b91:	74 11                	je     f0103ba4 <mp_init+0x15b>
		cprintf("SMP: Bad MP configuration checksum\n");
f0103b93:	c7 04 24 18 55 10 f0 	movl   $0xf0105518,(%esp)
f0103b9a:	e8 d5 e3 ff ff       	call   f0101f74 <cprintf>
f0103b9f:	e9 9f 01 00 00       	jmp    f0103d43 <mp_init+0x2fa>
		return NULL;
	}
	if (conf->version != 1 && conf->version != 4) {
f0103ba4:	0f b6 43 06          	movzbl 0x6(%ebx),%eax
f0103ba8:	3c 04                	cmp    $0x4,%al
f0103baa:	74 1e                	je     f0103bca <mp_init+0x181>
f0103bac:	3c 01                	cmp    $0x1,%al
f0103bae:	66 90                	xchg   %ax,%ax
f0103bb0:	74 18                	je     f0103bca <mp_init+0x181>
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
f0103bb2:	0f b6 c0             	movzbl %al,%eax
f0103bb5:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103bb9:	c7 04 24 3c 55 10 f0 	movl   $0xf010553c,(%esp)
f0103bc0:	e8 af e3 ff ff       	call   f0101f74 <cprintf>
f0103bc5:	e9 79 01 00 00       	jmp    f0103d43 <mp_init+0x2fa>
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0103bca:	0f b7 73 28          	movzwl 0x28(%ebx),%esi
f0103bce:	0f b7 7d e2          	movzwl -0x1e(%ebp),%edi
f0103bd2:	01 df                	add    %ebx,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0103bd4:	85 f6                	test   %esi,%esi
f0103bd6:	7e 19                	jle    f0103bf1 <mp_init+0x1a8>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0103bd8:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0103bdd:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0103be2:	0f b6 0c 07          	movzbl (%edi,%eax,1),%ecx
f0103be6:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0103be8:	83 c0 01             	add    $0x1,%eax
f0103beb:	39 c6                	cmp    %eax,%esi
f0103bed:	7f f3                	jg     f0103be2 <mp_init+0x199>
f0103bef:	eb 05                	jmp    f0103bf6 <mp_init+0x1ad>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0103bf1:	ba 00 00 00 00       	mov    $0x0,%edx
	}
	if (conf->version != 1 && conf->version != 4) {
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0103bf6:	38 53 2a             	cmp    %dl,0x2a(%ebx)
f0103bf9:	74 11                	je     f0103c0c <mp_init+0x1c3>
		cprintf("SMP: Bad MP configuration extended checksum\n");
f0103bfb:	c7 04 24 5c 55 10 f0 	movl   $0xf010555c,(%esp)
f0103c02:	e8 6d e3 ff ff       	call   f0101f74 <cprintf>
f0103c07:	e9 37 01 00 00       	jmp    f0103d43 <mp_init+0x2fa>
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
	if ((conf = mpconfig(&mp)) == 0)
f0103c0c:	85 db                	test   %ebx,%ebx
f0103c0e:	0f 84 2f 01 00 00    	je     f0103d43 <mp_init+0x2fa>
		return;
	ismp = 1;
f0103c14:	c7 05 00 00 22 f0 01 	movl   $0x1,0xf0220000
f0103c1b:	00 00 00 
	lapic = (uint32_t *)conf->lapicaddr;
f0103c1e:	8b 43 24             	mov    0x24(%ebx),%eax
f0103c21:	a3 00 10 26 f0       	mov    %eax,0xf0261000

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0103c26:	8d 7b 2c             	lea    0x2c(%ebx),%edi
f0103c29:	66 83 7b 22 00       	cmpw   $0x0,0x22(%ebx)
f0103c2e:	0f 84 94 00 00 00    	je     f0103cc8 <mp_init+0x27f>
f0103c34:	be 00 00 00 00       	mov    $0x0,%esi
		switch (*p) {
f0103c39:	0f b6 07             	movzbl (%edi),%eax
f0103c3c:	84 c0                	test   %al,%al
f0103c3e:	74 06                	je     f0103c46 <mp_init+0x1fd>
f0103c40:	3c 04                	cmp    $0x4,%al
f0103c42:	77 54                	ja     f0103c98 <mp_init+0x24f>
f0103c44:	eb 4d                	jmp    f0103c93 <mp_init+0x24a>
		case MPPROC:
			proc = (struct mpproc *)p;
			if (proc->flags & MPPROC_BOOT)
f0103c46:	f6 47 03 02          	testb  $0x2,0x3(%edi)
f0103c4a:	74 11                	je     f0103c5d <mp_init+0x214>
				bootcpu = &cpus[ncpu];
f0103c4c:	6b 05 c4 03 22 f0 74 	imul   $0x74,0xf02203c4,%eax
f0103c53:	05 20 00 22 f0       	add    $0xf0220020,%eax
f0103c58:	a3 c0 03 22 f0       	mov    %eax,0xf02203c0
			if (ncpu < NCPU) {
f0103c5d:	a1 c4 03 22 f0       	mov    0xf02203c4,%eax
f0103c62:	83 f8 07             	cmp    $0x7,%eax
f0103c65:	7f 13                	jg     f0103c7a <mp_init+0x231>
				cpus[ncpu].cpu_id = ncpu;
f0103c67:	6b d0 74             	imul   $0x74,%eax,%edx
f0103c6a:	88 82 20 00 22 f0    	mov    %al,-0xfddffe0(%edx)
				ncpu++;
f0103c70:	83 c0 01             	add    $0x1,%eax
f0103c73:	a3 c4 03 22 f0       	mov    %eax,0xf02203c4
f0103c78:	eb 14                	jmp    f0103c8e <mp_init+0x245>
			} else {
				cprintf("SMP: too many CPUs, CPU %d disabled\n",
f0103c7a:	0f b6 47 01          	movzbl 0x1(%edi),%eax
f0103c7e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c82:	c7 04 24 8c 55 10 f0 	movl   $0xf010558c,(%esp)
f0103c89:	e8 e6 e2 ff ff       	call   f0101f74 <cprintf>
					proc->apicid);
			}
			p += sizeof(struct mpproc);
f0103c8e:	83 c7 14             	add    $0x14,%edi
			continue;
f0103c91:	eb 26                	jmp    f0103cb9 <mp_init+0x270>
		case MPBUS:
		case MPIOAPIC:
		case MPIOINTR:
		case MPLINTR:
			p += 8;
f0103c93:	83 c7 08             	add    $0x8,%edi
			continue;
f0103c96:	eb 21                	jmp    f0103cb9 <mp_init+0x270>
		default:
			cprintf("mpinit: unknown config type %x\n", *p);
f0103c98:	0f b6 c0             	movzbl %al,%eax
f0103c9b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c9f:	c7 04 24 b4 55 10 f0 	movl   $0xf01055b4,(%esp)
f0103ca6:	e8 c9 e2 ff ff       	call   f0101f74 <cprintf>
			ismp = 0;
f0103cab:	c7 05 00 00 22 f0 00 	movl   $0x0,0xf0220000
f0103cb2:	00 00 00 
			i = conf->entry;
f0103cb5:	0f b7 73 22          	movzwl 0x22(%ebx),%esi
	if ((conf = mpconfig(&mp)) == 0)
		return;
	ismp = 1;
	lapic = (uint32_t *)conf->lapicaddr;

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0103cb9:	83 c6 01             	add    $0x1,%esi
f0103cbc:	0f b7 43 22          	movzwl 0x22(%ebx),%eax
f0103cc0:	39 f0                	cmp    %esi,%eax
f0103cc2:	0f 87 71 ff ff ff    	ja     f0103c39 <mp_init+0x1f0>
			ismp = 0;
			i = conf->entry;
		}
	}

	bootcpu->cpu_status = CPU_STARTED;
f0103cc8:	a1 c0 03 22 f0       	mov    0xf02203c0,%eax
f0103ccd:	c7 40 04 01 00 00 00 	movl   $0x1,0x4(%eax)
	if (!ismp) {
f0103cd4:	83 3d 00 00 22 f0 00 	cmpl   $0x0,0xf0220000
f0103cdb:	75 22                	jne    f0103cff <mp_init+0x2b6>
		// Didn't like what we found; fall back to no MP.
		ncpu = 1;
f0103cdd:	c7 05 c4 03 22 f0 01 	movl   $0x1,0xf02203c4
f0103ce4:	00 00 00 
		lapic = NULL;
f0103ce7:	c7 05 00 10 26 f0 00 	movl   $0x0,0xf0261000
f0103cee:	00 00 00 
		cprintf("SMP: configuration not found, SMP disabled\n");
f0103cf1:	c7 04 24 d4 55 10 f0 	movl   $0xf01055d4,(%esp)
f0103cf8:	e8 77 e2 ff ff       	call   f0101f74 <cprintf>
		return;
f0103cfd:	eb 44                	jmp    f0103d43 <mp_init+0x2fa>
	}
	cprintf("SMP: CPU %d found %d CPU(s)\n", bootcpu->cpu_id,  ncpu);
f0103cff:	8b 15 c4 03 22 f0    	mov    0xf02203c4,%edx
f0103d05:	89 54 24 08          	mov    %edx,0x8(%esp)
f0103d09:	0f b6 00             	movzbl (%eax),%eax
f0103d0c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d10:	c7 04 24 5b 56 10 f0 	movl   $0xf010565b,(%esp)
f0103d17:	e8 58 e2 ff ff       	call   f0101f74 <cprintf>

	if (mp->imcrp) {
f0103d1c:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103d1f:	80 78 0c 00          	cmpb   $0x0,0xc(%eax)
f0103d23:	74 1e                	je     f0103d43 <mp_init+0x2fa>
		// [MP 3.2.6.1] If the hardware implements PIC mode,
		// switch to getting interrupts from the LAPIC.
		cprintf("SMP: Setting IMCR to switch from PIC mode to symmetric I/O mode\n");
f0103d25:	c7 04 24 00 56 10 f0 	movl   $0xf0105600,(%esp)
f0103d2c:	e8 43 e2 ff ff       	call   f0101f74 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103d31:	ba 22 00 00 00       	mov    $0x22,%edx
f0103d36:	b8 70 00 00 00       	mov    $0x70,%eax
f0103d3b:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0103d3c:	b2 23                	mov    $0x23,%dl
f0103d3e:	ec                   	in     (%dx),%al
		outb(0x22, 0x70);   // Select IMCR
		outb(0x23, inb(0x23) | 1);  // Mask external interrupts.
f0103d3f:	83 c8 01             	or     $0x1,%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103d42:	ee                   	out    %al,(%dx)
	}
}
f0103d43:	83 c4 2c             	add    $0x2c,%esp
f0103d46:	5b                   	pop    %ebx
f0103d47:	5e                   	pop    %esi
f0103d48:	5f                   	pop    %edi
f0103d49:	5d                   	pop    %ebp
f0103d4a:	c3                   	ret    

f0103d4b <lapicw>:

volatile uint32_t *lapic;  // Initialized in mp.c

static void
lapicw(int index, int value)
{
f0103d4b:	55                   	push   %ebp
f0103d4c:	89 e5                	mov    %esp,%ebp
	lapic[index] = value;
f0103d4e:	8b 0d 00 10 26 f0    	mov    0xf0261000,%ecx
f0103d54:	8d 04 81             	lea    (%ecx,%eax,4),%eax
f0103d57:	89 10                	mov    %edx,(%eax)
	lapic[ID];  // wait for write to finish, by reading
f0103d59:	a1 00 10 26 f0       	mov    0xf0261000,%eax
f0103d5e:	8b 40 20             	mov    0x20(%eax),%eax
}
f0103d61:	5d                   	pop    %ebp
f0103d62:	c3                   	ret    

f0103d63 <cpunum>:
	lapicw(TPR, 0);
}

int
cpunum(void)
{
f0103d63:	55                   	push   %ebp
f0103d64:	89 e5                	mov    %esp,%ebp
	if (lapic)
f0103d66:	a1 00 10 26 f0       	mov    0xf0261000,%eax
f0103d6b:	85 c0                	test   %eax,%eax
f0103d6d:	74 08                	je     f0103d77 <cpunum+0x14>
		return lapic[ID] >> 24;
f0103d6f:	8b 40 20             	mov    0x20(%eax),%eax
f0103d72:	c1 e8 18             	shr    $0x18,%eax
f0103d75:	eb 05                	jmp    f0103d7c <cpunum+0x19>
	return 0;
f0103d77:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0103d7c:	5d                   	pop    %ebp
f0103d7d:	c3                   	ret    

f0103d7e <lapic_init>:
}

void
lapic_init(void)
{
	if (!lapic) 
f0103d7e:	83 3d 00 10 26 f0 00 	cmpl   $0x0,0xf0261000
f0103d85:	0f 84 0b 01 00 00    	je     f0103e96 <lapic_init+0x118>
	lapic[ID];  // wait for write to finish, by reading
}

void
lapic_init(void)
{
f0103d8b:	55                   	push   %ebp
f0103d8c:	89 e5                	mov    %esp,%ebp
	if (!lapic) 
		return;

	// Enable local APIC; set spurious interrupt vector.
	lapicw(SVR, ENABLE | (IRQ_OFFSET + IRQ_SPURIOUS));
f0103d8e:	ba 27 01 00 00       	mov    $0x127,%edx
f0103d93:	b8 3c 00 00 00       	mov    $0x3c,%eax
f0103d98:	e8 ae ff ff ff       	call   f0103d4b <lapicw>

	// The timer repeatedly counts down at bus frequency
	// from lapic[TICR] and then issues an interrupt.  
	// If we cared more about precise timekeeping,
	// TICR would be calibrated using an external time source.
	lapicw(TDCR, X1);
f0103d9d:	ba 0b 00 00 00       	mov    $0xb,%edx
f0103da2:	b8 f8 00 00 00       	mov    $0xf8,%eax
f0103da7:	e8 9f ff ff ff       	call   f0103d4b <lapicw>
	lapicw(TIMER, PERIODIC | (IRQ_OFFSET + IRQ_TIMER));
f0103dac:	ba 20 00 02 00       	mov    $0x20020,%edx
f0103db1:	b8 c8 00 00 00       	mov    $0xc8,%eax
f0103db6:	e8 90 ff ff ff       	call   f0103d4b <lapicw>
	lapicw(TICR, 10000000); 
f0103dbb:	ba 80 96 98 00       	mov    $0x989680,%edx
f0103dc0:	b8 e0 00 00 00       	mov    $0xe0,%eax
f0103dc5:	e8 81 ff ff ff       	call   f0103d4b <lapicw>
	//
	// According to Intel MP Specification, the BIOS should initialize
	// BSP's local APIC in Virtual Wire Mode, in which 8259A's
	// INTR is virtually connected to BSP's LINTIN0. In this mode,
	// we do not need to program the IOAPIC.
	if (thiscpu != bootcpu)
f0103dca:	e8 94 ff ff ff       	call   f0103d63 <cpunum>
f0103dcf:	6b c0 74             	imul   $0x74,%eax,%eax
f0103dd2:	05 20 00 22 f0       	add    $0xf0220020,%eax
f0103dd7:	39 05 c0 03 22 f0    	cmp    %eax,0xf02203c0
f0103ddd:	74 0f                	je     f0103dee <lapic_init+0x70>
		lapicw(LINT0, MASKED);
f0103ddf:	ba 00 00 01 00       	mov    $0x10000,%edx
f0103de4:	b8 d4 00 00 00       	mov    $0xd4,%eax
f0103de9:	e8 5d ff ff ff       	call   f0103d4b <lapicw>

	// Disable NMI (LINT1) on all CPUs
	lapicw(LINT1, MASKED);
f0103dee:	ba 00 00 01 00       	mov    $0x10000,%edx
f0103df3:	b8 d8 00 00 00       	mov    $0xd8,%eax
f0103df8:	e8 4e ff ff ff       	call   f0103d4b <lapicw>

	// Disable performance counter overflow interrupts
	// on machines that provide that interrupt entry.
	if (((lapic[VER]>>16) & 0xFF) >= 4)
f0103dfd:	a1 00 10 26 f0       	mov    0xf0261000,%eax
f0103e02:	8b 40 30             	mov    0x30(%eax),%eax
f0103e05:	c1 e8 10             	shr    $0x10,%eax
f0103e08:	3c 03                	cmp    $0x3,%al
f0103e0a:	76 0f                	jbe    f0103e1b <lapic_init+0x9d>
		lapicw(PCINT, MASKED);
f0103e0c:	ba 00 00 01 00       	mov    $0x10000,%edx
f0103e11:	b8 d0 00 00 00       	mov    $0xd0,%eax
f0103e16:	e8 30 ff ff ff       	call   f0103d4b <lapicw>

	// Map error interrupt to IRQ_ERROR.
	lapicw(ERROR, IRQ_OFFSET + IRQ_ERROR);
f0103e1b:	ba 33 00 00 00       	mov    $0x33,%edx
f0103e20:	b8 dc 00 00 00       	mov    $0xdc,%eax
f0103e25:	e8 21 ff ff ff       	call   f0103d4b <lapicw>

	// Clear error status register (requires back-to-back writes).
	lapicw(ESR, 0);
f0103e2a:	ba 00 00 00 00       	mov    $0x0,%edx
f0103e2f:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0103e34:	e8 12 ff ff ff       	call   f0103d4b <lapicw>
	lapicw(ESR, 0);
f0103e39:	ba 00 00 00 00       	mov    $0x0,%edx
f0103e3e:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0103e43:	e8 03 ff ff ff       	call   f0103d4b <lapicw>

	// Ack any outstanding interrupts.
	lapicw(EOI, 0);
f0103e48:	ba 00 00 00 00       	mov    $0x0,%edx
f0103e4d:	b8 2c 00 00 00       	mov    $0x2c,%eax
f0103e52:	e8 f4 fe ff ff       	call   f0103d4b <lapicw>

	// Send an Init Level De-Assert to synchronize arbitration ID's.
	lapicw(ICRHI, 0);
f0103e57:	ba 00 00 00 00       	mov    $0x0,%edx
f0103e5c:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0103e61:	e8 e5 fe ff ff       	call   f0103d4b <lapicw>
	lapicw(ICRLO, BCAST | INIT | LEVEL);
f0103e66:	ba 00 85 08 00       	mov    $0x88500,%edx
f0103e6b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0103e70:	e8 d6 fe ff ff       	call   f0103d4b <lapicw>
	while(lapic[ICRLO] & DELIVS)
f0103e75:	8b 15 00 10 26 f0    	mov    0xf0261000,%edx
f0103e7b:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f0103e81:	f6 c4 10             	test   $0x10,%ah
f0103e84:	75 f5                	jne    f0103e7b <lapic_init+0xfd>
		;

	// Enable interrupts on the APIC (but not on the processor).
	lapicw(TPR, 0);
f0103e86:	ba 00 00 00 00       	mov    $0x0,%edx
f0103e8b:	b8 20 00 00 00       	mov    $0x20,%eax
f0103e90:	e8 b6 fe ff ff       	call   f0103d4b <lapicw>
}
f0103e95:	5d                   	pop    %ebp
f0103e96:	f3 c3                	repz ret 

f0103e98 <lapic_eoi>:

// Acknowledge interrupt.
void
lapic_eoi(void)
{
	if (lapic)
f0103e98:	83 3d 00 10 26 f0 00 	cmpl   $0x0,0xf0261000
f0103e9f:	74 13                	je     f0103eb4 <lapic_eoi+0x1c>
}

// Acknowledge interrupt.
void
lapic_eoi(void)
{
f0103ea1:	55                   	push   %ebp
f0103ea2:	89 e5                	mov    %esp,%ebp
	if (lapic)
		lapicw(EOI, 0);
f0103ea4:	ba 00 00 00 00       	mov    $0x0,%edx
f0103ea9:	b8 2c 00 00 00       	mov    $0x2c,%eax
f0103eae:	e8 98 fe ff ff       	call   f0103d4b <lapicw>
}
f0103eb3:	5d                   	pop    %ebp
f0103eb4:	f3 c3                	repz ret 

f0103eb6 <lapic_startap>:

// Start additional processor running entry code at addr.
// See Appendix B of MultiProcessor Specification.
void
lapic_startap(uint8_t apicid, uint32_t addr)
{
f0103eb6:	55                   	push   %ebp
f0103eb7:	89 e5                	mov    %esp,%ebp
f0103eb9:	56                   	push   %esi
f0103eba:	53                   	push   %ebx
f0103ebb:	83 ec 10             	sub    $0x10,%esp
f0103ebe:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0103ec1:	8b 75 0c             	mov    0xc(%ebp),%esi
f0103ec4:	ba 70 00 00 00       	mov    $0x70,%edx
f0103ec9:	b8 0f 00 00 00       	mov    $0xf,%eax
f0103ece:	ee                   	out    %al,(%dx)
f0103ecf:	b2 71                	mov    $0x71,%dl
f0103ed1:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103ed6:	ee                   	out    %al,(%dx)
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103ed7:	83 3d 08 ff 21 f0 00 	cmpl   $0x0,0xf021ff08
f0103ede:	75 24                	jne    f0103f04 <lapic_startap+0x4e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103ee0:	c7 44 24 0c 67 04 00 	movl   $0x467,0xc(%esp)
f0103ee7:	00 
f0103ee8:	c7 44 24 08 84 44 10 	movl   $0xf0104484,0x8(%esp)
f0103eef:	f0 
f0103ef0:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
f0103ef7:	00 
f0103ef8:	c7 04 24 78 56 10 f0 	movl   $0xf0105678,(%esp)
f0103eff:	e8 3c c1 ff ff       	call   f0100040 <_panic>
	// and the warm reset vector (DWORD based at 40:67) to point at
	// the AP startup code prior to the [universal startup algorithm]."
	outb(IO_RTC, 0xF);  // offset 0xF is shutdown code
	outb(IO_RTC+1, 0x0A);
	wrv = (uint16_t *)KADDR((0x40 << 4 | 0x67));  // Warm reset vector
	wrv[0] = 0;
f0103f04:	66 c7 05 67 04 00 f0 	movw   $0x0,0xf0000467
f0103f0b:	00 00 
	wrv[1] = addr >> 4;
f0103f0d:	89 f0                	mov    %esi,%eax
f0103f0f:	c1 e8 04             	shr    $0x4,%eax
f0103f12:	66 a3 69 04 00 f0    	mov    %ax,0xf0000469

	// "Universal startup algorithm."
	// Send INIT (level-triggered) interrupt to reset other CPU.
	lapicw(ICRHI, apicid << 24);
f0103f18:	c1 e3 18             	shl    $0x18,%ebx
f0103f1b:	89 da                	mov    %ebx,%edx
f0103f1d:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0103f22:	e8 24 fe ff ff       	call   f0103d4b <lapicw>
	lapicw(ICRLO, INIT | LEVEL | ASSERT);
f0103f27:	ba 00 c5 00 00       	mov    $0xc500,%edx
f0103f2c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0103f31:	e8 15 fe ff ff       	call   f0103d4b <lapicw>
	microdelay(200);
	lapicw(ICRLO, INIT | LEVEL);
f0103f36:	ba 00 85 00 00       	mov    $0x8500,%edx
f0103f3b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0103f40:	e8 06 fe ff ff       	call   f0103d4b <lapicw>
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0103f45:	c1 ee 0c             	shr    $0xc,%esi
f0103f48:	81 ce 00 06 00 00    	or     $0x600,%esi
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f0103f4e:	89 da                	mov    %ebx,%edx
f0103f50:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0103f55:	e8 f1 fd ff ff       	call   f0103d4b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0103f5a:	89 f2                	mov    %esi,%edx
f0103f5c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0103f61:	e8 e5 fd ff ff       	call   f0103d4b <lapicw>
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f0103f66:	89 da                	mov    %ebx,%edx
f0103f68:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0103f6d:	e8 d9 fd ff ff       	call   f0103d4b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0103f72:	89 f2                	mov    %esi,%edx
f0103f74:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0103f79:	e8 cd fd ff ff       	call   f0103d4b <lapicw>
		microdelay(200);
	}
}
f0103f7e:	83 c4 10             	add    $0x10,%esp
f0103f81:	5b                   	pop    %ebx
f0103f82:	5e                   	pop    %esi
f0103f83:	5d                   	pop    %ebp
f0103f84:	c3                   	ret    

f0103f85 <lapic_ipi>:

void
lapic_ipi(int vector)
{
f0103f85:	55                   	push   %ebp
f0103f86:	89 e5                	mov    %esp,%ebp
	lapicw(ICRLO, OTHERS | FIXED | vector);
f0103f88:	8b 55 08             	mov    0x8(%ebp),%edx
f0103f8b:	81 ca 00 00 0c 00    	or     $0xc0000,%edx
f0103f91:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0103f96:	e8 b0 fd ff ff       	call   f0103d4b <lapicw>
	while (lapic[ICRLO] & DELIVS)
f0103f9b:	8b 15 00 10 26 f0    	mov    0xf0261000,%edx
f0103fa1:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f0103fa7:	f6 c4 10             	test   $0x10,%ah
f0103faa:	75 f5                	jne    f0103fa1 <lapic_ipi+0x1c>
		;
}
f0103fac:	5d                   	pop    %ebp
f0103fad:	c3                   	ret    

f0103fae <__spin_initlock>:
}
#endif

void
__spin_initlock(struct spinlock *lk, char *name)
{
f0103fae:	55                   	push   %ebp
f0103faf:	89 e5                	mov    %esp,%ebp
f0103fb1:	8b 45 08             	mov    0x8(%ebp),%eax
	lk->locked = 0;
f0103fb4:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
#ifdef DEBUG_SPINLOCK
	lk->name = name;
f0103fba:	8b 55 0c             	mov    0xc(%ebp),%edx
f0103fbd:	89 50 04             	mov    %edx,0x4(%eax)
	lk->cpu = 0;
f0103fc0:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
#endif
}
f0103fc7:	5d                   	pop    %ebp
f0103fc8:	c3                   	ret    

f0103fc9 <spin_lock>:
// Loops (spins) until the lock is acquired.
// Holding a lock for a long time may cause
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
f0103fc9:	55                   	push   %ebp
f0103fca:	89 e5                	mov    %esp,%ebp
f0103fcc:	56                   	push   %esi
f0103fcd:	53                   	push   %ebx
f0103fce:	83 ec 20             	sub    $0x20,%esp
f0103fd1:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0103fd4:	83 3b 00             	cmpl   $0x0,(%ebx)
f0103fd7:	74 14                	je     f0103fed <spin_lock+0x24>
f0103fd9:	8b 73 08             	mov    0x8(%ebx),%esi
f0103fdc:	e8 82 fd ff ff       	call   f0103d63 <cpunum>
f0103fe1:	6b c0 74             	imul   $0x74,%eax,%eax
f0103fe4:	05 20 00 22 f0       	add    $0xf0220020,%eax
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
f0103fe9:	39 c6                	cmp    %eax,%esi
f0103feb:	74 15                	je     f0104002 <spin_lock+0x39>
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f0103fed:	89 da                	mov    %ebx,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f0103fef:	b8 01 00 00 00       	mov    $0x1,%eax
f0103ff4:	f0 87 03             	lock xchg %eax,(%ebx)
f0103ff7:	b9 01 00 00 00       	mov    $0x1,%ecx
f0103ffc:	85 c0                	test   %eax,%eax
f0103ffe:	75 2e                	jne    f010402e <spin_lock+0x65>
f0104000:	eb 37                	jmp    f0104039 <spin_lock+0x70>
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
		panic("CPU %d cannot acquire %s: already holding", cpunum(), lk->name);
f0104002:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0104005:	e8 59 fd ff ff       	call   f0103d63 <cpunum>
f010400a:	89 5c 24 10          	mov    %ebx,0x10(%esp)
f010400e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104012:	c7 44 24 08 88 56 10 	movl   $0xf0105688,0x8(%esp)
f0104019:	f0 
f010401a:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
f0104021:	00 
f0104022:	c7 04 24 ec 56 10 f0 	movl   $0xf01056ec,(%esp)
f0104029:	e8 12 c0 ff ff       	call   f0100040 <_panic>

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
		asm volatile ("pause");
f010402e:	f3 90                	pause  
f0104030:	89 c8                	mov    %ecx,%eax
f0104032:	f0 87 02             	lock xchg %eax,(%edx)
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f0104035:	85 c0                	test   %eax,%eax
f0104037:	75 f5                	jne    f010402e <spin_lock+0x65>
		asm volatile ("pause");

	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
f0104039:	e8 25 fd ff ff       	call   f0103d63 <cpunum>
f010403e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104041:	05 20 00 22 f0       	add    $0xf0220020,%eax
f0104046:	89 43 08             	mov    %eax,0x8(%ebx)
	get_caller_pcs(lk->pcs);
f0104049:	8d 4b 0c             	lea    0xc(%ebx),%ecx

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f010404c:	89 e8                	mov    %ebp,%eax
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
f010404e:	8d 90 00 00 80 10    	lea    0x10800000(%eax),%edx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0104054:	81 fa ff ff 7f 0e    	cmp    $0xe7fffff,%edx
f010405a:	76 3a                	jbe    f0104096 <spin_lock+0xcd>
f010405c:	eb 31                	jmp    f010408f <spin_lock+0xc6>
		    || ebp >= (uint32_t *)IOMEMBASE)
f010405e:	8d 9a 00 00 80 10    	lea    0x10800000(%edx),%ebx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0104064:	81 fb ff ff 7f 0e    	cmp    $0xe7fffff,%ebx
f010406a:	77 12                	ja     f010407e <spin_lock+0xb5>
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f010406c:	8b 5a 04             	mov    0x4(%edx),%ebx
f010406f:	89 1c 81             	mov    %ebx,(%ecx,%eax,4)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f0104072:	8b 12                	mov    (%edx),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f0104074:	83 c0 01             	add    $0x1,%eax
f0104077:	83 f8 0a             	cmp    $0xa,%eax
f010407a:	75 e2                	jne    f010405e <spin_lock+0x95>
f010407c:	eb 27                	jmp    f01040a5 <spin_lock+0xdc>
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
		pcs[i] = 0;
f010407e:	c7 04 81 00 00 00 00 	movl   $0x0,(%ecx,%eax,4)
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
f0104085:	83 c0 01             	add    $0x1,%eax
f0104088:	83 f8 09             	cmp    $0x9,%eax
f010408b:	7e f1                	jle    f010407e <spin_lock+0xb5>
f010408d:	eb 16                	jmp    f01040a5 <spin_lock+0xdc>
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f010408f:	b8 00 00 00 00       	mov    $0x0,%eax
f0104094:	eb e8                	jmp    f010407e <spin_lock+0xb5>
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f0104096:	8b 50 04             	mov    0x4(%eax),%edx
f0104099:	89 53 0c             	mov    %edx,0xc(%ebx)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f010409c:	8b 10                	mov    (%eax),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f010409e:	b8 01 00 00 00       	mov    $0x1,%eax
f01040a3:	eb b9                	jmp    f010405e <spin_lock+0x95>
	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
	get_caller_pcs(lk->pcs);
#endif
}
f01040a5:	83 c4 20             	add    $0x20,%esp
f01040a8:	5b                   	pop    %ebx
f01040a9:	5e                   	pop    %esi
f01040aa:	5d                   	pop    %ebp
f01040ab:	c3                   	ret    

f01040ac <spin_unlock>:

// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
f01040ac:	55                   	push   %ebp
f01040ad:	89 e5                	mov    %esp,%ebp
f01040af:	57                   	push   %edi
f01040b0:	56                   	push   %esi
f01040b1:	53                   	push   %ebx
f01040b2:	83 ec 6c             	sub    $0x6c,%esp
f01040b5:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f01040b8:	83 3b 00             	cmpl   $0x0,(%ebx)
f01040bb:	74 18                	je     f01040d5 <spin_unlock+0x29>
f01040bd:	8b 73 08             	mov    0x8(%ebx),%esi
f01040c0:	e8 9e fc ff ff       	call   f0103d63 <cpunum>
f01040c5:	6b c0 74             	imul   $0x74,%eax,%eax
f01040c8:	05 20 00 22 f0       	add    $0xf0220020,%eax
// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (!holding(lk)) {
f01040cd:	39 c6                	cmp    %eax,%esi
f01040cf:	0f 84 d4 00 00 00    	je     f01041a9 <spin_unlock+0xfd>
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
f01040d5:	c7 44 24 08 28 00 00 	movl   $0x28,0x8(%esp)
f01040dc:	00 
f01040dd:	8d 43 0c             	lea    0xc(%ebx),%eax
f01040e0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01040e4:	8d 45 c0             	lea    -0x40(%ebp),%eax
f01040e7:	89 04 24             	mov    %eax,(%esp)
f01040ea:	e8 27 f6 ff ff       	call   f0103716 <memmove>
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
f01040ef:	8b 43 08             	mov    0x8(%ebx),%eax
	if (!holding(lk)) {
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
f01040f2:	0f b6 30             	movzbl (%eax),%esi
f01040f5:	8b 5b 04             	mov    0x4(%ebx),%ebx
f01040f8:	e8 66 fc ff ff       	call   f0103d63 <cpunum>
f01040fd:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0104101:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0104105:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104109:	c7 04 24 b4 56 10 f0 	movl   $0xf01056b4,(%esp)
f0104110:	e8 5f de ff ff       	call   f0101f74 <cprintf>
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0104115:	8b 45 c0             	mov    -0x40(%ebp),%eax
f0104118:	85 c0                	test   %eax,%eax
f010411a:	74 71                	je     f010418d <spin_unlock+0xe1>
f010411c:	8d 5d c0             	lea    -0x40(%ebp),%ebx
f010411f:	8d 7d e4             	lea    -0x1c(%ebp),%edi
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
f0104122:	8d 75 a8             	lea    -0x58(%ebp),%esi
f0104125:	89 74 24 04          	mov    %esi,0x4(%esp)
f0104129:	89 04 24             	mov    %eax,(%esp)
f010412c:	e8 0b ea ff ff       	call   f0102b3c <debuginfo_eip>
f0104131:	85 c0                	test   %eax,%eax
f0104133:	78 39                	js     f010416e <spin_unlock+0xc2>
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
f0104135:	8b 03                	mov    (%ebx),%eax
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
f0104137:	89 c2                	mov    %eax,%edx
f0104139:	2b 55 b8             	sub    -0x48(%ebp),%edx
f010413c:	89 54 24 18          	mov    %edx,0x18(%esp)
f0104140:	8b 55 b0             	mov    -0x50(%ebp),%edx
f0104143:	89 54 24 14          	mov    %edx,0x14(%esp)
f0104147:	8b 55 b4             	mov    -0x4c(%ebp),%edx
f010414a:	89 54 24 10          	mov    %edx,0x10(%esp)
f010414e:	8b 55 ac             	mov    -0x54(%ebp),%edx
f0104151:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0104155:	8b 55 a8             	mov    -0x58(%ebp),%edx
f0104158:	89 54 24 08          	mov    %edx,0x8(%esp)
f010415c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104160:	c7 04 24 fc 56 10 f0 	movl   $0xf01056fc,(%esp)
f0104167:	e8 08 de ff ff       	call   f0101f74 <cprintf>
f010416c:	eb 12                	jmp    f0104180 <spin_unlock+0xd4>
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
f010416e:	8b 03                	mov    (%ebx),%eax
f0104170:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104174:	c7 04 24 13 57 10 f0 	movl   $0xf0105713,(%esp)
f010417b:	e8 f4 dd ff ff       	call   f0101f74 <cprintf>
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0104180:	39 fb                	cmp    %edi,%ebx
f0104182:	74 09                	je     f010418d <spin_unlock+0xe1>
f0104184:	83 c3 04             	add    $0x4,%ebx
f0104187:	8b 03                	mov    (%ebx),%eax
f0104189:	85 c0                	test   %eax,%eax
f010418b:	75 98                	jne    f0104125 <spin_unlock+0x79>
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
		}
		panic("spin_unlock");
f010418d:	c7 44 24 08 1b 57 10 	movl   $0xf010571b,0x8(%esp)
f0104194:	f0 
f0104195:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
f010419c:	00 
f010419d:	c7 04 24 ec 56 10 f0 	movl   $0xf01056ec,(%esp)
f01041a4:	e8 97 be ff ff       	call   f0100040 <_panic>
	}

	lk->pcs[0] = 0;
f01041a9:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
	lk->cpu = 0;
f01041b0:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f01041b7:	b8 00 00 00 00       	mov    $0x0,%eax
f01041bc:	f0 87 03             	lock xchg %eax,(%ebx)
	// Paper says that Intel 64 and IA-32 will not move a load
	// after a store. So lock->locked = 0 would work here.
	// The xchg being asm volatile ensures gcc emits it after
	// the above assignments (and after the critical section).
	xchg(&lk->locked, 0);
}
f01041bf:	83 c4 6c             	add    $0x6c,%esp
f01041c2:	5b                   	pop    %ebx
f01041c3:	5e                   	pop    %esi
f01041c4:	5f                   	pop    %edi
f01041c5:	5d                   	pop    %ebp
f01041c6:	c3                   	ret    
f01041c7:	66 90                	xchg   %ax,%ax
f01041c9:	66 90                	xchg   %ax,%ax
f01041cb:	66 90                	xchg   %ax,%ax
f01041cd:	66 90                	xchg   %ax,%ax
f01041cf:	90                   	nop

f01041d0 <__udivdi3>:
f01041d0:	55                   	push   %ebp
f01041d1:	57                   	push   %edi
f01041d2:	56                   	push   %esi
f01041d3:	83 ec 0c             	sub    $0xc,%esp
f01041d6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01041da:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f01041de:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f01041e2:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01041e6:	85 c0                	test   %eax,%eax
f01041e8:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01041ec:	89 ea                	mov    %ebp,%edx
f01041ee:	89 0c 24             	mov    %ecx,(%esp)
f01041f1:	75 2d                	jne    f0104220 <__udivdi3+0x50>
f01041f3:	39 e9                	cmp    %ebp,%ecx
f01041f5:	77 61                	ja     f0104258 <__udivdi3+0x88>
f01041f7:	85 c9                	test   %ecx,%ecx
f01041f9:	89 ce                	mov    %ecx,%esi
f01041fb:	75 0b                	jne    f0104208 <__udivdi3+0x38>
f01041fd:	b8 01 00 00 00       	mov    $0x1,%eax
f0104202:	31 d2                	xor    %edx,%edx
f0104204:	f7 f1                	div    %ecx
f0104206:	89 c6                	mov    %eax,%esi
f0104208:	31 d2                	xor    %edx,%edx
f010420a:	89 e8                	mov    %ebp,%eax
f010420c:	f7 f6                	div    %esi
f010420e:	89 c5                	mov    %eax,%ebp
f0104210:	89 f8                	mov    %edi,%eax
f0104212:	f7 f6                	div    %esi
f0104214:	89 ea                	mov    %ebp,%edx
f0104216:	83 c4 0c             	add    $0xc,%esp
f0104219:	5e                   	pop    %esi
f010421a:	5f                   	pop    %edi
f010421b:	5d                   	pop    %ebp
f010421c:	c3                   	ret    
f010421d:	8d 76 00             	lea    0x0(%esi),%esi
f0104220:	39 e8                	cmp    %ebp,%eax
f0104222:	77 24                	ja     f0104248 <__udivdi3+0x78>
f0104224:	0f bd e8             	bsr    %eax,%ebp
f0104227:	83 f5 1f             	xor    $0x1f,%ebp
f010422a:	75 3c                	jne    f0104268 <__udivdi3+0x98>
f010422c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0104230:	39 34 24             	cmp    %esi,(%esp)
f0104233:	0f 86 9f 00 00 00    	jbe    f01042d8 <__udivdi3+0x108>
f0104239:	39 d0                	cmp    %edx,%eax
f010423b:	0f 82 97 00 00 00    	jb     f01042d8 <__udivdi3+0x108>
f0104241:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0104248:	31 d2                	xor    %edx,%edx
f010424a:	31 c0                	xor    %eax,%eax
f010424c:	83 c4 0c             	add    $0xc,%esp
f010424f:	5e                   	pop    %esi
f0104250:	5f                   	pop    %edi
f0104251:	5d                   	pop    %ebp
f0104252:	c3                   	ret    
f0104253:	90                   	nop
f0104254:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0104258:	89 f8                	mov    %edi,%eax
f010425a:	f7 f1                	div    %ecx
f010425c:	31 d2                	xor    %edx,%edx
f010425e:	83 c4 0c             	add    $0xc,%esp
f0104261:	5e                   	pop    %esi
f0104262:	5f                   	pop    %edi
f0104263:	5d                   	pop    %ebp
f0104264:	c3                   	ret    
f0104265:	8d 76 00             	lea    0x0(%esi),%esi
f0104268:	89 e9                	mov    %ebp,%ecx
f010426a:	8b 3c 24             	mov    (%esp),%edi
f010426d:	d3 e0                	shl    %cl,%eax
f010426f:	89 c6                	mov    %eax,%esi
f0104271:	b8 20 00 00 00       	mov    $0x20,%eax
f0104276:	29 e8                	sub    %ebp,%eax
f0104278:	89 c1                	mov    %eax,%ecx
f010427a:	d3 ef                	shr    %cl,%edi
f010427c:	89 e9                	mov    %ebp,%ecx
f010427e:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0104282:	8b 3c 24             	mov    (%esp),%edi
f0104285:	09 74 24 08          	or     %esi,0x8(%esp)
f0104289:	89 d6                	mov    %edx,%esi
f010428b:	d3 e7                	shl    %cl,%edi
f010428d:	89 c1                	mov    %eax,%ecx
f010428f:	89 3c 24             	mov    %edi,(%esp)
f0104292:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0104296:	d3 ee                	shr    %cl,%esi
f0104298:	89 e9                	mov    %ebp,%ecx
f010429a:	d3 e2                	shl    %cl,%edx
f010429c:	89 c1                	mov    %eax,%ecx
f010429e:	d3 ef                	shr    %cl,%edi
f01042a0:	09 d7                	or     %edx,%edi
f01042a2:	89 f2                	mov    %esi,%edx
f01042a4:	89 f8                	mov    %edi,%eax
f01042a6:	f7 74 24 08          	divl   0x8(%esp)
f01042aa:	89 d6                	mov    %edx,%esi
f01042ac:	89 c7                	mov    %eax,%edi
f01042ae:	f7 24 24             	mull   (%esp)
f01042b1:	39 d6                	cmp    %edx,%esi
f01042b3:	89 14 24             	mov    %edx,(%esp)
f01042b6:	72 30                	jb     f01042e8 <__udivdi3+0x118>
f01042b8:	8b 54 24 04          	mov    0x4(%esp),%edx
f01042bc:	89 e9                	mov    %ebp,%ecx
f01042be:	d3 e2                	shl    %cl,%edx
f01042c0:	39 c2                	cmp    %eax,%edx
f01042c2:	73 05                	jae    f01042c9 <__udivdi3+0xf9>
f01042c4:	3b 34 24             	cmp    (%esp),%esi
f01042c7:	74 1f                	je     f01042e8 <__udivdi3+0x118>
f01042c9:	89 f8                	mov    %edi,%eax
f01042cb:	31 d2                	xor    %edx,%edx
f01042cd:	e9 7a ff ff ff       	jmp    f010424c <__udivdi3+0x7c>
f01042d2:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f01042d8:	31 d2                	xor    %edx,%edx
f01042da:	b8 01 00 00 00       	mov    $0x1,%eax
f01042df:	e9 68 ff ff ff       	jmp    f010424c <__udivdi3+0x7c>
f01042e4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01042e8:	8d 47 ff             	lea    -0x1(%edi),%eax
f01042eb:	31 d2                	xor    %edx,%edx
f01042ed:	83 c4 0c             	add    $0xc,%esp
f01042f0:	5e                   	pop    %esi
f01042f1:	5f                   	pop    %edi
f01042f2:	5d                   	pop    %ebp
f01042f3:	c3                   	ret    
f01042f4:	66 90                	xchg   %ax,%ax
f01042f6:	66 90                	xchg   %ax,%ax
f01042f8:	66 90                	xchg   %ax,%ax
f01042fa:	66 90                	xchg   %ax,%ax
f01042fc:	66 90                	xchg   %ax,%ax
f01042fe:	66 90                	xchg   %ax,%ax

f0104300 <__umoddi3>:
f0104300:	55                   	push   %ebp
f0104301:	57                   	push   %edi
f0104302:	56                   	push   %esi
f0104303:	83 ec 14             	sub    $0x14,%esp
f0104306:	8b 44 24 28          	mov    0x28(%esp),%eax
f010430a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f010430e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0104312:	89 c7                	mov    %eax,%edi
f0104314:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104318:	8b 44 24 30          	mov    0x30(%esp),%eax
f010431c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0104320:	89 34 24             	mov    %esi,(%esp)
f0104323:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104327:	85 c0                	test   %eax,%eax
f0104329:	89 c2                	mov    %eax,%edx
f010432b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f010432f:	75 17                	jne    f0104348 <__umoddi3+0x48>
f0104331:	39 fe                	cmp    %edi,%esi
f0104333:	76 4b                	jbe    f0104380 <__umoddi3+0x80>
f0104335:	89 c8                	mov    %ecx,%eax
f0104337:	89 fa                	mov    %edi,%edx
f0104339:	f7 f6                	div    %esi
f010433b:	89 d0                	mov    %edx,%eax
f010433d:	31 d2                	xor    %edx,%edx
f010433f:	83 c4 14             	add    $0x14,%esp
f0104342:	5e                   	pop    %esi
f0104343:	5f                   	pop    %edi
f0104344:	5d                   	pop    %ebp
f0104345:	c3                   	ret    
f0104346:	66 90                	xchg   %ax,%ax
f0104348:	39 f8                	cmp    %edi,%eax
f010434a:	77 54                	ja     f01043a0 <__umoddi3+0xa0>
f010434c:	0f bd e8             	bsr    %eax,%ebp
f010434f:	83 f5 1f             	xor    $0x1f,%ebp
f0104352:	75 5c                	jne    f01043b0 <__umoddi3+0xb0>
f0104354:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0104358:	39 3c 24             	cmp    %edi,(%esp)
f010435b:	0f 87 e7 00 00 00    	ja     f0104448 <__umoddi3+0x148>
f0104361:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0104365:	29 f1                	sub    %esi,%ecx
f0104367:	19 c7                	sbb    %eax,%edi
f0104369:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f010436d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0104371:	8b 44 24 08          	mov    0x8(%esp),%eax
f0104375:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0104379:	83 c4 14             	add    $0x14,%esp
f010437c:	5e                   	pop    %esi
f010437d:	5f                   	pop    %edi
f010437e:	5d                   	pop    %ebp
f010437f:	c3                   	ret    
f0104380:	85 f6                	test   %esi,%esi
f0104382:	89 f5                	mov    %esi,%ebp
f0104384:	75 0b                	jne    f0104391 <__umoddi3+0x91>
f0104386:	b8 01 00 00 00       	mov    $0x1,%eax
f010438b:	31 d2                	xor    %edx,%edx
f010438d:	f7 f6                	div    %esi
f010438f:	89 c5                	mov    %eax,%ebp
f0104391:	8b 44 24 04          	mov    0x4(%esp),%eax
f0104395:	31 d2                	xor    %edx,%edx
f0104397:	f7 f5                	div    %ebp
f0104399:	89 c8                	mov    %ecx,%eax
f010439b:	f7 f5                	div    %ebp
f010439d:	eb 9c                	jmp    f010433b <__umoddi3+0x3b>
f010439f:	90                   	nop
f01043a0:	89 c8                	mov    %ecx,%eax
f01043a2:	89 fa                	mov    %edi,%edx
f01043a4:	83 c4 14             	add    $0x14,%esp
f01043a7:	5e                   	pop    %esi
f01043a8:	5f                   	pop    %edi
f01043a9:	5d                   	pop    %ebp
f01043aa:	c3                   	ret    
f01043ab:	90                   	nop
f01043ac:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01043b0:	8b 04 24             	mov    (%esp),%eax
f01043b3:	be 20 00 00 00       	mov    $0x20,%esi
f01043b8:	89 e9                	mov    %ebp,%ecx
f01043ba:	29 ee                	sub    %ebp,%esi
f01043bc:	d3 e2                	shl    %cl,%edx
f01043be:	89 f1                	mov    %esi,%ecx
f01043c0:	d3 e8                	shr    %cl,%eax
f01043c2:	89 e9                	mov    %ebp,%ecx
f01043c4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01043c8:	8b 04 24             	mov    (%esp),%eax
f01043cb:	09 54 24 04          	or     %edx,0x4(%esp)
f01043cf:	89 fa                	mov    %edi,%edx
f01043d1:	d3 e0                	shl    %cl,%eax
f01043d3:	89 f1                	mov    %esi,%ecx
f01043d5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01043d9:	8b 44 24 10          	mov    0x10(%esp),%eax
f01043dd:	d3 ea                	shr    %cl,%edx
f01043df:	89 e9                	mov    %ebp,%ecx
f01043e1:	d3 e7                	shl    %cl,%edi
f01043e3:	89 f1                	mov    %esi,%ecx
f01043e5:	d3 e8                	shr    %cl,%eax
f01043e7:	89 e9                	mov    %ebp,%ecx
f01043e9:	09 f8                	or     %edi,%eax
f01043eb:	8b 7c 24 10          	mov    0x10(%esp),%edi
f01043ef:	f7 74 24 04          	divl   0x4(%esp)
f01043f3:	d3 e7                	shl    %cl,%edi
f01043f5:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01043f9:	89 d7                	mov    %edx,%edi
f01043fb:	f7 64 24 08          	mull   0x8(%esp)
f01043ff:	39 d7                	cmp    %edx,%edi
f0104401:	89 c1                	mov    %eax,%ecx
f0104403:	89 14 24             	mov    %edx,(%esp)
f0104406:	72 2c                	jb     f0104434 <__umoddi3+0x134>
f0104408:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f010440c:	72 22                	jb     f0104430 <__umoddi3+0x130>
f010440e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0104412:	29 c8                	sub    %ecx,%eax
f0104414:	19 d7                	sbb    %edx,%edi
f0104416:	89 e9                	mov    %ebp,%ecx
f0104418:	89 fa                	mov    %edi,%edx
f010441a:	d3 e8                	shr    %cl,%eax
f010441c:	89 f1                	mov    %esi,%ecx
f010441e:	d3 e2                	shl    %cl,%edx
f0104420:	89 e9                	mov    %ebp,%ecx
f0104422:	d3 ef                	shr    %cl,%edi
f0104424:	09 d0                	or     %edx,%eax
f0104426:	89 fa                	mov    %edi,%edx
f0104428:	83 c4 14             	add    $0x14,%esp
f010442b:	5e                   	pop    %esi
f010442c:	5f                   	pop    %edi
f010442d:	5d                   	pop    %ebp
f010442e:	c3                   	ret    
f010442f:	90                   	nop
f0104430:	39 d7                	cmp    %edx,%edi
f0104432:	75 da                	jne    f010440e <__umoddi3+0x10e>
f0104434:	8b 14 24             	mov    (%esp),%edx
f0104437:	89 c1                	mov    %eax,%ecx
f0104439:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f010443d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0104441:	eb cb                	jmp    f010440e <__umoddi3+0x10e>
f0104443:	90                   	nop
f0104444:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0104448:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f010444c:	0f 82 0f ff ff ff    	jb     f0104361 <__umoddi3+0x61>
f0104452:	e9 1a ff ff ff       	jmp    f0104371 <__umoddi3+0x71>
