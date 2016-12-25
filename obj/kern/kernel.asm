
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
f010005f:	e8 2f 65 00 00       	call   f0106593 <cpunum>
f0100064:	8b 55 0c             	mov    0xc(%ebp),%edx
f0100067:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010006b:	8b 55 08             	mov    0x8(%ebp),%edx
f010006e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100072:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100076:	c7 04 24 a0 6c 10 f0 	movl   $0xf0106ca0,(%esp)
f010007d:	e8 04 3e 00 00       	call   f0103e86 <cprintf>
	vcprintf(fmt, ap);
f0100082:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100086:	89 34 24             	mov    %esi,(%esp)
f0100089:	e8 c5 3d 00 00       	call   f0103e53 <vcprintf>
	cprintf("\n");
f010008e:	c7 04 24 78 7d 10 f0 	movl   $0xf0107d78,(%esp)
f0100095:	e8 ec 3d 00 00       	call   f0103e86 <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f010009a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000a1:	e8 6c 09 00 00       	call   f0100a12 <monitor>
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
f01000b4:	2d d3 61 1c f0       	sub    $0xf01c61d3,%eax
f01000b9:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000bd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01000c4:	00 
f01000c5:	c7 04 24 d3 61 1c f0 	movl   $0xf01c61d3,(%esp)
f01000cc:	e8 28 5e 00 00       	call   f0105ef9 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000d1:	e8 29 06 00 00       	call   f01006ff <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000d6:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000dd:	00 
f01000de:	c7 04 24 0c 6d 10 f0 	movl   $0xf0106d0c,(%esp)
f01000e5:	e8 9c 3d 00 00       	call   f0103e86 <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f01000ea:	e8 32 14 00 00       	call   f0101521 <mem_init>

	// Lab 3 user environment initialization functions
	env_init();
f01000ef:	e8 3a 35 00 00       	call   f010362e <env_init>
	trap_init();
f01000f4:	e8 30 3e 00 00       	call   f0103f29 <trap_init>

	// Lab 4 multiprocessor initialization functions
	mp_init();
f01000f9:	e8 7b 61 00 00       	call   f0106279 <mp_init>
	lapic_init();
f01000fe:	66 90                	xchg   %ax,%ax
f0100100:	e8 a9 64 00 00       	call   f01065ae <lapic_init>

	// Lab 4 multitasking initialization functions
	pic_init();
f0100105:	e8 a9 3c 00 00       	call   f0103db3 <pic_init>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f010010a:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f0100111:	e8 e3 66 00 00       	call   f01067f9 <spin_lock>
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
f0100127:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f010012e:	f0 
f010012f:	c7 44 24 04 6a 00 00 	movl   $0x6a,0x4(%esp)
f0100136:	00 
f0100137:	c7 04 24 27 6d 10 f0 	movl   $0xf0106d27,(%esp)
f010013e:	e8 fd fe ff ff       	call   f0100040 <_panic>
	void *code;
	struct Cpu *c;

	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);
f0100143:	b8 a6 61 10 f0       	mov    $0xf01061a6,%eax
f0100148:	2d 2c 61 10 f0       	sub    $0xf010612c,%eax
f010014d:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100151:	c7 44 24 04 2c 61 10 	movl   $0xf010612c,0x4(%esp)
f0100158:	f0 
f0100159:	c7 04 24 00 70 00 f0 	movl   $0xf0007000,(%esp)
f0100160:	e8 e1 5d 00 00       	call   f0105f46 <memmove>

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100165:	6b 05 c4 83 1c f0 74 	imul   $0x74,0xf01c83c4,%eax
f010016c:	05 20 80 1c f0       	add    $0xf01c8020,%eax
f0100171:	3d 20 80 1c f0       	cmp    $0xf01c8020,%eax
f0100176:	76 62                	jbe    f01001da <i386_init+0x132>
f0100178:	bb 20 80 1c f0       	mov    $0xf01c8020,%ebx
		if (c == cpus + cpunum())  // We've started already.
f010017d:	e8 11 64 00 00       	call   f0106593 <cpunum>
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
f01001ba:	e8 27 65 00 00       	call   f01066e6 <lapic_startap>
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
f01001da:	c7 04 24 33 6d 10 f0 	movl   $0xf0106d33,(%esp)
f01001e1:	e8 a0 3c 00 00       	call   f0103e86 <cprintf>
	ENV_CREATE(user_idle, ENV_TYPE_IDLE);
f01001e6:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01001ed:	00 
f01001ee:	c7 44 24 04 1d 3c 00 	movl   $0x3c1d,0x4(%esp)
f01001f5:	00 
f01001f6:	c7 04 24 0f 32 15 f0 	movl   $0xf015320f,(%esp)
f01001fd:	e8 f2 35 00 00       	call   f01037f4 <env_create>
		//cprintf("create idle env %d \n:",i);
		ENV_CREATE(user_idle, ENV_TYPE_IDLE);
	}*/

	// Start fs.
	cprintf("create fs env  \n:");
f0100202:	c7 04 24 47 6d 10 f0 	movl   $0xf0106d47,(%esp)
f0100209:	e8 78 3c 00 00       	call   f0103e86 <cprintf>
	ENV_CREATE(fs_fs, ENV_TYPE_FS);
f010020e:	c7 44 24 08 02 00 00 	movl   $0x2,0x8(%esp)
f0100215:	00 
f0100216:	c7 44 24 04 67 63 01 	movl   $0x16367,0x4(%esp)
f010021d:	00 
f010021e:	c7 04 24 6c fe 1a f0 	movl   $0xf01afe6c,(%esp)
f0100225:	e8 ca 35 00 00       	call   f01037f4 <env_create>
	//ENV_CREATE(user_yield, ENV_TYPE_USER);
	/*ENV_CREATE(user_yield, ENV_TYPE_USER);*/
	// Touch all you want.
	// ENV_CREATE(user_writemotd, ENV_TYPE_USER);
	// ENV_CREATE(user_testfile, ENV_TYPE_USER);
	cprintf("create icode env \n:");
f010022a:	c7 04 24 59 6d 10 f0 	movl   $0xf0106d59,(%esp)
f0100231:	e8 50 3c 00 00       	call   f0103e86 <cprintf>
	ENV_CREATE(user_icode, ENV_TYPE_USER);
f0100236:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f010023d:	00 
f010023e:	c7 44 24 04 4b 4c 00 	movl   $0x4c4b,0x4(%esp)
f0100245:	00 
f0100246:	c7 04 24 21 b2 1a f0 	movl   $0xf01ab221,(%esp)
f010024d:	e8 a2 35 00 00       	call   f01037f4 <env_create>

#endif // TEST*

	// Schedule and run the first user environment!
	sched_yield();
f0100252:	e8 59 49 00 00       	call   f0104bb0 <sched_yield>

f0100257 <mp_main>:
}

// Setup code for APs
void
mp_main(void)
{
f0100257:	55                   	push   %ebp
f0100258:	89 e5                	mov    %esp,%ebp
f010025a:	83 ec 18             	sub    $0x18,%esp
	// We are in high EIP now, safe to switch to kern_pgdir 
	lcr3(PADDR(kern_pgdir));
f010025d:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100262:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0100267:	77 20                	ja     f0100289 <mp_main+0x32>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0100269:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010026d:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0100274:	f0 
f0100275:	c7 44 24 04 81 00 00 	movl   $0x81,0x4(%esp)
f010027c:	00 
f010027d:	c7 04 24 27 6d 10 f0 	movl   $0xf0106d27,(%esp)
f0100284:	e8 b7 fd ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0100289:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f010028e:	0f 22 d8             	mov    %eax,%cr3
	cprintf("SMP: CPU %d starting\n", cpunum());
f0100291:	e8 fd 62 00 00       	call   f0106593 <cpunum>
f0100296:	89 44 24 04          	mov    %eax,0x4(%esp)
f010029a:	c7 04 24 6d 6d 10 f0 	movl   $0xf0106d6d,(%esp)
f01002a1:	e8 e0 3b 00 00       	call   f0103e86 <cprintf>

	lapic_init();
f01002a6:	e8 03 63 00 00       	call   f01065ae <lapic_init>
	env_init_percpu();
f01002ab:	e8 54 33 00 00       	call   f0103604 <env_init_percpu>
	trap_init_percpu();
f01002b0:	e8 eb 3b 00 00       	call   f0103ea0 <trap_init_percpu>
	xchg(&thiscpu->cpu_status, CPU_STARTED); // tell boot_aps() we're up
f01002b5:	e8 d9 62 00 00       	call   f0106593 <cpunum>
f01002ba:	6b d0 74             	imul   $0x74,%eax,%edx
f01002bd:	81 c2 20 80 1c f0    	add    $0xf01c8020,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f01002c3:	b8 01 00 00 00       	mov    $0x1,%eax
f01002c8:	f0 87 42 04          	lock xchg %eax,0x4(%edx)
f01002cc:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f01002d3:	e8 21 65 00 00       	call   f01067f9 <spin_lock>
	// to start running processes on this CPU.  But make sure that
	// only one CPU can enter the scheduler at a time!
	//
	// Your code here:
	lock_kernel();
	sched_yield();
f01002d8:	e8 d3 48 00 00       	call   f0104bb0 <sched_yield>

f01002dd <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f01002dd:	55                   	push   %ebp
f01002de:	89 e5                	mov    %esp,%ebp
f01002e0:	53                   	push   %ebx
f01002e1:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f01002e4:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f01002e7:	8b 45 0c             	mov    0xc(%ebp),%eax
f01002ea:	89 44 24 08          	mov    %eax,0x8(%esp)
f01002ee:	8b 45 08             	mov    0x8(%ebp),%eax
f01002f1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01002f5:	c7 04 24 83 6d 10 f0 	movl   $0xf0106d83,(%esp)
f01002fc:	e8 85 3b 00 00       	call   f0103e86 <cprintf>
	vcprintf(fmt, ap);
f0100301:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100305:	8b 45 10             	mov    0x10(%ebp),%eax
f0100308:	89 04 24             	mov    %eax,(%esp)
f010030b:	e8 43 3b 00 00       	call   f0103e53 <vcprintf>
	cprintf("\n");
f0100310:	c7 04 24 78 7d 10 f0 	movl   $0xf0107d78,(%esp)
f0100317:	e8 6a 3b 00 00       	call   f0103e86 <cprintf>
	va_end(ap);
}
f010031c:	83 c4 14             	add    $0x14,%esp
f010031f:	5b                   	pop    %ebx
f0100320:	5d                   	pop    %ebp
f0100321:	c3                   	ret    
f0100322:	66 90                	xchg   %ax,%ax
f0100324:	66 90                	xchg   %ax,%ax
f0100326:	66 90                	xchg   %ax,%ax
f0100328:	66 90                	xchg   %ax,%ax
f010032a:	66 90                	xchg   %ax,%ax
f010032c:	66 90                	xchg   %ax,%ax
f010032e:	66 90                	xchg   %ax,%ax

f0100330 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f0100330:	55                   	push   %ebp
f0100331:	89 e5                	mov    %esp,%ebp

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100333:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100338:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f0100339:	a8 01                	test   $0x1,%al
f010033b:	74 08                	je     f0100345 <serial_proc_data+0x15>
f010033d:	b2 f8                	mov    $0xf8,%dl
f010033f:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f0100340:	0f b6 c0             	movzbl %al,%eax
f0100343:	eb 05                	jmp    f010034a <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f0100345:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f010034a:	5d                   	pop    %ebp
f010034b:	c3                   	ret    

f010034c <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f010034c:	55                   	push   %ebp
f010034d:	89 e5                	mov    %esp,%ebp
f010034f:	53                   	push   %ebx
f0100350:	83 ec 04             	sub    $0x4,%esp
f0100353:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f0100355:	eb 2a                	jmp    f0100381 <cons_intr+0x35>
		if (c == 0)
f0100357:	85 d2                	test   %edx,%edx
f0100359:	74 26                	je     f0100381 <cons_intr+0x35>
			continue;
		cons.buf[cons.wpos++] = c;
f010035b:	a1 24 72 1c f0       	mov    0xf01c7224,%eax
f0100360:	8d 48 01             	lea    0x1(%eax),%ecx
f0100363:	89 0d 24 72 1c f0    	mov    %ecx,0xf01c7224
f0100369:	88 90 20 70 1c f0    	mov    %dl,-0xfe38fe0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f010036f:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100375:	75 0a                	jne    f0100381 <cons_intr+0x35>
			cons.wpos = 0;
f0100377:	c7 05 24 72 1c f0 00 	movl   $0x0,0xf01c7224
f010037e:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f0100381:	ff d3                	call   *%ebx
f0100383:	89 c2                	mov    %eax,%edx
f0100385:	83 f8 ff             	cmp    $0xffffffff,%eax
f0100388:	75 cd                	jne    f0100357 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f010038a:	83 c4 04             	add    $0x4,%esp
f010038d:	5b                   	pop    %ebx
f010038e:	5d                   	pop    %ebp
f010038f:	c3                   	ret    

f0100390 <kbd_proc_data>:
f0100390:	ba 64 00 00 00       	mov    $0x64,%edx
f0100395:	ec                   	in     (%dx),%al
{
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
f0100396:	a8 01                	test   $0x1,%al
f0100398:	0f 84 ef 00 00 00    	je     f010048d <kbd_proc_data+0xfd>
f010039e:	b2 60                	mov    $0x60,%dl
f01003a0:	ec                   	in     (%dx),%al
f01003a1:	89 c2                	mov    %eax,%edx
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f01003a3:	3c e0                	cmp    $0xe0,%al
f01003a5:	75 0d                	jne    f01003b4 <kbd_proc_data+0x24>
		// E0 escape character
		shift |= E0ESC;
f01003a7:	83 0d 00 70 1c f0 40 	orl    $0x40,0xf01c7000
		return 0;
f01003ae:	b8 00 00 00 00       	mov    $0x0,%eax
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f01003b3:	c3                   	ret    
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f01003b4:	55                   	push   %ebp
f01003b5:	89 e5                	mov    %esp,%ebp
f01003b7:	53                   	push   %ebx
f01003b8:	83 ec 14             	sub    $0x14,%esp

	if (data == 0xE0) {
		// E0 escape character
		shift |= E0ESC;
		return 0;
	} else if (data & 0x80) {
f01003bb:	84 c0                	test   %al,%al
f01003bd:	79 37                	jns    f01003f6 <kbd_proc_data+0x66>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f01003bf:	8b 0d 00 70 1c f0    	mov    0xf01c7000,%ecx
f01003c5:	89 cb                	mov    %ecx,%ebx
f01003c7:	83 e3 40             	and    $0x40,%ebx
f01003ca:	83 e0 7f             	and    $0x7f,%eax
f01003cd:	85 db                	test   %ebx,%ebx
f01003cf:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f01003d2:	0f b6 d2             	movzbl %dl,%edx
f01003d5:	0f b6 82 00 6f 10 f0 	movzbl -0xfef9100(%edx),%eax
f01003dc:	83 c8 40             	or     $0x40,%eax
f01003df:	0f b6 c0             	movzbl %al,%eax
f01003e2:	f7 d0                	not    %eax
f01003e4:	21 c1                	and    %eax,%ecx
f01003e6:	89 0d 00 70 1c f0    	mov    %ecx,0xf01c7000
		return 0;
f01003ec:	b8 00 00 00 00       	mov    $0x0,%eax
f01003f1:	e9 9d 00 00 00       	jmp    f0100493 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f01003f6:	8b 0d 00 70 1c f0    	mov    0xf01c7000,%ecx
f01003fc:	f6 c1 40             	test   $0x40,%cl
f01003ff:	74 0e                	je     f010040f <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f0100401:	83 c8 80             	or     $0xffffff80,%eax
f0100404:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f0100406:	83 e1 bf             	and    $0xffffffbf,%ecx
f0100409:	89 0d 00 70 1c f0    	mov    %ecx,0xf01c7000
	}

	shift |= shiftcode[data];
f010040f:	0f b6 d2             	movzbl %dl,%edx
f0100412:	0f b6 82 00 6f 10 f0 	movzbl -0xfef9100(%edx),%eax
f0100419:	0b 05 00 70 1c f0    	or     0xf01c7000,%eax
	shift ^= togglecode[data];
f010041f:	0f b6 8a 00 6e 10 f0 	movzbl -0xfef9200(%edx),%ecx
f0100426:	31 c8                	xor    %ecx,%eax
f0100428:	a3 00 70 1c f0       	mov    %eax,0xf01c7000

	c = charcode[shift & (CTL | SHIFT)][data];
f010042d:	89 c1                	mov    %eax,%ecx
f010042f:	83 e1 03             	and    $0x3,%ecx
f0100432:	8b 0c 8d e0 6d 10 f0 	mov    -0xfef9220(,%ecx,4),%ecx
f0100439:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f010043d:	0f b6 da             	movzbl %dl,%ebx
	if (shift & CAPSLOCK) {
f0100440:	a8 08                	test   $0x8,%al
f0100442:	74 1b                	je     f010045f <kbd_proc_data+0xcf>
		if ('a' <= c && c <= 'z')
f0100444:	89 da                	mov    %ebx,%edx
f0100446:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f0100449:	83 f9 19             	cmp    $0x19,%ecx
f010044c:	77 05                	ja     f0100453 <kbd_proc_data+0xc3>
			c += 'A' - 'a';
f010044e:	83 eb 20             	sub    $0x20,%ebx
f0100451:	eb 0c                	jmp    f010045f <kbd_proc_data+0xcf>
		else if ('A' <= c && c <= 'Z')
f0100453:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f0100456:	8d 4b 20             	lea    0x20(%ebx),%ecx
f0100459:	83 fa 19             	cmp    $0x19,%edx
f010045c:	0f 46 d9             	cmovbe %ecx,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f010045f:	f7 d0                	not    %eax
f0100461:	89 c2                	mov    %eax,%edx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100463:	89 d8                	mov    %ebx,%eax
			c += 'a' - 'A';
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f0100465:	f6 c2 06             	test   $0x6,%dl
f0100468:	75 29                	jne    f0100493 <kbd_proc_data+0x103>
f010046a:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f0100470:	75 21                	jne    f0100493 <kbd_proc_data+0x103>
		cprintf("Rebooting!\n");
f0100472:	c7 04 24 9d 6d 10 f0 	movl   $0xf0106d9d,(%esp)
f0100479:	e8 08 3a 00 00       	call   f0103e86 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010047e:	ba 92 00 00 00       	mov    $0x92,%edx
f0100483:	b8 03 00 00 00       	mov    $0x3,%eax
f0100488:	ee                   	out    %al,(%dx)
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100489:	89 d8                	mov    %ebx,%eax
f010048b:	eb 06                	jmp    f0100493 <kbd_proc_data+0x103>
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
		return -1;
f010048d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100492:	c3                   	ret    
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100493:	83 c4 14             	add    $0x14,%esp
f0100496:	5b                   	pop    %ebx
f0100497:	5d                   	pop    %ebp
f0100498:	c3                   	ret    

f0100499 <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f0100499:	55                   	push   %ebp
f010049a:	89 e5                	mov    %esp,%ebp
f010049c:	57                   	push   %edi
f010049d:	56                   	push   %esi
f010049e:	53                   	push   %ebx
f010049f:	83 ec 1c             	sub    $0x1c,%esp
f01004a2:	89 c7                	mov    %eax,%edi

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01004a4:	ba fd 03 00 00       	mov    $0x3fd,%edx
f01004a9:	ec                   	in     (%dx),%al
static void
serial_putc(int c)
{
	int i;
	
	for (i = 0;
f01004aa:	a8 20                	test   $0x20,%al
f01004ac:	75 21                	jne    f01004cf <cons_putc+0x36>
f01004ae:	bb 00 32 00 00       	mov    $0x3200,%ebx
f01004b3:	b9 84 00 00 00       	mov    $0x84,%ecx
f01004b8:	be fd 03 00 00       	mov    $0x3fd,%esi
f01004bd:	89 ca                	mov    %ecx,%edx
f01004bf:	ec                   	in     (%dx),%al
f01004c0:	ec                   	in     (%dx),%al
f01004c1:	ec                   	in     (%dx),%al
f01004c2:	ec                   	in     (%dx),%al
f01004c3:	89 f2                	mov    %esi,%edx
f01004c5:	ec                   	in     (%dx),%al
f01004c6:	a8 20                	test   $0x20,%al
f01004c8:	75 05                	jne    f01004cf <cons_putc+0x36>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f01004ca:	83 eb 01             	sub    $0x1,%ebx
f01004cd:	75 ee                	jne    f01004bd <cons_putc+0x24>
	     i++)
		delay();
	
	outb(COM1 + COM_TX, c);
f01004cf:	89 f8                	mov    %edi,%eax
f01004d1:	0f b6 c0             	movzbl %al,%eax
f01004d4:	89 45 e4             	mov    %eax,-0x1c(%ebp)
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01004d7:	ba f8 03 00 00       	mov    $0x3f8,%edx
f01004dc:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01004dd:	b2 79                	mov    $0x79,%dl
f01004df:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f01004e0:	84 c0                	test   %al,%al
f01004e2:	78 21                	js     f0100505 <cons_putc+0x6c>
f01004e4:	bb 00 32 00 00       	mov    $0x3200,%ebx
f01004e9:	b9 84 00 00 00       	mov    $0x84,%ecx
f01004ee:	be 79 03 00 00       	mov    $0x379,%esi
f01004f3:	89 ca                	mov    %ecx,%edx
f01004f5:	ec                   	in     (%dx),%al
f01004f6:	ec                   	in     (%dx),%al
f01004f7:	ec                   	in     (%dx),%al
f01004f8:	ec                   	in     (%dx),%al
f01004f9:	89 f2                	mov    %esi,%edx
f01004fb:	ec                   	in     (%dx),%al
f01004fc:	84 c0                	test   %al,%al
f01004fe:	78 05                	js     f0100505 <cons_putc+0x6c>
f0100500:	83 eb 01             	sub    $0x1,%ebx
f0100503:	75 ee                	jne    f01004f3 <cons_putc+0x5a>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100505:	ba 78 03 00 00       	mov    $0x378,%edx
f010050a:	0f b6 45 e4          	movzbl -0x1c(%ebp),%eax
f010050e:	ee                   	out    %al,(%dx)
f010050f:	b2 7a                	mov    $0x7a,%dl
f0100511:	b8 0d 00 00 00       	mov    $0xd,%eax
f0100516:	ee                   	out    %al,(%dx)
f0100517:	b8 08 00 00 00       	mov    $0x8,%eax
f010051c:	ee                   	out    %al,(%dx)

static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f010051d:	89 fa                	mov    %edi,%edx
f010051f:	81 e2 00 ff ff ff    	and    $0xffffff00,%edx
		c |= 0x0700;
f0100525:	89 f8                	mov    %edi,%eax
f0100527:	80 cc 07             	or     $0x7,%ah
f010052a:	85 d2                	test   %edx,%edx
f010052c:	0f 44 f8             	cmove  %eax,%edi

	switch (c & 0xff) {
f010052f:	89 f8                	mov    %edi,%eax
f0100531:	0f b6 c0             	movzbl %al,%eax
f0100534:	83 f8 09             	cmp    $0x9,%eax
f0100537:	74 79                	je     f01005b2 <cons_putc+0x119>
f0100539:	83 f8 09             	cmp    $0x9,%eax
f010053c:	7f 0a                	jg     f0100548 <cons_putc+0xaf>
f010053e:	83 f8 08             	cmp    $0x8,%eax
f0100541:	74 19                	je     f010055c <cons_putc+0xc3>
f0100543:	e9 9e 00 00 00       	jmp    f01005e6 <cons_putc+0x14d>
f0100548:	83 f8 0a             	cmp    $0xa,%eax
f010054b:	90                   	nop
f010054c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100550:	74 3a                	je     f010058c <cons_putc+0xf3>
f0100552:	83 f8 0d             	cmp    $0xd,%eax
f0100555:	74 3d                	je     f0100594 <cons_putc+0xfb>
f0100557:	e9 8a 00 00 00       	jmp    f01005e6 <cons_putc+0x14d>
	case '\b':
		if (crt_pos > 0) {
f010055c:	0f b7 05 28 72 1c f0 	movzwl 0xf01c7228,%eax
f0100563:	66 85 c0             	test   %ax,%ax
f0100566:	0f 84 e5 00 00 00    	je     f0100651 <cons_putc+0x1b8>
			crt_pos--;
f010056c:	83 e8 01             	sub    $0x1,%eax
f010056f:	66 a3 28 72 1c f0    	mov    %ax,0xf01c7228
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100575:	0f b7 c0             	movzwl %ax,%eax
f0100578:	66 81 e7 00 ff       	and    $0xff00,%di
f010057d:	83 cf 20             	or     $0x20,%edi
f0100580:	8b 15 2c 72 1c f0    	mov    0xf01c722c,%edx
f0100586:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f010058a:	eb 78                	jmp    f0100604 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f010058c:	66 83 05 28 72 1c f0 	addw   $0x50,0xf01c7228
f0100593:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f0100594:	0f b7 05 28 72 1c f0 	movzwl 0xf01c7228,%eax
f010059b:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f01005a1:	c1 e8 16             	shr    $0x16,%eax
f01005a4:	8d 04 80             	lea    (%eax,%eax,4),%eax
f01005a7:	c1 e0 04             	shl    $0x4,%eax
f01005aa:	66 a3 28 72 1c f0    	mov    %ax,0xf01c7228
f01005b0:	eb 52                	jmp    f0100604 <cons_putc+0x16b>
		break;
	case '\t':
		cons_putc(' ');
f01005b2:	b8 20 00 00 00       	mov    $0x20,%eax
f01005b7:	e8 dd fe ff ff       	call   f0100499 <cons_putc>
		cons_putc(' ');
f01005bc:	b8 20 00 00 00       	mov    $0x20,%eax
f01005c1:	e8 d3 fe ff ff       	call   f0100499 <cons_putc>
		cons_putc(' ');
f01005c6:	b8 20 00 00 00       	mov    $0x20,%eax
f01005cb:	e8 c9 fe ff ff       	call   f0100499 <cons_putc>
		cons_putc(' ');
f01005d0:	b8 20 00 00 00       	mov    $0x20,%eax
f01005d5:	e8 bf fe ff ff       	call   f0100499 <cons_putc>
		cons_putc(' ');
f01005da:	b8 20 00 00 00       	mov    $0x20,%eax
f01005df:	e8 b5 fe ff ff       	call   f0100499 <cons_putc>
f01005e4:	eb 1e                	jmp    f0100604 <cons_putc+0x16b>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f01005e6:	0f b7 05 28 72 1c f0 	movzwl 0xf01c7228,%eax
f01005ed:	8d 50 01             	lea    0x1(%eax),%edx
f01005f0:	66 89 15 28 72 1c f0 	mov    %dx,0xf01c7228
f01005f7:	0f b7 c0             	movzwl %ax,%eax
f01005fa:	8b 15 2c 72 1c f0    	mov    0xf01c722c,%edx
f0100600:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f0100604:	66 81 3d 28 72 1c f0 	cmpw   $0x7cf,0xf01c7228
f010060b:	cf 07 
f010060d:	76 42                	jbe    f0100651 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f010060f:	a1 2c 72 1c f0       	mov    0xf01c722c,%eax
f0100614:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010061b:	00 
f010061c:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100622:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100626:	89 04 24             	mov    %eax,(%esp)
f0100629:	e8 18 59 00 00       	call   f0105f46 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010062e:	8b 15 2c 72 1c f0    	mov    0xf01c722c,%edx
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f0100634:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f0100639:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f010063f:	83 c0 01             	add    $0x1,%eax
f0100642:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f0100647:	75 f0                	jne    f0100639 <cons_putc+0x1a0>
			crt_buf[i] = 0x0700 | ' ';
		crt_pos -= CRT_COLS;
f0100649:	66 83 2d 28 72 1c f0 	subw   $0x50,0xf01c7228
f0100650:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100651:	8b 0d 30 72 1c f0    	mov    0xf01c7230,%ecx
f0100657:	b8 0e 00 00 00       	mov    $0xe,%eax
f010065c:	89 ca                	mov    %ecx,%edx
f010065e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010065f:	0f b7 1d 28 72 1c f0 	movzwl 0xf01c7228,%ebx
f0100666:	8d 71 01             	lea    0x1(%ecx),%esi
f0100669:	89 d8                	mov    %ebx,%eax
f010066b:	66 c1 e8 08          	shr    $0x8,%ax
f010066f:	89 f2                	mov    %esi,%edx
f0100671:	ee                   	out    %al,(%dx)
f0100672:	b8 0f 00 00 00       	mov    $0xf,%eax
f0100677:	89 ca                	mov    %ecx,%edx
f0100679:	ee                   	out    %al,(%dx)
f010067a:	89 d8                	mov    %ebx,%eax
f010067c:	89 f2                	mov    %esi,%edx
f010067e:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f010067f:	83 c4 1c             	add    $0x1c,%esp
f0100682:	5b                   	pop    %ebx
f0100683:	5e                   	pop    %esi
f0100684:	5f                   	pop    %edi
f0100685:	5d                   	pop    %ebp
f0100686:	c3                   	ret    

f0100687 <serial_intr>:
}

void
serial_intr(void)
{
	if (serial_exists)
f0100687:	83 3d 34 72 1c f0 00 	cmpl   $0x0,0xf01c7234
f010068e:	74 11                	je     f01006a1 <serial_intr+0x1a>
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f0100690:	55                   	push   %ebp
f0100691:	89 e5                	mov    %esp,%ebp
f0100693:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
		cons_intr(serial_proc_data);
f0100696:	b8 30 03 10 f0       	mov    $0xf0100330,%eax
f010069b:	e8 ac fc ff ff       	call   f010034c <cons_intr>
}
f01006a0:	c9                   	leave  
f01006a1:	f3 c3                	repz ret 

f01006a3 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f01006a3:	55                   	push   %ebp
f01006a4:	89 e5                	mov    %esp,%ebp
f01006a6:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f01006a9:	b8 90 03 10 f0       	mov    $0xf0100390,%eax
f01006ae:	e8 99 fc ff ff       	call   f010034c <cons_intr>
}
f01006b3:	c9                   	leave  
f01006b4:	c3                   	ret    

f01006b5 <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f01006b5:	55                   	push   %ebp
f01006b6:	89 e5                	mov    %esp,%ebp
f01006b8:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f01006bb:	e8 c7 ff ff ff       	call   f0100687 <serial_intr>
	kbd_intr();
f01006c0:	e8 de ff ff ff       	call   f01006a3 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f01006c5:	a1 20 72 1c f0       	mov    0xf01c7220,%eax
f01006ca:	3b 05 24 72 1c f0    	cmp    0xf01c7224,%eax
f01006d0:	74 26                	je     f01006f8 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f01006d2:	8d 50 01             	lea    0x1(%eax),%edx
f01006d5:	89 15 20 72 1c f0    	mov    %edx,0xf01c7220
f01006db:	0f b6 88 20 70 1c f0 	movzbl -0xfe38fe0(%eax),%ecx
		if (cons.rpos == CONSBUFSIZE)
			cons.rpos = 0;
		return c;
f01006e2:	89 c8                	mov    %ecx,%eax
	kbd_intr();

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
		c = cons.buf[cons.rpos++];
		if (cons.rpos == CONSBUFSIZE)
f01006e4:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f01006ea:	75 11                	jne    f01006fd <cons_getc+0x48>
			cons.rpos = 0;
f01006ec:	c7 05 20 72 1c f0 00 	movl   $0x0,0xf01c7220
f01006f3:	00 00 00 
f01006f6:	eb 05                	jmp    f01006fd <cons_getc+0x48>
		return c;
	}
	return 0;
f01006f8:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01006fd:	c9                   	leave  
f01006fe:	c3                   	ret    

f01006ff <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f01006ff:	55                   	push   %ebp
f0100700:	89 e5                	mov    %esp,%ebp
f0100702:	57                   	push   %edi
f0100703:	56                   	push   %esi
f0100704:	53                   	push   %ebx
f0100705:	83 ec 1c             	sub    $0x1c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f0100708:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f010070f:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f0100716:	5a a5 
	if (*cp != 0xA55A) {
f0100718:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f010071f:	66 3d 5a a5          	cmp    $0xa55a,%ax
f0100723:	74 11                	je     f0100736 <cons_init+0x37>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f0100725:	c7 05 30 72 1c f0 b4 	movl   $0x3b4,0xf01c7230
f010072c:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f010072f:	bf 00 00 0b f0       	mov    $0xf00b0000,%edi
f0100734:	eb 16                	jmp    f010074c <cons_init+0x4d>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f0100736:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f010073d:	c7 05 30 72 1c f0 d4 	movl   $0x3d4,0xf01c7230
f0100744:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f0100747:	bf 00 80 0b f0       	mov    $0xf00b8000,%edi
		*cp = was;
		addr_6845 = CGA_BASE;
	}
	
	/* Extract cursor location */
	outb(addr_6845, 14);
f010074c:	8b 0d 30 72 1c f0    	mov    0xf01c7230,%ecx
f0100752:	b8 0e 00 00 00       	mov    $0xe,%eax
f0100757:	89 ca                	mov    %ecx,%edx
f0100759:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f010075a:	8d 59 01             	lea    0x1(%ecx),%ebx

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010075d:	89 da                	mov    %ebx,%edx
f010075f:	ec                   	in     (%dx),%al
f0100760:	0f b6 f0             	movzbl %al,%esi
f0100763:	c1 e6 08             	shl    $0x8,%esi
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100766:	b8 0f 00 00 00       	mov    $0xf,%eax
f010076b:	89 ca                	mov    %ecx,%edx
f010076d:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010076e:	89 da                	mov    %ebx,%edx
f0100770:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f0100771:	89 3d 2c 72 1c f0    	mov    %edi,0xf01c722c
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f0100777:	0f b6 d8             	movzbl %al,%ebx
f010077a:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f010077c:	66 89 35 28 72 1c f0 	mov    %si,0xf01c7228

static void
kbd_init(void)
{
	// Drain the kbd buffer so that Bochs generates interrupts.
	kbd_intr();
f0100783:	e8 1b ff ff ff       	call   f01006a3 <kbd_intr>
	irq_setmask_8259A(irq_mask_8259A & ~(1<<1));
f0100788:	0f b7 05 88 13 12 f0 	movzwl 0xf0121388,%eax
f010078f:	25 fd ff 00 00       	and    $0xfffd,%eax
f0100794:	89 04 24             	mov    %eax,(%esp)
f0100797:	e8 a8 35 00 00       	call   f0103d44 <irq_setmask_8259A>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010079c:	be fa 03 00 00       	mov    $0x3fa,%esi
f01007a1:	b8 00 00 00 00       	mov    $0x0,%eax
f01007a6:	89 f2                	mov    %esi,%edx
f01007a8:	ee                   	out    %al,(%dx)
f01007a9:	b2 fb                	mov    $0xfb,%dl
f01007ab:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f01007b0:	ee                   	out    %al,(%dx)
f01007b1:	bb f8 03 00 00       	mov    $0x3f8,%ebx
f01007b6:	b8 0c 00 00 00       	mov    $0xc,%eax
f01007bb:	89 da                	mov    %ebx,%edx
f01007bd:	ee                   	out    %al,(%dx)
f01007be:	b2 f9                	mov    $0xf9,%dl
f01007c0:	b8 00 00 00 00       	mov    $0x0,%eax
f01007c5:	ee                   	out    %al,(%dx)
f01007c6:	b2 fb                	mov    $0xfb,%dl
f01007c8:	b8 03 00 00 00       	mov    $0x3,%eax
f01007cd:	ee                   	out    %al,(%dx)
f01007ce:	b2 fc                	mov    $0xfc,%dl
f01007d0:	b8 00 00 00 00       	mov    $0x0,%eax
f01007d5:	ee                   	out    %al,(%dx)
f01007d6:	b2 f9                	mov    $0xf9,%dl
f01007d8:	b8 01 00 00 00       	mov    $0x1,%eax
f01007dd:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01007de:	b2 fd                	mov    $0xfd,%dl
f01007e0:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f01007e1:	3c ff                	cmp    $0xff,%al
f01007e3:	0f 95 c1             	setne  %cl
f01007e6:	0f b6 c9             	movzbl %cl,%ecx
f01007e9:	89 0d 34 72 1c f0    	mov    %ecx,0xf01c7234
f01007ef:	89 f2                	mov    %esi,%edx
f01007f1:	ec                   	in     (%dx),%al
f01007f2:	89 da                	mov    %ebx,%edx
f01007f4:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f01007f5:	85 c9                	test   %ecx,%ecx
f01007f7:	75 0c                	jne    f0100805 <cons_init+0x106>
		cprintf("Serial port does not exist!\n");
f01007f9:	c7 04 24 a9 6d 10 f0 	movl   $0xf0106da9,(%esp)
f0100800:	e8 81 36 00 00       	call   f0103e86 <cprintf>
}
f0100805:	83 c4 1c             	add    $0x1c,%esp
f0100808:	5b                   	pop    %ebx
f0100809:	5e                   	pop    %esi
f010080a:	5f                   	pop    %edi
f010080b:	5d                   	pop    %ebp
f010080c:	c3                   	ret    

f010080d <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f010080d:	55                   	push   %ebp
f010080e:	89 e5                	mov    %esp,%ebp
f0100810:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f0100813:	8b 45 08             	mov    0x8(%ebp),%eax
f0100816:	e8 7e fc ff ff       	call   f0100499 <cons_putc>
}
f010081b:	c9                   	leave  
f010081c:	c3                   	ret    

f010081d <getchar>:

int
getchar(void)
{
f010081d:	55                   	push   %ebp
f010081e:	89 e5                	mov    %esp,%ebp
f0100820:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f0100823:	e8 8d fe ff ff       	call   f01006b5 <cons_getc>
f0100828:	85 c0                	test   %eax,%eax
f010082a:	74 f7                	je     f0100823 <getchar+0x6>
		/* do nothing */;
	return c;
}
f010082c:	c9                   	leave  
f010082d:	c3                   	ret    

f010082e <iscons>:

int
iscons(int fdnum)
{
f010082e:	55                   	push   %ebp
f010082f:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f0100831:	b8 01 00 00 00       	mov    $0x1,%eax
f0100836:	5d                   	pop    %ebp
f0100837:	c3                   	ret    
f0100838:	66 90                	xchg   %ax,%ax
f010083a:	66 90                	xchg   %ax,%ax
f010083c:	66 90                	xchg   %ax,%ax
f010083e:	66 90                	xchg   %ax,%ax

f0100840 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100840:	55                   	push   %ebp
f0100841:	89 e5                	mov    %esp,%ebp
f0100843:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < NCOMMANDS; i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100846:	c7 44 24 08 00 70 10 	movl   $0xf0107000,0x8(%esp)
f010084d:	f0 
f010084e:	c7 44 24 04 1e 70 10 	movl   $0xf010701e,0x4(%esp)
f0100855:	f0 
f0100856:	c7 04 24 23 70 10 f0 	movl   $0xf0107023,(%esp)
f010085d:	e8 24 36 00 00       	call   f0103e86 <cprintf>
f0100862:	c7 44 24 08 c0 70 10 	movl   $0xf01070c0,0x8(%esp)
f0100869:	f0 
f010086a:	c7 44 24 04 2c 70 10 	movl   $0xf010702c,0x4(%esp)
f0100871:	f0 
f0100872:	c7 04 24 23 70 10 f0 	movl   $0xf0107023,(%esp)
f0100879:	e8 08 36 00 00       	call   f0103e86 <cprintf>
f010087e:	c7 44 24 08 e8 70 10 	movl   $0xf01070e8,0x8(%esp)
f0100885:	f0 
f0100886:	c7 44 24 04 35 70 10 	movl   $0xf0107035,0x4(%esp)
f010088d:	f0 
f010088e:	c7 04 24 23 70 10 f0 	movl   $0xf0107023,(%esp)
f0100895:	e8 ec 35 00 00       	call   f0103e86 <cprintf>
	return 0;
}
f010089a:	b8 00 00 00 00       	mov    $0x0,%eax
f010089f:	c9                   	leave  
f01008a0:	c3                   	ret    

f01008a1 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f01008a1:	55                   	push   %ebp
f01008a2:	89 e5                	mov    %esp,%ebp
f01008a4:	83 ec 18             	sub    $0x18,%esp
	extern char entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f01008a7:	c7 04 24 3f 70 10 f0 	movl   $0xf010703f,(%esp)
f01008ae:	e8 d3 35 00 00       	call   f0103e86 <cprintf>
	cprintf(" this is work 1 insert:\n");
f01008b3:	c7 04 24 58 70 10 f0 	movl   $0xf0107058,(%esp)
f01008ba:	e8 c7 35 00 00       	call   f0103e86 <cprintf>
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
f01008bf:	c7 44 24 08 0f 00 00 	movl   $0xf,0x8(%esp)
f01008c6:	00 
f01008c7:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
f01008ce:	00 
f01008cf:	c7 04 24 14 71 10 f0 	movl   $0xf0107114,(%esp)
f01008d6:	e8 ab 35 00 00       	call   f0103e86 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
f01008db:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f01008e2:	00 
f01008e3:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f01008ea:	f0 
f01008eb:	c7 04 24 4c 71 10 f0 	movl   $0xf010714c,(%esp)
f01008f2:	e8 8f 35 00 00       	call   f0103e86 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01008f7:	c7 44 24 08 87 6c 10 	movl   $0x106c87,0x8(%esp)
f01008fe:	00 
f01008ff:	c7 44 24 04 87 6c 10 	movl   $0xf0106c87,0x4(%esp)
f0100906:	f0 
f0100907:	c7 04 24 74 71 10 f0 	movl   $0xf0107174,(%esp)
f010090e:	e8 73 35 00 00       	call   f0103e86 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f0100913:	c7 44 24 08 d3 61 1c 	movl   $0x1c61d3,0x8(%esp)
f010091a:	00 
f010091b:	c7 44 24 04 d3 61 1c 	movl   $0xf01c61d3,0x4(%esp)
f0100922:	f0 
f0100923:	c7 04 24 98 71 10 f0 	movl   $0xf0107198,(%esp)
f010092a:	e8 57 35 00 00       	call   f0103e86 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f010092f:	c7 44 24 08 04 90 20 	movl   $0x209004,0x8(%esp)
f0100936:	00 
f0100937:	c7 44 24 04 04 90 20 	movl   $0xf0209004,0x4(%esp)
f010093e:	f0 
f010093f:	c7 04 24 bc 71 10 f0 	movl   $0xf01071bc,(%esp)
f0100946:	e8 3b 35 00 00       	call   f0103e86 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f010094b:	b8 03 94 20 f0       	mov    $0xf0209403,%eax
f0100950:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f0100955:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f010095b:	85 c0                	test   %eax,%eax
f010095d:	0f 48 c2             	cmovs  %edx,%eax
f0100960:	c1 f8 0a             	sar    $0xa,%eax
f0100963:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100967:	c7 04 24 e0 71 10 f0 	movl   $0xf01071e0,(%esp)
f010096e:	e8 13 35 00 00       	call   f0103e86 <cprintf>
		(end-entry+1023)/1024);
	return 0;
}
f0100973:	b8 00 00 00 00       	mov    $0x0,%eax
f0100978:	c9                   	leave  
f0100979:	c3                   	ret    

f010097a <mon_backtrace>:
int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f010097a:	55                   	push   %ebp
f010097b:	89 e5                	mov    %esp,%ebp
f010097d:	56                   	push   %esi
f010097e:	53                   	push   %ebx
f010097f:	83 ec 40             	sub    $0x40,%esp
	// Your code here
	cprintf("start backtrace\n");
f0100982:	c7 04 24 71 70 10 f0 	movl   $0xf0107071,(%esp)
f0100989:	e8 f8 34 00 00       	call   f0103e86 <cprintf>
	cprintf("\n");
f010098e:	c7 04 24 78 7d 10 f0 	movl   $0xf0107d78,(%esp)
f0100995:	e8 ec 34 00 00       	call   f0103e86 <cprintf>

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f010099a:	89 e8                	mov    %ebp,%eax
f010099c:	89 c1                	mov    %eax,%ecx
	uint32_t eip;
	uint32_t ebp = read_ebp();
	uint32_t esp;
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
f010099e:	83 f8 ff             	cmp    $0xffffffff,%eax
f01009a1:	74 63                	je     f0100a06 <mon_backtrace+0x8c>
		esp = ebp+8;
		eip = *(uint32_t*)(ebp+4);
f01009a3:	8b 71 04             	mov    0x4(%ecx),%esi
		if(ebp==0){
			ebp = -1;
f01009a6:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
		esp = ebp+8;
		eip = *(uint32_t*)(ebp+4);
		if(ebp==0){
f01009ab:	85 c9                	test   %ecx,%ecx
f01009ad:	74 02                	je     f01009b1 <mon_backtrace+0x37>
			ebp = -1;
		}else{
			ebp = *(uint32_t*)(ebp);
f01009af:	8b 19                	mov    (%ecx),%ebx
		}
		for(i=0;i<5;i++){
f01009b1:	b8 00 00 00 00       	mov    $0x0,%eax
		args[i] = *(uint32_t*)(esp+i*4);
f01009b6:	8b 54 81 08          	mov    0x8(%ecx,%eax,4),%edx
f01009ba:	89 54 85 e4          	mov    %edx,-0x1c(%ebp,%eax,4)
		if(ebp==0){
			ebp = -1;
		}else{
			ebp = *(uint32_t*)(ebp);
		}
		for(i=0;i<5;i++){
f01009be:	83 c0 01             	add    $0x1,%eax
f01009c1:	83 f8 05             	cmp    $0x5,%eax
f01009c4:	75 f0                	jne    f01009b6 <mon_backtrace+0x3c>
		args[i] = *(uint32_t*)(esp+i*4);
	        }
                            cprintf("ebp  %08x   eip %08x   args  %08x  %08x  %08x  %08x  %08x\n",ebp,eip,args[0],args[1],args[2],args[3],args[4]);
f01009c6:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01009c9:	89 44 24 1c          	mov    %eax,0x1c(%esp)
f01009cd:	8b 45 f0             	mov    -0x10(%ebp),%eax
f01009d0:	89 44 24 18          	mov    %eax,0x18(%esp)
f01009d4:	8b 45 ec             	mov    -0x14(%ebp),%eax
f01009d7:	89 44 24 14          	mov    %eax,0x14(%esp)
f01009db:	8b 45 e8             	mov    -0x18(%ebp),%eax
f01009de:	89 44 24 10          	mov    %eax,0x10(%esp)
f01009e2:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01009e5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01009e9:	89 74 24 08          	mov    %esi,0x8(%esp)
f01009ed:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01009f1:	c7 04 24 0c 72 10 f0 	movl   $0xf010720c,(%esp)
f01009f8:	e8 89 34 00 00       	call   f0103e86 <cprintf>
	uint32_t eip;
	uint32_t ebp = read_ebp();
	uint32_t esp;
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
f01009fd:	83 fb ff             	cmp    $0xffffffff,%ebx
f0100a00:	74 04                	je     f0100a06 <mon_backtrace+0x8c>
f0100a02:	89 d9                	mov    %ebx,%ecx
f0100a04:	eb 9d                	jmp    f01009a3 <mon_backtrace+0x29>
                            cprintf("ebp  %08x   eip %08x   args  %08x  %08x  %08x  %08x  %08x\n",ebp,eip,args[0],args[1],args[2],args[3],args[4]);

	}
	
	return 0;
}
f0100a06:	b8 00 00 00 00       	mov    $0x0,%eax
f0100a0b:	83 c4 40             	add    $0x40,%esp
f0100a0e:	5b                   	pop    %ebx
f0100a0f:	5e                   	pop    %esi
f0100a10:	5d                   	pop    %ebp
f0100a11:	c3                   	ret    

f0100a12 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f0100a12:	55                   	push   %ebp
f0100a13:	89 e5                	mov    %esp,%ebp
f0100a15:	57                   	push   %edi
f0100a16:	56                   	push   %esi
f0100a17:	53                   	push   %ebx
f0100a18:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f0100a1b:	c7 04 24 48 72 10 f0 	movl   $0xf0107248,(%esp)
f0100a22:	e8 5f 34 00 00       	call   f0103e86 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f0100a27:	c7 04 24 6c 72 10 f0 	movl   $0xf010726c,(%esp)
f0100a2e:	e8 53 34 00 00       	call   f0103e86 <cprintf>

	if (tf != NULL)
f0100a33:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f0100a37:	74 0b                	je     f0100a44 <monitor+0x32>
		print_trapframe(tf);
f0100a39:	8b 45 08             	mov    0x8(%ebp),%eax
f0100a3c:	89 04 24             	mov    %eax,(%esp)
f0100a3f:	e8 4f 3b 00 00       	call   f0104593 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f0100a44:	c7 04 24 82 70 10 f0 	movl   $0xf0107082,(%esp)
f0100a4b:	e8 d0 51 00 00       	call   f0105c20 <readline>
f0100a50:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f0100a52:	85 c0                	test   %eax,%eax
f0100a54:	74 ee                	je     f0100a44 <monitor+0x32>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f0100a56:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f0100a5d:	be 00 00 00 00       	mov    $0x0,%esi
f0100a62:	eb 0a                	jmp    f0100a6e <monitor+0x5c>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f0100a64:	c6 03 00             	movb   $0x0,(%ebx)
f0100a67:	89 f7                	mov    %esi,%edi
f0100a69:	8d 5b 01             	lea    0x1(%ebx),%ebx
f0100a6c:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f0100a6e:	0f b6 03             	movzbl (%ebx),%eax
f0100a71:	84 c0                	test   %al,%al
f0100a73:	74 6a                	je     f0100adf <monitor+0xcd>
f0100a75:	0f be c0             	movsbl %al,%eax
f0100a78:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a7c:	c7 04 24 86 70 10 f0 	movl   $0xf0107086,(%esp)
f0100a83:	e8 11 54 00 00       	call   f0105e99 <strchr>
f0100a88:	85 c0                	test   %eax,%eax
f0100a8a:	75 d8                	jne    f0100a64 <monitor+0x52>
			*buf++ = 0;
		if (*buf == 0)
f0100a8c:	80 3b 00             	cmpb   $0x0,(%ebx)
f0100a8f:	74 4e                	je     f0100adf <monitor+0xcd>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f0100a91:	83 fe 0f             	cmp    $0xf,%esi
f0100a94:	75 16                	jne    f0100aac <monitor+0x9a>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f0100a96:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f0100a9d:	00 
f0100a9e:	c7 04 24 8b 70 10 f0 	movl   $0xf010708b,(%esp)
f0100aa5:	e8 dc 33 00 00       	call   f0103e86 <cprintf>
f0100aaa:	eb 98                	jmp    f0100a44 <monitor+0x32>
			return 0;
		}
		argv[argc++] = buf;
f0100aac:	8d 7e 01             	lea    0x1(%esi),%edi
f0100aaf:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f0100ab3:	0f b6 03             	movzbl (%ebx),%eax
f0100ab6:	84 c0                	test   %al,%al
f0100ab8:	75 0c                	jne    f0100ac6 <monitor+0xb4>
f0100aba:	eb b0                	jmp    f0100a6c <monitor+0x5a>
			buf++;
f0100abc:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f0100abf:	0f b6 03             	movzbl (%ebx),%eax
f0100ac2:	84 c0                	test   %al,%al
f0100ac4:	74 a6                	je     f0100a6c <monitor+0x5a>
f0100ac6:	0f be c0             	movsbl %al,%eax
f0100ac9:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100acd:	c7 04 24 86 70 10 f0 	movl   $0xf0107086,(%esp)
f0100ad4:	e8 c0 53 00 00       	call   f0105e99 <strchr>
f0100ad9:	85 c0                	test   %eax,%eax
f0100adb:	74 df                	je     f0100abc <monitor+0xaa>
f0100add:	eb 8d                	jmp    f0100a6c <monitor+0x5a>
			buf++;
	}
	argv[argc] = 0;
f0100adf:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f0100ae6:	00 

	// Lookup and invoke the command
	if (argc == 0)
f0100ae7:	85 f6                	test   %esi,%esi
f0100ae9:	0f 84 55 ff ff ff    	je     f0100a44 <monitor+0x32>
f0100aef:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100af4:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f0100af7:	8b 04 85 a0 72 10 f0 	mov    -0xfef8d60(,%eax,4),%eax
f0100afe:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100b02:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100b05:	89 04 24             	mov    %eax,(%esp)
f0100b08:	e8 08 53 00 00       	call   f0105e15 <strcmp>
f0100b0d:	85 c0                	test   %eax,%eax
f0100b0f:	75 24                	jne    f0100b35 <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100b11:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100b14:	8b 55 08             	mov    0x8(%ebp),%edx
f0100b17:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100b1b:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100b1e:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100b22:	89 34 24             	mov    %esi,(%esp)
f0100b25:	ff 14 85 a8 72 10 f0 	call   *-0xfef8d58(,%eax,4)
		print_trapframe(tf);

	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f0100b2c:	85 c0                	test   %eax,%eax
f0100b2e:	78 25                	js     f0100b55 <monitor+0x143>
f0100b30:	e9 0f ff ff ff       	jmp    f0100a44 <monitor+0x32>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
f0100b35:	83 c3 01             	add    $0x1,%ebx
f0100b38:	83 fb 03             	cmp    $0x3,%ebx
f0100b3b:	75 b7                	jne    f0100af4 <monitor+0xe2>
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f0100b3d:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100b40:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100b44:	c7 04 24 a8 70 10 f0 	movl   $0xf01070a8,(%esp)
f0100b4b:	e8 36 33 00 00       	call   f0103e86 <cprintf>
f0100b50:	e9 ef fe ff ff       	jmp    f0100a44 <monitor+0x32>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f0100b55:	83 c4 5c             	add    $0x5c,%esp
f0100b58:	5b                   	pop    %ebx
f0100b59:	5e                   	pop    %esi
f0100b5a:	5f                   	pop    %edi
f0100b5b:	5d                   	pop    %ebp
f0100b5c:	c3                   	ret    

f0100b5d <read_eip>:
// return EIP of caller.
// does not work if inlined.
// putting at the end of the file seems to prevent inlining.
unsigned
read_eip()
{
f0100b5d:	55                   	push   %ebp
f0100b5e:	89 e5                	mov    %esp,%ebp
	uint32_t callerpc;
	__asm __volatile("movl 4(%%ebp), %0" : "=r" (callerpc));
f0100b60:	8b 45 04             	mov    0x4(%ebp),%eax
	return callerpc;
}
f0100b63:	5d                   	pop    %ebp
f0100b64:	c3                   	ret    
f0100b65:	66 90                	xchg   %ax,%ax
f0100b67:	66 90                	xchg   %ax,%ax
f0100b69:	66 90                	xchg   %ax,%ax
f0100b6b:	66 90                	xchg   %ax,%ax
f0100b6d:	66 90                	xchg   %ax,%ax
f0100b6f:	90                   	nop

f0100b70 <boot_alloc>:
// If we're out of memory, boot_alloc should panic.
// This function may ONLY be used during initialization,
// before the page_free_list list has been set up.
static void *
boot_alloc(uint32_t n)
{
f0100b70:	55                   	push   %ebp
f0100b71:	89 e5                	mov    %esp,%ebp
f0100b73:	53                   	push   %ebx
f0100b74:	83 ec 14             	sub    $0x14,%esp
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f0100b77:	83 3d 38 72 1c f0 00 	cmpl   $0x0,0xf01c7238
f0100b7e:	75 36                	jne    f0100bb6 <boot_alloc+0x46>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100b80:	ba 03 a0 20 f0       	mov    $0xf020a003,%edx
f0100b85:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0100b8b:	89 15 38 72 1c f0    	mov    %edx,0xf01c7238
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f0100b91:	85 c0                	test   %eax,%eax
f0100b93:	74 19                	je     f0100bae <boot_alloc+0x3e>
                      result = nextfree;
f0100b95:	8b 1d 38 72 1c f0    	mov    0xf01c7238,%ebx
                      nextfree += ROUNDUP(n, PGSIZE);
f0100b9b:	05 ff 0f 00 00       	add    $0xfff,%eax
f0100ba0:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100ba5:	01 d8                	add    %ebx,%eax
f0100ba7:	a3 38 72 1c f0       	mov    %eax,0xf01c7238
f0100bac:	eb 0e                	jmp    f0100bbc <boot_alloc+0x4c>
               } else if (n == 0)
                      result = nextfree;
f0100bae:	8b 1d 38 72 1c f0    	mov    0xf01c7238,%ebx
f0100bb4:	eb 06                	jmp    f0100bbc <boot_alloc+0x4c>
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f0100bb6:	85 c0                	test   %eax,%eax
f0100bb8:	74 f4                	je     f0100bae <boot_alloc+0x3e>
f0100bba:	eb d9                	jmp    f0100b95 <boot_alloc+0x25>
                      nextfree += ROUNDUP(n, PGSIZE);
               } else if (n == 0)
                      result = nextfree;
              else
                      result = NULL;
              cprintf(">>  boot_alloc() was called! Entry(virtual address) of new page is: %x\n\n", (int)result);
f0100bbc:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100bc0:	c7 04 24 c4 72 10 f0 	movl   $0xf01072c4,(%esp)
f0100bc7:	e8 ba 32 00 00       	call   f0103e86 <cprintf>
              return result;
   
	//return NULL;
}
f0100bcc:	89 d8                	mov    %ebx,%eax
f0100bce:	83 c4 14             	add    $0x14,%esp
f0100bd1:	5b                   	pop    %ebx
f0100bd2:	5d                   	pop    %ebp
f0100bd3:	c3                   	ret    

f0100bd4 <check_va2pa>:
static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
f0100bd4:	89 d1                	mov    %edx,%ecx
f0100bd6:	c1 e9 16             	shr    $0x16,%ecx
	if (!(*pgdir & PTE_P))
f0100bd9:	8b 04 88             	mov    (%eax,%ecx,4),%eax
f0100bdc:	a8 01                	test   $0x1,%al
f0100bde:	74 5d                	je     f0100c3d <check_va2pa+0x69>
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
f0100be0:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100be5:	89 c1                	mov    %eax,%ecx
f0100be7:	c1 e9 0c             	shr    $0xc,%ecx
f0100bea:	3b 0d 88 7e 1c f0    	cmp    0xf01c7e88,%ecx
f0100bf0:	72 26                	jb     f0100c18 <check_va2pa+0x44>
// this functionality for us!  We define our own version to help check
// the check_kern_pgdir() function; it shouldn't be used elsewhere.

static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
f0100bf2:	55                   	push   %ebp
f0100bf3:	89 e5                	mov    %esp,%ebp
f0100bf5:	83 ec 18             	sub    $0x18,%esp
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100bf8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100bfc:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0100c03:	f0 
f0100c04:	c7 44 24 04 9c 03 00 	movl   $0x39c,0x4(%esp)
f0100c0b:	00 
f0100c0c:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0100c13:	e8 28 f4 ff ff       	call   f0100040 <_panic>

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
f0100c18:	c1 ea 0c             	shr    $0xc,%edx
f0100c1b:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f0100c21:	8b 84 90 00 00 00 f0 	mov    -0x10000000(%eax,%edx,4),%eax
f0100c28:	89 c2                	mov    %eax,%edx
f0100c2a:	83 e2 01             	and    $0x1,%edx
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
f0100c2d:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100c32:	85 d2                	test   %edx,%edx
f0100c34:	ba ff ff ff ff       	mov    $0xffffffff,%edx
f0100c39:	0f 44 c2             	cmove  %edx,%eax
f0100c3c:	c3                   	ret    
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
f0100c3d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
}
f0100c42:	c3                   	ret    

f0100c43 <check_page_free_list>:
//
// Check that the pages on the page_free_list are reasonable.
//
static void
check_page_free_list(bool only_low_memory)
{
f0100c43:	55                   	push   %ebp
f0100c44:	89 e5                	mov    %esp,%ebp
f0100c46:	57                   	push   %edi
f0100c47:	56                   	push   %esi
f0100c48:	53                   	push   %ebx
f0100c49:	83 ec 4c             	sub    $0x4c,%esp
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100c4c:	85 c0                	test   %eax,%eax
f0100c4e:	0f 85 6a 03 00 00    	jne    f0100fbe <check_page_free_list+0x37b>
f0100c54:	e9 77 03 00 00       	jmp    f0100fd0 <check_page_free_list+0x38d>
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
		panic("'page_free_list' is a null pointer!");
f0100c59:	c7 44 24 08 10 73 10 	movl   $0xf0107310,0x8(%esp)
f0100c60:	f0 
f0100c61:	c7 44 24 04 ce 02 00 	movl   $0x2ce,0x4(%esp)
f0100c68:	00 
f0100c69:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0100c70:	e8 cb f3 ff ff       	call   f0100040 <_panic>

	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
f0100c75:	8d 55 d8             	lea    -0x28(%ebp),%edx
f0100c78:	89 55 e0             	mov    %edx,-0x20(%ebp)
f0100c7b:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100c7e:	89 55 e4             	mov    %edx,-0x1c(%ebp)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100c81:	89 c2                	mov    %eax,%edx
f0100c83:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
		for (pp = page_free_list; pp; pp = pp->pp_link) {
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
f0100c89:	f7 c2 00 e0 7f 00    	test   $0x7fe000,%edx
f0100c8f:	0f 95 c2             	setne  %dl
f0100c92:	0f b6 d2             	movzbl %dl,%edx
			*tp[pagetype] = pp;
f0100c95:	8b 4c 95 e0          	mov    -0x20(%ebp,%edx,4),%ecx
f0100c99:	89 01                	mov    %eax,(%ecx)
			tp[pagetype] = &pp->pp_link;
f0100c9b:	89 44 95 e0          	mov    %eax,-0x20(%ebp,%edx,4)
	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
		for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100c9f:	8b 00                	mov    (%eax),%eax
f0100ca1:	85 c0                	test   %eax,%eax
f0100ca3:	75 dc                	jne    f0100c81 <check_page_free_list+0x3e>
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
			*tp[pagetype] = pp;
			tp[pagetype] = &pp->pp_link;
		}
		*tp[1] = 0;
f0100ca5:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100ca8:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		*tp[0] = pp2;
f0100cae:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100cb1:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100cb4:	89 10                	mov    %edx,(%eax)
		page_free_list = pp1;
f0100cb6:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100cb9:	a3 40 72 1c f0       	mov    %eax,0xf01c7240
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100cbe:	89 c3                	mov    %eax,%ebx
f0100cc0:	85 c0                	test   %eax,%eax
f0100cc2:	74 6c                	je     f0100d30 <check_page_free_list+0xed>
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100cc4:	be 01 00 00 00       	mov    $0x1,%esi
f0100cc9:	89 d8                	mov    %ebx,%eax
f0100ccb:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f0100cd1:	c1 f8 03             	sar    $0x3,%eax
f0100cd4:	c1 e0 0c             	shl    $0xc,%eax
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
f0100cd7:	89 c2                	mov    %eax,%edx
f0100cd9:	c1 ea 16             	shr    $0x16,%edx
f0100cdc:	39 f2                	cmp    %esi,%edx
f0100cde:	73 4a                	jae    f0100d2a <check_page_free_list+0xe7>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100ce0:	89 c2                	mov    %eax,%edx
f0100ce2:	c1 ea 0c             	shr    $0xc,%edx
f0100ce5:	3b 15 88 7e 1c f0    	cmp    0xf01c7e88,%edx
f0100ceb:	72 20                	jb     f0100d0d <check_page_free_list+0xca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100ced:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100cf1:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0100cf8:	f0 
f0100cf9:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100d00:	00 
f0100d01:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f0100d08:	e8 33 f3 ff ff       	call   f0100040 <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100d0d:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100d14:	00 
f0100d15:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100d1c:	00 
	return (void *)(pa + KERNBASE);
f0100d1d:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100d22:	89 04 24             	mov    %eax,(%esp)
f0100d25:	e8 cf 51 00 00       	call   f0105ef9 <memset>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100d2a:	8b 1b                	mov    (%ebx),%ebx
f0100d2c:	85 db                	test   %ebx,%ebx
f0100d2e:	75 99                	jne    f0100cc9 <check_page_free_list+0x86>
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
f0100d30:	b8 00 00 00 00       	mov    $0x0,%eax
f0100d35:	e8 36 fe ff ff       	call   f0100b70 <boot_alloc>
f0100d3a:	89 45 c8             	mov    %eax,-0x38(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100d3d:	8b 15 40 72 1c f0    	mov    0xf01c7240,%edx
f0100d43:	85 d2                	test   %edx,%edx
f0100d45:	0f 84 27 02 00 00    	je     f0100f72 <check_page_free_list+0x32f>
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d4b:	8b 3d 90 7e 1c f0    	mov    0xf01c7e90,%edi
f0100d51:	39 fa                	cmp    %edi,%edx
f0100d53:	72 3f                	jb     f0100d94 <check_page_free_list+0x151>
		assert(pp < pages + npages);
f0100d55:	a1 88 7e 1c f0       	mov    0xf01c7e88,%eax
f0100d5a:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0100d5d:	8d 04 c7             	lea    (%edi,%eax,8),%eax
f0100d60:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100d63:	39 c2                	cmp    %eax,%edx
f0100d65:	73 56                	jae    f0100dbd <check_page_free_list+0x17a>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100d67:	89 7d d0             	mov    %edi,-0x30(%ebp)
f0100d6a:	89 d0                	mov    %edx,%eax
f0100d6c:	29 f8                	sub    %edi,%eax
f0100d6e:	a8 07                	test   $0x7,%al
f0100d70:	75 78                	jne    f0100dea <check_page_free_list+0x1a7>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100d72:	c1 f8 03             	sar    $0x3,%eax
f0100d75:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100d78:	85 c0                	test   %eax,%eax
f0100d7a:	0f 84 98 00 00 00    	je     f0100e18 <check_page_free_list+0x1d5>
		assert(page2pa(pp) != IOPHYSMEM);
f0100d80:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100d85:	0f 85 dc 00 00 00    	jne    f0100e67 <check_page_free_list+0x224>
f0100d8b:	e9 b3 00 00 00       	jmp    f0100e43 <check_page_free_list+0x200>
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d90:	39 d7                	cmp    %edx,%edi
f0100d92:	76 24                	jbe    f0100db8 <check_page_free_list+0x175>
f0100d94:	c7 44 24 0c 27 7a 10 	movl   $0xf0107a27,0xc(%esp)
f0100d9b:	f0 
f0100d9c:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0100da3:	f0 
f0100da4:	c7 44 24 04 e8 02 00 	movl   $0x2e8,0x4(%esp)
f0100dab:	00 
f0100dac:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0100db3:	e8 88 f2 ff ff       	call   f0100040 <_panic>
		assert(pp < pages + npages);
f0100db8:	3b 55 d4             	cmp    -0x2c(%ebp),%edx
f0100dbb:	72 24                	jb     f0100de1 <check_page_free_list+0x19e>
f0100dbd:	c7 44 24 0c 48 7a 10 	movl   $0xf0107a48,0xc(%esp)
f0100dc4:	f0 
f0100dc5:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0100dcc:	f0 
f0100dcd:	c7 44 24 04 e9 02 00 	movl   $0x2e9,0x4(%esp)
f0100dd4:	00 
f0100dd5:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0100ddc:	e8 5f f2 ff ff       	call   f0100040 <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100de1:	89 d0                	mov    %edx,%eax
f0100de3:	2b 45 d0             	sub    -0x30(%ebp),%eax
f0100de6:	a8 07                	test   $0x7,%al
f0100de8:	74 24                	je     f0100e0e <check_page_free_list+0x1cb>
f0100dea:	c7 44 24 0c 34 73 10 	movl   $0xf0107334,0xc(%esp)
f0100df1:	f0 
f0100df2:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0100df9:	f0 
f0100dfa:	c7 44 24 04 ea 02 00 	movl   $0x2ea,0x4(%esp)
f0100e01:	00 
f0100e02:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0100e09:	e8 32 f2 ff ff       	call   f0100040 <_panic>
f0100e0e:	c1 f8 03             	sar    $0x3,%eax
f0100e11:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100e14:	85 c0                	test   %eax,%eax
f0100e16:	75 24                	jne    f0100e3c <check_page_free_list+0x1f9>
f0100e18:	c7 44 24 0c 5c 7a 10 	movl   $0xf0107a5c,0xc(%esp)
f0100e1f:	f0 
f0100e20:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0100e27:	f0 
f0100e28:	c7 44 24 04 ed 02 00 	movl   $0x2ed,0x4(%esp)
f0100e2f:	00 
f0100e30:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0100e37:	e8 04 f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100e3c:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100e41:	75 31                	jne    f0100e74 <check_page_free_list+0x231>
f0100e43:	c7 44 24 0c 6d 7a 10 	movl   $0xf0107a6d,0xc(%esp)
f0100e4a:	f0 
f0100e4b:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0100e52:	f0 
f0100e53:	c7 44 24 04 ee 02 00 	movl   $0x2ee,0x4(%esp)
f0100e5a:	00 
f0100e5b:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0100e62:	e8 d9 f1 ff ff       	call   f0100040 <_panic>
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
f0100e67:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100e6c:	be 00 00 00 00       	mov    $0x0,%esi
f0100e71:	89 5d cc             	mov    %ebx,-0x34(%ebp)
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
f0100e74:	3d 00 f0 0f 00       	cmp    $0xff000,%eax
f0100e79:	75 24                	jne    f0100e9f <check_page_free_list+0x25c>
f0100e7b:	c7 44 24 0c 68 73 10 	movl   $0xf0107368,0xc(%esp)
f0100e82:	f0 
f0100e83:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0100e8a:	f0 
f0100e8b:	c7 44 24 04 ef 02 00 	movl   $0x2ef,0x4(%esp)
f0100e92:	00 
f0100e93:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0100e9a:	e8 a1 f1 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100e9f:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100ea4:	75 24                	jne    f0100eca <check_page_free_list+0x287>
f0100ea6:	c7 44 24 0c 86 7a 10 	movl   $0xf0107a86,0xc(%esp)
f0100ead:	f0 
f0100eae:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0100eb5:	f0 
f0100eb6:	c7 44 24 04 f0 02 00 	movl   $0x2f0,0x4(%esp)
f0100ebd:	00 
f0100ebe:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0100ec5:	e8 76 f1 ff ff       	call   f0100040 <_panic>
f0100eca:	89 c1                	mov    %eax,%ecx
		//assert((char *) page2kva(pp) >= first_free_page );
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
f0100ecc:	3d ff ff 0f 00       	cmp    $0xfffff,%eax
f0100ed1:	0f 86 07 01 00 00    	jbe    f0100fde <check_page_free_list+0x39b>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100ed7:	89 c3                	mov    %eax,%ebx
f0100ed9:	c1 eb 0c             	shr    $0xc,%ebx
f0100edc:	39 5d c4             	cmp    %ebx,-0x3c(%ebp)
f0100edf:	77 20                	ja     f0100f01 <check_page_free_list+0x2be>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100ee1:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100ee5:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0100eec:	f0 
f0100eed:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100ef4:	00 
f0100ef5:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f0100efc:	e8 3f f1 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0100f01:	81 e9 00 00 00 10    	sub    $0x10000000,%ecx
f0100f07:	39 4d c8             	cmp    %ecx,-0x38(%ebp)
f0100f0a:	0f 86 de 00 00 00    	jbe    f0100fee <check_page_free_list+0x3ab>
f0100f10:	c7 44 24 0c 8c 73 10 	movl   $0xf010738c,0xc(%esp)
f0100f17:	f0 
f0100f18:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0100f1f:	f0 
f0100f20:	c7 44 24 04 f2 02 00 	movl   $0x2f2,0x4(%esp)
f0100f27:	00 
f0100f28:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0100f2f:	e8 0c f1 ff ff       	call   f0100040 <_panic>
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100f34:	c7 44 24 0c a0 7a 10 	movl   $0xf0107aa0,0xc(%esp)
f0100f3b:	f0 
f0100f3c:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0100f43:	f0 
f0100f44:	c7 44 24 04 f4 02 00 	movl   $0x2f4,0x4(%esp)
f0100f4b:	00 
f0100f4c:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0100f53:	e8 e8 f0 ff ff       	call   f0100040 <_panic>

		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
f0100f58:	83 c6 01             	add    $0x1,%esi
f0100f5b:	eb 04                	jmp    f0100f61 <check_page_free_list+0x31e>
		else
			++nfree_extmem;
f0100f5d:	83 45 cc 01          	addl   $0x1,-0x34(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100f61:	8b 12                	mov    (%edx),%edx
f0100f63:	85 d2                	test   %edx,%edx
f0100f65:	0f 85 25 fe ff ff    	jne    f0100d90 <check_page_free_list+0x14d>
f0100f6b:	8b 5d cc             	mov    -0x34(%ebp),%ebx
		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
		else
			++nfree_extmem;
	}
	assert(nfree_basemem > 0);
f0100f6e:	85 f6                	test   %esi,%esi
f0100f70:	7f 24                	jg     f0100f96 <check_page_free_list+0x353>
f0100f72:	c7 44 24 0c bd 7a 10 	movl   $0xf0107abd,0xc(%esp)
f0100f79:	f0 
f0100f7a:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0100f81:	f0 
f0100f82:	c7 44 24 04 fb 02 00 	movl   $0x2fb,0x4(%esp)
f0100f89:	00 
f0100f8a:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0100f91:	e8 aa f0 ff ff       	call   f0100040 <_panic>
	assert(nfree_extmem > 0);
f0100f96:	85 db                	test   %ebx,%ebx
f0100f98:	7f 74                	jg     f010100e <check_page_free_list+0x3cb>
f0100f9a:	c7 44 24 0c cf 7a 10 	movl   $0xf0107acf,0xc(%esp)
f0100fa1:	f0 
f0100fa2:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0100fa9:	f0 
f0100faa:	c7 44 24 04 fc 02 00 	movl   $0x2fc,0x4(%esp)
f0100fb1:	00 
f0100fb2:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0100fb9:	e8 82 f0 ff ff       	call   f0100040 <_panic>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100fbe:	a1 40 72 1c f0       	mov    0xf01c7240,%eax
f0100fc3:	85 c0                	test   %eax,%eax
f0100fc5:	0f 85 aa fc ff ff    	jne    f0100c75 <check_page_free_list+0x32>
f0100fcb:	e9 89 fc ff ff       	jmp    f0100c59 <check_page_free_list+0x16>
f0100fd0:	83 3d 40 72 1c f0 00 	cmpl   $0x0,0xf01c7240
f0100fd7:	75 25                	jne    f0100ffe <check_page_free_list+0x3bb>
f0100fd9:	e9 7b fc ff ff       	jmp    f0100c59 <check_page_free_list+0x16>
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
		assert(page2pa(pp) != EXTPHYSMEM);
		//assert((char *) page2kva(pp) >= first_free_page );
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100fde:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100fe3:	0f 85 6f ff ff ff    	jne    f0100f58 <check_page_free_list+0x315>
f0100fe9:	e9 46 ff ff ff       	jmp    f0100f34 <check_page_free_list+0x2f1>
f0100fee:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100ff3:	0f 85 64 ff ff ff    	jne    f0100f5d <check_page_free_list+0x31a>
f0100ff9:	e9 36 ff ff ff       	jmp    f0100f34 <check_page_free_list+0x2f1>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100ffe:	8b 1d 40 72 1c f0    	mov    0xf01c7240,%ebx
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0101004:	be 00 04 00 00       	mov    $0x400,%esi
f0101009:	e9 bb fc ff ff       	jmp    f0100cc9 <check_page_free_list+0x86>
		else
			++nfree_extmem;
	}
	assert(nfree_basemem > 0);
	assert(nfree_extmem > 0);
}
f010100e:	83 c4 4c             	add    $0x4c,%esp
f0101011:	5b                   	pop    %ebx
f0101012:	5e                   	pop    %esi
f0101013:	5f                   	pop    %edi
f0101014:	5d                   	pop    %ebp
f0101015:	c3                   	ret    

f0101016 <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0101016:	55                   	push   %ebp
f0101017:	89 e5                	mov    %esp,%ebp
f0101019:	56                   	push   %esi
f010101a:	53                   	push   %ebx
f010101b:	83 ec 10             	sub    $0x10,%esp
	size_t i = 1;
	for (i; i < npages_basemem; i++) {
f010101e:	8b 35 44 72 1c f0    	mov    0xf01c7244,%esi
f0101024:	83 fe 01             	cmp    $0x1,%esi
f0101027:	76 39                	jbe    f0101062 <page_init+0x4c>
f0101029:	8b 1d 40 72 1c f0    	mov    0xf01c7240,%ebx
// memory via the page_free_list.
//
void
page_init(void)
{
	size_t i = 1;
f010102f:	b8 01 00 00 00       	mov    $0x1,%eax
f0101034:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
	for (i; i < npages_basemem; i++) {
		pages[i].pp_ref = 0;
f010103b:	89 d1                	mov    %edx,%ecx
f010103d:	03 0d 90 7e 1c f0    	add    0xf01c7e90,%ecx
f0101043:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0101049:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f010104b:	03 15 90 7e 1c f0    	add    0xf01c7e90,%edx
//
void
page_init(void)
{
	size_t i = 1;
	for (i; i < npages_basemem; i++) {
f0101051:	83 c0 01             	add    $0x1,%eax
f0101054:	39 f0                	cmp    %esi,%eax
f0101056:	73 04                	jae    f010105c <page_init+0x46>
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f0101058:	89 d3                	mov    %edx,%ebx
f010105a:	eb d8                	jmp    f0101034 <page_init+0x1e>
f010105c:	89 15 40 72 1c f0    	mov    %edx,0xf01c7240
	}

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
f0101062:	8b 0d 88 7e 1c f0    	mov    0xf01c7e88,%ecx
f0101068:	a1 90 7e 1c f0       	mov    0xf01c7e90,%eax
f010106d:	8d 84 c8 ff ff 01 10 	lea    0x1001ffff(%eax,%ecx,8),%eax
f0101074:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0101079:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f010107f:	85 c0                	test   %eax,%eax
f0101081:	0f 48 c2             	cmovs  %edx,%eax
f0101084:	c1 f8 0c             	sar    $0xc,%eax
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f0101087:	89 c2                	mov    %eax,%edx
f0101089:	39 c1                	cmp    %eax,%ecx
f010108b:	76 37                	jbe    f01010c4 <page_init+0xae>
f010108d:	8b 1d 40 72 1c f0    	mov    0xf01c7240,%ebx
f0101093:	c1 e0 03             	shl    $0x3,%eax
		pages[i].pp_ref = 0;
f0101096:	89 c1                	mov    %eax,%ecx
f0101098:	03 0d 90 7e 1c f0    	add    0xf01c7e90,%ecx
f010109e:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f01010a4:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f01010a6:	89 c3                	mov    %eax,%ebx
f01010a8:	03 1d 90 7e 1c f0    	add    0xf01c7e90,%ebx

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f01010ae:	83 c2 01             	add    $0x1,%edx
f01010b1:	8b 0d 88 7e 1c f0    	mov    0xf01c7e88,%ecx
f01010b7:	83 c0 08             	add    $0x8,%eax
f01010ba:	39 d1                	cmp    %edx,%ecx
f01010bc:	77 d8                	ja     f0101096 <page_init+0x80>
f01010be:	89 1d 40 72 1c f0    	mov    %ebx,0xf01c7240
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01010c4:	83 f9 07             	cmp    $0x7,%ecx
f01010c7:	77 1c                	ja     f01010e5 <page_init+0xcf>
		panic("pa2page called with invalid pa");
f01010c9:	c7 44 24 08 d4 73 10 	movl   $0xf01073d4,0x8(%esp)
f01010d0:	f0 
f01010d1:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01010d8:	00 
f01010d9:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f01010e0:	e8 5b ef ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f01010e5:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
               ppg_end->pp_link = ppg_start;*/

               //remain the page of mp entry Code
               extern unsigned char mpentry_start[], mpentry_end[];
               struct Page *ppg_start = pa2page((physaddr_t)MPENTRY_PADDR);      
               struct Page * ppg_end = pa2page((physaddr_t)(MPENTRY_PADDR+mpentry_end - mpentry_start));  
f01010eb:	b8 a6 d1 10 f0       	mov    $0xf010d1a6,%eax
f01010f0:	2d 2c 61 10 f0       	sub    $0xf010612c,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01010f5:	c1 e8 0c             	shr    $0xc,%eax
f01010f8:	39 c8                	cmp    %ecx,%eax
f01010fa:	72 1c                	jb     f0101118 <page_init+0x102>
		panic("pa2page called with invalid pa");
f01010fc:	c7 44 24 08 d4 73 10 	movl   $0xf01073d4,0x8(%esp)
f0101103:	f0 
f0101104:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010110b:	00 
f010110c:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f0101113:	e8 28 ef ff ff       	call   f0100040 <_panic>
               ppg_start--;    ppg_end++;
f0101118:	8d 4a 30             	lea    0x30(%edx),%ecx
f010111b:	89 4c c2 08          	mov    %ecx,0x8(%edx,%eax,8)
               ppg_end->pp_link = ppg_start;

              // cprintf("MPENTRY_PADDR_page_start:  %d\n",PGNUM(page2pa(ppg_start)));
               //cprintf("MPENTRY_PADDR_page_end:  %d\n",PGNUM(page2pa(ppg_end)));
               //cprintf("\n");
}
f010111f:	83 c4 10             	add    $0x10,%esp
f0101122:	5b                   	pop    %ebx
f0101123:	5e                   	pop    %esi
f0101124:	5d                   	pop    %ebp
f0101125:	c3                   	ret    

f0101126 <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
f0101126:	55                   	push   %ebp
f0101127:	89 e5                	mov    %esp,%ebp
f0101129:	53                   	push   %ebx
f010112a:	83 ec 14             	sub    $0x14,%esp
	//test output
              //cprintf(">>  page_alloc() was called!\n");

             if (page_free_list == NULL)
f010112d:	8b 1d 40 72 1c f0    	mov    0xf01c7240,%ebx
f0101133:	85 db                	test   %ebx,%ebx
f0101135:	74 69                	je     f01011a0 <page_alloc+0x7a>
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
f0101137:	8b 03                	mov    (%ebx),%eax
f0101139:	a3 40 72 1c f0       	mov    %eax,0xf01c7240
    
             if (alloc_flags & ALLOC_ZERO)
                    memset(page2kva(result), 0, PGSIZE);
        
             return result;
f010113e:	89 d8                	mov    %ebx,%eax
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
    
             if (alloc_flags & ALLOC_ZERO)
f0101140:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f0101144:	74 5f                	je     f01011a5 <page_alloc+0x7f>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101146:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f010114c:	c1 f8 03             	sar    $0x3,%eax
f010114f:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101152:	89 c2                	mov    %eax,%edx
f0101154:	c1 ea 0c             	shr    $0xc,%edx
f0101157:	3b 15 88 7e 1c f0    	cmp    0xf01c7e88,%edx
f010115d:	72 20                	jb     f010117f <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010115f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101163:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f010116a:	f0 
f010116b:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101172:	00 
f0101173:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f010117a:	e8 c1 ee ff ff       	call   f0100040 <_panic>
                    memset(page2kva(result), 0, PGSIZE);
f010117f:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101186:	00 
f0101187:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010118e:	00 
	return (void *)(pa + KERNBASE);
f010118f:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101194:	89 04 24             	mov    %eax,(%esp)
f0101197:	e8 5d 4d 00 00       	call   f0105ef9 <memset>
        
             return result;
f010119c:	89 d8                	mov    %ebx,%eax
f010119e:	eb 05                	jmp    f01011a5 <page_alloc+0x7f>
{
	//test output
              //cprintf(">>  page_alloc() was called!\n");

             if (page_free_list == NULL)
                             return NULL;
f01011a0:	b8 00 00 00 00       	mov    $0x0,%eax
    
             if (alloc_flags & ALLOC_ZERO)
                    memset(page2kva(result), 0, PGSIZE);
        
             return result;
}
f01011a5:	83 c4 14             	add    $0x14,%esp
f01011a8:	5b                   	pop    %ebx
f01011a9:	5d                   	pop    %ebp
f01011aa:	c3                   	ret    

f01011ab <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct Page *pp)
{
f01011ab:	55                   	push   %ebp
f01011ac:	89 e5                	mov    %esp,%ebp
f01011ae:	8b 45 08             	mov    0x8(%ebp),%eax
	pp->pp_link = page_free_list;
f01011b1:	8b 15 40 72 1c f0    	mov    0xf01c7240,%edx
f01011b7:	89 10                	mov    %edx,(%eax)
              page_free_list = pp;
f01011b9:	a3 40 72 1c f0       	mov    %eax,0xf01c7240
	// Fill this function in
}
f01011be:	5d                   	pop    %ebp
f01011bf:	c3                   	ret    

f01011c0 <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct Page* pp)
{
f01011c0:	55                   	push   %ebp
f01011c1:	89 e5                	mov    %esp,%ebp
f01011c3:	83 ec 04             	sub    $0x4,%esp
f01011c6:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f01011c9:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f01011cd:	8d 51 ff             	lea    -0x1(%ecx),%edx
f01011d0:	66 89 50 04          	mov    %dx,0x4(%eax)
f01011d4:	66 85 d2             	test   %dx,%dx
f01011d7:	75 08                	jne    f01011e1 <page_decref+0x21>
		page_free(pp);
f01011d9:	89 04 24             	mov    %eax,(%esp)
f01011dc:	e8 ca ff ff ff       	call   f01011ab <page_free>
}
f01011e1:	c9                   	leave  
f01011e2:	c3                   	ret    

f01011e3 <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f01011e3:	55                   	push   %ebp
f01011e4:	89 e5                	mov    %esp,%ebp
f01011e6:	56                   	push   %esi
f01011e7:	53                   	push   %ebx
f01011e8:	83 ec 10             	sub    $0x10,%esp
f01011eb:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	// Fill this function in
	//test output
              //cprintf(">>  pgdir_walk() was called!\n");

             pte_t *result;
            if (pgdir[PDX(va)] == (pte_t)NULL) {            //yet to create
f01011ee:	89 de                	mov    %ebx,%esi
f01011f0:	c1 ee 16             	shr    $0x16,%esi
f01011f3:	c1 e6 02             	shl    $0x2,%esi
f01011f6:	03 75 08             	add    0x8(%ebp),%esi
f01011f9:	8b 06                	mov    (%esi),%eax
f01011fb:	85 c0                	test   %eax,%eax
f01011fd:	75 76                	jne    f0101275 <pgdir_walk+0x92>
                      if (create == 0)
f01011ff:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f0101203:	0f 84 d1 00 00 00    	je     f01012da <pgdir_walk+0xf7>
                                        return NULL;
                     else {
                                        struct Page *tmp = page_alloc(ALLOC_ZERO);
f0101209:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101210:	e8 11 ff ff ff       	call   f0101126 <page_alloc>
                                        if (tmp == NULL)
f0101215:	85 c0                	test   %eax,%eax
f0101217:	0f 84 c4 00 00 00    	je     f01012e1 <pgdir_walk+0xfe>
                                                  return NULL;                        //failed to alloc
                                        else {
                                                  tmp->pp_ref++;
f010121d:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101222:	89 c2                	mov    %eax,%edx
f0101224:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f010122a:	c1 fa 03             	sar    $0x3,%edx
f010122d:	c1 e2 0c             	shl    $0xc,%edx
                                                  pgdir[PDX(va)] = page2pa(tmp) | PTE_P | PTE_W |PTE_U;    //save the physical address of newly allocated page in page dir
f0101230:	83 ca 07             	or     $0x7,%edx
f0101233:	89 16                	mov    %edx,(%esi)
f0101235:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f010123b:	c1 f8 03             	sar    $0x3,%eax
f010123e:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101241:	89 c2                	mov    %eax,%edx
f0101243:	c1 ea 0c             	shr    $0xc,%edx
f0101246:	3b 15 88 7e 1c f0    	cmp    0xf01c7e88,%edx
f010124c:	72 20                	jb     f010126e <pgdir_walk+0x8b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010124e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101252:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0101259:	f0 
f010125a:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101261:	00 
f0101262:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f0101269:	e8 d2 ed ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f010126e:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101273:	eb 58                	jmp    f01012cd <pgdir_walk+0xea>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101275:	c1 e8 0c             	shr    $0xc,%eax
f0101278:	8b 15 88 7e 1c f0    	mov    0xf01c7e88,%edx
f010127e:	39 d0                	cmp    %edx,%eax
f0101280:	72 1c                	jb     f010129e <pgdir_walk+0xbb>
		panic("pa2page called with invalid pa");
f0101282:	c7 44 24 08 d4 73 10 	movl   $0xf01073d4,0x8(%esp)
f0101289:	f0 
f010128a:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101291:	00 
f0101292:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f0101299:	e8 a2 ed ff ff       	call   f0100040 <_panic>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010129e:	89 c1                	mov    %eax,%ecx
f01012a0:	c1 e1 0c             	shl    $0xc,%ecx
f01012a3:	39 d0                	cmp    %edx,%eax
f01012a5:	72 20                	jb     f01012c7 <pgdir_walk+0xe4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01012a7:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01012ab:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f01012b2:	f0 
f01012b3:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01012ba:	00 
f01012bb:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f01012c2:	e8 79 ed ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01012c7:	8d 81 00 00 00 f0    	lea    -0x10000000(%ecx),%eax
                                  }
                 }
               else                        
               result = page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
        
               return &result[PTX(va)];
f01012cd:	c1 eb 0a             	shr    $0xa,%ebx
f01012d0:	81 e3 fc 0f 00 00    	and    $0xffc,%ebx
f01012d6:	01 d8                	add    %ebx,%eax
f01012d8:	eb 0c                	jmp    f01012e6 <pgdir_walk+0x103>
              //cprintf(">>  pgdir_walk() was called!\n");

             pte_t *result;
            if (pgdir[PDX(va)] == (pte_t)NULL) {            //yet to create
                      if (create == 0)
                                        return NULL;
f01012da:	b8 00 00 00 00       	mov    $0x0,%eax
f01012df:	eb 05                	jmp    f01012e6 <pgdir_walk+0x103>
                     else {
                                        struct Page *tmp = page_alloc(ALLOC_ZERO);
                                        if (tmp == NULL)
                                                  return NULL;                        //failed to alloc
f01012e1:	b8 00 00 00 00       	mov    $0x0,%eax
                 }
               else                        
               result = page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
        
               return &result[PTX(va)];
}
f01012e6:	83 c4 10             	add    $0x10,%esp
f01012e9:	5b                   	pop    %ebx
f01012ea:	5e                   	pop    %esi
f01012eb:	5d                   	pop    %ebp
f01012ec:	c3                   	ret    

f01012ed <boot_map_region>:
// mapped pages.
//
// Hint: the TA solution uses pgdir_walk
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
f01012ed:	55                   	push   %ebp
f01012ee:	89 e5                	mov    %esp,%ebp
f01012f0:	57                   	push   %edi
f01012f1:	56                   	push   %esi
f01012f2:	53                   	push   %ebx
f01012f3:	83 ec 2c             	sub    $0x2c,%esp
	size_t i = 0;
	pte_t * pgEntry;
	for(i;i<(size/PGSIZE);i++){
f01012f6:	c1 e9 0c             	shr    $0xc,%ecx
f01012f9:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
f01012fc:	85 c9                	test   %ecx,%ecx
f01012fe:	74 6d                	je     f010136d <boot_map_region+0x80>
f0101300:	89 c7                	mov    %eax,%edi
f0101302:	89 d3                	mov    %edx,%ebx
//
// Hint: the TA solution uses pgdir_walk
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	size_t i = 0;
f0101304:	be 00 00 00 00       	mov    $0x0,%esi
	for(i;i<(size/PGSIZE);i++){
		pgEntry = pgdir_walk(pgdir,(void*)(va+i*PGSIZE),1);
		if(pgEntry==NULL){
			panic("kern page not allocated!\n");
		}
		(*pgEntry) = PTE_ADDR(pa + PGSIZE * i) | perm | PTE_P;
f0101309:	8b 45 0c             	mov    0xc(%ebp),%eax
f010130c:	83 c8 01             	or     $0x1,%eax
f010130f:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0101312:	8b 45 08             	mov    0x8(%ebp),%eax
f0101315:	29 d0                	sub    %edx,%eax
f0101317:	89 45 dc             	mov    %eax,-0x24(%ebp)
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	size_t i = 0;
	pte_t * pgEntry;
	for(i;i<(size/PGSIZE);i++){
		pgEntry = pgdir_walk(pgdir,(void*)(va+i*PGSIZE),1);
f010131a:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0101321:	00 
f0101322:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101326:	89 3c 24             	mov    %edi,(%esp)
f0101329:	e8 b5 fe ff ff       	call   f01011e3 <pgdir_walk>
		if(pgEntry==NULL){
f010132e:	85 c0                	test   %eax,%eax
f0101330:	75 1c                	jne    f010134e <boot_map_region+0x61>
			panic("kern page not allocated!\n");
f0101332:	c7 44 24 08 e0 7a 10 	movl   $0xf0107ae0,0x8(%esp)
f0101339:	f0 
f010133a:	c7 44 24 04 f3 01 00 	movl   $0x1f3,0x4(%esp)
f0101341:	00 
f0101342:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101349:	e8 f2 ec ff ff       	call   f0100040 <_panic>
f010134e:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0101351:	8d 14 19             	lea    (%ecx,%ebx,1),%edx
		}
		(*pgEntry) = PTE_ADDR(pa + PGSIZE * i) | perm | PTE_P;
f0101354:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f010135a:	0b 55 e0             	or     -0x20(%ebp),%edx
f010135d:	89 10                	mov    %edx,(%eax)
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	size_t i = 0;
	pte_t * pgEntry;
	for(i;i<(size/PGSIZE);i++){
f010135f:	83 c6 01             	add    $0x1,%esi
f0101362:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0101368:	3b 75 e4             	cmp    -0x1c(%ebp),%esi
f010136b:	75 ad                	jne    f010131a <boot_map_region+0x2d>
			panic("kern page not allocated!\n");
		}
		(*pgEntry) = PTE_ADDR(pa + PGSIZE * i) | perm | PTE_P;
	}
	// Fill this function in
}
f010136d:	83 c4 2c             	add    $0x2c,%esp
f0101370:	5b                   	pop    %ebx
f0101371:	5e                   	pop    %esi
f0101372:	5f                   	pop    %edi
f0101373:	5d                   	pop    %ebp
f0101374:	c3                   	ret    

f0101375 <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f0101375:	55                   	push   %ebp
f0101376:	89 e5                	mov    %esp,%ebp
f0101378:	53                   	push   %ebx
f0101379:	83 ec 14             	sub    $0x14,%esp
f010137c:	8b 5d 10             	mov    0x10(%ebp),%ebx
	// Fill this function in
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
f010137f:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101386:	00 
f0101387:	8b 45 0c             	mov    0xc(%ebp),%eax
f010138a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010138e:	8b 45 08             	mov    0x8(%ebp),%eax
f0101391:	89 04 24             	mov    %eax,(%esp)
f0101394:	e8 4a fe ff ff       	call   f01011e3 <pgdir_walk>
              if (pte == NULL)
f0101399:	85 c0                	test   %eax,%eax
f010139b:	74 3a                	je     f01013d7 <page_lookup+0x62>
                       return NULL;

             if (pte_store != 0)
f010139d:	85 db                	test   %ebx,%ebx
f010139f:	74 02                	je     f01013a3 <page_lookup+0x2e>
                     *pte_store = pte;
f01013a1:	89 03                	mov    %eax,(%ebx)

             return pa2page(PTE_ADDR(pte[0]));
f01013a3:	8b 00                	mov    (%eax),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01013a5:	c1 e8 0c             	shr    $0xc,%eax
f01013a8:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f01013ae:	72 1c                	jb     f01013cc <page_lookup+0x57>
		panic("pa2page called with invalid pa");
f01013b0:	c7 44 24 08 d4 73 10 	movl   $0xf01073d4,0x8(%esp)
f01013b7:	f0 
f01013b8:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01013bf:	00 
f01013c0:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f01013c7:	e8 74 ec ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f01013cc:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
f01013d2:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01013d5:	eb 05                	jmp    f01013dc <page_lookup+0x67>
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
              if (pte == NULL)
                       return NULL;
f01013d7:	b8 00 00 00 00       	mov    $0x0,%eax

             if (pte_store != 0)
                     *pte_store = pte;

             return pa2page(PTE_ADDR(pte[0]));
}
f01013dc:	83 c4 14             	add    $0x14,%esp
f01013df:	5b                   	pop    %ebx
f01013e0:	5d                   	pop    %ebp
f01013e1:	c3                   	ret    

f01013e2 <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f01013e2:	55                   	push   %ebp
f01013e3:	89 e5                	mov    %esp,%ebp
f01013e5:	83 ec 08             	sub    $0x8,%esp
	// Flush the entry only if we're modifying the current address space.
	if (!curenv || curenv->env_pgdir == pgdir)
f01013e8:	e8 a6 51 00 00       	call   f0106593 <cpunum>
f01013ed:	6b c0 74             	imul   $0x74,%eax,%eax
f01013f0:	83 b8 28 80 1c f0 00 	cmpl   $0x0,-0xfe37fd8(%eax)
f01013f7:	74 16                	je     f010140f <tlb_invalidate+0x2d>
f01013f9:	e8 95 51 00 00       	call   f0106593 <cpunum>
f01013fe:	6b c0 74             	imul   $0x74,%eax,%eax
f0101401:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0101407:	8b 55 08             	mov    0x8(%ebp),%edx
f010140a:	39 50 60             	cmp    %edx,0x60(%eax)
f010140d:	75 06                	jne    f0101415 <tlb_invalidate+0x33>
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f010140f:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101412:	0f 01 38             	invlpg (%eax)
		invlpg(va);
}
f0101415:	c9                   	leave  
f0101416:	c3                   	ret    

f0101417 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f0101417:	55                   	push   %ebp
f0101418:	89 e5                	mov    %esp,%ebp
f010141a:	56                   	push   %esi
f010141b:	53                   	push   %ebx
f010141c:	83 ec 20             	sub    $0x20,%esp
f010141f:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0101422:	8b 75 0c             	mov    0xc(%ebp),%esi
	// Fill this function in
	//test output
               //cprintf(">>  page_remove() was called!\n");
    
              pte_t *pte;
              struct Page *page = page_lookup(pgdir, va, &pte);
f0101425:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0101428:	89 44 24 08          	mov    %eax,0x8(%esp)
f010142c:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101430:	89 1c 24             	mov    %ebx,(%esp)
f0101433:	e8 3d ff ff ff       	call   f0101375 <page_lookup>
    
              if (page != NULL)
f0101438:	85 c0                	test   %eax,%eax
f010143a:	74 08                	je     f0101444 <page_remove+0x2d>
                         page_decref(page);
f010143c:	89 04 24             	mov    %eax,(%esp)
f010143f:	e8 7c fd ff ff       	call   f01011c0 <page_decref>
        
              pte[0] = 0;
f0101444:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101447:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
              tlb_invalidate(pgdir, va);
f010144d:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101451:	89 1c 24             	mov    %ebx,(%esp)
f0101454:	e8 89 ff ff ff       	call   f01013e2 <tlb_invalidate>
}
f0101459:	83 c4 20             	add    $0x20,%esp
f010145c:	5b                   	pop    %ebx
f010145d:	5e                   	pop    %esi
f010145e:	5d                   	pop    %ebp
f010145f:	c3                   	ret    

f0101460 <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
{
f0101460:	55                   	push   %ebp
f0101461:	89 e5                	mov    %esp,%ebp
f0101463:	57                   	push   %edi
f0101464:	56                   	push   %esi
f0101465:	53                   	push   %ebx
f0101466:	83 ec 1c             	sub    $0x1c,%esp
f0101469:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010146c:	8b 75 10             	mov    0x10(%ebp),%esi
    
               struct Page *page = page_lookup(pgdir, va, NULL);
f010146f:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101476:	00 
f0101477:	89 74 24 04          	mov    %esi,0x4(%esp)
f010147b:	8b 45 08             	mov    0x8(%ebp),%eax
f010147e:	89 04 24             	mov    %eax,(%esp)
f0101481:	e8 ef fe ff ff       	call   f0101375 <page_lookup>
f0101486:	89 c7                	mov    %eax,%edi
               pte_t *pte;
    
              if (page == pp) {                       //re-insert into the same place
f0101488:	39 d8                	cmp    %ebx,%eax
f010148a:	75 36                	jne    f01014c2 <page_insert+0x62>
                            pte = pgdir_walk(pgdir, va, 0);
f010148c:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101493:	00 
f0101494:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101498:	8b 45 08             	mov    0x8(%ebp),%eax
f010149b:	89 04 24             	mov    %eax,(%esp)
f010149e:	e8 40 fd ff ff       	call   f01011e3 <pgdir_walk>
                            pte[0] = page2pa(pp) | perm | PTE_P;
f01014a3:	8b 4d 14             	mov    0x14(%ebp),%ecx
f01014a6:	83 c9 01             	or     $0x1,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01014a9:	2b 3d 90 7e 1c f0    	sub    0xf01c7e90,%edi
f01014af:	c1 ff 03             	sar    $0x3,%edi
f01014b2:	c1 e7 0c             	shl    $0xc,%edi
f01014b5:	89 fa                	mov    %edi,%edx
f01014b7:	09 ca                	or     %ecx,%edx
f01014b9:	89 10                	mov    %edx,(%eax)
                            return 0;
f01014bb:	b8 00 00 00 00       	mov    $0x0,%eax
f01014c0:	eb 57                	jmp    f0101519 <page_insert+0xb9>
                          }
    
               if (page != NULL)                       //remove original page if existed
f01014c2:	85 c0                	test   %eax,%eax
f01014c4:	74 0f                	je     f01014d5 <page_insert+0x75>
                        page_remove(pgdir, va);
f01014c6:	89 74 24 04          	mov    %esi,0x4(%esp)
f01014ca:	8b 45 08             	mov    0x8(%ebp),%eax
f01014cd:	89 04 24             	mov    %eax,(%esp)
f01014d0:	e8 42 ff ff ff       	call   f0101417 <page_remove>
        
              pte = pgdir_walk(pgdir, va, 1);
f01014d5:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01014dc:	00 
f01014dd:	89 74 24 04          	mov    %esi,0x4(%esp)
f01014e1:	8b 45 08             	mov    0x8(%ebp),%eax
f01014e4:	89 04 24             	mov    %eax,(%esp)
f01014e7:	e8 f7 fc ff ff       	call   f01011e3 <pgdir_walk>
              if (pte == NULL)
f01014ec:	85 c0                	test   %eax,%eax
f01014ee:	74 24                	je     f0101514 <page_insert+0xb4>
                       return -E_NO_MEM;

              pte[0] = page2pa(pp) | perm | PTE_P;
f01014f0:	8b 4d 14             	mov    0x14(%ebp),%ecx
f01014f3:	83 c9 01             	or     $0x1,%ecx
f01014f6:	89 da                	mov    %ebx,%edx
f01014f8:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f01014fe:	c1 fa 03             	sar    $0x3,%edx
f0101501:	c1 e2 0c             	shl    $0xc,%edx
f0101504:	09 ca                	or     %ecx,%edx
f0101506:	89 10                	mov    %edx,(%eax)
               pp->pp_ref++;
f0101508:	66 83 43 04 01       	addw   $0x1,0x4(%ebx)

	return 0; 
f010150d:	b8 00 00 00 00       	mov    $0x0,%eax
f0101512:	eb 05                	jmp    f0101519 <page_insert+0xb9>
               if (page != NULL)                       //remove original page if existed
                        page_remove(pgdir, va);
        
              pte = pgdir_walk(pgdir, va, 1);
              if (pte == NULL)
                       return -E_NO_MEM;
f0101514:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax

              pte[0] = page2pa(pp) | perm | PTE_P;
               pp->pp_ref++;

	return 0; 
}
f0101519:	83 c4 1c             	add    $0x1c,%esp
f010151c:	5b                   	pop    %ebx
f010151d:	5e                   	pop    %esi
f010151e:	5f                   	pop    %edi
f010151f:	5d                   	pop    %ebp
f0101520:	c3                   	ret    

f0101521 <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f0101521:	55                   	push   %ebp
f0101522:	89 e5                	mov    %esp,%ebp
f0101524:	57                   	push   %edi
f0101525:	56                   	push   %esi
f0101526:	53                   	push   %ebx
f0101527:	83 ec 4c             	sub    $0x4c,%esp
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f010152a:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f0101531:	e8 e4 27 00 00       	call   f0103d1a <mc146818_read>
f0101536:	89 c3                	mov    %eax,%ebx
f0101538:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f010153f:	e8 d6 27 00 00       	call   f0103d1a <mc146818_read>
f0101544:	c1 e0 08             	shl    $0x8,%eax
f0101547:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f0101549:	89 d8                	mov    %ebx,%eax
f010154b:	c1 e0 0a             	shl    $0xa,%eax
f010154e:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0101554:	85 c0                	test   %eax,%eax
f0101556:	0f 48 c2             	cmovs  %edx,%eax
f0101559:	c1 f8 0c             	sar    $0xc,%eax
f010155c:	a3 44 72 1c f0       	mov    %eax,0xf01c7244
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0101561:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f0101568:	e8 ad 27 00 00       	call   f0103d1a <mc146818_read>
f010156d:	89 c3                	mov    %eax,%ebx
f010156f:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f0101576:	e8 9f 27 00 00       	call   f0103d1a <mc146818_read>
f010157b:	c1 e0 08             	shl    $0x8,%eax
f010157e:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f0101580:	89 d8                	mov    %ebx,%eax
f0101582:	c1 e0 0a             	shl    $0xa,%eax
f0101585:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f010158b:	85 c0                	test   %eax,%eax
f010158d:	0f 48 c2             	cmovs  %edx,%eax
f0101590:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f0101593:	85 c0                	test   %eax,%eax
f0101595:	74 0e                	je     f01015a5 <mem_init+0x84>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f0101597:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f010159d:	89 15 88 7e 1c f0    	mov    %edx,0xf01c7e88
f01015a3:	eb 0c                	jmp    f01015b1 <mem_init+0x90>
	else
		npages = npages_basemem;
f01015a5:	8b 15 44 72 1c f0    	mov    0xf01c7244,%edx
f01015ab:	89 15 88 7e 1c f0    	mov    %edx,0xf01c7e88

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f01015b1:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f01015b4:	c1 e8 0a             	shr    $0xa,%eax
f01015b7:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f01015bb:	a1 44 72 1c f0       	mov    0xf01c7244,%eax
f01015c0:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f01015c3:	c1 e8 0a             	shr    $0xa,%eax
f01015c6:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f01015ca:	a1 88 7e 1c f0       	mov    0xf01c7e88,%eax
f01015cf:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f01015d2:	c1 e8 0a             	shr    $0xa,%eax
f01015d5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01015d9:	c7 04 24 f4 73 10 f0 	movl   $0xf01073f4,(%esp)
f01015e0:	e8 a1 28 00 00       	call   f0103e86 <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);  // first_level pagedir
f01015e5:	b8 00 10 00 00       	mov    $0x1000,%eax
f01015ea:	e8 81 f5 ff ff       	call   f0100b70 <boot_alloc>
f01015ef:	a3 8c 7e 1c f0       	mov    %eax,0xf01c7e8c
	memset(kern_pgdir, 0, PGSIZE);
f01015f4:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01015fb:	00 
f01015fc:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101603:	00 
f0101604:	89 04 24             	mov    %eax,(%esp)
f0101607:	e8 ed 48 00 00       	call   f0105ef9 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f010160c:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101611:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101616:	77 20                	ja     f0101638 <mem_init+0x117>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101618:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010161c:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0101623:	f0 
f0101624:	c7 44 24 04 96 00 00 	movl   $0x96,0x4(%esp)
f010162b:	00 
f010162c:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101633:	e8 08 ea ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0101638:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f010163e:	83 ca 05             	or     $0x5,%edx
f0101641:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct Page in this
	// array.  'npages' is the number of physical pages in memory.
	// Your code goes here:

	pages = (struct Page *)boot_alloc(npages * sizeof(struct Page)); // allocate npages to record all physical pages in memort using condition
f0101647:	a1 88 7e 1c f0       	mov    0xf01c7e88,%eax
f010164c:	c1 e0 03             	shl    $0x3,%eax
f010164f:	e8 1c f5 ff ff       	call   f0100b70 <boot_alloc>
f0101654:	a3 90 7e 1c f0       	mov    %eax,0xf01c7e90


	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.
	envs =  (struct Env *)boot_alloc(NENV * sizeof(struct Env));
f0101659:	b8 00 f0 01 00       	mov    $0x1f000,%eax
f010165e:	e8 0d f5 ff ff       	call   f0100b70 <boot_alloc>
f0101663:	a3 48 72 1c f0       	mov    %eax,0xf01c7248
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f0101668:	e8 a9 f9 ff ff       	call   f0101016 <page_init>

	check_page_free_list(1);
f010166d:	b8 01 00 00 00       	mov    $0x1,%eax
f0101672:	e8 cc f5 ff ff       	call   f0100c43 <check_page_free_list>
	int nfree;
	struct Page *fl;
	char *c;
	int i;

	if (!pages)
f0101677:	83 3d 90 7e 1c f0 00 	cmpl   $0x0,0xf01c7e90
f010167e:	75 1c                	jne    f010169c <mem_init+0x17b>
		panic("'pages' is a null pointer!");
f0101680:	c7 44 24 08 fa 7a 10 	movl   $0xf0107afa,0x8(%esp)
f0101687:	f0 
f0101688:	c7 44 24 04 0d 03 00 	movl   $0x30d,0x4(%esp)
f010168f:	00 
f0101690:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101697:	e8 a4 e9 ff ff       	call   f0100040 <_panic>

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010169c:	a1 40 72 1c f0       	mov    0xf01c7240,%eax
f01016a1:	85 c0                	test   %eax,%eax
f01016a3:	74 10                	je     f01016b5 <mem_init+0x194>
f01016a5:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;
f01016aa:	83 c3 01             	add    $0x1,%ebx

	if (!pages)
		panic("'pages' is a null pointer!");

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f01016ad:	8b 00                	mov    (%eax),%eax
f01016af:	85 c0                	test   %eax,%eax
f01016b1:	75 f7                	jne    f01016aa <mem_init+0x189>
f01016b3:	eb 05                	jmp    f01016ba <mem_init+0x199>
f01016b5:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f01016ba:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01016c1:	e8 60 fa ff ff       	call   f0101126 <page_alloc>
f01016c6:	89 c7                	mov    %eax,%edi
f01016c8:	85 c0                	test   %eax,%eax
f01016ca:	75 24                	jne    f01016f0 <mem_init+0x1cf>
f01016cc:	c7 44 24 0c 15 7b 10 	movl   $0xf0107b15,0xc(%esp)
f01016d3:	f0 
f01016d4:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01016db:	f0 
f01016dc:	c7 44 24 04 15 03 00 	movl   $0x315,0x4(%esp)
f01016e3:	00 
f01016e4:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01016eb:	e8 50 e9 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f01016f0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01016f7:	e8 2a fa ff ff       	call   f0101126 <page_alloc>
f01016fc:	89 c6                	mov    %eax,%esi
f01016fe:	85 c0                	test   %eax,%eax
f0101700:	75 24                	jne    f0101726 <mem_init+0x205>
f0101702:	c7 44 24 0c 2b 7b 10 	movl   $0xf0107b2b,0xc(%esp)
f0101709:	f0 
f010170a:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101711:	f0 
f0101712:	c7 44 24 04 16 03 00 	movl   $0x316,0x4(%esp)
f0101719:	00 
f010171a:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101721:	e8 1a e9 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0101726:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010172d:	e8 f4 f9 ff ff       	call   f0101126 <page_alloc>
f0101732:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101735:	85 c0                	test   %eax,%eax
f0101737:	75 24                	jne    f010175d <mem_init+0x23c>
f0101739:	c7 44 24 0c 41 7b 10 	movl   $0xf0107b41,0xc(%esp)
f0101740:	f0 
f0101741:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101748:	f0 
f0101749:	c7 44 24 04 17 03 00 	movl   $0x317,0x4(%esp)
f0101750:	00 
f0101751:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101758:	e8 e3 e8 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f010175d:	39 f7                	cmp    %esi,%edi
f010175f:	75 24                	jne    f0101785 <mem_init+0x264>
f0101761:	c7 44 24 0c 57 7b 10 	movl   $0xf0107b57,0xc(%esp)
f0101768:	f0 
f0101769:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101770:	f0 
f0101771:	c7 44 24 04 1a 03 00 	movl   $0x31a,0x4(%esp)
f0101778:	00 
f0101779:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101780:	e8 bb e8 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101785:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101788:	39 c6                	cmp    %eax,%esi
f010178a:	74 04                	je     f0101790 <mem_init+0x26f>
f010178c:	39 c7                	cmp    %eax,%edi
f010178e:	75 24                	jne    f01017b4 <mem_init+0x293>
f0101790:	c7 44 24 0c 30 74 10 	movl   $0xf0107430,0xc(%esp)
f0101797:	f0 
f0101798:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010179f:	f0 
f01017a0:	c7 44 24 04 1b 03 00 	movl   $0x31b,0x4(%esp)
f01017a7:	00 
f01017a8:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01017af:	e8 8c e8 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01017b4:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f01017ba:	a1 88 7e 1c f0       	mov    0xf01c7e88,%eax
f01017bf:	c1 e0 0c             	shl    $0xc,%eax
f01017c2:	89 f9                	mov    %edi,%ecx
f01017c4:	29 d1                	sub    %edx,%ecx
f01017c6:	c1 f9 03             	sar    $0x3,%ecx
f01017c9:	c1 e1 0c             	shl    $0xc,%ecx
f01017cc:	39 c1                	cmp    %eax,%ecx
f01017ce:	72 24                	jb     f01017f4 <mem_init+0x2d3>
f01017d0:	c7 44 24 0c 69 7b 10 	movl   $0xf0107b69,0xc(%esp)
f01017d7:	f0 
f01017d8:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01017df:	f0 
f01017e0:	c7 44 24 04 1c 03 00 	movl   $0x31c,0x4(%esp)
f01017e7:	00 
f01017e8:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01017ef:	e8 4c e8 ff ff       	call   f0100040 <_panic>
f01017f4:	89 f1                	mov    %esi,%ecx
f01017f6:	29 d1                	sub    %edx,%ecx
f01017f8:	c1 f9 03             	sar    $0x3,%ecx
f01017fb:	c1 e1 0c             	shl    $0xc,%ecx
	assert(page2pa(pp1) < npages*PGSIZE);
f01017fe:	39 c8                	cmp    %ecx,%eax
f0101800:	77 24                	ja     f0101826 <mem_init+0x305>
f0101802:	c7 44 24 0c 86 7b 10 	movl   $0xf0107b86,0xc(%esp)
f0101809:	f0 
f010180a:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101811:	f0 
f0101812:	c7 44 24 04 1d 03 00 	movl   $0x31d,0x4(%esp)
f0101819:	00 
f010181a:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101821:	e8 1a e8 ff ff       	call   f0100040 <_panic>
f0101826:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0101829:	29 d1                	sub    %edx,%ecx
f010182b:	89 ca                	mov    %ecx,%edx
f010182d:	c1 fa 03             	sar    $0x3,%edx
f0101830:	c1 e2 0c             	shl    $0xc,%edx
	assert(page2pa(pp2) < npages*PGSIZE);
f0101833:	39 d0                	cmp    %edx,%eax
f0101835:	77 24                	ja     f010185b <mem_init+0x33a>
f0101837:	c7 44 24 0c a3 7b 10 	movl   $0xf0107ba3,0xc(%esp)
f010183e:	f0 
f010183f:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101846:	f0 
f0101847:	c7 44 24 04 1e 03 00 	movl   $0x31e,0x4(%esp)
f010184e:	00 
f010184f:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101856:	e8 e5 e7 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f010185b:	a1 40 72 1c f0       	mov    0xf01c7240,%eax
f0101860:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101863:	c7 05 40 72 1c f0 00 	movl   $0x0,0xf01c7240
f010186a:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f010186d:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101874:	e8 ad f8 ff ff       	call   f0101126 <page_alloc>
f0101879:	85 c0                	test   %eax,%eax
f010187b:	74 24                	je     f01018a1 <mem_init+0x380>
f010187d:	c7 44 24 0c c0 7b 10 	movl   $0xf0107bc0,0xc(%esp)
f0101884:	f0 
f0101885:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010188c:	f0 
f010188d:	c7 44 24 04 25 03 00 	movl   $0x325,0x4(%esp)
f0101894:	00 
f0101895:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010189c:	e8 9f e7 ff ff       	call   f0100040 <_panic>

	// free and re-allocate?
	page_free(pp0);
f01018a1:	89 3c 24             	mov    %edi,(%esp)
f01018a4:	e8 02 f9 ff ff       	call   f01011ab <page_free>
	page_free(pp1);
f01018a9:	89 34 24             	mov    %esi,(%esp)
f01018ac:	e8 fa f8 ff ff       	call   f01011ab <page_free>
	page_free(pp2);
f01018b1:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01018b4:	89 04 24             	mov    %eax,(%esp)
f01018b7:	e8 ef f8 ff ff       	call   f01011ab <page_free>
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f01018bc:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018c3:	e8 5e f8 ff ff       	call   f0101126 <page_alloc>
f01018c8:	89 c6                	mov    %eax,%esi
f01018ca:	85 c0                	test   %eax,%eax
f01018cc:	75 24                	jne    f01018f2 <mem_init+0x3d1>
f01018ce:	c7 44 24 0c 15 7b 10 	movl   $0xf0107b15,0xc(%esp)
f01018d5:	f0 
f01018d6:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01018dd:	f0 
f01018de:	c7 44 24 04 2c 03 00 	movl   $0x32c,0x4(%esp)
f01018e5:	00 
f01018e6:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01018ed:	e8 4e e7 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f01018f2:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018f9:	e8 28 f8 ff ff       	call   f0101126 <page_alloc>
f01018fe:	89 c7                	mov    %eax,%edi
f0101900:	85 c0                	test   %eax,%eax
f0101902:	75 24                	jne    f0101928 <mem_init+0x407>
f0101904:	c7 44 24 0c 2b 7b 10 	movl   $0xf0107b2b,0xc(%esp)
f010190b:	f0 
f010190c:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101913:	f0 
f0101914:	c7 44 24 04 2d 03 00 	movl   $0x32d,0x4(%esp)
f010191b:	00 
f010191c:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101923:	e8 18 e7 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0101928:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010192f:	e8 f2 f7 ff ff       	call   f0101126 <page_alloc>
f0101934:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101937:	85 c0                	test   %eax,%eax
f0101939:	75 24                	jne    f010195f <mem_init+0x43e>
f010193b:	c7 44 24 0c 41 7b 10 	movl   $0xf0107b41,0xc(%esp)
f0101942:	f0 
f0101943:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010194a:	f0 
f010194b:	c7 44 24 04 2e 03 00 	movl   $0x32e,0x4(%esp)
f0101952:	00 
f0101953:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010195a:	e8 e1 e6 ff ff       	call   f0100040 <_panic>
	assert(pp0);
	assert(pp1 && pp1 != pp0);
f010195f:	39 fe                	cmp    %edi,%esi
f0101961:	75 24                	jne    f0101987 <mem_init+0x466>
f0101963:	c7 44 24 0c 57 7b 10 	movl   $0xf0107b57,0xc(%esp)
f010196a:	f0 
f010196b:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101972:	f0 
f0101973:	c7 44 24 04 30 03 00 	movl   $0x330,0x4(%esp)
f010197a:	00 
f010197b:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101982:	e8 b9 e6 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101987:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010198a:	39 c7                	cmp    %eax,%edi
f010198c:	74 04                	je     f0101992 <mem_init+0x471>
f010198e:	39 c6                	cmp    %eax,%esi
f0101990:	75 24                	jne    f01019b6 <mem_init+0x495>
f0101992:	c7 44 24 0c 30 74 10 	movl   $0xf0107430,0xc(%esp)
f0101999:	f0 
f010199a:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01019a1:	f0 
f01019a2:	c7 44 24 04 31 03 00 	movl   $0x331,0x4(%esp)
f01019a9:	00 
f01019aa:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01019b1:	e8 8a e6 ff ff       	call   f0100040 <_panic>
	assert(!page_alloc(0));
f01019b6:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01019bd:	e8 64 f7 ff ff       	call   f0101126 <page_alloc>
f01019c2:	85 c0                	test   %eax,%eax
f01019c4:	74 24                	je     f01019ea <mem_init+0x4c9>
f01019c6:	c7 44 24 0c c0 7b 10 	movl   $0xf0107bc0,0xc(%esp)
f01019cd:	f0 
f01019ce:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01019d5:	f0 
f01019d6:	c7 44 24 04 32 03 00 	movl   $0x332,0x4(%esp)
f01019dd:	00 
f01019de:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01019e5:	e8 56 e6 ff ff       	call   f0100040 <_panic>
f01019ea:	89 f0                	mov    %esi,%eax
f01019ec:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f01019f2:	c1 f8 03             	sar    $0x3,%eax
f01019f5:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01019f8:	89 c2                	mov    %eax,%edx
f01019fa:	c1 ea 0c             	shr    $0xc,%edx
f01019fd:	3b 15 88 7e 1c f0    	cmp    0xf01c7e88,%edx
f0101a03:	72 20                	jb     f0101a25 <mem_init+0x504>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101a05:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101a09:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0101a10:	f0 
f0101a11:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101a18:	00 
f0101a19:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f0101a20:	e8 1b e6 ff ff       	call   f0100040 <_panic>

	// test flags
	memset(page2kva(pp0), 1, PGSIZE);
f0101a25:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101a2c:	00 
f0101a2d:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f0101a34:	00 
	return (void *)(pa + KERNBASE);
f0101a35:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101a3a:	89 04 24             	mov    %eax,(%esp)
f0101a3d:	e8 b7 44 00 00       	call   f0105ef9 <memset>
	page_free(pp0);
f0101a42:	89 34 24             	mov    %esi,(%esp)
f0101a45:	e8 61 f7 ff ff       	call   f01011ab <page_free>
	assert((pp = page_alloc(ALLOC_ZERO)));
f0101a4a:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101a51:	e8 d0 f6 ff ff       	call   f0101126 <page_alloc>
f0101a56:	85 c0                	test   %eax,%eax
f0101a58:	75 24                	jne    f0101a7e <mem_init+0x55d>
f0101a5a:	c7 44 24 0c cf 7b 10 	movl   $0xf0107bcf,0xc(%esp)
f0101a61:	f0 
f0101a62:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101a69:	f0 
f0101a6a:	c7 44 24 04 37 03 00 	movl   $0x337,0x4(%esp)
f0101a71:	00 
f0101a72:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101a79:	e8 c2 e5 ff ff       	call   f0100040 <_panic>
	assert(pp && pp0 == pp);
f0101a7e:	39 c6                	cmp    %eax,%esi
f0101a80:	74 24                	je     f0101aa6 <mem_init+0x585>
f0101a82:	c7 44 24 0c ed 7b 10 	movl   $0xf0107bed,0xc(%esp)
f0101a89:	f0 
f0101a8a:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101a91:	f0 
f0101a92:	c7 44 24 04 38 03 00 	movl   $0x338,0x4(%esp)
f0101a99:	00 
f0101a9a:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101aa1:	e8 9a e5 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101aa6:	89 f2                	mov    %esi,%edx
f0101aa8:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f0101aae:	c1 fa 03             	sar    $0x3,%edx
f0101ab1:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101ab4:	89 d0                	mov    %edx,%eax
f0101ab6:	c1 e8 0c             	shr    $0xc,%eax
f0101ab9:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f0101abf:	72 20                	jb     f0101ae1 <mem_init+0x5c0>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101ac1:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101ac5:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0101acc:	f0 
f0101acd:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101ad4:	00 
f0101ad5:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f0101adc:	e8 5f e5 ff ff       	call   f0100040 <_panic>
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
		assert(c[i] == 0);
f0101ae1:	80 ba 00 00 00 f0 00 	cmpb   $0x0,-0x10000000(%edx)
f0101ae8:	75 11                	jne    f0101afb <mem_init+0x5da>
f0101aea:	8d 82 01 00 00 f0    	lea    -0xfffffff(%edx),%eax
f0101af0:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0101af6:	80 38 00             	cmpb   $0x0,(%eax)
f0101af9:	74 24                	je     f0101b1f <mem_init+0x5fe>
f0101afb:	c7 44 24 0c fd 7b 10 	movl   $0xf0107bfd,0xc(%esp)
f0101b02:	f0 
f0101b03:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101b0a:	f0 
f0101b0b:	c7 44 24 04 3b 03 00 	movl   $0x33b,0x4(%esp)
f0101b12:	00 
f0101b13:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101b1a:	e8 21 e5 ff ff       	call   f0100040 <_panic>
f0101b1f:	83 c0 01             	add    $0x1,%eax
	memset(page2kva(pp0), 1, PGSIZE);
	page_free(pp0);
	assert((pp = page_alloc(ALLOC_ZERO)));
	assert(pp && pp0 == pp);
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
f0101b22:	39 d0                	cmp    %edx,%eax
f0101b24:	75 d0                	jne    f0101af6 <mem_init+0x5d5>
		assert(c[i] == 0);

	// give free list back
	page_free_list = fl;
f0101b26:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101b29:	a3 40 72 1c f0       	mov    %eax,0xf01c7240

	// free the pages we took
	page_free(pp0);
f0101b2e:	89 34 24             	mov    %esi,(%esp)
f0101b31:	e8 75 f6 ff ff       	call   f01011ab <page_free>
	page_free(pp1);
f0101b36:	89 3c 24             	mov    %edi,(%esp)
f0101b39:	e8 6d f6 ff ff       	call   f01011ab <page_free>
	page_free(pp2);
f0101b3e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101b41:	89 04 24             	mov    %eax,(%esp)
f0101b44:	e8 62 f6 ff ff       	call   f01011ab <page_free>

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101b49:	a1 40 72 1c f0       	mov    0xf01c7240,%eax
f0101b4e:	85 c0                	test   %eax,%eax
f0101b50:	74 09                	je     f0101b5b <mem_init+0x63a>
		--nfree;
f0101b52:	83 eb 01             	sub    $0x1,%ebx
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101b55:	8b 00                	mov    (%eax),%eax
f0101b57:	85 c0                	test   %eax,%eax
f0101b59:	75 f7                	jne    f0101b52 <mem_init+0x631>
		--nfree;
	assert(nfree == 0);
f0101b5b:	85 db                	test   %ebx,%ebx
f0101b5d:	74 24                	je     f0101b83 <mem_init+0x662>
f0101b5f:	c7 44 24 0c 07 7c 10 	movl   $0xf0107c07,0xc(%esp)
f0101b66:	f0 
f0101b67:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101b6e:	f0 
f0101b6f:	c7 44 24 04 48 03 00 	movl   $0x348,0x4(%esp)
f0101b76:	00 
f0101b77:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101b7e:	e8 bd e4 ff ff       	call   f0100040 <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f0101b83:	c7 04 24 50 74 10 f0 	movl   $0xf0107450,(%esp)
f0101b8a:	e8 f7 22 00 00       	call   f0103e86 <cprintf>
	int i;
	extern pde_t entry_pgdir[];

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101b8f:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b96:	e8 8b f5 ff ff       	call   f0101126 <page_alloc>
f0101b9b:	89 c3                	mov    %eax,%ebx
f0101b9d:	85 c0                	test   %eax,%eax
f0101b9f:	75 24                	jne    f0101bc5 <mem_init+0x6a4>
f0101ba1:	c7 44 24 0c 15 7b 10 	movl   $0xf0107b15,0xc(%esp)
f0101ba8:	f0 
f0101ba9:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101bb0:	f0 
f0101bb1:	c7 44 24 04 b0 03 00 	movl   $0x3b0,0x4(%esp)
f0101bb8:	00 
f0101bb9:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101bc0:	e8 7b e4 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101bc5:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101bcc:	e8 55 f5 ff ff       	call   f0101126 <page_alloc>
f0101bd1:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101bd4:	85 c0                	test   %eax,%eax
f0101bd6:	75 24                	jne    f0101bfc <mem_init+0x6db>
f0101bd8:	c7 44 24 0c 2b 7b 10 	movl   $0xf0107b2b,0xc(%esp)
f0101bdf:	f0 
f0101be0:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101be7:	f0 
f0101be8:	c7 44 24 04 b1 03 00 	movl   $0x3b1,0x4(%esp)
f0101bef:	00 
f0101bf0:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101bf7:	e8 44 e4 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0101bfc:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101c03:	e8 1e f5 ff ff       	call   f0101126 <page_alloc>
f0101c08:	89 c7                	mov    %eax,%edi
f0101c0a:	85 c0                	test   %eax,%eax
f0101c0c:	75 24                	jne    f0101c32 <mem_init+0x711>
f0101c0e:	c7 44 24 0c 41 7b 10 	movl   $0xf0107b41,0xc(%esp)
f0101c15:	f0 
f0101c16:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101c1d:	f0 
f0101c1e:	c7 44 24 04 b2 03 00 	movl   $0x3b2,0x4(%esp)
f0101c25:	00 
f0101c26:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101c2d:	e8 0e e4 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101c32:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0101c35:	75 24                	jne    f0101c5b <mem_init+0x73a>
f0101c37:	c7 44 24 0c 57 7b 10 	movl   $0xf0107b57,0xc(%esp)
f0101c3e:	f0 
f0101c3f:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101c46:	f0 
f0101c47:	c7 44 24 04 b5 03 00 	movl   $0x3b5,0x4(%esp)
f0101c4e:	00 
f0101c4f:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101c56:	e8 e5 e3 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101c5b:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f0101c5e:	74 04                	je     f0101c64 <mem_init+0x743>
f0101c60:	39 c3                	cmp    %eax,%ebx
f0101c62:	75 24                	jne    f0101c88 <mem_init+0x767>
f0101c64:	c7 44 24 0c 30 74 10 	movl   $0xf0107430,0xc(%esp)
f0101c6b:	f0 
f0101c6c:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101c73:	f0 
f0101c74:	c7 44 24 04 b6 03 00 	movl   $0x3b6,0x4(%esp)
f0101c7b:	00 
f0101c7c:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101c83:	e8 b8 e3 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101c88:	a1 40 72 1c f0       	mov    0xf01c7240,%eax
f0101c8d:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101c90:	c7 05 40 72 1c f0 00 	movl   $0x0,0xf01c7240
f0101c97:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f0101c9a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101ca1:	e8 80 f4 ff ff       	call   f0101126 <page_alloc>
f0101ca6:	85 c0                	test   %eax,%eax
f0101ca8:	74 24                	je     f0101cce <mem_init+0x7ad>
f0101caa:	c7 44 24 0c c0 7b 10 	movl   $0xf0107bc0,0xc(%esp)
f0101cb1:	f0 
f0101cb2:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101cb9:	f0 
f0101cba:	c7 44 24 04 bd 03 00 	movl   $0x3bd,0x4(%esp)
f0101cc1:	00 
f0101cc2:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101cc9:	e8 72 e3 ff ff       	call   f0100040 <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f0101cce:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101cd1:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101cd5:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101cdc:	00 
f0101cdd:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0101ce2:	89 04 24             	mov    %eax,(%esp)
f0101ce5:	e8 8b f6 ff ff       	call   f0101375 <page_lookup>
f0101cea:	85 c0                	test   %eax,%eax
f0101cec:	74 24                	je     f0101d12 <mem_init+0x7f1>
f0101cee:	c7 44 24 0c 70 74 10 	movl   $0xf0107470,0xc(%esp)
f0101cf5:	f0 
f0101cf6:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101cfd:	f0 
f0101cfe:	c7 44 24 04 c0 03 00 	movl   $0x3c0,0x4(%esp)
f0101d05:	00 
f0101d06:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101d0d:	e8 2e e3 ff ff       	call   f0100040 <_panic>

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);
f0101d12:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101d19:	00 
f0101d1a:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101d21:	00 
f0101d22:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101d25:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101d29:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0101d2e:	89 04 24             	mov    %eax,(%esp)
f0101d31:	e8 2a f7 ff ff       	call   f0101460 <page_insert>
f0101d36:	85 c0                	test   %eax,%eax
f0101d38:	78 24                	js     f0101d5e <mem_init+0x83d>
f0101d3a:	c7 44 24 0c a8 74 10 	movl   $0xf01074a8,0xc(%esp)
f0101d41:	f0 
f0101d42:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101d49:	f0 
f0101d4a:	c7 44 24 04 c3 03 00 	movl   $0x3c3,0x4(%esp)
f0101d51:	00 
f0101d52:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101d59:	e8 e2 e2 ff ff       	call   f0100040 <_panic>

	// free pp0 and try again: pp0 should be used for page table
	page_free(pp0);
f0101d5e:	89 1c 24             	mov    %ebx,(%esp)
f0101d61:	e8 45 f4 ff ff       	call   f01011ab <page_free>
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) == 0);
f0101d66:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101d6d:	00 
f0101d6e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101d75:	00 
f0101d76:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101d79:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101d7d:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0101d82:	89 04 24             	mov    %eax,(%esp)
f0101d85:	e8 d6 f6 ff ff       	call   f0101460 <page_insert>
f0101d8a:	85 c0                	test   %eax,%eax
f0101d8c:	74 24                	je     f0101db2 <mem_init+0x891>
f0101d8e:	c7 44 24 0c d8 74 10 	movl   $0xf01074d8,0xc(%esp)
f0101d95:	f0 
f0101d96:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101d9d:	f0 
f0101d9e:	c7 44 24 04 c7 03 00 	movl   $0x3c7,0x4(%esp)
f0101da5:	00 
f0101da6:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101dad:	e8 8e e2 ff ff       	call   f0100040 <_panic>
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101db2:	8b 35 8c 7e 1c f0    	mov    0xf01c7e8c,%esi
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101db8:	a1 90 7e 1c f0       	mov    0xf01c7e90,%eax
f0101dbd:	89 45 cc             	mov    %eax,-0x34(%ebp)
f0101dc0:	8b 16                	mov    (%esi),%edx
f0101dc2:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0101dc8:	89 d9                	mov    %ebx,%ecx
f0101dca:	29 c1                	sub    %eax,%ecx
f0101dcc:	89 c8                	mov    %ecx,%eax
f0101dce:	c1 f8 03             	sar    $0x3,%eax
f0101dd1:	c1 e0 0c             	shl    $0xc,%eax
f0101dd4:	39 c2                	cmp    %eax,%edx
f0101dd6:	74 24                	je     f0101dfc <mem_init+0x8db>
f0101dd8:	c7 44 24 0c 08 75 10 	movl   $0xf0107508,0xc(%esp)
f0101ddf:	f0 
f0101de0:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101de7:	f0 
f0101de8:	c7 44 24 04 c8 03 00 	movl   $0x3c8,0x4(%esp)
f0101def:	00 
f0101df0:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101df7:	e8 44 e2 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, 0x0) == page2pa(pp1));
f0101dfc:	ba 00 00 00 00       	mov    $0x0,%edx
f0101e01:	89 f0                	mov    %esi,%eax
f0101e03:	e8 cc ed ff ff       	call   f0100bd4 <check_va2pa>
f0101e08:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101e0b:	2b 55 cc             	sub    -0x34(%ebp),%edx
f0101e0e:	c1 fa 03             	sar    $0x3,%edx
f0101e11:	c1 e2 0c             	shl    $0xc,%edx
f0101e14:	39 d0                	cmp    %edx,%eax
f0101e16:	74 24                	je     f0101e3c <mem_init+0x91b>
f0101e18:	c7 44 24 0c 30 75 10 	movl   $0xf0107530,0xc(%esp)
f0101e1f:	f0 
f0101e20:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101e27:	f0 
f0101e28:	c7 44 24 04 c9 03 00 	movl   $0x3c9,0x4(%esp)
f0101e2f:	00 
f0101e30:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101e37:	e8 04 e2 ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0101e3c:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101e3f:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101e44:	74 24                	je     f0101e6a <mem_init+0x949>
f0101e46:	c7 44 24 0c 12 7c 10 	movl   $0xf0107c12,0xc(%esp)
f0101e4d:	f0 
f0101e4e:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101e55:	f0 
f0101e56:	c7 44 24 04 ca 03 00 	movl   $0x3ca,0x4(%esp)
f0101e5d:	00 
f0101e5e:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101e65:	e8 d6 e1 ff ff       	call   f0100040 <_panic>
	assert(pp0->pp_ref == 1);
f0101e6a:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0101e6f:	74 24                	je     f0101e95 <mem_init+0x974>
f0101e71:	c7 44 24 0c 23 7c 10 	movl   $0xf0107c23,0xc(%esp)
f0101e78:	f0 
f0101e79:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101e80:	f0 
f0101e81:	c7 44 24 04 cb 03 00 	movl   $0x3cb,0x4(%esp)
f0101e88:	00 
f0101e89:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101e90:	e8 ab e1 ff ff       	call   f0100040 <_panic>

	// should be able to map pp2 at PGSIZE because pp0 is already allocated for page table
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101e95:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101e9c:	00 
f0101e9d:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101ea4:	00 
f0101ea5:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101ea9:	89 34 24             	mov    %esi,(%esp)
f0101eac:	e8 af f5 ff ff       	call   f0101460 <page_insert>
f0101eb1:	85 c0                	test   %eax,%eax
f0101eb3:	74 24                	je     f0101ed9 <mem_init+0x9b8>
f0101eb5:	c7 44 24 0c 60 75 10 	movl   $0xf0107560,0xc(%esp)
f0101ebc:	f0 
f0101ebd:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101ec4:	f0 
f0101ec5:	c7 44 24 04 ce 03 00 	movl   $0x3ce,0x4(%esp)
f0101ecc:	00 
f0101ecd:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101ed4:	e8 67 e1 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101ed9:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101ede:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0101ee3:	e8 ec ec ff ff       	call   f0100bd4 <check_va2pa>
f0101ee8:	89 fa                	mov    %edi,%edx
f0101eea:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f0101ef0:	c1 fa 03             	sar    $0x3,%edx
f0101ef3:	c1 e2 0c             	shl    $0xc,%edx
f0101ef6:	39 d0                	cmp    %edx,%eax
f0101ef8:	74 24                	je     f0101f1e <mem_init+0x9fd>
f0101efa:	c7 44 24 0c 9c 75 10 	movl   $0xf010759c,0xc(%esp)
f0101f01:	f0 
f0101f02:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101f09:	f0 
f0101f0a:	c7 44 24 04 cf 03 00 	movl   $0x3cf,0x4(%esp)
f0101f11:	00 
f0101f12:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101f19:	e8 22 e1 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101f1e:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0101f23:	74 24                	je     f0101f49 <mem_init+0xa28>
f0101f25:	c7 44 24 0c 34 7c 10 	movl   $0xf0107c34,0xc(%esp)
f0101f2c:	f0 
f0101f2d:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101f34:	f0 
f0101f35:	c7 44 24 04 d0 03 00 	movl   $0x3d0,0x4(%esp)
f0101f3c:	00 
f0101f3d:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101f44:	e8 f7 e0 ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0101f49:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101f50:	e8 d1 f1 ff ff       	call   f0101126 <page_alloc>
f0101f55:	85 c0                	test   %eax,%eax
f0101f57:	74 24                	je     f0101f7d <mem_init+0xa5c>
f0101f59:	c7 44 24 0c c0 7b 10 	movl   $0xf0107bc0,0xc(%esp)
f0101f60:	f0 
f0101f61:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101f68:	f0 
f0101f69:	c7 44 24 04 d3 03 00 	movl   $0x3d3,0x4(%esp)
f0101f70:	00 
f0101f71:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101f78:	e8 c3 e0 ff ff       	call   f0100040 <_panic>

	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101f7d:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101f84:	00 
f0101f85:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101f8c:	00 
f0101f8d:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101f91:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0101f96:	89 04 24             	mov    %eax,(%esp)
f0101f99:	e8 c2 f4 ff ff       	call   f0101460 <page_insert>
f0101f9e:	85 c0                	test   %eax,%eax
f0101fa0:	74 24                	je     f0101fc6 <mem_init+0xaa5>
f0101fa2:	c7 44 24 0c 60 75 10 	movl   $0xf0107560,0xc(%esp)
f0101fa9:	f0 
f0101faa:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101fb1:	f0 
f0101fb2:	c7 44 24 04 d6 03 00 	movl   $0x3d6,0x4(%esp)
f0101fb9:	00 
f0101fba:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0101fc1:	e8 7a e0 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101fc6:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101fcb:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0101fd0:	e8 ff eb ff ff       	call   f0100bd4 <check_va2pa>
f0101fd5:	89 fa                	mov    %edi,%edx
f0101fd7:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f0101fdd:	c1 fa 03             	sar    $0x3,%edx
f0101fe0:	c1 e2 0c             	shl    $0xc,%edx
f0101fe3:	39 d0                	cmp    %edx,%eax
f0101fe5:	74 24                	je     f010200b <mem_init+0xaea>
f0101fe7:	c7 44 24 0c 9c 75 10 	movl   $0xf010759c,0xc(%esp)
f0101fee:	f0 
f0101fef:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0101ff6:	f0 
f0101ff7:	c7 44 24 04 d7 03 00 	movl   $0x3d7,0x4(%esp)
f0101ffe:	00 
f0101fff:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102006:	e8 35 e0 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f010200b:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0102010:	74 24                	je     f0102036 <mem_init+0xb15>
f0102012:	c7 44 24 0c 34 7c 10 	movl   $0xf0107c34,0xc(%esp)
f0102019:	f0 
f010201a:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102021:	f0 
f0102022:	c7 44 24 04 d8 03 00 	movl   $0x3d8,0x4(%esp)
f0102029:	00 
f010202a:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102031:	e8 0a e0 ff ff       	call   f0100040 <_panic>

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));
f0102036:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010203d:	e8 e4 f0 ff ff       	call   f0101126 <page_alloc>
f0102042:	85 c0                	test   %eax,%eax
f0102044:	74 24                	je     f010206a <mem_init+0xb49>
f0102046:	c7 44 24 0c c0 7b 10 	movl   $0xf0107bc0,0xc(%esp)
f010204d:	f0 
f010204e:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102055:	f0 
f0102056:	c7 44 24 04 dc 03 00 	movl   $0x3dc,0x4(%esp)
f010205d:	00 
f010205e:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102065:	e8 d6 df ff ff       	call   f0100040 <_panic>

	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f010206a:	8b 15 8c 7e 1c f0    	mov    0xf01c7e8c,%edx
f0102070:	8b 02                	mov    (%edx),%eax
f0102072:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102077:	89 c1                	mov    %eax,%ecx
f0102079:	c1 e9 0c             	shr    $0xc,%ecx
f010207c:	3b 0d 88 7e 1c f0    	cmp    0xf01c7e88,%ecx
f0102082:	72 20                	jb     f01020a4 <mem_init+0xb83>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102084:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102088:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f010208f:	f0 
f0102090:	c7 44 24 04 df 03 00 	movl   $0x3df,0x4(%esp)
f0102097:	00 
f0102098:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010209f:	e8 9c df ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01020a4:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01020a9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	assert(pgdir_walk(kern_pgdir, (void*)PGSIZE, 0) == ptep+PTX(PGSIZE));
f01020ac:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01020b3:	00 
f01020b4:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01020bb:	00 
f01020bc:	89 14 24             	mov    %edx,(%esp)
f01020bf:	e8 1f f1 ff ff       	call   f01011e3 <pgdir_walk>
f01020c4:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f01020c7:	8d 51 04             	lea    0x4(%ecx),%edx
f01020ca:	39 d0                	cmp    %edx,%eax
f01020cc:	74 24                	je     f01020f2 <mem_init+0xbd1>
f01020ce:	c7 44 24 0c cc 75 10 	movl   $0xf01075cc,0xc(%esp)
f01020d5:	f0 
f01020d6:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01020dd:	f0 
f01020de:	c7 44 24 04 e0 03 00 	movl   $0x3e0,0x4(%esp)
f01020e5:	00 
f01020e6:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01020ed:	e8 4e df ff ff       	call   f0100040 <_panic>

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
f01020f2:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01020f9:	00 
f01020fa:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102101:	00 
f0102102:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102106:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f010210b:	89 04 24             	mov    %eax,(%esp)
f010210e:	e8 4d f3 ff ff       	call   f0101460 <page_insert>
f0102113:	85 c0                	test   %eax,%eax
f0102115:	74 24                	je     f010213b <mem_init+0xc1a>
f0102117:	c7 44 24 0c 0c 76 10 	movl   $0xf010760c,0xc(%esp)
f010211e:	f0 
f010211f:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102126:	f0 
f0102127:	c7 44 24 04 e3 03 00 	movl   $0x3e3,0x4(%esp)
f010212e:	00 
f010212f:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102136:	e8 05 df ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f010213b:	8b 35 8c 7e 1c f0    	mov    0xf01c7e8c,%esi
f0102141:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102146:	89 f0                	mov    %esi,%eax
f0102148:	e8 87 ea ff ff       	call   f0100bd4 <check_va2pa>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010214d:	89 fa                	mov    %edi,%edx
f010214f:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f0102155:	c1 fa 03             	sar    $0x3,%edx
f0102158:	c1 e2 0c             	shl    $0xc,%edx
f010215b:	39 d0                	cmp    %edx,%eax
f010215d:	74 24                	je     f0102183 <mem_init+0xc62>
f010215f:	c7 44 24 0c 9c 75 10 	movl   $0xf010759c,0xc(%esp)
f0102166:	f0 
f0102167:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010216e:	f0 
f010216f:	c7 44 24 04 e4 03 00 	movl   $0x3e4,0x4(%esp)
f0102176:	00 
f0102177:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010217e:	e8 bd de ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0102183:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0102188:	74 24                	je     f01021ae <mem_init+0xc8d>
f010218a:	c7 44 24 0c 34 7c 10 	movl   $0xf0107c34,0xc(%esp)
f0102191:	f0 
f0102192:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102199:	f0 
f010219a:	c7 44 24 04 e5 03 00 	movl   $0x3e5,0x4(%esp)
f01021a1:	00 
f01021a2:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01021a9:	e8 92 de ff ff       	call   f0100040 <_panic>
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U);
f01021ae:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01021b5:	00 
f01021b6:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01021bd:	00 
f01021be:	89 34 24             	mov    %esi,(%esp)
f01021c1:	e8 1d f0 ff ff       	call   f01011e3 <pgdir_walk>
f01021c6:	f6 00 04             	testb  $0x4,(%eax)
f01021c9:	75 24                	jne    f01021ef <mem_init+0xcce>
f01021cb:	c7 44 24 0c 4c 76 10 	movl   $0xf010764c,0xc(%esp)
f01021d2:	f0 
f01021d3:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01021da:	f0 
f01021db:	c7 44 24 04 e6 03 00 	movl   $0x3e6,0x4(%esp)
f01021e2:	00 
f01021e3:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01021ea:	e8 51 de ff ff       	call   f0100040 <_panic>
	assert(kern_pgdir[0] & PTE_U);
f01021ef:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01021f4:	f6 00 04             	testb  $0x4,(%eax)
f01021f7:	75 24                	jne    f010221d <mem_init+0xcfc>
f01021f9:	c7 44 24 0c 45 7c 10 	movl   $0xf0107c45,0xc(%esp)
f0102200:	f0 
f0102201:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102208:	f0 
f0102209:	c7 44 24 04 e7 03 00 	movl   $0x3e7,0x4(%esp)
f0102210:	00 
f0102211:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102218:	e8 23 de ff ff       	call   f0100040 <_panic>

	// should not be able to map at PTSIZE because need free page for page table
	assert(page_insert(kern_pgdir, pp0, (void*) PTSIZE, PTE_W) < 0);
f010221d:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102224:	00 
f0102225:	c7 44 24 08 00 00 40 	movl   $0x400000,0x8(%esp)
f010222c:	00 
f010222d:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0102231:	89 04 24             	mov    %eax,(%esp)
f0102234:	e8 27 f2 ff ff       	call   f0101460 <page_insert>
f0102239:	85 c0                	test   %eax,%eax
f010223b:	78 24                	js     f0102261 <mem_init+0xd40>
f010223d:	c7 44 24 0c 80 76 10 	movl   $0xf0107680,0xc(%esp)
f0102244:	f0 
f0102245:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010224c:	f0 
f010224d:	c7 44 24 04 ea 03 00 	movl   $0x3ea,0x4(%esp)
f0102254:	00 
f0102255:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010225c:	e8 df dd ff ff       	call   f0100040 <_panic>

	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
f0102261:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102268:	00 
f0102269:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102270:	00 
f0102271:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102274:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102278:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f010227d:	89 04 24             	mov    %eax,(%esp)
f0102280:	e8 db f1 ff ff       	call   f0101460 <page_insert>
f0102285:	85 c0                	test   %eax,%eax
f0102287:	74 24                	je     f01022ad <mem_init+0xd8c>
f0102289:	c7 44 24 0c b8 76 10 	movl   $0xf01076b8,0xc(%esp)
f0102290:	f0 
f0102291:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102298:	f0 
f0102299:	c7 44 24 04 ed 03 00 	movl   $0x3ed,0x4(%esp)
f01022a0:	00 
f01022a1:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01022a8:	e8 93 dd ff ff       	call   f0100040 <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f01022ad:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01022b4:	00 
f01022b5:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01022bc:	00 
f01022bd:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01022c2:	89 04 24             	mov    %eax,(%esp)
f01022c5:	e8 19 ef ff ff       	call   f01011e3 <pgdir_walk>
f01022ca:	f6 00 04             	testb  $0x4,(%eax)
f01022cd:	74 24                	je     f01022f3 <mem_init+0xdd2>
f01022cf:	c7 44 24 0c f4 76 10 	movl   $0xf01076f4,0xc(%esp)
f01022d6:	f0 
f01022d7:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01022de:	f0 
f01022df:	c7 44 24 04 ee 03 00 	movl   $0x3ee,0x4(%esp)
f01022e6:	00 
f01022e7:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01022ee:	e8 4d dd ff ff       	call   f0100040 <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f01022f3:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01022f8:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01022fb:	ba 00 00 00 00       	mov    $0x0,%edx
f0102300:	e8 cf e8 ff ff       	call   f0100bd4 <check_va2pa>
f0102305:	89 c6                	mov    %eax,%esi
f0102307:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010230a:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f0102310:	c1 f8 03             	sar    $0x3,%eax
f0102313:	c1 e0 0c             	shl    $0xc,%eax
f0102316:	39 c6                	cmp    %eax,%esi
f0102318:	74 24                	je     f010233e <mem_init+0xe1d>
f010231a:	c7 44 24 0c 2c 77 10 	movl   $0xf010772c,0xc(%esp)
f0102321:	f0 
f0102322:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102329:	f0 
f010232a:	c7 44 24 04 f1 03 00 	movl   $0x3f1,0x4(%esp)
f0102331:	00 
f0102332:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102339:	e8 02 dd ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f010233e:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102343:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0102346:	e8 89 e8 ff ff       	call   f0100bd4 <check_va2pa>
f010234b:	39 c6                	cmp    %eax,%esi
f010234d:	74 24                	je     f0102373 <mem_init+0xe52>
f010234f:	c7 44 24 0c 58 77 10 	movl   $0xf0107758,0xc(%esp)
f0102356:	f0 
f0102357:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010235e:	f0 
f010235f:	c7 44 24 04 f2 03 00 	movl   $0x3f2,0x4(%esp)
f0102366:	00 
f0102367:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010236e:	e8 cd dc ff ff       	call   f0100040 <_panic>
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
f0102373:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102376:	66 83 78 04 02       	cmpw   $0x2,0x4(%eax)
f010237b:	74 24                	je     f01023a1 <mem_init+0xe80>
f010237d:	c7 44 24 0c 5b 7c 10 	movl   $0xf0107c5b,0xc(%esp)
f0102384:	f0 
f0102385:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010238c:	f0 
f010238d:	c7 44 24 04 f4 03 00 	movl   $0x3f4,0x4(%esp)
f0102394:	00 
f0102395:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010239c:	e8 9f dc ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f01023a1:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f01023a6:	74 24                	je     f01023cc <mem_init+0xeab>
f01023a8:	c7 44 24 0c 6c 7c 10 	movl   $0xf0107c6c,0xc(%esp)
f01023af:	f0 
f01023b0:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01023b7:	f0 
f01023b8:	c7 44 24 04 f5 03 00 	movl   $0x3f5,0x4(%esp)
f01023bf:	00 
f01023c0:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01023c7:	e8 74 dc ff ff       	call   f0100040 <_panic>

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);
f01023cc:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01023d3:	e8 4e ed ff ff       	call   f0101126 <page_alloc>
f01023d8:	85 c0                	test   %eax,%eax
f01023da:	74 04                	je     f01023e0 <mem_init+0xebf>
f01023dc:	39 c7                	cmp    %eax,%edi
f01023de:	74 24                	je     f0102404 <mem_init+0xee3>
f01023e0:	c7 44 24 0c 88 77 10 	movl   $0xf0107788,0xc(%esp)
f01023e7:	f0 
f01023e8:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01023ef:	f0 
f01023f0:	c7 44 24 04 f8 03 00 	movl   $0x3f8,0x4(%esp)
f01023f7:	00 
f01023f8:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01023ff:	e8 3c dc ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f0102404:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010240b:	00 
f010240c:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0102411:	89 04 24             	mov    %eax,(%esp)
f0102414:	e8 fe ef ff ff       	call   f0101417 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f0102419:	8b 35 8c 7e 1c f0    	mov    0xf01c7e8c,%esi
f010241f:	ba 00 00 00 00       	mov    $0x0,%edx
f0102424:	89 f0                	mov    %esi,%eax
f0102426:	e8 a9 e7 ff ff       	call   f0100bd4 <check_va2pa>
f010242b:	83 f8 ff             	cmp    $0xffffffff,%eax
f010242e:	74 24                	je     f0102454 <mem_init+0xf33>
f0102430:	c7 44 24 0c ac 77 10 	movl   $0xf01077ac,0xc(%esp)
f0102437:	f0 
f0102438:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010243f:	f0 
f0102440:	c7 44 24 04 fc 03 00 	movl   $0x3fc,0x4(%esp)
f0102447:	00 
f0102448:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010244f:	e8 ec db ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102454:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102459:	89 f0                	mov    %esi,%eax
f010245b:	e8 74 e7 ff ff       	call   f0100bd4 <check_va2pa>
f0102460:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0102463:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f0102469:	c1 fa 03             	sar    $0x3,%edx
f010246c:	c1 e2 0c             	shl    $0xc,%edx
f010246f:	39 d0                	cmp    %edx,%eax
f0102471:	74 24                	je     f0102497 <mem_init+0xf76>
f0102473:	c7 44 24 0c 58 77 10 	movl   $0xf0107758,0xc(%esp)
f010247a:	f0 
f010247b:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102482:	f0 
f0102483:	c7 44 24 04 fd 03 00 	movl   $0x3fd,0x4(%esp)
f010248a:	00 
f010248b:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102492:	e8 a9 db ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0102497:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010249a:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f010249f:	74 24                	je     f01024c5 <mem_init+0xfa4>
f01024a1:	c7 44 24 0c 12 7c 10 	movl   $0xf0107c12,0xc(%esp)
f01024a8:	f0 
f01024a9:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01024b0:	f0 
f01024b1:	c7 44 24 04 fe 03 00 	movl   $0x3fe,0x4(%esp)
f01024b8:	00 
f01024b9:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01024c0:	e8 7b db ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f01024c5:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f01024ca:	74 24                	je     f01024f0 <mem_init+0xfcf>
f01024cc:	c7 44 24 0c 6c 7c 10 	movl   $0xf0107c6c,0xc(%esp)
f01024d3:	f0 
f01024d4:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01024db:	f0 
f01024dc:	c7 44 24 04 ff 03 00 	movl   $0x3ff,0x4(%esp)
f01024e3:	00 
f01024e4:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01024eb:	e8 50 db ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
f01024f0:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01024f7:	00 
f01024f8:	89 34 24             	mov    %esi,(%esp)
f01024fb:	e8 17 ef ff ff       	call   f0101417 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f0102500:	8b 35 8c 7e 1c f0    	mov    0xf01c7e8c,%esi
f0102506:	ba 00 00 00 00       	mov    $0x0,%edx
f010250b:	89 f0                	mov    %esi,%eax
f010250d:	e8 c2 e6 ff ff       	call   f0100bd4 <check_va2pa>
f0102512:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102515:	74 24                	je     f010253b <mem_init+0x101a>
f0102517:	c7 44 24 0c ac 77 10 	movl   $0xf01077ac,0xc(%esp)
f010251e:	f0 
f010251f:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102526:	f0 
f0102527:	c7 44 24 04 03 04 00 	movl   $0x403,0x4(%esp)
f010252e:	00 
f010252f:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102536:	e8 05 db ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
f010253b:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102540:	89 f0                	mov    %esi,%eax
f0102542:	e8 8d e6 ff ff       	call   f0100bd4 <check_va2pa>
f0102547:	83 f8 ff             	cmp    $0xffffffff,%eax
f010254a:	74 24                	je     f0102570 <mem_init+0x104f>
f010254c:	c7 44 24 0c d0 77 10 	movl   $0xf01077d0,0xc(%esp)
f0102553:	f0 
f0102554:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010255b:	f0 
f010255c:	c7 44 24 04 04 04 00 	movl   $0x404,0x4(%esp)
f0102563:	00 
f0102564:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010256b:	e8 d0 da ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f0102570:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102573:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102578:	74 24                	je     f010259e <mem_init+0x107d>
f010257a:	c7 44 24 0c 7d 7c 10 	movl   $0xf0107c7d,0xc(%esp)
f0102581:	f0 
f0102582:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102589:	f0 
f010258a:	c7 44 24 04 05 04 00 	movl   $0x405,0x4(%esp)
f0102591:	00 
f0102592:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102599:	e8 a2 da ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f010259e:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f01025a3:	74 24                	je     f01025c9 <mem_init+0x10a8>
f01025a5:	c7 44 24 0c 6c 7c 10 	movl   $0xf0107c6c,0xc(%esp)
f01025ac:	f0 
f01025ad:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01025b4:	f0 
f01025b5:	c7 44 24 04 06 04 00 	movl   $0x406,0x4(%esp)
f01025bc:	00 
f01025bd:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01025c4:	e8 77 da ff ff       	call   f0100040 <_panic>

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);
f01025c9:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01025d0:	e8 51 eb ff ff       	call   f0101126 <page_alloc>
f01025d5:	85 c0                	test   %eax,%eax
f01025d7:	74 05                	je     f01025de <mem_init+0x10bd>
f01025d9:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f01025dc:	74 24                	je     f0102602 <mem_init+0x10e1>
f01025de:	c7 44 24 0c f8 77 10 	movl   $0xf01077f8,0xc(%esp)
f01025e5:	f0 
f01025e6:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01025ed:	f0 
f01025ee:	c7 44 24 04 09 04 00 	movl   $0x409,0x4(%esp)
f01025f5:	00 
f01025f6:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01025fd:	e8 3e da ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0102602:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102609:	e8 18 eb ff ff       	call   f0101126 <page_alloc>
f010260e:	85 c0                	test   %eax,%eax
f0102610:	74 24                	je     f0102636 <mem_init+0x1115>
f0102612:	c7 44 24 0c c0 7b 10 	movl   $0xf0107bc0,0xc(%esp)
f0102619:	f0 
f010261a:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102621:	f0 
f0102622:	c7 44 24 04 0c 04 00 	movl   $0x40c,0x4(%esp)
f0102629:	00 
f010262a:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102631:	e8 0a da ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102636:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f010263b:	8b 08                	mov    (%eax),%ecx
f010263d:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f0102643:	89 da                	mov    %ebx,%edx
f0102645:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f010264b:	c1 fa 03             	sar    $0x3,%edx
f010264e:	c1 e2 0c             	shl    $0xc,%edx
f0102651:	39 d1                	cmp    %edx,%ecx
f0102653:	74 24                	je     f0102679 <mem_init+0x1158>
f0102655:	c7 44 24 0c 08 75 10 	movl   $0xf0107508,0xc(%esp)
f010265c:	f0 
f010265d:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102664:	f0 
f0102665:	c7 44 24 04 0f 04 00 	movl   $0x40f,0x4(%esp)
f010266c:	00 
f010266d:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102674:	e8 c7 d9 ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f0102679:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f010267f:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102684:	74 24                	je     f01026aa <mem_init+0x1189>
f0102686:	c7 44 24 0c 23 7c 10 	movl   $0xf0107c23,0xc(%esp)
f010268d:	f0 
f010268e:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102695:	f0 
f0102696:	c7 44 24 04 11 04 00 	movl   $0x411,0x4(%esp)
f010269d:	00 
f010269e:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01026a5:	e8 96 d9 ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f01026aa:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// check pointer arithmetic in pgdir_walk
	page_free(pp0);
f01026b0:	89 1c 24             	mov    %ebx,(%esp)
f01026b3:	e8 f3 ea ff ff       	call   f01011ab <page_free>
	va = (void*)(PGSIZE * NPDENTRIES + PGSIZE);
	ptep = pgdir_walk(kern_pgdir, va, 1);
f01026b8:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01026bf:	00 
f01026c0:	c7 44 24 04 00 10 40 	movl   $0x401000,0x4(%esp)
f01026c7:	00 
f01026c8:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01026cd:	89 04 24             	mov    %eax,(%esp)
f01026d0:	e8 0e eb ff ff       	call   f01011e3 <pgdir_walk>
f01026d5:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01026d8:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f01026db:	8b 0d 8c 7e 1c f0    	mov    0xf01c7e8c,%ecx
f01026e1:	8b 51 04             	mov    0x4(%ecx),%edx
f01026e4:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01026ea:	8b 35 88 7e 1c f0    	mov    0xf01c7e88,%esi
f01026f0:	89 d0                	mov    %edx,%eax
f01026f2:	c1 e8 0c             	shr    $0xc,%eax
f01026f5:	39 f0                	cmp    %esi,%eax
f01026f7:	72 20                	jb     f0102719 <mem_init+0x11f8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01026f9:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01026fd:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0102704:	f0 
f0102705:	c7 44 24 04 18 04 00 	movl   $0x418,0x4(%esp)
f010270c:	00 
f010270d:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102714:	e8 27 d9 ff ff       	call   f0100040 <_panic>
	assert(ptep == ptep1 + PTX(va));
f0102719:	81 ea fc ff ff 0f    	sub    $0xffffffc,%edx
f010271f:	39 55 cc             	cmp    %edx,-0x34(%ebp)
f0102722:	74 24                	je     f0102748 <mem_init+0x1227>
f0102724:	c7 44 24 0c 8e 7c 10 	movl   $0xf0107c8e,0xc(%esp)
f010272b:	f0 
f010272c:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102733:	f0 
f0102734:	c7 44 24 04 19 04 00 	movl   $0x419,0x4(%esp)
f010273b:	00 
f010273c:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102743:	e8 f8 d8 ff ff       	call   f0100040 <_panic>
	kern_pgdir[PDX(va)] = 0;
f0102748:	c7 41 04 00 00 00 00 	movl   $0x0,0x4(%ecx)
	pp0->pp_ref = 0;
f010274f:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102755:	89 d8                	mov    %ebx,%eax
f0102757:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f010275d:	c1 f8 03             	sar    $0x3,%eax
f0102760:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102763:	89 c2                	mov    %eax,%edx
f0102765:	c1 ea 0c             	shr    $0xc,%edx
f0102768:	39 d6                	cmp    %edx,%esi
f010276a:	77 20                	ja     f010278c <mem_init+0x126b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010276c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102770:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0102777:	f0 
f0102778:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010277f:	00 
f0102780:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f0102787:	e8 b4 d8 ff ff       	call   f0100040 <_panic>

	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
f010278c:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102793:	00 
f0102794:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
f010279b:	00 
	return (void *)(pa + KERNBASE);
f010279c:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01027a1:	89 04 24             	mov    %eax,(%esp)
f01027a4:	e8 50 37 00 00       	call   f0105ef9 <memset>
	page_free(pp0);
f01027a9:	89 1c 24             	mov    %ebx,(%esp)
f01027ac:	e8 fa e9 ff ff       	call   f01011ab <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f01027b1:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01027b8:	00 
f01027b9:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01027c0:	00 
f01027c1:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01027c6:	89 04 24             	mov    %eax,(%esp)
f01027c9:	e8 15 ea ff ff       	call   f01011e3 <pgdir_walk>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01027ce:	89 da                	mov    %ebx,%edx
f01027d0:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f01027d6:	c1 fa 03             	sar    $0x3,%edx
f01027d9:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01027dc:	89 d0                	mov    %edx,%eax
f01027de:	c1 e8 0c             	shr    $0xc,%eax
f01027e1:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f01027e7:	72 20                	jb     f0102809 <mem_init+0x12e8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01027e9:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01027ed:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f01027f4:	f0 
f01027f5:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01027fc:	00 
f01027fd:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f0102804:	e8 37 d8 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0102809:	8d 82 00 00 00 f0    	lea    -0x10000000(%edx),%eax
	ptep = (pte_t *) page2kva(pp0);
f010280f:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	for(i=0; i<NPTENTRIES; i++)
		assert((ptep[i] & PTE_P) == 0);
f0102812:	f6 82 00 00 00 f0 01 	testb  $0x1,-0x10000000(%edx)
f0102819:	75 13                	jne    f010282e <mem_init+0x130d>
f010281b:	8d 82 04 00 00 f0    	lea    -0xffffffc(%edx),%eax
f0102821:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0102827:	8b 30                	mov    (%eax),%esi
f0102829:	83 e6 01             	and    $0x1,%esi
f010282c:	74 24                	je     f0102852 <mem_init+0x1331>
f010282e:	c7 44 24 0c a6 7c 10 	movl   $0xf0107ca6,0xc(%esp)
f0102835:	f0 
f0102836:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010283d:	f0 
f010283e:	c7 44 24 04 23 04 00 	movl   $0x423,0x4(%esp)
f0102845:	00 
f0102846:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010284d:	e8 ee d7 ff ff       	call   f0100040 <_panic>
f0102852:	83 c0 04             	add    $0x4,%eax
	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
	page_free(pp0);
	pgdir_walk(kern_pgdir, 0x0, 1);
	ptep = (pte_t *) page2kva(pp0);
	for(i=0; i<NPTENTRIES; i++)
f0102855:	39 d0                	cmp    %edx,%eax
f0102857:	75 ce                	jne    f0102827 <mem_init+0x1306>
		assert((ptep[i] & PTE_P) == 0);
	kern_pgdir[0] = 0;
f0102859:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f010285e:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f0102864:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// give free list back
	page_free_list = fl;
f010286a:	8b 45 d0             	mov    -0x30(%ebp),%eax
f010286d:	a3 40 72 1c f0       	mov    %eax,0xf01c7240

	// free the pages we took
	page_free(pp0);
f0102872:	89 1c 24             	mov    %ebx,(%esp)
f0102875:	e8 31 e9 ff ff       	call   f01011ab <page_free>
	page_free(pp1);
f010287a:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010287d:	89 04 24             	mov    %eax,(%esp)
f0102880:	e8 26 e9 ff ff       	call   f01011ab <page_free>
	page_free(pp2);
f0102885:	89 3c 24             	mov    %edi,(%esp)
f0102888:	e8 1e e9 ff ff       	call   f01011ab <page_free>

	cprintf("check_page() succeeded!\n");
f010288d:	c7 04 24 bd 7c 10 f0 	movl   $0xf0107cbd,(%esp)
f0102894:	e8 ed 15 00 00       	call   f0103e86 <cprintf>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t to_map_pages;
	to_map_pages = (sizeof(struct Page) * npages - 1) / PGSIZE + 1;
f0102899:	a1 88 7e 1c f0       	mov    0xf01c7e88,%eax
f010289e:	8d 0c c5 ff ff ff ff 	lea    -0x1(,%eax,8),%ecx
f01028a5:	c1 e9 0c             	shr    $0xc,%ecx
f01028a8:	83 c1 01             	add    $0x1,%ecx
	boot_map_region(kern_pgdir, UPAGES, to_map_pages * PGSIZE, PADDR(pages), PTE_U | PTE_P);
f01028ab:	a1 90 7e 1c f0       	mov    0xf01c7e90,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01028b0:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01028b5:	77 20                	ja     f01028d7 <mem_init+0x13b6>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01028b7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01028bb:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f01028c2:	f0 
f01028c3:	c7 44 24 04 be 00 00 	movl   $0xbe,0x4(%esp)
f01028ca:	00 
f01028cb:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01028d2:	e8 69 d7 ff ff       	call   f0100040 <_panic>
f01028d7:	c1 e1 0c             	shl    $0xc,%ecx
f01028da:	c7 44 24 04 05 00 00 	movl   $0x5,0x4(%esp)
f01028e1:	00 
	return (physaddr_t)kva - KERNBASE;
f01028e2:	05 00 00 00 10       	add    $0x10000000,%eax
f01028e7:	89 04 24             	mov    %eax,(%esp)
f01028ea:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f01028ef:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01028f4:	e8 f4 e9 ff ff       	call   f01012ed <boot_map_region>
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	size_t i;
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		page_insert(kern_pgdir,pa2page(PADDR(envs)+i),(void *)(UENVS + i),PTE_U| PTE_P);
f01028f9:	a1 48 72 1c f0       	mov    0xf01c7248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01028fe:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102903:	76 28                	jbe    f010292d <mem_init+0x140c>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102905:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010290a:	c1 e8 0c             	shr    $0xc,%eax
f010290d:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f0102913:	0f 82 ec 0a 00 00    	jb     f0103405 <mem_init+0x1ee4>
f0102919:	eb 44                	jmp    f010295f <mem_init+0x143e>
f010291b:	8d 93 00 00 c0 ee    	lea    -0x11400000(%ebx),%edx
f0102921:	a1 48 72 1c f0       	mov    0xf01c7248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102926:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010292b:	77 20                	ja     f010294d <mem_init+0x142c>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010292d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102931:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0102938:	f0 
f0102939:	c7 44 24 04 c9 00 00 	movl   $0xc9,0x4(%esp)
f0102940:	00 
f0102941:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102948:	e8 f3 d6 ff ff       	call   f0100040 <_panic>
f010294d:	8d 84 18 00 00 00 10 	lea    0x10000000(%eax,%ebx,1),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102954:	c1 e8 0c             	shr    $0xc,%eax
f0102957:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f010295d:	72 1c                	jb     f010297b <mem_init+0x145a>
		panic("pa2page called with invalid pa");
f010295f:	c7 44 24 08 d4 73 10 	movl   $0xf01073d4,0x8(%esp)
f0102966:	f0 
f0102967:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010296e:	00 
f010296f:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f0102976:	e8 c5 d6 ff ff       	call   f0100040 <_panic>
f010297b:	c7 44 24 0c 05 00 00 	movl   $0x5,0xc(%esp)
f0102982:	00 
f0102983:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102987:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
f010298d:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102990:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102994:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0102999:	89 04 24             	mov    %eax,(%esp)
f010299c:	e8 bf ea ff ff       	call   f0101460 <page_insert>
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	size_t i;
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f01029a1:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f01029a7:	81 fb 00 f0 01 00    	cmp    $0x1f000,%ebx
f01029ad:	0f 85 68 ff ff ff    	jne    f010291b <mem_init+0x13fa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01029b3:	bb 00 70 11 f0       	mov    $0xf0117000,%ebx
f01029b8:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f01029be:	76 28                	jbe    f01029e8 <mem_init+0x14c7>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f01029c0:	b8 00 70 11 00       	mov    $0x117000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01029c5:	c1 e8 0c             	shr    $0xc,%eax
f01029c8:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f01029ce:	0f 82 f4 09 00 00    	jb     f01033c8 <mem_init+0x1ea7>
f01029d4:	eb 36                	jmp    f0102a0c <mem_init+0x14eb>
f01029d6:	8d 14 3b             	lea    (%ebx,%edi,1),%edx
f01029d9:	89 f8                	mov    %edi,%eax
f01029db:	c1 e8 0c             	shr    $0xc,%eax
f01029de:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f01029e4:	72 42                	jb     f0102a28 <mem_init+0x1507>
f01029e6:	eb 24                	jmp    f0102a0c <mem_init+0x14eb>

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01029e8:	c7 44 24 0c 00 70 11 	movl   $0xf0117000,0xc(%esp)
f01029ef:	f0 
f01029f0:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f01029f7:	f0 
f01029f8:	c7 44 24 04 d6 00 00 	movl   $0xd6,0x4(%esp)
f01029ff:	00 
f0102a00:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102a07:	e8 34 d6 ff ff       	call   f0100040 <_panic>

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
f0102a0c:	c7 44 24 08 d4 73 10 	movl   $0xf01073d4,0x8(%esp)
f0102a13:	f0 
f0102a14:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102a1b:	00 
f0102a1c:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f0102a23:	e8 18 d6 ff ff       	call   f0100040 <_panic>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		page_insert(kern_pgdir, pa2page(PADDR(bootstack) + i), (void *)(KSTACKTOP-KSTKSIZE + i), PTE_W| PTE_P);
f0102a28:	c7 44 24 0c 03 00 00 	movl   $0x3,0xc(%esp)
f0102a2f:	00 
f0102a30:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102a34:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
f0102a3a:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102a3d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102a41:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0102a46:	89 04 24             	mov    %eax,(%esp)
f0102a49:	e8 12 ea ff ff       	call   f0101460 <page_insert>
f0102a4e:	81 c7 00 10 00 00    	add    $0x1000,%edi
	//     * [KSTACKTOP-PTSIZE, KSTACKTOP-KSTKSIZE) -- not backed; so if
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102a54:	81 ff 00 f0 11 00    	cmp    $0x11f000,%edi
f0102a5a:	0f 85 76 ff ff ff    	jne    f01029d6 <mem_init+0x14b5>
f0102a60:	e9 0e 09 00 00       	jmp    f0103373 <mem_init+0x1e52>
f0102a65:	8d bb 00 10 00 f0    	lea    -0xffff000(%ebx),%edi
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W| PTE_P);
f0102a6b:	8b 1d 88 7e 1c f0    	mov    0xf01c7e88,%ebx
f0102a71:	89 de                	mov    %ebx,%esi
f0102a73:	c1 e6 0c             	shl    $0xc,%esi
f0102a76:	89 c8                	mov    %ecx,%eax
f0102a78:	ba 00 00 00 00       	mov    $0x0,%edx
f0102a7d:	f7 f6                	div    %esi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102a7f:	c1 ea 0c             	shr    $0xc,%edx
f0102a82:	39 d3                	cmp    %edx,%ebx
f0102a84:	77 1c                	ja     f0102aa2 <mem_init+0x1581>
		panic("pa2page called with invalid pa");
f0102a86:	c7 44 24 08 d4 73 10 	movl   $0xf01073d4,0x8(%esp)
f0102a8d:	f0 
f0102a8e:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102a95:	00 
f0102a96:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f0102a9d:	e8 9e d5 ff ff       	call   f0100040 <_panic>
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
f0102aa2:	89 cb                	mov    %ecx,%ebx
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W| PTE_P);
f0102aa4:	c7 44 24 0c 03 00 00 	movl   $0x3,0xc(%esp)
f0102aab:	00 
f0102aac:	89 7c 24 08          	mov    %edi,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102ab0:	a1 90 7e 1c f0       	mov    0xf01c7e90,%eax
f0102ab5:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f0102ab8:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102abc:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0102ac1:	89 04 24             	mov    %eax,(%esp)
f0102ac4:	e8 97 e9 ff ff       	call   f0101460 <page_insert>
		pa2page(i % (npages*PGSIZE))->pp_ref--;                 //this statement is to keep pp_ref == 0 in page_free_list
f0102ac9:	8b 0d 88 7e 1c f0    	mov    0xf01c7e88,%ecx
f0102acf:	89 ce                	mov    %ecx,%esi
f0102ad1:	c1 e6 0c             	shl    $0xc,%esi
f0102ad4:	89 d8                	mov    %ebx,%eax
f0102ad6:	ba 00 00 00 00       	mov    $0x0,%edx
f0102adb:	f7 f6                	div    %esi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102add:	c1 ea 0c             	shr    $0xc,%edx
f0102ae0:	39 d1                	cmp    %edx,%ecx
f0102ae2:	77 1c                	ja     f0102b00 <mem_init+0x15df>
		panic("pa2page called with invalid pa");
f0102ae4:	c7 44 24 08 d4 73 10 	movl   $0xf01073d4,0x8(%esp)
f0102aeb:	f0 
f0102aec:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102af3:	00 
f0102af4:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f0102afb:	e8 40 d5 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0102b00:	a1 90 7e 1c f0       	mov    0xf01c7e90,%eax
f0102b05:	66 83 6c d0 04 01    	subw   $0x1,0x4(%eax,%edx,8)
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
f0102b0b:	8d 8b 00 10 00 00    	lea    0x1000(%ebx),%ecx
f0102b11:	81 f9 00 00 00 10    	cmp    $0x10000000,%ecx
f0102b17:	0f 85 48 ff ff ff    	jne    f0102a65 <mem_init+0x1544>
static void
mem_init_mp(void)
{
	// Create a direct mapping at the top of virtual address space starting
	// at IOMEMBASE for accessing the LAPIC unit using memory-mapped I/O.
	boot_map_region(kern_pgdir, IOMEMBASE, -IOMEMBASE, IOMEM_PADDR, PTE_W);
f0102b1d:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102b24:	00 
f0102b25:	c7 04 24 00 00 00 fe 	movl   $0xfe000000,(%esp)
f0102b2c:	b9 00 00 00 02       	mov    $0x2000000,%ecx
f0102b31:	ba 00 00 00 fe       	mov    $0xfe000000,%edx
f0102b36:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0102b3b:	e8 ad e7 ff ff       	call   f01012ed <boot_map_region>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102b40:	b8 00 90 1c f0       	mov    $0xf01c9000,%eax
f0102b45:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102b4a:	0f 87 41 08 00 00    	ja     f0103391 <mem_init+0x1e70>
f0102b50:	eb 0c                	jmp    f0102b5e <mem_init+0x163d>
	physaddr_t cpu_phystk_i;
	uintptr_t cpu_vastk_i;
	size_t va;
	for(i = 0 ; i<NCPU ;i++){
		cpu_vastk_i = KSTACKTOP - i* (KSTKSIZE + KSTKGAP)-KSTKSIZE;
		cpu_phystk_i = PADDR(percpu_kstacks[i]);
f0102b52:	89 d8                	mov    %ebx,%eax
f0102b54:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102b5a:	77 27                	ja     f0102b83 <mem_init+0x1662>
f0102b5c:	eb 05                	jmp    f0102b63 <mem_init+0x1642>
f0102b5e:	b8 00 90 1c f0       	mov    $0xf01c9000,%eax
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102b63:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102b67:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0102b6e:	f0 
f0102b6f:	c7 44 24 04 24 01 00 	movl   $0x124,0x4(%esp)
f0102b76:	00 
f0102b77:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102b7e:	e8 bd d4 ff ff       	call   f0100040 <_panic>
		boot_map_region(kern_pgdir,cpu_vastk_i,KSTKSIZE,cpu_phystk_i,PTE_W);
f0102b83:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102b8a:	00 
f0102b8b:	8d 83 00 00 00 10    	lea    0x10000000(%ebx),%eax
f0102b91:	89 04 24             	mov    %eax,(%esp)
f0102b94:	b9 00 80 00 00       	mov    $0x8000,%ecx
f0102b99:	89 f2                	mov    %esi,%edx
f0102b9b:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0102ba0:	e8 48 e7 ff ff       	call   f01012ed <boot_map_region>
f0102ba5:	81 c3 00 80 00 00    	add    $0x8000,%ebx
f0102bab:	81 ee 00 00 01 00    	sub    $0x10000,%esi
	// LAB 4: Your code here:
	int i;
	physaddr_t cpu_phystk_i;
	uintptr_t cpu_vastk_i;
	size_t va;
	for(i = 0 ; i<NCPU ;i++){
f0102bb1:	39 fb                	cmp    %edi,%ebx
f0102bb3:	75 9d                	jne    f0102b52 <mem_init+0x1631>
check_kern_pgdir(void)
{
	uint32_t i, n;
	pde_t *pgdir;

	pgdir = kern_pgdir;
f0102bb5:	8b 3d 8c 7e 1c f0    	mov    0xf01c7e8c,%edi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
f0102bbb:	a1 88 7e 1c f0       	mov    0xf01c7e88,%eax
f0102bc0:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0102bc3:	8d 04 c5 ff 0f 00 00 	lea    0xfff(,%eax,8),%eax
	for (i = 0; i < n; i += PGSIZE)
f0102bca:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102bcf:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0102bd2:	75 30                	jne    f0102c04 <mem_init+0x16e3>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102bd4:	8b 1d 48 72 1c f0    	mov    0xf01c7248,%ebx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102bda:	89 de                	mov    %ebx,%esi
f0102bdc:	ba 00 00 c0 ee       	mov    $0xeec00000,%edx
f0102be1:	89 f8                	mov    %edi,%eax
f0102be3:	e8 ec df ff ff       	call   f0100bd4 <check_va2pa>
f0102be8:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102bee:	0f 86 94 00 00 00    	jbe    f0102c88 <mem_init+0x1767>
f0102bf4:	bb 00 00 c0 ee       	mov    $0xeec00000,%ebx
f0102bf9:	81 c6 00 00 40 21    	add    $0x21400000,%esi
f0102bff:	e9 a4 00 00 00       	jmp    f0102ca8 <mem_init+0x1787>
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102c04:	8b 1d 90 7e 1c f0    	mov    0xf01c7e90,%ebx
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102c0a:	8d b3 00 00 00 10    	lea    0x10000000(%ebx),%esi
f0102c10:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f0102c15:	89 f8                	mov    %edi,%eax
f0102c17:	e8 b8 df ff ff       	call   f0100bd4 <check_va2pa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102c1c:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102c22:	77 20                	ja     f0102c44 <mem_init+0x1723>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102c24:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102c28:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0102c2f:	f0 
f0102c30:	c7 44 24 04 60 03 00 	movl   $0x360,0x4(%esp)
f0102c37:	00 
f0102c38:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102c3f:	e8 fc d3 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102c44:	ba 00 00 00 00       	mov    $0x0,%edx
f0102c49:	8d 0c 16             	lea    (%esi,%edx,1),%ecx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102c4c:	39 c8                	cmp    %ecx,%eax
f0102c4e:	74 24                	je     f0102c74 <mem_init+0x1753>
f0102c50:	c7 44 24 0c 1c 78 10 	movl   $0xf010781c,0xc(%esp)
f0102c57:	f0 
f0102c58:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102c5f:	f0 
f0102c60:	c7 44 24 04 60 03 00 	movl   $0x360,0x4(%esp)
f0102c67:	00 
f0102c68:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102c6f:	e8 cc d3 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102c74:	8d 9a 00 10 00 00    	lea    0x1000(%edx),%ebx
f0102c7a:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f0102c7d:	0f 87 d2 07 00 00    	ja     f0103455 <mem_init+0x1f34>
f0102c83:	e9 4c ff ff ff       	jmp    f0102bd4 <mem_init+0x16b3>
f0102c88:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102c8c:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0102c93:	f0 
f0102c94:	c7 44 24 04 65 03 00 	movl   $0x365,0x4(%esp)
f0102c9b:	00 
f0102c9c:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102ca3:	e8 98 d3 ff ff       	call   f0100040 <_panic>
f0102ca8:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102cab:	39 c2                	cmp    %eax,%edx
f0102cad:	74 24                	je     f0102cd3 <mem_init+0x17b2>
f0102caf:	c7 44 24 0c 50 78 10 	movl   $0xf0107850,0xc(%esp)
f0102cb6:	f0 
f0102cb7:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102cbe:	f0 
f0102cbf:	c7 44 24 04 65 03 00 	movl   $0x365,0x4(%esp)
f0102cc6:	00 
f0102cc7:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102cce:	e8 6d d3 ff ff       	call   f0100040 <_panic>
f0102cd3:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102cd9:	81 fb 00 f0 c1 ee    	cmp    $0xeec1f000,%ebx
f0102cdf:	0f 85 62 07 00 00    	jne    f0103447 <mem_init+0x1f26>
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102ce5:	8b 75 d0             	mov    -0x30(%ebp),%esi
f0102ce8:	c1 e6 0c             	shl    $0xc,%esi
f0102ceb:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102cf0:	85 f6                	test   %esi,%esi
f0102cf2:	75 07                	jne    f0102cfb <mem_init+0x17da>
f0102cf4:	bb 00 00 00 fe       	mov    $0xfe000000,%ebx
f0102cf9:	eb 41                	jmp    f0102d3c <mem_init+0x181b>
f0102cfb:	8d 93 00 00 00 f0    	lea    -0x10000000(%ebx),%edx
		assert(check_va2pa(pgdir, KERNBASE + i) == i);
f0102d01:	89 f8                	mov    %edi,%eax
f0102d03:	e8 cc de ff ff       	call   f0100bd4 <check_va2pa>
f0102d08:	39 c3                	cmp    %eax,%ebx
f0102d0a:	74 24                	je     f0102d30 <mem_init+0x180f>
f0102d0c:	c7 44 24 0c 84 78 10 	movl   $0xf0107884,0xc(%esp)
f0102d13:	f0 
f0102d14:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102d1b:	f0 
f0102d1c:	c7 44 24 04 69 03 00 	movl   $0x369,0x4(%esp)
f0102d23:	00 
f0102d24:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102d2b:	e8 10 d3 ff ff       	call   f0100040 <_panic>
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102d30:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102d36:	39 f3                	cmp    %esi,%ebx
f0102d38:	72 c1                	jb     f0102cfb <mem_init+0x17da>
f0102d3a:	eb b8                	jmp    f0102cf4 <mem_init+0x17d3>
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);
f0102d3c:	89 da                	mov    %ebx,%edx
f0102d3e:	89 f8                	mov    %edi,%eax
f0102d40:	e8 8f de ff ff       	call   f0100bd4 <check_va2pa>
f0102d45:	39 c3                	cmp    %eax,%ebx
f0102d47:	74 24                	je     f0102d6d <mem_init+0x184c>
f0102d49:	c7 44 24 0c d6 7c 10 	movl   $0xf0107cd6,0xc(%esp)
f0102d50:	f0 
f0102d51:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102d58:	f0 
f0102d59:	c7 44 24 04 6d 03 00 	movl   $0x36d,0x4(%esp)
f0102d60:	00 
f0102d61:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102d68:	e8 d3 d2 ff ff       	call   f0100040 <_panic>
	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
f0102d6d:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102d73:	81 fb 00 f0 ff ff    	cmp    $0xfffff000,%ebx
f0102d79:	75 c1                	jne    f0102d3c <mem_init+0x181b>
f0102d7b:	c7 45 d0 00 90 1c f0 	movl   $0xf01c9000,-0x30(%ebp)
f0102d82:	c7 45 cc 00 00 00 00 	movl   $0x0,-0x34(%ebp)
f0102d89:	be 00 80 bf ef       	mov    $0xefbf8000,%esi
f0102d8e:	b8 00 90 1c f0       	mov    $0xf01c9000,%eax
f0102d93:	05 00 80 40 20       	add    $0x20408000,%eax
f0102d98:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0102d9b:	8d 86 00 80 00 00    	lea    0x8000(%esi),%eax
f0102da1:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0102da4:	89 f2                	mov    %esi,%edx
f0102da6:	89 f8                	mov    %edi,%eax
f0102da8:	e8 27 de ff ff       	call   f0100bd4 <check_va2pa>
f0102dad:	8b 4d d0             	mov    -0x30(%ebp),%ecx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102db0:	81 f9 ff ff ff ef    	cmp    $0xefffffff,%ecx
f0102db6:	77 20                	ja     f0102dd8 <mem_init+0x18b7>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102db8:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0102dbc:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0102dc3:	f0 
f0102dc4:	c7 44 24 04 75 03 00 	movl   $0x375,0x4(%esp)
f0102dcb:	00 
f0102dcc:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102dd3:	e8 68 d2 ff ff       	call   f0100040 <_panic>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102dd8:	89 f3                	mov    %esi,%ebx
f0102dda:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0102ddd:	03 4d c4             	add    -0x3c(%ebp),%ecx
f0102de0:	89 75 c8             	mov    %esi,-0x38(%ebp)
f0102de3:	89 ce                	mov    %ecx,%esi
f0102de5:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
f0102de8:	39 c2                	cmp    %eax,%edx
f0102dea:	74 24                	je     f0102e10 <mem_init+0x18ef>
f0102dec:	c7 44 24 0c ac 78 10 	movl   $0xf01078ac,0xc(%esp)
f0102df3:	f0 
f0102df4:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102dfb:	f0 
f0102dfc:	c7 44 24 04 75 03 00 	movl   $0x375,0x4(%esp)
f0102e03:	00 
f0102e04:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102e0b:	e8 30 d2 ff ff       	call   f0100040 <_panic>
f0102e10:	81 c3 00 10 00 00    	add    $0x1000,%ebx

	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102e16:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0102e19:	0f 85 1a 06 00 00    	jne    f0103439 <mem_init+0x1f18>
f0102e1f:	8b 75 c8             	mov    -0x38(%ebp),%esi
f0102e22:	8d 9e 00 80 ff ff    	lea    -0x8000(%esi),%ebx
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
f0102e28:	89 da                	mov    %ebx,%edx
f0102e2a:	89 f8                	mov    %edi,%eax
f0102e2c:	e8 a3 dd ff ff       	call   f0100bd4 <check_va2pa>
f0102e31:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102e34:	74 24                	je     f0102e5a <mem_init+0x1939>
f0102e36:	c7 44 24 0c f4 78 10 	movl   $0xf01078f4,0xc(%esp)
f0102e3d:	f0 
f0102e3e:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102e45:	f0 
f0102e46:	c7 44 24 04 77 03 00 	movl   $0x377,0x4(%esp)
f0102e4d:	00 
f0102e4e:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102e55:	e8 e6 d1 ff ff       	call   f0100040 <_panic>
f0102e5a:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
f0102e60:	39 f3                	cmp    %esi,%ebx
f0102e62:	75 c4                	jne    f0102e28 <mem_init+0x1907>
f0102e64:	81 ee 00 00 01 00    	sub    $0x10000,%esi
f0102e6a:	81 45 cc 00 80 01 00 	addl   $0x18000,-0x34(%ebp)
f0102e71:	81 45 d0 00 80 00 00 	addl   $0x8000,-0x30(%ebp)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);

	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
f0102e78:	81 fe 00 80 b7 ef    	cmp    $0xefb78000,%esi
f0102e7e:	0f 85 17 ff ff ff    	jne    f0102d9b <mem_init+0x187a>
f0102e84:	b8 00 00 00 00       	mov    $0x0,%eax
			assert(check_va2pa(pgdir, base + i) == ~0);
	}

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
		switch (i) {
f0102e89:	8d 90 45 fc ff ff    	lea    -0x3bb(%eax),%edx
f0102e8f:	83 fa 03             	cmp    $0x3,%edx
f0102e92:	77 2e                	ja     f0102ec2 <mem_init+0x19a1>
		case PDX(UVPT):
		case PDX(KSTACKTOP-1):
		case PDX(UPAGES):
		case PDX(UENVS):
			assert(pgdir[i] & PTE_P);
f0102e94:	f6 04 87 01          	testb  $0x1,(%edi,%eax,4)
f0102e98:	0f 85 aa 00 00 00    	jne    f0102f48 <mem_init+0x1a27>
f0102e9e:	c7 44 24 0c f1 7c 10 	movl   $0xf0107cf1,0xc(%esp)
f0102ea5:	f0 
f0102ea6:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102ead:	f0 
f0102eae:	c7 44 24 04 81 03 00 	movl   $0x381,0x4(%esp)
f0102eb5:	00 
f0102eb6:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102ebd:	e8 7e d1 ff ff       	call   f0100040 <_panic>
			break;
		default:
			if (i >= PDX(KERNBASE)) {
f0102ec2:	3d bf 03 00 00       	cmp    $0x3bf,%eax
f0102ec7:	76 55                	jbe    f0102f1e <mem_init+0x19fd>
				assert(pgdir[i] & PTE_P);
f0102ec9:	8b 14 87             	mov    (%edi,%eax,4),%edx
f0102ecc:	f6 c2 01             	test   $0x1,%dl
f0102ecf:	75 24                	jne    f0102ef5 <mem_init+0x19d4>
f0102ed1:	c7 44 24 0c f1 7c 10 	movl   $0xf0107cf1,0xc(%esp)
f0102ed8:	f0 
f0102ed9:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102ee0:	f0 
f0102ee1:	c7 44 24 04 85 03 00 	movl   $0x385,0x4(%esp)
f0102ee8:	00 
f0102ee9:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102ef0:	e8 4b d1 ff ff       	call   f0100040 <_panic>
				assert(pgdir[i] & PTE_W);
f0102ef5:	f6 c2 02             	test   $0x2,%dl
f0102ef8:	75 4e                	jne    f0102f48 <mem_init+0x1a27>
f0102efa:	c7 44 24 0c 02 7d 10 	movl   $0xf0107d02,0xc(%esp)
f0102f01:	f0 
f0102f02:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102f09:	f0 
f0102f0a:	c7 44 24 04 86 03 00 	movl   $0x386,0x4(%esp)
f0102f11:	00 
f0102f12:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102f19:	e8 22 d1 ff ff       	call   f0100040 <_panic>
			} else
				assert(pgdir[i] == 0);
f0102f1e:	83 3c 87 00          	cmpl   $0x0,(%edi,%eax,4)
f0102f22:	74 24                	je     f0102f48 <mem_init+0x1a27>
f0102f24:	c7 44 24 0c 13 7d 10 	movl   $0xf0107d13,0xc(%esp)
f0102f2b:	f0 
f0102f2c:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102f33:	f0 
f0102f34:	c7 44 24 04 88 03 00 	movl   $0x388,0x4(%esp)
f0102f3b:	00 
f0102f3c:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102f43:	e8 f8 d0 ff ff       	call   f0100040 <_panic>
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
	}

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
f0102f48:	83 c0 01             	add    $0x1,%eax
f0102f4b:	3d 00 04 00 00       	cmp    $0x400,%eax
f0102f50:	0f 85 33 ff ff ff    	jne    f0102e89 <mem_init+0x1968>
			} else
				assert(pgdir[i] == 0);
			break;
		}
	}
	cprintf("check_kern_pgdir() succeeded!\n");
f0102f56:	c7 04 24 18 79 10 f0 	movl   $0xf0107918,(%esp)
f0102f5d:	e8 24 0f 00 00       	call   f0103e86 <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f0102f62:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0102f67:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102f6c:	77 20                	ja     f0102f8e <mem_init+0x1a6d>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102f6e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102f72:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0102f79:	f0 
f0102f7a:	c7 44 24 04 f6 00 00 	movl   $0xf6,0x4(%esp)
f0102f81:	00 
f0102f82:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102f89:	e8 b2 d0 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0102f8e:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0102f93:	0f 22 d8             	mov    %eax,%cr3
	check_page_free_list(0);
f0102f96:	b8 00 00 00 00       	mov    $0x0,%eax
f0102f9b:	e8 a3 dc ff ff       	call   f0100c43 <check_page_free_list>

static __inline uint32_t
rcr0(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr0,%0" : "=r" (val));
f0102fa0:	0f 20 c0             	mov    %cr0,%eax
	// entry.S set the really important flags in cr0 (including enabling
	// paging).  Here we configure the rest of the flags that we care about.
	cr0 = rcr0();
	cr0 |= CR0_PE|CR0_PG|CR0_AM|CR0_WP|CR0_NE|CR0_MP;
	cr0 &= ~(CR0_TS|CR0_EM);
f0102fa3:	83 e0 f3             	and    $0xfffffff3,%eax
f0102fa6:	0d 23 00 05 80       	or     $0x80050023,%eax
}

static __inline void
lcr0(uint32_t val)
{
	__asm __volatile("movl %0,%%cr0" : : "r" (val));
f0102fab:	0f 22 c0             	mov    %eax,%cr0
	uintptr_t va;
	int i;

	// check that we can read and write installed pages
	pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0102fae:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102fb5:	e8 6c e1 ff ff       	call   f0101126 <page_alloc>
f0102fba:	89 c3                	mov    %eax,%ebx
f0102fbc:	85 c0                	test   %eax,%eax
f0102fbe:	75 24                	jne    f0102fe4 <mem_init+0x1ac3>
f0102fc0:	c7 44 24 0c 15 7b 10 	movl   $0xf0107b15,0xc(%esp)
f0102fc7:	f0 
f0102fc8:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0102fcf:	f0 
f0102fd0:	c7 44 24 04 3e 04 00 	movl   $0x43e,0x4(%esp)
f0102fd7:	00 
f0102fd8:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0102fdf:	e8 5c d0 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0102fe4:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102feb:	e8 36 e1 ff ff       	call   f0101126 <page_alloc>
f0102ff0:	89 c7                	mov    %eax,%edi
f0102ff2:	85 c0                	test   %eax,%eax
f0102ff4:	75 24                	jne    f010301a <mem_init+0x1af9>
f0102ff6:	c7 44 24 0c 2b 7b 10 	movl   $0xf0107b2b,0xc(%esp)
f0102ffd:	f0 
f0102ffe:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0103005:	f0 
f0103006:	c7 44 24 04 3f 04 00 	movl   $0x43f,0x4(%esp)
f010300d:	00 
f010300e:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0103015:	e8 26 d0 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f010301a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0103021:	e8 00 e1 ff ff       	call   f0101126 <page_alloc>
f0103026:	89 c6                	mov    %eax,%esi
f0103028:	85 c0                	test   %eax,%eax
f010302a:	75 24                	jne    f0103050 <mem_init+0x1b2f>
f010302c:	c7 44 24 0c 41 7b 10 	movl   $0xf0107b41,0xc(%esp)
f0103033:	f0 
f0103034:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010303b:	f0 
f010303c:	c7 44 24 04 40 04 00 	movl   $0x440,0x4(%esp)
f0103043:	00 
f0103044:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010304b:	e8 f0 cf ff ff       	call   f0100040 <_panic>
	page_free(pp0);
f0103050:	89 1c 24             	mov    %ebx,(%esp)
f0103053:	e8 53 e1 ff ff       	call   f01011ab <page_free>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103058:	89 f8                	mov    %edi,%eax
f010305a:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f0103060:	c1 f8 03             	sar    $0x3,%eax
f0103063:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103066:	89 c2                	mov    %eax,%edx
f0103068:	c1 ea 0c             	shr    $0xc,%edx
f010306b:	3b 15 88 7e 1c f0    	cmp    0xf01c7e88,%edx
f0103071:	72 20                	jb     f0103093 <mem_init+0x1b72>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103073:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103077:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f010307e:	f0 
f010307f:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103086:	00 
f0103087:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f010308e:	e8 ad cf ff ff       	call   f0100040 <_panic>
	memset(page2kva(pp1), 1, PGSIZE);
f0103093:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010309a:	00 
f010309b:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f01030a2:	00 
	return (void *)(pa + KERNBASE);
f01030a3:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01030a8:	89 04 24             	mov    %eax,(%esp)
f01030ab:	e8 49 2e 00 00       	call   f0105ef9 <memset>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01030b0:	89 f0                	mov    %esi,%eax
f01030b2:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f01030b8:	c1 f8 03             	sar    $0x3,%eax
f01030bb:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01030be:	89 c2                	mov    %eax,%edx
f01030c0:	c1 ea 0c             	shr    $0xc,%edx
f01030c3:	3b 15 88 7e 1c f0    	cmp    0xf01c7e88,%edx
f01030c9:	72 20                	jb     f01030eb <mem_init+0x1bca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01030cb:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01030cf:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f01030d6:	f0 
f01030d7:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01030de:	00 
f01030df:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f01030e6:	e8 55 cf ff ff       	call   f0100040 <_panic>
	memset(page2kva(pp2), 2, PGSIZE);
f01030eb:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01030f2:	00 
f01030f3:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f01030fa:	00 
	return (void *)(pa + KERNBASE);
f01030fb:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0103100:	89 04 24             	mov    %eax,(%esp)
f0103103:	e8 f1 2d 00 00       	call   f0105ef9 <memset>
	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f0103108:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f010310f:	00 
f0103110:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0103117:	00 
f0103118:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010311c:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0103121:	89 04 24             	mov    %eax,(%esp)
f0103124:	e8 37 e3 ff ff       	call   f0101460 <page_insert>
	assert(pp1->pp_ref == 1);
f0103129:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f010312e:	74 24                	je     f0103154 <mem_init+0x1c33>
f0103130:	c7 44 24 0c 12 7c 10 	movl   $0xf0107c12,0xc(%esp)
f0103137:	f0 
f0103138:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010313f:	f0 
f0103140:	c7 44 24 04 45 04 00 	movl   $0x445,0x4(%esp)
f0103147:	00 
f0103148:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010314f:	e8 ec ce ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
f0103154:	81 3d 00 10 00 00 01 	cmpl   $0x1010101,0x1000
f010315b:	01 01 01 
f010315e:	74 24                	je     f0103184 <mem_init+0x1c63>
f0103160:	c7 44 24 0c 38 79 10 	movl   $0xf0107938,0xc(%esp)
f0103167:	f0 
f0103168:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010316f:	f0 
f0103170:	c7 44 24 04 46 04 00 	movl   $0x446,0x4(%esp)
f0103177:	00 
f0103178:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010317f:	e8 bc ce ff ff       	call   f0100040 <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f0103184:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f010318b:	00 
f010318c:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0103193:	00 
f0103194:	89 74 24 04          	mov    %esi,0x4(%esp)
f0103198:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f010319d:	89 04 24             	mov    %eax,(%esp)
f01031a0:	e8 bb e2 ff ff       	call   f0101460 <page_insert>
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
f01031a5:	81 3d 00 10 00 00 02 	cmpl   $0x2020202,0x1000
f01031ac:	02 02 02 
f01031af:	74 24                	je     f01031d5 <mem_init+0x1cb4>
f01031b1:	c7 44 24 0c 5c 79 10 	movl   $0xf010795c,0xc(%esp)
f01031b8:	f0 
f01031b9:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01031c0:	f0 
f01031c1:	c7 44 24 04 48 04 00 	movl   $0x448,0x4(%esp)
f01031c8:	00 
f01031c9:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01031d0:	e8 6b ce ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f01031d5:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f01031da:	74 24                	je     f0103200 <mem_init+0x1cdf>
f01031dc:	c7 44 24 0c 34 7c 10 	movl   $0xf0107c34,0xc(%esp)
f01031e3:	f0 
f01031e4:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01031eb:	f0 
f01031ec:	c7 44 24 04 49 04 00 	movl   $0x449,0x4(%esp)
f01031f3:	00 
f01031f4:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01031fb:	e8 40 ce ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f0103200:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f0103205:	74 24                	je     f010322b <mem_init+0x1d0a>
f0103207:	c7 44 24 0c 7d 7c 10 	movl   $0xf0107c7d,0xc(%esp)
f010320e:	f0 
f010320f:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0103216:	f0 
f0103217:	c7 44 24 04 4a 04 00 	movl   $0x44a,0x4(%esp)
f010321e:	00 
f010321f:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f0103226:	e8 15 ce ff ff       	call   f0100040 <_panic>
	*(uint32_t *)PGSIZE = 0x03030303U;
f010322b:	c7 05 00 10 00 00 03 	movl   $0x3030303,0x1000
f0103232:	03 03 03 
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103235:	89 f0                	mov    %esi,%eax
f0103237:	2b 05 90 7e 1c f0    	sub    0xf01c7e90,%eax
f010323d:	c1 f8 03             	sar    $0x3,%eax
f0103240:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103243:	89 c2                	mov    %eax,%edx
f0103245:	c1 ea 0c             	shr    $0xc,%edx
f0103248:	3b 15 88 7e 1c f0    	cmp    0xf01c7e88,%edx
f010324e:	72 20                	jb     f0103270 <mem_init+0x1d4f>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103250:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103254:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f010325b:	f0 
f010325c:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103263:	00 
f0103264:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f010326b:	e8 d0 cd ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
f0103270:	81 b8 00 00 00 f0 03 	cmpl   $0x3030303,-0x10000000(%eax)
f0103277:	03 03 03 
f010327a:	74 24                	je     f01032a0 <mem_init+0x1d7f>
f010327c:	c7 44 24 0c 80 79 10 	movl   $0xf0107980,0xc(%esp)
f0103283:	f0 
f0103284:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010328b:	f0 
f010328c:	c7 44 24 04 4c 04 00 	movl   $0x44c,0x4(%esp)
f0103293:	00 
f0103294:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010329b:	e8 a0 cd ff ff       	call   f0100040 <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f01032a0:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01032a7:	00 
f01032a8:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01032ad:	89 04 24             	mov    %eax,(%esp)
f01032b0:	e8 62 e1 ff ff       	call   f0101417 <page_remove>
	assert(pp2->pp_ref == 0);
f01032b5:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f01032ba:	74 24                	je     f01032e0 <mem_init+0x1dbf>
f01032bc:	c7 44 24 0c 6c 7c 10 	movl   $0xf0107c6c,0xc(%esp)
f01032c3:	f0 
f01032c4:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f01032cb:	f0 
f01032cc:	c7 44 24 04 4e 04 00 	movl   $0x44e,0x4(%esp)
f01032d3:	00 
f01032d4:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f01032db:	e8 60 cd ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f01032e0:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01032e5:	8b 08                	mov    (%eax),%ecx
f01032e7:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01032ed:	89 da                	mov    %ebx,%edx
f01032ef:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f01032f5:	c1 fa 03             	sar    $0x3,%edx
f01032f8:	c1 e2 0c             	shl    $0xc,%edx
f01032fb:	39 d1                	cmp    %edx,%ecx
f01032fd:	74 24                	je     f0103323 <mem_init+0x1e02>
f01032ff:	c7 44 24 0c 08 75 10 	movl   $0xf0107508,0xc(%esp)
f0103306:	f0 
f0103307:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010330e:	f0 
f010330f:	c7 44 24 04 51 04 00 	movl   $0x451,0x4(%esp)
f0103316:	00 
f0103317:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010331e:	e8 1d cd ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f0103323:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f0103329:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f010332e:	74 24                	je     f0103354 <mem_init+0x1e33>
f0103330:	c7 44 24 0c 23 7c 10 	movl   $0xf0107c23,0xc(%esp)
f0103337:	f0 
f0103338:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f010333f:	f0 
f0103340:	c7 44 24 04 53 04 00 	movl   $0x453,0x4(%esp)
f0103347:	00 
f0103348:	c7 04 24 0d 7a 10 f0 	movl   $0xf0107a0d,(%esp)
f010334f:	e8 ec cc ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f0103354:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// free the pages we took
	page_free(pp0);
f010335a:	89 1c 24             	mov    %ebx,(%esp)
f010335d:	e8 49 de ff ff       	call   f01011ab <page_free>

	cprintf("check_page_installed_pgdir() succeeded!\n");
f0103362:	c7 04 24 ac 79 10 f0 	movl   $0xf01079ac,(%esp)
f0103369:	e8 18 0b 00 00       	call   f0103e86 <cprintf>
f010336e:	e9 f6 00 00 00       	jmp    f0103469 <mem_init+0x1f48>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103373:	83 3d 88 7e 1c f0 00 	cmpl   $0x0,0xf01c7e88
f010337a:	0f 84 06 f7 ff ff    	je     f0102a86 <mem_init+0x1565>
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W| PTE_P);
f0103380:	bf 00 00 00 f0       	mov    $0xf0000000,%edi
f0103385:	bb 00 00 00 00       	mov    $0x0,%ebx
f010338a:	89 f2                	mov    %esi,%edx
f010338c:	e9 13 f7 ff ff       	jmp    f0102aa4 <mem_init+0x1583>
	uintptr_t cpu_vastk_i;
	size_t va;
	for(i = 0 ; i<NCPU ;i++){
		cpu_vastk_i = KSTACKTOP - i* (KSTKSIZE + KSTKGAP)-KSTKSIZE;
		cpu_phystk_i = PADDR(percpu_kstacks[i]);
		boot_map_region(kern_pgdir,cpu_vastk_i,KSTKSIZE,cpu_phystk_i,PTE_W);
f0103391:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0103398:	00 
f0103399:	c7 04 24 00 90 1c 00 	movl   $0x1c9000,(%esp)
f01033a0:	b9 00 80 00 00       	mov    $0x8000,%ecx
f01033a5:	ba 00 80 bf ef       	mov    $0xefbf8000,%edx
f01033aa:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01033af:	e8 39 df ff ff       	call   f01012ed <boot_map_region>
f01033b4:	bb 00 10 1d f0       	mov    $0xf01d1000,%ebx
f01033b9:	bf 00 90 20 f0       	mov    $0xf0209000,%edi
f01033be:	be 00 80 be ef       	mov    $0xefbe8000,%esi
f01033c3:	e9 8a f7 ff ff       	jmp    f0102b52 <mem_init+0x1631>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		page_insert(kern_pgdir, pa2page(PADDR(bootstack) + i), (void *)(KSTACKTOP-KSTKSIZE + i), PTE_W| PTE_P);
f01033c8:	c7 44 24 0c 03 00 00 	movl   $0x3,0xc(%esp)
f01033cf:	00 
f01033d0:	c7 44 24 08 00 80 bf 	movl   $0xefbf8000,0x8(%esp)
f01033d7:	ef 
		panic("pa2page called with invalid pa");
	return &pages[PGNUM(pa)];
f01033d8:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
f01033de:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01033e1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01033e5:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f01033ea:	89 04 24             	mov    %eax,(%esp)
f01033ed:	e8 6e e0 ff ff       	call   f0101460 <page_insert>
f01033f2:	bf 00 80 11 00       	mov    $0x118000,%edi
f01033f7:	b8 00 80 bf df       	mov    $0xdfbf8000,%eax
f01033fc:	29 d8                	sub    %ebx,%eax
f01033fe:	89 c3                	mov    %eax,%ebx
f0103400:	e9 d1 f5 ff ff       	jmp    f01029d6 <mem_init+0x14b5>
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	size_t i;
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		page_insert(kern_pgdir,pa2page(PADDR(envs)+i),(void *)(UENVS + i),PTE_U| PTE_P);
f0103405:	c7 44 24 0c 05 00 00 	movl   $0x5,0xc(%esp)
f010340c:	00 
f010340d:	c7 44 24 08 00 00 c0 	movl   $0xeec00000,0x8(%esp)
f0103414:	ee 
f0103415:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
f010341b:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f010341e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103422:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
f0103427:	89 04 24             	mov    %eax,(%esp)
f010342a:	e8 31 e0 ff ff       	call   f0101460 <page_insert>
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	size_t i;
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f010342f:	bb 00 10 00 00       	mov    $0x1000,%ebx
f0103434:	e9 e2 f4 ff ff       	jmp    f010291b <mem_init+0x13fa>
	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0103439:	89 da                	mov    %ebx,%edx
f010343b:	89 f8                	mov    %edi,%eax
f010343d:	e8 92 d7 ff ff       	call   f0100bd4 <check_va2pa>
f0103442:	e9 9e f9 ff ff       	jmp    f0102de5 <mem_init+0x18c4>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0103447:	89 da                	mov    %ebx,%edx
f0103449:	89 f8                	mov    %edi,%eax
f010344b:	e8 84 d7 ff ff       	call   f0100bd4 <check_va2pa>
f0103450:	e9 53 f8 ff ff       	jmp    f0102ca8 <mem_init+0x1787>
f0103455:	81 ea 00 f0 ff 10    	sub    $0x10fff000,%edx
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f010345b:	89 f8                	mov    %edi,%eax
f010345d:	e8 72 d7 ff ff       	call   f0100bd4 <check_va2pa>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0103462:	89 da                	mov    %ebx,%edx
f0103464:	e9 e0 f7 ff ff       	jmp    f0102c49 <mem_init+0x1728>
	cr0 &= ~(CR0_TS|CR0_EM);
	lcr0(cr0);

	// Some more checks, only possible after kern_pgdir is installed.
	check_page_installed_pgdir();
}
f0103469:	83 c4 4c             	add    $0x4c,%esp
f010346c:	5b                   	pop    %ebx
f010346d:	5e                   	pop    %esi
f010346e:	5f                   	pop    %edi
f010346f:	5d                   	pop    %ebp
f0103470:	c3                   	ret    

f0103471 <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f0103471:	55                   	push   %ebp
f0103472:	89 e5                	mov    %esp,%ebp
f0103474:	57                   	push   %edi
f0103475:	56                   	push   %esi
f0103476:	53                   	push   %ebx
f0103477:	83 ec 3c             	sub    $0x3c,%esp
f010347a:	8b 7d 08             	mov    0x8(%ebp),%edi
f010347d:	8b 45 0c             	mov    0xc(%ebp),%eax

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
f0103480:	89 c2                	mov    %eax,%edx
f0103482:	03 55 10             	add    0x10(%ebp),%edx
f0103485:	89 55 d0             	mov    %edx,-0x30(%ebp)
f0103488:	39 d0                	cmp    %edx,%eax
f010348a:	73 70                	jae    f01034fc <user_mem_check+0x8b>
f010348c:	89 c3                	mov    %eax,%ebx
f010348e:	89 c6                	mov    %eax,%esi
		pte_t* store=0;
		struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
		if(store!=NULL)
		{
			//cprintf("pte!=NULL %08x\r\n",*store);
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f0103490:	8b 45 14             	mov    0x14(%ebp),%eax
f0103493:	83 c8 01             	or     $0x1,%eax
f0103496:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
	{
		pte_t* store=0;
f0103499:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
		struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
f01034a0:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f01034a3:	89 44 24 08          	mov    %eax,0x8(%esp)
f01034a7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01034ab:	8b 47 60             	mov    0x60(%edi),%eax
f01034ae:	89 04 24             	mov    %eax,(%esp)
f01034b1:	e8 bf de ff ff       	call   f0101375 <page_lookup>
		if(store!=NULL)
f01034b6:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01034b9:	85 c0                	test   %eax,%eax
f01034bb:	74 1b                	je     f01034d8 <user_mem_check+0x67>
		{
			//cprintf("pte!=NULL %08x\r\n",*store);
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f01034bd:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01034c0:	89 ca                	mov    %ecx,%edx
f01034c2:	23 10                	and    (%eax),%edx
f01034c4:	39 d1                	cmp    %edx,%ecx
f01034c6:	75 08                	jne    f01034d0 <user_mem_check+0x5f>
f01034c8:	81 fe 00 00 80 ef    	cmp    $0xef800000,%esi
f01034ce:	76 10                	jbe    f01034e0 <user_mem_check+0x6f>
			   {
				//cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f01034d0:	89 35 3c 72 1c f0    	mov    %esi,0xf01c723c
				break;
f01034d6:	eb 1d                	jmp    f01034f5 <user_mem_check+0x84>
			}
			else
			{
				//cprintf("no pte!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f01034d8:	89 35 3c 72 1c f0    	mov    %esi,0xf01c723c
				break;
f01034de:	eb 15                	jmp    f01034f5 <user_mem_check+0x84>
			}
		    i=ROUNDDOWN(i,PGSIZE);
f01034e0:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
f01034e6:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f01034ec:	89 de                	mov    %ebx,%esi
f01034ee:	3b 5d d0             	cmp    -0x30(%ebp),%ebx
f01034f1:	72 a6                	jb     f0103499 <user_mem_check+0x28>
f01034f3:	eb 0e                	jmp    f0103503 <user_mem_check+0x92>
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
			   {
				//cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
				break;
f01034f5:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f01034fa:	eb 0c                	jmp    f0103508 <user_mem_check+0x97>
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
f01034fc:	b8 00 00 00 00       	mov    $0x0,%eax
f0103501:	eb 05                	jmp    f0103508 <user_mem_check+0x97>
f0103503:	b8 00 00 00 00       	mov    $0x0,%eax
			}
		    i=ROUNDDOWN(i,PGSIZE);
		}

	return flag;
}
f0103508:	83 c4 3c             	add    $0x3c,%esp
f010350b:	5b                   	pop    %ebx
f010350c:	5e                   	pop    %esi
f010350d:	5f                   	pop    %edi
f010350e:	5d                   	pop    %ebp
f010350f:	c3                   	ret    

f0103510 <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f0103510:	55                   	push   %ebp
f0103511:	89 e5                	mov    %esp,%ebp
f0103513:	53                   	push   %ebx
f0103514:	83 ec 14             	sub    $0x14,%esp
f0103517:	8b 5d 08             	mov    0x8(%ebp),%ebx
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
f010351a:	8b 45 14             	mov    0x14(%ebp),%eax
f010351d:	83 c8 04             	or     $0x4,%eax
f0103520:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103524:	8b 45 10             	mov    0x10(%ebp),%eax
f0103527:	89 44 24 08          	mov    %eax,0x8(%esp)
f010352b:	8b 45 0c             	mov    0xc(%ebp),%eax
f010352e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103532:	89 1c 24             	mov    %ebx,(%esp)
f0103535:	e8 37 ff ff ff       	call   f0103471 <user_mem_check>
f010353a:	85 c0                	test   %eax,%eax
f010353c:	79 24                	jns    f0103562 <user_mem_assert+0x52>
		cprintf(".%08x. user_mem_check assertion failure for "
f010353e:	a1 3c 72 1c f0       	mov    0xf01c723c,%eax
f0103543:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103547:	8b 43 48             	mov    0x48(%ebx),%eax
f010354a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010354e:	c7 04 24 d8 79 10 f0 	movl   $0xf01079d8,(%esp)
f0103555:	e8 2c 09 00 00       	call   f0103e86 <cprintf>
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
f010355a:	89 1c 24             	mov    %ebx,(%esp)
f010355d:	e8 72 06 00 00       	call   f0103bd4 <env_destroy>
	}
}
f0103562:	83 c4 14             	add    $0x14,%esp
f0103565:	5b                   	pop    %ebx
f0103566:	5d                   	pop    %ebp
f0103567:	c3                   	ret    

f0103568 <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f0103568:	55                   	push   %ebp
f0103569:	89 e5                	mov    %esp,%ebp
f010356b:	56                   	push   %esi
f010356c:	53                   	push   %ebx
f010356d:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f0103570:	85 c0                	test   %eax,%eax
f0103572:	75 1a                	jne    f010358e <envid2env+0x26>
		*env_store = curenv;
f0103574:	e8 1a 30 00 00       	call   f0106593 <cpunum>
f0103579:	6b c0 74             	imul   $0x74,%eax,%eax
f010357c:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0103582:	8b 55 0c             	mov    0xc(%ebp),%edx
f0103585:	89 02                	mov    %eax,(%edx)
		return 0;
f0103587:	b8 00 00 00 00       	mov    $0x0,%eax
f010358c:	eb 72                	jmp    f0103600 <envid2env+0x98>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f010358e:	89 c3                	mov    %eax,%ebx
f0103590:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
f0103596:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f0103599:	03 1d 48 72 1c f0    	add    0xf01c7248,%ebx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f010359f:	83 7b 54 00          	cmpl   $0x0,0x54(%ebx)
f01035a3:	74 05                	je     f01035aa <envid2env+0x42>
f01035a5:	39 43 48             	cmp    %eax,0x48(%ebx)
f01035a8:	74 10                	je     f01035ba <envid2env+0x52>
		*env_store = 0;
f01035aa:	8b 45 0c             	mov    0xc(%ebp),%eax
f01035ad:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f01035b3:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01035b8:	eb 46                	jmp    f0103600 <envid2env+0x98>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f01035ba:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f01035be:	74 36                	je     f01035f6 <envid2env+0x8e>
f01035c0:	e8 ce 2f 00 00       	call   f0106593 <cpunum>
f01035c5:	6b c0 74             	imul   $0x74,%eax,%eax
f01035c8:	39 98 28 80 1c f0    	cmp    %ebx,-0xfe37fd8(%eax)
f01035ce:	74 26                	je     f01035f6 <envid2env+0x8e>
f01035d0:	8b 73 4c             	mov    0x4c(%ebx),%esi
f01035d3:	e8 bb 2f 00 00       	call   f0106593 <cpunum>
f01035d8:	6b c0 74             	imul   $0x74,%eax,%eax
f01035db:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f01035e1:	3b 70 48             	cmp    0x48(%eax),%esi
f01035e4:	74 10                	je     f01035f6 <envid2env+0x8e>
		*env_store = 0;
f01035e6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01035e9:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f01035ef:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01035f4:	eb 0a                	jmp    f0103600 <envid2env+0x98>
	}

	*env_store = e;
f01035f6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01035f9:	89 18                	mov    %ebx,(%eax)
	return 0;
f01035fb:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0103600:	5b                   	pop    %ebx
f0103601:	5e                   	pop    %esi
f0103602:	5d                   	pop    %ebp
f0103603:	c3                   	ret    

f0103604 <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f0103604:	55                   	push   %ebp
f0103605:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f0103607:	b8 00 13 12 f0       	mov    $0xf0121300,%eax
f010360c:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f010360f:	b8 23 00 00 00       	mov    $0x23,%eax
f0103614:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f0103616:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f0103618:	b0 10                	mov    $0x10,%al
f010361a:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f010361c:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f010361e:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f0103620:	ea 27 36 10 f0 08 00 	ljmp   $0x8,$0xf0103627
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f0103627:	b0 00                	mov    $0x0,%al
f0103629:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f010362c:	5d                   	pop    %ebp
f010362d:	c3                   	ret    

f010362e <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f010362e:	55                   	push   %ebp
f010362f:	89 e5                	mov    %esp,%ebp
f0103631:	56                   	push   %esi
f0103632:	53                   	push   %ebx
	// Set up envs array
	// LAB 3: Your code here.
	env_free_list = NULL;
	size_t i = NENV - 1;
	while(i+1) {
		envs[i].env_id = 0;
f0103633:	8b 35 48 72 1c f0    	mov    0xf01c7248,%esi
f0103639:	8d 86 84 ef 01 00    	lea    0x1ef84(%esi),%eax
f010363f:	ba 00 04 00 00       	mov    $0x400,%edx
f0103644:	b9 00 00 00 00       	mov    $0x0,%ecx
f0103649:	89 c3                	mov    %eax,%ebx
f010364b:	c7 40 48 00 00 00 00 	movl   $0x0,0x48(%eax)
		envs[i].env_link = env_free_list;
f0103652:	89 48 44             	mov    %ecx,0x44(%eax)
f0103655:	83 e8 7c             	sub    $0x7c,%eax
{
	// Set up envs array
	// LAB 3: Your code here.
	env_free_list = NULL;
	size_t i = NENV - 1;
	while(i+1) {
f0103658:	83 ea 01             	sub    $0x1,%edx
f010365b:	74 04                	je     f0103661 <env_init+0x33>
		envs[i].env_id = 0;
		envs[i].env_link = env_free_list;
		env_free_list = &envs[i];
f010365d:	89 d9                	mov    %ebx,%ecx
f010365f:	eb e8                	jmp    f0103649 <env_init+0x1b>
f0103661:	89 35 4c 72 1c f0    	mov    %esi,0xf01c724c
		i = i-1;
	}
	//env_free_list = envs; // this line of code changing like this ugly looks just fit fuck grade sh,too useless
	// Per-CPU part of the initialization
	env_init_percpu();
f0103667:	e8 98 ff ff ff       	call   f0103604 <env_init_percpu>
}
f010366c:	5b                   	pop    %ebx
f010366d:	5e                   	pop    %esi
f010366e:	5d                   	pop    %ebp
f010366f:	c3                   	ret    

f0103670 <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f0103670:	55                   	push   %ebp
f0103671:	89 e5                	mov    %esp,%ebp
f0103673:	56                   	push   %esi
f0103674:	53                   	push   %ebx
f0103675:	83 ec 10             	sub    $0x10,%esp
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list)){
f0103678:	8b 1d 4c 72 1c f0    	mov    0xf01c724c,%ebx
f010367e:	85 db                	test   %ebx,%ebx
f0103680:	0f 84 5b 01 00 00    	je     f01037e1 <env_alloc+0x171>
{
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f0103686:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f010368d:	e8 94 da ff ff       	call   f0101126 <page_alloc>
f0103692:	85 c0                	test   %eax,%eax
f0103694:	0f 84 4e 01 00 00    	je     f01037e8 <env_alloc+0x178>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010369a:	89 c2                	mov    %eax,%edx
f010369c:	2b 15 90 7e 1c f0    	sub    0xf01c7e90,%edx
f01036a2:	c1 fa 03             	sar    $0x3,%edx
f01036a5:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01036a8:	89 d1                	mov    %edx,%ecx
f01036aa:	c1 e9 0c             	shr    $0xc,%ecx
f01036ad:	3b 0d 88 7e 1c f0    	cmp    0xf01c7e88,%ecx
f01036b3:	72 20                	jb     f01036d5 <env_alloc+0x65>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01036b5:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01036b9:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f01036c0:	f0 
f01036c1:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01036c8:	00 
f01036c9:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f01036d0:	e8 6b c9 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01036d5:	81 ea 00 00 00 10    	sub    $0x10000000,%edx
f01036db:	89 53 60             	mov    %edx,0x60(%ebx)
	//	is an exception -- you need to increment env_pgdir's
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
f01036de:	ba ec 0e 00 00       	mov    $0xeec,%edx
	for(i=PDX(UTOP);i<1024;i++){
		e->env_pgdir[i] = kern_pgdir[i];
f01036e3:	8b 0d 8c 7e 1c f0    	mov    0xf01c7e8c,%ecx
f01036e9:	8b 34 11             	mov    (%ecx,%edx,1),%esi
f01036ec:	8b 4b 60             	mov    0x60(%ebx),%ecx
f01036ef:	89 34 11             	mov    %esi,(%ecx,%edx,1)
f01036f2:	83 c2 04             	add    $0x4,%edx
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
	for(i=PDX(UTOP);i<1024;i++){
f01036f5:	81 fa 00 10 00 00    	cmp    $0x1000,%edx
f01036fb:	75 e6                	jne    f01036e3 <env_alloc+0x73>
		e->env_pgdir[i] = kern_pgdir[i];
	}
	p->pp_ref++;
f01036fd:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f0103702:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103705:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010370a:	77 20                	ja     f010372c <env_alloc+0xbc>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010370c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103710:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0103717:	f0 
f0103718:	c7 44 24 04 c8 00 00 	movl   $0xc8,0x4(%esp)
f010371f:	00 
f0103720:	c7 04 24 21 7d 10 f0 	movl   $0xf0107d21,(%esp)
f0103727:	e8 14 c9 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f010372c:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f0103732:	83 ca 05             	or     $0x5,%edx
f0103735:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	if ((r = env_setup_vm(e)) < 0){
		return r;
	}

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f010373b:	8b 43 48             	mov    0x48(%ebx),%eax
f010373e:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f0103743:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f0103748:	ba 00 10 00 00       	mov    $0x1000,%edx
f010374d:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f0103750:	89 da                	mov    %ebx,%edx
f0103752:	2b 15 48 72 1c f0    	sub    0xf01c7248,%edx
f0103758:	c1 fa 02             	sar    $0x2,%edx
f010375b:	69 d2 df 7b ef bd    	imul   $0xbdef7bdf,%edx,%edx
f0103761:	09 d0                	or     %edx,%eax
f0103763:	89 43 48             	mov    %eax,0x48(%ebx)
	// Set the basic status variables.
	e->env_parent_id = parent_id;
f0103766:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103769:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f010376c:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f0103773:	c7 43 54 02 00 00 00 	movl   $0x2,0x54(%ebx)
	e->env_runs = 0;
f010377a:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f0103781:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f0103788:	00 
f0103789:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0103790:	00 
f0103791:	89 1c 24             	mov    %ebx,(%esp)
f0103794:	e8 60 27 00 00       	call   f0105ef9 <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f0103799:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f010379f:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f01037a5:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f01037ab:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f01037b2:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)
	// You will set e->env_tf.tf_eip later.

	// Enable interrupts while in user mode.
	// LAB 4: Your code here.
	e->env_tf.tf_eflags |= FL_IF;
f01037b8:	81 4b 38 00 02 00 00 	orl    $0x200,0x38(%ebx)
	// Clear the page fault handler until user installs one.
	e->env_pgfault_upcall = 0;
f01037bf:	c7 43 64 00 00 00 00 	movl   $0x0,0x64(%ebx)

	// Also clear the IPC receiving flag.
	e->env_ipc_recving = 0;
f01037c6:	c7 43 68 00 00 00 00 	movl   $0x0,0x68(%ebx)

	// commit the allocation
	env_free_list = e->env_link;
f01037cd:	8b 43 44             	mov    0x44(%ebx),%eax
f01037d0:	a3 4c 72 1c f0       	mov    %eax,0xf01c724c
	*newenv_store = e;
f01037d5:	8b 45 08             	mov    0x8(%ebp),%eax
f01037d8:	89 18                	mov    %ebx,(%eax)

	// cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
f01037da:	b8 00 00 00 00       	mov    $0x0,%eax
f01037df:	eb 0c                	jmp    f01037ed <env_alloc+0x17d>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list)){
		return -E_NO_FREE_ENV;
f01037e1:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f01037e6:	eb 05                	jmp    f01037ed <env_alloc+0x17d>
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f01037e8:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	env_free_list = e->env_link;
	*newenv_store = e;

	// cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}
f01037ed:	83 c4 10             	add    $0x10,%esp
f01037f0:	5b                   	pop    %ebx
f01037f1:	5e                   	pop    %esi
f01037f2:	5d                   	pop    %ebp
f01037f3:	c3                   	ret    

f01037f4 <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f01037f4:	55                   	push   %ebp
f01037f5:	89 e5                	mov    %esp,%ebp
f01037f7:	57                   	push   %edi
f01037f8:	56                   	push   %esi
f01037f9:	53                   	push   %ebx
f01037fa:	83 ec 3c             	sub    $0x3c,%esp
	// LAB 3: Your code here.
	// If this is the file server (type == ENV_TYPE_FS) give it I/O privileges.
	// LAB 5: Your code here.
	struct Env * env;
	int test = env_alloc(&env,0);
f01037fd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0103804:	00 
f0103805:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0103808:	89 04 24             	mov    %eax,(%esp)
f010380b:	e8 60 fe ff ff       	call   f0103670 <env_alloc>
	if(test==0){
f0103810:	85 c0                	test   %eax,%eax
f0103812:	0f 85 cd 01 00 00    	jne    f01039e5 <env_create+0x1f1>
		load_icode(env,binary,size);
f0103818:	8b 75 e4             	mov    -0x1c(%ebp),%esi
	//  this function?
	//
	//  You must also do something with the program's entry point,
	//  to make sure that the environment starts executing there.
	//  What?  (See env_run() and env_pop_tf() below.)
	 lcr3(PADDR(e->env_pgdir));
f010381b:	8b 46 60             	mov    0x60(%esi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010381e:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103823:	77 20                	ja     f0103845 <env_create+0x51>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103825:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103829:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0103830:	f0 
f0103831:	c7 44 24 04 65 01 00 	movl   $0x165,0x4(%esp)
f0103838:	00 
f0103839:	c7 04 24 21 7d 10 f0 	movl   $0xf0107d21,(%esp)
f0103840:	e8 fb c7 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103845:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f010384a:	0f 22 d8             	mov    %eax,%cr3

    	struct Elf* ELFHDR = (struct Elf*)binary;

    	assert(ELFHDR->e_magic == ELF_MAGIC);
f010384d:	8b 45 08             	mov    0x8(%ebp),%eax
f0103850:	81 38 7f 45 4c 46    	cmpl   $0x464c457f,(%eax)
f0103856:	74 24                	je     f010387c <env_create+0x88>
f0103858:	c7 44 24 0c 2c 7d 10 	movl   $0xf0107d2c,0xc(%esp)
f010385f:	f0 
f0103860:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0103867:	f0 
f0103868:	c7 44 24 04 69 01 00 	movl   $0x169,0x4(%esp)
f010386f:	00 
f0103870:	c7 04 24 21 7d 10 f0 	movl   $0xf0107d21,(%esp)
f0103877:	e8 c4 c7 ff ff       	call   f0100040 <_panic>
   	 struct Proghdr *ph, *eph;

   	 uint8_t* p_src = NULL, *p_dst = NULL;
    	uint32_t cnt = 0;

    	ph = (struct Proghdr *) (binary + ELFHDR->e_phoff);
f010387c:	8b 45 08             	mov    0x8(%ebp),%eax
f010387f:	89 c7                	mov    %eax,%edi
f0103881:	03 78 1c             	add    0x1c(%eax),%edi
    	eph = ph + ELFHDR->e_phnum;
f0103884:	0f b7 40 2c          	movzwl 0x2c(%eax),%eax
f0103888:	c1 e0 05             	shl    $0x5,%eax
f010388b:	01 f8                	add    %edi,%eax
f010388d:	89 45 d4             	mov    %eax,-0x2c(%ebp)

    	for(; ph < eph; ph++)
f0103890:	39 c7                	cmp    %eax,%edi
f0103892:	0f 83 a6 00 00 00    	jae    f010393e <env_create+0x14a>
   	 {
        		if(ph->p_type == ELF_PROG_LOAD)
f0103898:	83 3f 01             	cmpl   $0x1,(%edi)
f010389b:	0f 85 91 00 00 00    	jne    f0103932 <env_create+0x13e>
        		{
            			region_alloc(e, (void*)ph->p_va, ph->p_memsz);
f01038a1:	8b 47 08             	mov    0x8(%edi),%eax
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f01038a4:	89 c3                	mov    %eax,%ebx
f01038a6:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f01038ac:	03 47 14             	add    0x14(%edi),%eax
f01038af:	05 ff 0f 00 00       	add    $0xfff,%eax
f01038b4:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01038b9:	39 c3                	cmp    %eax,%ebx
f01038bb:	73 59                	jae    f0103916 <env_create+0x122>
f01038bd:	89 7d d0             	mov    %edi,-0x30(%ebp)
f01038c0:	89 c7                	mov    %eax,%edi
		p = (struct Page*)page_alloc(1);
f01038c2:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01038c9:	e8 58 d8 ff ff       	call   f0101126 <page_alloc>
		if(p==NULL)
f01038ce:	85 c0                	test   %eax,%eax
f01038d0:	75 1c                	jne    f01038ee <env_create+0xfa>
			panic("Memory out!");
f01038d2:	c7 44 24 08 49 7d 10 	movl   $0xf0107d49,0x8(%esp)
f01038d9:	f0 
f01038da:	c7 44 24 04 2c 01 00 	movl   $0x12c,0x4(%esp)
f01038e1:	00 
f01038e2:	c7 04 24 21 7d 10 f0 	movl   $0xf0107d21,(%esp)
f01038e9:	e8 52 c7 ff ff       	call   f0100040 <_panic>
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
f01038ee:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01038f5:	00 
f01038f6:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f01038fa:	89 44 24 04          	mov    %eax,0x4(%esp)
f01038fe:	8b 46 60             	mov    0x60(%esi),%eax
f0103901:	89 04 24             	mov    %eax,(%esp)
f0103904:	e8 57 db ff ff       	call   f0101460 <page_insert>
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f0103909:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f010390f:	39 fb                	cmp    %edi,%ebx
f0103911:	72 af                	jb     f01038c2 <env_create+0xce>
f0103913:	8b 7d d0             	mov    -0x30(%ebp),%edi
    	for(; ph < eph; ph++)
   	 {
        		if(ph->p_type == ELF_PROG_LOAD)
        		{
            			region_alloc(e, (void*)ph->p_va, ph->p_memsz);
           			 memmove((void*)ph->p_va, (void*)binary + ph->p_offset, ph->p_filesz);
f0103916:	8b 47 10             	mov    0x10(%edi),%eax
f0103919:	89 44 24 08          	mov    %eax,0x8(%esp)
f010391d:	8b 45 08             	mov    0x8(%ebp),%eax
f0103920:	03 47 04             	add    0x4(%edi),%eax
f0103923:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103927:	8b 47 08             	mov    0x8(%edi),%eax
f010392a:	89 04 24             	mov    %eax,(%esp)
f010392d:	e8 14 26 00 00       	call   f0105f46 <memmove>
    	uint32_t cnt = 0;

    	ph = (struct Proghdr *) (binary + ELFHDR->e_phoff);
    	eph = ph + ELFHDR->e_phnum;

    	for(; ph < eph; ph++)
f0103932:	83 c7 20             	add    $0x20,%edi
f0103935:	39 7d d4             	cmp    %edi,-0x2c(%ebp)
f0103938:	0f 87 5a ff ff ff    	ja     f0103898 <env_create+0xa4>
        		{
            			region_alloc(e, (void*)ph->p_va, ph->p_memsz);
           			 memmove((void*)ph->p_va, (void*)binary + ph->p_offset, ph->p_filesz);
       		 }
   	 }
    	e->env_tf.tf_eip = ELFHDR->e_entry;
f010393e:	8b 45 08             	mov    0x8(%ebp),%eax
f0103941:	8b 40 18             	mov    0x18(%eax),%eax
f0103944:	89 46 30             	mov    %eax,0x30(%esi)
    	// Now map one page for the program's initial stack
    	// at virtual address USTACKTOP - PGSIZE.

    	// LAB 3: Your code here.
    	struct Page* stack_page = (struct Page*)page_alloc(1);
f0103947:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f010394e:	e8 d3 d7 ff ff       	call   f0101126 <page_alloc>
   	if(stack_page == 0)
f0103953:	85 c0                	test   %eax,%eax
f0103955:	75 24                	jne    f010397b <env_create+0x187>
        		panic("load_icode(): %e", -E_NO_MEM);
f0103957:	c7 44 24 0c fc ff ff 	movl   $0xfffffffc,0xc(%esp)
f010395e:	ff 
f010395f:	c7 44 24 08 55 7d 10 	movl   $0xf0107d55,0x8(%esp)
f0103966:	f0 
f0103967:	c7 44 24 04 82 01 00 	movl   $0x182,0x4(%esp)
f010396e:	00 
f010396f:	c7 04 24 21 7d 10 f0 	movl   $0xf0107d21,(%esp)
f0103976:	e8 c5 c6 ff ff       	call   f0100040 <_panic>
        	//cprintf("except page_insert Complete in env_create\n");
	//readline("type_anything\n");
    	page_insert(e->env_pgdir, stack_page, (void*)(USTACKTOP - PGSIZE), PTE_W | PTE_U);
f010397b:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0103982:	00 
f0103983:	c7 44 24 08 00 d0 bf 	movl   $0xeebfd000,0x8(%esp)
f010398a:	ee 
f010398b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010398f:	8b 46 60             	mov    0x60(%esi),%eax
f0103992:	89 04 24             	mov    %eax,(%esp)
f0103995:	e8 c6 da ff ff       	call   f0101460 <page_insert>

    	lcr3(PADDR(kern_pgdir));
f010399a:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010399f:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01039a4:	77 20                	ja     f01039c6 <env_create+0x1d2>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01039a6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01039aa:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f01039b1:	f0 
f01039b2:	c7 44 24 04 87 01 00 	movl   $0x187,0x4(%esp)
f01039b9:	00 
f01039ba:	c7 04 24 21 7d 10 f0 	movl   $0xf0107d21,(%esp)
f01039c1:	e8 7a c6 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01039c6:	05 00 00 00 10       	add    $0x10000000,%eax
f01039cb:	0f 22 d8             	mov    %eax,%cr3
	// LAB 5: Your code here.
	struct Env * env;
	int test = env_alloc(&env,0);
	if(test==0){
		load_icode(env,binary,size);
		env->env_type = type;
f01039ce:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01039d1:	8b 55 10             	mov    0x10(%ebp),%edx
f01039d4:	89 50 50             	mov    %edx,0x50(%eax)
		if(type==ENV_TYPE_FS){
f01039d7:	83 fa 02             	cmp    $0x2,%edx
f01039da:	75 25                	jne    f0103a01 <env_create+0x20d>
			env->env_tf.tf_eflags |= FL_IOPL_3;
f01039dc:	81 48 38 00 30 00 00 	orl    $0x3000,0x38(%eax)
f01039e3:	eb 1c                	jmp    f0103a01 <env_create+0x20d>
		}else{
			env->env_tf.tf_eflags |=FL_IOPL_0;
		}
	}else{
		panic("create env fails !\n");
f01039e5:	c7 44 24 08 66 7d 10 	movl   $0xf0107d66,0x8(%esp)
f01039ec:	f0 
f01039ed:	c7 44 24 04 c1 01 00 	movl   $0x1c1,0x4(%esp)
f01039f4:	00 
f01039f5:	c7 04 24 21 7d 10 f0 	movl   $0xf0107d21,(%esp)
f01039fc:	e8 3f c6 ff ff       	call   f0100040 <_panic>
	}
}
f0103a01:	83 c4 3c             	add    $0x3c,%esp
f0103a04:	5b                   	pop    %ebx
f0103a05:	5e                   	pop    %esi
f0103a06:	5f                   	pop    %edi
f0103a07:	5d                   	pop    %ebp
f0103a08:	c3                   	ret    

f0103a09 <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0103a09:	55                   	push   %ebp
f0103a0a:	89 e5                	mov    %esp,%ebp
f0103a0c:	57                   	push   %edi
f0103a0d:	56                   	push   %esi
f0103a0e:	53                   	push   %ebx
f0103a0f:	83 ec 2c             	sub    $0x2c,%esp
f0103a12:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f0103a15:	e8 79 2b 00 00       	call   f0106593 <cpunum>
f0103a1a:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a1d:	39 b8 28 80 1c f0    	cmp    %edi,-0xfe37fd8(%eax)
f0103a23:	74 09                	je     f0103a2e <env_free+0x25>
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0103a25:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0103a2c:	eb 36                	jmp    f0103a64 <env_free+0x5b>

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
		lcr3(PADDR(kern_pgdir));
f0103a2e:	a1 8c 7e 1c f0       	mov    0xf01c7e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103a33:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103a38:	77 20                	ja     f0103a5a <env_free+0x51>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103a3a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103a3e:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0103a45:	f0 
f0103a46:	c7 44 24 04 d3 01 00 	movl   $0x1d3,0x4(%esp)
f0103a4d:	00 
f0103a4e:	c7 04 24 21 7d 10 f0 	movl   $0xf0107d21,(%esp)
f0103a55:	e8 e6 c5 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103a5a:	05 00 00 00 10       	add    $0x10000000,%eax
f0103a5f:	0f 22 d8             	mov    %eax,%cr3
f0103a62:	eb c1                	jmp    f0103a25 <env_free+0x1c>
f0103a64:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0103a67:	89 c8                	mov    %ecx,%eax
f0103a69:	c1 e0 02             	shl    $0x2,%eax
f0103a6c:	89 45 dc             	mov    %eax,-0x24(%ebp)
	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f0103a6f:	8b 47 60             	mov    0x60(%edi),%eax
f0103a72:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f0103a75:	f7 c6 01 00 00 00    	test   $0x1,%esi
f0103a7b:	0f 84 b7 00 00 00    	je     f0103b38 <env_free+0x12f>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f0103a81:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103a87:	89 f0                	mov    %esi,%eax
f0103a89:	c1 e8 0c             	shr    $0xc,%eax
f0103a8c:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103a8f:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f0103a95:	72 20                	jb     f0103ab7 <env_free+0xae>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103a97:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0103a9b:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0103aa2:	f0 
f0103aa3:	c7 44 24 04 e2 01 00 	movl   $0x1e2,0x4(%esp)
f0103aaa:	00 
f0103aab:	c7 04 24 21 7d 10 f0 	movl   $0xf0107d21,(%esp)
f0103ab2:	e8 89 c5 ff ff       	call   f0100040 <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103ab7:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103aba:	c1 e0 16             	shl    $0x16,%eax
f0103abd:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103ac0:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f0103ac5:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f0103acc:	01 
f0103acd:	74 17                	je     f0103ae6 <env_free+0xdd>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103acf:	89 d8                	mov    %ebx,%eax
f0103ad1:	c1 e0 0c             	shl    $0xc,%eax
f0103ad4:	0b 45 e4             	or     -0x1c(%ebp),%eax
f0103ad7:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103adb:	8b 47 60             	mov    0x60(%edi),%eax
f0103ade:	89 04 24             	mov    %eax,(%esp)
f0103ae1:	e8 31 d9 ff ff       	call   f0101417 <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103ae6:	83 c3 01             	add    $0x1,%ebx
f0103ae9:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f0103aef:	75 d4                	jne    f0103ac5 <env_free+0xbc>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f0103af1:	8b 47 60             	mov    0x60(%edi),%eax
f0103af4:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103af7:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103afe:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103b01:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f0103b07:	72 1c                	jb     f0103b25 <env_free+0x11c>
		panic("pa2page called with invalid pa");
f0103b09:	c7 44 24 08 d4 73 10 	movl   $0xf01073d4,0x8(%esp)
f0103b10:	f0 
f0103b11:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103b18:	00 
f0103b19:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f0103b20:	e8 1b c5 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103b25:	a1 90 7e 1c f0       	mov    0xf01c7e90,%eax
f0103b2a:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103b2d:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0103b30:	89 04 24             	mov    %eax,(%esp)
f0103b33:	e8 88 d6 ff ff       	call   f01011c0 <page_decref>
	// Note the environment's demise.
	// cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103b38:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f0103b3c:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f0103b43:	0f 85 1b ff ff ff    	jne    f0103a64 <env_free+0x5b>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f0103b49:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103b4c:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103b51:	77 20                	ja     f0103b73 <env_free+0x16a>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103b53:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103b57:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0103b5e:	f0 
f0103b5f:	c7 44 24 04 f0 01 00 	movl   $0x1f0,0x4(%esp)
f0103b66:	00 
f0103b67:	c7 04 24 21 7d 10 f0 	movl   $0xf0107d21,(%esp)
f0103b6e:	e8 cd c4 ff ff       	call   f0100040 <_panic>
	e->env_pgdir = 0;
f0103b73:	c7 47 60 00 00 00 00 	movl   $0x0,0x60(%edi)
	return (physaddr_t)kva - KERNBASE;
f0103b7a:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103b7f:	c1 e8 0c             	shr    $0xc,%eax
f0103b82:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f0103b88:	72 1c                	jb     f0103ba6 <env_free+0x19d>
		panic("pa2page called with invalid pa");
f0103b8a:	c7 44 24 08 d4 73 10 	movl   $0xf01073d4,0x8(%esp)
f0103b91:	f0 
f0103b92:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103b99:	00 
f0103b9a:	c7 04 24 19 7a 10 f0 	movl   $0xf0107a19,(%esp)
f0103ba1:	e8 9a c4 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103ba6:	8b 15 90 7e 1c f0    	mov    0xf01c7e90,%edx
f0103bac:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f0103baf:	89 04 24             	mov    %eax,(%esp)
f0103bb2:	e8 09 d6 ff ff       	call   f01011c0 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f0103bb7:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f0103bbe:	a1 4c 72 1c f0       	mov    0xf01c724c,%eax
f0103bc3:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f0103bc6:	89 3d 4c 72 1c f0    	mov    %edi,0xf01c724c
}
f0103bcc:	83 c4 2c             	add    $0x2c,%esp
f0103bcf:	5b                   	pop    %ebx
f0103bd0:	5e                   	pop    %esi
f0103bd1:	5f                   	pop    %edi
f0103bd2:	5d                   	pop    %ebp
f0103bd3:	c3                   	ret    

f0103bd4 <env_destroy>:
// If e was the current env, then runs a new environment (and does not return
// to the caller).
//
void
env_destroy(struct Env *e)
{
f0103bd4:	55                   	push   %ebp
f0103bd5:	89 e5                	mov    %esp,%ebp
f0103bd7:	53                   	push   %ebx
f0103bd8:	83 ec 14             	sub    $0x14,%esp
f0103bdb:	8b 5d 08             	mov    0x8(%ebp),%ebx
	// If e is currently running on other CPUs, we change its state to
	// ENV_DYING. A zombie environment will be freed the next time
	// it traps to the kernel.
	if (e->env_status == ENV_RUNNING && curenv != e) {
f0103bde:	83 7b 54 03          	cmpl   $0x3,0x54(%ebx)
f0103be2:	75 19                	jne    f0103bfd <env_destroy+0x29>
f0103be4:	e8 aa 29 00 00       	call   f0106593 <cpunum>
f0103be9:	6b c0 74             	imul   $0x74,%eax,%eax
f0103bec:	39 98 28 80 1c f0    	cmp    %ebx,-0xfe37fd8(%eax)
f0103bf2:	74 09                	je     f0103bfd <env_destroy+0x29>
		e->env_status = ENV_DYING;
f0103bf4:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
		return;
f0103bfb:	eb 2f                	jmp    f0103c2c <env_destroy+0x58>
	}

	env_free(e);
f0103bfd:	89 1c 24             	mov    %ebx,(%esp)
f0103c00:	e8 04 fe ff ff       	call   f0103a09 <env_free>

	if (curenv == e) {
f0103c05:	e8 89 29 00 00       	call   f0106593 <cpunum>
f0103c0a:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c0d:	39 98 28 80 1c f0    	cmp    %ebx,-0xfe37fd8(%eax)
f0103c13:	75 17                	jne    f0103c2c <env_destroy+0x58>
		curenv = NULL;
f0103c15:	e8 79 29 00 00       	call   f0106593 <cpunum>
f0103c1a:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c1d:	c7 80 28 80 1c f0 00 	movl   $0x0,-0xfe37fd8(%eax)
f0103c24:	00 00 00 
		sched_yield();
f0103c27:	e8 84 0f 00 00       	call   f0104bb0 <sched_yield>
	}
}
f0103c2c:	83 c4 14             	add    $0x14,%esp
f0103c2f:	5b                   	pop    %ebx
f0103c30:	5d                   	pop    %ebp
f0103c31:	c3                   	ret    

f0103c32 <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f0103c32:	55                   	push   %ebp
f0103c33:	89 e5                	mov    %esp,%ebp
f0103c35:	53                   	push   %ebx
f0103c36:	83 ec 14             	sub    $0x14,%esp
	// Record the CPU we are running on for user-space debugging
	curenv->env_cpunum = cpunum();
f0103c39:	e8 55 29 00 00       	call   f0106593 <cpunum>
f0103c3e:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c41:	8b 98 28 80 1c f0    	mov    -0xfe37fd8(%eax),%ebx
f0103c47:	e8 47 29 00 00       	call   f0106593 <cpunum>
f0103c4c:	89 43 5c             	mov    %eax,0x5c(%ebx)

	__asm __volatile("movl %0,%%esp\n"
f0103c4f:	8b 65 08             	mov    0x8(%ebp),%esp
f0103c52:	61                   	popa   
f0103c53:	07                   	pop    %es
f0103c54:	1f                   	pop    %ds
f0103c55:	83 c4 08             	add    $0x8,%esp
f0103c58:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f0103c59:	c7 44 24 08 7a 7d 10 	movl   $0xf0107d7a,0x8(%esp)
f0103c60:	f0 
f0103c61:	c7 44 24 04 26 02 00 	movl   $0x226,0x4(%esp)
f0103c68:	00 
f0103c69:	c7 04 24 21 7d 10 f0 	movl   $0xf0107d21,(%esp)
f0103c70:	e8 cb c3 ff ff       	call   f0100040 <_panic>

f0103c75 <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0103c75:	55                   	push   %ebp
f0103c76:	89 e5                	mov    %esp,%ebp
f0103c78:	53                   	push   %ebx
f0103c79:	83 ec 14             	sub    $0x14,%esp
f0103c7c:	8b 5d 08             	mov    0x8(%ebp),%ebx

	// Hint: This function loads the new environment's state from
	//	e->env_tf.  Go back through the code you wrote above
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.
	if(curenv!=NULL&& curenv->env_status==ENV_RUNNING)
f0103c7f:	e8 0f 29 00 00       	call   f0106593 <cpunum>
f0103c84:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c87:	83 b8 28 80 1c f0 00 	cmpl   $0x0,-0xfe37fd8(%eax)
f0103c8e:	74 29                	je     f0103cb9 <env_run+0x44>
f0103c90:	e8 fe 28 00 00       	call   f0106593 <cpunum>
f0103c95:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c98:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0103c9e:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0103ca2:	75 15                	jne    f0103cb9 <env_run+0x44>
		curenv->env_status = ENV_RUNNABLE;
f0103ca4:	e8 ea 28 00 00       	call   f0106593 <cpunum>
f0103ca9:	6b c0 74             	imul   $0x74,%eax,%eax
f0103cac:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0103cb2:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)

	curenv = e;
f0103cb9:	e8 d5 28 00 00       	call   f0106593 <cpunum>
f0103cbe:	6b c0 74             	imul   $0x74,%eax,%eax
f0103cc1:	89 98 28 80 1c f0    	mov    %ebx,-0xfe37fd8(%eax)
	int zero = 0;
	e->env_status = ENV_RUNNING;
f0103cc7:	c7 43 54 03 00 00 00 	movl   $0x3,0x54(%ebx)
	e->env_runs++;
f0103cce:	83 43 58 01          	addl   $0x1,0x58(%ebx)
	lcr3(PADDR(e->env_pgdir));
f0103cd2:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103cd5:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103cda:	77 20                	ja     f0103cfc <env_run+0x87>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103cdc:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103ce0:	c7 44 24 08 e8 6c 10 	movl   $0xf0106ce8,0x8(%esp)
f0103ce7:	f0 
f0103ce8:	c7 44 24 04 49 02 00 	movl   $0x249,0x4(%esp)
f0103cef:	00 
f0103cf0:	c7 04 24 21 7d 10 f0 	movl   $0xf0107d21,(%esp)
f0103cf7:	e8 44 c3 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103cfc:	05 00 00 00 10       	add    $0x10000000,%eax
f0103d01:	0f 22 d8             	mov    %eax,%cr3
}

static inline void
unlock_kernel(void)
{
	spin_unlock(&kernel_lock);
f0103d04:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f0103d0b:	e8 cc 2b 00 00       	call   f01068dc <spin_unlock>

	// Normally we wouldn't need to do this, but QEMU only runs
	// one CPU at a time and has a long time-slice.  Without the
	// pause, this CPU is likely to reacquire the lock before
	// another CPU has even been given a chance to acquire it.
	asm volatile("pause");
f0103d10:	f3 90                	pause  
	unlock_kernel();

	env_pop_tf(&e->env_tf);
f0103d12:	89 1c 24             	mov    %ebx,(%esp)
f0103d15:	e8 18 ff ff ff       	call   f0103c32 <env_pop_tf>

f0103d1a <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0103d1a:	55                   	push   %ebp
f0103d1b:	89 e5                	mov    %esp,%ebp
f0103d1d:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103d21:	ba 70 00 00 00       	mov    $0x70,%edx
f0103d26:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0103d27:	b2 71                	mov    $0x71,%dl
f0103d29:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0103d2a:	0f b6 c0             	movzbl %al,%eax
}
f0103d2d:	5d                   	pop    %ebp
f0103d2e:	c3                   	ret    

f0103d2f <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0103d2f:	55                   	push   %ebp
f0103d30:	89 e5                	mov    %esp,%ebp
f0103d32:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103d36:	ba 70 00 00 00       	mov    $0x70,%edx
f0103d3b:	ee                   	out    %al,(%dx)
f0103d3c:	b2 71                	mov    $0x71,%dl
f0103d3e:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103d41:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0103d42:	5d                   	pop    %ebp
f0103d43:	c3                   	ret    

f0103d44 <irq_setmask_8259A>:
		irq_setmask_8259A(irq_mask_8259A);
}

void
irq_setmask_8259A(uint16_t mask)
{
f0103d44:	55                   	push   %ebp
f0103d45:	89 e5                	mov    %esp,%ebp
f0103d47:	56                   	push   %esi
f0103d48:	53                   	push   %ebx
f0103d49:	83 ec 10             	sub    $0x10,%esp
f0103d4c:	8b 45 08             	mov    0x8(%ebp),%eax
	int i;
	irq_mask_8259A = mask;
f0103d4f:	66 a3 88 13 12 f0    	mov    %ax,0xf0121388
	if (!didinit)
f0103d55:	83 3d 50 72 1c f0 00 	cmpl   $0x0,0xf01c7250
f0103d5c:	74 4e                	je     f0103dac <irq_setmask_8259A+0x68>
f0103d5e:	89 c6                	mov    %eax,%esi
f0103d60:	ba 21 00 00 00       	mov    $0x21,%edx
f0103d65:	ee                   	out    %al,(%dx)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
f0103d66:	66 c1 e8 08          	shr    $0x8,%ax
f0103d6a:	b2 a1                	mov    $0xa1,%dl
f0103d6c:	ee                   	out    %al,(%dx)
	cprintf("enabled interrupts:");
f0103d6d:	c7 04 24 86 7d 10 f0 	movl   $0xf0107d86,(%esp)
f0103d74:	e8 0d 01 00 00       	call   f0103e86 <cprintf>
	for (i = 0; i < 16; i++)
f0103d79:	bb 00 00 00 00       	mov    $0x0,%ebx
		if (~mask & (1<<i))
f0103d7e:	0f b7 f6             	movzwl %si,%esi
f0103d81:	f7 d6                	not    %esi
f0103d83:	0f a3 de             	bt     %ebx,%esi
f0103d86:	73 10                	jae    f0103d98 <irq_setmask_8259A+0x54>
			cprintf(" %d", i);
f0103d88:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103d8c:	c7 04 24 1f 82 10 f0 	movl   $0xf010821f,(%esp)
f0103d93:	e8 ee 00 00 00       	call   f0103e86 <cprintf>
	if (!didinit)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
	cprintf("enabled interrupts:");
	for (i = 0; i < 16; i++)
f0103d98:	83 c3 01             	add    $0x1,%ebx
f0103d9b:	83 fb 10             	cmp    $0x10,%ebx
f0103d9e:	75 e3                	jne    f0103d83 <irq_setmask_8259A+0x3f>
		if (~mask & (1<<i))
			cprintf(" %d", i);
	cprintf("\n");
f0103da0:	c7 04 24 78 7d 10 f0 	movl   $0xf0107d78,(%esp)
f0103da7:	e8 da 00 00 00       	call   f0103e86 <cprintf>
}
f0103dac:	83 c4 10             	add    $0x10,%esp
f0103daf:	5b                   	pop    %ebx
f0103db0:	5e                   	pop    %esi
f0103db1:	5d                   	pop    %ebp
f0103db2:	c3                   	ret    

f0103db3 <pic_init>:

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
	didinit = 1;
f0103db3:	c7 05 50 72 1c f0 01 	movl   $0x1,0xf01c7250
f0103dba:	00 00 00 
f0103dbd:	ba 21 00 00 00       	mov    $0x21,%edx
f0103dc2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0103dc7:	ee                   	out    %al,(%dx)
f0103dc8:	b2 a1                	mov    $0xa1,%dl
f0103dca:	ee                   	out    %al,(%dx)
f0103dcb:	b2 20                	mov    $0x20,%dl
f0103dcd:	b8 11 00 00 00       	mov    $0x11,%eax
f0103dd2:	ee                   	out    %al,(%dx)
f0103dd3:	b2 21                	mov    $0x21,%dl
f0103dd5:	b8 20 00 00 00       	mov    $0x20,%eax
f0103dda:	ee                   	out    %al,(%dx)
f0103ddb:	b8 04 00 00 00       	mov    $0x4,%eax
f0103de0:	ee                   	out    %al,(%dx)
f0103de1:	b8 03 00 00 00       	mov    $0x3,%eax
f0103de6:	ee                   	out    %al,(%dx)
f0103de7:	b2 a0                	mov    $0xa0,%dl
f0103de9:	b8 11 00 00 00       	mov    $0x11,%eax
f0103dee:	ee                   	out    %al,(%dx)
f0103def:	b2 a1                	mov    $0xa1,%dl
f0103df1:	b8 28 00 00 00       	mov    $0x28,%eax
f0103df6:	ee                   	out    %al,(%dx)
f0103df7:	b8 02 00 00 00       	mov    $0x2,%eax
f0103dfc:	ee                   	out    %al,(%dx)
f0103dfd:	b8 01 00 00 00       	mov    $0x1,%eax
f0103e02:	ee                   	out    %al,(%dx)
f0103e03:	b2 20                	mov    $0x20,%dl
f0103e05:	b8 68 00 00 00       	mov    $0x68,%eax
f0103e0a:	ee                   	out    %al,(%dx)
f0103e0b:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103e10:	ee                   	out    %al,(%dx)
f0103e11:	b2 a0                	mov    $0xa0,%dl
f0103e13:	b8 68 00 00 00       	mov    $0x68,%eax
f0103e18:	ee                   	out    %al,(%dx)
f0103e19:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103e1e:	ee                   	out    %al,(%dx)
	outb(IO_PIC1, 0x0a);             /* read IRR by default */

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
f0103e1f:	0f b7 05 88 13 12 f0 	movzwl 0xf0121388,%eax
f0103e26:	66 83 f8 ff          	cmp    $0xffff,%ax
f0103e2a:	74 12                	je     f0103e3e <pic_init+0x8b>
static bool didinit;

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
f0103e2c:	55                   	push   %ebp
f0103e2d:	89 e5                	mov    %esp,%ebp
f0103e2f:	83 ec 18             	sub    $0x18,%esp

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
		irq_setmask_8259A(irq_mask_8259A);
f0103e32:	0f b7 c0             	movzwl %ax,%eax
f0103e35:	89 04 24             	mov    %eax,(%esp)
f0103e38:	e8 07 ff ff ff       	call   f0103d44 <irq_setmask_8259A>
}
f0103e3d:	c9                   	leave  
f0103e3e:	f3 c3                	repz ret 

f0103e40 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0103e40:	55                   	push   %ebp
f0103e41:	89 e5                	mov    %esp,%ebp
f0103e43:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0103e46:	8b 45 08             	mov    0x8(%ebp),%eax
f0103e49:	89 04 24             	mov    %eax,(%esp)
f0103e4c:	e8 bc c9 ff ff       	call   f010080d <cputchar>
	*cnt++;
}
f0103e51:	c9                   	leave  
f0103e52:	c3                   	ret    

f0103e53 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0103e53:	55                   	push   %ebp
f0103e54:	89 e5                	mov    %esp,%ebp
f0103e56:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0103e59:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0103e60:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103e63:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103e67:	8b 45 08             	mov    0x8(%ebp),%eax
f0103e6a:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103e6e:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0103e71:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e75:	c7 04 24 40 3e 10 f0 	movl   $0xf0103e40,(%esp)
f0103e7c:	e8 33 19 00 00       	call   f01057b4 <vprintfmt>
	return cnt;
}
f0103e81:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0103e84:	c9                   	leave  
f0103e85:	c3                   	ret    

f0103e86 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0103e86:	55                   	push   %ebp
f0103e87:	89 e5                	mov    %esp,%ebp
f0103e89:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0103e8c:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0103e8f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e93:	8b 45 08             	mov    0x8(%ebp),%eax
f0103e96:	89 04 24             	mov    %eax,(%esp)
f0103e99:	e8 b5 ff ff ff       	call   f0103e53 <vcprintf>
	va_end(ap);

	return cnt;
}
f0103e9e:	c9                   	leave  
f0103e9f:	c3                   	ret    

f0103ea0 <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f0103ea0:	55                   	push   %ebp
f0103ea1:	89 e5                	mov    %esp,%ebp
f0103ea3:	53                   	push   %ebx
f0103ea4:	83 ec 04             	sub    $0x4,%esp
	struct Taskstate* this_ts = &thiscpu->cpu_ts;
f0103ea7:	e8 e7 26 00 00       	call   f0106593 <cpunum>
f0103eac:	6b d8 74             	imul   $0x74,%eax,%ebx
	int CPUID = cpunum();
f0103eaf:	e8 df 26 00 00       	call   f0106593 <cpunum>
	this_ts->ts_esp0 = KSTACKTOP - CPUID * (KSTKGAP + KSTKSIZE);
f0103eb4:	89 c2                	mov    %eax,%edx
f0103eb6:	f7 da                	neg    %edx
f0103eb8:	c1 e2 10             	shl    $0x10,%edx
f0103ebb:	81 ea 00 00 40 10    	sub    $0x10400000,%edx
f0103ec1:	89 93 30 80 1c f0    	mov    %edx,-0xfe37fd0(%ebx)
	this_ts->ts_ss0 = GD_KD;
f0103ec7:	66 c7 83 34 80 1c f0 	movw   $0x10,-0xfe37fcc(%ebx)
f0103ece:	10 00 

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
	struct Taskstate* this_ts = &thiscpu->cpu_ts;
f0103ed0:	81 c3 2c 80 1c f0    	add    $0xf01c802c,%ebx
	int CPUID = cpunum();
	this_ts->ts_esp0 = KSTACKTOP - CPUID * (KSTKGAP + KSTKSIZE);
	this_ts->ts_ss0 = GD_KD;

	gdt[(GD_TSS0 >> 3) + CPUID] = SEG16(STS_T32A, (uint32_t) (this_ts),
f0103ed6:	8d 50 05             	lea    0x5(%eax),%edx
f0103ed9:	66 c7 04 d5 20 13 12 	movw   $0x68,-0xfedece0(,%edx,8)
f0103ee0:	f0 68 00 
f0103ee3:	66 89 1c d5 22 13 12 	mov    %bx,-0xfedecde(,%edx,8)
f0103eea:	f0 
f0103eeb:	89 d9                	mov    %ebx,%ecx
f0103eed:	c1 e9 10             	shr    $0x10,%ecx
f0103ef0:	88 0c d5 24 13 12 f0 	mov    %cl,-0xfedecdc(,%edx,8)
f0103ef7:	c6 04 d5 26 13 12 f0 	movb   $0x40,-0xfedecda(,%edx,8)
f0103efe:	40 
f0103eff:	c1 eb 18             	shr    $0x18,%ebx
f0103f02:	88 1c d5 27 13 12 f0 	mov    %bl,-0xfedecd9(,%edx,8)
					sizeof(struct Taskstate), 0);
	gdt[(GD_TSS0 >> 3) + CPUID].sd_s = 0;
f0103f09:	c6 04 d5 25 13 12 f0 	movb   $0x89,-0xfedecdb(,%edx,8)
f0103f10:	89 

	//cprintf("Loading GD_TSS_ %d\n", ((GD_TSS0>>3) + CPUID)<<3);

	ltr(GD_TSS0 + (CPUID << 3));
f0103f11:	8d 04 c5 28 00 00 00 	lea    0x28(,%eax,8),%eax
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f0103f18:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f0103f1b:	b8 8a 13 12 f0       	mov    $0xf012138a,%eax
f0103f20:	0f 01 18             	lidtl  (%eax)
	// bottom three bits are special; we leave them 0)
	ltr(GD_TSS0+(cpu_id<<3));

	// Load the IDT
	lidt(&idt_pd);*/
}
f0103f23:	83 c4 04             	add    $0x4,%esp
f0103f26:	5b                   	pop    %ebx
f0103f27:	5d                   	pop    %ebp
f0103f28:	c3                   	ret    

f0103f29 <trap_init>:
}


void
trap_init(void)
{
f0103f29:	55                   	push   %ebp
f0103f2a:	89 e5                	mov    %esp,%ebp
f0103f2c:	83 ec 08             	sub    $0x8,%esp
	extern struct Segdesc gdt[];
	SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);
f0103f2f:	b8 9a 4a 10 f0       	mov    $0xf0104a9a,%eax
f0103f34:	66 a3 60 72 1c f0    	mov    %ax,0xf01c7260
f0103f3a:	66 c7 05 62 72 1c f0 	movw   $0x8,0xf01c7262
f0103f41:	08 00 
f0103f43:	c6 05 64 72 1c f0 00 	movb   $0x0,0xf01c7264
f0103f4a:	c6 05 65 72 1c f0 8f 	movb   $0x8f,0xf01c7265
f0103f51:	c1 e8 10             	shr    $0x10,%eax
f0103f54:	66 a3 66 72 1c f0    	mov    %ax,0xf01c7266
	SETGATE(idt[2], 0, GD_KT, nmi_handler, 0);
f0103f5a:	b8 a4 4a 10 f0       	mov    $0xf0104aa4,%eax
f0103f5f:	66 a3 70 72 1c f0    	mov    %ax,0xf01c7270
f0103f65:	66 c7 05 72 72 1c f0 	movw   $0x8,0xf01c7272
f0103f6c:	08 00 
f0103f6e:	c6 05 74 72 1c f0 00 	movb   $0x0,0xf01c7274
f0103f75:	c6 05 75 72 1c f0 8e 	movb   $0x8e,0xf01c7275
f0103f7c:	c1 e8 10             	shr    $0x10,%eax
f0103f7f:	66 a3 76 72 1c f0    	mov    %ax,0xf01c7276
	SETGATE(idt[3], 1, GD_KT, breakpoint_handler, 3);
f0103f85:	b8 ae 4a 10 f0       	mov    $0xf0104aae,%eax
f0103f8a:	66 a3 78 72 1c f0    	mov    %ax,0xf01c7278
f0103f90:	66 c7 05 7a 72 1c f0 	movw   $0x8,0xf01c727a
f0103f97:	08 00 
f0103f99:	c6 05 7c 72 1c f0 00 	movb   $0x0,0xf01c727c
f0103fa0:	c6 05 7d 72 1c f0 ef 	movb   $0xef,0xf01c727d
f0103fa7:	c1 e8 10             	shr    $0x10,%eax
f0103faa:	66 a3 7e 72 1c f0    	mov    %ax,0xf01c727e
	SETGATE(idt[4], 1, GD_KT, overflow_handler, 3);
f0103fb0:	b8 b8 4a 10 f0       	mov    $0xf0104ab8,%eax
f0103fb5:	66 a3 80 72 1c f0    	mov    %ax,0xf01c7280
f0103fbb:	66 c7 05 82 72 1c f0 	movw   $0x8,0xf01c7282
f0103fc2:	08 00 
f0103fc4:	c6 05 84 72 1c f0 00 	movb   $0x0,0xf01c7284
f0103fcb:	c6 05 85 72 1c f0 ef 	movb   $0xef,0xf01c7285
f0103fd2:	c1 e8 10             	shr    $0x10,%eax
f0103fd5:	66 a3 86 72 1c f0    	mov    %ax,0xf01c7286
	SETGATE(idt[5], 1, GD_KT, bdrgeexceed_handler, 3);
f0103fdb:	b8 c2 4a 10 f0       	mov    $0xf0104ac2,%eax
f0103fe0:	66 a3 88 72 1c f0    	mov    %ax,0xf01c7288
f0103fe6:	66 c7 05 8a 72 1c f0 	movw   $0x8,0xf01c728a
f0103fed:	08 00 
f0103fef:	c6 05 8c 72 1c f0 00 	movb   $0x0,0xf01c728c
f0103ff6:	c6 05 8d 72 1c f0 ef 	movb   $0xef,0xf01c728d
f0103ffd:	c1 e8 10             	shr    $0x10,%eax
f0104000:	66 a3 8e 72 1c f0    	mov    %ax,0xf01c728e
	SETGATE(idt[6], 1, GD_KT, invalidop_handler, 0);
f0104006:	b8 cc 4a 10 f0       	mov    $0xf0104acc,%eax
f010400b:	66 a3 90 72 1c f0    	mov    %ax,0xf01c7290
f0104011:	66 c7 05 92 72 1c f0 	movw   $0x8,0xf01c7292
f0104018:	08 00 
f010401a:	c6 05 94 72 1c f0 00 	movb   $0x0,0xf01c7294
f0104021:	c6 05 95 72 1c f0 8f 	movb   $0x8f,0xf01c7295
f0104028:	c1 e8 10             	shr    $0x10,%eax
f010402b:	66 a3 96 72 1c f0    	mov    %ax,0xf01c7296
	SETGATE(idt[7], 1, GD_KT, nomathcopro_handler, 0);
f0104031:	b8 d6 4a 10 f0       	mov    $0xf0104ad6,%eax
f0104036:	66 a3 98 72 1c f0    	mov    %ax,0xf01c7298
f010403c:	66 c7 05 9a 72 1c f0 	movw   $0x8,0xf01c729a
f0104043:	08 00 
f0104045:	c6 05 9c 72 1c f0 00 	movb   $0x0,0xf01c729c
f010404c:	c6 05 9d 72 1c f0 8f 	movb   $0x8f,0xf01c729d
f0104053:	c1 e8 10             	shr    $0x10,%eax
f0104056:	66 a3 9e 72 1c f0    	mov    %ax,0xf01c729e
	SETGATE(idt[8], 1, GD_KT, dbfault_handler, 0);
f010405c:	b8 e0 4a 10 f0       	mov    $0xf0104ae0,%eax
f0104061:	66 a3 a0 72 1c f0    	mov    %ax,0xf01c72a0
f0104067:	66 c7 05 a2 72 1c f0 	movw   $0x8,0xf01c72a2
f010406e:	08 00 
f0104070:	c6 05 a4 72 1c f0 00 	movb   $0x0,0xf01c72a4
f0104077:	c6 05 a5 72 1c f0 8f 	movb   $0x8f,0xf01c72a5
f010407e:	c1 e8 10             	shr    $0x10,%eax
f0104081:	66 a3 a6 72 1c f0    	mov    %ax,0xf01c72a6
	SETGATE(idt[10], 1, GD_KT, invalidTSS_handler, 0);
f0104087:	b8 e8 4a 10 f0       	mov    $0xf0104ae8,%eax
f010408c:	66 a3 b0 72 1c f0    	mov    %ax,0xf01c72b0
f0104092:	66 c7 05 b2 72 1c f0 	movw   $0x8,0xf01c72b2
f0104099:	08 00 
f010409b:	c6 05 b4 72 1c f0 00 	movb   $0x0,0xf01c72b4
f01040a2:	c6 05 b5 72 1c f0 8f 	movb   $0x8f,0xf01c72b5
f01040a9:	c1 e8 10             	shr    $0x10,%eax
f01040ac:	66 a3 b6 72 1c f0    	mov    %ax,0xf01c72b6

	SETGATE(idt[11], 1, GD_KT, sgmtnotpresent_handler, 0);
f01040b2:	b8 f0 4a 10 f0       	mov    $0xf0104af0,%eax
f01040b7:	66 a3 b8 72 1c f0    	mov    %ax,0xf01c72b8
f01040bd:	66 c7 05 ba 72 1c f0 	movw   $0x8,0xf01c72ba
f01040c4:	08 00 
f01040c6:	c6 05 bc 72 1c f0 00 	movb   $0x0,0xf01c72bc
f01040cd:	c6 05 bd 72 1c f0 8f 	movb   $0x8f,0xf01c72bd
f01040d4:	c1 e8 10             	shr    $0x10,%eax
f01040d7:	66 a3 be 72 1c f0    	mov    %ax,0xf01c72be
	SETGATE(idt[12], 1, GD_KT, stacksgmtfault_handler, 0);
f01040dd:	b8 f8 4a 10 f0       	mov    $0xf0104af8,%eax
f01040e2:	66 a3 c0 72 1c f0    	mov    %ax,0xf01c72c0
f01040e8:	66 c7 05 c2 72 1c f0 	movw   $0x8,0xf01c72c2
f01040ef:	08 00 
f01040f1:	c6 05 c4 72 1c f0 00 	movb   $0x0,0xf01c72c4
f01040f8:	c6 05 c5 72 1c f0 8f 	movb   $0x8f,0xf01c72c5
f01040ff:	c1 e8 10             	shr    $0x10,%eax
f0104102:	66 a3 c6 72 1c f0    	mov    %ax,0xf01c72c6
	SETGATE(idt[14], 1, GD_KT, pagefault_handler, 0);
f0104108:	b8 08 4b 10 f0       	mov    $0xf0104b08,%eax
f010410d:	66 a3 d0 72 1c f0    	mov    %ax,0xf01c72d0
f0104113:	66 c7 05 d2 72 1c f0 	movw   $0x8,0xf01c72d2
f010411a:	08 00 
f010411c:	c6 05 d4 72 1c f0 00 	movb   $0x0,0xf01c72d4
f0104123:	c6 05 d5 72 1c f0 8f 	movb   $0x8f,0xf01c72d5
f010412a:	c1 e8 10             	shr    $0x10,%eax
f010412d:	66 a3 d6 72 1c f0    	mov    %ax,0xf01c72d6
	SETGATE(idt[13], 1, GD_KT, generalprotection_handler, 0);
f0104133:	b8 00 4b 10 f0       	mov    $0xf0104b00,%eax
f0104138:	66 a3 c8 72 1c f0    	mov    %ax,0xf01c72c8
f010413e:	66 c7 05 ca 72 1c f0 	movw   $0x8,0xf01c72ca
f0104145:	08 00 
f0104147:	c6 05 cc 72 1c f0 00 	movb   $0x0,0xf01c72cc
f010414e:	c6 05 cd 72 1c f0 8f 	movb   $0x8f,0xf01c72cd
f0104155:	c1 e8 10             	shr    $0x10,%eax
f0104158:	66 a3 ce 72 1c f0    	mov    %ax,0xf01c72ce
	SETGATE(idt[16], 1, GD_KT, FPUerror_handler, 0);
f010415e:	b8 0c 4b 10 f0       	mov    $0xf0104b0c,%eax
f0104163:	66 a3 e0 72 1c f0    	mov    %ax,0xf01c72e0
f0104169:	66 c7 05 e2 72 1c f0 	movw   $0x8,0xf01c72e2
f0104170:	08 00 
f0104172:	c6 05 e4 72 1c f0 00 	movb   $0x0,0xf01c72e4
f0104179:	c6 05 e5 72 1c f0 8f 	movb   $0x8f,0xf01c72e5
f0104180:	c1 e8 10             	shr    $0x10,%eax
f0104183:	66 a3 e6 72 1c f0    	mov    %ax,0xf01c72e6
	SETGATE(idt[17], 1, GD_KT, alignmentcheck_handler, 0);
f0104189:	b8 12 4b 10 f0       	mov    $0xf0104b12,%eax
f010418e:	66 a3 e8 72 1c f0    	mov    %ax,0xf01c72e8
f0104194:	66 c7 05 ea 72 1c f0 	movw   $0x8,0xf01c72ea
f010419b:	08 00 
f010419d:	c6 05 ec 72 1c f0 00 	movb   $0x0,0xf01c72ec
f01041a4:	c6 05 ed 72 1c f0 8f 	movb   $0x8f,0xf01c72ed
f01041ab:	c1 e8 10             	shr    $0x10,%eax
f01041ae:	66 a3 ee 72 1c f0    	mov    %ax,0xf01c72ee
	SETGATE(idt[18],1, GD_KT, machinecheck_handler, 0);
f01041b4:	b8 16 4b 10 f0       	mov    $0xf0104b16,%eax
f01041b9:	66 a3 f0 72 1c f0    	mov    %ax,0xf01c72f0
f01041bf:	66 c7 05 f2 72 1c f0 	movw   $0x8,0xf01c72f2
f01041c6:	08 00 
f01041c8:	c6 05 f4 72 1c f0 00 	movb   $0x0,0xf01c72f4
f01041cf:	c6 05 f5 72 1c f0 8f 	movb   $0x8f,0xf01c72f5
f01041d6:	c1 e8 10             	shr    $0x10,%eax
f01041d9:	66 a3 f6 72 1c f0    	mov    %ax,0xf01c72f6
	SETGATE(idt[19], 1, GD_KT, SIMDFPexception_handler, 0);
f01041df:	b8 1c 4b 10 f0       	mov    $0xf0104b1c,%eax
f01041e4:	66 a3 f8 72 1c f0    	mov    %ax,0xf01c72f8
f01041ea:	66 c7 05 fa 72 1c f0 	movw   $0x8,0xf01c72fa
f01041f1:	08 00 
f01041f3:	c6 05 fc 72 1c f0 00 	movb   $0x0,0xf01c72fc
f01041fa:	c6 05 fd 72 1c f0 8f 	movb   $0x8f,0xf01c72fd
f0104201:	c1 e8 10             	shr    $0x10,%eax
f0104204:	66 a3 fe 72 1c f0    	mov    %ax,0xf01c72fe
	SETGATE(idt[48], 0, GD_KT, systemcall_handler, 3);
f010420a:	b8 22 4b 10 f0       	mov    $0xf0104b22,%eax
f010420f:	66 a3 e0 73 1c f0    	mov    %ax,0xf01c73e0
f0104215:	66 c7 05 e2 73 1c f0 	movw   $0x8,0xf01c73e2
f010421c:	08 00 
f010421e:	c6 05 e4 73 1c f0 00 	movb   $0x0,0xf01c73e4
f0104225:	c6 05 e5 73 1c f0 ee 	movb   $0xee,0xf01c73e5
f010422c:	c1 e8 10             	shr    $0x10,%eax
f010422f:	66 a3 e6 73 1c f0    	mov    %ax,0xf01c73e6
	// LAB 3: Your code here.

	SETGATE(idt[IRQ_OFFSET + 0], 0, GD_KT, t_irq0, 0);
f0104235:	b8 28 4b 10 f0       	mov    $0xf0104b28,%eax
f010423a:	66 a3 60 73 1c f0    	mov    %ax,0xf01c7360
f0104240:	66 c7 05 62 73 1c f0 	movw   $0x8,0xf01c7362
f0104247:	08 00 
f0104249:	c6 05 64 73 1c f0 00 	movb   $0x0,0xf01c7364
f0104250:	c6 05 65 73 1c f0 8e 	movb   $0x8e,0xf01c7365
f0104257:	c1 e8 10             	shr    $0x10,%eax
f010425a:	66 a3 66 73 1c f0    	mov    %ax,0xf01c7366
	SETGATE(idt[IRQ_OFFSET + 1], 0, GD_KT, t_irq1, 0);
f0104260:	b8 2e 4b 10 f0       	mov    $0xf0104b2e,%eax
f0104265:	66 a3 68 73 1c f0    	mov    %ax,0xf01c7368
f010426b:	66 c7 05 6a 73 1c f0 	movw   $0x8,0xf01c736a
f0104272:	08 00 
f0104274:	c6 05 6c 73 1c f0 00 	movb   $0x0,0xf01c736c
f010427b:	c6 05 6d 73 1c f0 8e 	movb   $0x8e,0xf01c736d
f0104282:	c1 e8 10             	shr    $0x10,%eax
f0104285:	66 a3 6e 73 1c f0    	mov    %ax,0xf01c736e
	SETGATE(idt[IRQ_OFFSET + 2], 0, GD_KT, t_irq2, 0);
f010428b:	b8 34 4b 10 f0       	mov    $0xf0104b34,%eax
f0104290:	66 a3 70 73 1c f0    	mov    %ax,0xf01c7370
f0104296:	66 c7 05 72 73 1c f0 	movw   $0x8,0xf01c7372
f010429d:	08 00 
f010429f:	c6 05 74 73 1c f0 00 	movb   $0x0,0xf01c7374
f01042a6:	c6 05 75 73 1c f0 8e 	movb   $0x8e,0xf01c7375
f01042ad:	c1 e8 10             	shr    $0x10,%eax
f01042b0:	66 a3 76 73 1c f0    	mov    %ax,0xf01c7376
	SETGATE(idt[IRQ_OFFSET + 3], 0, GD_KT, t_irq3, 0);
f01042b6:	b8 3a 4b 10 f0       	mov    $0xf0104b3a,%eax
f01042bb:	66 a3 78 73 1c f0    	mov    %ax,0xf01c7378
f01042c1:	66 c7 05 7a 73 1c f0 	movw   $0x8,0xf01c737a
f01042c8:	08 00 
f01042ca:	c6 05 7c 73 1c f0 00 	movb   $0x0,0xf01c737c
f01042d1:	c6 05 7d 73 1c f0 8e 	movb   $0x8e,0xf01c737d
f01042d8:	c1 e8 10             	shr    $0x10,%eax
f01042db:	66 a3 7e 73 1c f0    	mov    %ax,0xf01c737e
	SETGATE(idt[IRQ_OFFSET + 4], 0, GD_KT, t_irq4, 0);
f01042e1:	b8 40 4b 10 f0       	mov    $0xf0104b40,%eax
f01042e6:	66 a3 80 73 1c f0    	mov    %ax,0xf01c7380
f01042ec:	66 c7 05 82 73 1c f0 	movw   $0x8,0xf01c7382
f01042f3:	08 00 
f01042f5:	c6 05 84 73 1c f0 00 	movb   $0x0,0xf01c7384
f01042fc:	c6 05 85 73 1c f0 8e 	movb   $0x8e,0xf01c7385
f0104303:	c1 e8 10             	shr    $0x10,%eax
f0104306:	66 a3 86 73 1c f0    	mov    %ax,0xf01c7386
	SETGATE(idt[IRQ_OFFSET + 5], 0, GD_KT, t_irq5, 0);
f010430c:	b8 46 4b 10 f0       	mov    $0xf0104b46,%eax
f0104311:	66 a3 88 73 1c f0    	mov    %ax,0xf01c7388
f0104317:	66 c7 05 8a 73 1c f0 	movw   $0x8,0xf01c738a
f010431e:	08 00 
f0104320:	c6 05 8c 73 1c f0 00 	movb   $0x0,0xf01c738c
f0104327:	c6 05 8d 73 1c f0 8e 	movb   $0x8e,0xf01c738d
f010432e:	c1 e8 10             	shr    $0x10,%eax
f0104331:	66 a3 8e 73 1c f0    	mov    %ax,0xf01c738e
	SETGATE(idt[IRQ_OFFSET + 6], 0, GD_KT, t_irq6, 0);
f0104337:	b8 4c 4b 10 f0       	mov    $0xf0104b4c,%eax
f010433c:	66 a3 90 73 1c f0    	mov    %ax,0xf01c7390
f0104342:	66 c7 05 92 73 1c f0 	movw   $0x8,0xf01c7392
f0104349:	08 00 
f010434b:	c6 05 94 73 1c f0 00 	movb   $0x0,0xf01c7394
f0104352:	c6 05 95 73 1c f0 8e 	movb   $0x8e,0xf01c7395
f0104359:	c1 e8 10             	shr    $0x10,%eax
f010435c:	66 a3 96 73 1c f0    	mov    %ax,0xf01c7396
	SETGATE(idt[IRQ_OFFSET + 7], 0, GD_KT, t_irq7, 0);
f0104362:	b8 52 4b 10 f0       	mov    $0xf0104b52,%eax
f0104367:	66 a3 98 73 1c f0    	mov    %ax,0xf01c7398
f010436d:	66 c7 05 9a 73 1c f0 	movw   $0x8,0xf01c739a
f0104374:	08 00 
f0104376:	c6 05 9c 73 1c f0 00 	movb   $0x0,0xf01c739c
f010437d:	c6 05 9d 73 1c f0 8e 	movb   $0x8e,0xf01c739d
f0104384:	c1 e8 10             	shr    $0x10,%eax
f0104387:	66 a3 9e 73 1c f0    	mov    %ax,0xf01c739e
	SETGATE(idt[IRQ_OFFSET + 8], 0, GD_KT, t_irq8, 0);
f010438d:	b8 58 4b 10 f0       	mov    $0xf0104b58,%eax
f0104392:	66 a3 a0 73 1c f0    	mov    %ax,0xf01c73a0
f0104398:	66 c7 05 a2 73 1c f0 	movw   $0x8,0xf01c73a2
f010439f:	08 00 
f01043a1:	c6 05 a4 73 1c f0 00 	movb   $0x0,0xf01c73a4
f01043a8:	c6 05 a5 73 1c f0 8e 	movb   $0x8e,0xf01c73a5
f01043af:	c1 e8 10             	shr    $0x10,%eax
f01043b2:	66 a3 a6 73 1c f0    	mov    %ax,0xf01c73a6
	SETGATE(idt[IRQ_OFFSET + 9], 0, GD_KT, t_irq9, 0);
f01043b8:	b8 5e 4b 10 f0       	mov    $0xf0104b5e,%eax
f01043bd:	66 a3 a8 73 1c f0    	mov    %ax,0xf01c73a8
f01043c3:	66 c7 05 aa 73 1c f0 	movw   $0x8,0xf01c73aa
f01043ca:	08 00 
f01043cc:	c6 05 ac 73 1c f0 00 	movb   $0x0,0xf01c73ac
f01043d3:	c6 05 ad 73 1c f0 8e 	movb   $0x8e,0xf01c73ad
f01043da:	c1 e8 10             	shr    $0x10,%eax
f01043dd:	66 a3 ae 73 1c f0    	mov    %ax,0xf01c73ae
	SETGATE(idt[IRQ_OFFSET + 10], 0, GD_KT, t_irq10, 0);
f01043e3:	b8 64 4b 10 f0       	mov    $0xf0104b64,%eax
f01043e8:	66 a3 b0 73 1c f0    	mov    %ax,0xf01c73b0
f01043ee:	66 c7 05 b2 73 1c f0 	movw   $0x8,0xf01c73b2
f01043f5:	08 00 
f01043f7:	c6 05 b4 73 1c f0 00 	movb   $0x0,0xf01c73b4
f01043fe:	c6 05 b5 73 1c f0 8e 	movb   $0x8e,0xf01c73b5
f0104405:	c1 e8 10             	shr    $0x10,%eax
f0104408:	66 a3 b6 73 1c f0    	mov    %ax,0xf01c73b6
	SETGATE(idt[IRQ_OFFSET + 11], 0, GD_KT, t_irq11, 0);
f010440e:	b8 6a 4b 10 f0       	mov    $0xf0104b6a,%eax
f0104413:	66 a3 b8 73 1c f0    	mov    %ax,0xf01c73b8
f0104419:	66 c7 05 ba 73 1c f0 	movw   $0x8,0xf01c73ba
f0104420:	08 00 
f0104422:	c6 05 bc 73 1c f0 00 	movb   $0x0,0xf01c73bc
f0104429:	c6 05 bd 73 1c f0 8e 	movb   $0x8e,0xf01c73bd
f0104430:	c1 e8 10             	shr    $0x10,%eax
f0104433:	66 a3 be 73 1c f0    	mov    %ax,0xf01c73be
	SETGATE(idt[IRQ_OFFSET + 12], 0, GD_KT, t_irq12, 0);
f0104439:	b8 70 4b 10 f0       	mov    $0xf0104b70,%eax
f010443e:	66 a3 c0 73 1c f0    	mov    %ax,0xf01c73c0
f0104444:	66 c7 05 c2 73 1c f0 	movw   $0x8,0xf01c73c2
f010444b:	08 00 
f010444d:	c6 05 c4 73 1c f0 00 	movb   $0x0,0xf01c73c4
f0104454:	c6 05 c5 73 1c f0 8e 	movb   $0x8e,0xf01c73c5
f010445b:	c1 e8 10             	shr    $0x10,%eax
f010445e:	66 a3 c6 73 1c f0    	mov    %ax,0xf01c73c6
	SETGATE(idt[IRQ_OFFSET + 13], 0, GD_KT, t_irq13, 0);
f0104464:	b8 76 4b 10 f0       	mov    $0xf0104b76,%eax
f0104469:	66 a3 c8 73 1c f0    	mov    %ax,0xf01c73c8
f010446f:	66 c7 05 ca 73 1c f0 	movw   $0x8,0xf01c73ca
f0104476:	08 00 
f0104478:	c6 05 cc 73 1c f0 00 	movb   $0x0,0xf01c73cc
f010447f:	c6 05 cd 73 1c f0 8e 	movb   $0x8e,0xf01c73cd
f0104486:	c1 e8 10             	shr    $0x10,%eax
f0104489:	66 a3 ce 73 1c f0    	mov    %ax,0xf01c73ce
	SETGATE(idt[IRQ_OFFSET + 14], 0, GD_KT, t_irq14, 0);
f010448f:	b8 7c 4b 10 f0       	mov    $0xf0104b7c,%eax
f0104494:	66 a3 d0 73 1c f0    	mov    %ax,0xf01c73d0
f010449a:	66 c7 05 d2 73 1c f0 	movw   $0x8,0xf01c73d2
f01044a1:	08 00 
f01044a3:	c6 05 d4 73 1c f0 00 	movb   $0x0,0xf01c73d4
f01044aa:	c6 05 d5 73 1c f0 8e 	movb   $0x8e,0xf01c73d5
f01044b1:	c1 e8 10             	shr    $0x10,%eax
f01044b4:	66 a3 d6 73 1c f0    	mov    %ax,0xf01c73d6
	SETGATE(idt[IRQ_OFFSET + 15], 0, GD_KT, t_irq15, 0);
f01044ba:	b8 82 4b 10 f0       	mov    $0xf0104b82,%eax
f01044bf:	66 a3 d8 73 1c f0    	mov    %ax,0xf01c73d8
f01044c5:	66 c7 05 da 73 1c f0 	movw   $0x8,0xf01c73da
f01044cc:	08 00 
f01044ce:	c6 05 dc 73 1c f0 00 	movb   $0x0,0xf01c73dc
f01044d5:	c6 05 dd 73 1c f0 8e 	movb   $0x8e,0xf01c73dd
f01044dc:	c1 e8 10             	shr    $0x10,%eax
f01044df:	66 a3 de 73 1c f0    	mov    %ax,0xf01c73de
	// Per-CPU setup 
	trap_init_percpu();
f01044e5:	e8 b6 f9 ff ff       	call   f0103ea0 <trap_init_percpu>
}
f01044ea:	c9                   	leave  
f01044eb:	c3                   	ret    

f01044ec <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f01044ec:	55                   	push   %ebp
f01044ed:	89 e5                	mov    %esp,%ebp
f01044ef:	53                   	push   %ebx
f01044f0:	83 ec 14             	sub    $0x14,%esp
f01044f3:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f01044f6:	8b 03                	mov    (%ebx),%eax
f01044f8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01044fc:	c7 04 24 9a 7d 10 f0 	movl   $0xf0107d9a,(%esp)
f0104503:	e8 7e f9 ff ff       	call   f0103e86 <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f0104508:	8b 43 04             	mov    0x4(%ebx),%eax
f010450b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010450f:	c7 04 24 a9 7d 10 f0 	movl   $0xf0107da9,(%esp)
f0104516:	e8 6b f9 ff ff       	call   f0103e86 <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f010451b:	8b 43 08             	mov    0x8(%ebx),%eax
f010451e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104522:	c7 04 24 b8 7d 10 f0 	movl   $0xf0107db8,(%esp)
f0104529:	e8 58 f9 ff ff       	call   f0103e86 <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f010452e:	8b 43 0c             	mov    0xc(%ebx),%eax
f0104531:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104535:	c7 04 24 c7 7d 10 f0 	movl   $0xf0107dc7,(%esp)
f010453c:	e8 45 f9 ff ff       	call   f0103e86 <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f0104541:	8b 43 10             	mov    0x10(%ebx),%eax
f0104544:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104548:	c7 04 24 d6 7d 10 f0 	movl   $0xf0107dd6,(%esp)
f010454f:	e8 32 f9 ff ff       	call   f0103e86 <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0104554:	8b 43 14             	mov    0x14(%ebx),%eax
f0104557:	89 44 24 04          	mov    %eax,0x4(%esp)
f010455b:	c7 04 24 e5 7d 10 f0 	movl   $0xf0107de5,(%esp)
f0104562:	e8 1f f9 ff ff       	call   f0103e86 <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f0104567:	8b 43 18             	mov    0x18(%ebx),%eax
f010456a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010456e:	c7 04 24 f4 7d 10 f0 	movl   $0xf0107df4,(%esp)
f0104575:	e8 0c f9 ff ff       	call   f0103e86 <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f010457a:	8b 43 1c             	mov    0x1c(%ebx),%eax
f010457d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104581:	c7 04 24 03 7e 10 f0 	movl   $0xf0107e03,(%esp)
f0104588:	e8 f9 f8 ff ff       	call   f0103e86 <cprintf>
}
f010458d:	83 c4 14             	add    $0x14,%esp
f0104590:	5b                   	pop    %ebx
f0104591:	5d                   	pop    %ebp
f0104592:	c3                   	ret    

f0104593 <print_trapframe>:
	lidt(&idt_pd);*/
}

void
print_trapframe(struct Trapframe *tf)
{
f0104593:	55                   	push   %ebp
f0104594:	89 e5                	mov    %esp,%ebp
f0104596:	56                   	push   %esi
f0104597:	53                   	push   %ebx
f0104598:	83 ec 10             	sub    $0x10,%esp
f010459b:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
f010459e:	e8 f0 1f 00 00       	call   f0106593 <cpunum>
f01045a3:	89 44 24 08          	mov    %eax,0x8(%esp)
f01045a7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01045ab:	c7 04 24 67 7e 10 f0 	movl   $0xf0107e67,(%esp)
f01045b2:	e8 cf f8 ff ff       	call   f0103e86 <cprintf>
	print_regs(&tf->tf_regs);
f01045b7:	89 1c 24             	mov    %ebx,(%esp)
f01045ba:	e8 2d ff ff ff       	call   f01044ec <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f01045bf:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f01045c3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01045c7:	c7 04 24 85 7e 10 f0 	movl   $0xf0107e85,(%esp)
f01045ce:	e8 b3 f8 ff ff       	call   f0103e86 <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f01045d3:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f01045d7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01045db:	c7 04 24 98 7e 10 f0 	movl   $0xf0107e98,(%esp)
f01045e2:	e8 9f f8 ff ff       	call   f0103e86 <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f01045e7:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f01045ea:	83 f8 13             	cmp    $0x13,%eax
f01045ed:	77 09                	ja     f01045f8 <print_trapframe+0x65>
		return excnames[trapno];
f01045ef:	8b 14 85 20 81 10 f0 	mov    -0xfef7ee0(,%eax,4),%edx
f01045f6:	eb 1f                	jmp    f0104617 <print_trapframe+0x84>
	if (trapno == T_SYSCALL)
f01045f8:	83 f8 30             	cmp    $0x30,%eax
f01045fb:	74 15                	je     f0104612 <print_trapframe+0x7f>
		return "System call";
	if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16)
f01045fd:	8d 50 e0             	lea    -0x20(%eax),%edx
		return "Hardware Interrupt";
f0104600:	83 fa 0f             	cmp    $0xf,%edx
f0104603:	ba 1e 7e 10 f0       	mov    $0xf0107e1e,%edx
f0104608:	b9 31 7e 10 f0       	mov    $0xf0107e31,%ecx
f010460d:	0f 47 d1             	cmova  %ecx,%edx
f0104610:	eb 05                	jmp    f0104617 <print_trapframe+0x84>
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
		return excnames[trapno];
	if (trapno == T_SYSCALL)
		return "System call";
f0104612:	ba 12 7e 10 f0       	mov    $0xf0107e12,%edx
{
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0104617:	89 54 24 08          	mov    %edx,0x8(%esp)
f010461b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010461f:	c7 04 24 ab 7e 10 f0 	movl   $0xf0107eab,(%esp)
f0104626:	e8 5b f8 ff ff       	call   f0103e86 <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f010462b:	3b 1d 60 7a 1c f0    	cmp    0xf01c7a60,%ebx
f0104631:	75 19                	jne    f010464c <print_trapframe+0xb9>
f0104633:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104637:	75 13                	jne    f010464c <print_trapframe+0xb9>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f0104639:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f010463c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104640:	c7 04 24 bd 7e 10 f0 	movl   $0xf0107ebd,(%esp)
f0104647:	e8 3a f8 ff ff       	call   f0103e86 <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f010464c:	8b 43 2c             	mov    0x2c(%ebx),%eax
f010464f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104653:	c7 04 24 cc 7e 10 f0 	movl   $0xf0107ecc,(%esp)
f010465a:	e8 27 f8 ff ff       	call   f0103e86 <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f010465f:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104663:	75 51                	jne    f01046b6 <print_trapframe+0x123>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f0104665:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f0104668:	89 c2                	mov    %eax,%edx
f010466a:	83 e2 01             	and    $0x1,%edx
f010466d:	ba 40 7e 10 f0       	mov    $0xf0107e40,%edx
f0104672:	b9 4b 7e 10 f0       	mov    $0xf0107e4b,%ecx
f0104677:	0f 45 ca             	cmovne %edx,%ecx
f010467a:	89 c2                	mov    %eax,%edx
f010467c:	83 e2 02             	and    $0x2,%edx
f010467f:	ba 57 7e 10 f0       	mov    $0xf0107e57,%edx
f0104684:	be 5d 7e 10 f0       	mov    $0xf0107e5d,%esi
f0104689:	0f 44 d6             	cmove  %esi,%edx
f010468c:	83 e0 04             	and    $0x4,%eax
f010468f:	b8 62 7e 10 f0       	mov    $0xf0107e62,%eax
f0104694:	be 7e 7f 10 f0       	mov    $0xf0107f7e,%esi
f0104699:	0f 44 c6             	cmove  %esi,%eax
f010469c:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01046a0:	89 54 24 08          	mov    %edx,0x8(%esp)
f01046a4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046a8:	c7 04 24 da 7e 10 f0 	movl   $0xf0107eda,(%esp)
f01046af:	e8 d2 f7 ff ff       	call   f0103e86 <cprintf>
f01046b4:	eb 0c                	jmp    f01046c2 <print_trapframe+0x12f>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f01046b6:	c7 04 24 78 7d 10 f0 	movl   $0xf0107d78,(%esp)
f01046bd:	e8 c4 f7 ff ff       	call   f0103e86 <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f01046c2:	8b 43 30             	mov    0x30(%ebx),%eax
f01046c5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046c9:	c7 04 24 e9 7e 10 f0 	movl   $0xf0107ee9,(%esp)
f01046d0:	e8 b1 f7 ff ff       	call   f0103e86 <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f01046d5:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f01046d9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046dd:	c7 04 24 f8 7e 10 f0 	movl   $0xf0107ef8,(%esp)
f01046e4:	e8 9d f7 ff ff       	call   f0103e86 <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f01046e9:	8b 43 38             	mov    0x38(%ebx),%eax
f01046ec:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046f0:	c7 04 24 0b 7f 10 f0 	movl   $0xf0107f0b,(%esp)
f01046f7:	e8 8a f7 ff ff       	call   f0103e86 <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f01046fc:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f0104700:	74 27                	je     f0104729 <print_trapframe+0x196>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f0104702:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0104705:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104709:	c7 04 24 1a 7f 10 f0 	movl   $0xf0107f1a,(%esp)
f0104710:	e8 71 f7 ff ff       	call   f0103e86 <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f0104715:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f0104719:	89 44 24 04          	mov    %eax,0x4(%esp)
f010471d:	c7 04 24 29 7f 10 f0 	movl   $0xf0107f29,(%esp)
f0104724:	e8 5d f7 ff ff       	call   f0103e86 <cprintf>
	}
}
f0104729:	83 c4 10             	add    $0x10,%esp
f010472c:	5b                   	pop    %ebx
f010472d:	5e                   	pop    %esi
f010472e:	5d                   	pop    %ebp
f010472f:	c3                   	ret    

f0104730 <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f0104730:	55                   	push   %ebp
f0104731:	89 e5                	mov    %esp,%ebp
f0104733:	57                   	push   %edi
f0104734:	56                   	push   %esi
f0104735:	53                   	push   %ebx
f0104736:	83 ec 2c             	sub    $0x2c,%esp
f0104739:	8b 5d 08             	mov    0x8(%ebp),%ebx
f010473c:	0f 20 d0             	mov    %cr2,%eax
f010473f:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	uint32_t fault_va;

	// Read processor's CR2 register to find the faulting address
	fault_va = rcr2();
	if((tf->tf_cs & 0x3) != 3)
f0104742:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f0104746:	83 e0 03             	and    $0x3,%eax
f0104749:	66 83 f8 03          	cmp    $0x3,%ax
f010474d:	74 1c                	je     f010476b <page_fault_handler+0x3b>
		panic("page_fault_handler(): page fault at kernel-mode !");
f010474f:	c7 44 24 08 c8 80 10 	movl   $0xf01080c8,0x8(%esp)
f0104756:	f0 
f0104757:	c7 44 24 04 78 01 00 	movl   $0x178,0x4(%esp)
f010475e:	00 
f010475f:	c7 04 24 3c 7f 10 f0 	movl   $0xf0107f3c,(%esp)
f0104766:	e8 d5 b8 ff ff       	call   f0100040 <_panic>
	//   user_mem_assert() and env_run() are useful here.
	//   To change what the user environment runs, modify 'curenv->env_tf'
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.
	if(curenv->env_pgfault_upcall == NULL){
f010476b:	e8 23 1e 00 00       	call   f0106593 <cpunum>
f0104770:	6b c0 74             	imul   $0x74,%eax,%eax
f0104773:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104779:	83 78 64 00          	cmpl   $0x0,0x64(%eax)
f010477d:	75 4d                	jne    f01047cc <page_fault_handler+0x9c>
		// Destroy the environment that caused the fault.
		cprintf("[%08x] user fault va %08x ip %08x\n",
f010477f:	8b 73 30             	mov    0x30(%ebx),%esi
		curenv->env_id, fault_va, tf->tf_eip);
f0104782:	e8 0c 1e 00 00       	call   f0106593 <cpunum>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.
	if(curenv->env_pgfault_upcall == NULL){
		// Destroy the environment that caused the fault.
		cprintf("[%08x] user fault va %08x ip %08x\n",
f0104787:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010478b:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f010478e:	89 7c 24 08          	mov    %edi,0x8(%esp)
		curenv->env_id, fault_va, tf->tf_eip);
f0104792:	6b c0 74             	imul   $0x74,%eax,%eax
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.
	if(curenv->env_pgfault_upcall == NULL){
		// Destroy the environment that caused the fault.
		cprintf("[%08x] user fault va %08x ip %08x\n",
f0104795:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f010479b:	8b 40 48             	mov    0x48(%eax),%eax
f010479e:	89 44 24 04          	mov    %eax,0x4(%esp)
f01047a2:	c7 04 24 fc 80 10 f0 	movl   $0xf01080fc,(%esp)
f01047a9:	e8 d8 f6 ff ff       	call   f0103e86 <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
		print_trapframe(tf);
f01047ae:	89 1c 24             	mov    %ebx,(%esp)
f01047b1:	e8 dd fd ff ff       	call   f0104593 <print_trapframe>
		env_destroy(curenv);
f01047b6:	e8 d8 1d 00 00       	call   f0106593 <cpunum>
f01047bb:	6b c0 74             	imul   $0x74,%eax,%eax
f01047be:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f01047c4:	89 04 24             	mov    %eax,(%esp)
f01047c7:	e8 08 f4 ff ff       	call   f0103bd4 <env_destroy>
	}

	struct UTrapframe* utf;
	if(UXSTACKTOP - PGSIZE <= tf->tf_esp && tf->tf_esp < UXSTACKTOP) // an page_fault from user exception stack
f01047cc:	8b 43 3c             	mov    0x3c(%ebx),%eax
f01047cf:	8d 90 00 10 40 11    	lea    0x11401000(%eax),%edx
	{
		utf = (struct UTrapframe*) (tf->tf_esp - sizeof (struct UTrapframe) - sizeof(uint32_t));
f01047d5:	83 e8 38             	sub    $0x38,%eax
f01047d8:	81 fa ff 0f 00 00    	cmp    $0xfff,%edx
f01047de:	ba cc ff bf ee       	mov    $0xeebfffcc,%edx
f01047e3:	0f 46 d0             	cmovbe %eax,%edx
f01047e6:	89 d6                	mov    %edx,%esi
f01047e8:	89 55 e0             	mov    %edx,-0x20(%ebp)
	}
	else // an page_fault from normal user space
	{
		utf = (struct UTrapframe*) (UXSTACKTOP - sizeof(struct UTrapframe));
	}
	user_mem_assert(curenv, (void*) utf, sizeof (struct UTrapframe), PTE_U | PTE_W);
f01047eb:	e8 a3 1d 00 00       	call   f0106593 <cpunum>
f01047f0:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01047f7:	00 
f01047f8:	c7 44 24 08 34 00 00 	movl   $0x34,0x8(%esp)
f01047ff:	00 
f0104800:	89 74 24 04          	mov    %esi,0x4(%esp)
f0104804:	6b c0 74             	imul   $0x74,%eax,%eax
f0104807:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f010480d:	89 04 24             	mov    %eax,(%esp)
f0104810:	e8 fb ec ff ff       	call   f0103510 <user_mem_assert>
	
	// setup a stack
	utf->utf_eflags = tf->tf_eflags;
f0104815:	8b 43 38             	mov    0x38(%ebx),%eax
f0104818:	89 46 2c             	mov    %eax,0x2c(%esi)
	utf->utf_eip = tf->tf_eip;
f010481b:	8b 43 30             	mov    0x30(%ebx),%eax
f010481e:	89 46 28             	mov    %eax,0x28(%esi)
	utf->utf_esp = tf->tf_esp;
f0104821:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0104824:	89 46 30             	mov    %eax,0x30(%esi)
	utf->utf_regs = tf->tf_regs;
f0104827:	8d 7e 08             	lea    0x8(%esi),%edi
f010482a:	89 de                	mov    %ebx,%esi
f010482c:	b8 20 00 00 00       	mov    $0x20,%eax
f0104831:	f7 c7 01 00 00 00    	test   $0x1,%edi
f0104837:	74 03                	je     f010483c <page_fault_handler+0x10c>
f0104839:	a4                   	movsb  %ds:(%esi),%es:(%edi)
f010483a:	b0 1f                	mov    $0x1f,%al
f010483c:	f7 c7 02 00 00 00    	test   $0x2,%edi
f0104842:	74 05                	je     f0104849 <page_fault_handler+0x119>
f0104844:	66 a5                	movsw  %ds:(%esi),%es:(%edi)
f0104846:	83 e8 02             	sub    $0x2,%eax
f0104849:	89 c1                	mov    %eax,%ecx
f010484b:	c1 e9 02             	shr    $0x2,%ecx
f010484e:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0104850:	ba 00 00 00 00       	mov    $0x0,%edx
f0104855:	a8 02                	test   $0x2,%al
f0104857:	74 0b                	je     f0104864 <page_fault_handler+0x134>
f0104859:	0f b7 16             	movzwl (%esi),%edx
f010485c:	66 89 17             	mov    %dx,(%edi)
f010485f:	ba 02 00 00 00       	mov    $0x2,%edx
f0104864:	a8 01                	test   $0x1,%al
f0104866:	74 07                	je     f010486f <page_fault_handler+0x13f>
f0104868:	0f b6 04 16          	movzbl (%esi,%edx,1),%eax
f010486c:	88 04 17             	mov    %al,(%edi,%edx,1)
	utf->utf_err = tf->tf_err;
f010486f:	8b 43 2c             	mov    0x2c(%ebx),%eax
f0104872:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0104875:	89 47 04             	mov    %eax,0x4(%edi)
	utf->utf_fault_va = fault_va;
f0104878:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010487b:	89 07                	mov    %eax,(%edi)

	curenv->env_tf.tf_eip = (uint32_t)curenv->env_pgfault_upcall;
f010487d:	e8 11 1d 00 00       	call   f0106593 <cpunum>
f0104882:	6b c0 74             	imul   $0x74,%eax,%eax
f0104885:	8b 98 28 80 1c f0    	mov    -0xfe37fd8(%eax),%ebx
f010488b:	e8 03 1d 00 00       	call   f0106593 <cpunum>
f0104890:	6b c0 74             	imul   $0x74,%eax,%eax
f0104893:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104899:	8b 40 64             	mov    0x64(%eax),%eax
f010489c:	89 43 30             	mov    %eax,0x30(%ebx)
	curenv->env_tf.tf_esp = (uint32_t)utf;
f010489f:	e8 ef 1c 00 00       	call   f0106593 <cpunum>
f01048a4:	6b c0 74             	imul   $0x74,%eax,%eax
f01048a7:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f01048ad:	89 78 3c             	mov    %edi,0x3c(%eax)

	env_run(curenv);
f01048b0:	e8 de 1c 00 00       	call   f0106593 <cpunum>
f01048b5:	6b c0 74             	imul   $0x74,%eax,%eax
f01048b8:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f01048be:	89 04 24             	mov    %eax,(%esp)
f01048c1:	e8 af f3 ff ff       	call   f0103c75 <env_run>

f01048c6 <trap>:



void
trap(struct Trapframe *tf)
{
f01048c6:	55                   	push   %ebp
f01048c7:	89 e5                	mov    %esp,%ebp
f01048c9:	57                   	push   %edi
f01048ca:	56                   	push   %esi
f01048cb:	83 ec 20             	sub    $0x20,%esp
f01048ce:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f01048d1:	fc                   	cld    

	// Halt the CPU if some other CPU has called panic()
	extern char *panicstr;
	if (panicstr)
f01048d2:	83 3d 80 7e 1c f0 00 	cmpl   $0x0,0xf01c7e80
f01048d9:	74 01                	je     f01048dc <trap+0x16>
		asm volatile("hlt");
f01048db:	f4                   	hlt    
	// the interrupt path.
	//assert(!(read_eflags() & FL_IF));
	
	//cprintf("Incoming TRAP frame at %p\n", tf);

	if ((tf->tf_cs & 3) == 3) {
f01048dc:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f01048e0:	83 e0 03             	and    $0x3,%eax
f01048e3:	66 83 f8 03          	cmp    $0x3,%ax
f01048e7:	0f 85 a7 00 00 00    	jne    f0104994 <trap+0xce>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f01048ed:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f01048f4:	e8 00 1f 00 00       	call   f01067f9 <spin_lock>
		// serious kernel work.
		// LAB 4: Your code here.
		//if(tf->tf_cs!=GD_KT){
		lock_kernel();
		//}
		assert(curenv);
f01048f9:	e8 95 1c 00 00       	call   f0106593 <cpunum>
f01048fe:	6b c0 74             	imul   $0x74,%eax,%eax
f0104901:	83 b8 28 80 1c f0 00 	cmpl   $0x0,-0xfe37fd8(%eax)
f0104908:	75 24                	jne    f010492e <trap+0x68>
f010490a:	c7 44 24 0c 48 7f 10 	movl   $0xf0107f48,0xc(%esp)
f0104911:	f0 
f0104912:	c7 44 24 08 33 7a 10 	movl   $0xf0107a33,0x8(%esp)
f0104919:	f0 
f010491a:	c7 44 24 04 4e 01 00 	movl   $0x14e,0x4(%esp)
f0104921:	00 
f0104922:	c7 04 24 3c 7f 10 f0 	movl   $0xf0107f3c,(%esp)
f0104929:	e8 12 b7 ff ff       	call   f0100040 <_panic>

		// Garbage collect if current enviroment is a zombie
		if (curenv->env_status == ENV_DYING) {
f010492e:	e8 60 1c 00 00       	call   f0106593 <cpunum>
f0104933:	6b c0 74             	imul   $0x74,%eax,%eax
f0104936:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f010493c:	83 78 54 01          	cmpl   $0x1,0x54(%eax)
f0104940:	75 2d                	jne    f010496f <trap+0xa9>
			env_free(curenv);
f0104942:	e8 4c 1c 00 00       	call   f0106593 <cpunum>
f0104947:	6b c0 74             	imul   $0x74,%eax,%eax
f010494a:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104950:	89 04 24             	mov    %eax,(%esp)
f0104953:	e8 b1 f0 ff ff       	call   f0103a09 <env_free>
			curenv = NULL;
f0104958:	e8 36 1c 00 00       	call   f0106593 <cpunum>
f010495d:	6b c0 74             	imul   $0x74,%eax,%eax
f0104960:	c7 80 28 80 1c f0 00 	movl   $0x0,-0xfe37fd8(%eax)
f0104967:	00 00 00 
			sched_yield();
f010496a:	e8 41 02 00 00       	call   f0104bb0 <sched_yield>
		}

		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		curenv->env_tf = *tf;
f010496f:	e8 1f 1c 00 00       	call   f0106593 <cpunum>
f0104974:	6b c0 74             	imul   $0x74,%eax,%eax
f0104977:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f010497d:	b9 11 00 00 00       	mov    $0x11,%ecx
f0104982:	89 c7                	mov    %eax,%edi
f0104984:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f0104986:	e8 08 1c 00 00       	call   f0106593 <cpunum>
f010498b:	6b c0 74             	imul   $0x74,%eax,%eax
f010498e:	8b b0 28 80 1c f0    	mov    -0xfe37fd8(%eax),%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f0104994:	89 35 60 7a 1c f0    	mov    %esi,0xf01c7a60
	// LAB 3: Your code here.

	// Handle spurious interrupts
	// The hardware sometimes raises these because of noise on the
	// IRQ line or other reasons. We don't care.
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_SPURIOUS) {
f010499a:	8b 46 28             	mov    0x28(%esi),%eax
f010499d:	83 f8 27             	cmp    $0x27,%eax
f01049a0:	75 19                	jne    f01049bb <trap+0xf5>
		cprintf("Spurious interrupt on irq 7\n");
f01049a2:	c7 04 24 4f 7f 10 f0 	movl   $0xf0107f4f,(%esp)
f01049a9:	e8 d8 f4 ff ff       	call   f0103e86 <cprintf>
		print_trapframe(tf);
f01049ae:	89 34 24             	mov    %esi,(%esp)
f01049b1:	e8 dd fb ff ff       	call   f0104593 <print_trapframe>
f01049b6:	e9 9e 00 00 00       	jmp    f0104a59 <trap+0x193>
		return;
	}
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_TIMER) {
f01049bb:	83 f8 20             	cmp    $0x20,%eax
f01049be:	66 90                	xchg   %ax,%ax
f01049c0:	75 0a                	jne    f01049cc <trap+0x106>
        		lapic_eoi();
f01049c2:	e8 01 1d 00 00       	call   f01066c8 <lapic_eoi>
        		sched_yield();
f01049c7:	e8 e4 01 00 00       	call   f0104bb0 <sched_yield>
  	  }
	// Handle clock interrupts. Don't forget to acknowledge the
	// interrupt using lapic_eoi() before calling the scheduler!
	// LAB 4: Your code here.

	if(tf->tf_trapno==T_PGFLT)
f01049cc:	83 f8 0e             	cmp    $0xe,%eax
f01049cf:	90                   	nop
f01049d0:	75 08                	jne    f01049da <trap+0x114>
	{
		page_fault_handler(tf);
f01049d2:	89 34 24             	mov    %esi,(%esp)
f01049d5:	e8 56 fd ff ff       	call   f0104730 <page_fault_handler>
		return;
	}
	if(tf->tf_trapno==T_BRKPT)
f01049da:	83 f8 03             	cmp    $0x3,%eax
f01049dd:	75 0a                	jne    f01049e9 <trap+0x123>
	{
		monitor(tf);
f01049df:	89 34 24             	mov    %esi,(%esp)
f01049e2:	e8 2b c0 ff ff       	call   f0100a12 <monitor>
f01049e7:	eb 70                	jmp    f0104a59 <trap+0x193>
		return;
	}
	if(tf->tf_trapno==T_SYSCALL)
f01049e9:	83 f8 30             	cmp    $0x30,%eax
f01049ec:	75 32                	jne    f0104a20 <trap+0x15a>
	{
		tf->tf_regs.reg_eax=syscall(tf->tf_regs.reg_eax,tf->tf_regs.reg_edx,tf->tf_regs.reg_ecx,tf->tf_regs.reg_ebx,tf->tf_regs.reg_edi,tf->tf_regs.reg_esi);
f01049ee:	8b 46 04             	mov    0x4(%esi),%eax
f01049f1:	89 44 24 14          	mov    %eax,0x14(%esp)
f01049f5:	8b 06                	mov    (%esi),%eax
f01049f7:	89 44 24 10          	mov    %eax,0x10(%esp)
f01049fb:	8b 46 10             	mov    0x10(%esi),%eax
f01049fe:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104a02:	8b 46 18             	mov    0x18(%esi),%eax
f0104a05:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104a09:	8b 46 14             	mov    0x14(%esi),%eax
f0104a0c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104a10:	8b 46 1c             	mov    0x1c(%esi),%eax
f0104a13:	89 04 24             	mov    %eax,(%esp)
f0104a16:	e8 b5 02 00 00       	call   f0104cd0 <syscall>
f0104a1b:	89 46 1c             	mov    %eax,0x1c(%esi)
f0104a1e:	eb 39                	jmp    f0104a59 <trap+0x193>
	    return;
	}
	// Unexpected trap: The user process or the kernel has a bug.

	if (tf->tf_cs == GD_KT)
f0104a20:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f0104a25:	75 1c                	jne    f0104a43 <trap+0x17d>
		panic("unhandled trap in kernel");
f0104a27:	c7 44 24 08 6c 7f 10 	movl   $0xf0107f6c,0x8(%esp)
f0104a2e:	f0 
f0104a2f:	c7 44 24 04 2a 01 00 	movl   $0x12a,0x4(%esp)
f0104a36:	00 
f0104a37:	c7 04 24 3c 7f 10 f0 	movl   $0xf0107f3c,(%esp)
f0104a3e:	e8 fd b5 ff ff       	call   f0100040 <_panic>
	else {
		env_destroy(curenv);
f0104a43:	e8 4b 1b 00 00       	call   f0106593 <cpunum>
f0104a48:	6b c0 74             	imul   $0x74,%eax,%eax
f0104a4b:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104a51:	89 04 24             	mov    %eax,(%esp)
f0104a54:	e8 7b f1 ff ff       	call   f0103bd4 <env_destroy>
	trap_dispatch(tf);

	// If we made it to this point, then no other environment was
	// scheduled, so we should return to the current environment
	// if doing so makes sense.
	if (curenv && curenv->env_status == ENV_RUNNING)
f0104a59:	e8 35 1b 00 00       	call   f0106593 <cpunum>
f0104a5e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104a61:	83 b8 28 80 1c f0 00 	cmpl   $0x0,-0xfe37fd8(%eax)
f0104a68:	74 2a                	je     f0104a94 <trap+0x1ce>
f0104a6a:	e8 24 1b 00 00       	call   f0106593 <cpunum>
f0104a6f:	6b c0 74             	imul   $0x74,%eax,%eax
f0104a72:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104a78:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0104a7c:	75 16                	jne    f0104a94 <trap+0x1ce>
		env_run(curenv);
f0104a7e:	e8 10 1b 00 00       	call   f0106593 <cpunum>
f0104a83:	6b c0 74             	imul   $0x74,%eax,%eax
f0104a86:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104a8c:	89 04 24             	mov    %eax,(%esp)
f0104a8f:	e8 e1 f1 ff ff       	call   f0103c75 <env_run>
	else
		sched_yield();
f0104a94:	e8 17 01 00 00       	call   f0104bb0 <sched_yield>
f0104a99:	90                   	nop

f0104a9a <dividezero_handler>:
.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
f0104a9a:	6a 00                	push   $0x0
f0104a9c:	6a 00                	push   $0x0
f0104a9e:	e9 e5 00 00 00       	jmp    f0104b88 <_alltraps>
f0104aa3:	90                   	nop

f0104aa4 <nmi_handler>:
TRAPHANDLER_NOEC(nmi_handler, 0x2)
f0104aa4:	6a 00                	push   $0x0
f0104aa6:	6a 02                	push   $0x2
f0104aa8:	e9 db 00 00 00       	jmp    f0104b88 <_alltraps>
f0104aad:	90                   	nop

f0104aae <breakpoint_handler>:
TRAPHANDLER_NOEC(breakpoint_handler, 0x3)
f0104aae:	6a 00                	push   $0x0
f0104ab0:	6a 03                	push   $0x3
f0104ab2:	e9 d1 00 00 00       	jmp    f0104b88 <_alltraps>
f0104ab7:	90                   	nop

f0104ab8 <overflow_handler>:
TRAPHANDLER_NOEC(overflow_handler, 0x4)
f0104ab8:	6a 00                	push   $0x0
f0104aba:	6a 04                	push   $0x4
f0104abc:	e9 c7 00 00 00       	jmp    f0104b88 <_alltraps>
f0104ac1:	90                   	nop

f0104ac2 <bdrgeexceed_handler>:
TRAPHANDLER_NOEC(bdrgeexceed_handler, 0x5)
f0104ac2:	6a 00                	push   $0x0
f0104ac4:	6a 05                	push   $0x5
f0104ac6:	e9 bd 00 00 00       	jmp    f0104b88 <_alltraps>
f0104acb:	90                   	nop

f0104acc <invalidop_handler>:
TRAPHANDLER_NOEC(invalidop_handler, 0x6)
f0104acc:	6a 00                	push   $0x0
f0104ace:	6a 06                	push   $0x6
f0104ad0:	e9 b3 00 00 00       	jmp    f0104b88 <_alltraps>
f0104ad5:	90                   	nop

f0104ad6 <nomathcopro_handler>:
TRAPHANDLER_NOEC(nomathcopro_handler, 0x7)
f0104ad6:	6a 00                	push   $0x0
f0104ad8:	6a 07                	push   $0x7
f0104ada:	e9 a9 00 00 00       	jmp    f0104b88 <_alltraps>
f0104adf:	90                   	nop

f0104ae0 <dbfault_handler>:
TRAPHANDLER(dbfault_handler, 0x8)
f0104ae0:	6a 08                	push   $0x8
f0104ae2:	e9 a1 00 00 00       	jmp    f0104b88 <_alltraps>
f0104ae7:	90                   	nop

f0104ae8 <invalidTSS_handler>:
TRAPHANDLER(invalidTSS_handler, 0xA)
f0104ae8:	6a 0a                	push   $0xa
f0104aea:	e9 99 00 00 00       	jmp    f0104b88 <_alltraps>
f0104aef:	90                   	nop

f0104af0 <sgmtnotpresent_handler>:
TRAPHANDLER(sgmtnotpresent_handler, 0xB)
f0104af0:	6a 0b                	push   $0xb
f0104af2:	e9 91 00 00 00       	jmp    f0104b88 <_alltraps>
f0104af7:	90                   	nop

f0104af8 <stacksgmtfault_handler>:
TRAPHANDLER(stacksgmtfault_handler,0xC)
f0104af8:	6a 0c                	push   $0xc
f0104afa:	e9 89 00 00 00       	jmp    f0104b88 <_alltraps>
f0104aff:	90                   	nop

f0104b00 <generalprotection_handler>:
TRAPHANDLER(generalprotection_handler, 0xD)
f0104b00:	6a 0d                	push   $0xd
f0104b02:	e9 81 00 00 00       	jmp    f0104b88 <_alltraps>
f0104b07:	90                   	nop

f0104b08 <pagefault_handler>:
TRAPHANDLER(pagefault_handler, 0xE)
f0104b08:	6a 0e                	push   $0xe
f0104b0a:	eb 7c                	jmp    f0104b88 <_alltraps>

f0104b0c <FPUerror_handler>:
TRAPHANDLER_NOEC(FPUerror_handler, 0x10)
f0104b0c:	6a 00                	push   $0x0
f0104b0e:	6a 10                	push   $0x10
f0104b10:	eb 76                	jmp    f0104b88 <_alltraps>

f0104b12 <alignmentcheck_handler>:
TRAPHANDLER(alignmentcheck_handler, 0x11)
f0104b12:	6a 11                	push   $0x11
f0104b14:	eb 72                	jmp    f0104b88 <_alltraps>

f0104b16 <machinecheck_handler>:
TRAPHANDLER_NOEC(machinecheck_handler, 0x12)
f0104b16:	6a 00                	push   $0x0
f0104b18:	6a 12                	push   $0x12
f0104b1a:	eb 6c                	jmp    f0104b88 <_alltraps>

f0104b1c <SIMDFPexception_handler>:
TRAPHANDLER_NOEC(SIMDFPexception_handler, 0x13)
f0104b1c:	6a 00                	push   $0x0
f0104b1e:	6a 13                	push   $0x13
f0104b20:	eb 66                	jmp    f0104b88 <_alltraps>

f0104b22 <systemcall_handler>:
TRAPHANDLER_NOEC(systemcall_handler, 0x30)
f0104b22:	6a 00                	push   $0x0
f0104b24:	6a 30                	push   $0x30
f0104b26:	eb 60                	jmp    f0104b88 <_alltraps>

f0104b28 <t_irq0>:


TRAPHANDLER_NOEC(t_irq0, IRQ_OFFSET + 0);
f0104b28:	6a 00                	push   $0x0
f0104b2a:	6a 20                	push   $0x20
f0104b2c:	eb 5a                	jmp    f0104b88 <_alltraps>

f0104b2e <t_irq1>:
TRAPHANDLER_NOEC(t_irq1, IRQ_OFFSET + 1);
f0104b2e:	6a 00                	push   $0x0
f0104b30:	6a 21                	push   $0x21
f0104b32:	eb 54                	jmp    f0104b88 <_alltraps>

f0104b34 <t_irq2>:
TRAPHANDLER_NOEC(t_irq2, IRQ_OFFSET + 2);
f0104b34:	6a 00                	push   $0x0
f0104b36:	6a 22                	push   $0x22
f0104b38:	eb 4e                	jmp    f0104b88 <_alltraps>

f0104b3a <t_irq3>:
TRAPHANDLER_NOEC(t_irq3, IRQ_OFFSET + 3);
f0104b3a:	6a 00                	push   $0x0
f0104b3c:	6a 23                	push   $0x23
f0104b3e:	eb 48                	jmp    f0104b88 <_alltraps>

f0104b40 <t_irq4>:
TRAPHANDLER_NOEC(t_irq4, IRQ_OFFSET + 4);
f0104b40:	6a 00                	push   $0x0
f0104b42:	6a 24                	push   $0x24
f0104b44:	eb 42                	jmp    f0104b88 <_alltraps>

f0104b46 <t_irq5>:
TRAPHANDLER_NOEC(t_irq5, IRQ_OFFSET + 5);
f0104b46:	6a 00                	push   $0x0
f0104b48:	6a 25                	push   $0x25
f0104b4a:	eb 3c                	jmp    f0104b88 <_alltraps>

f0104b4c <t_irq6>:
TRAPHANDLER_NOEC(t_irq6, IRQ_OFFSET + 6);
f0104b4c:	6a 00                	push   $0x0
f0104b4e:	6a 26                	push   $0x26
f0104b50:	eb 36                	jmp    f0104b88 <_alltraps>

f0104b52 <t_irq7>:
TRAPHANDLER_NOEC(t_irq7, IRQ_OFFSET + 7);
f0104b52:	6a 00                	push   $0x0
f0104b54:	6a 27                	push   $0x27
f0104b56:	eb 30                	jmp    f0104b88 <_alltraps>

f0104b58 <t_irq8>:
TRAPHANDLER_NOEC(t_irq8, IRQ_OFFSET + 8);
f0104b58:	6a 00                	push   $0x0
f0104b5a:	6a 28                	push   $0x28
f0104b5c:	eb 2a                	jmp    f0104b88 <_alltraps>

f0104b5e <t_irq9>:
TRAPHANDLER_NOEC(t_irq9, IRQ_OFFSET + 9);
f0104b5e:	6a 00                	push   $0x0
f0104b60:	6a 29                	push   $0x29
f0104b62:	eb 24                	jmp    f0104b88 <_alltraps>

f0104b64 <t_irq10>:
TRAPHANDLER_NOEC(t_irq10, IRQ_OFFSET + 10);
f0104b64:	6a 00                	push   $0x0
f0104b66:	6a 2a                	push   $0x2a
f0104b68:	eb 1e                	jmp    f0104b88 <_alltraps>

f0104b6a <t_irq11>:
TRAPHANDLER_NOEC(t_irq11, IRQ_OFFSET + 11);
f0104b6a:	6a 00                	push   $0x0
f0104b6c:	6a 2b                	push   $0x2b
f0104b6e:	eb 18                	jmp    f0104b88 <_alltraps>

f0104b70 <t_irq12>:
TRAPHANDLER_NOEC(t_irq12, IRQ_OFFSET + 12);
f0104b70:	6a 00                	push   $0x0
f0104b72:	6a 2c                	push   $0x2c
f0104b74:	eb 12                	jmp    f0104b88 <_alltraps>

f0104b76 <t_irq13>:
TRAPHANDLER_NOEC(t_irq13, IRQ_OFFSET + 13);
f0104b76:	6a 00                	push   $0x0
f0104b78:	6a 2d                	push   $0x2d
f0104b7a:	eb 0c                	jmp    f0104b88 <_alltraps>

f0104b7c <t_irq14>:
TRAPHANDLER_NOEC(t_irq14, IRQ_OFFSET + 14);
f0104b7c:	6a 00                	push   $0x0
f0104b7e:	6a 2e                	push   $0x2e
f0104b80:	eb 06                	jmp    f0104b88 <_alltraps>

f0104b82 <t_irq15>:
TRAPHANDLER_NOEC(t_irq15, IRQ_OFFSET + 15);
f0104b82:	6a 00                	push   $0x0
f0104b84:	6a 2f                	push   $0x2f
f0104b86:	eb 00                	jmp    f0104b88 <_alltraps>

f0104b88 <_alltraps>:
/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
	pushw $0
f0104b88:	66 6a 00             	pushw  $0x0
	pushw %ds
f0104b8b:	66 1e                	pushw  %ds
	pushw $0
f0104b8d:	66 6a 00             	pushw  $0x0
	pushw %es
f0104b90:	66 06                	pushw  %es
	pushal
f0104b92:	60                   	pusha  
	pushl %esp
f0104b93:	54                   	push   %esp
	movw $(GD_KD),%ax
f0104b94:	66 b8 10 00          	mov    $0x10,%ax
	movw %ax,%ds
f0104b98:	8e d8                	mov    %eax,%ds
	movw %ax,%es
f0104b9a:	8e c0                	mov    %eax,%es
	call trap
f0104b9c:	e8 25 fd ff ff       	call   f01048c6 <trap>
f0104ba1:	66 90                	xchg   %ax,%ax
f0104ba3:	66 90                	xchg   %ax,%ax
f0104ba5:	66 90                	xchg   %ax,%ax
f0104ba7:	66 90                	xchg   %ax,%ax
f0104ba9:	66 90                	xchg   %ax,%ax
f0104bab:	66 90                	xchg   %ax,%ax
f0104bad:	66 90                	xchg   %ax,%ax
f0104baf:	90                   	nop

f0104bb0 <sched_yield>:
#include <kern/monitor.h>

// Choose a user environment to run and run it.
void
sched_yield(void)
{
f0104bb0:	55                   	push   %ebp
f0104bb1:	89 e5                	mov    %esp,%ebp
f0104bb3:	57                   	push   %edi
f0104bb4:	56                   	push   %esi
f0104bb5:	53                   	push   %ebx
f0104bb6:	83 ec 1c             	sub    $0x1c,%esp
	// Search through 'envs' for an ENV_RUNNABLE environment in
	// circular fashion starting just after the env this CPU was
	// last running.  Switch to the first such environment found.
	//
	int start;
	struct Env * curr = thiscpu->cpu_env;
f0104bb9:	e8 d5 19 00 00       	call   f0106593 <cpunum>
f0104bbe:	6b c0 74             	imul   $0x74,%eax,%eax
f0104bc1:	8b b0 28 80 1c f0    	mov    -0xfe37fd8(%eax),%esi
	if(curr == NULL){
f0104bc7:	85 f6                	test   %esi,%esi
f0104bc9:	0f 84 df 00 00 00    	je     f0104cae <sched_yield+0xfe>
		start = 0;
	}else{
		start = ENVX(curr->env_id ) ;
f0104bcf:	8b 7e 48             	mov    0x48(%esi),%edi
f0104bd2:	81 e7 ff 03 00 00    	and    $0x3ff,%edi
f0104bd8:	e9 d6 00 00 00       	jmp    f0104cb3 <sched_yield+0x103>
	}
	for(i=1;i<NENV;i++){
		start = (start+1) % NENV;
f0104bdd:	8d 47 01             	lea    0x1(%edi),%eax
f0104be0:	99                   	cltd   
f0104be1:	c1 ea 16             	shr    $0x16,%edx
f0104be4:	01 d0                	add    %edx,%eax
f0104be6:	25 ff 03 00 00       	and    $0x3ff,%eax
f0104beb:	29 d0                	sub    %edx,%eax
f0104bed:	89 c7                	mov    %eax,%edi
		if (envs[start].env_type != ENV_TYPE_IDLE && (envs[start].env_status == ENV_RUNNABLE )){
f0104bef:	6b c0 7c             	imul   $0x7c,%eax,%eax
f0104bf2:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f0104bf5:	83 7a 50 01          	cmpl   $0x1,0x50(%edx)
f0104bf9:	74 0e                	je     f0104c09 <sched_yield+0x59>
f0104bfb:	83 7a 54 02          	cmpl   $0x2,0x54(%edx)
f0104bff:	75 08                	jne    f0104c09 <sched_yield+0x59>
			env_run(&envs[start]);
f0104c01:	89 14 24             	mov    %edx,(%esp)
f0104c04:	e8 6c f0 ff ff       	call   f0103c75 <env_run>
	if(curr == NULL){
		start = 0;
	}else{
		start = ENVX(curr->env_id ) ;
	}
	for(i=1;i<NENV;i++){
f0104c09:	83 e9 01             	sub    $0x1,%ecx
f0104c0c:	75 cf                	jne    f0104bdd <sched_yield+0x2d>
		start = (start+1) % NENV;
		if (envs[start].env_type != ENV_TYPE_IDLE && (envs[start].env_status == ENV_RUNNABLE )){
			env_run(&envs[start]);
		}
	}
	 if (curr && curr->env_status == ENV_RUNNING) {
f0104c0e:	85 f6                	test   %esi,%esi
f0104c10:	74 06                	je     f0104c18 <sched_yield+0x68>
f0104c12:	83 7e 54 03          	cmpl   $0x3,0x54(%esi)
f0104c16:	74 09                	je     f0104c21 <sched_yield+0x71>
f0104c18:	89 d8                	mov    %ebx,%eax
	}else{
		start = ENVX(curr->env_id ) ;
	}
	for(i=1;i<NENV;i++){
		start = (start+1) % NENV;
		if (envs[start].env_type != ENV_TYPE_IDLE && (envs[start].env_status == ENV_RUNNABLE )){
f0104c1a:	ba 00 00 00 00       	mov    $0x0,%edx
f0104c1f:	eb 08                	jmp    f0104c29 <sched_yield+0x79>
			env_run(&envs[start]);
		}
	}
	 if (curr && curr->env_status == ENV_RUNNING) {
       		 env_run(curr);
f0104c21:	89 34 24             	mov    %esi,(%esp)
f0104c24:	e8 4c f0 ff ff       	call   f0103c75 <env_run>

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104c29:	83 78 50 01          	cmpl   $0x1,0x50(%eax)
f0104c2d:	74 0b                	je     f0104c3a <sched_yield+0x8a>
		    (envs[i].env_status == ENV_RUNNABLE ||
f0104c2f:	8b 70 54             	mov    0x54(%eax),%esi
f0104c32:	8d 4e fe             	lea    -0x2(%esi),%ecx

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104c35:	83 f9 01             	cmp    $0x1,%ecx
f0104c38:	76 10                	jbe    f0104c4a <sched_yield+0x9a>
	// LAB 4: Your code here.

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0104c3a:	83 c2 01             	add    $0x1,%edx
f0104c3d:	83 c0 7c             	add    $0x7c,%eax
f0104c40:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104c46:	75 e1                	jne    f0104c29 <sched_yield+0x79>
f0104c48:	eb 08                	jmp    f0104c52 <sched_yield+0xa2>
		if (envs[i].env_type != ENV_TYPE_IDLE &&
		    (envs[i].env_status == ENV_RUNNABLE ||
		     envs[i].env_status == ENV_RUNNING))
			break;
	}
	if (i == NENV) {
f0104c4a:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104c50:	75 1a                	jne    f0104c6c <sched_yield+0xbc>
		cprintf("No more runnable environments!\n");
f0104c52:	c7 04 24 70 81 10 f0 	movl   $0xf0108170,(%esp)
f0104c59:	e8 28 f2 ff ff       	call   f0103e86 <cprintf>
		while (1)
			monitor(NULL);
f0104c5e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0104c65:	e8 a8 bd ff ff       	call   f0100a12 <monitor>
f0104c6a:	eb f2                	jmp    f0104c5e <sched_yield+0xae>
	}

	// Run this CPU's idle environment when nothing else is runnable.
	idle = &envs[cpunum()];
f0104c6c:	e8 22 19 00 00       	call   f0106593 <cpunum>
f0104c71:	6b c0 7c             	imul   $0x7c,%eax,%eax
f0104c74:	01 c3                	add    %eax,%ebx
	if (!(idle->env_status == ENV_RUNNABLE || idle->env_status == ENV_RUNNING))
f0104c76:	8b 43 54             	mov    0x54(%ebx),%eax
f0104c79:	83 e8 02             	sub    $0x2,%eax
f0104c7c:	83 f8 01             	cmp    $0x1,%eax
f0104c7f:	76 25                	jbe    f0104ca6 <sched_yield+0xf6>
		panic("CPU %d: No idle environment!", cpunum());
f0104c81:	e8 0d 19 00 00       	call   f0106593 <cpunum>
f0104c86:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104c8a:	c7 44 24 08 90 81 10 	movl   $0xf0108190,0x8(%esp)
f0104c91:	f0 
f0104c92:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
f0104c99:	00 
f0104c9a:	c7 04 24 ad 81 10 f0 	movl   $0xf01081ad,(%esp)
f0104ca1:	e8 9a b3 ff ff       	call   f0100040 <_panic>
	env_run(idle);
f0104ca6:	89 1c 24             	mov    %ebx,(%esp)
f0104ca9:	e8 c7 ef ff ff       	call   f0103c75 <env_run>
	// last running.  Switch to the first such environment found.
	//
	int start;
	struct Env * curr = thiscpu->cpu_env;
	if(curr == NULL){
		start = 0;
f0104cae:	bf 00 00 00 00       	mov    $0x0,%edi
	}else{
		start = ENVX(curr->env_id ) ;
	}
	for(i=1;i<NENV;i++){
		start = (start+1) % NENV;
		if (envs[start].env_type != ENV_TYPE_IDLE && (envs[start].env_status == ENV_RUNNABLE )){
f0104cb3:	8b 1d 48 72 1c f0    	mov    0xf01c7248,%ebx
f0104cb9:	b9 ff 03 00 00       	mov    $0x3ff,%ecx
f0104cbe:	e9 1a ff ff ff       	jmp    f0104bdd <sched_yield+0x2d>
f0104cc3:	66 90                	xchg   %ax,%ax
f0104cc5:	66 90                	xchg   %ax,%ax
f0104cc7:	66 90                	xchg   %ax,%ax
f0104cc9:	66 90                	xchg   %ax,%ax
f0104ccb:	66 90                	xchg   %ax,%ax
f0104ccd:	66 90                	xchg   %ax,%ax
f0104ccf:	90                   	nop

f0104cd0 <syscall>:
}

// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
f0104cd0:	55                   	push   %ebp
f0104cd1:	89 e5                	mov    %esp,%ebp
f0104cd3:	57                   	push   %edi
f0104cd4:	56                   	push   %esi
f0104cd5:	53                   	push   %ebx
f0104cd6:	83 ec 2c             	sub    $0x2c,%esp
f0104cd9:	8b 45 08             	mov    0x8(%ebp),%eax
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
	switch(syscallno){
f0104cdc:	83 f8 0d             	cmp    $0xd,%eax
f0104cdf:	0f 87 47 05 00 00    	ja     f010522c <syscall+0x55c>
f0104ce5:	ff 24 85 c0 81 10 f0 	jmp    *-0xfef7e40(,%eax,4)

// Deschedule current environment and pick a different one to run.
static void
sys_yield(void)
{
	sched_yield();
f0104cec:	e8 bf fe ff ff       	call   f0104bb0 <sched_yield>
static void
sys_cputs(const char *s, size_t len)
{
	// Check that the user has permission to read memory [s, s+len).
	// Destroy the environment if not.
	user_mem_assert(curenv,s,len,0);
f0104cf1:	e8 9d 18 00 00       	call   f0106593 <cpunum>
f0104cf6:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104cfd:	00 
f0104cfe:	8b 7d 10             	mov    0x10(%ebp),%edi
f0104d01:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0104d05:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104d08:	89 74 24 04          	mov    %esi,0x4(%esp)
f0104d0c:	6b c0 74             	imul   $0x74,%eax,%eax
f0104d0f:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104d15:	89 04 24             	mov    %eax,(%esp)
f0104d18:	e8 f3 e7 ff ff       	call   f0103510 <user_mem_assert>
	// LAB 3: Your code here.
	// Print the string supplied by the user.
	cprintf("%.*s", len, s);
f0104d1d:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104d20:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104d24:	8b 45 10             	mov    0x10(%ebp),%eax
f0104d27:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104d2b:	c7 04 24 ba 81 10 f0 	movl   $0xf01081ba,(%esp)
f0104d32:	e8 4f f1 ff ff       	call   f0103e86 <cprintf>
		case(SYS_yield):
			sys_yield();
			return 0;
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
f0104d37:	b8 00 00 00 00       	mov    $0x0,%eax
f0104d3c:	e9 f7 04 00 00       	jmp    f0105238 <syscall+0x568>
//	-E_NO_MEM if there's no memory to allocate the new page,
//		or to allocate any necessary page tables.
static int
sys_page_alloc(envid_t envid, void *va, int perm)
{
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
f0104d41:	8b 45 14             	mov    0x14(%ebp),%eax
f0104d44:	25 fd f1 ff ff       	and    $0xfffff1fd,%eax
f0104d49:	83 f8 05             	cmp    $0x5,%eax
f0104d4c:	75 70                	jne    f0104dbe <syscall+0xee>
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
	struct Page* pp = page_alloc(ALLOC_ZERO);
f0104d4e:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0104d55:	e8 cc c3 ff ff       	call   f0101126 <page_alloc>
f0104d5a:	89 c3                	mov    %eax,%ebx
	if(pp == NULL) // out of memory
f0104d5c:	85 c0                	test   %eax,%eax
f0104d5e:	74 68                	je     f0104dc8 <syscall+0xf8>
		return -E_NO_MEM;

	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
f0104d60:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104d67:	00 
f0104d68:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104d6b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104d6f:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104d72:	89 04 24             	mov    %eax,(%esp)
f0104d75:	e8 ee e7 ff ff       	call   f0103568 <envid2env>
f0104d7a:	89 c1                	mov    %eax,%ecx
	if(r != 0) // any bad env
f0104d7c:	85 c9                	test   %ecx,%ecx
f0104d7e:	0f 85 b4 04 00 00    	jne    f0105238 <syscall+0x568>
		return r;

	//if va >= UTOP, or va is not page-aligned.
	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
f0104d84:	81 7d 10 ff ff bf ee 	cmpl   $0xeebfffff,0x10(%ebp)
f0104d8b:	77 45                	ja     f0104dd2 <syscall+0x102>
f0104d8d:	f7 45 10 ff 0f 00 00 	testl  $0xfff,0x10(%ebp)
f0104d94:	75 46                	jne    f0104ddc <syscall+0x10c>
		return -E_INVAL;

	r = page_insert(target_env->env_pgdir, pp, va, perm | PTE_P);
f0104d96:	8b 45 14             	mov    0x14(%ebp),%eax
f0104d99:	83 c8 01             	or     $0x1,%eax
f0104d9c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104da0:	8b 45 10             	mov    0x10(%ebp),%eax
f0104da3:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104da7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104dab:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104dae:	8b 40 60             	mov    0x60(%eax),%eax
f0104db1:	89 04 24             	mov    %eax,(%esp)
f0104db4:	e8 a7 c6 ff ff       	call   f0101460 <page_insert>
f0104db9:	e9 7a 04 00 00       	jmp    f0105238 <syscall+0x568>
sys_page_alloc(envid_t envid, void *va, int perm)
{
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
f0104dbe:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0104dc3:	e9 70 04 00 00       	jmp    f0105238 <syscall+0x568>
	struct Page* pp = page_alloc(ALLOC_ZERO);
	if(pp == NULL) // out of memory
		return -E_NO_MEM;
f0104dc8:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
f0104dcd:	e9 66 04 00 00       	jmp    f0105238 <syscall+0x568>
	if(r != 0) // any bad env
		return r;

	//if va >= UTOP, or va is not page-aligned.
	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
		return -E_INVAL;
f0104dd2:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0104dd7:	e9 5c 04 00 00       	jmp    f0105238 <syscall+0x568>
f0104ddc:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
			return 0;
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case (SYS_page_alloc):
			return sys_page_alloc(a1, (void*)a2, a3);
f0104de1:	e9 52 04 00 00       	jmp    f0105238 <syscall+0x568>
// Read a character from the system console without blocking.
// Returns the character, or 0 if there is no input waiting.
static int
sys_cgetc(void)
{
	return cons_getc();
f0104de6:	e8 ca b8 ff ff       	call   f01006b5 <cons_getc>
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case (SYS_page_alloc):
			return sys_page_alloc(a1, (void*)a2, a3);
		case(SYS_cgetc):
			return sys_cgetc();
f0104deb:	e9 48 04 00 00       	jmp    f0105238 <syscall+0x568>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f0104df0:	e8 9e 17 00 00       	call   f0106593 <cpunum>
f0104df5:	6b c0 74             	imul   $0x74,%eax,%eax
f0104df8:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104dfe:	8b 40 48             	mov    0x48(%eax),%eax
		case (SYS_page_alloc):
			return sys_page_alloc(a1, (void*)a2, a3);
		case(SYS_cgetc):
			return sys_cgetc();
		case(SYS_getenvid):
			return sys_getenvid();
f0104e01:	e9 32 04 00 00       	jmp    f0105238 <syscall+0x568>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f0104e06:	e8 88 17 00 00       	call   f0106593 <cpunum>
f0104e0b:	6b c0 74             	imul   $0x74,%eax,%eax
f0104e0e:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0104e14:	8b 58 48             	mov    0x48(%eax),%ebx
	// from the current environment -- but tweaked so sys_exofork
	// will appear to return 0.
	struct Env* new_env;
	struct Env* this_env;
	envid_t this_envid = sys_getenvid();
	envid2env(this_envid,&this_env,1);
f0104e17:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104e1e:	00 
f0104e1f:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104e22:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104e26:	89 1c 24             	mov    %ebx,(%esp)
f0104e29:	e8 3a e7 ff ff       	call   f0103568 <envid2env>
	int r = env_alloc(&new_env,this_envid);
f0104e2e:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104e32:	8d 45 e0             	lea    -0x20(%ebp),%eax
f0104e35:	89 04 24             	mov    %eax,(%esp)
f0104e38:	e8 33 e8 ff ff       	call   f0103670 <env_alloc>
	if(r!=0)
		return r;
f0104e3d:	89 c2                	mov    %eax,%edx
	struct Env* new_env;
	struct Env* this_env;
	envid_t this_envid = sys_getenvid();
	envid2env(this_envid,&this_env,1);
	int r = env_alloc(&new_env,this_envid);
	if(r!=0)
f0104e3f:	85 c0                	test   %eax,%eax
f0104e41:	75 21                	jne    f0104e64 <syscall+0x194>
		return r;

	new_env->env_tf = this_env->env_tf;
f0104e43:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0104e46:	b9 11 00 00 00       	mov    $0x11,%ecx
f0104e4b:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0104e4e:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
	new_env->env_tf.tf_regs.reg_eax = 0;
f0104e50:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104e53:	c7 40 1c 00 00 00 00 	movl   $0x0,0x1c(%eax)
	new_env->env_status = ENV_NOT_RUNNABLE;
f0104e5a:	c7 40 54 04 00 00 00 	movl   $0x4,0x54(%eax)
	//cprintf("alloc env number %d",new_env->env_id);
	return new_env->env_id;
f0104e61:	8b 50 48             	mov    0x48(%eax),%edx
		case(SYS_cgetc):
			return sys_cgetc();
		case(SYS_getenvid):
			return sys_getenvid();
		case (SYS_exofork):
			return sys_exofork();
f0104e64:	89 d0                	mov    %edx,%eax
f0104e66:	e9 cd 03 00 00       	jmp    f0105238 <syscall+0x568>
	// envid to a struct Env.
	// You should set envid2env's third argument to 1, which will
	// check whether the current environment has permission to set
	// envid's status.
	struct  Env* this_env;
	int r = envid2env(envid,&this_env,1);
f0104e6b:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104e72:	00 
f0104e73:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104e76:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104e7a:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104e7d:	89 04 24             	mov    %eax,(%esp)
f0104e80:	e8 e3 e6 ff ff       	call   f0103568 <envid2env>
	if(r != 0)
		return r;
f0104e85:	89 c2                	mov    %eax,%edx
	// You should set envid2env's third argument to 1, which will
	// check whether the current environment has permission to set
	// envid's status.
	struct  Env* this_env;
	int r = envid2env(envid,&this_env,1);
	if(r != 0)
f0104e87:	85 c0                	test   %eax,%eax
f0104e89:	75 21                	jne    f0104eac <syscall+0x1dc>
		return r;
	if((status != ENV_RUNNABLE) && (status != ENV_NOT_RUNNABLE))
f0104e8b:	83 7d 10 04          	cmpl   $0x4,0x10(%ebp)
f0104e8f:	74 06                	je     f0104e97 <syscall+0x1c7>
f0104e91:	83 7d 10 02          	cmpl   $0x2,0x10(%ebp)
f0104e95:	75 10                	jne    f0104ea7 <syscall+0x1d7>
		return -E_INVAL;
	this_env->env_status = status;
f0104e97:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104e9a:	8b 4d 10             	mov    0x10(%ebp),%ecx
f0104e9d:	89 48 54             	mov    %ecx,0x54(%eax)
	return 0;
f0104ea0:	ba 00 00 00 00       	mov    $0x0,%edx
f0104ea5:	eb 05                	jmp    f0104eac <syscall+0x1dc>
	struct  Env* this_env;
	int r = envid2env(envid,&this_env,1);
	if(r != 0)
		return r;
	if((status != ENV_RUNNABLE) && (status != ENV_NOT_RUNNABLE))
		return -E_INVAL;
f0104ea7:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
		case(SYS_getenvid):
			return sys_getenvid();
		case (SYS_exofork):
			return sys_exofork();
		case (SYS_env_set_status):
			return sys_env_set_status(a1, a2);
f0104eac:	89 d0                	mov    %edx,%eax
f0104eae:	e9 85 03 00 00       	jmp    f0105238 <syscall+0x568>
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104eb3:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104eba:	00 
f0104ebb:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104ebe:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104ec2:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104ec5:	89 04 24             	mov    %eax,(%esp)
f0104ec8:	e8 9b e6 ff ff       	call   f0103568 <envid2env>
		return r;
f0104ecd:	89 c2                	mov    %eax,%edx
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104ecf:	85 c0                	test   %eax,%eax
f0104ed1:	78 10                	js     f0104ee3 <syscall+0x213>
		return r;
	env_destroy(e);
f0104ed3:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104ed6:	89 04 24             	mov    %eax,(%esp)
f0104ed9:	e8 f6 ec ff ff       	call   f0103bd4 <env_destroy>
	return 0;
f0104ede:	ba 00 00 00 00       	mov    $0x0,%edx
		case (SYS_exofork):
			return sys_exofork();
		case (SYS_env_set_status):
			return sys_env_set_status(a1, a2);
		case(SYS_env_destroy):
			return sys_env_destroy((envid_t) a1);
f0104ee3:	89 d0                	mov    %edx,%eax
f0104ee5:	e9 4e 03 00 00       	jmp    f0105238 <syscall+0x568>
	//   page_insert() from kern/pmap.c.
	//   Again, most of the new code you write should be to check the
	//   parameters for correctness.
	//   Use the third argument to page_lookup() to
	//   check the current permissions on the page.
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
f0104eea:	8b 45 1c             	mov    0x1c(%ebp),%eax
f0104eed:	25 fd f1 ff ff       	and    $0xfffff1fd,%eax
f0104ef2:	83 f8 05             	cmp    $0x5,%eax
f0104ef5:	0f 85 be 00 00 00    	jne    f0104fb9 <syscall+0x2e9>
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;

	struct Env* srcenv, * dstenv;
	int r = envid2env(srcenvid, &srcenv, 1);
f0104efb:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104f02:	00 
f0104f03:	8d 45 dc             	lea    -0x24(%ebp),%eax
f0104f06:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104f0a:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104f0d:	89 04 24             	mov    %eax,(%esp)
f0104f10:	e8 53 e6 ff ff       	call   f0103568 <envid2env>
	if(r) return E_BAD_ENV;
f0104f15:	ba 02 00 00 00       	mov    $0x2,%edx
f0104f1a:	85 c0                	test   %eax,%eax
f0104f1c:	0f 85 bf 00 00 00    	jne    f0104fe1 <syscall+0x311>
	r = envid2env(dstenvid, &dstenv, 1);
f0104f22:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104f29:	00 
f0104f2a:	8d 45 e0             	lea    -0x20(%ebp),%eax
f0104f2d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104f31:	8b 45 14             	mov    0x14(%ebp),%eax
f0104f34:	89 04 24             	mov    %eax,(%esp)
f0104f37:	e8 2c e6 ff ff       	call   f0103568 <envid2env>
	if(r) return E_BAD_ENV;
f0104f3c:	ba 02 00 00 00       	mov    $0x2,%edx
f0104f41:	85 c0                	test   %eax,%eax
f0104f43:	0f 85 98 00 00 00    	jne    f0104fe1 <syscall+0x311>

	if(((uint32_t)srcva >= UTOP) || ((((uint32_t)srcva & 0x00000fff) != 0)))
f0104f49:	81 7d 10 ff ff bf ee 	cmpl   $0xeebfffff,0x10(%ebp)
f0104f50:	77 6e                	ja     f0104fc0 <syscall+0x2f0>
f0104f52:	f7 45 10 ff 0f 00 00 	testl  $0xfff,0x10(%ebp)
f0104f59:	75 6c                	jne    f0104fc7 <syscall+0x2f7>
		return -E_INVAL;

	if(((uint32_t)dstva >= UTOP) || ((((uint32_t)dstva & 0x00000fff) != 0)))
f0104f5b:	81 7d 18 ff ff bf ee 	cmpl   $0xeebfffff,0x18(%ebp)
f0104f62:	77 6a                	ja     f0104fce <syscall+0x2fe>
f0104f64:	f7 45 18 ff 0f 00 00 	testl  $0xfff,0x18(%ebp)
f0104f6b:	75 68                	jne    f0104fd5 <syscall+0x305>
		return -E_INVAL;


	pte_t* src_table_entry;
	struct Page* srcpp;
	srcpp = page_lookup(srcenv->env_pgdir, srcva, &src_table_entry);
f0104f6d:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104f70:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104f74:	8b 45 10             	mov    0x10(%ebp),%eax
f0104f77:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104f7b:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0104f7e:	8b 40 60             	mov    0x60(%eax),%eax
f0104f81:	89 04 24             	mov    %eax,(%esp)
f0104f84:	e8 ec c3 ff ff       	call   f0101375 <page_lookup>
	if(srcpp == NULL) return -E_INVAL;
f0104f89:	85 c0                	test   %eax,%eax
f0104f8b:	74 4f                	je     f0104fdc <syscall+0x30c>
	//cprintf("3. page lookup check passed.\n");

	if(((perm & PTE_W) == 1) && (((*src_table_entry) & PTE_W) == 0))
		return E_BAD_ENV;

	r = page_insert(dstenv->env_pgdir, srcpp, dstva, perm);
f0104f8d:	8b 75 1c             	mov    0x1c(%ebp),%esi
f0104f90:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0104f94:	8b 75 18             	mov    0x18(%ebp),%esi
f0104f97:	89 74 24 08          	mov    %esi,0x8(%esp)
f0104f9b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104f9f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104fa2:	8b 40 60             	mov    0x60(%eax),%eax
f0104fa5:	89 04 24             	mov    %eax,(%esp)
f0104fa8:	e8 b3 c4 ff ff       	call   f0101460 <page_insert>
	if(r)
		return -E_INVAL;
f0104fad:	83 f8 01             	cmp    $0x1,%eax
f0104fb0:	19 d2                	sbb    %edx,%edx
f0104fb2:	f7 d2                	not    %edx
f0104fb4:	83 e2 fd             	and    $0xfffffffd,%edx
f0104fb7:	eb 28                	jmp    f0104fe1 <syscall+0x311>
	//   Use the third argument to page_lookup() to
	//   check the current permissions on the page.
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
f0104fb9:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104fbe:	eb 21                	jmp    f0104fe1 <syscall+0x311>
	if(r) return E_BAD_ENV;
	r = envid2env(dstenvid, &dstenv, 1);
	if(r) return E_BAD_ENV;

	if(((uint32_t)srcva >= UTOP) || ((((uint32_t)srcva & 0x00000fff) != 0)))
		return -E_INVAL;
f0104fc0:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104fc5:	eb 1a                	jmp    f0104fe1 <syscall+0x311>
f0104fc7:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104fcc:	eb 13                	jmp    f0104fe1 <syscall+0x311>

	if(((uint32_t)dstva >= UTOP) || ((((uint32_t)dstva & 0x00000fff) != 0)))
		return -E_INVAL;
f0104fce:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104fd3:	eb 0c                	jmp    f0104fe1 <syscall+0x311>
f0104fd5:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104fda:	eb 05                	jmp    f0104fe1 <syscall+0x311>


	pte_t* src_table_entry;
	struct Page* srcpp;
	srcpp = page_lookup(srcenv->env_pgdir, srcva, &src_table_entry);
	if(srcpp == NULL) return -E_INVAL;
f0104fdc:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
		case (SYS_env_set_status):
			return sys_env_set_status(a1, a2);
		case(SYS_env_destroy):
			return sys_env_destroy((envid_t) a1);
		case (SYS_page_map):
			return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
f0104fe1:	89 d0                	mov    %edx,%eax
f0104fe3:	e9 50 02 00 00       	jmp    f0105238 <syscall+0x568>
static int
sys_page_unmap(envid_t envid, void *va)
{
	// Hint: This function is a wrapper around page_remove().
	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
f0104fe8:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104fef:	00 
f0104ff0:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104ff3:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104ff7:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104ffa:	89 04 24             	mov    %eax,(%esp)
f0104ffd:	e8 66 e5 ff ff       	call   f0103568 <envid2env>
	if(r) return E_BAD_ENV;
f0105002:	ba 02 00 00 00       	mov    $0x2,%edx
f0105007:	85 c0                	test   %eax,%eax
f0105009:	75 3a                	jne    f0105045 <syscall+0x375>

	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
f010500b:	81 7d 10 ff ff bf ee 	cmpl   $0xeebfffff,0x10(%ebp)
f0105012:	77 25                	ja     f0105039 <syscall+0x369>
f0105014:	f7 45 10 ff 0f 00 00 	testl  $0xfff,0x10(%ebp)
f010501b:	75 23                	jne    f0105040 <syscall+0x370>
		return -E_INVAL;

	page_remove(target_env->env_pgdir, va);
f010501d:	8b 45 10             	mov    0x10(%ebp),%eax
f0105020:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105024:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105027:	8b 40 60             	mov    0x60(%eax),%eax
f010502a:	89 04 24             	mov    %eax,(%esp)
f010502d:	e8 e5 c3 ff ff       	call   f0101417 <page_remove>
	return 0;
f0105032:	ba 00 00 00 00       	mov    $0x0,%edx
f0105037:	eb 0c                	jmp    f0105045 <syscall+0x375>
	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
	if(r) return E_BAD_ENV;

	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
		return -E_INVAL;
f0105039:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f010503e:	eb 05                	jmp    f0105045 <syscall+0x375>
f0105040:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
		case(SYS_env_destroy):
			return sys_env_destroy((envid_t) a1);
		case (SYS_page_map):
			return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
		case (SYS_page_unmap):
			return sys_page_unmap(a1, (void*)a2);
f0105045:	89 d0                	mov    %edx,%eax
f0105047:	e9 ec 01 00 00       	jmp    f0105238 <syscall+0x568>
//	-E_BAD_ENV if environment envid doesn't currently exist,
//		or the caller doesn't have permission to change envid.
static int
sys_env_set_pgfault_upcall(envid_t envid, void *func)
{
	struct Env* this_env =  NULL;
f010504c:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	int r = envid2env(envid,&this_env,1);
f0105053:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010505a:	00 
f010505b:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f010505e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105062:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105065:	89 04 24             	mov    %eax,(%esp)
f0105068:	e8 fb e4 ff ff       	call   f0103568 <envid2env>
	if(r){
f010506d:	85 c0                	test   %eax,%eax
f010506f:	75 13                	jne    f0105084 <syscall+0x3b4>
		return -E_BAD_ENV ;
	}
	this_env->env_pgfault_upcall = func;
f0105071:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105074:	8b 7d 10             	mov    0x10(%ebp),%edi
f0105077:	89 78 64             	mov    %edi,0x64(%eax)
	return 0;
f010507a:	b8 00 00 00 00       	mov    $0x0,%eax
f010507f:	e9 b4 01 00 00       	jmp    f0105238 <syscall+0x568>
sys_env_set_pgfault_upcall(envid_t envid, void *func)
{
	struct Env* this_env =  NULL;
	int r = envid2env(envid,&this_env,1);
	if(r){
		return -E_BAD_ENV ;
f0105084:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
		case (SYS_page_map):
			return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
		case (SYS_page_unmap):
			return sys_page_unmap(a1, (void*)a2);
		case (SYS_env_set_pgfault_upcall):
			return sys_env_set_pgfault_upcall(a1, (void*)a2);
f0105089:	e9 aa 01 00 00       	jmp    f0105238 <syscall+0x568>
//		address space.
static int
sys_ipc_try_send(envid_t envid, uint32_t value, void *srcva, unsigned perm)
{
	struct Env * target_env;
	int ret = envid2env(envid,&target_env,0);//zero for not to check permission
f010508e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0105095:	00 
f0105096:	8d 45 e0             	lea    -0x20(%ebp),%eax
f0105099:	89 44 24 04          	mov    %eax,0x4(%esp)
f010509d:	8b 45 0c             	mov    0xc(%ebp),%eax
f01050a0:	89 04 24             	mov    %eax,(%esp)
f01050a3:	e8 c0 e4 ff ff       	call   f0103568 <envid2env>
	if(ret)
f01050a8:	85 c0                	test   %eax,%eax
f01050aa:	0f 85 15 01 00 00    	jne    f01051c5 <syscall+0x4f5>
		return -E_BAD_ENV;
	if(!target_env->env_ipc_recving)
f01050b0:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01050b3:	83 78 68 00          	cmpl   $0x0,0x68(%eax)
f01050b7:	0f 84 0f 01 00 00    	je     f01051cc <syscall+0x4fc>
		return -E_IPC_NOT_RECV;
	target_env->env_ipc_perm = 0;
f01050bd:	c7 40 78 00 00 00 00 	movl   $0x0,0x78(%eax)
	// LAB 4: Your code here.
	//panic("sys_ipc_try_send not implemented");
	if(srcva!=NULL && ((uint32_t)srcva<UTOP)){
f01050c4:	8b 45 14             	mov    0x14(%ebp),%eax
f01050c7:	83 e8 01             	sub    $0x1,%eax
f01050ca:	3d fe ff bf ee       	cmp    $0xeebffffe,%eax
f01050cf:	0f 87 b4 00 00 00    	ja     f0105189 <syscall+0x4b9>
		if(ROUNDDOWN(srcva,PGSIZE)!=srcva) return -E_INVAL;
f01050d5:	8b 55 14             	mov    0x14(%ebp),%edx
f01050d8:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f01050de:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f01050e3:	39 55 14             	cmp    %edx,0x14(%ebp)
f01050e6:	0f 85 4c 01 00 00    	jne    f0105238 <syscall+0x568>
		if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
f01050ec:	8b 55 18             	mov    0x18(%ebp),%edx
f01050ef:	81 e2 fd f1 ff ff    	and    $0xfffff1fd,%edx
f01050f5:	83 fa 05             	cmp    $0x5,%edx
f01050f8:	0f 85 3a 01 00 00    	jne    f0105238 <syscall+0x568>
		return -E_INVAL;

		pte_t* src_table_entry;
		struct Page* srcpp;

		srcpp = page_lookup(curenv->env_pgdir, srcva, &src_table_entry);
f01050fe:	e8 90 14 00 00       	call   f0106593 <cpunum>
f0105103:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0105106:	89 54 24 08          	mov    %edx,0x8(%esp)
f010510a:	8b 75 14             	mov    0x14(%ebp),%esi
f010510d:	89 74 24 04          	mov    %esi,0x4(%esp)
f0105111:	6b c0 74             	imul   $0x74,%eax,%eax
f0105114:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f010511a:	8b 40 60             	mov    0x60(%eax),%eax
f010511d:	89 04 24             	mov    %eax,(%esp)
f0105120:	e8 50 c2 ff ff       	call   f0101375 <page_lookup>
f0105125:	89 c2                	mov    %eax,%edx
		if(srcpp == NULL) return -E_INVAL;
f0105127:	85 c0                	test   %eax,%eax
f0105129:	74 4a                	je     f0105175 <syscall+0x4a5>

		if((perm & PTE_W) && (*src_table_entry & PTE_W) == 0)
f010512b:	f6 45 18 02          	testb  $0x2,0x18(%ebp)
f010512f:	74 11                	je     f0105142 <syscall+0x472>
			return -E_INVAL;
f0105131:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
		struct Page* srcpp;

		srcpp = page_lookup(curenv->env_pgdir, srcva, &src_table_entry);
		if(srcpp == NULL) return -E_INVAL;

		if((perm & PTE_W) && (*src_table_entry & PTE_W) == 0)
f0105136:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0105139:	f6 01 02             	testb  $0x2,(%ecx)
f010513c:	0f 84 f6 00 00 00    	je     f0105238 <syscall+0x568>
			return -E_INVAL;

		if(target_env->env_ipc_dstva != 0) // really send the page if the target want.
f0105142:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105145:	8b 48 6c             	mov    0x6c(%eax),%ecx
f0105148:	85 c9                	test   %ecx,%ecx
f010514a:	74 3d                	je     f0105189 <syscall+0x4b9>
		{
			if(page_insert (target_env->env_pgdir, srcpp, target_env->env_ipc_dstva, perm) < 0)
f010514c:	8b 75 18             	mov    0x18(%ebp),%esi
f010514f:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105153:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0105157:	89 54 24 04          	mov    %edx,0x4(%esp)
f010515b:	8b 40 60             	mov    0x60(%eax),%eax
f010515e:	89 04 24             	mov    %eax,(%esp)
f0105161:	e8 fa c2 ff ff       	call   f0101460 <page_insert>
f0105166:	85 c0                	test   %eax,%eax
f0105168:	78 15                	js     f010517f <syscall+0x4af>
				return -E_NO_MEM;
			target_env->env_ipc_perm = perm;
f010516a:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010516d:	8b 75 18             	mov    0x18(%ebp),%esi
f0105170:	89 70 78             	mov    %esi,0x78(%eax)
f0105173:	eb 14                	jmp    f0105189 <syscall+0x4b9>

		pte_t* src_table_entry;
		struct Page* srcpp;

		srcpp = page_lookup(curenv->env_pgdir, srcva, &src_table_entry);
		if(srcpp == NULL) return -E_INVAL;
f0105175:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f010517a:	e9 b9 00 00 00       	jmp    f0105238 <syscall+0x568>
			return -E_INVAL;

		if(target_env->env_ipc_dstva != 0) // really send the page if the target want.
		{
			if(page_insert (target_env->env_pgdir, srcpp, target_env->env_ipc_dstva, perm) < 0)
				return -E_NO_MEM;
f010517f:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
f0105184:	e9 af 00 00 00       	jmp    f0105238 <syscall+0x568>
			target_env->env_ipc_perm = perm;
		}
	}
	target_env->env_ipc_recving = 0;
f0105189:	8b 5d e0             	mov    -0x20(%ebp),%ebx
f010518c:	c7 43 68 00 00 00 00 	movl   $0x0,0x68(%ebx)
    	target_env->env_ipc_from = curenv->env_id;
f0105193:	e8 fb 13 00 00       	call   f0106593 <cpunum>
f0105198:	6b c0 74             	imul   $0x74,%eax,%eax
f010519b:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f01051a1:	8b 40 48             	mov    0x48(%eax),%eax
f01051a4:	89 43 74             	mov    %eax,0x74(%ebx)
    	target_env->env_ipc_value = value; 
f01051a7:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01051aa:	8b 75 10             	mov    0x10(%ebp),%esi
f01051ad:	89 70 70             	mov    %esi,0x70(%eax)
    	target_env->env_status = ENV_RUNNABLE;
f01051b0:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)
   	 target_env->env_tf.tf_regs.reg_eax = 0;
f01051b7:	c7 40 1c 00 00 00 00 	movl   $0x0,0x1c(%eax)
   	 return 0;
f01051be:	b8 00 00 00 00       	mov    $0x0,%eax
f01051c3:	eb 73                	jmp    f0105238 <syscall+0x568>
sys_ipc_try_send(envid_t envid, uint32_t value, void *srcva, unsigned perm)
{
	struct Env * target_env;
	int ret = envid2env(envid,&target_env,0);//zero for not to check permission
	if(ret)
		return -E_BAD_ENV;
f01051c5:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01051ca:	eb 6c                	jmp    f0105238 <syscall+0x568>
	if(!target_env->env_ipc_recving)
		return -E_IPC_NOT_RECV;
f01051cc:	b8 f9 ff ff ff       	mov    $0xfffffff9,%eax
		case (SYS_page_unmap):
			return sys_page_unmap(a1, (void*)a2);
		case (SYS_env_set_pgfault_upcall):
			return sys_env_set_pgfault_upcall(a1, (void*)a2);
		case (SYS_ipc_try_send):
			return sys_ipc_try_send(a1, a2, (void*)a3, a4);
f01051d1:	eb 65                	jmp    f0105238 <syscall+0x568>
// Return < 0 on error.  Errors are:
//	-E_INVAL if dstva < UTOP but dstva is not page-aligned.
static int
sys_ipc_recv(void *dstva)
{
	if(dstva<(void*)UTOP){
f01051d3:	81 7d 0c ff ff bf ee 	cmpl   $0xeebfffff,0xc(%ebp)
f01051da:	77 0d                	ja     f01051e9 <syscall+0x519>
		if(dstva != ROUNDDOWN(dstva,PGSIZE))
f01051dc:	8b 45 0c             	mov    0xc(%ebp),%eax
f01051df:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01051e4:	39 45 0c             	cmp    %eax,0xc(%ebp)
f01051e7:	75 4a                	jne    f0105233 <syscall+0x563>
			return -E_INVAL;
	}
	// LAB 4: Your code here.
	curenv->env_ipc_recving = 1;
f01051e9:	e8 a5 13 00 00       	call   f0106593 <cpunum>
f01051ee:	6b c0 74             	imul   $0x74,%eax,%eax
f01051f1:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f01051f7:	c7 40 68 01 00 00 00 	movl   $0x1,0x68(%eax)
    	curenv->env_status = ENV_NOT_RUNNABLE;
f01051fe:	e8 90 13 00 00       	call   f0106593 <cpunum>
f0105203:	6b c0 74             	imul   $0x74,%eax,%eax
f0105206:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f010520c:	c7 40 54 04 00 00 00 	movl   $0x4,0x54(%eax)
    	curenv->env_ipc_dstva = dstva;
f0105213:	e8 7b 13 00 00       	call   f0106593 <cpunum>
f0105218:	6b c0 74             	imul   $0x74,%eax,%eax
f010521b:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0105221:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105224:	89 70 6c             	mov    %esi,0x6c(%eax)

// Deschedule current environment and pick a different one to run.
static void
sys_yield(void)
{
	sched_yield();
f0105227:	e8 84 f9 ff ff       	call   f0104bb0 <sched_yield>
		case (SYS_ipc_try_send):
			return sys_ipc_try_send(a1, a2, (void*)a3, a4);
		case (SYS_ipc_recv):
			return sys_ipc_recv((void*)a1);
		default:
			return -E_INVAL;
f010522c:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0105231:	eb 05                	jmp    f0105238 <syscall+0x568>
		case (SYS_env_set_pgfault_upcall):
			return sys_env_set_pgfault_upcall(a1, (void*)a2);
		case (SYS_ipc_try_send):
			return sys_ipc_try_send(a1, a2, (void*)a3, a4);
		case (SYS_ipc_recv):
			return sys_ipc_recv((void*)a1);
f0105233:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
		default:
			return -E_INVAL;
	}
	//panic("syscall not implemented");
}
f0105238:	83 c4 2c             	add    $0x2c,%esp
f010523b:	5b                   	pop    %ebx
f010523c:	5e                   	pop    %esi
f010523d:	5f                   	pop    %edi
f010523e:	5d                   	pop    %ebp
f010523f:	c3                   	ret    

f0105240 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0105240:	55                   	push   %ebp
f0105241:	89 e5                	mov    %esp,%ebp
f0105243:	57                   	push   %edi
f0105244:	56                   	push   %esi
f0105245:	53                   	push   %ebx
f0105246:	83 ec 14             	sub    $0x14,%esp
f0105249:	89 45 ec             	mov    %eax,-0x14(%ebp)
f010524c:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f010524f:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0105252:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0105255:	8b 1a                	mov    (%edx),%ebx
f0105257:	8b 01                	mov    (%ecx),%eax
f0105259:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f010525c:	39 c3                	cmp    %eax,%ebx
f010525e:	0f 8f 9a 00 00 00    	jg     f01052fe <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f0105264:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f010526b:	8b 45 f0             	mov    -0x10(%ebp),%eax
f010526e:	01 d8                	add    %ebx,%eax
f0105270:	89 c7                	mov    %eax,%edi
f0105272:	c1 ef 1f             	shr    $0x1f,%edi
f0105275:	01 c7                	add    %eax,%edi
f0105277:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0105279:	39 df                	cmp    %ebx,%edi
f010527b:	0f 8c c4 00 00 00    	jl     f0105345 <stab_binsearch+0x105>
f0105281:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0105284:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0105287:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f010528a:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f010528e:	39 f0                	cmp    %esi,%eax
f0105290:	0f 84 b4 00 00 00    	je     f010534a <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0105296:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f0105298:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f010529b:	39 d8                	cmp    %ebx,%eax
f010529d:	0f 8c a2 00 00 00    	jl     f0105345 <stab_binsearch+0x105>
f01052a3:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f01052a7:	83 ea 0c             	sub    $0xc,%edx
f01052aa:	39 f1                	cmp    %esi,%ecx
f01052ac:	75 ea                	jne    f0105298 <stab_binsearch+0x58>
f01052ae:	e9 99 00 00 00       	jmp    f010534c <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f01052b3:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f01052b6:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f01052b8:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01052bb:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01052c2:	eb 2b                	jmp    f01052ef <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f01052c4:	3b 55 0c             	cmp    0xc(%ebp),%edx
f01052c7:	76 14                	jbe    f01052dd <stab_binsearch+0x9d>
			*region_right = m - 1;
f01052c9:	83 e8 01             	sub    $0x1,%eax
f01052cc:	89 45 f0             	mov    %eax,-0x10(%ebp)
f01052cf:	8b 7d e0             	mov    -0x20(%ebp),%edi
f01052d2:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01052d4:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01052db:	eb 12                	jmp    f01052ef <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f01052dd:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01052e0:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f01052e2:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f01052e6:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01052e8:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f01052ef:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f01052f2:	0f 8e 73 ff ff ff    	jle    f010526b <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f01052f8:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f01052fc:	75 0f                	jne    f010530d <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f01052fe:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105301:	8b 00                	mov    (%eax),%eax
f0105303:	83 e8 01             	sub    $0x1,%eax
f0105306:	8b 75 e0             	mov    -0x20(%ebp),%esi
f0105309:	89 06                	mov    %eax,(%esi)
f010530b:	eb 57                	jmp    f0105364 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f010530d:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105310:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0105312:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0105315:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0105317:	39 c8                	cmp    %ecx,%eax
f0105319:	7e 23                	jle    f010533e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f010531b:	8d 14 40             	lea    (%eax,%eax,2),%edx
f010531e:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0105321:	8d 14 97             	lea    (%edi,%edx,4),%edx
f0105324:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f0105328:	39 f3                	cmp    %esi,%ebx
f010532a:	74 12                	je     f010533e <stab_binsearch+0xfe>
		     l--)
f010532c:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f010532f:	39 c8                	cmp    %ecx,%eax
f0105331:	7e 0b                	jle    f010533e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0105333:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f0105337:	83 ea 0c             	sub    $0xc,%edx
f010533a:	39 f3                	cmp    %esi,%ebx
f010533c:	75 ee                	jne    f010532c <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f010533e:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0105341:	89 06                	mov    %eax,(%esi)
f0105343:	eb 1f                	jmp    f0105364 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0105345:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0105348:	eb a5                	jmp    f01052ef <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f010534a:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f010534c:	8d 14 40             	lea    (%eax,%eax,2),%edx
f010534f:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0105352:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0105356:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0105359:	0f 82 54 ff ff ff    	jb     f01052b3 <stab_binsearch+0x73>
f010535f:	e9 60 ff ff ff       	jmp    f01052c4 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0105364:	83 c4 14             	add    $0x14,%esp
f0105367:	5b                   	pop    %ebx
f0105368:	5e                   	pop    %esi
f0105369:	5f                   	pop    %edi
f010536a:	5d                   	pop    %ebp
f010536b:	c3                   	ret    

f010536c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f010536c:	55                   	push   %ebp
f010536d:	89 e5                	mov    %esp,%ebp
f010536f:	57                   	push   %edi
f0105370:	56                   	push   %esi
f0105371:	53                   	push   %ebx
f0105372:	83 ec 3c             	sub    $0x3c,%esp
f0105375:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105378:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f010537b:	c7 06 f8 81 10 f0    	movl   $0xf01081f8,(%esi)
	info->eip_line = 0;
f0105381:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0105388:	c7 46 08 f8 81 10 f0 	movl   $0xf01081f8,0x8(%esi)
	info->eip_fn_namelen = 9;
f010538f:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0105396:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0105399:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f01053a0:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f01053a6:	0f 87 ca 00 00 00    	ja     f0105476 <debuginfo_eip+0x10a>
		const struct UserStabData *usd = (const struct UserStabData *) USTABDATA;

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
f01053ac:	e8 e2 11 00 00       	call   f0106593 <cpunum>
f01053b1:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f01053b8:	00 
f01053b9:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
f01053c0:	00 
f01053c1:	c7 44 24 04 00 00 20 	movl   $0x200000,0x4(%esp)
f01053c8:	00 
f01053c9:	6b c0 74             	imul   $0x74,%eax,%eax
f01053cc:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f01053d2:	89 04 24             	mov    %eax,(%esp)
f01053d5:	e8 97 e0 ff ff       	call   f0103471 <user_mem_check>
f01053da:	85 c0                	test   %eax,%eax
f01053dc:	0f 85 12 02 00 00    	jne    f01055f4 <debuginfo_eip+0x288>
			return -1;
		stabs = usd->stabs;
f01053e2:	a1 00 00 20 00       	mov    0x200000,%eax
f01053e7:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f01053ea:	8b 1d 04 00 20 00    	mov    0x200004,%ebx
		stabstr = usd->stabstr;
f01053f0:	8b 15 08 00 20 00    	mov    0x200008,%edx
f01053f6:	89 55 d0             	mov    %edx,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f01053f9:	a1 0c 00 20 00       	mov    0x20000c,%eax
f01053fe:	89 45 cc             	mov    %eax,-0x34(%ebp)

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
f0105401:	e8 8d 11 00 00       	call   f0106593 <cpunum>
f0105406:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f010540d:	00 
f010540e:	89 da                	mov    %ebx,%edx
f0105410:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0105413:	29 ca                	sub    %ecx,%edx
f0105415:	c1 fa 02             	sar    $0x2,%edx
f0105418:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f010541e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0105422:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0105426:	6b c0 74             	imul   $0x74,%eax,%eax
f0105429:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f010542f:	89 04 24             	mov    %eax,(%esp)
f0105432:	e8 3a e0 ff ff       	call   f0103471 <user_mem_check>
f0105437:	85 c0                	test   %eax,%eax
f0105439:	0f 85 bc 01 00 00    	jne    f01055fb <debuginfo_eip+0x28f>
f010543f:	e8 4f 11 00 00       	call   f0106593 <cpunum>
f0105444:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f010544b:	00 
f010544c:	8b 55 cc             	mov    -0x34(%ebp),%edx
f010544f:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0105452:	29 ca                	sub    %ecx,%edx
f0105454:	89 54 24 08          	mov    %edx,0x8(%esp)
f0105458:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f010545c:	6b c0 74             	imul   $0x74,%eax,%eax
f010545f:	8b 80 28 80 1c f0    	mov    -0xfe37fd8(%eax),%eax
f0105465:	89 04 24             	mov    %eax,(%esp)
f0105468:	e8 04 e0 ff ff       	call   f0103471 <user_mem_check>
f010546d:	85 c0                	test   %eax,%eax
f010546f:	74 1f                	je     f0105490 <debuginfo_eip+0x124>
f0105471:	e9 8c 01 00 00       	jmp    f0105602 <debuginfo_eip+0x296>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f0105476:	c7 45 cc 22 64 11 f0 	movl   $0xf0116422,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f010547d:	c7 45 d0 ad 2e 11 f0 	movl   $0xf0112ead,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f0105484:	bb ac 2e 11 f0       	mov    $0xf0112eac,%ebx
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f0105489:	c7 45 d4 90 87 10 f0 	movl   $0xf0108790,-0x2c(%ebp)
		    return -1;
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0105490:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0105493:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0105496:	0f 83 6d 01 00 00    	jae    f0105609 <debuginfo_eip+0x29d>
f010549c:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f01054a0:	0f 85 6a 01 00 00    	jne    f0105610 <debuginfo_eip+0x2a4>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f01054a6:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f01054ad:	2b 5d d4             	sub    -0x2c(%ebp),%ebx
f01054b0:	c1 fb 02             	sar    $0x2,%ebx
f01054b3:	69 c3 ab aa aa aa    	imul   $0xaaaaaaab,%ebx,%eax
f01054b9:	83 e8 01             	sub    $0x1,%eax
f01054bc:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f01054bf:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01054c3:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f01054ca:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f01054cd:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f01054d0:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f01054d3:	89 d8                	mov    %ebx,%eax
f01054d5:	e8 66 fd ff ff       	call   f0105240 <stab_binsearch>
	if (lfile == 0)
f01054da:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01054dd:	85 c0                	test   %eax,%eax
f01054df:	0f 84 32 01 00 00    	je     f0105617 <debuginfo_eip+0x2ab>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f01054e5:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f01054e8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01054eb:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f01054ee:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01054f2:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f01054f9:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f01054fc:	8d 55 dc             	lea    -0x24(%ebp),%edx
f01054ff:	89 d8                	mov    %ebx,%eax
f0105501:	e8 3a fd ff ff       	call   f0105240 <stab_binsearch>

	if (lfun <= rfun) {
f0105506:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f0105509:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f010550c:	7f 23                	jg     f0105531 <debuginfo_eip+0x1c5>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f010550e:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0105511:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0105514:	8d 04 87             	lea    (%edi,%eax,4),%eax
f0105517:	8b 10                	mov    (%eax),%edx
f0105519:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f010551c:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f010551f:	39 ca                	cmp    %ecx,%edx
f0105521:	73 06                	jae    f0105529 <debuginfo_eip+0x1bd>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0105523:	03 55 d0             	add    -0x30(%ebp),%edx
f0105526:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f0105529:	8b 40 08             	mov    0x8(%eax),%eax
f010552c:	89 46 10             	mov    %eax,0x10(%esi)
f010552f:	eb 06                	jmp    f0105537 <debuginfo_eip+0x1cb>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0105531:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f0105534:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0105537:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f010553e:	00 
f010553f:	8b 46 08             	mov    0x8(%esi),%eax
f0105542:	89 04 24             	mov    %eax,(%esp)
f0105545:	e8 85 09 00 00       	call   f0105ecf <strfind>
f010554a:	2b 46 08             	sub    0x8(%esi),%eax
f010554d:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0105550:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0105553:	39 fb                	cmp    %edi,%ebx
f0105555:	7c 5d                	jl     f01055b4 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0105557:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f010555a:	c1 e0 02             	shl    $0x2,%eax
f010555d:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0105560:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f0105563:	89 55 c8             	mov    %edx,-0x38(%ebp)
f0105566:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f010556a:	80 fa 84             	cmp    $0x84,%dl
f010556d:	74 2d                	je     f010559c <debuginfo_eip+0x230>
f010556f:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f0105573:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0105576:	eb 15                	jmp    f010558d <debuginfo_eip+0x221>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0105578:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f010557b:	39 fb                	cmp    %edi,%ebx
f010557d:	7c 35                	jl     f01055b4 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f010557f:	89 c1                	mov    %eax,%ecx
f0105581:	83 e8 0c             	sub    $0xc,%eax
f0105584:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0105588:	80 fa 84             	cmp    $0x84,%dl
f010558b:	74 0f                	je     f010559c <debuginfo_eip+0x230>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f010558d:	80 fa 64             	cmp    $0x64,%dl
f0105590:	75 e6                	jne    f0105578 <debuginfo_eip+0x20c>
f0105592:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f0105596:	74 e0                	je     f0105578 <debuginfo_eip+0x20c>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0105598:	39 df                	cmp    %ebx,%edi
f010559a:	7f 18                	jg     f01055b4 <debuginfo_eip+0x248>
f010559c:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f010559f:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f01055a2:	8b 04 87             	mov    (%edi,%eax,4),%eax
f01055a5:	8b 55 cc             	mov    -0x34(%ebp),%edx
f01055a8:	2b 55 d0             	sub    -0x30(%ebp),%edx
f01055ab:	39 d0                	cmp    %edx,%eax
f01055ad:	73 05                	jae    f01055b4 <debuginfo_eip+0x248>
		info->eip_file = stabstr + stabs[lline].n_strx;
f01055af:	03 45 d0             	add    -0x30(%ebp),%eax
f01055b2:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f01055b4:	8b 55 dc             	mov    -0x24(%ebp),%edx
f01055b7:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f01055ba:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f01055bf:	39 ca                	cmp    %ecx,%edx
f01055c1:	7d 75                	jge    f0105638 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
f01055c3:	8d 42 01             	lea    0x1(%edx),%eax
f01055c6:	39 c1                	cmp    %eax,%ecx
f01055c8:	7e 54                	jle    f010561e <debuginfo_eip+0x2b2>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f01055ca:	8d 14 40             	lea    (%eax,%eax,2),%edx
f01055cd:	c1 e2 02             	shl    $0x2,%edx
f01055d0:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f01055d3:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f01055d8:	75 4b                	jne    f0105625 <debuginfo_eip+0x2b9>
f01055da:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f01055de:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f01055e2:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f01055e5:	39 c1                	cmp    %eax,%ecx
f01055e7:	7e 43                	jle    f010562c <debuginfo_eip+0x2c0>
f01055e9:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f01055ec:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f01055f0:	74 ec                	je     f01055de <debuginfo_eip+0x272>
f01055f2:	eb 3f                	jmp    f0105633 <debuginfo_eip+0x2c7>

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
			return -1;
f01055f4:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01055f9:	eb 3d                	jmp    f0105638 <debuginfo_eip+0x2cc>

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
		 {
		    return -1;
f01055fb:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105600:	eb 36                	jmp    f0105638 <debuginfo_eip+0x2cc>
f0105602:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105607:	eb 2f                	jmp    f0105638 <debuginfo_eip+0x2cc>
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0105609:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f010560e:	eb 28                	jmp    f0105638 <debuginfo_eip+0x2cc>
f0105610:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105615:	eb 21                	jmp    f0105638 <debuginfo_eip+0x2cc>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0105617:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f010561c:	eb 1a                	jmp    f0105638 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f010561e:	b8 00 00 00 00       	mov    $0x0,%eax
f0105623:	eb 13                	jmp    f0105638 <debuginfo_eip+0x2cc>
f0105625:	b8 00 00 00 00       	mov    $0x0,%eax
f010562a:	eb 0c                	jmp    f0105638 <debuginfo_eip+0x2cc>
f010562c:	b8 00 00 00 00       	mov    $0x0,%eax
f0105631:	eb 05                	jmp    f0105638 <debuginfo_eip+0x2cc>
f0105633:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105638:	83 c4 3c             	add    $0x3c,%esp
f010563b:	5b                   	pop    %ebx
f010563c:	5e                   	pop    %esi
f010563d:	5f                   	pop    %edi
f010563e:	5d                   	pop    %ebp
f010563f:	c3                   	ret    

f0105640 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0105640:	55                   	push   %ebp
f0105641:	89 e5                	mov    %esp,%ebp
f0105643:	57                   	push   %edi
f0105644:	56                   	push   %esi
f0105645:	53                   	push   %ebx
f0105646:	83 ec 3c             	sub    $0x3c,%esp
f0105649:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010564c:	89 d7                	mov    %edx,%edi
f010564e:	8b 45 08             	mov    0x8(%ebp),%eax
f0105651:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0105654:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105657:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f010565a:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f010565d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105662:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0105665:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0105668:	39 f1                	cmp    %esi,%ecx
f010566a:	72 14                	jb     f0105680 <printnum+0x40>
f010566c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f010566f:	76 0f                	jbe    f0105680 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0105671:	8b 45 14             	mov    0x14(%ebp),%eax
f0105674:	8d 70 ff             	lea    -0x1(%eax),%esi
f0105677:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f010567a:	85 f6                	test   %esi,%esi
f010567c:	7f 60                	jg     f01056de <printnum+0x9e>
f010567e:	eb 72                	jmp    f01056f2 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0105680:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0105683:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0105687:	8b 4d 14             	mov    0x14(%ebp),%ecx
f010568a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f010568d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0105691:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105695:	8b 44 24 08          	mov    0x8(%esp),%eax
f0105699:	8b 54 24 0c          	mov    0xc(%esp),%edx
f010569d:	89 c3                	mov    %eax,%ebx
f010569f:	89 d6                	mov    %edx,%esi
f01056a1:	8b 55 d8             	mov    -0x28(%ebp),%edx
f01056a4:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f01056a7:	89 54 24 08          	mov    %edx,0x8(%esp)
f01056ab:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01056af:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01056b2:	89 04 24             	mov    %eax,(%esp)
f01056b5:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01056b8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01056bc:	e8 3f 13 00 00       	call   f0106a00 <__udivdi3>
f01056c1:	89 d9                	mov    %ebx,%ecx
f01056c3:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01056c7:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01056cb:	89 04 24             	mov    %eax,(%esp)
f01056ce:	89 54 24 04          	mov    %edx,0x4(%esp)
f01056d2:	89 fa                	mov    %edi,%edx
f01056d4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01056d7:	e8 64 ff ff ff       	call   f0105640 <printnum>
f01056dc:	eb 14                	jmp    f01056f2 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f01056de:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01056e2:	8b 45 18             	mov    0x18(%ebp),%eax
f01056e5:	89 04 24             	mov    %eax,(%esp)
f01056e8:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f01056ea:	83 ee 01             	sub    $0x1,%esi
f01056ed:	75 ef                	jne    f01056de <printnum+0x9e>
f01056ef:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f01056f2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01056f6:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01056fa:	8b 45 d8             	mov    -0x28(%ebp),%eax
f01056fd:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0105700:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105704:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0105708:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010570b:	89 04 24             	mov    %eax,(%esp)
f010570e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105711:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105715:	e8 16 14 00 00       	call   f0106b30 <__umoddi3>
f010571a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010571e:	0f be 80 02 82 10 f0 	movsbl -0xfef7dfe(%eax),%eax
f0105725:	89 04 24             	mov    %eax,(%esp)
f0105728:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010572b:	ff d0                	call   *%eax
}
f010572d:	83 c4 3c             	add    $0x3c,%esp
f0105730:	5b                   	pop    %ebx
f0105731:	5e                   	pop    %esi
f0105732:	5f                   	pop    %edi
f0105733:	5d                   	pop    %ebp
f0105734:	c3                   	ret    

f0105735 <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0105735:	55                   	push   %ebp
f0105736:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0105738:	83 fa 01             	cmp    $0x1,%edx
f010573b:	7e 0e                	jle    f010574b <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f010573d:	8b 10                	mov    (%eax),%edx
f010573f:	8d 4a 08             	lea    0x8(%edx),%ecx
f0105742:	89 08                	mov    %ecx,(%eax)
f0105744:	8b 02                	mov    (%edx),%eax
f0105746:	8b 52 04             	mov    0x4(%edx),%edx
f0105749:	eb 22                	jmp    f010576d <getuint+0x38>
	else if (lflag)
f010574b:	85 d2                	test   %edx,%edx
f010574d:	74 10                	je     f010575f <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f010574f:	8b 10                	mov    (%eax),%edx
f0105751:	8d 4a 04             	lea    0x4(%edx),%ecx
f0105754:	89 08                	mov    %ecx,(%eax)
f0105756:	8b 02                	mov    (%edx),%eax
f0105758:	ba 00 00 00 00       	mov    $0x0,%edx
f010575d:	eb 0e                	jmp    f010576d <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f010575f:	8b 10                	mov    (%eax),%edx
f0105761:	8d 4a 04             	lea    0x4(%edx),%ecx
f0105764:	89 08                	mov    %ecx,(%eax)
f0105766:	8b 02                	mov    (%edx),%eax
f0105768:	ba 00 00 00 00       	mov    $0x0,%edx
}
f010576d:	5d                   	pop    %ebp
f010576e:	c3                   	ret    

f010576f <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f010576f:	55                   	push   %ebp
f0105770:	89 e5                	mov    %esp,%ebp
f0105772:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0105775:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0105779:	8b 10                	mov    (%eax),%edx
f010577b:	3b 50 04             	cmp    0x4(%eax),%edx
f010577e:	73 0a                	jae    f010578a <sprintputch+0x1b>
		*b->buf++ = ch;
f0105780:	8d 4a 01             	lea    0x1(%edx),%ecx
f0105783:	89 08                	mov    %ecx,(%eax)
f0105785:	8b 45 08             	mov    0x8(%ebp),%eax
f0105788:	88 02                	mov    %al,(%edx)
}
f010578a:	5d                   	pop    %ebp
f010578b:	c3                   	ret    

f010578c <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f010578c:	55                   	push   %ebp
f010578d:	89 e5                	mov    %esp,%ebp
f010578f:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0105792:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0105795:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105799:	8b 45 10             	mov    0x10(%ebp),%eax
f010579c:	89 44 24 08          	mov    %eax,0x8(%esp)
f01057a0:	8b 45 0c             	mov    0xc(%ebp),%eax
f01057a3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01057a7:	8b 45 08             	mov    0x8(%ebp),%eax
f01057aa:	89 04 24             	mov    %eax,(%esp)
f01057ad:	e8 02 00 00 00       	call   f01057b4 <vprintfmt>
	va_end(ap);
}
f01057b2:	c9                   	leave  
f01057b3:	c3                   	ret    

f01057b4 <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f01057b4:	55                   	push   %ebp
f01057b5:	89 e5                	mov    %esp,%ebp
f01057b7:	57                   	push   %edi
f01057b8:	56                   	push   %esi
f01057b9:	53                   	push   %ebx
f01057ba:	83 ec 3c             	sub    $0x3c,%esp
f01057bd:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01057c0:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01057c3:	eb 18                	jmp    f01057dd <vprintfmt+0x29>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f01057c5:	85 c0                	test   %eax,%eax
f01057c7:	0f 84 c3 03 00 00    	je     f0105b90 <vprintfmt+0x3dc>
				return;
			putch(ch, putdat);
f01057cd:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01057d1:	89 04 24             	mov    %eax,(%esp)
f01057d4:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01057d7:	89 f3                	mov    %esi,%ebx
f01057d9:	eb 02                	jmp    f01057dd <vprintfmt+0x29>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f01057db:	89 f3                	mov    %esi,%ebx
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01057dd:	8d 73 01             	lea    0x1(%ebx),%esi
f01057e0:	0f b6 03             	movzbl (%ebx),%eax
f01057e3:	83 f8 25             	cmp    $0x25,%eax
f01057e6:	75 dd                	jne    f01057c5 <vprintfmt+0x11>
f01057e8:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f01057ec:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f01057f3:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f01057fa:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0105801:	ba 00 00 00 00       	mov    $0x0,%edx
f0105806:	eb 1d                	jmp    f0105825 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105808:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f010580a:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f010580e:	eb 15                	jmp    f0105825 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105810:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0105812:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f0105816:	eb 0d                	jmp    f0105825 <vprintfmt+0x71>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0105818:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010581b:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010581e:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105825:	8d 5e 01             	lea    0x1(%esi),%ebx
f0105828:	0f b6 06             	movzbl (%esi),%eax
f010582b:	0f b6 c8             	movzbl %al,%ecx
f010582e:	83 e8 23             	sub    $0x23,%eax
f0105831:	3c 55                	cmp    $0x55,%al
f0105833:	0f 87 2f 03 00 00    	ja     f0105b68 <vprintfmt+0x3b4>
f0105839:	0f b6 c0             	movzbl %al,%eax
f010583c:	ff 24 85 40 83 10 f0 	jmp    *-0xfef7cc0(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0105843:	8d 41 d0             	lea    -0x30(%ecx),%eax
f0105846:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0105849:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f010584d:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0105850:	83 f9 09             	cmp    $0x9,%ecx
f0105853:	77 50                	ja     f01058a5 <vprintfmt+0xf1>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105855:	89 de                	mov    %ebx,%esi
f0105857:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f010585a:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f010585d:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0105860:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0105864:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0105867:	8d 58 d0             	lea    -0x30(%eax),%ebx
f010586a:	83 fb 09             	cmp    $0x9,%ebx
f010586d:	76 eb                	jbe    f010585a <vprintfmt+0xa6>
f010586f:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0105872:	eb 33                	jmp    f01058a7 <vprintfmt+0xf3>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0105874:	8b 45 14             	mov    0x14(%ebp),%eax
f0105877:	8d 48 04             	lea    0x4(%eax),%ecx
f010587a:	89 4d 14             	mov    %ecx,0x14(%ebp)
f010587d:	8b 00                	mov    (%eax),%eax
f010587f:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105882:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0105884:	eb 21                	jmp    f01058a7 <vprintfmt+0xf3>
f0105886:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0105889:	85 c9                	test   %ecx,%ecx
f010588b:	b8 00 00 00 00       	mov    $0x0,%eax
f0105890:	0f 49 c1             	cmovns %ecx,%eax
f0105893:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105896:	89 de                	mov    %ebx,%esi
f0105898:	eb 8b                	jmp    f0105825 <vprintfmt+0x71>
f010589a:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f010589c:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f01058a3:	eb 80                	jmp    f0105825 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01058a5:	89 de                	mov    %ebx,%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f01058a7:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01058ab:	0f 89 74 ff ff ff    	jns    f0105825 <vprintfmt+0x71>
f01058b1:	e9 62 ff ff ff       	jmp    f0105818 <vprintfmt+0x64>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f01058b6:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01058b9:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f01058bb:	e9 65 ff ff ff       	jmp    f0105825 <vprintfmt+0x71>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f01058c0:	8b 45 14             	mov    0x14(%ebp),%eax
f01058c3:	8d 50 04             	lea    0x4(%eax),%edx
f01058c6:	89 55 14             	mov    %edx,0x14(%ebp)
f01058c9:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01058cd:	8b 00                	mov    (%eax),%eax
f01058cf:	89 04 24             	mov    %eax,(%esp)
f01058d2:	ff 55 08             	call   *0x8(%ebp)
			break;
f01058d5:	e9 03 ff ff ff       	jmp    f01057dd <vprintfmt+0x29>

		// error message
		case 'e':
			err = va_arg(ap, int);
f01058da:	8b 45 14             	mov    0x14(%ebp),%eax
f01058dd:	8d 50 04             	lea    0x4(%eax),%edx
f01058e0:	89 55 14             	mov    %edx,0x14(%ebp)
f01058e3:	8b 00                	mov    (%eax),%eax
f01058e5:	99                   	cltd   
f01058e6:	31 d0                	xor    %edx,%eax
f01058e8:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f01058ea:	83 f8 0f             	cmp    $0xf,%eax
f01058ed:	7f 0b                	jg     f01058fa <vprintfmt+0x146>
f01058ef:	8b 14 85 a0 84 10 f0 	mov    -0xfef7b60(,%eax,4),%edx
f01058f6:	85 d2                	test   %edx,%edx
f01058f8:	75 20                	jne    f010591a <vprintfmt+0x166>
				printfmt(putch, putdat, "error %d", err);
f01058fa:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01058fe:	c7 44 24 08 1a 82 10 	movl   $0xf010821a,0x8(%esp)
f0105905:	f0 
f0105906:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010590a:	8b 45 08             	mov    0x8(%ebp),%eax
f010590d:	89 04 24             	mov    %eax,(%esp)
f0105910:	e8 77 fe ff ff       	call   f010578c <printfmt>
f0105915:	e9 c3 fe ff ff       	jmp    f01057dd <vprintfmt+0x29>
			else
				printfmt(putch, putdat, "%s", p);
f010591a:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010591e:	c7 44 24 08 45 7a 10 	movl   $0xf0107a45,0x8(%esp)
f0105925:	f0 
f0105926:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010592a:	8b 45 08             	mov    0x8(%ebp),%eax
f010592d:	89 04 24             	mov    %eax,(%esp)
f0105930:	e8 57 fe ff ff       	call   f010578c <printfmt>
f0105935:	e9 a3 fe ff ff       	jmp    f01057dd <vprintfmt+0x29>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010593a:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f010593d:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0105940:	8b 45 14             	mov    0x14(%ebp),%eax
f0105943:	8d 50 04             	lea    0x4(%eax),%edx
f0105946:	89 55 14             	mov    %edx,0x14(%ebp)
f0105949:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f010594b:	85 c0                	test   %eax,%eax
f010594d:	ba 13 82 10 f0       	mov    $0xf0108213,%edx
f0105952:	0f 45 d0             	cmovne %eax,%edx
f0105955:	89 55 d0             	mov    %edx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f0105958:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f010595c:	74 04                	je     f0105962 <vprintfmt+0x1ae>
f010595e:	85 f6                	test   %esi,%esi
f0105960:	7f 19                	jg     f010597b <vprintfmt+0x1c7>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0105962:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0105965:	8d 70 01             	lea    0x1(%eax),%esi
f0105968:	0f b6 10             	movzbl (%eax),%edx
f010596b:	0f be c2             	movsbl %dl,%eax
f010596e:	85 c0                	test   %eax,%eax
f0105970:	0f 85 95 00 00 00    	jne    f0105a0b <vprintfmt+0x257>
f0105976:	e9 85 00 00 00       	jmp    f0105a00 <vprintfmt+0x24c>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f010597b:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f010597f:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0105982:	89 04 24             	mov    %eax,(%esp)
f0105985:	e8 88 03 00 00       	call   f0105d12 <strnlen>
f010598a:	29 c6                	sub    %eax,%esi
f010598c:	89 f0                	mov    %esi,%eax
f010598e:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0105991:	85 f6                	test   %esi,%esi
f0105993:	7e cd                	jle    f0105962 <vprintfmt+0x1ae>
					putch(padc, putdat);
f0105995:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105999:	89 5d 10             	mov    %ebx,0x10(%ebp)
f010599c:	89 c3                	mov    %eax,%ebx
f010599e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01059a2:	89 34 24             	mov    %esi,(%esp)
f01059a5:	ff 55 08             	call   *0x8(%ebp)
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f01059a8:	83 eb 01             	sub    $0x1,%ebx
f01059ab:	75 f1                	jne    f010599e <vprintfmt+0x1ea>
f01059ad:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f01059b0:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01059b3:	eb ad                	jmp    f0105962 <vprintfmt+0x1ae>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f01059b5:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f01059b9:	74 1e                	je     f01059d9 <vprintfmt+0x225>
f01059bb:	0f be d2             	movsbl %dl,%edx
f01059be:	83 ea 20             	sub    $0x20,%edx
f01059c1:	83 fa 5e             	cmp    $0x5e,%edx
f01059c4:	76 13                	jbe    f01059d9 <vprintfmt+0x225>
					putch('?', putdat);
f01059c6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01059c9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01059cd:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f01059d4:	ff 55 08             	call   *0x8(%ebp)
f01059d7:	eb 0d                	jmp    f01059e6 <vprintfmt+0x232>
				else
					putch(ch, putdat);
f01059d9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01059dc:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01059e0:	89 04 24             	mov    %eax,(%esp)
f01059e3:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01059e6:	83 ef 01             	sub    $0x1,%edi
f01059e9:	83 c6 01             	add    $0x1,%esi
f01059ec:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f01059f0:	0f be c2             	movsbl %dl,%eax
f01059f3:	85 c0                	test   %eax,%eax
f01059f5:	75 20                	jne    f0105a17 <vprintfmt+0x263>
f01059f7:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f01059fa:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01059fd:	8b 5d 10             	mov    0x10(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0105a00:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0105a04:	7f 25                	jg     f0105a2b <vprintfmt+0x277>
f0105a06:	e9 d2 fd ff ff       	jmp    f01057dd <vprintfmt+0x29>
f0105a0b:	89 7d 0c             	mov    %edi,0xc(%ebp)
f0105a0e:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0105a11:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0105a14:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0105a17:	85 db                	test   %ebx,%ebx
f0105a19:	78 9a                	js     f01059b5 <vprintfmt+0x201>
f0105a1b:	83 eb 01             	sub    $0x1,%ebx
f0105a1e:	79 95                	jns    f01059b5 <vprintfmt+0x201>
f0105a20:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f0105a23:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0105a26:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0105a29:	eb d5                	jmp    f0105a00 <vprintfmt+0x24c>
f0105a2b:	8b 75 08             	mov    0x8(%ebp),%esi
f0105a2e:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0105a31:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0105a34:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105a38:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f0105a3f:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0105a41:	83 eb 01             	sub    $0x1,%ebx
f0105a44:	75 ee                	jne    f0105a34 <vprintfmt+0x280>
f0105a46:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0105a49:	e9 8f fd ff ff       	jmp    f01057dd <vprintfmt+0x29>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f0105a4e:	83 fa 01             	cmp    $0x1,%edx
f0105a51:	7e 16                	jle    f0105a69 <vprintfmt+0x2b5>
		return va_arg(*ap, long long);
f0105a53:	8b 45 14             	mov    0x14(%ebp),%eax
f0105a56:	8d 50 08             	lea    0x8(%eax),%edx
f0105a59:	89 55 14             	mov    %edx,0x14(%ebp)
f0105a5c:	8b 50 04             	mov    0x4(%eax),%edx
f0105a5f:	8b 00                	mov    (%eax),%eax
f0105a61:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0105a64:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0105a67:	eb 32                	jmp    f0105a9b <vprintfmt+0x2e7>
	else if (lflag)
f0105a69:	85 d2                	test   %edx,%edx
f0105a6b:	74 18                	je     f0105a85 <vprintfmt+0x2d1>
		return va_arg(*ap, long);
f0105a6d:	8b 45 14             	mov    0x14(%ebp),%eax
f0105a70:	8d 50 04             	lea    0x4(%eax),%edx
f0105a73:	89 55 14             	mov    %edx,0x14(%ebp)
f0105a76:	8b 30                	mov    (%eax),%esi
f0105a78:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105a7b:	89 f0                	mov    %esi,%eax
f0105a7d:	c1 f8 1f             	sar    $0x1f,%eax
f0105a80:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0105a83:	eb 16                	jmp    f0105a9b <vprintfmt+0x2e7>
	else
		return va_arg(*ap, int);
f0105a85:	8b 45 14             	mov    0x14(%ebp),%eax
f0105a88:	8d 50 04             	lea    0x4(%eax),%edx
f0105a8b:	89 55 14             	mov    %edx,0x14(%ebp)
f0105a8e:	8b 30                	mov    (%eax),%esi
f0105a90:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105a93:	89 f0                	mov    %esi,%eax
f0105a95:	c1 f8 1f             	sar    $0x1f,%eax
f0105a98:	89 45 dc             	mov    %eax,-0x24(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f0105a9b:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0105a9e:	8b 55 dc             	mov    -0x24(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f0105aa1:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0105aa6:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f0105aaa:	0f 89 80 00 00 00    	jns    f0105b30 <vprintfmt+0x37c>
				putch('-', putdat);
f0105ab0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105ab4:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f0105abb:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f0105abe:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0105ac1:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0105ac4:	f7 d8                	neg    %eax
f0105ac6:	83 d2 00             	adc    $0x0,%edx
f0105ac9:	f7 da                	neg    %edx
			}
			base = 10;
f0105acb:	b9 0a 00 00 00       	mov    $0xa,%ecx
f0105ad0:	eb 5e                	jmp    f0105b30 <vprintfmt+0x37c>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f0105ad2:	8d 45 14             	lea    0x14(%ebp),%eax
f0105ad5:	e8 5b fc ff ff       	call   f0105735 <getuint>
			base = 10;
f0105ada:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f0105adf:	eb 4f                	jmp    f0105b30 <vprintfmt+0x37c>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			//putch('X', putdat);
			num = getuint(&ap, lflag);
f0105ae1:	8d 45 14             	lea    0x14(%ebp),%eax
f0105ae4:	e8 4c fc ff ff       	call   f0105735 <getuint>
			base = 8;
f0105ae9:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f0105aee:	eb 40                	jmp    f0105b30 <vprintfmt+0x37c>
			//putch('X', putdat);
			//break;

		// pointer
		case 'p':
			putch('0', putdat);
f0105af0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105af4:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f0105afb:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f0105afe:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105b02:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f0105b09:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f0105b0c:	8b 45 14             	mov    0x14(%ebp),%eax
f0105b0f:	8d 50 04             	lea    0x4(%eax),%edx
f0105b12:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f0105b15:	8b 00                	mov    (%eax),%eax
f0105b17:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f0105b1c:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f0105b21:	eb 0d                	jmp    f0105b30 <vprintfmt+0x37c>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f0105b23:	8d 45 14             	lea    0x14(%ebp),%eax
f0105b26:	e8 0a fc ff ff       	call   f0105735 <getuint>
			base = 16;
f0105b2b:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f0105b30:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105b34:	89 74 24 10          	mov    %esi,0x10(%esp)
f0105b38:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0105b3b:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105b3f:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0105b43:	89 04 24             	mov    %eax,(%esp)
f0105b46:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105b4a:	89 fa                	mov    %edi,%edx
f0105b4c:	8b 45 08             	mov    0x8(%ebp),%eax
f0105b4f:	e8 ec fa ff ff       	call   f0105640 <printnum>
			break;
f0105b54:	e9 84 fc ff ff       	jmp    f01057dd <vprintfmt+0x29>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0105b59:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105b5d:	89 0c 24             	mov    %ecx,(%esp)
f0105b60:	ff 55 08             	call   *0x8(%ebp)
			break;
f0105b63:	e9 75 fc ff ff       	jmp    f01057dd <vprintfmt+0x29>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0105b68:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105b6c:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0105b73:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f0105b76:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f0105b7a:	0f 84 5b fc ff ff    	je     f01057db <vprintfmt+0x27>
f0105b80:	89 f3                	mov    %esi,%ebx
f0105b82:	83 eb 01             	sub    $0x1,%ebx
f0105b85:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f0105b89:	75 f7                	jne    f0105b82 <vprintfmt+0x3ce>
f0105b8b:	e9 4d fc ff ff       	jmp    f01057dd <vprintfmt+0x29>
				/* do nothing */;
			break;
		}
	}
}
f0105b90:	83 c4 3c             	add    $0x3c,%esp
f0105b93:	5b                   	pop    %ebx
f0105b94:	5e                   	pop    %esi
f0105b95:	5f                   	pop    %edi
f0105b96:	5d                   	pop    %ebp
f0105b97:	c3                   	ret    

f0105b98 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0105b98:	55                   	push   %ebp
f0105b99:	89 e5                	mov    %esp,%ebp
f0105b9b:	83 ec 28             	sub    $0x28,%esp
f0105b9e:	8b 45 08             	mov    0x8(%ebp),%eax
f0105ba1:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0105ba4:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0105ba7:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f0105bab:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f0105bae:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0105bb5:	85 c0                	test   %eax,%eax
f0105bb7:	74 30                	je     f0105be9 <vsnprintf+0x51>
f0105bb9:	85 d2                	test   %edx,%edx
f0105bbb:	7e 2c                	jle    f0105be9 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f0105bbd:	8b 45 14             	mov    0x14(%ebp),%eax
f0105bc0:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105bc4:	8b 45 10             	mov    0x10(%ebp),%eax
f0105bc7:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105bcb:	8d 45 ec             	lea    -0x14(%ebp),%eax
f0105bce:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105bd2:	c7 04 24 6f 57 10 f0 	movl   $0xf010576f,(%esp)
f0105bd9:	e8 d6 fb ff ff       	call   f01057b4 <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0105bde:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0105be1:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0105be4:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0105be7:	eb 05                	jmp    f0105bee <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f0105be9:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f0105bee:	c9                   	leave  
f0105bef:	c3                   	ret    

f0105bf0 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f0105bf0:	55                   	push   %ebp
f0105bf1:	89 e5                	mov    %esp,%ebp
f0105bf3:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0105bf6:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f0105bf9:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105bfd:	8b 45 10             	mov    0x10(%ebp),%eax
f0105c00:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105c04:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105c07:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105c0b:	8b 45 08             	mov    0x8(%ebp),%eax
f0105c0e:	89 04 24             	mov    %eax,(%esp)
f0105c11:	e8 82 ff ff ff       	call   f0105b98 <vsnprintf>
	va_end(ap);

	return rc;
}
f0105c16:	c9                   	leave  
f0105c17:	c3                   	ret    
f0105c18:	66 90                	xchg   %ax,%ax
f0105c1a:	66 90                	xchg   %ax,%ax
f0105c1c:	66 90                	xchg   %ax,%ax
f0105c1e:	66 90                	xchg   %ax,%ax

f0105c20 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0105c20:	55                   	push   %ebp
f0105c21:	89 e5                	mov    %esp,%ebp
f0105c23:	57                   	push   %edi
f0105c24:	56                   	push   %esi
f0105c25:	53                   	push   %ebx
f0105c26:	83 ec 1c             	sub    $0x1c,%esp
f0105c29:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f0105c2c:	85 c0                	test   %eax,%eax
f0105c2e:	74 10                	je     f0105c40 <readline+0x20>
		cprintf("%s", prompt);
f0105c30:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105c34:	c7 04 24 45 7a 10 f0 	movl   $0xf0107a45,(%esp)
f0105c3b:	e8 46 e2 ff ff       	call   f0103e86 <cprintf>

	i = 0;
	echoing = iscons(0);
f0105c40:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0105c47:	e8 e2 ab ff ff       	call   f010082e <iscons>
f0105c4c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f0105c4e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0105c53:	e8 c5 ab ff ff       	call   f010081d <getchar>
f0105c58:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f0105c5a:	85 c0                	test   %eax,%eax
f0105c5c:	79 17                	jns    f0105c75 <readline+0x55>
			cprintf("read error: %e\n", c);
f0105c5e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105c62:	c7 04 24 ff 84 10 f0 	movl   $0xf01084ff,(%esp)
f0105c69:	e8 18 e2 ff ff       	call   f0103e86 <cprintf>
			return NULL;
f0105c6e:	b8 00 00 00 00       	mov    $0x0,%eax
f0105c73:	eb 6d                	jmp    f0105ce2 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0105c75:	83 f8 7f             	cmp    $0x7f,%eax
f0105c78:	74 05                	je     f0105c7f <readline+0x5f>
f0105c7a:	83 f8 08             	cmp    $0x8,%eax
f0105c7d:	75 19                	jne    f0105c98 <readline+0x78>
f0105c7f:	85 f6                	test   %esi,%esi
f0105c81:	7e 15                	jle    f0105c98 <readline+0x78>
			if (echoing)
f0105c83:	85 ff                	test   %edi,%edi
f0105c85:	74 0c                	je     f0105c93 <readline+0x73>
				cputchar('\b');
f0105c87:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f0105c8e:	e8 7a ab ff ff       	call   f010080d <cputchar>
			i--;
f0105c93:	83 ee 01             	sub    $0x1,%esi
f0105c96:	eb bb                	jmp    f0105c53 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0105c98:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f0105c9e:	7f 1c                	jg     f0105cbc <readline+0x9c>
f0105ca0:	83 fb 1f             	cmp    $0x1f,%ebx
f0105ca3:	7e 17                	jle    f0105cbc <readline+0x9c>
			if (echoing)
f0105ca5:	85 ff                	test   %edi,%edi
f0105ca7:	74 08                	je     f0105cb1 <readline+0x91>
				cputchar(c);
f0105ca9:	89 1c 24             	mov    %ebx,(%esp)
f0105cac:	e8 5c ab ff ff       	call   f010080d <cputchar>
			buf[i++] = c;
f0105cb1:	88 9e 80 7a 1c f0    	mov    %bl,-0xfe38580(%esi)
f0105cb7:	8d 76 01             	lea    0x1(%esi),%esi
f0105cba:	eb 97                	jmp    f0105c53 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f0105cbc:	83 fb 0d             	cmp    $0xd,%ebx
f0105cbf:	74 05                	je     f0105cc6 <readline+0xa6>
f0105cc1:	83 fb 0a             	cmp    $0xa,%ebx
f0105cc4:	75 8d                	jne    f0105c53 <readline+0x33>
			if (echoing)
f0105cc6:	85 ff                	test   %edi,%edi
f0105cc8:	74 0c                	je     f0105cd6 <readline+0xb6>
				cputchar('\n');
f0105cca:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0105cd1:	e8 37 ab ff ff       	call   f010080d <cputchar>
			buf[i] = 0;
f0105cd6:	c6 86 80 7a 1c f0 00 	movb   $0x0,-0xfe38580(%esi)
			return buf;
f0105cdd:	b8 80 7a 1c f0       	mov    $0xf01c7a80,%eax
		}
	}
}
f0105ce2:	83 c4 1c             	add    $0x1c,%esp
f0105ce5:	5b                   	pop    %ebx
f0105ce6:	5e                   	pop    %esi
f0105ce7:	5f                   	pop    %edi
f0105ce8:	5d                   	pop    %ebp
f0105ce9:	c3                   	ret    
f0105cea:	66 90                	xchg   %ax,%ax
f0105cec:	66 90                	xchg   %ax,%ax
f0105cee:	66 90                	xchg   %ax,%ax

f0105cf0 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0105cf0:	55                   	push   %ebp
f0105cf1:	89 e5                	mov    %esp,%ebp
f0105cf3:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0105cf6:	80 3a 00             	cmpb   $0x0,(%edx)
f0105cf9:	74 10                	je     f0105d0b <strlen+0x1b>
f0105cfb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f0105d00:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0105d03:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0105d07:	75 f7                	jne    f0105d00 <strlen+0x10>
f0105d09:	eb 05                	jmp    f0105d10 <strlen+0x20>
f0105d0b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0105d10:	5d                   	pop    %ebp
f0105d11:	c3                   	ret    

f0105d12 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0105d12:	55                   	push   %ebp
f0105d13:	89 e5                	mov    %esp,%ebp
f0105d15:	53                   	push   %ebx
f0105d16:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105d19:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0105d1c:	85 c9                	test   %ecx,%ecx
f0105d1e:	74 1c                	je     f0105d3c <strnlen+0x2a>
f0105d20:	80 3b 00             	cmpb   $0x0,(%ebx)
f0105d23:	74 1e                	je     f0105d43 <strnlen+0x31>
f0105d25:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f0105d2a:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0105d2c:	39 ca                	cmp    %ecx,%edx
f0105d2e:	74 18                	je     f0105d48 <strnlen+0x36>
f0105d30:	83 c2 01             	add    $0x1,%edx
f0105d33:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0105d38:	75 f0                	jne    f0105d2a <strnlen+0x18>
f0105d3a:	eb 0c                	jmp    f0105d48 <strnlen+0x36>
f0105d3c:	b8 00 00 00 00       	mov    $0x0,%eax
f0105d41:	eb 05                	jmp    f0105d48 <strnlen+0x36>
f0105d43:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0105d48:	5b                   	pop    %ebx
f0105d49:	5d                   	pop    %ebp
f0105d4a:	c3                   	ret    

f0105d4b <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f0105d4b:	55                   	push   %ebp
f0105d4c:	89 e5                	mov    %esp,%ebp
f0105d4e:	53                   	push   %ebx
f0105d4f:	8b 45 08             	mov    0x8(%ebp),%eax
f0105d52:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0105d55:	89 c2                	mov    %eax,%edx
f0105d57:	83 c2 01             	add    $0x1,%edx
f0105d5a:	83 c1 01             	add    $0x1,%ecx
f0105d5d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0105d61:	88 5a ff             	mov    %bl,-0x1(%edx)
f0105d64:	84 db                	test   %bl,%bl
f0105d66:	75 ef                	jne    f0105d57 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0105d68:	5b                   	pop    %ebx
f0105d69:	5d                   	pop    %ebp
f0105d6a:	c3                   	ret    

f0105d6b <strcat>:

char *
strcat(char *dst, const char *src)
{
f0105d6b:	55                   	push   %ebp
f0105d6c:	89 e5                	mov    %esp,%ebp
f0105d6e:	53                   	push   %ebx
f0105d6f:	83 ec 08             	sub    $0x8,%esp
f0105d72:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f0105d75:	89 1c 24             	mov    %ebx,(%esp)
f0105d78:	e8 73 ff ff ff       	call   f0105cf0 <strlen>
	strcpy(dst + len, src);
f0105d7d:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105d80:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105d84:	01 d8                	add    %ebx,%eax
f0105d86:	89 04 24             	mov    %eax,(%esp)
f0105d89:	e8 bd ff ff ff       	call   f0105d4b <strcpy>
	return dst;
}
f0105d8e:	89 d8                	mov    %ebx,%eax
f0105d90:	83 c4 08             	add    $0x8,%esp
f0105d93:	5b                   	pop    %ebx
f0105d94:	5d                   	pop    %ebp
f0105d95:	c3                   	ret    

f0105d96 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f0105d96:	55                   	push   %ebp
f0105d97:	89 e5                	mov    %esp,%ebp
f0105d99:	56                   	push   %esi
f0105d9a:	53                   	push   %ebx
f0105d9b:	8b 75 08             	mov    0x8(%ebp),%esi
f0105d9e:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105da1:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0105da4:	85 db                	test   %ebx,%ebx
f0105da6:	74 17                	je     f0105dbf <strncpy+0x29>
f0105da8:	01 f3                	add    %esi,%ebx
f0105daa:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f0105dac:	83 c1 01             	add    $0x1,%ecx
f0105daf:	0f b6 02             	movzbl (%edx),%eax
f0105db2:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f0105db5:	80 3a 01             	cmpb   $0x1,(%edx)
f0105db8:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0105dbb:	39 d9                	cmp    %ebx,%ecx
f0105dbd:	75 ed                	jne    f0105dac <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f0105dbf:	89 f0                	mov    %esi,%eax
f0105dc1:	5b                   	pop    %ebx
f0105dc2:	5e                   	pop    %esi
f0105dc3:	5d                   	pop    %ebp
f0105dc4:	c3                   	ret    

f0105dc5 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f0105dc5:	55                   	push   %ebp
f0105dc6:	89 e5                	mov    %esp,%ebp
f0105dc8:	57                   	push   %edi
f0105dc9:	56                   	push   %esi
f0105dca:	53                   	push   %ebx
f0105dcb:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105dce:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0105dd1:	8b 75 10             	mov    0x10(%ebp),%esi
f0105dd4:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0105dd6:	85 f6                	test   %esi,%esi
f0105dd8:	74 34                	je     f0105e0e <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f0105dda:	83 fe 01             	cmp    $0x1,%esi
f0105ddd:	74 26                	je     f0105e05 <strlcpy+0x40>
f0105ddf:	0f b6 0b             	movzbl (%ebx),%ecx
f0105de2:	84 c9                	test   %cl,%cl
f0105de4:	74 23                	je     f0105e09 <strlcpy+0x44>
f0105de6:	83 ee 02             	sub    $0x2,%esi
f0105de9:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f0105dee:	83 c0 01             	add    $0x1,%eax
f0105df1:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0105df4:	39 f2                	cmp    %esi,%edx
f0105df6:	74 13                	je     f0105e0b <strlcpy+0x46>
f0105df8:	83 c2 01             	add    $0x1,%edx
f0105dfb:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f0105dff:	84 c9                	test   %cl,%cl
f0105e01:	75 eb                	jne    f0105dee <strlcpy+0x29>
f0105e03:	eb 06                	jmp    f0105e0b <strlcpy+0x46>
f0105e05:	89 f8                	mov    %edi,%eax
f0105e07:	eb 02                	jmp    f0105e0b <strlcpy+0x46>
f0105e09:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f0105e0b:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f0105e0e:	29 f8                	sub    %edi,%eax
}
f0105e10:	5b                   	pop    %ebx
f0105e11:	5e                   	pop    %esi
f0105e12:	5f                   	pop    %edi
f0105e13:	5d                   	pop    %ebp
f0105e14:	c3                   	ret    

f0105e15 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f0105e15:	55                   	push   %ebp
f0105e16:	89 e5                	mov    %esp,%ebp
f0105e18:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0105e1b:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f0105e1e:	0f b6 01             	movzbl (%ecx),%eax
f0105e21:	84 c0                	test   %al,%al
f0105e23:	74 15                	je     f0105e3a <strcmp+0x25>
f0105e25:	3a 02                	cmp    (%edx),%al
f0105e27:	75 11                	jne    f0105e3a <strcmp+0x25>
		p++, q++;
f0105e29:	83 c1 01             	add    $0x1,%ecx
f0105e2c:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f0105e2f:	0f b6 01             	movzbl (%ecx),%eax
f0105e32:	84 c0                	test   %al,%al
f0105e34:	74 04                	je     f0105e3a <strcmp+0x25>
f0105e36:	3a 02                	cmp    (%edx),%al
f0105e38:	74 ef                	je     f0105e29 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f0105e3a:	0f b6 c0             	movzbl %al,%eax
f0105e3d:	0f b6 12             	movzbl (%edx),%edx
f0105e40:	29 d0                	sub    %edx,%eax
}
f0105e42:	5d                   	pop    %ebp
f0105e43:	c3                   	ret    

f0105e44 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0105e44:	55                   	push   %ebp
f0105e45:	89 e5                	mov    %esp,%ebp
f0105e47:	56                   	push   %esi
f0105e48:	53                   	push   %ebx
f0105e49:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105e4c:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105e4f:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f0105e52:	85 f6                	test   %esi,%esi
f0105e54:	74 29                	je     f0105e7f <strncmp+0x3b>
f0105e56:	0f b6 03             	movzbl (%ebx),%eax
f0105e59:	84 c0                	test   %al,%al
f0105e5b:	74 30                	je     f0105e8d <strncmp+0x49>
f0105e5d:	3a 02                	cmp    (%edx),%al
f0105e5f:	75 2c                	jne    f0105e8d <strncmp+0x49>
f0105e61:	8d 43 01             	lea    0x1(%ebx),%eax
f0105e64:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f0105e66:	89 c3                	mov    %eax,%ebx
f0105e68:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f0105e6b:	39 f0                	cmp    %esi,%eax
f0105e6d:	74 17                	je     f0105e86 <strncmp+0x42>
f0105e6f:	0f b6 08             	movzbl (%eax),%ecx
f0105e72:	84 c9                	test   %cl,%cl
f0105e74:	74 17                	je     f0105e8d <strncmp+0x49>
f0105e76:	83 c0 01             	add    $0x1,%eax
f0105e79:	3a 0a                	cmp    (%edx),%cl
f0105e7b:	74 e9                	je     f0105e66 <strncmp+0x22>
f0105e7d:	eb 0e                	jmp    f0105e8d <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f0105e7f:	b8 00 00 00 00       	mov    $0x0,%eax
f0105e84:	eb 0f                	jmp    f0105e95 <strncmp+0x51>
f0105e86:	b8 00 00 00 00       	mov    $0x0,%eax
f0105e8b:	eb 08                	jmp    f0105e95 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f0105e8d:	0f b6 03             	movzbl (%ebx),%eax
f0105e90:	0f b6 12             	movzbl (%edx),%edx
f0105e93:	29 d0                	sub    %edx,%eax
}
f0105e95:	5b                   	pop    %ebx
f0105e96:	5e                   	pop    %esi
f0105e97:	5d                   	pop    %ebp
f0105e98:	c3                   	ret    

f0105e99 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f0105e99:	55                   	push   %ebp
f0105e9a:	89 e5                	mov    %esp,%ebp
f0105e9c:	53                   	push   %ebx
f0105e9d:	8b 45 08             	mov    0x8(%ebp),%eax
f0105ea0:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105ea3:	0f b6 18             	movzbl (%eax),%ebx
f0105ea6:	84 db                	test   %bl,%bl
f0105ea8:	74 1d                	je     f0105ec7 <strchr+0x2e>
f0105eaa:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0105eac:	38 d3                	cmp    %dl,%bl
f0105eae:	75 06                	jne    f0105eb6 <strchr+0x1d>
f0105eb0:	eb 1a                	jmp    f0105ecc <strchr+0x33>
f0105eb2:	38 ca                	cmp    %cl,%dl
f0105eb4:	74 16                	je     f0105ecc <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0105eb6:	83 c0 01             	add    $0x1,%eax
f0105eb9:	0f b6 10             	movzbl (%eax),%edx
f0105ebc:	84 d2                	test   %dl,%dl
f0105ebe:	75 f2                	jne    f0105eb2 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0105ec0:	b8 00 00 00 00       	mov    $0x0,%eax
f0105ec5:	eb 05                	jmp    f0105ecc <strchr+0x33>
f0105ec7:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105ecc:	5b                   	pop    %ebx
f0105ecd:	5d                   	pop    %ebp
f0105ece:	c3                   	ret    

f0105ecf <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f0105ecf:	55                   	push   %ebp
f0105ed0:	89 e5                	mov    %esp,%ebp
f0105ed2:	53                   	push   %ebx
f0105ed3:	8b 45 08             	mov    0x8(%ebp),%eax
f0105ed6:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105ed9:	0f b6 18             	movzbl (%eax),%ebx
f0105edc:	84 db                	test   %bl,%bl
f0105ede:	74 16                	je     f0105ef6 <strfind+0x27>
f0105ee0:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0105ee2:	38 d3                	cmp    %dl,%bl
f0105ee4:	75 06                	jne    f0105eec <strfind+0x1d>
f0105ee6:	eb 0e                	jmp    f0105ef6 <strfind+0x27>
f0105ee8:	38 ca                	cmp    %cl,%dl
f0105eea:	74 0a                	je     f0105ef6 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f0105eec:	83 c0 01             	add    $0x1,%eax
f0105eef:	0f b6 10             	movzbl (%eax),%edx
f0105ef2:	84 d2                	test   %dl,%dl
f0105ef4:	75 f2                	jne    f0105ee8 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f0105ef6:	5b                   	pop    %ebx
f0105ef7:	5d                   	pop    %ebp
f0105ef8:	c3                   	ret    

f0105ef9 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f0105ef9:	55                   	push   %ebp
f0105efa:	89 e5                	mov    %esp,%ebp
f0105efc:	57                   	push   %edi
f0105efd:	56                   	push   %esi
f0105efe:	53                   	push   %ebx
f0105eff:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105f02:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0105f05:	85 c9                	test   %ecx,%ecx
f0105f07:	74 36                	je     f0105f3f <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f0105f09:	f7 c7 03 00 00 00    	test   $0x3,%edi
f0105f0f:	75 28                	jne    f0105f39 <memset+0x40>
f0105f11:	f6 c1 03             	test   $0x3,%cl
f0105f14:	75 23                	jne    f0105f39 <memset+0x40>
		c &= 0xFF;
f0105f16:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f0105f1a:	89 d3                	mov    %edx,%ebx
f0105f1c:	c1 e3 08             	shl    $0x8,%ebx
f0105f1f:	89 d6                	mov    %edx,%esi
f0105f21:	c1 e6 18             	shl    $0x18,%esi
f0105f24:	89 d0                	mov    %edx,%eax
f0105f26:	c1 e0 10             	shl    $0x10,%eax
f0105f29:	09 f0                	or     %esi,%eax
f0105f2b:	09 c2                	or     %eax,%edx
f0105f2d:	89 d0                	mov    %edx,%eax
f0105f2f:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f0105f31:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0105f34:	fc                   	cld    
f0105f35:	f3 ab                	rep stos %eax,%es:(%edi)
f0105f37:	eb 06                	jmp    f0105f3f <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0105f39:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105f3c:	fc                   	cld    
f0105f3d:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f0105f3f:	89 f8                	mov    %edi,%eax
f0105f41:	5b                   	pop    %ebx
f0105f42:	5e                   	pop    %esi
f0105f43:	5f                   	pop    %edi
f0105f44:	5d                   	pop    %ebp
f0105f45:	c3                   	ret    

f0105f46 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0105f46:	55                   	push   %ebp
f0105f47:	89 e5                	mov    %esp,%ebp
f0105f49:	57                   	push   %edi
f0105f4a:	56                   	push   %esi
f0105f4b:	8b 45 08             	mov    0x8(%ebp),%eax
f0105f4e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105f51:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0105f54:	39 c6                	cmp    %eax,%esi
f0105f56:	73 35                	jae    f0105f8d <memmove+0x47>
f0105f58:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0105f5b:	39 d0                	cmp    %edx,%eax
f0105f5d:	73 2e                	jae    f0105f8d <memmove+0x47>
		s += n;
		d += n;
f0105f5f:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0105f62:	89 d6                	mov    %edx,%esi
f0105f64:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105f66:	f7 c6 03 00 00 00    	test   $0x3,%esi
f0105f6c:	75 13                	jne    f0105f81 <memmove+0x3b>
f0105f6e:	f6 c1 03             	test   $0x3,%cl
f0105f71:	75 0e                	jne    f0105f81 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0105f73:	83 ef 04             	sub    $0x4,%edi
f0105f76:	8d 72 fc             	lea    -0x4(%edx),%esi
f0105f79:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f0105f7c:	fd                   	std    
f0105f7d:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0105f7f:	eb 09                	jmp    f0105f8a <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0105f81:	83 ef 01             	sub    $0x1,%edi
f0105f84:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0105f87:	fd                   	std    
f0105f88:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0105f8a:	fc                   	cld    
f0105f8b:	eb 1d                	jmp    f0105faa <memmove+0x64>
f0105f8d:	89 f2                	mov    %esi,%edx
f0105f8f:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105f91:	f6 c2 03             	test   $0x3,%dl
f0105f94:	75 0f                	jne    f0105fa5 <memmove+0x5f>
f0105f96:	f6 c1 03             	test   $0x3,%cl
f0105f99:	75 0a                	jne    f0105fa5 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0105f9b:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f0105f9e:	89 c7                	mov    %eax,%edi
f0105fa0:	fc                   	cld    
f0105fa1:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0105fa3:	eb 05                	jmp    f0105faa <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0105fa5:	89 c7                	mov    %eax,%edi
f0105fa7:	fc                   	cld    
f0105fa8:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f0105faa:	5e                   	pop    %esi
f0105fab:	5f                   	pop    %edi
f0105fac:	5d                   	pop    %ebp
f0105fad:	c3                   	ret    

f0105fae <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f0105fae:	55                   	push   %ebp
f0105faf:	89 e5                	mov    %esp,%ebp
f0105fb1:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0105fb4:	8b 45 10             	mov    0x10(%ebp),%eax
f0105fb7:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105fbb:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105fbe:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105fc2:	8b 45 08             	mov    0x8(%ebp),%eax
f0105fc5:	89 04 24             	mov    %eax,(%esp)
f0105fc8:	e8 79 ff ff ff       	call   f0105f46 <memmove>
}
f0105fcd:	c9                   	leave  
f0105fce:	c3                   	ret    

f0105fcf <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f0105fcf:	55                   	push   %ebp
f0105fd0:	89 e5                	mov    %esp,%ebp
f0105fd2:	57                   	push   %edi
f0105fd3:	56                   	push   %esi
f0105fd4:	53                   	push   %ebx
f0105fd5:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105fd8:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105fdb:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0105fde:	8d 78 ff             	lea    -0x1(%eax),%edi
f0105fe1:	85 c0                	test   %eax,%eax
f0105fe3:	74 36                	je     f010601b <memcmp+0x4c>
		if (*s1 != *s2)
f0105fe5:	0f b6 03             	movzbl (%ebx),%eax
f0105fe8:	0f b6 0e             	movzbl (%esi),%ecx
f0105feb:	ba 00 00 00 00       	mov    $0x0,%edx
f0105ff0:	38 c8                	cmp    %cl,%al
f0105ff2:	74 1c                	je     f0106010 <memcmp+0x41>
f0105ff4:	eb 10                	jmp    f0106006 <memcmp+0x37>
f0105ff6:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f0105ffb:	83 c2 01             	add    $0x1,%edx
f0105ffe:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f0106002:	38 c8                	cmp    %cl,%al
f0106004:	74 0a                	je     f0106010 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f0106006:	0f b6 c0             	movzbl %al,%eax
f0106009:	0f b6 c9             	movzbl %cl,%ecx
f010600c:	29 c8                	sub    %ecx,%eax
f010600e:	eb 10                	jmp    f0106020 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0106010:	39 fa                	cmp    %edi,%edx
f0106012:	75 e2                	jne    f0105ff6 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f0106014:	b8 00 00 00 00       	mov    $0x0,%eax
f0106019:	eb 05                	jmp    f0106020 <memcmp+0x51>
f010601b:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0106020:	5b                   	pop    %ebx
f0106021:	5e                   	pop    %esi
f0106022:	5f                   	pop    %edi
f0106023:	5d                   	pop    %ebp
f0106024:	c3                   	ret    

f0106025 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0106025:	55                   	push   %ebp
f0106026:	89 e5                	mov    %esp,%ebp
f0106028:	53                   	push   %ebx
f0106029:	8b 45 08             	mov    0x8(%ebp),%eax
f010602c:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f010602f:	89 c2                	mov    %eax,%edx
f0106031:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0106034:	39 d0                	cmp    %edx,%eax
f0106036:	73 13                	jae    f010604b <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f0106038:	89 d9                	mov    %ebx,%ecx
f010603a:	38 18                	cmp    %bl,(%eax)
f010603c:	75 06                	jne    f0106044 <memfind+0x1f>
f010603e:	eb 0b                	jmp    f010604b <memfind+0x26>
f0106040:	38 08                	cmp    %cl,(%eax)
f0106042:	74 07                	je     f010604b <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f0106044:	83 c0 01             	add    $0x1,%eax
f0106047:	39 d0                	cmp    %edx,%eax
f0106049:	75 f5                	jne    f0106040 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f010604b:	5b                   	pop    %ebx
f010604c:	5d                   	pop    %ebp
f010604d:	c3                   	ret    

f010604e <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f010604e:	55                   	push   %ebp
f010604f:	89 e5                	mov    %esp,%ebp
f0106051:	57                   	push   %edi
f0106052:	56                   	push   %esi
f0106053:	53                   	push   %ebx
f0106054:	8b 55 08             	mov    0x8(%ebp),%edx
f0106057:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010605a:	0f b6 0a             	movzbl (%edx),%ecx
f010605d:	80 f9 09             	cmp    $0x9,%cl
f0106060:	74 05                	je     f0106067 <strtol+0x19>
f0106062:	80 f9 20             	cmp    $0x20,%cl
f0106065:	75 10                	jne    f0106077 <strtol+0x29>
		s++;
f0106067:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010606a:	0f b6 0a             	movzbl (%edx),%ecx
f010606d:	80 f9 09             	cmp    $0x9,%cl
f0106070:	74 f5                	je     f0106067 <strtol+0x19>
f0106072:	80 f9 20             	cmp    $0x20,%cl
f0106075:	74 f0                	je     f0106067 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f0106077:	80 f9 2b             	cmp    $0x2b,%cl
f010607a:	75 0a                	jne    f0106086 <strtol+0x38>
		s++;
f010607c:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f010607f:	bf 00 00 00 00       	mov    $0x0,%edi
f0106084:	eb 11                	jmp    f0106097 <strtol+0x49>
f0106086:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f010608b:	80 f9 2d             	cmp    $0x2d,%cl
f010608e:	75 07                	jne    f0106097 <strtol+0x49>
		s++, neg = 1;
f0106090:	83 c2 01             	add    $0x1,%edx
f0106093:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0106097:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f010609c:	75 15                	jne    f01060b3 <strtol+0x65>
f010609e:	80 3a 30             	cmpb   $0x30,(%edx)
f01060a1:	75 10                	jne    f01060b3 <strtol+0x65>
f01060a3:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f01060a7:	75 0a                	jne    f01060b3 <strtol+0x65>
		s += 2, base = 16;
f01060a9:	83 c2 02             	add    $0x2,%edx
f01060ac:	b8 10 00 00 00       	mov    $0x10,%eax
f01060b1:	eb 10                	jmp    f01060c3 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f01060b3:	85 c0                	test   %eax,%eax
f01060b5:	75 0c                	jne    f01060c3 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f01060b7:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f01060b9:	80 3a 30             	cmpb   $0x30,(%edx)
f01060bc:	75 05                	jne    f01060c3 <strtol+0x75>
		s++, base = 8;
f01060be:	83 c2 01             	add    $0x1,%edx
f01060c1:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f01060c3:	bb 00 00 00 00       	mov    $0x0,%ebx
f01060c8:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f01060cb:	0f b6 0a             	movzbl (%edx),%ecx
f01060ce:	8d 71 d0             	lea    -0x30(%ecx),%esi
f01060d1:	89 f0                	mov    %esi,%eax
f01060d3:	3c 09                	cmp    $0x9,%al
f01060d5:	77 08                	ja     f01060df <strtol+0x91>
			dig = *s - '0';
f01060d7:	0f be c9             	movsbl %cl,%ecx
f01060da:	83 e9 30             	sub    $0x30,%ecx
f01060dd:	eb 20                	jmp    f01060ff <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f01060df:	8d 71 9f             	lea    -0x61(%ecx),%esi
f01060e2:	89 f0                	mov    %esi,%eax
f01060e4:	3c 19                	cmp    $0x19,%al
f01060e6:	77 08                	ja     f01060f0 <strtol+0xa2>
			dig = *s - 'a' + 10;
f01060e8:	0f be c9             	movsbl %cl,%ecx
f01060eb:	83 e9 57             	sub    $0x57,%ecx
f01060ee:	eb 0f                	jmp    f01060ff <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f01060f0:	8d 71 bf             	lea    -0x41(%ecx),%esi
f01060f3:	89 f0                	mov    %esi,%eax
f01060f5:	3c 19                	cmp    $0x19,%al
f01060f7:	77 16                	ja     f010610f <strtol+0xc1>
			dig = *s - 'A' + 10;
f01060f9:	0f be c9             	movsbl %cl,%ecx
f01060fc:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f01060ff:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f0106102:	7d 0f                	jge    f0106113 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f0106104:	83 c2 01             	add    $0x1,%edx
f0106107:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f010610b:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f010610d:	eb bc                	jmp    f01060cb <strtol+0x7d>
f010610f:	89 d8                	mov    %ebx,%eax
f0106111:	eb 02                	jmp    f0106115 <strtol+0xc7>
f0106113:	89 d8                	mov    %ebx,%eax

	if (endptr)
f0106115:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0106119:	74 05                	je     f0106120 <strtol+0xd2>
		*endptr = (char *) s;
f010611b:	8b 75 0c             	mov    0xc(%ebp),%esi
f010611e:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f0106120:	f7 d8                	neg    %eax
f0106122:	85 ff                	test   %edi,%edi
f0106124:	0f 44 c3             	cmove  %ebx,%eax
}
f0106127:	5b                   	pop    %ebx
f0106128:	5e                   	pop    %esi
f0106129:	5f                   	pop    %edi
f010612a:	5d                   	pop    %ebp
f010612b:	c3                   	ret    

f010612c <mpentry_start>:
.set PROT_MODE_DSEG, 0x10	# kernel data segment selector

.code16           
.globl mpentry_start
mpentry_start:
	cli            
f010612c:	fa                   	cli    

	xorw    %ax, %ax
f010612d:	31 c0                	xor    %eax,%eax
	movw    %ax, %ds
f010612f:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0106131:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0106133:	8e d0                	mov    %eax,%ss

	lgdt    MPBOOTPHYS(gdtdesc)
f0106135:	0f 01 16             	lgdtl  (%esi)
f0106138:	74 70                	je     f01061aa <mpentry_end+0x4>
	movl    %cr0, %eax
f010613a:	0f 20 c0             	mov    %cr0,%eax
	orl     $CR0_PE, %eax
f010613d:	66 83 c8 01          	or     $0x1,%ax
	movl    %eax, %cr0
f0106141:	0f 22 c0             	mov    %eax,%cr0

	ljmpl   $(PROT_MODE_CSEG), $(MPBOOTPHYS(start32))
f0106144:	66 ea 20 70 00 00    	ljmpw  $0x0,$0x7020
f010614a:	08 00                	or     %al,(%eax)

f010614c <start32>:

.code32
start32:
	movw    $(PROT_MODE_DSEG), %ax
f010614c:	66 b8 10 00          	mov    $0x10,%ax
	movw    %ax, %ds
f0106150:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0106152:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0106154:	8e d0                	mov    %eax,%ss
	movw    $0, %ax
f0106156:	66 b8 00 00          	mov    $0x0,%ax
	movw    %ax, %fs
f010615a:	8e e0                	mov    %eax,%fs
	movw    %ax, %gs
f010615c:	8e e8                	mov    %eax,%gs

	# Set up initial page table. We cannot use kern_pgdir yet because
	# we are still running at a low EIP.
	movl    $(RELOC(entry_pgdir)), %eax
f010615e:	b8 00 f0 11 00       	mov    $0x11f000,%eax
	movl    %eax, %cr3
f0106163:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl    %cr0, %eax
f0106166:	0f 20 c0             	mov    %cr0,%eax
	orl     $(CR0_PE|CR0_PG|CR0_WP), %eax
f0106169:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl    %eax, %cr0
f010616e:	0f 22 c0             	mov    %eax,%cr0

	# Switch to the per-cpu stack allocated in mem_init()
	movl    mpentry_kstack, %esp
f0106171:	8b 25 84 7e 1c f0    	mov    0xf01c7e84,%esp
	movl    $0x0, %ebp       # nuke frame pointer
f0106177:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Call mp_main().  (Exercise for the reader: why the indirect call?)
	movl    $mp_main, %eax
f010617c:	b8 57 02 10 f0       	mov    $0xf0100257,%eax
	call    *%eax
f0106181:	ff d0                	call   *%eax

f0106183 <spin>:

	# If mp_main returns (it shouldn't), loop.
spin:
	jmp     spin
f0106183:	eb fe                	jmp    f0106183 <spin>
f0106185:	8d 76 00             	lea    0x0(%esi),%esi

f0106188 <gdt>:
	...
f0106190:	ff                   	(bad)  
f0106191:	ff 00                	incl   (%eax)
f0106193:	00 00                	add    %al,(%eax)
f0106195:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
f010619c:	00 92 cf 00 17 00    	add    %dl,0x1700cf(%edx)

f01061a0 <gdtdesc>:
f01061a0:	17                   	pop    %ss
f01061a1:	00 5c 70 00          	add    %bl,0x0(%eax,%esi,2)
	...

f01061a6 <mpentry_end>:
	.word   0x17				# sizeof(gdt) - 1
	.long   MPBOOTPHYS(gdt)			# address gdt

.globl mpentry_end
mpentry_end:
	nop
f01061a6:	90                   	nop
f01061a7:	66 90                	xchg   %ax,%ax
f01061a9:	66 90                	xchg   %ax,%ax
f01061ab:	66 90                	xchg   %ax,%ax
f01061ad:	66 90                	xchg   %ax,%ax
f01061af:	90                   	nop

f01061b0 <mpsearch1>:
}

// Look for an MP structure in the len bytes at physical address addr.
static struct mp *
mpsearch1(physaddr_t a, int len)
{
f01061b0:	55                   	push   %ebp
f01061b1:	89 e5                	mov    %esp,%ebp
f01061b3:	56                   	push   %esi
f01061b4:	53                   	push   %ebx
f01061b5:	83 ec 10             	sub    $0x10,%esp
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01061b8:	8b 0d 88 7e 1c f0    	mov    0xf01c7e88,%ecx
f01061be:	89 c3                	mov    %eax,%ebx
f01061c0:	c1 eb 0c             	shr    $0xc,%ebx
f01061c3:	39 cb                	cmp    %ecx,%ebx
f01061c5:	72 20                	jb     f01061e7 <mpsearch1+0x37>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01061c7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01061cb:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f01061d2:	f0 
f01061d3:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f01061da:	00 
f01061db:	c7 04 24 9d 86 10 f0 	movl   $0xf010869d,(%esp)
f01061e2:	e8 59 9e ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01061e7:	8d 98 00 00 00 f0    	lea    -0x10000000(%eax),%ebx
	struct mp *mp = KADDR(a), *end = KADDR(a + len);
f01061ed:	01 d0                	add    %edx,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01061ef:	89 c2                	mov    %eax,%edx
f01061f1:	c1 ea 0c             	shr    $0xc,%edx
f01061f4:	39 d1                	cmp    %edx,%ecx
f01061f6:	77 20                	ja     f0106218 <mpsearch1+0x68>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01061f8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01061fc:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f0106203:	f0 
f0106204:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f010620b:	00 
f010620c:	c7 04 24 9d 86 10 f0 	movl   $0xf010869d,(%esp)
f0106213:	e8 28 9e ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0106218:	8d b0 00 00 00 f0    	lea    -0x10000000(%eax),%esi

	for (; mp < end; mp++)
f010621e:	39 f3                	cmp    %esi,%ebx
f0106220:	73 40                	jae    f0106262 <mpsearch1+0xb2>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0106222:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0106229:	00 
f010622a:	c7 44 24 04 ad 86 10 	movl   $0xf01086ad,0x4(%esp)
f0106231:	f0 
f0106232:	89 1c 24             	mov    %ebx,(%esp)
f0106235:	e8 95 fd ff ff       	call   f0105fcf <memcmp>
f010623a:	85 c0                	test   %eax,%eax
f010623c:	75 17                	jne    f0106255 <mpsearch1+0xa5>
f010623e:	ba 00 00 00 00       	mov    $0x0,%edx
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
		sum += ((uint8_t *)addr)[i];
f0106243:	0f b6 0c 03          	movzbl (%ebx,%eax,1),%ecx
f0106247:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106249:	83 c0 01             	add    $0x1,%eax
f010624c:	83 f8 10             	cmp    $0x10,%eax
f010624f:	75 f2                	jne    f0106243 <mpsearch1+0x93>
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0106251:	84 d2                	test   %dl,%dl
f0106253:	74 14                	je     f0106269 <mpsearch1+0xb9>
static struct mp *
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
f0106255:	83 c3 10             	add    $0x10,%ebx
f0106258:	39 f3                	cmp    %esi,%ebx
f010625a:	72 c6                	jb     f0106222 <mpsearch1+0x72>
f010625c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106260:	eb 0b                	jmp    f010626d <mpsearch1+0xbd>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
		    sum(mp, sizeof(*mp)) == 0)
			return mp;
	return NULL;
f0106262:	b8 00 00 00 00       	mov    $0x0,%eax
f0106267:	eb 09                	jmp    f0106272 <mpsearch1+0xc2>
f0106269:	89 d8                	mov    %ebx,%eax
f010626b:	eb 05                	jmp    f0106272 <mpsearch1+0xc2>
f010626d:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0106272:	83 c4 10             	add    $0x10,%esp
f0106275:	5b                   	pop    %ebx
f0106276:	5e                   	pop    %esi
f0106277:	5d                   	pop    %ebp
f0106278:	c3                   	ret    

f0106279 <mp_init>:
	return conf;
}

void
mp_init(void)
{
f0106279:	55                   	push   %ebp
f010627a:	89 e5                	mov    %esp,%ebp
f010627c:	57                   	push   %edi
f010627d:	56                   	push   %esi
f010627e:	53                   	push   %ebx
f010627f:	83 ec 2c             	sub    $0x2c,%esp
	struct mpconf *conf;
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
f0106282:	c7 05 c0 83 1c f0 20 	movl   $0xf01c8020,0xf01c83c0
f0106289:	80 1c f0 
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010628c:	83 3d 88 7e 1c f0 00 	cmpl   $0x0,0xf01c7e88
f0106293:	75 24                	jne    f01062b9 <mp_init+0x40>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106295:	c7 44 24 0c 00 04 00 	movl   $0x400,0xc(%esp)
f010629c:	00 
f010629d:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f01062a4:	f0 
f01062a5:	c7 44 24 04 6f 00 00 	movl   $0x6f,0x4(%esp)
f01062ac:	00 
f01062ad:	c7 04 24 9d 86 10 f0 	movl   $0xf010869d,(%esp)
f01062b4:	e8 87 9d ff ff       	call   f0100040 <_panic>
	// The BIOS data area lives in 16-bit segment 0x40.
	bda = (uint8_t *) KADDR(0x40 << 4);

	// [MP 4] The 16-bit segment of the EBDA is in the two bytes
	// starting at byte 0x0E of the BDA.  0 if not present.
	if ((p = *(uint16_t *) (bda + 0x0E))) {
f01062b9:	0f b7 05 0e 04 00 f0 	movzwl 0xf000040e,%eax
f01062c0:	85 c0                	test   %eax,%eax
f01062c2:	74 16                	je     f01062da <mp_init+0x61>
		p <<= 4;	// Translate from segment to PA
f01062c4:	c1 e0 04             	shl    $0x4,%eax
		if ((mp = mpsearch1(p, 1024)))
f01062c7:	ba 00 04 00 00       	mov    $0x400,%edx
f01062cc:	e8 df fe ff ff       	call   f01061b0 <mpsearch1>
f01062d1:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01062d4:	85 c0                	test   %eax,%eax
f01062d6:	75 3c                	jne    f0106314 <mp_init+0x9b>
f01062d8:	eb 20                	jmp    f01062fa <mp_init+0x81>
			return mp;
	} else {
		// The size of base memory, in KB is in the two bytes
		// starting at 0x13 of the BDA.
		p = *(uint16_t *) (bda + 0x13) * 1024;
f01062da:	0f b7 05 13 04 00 f0 	movzwl 0xf0000413,%eax
f01062e1:	c1 e0 0a             	shl    $0xa,%eax
		if ((mp = mpsearch1(p - 1024, 1024)))
f01062e4:	2d 00 04 00 00       	sub    $0x400,%eax
f01062e9:	ba 00 04 00 00       	mov    $0x400,%edx
f01062ee:	e8 bd fe ff ff       	call   f01061b0 <mpsearch1>
f01062f3:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01062f6:	85 c0                	test   %eax,%eax
f01062f8:	75 1a                	jne    f0106314 <mp_init+0x9b>
			return mp;
	}
	return mpsearch1(0xF0000, 0x10000);
f01062fa:	ba 00 00 01 00       	mov    $0x10000,%edx
f01062ff:	b8 00 00 0f 00       	mov    $0xf0000,%eax
f0106304:	e8 a7 fe ff ff       	call   f01061b0 <mpsearch1>
f0106309:	89 45 e4             	mov    %eax,-0x1c(%ebp)
mpconfig(struct mp **pmp)
{
	struct mpconf *conf;
	struct mp *mp;

	if ((mp = mpsearch()) == 0)
f010630c:	85 c0                	test   %eax,%eax
f010630e:	0f 84 5f 02 00 00    	je     f0106573 <mp_init+0x2fa>
		return NULL;
	if (mp->physaddr == 0 || mp->type != 0) {
f0106314:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0106317:	8b 70 04             	mov    0x4(%eax),%esi
f010631a:	85 f6                	test   %esi,%esi
f010631c:	74 06                	je     f0106324 <mp_init+0xab>
f010631e:	80 78 0b 00          	cmpb   $0x0,0xb(%eax)
f0106322:	74 11                	je     f0106335 <mp_init+0xbc>
		cprintf("SMP: Default configurations not implemented\n");
f0106324:	c7 04 24 10 85 10 f0 	movl   $0xf0108510,(%esp)
f010632b:	e8 56 db ff ff       	call   f0103e86 <cprintf>
f0106330:	e9 3e 02 00 00       	jmp    f0106573 <mp_init+0x2fa>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0106335:	89 f0                	mov    %esi,%eax
f0106337:	c1 e8 0c             	shr    $0xc,%eax
f010633a:	3b 05 88 7e 1c f0    	cmp    0xf01c7e88,%eax
f0106340:	72 20                	jb     f0106362 <mp_init+0xe9>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106342:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0106346:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f010634d:	f0 
f010634e:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f0106355:	00 
f0106356:	c7 04 24 9d 86 10 f0 	movl   $0xf010869d,(%esp)
f010635d:	e8 de 9c ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0106362:	8d 9e 00 00 00 f0    	lea    -0x10000000(%esi),%ebx
		return NULL;
	}
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
f0106368:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f010636f:	00 
f0106370:	c7 44 24 04 b2 86 10 	movl   $0xf01086b2,0x4(%esp)
f0106377:	f0 
f0106378:	89 1c 24             	mov    %ebx,(%esp)
f010637b:	e8 4f fc ff ff       	call   f0105fcf <memcmp>
f0106380:	85 c0                	test   %eax,%eax
f0106382:	74 11                	je     f0106395 <mp_init+0x11c>
		cprintf("SMP: Incorrect MP configuration table signature\n");
f0106384:	c7 04 24 40 85 10 f0 	movl   $0xf0108540,(%esp)
f010638b:	e8 f6 da ff ff       	call   f0103e86 <cprintf>
f0106390:	e9 de 01 00 00       	jmp    f0106573 <mp_init+0x2fa>
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0106395:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0106399:	66 89 45 e2          	mov    %ax,-0x1e(%ebp)
f010639d:	0f b7 f8             	movzwl %ax,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f01063a0:	85 ff                	test   %edi,%edi
f01063a2:	7e 30                	jle    f01063d4 <mp_init+0x15b>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f01063a4:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f01063a9:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f01063ae:	0f b6 8c 30 00 00 00 	movzbl -0x10000000(%eax,%esi,1),%ecx
f01063b5:	f0 
f01063b6:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f01063b8:	83 c0 01             	add    $0x1,%eax
f01063bb:	39 c7                	cmp    %eax,%edi
f01063bd:	7f ef                	jg     f01063ae <mp_init+0x135>
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
		cprintf("SMP: Incorrect MP configuration table signature\n");
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f01063bf:	84 d2                	test   %dl,%dl
f01063c1:	74 11                	je     f01063d4 <mp_init+0x15b>
		cprintf("SMP: Bad MP configuration checksum\n");
f01063c3:	c7 04 24 74 85 10 f0 	movl   $0xf0108574,(%esp)
f01063ca:	e8 b7 da ff ff       	call   f0103e86 <cprintf>
f01063cf:	e9 9f 01 00 00       	jmp    f0106573 <mp_init+0x2fa>
		return NULL;
	}
	if (conf->version != 1 && conf->version != 4) {
f01063d4:	0f b6 43 06          	movzbl 0x6(%ebx),%eax
f01063d8:	3c 04                	cmp    $0x4,%al
f01063da:	74 1e                	je     f01063fa <mp_init+0x181>
f01063dc:	3c 01                	cmp    $0x1,%al
f01063de:	66 90                	xchg   %ax,%ax
f01063e0:	74 18                	je     f01063fa <mp_init+0x181>
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
f01063e2:	0f b6 c0             	movzbl %al,%eax
f01063e5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01063e9:	c7 04 24 98 85 10 f0 	movl   $0xf0108598,(%esp)
f01063f0:	e8 91 da ff ff       	call   f0103e86 <cprintf>
f01063f5:	e9 79 01 00 00       	jmp    f0106573 <mp_init+0x2fa>
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f01063fa:	0f b7 73 28          	movzwl 0x28(%ebx),%esi
f01063fe:	0f b7 7d e2          	movzwl -0x1e(%ebp),%edi
f0106402:	01 df                	add    %ebx,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106404:	85 f6                	test   %esi,%esi
f0106406:	7e 19                	jle    f0106421 <mp_init+0x1a8>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0106408:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f010640d:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0106412:	0f b6 0c 07          	movzbl (%edi,%eax,1),%ecx
f0106416:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106418:	83 c0 01             	add    $0x1,%eax
f010641b:	39 c6                	cmp    %eax,%esi
f010641d:	7f f3                	jg     f0106412 <mp_init+0x199>
f010641f:	eb 05                	jmp    f0106426 <mp_init+0x1ad>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0106421:	ba 00 00 00 00       	mov    $0x0,%edx
	}
	if (conf->version != 1 && conf->version != 4) {
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0106426:	38 53 2a             	cmp    %dl,0x2a(%ebx)
f0106429:	74 11                	je     f010643c <mp_init+0x1c3>
		cprintf("SMP: Bad MP configuration extended checksum\n");
f010642b:	c7 04 24 b8 85 10 f0 	movl   $0xf01085b8,(%esp)
f0106432:	e8 4f da ff ff       	call   f0103e86 <cprintf>
f0106437:	e9 37 01 00 00       	jmp    f0106573 <mp_init+0x2fa>
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
	if ((conf = mpconfig(&mp)) == 0)
f010643c:	85 db                	test   %ebx,%ebx
f010643e:	0f 84 2f 01 00 00    	je     f0106573 <mp_init+0x2fa>
		return;
	ismp = 1;
f0106444:	c7 05 00 80 1c f0 01 	movl   $0x1,0xf01c8000
f010644b:	00 00 00 
	lapic = (uint32_t *)conf->lapicaddr;
f010644e:	8b 43 24             	mov    0x24(%ebx),%eax
f0106451:	a3 00 90 20 f0       	mov    %eax,0xf0209000

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0106456:	8d 7b 2c             	lea    0x2c(%ebx),%edi
f0106459:	66 83 7b 22 00       	cmpw   $0x0,0x22(%ebx)
f010645e:	0f 84 94 00 00 00    	je     f01064f8 <mp_init+0x27f>
f0106464:	be 00 00 00 00       	mov    $0x0,%esi
		switch (*p) {
f0106469:	0f b6 07             	movzbl (%edi),%eax
f010646c:	84 c0                	test   %al,%al
f010646e:	74 06                	je     f0106476 <mp_init+0x1fd>
f0106470:	3c 04                	cmp    $0x4,%al
f0106472:	77 54                	ja     f01064c8 <mp_init+0x24f>
f0106474:	eb 4d                	jmp    f01064c3 <mp_init+0x24a>
		case MPPROC:
			proc = (struct mpproc *)p;
			if (proc->flags & MPPROC_BOOT)
f0106476:	f6 47 03 02          	testb  $0x2,0x3(%edi)
f010647a:	74 11                	je     f010648d <mp_init+0x214>
				bootcpu = &cpus[ncpu];
f010647c:	6b 05 c4 83 1c f0 74 	imul   $0x74,0xf01c83c4,%eax
f0106483:	05 20 80 1c f0       	add    $0xf01c8020,%eax
f0106488:	a3 c0 83 1c f0       	mov    %eax,0xf01c83c0
			if (ncpu < NCPU) {
f010648d:	a1 c4 83 1c f0       	mov    0xf01c83c4,%eax
f0106492:	83 f8 07             	cmp    $0x7,%eax
f0106495:	7f 13                	jg     f01064aa <mp_init+0x231>
				cpus[ncpu].cpu_id = ncpu;
f0106497:	6b d0 74             	imul   $0x74,%eax,%edx
f010649a:	88 82 20 80 1c f0    	mov    %al,-0xfe37fe0(%edx)
				ncpu++;
f01064a0:	83 c0 01             	add    $0x1,%eax
f01064a3:	a3 c4 83 1c f0       	mov    %eax,0xf01c83c4
f01064a8:	eb 14                	jmp    f01064be <mp_init+0x245>
			} else {
				cprintf("SMP: too many CPUs, CPU %d disabled\n",
f01064aa:	0f b6 47 01          	movzbl 0x1(%edi),%eax
f01064ae:	89 44 24 04          	mov    %eax,0x4(%esp)
f01064b2:	c7 04 24 e8 85 10 f0 	movl   $0xf01085e8,(%esp)
f01064b9:	e8 c8 d9 ff ff       	call   f0103e86 <cprintf>
					proc->apicid);
			}
			p += sizeof(struct mpproc);
f01064be:	83 c7 14             	add    $0x14,%edi
			continue;
f01064c1:	eb 26                	jmp    f01064e9 <mp_init+0x270>
		case MPBUS:
		case MPIOAPIC:
		case MPIOINTR:
		case MPLINTR:
			p += 8;
f01064c3:	83 c7 08             	add    $0x8,%edi
			continue;
f01064c6:	eb 21                	jmp    f01064e9 <mp_init+0x270>
		default:
			cprintf("mpinit: unknown config type %x\n", *p);
f01064c8:	0f b6 c0             	movzbl %al,%eax
f01064cb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01064cf:	c7 04 24 10 86 10 f0 	movl   $0xf0108610,(%esp)
f01064d6:	e8 ab d9 ff ff       	call   f0103e86 <cprintf>
			ismp = 0;
f01064db:	c7 05 00 80 1c f0 00 	movl   $0x0,0xf01c8000
f01064e2:	00 00 00 
			i = conf->entry;
f01064e5:	0f b7 73 22          	movzwl 0x22(%ebx),%esi
	if ((conf = mpconfig(&mp)) == 0)
		return;
	ismp = 1;
	lapic = (uint32_t *)conf->lapicaddr;

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f01064e9:	83 c6 01             	add    $0x1,%esi
f01064ec:	0f b7 43 22          	movzwl 0x22(%ebx),%eax
f01064f0:	39 f0                	cmp    %esi,%eax
f01064f2:	0f 87 71 ff ff ff    	ja     f0106469 <mp_init+0x1f0>
			ismp = 0;
			i = conf->entry;
		}
	}

	bootcpu->cpu_status = CPU_STARTED;
f01064f8:	a1 c0 83 1c f0       	mov    0xf01c83c0,%eax
f01064fd:	c7 40 04 01 00 00 00 	movl   $0x1,0x4(%eax)
	if (!ismp) {
f0106504:	83 3d 00 80 1c f0 00 	cmpl   $0x0,0xf01c8000
f010650b:	75 22                	jne    f010652f <mp_init+0x2b6>
		// Didn't like what we found; fall back to no MP.
		ncpu = 1;
f010650d:	c7 05 c4 83 1c f0 01 	movl   $0x1,0xf01c83c4
f0106514:	00 00 00 
		lapic = NULL;
f0106517:	c7 05 00 90 20 f0 00 	movl   $0x0,0xf0209000
f010651e:	00 00 00 
		cprintf("SMP: configuration not found, SMP disabled\n");
f0106521:	c7 04 24 30 86 10 f0 	movl   $0xf0108630,(%esp)
f0106528:	e8 59 d9 ff ff       	call   f0103e86 <cprintf>
		return;
f010652d:	eb 44                	jmp    f0106573 <mp_init+0x2fa>
	}
	cprintf("SMP: CPU %d found %d CPU(s)\n", bootcpu->cpu_id,  ncpu);
f010652f:	8b 15 c4 83 1c f0    	mov    0xf01c83c4,%edx
f0106535:	89 54 24 08          	mov    %edx,0x8(%esp)
f0106539:	0f b6 00             	movzbl (%eax),%eax
f010653c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106540:	c7 04 24 b7 86 10 f0 	movl   $0xf01086b7,(%esp)
f0106547:	e8 3a d9 ff ff       	call   f0103e86 <cprintf>

	if (mp->imcrp) {
f010654c:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010654f:	80 78 0c 00          	cmpb   $0x0,0xc(%eax)
f0106553:	74 1e                	je     f0106573 <mp_init+0x2fa>
		// [MP 3.2.6.1] If the hardware implements PIC mode,
		// switch to getting interrupts from the LAPIC.
		cprintf("SMP: Setting IMCR to switch from PIC mode to symmetric I/O mode\n");
f0106555:	c7 04 24 5c 86 10 f0 	movl   $0xf010865c,(%esp)
f010655c:	e8 25 d9 ff ff       	call   f0103e86 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0106561:	ba 22 00 00 00       	mov    $0x22,%edx
f0106566:	b8 70 00 00 00       	mov    $0x70,%eax
f010656b:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010656c:	b2 23                	mov    $0x23,%dl
f010656e:	ec                   	in     (%dx),%al
		outb(0x22, 0x70);   // Select IMCR
		outb(0x23, inb(0x23) | 1);  // Mask external interrupts.
f010656f:	83 c8 01             	or     $0x1,%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0106572:	ee                   	out    %al,(%dx)
	}
}
f0106573:	83 c4 2c             	add    $0x2c,%esp
f0106576:	5b                   	pop    %ebx
f0106577:	5e                   	pop    %esi
f0106578:	5f                   	pop    %edi
f0106579:	5d                   	pop    %ebp
f010657a:	c3                   	ret    

f010657b <lapicw>:

volatile uint32_t *lapic;  // Initialized in mp.c

static void
lapicw(int index, int value)
{
f010657b:	55                   	push   %ebp
f010657c:	89 e5                	mov    %esp,%ebp
	lapic[index] = value;
f010657e:	8b 0d 00 90 20 f0    	mov    0xf0209000,%ecx
f0106584:	8d 04 81             	lea    (%ecx,%eax,4),%eax
f0106587:	89 10                	mov    %edx,(%eax)
	lapic[ID];  // wait for write to finish, by reading
f0106589:	a1 00 90 20 f0       	mov    0xf0209000,%eax
f010658e:	8b 40 20             	mov    0x20(%eax),%eax
}
f0106591:	5d                   	pop    %ebp
f0106592:	c3                   	ret    

f0106593 <cpunum>:
	lapicw(TPR, 0);
}

int
cpunum(void)
{
f0106593:	55                   	push   %ebp
f0106594:	89 e5                	mov    %esp,%ebp
	if (lapic)
f0106596:	a1 00 90 20 f0       	mov    0xf0209000,%eax
f010659b:	85 c0                	test   %eax,%eax
f010659d:	74 08                	je     f01065a7 <cpunum+0x14>
		return lapic[ID] >> 24;
f010659f:	8b 40 20             	mov    0x20(%eax),%eax
f01065a2:	c1 e8 18             	shr    $0x18,%eax
f01065a5:	eb 05                	jmp    f01065ac <cpunum+0x19>
	return 0;
f01065a7:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01065ac:	5d                   	pop    %ebp
f01065ad:	c3                   	ret    

f01065ae <lapic_init>:
}

void
lapic_init(void)
{
	if (!lapic) 
f01065ae:	83 3d 00 90 20 f0 00 	cmpl   $0x0,0xf0209000
f01065b5:	0f 84 0b 01 00 00    	je     f01066c6 <lapic_init+0x118>
	lapic[ID];  // wait for write to finish, by reading
}

void
lapic_init(void)
{
f01065bb:	55                   	push   %ebp
f01065bc:	89 e5                	mov    %esp,%ebp
	if (!lapic) 
		return;

	// Enable local APIC; set spurious interrupt vector.
	lapicw(SVR, ENABLE | (IRQ_OFFSET + IRQ_SPURIOUS));
f01065be:	ba 27 01 00 00       	mov    $0x127,%edx
f01065c3:	b8 3c 00 00 00       	mov    $0x3c,%eax
f01065c8:	e8 ae ff ff ff       	call   f010657b <lapicw>

	// The timer repeatedly counts down at bus frequency
	// from lapic[TICR] and then issues an interrupt.  
	// If we cared more about precise timekeeping,
	// TICR would be calibrated using an external time source.
	lapicw(TDCR, X1);
f01065cd:	ba 0b 00 00 00       	mov    $0xb,%edx
f01065d2:	b8 f8 00 00 00       	mov    $0xf8,%eax
f01065d7:	e8 9f ff ff ff       	call   f010657b <lapicw>
	lapicw(TIMER, PERIODIC | (IRQ_OFFSET + IRQ_TIMER));
f01065dc:	ba 20 00 02 00       	mov    $0x20020,%edx
f01065e1:	b8 c8 00 00 00       	mov    $0xc8,%eax
f01065e6:	e8 90 ff ff ff       	call   f010657b <lapicw>
	lapicw(TICR, 10000000); 
f01065eb:	ba 80 96 98 00       	mov    $0x989680,%edx
f01065f0:	b8 e0 00 00 00       	mov    $0xe0,%eax
f01065f5:	e8 81 ff ff ff       	call   f010657b <lapicw>
	//
	// According to Intel MP Specification, the BIOS should initialize
	// BSP's local APIC in Virtual Wire Mode, in which 8259A's
	// INTR is virtually connected to BSP's LINTIN0. In this mode,
	// we do not need to program the IOAPIC.
	if (thiscpu != bootcpu)
f01065fa:	e8 94 ff ff ff       	call   f0106593 <cpunum>
f01065ff:	6b c0 74             	imul   $0x74,%eax,%eax
f0106602:	05 20 80 1c f0       	add    $0xf01c8020,%eax
f0106607:	39 05 c0 83 1c f0    	cmp    %eax,0xf01c83c0
f010660d:	74 0f                	je     f010661e <lapic_init+0x70>
		lapicw(LINT0, MASKED);
f010660f:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106614:	b8 d4 00 00 00       	mov    $0xd4,%eax
f0106619:	e8 5d ff ff ff       	call   f010657b <lapicw>

	// Disable NMI (LINT1) on all CPUs
	lapicw(LINT1, MASKED);
f010661e:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106623:	b8 d8 00 00 00       	mov    $0xd8,%eax
f0106628:	e8 4e ff ff ff       	call   f010657b <lapicw>

	// Disable performance counter overflow interrupts
	// on machines that provide that interrupt entry.
	if (((lapic[VER]>>16) & 0xFF) >= 4)
f010662d:	a1 00 90 20 f0       	mov    0xf0209000,%eax
f0106632:	8b 40 30             	mov    0x30(%eax),%eax
f0106635:	c1 e8 10             	shr    $0x10,%eax
f0106638:	3c 03                	cmp    $0x3,%al
f010663a:	76 0f                	jbe    f010664b <lapic_init+0x9d>
		lapicw(PCINT, MASKED);
f010663c:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106641:	b8 d0 00 00 00       	mov    $0xd0,%eax
f0106646:	e8 30 ff ff ff       	call   f010657b <lapicw>

	// Map error interrupt to IRQ_ERROR.
	lapicw(ERROR, IRQ_OFFSET + IRQ_ERROR);
f010664b:	ba 33 00 00 00       	mov    $0x33,%edx
f0106650:	b8 dc 00 00 00       	mov    $0xdc,%eax
f0106655:	e8 21 ff ff ff       	call   f010657b <lapicw>

	// Clear error status register (requires back-to-back writes).
	lapicw(ESR, 0);
f010665a:	ba 00 00 00 00       	mov    $0x0,%edx
f010665f:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0106664:	e8 12 ff ff ff       	call   f010657b <lapicw>
	lapicw(ESR, 0);
f0106669:	ba 00 00 00 00       	mov    $0x0,%edx
f010666e:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0106673:	e8 03 ff ff ff       	call   f010657b <lapicw>

	// Ack any outstanding interrupts.
	lapicw(EOI, 0);
f0106678:	ba 00 00 00 00       	mov    $0x0,%edx
f010667d:	b8 2c 00 00 00       	mov    $0x2c,%eax
f0106682:	e8 f4 fe ff ff       	call   f010657b <lapicw>

	// Send an Init Level De-Assert to synchronize arbitration ID's.
	lapicw(ICRHI, 0);
f0106687:	ba 00 00 00 00       	mov    $0x0,%edx
f010668c:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106691:	e8 e5 fe ff ff       	call   f010657b <lapicw>
	lapicw(ICRLO, BCAST | INIT | LEVEL);
f0106696:	ba 00 85 08 00       	mov    $0x88500,%edx
f010669b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01066a0:	e8 d6 fe ff ff       	call   f010657b <lapicw>
	while(lapic[ICRLO] & DELIVS)
f01066a5:	8b 15 00 90 20 f0    	mov    0xf0209000,%edx
f01066ab:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f01066b1:	f6 c4 10             	test   $0x10,%ah
f01066b4:	75 f5                	jne    f01066ab <lapic_init+0xfd>
		;

	// Enable interrupts on the APIC (but not on the processor).
	lapicw(TPR, 0);
f01066b6:	ba 00 00 00 00       	mov    $0x0,%edx
f01066bb:	b8 20 00 00 00       	mov    $0x20,%eax
f01066c0:	e8 b6 fe ff ff       	call   f010657b <lapicw>
}
f01066c5:	5d                   	pop    %ebp
f01066c6:	f3 c3                	repz ret 

f01066c8 <lapic_eoi>:

// Acknowledge interrupt.
void
lapic_eoi(void)
{
	if (lapic)
f01066c8:	83 3d 00 90 20 f0 00 	cmpl   $0x0,0xf0209000
f01066cf:	74 13                	je     f01066e4 <lapic_eoi+0x1c>
}

// Acknowledge interrupt.
void
lapic_eoi(void)
{
f01066d1:	55                   	push   %ebp
f01066d2:	89 e5                	mov    %esp,%ebp
	if (lapic)
		lapicw(EOI, 0);
f01066d4:	ba 00 00 00 00       	mov    $0x0,%edx
f01066d9:	b8 2c 00 00 00       	mov    $0x2c,%eax
f01066de:	e8 98 fe ff ff       	call   f010657b <lapicw>
}
f01066e3:	5d                   	pop    %ebp
f01066e4:	f3 c3                	repz ret 

f01066e6 <lapic_startap>:

// Start additional processor running entry code at addr.
// See Appendix B of MultiProcessor Specification.
void
lapic_startap(uint8_t apicid, uint32_t addr)
{
f01066e6:	55                   	push   %ebp
f01066e7:	89 e5                	mov    %esp,%ebp
f01066e9:	56                   	push   %esi
f01066ea:	53                   	push   %ebx
f01066eb:	83 ec 10             	sub    $0x10,%esp
f01066ee:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01066f1:	8b 75 0c             	mov    0xc(%ebp),%esi
f01066f4:	ba 70 00 00 00       	mov    $0x70,%edx
f01066f9:	b8 0f 00 00 00       	mov    $0xf,%eax
f01066fe:	ee                   	out    %al,(%dx)
f01066ff:	b2 71                	mov    $0x71,%dl
f0106701:	b8 0a 00 00 00       	mov    $0xa,%eax
f0106706:	ee                   	out    %al,(%dx)
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0106707:	83 3d 88 7e 1c f0 00 	cmpl   $0x0,0xf01c7e88
f010670e:	75 24                	jne    f0106734 <lapic_startap+0x4e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106710:	c7 44 24 0c 67 04 00 	movl   $0x467,0xc(%esp)
f0106717:	00 
f0106718:	c7 44 24 08 c4 6c 10 	movl   $0xf0106cc4,0x8(%esp)
f010671f:	f0 
f0106720:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
f0106727:	00 
f0106728:	c7 04 24 d4 86 10 f0 	movl   $0xf01086d4,(%esp)
f010672f:	e8 0c 99 ff ff       	call   f0100040 <_panic>
	// and the warm reset vector (DWORD based at 40:67) to point at
	// the AP startup code prior to the [universal startup algorithm]."
	outb(IO_RTC, 0xF);  // offset 0xF is shutdown code
	outb(IO_RTC+1, 0x0A);
	wrv = (uint16_t *)KADDR((0x40 << 4 | 0x67));  // Warm reset vector
	wrv[0] = 0;
f0106734:	66 c7 05 67 04 00 f0 	movw   $0x0,0xf0000467
f010673b:	00 00 
	wrv[1] = addr >> 4;
f010673d:	89 f0                	mov    %esi,%eax
f010673f:	c1 e8 04             	shr    $0x4,%eax
f0106742:	66 a3 69 04 00 f0    	mov    %ax,0xf0000469

	// "Universal startup algorithm."
	// Send INIT (level-triggered) interrupt to reset other CPU.
	lapicw(ICRHI, apicid << 24);
f0106748:	c1 e3 18             	shl    $0x18,%ebx
f010674b:	89 da                	mov    %ebx,%edx
f010674d:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106752:	e8 24 fe ff ff       	call   f010657b <lapicw>
	lapicw(ICRLO, INIT | LEVEL | ASSERT);
f0106757:	ba 00 c5 00 00       	mov    $0xc500,%edx
f010675c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106761:	e8 15 fe ff ff       	call   f010657b <lapicw>
	microdelay(200);
	lapicw(ICRLO, INIT | LEVEL);
f0106766:	ba 00 85 00 00       	mov    $0x8500,%edx
f010676b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106770:	e8 06 fe ff ff       	call   f010657b <lapicw>
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0106775:	c1 ee 0c             	shr    $0xc,%esi
f0106778:	81 ce 00 06 00 00    	or     $0x600,%esi
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f010677e:	89 da                	mov    %ebx,%edx
f0106780:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106785:	e8 f1 fd ff ff       	call   f010657b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f010678a:	89 f2                	mov    %esi,%edx
f010678c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106791:	e8 e5 fd ff ff       	call   f010657b <lapicw>
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f0106796:	89 da                	mov    %ebx,%edx
f0106798:	b8 c4 00 00 00       	mov    $0xc4,%eax
f010679d:	e8 d9 fd ff ff       	call   f010657b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f01067a2:	89 f2                	mov    %esi,%edx
f01067a4:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01067a9:	e8 cd fd ff ff       	call   f010657b <lapicw>
		microdelay(200);
	}
}
f01067ae:	83 c4 10             	add    $0x10,%esp
f01067b1:	5b                   	pop    %ebx
f01067b2:	5e                   	pop    %esi
f01067b3:	5d                   	pop    %ebp
f01067b4:	c3                   	ret    

f01067b5 <lapic_ipi>:

void
lapic_ipi(int vector)
{
f01067b5:	55                   	push   %ebp
f01067b6:	89 e5                	mov    %esp,%ebp
	lapicw(ICRLO, OTHERS | FIXED | vector);
f01067b8:	8b 55 08             	mov    0x8(%ebp),%edx
f01067bb:	81 ca 00 00 0c 00    	or     $0xc0000,%edx
f01067c1:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01067c6:	e8 b0 fd ff ff       	call   f010657b <lapicw>
	while (lapic[ICRLO] & DELIVS)
f01067cb:	8b 15 00 90 20 f0    	mov    0xf0209000,%edx
f01067d1:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f01067d7:	f6 c4 10             	test   $0x10,%ah
f01067da:	75 f5                	jne    f01067d1 <lapic_ipi+0x1c>
		;
}
f01067dc:	5d                   	pop    %ebp
f01067dd:	c3                   	ret    

f01067de <__spin_initlock>:
}
#endif

void
__spin_initlock(struct spinlock *lk, char *name)
{
f01067de:	55                   	push   %ebp
f01067df:	89 e5                	mov    %esp,%ebp
f01067e1:	8b 45 08             	mov    0x8(%ebp),%eax
	lk->locked = 0;
f01067e4:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
#ifdef DEBUG_SPINLOCK
	lk->name = name;
f01067ea:	8b 55 0c             	mov    0xc(%ebp),%edx
f01067ed:	89 50 04             	mov    %edx,0x4(%eax)
	lk->cpu = 0;
f01067f0:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
#endif
}
f01067f7:	5d                   	pop    %ebp
f01067f8:	c3                   	ret    

f01067f9 <spin_lock>:
// Loops (spins) until the lock is acquired.
// Holding a lock for a long time may cause
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
f01067f9:	55                   	push   %ebp
f01067fa:	89 e5                	mov    %esp,%ebp
f01067fc:	56                   	push   %esi
f01067fd:	53                   	push   %ebx
f01067fe:	83 ec 20             	sub    $0x20,%esp
f0106801:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0106804:	83 3b 00             	cmpl   $0x0,(%ebx)
f0106807:	74 14                	je     f010681d <spin_lock+0x24>
f0106809:	8b 73 08             	mov    0x8(%ebx),%esi
f010680c:	e8 82 fd ff ff       	call   f0106593 <cpunum>
f0106811:	6b c0 74             	imul   $0x74,%eax,%eax
f0106814:	05 20 80 1c f0       	add    $0xf01c8020,%eax
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
f0106819:	39 c6                	cmp    %eax,%esi
f010681b:	74 15                	je     f0106832 <spin_lock+0x39>
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f010681d:	89 da                	mov    %ebx,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f010681f:	b8 01 00 00 00       	mov    $0x1,%eax
f0106824:	f0 87 03             	lock xchg %eax,(%ebx)
f0106827:	b9 01 00 00 00       	mov    $0x1,%ecx
f010682c:	85 c0                	test   %eax,%eax
f010682e:	75 2e                	jne    f010685e <spin_lock+0x65>
f0106830:	eb 37                	jmp    f0106869 <spin_lock+0x70>
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
		panic("CPU %d cannot acquire %s: already holding", cpunum(), lk->name);
f0106832:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106835:	e8 59 fd ff ff       	call   f0106593 <cpunum>
f010683a:	89 5c 24 10          	mov    %ebx,0x10(%esp)
f010683e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0106842:	c7 44 24 08 e4 86 10 	movl   $0xf01086e4,0x8(%esp)
f0106849:	f0 
f010684a:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
f0106851:	00 
f0106852:	c7 04 24 48 87 10 f0 	movl   $0xf0108748,(%esp)
f0106859:	e8 e2 97 ff ff       	call   f0100040 <_panic>

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
		asm volatile ("pause");
f010685e:	f3 90                	pause  
f0106860:	89 c8                	mov    %ecx,%eax
f0106862:	f0 87 02             	lock xchg %eax,(%edx)
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f0106865:	85 c0                	test   %eax,%eax
f0106867:	75 f5                	jne    f010685e <spin_lock+0x65>
		asm volatile ("pause");

	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
f0106869:	e8 25 fd ff ff       	call   f0106593 <cpunum>
f010686e:	6b c0 74             	imul   $0x74,%eax,%eax
f0106871:	05 20 80 1c f0       	add    $0xf01c8020,%eax
f0106876:	89 43 08             	mov    %eax,0x8(%ebx)
	get_caller_pcs(lk->pcs);
f0106879:	8d 4b 0c             	lea    0xc(%ebx),%ecx

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f010687c:	89 e8                	mov    %ebp,%eax
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
f010687e:	8d 90 00 00 80 10    	lea    0x10800000(%eax),%edx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0106884:	81 fa ff ff 7f 0e    	cmp    $0xe7fffff,%edx
f010688a:	76 3a                	jbe    f01068c6 <spin_lock+0xcd>
f010688c:	eb 31                	jmp    f01068bf <spin_lock+0xc6>
		    || ebp >= (uint32_t *)IOMEMBASE)
f010688e:	8d 9a 00 00 80 10    	lea    0x10800000(%edx),%ebx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0106894:	81 fb ff ff 7f 0e    	cmp    $0xe7fffff,%ebx
f010689a:	77 12                	ja     f01068ae <spin_lock+0xb5>
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f010689c:	8b 5a 04             	mov    0x4(%edx),%ebx
f010689f:	89 1c 81             	mov    %ebx,(%ecx,%eax,4)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f01068a2:	8b 12                	mov    (%edx),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01068a4:	83 c0 01             	add    $0x1,%eax
f01068a7:	83 f8 0a             	cmp    $0xa,%eax
f01068aa:	75 e2                	jne    f010688e <spin_lock+0x95>
f01068ac:	eb 27                	jmp    f01068d5 <spin_lock+0xdc>
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
		pcs[i] = 0;
f01068ae:	c7 04 81 00 00 00 00 	movl   $0x0,(%ecx,%eax,4)
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
f01068b5:	83 c0 01             	add    $0x1,%eax
f01068b8:	83 f8 09             	cmp    $0x9,%eax
f01068bb:	7e f1                	jle    f01068ae <spin_lock+0xb5>
f01068bd:	eb 16                	jmp    f01068d5 <spin_lock+0xdc>
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01068bf:	b8 00 00 00 00       	mov    $0x0,%eax
f01068c4:	eb e8                	jmp    f01068ae <spin_lock+0xb5>
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f01068c6:	8b 50 04             	mov    0x4(%eax),%edx
f01068c9:	89 53 0c             	mov    %edx,0xc(%ebx)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f01068cc:	8b 10                	mov    (%eax),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01068ce:	b8 01 00 00 00       	mov    $0x1,%eax
f01068d3:	eb b9                	jmp    f010688e <spin_lock+0x95>
	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
	get_caller_pcs(lk->pcs);
#endif
}
f01068d5:	83 c4 20             	add    $0x20,%esp
f01068d8:	5b                   	pop    %ebx
f01068d9:	5e                   	pop    %esi
f01068da:	5d                   	pop    %ebp
f01068db:	c3                   	ret    

f01068dc <spin_unlock>:

// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
f01068dc:	55                   	push   %ebp
f01068dd:	89 e5                	mov    %esp,%ebp
f01068df:	57                   	push   %edi
f01068e0:	56                   	push   %esi
f01068e1:	53                   	push   %ebx
f01068e2:	83 ec 6c             	sub    $0x6c,%esp
f01068e5:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f01068e8:	83 3b 00             	cmpl   $0x0,(%ebx)
f01068eb:	74 18                	je     f0106905 <spin_unlock+0x29>
f01068ed:	8b 73 08             	mov    0x8(%ebx),%esi
f01068f0:	e8 9e fc ff ff       	call   f0106593 <cpunum>
f01068f5:	6b c0 74             	imul   $0x74,%eax,%eax
f01068f8:	05 20 80 1c f0       	add    $0xf01c8020,%eax
// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (!holding(lk)) {
f01068fd:	39 c6                	cmp    %eax,%esi
f01068ff:	0f 84 d4 00 00 00    	je     f01069d9 <spin_unlock+0xfd>
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
f0106905:	c7 44 24 08 28 00 00 	movl   $0x28,0x8(%esp)
f010690c:	00 
f010690d:	8d 43 0c             	lea    0xc(%ebx),%eax
f0106910:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106914:	8d 45 c0             	lea    -0x40(%ebp),%eax
f0106917:	89 04 24             	mov    %eax,(%esp)
f010691a:	e8 27 f6 ff ff       	call   f0105f46 <memmove>
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
f010691f:	8b 43 08             	mov    0x8(%ebx),%eax
	if (!holding(lk)) {
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
f0106922:	0f b6 30             	movzbl (%eax),%esi
f0106925:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106928:	e8 66 fc ff ff       	call   f0106593 <cpunum>
f010692d:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0106931:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0106935:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106939:	c7 04 24 10 87 10 f0 	movl   $0xf0108710,(%esp)
f0106940:	e8 41 d5 ff ff       	call   f0103e86 <cprintf>
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0106945:	8b 45 c0             	mov    -0x40(%ebp),%eax
f0106948:	85 c0                	test   %eax,%eax
f010694a:	74 71                	je     f01069bd <spin_unlock+0xe1>
f010694c:	8d 5d c0             	lea    -0x40(%ebp),%ebx
f010694f:	8d 7d e4             	lea    -0x1c(%ebp),%edi
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
f0106952:	8d 75 a8             	lea    -0x58(%ebp),%esi
f0106955:	89 74 24 04          	mov    %esi,0x4(%esp)
f0106959:	89 04 24             	mov    %eax,(%esp)
f010695c:	e8 0b ea ff ff       	call   f010536c <debuginfo_eip>
f0106961:	85 c0                	test   %eax,%eax
f0106963:	78 39                	js     f010699e <spin_unlock+0xc2>
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
f0106965:	8b 03                	mov    (%ebx),%eax
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
f0106967:	89 c2                	mov    %eax,%edx
f0106969:	2b 55 b8             	sub    -0x48(%ebp),%edx
f010696c:	89 54 24 18          	mov    %edx,0x18(%esp)
f0106970:	8b 55 b0             	mov    -0x50(%ebp),%edx
f0106973:	89 54 24 14          	mov    %edx,0x14(%esp)
f0106977:	8b 55 b4             	mov    -0x4c(%ebp),%edx
f010697a:	89 54 24 10          	mov    %edx,0x10(%esp)
f010697e:	8b 55 ac             	mov    -0x54(%ebp),%edx
f0106981:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0106985:	8b 55 a8             	mov    -0x58(%ebp),%edx
f0106988:	89 54 24 08          	mov    %edx,0x8(%esp)
f010698c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106990:	c7 04 24 58 87 10 f0 	movl   $0xf0108758,(%esp)
f0106997:	e8 ea d4 ff ff       	call   f0103e86 <cprintf>
f010699c:	eb 12                	jmp    f01069b0 <spin_unlock+0xd4>
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
f010699e:	8b 03                	mov    (%ebx),%eax
f01069a0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01069a4:	c7 04 24 6f 87 10 f0 	movl   $0xf010876f,(%esp)
f01069ab:	e8 d6 d4 ff ff       	call   f0103e86 <cprintf>
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f01069b0:	39 fb                	cmp    %edi,%ebx
f01069b2:	74 09                	je     f01069bd <spin_unlock+0xe1>
f01069b4:	83 c3 04             	add    $0x4,%ebx
f01069b7:	8b 03                	mov    (%ebx),%eax
f01069b9:	85 c0                	test   %eax,%eax
f01069bb:	75 98                	jne    f0106955 <spin_unlock+0x79>
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
		}
		panic("spin_unlock");
f01069bd:	c7 44 24 08 77 87 10 	movl   $0xf0108777,0x8(%esp)
f01069c4:	f0 
f01069c5:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
f01069cc:	00 
f01069cd:	c7 04 24 48 87 10 f0 	movl   $0xf0108748,(%esp)
f01069d4:	e8 67 96 ff ff       	call   f0100040 <_panic>
	}
	
	lk->pcs[0] = 0;
f01069d9:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
	lk->cpu = 0;
f01069e0:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f01069e7:	b8 00 00 00 00       	mov    $0x0,%eax
f01069ec:	f0 87 03             	lock xchg %eax,(%ebx)
	// after a store. So lock->locked = 0 would work here.
	// The xchg being asm volatile ensures gcc emits it after
	// the above assignments (and after the critical section).
	xchg(&lk->locked, 0);

}
f01069ef:	83 c4 6c             	add    $0x6c,%esp
f01069f2:	5b                   	pop    %ebx
f01069f3:	5e                   	pop    %esi
f01069f4:	5f                   	pop    %edi
f01069f5:	5d                   	pop    %ebp
f01069f6:	c3                   	ret    
f01069f7:	66 90                	xchg   %ax,%ax
f01069f9:	66 90                	xchg   %ax,%ax
f01069fb:	66 90                	xchg   %ax,%ax
f01069fd:	66 90                	xchg   %ax,%ax
f01069ff:	90                   	nop

f0106a00 <__udivdi3>:
f0106a00:	55                   	push   %ebp
f0106a01:	57                   	push   %edi
f0106a02:	56                   	push   %esi
f0106a03:	83 ec 0c             	sub    $0xc,%esp
f0106a06:	8b 44 24 28          	mov    0x28(%esp),%eax
f0106a0a:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f0106a0e:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f0106a12:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0106a16:	85 c0                	test   %eax,%eax
f0106a18:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0106a1c:	89 ea                	mov    %ebp,%edx
f0106a1e:	89 0c 24             	mov    %ecx,(%esp)
f0106a21:	75 2d                	jne    f0106a50 <__udivdi3+0x50>
f0106a23:	39 e9                	cmp    %ebp,%ecx
f0106a25:	77 61                	ja     f0106a88 <__udivdi3+0x88>
f0106a27:	85 c9                	test   %ecx,%ecx
f0106a29:	89 ce                	mov    %ecx,%esi
f0106a2b:	75 0b                	jne    f0106a38 <__udivdi3+0x38>
f0106a2d:	b8 01 00 00 00       	mov    $0x1,%eax
f0106a32:	31 d2                	xor    %edx,%edx
f0106a34:	f7 f1                	div    %ecx
f0106a36:	89 c6                	mov    %eax,%esi
f0106a38:	31 d2                	xor    %edx,%edx
f0106a3a:	89 e8                	mov    %ebp,%eax
f0106a3c:	f7 f6                	div    %esi
f0106a3e:	89 c5                	mov    %eax,%ebp
f0106a40:	89 f8                	mov    %edi,%eax
f0106a42:	f7 f6                	div    %esi
f0106a44:	89 ea                	mov    %ebp,%edx
f0106a46:	83 c4 0c             	add    $0xc,%esp
f0106a49:	5e                   	pop    %esi
f0106a4a:	5f                   	pop    %edi
f0106a4b:	5d                   	pop    %ebp
f0106a4c:	c3                   	ret    
f0106a4d:	8d 76 00             	lea    0x0(%esi),%esi
f0106a50:	39 e8                	cmp    %ebp,%eax
f0106a52:	77 24                	ja     f0106a78 <__udivdi3+0x78>
f0106a54:	0f bd e8             	bsr    %eax,%ebp
f0106a57:	83 f5 1f             	xor    $0x1f,%ebp
f0106a5a:	75 3c                	jne    f0106a98 <__udivdi3+0x98>
f0106a5c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0106a60:	39 34 24             	cmp    %esi,(%esp)
f0106a63:	0f 86 9f 00 00 00    	jbe    f0106b08 <__udivdi3+0x108>
f0106a69:	39 d0                	cmp    %edx,%eax
f0106a6b:	0f 82 97 00 00 00    	jb     f0106b08 <__udivdi3+0x108>
f0106a71:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0106a78:	31 d2                	xor    %edx,%edx
f0106a7a:	31 c0                	xor    %eax,%eax
f0106a7c:	83 c4 0c             	add    $0xc,%esp
f0106a7f:	5e                   	pop    %esi
f0106a80:	5f                   	pop    %edi
f0106a81:	5d                   	pop    %ebp
f0106a82:	c3                   	ret    
f0106a83:	90                   	nop
f0106a84:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106a88:	89 f8                	mov    %edi,%eax
f0106a8a:	f7 f1                	div    %ecx
f0106a8c:	31 d2                	xor    %edx,%edx
f0106a8e:	83 c4 0c             	add    $0xc,%esp
f0106a91:	5e                   	pop    %esi
f0106a92:	5f                   	pop    %edi
f0106a93:	5d                   	pop    %ebp
f0106a94:	c3                   	ret    
f0106a95:	8d 76 00             	lea    0x0(%esi),%esi
f0106a98:	89 e9                	mov    %ebp,%ecx
f0106a9a:	8b 3c 24             	mov    (%esp),%edi
f0106a9d:	d3 e0                	shl    %cl,%eax
f0106a9f:	89 c6                	mov    %eax,%esi
f0106aa1:	b8 20 00 00 00       	mov    $0x20,%eax
f0106aa6:	29 e8                	sub    %ebp,%eax
f0106aa8:	89 c1                	mov    %eax,%ecx
f0106aaa:	d3 ef                	shr    %cl,%edi
f0106aac:	89 e9                	mov    %ebp,%ecx
f0106aae:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0106ab2:	8b 3c 24             	mov    (%esp),%edi
f0106ab5:	09 74 24 08          	or     %esi,0x8(%esp)
f0106ab9:	89 d6                	mov    %edx,%esi
f0106abb:	d3 e7                	shl    %cl,%edi
f0106abd:	89 c1                	mov    %eax,%ecx
f0106abf:	89 3c 24             	mov    %edi,(%esp)
f0106ac2:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106ac6:	d3 ee                	shr    %cl,%esi
f0106ac8:	89 e9                	mov    %ebp,%ecx
f0106aca:	d3 e2                	shl    %cl,%edx
f0106acc:	89 c1                	mov    %eax,%ecx
f0106ace:	d3 ef                	shr    %cl,%edi
f0106ad0:	09 d7                	or     %edx,%edi
f0106ad2:	89 f2                	mov    %esi,%edx
f0106ad4:	89 f8                	mov    %edi,%eax
f0106ad6:	f7 74 24 08          	divl   0x8(%esp)
f0106ada:	89 d6                	mov    %edx,%esi
f0106adc:	89 c7                	mov    %eax,%edi
f0106ade:	f7 24 24             	mull   (%esp)
f0106ae1:	39 d6                	cmp    %edx,%esi
f0106ae3:	89 14 24             	mov    %edx,(%esp)
f0106ae6:	72 30                	jb     f0106b18 <__udivdi3+0x118>
f0106ae8:	8b 54 24 04          	mov    0x4(%esp),%edx
f0106aec:	89 e9                	mov    %ebp,%ecx
f0106aee:	d3 e2                	shl    %cl,%edx
f0106af0:	39 c2                	cmp    %eax,%edx
f0106af2:	73 05                	jae    f0106af9 <__udivdi3+0xf9>
f0106af4:	3b 34 24             	cmp    (%esp),%esi
f0106af7:	74 1f                	je     f0106b18 <__udivdi3+0x118>
f0106af9:	89 f8                	mov    %edi,%eax
f0106afb:	31 d2                	xor    %edx,%edx
f0106afd:	e9 7a ff ff ff       	jmp    f0106a7c <__udivdi3+0x7c>
f0106b02:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0106b08:	31 d2                	xor    %edx,%edx
f0106b0a:	b8 01 00 00 00       	mov    $0x1,%eax
f0106b0f:	e9 68 ff ff ff       	jmp    f0106a7c <__udivdi3+0x7c>
f0106b14:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106b18:	8d 47 ff             	lea    -0x1(%edi),%eax
f0106b1b:	31 d2                	xor    %edx,%edx
f0106b1d:	83 c4 0c             	add    $0xc,%esp
f0106b20:	5e                   	pop    %esi
f0106b21:	5f                   	pop    %edi
f0106b22:	5d                   	pop    %ebp
f0106b23:	c3                   	ret    
f0106b24:	66 90                	xchg   %ax,%ax
f0106b26:	66 90                	xchg   %ax,%ax
f0106b28:	66 90                	xchg   %ax,%ax
f0106b2a:	66 90                	xchg   %ax,%ax
f0106b2c:	66 90                	xchg   %ax,%ax
f0106b2e:	66 90                	xchg   %ax,%ax

f0106b30 <__umoddi3>:
f0106b30:	55                   	push   %ebp
f0106b31:	57                   	push   %edi
f0106b32:	56                   	push   %esi
f0106b33:	83 ec 14             	sub    $0x14,%esp
f0106b36:	8b 44 24 28          	mov    0x28(%esp),%eax
f0106b3a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0106b3e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0106b42:	89 c7                	mov    %eax,%edi
f0106b44:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106b48:	8b 44 24 30          	mov    0x30(%esp),%eax
f0106b4c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0106b50:	89 34 24             	mov    %esi,(%esp)
f0106b53:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0106b57:	85 c0                	test   %eax,%eax
f0106b59:	89 c2                	mov    %eax,%edx
f0106b5b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106b5f:	75 17                	jne    f0106b78 <__umoddi3+0x48>
f0106b61:	39 fe                	cmp    %edi,%esi
f0106b63:	76 4b                	jbe    f0106bb0 <__umoddi3+0x80>
f0106b65:	89 c8                	mov    %ecx,%eax
f0106b67:	89 fa                	mov    %edi,%edx
f0106b69:	f7 f6                	div    %esi
f0106b6b:	89 d0                	mov    %edx,%eax
f0106b6d:	31 d2                	xor    %edx,%edx
f0106b6f:	83 c4 14             	add    $0x14,%esp
f0106b72:	5e                   	pop    %esi
f0106b73:	5f                   	pop    %edi
f0106b74:	5d                   	pop    %ebp
f0106b75:	c3                   	ret    
f0106b76:	66 90                	xchg   %ax,%ax
f0106b78:	39 f8                	cmp    %edi,%eax
f0106b7a:	77 54                	ja     f0106bd0 <__umoddi3+0xa0>
f0106b7c:	0f bd e8             	bsr    %eax,%ebp
f0106b7f:	83 f5 1f             	xor    $0x1f,%ebp
f0106b82:	75 5c                	jne    f0106be0 <__umoddi3+0xb0>
f0106b84:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0106b88:	39 3c 24             	cmp    %edi,(%esp)
f0106b8b:	0f 87 e7 00 00 00    	ja     f0106c78 <__umoddi3+0x148>
f0106b91:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106b95:	29 f1                	sub    %esi,%ecx
f0106b97:	19 c7                	sbb    %eax,%edi
f0106b99:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0106b9d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106ba1:	8b 44 24 08          	mov    0x8(%esp),%eax
f0106ba5:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0106ba9:	83 c4 14             	add    $0x14,%esp
f0106bac:	5e                   	pop    %esi
f0106bad:	5f                   	pop    %edi
f0106bae:	5d                   	pop    %ebp
f0106baf:	c3                   	ret    
f0106bb0:	85 f6                	test   %esi,%esi
f0106bb2:	89 f5                	mov    %esi,%ebp
f0106bb4:	75 0b                	jne    f0106bc1 <__umoddi3+0x91>
f0106bb6:	b8 01 00 00 00       	mov    $0x1,%eax
f0106bbb:	31 d2                	xor    %edx,%edx
f0106bbd:	f7 f6                	div    %esi
f0106bbf:	89 c5                	mov    %eax,%ebp
f0106bc1:	8b 44 24 04          	mov    0x4(%esp),%eax
f0106bc5:	31 d2                	xor    %edx,%edx
f0106bc7:	f7 f5                	div    %ebp
f0106bc9:	89 c8                	mov    %ecx,%eax
f0106bcb:	f7 f5                	div    %ebp
f0106bcd:	eb 9c                	jmp    f0106b6b <__umoddi3+0x3b>
f0106bcf:	90                   	nop
f0106bd0:	89 c8                	mov    %ecx,%eax
f0106bd2:	89 fa                	mov    %edi,%edx
f0106bd4:	83 c4 14             	add    $0x14,%esp
f0106bd7:	5e                   	pop    %esi
f0106bd8:	5f                   	pop    %edi
f0106bd9:	5d                   	pop    %ebp
f0106bda:	c3                   	ret    
f0106bdb:	90                   	nop
f0106bdc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106be0:	8b 04 24             	mov    (%esp),%eax
f0106be3:	be 20 00 00 00       	mov    $0x20,%esi
f0106be8:	89 e9                	mov    %ebp,%ecx
f0106bea:	29 ee                	sub    %ebp,%esi
f0106bec:	d3 e2                	shl    %cl,%edx
f0106bee:	89 f1                	mov    %esi,%ecx
f0106bf0:	d3 e8                	shr    %cl,%eax
f0106bf2:	89 e9                	mov    %ebp,%ecx
f0106bf4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106bf8:	8b 04 24             	mov    (%esp),%eax
f0106bfb:	09 54 24 04          	or     %edx,0x4(%esp)
f0106bff:	89 fa                	mov    %edi,%edx
f0106c01:	d3 e0                	shl    %cl,%eax
f0106c03:	89 f1                	mov    %esi,%ecx
f0106c05:	89 44 24 08          	mov    %eax,0x8(%esp)
f0106c09:	8b 44 24 10          	mov    0x10(%esp),%eax
f0106c0d:	d3 ea                	shr    %cl,%edx
f0106c0f:	89 e9                	mov    %ebp,%ecx
f0106c11:	d3 e7                	shl    %cl,%edi
f0106c13:	89 f1                	mov    %esi,%ecx
f0106c15:	d3 e8                	shr    %cl,%eax
f0106c17:	89 e9                	mov    %ebp,%ecx
f0106c19:	09 f8                	or     %edi,%eax
f0106c1b:	8b 7c 24 10          	mov    0x10(%esp),%edi
f0106c1f:	f7 74 24 04          	divl   0x4(%esp)
f0106c23:	d3 e7                	shl    %cl,%edi
f0106c25:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106c29:	89 d7                	mov    %edx,%edi
f0106c2b:	f7 64 24 08          	mull   0x8(%esp)
f0106c2f:	39 d7                	cmp    %edx,%edi
f0106c31:	89 c1                	mov    %eax,%ecx
f0106c33:	89 14 24             	mov    %edx,(%esp)
f0106c36:	72 2c                	jb     f0106c64 <__umoddi3+0x134>
f0106c38:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f0106c3c:	72 22                	jb     f0106c60 <__umoddi3+0x130>
f0106c3e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0106c42:	29 c8                	sub    %ecx,%eax
f0106c44:	19 d7                	sbb    %edx,%edi
f0106c46:	89 e9                	mov    %ebp,%ecx
f0106c48:	89 fa                	mov    %edi,%edx
f0106c4a:	d3 e8                	shr    %cl,%eax
f0106c4c:	89 f1                	mov    %esi,%ecx
f0106c4e:	d3 e2                	shl    %cl,%edx
f0106c50:	89 e9                	mov    %ebp,%ecx
f0106c52:	d3 ef                	shr    %cl,%edi
f0106c54:	09 d0                	or     %edx,%eax
f0106c56:	89 fa                	mov    %edi,%edx
f0106c58:	83 c4 14             	add    $0x14,%esp
f0106c5b:	5e                   	pop    %esi
f0106c5c:	5f                   	pop    %edi
f0106c5d:	5d                   	pop    %ebp
f0106c5e:	c3                   	ret    
f0106c5f:	90                   	nop
f0106c60:	39 d7                	cmp    %edx,%edi
f0106c62:	75 da                	jne    f0106c3e <__umoddi3+0x10e>
f0106c64:	8b 14 24             	mov    (%esp),%edx
f0106c67:	89 c1                	mov    %eax,%ecx
f0106c69:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f0106c6d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0106c71:	eb cb                	jmp    f0106c3e <__umoddi3+0x10e>
f0106c73:	90                   	nop
f0106c74:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106c78:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f0106c7c:	0f 82 0f ff ff ff    	jb     f0106b91 <__umoddi3+0x61>
f0106c82:	e9 1a ff ff ff       	jmp    f0106ba1 <__umoddi3+0x71>
