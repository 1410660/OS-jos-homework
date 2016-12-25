
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
f0100015:	b8 00 f0 11 00       	mov    $0x11f000,%eax
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
f0100034:	bc 00 f0 11 f0       	mov    $0xf011f000,%esp

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
f010004b:	83 3d 80 4e 1c f0 00 	cmpl   $0x0,0xf01c4e80
f0100052:	75 46                	jne    f010009a <_panic+0x5a>
		goto dead;
	panicstr = fmt;
f0100054:	89 35 80 4e 1c f0    	mov    %esi,0xf01c4e80

	// Be extra sure that the machine is in as reasonable state
	__asm __volatile("cli; cld");
f010005a:	fa                   	cli    
f010005b:	fc                   	cld    

	va_start(ap, fmt);
f010005c:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic on CPU %d at %s:%d: ", cpunum(), file, line);
f010005f:	e8 3f 65 00 00       	call   f01065a3 <cpunum>
f0100064:	8b 55 0c             	mov    0xc(%ebp),%edx
f0100067:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010006b:	8b 55 08             	mov    0x8(%ebp),%edx
f010006e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100072:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100076:	c7 04 24 a0 6c 10 f0 	movl   $0xf0106ca0,(%esp)
f010007d:	e8 10 3e 00 00       	call   f0103e92 <cprintf>
	vcprintf(fmt, ap);
f0100082:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100086:	89 34 24             	mov    %esi,(%esp)
f0100089:	e8 d1 3d 00 00       	call   f0103e5f <vcprintf>
	cprintf("\n");
f010008e:	c7 04 24 4a 7d 10 f0 	movl   $0xf0107d4a,(%esp)
f0100095:	e8 f8 3d 00 00       	call   f0103e92 <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f010009a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000a1:	e8 5c 09 00 00       	call   f0100a02 <monitor>
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
f01000af:	b8 04 60 20 f0       	mov    $0xf0206004,%eax
f01000b4:	2d eb 31 1c f0       	sub    $0xf01c31eb,%eax
f01000b9:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000bd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01000c4:	00 
f01000c5:	c7 04 24 eb 31 1c f0 	movl   $0xf01c31eb,(%esp)
f01000cc:	e8 38 5e 00 00       	call   f0105f09 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000d1:	e8 19 06 00 00       	call   f01006ef <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000d6:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000dd:	00 
f01000de:	c7 04 24 0c 6d 10 f0 	movl   $0xf0106d0c,(%esp)
f01000e5:	e8 a8 3d 00 00       	call   f0103e92 <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f01000ea:	e8 22 14 00 00       	call   f0101511 <mem_init>

	// Lab 3 user environment initialization functions
	env_init();
f01000ef:	e8 2a 35 00 00       	call   f010361e <env_init>
	trap_init();
f01000f4:	e8 40 3e 00 00       	call   f0103f39 <trap_init>

	// Lab 4 multiprocessor initialization functions
	mp_init();
f01000f9:	e8 8b 61 00 00       	call   f0106289 <mp_init>
	lapic_init();
f01000fe:	66 90                	xchg   %ax,%ax
f0100100:	e8 b9 64 00 00       	call   f01065be <lapic_init>

	// Lab 4 multitasking initialization functions
	pic_init();
f0100105:	e8 b5 3c 00 00       	call   f0103dbf <pic_init>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f010010a:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f0100111:	e8 f3 66 00 00       	call   f0106809 <spin_lock>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100116:	83 3d 88 4e 1c f0 07 	cmpl   $0x7,0xf01c4e88
f010011d:	77 24                	ja     f0100143 <i386_init+0x9b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010011f:	c7 44 24 0c 00 70 00 	movl   $0x7000,0xc(%esp)
f0100126:	00 
f0100127:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f010012e:	f0 
f010012f:	c7 44 24 04 64 00 00 	movl   $0x64,0x4(%esp)
f0100136:	00 
f0100137:	c7 04 24 27 6d 10 f0 	movl   $0xf0106d27,(%esp)
f010013e:	e8 fd fe ff ff       	call   f0100040 <_panic>
	void *code;
	struct Cpu *c;

	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);
f0100143:	b8 b6 61 10 f0       	mov    $0xf01061b6,%eax
f0100148:	2d 3c 61 10 f0       	sub    $0xf010613c,%eax
f010014d:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100151:	c7 44 24 04 3c 61 10 	movl   $0xf010613c,0x4(%esp)
f0100158:	f0 
f0100159:	c7 04 24 00 70 00 f0 	movl   $0xf0007000,(%esp)
f0100160:	e8 f1 5d 00 00       	call   f0105f56 <memmove>

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100165:	6b 05 c4 53 1c f0 74 	imul   $0x74,0xf01c53c4,%eax
f010016c:	05 20 50 1c f0       	add    $0xf01c5020,%eax
f0100171:	3d 20 50 1c f0       	cmp    $0xf01c5020,%eax
f0100176:	0f 86 c2 00 00 00    	jbe    f010023e <i386_init+0x196>
f010017c:	bb 20 50 1c f0       	mov    $0xf01c5020,%ebx
		if (c == cpus + cpunum())  // We've started already.
f0100181:	e8 1d 64 00 00       	call   f01065a3 <cpunum>
f0100186:	6b c0 74             	imul   $0x74,%eax,%eax
f0100189:	05 20 50 1c f0       	add    $0xf01c5020,%eax
f010018e:	39 c3                	cmp    %eax,%ebx
f0100190:	74 39                	je     f01001cb <i386_init+0x123>
f0100192:	89 d8                	mov    %ebx,%eax
f0100194:	2d 20 50 1c f0       	sub    $0xf01c5020,%eax
			continue;

		// Tell mpentry.S what stack to use 
		mpentry_kstack = percpu_kstacks[c - cpus] + KSTKSIZE;
f0100199:	c1 f8 02             	sar    $0x2,%eax
f010019c:	69 c0 35 c2 72 4f    	imul   $0x4f72c235,%eax,%eax
f01001a2:	c1 e0 0f             	shl    $0xf,%eax
f01001a5:	8d 80 00 e0 1c f0    	lea    -0xfe32000(%eax),%eax
f01001ab:	a3 84 4e 1c f0       	mov    %eax,0xf01c4e84
		// Start the CPU at mpentry_start
		lapic_startap(c->cpu_id, PADDR(code));
f01001b0:	c7 44 24 04 00 70 00 	movl   $0x7000,0x4(%esp)
f01001b7:	00 
f01001b8:	0f b6 03             	movzbl (%ebx),%eax
f01001bb:	89 04 24             	mov    %eax,(%esp)
f01001be:	e8 33 65 00 00       	call   f01066f6 <lapic_startap>
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
f01001ce:	6b 05 c4 53 1c f0 74 	imul   $0x74,0xf01c53c4,%eax
f01001d5:	05 20 50 1c f0       	add    $0xf01c5020,%eax
f01001da:	39 c3                	cmp    %eax,%ebx
f01001dc:	72 a3                	jb     f0100181 <i386_init+0xd9>
f01001de:	eb 5e                	jmp    f010023e <i386_init+0x196>
	boot_aps();

	// Should always have idle processes at first.
	int i;
	for (i = 0; i < NCPU; i++){
		ENV_CREATE(user_idle, ENV_TYPE_IDLE);
f01001e0:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01001e7:	00 
f01001e8:	c7 44 24 04 1d 3c 00 	movl   $0x3c1d,0x4(%esp)
f01001ef:	00 
f01001f0:	c7 04 24 0f 32 15 f0 	movl   $0xf015320f,(%esp)
f01001f7:	e8 e8 35 00 00       	call   f01037e4 <env_create>
	// Starting non-boot CPUs
	boot_aps();

	// Should always have idle processes at first.
	int i;
	for (i = 0; i < NCPU; i++){
f01001fc:	83 eb 01             	sub    $0x1,%ebx
f01001ff:	75 df                	jne    f01001e0 <i386_init+0x138>
		ENV_CREATE(user_idle, ENV_TYPE_IDLE);
	}

	// Start fs.
	ENV_CREATE(fs_fs, ENV_TYPE_FS);
f0100201:	c7 44 24 08 02 00 00 	movl   $0x2,0x8(%esp)
f0100208:	00 
f0100209:	c7 44 24 04 67 63 01 	movl   $0x16367,0x4(%esp)
f0100210:	00 
f0100211:	c7 04 24 84 ce 1a f0 	movl   $0xf01ace84,(%esp)
f0100218:	e8 c7 35 00 00       	call   f01037e4 <env_create>

#if defined(TEST)
	// Don't touch -- used by grading script!
	ENV_CREATE(TEST, ENV_TYPE_USER);
f010021d:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0100224:	00 
f0100225:	c7 44 24 04 63 4c 00 	movl   $0x4c63,0x4(%esp)
f010022c:	00 
f010022d:	c7 04 24 21 82 1a f0 	movl   $0xf01a8221,(%esp)
f0100234:	e8 ab 35 00 00       	call   f01037e4 <env_create>
	// ENV_CREATE(user_icode, ENV_TYPE_USER);

#endif // TEST*

	// Schedule and run the first user environment!
	sched_yield();
f0100239:	e8 82 49 00 00       	call   f0104bc0 <sched_yield>
	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f010023e:	bb 08 00 00 00       	mov    $0x8,%ebx
f0100243:	eb 9b                	jmp    f01001e0 <i386_init+0x138>

f0100245 <mp_main>:
}

// Setup code for APs
void
mp_main(void)
{
f0100245:	55                   	push   %ebp
f0100246:	89 e5                	mov    %esp,%ebp
f0100248:	83 ec 18             	sub    $0x18,%esp
	// We are in high EIP now, safe to switch to kern_pgdir 
	lcr3(PADDR(kern_pgdir));
f010024b:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100250:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0100255:	77 20                	ja     f0100277 <mp_main+0x32>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0100257:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010025b:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0100262:	f0 
f0100263:	c7 44 24 04 7b 00 00 	movl   $0x7b,0x4(%esp)
f010026a:	00 
f010026b:	c7 04 24 27 6d 10 f0 	movl   $0xf0106d27,(%esp)
f0100272:	e8 c9 fd ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0100277:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f010027c:	0f 22 d8             	mov    %eax,%cr3
	cprintf("SMP: CPU %d starting\n", cpunum());
f010027f:	e8 1f 63 00 00       	call   f01065a3 <cpunum>
f0100284:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100288:	c7 04 24 33 6d 10 f0 	movl   $0xf0106d33,(%esp)
f010028f:	e8 fe 3b 00 00       	call   f0103e92 <cprintf>

	lapic_init();
f0100294:	e8 25 63 00 00       	call   f01065be <lapic_init>
	env_init_percpu();
f0100299:	e8 56 33 00 00       	call   f01035f4 <env_init_percpu>
	trap_init_percpu();
f010029e:	66 90                	xchg   %ax,%ax
f01002a0:	e8 0b 3c 00 00       	call   f0103eb0 <trap_init_percpu>
	xchg(&thiscpu->cpu_status, CPU_STARTED); // tell boot_aps() we're up
f01002a5:	e8 f9 62 00 00       	call   f01065a3 <cpunum>
f01002aa:	6b d0 74             	imul   $0x74,%eax,%edx
f01002ad:	81 c2 20 50 1c f0    	add    $0xf01c5020,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f01002b3:	b8 01 00 00 00       	mov    $0x1,%eax
f01002b8:	f0 87 42 04          	lock xchg %eax,0x4(%edx)
f01002bc:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f01002c3:	e8 41 65 00 00       	call   f0106809 <spin_lock>
	// to start running processes on this CPU.  But make sure that
	// only one CPU can enter the scheduler at a time!
	//
	// Your code here:
	lock_kernel();
	sched_yield();
f01002c8:	e8 f3 48 00 00       	call   f0104bc0 <sched_yield>

f01002cd <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f01002cd:	55                   	push   %ebp
f01002ce:	89 e5                	mov    %esp,%ebp
f01002d0:	53                   	push   %ebx
f01002d1:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f01002d4:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f01002d7:	8b 45 0c             	mov    0xc(%ebp),%eax
f01002da:	89 44 24 08          	mov    %eax,0x8(%esp)
f01002de:	8b 45 08             	mov    0x8(%ebp),%eax
f01002e1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01002e5:	c7 04 24 49 6d 10 f0 	movl   $0xf0106d49,(%esp)
f01002ec:	e8 a1 3b 00 00       	call   f0103e92 <cprintf>
	vcprintf(fmt, ap);
f01002f1:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01002f5:	8b 45 10             	mov    0x10(%ebp),%eax
f01002f8:	89 04 24             	mov    %eax,(%esp)
f01002fb:	e8 5f 3b 00 00       	call   f0103e5f <vcprintf>
	cprintf("\n");
f0100300:	c7 04 24 4a 7d 10 f0 	movl   $0xf0107d4a,(%esp)
f0100307:	e8 86 3b 00 00       	call   f0103e92 <cprintf>
	va_end(ap);
}
f010030c:	83 c4 14             	add    $0x14,%esp
f010030f:	5b                   	pop    %ebx
f0100310:	5d                   	pop    %ebp
f0100311:	c3                   	ret    
f0100312:	66 90                	xchg   %ax,%ax
f0100314:	66 90                	xchg   %ax,%ax
f0100316:	66 90                	xchg   %ax,%ax
f0100318:	66 90                	xchg   %ax,%ax
f010031a:	66 90                	xchg   %ax,%ax
f010031c:	66 90                	xchg   %ax,%ax
f010031e:	66 90                	xchg   %ax,%ax

f0100320 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f0100320:	55                   	push   %ebp
f0100321:	89 e5                	mov    %esp,%ebp

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100323:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100328:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f0100329:	a8 01                	test   $0x1,%al
f010032b:	74 08                	je     f0100335 <serial_proc_data+0x15>
f010032d:	b2 f8                	mov    $0xf8,%dl
f010032f:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f0100330:	0f b6 c0             	movzbl %al,%eax
f0100333:	eb 05                	jmp    f010033a <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f0100335:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f010033a:	5d                   	pop    %ebp
f010033b:	c3                   	ret    

f010033c <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f010033c:	55                   	push   %ebp
f010033d:	89 e5                	mov    %esp,%ebp
f010033f:	53                   	push   %ebx
f0100340:	83 ec 04             	sub    $0x4,%esp
f0100343:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f0100345:	eb 2a                	jmp    f0100371 <cons_intr+0x35>
		if (c == 0)
f0100347:	85 d2                	test   %edx,%edx
f0100349:	74 26                	je     f0100371 <cons_intr+0x35>
			continue;
		cons.buf[cons.wpos++] = c;
f010034b:	a1 24 42 1c f0       	mov    0xf01c4224,%eax
f0100350:	8d 48 01             	lea    0x1(%eax),%ecx
f0100353:	89 0d 24 42 1c f0    	mov    %ecx,0xf01c4224
f0100359:	88 90 20 40 1c f0    	mov    %dl,-0xfe3bfe0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f010035f:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100365:	75 0a                	jne    f0100371 <cons_intr+0x35>
			cons.wpos = 0;
f0100367:	c7 05 24 42 1c f0 00 	movl   $0x0,0xf01c4224
f010036e:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f0100371:	ff d3                	call   *%ebx
f0100373:	89 c2                	mov    %eax,%edx
f0100375:	83 f8 ff             	cmp    $0xffffffff,%eax
f0100378:	75 cd                	jne    f0100347 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f010037a:	83 c4 04             	add    $0x4,%esp
f010037d:	5b                   	pop    %ebx
f010037e:	5d                   	pop    %ebp
f010037f:	c3                   	ret    

f0100380 <kbd_proc_data>:
f0100380:	ba 64 00 00 00       	mov    $0x64,%edx
f0100385:	ec                   	in     (%dx),%al
{
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
f0100386:	a8 01                	test   $0x1,%al
f0100388:	0f 84 ef 00 00 00    	je     f010047d <kbd_proc_data+0xfd>
f010038e:	b2 60                	mov    $0x60,%dl
f0100390:	ec                   	in     (%dx),%al
f0100391:	89 c2                	mov    %eax,%edx
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f0100393:	3c e0                	cmp    $0xe0,%al
f0100395:	75 0d                	jne    f01003a4 <kbd_proc_data+0x24>
		// E0 escape character
		shift |= E0ESC;
f0100397:	83 0d 00 40 1c f0 40 	orl    $0x40,0xf01c4000
		return 0;
f010039e:	b8 00 00 00 00       	mov    $0x0,%eax
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f01003a3:	c3                   	ret    
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f01003a4:	55                   	push   %ebp
f01003a5:	89 e5                	mov    %esp,%ebp
f01003a7:	53                   	push   %ebx
f01003a8:	83 ec 14             	sub    $0x14,%esp

	if (data == 0xE0) {
		// E0 escape character
		shift |= E0ESC;
		return 0;
	} else if (data & 0x80) {
f01003ab:	84 c0                	test   %al,%al
f01003ad:	79 37                	jns    f01003e6 <kbd_proc_data+0x66>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f01003af:	8b 0d 00 40 1c f0    	mov    0xf01c4000,%ecx
f01003b5:	89 cb                	mov    %ecx,%ebx
f01003b7:	83 e3 40             	and    $0x40,%ebx
f01003ba:	83 e0 7f             	and    $0x7f,%eax
f01003bd:	85 db                	test   %ebx,%ebx
f01003bf:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f01003c2:	0f b6 d2             	movzbl %dl,%edx
f01003c5:	0f b6 82 c0 6e 10 f0 	movzbl -0xfef9140(%edx),%eax
f01003cc:	83 c8 40             	or     $0x40,%eax
f01003cf:	0f b6 c0             	movzbl %al,%eax
f01003d2:	f7 d0                	not    %eax
f01003d4:	21 c1                	and    %eax,%ecx
f01003d6:	89 0d 00 40 1c f0    	mov    %ecx,0xf01c4000
		return 0;
f01003dc:	b8 00 00 00 00       	mov    $0x0,%eax
f01003e1:	e9 9d 00 00 00       	jmp    f0100483 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f01003e6:	8b 0d 00 40 1c f0    	mov    0xf01c4000,%ecx
f01003ec:	f6 c1 40             	test   $0x40,%cl
f01003ef:	74 0e                	je     f01003ff <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f01003f1:	83 c8 80             	or     $0xffffff80,%eax
f01003f4:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f01003f6:	83 e1 bf             	and    $0xffffffbf,%ecx
f01003f9:	89 0d 00 40 1c f0    	mov    %ecx,0xf01c4000
	}

	shift |= shiftcode[data];
f01003ff:	0f b6 d2             	movzbl %dl,%edx
f0100402:	0f b6 82 c0 6e 10 f0 	movzbl -0xfef9140(%edx),%eax
f0100409:	0b 05 00 40 1c f0    	or     0xf01c4000,%eax
	shift ^= togglecode[data];
f010040f:	0f b6 8a c0 6d 10 f0 	movzbl -0xfef9240(%edx),%ecx
f0100416:	31 c8                	xor    %ecx,%eax
f0100418:	a3 00 40 1c f0       	mov    %eax,0xf01c4000

	c = charcode[shift & (CTL | SHIFT)][data];
f010041d:	89 c1                	mov    %eax,%ecx
f010041f:	83 e1 03             	and    $0x3,%ecx
f0100422:	8b 0c 8d a0 6d 10 f0 	mov    -0xfef9260(,%ecx,4),%ecx
f0100429:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f010042d:	0f b6 da             	movzbl %dl,%ebx
	if (shift & CAPSLOCK) {
f0100430:	a8 08                	test   $0x8,%al
f0100432:	74 1b                	je     f010044f <kbd_proc_data+0xcf>
		if ('a' <= c && c <= 'z')
f0100434:	89 da                	mov    %ebx,%edx
f0100436:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f0100439:	83 f9 19             	cmp    $0x19,%ecx
f010043c:	77 05                	ja     f0100443 <kbd_proc_data+0xc3>
			c += 'A' - 'a';
f010043e:	83 eb 20             	sub    $0x20,%ebx
f0100441:	eb 0c                	jmp    f010044f <kbd_proc_data+0xcf>
		else if ('A' <= c && c <= 'Z')
f0100443:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f0100446:	8d 4b 20             	lea    0x20(%ebx),%ecx
f0100449:	83 fa 19             	cmp    $0x19,%edx
f010044c:	0f 46 d9             	cmovbe %ecx,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f010044f:	f7 d0                	not    %eax
f0100451:	89 c2                	mov    %eax,%edx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100453:	89 d8                	mov    %ebx,%eax
			c += 'a' - 'A';
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f0100455:	f6 c2 06             	test   $0x6,%dl
f0100458:	75 29                	jne    f0100483 <kbd_proc_data+0x103>
f010045a:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f0100460:	75 21                	jne    f0100483 <kbd_proc_data+0x103>
		cprintf("Rebooting!\n");
f0100462:	c7 04 24 63 6d 10 f0 	movl   $0xf0106d63,(%esp)
f0100469:	e8 24 3a 00 00       	call   f0103e92 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010046e:	ba 92 00 00 00       	mov    $0x92,%edx
f0100473:	b8 03 00 00 00       	mov    $0x3,%eax
f0100478:	ee                   	out    %al,(%dx)
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100479:	89 d8                	mov    %ebx,%eax
f010047b:	eb 06                	jmp    f0100483 <kbd_proc_data+0x103>
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
		return -1;
f010047d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100482:	c3                   	ret    
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100483:	83 c4 14             	add    $0x14,%esp
f0100486:	5b                   	pop    %ebx
f0100487:	5d                   	pop    %ebp
f0100488:	c3                   	ret    

f0100489 <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f0100489:	55                   	push   %ebp
f010048a:	89 e5                	mov    %esp,%ebp
f010048c:	57                   	push   %edi
f010048d:	56                   	push   %esi
f010048e:	53                   	push   %ebx
f010048f:	83 ec 1c             	sub    $0x1c,%esp
f0100492:	89 c7                	mov    %eax,%edi

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100494:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100499:	ec                   	in     (%dx),%al
static void
serial_putc(int c)
{
	int i;
	
	for (i = 0;
f010049a:	a8 20                	test   $0x20,%al
f010049c:	75 21                	jne    f01004bf <cons_putc+0x36>
f010049e:	bb 00 32 00 00       	mov    $0x3200,%ebx
f01004a3:	b9 84 00 00 00       	mov    $0x84,%ecx
f01004a8:	be fd 03 00 00       	mov    $0x3fd,%esi
f01004ad:	89 ca                	mov    %ecx,%edx
f01004af:	ec                   	in     (%dx),%al
f01004b0:	ec                   	in     (%dx),%al
f01004b1:	ec                   	in     (%dx),%al
f01004b2:	ec                   	in     (%dx),%al
f01004b3:	89 f2                	mov    %esi,%edx
f01004b5:	ec                   	in     (%dx),%al
f01004b6:	a8 20                	test   $0x20,%al
f01004b8:	75 05                	jne    f01004bf <cons_putc+0x36>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f01004ba:	83 eb 01             	sub    $0x1,%ebx
f01004bd:	75 ee                	jne    f01004ad <cons_putc+0x24>
	     i++)
		delay();
	
	outb(COM1 + COM_TX, c);
f01004bf:	89 f8                	mov    %edi,%eax
f01004c1:	0f b6 c0             	movzbl %al,%eax
f01004c4:	89 45 e4             	mov    %eax,-0x1c(%ebp)
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01004c7:	ba f8 03 00 00       	mov    $0x3f8,%edx
f01004cc:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01004cd:	b2 79                	mov    $0x79,%dl
f01004cf:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f01004d0:	84 c0                	test   %al,%al
f01004d2:	78 21                	js     f01004f5 <cons_putc+0x6c>
f01004d4:	bb 00 32 00 00       	mov    $0x3200,%ebx
f01004d9:	b9 84 00 00 00       	mov    $0x84,%ecx
f01004de:	be 79 03 00 00       	mov    $0x379,%esi
f01004e3:	89 ca                	mov    %ecx,%edx
f01004e5:	ec                   	in     (%dx),%al
f01004e6:	ec                   	in     (%dx),%al
f01004e7:	ec                   	in     (%dx),%al
f01004e8:	ec                   	in     (%dx),%al
f01004e9:	89 f2                	mov    %esi,%edx
f01004eb:	ec                   	in     (%dx),%al
f01004ec:	84 c0                	test   %al,%al
f01004ee:	78 05                	js     f01004f5 <cons_putc+0x6c>
f01004f0:	83 eb 01             	sub    $0x1,%ebx
f01004f3:	75 ee                	jne    f01004e3 <cons_putc+0x5a>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01004f5:	ba 78 03 00 00       	mov    $0x378,%edx
f01004fa:	0f b6 45 e4          	movzbl -0x1c(%ebp),%eax
f01004fe:	ee                   	out    %al,(%dx)
f01004ff:	b2 7a                	mov    $0x7a,%dl
f0100501:	b8 0d 00 00 00       	mov    $0xd,%eax
f0100506:	ee                   	out    %al,(%dx)
f0100507:	b8 08 00 00 00       	mov    $0x8,%eax
f010050c:	ee                   	out    %al,(%dx)

static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f010050d:	89 fa                	mov    %edi,%edx
f010050f:	81 e2 00 ff ff ff    	and    $0xffffff00,%edx
		c |= 0x0700;
f0100515:	89 f8                	mov    %edi,%eax
f0100517:	80 cc 07             	or     $0x7,%ah
f010051a:	85 d2                	test   %edx,%edx
f010051c:	0f 44 f8             	cmove  %eax,%edi

	switch (c & 0xff) {
f010051f:	89 f8                	mov    %edi,%eax
f0100521:	0f b6 c0             	movzbl %al,%eax
f0100524:	83 f8 09             	cmp    $0x9,%eax
f0100527:	74 79                	je     f01005a2 <cons_putc+0x119>
f0100529:	83 f8 09             	cmp    $0x9,%eax
f010052c:	7f 0a                	jg     f0100538 <cons_putc+0xaf>
f010052e:	83 f8 08             	cmp    $0x8,%eax
f0100531:	74 19                	je     f010054c <cons_putc+0xc3>
f0100533:	e9 9e 00 00 00       	jmp    f01005d6 <cons_putc+0x14d>
f0100538:	83 f8 0a             	cmp    $0xa,%eax
f010053b:	90                   	nop
f010053c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100540:	74 3a                	je     f010057c <cons_putc+0xf3>
f0100542:	83 f8 0d             	cmp    $0xd,%eax
f0100545:	74 3d                	je     f0100584 <cons_putc+0xfb>
f0100547:	e9 8a 00 00 00       	jmp    f01005d6 <cons_putc+0x14d>
	case '\b':
		if (crt_pos > 0) {
f010054c:	0f b7 05 28 42 1c f0 	movzwl 0xf01c4228,%eax
f0100553:	66 85 c0             	test   %ax,%ax
f0100556:	0f 84 e5 00 00 00    	je     f0100641 <cons_putc+0x1b8>
			crt_pos--;
f010055c:	83 e8 01             	sub    $0x1,%eax
f010055f:	66 a3 28 42 1c f0    	mov    %ax,0xf01c4228
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100565:	0f b7 c0             	movzwl %ax,%eax
f0100568:	66 81 e7 00 ff       	and    $0xff00,%di
f010056d:	83 cf 20             	or     $0x20,%edi
f0100570:	8b 15 2c 42 1c f0    	mov    0xf01c422c,%edx
f0100576:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f010057a:	eb 78                	jmp    f01005f4 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f010057c:	66 83 05 28 42 1c f0 	addw   $0x50,0xf01c4228
f0100583:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f0100584:	0f b7 05 28 42 1c f0 	movzwl 0xf01c4228,%eax
f010058b:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100591:	c1 e8 16             	shr    $0x16,%eax
f0100594:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0100597:	c1 e0 04             	shl    $0x4,%eax
f010059a:	66 a3 28 42 1c f0    	mov    %ax,0xf01c4228
f01005a0:	eb 52                	jmp    f01005f4 <cons_putc+0x16b>
		break;
	case '\t':
		cons_putc(' ');
f01005a2:	b8 20 00 00 00       	mov    $0x20,%eax
f01005a7:	e8 dd fe ff ff       	call   f0100489 <cons_putc>
		cons_putc(' ');
f01005ac:	b8 20 00 00 00       	mov    $0x20,%eax
f01005b1:	e8 d3 fe ff ff       	call   f0100489 <cons_putc>
		cons_putc(' ');
f01005b6:	b8 20 00 00 00       	mov    $0x20,%eax
f01005bb:	e8 c9 fe ff ff       	call   f0100489 <cons_putc>
		cons_putc(' ');
f01005c0:	b8 20 00 00 00       	mov    $0x20,%eax
f01005c5:	e8 bf fe ff ff       	call   f0100489 <cons_putc>
		cons_putc(' ');
f01005ca:	b8 20 00 00 00       	mov    $0x20,%eax
f01005cf:	e8 b5 fe ff ff       	call   f0100489 <cons_putc>
f01005d4:	eb 1e                	jmp    f01005f4 <cons_putc+0x16b>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f01005d6:	0f b7 05 28 42 1c f0 	movzwl 0xf01c4228,%eax
f01005dd:	8d 50 01             	lea    0x1(%eax),%edx
f01005e0:	66 89 15 28 42 1c f0 	mov    %dx,0xf01c4228
f01005e7:	0f b7 c0             	movzwl %ax,%eax
f01005ea:	8b 15 2c 42 1c f0    	mov    0xf01c422c,%edx
f01005f0:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f01005f4:	66 81 3d 28 42 1c f0 	cmpw   $0x7cf,0xf01c4228
f01005fb:	cf 07 
f01005fd:	76 42                	jbe    f0100641 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f01005ff:	a1 2c 42 1c f0       	mov    0xf01c422c,%eax
f0100604:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010060b:	00 
f010060c:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100612:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100616:	89 04 24             	mov    %eax,(%esp)
f0100619:	e8 38 59 00 00       	call   f0105f56 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010061e:	8b 15 2c 42 1c f0    	mov    0xf01c422c,%edx
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f0100624:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f0100629:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f010062f:	83 c0 01             	add    $0x1,%eax
f0100632:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f0100637:	75 f0                	jne    f0100629 <cons_putc+0x1a0>
			crt_buf[i] = 0x0700 | ' ';
		crt_pos -= CRT_COLS;
f0100639:	66 83 2d 28 42 1c f0 	subw   $0x50,0xf01c4228
f0100640:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100641:	8b 0d 30 42 1c f0    	mov    0xf01c4230,%ecx
f0100647:	b8 0e 00 00 00       	mov    $0xe,%eax
f010064c:	89 ca                	mov    %ecx,%edx
f010064e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010064f:	0f b7 1d 28 42 1c f0 	movzwl 0xf01c4228,%ebx
f0100656:	8d 71 01             	lea    0x1(%ecx),%esi
f0100659:	89 d8                	mov    %ebx,%eax
f010065b:	66 c1 e8 08          	shr    $0x8,%ax
f010065f:	89 f2                	mov    %esi,%edx
f0100661:	ee                   	out    %al,(%dx)
f0100662:	b8 0f 00 00 00       	mov    $0xf,%eax
f0100667:	89 ca                	mov    %ecx,%edx
f0100669:	ee                   	out    %al,(%dx)
f010066a:	89 d8                	mov    %ebx,%eax
f010066c:	89 f2                	mov    %esi,%edx
f010066e:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f010066f:	83 c4 1c             	add    $0x1c,%esp
f0100672:	5b                   	pop    %ebx
f0100673:	5e                   	pop    %esi
f0100674:	5f                   	pop    %edi
f0100675:	5d                   	pop    %ebp
f0100676:	c3                   	ret    

f0100677 <serial_intr>:
}

void
serial_intr(void)
{
	if (serial_exists)
f0100677:	83 3d 34 42 1c f0 00 	cmpl   $0x0,0xf01c4234
f010067e:	74 11                	je     f0100691 <serial_intr+0x1a>
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f0100680:	55                   	push   %ebp
f0100681:	89 e5                	mov    %esp,%ebp
f0100683:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
		cons_intr(serial_proc_data);
f0100686:	b8 20 03 10 f0       	mov    $0xf0100320,%eax
f010068b:	e8 ac fc ff ff       	call   f010033c <cons_intr>
}
f0100690:	c9                   	leave  
f0100691:	f3 c3                	repz ret 

f0100693 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f0100693:	55                   	push   %ebp
f0100694:	89 e5                	mov    %esp,%ebp
f0100696:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f0100699:	b8 80 03 10 f0       	mov    $0xf0100380,%eax
f010069e:	e8 99 fc ff ff       	call   f010033c <cons_intr>
}
f01006a3:	c9                   	leave  
f01006a4:	c3                   	ret    

f01006a5 <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f01006a5:	55                   	push   %ebp
f01006a6:	89 e5                	mov    %esp,%ebp
f01006a8:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f01006ab:	e8 c7 ff ff ff       	call   f0100677 <serial_intr>
	kbd_intr();
f01006b0:	e8 de ff ff ff       	call   f0100693 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f01006b5:	a1 20 42 1c f0       	mov    0xf01c4220,%eax
f01006ba:	3b 05 24 42 1c f0    	cmp    0xf01c4224,%eax
f01006c0:	74 26                	je     f01006e8 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f01006c2:	8d 50 01             	lea    0x1(%eax),%edx
f01006c5:	89 15 20 42 1c f0    	mov    %edx,0xf01c4220
f01006cb:	0f b6 88 20 40 1c f0 	movzbl -0xfe3bfe0(%eax),%ecx
		if (cons.rpos == CONSBUFSIZE)
			cons.rpos = 0;
		return c;
f01006d2:	89 c8                	mov    %ecx,%eax
	kbd_intr();

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
		c = cons.buf[cons.rpos++];
		if (cons.rpos == CONSBUFSIZE)
f01006d4:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f01006da:	75 11                	jne    f01006ed <cons_getc+0x48>
			cons.rpos = 0;
f01006dc:	c7 05 20 42 1c f0 00 	movl   $0x0,0xf01c4220
f01006e3:	00 00 00 
f01006e6:	eb 05                	jmp    f01006ed <cons_getc+0x48>
		return c;
	}
	return 0;
f01006e8:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01006ed:	c9                   	leave  
f01006ee:	c3                   	ret    

f01006ef <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f01006ef:	55                   	push   %ebp
f01006f0:	89 e5                	mov    %esp,%ebp
f01006f2:	57                   	push   %edi
f01006f3:	56                   	push   %esi
f01006f4:	53                   	push   %ebx
f01006f5:	83 ec 1c             	sub    $0x1c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f01006f8:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f01006ff:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f0100706:	5a a5 
	if (*cp != 0xA55A) {
f0100708:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f010070f:	66 3d 5a a5          	cmp    $0xa55a,%ax
f0100713:	74 11                	je     f0100726 <cons_init+0x37>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f0100715:	c7 05 30 42 1c f0 b4 	movl   $0x3b4,0xf01c4230
f010071c:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f010071f:	bf 00 00 0b f0       	mov    $0xf00b0000,%edi
f0100724:	eb 16                	jmp    f010073c <cons_init+0x4d>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f0100726:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f010072d:	c7 05 30 42 1c f0 d4 	movl   $0x3d4,0xf01c4230
f0100734:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f0100737:	bf 00 80 0b f0       	mov    $0xf00b8000,%edi
		*cp = was;
		addr_6845 = CGA_BASE;
	}
	
	/* Extract cursor location */
	outb(addr_6845, 14);
f010073c:	8b 0d 30 42 1c f0    	mov    0xf01c4230,%ecx
f0100742:	b8 0e 00 00 00       	mov    $0xe,%eax
f0100747:	89 ca                	mov    %ecx,%edx
f0100749:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f010074a:	8d 59 01             	lea    0x1(%ecx),%ebx

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010074d:	89 da                	mov    %ebx,%edx
f010074f:	ec                   	in     (%dx),%al
f0100750:	0f b6 f0             	movzbl %al,%esi
f0100753:	c1 e6 08             	shl    $0x8,%esi
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100756:	b8 0f 00 00 00       	mov    $0xf,%eax
f010075b:	89 ca                	mov    %ecx,%edx
f010075d:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010075e:	89 da                	mov    %ebx,%edx
f0100760:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f0100761:	89 3d 2c 42 1c f0    	mov    %edi,0xf01c422c
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f0100767:	0f b6 d8             	movzbl %al,%ebx
f010076a:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f010076c:	66 89 35 28 42 1c f0 	mov    %si,0xf01c4228

static void
kbd_init(void)
{
	// Drain the kbd buffer so that Bochs generates interrupts.
	kbd_intr();
f0100773:	e8 1b ff ff ff       	call   f0100693 <kbd_intr>
	irq_setmask_8259A(irq_mask_8259A & ~(1<<1));
f0100778:	0f b7 05 88 13 12 f0 	movzwl 0xf0121388,%eax
f010077f:	25 fd ff 00 00       	and    $0xfffd,%eax
f0100784:	89 04 24             	mov    %eax,(%esp)
f0100787:	e8 c4 35 00 00       	call   f0103d50 <irq_setmask_8259A>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010078c:	be fa 03 00 00       	mov    $0x3fa,%esi
f0100791:	b8 00 00 00 00       	mov    $0x0,%eax
f0100796:	89 f2                	mov    %esi,%edx
f0100798:	ee                   	out    %al,(%dx)
f0100799:	b2 fb                	mov    $0xfb,%dl
f010079b:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f01007a0:	ee                   	out    %al,(%dx)
f01007a1:	bb f8 03 00 00       	mov    $0x3f8,%ebx
f01007a6:	b8 0c 00 00 00       	mov    $0xc,%eax
f01007ab:	89 da                	mov    %ebx,%edx
f01007ad:	ee                   	out    %al,(%dx)
f01007ae:	b2 f9                	mov    $0xf9,%dl
f01007b0:	b8 00 00 00 00       	mov    $0x0,%eax
f01007b5:	ee                   	out    %al,(%dx)
f01007b6:	b2 fb                	mov    $0xfb,%dl
f01007b8:	b8 03 00 00 00       	mov    $0x3,%eax
f01007bd:	ee                   	out    %al,(%dx)
f01007be:	b2 fc                	mov    $0xfc,%dl
f01007c0:	b8 00 00 00 00       	mov    $0x0,%eax
f01007c5:	ee                   	out    %al,(%dx)
f01007c6:	b2 f9                	mov    $0xf9,%dl
f01007c8:	b8 01 00 00 00       	mov    $0x1,%eax
f01007cd:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01007ce:	b2 fd                	mov    $0xfd,%dl
f01007d0:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f01007d1:	3c ff                	cmp    $0xff,%al
f01007d3:	0f 95 c1             	setne  %cl
f01007d6:	0f b6 c9             	movzbl %cl,%ecx
f01007d9:	89 0d 34 42 1c f0    	mov    %ecx,0xf01c4234
f01007df:	89 f2                	mov    %esi,%edx
f01007e1:	ec                   	in     (%dx),%al
f01007e2:	89 da                	mov    %ebx,%edx
f01007e4:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f01007e5:	85 c9                	test   %ecx,%ecx
f01007e7:	75 0c                	jne    f01007f5 <cons_init+0x106>
		cprintf("Serial port does not exist!\n");
f01007e9:	c7 04 24 6f 6d 10 f0 	movl   $0xf0106d6f,(%esp)
f01007f0:	e8 9d 36 00 00       	call   f0103e92 <cprintf>
}
f01007f5:	83 c4 1c             	add    $0x1c,%esp
f01007f8:	5b                   	pop    %ebx
f01007f9:	5e                   	pop    %esi
f01007fa:	5f                   	pop    %edi
f01007fb:	5d                   	pop    %ebp
f01007fc:	c3                   	ret    

f01007fd <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f01007fd:	55                   	push   %ebp
f01007fe:	89 e5                	mov    %esp,%ebp
f0100800:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f0100803:	8b 45 08             	mov    0x8(%ebp),%eax
f0100806:	e8 7e fc ff ff       	call   f0100489 <cons_putc>
}
f010080b:	c9                   	leave  
f010080c:	c3                   	ret    

f010080d <getchar>:

int
getchar(void)
{
f010080d:	55                   	push   %ebp
f010080e:	89 e5                	mov    %esp,%ebp
f0100810:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f0100813:	e8 8d fe ff ff       	call   f01006a5 <cons_getc>
f0100818:	85 c0                	test   %eax,%eax
f010081a:	74 f7                	je     f0100813 <getchar+0x6>
		/* do nothing */;
	return c;
}
f010081c:	c9                   	leave  
f010081d:	c3                   	ret    

f010081e <iscons>:

int
iscons(int fdnum)
{
f010081e:	55                   	push   %ebp
f010081f:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f0100821:	b8 01 00 00 00       	mov    $0x1,%eax
f0100826:	5d                   	pop    %ebp
f0100827:	c3                   	ret    
f0100828:	66 90                	xchg   %ax,%ax
f010082a:	66 90                	xchg   %ax,%ax
f010082c:	66 90                	xchg   %ax,%ax
f010082e:	66 90                	xchg   %ax,%ax

f0100830 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100830:	55                   	push   %ebp
f0100831:	89 e5                	mov    %esp,%ebp
f0100833:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < NCOMMANDS; i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100836:	c7 44 24 08 c0 6f 10 	movl   $0xf0106fc0,0x8(%esp)
f010083d:	f0 
f010083e:	c7 44 24 04 de 6f 10 	movl   $0xf0106fde,0x4(%esp)
f0100845:	f0 
f0100846:	c7 04 24 e3 6f 10 f0 	movl   $0xf0106fe3,(%esp)
f010084d:	e8 40 36 00 00       	call   f0103e92 <cprintf>
f0100852:	c7 44 24 08 80 70 10 	movl   $0xf0107080,0x8(%esp)
f0100859:	f0 
f010085a:	c7 44 24 04 ec 6f 10 	movl   $0xf0106fec,0x4(%esp)
f0100861:	f0 
f0100862:	c7 04 24 e3 6f 10 f0 	movl   $0xf0106fe3,(%esp)
f0100869:	e8 24 36 00 00       	call   f0103e92 <cprintf>
f010086e:	c7 44 24 08 a8 70 10 	movl   $0xf01070a8,0x8(%esp)
f0100875:	f0 
f0100876:	c7 44 24 04 f5 6f 10 	movl   $0xf0106ff5,0x4(%esp)
f010087d:	f0 
f010087e:	c7 04 24 e3 6f 10 f0 	movl   $0xf0106fe3,(%esp)
f0100885:	e8 08 36 00 00       	call   f0103e92 <cprintf>
	return 0;
}
f010088a:	b8 00 00 00 00       	mov    $0x0,%eax
f010088f:	c9                   	leave  
f0100890:	c3                   	ret    

f0100891 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f0100891:	55                   	push   %ebp
f0100892:	89 e5                	mov    %esp,%ebp
f0100894:	83 ec 18             	sub    $0x18,%esp
	extern char entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f0100897:	c7 04 24 ff 6f 10 f0 	movl   $0xf0106fff,(%esp)
f010089e:	e8 ef 35 00 00       	call   f0103e92 <cprintf>
	cprintf(" this is work 1 insert:\n");
f01008a3:	c7 04 24 18 70 10 f0 	movl   $0xf0107018,(%esp)
f01008aa:	e8 e3 35 00 00       	call   f0103e92 <cprintf>
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
f01008af:	c7 44 24 08 0f 00 00 	movl   $0xf,0x8(%esp)
f01008b6:	00 
f01008b7:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
f01008be:	00 
f01008bf:	c7 04 24 d4 70 10 f0 	movl   $0xf01070d4,(%esp)
f01008c6:	e8 c7 35 00 00       	call   f0103e92 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
f01008cb:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f01008d2:	00 
f01008d3:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f01008da:	f0 
f01008db:	c7 04 24 0c 71 10 f0 	movl   $0xf010710c,(%esp)
f01008e2:	e8 ab 35 00 00       	call   f0103e92 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01008e7:	c7 44 24 08 97 6c 10 	movl   $0x106c97,0x8(%esp)
f01008ee:	00 
f01008ef:	c7 44 24 04 97 6c 10 	movl   $0xf0106c97,0x4(%esp)
f01008f6:	f0 
f01008f7:	c7 04 24 34 71 10 f0 	movl   $0xf0107134,(%esp)
f01008fe:	e8 8f 35 00 00       	call   f0103e92 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f0100903:	c7 44 24 08 eb 31 1c 	movl   $0x1c31eb,0x8(%esp)
f010090a:	00 
f010090b:	c7 44 24 04 eb 31 1c 	movl   $0xf01c31eb,0x4(%esp)
f0100912:	f0 
f0100913:	c7 04 24 58 71 10 f0 	movl   $0xf0107158,(%esp)
f010091a:	e8 73 35 00 00       	call   f0103e92 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f010091f:	c7 44 24 08 04 60 20 	movl   $0x206004,0x8(%esp)
f0100926:	00 
f0100927:	c7 44 24 04 04 60 20 	movl   $0xf0206004,0x4(%esp)
f010092e:	f0 
f010092f:	c7 04 24 7c 71 10 f0 	movl   $0xf010717c,(%esp)
f0100936:	e8 57 35 00 00       	call   f0103e92 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f010093b:	b8 03 64 20 f0       	mov    $0xf0206403,%eax
f0100940:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f0100945:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f010094b:	85 c0                	test   %eax,%eax
f010094d:	0f 48 c2             	cmovs  %edx,%eax
f0100950:	c1 f8 0a             	sar    $0xa,%eax
f0100953:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100957:	c7 04 24 a0 71 10 f0 	movl   $0xf01071a0,(%esp)
f010095e:	e8 2f 35 00 00       	call   f0103e92 <cprintf>
		(end-entry+1023)/1024);
	return 0;
}
f0100963:	b8 00 00 00 00       	mov    $0x0,%eax
f0100968:	c9                   	leave  
f0100969:	c3                   	ret    

f010096a <mon_backtrace>:
int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f010096a:	55                   	push   %ebp
f010096b:	89 e5                	mov    %esp,%ebp
f010096d:	56                   	push   %esi
f010096e:	53                   	push   %ebx
f010096f:	83 ec 40             	sub    $0x40,%esp
	// Your code here
	cprintf("start backtrace\n");
f0100972:	c7 04 24 31 70 10 f0 	movl   $0xf0107031,(%esp)
f0100979:	e8 14 35 00 00       	call   f0103e92 <cprintf>
	cprintf("\n");
f010097e:	c7 04 24 4a 7d 10 f0 	movl   $0xf0107d4a,(%esp)
f0100985:	e8 08 35 00 00       	call   f0103e92 <cprintf>

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f010098a:	89 e8                	mov    %ebp,%eax
f010098c:	89 c1                	mov    %eax,%ecx
	uint32_t eip;
	uint32_t ebp = read_ebp();
	uint32_t esp;
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
f010098e:	83 f8 ff             	cmp    $0xffffffff,%eax
f0100991:	74 63                	je     f01009f6 <mon_backtrace+0x8c>
		esp = ebp+8;
		eip = *(uint32_t*)(ebp+4);
f0100993:	8b 71 04             	mov    0x4(%ecx),%esi
		if(ebp==0){
			ebp = -1;
f0100996:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
		esp = ebp+8;
		eip = *(uint32_t*)(ebp+4);
		if(ebp==0){
f010099b:	85 c9                	test   %ecx,%ecx
f010099d:	74 02                	je     f01009a1 <mon_backtrace+0x37>
			ebp = -1;
		}else{
			ebp = *(uint32_t*)(ebp);
f010099f:	8b 19                	mov    (%ecx),%ebx
		}
		for(i=0;i<5;i++){
f01009a1:	b8 00 00 00 00       	mov    $0x0,%eax
		args[i] = *(uint32_t*)(esp+i*4);
f01009a6:	8b 54 81 08          	mov    0x8(%ecx,%eax,4),%edx
f01009aa:	89 54 85 e4          	mov    %edx,-0x1c(%ebp,%eax,4)
		if(ebp==0){
			ebp = -1;
		}else{
			ebp = *(uint32_t*)(ebp);
		}
		for(i=0;i<5;i++){
f01009ae:	83 c0 01             	add    $0x1,%eax
f01009b1:	83 f8 05             	cmp    $0x5,%eax
f01009b4:	75 f0                	jne    f01009a6 <mon_backtrace+0x3c>
		args[i] = *(uint32_t*)(esp+i*4);
	        }
                            cprintf("ebp  %08x   eip %08x   args  %08x  %08x  %08x  %08x  %08x\n",ebp,eip,args[0],args[1],args[2],args[3],args[4]);
f01009b6:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01009b9:	89 44 24 1c          	mov    %eax,0x1c(%esp)
f01009bd:	8b 45 f0             	mov    -0x10(%ebp),%eax
f01009c0:	89 44 24 18          	mov    %eax,0x18(%esp)
f01009c4:	8b 45 ec             	mov    -0x14(%ebp),%eax
f01009c7:	89 44 24 14          	mov    %eax,0x14(%esp)
f01009cb:	8b 45 e8             	mov    -0x18(%ebp),%eax
f01009ce:	89 44 24 10          	mov    %eax,0x10(%esp)
f01009d2:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01009d5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01009d9:	89 74 24 08          	mov    %esi,0x8(%esp)
f01009dd:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01009e1:	c7 04 24 cc 71 10 f0 	movl   $0xf01071cc,(%esp)
f01009e8:	e8 a5 34 00 00       	call   f0103e92 <cprintf>
	uint32_t eip;
	uint32_t ebp = read_ebp();
	uint32_t esp;
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
f01009ed:	83 fb ff             	cmp    $0xffffffff,%ebx
f01009f0:	74 04                	je     f01009f6 <mon_backtrace+0x8c>
f01009f2:	89 d9                	mov    %ebx,%ecx
f01009f4:	eb 9d                	jmp    f0100993 <mon_backtrace+0x29>
                            cprintf("ebp  %08x   eip %08x   args  %08x  %08x  %08x  %08x  %08x\n",ebp,eip,args[0],args[1],args[2],args[3],args[4]);

	}
	
	return 0;
}
f01009f6:	b8 00 00 00 00       	mov    $0x0,%eax
f01009fb:	83 c4 40             	add    $0x40,%esp
f01009fe:	5b                   	pop    %ebx
f01009ff:	5e                   	pop    %esi
f0100a00:	5d                   	pop    %ebp
f0100a01:	c3                   	ret    

f0100a02 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f0100a02:	55                   	push   %ebp
f0100a03:	89 e5                	mov    %esp,%ebp
f0100a05:	57                   	push   %edi
f0100a06:	56                   	push   %esi
f0100a07:	53                   	push   %ebx
f0100a08:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f0100a0b:	c7 04 24 08 72 10 f0 	movl   $0xf0107208,(%esp)
f0100a12:	e8 7b 34 00 00       	call   f0103e92 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f0100a17:	c7 04 24 2c 72 10 f0 	movl   $0xf010722c,(%esp)
f0100a1e:	e8 6f 34 00 00       	call   f0103e92 <cprintf>

	if (tf != NULL)
f0100a23:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f0100a27:	74 0b                	je     f0100a34 <monitor+0x32>
		print_trapframe(tf);
f0100a29:	8b 45 08             	mov    0x8(%ebp),%eax
f0100a2c:	89 04 24             	mov    %eax,(%esp)
f0100a2f:	e8 6f 3b 00 00       	call   f01045a3 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f0100a34:	c7 04 24 42 70 10 f0 	movl   $0xf0107042,(%esp)
f0100a3b:	e8 f0 51 00 00       	call   f0105c30 <readline>
f0100a40:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f0100a42:	85 c0                	test   %eax,%eax
f0100a44:	74 ee                	je     f0100a34 <monitor+0x32>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f0100a46:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f0100a4d:	be 00 00 00 00       	mov    $0x0,%esi
f0100a52:	eb 0a                	jmp    f0100a5e <monitor+0x5c>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f0100a54:	c6 03 00             	movb   $0x0,(%ebx)
f0100a57:	89 f7                	mov    %esi,%edi
f0100a59:	8d 5b 01             	lea    0x1(%ebx),%ebx
f0100a5c:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f0100a5e:	0f b6 03             	movzbl (%ebx),%eax
f0100a61:	84 c0                	test   %al,%al
f0100a63:	74 6a                	je     f0100acf <monitor+0xcd>
f0100a65:	0f be c0             	movsbl %al,%eax
f0100a68:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a6c:	c7 04 24 46 70 10 f0 	movl   $0xf0107046,(%esp)
f0100a73:	e8 31 54 00 00       	call   f0105ea9 <strchr>
f0100a78:	85 c0                	test   %eax,%eax
f0100a7a:	75 d8                	jne    f0100a54 <monitor+0x52>
			*buf++ = 0;
		if (*buf == 0)
f0100a7c:	80 3b 00             	cmpb   $0x0,(%ebx)
f0100a7f:	74 4e                	je     f0100acf <monitor+0xcd>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f0100a81:	83 fe 0f             	cmp    $0xf,%esi
f0100a84:	75 16                	jne    f0100a9c <monitor+0x9a>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f0100a86:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f0100a8d:	00 
f0100a8e:	c7 04 24 4b 70 10 f0 	movl   $0xf010704b,(%esp)
f0100a95:	e8 f8 33 00 00       	call   f0103e92 <cprintf>
f0100a9a:	eb 98                	jmp    f0100a34 <monitor+0x32>
			return 0;
		}
		argv[argc++] = buf;
f0100a9c:	8d 7e 01             	lea    0x1(%esi),%edi
f0100a9f:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f0100aa3:	0f b6 03             	movzbl (%ebx),%eax
f0100aa6:	84 c0                	test   %al,%al
f0100aa8:	75 0c                	jne    f0100ab6 <monitor+0xb4>
f0100aaa:	eb b0                	jmp    f0100a5c <monitor+0x5a>
			buf++;
f0100aac:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f0100aaf:	0f b6 03             	movzbl (%ebx),%eax
f0100ab2:	84 c0                	test   %al,%al
f0100ab4:	74 a6                	je     f0100a5c <monitor+0x5a>
f0100ab6:	0f be c0             	movsbl %al,%eax
f0100ab9:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100abd:	c7 04 24 46 70 10 f0 	movl   $0xf0107046,(%esp)
f0100ac4:	e8 e0 53 00 00       	call   f0105ea9 <strchr>
f0100ac9:	85 c0                	test   %eax,%eax
f0100acb:	74 df                	je     f0100aac <monitor+0xaa>
f0100acd:	eb 8d                	jmp    f0100a5c <monitor+0x5a>
			buf++;
	}
	argv[argc] = 0;
f0100acf:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f0100ad6:	00 

	// Lookup and invoke the command
	if (argc == 0)
f0100ad7:	85 f6                	test   %esi,%esi
f0100ad9:	0f 84 55 ff ff ff    	je     f0100a34 <monitor+0x32>
f0100adf:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100ae4:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f0100ae7:	8b 04 85 60 72 10 f0 	mov    -0xfef8da0(,%eax,4),%eax
f0100aee:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100af2:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100af5:	89 04 24             	mov    %eax,(%esp)
f0100af8:	e8 28 53 00 00       	call   f0105e25 <strcmp>
f0100afd:	85 c0                	test   %eax,%eax
f0100aff:	75 24                	jne    f0100b25 <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100b01:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100b04:	8b 55 08             	mov    0x8(%ebp),%edx
f0100b07:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100b0b:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100b0e:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100b12:	89 34 24             	mov    %esi,(%esp)
f0100b15:	ff 14 85 68 72 10 f0 	call   *-0xfef8d98(,%eax,4)
		print_trapframe(tf);

	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f0100b1c:	85 c0                	test   %eax,%eax
f0100b1e:	78 25                	js     f0100b45 <monitor+0x143>
f0100b20:	e9 0f ff ff ff       	jmp    f0100a34 <monitor+0x32>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
f0100b25:	83 c3 01             	add    $0x1,%ebx
f0100b28:	83 fb 03             	cmp    $0x3,%ebx
f0100b2b:	75 b7                	jne    f0100ae4 <monitor+0xe2>
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f0100b2d:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100b30:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100b34:	c7 04 24 68 70 10 f0 	movl   $0xf0107068,(%esp)
f0100b3b:	e8 52 33 00 00       	call   f0103e92 <cprintf>
f0100b40:	e9 ef fe ff ff       	jmp    f0100a34 <monitor+0x32>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f0100b45:	83 c4 5c             	add    $0x5c,%esp
f0100b48:	5b                   	pop    %ebx
f0100b49:	5e                   	pop    %esi
f0100b4a:	5f                   	pop    %edi
f0100b4b:	5d                   	pop    %ebp
f0100b4c:	c3                   	ret    

f0100b4d <read_eip>:
// return EIP of caller.
// does not work if inlined.
// putting at the end of the file seems to prevent inlining.
unsigned
read_eip()
{
f0100b4d:	55                   	push   %ebp
f0100b4e:	89 e5                	mov    %esp,%ebp
	uint32_t callerpc;
	__asm __volatile("movl 4(%%ebp), %0" : "=r" (callerpc));
f0100b50:	8b 45 04             	mov    0x4(%ebp),%eax
	return callerpc;
}
f0100b53:	5d                   	pop    %ebp
f0100b54:	c3                   	ret    
f0100b55:	66 90                	xchg   %ax,%ax
f0100b57:	66 90                	xchg   %ax,%ax
f0100b59:	66 90                	xchg   %ax,%ax
f0100b5b:	66 90                	xchg   %ax,%ax
f0100b5d:	66 90                	xchg   %ax,%ax
f0100b5f:	90                   	nop

f0100b60 <boot_alloc>:
// If we're out of memory, boot_alloc should panic.
// This function may ONLY be used during initialization,
// before the page_free_list list has been set up.
static void *
boot_alloc(uint32_t n)
{
f0100b60:	55                   	push   %ebp
f0100b61:	89 e5                	mov    %esp,%ebp
f0100b63:	53                   	push   %ebx
f0100b64:	83 ec 14             	sub    $0x14,%esp
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f0100b67:	83 3d 38 42 1c f0 00 	cmpl   $0x0,0xf01c4238
f0100b6e:	75 36                	jne    f0100ba6 <boot_alloc+0x46>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100b70:	ba 03 70 20 f0       	mov    $0xf0207003,%edx
f0100b75:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0100b7b:	89 15 38 42 1c f0    	mov    %edx,0xf01c4238
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f0100b81:	85 c0                	test   %eax,%eax
f0100b83:	74 19                	je     f0100b9e <boot_alloc+0x3e>
                      result = nextfree;
f0100b85:	8b 1d 38 42 1c f0    	mov    0xf01c4238,%ebx
                      nextfree += ROUNDUP(n, PGSIZE);
f0100b8b:	05 ff 0f 00 00       	add    $0xfff,%eax
f0100b90:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100b95:	01 d8                	add    %ebx,%eax
f0100b97:	a3 38 42 1c f0       	mov    %eax,0xf01c4238
f0100b9c:	eb 0e                	jmp    f0100bac <boot_alloc+0x4c>
               } else if (n == 0)
                      result = nextfree;
f0100b9e:	8b 1d 38 42 1c f0    	mov    0xf01c4238,%ebx
f0100ba4:	eb 06                	jmp    f0100bac <boot_alloc+0x4c>
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f0100ba6:	85 c0                	test   %eax,%eax
f0100ba8:	74 f4                	je     f0100b9e <boot_alloc+0x3e>
f0100baa:	eb d9                	jmp    f0100b85 <boot_alloc+0x25>
                      nextfree += ROUNDUP(n, PGSIZE);
               } else if (n == 0)
                      result = nextfree;
              else
                      result = NULL;
              cprintf(">>  boot_alloc() was called! Entry(virtual address) of new page is: %x\n\n", (int)result);
f0100bac:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100bb0:	c7 04 24 84 72 10 f0 	movl   $0xf0107284,(%esp)
f0100bb7:	e8 d6 32 00 00       	call   f0103e92 <cprintf>
              return result;
   
	//return NULL;
}
f0100bbc:	89 d8                	mov    %ebx,%eax
f0100bbe:	83 c4 14             	add    $0x14,%esp
f0100bc1:	5b                   	pop    %ebx
f0100bc2:	5d                   	pop    %ebp
f0100bc3:	c3                   	ret    

f0100bc4 <check_va2pa>:
static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
f0100bc4:	89 d1                	mov    %edx,%ecx
f0100bc6:	c1 e9 16             	shr    $0x16,%ecx
	if (!(*pgdir & PTE_P))
f0100bc9:	8b 04 88             	mov    (%eax,%ecx,4),%eax
f0100bcc:	a8 01                	test   $0x1,%al
f0100bce:	74 5d                	je     f0100c2d <check_va2pa+0x69>
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
f0100bd0:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100bd5:	89 c1                	mov    %eax,%ecx
f0100bd7:	c1 e9 0c             	shr    $0xc,%ecx
f0100bda:	3b 0d 88 4e 1c f0    	cmp    0xf01c4e88,%ecx
f0100be0:	72 26                	jb     f0100c08 <check_va2pa+0x44>
// this functionality for us!  We define our own version to help check
// the check_kern_pgdir() function; it shouldn't be used elsewhere.

static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
f0100be2:	55                   	push   %ebp
f0100be3:	89 e5                	mov    %esp,%ebp
f0100be5:	83 ec 18             	sub    $0x18,%esp
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100be8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100bec:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0100bf3:	f0 
f0100bf4:	c7 44 24 04 9f 03 00 	movl   $0x39f,0x4(%esp)
f0100bfb:	00 
f0100bfc:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0100c03:	e8 38 f4 ff ff       	call   f0100040 <_panic>

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
f0100c08:	c1 ea 0c             	shr    $0xc,%edx
f0100c0b:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f0100c11:	8b 84 90 00 00 00 f0 	mov    -0x10000000(%eax,%edx,4),%eax
f0100c18:	89 c2                	mov    %eax,%edx
f0100c1a:	83 e2 01             	and    $0x1,%edx
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
f0100c1d:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100c22:	85 d2                	test   %edx,%edx
f0100c24:	ba ff ff ff ff       	mov    $0xffffffff,%edx
f0100c29:	0f 44 c2             	cmove  %edx,%eax
f0100c2c:	c3                   	ret    
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
f0100c2d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
}
f0100c32:	c3                   	ret    

f0100c33 <check_page_free_list>:
//
// Check that the pages on the page_free_list are reasonable.
//
static void
check_page_free_list(bool only_low_memory)
{
f0100c33:	55                   	push   %ebp
f0100c34:	89 e5                	mov    %esp,%ebp
f0100c36:	57                   	push   %edi
f0100c37:	56                   	push   %esi
f0100c38:	53                   	push   %ebx
f0100c39:	83 ec 4c             	sub    $0x4c,%esp
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100c3c:	85 c0                	test   %eax,%eax
f0100c3e:	0f 85 6a 03 00 00    	jne    f0100fae <check_page_free_list+0x37b>
f0100c44:	e9 77 03 00 00       	jmp    f0100fc0 <check_page_free_list+0x38d>
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
		panic("'page_free_list' is a null pointer!");
f0100c49:	c7 44 24 08 d0 72 10 	movl   $0xf01072d0,0x8(%esp)
f0100c50:	f0 
f0100c51:	c7 44 24 04 d1 02 00 	movl   $0x2d1,0x4(%esp)
f0100c58:	00 
f0100c59:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0100c60:	e8 db f3 ff ff       	call   f0100040 <_panic>

	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
f0100c65:	8d 55 d8             	lea    -0x28(%ebp),%edx
f0100c68:	89 55 e0             	mov    %edx,-0x20(%ebp)
f0100c6b:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100c6e:	89 55 e4             	mov    %edx,-0x1c(%ebp)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100c71:	89 c2                	mov    %eax,%edx
f0100c73:	2b 15 90 4e 1c f0    	sub    0xf01c4e90,%edx
		for (pp = page_free_list; pp; pp = pp->pp_link) {
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
f0100c79:	f7 c2 00 e0 7f 00    	test   $0x7fe000,%edx
f0100c7f:	0f 95 c2             	setne  %dl
f0100c82:	0f b6 d2             	movzbl %dl,%edx
			*tp[pagetype] = pp;
f0100c85:	8b 4c 95 e0          	mov    -0x20(%ebp,%edx,4),%ecx
f0100c89:	89 01                	mov    %eax,(%ecx)
			tp[pagetype] = &pp->pp_link;
f0100c8b:	89 44 95 e0          	mov    %eax,-0x20(%ebp,%edx,4)
	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
		for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100c8f:	8b 00                	mov    (%eax),%eax
f0100c91:	85 c0                	test   %eax,%eax
f0100c93:	75 dc                	jne    f0100c71 <check_page_free_list+0x3e>
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
			*tp[pagetype] = pp;
			tp[pagetype] = &pp->pp_link;
		}
		*tp[1] = 0;
f0100c95:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100c98:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		*tp[0] = pp2;
f0100c9e:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100ca1:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100ca4:	89 10                	mov    %edx,(%eax)
		page_free_list = pp1;
f0100ca6:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100ca9:	a3 40 42 1c f0       	mov    %eax,0xf01c4240
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100cae:	89 c3                	mov    %eax,%ebx
f0100cb0:	85 c0                	test   %eax,%eax
f0100cb2:	74 6c                	je     f0100d20 <check_page_free_list+0xed>
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100cb4:	be 01 00 00 00       	mov    $0x1,%esi
f0100cb9:	89 d8                	mov    %ebx,%eax
f0100cbb:	2b 05 90 4e 1c f0    	sub    0xf01c4e90,%eax
f0100cc1:	c1 f8 03             	sar    $0x3,%eax
f0100cc4:	c1 e0 0c             	shl    $0xc,%eax
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
f0100cc7:	89 c2                	mov    %eax,%edx
f0100cc9:	c1 ea 16             	shr    $0x16,%edx
f0100ccc:	39 f2                	cmp    %esi,%edx
f0100cce:	73 4a                	jae    f0100d1a <check_page_free_list+0xe7>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100cd0:	89 c2                	mov    %eax,%edx
f0100cd2:	c1 ea 0c             	shr    $0xc,%edx
f0100cd5:	3b 15 88 4e 1c f0    	cmp    0xf01c4e88,%edx
f0100cdb:	72 20                	jb     f0100cfd <check_page_free_list+0xca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100cdd:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100ce1:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0100ce8:	f0 
f0100ce9:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100cf0:	00 
f0100cf1:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f0100cf8:	e8 43 f3 ff ff       	call   f0100040 <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100cfd:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100d04:	00 
f0100d05:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100d0c:	00 
	return (void *)(pa + KERNBASE);
f0100d0d:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100d12:	89 04 24             	mov    %eax,(%esp)
f0100d15:	e8 ef 51 00 00       	call   f0105f09 <memset>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100d1a:	8b 1b                	mov    (%ebx),%ebx
f0100d1c:	85 db                	test   %ebx,%ebx
f0100d1e:	75 99                	jne    f0100cb9 <check_page_free_list+0x86>
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
f0100d20:	b8 00 00 00 00       	mov    $0x0,%eax
f0100d25:	e8 36 fe ff ff       	call   f0100b60 <boot_alloc>
f0100d2a:	89 45 c8             	mov    %eax,-0x38(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100d2d:	8b 15 40 42 1c f0    	mov    0xf01c4240,%edx
f0100d33:	85 d2                	test   %edx,%edx
f0100d35:	0f 84 27 02 00 00    	je     f0100f62 <check_page_free_list+0x32f>
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d3b:	8b 3d 90 4e 1c f0    	mov    0xf01c4e90,%edi
f0100d41:	39 fa                	cmp    %edi,%edx
f0100d43:	72 3f                	jb     f0100d84 <check_page_free_list+0x151>
		assert(pp < pages + npages);
f0100d45:	a1 88 4e 1c f0       	mov    0xf01c4e88,%eax
f0100d4a:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0100d4d:	8d 04 c7             	lea    (%edi,%eax,8),%eax
f0100d50:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100d53:	39 c2                	cmp    %eax,%edx
f0100d55:	73 56                	jae    f0100dad <check_page_free_list+0x17a>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100d57:	89 7d d0             	mov    %edi,-0x30(%ebp)
f0100d5a:	89 d0                	mov    %edx,%eax
f0100d5c:	29 f8                	sub    %edi,%eax
f0100d5e:	a8 07                	test   $0x7,%al
f0100d60:	75 78                	jne    f0100dda <check_page_free_list+0x1a7>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100d62:	c1 f8 03             	sar    $0x3,%eax
f0100d65:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100d68:	85 c0                	test   %eax,%eax
f0100d6a:	0f 84 98 00 00 00    	je     f0100e08 <check_page_free_list+0x1d5>
		assert(page2pa(pp) != IOPHYSMEM);
f0100d70:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100d75:	0f 85 dc 00 00 00    	jne    f0100e57 <check_page_free_list+0x224>
f0100d7b:	e9 b3 00 00 00       	jmp    f0100e33 <check_page_free_list+0x200>
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d80:	39 d7                	cmp    %edx,%edi
f0100d82:	76 24                	jbe    f0100da8 <check_page_free_list+0x175>
f0100d84:	c7 44 24 0c e7 79 10 	movl   $0xf01079e7,0xc(%esp)
f0100d8b:	f0 
f0100d8c:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0100d93:	f0 
f0100d94:	c7 44 24 04 eb 02 00 	movl   $0x2eb,0x4(%esp)
f0100d9b:	00 
f0100d9c:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0100da3:	e8 98 f2 ff ff       	call   f0100040 <_panic>
		assert(pp < pages + npages);
f0100da8:	3b 55 d4             	cmp    -0x2c(%ebp),%edx
f0100dab:	72 24                	jb     f0100dd1 <check_page_free_list+0x19e>
f0100dad:	c7 44 24 0c 08 7a 10 	movl   $0xf0107a08,0xc(%esp)
f0100db4:	f0 
f0100db5:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0100dbc:	f0 
f0100dbd:	c7 44 24 04 ec 02 00 	movl   $0x2ec,0x4(%esp)
f0100dc4:	00 
f0100dc5:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0100dcc:	e8 6f f2 ff ff       	call   f0100040 <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100dd1:	89 d0                	mov    %edx,%eax
f0100dd3:	2b 45 d0             	sub    -0x30(%ebp),%eax
f0100dd6:	a8 07                	test   $0x7,%al
f0100dd8:	74 24                	je     f0100dfe <check_page_free_list+0x1cb>
f0100dda:	c7 44 24 0c f4 72 10 	movl   $0xf01072f4,0xc(%esp)
f0100de1:	f0 
f0100de2:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0100de9:	f0 
f0100dea:	c7 44 24 04 ed 02 00 	movl   $0x2ed,0x4(%esp)
f0100df1:	00 
f0100df2:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0100df9:	e8 42 f2 ff ff       	call   f0100040 <_panic>
f0100dfe:	c1 f8 03             	sar    $0x3,%eax
f0100e01:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100e04:	85 c0                	test   %eax,%eax
f0100e06:	75 24                	jne    f0100e2c <check_page_free_list+0x1f9>
f0100e08:	c7 44 24 0c 1c 7a 10 	movl   $0xf0107a1c,0xc(%esp)
f0100e0f:	f0 
f0100e10:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0100e17:	f0 
f0100e18:	c7 44 24 04 f0 02 00 	movl   $0x2f0,0x4(%esp)
f0100e1f:	00 
f0100e20:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0100e27:	e8 14 f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100e2c:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100e31:	75 31                	jne    f0100e64 <check_page_free_list+0x231>
f0100e33:	c7 44 24 0c 2d 7a 10 	movl   $0xf0107a2d,0xc(%esp)
f0100e3a:	f0 
f0100e3b:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0100e42:	f0 
f0100e43:	c7 44 24 04 f1 02 00 	movl   $0x2f1,0x4(%esp)
f0100e4a:	00 
f0100e4b:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0100e52:	e8 e9 f1 ff ff       	call   f0100040 <_panic>
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
f0100e57:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100e5c:	be 00 00 00 00       	mov    $0x0,%esi
f0100e61:	89 5d cc             	mov    %ebx,-0x34(%ebp)
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
f0100e64:	3d 00 f0 0f 00       	cmp    $0xff000,%eax
f0100e69:	75 24                	jne    f0100e8f <check_page_free_list+0x25c>
f0100e6b:	c7 44 24 0c 28 73 10 	movl   $0xf0107328,0xc(%esp)
f0100e72:	f0 
f0100e73:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0100e7a:	f0 
f0100e7b:	c7 44 24 04 f2 02 00 	movl   $0x2f2,0x4(%esp)
f0100e82:	00 
f0100e83:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0100e8a:	e8 b1 f1 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100e8f:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100e94:	75 24                	jne    f0100eba <check_page_free_list+0x287>
f0100e96:	c7 44 24 0c 46 7a 10 	movl   $0xf0107a46,0xc(%esp)
f0100e9d:	f0 
f0100e9e:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0100ea5:	f0 
f0100ea6:	c7 44 24 04 f3 02 00 	movl   $0x2f3,0x4(%esp)
f0100ead:	00 
f0100eae:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0100eb5:	e8 86 f1 ff ff       	call   f0100040 <_panic>
f0100eba:	89 c1                	mov    %eax,%ecx
		//assert((char *) page2kva(pp) >= first_free_page );
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
f0100ebc:	3d ff ff 0f 00       	cmp    $0xfffff,%eax
f0100ec1:	0f 86 07 01 00 00    	jbe    f0100fce <check_page_free_list+0x39b>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100ec7:	89 c3                	mov    %eax,%ebx
f0100ec9:	c1 eb 0c             	shr    $0xc,%ebx
f0100ecc:	39 5d c4             	cmp    %ebx,-0x3c(%ebp)
f0100ecf:	77 20                	ja     f0100ef1 <check_page_free_list+0x2be>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100ed1:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100ed5:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0100edc:	f0 
f0100edd:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100ee4:	00 
f0100ee5:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f0100eec:	e8 4f f1 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0100ef1:	81 e9 00 00 00 10    	sub    $0x10000000,%ecx
f0100ef7:	39 4d c8             	cmp    %ecx,-0x38(%ebp)
f0100efa:	0f 86 de 00 00 00    	jbe    f0100fde <check_page_free_list+0x3ab>
f0100f00:	c7 44 24 0c 4c 73 10 	movl   $0xf010734c,0xc(%esp)
f0100f07:	f0 
f0100f08:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0100f0f:	f0 
f0100f10:	c7 44 24 04 f5 02 00 	movl   $0x2f5,0x4(%esp)
f0100f17:	00 
f0100f18:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0100f1f:	e8 1c f1 ff ff       	call   f0100040 <_panic>
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100f24:	c7 44 24 0c 60 7a 10 	movl   $0xf0107a60,0xc(%esp)
f0100f2b:	f0 
f0100f2c:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0100f33:	f0 
f0100f34:	c7 44 24 04 f7 02 00 	movl   $0x2f7,0x4(%esp)
f0100f3b:	00 
f0100f3c:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0100f43:	e8 f8 f0 ff ff       	call   f0100040 <_panic>

		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
f0100f48:	83 c6 01             	add    $0x1,%esi
f0100f4b:	eb 04                	jmp    f0100f51 <check_page_free_list+0x31e>
		else
			++nfree_extmem;
f0100f4d:	83 45 cc 01          	addl   $0x1,-0x34(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100f51:	8b 12                	mov    (%edx),%edx
f0100f53:	85 d2                	test   %edx,%edx
f0100f55:	0f 85 25 fe ff ff    	jne    f0100d80 <check_page_free_list+0x14d>
f0100f5b:	8b 5d cc             	mov    -0x34(%ebp),%ebx
		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
		else
			++nfree_extmem;
	}
	assert(nfree_basemem > 0);
f0100f5e:	85 f6                	test   %esi,%esi
f0100f60:	7f 24                	jg     f0100f86 <check_page_free_list+0x353>
f0100f62:	c7 44 24 0c 7d 7a 10 	movl   $0xf0107a7d,0xc(%esp)
f0100f69:	f0 
f0100f6a:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0100f71:	f0 
f0100f72:	c7 44 24 04 fe 02 00 	movl   $0x2fe,0x4(%esp)
f0100f79:	00 
f0100f7a:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0100f81:	e8 ba f0 ff ff       	call   f0100040 <_panic>
	assert(nfree_extmem > 0);
f0100f86:	85 db                	test   %ebx,%ebx
f0100f88:	7f 74                	jg     f0100ffe <check_page_free_list+0x3cb>
f0100f8a:	c7 44 24 0c 8f 7a 10 	movl   $0xf0107a8f,0xc(%esp)
f0100f91:	f0 
f0100f92:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0100f99:	f0 
f0100f9a:	c7 44 24 04 ff 02 00 	movl   $0x2ff,0x4(%esp)
f0100fa1:	00 
f0100fa2:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0100fa9:	e8 92 f0 ff ff       	call   f0100040 <_panic>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100fae:	a1 40 42 1c f0       	mov    0xf01c4240,%eax
f0100fb3:	85 c0                	test   %eax,%eax
f0100fb5:	0f 85 aa fc ff ff    	jne    f0100c65 <check_page_free_list+0x32>
f0100fbb:	e9 89 fc ff ff       	jmp    f0100c49 <check_page_free_list+0x16>
f0100fc0:	83 3d 40 42 1c f0 00 	cmpl   $0x0,0xf01c4240
f0100fc7:	75 25                	jne    f0100fee <check_page_free_list+0x3bb>
f0100fc9:	e9 7b fc ff ff       	jmp    f0100c49 <check_page_free_list+0x16>
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
		assert(page2pa(pp) != EXTPHYSMEM);
		//assert((char *) page2kva(pp) >= first_free_page );
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100fce:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100fd3:	0f 85 6f ff ff ff    	jne    f0100f48 <check_page_free_list+0x315>
f0100fd9:	e9 46 ff ff ff       	jmp    f0100f24 <check_page_free_list+0x2f1>
f0100fde:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100fe3:	0f 85 64 ff ff ff    	jne    f0100f4d <check_page_free_list+0x31a>
f0100fe9:	e9 36 ff ff ff       	jmp    f0100f24 <check_page_free_list+0x2f1>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100fee:	8b 1d 40 42 1c f0    	mov    0xf01c4240,%ebx
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100ff4:	be 00 04 00 00       	mov    $0x400,%esi
f0100ff9:	e9 bb fc ff ff       	jmp    f0100cb9 <check_page_free_list+0x86>
		else
			++nfree_extmem;
	}
	assert(nfree_basemem > 0);
	assert(nfree_extmem > 0);
}
f0100ffe:	83 c4 4c             	add    $0x4c,%esp
f0101001:	5b                   	pop    %ebx
f0101002:	5e                   	pop    %esi
f0101003:	5f                   	pop    %edi
f0101004:	5d                   	pop    %ebp
f0101005:	c3                   	ret    

f0101006 <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0101006:	55                   	push   %ebp
f0101007:	89 e5                	mov    %esp,%ebp
f0101009:	56                   	push   %esi
f010100a:	53                   	push   %ebx
f010100b:	83 ec 10             	sub    $0x10,%esp
	size_t i = 1;
	for (i; i < npages_basemem; i++) {
f010100e:	8b 35 44 42 1c f0    	mov    0xf01c4244,%esi
f0101014:	83 fe 01             	cmp    $0x1,%esi
f0101017:	76 39                	jbe    f0101052 <page_init+0x4c>
f0101019:	8b 1d 40 42 1c f0    	mov    0xf01c4240,%ebx
// memory via the page_free_list.
//
void
page_init(void)
{
	size_t i = 1;
f010101f:	b8 01 00 00 00       	mov    $0x1,%eax
f0101024:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
	for (i; i < npages_basemem; i++) {
		pages[i].pp_ref = 0;
f010102b:	89 d1                	mov    %edx,%ecx
f010102d:	03 0d 90 4e 1c f0    	add    0xf01c4e90,%ecx
f0101033:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0101039:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f010103b:	03 15 90 4e 1c f0    	add    0xf01c4e90,%edx
//
void
page_init(void)
{
	size_t i = 1;
	for (i; i < npages_basemem; i++) {
f0101041:	83 c0 01             	add    $0x1,%eax
f0101044:	39 f0                	cmp    %esi,%eax
f0101046:	73 04                	jae    f010104c <page_init+0x46>
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f0101048:	89 d3                	mov    %edx,%ebx
f010104a:	eb d8                	jmp    f0101024 <page_init+0x1e>
f010104c:	89 15 40 42 1c f0    	mov    %edx,0xf01c4240
	}

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
f0101052:	8b 0d 88 4e 1c f0    	mov    0xf01c4e88,%ecx
f0101058:	a1 90 4e 1c f0       	mov    0xf01c4e90,%eax
f010105d:	8d 84 c8 ff ff 01 10 	lea    0x1001ffff(%eax,%ecx,8),%eax
f0101064:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0101069:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f010106f:	85 c0                	test   %eax,%eax
f0101071:	0f 48 c2             	cmovs  %edx,%eax
f0101074:	c1 f8 0c             	sar    $0xc,%eax
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f0101077:	89 c2                	mov    %eax,%edx
f0101079:	39 c1                	cmp    %eax,%ecx
f010107b:	76 37                	jbe    f01010b4 <page_init+0xae>
f010107d:	8b 1d 40 42 1c f0    	mov    0xf01c4240,%ebx
f0101083:	c1 e0 03             	shl    $0x3,%eax
		pages[i].pp_ref = 0;
f0101086:	89 c1                	mov    %eax,%ecx
f0101088:	03 0d 90 4e 1c f0    	add    0xf01c4e90,%ecx
f010108e:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0101094:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f0101096:	89 c3                	mov    %eax,%ebx
f0101098:	03 1d 90 4e 1c f0    	add    0xf01c4e90,%ebx

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f010109e:	83 c2 01             	add    $0x1,%edx
f01010a1:	8b 0d 88 4e 1c f0    	mov    0xf01c4e88,%ecx
f01010a7:	83 c0 08             	add    $0x8,%eax
f01010aa:	39 d1                	cmp    %edx,%ecx
f01010ac:	77 d8                	ja     f0101086 <page_init+0x80>
f01010ae:	89 1d 40 42 1c f0    	mov    %ebx,0xf01c4240
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01010b4:	83 f9 07             	cmp    $0x7,%ecx
f01010b7:	77 1c                	ja     f01010d5 <page_init+0xcf>
		panic("pa2page called with invalid pa");
f01010b9:	c7 44 24 08 94 73 10 	movl   $0xf0107394,0x8(%esp)
f01010c0:	f0 
f01010c1:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01010c8:	00 
f01010c9:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f01010d0:	e8 6b ef ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f01010d5:	8b 15 90 4e 1c f0    	mov    0xf01c4e90,%edx
               ppg_end->pp_link = ppg_start;*/

               //remain the page of mp entry Code
               extern unsigned char mpentry_start[], mpentry_end[];
               struct Page *ppg_start = pa2page((physaddr_t)MPENTRY_PADDR);      
               struct Page * ppg_end = pa2page((physaddr_t)(MPENTRY_PADDR+mpentry_end - mpentry_start));  
f01010db:	b8 b6 d1 10 f0       	mov    $0xf010d1b6,%eax
f01010e0:	2d 3c 61 10 f0       	sub    $0xf010613c,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01010e5:	c1 e8 0c             	shr    $0xc,%eax
f01010e8:	39 c8                	cmp    %ecx,%eax
f01010ea:	72 1c                	jb     f0101108 <page_init+0x102>
		panic("pa2page called with invalid pa");
f01010ec:	c7 44 24 08 94 73 10 	movl   $0xf0107394,0x8(%esp)
f01010f3:	f0 
f01010f4:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01010fb:	00 
f01010fc:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f0101103:	e8 38 ef ff ff       	call   f0100040 <_panic>
               ppg_start--;    ppg_end++;
f0101108:	8d 4a 30             	lea    0x30(%edx),%ecx
f010110b:	89 4c c2 08          	mov    %ecx,0x8(%edx,%eax,8)
               ppg_end->pp_link = ppg_start;

              // cprintf("MPENTRY_PADDR_page_start:  %d\n",PGNUM(page2pa(ppg_start)));
               //cprintf("MPENTRY_PADDR_page_end:  %d\n",PGNUM(page2pa(ppg_end)));
               //cprintf("\n");
}
f010110f:	83 c4 10             	add    $0x10,%esp
f0101112:	5b                   	pop    %ebx
f0101113:	5e                   	pop    %esi
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
f010111d:	8b 1d 40 42 1c f0    	mov    0xf01c4240,%ebx
f0101123:	85 db                	test   %ebx,%ebx
f0101125:	74 69                	je     f0101190 <page_alloc+0x7a>
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
f0101127:	8b 03                	mov    (%ebx),%eax
f0101129:	a3 40 42 1c f0       	mov    %eax,0xf01c4240
    
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
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101136:	2b 05 90 4e 1c f0    	sub    0xf01c4e90,%eax
f010113c:	c1 f8 03             	sar    $0x3,%eax
f010113f:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101142:	89 c2                	mov    %eax,%edx
f0101144:	c1 ea 0c             	shr    $0xc,%edx
f0101147:	3b 15 88 4e 1c f0    	cmp    0xf01c4e88,%edx
f010114d:	72 20                	jb     f010116f <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010114f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101153:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f010115a:	f0 
f010115b:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101162:	00 
f0101163:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f010116a:	e8 d1 ee ff ff       	call   f0100040 <_panic>
                    memset(page2kva(result), 0, PGSIZE);
f010116f:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101176:	00 
f0101177:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010117e:	00 
	return (void *)(pa + KERNBASE);
f010117f:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101184:	89 04 24             	mov    %eax,(%esp)
f0101187:	e8 7d 4d 00 00       	call   f0105f09 <memset>
        
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
f01011a1:	8b 15 40 42 1c f0    	mov    0xf01c4240,%edx
f01011a7:	89 10                	mov    %edx,(%eax)
              page_free_list = pp;
f01011a9:	a3 40 42 1c f0       	mov    %eax,0xf01c4240
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
f0101214:	2b 15 90 4e 1c f0    	sub    0xf01c4e90,%edx
f010121a:	c1 fa 03             	sar    $0x3,%edx
f010121d:	c1 e2 0c             	shl    $0xc,%edx
                                                  pgdir[PDX(va)] = page2pa(tmp) | PTE_P | PTE_W |PTE_U;    //save the physical address of newly allocated page in page dir
f0101220:	83 ca 07             	or     $0x7,%edx
f0101223:	89 16                	mov    %edx,(%esi)
f0101225:	2b 05 90 4e 1c f0    	sub    0xf01c4e90,%eax
f010122b:	c1 f8 03             	sar    $0x3,%eax
f010122e:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101231:	89 c2                	mov    %eax,%edx
f0101233:	c1 ea 0c             	shr    $0xc,%edx
f0101236:	3b 15 88 4e 1c f0    	cmp    0xf01c4e88,%edx
f010123c:	72 20                	jb     f010125e <pgdir_walk+0x8b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010123e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101242:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0101249:	f0 
f010124a:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101251:	00 
f0101252:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
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
f0101268:	8b 15 88 4e 1c f0    	mov    0xf01c4e88,%edx
f010126e:	39 d0                	cmp    %edx,%eax
f0101270:	72 1c                	jb     f010128e <pgdir_walk+0xbb>
		panic("pa2page called with invalid pa");
f0101272:	c7 44 24 08 94 73 10 	movl   $0xf0107394,0x8(%esp)
f0101279:	f0 
f010127a:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101281:	00 
f0101282:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
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
f010129b:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f01012a2:	f0 
f01012a3:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01012aa:	00 
f01012ab:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
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

f01012dd <boot_map_region>:
// mapped pages.
//
// Hint: the TA solution uses pgdir_walk
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
f01012dd:	55                   	push   %ebp
f01012de:	89 e5                	mov    %esp,%ebp
f01012e0:	57                   	push   %edi
f01012e1:	56                   	push   %esi
f01012e2:	53                   	push   %ebx
f01012e3:	83 ec 2c             	sub    $0x2c,%esp
	size_t i = 0;
	pte_t * pgEntry;
	for(i;i<(size/PGSIZE);i++){
f01012e6:	c1 e9 0c             	shr    $0xc,%ecx
f01012e9:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
f01012ec:	85 c9                	test   %ecx,%ecx
f01012ee:	74 6d                	je     f010135d <boot_map_region+0x80>
f01012f0:	89 c7                	mov    %eax,%edi
f01012f2:	89 d3                	mov    %edx,%ebx
//
// Hint: the TA solution uses pgdir_walk
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	size_t i = 0;
f01012f4:	be 00 00 00 00       	mov    $0x0,%esi
	for(i;i<(size/PGSIZE);i++){
		pgEntry = pgdir_walk(pgdir,(void*)(va+i*PGSIZE),1);
		if(pgEntry==NULL){
			panic("kern page not allocated!\n");
		}
		(*pgEntry) = PTE_ADDR(pa + PGSIZE * i) | perm | PTE_P;
f01012f9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01012fc:	83 c8 01             	or     $0x1,%eax
f01012ff:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0101302:	8b 45 08             	mov    0x8(%ebp),%eax
f0101305:	29 d0                	sub    %edx,%eax
f0101307:	89 45 dc             	mov    %eax,-0x24(%ebp)
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	size_t i = 0;
	pte_t * pgEntry;
	for(i;i<(size/PGSIZE);i++){
		pgEntry = pgdir_walk(pgdir,(void*)(va+i*PGSIZE),1);
f010130a:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0101311:	00 
f0101312:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101316:	89 3c 24             	mov    %edi,(%esp)
f0101319:	e8 b5 fe ff ff       	call   f01011d3 <pgdir_walk>
		if(pgEntry==NULL){
f010131e:	85 c0                	test   %eax,%eax
f0101320:	75 1c                	jne    f010133e <boot_map_region+0x61>
			panic("kern page not allocated!\n");
f0101322:	c7 44 24 08 a0 7a 10 	movl   $0xf0107aa0,0x8(%esp)
f0101329:	f0 
f010132a:	c7 44 24 04 f3 01 00 	movl   $0x1f3,0x4(%esp)
f0101331:	00 
f0101332:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101339:	e8 02 ed ff ff       	call   f0100040 <_panic>
f010133e:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0101341:	8d 14 19             	lea    (%ecx,%ebx,1),%edx
		}
		(*pgEntry) = PTE_ADDR(pa + PGSIZE * i) | perm | PTE_P;
f0101344:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f010134a:	0b 55 e0             	or     -0x20(%ebp),%edx
f010134d:	89 10                	mov    %edx,(%eax)
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	size_t i = 0;
	pte_t * pgEntry;
	for(i;i<(size/PGSIZE);i++){
f010134f:	83 c6 01             	add    $0x1,%esi
f0101352:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0101358:	3b 75 e4             	cmp    -0x1c(%ebp),%esi
f010135b:	75 ad                	jne    f010130a <boot_map_region+0x2d>
			panic("kern page not allocated!\n");
		}
		(*pgEntry) = PTE_ADDR(pa + PGSIZE * i) | perm | PTE_P;
	}
	// Fill this function in
}
f010135d:	83 c4 2c             	add    $0x2c,%esp
f0101360:	5b                   	pop    %ebx
f0101361:	5e                   	pop    %esi
f0101362:	5f                   	pop    %edi
f0101363:	5d                   	pop    %ebp
f0101364:	c3                   	ret    

f0101365 <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f0101365:	55                   	push   %ebp
f0101366:	89 e5                	mov    %esp,%ebp
f0101368:	53                   	push   %ebx
f0101369:	83 ec 14             	sub    $0x14,%esp
f010136c:	8b 5d 10             	mov    0x10(%ebp),%ebx
	// Fill this function in
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
f010136f:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101376:	00 
f0101377:	8b 45 0c             	mov    0xc(%ebp),%eax
f010137a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010137e:	8b 45 08             	mov    0x8(%ebp),%eax
f0101381:	89 04 24             	mov    %eax,(%esp)
f0101384:	e8 4a fe ff ff       	call   f01011d3 <pgdir_walk>
              if (pte == NULL)
f0101389:	85 c0                	test   %eax,%eax
f010138b:	74 3a                	je     f01013c7 <page_lookup+0x62>
                       return NULL;

             if (pte_store != 0)
f010138d:	85 db                	test   %ebx,%ebx
f010138f:	74 02                	je     f0101393 <page_lookup+0x2e>
                     *pte_store = pte;
f0101391:	89 03                	mov    %eax,(%ebx)

             return pa2page(PTE_ADDR(pte[0]));
f0101393:	8b 00                	mov    (%eax),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101395:	c1 e8 0c             	shr    $0xc,%eax
f0101398:	3b 05 88 4e 1c f0    	cmp    0xf01c4e88,%eax
f010139e:	72 1c                	jb     f01013bc <page_lookup+0x57>
		panic("pa2page called with invalid pa");
f01013a0:	c7 44 24 08 94 73 10 	movl   $0xf0107394,0x8(%esp)
f01013a7:	f0 
f01013a8:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01013af:	00 
f01013b0:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f01013b7:	e8 84 ec ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f01013bc:	8b 15 90 4e 1c f0    	mov    0xf01c4e90,%edx
f01013c2:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01013c5:	eb 05                	jmp    f01013cc <page_lookup+0x67>
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
              if (pte == NULL)
                       return NULL;
f01013c7:	b8 00 00 00 00       	mov    $0x0,%eax

             if (pte_store != 0)
                     *pte_store = pte;

             return pa2page(PTE_ADDR(pte[0]));
}
f01013cc:	83 c4 14             	add    $0x14,%esp
f01013cf:	5b                   	pop    %ebx
f01013d0:	5d                   	pop    %ebp
f01013d1:	c3                   	ret    

f01013d2 <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f01013d2:	55                   	push   %ebp
f01013d3:	89 e5                	mov    %esp,%ebp
f01013d5:	83 ec 08             	sub    $0x8,%esp
	// Flush the entry only if we're modifying the current address space.
	if (!curenv || curenv->env_pgdir == pgdir)
f01013d8:	e8 c6 51 00 00       	call   f01065a3 <cpunum>
f01013dd:	6b c0 74             	imul   $0x74,%eax,%eax
f01013e0:	83 b8 28 50 1c f0 00 	cmpl   $0x0,-0xfe3afd8(%eax)
f01013e7:	74 16                	je     f01013ff <tlb_invalidate+0x2d>
f01013e9:	e8 b5 51 00 00       	call   f01065a3 <cpunum>
f01013ee:	6b c0 74             	imul   $0x74,%eax,%eax
f01013f1:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f01013f7:	8b 55 08             	mov    0x8(%ebp),%edx
f01013fa:	39 50 60             	cmp    %edx,0x60(%eax)
f01013fd:	75 06                	jne    f0101405 <tlb_invalidate+0x33>
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f01013ff:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101402:	0f 01 38             	invlpg (%eax)
		invlpg(va);
}
f0101405:	c9                   	leave  
f0101406:	c3                   	ret    

f0101407 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f0101407:	55                   	push   %ebp
f0101408:	89 e5                	mov    %esp,%ebp
f010140a:	56                   	push   %esi
f010140b:	53                   	push   %ebx
f010140c:	83 ec 20             	sub    $0x20,%esp
f010140f:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0101412:	8b 75 0c             	mov    0xc(%ebp),%esi
	// Fill this function in
	//test output
               //cprintf(">>  page_remove() was called!\n");
    
              pte_t *pte;
              struct Page *page = page_lookup(pgdir, va, &pte);
f0101415:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0101418:	89 44 24 08          	mov    %eax,0x8(%esp)
f010141c:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101420:	89 1c 24             	mov    %ebx,(%esp)
f0101423:	e8 3d ff ff ff       	call   f0101365 <page_lookup>
    
              if (page != NULL)
f0101428:	85 c0                	test   %eax,%eax
f010142a:	74 08                	je     f0101434 <page_remove+0x2d>
                         page_decref(page);
f010142c:	89 04 24             	mov    %eax,(%esp)
f010142f:	e8 7c fd ff ff       	call   f01011b0 <page_decref>
        
              pte[0] = 0;
f0101434:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101437:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
              tlb_invalidate(pgdir, va);
f010143d:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101441:	89 1c 24             	mov    %ebx,(%esp)
f0101444:	e8 89 ff ff ff       	call   f01013d2 <tlb_invalidate>
}
f0101449:	83 c4 20             	add    $0x20,%esp
f010144c:	5b                   	pop    %ebx
f010144d:	5e                   	pop    %esi
f010144e:	5d                   	pop    %ebp
f010144f:	c3                   	ret    

f0101450 <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
{
f0101450:	55                   	push   %ebp
f0101451:	89 e5                	mov    %esp,%ebp
f0101453:	57                   	push   %edi
f0101454:	56                   	push   %esi
f0101455:	53                   	push   %ebx
f0101456:	83 ec 1c             	sub    $0x1c,%esp
f0101459:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010145c:	8b 75 10             	mov    0x10(%ebp),%esi
	// Fill this function in
	//test output
                                //cprintf(">>  page_insert() was called!\n");
    
               struct Page *page = page_lookup(pgdir, va, NULL);
f010145f:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101466:	00 
f0101467:	89 74 24 04          	mov    %esi,0x4(%esp)
f010146b:	8b 45 08             	mov    0x8(%ebp),%eax
f010146e:	89 04 24             	mov    %eax,(%esp)
f0101471:	e8 ef fe ff ff       	call   f0101365 <page_lookup>
f0101476:	89 c7                	mov    %eax,%edi
               pte_t *pte;
    
              if (page == pp) {                       //re-insert into the same place
f0101478:	39 d8                	cmp    %ebx,%eax
f010147a:	75 36                	jne    f01014b2 <page_insert+0x62>
                            pte = pgdir_walk(pgdir, va, 0);
f010147c:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101483:	00 
f0101484:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101488:	8b 45 08             	mov    0x8(%ebp),%eax
f010148b:	89 04 24             	mov    %eax,(%esp)
f010148e:	e8 40 fd ff ff       	call   f01011d3 <pgdir_walk>
                            pte[0] = page2pa(pp) | perm | PTE_P;
f0101493:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0101496:	83 c9 01             	or     $0x1,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101499:	2b 3d 90 4e 1c f0    	sub    0xf01c4e90,%edi
f010149f:	c1 ff 03             	sar    $0x3,%edi
f01014a2:	c1 e7 0c             	shl    $0xc,%edi
f01014a5:	89 fa                	mov    %edi,%edx
f01014a7:	09 ca                	or     %ecx,%edx
f01014a9:	89 10                	mov    %edx,(%eax)
                            return 0;
f01014ab:	b8 00 00 00 00       	mov    $0x0,%eax
f01014b0:	eb 57                	jmp    f0101509 <page_insert+0xb9>
                          }
    
               if (page != NULL)                       //remove original page if existed
f01014b2:	85 c0                	test   %eax,%eax
f01014b4:	74 0f                	je     f01014c5 <page_insert+0x75>
                        page_remove(pgdir, va);
f01014b6:	89 74 24 04          	mov    %esi,0x4(%esp)
f01014ba:	8b 45 08             	mov    0x8(%ebp),%eax
f01014bd:	89 04 24             	mov    %eax,(%esp)
f01014c0:	e8 42 ff ff ff       	call   f0101407 <page_remove>
        
              pte = pgdir_walk(pgdir, va, 1);
f01014c5:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01014cc:	00 
f01014cd:	89 74 24 04          	mov    %esi,0x4(%esp)
f01014d1:	8b 45 08             	mov    0x8(%ebp),%eax
f01014d4:	89 04 24             	mov    %eax,(%esp)
f01014d7:	e8 f7 fc ff ff       	call   f01011d3 <pgdir_walk>
              if (pte == NULL)
f01014dc:	85 c0                	test   %eax,%eax
f01014de:	74 24                	je     f0101504 <page_insert+0xb4>
                       return -E_NO_MEM;

              pte[0] = page2pa(pp) | perm | PTE_P;
f01014e0:	8b 4d 14             	mov    0x14(%ebp),%ecx
f01014e3:	83 c9 01             	or     $0x1,%ecx
f01014e6:	89 da                	mov    %ebx,%edx
f01014e8:	2b 15 90 4e 1c f0    	sub    0xf01c4e90,%edx
f01014ee:	c1 fa 03             	sar    $0x3,%edx
f01014f1:	c1 e2 0c             	shl    $0xc,%edx
f01014f4:	09 ca                	or     %ecx,%edx
f01014f6:	89 10                	mov    %edx,(%eax)
               pp->pp_ref++;
f01014f8:	66 83 43 04 01       	addw   $0x1,0x4(%ebx)

	return 0; 
f01014fd:	b8 00 00 00 00       	mov    $0x0,%eax
f0101502:	eb 05                	jmp    f0101509 <page_insert+0xb9>
               if (page != NULL)                       //remove original page if existed
                        page_remove(pgdir, va);
        
              pte = pgdir_walk(pgdir, va, 1);
              if (pte == NULL)
                       return -E_NO_MEM;
f0101504:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax

              pte[0] = page2pa(pp) | perm | PTE_P;
               pp->pp_ref++;

	return 0; 
}
f0101509:	83 c4 1c             	add    $0x1c,%esp
f010150c:	5b                   	pop    %ebx
f010150d:	5e                   	pop    %esi
f010150e:	5f                   	pop    %edi
f010150f:	5d                   	pop    %ebp
f0101510:	c3                   	ret    

f0101511 <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f0101511:	55                   	push   %ebp
f0101512:	89 e5                	mov    %esp,%ebp
f0101514:	57                   	push   %edi
f0101515:	56                   	push   %esi
f0101516:	53                   	push   %ebx
f0101517:	83 ec 4c             	sub    $0x4c,%esp
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f010151a:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f0101521:	e8 00 28 00 00       	call   f0103d26 <mc146818_read>
f0101526:	89 c3                	mov    %eax,%ebx
f0101528:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f010152f:	e8 f2 27 00 00       	call   f0103d26 <mc146818_read>
f0101534:	c1 e0 08             	shl    $0x8,%eax
f0101537:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f0101539:	89 d8                	mov    %ebx,%eax
f010153b:	c1 e0 0a             	shl    $0xa,%eax
f010153e:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0101544:	85 c0                	test   %eax,%eax
f0101546:	0f 48 c2             	cmovs  %edx,%eax
f0101549:	c1 f8 0c             	sar    $0xc,%eax
f010154c:	a3 44 42 1c f0       	mov    %eax,0xf01c4244
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0101551:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f0101558:	e8 c9 27 00 00       	call   f0103d26 <mc146818_read>
f010155d:	89 c3                	mov    %eax,%ebx
f010155f:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f0101566:	e8 bb 27 00 00       	call   f0103d26 <mc146818_read>
f010156b:	c1 e0 08             	shl    $0x8,%eax
f010156e:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f0101570:	89 d8                	mov    %ebx,%eax
f0101572:	c1 e0 0a             	shl    $0xa,%eax
f0101575:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f010157b:	85 c0                	test   %eax,%eax
f010157d:	0f 48 c2             	cmovs  %edx,%eax
f0101580:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f0101583:	85 c0                	test   %eax,%eax
f0101585:	74 0e                	je     f0101595 <mem_init+0x84>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f0101587:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f010158d:	89 15 88 4e 1c f0    	mov    %edx,0xf01c4e88
f0101593:	eb 0c                	jmp    f01015a1 <mem_init+0x90>
	else
		npages = npages_basemem;
f0101595:	8b 15 44 42 1c f0    	mov    0xf01c4244,%edx
f010159b:	89 15 88 4e 1c f0    	mov    %edx,0xf01c4e88

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f01015a1:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f01015a4:	c1 e8 0a             	shr    $0xa,%eax
f01015a7:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f01015ab:	a1 44 42 1c f0       	mov    0xf01c4244,%eax
f01015b0:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f01015b3:	c1 e8 0a             	shr    $0xa,%eax
f01015b6:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f01015ba:	a1 88 4e 1c f0       	mov    0xf01c4e88,%eax
f01015bf:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f01015c2:	c1 e8 0a             	shr    $0xa,%eax
f01015c5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01015c9:	c7 04 24 b4 73 10 f0 	movl   $0xf01073b4,(%esp)
f01015d0:	e8 bd 28 00 00       	call   f0103e92 <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);  // first_level pagedir
f01015d5:	b8 00 10 00 00       	mov    $0x1000,%eax
f01015da:	e8 81 f5 ff ff       	call   f0100b60 <boot_alloc>
f01015df:	a3 8c 4e 1c f0       	mov    %eax,0xf01c4e8c
	memset(kern_pgdir, 0, PGSIZE);
f01015e4:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01015eb:	00 
f01015ec:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01015f3:	00 
f01015f4:	89 04 24             	mov    %eax,(%esp)
f01015f7:	e8 0d 49 00 00       	call   f0105f09 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f01015fc:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101601:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101606:	77 20                	ja     f0101628 <mem_init+0x117>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101608:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010160c:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0101613:	f0 
f0101614:	c7 44 24 04 96 00 00 	movl   $0x96,0x4(%esp)
f010161b:	00 
f010161c:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101623:	e8 18 ea ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0101628:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f010162e:	83 ca 05             	or     $0x5,%edx
f0101631:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct Page in this
	// array.  'npages' is the number of physical pages in memory.
	// Your code goes here:

	pages = (struct Page *)boot_alloc(npages * sizeof(struct Page)); // allocate npages to record all physical pages in memort using condition
f0101637:	a1 88 4e 1c f0       	mov    0xf01c4e88,%eax
f010163c:	c1 e0 03             	shl    $0x3,%eax
f010163f:	e8 1c f5 ff ff       	call   f0100b60 <boot_alloc>
f0101644:	a3 90 4e 1c f0       	mov    %eax,0xf01c4e90


	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.
	envs =  (struct Env *)boot_alloc(NENV * sizeof(struct Env));
f0101649:	b8 00 f0 01 00       	mov    $0x1f000,%eax
f010164e:	e8 0d f5 ff ff       	call   f0100b60 <boot_alloc>
f0101653:	a3 48 42 1c f0       	mov    %eax,0xf01c4248
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f0101658:	e8 a9 f9 ff ff       	call   f0101006 <page_init>

	check_page_free_list(1);
f010165d:	b8 01 00 00 00       	mov    $0x1,%eax
f0101662:	e8 cc f5 ff ff       	call   f0100c33 <check_page_free_list>
	int nfree;
	struct Page *fl;
	char *c;
	int i;

	if (!pages)
f0101667:	83 3d 90 4e 1c f0 00 	cmpl   $0x0,0xf01c4e90
f010166e:	75 1c                	jne    f010168c <mem_init+0x17b>
		panic("'pages' is a null pointer!");
f0101670:	c7 44 24 08 ba 7a 10 	movl   $0xf0107aba,0x8(%esp)
f0101677:	f0 
f0101678:	c7 44 24 04 10 03 00 	movl   $0x310,0x4(%esp)
f010167f:	00 
f0101680:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101687:	e8 b4 e9 ff ff       	call   f0100040 <_panic>

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010168c:	a1 40 42 1c f0       	mov    0xf01c4240,%eax
f0101691:	85 c0                	test   %eax,%eax
f0101693:	74 10                	je     f01016a5 <mem_init+0x194>
f0101695:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;
f010169a:	83 c3 01             	add    $0x1,%ebx

	if (!pages)
		panic("'pages' is a null pointer!");

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010169d:	8b 00                	mov    (%eax),%eax
f010169f:	85 c0                	test   %eax,%eax
f01016a1:	75 f7                	jne    f010169a <mem_init+0x189>
f01016a3:	eb 05                	jmp    f01016aa <mem_init+0x199>
f01016a5:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f01016aa:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01016b1:	e8 60 fa ff ff       	call   f0101116 <page_alloc>
f01016b6:	89 c7                	mov    %eax,%edi
f01016b8:	85 c0                	test   %eax,%eax
f01016ba:	75 24                	jne    f01016e0 <mem_init+0x1cf>
f01016bc:	c7 44 24 0c d5 7a 10 	movl   $0xf0107ad5,0xc(%esp)
f01016c3:	f0 
f01016c4:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01016cb:	f0 
f01016cc:	c7 44 24 04 18 03 00 	movl   $0x318,0x4(%esp)
f01016d3:	00 
f01016d4:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01016db:	e8 60 e9 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f01016e0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01016e7:	e8 2a fa ff ff       	call   f0101116 <page_alloc>
f01016ec:	89 c6                	mov    %eax,%esi
f01016ee:	85 c0                	test   %eax,%eax
f01016f0:	75 24                	jne    f0101716 <mem_init+0x205>
f01016f2:	c7 44 24 0c eb 7a 10 	movl   $0xf0107aeb,0xc(%esp)
f01016f9:	f0 
f01016fa:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101701:	f0 
f0101702:	c7 44 24 04 19 03 00 	movl   $0x319,0x4(%esp)
f0101709:	00 
f010170a:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101711:	e8 2a e9 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0101716:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010171d:	e8 f4 f9 ff ff       	call   f0101116 <page_alloc>
f0101722:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101725:	85 c0                	test   %eax,%eax
f0101727:	75 24                	jne    f010174d <mem_init+0x23c>
f0101729:	c7 44 24 0c 01 7b 10 	movl   $0xf0107b01,0xc(%esp)
f0101730:	f0 
f0101731:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101738:	f0 
f0101739:	c7 44 24 04 1a 03 00 	movl   $0x31a,0x4(%esp)
f0101740:	00 
f0101741:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101748:	e8 f3 e8 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f010174d:	39 f7                	cmp    %esi,%edi
f010174f:	75 24                	jne    f0101775 <mem_init+0x264>
f0101751:	c7 44 24 0c 17 7b 10 	movl   $0xf0107b17,0xc(%esp)
f0101758:	f0 
f0101759:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101760:	f0 
f0101761:	c7 44 24 04 1d 03 00 	movl   $0x31d,0x4(%esp)
f0101768:	00 
f0101769:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101770:	e8 cb e8 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101775:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101778:	39 c6                	cmp    %eax,%esi
f010177a:	74 04                	je     f0101780 <mem_init+0x26f>
f010177c:	39 c7                	cmp    %eax,%edi
f010177e:	75 24                	jne    f01017a4 <mem_init+0x293>
f0101780:	c7 44 24 0c f0 73 10 	movl   $0xf01073f0,0xc(%esp)
f0101787:	f0 
f0101788:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010178f:	f0 
f0101790:	c7 44 24 04 1e 03 00 	movl   $0x31e,0x4(%esp)
f0101797:	00 
f0101798:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010179f:	e8 9c e8 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01017a4:	8b 15 90 4e 1c f0    	mov    0xf01c4e90,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f01017aa:	a1 88 4e 1c f0       	mov    0xf01c4e88,%eax
f01017af:	c1 e0 0c             	shl    $0xc,%eax
f01017b2:	89 f9                	mov    %edi,%ecx
f01017b4:	29 d1                	sub    %edx,%ecx
f01017b6:	c1 f9 03             	sar    $0x3,%ecx
f01017b9:	c1 e1 0c             	shl    $0xc,%ecx
f01017bc:	39 c1                	cmp    %eax,%ecx
f01017be:	72 24                	jb     f01017e4 <mem_init+0x2d3>
f01017c0:	c7 44 24 0c 29 7b 10 	movl   $0xf0107b29,0xc(%esp)
f01017c7:	f0 
f01017c8:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01017cf:	f0 
f01017d0:	c7 44 24 04 1f 03 00 	movl   $0x31f,0x4(%esp)
f01017d7:	00 
f01017d8:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01017df:	e8 5c e8 ff ff       	call   f0100040 <_panic>
f01017e4:	89 f1                	mov    %esi,%ecx
f01017e6:	29 d1                	sub    %edx,%ecx
f01017e8:	c1 f9 03             	sar    $0x3,%ecx
f01017eb:	c1 e1 0c             	shl    $0xc,%ecx
	assert(page2pa(pp1) < npages*PGSIZE);
f01017ee:	39 c8                	cmp    %ecx,%eax
f01017f0:	77 24                	ja     f0101816 <mem_init+0x305>
f01017f2:	c7 44 24 0c 46 7b 10 	movl   $0xf0107b46,0xc(%esp)
f01017f9:	f0 
f01017fa:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101801:	f0 
f0101802:	c7 44 24 04 20 03 00 	movl   $0x320,0x4(%esp)
f0101809:	00 
f010180a:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101811:	e8 2a e8 ff ff       	call   f0100040 <_panic>
f0101816:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0101819:	29 d1                	sub    %edx,%ecx
f010181b:	89 ca                	mov    %ecx,%edx
f010181d:	c1 fa 03             	sar    $0x3,%edx
f0101820:	c1 e2 0c             	shl    $0xc,%edx
	assert(page2pa(pp2) < npages*PGSIZE);
f0101823:	39 d0                	cmp    %edx,%eax
f0101825:	77 24                	ja     f010184b <mem_init+0x33a>
f0101827:	c7 44 24 0c 63 7b 10 	movl   $0xf0107b63,0xc(%esp)
f010182e:	f0 
f010182f:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101836:	f0 
f0101837:	c7 44 24 04 21 03 00 	movl   $0x321,0x4(%esp)
f010183e:	00 
f010183f:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101846:	e8 f5 e7 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f010184b:	a1 40 42 1c f0       	mov    0xf01c4240,%eax
f0101850:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101853:	c7 05 40 42 1c f0 00 	movl   $0x0,0xf01c4240
f010185a:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f010185d:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101864:	e8 ad f8 ff ff       	call   f0101116 <page_alloc>
f0101869:	85 c0                	test   %eax,%eax
f010186b:	74 24                	je     f0101891 <mem_init+0x380>
f010186d:	c7 44 24 0c 80 7b 10 	movl   $0xf0107b80,0xc(%esp)
f0101874:	f0 
f0101875:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010187c:	f0 
f010187d:	c7 44 24 04 28 03 00 	movl   $0x328,0x4(%esp)
f0101884:	00 
f0101885:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010188c:	e8 af e7 ff ff       	call   f0100040 <_panic>

	// free and re-allocate?
	page_free(pp0);
f0101891:	89 3c 24             	mov    %edi,(%esp)
f0101894:	e8 02 f9 ff ff       	call   f010119b <page_free>
	page_free(pp1);
f0101899:	89 34 24             	mov    %esi,(%esp)
f010189c:	e8 fa f8 ff ff       	call   f010119b <page_free>
	page_free(pp2);
f01018a1:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01018a4:	89 04 24             	mov    %eax,(%esp)
f01018a7:	e8 ef f8 ff ff       	call   f010119b <page_free>
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f01018ac:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018b3:	e8 5e f8 ff ff       	call   f0101116 <page_alloc>
f01018b8:	89 c6                	mov    %eax,%esi
f01018ba:	85 c0                	test   %eax,%eax
f01018bc:	75 24                	jne    f01018e2 <mem_init+0x3d1>
f01018be:	c7 44 24 0c d5 7a 10 	movl   $0xf0107ad5,0xc(%esp)
f01018c5:	f0 
f01018c6:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01018cd:	f0 
f01018ce:	c7 44 24 04 2f 03 00 	movl   $0x32f,0x4(%esp)
f01018d5:	00 
f01018d6:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01018dd:	e8 5e e7 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f01018e2:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018e9:	e8 28 f8 ff ff       	call   f0101116 <page_alloc>
f01018ee:	89 c7                	mov    %eax,%edi
f01018f0:	85 c0                	test   %eax,%eax
f01018f2:	75 24                	jne    f0101918 <mem_init+0x407>
f01018f4:	c7 44 24 0c eb 7a 10 	movl   $0xf0107aeb,0xc(%esp)
f01018fb:	f0 
f01018fc:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101903:	f0 
f0101904:	c7 44 24 04 30 03 00 	movl   $0x330,0x4(%esp)
f010190b:	00 
f010190c:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101913:	e8 28 e7 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0101918:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010191f:	e8 f2 f7 ff ff       	call   f0101116 <page_alloc>
f0101924:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101927:	85 c0                	test   %eax,%eax
f0101929:	75 24                	jne    f010194f <mem_init+0x43e>
f010192b:	c7 44 24 0c 01 7b 10 	movl   $0xf0107b01,0xc(%esp)
f0101932:	f0 
f0101933:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010193a:	f0 
f010193b:	c7 44 24 04 31 03 00 	movl   $0x331,0x4(%esp)
f0101942:	00 
f0101943:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010194a:	e8 f1 e6 ff ff       	call   f0100040 <_panic>
	assert(pp0);
	assert(pp1 && pp1 != pp0);
f010194f:	39 fe                	cmp    %edi,%esi
f0101951:	75 24                	jne    f0101977 <mem_init+0x466>
f0101953:	c7 44 24 0c 17 7b 10 	movl   $0xf0107b17,0xc(%esp)
f010195a:	f0 
f010195b:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101962:	f0 
f0101963:	c7 44 24 04 33 03 00 	movl   $0x333,0x4(%esp)
f010196a:	00 
f010196b:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101972:	e8 c9 e6 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101977:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010197a:	39 c7                	cmp    %eax,%edi
f010197c:	74 04                	je     f0101982 <mem_init+0x471>
f010197e:	39 c6                	cmp    %eax,%esi
f0101980:	75 24                	jne    f01019a6 <mem_init+0x495>
f0101982:	c7 44 24 0c f0 73 10 	movl   $0xf01073f0,0xc(%esp)
f0101989:	f0 
f010198a:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101991:	f0 
f0101992:	c7 44 24 04 34 03 00 	movl   $0x334,0x4(%esp)
f0101999:	00 
f010199a:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01019a1:	e8 9a e6 ff ff       	call   f0100040 <_panic>
	assert(!page_alloc(0));
f01019a6:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01019ad:	e8 64 f7 ff ff       	call   f0101116 <page_alloc>
f01019b2:	85 c0                	test   %eax,%eax
f01019b4:	74 24                	je     f01019da <mem_init+0x4c9>
f01019b6:	c7 44 24 0c 80 7b 10 	movl   $0xf0107b80,0xc(%esp)
f01019bd:	f0 
f01019be:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01019c5:	f0 
f01019c6:	c7 44 24 04 35 03 00 	movl   $0x335,0x4(%esp)
f01019cd:	00 
f01019ce:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01019d5:	e8 66 e6 ff ff       	call   f0100040 <_panic>
f01019da:	89 f0                	mov    %esi,%eax
f01019dc:	2b 05 90 4e 1c f0    	sub    0xf01c4e90,%eax
f01019e2:	c1 f8 03             	sar    $0x3,%eax
f01019e5:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01019e8:	89 c2                	mov    %eax,%edx
f01019ea:	c1 ea 0c             	shr    $0xc,%edx
f01019ed:	3b 15 88 4e 1c f0    	cmp    0xf01c4e88,%edx
f01019f3:	72 20                	jb     f0101a15 <mem_init+0x504>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01019f5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01019f9:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0101a00:	f0 
f0101a01:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101a08:	00 
f0101a09:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f0101a10:	e8 2b e6 ff ff       	call   f0100040 <_panic>

	// test flags
	memset(page2kva(pp0), 1, PGSIZE);
f0101a15:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101a1c:	00 
f0101a1d:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f0101a24:	00 
	return (void *)(pa + KERNBASE);
f0101a25:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101a2a:	89 04 24             	mov    %eax,(%esp)
f0101a2d:	e8 d7 44 00 00       	call   f0105f09 <memset>
	page_free(pp0);
f0101a32:	89 34 24             	mov    %esi,(%esp)
f0101a35:	e8 61 f7 ff ff       	call   f010119b <page_free>
	assert((pp = page_alloc(ALLOC_ZERO)));
f0101a3a:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101a41:	e8 d0 f6 ff ff       	call   f0101116 <page_alloc>
f0101a46:	85 c0                	test   %eax,%eax
f0101a48:	75 24                	jne    f0101a6e <mem_init+0x55d>
f0101a4a:	c7 44 24 0c 8f 7b 10 	movl   $0xf0107b8f,0xc(%esp)
f0101a51:	f0 
f0101a52:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101a59:	f0 
f0101a5a:	c7 44 24 04 3a 03 00 	movl   $0x33a,0x4(%esp)
f0101a61:	00 
f0101a62:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101a69:	e8 d2 e5 ff ff       	call   f0100040 <_panic>
	assert(pp && pp0 == pp);
f0101a6e:	39 c6                	cmp    %eax,%esi
f0101a70:	74 24                	je     f0101a96 <mem_init+0x585>
f0101a72:	c7 44 24 0c ad 7b 10 	movl   $0xf0107bad,0xc(%esp)
f0101a79:	f0 
f0101a7a:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101a81:	f0 
f0101a82:	c7 44 24 04 3b 03 00 	movl   $0x33b,0x4(%esp)
f0101a89:	00 
f0101a8a:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101a91:	e8 aa e5 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101a96:	89 f2                	mov    %esi,%edx
f0101a98:	2b 15 90 4e 1c f0    	sub    0xf01c4e90,%edx
f0101a9e:	c1 fa 03             	sar    $0x3,%edx
f0101aa1:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101aa4:	89 d0                	mov    %edx,%eax
f0101aa6:	c1 e8 0c             	shr    $0xc,%eax
f0101aa9:	3b 05 88 4e 1c f0    	cmp    0xf01c4e88,%eax
f0101aaf:	72 20                	jb     f0101ad1 <mem_init+0x5c0>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101ab1:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101ab5:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0101abc:	f0 
f0101abd:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101ac4:	00 
f0101ac5:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f0101acc:	e8 6f e5 ff ff       	call   f0100040 <_panic>
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
		assert(c[i] == 0);
f0101ad1:	80 ba 00 00 00 f0 00 	cmpb   $0x0,-0x10000000(%edx)
f0101ad8:	75 11                	jne    f0101aeb <mem_init+0x5da>
f0101ada:	8d 82 01 00 00 f0    	lea    -0xfffffff(%edx),%eax
f0101ae0:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0101ae6:	80 38 00             	cmpb   $0x0,(%eax)
f0101ae9:	74 24                	je     f0101b0f <mem_init+0x5fe>
f0101aeb:	c7 44 24 0c bd 7b 10 	movl   $0xf0107bbd,0xc(%esp)
f0101af2:	f0 
f0101af3:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101afa:	f0 
f0101afb:	c7 44 24 04 3e 03 00 	movl   $0x33e,0x4(%esp)
f0101b02:	00 
f0101b03:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101b0a:	e8 31 e5 ff ff       	call   f0100040 <_panic>
f0101b0f:	83 c0 01             	add    $0x1,%eax
	memset(page2kva(pp0), 1, PGSIZE);
	page_free(pp0);
	assert((pp = page_alloc(ALLOC_ZERO)));
	assert(pp && pp0 == pp);
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
f0101b12:	39 d0                	cmp    %edx,%eax
f0101b14:	75 d0                	jne    f0101ae6 <mem_init+0x5d5>
		assert(c[i] == 0);

	// give free list back
	page_free_list = fl;
f0101b16:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101b19:	a3 40 42 1c f0       	mov    %eax,0xf01c4240

	// free the pages we took
	page_free(pp0);
f0101b1e:	89 34 24             	mov    %esi,(%esp)
f0101b21:	e8 75 f6 ff ff       	call   f010119b <page_free>
	page_free(pp1);
f0101b26:	89 3c 24             	mov    %edi,(%esp)
f0101b29:	e8 6d f6 ff ff       	call   f010119b <page_free>
	page_free(pp2);
f0101b2e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101b31:	89 04 24             	mov    %eax,(%esp)
f0101b34:	e8 62 f6 ff ff       	call   f010119b <page_free>

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101b39:	a1 40 42 1c f0       	mov    0xf01c4240,%eax
f0101b3e:	85 c0                	test   %eax,%eax
f0101b40:	74 09                	je     f0101b4b <mem_init+0x63a>
		--nfree;
f0101b42:	83 eb 01             	sub    $0x1,%ebx
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101b45:	8b 00                	mov    (%eax),%eax
f0101b47:	85 c0                	test   %eax,%eax
f0101b49:	75 f7                	jne    f0101b42 <mem_init+0x631>
		--nfree;
	assert(nfree == 0);
f0101b4b:	85 db                	test   %ebx,%ebx
f0101b4d:	74 24                	je     f0101b73 <mem_init+0x662>
f0101b4f:	c7 44 24 0c c7 7b 10 	movl   $0xf0107bc7,0xc(%esp)
f0101b56:	f0 
f0101b57:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101b5e:	f0 
f0101b5f:	c7 44 24 04 4b 03 00 	movl   $0x34b,0x4(%esp)
f0101b66:	00 
f0101b67:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101b6e:	e8 cd e4 ff ff       	call   f0100040 <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f0101b73:	c7 04 24 10 74 10 f0 	movl   $0xf0107410,(%esp)
f0101b7a:	e8 13 23 00 00       	call   f0103e92 <cprintf>
	int i;
	extern pde_t entry_pgdir[];

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101b7f:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b86:	e8 8b f5 ff ff       	call   f0101116 <page_alloc>
f0101b8b:	89 c3                	mov    %eax,%ebx
f0101b8d:	85 c0                	test   %eax,%eax
f0101b8f:	75 24                	jne    f0101bb5 <mem_init+0x6a4>
f0101b91:	c7 44 24 0c d5 7a 10 	movl   $0xf0107ad5,0xc(%esp)
f0101b98:	f0 
f0101b99:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101ba0:	f0 
f0101ba1:	c7 44 24 04 b3 03 00 	movl   $0x3b3,0x4(%esp)
f0101ba8:	00 
f0101ba9:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101bb0:	e8 8b e4 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101bb5:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101bbc:	e8 55 f5 ff ff       	call   f0101116 <page_alloc>
f0101bc1:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101bc4:	85 c0                	test   %eax,%eax
f0101bc6:	75 24                	jne    f0101bec <mem_init+0x6db>
f0101bc8:	c7 44 24 0c eb 7a 10 	movl   $0xf0107aeb,0xc(%esp)
f0101bcf:	f0 
f0101bd0:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101bd7:	f0 
f0101bd8:	c7 44 24 04 b4 03 00 	movl   $0x3b4,0x4(%esp)
f0101bdf:	00 
f0101be0:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101be7:	e8 54 e4 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0101bec:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101bf3:	e8 1e f5 ff ff       	call   f0101116 <page_alloc>
f0101bf8:	89 c7                	mov    %eax,%edi
f0101bfa:	85 c0                	test   %eax,%eax
f0101bfc:	75 24                	jne    f0101c22 <mem_init+0x711>
f0101bfe:	c7 44 24 0c 01 7b 10 	movl   $0xf0107b01,0xc(%esp)
f0101c05:	f0 
f0101c06:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101c0d:	f0 
f0101c0e:	c7 44 24 04 b5 03 00 	movl   $0x3b5,0x4(%esp)
f0101c15:	00 
f0101c16:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101c1d:	e8 1e e4 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101c22:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0101c25:	75 24                	jne    f0101c4b <mem_init+0x73a>
f0101c27:	c7 44 24 0c 17 7b 10 	movl   $0xf0107b17,0xc(%esp)
f0101c2e:	f0 
f0101c2f:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101c36:	f0 
f0101c37:	c7 44 24 04 b8 03 00 	movl   $0x3b8,0x4(%esp)
f0101c3e:	00 
f0101c3f:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101c46:	e8 f5 e3 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101c4b:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f0101c4e:	74 04                	je     f0101c54 <mem_init+0x743>
f0101c50:	39 c3                	cmp    %eax,%ebx
f0101c52:	75 24                	jne    f0101c78 <mem_init+0x767>
f0101c54:	c7 44 24 0c f0 73 10 	movl   $0xf01073f0,0xc(%esp)
f0101c5b:	f0 
f0101c5c:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101c63:	f0 
f0101c64:	c7 44 24 04 b9 03 00 	movl   $0x3b9,0x4(%esp)
f0101c6b:	00 
f0101c6c:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101c73:	e8 c8 e3 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101c78:	a1 40 42 1c f0       	mov    0xf01c4240,%eax
f0101c7d:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101c80:	c7 05 40 42 1c f0 00 	movl   $0x0,0xf01c4240
f0101c87:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f0101c8a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101c91:	e8 80 f4 ff ff       	call   f0101116 <page_alloc>
f0101c96:	85 c0                	test   %eax,%eax
f0101c98:	74 24                	je     f0101cbe <mem_init+0x7ad>
f0101c9a:	c7 44 24 0c 80 7b 10 	movl   $0xf0107b80,0xc(%esp)
f0101ca1:	f0 
f0101ca2:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101ca9:	f0 
f0101caa:	c7 44 24 04 c0 03 00 	movl   $0x3c0,0x4(%esp)
f0101cb1:	00 
f0101cb2:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101cb9:	e8 82 e3 ff ff       	call   f0100040 <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f0101cbe:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101cc1:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101cc5:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101ccc:	00 
f0101ccd:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f0101cd2:	89 04 24             	mov    %eax,(%esp)
f0101cd5:	e8 8b f6 ff ff       	call   f0101365 <page_lookup>
f0101cda:	85 c0                	test   %eax,%eax
f0101cdc:	74 24                	je     f0101d02 <mem_init+0x7f1>
f0101cde:	c7 44 24 0c 30 74 10 	movl   $0xf0107430,0xc(%esp)
f0101ce5:	f0 
f0101ce6:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101ced:	f0 
f0101cee:	c7 44 24 04 c3 03 00 	movl   $0x3c3,0x4(%esp)
f0101cf5:	00 
f0101cf6:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101cfd:	e8 3e e3 ff ff       	call   f0100040 <_panic>

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);
f0101d02:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101d09:	00 
f0101d0a:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101d11:	00 
f0101d12:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101d15:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101d19:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f0101d1e:	89 04 24             	mov    %eax,(%esp)
f0101d21:	e8 2a f7 ff ff       	call   f0101450 <page_insert>
f0101d26:	85 c0                	test   %eax,%eax
f0101d28:	78 24                	js     f0101d4e <mem_init+0x83d>
f0101d2a:	c7 44 24 0c 68 74 10 	movl   $0xf0107468,0xc(%esp)
f0101d31:	f0 
f0101d32:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101d39:	f0 
f0101d3a:	c7 44 24 04 c6 03 00 	movl   $0x3c6,0x4(%esp)
f0101d41:	00 
f0101d42:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101d49:	e8 f2 e2 ff ff       	call   f0100040 <_panic>

	// free pp0 and try again: pp0 should be used for page table
	page_free(pp0);
f0101d4e:	89 1c 24             	mov    %ebx,(%esp)
f0101d51:	e8 45 f4 ff ff       	call   f010119b <page_free>
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) == 0);
f0101d56:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101d5d:	00 
f0101d5e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101d65:	00 
f0101d66:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101d69:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101d6d:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f0101d72:	89 04 24             	mov    %eax,(%esp)
f0101d75:	e8 d6 f6 ff ff       	call   f0101450 <page_insert>
f0101d7a:	85 c0                	test   %eax,%eax
f0101d7c:	74 24                	je     f0101da2 <mem_init+0x891>
f0101d7e:	c7 44 24 0c 98 74 10 	movl   $0xf0107498,0xc(%esp)
f0101d85:	f0 
f0101d86:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101d8d:	f0 
f0101d8e:	c7 44 24 04 ca 03 00 	movl   $0x3ca,0x4(%esp)
f0101d95:	00 
f0101d96:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101d9d:	e8 9e e2 ff ff       	call   f0100040 <_panic>
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101da2:	8b 35 8c 4e 1c f0    	mov    0xf01c4e8c,%esi
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101da8:	a1 90 4e 1c f0       	mov    0xf01c4e90,%eax
f0101dad:	89 45 cc             	mov    %eax,-0x34(%ebp)
f0101db0:	8b 16                	mov    (%esi),%edx
f0101db2:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0101db8:	89 d9                	mov    %ebx,%ecx
f0101dba:	29 c1                	sub    %eax,%ecx
f0101dbc:	89 c8                	mov    %ecx,%eax
f0101dbe:	c1 f8 03             	sar    $0x3,%eax
f0101dc1:	c1 e0 0c             	shl    $0xc,%eax
f0101dc4:	39 c2                	cmp    %eax,%edx
f0101dc6:	74 24                	je     f0101dec <mem_init+0x8db>
f0101dc8:	c7 44 24 0c c8 74 10 	movl   $0xf01074c8,0xc(%esp)
f0101dcf:	f0 
f0101dd0:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101dd7:	f0 
f0101dd8:	c7 44 24 04 cb 03 00 	movl   $0x3cb,0x4(%esp)
f0101ddf:	00 
f0101de0:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101de7:	e8 54 e2 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, 0x0) == page2pa(pp1));
f0101dec:	ba 00 00 00 00       	mov    $0x0,%edx
f0101df1:	89 f0                	mov    %esi,%eax
f0101df3:	e8 cc ed ff ff       	call   f0100bc4 <check_va2pa>
f0101df8:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101dfb:	2b 55 cc             	sub    -0x34(%ebp),%edx
f0101dfe:	c1 fa 03             	sar    $0x3,%edx
f0101e01:	c1 e2 0c             	shl    $0xc,%edx
f0101e04:	39 d0                	cmp    %edx,%eax
f0101e06:	74 24                	je     f0101e2c <mem_init+0x91b>
f0101e08:	c7 44 24 0c f0 74 10 	movl   $0xf01074f0,0xc(%esp)
f0101e0f:	f0 
f0101e10:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101e17:	f0 
f0101e18:	c7 44 24 04 cc 03 00 	movl   $0x3cc,0x4(%esp)
f0101e1f:	00 
f0101e20:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101e27:	e8 14 e2 ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0101e2c:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101e2f:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101e34:	74 24                	je     f0101e5a <mem_init+0x949>
f0101e36:	c7 44 24 0c d2 7b 10 	movl   $0xf0107bd2,0xc(%esp)
f0101e3d:	f0 
f0101e3e:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101e45:	f0 
f0101e46:	c7 44 24 04 cd 03 00 	movl   $0x3cd,0x4(%esp)
f0101e4d:	00 
f0101e4e:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101e55:	e8 e6 e1 ff ff       	call   f0100040 <_panic>
	assert(pp0->pp_ref == 1);
f0101e5a:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0101e5f:	74 24                	je     f0101e85 <mem_init+0x974>
f0101e61:	c7 44 24 0c e3 7b 10 	movl   $0xf0107be3,0xc(%esp)
f0101e68:	f0 
f0101e69:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101e70:	f0 
f0101e71:	c7 44 24 04 ce 03 00 	movl   $0x3ce,0x4(%esp)
f0101e78:	00 
f0101e79:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101e80:	e8 bb e1 ff ff       	call   f0100040 <_panic>

	// should be able to map pp2 at PGSIZE because pp0 is already allocated for page table
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101e85:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101e8c:	00 
f0101e8d:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101e94:	00 
f0101e95:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101e99:	89 34 24             	mov    %esi,(%esp)
f0101e9c:	e8 af f5 ff ff       	call   f0101450 <page_insert>
f0101ea1:	85 c0                	test   %eax,%eax
f0101ea3:	74 24                	je     f0101ec9 <mem_init+0x9b8>
f0101ea5:	c7 44 24 0c 20 75 10 	movl   $0xf0107520,0xc(%esp)
f0101eac:	f0 
f0101ead:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101eb4:	f0 
f0101eb5:	c7 44 24 04 d1 03 00 	movl   $0x3d1,0x4(%esp)
f0101ebc:	00 
f0101ebd:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101ec4:	e8 77 e1 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101ec9:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101ece:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f0101ed3:	e8 ec ec ff ff       	call   f0100bc4 <check_va2pa>
f0101ed8:	89 fa                	mov    %edi,%edx
f0101eda:	2b 15 90 4e 1c f0    	sub    0xf01c4e90,%edx
f0101ee0:	c1 fa 03             	sar    $0x3,%edx
f0101ee3:	c1 e2 0c             	shl    $0xc,%edx
f0101ee6:	39 d0                	cmp    %edx,%eax
f0101ee8:	74 24                	je     f0101f0e <mem_init+0x9fd>
f0101eea:	c7 44 24 0c 5c 75 10 	movl   $0xf010755c,0xc(%esp)
f0101ef1:	f0 
f0101ef2:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101ef9:	f0 
f0101efa:	c7 44 24 04 d2 03 00 	movl   $0x3d2,0x4(%esp)
f0101f01:	00 
f0101f02:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101f09:	e8 32 e1 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101f0e:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0101f13:	74 24                	je     f0101f39 <mem_init+0xa28>
f0101f15:	c7 44 24 0c f4 7b 10 	movl   $0xf0107bf4,0xc(%esp)
f0101f1c:	f0 
f0101f1d:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101f24:	f0 
f0101f25:	c7 44 24 04 d3 03 00 	movl   $0x3d3,0x4(%esp)
f0101f2c:	00 
f0101f2d:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101f34:	e8 07 e1 ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0101f39:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101f40:	e8 d1 f1 ff ff       	call   f0101116 <page_alloc>
f0101f45:	85 c0                	test   %eax,%eax
f0101f47:	74 24                	je     f0101f6d <mem_init+0xa5c>
f0101f49:	c7 44 24 0c 80 7b 10 	movl   $0xf0107b80,0xc(%esp)
f0101f50:	f0 
f0101f51:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101f58:	f0 
f0101f59:	c7 44 24 04 d6 03 00 	movl   $0x3d6,0x4(%esp)
f0101f60:	00 
f0101f61:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101f68:	e8 d3 e0 ff ff       	call   f0100040 <_panic>

	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101f6d:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101f74:	00 
f0101f75:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101f7c:	00 
f0101f7d:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101f81:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f0101f86:	89 04 24             	mov    %eax,(%esp)
f0101f89:	e8 c2 f4 ff ff       	call   f0101450 <page_insert>
f0101f8e:	85 c0                	test   %eax,%eax
f0101f90:	74 24                	je     f0101fb6 <mem_init+0xaa5>
f0101f92:	c7 44 24 0c 20 75 10 	movl   $0xf0107520,0xc(%esp)
f0101f99:	f0 
f0101f9a:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101fa1:	f0 
f0101fa2:	c7 44 24 04 d9 03 00 	movl   $0x3d9,0x4(%esp)
f0101fa9:	00 
f0101faa:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101fb1:	e8 8a e0 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101fb6:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101fbb:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f0101fc0:	e8 ff eb ff ff       	call   f0100bc4 <check_va2pa>
f0101fc5:	89 fa                	mov    %edi,%edx
f0101fc7:	2b 15 90 4e 1c f0    	sub    0xf01c4e90,%edx
f0101fcd:	c1 fa 03             	sar    $0x3,%edx
f0101fd0:	c1 e2 0c             	shl    $0xc,%edx
f0101fd3:	39 d0                	cmp    %edx,%eax
f0101fd5:	74 24                	je     f0101ffb <mem_init+0xaea>
f0101fd7:	c7 44 24 0c 5c 75 10 	movl   $0xf010755c,0xc(%esp)
f0101fde:	f0 
f0101fdf:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101fe6:	f0 
f0101fe7:	c7 44 24 04 da 03 00 	movl   $0x3da,0x4(%esp)
f0101fee:	00 
f0101fef:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101ff6:	e8 45 e0 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101ffb:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0102000:	74 24                	je     f0102026 <mem_init+0xb15>
f0102002:	c7 44 24 0c f4 7b 10 	movl   $0xf0107bf4,0xc(%esp)
f0102009:	f0 
f010200a:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102011:	f0 
f0102012:	c7 44 24 04 db 03 00 	movl   $0x3db,0x4(%esp)
f0102019:	00 
f010201a:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102021:	e8 1a e0 ff ff       	call   f0100040 <_panic>

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));
f0102026:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010202d:	e8 e4 f0 ff ff       	call   f0101116 <page_alloc>
f0102032:	85 c0                	test   %eax,%eax
f0102034:	74 24                	je     f010205a <mem_init+0xb49>
f0102036:	c7 44 24 0c 80 7b 10 	movl   $0xf0107b80,0xc(%esp)
f010203d:	f0 
f010203e:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102045:	f0 
f0102046:	c7 44 24 04 df 03 00 	movl   $0x3df,0x4(%esp)
f010204d:	00 
f010204e:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102055:	e8 e6 df ff ff       	call   f0100040 <_panic>

	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f010205a:	8b 15 8c 4e 1c f0    	mov    0xf01c4e8c,%edx
f0102060:	8b 02                	mov    (%edx),%eax
f0102062:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102067:	89 c1                	mov    %eax,%ecx
f0102069:	c1 e9 0c             	shr    $0xc,%ecx
f010206c:	3b 0d 88 4e 1c f0    	cmp    0xf01c4e88,%ecx
f0102072:	72 20                	jb     f0102094 <mem_init+0xb83>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102074:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102078:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f010207f:	f0 
f0102080:	c7 44 24 04 e2 03 00 	movl   $0x3e2,0x4(%esp)
f0102087:	00 
f0102088:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010208f:	e8 ac df ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0102094:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102099:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	assert(pgdir_walk(kern_pgdir, (void*)PGSIZE, 0) == ptep+PTX(PGSIZE));
f010209c:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01020a3:	00 
f01020a4:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01020ab:	00 
f01020ac:	89 14 24             	mov    %edx,(%esp)
f01020af:	e8 1f f1 ff ff       	call   f01011d3 <pgdir_walk>
f01020b4:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f01020b7:	8d 51 04             	lea    0x4(%ecx),%edx
f01020ba:	39 d0                	cmp    %edx,%eax
f01020bc:	74 24                	je     f01020e2 <mem_init+0xbd1>
f01020be:	c7 44 24 0c 8c 75 10 	movl   $0xf010758c,0xc(%esp)
f01020c5:	f0 
f01020c6:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01020cd:	f0 
f01020ce:	c7 44 24 04 e3 03 00 	movl   $0x3e3,0x4(%esp)
f01020d5:	00 
f01020d6:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01020dd:	e8 5e df ff ff       	call   f0100040 <_panic>

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
f01020e2:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01020e9:	00 
f01020ea:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01020f1:	00 
f01020f2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01020f6:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f01020fb:	89 04 24             	mov    %eax,(%esp)
f01020fe:	e8 4d f3 ff ff       	call   f0101450 <page_insert>
f0102103:	85 c0                	test   %eax,%eax
f0102105:	74 24                	je     f010212b <mem_init+0xc1a>
f0102107:	c7 44 24 0c cc 75 10 	movl   $0xf01075cc,0xc(%esp)
f010210e:	f0 
f010210f:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102116:	f0 
f0102117:	c7 44 24 04 e6 03 00 	movl   $0x3e6,0x4(%esp)
f010211e:	00 
f010211f:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102126:	e8 15 df ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f010212b:	8b 35 8c 4e 1c f0    	mov    0xf01c4e8c,%esi
f0102131:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102136:	89 f0                	mov    %esi,%eax
f0102138:	e8 87 ea ff ff       	call   f0100bc4 <check_va2pa>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010213d:	89 fa                	mov    %edi,%edx
f010213f:	2b 15 90 4e 1c f0    	sub    0xf01c4e90,%edx
f0102145:	c1 fa 03             	sar    $0x3,%edx
f0102148:	c1 e2 0c             	shl    $0xc,%edx
f010214b:	39 d0                	cmp    %edx,%eax
f010214d:	74 24                	je     f0102173 <mem_init+0xc62>
f010214f:	c7 44 24 0c 5c 75 10 	movl   $0xf010755c,0xc(%esp)
f0102156:	f0 
f0102157:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010215e:	f0 
f010215f:	c7 44 24 04 e7 03 00 	movl   $0x3e7,0x4(%esp)
f0102166:	00 
f0102167:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010216e:	e8 cd de ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0102173:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0102178:	74 24                	je     f010219e <mem_init+0xc8d>
f010217a:	c7 44 24 0c f4 7b 10 	movl   $0xf0107bf4,0xc(%esp)
f0102181:	f0 
f0102182:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102189:	f0 
f010218a:	c7 44 24 04 e8 03 00 	movl   $0x3e8,0x4(%esp)
f0102191:	00 
f0102192:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102199:	e8 a2 de ff ff       	call   f0100040 <_panic>
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U);
f010219e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01021a5:	00 
f01021a6:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01021ad:	00 
f01021ae:	89 34 24             	mov    %esi,(%esp)
f01021b1:	e8 1d f0 ff ff       	call   f01011d3 <pgdir_walk>
f01021b6:	f6 00 04             	testb  $0x4,(%eax)
f01021b9:	75 24                	jne    f01021df <mem_init+0xcce>
f01021bb:	c7 44 24 0c 0c 76 10 	movl   $0xf010760c,0xc(%esp)
f01021c2:	f0 
f01021c3:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01021ca:	f0 
f01021cb:	c7 44 24 04 e9 03 00 	movl   $0x3e9,0x4(%esp)
f01021d2:	00 
f01021d3:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01021da:	e8 61 de ff ff       	call   f0100040 <_panic>
	assert(kern_pgdir[0] & PTE_U);
f01021df:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f01021e4:	f6 00 04             	testb  $0x4,(%eax)
f01021e7:	75 24                	jne    f010220d <mem_init+0xcfc>
f01021e9:	c7 44 24 0c 05 7c 10 	movl   $0xf0107c05,0xc(%esp)
f01021f0:	f0 
f01021f1:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01021f8:	f0 
f01021f9:	c7 44 24 04 ea 03 00 	movl   $0x3ea,0x4(%esp)
f0102200:	00 
f0102201:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102208:	e8 33 de ff ff       	call   f0100040 <_panic>

	// should not be able to map at PTSIZE because need free page for page table
	assert(page_insert(kern_pgdir, pp0, (void*) PTSIZE, PTE_W) < 0);
f010220d:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102214:	00 
f0102215:	c7 44 24 08 00 00 40 	movl   $0x400000,0x8(%esp)
f010221c:	00 
f010221d:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0102221:	89 04 24             	mov    %eax,(%esp)
f0102224:	e8 27 f2 ff ff       	call   f0101450 <page_insert>
f0102229:	85 c0                	test   %eax,%eax
f010222b:	78 24                	js     f0102251 <mem_init+0xd40>
f010222d:	c7 44 24 0c 40 76 10 	movl   $0xf0107640,0xc(%esp)
f0102234:	f0 
f0102235:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010223c:	f0 
f010223d:	c7 44 24 04 ed 03 00 	movl   $0x3ed,0x4(%esp)
f0102244:	00 
f0102245:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010224c:	e8 ef dd ff ff       	call   f0100040 <_panic>

	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
f0102251:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102258:	00 
f0102259:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102260:	00 
f0102261:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102264:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102268:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f010226d:	89 04 24             	mov    %eax,(%esp)
f0102270:	e8 db f1 ff ff       	call   f0101450 <page_insert>
f0102275:	85 c0                	test   %eax,%eax
f0102277:	74 24                	je     f010229d <mem_init+0xd8c>
f0102279:	c7 44 24 0c 78 76 10 	movl   $0xf0107678,0xc(%esp)
f0102280:	f0 
f0102281:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102288:	f0 
f0102289:	c7 44 24 04 f0 03 00 	movl   $0x3f0,0x4(%esp)
f0102290:	00 
f0102291:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102298:	e8 a3 dd ff ff       	call   f0100040 <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f010229d:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01022a4:	00 
f01022a5:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01022ac:	00 
f01022ad:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f01022b2:	89 04 24             	mov    %eax,(%esp)
f01022b5:	e8 19 ef ff ff       	call   f01011d3 <pgdir_walk>
f01022ba:	f6 00 04             	testb  $0x4,(%eax)
f01022bd:	74 24                	je     f01022e3 <mem_init+0xdd2>
f01022bf:	c7 44 24 0c b4 76 10 	movl   $0xf01076b4,0xc(%esp)
f01022c6:	f0 
f01022c7:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01022ce:	f0 
f01022cf:	c7 44 24 04 f1 03 00 	movl   $0x3f1,0x4(%esp)
f01022d6:	00 
f01022d7:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01022de:	e8 5d dd ff ff       	call   f0100040 <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f01022e3:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f01022e8:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01022eb:	ba 00 00 00 00       	mov    $0x0,%edx
f01022f0:	e8 cf e8 ff ff       	call   f0100bc4 <check_va2pa>
f01022f5:	89 c6                	mov    %eax,%esi
f01022f7:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01022fa:	2b 05 90 4e 1c f0    	sub    0xf01c4e90,%eax
f0102300:	c1 f8 03             	sar    $0x3,%eax
f0102303:	c1 e0 0c             	shl    $0xc,%eax
f0102306:	39 c6                	cmp    %eax,%esi
f0102308:	74 24                	je     f010232e <mem_init+0xe1d>
f010230a:	c7 44 24 0c ec 76 10 	movl   $0xf01076ec,0xc(%esp)
f0102311:	f0 
f0102312:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102319:	f0 
f010231a:	c7 44 24 04 f4 03 00 	movl   $0x3f4,0x4(%esp)
f0102321:	00 
f0102322:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102329:	e8 12 dd ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f010232e:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102333:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0102336:	e8 89 e8 ff ff       	call   f0100bc4 <check_va2pa>
f010233b:	39 c6                	cmp    %eax,%esi
f010233d:	74 24                	je     f0102363 <mem_init+0xe52>
f010233f:	c7 44 24 0c 18 77 10 	movl   $0xf0107718,0xc(%esp)
f0102346:	f0 
f0102347:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010234e:	f0 
f010234f:	c7 44 24 04 f5 03 00 	movl   $0x3f5,0x4(%esp)
f0102356:	00 
f0102357:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010235e:	e8 dd dc ff ff       	call   f0100040 <_panic>
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
f0102363:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102366:	66 83 78 04 02       	cmpw   $0x2,0x4(%eax)
f010236b:	74 24                	je     f0102391 <mem_init+0xe80>
f010236d:	c7 44 24 0c 1b 7c 10 	movl   $0xf0107c1b,0xc(%esp)
f0102374:	f0 
f0102375:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010237c:	f0 
f010237d:	c7 44 24 04 f7 03 00 	movl   $0x3f7,0x4(%esp)
f0102384:	00 
f0102385:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010238c:	e8 af dc ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f0102391:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f0102396:	74 24                	je     f01023bc <mem_init+0xeab>
f0102398:	c7 44 24 0c 2c 7c 10 	movl   $0xf0107c2c,0xc(%esp)
f010239f:	f0 
f01023a0:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01023a7:	f0 
f01023a8:	c7 44 24 04 f8 03 00 	movl   $0x3f8,0x4(%esp)
f01023af:	00 
f01023b0:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01023b7:	e8 84 dc ff ff       	call   f0100040 <_panic>

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);
f01023bc:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01023c3:	e8 4e ed ff ff       	call   f0101116 <page_alloc>
f01023c8:	85 c0                	test   %eax,%eax
f01023ca:	74 04                	je     f01023d0 <mem_init+0xebf>
f01023cc:	39 c7                	cmp    %eax,%edi
f01023ce:	74 24                	je     f01023f4 <mem_init+0xee3>
f01023d0:	c7 44 24 0c 48 77 10 	movl   $0xf0107748,0xc(%esp)
f01023d7:	f0 
f01023d8:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01023df:	f0 
f01023e0:	c7 44 24 04 fb 03 00 	movl   $0x3fb,0x4(%esp)
f01023e7:	00 
f01023e8:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01023ef:	e8 4c dc ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f01023f4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01023fb:	00 
f01023fc:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f0102401:	89 04 24             	mov    %eax,(%esp)
f0102404:	e8 fe ef ff ff       	call   f0101407 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f0102409:	8b 35 8c 4e 1c f0    	mov    0xf01c4e8c,%esi
f010240f:	ba 00 00 00 00       	mov    $0x0,%edx
f0102414:	89 f0                	mov    %esi,%eax
f0102416:	e8 a9 e7 ff ff       	call   f0100bc4 <check_va2pa>
f010241b:	83 f8 ff             	cmp    $0xffffffff,%eax
f010241e:	74 24                	je     f0102444 <mem_init+0xf33>
f0102420:	c7 44 24 0c 6c 77 10 	movl   $0xf010776c,0xc(%esp)
f0102427:	f0 
f0102428:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010242f:	f0 
f0102430:	c7 44 24 04 ff 03 00 	movl   $0x3ff,0x4(%esp)
f0102437:	00 
f0102438:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010243f:	e8 fc db ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102444:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102449:	89 f0                	mov    %esi,%eax
f010244b:	e8 74 e7 ff ff       	call   f0100bc4 <check_va2pa>
f0102450:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0102453:	2b 15 90 4e 1c f0    	sub    0xf01c4e90,%edx
f0102459:	c1 fa 03             	sar    $0x3,%edx
f010245c:	c1 e2 0c             	shl    $0xc,%edx
f010245f:	39 d0                	cmp    %edx,%eax
f0102461:	74 24                	je     f0102487 <mem_init+0xf76>
f0102463:	c7 44 24 0c 18 77 10 	movl   $0xf0107718,0xc(%esp)
f010246a:	f0 
f010246b:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102472:	f0 
f0102473:	c7 44 24 04 00 04 00 	movl   $0x400,0x4(%esp)
f010247a:	00 
f010247b:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102482:	e8 b9 db ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0102487:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010248a:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f010248f:	74 24                	je     f01024b5 <mem_init+0xfa4>
f0102491:	c7 44 24 0c d2 7b 10 	movl   $0xf0107bd2,0xc(%esp)
f0102498:	f0 
f0102499:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01024a0:	f0 
f01024a1:	c7 44 24 04 01 04 00 	movl   $0x401,0x4(%esp)
f01024a8:	00 
f01024a9:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01024b0:	e8 8b db ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f01024b5:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f01024ba:	74 24                	je     f01024e0 <mem_init+0xfcf>
f01024bc:	c7 44 24 0c 2c 7c 10 	movl   $0xf0107c2c,0xc(%esp)
f01024c3:	f0 
f01024c4:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01024cb:	f0 
f01024cc:	c7 44 24 04 02 04 00 	movl   $0x402,0x4(%esp)
f01024d3:	00 
f01024d4:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01024db:	e8 60 db ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
f01024e0:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01024e7:	00 
f01024e8:	89 34 24             	mov    %esi,(%esp)
f01024eb:	e8 17 ef ff ff       	call   f0101407 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01024f0:	8b 35 8c 4e 1c f0    	mov    0xf01c4e8c,%esi
f01024f6:	ba 00 00 00 00       	mov    $0x0,%edx
f01024fb:	89 f0                	mov    %esi,%eax
f01024fd:	e8 c2 e6 ff ff       	call   f0100bc4 <check_va2pa>
f0102502:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102505:	74 24                	je     f010252b <mem_init+0x101a>
f0102507:	c7 44 24 0c 6c 77 10 	movl   $0xf010776c,0xc(%esp)
f010250e:	f0 
f010250f:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102516:	f0 
f0102517:	c7 44 24 04 06 04 00 	movl   $0x406,0x4(%esp)
f010251e:	00 
f010251f:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102526:	e8 15 db ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
f010252b:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102530:	89 f0                	mov    %esi,%eax
f0102532:	e8 8d e6 ff ff       	call   f0100bc4 <check_va2pa>
f0102537:	83 f8 ff             	cmp    $0xffffffff,%eax
f010253a:	74 24                	je     f0102560 <mem_init+0x104f>
f010253c:	c7 44 24 0c 90 77 10 	movl   $0xf0107790,0xc(%esp)
f0102543:	f0 
f0102544:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010254b:	f0 
f010254c:	c7 44 24 04 07 04 00 	movl   $0x407,0x4(%esp)
f0102553:	00 
f0102554:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010255b:	e8 e0 da ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f0102560:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102563:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102568:	74 24                	je     f010258e <mem_init+0x107d>
f010256a:	c7 44 24 0c 3d 7c 10 	movl   $0xf0107c3d,0xc(%esp)
f0102571:	f0 
f0102572:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102579:	f0 
f010257a:	c7 44 24 04 08 04 00 	movl   $0x408,0x4(%esp)
f0102581:	00 
f0102582:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102589:	e8 b2 da ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f010258e:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f0102593:	74 24                	je     f01025b9 <mem_init+0x10a8>
f0102595:	c7 44 24 0c 2c 7c 10 	movl   $0xf0107c2c,0xc(%esp)
f010259c:	f0 
f010259d:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01025a4:	f0 
f01025a5:	c7 44 24 04 09 04 00 	movl   $0x409,0x4(%esp)
f01025ac:	00 
f01025ad:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01025b4:	e8 87 da ff ff       	call   f0100040 <_panic>

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);
f01025b9:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01025c0:	e8 51 eb ff ff       	call   f0101116 <page_alloc>
f01025c5:	85 c0                	test   %eax,%eax
f01025c7:	74 05                	je     f01025ce <mem_init+0x10bd>
f01025c9:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f01025cc:	74 24                	je     f01025f2 <mem_init+0x10e1>
f01025ce:	c7 44 24 0c b8 77 10 	movl   $0xf01077b8,0xc(%esp)
f01025d5:	f0 
f01025d6:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01025dd:	f0 
f01025de:	c7 44 24 04 0c 04 00 	movl   $0x40c,0x4(%esp)
f01025e5:	00 
f01025e6:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01025ed:	e8 4e da ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f01025f2:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01025f9:	e8 18 eb ff ff       	call   f0101116 <page_alloc>
f01025fe:	85 c0                	test   %eax,%eax
f0102600:	74 24                	je     f0102626 <mem_init+0x1115>
f0102602:	c7 44 24 0c 80 7b 10 	movl   $0xf0107b80,0xc(%esp)
f0102609:	f0 
f010260a:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102611:	f0 
f0102612:	c7 44 24 04 0f 04 00 	movl   $0x40f,0x4(%esp)
f0102619:	00 
f010261a:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102621:	e8 1a da ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102626:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f010262b:	8b 08                	mov    (%eax),%ecx
f010262d:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f0102633:	89 da                	mov    %ebx,%edx
f0102635:	2b 15 90 4e 1c f0    	sub    0xf01c4e90,%edx
f010263b:	c1 fa 03             	sar    $0x3,%edx
f010263e:	c1 e2 0c             	shl    $0xc,%edx
f0102641:	39 d1                	cmp    %edx,%ecx
f0102643:	74 24                	je     f0102669 <mem_init+0x1158>
f0102645:	c7 44 24 0c c8 74 10 	movl   $0xf01074c8,0xc(%esp)
f010264c:	f0 
f010264d:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102654:	f0 
f0102655:	c7 44 24 04 12 04 00 	movl   $0x412,0x4(%esp)
f010265c:	00 
f010265d:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102664:	e8 d7 d9 ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f0102669:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f010266f:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102674:	74 24                	je     f010269a <mem_init+0x1189>
f0102676:	c7 44 24 0c e3 7b 10 	movl   $0xf0107be3,0xc(%esp)
f010267d:	f0 
f010267e:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102685:	f0 
f0102686:	c7 44 24 04 14 04 00 	movl   $0x414,0x4(%esp)
f010268d:	00 
f010268e:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102695:	e8 a6 d9 ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f010269a:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// check pointer arithmetic in pgdir_walk
	page_free(pp0);
f01026a0:	89 1c 24             	mov    %ebx,(%esp)
f01026a3:	e8 f3 ea ff ff       	call   f010119b <page_free>
	va = (void*)(PGSIZE * NPDENTRIES + PGSIZE);
	ptep = pgdir_walk(kern_pgdir, va, 1);
f01026a8:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01026af:	00 
f01026b0:	c7 44 24 04 00 10 40 	movl   $0x401000,0x4(%esp)
f01026b7:	00 
f01026b8:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f01026bd:	89 04 24             	mov    %eax,(%esp)
f01026c0:	e8 0e eb ff ff       	call   f01011d3 <pgdir_walk>
f01026c5:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01026c8:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f01026cb:	8b 0d 8c 4e 1c f0    	mov    0xf01c4e8c,%ecx
f01026d1:	8b 51 04             	mov    0x4(%ecx),%edx
f01026d4:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01026da:	8b 35 88 4e 1c f0    	mov    0xf01c4e88,%esi
f01026e0:	89 d0                	mov    %edx,%eax
f01026e2:	c1 e8 0c             	shr    $0xc,%eax
f01026e5:	39 f0                	cmp    %esi,%eax
f01026e7:	72 20                	jb     f0102709 <mem_init+0x11f8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01026e9:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01026ed:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f01026f4:	f0 
f01026f5:	c7 44 24 04 1b 04 00 	movl   $0x41b,0x4(%esp)
f01026fc:	00 
f01026fd:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102704:	e8 37 d9 ff ff       	call   f0100040 <_panic>
	assert(ptep == ptep1 + PTX(va));
f0102709:	81 ea fc ff ff 0f    	sub    $0xffffffc,%edx
f010270f:	39 55 cc             	cmp    %edx,-0x34(%ebp)
f0102712:	74 24                	je     f0102738 <mem_init+0x1227>
f0102714:	c7 44 24 0c 4e 7c 10 	movl   $0xf0107c4e,0xc(%esp)
f010271b:	f0 
f010271c:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102723:	f0 
f0102724:	c7 44 24 04 1c 04 00 	movl   $0x41c,0x4(%esp)
f010272b:	00 
f010272c:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102733:	e8 08 d9 ff ff       	call   f0100040 <_panic>
	kern_pgdir[PDX(va)] = 0;
f0102738:	c7 41 04 00 00 00 00 	movl   $0x0,0x4(%ecx)
	pp0->pp_ref = 0;
f010273f:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102745:	89 d8                	mov    %ebx,%eax
f0102747:	2b 05 90 4e 1c f0    	sub    0xf01c4e90,%eax
f010274d:	c1 f8 03             	sar    $0x3,%eax
f0102750:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102753:	89 c2                	mov    %eax,%edx
f0102755:	c1 ea 0c             	shr    $0xc,%edx
f0102758:	39 d6                	cmp    %edx,%esi
f010275a:	77 20                	ja     f010277c <mem_init+0x126b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010275c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102760:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0102767:	f0 
f0102768:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010276f:	00 
f0102770:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f0102777:	e8 c4 d8 ff ff       	call   f0100040 <_panic>

	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
f010277c:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102783:	00 
f0102784:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
f010278b:	00 
	return (void *)(pa + KERNBASE);
f010278c:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102791:	89 04 24             	mov    %eax,(%esp)
f0102794:	e8 70 37 00 00       	call   f0105f09 <memset>
	page_free(pp0);
f0102799:	89 1c 24             	mov    %ebx,(%esp)
f010279c:	e8 fa e9 ff ff       	call   f010119b <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f01027a1:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01027a8:	00 
f01027a9:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01027b0:	00 
f01027b1:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f01027b6:	89 04 24             	mov    %eax,(%esp)
f01027b9:	e8 15 ea ff ff       	call   f01011d3 <pgdir_walk>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01027be:	89 da                	mov    %ebx,%edx
f01027c0:	2b 15 90 4e 1c f0    	sub    0xf01c4e90,%edx
f01027c6:	c1 fa 03             	sar    $0x3,%edx
f01027c9:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01027cc:	89 d0                	mov    %edx,%eax
f01027ce:	c1 e8 0c             	shr    $0xc,%eax
f01027d1:	3b 05 88 4e 1c f0    	cmp    0xf01c4e88,%eax
f01027d7:	72 20                	jb     f01027f9 <mem_init+0x12e8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01027d9:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01027dd:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f01027e4:	f0 
f01027e5:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01027ec:	00 
f01027ed:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f01027f4:	e8 47 d8 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01027f9:	8d 82 00 00 00 f0    	lea    -0x10000000(%edx),%eax
	ptep = (pte_t *) page2kva(pp0);
f01027ff:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	for(i=0; i<NPTENTRIES; i++)
		assert((ptep[i] & PTE_P) == 0);
f0102802:	f6 82 00 00 00 f0 01 	testb  $0x1,-0x10000000(%edx)
f0102809:	75 13                	jne    f010281e <mem_init+0x130d>
f010280b:	8d 82 04 00 00 f0    	lea    -0xffffffc(%edx),%eax
f0102811:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0102817:	8b 30                	mov    (%eax),%esi
f0102819:	83 e6 01             	and    $0x1,%esi
f010281c:	74 24                	je     f0102842 <mem_init+0x1331>
f010281e:	c7 44 24 0c 66 7c 10 	movl   $0xf0107c66,0xc(%esp)
f0102825:	f0 
f0102826:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010282d:	f0 
f010282e:	c7 44 24 04 26 04 00 	movl   $0x426,0x4(%esp)
f0102835:	00 
f0102836:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010283d:	e8 fe d7 ff ff       	call   f0100040 <_panic>
f0102842:	83 c0 04             	add    $0x4,%eax
	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
	page_free(pp0);
	pgdir_walk(kern_pgdir, 0x0, 1);
	ptep = (pte_t *) page2kva(pp0);
	for(i=0; i<NPTENTRIES; i++)
f0102845:	39 d0                	cmp    %edx,%eax
f0102847:	75 ce                	jne    f0102817 <mem_init+0x1306>
		assert((ptep[i] & PTE_P) == 0);
	kern_pgdir[0] = 0;
f0102849:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f010284e:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f0102854:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// give free list back
	page_free_list = fl;
f010285a:	8b 45 d0             	mov    -0x30(%ebp),%eax
f010285d:	a3 40 42 1c f0       	mov    %eax,0xf01c4240

	// free the pages we took
	page_free(pp0);
f0102862:	89 1c 24             	mov    %ebx,(%esp)
f0102865:	e8 31 e9 ff ff       	call   f010119b <page_free>
	page_free(pp1);
f010286a:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010286d:	89 04 24             	mov    %eax,(%esp)
f0102870:	e8 26 e9 ff ff       	call   f010119b <page_free>
	page_free(pp2);
f0102875:	89 3c 24             	mov    %edi,(%esp)
f0102878:	e8 1e e9 ff ff       	call   f010119b <page_free>

	cprintf("check_page() succeeded!\n");
f010287d:	c7 04 24 7d 7c 10 f0 	movl   $0xf0107c7d,(%esp)
f0102884:	e8 09 16 00 00       	call   f0103e92 <cprintf>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t to_map_pages;
	to_map_pages = (sizeof(struct Page) * npages - 1) / PGSIZE + 1;
f0102889:	a1 88 4e 1c f0       	mov    0xf01c4e88,%eax
f010288e:	8d 0c c5 ff ff ff ff 	lea    -0x1(,%eax,8),%ecx
f0102895:	c1 e9 0c             	shr    $0xc,%ecx
f0102898:	83 c1 01             	add    $0x1,%ecx
	boot_map_region(kern_pgdir, UPAGES, to_map_pages * PGSIZE, PADDR(pages), PTE_U | PTE_P);
f010289b:	a1 90 4e 1c f0       	mov    0xf01c4e90,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01028a0:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01028a5:	77 20                	ja     f01028c7 <mem_init+0x13b6>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01028a7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01028ab:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f01028b2:	f0 
f01028b3:	c7 44 24 04 be 00 00 	movl   $0xbe,0x4(%esp)
f01028ba:	00 
f01028bb:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01028c2:	e8 79 d7 ff ff       	call   f0100040 <_panic>
f01028c7:	c1 e1 0c             	shl    $0xc,%ecx
f01028ca:	c7 44 24 04 05 00 00 	movl   $0x5,0x4(%esp)
f01028d1:	00 
	return (physaddr_t)kva - KERNBASE;
f01028d2:	05 00 00 00 10       	add    $0x10000000,%eax
f01028d7:	89 04 24             	mov    %eax,(%esp)
f01028da:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f01028df:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f01028e4:	e8 f4 e9 ff ff       	call   f01012dd <boot_map_region>
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	size_t i;
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		page_insert(kern_pgdir,pa2page(PADDR(envs)+i),(void *)(UENVS + i),PTE_U| PTE_P);
f01028e9:	a1 48 42 1c f0       	mov    0xf01c4248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01028ee:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01028f3:	76 28                	jbe    f010291d <mem_init+0x140c>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f01028f5:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01028fa:	c1 e8 0c             	shr    $0xc,%eax
f01028fd:	3b 05 88 4e 1c f0    	cmp    0xf01c4e88,%eax
f0102903:	0f 82 ec 0a 00 00    	jb     f01033f5 <mem_init+0x1ee4>
f0102909:	eb 44                	jmp    f010294f <mem_init+0x143e>
f010290b:	8d 93 00 00 c0 ee    	lea    -0x11400000(%ebx),%edx
f0102911:	a1 48 42 1c f0       	mov    0xf01c4248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102916:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010291b:	77 20                	ja     f010293d <mem_init+0x142c>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010291d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102921:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0102928:	f0 
f0102929:	c7 44 24 04 c9 00 00 	movl   $0xc9,0x4(%esp)
f0102930:	00 
f0102931:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102938:	e8 03 d7 ff ff       	call   f0100040 <_panic>
f010293d:	8d 84 18 00 00 00 10 	lea    0x10000000(%eax,%ebx,1),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102944:	c1 e8 0c             	shr    $0xc,%eax
f0102947:	3b 05 88 4e 1c f0    	cmp    0xf01c4e88,%eax
f010294d:	72 1c                	jb     f010296b <mem_init+0x145a>
		panic("pa2page called with invalid pa");
f010294f:	c7 44 24 08 94 73 10 	movl   $0xf0107394,0x8(%esp)
f0102956:	f0 
f0102957:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010295e:	00 
f010295f:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f0102966:	e8 d5 d6 ff ff       	call   f0100040 <_panic>
f010296b:	c7 44 24 0c 05 00 00 	movl   $0x5,0xc(%esp)
f0102972:	00 
f0102973:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102977:	8b 15 90 4e 1c f0    	mov    0xf01c4e90,%edx
f010297d:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102980:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102984:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f0102989:	89 04 24             	mov    %eax,(%esp)
f010298c:	e8 bf ea ff ff       	call   f0101450 <page_insert>
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	size_t i;
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f0102991:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102997:	81 fb 00 f0 01 00    	cmp    $0x1f000,%ebx
f010299d:	0f 85 68 ff ff ff    	jne    f010290b <mem_init+0x13fa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01029a3:	bb 00 70 11 f0       	mov    $0xf0117000,%ebx
f01029a8:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f01029ae:	76 28                	jbe    f01029d8 <mem_init+0x14c7>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f01029b0:	b8 00 70 11 00       	mov    $0x117000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01029b5:	c1 e8 0c             	shr    $0xc,%eax
f01029b8:	3b 05 88 4e 1c f0    	cmp    0xf01c4e88,%eax
f01029be:	0f 82 f4 09 00 00    	jb     f01033b8 <mem_init+0x1ea7>
f01029c4:	eb 36                	jmp    f01029fc <mem_init+0x14eb>
f01029c6:	8d 14 3b             	lea    (%ebx,%edi,1),%edx
f01029c9:	89 f8                	mov    %edi,%eax
f01029cb:	c1 e8 0c             	shr    $0xc,%eax
f01029ce:	3b 05 88 4e 1c f0    	cmp    0xf01c4e88,%eax
f01029d4:	72 42                	jb     f0102a18 <mem_init+0x1507>
f01029d6:	eb 24                	jmp    f01029fc <mem_init+0x14eb>

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01029d8:	c7 44 24 0c 00 70 11 	movl   $0xf0117000,0xc(%esp)
f01029df:	f0 
f01029e0:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f01029e7:	f0 
f01029e8:	c7 44 24 04 d6 00 00 	movl   $0xd6,0x4(%esp)
f01029ef:	00 
f01029f0:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01029f7:	e8 44 d6 ff ff       	call   f0100040 <_panic>

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
f01029fc:	c7 44 24 08 94 73 10 	movl   $0xf0107394,0x8(%esp)
f0102a03:	f0 
f0102a04:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102a0b:	00 
f0102a0c:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f0102a13:	e8 28 d6 ff ff       	call   f0100040 <_panic>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		page_insert(kern_pgdir, pa2page(PADDR(bootstack) + i), (void *)(KSTACKTOP-KSTKSIZE + i), PTE_W| PTE_P);
f0102a18:	c7 44 24 0c 03 00 00 	movl   $0x3,0xc(%esp)
f0102a1f:	00 
f0102a20:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102a24:	8b 15 90 4e 1c f0    	mov    0xf01c4e90,%edx
f0102a2a:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102a2d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102a31:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f0102a36:	89 04 24             	mov    %eax,(%esp)
f0102a39:	e8 12 ea ff ff       	call   f0101450 <page_insert>
f0102a3e:	81 c7 00 10 00 00    	add    $0x1000,%edi
	//     * [KSTACKTOP-PTSIZE, KSTACKTOP-KSTKSIZE) -- not backed; so if
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102a44:	81 ff 00 f0 11 00    	cmp    $0x11f000,%edi
f0102a4a:	0f 85 76 ff ff ff    	jne    f01029c6 <mem_init+0x14b5>
f0102a50:	e9 0e 09 00 00       	jmp    f0103363 <mem_init+0x1e52>
f0102a55:	8d bb 00 10 00 f0    	lea    -0xffff000(%ebx),%edi
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W| PTE_P);
f0102a5b:	8b 1d 88 4e 1c f0    	mov    0xf01c4e88,%ebx
f0102a61:	89 de                	mov    %ebx,%esi
f0102a63:	c1 e6 0c             	shl    $0xc,%esi
f0102a66:	89 c8                	mov    %ecx,%eax
f0102a68:	ba 00 00 00 00       	mov    $0x0,%edx
f0102a6d:	f7 f6                	div    %esi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102a6f:	c1 ea 0c             	shr    $0xc,%edx
f0102a72:	39 d3                	cmp    %edx,%ebx
f0102a74:	77 1c                	ja     f0102a92 <mem_init+0x1581>
		panic("pa2page called with invalid pa");
f0102a76:	c7 44 24 08 94 73 10 	movl   $0xf0107394,0x8(%esp)
f0102a7d:	f0 
f0102a7e:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102a85:	00 
f0102a86:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f0102a8d:	e8 ae d5 ff ff       	call   f0100040 <_panic>
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
f0102a92:	89 cb                	mov    %ecx,%ebx
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W| PTE_P);
f0102a94:	c7 44 24 0c 03 00 00 	movl   $0x3,0xc(%esp)
f0102a9b:	00 
f0102a9c:	89 7c 24 08          	mov    %edi,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102aa0:	a1 90 4e 1c f0       	mov    0xf01c4e90,%eax
f0102aa5:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f0102aa8:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102aac:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f0102ab1:	89 04 24             	mov    %eax,(%esp)
f0102ab4:	e8 97 e9 ff ff       	call   f0101450 <page_insert>
		pa2page(i % (npages*PGSIZE))->pp_ref--;                 //this statement is to keep pp_ref == 0 in page_free_list
f0102ab9:	8b 0d 88 4e 1c f0    	mov    0xf01c4e88,%ecx
f0102abf:	89 ce                	mov    %ecx,%esi
f0102ac1:	c1 e6 0c             	shl    $0xc,%esi
f0102ac4:	89 d8                	mov    %ebx,%eax
f0102ac6:	ba 00 00 00 00       	mov    $0x0,%edx
f0102acb:	f7 f6                	div    %esi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102acd:	c1 ea 0c             	shr    $0xc,%edx
f0102ad0:	39 d1                	cmp    %edx,%ecx
f0102ad2:	77 1c                	ja     f0102af0 <mem_init+0x15df>
		panic("pa2page called with invalid pa");
f0102ad4:	c7 44 24 08 94 73 10 	movl   $0xf0107394,0x8(%esp)
f0102adb:	f0 
f0102adc:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102ae3:	00 
f0102ae4:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f0102aeb:	e8 50 d5 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0102af0:	a1 90 4e 1c f0       	mov    0xf01c4e90,%eax
f0102af5:	66 83 6c d0 04 01    	subw   $0x1,0x4(%eax,%edx,8)
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
f0102afb:	8d 8b 00 10 00 00    	lea    0x1000(%ebx),%ecx
f0102b01:	81 f9 00 00 00 10    	cmp    $0x10000000,%ecx
f0102b07:	0f 85 48 ff ff ff    	jne    f0102a55 <mem_init+0x1544>
static void
mem_init_mp(void)
{
	// Create a direct mapping at the top of virtual address space starting
	// at IOMEMBASE for accessing the LAPIC unit using memory-mapped I/O.
	boot_map_region(kern_pgdir, IOMEMBASE, -IOMEMBASE, IOMEM_PADDR, PTE_W);
f0102b0d:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102b14:	00 
f0102b15:	c7 04 24 00 00 00 fe 	movl   $0xfe000000,(%esp)
f0102b1c:	b9 00 00 00 02       	mov    $0x2000000,%ecx
f0102b21:	ba 00 00 00 fe       	mov    $0xfe000000,%edx
f0102b26:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f0102b2b:	e8 ad e7 ff ff       	call   f01012dd <boot_map_region>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102b30:	b8 00 60 1c f0       	mov    $0xf01c6000,%eax
f0102b35:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102b3a:	0f 87 41 08 00 00    	ja     f0103381 <mem_init+0x1e70>
f0102b40:	eb 0c                	jmp    f0102b4e <mem_init+0x163d>
	physaddr_t cpu_phystk_i;
	uintptr_t cpu_vastk_i;
	size_t va;
	for(i = 0 ; i<NCPU ;i++){
		cpu_vastk_i = KSTACKTOP - i* (KSTKSIZE + KSTKGAP)-KSTKSIZE;
		cpu_phystk_i = PADDR(percpu_kstacks[i]);
f0102b42:	89 d8                	mov    %ebx,%eax
f0102b44:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102b4a:	77 27                	ja     f0102b73 <mem_init+0x1662>
f0102b4c:	eb 05                	jmp    f0102b53 <mem_init+0x1642>
f0102b4e:	b8 00 60 1c f0       	mov    $0xf01c6000,%eax
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102b53:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102b57:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0102b5e:	f0 
f0102b5f:	c7 44 24 04 24 01 00 	movl   $0x124,0x4(%esp)
f0102b66:	00 
f0102b67:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102b6e:	e8 cd d4 ff ff       	call   f0100040 <_panic>
		boot_map_region(kern_pgdir,cpu_vastk_i,KSTKSIZE,cpu_phystk_i,PTE_W);
f0102b73:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102b7a:	00 
f0102b7b:	8d 83 00 00 00 10    	lea    0x10000000(%ebx),%eax
f0102b81:	89 04 24             	mov    %eax,(%esp)
f0102b84:	b9 00 80 00 00       	mov    $0x8000,%ecx
f0102b89:	89 f2                	mov    %esi,%edx
f0102b8b:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f0102b90:	e8 48 e7 ff ff       	call   f01012dd <boot_map_region>
f0102b95:	81 c3 00 80 00 00    	add    $0x8000,%ebx
f0102b9b:	81 ee 00 00 01 00    	sub    $0x10000,%esi
	// LAB 4: Your code here:
	int i;
	physaddr_t cpu_phystk_i;
	uintptr_t cpu_vastk_i;
	size_t va;
	for(i = 0 ; i<NCPU ;i++){
f0102ba1:	39 fb                	cmp    %edi,%ebx
f0102ba3:	75 9d                	jne    f0102b42 <mem_init+0x1631>
check_kern_pgdir(void)
{
	uint32_t i, n;
	pde_t *pgdir;

	pgdir = kern_pgdir;
f0102ba5:	8b 3d 8c 4e 1c f0    	mov    0xf01c4e8c,%edi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
f0102bab:	a1 88 4e 1c f0       	mov    0xf01c4e88,%eax
f0102bb0:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0102bb3:	8d 04 c5 ff 0f 00 00 	lea    0xfff(,%eax,8),%eax
	for (i = 0; i < n; i += PGSIZE)
f0102bba:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102bbf:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0102bc2:	75 30                	jne    f0102bf4 <mem_init+0x16e3>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102bc4:	8b 1d 48 42 1c f0    	mov    0xf01c4248,%ebx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102bca:	89 de                	mov    %ebx,%esi
f0102bcc:	ba 00 00 c0 ee       	mov    $0xeec00000,%edx
f0102bd1:	89 f8                	mov    %edi,%eax
f0102bd3:	e8 ec df ff ff       	call   f0100bc4 <check_va2pa>
f0102bd8:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102bde:	0f 86 94 00 00 00    	jbe    f0102c78 <mem_init+0x1767>
f0102be4:	bb 00 00 c0 ee       	mov    $0xeec00000,%ebx
f0102be9:	81 c6 00 00 40 21    	add    $0x21400000,%esi
f0102bef:	e9 a4 00 00 00       	jmp    f0102c98 <mem_init+0x1787>
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102bf4:	8b 1d 90 4e 1c f0    	mov    0xf01c4e90,%ebx
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102bfa:	8d b3 00 00 00 10    	lea    0x10000000(%ebx),%esi
f0102c00:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f0102c05:	89 f8                	mov    %edi,%eax
f0102c07:	e8 b8 df ff ff       	call   f0100bc4 <check_va2pa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102c0c:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102c12:	77 20                	ja     f0102c34 <mem_init+0x1723>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102c14:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102c18:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0102c1f:	f0 
f0102c20:	c7 44 24 04 63 03 00 	movl   $0x363,0x4(%esp)
f0102c27:	00 
f0102c28:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102c2f:	e8 0c d4 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102c34:	ba 00 00 00 00       	mov    $0x0,%edx
f0102c39:	8d 0c 16             	lea    (%esi,%edx,1),%ecx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102c3c:	39 c8                	cmp    %ecx,%eax
f0102c3e:	74 24                	je     f0102c64 <mem_init+0x1753>
f0102c40:	c7 44 24 0c dc 77 10 	movl   $0xf01077dc,0xc(%esp)
f0102c47:	f0 
f0102c48:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102c4f:	f0 
f0102c50:	c7 44 24 04 63 03 00 	movl   $0x363,0x4(%esp)
f0102c57:	00 
f0102c58:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102c5f:	e8 dc d3 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102c64:	8d 9a 00 10 00 00    	lea    0x1000(%edx),%ebx
f0102c6a:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f0102c6d:	0f 87 d2 07 00 00    	ja     f0103445 <mem_init+0x1f34>
f0102c73:	e9 4c ff ff ff       	jmp    f0102bc4 <mem_init+0x16b3>
f0102c78:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102c7c:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0102c83:	f0 
f0102c84:	c7 44 24 04 68 03 00 	movl   $0x368,0x4(%esp)
f0102c8b:	00 
f0102c8c:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102c93:	e8 a8 d3 ff ff       	call   f0100040 <_panic>
f0102c98:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102c9b:	39 c2                	cmp    %eax,%edx
f0102c9d:	74 24                	je     f0102cc3 <mem_init+0x17b2>
f0102c9f:	c7 44 24 0c 10 78 10 	movl   $0xf0107810,0xc(%esp)
f0102ca6:	f0 
f0102ca7:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102cae:	f0 
f0102caf:	c7 44 24 04 68 03 00 	movl   $0x368,0x4(%esp)
f0102cb6:	00 
f0102cb7:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102cbe:	e8 7d d3 ff ff       	call   f0100040 <_panic>
f0102cc3:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102cc9:	81 fb 00 f0 c1 ee    	cmp    $0xeec1f000,%ebx
f0102ccf:	0f 85 62 07 00 00    	jne    f0103437 <mem_init+0x1f26>
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102cd5:	8b 75 d0             	mov    -0x30(%ebp),%esi
f0102cd8:	c1 e6 0c             	shl    $0xc,%esi
f0102cdb:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102ce0:	85 f6                	test   %esi,%esi
f0102ce2:	75 07                	jne    f0102ceb <mem_init+0x17da>
f0102ce4:	bb 00 00 00 fe       	mov    $0xfe000000,%ebx
f0102ce9:	eb 41                	jmp    f0102d2c <mem_init+0x181b>
f0102ceb:	8d 93 00 00 00 f0    	lea    -0x10000000(%ebx),%edx
		assert(check_va2pa(pgdir, KERNBASE + i) == i);
f0102cf1:	89 f8                	mov    %edi,%eax
f0102cf3:	e8 cc de ff ff       	call   f0100bc4 <check_va2pa>
f0102cf8:	39 c3                	cmp    %eax,%ebx
f0102cfa:	74 24                	je     f0102d20 <mem_init+0x180f>
f0102cfc:	c7 44 24 0c 44 78 10 	movl   $0xf0107844,0xc(%esp)
f0102d03:	f0 
f0102d04:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102d0b:	f0 
f0102d0c:	c7 44 24 04 6c 03 00 	movl   $0x36c,0x4(%esp)
f0102d13:	00 
f0102d14:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102d1b:	e8 20 d3 ff ff       	call   f0100040 <_panic>
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102d20:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102d26:	39 f3                	cmp    %esi,%ebx
f0102d28:	72 c1                	jb     f0102ceb <mem_init+0x17da>
f0102d2a:	eb b8                	jmp    f0102ce4 <mem_init+0x17d3>
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);
f0102d2c:	89 da                	mov    %ebx,%edx
f0102d2e:	89 f8                	mov    %edi,%eax
f0102d30:	e8 8f de ff ff       	call   f0100bc4 <check_va2pa>
f0102d35:	39 c3                	cmp    %eax,%ebx
f0102d37:	74 24                	je     f0102d5d <mem_init+0x184c>
f0102d39:	c7 44 24 0c 96 7c 10 	movl   $0xf0107c96,0xc(%esp)
f0102d40:	f0 
f0102d41:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102d48:	f0 
f0102d49:	c7 44 24 04 70 03 00 	movl   $0x370,0x4(%esp)
f0102d50:	00 
f0102d51:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102d58:	e8 e3 d2 ff ff       	call   f0100040 <_panic>
	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
f0102d5d:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102d63:	81 fb 00 f0 ff ff    	cmp    $0xfffff000,%ebx
f0102d69:	75 c1                	jne    f0102d2c <mem_init+0x181b>
f0102d6b:	c7 45 d0 00 60 1c f0 	movl   $0xf01c6000,-0x30(%ebp)
f0102d72:	c7 45 cc 00 00 00 00 	movl   $0x0,-0x34(%ebp)
f0102d79:	be 00 80 bf ef       	mov    $0xefbf8000,%esi
f0102d7e:	b8 00 60 1c f0       	mov    $0xf01c6000,%eax
f0102d83:	05 00 80 40 20       	add    $0x20408000,%eax
f0102d88:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0102d8b:	8d 86 00 80 00 00    	lea    0x8000(%esi),%eax
f0102d91:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0102d94:	89 f2                	mov    %esi,%edx
f0102d96:	89 f8                	mov    %edi,%eax
f0102d98:	e8 27 de ff ff       	call   f0100bc4 <check_va2pa>
f0102d9d:	8b 4d d0             	mov    -0x30(%ebp),%ecx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102da0:	81 f9 ff ff ff ef    	cmp    $0xefffffff,%ecx
f0102da6:	77 20                	ja     f0102dc8 <mem_init+0x18b7>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102da8:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0102dac:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0102db3:	f0 
f0102db4:	c7 44 24 04 78 03 00 	movl   $0x378,0x4(%esp)
f0102dbb:	00 
f0102dbc:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102dc3:	e8 78 d2 ff ff       	call   f0100040 <_panic>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102dc8:	89 f3                	mov    %esi,%ebx
f0102dca:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0102dcd:	03 4d c4             	add    -0x3c(%ebp),%ecx
f0102dd0:	89 75 c8             	mov    %esi,-0x38(%ebp)
f0102dd3:	89 ce                	mov    %ecx,%esi
f0102dd5:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
f0102dd8:	39 c2                	cmp    %eax,%edx
f0102dda:	74 24                	je     f0102e00 <mem_init+0x18ef>
f0102ddc:	c7 44 24 0c 6c 78 10 	movl   $0xf010786c,0xc(%esp)
f0102de3:	f0 
f0102de4:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102deb:	f0 
f0102dec:	c7 44 24 04 78 03 00 	movl   $0x378,0x4(%esp)
f0102df3:	00 
f0102df4:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102dfb:	e8 40 d2 ff ff       	call   f0100040 <_panic>
f0102e00:	81 c3 00 10 00 00    	add    $0x1000,%ebx

	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102e06:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0102e09:	0f 85 1a 06 00 00    	jne    f0103429 <mem_init+0x1f18>
f0102e0f:	8b 75 c8             	mov    -0x38(%ebp),%esi
f0102e12:	8d 9e 00 80 ff ff    	lea    -0x8000(%esi),%ebx
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
f0102e18:	89 da                	mov    %ebx,%edx
f0102e1a:	89 f8                	mov    %edi,%eax
f0102e1c:	e8 a3 dd ff ff       	call   f0100bc4 <check_va2pa>
f0102e21:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102e24:	74 24                	je     f0102e4a <mem_init+0x1939>
f0102e26:	c7 44 24 0c b4 78 10 	movl   $0xf01078b4,0xc(%esp)
f0102e2d:	f0 
f0102e2e:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102e35:	f0 
f0102e36:	c7 44 24 04 7a 03 00 	movl   $0x37a,0x4(%esp)
f0102e3d:	00 
f0102e3e:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102e45:	e8 f6 d1 ff ff       	call   f0100040 <_panic>
f0102e4a:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
f0102e50:	39 f3                	cmp    %esi,%ebx
f0102e52:	75 c4                	jne    f0102e18 <mem_init+0x1907>
f0102e54:	81 ee 00 00 01 00    	sub    $0x10000,%esi
f0102e5a:	81 45 cc 00 80 01 00 	addl   $0x18000,-0x34(%ebp)
f0102e61:	81 45 d0 00 80 00 00 	addl   $0x8000,-0x30(%ebp)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);

	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
f0102e68:	81 fe 00 80 b7 ef    	cmp    $0xefb78000,%esi
f0102e6e:	0f 85 17 ff ff ff    	jne    f0102d8b <mem_init+0x187a>
f0102e74:	b8 00 00 00 00       	mov    $0x0,%eax
			assert(check_va2pa(pgdir, base + i) == ~0);
	}

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
		switch (i) {
f0102e79:	8d 90 45 fc ff ff    	lea    -0x3bb(%eax),%edx
f0102e7f:	83 fa 03             	cmp    $0x3,%edx
f0102e82:	77 2e                	ja     f0102eb2 <mem_init+0x19a1>
		case PDX(UVPT):
		case PDX(KSTACKTOP-1):
		case PDX(UPAGES):
		case PDX(UENVS):
			assert(pgdir[i] & PTE_P);
f0102e84:	f6 04 87 01          	testb  $0x1,(%edi,%eax,4)
f0102e88:	0f 85 aa 00 00 00    	jne    f0102f38 <mem_init+0x1a27>
f0102e8e:	c7 44 24 0c b1 7c 10 	movl   $0xf0107cb1,0xc(%esp)
f0102e95:	f0 
f0102e96:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102e9d:	f0 
f0102e9e:	c7 44 24 04 84 03 00 	movl   $0x384,0x4(%esp)
f0102ea5:	00 
f0102ea6:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102ead:	e8 8e d1 ff ff       	call   f0100040 <_panic>
			break;
		default:
			if (i >= PDX(KERNBASE)) {
f0102eb2:	3d bf 03 00 00       	cmp    $0x3bf,%eax
f0102eb7:	76 55                	jbe    f0102f0e <mem_init+0x19fd>
				assert(pgdir[i] & PTE_P);
f0102eb9:	8b 14 87             	mov    (%edi,%eax,4),%edx
f0102ebc:	f6 c2 01             	test   $0x1,%dl
f0102ebf:	75 24                	jne    f0102ee5 <mem_init+0x19d4>
f0102ec1:	c7 44 24 0c b1 7c 10 	movl   $0xf0107cb1,0xc(%esp)
f0102ec8:	f0 
f0102ec9:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102ed0:	f0 
f0102ed1:	c7 44 24 04 88 03 00 	movl   $0x388,0x4(%esp)
f0102ed8:	00 
f0102ed9:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102ee0:	e8 5b d1 ff ff       	call   f0100040 <_panic>
				assert(pgdir[i] & PTE_W);
f0102ee5:	f6 c2 02             	test   $0x2,%dl
f0102ee8:	75 4e                	jne    f0102f38 <mem_init+0x1a27>
f0102eea:	c7 44 24 0c c2 7c 10 	movl   $0xf0107cc2,0xc(%esp)
f0102ef1:	f0 
f0102ef2:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102ef9:	f0 
f0102efa:	c7 44 24 04 89 03 00 	movl   $0x389,0x4(%esp)
f0102f01:	00 
f0102f02:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102f09:	e8 32 d1 ff ff       	call   f0100040 <_panic>
			} else
				assert(pgdir[i] == 0);
f0102f0e:	83 3c 87 00          	cmpl   $0x0,(%edi,%eax,4)
f0102f12:	74 24                	je     f0102f38 <mem_init+0x1a27>
f0102f14:	c7 44 24 0c d3 7c 10 	movl   $0xf0107cd3,0xc(%esp)
f0102f1b:	f0 
f0102f1c:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102f23:	f0 
f0102f24:	c7 44 24 04 8b 03 00 	movl   $0x38b,0x4(%esp)
f0102f2b:	00 
f0102f2c:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102f33:	e8 08 d1 ff ff       	call   f0100040 <_panic>
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
	}

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
f0102f38:	83 c0 01             	add    $0x1,%eax
f0102f3b:	3d 00 04 00 00       	cmp    $0x400,%eax
f0102f40:	0f 85 33 ff ff ff    	jne    f0102e79 <mem_init+0x1968>
			} else
				assert(pgdir[i] == 0);
			break;
		}
	}
	cprintf("check_kern_pgdir() succeeded!\n");
f0102f46:	c7 04 24 d8 78 10 f0 	movl   $0xf01078d8,(%esp)
f0102f4d:	e8 40 0f 00 00       	call   f0103e92 <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f0102f52:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f0102f57:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102f5c:	77 20                	ja     f0102f7e <mem_init+0x1a6d>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102f5e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102f62:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0102f69:	f0 
f0102f6a:	c7 44 24 04 f6 00 00 	movl   $0xf6,0x4(%esp)
f0102f71:	00 
f0102f72:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102f79:	e8 c2 d0 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0102f7e:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0102f83:	0f 22 d8             	mov    %eax,%cr3
	check_page_free_list(0);
f0102f86:	b8 00 00 00 00       	mov    $0x0,%eax
f0102f8b:	e8 a3 dc ff ff       	call   f0100c33 <check_page_free_list>

static __inline uint32_t
rcr0(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr0,%0" : "=r" (val));
f0102f90:	0f 20 c0             	mov    %cr0,%eax
	// entry.S set the really important flags in cr0 (including enabling
	// paging).  Here we configure the rest of the flags that we care about.
	cr0 = rcr0();
	cr0 |= CR0_PE|CR0_PG|CR0_AM|CR0_WP|CR0_NE|CR0_MP;
	cr0 &= ~(CR0_TS|CR0_EM);
f0102f93:	83 e0 f3             	and    $0xfffffff3,%eax
f0102f96:	0d 23 00 05 80       	or     $0x80050023,%eax
}

static __inline void
lcr0(uint32_t val)
{
	__asm __volatile("movl %0,%%cr0" : : "r" (val));
f0102f9b:	0f 22 c0             	mov    %eax,%cr0
	uintptr_t va;
	int i;

	// check that we can read and write installed pages
	pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0102f9e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102fa5:	e8 6c e1 ff ff       	call   f0101116 <page_alloc>
f0102faa:	89 c3                	mov    %eax,%ebx
f0102fac:	85 c0                	test   %eax,%eax
f0102fae:	75 24                	jne    f0102fd4 <mem_init+0x1ac3>
f0102fb0:	c7 44 24 0c d5 7a 10 	movl   $0xf0107ad5,0xc(%esp)
f0102fb7:	f0 
f0102fb8:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102fbf:	f0 
f0102fc0:	c7 44 24 04 41 04 00 	movl   $0x441,0x4(%esp)
f0102fc7:	00 
f0102fc8:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102fcf:	e8 6c d0 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0102fd4:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102fdb:	e8 36 e1 ff ff       	call   f0101116 <page_alloc>
f0102fe0:	89 c7                	mov    %eax,%edi
f0102fe2:	85 c0                	test   %eax,%eax
f0102fe4:	75 24                	jne    f010300a <mem_init+0x1af9>
f0102fe6:	c7 44 24 0c eb 7a 10 	movl   $0xf0107aeb,0xc(%esp)
f0102fed:	f0 
f0102fee:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102ff5:	f0 
f0102ff6:	c7 44 24 04 42 04 00 	movl   $0x442,0x4(%esp)
f0102ffd:	00 
f0102ffe:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0103005:	e8 36 d0 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f010300a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0103011:	e8 00 e1 ff ff       	call   f0101116 <page_alloc>
f0103016:	89 c6                	mov    %eax,%esi
f0103018:	85 c0                	test   %eax,%eax
f010301a:	75 24                	jne    f0103040 <mem_init+0x1b2f>
f010301c:	c7 44 24 0c 01 7b 10 	movl   $0xf0107b01,0xc(%esp)
f0103023:	f0 
f0103024:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010302b:	f0 
f010302c:	c7 44 24 04 43 04 00 	movl   $0x443,0x4(%esp)
f0103033:	00 
f0103034:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010303b:	e8 00 d0 ff ff       	call   f0100040 <_panic>
	page_free(pp0);
f0103040:	89 1c 24             	mov    %ebx,(%esp)
f0103043:	e8 53 e1 ff ff       	call   f010119b <page_free>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103048:	89 f8                	mov    %edi,%eax
f010304a:	2b 05 90 4e 1c f0    	sub    0xf01c4e90,%eax
f0103050:	c1 f8 03             	sar    $0x3,%eax
f0103053:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103056:	89 c2                	mov    %eax,%edx
f0103058:	c1 ea 0c             	shr    $0xc,%edx
f010305b:	3b 15 88 4e 1c f0    	cmp    0xf01c4e88,%edx
f0103061:	72 20                	jb     f0103083 <mem_init+0x1b72>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103063:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103067:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f010306e:	f0 
f010306f:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103076:	00 
f0103077:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f010307e:	e8 bd cf ff ff       	call   f0100040 <_panic>
	memset(page2kva(pp1), 1, PGSIZE);
f0103083:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010308a:	00 
f010308b:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f0103092:	00 
	return (void *)(pa + KERNBASE);
f0103093:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0103098:	89 04 24             	mov    %eax,(%esp)
f010309b:	e8 69 2e 00 00       	call   f0105f09 <memset>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01030a0:	89 f0                	mov    %esi,%eax
f01030a2:	2b 05 90 4e 1c f0    	sub    0xf01c4e90,%eax
f01030a8:	c1 f8 03             	sar    $0x3,%eax
f01030ab:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01030ae:	89 c2                	mov    %eax,%edx
f01030b0:	c1 ea 0c             	shr    $0xc,%edx
f01030b3:	3b 15 88 4e 1c f0    	cmp    0xf01c4e88,%edx
f01030b9:	72 20                	jb     f01030db <mem_init+0x1bca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01030bb:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01030bf:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f01030c6:	f0 
f01030c7:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01030ce:	00 
f01030cf:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f01030d6:	e8 65 cf ff ff       	call   f0100040 <_panic>
	memset(page2kva(pp2), 2, PGSIZE);
f01030db:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01030e2:	00 
f01030e3:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f01030ea:	00 
	return (void *)(pa + KERNBASE);
f01030eb:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01030f0:	89 04 24             	mov    %eax,(%esp)
f01030f3:	e8 11 2e 00 00       	call   f0105f09 <memset>
	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f01030f8:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01030ff:	00 
f0103100:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0103107:	00 
f0103108:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010310c:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f0103111:	89 04 24             	mov    %eax,(%esp)
f0103114:	e8 37 e3 ff ff       	call   f0101450 <page_insert>
	assert(pp1->pp_ref == 1);
f0103119:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f010311e:	74 24                	je     f0103144 <mem_init+0x1c33>
f0103120:	c7 44 24 0c d2 7b 10 	movl   $0xf0107bd2,0xc(%esp)
f0103127:	f0 
f0103128:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010312f:	f0 
f0103130:	c7 44 24 04 48 04 00 	movl   $0x448,0x4(%esp)
f0103137:	00 
f0103138:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010313f:	e8 fc ce ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
f0103144:	81 3d 00 10 00 00 01 	cmpl   $0x1010101,0x1000
f010314b:	01 01 01 
f010314e:	74 24                	je     f0103174 <mem_init+0x1c63>
f0103150:	c7 44 24 0c f8 78 10 	movl   $0xf01078f8,0xc(%esp)
f0103157:	f0 
f0103158:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010315f:	f0 
f0103160:	c7 44 24 04 49 04 00 	movl   $0x449,0x4(%esp)
f0103167:	00 
f0103168:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010316f:	e8 cc ce ff ff       	call   f0100040 <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f0103174:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f010317b:	00 
f010317c:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0103183:	00 
f0103184:	89 74 24 04          	mov    %esi,0x4(%esp)
f0103188:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f010318d:	89 04 24             	mov    %eax,(%esp)
f0103190:	e8 bb e2 ff ff       	call   f0101450 <page_insert>
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
f0103195:	81 3d 00 10 00 00 02 	cmpl   $0x2020202,0x1000
f010319c:	02 02 02 
f010319f:	74 24                	je     f01031c5 <mem_init+0x1cb4>
f01031a1:	c7 44 24 0c 1c 79 10 	movl   $0xf010791c,0xc(%esp)
f01031a8:	f0 
f01031a9:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01031b0:	f0 
f01031b1:	c7 44 24 04 4b 04 00 	movl   $0x44b,0x4(%esp)
f01031b8:	00 
f01031b9:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01031c0:	e8 7b ce ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f01031c5:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f01031ca:	74 24                	je     f01031f0 <mem_init+0x1cdf>
f01031cc:	c7 44 24 0c f4 7b 10 	movl   $0xf0107bf4,0xc(%esp)
f01031d3:	f0 
f01031d4:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01031db:	f0 
f01031dc:	c7 44 24 04 4c 04 00 	movl   $0x44c,0x4(%esp)
f01031e3:	00 
f01031e4:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01031eb:	e8 50 ce ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f01031f0:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f01031f5:	74 24                	je     f010321b <mem_init+0x1d0a>
f01031f7:	c7 44 24 0c 3d 7c 10 	movl   $0xf0107c3d,0xc(%esp)
f01031fe:	f0 
f01031ff:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0103206:	f0 
f0103207:	c7 44 24 04 4d 04 00 	movl   $0x44d,0x4(%esp)
f010320e:	00 
f010320f:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0103216:	e8 25 ce ff ff       	call   f0100040 <_panic>
	*(uint32_t *)PGSIZE = 0x03030303U;
f010321b:	c7 05 00 10 00 00 03 	movl   $0x3030303,0x1000
f0103222:	03 03 03 
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103225:	89 f0                	mov    %esi,%eax
f0103227:	2b 05 90 4e 1c f0    	sub    0xf01c4e90,%eax
f010322d:	c1 f8 03             	sar    $0x3,%eax
f0103230:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103233:	89 c2                	mov    %eax,%edx
f0103235:	c1 ea 0c             	shr    $0xc,%edx
f0103238:	3b 15 88 4e 1c f0    	cmp    0xf01c4e88,%edx
f010323e:	72 20                	jb     f0103260 <mem_init+0x1d4f>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103240:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103244:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f010324b:	f0 
f010324c:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103253:	00 
f0103254:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f010325b:	e8 e0 cd ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
f0103260:	81 b8 00 00 00 f0 03 	cmpl   $0x3030303,-0x10000000(%eax)
f0103267:	03 03 03 
f010326a:	74 24                	je     f0103290 <mem_init+0x1d7f>
f010326c:	c7 44 24 0c 40 79 10 	movl   $0xf0107940,0xc(%esp)
f0103273:	f0 
f0103274:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010327b:	f0 
f010327c:	c7 44 24 04 4f 04 00 	movl   $0x44f,0x4(%esp)
f0103283:	00 
f0103284:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010328b:	e8 b0 cd ff ff       	call   f0100040 <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f0103290:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0103297:	00 
f0103298:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f010329d:	89 04 24             	mov    %eax,(%esp)
f01032a0:	e8 62 e1 ff ff       	call   f0101407 <page_remove>
	assert(pp2->pp_ref == 0);
f01032a5:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f01032aa:	74 24                	je     f01032d0 <mem_init+0x1dbf>
f01032ac:	c7 44 24 0c 2c 7c 10 	movl   $0xf0107c2c,0xc(%esp)
f01032b3:	f0 
f01032b4:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01032bb:	f0 
f01032bc:	c7 44 24 04 51 04 00 	movl   $0x451,0x4(%esp)
f01032c3:	00 
f01032c4:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01032cb:	e8 70 cd ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f01032d0:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f01032d5:	8b 08                	mov    (%eax),%ecx
f01032d7:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01032dd:	89 da                	mov    %ebx,%edx
f01032df:	2b 15 90 4e 1c f0    	sub    0xf01c4e90,%edx
f01032e5:	c1 fa 03             	sar    $0x3,%edx
f01032e8:	c1 e2 0c             	shl    $0xc,%edx
f01032eb:	39 d1                	cmp    %edx,%ecx
f01032ed:	74 24                	je     f0103313 <mem_init+0x1e02>
f01032ef:	c7 44 24 0c c8 74 10 	movl   $0xf01074c8,0xc(%esp)
f01032f6:	f0 
f01032f7:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01032fe:	f0 
f01032ff:	c7 44 24 04 54 04 00 	movl   $0x454,0x4(%esp)
f0103306:	00 
f0103307:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010330e:	e8 2d cd ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f0103313:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f0103319:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f010331e:	74 24                	je     f0103344 <mem_init+0x1e33>
f0103320:	c7 44 24 0c e3 7b 10 	movl   $0xf0107be3,0xc(%esp)
f0103327:	f0 
f0103328:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010332f:	f0 
f0103330:	c7 44 24 04 56 04 00 	movl   $0x456,0x4(%esp)
f0103337:	00 
f0103338:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010333f:	e8 fc cc ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f0103344:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// free the pages we took
	page_free(pp0);
f010334a:	89 1c 24             	mov    %ebx,(%esp)
f010334d:	e8 49 de ff ff       	call   f010119b <page_free>

	cprintf("check_page_installed_pgdir() succeeded!\n");
f0103352:	c7 04 24 6c 79 10 f0 	movl   $0xf010796c,(%esp)
f0103359:	e8 34 0b 00 00       	call   f0103e92 <cprintf>
f010335e:	e9 f6 00 00 00       	jmp    f0103459 <mem_init+0x1f48>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103363:	83 3d 88 4e 1c f0 00 	cmpl   $0x0,0xf01c4e88
f010336a:	0f 84 06 f7 ff ff    	je     f0102a76 <mem_init+0x1565>
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W| PTE_P);
f0103370:	bf 00 00 00 f0       	mov    $0xf0000000,%edi
f0103375:	bb 00 00 00 00       	mov    $0x0,%ebx
f010337a:	89 f2                	mov    %esi,%edx
f010337c:	e9 13 f7 ff ff       	jmp    f0102a94 <mem_init+0x1583>
	uintptr_t cpu_vastk_i;
	size_t va;
	for(i = 0 ; i<NCPU ;i++){
		cpu_vastk_i = KSTACKTOP - i* (KSTKSIZE + KSTKGAP)-KSTKSIZE;
		cpu_phystk_i = PADDR(percpu_kstacks[i]);
		boot_map_region(kern_pgdir,cpu_vastk_i,KSTKSIZE,cpu_phystk_i,PTE_W);
f0103381:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0103388:	00 
f0103389:	c7 04 24 00 60 1c 00 	movl   $0x1c6000,(%esp)
f0103390:	b9 00 80 00 00       	mov    $0x8000,%ecx
f0103395:	ba 00 80 bf ef       	mov    $0xefbf8000,%edx
f010339a:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f010339f:	e8 39 df ff ff       	call   f01012dd <boot_map_region>
f01033a4:	bb 00 e0 1c f0       	mov    $0xf01ce000,%ebx
f01033a9:	bf 00 60 20 f0       	mov    $0xf0206000,%edi
f01033ae:	be 00 80 be ef       	mov    $0xefbe8000,%esi
f01033b3:	e9 8a f7 ff ff       	jmp    f0102b42 <mem_init+0x1631>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		page_insert(kern_pgdir, pa2page(PADDR(bootstack) + i), (void *)(KSTACKTOP-KSTKSIZE + i), PTE_W| PTE_P);
f01033b8:	c7 44 24 0c 03 00 00 	movl   $0x3,0xc(%esp)
f01033bf:	00 
f01033c0:	c7 44 24 08 00 80 bf 	movl   $0xefbf8000,0x8(%esp)
f01033c7:	ef 
		panic("pa2page called with invalid pa");
	return &pages[PGNUM(pa)];
f01033c8:	8b 15 90 4e 1c f0    	mov    0xf01c4e90,%edx
f01033ce:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01033d1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01033d5:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f01033da:	89 04 24             	mov    %eax,(%esp)
f01033dd:	e8 6e e0 ff ff       	call   f0101450 <page_insert>
f01033e2:	bf 00 80 11 00       	mov    $0x118000,%edi
f01033e7:	b8 00 80 bf df       	mov    $0xdfbf8000,%eax
f01033ec:	29 d8                	sub    %ebx,%eax
f01033ee:	89 c3                	mov    %eax,%ebx
f01033f0:	e9 d1 f5 ff ff       	jmp    f01029c6 <mem_init+0x14b5>
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	size_t i;
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		page_insert(kern_pgdir,pa2page(PADDR(envs)+i),(void *)(UENVS + i),PTE_U| PTE_P);
f01033f5:	c7 44 24 0c 05 00 00 	movl   $0x5,0xc(%esp)
f01033fc:	00 
f01033fd:	c7 44 24 08 00 00 c0 	movl   $0xeec00000,0x8(%esp)
f0103404:	ee 
f0103405:	8b 15 90 4e 1c f0    	mov    0xf01c4e90,%edx
f010340b:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f010340e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103412:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
f0103417:	89 04 24             	mov    %eax,(%esp)
f010341a:	e8 31 e0 ff ff       	call   f0101450 <page_insert>
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	size_t i;
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f010341f:	bb 00 10 00 00       	mov    $0x1000,%ebx
f0103424:	e9 e2 f4 ff ff       	jmp    f010290b <mem_init+0x13fa>
	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0103429:	89 da                	mov    %ebx,%edx
f010342b:	89 f8                	mov    %edi,%eax
f010342d:	e8 92 d7 ff ff       	call   f0100bc4 <check_va2pa>
f0103432:	e9 9e f9 ff ff       	jmp    f0102dd5 <mem_init+0x18c4>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0103437:	89 da                	mov    %ebx,%edx
f0103439:	89 f8                	mov    %edi,%eax
f010343b:	e8 84 d7 ff ff       	call   f0100bc4 <check_va2pa>
f0103440:	e9 53 f8 ff ff       	jmp    f0102c98 <mem_init+0x1787>
f0103445:	81 ea 00 f0 ff 10    	sub    $0x10fff000,%edx
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f010344b:	89 f8                	mov    %edi,%eax
f010344d:	e8 72 d7 ff ff       	call   f0100bc4 <check_va2pa>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0103452:	89 da                	mov    %ebx,%edx
f0103454:	e9 e0 f7 ff ff       	jmp    f0102c39 <mem_init+0x1728>
	cr0 &= ~(CR0_TS|CR0_EM);
	lcr0(cr0);

	// Some more checks, only possible after kern_pgdir is installed.
	check_page_installed_pgdir();
}
f0103459:	83 c4 4c             	add    $0x4c,%esp
f010345c:	5b                   	pop    %ebx
f010345d:	5e                   	pop    %esi
f010345e:	5f                   	pop    %edi
f010345f:	5d                   	pop    %ebp
f0103460:	c3                   	ret    

f0103461 <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f0103461:	55                   	push   %ebp
f0103462:	89 e5                	mov    %esp,%ebp
f0103464:	57                   	push   %edi
f0103465:	56                   	push   %esi
f0103466:	53                   	push   %ebx
f0103467:	83 ec 3c             	sub    $0x3c,%esp
f010346a:	8b 7d 08             	mov    0x8(%ebp),%edi
f010346d:	8b 45 0c             	mov    0xc(%ebp),%eax

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
f0103470:	89 c2                	mov    %eax,%edx
f0103472:	03 55 10             	add    0x10(%ebp),%edx
f0103475:	89 55 d0             	mov    %edx,-0x30(%ebp)
f0103478:	39 d0                	cmp    %edx,%eax
f010347a:	73 70                	jae    f01034ec <user_mem_check+0x8b>
f010347c:	89 c3                	mov    %eax,%ebx
f010347e:	89 c6                	mov    %eax,%esi
		pte_t* store=0;
		struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
		if(store!=NULL)
		{
			//cprintf("pte!=NULL %08x\r\n",*store);
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f0103480:	8b 45 14             	mov    0x14(%ebp),%eax
f0103483:	83 c8 01             	or     $0x1,%eax
f0103486:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
	{
		pte_t* store=0;
f0103489:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
		struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
f0103490:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0103493:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103497:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010349b:	8b 47 60             	mov    0x60(%edi),%eax
f010349e:	89 04 24             	mov    %eax,(%esp)
f01034a1:	e8 bf de ff ff       	call   f0101365 <page_lookup>
		if(store!=NULL)
f01034a6:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01034a9:	85 c0                	test   %eax,%eax
f01034ab:	74 1b                	je     f01034c8 <user_mem_check+0x67>
		{
			//cprintf("pte!=NULL %08x\r\n",*store);
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f01034ad:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01034b0:	89 ca                	mov    %ecx,%edx
f01034b2:	23 10                	and    (%eax),%edx
f01034b4:	39 d1                	cmp    %edx,%ecx
f01034b6:	75 08                	jne    f01034c0 <user_mem_check+0x5f>
f01034b8:	81 fe 00 00 80 ef    	cmp    $0xef800000,%esi
f01034be:	76 10                	jbe    f01034d0 <user_mem_check+0x6f>
			   {
				//cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f01034c0:	89 35 3c 42 1c f0    	mov    %esi,0xf01c423c
				break;
f01034c6:	eb 1d                	jmp    f01034e5 <user_mem_check+0x84>
			}
			else
			{
				//cprintf("no pte!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f01034c8:	89 35 3c 42 1c f0    	mov    %esi,0xf01c423c
				break;
f01034ce:	eb 15                	jmp    f01034e5 <user_mem_check+0x84>
			}
		    i=ROUNDDOWN(i,PGSIZE);
f01034d0:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
f01034d6:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f01034dc:	89 de                	mov    %ebx,%esi
f01034de:	3b 5d d0             	cmp    -0x30(%ebp),%ebx
f01034e1:	72 a6                	jb     f0103489 <user_mem_check+0x28>
f01034e3:	eb 0e                	jmp    f01034f3 <user_mem_check+0x92>
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
			   {
				//cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
				break;
f01034e5:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f01034ea:	eb 0c                	jmp    f01034f8 <user_mem_check+0x97>
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
f01034ec:	b8 00 00 00 00       	mov    $0x0,%eax
f01034f1:	eb 05                	jmp    f01034f8 <user_mem_check+0x97>
f01034f3:	b8 00 00 00 00       	mov    $0x0,%eax
			}
		    i=ROUNDDOWN(i,PGSIZE);
		}

	return flag;
}
f01034f8:	83 c4 3c             	add    $0x3c,%esp
f01034fb:	5b                   	pop    %ebx
f01034fc:	5e                   	pop    %esi
f01034fd:	5f                   	pop    %edi
f01034fe:	5d                   	pop    %ebp
f01034ff:	c3                   	ret    

f0103500 <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f0103500:	55                   	push   %ebp
f0103501:	89 e5                	mov    %esp,%ebp
f0103503:	53                   	push   %ebx
f0103504:	83 ec 14             	sub    $0x14,%esp
f0103507:	8b 5d 08             	mov    0x8(%ebp),%ebx
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
f010350a:	8b 45 14             	mov    0x14(%ebp),%eax
f010350d:	83 c8 04             	or     $0x4,%eax
f0103510:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103514:	8b 45 10             	mov    0x10(%ebp),%eax
f0103517:	89 44 24 08          	mov    %eax,0x8(%esp)
f010351b:	8b 45 0c             	mov    0xc(%ebp),%eax
f010351e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103522:	89 1c 24             	mov    %ebx,(%esp)
f0103525:	e8 37 ff ff ff       	call   f0103461 <user_mem_check>
f010352a:	85 c0                	test   %eax,%eax
f010352c:	79 24                	jns    f0103552 <user_mem_assert+0x52>
		cprintf(".%08x. user_mem_check assertion failure for "
f010352e:	a1 3c 42 1c f0       	mov    0xf01c423c,%eax
f0103533:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103537:	8b 43 48             	mov    0x48(%ebx),%eax
f010353a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010353e:	c7 04 24 98 79 10 f0 	movl   $0xf0107998,(%esp)
f0103545:	e8 48 09 00 00       	call   f0103e92 <cprintf>
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
f010354a:	89 1c 24             	mov    %ebx,(%esp)
f010354d:	e8 8e 06 00 00       	call   f0103be0 <env_destroy>
	}
}
f0103552:	83 c4 14             	add    $0x14,%esp
f0103555:	5b                   	pop    %ebx
f0103556:	5d                   	pop    %ebp
f0103557:	c3                   	ret    

f0103558 <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f0103558:	55                   	push   %ebp
f0103559:	89 e5                	mov    %esp,%ebp
f010355b:	56                   	push   %esi
f010355c:	53                   	push   %ebx
f010355d:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f0103560:	85 c0                	test   %eax,%eax
f0103562:	75 1a                	jne    f010357e <envid2env+0x26>
		*env_store = curenv;
f0103564:	e8 3a 30 00 00       	call   f01065a3 <cpunum>
f0103569:	6b c0 74             	imul   $0x74,%eax,%eax
f010356c:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f0103572:	8b 55 0c             	mov    0xc(%ebp),%edx
f0103575:	89 02                	mov    %eax,(%edx)
		return 0;
f0103577:	b8 00 00 00 00       	mov    $0x0,%eax
f010357c:	eb 72                	jmp    f01035f0 <envid2env+0x98>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f010357e:	89 c3                	mov    %eax,%ebx
f0103580:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
f0103586:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f0103589:	03 1d 48 42 1c f0    	add    0xf01c4248,%ebx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f010358f:	83 7b 54 00          	cmpl   $0x0,0x54(%ebx)
f0103593:	74 05                	je     f010359a <envid2env+0x42>
f0103595:	39 43 48             	cmp    %eax,0x48(%ebx)
f0103598:	74 10                	je     f01035aa <envid2env+0x52>
		*env_store = 0;
f010359a:	8b 45 0c             	mov    0xc(%ebp),%eax
f010359d:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f01035a3:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01035a8:	eb 46                	jmp    f01035f0 <envid2env+0x98>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f01035aa:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f01035ae:	74 36                	je     f01035e6 <envid2env+0x8e>
f01035b0:	e8 ee 2f 00 00       	call   f01065a3 <cpunum>
f01035b5:	6b c0 74             	imul   $0x74,%eax,%eax
f01035b8:	39 98 28 50 1c f0    	cmp    %ebx,-0xfe3afd8(%eax)
f01035be:	74 26                	je     f01035e6 <envid2env+0x8e>
f01035c0:	8b 73 4c             	mov    0x4c(%ebx),%esi
f01035c3:	e8 db 2f 00 00       	call   f01065a3 <cpunum>
f01035c8:	6b c0 74             	imul   $0x74,%eax,%eax
f01035cb:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f01035d1:	3b 70 48             	cmp    0x48(%eax),%esi
f01035d4:	74 10                	je     f01035e6 <envid2env+0x8e>
		*env_store = 0;
f01035d6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01035d9:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f01035df:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01035e4:	eb 0a                	jmp    f01035f0 <envid2env+0x98>
	}

	*env_store = e;
f01035e6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01035e9:	89 18                	mov    %ebx,(%eax)
	return 0;
f01035eb:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01035f0:	5b                   	pop    %ebx
f01035f1:	5e                   	pop    %esi
f01035f2:	5d                   	pop    %ebp
f01035f3:	c3                   	ret    

f01035f4 <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f01035f4:	55                   	push   %ebp
f01035f5:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f01035f7:	b8 00 13 12 f0       	mov    $0xf0121300,%eax
f01035fc:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f01035ff:	b8 23 00 00 00       	mov    $0x23,%eax
f0103604:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f0103606:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f0103608:	b0 10                	mov    $0x10,%al
f010360a:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f010360c:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f010360e:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f0103610:	ea 17 36 10 f0 08 00 	ljmp   $0x8,$0xf0103617
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f0103617:	b0 00                	mov    $0x0,%al
f0103619:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f010361c:	5d                   	pop    %ebp
f010361d:	c3                   	ret    

f010361e <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f010361e:	55                   	push   %ebp
f010361f:	89 e5                	mov    %esp,%ebp
f0103621:	56                   	push   %esi
f0103622:	53                   	push   %ebx
	// Set up envs array
	// LAB 3: Your code here.
	env_free_list = NULL;
	size_t i = NENV - 1;
	while(i+1) {
		envs[i].env_id = 0;
f0103623:	8b 35 48 42 1c f0    	mov    0xf01c4248,%esi
f0103629:	8d 86 84 ef 01 00    	lea    0x1ef84(%esi),%eax
f010362f:	ba 00 04 00 00       	mov    $0x400,%edx
f0103634:	b9 00 00 00 00       	mov    $0x0,%ecx
f0103639:	89 c3                	mov    %eax,%ebx
f010363b:	c7 40 48 00 00 00 00 	movl   $0x0,0x48(%eax)
		envs[i].env_link = env_free_list;
f0103642:	89 48 44             	mov    %ecx,0x44(%eax)
f0103645:	83 e8 7c             	sub    $0x7c,%eax
{
	// Set up envs array
	// LAB 3: Your code here.
	env_free_list = NULL;
	size_t i = NENV - 1;
	while(i+1) {
f0103648:	83 ea 01             	sub    $0x1,%edx
f010364b:	74 04                	je     f0103651 <env_init+0x33>
		envs[i].env_id = 0;
		envs[i].env_link = env_free_list;
		env_free_list = &envs[i];
f010364d:	89 d9                	mov    %ebx,%ecx
f010364f:	eb e8                	jmp    f0103639 <env_init+0x1b>
f0103651:	89 35 4c 42 1c f0    	mov    %esi,0xf01c424c
		i = i-1;
	}
	//env_free_list = envs; // this line of code changing like this ugly looks just fit fuck grade sh,too useless
	// Per-CPU part of the initialization
	env_init_percpu();
f0103657:	e8 98 ff ff ff       	call   f01035f4 <env_init_percpu>
}
f010365c:	5b                   	pop    %ebx
f010365d:	5e                   	pop    %esi
f010365e:	5d                   	pop    %ebp
f010365f:	c3                   	ret    

f0103660 <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f0103660:	55                   	push   %ebp
f0103661:	89 e5                	mov    %esp,%ebp
f0103663:	56                   	push   %esi
f0103664:	53                   	push   %ebx
f0103665:	83 ec 10             	sub    $0x10,%esp
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list)){
f0103668:	8b 1d 4c 42 1c f0    	mov    0xf01c424c,%ebx
f010366e:	85 db                	test   %ebx,%ebx
f0103670:	0f 84 5b 01 00 00    	je     f01037d1 <env_alloc+0x171>
{
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f0103676:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f010367d:	e8 94 da ff ff       	call   f0101116 <page_alloc>
f0103682:	85 c0                	test   %eax,%eax
f0103684:	0f 84 4e 01 00 00    	je     f01037d8 <env_alloc+0x178>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010368a:	89 c2                	mov    %eax,%edx
f010368c:	2b 15 90 4e 1c f0    	sub    0xf01c4e90,%edx
f0103692:	c1 fa 03             	sar    $0x3,%edx
f0103695:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103698:	89 d1                	mov    %edx,%ecx
f010369a:	c1 e9 0c             	shr    $0xc,%ecx
f010369d:	3b 0d 88 4e 1c f0    	cmp    0xf01c4e88,%ecx
f01036a3:	72 20                	jb     f01036c5 <env_alloc+0x65>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01036a5:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01036a9:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f01036b0:	f0 
f01036b1:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01036b8:	00 
f01036b9:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f01036c0:	e8 7b c9 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01036c5:	81 ea 00 00 00 10    	sub    $0x10000000,%edx
f01036cb:	89 53 60             	mov    %edx,0x60(%ebx)
	//	is an exception -- you need to increment env_pgdir's
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
f01036ce:	ba ec 0e 00 00       	mov    $0xeec,%edx
	for(i=PDX(UTOP);i<1024;i++){
		e->env_pgdir[i] = kern_pgdir[i];
f01036d3:	8b 0d 8c 4e 1c f0    	mov    0xf01c4e8c,%ecx
f01036d9:	8b 34 11             	mov    (%ecx,%edx,1),%esi
f01036dc:	8b 4b 60             	mov    0x60(%ebx),%ecx
f01036df:	89 34 11             	mov    %esi,(%ecx,%edx,1)
f01036e2:	83 c2 04             	add    $0x4,%edx
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
	for(i=PDX(UTOP);i<1024;i++){
f01036e5:	81 fa 00 10 00 00    	cmp    $0x1000,%edx
f01036eb:	75 e6                	jne    f01036d3 <env_alloc+0x73>
		e->env_pgdir[i] = kern_pgdir[i];
	}
	p->pp_ref++;
f01036ed:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f01036f2:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01036f5:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01036fa:	77 20                	ja     f010371c <env_alloc+0xbc>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01036fc:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103700:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0103707:	f0 
f0103708:	c7 44 24 04 c8 00 00 	movl   $0xc8,0x4(%esp)
f010370f:	00 
f0103710:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103717:	e8 24 c9 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f010371c:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f0103722:	83 ca 05             	or     $0x5,%edx
f0103725:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	if ((r = env_setup_vm(e)) < 0){
		return r;
	}

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f010372b:	8b 43 48             	mov    0x48(%ebx),%eax
f010372e:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f0103733:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f0103738:	ba 00 10 00 00       	mov    $0x1000,%edx
f010373d:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f0103740:	89 da                	mov    %ebx,%edx
f0103742:	2b 15 48 42 1c f0    	sub    0xf01c4248,%edx
f0103748:	c1 fa 02             	sar    $0x2,%edx
f010374b:	69 d2 df 7b ef bd    	imul   $0xbdef7bdf,%edx,%edx
f0103751:	09 d0                	or     %edx,%eax
f0103753:	89 43 48             	mov    %eax,0x48(%ebx)
	// Set the basic status variables.
	e->env_parent_id = parent_id;
f0103756:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103759:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f010375c:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f0103763:	c7 43 54 02 00 00 00 	movl   $0x2,0x54(%ebx)
	e->env_runs = 0;
f010376a:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f0103771:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f0103778:	00 
f0103779:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0103780:	00 
f0103781:	89 1c 24             	mov    %ebx,(%esp)
f0103784:	e8 80 27 00 00       	call   f0105f09 <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f0103789:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f010378f:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f0103795:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f010379b:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f01037a2:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)
	// You will set e->env_tf.tf_eip later.

	// Enable interrupts while in user mode.
	// LAB 4: Your code here.
	e->env_tf.tf_eflags |= FL_IF;
f01037a8:	81 4b 38 00 02 00 00 	orl    $0x200,0x38(%ebx)
	// Clear the page fault handler until user installs one.
	e->env_pgfault_upcall = 0;
f01037af:	c7 43 64 00 00 00 00 	movl   $0x0,0x64(%ebx)

	// Also clear the IPC receiving flag.
	e->env_ipc_recving = 0;
f01037b6:	c7 43 68 00 00 00 00 	movl   $0x0,0x68(%ebx)

	// commit the allocation
	env_free_list = e->env_link;
f01037bd:	8b 43 44             	mov    0x44(%ebx),%eax
f01037c0:	a3 4c 42 1c f0       	mov    %eax,0xf01c424c
	*newenv_store = e;
f01037c5:	8b 45 08             	mov    0x8(%ebp),%eax
f01037c8:	89 18                	mov    %ebx,(%eax)

	// cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
f01037ca:	b8 00 00 00 00       	mov    $0x0,%eax
f01037cf:	eb 0c                	jmp    f01037dd <env_alloc+0x17d>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list)){
		return -E_NO_FREE_ENV;
f01037d1:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f01037d6:	eb 05                	jmp    f01037dd <env_alloc+0x17d>
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f01037d8:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	env_free_list = e->env_link;
	*newenv_store = e;

	// cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}
f01037dd:	83 c4 10             	add    $0x10,%esp
f01037e0:	5b                   	pop    %ebx
f01037e1:	5e                   	pop    %esi
f01037e2:	5d                   	pop    %ebp
f01037e3:	c3                   	ret    

f01037e4 <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f01037e4:	55                   	push   %ebp
f01037e5:	89 e5                	mov    %esp,%ebp
f01037e7:	57                   	push   %edi
f01037e8:	56                   	push   %esi
f01037e9:	53                   	push   %ebx
f01037ea:	83 ec 3c             	sub    $0x3c,%esp
	// LAB 3: Your code here.
	// If this is the file server (type == ENV_TYPE_FS) give it I/O privileges.
	// LAB 5: Your code here.
	struct Env * env;
	int test = env_alloc(&env,0);
f01037ed:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01037f4:	00 
f01037f5:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f01037f8:	89 04 24             	mov    %eax,(%esp)
f01037fb:	e8 60 fe ff ff       	call   f0103660 <env_alloc>
	if(test==0){
f0103800:	85 c0                	test   %eax,%eax
f0103802:	0f 85 e9 01 00 00    	jne    f01039f1 <env_create+0x20d>
		load_icode(env,binary,size);
f0103808:	8b 7d e4             	mov    -0x1c(%ebp),%edi
	//  You must also do something with the program's entry point,
	//  to make sure that the environment starts executing there.
	//  What?  (See env_run() and env_pop_tf() below.)

	// LAB 3: Your code here.
	lcr3(PADDR(e->env_pgdir));
f010380b:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010380e:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103813:	77 20                	ja     f0103835 <env_create+0x51>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103815:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103819:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0103820:	f0 
f0103821:	c7 44 24 04 67 01 00 	movl   $0x167,0x4(%esp)
f0103828:	00 
f0103829:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103830:	e8 0b c8 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103835:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f010383a:	0f 22 d8             	mov    %eax,%cr3
	struct Elf* ELFHDR = (struct Elf *) binary;
	if(ELFHDR->e_magic != ELF_MAGIC)
f010383d:	8b 45 08             	mov    0x8(%ebp),%eax
f0103840:	81 38 7f 45 4c 46    	cmpl   $0x464c457f,(%eax)
f0103846:	74 1c                	je     f0103864 <env_create+0x80>
		panic("Invalid ELF format !");
f0103848:	c7 44 24 08 ec 7c 10 	movl   $0xf0107cec,0x8(%esp)
f010384f:	f0 
f0103850:	c7 44 24 04 6a 01 00 	movl   $0x16a,0x4(%esp)
f0103857:	00 
f0103858:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f010385f:	e8 dc c7 ff ff       	call   f0100040 <_panic>

	struct Proghdr *ph,*eph;
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
f0103864:	8b 45 08             	mov    0x8(%ebp),%eax
f0103867:	89 c6                	mov    %eax,%esi
f0103869:	03 70 1c             	add    0x1c(%eax),%esi
	eph = ph + ELFHDR->e_phnum;
f010386c:	0f b7 40 2c          	movzwl 0x2c(%eax),%eax
f0103870:	c1 e0 05             	shl    $0x5,%eax
f0103873:	01 f0                	add    %esi,%eax
f0103875:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	for (; ph < eph; ph++) {
f0103878:	39 c6                	cmp    %eax,%esi
f010387a:	0f 83 d2 00 00 00    	jae    f0103952 <env_create+0x16e>
		if (ph->p_type == ELF_PROG_LOAD) {
f0103880:	83 3e 01             	cmpl   $0x1,(%esi)
f0103883:	0f 85 bd 00 00 00    	jne    f0103946 <env_create+0x162>
			if (ph->p_filesz > ph->p_memsz)
f0103889:	8b 56 14             	mov    0x14(%esi),%edx
f010388c:	39 56 10             	cmp    %edx,0x10(%esi)
f010388f:	76 1c                	jbe    f01038ad <env_create+0xc9>
				panic("invalid ELF proGhdr header!");
f0103891:	c7 44 24 08 01 7d 10 	movl   $0xf0107d01,0x8(%esp)
f0103898:	f0 
f0103899:	c7 44 24 04 72 01 00 	movl   $0x172,0x4(%esp)
f01038a0:	00 
f01038a1:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f01038a8:	e8 93 c7 ff ff       	call   f0100040 <_panic>

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
f01038ad:	8b 46 08             	mov    0x8(%esi),%eax
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f01038b0:	89 c3                	mov    %eax,%ebx
f01038b2:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f01038b8:	8d 84 02 ff 0f 00 00 	lea    0xfff(%edx,%eax,1),%eax
f01038bf:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01038c4:	39 c3                	cmp    %eax,%ebx
f01038c6:	73 59                	jae    f0103921 <env_create+0x13d>
f01038c8:	89 75 d0             	mov    %esi,-0x30(%ebp)
f01038cb:	89 c6                	mov    %eax,%esi
		p = (struct Page*)page_alloc(1);
f01038cd:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01038d4:	e8 3d d8 ff ff       	call   f0101116 <page_alloc>
		if(p==NULL)
f01038d9:	85 c0                	test   %eax,%eax
f01038db:	75 1c                	jne    f01038f9 <env_create+0x115>
			panic("Memory out!");
f01038dd:	c7 44 24 08 1d 7d 10 	movl   $0xf0107d1d,0x8(%esp)
f01038e4:	f0 
f01038e5:	c7 44 24 04 2c 01 00 	movl   $0x12c,0x4(%esp)
f01038ec:	00 
f01038ed:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f01038f4:	e8 47 c7 ff ff       	call   f0100040 <_panic>
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
f01038f9:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0103900:	00 
f0103901:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103905:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103909:	8b 47 60             	mov    0x60(%edi),%eax
f010390c:	89 04 24             	mov    %eax,(%esp)
f010390f:	e8 3c db ff ff       	call   f0101450 <page_insert>
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f0103914:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f010391a:	39 f3                	cmp    %esi,%ebx
f010391c:	72 af                	jb     f01038cd <env_create+0xe9>
f010391e:	8b 75 d0             	mov    -0x30(%ebp),%esi
			if (ph->p_filesz > ph->p_memsz)
				panic("invalid ELF proGhdr header!");

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
			//copy to va
			char *va = (char *)(ph->p_va);
f0103921:	8b 4e 08             	mov    0x8(%esi),%ecx
			size_t i;
			for (i = 0; i < ph->p_filesz; i++)
f0103924:	83 7e 10 00          	cmpl   $0x0,0x10(%esi)
f0103928:	74 1c                	je     f0103946 <env_create+0x162>
f010392a:	b8 00 00 00 00       	mov    $0x0,%eax
f010392f:	8b 5d 08             	mov    0x8(%ebp),%ebx
				va[i] = binary[ph->p_offset + i];
f0103932:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f0103935:	03 56 04             	add    0x4(%esi),%edx
f0103938:	0f b6 12             	movzbl (%edx),%edx
f010393b:	88 14 08             	mov    %dl,(%eax,%ecx,1)

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
			//copy to va
			char *va = (char *)(ph->p_va);
			size_t i;
			for (i = 0; i < ph->p_filesz; i++)
f010393e:	83 c0 01             	add    $0x1,%eax
f0103941:	3b 46 10             	cmp    0x10(%esi),%eax
f0103944:	72 ec                	jb     f0103932 <env_create+0x14e>
		panic("Invalid ELF format !");

	struct Proghdr *ph,*eph;
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
	eph = ph + ELFHDR->e_phnum;
	for (; ph < eph; ph++) {
f0103946:	83 c6 20             	add    $0x20,%esi
f0103949:	39 75 d4             	cmp    %esi,-0x2c(%ebp)
f010394c:	0f 87 2e ff ff ff    	ja     f0103880 <env_create+0x9c>
			for (i = 0; i < ph->p_filesz; i++)
				va[i] = binary[ph->p_offset + i];
		}
	}
	//set programe entry
	e->env_tf.tf_eip = ELFHDR->e_entry;
f0103952:	8b 45 08             	mov    0x8(%ebp),%eax
f0103955:	8b 40 18             	mov    0x18(%eax),%eax
f0103958:	89 47 30             	mov    %eax,0x30(%edi)
	// Now map one page for the program's initial stack
	// at virtual address USTACKTOP - PGSIZE.

	// LAB 3: Your code here.
	struct Page* stackPage = (struct Page*)page_alloc(1);
f010395b:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0103962:	e8 af d7 ff ff       	call   f0101116 <page_alloc>
	if(stackPage == NULL)
f0103967:	85 c0                	test   %eax,%eax
f0103969:	75 1c                	jne    f0103987 <env_create+0x1a3>
		panic("Out of memory!");
f010396b:	c7 44 24 08 29 7d 10 	movl   $0xf0107d29,0x8(%esp)
f0103972:	f0 
f0103973:	c7 44 24 04 84 01 00 	movl   $0x184,0x4(%esp)
f010397a:	00 
f010397b:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103982:	e8 b9 c6 ff ff       	call   f0100040 <_panic>
	page_insert(e->env_pgdir,stackPage,(void*)USTACKTOP - PGSIZE,PTE_U|PTE_W);
f0103987:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f010398e:	00 
f010398f:	c7 44 24 08 00 d0 bf 	movl   $0xeebfd000,0x8(%esp)
f0103996:	ee 
f0103997:	89 44 24 04          	mov    %eax,0x4(%esp)
f010399b:	8b 47 60             	mov    0x60(%edi),%eax
f010399e:	89 04 24             	mov    %eax,(%esp)
f01039a1:	e8 aa da ff ff       	call   f0101450 <page_insert>
	lcr3(PADDR(kern_pgdir));
f01039a6:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01039ab:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01039b0:	77 20                	ja     f01039d2 <env_create+0x1ee>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01039b2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01039b6:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f01039bd:	f0 
f01039be:	c7 44 24 04 86 01 00 	movl   $0x186,0x4(%esp)
f01039c5:	00 
f01039c6:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f01039cd:	e8 6e c6 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01039d2:	05 00 00 00 10       	add    $0x10000000,%eax
f01039d7:	0f 22 d8             	mov    %eax,%cr3
	// LAB 5: Your code here.
	struct Env * env;
	int test = env_alloc(&env,0);
	if(test==0){
		load_icode(env,binary,size);
		env->env_type = type;
f01039da:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01039dd:	8b 4d 10             	mov    0x10(%ebp),%ecx
f01039e0:	89 48 50             	mov    %ecx,0x50(%eax)
		if(type==ENV_TYPE_FS){
f01039e3:	83 f9 02             	cmp    $0x2,%ecx
f01039e6:	75 25                	jne    f0103a0d <env_create+0x229>
			env->env_tf.tf_eflags |= FL_IOPL_3;
f01039e8:	81 48 38 00 30 00 00 	orl    $0x3000,0x38(%eax)
f01039ef:	eb 1c                	jmp    f0103a0d <env_create+0x229>
		}else{
			env->env_tf.tf_eflags |=FL_IOPL_0;
		}
	}else{
		panic("create env fails !\n");
f01039f1:	c7 44 24 08 38 7d 10 	movl   $0xf0107d38,0x8(%esp)
f01039f8:	f0 
f01039f9:	c7 44 24 04 a1 01 00 	movl   $0x1a1,0x4(%esp)
f0103a00:	00 
f0103a01:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103a08:	e8 33 c6 ff ff       	call   f0100040 <_panic>
	}
}
f0103a0d:	83 c4 3c             	add    $0x3c,%esp
f0103a10:	5b                   	pop    %ebx
f0103a11:	5e                   	pop    %esi
f0103a12:	5f                   	pop    %edi
f0103a13:	5d                   	pop    %ebp
f0103a14:	c3                   	ret    

f0103a15 <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0103a15:	55                   	push   %ebp
f0103a16:	89 e5                	mov    %esp,%ebp
f0103a18:	57                   	push   %edi
f0103a19:	56                   	push   %esi
f0103a1a:	53                   	push   %ebx
f0103a1b:	83 ec 2c             	sub    $0x2c,%esp
f0103a1e:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f0103a21:	e8 7d 2b 00 00       	call   f01065a3 <cpunum>
f0103a26:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a29:	39 b8 28 50 1c f0    	cmp    %edi,-0xfe3afd8(%eax)
f0103a2f:	74 09                	je     f0103a3a <env_free+0x25>
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0103a31:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0103a38:	eb 36                	jmp    f0103a70 <env_free+0x5b>

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
		lcr3(PADDR(kern_pgdir));
f0103a3a:	a1 8c 4e 1c f0       	mov    0xf01c4e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103a3f:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103a44:	77 20                	ja     f0103a66 <env_free+0x51>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103a46:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103a4a:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0103a51:	f0 
f0103a52:	c7 44 24 04 b3 01 00 	movl   $0x1b3,0x4(%esp)
f0103a59:	00 
f0103a5a:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103a61:	e8 da c5 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103a66:	05 00 00 00 10       	add    $0x10000000,%eax
f0103a6b:	0f 22 d8             	mov    %eax,%cr3
f0103a6e:	eb c1                	jmp    f0103a31 <env_free+0x1c>
f0103a70:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0103a73:	89 c8                	mov    %ecx,%eax
f0103a75:	c1 e0 02             	shl    $0x2,%eax
f0103a78:	89 45 dc             	mov    %eax,-0x24(%ebp)
	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f0103a7b:	8b 47 60             	mov    0x60(%edi),%eax
f0103a7e:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f0103a81:	f7 c6 01 00 00 00    	test   $0x1,%esi
f0103a87:	0f 84 b7 00 00 00    	je     f0103b44 <env_free+0x12f>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f0103a8d:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103a93:	89 f0                	mov    %esi,%eax
f0103a95:	c1 e8 0c             	shr    $0xc,%eax
f0103a98:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103a9b:	3b 05 88 4e 1c f0    	cmp    0xf01c4e88,%eax
f0103aa1:	72 20                	jb     f0103ac3 <env_free+0xae>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103aa3:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0103aa7:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0103aae:	f0 
f0103aaf:	c7 44 24 04 c2 01 00 	movl   $0x1c2,0x4(%esp)
f0103ab6:	00 
f0103ab7:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103abe:	e8 7d c5 ff ff       	call   f0100040 <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103ac3:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103ac6:	c1 e0 16             	shl    $0x16,%eax
f0103ac9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103acc:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f0103ad1:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f0103ad8:	01 
f0103ad9:	74 17                	je     f0103af2 <env_free+0xdd>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103adb:	89 d8                	mov    %ebx,%eax
f0103add:	c1 e0 0c             	shl    $0xc,%eax
f0103ae0:	0b 45 e4             	or     -0x1c(%ebp),%eax
f0103ae3:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103ae7:	8b 47 60             	mov    0x60(%edi),%eax
f0103aea:	89 04 24             	mov    %eax,(%esp)
f0103aed:	e8 15 d9 ff ff       	call   f0101407 <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103af2:	83 c3 01             	add    $0x1,%ebx
f0103af5:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f0103afb:	75 d4                	jne    f0103ad1 <env_free+0xbc>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f0103afd:	8b 47 60             	mov    0x60(%edi),%eax
f0103b00:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103b03:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103b0a:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103b0d:	3b 05 88 4e 1c f0    	cmp    0xf01c4e88,%eax
f0103b13:	72 1c                	jb     f0103b31 <env_free+0x11c>
		panic("pa2page called with invalid pa");
f0103b15:	c7 44 24 08 94 73 10 	movl   $0xf0107394,0x8(%esp)
f0103b1c:	f0 
f0103b1d:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103b24:	00 
f0103b25:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f0103b2c:	e8 0f c5 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103b31:	a1 90 4e 1c f0       	mov    0xf01c4e90,%eax
f0103b36:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103b39:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0103b3c:	89 04 24             	mov    %eax,(%esp)
f0103b3f:	e8 6c d6 ff ff       	call   f01011b0 <page_decref>
	// Note the environment's demise.
	// cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103b44:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f0103b48:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f0103b4f:	0f 85 1b ff ff ff    	jne    f0103a70 <env_free+0x5b>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f0103b55:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103b58:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103b5d:	77 20                	ja     f0103b7f <env_free+0x16a>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103b5f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103b63:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0103b6a:	f0 
f0103b6b:	c7 44 24 04 d0 01 00 	movl   $0x1d0,0x4(%esp)
f0103b72:	00 
f0103b73:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103b7a:	e8 c1 c4 ff ff       	call   f0100040 <_panic>
	e->env_pgdir = 0;
f0103b7f:	c7 47 60 00 00 00 00 	movl   $0x0,0x60(%edi)
	return (physaddr_t)kva - KERNBASE;
f0103b86:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103b8b:	c1 e8 0c             	shr    $0xc,%eax
f0103b8e:	3b 05 88 4e 1c f0    	cmp    0xf01c4e88,%eax
f0103b94:	72 1c                	jb     f0103bb2 <env_free+0x19d>
		panic("pa2page called with invalid pa");
f0103b96:	c7 44 24 08 94 73 10 	movl   $0xf0107394,0x8(%esp)
f0103b9d:	f0 
f0103b9e:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103ba5:	00 
f0103ba6:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f0103bad:	e8 8e c4 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103bb2:	8b 15 90 4e 1c f0    	mov    0xf01c4e90,%edx
f0103bb8:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f0103bbb:	89 04 24             	mov    %eax,(%esp)
f0103bbe:	e8 ed d5 ff ff       	call   f01011b0 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f0103bc3:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f0103bca:	a1 4c 42 1c f0       	mov    0xf01c424c,%eax
f0103bcf:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f0103bd2:	89 3d 4c 42 1c f0    	mov    %edi,0xf01c424c
}
f0103bd8:	83 c4 2c             	add    $0x2c,%esp
f0103bdb:	5b                   	pop    %ebx
f0103bdc:	5e                   	pop    %esi
f0103bdd:	5f                   	pop    %edi
f0103bde:	5d                   	pop    %ebp
f0103bdf:	c3                   	ret    

f0103be0 <env_destroy>:
// If e was the current env, then runs a new environment (and does not return
// to the caller).
//
void
env_destroy(struct Env *e)
{
f0103be0:	55                   	push   %ebp
f0103be1:	89 e5                	mov    %esp,%ebp
f0103be3:	53                   	push   %ebx
f0103be4:	83 ec 14             	sub    $0x14,%esp
f0103be7:	8b 5d 08             	mov    0x8(%ebp),%ebx
	// If e is currently running on other CPUs, we change its state to
	// ENV_DYING. A zombie environment will be freed the next time
	// it traps to the kernel.
	if (e->env_status == ENV_RUNNING && curenv != e) {
f0103bea:	83 7b 54 03          	cmpl   $0x3,0x54(%ebx)
f0103bee:	75 19                	jne    f0103c09 <env_destroy+0x29>
f0103bf0:	e8 ae 29 00 00       	call   f01065a3 <cpunum>
f0103bf5:	6b c0 74             	imul   $0x74,%eax,%eax
f0103bf8:	39 98 28 50 1c f0    	cmp    %ebx,-0xfe3afd8(%eax)
f0103bfe:	74 09                	je     f0103c09 <env_destroy+0x29>
		e->env_status = ENV_DYING;
f0103c00:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
		return;
f0103c07:	eb 2f                	jmp    f0103c38 <env_destroy+0x58>
	}

	env_free(e);
f0103c09:	89 1c 24             	mov    %ebx,(%esp)
f0103c0c:	e8 04 fe ff ff       	call   f0103a15 <env_free>

	if (curenv == e) {
f0103c11:	e8 8d 29 00 00       	call   f01065a3 <cpunum>
f0103c16:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c19:	39 98 28 50 1c f0    	cmp    %ebx,-0xfe3afd8(%eax)
f0103c1f:	75 17                	jne    f0103c38 <env_destroy+0x58>
		curenv = NULL;
f0103c21:	e8 7d 29 00 00       	call   f01065a3 <cpunum>
f0103c26:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c29:	c7 80 28 50 1c f0 00 	movl   $0x0,-0xfe3afd8(%eax)
f0103c30:	00 00 00 
		sched_yield();
f0103c33:	e8 88 0f 00 00       	call   f0104bc0 <sched_yield>
	}
}
f0103c38:	83 c4 14             	add    $0x14,%esp
f0103c3b:	5b                   	pop    %ebx
f0103c3c:	5d                   	pop    %ebp
f0103c3d:	c3                   	ret    

f0103c3e <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f0103c3e:	55                   	push   %ebp
f0103c3f:	89 e5                	mov    %esp,%ebp
f0103c41:	53                   	push   %ebx
f0103c42:	83 ec 14             	sub    $0x14,%esp
	// Record the CPU we are running on for user-space debugging
	curenv->env_cpunum = cpunum();
f0103c45:	e8 59 29 00 00       	call   f01065a3 <cpunum>
f0103c4a:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c4d:	8b 98 28 50 1c f0    	mov    -0xfe3afd8(%eax),%ebx
f0103c53:	e8 4b 29 00 00       	call   f01065a3 <cpunum>
f0103c58:	89 43 5c             	mov    %eax,0x5c(%ebx)

	__asm __volatile("movl %0,%%esp\n"
f0103c5b:	8b 65 08             	mov    0x8(%ebp),%esp
f0103c5e:	61                   	popa   
f0103c5f:	07                   	pop    %es
f0103c60:	1f                   	pop    %ds
f0103c61:	83 c4 08             	add    $0x8,%esp
f0103c64:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f0103c65:	c7 44 24 08 4c 7d 10 	movl   $0xf0107d4c,0x8(%esp)
f0103c6c:	f0 
f0103c6d:	c7 44 24 04 06 02 00 	movl   $0x206,0x4(%esp)
f0103c74:	00 
f0103c75:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103c7c:	e8 bf c3 ff ff       	call   f0100040 <_panic>

f0103c81 <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0103c81:	55                   	push   %ebp
f0103c82:	89 e5                	mov    %esp,%ebp
f0103c84:	53                   	push   %ebx
f0103c85:	83 ec 14             	sub    $0x14,%esp
f0103c88:	8b 5d 08             	mov    0x8(%ebp),%ebx

	// Hint: This function loads the new environment's state from
	//	e->env_tf.  Go back through the code you wrote above
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.
	if(curenv!=NULL&& curenv->env_status==ENV_RUNNING)
f0103c8b:	e8 13 29 00 00       	call   f01065a3 <cpunum>
f0103c90:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c93:	83 b8 28 50 1c f0 00 	cmpl   $0x0,-0xfe3afd8(%eax)
f0103c9a:	74 29                	je     f0103cc5 <env_run+0x44>
f0103c9c:	e8 02 29 00 00       	call   f01065a3 <cpunum>
f0103ca1:	6b c0 74             	imul   $0x74,%eax,%eax
f0103ca4:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f0103caa:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0103cae:	75 15                	jne    f0103cc5 <env_run+0x44>
		curenv->env_status = ENV_RUNNABLE;
f0103cb0:	e8 ee 28 00 00       	call   f01065a3 <cpunum>
f0103cb5:	6b c0 74             	imul   $0x74,%eax,%eax
f0103cb8:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f0103cbe:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)

	curenv = e;
f0103cc5:	e8 d9 28 00 00       	call   f01065a3 <cpunum>
f0103cca:	6b c0 74             	imul   $0x74,%eax,%eax
f0103ccd:	89 98 28 50 1c f0    	mov    %ebx,-0xfe3afd8(%eax)
	int zero = 0;
	e->env_status = ENV_RUNNING;
f0103cd3:	c7 43 54 03 00 00 00 	movl   $0x3,0x54(%ebx)
	e->env_runs++;
f0103cda:	83 43 58 01          	addl   $0x1,0x58(%ebx)
	lcr3(PADDR(e->env_pgdir));
f0103cde:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103ce1:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103ce6:	77 20                	ja     f0103d08 <env_run+0x87>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103ce8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103cec:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0103cf3:	f0 
f0103cf4:	c7 44 24 04 29 02 00 	movl   $0x229,0x4(%esp)
f0103cfb:	00 
f0103cfc:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103d03:	e8 38 c3 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103d08:	05 00 00 00 10       	add    $0x10000000,%eax
f0103d0d:	0f 22 d8             	mov    %eax,%cr3
}

static inline void
unlock_kernel(void)
{
	spin_unlock(&kernel_lock);
f0103d10:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f0103d17:	e8 d0 2b 00 00       	call   f01068ec <spin_unlock>

	// Normally we wouldn't need to do this, but QEMU only runs
	// one CPU at a time and has a long time-slice.  Without the
	// pause, this CPU is likely to reacquire the lock before
	// another CPU has even been given a chance to acquire it.
	asm volatile("pause");
f0103d1c:	f3 90                	pause  
	unlock_kernel();

	env_pop_tf(&e->env_tf);
f0103d1e:	89 1c 24             	mov    %ebx,(%esp)
f0103d21:	e8 18 ff ff ff       	call   f0103c3e <env_pop_tf>

f0103d26 <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0103d26:	55                   	push   %ebp
f0103d27:	89 e5                	mov    %esp,%ebp
f0103d29:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103d2d:	ba 70 00 00 00       	mov    $0x70,%edx
f0103d32:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0103d33:	b2 71                	mov    $0x71,%dl
f0103d35:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0103d36:	0f b6 c0             	movzbl %al,%eax
}
f0103d39:	5d                   	pop    %ebp
f0103d3a:	c3                   	ret    

f0103d3b <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0103d3b:	55                   	push   %ebp
f0103d3c:	89 e5                	mov    %esp,%ebp
f0103d3e:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103d42:	ba 70 00 00 00       	mov    $0x70,%edx
f0103d47:	ee                   	out    %al,(%dx)
f0103d48:	b2 71                	mov    $0x71,%dl
f0103d4a:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103d4d:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0103d4e:	5d                   	pop    %ebp
f0103d4f:	c3                   	ret    

f0103d50 <irq_setmask_8259A>:
		irq_setmask_8259A(irq_mask_8259A);
}

void
irq_setmask_8259A(uint16_t mask)
{
f0103d50:	55                   	push   %ebp
f0103d51:	89 e5                	mov    %esp,%ebp
f0103d53:	56                   	push   %esi
f0103d54:	53                   	push   %ebx
f0103d55:	83 ec 10             	sub    $0x10,%esp
f0103d58:	8b 45 08             	mov    0x8(%ebp),%eax
	int i;
	irq_mask_8259A = mask;
f0103d5b:	66 a3 88 13 12 f0    	mov    %ax,0xf0121388
	if (!didinit)
f0103d61:	83 3d 50 42 1c f0 00 	cmpl   $0x0,0xf01c4250
f0103d68:	74 4e                	je     f0103db8 <irq_setmask_8259A+0x68>
f0103d6a:	89 c6                	mov    %eax,%esi
f0103d6c:	ba 21 00 00 00       	mov    $0x21,%edx
f0103d71:	ee                   	out    %al,(%dx)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
f0103d72:	66 c1 e8 08          	shr    $0x8,%ax
f0103d76:	b2 a1                	mov    $0xa1,%dl
f0103d78:	ee                   	out    %al,(%dx)
	cprintf("enabled interrupts:");
f0103d79:	c7 04 24 58 7d 10 f0 	movl   $0xf0107d58,(%esp)
f0103d80:	e8 0d 01 00 00       	call   f0103e92 <cprintf>
	for (i = 0; i < 16; i++)
f0103d85:	bb 00 00 00 00       	mov    $0x0,%ebx
		if (~mask & (1<<i))
f0103d8a:	0f b7 f6             	movzwl %si,%esi
f0103d8d:	f7 d6                	not    %esi
f0103d8f:	0f a3 de             	bt     %ebx,%esi
f0103d92:	73 10                	jae    f0103da4 <irq_setmask_8259A+0x54>
			cprintf(" %d", i);
f0103d94:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103d98:	c7 04 24 ff 81 10 f0 	movl   $0xf01081ff,(%esp)
f0103d9f:	e8 ee 00 00 00       	call   f0103e92 <cprintf>
	if (!didinit)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
	cprintf("enabled interrupts:");
	for (i = 0; i < 16; i++)
f0103da4:	83 c3 01             	add    $0x1,%ebx
f0103da7:	83 fb 10             	cmp    $0x10,%ebx
f0103daa:	75 e3                	jne    f0103d8f <irq_setmask_8259A+0x3f>
		if (~mask & (1<<i))
			cprintf(" %d", i);
	cprintf("\n");
f0103dac:	c7 04 24 4a 7d 10 f0 	movl   $0xf0107d4a,(%esp)
f0103db3:	e8 da 00 00 00       	call   f0103e92 <cprintf>
}
f0103db8:	83 c4 10             	add    $0x10,%esp
f0103dbb:	5b                   	pop    %ebx
f0103dbc:	5e                   	pop    %esi
f0103dbd:	5d                   	pop    %ebp
f0103dbe:	c3                   	ret    

f0103dbf <pic_init>:

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
	didinit = 1;
f0103dbf:	c7 05 50 42 1c f0 01 	movl   $0x1,0xf01c4250
f0103dc6:	00 00 00 
f0103dc9:	ba 21 00 00 00       	mov    $0x21,%edx
f0103dce:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0103dd3:	ee                   	out    %al,(%dx)
f0103dd4:	b2 a1                	mov    $0xa1,%dl
f0103dd6:	ee                   	out    %al,(%dx)
f0103dd7:	b2 20                	mov    $0x20,%dl
f0103dd9:	b8 11 00 00 00       	mov    $0x11,%eax
f0103dde:	ee                   	out    %al,(%dx)
f0103ddf:	b2 21                	mov    $0x21,%dl
f0103de1:	b8 20 00 00 00       	mov    $0x20,%eax
f0103de6:	ee                   	out    %al,(%dx)
f0103de7:	b8 04 00 00 00       	mov    $0x4,%eax
f0103dec:	ee                   	out    %al,(%dx)
f0103ded:	b8 03 00 00 00       	mov    $0x3,%eax
f0103df2:	ee                   	out    %al,(%dx)
f0103df3:	b2 a0                	mov    $0xa0,%dl
f0103df5:	b8 11 00 00 00       	mov    $0x11,%eax
f0103dfa:	ee                   	out    %al,(%dx)
f0103dfb:	b2 a1                	mov    $0xa1,%dl
f0103dfd:	b8 28 00 00 00       	mov    $0x28,%eax
f0103e02:	ee                   	out    %al,(%dx)
f0103e03:	b8 02 00 00 00       	mov    $0x2,%eax
f0103e08:	ee                   	out    %al,(%dx)
f0103e09:	b8 01 00 00 00       	mov    $0x1,%eax
f0103e0e:	ee                   	out    %al,(%dx)
f0103e0f:	b2 20                	mov    $0x20,%dl
f0103e11:	b8 68 00 00 00       	mov    $0x68,%eax
f0103e16:	ee                   	out    %al,(%dx)
f0103e17:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103e1c:	ee                   	out    %al,(%dx)
f0103e1d:	b2 a0                	mov    $0xa0,%dl
f0103e1f:	b8 68 00 00 00       	mov    $0x68,%eax
f0103e24:	ee                   	out    %al,(%dx)
f0103e25:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103e2a:	ee                   	out    %al,(%dx)
	outb(IO_PIC1, 0x0a);             /* read IRR by default */

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
f0103e2b:	0f b7 05 88 13 12 f0 	movzwl 0xf0121388,%eax
f0103e32:	66 83 f8 ff          	cmp    $0xffff,%ax
f0103e36:	74 12                	je     f0103e4a <pic_init+0x8b>
static bool didinit;

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
f0103e38:	55                   	push   %ebp
f0103e39:	89 e5                	mov    %esp,%ebp
f0103e3b:	83 ec 18             	sub    $0x18,%esp

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
		irq_setmask_8259A(irq_mask_8259A);
f0103e3e:	0f b7 c0             	movzwl %ax,%eax
f0103e41:	89 04 24             	mov    %eax,(%esp)
f0103e44:	e8 07 ff ff ff       	call   f0103d50 <irq_setmask_8259A>
}
f0103e49:	c9                   	leave  
f0103e4a:	f3 c3                	repz ret 

f0103e4c <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0103e4c:	55                   	push   %ebp
f0103e4d:	89 e5                	mov    %esp,%ebp
f0103e4f:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0103e52:	8b 45 08             	mov    0x8(%ebp),%eax
f0103e55:	89 04 24             	mov    %eax,(%esp)
f0103e58:	e8 a0 c9 ff ff       	call   f01007fd <cputchar>
	*cnt++;
}
f0103e5d:	c9                   	leave  
f0103e5e:	c3                   	ret    

f0103e5f <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0103e5f:	55                   	push   %ebp
f0103e60:	89 e5                	mov    %esp,%ebp
f0103e62:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0103e65:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0103e6c:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103e6f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103e73:	8b 45 08             	mov    0x8(%ebp),%eax
f0103e76:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103e7a:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0103e7d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e81:	c7 04 24 4c 3e 10 f0 	movl   $0xf0103e4c,(%esp)
f0103e88:	e8 37 19 00 00       	call   f01057c4 <vprintfmt>
	return cnt;
}
f0103e8d:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0103e90:	c9                   	leave  
f0103e91:	c3                   	ret    

f0103e92 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0103e92:	55                   	push   %ebp
f0103e93:	89 e5                	mov    %esp,%ebp
f0103e95:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0103e98:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0103e9b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e9f:	8b 45 08             	mov    0x8(%ebp),%eax
f0103ea2:	89 04 24             	mov    %eax,(%esp)
f0103ea5:	e8 b5 ff ff ff       	call   f0103e5f <vcprintf>
	va_end(ap);

	return cnt;
}
f0103eaa:	c9                   	leave  
f0103eab:	c3                   	ret    
f0103eac:	66 90                	xchg   %ax,%ax
f0103eae:	66 90                	xchg   %ax,%ax

f0103eb0 <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f0103eb0:	55                   	push   %ebp
f0103eb1:	89 e5                	mov    %esp,%ebp
f0103eb3:	53                   	push   %ebx
f0103eb4:	83 ec 04             	sub    $0x4,%esp
	struct Taskstate* this_ts = &thiscpu->cpu_ts;
f0103eb7:	e8 e7 26 00 00       	call   f01065a3 <cpunum>
f0103ebc:	6b d8 74             	imul   $0x74,%eax,%ebx
	int CPUID = cpunum();
f0103ebf:	e8 df 26 00 00       	call   f01065a3 <cpunum>
	this_ts->ts_esp0 = KSTACKTOP - CPUID * (KSTKGAP + KSTKSIZE);
f0103ec4:	89 c2                	mov    %eax,%edx
f0103ec6:	f7 da                	neg    %edx
f0103ec8:	c1 e2 10             	shl    $0x10,%edx
f0103ecb:	81 ea 00 00 40 10    	sub    $0x10400000,%edx
f0103ed1:	89 93 30 50 1c f0    	mov    %edx,-0xfe3afd0(%ebx)
	this_ts->ts_ss0 = GD_KD;
f0103ed7:	66 c7 83 34 50 1c f0 	movw   $0x10,-0xfe3afcc(%ebx)
f0103ede:	10 00 

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
	struct Taskstate* this_ts = &thiscpu->cpu_ts;
f0103ee0:	81 c3 2c 50 1c f0    	add    $0xf01c502c,%ebx
	int CPUID = cpunum();
	this_ts->ts_esp0 = KSTACKTOP - CPUID * (KSTKGAP + KSTKSIZE);
	this_ts->ts_ss0 = GD_KD;

	gdt[(GD_TSS0 >> 3) + CPUID] = SEG16(STS_T32A, (uint32_t) (this_ts),
f0103ee6:	8d 50 05             	lea    0x5(%eax),%edx
f0103ee9:	66 c7 04 d5 20 13 12 	movw   $0x68,-0xfedece0(,%edx,8)
f0103ef0:	f0 68 00 
f0103ef3:	66 89 1c d5 22 13 12 	mov    %bx,-0xfedecde(,%edx,8)
f0103efa:	f0 
f0103efb:	89 d9                	mov    %ebx,%ecx
f0103efd:	c1 e9 10             	shr    $0x10,%ecx
f0103f00:	88 0c d5 24 13 12 f0 	mov    %cl,-0xfedecdc(,%edx,8)
f0103f07:	c6 04 d5 26 13 12 f0 	movb   $0x40,-0xfedecda(,%edx,8)
f0103f0e:	40 
f0103f0f:	c1 eb 18             	shr    $0x18,%ebx
f0103f12:	88 1c d5 27 13 12 f0 	mov    %bl,-0xfedecd9(,%edx,8)
					sizeof(struct Taskstate), 0);
	gdt[(GD_TSS0 >> 3) + CPUID].sd_s = 0;
f0103f19:	c6 04 d5 25 13 12 f0 	movb   $0x89,-0xfedecdb(,%edx,8)
f0103f20:	89 

	//cprintf("Loading GD_TSS_ %d\n", ((GD_TSS0>>3) + CPUID)<<3);

	ltr(GD_TSS0 + (CPUID << 3));
f0103f21:	8d 04 c5 28 00 00 00 	lea    0x28(,%eax,8),%eax
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f0103f28:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f0103f2b:	b8 8a 13 12 f0       	mov    $0xf012138a,%eax
f0103f30:	0f 01 18             	lidtl  (%eax)
	// bottom three bits are special; we leave them 0)
	ltr(GD_TSS0+(cpu_id<<3));

	// Load the IDT
	lidt(&idt_pd);*/
}
f0103f33:	83 c4 04             	add    $0x4,%esp
f0103f36:	5b                   	pop    %ebx
f0103f37:	5d                   	pop    %ebp
f0103f38:	c3                   	ret    

f0103f39 <trap_init>:
}


void
trap_init(void)
{
f0103f39:	55                   	push   %ebp
f0103f3a:	89 e5                	mov    %esp,%ebp
f0103f3c:	83 ec 08             	sub    $0x8,%esp
	extern struct Segdesc gdt[];
	SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);
f0103f3f:	b8 aa 4a 10 f0       	mov    $0xf0104aaa,%eax
f0103f44:	66 a3 60 42 1c f0    	mov    %ax,0xf01c4260
f0103f4a:	66 c7 05 62 42 1c f0 	movw   $0x8,0xf01c4262
f0103f51:	08 00 
f0103f53:	c6 05 64 42 1c f0 00 	movb   $0x0,0xf01c4264
f0103f5a:	c6 05 65 42 1c f0 8f 	movb   $0x8f,0xf01c4265
f0103f61:	c1 e8 10             	shr    $0x10,%eax
f0103f64:	66 a3 66 42 1c f0    	mov    %ax,0xf01c4266
	SETGATE(idt[2], 0, GD_KT, nmi_handler, 0);
f0103f6a:	b8 b4 4a 10 f0       	mov    $0xf0104ab4,%eax
f0103f6f:	66 a3 70 42 1c f0    	mov    %ax,0xf01c4270
f0103f75:	66 c7 05 72 42 1c f0 	movw   $0x8,0xf01c4272
f0103f7c:	08 00 
f0103f7e:	c6 05 74 42 1c f0 00 	movb   $0x0,0xf01c4274
f0103f85:	c6 05 75 42 1c f0 8e 	movb   $0x8e,0xf01c4275
f0103f8c:	c1 e8 10             	shr    $0x10,%eax
f0103f8f:	66 a3 76 42 1c f0    	mov    %ax,0xf01c4276
	SETGATE(idt[3], 1, GD_KT, breakpoint_handler, 3);
f0103f95:	b8 be 4a 10 f0       	mov    $0xf0104abe,%eax
f0103f9a:	66 a3 78 42 1c f0    	mov    %ax,0xf01c4278
f0103fa0:	66 c7 05 7a 42 1c f0 	movw   $0x8,0xf01c427a
f0103fa7:	08 00 
f0103fa9:	c6 05 7c 42 1c f0 00 	movb   $0x0,0xf01c427c
f0103fb0:	c6 05 7d 42 1c f0 ef 	movb   $0xef,0xf01c427d
f0103fb7:	c1 e8 10             	shr    $0x10,%eax
f0103fba:	66 a3 7e 42 1c f0    	mov    %ax,0xf01c427e
	SETGATE(idt[4], 1, GD_KT, overflow_handler, 3);
f0103fc0:	b8 c8 4a 10 f0       	mov    $0xf0104ac8,%eax
f0103fc5:	66 a3 80 42 1c f0    	mov    %ax,0xf01c4280
f0103fcb:	66 c7 05 82 42 1c f0 	movw   $0x8,0xf01c4282
f0103fd2:	08 00 
f0103fd4:	c6 05 84 42 1c f0 00 	movb   $0x0,0xf01c4284
f0103fdb:	c6 05 85 42 1c f0 ef 	movb   $0xef,0xf01c4285
f0103fe2:	c1 e8 10             	shr    $0x10,%eax
f0103fe5:	66 a3 86 42 1c f0    	mov    %ax,0xf01c4286
	SETGATE(idt[5], 1, GD_KT, bdrgeexceed_handler, 3);
f0103feb:	b8 d2 4a 10 f0       	mov    $0xf0104ad2,%eax
f0103ff0:	66 a3 88 42 1c f0    	mov    %ax,0xf01c4288
f0103ff6:	66 c7 05 8a 42 1c f0 	movw   $0x8,0xf01c428a
f0103ffd:	08 00 
f0103fff:	c6 05 8c 42 1c f0 00 	movb   $0x0,0xf01c428c
f0104006:	c6 05 8d 42 1c f0 ef 	movb   $0xef,0xf01c428d
f010400d:	c1 e8 10             	shr    $0x10,%eax
f0104010:	66 a3 8e 42 1c f0    	mov    %ax,0xf01c428e
	SETGATE(idt[6], 1, GD_KT, invalidop_handler, 0);
f0104016:	b8 dc 4a 10 f0       	mov    $0xf0104adc,%eax
f010401b:	66 a3 90 42 1c f0    	mov    %ax,0xf01c4290
f0104021:	66 c7 05 92 42 1c f0 	movw   $0x8,0xf01c4292
f0104028:	08 00 
f010402a:	c6 05 94 42 1c f0 00 	movb   $0x0,0xf01c4294
f0104031:	c6 05 95 42 1c f0 8f 	movb   $0x8f,0xf01c4295
f0104038:	c1 e8 10             	shr    $0x10,%eax
f010403b:	66 a3 96 42 1c f0    	mov    %ax,0xf01c4296
	SETGATE(idt[7], 1, GD_KT, nomathcopro_handler, 0);
f0104041:	b8 e6 4a 10 f0       	mov    $0xf0104ae6,%eax
f0104046:	66 a3 98 42 1c f0    	mov    %ax,0xf01c4298
f010404c:	66 c7 05 9a 42 1c f0 	movw   $0x8,0xf01c429a
f0104053:	08 00 
f0104055:	c6 05 9c 42 1c f0 00 	movb   $0x0,0xf01c429c
f010405c:	c6 05 9d 42 1c f0 8f 	movb   $0x8f,0xf01c429d
f0104063:	c1 e8 10             	shr    $0x10,%eax
f0104066:	66 a3 9e 42 1c f0    	mov    %ax,0xf01c429e
	SETGATE(idt[8], 1, GD_KT, dbfault_handler, 0);
f010406c:	b8 f0 4a 10 f0       	mov    $0xf0104af0,%eax
f0104071:	66 a3 a0 42 1c f0    	mov    %ax,0xf01c42a0
f0104077:	66 c7 05 a2 42 1c f0 	movw   $0x8,0xf01c42a2
f010407e:	08 00 
f0104080:	c6 05 a4 42 1c f0 00 	movb   $0x0,0xf01c42a4
f0104087:	c6 05 a5 42 1c f0 8f 	movb   $0x8f,0xf01c42a5
f010408e:	c1 e8 10             	shr    $0x10,%eax
f0104091:	66 a3 a6 42 1c f0    	mov    %ax,0xf01c42a6
	SETGATE(idt[10], 1, GD_KT, invalidTSS_handler, 0);
f0104097:	b8 f8 4a 10 f0       	mov    $0xf0104af8,%eax
f010409c:	66 a3 b0 42 1c f0    	mov    %ax,0xf01c42b0
f01040a2:	66 c7 05 b2 42 1c f0 	movw   $0x8,0xf01c42b2
f01040a9:	08 00 
f01040ab:	c6 05 b4 42 1c f0 00 	movb   $0x0,0xf01c42b4
f01040b2:	c6 05 b5 42 1c f0 8f 	movb   $0x8f,0xf01c42b5
f01040b9:	c1 e8 10             	shr    $0x10,%eax
f01040bc:	66 a3 b6 42 1c f0    	mov    %ax,0xf01c42b6

	SETGATE(idt[11], 1, GD_KT, sgmtnotpresent_handler, 0);
f01040c2:	b8 00 4b 10 f0       	mov    $0xf0104b00,%eax
f01040c7:	66 a3 b8 42 1c f0    	mov    %ax,0xf01c42b8
f01040cd:	66 c7 05 ba 42 1c f0 	movw   $0x8,0xf01c42ba
f01040d4:	08 00 
f01040d6:	c6 05 bc 42 1c f0 00 	movb   $0x0,0xf01c42bc
f01040dd:	c6 05 bd 42 1c f0 8f 	movb   $0x8f,0xf01c42bd
f01040e4:	c1 e8 10             	shr    $0x10,%eax
f01040e7:	66 a3 be 42 1c f0    	mov    %ax,0xf01c42be
	SETGATE(idt[12], 1, GD_KT, stacksgmtfault_handler, 0);
f01040ed:	b8 08 4b 10 f0       	mov    $0xf0104b08,%eax
f01040f2:	66 a3 c0 42 1c f0    	mov    %ax,0xf01c42c0
f01040f8:	66 c7 05 c2 42 1c f0 	movw   $0x8,0xf01c42c2
f01040ff:	08 00 
f0104101:	c6 05 c4 42 1c f0 00 	movb   $0x0,0xf01c42c4
f0104108:	c6 05 c5 42 1c f0 8f 	movb   $0x8f,0xf01c42c5
f010410f:	c1 e8 10             	shr    $0x10,%eax
f0104112:	66 a3 c6 42 1c f0    	mov    %ax,0xf01c42c6
	SETGATE(idt[14], 1, GD_KT, pagefault_handler, 0);
f0104118:	b8 18 4b 10 f0       	mov    $0xf0104b18,%eax
f010411d:	66 a3 d0 42 1c f0    	mov    %ax,0xf01c42d0
f0104123:	66 c7 05 d2 42 1c f0 	movw   $0x8,0xf01c42d2
f010412a:	08 00 
f010412c:	c6 05 d4 42 1c f0 00 	movb   $0x0,0xf01c42d4
f0104133:	c6 05 d5 42 1c f0 8f 	movb   $0x8f,0xf01c42d5
f010413a:	c1 e8 10             	shr    $0x10,%eax
f010413d:	66 a3 d6 42 1c f0    	mov    %ax,0xf01c42d6
	SETGATE(idt[13], 1, GD_KT, generalprotection_handler, 0);
f0104143:	b8 10 4b 10 f0       	mov    $0xf0104b10,%eax
f0104148:	66 a3 c8 42 1c f0    	mov    %ax,0xf01c42c8
f010414e:	66 c7 05 ca 42 1c f0 	movw   $0x8,0xf01c42ca
f0104155:	08 00 
f0104157:	c6 05 cc 42 1c f0 00 	movb   $0x0,0xf01c42cc
f010415e:	c6 05 cd 42 1c f0 8f 	movb   $0x8f,0xf01c42cd
f0104165:	c1 e8 10             	shr    $0x10,%eax
f0104168:	66 a3 ce 42 1c f0    	mov    %ax,0xf01c42ce
	SETGATE(idt[16], 1, GD_KT, FPUerror_handler, 0);
f010416e:	b8 1c 4b 10 f0       	mov    $0xf0104b1c,%eax
f0104173:	66 a3 e0 42 1c f0    	mov    %ax,0xf01c42e0
f0104179:	66 c7 05 e2 42 1c f0 	movw   $0x8,0xf01c42e2
f0104180:	08 00 
f0104182:	c6 05 e4 42 1c f0 00 	movb   $0x0,0xf01c42e4
f0104189:	c6 05 e5 42 1c f0 8f 	movb   $0x8f,0xf01c42e5
f0104190:	c1 e8 10             	shr    $0x10,%eax
f0104193:	66 a3 e6 42 1c f0    	mov    %ax,0xf01c42e6
	SETGATE(idt[17], 1, GD_KT, alignmentcheck_handler, 0);
f0104199:	b8 22 4b 10 f0       	mov    $0xf0104b22,%eax
f010419e:	66 a3 e8 42 1c f0    	mov    %ax,0xf01c42e8
f01041a4:	66 c7 05 ea 42 1c f0 	movw   $0x8,0xf01c42ea
f01041ab:	08 00 
f01041ad:	c6 05 ec 42 1c f0 00 	movb   $0x0,0xf01c42ec
f01041b4:	c6 05 ed 42 1c f0 8f 	movb   $0x8f,0xf01c42ed
f01041bb:	c1 e8 10             	shr    $0x10,%eax
f01041be:	66 a3 ee 42 1c f0    	mov    %ax,0xf01c42ee
	SETGATE(idt[18],1, GD_KT, machinecheck_handler, 0);
f01041c4:	b8 26 4b 10 f0       	mov    $0xf0104b26,%eax
f01041c9:	66 a3 f0 42 1c f0    	mov    %ax,0xf01c42f0
f01041cf:	66 c7 05 f2 42 1c f0 	movw   $0x8,0xf01c42f2
f01041d6:	08 00 
f01041d8:	c6 05 f4 42 1c f0 00 	movb   $0x0,0xf01c42f4
f01041df:	c6 05 f5 42 1c f0 8f 	movb   $0x8f,0xf01c42f5
f01041e6:	c1 e8 10             	shr    $0x10,%eax
f01041e9:	66 a3 f6 42 1c f0    	mov    %ax,0xf01c42f6
	SETGATE(idt[19], 1, GD_KT, SIMDFPexception_handler, 0);
f01041ef:	b8 2c 4b 10 f0       	mov    $0xf0104b2c,%eax
f01041f4:	66 a3 f8 42 1c f0    	mov    %ax,0xf01c42f8
f01041fa:	66 c7 05 fa 42 1c f0 	movw   $0x8,0xf01c42fa
f0104201:	08 00 
f0104203:	c6 05 fc 42 1c f0 00 	movb   $0x0,0xf01c42fc
f010420a:	c6 05 fd 42 1c f0 8f 	movb   $0x8f,0xf01c42fd
f0104211:	c1 e8 10             	shr    $0x10,%eax
f0104214:	66 a3 fe 42 1c f0    	mov    %ax,0xf01c42fe
	SETGATE(idt[48], 0, GD_KT, systemcall_handler, 3);
f010421a:	b8 32 4b 10 f0       	mov    $0xf0104b32,%eax
f010421f:	66 a3 e0 43 1c f0    	mov    %ax,0xf01c43e0
f0104225:	66 c7 05 e2 43 1c f0 	movw   $0x8,0xf01c43e2
f010422c:	08 00 
f010422e:	c6 05 e4 43 1c f0 00 	movb   $0x0,0xf01c43e4
f0104235:	c6 05 e5 43 1c f0 ee 	movb   $0xee,0xf01c43e5
f010423c:	c1 e8 10             	shr    $0x10,%eax
f010423f:	66 a3 e6 43 1c f0    	mov    %ax,0xf01c43e6
	// LAB 3: Your code here.

	SETGATE(idt[IRQ_OFFSET + 0], 0, GD_KT, t_irq0, 0);
f0104245:	b8 38 4b 10 f0       	mov    $0xf0104b38,%eax
f010424a:	66 a3 60 43 1c f0    	mov    %ax,0xf01c4360
f0104250:	66 c7 05 62 43 1c f0 	movw   $0x8,0xf01c4362
f0104257:	08 00 
f0104259:	c6 05 64 43 1c f0 00 	movb   $0x0,0xf01c4364
f0104260:	c6 05 65 43 1c f0 8e 	movb   $0x8e,0xf01c4365
f0104267:	c1 e8 10             	shr    $0x10,%eax
f010426a:	66 a3 66 43 1c f0    	mov    %ax,0xf01c4366
	SETGATE(idt[IRQ_OFFSET + 1], 0, GD_KT, t_irq1, 0);
f0104270:	b8 3e 4b 10 f0       	mov    $0xf0104b3e,%eax
f0104275:	66 a3 68 43 1c f0    	mov    %ax,0xf01c4368
f010427b:	66 c7 05 6a 43 1c f0 	movw   $0x8,0xf01c436a
f0104282:	08 00 
f0104284:	c6 05 6c 43 1c f0 00 	movb   $0x0,0xf01c436c
f010428b:	c6 05 6d 43 1c f0 8e 	movb   $0x8e,0xf01c436d
f0104292:	c1 e8 10             	shr    $0x10,%eax
f0104295:	66 a3 6e 43 1c f0    	mov    %ax,0xf01c436e
	SETGATE(idt[IRQ_OFFSET + 2], 0, GD_KT, t_irq2, 0);
f010429b:	b8 44 4b 10 f0       	mov    $0xf0104b44,%eax
f01042a0:	66 a3 70 43 1c f0    	mov    %ax,0xf01c4370
f01042a6:	66 c7 05 72 43 1c f0 	movw   $0x8,0xf01c4372
f01042ad:	08 00 
f01042af:	c6 05 74 43 1c f0 00 	movb   $0x0,0xf01c4374
f01042b6:	c6 05 75 43 1c f0 8e 	movb   $0x8e,0xf01c4375
f01042bd:	c1 e8 10             	shr    $0x10,%eax
f01042c0:	66 a3 76 43 1c f0    	mov    %ax,0xf01c4376
	SETGATE(idt[IRQ_OFFSET + 3], 0, GD_KT, t_irq3, 0);
f01042c6:	b8 4a 4b 10 f0       	mov    $0xf0104b4a,%eax
f01042cb:	66 a3 78 43 1c f0    	mov    %ax,0xf01c4378
f01042d1:	66 c7 05 7a 43 1c f0 	movw   $0x8,0xf01c437a
f01042d8:	08 00 
f01042da:	c6 05 7c 43 1c f0 00 	movb   $0x0,0xf01c437c
f01042e1:	c6 05 7d 43 1c f0 8e 	movb   $0x8e,0xf01c437d
f01042e8:	c1 e8 10             	shr    $0x10,%eax
f01042eb:	66 a3 7e 43 1c f0    	mov    %ax,0xf01c437e
	SETGATE(idt[IRQ_OFFSET + 4], 0, GD_KT, t_irq4, 0);
f01042f1:	b8 50 4b 10 f0       	mov    $0xf0104b50,%eax
f01042f6:	66 a3 80 43 1c f0    	mov    %ax,0xf01c4380
f01042fc:	66 c7 05 82 43 1c f0 	movw   $0x8,0xf01c4382
f0104303:	08 00 
f0104305:	c6 05 84 43 1c f0 00 	movb   $0x0,0xf01c4384
f010430c:	c6 05 85 43 1c f0 8e 	movb   $0x8e,0xf01c4385
f0104313:	c1 e8 10             	shr    $0x10,%eax
f0104316:	66 a3 86 43 1c f0    	mov    %ax,0xf01c4386
	SETGATE(idt[IRQ_OFFSET + 5], 0, GD_KT, t_irq5, 0);
f010431c:	b8 56 4b 10 f0       	mov    $0xf0104b56,%eax
f0104321:	66 a3 88 43 1c f0    	mov    %ax,0xf01c4388
f0104327:	66 c7 05 8a 43 1c f0 	movw   $0x8,0xf01c438a
f010432e:	08 00 
f0104330:	c6 05 8c 43 1c f0 00 	movb   $0x0,0xf01c438c
f0104337:	c6 05 8d 43 1c f0 8e 	movb   $0x8e,0xf01c438d
f010433e:	c1 e8 10             	shr    $0x10,%eax
f0104341:	66 a3 8e 43 1c f0    	mov    %ax,0xf01c438e
	SETGATE(idt[IRQ_OFFSET + 6], 0, GD_KT, t_irq6, 0);
f0104347:	b8 5c 4b 10 f0       	mov    $0xf0104b5c,%eax
f010434c:	66 a3 90 43 1c f0    	mov    %ax,0xf01c4390
f0104352:	66 c7 05 92 43 1c f0 	movw   $0x8,0xf01c4392
f0104359:	08 00 
f010435b:	c6 05 94 43 1c f0 00 	movb   $0x0,0xf01c4394
f0104362:	c6 05 95 43 1c f0 8e 	movb   $0x8e,0xf01c4395
f0104369:	c1 e8 10             	shr    $0x10,%eax
f010436c:	66 a3 96 43 1c f0    	mov    %ax,0xf01c4396
	SETGATE(idt[IRQ_OFFSET + 7], 0, GD_KT, t_irq7, 0);
f0104372:	b8 62 4b 10 f0       	mov    $0xf0104b62,%eax
f0104377:	66 a3 98 43 1c f0    	mov    %ax,0xf01c4398
f010437d:	66 c7 05 9a 43 1c f0 	movw   $0x8,0xf01c439a
f0104384:	08 00 
f0104386:	c6 05 9c 43 1c f0 00 	movb   $0x0,0xf01c439c
f010438d:	c6 05 9d 43 1c f0 8e 	movb   $0x8e,0xf01c439d
f0104394:	c1 e8 10             	shr    $0x10,%eax
f0104397:	66 a3 9e 43 1c f0    	mov    %ax,0xf01c439e
	SETGATE(idt[IRQ_OFFSET + 8], 0, GD_KT, t_irq8, 0);
f010439d:	b8 68 4b 10 f0       	mov    $0xf0104b68,%eax
f01043a2:	66 a3 a0 43 1c f0    	mov    %ax,0xf01c43a0
f01043a8:	66 c7 05 a2 43 1c f0 	movw   $0x8,0xf01c43a2
f01043af:	08 00 
f01043b1:	c6 05 a4 43 1c f0 00 	movb   $0x0,0xf01c43a4
f01043b8:	c6 05 a5 43 1c f0 8e 	movb   $0x8e,0xf01c43a5
f01043bf:	c1 e8 10             	shr    $0x10,%eax
f01043c2:	66 a3 a6 43 1c f0    	mov    %ax,0xf01c43a6
	SETGATE(idt[IRQ_OFFSET + 9], 0, GD_KT, t_irq9, 0);
f01043c8:	b8 6e 4b 10 f0       	mov    $0xf0104b6e,%eax
f01043cd:	66 a3 a8 43 1c f0    	mov    %ax,0xf01c43a8
f01043d3:	66 c7 05 aa 43 1c f0 	movw   $0x8,0xf01c43aa
f01043da:	08 00 
f01043dc:	c6 05 ac 43 1c f0 00 	movb   $0x0,0xf01c43ac
f01043e3:	c6 05 ad 43 1c f0 8e 	movb   $0x8e,0xf01c43ad
f01043ea:	c1 e8 10             	shr    $0x10,%eax
f01043ed:	66 a3 ae 43 1c f0    	mov    %ax,0xf01c43ae
	SETGATE(idt[IRQ_OFFSET + 10], 0, GD_KT, t_irq10, 0);
f01043f3:	b8 74 4b 10 f0       	mov    $0xf0104b74,%eax
f01043f8:	66 a3 b0 43 1c f0    	mov    %ax,0xf01c43b0
f01043fe:	66 c7 05 b2 43 1c f0 	movw   $0x8,0xf01c43b2
f0104405:	08 00 
f0104407:	c6 05 b4 43 1c f0 00 	movb   $0x0,0xf01c43b4
f010440e:	c6 05 b5 43 1c f0 8e 	movb   $0x8e,0xf01c43b5
f0104415:	c1 e8 10             	shr    $0x10,%eax
f0104418:	66 a3 b6 43 1c f0    	mov    %ax,0xf01c43b6
	SETGATE(idt[IRQ_OFFSET + 11], 0, GD_KT, t_irq11, 0);
f010441e:	b8 7a 4b 10 f0       	mov    $0xf0104b7a,%eax
f0104423:	66 a3 b8 43 1c f0    	mov    %ax,0xf01c43b8
f0104429:	66 c7 05 ba 43 1c f0 	movw   $0x8,0xf01c43ba
f0104430:	08 00 
f0104432:	c6 05 bc 43 1c f0 00 	movb   $0x0,0xf01c43bc
f0104439:	c6 05 bd 43 1c f0 8e 	movb   $0x8e,0xf01c43bd
f0104440:	c1 e8 10             	shr    $0x10,%eax
f0104443:	66 a3 be 43 1c f0    	mov    %ax,0xf01c43be
	SETGATE(idt[IRQ_OFFSET + 12], 0, GD_KT, t_irq12, 0);
f0104449:	b8 80 4b 10 f0       	mov    $0xf0104b80,%eax
f010444e:	66 a3 c0 43 1c f0    	mov    %ax,0xf01c43c0
f0104454:	66 c7 05 c2 43 1c f0 	movw   $0x8,0xf01c43c2
f010445b:	08 00 
f010445d:	c6 05 c4 43 1c f0 00 	movb   $0x0,0xf01c43c4
f0104464:	c6 05 c5 43 1c f0 8e 	movb   $0x8e,0xf01c43c5
f010446b:	c1 e8 10             	shr    $0x10,%eax
f010446e:	66 a3 c6 43 1c f0    	mov    %ax,0xf01c43c6
	SETGATE(idt[IRQ_OFFSET + 13], 0, GD_KT, t_irq13, 0);
f0104474:	b8 86 4b 10 f0       	mov    $0xf0104b86,%eax
f0104479:	66 a3 c8 43 1c f0    	mov    %ax,0xf01c43c8
f010447f:	66 c7 05 ca 43 1c f0 	movw   $0x8,0xf01c43ca
f0104486:	08 00 
f0104488:	c6 05 cc 43 1c f0 00 	movb   $0x0,0xf01c43cc
f010448f:	c6 05 cd 43 1c f0 8e 	movb   $0x8e,0xf01c43cd
f0104496:	c1 e8 10             	shr    $0x10,%eax
f0104499:	66 a3 ce 43 1c f0    	mov    %ax,0xf01c43ce
	SETGATE(idt[IRQ_OFFSET + 14], 0, GD_KT, t_irq14, 0);
f010449f:	b8 8c 4b 10 f0       	mov    $0xf0104b8c,%eax
f01044a4:	66 a3 d0 43 1c f0    	mov    %ax,0xf01c43d0
f01044aa:	66 c7 05 d2 43 1c f0 	movw   $0x8,0xf01c43d2
f01044b1:	08 00 
f01044b3:	c6 05 d4 43 1c f0 00 	movb   $0x0,0xf01c43d4
f01044ba:	c6 05 d5 43 1c f0 8e 	movb   $0x8e,0xf01c43d5
f01044c1:	c1 e8 10             	shr    $0x10,%eax
f01044c4:	66 a3 d6 43 1c f0    	mov    %ax,0xf01c43d6
	SETGATE(idt[IRQ_OFFSET + 15], 0, GD_KT, t_irq15, 0);
f01044ca:	b8 92 4b 10 f0       	mov    $0xf0104b92,%eax
f01044cf:	66 a3 d8 43 1c f0    	mov    %ax,0xf01c43d8
f01044d5:	66 c7 05 da 43 1c f0 	movw   $0x8,0xf01c43da
f01044dc:	08 00 
f01044de:	c6 05 dc 43 1c f0 00 	movb   $0x0,0xf01c43dc
f01044e5:	c6 05 dd 43 1c f0 8e 	movb   $0x8e,0xf01c43dd
f01044ec:	c1 e8 10             	shr    $0x10,%eax
f01044ef:	66 a3 de 43 1c f0    	mov    %ax,0xf01c43de
	// Per-CPU setup 
	trap_init_percpu();
f01044f5:	e8 b6 f9 ff ff       	call   f0103eb0 <trap_init_percpu>
}
f01044fa:	c9                   	leave  
f01044fb:	c3                   	ret    

f01044fc <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f01044fc:	55                   	push   %ebp
f01044fd:	89 e5                	mov    %esp,%ebp
f01044ff:	53                   	push   %ebx
f0104500:	83 ec 14             	sub    $0x14,%esp
f0104503:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f0104506:	8b 03                	mov    (%ebx),%eax
f0104508:	89 44 24 04          	mov    %eax,0x4(%esp)
f010450c:	c7 04 24 6c 7d 10 f0 	movl   $0xf0107d6c,(%esp)
f0104513:	e8 7a f9 ff ff       	call   f0103e92 <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f0104518:	8b 43 04             	mov    0x4(%ebx),%eax
f010451b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010451f:	c7 04 24 7b 7d 10 f0 	movl   $0xf0107d7b,(%esp)
f0104526:	e8 67 f9 ff ff       	call   f0103e92 <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f010452b:	8b 43 08             	mov    0x8(%ebx),%eax
f010452e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104532:	c7 04 24 8a 7d 10 f0 	movl   $0xf0107d8a,(%esp)
f0104539:	e8 54 f9 ff ff       	call   f0103e92 <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f010453e:	8b 43 0c             	mov    0xc(%ebx),%eax
f0104541:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104545:	c7 04 24 99 7d 10 f0 	movl   $0xf0107d99,(%esp)
f010454c:	e8 41 f9 ff ff       	call   f0103e92 <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f0104551:	8b 43 10             	mov    0x10(%ebx),%eax
f0104554:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104558:	c7 04 24 a8 7d 10 f0 	movl   $0xf0107da8,(%esp)
f010455f:	e8 2e f9 ff ff       	call   f0103e92 <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0104564:	8b 43 14             	mov    0x14(%ebx),%eax
f0104567:	89 44 24 04          	mov    %eax,0x4(%esp)
f010456b:	c7 04 24 b7 7d 10 f0 	movl   $0xf0107db7,(%esp)
f0104572:	e8 1b f9 ff ff       	call   f0103e92 <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f0104577:	8b 43 18             	mov    0x18(%ebx),%eax
f010457a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010457e:	c7 04 24 c6 7d 10 f0 	movl   $0xf0107dc6,(%esp)
f0104585:	e8 08 f9 ff ff       	call   f0103e92 <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f010458a:	8b 43 1c             	mov    0x1c(%ebx),%eax
f010458d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104591:	c7 04 24 d5 7d 10 f0 	movl   $0xf0107dd5,(%esp)
f0104598:	e8 f5 f8 ff ff       	call   f0103e92 <cprintf>
}
f010459d:	83 c4 14             	add    $0x14,%esp
f01045a0:	5b                   	pop    %ebx
f01045a1:	5d                   	pop    %ebp
f01045a2:	c3                   	ret    

f01045a3 <print_trapframe>:
	lidt(&idt_pd);*/
}

void
print_trapframe(struct Trapframe *tf)
{
f01045a3:	55                   	push   %ebp
f01045a4:	89 e5                	mov    %esp,%ebp
f01045a6:	56                   	push   %esi
f01045a7:	53                   	push   %ebx
f01045a8:	83 ec 10             	sub    $0x10,%esp
f01045ab:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
f01045ae:	e8 f0 1f 00 00       	call   f01065a3 <cpunum>
f01045b3:	89 44 24 08          	mov    %eax,0x8(%esp)
f01045b7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01045bb:	c7 04 24 39 7e 10 f0 	movl   $0xf0107e39,(%esp)
f01045c2:	e8 cb f8 ff ff       	call   f0103e92 <cprintf>
	print_regs(&tf->tf_regs);
f01045c7:	89 1c 24             	mov    %ebx,(%esp)
f01045ca:	e8 2d ff ff ff       	call   f01044fc <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f01045cf:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f01045d3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01045d7:	c7 04 24 57 7e 10 f0 	movl   $0xf0107e57,(%esp)
f01045de:	e8 af f8 ff ff       	call   f0103e92 <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f01045e3:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f01045e7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01045eb:	c7 04 24 6a 7e 10 f0 	movl   $0xf0107e6a,(%esp)
f01045f2:	e8 9b f8 ff ff       	call   f0103e92 <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f01045f7:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f01045fa:	83 f8 13             	cmp    $0x13,%eax
f01045fd:	77 09                	ja     f0104608 <print_trapframe+0x65>
		return excnames[trapno];
f01045ff:	8b 14 85 00 81 10 f0 	mov    -0xfef7f00(,%eax,4),%edx
f0104606:	eb 1f                	jmp    f0104627 <print_trapframe+0x84>
	if (trapno == T_SYSCALL)
f0104608:	83 f8 30             	cmp    $0x30,%eax
f010460b:	74 15                	je     f0104622 <print_trapframe+0x7f>
		return "System call";
	if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16)
f010460d:	8d 50 e0             	lea    -0x20(%eax),%edx
		return "Hardware Interrupt";
f0104610:	83 fa 0f             	cmp    $0xf,%edx
f0104613:	ba f0 7d 10 f0       	mov    $0xf0107df0,%edx
f0104618:	b9 03 7e 10 f0       	mov    $0xf0107e03,%ecx
f010461d:	0f 47 d1             	cmova  %ecx,%edx
f0104620:	eb 05                	jmp    f0104627 <print_trapframe+0x84>
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
		return excnames[trapno];
	if (trapno == T_SYSCALL)
		return "System call";
f0104622:	ba e4 7d 10 f0       	mov    $0xf0107de4,%edx
{
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0104627:	89 54 24 08          	mov    %edx,0x8(%esp)
f010462b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010462f:	c7 04 24 7d 7e 10 f0 	movl   $0xf0107e7d,(%esp)
f0104636:	e8 57 f8 ff ff       	call   f0103e92 <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f010463b:	3b 1d 60 4a 1c f0    	cmp    0xf01c4a60,%ebx
f0104641:	75 19                	jne    f010465c <print_trapframe+0xb9>
f0104643:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104647:	75 13                	jne    f010465c <print_trapframe+0xb9>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f0104649:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f010464c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104650:	c7 04 24 8f 7e 10 f0 	movl   $0xf0107e8f,(%esp)
f0104657:	e8 36 f8 ff ff       	call   f0103e92 <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f010465c:	8b 43 2c             	mov    0x2c(%ebx),%eax
f010465f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104663:	c7 04 24 9e 7e 10 f0 	movl   $0xf0107e9e,(%esp)
f010466a:	e8 23 f8 ff ff       	call   f0103e92 <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f010466f:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104673:	75 51                	jne    f01046c6 <print_trapframe+0x123>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f0104675:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f0104678:	89 c2                	mov    %eax,%edx
f010467a:	83 e2 01             	and    $0x1,%edx
f010467d:	ba 12 7e 10 f0       	mov    $0xf0107e12,%edx
f0104682:	b9 1d 7e 10 f0       	mov    $0xf0107e1d,%ecx
f0104687:	0f 45 ca             	cmovne %edx,%ecx
f010468a:	89 c2                	mov    %eax,%edx
f010468c:	83 e2 02             	and    $0x2,%edx
f010468f:	ba 29 7e 10 f0       	mov    $0xf0107e29,%edx
f0104694:	be 2f 7e 10 f0       	mov    $0xf0107e2f,%esi
f0104699:	0f 44 d6             	cmove  %esi,%edx
f010469c:	83 e0 04             	and    $0x4,%eax
f010469f:	b8 34 7e 10 f0       	mov    $0xf0107e34,%eax
f01046a4:	be 50 7f 10 f0       	mov    $0xf0107f50,%esi
f01046a9:	0f 44 c6             	cmove  %esi,%eax
f01046ac:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01046b0:	89 54 24 08          	mov    %edx,0x8(%esp)
f01046b4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046b8:	c7 04 24 ac 7e 10 f0 	movl   $0xf0107eac,(%esp)
f01046bf:	e8 ce f7 ff ff       	call   f0103e92 <cprintf>
f01046c4:	eb 0c                	jmp    f01046d2 <print_trapframe+0x12f>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f01046c6:	c7 04 24 4a 7d 10 f0 	movl   $0xf0107d4a,(%esp)
f01046cd:	e8 c0 f7 ff ff       	call   f0103e92 <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f01046d2:	8b 43 30             	mov    0x30(%ebx),%eax
f01046d5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046d9:	c7 04 24 bb 7e 10 f0 	movl   $0xf0107ebb,(%esp)
f01046e0:	e8 ad f7 ff ff       	call   f0103e92 <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f01046e5:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f01046e9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046ed:	c7 04 24 ca 7e 10 f0 	movl   $0xf0107eca,(%esp)
f01046f4:	e8 99 f7 ff ff       	call   f0103e92 <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f01046f9:	8b 43 38             	mov    0x38(%ebx),%eax
f01046fc:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104700:	c7 04 24 dd 7e 10 f0 	movl   $0xf0107edd,(%esp)
f0104707:	e8 86 f7 ff ff       	call   f0103e92 <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f010470c:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f0104710:	74 27                	je     f0104739 <print_trapframe+0x196>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f0104712:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0104715:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104719:	c7 04 24 ec 7e 10 f0 	movl   $0xf0107eec,(%esp)
f0104720:	e8 6d f7 ff ff       	call   f0103e92 <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f0104725:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f0104729:	89 44 24 04          	mov    %eax,0x4(%esp)
f010472d:	c7 04 24 fb 7e 10 f0 	movl   $0xf0107efb,(%esp)
f0104734:	e8 59 f7 ff ff       	call   f0103e92 <cprintf>
	}
}
f0104739:	83 c4 10             	add    $0x10,%esp
f010473c:	5b                   	pop    %ebx
f010473d:	5e                   	pop    %esi
f010473e:	5d                   	pop    %ebp
f010473f:	c3                   	ret    

f0104740 <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f0104740:	55                   	push   %ebp
f0104741:	89 e5                	mov    %esp,%ebp
f0104743:	57                   	push   %edi
f0104744:	56                   	push   %esi
f0104745:	53                   	push   %ebx
f0104746:	83 ec 2c             	sub    $0x2c,%esp
f0104749:	8b 5d 08             	mov    0x8(%ebp),%ebx
f010474c:	0f 20 d0             	mov    %cr2,%eax
f010474f:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	uint32_t fault_va;

	// Read processor's CR2 register to find the faulting address
	fault_va = rcr2();
	if((tf->tf_cs & 0x3) != 3)
f0104752:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f0104756:	83 e0 03             	and    $0x3,%eax
f0104759:	66 83 f8 03          	cmp    $0x3,%ax
f010475d:	74 1c                	je     f010477b <page_fault_handler+0x3b>
		panic("page_fault_handler(): page fault at kernel-mode !");
f010475f:	c7 44 24 08 9c 80 10 	movl   $0xf010809c,0x8(%esp)
f0104766:	f0 
f0104767:	c7 44 24 04 78 01 00 	movl   $0x178,0x4(%esp)
f010476e:	00 
f010476f:	c7 04 24 0e 7f 10 f0 	movl   $0xf0107f0e,(%esp)
f0104776:	e8 c5 b8 ff ff       	call   f0100040 <_panic>
	//   user_mem_assert() and env_run() are useful here.
	//   To change what the user environment runs, modify 'curenv->env_tf'
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.
	if(curenv->env_pgfault_upcall == NULL){
f010477b:	e8 23 1e 00 00       	call   f01065a3 <cpunum>
f0104780:	6b c0 74             	imul   $0x74,%eax,%eax
f0104783:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f0104789:	83 78 64 00          	cmpl   $0x0,0x64(%eax)
f010478d:	75 4d                	jne    f01047dc <page_fault_handler+0x9c>
		// Destroy the environment that caused the fault.
		cprintf("[%08x] user fault va %08x ip %08x\n",
f010478f:	8b 73 30             	mov    0x30(%ebx),%esi
		curenv->env_id, fault_va, tf->tf_eip);
f0104792:	e8 0c 1e 00 00       	call   f01065a3 <cpunum>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.
	if(curenv->env_pgfault_upcall == NULL){
		// Destroy the environment that caused the fault.
		cprintf("[%08x] user fault va %08x ip %08x\n",
f0104797:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010479b:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f010479e:	89 7c 24 08          	mov    %edi,0x8(%esp)
		curenv->env_id, fault_va, tf->tf_eip);
f01047a2:	6b c0 74             	imul   $0x74,%eax,%eax
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.
	if(curenv->env_pgfault_upcall == NULL){
		// Destroy the environment that caused the fault.
		cprintf("[%08x] user fault va %08x ip %08x\n",
f01047a5:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f01047ab:	8b 40 48             	mov    0x48(%eax),%eax
f01047ae:	89 44 24 04          	mov    %eax,0x4(%esp)
f01047b2:	c7 04 24 d0 80 10 f0 	movl   $0xf01080d0,(%esp)
f01047b9:	e8 d4 f6 ff ff       	call   f0103e92 <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
		print_trapframe(tf);
f01047be:	89 1c 24             	mov    %ebx,(%esp)
f01047c1:	e8 dd fd ff ff       	call   f01045a3 <print_trapframe>
		env_destroy(curenv);
f01047c6:	e8 d8 1d 00 00       	call   f01065a3 <cpunum>
f01047cb:	6b c0 74             	imul   $0x74,%eax,%eax
f01047ce:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f01047d4:	89 04 24             	mov    %eax,(%esp)
f01047d7:	e8 04 f4 ff ff       	call   f0103be0 <env_destroy>
	}

	struct UTrapframe* utf;
	if(UXSTACKTOP - PGSIZE <= tf->tf_esp && tf->tf_esp < UXSTACKTOP) // an page_fault from user exception stack
f01047dc:	8b 43 3c             	mov    0x3c(%ebx),%eax
f01047df:	8d 90 00 10 40 11    	lea    0x11401000(%eax),%edx
	{
		utf = (struct UTrapframe*) (tf->tf_esp - sizeof (struct UTrapframe) - sizeof(uint32_t));
f01047e5:	83 e8 38             	sub    $0x38,%eax
f01047e8:	81 fa ff 0f 00 00    	cmp    $0xfff,%edx
f01047ee:	ba cc ff bf ee       	mov    $0xeebfffcc,%edx
f01047f3:	0f 46 d0             	cmovbe %eax,%edx
f01047f6:	89 d6                	mov    %edx,%esi
f01047f8:	89 55 e0             	mov    %edx,-0x20(%ebp)
	}
	else // an page_fault from normal user space
	{
		utf = (struct UTrapframe*) (UXSTACKTOP - sizeof(struct UTrapframe));
	}
	user_mem_assert(curenv, (void*) utf, sizeof (struct UTrapframe), PTE_U | PTE_W);
f01047fb:	e8 a3 1d 00 00       	call   f01065a3 <cpunum>
f0104800:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0104807:	00 
f0104808:	c7 44 24 08 34 00 00 	movl   $0x34,0x8(%esp)
f010480f:	00 
f0104810:	89 74 24 04          	mov    %esi,0x4(%esp)
f0104814:	6b c0 74             	imul   $0x74,%eax,%eax
f0104817:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f010481d:	89 04 24             	mov    %eax,(%esp)
f0104820:	e8 db ec ff ff       	call   f0103500 <user_mem_assert>
	
	// setup a stack
	utf->utf_eflags = tf->tf_eflags;
f0104825:	8b 43 38             	mov    0x38(%ebx),%eax
f0104828:	89 46 2c             	mov    %eax,0x2c(%esi)
	utf->utf_eip = tf->tf_eip;
f010482b:	8b 43 30             	mov    0x30(%ebx),%eax
f010482e:	89 46 28             	mov    %eax,0x28(%esi)
	utf->utf_esp = tf->tf_esp;
f0104831:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0104834:	89 46 30             	mov    %eax,0x30(%esi)
	utf->utf_regs = tf->tf_regs;
f0104837:	8d 7e 08             	lea    0x8(%esi),%edi
f010483a:	89 de                	mov    %ebx,%esi
f010483c:	b8 20 00 00 00       	mov    $0x20,%eax
f0104841:	f7 c7 01 00 00 00    	test   $0x1,%edi
f0104847:	74 03                	je     f010484c <page_fault_handler+0x10c>
f0104849:	a4                   	movsb  %ds:(%esi),%es:(%edi)
f010484a:	b0 1f                	mov    $0x1f,%al
f010484c:	f7 c7 02 00 00 00    	test   $0x2,%edi
f0104852:	74 05                	je     f0104859 <page_fault_handler+0x119>
f0104854:	66 a5                	movsw  %ds:(%esi),%es:(%edi)
f0104856:	83 e8 02             	sub    $0x2,%eax
f0104859:	89 c1                	mov    %eax,%ecx
f010485b:	c1 e9 02             	shr    $0x2,%ecx
f010485e:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0104860:	ba 00 00 00 00       	mov    $0x0,%edx
f0104865:	a8 02                	test   $0x2,%al
f0104867:	74 0b                	je     f0104874 <page_fault_handler+0x134>
f0104869:	0f b7 16             	movzwl (%esi),%edx
f010486c:	66 89 17             	mov    %dx,(%edi)
f010486f:	ba 02 00 00 00       	mov    $0x2,%edx
f0104874:	a8 01                	test   $0x1,%al
f0104876:	74 07                	je     f010487f <page_fault_handler+0x13f>
f0104878:	0f b6 04 16          	movzbl (%esi,%edx,1),%eax
f010487c:	88 04 17             	mov    %al,(%edi,%edx,1)
	utf->utf_err = tf->tf_err;
f010487f:	8b 43 2c             	mov    0x2c(%ebx),%eax
f0104882:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0104885:	89 47 04             	mov    %eax,0x4(%edi)
	utf->utf_fault_va = fault_va;
f0104888:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010488b:	89 07                	mov    %eax,(%edi)

	curenv->env_tf.tf_eip = (uint32_t)curenv->env_pgfault_upcall;
f010488d:	e8 11 1d 00 00       	call   f01065a3 <cpunum>
f0104892:	6b c0 74             	imul   $0x74,%eax,%eax
f0104895:	8b 98 28 50 1c f0    	mov    -0xfe3afd8(%eax),%ebx
f010489b:	e8 03 1d 00 00       	call   f01065a3 <cpunum>
f01048a0:	6b c0 74             	imul   $0x74,%eax,%eax
f01048a3:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f01048a9:	8b 40 64             	mov    0x64(%eax),%eax
f01048ac:	89 43 30             	mov    %eax,0x30(%ebx)
	curenv->env_tf.tf_esp = (uint32_t)utf;
f01048af:	e8 ef 1c 00 00       	call   f01065a3 <cpunum>
f01048b4:	6b c0 74             	imul   $0x74,%eax,%eax
f01048b7:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f01048bd:	89 78 3c             	mov    %edi,0x3c(%eax)

	env_run(curenv);
f01048c0:	e8 de 1c 00 00       	call   f01065a3 <cpunum>
f01048c5:	6b c0 74             	imul   $0x74,%eax,%eax
f01048c8:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f01048ce:	89 04 24             	mov    %eax,(%esp)
f01048d1:	e8 ab f3 ff ff       	call   f0103c81 <env_run>

f01048d6 <trap>:



void
trap(struct Trapframe *tf)
{
f01048d6:	55                   	push   %ebp
f01048d7:	89 e5                	mov    %esp,%ebp
f01048d9:	57                   	push   %edi
f01048da:	56                   	push   %esi
f01048db:	83 ec 20             	sub    $0x20,%esp
f01048de:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f01048e1:	fc                   	cld    

	// Halt the CPU if some other CPU has called panic()
	extern char *panicstr;
	if (panicstr)
f01048e2:	83 3d 80 4e 1c f0 00 	cmpl   $0x0,0xf01c4e80
f01048e9:	74 01                	je     f01048ec <trap+0x16>
		asm volatile("hlt");
f01048eb:	f4                   	hlt    
	// the interrupt path.
	//assert(!(read_eflags() & FL_IF));
	
	//cprintf("Incoming TRAP frame at %p\n", tf);

	if ((tf->tf_cs & 3) == 3) {
f01048ec:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f01048f0:	83 e0 03             	and    $0x3,%eax
f01048f3:	66 83 f8 03          	cmp    $0x3,%ax
f01048f7:	0f 85 a7 00 00 00    	jne    f01049a4 <trap+0xce>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f01048fd:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f0104904:	e8 00 1f 00 00       	call   f0106809 <spin_lock>
		// serious kernel work.
		// LAB 4: Your code here.
		//if(tf->tf_cs!=GD_KT){
		lock_kernel();
		//}
		assert(curenv);
f0104909:	e8 95 1c 00 00       	call   f01065a3 <cpunum>
f010490e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104911:	83 b8 28 50 1c f0 00 	cmpl   $0x0,-0xfe3afd8(%eax)
f0104918:	75 24                	jne    f010493e <trap+0x68>
f010491a:	c7 44 24 0c 1a 7f 10 	movl   $0xf0107f1a,0xc(%esp)
f0104921:	f0 
f0104922:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0104929:	f0 
f010492a:	c7 44 24 04 4e 01 00 	movl   $0x14e,0x4(%esp)
f0104931:	00 
f0104932:	c7 04 24 0e 7f 10 f0 	movl   $0xf0107f0e,(%esp)
f0104939:	e8 02 b7 ff ff       	call   f0100040 <_panic>

		// Garbage collect if current enviroment is a zombie
		if (curenv->env_status == ENV_DYING) {
f010493e:	e8 60 1c 00 00       	call   f01065a3 <cpunum>
f0104943:	6b c0 74             	imul   $0x74,%eax,%eax
f0104946:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f010494c:	83 78 54 01          	cmpl   $0x1,0x54(%eax)
f0104950:	75 2d                	jne    f010497f <trap+0xa9>
			env_free(curenv);
f0104952:	e8 4c 1c 00 00       	call   f01065a3 <cpunum>
f0104957:	6b c0 74             	imul   $0x74,%eax,%eax
f010495a:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f0104960:	89 04 24             	mov    %eax,(%esp)
f0104963:	e8 ad f0 ff ff       	call   f0103a15 <env_free>
			curenv = NULL;
f0104968:	e8 36 1c 00 00       	call   f01065a3 <cpunum>
f010496d:	6b c0 74             	imul   $0x74,%eax,%eax
f0104970:	c7 80 28 50 1c f0 00 	movl   $0x0,-0xfe3afd8(%eax)
f0104977:	00 00 00 
			sched_yield();
f010497a:	e8 41 02 00 00       	call   f0104bc0 <sched_yield>
		}

		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		curenv->env_tf = *tf;
f010497f:	e8 1f 1c 00 00       	call   f01065a3 <cpunum>
f0104984:	6b c0 74             	imul   $0x74,%eax,%eax
f0104987:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f010498d:	b9 11 00 00 00       	mov    $0x11,%ecx
f0104992:	89 c7                	mov    %eax,%edi
f0104994:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f0104996:	e8 08 1c 00 00       	call   f01065a3 <cpunum>
f010499b:	6b c0 74             	imul   $0x74,%eax,%eax
f010499e:	8b b0 28 50 1c f0    	mov    -0xfe3afd8(%eax),%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f01049a4:	89 35 60 4a 1c f0    	mov    %esi,0xf01c4a60
	// LAB 3: Your code here.

	// Handle spurious interrupts
	// The hardware sometimes raises these because of noise on the
	// IRQ line or other reasons. We don't care.
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_SPURIOUS) {
f01049aa:	8b 46 28             	mov    0x28(%esi),%eax
f01049ad:	83 f8 27             	cmp    $0x27,%eax
f01049b0:	75 19                	jne    f01049cb <trap+0xf5>
		cprintf("Spurious interrupt on irq 7\n");
f01049b2:	c7 04 24 21 7f 10 f0 	movl   $0xf0107f21,(%esp)
f01049b9:	e8 d4 f4 ff ff       	call   f0103e92 <cprintf>
		print_trapframe(tf);
f01049be:	89 34 24             	mov    %esi,(%esp)
f01049c1:	e8 dd fb ff ff       	call   f01045a3 <print_trapframe>
f01049c6:	e9 9e 00 00 00       	jmp    f0104a69 <trap+0x193>
		return;
	}
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_TIMER) {
f01049cb:	83 f8 20             	cmp    $0x20,%eax
f01049ce:	66 90                	xchg   %ax,%ax
f01049d0:	75 0a                	jne    f01049dc <trap+0x106>
        		lapic_eoi();
f01049d2:	e8 01 1d 00 00       	call   f01066d8 <lapic_eoi>
        		sched_yield();
f01049d7:	e8 e4 01 00 00       	call   f0104bc0 <sched_yield>
  	  }
	// Handle clock interrupts. Don't forget to acknowledge the
	// interrupt using lapic_eoi() before calling the scheduler!
	// LAB 4: Your code here.

	if(tf->tf_trapno==T_PGFLT)
f01049dc:	83 f8 0e             	cmp    $0xe,%eax
f01049df:	90                   	nop
f01049e0:	75 08                	jne    f01049ea <trap+0x114>
	{
		page_fault_handler(tf);
f01049e2:	89 34 24             	mov    %esi,(%esp)
f01049e5:	e8 56 fd ff ff       	call   f0104740 <page_fault_handler>
		return;
	}
	if(tf->tf_trapno==T_BRKPT)
f01049ea:	83 f8 03             	cmp    $0x3,%eax
f01049ed:	75 0a                	jne    f01049f9 <trap+0x123>
	{
		monitor(tf);
f01049ef:	89 34 24             	mov    %esi,(%esp)
f01049f2:	e8 0b c0 ff ff       	call   f0100a02 <monitor>
f01049f7:	eb 70                	jmp    f0104a69 <trap+0x193>
		return;
	}
	if(tf->tf_trapno==T_SYSCALL)
f01049f9:	83 f8 30             	cmp    $0x30,%eax
f01049fc:	75 32                	jne    f0104a30 <trap+0x15a>
	{
		tf->tf_regs.reg_eax=syscall(tf->tf_regs.reg_eax,tf->tf_regs.reg_edx,tf->tf_regs.reg_ecx,tf->tf_regs.reg_ebx,tf->tf_regs.reg_edi,tf->tf_regs.reg_esi);
f01049fe:	8b 46 04             	mov    0x4(%esi),%eax
f0104a01:	89 44 24 14          	mov    %eax,0x14(%esp)
f0104a05:	8b 06                	mov    (%esi),%eax
f0104a07:	89 44 24 10          	mov    %eax,0x10(%esp)
f0104a0b:	8b 46 10             	mov    0x10(%esi),%eax
f0104a0e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104a12:	8b 46 18             	mov    0x18(%esi),%eax
f0104a15:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104a19:	8b 46 14             	mov    0x14(%esi),%eax
f0104a1c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104a20:	8b 46 1c             	mov    0x1c(%esi),%eax
f0104a23:	89 04 24             	mov    %eax,(%esp)
f0104a26:	e8 b5 02 00 00       	call   f0104ce0 <syscall>
f0104a2b:	89 46 1c             	mov    %eax,0x1c(%esi)
f0104a2e:	eb 39                	jmp    f0104a69 <trap+0x193>
	    return;
	}
	// Unexpected trap: The user process or the kernel has a bug.

	if (tf->tf_cs == GD_KT)
f0104a30:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f0104a35:	75 1c                	jne    f0104a53 <trap+0x17d>
		panic("unhandled trap in kernel");
f0104a37:	c7 44 24 08 3e 7f 10 	movl   $0xf0107f3e,0x8(%esp)
f0104a3e:	f0 
f0104a3f:	c7 44 24 04 2a 01 00 	movl   $0x12a,0x4(%esp)
f0104a46:	00 
f0104a47:	c7 04 24 0e 7f 10 f0 	movl   $0xf0107f0e,(%esp)
f0104a4e:	e8 ed b5 ff ff       	call   f0100040 <_panic>
	else {
		env_destroy(curenv);
f0104a53:	e8 4b 1b 00 00       	call   f01065a3 <cpunum>
f0104a58:	6b c0 74             	imul   $0x74,%eax,%eax
f0104a5b:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f0104a61:	89 04 24             	mov    %eax,(%esp)
f0104a64:	e8 77 f1 ff ff       	call   f0103be0 <env_destroy>
	trap_dispatch(tf);

	// If we made it to this point, then no other environment was
	// scheduled, so we should return to the current environment
	// if doing so makes sense.
	if (curenv && curenv->env_status == ENV_RUNNING)
f0104a69:	e8 35 1b 00 00       	call   f01065a3 <cpunum>
f0104a6e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104a71:	83 b8 28 50 1c f0 00 	cmpl   $0x0,-0xfe3afd8(%eax)
f0104a78:	74 2a                	je     f0104aa4 <trap+0x1ce>
f0104a7a:	e8 24 1b 00 00       	call   f01065a3 <cpunum>
f0104a7f:	6b c0 74             	imul   $0x74,%eax,%eax
f0104a82:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f0104a88:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0104a8c:	75 16                	jne    f0104aa4 <trap+0x1ce>
		env_run(curenv);
f0104a8e:	e8 10 1b 00 00       	call   f01065a3 <cpunum>
f0104a93:	6b c0 74             	imul   $0x74,%eax,%eax
f0104a96:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f0104a9c:	89 04 24             	mov    %eax,(%esp)
f0104a9f:	e8 dd f1 ff ff       	call   f0103c81 <env_run>
	else
		sched_yield();
f0104aa4:	e8 17 01 00 00       	call   f0104bc0 <sched_yield>
f0104aa9:	90                   	nop

f0104aaa <dividezero_handler>:
.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
f0104aaa:	6a 00                	push   $0x0
f0104aac:	6a 00                	push   $0x0
f0104aae:	e9 e5 00 00 00       	jmp    f0104b98 <_alltraps>
f0104ab3:	90                   	nop

f0104ab4 <nmi_handler>:
TRAPHANDLER_NOEC(nmi_handler, 0x2)
f0104ab4:	6a 00                	push   $0x0
f0104ab6:	6a 02                	push   $0x2
f0104ab8:	e9 db 00 00 00       	jmp    f0104b98 <_alltraps>
f0104abd:	90                   	nop

f0104abe <breakpoint_handler>:
TRAPHANDLER_NOEC(breakpoint_handler, 0x3)
f0104abe:	6a 00                	push   $0x0
f0104ac0:	6a 03                	push   $0x3
f0104ac2:	e9 d1 00 00 00       	jmp    f0104b98 <_alltraps>
f0104ac7:	90                   	nop

f0104ac8 <overflow_handler>:
TRAPHANDLER_NOEC(overflow_handler, 0x4)
f0104ac8:	6a 00                	push   $0x0
f0104aca:	6a 04                	push   $0x4
f0104acc:	e9 c7 00 00 00       	jmp    f0104b98 <_alltraps>
f0104ad1:	90                   	nop

f0104ad2 <bdrgeexceed_handler>:
TRAPHANDLER_NOEC(bdrgeexceed_handler, 0x5)
f0104ad2:	6a 00                	push   $0x0
f0104ad4:	6a 05                	push   $0x5
f0104ad6:	e9 bd 00 00 00       	jmp    f0104b98 <_alltraps>
f0104adb:	90                   	nop

f0104adc <invalidop_handler>:
TRAPHANDLER_NOEC(invalidop_handler, 0x6)
f0104adc:	6a 00                	push   $0x0
f0104ade:	6a 06                	push   $0x6
f0104ae0:	e9 b3 00 00 00       	jmp    f0104b98 <_alltraps>
f0104ae5:	90                   	nop

f0104ae6 <nomathcopro_handler>:
TRAPHANDLER_NOEC(nomathcopro_handler, 0x7)
f0104ae6:	6a 00                	push   $0x0
f0104ae8:	6a 07                	push   $0x7
f0104aea:	e9 a9 00 00 00       	jmp    f0104b98 <_alltraps>
f0104aef:	90                   	nop

f0104af0 <dbfault_handler>:
TRAPHANDLER(dbfault_handler, 0x8)
f0104af0:	6a 08                	push   $0x8
f0104af2:	e9 a1 00 00 00       	jmp    f0104b98 <_alltraps>
f0104af7:	90                   	nop

f0104af8 <invalidTSS_handler>:
TRAPHANDLER(invalidTSS_handler, 0xA)
f0104af8:	6a 0a                	push   $0xa
f0104afa:	e9 99 00 00 00       	jmp    f0104b98 <_alltraps>
f0104aff:	90                   	nop

f0104b00 <sgmtnotpresent_handler>:
TRAPHANDLER(sgmtnotpresent_handler, 0xB)
f0104b00:	6a 0b                	push   $0xb
f0104b02:	e9 91 00 00 00       	jmp    f0104b98 <_alltraps>
f0104b07:	90                   	nop

f0104b08 <stacksgmtfault_handler>:
TRAPHANDLER(stacksgmtfault_handler,0xC)
f0104b08:	6a 0c                	push   $0xc
f0104b0a:	e9 89 00 00 00       	jmp    f0104b98 <_alltraps>
f0104b0f:	90                   	nop

f0104b10 <generalprotection_handler>:
TRAPHANDLER(generalprotection_handler, 0xD)
f0104b10:	6a 0d                	push   $0xd
f0104b12:	e9 81 00 00 00       	jmp    f0104b98 <_alltraps>
f0104b17:	90                   	nop

f0104b18 <pagefault_handler>:
TRAPHANDLER(pagefault_handler, 0xE)
f0104b18:	6a 0e                	push   $0xe
f0104b1a:	eb 7c                	jmp    f0104b98 <_alltraps>

f0104b1c <FPUerror_handler>:
TRAPHANDLER_NOEC(FPUerror_handler, 0x10)
f0104b1c:	6a 00                	push   $0x0
f0104b1e:	6a 10                	push   $0x10
f0104b20:	eb 76                	jmp    f0104b98 <_alltraps>

f0104b22 <alignmentcheck_handler>:
TRAPHANDLER(alignmentcheck_handler, 0x11)
f0104b22:	6a 11                	push   $0x11
f0104b24:	eb 72                	jmp    f0104b98 <_alltraps>

f0104b26 <machinecheck_handler>:
TRAPHANDLER_NOEC(machinecheck_handler, 0x12)
f0104b26:	6a 00                	push   $0x0
f0104b28:	6a 12                	push   $0x12
f0104b2a:	eb 6c                	jmp    f0104b98 <_alltraps>

f0104b2c <SIMDFPexception_handler>:
TRAPHANDLER_NOEC(SIMDFPexception_handler, 0x13)
f0104b2c:	6a 00                	push   $0x0
f0104b2e:	6a 13                	push   $0x13
f0104b30:	eb 66                	jmp    f0104b98 <_alltraps>

f0104b32 <systemcall_handler>:
TRAPHANDLER_NOEC(systemcall_handler, 0x30)
f0104b32:	6a 00                	push   $0x0
f0104b34:	6a 30                	push   $0x30
f0104b36:	eb 60                	jmp    f0104b98 <_alltraps>

f0104b38 <t_irq0>:


TRAPHANDLER_NOEC(t_irq0, IRQ_OFFSET + 0);
f0104b38:	6a 00                	push   $0x0
f0104b3a:	6a 20                	push   $0x20
f0104b3c:	eb 5a                	jmp    f0104b98 <_alltraps>

f0104b3e <t_irq1>:
TRAPHANDLER_NOEC(t_irq1, IRQ_OFFSET + 1);
f0104b3e:	6a 00                	push   $0x0
f0104b40:	6a 21                	push   $0x21
f0104b42:	eb 54                	jmp    f0104b98 <_alltraps>

f0104b44 <t_irq2>:
TRAPHANDLER_NOEC(t_irq2, IRQ_OFFSET + 2);
f0104b44:	6a 00                	push   $0x0
f0104b46:	6a 22                	push   $0x22
f0104b48:	eb 4e                	jmp    f0104b98 <_alltraps>

f0104b4a <t_irq3>:
TRAPHANDLER_NOEC(t_irq3, IRQ_OFFSET + 3);
f0104b4a:	6a 00                	push   $0x0
f0104b4c:	6a 23                	push   $0x23
f0104b4e:	eb 48                	jmp    f0104b98 <_alltraps>

f0104b50 <t_irq4>:
TRAPHANDLER_NOEC(t_irq4, IRQ_OFFSET + 4);
f0104b50:	6a 00                	push   $0x0
f0104b52:	6a 24                	push   $0x24
f0104b54:	eb 42                	jmp    f0104b98 <_alltraps>

f0104b56 <t_irq5>:
TRAPHANDLER_NOEC(t_irq5, IRQ_OFFSET + 5);
f0104b56:	6a 00                	push   $0x0
f0104b58:	6a 25                	push   $0x25
f0104b5a:	eb 3c                	jmp    f0104b98 <_alltraps>

f0104b5c <t_irq6>:
TRAPHANDLER_NOEC(t_irq6, IRQ_OFFSET + 6);
f0104b5c:	6a 00                	push   $0x0
f0104b5e:	6a 26                	push   $0x26
f0104b60:	eb 36                	jmp    f0104b98 <_alltraps>

f0104b62 <t_irq7>:
TRAPHANDLER_NOEC(t_irq7, IRQ_OFFSET + 7);
f0104b62:	6a 00                	push   $0x0
f0104b64:	6a 27                	push   $0x27
f0104b66:	eb 30                	jmp    f0104b98 <_alltraps>

f0104b68 <t_irq8>:
TRAPHANDLER_NOEC(t_irq8, IRQ_OFFSET + 8);
f0104b68:	6a 00                	push   $0x0
f0104b6a:	6a 28                	push   $0x28
f0104b6c:	eb 2a                	jmp    f0104b98 <_alltraps>

f0104b6e <t_irq9>:
TRAPHANDLER_NOEC(t_irq9, IRQ_OFFSET + 9);
f0104b6e:	6a 00                	push   $0x0
f0104b70:	6a 29                	push   $0x29
f0104b72:	eb 24                	jmp    f0104b98 <_alltraps>

f0104b74 <t_irq10>:
TRAPHANDLER_NOEC(t_irq10, IRQ_OFFSET + 10);
f0104b74:	6a 00                	push   $0x0
f0104b76:	6a 2a                	push   $0x2a
f0104b78:	eb 1e                	jmp    f0104b98 <_alltraps>

f0104b7a <t_irq11>:
TRAPHANDLER_NOEC(t_irq11, IRQ_OFFSET + 11);
f0104b7a:	6a 00                	push   $0x0
f0104b7c:	6a 2b                	push   $0x2b
f0104b7e:	eb 18                	jmp    f0104b98 <_alltraps>

f0104b80 <t_irq12>:
TRAPHANDLER_NOEC(t_irq12, IRQ_OFFSET + 12);
f0104b80:	6a 00                	push   $0x0
f0104b82:	6a 2c                	push   $0x2c
f0104b84:	eb 12                	jmp    f0104b98 <_alltraps>

f0104b86 <t_irq13>:
TRAPHANDLER_NOEC(t_irq13, IRQ_OFFSET + 13);
f0104b86:	6a 00                	push   $0x0
f0104b88:	6a 2d                	push   $0x2d
f0104b8a:	eb 0c                	jmp    f0104b98 <_alltraps>

f0104b8c <t_irq14>:
TRAPHANDLER_NOEC(t_irq14, IRQ_OFFSET + 14);
f0104b8c:	6a 00                	push   $0x0
f0104b8e:	6a 2e                	push   $0x2e
f0104b90:	eb 06                	jmp    f0104b98 <_alltraps>

f0104b92 <t_irq15>:
TRAPHANDLER_NOEC(t_irq15, IRQ_OFFSET + 15);
f0104b92:	6a 00                	push   $0x0
f0104b94:	6a 2f                	push   $0x2f
f0104b96:	eb 00                	jmp    f0104b98 <_alltraps>

f0104b98 <_alltraps>:
/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
	pushw $0
f0104b98:	66 6a 00             	pushw  $0x0
	pushw %ds
f0104b9b:	66 1e                	pushw  %ds
	pushw $0
f0104b9d:	66 6a 00             	pushw  $0x0
	pushw %es
f0104ba0:	66 06                	pushw  %es
	pushal
f0104ba2:	60                   	pusha  
	pushl %esp
f0104ba3:	54                   	push   %esp
	movw $(GD_KD),%ax
f0104ba4:	66 b8 10 00          	mov    $0x10,%ax
	movw %ax,%ds
f0104ba8:	8e d8                	mov    %eax,%ds
	movw %ax,%es
f0104baa:	8e c0                	mov    %eax,%es
	call trap
f0104bac:	e8 25 fd ff ff       	call   f01048d6 <trap>
f0104bb1:	66 90                	xchg   %ax,%ax
f0104bb3:	66 90                	xchg   %ax,%ax
f0104bb5:	66 90                	xchg   %ax,%ax
f0104bb7:	66 90                	xchg   %ax,%ax
f0104bb9:	66 90                	xchg   %ax,%ax
f0104bbb:	66 90                	xchg   %ax,%ax
f0104bbd:	66 90                	xchg   %ax,%ax
f0104bbf:	90                   	nop

f0104bc0 <sched_yield>:
#include <kern/monitor.h>

// Choose a user environment to run and run it.
void
sched_yield(void)
{
f0104bc0:	55                   	push   %ebp
f0104bc1:	89 e5                	mov    %esp,%ebp
f0104bc3:	57                   	push   %edi
f0104bc4:	56                   	push   %esi
f0104bc5:	53                   	push   %ebx
f0104bc6:	83 ec 1c             	sub    $0x1c,%esp
	// Search through 'envs' for an ENV_RUNNABLE environment in
	// circular fashion starting just after the env this CPU was
	// last running.  Switch to the first such environment found.
	//
	int start;
	struct Env * curr = thiscpu->cpu_env;
f0104bc9:	e8 d5 19 00 00       	call   f01065a3 <cpunum>
f0104bce:	6b c0 74             	imul   $0x74,%eax,%eax
f0104bd1:	8b b0 28 50 1c f0    	mov    -0xfe3afd8(%eax),%esi
	if(curr == NULL){
f0104bd7:	85 f6                	test   %esi,%esi
f0104bd9:	0f 84 df 00 00 00    	je     f0104cbe <sched_yield+0xfe>
		start = 0;
	}else{
		start = ENVX(curr->env_id ) ;
f0104bdf:	8b 7e 48             	mov    0x48(%esi),%edi
f0104be2:	81 e7 ff 03 00 00    	and    $0x3ff,%edi
f0104be8:	e9 d6 00 00 00       	jmp    f0104cc3 <sched_yield+0x103>
	}
	for(i=1;i<NENV;i++){
		start = (start+1) % NENV;
f0104bed:	8d 47 01             	lea    0x1(%edi),%eax
f0104bf0:	99                   	cltd   
f0104bf1:	c1 ea 16             	shr    $0x16,%edx
f0104bf4:	01 d0                	add    %edx,%eax
f0104bf6:	25 ff 03 00 00       	and    $0x3ff,%eax
f0104bfb:	29 d0                	sub    %edx,%eax
f0104bfd:	89 c7                	mov    %eax,%edi
		if (envs[start].env_type != ENV_TYPE_IDLE && (envs[start].env_status == ENV_RUNNABLE )){
f0104bff:	6b c0 7c             	imul   $0x7c,%eax,%eax
f0104c02:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f0104c05:	83 7a 50 01          	cmpl   $0x1,0x50(%edx)
f0104c09:	74 0e                	je     f0104c19 <sched_yield+0x59>
f0104c0b:	83 7a 54 02          	cmpl   $0x2,0x54(%edx)
f0104c0f:	75 08                	jne    f0104c19 <sched_yield+0x59>
			env_run(&envs[start]);
f0104c11:	89 14 24             	mov    %edx,(%esp)
f0104c14:	e8 68 f0 ff ff       	call   f0103c81 <env_run>
	if(curr == NULL){
		start = 0;
	}else{
		start = ENVX(curr->env_id ) ;
	}
	for(i=1;i<NENV;i++){
f0104c19:	83 e9 01             	sub    $0x1,%ecx
f0104c1c:	75 cf                	jne    f0104bed <sched_yield+0x2d>
		start = (start+1) % NENV;
		if (envs[start].env_type != ENV_TYPE_IDLE && (envs[start].env_status == ENV_RUNNABLE )){
			env_run(&envs[start]);
		}
	}
	 if (curr && curr->env_status == ENV_RUNNING) {
f0104c1e:	85 f6                	test   %esi,%esi
f0104c20:	74 06                	je     f0104c28 <sched_yield+0x68>
f0104c22:	83 7e 54 03          	cmpl   $0x3,0x54(%esi)
f0104c26:	74 09                	je     f0104c31 <sched_yield+0x71>
f0104c28:	89 d8                	mov    %ebx,%eax
	}else{
		start = ENVX(curr->env_id ) ;
	}
	for(i=1;i<NENV;i++){
		start = (start+1) % NENV;
		if (envs[start].env_type != ENV_TYPE_IDLE && (envs[start].env_status == ENV_RUNNABLE )){
f0104c2a:	ba 00 00 00 00       	mov    $0x0,%edx
f0104c2f:	eb 08                	jmp    f0104c39 <sched_yield+0x79>
			env_run(&envs[start]);
		}
	}
	 if (curr && curr->env_status == ENV_RUNNING) {
       		 env_run(curr);
f0104c31:	89 34 24             	mov    %esi,(%esp)
f0104c34:	e8 48 f0 ff ff       	call   f0103c81 <env_run>

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104c39:	83 78 50 01          	cmpl   $0x1,0x50(%eax)
f0104c3d:	74 0b                	je     f0104c4a <sched_yield+0x8a>
		    (envs[i].env_status == ENV_RUNNABLE ||
f0104c3f:	8b 70 54             	mov    0x54(%eax),%esi
f0104c42:	8d 4e fe             	lea    -0x2(%esi),%ecx

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104c45:	83 f9 01             	cmp    $0x1,%ecx
f0104c48:	76 10                	jbe    f0104c5a <sched_yield+0x9a>
	// LAB 4: Your code here.

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0104c4a:	83 c2 01             	add    $0x1,%edx
f0104c4d:	83 c0 7c             	add    $0x7c,%eax
f0104c50:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104c56:	75 e1                	jne    f0104c39 <sched_yield+0x79>
f0104c58:	eb 08                	jmp    f0104c62 <sched_yield+0xa2>
		if (envs[i].env_type != ENV_TYPE_IDLE &&
		    (envs[i].env_status == ENV_RUNNABLE ||
		     envs[i].env_status == ENV_RUNNING))
			break;
	}
	if (i == NENV) {
f0104c5a:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104c60:	75 1a                	jne    f0104c7c <sched_yield+0xbc>
		cprintf("No more runnable environments!\n");
f0104c62:	c7 04 24 50 81 10 f0 	movl   $0xf0108150,(%esp)
f0104c69:	e8 24 f2 ff ff       	call   f0103e92 <cprintf>
		while (1)
			monitor(NULL);
f0104c6e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0104c75:	e8 88 bd ff ff       	call   f0100a02 <monitor>
f0104c7a:	eb f2                	jmp    f0104c6e <sched_yield+0xae>
	}

	// Run this CPU's idle environment when nothing else is runnable.
	idle = &envs[cpunum()];
f0104c7c:	e8 22 19 00 00       	call   f01065a3 <cpunum>
f0104c81:	6b c0 7c             	imul   $0x7c,%eax,%eax
f0104c84:	01 c3                	add    %eax,%ebx
	if (!(idle->env_status == ENV_RUNNABLE || idle->env_status == ENV_RUNNING))
f0104c86:	8b 43 54             	mov    0x54(%ebx),%eax
f0104c89:	83 e8 02             	sub    $0x2,%eax
f0104c8c:	83 f8 01             	cmp    $0x1,%eax
f0104c8f:	76 25                	jbe    f0104cb6 <sched_yield+0xf6>
		panic("CPU %d: No idle environment!", cpunum());
f0104c91:	e8 0d 19 00 00       	call   f01065a3 <cpunum>
f0104c96:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104c9a:	c7 44 24 08 70 81 10 	movl   $0xf0108170,0x8(%esp)
f0104ca1:	f0 
f0104ca2:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
f0104ca9:	00 
f0104caa:	c7 04 24 8d 81 10 f0 	movl   $0xf010818d,(%esp)
f0104cb1:	e8 8a b3 ff ff       	call   f0100040 <_panic>
	env_run(idle);
f0104cb6:	89 1c 24             	mov    %ebx,(%esp)
f0104cb9:	e8 c3 ef ff ff       	call   f0103c81 <env_run>
	// last running.  Switch to the first such environment found.
	//
	int start;
	struct Env * curr = thiscpu->cpu_env;
	if(curr == NULL){
		start = 0;
f0104cbe:	bf 00 00 00 00       	mov    $0x0,%edi
	}else{
		start = ENVX(curr->env_id ) ;
	}
	for(i=1;i<NENV;i++){
		start = (start+1) % NENV;
		if (envs[start].env_type != ENV_TYPE_IDLE && (envs[start].env_status == ENV_RUNNABLE )){
f0104cc3:	8b 1d 48 42 1c f0    	mov    0xf01c4248,%ebx
f0104cc9:	b9 ff 03 00 00       	mov    $0x3ff,%ecx
f0104cce:	e9 1a ff ff ff       	jmp    f0104bed <sched_yield+0x2d>
f0104cd3:	66 90                	xchg   %ax,%ax
f0104cd5:	66 90                	xchg   %ax,%ax
f0104cd7:	66 90                	xchg   %ax,%ax
f0104cd9:	66 90                	xchg   %ax,%ax
f0104cdb:	66 90                	xchg   %ax,%ax
f0104cdd:	66 90                	xchg   %ax,%ax
f0104cdf:	90                   	nop

f0104ce0 <syscall>:
}

// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
f0104ce0:	55                   	push   %ebp
f0104ce1:	89 e5                	mov    %esp,%ebp
f0104ce3:	57                   	push   %edi
f0104ce4:	56                   	push   %esi
f0104ce5:	53                   	push   %ebx
f0104ce6:	83 ec 2c             	sub    $0x2c,%esp
f0104ce9:	8b 45 08             	mov    0x8(%ebp),%eax
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
	switch(syscallno){
f0104cec:	83 f8 0d             	cmp    $0xd,%eax
f0104cef:	0f 87 47 05 00 00    	ja     f010523c <syscall+0x55c>
f0104cf5:	ff 24 85 a0 81 10 f0 	jmp    *-0xfef7e60(,%eax,4)

// Deschedule current environment and pick a different one to run.
static void
sys_yield(void)
{
	sched_yield();
f0104cfc:	e8 bf fe ff ff       	call   f0104bc0 <sched_yield>
static void
sys_cputs(const char *s, size_t len)
{
	// Check that the user has permission to read memory [s, s+len).
	// Destroy the environment if not.
	user_mem_assert(curenv,s,len,0);
f0104d01:	e8 9d 18 00 00       	call   f01065a3 <cpunum>
f0104d06:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104d0d:	00 
f0104d0e:	8b 7d 10             	mov    0x10(%ebp),%edi
f0104d11:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0104d15:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104d18:	89 74 24 04          	mov    %esi,0x4(%esp)
f0104d1c:	6b c0 74             	imul   $0x74,%eax,%eax
f0104d1f:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f0104d25:	89 04 24             	mov    %eax,(%esp)
f0104d28:	e8 d3 e7 ff ff       	call   f0103500 <user_mem_assert>
	// LAB 3: Your code here.
	// Print the string supplied by the user.
	cprintf("%.*s", len, s);
f0104d2d:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104d30:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104d34:	8b 45 10             	mov    0x10(%ebp),%eax
f0104d37:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104d3b:	c7 04 24 9a 81 10 f0 	movl   $0xf010819a,(%esp)
f0104d42:	e8 4b f1 ff ff       	call   f0103e92 <cprintf>
		case(SYS_yield):
			sys_yield();
			return 0;
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
f0104d47:	b8 00 00 00 00       	mov    $0x0,%eax
f0104d4c:	e9 f7 04 00 00       	jmp    f0105248 <syscall+0x568>
//	-E_NO_MEM if there's no memory to allocate the new page,
//		or to allocate any necessary page tables.
static int
sys_page_alloc(envid_t envid, void *va, int perm)
{
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
f0104d51:	8b 45 14             	mov    0x14(%ebp),%eax
f0104d54:	25 fd f1 ff ff       	and    $0xfffff1fd,%eax
f0104d59:	83 f8 05             	cmp    $0x5,%eax
f0104d5c:	75 70                	jne    f0104dce <syscall+0xee>
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
	struct Page* pp = page_alloc(ALLOC_ZERO);
f0104d5e:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0104d65:	e8 ac c3 ff ff       	call   f0101116 <page_alloc>
f0104d6a:	89 c3                	mov    %eax,%ebx
	if(pp == NULL) // out of memory
f0104d6c:	85 c0                	test   %eax,%eax
f0104d6e:	74 68                	je     f0104dd8 <syscall+0xf8>
		return -E_NO_MEM;

	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
f0104d70:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104d77:	00 
f0104d78:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104d7b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104d7f:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104d82:	89 04 24             	mov    %eax,(%esp)
f0104d85:	e8 ce e7 ff ff       	call   f0103558 <envid2env>
f0104d8a:	89 c1                	mov    %eax,%ecx
	if(r != 0) // any bad env
f0104d8c:	85 c9                	test   %ecx,%ecx
f0104d8e:	0f 85 b4 04 00 00    	jne    f0105248 <syscall+0x568>
		return r;

	//if va >= UTOP, or va is not page-aligned.
	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
f0104d94:	81 7d 10 ff ff bf ee 	cmpl   $0xeebfffff,0x10(%ebp)
f0104d9b:	77 45                	ja     f0104de2 <syscall+0x102>
f0104d9d:	f7 45 10 ff 0f 00 00 	testl  $0xfff,0x10(%ebp)
f0104da4:	75 46                	jne    f0104dec <syscall+0x10c>
		return -E_INVAL;

	r = page_insert(target_env->env_pgdir, pp, va, perm | PTE_P);
f0104da6:	8b 45 14             	mov    0x14(%ebp),%eax
f0104da9:	83 c8 01             	or     $0x1,%eax
f0104dac:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104db0:	8b 45 10             	mov    0x10(%ebp),%eax
f0104db3:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104db7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104dbb:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104dbe:	8b 40 60             	mov    0x60(%eax),%eax
f0104dc1:	89 04 24             	mov    %eax,(%esp)
f0104dc4:	e8 87 c6 ff ff       	call   f0101450 <page_insert>
f0104dc9:	e9 7a 04 00 00       	jmp    f0105248 <syscall+0x568>
sys_page_alloc(envid_t envid, void *va, int perm)
{
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
f0104dce:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0104dd3:	e9 70 04 00 00       	jmp    f0105248 <syscall+0x568>
	struct Page* pp = page_alloc(ALLOC_ZERO);
	if(pp == NULL) // out of memory
		return -E_NO_MEM;
f0104dd8:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
f0104ddd:	e9 66 04 00 00       	jmp    f0105248 <syscall+0x568>
	if(r != 0) // any bad env
		return r;

	//if va >= UTOP, or va is not page-aligned.
	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
		return -E_INVAL;
f0104de2:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0104de7:	e9 5c 04 00 00       	jmp    f0105248 <syscall+0x568>
f0104dec:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
			return 0;
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case (SYS_page_alloc):
			return sys_page_alloc(a1, (void*)a2, a3);
f0104df1:	e9 52 04 00 00       	jmp    f0105248 <syscall+0x568>
// Read a character from the system console without blocking.
// Returns the character, or 0 if there is no input waiting.
static int
sys_cgetc(void)
{
	return cons_getc();
f0104df6:	e8 aa b8 ff ff       	call   f01006a5 <cons_getc>
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case (SYS_page_alloc):
			return sys_page_alloc(a1, (void*)a2, a3);
		case(SYS_cgetc):
			return sys_cgetc();
f0104dfb:	e9 48 04 00 00       	jmp    f0105248 <syscall+0x568>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f0104e00:	e8 9e 17 00 00       	call   f01065a3 <cpunum>
f0104e05:	6b c0 74             	imul   $0x74,%eax,%eax
f0104e08:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f0104e0e:	8b 40 48             	mov    0x48(%eax),%eax
		case (SYS_page_alloc):
			return sys_page_alloc(a1, (void*)a2, a3);
		case(SYS_cgetc):
			return sys_cgetc();
		case(SYS_getenvid):
			return sys_getenvid();
f0104e11:	e9 32 04 00 00       	jmp    f0105248 <syscall+0x568>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f0104e16:	e8 88 17 00 00       	call   f01065a3 <cpunum>
f0104e1b:	6b c0 74             	imul   $0x74,%eax,%eax
f0104e1e:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f0104e24:	8b 58 48             	mov    0x48(%eax),%ebx
	// from the current environment -- but tweaked so sys_exofork
	// will appear to return 0.
	struct Env* new_env;
	struct Env* this_env;
	envid_t this_envid = sys_getenvid();
	envid2env(this_envid,&this_env,1);
f0104e27:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104e2e:	00 
f0104e2f:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104e32:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104e36:	89 1c 24             	mov    %ebx,(%esp)
f0104e39:	e8 1a e7 ff ff       	call   f0103558 <envid2env>
	int r = env_alloc(&new_env,this_envid);
f0104e3e:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104e42:	8d 45 e0             	lea    -0x20(%ebp),%eax
f0104e45:	89 04 24             	mov    %eax,(%esp)
f0104e48:	e8 13 e8 ff ff       	call   f0103660 <env_alloc>
	if(r!=0)
		return r;
f0104e4d:	89 c2                	mov    %eax,%edx
	struct Env* new_env;
	struct Env* this_env;
	envid_t this_envid = sys_getenvid();
	envid2env(this_envid,&this_env,1);
	int r = env_alloc(&new_env,this_envid);
	if(r!=0)
f0104e4f:	85 c0                	test   %eax,%eax
f0104e51:	75 21                	jne    f0104e74 <syscall+0x194>
		return r;

	new_env->env_tf = this_env->env_tf;
f0104e53:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0104e56:	b9 11 00 00 00       	mov    $0x11,%ecx
f0104e5b:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0104e5e:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
	new_env->env_tf.tf_regs.reg_eax = 0;
f0104e60:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104e63:	c7 40 1c 00 00 00 00 	movl   $0x0,0x1c(%eax)
	new_env->env_status = ENV_NOT_RUNNABLE;
f0104e6a:	c7 40 54 04 00 00 00 	movl   $0x4,0x54(%eax)
	//cprintf("alloc env number %d",new_env->env_id);
	return new_env->env_id;
f0104e71:	8b 50 48             	mov    0x48(%eax),%edx
		case(SYS_cgetc):
			return sys_cgetc();
		case(SYS_getenvid):
			return sys_getenvid();
		case (SYS_exofork):
			return sys_exofork();
f0104e74:	89 d0                	mov    %edx,%eax
f0104e76:	e9 cd 03 00 00       	jmp    f0105248 <syscall+0x568>
	// envid to a struct Env.
	// You should set envid2env's third argument to 1, which will
	// check whether the current environment has permission to set
	// envid's status.
	struct  Env* this_env;
	int r = envid2env(envid,&this_env,1);
f0104e7b:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104e82:	00 
f0104e83:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104e86:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104e8a:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104e8d:	89 04 24             	mov    %eax,(%esp)
f0104e90:	e8 c3 e6 ff ff       	call   f0103558 <envid2env>
	if(r != 0)
		return r;
f0104e95:	89 c2                	mov    %eax,%edx
	// You should set envid2env's third argument to 1, which will
	// check whether the current environment has permission to set
	// envid's status.
	struct  Env* this_env;
	int r = envid2env(envid,&this_env,1);
	if(r != 0)
f0104e97:	85 c0                	test   %eax,%eax
f0104e99:	75 21                	jne    f0104ebc <syscall+0x1dc>
		return r;
	if((status != ENV_RUNNABLE) && (status != ENV_NOT_RUNNABLE))
f0104e9b:	83 7d 10 04          	cmpl   $0x4,0x10(%ebp)
f0104e9f:	74 06                	je     f0104ea7 <syscall+0x1c7>
f0104ea1:	83 7d 10 02          	cmpl   $0x2,0x10(%ebp)
f0104ea5:	75 10                	jne    f0104eb7 <syscall+0x1d7>
		return -E_INVAL;
	this_env->env_status = status;
f0104ea7:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104eaa:	8b 4d 10             	mov    0x10(%ebp),%ecx
f0104ead:	89 48 54             	mov    %ecx,0x54(%eax)
	return 0;
f0104eb0:	ba 00 00 00 00       	mov    $0x0,%edx
f0104eb5:	eb 05                	jmp    f0104ebc <syscall+0x1dc>
	struct  Env* this_env;
	int r = envid2env(envid,&this_env,1);
	if(r != 0)
		return r;
	if((status != ENV_RUNNABLE) && (status != ENV_NOT_RUNNABLE))
		return -E_INVAL;
f0104eb7:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
		case(SYS_getenvid):
			return sys_getenvid();
		case (SYS_exofork):
			return sys_exofork();
		case (SYS_env_set_status):
			return sys_env_set_status(a1, a2);
f0104ebc:	89 d0                	mov    %edx,%eax
f0104ebe:	e9 85 03 00 00       	jmp    f0105248 <syscall+0x568>
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104ec3:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104eca:	00 
f0104ecb:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104ece:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104ed2:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104ed5:	89 04 24             	mov    %eax,(%esp)
f0104ed8:	e8 7b e6 ff ff       	call   f0103558 <envid2env>
		return r;
f0104edd:	89 c2                	mov    %eax,%edx
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104edf:	85 c0                	test   %eax,%eax
f0104ee1:	78 10                	js     f0104ef3 <syscall+0x213>
		return r;
	env_destroy(e);
f0104ee3:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104ee6:	89 04 24             	mov    %eax,(%esp)
f0104ee9:	e8 f2 ec ff ff       	call   f0103be0 <env_destroy>
	return 0;
f0104eee:	ba 00 00 00 00       	mov    $0x0,%edx
		case (SYS_exofork):
			return sys_exofork();
		case (SYS_env_set_status):
			return sys_env_set_status(a1, a2);
		case(SYS_env_destroy):
			return sys_env_destroy((envid_t) a1);
f0104ef3:	89 d0                	mov    %edx,%eax
f0104ef5:	e9 4e 03 00 00       	jmp    f0105248 <syscall+0x568>
	//   page_insert() from kern/pmap.c.
	//   Again, most of the new code you write should be to check the
	//   parameters for correctness.
	//   Use the third argument to page_lookup() to
	//   check the current permissions on the page.
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
f0104efa:	8b 45 1c             	mov    0x1c(%ebp),%eax
f0104efd:	25 fd f1 ff ff       	and    $0xfffff1fd,%eax
f0104f02:	83 f8 05             	cmp    $0x5,%eax
f0104f05:	0f 85 be 00 00 00    	jne    f0104fc9 <syscall+0x2e9>
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;

	struct Env* srcenv, * dstenv;
	int r = envid2env(srcenvid, &srcenv, 1);
f0104f0b:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104f12:	00 
f0104f13:	8d 45 dc             	lea    -0x24(%ebp),%eax
f0104f16:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104f1a:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104f1d:	89 04 24             	mov    %eax,(%esp)
f0104f20:	e8 33 e6 ff ff       	call   f0103558 <envid2env>
	if(r) return E_BAD_ENV;
f0104f25:	ba 02 00 00 00       	mov    $0x2,%edx
f0104f2a:	85 c0                	test   %eax,%eax
f0104f2c:	0f 85 bf 00 00 00    	jne    f0104ff1 <syscall+0x311>
	r = envid2env(dstenvid, &dstenv, 1);
f0104f32:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104f39:	00 
f0104f3a:	8d 45 e0             	lea    -0x20(%ebp),%eax
f0104f3d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104f41:	8b 45 14             	mov    0x14(%ebp),%eax
f0104f44:	89 04 24             	mov    %eax,(%esp)
f0104f47:	e8 0c e6 ff ff       	call   f0103558 <envid2env>
	if(r) return E_BAD_ENV;
f0104f4c:	ba 02 00 00 00       	mov    $0x2,%edx
f0104f51:	85 c0                	test   %eax,%eax
f0104f53:	0f 85 98 00 00 00    	jne    f0104ff1 <syscall+0x311>

	if(((uint32_t)srcva >= UTOP) || ((((uint32_t)srcva & 0x00000fff) != 0)))
f0104f59:	81 7d 10 ff ff bf ee 	cmpl   $0xeebfffff,0x10(%ebp)
f0104f60:	77 6e                	ja     f0104fd0 <syscall+0x2f0>
f0104f62:	f7 45 10 ff 0f 00 00 	testl  $0xfff,0x10(%ebp)
f0104f69:	75 6c                	jne    f0104fd7 <syscall+0x2f7>
		return -E_INVAL;

	if(((uint32_t)dstva >= UTOP) || ((((uint32_t)dstva & 0x00000fff) != 0)))
f0104f6b:	81 7d 18 ff ff bf ee 	cmpl   $0xeebfffff,0x18(%ebp)
f0104f72:	77 6a                	ja     f0104fde <syscall+0x2fe>
f0104f74:	f7 45 18 ff 0f 00 00 	testl  $0xfff,0x18(%ebp)
f0104f7b:	75 68                	jne    f0104fe5 <syscall+0x305>
		return -E_INVAL;


	pte_t* src_table_entry;
	struct Page* srcpp;
	srcpp = page_lookup(srcenv->env_pgdir, srcva, &src_table_entry);
f0104f7d:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104f80:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104f84:	8b 45 10             	mov    0x10(%ebp),%eax
f0104f87:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104f8b:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0104f8e:	8b 40 60             	mov    0x60(%eax),%eax
f0104f91:	89 04 24             	mov    %eax,(%esp)
f0104f94:	e8 cc c3 ff ff       	call   f0101365 <page_lookup>
	if(srcpp == NULL) return -E_INVAL;
f0104f99:	85 c0                	test   %eax,%eax
f0104f9b:	74 4f                	je     f0104fec <syscall+0x30c>
	//cprintf("3. page lookup check passed.\n");

	if(((perm & PTE_W) == 1) && (((*src_table_entry) & PTE_W) == 0))
		return E_BAD_ENV;

	r = page_insert(dstenv->env_pgdir, srcpp, dstva, perm);
f0104f9d:	8b 75 1c             	mov    0x1c(%ebp),%esi
f0104fa0:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0104fa4:	8b 75 18             	mov    0x18(%ebp),%esi
f0104fa7:	89 74 24 08          	mov    %esi,0x8(%esp)
f0104fab:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104faf:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104fb2:	8b 40 60             	mov    0x60(%eax),%eax
f0104fb5:	89 04 24             	mov    %eax,(%esp)
f0104fb8:	e8 93 c4 ff ff       	call   f0101450 <page_insert>
	if(r)
		return -E_INVAL;
f0104fbd:	83 f8 01             	cmp    $0x1,%eax
f0104fc0:	19 d2                	sbb    %edx,%edx
f0104fc2:	f7 d2                	not    %edx
f0104fc4:	83 e2 fd             	and    $0xfffffffd,%edx
f0104fc7:	eb 28                	jmp    f0104ff1 <syscall+0x311>
	//   Use the third argument to page_lookup() to
	//   check the current permissions on the page.
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
f0104fc9:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104fce:	eb 21                	jmp    f0104ff1 <syscall+0x311>
	if(r) return E_BAD_ENV;
	r = envid2env(dstenvid, &dstenv, 1);
	if(r) return E_BAD_ENV;

	if(((uint32_t)srcva >= UTOP) || ((((uint32_t)srcva & 0x00000fff) != 0)))
		return -E_INVAL;
f0104fd0:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104fd5:	eb 1a                	jmp    f0104ff1 <syscall+0x311>
f0104fd7:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104fdc:	eb 13                	jmp    f0104ff1 <syscall+0x311>

	if(((uint32_t)dstva >= UTOP) || ((((uint32_t)dstva & 0x00000fff) != 0)))
		return -E_INVAL;
f0104fde:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104fe3:	eb 0c                	jmp    f0104ff1 <syscall+0x311>
f0104fe5:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104fea:	eb 05                	jmp    f0104ff1 <syscall+0x311>


	pte_t* src_table_entry;
	struct Page* srcpp;
	srcpp = page_lookup(srcenv->env_pgdir, srcva, &src_table_entry);
	if(srcpp == NULL) return -E_INVAL;
f0104fec:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
		case (SYS_env_set_status):
			return sys_env_set_status(a1, a2);
		case(SYS_env_destroy):
			return sys_env_destroy((envid_t) a1);
		case (SYS_page_map):
			return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
f0104ff1:	89 d0                	mov    %edx,%eax
f0104ff3:	e9 50 02 00 00       	jmp    f0105248 <syscall+0x568>
static int
sys_page_unmap(envid_t envid, void *va)
{
	// Hint: This function is a wrapper around page_remove().
	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
f0104ff8:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104fff:	00 
f0105000:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0105003:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105007:	8b 45 0c             	mov    0xc(%ebp),%eax
f010500a:	89 04 24             	mov    %eax,(%esp)
f010500d:	e8 46 e5 ff ff       	call   f0103558 <envid2env>
	if(r) return E_BAD_ENV;
f0105012:	ba 02 00 00 00       	mov    $0x2,%edx
f0105017:	85 c0                	test   %eax,%eax
f0105019:	75 3a                	jne    f0105055 <syscall+0x375>

	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
f010501b:	81 7d 10 ff ff bf ee 	cmpl   $0xeebfffff,0x10(%ebp)
f0105022:	77 25                	ja     f0105049 <syscall+0x369>
f0105024:	f7 45 10 ff 0f 00 00 	testl  $0xfff,0x10(%ebp)
f010502b:	75 23                	jne    f0105050 <syscall+0x370>
		return -E_INVAL;

	page_remove(target_env->env_pgdir, va);
f010502d:	8b 45 10             	mov    0x10(%ebp),%eax
f0105030:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105034:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105037:	8b 40 60             	mov    0x60(%eax),%eax
f010503a:	89 04 24             	mov    %eax,(%esp)
f010503d:	e8 c5 c3 ff ff       	call   f0101407 <page_remove>
	return 0;
f0105042:	ba 00 00 00 00       	mov    $0x0,%edx
f0105047:	eb 0c                	jmp    f0105055 <syscall+0x375>
	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
	if(r) return E_BAD_ENV;

	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
		return -E_INVAL;
f0105049:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f010504e:	eb 05                	jmp    f0105055 <syscall+0x375>
f0105050:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
		case(SYS_env_destroy):
			return sys_env_destroy((envid_t) a1);
		case (SYS_page_map):
			return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
		case (SYS_page_unmap):
			return sys_page_unmap(a1, (void*)a2);
f0105055:	89 d0                	mov    %edx,%eax
f0105057:	e9 ec 01 00 00       	jmp    f0105248 <syscall+0x568>
//	-E_BAD_ENV if environment envid doesn't currently exist,
//		or the caller doesn't have permission to change envid.
static int
sys_env_set_pgfault_upcall(envid_t envid, void *func)
{
	struct Env* this_env =  NULL;
f010505c:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	int r = envid2env(envid,&this_env,1);
f0105063:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010506a:	00 
f010506b:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f010506e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105072:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105075:	89 04 24             	mov    %eax,(%esp)
f0105078:	e8 db e4 ff ff       	call   f0103558 <envid2env>
	if(r){
f010507d:	85 c0                	test   %eax,%eax
f010507f:	75 13                	jne    f0105094 <syscall+0x3b4>
		return -E_BAD_ENV ;
	}
	this_env->env_pgfault_upcall = func;
f0105081:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105084:	8b 7d 10             	mov    0x10(%ebp),%edi
f0105087:	89 78 64             	mov    %edi,0x64(%eax)
	return 0;
f010508a:	b8 00 00 00 00       	mov    $0x0,%eax
f010508f:	e9 b4 01 00 00       	jmp    f0105248 <syscall+0x568>
sys_env_set_pgfault_upcall(envid_t envid, void *func)
{
	struct Env* this_env =  NULL;
	int r = envid2env(envid,&this_env,1);
	if(r){
		return -E_BAD_ENV ;
f0105094:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
		case (SYS_page_map):
			return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
		case (SYS_page_unmap):
			return sys_page_unmap(a1, (void*)a2);
		case (SYS_env_set_pgfault_upcall):
			return sys_env_set_pgfault_upcall(a1, (void*)a2);
f0105099:	e9 aa 01 00 00       	jmp    f0105248 <syscall+0x568>
//		address space.
static int
sys_ipc_try_send(envid_t envid, uint32_t value, void *srcva, unsigned perm)
{
	struct Env * target_env;
	int ret = envid2env(envid,&target_env,0);//zero for not to check permission
f010509e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01050a5:	00 
f01050a6:	8d 45 e0             	lea    -0x20(%ebp),%eax
f01050a9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01050ad:	8b 45 0c             	mov    0xc(%ebp),%eax
f01050b0:	89 04 24             	mov    %eax,(%esp)
f01050b3:	e8 a0 e4 ff ff       	call   f0103558 <envid2env>
	if(ret)
f01050b8:	85 c0                	test   %eax,%eax
f01050ba:	0f 85 15 01 00 00    	jne    f01051d5 <syscall+0x4f5>
		return -E_BAD_ENV;
	if(!target_env->env_ipc_recving)
f01050c0:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01050c3:	83 78 68 00          	cmpl   $0x0,0x68(%eax)
f01050c7:	0f 84 0f 01 00 00    	je     f01051dc <syscall+0x4fc>
		return -E_IPC_NOT_RECV;
	target_env->env_ipc_perm = 0;
f01050cd:	c7 40 78 00 00 00 00 	movl   $0x0,0x78(%eax)
	// LAB 4: Your code here.
	//panic("sys_ipc_try_send not implemented");
	if(srcva!=NULL && ((uint32_t)srcva<UTOP)){
f01050d4:	8b 45 14             	mov    0x14(%ebp),%eax
f01050d7:	83 e8 01             	sub    $0x1,%eax
f01050da:	3d fe ff bf ee       	cmp    $0xeebffffe,%eax
f01050df:	0f 87 b4 00 00 00    	ja     f0105199 <syscall+0x4b9>
		if(ROUNDDOWN(srcva,PGSIZE)!=srcva) return -E_INVAL;
f01050e5:	8b 55 14             	mov    0x14(%ebp),%edx
f01050e8:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f01050ee:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f01050f3:	39 55 14             	cmp    %edx,0x14(%ebp)
f01050f6:	0f 85 4c 01 00 00    	jne    f0105248 <syscall+0x568>
		if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
f01050fc:	8b 55 18             	mov    0x18(%ebp),%edx
f01050ff:	81 e2 fd f1 ff ff    	and    $0xfffff1fd,%edx
f0105105:	83 fa 05             	cmp    $0x5,%edx
f0105108:	0f 85 3a 01 00 00    	jne    f0105248 <syscall+0x568>
		return -E_INVAL;

		pte_t* src_table_entry;
		struct Page* srcpp;

		srcpp = page_lookup(curenv->env_pgdir, srcva, &src_table_entry);
f010510e:	e8 90 14 00 00       	call   f01065a3 <cpunum>
f0105113:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0105116:	89 54 24 08          	mov    %edx,0x8(%esp)
f010511a:	8b 75 14             	mov    0x14(%ebp),%esi
f010511d:	89 74 24 04          	mov    %esi,0x4(%esp)
f0105121:	6b c0 74             	imul   $0x74,%eax,%eax
f0105124:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f010512a:	8b 40 60             	mov    0x60(%eax),%eax
f010512d:	89 04 24             	mov    %eax,(%esp)
f0105130:	e8 30 c2 ff ff       	call   f0101365 <page_lookup>
f0105135:	89 c2                	mov    %eax,%edx
		if(srcpp == NULL) return -E_INVAL;
f0105137:	85 c0                	test   %eax,%eax
f0105139:	74 4a                	je     f0105185 <syscall+0x4a5>

		if((perm & PTE_W) && (*src_table_entry & PTE_W) == 0)
f010513b:	f6 45 18 02          	testb  $0x2,0x18(%ebp)
f010513f:	74 11                	je     f0105152 <syscall+0x472>
			return -E_INVAL;
f0105141:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
		struct Page* srcpp;

		srcpp = page_lookup(curenv->env_pgdir, srcva, &src_table_entry);
		if(srcpp == NULL) return -E_INVAL;

		if((perm & PTE_W) && (*src_table_entry & PTE_W) == 0)
f0105146:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0105149:	f6 01 02             	testb  $0x2,(%ecx)
f010514c:	0f 84 f6 00 00 00    	je     f0105248 <syscall+0x568>
			return -E_INVAL;

		if(target_env->env_ipc_dstva != 0) // really send the page if the target want.
f0105152:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105155:	8b 48 6c             	mov    0x6c(%eax),%ecx
f0105158:	85 c9                	test   %ecx,%ecx
f010515a:	74 3d                	je     f0105199 <syscall+0x4b9>
		{
			if(page_insert (target_env->env_pgdir, srcpp, target_env->env_ipc_dstva, perm) < 0)
f010515c:	8b 75 18             	mov    0x18(%ebp),%esi
f010515f:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105163:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0105167:	89 54 24 04          	mov    %edx,0x4(%esp)
f010516b:	8b 40 60             	mov    0x60(%eax),%eax
f010516e:	89 04 24             	mov    %eax,(%esp)
f0105171:	e8 da c2 ff ff       	call   f0101450 <page_insert>
f0105176:	85 c0                	test   %eax,%eax
f0105178:	78 15                	js     f010518f <syscall+0x4af>
				return -E_NO_MEM;
			target_env->env_ipc_perm = perm;
f010517a:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010517d:	8b 75 18             	mov    0x18(%ebp),%esi
f0105180:	89 70 78             	mov    %esi,0x78(%eax)
f0105183:	eb 14                	jmp    f0105199 <syscall+0x4b9>

		pte_t* src_table_entry;
		struct Page* srcpp;

		srcpp = page_lookup(curenv->env_pgdir, srcva, &src_table_entry);
		if(srcpp == NULL) return -E_INVAL;
f0105185:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f010518a:	e9 b9 00 00 00       	jmp    f0105248 <syscall+0x568>
			return -E_INVAL;

		if(target_env->env_ipc_dstva != 0) // really send the page if the target want.
		{
			if(page_insert (target_env->env_pgdir, srcpp, target_env->env_ipc_dstva, perm) < 0)
				return -E_NO_MEM;
f010518f:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
f0105194:	e9 af 00 00 00       	jmp    f0105248 <syscall+0x568>
			target_env->env_ipc_perm = perm;
		}
	}
	target_env->env_ipc_recving = 0;
f0105199:	8b 5d e0             	mov    -0x20(%ebp),%ebx
f010519c:	c7 43 68 00 00 00 00 	movl   $0x0,0x68(%ebx)
    	target_env->env_ipc_from = curenv->env_id;
f01051a3:	e8 fb 13 00 00       	call   f01065a3 <cpunum>
f01051a8:	6b c0 74             	imul   $0x74,%eax,%eax
f01051ab:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f01051b1:	8b 40 48             	mov    0x48(%eax),%eax
f01051b4:	89 43 74             	mov    %eax,0x74(%ebx)
    	target_env->env_ipc_value = value; 
f01051b7:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01051ba:	8b 75 10             	mov    0x10(%ebp),%esi
f01051bd:	89 70 70             	mov    %esi,0x70(%eax)
    	target_env->env_status = ENV_RUNNABLE;
f01051c0:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)
   	 target_env->env_tf.tf_regs.reg_eax = 0;
f01051c7:	c7 40 1c 00 00 00 00 	movl   $0x0,0x1c(%eax)
   	 return 0;
f01051ce:	b8 00 00 00 00       	mov    $0x0,%eax
f01051d3:	eb 73                	jmp    f0105248 <syscall+0x568>
sys_ipc_try_send(envid_t envid, uint32_t value, void *srcva, unsigned perm)
{
	struct Env * target_env;
	int ret = envid2env(envid,&target_env,0);//zero for not to check permission
	if(ret)
		return -E_BAD_ENV;
f01051d5:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01051da:	eb 6c                	jmp    f0105248 <syscall+0x568>
	if(!target_env->env_ipc_recving)
		return -E_IPC_NOT_RECV;
f01051dc:	b8 f9 ff ff ff       	mov    $0xfffffff9,%eax
		case (SYS_page_unmap):
			return sys_page_unmap(a1, (void*)a2);
		case (SYS_env_set_pgfault_upcall):
			return sys_env_set_pgfault_upcall(a1, (void*)a2);
		case (SYS_ipc_try_send):
			return sys_ipc_try_send(a1, a2, (void*)a3, a4);
f01051e1:	eb 65                	jmp    f0105248 <syscall+0x568>
// Return < 0 on error.  Errors are:
//	-E_INVAL if dstva < UTOP but dstva is not page-aligned.
static int
sys_ipc_recv(void *dstva)
{
	if(dstva<(void*)UTOP){
f01051e3:	81 7d 0c ff ff bf ee 	cmpl   $0xeebfffff,0xc(%ebp)
f01051ea:	77 0d                	ja     f01051f9 <syscall+0x519>
		if(dstva != ROUNDDOWN(dstva,PGSIZE))
f01051ec:	8b 45 0c             	mov    0xc(%ebp),%eax
f01051ef:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01051f4:	39 45 0c             	cmp    %eax,0xc(%ebp)
f01051f7:	75 4a                	jne    f0105243 <syscall+0x563>
			return -E_INVAL;
	}
	// LAB 4: Your code here.
	curenv->env_ipc_recving = 1;
f01051f9:	e8 a5 13 00 00       	call   f01065a3 <cpunum>
f01051fe:	6b c0 74             	imul   $0x74,%eax,%eax
f0105201:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f0105207:	c7 40 68 01 00 00 00 	movl   $0x1,0x68(%eax)
    	curenv->env_status = ENV_NOT_RUNNABLE;
f010520e:	e8 90 13 00 00       	call   f01065a3 <cpunum>
f0105213:	6b c0 74             	imul   $0x74,%eax,%eax
f0105216:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f010521c:	c7 40 54 04 00 00 00 	movl   $0x4,0x54(%eax)
    	curenv->env_ipc_dstva = dstva;
f0105223:	e8 7b 13 00 00       	call   f01065a3 <cpunum>
f0105228:	6b c0 74             	imul   $0x74,%eax,%eax
f010522b:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f0105231:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105234:	89 70 6c             	mov    %esi,0x6c(%eax)

// Deschedule current environment and pick a different one to run.
static void
sys_yield(void)
{
	sched_yield();
f0105237:	e8 84 f9 ff ff       	call   f0104bc0 <sched_yield>
		case (SYS_ipc_try_send):
			return sys_ipc_try_send(a1, a2, (void*)a3, a4);
		case (SYS_ipc_recv):
			return sys_ipc_recv((void*)a1);
		default:
			return -E_INVAL;
f010523c:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0105241:	eb 05                	jmp    f0105248 <syscall+0x568>
		case (SYS_env_set_pgfault_upcall):
			return sys_env_set_pgfault_upcall(a1, (void*)a2);
		case (SYS_ipc_try_send):
			return sys_ipc_try_send(a1, a2, (void*)a3, a4);
		case (SYS_ipc_recv):
			return sys_ipc_recv((void*)a1);
f0105243:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
		default:
			return -E_INVAL;
	}
	//panic("syscall not implemented");
}
f0105248:	83 c4 2c             	add    $0x2c,%esp
f010524b:	5b                   	pop    %ebx
f010524c:	5e                   	pop    %esi
f010524d:	5f                   	pop    %edi
f010524e:	5d                   	pop    %ebp
f010524f:	c3                   	ret    

f0105250 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0105250:	55                   	push   %ebp
f0105251:	89 e5                	mov    %esp,%ebp
f0105253:	57                   	push   %edi
f0105254:	56                   	push   %esi
f0105255:	53                   	push   %ebx
f0105256:	83 ec 14             	sub    $0x14,%esp
f0105259:	89 45 ec             	mov    %eax,-0x14(%ebp)
f010525c:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f010525f:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0105262:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0105265:	8b 1a                	mov    (%edx),%ebx
f0105267:	8b 01                	mov    (%ecx),%eax
f0105269:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f010526c:	39 c3                	cmp    %eax,%ebx
f010526e:	0f 8f 9a 00 00 00    	jg     f010530e <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f0105274:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f010527b:	8b 45 f0             	mov    -0x10(%ebp),%eax
f010527e:	01 d8                	add    %ebx,%eax
f0105280:	89 c7                	mov    %eax,%edi
f0105282:	c1 ef 1f             	shr    $0x1f,%edi
f0105285:	01 c7                	add    %eax,%edi
f0105287:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0105289:	39 df                	cmp    %ebx,%edi
f010528b:	0f 8c c4 00 00 00    	jl     f0105355 <stab_binsearch+0x105>
f0105291:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0105294:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0105297:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f010529a:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f010529e:	39 f0                	cmp    %esi,%eax
f01052a0:	0f 84 b4 00 00 00    	je     f010535a <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f01052a6:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f01052a8:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f01052ab:	39 d8                	cmp    %ebx,%eax
f01052ad:	0f 8c a2 00 00 00    	jl     f0105355 <stab_binsearch+0x105>
f01052b3:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f01052b7:	83 ea 0c             	sub    $0xc,%edx
f01052ba:	39 f1                	cmp    %esi,%ecx
f01052bc:	75 ea                	jne    f01052a8 <stab_binsearch+0x58>
f01052be:	e9 99 00 00 00       	jmp    f010535c <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f01052c3:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f01052c6:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f01052c8:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01052cb:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01052d2:	eb 2b                	jmp    f01052ff <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f01052d4:	3b 55 0c             	cmp    0xc(%ebp),%edx
f01052d7:	76 14                	jbe    f01052ed <stab_binsearch+0x9d>
			*region_right = m - 1;
f01052d9:	83 e8 01             	sub    $0x1,%eax
f01052dc:	89 45 f0             	mov    %eax,-0x10(%ebp)
f01052df:	8b 7d e0             	mov    -0x20(%ebp),%edi
f01052e2:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01052e4:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01052eb:	eb 12                	jmp    f01052ff <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f01052ed:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01052f0:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f01052f2:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f01052f6:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01052f8:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f01052ff:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0105302:	0f 8e 73 ff ff ff    	jle    f010527b <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0105308:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f010530c:	75 0f                	jne    f010531d <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f010530e:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105311:	8b 00                	mov    (%eax),%eax
f0105313:	83 e8 01             	sub    $0x1,%eax
f0105316:	8b 75 e0             	mov    -0x20(%ebp),%esi
f0105319:	89 06                	mov    %eax,(%esi)
f010531b:	eb 57                	jmp    f0105374 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f010531d:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105320:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0105322:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0105325:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0105327:	39 c8                	cmp    %ecx,%eax
f0105329:	7e 23                	jle    f010534e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f010532b:	8d 14 40             	lea    (%eax,%eax,2),%edx
f010532e:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0105331:	8d 14 97             	lea    (%edi,%edx,4),%edx
f0105334:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f0105338:	39 f3                	cmp    %esi,%ebx
f010533a:	74 12                	je     f010534e <stab_binsearch+0xfe>
		     l--)
f010533c:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f010533f:	39 c8                	cmp    %ecx,%eax
f0105341:	7e 0b                	jle    f010534e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0105343:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f0105347:	83 ea 0c             	sub    $0xc,%edx
f010534a:	39 f3                	cmp    %esi,%ebx
f010534c:	75 ee                	jne    f010533c <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f010534e:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0105351:	89 06                	mov    %eax,(%esi)
f0105353:	eb 1f                	jmp    f0105374 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0105355:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0105358:	eb a5                	jmp    f01052ff <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f010535a:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f010535c:	8d 14 40             	lea    (%eax,%eax,2),%edx
f010535f:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0105362:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0105366:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0105369:	0f 82 54 ff ff ff    	jb     f01052c3 <stab_binsearch+0x73>
f010536f:	e9 60 ff ff ff       	jmp    f01052d4 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0105374:	83 c4 14             	add    $0x14,%esp
f0105377:	5b                   	pop    %ebx
f0105378:	5e                   	pop    %esi
f0105379:	5f                   	pop    %edi
f010537a:	5d                   	pop    %ebp
f010537b:	c3                   	ret    

f010537c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f010537c:	55                   	push   %ebp
f010537d:	89 e5                	mov    %esp,%ebp
f010537f:	57                   	push   %edi
f0105380:	56                   	push   %esi
f0105381:	53                   	push   %ebx
f0105382:	83 ec 3c             	sub    $0x3c,%esp
f0105385:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105388:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f010538b:	c7 06 d8 81 10 f0    	movl   $0xf01081d8,(%esi)
	info->eip_line = 0;
f0105391:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0105398:	c7 46 08 d8 81 10 f0 	movl   $0xf01081d8,0x8(%esi)
	info->eip_fn_namelen = 9;
f010539f:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f01053a6:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f01053a9:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f01053b0:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f01053b6:	0f 87 ca 00 00 00    	ja     f0105486 <debuginfo_eip+0x10a>
		const struct UserStabData *usd = (const struct UserStabData *) USTABDATA;

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
f01053bc:	e8 e2 11 00 00       	call   f01065a3 <cpunum>
f01053c1:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f01053c8:	00 
f01053c9:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
f01053d0:	00 
f01053d1:	c7 44 24 04 00 00 20 	movl   $0x200000,0x4(%esp)
f01053d8:	00 
f01053d9:	6b c0 74             	imul   $0x74,%eax,%eax
f01053dc:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f01053e2:	89 04 24             	mov    %eax,(%esp)
f01053e5:	e8 77 e0 ff ff       	call   f0103461 <user_mem_check>
f01053ea:	85 c0                	test   %eax,%eax
f01053ec:	0f 85 12 02 00 00    	jne    f0105604 <debuginfo_eip+0x288>
			return -1;
		stabs = usd->stabs;
f01053f2:	a1 00 00 20 00       	mov    0x200000,%eax
f01053f7:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f01053fa:	8b 1d 04 00 20 00    	mov    0x200004,%ebx
		stabstr = usd->stabstr;
f0105400:	8b 15 08 00 20 00    	mov    0x200008,%edx
f0105406:	89 55 d0             	mov    %edx,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f0105409:	a1 0c 00 20 00       	mov    0x20000c,%eax
f010540e:	89 45 cc             	mov    %eax,-0x34(%ebp)

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
f0105411:	e8 8d 11 00 00       	call   f01065a3 <cpunum>
f0105416:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f010541d:	00 
f010541e:	89 da                	mov    %ebx,%edx
f0105420:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0105423:	29 ca                	sub    %ecx,%edx
f0105425:	c1 fa 02             	sar    $0x2,%edx
f0105428:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f010542e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0105432:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0105436:	6b c0 74             	imul   $0x74,%eax,%eax
f0105439:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f010543f:	89 04 24             	mov    %eax,(%esp)
f0105442:	e8 1a e0 ff ff       	call   f0103461 <user_mem_check>
f0105447:	85 c0                	test   %eax,%eax
f0105449:	0f 85 bc 01 00 00    	jne    f010560b <debuginfo_eip+0x28f>
f010544f:	e8 4f 11 00 00       	call   f01065a3 <cpunum>
f0105454:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f010545b:	00 
f010545c:	8b 55 cc             	mov    -0x34(%ebp),%edx
f010545f:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0105462:	29 ca                	sub    %ecx,%edx
f0105464:	89 54 24 08          	mov    %edx,0x8(%esp)
f0105468:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f010546c:	6b c0 74             	imul   $0x74,%eax,%eax
f010546f:	8b 80 28 50 1c f0    	mov    -0xfe3afd8(%eax),%eax
f0105475:	89 04 24             	mov    %eax,(%esp)
f0105478:	e8 e4 df ff ff       	call   f0103461 <user_mem_check>
f010547d:	85 c0                	test   %eax,%eax
f010547f:	74 1f                	je     f01054a0 <debuginfo_eip+0x124>
f0105481:	e9 8c 01 00 00       	jmp    f0105612 <debuginfo_eip+0x296>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f0105486:	c7 45 cc 85 64 11 f0 	movl   $0xf0116485,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f010548d:	c7 45 d0 11 2f 11 f0 	movl   $0xf0112f11,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f0105494:	bb 10 2f 11 f0       	mov    $0xf0112f10,%ebx
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f0105499:	c7 45 d4 70 87 10 f0 	movl   $0xf0108770,-0x2c(%ebp)
		    return -1;
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f01054a0:	8b 45 cc             	mov    -0x34(%ebp),%eax
f01054a3:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f01054a6:	0f 83 6d 01 00 00    	jae    f0105619 <debuginfo_eip+0x29d>
f01054ac:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f01054b0:	0f 85 6a 01 00 00    	jne    f0105620 <debuginfo_eip+0x2a4>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f01054b6:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f01054bd:	2b 5d d4             	sub    -0x2c(%ebp),%ebx
f01054c0:	c1 fb 02             	sar    $0x2,%ebx
f01054c3:	69 c3 ab aa aa aa    	imul   $0xaaaaaaab,%ebx,%eax
f01054c9:	83 e8 01             	sub    $0x1,%eax
f01054cc:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f01054cf:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01054d3:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f01054da:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f01054dd:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f01054e0:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f01054e3:	89 d8                	mov    %ebx,%eax
f01054e5:	e8 66 fd ff ff       	call   f0105250 <stab_binsearch>
	if (lfile == 0)
f01054ea:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01054ed:	85 c0                	test   %eax,%eax
f01054ef:	0f 84 32 01 00 00    	je     f0105627 <debuginfo_eip+0x2ab>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f01054f5:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f01054f8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01054fb:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f01054fe:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105502:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0105509:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f010550c:	8d 55 dc             	lea    -0x24(%ebp),%edx
f010550f:	89 d8                	mov    %ebx,%eax
f0105511:	e8 3a fd ff ff       	call   f0105250 <stab_binsearch>

	if (lfun <= rfun) {
f0105516:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f0105519:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f010551c:	7f 23                	jg     f0105541 <debuginfo_eip+0x1c5>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f010551e:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0105521:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0105524:	8d 04 87             	lea    (%edi,%eax,4),%eax
f0105527:	8b 10                	mov    (%eax),%edx
f0105529:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f010552c:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f010552f:	39 ca                	cmp    %ecx,%edx
f0105531:	73 06                	jae    f0105539 <debuginfo_eip+0x1bd>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0105533:	03 55 d0             	add    -0x30(%ebp),%edx
f0105536:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f0105539:	8b 40 08             	mov    0x8(%eax),%eax
f010553c:	89 46 10             	mov    %eax,0x10(%esi)
f010553f:	eb 06                	jmp    f0105547 <debuginfo_eip+0x1cb>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0105541:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f0105544:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0105547:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f010554e:	00 
f010554f:	8b 46 08             	mov    0x8(%esi),%eax
f0105552:	89 04 24             	mov    %eax,(%esp)
f0105555:	e8 85 09 00 00       	call   f0105edf <strfind>
f010555a:	2b 46 08             	sub    0x8(%esi),%eax
f010555d:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0105560:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0105563:	39 fb                	cmp    %edi,%ebx
f0105565:	7c 5d                	jl     f01055c4 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0105567:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f010556a:	c1 e0 02             	shl    $0x2,%eax
f010556d:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0105570:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f0105573:	89 55 c8             	mov    %edx,-0x38(%ebp)
f0105576:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f010557a:	80 fa 84             	cmp    $0x84,%dl
f010557d:	74 2d                	je     f01055ac <debuginfo_eip+0x230>
f010557f:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f0105583:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0105586:	eb 15                	jmp    f010559d <debuginfo_eip+0x221>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0105588:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f010558b:	39 fb                	cmp    %edi,%ebx
f010558d:	7c 35                	jl     f01055c4 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f010558f:	89 c1                	mov    %eax,%ecx
f0105591:	83 e8 0c             	sub    $0xc,%eax
f0105594:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0105598:	80 fa 84             	cmp    $0x84,%dl
f010559b:	74 0f                	je     f01055ac <debuginfo_eip+0x230>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f010559d:	80 fa 64             	cmp    $0x64,%dl
f01055a0:	75 e6                	jne    f0105588 <debuginfo_eip+0x20c>
f01055a2:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f01055a6:	74 e0                	je     f0105588 <debuginfo_eip+0x20c>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f01055a8:	39 df                	cmp    %ebx,%edi
f01055aa:	7f 18                	jg     f01055c4 <debuginfo_eip+0x248>
f01055ac:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f01055af:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f01055b2:	8b 04 87             	mov    (%edi,%eax,4),%eax
f01055b5:	8b 55 cc             	mov    -0x34(%ebp),%edx
f01055b8:	2b 55 d0             	sub    -0x30(%ebp),%edx
f01055bb:	39 d0                	cmp    %edx,%eax
f01055bd:	73 05                	jae    f01055c4 <debuginfo_eip+0x248>
		info->eip_file = stabstr + stabs[lline].n_strx;
f01055bf:	03 45 d0             	add    -0x30(%ebp),%eax
f01055c2:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f01055c4:	8b 55 dc             	mov    -0x24(%ebp),%edx
f01055c7:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f01055ca:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f01055cf:	39 ca                	cmp    %ecx,%edx
f01055d1:	7d 75                	jge    f0105648 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
f01055d3:	8d 42 01             	lea    0x1(%edx),%eax
f01055d6:	39 c1                	cmp    %eax,%ecx
f01055d8:	7e 54                	jle    f010562e <debuginfo_eip+0x2b2>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f01055da:	8d 14 40             	lea    (%eax,%eax,2),%edx
f01055dd:	c1 e2 02             	shl    $0x2,%edx
f01055e0:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f01055e3:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f01055e8:	75 4b                	jne    f0105635 <debuginfo_eip+0x2b9>
f01055ea:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f01055ee:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f01055f2:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f01055f5:	39 c1                	cmp    %eax,%ecx
f01055f7:	7e 43                	jle    f010563c <debuginfo_eip+0x2c0>
f01055f9:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f01055fc:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0105600:	74 ec                	je     f01055ee <debuginfo_eip+0x272>
f0105602:	eb 3f                	jmp    f0105643 <debuginfo_eip+0x2c7>

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
			return -1;
f0105604:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105609:	eb 3d                	jmp    f0105648 <debuginfo_eip+0x2cc>

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
		 {
		    return -1;
f010560b:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105610:	eb 36                	jmp    f0105648 <debuginfo_eip+0x2cc>
f0105612:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105617:	eb 2f                	jmp    f0105648 <debuginfo_eip+0x2cc>
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0105619:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f010561e:	eb 28                	jmp    f0105648 <debuginfo_eip+0x2cc>
f0105620:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105625:	eb 21                	jmp    f0105648 <debuginfo_eip+0x2cc>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0105627:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f010562c:	eb 1a                	jmp    f0105648 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f010562e:	b8 00 00 00 00       	mov    $0x0,%eax
f0105633:	eb 13                	jmp    f0105648 <debuginfo_eip+0x2cc>
f0105635:	b8 00 00 00 00       	mov    $0x0,%eax
f010563a:	eb 0c                	jmp    f0105648 <debuginfo_eip+0x2cc>
f010563c:	b8 00 00 00 00       	mov    $0x0,%eax
f0105641:	eb 05                	jmp    f0105648 <debuginfo_eip+0x2cc>
f0105643:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105648:	83 c4 3c             	add    $0x3c,%esp
f010564b:	5b                   	pop    %ebx
f010564c:	5e                   	pop    %esi
f010564d:	5f                   	pop    %edi
f010564e:	5d                   	pop    %ebp
f010564f:	c3                   	ret    

f0105650 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0105650:	55                   	push   %ebp
f0105651:	89 e5                	mov    %esp,%ebp
f0105653:	57                   	push   %edi
f0105654:	56                   	push   %esi
f0105655:	53                   	push   %ebx
f0105656:	83 ec 3c             	sub    $0x3c,%esp
f0105659:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010565c:	89 d7                	mov    %edx,%edi
f010565e:	8b 45 08             	mov    0x8(%ebp),%eax
f0105661:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0105664:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105667:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f010566a:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f010566d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105672:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0105675:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0105678:	39 f1                	cmp    %esi,%ecx
f010567a:	72 14                	jb     f0105690 <printnum+0x40>
f010567c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f010567f:	76 0f                	jbe    f0105690 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0105681:	8b 45 14             	mov    0x14(%ebp),%eax
f0105684:	8d 70 ff             	lea    -0x1(%eax),%esi
f0105687:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f010568a:	85 f6                	test   %esi,%esi
f010568c:	7f 60                	jg     f01056ee <printnum+0x9e>
f010568e:	eb 72                	jmp    f0105702 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0105690:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0105693:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0105697:	8b 4d 14             	mov    0x14(%ebp),%ecx
f010569a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f010569d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01056a1:	89 44 24 08          	mov    %eax,0x8(%esp)
f01056a5:	8b 44 24 08          	mov    0x8(%esp),%eax
f01056a9:	8b 54 24 0c          	mov    0xc(%esp),%edx
f01056ad:	89 c3                	mov    %eax,%ebx
f01056af:	89 d6                	mov    %edx,%esi
f01056b1:	8b 55 d8             	mov    -0x28(%ebp),%edx
f01056b4:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f01056b7:	89 54 24 08          	mov    %edx,0x8(%esp)
f01056bb:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01056bf:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01056c2:	89 04 24             	mov    %eax,(%esp)
f01056c5:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01056c8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01056cc:	e8 3f 13 00 00       	call   f0106a10 <__udivdi3>
f01056d1:	89 d9                	mov    %ebx,%ecx
f01056d3:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01056d7:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01056db:	89 04 24             	mov    %eax,(%esp)
f01056de:	89 54 24 04          	mov    %edx,0x4(%esp)
f01056e2:	89 fa                	mov    %edi,%edx
f01056e4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01056e7:	e8 64 ff ff ff       	call   f0105650 <printnum>
f01056ec:	eb 14                	jmp    f0105702 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f01056ee:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01056f2:	8b 45 18             	mov    0x18(%ebp),%eax
f01056f5:	89 04 24             	mov    %eax,(%esp)
f01056f8:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f01056fa:	83 ee 01             	sub    $0x1,%esi
f01056fd:	75 ef                	jne    f01056ee <printnum+0x9e>
f01056ff:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0105702:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105706:	8b 7c 24 04          	mov    0x4(%esp),%edi
f010570a:	8b 45 d8             	mov    -0x28(%ebp),%eax
f010570d:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0105710:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105714:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0105718:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010571b:	89 04 24             	mov    %eax,(%esp)
f010571e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105721:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105725:	e8 16 14 00 00       	call   f0106b40 <__umoddi3>
f010572a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010572e:	0f be 80 e2 81 10 f0 	movsbl -0xfef7e1e(%eax),%eax
f0105735:	89 04 24             	mov    %eax,(%esp)
f0105738:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010573b:	ff d0                	call   *%eax
}
f010573d:	83 c4 3c             	add    $0x3c,%esp
f0105740:	5b                   	pop    %ebx
f0105741:	5e                   	pop    %esi
f0105742:	5f                   	pop    %edi
f0105743:	5d                   	pop    %ebp
f0105744:	c3                   	ret    

f0105745 <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0105745:	55                   	push   %ebp
f0105746:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0105748:	83 fa 01             	cmp    $0x1,%edx
f010574b:	7e 0e                	jle    f010575b <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f010574d:	8b 10                	mov    (%eax),%edx
f010574f:	8d 4a 08             	lea    0x8(%edx),%ecx
f0105752:	89 08                	mov    %ecx,(%eax)
f0105754:	8b 02                	mov    (%edx),%eax
f0105756:	8b 52 04             	mov    0x4(%edx),%edx
f0105759:	eb 22                	jmp    f010577d <getuint+0x38>
	else if (lflag)
f010575b:	85 d2                	test   %edx,%edx
f010575d:	74 10                	je     f010576f <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f010575f:	8b 10                	mov    (%eax),%edx
f0105761:	8d 4a 04             	lea    0x4(%edx),%ecx
f0105764:	89 08                	mov    %ecx,(%eax)
f0105766:	8b 02                	mov    (%edx),%eax
f0105768:	ba 00 00 00 00       	mov    $0x0,%edx
f010576d:	eb 0e                	jmp    f010577d <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f010576f:	8b 10                	mov    (%eax),%edx
f0105771:	8d 4a 04             	lea    0x4(%edx),%ecx
f0105774:	89 08                	mov    %ecx,(%eax)
f0105776:	8b 02                	mov    (%edx),%eax
f0105778:	ba 00 00 00 00       	mov    $0x0,%edx
}
f010577d:	5d                   	pop    %ebp
f010577e:	c3                   	ret    

f010577f <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f010577f:	55                   	push   %ebp
f0105780:	89 e5                	mov    %esp,%ebp
f0105782:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0105785:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0105789:	8b 10                	mov    (%eax),%edx
f010578b:	3b 50 04             	cmp    0x4(%eax),%edx
f010578e:	73 0a                	jae    f010579a <sprintputch+0x1b>
		*b->buf++ = ch;
f0105790:	8d 4a 01             	lea    0x1(%edx),%ecx
f0105793:	89 08                	mov    %ecx,(%eax)
f0105795:	8b 45 08             	mov    0x8(%ebp),%eax
f0105798:	88 02                	mov    %al,(%edx)
}
f010579a:	5d                   	pop    %ebp
f010579b:	c3                   	ret    

f010579c <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f010579c:	55                   	push   %ebp
f010579d:	89 e5                	mov    %esp,%ebp
f010579f:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f01057a2:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f01057a5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01057a9:	8b 45 10             	mov    0x10(%ebp),%eax
f01057ac:	89 44 24 08          	mov    %eax,0x8(%esp)
f01057b0:	8b 45 0c             	mov    0xc(%ebp),%eax
f01057b3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01057b7:	8b 45 08             	mov    0x8(%ebp),%eax
f01057ba:	89 04 24             	mov    %eax,(%esp)
f01057bd:	e8 02 00 00 00       	call   f01057c4 <vprintfmt>
	va_end(ap);
}
f01057c2:	c9                   	leave  
f01057c3:	c3                   	ret    

f01057c4 <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f01057c4:	55                   	push   %ebp
f01057c5:	89 e5                	mov    %esp,%ebp
f01057c7:	57                   	push   %edi
f01057c8:	56                   	push   %esi
f01057c9:	53                   	push   %ebx
f01057ca:	83 ec 3c             	sub    $0x3c,%esp
f01057cd:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01057d0:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01057d3:	eb 18                	jmp    f01057ed <vprintfmt+0x29>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f01057d5:	85 c0                	test   %eax,%eax
f01057d7:	0f 84 c3 03 00 00    	je     f0105ba0 <vprintfmt+0x3dc>
				return;
			putch(ch, putdat);
f01057dd:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01057e1:	89 04 24             	mov    %eax,(%esp)
f01057e4:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01057e7:	89 f3                	mov    %esi,%ebx
f01057e9:	eb 02                	jmp    f01057ed <vprintfmt+0x29>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f01057eb:	89 f3                	mov    %esi,%ebx
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01057ed:	8d 73 01             	lea    0x1(%ebx),%esi
f01057f0:	0f b6 03             	movzbl (%ebx),%eax
f01057f3:	83 f8 25             	cmp    $0x25,%eax
f01057f6:	75 dd                	jne    f01057d5 <vprintfmt+0x11>
f01057f8:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f01057fc:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0105803:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f010580a:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0105811:	ba 00 00 00 00       	mov    $0x0,%edx
f0105816:	eb 1d                	jmp    f0105835 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105818:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f010581a:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f010581e:	eb 15                	jmp    f0105835 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105820:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0105822:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f0105826:	eb 0d                	jmp    f0105835 <vprintfmt+0x71>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0105828:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010582b:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010582e:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105835:	8d 5e 01             	lea    0x1(%esi),%ebx
f0105838:	0f b6 06             	movzbl (%esi),%eax
f010583b:	0f b6 c8             	movzbl %al,%ecx
f010583e:	83 e8 23             	sub    $0x23,%eax
f0105841:	3c 55                	cmp    $0x55,%al
f0105843:	0f 87 2f 03 00 00    	ja     f0105b78 <vprintfmt+0x3b4>
f0105849:	0f b6 c0             	movzbl %al,%eax
f010584c:	ff 24 85 20 83 10 f0 	jmp    *-0xfef7ce0(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0105853:	8d 41 d0             	lea    -0x30(%ecx),%eax
f0105856:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0105859:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f010585d:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0105860:	83 f9 09             	cmp    $0x9,%ecx
f0105863:	77 50                	ja     f01058b5 <vprintfmt+0xf1>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105865:	89 de                	mov    %ebx,%esi
f0105867:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f010586a:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f010586d:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0105870:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0105874:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0105877:	8d 58 d0             	lea    -0x30(%eax),%ebx
f010587a:	83 fb 09             	cmp    $0x9,%ebx
f010587d:	76 eb                	jbe    f010586a <vprintfmt+0xa6>
f010587f:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0105882:	eb 33                	jmp    f01058b7 <vprintfmt+0xf3>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0105884:	8b 45 14             	mov    0x14(%ebp),%eax
f0105887:	8d 48 04             	lea    0x4(%eax),%ecx
f010588a:	89 4d 14             	mov    %ecx,0x14(%ebp)
f010588d:	8b 00                	mov    (%eax),%eax
f010588f:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105892:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0105894:	eb 21                	jmp    f01058b7 <vprintfmt+0xf3>
f0105896:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0105899:	85 c9                	test   %ecx,%ecx
f010589b:	b8 00 00 00 00       	mov    $0x0,%eax
f01058a0:	0f 49 c1             	cmovns %ecx,%eax
f01058a3:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01058a6:	89 de                	mov    %ebx,%esi
f01058a8:	eb 8b                	jmp    f0105835 <vprintfmt+0x71>
f01058aa:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f01058ac:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f01058b3:	eb 80                	jmp    f0105835 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01058b5:	89 de                	mov    %ebx,%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f01058b7:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01058bb:	0f 89 74 ff ff ff    	jns    f0105835 <vprintfmt+0x71>
f01058c1:	e9 62 ff ff ff       	jmp    f0105828 <vprintfmt+0x64>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f01058c6:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01058c9:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f01058cb:	e9 65 ff ff ff       	jmp    f0105835 <vprintfmt+0x71>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f01058d0:	8b 45 14             	mov    0x14(%ebp),%eax
f01058d3:	8d 50 04             	lea    0x4(%eax),%edx
f01058d6:	89 55 14             	mov    %edx,0x14(%ebp)
f01058d9:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01058dd:	8b 00                	mov    (%eax),%eax
f01058df:	89 04 24             	mov    %eax,(%esp)
f01058e2:	ff 55 08             	call   *0x8(%ebp)
			break;
f01058e5:	e9 03 ff ff ff       	jmp    f01057ed <vprintfmt+0x29>

		// error message
		case 'e':
			err = va_arg(ap, int);
f01058ea:	8b 45 14             	mov    0x14(%ebp),%eax
f01058ed:	8d 50 04             	lea    0x4(%eax),%edx
f01058f0:	89 55 14             	mov    %edx,0x14(%ebp)
f01058f3:	8b 00                	mov    (%eax),%eax
f01058f5:	99                   	cltd   
f01058f6:	31 d0                	xor    %edx,%eax
f01058f8:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f01058fa:	83 f8 0f             	cmp    $0xf,%eax
f01058fd:	7f 0b                	jg     f010590a <vprintfmt+0x146>
f01058ff:	8b 14 85 80 84 10 f0 	mov    -0xfef7b80(,%eax,4),%edx
f0105906:	85 d2                	test   %edx,%edx
f0105908:	75 20                	jne    f010592a <vprintfmt+0x166>
				printfmt(putch, putdat, "error %d", err);
f010590a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010590e:	c7 44 24 08 fa 81 10 	movl   $0xf01081fa,0x8(%esp)
f0105915:	f0 
f0105916:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010591a:	8b 45 08             	mov    0x8(%ebp),%eax
f010591d:	89 04 24             	mov    %eax,(%esp)
f0105920:	e8 77 fe ff ff       	call   f010579c <printfmt>
f0105925:	e9 c3 fe ff ff       	jmp    f01057ed <vprintfmt+0x29>
			else
				printfmt(putch, putdat, "%s", p);
f010592a:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010592e:	c7 44 24 08 05 7a 10 	movl   $0xf0107a05,0x8(%esp)
f0105935:	f0 
f0105936:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010593a:	8b 45 08             	mov    0x8(%ebp),%eax
f010593d:	89 04 24             	mov    %eax,(%esp)
f0105940:	e8 57 fe ff ff       	call   f010579c <printfmt>
f0105945:	e9 a3 fe ff ff       	jmp    f01057ed <vprintfmt+0x29>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010594a:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f010594d:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0105950:	8b 45 14             	mov    0x14(%ebp),%eax
f0105953:	8d 50 04             	lea    0x4(%eax),%edx
f0105956:	89 55 14             	mov    %edx,0x14(%ebp)
f0105959:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f010595b:	85 c0                	test   %eax,%eax
f010595d:	ba f3 81 10 f0       	mov    $0xf01081f3,%edx
f0105962:	0f 45 d0             	cmovne %eax,%edx
f0105965:	89 55 d0             	mov    %edx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f0105968:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f010596c:	74 04                	je     f0105972 <vprintfmt+0x1ae>
f010596e:	85 f6                	test   %esi,%esi
f0105970:	7f 19                	jg     f010598b <vprintfmt+0x1c7>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0105972:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0105975:	8d 70 01             	lea    0x1(%eax),%esi
f0105978:	0f b6 10             	movzbl (%eax),%edx
f010597b:	0f be c2             	movsbl %dl,%eax
f010597e:	85 c0                	test   %eax,%eax
f0105980:	0f 85 95 00 00 00    	jne    f0105a1b <vprintfmt+0x257>
f0105986:	e9 85 00 00 00       	jmp    f0105a10 <vprintfmt+0x24c>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f010598b:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f010598f:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0105992:	89 04 24             	mov    %eax,(%esp)
f0105995:	e8 88 03 00 00       	call   f0105d22 <strnlen>
f010599a:	29 c6                	sub    %eax,%esi
f010599c:	89 f0                	mov    %esi,%eax
f010599e:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f01059a1:	85 f6                	test   %esi,%esi
f01059a3:	7e cd                	jle    f0105972 <vprintfmt+0x1ae>
					putch(padc, putdat);
f01059a5:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f01059a9:	89 5d 10             	mov    %ebx,0x10(%ebp)
f01059ac:	89 c3                	mov    %eax,%ebx
f01059ae:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01059b2:	89 34 24             	mov    %esi,(%esp)
f01059b5:	ff 55 08             	call   *0x8(%ebp)
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f01059b8:	83 eb 01             	sub    $0x1,%ebx
f01059bb:	75 f1                	jne    f01059ae <vprintfmt+0x1ea>
f01059bd:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f01059c0:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01059c3:	eb ad                	jmp    f0105972 <vprintfmt+0x1ae>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f01059c5:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f01059c9:	74 1e                	je     f01059e9 <vprintfmt+0x225>
f01059cb:	0f be d2             	movsbl %dl,%edx
f01059ce:	83 ea 20             	sub    $0x20,%edx
f01059d1:	83 fa 5e             	cmp    $0x5e,%edx
f01059d4:	76 13                	jbe    f01059e9 <vprintfmt+0x225>
					putch('?', putdat);
f01059d6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01059d9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01059dd:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f01059e4:	ff 55 08             	call   *0x8(%ebp)
f01059e7:	eb 0d                	jmp    f01059f6 <vprintfmt+0x232>
				else
					putch(ch, putdat);
f01059e9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01059ec:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01059f0:	89 04 24             	mov    %eax,(%esp)
f01059f3:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01059f6:	83 ef 01             	sub    $0x1,%edi
f01059f9:	83 c6 01             	add    $0x1,%esi
f01059fc:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f0105a00:	0f be c2             	movsbl %dl,%eax
f0105a03:	85 c0                	test   %eax,%eax
f0105a05:	75 20                	jne    f0105a27 <vprintfmt+0x263>
f0105a07:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f0105a0a:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0105a0d:	8b 5d 10             	mov    0x10(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0105a10:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0105a14:	7f 25                	jg     f0105a3b <vprintfmt+0x277>
f0105a16:	e9 d2 fd ff ff       	jmp    f01057ed <vprintfmt+0x29>
f0105a1b:	89 7d 0c             	mov    %edi,0xc(%ebp)
f0105a1e:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0105a21:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0105a24:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0105a27:	85 db                	test   %ebx,%ebx
f0105a29:	78 9a                	js     f01059c5 <vprintfmt+0x201>
f0105a2b:	83 eb 01             	sub    $0x1,%ebx
f0105a2e:	79 95                	jns    f01059c5 <vprintfmt+0x201>
f0105a30:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f0105a33:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0105a36:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0105a39:	eb d5                	jmp    f0105a10 <vprintfmt+0x24c>
f0105a3b:	8b 75 08             	mov    0x8(%ebp),%esi
f0105a3e:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0105a41:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0105a44:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105a48:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f0105a4f:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0105a51:	83 eb 01             	sub    $0x1,%ebx
f0105a54:	75 ee                	jne    f0105a44 <vprintfmt+0x280>
f0105a56:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0105a59:	e9 8f fd ff ff       	jmp    f01057ed <vprintfmt+0x29>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f0105a5e:	83 fa 01             	cmp    $0x1,%edx
f0105a61:	7e 16                	jle    f0105a79 <vprintfmt+0x2b5>
		return va_arg(*ap, long long);
f0105a63:	8b 45 14             	mov    0x14(%ebp),%eax
f0105a66:	8d 50 08             	lea    0x8(%eax),%edx
f0105a69:	89 55 14             	mov    %edx,0x14(%ebp)
f0105a6c:	8b 50 04             	mov    0x4(%eax),%edx
f0105a6f:	8b 00                	mov    (%eax),%eax
f0105a71:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0105a74:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0105a77:	eb 32                	jmp    f0105aab <vprintfmt+0x2e7>
	else if (lflag)
f0105a79:	85 d2                	test   %edx,%edx
f0105a7b:	74 18                	je     f0105a95 <vprintfmt+0x2d1>
		return va_arg(*ap, long);
f0105a7d:	8b 45 14             	mov    0x14(%ebp),%eax
f0105a80:	8d 50 04             	lea    0x4(%eax),%edx
f0105a83:	89 55 14             	mov    %edx,0x14(%ebp)
f0105a86:	8b 30                	mov    (%eax),%esi
f0105a88:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105a8b:	89 f0                	mov    %esi,%eax
f0105a8d:	c1 f8 1f             	sar    $0x1f,%eax
f0105a90:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0105a93:	eb 16                	jmp    f0105aab <vprintfmt+0x2e7>
	else
		return va_arg(*ap, int);
f0105a95:	8b 45 14             	mov    0x14(%ebp),%eax
f0105a98:	8d 50 04             	lea    0x4(%eax),%edx
f0105a9b:	89 55 14             	mov    %edx,0x14(%ebp)
f0105a9e:	8b 30                	mov    (%eax),%esi
f0105aa0:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105aa3:	89 f0                	mov    %esi,%eax
f0105aa5:	c1 f8 1f             	sar    $0x1f,%eax
f0105aa8:	89 45 dc             	mov    %eax,-0x24(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f0105aab:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0105aae:	8b 55 dc             	mov    -0x24(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f0105ab1:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0105ab6:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f0105aba:	0f 89 80 00 00 00    	jns    f0105b40 <vprintfmt+0x37c>
				putch('-', putdat);
f0105ac0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105ac4:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f0105acb:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f0105ace:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0105ad1:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0105ad4:	f7 d8                	neg    %eax
f0105ad6:	83 d2 00             	adc    $0x0,%edx
f0105ad9:	f7 da                	neg    %edx
			}
			base = 10;
f0105adb:	b9 0a 00 00 00       	mov    $0xa,%ecx
f0105ae0:	eb 5e                	jmp    f0105b40 <vprintfmt+0x37c>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f0105ae2:	8d 45 14             	lea    0x14(%ebp),%eax
f0105ae5:	e8 5b fc ff ff       	call   f0105745 <getuint>
			base = 10;
f0105aea:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f0105aef:	eb 4f                	jmp    f0105b40 <vprintfmt+0x37c>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			//putch('X', putdat);
			num = getuint(&ap, lflag);
f0105af1:	8d 45 14             	lea    0x14(%ebp),%eax
f0105af4:	e8 4c fc ff ff       	call   f0105745 <getuint>
			base = 8;
f0105af9:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f0105afe:	eb 40                	jmp    f0105b40 <vprintfmt+0x37c>
			//putch('X', putdat);
			//break;

		// pointer
		case 'p':
			putch('0', putdat);
f0105b00:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105b04:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f0105b0b:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f0105b0e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105b12:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f0105b19:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f0105b1c:	8b 45 14             	mov    0x14(%ebp),%eax
f0105b1f:	8d 50 04             	lea    0x4(%eax),%edx
f0105b22:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f0105b25:	8b 00                	mov    (%eax),%eax
f0105b27:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f0105b2c:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f0105b31:	eb 0d                	jmp    f0105b40 <vprintfmt+0x37c>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f0105b33:	8d 45 14             	lea    0x14(%ebp),%eax
f0105b36:	e8 0a fc ff ff       	call   f0105745 <getuint>
			base = 16;
f0105b3b:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f0105b40:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105b44:	89 74 24 10          	mov    %esi,0x10(%esp)
f0105b48:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0105b4b:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105b4f:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0105b53:	89 04 24             	mov    %eax,(%esp)
f0105b56:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105b5a:	89 fa                	mov    %edi,%edx
f0105b5c:	8b 45 08             	mov    0x8(%ebp),%eax
f0105b5f:	e8 ec fa ff ff       	call   f0105650 <printnum>
			break;
f0105b64:	e9 84 fc ff ff       	jmp    f01057ed <vprintfmt+0x29>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0105b69:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105b6d:	89 0c 24             	mov    %ecx,(%esp)
f0105b70:	ff 55 08             	call   *0x8(%ebp)
			break;
f0105b73:	e9 75 fc ff ff       	jmp    f01057ed <vprintfmt+0x29>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0105b78:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105b7c:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0105b83:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f0105b86:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f0105b8a:	0f 84 5b fc ff ff    	je     f01057eb <vprintfmt+0x27>
f0105b90:	89 f3                	mov    %esi,%ebx
f0105b92:	83 eb 01             	sub    $0x1,%ebx
f0105b95:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f0105b99:	75 f7                	jne    f0105b92 <vprintfmt+0x3ce>
f0105b9b:	e9 4d fc ff ff       	jmp    f01057ed <vprintfmt+0x29>
				/* do nothing */;
			break;
		}
	}
}
f0105ba0:	83 c4 3c             	add    $0x3c,%esp
f0105ba3:	5b                   	pop    %ebx
f0105ba4:	5e                   	pop    %esi
f0105ba5:	5f                   	pop    %edi
f0105ba6:	5d                   	pop    %ebp
f0105ba7:	c3                   	ret    

f0105ba8 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0105ba8:	55                   	push   %ebp
f0105ba9:	89 e5                	mov    %esp,%ebp
f0105bab:	83 ec 28             	sub    $0x28,%esp
f0105bae:	8b 45 08             	mov    0x8(%ebp),%eax
f0105bb1:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0105bb4:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0105bb7:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f0105bbb:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f0105bbe:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0105bc5:	85 c0                	test   %eax,%eax
f0105bc7:	74 30                	je     f0105bf9 <vsnprintf+0x51>
f0105bc9:	85 d2                	test   %edx,%edx
f0105bcb:	7e 2c                	jle    f0105bf9 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f0105bcd:	8b 45 14             	mov    0x14(%ebp),%eax
f0105bd0:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105bd4:	8b 45 10             	mov    0x10(%ebp),%eax
f0105bd7:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105bdb:	8d 45 ec             	lea    -0x14(%ebp),%eax
f0105bde:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105be2:	c7 04 24 7f 57 10 f0 	movl   $0xf010577f,(%esp)
f0105be9:	e8 d6 fb ff ff       	call   f01057c4 <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0105bee:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0105bf1:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0105bf4:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0105bf7:	eb 05                	jmp    f0105bfe <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f0105bf9:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f0105bfe:	c9                   	leave  
f0105bff:	c3                   	ret    

f0105c00 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f0105c00:	55                   	push   %ebp
f0105c01:	89 e5                	mov    %esp,%ebp
f0105c03:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0105c06:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f0105c09:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105c0d:	8b 45 10             	mov    0x10(%ebp),%eax
f0105c10:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105c14:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105c17:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105c1b:	8b 45 08             	mov    0x8(%ebp),%eax
f0105c1e:	89 04 24             	mov    %eax,(%esp)
f0105c21:	e8 82 ff ff ff       	call   f0105ba8 <vsnprintf>
	va_end(ap);

	return rc;
}
f0105c26:	c9                   	leave  
f0105c27:	c3                   	ret    
f0105c28:	66 90                	xchg   %ax,%ax
f0105c2a:	66 90                	xchg   %ax,%ax
f0105c2c:	66 90                	xchg   %ax,%ax
f0105c2e:	66 90                	xchg   %ax,%ax

f0105c30 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0105c30:	55                   	push   %ebp
f0105c31:	89 e5                	mov    %esp,%ebp
f0105c33:	57                   	push   %edi
f0105c34:	56                   	push   %esi
f0105c35:	53                   	push   %ebx
f0105c36:	83 ec 1c             	sub    $0x1c,%esp
f0105c39:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f0105c3c:	85 c0                	test   %eax,%eax
f0105c3e:	74 10                	je     f0105c50 <readline+0x20>
		cprintf("%s", prompt);
f0105c40:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105c44:	c7 04 24 05 7a 10 f0 	movl   $0xf0107a05,(%esp)
f0105c4b:	e8 42 e2 ff ff       	call   f0103e92 <cprintf>

	i = 0;
	echoing = iscons(0);
f0105c50:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0105c57:	e8 c2 ab ff ff       	call   f010081e <iscons>
f0105c5c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f0105c5e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0105c63:	e8 a5 ab ff ff       	call   f010080d <getchar>
f0105c68:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f0105c6a:	85 c0                	test   %eax,%eax
f0105c6c:	79 17                	jns    f0105c85 <readline+0x55>
			cprintf("read error: %e\n", c);
f0105c6e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105c72:	c7 04 24 df 84 10 f0 	movl   $0xf01084df,(%esp)
f0105c79:	e8 14 e2 ff ff       	call   f0103e92 <cprintf>
			return NULL;
f0105c7e:	b8 00 00 00 00       	mov    $0x0,%eax
f0105c83:	eb 6d                	jmp    f0105cf2 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0105c85:	83 f8 7f             	cmp    $0x7f,%eax
f0105c88:	74 05                	je     f0105c8f <readline+0x5f>
f0105c8a:	83 f8 08             	cmp    $0x8,%eax
f0105c8d:	75 19                	jne    f0105ca8 <readline+0x78>
f0105c8f:	85 f6                	test   %esi,%esi
f0105c91:	7e 15                	jle    f0105ca8 <readline+0x78>
			if (echoing)
f0105c93:	85 ff                	test   %edi,%edi
f0105c95:	74 0c                	je     f0105ca3 <readline+0x73>
				cputchar('\b');
f0105c97:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f0105c9e:	e8 5a ab ff ff       	call   f01007fd <cputchar>
			i--;
f0105ca3:	83 ee 01             	sub    $0x1,%esi
f0105ca6:	eb bb                	jmp    f0105c63 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0105ca8:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f0105cae:	7f 1c                	jg     f0105ccc <readline+0x9c>
f0105cb0:	83 fb 1f             	cmp    $0x1f,%ebx
f0105cb3:	7e 17                	jle    f0105ccc <readline+0x9c>
			if (echoing)
f0105cb5:	85 ff                	test   %edi,%edi
f0105cb7:	74 08                	je     f0105cc1 <readline+0x91>
				cputchar(c);
f0105cb9:	89 1c 24             	mov    %ebx,(%esp)
f0105cbc:	e8 3c ab ff ff       	call   f01007fd <cputchar>
			buf[i++] = c;
f0105cc1:	88 9e 80 4a 1c f0    	mov    %bl,-0xfe3b580(%esi)
f0105cc7:	8d 76 01             	lea    0x1(%esi),%esi
f0105cca:	eb 97                	jmp    f0105c63 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f0105ccc:	83 fb 0d             	cmp    $0xd,%ebx
f0105ccf:	74 05                	je     f0105cd6 <readline+0xa6>
f0105cd1:	83 fb 0a             	cmp    $0xa,%ebx
f0105cd4:	75 8d                	jne    f0105c63 <readline+0x33>
			if (echoing)
f0105cd6:	85 ff                	test   %edi,%edi
f0105cd8:	74 0c                	je     f0105ce6 <readline+0xb6>
				cputchar('\n');
f0105cda:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0105ce1:	e8 17 ab ff ff       	call   f01007fd <cputchar>
			buf[i] = 0;
f0105ce6:	c6 86 80 4a 1c f0 00 	movb   $0x0,-0xfe3b580(%esi)
			return buf;
f0105ced:	b8 80 4a 1c f0       	mov    $0xf01c4a80,%eax
		}
	}
}
f0105cf2:	83 c4 1c             	add    $0x1c,%esp
f0105cf5:	5b                   	pop    %ebx
f0105cf6:	5e                   	pop    %esi
f0105cf7:	5f                   	pop    %edi
f0105cf8:	5d                   	pop    %ebp
f0105cf9:	c3                   	ret    
f0105cfa:	66 90                	xchg   %ax,%ax
f0105cfc:	66 90                	xchg   %ax,%ax
f0105cfe:	66 90                	xchg   %ax,%ax

f0105d00 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0105d00:	55                   	push   %ebp
f0105d01:	89 e5                	mov    %esp,%ebp
f0105d03:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0105d06:	80 3a 00             	cmpb   $0x0,(%edx)
f0105d09:	74 10                	je     f0105d1b <strlen+0x1b>
f0105d0b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f0105d10:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0105d13:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0105d17:	75 f7                	jne    f0105d10 <strlen+0x10>
f0105d19:	eb 05                	jmp    f0105d20 <strlen+0x20>
f0105d1b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0105d20:	5d                   	pop    %ebp
f0105d21:	c3                   	ret    

f0105d22 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0105d22:	55                   	push   %ebp
f0105d23:	89 e5                	mov    %esp,%ebp
f0105d25:	53                   	push   %ebx
f0105d26:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105d29:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0105d2c:	85 c9                	test   %ecx,%ecx
f0105d2e:	74 1c                	je     f0105d4c <strnlen+0x2a>
f0105d30:	80 3b 00             	cmpb   $0x0,(%ebx)
f0105d33:	74 1e                	je     f0105d53 <strnlen+0x31>
f0105d35:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f0105d3a:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0105d3c:	39 ca                	cmp    %ecx,%edx
f0105d3e:	74 18                	je     f0105d58 <strnlen+0x36>
f0105d40:	83 c2 01             	add    $0x1,%edx
f0105d43:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0105d48:	75 f0                	jne    f0105d3a <strnlen+0x18>
f0105d4a:	eb 0c                	jmp    f0105d58 <strnlen+0x36>
f0105d4c:	b8 00 00 00 00       	mov    $0x0,%eax
f0105d51:	eb 05                	jmp    f0105d58 <strnlen+0x36>
f0105d53:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0105d58:	5b                   	pop    %ebx
f0105d59:	5d                   	pop    %ebp
f0105d5a:	c3                   	ret    

f0105d5b <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f0105d5b:	55                   	push   %ebp
f0105d5c:	89 e5                	mov    %esp,%ebp
f0105d5e:	53                   	push   %ebx
f0105d5f:	8b 45 08             	mov    0x8(%ebp),%eax
f0105d62:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0105d65:	89 c2                	mov    %eax,%edx
f0105d67:	83 c2 01             	add    $0x1,%edx
f0105d6a:	83 c1 01             	add    $0x1,%ecx
f0105d6d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0105d71:	88 5a ff             	mov    %bl,-0x1(%edx)
f0105d74:	84 db                	test   %bl,%bl
f0105d76:	75 ef                	jne    f0105d67 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0105d78:	5b                   	pop    %ebx
f0105d79:	5d                   	pop    %ebp
f0105d7a:	c3                   	ret    

f0105d7b <strcat>:

char *
strcat(char *dst, const char *src)
{
f0105d7b:	55                   	push   %ebp
f0105d7c:	89 e5                	mov    %esp,%ebp
f0105d7e:	53                   	push   %ebx
f0105d7f:	83 ec 08             	sub    $0x8,%esp
f0105d82:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f0105d85:	89 1c 24             	mov    %ebx,(%esp)
f0105d88:	e8 73 ff ff ff       	call   f0105d00 <strlen>
	strcpy(dst + len, src);
f0105d8d:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105d90:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105d94:	01 d8                	add    %ebx,%eax
f0105d96:	89 04 24             	mov    %eax,(%esp)
f0105d99:	e8 bd ff ff ff       	call   f0105d5b <strcpy>
	return dst;
}
f0105d9e:	89 d8                	mov    %ebx,%eax
f0105da0:	83 c4 08             	add    $0x8,%esp
f0105da3:	5b                   	pop    %ebx
f0105da4:	5d                   	pop    %ebp
f0105da5:	c3                   	ret    

f0105da6 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f0105da6:	55                   	push   %ebp
f0105da7:	89 e5                	mov    %esp,%ebp
f0105da9:	56                   	push   %esi
f0105daa:	53                   	push   %ebx
f0105dab:	8b 75 08             	mov    0x8(%ebp),%esi
f0105dae:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105db1:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0105db4:	85 db                	test   %ebx,%ebx
f0105db6:	74 17                	je     f0105dcf <strncpy+0x29>
f0105db8:	01 f3                	add    %esi,%ebx
f0105dba:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f0105dbc:	83 c1 01             	add    $0x1,%ecx
f0105dbf:	0f b6 02             	movzbl (%edx),%eax
f0105dc2:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f0105dc5:	80 3a 01             	cmpb   $0x1,(%edx)
f0105dc8:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0105dcb:	39 d9                	cmp    %ebx,%ecx
f0105dcd:	75 ed                	jne    f0105dbc <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f0105dcf:	89 f0                	mov    %esi,%eax
f0105dd1:	5b                   	pop    %ebx
f0105dd2:	5e                   	pop    %esi
f0105dd3:	5d                   	pop    %ebp
f0105dd4:	c3                   	ret    

f0105dd5 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f0105dd5:	55                   	push   %ebp
f0105dd6:	89 e5                	mov    %esp,%ebp
f0105dd8:	57                   	push   %edi
f0105dd9:	56                   	push   %esi
f0105dda:	53                   	push   %ebx
f0105ddb:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105dde:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0105de1:	8b 75 10             	mov    0x10(%ebp),%esi
f0105de4:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0105de6:	85 f6                	test   %esi,%esi
f0105de8:	74 34                	je     f0105e1e <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f0105dea:	83 fe 01             	cmp    $0x1,%esi
f0105ded:	74 26                	je     f0105e15 <strlcpy+0x40>
f0105def:	0f b6 0b             	movzbl (%ebx),%ecx
f0105df2:	84 c9                	test   %cl,%cl
f0105df4:	74 23                	je     f0105e19 <strlcpy+0x44>
f0105df6:	83 ee 02             	sub    $0x2,%esi
f0105df9:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f0105dfe:	83 c0 01             	add    $0x1,%eax
f0105e01:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0105e04:	39 f2                	cmp    %esi,%edx
f0105e06:	74 13                	je     f0105e1b <strlcpy+0x46>
f0105e08:	83 c2 01             	add    $0x1,%edx
f0105e0b:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f0105e0f:	84 c9                	test   %cl,%cl
f0105e11:	75 eb                	jne    f0105dfe <strlcpy+0x29>
f0105e13:	eb 06                	jmp    f0105e1b <strlcpy+0x46>
f0105e15:	89 f8                	mov    %edi,%eax
f0105e17:	eb 02                	jmp    f0105e1b <strlcpy+0x46>
f0105e19:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f0105e1b:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f0105e1e:	29 f8                	sub    %edi,%eax
}
f0105e20:	5b                   	pop    %ebx
f0105e21:	5e                   	pop    %esi
f0105e22:	5f                   	pop    %edi
f0105e23:	5d                   	pop    %ebp
f0105e24:	c3                   	ret    

f0105e25 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f0105e25:	55                   	push   %ebp
f0105e26:	89 e5                	mov    %esp,%ebp
f0105e28:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0105e2b:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f0105e2e:	0f b6 01             	movzbl (%ecx),%eax
f0105e31:	84 c0                	test   %al,%al
f0105e33:	74 15                	je     f0105e4a <strcmp+0x25>
f0105e35:	3a 02                	cmp    (%edx),%al
f0105e37:	75 11                	jne    f0105e4a <strcmp+0x25>
		p++, q++;
f0105e39:	83 c1 01             	add    $0x1,%ecx
f0105e3c:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f0105e3f:	0f b6 01             	movzbl (%ecx),%eax
f0105e42:	84 c0                	test   %al,%al
f0105e44:	74 04                	je     f0105e4a <strcmp+0x25>
f0105e46:	3a 02                	cmp    (%edx),%al
f0105e48:	74 ef                	je     f0105e39 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f0105e4a:	0f b6 c0             	movzbl %al,%eax
f0105e4d:	0f b6 12             	movzbl (%edx),%edx
f0105e50:	29 d0                	sub    %edx,%eax
}
f0105e52:	5d                   	pop    %ebp
f0105e53:	c3                   	ret    

f0105e54 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0105e54:	55                   	push   %ebp
f0105e55:	89 e5                	mov    %esp,%ebp
f0105e57:	56                   	push   %esi
f0105e58:	53                   	push   %ebx
f0105e59:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105e5c:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105e5f:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f0105e62:	85 f6                	test   %esi,%esi
f0105e64:	74 29                	je     f0105e8f <strncmp+0x3b>
f0105e66:	0f b6 03             	movzbl (%ebx),%eax
f0105e69:	84 c0                	test   %al,%al
f0105e6b:	74 30                	je     f0105e9d <strncmp+0x49>
f0105e6d:	3a 02                	cmp    (%edx),%al
f0105e6f:	75 2c                	jne    f0105e9d <strncmp+0x49>
f0105e71:	8d 43 01             	lea    0x1(%ebx),%eax
f0105e74:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f0105e76:	89 c3                	mov    %eax,%ebx
f0105e78:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f0105e7b:	39 f0                	cmp    %esi,%eax
f0105e7d:	74 17                	je     f0105e96 <strncmp+0x42>
f0105e7f:	0f b6 08             	movzbl (%eax),%ecx
f0105e82:	84 c9                	test   %cl,%cl
f0105e84:	74 17                	je     f0105e9d <strncmp+0x49>
f0105e86:	83 c0 01             	add    $0x1,%eax
f0105e89:	3a 0a                	cmp    (%edx),%cl
f0105e8b:	74 e9                	je     f0105e76 <strncmp+0x22>
f0105e8d:	eb 0e                	jmp    f0105e9d <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f0105e8f:	b8 00 00 00 00       	mov    $0x0,%eax
f0105e94:	eb 0f                	jmp    f0105ea5 <strncmp+0x51>
f0105e96:	b8 00 00 00 00       	mov    $0x0,%eax
f0105e9b:	eb 08                	jmp    f0105ea5 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f0105e9d:	0f b6 03             	movzbl (%ebx),%eax
f0105ea0:	0f b6 12             	movzbl (%edx),%edx
f0105ea3:	29 d0                	sub    %edx,%eax
}
f0105ea5:	5b                   	pop    %ebx
f0105ea6:	5e                   	pop    %esi
f0105ea7:	5d                   	pop    %ebp
f0105ea8:	c3                   	ret    

f0105ea9 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f0105ea9:	55                   	push   %ebp
f0105eaa:	89 e5                	mov    %esp,%ebp
f0105eac:	53                   	push   %ebx
f0105ead:	8b 45 08             	mov    0x8(%ebp),%eax
f0105eb0:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105eb3:	0f b6 18             	movzbl (%eax),%ebx
f0105eb6:	84 db                	test   %bl,%bl
f0105eb8:	74 1d                	je     f0105ed7 <strchr+0x2e>
f0105eba:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0105ebc:	38 d3                	cmp    %dl,%bl
f0105ebe:	75 06                	jne    f0105ec6 <strchr+0x1d>
f0105ec0:	eb 1a                	jmp    f0105edc <strchr+0x33>
f0105ec2:	38 ca                	cmp    %cl,%dl
f0105ec4:	74 16                	je     f0105edc <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0105ec6:	83 c0 01             	add    $0x1,%eax
f0105ec9:	0f b6 10             	movzbl (%eax),%edx
f0105ecc:	84 d2                	test   %dl,%dl
f0105ece:	75 f2                	jne    f0105ec2 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0105ed0:	b8 00 00 00 00       	mov    $0x0,%eax
f0105ed5:	eb 05                	jmp    f0105edc <strchr+0x33>
f0105ed7:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105edc:	5b                   	pop    %ebx
f0105edd:	5d                   	pop    %ebp
f0105ede:	c3                   	ret    

f0105edf <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f0105edf:	55                   	push   %ebp
f0105ee0:	89 e5                	mov    %esp,%ebp
f0105ee2:	53                   	push   %ebx
f0105ee3:	8b 45 08             	mov    0x8(%ebp),%eax
f0105ee6:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105ee9:	0f b6 18             	movzbl (%eax),%ebx
f0105eec:	84 db                	test   %bl,%bl
f0105eee:	74 16                	je     f0105f06 <strfind+0x27>
f0105ef0:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0105ef2:	38 d3                	cmp    %dl,%bl
f0105ef4:	75 06                	jne    f0105efc <strfind+0x1d>
f0105ef6:	eb 0e                	jmp    f0105f06 <strfind+0x27>
f0105ef8:	38 ca                	cmp    %cl,%dl
f0105efa:	74 0a                	je     f0105f06 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f0105efc:	83 c0 01             	add    $0x1,%eax
f0105eff:	0f b6 10             	movzbl (%eax),%edx
f0105f02:	84 d2                	test   %dl,%dl
f0105f04:	75 f2                	jne    f0105ef8 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f0105f06:	5b                   	pop    %ebx
f0105f07:	5d                   	pop    %ebp
f0105f08:	c3                   	ret    

f0105f09 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f0105f09:	55                   	push   %ebp
f0105f0a:	89 e5                	mov    %esp,%ebp
f0105f0c:	57                   	push   %edi
f0105f0d:	56                   	push   %esi
f0105f0e:	53                   	push   %ebx
f0105f0f:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105f12:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0105f15:	85 c9                	test   %ecx,%ecx
f0105f17:	74 36                	je     f0105f4f <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f0105f19:	f7 c7 03 00 00 00    	test   $0x3,%edi
f0105f1f:	75 28                	jne    f0105f49 <memset+0x40>
f0105f21:	f6 c1 03             	test   $0x3,%cl
f0105f24:	75 23                	jne    f0105f49 <memset+0x40>
		c &= 0xFF;
f0105f26:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f0105f2a:	89 d3                	mov    %edx,%ebx
f0105f2c:	c1 e3 08             	shl    $0x8,%ebx
f0105f2f:	89 d6                	mov    %edx,%esi
f0105f31:	c1 e6 18             	shl    $0x18,%esi
f0105f34:	89 d0                	mov    %edx,%eax
f0105f36:	c1 e0 10             	shl    $0x10,%eax
f0105f39:	09 f0                	or     %esi,%eax
f0105f3b:	09 c2                	or     %eax,%edx
f0105f3d:	89 d0                	mov    %edx,%eax
f0105f3f:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f0105f41:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0105f44:	fc                   	cld    
f0105f45:	f3 ab                	rep stos %eax,%es:(%edi)
f0105f47:	eb 06                	jmp    f0105f4f <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0105f49:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105f4c:	fc                   	cld    
f0105f4d:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f0105f4f:	89 f8                	mov    %edi,%eax
f0105f51:	5b                   	pop    %ebx
f0105f52:	5e                   	pop    %esi
f0105f53:	5f                   	pop    %edi
f0105f54:	5d                   	pop    %ebp
f0105f55:	c3                   	ret    

f0105f56 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0105f56:	55                   	push   %ebp
f0105f57:	89 e5                	mov    %esp,%ebp
f0105f59:	57                   	push   %edi
f0105f5a:	56                   	push   %esi
f0105f5b:	8b 45 08             	mov    0x8(%ebp),%eax
f0105f5e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105f61:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0105f64:	39 c6                	cmp    %eax,%esi
f0105f66:	73 35                	jae    f0105f9d <memmove+0x47>
f0105f68:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0105f6b:	39 d0                	cmp    %edx,%eax
f0105f6d:	73 2e                	jae    f0105f9d <memmove+0x47>
		s += n;
		d += n;
f0105f6f:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0105f72:	89 d6                	mov    %edx,%esi
f0105f74:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105f76:	f7 c6 03 00 00 00    	test   $0x3,%esi
f0105f7c:	75 13                	jne    f0105f91 <memmove+0x3b>
f0105f7e:	f6 c1 03             	test   $0x3,%cl
f0105f81:	75 0e                	jne    f0105f91 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0105f83:	83 ef 04             	sub    $0x4,%edi
f0105f86:	8d 72 fc             	lea    -0x4(%edx),%esi
f0105f89:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f0105f8c:	fd                   	std    
f0105f8d:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0105f8f:	eb 09                	jmp    f0105f9a <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0105f91:	83 ef 01             	sub    $0x1,%edi
f0105f94:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0105f97:	fd                   	std    
f0105f98:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0105f9a:	fc                   	cld    
f0105f9b:	eb 1d                	jmp    f0105fba <memmove+0x64>
f0105f9d:	89 f2                	mov    %esi,%edx
f0105f9f:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105fa1:	f6 c2 03             	test   $0x3,%dl
f0105fa4:	75 0f                	jne    f0105fb5 <memmove+0x5f>
f0105fa6:	f6 c1 03             	test   $0x3,%cl
f0105fa9:	75 0a                	jne    f0105fb5 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0105fab:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f0105fae:	89 c7                	mov    %eax,%edi
f0105fb0:	fc                   	cld    
f0105fb1:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0105fb3:	eb 05                	jmp    f0105fba <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0105fb5:	89 c7                	mov    %eax,%edi
f0105fb7:	fc                   	cld    
f0105fb8:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f0105fba:	5e                   	pop    %esi
f0105fbb:	5f                   	pop    %edi
f0105fbc:	5d                   	pop    %ebp
f0105fbd:	c3                   	ret    

f0105fbe <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f0105fbe:	55                   	push   %ebp
f0105fbf:	89 e5                	mov    %esp,%ebp
f0105fc1:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0105fc4:	8b 45 10             	mov    0x10(%ebp),%eax
f0105fc7:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105fcb:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105fce:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105fd2:	8b 45 08             	mov    0x8(%ebp),%eax
f0105fd5:	89 04 24             	mov    %eax,(%esp)
f0105fd8:	e8 79 ff ff ff       	call   f0105f56 <memmove>
}
f0105fdd:	c9                   	leave  
f0105fde:	c3                   	ret    

f0105fdf <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f0105fdf:	55                   	push   %ebp
f0105fe0:	89 e5                	mov    %esp,%ebp
f0105fe2:	57                   	push   %edi
f0105fe3:	56                   	push   %esi
f0105fe4:	53                   	push   %ebx
f0105fe5:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105fe8:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105feb:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0105fee:	8d 78 ff             	lea    -0x1(%eax),%edi
f0105ff1:	85 c0                	test   %eax,%eax
f0105ff3:	74 36                	je     f010602b <memcmp+0x4c>
		if (*s1 != *s2)
f0105ff5:	0f b6 03             	movzbl (%ebx),%eax
f0105ff8:	0f b6 0e             	movzbl (%esi),%ecx
f0105ffb:	ba 00 00 00 00       	mov    $0x0,%edx
f0106000:	38 c8                	cmp    %cl,%al
f0106002:	74 1c                	je     f0106020 <memcmp+0x41>
f0106004:	eb 10                	jmp    f0106016 <memcmp+0x37>
f0106006:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f010600b:	83 c2 01             	add    $0x1,%edx
f010600e:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f0106012:	38 c8                	cmp    %cl,%al
f0106014:	74 0a                	je     f0106020 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f0106016:	0f b6 c0             	movzbl %al,%eax
f0106019:	0f b6 c9             	movzbl %cl,%ecx
f010601c:	29 c8                	sub    %ecx,%eax
f010601e:	eb 10                	jmp    f0106030 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0106020:	39 fa                	cmp    %edi,%edx
f0106022:	75 e2                	jne    f0106006 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f0106024:	b8 00 00 00 00       	mov    $0x0,%eax
f0106029:	eb 05                	jmp    f0106030 <memcmp+0x51>
f010602b:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0106030:	5b                   	pop    %ebx
f0106031:	5e                   	pop    %esi
f0106032:	5f                   	pop    %edi
f0106033:	5d                   	pop    %ebp
f0106034:	c3                   	ret    

f0106035 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0106035:	55                   	push   %ebp
f0106036:	89 e5                	mov    %esp,%ebp
f0106038:	53                   	push   %ebx
f0106039:	8b 45 08             	mov    0x8(%ebp),%eax
f010603c:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f010603f:	89 c2                	mov    %eax,%edx
f0106041:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0106044:	39 d0                	cmp    %edx,%eax
f0106046:	73 13                	jae    f010605b <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f0106048:	89 d9                	mov    %ebx,%ecx
f010604a:	38 18                	cmp    %bl,(%eax)
f010604c:	75 06                	jne    f0106054 <memfind+0x1f>
f010604e:	eb 0b                	jmp    f010605b <memfind+0x26>
f0106050:	38 08                	cmp    %cl,(%eax)
f0106052:	74 07                	je     f010605b <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f0106054:	83 c0 01             	add    $0x1,%eax
f0106057:	39 d0                	cmp    %edx,%eax
f0106059:	75 f5                	jne    f0106050 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f010605b:	5b                   	pop    %ebx
f010605c:	5d                   	pop    %ebp
f010605d:	c3                   	ret    

f010605e <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f010605e:	55                   	push   %ebp
f010605f:	89 e5                	mov    %esp,%ebp
f0106061:	57                   	push   %edi
f0106062:	56                   	push   %esi
f0106063:	53                   	push   %ebx
f0106064:	8b 55 08             	mov    0x8(%ebp),%edx
f0106067:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010606a:	0f b6 0a             	movzbl (%edx),%ecx
f010606d:	80 f9 09             	cmp    $0x9,%cl
f0106070:	74 05                	je     f0106077 <strtol+0x19>
f0106072:	80 f9 20             	cmp    $0x20,%cl
f0106075:	75 10                	jne    f0106087 <strtol+0x29>
		s++;
f0106077:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010607a:	0f b6 0a             	movzbl (%edx),%ecx
f010607d:	80 f9 09             	cmp    $0x9,%cl
f0106080:	74 f5                	je     f0106077 <strtol+0x19>
f0106082:	80 f9 20             	cmp    $0x20,%cl
f0106085:	74 f0                	je     f0106077 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f0106087:	80 f9 2b             	cmp    $0x2b,%cl
f010608a:	75 0a                	jne    f0106096 <strtol+0x38>
		s++;
f010608c:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f010608f:	bf 00 00 00 00       	mov    $0x0,%edi
f0106094:	eb 11                	jmp    f01060a7 <strtol+0x49>
f0106096:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f010609b:	80 f9 2d             	cmp    $0x2d,%cl
f010609e:	75 07                	jne    f01060a7 <strtol+0x49>
		s++, neg = 1;
f01060a0:	83 c2 01             	add    $0x1,%edx
f01060a3:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f01060a7:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f01060ac:	75 15                	jne    f01060c3 <strtol+0x65>
f01060ae:	80 3a 30             	cmpb   $0x30,(%edx)
f01060b1:	75 10                	jne    f01060c3 <strtol+0x65>
f01060b3:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f01060b7:	75 0a                	jne    f01060c3 <strtol+0x65>
		s += 2, base = 16;
f01060b9:	83 c2 02             	add    $0x2,%edx
f01060bc:	b8 10 00 00 00       	mov    $0x10,%eax
f01060c1:	eb 10                	jmp    f01060d3 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f01060c3:	85 c0                	test   %eax,%eax
f01060c5:	75 0c                	jne    f01060d3 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f01060c7:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f01060c9:	80 3a 30             	cmpb   $0x30,(%edx)
f01060cc:	75 05                	jne    f01060d3 <strtol+0x75>
		s++, base = 8;
f01060ce:	83 c2 01             	add    $0x1,%edx
f01060d1:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f01060d3:	bb 00 00 00 00       	mov    $0x0,%ebx
f01060d8:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f01060db:	0f b6 0a             	movzbl (%edx),%ecx
f01060de:	8d 71 d0             	lea    -0x30(%ecx),%esi
f01060e1:	89 f0                	mov    %esi,%eax
f01060e3:	3c 09                	cmp    $0x9,%al
f01060e5:	77 08                	ja     f01060ef <strtol+0x91>
			dig = *s - '0';
f01060e7:	0f be c9             	movsbl %cl,%ecx
f01060ea:	83 e9 30             	sub    $0x30,%ecx
f01060ed:	eb 20                	jmp    f010610f <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f01060ef:	8d 71 9f             	lea    -0x61(%ecx),%esi
f01060f2:	89 f0                	mov    %esi,%eax
f01060f4:	3c 19                	cmp    $0x19,%al
f01060f6:	77 08                	ja     f0106100 <strtol+0xa2>
			dig = *s - 'a' + 10;
f01060f8:	0f be c9             	movsbl %cl,%ecx
f01060fb:	83 e9 57             	sub    $0x57,%ecx
f01060fe:	eb 0f                	jmp    f010610f <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f0106100:	8d 71 bf             	lea    -0x41(%ecx),%esi
f0106103:	89 f0                	mov    %esi,%eax
f0106105:	3c 19                	cmp    $0x19,%al
f0106107:	77 16                	ja     f010611f <strtol+0xc1>
			dig = *s - 'A' + 10;
f0106109:	0f be c9             	movsbl %cl,%ecx
f010610c:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f010610f:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f0106112:	7d 0f                	jge    f0106123 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f0106114:	83 c2 01             	add    $0x1,%edx
f0106117:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f010611b:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f010611d:	eb bc                	jmp    f01060db <strtol+0x7d>
f010611f:	89 d8                	mov    %ebx,%eax
f0106121:	eb 02                	jmp    f0106125 <strtol+0xc7>
f0106123:	89 d8                	mov    %ebx,%eax

	if (endptr)
f0106125:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0106129:	74 05                	je     f0106130 <strtol+0xd2>
		*endptr = (char *) s;
f010612b:	8b 75 0c             	mov    0xc(%ebp),%esi
f010612e:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f0106130:	f7 d8                	neg    %eax
f0106132:	85 ff                	test   %edi,%edi
f0106134:	0f 44 c3             	cmove  %ebx,%eax
}
f0106137:	5b                   	pop    %ebx
f0106138:	5e                   	pop    %esi
f0106139:	5f                   	pop    %edi
f010613a:	5d                   	pop    %ebp
f010613b:	c3                   	ret    

f010613c <mpentry_start>:
.set PROT_MODE_DSEG, 0x10	# kernel data segment selector

.code16           
.globl mpentry_start
mpentry_start:
	cli            
f010613c:	fa                   	cli    

	xorw    %ax, %ax
f010613d:	31 c0                	xor    %eax,%eax
	movw    %ax, %ds
f010613f:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0106141:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0106143:	8e d0                	mov    %eax,%ss

	lgdt    MPBOOTPHYS(gdtdesc)
f0106145:	0f 01 16             	lgdtl  (%esi)
f0106148:	74 70                	je     f01061ba <mpentry_end+0x4>
	movl    %cr0, %eax
f010614a:	0f 20 c0             	mov    %cr0,%eax
	orl     $CR0_PE, %eax
f010614d:	66 83 c8 01          	or     $0x1,%ax
	movl    %eax, %cr0
f0106151:	0f 22 c0             	mov    %eax,%cr0

	ljmpl   $(PROT_MODE_CSEG), $(MPBOOTPHYS(start32))
f0106154:	66 ea 20 70 00 00    	ljmpw  $0x0,$0x7020
f010615a:	08 00                	or     %al,(%eax)

f010615c <start32>:

.code32
start32:
	movw    $(PROT_MODE_DSEG), %ax
f010615c:	66 b8 10 00          	mov    $0x10,%ax
	movw    %ax, %ds
f0106160:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0106162:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0106164:	8e d0                	mov    %eax,%ss
	movw    $0, %ax
f0106166:	66 b8 00 00          	mov    $0x0,%ax
	movw    %ax, %fs
f010616a:	8e e0                	mov    %eax,%fs
	movw    %ax, %gs
f010616c:	8e e8                	mov    %eax,%gs

	# Set up initial page table. We cannot use kern_pgdir yet because
	# we are still running at a low EIP.
	movl    $(RELOC(entry_pgdir)), %eax
f010616e:	b8 00 f0 11 00       	mov    $0x11f000,%eax
	movl    %eax, %cr3
f0106173:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl    %cr0, %eax
f0106176:	0f 20 c0             	mov    %cr0,%eax
	orl     $(CR0_PE|CR0_PG|CR0_WP), %eax
f0106179:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl    %eax, %cr0
f010617e:	0f 22 c0             	mov    %eax,%cr0

	# Switch to the per-cpu stack allocated in mem_init()
	movl    mpentry_kstack, %esp
f0106181:	8b 25 84 4e 1c f0    	mov    0xf01c4e84,%esp
	movl    $0x0, %ebp       # nuke frame pointer
f0106187:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Call mp_main().  (Exercise for the reader: why the indirect call?)
	movl    $mp_main, %eax
f010618c:	b8 45 02 10 f0       	mov    $0xf0100245,%eax
	call    *%eax
f0106191:	ff d0                	call   *%eax

f0106193 <spin>:

	# If mp_main returns (it shouldn't), loop.
spin:
	jmp     spin
f0106193:	eb fe                	jmp    f0106193 <spin>
f0106195:	8d 76 00             	lea    0x0(%esi),%esi

f0106198 <gdt>:
	...
f01061a0:	ff                   	(bad)  
f01061a1:	ff 00                	incl   (%eax)
f01061a3:	00 00                	add    %al,(%eax)
f01061a5:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
f01061ac:	00 92 cf 00 17 00    	add    %dl,0x1700cf(%edx)

f01061b0 <gdtdesc>:
f01061b0:	17                   	pop    %ss
f01061b1:	00 5c 70 00          	add    %bl,0x0(%eax,%esi,2)
	...

f01061b6 <mpentry_end>:
	.word   0x17				# sizeof(gdt) - 1
	.long   MPBOOTPHYS(gdt)			# address gdt

.globl mpentry_end
mpentry_end:
	nop
f01061b6:	90                   	nop
f01061b7:	66 90                	xchg   %ax,%ax
f01061b9:	66 90                	xchg   %ax,%ax
f01061bb:	66 90                	xchg   %ax,%ax
f01061bd:	66 90                	xchg   %ax,%ax
f01061bf:	90                   	nop

f01061c0 <mpsearch1>:
}

// Look for an MP structure in the len bytes at physical address addr.
static struct mp *
mpsearch1(physaddr_t a, int len)
{
f01061c0:	55                   	push   %ebp
f01061c1:	89 e5                	mov    %esp,%ebp
f01061c3:	56                   	push   %esi
f01061c4:	53                   	push   %ebx
f01061c5:	83 ec 10             	sub    $0x10,%esp
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01061c8:	8b 0d 88 4e 1c f0    	mov    0xf01c4e88,%ecx
f01061ce:	89 c3                	mov    %eax,%ebx
f01061d0:	c1 eb 0c             	shr    $0xc,%ebx
f01061d3:	39 cb                	cmp    %ecx,%ebx
f01061d5:	72 20                	jb     f01061f7 <mpsearch1+0x37>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01061d7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01061db:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f01061e2:	f0 
f01061e3:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f01061ea:	00 
f01061eb:	c7 04 24 7d 86 10 f0 	movl   $0xf010867d,(%esp)
f01061f2:	e8 49 9e ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01061f7:	8d 98 00 00 00 f0    	lea    -0x10000000(%eax),%ebx
	struct mp *mp = KADDR(a), *end = KADDR(a + len);
f01061fd:	01 d0                	add    %edx,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01061ff:	89 c2                	mov    %eax,%edx
f0106201:	c1 ea 0c             	shr    $0xc,%edx
f0106204:	39 d1                	cmp    %edx,%ecx
f0106206:	77 20                	ja     f0106228 <mpsearch1+0x68>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106208:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010620c:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0106213:	f0 
f0106214:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f010621b:	00 
f010621c:	c7 04 24 7d 86 10 f0 	movl   $0xf010867d,(%esp)
f0106223:	e8 18 9e ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0106228:	8d b0 00 00 00 f0    	lea    -0x10000000(%eax),%esi

	for (; mp < end; mp++)
f010622e:	39 f3                	cmp    %esi,%ebx
f0106230:	73 40                	jae    f0106272 <mpsearch1+0xb2>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0106232:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0106239:	00 
f010623a:	c7 44 24 04 8d 86 10 	movl   $0xf010868d,0x4(%esp)
f0106241:	f0 
f0106242:	89 1c 24             	mov    %ebx,(%esp)
f0106245:	e8 95 fd ff ff       	call   f0105fdf <memcmp>
f010624a:	85 c0                	test   %eax,%eax
f010624c:	75 17                	jne    f0106265 <mpsearch1+0xa5>
f010624e:	ba 00 00 00 00       	mov    $0x0,%edx
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
		sum += ((uint8_t *)addr)[i];
f0106253:	0f b6 0c 03          	movzbl (%ebx,%eax,1),%ecx
f0106257:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106259:	83 c0 01             	add    $0x1,%eax
f010625c:	83 f8 10             	cmp    $0x10,%eax
f010625f:	75 f2                	jne    f0106253 <mpsearch1+0x93>
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0106261:	84 d2                	test   %dl,%dl
f0106263:	74 14                	je     f0106279 <mpsearch1+0xb9>
static struct mp *
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
f0106265:	83 c3 10             	add    $0x10,%ebx
f0106268:	39 f3                	cmp    %esi,%ebx
f010626a:	72 c6                	jb     f0106232 <mpsearch1+0x72>
f010626c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106270:	eb 0b                	jmp    f010627d <mpsearch1+0xbd>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
		    sum(mp, sizeof(*mp)) == 0)
			return mp;
	return NULL;
f0106272:	b8 00 00 00 00       	mov    $0x0,%eax
f0106277:	eb 09                	jmp    f0106282 <mpsearch1+0xc2>
f0106279:	89 d8                	mov    %ebx,%eax
f010627b:	eb 05                	jmp    f0106282 <mpsearch1+0xc2>
f010627d:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0106282:	83 c4 10             	add    $0x10,%esp
f0106285:	5b                   	pop    %ebx
f0106286:	5e                   	pop    %esi
f0106287:	5d                   	pop    %ebp
f0106288:	c3                   	ret    

f0106289 <mp_init>:
	return conf;
}

void
mp_init(void)
{
f0106289:	55                   	push   %ebp
f010628a:	89 e5                	mov    %esp,%ebp
f010628c:	57                   	push   %edi
f010628d:	56                   	push   %esi
f010628e:	53                   	push   %ebx
f010628f:	83 ec 2c             	sub    $0x2c,%esp
	struct mpconf *conf;
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
f0106292:	c7 05 c0 53 1c f0 20 	movl   $0xf01c5020,0xf01c53c0
f0106299:	50 1c f0 
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010629c:	83 3d 88 4e 1c f0 00 	cmpl   $0x0,0xf01c4e88
f01062a3:	75 24                	jne    f01062c9 <mp_init+0x40>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01062a5:	c7 44 24 0c 00 04 00 	movl   $0x400,0xc(%esp)
f01062ac:	00 
f01062ad:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f01062b4:	f0 
f01062b5:	c7 44 24 04 6f 00 00 	movl   $0x6f,0x4(%esp)
f01062bc:	00 
f01062bd:	c7 04 24 7d 86 10 f0 	movl   $0xf010867d,(%esp)
f01062c4:	e8 77 9d ff ff       	call   f0100040 <_panic>
	// The BIOS data area lives in 16-bit segment 0x40.
	bda = (uint8_t *) KADDR(0x40 << 4);

	// [MP 4] The 16-bit segment of the EBDA is in the two bytes
	// starting at byte 0x0E of the BDA.  0 if not present.
	if ((p = *(uint16_t *) (bda + 0x0E))) {
f01062c9:	0f b7 05 0e 04 00 f0 	movzwl 0xf000040e,%eax
f01062d0:	85 c0                	test   %eax,%eax
f01062d2:	74 16                	je     f01062ea <mp_init+0x61>
		p <<= 4;	// Translate from segment to PA
f01062d4:	c1 e0 04             	shl    $0x4,%eax
		if ((mp = mpsearch1(p, 1024)))
f01062d7:	ba 00 04 00 00       	mov    $0x400,%edx
f01062dc:	e8 df fe ff ff       	call   f01061c0 <mpsearch1>
f01062e1:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01062e4:	85 c0                	test   %eax,%eax
f01062e6:	75 3c                	jne    f0106324 <mp_init+0x9b>
f01062e8:	eb 20                	jmp    f010630a <mp_init+0x81>
			return mp;
	} else {
		// The size of base memory, in KB is in the two bytes
		// starting at 0x13 of the BDA.
		p = *(uint16_t *) (bda + 0x13) * 1024;
f01062ea:	0f b7 05 13 04 00 f0 	movzwl 0xf0000413,%eax
f01062f1:	c1 e0 0a             	shl    $0xa,%eax
		if ((mp = mpsearch1(p - 1024, 1024)))
f01062f4:	2d 00 04 00 00       	sub    $0x400,%eax
f01062f9:	ba 00 04 00 00       	mov    $0x400,%edx
f01062fe:	e8 bd fe ff ff       	call   f01061c0 <mpsearch1>
f0106303:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0106306:	85 c0                	test   %eax,%eax
f0106308:	75 1a                	jne    f0106324 <mp_init+0x9b>
			return mp;
	}
	return mpsearch1(0xF0000, 0x10000);
f010630a:	ba 00 00 01 00       	mov    $0x10000,%edx
f010630f:	b8 00 00 0f 00       	mov    $0xf0000,%eax
f0106314:	e8 a7 fe ff ff       	call   f01061c0 <mpsearch1>
f0106319:	89 45 e4             	mov    %eax,-0x1c(%ebp)
mpconfig(struct mp **pmp)
{
	struct mpconf *conf;
	struct mp *mp;

	if ((mp = mpsearch()) == 0)
f010631c:	85 c0                	test   %eax,%eax
f010631e:	0f 84 5f 02 00 00    	je     f0106583 <mp_init+0x2fa>
		return NULL;
	if (mp->physaddr == 0 || mp->type != 0) {
f0106324:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0106327:	8b 70 04             	mov    0x4(%eax),%esi
f010632a:	85 f6                	test   %esi,%esi
f010632c:	74 06                	je     f0106334 <mp_init+0xab>
f010632e:	80 78 0b 00          	cmpb   $0x0,0xb(%eax)
f0106332:	74 11                	je     f0106345 <mp_init+0xbc>
		cprintf("SMP: Default configurations not implemented\n");
f0106334:	c7 04 24 f0 84 10 f0 	movl   $0xf01084f0,(%esp)
f010633b:	e8 52 db ff ff       	call   f0103e92 <cprintf>
f0106340:	e9 3e 02 00 00       	jmp    f0106583 <mp_init+0x2fa>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0106345:	89 f0                	mov    %esi,%eax
f0106347:	c1 e8 0c             	shr    $0xc,%eax
f010634a:	3b 05 88 4e 1c f0    	cmp    0xf01c4e88,%eax
f0106350:	72 20                	jb     f0106372 <mp_init+0xe9>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106352:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0106356:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f010635d:	f0 
f010635e:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f0106365:	00 
f0106366:	c7 04 24 7d 86 10 f0 	movl   $0xf010867d,(%esp)
f010636d:	e8 ce 9c ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0106372:	8d 9e 00 00 00 f0    	lea    -0x10000000(%esi),%ebx
		return NULL;
	}
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
f0106378:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f010637f:	00 
f0106380:	c7 44 24 04 92 86 10 	movl   $0xf0108692,0x4(%esp)
f0106387:	f0 
f0106388:	89 1c 24             	mov    %ebx,(%esp)
f010638b:	e8 4f fc ff ff       	call   f0105fdf <memcmp>
f0106390:	85 c0                	test   %eax,%eax
f0106392:	74 11                	je     f01063a5 <mp_init+0x11c>
		cprintf("SMP: Incorrect MP configuration table signature\n");
f0106394:	c7 04 24 20 85 10 f0 	movl   $0xf0108520,(%esp)
f010639b:	e8 f2 da ff ff       	call   f0103e92 <cprintf>
f01063a0:	e9 de 01 00 00       	jmp    f0106583 <mp_init+0x2fa>
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f01063a5:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f01063a9:	66 89 45 e2          	mov    %ax,-0x1e(%ebp)
f01063ad:	0f b7 f8             	movzwl %ax,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f01063b0:	85 ff                	test   %edi,%edi
f01063b2:	7e 30                	jle    f01063e4 <mp_init+0x15b>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f01063b4:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f01063b9:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f01063be:	0f b6 8c 30 00 00 00 	movzbl -0x10000000(%eax,%esi,1),%ecx
f01063c5:	f0 
f01063c6:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f01063c8:	83 c0 01             	add    $0x1,%eax
f01063cb:	39 c7                	cmp    %eax,%edi
f01063cd:	7f ef                	jg     f01063be <mp_init+0x135>
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
		cprintf("SMP: Incorrect MP configuration table signature\n");
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f01063cf:	84 d2                	test   %dl,%dl
f01063d1:	74 11                	je     f01063e4 <mp_init+0x15b>
		cprintf("SMP: Bad MP configuration checksum\n");
f01063d3:	c7 04 24 54 85 10 f0 	movl   $0xf0108554,(%esp)
f01063da:	e8 b3 da ff ff       	call   f0103e92 <cprintf>
f01063df:	e9 9f 01 00 00       	jmp    f0106583 <mp_init+0x2fa>
		return NULL;
	}
	if (conf->version != 1 && conf->version != 4) {
f01063e4:	0f b6 43 06          	movzbl 0x6(%ebx),%eax
f01063e8:	3c 04                	cmp    $0x4,%al
f01063ea:	74 1e                	je     f010640a <mp_init+0x181>
f01063ec:	3c 01                	cmp    $0x1,%al
f01063ee:	66 90                	xchg   %ax,%ax
f01063f0:	74 18                	je     f010640a <mp_init+0x181>
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
f01063f2:	0f b6 c0             	movzbl %al,%eax
f01063f5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01063f9:	c7 04 24 78 85 10 f0 	movl   $0xf0108578,(%esp)
f0106400:	e8 8d da ff ff       	call   f0103e92 <cprintf>
f0106405:	e9 79 01 00 00       	jmp    f0106583 <mp_init+0x2fa>
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f010640a:	0f b7 73 28          	movzwl 0x28(%ebx),%esi
f010640e:	0f b7 7d e2          	movzwl -0x1e(%ebp),%edi
f0106412:	01 df                	add    %ebx,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106414:	85 f6                	test   %esi,%esi
f0106416:	7e 19                	jle    f0106431 <mp_init+0x1a8>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0106418:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f010641d:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0106422:	0f b6 0c 07          	movzbl (%edi,%eax,1),%ecx
f0106426:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106428:	83 c0 01             	add    $0x1,%eax
f010642b:	39 c6                	cmp    %eax,%esi
f010642d:	7f f3                	jg     f0106422 <mp_init+0x199>
f010642f:	eb 05                	jmp    f0106436 <mp_init+0x1ad>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0106431:	ba 00 00 00 00       	mov    $0x0,%edx
	}
	if (conf->version != 1 && conf->version != 4) {
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0106436:	38 53 2a             	cmp    %dl,0x2a(%ebx)
f0106439:	74 11                	je     f010644c <mp_init+0x1c3>
		cprintf("SMP: Bad MP configuration extended checksum\n");
f010643b:	c7 04 24 98 85 10 f0 	movl   $0xf0108598,(%esp)
f0106442:	e8 4b da ff ff       	call   f0103e92 <cprintf>
f0106447:	e9 37 01 00 00       	jmp    f0106583 <mp_init+0x2fa>
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
	if ((conf = mpconfig(&mp)) == 0)
f010644c:	85 db                	test   %ebx,%ebx
f010644e:	0f 84 2f 01 00 00    	je     f0106583 <mp_init+0x2fa>
		return;
	ismp = 1;
f0106454:	c7 05 00 50 1c f0 01 	movl   $0x1,0xf01c5000
f010645b:	00 00 00 
	lapic = (uint32_t *)conf->lapicaddr;
f010645e:	8b 43 24             	mov    0x24(%ebx),%eax
f0106461:	a3 00 60 20 f0       	mov    %eax,0xf0206000

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0106466:	8d 7b 2c             	lea    0x2c(%ebx),%edi
f0106469:	66 83 7b 22 00       	cmpw   $0x0,0x22(%ebx)
f010646e:	0f 84 94 00 00 00    	je     f0106508 <mp_init+0x27f>
f0106474:	be 00 00 00 00       	mov    $0x0,%esi
		switch (*p) {
f0106479:	0f b6 07             	movzbl (%edi),%eax
f010647c:	84 c0                	test   %al,%al
f010647e:	74 06                	je     f0106486 <mp_init+0x1fd>
f0106480:	3c 04                	cmp    $0x4,%al
f0106482:	77 54                	ja     f01064d8 <mp_init+0x24f>
f0106484:	eb 4d                	jmp    f01064d3 <mp_init+0x24a>
		case MPPROC:
			proc = (struct mpproc *)p;
			if (proc->flags & MPPROC_BOOT)
f0106486:	f6 47 03 02          	testb  $0x2,0x3(%edi)
f010648a:	74 11                	je     f010649d <mp_init+0x214>
				bootcpu = &cpus[ncpu];
f010648c:	6b 05 c4 53 1c f0 74 	imul   $0x74,0xf01c53c4,%eax
f0106493:	05 20 50 1c f0       	add    $0xf01c5020,%eax
f0106498:	a3 c0 53 1c f0       	mov    %eax,0xf01c53c0
			if (ncpu < NCPU) {
f010649d:	a1 c4 53 1c f0       	mov    0xf01c53c4,%eax
f01064a2:	83 f8 07             	cmp    $0x7,%eax
f01064a5:	7f 13                	jg     f01064ba <mp_init+0x231>
				cpus[ncpu].cpu_id = ncpu;
f01064a7:	6b d0 74             	imul   $0x74,%eax,%edx
f01064aa:	88 82 20 50 1c f0    	mov    %al,-0xfe3afe0(%edx)
				ncpu++;
f01064b0:	83 c0 01             	add    $0x1,%eax
f01064b3:	a3 c4 53 1c f0       	mov    %eax,0xf01c53c4
f01064b8:	eb 14                	jmp    f01064ce <mp_init+0x245>
			} else {
				cprintf("SMP: too many CPUs, CPU %d disabled\n",
f01064ba:	0f b6 47 01          	movzbl 0x1(%edi),%eax
f01064be:	89 44 24 04          	mov    %eax,0x4(%esp)
f01064c2:	c7 04 24 c8 85 10 f0 	movl   $0xf01085c8,(%esp)
f01064c9:	e8 c4 d9 ff ff       	call   f0103e92 <cprintf>
					proc->apicid);
			}
			p += sizeof(struct mpproc);
f01064ce:	83 c7 14             	add    $0x14,%edi
			continue;
f01064d1:	eb 26                	jmp    f01064f9 <mp_init+0x270>
		case MPBUS:
		case MPIOAPIC:
		case MPIOINTR:
		case MPLINTR:
			p += 8;
f01064d3:	83 c7 08             	add    $0x8,%edi
			continue;
f01064d6:	eb 21                	jmp    f01064f9 <mp_init+0x270>
		default:
			cprintf("mpinit: unknown config type %x\n", *p);
f01064d8:	0f b6 c0             	movzbl %al,%eax
f01064db:	89 44 24 04          	mov    %eax,0x4(%esp)
f01064df:	c7 04 24 f0 85 10 f0 	movl   $0xf01085f0,(%esp)
f01064e6:	e8 a7 d9 ff ff       	call   f0103e92 <cprintf>
			ismp = 0;
f01064eb:	c7 05 00 50 1c f0 00 	movl   $0x0,0xf01c5000
f01064f2:	00 00 00 
			i = conf->entry;
f01064f5:	0f b7 73 22          	movzwl 0x22(%ebx),%esi
	if ((conf = mpconfig(&mp)) == 0)
		return;
	ismp = 1;
	lapic = (uint32_t *)conf->lapicaddr;

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f01064f9:	83 c6 01             	add    $0x1,%esi
f01064fc:	0f b7 43 22          	movzwl 0x22(%ebx),%eax
f0106500:	39 f0                	cmp    %esi,%eax
f0106502:	0f 87 71 ff ff ff    	ja     f0106479 <mp_init+0x1f0>
			ismp = 0;
			i = conf->entry;
		}
	}

	bootcpu->cpu_status = CPU_STARTED;
f0106508:	a1 c0 53 1c f0       	mov    0xf01c53c0,%eax
f010650d:	c7 40 04 01 00 00 00 	movl   $0x1,0x4(%eax)
	if (!ismp) {
f0106514:	83 3d 00 50 1c f0 00 	cmpl   $0x0,0xf01c5000
f010651b:	75 22                	jne    f010653f <mp_init+0x2b6>
		// Didn't like what we found; fall back to no MP.
		ncpu = 1;
f010651d:	c7 05 c4 53 1c f0 01 	movl   $0x1,0xf01c53c4
f0106524:	00 00 00 
		lapic = NULL;
f0106527:	c7 05 00 60 20 f0 00 	movl   $0x0,0xf0206000
f010652e:	00 00 00 
		cprintf("SMP: configuration not found, SMP disabled\n");
f0106531:	c7 04 24 10 86 10 f0 	movl   $0xf0108610,(%esp)
f0106538:	e8 55 d9 ff ff       	call   f0103e92 <cprintf>
		return;
f010653d:	eb 44                	jmp    f0106583 <mp_init+0x2fa>
	}
	cprintf("SMP: CPU %d found %d CPU(s)\n", bootcpu->cpu_id,  ncpu);
f010653f:	8b 15 c4 53 1c f0    	mov    0xf01c53c4,%edx
f0106545:	89 54 24 08          	mov    %edx,0x8(%esp)
f0106549:	0f b6 00             	movzbl (%eax),%eax
f010654c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106550:	c7 04 24 97 86 10 f0 	movl   $0xf0108697,(%esp)
f0106557:	e8 36 d9 ff ff       	call   f0103e92 <cprintf>

	if (mp->imcrp) {
f010655c:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010655f:	80 78 0c 00          	cmpb   $0x0,0xc(%eax)
f0106563:	74 1e                	je     f0106583 <mp_init+0x2fa>
		// [MP 3.2.6.1] If the hardware implements PIC mode,
		// switch to getting interrupts from the LAPIC.
		cprintf("SMP: Setting IMCR to switch from PIC mode to symmetric I/O mode\n");
f0106565:	c7 04 24 3c 86 10 f0 	movl   $0xf010863c,(%esp)
f010656c:	e8 21 d9 ff ff       	call   f0103e92 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0106571:	ba 22 00 00 00       	mov    $0x22,%edx
f0106576:	b8 70 00 00 00       	mov    $0x70,%eax
f010657b:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010657c:	b2 23                	mov    $0x23,%dl
f010657e:	ec                   	in     (%dx),%al
		outb(0x22, 0x70);   // Select IMCR
		outb(0x23, inb(0x23) | 1);  // Mask external interrupts.
f010657f:	83 c8 01             	or     $0x1,%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0106582:	ee                   	out    %al,(%dx)
	}
}
f0106583:	83 c4 2c             	add    $0x2c,%esp
f0106586:	5b                   	pop    %ebx
f0106587:	5e                   	pop    %esi
f0106588:	5f                   	pop    %edi
f0106589:	5d                   	pop    %ebp
f010658a:	c3                   	ret    

f010658b <lapicw>:

volatile uint32_t *lapic;  // Initialized in mp.c

static void
lapicw(int index, int value)
{
f010658b:	55                   	push   %ebp
f010658c:	89 e5                	mov    %esp,%ebp
	lapic[index] = value;
f010658e:	8b 0d 00 60 20 f0    	mov    0xf0206000,%ecx
f0106594:	8d 04 81             	lea    (%ecx,%eax,4),%eax
f0106597:	89 10                	mov    %edx,(%eax)
	lapic[ID];  // wait for write to finish, by reading
f0106599:	a1 00 60 20 f0       	mov    0xf0206000,%eax
f010659e:	8b 40 20             	mov    0x20(%eax),%eax
}
f01065a1:	5d                   	pop    %ebp
f01065a2:	c3                   	ret    

f01065a3 <cpunum>:
	lapicw(TPR, 0);
}

int
cpunum(void)
{
f01065a3:	55                   	push   %ebp
f01065a4:	89 e5                	mov    %esp,%ebp
	if (lapic)
f01065a6:	a1 00 60 20 f0       	mov    0xf0206000,%eax
f01065ab:	85 c0                	test   %eax,%eax
f01065ad:	74 08                	je     f01065b7 <cpunum+0x14>
		return lapic[ID] >> 24;
f01065af:	8b 40 20             	mov    0x20(%eax),%eax
f01065b2:	c1 e8 18             	shr    $0x18,%eax
f01065b5:	eb 05                	jmp    f01065bc <cpunum+0x19>
	return 0;
f01065b7:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01065bc:	5d                   	pop    %ebp
f01065bd:	c3                   	ret    

f01065be <lapic_init>:
}

void
lapic_init(void)
{
	if (!lapic) 
f01065be:	83 3d 00 60 20 f0 00 	cmpl   $0x0,0xf0206000
f01065c5:	0f 84 0b 01 00 00    	je     f01066d6 <lapic_init+0x118>
	lapic[ID];  // wait for write to finish, by reading
}

void
lapic_init(void)
{
f01065cb:	55                   	push   %ebp
f01065cc:	89 e5                	mov    %esp,%ebp
	if (!lapic) 
		return;

	// Enable local APIC; set spurious interrupt vector.
	lapicw(SVR, ENABLE | (IRQ_OFFSET + IRQ_SPURIOUS));
f01065ce:	ba 27 01 00 00       	mov    $0x127,%edx
f01065d3:	b8 3c 00 00 00       	mov    $0x3c,%eax
f01065d8:	e8 ae ff ff ff       	call   f010658b <lapicw>

	// The timer repeatedly counts down at bus frequency
	// from lapic[TICR] and then issues an interrupt.  
	// If we cared more about precise timekeeping,
	// TICR would be calibrated using an external time source.
	lapicw(TDCR, X1);
f01065dd:	ba 0b 00 00 00       	mov    $0xb,%edx
f01065e2:	b8 f8 00 00 00       	mov    $0xf8,%eax
f01065e7:	e8 9f ff ff ff       	call   f010658b <lapicw>
	lapicw(TIMER, PERIODIC | (IRQ_OFFSET + IRQ_TIMER));
f01065ec:	ba 20 00 02 00       	mov    $0x20020,%edx
f01065f1:	b8 c8 00 00 00       	mov    $0xc8,%eax
f01065f6:	e8 90 ff ff ff       	call   f010658b <lapicw>
	lapicw(TICR, 10000000); 
f01065fb:	ba 80 96 98 00       	mov    $0x989680,%edx
f0106600:	b8 e0 00 00 00       	mov    $0xe0,%eax
f0106605:	e8 81 ff ff ff       	call   f010658b <lapicw>
	//
	// According to Intel MP Specification, the BIOS should initialize
	// BSP's local APIC in Virtual Wire Mode, in which 8259A's
	// INTR is virtually connected to BSP's LINTIN0. In this mode,
	// we do not need to program the IOAPIC.
	if (thiscpu != bootcpu)
f010660a:	e8 94 ff ff ff       	call   f01065a3 <cpunum>
f010660f:	6b c0 74             	imul   $0x74,%eax,%eax
f0106612:	05 20 50 1c f0       	add    $0xf01c5020,%eax
f0106617:	39 05 c0 53 1c f0    	cmp    %eax,0xf01c53c0
f010661d:	74 0f                	je     f010662e <lapic_init+0x70>
		lapicw(LINT0, MASKED);
f010661f:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106624:	b8 d4 00 00 00       	mov    $0xd4,%eax
f0106629:	e8 5d ff ff ff       	call   f010658b <lapicw>

	// Disable NMI (LINT1) on all CPUs
	lapicw(LINT1, MASKED);
f010662e:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106633:	b8 d8 00 00 00       	mov    $0xd8,%eax
f0106638:	e8 4e ff ff ff       	call   f010658b <lapicw>

	// Disable performance counter overflow interrupts
	// on machines that provide that interrupt entry.
	if (((lapic[VER]>>16) & 0xFF) >= 4)
f010663d:	a1 00 60 20 f0       	mov    0xf0206000,%eax
f0106642:	8b 40 30             	mov    0x30(%eax),%eax
f0106645:	c1 e8 10             	shr    $0x10,%eax
f0106648:	3c 03                	cmp    $0x3,%al
f010664a:	76 0f                	jbe    f010665b <lapic_init+0x9d>
		lapicw(PCINT, MASKED);
f010664c:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106651:	b8 d0 00 00 00       	mov    $0xd0,%eax
f0106656:	e8 30 ff ff ff       	call   f010658b <lapicw>

	// Map error interrupt to IRQ_ERROR.
	lapicw(ERROR, IRQ_OFFSET + IRQ_ERROR);
f010665b:	ba 33 00 00 00       	mov    $0x33,%edx
f0106660:	b8 dc 00 00 00       	mov    $0xdc,%eax
f0106665:	e8 21 ff ff ff       	call   f010658b <lapicw>

	// Clear error status register (requires back-to-back writes).
	lapicw(ESR, 0);
f010666a:	ba 00 00 00 00       	mov    $0x0,%edx
f010666f:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0106674:	e8 12 ff ff ff       	call   f010658b <lapicw>
	lapicw(ESR, 0);
f0106679:	ba 00 00 00 00       	mov    $0x0,%edx
f010667e:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0106683:	e8 03 ff ff ff       	call   f010658b <lapicw>

	// Ack any outstanding interrupts.
	lapicw(EOI, 0);
f0106688:	ba 00 00 00 00       	mov    $0x0,%edx
f010668d:	b8 2c 00 00 00       	mov    $0x2c,%eax
f0106692:	e8 f4 fe ff ff       	call   f010658b <lapicw>

	// Send an Init Level De-Assert to synchronize arbitration ID's.
	lapicw(ICRHI, 0);
f0106697:	ba 00 00 00 00       	mov    $0x0,%edx
f010669c:	b8 c4 00 00 00       	mov    $0xc4,%eax
f01066a1:	e8 e5 fe ff ff       	call   f010658b <lapicw>
	lapicw(ICRLO, BCAST | INIT | LEVEL);
f01066a6:	ba 00 85 08 00       	mov    $0x88500,%edx
f01066ab:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01066b0:	e8 d6 fe ff ff       	call   f010658b <lapicw>
	while(lapic[ICRLO] & DELIVS)
f01066b5:	8b 15 00 60 20 f0    	mov    0xf0206000,%edx
f01066bb:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f01066c1:	f6 c4 10             	test   $0x10,%ah
f01066c4:	75 f5                	jne    f01066bb <lapic_init+0xfd>
		;

	// Enable interrupts on the APIC (but not on the processor).
	lapicw(TPR, 0);
f01066c6:	ba 00 00 00 00       	mov    $0x0,%edx
f01066cb:	b8 20 00 00 00       	mov    $0x20,%eax
f01066d0:	e8 b6 fe ff ff       	call   f010658b <lapicw>
}
f01066d5:	5d                   	pop    %ebp
f01066d6:	f3 c3                	repz ret 

f01066d8 <lapic_eoi>:

// Acknowledge interrupt.
void
lapic_eoi(void)
{
	if (lapic)
f01066d8:	83 3d 00 60 20 f0 00 	cmpl   $0x0,0xf0206000
f01066df:	74 13                	je     f01066f4 <lapic_eoi+0x1c>
}

// Acknowledge interrupt.
void
lapic_eoi(void)
{
f01066e1:	55                   	push   %ebp
f01066e2:	89 e5                	mov    %esp,%ebp
	if (lapic)
		lapicw(EOI, 0);
f01066e4:	ba 00 00 00 00       	mov    $0x0,%edx
f01066e9:	b8 2c 00 00 00       	mov    $0x2c,%eax
f01066ee:	e8 98 fe ff ff       	call   f010658b <lapicw>
}
f01066f3:	5d                   	pop    %ebp
f01066f4:	f3 c3                	repz ret 

f01066f6 <lapic_startap>:

// Start additional processor running entry code at addr.
// See Appendix B of MultiProcessor Specification.
void
lapic_startap(uint8_t apicid, uint32_t addr)
{
f01066f6:	55                   	push   %ebp
f01066f7:	89 e5                	mov    %esp,%ebp
f01066f9:	56                   	push   %esi
f01066fa:	53                   	push   %ebx
f01066fb:	83 ec 10             	sub    $0x10,%esp
f01066fe:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0106701:	8b 75 0c             	mov    0xc(%ebp),%esi
f0106704:	ba 70 00 00 00       	mov    $0x70,%edx
f0106709:	b8 0f 00 00 00       	mov    $0xf,%eax
f010670e:	ee                   	out    %al,(%dx)
f010670f:	b2 71                	mov    $0x71,%dl
f0106711:	b8 0a 00 00 00       	mov    $0xa,%eax
f0106716:	ee                   	out    %al,(%dx)
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0106717:	83 3d 88 4e 1c f0 00 	cmpl   $0x0,0xf01c4e88
f010671e:	75 24                	jne    f0106744 <lapic_startap+0x4e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106720:	c7 44 24 0c 67 04 00 	movl   $0x467,0xc(%esp)
f0106727:	00 
f0106728:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f010672f:	f0 
f0106730:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
f0106737:	00 
f0106738:	c7 04 24 b4 86 10 f0 	movl   $0xf01086b4,(%esp)
f010673f:	e8 fc 98 ff ff       	call   f0100040 <_panic>
	// and the warm reset vector (DWORD based at 40:67) to point at
	// the AP startup code prior to the [universal startup algorithm]."
	outb(IO_RTC, 0xF);  // offset 0xF is shutdown code
	outb(IO_RTC+1, 0x0A);
	wrv = (uint16_t *)KADDR((0x40 << 4 | 0x67));  // Warm reset vector
	wrv[0] = 0;
f0106744:	66 c7 05 67 04 00 f0 	movw   $0x0,0xf0000467
f010674b:	00 00 
	wrv[1] = addr >> 4;
f010674d:	89 f0                	mov    %esi,%eax
f010674f:	c1 e8 04             	shr    $0x4,%eax
f0106752:	66 a3 69 04 00 f0    	mov    %ax,0xf0000469

	// "Universal startup algorithm."
	// Send INIT (level-triggered) interrupt to reset other CPU.
	lapicw(ICRHI, apicid << 24);
f0106758:	c1 e3 18             	shl    $0x18,%ebx
f010675b:	89 da                	mov    %ebx,%edx
f010675d:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106762:	e8 24 fe ff ff       	call   f010658b <lapicw>
	lapicw(ICRLO, INIT | LEVEL | ASSERT);
f0106767:	ba 00 c5 00 00       	mov    $0xc500,%edx
f010676c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106771:	e8 15 fe ff ff       	call   f010658b <lapicw>
	microdelay(200);
	lapicw(ICRLO, INIT | LEVEL);
f0106776:	ba 00 85 00 00       	mov    $0x8500,%edx
f010677b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106780:	e8 06 fe ff ff       	call   f010658b <lapicw>
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0106785:	c1 ee 0c             	shr    $0xc,%esi
f0106788:	81 ce 00 06 00 00    	or     $0x600,%esi
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f010678e:	89 da                	mov    %ebx,%edx
f0106790:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106795:	e8 f1 fd ff ff       	call   f010658b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f010679a:	89 f2                	mov    %esi,%edx
f010679c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01067a1:	e8 e5 fd ff ff       	call   f010658b <lapicw>
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f01067a6:	89 da                	mov    %ebx,%edx
f01067a8:	b8 c4 00 00 00       	mov    $0xc4,%eax
f01067ad:	e8 d9 fd ff ff       	call   f010658b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f01067b2:	89 f2                	mov    %esi,%edx
f01067b4:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01067b9:	e8 cd fd ff ff       	call   f010658b <lapicw>
		microdelay(200);
	}
}
f01067be:	83 c4 10             	add    $0x10,%esp
f01067c1:	5b                   	pop    %ebx
f01067c2:	5e                   	pop    %esi
f01067c3:	5d                   	pop    %ebp
f01067c4:	c3                   	ret    

f01067c5 <lapic_ipi>:

void
lapic_ipi(int vector)
{
f01067c5:	55                   	push   %ebp
f01067c6:	89 e5                	mov    %esp,%ebp
	lapicw(ICRLO, OTHERS | FIXED | vector);
f01067c8:	8b 55 08             	mov    0x8(%ebp),%edx
f01067cb:	81 ca 00 00 0c 00    	or     $0xc0000,%edx
f01067d1:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01067d6:	e8 b0 fd ff ff       	call   f010658b <lapicw>
	while (lapic[ICRLO] & DELIVS)
f01067db:	8b 15 00 60 20 f0    	mov    0xf0206000,%edx
f01067e1:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f01067e7:	f6 c4 10             	test   $0x10,%ah
f01067ea:	75 f5                	jne    f01067e1 <lapic_ipi+0x1c>
		;
}
f01067ec:	5d                   	pop    %ebp
f01067ed:	c3                   	ret    

f01067ee <__spin_initlock>:
}
#endif

void
__spin_initlock(struct spinlock *lk, char *name)
{
f01067ee:	55                   	push   %ebp
f01067ef:	89 e5                	mov    %esp,%ebp
f01067f1:	8b 45 08             	mov    0x8(%ebp),%eax
	lk->locked = 0;
f01067f4:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
#ifdef DEBUG_SPINLOCK
	lk->name = name;
f01067fa:	8b 55 0c             	mov    0xc(%ebp),%edx
f01067fd:	89 50 04             	mov    %edx,0x4(%eax)
	lk->cpu = 0;
f0106800:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
#endif
}
f0106807:	5d                   	pop    %ebp
f0106808:	c3                   	ret    

f0106809 <spin_lock>:
// Loops (spins) until the lock is acquired.
// Holding a lock for a long time may cause
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
f0106809:	55                   	push   %ebp
f010680a:	89 e5                	mov    %esp,%ebp
f010680c:	56                   	push   %esi
f010680d:	53                   	push   %ebx
f010680e:	83 ec 20             	sub    $0x20,%esp
f0106811:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0106814:	83 3b 00             	cmpl   $0x0,(%ebx)
f0106817:	74 14                	je     f010682d <spin_lock+0x24>
f0106819:	8b 73 08             	mov    0x8(%ebx),%esi
f010681c:	e8 82 fd ff ff       	call   f01065a3 <cpunum>
f0106821:	6b c0 74             	imul   $0x74,%eax,%eax
f0106824:	05 20 50 1c f0       	add    $0xf01c5020,%eax
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
f0106829:	39 c6                	cmp    %eax,%esi
f010682b:	74 15                	je     f0106842 <spin_lock+0x39>
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f010682d:	89 da                	mov    %ebx,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f010682f:	b8 01 00 00 00       	mov    $0x1,%eax
f0106834:	f0 87 03             	lock xchg %eax,(%ebx)
f0106837:	b9 01 00 00 00       	mov    $0x1,%ecx
f010683c:	85 c0                	test   %eax,%eax
f010683e:	75 2e                	jne    f010686e <spin_lock+0x65>
f0106840:	eb 37                	jmp    f0106879 <spin_lock+0x70>
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
		panic("CPU %d cannot acquire %s: already holding", cpunum(), lk->name);
f0106842:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106845:	e8 59 fd ff ff       	call   f01065a3 <cpunum>
f010684a:	89 5c 24 10          	mov    %ebx,0x10(%esp)
f010684e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0106852:	c7 44 24 08 c4 86 10 	movl   $0xf01086c4,0x8(%esp)
f0106859:	f0 
f010685a:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
f0106861:	00 
f0106862:	c7 04 24 28 87 10 f0 	movl   $0xf0108728,(%esp)
f0106869:	e8 d2 97 ff ff       	call   f0100040 <_panic>

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
		asm volatile ("pause");
f010686e:	f3 90                	pause  
f0106870:	89 c8                	mov    %ecx,%eax
f0106872:	f0 87 02             	lock xchg %eax,(%edx)
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f0106875:	85 c0                	test   %eax,%eax
f0106877:	75 f5                	jne    f010686e <spin_lock+0x65>
		asm volatile ("pause");

	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
f0106879:	e8 25 fd ff ff       	call   f01065a3 <cpunum>
f010687e:	6b c0 74             	imul   $0x74,%eax,%eax
f0106881:	05 20 50 1c f0       	add    $0xf01c5020,%eax
f0106886:	89 43 08             	mov    %eax,0x8(%ebx)
	get_caller_pcs(lk->pcs);
f0106889:	8d 4b 0c             	lea    0xc(%ebx),%ecx

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f010688c:	89 e8                	mov    %ebp,%eax
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
f010688e:	8d 90 00 00 80 10    	lea    0x10800000(%eax),%edx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0106894:	81 fa ff ff 7f 0e    	cmp    $0xe7fffff,%edx
f010689a:	76 3a                	jbe    f01068d6 <spin_lock+0xcd>
f010689c:	eb 31                	jmp    f01068cf <spin_lock+0xc6>
		    || ebp >= (uint32_t *)IOMEMBASE)
f010689e:	8d 9a 00 00 80 10    	lea    0x10800000(%edx),%ebx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f01068a4:	81 fb ff ff 7f 0e    	cmp    $0xe7fffff,%ebx
f01068aa:	77 12                	ja     f01068be <spin_lock+0xb5>
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f01068ac:	8b 5a 04             	mov    0x4(%edx),%ebx
f01068af:	89 1c 81             	mov    %ebx,(%ecx,%eax,4)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f01068b2:	8b 12                	mov    (%edx),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01068b4:	83 c0 01             	add    $0x1,%eax
f01068b7:	83 f8 0a             	cmp    $0xa,%eax
f01068ba:	75 e2                	jne    f010689e <spin_lock+0x95>
f01068bc:	eb 27                	jmp    f01068e5 <spin_lock+0xdc>
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
		pcs[i] = 0;
f01068be:	c7 04 81 00 00 00 00 	movl   $0x0,(%ecx,%eax,4)
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
f01068c5:	83 c0 01             	add    $0x1,%eax
f01068c8:	83 f8 09             	cmp    $0x9,%eax
f01068cb:	7e f1                	jle    f01068be <spin_lock+0xb5>
f01068cd:	eb 16                	jmp    f01068e5 <spin_lock+0xdc>
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01068cf:	b8 00 00 00 00       	mov    $0x0,%eax
f01068d4:	eb e8                	jmp    f01068be <spin_lock+0xb5>
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f01068d6:	8b 50 04             	mov    0x4(%eax),%edx
f01068d9:	89 53 0c             	mov    %edx,0xc(%ebx)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f01068dc:	8b 10                	mov    (%eax),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01068de:	b8 01 00 00 00       	mov    $0x1,%eax
f01068e3:	eb b9                	jmp    f010689e <spin_lock+0x95>
	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
	get_caller_pcs(lk->pcs);
#endif
}
f01068e5:	83 c4 20             	add    $0x20,%esp
f01068e8:	5b                   	pop    %ebx
f01068e9:	5e                   	pop    %esi
f01068ea:	5d                   	pop    %ebp
f01068eb:	c3                   	ret    

f01068ec <spin_unlock>:

// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
f01068ec:	55                   	push   %ebp
f01068ed:	89 e5                	mov    %esp,%ebp
f01068ef:	57                   	push   %edi
f01068f0:	56                   	push   %esi
f01068f1:	53                   	push   %ebx
f01068f2:	83 ec 6c             	sub    $0x6c,%esp
f01068f5:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f01068f8:	83 3b 00             	cmpl   $0x0,(%ebx)
f01068fb:	74 18                	je     f0106915 <spin_unlock+0x29>
f01068fd:	8b 73 08             	mov    0x8(%ebx),%esi
f0106900:	e8 9e fc ff ff       	call   f01065a3 <cpunum>
f0106905:	6b c0 74             	imul   $0x74,%eax,%eax
f0106908:	05 20 50 1c f0       	add    $0xf01c5020,%eax
// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (!holding(lk)) {
f010690d:	39 c6                	cmp    %eax,%esi
f010690f:	0f 84 d4 00 00 00    	je     f01069e9 <spin_unlock+0xfd>
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
f0106915:	c7 44 24 08 28 00 00 	movl   $0x28,0x8(%esp)
f010691c:	00 
f010691d:	8d 43 0c             	lea    0xc(%ebx),%eax
f0106920:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106924:	8d 45 c0             	lea    -0x40(%ebp),%eax
f0106927:	89 04 24             	mov    %eax,(%esp)
f010692a:	e8 27 f6 ff ff       	call   f0105f56 <memmove>
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
f010692f:	8b 43 08             	mov    0x8(%ebx),%eax
	if (!holding(lk)) {
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
f0106932:	0f b6 30             	movzbl (%eax),%esi
f0106935:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106938:	e8 66 fc ff ff       	call   f01065a3 <cpunum>
f010693d:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0106941:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0106945:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106949:	c7 04 24 f0 86 10 f0 	movl   $0xf01086f0,(%esp)
f0106950:	e8 3d d5 ff ff       	call   f0103e92 <cprintf>
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0106955:	8b 45 c0             	mov    -0x40(%ebp),%eax
f0106958:	85 c0                	test   %eax,%eax
f010695a:	74 71                	je     f01069cd <spin_unlock+0xe1>
f010695c:	8d 5d c0             	lea    -0x40(%ebp),%ebx
f010695f:	8d 7d e4             	lea    -0x1c(%ebp),%edi
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
f0106962:	8d 75 a8             	lea    -0x58(%ebp),%esi
f0106965:	89 74 24 04          	mov    %esi,0x4(%esp)
f0106969:	89 04 24             	mov    %eax,(%esp)
f010696c:	e8 0b ea ff ff       	call   f010537c <debuginfo_eip>
f0106971:	85 c0                	test   %eax,%eax
f0106973:	78 39                	js     f01069ae <spin_unlock+0xc2>
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
f0106975:	8b 03                	mov    (%ebx),%eax
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
f0106977:	89 c2                	mov    %eax,%edx
f0106979:	2b 55 b8             	sub    -0x48(%ebp),%edx
f010697c:	89 54 24 18          	mov    %edx,0x18(%esp)
f0106980:	8b 55 b0             	mov    -0x50(%ebp),%edx
f0106983:	89 54 24 14          	mov    %edx,0x14(%esp)
f0106987:	8b 55 b4             	mov    -0x4c(%ebp),%edx
f010698a:	89 54 24 10          	mov    %edx,0x10(%esp)
f010698e:	8b 55 ac             	mov    -0x54(%ebp),%edx
f0106991:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0106995:	8b 55 a8             	mov    -0x58(%ebp),%edx
f0106998:	89 54 24 08          	mov    %edx,0x8(%esp)
f010699c:	89 44 24 04          	mov    %eax,0x4(%esp)
f01069a0:	c7 04 24 38 87 10 f0 	movl   $0xf0108738,(%esp)
f01069a7:	e8 e6 d4 ff ff       	call   f0103e92 <cprintf>
f01069ac:	eb 12                	jmp    f01069c0 <spin_unlock+0xd4>
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
f01069ae:	8b 03                	mov    (%ebx),%eax
f01069b0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01069b4:	c7 04 24 4f 87 10 f0 	movl   $0xf010874f,(%esp)
f01069bb:	e8 d2 d4 ff ff       	call   f0103e92 <cprintf>
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f01069c0:	39 fb                	cmp    %edi,%ebx
f01069c2:	74 09                	je     f01069cd <spin_unlock+0xe1>
f01069c4:	83 c3 04             	add    $0x4,%ebx
f01069c7:	8b 03                	mov    (%ebx),%eax
f01069c9:	85 c0                	test   %eax,%eax
f01069cb:	75 98                	jne    f0106965 <spin_unlock+0x79>
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
		}
		panic("spin_unlock");
f01069cd:	c7 44 24 08 57 87 10 	movl   $0xf0108757,0x8(%esp)
f01069d4:	f0 
f01069d5:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
f01069dc:	00 
f01069dd:	c7 04 24 28 87 10 f0 	movl   $0xf0108728,(%esp)
f01069e4:	e8 57 96 ff ff       	call   f0100040 <_panic>
	}
	
	lk->pcs[0] = 0;
f01069e9:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
	lk->cpu = 0;
f01069f0:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f01069f7:	b8 00 00 00 00       	mov    $0x0,%eax
f01069fc:	f0 87 03             	lock xchg %eax,(%ebx)
	// after a store. So lock->locked = 0 would work here.
	// The xchg being asm volatile ensures gcc emits it after
	// the above assignments (and after the critical section).
	xchg(&lk->locked, 0);

}
f01069ff:	83 c4 6c             	add    $0x6c,%esp
f0106a02:	5b                   	pop    %ebx
f0106a03:	5e                   	pop    %esi
f0106a04:	5f                   	pop    %edi
f0106a05:	5d                   	pop    %ebp
f0106a06:	c3                   	ret    
f0106a07:	66 90                	xchg   %ax,%ax
f0106a09:	66 90                	xchg   %ax,%ax
f0106a0b:	66 90                	xchg   %ax,%ax
f0106a0d:	66 90                	xchg   %ax,%ax
f0106a0f:	90                   	nop

f0106a10 <__udivdi3>:
f0106a10:	55                   	push   %ebp
f0106a11:	57                   	push   %edi
f0106a12:	56                   	push   %esi
f0106a13:	83 ec 0c             	sub    $0xc,%esp
f0106a16:	8b 44 24 28          	mov    0x28(%esp),%eax
f0106a1a:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f0106a1e:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f0106a22:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0106a26:	85 c0                	test   %eax,%eax
f0106a28:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0106a2c:	89 ea                	mov    %ebp,%edx
f0106a2e:	89 0c 24             	mov    %ecx,(%esp)
f0106a31:	75 2d                	jne    f0106a60 <__udivdi3+0x50>
f0106a33:	39 e9                	cmp    %ebp,%ecx
f0106a35:	77 61                	ja     f0106a98 <__udivdi3+0x88>
f0106a37:	85 c9                	test   %ecx,%ecx
f0106a39:	89 ce                	mov    %ecx,%esi
f0106a3b:	75 0b                	jne    f0106a48 <__udivdi3+0x38>
f0106a3d:	b8 01 00 00 00       	mov    $0x1,%eax
f0106a42:	31 d2                	xor    %edx,%edx
f0106a44:	f7 f1                	div    %ecx
f0106a46:	89 c6                	mov    %eax,%esi
f0106a48:	31 d2                	xor    %edx,%edx
f0106a4a:	89 e8                	mov    %ebp,%eax
f0106a4c:	f7 f6                	div    %esi
f0106a4e:	89 c5                	mov    %eax,%ebp
f0106a50:	89 f8                	mov    %edi,%eax
f0106a52:	f7 f6                	div    %esi
f0106a54:	89 ea                	mov    %ebp,%edx
f0106a56:	83 c4 0c             	add    $0xc,%esp
f0106a59:	5e                   	pop    %esi
f0106a5a:	5f                   	pop    %edi
f0106a5b:	5d                   	pop    %ebp
f0106a5c:	c3                   	ret    
f0106a5d:	8d 76 00             	lea    0x0(%esi),%esi
f0106a60:	39 e8                	cmp    %ebp,%eax
f0106a62:	77 24                	ja     f0106a88 <__udivdi3+0x78>
f0106a64:	0f bd e8             	bsr    %eax,%ebp
f0106a67:	83 f5 1f             	xor    $0x1f,%ebp
f0106a6a:	75 3c                	jne    f0106aa8 <__udivdi3+0x98>
f0106a6c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0106a70:	39 34 24             	cmp    %esi,(%esp)
f0106a73:	0f 86 9f 00 00 00    	jbe    f0106b18 <__udivdi3+0x108>
f0106a79:	39 d0                	cmp    %edx,%eax
f0106a7b:	0f 82 97 00 00 00    	jb     f0106b18 <__udivdi3+0x108>
f0106a81:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0106a88:	31 d2                	xor    %edx,%edx
f0106a8a:	31 c0                	xor    %eax,%eax
f0106a8c:	83 c4 0c             	add    $0xc,%esp
f0106a8f:	5e                   	pop    %esi
f0106a90:	5f                   	pop    %edi
f0106a91:	5d                   	pop    %ebp
f0106a92:	c3                   	ret    
f0106a93:	90                   	nop
f0106a94:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106a98:	89 f8                	mov    %edi,%eax
f0106a9a:	f7 f1                	div    %ecx
f0106a9c:	31 d2                	xor    %edx,%edx
f0106a9e:	83 c4 0c             	add    $0xc,%esp
f0106aa1:	5e                   	pop    %esi
f0106aa2:	5f                   	pop    %edi
f0106aa3:	5d                   	pop    %ebp
f0106aa4:	c3                   	ret    
f0106aa5:	8d 76 00             	lea    0x0(%esi),%esi
f0106aa8:	89 e9                	mov    %ebp,%ecx
f0106aaa:	8b 3c 24             	mov    (%esp),%edi
f0106aad:	d3 e0                	shl    %cl,%eax
f0106aaf:	89 c6                	mov    %eax,%esi
f0106ab1:	b8 20 00 00 00       	mov    $0x20,%eax
f0106ab6:	29 e8                	sub    %ebp,%eax
f0106ab8:	89 c1                	mov    %eax,%ecx
f0106aba:	d3 ef                	shr    %cl,%edi
f0106abc:	89 e9                	mov    %ebp,%ecx
f0106abe:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0106ac2:	8b 3c 24             	mov    (%esp),%edi
f0106ac5:	09 74 24 08          	or     %esi,0x8(%esp)
f0106ac9:	89 d6                	mov    %edx,%esi
f0106acb:	d3 e7                	shl    %cl,%edi
f0106acd:	89 c1                	mov    %eax,%ecx
f0106acf:	89 3c 24             	mov    %edi,(%esp)
f0106ad2:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106ad6:	d3 ee                	shr    %cl,%esi
f0106ad8:	89 e9                	mov    %ebp,%ecx
f0106ada:	d3 e2                	shl    %cl,%edx
f0106adc:	89 c1                	mov    %eax,%ecx
f0106ade:	d3 ef                	shr    %cl,%edi
f0106ae0:	09 d7                	or     %edx,%edi
f0106ae2:	89 f2                	mov    %esi,%edx
f0106ae4:	89 f8                	mov    %edi,%eax
f0106ae6:	f7 74 24 08          	divl   0x8(%esp)
f0106aea:	89 d6                	mov    %edx,%esi
f0106aec:	89 c7                	mov    %eax,%edi
f0106aee:	f7 24 24             	mull   (%esp)
f0106af1:	39 d6                	cmp    %edx,%esi
f0106af3:	89 14 24             	mov    %edx,(%esp)
f0106af6:	72 30                	jb     f0106b28 <__udivdi3+0x118>
f0106af8:	8b 54 24 04          	mov    0x4(%esp),%edx
f0106afc:	89 e9                	mov    %ebp,%ecx
f0106afe:	d3 e2                	shl    %cl,%edx
f0106b00:	39 c2                	cmp    %eax,%edx
f0106b02:	73 05                	jae    f0106b09 <__udivdi3+0xf9>
f0106b04:	3b 34 24             	cmp    (%esp),%esi
f0106b07:	74 1f                	je     f0106b28 <__udivdi3+0x118>
f0106b09:	89 f8                	mov    %edi,%eax
f0106b0b:	31 d2                	xor    %edx,%edx
f0106b0d:	e9 7a ff ff ff       	jmp    f0106a8c <__udivdi3+0x7c>
f0106b12:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0106b18:	31 d2                	xor    %edx,%edx
f0106b1a:	b8 01 00 00 00       	mov    $0x1,%eax
f0106b1f:	e9 68 ff ff ff       	jmp    f0106a8c <__udivdi3+0x7c>
f0106b24:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106b28:	8d 47 ff             	lea    -0x1(%edi),%eax
f0106b2b:	31 d2                	xor    %edx,%edx
f0106b2d:	83 c4 0c             	add    $0xc,%esp
f0106b30:	5e                   	pop    %esi
f0106b31:	5f                   	pop    %edi
f0106b32:	5d                   	pop    %ebp
f0106b33:	c3                   	ret    
f0106b34:	66 90                	xchg   %ax,%ax
f0106b36:	66 90                	xchg   %ax,%ax
f0106b38:	66 90                	xchg   %ax,%ax
f0106b3a:	66 90                	xchg   %ax,%ax
f0106b3c:	66 90                	xchg   %ax,%ax
f0106b3e:	66 90                	xchg   %ax,%ax

f0106b40 <__umoddi3>:
f0106b40:	55                   	push   %ebp
f0106b41:	57                   	push   %edi
f0106b42:	56                   	push   %esi
f0106b43:	83 ec 14             	sub    $0x14,%esp
f0106b46:	8b 44 24 28          	mov    0x28(%esp),%eax
f0106b4a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0106b4e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0106b52:	89 c7                	mov    %eax,%edi
f0106b54:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106b58:	8b 44 24 30          	mov    0x30(%esp),%eax
f0106b5c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0106b60:	89 34 24             	mov    %esi,(%esp)
f0106b63:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0106b67:	85 c0                	test   %eax,%eax
f0106b69:	89 c2                	mov    %eax,%edx
f0106b6b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106b6f:	75 17                	jne    f0106b88 <__umoddi3+0x48>
f0106b71:	39 fe                	cmp    %edi,%esi
f0106b73:	76 4b                	jbe    f0106bc0 <__umoddi3+0x80>
f0106b75:	89 c8                	mov    %ecx,%eax
f0106b77:	89 fa                	mov    %edi,%edx
f0106b79:	f7 f6                	div    %esi
f0106b7b:	89 d0                	mov    %edx,%eax
f0106b7d:	31 d2                	xor    %edx,%edx
f0106b7f:	83 c4 14             	add    $0x14,%esp
f0106b82:	5e                   	pop    %esi
f0106b83:	5f                   	pop    %edi
f0106b84:	5d                   	pop    %ebp
f0106b85:	c3                   	ret    
f0106b86:	66 90                	xchg   %ax,%ax
f0106b88:	39 f8                	cmp    %edi,%eax
f0106b8a:	77 54                	ja     f0106be0 <__umoddi3+0xa0>
f0106b8c:	0f bd e8             	bsr    %eax,%ebp
f0106b8f:	83 f5 1f             	xor    $0x1f,%ebp
f0106b92:	75 5c                	jne    f0106bf0 <__umoddi3+0xb0>
f0106b94:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0106b98:	39 3c 24             	cmp    %edi,(%esp)
f0106b9b:	0f 87 e7 00 00 00    	ja     f0106c88 <__umoddi3+0x148>
f0106ba1:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106ba5:	29 f1                	sub    %esi,%ecx
f0106ba7:	19 c7                	sbb    %eax,%edi
f0106ba9:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0106bad:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106bb1:	8b 44 24 08          	mov    0x8(%esp),%eax
f0106bb5:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0106bb9:	83 c4 14             	add    $0x14,%esp
f0106bbc:	5e                   	pop    %esi
f0106bbd:	5f                   	pop    %edi
f0106bbe:	5d                   	pop    %ebp
f0106bbf:	c3                   	ret    
f0106bc0:	85 f6                	test   %esi,%esi
f0106bc2:	89 f5                	mov    %esi,%ebp
f0106bc4:	75 0b                	jne    f0106bd1 <__umoddi3+0x91>
f0106bc6:	b8 01 00 00 00       	mov    $0x1,%eax
f0106bcb:	31 d2                	xor    %edx,%edx
f0106bcd:	f7 f6                	div    %esi
f0106bcf:	89 c5                	mov    %eax,%ebp
f0106bd1:	8b 44 24 04          	mov    0x4(%esp),%eax
f0106bd5:	31 d2                	xor    %edx,%edx
f0106bd7:	f7 f5                	div    %ebp
f0106bd9:	89 c8                	mov    %ecx,%eax
f0106bdb:	f7 f5                	div    %ebp
f0106bdd:	eb 9c                	jmp    f0106b7b <__umoddi3+0x3b>
f0106bdf:	90                   	nop
f0106be0:	89 c8                	mov    %ecx,%eax
f0106be2:	89 fa                	mov    %edi,%edx
f0106be4:	83 c4 14             	add    $0x14,%esp
f0106be7:	5e                   	pop    %esi
f0106be8:	5f                   	pop    %edi
f0106be9:	5d                   	pop    %ebp
f0106bea:	c3                   	ret    
f0106beb:	90                   	nop
f0106bec:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106bf0:	8b 04 24             	mov    (%esp),%eax
f0106bf3:	be 20 00 00 00       	mov    $0x20,%esi
f0106bf8:	89 e9                	mov    %ebp,%ecx
f0106bfa:	29 ee                	sub    %ebp,%esi
f0106bfc:	d3 e2                	shl    %cl,%edx
f0106bfe:	89 f1                	mov    %esi,%ecx
f0106c00:	d3 e8                	shr    %cl,%eax
f0106c02:	89 e9                	mov    %ebp,%ecx
f0106c04:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106c08:	8b 04 24             	mov    (%esp),%eax
f0106c0b:	09 54 24 04          	or     %edx,0x4(%esp)
f0106c0f:	89 fa                	mov    %edi,%edx
f0106c11:	d3 e0                	shl    %cl,%eax
f0106c13:	89 f1                	mov    %esi,%ecx
f0106c15:	89 44 24 08          	mov    %eax,0x8(%esp)
f0106c19:	8b 44 24 10          	mov    0x10(%esp),%eax
f0106c1d:	d3 ea                	shr    %cl,%edx
f0106c1f:	89 e9                	mov    %ebp,%ecx
f0106c21:	d3 e7                	shl    %cl,%edi
f0106c23:	89 f1                	mov    %esi,%ecx
f0106c25:	d3 e8                	shr    %cl,%eax
f0106c27:	89 e9                	mov    %ebp,%ecx
f0106c29:	09 f8                	or     %edi,%eax
f0106c2b:	8b 7c 24 10          	mov    0x10(%esp),%edi
f0106c2f:	f7 74 24 04          	divl   0x4(%esp)
f0106c33:	d3 e7                	shl    %cl,%edi
f0106c35:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106c39:	89 d7                	mov    %edx,%edi
f0106c3b:	f7 64 24 08          	mull   0x8(%esp)
f0106c3f:	39 d7                	cmp    %edx,%edi
f0106c41:	89 c1                	mov    %eax,%ecx
f0106c43:	89 14 24             	mov    %edx,(%esp)
f0106c46:	72 2c                	jb     f0106c74 <__umoddi3+0x134>
f0106c48:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f0106c4c:	72 22                	jb     f0106c70 <__umoddi3+0x130>
f0106c4e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0106c52:	29 c8                	sub    %ecx,%eax
f0106c54:	19 d7                	sbb    %edx,%edi
f0106c56:	89 e9                	mov    %ebp,%ecx
f0106c58:	89 fa                	mov    %edi,%edx
f0106c5a:	d3 e8                	shr    %cl,%eax
f0106c5c:	89 f1                	mov    %esi,%ecx
f0106c5e:	d3 e2                	shl    %cl,%edx
f0106c60:	89 e9                	mov    %ebp,%ecx
f0106c62:	d3 ef                	shr    %cl,%edi
f0106c64:	09 d0                	or     %edx,%eax
f0106c66:	89 fa                	mov    %edi,%edx
f0106c68:	83 c4 14             	add    $0x14,%esp
f0106c6b:	5e                   	pop    %esi
f0106c6c:	5f                   	pop    %edi
f0106c6d:	5d                   	pop    %ebp
f0106c6e:	c3                   	ret    
f0106c6f:	90                   	nop
f0106c70:	39 d7                	cmp    %edx,%edi
f0106c72:	75 da                	jne    f0106c4e <__umoddi3+0x10e>
f0106c74:	8b 14 24             	mov    (%esp),%edx
f0106c77:	89 c1                	mov    %eax,%ecx
f0106c79:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f0106c7d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0106c81:	eb cb                	jmp    f0106c4e <__umoddi3+0x10e>
f0106c83:	90                   	nop
f0106c84:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106c88:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f0106c8c:	0f 82 0f ff ff ff    	jb     f0106ba1 <__umoddi3+0x61>
f0106c92:	e9 1a ff ff ff       	jmp    f0106bb1 <__umoddi3+0x71>
