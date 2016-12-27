
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
f010004b:	83 3d 80 7e 1c f0 00 	cmpl   $0x0,0xf01c7e80
f0100052:	75 46                	jne    f010009a <_panic+0x5a>
		goto dead;
	panicstr = fmt;
f0100054:	89 35 80 7e 1c f0    	mov    %esi,0xf01c7e80

	// Be extra sure that the machine is in as reasonable state
	__asm __volatile("cli; cld");
f010005a:	fa                   	cli    
f010005b:	fc                   	cld    

	va_start(ap, fmt);
f010005c:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic on CPU %d at %s:%d: ", cpunum(), file, line);
f010005f:	e8 1f 65 00 00       	call   f0106583 <cpunum>
f0100064:	8b 55 0c             	mov    0xc(%ebp),%edx
f0100067:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010006b:	8b 55 08             	mov    0x8(%ebp),%edx
f010006e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100072:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100076:	c7 04 24 80 6c 10 f0 	movl   $0xf0106c80,(%esp)
f010007d:	e8 f4 3d 00 00       	call   f0103e76 <cprintf>
	vcprintf(fmt, ap);
f0100082:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100086:	89 34 24             	mov    %esi,(%esp)
f0100089:	e8 b5 3d 00 00       	call   f0103e43 <vcprintf>
	cprintf("\n");
f010008e:	c7 04 24 38 7d 10 f0 	movl   $0xf0107d38,(%esp)
f0100095:	e8 dc 3d 00 00       	call   f0103e76 <cprintf>
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
f01000af:	b8 04 90 20 f0       	mov    $0xf0209004,%eax
f01000b4:	2d eb 61 1c f0       	sub    $0xf01c61eb,%eax
f01000b9:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000bd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01000c4:	00 
f01000c5:	c7 04 24 eb 61 1c f0 	movl   $0xf01c61eb,(%esp)
f01000cc:	e8 18 5e 00 00       	call   f0105ee9 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000d1:	e8 19 06 00 00       	call   f01006ef <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000d6:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000dd:	00 
f01000de:	c7 04 24 ec 6c 10 f0 	movl   $0xf0106cec,(%esp)
f01000e5:	e8 8c 3d 00 00       	call   f0103e76 <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f01000ea:	e8 22 14 00 00       	call   f0101511 <mem_init>

	// Lab 3 user environment initialization functions
	env_init();
f01000ef:	e8 2a 35 00 00       	call   f010361e <env_init>
	trap_init();
f01000f4:	e8 20 3e 00 00       	call   f0103f19 <trap_init>

	// Lab 4 multiprocessor initialization functions
	mp_init();
f01000f9:	e8 6b 61 00 00       	call   f0106269 <mp_init>
	lapic_init();
f01000fe:	66 90                	xchg   %ax,%ax
f0100100:	e8 99 64 00 00       	call   f010659e <lapic_init>

	// Lab 4 multitasking initialization functions
	pic_init();
f0100105:	e8 99 3c 00 00       	call   f0103da3 <pic_init>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f010010a:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f0100111:	e8 d3 66 00 00       	call   f01067e9 <spin_lock>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100116:	83 3d 88 7e 1c f0 07 	cmpl   $0x7,0xf01c7e88
f010011d:	77 24                	ja     f0100143 <i386_init+0x9b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010011f:	c7 44 24 0c 00 70 00 	movl   $0x7000,0xc(%esp)
f0100126:	00 
f0100127:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
f010012e:	f0 
f010012f:	c7 44 24 04 6a 00 00 	movl   $0x6a,0x4(%esp)
f0100136:	00 
f0100137:	c7 04 24 07 6d 10 f0 	movl   $0xf0106d07,(%esp)
f010013e:	e8 fd fe ff ff       	call   f0100040 <_panic>
	void *code;
	struct Cpu *c;

	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);
f0100143:	b8 96 61 10 f0       	mov    $0xf0106196,%eax
f0100148:	2d 1c 61 10 f0       	sub    $0xf010611c,%eax
f010014d:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100151:	c7 44 24 04 1c 61 10 	movl   $0xf010611c,0x4(%esp)
f0100158:	f0 
f0100159:	c7 04 24 00 70 00 f0 	movl   $0xf0007000,(%esp)
f0100160:	e8 d1 5d 00 00       	call   f0105f36 <memmove>

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100165:	6b 05 c4 83 1c f0 74 	imul   $0x74,0xf01c83c4,%eax
f010016c:	05 20 80 1c f0       	add    $0xf01c8020,%eax
f0100171:	3d 20 80 1c f0       	cmp    $0xf01c8020,%eax
f0100176:	76 62                	jbe    f01001da <i386_init+0x132>
f0100178:	bb 20 80 1c f0       	mov    $0xf01c8020,%ebx
		if (c == cpus + cpunum())  // We've started already.
f010017d:	e8 01 64 00 00       	call   f0106583 <cpunum>
f0100182:	6b c0 74             	imul   $0x74,%eax,%eax
f0100185:	05 20 80 1c f0       	add    $0xf01c8020,%eax
f010018a:	39 c3                	cmp    %eax,%ebx
f010018c:	74 39                	je     f01001c7 <i386_init+0x11f>
f010018e:	89 d8                	mov    %ebx,%eax
f0100190:	2d 20 80 1c f0       	sub    $0xf01c8020,%eax
			continue;

		// Tell mpentry.S what stack to use 
		mpentry_kstack = percpu_kstacks[c - cpus] + KSTKSIZE;
f0100195:	c1 f8 02             	sar    $0x2,%eax
f0100198:	69 c0 35 c2 72 4f    	imul   $0x4f72c235,%eax,%eax
f010019e:	c1 e0 0f             	shl    $0xf,%eax
f01001a1:	8d 80 00 10 1d f0    	lea    -0xfe2f000(%eax),%eax
f01001a7:	a3 84 7e 1c f0       	mov    %eax,0xf01c7e84
		// Start the CPU at mpentry_start
		lapic_startap(c->cpu_id, PADDR(code));
f01001ac:	c7 44 24 04 00 70 00 	movl   $0x7000,0x4(%esp)
f01001b3:	00 
f01001b4:	0f b6 03             	movzbl (%ebx),%eax
f01001b7:	89 04 24             	mov    %eax,(%esp)
f01001ba:	e8 17 65 00 00       	call   f01066d6 <lapic_startap>
		// Wait for the CPU to finish some basic setup in mp_main()
		while(c->cpu_status != CPU_STARTED)
f01001bf:	8b 43 04             	mov    0x4(%ebx),%eax
f01001c2:	83 f8 01             	cmp    $0x1,%eax
f01001c5:	75 f8                	jne    f01001bf <i386_init+0x117>
	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f01001c7:	83 c3 74             	add    $0x74,%ebx
f01001ca:	6b 05 c4 83 1c f0 74 	imul   $0x74,0xf01c83c4,%eax
f01001d1:	05 20 80 1c f0       	add    $0xf01c8020,%eax
f01001d6:	39 c3                	cmp    %eax,%ebx
f01001d8:	72 a3                	jb     f010017d <i386_init+0xd5>
	// Starting non-boot CPUs
	boot_aps();

	// Should always have idle processes at first.
	int i;
	cprintf("create idle env  \n:");
f01001da:	c7 04 24 13 6d 10 f0 	movl   $0xf0106d13,(%esp)
f01001e1:	e8 90 3c 00 00       	call   f0103e76 <cprintf>
	ENV_CREATE(user_idle, ENV_TYPE_IDLE);
f01001e6:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01001ed:	00 
f01001ee:	c7 44 24 04 1d 3c 00 	movl   $0x3c1d,0x4(%esp)
f01001f5:	00 
f01001f6:	c7 04 24 0f 32 15 f0 	movl   $0xf015320f,(%esp)
f01001fd:	e8 e2 35 00 00       	call   f01037e4 <env_create>
		//cprintf("create idle env %d \n:",i);
		ENV_CREATE(user_idle, ENV_TYPE_IDLE);
	}*/

	// Start fs.
	cprintf("create fs env  \n:");
f0100202:	c7 04 24 27 6d 10 f0 	movl   $0xf0106d27,(%esp)
f0100209:	e8 68 3c 00 00       	call   f0103e76 <cprintf>
	ENV_CREATE(fs_fs, ENV_TYPE_FS);
f010020e:	c7 44 24 08 02 00 00 	movl   $0x2,0x8(%esp)
f0100215:	00 
f0100216:	c7 44 24 04 67 63 01 	movl   $0x16367,0x4(%esp)
f010021d:	00 
f010021e:	c7 04 24 84 fe 1a f0 	movl   $0xf01afe84,(%esp)
f0100225:	e8 ba 35 00 00       	call   f01037e4 <env_create>

#if defined(TEST)
	// Don't touch -- used by grading script!
	ENV_CREATE(TEST, ENV_TYPE_USER);
f010022a:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0100231:	00 
f0100232:	c7 44 24 04 63 4c 00 	movl   $0x4c63,0x4(%esp)
f0100239:	00 
f010023a:	c7 04 24 21 b2 1a f0 	movl   $0xf01ab221,(%esp)
f0100241:	e8 9e 35 00 00       	call   f01037e4 <env_create>
	ENV_CREATE(user_icode, ENV_TYPE_USER);

#endif // TEST*

	// Schedule and run the first user environment!
	sched_yield();
f0100246:	e8 55 49 00 00       	call   f0104ba0 <sched_yield>

f010024b <mp_main>:
}

// Setup code for APs
void
mp_main(void)
{
f010024b:	55                   	push   %ebp
f010024c:	89 e5                	mov    %esp,%ebp
f010024e:	83 ec 18             	sub    $0x18,%esp
	// We are in high EIP now, safe to switch to kern_pgdir 
	lcr3(PADDR(kern_pgdir));
f0100251:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100256:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010025b:	77 20                	ja     f010027d <mp_main+0x32>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010025d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100261:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
f0100268:	f0 
f0100269:	c7 44 24 04 81 00 00 	movl   $0x81,0x4(%esp)
f0100270:	00 
f0100271:	c7 04 24 07 6d 10 f0 	movl   $0xf0106d07,(%esp)
f0100278:	e8 c3 fd ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f010027d:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0100282:	0f 22 d8             	mov    %eax,%cr3
	cprintf("SMP: CPU %d starting\n", cpunum());
f0100285:	e8 f9 62 00 00       	call   f0106583 <cpunum>
f010028a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010028e:	c7 04 24 39 6d 10 f0 	movl   $0xf0106d39,(%esp)
f0100295:	e8 dc 3b 00 00       	call   f0103e76 <cprintf>

	lapic_init();
f010029a:	e8 ff 62 00 00       	call   f010659e <lapic_init>
	env_init_percpu();
f010029f:	e8 50 33 00 00       	call   f01035f4 <env_init_percpu>
	trap_init_percpu();
f01002a4:	e8 e7 3b 00 00       	call   f0103e90 <trap_init_percpu>
	xchg(&thiscpu->cpu_status, CPU_STARTED); // tell boot_aps() we're up
f01002a9:	e8 d5 62 00 00       	call   f0106583 <cpunum>
f01002ae:	6b d0 74             	imul   $0x74,%eax,%edx
f01002b1:	81 c2 20 80 1c f0    	add    $0xf01c8020,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f01002b7:	b8 01 00 00 00       	mov    $0x1,%eax
f01002bc:	f0 87 42 04          	lock xchg %eax,0x4(%edx)
f01002c0:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f01002c7:	e8 1d 65 00 00       	call   f01067e9 <spin_lock>
	// to start running processes on this CPU.  But make sure that
	// only one CPU can enter the scheduler at a time!
	//
	// Your code here:
	lock_kernel();
	sched_yield();
f01002cc:	e8 cf 48 00 00       	call   f0104ba0 <sched_yield>

f01002d1 <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f01002d1:	55                   	push   %ebp
f01002d2:	89 e5                	mov    %esp,%ebp
f01002d4:	53                   	push   %ebx
f01002d5:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f01002d8:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f01002db:	8b 45 0c             	mov    0xc(%ebp),%eax
f01002de:	89 44 24 08          	mov    %eax,0x8(%esp)
f01002e2:	8b 45 08             	mov    0x8(%ebp),%eax
f01002e5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01002e9:	c7 04 24 4f 6d 10 f0 	movl   $0xf0106d4f,(%esp)
f01002f0:	e8 81 3b 00 00       	call   f0103e76 <cprintf>
	vcprintf(fmt, ap);
f01002f5:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01002f9:	8b 45 10             	mov    0x10(%ebp),%eax
f01002fc:	89 04 24             	mov    %eax,(%esp)
f01002ff:	e8 3f 3b 00 00       	call   f0103e43 <vcprintf>
	cprintf("\n");
f0100304:	c7 04 24 38 7d 10 f0 	movl   $0xf0107d38,(%esp)
f010030b:	e8 66 3b 00 00       	call   f0103e76 <cprintf>
	va_end(ap);
}
f0100310:	83 c4 14             	add    $0x14,%esp
f0100313:	5b                   	pop    %ebx
f0100314:	5d                   	pop    %ebp
f0100315:	c3                   	ret    
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
f010034b:	a1 24 72 1c f0       	mov    0xf01c7224,%eax
f0100350:	8d 48 01             	lea    0x1(%eax),%ecx
f0100353:	89 0d 24 72 1c f0    	mov    %ecx,0xf01c7224
f0100359:	88 90 20 70 1c f0    	mov    %dl,-0xfe38fe0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f010035f:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100365:	75 0a                	jne    f0100371 <cons_intr+0x35>
			cons.wpos = 0;
f0100367:	c7 05 24 72 1c f0 00 	movl   $0x0,0xf01c7224
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
f0100397:	83 0d 00 70 1c f0 40 	orl    $0x40,0xf01c7000
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
f01003af:	8b 0d 00 70 1c f0    	mov    0xf01c7000,%ecx
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
f01003d6:	89 0d 00 70 1c f0    	mov    %ecx,0xf01c7000
		return 0;
f01003dc:	b8 00 00 00 00       	mov    $0x0,%eax
f01003e1:	e9 9d 00 00 00       	jmp    f0100483 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f01003e6:	8b 0d 00 70 1c f0    	mov    0xf01c7000,%ecx
f01003ec:	f6 c1 40             	test   $0x40,%cl
f01003ef:	74 0e                	je     f01003ff <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f01003f1:	83 c8 80             	or     $0xffffff80,%eax
f01003f4:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f01003f6:	83 e1 bf             	and    $0xffffffbf,%ecx
f01003f9:	89 0d 00 70 1c f0    	mov    %ecx,0xf01c7000
	}

	shift |= shiftcode[data];
f01003ff:	0f b6 d2             	movzbl %dl,%edx
f0100402:	0f b6 82 c0 6e 10 f0 	movzbl -0xfef9140(%edx),%eax
f0100409:	0b 05 00 70 1c f0    	or     0xf01c7000,%eax
	shift ^= togglecode[data];
f010040f:	0f b6 8a c0 6d 10 f0 	movzbl -0xfef9240(%edx),%ecx
f0100416:	31 c8                	xor    %ecx,%eax
f0100418:	a3 00 70 1c f0       	mov    %eax,0xf01c7000

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
f0100462:	c7 04 24 69 6d 10 f0 	movl   $0xf0106d69,(%esp)
f0100469:	e8 08 3a 00 00       	call   f0103e76 <cprintf>
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
f010054c:	0f b7 05 28 72 1c f0 	movzwl 0xf01c7228,%eax
f0100553:	66 85 c0             	test   %ax,%ax
f0100556:	0f 84 e5 00 00 00    	je     f0100641 <cons_putc+0x1b8>
			crt_pos--;
f010055c:	83 e8 01             	sub    $0x1,%eax
f010055f:	66 a3 28 72 1c f0    	mov    %ax,0xf01c7228
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100565:	0f b7 c0             	movzwl %ax,%eax
f0100568:	66 81 e7 00 ff       	and    $0xff00,%di
f010056d:	83 cf 20             	or     $0x20,%edi
f0100570:	8b 15 2c 72 1c f0    	mov    0xf01c722c,%edx
f0100576:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f010057a:	eb 78                	jmp    f01005f4 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f010057c:	66 83 05 28 72 1c f0 	addw   $0x50,0xf01c7228
f0100583:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f0100584:	0f b7 05 28 72 1c f0 	movzwl 0xf01c7228,%eax
f010058b:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100591:	c1 e8 16             	shr    $0x16,%eax
f0100594:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0100597:	c1 e0 04             	shl    $0x4,%eax
f010059a:	66 a3 28 72 1c f0    	mov    %ax,0xf01c7228
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
f01005d6:	0f b7 05 28 72 1c f0 	movzwl 0xf01c7228,%eax
f01005dd:	8d 50 01             	lea    0x1(%eax),%edx
f01005e0:	66 89 15 28 72 1c f0 	mov    %dx,0xf01c7228
f01005e7:	0f b7 c0             	movzwl %ax,%eax
f01005ea:	8b 15 2c 72 1c f0    	mov    0xf01c722c,%edx
f01005f0:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f01005f4:	66 81 3d 28 72 1c f0 	cmpw   $0x7cf,0xf01c7228
f01005fb:	cf 07 
f01005fd:	76 42                	jbe    f0100641 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f01005ff:	a1 2c 72 1c f0       	mov    0xf01c722c,%eax
f0100604:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010060b:	00 
f010060c:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100612:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100616:	89 04 24             	mov    %eax,(%esp)
f0100619:	e8 18 59 00 00       	call   f0105f36 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010061e:	8b 15 2c 72 1c f0    	mov    0xf01c722c,%edx
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
f0100639:	66 83 2d 28 72 1c f0 	subw   $0x50,0xf01c7228
f0100640:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100641:	8b 0d 30 72 1c f0    	mov    0xf01c7230,%ecx
f0100647:	b8 0e 00 00 00       	mov    $0xe,%eax
f010064c:	89 ca                	mov    %ecx,%edx
f010064e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010064f:	0f b7 1d 28 72 1c f0 	movzwl 0xf01c7228,%ebx
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
f0100677:	83 3d 34 72 1c f0 00 	cmpl   $0x0,0xf01c7234
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
f01006b5:	a1 20 72 1c f0       	mov    0xf01c7220,%eax
f01006ba:	3b 05 24 72 1c f0    	cmp    0xf01c7224,%eax
f01006c0:	74 26                	je     f01006e8 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f01006c2:	8d 50 01             	lea    0x1(%eax),%edx
f01006c5:	89 15 20 72 1c f0    	mov    %edx,0xf01c7220
f01006cb:	0f b6 88 20 70 1c f0 	movzbl -0xfe38fe0(%eax),%ecx
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
f01006dc:	c7 05 20 72 1c f0 00 	movl   $0x0,0xf01c7220
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
f0100715:	c7 05 30 72 1c f0 b4 	movl   $0x3b4,0xf01c7230
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
f010072d:	c7 05 30 72 1c f0 d4 	movl   $0x3d4,0xf01c7230
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
f010073c:	8b 0d 30 72 1c f0    	mov    0xf01c7230,%ecx
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
f0100761:	89 3d 2c 72 1c f0    	mov    %edi,0xf01c722c
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f0100767:	0f b6 d8             	movzbl %al,%ebx
f010076a:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f010076c:	66 89 35 28 72 1c f0 	mov    %si,0xf01c7228

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
f0100787:	e8 a8 35 00 00       	call   f0103d34 <irq_setmask_8259A>
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
f01007d9:	89 0d 34 72 1c f0    	mov    %ecx,0xf01c7234
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
f01007e9:	c7 04 24 75 6d 10 f0 	movl   $0xf0106d75,(%esp)
f01007f0:	e8 81 36 00 00       	call   f0103e76 <cprintf>
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
f010084d:	e8 24 36 00 00       	call   f0103e76 <cprintf>
f0100852:	c7 44 24 08 80 70 10 	movl   $0xf0107080,0x8(%esp)
f0100859:	f0 
f010085a:	c7 44 24 04 ec 6f 10 	movl   $0xf0106fec,0x4(%esp)
f0100861:	f0 
f0100862:	c7 04 24 e3 6f 10 f0 	movl   $0xf0106fe3,(%esp)
f0100869:	e8 08 36 00 00       	call   f0103e76 <cprintf>
f010086e:	c7 44 24 08 a8 70 10 	movl   $0xf01070a8,0x8(%esp)
f0100875:	f0 
f0100876:	c7 44 24 04 f5 6f 10 	movl   $0xf0106ff5,0x4(%esp)
f010087d:	f0 
f010087e:	c7 04 24 e3 6f 10 f0 	movl   $0xf0106fe3,(%esp)
f0100885:	e8 ec 35 00 00       	call   f0103e76 <cprintf>
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
f010089e:	e8 d3 35 00 00       	call   f0103e76 <cprintf>
	cprintf(" this is work 1 insert:\n");
f01008a3:	c7 04 24 18 70 10 f0 	movl   $0xf0107018,(%esp)
f01008aa:	e8 c7 35 00 00       	call   f0103e76 <cprintf>
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
f01008af:	c7 44 24 08 0f 00 00 	movl   $0xf,0x8(%esp)
f01008b6:	00 
f01008b7:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
f01008be:	00 
f01008bf:	c7 04 24 d4 70 10 f0 	movl   $0xf01070d4,(%esp)
f01008c6:	e8 ab 35 00 00       	call   f0103e76 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
f01008cb:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f01008d2:	00 
f01008d3:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f01008da:	f0 
f01008db:	c7 04 24 0c 71 10 f0 	movl   $0xf010710c,(%esp)
f01008e2:	e8 8f 35 00 00       	call   f0103e76 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01008e7:	c7 44 24 08 77 6c 10 	movl   $0x106c77,0x8(%esp)
f01008ee:	00 
f01008ef:	c7 44 24 04 77 6c 10 	movl   $0xf0106c77,0x4(%esp)
f01008f6:	f0 
f01008f7:	c7 04 24 34 71 10 f0 	movl   $0xf0107134,(%esp)
f01008fe:	e8 73 35 00 00       	call   f0103e76 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f0100903:	c7 44 24 08 eb 61 1c 	movl   $0x1c61eb,0x8(%esp)
f010090a:	00 
f010090b:	c7 44 24 04 eb 61 1c 	movl   $0xf01c61eb,0x4(%esp)
f0100912:	f0 
f0100913:	c7 04 24 58 71 10 f0 	movl   $0xf0107158,(%esp)
f010091a:	e8 57 35 00 00       	call   f0103e76 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f010091f:	c7 44 24 08 04 90 20 	movl   $0x209004,0x8(%esp)
f0100926:	00 
f0100927:	c7 44 24 04 04 90 20 	movl   $0xf0209004,0x4(%esp)
f010092e:	f0 
f010092f:	c7 04 24 7c 71 10 f0 	movl   $0xf010717c,(%esp)
f0100936:	e8 3b 35 00 00       	call   f0103e76 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f010093b:	b8 03 94 20 f0       	mov    $0xf0209403,%eax
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
f010095e:	e8 13 35 00 00       	call   f0103e76 <cprintf>
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
f0100979:	e8 f8 34 00 00       	call   f0103e76 <cprintf>
	cprintf("\n");
f010097e:	c7 04 24 38 7d 10 f0 	movl   $0xf0107d38,(%esp)
f0100985:	e8 ec 34 00 00       	call   f0103e76 <cprintf>

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
f01009e8:	e8 89 34 00 00       	call   f0103e76 <cprintf>
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
f0100a12:	e8 5f 34 00 00       	call   f0103e76 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f0100a17:	c7 04 24 2c 72 10 f0 	movl   $0xf010722c,(%esp)
f0100a1e:	e8 53 34 00 00       	call   f0103e76 <cprintf>

	if (tf != NULL)
f0100a23:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f0100a27:	74 0b                	je     f0100a34 <monitor+0x32>
		print_trapframe(tf);
f0100a29:	8b 45 08             	mov    0x8(%ebp),%eax
f0100a2c:	89 04 24             	mov    %eax,(%esp)
f0100a2f:	e8 4f 3b 00 00       	call   f0104583 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f0100a34:	c7 04 24 42 70 10 f0 	movl   $0xf0107042,(%esp)
f0100a3b:	e8 d0 51 00 00       	call   f0105c10 <readline>
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
f0100a73:	e8 11 54 00 00       	call   f0105e89 <strchr>
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
f0100a95:	e8 dc 33 00 00       	call   f0103e76 <cprintf>
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
f0100ac4:	e8 c0 53 00 00       	call   f0105e89 <strchr>
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
f0100af8:	e8 08 53 00 00       	call   f0105e05 <strcmp>
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
f0100b3b:	e8 36 33 00 00       	call   f0103e76 <cprintf>
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
f0100b67:	83 3d 38 72 1c f0 00 	cmpl   $0x0,0xf01c7238
f0100b6e:	75 36                	jne    f0100ba6 <boot_alloc+0x46>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100b70:	ba 03 a0 20 f0       	mov    $0xf020a003,%edx
f0100b75:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0100b7b:	89 15 38 72 1c f0    	mov    %edx,0xf01c7238
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f0100b81:	85 c0                	test   %eax,%eax
f0100b83:	74 19                	je     f0100b9e <boot_alloc+0x3e>
                      result = nextfree;
f0100b85:	8b 1d 38 72 1c f0    	mov    0xf01c7238,%ebx
                      nextfree += ROUNDUP(n, PGSIZE);
f0100b8b:	05 ff 0f 00 00       	add    $0xfff,%eax
f0100b90:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100b95:	01 d8                	add    %ebx,%eax
f0100b97:	a3 38 72 1c f0       	mov    %eax,0xf01c7238
f0100b9c:	eb 0e                	jmp    f0100bac <boot_alloc+0x4c>
               } else if (n == 0)
                      result = nextfree;
f0100b9e:	8b 1d 38 72 1c f0    	mov    0xf01c7238,%ebx
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
f0100bb7:	e8 ba 32 00 00       	call   f0103e76 <cprintf>
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
f0100bda:	3b 0d 88 7e 1c f0    	cmp    0xf01c7e88,%ecx
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
f0100bec:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
f0100bf3:	f0 
f0100bf4:	c7 44 24 04 9c 03 00 	movl   $0x39c,0x4(%esp)
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
f0100c51:	c7 44 24 04 ce 02 00 	movl   $0x2ce,0x4(%esp)
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
f0100c73:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
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
f0100ca9:	a3 40 72 1c f0       	mov    %eax,0xf01c7240
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
f0100cbb:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
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
f0100cd5:	3b 15 88 7e 1c f0    	cmp    0xf01c7e88,%edx
f0100cdb:	72 20                	jb     f0100cfd <check_page_free_list+0xca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100cdd:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100ce1:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
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
f0100d15:	e8 cf 51 00 00       	call   f0105ee9 <memset>
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
f0100d2d:	8b 15 40 72 1c f0    	mov    0xf01c7240,%edx
f0100d33:	85 d2                	test   %edx,%edx
f0100d35:	0f 84 27 02 00 00    	je     f0100f62 <check_page_free_list+0x32f>
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d3b:	8b 3d 90 7e 1c f0    	mov    0xf01c7e90,%edi
f0100d41:	39 fa                	cmp    %edi,%edx
f0100d43:	72 3f                	jb     f0100d84 <check_page_free_list+0x151>
		assert(pp < pages + npages);
f0100d45:	a1 88 7e 1c f0       	mov    0xf01c7e88,%eax
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
f0100d94:	c7 44 24 04 e8 02 00 	movl   $0x2e8,0x4(%esp)
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
f0100dbd:	c7 44 24 04 e9 02 00 	movl   $0x2e9,0x4(%esp)
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
f0100dea:	c7 44 24 04 ea 02 00 	movl   $0x2ea,0x4(%esp)
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
f0100e18:	c7 44 24 04 ed 02 00 	movl   $0x2ed,0x4(%esp)
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
f0100e43:	c7 44 24 04 ee 02 00 	movl   $0x2ee,0x4(%esp)
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
f0100e7b:	c7 44 24 04 ef 02 00 	movl   $0x2ef,0x4(%esp)
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
f0100ea6:	c7 44 24 04 f0 02 00 	movl   $0x2f0,0x4(%esp)
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
f0100ed5:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
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
f0100f10:	c7 44 24 04 f2 02 00 	movl   $0x2f2,0x4(%esp)
f0100f17:	00 
f0100f18:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0100f1f:	e8 1c f1 ff ff       	call   f0100040 <_panic>
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100f24:	c7 44 24 0c 60 7a 10 	movl   $0xf0107a60,0xc(%esp)
f0100f2b:	f0 
f0100f2c:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0100f33:	f0 
f0100f34:	c7 44 24 04 f4 02 00 	movl   $0x2f4,0x4(%esp)
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
f0100f72:	c7 44 24 04 fb 02 00 	movl   $0x2fb,0x4(%esp)
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
f0100f9a:	c7 44 24 04 fc 02 00 	movl   $0x2fc,0x4(%esp)
f0100fa1:	00 
f0100fa2:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0100fa9:	e8 92 f0 ff ff       	call   f0100040 <_panic>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100fae:	a1 40 72 1c f0       	mov    0xf01c7240,%eax
f0100fb3:	85 c0                	test   %eax,%eax
f0100fb5:	0f 85 aa fc ff ff    	jne    f0100c65 <check_page_free_list+0x32>
f0100fbb:	e9 89 fc ff ff       	jmp    f0100c49 <check_page_free_list+0x16>
f0100fc0:	83 3d 40 72 1c f0 00 	cmpl   $0x0,0xf01c7240
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
f0100fee:	8b 1d 40 72 1c f0    	mov    0xf01c7240,%ebx
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
f010100e:	8b 35 44 72 1c f0    	mov    0xf01c7244,%esi
f0101014:	83 fe 01             	cmp    $0x1,%esi
f0101017:	76 39                	jbe    f0101052 <page_init+0x4c>
f0101019:	8b 1d 40 72 1c f0    	mov    0xf01c7240,%ebx
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
f010102d:	03 0d 90 7e 1c f0    	add    0xf01c7e90,%ecx
f0101033:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0101039:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f010103b:	03 15 90 7e 1c f0    	add    0xf01c7e90,%edx
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
f010104c:	89 15 40 72 1c f0    	mov    %edx,0xf01c7240
	}

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
f0101052:	8b 0d 88 7e 1c f0    	mov    0xf01c7e88,%ecx
f0101058:	a1 90 7e 1c f0       	mov    0xf01c7e90,%eax
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
f010107d:	8b 1d 40 72 1c f0    	mov    0xf01c7240,%ebx
f0101083:	c1 e0 03             	shl    $0x3,%eax
		pages[i].pp_ref = 0;
f0101086:	89 c1                	mov    %eax,%ecx
f0101088:	03 0d 90 7e 1c f0    	add    0xf01c7e90,%ecx
f010108e:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0101094:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f0101096:	89 c3                	mov    %eax,%ebx
f0101098:	03 1d 90 7e 1c f0    	add    0xf01c7e90,%ebx

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f010109e:	83 c2 01             	add    $0x1,%edx
f01010a1:	8b 0d 88 7e 1c f0    	mov    0xf01c7e88,%ecx
f01010a7:	83 c0 08             	add    $0x8,%eax
f01010aa:	39 d1                	cmp    %edx,%ecx
f01010ac:	77 d8                	ja     f0101086 <page_init+0x80>
f01010ae:	89 1d 40 72 1c f0    	mov    %ebx,0xf01c7240
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
f01010d5:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
               ppg_end->pp_link = ppg_start;*/

               //remain the page of mp entry Code
               extern unsigned char mpentry_start[], mpentry_end[];
               struct Page *ppg_start = pa2page((physaddr_t)MPENTRY_PADDR);      
               struct Page * ppg_end = pa2page((physaddr_t)(MPENTRY_PADDR+mpentry_end - mpentry_start));  
f01010db:	b8 96 d1 10 f0       	mov    $0xf010d196,%eax
f01010e0:	2d 1c 61 10 f0       	sub    $0xf010611c,%eax
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
f010111d:	8b 1d 40 72 1c f0    	mov    0xf01c7240,%ebx
f0101123:	85 db                	test   %ebx,%ebx
f0101125:	74 69                	je     f0101190 <page_alloc+0x7a>
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
f0101127:	8b 03                	mov    (%ebx),%eax
f0101129:	a3 40 72 1c f0       	mov    %eax,0xf01c7240
    
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
f0101136:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f010113c:	c1 f8 03             	sar    $0x3,%eax
f010113f:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101142:	89 c2                	mov    %eax,%edx
f0101144:	c1 ea 0c             	shr    $0xc,%edx
f0101147:	3b 15 88 7e 1c f0    	cmp    0xf01c7e88,%edx
f010114d:	72 20                	jb     f010116f <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010114f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101153:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
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
f0101187:	e8 5d 4d 00 00       	call   f0105ee9 <memset>
        
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
f01011a1:	8b 15 40 72 1c f0    	mov    0xf01c7240,%edx
f01011a7:	89 10                	mov    %edx,(%eax)
              page_free_list = pp;
f01011a9:	a3 40 72 1c f0       	mov    %eax,0xf01c7240
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
f0101214:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f010121a:	c1 fa 03             	sar    $0x3,%edx
f010121d:	c1 e2 0c             	shl    $0xc,%edx
                                                  pgdir[PDX(va)] = page2pa(tmp) | PTE_P | PTE_W |PTE_U;    //save the physical address of newly allocated page in page dir
f0101220:	83 ca 07             	or     $0x7,%edx
f0101223:	89 16                	mov    %edx,(%esi)
f0101225:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f010122b:	c1 f8 03             	sar    $0x3,%eax
f010122e:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101231:	89 c2                	mov    %eax,%edx
f0101233:	c1 ea 0c             	shr    $0xc,%edx
f0101236:	3b 15 88 7e 1c f0    	cmp    0xf01c7e88,%edx
f010123c:	72 20                	jb     f010125e <pgdir_walk+0x8b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010123e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101242:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
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
f0101268:	8b 15 88 7e 1c f0    	mov    0xf01c7e88,%edx
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
f010129b:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
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
f0101398:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f010139e:	72 1c                	jb     f01013bc <page_lookup+0x57>
		panic("pa2page called with invalid pa");
f01013a0:	c7 44 24 08 94 73 10 	movl   $0xf0107394,0x8(%esp)
f01013a7:	f0 
f01013a8:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01013af:	00 
f01013b0:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f01013b7:	e8 84 ec ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f01013bc:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
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
f01013d8:	e8 a6 51 00 00       	call   f0106583 <cpunum>
f01013dd:	6b c0 74             	imul   $0x74,%eax,%eax
f01013e0:	83 b8 28 80 1c f0 00 	cmpl   $0x0,-0xfe37fd8(%eax)
f01013e7:	74 16                	je     f01013ff <tlb_invalidate+0x2d>
f01013e9:	e8 95 51 00 00       	call   f0106583 <cpunum>
f01013ee:	6b c0 74             	imul   $0x74,%eax,%eax
f01013f1:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
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
f0101499:	2b 3d 90 7e 1c f0    	sub    0xf01c7e90,%edi
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
f01014e8:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
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
f0101521:	e8 e4 27 00 00       	call   f0103d0a <mc146818_read>
f0101526:	89 c3                	mov    %eax,%ebx
f0101528:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f010152f:	e8 d6 27 00 00       	call   f0103d0a <mc146818_read>
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
f010154c:	a3 44 72 1c f0       	mov    %eax,0xf01c7244
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0101551:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f0101558:	e8 ad 27 00 00       	call   f0103d0a <mc146818_read>
f010155d:	89 c3                	mov    %eax,%ebx
f010155f:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f0101566:	e8 9f 27 00 00       	call   f0103d0a <mc146818_read>
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
f010158d:	89 15 88 7e 1c f0    	mov    %edx,0xf01c7e88
f0101593:	eb 0c                	jmp    f01015a1 <mem_init+0x90>
	else
		npages = npages_basemem;
f0101595:	8b 15 44 72 1c f0    	mov    0xf01c7244,%edx
f010159b:	89 15 88 7e 1c f0    	mov    %edx,0xf01c7e88

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
f01015ab:	a1 44 72 1c f0       	mov    0xf01c7244,%eax
f01015b0:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f01015b3:	c1 e8 0a             	shr    $0xa,%eax
f01015b6:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f01015ba:	a1 88 7e 1c f0       	mov    0xf01c7e88,%eax
f01015bf:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f01015c2:	c1 e8 0a             	shr    $0xa,%eax
f01015c5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01015c9:	c7 04 24 b4 73 10 f0 	movl   $0xf01073b4,(%esp)
f01015d0:	e8 a1 28 00 00       	call   f0103e76 <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);  // first_level pagedir
f01015d5:	b8 00 10 00 00       	mov    $0x1000,%eax
f01015da:	e8 81 f5 ff ff       	call   f0100b60 <boot_alloc>
f01015df:	a3 8c 7e 1c f0       	mov    %eax,0xf01c7e8c
	memset(kern_pgdir, 0, PGSIZE);
f01015e4:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01015eb:	00 
f01015ec:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01015f3:	00 
f01015f4:	89 04 24             	mov    %eax,(%esp)
f01015f7:	e8 ed 48 00 00       	call   f0105ee9 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f01015fc:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101601:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101606:	77 20                	ja     f0101628 <mem_init+0x117>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101608:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010160c:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
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
f0101637:	a1 88 7e 1c f0       	mov    0xf01c7e88,%eax
f010163c:	c1 e0 03             	shl    $0x3,%eax
f010163f:	e8 1c f5 ff ff       	call   f0100b60 <boot_alloc>
f0101644:	a3 90 7e 1c f0       	mov    %eax,0xf01c7e90


	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.
	envs =  (struct Env *)boot_alloc(NENV * sizeof(struct Env));
f0101649:	b8 00 f0 01 00       	mov    $0x1f000,%eax
f010164e:	e8 0d f5 ff ff       	call   f0100b60 <boot_alloc>
f0101653:	a3 48 72 1c f0       	mov    %eax,0xf01c7248
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
f0101667:	83 3d 90 7e 1c f0 00 	cmpl   $0x0,0xf01c7e90
f010166e:	75 1c                	jne    f010168c <mem_init+0x17b>
		panic("'pages' is a null pointer!");
f0101670:	c7 44 24 08 ba 7a 10 	movl   $0xf0107aba,0x8(%esp)
f0101677:	f0 
f0101678:	c7 44 24 04 0d 03 00 	movl   $0x30d,0x4(%esp)
f010167f:	00 
f0101680:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101687:	e8 b4 e9 ff ff       	call   f0100040 <_panic>

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010168c:	a1 40 72 1c f0       	mov    0xf01c7240,%eax
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
f01016cc:	c7 44 24 04 15 03 00 	movl   $0x315,0x4(%esp)
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
f0101702:	c7 44 24 04 16 03 00 	movl   $0x316,0x4(%esp)
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
f0101739:	c7 44 24 04 17 03 00 	movl   $0x317,0x4(%esp)
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
f0101761:	c7 44 24 04 1a 03 00 	movl   $0x31a,0x4(%esp)
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
f0101790:	c7 44 24 04 1b 03 00 	movl   $0x31b,0x4(%esp)
f0101797:	00 
f0101798:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010179f:	e8 9c e8 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01017a4:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f01017aa:	a1 88 7e 1c f0       	mov    0xf01c7e88,%eax
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
f01017d0:	c7 44 24 04 1c 03 00 	movl   $0x31c,0x4(%esp)
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
f0101802:	c7 44 24 04 1d 03 00 	movl   $0x31d,0x4(%esp)
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
f0101837:	c7 44 24 04 1e 03 00 	movl   $0x31e,0x4(%esp)
f010183e:	00 
f010183f:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101846:	e8 f5 e7 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f010184b:	a1 40 72 1c f0       	mov    0xf01c7240,%eax
f0101850:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101853:	c7 05 40 72 1c f0 00 	movl   $0x0,0xf01c7240
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
f010187d:	c7 44 24 04 25 03 00 	movl   $0x325,0x4(%esp)
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
f01018ce:	c7 44 24 04 2c 03 00 	movl   $0x32c,0x4(%esp)
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
f0101904:	c7 44 24 04 2d 03 00 	movl   $0x32d,0x4(%esp)
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
f010193b:	c7 44 24 04 2e 03 00 	movl   $0x32e,0x4(%esp)
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
f0101963:	c7 44 24 04 30 03 00 	movl   $0x330,0x4(%esp)
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
f0101992:	c7 44 24 04 31 03 00 	movl   $0x331,0x4(%esp)
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
f01019c6:	c7 44 24 04 32 03 00 	movl   $0x332,0x4(%esp)
f01019cd:	00 
f01019ce:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01019d5:	e8 66 e6 ff ff       	call   f0100040 <_panic>
f01019da:	89 f0                	mov    %esi,%eax
f01019dc:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f01019e2:	c1 f8 03             	sar    $0x3,%eax
f01019e5:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01019e8:	89 c2                	mov    %eax,%edx
f01019ea:	c1 ea 0c             	shr    $0xc,%edx
f01019ed:	3b 15 88 7e 1c f0    	cmp    0xf01c7e88,%edx
f01019f3:	72 20                	jb     f0101a15 <mem_init+0x504>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01019f5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01019f9:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
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
f0101a2d:	e8 b7 44 00 00       	call   f0105ee9 <memset>
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
f0101a5a:	c7 44 24 04 37 03 00 	movl   $0x337,0x4(%esp)
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
f0101a82:	c7 44 24 04 38 03 00 	movl   $0x338,0x4(%esp)
f0101a89:	00 
f0101a8a:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101a91:	e8 aa e5 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101a96:	89 f2                	mov    %esi,%edx
f0101a98:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f0101a9e:	c1 fa 03             	sar    $0x3,%edx
f0101aa1:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101aa4:	89 d0                	mov    %edx,%eax
f0101aa6:	c1 e8 0c             	shr    $0xc,%eax
f0101aa9:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f0101aaf:	72 20                	jb     f0101ad1 <mem_init+0x5c0>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101ab1:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101ab5:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
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
f0101afb:	c7 44 24 04 3b 03 00 	movl   $0x33b,0x4(%esp)
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
f0101b19:	a3 40 72 1c f0       	mov    %eax,0xf01c7240

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
f0101b39:	a1 40 72 1c f0       	mov    0xf01c7240,%eax
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
f0101b5f:	c7 44 24 04 48 03 00 	movl   $0x348,0x4(%esp)
f0101b66:	00 
f0101b67:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101b6e:	e8 cd e4 ff ff       	call   f0100040 <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f0101b73:	c7 04 24 10 74 10 f0 	movl   $0xf0107410,(%esp)
f0101b7a:	e8 f7 22 00 00       	call   f0103e76 <cprintf>
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
f0101ba1:	c7 44 24 04 b0 03 00 	movl   $0x3b0,0x4(%esp)
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
f0101bd8:	c7 44 24 04 b1 03 00 	movl   $0x3b1,0x4(%esp)
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
f0101c0e:	c7 44 24 04 b2 03 00 	movl   $0x3b2,0x4(%esp)
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
f0101c37:	c7 44 24 04 b5 03 00 	movl   $0x3b5,0x4(%esp)
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
f0101c64:	c7 44 24 04 b6 03 00 	movl   $0x3b6,0x4(%esp)
f0101c6b:	00 
f0101c6c:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101c73:	e8 c8 e3 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101c78:	a1 40 72 1c f0       	mov    0xf01c7240,%eax
f0101c7d:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101c80:	c7 05 40 72 1c f0 00 	movl   $0x0,0xf01c7240
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
f0101caa:	c7 44 24 04 bd 03 00 	movl   $0x3bd,0x4(%esp)
f0101cb1:	00 
f0101cb2:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101cb9:	e8 82 e3 ff ff       	call   f0100040 <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f0101cbe:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101cc1:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101cc5:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101ccc:	00 
f0101ccd:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0101cd2:	89 04 24             	mov    %eax,(%esp)
f0101cd5:	e8 8b f6 ff ff       	call   f0101365 <page_lookup>
f0101cda:	85 c0                	test   %eax,%eax
f0101cdc:	74 24                	je     f0101d02 <mem_init+0x7f1>
f0101cde:	c7 44 24 0c 30 74 10 	movl   $0xf0107430,0xc(%esp)
f0101ce5:	f0 
f0101ce6:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101ced:	f0 
f0101cee:	c7 44 24 04 c0 03 00 	movl   $0x3c0,0x4(%esp)
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
f0101d19:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0101d1e:	89 04 24             	mov    %eax,(%esp)
f0101d21:	e8 2a f7 ff ff       	call   f0101450 <page_insert>
f0101d26:	85 c0                	test   %eax,%eax
f0101d28:	78 24                	js     f0101d4e <mem_init+0x83d>
f0101d2a:	c7 44 24 0c 68 74 10 	movl   $0xf0107468,0xc(%esp)
f0101d31:	f0 
f0101d32:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101d39:	f0 
f0101d3a:	c7 44 24 04 c3 03 00 	movl   $0x3c3,0x4(%esp)
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
f0101d6d:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0101d72:	89 04 24             	mov    %eax,(%esp)
f0101d75:	e8 d6 f6 ff ff       	call   f0101450 <page_insert>
f0101d7a:	85 c0                	test   %eax,%eax
f0101d7c:	74 24                	je     f0101da2 <mem_init+0x891>
f0101d7e:	c7 44 24 0c 98 74 10 	movl   $0xf0107498,0xc(%esp)
f0101d85:	f0 
f0101d86:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101d8d:	f0 
f0101d8e:	c7 44 24 04 c7 03 00 	movl   $0x3c7,0x4(%esp)
f0101d95:	00 
f0101d96:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101d9d:	e8 9e e2 ff ff       	call   f0100040 <_panic>
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101da2:	8b 35 8c 7e 1c f0    	mov    0xf01c7e8c,%esi
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101da8:	a1 90 7e 1c f0       	mov    0xf01c7e90,%eax
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
f0101dd8:	c7 44 24 04 c8 03 00 	movl   $0x3c8,0x4(%esp)
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
f0101e18:	c7 44 24 04 c9 03 00 	movl   $0x3c9,0x4(%esp)
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
f0101e46:	c7 44 24 04 ca 03 00 	movl   $0x3ca,0x4(%esp)
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
f0101e71:	c7 44 24 04 cb 03 00 	movl   $0x3cb,0x4(%esp)
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
f0101eb5:	c7 44 24 04 ce 03 00 	movl   $0x3ce,0x4(%esp)
f0101ebc:	00 
f0101ebd:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101ec4:	e8 77 e1 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101ec9:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101ece:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0101ed3:	e8 ec ec ff ff       	call   f0100bc4 <check_va2pa>
f0101ed8:	89 fa                	mov    %edi,%edx
f0101eda:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f0101ee0:	c1 fa 03             	sar    $0x3,%edx
f0101ee3:	c1 e2 0c             	shl    $0xc,%edx
f0101ee6:	39 d0                	cmp    %edx,%eax
f0101ee8:	74 24                	je     f0101f0e <mem_init+0x9fd>
f0101eea:	c7 44 24 0c 5c 75 10 	movl   $0xf010755c,0xc(%esp)
f0101ef1:	f0 
f0101ef2:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101ef9:	f0 
f0101efa:	c7 44 24 04 cf 03 00 	movl   $0x3cf,0x4(%esp)
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
f0101f25:	c7 44 24 04 d0 03 00 	movl   $0x3d0,0x4(%esp)
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
f0101f59:	c7 44 24 04 d3 03 00 	movl   $0x3d3,0x4(%esp)
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
f0101f81:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0101f86:	89 04 24             	mov    %eax,(%esp)
f0101f89:	e8 c2 f4 ff ff       	call   f0101450 <page_insert>
f0101f8e:	85 c0                	test   %eax,%eax
f0101f90:	74 24                	je     f0101fb6 <mem_init+0xaa5>
f0101f92:	c7 44 24 0c 20 75 10 	movl   $0xf0107520,0xc(%esp)
f0101f99:	f0 
f0101f9a:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101fa1:	f0 
f0101fa2:	c7 44 24 04 d6 03 00 	movl   $0x3d6,0x4(%esp)
f0101fa9:	00 
f0101faa:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0101fb1:	e8 8a e0 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101fb6:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101fbb:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0101fc0:	e8 ff eb ff ff       	call   f0100bc4 <check_va2pa>
f0101fc5:	89 fa                	mov    %edi,%edx
f0101fc7:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f0101fcd:	c1 fa 03             	sar    $0x3,%edx
f0101fd0:	c1 e2 0c             	shl    $0xc,%edx
f0101fd3:	39 d0                	cmp    %edx,%eax
f0101fd5:	74 24                	je     f0101ffb <mem_init+0xaea>
f0101fd7:	c7 44 24 0c 5c 75 10 	movl   $0xf010755c,0xc(%esp)
f0101fde:	f0 
f0101fdf:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0101fe6:	f0 
f0101fe7:	c7 44 24 04 d7 03 00 	movl   $0x3d7,0x4(%esp)
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
f0102012:	c7 44 24 04 d8 03 00 	movl   $0x3d8,0x4(%esp)
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
f0102046:	c7 44 24 04 dc 03 00 	movl   $0x3dc,0x4(%esp)
f010204d:	00 
f010204e:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102055:	e8 e6 df ff ff       	call   f0100040 <_panic>

	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f010205a:	8b 15 8c 7e 1c f0    	mov    0xf01c7e8c,%edx
f0102060:	8b 02                	mov    (%edx),%eax
f0102062:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102067:	89 c1                	mov    %eax,%ecx
f0102069:	c1 e9 0c             	shr    $0xc,%ecx
f010206c:	3b 0d 88 7e 1c f0    	cmp    0xf01c7e88,%ecx
f0102072:	72 20                	jb     f0102094 <mem_init+0xb83>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102074:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102078:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
f010207f:	f0 
f0102080:	c7 44 24 04 df 03 00 	movl   $0x3df,0x4(%esp)
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
f01020ce:	c7 44 24 04 e0 03 00 	movl   $0x3e0,0x4(%esp)
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
f01020f6:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01020fb:	89 04 24             	mov    %eax,(%esp)
f01020fe:	e8 4d f3 ff ff       	call   f0101450 <page_insert>
f0102103:	85 c0                	test   %eax,%eax
f0102105:	74 24                	je     f010212b <mem_init+0xc1a>
f0102107:	c7 44 24 0c cc 75 10 	movl   $0xf01075cc,0xc(%esp)
f010210e:	f0 
f010210f:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102116:	f0 
f0102117:	c7 44 24 04 e3 03 00 	movl   $0x3e3,0x4(%esp)
f010211e:	00 
f010211f:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102126:	e8 15 df ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f010212b:	8b 35 8c 7e 1c f0    	mov    0xf01c7e8c,%esi
f0102131:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102136:	89 f0                	mov    %esi,%eax
f0102138:	e8 87 ea ff ff       	call   f0100bc4 <check_va2pa>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010213d:	89 fa                	mov    %edi,%edx
f010213f:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f0102145:	c1 fa 03             	sar    $0x3,%edx
f0102148:	c1 e2 0c             	shl    $0xc,%edx
f010214b:	39 d0                	cmp    %edx,%eax
f010214d:	74 24                	je     f0102173 <mem_init+0xc62>
f010214f:	c7 44 24 0c 5c 75 10 	movl   $0xf010755c,0xc(%esp)
f0102156:	f0 
f0102157:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010215e:	f0 
f010215f:	c7 44 24 04 e4 03 00 	movl   $0x3e4,0x4(%esp)
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
f010218a:	c7 44 24 04 e5 03 00 	movl   $0x3e5,0x4(%esp)
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
f01021cb:	c7 44 24 04 e6 03 00 	movl   $0x3e6,0x4(%esp)
f01021d2:	00 
f01021d3:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01021da:	e8 61 de ff ff       	call   f0100040 <_panic>
	assert(kern_pgdir[0] & PTE_U);
f01021df:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01021e4:	f6 00 04             	testb  $0x4,(%eax)
f01021e7:	75 24                	jne    f010220d <mem_init+0xcfc>
f01021e9:	c7 44 24 0c 05 7c 10 	movl   $0xf0107c05,0xc(%esp)
f01021f0:	f0 
f01021f1:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01021f8:	f0 
f01021f9:	c7 44 24 04 e7 03 00 	movl   $0x3e7,0x4(%esp)
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
f010223d:	c7 44 24 04 ea 03 00 	movl   $0x3ea,0x4(%esp)
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
f0102268:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f010226d:	89 04 24             	mov    %eax,(%esp)
f0102270:	e8 db f1 ff ff       	call   f0101450 <page_insert>
f0102275:	85 c0                	test   %eax,%eax
f0102277:	74 24                	je     f010229d <mem_init+0xd8c>
f0102279:	c7 44 24 0c 78 76 10 	movl   $0xf0107678,0xc(%esp)
f0102280:	f0 
f0102281:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102288:	f0 
f0102289:	c7 44 24 04 ed 03 00 	movl   $0x3ed,0x4(%esp)
f0102290:	00 
f0102291:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102298:	e8 a3 dd ff ff       	call   f0100040 <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f010229d:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01022a4:	00 
f01022a5:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01022ac:	00 
f01022ad:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01022b2:	89 04 24             	mov    %eax,(%esp)
f01022b5:	e8 19 ef ff ff       	call   f01011d3 <pgdir_walk>
f01022ba:	f6 00 04             	testb  $0x4,(%eax)
f01022bd:	74 24                	je     f01022e3 <mem_init+0xdd2>
f01022bf:	c7 44 24 0c b4 76 10 	movl   $0xf01076b4,0xc(%esp)
f01022c6:	f0 
f01022c7:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01022ce:	f0 
f01022cf:	c7 44 24 04 ee 03 00 	movl   $0x3ee,0x4(%esp)
f01022d6:	00 
f01022d7:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01022de:	e8 5d dd ff ff       	call   f0100040 <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f01022e3:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01022e8:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01022eb:	ba 00 00 00 00       	mov    $0x0,%edx
f01022f0:	e8 cf e8 ff ff       	call   f0100bc4 <check_va2pa>
f01022f5:	89 c6                	mov    %eax,%esi
f01022f7:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01022fa:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f0102300:	c1 f8 03             	sar    $0x3,%eax
f0102303:	c1 e0 0c             	shl    $0xc,%eax
f0102306:	39 c6                	cmp    %eax,%esi
f0102308:	74 24                	je     f010232e <mem_init+0xe1d>
f010230a:	c7 44 24 0c ec 76 10 	movl   $0xf01076ec,0xc(%esp)
f0102311:	f0 
f0102312:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102319:	f0 
f010231a:	c7 44 24 04 f1 03 00 	movl   $0x3f1,0x4(%esp)
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
f010234f:	c7 44 24 04 f2 03 00 	movl   $0x3f2,0x4(%esp)
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
f010237d:	c7 44 24 04 f4 03 00 	movl   $0x3f4,0x4(%esp)
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
f01023a8:	c7 44 24 04 f5 03 00 	movl   $0x3f5,0x4(%esp)
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
f01023e0:	c7 44 24 04 f8 03 00 	movl   $0x3f8,0x4(%esp)
f01023e7:	00 
f01023e8:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01023ef:	e8 4c dc ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f01023f4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01023fb:	00 
f01023fc:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0102401:	89 04 24             	mov    %eax,(%esp)
f0102404:	e8 fe ef ff ff       	call   f0101407 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f0102409:	8b 35 8c 7e 1c f0    	mov    0xf01c7e8c,%esi
f010240f:	ba 00 00 00 00       	mov    $0x0,%edx
f0102414:	89 f0                	mov    %esi,%eax
f0102416:	e8 a9 e7 ff ff       	call   f0100bc4 <check_va2pa>
f010241b:	83 f8 ff             	cmp    $0xffffffff,%eax
f010241e:	74 24                	je     f0102444 <mem_init+0xf33>
f0102420:	c7 44 24 0c 6c 77 10 	movl   $0xf010776c,0xc(%esp)
f0102427:	f0 
f0102428:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010242f:	f0 
f0102430:	c7 44 24 04 fc 03 00 	movl   $0x3fc,0x4(%esp)
f0102437:	00 
f0102438:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010243f:	e8 fc db ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102444:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102449:	89 f0                	mov    %esi,%eax
f010244b:	e8 74 e7 ff ff       	call   f0100bc4 <check_va2pa>
f0102450:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0102453:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f0102459:	c1 fa 03             	sar    $0x3,%edx
f010245c:	c1 e2 0c             	shl    $0xc,%edx
f010245f:	39 d0                	cmp    %edx,%eax
f0102461:	74 24                	je     f0102487 <mem_init+0xf76>
f0102463:	c7 44 24 0c 18 77 10 	movl   $0xf0107718,0xc(%esp)
f010246a:	f0 
f010246b:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102472:	f0 
f0102473:	c7 44 24 04 fd 03 00 	movl   $0x3fd,0x4(%esp)
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
f01024a1:	c7 44 24 04 fe 03 00 	movl   $0x3fe,0x4(%esp)
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
f01024cc:	c7 44 24 04 ff 03 00 	movl   $0x3ff,0x4(%esp)
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
f01024f0:	8b 35 8c 7e 1c f0    	mov    0xf01c7e8c,%esi
f01024f6:	ba 00 00 00 00       	mov    $0x0,%edx
f01024fb:	89 f0                	mov    %esi,%eax
f01024fd:	e8 c2 e6 ff ff       	call   f0100bc4 <check_va2pa>
f0102502:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102505:	74 24                	je     f010252b <mem_init+0x101a>
f0102507:	c7 44 24 0c 6c 77 10 	movl   $0xf010776c,0xc(%esp)
f010250e:	f0 
f010250f:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102516:	f0 
f0102517:	c7 44 24 04 03 04 00 	movl   $0x403,0x4(%esp)
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
f010254c:	c7 44 24 04 04 04 00 	movl   $0x404,0x4(%esp)
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
f010257a:	c7 44 24 04 05 04 00 	movl   $0x405,0x4(%esp)
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
f01025a5:	c7 44 24 04 06 04 00 	movl   $0x406,0x4(%esp)
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
f01025de:	c7 44 24 04 09 04 00 	movl   $0x409,0x4(%esp)
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
f0102612:	c7 44 24 04 0c 04 00 	movl   $0x40c,0x4(%esp)
f0102619:	00 
f010261a:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f0102621:	e8 1a da ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102626:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f010262b:	8b 08                	mov    (%eax),%ecx
f010262d:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f0102633:	89 da                	mov    %ebx,%edx
f0102635:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f010263b:	c1 fa 03             	sar    $0x3,%edx
f010263e:	c1 e2 0c             	shl    $0xc,%edx
f0102641:	39 d1                	cmp    %edx,%ecx
f0102643:	74 24                	je     f0102669 <mem_init+0x1158>
f0102645:	c7 44 24 0c c8 74 10 	movl   $0xf01074c8,0xc(%esp)
f010264c:	f0 
f010264d:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0102654:	f0 
f0102655:	c7 44 24 04 0f 04 00 	movl   $0x40f,0x4(%esp)
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
f0102686:	c7 44 24 04 11 04 00 	movl   $0x411,0x4(%esp)
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
f01026b8:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01026bd:	89 04 24             	mov    %eax,(%esp)
f01026c0:	e8 0e eb ff ff       	call   f01011d3 <pgdir_walk>
f01026c5:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01026c8:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f01026cb:	8b 0d 8c 7e 1c f0    	mov    0xf01c7e8c,%ecx
f01026d1:	8b 51 04             	mov    0x4(%ecx),%edx
f01026d4:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01026da:	8b 35 88 7e 1c f0    	mov    0xf01c7e88,%esi
f01026e0:	89 d0                	mov    %edx,%eax
f01026e2:	c1 e8 0c             	shr    $0xc,%eax
f01026e5:	39 f0                	cmp    %esi,%eax
f01026e7:	72 20                	jb     f0102709 <mem_init+0x11f8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01026e9:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01026ed:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
f01026f4:	f0 
f01026f5:	c7 44 24 04 18 04 00 	movl   $0x418,0x4(%esp)
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
f0102724:	c7 44 24 04 19 04 00 	movl   $0x419,0x4(%esp)
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
f0102747:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
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
f0102760:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
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
f0102794:	e8 50 37 00 00       	call   f0105ee9 <memset>
	page_free(pp0);
f0102799:	89 1c 24             	mov    %ebx,(%esp)
f010279c:	e8 fa e9 ff ff       	call   f010119b <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f01027a1:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01027a8:	00 
f01027a9:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01027b0:	00 
f01027b1:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01027b6:	89 04 24             	mov    %eax,(%esp)
f01027b9:	e8 15 ea ff ff       	call   f01011d3 <pgdir_walk>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01027be:	89 da                	mov    %ebx,%edx
f01027c0:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f01027c6:	c1 fa 03             	sar    $0x3,%edx
f01027c9:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01027cc:	89 d0                	mov    %edx,%eax
f01027ce:	c1 e8 0c             	shr    $0xc,%eax
f01027d1:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f01027d7:	72 20                	jb     f01027f9 <mem_init+0x12e8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01027d9:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01027dd:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
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
f010282e:	c7 44 24 04 23 04 00 	movl   $0x423,0x4(%esp)
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
f0102849:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f010284e:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f0102854:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// give free list back
	page_free_list = fl;
f010285a:	8b 45 d0             	mov    -0x30(%ebp),%eax
f010285d:	a3 40 72 1c f0       	mov    %eax,0xf01c7240

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
f0102884:	e8 ed 15 00 00       	call   f0103e76 <cprintf>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t to_map_pages;
	to_map_pages = (sizeof(struct Page) * npages - 1) / PGSIZE + 1;
f0102889:	a1 88 7e 1c f0       	mov    0xf01c7e88,%eax
f010288e:	8d 0c c5 ff ff ff ff 	lea    -0x1(,%eax,8),%ecx
f0102895:	c1 e9 0c             	shr    $0xc,%ecx
f0102898:	83 c1 01             	add    $0x1,%ecx
	boot_map_region(kern_pgdir, UPAGES, to_map_pages * PGSIZE, PADDR(pages), PTE_U | PTE_P);
f010289b:	a1 90 7e 1c f0       	mov    0xf01c7e90,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01028a0:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01028a5:	77 20                	ja     f01028c7 <mem_init+0x13b6>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01028a7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01028ab:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
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
f01028df:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01028e4:	e8 f4 e9 ff ff       	call   f01012dd <boot_map_region>
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	size_t i;
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		page_insert(kern_pgdir,pa2page(PADDR(envs)+i),(void *)(UENVS + i),PTE_U| PTE_P);
f01028e9:	a1 48 72 1c f0       	mov    0xf01c7248,%eax
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
f01028fd:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f0102903:	0f 82 ec 0a 00 00    	jb     f01033f5 <mem_init+0x1ee4>
f0102909:	eb 44                	jmp    f010294f <mem_init+0x143e>
f010290b:	8d 93 00 00 c0 ee    	lea    -0x11400000(%ebx),%edx
f0102911:	a1 48 72 1c f0       	mov    0xf01c7248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102916:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010291b:	77 20                	ja     f010293d <mem_init+0x142c>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010291d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102921:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
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
f0102947:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
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
f0102977:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
f010297d:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102980:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102984:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
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
f01029b8:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f01029be:	0f 82 f4 09 00 00    	jb     f01033b8 <mem_init+0x1ea7>
f01029c4:	eb 36                	jmp    f01029fc <mem_init+0x14eb>
f01029c6:	8d 14 3b             	lea    (%ebx,%edi,1),%edx
f01029c9:	89 f8                	mov    %edi,%eax
f01029cb:	c1 e8 0c             	shr    $0xc,%eax
f01029ce:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f01029d4:	72 42                	jb     f0102a18 <mem_init+0x1507>
f01029d6:	eb 24                	jmp    f01029fc <mem_init+0x14eb>

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01029d8:	c7 44 24 0c 00 70 11 	movl   $0xf0117000,0xc(%esp)
f01029df:	f0 
f01029e0:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
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
f0102a24:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
f0102a2a:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102a2d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102a31:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
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
f0102a5b:	8b 1d 88 7e 1c f0    	mov    0xf01c7e88,%ebx
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
f0102aa0:	a1 90 7e 1c f0       	mov    0xf01c7e90,%eax
f0102aa5:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f0102aa8:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102aac:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0102ab1:	89 04 24             	mov    %eax,(%esp)
f0102ab4:	e8 97 e9 ff ff       	call   f0101450 <page_insert>
		pa2page(i % (npages*PGSIZE))->pp_ref--;                 //this statement is to keep pp_ref == 0 in page_free_list
f0102ab9:	8b 0d 88 7e 1c f0    	mov    0xf01c7e88,%ecx
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
f0102af0:	a1 90 7e 1c f0       	mov    0xf01c7e90,%eax
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
f0102b26:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0102b2b:	e8 ad e7 ff ff       	call   f01012dd <boot_map_region>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102b30:	b8 00 90 1c f0       	mov    $0xf01c9000,%eax
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
f0102b4e:	b8 00 90 1c f0       	mov    $0xf01c9000,%eax
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102b53:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102b57:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
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
f0102b8b:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
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
f0102ba5:	8b 3d 8c 7e 1c f0    	mov    0xf01c7e8c,%edi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
f0102bab:	a1 88 7e 1c f0       	mov    0xf01c7e88,%eax
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
f0102bc4:	8b 1d 48 72 1c f0    	mov    0xf01c7248,%ebx
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
f0102bf4:	8b 1d 90 7e 1c f0    	mov    0xf01c7e90,%ebx
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
f0102c18:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
f0102c1f:	f0 
f0102c20:	c7 44 24 04 60 03 00 	movl   $0x360,0x4(%esp)
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
f0102c50:	c7 44 24 04 60 03 00 	movl   $0x360,0x4(%esp)
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
f0102c7c:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
f0102c83:	f0 
f0102c84:	c7 44 24 04 65 03 00 	movl   $0x365,0x4(%esp)
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
f0102caf:	c7 44 24 04 65 03 00 	movl   $0x365,0x4(%esp)
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
f0102d0c:	c7 44 24 04 69 03 00 	movl   $0x369,0x4(%esp)
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
f0102d49:	c7 44 24 04 6d 03 00 	movl   $0x36d,0x4(%esp)
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
f0102d6b:	c7 45 d0 00 90 1c f0 	movl   $0xf01c9000,-0x30(%ebp)
f0102d72:	c7 45 cc 00 00 00 00 	movl   $0x0,-0x34(%ebp)
f0102d79:	be 00 80 bf ef       	mov    $0xefbf8000,%esi
f0102d7e:	b8 00 90 1c f0       	mov    $0xf01c9000,%eax
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
f0102dac:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
f0102db3:	f0 
f0102db4:	c7 44 24 04 75 03 00 	movl   $0x375,0x4(%esp)
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
f0102dec:	c7 44 24 04 75 03 00 	movl   $0x375,0x4(%esp)
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
f0102e36:	c7 44 24 04 77 03 00 	movl   $0x377,0x4(%esp)
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
f0102e9e:	c7 44 24 04 81 03 00 	movl   $0x381,0x4(%esp)
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
f0102ed1:	c7 44 24 04 85 03 00 	movl   $0x385,0x4(%esp)
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
f0102efa:	c7 44 24 04 86 03 00 	movl   $0x386,0x4(%esp)
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
f0102f24:	c7 44 24 04 88 03 00 	movl   $0x388,0x4(%esp)
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
f0102f4d:	e8 24 0f 00 00       	call   f0103e76 <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f0102f52:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0102f57:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102f5c:	77 20                	ja     f0102f7e <mem_init+0x1a6d>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102f5e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102f62:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
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
f0102fc0:	c7 44 24 04 3e 04 00 	movl   $0x43e,0x4(%esp)
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
f0102ff6:	c7 44 24 04 3f 04 00 	movl   $0x43f,0x4(%esp)
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
f010302c:	c7 44 24 04 40 04 00 	movl   $0x440,0x4(%esp)
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
f010304a:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f0103050:	c1 f8 03             	sar    $0x3,%eax
f0103053:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103056:	89 c2                	mov    %eax,%edx
f0103058:	c1 ea 0c             	shr    $0xc,%edx
f010305b:	3b 15 88 7e 1c f0    	cmp    0xf01c7e88,%edx
f0103061:	72 20                	jb     f0103083 <mem_init+0x1b72>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103063:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103067:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
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
f010309b:	e8 49 2e 00 00       	call   f0105ee9 <memset>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01030a0:	89 f0                	mov    %esi,%eax
f01030a2:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f01030a8:	c1 f8 03             	sar    $0x3,%eax
f01030ab:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01030ae:	89 c2                	mov    %eax,%edx
f01030b0:	c1 ea 0c             	shr    $0xc,%edx
f01030b3:	3b 15 88 7e 1c f0    	cmp    0xf01c7e88,%edx
f01030b9:	72 20                	jb     f01030db <mem_init+0x1bca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01030bb:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01030bf:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
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
f01030f3:	e8 f1 2d 00 00       	call   f0105ee9 <memset>
	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f01030f8:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01030ff:	00 
f0103100:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0103107:	00 
f0103108:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010310c:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0103111:	89 04 24             	mov    %eax,(%esp)
f0103114:	e8 37 e3 ff ff       	call   f0101450 <page_insert>
	assert(pp1->pp_ref == 1);
f0103119:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f010311e:	74 24                	je     f0103144 <mem_init+0x1c33>
f0103120:	c7 44 24 0c d2 7b 10 	movl   $0xf0107bd2,0xc(%esp)
f0103127:	f0 
f0103128:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f010312f:	f0 
f0103130:	c7 44 24 04 45 04 00 	movl   $0x445,0x4(%esp)
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
f0103160:	c7 44 24 04 46 04 00 	movl   $0x446,0x4(%esp)
f0103167:	00 
f0103168:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010316f:	e8 cc ce ff ff       	call   f0100040 <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f0103174:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f010317b:	00 
f010317c:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0103183:	00 
f0103184:	89 74 24 04          	mov    %esi,0x4(%esp)
f0103188:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
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
f01031b1:	c7 44 24 04 48 04 00 	movl   $0x448,0x4(%esp)
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
f01031dc:	c7 44 24 04 49 04 00 	movl   $0x449,0x4(%esp)
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
f0103207:	c7 44 24 04 4a 04 00 	movl   $0x44a,0x4(%esp)
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
f0103227:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f010322d:	c1 f8 03             	sar    $0x3,%eax
f0103230:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103233:	89 c2                	mov    %eax,%edx
f0103235:	c1 ea 0c             	shr    $0xc,%edx
f0103238:	3b 15 88 7e 1c f0    	cmp    0xf01c7e88,%edx
f010323e:	72 20                	jb     f0103260 <mem_init+0x1d4f>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103240:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103244:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
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
f010327c:	c7 44 24 04 4c 04 00 	movl   $0x44c,0x4(%esp)
f0103283:	00 
f0103284:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f010328b:	e8 b0 cd ff ff       	call   f0100040 <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f0103290:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0103297:	00 
f0103298:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f010329d:	89 04 24             	mov    %eax,(%esp)
f01032a0:	e8 62 e1 ff ff       	call   f0101407 <page_remove>
	assert(pp2->pp_ref == 0);
f01032a5:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f01032aa:	74 24                	je     f01032d0 <mem_init+0x1dbf>
f01032ac:	c7 44 24 0c 2c 7c 10 	movl   $0xf0107c2c,0xc(%esp)
f01032b3:	f0 
f01032b4:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01032bb:	f0 
f01032bc:	c7 44 24 04 4e 04 00 	movl   $0x44e,0x4(%esp)
f01032c3:	00 
f01032c4:	c7 04 24 cd 79 10 f0 	movl   $0xf01079cd,(%esp)
f01032cb:	e8 70 cd ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f01032d0:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01032d5:	8b 08                	mov    (%eax),%ecx
f01032d7:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01032dd:	89 da                	mov    %ebx,%edx
f01032df:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f01032e5:	c1 fa 03             	sar    $0x3,%edx
f01032e8:	c1 e2 0c             	shl    $0xc,%edx
f01032eb:	39 d1                	cmp    %edx,%ecx
f01032ed:	74 24                	je     f0103313 <mem_init+0x1e02>
f01032ef:	c7 44 24 0c c8 74 10 	movl   $0xf01074c8,0xc(%esp)
f01032f6:	f0 
f01032f7:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f01032fe:	f0 
f01032ff:	c7 44 24 04 51 04 00 	movl   $0x451,0x4(%esp)
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
f0103330:	c7 44 24 04 53 04 00 	movl   $0x453,0x4(%esp)
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
f0103359:	e8 18 0b 00 00       	call   f0103e76 <cprintf>
f010335e:	e9 f6 00 00 00       	jmp    f0103459 <mem_init+0x1f48>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103363:	83 3d 88 7e 1c f0 00 	cmpl   $0x0,0xf01c7e88
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
f0103389:	c7 04 24 00 90 1c 00 	movl   $0x1c9000,(%esp)
f0103390:	b9 00 80 00 00       	mov    $0x8000,%ecx
f0103395:	ba 00 80 bf ef       	mov    $0xefbf8000,%edx
f010339a:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f010339f:	e8 39 df ff ff       	call   f01012dd <boot_map_region>
f01033a4:	bb 00 10 1d f0       	mov    $0xf01d1000,%ebx
f01033a9:	bf 00 90 20 f0       	mov    $0xf0209000,%edi
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
f01033c8:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
f01033ce:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01033d1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01033d5:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
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
f0103405:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
f010340b:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f010340e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103412:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
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
f01034c0:	89 35 3c 72 1c f0    	mov    %esi,0xf01c723c
				break;
f01034c6:	eb 1d                	jmp    f01034e5 <user_mem_check+0x84>
			}
			else
			{
				//cprintf("no pte!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f01034c8:	89 35 3c 72 1c f0    	mov    %esi,0xf01c723c
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
f010352e:	a1 3c 72 1c f0       	mov    0xf01c723c,%eax
f0103533:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103537:	8b 43 48             	mov    0x48(%ebx),%eax
f010353a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010353e:	c7 04 24 98 79 10 f0 	movl   $0xf0107998,(%esp)
f0103545:	e8 2c 09 00 00       	call   f0103e76 <cprintf>
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
f010354a:	89 1c 24             	mov    %ebx,(%esp)
f010354d:	e8 72 06 00 00       	call   f0103bc4 <env_destroy>
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
f0103564:	e8 1a 30 00 00       	call   f0106583 <cpunum>
f0103569:	6b c0 74             	imul   $0x74,%eax,%eax
f010356c:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
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
f0103589:	03 1d 48 72 1c f0    	add    0xf01c7248,%ebx
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
f01035b0:	e8 ce 2f 00 00       	call   f0106583 <cpunum>
f01035b5:	6b c0 74             	imul   $0x74,%eax,%eax
f01035b8:	39 98 28 80 1c f0    	cmp    %ebx,-0xfe37fd8(%eax)
f01035be:	74 26                	je     f01035e6 <envid2env+0x8e>
f01035c0:	8b 73 4c             	mov    0x4c(%ebx),%esi
f01035c3:	e8 bb 2f 00 00       	call   f0106583 <cpunum>
f01035c8:	6b c0 74             	imul   $0x74,%eax,%eax
f01035cb:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
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
f0103623:	8b 35 48 72 1c f0    	mov    0xf01c7248,%esi
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
f0103651:	89 35 4c 72 1c f0    	mov    %esi,0xf01c724c
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
f0103668:	8b 1d 4c 72 1c f0    	mov    0xf01c724c,%ebx
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
f010368c:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f0103692:	c1 fa 03             	sar    $0x3,%edx
f0103695:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103698:	89 d1                	mov    %edx,%ecx
f010369a:	c1 e9 0c             	shr    $0xc,%ecx
f010369d:	3b 0d 88 7e 1c f0    	cmp    0xf01c7e88,%ecx
f01036a3:	72 20                	jb     f01036c5 <env_alloc+0x65>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01036a5:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01036a9:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
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
f01036d3:	8b 0d 8c 7e 1c f0    	mov    0xf01c7e8c,%ecx
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
f0103700:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
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
f0103742:	2b 15 48 72 1c f0    	sub    0xf01c7248,%edx
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
f0103784:	e8 60 27 00 00       	call   f0105ee9 <memset>
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
f01037c0:	a3 4c 72 1c f0       	mov    %eax,0xf01c724c
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
f0103802:	0f 85 cd 01 00 00    	jne    f01039d5 <env_create+0x1f1>
		load_icode(env,binary,size);
f0103808:	8b 75 e4             	mov    -0x1c(%ebp),%esi
	//  this function?
	//
	//  You must also do something with the program's entry point,
	//  to make sure that the environment starts executing there.
	//  What?  (See env_run() and env_pop_tf() below.)
	 lcr3(PADDR(e->env_pgdir));
f010380b:	8b 46 60             	mov    0x60(%esi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010380e:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103813:	77 20                	ja     f0103835 <env_create+0x51>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103815:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103819:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
f0103820:	f0 
f0103821:	c7 44 24 04 65 01 00 	movl   $0x165,0x4(%esp)
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

    	struct Elf* ELFHDR = (struct Elf*)binary;

    	assert(ELFHDR->e_magic == ELF_MAGIC);
f010383d:	8b 45 08             	mov    0x8(%ebp),%eax
f0103840:	81 38 7f 45 4c 46    	cmpl   $0x464c457f,(%eax)
f0103846:	74 24                	je     f010386c <env_create+0x88>
f0103848:	c7 44 24 0c ec 7c 10 	movl   $0xf0107cec,0xc(%esp)
f010384f:	f0 
f0103850:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0103857:	f0 
f0103858:	c7 44 24 04 69 01 00 	movl   $0x169,0x4(%esp)
f010385f:	00 
f0103860:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103867:	e8 d4 c7 ff ff       	call   f0100040 <_panic>
   	 struct Proghdr *ph, *eph;

   	 uint8_t* p_src = NULL, *p_dst = NULL;
    	uint32_t cnt = 0;

    	ph = (struct Proghdr *) (binary + ELFHDR->e_phoff);
f010386c:	8b 45 08             	mov    0x8(%ebp),%eax
f010386f:	89 c7                	mov    %eax,%edi
f0103871:	03 78 1c             	add    0x1c(%eax),%edi
    	eph = ph + ELFHDR->e_phnum;
f0103874:	0f b7 40 2c          	movzwl 0x2c(%eax),%eax
f0103878:	c1 e0 05             	shl    $0x5,%eax
f010387b:	01 f8                	add    %edi,%eax
f010387d:	89 45 d4             	mov    %eax,-0x2c(%ebp)

    	for(; ph < eph; ph++)
f0103880:	39 c7                	cmp    %eax,%edi
f0103882:	0f 83 a6 00 00 00    	jae    f010392e <env_create+0x14a>
   	 {
        		if(ph->p_type == ELF_PROG_LOAD)
f0103888:	83 3f 01             	cmpl   $0x1,(%edi)
f010388b:	0f 85 91 00 00 00    	jne    f0103922 <env_create+0x13e>
        		{
            			region_alloc(e, (void*)ph->p_va, ph->p_memsz);
f0103891:	8b 47 08             	mov    0x8(%edi),%eax
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f0103894:	89 c3                	mov    %eax,%ebx
f0103896:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f010389c:	03 47 14             	add    0x14(%edi),%eax
f010389f:	05 ff 0f 00 00       	add    $0xfff,%eax
f01038a4:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01038a9:	39 c3                	cmp    %eax,%ebx
f01038ab:	73 59                	jae    f0103906 <env_create+0x122>
f01038ad:	89 7d d0             	mov    %edi,-0x30(%ebp)
f01038b0:	89 c7                	mov    %eax,%edi
		p = (struct Page*)page_alloc(1);
f01038b2:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01038b9:	e8 58 d8 ff ff       	call   f0101116 <page_alloc>
		if(p==NULL)
f01038be:	85 c0                	test   %eax,%eax
f01038c0:	75 1c                	jne    f01038de <env_create+0xfa>
			panic("Memory out!");
f01038c2:	c7 44 24 08 09 7d 10 	movl   $0xf0107d09,0x8(%esp)
f01038c9:	f0 
f01038ca:	c7 44 24 04 2c 01 00 	movl   $0x12c,0x4(%esp)
f01038d1:	00 
f01038d2:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f01038d9:	e8 62 c7 ff ff       	call   f0100040 <_panic>
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
f01038de:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01038e5:	00 
f01038e6:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f01038ea:	89 44 24 04          	mov    %eax,0x4(%esp)
f01038ee:	8b 46 60             	mov    0x60(%esi),%eax
f01038f1:	89 04 24             	mov    %eax,(%esp)
f01038f4:	e8 57 db ff ff       	call   f0101450 <page_insert>
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f01038f9:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f01038ff:	39 fb                	cmp    %edi,%ebx
f0103901:	72 af                	jb     f01038b2 <env_create+0xce>
f0103903:	8b 7d d0             	mov    -0x30(%ebp),%edi
    	for(; ph < eph; ph++)
   	 {
        		if(ph->p_type == ELF_PROG_LOAD)
        		{
            			region_alloc(e, (void*)ph->p_va, ph->p_memsz);
           			 memmove((void*)ph->p_va, (void*)binary + ph->p_offset, ph->p_filesz);
f0103906:	8b 47 10             	mov    0x10(%edi),%eax
f0103909:	89 44 24 08          	mov    %eax,0x8(%esp)
f010390d:	8b 45 08             	mov    0x8(%ebp),%eax
f0103910:	03 47 04             	add    0x4(%edi),%eax
f0103913:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103917:	8b 47 08             	mov    0x8(%edi),%eax
f010391a:	89 04 24             	mov    %eax,(%esp)
f010391d:	e8 14 26 00 00       	call   f0105f36 <memmove>
    	uint32_t cnt = 0;

    	ph = (struct Proghdr *) (binary + ELFHDR->e_phoff);
    	eph = ph + ELFHDR->e_phnum;

    	for(; ph < eph; ph++)
f0103922:	83 c7 20             	add    $0x20,%edi
f0103925:	39 7d d4             	cmp    %edi,-0x2c(%ebp)
f0103928:	0f 87 5a ff ff ff    	ja     f0103888 <env_create+0xa4>
        		{
            			region_alloc(e, (void*)ph->p_va, ph->p_memsz);
           			 memmove((void*)ph->p_va, (void*)binary + ph->p_offset, ph->p_filesz);
       		 }
   	 }
    	e->env_tf.tf_eip = ELFHDR->e_entry;
f010392e:	8b 45 08             	mov    0x8(%ebp),%eax
f0103931:	8b 40 18             	mov    0x18(%eax),%eax
f0103934:	89 46 30             	mov    %eax,0x30(%esi)
    	// Now map one page for the program's initial stack
    	// at virtual address USTACKTOP - PGSIZE.

    	// LAB 3: Your code here.
    	struct Page* stack_page = (struct Page*)page_alloc(1);
f0103937:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f010393e:	e8 d3 d7 ff ff       	call   f0101116 <page_alloc>
   	if(stack_page == 0)
f0103943:	85 c0                	test   %eax,%eax
f0103945:	75 24                	jne    f010396b <env_create+0x187>
        		panic("load_icode(): %e", -E_NO_MEM);
f0103947:	c7 44 24 0c fc ff ff 	movl   $0xfffffffc,0xc(%esp)
f010394e:	ff 
f010394f:	c7 44 24 08 15 7d 10 	movl   $0xf0107d15,0x8(%esp)
f0103956:	f0 
f0103957:	c7 44 24 04 82 01 00 	movl   $0x182,0x4(%esp)
f010395e:	00 
f010395f:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103966:	e8 d5 c6 ff ff       	call   f0100040 <_panic>
        	//cprintf("except page_insert Complete in env_create\n");
	//readline("type_anything\n");
    	page_insert(e->env_pgdir, stack_page, (void*)(USTACKTOP - PGSIZE), PTE_W | PTE_U);
f010396b:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0103972:	00 
f0103973:	c7 44 24 08 00 d0 bf 	movl   $0xeebfd000,0x8(%esp)
f010397a:	ee 
f010397b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010397f:	8b 46 60             	mov    0x60(%esi),%eax
f0103982:	89 04 24             	mov    %eax,(%esp)
f0103985:	e8 c6 da ff ff       	call   f0101450 <page_insert>

    	lcr3(PADDR(kern_pgdir));
f010398a:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010398f:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103994:	77 20                	ja     f01039b6 <env_create+0x1d2>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103996:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010399a:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
f01039a1:	f0 
f01039a2:	c7 44 24 04 87 01 00 	movl   $0x187,0x4(%esp)
f01039a9:	00 
f01039aa:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f01039b1:	e8 8a c6 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01039b6:	05 00 00 00 10       	add    $0x10000000,%eax
f01039bb:	0f 22 d8             	mov    %eax,%cr3
	// LAB 5: Your code here.
	struct Env * env;
	int test = env_alloc(&env,0);
	if(test==0){
		load_icode(env,binary,size);
		env->env_type = type;
f01039be:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01039c1:	8b 55 10             	mov    0x10(%ebp),%edx
f01039c4:	89 50 50             	mov    %edx,0x50(%eax)
		if(type==ENV_TYPE_FS){
f01039c7:	83 fa 02             	cmp    $0x2,%edx
f01039ca:	75 25                	jne    f01039f1 <env_create+0x20d>
			env->env_tf.tf_eflags |= FL_IOPL_3;
f01039cc:	81 48 38 00 30 00 00 	orl    $0x3000,0x38(%eax)
f01039d3:	eb 1c                	jmp    f01039f1 <env_create+0x20d>
		}else{
			env->env_tf.tf_eflags |=FL_IOPL_0;
		}
	}else{
		panic("create env fails !\n");
f01039d5:	c7 44 24 08 26 7d 10 	movl   $0xf0107d26,0x8(%esp)
f01039dc:	f0 
f01039dd:	c7 44 24 04 c1 01 00 	movl   $0x1c1,0x4(%esp)
f01039e4:	00 
f01039e5:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f01039ec:	e8 4f c6 ff ff       	call   f0100040 <_panic>
	}
}
f01039f1:	83 c4 3c             	add    $0x3c,%esp
f01039f4:	5b                   	pop    %ebx
f01039f5:	5e                   	pop    %esi
f01039f6:	5f                   	pop    %edi
f01039f7:	5d                   	pop    %ebp
f01039f8:	c3                   	ret    

f01039f9 <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f01039f9:	55                   	push   %ebp
f01039fa:	89 e5                	mov    %esp,%ebp
f01039fc:	57                   	push   %edi
f01039fd:	56                   	push   %esi
f01039fe:	53                   	push   %ebx
f01039ff:	83 ec 2c             	sub    $0x2c,%esp
f0103a02:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f0103a05:	e8 79 2b 00 00       	call   f0106583 <cpunum>
f0103a0a:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a0d:	39 b8 28 80 1c f0    	cmp    %edi,-0xfe37fd8(%eax)
f0103a13:	74 09                	je     f0103a1e <env_free+0x25>
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0103a15:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0103a1c:	eb 36                	jmp    f0103a54 <env_free+0x5b>

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
		lcr3(PADDR(kern_pgdir));
f0103a1e:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103a23:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103a28:	77 20                	ja     f0103a4a <env_free+0x51>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103a2a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103a2e:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
f0103a35:	f0 
f0103a36:	c7 44 24 04 d3 01 00 	movl   $0x1d3,0x4(%esp)
f0103a3d:	00 
f0103a3e:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103a45:	e8 f6 c5 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103a4a:	05 00 00 00 10       	add    $0x10000000,%eax
f0103a4f:	0f 22 d8             	mov    %eax,%cr3
f0103a52:	eb c1                	jmp    f0103a15 <env_free+0x1c>
f0103a54:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0103a57:	89 c8                	mov    %ecx,%eax
f0103a59:	c1 e0 02             	shl    $0x2,%eax
f0103a5c:	89 45 dc             	mov    %eax,-0x24(%ebp)
	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f0103a5f:	8b 47 60             	mov    0x60(%edi),%eax
f0103a62:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f0103a65:	f7 c6 01 00 00 00    	test   $0x1,%esi
f0103a6b:	0f 84 b7 00 00 00    	je     f0103b28 <env_free+0x12f>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f0103a71:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103a77:	89 f0                	mov    %esi,%eax
f0103a79:	c1 e8 0c             	shr    $0xc,%eax
f0103a7c:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103a7f:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f0103a85:	72 20                	jb     f0103aa7 <env_free+0xae>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103a87:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0103a8b:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
f0103a92:	f0 
f0103a93:	c7 44 24 04 e2 01 00 	movl   $0x1e2,0x4(%esp)
f0103a9a:	00 
f0103a9b:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103aa2:	e8 99 c5 ff ff       	call   f0100040 <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103aa7:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103aaa:	c1 e0 16             	shl    $0x16,%eax
f0103aad:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103ab0:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f0103ab5:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f0103abc:	01 
f0103abd:	74 17                	je     f0103ad6 <env_free+0xdd>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103abf:	89 d8                	mov    %ebx,%eax
f0103ac1:	c1 e0 0c             	shl    $0xc,%eax
f0103ac4:	0b 45 e4             	or     -0x1c(%ebp),%eax
f0103ac7:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103acb:	8b 47 60             	mov    0x60(%edi),%eax
f0103ace:	89 04 24             	mov    %eax,(%esp)
f0103ad1:	e8 31 d9 ff ff       	call   f0101407 <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103ad6:	83 c3 01             	add    $0x1,%ebx
f0103ad9:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f0103adf:	75 d4                	jne    f0103ab5 <env_free+0xbc>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f0103ae1:	8b 47 60             	mov    0x60(%edi),%eax
f0103ae4:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103ae7:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103aee:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103af1:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f0103af7:	72 1c                	jb     f0103b15 <env_free+0x11c>
		panic("pa2page called with invalid pa");
f0103af9:	c7 44 24 08 94 73 10 	movl   $0xf0107394,0x8(%esp)
f0103b00:	f0 
f0103b01:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103b08:	00 
f0103b09:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f0103b10:	e8 2b c5 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103b15:	a1 90 7e 1c f0       	mov    0xf01c7e90,%eax
f0103b1a:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103b1d:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0103b20:	89 04 24             	mov    %eax,(%esp)
f0103b23:	e8 88 d6 ff ff       	call   f01011b0 <page_decref>
	// Note the environment's demise.
	// cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103b28:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f0103b2c:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f0103b33:	0f 85 1b ff ff ff    	jne    f0103a54 <env_free+0x5b>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f0103b39:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103b3c:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103b41:	77 20                	ja     f0103b63 <env_free+0x16a>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103b43:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103b47:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
f0103b4e:	f0 
f0103b4f:	c7 44 24 04 f0 01 00 	movl   $0x1f0,0x4(%esp)
f0103b56:	00 
f0103b57:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103b5e:	e8 dd c4 ff ff       	call   f0100040 <_panic>
	e->env_pgdir = 0;
f0103b63:	c7 47 60 00 00 00 00 	movl   $0x0,0x60(%edi)
	return (physaddr_t)kva - KERNBASE;
f0103b6a:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103b6f:	c1 e8 0c             	shr    $0xc,%eax
f0103b72:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f0103b78:	72 1c                	jb     f0103b96 <env_free+0x19d>
		panic("pa2page called with invalid pa");
f0103b7a:	c7 44 24 08 94 73 10 	movl   $0xf0107394,0x8(%esp)
f0103b81:	f0 
f0103b82:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103b89:	00 
f0103b8a:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f0103b91:	e8 aa c4 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103b96:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
f0103b9c:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f0103b9f:	89 04 24             	mov    %eax,(%esp)
f0103ba2:	e8 09 d6 ff ff       	call   f01011b0 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f0103ba7:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f0103bae:	a1 4c 72 1c f0       	mov    0xf01c724c,%eax
f0103bb3:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f0103bb6:	89 3d 4c 72 1c f0    	mov    %edi,0xf01c724c
}
f0103bbc:	83 c4 2c             	add    $0x2c,%esp
f0103bbf:	5b                   	pop    %ebx
f0103bc0:	5e                   	pop    %esi
f0103bc1:	5f                   	pop    %edi
f0103bc2:	5d                   	pop    %ebp
f0103bc3:	c3                   	ret    

f0103bc4 <env_destroy>:
// If e was the current env, then runs a new environment (and does not return
// to the caller).
//
void
env_destroy(struct Env *e)
{
f0103bc4:	55                   	push   %ebp
f0103bc5:	89 e5                	mov    %esp,%ebp
f0103bc7:	53                   	push   %ebx
f0103bc8:	83 ec 14             	sub    $0x14,%esp
f0103bcb:	8b 5d 08             	mov    0x8(%ebp),%ebx
	// If e is currently running on other CPUs, we change its state to
	// ENV_DYING. A zombie environment will be freed the next time
	// it traps to the kernel.
	if (e->env_status == ENV_RUNNING && curenv != e) {
f0103bce:	83 7b 54 03          	cmpl   $0x3,0x54(%ebx)
f0103bd2:	75 19                	jne    f0103bed <env_destroy+0x29>
f0103bd4:	e8 aa 29 00 00       	call   f0106583 <cpunum>
f0103bd9:	6b c0 74             	imul   $0x74,%eax,%eax
f0103bdc:	39 98 28 80 1c f0    	cmp    %ebx,-0xfe37fd8(%eax)
f0103be2:	74 09                	je     f0103bed <env_destroy+0x29>
		e->env_status = ENV_DYING;
f0103be4:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
		return;
f0103beb:	eb 2f                	jmp    f0103c1c <env_destroy+0x58>
	}

	env_free(e);
f0103bed:	89 1c 24             	mov    %ebx,(%esp)
f0103bf0:	e8 04 fe ff ff       	call   f01039f9 <env_free>

	if (curenv == e) {
f0103bf5:	e8 89 29 00 00       	call   f0106583 <cpunum>
f0103bfa:	6b c0 74             	imul   $0x74,%eax,%eax
f0103bfd:	39 98 28 80 1c f0    	cmp    %ebx,-0xfe37fd8(%eax)
f0103c03:	75 17                	jne    f0103c1c <env_destroy+0x58>
		curenv = NULL;
f0103c05:	e8 79 29 00 00       	call   f0106583 <cpunum>
f0103c0a:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c0d:	c7 80 28 80 1c f0 00 	movl   $0x0,-0xfe37fd8(%eax)
f0103c14:	00 00 00 
		sched_yield();
f0103c17:	e8 84 0f 00 00       	call   f0104ba0 <sched_yield>
	}
}
f0103c1c:	83 c4 14             	add    $0x14,%esp
f0103c1f:	5b                   	pop    %ebx
f0103c20:	5d                   	pop    %ebp
f0103c21:	c3                   	ret    

f0103c22 <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f0103c22:	55                   	push   %ebp
f0103c23:	89 e5                	mov    %esp,%ebp
f0103c25:	53                   	push   %ebx
f0103c26:	83 ec 14             	sub    $0x14,%esp
	// Record the CPU we are running on for user-space debugging
	curenv->env_cpunum = cpunum();
f0103c29:	e8 55 29 00 00       	call   f0106583 <cpunum>
f0103c2e:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c31:	8b 98 28 80 1c f0    	mov    -0xfe37fd8(%eax),%ebx
f0103c37:	e8 47 29 00 00       	call   f0106583 <cpunum>
f0103c3c:	89 43 5c             	mov    %eax,0x5c(%ebx)

	__asm __volatile("movl %0,%%esp\n"
f0103c3f:	8b 65 08             	mov    0x8(%ebp),%esp
f0103c42:	61                   	popa   
f0103c43:	07                   	pop    %es
f0103c44:	1f                   	pop    %ds
f0103c45:	83 c4 08             	add    $0x8,%esp
f0103c48:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f0103c49:	c7 44 24 08 3a 7d 10 	movl   $0xf0107d3a,0x8(%esp)
f0103c50:	f0 
f0103c51:	c7 44 24 04 26 02 00 	movl   $0x226,0x4(%esp)
f0103c58:	00 
f0103c59:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103c60:	e8 db c3 ff ff       	call   f0100040 <_panic>

f0103c65 <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0103c65:	55                   	push   %ebp
f0103c66:	89 e5                	mov    %esp,%ebp
f0103c68:	53                   	push   %ebx
f0103c69:	83 ec 14             	sub    $0x14,%esp
f0103c6c:	8b 5d 08             	mov    0x8(%ebp),%ebx

	// Hint: This function loads the new environment's state from
	//	e->env_tf.  Go back through the code you wrote above
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.
	if(curenv!=NULL&& curenv->env_status==ENV_RUNNING)
f0103c6f:	e8 0f 29 00 00       	call   f0106583 <cpunum>
f0103c74:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c77:	83 b8 28 80 1c f0 00 	cmpl   $0x0,-0xfe37fd8(%eax)
f0103c7e:	74 29                	je     f0103ca9 <env_run+0x44>
f0103c80:	e8 fe 28 00 00       	call   f0106583 <cpunum>
f0103c85:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c88:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0103c8e:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0103c92:	75 15                	jne    f0103ca9 <env_run+0x44>
		curenv->env_status = ENV_RUNNABLE;
f0103c94:	e8 ea 28 00 00       	call   f0106583 <cpunum>
f0103c99:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c9c:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0103ca2:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)

	curenv = e;
f0103ca9:	e8 d5 28 00 00       	call   f0106583 <cpunum>
f0103cae:	6b c0 74             	imul   $0x74,%eax,%eax
f0103cb1:	89 98 28 80 1c f0    	mov    %ebx,-0xfe37fd8(%eax)
	int zero = 0;
	e->env_status = ENV_RUNNING;
f0103cb7:	c7 43 54 03 00 00 00 	movl   $0x3,0x54(%ebx)
	e->env_runs++;
f0103cbe:	83 43 58 01          	addl   $0x1,0x58(%ebx)
	lcr3(PADDR(e->env_pgdir));
f0103cc2:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103cc5:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103cca:	77 20                	ja     f0103cec <env_run+0x87>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103ccc:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103cd0:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
f0103cd7:	f0 
f0103cd8:	c7 44 24 04 49 02 00 	movl   $0x249,0x4(%esp)
f0103cdf:	00 
f0103ce0:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f0103ce7:	e8 54 c3 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103cec:	05 00 00 00 10       	add    $0x10000000,%eax
f0103cf1:	0f 22 d8             	mov    %eax,%cr3
}

static inline void
unlock_kernel(void)
{
	spin_unlock(&kernel_lock);
f0103cf4:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f0103cfb:	e8 cc 2b 00 00       	call   f01068cc <spin_unlock>

	// Normally we wouldn't need to do this, but QEMU only runs
	// one CPU at a time and has a long time-slice.  Without the
	// pause, this CPU is likely to reacquire the lock before
	// another CPU has even been given a chance to acquire it.
	asm volatile("pause");
f0103d00:	f3 90                	pause  
	unlock_kernel();

	env_pop_tf(&e->env_tf);
f0103d02:	89 1c 24             	mov    %ebx,(%esp)
f0103d05:	e8 18 ff ff ff       	call   f0103c22 <env_pop_tf>

f0103d0a <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0103d0a:	55                   	push   %ebp
f0103d0b:	89 e5                	mov    %esp,%ebp
f0103d0d:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103d11:	ba 70 00 00 00       	mov    $0x70,%edx
f0103d16:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0103d17:	b2 71                	mov    $0x71,%dl
f0103d19:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0103d1a:	0f b6 c0             	movzbl %al,%eax
}
f0103d1d:	5d                   	pop    %ebp
f0103d1e:	c3                   	ret    

f0103d1f <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0103d1f:	55                   	push   %ebp
f0103d20:	89 e5                	mov    %esp,%ebp
f0103d22:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103d26:	ba 70 00 00 00       	mov    $0x70,%edx
f0103d2b:	ee                   	out    %al,(%dx)
f0103d2c:	b2 71                	mov    $0x71,%dl
f0103d2e:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103d31:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0103d32:	5d                   	pop    %ebp
f0103d33:	c3                   	ret    

f0103d34 <irq_setmask_8259A>:
		irq_setmask_8259A(irq_mask_8259A);
}

void
irq_setmask_8259A(uint16_t mask)
{
f0103d34:	55                   	push   %ebp
f0103d35:	89 e5                	mov    %esp,%ebp
f0103d37:	56                   	push   %esi
f0103d38:	53                   	push   %ebx
f0103d39:	83 ec 10             	sub    $0x10,%esp
f0103d3c:	8b 45 08             	mov    0x8(%ebp),%eax
	int i;
	irq_mask_8259A = mask;
f0103d3f:	66 a3 88 13 12 f0    	mov    %ax,0xf0121388
	if (!didinit)
f0103d45:	83 3d 50 72 1c f0 00 	cmpl   $0x0,0xf01c7250
f0103d4c:	74 4e                	je     f0103d9c <irq_setmask_8259A+0x68>
f0103d4e:	89 c6                	mov    %eax,%esi
f0103d50:	ba 21 00 00 00       	mov    $0x21,%edx
f0103d55:	ee                   	out    %al,(%dx)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
f0103d56:	66 c1 e8 08          	shr    $0x8,%ax
f0103d5a:	b2 a1                	mov    $0xa1,%dl
f0103d5c:	ee                   	out    %al,(%dx)
	cprintf("enabled interrupts:");
f0103d5d:	c7 04 24 46 7d 10 f0 	movl   $0xf0107d46,(%esp)
f0103d64:	e8 0d 01 00 00       	call   f0103e76 <cprintf>
	for (i = 0; i < 16; i++)
f0103d69:	bb 00 00 00 00       	mov    $0x0,%ebx
		if (~mask & (1<<i))
f0103d6e:	0f b7 f6             	movzwl %si,%esi
f0103d71:	f7 d6                	not    %esi
f0103d73:	0f a3 de             	bt     %ebx,%esi
f0103d76:	73 10                	jae    f0103d88 <irq_setmask_8259A+0x54>
			cprintf(" %d", i);
f0103d78:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103d7c:	c7 04 24 df 81 10 f0 	movl   $0xf01081df,(%esp)
f0103d83:	e8 ee 00 00 00       	call   f0103e76 <cprintf>
	if (!didinit)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
	cprintf("enabled interrupts:");
	for (i = 0; i < 16; i++)
f0103d88:	83 c3 01             	add    $0x1,%ebx
f0103d8b:	83 fb 10             	cmp    $0x10,%ebx
f0103d8e:	75 e3                	jne    f0103d73 <irq_setmask_8259A+0x3f>
		if (~mask & (1<<i))
			cprintf(" %d", i);
	cprintf("\n");
f0103d90:	c7 04 24 38 7d 10 f0 	movl   $0xf0107d38,(%esp)
f0103d97:	e8 da 00 00 00       	call   f0103e76 <cprintf>
}
f0103d9c:	83 c4 10             	add    $0x10,%esp
f0103d9f:	5b                   	pop    %ebx
f0103da0:	5e                   	pop    %esi
f0103da1:	5d                   	pop    %ebp
f0103da2:	c3                   	ret    

f0103da3 <pic_init>:

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
	didinit = 1;
f0103da3:	c7 05 50 72 1c f0 01 	movl   $0x1,0xf01c7250
f0103daa:	00 00 00 
f0103dad:	ba 21 00 00 00       	mov    $0x21,%edx
f0103db2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0103db7:	ee                   	out    %al,(%dx)
f0103db8:	b2 a1                	mov    $0xa1,%dl
f0103dba:	ee                   	out    %al,(%dx)
f0103dbb:	b2 20                	mov    $0x20,%dl
f0103dbd:	b8 11 00 00 00       	mov    $0x11,%eax
f0103dc2:	ee                   	out    %al,(%dx)
f0103dc3:	b2 21                	mov    $0x21,%dl
f0103dc5:	b8 20 00 00 00       	mov    $0x20,%eax
f0103dca:	ee                   	out    %al,(%dx)
f0103dcb:	b8 04 00 00 00       	mov    $0x4,%eax
f0103dd0:	ee                   	out    %al,(%dx)
f0103dd1:	b8 03 00 00 00       	mov    $0x3,%eax
f0103dd6:	ee                   	out    %al,(%dx)
f0103dd7:	b2 a0                	mov    $0xa0,%dl
f0103dd9:	b8 11 00 00 00       	mov    $0x11,%eax
f0103dde:	ee                   	out    %al,(%dx)
f0103ddf:	b2 a1                	mov    $0xa1,%dl
f0103de1:	b8 28 00 00 00       	mov    $0x28,%eax
f0103de6:	ee                   	out    %al,(%dx)
f0103de7:	b8 02 00 00 00       	mov    $0x2,%eax
f0103dec:	ee                   	out    %al,(%dx)
f0103ded:	b8 01 00 00 00       	mov    $0x1,%eax
f0103df2:	ee                   	out    %al,(%dx)
f0103df3:	b2 20                	mov    $0x20,%dl
f0103df5:	b8 68 00 00 00       	mov    $0x68,%eax
f0103dfa:	ee                   	out    %al,(%dx)
f0103dfb:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103e00:	ee                   	out    %al,(%dx)
f0103e01:	b2 a0                	mov    $0xa0,%dl
f0103e03:	b8 68 00 00 00       	mov    $0x68,%eax
f0103e08:	ee                   	out    %al,(%dx)
f0103e09:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103e0e:	ee                   	out    %al,(%dx)
	outb(IO_PIC1, 0x0a);             /* read IRR by default */

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
f0103e0f:	0f b7 05 88 13 12 f0 	movzwl 0xf0121388,%eax
f0103e16:	66 83 f8 ff          	cmp    $0xffff,%ax
f0103e1a:	74 12                	je     f0103e2e <pic_init+0x8b>
static bool didinit;

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
f0103e1c:	55                   	push   %ebp
f0103e1d:	89 e5                	mov    %esp,%ebp
f0103e1f:	83 ec 18             	sub    $0x18,%esp

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
		irq_setmask_8259A(irq_mask_8259A);
f0103e22:	0f b7 c0             	movzwl %ax,%eax
f0103e25:	89 04 24             	mov    %eax,(%esp)
f0103e28:	e8 07 ff ff ff       	call   f0103d34 <irq_setmask_8259A>
}
f0103e2d:	c9                   	leave  
f0103e2e:	f3 c3                	repz ret 

f0103e30 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0103e30:	55                   	push   %ebp
f0103e31:	89 e5                	mov    %esp,%ebp
f0103e33:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0103e36:	8b 45 08             	mov    0x8(%ebp),%eax
f0103e39:	89 04 24             	mov    %eax,(%esp)
f0103e3c:	e8 bc c9 ff ff       	call   f01007fd <cputchar>
	*cnt++;
}
f0103e41:	c9                   	leave  
f0103e42:	c3                   	ret    

f0103e43 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0103e43:	55                   	push   %ebp
f0103e44:	89 e5                	mov    %esp,%ebp
f0103e46:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0103e49:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0103e50:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103e53:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103e57:	8b 45 08             	mov    0x8(%ebp),%eax
f0103e5a:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103e5e:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0103e61:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e65:	c7 04 24 30 3e 10 f0 	movl   $0xf0103e30,(%esp)
f0103e6c:	e8 33 19 00 00       	call   f01057a4 <vprintfmt>
	return cnt;
}
f0103e71:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0103e74:	c9                   	leave  
f0103e75:	c3                   	ret    

f0103e76 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0103e76:	55                   	push   %ebp
f0103e77:	89 e5                	mov    %esp,%ebp
f0103e79:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0103e7c:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0103e7f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e83:	8b 45 08             	mov    0x8(%ebp),%eax
f0103e86:	89 04 24             	mov    %eax,(%esp)
f0103e89:	e8 b5 ff ff ff       	call   f0103e43 <vcprintf>
	va_end(ap);

	return cnt;
}
f0103e8e:	c9                   	leave  
f0103e8f:	c3                   	ret    

f0103e90 <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f0103e90:	55                   	push   %ebp
f0103e91:	89 e5                	mov    %esp,%ebp
f0103e93:	53                   	push   %ebx
f0103e94:	83 ec 04             	sub    $0x4,%esp
	struct Taskstate* this_ts = &thiscpu->cpu_ts;
f0103e97:	e8 e7 26 00 00       	call   f0106583 <cpunum>
f0103e9c:	6b d8 74             	imul   $0x74,%eax,%ebx
	int CPUID = cpunum();
f0103e9f:	e8 df 26 00 00       	call   f0106583 <cpunum>
	this_ts->ts_esp0 = KSTACKTOP - CPUID * (KSTKGAP + KSTKSIZE);
f0103ea4:	89 c2                	mov    %eax,%edx
f0103ea6:	f7 da                	neg    %edx
f0103ea8:	c1 e2 10             	shl    $0x10,%edx
f0103eab:	81 ea 00 00 40 10    	sub    $0x10400000,%edx
f0103eb1:	89 93 30 80 1c f0    	mov    %edx,-0xfe37fd0(%ebx)
	this_ts->ts_ss0 = GD_KD;
f0103eb7:	66 c7 83 34 80 1c f0 	movw   $0x10,-0xfe37fcc(%ebx)
f0103ebe:	10 00 

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
	struct Taskstate* this_ts = &thiscpu->cpu_ts;
f0103ec0:	81 c3 2c 80 1c f0    	add    $0xf01c802c,%ebx
	int CPUID = cpunum();
	this_ts->ts_esp0 = KSTACKTOP - CPUID * (KSTKGAP + KSTKSIZE);
	this_ts->ts_ss0 = GD_KD;

	gdt[(GD_TSS0 >> 3) + CPUID] = SEG16(STS_T32A, (uint32_t) (this_ts),
f0103ec6:	8d 50 05             	lea    0x5(%eax),%edx
f0103ec9:	66 c7 04 d5 20 13 12 	movw   $0x68,-0xfedece0(,%edx,8)
f0103ed0:	f0 68 00 
f0103ed3:	66 89 1c d5 22 13 12 	mov    %bx,-0xfedecde(,%edx,8)
f0103eda:	f0 
f0103edb:	89 d9                	mov    %ebx,%ecx
f0103edd:	c1 e9 10             	shr    $0x10,%ecx
f0103ee0:	88 0c d5 24 13 12 f0 	mov    %cl,-0xfedecdc(,%edx,8)
f0103ee7:	c6 04 d5 26 13 12 f0 	movb   $0x40,-0xfedecda(,%edx,8)
f0103eee:	40 
f0103eef:	c1 eb 18             	shr    $0x18,%ebx
f0103ef2:	88 1c d5 27 13 12 f0 	mov    %bl,-0xfedecd9(,%edx,8)
					sizeof(struct Taskstate), 0);
	gdt[(GD_TSS0 >> 3) + CPUID].sd_s = 0;
f0103ef9:	c6 04 d5 25 13 12 f0 	movb   $0x89,-0xfedecdb(,%edx,8)
f0103f00:	89 

	//cprintf("Loading GD_TSS_ %d\n", ((GD_TSS0>>3) + CPUID)<<3);

	ltr(GD_TSS0 + (CPUID << 3));
f0103f01:	8d 04 c5 28 00 00 00 	lea    0x28(,%eax,8),%eax
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f0103f08:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f0103f0b:	b8 8a 13 12 f0       	mov    $0xf012138a,%eax
f0103f10:	0f 01 18             	lidtl  (%eax)
	// bottom three bits are special; we leave them 0)
	ltr(GD_TSS0+(cpu_id<<3));

	// Load the IDT
	lidt(&idt_pd);*/
}
f0103f13:	83 c4 04             	add    $0x4,%esp
f0103f16:	5b                   	pop    %ebx
f0103f17:	5d                   	pop    %ebp
f0103f18:	c3                   	ret    

f0103f19 <trap_init>:
}


void
trap_init(void)
{
f0103f19:	55                   	push   %ebp
f0103f1a:	89 e5                	mov    %esp,%ebp
f0103f1c:	83 ec 08             	sub    $0x8,%esp
	extern struct Segdesc gdt[];
	SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);
f0103f1f:	b8 8a 4a 10 f0       	mov    $0xf0104a8a,%eax
f0103f24:	66 a3 60 72 1c f0    	mov    %ax,0xf01c7260
f0103f2a:	66 c7 05 62 72 1c f0 	movw   $0x8,0xf01c7262
f0103f31:	08 00 
f0103f33:	c6 05 64 72 1c f0 00 	movb   $0x0,0xf01c7264
f0103f3a:	c6 05 65 72 1c f0 8f 	movb   $0x8f,0xf01c7265
f0103f41:	c1 e8 10             	shr    $0x10,%eax
f0103f44:	66 a3 66 72 1c f0    	mov    %ax,0xf01c7266
	SETGATE(idt[2], 0, GD_KT, nmi_handler, 0);
f0103f4a:	b8 94 4a 10 f0       	mov    $0xf0104a94,%eax
f0103f4f:	66 a3 70 72 1c f0    	mov    %ax,0xf01c7270
f0103f55:	66 c7 05 72 72 1c f0 	movw   $0x8,0xf01c7272
f0103f5c:	08 00 
f0103f5e:	c6 05 74 72 1c f0 00 	movb   $0x0,0xf01c7274
f0103f65:	c6 05 75 72 1c f0 8e 	movb   $0x8e,0xf01c7275
f0103f6c:	c1 e8 10             	shr    $0x10,%eax
f0103f6f:	66 a3 76 72 1c f0    	mov    %ax,0xf01c7276
	SETGATE(idt[3], 1, GD_KT, breakpoint_handler, 3);
f0103f75:	b8 9e 4a 10 f0       	mov    $0xf0104a9e,%eax
f0103f7a:	66 a3 78 72 1c f0    	mov    %ax,0xf01c7278
f0103f80:	66 c7 05 7a 72 1c f0 	movw   $0x8,0xf01c727a
f0103f87:	08 00 
f0103f89:	c6 05 7c 72 1c f0 00 	movb   $0x0,0xf01c727c
f0103f90:	c6 05 7d 72 1c f0 ef 	movb   $0xef,0xf01c727d
f0103f97:	c1 e8 10             	shr    $0x10,%eax
f0103f9a:	66 a3 7e 72 1c f0    	mov    %ax,0xf01c727e
	SETGATE(idt[4], 1, GD_KT, overflow_handler, 3);
f0103fa0:	b8 a8 4a 10 f0       	mov    $0xf0104aa8,%eax
f0103fa5:	66 a3 80 72 1c f0    	mov    %ax,0xf01c7280
f0103fab:	66 c7 05 82 72 1c f0 	movw   $0x8,0xf01c7282
f0103fb2:	08 00 
f0103fb4:	c6 05 84 72 1c f0 00 	movb   $0x0,0xf01c7284
f0103fbb:	c6 05 85 72 1c f0 ef 	movb   $0xef,0xf01c7285
f0103fc2:	c1 e8 10             	shr    $0x10,%eax
f0103fc5:	66 a3 86 72 1c f0    	mov    %ax,0xf01c7286
	SETGATE(idt[5], 1, GD_KT, bdrgeexceed_handler, 3);
f0103fcb:	b8 b2 4a 10 f0       	mov    $0xf0104ab2,%eax
f0103fd0:	66 a3 88 72 1c f0    	mov    %ax,0xf01c7288
f0103fd6:	66 c7 05 8a 72 1c f0 	movw   $0x8,0xf01c728a
f0103fdd:	08 00 
f0103fdf:	c6 05 8c 72 1c f0 00 	movb   $0x0,0xf01c728c
f0103fe6:	c6 05 8d 72 1c f0 ef 	movb   $0xef,0xf01c728d
f0103fed:	c1 e8 10             	shr    $0x10,%eax
f0103ff0:	66 a3 8e 72 1c f0    	mov    %ax,0xf01c728e
	SETGATE(idt[6], 1, GD_KT, invalidop_handler, 0);
f0103ff6:	b8 bc 4a 10 f0       	mov    $0xf0104abc,%eax
f0103ffb:	66 a3 90 72 1c f0    	mov    %ax,0xf01c7290
f0104001:	66 c7 05 92 72 1c f0 	movw   $0x8,0xf01c7292
f0104008:	08 00 
f010400a:	c6 05 94 72 1c f0 00 	movb   $0x0,0xf01c7294
f0104011:	c6 05 95 72 1c f0 8f 	movb   $0x8f,0xf01c7295
f0104018:	c1 e8 10             	shr    $0x10,%eax
f010401b:	66 a3 96 72 1c f0    	mov    %ax,0xf01c7296
	SETGATE(idt[7], 1, GD_KT, nomathcopro_handler, 0);
f0104021:	b8 c6 4a 10 f0       	mov    $0xf0104ac6,%eax
f0104026:	66 a3 98 72 1c f0    	mov    %ax,0xf01c7298
f010402c:	66 c7 05 9a 72 1c f0 	movw   $0x8,0xf01c729a
f0104033:	08 00 
f0104035:	c6 05 9c 72 1c f0 00 	movb   $0x0,0xf01c729c
f010403c:	c6 05 9d 72 1c f0 8f 	movb   $0x8f,0xf01c729d
f0104043:	c1 e8 10             	shr    $0x10,%eax
f0104046:	66 a3 9e 72 1c f0    	mov    %ax,0xf01c729e
	SETGATE(idt[8], 1, GD_KT, dbfault_handler, 0);
f010404c:	b8 d0 4a 10 f0       	mov    $0xf0104ad0,%eax
f0104051:	66 a3 a0 72 1c f0    	mov    %ax,0xf01c72a0
f0104057:	66 c7 05 a2 72 1c f0 	movw   $0x8,0xf01c72a2
f010405e:	08 00 
f0104060:	c6 05 a4 72 1c f0 00 	movb   $0x0,0xf01c72a4
f0104067:	c6 05 a5 72 1c f0 8f 	movb   $0x8f,0xf01c72a5
f010406e:	c1 e8 10             	shr    $0x10,%eax
f0104071:	66 a3 a6 72 1c f0    	mov    %ax,0xf01c72a6
	SETGATE(idt[10], 1, GD_KT, invalidTSS_handler, 0);
f0104077:	b8 d8 4a 10 f0       	mov    $0xf0104ad8,%eax
f010407c:	66 a3 b0 72 1c f0    	mov    %ax,0xf01c72b0
f0104082:	66 c7 05 b2 72 1c f0 	movw   $0x8,0xf01c72b2
f0104089:	08 00 
f010408b:	c6 05 b4 72 1c f0 00 	movb   $0x0,0xf01c72b4
f0104092:	c6 05 b5 72 1c f0 8f 	movb   $0x8f,0xf01c72b5
f0104099:	c1 e8 10             	shr    $0x10,%eax
f010409c:	66 a3 b6 72 1c f0    	mov    %ax,0xf01c72b6

	SETGATE(idt[11], 1, GD_KT, sgmtnotpresent_handler, 0);
f01040a2:	b8 e0 4a 10 f0       	mov    $0xf0104ae0,%eax
f01040a7:	66 a3 b8 72 1c f0    	mov    %ax,0xf01c72b8
f01040ad:	66 c7 05 ba 72 1c f0 	movw   $0x8,0xf01c72ba
f01040b4:	08 00 
f01040b6:	c6 05 bc 72 1c f0 00 	movb   $0x0,0xf01c72bc
f01040bd:	c6 05 bd 72 1c f0 8f 	movb   $0x8f,0xf01c72bd
f01040c4:	c1 e8 10             	shr    $0x10,%eax
f01040c7:	66 a3 be 72 1c f0    	mov    %ax,0xf01c72be
	SETGATE(idt[12], 1, GD_KT, stacksgmtfault_handler, 0);
f01040cd:	b8 e8 4a 10 f0       	mov    $0xf0104ae8,%eax
f01040d2:	66 a3 c0 72 1c f0    	mov    %ax,0xf01c72c0
f01040d8:	66 c7 05 c2 72 1c f0 	movw   $0x8,0xf01c72c2
f01040df:	08 00 
f01040e1:	c6 05 c4 72 1c f0 00 	movb   $0x0,0xf01c72c4
f01040e8:	c6 05 c5 72 1c f0 8f 	movb   $0x8f,0xf01c72c5
f01040ef:	c1 e8 10             	shr    $0x10,%eax
f01040f2:	66 a3 c6 72 1c f0    	mov    %ax,0xf01c72c6
	SETGATE(idt[14], 1, GD_KT, pagefault_handler, 0);
f01040f8:	b8 f8 4a 10 f0       	mov    $0xf0104af8,%eax
f01040fd:	66 a3 d0 72 1c f0    	mov    %ax,0xf01c72d0
f0104103:	66 c7 05 d2 72 1c f0 	movw   $0x8,0xf01c72d2
f010410a:	08 00 
f010410c:	c6 05 d4 72 1c f0 00 	movb   $0x0,0xf01c72d4
f0104113:	c6 05 d5 72 1c f0 8f 	movb   $0x8f,0xf01c72d5
f010411a:	c1 e8 10             	shr    $0x10,%eax
f010411d:	66 a3 d6 72 1c f0    	mov    %ax,0xf01c72d6
	SETGATE(idt[13], 1, GD_KT, generalprotection_handler, 0);
f0104123:	b8 f0 4a 10 f0       	mov    $0xf0104af0,%eax
f0104128:	66 a3 c8 72 1c f0    	mov    %ax,0xf01c72c8
f010412e:	66 c7 05 ca 72 1c f0 	movw   $0x8,0xf01c72ca
f0104135:	08 00 
f0104137:	c6 05 cc 72 1c f0 00 	movb   $0x0,0xf01c72cc
f010413e:	c6 05 cd 72 1c f0 8f 	movb   $0x8f,0xf01c72cd
f0104145:	c1 e8 10             	shr    $0x10,%eax
f0104148:	66 a3 ce 72 1c f0    	mov    %ax,0xf01c72ce
	SETGATE(idt[16], 1, GD_KT, FPUerror_handler, 0);
f010414e:	b8 fc 4a 10 f0       	mov    $0xf0104afc,%eax
f0104153:	66 a3 e0 72 1c f0    	mov    %ax,0xf01c72e0
f0104159:	66 c7 05 e2 72 1c f0 	movw   $0x8,0xf01c72e2
f0104160:	08 00 
f0104162:	c6 05 e4 72 1c f0 00 	movb   $0x0,0xf01c72e4
f0104169:	c6 05 e5 72 1c f0 8f 	movb   $0x8f,0xf01c72e5
f0104170:	c1 e8 10             	shr    $0x10,%eax
f0104173:	66 a3 e6 72 1c f0    	mov    %ax,0xf01c72e6
	SETGATE(idt[17], 1, GD_KT, alignmentcheck_handler, 0);
f0104179:	b8 02 4b 10 f0       	mov    $0xf0104b02,%eax
f010417e:	66 a3 e8 72 1c f0    	mov    %ax,0xf01c72e8
f0104184:	66 c7 05 ea 72 1c f0 	movw   $0x8,0xf01c72ea
f010418b:	08 00 
f010418d:	c6 05 ec 72 1c f0 00 	movb   $0x0,0xf01c72ec
f0104194:	c6 05 ed 72 1c f0 8f 	movb   $0x8f,0xf01c72ed
f010419b:	c1 e8 10             	shr    $0x10,%eax
f010419e:	66 a3 ee 72 1c f0    	mov    %ax,0xf01c72ee
	SETGATE(idt[18],1, GD_KT, machinecheck_handler, 0);
f01041a4:	b8 06 4b 10 f0       	mov    $0xf0104b06,%eax
f01041a9:	66 a3 f0 72 1c f0    	mov    %ax,0xf01c72f0
f01041af:	66 c7 05 f2 72 1c f0 	movw   $0x8,0xf01c72f2
f01041b6:	08 00 
f01041b8:	c6 05 f4 72 1c f0 00 	movb   $0x0,0xf01c72f4
f01041bf:	c6 05 f5 72 1c f0 8f 	movb   $0x8f,0xf01c72f5
f01041c6:	c1 e8 10             	shr    $0x10,%eax
f01041c9:	66 a3 f6 72 1c f0    	mov    %ax,0xf01c72f6
	SETGATE(idt[19], 1, GD_KT, SIMDFPexception_handler, 0);
f01041cf:	b8 0c 4b 10 f0       	mov    $0xf0104b0c,%eax
f01041d4:	66 a3 f8 72 1c f0    	mov    %ax,0xf01c72f8
f01041da:	66 c7 05 fa 72 1c f0 	movw   $0x8,0xf01c72fa
f01041e1:	08 00 
f01041e3:	c6 05 fc 72 1c f0 00 	movb   $0x0,0xf01c72fc
f01041ea:	c6 05 fd 72 1c f0 8f 	movb   $0x8f,0xf01c72fd
f01041f1:	c1 e8 10             	shr    $0x10,%eax
f01041f4:	66 a3 fe 72 1c f0    	mov    %ax,0xf01c72fe
	SETGATE(idt[48], 0, GD_KT, systemcall_handler, 3);
f01041fa:	b8 12 4b 10 f0       	mov    $0xf0104b12,%eax
f01041ff:	66 a3 e0 73 1c f0    	mov    %ax,0xf01c73e0
f0104205:	66 c7 05 e2 73 1c f0 	movw   $0x8,0xf01c73e2
f010420c:	08 00 
f010420e:	c6 05 e4 73 1c f0 00 	movb   $0x0,0xf01c73e4
f0104215:	c6 05 e5 73 1c f0 ee 	movb   $0xee,0xf01c73e5
f010421c:	c1 e8 10             	shr    $0x10,%eax
f010421f:	66 a3 e6 73 1c f0    	mov    %ax,0xf01c73e6
	// LAB 3: Your code here.

	SETGATE(idt[IRQ_OFFSET + 0], 0, GD_KT, t_irq0, 0);
f0104225:	b8 18 4b 10 f0       	mov    $0xf0104b18,%eax
f010422a:	66 a3 60 73 1c f0    	mov    %ax,0xf01c7360
f0104230:	66 c7 05 62 73 1c f0 	movw   $0x8,0xf01c7362
f0104237:	08 00 
f0104239:	c6 05 64 73 1c f0 00 	movb   $0x0,0xf01c7364
f0104240:	c6 05 65 73 1c f0 8e 	movb   $0x8e,0xf01c7365
f0104247:	c1 e8 10             	shr    $0x10,%eax
f010424a:	66 a3 66 73 1c f0    	mov    %ax,0xf01c7366
	SETGATE(idt[IRQ_OFFSET + 1], 0, GD_KT, t_irq1, 0);
f0104250:	b8 1e 4b 10 f0       	mov    $0xf0104b1e,%eax
f0104255:	66 a3 68 73 1c f0    	mov    %ax,0xf01c7368
f010425b:	66 c7 05 6a 73 1c f0 	movw   $0x8,0xf01c736a
f0104262:	08 00 
f0104264:	c6 05 6c 73 1c f0 00 	movb   $0x0,0xf01c736c
f010426b:	c6 05 6d 73 1c f0 8e 	movb   $0x8e,0xf01c736d
f0104272:	c1 e8 10             	shr    $0x10,%eax
f0104275:	66 a3 6e 73 1c f0    	mov    %ax,0xf01c736e
	SETGATE(idt[IRQ_OFFSET + 2], 0, GD_KT, t_irq2, 0);
f010427b:	b8 24 4b 10 f0       	mov    $0xf0104b24,%eax
f0104280:	66 a3 70 73 1c f0    	mov    %ax,0xf01c7370
f0104286:	66 c7 05 72 73 1c f0 	movw   $0x8,0xf01c7372
f010428d:	08 00 
f010428f:	c6 05 74 73 1c f0 00 	movb   $0x0,0xf01c7374
f0104296:	c6 05 75 73 1c f0 8e 	movb   $0x8e,0xf01c7375
f010429d:	c1 e8 10             	shr    $0x10,%eax
f01042a0:	66 a3 76 73 1c f0    	mov    %ax,0xf01c7376
	SETGATE(idt[IRQ_OFFSET + 3], 0, GD_KT, t_irq3, 0);
f01042a6:	b8 2a 4b 10 f0       	mov    $0xf0104b2a,%eax
f01042ab:	66 a3 78 73 1c f0    	mov    %ax,0xf01c7378
f01042b1:	66 c7 05 7a 73 1c f0 	movw   $0x8,0xf01c737a
f01042b8:	08 00 
f01042ba:	c6 05 7c 73 1c f0 00 	movb   $0x0,0xf01c737c
f01042c1:	c6 05 7d 73 1c f0 8e 	movb   $0x8e,0xf01c737d
f01042c8:	c1 e8 10             	shr    $0x10,%eax
f01042cb:	66 a3 7e 73 1c f0    	mov    %ax,0xf01c737e
	SETGATE(idt[IRQ_OFFSET + 4], 0, GD_KT, t_irq4, 0);
f01042d1:	b8 30 4b 10 f0       	mov    $0xf0104b30,%eax
f01042d6:	66 a3 80 73 1c f0    	mov    %ax,0xf01c7380
f01042dc:	66 c7 05 82 73 1c f0 	movw   $0x8,0xf01c7382
f01042e3:	08 00 
f01042e5:	c6 05 84 73 1c f0 00 	movb   $0x0,0xf01c7384
f01042ec:	c6 05 85 73 1c f0 8e 	movb   $0x8e,0xf01c7385
f01042f3:	c1 e8 10             	shr    $0x10,%eax
f01042f6:	66 a3 86 73 1c f0    	mov    %ax,0xf01c7386
	SETGATE(idt[IRQ_OFFSET + 5], 0, GD_KT, t_irq5, 0);
f01042fc:	b8 36 4b 10 f0       	mov    $0xf0104b36,%eax
f0104301:	66 a3 88 73 1c f0    	mov    %ax,0xf01c7388
f0104307:	66 c7 05 8a 73 1c f0 	movw   $0x8,0xf01c738a
f010430e:	08 00 
f0104310:	c6 05 8c 73 1c f0 00 	movb   $0x0,0xf01c738c
f0104317:	c6 05 8d 73 1c f0 8e 	movb   $0x8e,0xf01c738d
f010431e:	c1 e8 10             	shr    $0x10,%eax
f0104321:	66 a3 8e 73 1c f0    	mov    %ax,0xf01c738e
	SETGATE(idt[IRQ_OFFSET + 6], 0, GD_KT, t_irq6, 0);
f0104327:	b8 3c 4b 10 f0       	mov    $0xf0104b3c,%eax
f010432c:	66 a3 90 73 1c f0    	mov    %ax,0xf01c7390
f0104332:	66 c7 05 92 73 1c f0 	movw   $0x8,0xf01c7392
f0104339:	08 00 
f010433b:	c6 05 94 73 1c f0 00 	movb   $0x0,0xf01c7394
f0104342:	c6 05 95 73 1c f0 8e 	movb   $0x8e,0xf01c7395
f0104349:	c1 e8 10             	shr    $0x10,%eax
f010434c:	66 a3 96 73 1c f0    	mov    %ax,0xf01c7396
	SETGATE(idt[IRQ_OFFSET + 7], 0, GD_KT, t_irq7, 0);
f0104352:	b8 42 4b 10 f0       	mov    $0xf0104b42,%eax
f0104357:	66 a3 98 73 1c f0    	mov    %ax,0xf01c7398
f010435d:	66 c7 05 9a 73 1c f0 	movw   $0x8,0xf01c739a
f0104364:	08 00 
f0104366:	c6 05 9c 73 1c f0 00 	movb   $0x0,0xf01c739c
f010436d:	c6 05 9d 73 1c f0 8e 	movb   $0x8e,0xf01c739d
f0104374:	c1 e8 10             	shr    $0x10,%eax
f0104377:	66 a3 9e 73 1c f0    	mov    %ax,0xf01c739e
	SETGATE(idt[IRQ_OFFSET + 8], 0, GD_KT, t_irq8, 0);
f010437d:	b8 48 4b 10 f0       	mov    $0xf0104b48,%eax
f0104382:	66 a3 a0 73 1c f0    	mov    %ax,0xf01c73a0
f0104388:	66 c7 05 a2 73 1c f0 	movw   $0x8,0xf01c73a2
f010438f:	08 00 
f0104391:	c6 05 a4 73 1c f0 00 	movb   $0x0,0xf01c73a4
f0104398:	c6 05 a5 73 1c f0 8e 	movb   $0x8e,0xf01c73a5
f010439f:	c1 e8 10             	shr    $0x10,%eax
f01043a2:	66 a3 a6 73 1c f0    	mov    %ax,0xf01c73a6
	SETGATE(idt[IRQ_OFFSET + 9], 0, GD_KT, t_irq9, 0);
f01043a8:	b8 4e 4b 10 f0       	mov    $0xf0104b4e,%eax
f01043ad:	66 a3 a8 73 1c f0    	mov    %ax,0xf01c73a8
f01043b3:	66 c7 05 aa 73 1c f0 	movw   $0x8,0xf01c73aa
f01043ba:	08 00 
f01043bc:	c6 05 ac 73 1c f0 00 	movb   $0x0,0xf01c73ac
f01043c3:	c6 05 ad 73 1c f0 8e 	movb   $0x8e,0xf01c73ad
f01043ca:	c1 e8 10             	shr    $0x10,%eax
f01043cd:	66 a3 ae 73 1c f0    	mov    %ax,0xf01c73ae
	SETGATE(idt[IRQ_OFFSET + 10], 0, GD_KT, t_irq10, 0);
f01043d3:	b8 54 4b 10 f0       	mov    $0xf0104b54,%eax
f01043d8:	66 a3 b0 73 1c f0    	mov    %ax,0xf01c73b0
f01043de:	66 c7 05 b2 73 1c f0 	movw   $0x8,0xf01c73b2
f01043e5:	08 00 
f01043e7:	c6 05 b4 73 1c f0 00 	movb   $0x0,0xf01c73b4
f01043ee:	c6 05 b5 73 1c f0 8e 	movb   $0x8e,0xf01c73b5
f01043f5:	c1 e8 10             	shr    $0x10,%eax
f01043f8:	66 a3 b6 73 1c f0    	mov    %ax,0xf01c73b6
	SETGATE(idt[IRQ_OFFSET + 11], 0, GD_KT, t_irq11, 0);
f01043fe:	b8 5a 4b 10 f0       	mov    $0xf0104b5a,%eax
f0104403:	66 a3 b8 73 1c f0    	mov    %ax,0xf01c73b8
f0104409:	66 c7 05 ba 73 1c f0 	movw   $0x8,0xf01c73ba
f0104410:	08 00 
f0104412:	c6 05 bc 73 1c f0 00 	movb   $0x0,0xf01c73bc
f0104419:	c6 05 bd 73 1c f0 8e 	movb   $0x8e,0xf01c73bd
f0104420:	c1 e8 10             	shr    $0x10,%eax
f0104423:	66 a3 be 73 1c f0    	mov    %ax,0xf01c73be
	SETGATE(idt[IRQ_OFFSET + 12], 0, GD_KT, t_irq12, 0);
f0104429:	b8 60 4b 10 f0       	mov    $0xf0104b60,%eax
f010442e:	66 a3 c0 73 1c f0    	mov    %ax,0xf01c73c0
f0104434:	66 c7 05 c2 73 1c f0 	movw   $0x8,0xf01c73c2
f010443b:	08 00 
f010443d:	c6 05 c4 73 1c f0 00 	movb   $0x0,0xf01c73c4
f0104444:	c6 05 c5 73 1c f0 8e 	movb   $0x8e,0xf01c73c5
f010444b:	c1 e8 10             	shr    $0x10,%eax
f010444e:	66 a3 c6 73 1c f0    	mov    %ax,0xf01c73c6
	SETGATE(idt[IRQ_OFFSET + 13], 0, GD_KT, t_irq13, 0);
f0104454:	b8 66 4b 10 f0       	mov    $0xf0104b66,%eax
f0104459:	66 a3 c8 73 1c f0    	mov    %ax,0xf01c73c8
f010445f:	66 c7 05 ca 73 1c f0 	movw   $0x8,0xf01c73ca
f0104466:	08 00 
f0104468:	c6 05 cc 73 1c f0 00 	movb   $0x0,0xf01c73cc
f010446f:	c6 05 cd 73 1c f0 8e 	movb   $0x8e,0xf01c73cd
f0104476:	c1 e8 10             	shr    $0x10,%eax
f0104479:	66 a3 ce 73 1c f0    	mov    %ax,0xf01c73ce
	SETGATE(idt[IRQ_OFFSET + 14], 0, GD_KT, t_irq14, 0);
f010447f:	b8 6c 4b 10 f0       	mov    $0xf0104b6c,%eax
f0104484:	66 a3 d0 73 1c f0    	mov    %ax,0xf01c73d0
f010448a:	66 c7 05 d2 73 1c f0 	movw   $0x8,0xf01c73d2
f0104491:	08 00 
f0104493:	c6 05 d4 73 1c f0 00 	movb   $0x0,0xf01c73d4
f010449a:	c6 05 d5 73 1c f0 8e 	movb   $0x8e,0xf01c73d5
f01044a1:	c1 e8 10             	shr    $0x10,%eax
f01044a4:	66 a3 d6 73 1c f0    	mov    %ax,0xf01c73d6
	SETGATE(idt[IRQ_OFFSET + 15], 0, GD_KT, t_irq15, 0);
f01044aa:	b8 72 4b 10 f0       	mov    $0xf0104b72,%eax
f01044af:	66 a3 d8 73 1c f0    	mov    %ax,0xf01c73d8
f01044b5:	66 c7 05 da 73 1c f0 	movw   $0x8,0xf01c73da
f01044bc:	08 00 
f01044be:	c6 05 dc 73 1c f0 00 	movb   $0x0,0xf01c73dc
f01044c5:	c6 05 dd 73 1c f0 8e 	movb   $0x8e,0xf01c73dd
f01044cc:	c1 e8 10             	shr    $0x10,%eax
f01044cf:	66 a3 de 73 1c f0    	mov    %ax,0xf01c73de
	// Per-CPU setup 
	trap_init_percpu();
f01044d5:	e8 b6 f9 ff ff       	call   f0103e90 <trap_init_percpu>
}
f01044da:	c9                   	leave  
f01044db:	c3                   	ret    

f01044dc <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f01044dc:	55                   	push   %ebp
f01044dd:	89 e5                	mov    %esp,%ebp
f01044df:	53                   	push   %ebx
f01044e0:	83 ec 14             	sub    $0x14,%esp
f01044e3:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f01044e6:	8b 03                	mov    (%ebx),%eax
f01044e8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01044ec:	c7 04 24 5a 7d 10 f0 	movl   $0xf0107d5a,(%esp)
f01044f3:	e8 7e f9 ff ff       	call   f0103e76 <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f01044f8:	8b 43 04             	mov    0x4(%ebx),%eax
f01044fb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01044ff:	c7 04 24 69 7d 10 f0 	movl   $0xf0107d69,(%esp)
f0104506:	e8 6b f9 ff ff       	call   f0103e76 <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f010450b:	8b 43 08             	mov    0x8(%ebx),%eax
f010450e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104512:	c7 04 24 78 7d 10 f0 	movl   $0xf0107d78,(%esp)
f0104519:	e8 58 f9 ff ff       	call   f0103e76 <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f010451e:	8b 43 0c             	mov    0xc(%ebx),%eax
f0104521:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104525:	c7 04 24 87 7d 10 f0 	movl   $0xf0107d87,(%esp)
f010452c:	e8 45 f9 ff ff       	call   f0103e76 <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f0104531:	8b 43 10             	mov    0x10(%ebx),%eax
f0104534:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104538:	c7 04 24 96 7d 10 f0 	movl   $0xf0107d96,(%esp)
f010453f:	e8 32 f9 ff ff       	call   f0103e76 <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0104544:	8b 43 14             	mov    0x14(%ebx),%eax
f0104547:	89 44 24 04          	mov    %eax,0x4(%esp)
f010454b:	c7 04 24 a5 7d 10 f0 	movl   $0xf0107da5,(%esp)
f0104552:	e8 1f f9 ff ff       	call   f0103e76 <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f0104557:	8b 43 18             	mov    0x18(%ebx),%eax
f010455a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010455e:	c7 04 24 b4 7d 10 f0 	movl   $0xf0107db4,(%esp)
f0104565:	e8 0c f9 ff ff       	call   f0103e76 <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f010456a:	8b 43 1c             	mov    0x1c(%ebx),%eax
f010456d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104571:	c7 04 24 c3 7d 10 f0 	movl   $0xf0107dc3,(%esp)
f0104578:	e8 f9 f8 ff ff       	call   f0103e76 <cprintf>
}
f010457d:	83 c4 14             	add    $0x14,%esp
f0104580:	5b                   	pop    %ebx
f0104581:	5d                   	pop    %ebp
f0104582:	c3                   	ret    

f0104583 <print_trapframe>:
	lidt(&idt_pd);*/
}

void
print_trapframe(struct Trapframe *tf)
{
f0104583:	55                   	push   %ebp
f0104584:	89 e5                	mov    %esp,%ebp
f0104586:	56                   	push   %esi
f0104587:	53                   	push   %ebx
f0104588:	83 ec 10             	sub    $0x10,%esp
f010458b:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
f010458e:	e8 f0 1f 00 00       	call   f0106583 <cpunum>
f0104593:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104597:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010459b:	c7 04 24 27 7e 10 f0 	movl   $0xf0107e27,(%esp)
f01045a2:	e8 cf f8 ff ff       	call   f0103e76 <cprintf>
	print_regs(&tf->tf_regs);
f01045a7:	89 1c 24             	mov    %ebx,(%esp)
f01045aa:	e8 2d ff ff ff       	call   f01044dc <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f01045af:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f01045b3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01045b7:	c7 04 24 45 7e 10 f0 	movl   $0xf0107e45,(%esp)
f01045be:	e8 b3 f8 ff ff       	call   f0103e76 <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f01045c3:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f01045c7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01045cb:	c7 04 24 58 7e 10 f0 	movl   $0xf0107e58,(%esp)
f01045d2:	e8 9f f8 ff ff       	call   f0103e76 <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f01045d7:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f01045da:	83 f8 13             	cmp    $0x13,%eax
f01045dd:	77 09                	ja     f01045e8 <print_trapframe+0x65>
		return excnames[trapno];
f01045df:	8b 14 85 e0 80 10 f0 	mov    -0xfef7f20(,%eax,4),%edx
f01045e6:	eb 1f                	jmp    f0104607 <print_trapframe+0x84>
	if (trapno == T_SYSCALL)
f01045e8:	83 f8 30             	cmp    $0x30,%eax
f01045eb:	74 15                	je     f0104602 <print_trapframe+0x7f>
		return "System call";
	if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16)
f01045ed:	8d 50 e0             	lea    -0x20(%eax),%edx
		return "Hardware Interrupt";
f01045f0:	83 fa 0f             	cmp    $0xf,%edx
f01045f3:	ba de 7d 10 f0       	mov    $0xf0107dde,%edx
f01045f8:	b9 f1 7d 10 f0       	mov    $0xf0107df1,%ecx
f01045fd:	0f 47 d1             	cmova  %ecx,%edx
f0104600:	eb 05                	jmp    f0104607 <print_trapframe+0x84>
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
		return excnames[trapno];
	if (trapno == T_SYSCALL)
		return "System call";
f0104602:	ba d2 7d 10 f0       	mov    $0xf0107dd2,%edx
{
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0104607:	89 54 24 08          	mov    %edx,0x8(%esp)
f010460b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010460f:	c7 04 24 6b 7e 10 f0 	movl   $0xf0107e6b,(%esp)
f0104616:	e8 5b f8 ff ff       	call   f0103e76 <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f010461b:	3b 1d 60 7a 1c f0    	cmp    0xf01c7a60,%ebx
f0104621:	75 19                	jne    f010463c <print_trapframe+0xb9>
f0104623:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104627:	75 13                	jne    f010463c <print_trapframe+0xb9>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f0104629:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f010462c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104630:	c7 04 24 7d 7e 10 f0 	movl   $0xf0107e7d,(%esp)
f0104637:	e8 3a f8 ff ff       	call   f0103e76 <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f010463c:	8b 43 2c             	mov    0x2c(%ebx),%eax
f010463f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104643:	c7 04 24 8c 7e 10 f0 	movl   $0xf0107e8c,(%esp)
f010464a:	e8 27 f8 ff ff       	call   f0103e76 <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f010464f:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104653:	75 51                	jne    f01046a6 <print_trapframe+0x123>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f0104655:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f0104658:	89 c2                	mov    %eax,%edx
f010465a:	83 e2 01             	and    $0x1,%edx
f010465d:	ba 00 7e 10 f0       	mov    $0xf0107e00,%edx
f0104662:	b9 0b 7e 10 f0       	mov    $0xf0107e0b,%ecx
f0104667:	0f 45 ca             	cmovne %edx,%ecx
f010466a:	89 c2                	mov    %eax,%edx
f010466c:	83 e2 02             	and    $0x2,%edx
f010466f:	ba 17 7e 10 f0       	mov    $0xf0107e17,%edx
f0104674:	be 1d 7e 10 f0       	mov    $0xf0107e1d,%esi
f0104679:	0f 44 d6             	cmove  %esi,%edx
f010467c:	83 e0 04             	and    $0x4,%eax
f010467f:	b8 22 7e 10 f0       	mov    $0xf0107e22,%eax
f0104684:	be 3e 7f 10 f0       	mov    $0xf0107f3e,%esi
f0104689:	0f 44 c6             	cmove  %esi,%eax
f010468c:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0104690:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104694:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104698:	c7 04 24 9a 7e 10 f0 	movl   $0xf0107e9a,(%esp)
f010469f:	e8 d2 f7 ff ff       	call   f0103e76 <cprintf>
f01046a4:	eb 0c                	jmp    f01046b2 <print_trapframe+0x12f>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f01046a6:	c7 04 24 38 7d 10 f0 	movl   $0xf0107d38,(%esp)
f01046ad:	e8 c4 f7 ff ff       	call   f0103e76 <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f01046b2:	8b 43 30             	mov    0x30(%ebx),%eax
f01046b5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046b9:	c7 04 24 a9 7e 10 f0 	movl   $0xf0107ea9,(%esp)
f01046c0:	e8 b1 f7 ff ff       	call   f0103e76 <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f01046c5:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f01046c9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046cd:	c7 04 24 b8 7e 10 f0 	movl   $0xf0107eb8,(%esp)
f01046d4:	e8 9d f7 ff ff       	call   f0103e76 <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f01046d9:	8b 43 38             	mov    0x38(%ebx),%eax
f01046dc:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046e0:	c7 04 24 cb 7e 10 f0 	movl   $0xf0107ecb,(%esp)
f01046e7:	e8 8a f7 ff ff       	call   f0103e76 <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f01046ec:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f01046f0:	74 27                	je     f0104719 <print_trapframe+0x196>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f01046f2:	8b 43 3c             	mov    0x3c(%ebx),%eax
f01046f5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046f9:	c7 04 24 da 7e 10 f0 	movl   $0xf0107eda,(%esp)
f0104700:	e8 71 f7 ff ff       	call   f0103e76 <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f0104705:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f0104709:	89 44 24 04          	mov    %eax,0x4(%esp)
f010470d:	c7 04 24 e9 7e 10 f0 	movl   $0xf0107ee9,(%esp)
f0104714:	e8 5d f7 ff ff       	call   f0103e76 <cprintf>
	}
}
f0104719:	83 c4 10             	add    $0x10,%esp
f010471c:	5b                   	pop    %ebx
f010471d:	5e                   	pop    %esi
f010471e:	5d                   	pop    %ebp
f010471f:	c3                   	ret    

f0104720 <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f0104720:	55                   	push   %ebp
f0104721:	89 e5                	mov    %esp,%ebp
f0104723:	57                   	push   %edi
f0104724:	56                   	push   %esi
f0104725:	53                   	push   %ebx
f0104726:	83 ec 2c             	sub    $0x2c,%esp
f0104729:	8b 5d 08             	mov    0x8(%ebp),%ebx
f010472c:	0f 20 d0             	mov    %cr2,%eax
f010472f:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	uint32_t fault_va;

	// Read processor's CR2 register to find the faulting address
	fault_va = rcr2();
	if((tf->tf_cs & 0x3) != 3)
f0104732:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f0104736:	83 e0 03             	and    $0x3,%eax
f0104739:	66 83 f8 03          	cmp    $0x3,%ax
f010473d:	74 1c                	je     f010475b <page_fault_handler+0x3b>
		panic("page_fault_handler(): page fault at kernel-mode !");
f010473f:	c7 44 24 08 88 80 10 	movl   $0xf0108088,0x8(%esp)
f0104746:	f0 
f0104747:	c7 44 24 04 78 01 00 	movl   $0x178,0x4(%esp)
f010474e:	00 
f010474f:	c7 04 24 fc 7e 10 f0 	movl   $0xf0107efc,(%esp)
f0104756:	e8 e5 b8 ff ff       	call   f0100040 <_panic>
	//   user_mem_assert() and env_run() are useful here.
	//   To change what the user environment runs, modify 'curenv->env_tf'
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.
	if(curenv->env_pgfault_upcall == NULL){
f010475b:	e8 23 1e 00 00       	call   f0106583 <cpunum>
f0104760:	6b c0 74             	imul   $0x74,%eax,%eax
f0104763:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104769:	83 78 64 00          	cmpl   $0x0,0x64(%eax)
f010476d:	75 4d                	jne    f01047bc <page_fault_handler+0x9c>
		// Destroy the environment that caused the fault.
		cprintf("[%08x] user fault va %08x ip %08x\n",
f010476f:	8b 73 30             	mov    0x30(%ebx),%esi
		curenv->env_id, fault_va, tf->tf_eip);
f0104772:	e8 0c 1e 00 00       	call   f0106583 <cpunum>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.
	if(curenv->env_pgfault_upcall == NULL){
		// Destroy the environment that caused the fault.
		cprintf("[%08x] user fault va %08x ip %08x\n",
f0104777:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010477b:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f010477e:	89 7c 24 08          	mov    %edi,0x8(%esp)
		curenv->env_id, fault_va, tf->tf_eip);
f0104782:	6b c0 74             	imul   $0x74,%eax,%eax
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.
	if(curenv->env_pgfault_upcall == NULL){
		// Destroy the environment that caused the fault.
		cprintf("[%08x] user fault va %08x ip %08x\n",
f0104785:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f010478b:	8b 40 48             	mov    0x48(%eax),%eax
f010478e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104792:	c7 04 24 bc 80 10 f0 	movl   $0xf01080bc,(%esp)
f0104799:	e8 d8 f6 ff ff       	call   f0103e76 <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
		print_trapframe(tf);
f010479e:	89 1c 24             	mov    %ebx,(%esp)
f01047a1:	e8 dd fd ff ff       	call   f0104583 <print_trapframe>
		env_destroy(curenv);
f01047a6:	e8 d8 1d 00 00       	call   f0106583 <cpunum>
f01047ab:	6b c0 74             	imul   $0x74,%eax,%eax
f01047ae:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f01047b4:	89 04 24             	mov    %eax,(%esp)
f01047b7:	e8 08 f4 ff ff       	call   f0103bc4 <env_destroy>
	}

	struct UTrapframe* utf;
	if(UXSTACKTOP - PGSIZE <= tf->tf_esp && tf->tf_esp < UXSTACKTOP) // an page_fault from user exception stack
f01047bc:	8b 43 3c             	mov    0x3c(%ebx),%eax
f01047bf:	8d 90 00 10 40 11    	lea    0x11401000(%eax),%edx
	{
		utf = (struct UTrapframe*) (tf->tf_esp - sizeof (struct UTrapframe) - sizeof(uint32_t));
f01047c5:	83 e8 38             	sub    $0x38,%eax
f01047c8:	81 fa ff 0f 00 00    	cmp    $0xfff,%edx
f01047ce:	ba cc ff bf ee       	mov    $0xeebfffcc,%edx
f01047d3:	0f 46 d0             	cmovbe %eax,%edx
f01047d6:	89 d6                	mov    %edx,%esi
f01047d8:	89 55 e0             	mov    %edx,-0x20(%ebp)
	}
	else // an page_fault from normal user space
	{
		utf = (struct UTrapframe*) (UXSTACKTOP - sizeof(struct UTrapframe));
	}
	user_mem_assert(curenv, (void*) utf, sizeof (struct UTrapframe), PTE_U | PTE_W);
f01047db:	e8 a3 1d 00 00       	call   f0106583 <cpunum>
f01047e0:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01047e7:	00 
f01047e8:	c7 44 24 08 34 00 00 	movl   $0x34,0x8(%esp)
f01047ef:	00 
f01047f0:	89 74 24 04          	mov    %esi,0x4(%esp)
f01047f4:	6b c0 74             	imul   $0x74,%eax,%eax
f01047f7:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f01047fd:	89 04 24             	mov    %eax,(%esp)
f0104800:	e8 fb ec ff ff       	call   f0103500 <user_mem_assert>
	
	// setup a stack
	utf->utf_eflags = tf->tf_eflags;
f0104805:	8b 43 38             	mov    0x38(%ebx),%eax
f0104808:	89 46 2c             	mov    %eax,0x2c(%esi)
	utf->utf_eip = tf->tf_eip;
f010480b:	8b 43 30             	mov    0x30(%ebx),%eax
f010480e:	89 46 28             	mov    %eax,0x28(%esi)
	utf->utf_esp = tf->tf_esp;
f0104811:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0104814:	89 46 30             	mov    %eax,0x30(%esi)
	utf->utf_regs = tf->tf_regs;
f0104817:	8d 7e 08             	lea    0x8(%esi),%edi
f010481a:	89 de                	mov    %ebx,%esi
f010481c:	b8 20 00 00 00       	mov    $0x20,%eax
f0104821:	f7 c7 01 00 00 00    	test   $0x1,%edi
f0104827:	74 03                	je     f010482c <page_fault_handler+0x10c>
f0104829:	a4                   	movsb  %ds:(%esi),%es:(%edi)
f010482a:	b0 1f                	mov    $0x1f,%al
f010482c:	f7 c7 02 00 00 00    	test   $0x2,%edi
f0104832:	74 05                	je     f0104839 <page_fault_handler+0x119>
f0104834:	66 a5                	movsw  %ds:(%esi),%es:(%edi)
f0104836:	83 e8 02             	sub    $0x2,%eax
f0104839:	89 c1                	mov    %eax,%ecx
f010483b:	c1 e9 02             	shr    $0x2,%ecx
f010483e:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0104840:	ba 00 00 00 00       	mov    $0x0,%edx
f0104845:	a8 02                	test   $0x2,%al
f0104847:	74 0b                	je     f0104854 <page_fault_handler+0x134>
f0104849:	0f b7 16             	movzwl (%esi),%edx
f010484c:	66 89 17             	mov    %dx,(%edi)
f010484f:	ba 02 00 00 00       	mov    $0x2,%edx
f0104854:	a8 01                	test   $0x1,%al
f0104856:	74 07                	je     f010485f <page_fault_handler+0x13f>
f0104858:	0f b6 04 16          	movzbl (%esi,%edx,1),%eax
f010485c:	88 04 17             	mov    %al,(%edi,%edx,1)
	utf->utf_err = tf->tf_err;
f010485f:	8b 43 2c             	mov    0x2c(%ebx),%eax
f0104862:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0104865:	89 47 04             	mov    %eax,0x4(%edi)
	utf->utf_fault_va = fault_va;
f0104868:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010486b:	89 07                	mov    %eax,(%edi)

	curenv->env_tf.tf_eip = (uint32_t)curenv->env_pgfault_upcall;
f010486d:	e8 11 1d 00 00       	call   f0106583 <cpunum>
f0104872:	6b c0 74             	imul   $0x74,%eax,%eax
f0104875:	8b 98 28 80 1c f0    	mov    -0xfe37fd8(%eax),%ebx
f010487b:	e8 03 1d 00 00       	call   f0106583 <cpunum>
f0104880:	6b c0 74             	imul   $0x74,%eax,%eax
f0104883:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104889:	8b 40 64             	mov    0x64(%eax),%eax
f010488c:	89 43 30             	mov    %eax,0x30(%ebx)
	curenv->env_tf.tf_esp = (uint32_t)utf;
f010488f:	e8 ef 1c 00 00       	call   f0106583 <cpunum>
f0104894:	6b c0 74             	imul   $0x74,%eax,%eax
f0104897:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f010489d:	89 78 3c             	mov    %edi,0x3c(%eax)

	env_run(curenv);
f01048a0:	e8 de 1c 00 00       	call   f0106583 <cpunum>
f01048a5:	6b c0 74             	imul   $0x74,%eax,%eax
f01048a8:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f01048ae:	89 04 24             	mov    %eax,(%esp)
f01048b1:	e8 af f3 ff ff       	call   f0103c65 <env_run>

f01048b6 <trap>:



void
trap(struct Trapframe *tf)
{
f01048b6:	55                   	push   %ebp
f01048b7:	89 e5                	mov    %esp,%ebp
f01048b9:	57                   	push   %edi
f01048ba:	56                   	push   %esi
f01048bb:	83 ec 20             	sub    $0x20,%esp
f01048be:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f01048c1:	fc                   	cld    

	// Halt the CPU if some other CPU has called panic()
	extern char *panicstr;
	if (panicstr)
f01048c2:	83 3d 80 7e 1c f0 00 	cmpl   $0x0,0xf01c7e80
f01048c9:	74 01                	je     f01048cc <trap+0x16>
		asm volatile("hlt");
f01048cb:	f4                   	hlt    
	// the interrupt path.
	//assert(!(read_eflags() & FL_IF));
	
	//cprintf("Incoming TRAP frame at %p\n", tf);

	if ((tf->tf_cs & 3) == 3) {
f01048cc:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f01048d0:	83 e0 03             	and    $0x3,%eax
f01048d3:	66 83 f8 03          	cmp    $0x3,%ax
f01048d7:	0f 85 a7 00 00 00    	jne    f0104984 <trap+0xce>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f01048dd:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f01048e4:	e8 00 1f 00 00       	call   f01067e9 <spin_lock>
		// serious kernel work.
		// LAB 4: Your code here.
		//if(tf->tf_cs!=GD_KT){
		lock_kernel();
		//}
		assert(curenv);
f01048e9:	e8 95 1c 00 00       	call   f0106583 <cpunum>
f01048ee:	6b c0 74             	imul   $0x74,%eax,%eax
f01048f1:	83 b8 28 80 1c f0 00 	cmpl   $0x0,-0xfe37fd8(%eax)
f01048f8:	75 24                	jne    f010491e <trap+0x68>
f01048fa:	c7 44 24 0c 08 7f 10 	movl   $0xf0107f08,0xc(%esp)
f0104901:	f0 
f0104902:	c7 44 24 08 f3 79 10 	movl   $0xf01079f3,0x8(%esp)
f0104909:	f0 
f010490a:	c7 44 24 04 4e 01 00 	movl   $0x14e,0x4(%esp)
f0104911:	00 
f0104912:	c7 04 24 fc 7e 10 f0 	movl   $0xf0107efc,(%esp)
f0104919:	e8 22 b7 ff ff       	call   f0100040 <_panic>

		// Garbage collect if current enviroment is a zombie
		if (curenv->env_status == ENV_DYING) {
f010491e:	e8 60 1c 00 00       	call   f0106583 <cpunum>
f0104923:	6b c0 74             	imul   $0x74,%eax,%eax
f0104926:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f010492c:	83 78 54 01          	cmpl   $0x1,0x54(%eax)
f0104930:	75 2d                	jne    f010495f <trap+0xa9>
			env_free(curenv);
f0104932:	e8 4c 1c 00 00       	call   f0106583 <cpunum>
f0104937:	6b c0 74             	imul   $0x74,%eax,%eax
f010493a:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104940:	89 04 24             	mov    %eax,(%esp)
f0104943:	e8 b1 f0 ff ff       	call   f01039f9 <env_free>
			curenv = NULL;
f0104948:	e8 36 1c 00 00       	call   f0106583 <cpunum>
f010494d:	6b c0 74             	imul   $0x74,%eax,%eax
f0104950:	c7 80 28 80 1c f0 00 	movl   $0x0,-0xfe37fd8(%eax)
f0104957:	00 00 00 
			sched_yield();
f010495a:	e8 41 02 00 00       	call   f0104ba0 <sched_yield>
		}

		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		curenv->env_tf = *tf;
f010495f:	e8 1f 1c 00 00       	call   f0106583 <cpunum>
f0104964:	6b c0 74             	imul   $0x74,%eax,%eax
f0104967:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f010496d:	b9 11 00 00 00       	mov    $0x11,%ecx
f0104972:	89 c7                	mov    %eax,%edi
f0104974:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f0104976:	e8 08 1c 00 00       	call   f0106583 <cpunum>
f010497b:	6b c0 74             	imul   $0x74,%eax,%eax
f010497e:	8b b0 28 80 1c f0    	mov    -0xfe37fd8(%eax),%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f0104984:	89 35 60 7a 1c f0    	mov    %esi,0xf01c7a60
	// LAB 3: Your code here.

	// Handle spurious interrupts
	// The hardware sometimes raises these because of noise on the
	// IRQ line or other reasons. We don't care.
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_SPURIOUS) {
f010498a:	8b 46 28             	mov    0x28(%esi),%eax
f010498d:	83 f8 27             	cmp    $0x27,%eax
f0104990:	75 19                	jne    f01049ab <trap+0xf5>
		cprintf("Spurious interrupt on irq 7\n");
f0104992:	c7 04 24 0f 7f 10 f0 	movl   $0xf0107f0f,(%esp)
f0104999:	e8 d8 f4 ff ff       	call   f0103e76 <cprintf>
		print_trapframe(tf);
f010499e:	89 34 24             	mov    %esi,(%esp)
f01049a1:	e8 dd fb ff ff       	call   f0104583 <print_trapframe>
f01049a6:	e9 9e 00 00 00       	jmp    f0104a49 <trap+0x193>
		return;
	}
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_TIMER) {
f01049ab:	83 f8 20             	cmp    $0x20,%eax
f01049ae:	66 90                	xchg   %ax,%ax
f01049b0:	75 0a                	jne    f01049bc <trap+0x106>
        		lapic_eoi();
f01049b2:	e8 01 1d 00 00       	call   f01066b8 <lapic_eoi>
        		sched_yield();
f01049b7:	e8 e4 01 00 00       	call   f0104ba0 <sched_yield>
  	  }
	// Handle clock interrupts. Don't forget to acknowledge the
	// interrupt using lapic_eoi() before calling the scheduler!
	// LAB 4: Your code here.

	if(tf->tf_trapno==T_PGFLT)
f01049bc:	83 f8 0e             	cmp    $0xe,%eax
f01049bf:	90                   	nop
f01049c0:	75 08                	jne    f01049ca <trap+0x114>
	{
		page_fault_handler(tf);
f01049c2:	89 34 24             	mov    %esi,(%esp)
f01049c5:	e8 56 fd ff ff       	call   f0104720 <page_fault_handler>
		return;
	}
	if(tf->tf_trapno==T_BRKPT)
f01049ca:	83 f8 03             	cmp    $0x3,%eax
f01049cd:	75 0a                	jne    f01049d9 <trap+0x123>
	{
		monitor(tf);
f01049cf:	89 34 24             	mov    %esi,(%esp)
f01049d2:	e8 2b c0 ff ff       	call   f0100a02 <monitor>
f01049d7:	eb 70                	jmp    f0104a49 <trap+0x193>
		return;
	}
	if(tf->tf_trapno==T_SYSCALL)
f01049d9:	83 f8 30             	cmp    $0x30,%eax
f01049dc:	75 32                	jne    f0104a10 <trap+0x15a>
	{
		tf->tf_regs.reg_eax=syscall(tf->tf_regs.reg_eax,tf->tf_regs.reg_edx,tf->tf_regs.reg_ecx,tf->tf_regs.reg_ebx,tf->tf_regs.reg_edi,tf->tf_regs.reg_esi);
f01049de:	8b 46 04             	mov    0x4(%esi),%eax
f01049e1:	89 44 24 14          	mov    %eax,0x14(%esp)
f01049e5:	8b 06                	mov    (%esi),%eax
f01049e7:	89 44 24 10          	mov    %eax,0x10(%esp)
f01049eb:	8b 46 10             	mov    0x10(%esi),%eax
f01049ee:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01049f2:	8b 46 18             	mov    0x18(%esi),%eax
f01049f5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01049f9:	8b 46 14             	mov    0x14(%esi),%eax
f01049fc:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104a00:	8b 46 1c             	mov    0x1c(%esi),%eax
f0104a03:	89 04 24             	mov    %eax,(%esp)
f0104a06:	e8 b5 02 00 00       	call   f0104cc0 <syscall>
f0104a0b:	89 46 1c             	mov    %eax,0x1c(%esi)
f0104a0e:	eb 39                	jmp    f0104a49 <trap+0x193>
	    return;
	}
	// Unexpected trap: The user process or the kernel has a bug.

	if (tf->tf_cs == GD_KT)
f0104a10:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f0104a15:	75 1c                	jne    f0104a33 <trap+0x17d>
		panic("unhandled trap in kernel");
f0104a17:	c7 44 24 08 2c 7f 10 	movl   $0xf0107f2c,0x8(%esp)
f0104a1e:	f0 
f0104a1f:	c7 44 24 04 2a 01 00 	movl   $0x12a,0x4(%esp)
f0104a26:	00 
f0104a27:	c7 04 24 fc 7e 10 f0 	movl   $0xf0107efc,(%esp)
f0104a2e:	e8 0d b6 ff ff       	call   f0100040 <_panic>
	else {
		env_destroy(curenv);
f0104a33:	e8 4b 1b 00 00       	call   f0106583 <cpunum>
f0104a38:	6b c0 74             	imul   $0x74,%eax,%eax
f0104a3b:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104a41:	89 04 24             	mov    %eax,(%esp)
f0104a44:	e8 7b f1 ff ff       	call   f0103bc4 <env_destroy>
	trap_dispatch(tf);

	// If we made it to this point, then no other environment was
	// scheduled, so we should return to the current environment
	// if doing so makes sense.
	if (curenv && curenv->env_status == ENV_RUNNING)
f0104a49:	e8 35 1b 00 00       	call   f0106583 <cpunum>
f0104a4e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104a51:	83 b8 28 80 1c f0 00 	cmpl   $0x0,-0xfe37fd8(%eax)
f0104a58:	74 2a                	je     f0104a84 <trap+0x1ce>
f0104a5a:	e8 24 1b 00 00       	call   f0106583 <cpunum>
f0104a5f:	6b c0 74             	imul   $0x74,%eax,%eax
f0104a62:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104a68:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0104a6c:	75 16                	jne    f0104a84 <trap+0x1ce>
		env_run(curenv);
f0104a6e:	e8 10 1b 00 00       	call   f0106583 <cpunum>
f0104a73:	6b c0 74             	imul   $0x74,%eax,%eax
f0104a76:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104a7c:	89 04 24             	mov    %eax,(%esp)
f0104a7f:	e8 e1 f1 ff ff       	call   f0103c65 <env_run>
	else
		sched_yield();
f0104a84:	e8 17 01 00 00       	call   f0104ba0 <sched_yield>
f0104a89:	90                   	nop

f0104a8a <dividezero_handler>:
.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
f0104a8a:	6a 00                	push   $0x0
f0104a8c:	6a 00                	push   $0x0
f0104a8e:	e9 e5 00 00 00       	jmp    f0104b78 <_alltraps>
f0104a93:	90                   	nop

f0104a94 <nmi_handler>:
TRAPHANDLER_NOEC(nmi_handler, 0x2)
f0104a94:	6a 00                	push   $0x0
f0104a96:	6a 02                	push   $0x2
f0104a98:	e9 db 00 00 00       	jmp    f0104b78 <_alltraps>
f0104a9d:	90                   	nop

f0104a9e <breakpoint_handler>:
TRAPHANDLER_NOEC(breakpoint_handler, 0x3)
f0104a9e:	6a 00                	push   $0x0
f0104aa0:	6a 03                	push   $0x3
f0104aa2:	e9 d1 00 00 00       	jmp    f0104b78 <_alltraps>
f0104aa7:	90                   	nop

f0104aa8 <overflow_handler>:
TRAPHANDLER_NOEC(overflow_handler, 0x4)
f0104aa8:	6a 00                	push   $0x0
f0104aaa:	6a 04                	push   $0x4
f0104aac:	e9 c7 00 00 00       	jmp    f0104b78 <_alltraps>
f0104ab1:	90                   	nop

f0104ab2 <bdrgeexceed_handler>:
TRAPHANDLER_NOEC(bdrgeexceed_handler, 0x5)
f0104ab2:	6a 00                	push   $0x0
f0104ab4:	6a 05                	push   $0x5
f0104ab6:	e9 bd 00 00 00       	jmp    f0104b78 <_alltraps>
f0104abb:	90                   	nop

f0104abc <invalidop_handler>:
TRAPHANDLER_NOEC(invalidop_handler, 0x6)
f0104abc:	6a 00                	push   $0x0
f0104abe:	6a 06                	push   $0x6
f0104ac0:	e9 b3 00 00 00       	jmp    f0104b78 <_alltraps>
f0104ac5:	90                   	nop

f0104ac6 <nomathcopro_handler>:
TRAPHANDLER_NOEC(nomathcopro_handler, 0x7)
f0104ac6:	6a 00                	push   $0x0
f0104ac8:	6a 07                	push   $0x7
f0104aca:	e9 a9 00 00 00       	jmp    f0104b78 <_alltraps>
f0104acf:	90                   	nop

f0104ad0 <dbfault_handler>:
TRAPHANDLER(dbfault_handler, 0x8)
f0104ad0:	6a 08                	push   $0x8
f0104ad2:	e9 a1 00 00 00       	jmp    f0104b78 <_alltraps>
f0104ad7:	90                   	nop

f0104ad8 <invalidTSS_handler>:
TRAPHANDLER(invalidTSS_handler, 0xA)
f0104ad8:	6a 0a                	push   $0xa
f0104ada:	e9 99 00 00 00       	jmp    f0104b78 <_alltraps>
f0104adf:	90                   	nop

f0104ae0 <sgmtnotpresent_handler>:
TRAPHANDLER(sgmtnotpresent_handler, 0xB)
f0104ae0:	6a 0b                	push   $0xb
f0104ae2:	e9 91 00 00 00       	jmp    f0104b78 <_alltraps>
f0104ae7:	90                   	nop

f0104ae8 <stacksgmtfault_handler>:
TRAPHANDLER(stacksgmtfault_handler,0xC)
f0104ae8:	6a 0c                	push   $0xc
f0104aea:	e9 89 00 00 00       	jmp    f0104b78 <_alltraps>
f0104aef:	90                   	nop

f0104af0 <generalprotection_handler>:
TRAPHANDLER(generalprotection_handler, 0xD)
f0104af0:	6a 0d                	push   $0xd
f0104af2:	e9 81 00 00 00       	jmp    f0104b78 <_alltraps>
f0104af7:	90                   	nop

f0104af8 <pagefault_handler>:
TRAPHANDLER(pagefault_handler, 0xE)
f0104af8:	6a 0e                	push   $0xe
f0104afa:	eb 7c                	jmp    f0104b78 <_alltraps>

f0104afc <FPUerror_handler>:
TRAPHANDLER_NOEC(FPUerror_handler, 0x10)
f0104afc:	6a 00                	push   $0x0
f0104afe:	6a 10                	push   $0x10
f0104b00:	eb 76                	jmp    f0104b78 <_alltraps>

f0104b02 <alignmentcheck_handler>:
TRAPHANDLER(alignmentcheck_handler, 0x11)
f0104b02:	6a 11                	push   $0x11
f0104b04:	eb 72                	jmp    f0104b78 <_alltraps>

f0104b06 <machinecheck_handler>:
TRAPHANDLER_NOEC(machinecheck_handler, 0x12)
f0104b06:	6a 00                	push   $0x0
f0104b08:	6a 12                	push   $0x12
f0104b0a:	eb 6c                	jmp    f0104b78 <_alltraps>

f0104b0c <SIMDFPexception_handler>:
TRAPHANDLER_NOEC(SIMDFPexception_handler, 0x13)
f0104b0c:	6a 00                	push   $0x0
f0104b0e:	6a 13                	push   $0x13
f0104b10:	eb 66                	jmp    f0104b78 <_alltraps>

f0104b12 <systemcall_handler>:
TRAPHANDLER_NOEC(systemcall_handler, 0x30)
f0104b12:	6a 00                	push   $0x0
f0104b14:	6a 30                	push   $0x30
f0104b16:	eb 60                	jmp    f0104b78 <_alltraps>

f0104b18 <t_irq0>:


TRAPHANDLER_NOEC(t_irq0, IRQ_OFFSET + 0);
f0104b18:	6a 00                	push   $0x0
f0104b1a:	6a 20                	push   $0x20
f0104b1c:	eb 5a                	jmp    f0104b78 <_alltraps>

f0104b1e <t_irq1>:
TRAPHANDLER_NOEC(t_irq1, IRQ_OFFSET + 1);
f0104b1e:	6a 00                	push   $0x0
f0104b20:	6a 21                	push   $0x21
f0104b22:	eb 54                	jmp    f0104b78 <_alltraps>

f0104b24 <t_irq2>:
TRAPHANDLER_NOEC(t_irq2, IRQ_OFFSET + 2);
f0104b24:	6a 00                	push   $0x0
f0104b26:	6a 22                	push   $0x22
f0104b28:	eb 4e                	jmp    f0104b78 <_alltraps>

f0104b2a <t_irq3>:
TRAPHANDLER_NOEC(t_irq3, IRQ_OFFSET + 3);
f0104b2a:	6a 00                	push   $0x0
f0104b2c:	6a 23                	push   $0x23
f0104b2e:	eb 48                	jmp    f0104b78 <_alltraps>

f0104b30 <t_irq4>:
TRAPHANDLER_NOEC(t_irq4, IRQ_OFFSET + 4);
f0104b30:	6a 00                	push   $0x0
f0104b32:	6a 24                	push   $0x24
f0104b34:	eb 42                	jmp    f0104b78 <_alltraps>

f0104b36 <t_irq5>:
TRAPHANDLER_NOEC(t_irq5, IRQ_OFFSET + 5);
f0104b36:	6a 00                	push   $0x0
f0104b38:	6a 25                	push   $0x25
f0104b3a:	eb 3c                	jmp    f0104b78 <_alltraps>

f0104b3c <t_irq6>:
TRAPHANDLER_NOEC(t_irq6, IRQ_OFFSET + 6);
f0104b3c:	6a 00                	push   $0x0
f0104b3e:	6a 26                	push   $0x26
f0104b40:	eb 36                	jmp    f0104b78 <_alltraps>

f0104b42 <t_irq7>:
TRAPHANDLER_NOEC(t_irq7, IRQ_OFFSET + 7);
f0104b42:	6a 00                	push   $0x0
f0104b44:	6a 27                	push   $0x27
f0104b46:	eb 30                	jmp    f0104b78 <_alltraps>

f0104b48 <t_irq8>:
TRAPHANDLER_NOEC(t_irq8, IRQ_OFFSET + 8);
f0104b48:	6a 00                	push   $0x0
f0104b4a:	6a 28                	push   $0x28
f0104b4c:	eb 2a                	jmp    f0104b78 <_alltraps>

f0104b4e <t_irq9>:
TRAPHANDLER_NOEC(t_irq9, IRQ_OFFSET + 9);
f0104b4e:	6a 00                	push   $0x0
f0104b50:	6a 29                	push   $0x29
f0104b52:	eb 24                	jmp    f0104b78 <_alltraps>

f0104b54 <t_irq10>:
TRAPHANDLER_NOEC(t_irq10, IRQ_OFFSET + 10);
f0104b54:	6a 00                	push   $0x0
f0104b56:	6a 2a                	push   $0x2a
f0104b58:	eb 1e                	jmp    f0104b78 <_alltraps>

f0104b5a <t_irq11>:
TRAPHANDLER_NOEC(t_irq11, IRQ_OFFSET + 11);
f0104b5a:	6a 00                	push   $0x0
f0104b5c:	6a 2b                	push   $0x2b
f0104b5e:	eb 18                	jmp    f0104b78 <_alltraps>

f0104b60 <t_irq12>:
TRAPHANDLER_NOEC(t_irq12, IRQ_OFFSET + 12);
f0104b60:	6a 00                	push   $0x0
f0104b62:	6a 2c                	push   $0x2c
f0104b64:	eb 12                	jmp    f0104b78 <_alltraps>

f0104b66 <t_irq13>:
TRAPHANDLER_NOEC(t_irq13, IRQ_OFFSET + 13);
f0104b66:	6a 00                	push   $0x0
f0104b68:	6a 2d                	push   $0x2d
f0104b6a:	eb 0c                	jmp    f0104b78 <_alltraps>

f0104b6c <t_irq14>:
TRAPHANDLER_NOEC(t_irq14, IRQ_OFFSET + 14);
f0104b6c:	6a 00                	push   $0x0
f0104b6e:	6a 2e                	push   $0x2e
f0104b70:	eb 06                	jmp    f0104b78 <_alltraps>

f0104b72 <t_irq15>:
TRAPHANDLER_NOEC(t_irq15, IRQ_OFFSET + 15);
f0104b72:	6a 00                	push   $0x0
f0104b74:	6a 2f                	push   $0x2f
f0104b76:	eb 00                	jmp    f0104b78 <_alltraps>

f0104b78 <_alltraps>:
/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
	pushw $0
f0104b78:	66 6a 00             	pushw  $0x0
	pushw %ds
f0104b7b:	66 1e                	pushw  %ds
	pushw $0
f0104b7d:	66 6a 00             	pushw  $0x0
	pushw %es
f0104b80:	66 06                	pushw  %es
	pushal
f0104b82:	60                   	pusha  
	pushl %esp
f0104b83:	54                   	push   %esp
	movw $(GD_KD),%ax
f0104b84:	66 b8 10 00          	mov    $0x10,%ax
	movw %ax,%ds
f0104b88:	8e d8                	mov    %eax,%ds
	movw %ax,%es
f0104b8a:	8e c0                	mov    %eax,%es
	call trap
f0104b8c:	e8 25 fd ff ff       	call   f01048b6 <trap>
f0104b91:	66 90                	xchg   %ax,%ax
f0104b93:	66 90                	xchg   %ax,%ax
f0104b95:	66 90                	xchg   %ax,%ax
f0104b97:	66 90                	xchg   %ax,%ax
f0104b99:	66 90                	xchg   %ax,%ax
f0104b9b:	66 90                	xchg   %ax,%ax
f0104b9d:	66 90                	xchg   %ax,%ax
f0104b9f:	90                   	nop

f0104ba0 <sched_yield>:
#include <kern/monitor.h>

// Choose a user environment to run and run it.
void
sched_yield(void)
{
f0104ba0:	55                   	push   %ebp
f0104ba1:	89 e5                	mov    %esp,%ebp
f0104ba3:	57                   	push   %edi
f0104ba4:	56                   	push   %esi
f0104ba5:	53                   	push   %ebx
f0104ba6:	83 ec 1c             	sub    $0x1c,%esp
	// Search through 'envs' for an ENV_RUNNABLE environment in
	// circular fashion starting just after the env this CPU was
	// last running.  Switch to the first such environment found.
	//
	int start;
	struct Env * curr = thiscpu->cpu_env;
f0104ba9:	e8 d5 19 00 00       	call   f0106583 <cpunum>
f0104bae:	6b c0 74             	imul   $0x74,%eax,%eax
f0104bb1:	8b b0 28 80 1c f0    	mov    -0xfe37fd8(%eax),%esi
	if(curr == NULL){
f0104bb7:	85 f6                	test   %esi,%esi
f0104bb9:	0f 84 df 00 00 00    	je     f0104c9e <sched_yield+0xfe>
		start = 0;
	}else{
		start = ENVX(curr->env_id ) ;
f0104bbf:	8b 7e 48             	mov    0x48(%esi),%edi
f0104bc2:	81 e7 ff 03 00 00    	and    $0x3ff,%edi
f0104bc8:	e9 d6 00 00 00       	jmp    f0104ca3 <sched_yield+0x103>
	}
	for(i=1;i<NENV;i++){
		start = (start+1) % NENV;
f0104bcd:	8d 47 01             	lea    0x1(%edi),%eax
f0104bd0:	99                   	cltd   
f0104bd1:	c1 ea 16             	shr    $0x16,%edx
f0104bd4:	01 d0                	add    %edx,%eax
f0104bd6:	25 ff 03 00 00       	and    $0x3ff,%eax
f0104bdb:	29 d0                	sub    %edx,%eax
f0104bdd:	89 c7                	mov    %eax,%edi
		if (envs[start].env_type != ENV_TYPE_IDLE && (envs[start].env_status == ENV_RUNNABLE )){
f0104bdf:	6b c0 7c             	imul   $0x7c,%eax,%eax
f0104be2:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f0104be5:	83 7a 50 01          	cmpl   $0x1,0x50(%edx)
f0104be9:	74 0e                	je     f0104bf9 <sched_yield+0x59>
f0104beb:	83 7a 54 02          	cmpl   $0x2,0x54(%edx)
f0104bef:	75 08                	jne    f0104bf9 <sched_yield+0x59>
			env_run(&envs[start]);
f0104bf1:	89 14 24             	mov    %edx,(%esp)
f0104bf4:	e8 6c f0 ff ff       	call   f0103c65 <env_run>
	if(curr == NULL){
		start = 0;
	}else{
		start = ENVX(curr->env_id ) ;
	}
	for(i=1;i<NENV;i++){
f0104bf9:	83 e9 01             	sub    $0x1,%ecx
f0104bfc:	75 cf                	jne    f0104bcd <sched_yield+0x2d>
		start = (start+1) % NENV;
		if (envs[start].env_type != ENV_TYPE_IDLE && (envs[start].env_status == ENV_RUNNABLE )){
			env_run(&envs[start]);
		}
	}
	 if (curr && curr->env_status == ENV_RUNNING) {
f0104bfe:	85 f6                	test   %esi,%esi
f0104c00:	74 06                	je     f0104c08 <sched_yield+0x68>
f0104c02:	83 7e 54 03          	cmpl   $0x3,0x54(%esi)
f0104c06:	74 09                	je     f0104c11 <sched_yield+0x71>
f0104c08:	89 d8                	mov    %ebx,%eax
	}else{
		start = ENVX(curr->env_id ) ;
	}
	for(i=1;i<NENV;i++){
		start = (start+1) % NENV;
		if (envs[start].env_type != ENV_TYPE_IDLE && (envs[start].env_status == ENV_RUNNABLE )){
f0104c0a:	ba 00 00 00 00       	mov    $0x0,%edx
f0104c0f:	eb 08                	jmp    f0104c19 <sched_yield+0x79>
			env_run(&envs[start]);
		}
	}
	 if (curr && curr->env_status == ENV_RUNNING) {
       		 env_run(curr);
f0104c11:	89 34 24             	mov    %esi,(%esp)
f0104c14:	e8 4c f0 ff ff       	call   f0103c65 <env_run>

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104c19:	83 78 50 01          	cmpl   $0x1,0x50(%eax)
f0104c1d:	74 0b                	je     f0104c2a <sched_yield+0x8a>
		    (envs[i].env_status == ENV_RUNNABLE ||
f0104c1f:	8b 70 54             	mov    0x54(%eax),%esi
f0104c22:	8d 4e fe             	lea    -0x2(%esi),%ecx

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104c25:	83 f9 01             	cmp    $0x1,%ecx
f0104c28:	76 10                	jbe    f0104c3a <sched_yield+0x9a>
	// LAB 4: Your code here.

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0104c2a:	83 c2 01             	add    $0x1,%edx
f0104c2d:	83 c0 7c             	add    $0x7c,%eax
f0104c30:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104c36:	75 e1                	jne    f0104c19 <sched_yield+0x79>
f0104c38:	eb 08                	jmp    f0104c42 <sched_yield+0xa2>
		if (envs[i].env_type != ENV_TYPE_IDLE &&
		    (envs[i].env_status == ENV_RUNNABLE ||
		     envs[i].env_status == ENV_RUNNING))
			break;
	}
	if (i == NENV) {
f0104c3a:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104c40:	75 1a                	jne    f0104c5c <sched_yield+0xbc>
		cprintf("No more runnable environments!\n");
f0104c42:	c7 04 24 30 81 10 f0 	movl   $0xf0108130,(%esp)
f0104c49:	e8 28 f2 ff ff       	call   f0103e76 <cprintf>
		while (1)
			monitor(NULL);
f0104c4e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0104c55:	e8 a8 bd ff ff       	call   f0100a02 <monitor>
f0104c5a:	eb f2                	jmp    f0104c4e <sched_yield+0xae>
	}

	// Run this CPU's idle environment when nothing else is runnable.
	idle = &envs[cpunum()];
f0104c5c:	e8 22 19 00 00       	call   f0106583 <cpunum>
f0104c61:	6b c0 7c             	imul   $0x7c,%eax,%eax
f0104c64:	01 c3                	add    %eax,%ebx
	if (!(idle->env_status == ENV_RUNNABLE || idle->env_status == ENV_RUNNING))
f0104c66:	8b 43 54             	mov    0x54(%ebx),%eax
f0104c69:	83 e8 02             	sub    $0x2,%eax
f0104c6c:	83 f8 01             	cmp    $0x1,%eax
f0104c6f:	76 25                	jbe    f0104c96 <sched_yield+0xf6>
		panic("CPU %d: No idle environment!", cpunum());
f0104c71:	e8 0d 19 00 00       	call   f0106583 <cpunum>
f0104c76:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104c7a:	c7 44 24 08 50 81 10 	movl   $0xf0108150,0x8(%esp)
f0104c81:	f0 
f0104c82:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
f0104c89:	00 
f0104c8a:	c7 04 24 6d 81 10 f0 	movl   $0xf010816d,(%esp)
f0104c91:	e8 aa b3 ff ff       	call   f0100040 <_panic>
	env_run(idle);
f0104c96:	89 1c 24             	mov    %ebx,(%esp)
f0104c99:	e8 c7 ef ff ff       	call   f0103c65 <env_run>
	// last running.  Switch to the first such environment found.
	//
	int start;
	struct Env * curr = thiscpu->cpu_env;
	if(curr == NULL){
		start = 0;
f0104c9e:	bf 00 00 00 00       	mov    $0x0,%edi
	}else{
		start = ENVX(curr->env_id ) ;
	}
	for(i=1;i<NENV;i++){
		start = (start+1) % NENV;
		if (envs[start].env_type != ENV_TYPE_IDLE && (envs[start].env_status == ENV_RUNNABLE )){
f0104ca3:	8b 1d 48 72 1c f0    	mov    0xf01c7248,%ebx
f0104ca9:	b9 ff 03 00 00       	mov    $0x3ff,%ecx
f0104cae:	e9 1a ff ff ff       	jmp    f0104bcd <sched_yield+0x2d>
f0104cb3:	66 90                	xchg   %ax,%ax
f0104cb5:	66 90                	xchg   %ax,%ax
f0104cb7:	66 90                	xchg   %ax,%ax
f0104cb9:	66 90                	xchg   %ax,%ax
f0104cbb:	66 90                	xchg   %ax,%ax
f0104cbd:	66 90                	xchg   %ax,%ax
f0104cbf:	90                   	nop

f0104cc0 <syscall>:
}

// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
f0104cc0:	55                   	push   %ebp
f0104cc1:	89 e5                	mov    %esp,%ebp
f0104cc3:	57                   	push   %edi
f0104cc4:	56                   	push   %esi
f0104cc5:	53                   	push   %ebx
f0104cc6:	83 ec 2c             	sub    $0x2c,%esp
f0104cc9:	8b 45 08             	mov    0x8(%ebp),%eax
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
	switch(syscallno){
f0104ccc:	83 f8 0d             	cmp    $0xd,%eax
f0104ccf:	0f 87 47 05 00 00    	ja     f010521c <syscall+0x55c>
f0104cd5:	ff 24 85 80 81 10 f0 	jmp    *-0xfef7e80(,%eax,4)

// Deschedule current environment and pick a different one to run.
static void
sys_yield(void)
{
	sched_yield();
f0104cdc:	e8 bf fe ff ff       	call   f0104ba0 <sched_yield>
static void
sys_cputs(const char *s, size_t len)
{
	// Check that the user has permission to read memory [s, s+len).
	// Destroy the environment if not.
	user_mem_assert(curenv,s,len,0);
f0104ce1:	e8 9d 18 00 00       	call   f0106583 <cpunum>
f0104ce6:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104ced:	00 
f0104cee:	8b 7d 10             	mov    0x10(%ebp),%edi
f0104cf1:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0104cf5:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104cf8:	89 74 24 04          	mov    %esi,0x4(%esp)
f0104cfc:	6b c0 74             	imul   $0x74,%eax,%eax
f0104cff:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104d05:	89 04 24             	mov    %eax,(%esp)
f0104d08:	e8 f3 e7 ff ff       	call   f0103500 <user_mem_assert>
	// LAB 3: Your code here.
	// Print the string supplied by the user.
	cprintf("%.*s", len, s);
f0104d0d:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104d10:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104d14:	8b 45 10             	mov    0x10(%ebp),%eax
f0104d17:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104d1b:	c7 04 24 7a 81 10 f0 	movl   $0xf010817a,(%esp)
f0104d22:	e8 4f f1 ff ff       	call   f0103e76 <cprintf>
		case(SYS_yield):
			sys_yield();
			return 0;
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
f0104d27:	b8 00 00 00 00       	mov    $0x0,%eax
f0104d2c:	e9 f7 04 00 00       	jmp    f0105228 <syscall+0x568>
//	-E_NO_MEM if there's no memory to allocate the new page,
//		or to allocate any necessary page tables.
static int
sys_page_alloc(envid_t envid, void *va, int perm)
{
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
f0104d31:	8b 45 14             	mov    0x14(%ebp),%eax
f0104d34:	25 fd f1 ff ff       	and    $0xfffff1fd,%eax
f0104d39:	83 f8 05             	cmp    $0x5,%eax
f0104d3c:	75 70                	jne    f0104dae <syscall+0xee>
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
	struct Page* pp = page_alloc(ALLOC_ZERO);
f0104d3e:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0104d45:	e8 cc c3 ff ff       	call   f0101116 <page_alloc>
f0104d4a:	89 c3                	mov    %eax,%ebx
	if(pp == NULL) // out of memory
f0104d4c:	85 c0                	test   %eax,%eax
f0104d4e:	74 68                	je     f0104db8 <syscall+0xf8>
		return -E_NO_MEM;

	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
f0104d50:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104d57:	00 
f0104d58:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104d5b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104d5f:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104d62:	89 04 24             	mov    %eax,(%esp)
f0104d65:	e8 ee e7 ff ff       	call   f0103558 <envid2env>
f0104d6a:	89 c1                	mov    %eax,%ecx
	if(r != 0) // any bad env
f0104d6c:	85 c9                	test   %ecx,%ecx
f0104d6e:	0f 85 b4 04 00 00    	jne    f0105228 <syscall+0x568>
		return r;

	//if va >= UTOP, or va is not page-aligned.
	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
f0104d74:	81 7d 10 ff ff bf ee 	cmpl   $0xeebfffff,0x10(%ebp)
f0104d7b:	77 45                	ja     f0104dc2 <syscall+0x102>
f0104d7d:	f7 45 10 ff 0f 00 00 	testl  $0xfff,0x10(%ebp)
f0104d84:	75 46                	jne    f0104dcc <syscall+0x10c>
		return -E_INVAL;

	r = page_insert(target_env->env_pgdir, pp, va, perm | PTE_P);
f0104d86:	8b 45 14             	mov    0x14(%ebp),%eax
f0104d89:	83 c8 01             	or     $0x1,%eax
f0104d8c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104d90:	8b 45 10             	mov    0x10(%ebp),%eax
f0104d93:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104d97:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104d9b:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104d9e:	8b 40 60             	mov    0x60(%eax),%eax
f0104da1:	89 04 24             	mov    %eax,(%esp)
f0104da4:	e8 a7 c6 ff ff       	call   f0101450 <page_insert>
f0104da9:	e9 7a 04 00 00       	jmp    f0105228 <syscall+0x568>
sys_page_alloc(envid_t envid, void *va, int perm)
{
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
f0104dae:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0104db3:	e9 70 04 00 00       	jmp    f0105228 <syscall+0x568>
	struct Page* pp = page_alloc(ALLOC_ZERO);
	if(pp == NULL) // out of memory
		return -E_NO_MEM;
f0104db8:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
f0104dbd:	e9 66 04 00 00       	jmp    f0105228 <syscall+0x568>
	if(r != 0) // any bad env
		return r;

	//if va >= UTOP, or va is not page-aligned.
	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
		return -E_INVAL;
f0104dc2:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0104dc7:	e9 5c 04 00 00       	jmp    f0105228 <syscall+0x568>
f0104dcc:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
			return 0;
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case (SYS_page_alloc):
			return sys_page_alloc(a1, (void*)a2, a3);
f0104dd1:	e9 52 04 00 00       	jmp    f0105228 <syscall+0x568>
// Read a character from the system console without blocking.
// Returns the character, or 0 if there is no input waiting.
static int
sys_cgetc(void)
{
	return cons_getc();
f0104dd6:	e8 ca b8 ff ff       	call   f01006a5 <cons_getc>
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case (SYS_page_alloc):
			return sys_page_alloc(a1, (void*)a2, a3);
		case(SYS_cgetc):
			return sys_cgetc();
f0104ddb:	e9 48 04 00 00       	jmp    f0105228 <syscall+0x568>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f0104de0:	e8 9e 17 00 00       	call   f0106583 <cpunum>
f0104de5:	6b c0 74             	imul   $0x74,%eax,%eax
f0104de8:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104dee:	8b 40 48             	mov    0x48(%eax),%eax
		case (SYS_page_alloc):
			return sys_page_alloc(a1, (void*)a2, a3);
		case(SYS_cgetc):
			return sys_cgetc();
		case(SYS_getenvid):
			return sys_getenvid();
f0104df1:	e9 32 04 00 00       	jmp    f0105228 <syscall+0x568>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f0104df6:	e8 88 17 00 00       	call   f0106583 <cpunum>
f0104dfb:	6b c0 74             	imul   $0x74,%eax,%eax
f0104dfe:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104e04:	8b 58 48             	mov    0x48(%eax),%ebx
	// from the current environment -- but tweaked so sys_exofork
	// will appear to return 0.
	struct Env* new_env;
	struct Env* this_env;
	envid_t this_envid = sys_getenvid();
	envid2env(this_envid,&this_env,1);
f0104e07:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104e0e:	00 
f0104e0f:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104e12:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104e16:	89 1c 24             	mov    %ebx,(%esp)
f0104e19:	e8 3a e7 ff ff       	call   f0103558 <envid2env>
	int r = env_alloc(&new_env,this_envid);
f0104e1e:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104e22:	8d 45 e0             	lea    -0x20(%ebp),%eax
f0104e25:	89 04 24             	mov    %eax,(%esp)
f0104e28:	e8 33 e8 ff ff       	call   f0103660 <env_alloc>
	if(r!=0)
		return r;
f0104e2d:	89 c2                	mov    %eax,%edx
	struct Env* new_env;
	struct Env* this_env;
	envid_t this_envid = sys_getenvid();
	envid2env(this_envid,&this_env,1);
	int r = env_alloc(&new_env,this_envid);
	if(r!=0)
f0104e2f:	85 c0                	test   %eax,%eax
f0104e31:	75 21                	jne    f0104e54 <syscall+0x194>
		return r;

	new_env->env_tf = this_env->env_tf;
f0104e33:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0104e36:	b9 11 00 00 00       	mov    $0x11,%ecx
f0104e3b:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0104e3e:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
	new_env->env_tf.tf_regs.reg_eax = 0;
f0104e40:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104e43:	c7 40 1c 00 00 00 00 	movl   $0x0,0x1c(%eax)
	new_env->env_status = ENV_NOT_RUNNABLE;
f0104e4a:	c7 40 54 04 00 00 00 	movl   $0x4,0x54(%eax)
	//cprintf("alloc env number %d",new_env->env_id);
	return new_env->env_id;
f0104e51:	8b 50 48             	mov    0x48(%eax),%edx
		case(SYS_cgetc):
			return sys_cgetc();
		case(SYS_getenvid):
			return sys_getenvid();
		case (SYS_exofork):
			return sys_exofork();
f0104e54:	89 d0                	mov    %edx,%eax
f0104e56:	e9 cd 03 00 00       	jmp    f0105228 <syscall+0x568>
	// envid to a struct Env.
	// You should set envid2env's third argument to 1, which will
	// check whether the current environment has permission to set
	// envid's status.
	struct  Env* this_env;
	int r = envid2env(envid,&this_env,1);
f0104e5b:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104e62:	00 
f0104e63:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104e66:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104e6a:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104e6d:	89 04 24             	mov    %eax,(%esp)
f0104e70:	e8 e3 e6 ff ff       	call   f0103558 <envid2env>
	if(r != 0)
		return r;
f0104e75:	89 c2                	mov    %eax,%edx
	// You should set envid2env's third argument to 1, which will
	// check whether the current environment has permission to set
	// envid's status.
	struct  Env* this_env;
	int r = envid2env(envid,&this_env,1);
	if(r != 0)
f0104e77:	85 c0                	test   %eax,%eax
f0104e79:	75 21                	jne    f0104e9c <syscall+0x1dc>
		return r;
	if((status != ENV_RUNNABLE) && (status != ENV_NOT_RUNNABLE))
f0104e7b:	83 7d 10 04          	cmpl   $0x4,0x10(%ebp)
f0104e7f:	74 06                	je     f0104e87 <syscall+0x1c7>
f0104e81:	83 7d 10 02          	cmpl   $0x2,0x10(%ebp)
f0104e85:	75 10                	jne    f0104e97 <syscall+0x1d7>
		return -E_INVAL;
	this_env->env_status = status;
f0104e87:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104e8a:	8b 4d 10             	mov    0x10(%ebp),%ecx
f0104e8d:	89 48 54             	mov    %ecx,0x54(%eax)
	return 0;
f0104e90:	ba 00 00 00 00       	mov    $0x0,%edx
f0104e95:	eb 05                	jmp    f0104e9c <syscall+0x1dc>
	struct  Env* this_env;
	int r = envid2env(envid,&this_env,1);
	if(r != 0)
		return r;
	if((status != ENV_RUNNABLE) && (status != ENV_NOT_RUNNABLE))
		return -E_INVAL;
f0104e97:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
		case(SYS_getenvid):
			return sys_getenvid();
		case (SYS_exofork):
			return sys_exofork();
		case (SYS_env_set_status):
			return sys_env_set_status(a1, a2);
f0104e9c:	89 d0                	mov    %edx,%eax
f0104e9e:	e9 85 03 00 00       	jmp    f0105228 <syscall+0x568>
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104ea3:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104eaa:	00 
f0104eab:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104eae:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104eb2:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104eb5:	89 04 24             	mov    %eax,(%esp)
f0104eb8:	e8 9b e6 ff ff       	call   f0103558 <envid2env>
		return r;
f0104ebd:	89 c2                	mov    %eax,%edx
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104ebf:	85 c0                	test   %eax,%eax
f0104ec1:	78 10                	js     f0104ed3 <syscall+0x213>
		return r;
	env_destroy(e);
f0104ec3:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104ec6:	89 04 24             	mov    %eax,(%esp)
f0104ec9:	e8 f6 ec ff ff       	call   f0103bc4 <env_destroy>
	return 0;
f0104ece:	ba 00 00 00 00       	mov    $0x0,%edx
		case (SYS_exofork):
			return sys_exofork();
		case (SYS_env_set_status):
			return sys_env_set_status(a1, a2);
		case(SYS_env_destroy):
			return sys_env_destroy((envid_t) a1);
f0104ed3:	89 d0                	mov    %edx,%eax
f0104ed5:	e9 4e 03 00 00       	jmp    f0105228 <syscall+0x568>
	//   page_insert() from kern/pmap.c.
	//   Again, most of the new code you write should be to check the
	//   parameters for correctness.
	//   Use the third argument to page_lookup() to
	//   check the current permissions on the page.
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
f0104eda:	8b 45 1c             	mov    0x1c(%ebp),%eax
f0104edd:	25 fd f1 ff ff       	and    $0xfffff1fd,%eax
f0104ee2:	83 f8 05             	cmp    $0x5,%eax
f0104ee5:	0f 85 be 00 00 00    	jne    f0104fa9 <syscall+0x2e9>
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;

	struct Env* srcenv, * dstenv;
	int r = envid2env(srcenvid, &srcenv, 1);
f0104eeb:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104ef2:	00 
f0104ef3:	8d 45 dc             	lea    -0x24(%ebp),%eax
f0104ef6:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104efa:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104efd:	89 04 24             	mov    %eax,(%esp)
f0104f00:	e8 53 e6 ff ff       	call   f0103558 <envid2env>
	if(r) return E_BAD_ENV;
f0104f05:	ba 02 00 00 00       	mov    $0x2,%edx
f0104f0a:	85 c0                	test   %eax,%eax
f0104f0c:	0f 85 bf 00 00 00    	jne    f0104fd1 <syscall+0x311>
	r = envid2env(dstenvid, &dstenv, 1);
f0104f12:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104f19:	00 
f0104f1a:	8d 45 e0             	lea    -0x20(%ebp),%eax
f0104f1d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104f21:	8b 45 14             	mov    0x14(%ebp),%eax
f0104f24:	89 04 24             	mov    %eax,(%esp)
f0104f27:	e8 2c e6 ff ff       	call   f0103558 <envid2env>
	if(r) return E_BAD_ENV;
f0104f2c:	ba 02 00 00 00       	mov    $0x2,%edx
f0104f31:	85 c0                	test   %eax,%eax
f0104f33:	0f 85 98 00 00 00    	jne    f0104fd1 <syscall+0x311>

	if(((uint32_t)srcva >= UTOP) || ((((uint32_t)srcva & 0x00000fff) != 0)))
f0104f39:	81 7d 10 ff ff bf ee 	cmpl   $0xeebfffff,0x10(%ebp)
f0104f40:	77 6e                	ja     f0104fb0 <syscall+0x2f0>
f0104f42:	f7 45 10 ff 0f 00 00 	testl  $0xfff,0x10(%ebp)
f0104f49:	75 6c                	jne    f0104fb7 <syscall+0x2f7>
		return -E_INVAL;

	if(((uint32_t)dstva >= UTOP) || ((((uint32_t)dstva & 0x00000fff) != 0)))
f0104f4b:	81 7d 18 ff ff bf ee 	cmpl   $0xeebfffff,0x18(%ebp)
f0104f52:	77 6a                	ja     f0104fbe <syscall+0x2fe>
f0104f54:	f7 45 18 ff 0f 00 00 	testl  $0xfff,0x18(%ebp)
f0104f5b:	75 68                	jne    f0104fc5 <syscall+0x305>
		return -E_INVAL;


	pte_t* src_table_entry;
	struct Page* srcpp;
	srcpp = page_lookup(srcenv->env_pgdir, srcva, &src_table_entry);
f0104f5d:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104f60:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104f64:	8b 45 10             	mov    0x10(%ebp),%eax
f0104f67:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104f6b:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0104f6e:	8b 40 60             	mov    0x60(%eax),%eax
f0104f71:	89 04 24             	mov    %eax,(%esp)
f0104f74:	e8 ec c3 ff ff       	call   f0101365 <page_lookup>
	if(srcpp == NULL) return -E_INVAL;
f0104f79:	85 c0                	test   %eax,%eax
f0104f7b:	74 4f                	je     f0104fcc <syscall+0x30c>
	//cprintf("3. page lookup check passed.\n");

	if(((perm & PTE_W) == 1) && (((*src_table_entry) & PTE_W) == 0))
		return E_BAD_ENV;

	r = page_insert(dstenv->env_pgdir, srcpp, dstva, perm);
f0104f7d:	8b 75 1c             	mov    0x1c(%ebp),%esi
f0104f80:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0104f84:	8b 75 18             	mov    0x18(%ebp),%esi
f0104f87:	89 74 24 08          	mov    %esi,0x8(%esp)
f0104f8b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104f8f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104f92:	8b 40 60             	mov    0x60(%eax),%eax
f0104f95:	89 04 24             	mov    %eax,(%esp)
f0104f98:	e8 b3 c4 ff ff       	call   f0101450 <page_insert>
	if(r)
		return -E_INVAL;
f0104f9d:	83 f8 01             	cmp    $0x1,%eax
f0104fa0:	19 d2                	sbb    %edx,%edx
f0104fa2:	f7 d2                	not    %edx
f0104fa4:	83 e2 fd             	and    $0xfffffffd,%edx
f0104fa7:	eb 28                	jmp    f0104fd1 <syscall+0x311>
	//   Use the third argument to page_lookup() to
	//   check the current permissions on the page.
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
f0104fa9:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104fae:	eb 21                	jmp    f0104fd1 <syscall+0x311>
	if(r) return E_BAD_ENV;
	r = envid2env(dstenvid, &dstenv, 1);
	if(r) return E_BAD_ENV;

	if(((uint32_t)srcva >= UTOP) || ((((uint32_t)srcva & 0x00000fff) != 0)))
		return -E_INVAL;
f0104fb0:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104fb5:	eb 1a                	jmp    f0104fd1 <syscall+0x311>
f0104fb7:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104fbc:	eb 13                	jmp    f0104fd1 <syscall+0x311>

	if(((uint32_t)dstva >= UTOP) || ((((uint32_t)dstva & 0x00000fff) != 0)))
		return -E_INVAL;
f0104fbe:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104fc3:	eb 0c                	jmp    f0104fd1 <syscall+0x311>
f0104fc5:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104fca:	eb 05                	jmp    f0104fd1 <syscall+0x311>


	pte_t* src_table_entry;
	struct Page* srcpp;
	srcpp = page_lookup(srcenv->env_pgdir, srcva, &src_table_entry);
	if(srcpp == NULL) return -E_INVAL;
f0104fcc:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
		case (SYS_env_set_status):
			return sys_env_set_status(a1, a2);
		case(SYS_env_destroy):
			return sys_env_destroy((envid_t) a1);
		case (SYS_page_map):
			return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
f0104fd1:	89 d0                	mov    %edx,%eax
f0104fd3:	e9 50 02 00 00       	jmp    f0105228 <syscall+0x568>
static int
sys_page_unmap(envid_t envid, void *va)
{
	// Hint: This function is a wrapper around page_remove().
	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
f0104fd8:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104fdf:	00 
f0104fe0:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104fe3:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104fe7:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104fea:	89 04 24             	mov    %eax,(%esp)
f0104fed:	e8 66 e5 ff ff       	call   f0103558 <envid2env>
	if(r) return E_BAD_ENV;
f0104ff2:	ba 02 00 00 00       	mov    $0x2,%edx
f0104ff7:	85 c0                	test   %eax,%eax
f0104ff9:	75 3a                	jne    f0105035 <syscall+0x375>

	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
f0104ffb:	81 7d 10 ff ff bf ee 	cmpl   $0xeebfffff,0x10(%ebp)
f0105002:	77 25                	ja     f0105029 <syscall+0x369>
f0105004:	f7 45 10 ff 0f 00 00 	testl  $0xfff,0x10(%ebp)
f010500b:	75 23                	jne    f0105030 <syscall+0x370>
		return -E_INVAL;

	page_remove(target_env->env_pgdir, va);
f010500d:	8b 45 10             	mov    0x10(%ebp),%eax
f0105010:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105014:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105017:	8b 40 60             	mov    0x60(%eax),%eax
f010501a:	89 04 24             	mov    %eax,(%esp)
f010501d:	e8 e5 c3 ff ff       	call   f0101407 <page_remove>
	return 0;
f0105022:	ba 00 00 00 00       	mov    $0x0,%edx
f0105027:	eb 0c                	jmp    f0105035 <syscall+0x375>
	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
	if(r) return E_BAD_ENV;

	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
		return -E_INVAL;
f0105029:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f010502e:	eb 05                	jmp    f0105035 <syscall+0x375>
f0105030:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
		case(SYS_env_destroy):
			return sys_env_destroy((envid_t) a1);
		case (SYS_page_map):
			return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
		case (SYS_page_unmap):
			return sys_page_unmap(a1, (void*)a2);
f0105035:	89 d0                	mov    %edx,%eax
f0105037:	e9 ec 01 00 00       	jmp    f0105228 <syscall+0x568>
//	-E_BAD_ENV if environment envid doesn't currently exist,
//		or the caller doesn't have permission to change envid.
static int
sys_env_set_pgfault_upcall(envid_t envid, void *func)
{
	struct Env* this_env =  NULL;
f010503c:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	int r = envid2env(envid,&this_env,1);
f0105043:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010504a:	00 
f010504b:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f010504e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105052:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105055:	89 04 24             	mov    %eax,(%esp)
f0105058:	e8 fb e4 ff ff       	call   f0103558 <envid2env>
	if(r){
f010505d:	85 c0                	test   %eax,%eax
f010505f:	75 13                	jne    f0105074 <syscall+0x3b4>
		return -E_BAD_ENV ;
	}
	this_env->env_pgfault_upcall = func;
f0105061:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105064:	8b 7d 10             	mov    0x10(%ebp),%edi
f0105067:	89 78 64             	mov    %edi,0x64(%eax)
	return 0;
f010506a:	b8 00 00 00 00       	mov    $0x0,%eax
f010506f:	e9 b4 01 00 00       	jmp    f0105228 <syscall+0x568>
sys_env_set_pgfault_upcall(envid_t envid, void *func)
{
	struct Env* this_env =  NULL;
	int r = envid2env(envid,&this_env,1);
	if(r){
		return -E_BAD_ENV ;
f0105074:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
		case (SYS_page_map):
			return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
		case (SYS_page_unmap):
			return sys_page_unmap(a1, (void*)a2);
		case (SYS_env_set_pgfault_upcall):
			return sys_env_set_pgfault_upcall(a1, (void*)a2);
f0105079:	e9 aa 01 00 00       	jmp    f0105228 <syscall+0x568>
//		address space.
static int
sys_ipc_try_send(envid_t envid, uint32_t value, void *srcva, unsigned perm)
{
	struct Env * target_env;
	int ret = envid2env(envid,&target_env,0);//zero for not to check permission
f010507e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0105085:	00 
f0105086:	8d 45 e0             	lea    -0x20(%ebp),%eax
f0105089:	89 44 24 04          	mov    %eax,0x4(%esp)
f010508d:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105090:	89 04 24             	mov    %eax,(%esp)
f0105093:	e8 c0 e4 ff ff       	call   f0103558 <envid2env>
	if(ret)
f0105098:	85 c0                	test   %eax,%eax
f010509a:	0f 85 15 01 00 00    	jne    f01051b5 <syscall+0x4f5>
		return -E_BAD_ENV;
	if(!target_env->env_ipc_recving)
f01050a0:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01050a3:	83 78 68 00          	cmpl   $0x0,0x68(%eax)
f01050a7:	0f 84 0f 01 00 00    	je     f01051bc <syscall+0x4fc>
		return -E_IPC_NOT_RECV;
	target_env->env_ipc_perm = 0;
f01050ad:	c7 40 78 00 00 00 00 	movl   $0x0,0x78(%eax)
	// LAB 4: Your code here.
	//panic("sys_ipc_try_send not implemented");
	if(srcva!=NULL && ((uint32_t)srcva<UTOP)){
f01050b4:	8b 45 14             	mov    0x14(%ebp),%eax
f01050b7:	83 e8 01             	sub    $0x1,%eax
f01050ba:	3d fe ff bf ee       	cmp    $0xeebffffe,%eax
f01050bf:	0f 87 b4 00 00 00    	ja     f0105179 <syscall+0x4b9>
		if(ROUNDDOWN(srcva,PGSIZE)!=srcva) return -E_INVAL;
f01050c5:	8b 55 14             	mov    0x14(%ebp),%edx
f01050c8:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f01050ce:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f01050d3:	39 55 14             	cmp    %edx,0x14(%ebp)
f01050d6:	0f 85 4c 01 00 00    	jne    f0105228 <syscall+0x568>
		if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
f01050dc:	8b 55 18             	mov    0x18(%ebp),%edx
f01050df:	81 e2 fd f1 ff ff    	and    $0xfffff1fd,%edx
f01050e5:	83 fa 05             	cmp    $0x5,%edx
f01050e8:	0f 85 3a 01 00 00    	jne    f0105228 <syscall+0x568>
		return -E_INVAL;

		pte_t* src_table_entry;
		struct Page* srcpp;

		srcpp = page_lookup(curenv->env_pgdir, srcva, &src_table_entry);
f01050ee:	e8 90 14 00 00       	call   f0106583 <cpunum>
f01050f3:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f01050f6:	89 54 24 08          	mov    %edx,0x8(%esp)
f01050fa:	8b 75 14             	mov    0x14(%ebp),%esi
f01050fd:	89 74 24 04          	mov    %esi,0x4(%esp)
f0105101:	6b c0 74             	imul   $0x74,%eax,%eax
f0105104:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f010510a:	8b 40 60             	mov    0x60(%eax),%eax
f010510d:	89 04 24             	mov    %eax,(%esp)
f0105110:	e8 50 c2 ff ff       	call   f0101365 <page_lookup>
f0105115:	89 c2                	mov    %eax,%edx
		if(srcpp == NULL) return -E_INVAL;
f0105117:	85 c0                	test   %eax,%eax
f0105119:	74 4a                	je     f0105165 <syscall+0x4a5>

		if((perm & PTE_W) && (*src_table_entry & PTE_W) == 0)
f010511b:	f6 45 18 02          	testb  $0x2,0x18(%ebp)
f010511f:	74 11                	je     f0105132 <syscall+0x472>
			return -E_INVAL;
f0105121:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
		struct Page* srcpp;

		srcpp = page_lookup(curenv->env_pgdir, srcva, &src_table_entry);
		if(srcpp == NULL) return -E_INVAL;

		if((perm & PTE_W) && (*src_table_entry & PTE_W) == 0)
f0105126:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0105129:	f6 01 02             	testb  $0x2,(%ecx)
f010512c:	0f 84 f6 00 00 00    	je     f0105228 <syscall+0x568>
			return -E_INVAL;

		if(target_env->env_ipc_dstva != 0) // really send the page if the target want.
f0105132:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105135:	8b 48 6c             	mov    0x6c(%eax),%ecx
f0105138:	85 c9                	test   %ecx,%ecx
f010513a:	74 3d                	je     f0105179 <syscall+0x4b9>
		{
			if(page_insert (target_env->env_pgdir, srcpp, target_env->env_ipc_dstva, perm) < 0)
f010513c:	8b 75 18             	mov    0x18(%ebp),%esi
f010513f:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105143:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0105147:	89 54 24 04          	mov    %edx,0x4(%esp)
f010514b:	8b 40 60             	mov    0x60(%eax),%eax
f010514e:	89 04 24             	mov    %eax,(%esp)
f0105151:	e8 fa c2 ff ff       	call   f0101450 <page_insert>
f0105156:	85 c0                	test   %eax,%eax
f0105158:	78 15                	js     f010516f <syscall+0x4af>
				return -E_NO_MEM;
			target_env->env_ipc_perm = perm;
f010515a:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010515d:	8b 75 18             	mov    0x18(%ebp),%esi
f0105160:	89 70 78             	mov    %esi,0x78(%eax)
f0105163:	eb 14                	jmp    f0105179 <syscall+0x4b9>

		pte_t* src_table_entry;
		struct Page* srcpp;

		srcpp = page_lookup(curenv->env_pgdir, srcva, &src_table_entry);
		if(srcpp == NULL) return -E_INVAL;
f0105165:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f010516a:	e9 b9 00 00 00       	jmp    f0105228 <syscall+0x568>
			return -E_INVAL;

		if(target_env->env_ipc_dstva != 0) // really send the page if the target want.
		{
			if(page_insert (target_env->env_pgdir, srcpp, target_env->env_ipc_dstva, perm) < 0)
				return -E_NO_MEM;
f010516f:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
f0105174:	e9 af 00 00 00       	jmp    f0105228 <syscall+0x568>
			target_env->env_ipc_perm = perm;
		}
	}
	target_env->env_ipc_recving = 0;
f0105179:	8b 5d e0             	mov    -0x20(%ebp),%ebx
f010517c:	c7 43 68 00 00 00 00 	movl   $0x0,0x68(%ebx)
    	target_env->env_ipc_from = curenv->env_id;
f0105183:	e8 fb 13 00 00       	call   f0106583 <cpunum>
f0105188:	6b c0 74             	imul   $0x74,%eax,%eax
f010518b:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0105191:	8b 40 48             	mov    0x48(%eax),%eax
f0105194:	89 43 74             	mov    %eax,0x74(%ebx)
    	target_env->env_ipc_value = value; 
f0105197:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010519a:	8b 75 10             	mov    0x10(%ebp),%esi
f010519d:	89 70 70             	mov    %esi,0x70(%eax)
    	target_env->env_status = ENV_RUNNABLE;
f01051a0:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)
   	 target_env->env_tf.tf_regs.reg_eax = 0;
f01051a7:	c7 40 1c 00 00 00 00 	movl   $0x0,0x1c(%eax)
   	 return 0;
f01051ae:	b8 00 00 00 00       	mov    $0x0,%eax
f01051b3:	eb 73                	jmp    f0105228 <syscall+0x568>
sys_ipc_try_send(envid_t envid, uint32_t value, void *srcva, unsigned perm)
{
	struct Env * target_env;
	int ret = envid2env(envid,&target_env,0);//zero for not to check permission
	if(ret)
		return -E_BAD_ENV;
f01051b5:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01051ba:	eb 6c                	jmp    f0105228 <syscall+0x568>
	if(!target_env->env_ipc_recving)
		return -E_IPC_NOT_RECV;
f01051bc:	b8 f9 ff ff ff       	mov    $0xfffffff9,%eax
		case (SYS_page_unmap):
			return sys_page_unmap(a1, (void*)a2);
		case (SYS_env_set_pgfault_upcall):
			return sys_env_set_pgfault_upcall(a1, (void*)a2);
		case (SYS_ipc_try_send):
			return sys_ipc_try_send(a1, a2, (void*)a3, a4);
f01051c1:	eb 65                	jmp    f0105228 <syscall+0x568>
// Return < 0 on error.  Errors are:
//	-E_INVAL if dstva < UTOP but dstva is not page-aligned.
static int
sys_ipc_recv(void *dstva)
{
	if(dstva<(void*)UTOP){
f01051c3:	81 7d 0c ff ff bf ee 	cmpl   $0xeebfffff,0xc(%ebp)
f01051ca:	77 0d                	ja     f01051d9 <syscall+0x519>
		if(dstva != ROUNDDOWN(dstva,PGSIZE))
f01051cc:	8b 45 0c             	mov    0xc(%ebp),%eax
f01051cf:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01051d4:	39 45 0c             	cmp    %eax,0xc(%ebp)
f01051d7:	75 4a                	jne    f0105223 <syscall+0x563>
			return -E_INVAL;
	}
	// LAB 4: Your code here.
	curenv->env_ipc_recving = 1;
f01051d9:	e8 a5 13 00 00       	call   f0106583 <cpunum>
f01051de:	6b c0 74             	imul   $0x74,%eax,%eax
f01051e1:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f01051e7:	c7 40 68 01 00 00 00 	movl   $0x1,0x68(%eax)
    	curenv->env_status = ENV_NOT_RUNNABLE;
f01051ee:	e8 90 13 00 00       	call   f0106583 <cpunum>
f01051f3:	6b c0 74             	imul   $0x74,%eax,%eax
f01051f6:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f01051fc:	c7 40 54 04 00 00 00 	movl   $0x4,0x54(%eax)
    	curenv->env_ipc_dstva = dstva;
f0105203:	e8 7b 13 00 00       	call   f0106583 <cpunum>
f0105208:	6b c0 74             	imul   $0x74,%eax,%eax
f010520b:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0105211:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105214:	89 70 6c             	mov    %esi,0x6c(%eax)

// Deschedule current environment and pick a different one to run.
static void
sys_yield(void)
{
	sched_yield();
f0105217:	e8 84 f9 ff ff       	call   f0104ba0 <sched_yield>
		case (SYS_ipc_try_send):
			return sys_ipc_try_send(a1, a2, (void*)a3, a4);
		case (SYS_ipc_recv):
			return sys_ipc_recv((void*)a1);
		default:
			return -E_INVAL;
f010521c:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0105221:	eb 05                	jmp    f0105228 <syscall+0x568>
		case (SYS_env_set_pgfault_upcall):
			return sys_env_set_pgfault_upcall(a1, (void*)a2);
		case (SYS_ipc_try_send):
			return sys_ipc_try_send(a1, a2, (void*)a3, a4);
		case (SYS_ipc_recv):
			return sys_ipc_recv((void*)a1);
f0105223:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
		default:
			return -E_INVAL;
	}
	//panic("syscall not implemented");
}
f0105228:	83 c4 2c             	add    $0x2c,%esp
f010522b:	5b                   	pop    %ebx
f010522c:	5e                   	pop    %esi
f010522d:	5f                   	pop    %edi
f010522e:	5d                   	pop    %ebp
f010522f:	c3                   	ret    

f0105230 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0105230:	55                   	push   %ebp
f0105231:	89 e5                	mov    %esp,%ebp
f0105233:	57                   	push   %edi
f0105234:	56                   	push   %esi
f0105235:	53                   	push   %ebx
f0105236:	83 ec 14             	sub    $0x14,%esp
f0105239:	89 45 ec             	mov    %eax,-0x14(%ebp)
f010523c:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f010523f:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0105242:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0105245:	8b 1a                	mov    (%edx),%ebx
f0105247:	8b 01                	mov    (%ecx),%eax
f0105249:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f010524c:	39 c3                	cmp    %eax,%ebx
f010524e:	0f 8f 9a 00 00 00    	jg     f01052ee <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f0105254:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f010525b:	8b 45 f0             	mov    -0x10(%ebp),%eax
f010525e:	01 d8                	add    %ebx,%eax
f0105260:	89 c7                	mov    %eax,%edi
f0105262:	c1 ef 1f             	shr    $0x1f,%edi
f0105265:	01 c7                	add    %eax,%edi
f0105267:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0105269:	39 df                	cmp    %ebx,%edi
f010526b:	0f 8c c4 00 00 00    	jl     f0105335 <stab_binsearch+0x105>
f0105271:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0105274:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0105277:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f010527a:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f010527e:	39 f0                	cmp    %esi,%eax
f0105280:	0f 84 b4 00 00 00    	je     f010533a <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0105286:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f0105288:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f010528b:	39 d8                	cmp    %ebx,%eax
f010528d:	0f 8c a2 00 00 00    	jl     f0105335 <stab_binsearch+0x105>
f0105293:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f0105297:	83 ea 0c             	sub    $0xc,%edx
f010529a:	39 f1                	cmp    %esi,%ecx
f010529c:	75 ea                	jne    f0105288 <stab_binsearch+0x58>
f010529e:	e9 99 00 00 00       	jmp    f010533c <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f01052a3:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f01052a6:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f01052a8:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01052ab:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01052b2:	eb 2b                	jmp    f01052df <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f01052b4:	3b 55 0c             	cmp    0xc(%ebp),%edx
f01052b7:	76 14                	jbe    f01052cd <stab_binsearch+0x9d>
			*region_right = m - 1;
f01052b9:	83 e8 01             	sub    $0x1,%eax
f01052bc:	89 45 f0             	mov    %eax,-0x10(%ebp)
f01052bf:	8b 7d e0             	mov    -0x20(%ebp),%edi
f01052c2:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01052c4:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01052cb:	eb 12                	jmp    f01052df <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f01052cd:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01052d0:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f01052d2:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f01052d6:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01052d8:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f01052df:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f01052e2:	0f 8e 73 ff ff ff    	jle    f010525b <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f01052e8:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f01052ec:	75 0f                	jne    f01052fd <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f01052ee:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01052f1:	8b 00                	mov    (%eax),%eax
f01052f3:	83 e8 01             	sub    $0x1,%eax
f01052f6:	8b 75 e0             	mov    -0x20(%ebp),%esi
f01052f9:	89 06                	mov    %eax,(%esi)
f01052fb:	eb 57                	jmp    f0105354 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f01052fd:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105300:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0105302:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0105305:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0105307:	39 c8                	cmp    %ecx,%eax
f0105309:	7e 23                	jle    f010532e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f010530b:	8d 14 40             	lea    (%eax,%eax,2),%edx
f010530e:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0105311:	8d 14 97             	lea    (%edi,%edx,4),%edx
f0105314:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f0105318:	39 f3                	cmp    %esi,%ebx
f010531a:	74 12                	je     f010532e <stab_binsearch+0xfe>
		     l--)
f010531c:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f010531f:	39 c8                	cmp    %ecx,%eax
f0105321:	7e 0b                	jle    f010532e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0105323:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f0105327:	83 ea 0c             	sub    $0xc,%edx
f010532a:	39 f3                	cmp    %esi,%ebx
f010532c:	75 ee                	jne    f010531c <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f010532e:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0105331:	89 06                	mov    %eax,(%esi)
f0105333:	eb 1f                	jmp    f0105354 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0105335:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0105338:	eb a5                	jmp    f01052df <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f010533a:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f010533c:	8d 14 40             	lea    (%eax,%eax,2),%edx
f010533f:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0105342:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0105346:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0105349:	0f 82 54 ff ff ff    	jb     f01052a3 <stab_binsearch+0x73>
f010534f:	e9 60 ff ff ff       	jmp    f01052b4 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0105354:	83 c4 14             	add    $0x14,%esp
f0105357:	5b                   	pop    %ebx
f0105358:	5e                   	pop    %esi
f0105359:	5f                   	pop    %edi
f010535a:	5d                   	pop    %ebp
f010535b:	c3                   	ret    

f010535c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f010535c:	55                   	push   %ebp
f010535d:	89 e5                	mov    %esp,%ebp
f010535f:	57                   	push   %edi
f0105360:	56                   	push   %esi
f0105361:	53                   	push   %ebx
f0105362:	83 ec 3c             	sub    $0x3c,%esp
f0105365:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105368:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f010536b:	c7 06 b8 81 10 f0    	movl   $0xf01081b8,(%esi)
	info->eip_line = 0;
f0105371:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0105378:	c7 46 08 b8 81 10 f0 	movl   $0xf01081b8,0x8(%esi)
	info->eip_fn_namelen = 9;
f010537f:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0105386:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0105389:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0105390:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f0105396:	0f 87 ca 00 00 00    	ja     f0105466 <debuginfo_eip+0x10a>
		const struct UserStabData *usd = (const struct UserStabData *) USTABDATA;

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
f010539c:	e8 e2 11 00 00       	call   f0106583 <cpunum>
f01053a1:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f01053a8:	00 
f01053a9:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
f01053b0:	00 
f01053b1:	c7 44 24 04 00 00 20 	movl   $0x200000,0x4(%esp)
f01053b8:	00 
f01053b9:	6b c0 74             	imul   $0x74,%eax,%eax
f01053bc:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f01053c2:	89 04 24             	mov    %eax,(%esp)
f01053c5:	e8 97 e0 ff ff       	call   f0103461 <user_mem_check>
f01053ca:	85 c0                	test   %eax,%eax
f01053cc:	0f 85 12 02 00 00    	jne    f01055e4 <debuginfo_eip+0x288>
			return -1;
		stabs = usd->stabs;
f01053d2:	a1 00 00 20 00       	mov    0x200000,%eax
f01053d7:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f01053da:	8b 1d 04 00 20 00    	mov    0x200004,%ebx
		stabstr = usd->stabstr;
f01053e0:	8b 15 08 00 20 00    	mov    0x200008,%edx
f01053e6:	89 55 d0             	mov    %edx,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f01053e9:	a1 0c 00 20 00       	mov    0x20000c,%eax
f01053ee:	89 45 cc             	mov    %eax,-0x34(%ebp)

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
f01053f1:	e8 8d 11 00 00       	call   f0106583 <cpunum>
f01053f6:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f01053fd:	00 
f01053fe:	89 da                	mov    %ebx,%edx
f0105400:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0105403:	29 ca                	sub    %ecx,%edx
f0105405:	c1 fa 02             	sar    $0x2,%edx
f0105408:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f010540e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0105412:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0105416:	6b c0 74             	imul   $0x74,%eax,%eax
f0105419:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f010541f:	89 04 24             	mov    %eax,(%esp)
f0105422:	e8 3a e0 ff ff       	call   f0103461 <user_mem_check>
f0105427:	85 c0                	test   %eax,%eax
f0105429:	0f 85 bc 01 00 00    	jne    f01055eb <debuginfo_eip+0x28f>
f010542f:	e8 4f 11 00 00       	call   f0106583 <cpunum>
f0105434:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f010543b:	00 
f010543c:	8b 55 cc             	mov    -0x34(%ebp),%edx
f010543f:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0105442:	29 ca                	sub    %ecx,%edx
f0105444:	89 54 24 08          	mov    %edx,0x8(%esp)
f0105448:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f010544c:	6b c0 74             	imul   $0x74,%eax,%eax
f010544f:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0105455:	89 04 24             	mov    %eax,(%esp)
f0105458:	e8 04 e0 ff ff       	call   f0103461 <user_mem_check>
f010545d:	85 c0                	test   %eax,%eax
f010545f:	74 1f                	je     f0105480 <debuginfo_eip+0x124>
f0105461:	e9 8c 01 00 00       	jmp    f01055f2 <debuginfo_eip+0x296>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f0105466:	c7 45 cc d6 63 11 f0 	movl   $0xf01163d6,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f010546d:	c7 45 d0 61 2e 11 f0 	movl   $0xf0112e61,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f0105474:	bb 60 2e 11 f0       	mov    $0xf0112e60,%ebx
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f0105479:	c7 45 d4 50 87 10 f0 	movl   $0xf0108750,-0x2c(%ebp)
		    return -1;
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0105480:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0105483:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0105486:	0f 83 6d 01 00 00    	jae    f01055f9 <debuginfo_eip+0x29d>
f010548c:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f0105490:	0f 85 6a 01 00 00    	jne    f0105600 <debuginfo_eip+0x2a4>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0105496:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f010549d:	2b 5d d4             	sub    -0x2c(%ebp),%ebx
f01054a0:	c1 fb 02             	sar    $0x2,%ebx
f01054a3:	69 c3 ab aa aa aa    	imul   $0xaaaaaaab,%ebx,%eax
f01054a9:	83 e8 01             	sub    $0x1,%eax
f01054ac:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f01054af:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01054b3:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f01054ba:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f01054bd:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f01054c0:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f01054c3:	89 d8                	mov    %ebx,%eax
f01054c5:	e8 66 fd ff ff       	call   f0105230 <stab_binsearch>
	if (lfile == 0)
f01054ca:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01054cd:	85 c0                	test   %eax,%eax
f01054cf:	0f 84 32 01 00 00    	je     f0105607 <debuginfo_eip+0x2ab>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f01054d5:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f01054d8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01054db:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f01054de:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01054e2:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f01054e9:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f01054ec:	8d 55 dc             	lea    -0x24(%ebp),%edx
f01054ef:	89 d8                	mov    %ebx,%eax
f01054f1:	e8 3a fd ff ff       	call   f0105230 <stab_binsearch>

	if (lfun <= rfun) {
f01054f6:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f01054f9:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f01054fc:	7f 23                	jg     f0105521 <debuginfo_eip+0x1c5>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f01054fe:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0105501:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0105504:	8d 04 87             	lea    (%edi,%eax,4),%eax
f0105507:	8b 10                	mov    (%eax),%edx
f0105509:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f010550c:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f010550f:	39 ca                	cmp    %ecx,%edx
f0105511:	73 06                	jae    f0105519 <debuginfo_eip+0x1bd>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0105513:	03 55 d0             	add    -0x30(%ebp),%edx
f0105516:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f0105519:	8b 40 08             	mov    0x8(%eax),%eax
f010551c:	89 46 10             	mov    %eax,0x10(%esi)
f010551f:	eb 06                	jmp    f0105527 <debuginfo_eip+0x1cb>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0105521:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f0105524:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0105527:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f010552e:	00 
f010552f:	8b 46 08             	mov    0x8(%esi),%eax
f0105532:	89 04 24             	mov    %eax,(%esp)
f0105535:	e8 85 09 00 00       	call   f0105ebf <strfind>
f010553a:	2b 46 08             	sub    0x8(%esi),%eax
f010553d:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0105540:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0105543:	39 fb                	cmp    %edi,%ebx
f0105545:	7c 5d                	jl     f01055a4 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0105547:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f010554a:	c1 e0 02             	shl    $0x2,%eax
f010554d:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0105550:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f0105553:	89 55 c8             	mov    %edx,-0x38(%ebp)
f0105556:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f010555a:	80 fa 84             	cmp    $0x84,%dl
f010555d:	74 2d                	je     f010558c <debuginfo_eip+0x230>
f010555f:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f0105563:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0105566:	eb 15                	jmp    f010557d <debuginfo_eip+0x221>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0105568:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f010556b:	39 fb                	cmp    %edi,%ebx
f010556d:	7c 35                	jl     f01055a4 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f010556f:	89 c1                	mov    %eax,%ecx
f0105571:	83 e8 0c             	sub    $0xc,%eax
f0105574:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0105578:	80 fa 84             	cmp    $0x84,%dl
f010557b:	74 0f                	je     f010558c <debuginfo_eip+0x230>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f010557d:	80 fa 64             	cmp    $0x64,%dl
f0105580:	75 e6                	jne    f0105568 <debuginfo_eip+0x20c>
f0105582:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f0105586:	74 e0                	je     f0105568 <debuginfo_eip+0x20c>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0105588:	39 df                	cmp    %ebx,%edi
f010558a:	7f 18                	jg     f01055a4 <debuginfo_eip+0x248>
f010558c:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f010558f:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0105592:	8b 04 87             	mov    (%edi,%eax,4),%eax
f0105595:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0105598:	2b 55 d0             	sub    -0x30(%ebp),%edx
f010559b:	39 d0                	cmp    %edx,%eax
f010559d:	73 05                	jae    f01055a4 <debuginfo_eip+0x248>
		info->eip_file = stabstr + stabs[lline].n_strx;
f010559f:	03 45 d0             	add    -0x30(%ebp),%eax
f01055a2:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f01055a4:	8b 55 dc             	mov    -0x24(%ebp),%edx
f01055a7:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f01055aa:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f01055af:	39 ca                	cmp    %ecx,%edx
f01055b1:	7d 75                	jge    f0105628 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
f01055b3:	8d 42 01             	lea    0x1(%edx),%eax
f01055b6:	39 c1                	cmp    %eax,%ecx
f01055b8:	7e 54                	jle    f010560e <debuginfo_eip+0x2b2>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f01055ba:	8d 14 40             	lea    (%eax,%eax,2),%edx
f01055bd:	c1 e2 02             	shl    $0x2,%edx
f01055c0:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f01055c3:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f01055c8:	75 4b                	jne    f0105615 <debuginfo_eip+0x2b9>
f01055ca:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f01055ce:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f01055d2:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f01055d5:	39 c1                	cmp    %eax,%ecx
f01055d7:	7e 43                	jle    f010561c <debuginfo_eip+0x2c0>
f01055d9:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f01055dc:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f01055e0:	74 ec                	je     f01055ce <debuginfo_eip+0x272>
f01055e2:	eb 3f                	jmp    f0105623 <debuginfo_eip+0x2c7>

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
			return -1;
f01055e4:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01055e9:	eb 3d                	jmp    f0105628 <debuginfo_eip+0x2cc>

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
		 {
		    return -1;
f01055eb:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01055f0:	eb 36                	jmp    f0105628 <debuginfo_eip+0x2cc>
f01055f2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01055f7:	eb 2f                	jmp    f0105628 <debuginfo_eip+0x2cc>
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f01055f9:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01055fe:	eb 28                	jmp    f0105628 <debuginfo_eip+0x2cc>
f0105600:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105605:	eb 21                	jmp    f0105628 <debuginfo_eip+0x2cc>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0105607:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f010560c:	eb 1a                	jmp    f0105628 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f010560e:	b8 00 00 00 00       	mov    $0x0,%eax
f0105613:	eb 13                	jmp    f0105628 <debuginfo_eip+0x2cc>
f0105615:	b8 00 00 00 00       	mov    $0x0,%eax
f010561a:	eb 0c                	jmp    f0105628 <debuginfo_eip+0x2cc>
f010561c:	b8 00 00 00 00       	mov    $0x0,%eax
f0105621:	eb 05                	jmp    f0105628 <debuginfo_eip+0x2cc>
f0105623:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105628:	83 c4 3c             	add    $0x3c,%esp
f010562b:	5b                   	pop    %ebx
f010562c:	5e                   	pop    %esi
f010562d:	5f                   	pop    %edi
f010562e:	5d                   	pop    %ebp
f010562f:	c3                   	ret    

f0105630 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0105630:	55                   	push   %ebp
f0105631:	89 e5                	mov    %esp,%ebp
f0105633:	57                   	push   %edi
f0105634:	56                   	push   %esi
f0105635:	53                   	push   %ebx
f0105636:	83 ec 3c             	sub    $0x3c,%esp
f0105639:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010563c:	89 d7                	mov    %edx,%edi
f010563e:	8b 45 08             	mov    0x8(%ebp),%eax
f0105641:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0105644:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105647:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f010564a:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f010564d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105652:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0105655:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0105658:	39 f1                	cmp    %esi,%ecx
f010565a:	72 14                	jb     f0105670 <printnum+0x40>
f010565c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f010565f:	76 0f                	jbe    f0105670 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0105661:	8b 45 14             	mov    0x14(%ebp),%eax
f0105664:	8d 70 ff             	lea    -0x1(%eax),%esi
f0105667:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f010566a:	85 f6                	test   %esi,%esi
f010566c:	7f 60                	jg     f01056ce <printnum+0x9e>
f010566e:	eb 72                	jmp    f01056e2 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0105670:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0105673:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0105677:	8b 4d 14             	mov    0x14(%ebp),%ecx
f010567a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f010567d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0105681:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105685:	8b 44 24 08          	mov    0x8(%esp),%eax
f0105689:	8b 54 24 0c          	mov    0xc(%esp),%edx
f010568d:	89 c3                	mov    %eax,%ebx
f010568f:	89 d6                	mov    %edx,%esi
f0105691:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0105694:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0105697:	89 54 24 08          	mov    %edx,0x8(%esp)
f010569b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f010569f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01056a2:	89 04 24             	mov    %eax,(%esp)
f01056a5:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01056a8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01056ac:	e8 3f 13 00 00       	call   f01069f0 <__udivdi3>
f01056b1:	89 d9                	mov    %ebx,%ecx
f01056b3:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01056b7:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01056bb:	89 04 24             	mov    %eax,(%esp)
f01056be:	89 54 24 04          	mov    %edx,0x4(%esp)
f01056c2:	89 fa                	mov    %edi,%edx
f01056c4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01056c7:	e8 64 ff ff ff       	call   f0105630 <printnum>
f01056cc:	eb 14                	jmp    f01056e2 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f01056ce:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01056d2:	8b 45 18             	mov    0x18(%ebp),%eax
f01056d5:	89 04 24             	mov    %eax,(%esp)
f01056d8:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f01056da:	83 ee 01             	sub    $0x1,%esi
f01056dd:	75 ef                	jne    f01056ce <printnum+0x9e>
f01056df:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f01056e2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01056e6:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01056ea:	8b 45 d8             	mov    -0x28(%ebp),%eax
f01056ed:	8b 55 dc             	mov    -0x24(%ebp),%edx
f01056f0:	89 44 24 08          	mov    %eax,0x8(%esp)
f01056f4:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01056f8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01056fb:	89 04 24             	mov    %eax,(%esp)
f01056fe:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105701:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105705:	e8 16 14 00 00       	call   f0106b20 <__umoddi3>
f010570a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010570e:	0f be 80 c2 81 10 f0 	movsbl -0xfef7e3e(%eax),%eax
f0105715:	89 04 24             	mov    %eax,(%esp)
f0105718:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010571b:	ff d0                	call   *%eax
}
f010571d:	83 c4 3c             	add    $0x3c,%esp
f0105720:	5b                   	pop    %ebx
f0105721:	5e                   	pop    %esi
f0105722:	5f                   	pop    %edi
f0105723:	5d                   	pop    %ebp
f0105724:	c3                   	ret    

f0105725 <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0105725:	55                   	push   %ebp
f0105726:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0105728:	83 fa 01             	cmp    $0x1,%edx
f010572b:	7e 0e                	jle    f010573b <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f010572d:	8b 10                	mov    (%eax),%edx
f010572f:	8d 4a 08             	lea    0x8(%edx),%ecx
f0105732:	89 08                	mov    %ecx,(%eax)
f0105734:	8b 02                	mov    (%edx),%eax
f0105736:	8b 52 04             	mov    0x4(%edx),%edx
f0105739:	eb 22                	jmp    f010575d <getuint+0x38>
	else if (lflag)
f010573b:	85 d2                	test   %edx,%edx
f010573d:	74 10                	je     f010574f <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f010573f:	8b 10                	mov    (%eax),%edx
f0105741:	8d 4a 04             	lea    0x4(%edx),%ecx
f0105744:	89 08                	mov    %ecx,(%eax)
f0105746:	8b 02                	mov    (%edx),%eax
f0105748:	ba 00 00 00 00       	mov    $0x0,%edx
f010574d:	eb 0e                	jmp    f010575d <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f010574f:	8b 10                	mov    (%eax),%edx
f0105751:	8d 4a 04             	lea    0x4(%edx),%ecx
f0105754:	89 08                	mov    %ecx,(%eax)
f0105756:	8b 02                	mov    (%edx),%eax
f0105758:	ba 00 00 00 00       	mov    $0x0,%edx
}
f010575d:	5d                   	pop    %ebp
f010575e:	c3                   	ret    

f010575f <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f010575f:	55                   	push   %ebp
f0105760:	89 e5                	mov    %esp,%ebp
f0105762:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0105765:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0105769:	8b 10                	mov    (%eax),%edx
f010576b:	3b 50 04             	cmp    0x4(%eax),%edx
f010576e:	73 0a                	jae    f010577a <sprintputch+0x1b>
		*b->buf++ = ch;
f0105770:	8d 4a 01             	lea    0x1(%edx),%ecx
f0105773:	89 08                	mov    %ecx,(%eax)
f0105775:	8b 45 08             	mov    0x8(%ebp),%eax
f0105778:	88 02                	mov    %al,(%edx)
}
f010577a:	5d                   	pop    %ebp
f010577b:	c3                   	ret    

f010577c <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f010577c:	55                   	push   %ebp
f010577d:	89 e5                	mov    %esp,%ebp
f010577f:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0105782:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0105785:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105789:	8b 45 10             	mov    0x10(%ebp),%eax
f010578c:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105790:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105793:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105797:	8b 45 08             	mov    0x8(%ebp),%eax
f010579a:	89 04 24             	mov    %eax,(%esp)
f010579d:	e8 02 00 00 00       	call   f01057a4 <vprintfmt>
	va_end(ap);
}
f01057a2:	c9                   	leave  
f01057a3:	c3                   	ret    

f01057a4 <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f01057a4:	55                   	push   %ebp
f01057a5:	89 e5                	mov    %esp,%ebp
f01057a7:	57                   	push   %edi
f01057a8:	56                   	push   %esi
f01057a9:	53                   	push   %ebx
f01057aa:	83 ec 3c             	sub    $0x3c,%esp
f01057ad:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01057b0:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01057b3:	eb 18                	jmp    f01057cd <vprintfmt+0x29>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f01057b5:	85 c0                	test   %eax,%eax
f01057b7:	0f 84 c3 03 00 00    	je     f0105b80 <vprintfmt+0x3dc>
				return;
			putch(ch, putdat);
f01057bd:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01057c1:	89 04 24             	mov    %eax,(%esp)
f01057c4:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01057c7:	89 f3                	mov    %esi,%ebx
f01057c9:	eb 02                	jmp    f01057cd <vprintfmt+0x29>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f01057cb:	89 f3                	mov    %esi,%ebx
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01057cd:	8d 73 01             	lea    0x1(%ebx),%esi
f01057d0:	0f b6 03             	movzbl (%ebx),%eax
f01057d3:	83 f8 25             	cmp    $0x25,%eax
f01057d6:	75 dd                	jne    f01057b5 <vprintfmt+0x11>
f01057d8:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f01057dc:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f01057e3:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f01057ea:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f01057f1:	ba 00 00 00 00       	mov    $0x0,%edx
f01057f6:	eb 1d                	jmp    f0105815 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01057f8:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f01057fa:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f01057fe:	eb 15                	jmp    f0105815 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105800:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0105802:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f0105806:	eb 0d                	jmp    f0105815 <vprintfmt+0x71>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0105808:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010580b:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010580e:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105815:	8d 5e 01             	lea    0x1(%esi),%ebx
f0105818:	0f b6 06             	movzbl (%esi),%eax
f010581b:	0f b6 c8             	movzbl %al,%ecx
f010581e:	83 e8 23             	sub    $0x23,%eax
f0105821:	3c 55                	cmp    $0x55,%al
f0105823:	0f 87 2f 03 00 00    	ja     f0105b58 <vprintfmt+0x3b4>
f0105829:	0f b6 c0             	movzbl %al,%eax
f010582c:	ff 24 85 00 83 10 f0 	jmp    *-0xfef7d00(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0105833:	8d 41 d0             	lea    -0x30(%ecx),%eax
f0105836:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0105839:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f010583d:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0105840:	83 f9 09             	cmp    $0x9,%ecx
f0105843:	77 50                	ja     f0105895 <vprintfmt+0xf1>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105845:	89 de                	mov    %ebx,%esi
f0105847:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f010584a:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f010584d:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0105850:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0105854:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0105857:	8d 58 d0             	lea    -0x30(%eax),%ebx
f010585a:	83 fb 09             	cmp    $0x9,%ebx
f010585d:	76 eb                	jbe    f010584a <vprintfmt+0xa6>
f010585f:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0105862:	eb 33                	jmp    f0105897 <vprintfmt+0xf3>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0105864:	8b 45 14             	mov    0x14(%ebp),%eax
f0105867:	8d 48 04             	lea    0x4(%eax),%ecx
f010586a:	89 4d 14             	mov    %ecx,0x14(%ebp)
f010586d:	8b 00                	mov    (%eax),%eax
f010586f:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105872:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0105874:	eb 21                	jmp    f0105897 <vprintfmt+0xf3>
f0105876:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0105879:	85 c9                	test   %ecx,%ecx
f010587b:	b8 00 00 00 00       	mov    $0x0,%eax
f0105880:	0f 49 c1             	cmovns %ecx,%eax
f0105883:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105886:	89 de                	mov    %ebx,%esi
f0105888:	eb 8b                	jmp    f0105815 <vprintfmt+0x71>
f010588a:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f010588c:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f0105893:	eb 80                	jmp    f0105815 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105895:	89 de                	mov    %ebx,%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0105897:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f010589b:	0f 89 74 ff ff ff    	jns    f0105815 <vprintfmt+0x71>
f01058a1:	e9 62 ff ff ff       	jmp    f0105808 <vprintfmt+0x64>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f01058a6:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01058a9:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f01058ab:	e9 65 ff ff ff       	jmp    f0105815 <vprintfmt+0x71>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f01058b0:	8b 45 14             	mov    0x14(%ebp),%eax
f01058b3:	8d 50 04             	lea    0x4(%eax),%edx
f01058b6:	89 55 14             	mov    %edx,0x14(%ebp)
f01058b9:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01058bd:	8b 00                	mov    (%eax),%eax
f01058bf:	89 04 24             	mov    %eax,(%esp)
f01058c2:	ff 55 08             	call   *0x8(%ebp)
			break;
f01058c5:	e9 03 ff ff ff       	jmp    f01057cd <vprintfmt+0x29>

		// error message
		case 'e':
			err = va_arg(ap, int);
f01058ca:	8b 45 14             	mov    0x14(%ebp),%eax
f01058cd:	8d 50 04             	lea    0x4(%eax),%edx
f01058d0:	89 55 14             	mov    %edx,0x14(%ebp)
f01058d3:	8b 00                	mov    (%eax),%eax
f01058d5:	99                   	cltd   
f01058d6:	31 d0                	xor    %edx,%eax
f01058d8:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f01058da:	83 f8 0f             	cmp    $0xf,%eax
f01058dd:	7f 0b                	jg     f01058ea <vprintfmt+0x146>
f01058df:	8b 14 85 60 84 10 f0 	mov    -0xfef7ba0(,%eax,4),%edx
f01058e6:	85 d2                	test   %edx,%edx
f01058e8:	75 20                	jne    f010590a <vprintfmt+0x166>
				printfmt(putch, putdat, "error %d", err);
f01058ea:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01058ee:	c7 44 24 08 da 81 10 	movl   $0xf01081da,0x8(%esp)
f01058f5:	f0 
f01058f6:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01058fa:	8b 45 08             	mov    0x8(%ebp),%eax
f01058fd:	89 04 24             	mov    %eax,(%esp)
f0105900:	e8 77 fe ff ff       	call   f010577c <printfmt>
f0105905:	e9 c3 fe ff ff       	jmp    f01057cd <vprintfmt+0x29>
			else
				printfmt(putch, putdat, "%s", p);
f010590a:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010590e:	c7 44 24 08 05 7a 10 	movl   $0xf0107a05,0x8(%esp)
f0105915:	f0 
f0105916:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010591a:	8b 45 08             	mov    0x8(%ebp),%eax
f010591d:	89 04 24             	mov    %eax,(%esp)
f0105920:	e8 57 fe ff ff       	call   f010577c <printfmt>
f0105925:	e9 a3 fe ff ff       	jmp    f01057cd <vprintfmt+0x29>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010592a:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f010592d:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0105930:	8b 45 14             	mov    0x14(%ebp),%eax
f0105933:	8d 50 04             	lea    0x4(%eax),%edx
f0105936:	89 55 14             	mov    %edx,0x14(%ebp)
f0105939:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f010593b:	85 c0                	test   %eax,%eax
f010593d:	ba d3 81 10 f0       	mov    $0xf01081d3,%edx
f0105942:	0f 45 d0             	cmovne %eax,%edx
f0105945:	89 55 d0             	mov    %edx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f0105948:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f010594c:	74 04                	je     f0105952 <vprintfmt+0x1ae>
f010594e:	85 f6                	test   %esi,%esi
f0105950:	7f 19                	jg     f010596b <vprintfmt+0x1c7>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0105952:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0105955:	8d 70 01             	lea    0x1(%eax),%esi
f0105958:	0f b6 10             	movzbl (%eax),%edx
f010595b:	0f be c2             	movsbl %dl,%eax
f010595e:	85 c0                	test   %eax,%eax
f0105960:	0f 85 95 00 00 00    	jne    f01059fb <vprintfmt+0x257>
f0105966:	e9 85 00 00 00       	jmp    f01059f0 <vprintfmt+0x24c>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f010596b:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f010596f:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0105972:	89 04 24             	mov    %eax,(%esp)
f0105975:	e8 88 03 00 00       	call   f0105d02 <strnlen>
f010597a:	29 c6                	sub    %eax,%esi
f010597c:	89 f0                	mov    %esi,%eax
f010597e:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0105981:	85 f6                	test   %esi,%esi
f0105983:	7e cd                	jle    f0105952 <vprintfmt+0x1ae>
					putch(padc, putdat);
f0105985:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105989:	89 5d 10             	mov    %ebx,0x10(%ebp)
f010598c:	89 c3                	mov    %eax,%ebx
f010598e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105992:	89 34 24             	mov    %esi,(%esp)
f0105995:	ff 55 08             	call   *0x8(%ebp)
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0105998:	83 eb 01             	sub    $0x1,%ebx
f010599b:	75 f1                	jne    f010598e <vprintfmt+0x1ea>
f010599d:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f01059a0:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01059a3:	eb ad                	jmp    f0105952 <vprintfmt+0x1ae>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f01059a5:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f01059a9:	74 1e                	je     f01059c9 <vprintfmt+0x225>
f01059ab:	0f be d2             	movsbl %dl,%edx
f01059ae:	83 ea 20             	sub    $0x20,%edx
f01059b1:	83 fa 5e             	cmp    $0x5e,%edx
f01059b4:	76 13                	jbe    f01059c9 <vprintfmt+0x225>
					putch('?', putdat);
f01059b6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01059b9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01059bd:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f01059c4:	ff 55 08             	call   *0x8(%ebp)
f01059c7:	eb 0d                	jmp    f01059d6 <vprintfmt+0x232>
				else
					putch(ch, putdat);
f01059c9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01059cc:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01059d0:	89 04 24             	mov    %eax,(%esp)
f01059d3:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01059d6:	83 ef 01             	sub    $0x1,%edi
f01059d9:	83 c6 01             	add    $0x1,%esi
f01059dc:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f01059e0:	0f be c2             	movsbl %dl,%eax
f01059e3:	85 c0                	test   %eax,%eax
f01059e5:	75 20                	jne    f0105a07 <vprintfmt+0x263>
f01059e7:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f01059ea:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01059ed:	8b 5d 10             	mov    0x10(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01059f0:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01059f4:	7f 25                	jg     f0105a1b <vprintfmt+0x277>
f01059f6:	e9 d2 fd ff ff       	jmp    f01057cd <vprintfmt+0x29>
f01059fb:	89 7d 0c             	mov    %edi,0xc(%ebp)
f01059fe:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0105a01:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0105a04:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0105a07:	85 db                	test   %ebx,%ebx
f0105a09:	78 9a                	js     f01059a5 <vprintfmt+0x201>
f0105a0b:	83 eb 01             	sub    $0x1,%ebx
f0105a0e:	79 95                	jns    f01059a5 <vprintfmt+0x201>
f0105a10:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f0105a13:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0105a16:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0105a19:	eb d5                	jmp    f01059f0 <vprintfmt+0x24c>
f0105a1b:	8b 75 08             	mov    0x8(%ebp),%esi
f0105a1e:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0105a21:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0105a24:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105a28:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f0105a2f:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0105a31:	83 eb 01             	sub    $0x1,%ebx
f0105a34:	75 ee                	jne    f0105a24 <vprintfmt+0x280>
f0105a36:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0105a39:	e9 8f fd ff ff       	jmp    f01057cd <vprintfmt+0x29>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f0105a3e:	83 fa 01             	cmp    $0x1,%edx
f0105a41:	7e 16                	jle    f0105a59 <vprintfmt+0x2b5>
		return va_arg(*ap, long long);
f0105a43:	8b 45 14             	mov    0x14(%ebp),%eax
f0105a46:	8d 50 08             	lea    0x8(%eax),%edx
f0105a49:	89 55 14             	mov    %edx,0x14(%ebp)
f0105a4c:	8b 50 04             	mov    0x4(%eax),%edx
f0105a4f:	8b 00                	mov    (%eax),%eax
f0105a51:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0105a54:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0105a57:	eb 32                	jmp    f0105a8b <vprintfmt+0x2e7>
	else if (lflag)
f0105a59:	85 d2                	test   %edx,%edx
f0105a5b:	74 18                	je     f0105a75 <vprintfmt+0x2d1>
		return va_arg(*ap, long);
f0105a5d:	8b 45 14             	mov    0x14(%ebp),%eax
f0105a60:	8d 50 04             	lea    0x4(%eax),%edx
f0105a63:	89 55 14             	mov    %edx,0x14(%ebp)
f0105a66:	8b 30                	mov    (%eax),%esi
f0105a68:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105a6b:	89 f0                	mov    %esi,%eax
f0105a6d:	c1 f8 1f             	sar    $0x1f,%eax
f0105a70:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0105a73:	eb 16                	jmp    f0105a8b <vprintfmt+0x2e7>
	else
		return va_arg(*ap, int);
f0105a75:	8b 45 14             	mov    0x14(%ebp),%eax
f0105a78:	8d 50 04             	lea    0x4(%eax),%edx
f0105a7b:	89 55 14             	mov    %edx,0x14(%ebp)
f0105a7e:	8b 30                	mov    (%eax),%esi
f0105a80:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105a83:	89 f0                	mov    %esi,%eax
f0105a85:	c1 f8 1f             	sar    $0x1f,%eax
f0105a88:	89 45 dc             	mov    %eax,-0x24(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f0105a8b:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0105a8e:	8b 55 dc             	mov    -0x24(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f0105a91:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0105a96:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f0105a9a:	0f 89 80 00 00 00    	jns    f0105b20 <vprintfmt+0x37c>
				putch('-', putdat);
f0105aa0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105aa4:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f0105aab:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f0105aae:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0105ab1:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0105ab4:	f7 d8                	neg    %eax
f0105ab6:	83 d2 00             	adc    $0x0,%edx
f0105ab9:	f7 da                	neg    %edx
			}
			base = 10;
f0105abb:	b9 0a 00 00 00       	mov    $0xa,%ecx
f0105ac0:	eb 5e                	jmp    f0105b20 <vprintfmt+0x37c>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f0105ac2:	8d 45 14             	lea    0x14(%ebp),%eax
f0105ac5:	e8 5b fc ff ff       	call   f0105725 <getuint>
			base = 10;
f0105aca:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f0105acf:	eb 4f                	jmp    f0105b20 <vprintfmt+0x37c>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			//putch('X', putdat);
			num = getuint(&ap, lflag);
f0105ad1:	8d 45 14             	lea    0x14(%ebp),%eax
f0105ad4:	e8 4c fc ff ff       	call   f0105725 <getuint>
			base = 8;
f0105ad9:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f0105ade:	eb 40                	jmp    f0105b20 <vprintfmt+0x37c>
			//putch('X', putdat);
			//break;

		// pointer
		case 'p':
			putch('0', putdat);
f0105ae0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105ae4:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f0105aeb:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f0105aee:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105af2:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f0105af9:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f0105afc:	8b 45 14             	mov    0x14(%ebp),%eax
f0105aff:	8d 50 04             	lea    0x4(%eax),%edx
f0105b02:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f0105b05:	8b 00                	mov    (%eax),%eax
f0105b07:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f0105b0c:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f0105b11:	eb 0d                	jmp    f0105b20 <vprintfmt+0x37c>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f0105b13:	8d 45 14             	lea    0x14(%ebp),%eax
f0105b16:	e8 0a fc ff ff       	call   f0105725 <getuint>
			base = 16;
f0105b1b:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f0105b20:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105b24:	89 74 24 10          	mov    %esi,0x10(%esp)
f0105b28:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0105b2b:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105b2f:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0105b33:	89 04 24             	mov    %eax,(%esp)
f0105b36:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105b3a:	89 fa                	mov    %edi,%edx
f0105b3c:	8b 45 08             	mov    0x8(%ebp),%eax
f0105b3f:	e8 ec fa ff ff       	call   f0105630 <printnum>
			break;
f0105b44:	e9 84 fc ff ff       	jmp    f01057cd <vprintfmt+0x29>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0105b49:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105b4d:	89 0c 24             	mov    %ecx,(%esp)
f0105b50:	ff 55 08             	call   *0x8(%ebp)
			break;
f0105b53:	e9 75 fc ff ff       	jmp    f01057cd <vprintfmt+0x29>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0105b58:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105b5c:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0105b63:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f0105b66:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f0105b6a:	0f 84 5b fc ff ff    	je     f01057cb <vprintfmt+0x27>
f0105b70:	89 f3                	mov    %esi,%ebx
f0105b72:	83 eb 01             	sub    $0x1,%ebx
f0105b75:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f0105b79:	75 f7                	jne    f0105b72 <vprintfmt+0x3ce>
f0105b7b:	e9 4d fc ff ff       	jmp    f01057cd <vprintfmt+0x29>
				/* do nothing */;
			break;
		}
	}
}
f0105b80:	83 c4 3c             	add    $0x3c,%esp
f0105b83:	5b                   	pop    %ebx
f0105b84:	5e                   	pop    %esi
f0105b85:	5f                   	pop    %edi
f0105b86:	5d                   	pop    %ebp
f0105b87:	c3                   	ret    

f0105b88 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0105b88:	55                   	push   %ebp
f0105b89:	89 e5                	mov    %esp,%ebp
f0105b8b:	83 ec 28             	sub    $0x28,%esp
f0105b8e:	8b 45 08             	mov    0x8(%ebp),%eax
f0105b91:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0105b94:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0105b97:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f0105b9b:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f0105b9e:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0105ba5:	85 c0                	test   %eax,%eax
f0105ba7:	74 30                	je     f0105bd9 <vsnprintf+0x51>
f0105ba9:	85 d2                	test   %edx,%edx
f0105bab:	7e 2c                	jle    f0105bd9 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f0105bad:	8b 45 14             	mov    0x14(%ebp),%eax
f0105bb0:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105bb4:	8b 45 10             	mov    0x10(%ebp),%eax
f0105bb7:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105bbb:	8d 45 ec             	lea    -0x14(%ebp),%eax
f0105bbe:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105bc2:	c7 04 24 5f 57 10 f0 	movl   $0xf010575f,(%esp)
f0105bc9:	e8 d6 fb ff ff       	call   f01057a4 <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0105bce:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0105bd1:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0105bd4:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0105bd7:	eb 05                	jmp    f0105bde <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f0105bd9:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f0105bde:	c9                   	leave  
f0105bdf:	c3                   	ret    

f0105be0 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f0105be0:	55                   	push   %ebp
f0105be1:	89 e5                	mov    %esp,%ebp
f0105be3:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0105be6:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f0105be9:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105bed:	8b 45 10             	mov    0x10(%ebp),%eax
f0105bf0:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105bf4:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105bf7:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105bfb:	8b 45 08             	mov    0x8(%ebp),%eax
f0105bfe:	89 04 24             	mov    %eax,(%esp)
f0105c01:	e8 82 ff ff ff       	call   f0105b88 <vsnprintf>
	va_end(ap);

	return rc;
}
f0105c06:	c9                   	leave  
f0105c07:	c3                   	ret    
f0105c08:	66 90                	xchg   %ax,%ax
f0105c0a:	66 90                	xchg   %ax,%ax
f0105c0c:	66 90                	xchg   %ax,%ax
f0105c0e:	66 90                	xchg   %ax,%ax

f0105c10 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0105c10:	55                   	push   %ebp
f0105c11:	89 e5                	mov    %esp,%ebp
f0105c13:	57                   	push   %edi
f0105c14:	56                   	push   %esi
f0105c15:	53                   	push   %ebx
f0105c16:	83 ec 1c             	sub    $0x1c,%esp
f0105c19:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f0105c1c:	85 c0                	test   %eax,%eax
f0105c1e:	74 10                	je     f0105c30 <readline+0x20>
		cprintf("%s", prompt);
f0105c20:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105c24:	c7 04 24 05 7a 10 f0 	movl   $0xf0107a05,(%esp)
f0105c2b:	e8 46 e2 ff ff       	call   f0103e76 <cprintf>

	i = 0;
	echoing = iscons(0);
f0105c30:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0105c37:	e8 e2 ab ff ff       	call   f010081e <iscons>
f0105c3c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f0105c3e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0105c43:	e8 c5 ab ff ff       	call   f010080d <getchar>
f0105c48:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f0105c4a:	85 c0                	test   %eax,%eax
f0105c4c:	79 17                	jns    f0105c65 <readline+0x55>
			cprintf("read error: %e\n", c);
f0105c4e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105c52:	c7 04 24 bf 84 10 f0 	movl   $0xf01084bf,(%esp)
f0105c59:	e8 18 e2 ff ff       	call   f0103e76 <cprintf>
			return NULL;
f0105c5e:	b8 00 00 00 00       	mov    $0x0,%eax
f0105c63:	eb 6d                	jmp    f0105cd2 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0105c65:	83 f8 7f             	cmp    $0x7f,%eax
f0105c68:	74 05                	je     f0105c6f <readline+0x5f>
f0105c6a:	83 f8 08             	cmp    $0x8,%eax
f0105c6d:	75 19                	jne    f0105c88 <readline+0x78>
f0105c6f:	85 f6                	test   %esi,%esi
f0105c71:	7e 15                	jle    f0105c88 <readline+0x78>
			if (echoing)
f0105c73:	85 ff                	test   %edi,%edi
f0105c75:	74 0c                	je     f0105c83 <readline+0x73>
				cputchar('\b');
f0105c77:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f0105c7e:	e8 7a ab ff ff       	call   f01007fd <cputchar>
			i--;
f0105c83:	83 ee 01             	sub    $0x1,%esi
f0105c86:	eb bb                	jmp    f0105c43 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0105c88:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f0105c8e:	7f 1c                	jg     f0105cac <readline+0x9c>
f0105c90:	83 fb 1f             	cmp    $0x1f,%ebx
f0105c93:	7e 17                	jle    f0105cac <readline+0x9c>
			if (echoing)
f0105c95:	85 ff                	test   %edi,%edi
f0105c97:	74 08                	je     f0105ca1 <readline+0x91>
				cputchar(c);
f0105c99:	89 1c 24             	mov    %ebx,(%esp)
f0105c9c:	e8 5c ab ff ff       	call   f01007fd <cputchar>
			buf[i++] = c;
f0105ca1:	88 9e 80 7a 1c f0    	mov    %bl,-0xfe38580(%esi)
f0105ca7:	8d 76 01             	lea    0x1(%esi),%esi
f0105caa:	eb 97                	jmp    f0105c43 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f0105cac:	83 fb 0d             	cmp    $0xd,%ebx
f0105caf:	74 05                	je     f0105cb6 <readline+0xa6>
f0105cb1:	83 fb 0a             	cmp    $0xa,%ebx
f0105cb4:	75 8d                	jne    f0105c43 <readline+0x33>
			if (echoing)
f0105cb6:	85 ff                	test   %edi,%edi
f0105cb8:	74 0c                	je     f0105cc6 <readline+0xb6>
				cputchar('\n');
f0105cba:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0105cc1:	e8 37 ab ff ff       	call   f01007fd <cputchar>
			buf[i] = 0;
f0105cc6:	c6 86 80 7a 1c f0 00 	movb   $0x0,-0xfe38580(%esi)
			return buf;
f0105ccd:	b8 80 7a 1c f0       	mov    $0xf01c7a80,%eax
		}
	}
}
f0105cd2:	83 c4 1c             	add    $0x1c,%esp
f0105cd5:	5b                   	pop    %ebx
f0105cd6:	5e                   	pop    %esi
f0105cd7:	5f                   	pop    %edi
f0105cd8:	5d                   	pop    %ebp
f0105cd9:	c3                   	ret    
f0105cda:	66 90                	xchg   %ax,%ax
f0105cdc:	66 90                	xchg   %ax,%ax
f0105cde:	66 90                	xchg   %ax,%ax

f0105ce0 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0105ce0:	55                   	push   %ebp
f0105ce1:	89 e5                	mov    %esp,%ebp
f0105ce3:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0105ce6:	80 3a 00             	cmpb   $0x0,(%edx)
f0105ce9:	74 10                	je     f0105cfb <strlen+0x1b>
f0105ceb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f0105cf0:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0105cf3:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0105cf7:	75 f7                	jne    f0105cf0 <strlen+0x10>
f0105cf9:	eb 05                	jmp    f0105d00 <strlen+0x20>
f0105cfb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0105d00:	5d                   	pop    %ebp
f0105d01:	c3                   	ret    

f0105d02 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0105d02:	55                   	push   %ebp
f0105d03:	89 e5                	mov    %esp,%ebp
f0105d05:	53                   	push   %ebx
f0105d06:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105d09:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0105d0c:	85 c9                	test   %ecx,%ecx
f0105d0e:	74 1c                	je     f0105d2c <strnlen+0x2a>
f0105d10:	80 3b 00             	cmpb   $0x0,(%ebx)
f0105d13:	74 1e                	je     f0105d33 <strnlen+0x31>
f0105d15:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f0105d1a:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0105d1c:	39 ca                	cmp    %ecx,%edx
f0105d1e:	74 18                	je     f0105d38 <strnlen+0x36>
f0105d20:	83 c2 01             	add    $0x1,%edx
f0105d23:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0105d28:	75 f0                	jne    f0105d1a <strnlen+0x18>
f0105d2a:	eb 0c                	jmp    f0105d38 <strnlen+0x36>
f0105d2c:	b8 00 00 00 00       	mov    $0x0,%eax
f0105d31:	eb 05                	jmp    f0105d38 <strnlen+0x36>
f0105d33:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0105d38:	5b                   	pop    %ebx
f0105d39:	5d                   	pop    %ebp
f0105d3a:	c3                   	ret    

f0105d3b <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f0105d3b:	55                   	push   %ebp
f0105d3c:	89 e5                	mov    %esp,%ebp
f0105d3e:	53                   	push   %ebx
f0105d3f:	8b 45 08             	mov    0x8(%ebp),%eax
f0105d42:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0105d45:	89 c2                	mov    %eax,%edx
f0105d47:	83 c2 01             	add    $0x1,%edx
f0105d4a:	83 c1 01             	add    $0x1,%ecx
f0105d4d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0105d51:	88 5a ff             	mov    %bl,-0x1(%edx)
f0105d54:	84 db                	test   %bl,%bl
f0105d56:	75 ef                	jne    f0105d47 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0105d58:	5b                   	pop    %ebx
f0105d59:	5d                   	pop    %ebp
f0105d5a:	c3                   	ret    

f0105d5b <strcat>:

char *
strcat(char *dst, const char *src)
{
f0105d5b:	55                   	push   %ebp
f0105d5c:	89 e5                	mov    %esp,%ebp
f0105d5e:	53                   	push   %ebx
f0105d5f:	83 ec 08             	sub    $0x8,%esp
f0105d62:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f0105d65:	89 1c 24             	mov    %ebx,(%esp)
f0105d68:	e8 73 ff ff ff       	call   f0105ce0 <strlen>
	strcpy(dst + len, src);
f0105d6d:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105d70:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105d74:	01 d8                	add    %ebx,%eax
f0105d76:	89 04 24             	mov    %eax,(%esp)
f0105d79:	e8 bd ff ff ff       	call   f0105d3b <strcpy>
	return dst;
}
f0105d7e:	89 d8                	mov    %ebx,%eax
f0105d80:	83 c4 08             	add    $0x8,%esp
f0105d83:	5b                   	pop    %ebx
f0105d84:	5d                   	pop    %ebp
f0105d85:	c3                   	ret    

f0105d86 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f0105d86:	55                   	push   %ebp
f0105d87:	89 e5                	mov    %esp,%ebp
f0105d89:	56                   	push   %esi
f0105d8a:	53                   	push   %ebx
f0105d8b:	8b 75 08             	mov    0x8(%ebp),%esi
f0105d8e:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105d91:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0105d94:	85 db                	test   %ebx,%ebx
f0105d96:	74 17                	je     f0105daf <strncpy+0x29>
f0105d98:	01 f3                	add    %esi,%ebx
f0105d9a:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f0105d9c:	83 c1 01             	add    $0x1,%ecx
f0105d9f:	0f b6 02             	movzbl (%edx),%eax
f0105da2:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f0105da5:	80 3a 01             	cmpb   $0x1,(%edx)
f0105da8:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0105dab:	39 d9                	cmp    %ebx,%ecx
f0105dad:	75 ed                	jne    f0105d9c <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f0105daf:	89 f0                	mov    %esi,%eax
f0105db1:	5b                   	pop    %ebx
f0105db2:	5e                   	pop    %esi
f0105db3:	5d                   	pop    %ebp
f0105db4:	c3                   	ret    

f0105db5 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f0105db5:	55                   	push   %ebp
f0105db6:	89 e5                	mov    %esp,%ebp
f0105db8:	57                   	push   %edi
f0105db9:	56                   	push   %esi
f0105dba:	53                   	push   %ebx
f0105dbb:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105dbe:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0105dc1:	8b 75 10             	mov    0x10(%ebp),%esi
f0105dc4:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0105dc6:	85 f6                	test   %esi,%esi
f0105dc8:	74 34                	je     f0105dfe <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f0105dca:	83 fe 01             	cmp    $0x1,%esi
f0105dcd:	74 26                	je     f0105df5 <strlcpy+0x40>
f0105dcf:	0f b6 0b             	movzbl (%ebx),%ecx
f0105dd2:	84 c9                	test   %cl,%cl
f0105dd4:	74 23                	je     f0105df9 <strlcpy+0x44>
f0105dd6:	83 ee 02             	sub    $0x2,%esi
f0105dd9:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f0105dde:	83 c0 01             	add    $0x1,%eax
f0105de1:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0105de4:	39 f2                	cmp    %esi,%edx
f0105de6:	74 13                	je     f0105dfb <strlcpy+0x46>
f0105de8:	83 c2 01             	add    $0x1,%edx
f0105deb:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f0105def:	84 c9                	test   %cl,%cl
f0105df1:	75 eb                	jne    f0105dde <strlcpy+0x29>
f0105df3:	eb 06                	jmp    f0105dfb <strlcpy+0x46>
f0105df5:	89 f8                	mov    %edi,%eax
f0105df7:	eb 02                	jmp    f0105dfb <strlcpy+0x46>
f0105df9:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f0105dfb:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f0105dfe:	29 f8                	sub    %edi,%eax
}
f0105e00:	5b                   	pop    %ebx
f0105e01:	5e                   	pop    %esi
f0105e02:	5f                   	pop    %edi
f0105e03:	5d                   	pop    %ebp
f0105e04:	c3                   	ret    

f0105e05 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f0105e05:	55                   	push   %ebp
f0105e06:	89 e5                	mov    %esp,%ebp
f0105e08:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0105e0b:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f0105e0e:	0f b6 01             	movzbl (%ecx),%eax
f0105e11:	84 c0                	test   %al,%al
f0105e13:	74 15                	je     f0105e2a <strcmp+0x25>
f0105e15:	3a 02                	cmp    (%edx),%al
f0105e17:	75 11                	jne    f0105e2a <strcmp+0x25>
		p++, q++;
f0105e19:	83 c1 01             	add    $0x1,%ecx
f0105e1c:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f0105e1f:	0f b6 01             	movzbl (%ecx),%eax
f0105e22:	84 c0                	test   %al,%al
f0105e24:	74 04                	je     f0105e2a <strcmp+0x25>
f0105e26:	3a 02                	cmp    (%edx),%al
f0105e28:	74 ef                	je     f0105e19 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f0105e2a:	0f b6 c0             	movzbl %al,%eax
f0105e2d:	0f b6 12             	movzbl (%edx),%edx
f0105e30:	29 d0                	sub    %edx,%eax
}
f0105e32:	5d                   	pop    %ebp
f0105e33:	c3                   	ret    

f0105e34 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0105e34:	55                   	push   %ebp
f0105e35:	89 e5                	mov    %esp,%ebp
f0105e37:	56                   	push   %esi
f0105e38:	53                   	push   %ebx
f0105e39:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105e3c:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105e3f:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f0105e42:	85 f6                	test   %esi,%esi
f0105e44:	74 29                	je     f0105e6f <strncmp+0x3b>
f0105e46:	0f b6 03             	movzbl (%ebx),%eax
f0105e49:	84 c0                	test   %al,%al
f0105e4b:	74 30                	je     f0105e7d <strncmp+0x49>
f0105e4d:	3a 02                	cmp    (%edx),%al
f0105e4f:	75 2c                	jne    f0105e7d <strncmp+0x49>
f0105e51:	8d 43 01             	lea    0x1(%ebx),%eax
f0105e54:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f0105e56:	89 c3                	mov    %eax,%ebx
f0105e58:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f0105e5b:	39 f0                	cmp    %esi,%eax
f0105e5d:	74 17                	je     f0105e76 <strncmp+0x42>
f0105e5f:	0f b6 08             	movzbl (%eax),%ecx
f0105e62:	84 c9                	test   %cl,%cl
f0105e64:	74 17                	je     f0105e7d <strncmp+0x49>
f0105e66:	83 c0 01             	add    $0x1,%eax
f0105e69:	3a 0a                	cmp    (%edx),%cl
f0105e6b:	74 e9                	je     f0105e56 <strncmp+0x22>
f0105e6d:	eb 0e                	jmp    f0105e7d <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f0105e6f:	b8 00 00 00 00       	mov    $0x0,%eax
f0105e74:	eb 0f                	jmp    f0105e85 <strncmp+0x51>
f0105e76:	b8 00 00 00 00       	mov    $0x0,%eax
f0105e7b:	eb 08                	jmp    f0105e85 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f0105e7d:	0f b6 03             	movzbl (%ebx),%eax
f0105e80:	0f b6 12             	movzbl (%edx),%edx
f0105e83:	29 d0                	sub    %edx,%eax
}
f0105e85:	5b                   	pop    %ebx
f0105e86:	5e                   	pop    %esi
f0105e87:	5d                   	pop    %ebp
f0105e88:	c3                   	ret    

f0105e89 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f0105e89:	55                   	push   %ebp
f0105e8a:	89 e5                	mov    %esp,%ebp
f0105e8c:	53                   	push   %ebx
f0105e8d:	8b 45 08             	mov    0x8(%ebp),%eax
f0105e90:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105e93:	0f b6 18             	movzbl (%eax),%ebx
f0105e96:	84 db                	test   %bl,%bl
f0105e98:	74 1d                	je     f0105eb7 <strchr+0x2e>
f0105e9a:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0105e9c:	38 d3                	cmp    %dl,%bl
f0105e9e:	75 06                	jne    f0105ea6 <strchr+0x1d>
f0105ea0:	eb 1a                	jmp    f0105ebc <strchr+0x33>
f0105ea2:	38 ca                	cmp    %cl,%dl
f0105ea4:	74 16                	je     f0105ebc <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0105ea6:	83 c0 01             	add    $0x1,%eax
f0105ea9:	0f b6 10             	movzbl (%eax),%edx
f0105eac:	84 d2                	test   %dl,%dl
f0105eae:	75 f2                	jne    f0105ea2 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0105eb0:	b8 00 00 00 00       	mov    $0x0,%eax
f0105eb5:	eb 05                	jmp    f0105ebc <strchr+0x33>
f0105eb7:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105ebc:	5b                   	pop    %ebx
f0105ebd:	5d                   	pop    %ebp
f0105ebe:	c3                   	ret    

f0105ebf <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f0105ebf:	55                   	push   %ebp
f0105ec0:	89 e5                	mov    %esp,%ebp
f0105ec2:	53                   	push   %ebx
f0105ec3:	8b 45 08             	mov    0x8(%ebp),%eax
f0105ec6:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105ec9:	0f b6 18             	movzbl (%eax),%ebx
f0105ecc:	84 db                	test   %bl,%bl
f0105ece:	74 16                	je     f0105ee6 <strfind+0x27>
f0105ed0:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0105ed2:	38 d3                	cmp    %dl,%bl
f0105ed4:	75 06                	jne    f0105edc <strfind+0x1d>
f0105ed6:	eb 0e                	jmp    f0105ee6 <strfind+0x27>
f0105ed8:	38 ca                	cmp    %cl,%dl
f0105eda:	74 0a                	je     f0105ee6 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f0105edc:	83 c0 01             	add    $0x1,%eax
f0105edf:	0f b6 10             	movzbl (%eax),%edx
f0105ee2:	84 d2                	test   %dl,%dl
f0105ee4:	75 f2                	jne    f0105ed8 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f0105ee6:	5b                   	pop    %ebx
f0105ee7:	5d                   	pop    %ebp
f0105ee8:	c3                   	ret    

f0105ee9 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f0105ee9:	55                   	push   %ebp
f0105eea:	89 e5                	mov    %esp,%ebp
f0105eec:	57                   	push   %edi
f0105eed:	56                   	push   %esi
f0105eee:	53                   	push   %ebx
f0105eef:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105ef2:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0105ef5:	85 c9                	test   %ecx,%ecx
f0105ef7:	74 36                	je     f0105f2f <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f0105ef9:	f7 c7 03 00 00 00    	test   $0x3,%edi
f0105eff:	75 28                	jne    f0105f29 <memset+0x40>
f0105f01:	f6 c1 03             	test   $0x3,%cl
f0105f04:	75 23                	jne    f0105f29 <memset+0x40>
		c &= 0xFF;
f0105f06:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f0105f0a:	89 d3                	mov    %edx,%ebx
f0105f0c:	c1 e3 08             	shl    $0x8,%ebx
f0105f0f:	89 d6                	mov    %edx,%esi
f0105f11:	c1 e6 18             	shl    $0x18,%esi
f0105f14:	89 d0                	mov    %edx,%eax
f0105f16:	c1 e0 10             	shl    $0x10,%eax
f0105f19:	09 f0                	or     %esi,%eax
f0105f1b:	09 c2                	or     %eax,%edx
f0105f1d:	89 d0                	mov    %edx,%eax
f0105f1f:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f0105f21:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0105f24:	fc                   	cld    
f0105f25:	f3 ab                	rep stos %eax,%es:(%edi)
f0105f27:	eb 06                	jmp    f0105f2f <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0105f29:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105f2c:	fc                   	cld    
f0105f2d:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f0105f2f:	89 f8                	mov    %edi,%eax
f0105f31:	5b                   	pop    %ebx
f0105f32:	5e                   	pop    %esi
f0105f33:	5f                   	pop    %edi
f0105f34:	5d                   	pop    %ebp
f0105f35:	c3                   	ret    

f0105f36 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0105f36:	55                   	push   %ebp
f0105f37:	89 e5                	mov    %esp,%ebp
f0105f39:	57                   	push   %edi
f0105f3a:	56                   	push   %esi
f0105f3b:	8b 45 08             	mov    0x8(%ebp),%eax
f0105f3e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105f41:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0105f44:	39 c6                	cmp    %eax,%esi
f0105f46:	73 35                	jae    f0105f7d <memmove+0x47>
f0105f48:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0105f4b:	39 d0                	cmp    %edx,%eax
f0105f4d:	73 2e                	jae    f0105f7d <memmove+0x47>
		s += n;
		d += n;
f0105f4f:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0105f52:	89 d6                	mov    %edx,%esi
f0105f54:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105f56:	f7 c6 03 00 00 00    	test   $0x3,%esi
f0105f5c:	75 13                	jne    f0105f71 <memmove+0x3b>
f0105f5e:	f6 c1 03             	test   $0x3,%cl
f0105f61:	75 0e                	jne    f0105f71 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0105f63:	83 ef 04             	sub    $0x4,%edi
f0105f66:	8d 72 fc             	lea    -0x4(%edx),%esi
f0105f69:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f0105f6c:	fd                   	std    
f0105f6d:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0105f6f:	eb 09                	jmp    f0105f7a <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0105f71:	83 ef 01             	sub    $0x1,%edi
f0105f74:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0105f77:	fd                   	std    
f0105f78:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0105f7a:	fc                   	cld    
f0105f7b:	eb 1d                	jmp    f0105f9a <memmove+0x64>
f0105f7d:	89 f2                	mov    %esi,%edx
f0105f7f:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105f81:	f6 c2 03             	test   $0x3,%dl
f0105f84:	75 0f                	jne    f0105f95 <memmove+0x5f>
f0105f86:	f6 c1 03             	test   $0x3,%cl
f0105f89:	75 0a                	jne    f0105f95 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0105f8b:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f0105f8e:	89 c7                	mov    %eax,%edi
f0105f90:	fc                   	cld    
f0105f91:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0105f93:	eb 05                	jmp    f0105f9a <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0105f95:	89 c7                	mov    %eax,%edi
f0105f97:	fc                   	cld    
f0105f98:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f0105f9a:	5e                   	pop    %esi
f0105f9b:	5f                   	pop    %edi
f0105f9c:	5d                   	pop    %ebp
f0105f9d:	c3                   	ret    

f0105f9e <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f0105f9e:	55                   	push   %ebp
f0105f9f:	89 e5                	mov    %esp,%ebp
f0105fa1:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0105fa4:	8b 45 10             	mov    0x10(%ebp),%eax
f0105fa7:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105fab:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105fae:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105fb2:	8b 45 08             	mov    0x8(%ebp),%eax
f0105fb5:	89 04 24             	mov    %eax,(%esp)
f0105fb8:	e8 79 ff ff ff       	call   f0105f36 <memmove>
}
f0105fbd:	c9                   	leave  
f0105fbe:	c3                   	ret    

f0105fbf <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f0105fbf:	55                   	push   %ebp
f0105fc0:	89 e5                	mov    %esp,%ebp
f0105fc2:	57                   	push   %edi
f0105fc3:	56                   	push   %esi
f0105fc4:	53                   	push   %ebx
f0105fc5:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105fc8:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105fcb:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0105fce:	8d 78 ff             	lea    -0x1(%eax),%edi
f0105fd1:	85 c0                	test   %eax,%eax
f0105fd3:	74 36                	je     f010600b <memcmp+0x4c>
		if (*s1 != *s2)
f0105fd5:	0f b6 03             	movzbl (%ebx),%eax
f0105fd8:	0f b6 0e             	movzbl (%esi),%ecx
f0105fdb:	ba 00 00 00 00       	mov    $0x0,%edx
f0105fe0:	38 c8                	cmp    %cl,%al
f0105fe2:	74 1c                	je     f0106000 <memcmp+0x41>
f0105fe4:	eb 10                	jmp    f0105ff6 <memcmp+0x37>
f0105fe6:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f0105feb:	83 c2 01             	add    $0x1,%edx
f0105fee:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f0105ff2:	38 c8                	cmp    %cl,%al
f0105ff4:	74 0a                	je     f0106000 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f0105ff6:	0f b6 c0             	movzbl %al,%eax
f0105ff9:	0f b6 c9             	movzbl %cl,%ecx
f0105ffc:	29 c8                	sub    %ecx,%eax
f0105ffe:	eb 10                	jmp    f0106010 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0106000:	39 fa                	cmp    %edi,%edx
f0106002:	75 e2                	jne    f0105fe6 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f0106004:	b8 00 00 00 00       	mov    $0x0,%eax
f0106009:	eb 05                	jmp    f0106010 <memcmp+0x51>
f010600b:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0106010:	5b                   	pop    %ebx
f0106011:	5e                   	pop    %esi
f0106012:	5f                   	pop    %edi
f0106013:	5d                   	pop    %ebp
f0106014:	c3                   	ret    

f0106015 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0106015:	55                   	push   %ebp
f0106016:	89 e5                	mov    %esp,%ebp
f0106018:	53                   	push   %ebx
f0106019:	8b 45 08             	mov    0x8(%ebp),%eax
f010601c:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f010601f:	89 c2                	mov    %eax,%edx
f0106021:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0106024:	39 d0                	cmp    %edx,%eax
f0106026:	73 13                	jae    f010603b <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f0106028:	89 d9                	mov    %ebx,%ecx
f010602a:	38 18                	cmp    %bl,(%eax)
f010602c:	75 06                	jne    f0106034 <memfind+0x1f>
f010602e:	eb 0b                	jmp    f010603b <memfind+0x26>
f0106030:	38 08                	cmp    %cl,(%eax)
f0106032:	74 07                	je     f010603b <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f0106034:	83 c0 01             	add    $0x1,%eax
f0106037:	39 d0                	cmp    %edx,%eax
f0106039:	75 f5                	jne    f0106030 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f010603b:	5b                   	pop    %ebx
f010603c:	5d                   	pop    %ebp
f010603d:	c3                   	ret    

f010603e <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f010603e:	55                   	push   %ebp
f010603f:	89 e5                	mov    %esp,%ebp
f0106041:	57                   	push   %edi
f0106042:	56                   	push   %esi
f0106043:	53                   	push   %ebx
f0106044:	8b 55 08             	mov    0x8(%ebp),%edx
f0106047:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010604a:	0f b6 0a             	movzbl (%edx),%ecx
f010604d:	80 f9 09             	cmp    $0x9,%cl
f0106050:	74 05                	je     f0106057 <strtol+0x19>
f0106052:	80 f9 20             	cmp    $0x20,%cl
f0106055:	75 10                	jne    f0106067 <strtol+0x29>
		s++;
f0106057:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010605a:	0f b6 0a             	movzbl (%edx),%ecx
f010605d:	80 f9 09             	cmp    $0x9,%cl
f0106060:	74 f5                	je     f0106057 <strtol+0x19>
f0106062:	80 f9 20             	cmp    $0x20,%cl
f0106065:	74 f0                	je     f0106057 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f0106067:	80 f9 2b             	cmp    $0x2b,%cl
f010606a:	75 0a                	jne    f0106076 <strtol+0x38>
		s++;
f010606c:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f010606f:	bf 00 00 00 00       	mov    $0x0,%edi
f0106074:	eb 11                	jmp    f0106087 <strtol+0x49>
f0106076:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f010607b:	80 f9 2d             	cmp    $0x2d,%cl
f010607e:	75 07                	jne    f0106087 <strtol+0x49>
		s++, neg = 1;
f0106080:	83 c2 01             	add    $0x1,%edx
f0106083:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0106087:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f010608c:	75 15                	jne    f01060a3 <strtol+0x65>
f010608e:	80 3a 30             	cmpb   $0x30,(%edx)
f0106091:	75 10                	jne    f01060a3 <strtol+0x65>
f0106093:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0106097:	75 0a                	jne    f01060a3 <strtol+0x65>
		s += 2, base = 16;
f0106099:	83 c2 02             	add    $0x2,%edx
f010609c:	b8 10 00 00 00       	mov    $0x10,%eax
f01060a1:	eb 10                	jmp    f01060b3 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f01060a3:	85 c0                	test   %eax,%eax
f01060a5:	75 0c                	jne    f01060b3 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f01060a7:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f01060a9:	80 3a 30             	cmpb   $0x30,(%edx)
f01060ac:	75 05                	jne    f01060b3 <strtol+0x75>
		s++, base = 8;
f01060ae:	83 c2 01             	add    $0x1,%edx
f01060b1:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f01060b3:	bb 00 00 00 00       	mov    $0x0,%ebx
f01060b8:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f01060bb:	0f b6 0a             	movzbl (%edx),%ecx
f01060be:	8d 71 d0             	lea    -0x30(%ecx),%esi
f01060c1:	89 f0                	mov    %esi,%eax
f01060c3:	3c 09                	cmp    $0x9,%al
f01060c5:	77 08                	ja     f01060cf <strtol+0x91>
			dig = *s - '0';
f01060c7:	0f be c9             	movsbl %cl,%ecx
f01060ca:	83 e9 30             	sub    $0x30,%ecx
f01060cd:	eb 20                	jmp    f01060ef <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f01060cf:	8d 71 9f             	lea    -0x61(%ecx),%esi
f01060d2:	89 f0                	mov    %esi,%eax
f01060d4:	3c 19                	cmp    $0x19,%al
f01060d6:	77 08                	ja     f01060e0 <strtol+0xa2>
			dig = *s - 'a' + 10;
f01060d8:	0f be c9             	movsbl %cl,%ecx
f01060db:	83 e9 57             	sub    $0x57,%ecx
f01060de:	eb 0f                	jmp    f01060ef <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f01060e0:	8d 71 bf             	lea    -0x41(%ecx),%esi
f01060e3:	89 f0                	mov    %esi,%eax
f01060e5:	3c 19                	cmp    $0x19,%al
f01060e7:	77 16                	ja     f01060ff <strtol+0xc1>
			dig = *s - 'A' + 10;
f01060e9:	0f be c9             	movsbl %cl,%ecx
f01060ec:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f01060ef:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f01060f2:	7d 0f                	jge    f0106103 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f01060f4:	83 c2 01             	add    $0x1,%edx
f01060f7:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f01060fb:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f01060fd:	eb bc                	jmp    f01060bb <strtol+0x7d>
f01060ff:	89 d8                	mov    %ebx,%eax
f0106101:	eb 02                	jmp    f0106105 <strtol+0xc7>
f0106103:	89 d8                	mov    %ebx,%eax

	if (endptr)
f0106105:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0106109:	74 05                	je     f0106110 <strtol+0xd2>
		*endptr = (char *) s;
f010610b:	8b 75 0c             	mov    0xc(%ebp),%esi
f010610e:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f0106110:	f7 d8                	neg    %eax
f0106112:	85 ff                	test   %edi,%edi
f0106114:	0f 44 c3             	cmove  %ebx,%eax
}
f0106117:	5b                   	pop    %ebx
f0106118:	5e                   	pop    %esi
f0106119:	5f                   	pop    %edi
f010611a:	5d                   	pop    %ebp
f010611b:	c3                   	ret    

f010611c <mpentry_start>:
.set PROT_MODE_DSEG, 0x10	# kernel data segment selector

.code16           
.globl mpentry_start
mpentry_start:
	cli            
f010611c:	fa                   	cli    

	xorw    %ax, %ax
f010611d:	31 c0                	xor    %eax,%eax
	movw    %ax, %ds
f010611f:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0106121:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0106123:	8e d0                	mov    %eax,%ss

	lgdt    MPBOOTPHYS(gdtdesc)
f0106125:	0f 01 16             	lgdtl  (%esi)
f0106128:	74 70                	je     f010619a <mpentry_end+0x4>
	movl    %cr0, %eax
f010612a:	0f 20 c0             	mov    %cr0,%eax
	orl     $CR0_PE, %eax
f010612d:	66 83 c8 01          	or     $0x1,%ax
	movl    %eax, %cr0
f0106131:	0f 22 c0             	mov    %eax,%cr0

	ljmpl   $(PROT_MODE_CSEG), $(MPBOOTPHYS(start32))
f0106134:	66 ea 20 70 00 00    	ljmpw  $0x0,$0x7020
f010613a:	08 00                	or     %al,(%eax)

f010613c <start32>:

.code32
start32:
	movw    $(PROT_MODE_DSEG), %ax
f010613c:	66 b8 10 00          	mov    $0x10,%ax
	movw    %ax, %ds
f0106140:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0106142:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0106144:	8e d0                	mov    %eax,%ss
	movw    $0, %ax
f0106146:	66 b8 00 00          	mov    $0x0,%ax
	movw    %ax, %fs
f010614a:	8e e0                	mov    %eax,%fs
	movw    %ax, %gs
f010614c:	8e e8                	mov    %eax,%gs

	# Set up initial page table. We cannot use kern_pgdir yet because
	# we are still running at a low EIP.
	movl    $(RELOC(entry_pgdir)), %eax
f010614e:	b8 00 f0 11 00       	mov    $0x11f000,%eax
	movl    %eax, %cr3
f0106153:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl    %cr0, %eax
f0106156:	0f 20 c0             	mov    %cr0,%eax
	orl     $(CR0_PE|CR0_PG|CR0_WP), %eax
f0106159:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl    %eax, %cr0
f010615e:	0f 22 c0             	mov    %eax,%cr0

	# Switch to the per-cpu stack allocated in mem_init()
	movl    mpentry_kstack, %esp
f0106161:	8b 25 84 7e 1c f0    	mov    0xf01c7e84,%esp
	movl    $0x0, %ebp       # nuke frame pointer
f0106167:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Call mp_main().  (Exercise for the reader: why the indirect call?)
	movl    $mp_main, %eax
f010616c:	b8 4b 02 10 f0       	mov    $0xf010024b,%eax
	call    *%eax
f0106171:	ff d0                	call   *%eax

f0106173 <spin>:

	# If mp_main returns (it shouldn't), loop.
spin:
	jmp     spin
f0106173:	eb fe                	jmp    f0106173 <spin>
f0106175:	8d 76 00             	lea    0x0(%esi),%esi

f0106178 <gdt>:
	...
f0106180:	ff                   	(bad)  
f0106181:	ff 00                	incl   (%eax)
f0106183:	00 00                	add    %al,(%eax)
f0106185:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
f010618c:	00 92 cf 00 17 00    	add    %dl,0x1700cf(%edx)

f0106190 <gdtdesc>:
f0106190:	17                   	pop    %ss
f0106191:	00 5c 70 00          	add    %bl,0x0(%eax,%esi,2)
	...

f0106196 <mpentry_end>:
	.word   0x17				# sizeof(gdt) - 1
	.long   MPBOOTPHYS(gdt)			# address gdt

.globl mpentry_end
mpentry_end:
	nop
f0106196:	90                   	nop
f0106197:	66 90                	xchg   %ax,%ax
f0106199:	66 90                	xchg   %ax,%ax
f010619b:	66 90                	xchg   %ax,%ax
f010619d:	66 90                	xchg   %ax,%ax
f010619f:	90                   	nop

f01061a0 <mpsearch1>:
}

// Look for an MP structure in the len bytes at physical address addr.
static struct mp *
mpsearch1(physaddr_t a, int len)
{
f01061a0:	55                   	push   %ebp
f01061a1:	89 e5                	mov    %esp,%ebp
f01061a3:	56                   	push   %esi
f01061a4:	53                   	push   %ebx
f01061a5:	83 ec 10             	sub    $0x10,%esp
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01061a8:	8b 0d 88 7e 1c f0    	mov    0xf01c7e88,%ecx
f01061ae:	89 c3                	mov    %eax,%ebx
f01061b0:	c1 eb 0c             	shr    $0xc,%ebx
f01061b3:	39 cb                	cmp    %ecx,%ebx
f01061b5:	72 20                	jb     f01061d7 <mpsearch1+0x37>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01061b7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01061bb:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
f01061c2:	f0 
f01061c3:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f01061ca:	00 
f01061cb:	c7 04 24 5d 86 10 f0 	movl   $0xf010865d,(%esp)
f01061d2:	e8 69 9e ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01061d7:	8d 98 00 00 00 f0    	lea    -0x10000000(%eax),%ebx
	struct mp *mp = KADDR(a), *end = KADDR(a + len);
f01061dd:	01 d0                	add    %edx,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01061df:	89 c2                	mov    %eax,%edx
f01061e1:	c1 ea 0c             	shr    $0xc,%edx
f01061e4:	39 d1                	cmp    %edx,%ecx
f01061e6:	77 20                	ja     f0106208 <mpsearch1+0x68>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01061e8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01061ec:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
f01061f3:	f0 
f01061f4:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f01061fb:	00 
f01061fc:	c7 04 24 5d 86 10 f0 	movl   $0xf010865d,(%esp)
f0106203:	e8 38 9e ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0106208:	8d b0 00 00 00 f0    	lea    -0x10000000(%eax),%esi

	for (; mp < end; mp++)
f010620e:	39 f3                	cmp    %esi,%ebx
f0106210:	73 40                	jae    f0106252 <mpsearch1+0xb2>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0106212:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0106219:	00 
f010621a:	c7 44 24 04 6d 86 10 	movl   $0xf010866d,0x4(%esp)
f0106221:	f0 
f0106222:	89 1c 24             	mov    %ebx,(%esp)
f0106225:	e8 95 fd ff ff       	call   f0105fbf <memcmp>
f010622a:	85 c0                	test   %eax,%eax
f010622c:	75 17                	jne    f0106245 <mpsearch1+0xa5>
f010622e:	ba 00 00 00 00       	mov    $0x0,%edx
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
		sum += ((uint8_t *)addr)[i];
f0106233:	0f b6 0c 03          	movzbl (%ebx,%eax,1),%ecx
f0106237:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106239:	83 c0 01             	add    $0x1,%eax
f010623c:	83 f8 10             	cmp    $0x10,%eax
f010623f:	75 f2                	jne    f0106233 <mpsearch1+0x93>
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0106241:	84 d2                	test   %dl,%dl
f0106243:	74 14                	je     f0106259 <mpsearch1+0xb9>
static struct mp *
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
f0106245:	83 c3 10             	add    $0x10,%ebx
f0106248:	39 f3                	cmp    %esi,%ebx
f010624a:	72 c6                	jb     f0106212 <mpsearch1+0x72>
f010624c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106250:	eb 0b                	jmp    f010625d <mpsearch1+0xbd>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
		    sum(mp, sizeof(*mp)) == 0)
			return mp;
	return NULL;
f0106252:	b8 00 00 00 00       	mov    $0x0,%eax
f0106257:	eb 09                	jmp    f0106262 <mpsearch1+0xc2>
f0106259:	89 d8                	mov    %ebx,%eax
f010625b:	eb 05                	jmp    f0106262 <mpsearch1+0xc2>
f010625d:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0106262:	83 c4 10             	add    $0x10,%esp
f0106265:	5b                   	pop    %ebx
f0106266:	5e                   	pop    %esi
f0106267:	5d                   	pop    %ebp
f0106268:	c3                   	ret    

f0106269 <mp_init>:
	return conf;
}

void
mp_init(void)
{
f0106269:	55                   	push   %ebp
f010626a:	89 e5                	mov    %esp,%ebp
f010626c:	57                   	push   %edi
f010626d:	56                   	push   %esi
f010626e:	53                   	push   %ebx
f010626f:	83 ec 2c             	sub    $0x2c,%esp
	struct mpconf *conf;
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
f0106272:	c7 05 c0 83 1c f0 20 	movl   $0xf01c8020,0xf01c83c0
f0106279:	80 1c f0 
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010627c:	83 3d 88 7e 1c f0 00 	cmpl   $0x0,0xf01c7e88
f0106283:	75 24                	jne    f01062a9 <mp_init+0x40>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106285:	c7 44 24 0c 00 04 00 	movl   $0x400,0xc(%esp)
f010628c:	00 
f010628d:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
f0106294:	f0 
f0106295:	c7 44 24 04 6f 00 00 	movl   $0x6f,0x4(%esp)
f010629c:	00 
f010629d:	c7 04 24 5d 86 10 f0 	movl   $0xf010865d,(%esp)
f01062a4:	e8 97 9d ff ff       	call   f0100040 <_panic>
	// The BIOS data area lives in 16-bit segment 0x40.
	bda = (uint8_t *) KADDR(0x40 << 4);

	// [MP 4] The 16-bit segment of the EBDA is in the two bytes
	// starting at byte 0x0E of the BDA.  0 if not present.
	if ((p = *(uint16_t *) (bda + 0x0E))) {
f01062a9:	0f b7 05 0e 04 00 f0 	movzwl 0xf000040e,%eax
f01062b0:	85 c0                	test   %eax,%eax
f01062b2:	74 16                	je     f01062ca <mp_init+0x61>
		p <<= 4;	// Translate from segment to PA
f01062b4:	c1 e0 04             	shl    $0x4,%eax
		if ((mp = mpsearch1(p, 1024)))
f01062b7:	ba 00 04 00 00       	mov    $0x400,%edx
f01062bc:	e8 df fe ff ff       	call   f01061a0 <mpsearch1>
f01062c1:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01062c4:	85 c0                	test   %eax,%eax
f01062c6:	75 3c                	jne    f0106304 <mp_init+0x9b>
f01062c8:	eb 20                	jmp    f01062ea <mp_init+0x81>
			return mp;
	} else {
		// The size of base memory, in KB is in the two bytes
		// starting at 0x13 of the BDA.
		p = *(uint16_t *) (bda + 0x13) * 1024;
f01062ca:	0f b7 05 13 04 00 f0 	movzwl 0xf0000413,%eax
f01062d1:	c1 e0 0a             	shl    $0xa,%eax
		if ((mp = mpsearch1(p - 1024, 1024)))
f01062d4:	2d 00 04 00 00       	sub    $0x400,%eax
f01062d9:	ba 00 04 00 00       	mov    $0x400,%edx
f01062de:	e8 bd fe ff ff       	call   f01061a0 <mpsearch1>
f01062e3:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01062e6:	85 c0                	test   %eax,%eax
f01062e8:	75 1a                	jne    f0106304 <mp_init+0x9b>
			return mp;
	}
	return mpsearch1(0xF0000, 0x10000);
f01062ea:	ba 00 00 01 00       	mov    $0x10000,%edx
f01062ef:	b8 00 00 0f 00       	mov    $0xf0000,%eax
f01062f4:	e8 a7 fe ff ff       	call   f01061a0 <mpsearch1>
f01062f9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
mpconfig(struct mp **pmp)
{
	struct mpconf *conf;
	struct mp *mp;

	if ((mp = mpsearch()) == 0)
f01062fc:	85 c0                	test   %eax,%eax
f01062fe:	0f 84 5f 02 00 00    	je     f0106563 <mp_init+0x2fa>
		return NULL;
	if (mp->physaddr == 0 || mp->type != 0) {
f0106304:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0106307:	8b 70 04             	mov    0x4(%eax),%esi
f010630a:	85 f6                	test   %esi,%esi
f010630c:	74 06                	je     f0106314 <mp_init+0xab>
f010630e:	80 78 0b 00          	cmpb   $0x0,0xb(%eax)
f0106312:	74 11                	je     f0106325 <mp_init+0xbc>
		cprintf("SMP: Default configurations not implemented\n");
f0106314:	c7 04 24 d0 84 10 f0 	movl   $0xf01084d0,(%esp)
f010631b:	e8 56 db ff ff       	call   f0103e76 <cprintf>
f0106320:	e9 3e 02 00 00       	jmp    f0106563 <mp_init+0x2fa>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0106325:	89 f0                	mov    %esi,%eax
f0106327:	c1 e8 0c             	shr    $0xc,%eax
f010632a:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f0106330:	72 20                	jb     f0106352 <mp_init+0xe9>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106332:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0106336:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
f010633d:	f0 
f010633e:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f0106345:	00 
f0106346:	c7 04 24 5d 86 10 f0 	movl   $0xf010865d,(%esp)
f010634d:	e8 ee 9c ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0106352:	8d 9e 00 00 00 f0    	lea    -0x10000000(%esi),%ebx
		return NULL;
	}
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
f0106358:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f010635f:	00 
f0106360:	c7 44 24 04 72 86 10 	movl   $0xf0108672,0x4(%esp)
f0106367:	f0 
f0106368:	89 1c 24             	mov    %ebx,(%esp)
f010636b:	e8 4f fc ff ff       	call   f0105fbf <memcmp>
f0106370:	85 c0                	test   %eax,%eax
f0106372:	74 11                	je     f0106385 <mp_init+0x11c>
		cprintf("SMP: Incorrect MP configuration table signature\n");
f0106374:	c7 04 24 00 85 10 f0 	movl   $0xf0108500,(%esp)
f010637b:	e8 f6 da ff ff       	call   f0103e76 <cprintf>
f0106380:	e9 de 01 00 00       	jmp    f0106563 <mp_init+0x2fa>
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0106385:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0106389:	66 89 45 e2          	mov    %ax,-0x1e(%ebp)
f010638d:	0f b7 f8             	movzwl %ax,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106390:	85 ff                	test   %edi,%edi
f0106392:	7e 30                	jle    f01063c4 <mp_init+0x15b>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0106394:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0106399:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f010639e:	0f b6 8c 30 00 00 00 	movzbl -0x10000000(%eax,%esi,1),%ecx
f01063a5:	f0 
f01063a6:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f01063a8:	83 c0 01             	add    $0x1,%eax
f01063ab:	39 c7                	cmp    %eax,%edi
f01063ad:	7f ef                	jg     f010639e <mp_init+0x135>
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
		cprintf("SMP: Incorrect MP configuration table signature\n");
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f01063af:	84 d2                	test   %dl,%dl
f01063b1:	74 11                	je     f01063c4 <mp_init+0x15b>
		cprintf("SMP: Bad MP configuration checksum\n");
f01063b3:	c7 04 24 34 85 10 f0 	movl   $0xf0108534,(%esp)
f01063ba:	e8 b7 da ff ff       	call   f0103e76 <cprintf>
f01063bf:	e9 9f 01 00 00       	jmp    f0106563 <mp_init+0x2fa>
		return NULL;
	}
	if (conf->version != 1 && conf->version != 4) {
f01063c4:	0f b6 43 06          	movzbl 0x6(%ebx),%eax
f01063c8:	3c 04                	cmp    $0x4,%al
f01063ca:	74 1e                	je     f01063ea <mp_init+0x181>
f01063cc:	3c 01                	cmp    $0x1,%al
f01063ce:	66 90                	xchg   %ax,%ax
f01063d0:	74 18                	je     f01063ea <mp_init+0x181>
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
f01063d2:	0f b6 c0             	movzbl %al,%eax
f01063d5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01063d9:	c7 04 24 58 85 10 f0 	movl   $0xf0108558,(%esp)
f01063e0:	e8 91 da ff ff       	call   f0103e76 <cprintf>
f01063e5:	e9 79 01 00 00       	jmp    f0106563 <mp_init+0x2fa>
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f01063ea:	0f b7 73 28          	movzwl 0x28(%ebx),%esi
f01063ee:	0f b7 7d e2          	movzwl -0x1e(%ebp),%edi
f01063f2:	01 df                	add    %ebx,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f01063f4:	85 f6                	test   %esi,%esi
f01063f6:	7e 19                	jle    f0106411 <mp_init+0x1a8>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f01063f8:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f01063fd:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0106402:	0f b6 0c 07          	movzbl (%edi,%eax,1),%ecx
f0106406:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106408:	83 c0 01             	add    $0x1,%eax
f010640b:	39 c6                	cmp    %eax,%esi
f010640d:	7f f3                	jg     f0106402 <mp_init+0x199>
f010640f:	eb 05                	jmp    f0106416 <mp_init+0x1ad>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0106411:	ba 00 00 00 00       	mov    $0x0,%edx
	}
	if (conf->version != 1 && conf->version != 4) {
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0106416:	38 53 2a             	cmp    %dl,0x2a(%ebx)
f0106419:	74 11                	je     f010642c <mp_init+0x1c3>
		cprintf("SMP: Bad MP configuration extended checksum\n");
f010641b:	c7 04 24 78 85 10 f0 	movl   $0xf0108578,(%esp)
f0106422:	e8 4f da ff ff       	call   f0103e76 <cprintf>
f0106427:	e9 37 01 00 00       	jmp    f0106563 <mp_init+0x2fa>
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
	if ((conf = mpconfig(&mp)) == 0)
f010642c:	85 db                	test   %ebx,%ebx
f010642e:	0f 84 2f 01 00 00    	je     f0106563 <mp_init+0x2fa>
		return;
	ismp = 1;
f0106434:	c7 05 00 80 1c f0 01 	movl   $0x1,0xf01c8000
f010643b:	00 00 00 
	lapic = (uint32_t *)conf->lapicaddr;
f010643e:	8b 43 24             	mov    0x24(%ebx),%eax
f0106441:	a3 00 90 20 f0       	mov    %eax,0xf0209000

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0106446:	8d 7b 2c             	lea    0x2c(%ebx),%edi
f0106449:	66 83 7b 22 00       	cmpw   $0x0,0x22(%ebx)
f010644e:	0f 84 94 00 00 00    	je     f01064e8 <mp_init+0x27f>
f0106454:	be 00 00 00 00       	mov    $0x0,%esi
		switch (*p) {
f0106459:	0f b6 07             	movzbl (%edi),%eax
f010645c:	84 c0                	test   %al,%al
f010645e:	74 06                	je     f0106466 <mp_init+0x1fd>
f0106460:	3c 04                	cmp    $0x4,%al
f0106462:	77 54                	ja     f01064b8 <mp_init+0x24f>
f0106464:	eb 4d                	jmp    f01064b3 <mp_init+0x24a>
		case MPPROC:
			proc = (struct mpproc *)p;
			if (proc->flags & MPPROC_BOOT)
f0106466:	f6 47 03 02          	testb  $0x2,0x3(%edi)
f010646a:	74 11                	je     f010647d <mp_init+0x214>
				bootcpu = &cpus[ncpu];
f010646c:	6b 05 c4 83 1c f0 74 	imul   $0x74,0xf01c83c4,%eax
f0106473:	05 20 80 1c f0       	add    $0xf01c8020,%eax
f0106478:	a3 c0 83 1c f0       	mov    %eax,0xf01c83c0
			if (ncpu < NCPU) {
f010647d:	a1 c4 83 1c f0       	mov    0xf01c83c4,%eax
f0106482:	83 f8 07             	cmp    $0x7,%eax
f0106485:	7f 13                	jg     f010649a <mp_init+0x231>
				cpus[ncpu].cpu_id = ncpu;
f0106487:	6b d0 74             	imul   $0x74,%eax,%edx
f010648a:	88 82 20 80 1c f0    	mov    %al,-0xfe37fe0(%edx)
				ncpu++;
f0106490:	83 c0 01             	add    $0x1,%eax
f0106493:	a3 c4 83 1c f0       	mov    %eax,0xf01c83c4
f0106498:	eb 14                	jmp    f01064ae <mp_init+0x245>
			} else {
				cprintf("SMP: too many CPUs, CPU %d disabled\n",
f010649a:	0f b6 47 01          	movzbl 0x1(%edi),%eax
f010649e:	89 44 24 04          	mov    %eax,0x4(%esp)
f01064a2:	c7 04 24 a8 85 10 f0 	movl   $0xf01085a8,(%esp)
f01064a9:	e8 c8 d9 ff ff       	call   f0103e76 <cprintf>
					proc->apicid);
			}
			p += sizeof(struct mpproc);
f01064ae:	83 c7 14             	add    $0x14,%edi
			continue;
f01064b1:	eb 26                	jmp    f01064d9 <mp_init+0x270>
		case MPBUS:
		case MPIOAPIC:
		case MPIOINTR:
		case MPLINTR:
			p += 8;
f01064b3:	83 c7 08             	add    $0x8,%edi
			continue;
f01064b6:	eb 21                	jmp    f01064d9 <mp_init+0x270>
		default:
			cprintf("mpinit: unknown config type %x\n", *p);
f01064b8:	0f b6 c0             	movzbl %al,%eax
f01064bb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01064bf:	c7 04 24 d0 85 10 f0 	movl   $0xf01085d0,(%esp)
f01064c6:	e8 ab d9 ff ff       	call   f0103e76 <cprintf>
			ismp = 0;
f01064cb:	c7 05 00 80 1c f0 00 	movl   $0x0,0xf01c8000
f01064d2:	00 00 00 
			i = conf->entry;
f01064d5:	0f b7 73 22          	movzwl 0x22(%ebx),%esi
	if ((conf = mpconfig(&mp)) == 0)
		return;
	ismp = 1;
	lapic = (uint32_t *)conf->lapicaddr;

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f01064d9:	83 c6 01             	add    $0x1,%esi
f01064dc:	0f b7 43 22          	movzwl 0x22(%ebx),%eax
f01064e0:	39 f0                	cmp    %esi,%eax
f01064e2:	0f 87 71 ff ff ff    	ja     f0106459 <mp_init+0x1f0>
			ismp = 0;
			i = conf->entry;
		}
	}

	bootcpu->cpu_status = CPU_STARTED;
f01064e8:	a1 c0 83 1c f0       	mov    0xf01c83c0,%eax
f01064ed:	c7 40 04 01 00 00 00 	movl   $0x1,0x4(%eax)
	if (!ismp) {
f01064f4:	83 3d 00 80 1c f0 00 	cmpl   $0x0,0xf01c8000
f01064fb:	75 22                	jne    f010651f <mp_init+0x2b6>
		// Didn't like what we found; fall back to no MP.
		ncpu = 1;
f01064fd:	c7 05 c4 83 1c f0 01 	movl   $0x1,0xf01c83c4
f0106504:	00 00 00 
		lapic = NULL;
f0106507:	c7 05 00 90 20 f0 00 	movl   $0x0,0xf0209000
f010650e:	00 00 00 
		cprintf("SMP: configuration not found, SMP disabled\n");
f0106511:	c7 04 24 f0 85 10 f0 	movl   $0xf01085f0,(%esp)
f0106518:	e8 59 d9 ff ff       	call   f0103e76 <cprintf>
		return;
f010651d:	eb 44                	jmp    f0106563 <mp_init+0x2fa>
	}
	cprintf("SMP: CPU %d found %d CPU(s)\n", bootcpu->cpu_id,  ncpu);
f010651f:	8b 15 c4 83 1c f0    	mov    0xf01c83c4,%edx
f0106525:	89 54 24 08          	mov    %edx,0x8(%esp)
f0106529:	0f b6 00             	movzbl (%eax),%eax
f010652c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106530:	c7 04 24 77 86 10 f0 	movl   $0xf0108677,(%esp)
f0106537:	e8 3a d9 ff ff       	call   f0103e76 <cprintf>

	if (mp->imcrp) {
f010653c:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010653f:	80 78 0c 00          	cmpb   $0x0,0xc(%eax)
f0106543:	74 1e                	je     f0106563 <mp_init+0x2fa>
		// [MP 3.2.6.1] If the hardware implements PIC mode,
		// switch to getting interrupts from the LAPIC.
		cprintf("SMP: Setting IMCR to switch from PIC mode to symmetric I/O mode\n");
f0106545:	c7 04 24 1c 86 10 f0 	movl   $0xf010861c,(%esp)
f010654c:	e8 25 d9 ff ff       	call   f0103e76 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0106551:	ba 22 00 00 00       	mov    $0x22,%edx
f0106556:	b8 70 00 00 00       	mov    $0x70,%eax
f010655b:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010655c:	b2 23                	mov    $0x23,%dl
f010655e:	ec                   	in     (%dx),%al
		outb(0x22, 0x70);   // Select IMCR
		outb(0x23, inb(0x23) | 1);  // Mask external interrupts.
f010655f:	83 c8 01             	or     $0x1,%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0106562:	ee                   	out    %al,(%dx)
	}
}
f0106563:	83 c4 2c             	add    $0x2c,%esp
f0106566:	5b                   	pop    %ebx
f0106567:	5e                   	pop    %esi
f0106568:	5f                   	pop    %edi
f0106569:	5d                   	pop    %ebp
f010656a:	c3                   	ret    

f010656b <lapicw>:

volatile uint32_t *lapic;  // Initialized in mp.c

static void
lapicw(int index, int value)
{
f010656b:	55                   	push   %ebp
f010656c:	89 e5                	mov    %esp,%ebp
	lapic[index] = value;
f010656e:	8b 0d 00 90 20 f0    	mov    0xf0209000,%ecx
f0106574:	8d 04 81             	lea    (%ecx,%eax,4),%eax
f0106577:	89 10                	mov    %edx,(%eax)
	lapic[ID];  // wait for write to finish, by reading
f0106579:	a1 00 90 20 f0       	mov    0xf0209000,%eax
f010657e:	8b 40 20             	mov    0x20(%eax),%eax
}
f0106581:	5d                   	pop    %ebp
f0106582:	c3                   	ret    

f0106583 <cpunum>:
	lapicw(TPR, 0);
}

int
cpunum(void)
{
f0106583:	55                   	push   %ebp
f0106584:	89 e5                	mov    %esp,%ebp
	if (lapic)
f0106586:	a1 00 90 20 f0       	mov    0xf0209000,%eax
f010658b:	85 c0                	test   %eax,%eax
f010658d:	74 08                	je     f0106597 <cpunum+0x14>
		return lapic[ID] >> 24;
f010658f:	8b 40 20             	mov    0x20(%eax),%eax
f0106592:	c1 e8 18             	shr    $0x18,%eax
f0106595:	eb 05                	jmp    f010659c <cpunum+0x19>
	return 0;
f0106597:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010659c:	5d                   	pop    %ebp
f010659d:	c3                   	ret    

f010659e <lapic_init>:
}

void
lapic_init(void)
{
	if (!lapic) 
f010659e:	83 3d 00 90 20 f0 00 	cmpl   $0x0,0xf0209000
f01065a5:	0f 84 0b 01 00 00    	je     f01066b6 <lapic_init+0x118>
	lapic[ID];  // wait for write to finish, by reading
}

void
lapic_init(void)
{
f01065ab:	55                   	push   %ebp
f01065ac:	89 e5                	mov    %esp,%ebp
	if (!lapic) 
		return;

	// Enable local APIC; set spurious interrupt vector.
	lapicw(SVR, ENABLE | (IRQ_OFFSET + IRQ_SPURIOUS));
f01065ae:	ba 27 01 00 00       	mov    $0x127,%edx
f01065b3:	b8 3c 00 00 00       	mov    $0x3c,%eax
f01065b8:	e8 ae ff ff ff       	call   f010656b <lapicw>

	// The timer repeatedly counts down at bus frequency
	// from lapic[TICR] and then issues an interrupt.  
	// If we cared more about precise timekeeping,
	// TICR would be calibrated using an external time source.
	lapicw(TDCR, X1);
f01065bd:	ba 0b 00 00 00       	mov    $0xb,%edx
f01065c2:	b8 f8 00 00 00       	mov    $0xf8,%eax
f01065c7:	e8 9f ff ff ff       	call   f010656b <lapicw>
	lapicw(TIMER, PERIODIC | (IRQ_OFFSET + IRQ_TIMER));
f01065cc:	ba 20 00 02 00       	mov    $0x20020,%edx
f01065d1:	b8 c8 00 00 00       	mov    $0xc8,%eax
f01065d6:	e8 90 ff ff ff       	call   f010656b <lapicw>
	lapicw(TICR, 10000000); 
f01065db:	ba 80 96 98 00       	mov    $0x989680,%edx
f01065e0:	b8 e0 00 00 00       	mov    $0xe0,%eax
f01065e5:	e8 81 ff ff ff       	call   f010656b <lapicw>
	//
	// According to Intel MP Specification, the BIOS should initialize
	// BSP's local APIC in Virtual Wire Mode, in which 8259A's
	// INTR is virtually connected to BSP's LINTIN0. In this mode,
	// we do not need to program the IOAPIC.
	if (thiscpu != bootcpu)
f01065ea:	e8 94 ff ff ff       	call   f0106583 <cpunum>
f01065ef:	6b c0 74             	imul   $0x74,%eax,%eax
f01065f2:	05 20 80 1c f0       	add    $0xf01c8020,%eax
f01065f7:	39 05 c0 83 1c f0    	cmp    %eax,0xf01c83c0
f01065fd:	74 0f                	je     f010660e <lapic_init+0x70>
		lapicw(LINT0, MASKED);
f01065ff:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106604:	b8 d4 00 00 00       	mov    $0xd4,%eax
f0106609:	e8 5d ff ff ff       	call   f010656b <lapicw>

	// Disable NMI (LINT1) on all CPUs
	lapicw(LINT1, MASKED);
f010660e:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106613:	b8 d8 00 00 00       	mov    $0xd8,%eax
f0106618:	e8 4e ff ff ff       	call   f010656b <lapicw>

	// Disable performance counter overflow interrupts
	// on machines that provide that interrupt entry.
	if (((lapic[VER]>>16) & 0xFF) >= 4)
f010661d:	a1 00 90 20 f0       	mov    0xf0209000,%eax
f0106622:	8b 40 30             	mov    0x30(%eax),%eax
f0106625:	c1 e8 10             	shr    $0x10,%eax
f0106628:	3c 03                	cmp    $0x3,%al
f010662a:	76 0f                	jbe    f010663b <lapic_init+0x9d>
		lapicw(PCINT, MASKED);
f010662c:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106631:	b8 d0 00 00 00       	mov    $0xd0,%eax
f0106636:	e8 30 ff ff ff       	call   f010656b <lapicw>

	// Map error interrupt to IRQ_ERROR.
	lapicw(ERROR, IRQ_OFFSET + IRQ_ERROR);
f010663b:	ba 33 00 00 00       	mov    $0x33,%edx
f0106640:	b8 dc 00 00 00       	mov    $0xdc,%eax
f0106645:	e8 21 ff ff ff       	call   f010656b <lapicw>

	// Clear error status register (requires back-to-back writes).
	lapicw(ESR, 0);
f010664a:	ba 00 00 00 00       	mov    $0x0,%edx
f010664f:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0106654:	e8 12 ff ff ff       	call   f010656b <lapicw>
	lapicw(ESR, 0);
f0106659:	ba 00 00 00 00       	mov    $0x0,%edx
f010665e:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0106663:	e8 03 ff ff ff       	call   f010656b <lapicw>

	// Ack any outstanding interrupts.
	lapicw(EOI, 0);
f0106668:	ba 00 00 00 00       	mov    $0x0,%edx
f010666d:	b8 2c 00 00 00       	mov    $0x2c,%eax
f0106672:	e8 f4 fe ff ff       	call   f010656b <lapicw>

	// Send an Init Level De-Assert to synchronize arbitration ID's.
	lapicw(ICRHI, 0);
f0106677:	ba 00 00 00 00       	mov    $0x0,%edx
f010667c:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106681:	e8 e5 fe ff ff       	call   f010656b <lapicw>
	lapicw(ICRLO, BCAST | INIT | LEVEL);
f0106686:	ba 00 85 08 00       	mov    $0x88500,%edx
f010668b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106690:	e8 d6 fe ff ff       	call   f010656b <lapicw>
	while(lapic[ICRLO] & DELIVS)
f0106695:	8b 15 00 90 20 f0    	mov    0xf0209000,%edx
f010669b:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f01066a1:	f6 c4 10             	test   $0x10,%ah
f01066a4:	75 f5                	jne    f010669b <lapic_init+0xfd>
		;

	// Enable interrupts on the APIC (but not on the processor).
	lapicw(TPR, 0);
f01066a6:	ba 00 00 00 00       	mov    $0x0,%edx
f01066ab:	b8 20 00 00 00       	mov    $0x20,%eax
f01066b0:	e8 b6 fe ff ff       	call   f010656b <lapicw>
}
f01066b5:	5d                   	pop    %ebp
f01066b6:	f3 c3                	repz ret 

f01066b8 <lapic_eoi>:

// Acknowledge interrupt.
void
lapic_eoi(void)
{
	if (lapic)
f01066b8:	83 3d 00 90 20 f0 00 	cmpl   $0x0,0xf0209000
f01066bf:	74 13                	je     f01066d4 <lapic_eoi+0x1c>
}

// Acknowledge interrupt.
void
lapic_eoi(void)
{
f01066c1:	55                   	push   %ebp
f01066c2:	89 e5                	mov    %esp,%ebp
	if (lapic)
		lapicw(EOI, 0);
f01066c4:	ba 00 00 00 00       	mov    $0x0,%edx
f01066c9:	b8 2c 00 00 00       	mov    $0x2c,%eax
f01066ce:	e8 98 fe ff ff       	call   f010656b <lapicw>
}
f01066d3:	5d                   	pop    %ebp
f01066d4:	f3 c3                	repz ret 

f01066d6 <lapic_startap>:

// Start additional processor running entry code at addr.
// See Appendix B of MultiProcessor Specification.
void
lapic_startap(uint8_t apicid, uint32_t addr)
{
f01066d6:	55                   	push   %ebp
f01066d7:	89 e5                	mov    %esp,%ebp
f01066d9:	56                   	push   %esi
f01066da:	53                   	push   %ebx
f01066db:	83 ec 10             	sub    $0x10,%esp
f01066de:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01066e1:	8b 75 0c             	mov    0xc(%ebp),%esi
f01066e4:	ba 70 00 00 00       	mov    $0x70,%edx
f01066e9:	b8 0f 00 00 00       	mov    $0xf,%eax
f01066ee:	ee                   	out    %al,(%dx)
f01066ef:	b2 71                	mov    $0x71,%dl
f01066f1:	b8 0a 00 00 00       	mov    $0xa,%eax
f01066f6:	ee                   	out    %al,(%dx)
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01066f7:	83 3d 88 7e 1c f0 00 	cmpl   $0x0,0xf01c7e88
f01066fe:	75 24                	jne    f0106724 <lapic_startap+0x4e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106700:	c7 44 24 0c 67 04 00 	movl   $0x467,0xc(%esp)
f0106707:	00 
f0106708:	c7 44 24 08 a4 6c 10 	movl   $0xf0106ca4,0x8(%esp)
f010670f:	f0 
f0106710:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
f0106717:	00 
f0106718:	c7 04 24 94 86 10 f0 	movl   $0xf0108694,(%esp)
f010671f:	e8 1c 99 ff ff       	call   f0100040 <_panic>
	// and the warm reset vector (DWORD based at 40:67) to point at
	// the AP startup code prior to the [universal startup algorithm]."
	outb(IO_RTC, 0xF);  // offset 0xF is shutdown code
	outb(IO_RTC+1, 0x0A);
	wrv = (uint16_t *)KADDR((0x40 << 4 | 0x67));  // Warm reset vector
	wrv[0] = 0;
f0106724:	66 c7 05 67 04 00 f0 	movw   $0x0,0xf0000467
f010672b:	00 00 
	wrv[1] = addr >> 4;
f010672d:	89 f0                	mov    %esi,%eax
f010672f:	c1 e8 04             	shr    $0x4,%eax
f0106732:	66 a3 69 04 00 f0    	mov    %ax,0xf0000469

	// "Universal startup algorithm."
	// Send INIT (level-triggered) interrupt to reset other CPU.
	lapicw(ICRHI, apicid << 24);
f0106738:	c1 e3 18             	shl    $0x18,%ebx
f010673b:	89 da                	mov    %ebx,%edx
f010673d:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106742:	e8 24 fe ff ff       	call   f010656b <lapicw>
	lapicw(ICRLO, INIT | LEVEL | ASSERT);
f0106747:	ba 00 c5 00 00       	mov    $0xc500,%edx
f010674c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106751:	e8 15 fe ff ff       	call   f010656b <lapicw>
	microdelay(200);
	lapicw(ICRLO, INIT | LEVEL);
f0106756:	ba 00 85 00 00       	mov    $0x8500,%edx
f010675b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106760:	e8 06 fe ff ff       	call   f010656b <lapicw>
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0106765:	c1 ee 0c             	shr    $0xc,%esi
f0106768:	81 ce 00 06 00 00    	or     $0x600,%esi
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f010676e:	89 da                	mov    %ebx,%edx
f0106770:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106775:	e8 f1 fd ff ff       	call   f010656b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f010677a:	89 f2                	mov    %esi,%edx
f010677c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106781:	e8 e5 fd ff ff       	call   f010656b <lapicw>
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f0106786:	89 da                	mov    %ebx,%edx
f0106788:	b8 c4 00 00 00       	mov    $0xc4,%eax
f010678d:	e8 d9 fd ff ff       	call   f010656b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0106792:	89 f2                	mov    %esi,%edx
f0106794:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106799:	e8 cd fd ff ff       	call   f010656b <lapicw>
		microdelay(200);
	}
}
f010679e:	83 c4 10             	add    $0x10,%esp
f01067a1:	5b                   	pop    %ebx
f01067a2:	5e                   	pop    %esi
f01067a3:	5d                   	pop    %ebp
f01067a4:	c3                   	ret    

f01067a5 <lapic_ipi>:

void
lapic_ipi(int vector)
{
f01067a5:	55                   	push   %ebp
f01067a6:	89 e5                	mov    %esp,%ebp
	lapicw(ICRLO, OTHERS | FIXED | vector);
f01067a8:	8b 55 08             	mov    0x8(%ebp),%edx
f01067ab:	81 ca 00 00 0c 00    	or     $0xc0000,%edx
f01067b1:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01067b6:	e8 b0 fd ff ff       	call   f010656b <lapicw>
	while (lapic[ICRLO] & DELIVS)
f01067bb:	8b 15 00 90 20 f0    	mov    0xf0209000,%edx
f01067c1:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f01067c7:	f6 c4 10             	test   $0x10,%ah
f01067ca:	75 f5                	jne    f01067c1 <lapic_ipi+0x1c>
		;
}
f01067cc:	5d                   	pop    %ebp
f01067cd:	c3                   	ret    

f01067ce <__spin_initlock>:
}
#endif

void
__spin_initlock(struct spinlock *lk, char *name)
{
f01067ce:	55                   	push   %ebp
f01067cf:	89 e5                	mov    %esp,%ebp
f01067d1:	8b 45 08             	mov    0x8(%ebp),%eax
	lk->locked = 0;
f01067d4:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
#ifdef DEBUG_SPINLOCK
	lk->name = name;
f01067da:	8b 55 0c             	mov    0xc(%ebp),%edx
f01067dd:	89 50 04             	mov    %edx,0x4(%eax)
	lk->cpu = 0;
f01067e0:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
#endif
}
f01067e7:	5d                   	pop    %ebp
f01067e8:	c3                   	ret    

f01067e9 <spin_lock>:
// Loops (spins) until the lock is acquired.
// Holding a lock for a long time may cause
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
f01067e9:	55                   	push   %ebp
f01067ea:	89 e5                	mov    %esp,%ebp
f01067ec:	56                   	push   %esi
f01067ed:	53                   	push   %ebx
f01067ee:	83 ec 20             	sub    $0x20,%esp
f01067f1:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f01067f4:	83 3b 00             	cmpl   $0x0,(%ebx)
f01067f7:	74 14                	je     f010680d <spin_lock+0x24>
f01067f9:	8b 73 08             	mov    0x8(%ebx),%esi
f01067fc:	e8 82 fd ff ff       	call   f0106583 <cpunum>
f0106801:	6b c0 74             	imul   $0x74,%eax,%eax
f0106804:	05 20 80 1c f0       	add    $0xf01c8020,%eax
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
f0106809:	39 c6                	cmp    %eax,%esi
f010680b:	74 15                	je     f0106822 <spin_lock+0x39>
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f010680d:	89 da                	mov    %ebx,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f010680f:	b8 01 00 00 00       	mov    $0x1,%eax
f0106814:	f0 87 03             	lock xchg %eax,(%ebx)
f0106817:	b9 01 00 00 00       	mov    $0x1,%ecx
f010681c:	85 c0                	test   %eax,%eax
f010681e:	75 2e                	jne    f010684e <spin_lock+0x65>
f0106820:	eb 37                	jmp    f0106859 <spin_lock+0x70>
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
		panic("CPU %d cannot acquire %s: already holding", cpunum(), lk->name);
f0106822:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106825:	e8 59 fd ff ff       	call   f0106583 <cpunum>
f010682a:	89 5c 24 10          	mov    %ebx,0x10(%esp)
f010682e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0106832:	c7 44 24 08 a4 86 10 	movl   $0xf01086a4,0x8(%esp)
f0106839:	f0 
f010683a:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
f0106841:	00 
f0106842:	c7 04 24 08 87 10 f0 	movl   $0xf0108708,(%esp)
f0106849:	e8 f2 97 ff ff       	call   f0100040 <_panic>

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
		asm volatile ("pause");
f010684e:	f3 90                	pause  
f0106850:	89 c8                	mov    %ecx,%eax
f0106852:	f0 87 02             	lock xchg %eax,(%edx)
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f0106855:	85 c0                	test   %eax,%eax
f0106857:	75 f5                	jne    f010684e <spin_lock+0x65>
		asm volatile ("pause");

	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
f0106859:	e8 25 fd ff ff       	call   f0106583 <cpunum>
f010685e:	6b c0 74             	imul   $0x74,%eax,%eax
f0106861:	05 20 80 1c f0       	add    $0xf01c8020,%eax
f0106866:	89 43 08             	mov    %eax,0x8(%ebx)
	get_caller_pcs(lk->pcs);
f0106869:	8d 4b 0c             	lea    0xc(%ebx),%ecx

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f010686c:	89 e8                	mov    %ebp,%eax
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
f010686e:	8d 90 00 00 80 10    	lea    0x10800000(%eax),%edx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0106874:	81 fa ff ff 7f 0e    	cmp    $0xe7fffff,%edx
f010687a:	76 3a                	jbe    f01068b6 <spin_lock+0xcd>
f010687c:	eb 31                	jmp    f01068af <spin_lock+0xc6>
		    || ebp >= (uint32_t *)IOMEMBASE)
f010687e:	8d 9a 00 00 80 10    	lea    0x10800000(%edx),%ebx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0106884:	81 fb ff ff 7f 0e    	cmp    $0xe7fffff,%ebx
f010688a:	77 12                	ja     f010689e <spin_lock+0xb5>
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f010688c:	8b 5a 04             	mov    0x4(%edx),%ebx
f010688f:	89 1c 81             	mov    %ebx,(%ecx,%eax,4)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f0106892:	8b 12                	mov    (%edx),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f0106894:	83 c0 01             	add    $0x1,%eax
f0106897:	83 f8 0a             	cmp    $0xa,%eax
f010689a:	75 e2                	jne    f010687e <spin_lock+0x95>
f010689c:	eb 27                	jmp    f01068c5 <spin_lock+0xdc>
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
		pcs[i] = 0;
f010689e:	c7 04 81 00 00 00 00 	movl   $0x0,(%ecx,%eax,4)
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
f01068a5:	83 c0 01             	add    $0x1,%eax
f01068a8:	83 f8 09             	cmp    $0x9,%eax
f01068ab:	7e f1                	jle    f010689e <spin_lock+0xb5>
f01068ad:	eb 16                	jmp    f01068c5 <spin_lock+0xdc>
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01068af:	b8 00 00 00 00       	mov    $0x0,%eax
f01068b4:	eb e8                	jmp    f010689e <spin_lock+0xb5>
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f01068b6:	8b 50 04             	mov    0x4(%eax),%edx
f01068b9:	89 53 0c             	mov    %edx,0xc(%ebx)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f01068bc:	8b 10                	mov    (%eax),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01068be:	b8 01 00 00 00       	mov    $0x1,%eax
f01068c3:	eb b9                	jmp    f010687e <spin_lock+0x95>
	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
	get_caller_pcs(lk->pcs);
#endif
}
f01068c5:	83 c4 20             	add    $0x20,%esp
f01068c8:	5b                   	pop    %ebx
f01068c9:	5e                   	pop    %esi
f01068ca:	5d                   	pop    %ebp
f01068cb:	c3                   	ret    

f01068cc <spin_unlock>:

// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
f01068cc:	55                   	push   %ebp
f01068cd:	89 e5                	mov    %esp,%ebp
f01068cf:	57                   	push   %edi
f01068d0:	56                   	push   %esi
f01068d1:	53                   	push   %ebx
f01068d2:	83 ec 6c             	sub    $0x6c,%esp
f01068d5:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f01068d8:	83 3b 00             	cmpl   $0x0,(%ebx)
f01068db:	74 18                	je     f01068f5 <spin_unlock+0x29>
f01068dd:	8b 73 08             	mov    0x8(%ebx),%esi
f01068e0:	e8 9e fc ff ff       	call   f0106583 <cpunum>
f01068e5:	6b c0 74             	imul   $0x74,%eax,%eax
f01068e8:	05 20 80 1c f0       	add    $0xf01c8020,%eax
// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (!holding(lk)) {
f01068ed:	39 c6                	cmp    %eax,%esi
f01068ef:	0f 84 d4 00 00 00    	je     f01069c9 <spin_unlock+0xfd>
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
f01068f5:	c7 44 24 08 28 00 00 	movl   $0x28,0x8(%esp)
f01068fc:	00 
f01068fd:	8d 43 0c             	lea    0xc(%ebx),%eax
f0106900:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106904:	8d 45 c0             	lea    -0x40(%ebp),%eax
f0106907:	89 04 24             	mov    %eax,(%esp)
f010690a:	e8 27 f6 ff ff       	call   f0105f36 <memmove>
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
f010690f:	8b 43 08             	mov    0x8(%ebx),%eax
	if (!holding(lk)) {
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
f0106912:	0f b6 30             	movzbl (%eax),%esi
f0106915:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106918:	e8 66 fc ff ff       	call   f0106583 <cpunum>
f010691d:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0106921:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0106925:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106929:	c7 04 24 d0 86 10 f0 	movl   $0xf01086d0,(%esp)
f0106930:	e8 41 d5 ff ff       	call   f0103e76 <cprintf>
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0106935:	8b 45 c0             	mov    -0x40(%ebp),%eax
f0106938:	85 c0                	test   %eax,%eax
f010693a:	74 71                	je     f01069ad <spin_unlock+0xe1>
f010693c:	8d 5d c0             	lea    -0x40(%ebp),%ebx
f010693f:	8d 7d e4             	lea    -0x1c(%ebp),%edi
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
f0106942:	8d 75 a8             	lea    -0x58(%ebp),%esi
f0106945:	89 74 24 04          	mov    %esi,0x4(%esp)
f0106949:	89 04 24             	mov    %eax,(%esp)
f010694c:	e8 0b ea ff ff       	call   f010535c <debuginfo_eip>
f0106951:	85 c0                	test   %eax,%eax
f0106953:	78 39                	js     f010698e <spin_unlock+0xc2>
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
f0106955:	8b 03                	mov    (%ebx),%eax
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
f0106957:	89 c2                	mov    %eax,%edx
f0106959:	2b 55 b8             	sub    -0x48(%ebp),%edx
f010695c:	89 54 24 18          	mov    %edx,0x18(%esp)
f0106960:	8b 55 b0             	mov    -0x50(%ebp),%edx
f0106963:	89 54 24 14          	mov    %edx,0x14(%esp)
f0106967:	8b 55 b4             	mov    -0x4c(%ebp),%edx
f010696a:	89 54 24 10          	mov    %edx,0x10(%esp)
f010696e:	8b 55 ac             	mov    -0x54(%ebp),%edx
f0106971:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0106975:	8b 55 a8             	mov    -0x58(%ebp),%edx
f0106978:	89 54 24 08          	mov    %edx,0x8(%esp)
f010697c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106980:	c7 04 24 18 87 10 f0 	movl   $0xf0108718,(%esp)
f0106987:	e8 ea d4 ff ff       	call   f0103e76 <cprintf>
f010698c:	eb 12                	jmp    f01069a0 <spin_unlock+0xd4>
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
f010698e:	8b 03                	mov    (%ebx),%eax
f0106990:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106994:	c7 04 24 2f 87 10 f0 	movl   $0xf010872f,(%esp)
f010699b:	e8 d6 d4 ff ff       	call   f0103e76 <cprintf>
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f01069a0:	39 fb                	cmp    %edi,%ebx
f01069a2:	74 09                	je     f01069ad <spin_unlock+0xe1>
f01069a4:	83 c3 04             	add    $0x4,%ebx
f01069a7:	8b 03                	mov    (%ebx),%eax
f01069a9:	85 c0                	test   %eax,%eax
f01069ab:	75 98                	jne    f0106945 <spin_unlock+0x79>
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
		}
		panic("spin_unlock");
f01069ad:	c7 44 24 08 37 87 10 	movl   $0xf0108737,0x8(%esp)
f01069b4:	f0 
f01069b5:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
f01069bc:	00 
f01069bd:	c7 04 24 08 87 10 f0 	movl   $0xf0108708,(%esp)
f01069c4:	e8 77 96 ff ff       	call   f0100040 <_panic>
	}
	
	lk->pcs[0] = 0;
f01069c9:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
	lk->cpu = 0;
f01069d0:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f01069d7:	b8 00 00 00 00       	mov    $0x0,%eax
f01069dc:	f0 87 03             	lock xchg %eax,(%ebx)
	// after a store. So lock->locked = 0 would work here.
	// The xchg being asm volatile ensures gcc emits it after
	// the above assignments (and after the critical section).
	xchg(&lk->locked, 0);

}
f01069df:	83 c4 6c             	add    $0x6c,%esp
f01069e2:	5b                   	pop    %ebx
f01069e3:	5e                   	pop    %esi
f01069e4:	5f                   	pop    %edi
f01069e5:	5d                   	pop    %ebp
f01069e6:	c3                   	ret    
f01069e7:	66 90                	xchg   %ax,%ax
f01069e9:	66 90                	xchg   %ax,%ax
f01069eb:	66 90                	xchg   %ax,%ax
f01069ed:	66 90                	xchg   %ax,%ax
f01069ef:	90                   	nop

f01069f0 <__udivdi3>:
f01069f0:	55                   	push   %ebp
f01069f1:	57                   	push   %edi
f01069f2:	56                   	push   %esi
f01069f3:	83 ec 0c             	sub    $0xc,%esp
f01069f6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01069fa:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f01069fe:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f0106a02:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0106a06:	85 c0                	test   %eax,%eax
f0106a08:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0106a0c:	89 ea                	mov    %ebp,%edx
f0106a0e:	89 0c 24             	mov    %ecx,(%esp)
f0106a11:	75 2d                	jne    f0106a40 <__udivdi3+0x50>
f0106a13:	39 e9                	cmp    %ebp,%ecx
f0106a15:	77 61                	ja     f0106a78 <__udivdi3+0x88>
f0106a17:	85 c9                	test   %ecx,%ecx
f0106a19:	89 ce                	mov    %ecx,%esi
f0106a1b:	75 0b                	jne    f0106a28 <__udivdi3+0x38>
f0106a1d:	b8 01 00 00 00       	mov    $0x1,%eax
f0106a22:	31 d2                	xor    %edx,%edx
f0106a24:	f7 f1                	div    %ecx
f0106a26:	89 c6                	mov    %eax,%esi
f0106a28:	31 d2                	xor    %edx,%edx
f0106a2a:	89 e8                	mov    %ebp,%eax
f0106a2c:	f7 f6                	div    %esi
f0106a2e:	89 c5                	mov    %eax,%ebp
f0106a30:	89 f8                	mov    %edi,%eax
f0106a32:	f7 f6                	div    %esi
f0106a34:	89 ea                	mov    %ebp,%edx
f0106a36:	83 c4 0c             	add    $0xc,%esp
f0106a39:	5e                   	pop    %esi
f0106a3a:	5f                   	pop    %edi
f0106a3b:	5d                   	pop    %ebp
f0106a3c:	c3                   	ret    
f0106a3d:	8d 76 00             	lea    0x0(%esi),%esi
f0106a40:	39 e8                	cmp    %ebp,%eax
f0106a42:	77 24                	ja     f0106a68 <__udivdi3+0x78>
f0106a44:	0f bd e8             	bsr    %eax,%ebp
f0106a47:	83 f5 1f             	xor    $0x1f,%ebp
f0106a4a:	75 3c                	jne    f0106a88 <__udivdi3+0x98>
f0106a4c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0106a50:	39 34 24             	cmp    %esi,(%esp)
f0106a53:	0f 86 9f 00 00 00    	jbe    f0106af8 <__udivdi3+0x108>
f0106a59:	39 d0                	cmp    %edx,%eax
f0106a5b:	0f 82 97 00 00 00    	jb     f0106af8 <__udivdi3+0x108>
f0106a61:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0106a68:	31 d2                	xor    %edx,%edx
f0106a6a:	31 c0                	xor    %eax,%eax
f0106a6c:	83 c4 0c             	add    $0xc,%esp
f0106a6f:	5e                   	pop    %esi
f0106a70:	5f                   	pop    %edi
f0106a71:	5d                   	pop    %ebp
f0106a72:	c3                   	ret    
f0106a73:	90                   	nop
f0106a74:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106a78:	89 f8                	mov    %edi,%eax
f0106a7a:	f7 f1                	div    %ecx
f0106a7c:	31 d2                	xor    %edx,%edx
f0106a7e:	83 c4 0c             	add    $0xc,%esp
f0106a81:	5e                   	pop    %esi
f0106a82:	5f                   	pop    %edi
f0106a83:	5d                   	pop    %ebp
f0106a84:	c3                   	ret    
f0106a85:	8d 76 00             	lea    0x0(%esi),%esi
f0106a88:	89 e9                	mov    %ebp,%ecx
f0106a8a:	8b 3c 24             	mov    (%esp),%edi
f0106a8d:	d3 e0                	shl    %cl,%eax
f0106a8f:	89 c6                	mov    %eax,%esi
f0106a91:	b8 20 00 00 00       	mov    $0x20,%eax
f0106a96:	29 e8                	sub    %ebp,%eax
f0106a98:	89 c1                	mov    %eax,%ecx
f0106a9a:	d3 ef                	shr    %cl,%edi
f0106a9c:	89 e9                	mov    %ebp,%ecx
f0106a9e:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0106aa2:	8b 3c 24             	mov    (%esp),%edi
f0106aa5:	09 74 24 08          	or     %esi,0x8(%esp)
f0106aa9:	89 d6                	mov    %edx,%esi
f0106aab:	d3 e7                	shl    %cl,%edi
f0106aad:	89 c1                	mov    %eax,%ecx
f0106aaf:	89 3c 24             	mov    %edi,(%esp)
f0106ab2:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106ab6:	d3 ee                	shr    %cl,%esi
f0106ab8:	89 e9                	mov    %ebp,%ecx
f0106aba:	d3 e2                	shl    %cl,%edx
f0106abc:	89 c1                	mov    %eax,%ecx
f0106abe:	d3 ef                	shr    %cl,%edi
f0106ac0:	09 d7                	or     %edx,%edi
f0106ac2:	89 f2                	mov    %esi,%edx
f0106ac4:	89 f8                	mov    %edi,%eax
f0106ac6:	f7 74 24 08          	divl   0x8(%esp)
f0106aca:	89 d6                	mov    %edx,%esi
f0106acc:	89 c7                	mov    %eax,%edi
f0106ace:	f7 24 24             	mull   (%esp)
f0106ad1:	39 d6                	cmp    %edx,%esi
f0106ad3:	89 14 24             	mov    %edx,(%esp)
f0106ad6:	72 30                	jb     f0106b08 <__udivdi3+0x118>
f0106ad8:	8b 54 24 04          	mov    0x4(%esp),%edx
f0106adc:	89 e9                	mov    %ebp,%ecx
f0106ade:	d3 e2                	shl    %cl,%edx
f0106ae0:	39 c2                	cmp    %eax,%edx
f0106ae2:	73 05                	jae    f0106ae9 <__udivdi3+0xf9>
f0106ae4:	3b 34 24             	cmp    (%esp),%esi
f0106ae7:	74 1f                	je     f0106b08 <__udivdi3+0x118>
f0106ae9:	89 f8                	mov    %edi,%eax
f0106aeb:	31 d2                	xor    %edx,%edx
f0106aed:	e9 7a ff ff ff       	jmp    f0106a6c <__udivdi3+0x7c>
f0106af2:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0106af8:	31 d2                	xor    %edx,%edx
f0106afa:	b8 01 00 00 00       	mov    $0x1,%eax
f0106aff:	e9 68 ff ff ff       	jmp    f0106a6c <__udivdi3+0x7c>
f0106b04:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106b08:	8d 47 ff             	lea    -0x1(%edi),%eax
f0106b0b:	31 d2                	xor    %edx,%edx
f0106b0d:	83 c4 0c             	add    $0xc,%esp
f0106b10:	5e                   	pop    %esi
f0106b11:	5f                   	pop    %edi
f0106b12:	5d                   	pop    %ebp
f0106b13:	c3                   	ret    
f0106b14:	66 90                	xchg   %ax,%ax
f0106b16:	66 90                	xchg   %ax,%ax
f0106b18:	66 90                	xchg   %ax,%ax
f0106b1a:	66 90                	xchg   %ax,%ax
f0106b1c:	66 90                	xchg   %ax,%ax
f0106b1e:	66 90                	xchg   %ax,%ax

f0106b20 <__umoddi3>:
f0106b20:	55                   	push   %ebp
f0106b21:	57                   	push   %edi
f0106b22:	56                   	push   %esi
f0106b23:	83 ec 14             	sub    $0x14,%esp
f0106b26:	8b 44 24 28          	mov    0x28(%esp),%eax
f0106b2a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0106b2e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0106b32:	89 c7                	mov    %eax,%edi
f0106b34:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106b38:	8b 44 24 30          	mov    0x30(%esp),%eax
f0106b3c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0106b40:	89 34 24             	mov    %esi,(%esp)
f0106b43:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0106b47:	85 c0                	test   %eax,%eax
f0106b49:	89 c2                	mov    %eax,%edx
f0106b4b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106b4f:	75 17                	jne    f0106b68 <__umoddi3+0x48>
f0106b51:	39 fe                	cmp    %edi,%esi
f0106b53:	76 4b                	jbe    f0106ba0 <__umoddi3+0x80>
f0106b55:	89 c8                	mov    %ecx,%eax
f0106b57:	89 fa                	mov    %edi,%edx
f0106b59:	f7 f6                	div    %esi
f0106b5b:	89 d0                	mov    %edx,%eax
f0106b5d:	31 d2                	xor    %edx,%edx
f0106b5f:	83 c4 14             	add    $0x14,%esp
f0106b62:	5e                   	pop    %esi
f0106b63:	5f                   	pop    %edi
f0106b64:	5d                   	pop    %ebp
f0106b65:	c3                   	ret    
f0106b66:	66 90                	xchg   %ax,%ax
f0106b68:	39 f8                	cmp    %edi,%eax
f0106b6a:	77 54                	ja     f0106bc0 <__umoddi3+0xa0>
f0106b6c:	0f bd e8             	bsr    %eax,%ebp
f0106b6f:	83 f5 1f             	xor    $0x1f,%ebp
f0106b72:	75 5c                	jne    f0106bd0 <__umoddi3+0xb0>
f0106b74:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0106b78:	39 3c 24             	cmp    %edi,(%esp)
f0106b7b:	0f 87 e7 00 00 00    	ja     f0106c68 <__umoddi3+0x148>
f0106b81:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106b85:	29 f1                	sub    %esi,%ecx
f0106b87:	19 c7                	sbb    %eax,%edi
f0106b89:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0106b8d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106b91:	8b 44 24 08          	mov    0x8(%esp),%eax
f0106b95:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0106b99:	83 c4 14             	add    $0x14,%esp
f0106b9c:	5e                   	pop    %esi
f0106b9d:	5f                   	pop    %edi
f0106b9e:	5d                   	pop    %ebp
f0106b9f:	c3                   	ret    
f0106ba0:	85 f6                	test   %esi,%esi
f0106ba2:	89 f5                	mov    %esi,%ebp
f0106ba4:	75 0b                	jne    f0106bb1 <__umoddi3+0x91>
f0106ba6:	b8 01 00 00 00       	mov    $0x1,%eax
f0106bab:	31 d2                	xor    %edx,%edx
f0106bad:	f7 f6                	div    %esi
f0106baf:	89 c5                	mov    %eax,%ebp
f0106bb1:	8b 44 24 04          	mov    0x4(%esp),%eax
f0106bb5:	31 d2                	xor    %edx,%edx
f0106bb7:	f7 f5                	div    %ebp
f0106bb9:	89 c8                	mov    %ecx,%eax
f0106bbb:	f7 f5                	div    %ebp
f0106bbd:	eb 9c                	jmp    f0106b5b <__umoddi3+0x3b>
f0106bbf:	90                   	nop
f0106bc0:	89 c8                	mov    %ecx,%eax
f0106bc2:	89 fa                	mov    %edi,%edx
f0106bc4:	83 c4 14             	add    $0x14,%esp
f0106bc7:	5e                   	pop    %esi
f0106bc8:	5f                   	pop    %edi
f0106bc9:	5d                   	pop    %ebp
f0106bca:	c3                   	ret    
f0106bcb:	90                   	nop
f0106bcc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106bd0:	8b 04 24             	mov    (%esp),%eax
f0106bd3:	be 20 00 00 00       	mov    $0x20,%esi
f0106bd8:	89 e9                	mov    %ebp,%ecx
f0106bda:	29 ee                	sub    %ebp,%esi
f0106bdc:	d3 e2                	shl    %cl,%edx
f0106bde:	89 f1                	mov    %esi,%ecx
f0106be0:	d3 e8                	shr    %cl,%eax
f0106be2:	89 e9                	mov    %ebp,%ecx
f0106be4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106be8:	8b 04 24             	mov    (%esp),%eax
f0106beb:	09 54 24 04          	or     %edx,0x4(%esp)
f0106bef:	89 fa                	mov    %edi,%edx
f0106bf1:	d3 e0                	shl    %cl,%eax
f0106bf3:	89 f1                	mov    %esi,%ecx
f0106bf5:	89 44 24 08          	mov    %eax,0x8(%esp)
f0106bf9:	8b 44 24 10          	mov    0x10(%esp),%eax
f0106bfd:	d3 ea                	shr    %cl,%edx
f0106bff:	89 e9                	mov    %ebp,%ecx
f0106c01:	d3 e7                	shl    %cl,%edi
f0106c03:	89 f1                	mov    %esi,%ecx
f0106c05:	d3 e8                	shr    %cl,%eax
f0106c07:	89 e9                	mov    %ebp,%ecx
f0106c09:	09 f8                	or     %edi,%eax
f0106c0b:	8b 7c 24 10          	mov    0x10(%esp),%edi
f0106c0f:	f7 74 24 04          	divl   0x4(%esp)
f0106c13:	d3 e7                	shl    %cl,%edi
f0106c15:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106c19:	89 d7                	mov    %edx,%edi
f0106c1b:	f7 64 24 08          	mull   0x8(%esp)
f0106c1f:	39 d7                	cmp    %edx,%edi
f0106c21:	89 c1                	mov    %eax,%ecx
f0106c23:	89 14 24             	mov    %edx,(%esp)
f0106c26:	72 2c                	jb     f0106c54 <__umoddi3+0x134>
f0106c28:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f0106c2c:	72 22                	jb     f0106c50 <__umoddi3+0x130>
f0106c2e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0106c32:	29 c8                	sub    %ecx,%eax
f0106c34:	19 d7                	sbb    %edx,%edi
f0106c36:	89 e9                	mov    %ebp,%ecx
f0106c38:	89 fa                	mov    %edi,%edx
f0106c3a:	d3 e8                	shr    %cl,%eax
f0106c3c:	89 f1                	mov    %esi,%ecx
f0106c3e:	d3 e2                	shl    %cl,%edx
f0106c40:	89 e9                	mov    %ebp,%ecx
f0106c42:	d3 ef                	shr    %cl,%edi
f0106c44:	09 d0                	or     %edx,%eax
f0106c46:	89 fa                	mov    %edi,%edx
f0106c48:	83 c4 14             	add    $0x14,%esp
f0106c4b:	5e                   	pop    %esi
f0106c4c:	5f                   	pop    %edi
f0106c4d:	5d                   	pop    %ebp
f0106c4e:	c3                   	ret    
f0106c4f:	90                   	nop
f0106c50:	39 d7                	cmp    %edx,%edi
f0106c52:	75 da                	jne    f0106c2e <__umoddi3+0x10e>
f0106c54:	8b 14 24             	mov    (%esp),%edx
f0106c57:	89 c1                	mov    %eax,%ecx
f0106c59:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f0106c5d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0106c61:	eb cb                	jmp    f0106c2e <__umoddi3+0x10e>
f0106c63:	90                   	nop
f0106c64:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106c68:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f0106c6c:	0f 82 0f ff ff ff    	jb     f0106b81 <__umoddi3+0x61>
f0106c72:	e9 1a ff ff ff       	jmp    f0106b91 <__umoddi3+0x71>
