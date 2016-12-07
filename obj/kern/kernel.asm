
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
f0100015:	b8 00 80 11 00       	mov    $0x118000,%eax
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
f0100034:	bc 00 80 11 f0       	mov    $0xf0118000,%esp

	# now to C code
	call	i386_init
f0100039:	e8 02 00 00 00       	call   f0100040 <i386_init>

f010003e <spin>:

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <i386_init>:
#include <kern/trap.h>


void
i386_init(void)
{
f0100040:	55                   	push   %ebp
f0100041:	89 e5                	mov    %esp,%ebp
f0100043:	83 ec 18             	sub    $0x18,%esp
	extern char edata[], end[];

	// Before doing anything else, complete the ELF loading process.
	// Clear the uninitialized global data (BSS) section of our program.
	// This ensures that all static/global variables start out zero.
	memset(edata, 0, end - edata);
f0100046:	b8 d0 cf 17 f0       	mov    $0xf017cfd0,%eax
f010004b:	2d a1 c0 17 f0       	sub    $0xf017c0a1,%eax
f0100050:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100054:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010005b:	00 
f010005c:	c7 04 24 a1 c0 17 f0 	movl   $0xf017c0a1,(%esp)
f0100063:	e8 f1 43 00 00       	call   f0104459 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f0100068:	e8 d2 04 00 00       	call   f010053f <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f010006d:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f0100074:	00 
f0100075:	c7 04 24 20 49 10 f0 	movl   $0xf0104920,(%esp)
f010007c:	e8 b9 33 00 00       	call   f010343a <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f0100081:	e8 5a 11 00 00       	call   f01011e0 <mem_init>

	// Lab 3 user environment initialization functions
	env_init();
f0100086:	e8 a0 2f 00 00       	call   f010302b <env_init>
	trap_init();
f010008b:	90                   	nop
f010008c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100090:	e8 1c 34 00 00       	call   f01034b1 <trap_init>
#if defined(TEST)
	// Don't touch -- used by grading script!
	ENV_CREATE(TEST, ENV_TYPE_USER);
#else
	// Touch all you want.
	ENV_CREATE(user_hello, ENV_TYPE_USER);
f0100095:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f010009c:	00 
f010009d:	c7 44 24 04 5e 78 00 	movl   $0x785e,0x4(%esp)
f01000a4:	00 
f01000a5:	c7 04 24 56 a3 11 f0 	movl   $0xf011a356,(%esp)
f01000ac:	e8 b3 30 00 00       	call   f0103164 <env_create>
#endif // TEST*

	// We only have one user environment for now, so just run it.
	env_run(&envs[0]);
f01000b1:	a1 08 c3 17 f0       	mov    0xf017c308,%eax
f01000b6:	89 04 24             	mov    %eax,(%esp)
f01000b9:	e8 ea 32 00 00       	call   f01033a8 <env_run>

f01000be <_panic>:
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void
_panic(const char *file, int line, const char *fmt,...)
{
f01000be:	55                   	push   %ebp
f01000bf:	89 e5                	mov    %esp,%ebp
f01000c1:	56                   	push   %esi
f01000c2:	53                   	push   %ebx
f01000c3:	83 ec 10             	sub    $0x10,%esp
f01000c6:	8b 75 10             	mov    0x10(%ebp),%esi
	va_list ap;

	if (panicstr)
f01000c9:	83 3d c0 cf 17 f0 00 	cmpl   $0x0,0xf017cfc0
f01000d0:	75 3d                	jne    f010010f <_panic+0x51>
		goto dead;
	panicstr = fmt;
f01000d2:	89 35 c0 cf 17 f0    	mov    %esi,0xf017cfc0

	// Be extra sure that the machine is in as reasonable state
	__asm __volatile("cli; cld");
f01000d8:	fa                   	cli    
f01000d9:	fc                   	cld    

	va_start(ap, fmt);
f01000da:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic at %s:%d: ", file, line);
f01000dd:	8b 45 0c             	mov    0xc(%ebp),%eax
f01000e0:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000e4:	8b 45 08             	mov    0x8(%ebp),%eax
f01000e7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01000eb:	c7 04 24 3b 49 10 f0 	movl   $0xf010493b,(%esp)
f01000f2:	e8 43 33 00 00       	call   f010343a <cprintf>
	vcprintf(fmt, ap);
f01000f7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01000fb:	89 34 24             	mov    %esi,(%esp)
f01000fe:	e8 04 33 00 00       	call   f0103407 <vcprintf>
	cprintf("\n");
f0100103:	c7 04 24 79 58 10 f0 	movl   $0xf0105879,(%esp)
f010010a:	e8 2b 33 00 00       	call   f010343a <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f010010f:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0100116:	e8 17 07 00 00       	call   f0100832 <monitor>
f010011b:	eb f2                	jmp    f010010f <_panic+0x51>

f010011d <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f010011d:	55                   	push   %ebp
f010011e:	89 e5                	mov    %esp,%ebp
f0100120:	53                   	push   %ebx
f0100121:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f0100124:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f0100127:	8b 45 0c             	mov    0xc(%ebp),%eax
f010012a:	89 44 24 08          	mov    %eax,0x8(%esp)
f010012e:	8b 45 08             	mov    0x8(%ebp),%eax
f0100131:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100135:	c7 04 24 53 49 10 f0 	movl   $0xf0104953,(%esp)
f010013c:	e8 f9 32 00 00       	call   f010343a <cprintf>
	vcprintf(fmt, ap);
f0100141:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100145:	8b 45 10             	mov    0x10(%ebp),%eax
f0100148:	89 04 24             	mov    %eax,(%esp)
f010014b:	e8 b7 32 00 00       	call   f0103407 <vcprintf>
	cprintf("\n");
f0100150:	c7 04 24 79 58 10 f0 	movl   $0xf0105879,(%esp)
f0100157:	e8 de 32 00 00       	call   f010343a <cprintf>
	va_end(ap);
}
f010015c:	83 c4 14             	add    $0x14,%esp
f010015f:	5b                   	pop    %ebx
f0100160:	5d                   	pop    %ebp
f0100161:	c3                   	ret    
f0100162:	66 90                	xchg   %ax,%ax
f0100164:	66 90                	xchg   %ax,%ax
f0100166:	66 90                	xchg   %ax,%ax
f0100168:	66 90                	xchg   %ax,%ax
f010016a:	66 90                	xchg   %ax,%ax
f010016c:	66 90                	xchg   %ax,%ax
f010016e:	66 90                	xchg   %ax,%ax

f0100170 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f0100170:	55                   	push   %ebp
f0100171:	89 e5                	mov    %esp,%ebp

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100173:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100178:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f0100179:	a8 01                	test   $0x1,%al
f010017b:	74 08                	je     f0100185 <serial_proc_data+0x15>
f010017d:	b2 f8                	mov    $0xf8,%dl
f010017f:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f0100180:	0f b6 c0             	movzbl %al,%eax
f0100183:	eb 05                	jmp    f010018a <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f0100185:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f010018a:	5d                   	pop    %ebp
f010018b:	c3                   	ret    

f010018c <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f010018c:	55                   	push   %ebp
f010018d:	89 e5                	mov    %esp,%ebp
f010018f:	53                   	push   %ebx
f0100190:	83 ec 04             	sub    $0x4,%esp
f0100193:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f0100195:	eb 2a                	jmp    f01001c1 <cons_intr+0x35>
		if (c == 0)
f0100197:	85 d2                	test   %edx,%edx
f0100199:	74 26                	je     f01001c1 <cons_intr+0x35>
			continue;
		cons.buf[cons.wpos++] = c;
f010019b:	a1 e4 c2 17 f0       	mov    0xf017c2e4,%eax
f01001a0:	8d 48 01             	lea    0x1(%eax),%ecx
f01001a3:	89 0d e4 c2 17 f0    	mov    %ecx,0xf017c2e4
f01001a9:	88 90 e0 c0 17 f0    	mov    %dl,-0xfe83f20(%eax)
		if (cons.wpos == CONSBUFSIZE)
f01001af:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f01001b5:	75 0a                	jne    f01001c1 <cons_intr+0x35>
			cons.wpos = 0;
f01001b7:	c7 05 e4 c2 17 f0 00 	movl   $0x0,0xf017c2e4
f01001be:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f01001c1:	ff d3                	call   *%ebx
f01001c3:	89 c2                	mov    %eax,%edx
f01001c5:	83 f8 ff             	cmp    $0xffffffff,%eax
f01001c8:	75 cd                	jne    f0100197 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f01001ca:	83 c4 04             	add    $0x4,%esp
f01001cd:	5b                   	pop    %ebx
f01001ce:	5d                   	pop    %ebp
f01001cf:	c3                   	ret    

f01001d0 <kbd_proc_data>:
f01001d0:	ba 64 00 00 00       	mov    $0x64,%edx
f01001d5:	ec                   	in     (%dx),%al
{
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
f01001d6:	a8 01                	test   $0x1,%al
f01001d8:	0f 84 ef 00 00 00    	je     f01002cd <kbd_proc_data+0xfd>
f01001de:	b2 60                	mov    $0x60,%dl
f01001e0:	ec                   	in     (%dx),%al
f01001e1:	89 c2                	mov    %eax,%edx
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f01001e3:	3c e0                	cmp    $0xe0,%al
f01001e5:	75 0d                	jne    f01001f4 <kbd_proc_data+0x24>
		// E0 escape character
		shift |= E0ESC;
f01001e7:	83 0d c0 c0 17 f0 40 	orl    $0x40,0xf017c0c0
		return 0;
f01001ee:	b8 00 00 00 00       	mov    $0x0,%eax
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f01001f3:	c3                   	ret    
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f01001f4:	55                   	push   %ebp
f01001f5:	89 e5                	mov    %esp,%ebp
f01001f7:	53                   	push   %ebx
f01001f8:	83 ec 14             	sub    $0x14,%esp

	if (data == 0xE0) {
		// E0 escape character
		shift |= E0ESC;
		return 0;
	} else if (data & 0x80) {
f01001fb:	84 c0                	test   %al,%al
f01001fd:	79 37                	jns    f0100236 <kbd_proc_data+0x66>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f01001ff:	8b 0d c0 c0 17 f0    	mov    0xf017c0c0,%ecx
f0100205:	89 cb                	mov    %ecx,%ebx
f0100207:	83 e3 40             	and    $0x40,%ebx
f010020a:	83 e0 7f             	and    $0x7f,%eax
f010020d:	85 db                	test   %ebx,%ebx
f010020f:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f0100212:	0f b6 d2             	movzbl %dl,%edx
f0100215:	0f b6 82 c0 4a 10 f0 	movzbl -0xfefb540(%edx),%eax
f010021c:	83 c8 40             	or     $0x40,%eax
f010021f:	0f b6 c0             	movzbl %al,%eax
f0100222:	f7 d0                	not    %eax
f0100224:	21 c1                	and    %eax,%ecx
f0100226:	89 0d c0 c0 17 f0    	mov    %ecx,0xf017c0c0
		return 0;
f010022c:	b8 00 00 00 00       	mov    $0x0,%eax
f0100231:	e9 9d 00 00 00       	jmp    f01002d3 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f0100236:	8b 0d c0 c0 17 f0    	mov    0xf017c0c0,%ecx
f010023c:	f6 c1 40             	test   $0x40,%cl
f010023f:	74 0e                	je     f010024f <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f0100241:	83 c8 80             	or     $0xffffff80,%eax
f0100244:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f0100246:	83 e1 bf             	and    $0xffffffbf,%ecx
f0100249:	89 0d c0 c0 17 f0    	mov    %ecx,0xf017c0c0
	}

	shift |= shiftcode[data];
f010024f:	0f b6 d2             	movzbl %dl,%edx
f0100252:	0f b6 82 c0 4a 10 f0 	movzbl -0xfefb540(%edx),%eax
f0100259:	0b 05 c0 c0 17 f0    	or     0xf017c0c0,%eax
	shift ^= togglecode[data];
f010025f:	0f b6 8a c0 49 10 f0 	movzbl -0xfefb640(%edx),%ecx
f0100266:	31 c8                	xor    %ecx,%eax
f0100268:	a3 c0 c0 17 f0       	mov    %eax,0xf017c0c0

	c = charcode[shift & (CTL | SHIFT)][data];
f010026d:	89 c1                	mov    %eax,%ecx
f010026f:	83 e1 03             	and    $0x3,%ecx
f0100272:	8b 0c 8d a0 49 10 f0 	mov    -0xfefb660(,%ecx,4),%ecx
f0100279:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f010027d:	0f b6 da             	movzbl %dl,%ebx
	if (shift & CAPSLOCK) {
f0100280:	a8 08                	test   $0x8,%al
f0100282:	74 1b                	je     f010029f <kbd_proc_data+0xcf>
		if ('a' <= c && c <= 'z')
f0100284:	89 da                	mov    %ebx,%edx
f0100286:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f0100289:	83 f9 19             	cmp    $0x19,%ecx
f010028c:	77 05                	ja     f0100293 <kbd_proc_data+0xc3>
			c += 'A' - 'a';
f010028e:	83 eb 20             	sub    $0x20,%ebx
f0100291:	eb 0c                	jmp    f010029f <kbd_proc_data+0xcf>
		else if ('A' <= c && c <= 'Z')
f0100293:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f0100296:	8d 4b 20             	lea    0x20(%ebx),%ecx
f0100299:	83 fa 19             	cmp    $0x19,%edx
f010029c:	0f 46 d9             	cmovbe %ecx,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f010029f:	f7 d0                	not    %eax
f01002a1:	89 c2                	mov    %eax,%edx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f01002a3:	89 d8                	mov    %ebx,%eax
			c += 'a' - 'A';
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f01002a5:	f6 c2 06             	test   $0x6,%dl
f01002a8:	75 29                	jne    f01002d3 <kbd_proc_data+0x103>
f01002aa:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f01002b0:	75 21                	jne    f01002d3 <kbd_proc_data+0x103>
		cprintf("Rebooting!\n");
f01002b2:	c7 04 24 6d 49 10 f0 	movl   $0xf010496d,(%esp)
f01002b9:	e8 7c 31 00 00       	call   f010343a <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01002be:	ba 92 00 00 00       	mov    $0x92,%edx
f01002c3:	b8 03 00 00 00       	mov    $0x3,%eax
f01002c8:	ee                   	out    %al,(%dx)
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f01002c9:	89 d8                	mov    %ebx,%eax
f01002cb:	eb 06                	jmp    f01002d3 <kbd_proc_data+0x103>
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
		return -1;
f01002cd:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01002d2:	c3                   	ret    
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f01002d3:	83 c4 14             	add    $0x14,%esp
f01002d6:	5b                   	pop    %ebx
f01002d7:	5d                   	pop    %ebp
f01002d8:	c3                   	ret    

f01002d9 <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f01002d9:	55                   	push   %ebp
f01002da:	89 e5                	mov    %esp,%ebp
f01002dc:	57                   	push   %edi
f01002dd:	56                   	push   %esi
f01002de:	53                   	push   %ebx
f01002df:	83 ec 1c             	sub    $0x1c,%esp
f01002e2:	89 c7                	mov    %eax,%edi

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01002e4:	ba fd 03 00 00       	mov    $0x3fd,%edx
f01002e9:	ec                   	in     (%dx),%al
static void
serial_putc(int c)
{
	int i;
	
	for (i = 0;
f01002ea:	a8 20                	test   $0x20,%al
f01002ec:	75 21                	jne    f010030f <cons_putc+0x36>
f01002ee:	bb 00 32 00 00       	mov    $0x3200,%ebx
f01002f3:	b9 84 00 00 00       	mov    $0x84,%ecx
f01002f8:	be fd 03 00 00       	mov    $0x3fd,%esi
f01002fd:	89 ca                	mov    %ecx,%edx
f01002ff:	ec                   	in     (%dx),%al
f0100300:	ec                   	in     (%dx),%al
f0100301:	ec                   	in     (%dx),%al
f0100302:	ec                   	in     (%dx),%al
f0100303:	89 f2                	mov    %esi,%edx
f0100305:	ec                   	in     (%dx),%al
f0100306:	a8 20                	test   $0x20,%al
f0100308:	75 05                	jne    f010030f <cons_putc+0x36>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f010030a:	83 eb 01             	sub    $0x1,%ebx
f010030d:	75 ee                	jne    f01002fd <cons_putc+0x24>
	     i++)
		delay();
	
	outb(COM1 + COM_TX, c);
f010030f:	89 f8                	mov    %edi,%eax
f0100311:	0f b6 c0             	movzbl %al,%eax
f0100314:	89 45 e4             	mov    %eax,-0x1c(%ebp)
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100317:	ba f8 03 00 00       	mov    $0x3f8,%edx
f010031c:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010031d:	b2 79                	mov    $0x79,%dl
f010031f:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f0100320:	84 c0                	test   %al,%al
f0100322:	78 21                	js     f0100345 <cons_putc+0x6c>
f0100324:	bb 00 32 00 00       	mov    $0x3200,%ebx
f0100329:	b9 84 00 00 00       	mov    $0x84,%ecx
f010032e:	be 79 03 00 00       	mov    $0x379,%esi
f0100333:	89 ca                	mov    %ecx,%edx
f0100335:	ec                   	in     (%dx),%al
f0100336:	ec                   	in     (%dx),%al
f0100337:	ec                   	in     (%dx),%al
f0100338:	ec                   	in     (%dx),%al
f0100339:	89 f2                	mov    %esi,%edx
f010033b:	ec                   	in     (%dx),%al
f010033c:	84 c0                	test   %al,%al
f010033e:	78 05                	js     f0100345 <cons_putc+0x6c>
f0100340:	83 eb 01             	sub    $0x1,%ebx
f0100343:	75 ee                	jne    f0100333 <cons_putc+0x5a>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100345:	ba 78 03 00 00       	mov    $0x378,%edx
f010034a:	0f b6 45 e4          	movzbl -0x1c(%ebp),%eax
f010034e:	ee                   	out    %al,(%dx)
f010034f:	b2 7a                	mov    $0x7a,%dl
f0100351:	b8 0d 00 00 00       	mov    $0xd,%eax
f0100356:	ee                   	out    %al,(%dx)
f0100357:	b8 08 00 00 00       	mov    $0x8,%eax
f010035c:	ee                   	out    %al,(%dx)

static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f010035d:	89 fa                	mov    %edi,%edx
f010035f:	81 e2 00 ff ff ff    	and    $0xffffff00,%edx
		c |= 0x0700;
f0100365:	89 f8                	mov    %edi,%eax
f0100367:	80 cc 07             	or     $0x7,%ah
f010036a:	85 d2                	test   %edx,%edx
f010036c:	0f 44 f8             	cmove  %eax,%edi

	switch (c & 0xff) {
f010036f:	89 f8                	mov    %edi,%eax
f0100371:	0f b6 c0             	movzbl %al,%eax
f0100374:	83 f8 09             	cmp    $0x9,%eax
f0100377:	74 79                	je     f01003f2 <cons_putc+0x119>
f0100379:	83 f8 09             	cmp    $0x9,%eax
f010037c:	7f 0a                	jg     f0100388 <cons_putc+0xaf>
f010037e:	83 f8 08             	cmp    $0x8,%eax
f0100381:	74 19                	je     f010039c <cons_putc+0xc3>
f0100383:	e9 9e 00 00 00       	jmp    f0100426 <cons_putc+0x14d>
f0100388:	83 f8 0a             	cmp    $0xa,%eax
f010038b:	90                   	nop
f010038c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100390:	74 3a                	je     f01003cc <cons_putc+0xf3>
f0100392:	83 f8 0d             	cmp    $0xd,%eax
f0100395:	74 3d                	je     f01003d4 <cons_putc+0xfb>
f0100397:	e9 8a 00 00 00       	jmp    f0100426 <cons_putc+0x14d>
	case '\b':
		if (crt_pos > 0) {
f010039c:	0f b7 05 e8 c2 17 f0 	movzwl 0xf017c2e8,%eax
f01003a3:	66 85 c0             	test   %ax,%ax
f01003a6:	0f 84 e5 00 00 00    	je     f0100491 <cons_putc+0x1b8>
			crt_pos--;
f01003ac:	83 e8 01             	sub    $0x1,%eax
f01003af:	66 a3 e8 c2 17 f0    	mov    %ax,0xf017c2e8
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f01003b5:	0f b7 c0             	movzwl %ax,%eax
f01003b8:	66 81 e7 00 ff       	and    $0xff00,%di
f01003bd:	83 cf 20             	or     $0x20,%edi
f01003c0:	8b 15 ec c2 17 f0    	mov    0xf017c2ec,%edx
f01003c6:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f01003ca:	eb 78                	jmp    f0100444 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f01003cc:	66 83 05 e8 c2 17 f0 	addw   $0x50,0xf017c2e8
f01003d3:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f01003d4:	0f b7 05 e8 c2 17 f0 	movzwl 0xf017c2e8,%eax
f01003db:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f01003e1:	c1 e8 16             	shr    $0x16,%eax
f01003e4:	8d 04 80             	lea    (%eax,%eax,4),%eax
f01003e7:	c1 e0 04             	shl    $0x4,%eax
f01003ea:	66 a3 e8 c2 17 f0    	mov    %ax,0xf017c2e8
f01003f0:	eb 52                	jmp    f0100444 <cons_putc+0x16b>
		break;
	case '\t':
		cons_putc(' ');
f01003f2:	b8 20 00 00 00       	mov    $0x20,%eax
f01003f7:	e8 dd fe ff ff       	call   f01002d9 <cons_putc>
		cons_putc(' ');
f01003fc:	b8 20 00 00 00       	mov    $0x20,%eax
f0100401:	e8 d3 fe ff ff       	call   f01002d9 <cons_putc>
		cons_putc(' ');
f0100406:	b8 20 00 00 00       	mov    $0x20,%eax
f010040b:	e8 c9 fe ff ff       	call   f01002d9 <cons_putc>
		cons_putc(' ');
f0100410:	b8 20 00 00 00       	mov    $0x20,%eax
f0100415:	e8 bf fe ff ff       	call   f01002d9 <cons_putc>
		cons_putc(' ');
f010041a:	b8 20 00 00 00       	mov    $0x20,%eax
f010041f:	e8 b5 fe ff ff       	call   f01002d9 <cons_putc>
f0100424:	eb 1e                	jmp    f0100444 <cons_putc+0x16b>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f0100426:	0f b7 05 e8 c2 17 f0 	movzwl 0xf017c2e8,%eax
f010042d:	8d 50 01             	lea    0x1(%eax),%edx
f0100430:	66 89 15 e8 c2 17 f0 	mov    %dx,0xf017c2e8
f0100437:	0f b7 c0             	movzwl %ax,%eax
f010043a:	8b 15 ec c2 17 f0    	mov    0xf017c2ec,%edx
f0100440:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f0100444:	66 81 3d e8 c2 17 f0 	cmpw   $0x7cf,0xf017c2e8
f010044b:	cf 07 
f010044d:	76 42                	jbe    f0100491 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f010044f:	a1 ec c2 17 f0       	mov    0xf017c2ec,%eax
f0100454:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010045b:	00 
f010045c:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100462:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100466:	89 04 24             	mov    %eax,(%esp)
f0100469:	e8 38 40 00 00       	call   f01044a6 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010046e:	8b 15 ec c2 17 f0    	mov    0xf017c2ec,%edx
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f0100474:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f0100479:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f010047f:	83 c0 01             	add    $0x1,%eax
f0100482:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f0100487:	75 f0                	jne    f0100479 <cons_putc+0x1a0>
			crt_buf[i] = 0x0700 | ' ';
		crt_pos -= CRT_COLS;
f0100489:	66 83 2d e8 c2 17 f0 	subw   $0x50,0xf017c2e8
f0100490:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100491:	8b 0d f0 c2 17 f0    	mov    0xf017c2f0,%ecx
f0100497:	b8 0e 00 00 00       	mov    $0xe,%eax
f010049c:	89 ca                	mov    %ecx,%edx
f010049e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010049f:	0f b7 1d e8 c2 17 f0 	movzwl 0xf017c2e8,%ebx
f01004a6:	8d 71 01             	lea    0x1(%ecx),%esi
f01004a9:	89 d8                	mov    %ebx,%eax
f01004ab:	66 c1 e8 08          	shr    $0x8,%ax
f01004af:	89 f2                	mov    %esi,%edx
f01004b1:	ee                   	out    %al,(%dx)
f01004b2:	b8 0f 00 00 00       	mov    $0xf,%eax
f01004b7:	89 ca                	mov    %ecx,%edx
f01004b9:	ee                   	out    %al,(%dx)
f01004ba:	89 d8                	mov    %ebx,%eax
f01004bc:	89 f2                	mov    %esi,%edx
f01004be:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f01004bf:	83 c4 1c             	add    $0x1c,%esp
f01004c2:	5b                   	pop    %ebx
f01004c3:	5e                   	pop    %esi
f01004c4:	5f                   	pop    %edi
f01004c5:	5d                   	pop    %ebp
f01004c6:	c3                   	ret    

f01004c7 <serial_intr>:
}

void
serial_intr(void)
{
	if (serial_exists)
f01004c7:	83 3d f4 c2 17 f0 00 	cmpl   $0x0,0xf017c2f4
f01004ce:	74 11                	je     f01004e1 <serial_intr+0x1a>
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f01004d0:	55                   	push   %ebp
f01004d1:	89 e5                	mov    %esp,%ebp
f01004d3:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
		cons_intr(serial_proc_data);
f01004d6:	b8 70 01 10 f0       	mov    $0xf0100170,%eax
f01004db:	e8 ac fc ff ff       	call   f010018c <cons_intr>
}
f01004e0:	c9                   	leave  
f01004e1:	f3 c3                	repz ret 

f01004e3 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f01004e3:	55                   	push   %ebp
f01004e4:	89 e5                	mov    %esp,%ebp
f01004e6:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f01004e9:	b8 d0 01 10 f0       	mov    $0xf01001d0,%eax
f01004ee:	e8 99 fc ff ff       	call   f010018c <cons_intr>
}
f01004f3:	c9                   	leave  
f01004f4:	c3                   	ret    

f01004f5 <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f01004f5:	55                   	push   %ebp
f01004f6:	89 e5                	mov    %esp,%ebp
f01004f8:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f01004fb:	e8 c7 ff ff ff       	call   f01004c7 <serial_intr>
	kbd_intr();
f0100500:	e8 de ff ff ff       	call   f01004e3 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f0100505:	a1 e0 c2 17 f0       	mov    0xf017c2e0,%eax
f010050a:	3b 05 e4 c2 17 f0    	cmp    0xf017c2e4,%eax
f0100510:	74 26                	je     f0100538 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f0100512:	8d 50 01             	lea    0x1(%eax),%edx
f0100515:	89 15 e0 c2 17 f0    	mov    %edx,0xf017c2e0
f010051b:	0f b6 88 e0 c0 17 f0 	movzbl -0xfe83f20(%eax),%ecx
		if (cons.rpos == CONSBUFSIZE)
			cons.rpos = 0;
		return c;
f0100522:	89 c8                	mov    %ecx,%eax
	kbd_intr();

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
		c = cons.buf[cons.rpos++];
		if (cons.rpos == CONSBUFSIZE)
f0100524:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f010052a:	75 11                	jne    f010053d <cons_getc+0x48>
			cons.rpos = 0;
f010052c:	c7 05 e0 c2 17 f0 00 	movl   $0x0,0xf017c2e0
f0100533:	00 00 00 
f0100536:	eb 05                	jmp    f010053d <cons_getc+0x48>
		return c;
	}
	return 0;
f0100538:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010053d:	c9                   	leave  
f010053e:	c3                   	ret    

f010053f <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f010053f:	55                   	push   %ebp
f0100540:	89 e5                	mov    %esp,%ebp
f0100542:	57                   	push   %edi
f0100543:	56                   	push   %esi
f0100544:	53                   	push   %ebx
f0100545:	83 ec 1c             	sub    $0x1c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f0100548:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f010054f:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f0100556:	5a a5 
	if (*cp != 0xA55A) {
f0100558:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f010055f:	66 3d 5a a5          	cmp    $0xa55a,%ax
f0100563:	74 11                	je     f0100576 <cons_init+0x37>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f0100565:	c7 05 f0 c2 17 f0 b4 	movl   $0x3b4,0xf017c2f0
f010056c:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f010056f:	bf 00 00 0b f0       	mov    $0xf00b0000,%edi
f0100574:	eb 16                	jmp    f010058c <cons_init+0x4d>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f0100576:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f010057d:	c7 05 f0 c2 17 f0 d4 	movl   $0x3d4,0xf017c2f0
f0100584:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f0100587:	bf 00 80 0b f0       	mov    $0xf00b8000,%edi
		*cp = was;
		addr_6845 = CGA_BASE;
	}
	
	/* Extract cursor location */
	outb(addr_6845, 14);
f010058c:	8b 0d f0 c2 17 f0    	mov    0xf017c2f0,%ecx
f0100592:	b8 0e 00 00 00       	mov    $0xe,%eax
f0100597:	89 ca                	mov    %ecx,%edx
f0100599:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f010059a:	8d 59 01             	lea    0x1(%ecx),%ebx

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010059d:	89 da                	mov    %ebx,%edx
f010059f:	ec                   	in     (%dx),%al
f01005a0:	0f b6 f0             	movzbl %al,%esi
f01005a3:	c1 e6 08             	shl    $0x8,%esi
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01005a6:	b8 0f 00 00 00       	mov    $0xf,%eax
f01005ab:	89 ca                	mov    %ecx,%edx
f01005ad:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01005ae:	89 da                	mov    %ebx,%edx
f01005b0:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f01005b1:	89 3d ec c2 17 f0    	mov    %edi,0xf017c2ec
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f01005b7:	0f b6 d8             	movzbl %al,%ebx
f01005ba:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f01005bc:	66 89 35 e8 c2 17 f0 	mov    %si,0xf017c2e8
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01005c3:	be fa 03 00 00       	mov    $0x3fa,%esi
f01005c8:	b8 00 00 00 00       	mov    $0x0,%eax
f01005cd:	89 f2                	mov    %esi,%edx
f01005cf:	ee                   	out    %al,(%dx)
f01005d0:	b2 fb                	mov    $0xfb,%dl
f01005d2:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f01005d7:	ee                   	out    %al,(%dx)
f01005d8:	bb f8 03 00 00       	mov    $0x3f8,%ebx
f01005dd:	b8 0c 00 00 00       	mov    $0xc,%eax
f01005e2:	89 da                	mov    %ebx,%edx
f01005e4:	ee                   	out    %al,(%dx)
f01005e5:	b2 f9                	mov    $0xf9,%dl
f01005e7:	b8 00 00 00 00       	mov    $0x0,%eax
f01005ec:	ee                   	out    %al,(%dx)
f01005ed:	b2 fb                	mov    $0xfb,%dl
f01005ef:	b8 03 00 00 00       	mov    $0x3,%eax
f01005f4:	ee                   	out    %al,(%dx)
f01005f5:	b2 fc                	mov    $0xfc,%dl
f01005f7:	b8 00 00 00 00       	mov    $0x0,%eax
f01005fc:	ee                   	out    %al,(%dx)
f01005fd:	b2 f9                	mov    $0xf9,%dl
f01005ff:	b8 01 00 00 00       	mov    $0x1,%eax
f0100604:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100605:	b2 fd                	mov    $0xfd,%dl
f0100607:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f0100608:	3c ff                	cmp    $0xff,%al
f010060a:	0f 95 c1             	setne  %cl
f010060d:	0f b6 c9             	movzbl %cl,%ecx
f0100610:	89 0d f4 c2 17 f0    	mov    %ecx,0xf017c2f4
f0100616:	89 f2                	mov    %esi,%edx
f0100618:	ec                   	in     (%dx),%al
f0100619:	89 da                	mov    %ebx,%edx
f010061b:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f010061c:	85 c9                	test   %ecx,%ecx
f010061e:	75 0c                	jne    f010062c <cons_init+0xed>
		cprintf("Serial port does not exist!\n");
f0100620:	c7 04 24 79 49 10 f0 	movl   $0xf0104979,(%esp)
f0100627:	e8 0e 2e 00 00       	call   f010343a <cprintf>
}
f010062c:	83 c4 1c             	add    $0x1c,%esp
f010062f:	5b                   	pop    %ebx
f0100630:	5e                   	pop    %esi
f0100631:	5f                   	pop    %edi
f0100632:	5d                   	pop    %ebp
f0100633:	c3                   	ret    

f0100634 <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f0100634:	55                   	push   %ebp
f0100635:	89 e5                	mov    %esp,%ebp
f0100637:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f010063a:	8b 45 08             	mov    0x8(%ebp),%eax
f010063d:	e8 97 fc ff ff       	call   f01002d9 <cons_putc>
}
f0100642:	c9                   	leave  
f0100643:	c3                   	ret    

f0100644 <getchar>:

int
getchar(void)
{
f0100644:	55                   	push   %ebp
f0100645:	89 e5                	mov    %esp,%ebp
f0100647:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f010064a:	e8 a6 fe ff ff       	call   f01004f5 <cons_getc>
f010064f:	85 c0                	test   %eax,%eax
f0100651:	74 f7                	je     f010064a <getchar+0x6>
		/* do nothing */;
	return c;
}
f0100653:	c9                   	leave  
f0100654:	c3                   	ret    

f0100655 <iscons>:

int
iscons(int fdnum)
{
f0100655:	55                   	push   %ebp
f0100656:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f0100658:	b8 01 00 00 00       	mov    $0x1,%eax
f010065d:	5d                   	pop    %ebp
f010065e:	c3                   	ret    
f010065f:	90                   	nop

f0100660 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100660:	55                   	push   %ebp
f0100661:	89 e5                	mov    %esp,%ebp
f0100663:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < NCOMMANDS; i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100666:	c7 44 24 08 c0 4b 10 	movl   $0xf0104bc0,0x8(%esp)
f010066d:	f0 
f010066e:	c7 44 24 04 de 4b 10 	movl   $0xf0104bde,0x4(%esp)
f0100675:	f0 
f0100676:	c7 04 24 e3 4b 10 f0 	movl   $0xf0104be3,(%esp)
f010067d:	e8 b8 2d 00 00       	call   f010343a <cprintf>
f0100682:	c7 44 24 08 80 4c 10 	movl   $0xf0104c80,0x8(%esp)
f0100689:	f0 
f010068a:	c7 44 24 04 ec 4b 10 	movl   $0xf0104bec,0x4(%esp)
f0100691:	f0 
f0100692:	c7 04 24 e3 4b 10 f0 	movl   $0xf0104be3,(%esp)
f0100699:	e8 9c 2d 00 00       	call   f010343a <cprintf>
f010069e:	c7 44 24 08 a8 4c 10 	movl   $0xf0104ca8,0x8(%esp)
f01006a5:	f0 
f01006a6:	c7 44 24 04 f5 4b 10 	movl   $0xf0104bf5,0x4(%esp)
f01006ad:	f0 
f01006ae:	c7 04 24 e3 4b 10 f0 	movl   $0xf0104be3,(%esp)
f01006b5:	e8 80 2d 00 00       	call   f010343a <cprintf>
	return 0;
}
f01006ba:	b8 00 00 00 00       	mov    $0x0,%eax
f01006bf:	c9                   	leave  
f01006c0:	c3                   	ret    

f01006c1 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f01006c1:	55                   	push   %ebp
f01006c2:	89 e5                	mov    %esp,%ebp
f01006c4:	83 ec 18             	sub    $0x18,%esp
	extern char entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f01006c7:	c7 04 24 ff 4b 10 f0 	movl   $0xf0104bff,(%esp)
f01006ce:	e8 67 2d 00 00       	call   f010343a <cprintf>
	cprintf(" this is work 1 insert:\n");
f01006d3:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01006da:	e8 5b 2d 00 00       	call   f010343a <cprintf>
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
f01006df:	c7 44 24 08 0f 00 00 	movl   $0xf,0x8(%esp)
f01006e6:	00 
f01006e7:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
f01006ee:	00 
f01006ef:	c7 04 24 d4 4c 10 f0 	movl   $0xf0104cd4,(%esp)
f01006f6:	e8 3f 2d 00 00       	call   f010343a <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
f01006fb:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f0100702:	00 
f0100703:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f010070a:	f0 
f010070b:	c7 04 24 0c 4d 10 f0 	movl   $0xf0104d0c,(%esp)
f0100712:	e8 23 2d 00 00       	call   f010343a <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f0100717:	c7 44 24 08 17 49 10 	movl   $0x104917,0x8(%esp)
f010071e:	00 
f010071f:	c7 44 24 04 17 49 10 	movl   $0xf0104917,0x4(%esp)
f0100726:	f0 
f0100727:	c7 04 24 34 4d 10 f0 	movl   $0xf0104d34,(%esp)
f010072e:	e8 07 2d 00 00       	call   f010343a <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f0100733:	c7 44 24 08 a1 c0 17 	movl   $0x17c0a1,0x8(%esp)
f010073a:	00 
f010073b:	c7 44 24 04 a1 c0 17 	movl   $0xf017c0a1,0x4(%esp)
f0100742:	f0 
f0100743:	c7 04 24 58 4d 10 f0 	movl   $0xf0104d58,(%esp)
f010074a:	e8 eb 2c 00 00       	call   f010343a <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f010074f:	c7 44 24 08 d0 cf 17 	movl   $0x17cfd0,0x8(%esp)
f0100756:	00 
f0100757:	c7 44 24 04 d0 cf 17 	movl   $0xf017cfd0,0x4(%esp)
f010075e:	f0 
f010075f:	c7 04 24 7c 4d 10 f0 	movl   $0xf0104d7c,(%esp)
f0100766:	e8 cf 2c 00 00       	call   f010343a <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f010076b:	b8 cf d3 17 f0       	mov    $0xf017d3cf,%eax
f0100770:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f0100775:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f010077b:	85 c0                	test   %eax,%eax
f010077d:	0f 48 c2             	cmovs  %edx,%eax
f0100780:	c1 f8 0a             	sar    $0xa,%eax
f0100783:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100787:	c7 04 24 a0 4d 10 f0 	movl   $0xf0104da0,(%esp)
f010078e:	e8 a7 2c 00 00       	call   f010343a <cprintf>
		(end-entry+1023)/1024);
	return 0;
}
f0100793:	b8 00 00 00 00       	mov    $0x0,%eax
f0100798:	c9                   	leave  
f0100799:	c3                   	ret    

f010079a <mon_backtrace>:
int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f010079a:	55                   	push   %ebp
f010079b:	89 e5                	mov    %esp,%ebp
f010079d:	56                   	push   %esi
f010079e:	53                   	push   %ebx
f010079f:	83 ec 40             	sub    $0x40,%esp
	// Your code here
	cprintf("start backtrace\n");
f01007a2:	c7 04 24 31 4c 10 f0 	movl   $0xf0104c31,(%esp)
f01007a9:	e8 8c 2c 00 00       	call   f010343a <cprintf>
	cprintf("\n");
f01007ae:	c7 04 24 79 58 10 f0 	movl   $0xf0105879,(%esp)
f01007b5:	e8 80 2c 00 00       	call   f010343a <cprintf>

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f01007ba:	89 e8                	mov    %ebp,%eax
f01007bc:	89 c1                	mov    %eax,%ecx
	uint32_t eip;
	uint32_t ebp = read_ebp();
	uint32_t esp;
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
f01007be:	83 f8 ff             	cmp    $0xffffffff,%eax
f01007c1:	74 63                	je     f0100826 <mon_backtrace+0x8c>
		esp = ebp+8;
		eip = *(uint32_t*)(ebp+4);
f01007c3:	8b 71 04             	mov    0x4(%ecx),%esi
		if(ebp==0){
			ebp = -1;
f01007c6:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
		esp = ebp+8;
		eip = *(uint32_t*)(ebp+4);
		if(ebp==0){
f01007cb:	85 c9                	test   %ecx,%ecx
f01007cd:	74 02                	je     f01007d1 <mon_backtrace+0x37>
			ebp = -1;
		}else{
			ebp = *(uint32_t*)(ebp);
f01007cf:	8b 19                	mov    (%ecx),%ebx
		}
		for(i=0;i<5;i++){
f01007d1:	b8 00 00 00 00       	mov    $0x0,%eax
		args[i] = *(uint32_t*)(esp+i*4);
f01007d6:	8b 54 81 08          	mov    0x8(%ecx,%eax,4),%edx
f01007da:	89 54 85 e4          	mov    %edx,-0x1c(%ebp,%eax,4)
		if(ebp==0){
			ebp = -1;
		}else{
			ebp = *(uint32_t*)(ebp);
		}
		for(i=0;i<5;i++){
f01007de:	83 c0 01             	add    $0x1,%eax
f01007e1:	83 f8 05             	cmp    $0x5,%eax
f01007e4:	75 f0                	jne    f01007d6 <mon_backtrace+0x3c>
		args[i] = *(uint32_t*)(esp+i*4);
	        }
                            cprintf("ebp  %08x   eip %08x   args  %08x  %08x  %08x  %08x  %08x\n",ebp,eip,args[0],args[1],args[2],args[3],args[4]);
f01007e6:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01007e9:	89 44 24 1c          	mov    %eax,0x1c(%esp)
f01007ed:	8b 45 f0             	mov    -0x10(%ebp),%eax
f01007f0:	89 44 24 18          	mov    %eax,0x18(%esp)
f01007f4:	8b 45 ec             	mov    -0x14(%ebp),%eax
f01007f7:	89 44 24 14          	mov    %eax,0x14(%esp)
f01007fb:	8b 45 e8             	mov    -0x18(%ebp),%eax
f01007fe:	89 44 24 10          	mov    %eax,0x10(%esp)
f0100802:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100805:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100809:	89 74 24 08          	mov    %esi,0x8(%esp)
f010080d:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100811:	c7 04 24 cc 4d 10 f0 	movl   $0xf0104dcc,(%esp)
f0100818:	e8 1d 2c 00 00       	call   f010343a <cprintf>
	uint32_t eip;
	uint32_t ebp = read_ebp();
	uint32_t esp;
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
f010081d:	83 fb ff             	cmp    $0xffffffff,%ebx
f0100820:	74 04                	je     f0100826 <mon_backtrace+0x8c>
f0100822:	89 d9                	mov    %ebx,%ecx
f0100824:	eb 9d                	jmp    f01007c3 <mon_backtrace+0x29>
                            cprintf("ebp  %08x   eip %08x   args  %08x  %08x  %08x  %08x  %08x\n",ebp,eip,args[0],args[1],args[2],args[3],args[4]);

	}
	
	return 0;
}
f0100826:	b8 00 00 00 00       	mov    $0x0,%eax
f010082b:	83 c4 40             	add    $0x40,%esp
f010082e:	5b                   	pop    %ebx
f010082f:	5e                   	pop    %esi
f0100830:	5d                   	pop    %ebp
f0100831:	c3                   	ret    

f0100832 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f0100832:	55                   	push   %ebp
f0100833:	89 e5                	mov    %esp,%ebp
f0100835:	57                   	push   %edi
f0100836:	56                   	push   %esi
f0100837:	53                   	push   %ebx
f0100838:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f010083b:	c7 04 24 08 4e 10 f0 	movl   $0xf0104e08,(%esp)
f0100842:	e8 f3 2b 00 00       	call   f010343a <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f0100847:	c7 04 24 2c 4e 10 f0 	movl   $0xf0104e2c,(%esp)
f010084e:	e8 e7 2b 00 00       	call   f010343a <cprintf>

	if (tf != NULL)
f0100853:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f0100857:	74 0b                	je     f0100864 <monitor+0x32>
		print_trapframe(tf);
f0100859:	8b 45 08             	mov    0x8(%ebp),%eax
f010085c:	89 04 24             	mov    %eax,(%esp)
f010085f:	e8 fe 2c 00 00       	call   f0103562 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f0100864:	c7 04 24 42 4c 10 f0 	movl   $0xf0104c42,(%esp)
f010086b:	e8 10 39 00 00       	call   f0104180 <readline>
f0100870:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f0100872:	85 c0                	test   %eax,%eax
f0100874:	74 ee                	je     f0100864 <monitor+0x32>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f0100876:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f010087d:	be 00 00 00 00       	mov    $0x0,%esi
f0100882:	eb 0a                	jmp    f010088e <monitor+0x5c>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f0100884:	c6 03 00             	movb   $0x0,(%ebx)
f0100887:	89 f7                	mov    %esi,%edi
f0100889:	8d 5b 01             	lea    0x1(%ebx),%ebx
f010088c:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f010088e:	0f b6 03             	movzbl (%ebx),%eax
f0100891:	84 c0                	test   %al,%al
f0100893:	74 6a                	je     f01008ff <monitor+0xcd>
f0100895:	0f be c0             	movsbl %al,%eax
f0100898:	89 44 24 04          	mov    %eax,0x4(%esp)
f010089c:	c7 04 24 46 4c 10 f0 	movl   $0xf0104c46,(%esp)
f01008a3:	e8 51 3b 00 00       	call   f01043f9 <strchr>
f01008a8:	85 c0                	test   %eax,%eax
f01008aa:	75 d8                	jne    f0100884 <monitor+0x52>
			*buf++ = 0;
		if (*buf == 0)
f01008ac:	80 3b 00             	cmpb   $0x0,(%ebx)
f01008af:	74 4e                	je     f01008ff <monitor+0xcd>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f01008b1:	83 fe 0f             	cmp    $0xf,%esi
f01008b4:	75 16                	jne    f01008cc <monitor+0x9a>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f01008b6:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f01008bd:	00 
f01008be:	c7 04 24 4b 4c 10 f0 	movl   $0xf0104c4b,(%esp)
f01008c5:	e8 70 2b 00 00       	call   f010343a <cprintf>
f01008ca:	eb 98                	jmp    f0100864 <monitor+0x32>
			return 0;
		}
		argv[argc++] = buf;
f01008cc:	8d 7e 01             	lea    0x1(%esi),%edi
f01008cf:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f01008d3:	0f b6 03             	movzbl (%ebx),%eax
f01008d6:	84 c0                	test   %al,%al
f01008d8:	75 0c                	jne    f01008e6 <monitor+0xb4>
f01008da:	eb b0                	jmp    f010088c <monitor+0x5a>
			buf++;
f01008dc:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f01008df:	0f b6 03             	movzbl (%ebx),%eax
f01008e2:	84 c0                	test   %al,%al
f01008e4:	74 a6                	je     f010088c <monitor+0x5a>
f01008e6:	0f be c0             	movsbl %al,%eax
f01008e9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01008ed:	c7 04 24 46 4c 10 f0 	movl   $0xf0104c46,(%esp)
f01008f4:	e8 00 3b 00 00       	call   f01043f9 <strchr>
f01008f9:	85 c0                	test   %eax,%eax
f01008fb:	74 df                	je     f01008dc <monitor+0xaa>
f01008fd:	eb 8d                	jmp    f010088c <monitor+0x5a>
			buf++;
	}
	argv[argc] = 0;
f01008ff:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f0100906:	00 

	// Lookup and invoke the command
	if (argc == 0)
f0100907:	85 f6                	test   %esi,%esi
f0100909:	0f 84 55 ff ff ff    	je     f0100864 <monitor+0x32>
f010090f:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100914:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f0100917:	8b 04 85 60 4e 10 f0 	mov    -0xfefb1a0(,%eax,4),%eax
f010091e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100922:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100925:	89 04 24             	mov    %eax,(%esp)
f0100928:	e8 48 3a 00 00       	call   f0104375 <strcmp>
f010092d:	85 c0                	test   %eax,%eax
f010092f:	75 24                	jne    f0100955 <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100931:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100934:	8b 55 08             	mov    0x8(%ebp),%edx
f0100937:	89 54 24 08          	mov    %edx,0x8(%esp)
f010093b:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f010093e:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100942:	89 34 24             	mov    %esi,(%esp)
f0100945:	ff 14 85 68 4e 10 f0 	call   *-0xfefb198(,%eax,4)
		print_trapframe(tf);

	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f010094c:	85 c0                	test   %eax,%eax
f010094e:	78 25                	js     f0100975 <monitor+0x143>
f0100950:	e9 0f ff ff ff       	jmp    f0100864 <monitor+0x32>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
f0100955:	83 c3 01             	add    $0x1,%ebx
f0100958:	83 fb 03             	cmp    $0x3,%ebx
f010095b:	75 b7                	jne    f0100914 <monitor+0xe2>
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f010095d:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100960:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100964:	c7 04 24 68 4c 10 f0 	movl   $0xf0104c68,(%esp)
f010096b:	e8 ca 2a 00 00       	call   f010343a <cprintf>
f0100970:	e9 ef fe ff ff       	jmp    f0100864 <monitor+0x32>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f0100975:	83 c4 5c             	add    $0x5c,%esp
f0100978:	5b                   	pop    %ebx
f0100979:	5e                   	pop    %esi
f010097a:	5f                   	pop    %edi
f010097b:	5d                   	pop    %ebp
f010097c:	c3                   	ret    

f010097d <read_eip>:
// return EIP of caller.
// does not work if inlined.
// putting at the end of the file seems to prevent inlining.
unsigned
read_eip()
{
f010097d:	55                   	push   %ebp
f010097e:	89 e5                	mov    %esp,%ebp
	uint32_t callerpc;
	__asm __volatile("movl 4(%%ebp), %0" : "=r" (callerpc));
f0100980:	8b 45 04             	mov    0x4(%ebp),%eax
	return callerpc;
}
f0100983:	5d                   	pop    %ebp
f0100984:	c3                   	ret    
f0100985:	66 90                	xchg   %ax,%ax
f0100987:	66 90                	xchg   %ax,%ax
f0100989:	66 90                	xchg   %ax,%ax
f010098b:	66 90                	xchg   %ax,%ax
f010098d:	66 90                	xchg   %ax,%ax
f010098f:	90                   	nop

f0100990 <boot_alloc>:
// If we're out of memory, boot_alloc should panic.
// This function may ONLY be used during initialization,
// before the page_free_list list has been set up.
static void *
boot_alloc(uint32_t n)
{
f0100990:	55                   	push   %ebp
f0100991:	89 e5                	mov    %esp,%ebp
f0100993:	53                   	push   %ebx
f0100994:	83 ec 14             	sub    $0x14,%esp
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f0100997:	83 3d f8 c2 17 f0 00 	cmpl   $0x0,0xf017c2f8
f010099e:	75 36                	jne    f01009d6 <boot_alloc+0x46>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f01009a0:	ba cf df 17 f0       	mov    $0xf017dfcf,%edx
f01009a5:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f01009ab:	89 15 f8 c2 17 f0    	mov    %edx,0xf017c2f8
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f01009b1:	85 c0                	test   %eax,%eax
f01009b3:	74 19                	je     f01009ce <boot_alloc+0x3e>
                      result = nextfree;
f01009b5:	8b 1d f8 c2 17 f0    	mov    0xf017c2f8,%ebx
                      nextfree += ROUNDUP(n, PGSIZE);
f01009bb:	05 ff 0f 00 00       	add    $0xfff,%eax
f01009c0:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01009c5:	01 d8                	add    %ebx,%eax
f01009c7:	a3 f8 c2 17 f0       	mov    %eax,0xf017c2f8
f01009cc:	eb 0e                	jmp    f01009dc <boot_alloc+0x4c>
               } else if (n == 0)
                      result = nextfree;
f01009ce:	8b 1d f8 c2 17 f0    	mov    0xf017c2f8,%ebx
f01009d4:	eb 06                	jmp    f01009dc <boot_alloc+0x4c>
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f01009d6:	85 c0                	test   %eax,%eax
f01009d8:	74 f4                	je     f01009ce <boot_alloc+0x3e>
f01009da:	eb d9                	jmp    f01009b5 <boot_alloc+0x25>
                      nextfree += ROUNDUP(n, PGSIZE);
               } else if (n == 0)
                      result = nextfree;
              else
                      result = NULL;
              cprintf(">>  boot_alloc() was called! Entry(virtual address) of new page is: %x\n\n", (int)result);
f01009dc:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01009e0:	c7 04 24 84 4e 10 f0 	movl   $0xf0104e84,(%esp)
f01009e7:	e8 4e 2a 00 00       	call   f010343a <cprintf>
              return result;
   
	//return NULL;
}
f01009ec:	89 d8                	mov    %ebx,%eax
f01009ee:	83 c4 14             	add    $0x14,%esp
f01009f1:	5b                   	pop    %ebx
f01009f2:	5d                   	pop    %ebp
f01009f3:	c3                   	ret    

f01009f4 <check_va2pa>:
static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
f01009f4:	89 d1                	mov    %edx,%ecx
f01009f6:	c1 e9 16             	shr    $0x16,%ecx
	if (!(*pgdir & PTE_P))
f01009f9:	8b 04 88             	mov    (%eax,%ecx,4),%eax
f01009fc:	a8 01                	test   $0x1,%al
f01009fe:	74 5d                	je     f0100a5d <check_va2pa+0x69>
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
f0100a00:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100a05:	89 c1                	mov    %eax,%ecx
f0100a07:	c1 e9 0c             	shr    $0xc,%ecx
f0100a0a:	3b 0d c4 cf 17 f0    	cmp    0xf017cfc4,%ecx
f0100a10:	72 26                	jb     f0100a38 <check_va2pa+0x44>
// this functionality for us!  We define our own version to help check
// the check_kern_pgdir() function; it shouldn't be used elsewhere.

static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
f0100a12:	55                   	push   %ebp
f0100a13:	89 e5                	mov    %esp,%ebp
f0100a15:	83 ec 18             	sub    $0x18,%esp
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100a18:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100a1c:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f0100a23:	f0 
f0100a24:	c7 44 24 04 21 03 00 	movl   $0x321,0x4(%esp)
f0100a2b:	00 
f0100a2c:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0100a33:	e8 86 f6 ff ff       	call   f01000be <_panic>

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
f0100a38:	c1 ea 0c             	shr    $0xc,%edx
f0100a3b:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f0100a41:	8b 84 90 00 00 00 f0 	mov    -0x10000000(%eax,%edx,4),%eax
f0100a48:	89 c2                	mov    %eax,%edx
f0100a4a:	83 e2 01             	and    $0x1,%edx
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
f0100a4d:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100a52:	85 d2                	test   %edx,%edx
f0100a54:	ba ff ff ff ff       	mov    $0xffffffff,%edx
f0100a59:	0f 44 c2             	cmove  %edx,%eax
f0100a5c:	c3                   	ret    
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
f0100a5d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
}
f0100a62:	c3                   	ret    

f0100a63 <check_page_free_list>:
//
// Check that the pages on the page_free_list are reasonable.
//
static void
check_page_free_list(bool only_low_memory)
{
f0100a63:	55                   	push   %ebp
f0100a64:	89 e5                	mov    %esp,%ebp
f0100a66:	57                   	push   %edi
f0100a67:	56                   	push   %esi
f0100a68:	53                   	push   %ebx
f0100a69:	83 ec 3c             	sub    $0x3c,%esp
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100a6c:	85 c0                	test   %eax,%eax
f0100a6e:	0f 85 35 03 00 00    	jne    f0100da9 <check_page_free_list+0x346>
f0100a74:	e9 42 03 00 00       	jmp    f0100dbb <check_page_free_list+0x358>
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
		panic("'page_free_list' is a null pointer!");
f0100a79:	c7 44 24 08 f4 4e 10 	movl   $0xf0104ef4,0x8(%esp)
f0100a80:	f0 
f0100a81:	c7 44 24 04 5f 02 00 	movl   $0x25f,0x4(%esp)
f0100a88:	00 
f0100a89:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0100a90:	e8 29 f6 ff ff       	call   f01000be <_panic>

	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
f0100a95:	8d 55 d8             	lea    -0x28(%ebp),%edx
f0100a98:	89 55 e0             	mov    %edx,-0x20(%ebp)
f0100a9b:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100a9e:	89 55 e4             	mov    %edx,-0x1c(%ebp)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100aa1:	89 c2                	mov    %eax,%edx
f0100aa3:	2b 15 cc cf 17 f0    	sub    0xf017cfcc,%edx
		for (pp = page_free_list; pp; pp = pp->pp_link) {
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
f0100aa9:	f7 c2 00 e0 7f 00    	test   $0x7fe000,%edx
f0100aaf:	0f 95 c2             	setne  %dl
f0100ab2:	0f b6 d2             	movzbl %dl,%edx
			*tp[pagetype] = pp;
f0100ab5:	8b 4c 95 e0          	mov    -0x20(%ebp,%edx,4),%ecx
f0100ab9:	89 01                	mov    %eax,(%ecx)
			tp[pagetype] = &pp->pp_link;
f0100abb:	89 44 95 e0          	mov    %eax,-0x20(%ebp,%edx,4)
	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
		for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100abf:	8b 00                	mov    (%eax),%eax
f0100ac1:	85 c0                	test   %eax,%eax
f0100ac3:	75 dc                	jne    f0100aa1 <check_page_free_list+0x3e>
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
			*tp[pagetype] = pp;
			tp[pagetype] = &pp->pp_link;
		}
		*tp[1] = 0;
f0100ac5:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100ac8:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		*tp[0] = pp2;
f0100ace:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100ad1:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100ad4:	89 10                	mov    %edx,(%eax)
		page_free_list = pp1;
f0100ad6:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100ad9:	a3 fc c2 17 f0       	mov    %eax,0xf017c2fc
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100ade:	89 c3                	mov    %eax,%ebx
f0100ae0:	85 c0                	test   %eax,%eax
f0100ae2:	74 6c                	je     f0100b50 <check_page_free_list+0xed>
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100ae4:	be 01 00 00 00       	mov    $0x1,%esi
f0100ae9:	89 d8                	mov    %ebx,%eax
f0100aeb:	2b 05 cc cf 17 f0    	sub    0xf017cfcc,%eax
f0100af1:	c1 f8 03             	sar    $0x3,%eax
f0100af4:	c1 e0 0c             	shl    $0xc,%eax
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
f0100af7:	89 c2                	mov    %eax,%edx
f0100af9:	c1 ea 16             	shr    $0x16,%edx
f0100afc:	39 f2                	cmp    %esi,%edx
f0100afe:	73 4a                	jae    f0100b4a <check_page_free_list+0xe7>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100b00:	89 c2                	mov    %eax,%edx
f0100b02:	c1 ea 0c             	shr    $0xc,%edx
f0100b05:	3b 15 c4 cf 17 f0    	cmp    0xf017cfc4,%edx
f0100b0b:	72 20                	jb     f0100b2d <check_page_free_list+0xca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100b0d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100b11:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f0100b18:	f0 
f0100b19:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100b20:	00 
f0100b21:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f0100b28:	e8 91 f5 ff ff       	call   f01000be <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100b2d:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100b34:	00 
f0100b35:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100b3c:	00 
	return (void *)(pa + KERNBASE);
f0100b3d:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100b42:	89 04 24             	mov    %eax,(%esp)
f0100b45:	e8 0f 39 00 00       	call   f0104459 <memset>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100b4a:	8b 1b                	mov    (%ebx),%ebx
f0100b4c:	85 db                	test   %ebx,%ebx
f0100b4e:	75 99                	jne    f0100ae9 <check_page_free_list+0x86>
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
f0100b50:	b8 00 00 00 00       	mov    $0x0,%eax
f0100b55:	e8 36 fe ff ff       	call   f0100990 <boot_alloc>
f0100b5a:	89 45 cc             	mov    %eax,-0x34(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100b5d:	8b 15 fc c2 17 f0    	mov    0xf017c2fc,%edx
f0100b63:	85 d2                	test   %edx,%edx
f0100b65:	0f 84 f2 01 00 00    	je     f0100d5d <check_page_free_list+0x2fa>
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100b6b:	8b 1d cc cf 17 f0    	mov    0xf017cfcc,%ebx
f0100b71:	39 da                	cmp    %ebx,%edx
f0100b73:	72 3f                	jb     f0100bb4 <check_page_free_list+0x151>
		assert(pp < pages + npages);
f0100b75:	a1 c4 cf 17 f0       	mov    0xf017cfc4,%eax
f0100b7a:	89 45 c8             	mov    %eax,-0x38(%ebp)
f0100b7d:	8d 04 c3             	lea    (%ebx,%eax,8),%eax
f0100b80:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100b83:	39 c2                	cmp    %eax,%edx
f0100b85:	73 56                	jae    f0100bdd <check_page_free_list+0x17a>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100b87:	89 5d d0             	mov    %ebx,-0x30(%ebp)
f0100b8a:	89 d0                	mov    %edx,%eax
f0100b8c:	29 d8                	sub    %ebx,%eax
f0100b8e:	a8 07                	test   $0x7,%al
f0100b90:	75 78                	jne    f0100c0a <check_page_free_list+0x1a7>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100b92:	c1 f8 03             	sar    $0x3,%eax
f0100b95:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100b98:	85 c0                	test   %eax,%eax
f0100b9a:	0f 84 98 00 00 00    	je     f0100c38 <check_page_free_list+0x1d5>
		assert(page2pa(pp) != IOPHYSMEM);
f0100ba0:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100ba5:	0f 85 dc 00 00 00    	jne    f0100c87 <check_page_free_list+0x224>
f0100bab:	e9 b3 00 00 00       	jmp    f0100c63 <check_page_free_list+0x200>
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100bb0:	39 d3                	cmp    %edx,%ebx
f0100bb2:	76 24                	jbe    f0100bd8 <check_page_free_list+0x175>
f0100bb4:	c7 44 24 0c 03 56 10 	movl   $0xf0105603,0xc(%esp)
f0100bbb:	f0 
f0100bbc:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0100bc3:	f0 
f0100bc4:	c7 44 24 04 79 02 00 	movl   $0x279,0x4(%esp)
f0100bcb:	00 
f0100bcc:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0100bd3:	e8 e6 f4 ff ff       	call   f01000be <_panic>
		assert(pp < pages + npages);
f0100bd8:	3b 55 d4             	cmp    -0x2c(%ebp),%edx
f0100bdb:	72 24                	jb     f0100c01 <check_page_free_list+0x19e>
f0100bdd:	c7 44 24 0c 24 56 10 	movl   $0xf0105624,0xc(%esp)
f0100be4:	f0 
f0100be5:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0100bec:	f0 
f0100bed:	c7 44 24 04 7a 02 00 	movl   $0x27a,0x4(%esp)
f0100bf4:	00 
f0100bf5:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0100bfc:	e8 bd f4 ff ff       	call   f01000be <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100c01:	89 d0                	mov    %edx,%eax
f0100c03:	2b 45 d0             	sub    -0x30(%ebp),%eax
f0100c06:	a8 07                	test   $0x7,%al
f0100c08:	74 24                	je     f0100c2e <check_page_free_list+0x1cb>
f0100c0a:	c7 44 24 0c 18 4f 10 	movl   $0xf0104f18,0xc(%esp)
f0100c11:	f0 
f0100c12:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0100c19:	f0 
f0100c1a:	c7 44 24 04 7b 02 00 	movl   $0x27b,0x4(%esp)
f0100c21:	00 
f0100c22:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0100c29:	e8 90 f4 ff ff       	call   f01000be <_panic>
f0100c2e:	c1 f8 03             	sar    $0x3,%eax
f0100c31:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100c34:	85 c0                	test   %eax,%eax
f0100c36:	75 24                	jne    f0100c5c <check_page_free_list+0x1f9>
f0100c38:	c7 44 24 0c 38 56 10 	movl   $0xf0105638,0xc(%esp)
f0100c3f:	f0 
f0100c40:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0100c47:	f0 
f0100c48:	c7 44 24 04 7e 02 00 	movl   $0x27e,0x4(%esp)
f0100c4f:	00 
f0100c50:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0100c57:	e8 62 f4 ff ff       	call   f01000be <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100c5c:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100c61:	75 2e                	jne    f0100c91 <check_page_free_list+0x22e>
f0100c63:	c7 44 24 0c 49 56 10 	movl   $0xf0105649,0xc(%esp)
f0100c6a:	f0 
f0100c6b:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0100c72:	f0 
f0100c73:	c7 44 24 04 7f 02 00 	movl   $0x27f,0x4(%esp)
f0100c7a:	00 
f0100c7b:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0100c82:	e8 37 f4 ff ff       	call   f01000be <_panic>
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
f0100c87:	be 00 00 00 00       	mov    $0x0,%esi
f0100c8c:	bf 00 00 00 00       	mov    $0x0,%edi
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
f0100c91:	3d 00 f0 0f 00       	cmp    $0xff000,%eax
f0100c96:	75 24                	jne    f0100cbc <check_page_free_list+0x259>
f0100c98:	c7 44 24 0c 4c 4f 10 	movl   $0xf0104f4c,0xc(%esp)
f0100c9f:	f0 
f0100ca0:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0100ca7:	f0 
f0100ca8:	c7 44 24 04 80 02 00 	movl   $0x280,0x4(%esp)
f0100caf:	00 
f0100cb0:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0100cb7:	e8 02 f4 ff ff       	call   f01000be <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100cbc:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100cc1:	75 24                	jne    f0100ce7 <check_page_free_list+0x284>
f0100cc3:	c7 44 24 0c 62 56 10 	movl   $0xf0105662,0xc(%esp)
f0100cca:	f0 
f0100ccb:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0100cd2:	f0 
f0100cd3:	c7 44 24 04 81 02 00 	movl   $0x281,0x4(%esp)
f0100cda:	00 
f0100cdb:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0100ce2:	e8 d7 f3 ff ff       	call   f01000be <_panic>
f0100ce7:	89 c1                	mov    %eax,%ecx
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
f0100ce9:	3d ff ff 0f 00       	cmp    $0xfffff,%eax
f0100cee:	76 57                	jbe    f0100d47 <check_page_free_list+0x2e4>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100cf0:	c1 e8 0c             	shr    $0xc,%eax
f0100cf3:	39 45 c8             	cmp    %eax,-0x38(%ebp)
f0100cf6:	77 20                	ja     f0100d18 <check_page_free_list+0x2b5>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100cf8:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0100cfc:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f0100d03:	f0 
f0100d04:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100d0b:	00 
f0100d0c:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f0100d13:	e8 a6 f3 ff ff       	call   f01000be <_panic>
	return (void *)(pa + KERNBASE);
f0100d18:	81 e9 00 00 00 10    	sub    $0x10000000,%ecx
f0100d1e:	39 4d cc             	cmp    %ecx,-0x34(%ebp)
f0100d21:	76 29                	jbe    f0100d4c <check_page_free_list+0x2e9>
f0100d23:	c7 44 24 0c 70 4f 10 	movl   $0xf0104f70,0xc(%esp)
f0100d2a:	f0 
f0100d2b:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0100d32:	f0 
f0100d33:	c7 44 24 04 82 02 00 	movl   $0x282,0x4(%esp)
f0100d3a:	00 
f0100d3b:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0100d42:	e8 77 f3 ff ff       	call   f01000be <_panic>

		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
f0100d47:	83 c7 01             	add    $0x1,%edi
f0100d4a:	eb 03                	jmp    f0100d4f <check_page_free_list+0x2ec>
		else
			++nfree_extmem;
f0100d4c:	83 c6 01             	add    $0x1,%esi
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100d4f:	8b 12                	mov    (%edx),%edx
f0100d51:	85 d2                	test   %edx,%edx
f0100d53:	0f 85 57 fe ff ff    	jne    f0100bb0 <check_page_free_list+0x14d>
			++nfree_basemem;
		else
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
f0100d59:	85 ff                	test   %edi,%edi
f0100d5b:	7f 24                	jg     f0100d81 <check_page_free_list+0x31e>
f0100d5d:	c7 44 24 0c 7c 56 10 	movl   $0xf010567c,0xc(%esp)
f0100d64:	f0 
f0100d65:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0100d6c:	f0 
f0100d6d:	c7 44 24 04 8a 02 00 	movl   $0x28a,0x4(%esp)
f0100d74:	00 
f0100d75:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0100d7c:	e8 3d f3 ff ff       	call   f01000be <_panic>
	assert(nfree_extmem > 0);
f0100d81:	85 f6                	test   %esi,%esi
f0100d83:	7f 53                	jg     f0100dd8 <check_page_free_list+0x375>
f0100d85:	c7 44 24 0c 8e 56 10 	movl   $0xf010568e,0xc(%esp)
f0100d8c:	f0 
f0100d8d:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0100d94:	f0 
f0100d95:	c7 44 24 04 8b 02 00 	movl   $0x28b,0x4(%esp)
f0100d9c:	00 
f0100d9d:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0100da4:	e8 15 f3 ff ff       	call   f01000be <_panic>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100da9:	a1 fc c2 17 f0       	mov    0xf017c2fc,%eax
f0100dae:	85 c0                	test   %eax,%eax
f0100db0:	0f 85 df fc ff ff    	jne    f0100a95 <check_page_free_list+0x32>
f0100db6:	e9 be fc ff ff       	jmp    f0100a79 <check_page_free_list+0x16>
f0100dbb:	83 3d fc c2 17 f0 00 	cmpl   $0x0,0xf017c2fc
f0100dc2:	0f 84 b1 fc ff ff    	je     f0100a79 <check_page_free_list+0x16>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100dc8:	8b 1d fc c2 17 f0    	mov    0xf017c2fc,%ebx
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100dce:	be 00 04 00 00       	mov    $0x400,%esi
f0100dd3:	e9 11 fd ff ff       	jmp    f0100ae9 <check_page_free_list+0x86>
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
	assert(nfree_extmem > 0);
}
f0100dd8:	83 c4 3c             	add    $0x3c,%esp
f0100ddb:	5b                   	pop    %ebx
f0100ddc:	5e                   	pop    %esi
f0100ddd:	5f                   	pop    %edi
f0100dde:	5d                   	pop    %ebp
f0100ddf:	c3                   	ret    

f0100de0 <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0100de0:	55                   	push   %ebp
f0100de1:	89 e5                	mov    %esp,%ebp
f0100de3:	53                   	push   %ebx
f0100de4:	83 ec 14             	sub    $0x14,%esp
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100de7:	83 3d c4 cf 17 f0 00 	cmpl   $0x0,0xf017cfc4
f0100dee:	0f 84 a5 00 00 00    	je     f0100e99 <page_init+0xb9>
f0100df4:	8b 1d fc c2 17 f0    	mov    0xf017c2fc,%ebx
f0100dfa:	b8 00 00 00 00       	mov    $0x0,%eax
f0100dff:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
		pages[i].pp_ref = 0;
f0100e06:	89 d1                	mov    %edx,%ecx
f0100e08:	03 0d cc cf 17 f0    	add    0xf017cfcc,%ecx
f0100e0e:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0100e14:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f0100e16:	03 15 cc cf 17 f0    	add    0xf017cfcc,%edx
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100e1c:	83 c0 01             	add    $0x1,%eax
f0100e1f:	8b 0d c4 cf 17 f0    	mov    0xf017cfc4,%ecx
f0100e25:	39 c1                	cmp    %eax,%ecx
f0100e27:	76 04                	jbe    f0100e2d <page_init+0x4d>
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f0100e29:	89 d3                	mov    %edx,%ebx
f0100e2b:	eb d2                	jmp    f0100dff <page_init+0x1f>
f0100e2d:	89 15 fc c2 17 f0    	mov    %edx,0xf017c2fc
	}

	//remove physical page 0 from page_free_list
             pages[1].pp_link = NULL;
f0100e33:	a1 cc cf 17 f0       	mov    0xf017cfcc,%eax
f0100e38:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100e3f:	81 f9 a0 00 00 00    	cmp    $0xa0,%ecx
f0100e45:	77 1c                	ja     f0100e63 <page_init+0x83>
		panic("pa2page called with invalid pa");
f0100e47:	c7 44 24 08 b8 4f 10 	movl   $0xf0104fb8,0x8(%esp)
f0100e4e:	f0 
f0100e4f:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0100e56:	00 
f0100e57:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f0100e5e:	e8 5b f2 ff ff       	call   f01000be <_panic>

              //remove continuous pages from page_free_list
              extern char end[];                        //this is an *virtual* address
              struct Page *ppg_start = pa2page((physaddr_t)IOPHYSMEM);                                                //at low *physical* address
              struct Page *ppg_end = pa2page((physaddr_t)((end - KERNBASE) + PGSIZE + sizeof(struct Page)*npages));    //at high *physical* address
f0100e63:	8d 14 cd d0 df 17 00 	lea    0x17dfd0(,%ecx,8),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100e6a:	c1 ea 0c             	shr    $0xc,%edx
f0100e6d:	39 d1                	cmp    %edx,%ecx
f0100e6f:	77 1c                	ja     f0100e8d <page_init+0xad>
		panic("pa2page called with invalid pa");
f0100e71:	c7 44 24 08 b8 4f 10 	movl   $0xf0104fb8,0x8(%esp)
f0100e78:	f0 
f0100e79:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0100e80:	00 
f0100e81:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f0100e88:	e8 31 f2 ff ff       	call   f01000be <_panic>

              //test output
             //cprintf(">>  ppg_start: %x\tppg_end: %x\n", (int)ppg_start, (int)ppg_end);

               ppg_start--;    ppg_end++;
f0100e8d:	8d 88 f8 04 00 00    	lea    0x4f8(%eax),%ecx
f0100e93:	89 4c d0 08          	mov    %ecx,0x8(%eax,%edx,8)
f0100e97:	eb 0e                	jmp    f0100ea7 <page_init+0xc7>
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
	}

	//remove physical page 0 from page_free_list
             pages[1].pp_link = NULL;
f0100e99:	a1 cc cf 17 f0       	mov    0xf017cfcc,%eax
f0100e9e:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
f0100ea5:	eb a0                	jmp    f0100e47 <page_init+0x67>
              //test output
             //cprintf(">>  ppg_start: %x\tppg_end: %x\n", (int)ppg_start, (int)ppg_end);

               ppg_start--;    ppg_end++;
               ppg_end->pp_link = ppg_start;
}
f0100ea7:	83 c4 14             	add    $0x14,%esp
f0100eaa:	5b                   	pop    %ebx
f0100eab:	5d                   	pop    %ebp
f0100eac:	c3                   	ret    

f0100ead <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
f0100ead:	55                   	push   %ebp
f0100eae:	89 e5                	mov    %esp,%ebp
f0100eb0:	53                   	push   %ebx
f0100eb1:	83 ec 14             	sub    $0x14,%esp
	//test output
              //cprintf(">>  page_alloc() was called!\n");

             if (page_free_list == NULL)
f0100eb4:	8b 1d fc c2 17 f0    	mov    0xf017c2fc,%ebx
f0100eba:	85 db                	test   %ebx,%ebx
f0100ebc:	74 69                	je     f0100f27 <page_alloc+0x7a>
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
f0100ebe:	8b 03                	mov    (%ebx),%eax
f0100ec0:	a3 fc c2 17 f0       	mov    %eax,0xf017c2fc
    
             if (alloc_flags & ALLOC_ZERO)
                    memset(page2kva(result), 0, PGSIZE);
        
             return result;
f0100ec5:	89 d8                	mov    %ebx,%eax
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
    
             if (alloc_flags & ALLOC_ZERO)
f0100ec7:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f0100ecb:	74 5f                	je     f0100f2c <page_alloc+0x7f>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100ecd:	2b 05 cc cf 17 f0    	sub    0xf017cfcc,%eax
f0100ed3:	c1 f8 03             	sar    $0x3,%eax
f0100ed6:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100ed9:	89 c2                	mov    %eax,%edx
f0100edb:	c1 ea 0c             	shr    $0xc,%edx
f0100ede:	3b 15 c4 cf 17 f0    	cmp    0xf017cfc4,%edx
f0100ee4:	72 20                	jb     f0100f06 <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100ee6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100eea:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f0100ef1:	f0 
f0100ef2:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100ef9:	00 
f0100efa:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f0100f01:	e8 b8 f1 ff ff       	call   f01000be <_panic>
                    memset(page2kva(result), 0, PGSIZE);
f0100f06:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0100f0d:	00 
f0100f0e:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0100f15:	00 
	return (void *)(pa + KERNBASE);
f0100f16:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100f1b:	89 04 24             	mov    %eax,(%esp)
f0100f1e:	e8 36 35 00 00       	call   f0104459 <memset>
        
             return result;
f0100f23:	89 d8                	mov    %ebx,%eax
f0100f25:	eb 05                	jmp    f0100f2c <page_alloc+0x7f>
{
	//test output
              //cprintf(">>  page_alloc() was called!\n");

             if (page_free_list == NULL)
                             return NULL;
f0100f27:	b8 00 00 00 00       	mov    $0x0,%eax
    
             if (alloc_flags & ALLOC_ZERO)
                    memset(page2kva(result), 0, PGSIZE);
        
             return result;
}
f0100f2c:	83 c4 14             	add    $0x14,%esp
f0100f2f:	5b                   	pop    %ebx
f0100f30:	5d                   	pop    %ebp
f0100f31:	c3                   	ret    

f0100f32 <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct Page *pp)
{
f0100f32:	55                   	push   %ebp
f0100f33:	89 e5                	mov    %esp,%ebp
f0100f35:	8b 45 08             	mov    0x8(%ebp),%eax
	pp->pp_link = page_free_list;
f0100f38:	8b 15 fc c2 17 f0    	mov    0xf017c2fc,%edx
f0100f3e:	89 10                	mov    %edx,(%eax)
              page_free_list = pp;
f0100f40:	a3 fc c2 17 f0       	mov    %eax,0xf017c2fc
	// Fill this function in
}
f0100f45:	5d                   	pop    %ebp
f0100f46:	c3                   	ret    

f0100f47 <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct Page* pp)
{
f0100f47:	55                   	push   %ebp
f0100f48:	89 e5                	mov    %esp,%ebp
f0100f4a:	83 ec 04             	sub    $0x4,%esp
f0100f4d:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f0100f50:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f0100f54:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0100f57:	66 89 50 04          	mov    %dx,0x4(%eax)
f0100f5b:	66 85 d2             	test   %dx,%dx
f0100f5e:	75 08                	jne    f0100f68 <page_decref+0x21>
		page_free(pp);
f0100f60:	89 04 24             	mov    %eax,(%esp)
f0100f63:	e8 ca ff ff ff       	call   f0100f32 <page_free>
}
f0100f68:	c9                   	leave  
f0100f69:	c3                   	ret    

f0100f6a <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f0100f6a:	55                   	push   %ebp
f0100f6b:	89 e5                	mov    %esp,%ebp
f0100f6d:	56                   	push   %esi
f0100f6e:	53                   	push   %ebx
f0100f6f:	83 ec 10             	sub    $0x10,%esp
f0100f72:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	// Fill this function in
	//test output
              //cprintf(">>  pgdir_walk() was called!\n");

             pte_t *result;
            if (pgdir[PDX(va)] == (pte_t)NULL) {            //yet to create
f0100f75:	89 de                	mov    %ebx,%esi
f0100f77:	c1 ee 16             	shr    $0x16,%esi
f0100f7a:	c1 e6 02             	shl    $0x2,%esi
f0100f7d:	03 75 08             	add    0x8(%ebp),%esi
f0100f80:	8b 06                	mov    (%esi),%eax
f0100f82:	85 c0                	test   %eax,%eax
f0100f84:	75 76                	jne    f0100ffc <pgdir_walk+0x92>
                      if (create == 0)
f0100f86:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f0100f8a:	0f 84 d1 00 00 00    	je     f0101061 <pgdir_walk+0xf7>
                                        return NULL;
                     else {
                                        struct Page *tmp = page_alloc(ALLOC_ZERO);
f0100f90:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0100f97:	e8 11 ff ff ff       	call   f0100ead <page_alloc>
                                        if (tmp == NULL)
f0100f9c:	85 c0                	test   %eax,%eax
f0100f9e:	0f 84 c4 00 00 00    	je     f0101068 <pgdir_walk+0xfe>
                                                  return NULL;                        //failed to alloc
                                        else {
                                                  tmp->pp_ref++;
f0100fa4:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100fa9:	89 c2                	mov    %eax,%edx
f0100fab:	2b 15 cc cf 17 f0    	sub    0xf017cfcc,%edx
f0100fb1:	c1 fa 03             	sar    $0x3,%edx
f0100fb4:	c1 e2 0c             	shl    $0xc,%edx
                                                  pgdir[PDX(va)] = page2pa(tmp) | PTE_P | PTE_W |PTE_U;    //save the physical address of newly allocated page in page dir
f0100fb7:	83 ca 07             	or     $0x7,%edx
f0100fba:	89 16                	mov    %edx,(%esi)
f0100fbc:	2b 05 cc cf 17 f0    	sub    0xf017cfcc,%eax
f0100fc2:	c1 f8 03             	sar    $0x3,%eax
f0100fc5:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100fc8:	89 c2                	mov    %eax,%edx
f0100fca:	c1 ea 0c             	shr    $0xc,%edx
f0100fcd:	3b 15 c4 cf 17 f0    	cmp    0xf017cfc4,%edx
f0100fd3:	72 20                	jb     f0100ff5 <pgdir_walk+0x8b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100fd5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100fd9:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f0100fe0:	f0 
f0100fe1:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100fe8:	00 
f0100fe9:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f0100ff0:	e8 c9 f0 ff ff       	call   f01000be <_panic>
	return (void *)(pa + KERNBASE);
f0100ff5:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100ffa:	eb 58                	jmp    f0101054 <pgdir_walk+0xea>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100ffc:	c1 e8 0c             	shr    $0xc,%eax
f0100fff:	8b 15 c4 cf 17 f0    	mov    0xf017cfc4,%edx
f0101005:	39 d0                	cmp    %edx,%eax
f0101007:	72 1c                	jb     f0101025 <pgdir_walk+0xbb>
		panic("pa2page called with invalid pa");
f0101009:	c7 44 24 08 b8 4f 10 	movl   $0xf0104fb8,0x8(%esp)
f0101010:	f0 
f0101011:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101018:	00 
f0101019:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f0101020:	e8 99 f0 ff ff       	call   f01000be <_panic>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101025:	89 c1                	mov    %eax,%ecx
f0101027:	c1 e1 0c             	shl    $0xc,%ecx
f010102a:	39 d0                	cmp    %edx,%eax
f010102c:	72 20                	jb     f010104e <pgdir_walk+0xe4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010102e:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0101032:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f0101039:	f0 
f010103a:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101041:	00 
f0101042:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f0101049:	e8 70 f0 ff ff       	call   f01000be <_panic>
	return (void *)(pa + KERNBASE);
f010104e:	8d 81 00 00 00 f0    	lea    -0x10000000(%ecx),%eax
                                  }
                 }
               else                        
               result = page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
        
               return &result[PTX(va)];
f0101054:	c1 eb 0a             	shr    $0xa,%ebx
f0101057:	81 e3 fc 0f 00 00    	and    $0xffc,%ebx
f010105d:	01 d8                	add    %ebx,%eax
f010105f:	eb 0c                	jmp    f010106d <pgdir_walk+0x103>
              //cprintf(">>  pgdir_walk() was called!\n");

             pte_t *result;
            if (pgdir[PDX(va)] == (pte_t)NULL) {            //yet to create
                      if (create == 0)
                                        return NULL;
f0101061:	b8 00 00 00 00       	mov    $0x0,%eax
f0101066:	eb 05                	jmp    f010106d <pgdir_walk+0x103>
                     else {
                                        struct Page *tmp = page_alloc(ALLOC_ZERO);
                                        if (tmp == NULL)
                                                  return NULL;                        //failed to alloc
f0101068:	b8 00 00 00 00       	mov    $0x0,%eax
                 }
               else                        
               result = page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
        
               return &result[PTX(va)];
}
f010106d:	83 c4 10             	add    $0x10,%esp
f0101070:	5b                   	pop    %ebx
f0101071:	5e                   	pop    %esi
f0101072:	5d                   	pop    %ebp
f0101073:	c3                   	ret    

f0101074 <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f0101074:	55                   	push   %ebp
f0101075:	89 e5                	mov    %esp,%ebp
f0101077:	53                   	push   %ebx
f0101078:	83 ec 14             	sub    $0x14,%esp
f010107b:	8b 5d 10             	mov    0x10(%ebp),%ebx
	// Fill this function in
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
f010107e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101085:	00 
f0101086:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101089:	89 44 24 04          	mov    %eax,0x4(%esp)
f010108d:	8b 45 08             	mov    0x8(%ebp),%eax
f0101090:	89 04 24             	mov    %eax,(%esp)
f0101093:	e8 d2 fe ff ff       	call   f0100f6a <pgdir_walk>
              if (pte == NULL)
f0101098:	85 c0                	test   %eax,%eax
f010109a:	74 3a                	je     f01010d6 <page_lookup+0x62>
                       return NULL;

             if (pte_store != 0)
f010109c:	85 db                	test   %ebx,%ebx
f010109e:	74 02                	je     f01010a2 <page_lookup+0x2e>
                     *pte_store = pte;
f01010a0:	89 03                	mov    %eax,(%ebx)

             return pa2page(PTE_ADDR(pte[0]));
f01010a2:	8b 00                	mov    (%eax),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01010a4:	c1 e8 0c             	shr    $0xc,%eax
f01010a7:	3b 05 c4 cf 17 f0    	cmp    0xf017cfc4,%eax
f01010ad:	72 1c                	jb     f01010cb <page_lookup+0x57>
		panic("pa2page called with invalid pa");
f01010af:	c7 44 24 08 b8 4f 10 	movl   $0xf0104fb8,0x8(%esp)
f01010b6:	f0 
f01010b7:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01010be:	00 
f01010bf:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f01010c6:	e8 f3 ef ff ff       	call   f01000be <_panic>
	return &pages[PGNUM(pa)];
f01010cb:	8b 15 cc cf 17 f0    	mov    0xf017cfcc,%edx
f01010d1:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01010d4:	eb 05                	jmp    f01010db <page_lookup+0x67>
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
              if (pte == NULL)
                       return NULL;
f01010d6:	b8 00 00 00 00       	mov    $0x0,%eax

             if (pte_store != 0)
                     *pte_store = pte;

             return pa2page(PTE_ADDR(pte[0]));
}
f01010db:	83 c4 14             	add    $0x14,%esp
f01010de:	5b                   	pop    %ebx
f01010df:	5d                   	pop    %ebp
f01010e0:	c3                   	ret    

f01010e1 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f01010e1:	55                   	push   %ebp
f01010e2:	89 e5                	mov    %esp,%ebp
f01010e4:	53                   	push   %ebx
f01010e5:	83 ec 24             	sub    $0x24,%esp
f01010e8:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	// Fill this function in
	//test output
               //cprintf(">>  page_remove() was called!\n");
    
              pte_t *pte;
              struct Page *page = page_lookup(pgdir, va, &pte);
f01010eb:	8d 45 f4             	lea    -0xc(%ebp),%eax
f01010ee:	89 44 24 08          	mov    %eax,0x8(%esp)
f01010f2:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01010f6:	8b 45 08             	mov    0x8(%ebp),%eax
f01010f9:	89 04 24             	mov    %eax,(%esp)
f01010fc:	e8 73 ff ff ff       	call   f0101074 <page_lookup>
    
              if (page != NULL)
f0101101:	85 c0                	test   %eax,%eax
f0101103:	74 08                	je     f010110d <page_remove+0x2c>
                         page_decref(page);
f0101105:	89 04 24             	mov    %eax,(%esp)
f0101108:	e8 3a fe ff ff       	call   f0100f47 <page_decref>
        
              pte[0] = 0;
f010110d:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101110:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f0101116:	0f 01 3b             	invlpg (%ebx)
              tlb_invalidate(pgdir, va);
}
f0101119:	83 c4 24             	add    $0x24,%esp
f010111c:	5b                   	pop    %ebx
f010111d:	5d                   	pop    %ebp
f010111e:	c3                   	ret    

f010111f <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
{
f010111f:	55                   	push   %ebp
f0101120:	89 e5                	mov    %esp,%ebp
f0101122:	57                   	push   %edi
f0101123:	56                   	push   %esi
f0101124:	53                   	push   %ebx
f0101125:	83 ec 1c             	sub    $0x1c,%esp
f0101128:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010112b:	8b 75 10             	mov    0x10(%ebp),%esi
	// Fill this function in
	//test output
                                //cprintf(">>  page_insert() was called!\n");
    
               struct Page *page = page_lookup(pgdir, va, NULL);
f010112e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101135:	00 
f0101136:	89 74 24 04          	mov    %esi,0x4(%esp)
f010113a:	8b 45 08             	mov    0x8(%ebp),%eax
f010113d:	89 04 24             	mov    %eax,(%esp)
f0101140:	e8 2f ff ff ff       	call   f0101074 <page_lookup>
f0101145:	89 c7                	mov    %eax,%edi
               pte_t *pte;
    
              if (page == pp) {                       //re-insert into the same place
f0101147:	39 d8                	cmp    %ebx,%eax
f0101149:	75 36                	jne    f0101181 <page_insert+0x62>
                            pte = pgdir_walk(pgdir, va, 0);
f010114b:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101152:	00 
f0101153:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101157:	8b 45 08             	mov    0x8(%ebp),%eax
f010115a:	89 04 24             	mov    %eax,(%esp)
f010115d:	e8 08 fe ff ff       	call   f0100f6a <pgdir_walk>
                            pte[0] = page2pa(pp) | perm | PTE_P;
f0101162:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0101165:	83 c9 01             	or     $0x1,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101168:	2b 3d cc cf 17 f0    	sub    0xf017cfcc,%edi
f010116e:	c1 ff 03             	sar    $0x3,%edi
f0101171:	c1 e7 0c             	shl    $0xc,%edi
f0101174:	89 fa                	mov    %edi,%edx
f0101176:	09 ca                	or     %ecx,%edx
f0101178:	89 10                	mov    %edx,(%eax)
                            return 0;
f010117a:	b8 00 00 00 00       	mov    $0x0,%eax
f010117f:	eb 57                	jmp    f01011d8 <page_insert+0xb9>
                          }
    
               if (page != NULL)                       //remove original page if existed
f0101181:	85 c0                	test   %eax,%eax
f0101183:	74 0f                	je     f0101194 <page_insert+0x75>
                        page_remove(pgdir, va);
f0101185:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101189:	8b 45 08             	mov    0x8(%ebp),%eax
f010118c:	89 04 24             	mov    %eax,(%esp)
f010118f:	e8 4d ff ff ff       	call   f01010e1 <page_remove>
        
              pte = pgdir_walk(pgdir, va, 1);
f0101194:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010119b:	00 
f010119c:	89 74 24 04          	mov    %esi,0x4(%esp)
f01011a0:	8b 45 08             	mov    0x8(%ebp),%eax
f01011a3:	89 04 24             	mov    %eax,(%esp)
f01011a6:	e8 bf fd ff ff       	call   f0100f6a <pgdir_walk>
              if (pte == NULL)
f01011ab:	85 c0                	test   %eax,%eax
f01011ad:	74 24                	je     f01011d3 <page_insert+0xb4>
                       return -E_NO_MEM;

              pte[0] = page2pa(pp) | perm | PTE_P;
f01011af:	8b 4d 14             	mov    0x14(%ebp),%ecx
f01011b2:	83 c9 01             	or     $0x1,%ecx
f01011b5:	89 da                	mov    %ebx,%edx
f01011b7:	2b 15 cc cf 17 f0    	sub    0xf017cfcc,%edx
f01011bd:	c1 fa 03             	sar    $0x3,%edx
f01011c0:	c1 e2 0c             	shl    $0xc,%edx
f01011c3:	09 ca                	or     %ecx,%edx
f01011c5:	89 10                	mov    %edx,(%eax)
               pp->pp_ref++;
f01011c7:	66 83 43 04 01       	addw   $0x1,0x4(%ebx)

	return 0; 
f01011cc:	b8 00 00 00 00       	mov    $0x0,%eax
f01011d1:	eb 05                	jmp    f01011d8 <page_insert+0xb9>
               if (page != NULL)                       //remove original page if existed
                        page_remove(pgdir, va);
        
              pte = pgdir_walk(pgdir, va, 1);
              if (pte == NULL)
                       return -E_NO_MEM;
f01011d3:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax

              pte[0] = page2pa(pp) | perm | PTE_P;
               pp->pp_ref++;

	return 0; 
}
f01011d8:	83 c4 1c             	add    $0x1c,%esp
f01011db:	5b                   	pop    %ebx
f01011dc:	5e                   	pop    %esi
f01011dd:	5f                   	pop    %edi
f01011de:	5d                   	pop    %ebp
f01011df:	c3                   	ret    

f01011e0 <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f01011e0:	55                   	push   %ebp
f01011e1:	89 e5                	mov    %esp,%ebp
f01011e3:	57                   	push   %edi
f01011e4:	56                   	push   %esi
f01011e5:	53                   	push   %ebx
f01011e6:	83 ec 3c             	sub    $0x3c,%esp
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01011e9:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f01011f0:	e8 d5 21 00 00       	call   f01033ca <mc146818_read>
f01011f5:	89 c3                	mov    %eax,%ebx
f01011f7:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f01011fe:	e8 c7 21 00 00       	call   f01033ca <mc146818_read>
f0101203:	c1 e0 08             	shl    $0x8,%eax
f0101206:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f0101208:	89 d8                	mov    %ebx,%eax
f010120a:	c1 e0 0a             	shl    $0xa,%eax
f010120d:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0101213:	85 c0                	test   %eax,%eax
f0101215:	0f 48 c2             	cmovs  %edx,%eax
f0101218:	c1 f8 0c             	sar    $0xc,%eax
f010121b:	a3 00 c3 17 f0       	mov    %eax,0xf017c300
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0101220:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f0101227:	e8 9e 21 00 00       	call   f01033ca <mc146818_read>
f010122c:	89 c3                	mov    %eax,%ebx
f010122e:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f0101235:	e8 90 21 00 00       	call   f01033ca <mc146818_read>
f010123a:	c1 e0 08             	shl    $0x8,%eax
f010123d:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f010123f:	89 d8                	mov    %ebx,%eax
f0101241:	c1 e0 0a             	shl    $0xa,%eax
f0101244:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f010124a:	85 c0                	test   %eax,%eax
f010124c:	0f 48 c2             	cmovs  %edx,%eax
f010124f:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f0101252:	85 c0                	test   %eax,%eax
f0101254:	74 0e                	je     f0101264 <mem_init+0x84>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f0101256:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f010125c:	89 15 c4 cf 17 f0    	mov    %edx,0xf017cfc4
f0101262:	eb 0c                	jmp    f0101270 <mem_init+0x90>
	else
		npages = npages_basemem;
f0101264:	8b 15 00 c3 17 f0    	mov    0xf017c300,%edx
f010126a:	89 15 c4 cf 17 f0    	mov    %edx,0xf017cfc4

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f0101270:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101273:	c1 e8 0a             	shr    $0xa,%eax
f0101276:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f010127a:	a1 00 c3 17 f0       	mov    0xf017c300,%eax
f010127f:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101282:	c1 e8 0a             	shr    $0xa,%eax
f0101285:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f0101289:	a1 c4 cf 17 f0       	mov    0xf017cfc4,%eax
f010128e:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101291:	c1 e8 0a             	shr    $0xa,%eax
f0101294:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101298:	c7 04 24 d8 4f 10 f0 	movl   $0xf0104fd8,(%esp)
f010129f:	e8 96 21 00 00       	call   f010343a <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);  // first_level pagedir
f01012a4:	b8 00 10 00 00       	mov    $0x1000,%eax
f01012a9:	e8 e2 f6 ff ff       	call   f0100990 <boot_alloc>
f01012ae:	a3 c8 cf 17 f0       	mov    %eax,0xf017cfc8
	memset(kern_pgdir, 0, PGSIZE);
f01012b3:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01012ba:	00 
f01012bb:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01012c2:	00 
f01012c3:	89 04 24             	mov    %eax,(%esp)
f01012c6:	e8 8e 31 00 00       	call   f0104459 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f01012cb:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01012d0:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01012d5:	77 20                	ja     f01012f7 <mem_init+0x117>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01012d7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01012db:	c7 44 24 08 14 50 10 	movl   $0xf0105014,0x8(%esp)
f01012e2:	f0 
f01012e3:	c7 44 24 04 94 00 00 	movl   $0x94,0x4(%esp)
f01012ea:	00 
f01012eb:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01012f2:	e8 c7 ed ff ff       	call   f01000be <_panic>
	return (physaddr_t)kva - KERNBASE;
f01012f7:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f01012fd:	83 ca 05             	or     $0x5,%edx
f0101300:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct Page in this
	// array.  'npages' is the number of physical pages in memory.
	// Your code goes here:

	pages = (struct Page *)boot_alloc(npages * sizeof(struct Page)); // allocate npages to record all physical pages in memort using condition
f0101306:	a1 c4 cf 17 f0       	mov    0xf017cfc4,%eax
f010130b:	c1 e0 03             	shl    $0x3,%eax
f010130e:	e8 7d f6 ff ff       	call   f0100990 <boot_alloc>
f0101313:	a3 cc cf 17 f0       	mov    %eax,0xf017cfcc
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f0101318:	e8 c3 fa ff ff       	call   f0100de0 <page_init>

	check_page_free_list(1);
f010131d:	b8 01 00 00 00       	mov    $0x1,%eax
f0101322:	e8 3c f7 ff ff       	call   f0100a63 <check_page_free_list>
	int nfree;
	struct Page *fl;
	char *c;
	int i;

	if (!pages)
f0101327:	83 3d cc cf 17 f0 00 	cmpl   $0x0,0xf017cfcc
f010132e:	75 1c                	jne    f010134c <mem_init+0x16c>
		panic("'pages' is a null pointer!");
f0101330:	c7 44 24 08 9f 56 10 	movl   $0xf010569f,0x8(%esp)
f0101337:	f0 
f0101338:	c7 44 24 04 9c 02 00 	movl   $0x29c,0x4(%esp)
f010133f:	00 
f0101340:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101347:	e8 72 ed ff ff       	call   f01000be <_panic>

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010134c:	a1 fc c2 17 f0       	mov    0xf017c2fc,%eax
f0101351:	85 c0                	test   %eax,%eax
f0101353:	74 10                	je     f0101365 <mem_init+0x185>
f0101355:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;
f010135a:	83 c3 01             	add    $0x1,%ebx

	if (!pages)
		panic("'pages' is a null pointer!");

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010135d:	8b 00                	mov    (%eax),%eax
f010135f:	85 c0                	test   %eax,%eax
f0101361:	75 f7                	jne    f010135a <mem_init+0x17a>
f0101363:	eb 05                	jmp    f010136a <mem_init+0x18a>
f0101365:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f010136a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101371:	e8 37 fb ff ff       	call   f0100ead <page_alloc>
f0101376:	89 c7                	mov    %eax,%edi
f0101378:	85 c0                	test   %eax,%eax
f010137a:	75 24                	jne    f01013a0 <mem_init+0x1c0>
f010137c:	c7 44 24 0c ba 56 10 	movl   $0xf01056ba,0xc(%esp)
f0101383:	f0 
f0101384:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f010138b:	f0 
f010138c:	c7 44 24 04 a4 02 00 	movl   $0x2a4,0x4(%esp)
f0101393:	00 
f0101394:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010139b:	e8 1e ed ff ff       	call   f01000be <_panic>
	assert((pp1 = page_alloc(0)));
f01013a0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01013a7:	e8 01 fb ff ff       	call   f0100ead <page_alloc>
f01013ac:	89 c6                	mov    %eax,%esi
f01013ae:	85 c0                	test   %eax,%eax
f01013b0:	75 24                	jne    f01013d6 <mem_init+0x1f6>
f01013b2:	c7 44 24 0c d0 56 10 	movl   $0xf01056d0,0xc(%esp)
f01013b9:	f0 
f01013ba:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01013c1:	f0 
f01013c2:	c7 44 24 04 a5 02 00 	movl   $0x2a5,0x4(%esp)
f01013c9:	00 
f01013ca:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01013d1:	e8 e8 ec ff ff       	call   f01000be <_panic>
	assert((pp2 = page_alloc(0)));
f01013d6:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01013dd:	e8 cb fa ff ff       	call   f0100ead <page_alloc>
f01013e2:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01013e5:	85 c0                	test   %eax,%eax
f01013e7:	75 24                	jne    f010140d <mem_init+0x22d>
f01013e9:	c7 44 24 0c e6 56 10 	movl   $0xf01056e6,0xc(%esp)
f01013f0:	f0 
f01013f1:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01013f8:	f0 
f01013f9:	c7 44 24 04 a6 02 00 	movl   $0x2a6,0x4(%esp)
f0101400:	00 
f0101401:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101408:	e8 b1 ec ff ff       	call   f01000be <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f010140d:	39 f7                	cmp    %esi,%edi
f010140f:	75 24                	jne    f0101435 <mem_init+0x255>
f0101411:	c7 44 24 0c fc 56 10 	movl   $0xf01056fc,0xc(%esp)
f0101418:	f0 
f0101419:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101420:	f0 
f0101421:	c7 44 24 04 a9 02 00 	movl   $0x2a9,0x4(%esp)
f0101428:	00 
f0101429:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101430:	e8 89 ec ff ff       	call   f01000be <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101435:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101438:	39 c6                	cmp    %eax,%esi
f010143a:	74 04                	je     f0101440 <mem_init+0x260>
f010143c:	39 c7                	cmp    %eax,%edi
f010143e:	75 24                	jne    f0101464 <mem_init+0x284>
f0101440:	c7 44 24 0c 38 50 10 	movl   $0xf0105038,0xc(%esp)
f0101447:	f0 
f0101448:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f010144f:	f0 
f0101450:	c7 44 24 04 aa 02 00 	movl   $0x2aa,0x4(%esp)
f0101457:	00 
f0101458:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010145f:	e8 5a ec ff ff       	call   f01000be <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101464:	8b 15 cc cf 17 f0    	mov    0xf017cfcc,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f010146a:	a1 c4 cf 17 f0       	mov    0xf017cfc4,%eax
f010146f:	c1 e0 0c             	shl    $0xc,%eax
f0101472:	89 f9                	mov    %edi,%ecx
f0101474:	29 d1                	sub    %edx,%ecx
f0101476:	c1 f9 03             	sar    $0x3,%ecx
f0101479:	c1 e1 0c             	shl    $0xc,%ecx
f010147c:	39 c1                	cmp    %eax,%ecx
f010147e:	72 24                	jb     f01014a4 <mem_init+0x2c4>
f0101480:	c7 44 24 0c 0e 57 10 	movl   $0xf010570e,0xc(%esp)
f0101487:	f0 
f0101488:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f010148f:	f0 
f0101490:	c7 44 24 04 ab 02 00 	movl   $0x2ab,0x4(%esp)
f0101497:	00 
f0101498:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010149f:	e8 1a ec ff ff       	call   f01000be <_panic>
f01014a4:	89 f1                	mov    %esi,%ecx
f01014a6:	29 d1                	sub    %edx,%ecx
f01014a8:	c1 f9 03             	sar    $0x3,%ecx
f01014ab:	c1 e1 0c             	shl    $0xc,%ecx
	assert(page2pa(pp1) < npages*PGSIZE);
f01014ae:	39 c8                	cmp    %ecx,%eax
f01014b0:	77 24                	ja     f01014d6 <mem_init+0x2f6>
f01014b2:	c7 44 24 0c 2b 57 10 	movl   $0xf010572b,0xc(%esp)
f01014b9:	f0 
f01014ba:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01014c1:	f0 
f01014c2:	c7 44 24 04 ac 02 00 	movl   $0x2ac,0x4(%esp)
f01014c9:	00 
f01014ca:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01014d1:	e8 e8 eb ff ff       	call   f01000be <_panic>
f01014d6:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01014d9:	29 d1                	sub    %edx,%ecx
f01014db:	89 ca                	mov    %ecx,%edx
f01014dd:	c1 fa 03             	sar    $0x3,%edx
f01014e0:	c1 e2 0c             	shl    $0xc,%edx
	assert(page2pa(pp2) < npages*PGSIZE);
f01014e3:	39 d0                	cmp    %edx,%eax
f01014e5:	77 24                	ja     f010150b <mem_init+0x32b>
f01014e7:	c7 44 24 0c 48 57 10 	movl   $0xf0105748,0xc(%esp)
f01014ee:	f0 
f01014ef:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01014f6:	f0 
f01014f7:	c7 44 24 04 ad 02 00 	movl   $0x2ad,0x4(%esp)
f01014fe:	00 
f01014ff:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101506:	e8 b3 eb ff ff       	call   f01000be <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f010150b:	a1 fc c2 17 f0       	mov    0xf017c2fc,%eax
f0101510:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101513:	c7 05 fc c2 17 f0 00 	movl   $0x0,0xf017c2fc
f010151a:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f010151d:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101524:	e8 84 f9 ff ff       	call   f0100ead <page_alloc>
f0101529:	85 c0                	test   %eax,%eax
f010152b:	74 24                	je     f0101551 <mem_init+0x371>
f010152d:	c7 44 24 0c 65 57 10 	movl   $0xf0105765,0xc(%esp)
f0101534:	f0 
f0101535:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f010153c:	f0 
f010153d:	c7 44 24 04 b4 02 00 	movl   $0x2b4,0x4(%esp)
f0101544:	00 
f0101545:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010154c:	e8 6d eb ff ff       	call   f01000be <_panic>

	// free and re-allocate?
	page_free(pp0);
f0101551:	89 3c 24             	mov    %edi,(%esp)
f0101554:	e8 d9 f9 ff ff       	call   f0100f32 <page_free>
	page_free(pp1);
f0101559:	89 34 24             	mov    %esi,(%esp)
f010155c:	e8 d1 f9 ff ff       	call   f0100f32 <page_free>
	page_free(pp2);
f0101561:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101564:	89 04 24             	mov    %eax,(%esp)
f0101567:	e8 c6 f9 ff ff       	call   f0100f32 <page_free>
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f010156c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101573:	e8 35 f9 ff ff       	call   f0100ead <page_alloc>
f0101578:	89 c6                	mov    %eax,%esi
f010157a:	85 c0                	test   %eax,%eax
f010157c:	75 24                	jne    f01015a2 <mem_init+0x3c2>
f010157e:	c7 44 24 0c ba 56 10 	movl   $0xf01056ba,0xc(%esp)
f0101585:	f0 
f0101586:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f010158d:	f0 
f010158e:	c7 44 24 04 bb 02 00 	movl   $0x2bb,0x4(%esp)
f0101595:	00 
f0101596:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010159d:	e8 1c eb ff ff       	call   f01000be <_panic>
	assert((pp1 = page_alloc(0)));
f01015a2:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01015a9:	e8 ff f8 ff ff       	call   f0100ead <page_alloc>
f01015ae:	89 c7                	mov    %eax,%edi
f01015b0:	85 c0                	test   %eax,%eax
f01015b2:	75 24                	jne    f01015d8 <mem_init+0x3f8>
f01015b4:	c7 44 24 0c d0 56 10 	movl   $0xf01056d0,0xc(%esp)
f01015bb:	f0 
f01015bc:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01015c3:	f0 
f01015c4:	c7 44 24 04 bc 02 00 	movl   $0x2bc,0x4(%esp)
f01015cb:	00 
f01015cc:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01015d3:	e8 e6 ea ff ff       	call   f01000be <_panic>
	assert((pp2 = page_alloc(0)));
f01015d8:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01015df:	e8 c9 f8 ff ff       	call   f0100ead <page_alloc>
f01015e4:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01015e7:	85 c0                	test   %eax,%eax
f01015e9:	75 24                	jne    f010160f <mem_init+0x42f>
f01015eb:	c7 44 24 0c e6 56 10 	movl   $0xf01056e6,0xc(%esp)
f01015f2:	f0 
f01015f3:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01015fa:	f0 
f01015fb:	c7 44 24 04 bd 02 00 	movl   $0x2bd,0x4(%esp)
f0101602:	00 
f0101603:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010160a:	e8 af ea ff ff       	call   f01000be <_panic>
	assert(pp0);
	assert(pp1 && pp1 != pp0);
f010160f:	39 fe                	cmp    %edi,%esi
f0101611:	75 24                	jne    f0101637 <mem_init+0x457>
f0101613:	c7 44 24 0c fc 56 10 	movl   $0xf01056fc,0xc(%esp)
f010161a:	f0 
f010161b:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101622:	f0 
f0101623:	c7 44 24 04 bf 02 00 	movl   $0x2bf,0x4(%esp)
f010162a:	00 
f010162b:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101632:	e8 87 ea ff ff       	call   f01000be <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101637:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010163a:	39 c7                	cmp    %eax,%edi
f010163c:	74 04                	je     f0101642 <mem_init+0x462>
f010163e:	39 c6                	cmp    %eax,%esi
f0101640:	75 24                	jne    f0101666 <mem_init+0x486>
f0101642:	c7 44 24 0c 38 50 10 	movl   $0xf0105038,0xc(%esp)
f0101649:	f0 
f010164a:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101651:	f0 
f0101652:	c7 44 24 04 c0 02 00 	movl   $0x2c0,0x4(%esp)
f0101659:	00 
f010165a:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101661:	e8 58 ea ff ff       	call   f01000be <_panic>
	assert(!page_alloc(0));
f0101666:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010166d:	e8 3b f8 ff ff       	call   f0100ead <page_alloc>
f0101672:	85 c0                	test   %eax,%eax
f0101674:	74 24                	je     f010169a <mem_init+0x4ba>
f0101676:	c7 44 24 0c 65 57 10 	movl   $0xf0105765,0xc(%esp)
f010167d:	f0 
f010167e:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101685:	f0 
f0101686:	c7 44 24 04 c1 02 00 	movl   $0x2c1,0x4(%esp)
f010168d:	00 
f010168e:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101695:	e8 24 ea ff ff       	call   f01000be <_panic>
f010169a:	89 f0                	mov    %esi,%eax
f010169c:	2b 05 cc cf 17 f0    	sub    0xf017cfcc,%eax
f01016a2:	c1 f8 03             	sar    $0x3,%eax
f01016a5:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01016a8:	89 c2                	mov    %eax,%edx
f01016aa:	c1 ea 0c             	shr    $0xc,%edx
f01016ad:	3b 15 c4 cf 17 f0    	cmp    0xf017cfc4,%edx
f01016b3:	72 20                	jb     f01016d5 <mem_init+0x4f5>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01016b5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01016b9:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f01016c0:	f0 
f01016c1:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01016c8:	00 
f01016c9:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f01016d0:	e8 e9 e9 ff ff       	call   f01000be <_panic>

	// test flags
	memset(page2kva(pp0), 1, PGSIZE);
f01016d5:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01016dc:	00 
f01016dd:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f01016e4:	00 
	return (void *)(pa + KERNBASE);
f01016e5:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01016ea:	89 04 24             	mov    %eax,(%esp)
f01016ed:	e8 67 2d 00 00       	call   f0104459 <memset>
	page_free(pp0);
f01016f2:	89 34 24             	mov    %esi,(%esp)
f01016f5:	e8 38 f8 ff ff       	call   f0100f32 <page_free>
	assert((pp = page_alloc(ALLOC_ZERO)));
f01016fa:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101701:	e8 a7 f7 ff ff       	call   f0100ead <page_alloc>
f0101706:	85 c0                	test   %eax,%eax
f0101708:	75 24                	jne    f010172e <mem_init+0x54e>
f010170a:	c7 44 24 0c 74 57 10 	movl   $0xf0105774,0xc(%esp)
f0101711:	f0 
f0101712:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101719:	f0 
f010171a:	c7 44 24 04 c6 02 00 	movl   $0x2c6,0x4(%esp)
f0101721:	00 
f0101722:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101729:	e8 90 e9 ff ff       	call   f01000be <_panic>
	assert(pp && pp0 == pp);
f010172e:	39 c6                	cmp    %eax,%esi
f0101730:	74 24                	je     f0101756 <mem_init+0x576>
f0101732:	c7 44 24 0c 92 57 10 	movl   $0xf0105792,0xc(%esp)
f0101739:	f0 
f010173a:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101741:	f0 
f0101742:	c7 44 24 04 c7 02 00 	movl   $0x2c7,0x4(%esp)
f0101749:	00 
f010174a:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101751:	e8 68 e9 ff ff       	call   f01000be <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101756:	89 f2                	mov    %esi,%edx
f0101758:	2b 15 cc cf 17 f0    	sub    0xf017cfcc,%edx
f010175e:	c1 fa 03             	sar    $0x3,%edx
f0101761:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101764:	89 d0                	mov    %edx,%eax
f0101766:	c1 e8 0c             	shr    $0xc,%eax
f0101769:	3b 05 c4 cf 17 f0    	cmp    0xf017cfc4,%eax
f010176f:	72 20                	jb     f0101791 <mem_init+0x5b1>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101771:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101775:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f010177c:	f0 
f010177d:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101784:	00 
f0101785:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f010178c:	e8 2d e9 ff ff       	call   f01000be <_panic>
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
		assert(c[i] == 0);
f0101791:	80 ba 00 00 00 f0 00 	cmpb   $0x0,-0x10000000(%edx)
f0101798:	75 11                	jne    f01017ab <mem_init+0x5cb>
f010179a:	8d 82 01 00 00 f0    	lea    -0xfffffff(%edx),%eax
f01017a0:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f01017a6:	80 38 00             	cmpb   $0x0,(%eax)
f01017a9:	74 24                	je     f01017cf <mem_init+0x5ef>
f01017ab:	c7 44 24 0c a2 57 10 	movl   $0xf01057a2,0xc(%esp)
f01017b2:	f0 
f01017b3:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01017ba:	f0 
f01017bb:	c7 44 24 04 ca 02 00 	movl   $0x2ca,0x4(%esp)
f01017c2:	00 
f01017c3:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01017ca:	e8 ef e8 ff ff       	call   f01000be <_panic>
f01017cf:	83 c0 01             	add    $0x1,%eax
	memset(page2kva(pp0), 1, PGSIZE);
	page_free(pp0);
	assert((pp = page_alloc(ALLOC_ZERO)));
	assert(pp && pp0 == pp);
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
f01017d2:	39 d0                	cmp    %edx,%eax
f01017d4:	75 d0                	jne    f01017a6 <mem_init+0x5c6>
		assert(c[i] == 0);

	// give free list back
	page_free_list = fl;
f01017d6:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01017d9:	a3 fc c2 17 f0       	mov    %eax,0xf017c2fc

	// free the pages we took
	page_free(pp0);
f01017de:	89 34 24             	mov    %esi,(%esp)
f01017e1:	e8 4c f7 ff ff       	call   f0100f32 <page_free>
	page_free(pp1);
f01017e6:	89 3c 24             	mov    %edi,(%esp)
f01017e9:	e8 44 f7 ff ff       	call   f0100f32 <page_free>
	page_free(pp2);
f01017ee:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01017f1:	89 04 24             	mov    %eax,(%esp)
f01017f4:	e8 39 f7 ff ff       	call   f0100f32 <page_free>

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f01017f9:	a1 fc c2 17 f0       	mov    0xf017c2fc,%eax
f01017fe:	85 c0                	test   %eax,%eax
f0101800:	74 09                	je     f010180b <mem_init+0x62b>
		--nfree;
f0101802:	83 eb 01             	sub    $0x1,%ebx
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101805:	8b 00                	mov    (%eax),%eax
f0101807:	85 c0                	test   %eax,%eax
f0101809:	75 f7                	jne    f0101802 <mem_init+0x622>
		--nfree;
	assert(nfree == 0);
f010180b:	85 db                	test   %ebx,%ebx
f010180d:	74 24                	je     f0101833 <mem_init+0x653>
f010180f:	c7 44 24 0c ac 57 10 	movl   $0xf01057ac,0xc(%esp)
f0101816:	f0 
f0101817:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f010181e:	f0 
f010181f:	c7 44 24 04 d7 02 00 	movl   $0x2d7,0x4(%esp)
f0101826:	00 
f0101827:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010182e:	e8 8b e8 ff ff       	call   f01000be <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f0101833:	c7 04 24 58 50 10 f0 	movl   $0xf0105058,(%esp)
f010183a:	e8 fb 1b 00 00       	call   f010343a <cprintf>
	int i;
	extern pde_t entry_pgdir[];

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f010183f:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101846:	e8 62 f6 ff ff       	call   f0100ead <page_alloc>
f010184b:	89 c3                	mov    %eax,%ebx
f010184d:	85 c0                	test   %eax,%eax
f010184f:	75 24                	jne    f0101875 <mem_init+0x695>
f0101851:	c7 44 24 0c ba 56 10 	movl   $0xf01056ba,0xc(%esp)
f0101858:	f0 
f0101859:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101860:	f0 
f0101861:	c7 44 24 04 35 03 00 	movl   $0x335,0x4(%esp)
f0101868:	00 
f0101869:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101870:	e8 49 e8 ff ff       	call   f01000be <_panic>
	assert((pp1 = page_alloc(0)));
f0101875:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010187c:	e8 2c f6 ff ff       	call   f0100ead <page_alloc>
f0101881:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0101884:	85 c0                	test   %eax,%eax
f0101886:	75 24                	jne    f01018ac <mem_init+0x6cc>
f0101888:	c7 44 24 0c d0 56 10 	movl   $0xf01056d0,0xc(%esp)
f010188f:	f0 
f0101890:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101897:	f0 
f0101898:	c7 44 24 04 36 03 00 	movl   $0x336,0x4(%esp)
f010189f:	00 
f01018a0:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01018a7:	e8 12 e8 ff ff       	call   f01000be <_panic>
	assert((pp2 = page_alloc(0)));
f01018ac:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018b3:	e8 f5 f5 ff ff       	call   f0100ead <page_alloc>
f01018b8:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01018bb:	85 c0                	test   %eax,%eax
f01018bd:	75 24                	jne    f01018e3 <mem_init+0x703>
f01018bf:	c7 44 24 0c e6 56 10 	movl   $0xf01056e6,0xc(%esp)
f01018c6:	f0 
f01018c7:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01018ce:	f0 
f01018cf:	c7 44 24 04 37 03 00 	movl   $0x337,0x4(%esp)
f01018d6:	00 
f01018d7:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01018de:	e8 db e7 ff ff       	call   f01000be <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f01018e3:	3b 5d d0             	cmp    -0x30(%ebp),%ebx
f01018e6:	75 24                	jne    f010190c <mem_init+0x72c>
f01018e8:	c7 44 24 0c fc 56 10 	movl   $0xf01056fc,0xc(%esp)
f01018ef:	f0 
f01018f0:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01018f7:	f0 
f01018f8:	c7 44 24 04 3a 03 00 	movl   $0x33a,0x4(%esp)
f01018ff:	00 
f0101900:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101907:	e8 b2 e7 ff ff       	call   f01000be <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f010190c:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010190f:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0101912:	74 04                	je     f0101918 <mem_init+0x738>
f0101914:	39 c3                	cmp    %eax,%ebx
f0101916:	75 24                	jne    f010193c <mem_init+0x75c>
f0101918:	c7 44 24 0c 38 50 10 	movl   $0xf0105038,0xc(%esp)
f010191f:	f0 
f0101920:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101927:	f0 
f0101928:	c7 44 24 04 3b 03 00 	movl   $0x33b,0x4(%esp)
f010192f:	00 
f0101930:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101937:	e8 82 e7 ff ff       	call   f01000be <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f010193c:	a1 fc c2 17 f0       	mov    0xf017c2fc,%eax
f0101941:	89 45 cc             	mov    %eax,-0x34(%ebp)
	page_free_list = 0;
f0101944:	c7 05 fc c2 17 f0 00 	movl   $0x0,0xf017c2fc
f010194b:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f010194e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101955:	e8 53 f5 ff ff       	call   f0100ead <page_alloc>
f010195a:	85 c0                	test   %eax,%eax
f010195c:	74 24                	je     f0101982 <mem_init+0x7a2>
f010195e:	c7 44 24 0c 65 57 10 	movl   $0xf0105765,0xc(%esp)
f0101965:	f0 
f0101966:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f010196d:	f0 
f010196e:	c7 44 24 04 42 03 00 	movl   $0x342,0x4(%esp)
f0101975:	00 
f0101976:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010197d:	e8 3c e7 ff ff       	call   f01000be <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f0101982:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101985:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101989:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101990:	00 
f0101991:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0101996:	89 04 24             	mov    %eax,(%esp)
f0101999:	e8 d6 f6 ff ff       	call   f0101074 <page_lookup>
f010199e:	85 c0                	test   %eax,%eax
f01019a0:	74 24                	je     f01019c6 <mem_init+0x7e6>
f01019a2:	c7 44 24 0c 78 50 10 	movl   $0xf0105078,0xc(%esp)
f01019a9:	f0 
f01019aa:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01019b1:	f0 
f01019b2:	c7 44 24 04 45 03 00 	movl   $0x345,0x4(%esp)
f01019b9:	00 
f01019ba:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01019c1:	e8 f8 e6 ff ff       	call   f01000be <_panic>

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);
f01019c6:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01019cd:	00 
f01019ce:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01019d5:	00 
f01019d6:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01019d9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01019dd:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f01019e2:	89 04 24             	mov    %eax,(%esp)
f01019e5:	e8 35 f7 ff ff       	call   f010111f <page_insert>
f01019ea:	85 c0                	test   %eax,%eax
f01019ec:	78 24                	js     f0101a12 <mem_init+0x832>
f01019ee:	c7 44 24 0c b0 50 10 	movl   $0xf01050b0,0xc(%esp)
f01019f5:	f0 
f01019f6:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01019fd:	f0 
f01019fe:	c7 44 24 04 48 03 00 	movl   $0x348,0x4(%esp)
f0101a05:	00 
f0101a06:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101a0d:	e8 ac e6 ff ff       	call   f01000be <_panic>

	// free pp0 and try again: pp0 should be used for page table
	page_free(pp0);
f0101a12:	89 1c 24             	mov    %ebx,(%esp)
f0101a15:	e8 18 f5 ff ff       	call   f0100f32 <page_free>
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) == 0);
f0101a1a:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101a21:	00 
f0101a22:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101a29:	00 
f0101a2a:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101a2d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101a31:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0101a36:	89 04 24             	mov    %eax,(%esp)
f0101a39:	e8 e1 f6 ff ff       	call   f010111f <page_insert>
f0101a3e:	85 c0                	test   %eax,%eax
f0101a40:	74 24                	je     f0101a66 <mem_init+0x886>
f0101a42:	c7 44 24 0c e0 50 10 	movl   $0xf01050e0,0xc(%esp)
f0101a49:	f0 
f0101a4a:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101a51:	f0 
f0101a52:	c7 44 24 04 4c 03 00 	movl   $0x34c,0x4(%esp)
f0101a59:	00 
f0101a5a:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101a61:	e8 58 e6 ff ff       	call   f01000be <_panic>
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101a66:	8b 35 c8 cf 17 f0    	mov    0xf017cfc8,%esi
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101a6c:	8b 3d cc cf 17 f0    	mov    0xf017cfcc,%edi
f0101a72:	8b 16                	mov    (%esi),%edx
f0101a74:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0101a7a:	89 d8                	mov    %ebx,%eax
f0101a7c:	29 f8                	sub    %edi,%eax
f0101a7e:	c1 f8 03             	sar    $0x3,%eax
f0101a81:	c1 e0 0c             	shl    $0xc,%eax
f0101a84:	39 c2                	cmp    %eax,%edx
f0101a86:	74 24                	je     f0101aac <mem_init+0x8cc>
f0101a88:	c7 44 24 0c 10 51 10 	movl   $0xf0105110,0xc(%esp)
f0101a8f:	f0 
f0101a90:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101a97:	f0 
f0101a98:	c7 44 24 04 4d 03 00 	movl   $0x34d,0x4(%esp)
f0101a9f:	00 
f0101aa0:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101aa7:	e8 12 e6 ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, 0x0) == page2pa(pp1));
f0101aac:	ba 00 00 00 00       	mov    $0x0,%edx
f0101ab1:	89 f0                	mov    %esi,%eax
f0101ab3:	e8 3c ef ff ff       	call   f01009f4 <check_va2pa>
f0101ab8:	8b 55 d0             	mov    -0x30(%ebp),%edx
f0101abb:	29 fa                	sub    %edi,%edx
f0101abd:	c1 fa 03             	sar    $0x3,%edx
f0101ac0:	c1 e2 0c             	shl    $0xc,%edx
f0101ac3:	39 d0                	cmp    %edx,%eax
f0101ac5:	74 24                	je     f0101aeb <mem_init+0x90b>
f0101ac7:	c7 44 24 0c 38 51 10 	movl   $0xf0105138,0xc(%esp)
f0101ace:	f0 
f0101acf:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101ad6:	f0 
f0101ad7:	c7 44 24 04 4e 03 00 	movl   $0x34e,0x4(%esp)
f0101ade:	00 
f0101adf:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101ae6:	e8 d3 e5 ff ff       	call   f01000be <_panic>
	assert(pp1->pp_ref == 1);
f0101aeb:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101aee:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101af3:	74 24                	je     f0101b19 <mem_init+0x939>
f0101af5:	c7 44 24 0c b7 57 10 	movl   $0xf01057b7,0xc(%esp)
f0101afc:	f0 
f0101afd:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101b04:	f0 
f0101b05:	c7 44 24 04 4f 03 00 	movl   $0x34f,0x4(%esp)
f0101b0c:	00 
f0101b0d:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101b14:	e8 a5 e5 ff ff       	call   f01000be <_panic>
	assert(pp0->pp_ref == 1);
f0101b19:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0101b1e:	74 24                	je     f0101b44 <mem_init+0x964>
f0101b20:	c7 44 24 0c c8 57 10 	movl   $0xf01057c8,0xc(%esp)
f0101b27:	f0 
f0101b28:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101b2f:	f0 
f0101b30:	c7 44 24 04 50 03 00 	movl   $0x350,0x4(%esp)
f0101b37:	00 
f0101b38:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101b3f:	e8 7a e5 ff ff       	call   f01000be <_panic>

	// should be able to map pp2 at PGSIZE because pp0 is already allocated for page table
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101b44:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101b4b:	00 
f0101b4c:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101b53:	00 
f0101b54:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101b57:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101b5b:	89 34 24             	mov    %esi,(%esp)
f0101b5e:	e8 bc f5 ff ff       	call   f010111f <page_insert>
f0101b63:	85 c0                	test   %eax,%eax
f0101b65:	74 24                	je     f0101b8b <mem_init+0x9ab>
f0101b67:	c7 44 24 0c 68 51 10 	movl   $0xf0105168,0xc(%esp)
f0101b6e:	f0 
f0101b6f:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101b76:	f0 
f0101b77:	c7 44 24 04 53 03 00 	movl   $0x353,0x4(%esp)
f0101b7e:	00 
f0101b7f:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101b86:	e8 33 e5 ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101b8b:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101b90:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0101b95:	e8 5a ee ff ff       	call   f01009f4 <check_va2pa>
f0101b9a:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101b9d:	2b 15 cc cf 17 f0    	sub    0xf017cfcc,%edx
f0101ba3:	c1 fa 03             	sar    $0x3,%edx
f0101ba6:	c1 e2 0c             	shl    $0xc,%edx
f0101ba9:	39 d0                	cmp    %edx,%eax
f0101bab:	74 24                	je     f0101bd1 <mem_init+0x9f1>
f0101bad:	c7 44 24 0c a4 51 10 	movl   $0xf01051a4,0xc(%esp)
f0101bb4:	f0 
f0101bb5:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101bbc:	f0 
f0101bbd:	c7 44 24 04 54 03 00 	movl   $0x354,0x4(%esp)
f0101bc4:	00 
f0101bc5:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101bcc:	e8 ed e4 ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 1);
f0101bd1:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101bd4:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101bd9:	74 24                	je     f0101bff <mem_init+0xa1f>
f0101bdb:	c7 44 24 0c d9 57 10 	movl   $0xf01057d9,0xc(%esp)
f0101be2:	f0 
f0101be3:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101bea:	f0 
f0101beb:	c7 44 24 04 55 03 00 	movl   $0x355,0x4(%esp)
f0101bf2:	00 
f0101bf3:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101bfa:	e8 bf e4 ff ff       	call   f01000be <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0101bff:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101c06:	e8 a2 f2 ff ff       	call   f0100ead <page_alloc>
f0101c0b:	85 c0                	test   %eax,%eax
f0101c0d:	74 24                	je     f0101c33 <mem_init+0xa53>
f0101c0f:	c7 44 24 0c 65 57 10 	movl   $0xf0105765,0xc(%esp)
f0101c16:	f0 
f0101c17:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101c1e:	f0 
f0101c1f:	c7 44 24 04 58 03 00 	movl   $0x358,0x4(%esp)
f0101c26:	00 
f0101c27:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101c2e:	e8 8b e4 ff ff       	call   f01000be <_panic>

	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101c33:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101c3a:	00 
f0101c3b:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101c42:	00 
f0101c43:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101c46:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101c4a:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0101c4f:	89 04 24             	mov    %eax,(%esp)
f0101c52:	e8 c8 f4 ff ff       	call   f010111f <page_insert>
f0101c57:	85 c0                	test   %eax,%eax
f0101c59:	74 24                	je     f0101c7f <mem_init+0xa9f>
f0101c5b:	c7 44 24 0c 68 51 10 	movl   $0xf0105168,0xc(%esp)
f0101c62:	f0 
f0101c63:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101c6a:	f0 
f0101c6b:	c7 44 24 04 5b 03 00 	movl   $0x35b,0x4(%esp)
f0101c72:	00 
f0101c73:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101c7a:	e8 3f e4 ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101c7f:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101c84:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0101c89:	e8 66 ed ff ff       	call   f01009f4 <check_va2pa>
f0101c8e:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101c91:	2b 15 cc cf 17 f0    	sub    0xf017cfcc,%edx
f0101c97:	c1 fa 03             	sar    $0x3,%edx
f0101c9a:	c1 e2 0c             	shl    $0xc,%edx
f0101c9d:	39 d0                	cmp    %edx,%eax
f0101c9f:	74 24                	je     f0101cc5 <mem_init+0xae5>
f0101ca1:	c7 44 24 0c a4 51 10 	movl   $0xf01051a4,0xc(%esp)
f0101ca8:	f0 
f0101ca9:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101cb0:	f0 
f0101cb1:	c7 44 24 04 5c 03 00 	movl   $0x35c,0x4(%esp)
f0101cb8:	00 
f0101cb9:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101cc0:	e8 f9 e3 ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 1);
f0101cc5:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101cc8:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101ccd:	74 24                	je     f0101cf3 <mem_init+0xb13>
f0101ccf:	c7 44 24 0c d9 57 10 	movl   $0xf01057d9,0xc(%esp)
f0101cd6:	f0 
f0101cd7:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101cde:	f0 
f0101cdf:	c7 44 24 04 5d 03 00 	movl   $0x35d,0x4(%esp)
f0101ce6:	00 
f0101ce7:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101cee:	e8 cb e3 ff ff       	call   f01000be <_panic>

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));
f0101cf3:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101cfa:	e8 ae f1 ff ff       	call   f0100ead <page_alloc>
f0101cff:	85 c0                	test   %eax,%eax
f0101d01:	74 24                	je     f0101d27 <mem_init+0xb47>
f0101d03:	c7 44 24 0c 65 57 10 	movl   $0xf0105765,0xc(%esp)
f0101d0a:	f0 
f0101d0b:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101d12:	f0 
f0101d13:	c7 44 24 04 61 03 00 	movl   $0x361,0x4(%esp)
f0101d1a:	00 
f0101d1b:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101d22:	e8 97 e3 ff ff       	call   f01000be <_panic>

	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f0101d27:	8b 15 c8 cf 17 f0    	mov    0xf017cfc8,%edx
f0101d2d:	8b 02                	mov    (%edx),%eax
f0101d2f:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101d34:	89 c1                	mov    %eax,%ecx
f0101d36:	c1 e9 0c             	shr    $0xc,%ecx
f0101d39:	3b 0d c4 cf 17 f0    	cmp    0xf017cfc4,%ecx
f0101d3f:	72 20                	jb     f0101d61 <mem_init+0xb81>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101d41:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101d45:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f0101d4c:	f0 
f0101d4d:	c7 44 24 04 64 03 00 	movl   $0x364,0x4(%esp)
f0101d54:	00 
f0101d55:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101d5c:	e8 5d e3 ff ff       	call   f01000be <_panic>
	return (void *)(pa + KERNBASE);
f0101d61:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101d66:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	assert(pgdir_walk(kern_pgdir, (void*)PGSIZE, 0) == ptep+PTX(PGSIZE));
f0101d69:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101d70:	00 
f0101d71:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0101d78:	00 
f0101d79:	89 14 24             	mov    %edx,(%esp)
f0101d7c:	e8 e9 f1 ff ff       	call   f0100f6a <pgdir_walk>
f0101d81:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0101d84:	8d 51 04             	lea    0x4(%ecx),%edx
f0101d87:	39 d0                	cmp    %edx,%eax
f0101d89:	74 24                	je     f0101daf <mem_init+0xbcf>
f0101d8b:	c7 44 24 0c d4 51 10 	movl   $0xf01051d4,0xc(%esp)
f0101d92:	f0 
f0101d93:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101d9a:	f0 
f0101d9b:	c7 44 24 04 65 03 00 	movl   $0x365,0x4(%esp)
f0101da2:	00 
f0101da3:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101daa:	e8 0f e3 ff ff       	call   f01000be <_panic>

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
f0101daf:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0101db6:	00 
f0101db7:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101dbe:	00 
f0101dbf:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101dc2:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101dc6:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0101dcb:	89 04 24             	mov    %eax,(%esp)
f0101dce:	e8 4c f3 ff ff       	call   f010111f <page_insert>
f0101dd3:	85 c0                	test   %eax,%eax
f0101dd5:	74 24                	je     f0101dfb <mem_init+0xc1b>
f0101dd7:	c7 44 24 0c 14 52 10 	movl   $0xf0105214,0xc(%esp)
f0101dde:	f0 
f0101ddf:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101de6:	f0 
f0101de7:	c7 44 24 04 68 03 00 	movl   $0x368,0x4(%esp)
f0101dee:	00 
f0101def:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101df6:	e8 c3 e2 ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101dfb:	8b 35 c8 cf 17 f0    	mov    0xf017cfc8,%esi
f0101e01:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101e06:	89 f0                	mov    %esi,%eax
f0101e08:	e8 e7 eb ff ff       	call   f01009f4 <check_va2pa>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101e0d:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101e10:	2b 15 cc cf 17 f0    	sub    0xf017cfcc,%edx
f0101e16:	c1 fa 03             	sar    $0x3,%edx
f0101e19:	c1 e2 0c             	shl    $0xc,%edx
f0101e1c:	39 d0                	cmp    %edx,%eax
f0101e1e:	74 24                	je     f0101e44 <mem_init+0xc64>
f0101e20:	c7 44 24 0c a4 51 10 	movl   $0xf01051a4,0xc(%esp)
f0101e27:	f0 
f0101e28:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101e2f:	f0 
f0101e30:	c7 44 24 04 69 03 00 	movl   $0x369,0x4(%esp)
f0101e37:	00 
f0101e38:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101e3f:	e8 7a e2 ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 1);
f0101e44:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101e47:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101e4c:	74 24                	je     f0101e72 <mem_init+0xc92>
f0101e4e:	c7 44 24 0c d9 57 10 	movl   $0xf01057d9,0xc(%esp)
f0101e55:	f0 
f0101e56:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101e5d:	f0 
f0101e5e:	c7 44 24 04 6a 03 00 	movl   $0x36a,0x4(%esp)
f0101e65:	00 
f0101e66:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101e6d:	e8 4c e2 ff ff       	call   f01000be <_panic>
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U);
f0101e72:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101e79:	00 
f0101e7a:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0101e81:	00 
f0101e82:	89 34 24             	mov    %esi,(%esp)
f0101e85:	e8 e0 f0 ff ff       	call   f0100f6a <pgdir_walk>
f0101e8a:	f6 00 04             	testb  $0x4,(%eax)
f0101e8d:	75 24                	jne    f0101eb3 <mem_init+0xcd3>
f0101e8f:	c7 44 24 0c 54 52 10 	movl   $0xf0105254,0xc(%esp)
f0101e96:	f0 
f0101e97:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101e9e:	f0 
f0101e9f:	c7 44 24 04 6b 03 00 	movl   $0x36b,0x4(%esp)
f0101ea6:	00 
f0101ea7:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101eae:	e8 0b e2 ff ff       	call   f01000be <_panic>
	assert(kern_pgdir[0] & PTE_U);
f0101eb3:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0101eb8:	f6 00 04             	testb  $0x4,(%eax)
f0101ebb:	75 24                	jne    f0101ee1 <mem_init+0xd01>
f0101ebd:	c7 44 24 0c ea 57 10 	movl   $0xf01057ea,0xc(%esp)
f0101ec4:	f0 
f0101ec5:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101ecc:	f0 
f0101ecd:	c7 44 24 04 6c 03 00 	movl   $0x36c,0x4(%esp)
f0101ed4:	00 
f0101ed5:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101edc:	e8 dd e1 ff ff       	call   f01000be <_panic>

	// should not be able to map at PTSIZE because need free page for page table
	assert(page_insert(kern_pgdir, pp0, (void*) PTSIZE, PTE_W) < 0);
f0101ee1:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101ee8:	00 
f0101ee9:	c7 44 24 08 00 00 40 	movl   $0x400000,0x8(%esp)
f0101ef0:	00 
f0101ef1:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101ef5:	89 04 24             	mov    %eax,(%esp)
f0101ef8:	e8 22 f2 ff ff       	call   f010111f <page_insert>
f0101efd:	85 c0                	test   %eax,%eax
f0101eff:	78 24                	js     f0101f25 <mem_init+0xd45>
f0101f01:	c7 44 24 0c 88 52 10 	movl   $0xf0105288,0xc(%esp)
f0101f08:	f0 
f0101f09:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101f10:	f0 
f0101f11:	c7 44 24 04 6f 03 00 	movl   $0x36f,0x4(%esp)
f0101f18:	00 
f0101f19:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101f20:	e8 99 e1 ff ff       	call   f01000be <_panic>

	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
f0101f25:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101f2c:	00 
f0101f2d:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101f34:	00 
f0101f35:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101f38:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101f3c:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0101f41:	89 04 24             	mov    %eax,(%esp)
f0101f44:	e8 d6 f1 ff ff       	call   f010111f <page_insert>
f0101f49:	85 c0                	test   %eax,%eax
f0101f4b:	74 24                	je     f0101f71 <mem_init+0xd91>
f0101f4d:	c7 44 24 0c c0 52 10 	movl   $0xf01052c0,0xc(%esp)
f0101f54:	f0 
f0101f55:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101f5c:	f0 
f0101f5d:	c7 44 24 04 72 03 00 	movl   $0x372,0x4(%esp)
f0101f64:	00 
f0101f65:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101f6c:	e8 4d e1 ff ff       	call   f01000be <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f0101f71:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101f78:	00 
f0101f79:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0101f80:	00 
f0101f81:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0101f86:	89 04 24             	mov    %eax,(%esp)
f0101f89:	e8 dc ef ff ff       	call   f0100f6a <pgdir_walk>
f0101f8e:	f6 00 04             	testb  $0x4,(%eax)
f0101f91:	74 24                	je     f0101fb7 <mem_init+0xdd7>
f0101f93:	c7 44 24 0c fc 52 10 	movl   $0xf01052fc,0xc(%esp)
f0101f9a:	f0 
f0101f9b:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101fa2:	f0 
f0101fa3:	c7 44 24 04 73 03 00 	movl   $0x373,0x4(%esp)
f0101faa:	00 
f0101fab:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101fb2:	e8 07 e1 ff ff       	call   f01000be <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f0101fb7:	8b 3d c8 cf 17 f0    	mov    0xf017cfc8,%edi
f0101fbd:	ba 00 00 00 00       	mov    $0x0,%edx
f0101fc2:	89 f8                	mov    %edi,%eax
f0101fc4:	e8 2b ea ff ff       	call   f01009f4 <check_va2pa>
f0101fc9:	89 c6                	mov    %eax,%esi
f0101fcb:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101fce:	2b 05 cc cf 17 f0    	sub    0xf017cfcc,%eax
f0101fd4:	c1 f8 03             	sar    $0x3,%eax
f0101fd7:	c1 e0 0c             	shl    $0xc,%eax
f0101fda:	39 c6                	cmp    %eax,%esi
f0101fdc:	74 24                	je     f0102002 <mem_init+0xe22>
f0101fde:	c7 44 24 0c 34 53 10 	movl   $0xf0105334,0xc(%esp)
f0101fe5:	f0 
f0101fe6:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0101fed:	f0 
f0101fee:	c7 44 24 04 76 03 00 	movl   $0x376,0x4(%esp)
f0101ff5:	00 
f0101ff6:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0101ffd:	e8 bc e0 ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102002:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102007:	89 f8                	mov    %edi,%eax
f0102009:	e8 e6 e9 ff ff       	call   f01009f4 <check_va2pa>
f010200e:	39 c6                	cmp    %eax,%esi
f0102010:	74 24                	je     f0102036 <mem_init+0xe56>
f0102012:	c7 44 24 0c 60 53 10 	movl   $0xf0105360,0xc(%esp)
f0102019:	f0 
f010201a:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102021:	f0 
f0102022:	c7 44 24 04 77 03 00 	movl   $0x377,0x4(%esp)
f0102029:	00 
f010202a:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102031:	e8 88 e0 ff ff       	call   f01000be <_panic>
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
f0102036:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102039:	66 83 78 04 02       	cmpw   $0x2,0x4(%eax)
f010203e:	74 24                	je     f0102064 <mem_init+0xe84>
f0102040:	c7 44 24 0c 00 58 10 	movl   $0xf0105800,0xc(%esp)
f0102047:	f0 
f0102048:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f010204f:	f0 
f0102050:	c7 44 24 04 79 03 00 	movl   $0x379,0x4(%esp)
f0102057:	00 
f0102058:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010205f:	e8 5a e0 ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 0);
f0102064:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102067:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f010206c:	74 24                	je     f0102092 <mem_init+0xeb2>
f010206e:	c7 44 24 0c 11 58 10 	movl   $0xf0105811,0xc(%esp)
f0102075:	f0 
f0102076:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f010207d:	f0 
f010207e:	c7 44 24 04 7a 03 00 	movl   $0x37a,0x4(%esp)
f0102085:	00 
f0102086:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010208d:	e8 2c e0 ff ff       	call   f01000be <_panic>

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);
f0102092:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102099:	e8 0f ee ff ff       	call   f0100ead <page_alloc>
f010209e:	85 c0                	test   %eax,%eax
f01020a0:	74 05                	je     f01020a7 <mem_init+0xec7>
f01020a2:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f01020a5:	74 24                	je     f01020cb <mem_init+0xeeb>
f01020a7:	c7 44 24 0c 90 53 10 	movl   $0xf0105390,0xc(%esp)
f01020ae:	f0 
f01020af:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01020b6:	f0 
f01020b7:	c7 44 24 04 7d 03 00 	movl   $0x37d,0x4(%esp)
f01020be:	00 
f01020bf:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01020c6:	e8 f3 df ff ff       	call   f01000be <_panic>

	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f01020cb:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01020d2:	00 
f01020d3:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f01020d8:	89 04 24             	mov    %eax,(%esp)
f01020db:	e8 01 f0 ff ff       	call   f01010e1 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01020e0:	8b 35 c8 cf 17 f0    	mov    0xf017cfc8,%esi
f01020e6:	ba 00 00 00 00       	mov    $0x0,%edx
f01020eb:	89 f0                	mov    %esi,%eax
f01020ed:	e8 02 e9 ff ff       	call   f01009f4 <check_va2pa>
f01020f2:	83 f8 ff             	cmp    $0xffffffff,%eax
f01020f5:	74 24                	je     f010211b <mem_init+0xf3b>
f01020f7:	c7 44 24 0c b4 53 10 	movl   $0xf01053b4,0xc(%esp)
f01020fe:	f0 
f01020ff:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102106:	f0 
f0102107:	c7 44 24 04 81 03 00 	movl   $0x381,0x4(%esp)
f010210e:	00 
f010210f:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102116:	e8 a3 df ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f010211b:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102120:	89 f0                	mov    %esi,%eax
f0102122:	e8 cd e8 ff ff       	call   f01009f4 <check_va2pa>
f0102127:	8b 55 d0             	mov    -0x30(%ebp),%edx
f010212a:	2b 15 cc cf 17 f0    	sub    0xf017cfcc,%edx
f0102130:	c1 fa 03             	sar    $0x3,%edx
f0102133:	c1 e2 0c             	shl    $0xc,%edx
f0102136:	39 d0                	cmp    %edx,%eax
f0102138:	74 24                	je     f010215e <mem_init+0xf7e>
f010213a:	c7 44 24 0c 60 53 10 	movl   $0xf0105360,0xc(%esp)
f0102141:	f0 
f0102142:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102149:	f0 
f010214a:	c7 44 24 04 82 03 00 	movl   $0x382,0x4(%esp)
f0102151:	00 
f0102152:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102159:	e8 60 df ff ff       	call   f01000be <_panic>
	assert(pp1->pp_ref == 1);
f010215e:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102161:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0102166:	74 24                	je     f010218c <mem_init+0xfac>
f0102168:	c7 44 24 0c b7 57 10 	movl   $0xf01057b7,0xc(%esp)
f010216f:	f0 
f0102170:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102177:	f0 
f0102178:	c7 44 24 04 83 03 00 	movl   $0x383,0x4(%esp)
f010217f:	00 
f0102180:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102187:	e8 32 df ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 0);
f010218c:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010218f:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102194:	74 24                	je     f01021ba <mem_init+0xfda>
f0102196:	c7 44 24 0c 11 58 10 	movl   $0xf0105811,0xc(%esp)
f010219d:	f0 
f010219e:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01021a5:	f0 
f01021a6:	c7 44 24 04 84 03 00 	movl   $0x384,0x4(%esp)
f01021ad:	00 
f01021ae:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01021b5:	e8 04 df ff ff       	call   f01000be <_panic>

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
f01021ba:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01021c1:	00 
f01021c2:	89 34 24             	mov    %esi,(%esp)
f01021c5:	e8 17 ef ff ff       	call   f01010e1 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01021ca:	8b 35 c8 cf 17 f0    	mov    0xf017cfc8,%esi
f01021d0:	ba 00 00 00 00       	mov    $0x0,%edx
f01021d5:	89 f0                	mov    %esi,%eax
f01021d7:	e8 18 e8 ff ff       	call   f01009f4 <check_va2pa>
f01021dc:	83 f8 ff             	cmp    $0xffffffff,%eax
f01021df:	74 24                	je     f0102205 <mem_init+0x1025>
f01021e1:	c7 44 24 0c b4 53 10 	movl   $0xf01053b4,0xc(%esp)
f01021e8:	f0 
f01021e9:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01021f0:	f0 
f01021f1:	c7 44 24 04 88 03 00 	movl   $0x388,0x4(%esp)
f01021f8:	00 
f01021f9:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102200:	e8 b9 de ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
f0102205:	ba 00 10 00 00       	mov    $0x1000,%edx
f010220a:	89 f0                	mov    %esi,%eax
f010220c:	e8 e3 e7 ff ff       	call   f01009f4 <check_va2pa>
f0102211:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102214:	74 24                	je     f010223a <mem_init+0x105a>
f0102216:	c7 44 24 0c d8 53 10 	movl   $0xf01053d8,0xc(%esp)
f010221d:	f0 
f010221e:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102225:	f0 
f0102226:	c7 44 24 04 89 03 00 	movl   $0x389,0x4(%esp)
f010222d:	00 
f010222e:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102235:	e8 84 de ff ff       	call   f01000be <_panic>
	assert(pp1->pp_ref == 0);
f010223a:	8b 45 d0             	mov    -0x30(%ebp),%eax
f010223d:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102242:	74 24                	je     f0102268 <mem_init+0x1088>
f0102244:	c7 44 24 0c 22 58 10 	movl   $0xf0105822,0xc(%esp)
f010224b:	f0 
f010224c:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102253:	f0 
f0102254:	c7 44 24 04 8a 03 00 	movl   $0x38a,0x4(%esp)
f010225b:	00 
f010225c:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102263:	e8 56 de ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 0);
f0102268:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010226b:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102270:	74 24                	je     f0102296 <mem_init+0x10b6>
f0102272:	c7 44 24 0c 11 58 10 	movl   $0xf0105811,0xc(%esp)
f0102279:	f0 
f010227a:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102281:	f0 
f0102282:	c7 44 24 04 8b 03 00 	movl   $0x38b,0x4(%esp)
f0102289:	00 
f010228a:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102291:	e8 28 de ff ff       	call   f01000be <_panic>

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);
f0102296:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010229d:	e8 0b ec ff ff       	call   f0100ead <page_alloc>
f01022a2:	85 c0                	test   %eax,%eax
f01022a4:	74 05                	je     f01022ab <mem_init+0x10cb>
f01022a6:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f01022a9:	74 24                	je     f01022cf <mem_init+0x10ef>
f01022ab:	c7 44 24 0c 00 54 10 	movl   $0xf0105400,0xc(%esp)
f01022b2:	f0 
f01022b3:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01022ba:	f0 
f01022bb:	c7 44 24 04 8e 03 00 	movl   $0x38e,0x4(%esp)
f01022c2:	00 
f01022c3:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01022ca:	e8 ef dd ff ff       	call   f01000be <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f01022cf:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01022d6:	e8 d2 eb ff ff       	call   f0100ead <page_alloc>
f01022db:	85 c0                	test   %eax,%eax
f01022dd:	74 24                	je     f0102303 <mem_init+0x1123>
f01022df:	c7 44 24 0c 65 57 10 	movl   $0xf0105765,0xc(%esp)
f01022e6:	f0 
f01022e7:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01022ee:	f0 
f01022ef:	c7 44 24 04 91 03 00 	movl   $0x391,0x4(%esp)
f01022f6:	00 
f01022f7:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01022fe:	e8 bb dd ff ff       	call   f01000be <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102303:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0102308:	8b 08                	mov    (%eax),%ecx
f010230a:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f0102310:	89 da                	mov    %ebx,%edx
f0102312:	2b 15 cc cf 17 f0    	sub    0xf017cfcc,%edx
f0102318:	c1 fa 03             	sar    $0x3,%edx
f010231b:	c1 e2 0c             	shl    $0xc,%edx
f010231e:	39 d1                	cmp    %edx,%ecx
f0102320:	74 24                	je     f0102346 <mem_init+0x1166>
f0102322:	c7 44 24 0c 10 51 10 	movl   $0xf0105110,0xc(%esp)
f0102329:	f0 
f010232a:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102331:	f0 
f0102332:	c7 44 24 04 94 03 00 	movl   $0x394,0x4(%esp)
f0102339:	00 
f010233a:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102341:	e8 78 dd ff ff       	call   f01000be <_panic>
	kern_pgdir[0] = 0;
f0102346:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f010234c:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102351:	74 24                	je     f0102377 <mem_init+0x1197>
f0102353:	c7 44 24 0c c8 57 10 	movl   $0xf01057c8,0xc(%esp)
f010235a:	f0 
f010235b:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102362:	f0 
f0102363:	c7 44 24 04 96 03 00 	movl   $0x396,0x4(%esp)
f010236a:	00 
f010236b:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102372:	e8 47 dd ff ff       	call   f01000be <_panic>
	pp0->pp_ref = 0;
f0102377:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// check pointer arithmetic in pgdir_walk
	page_free(pp0);
f010237d:	89 1c 24             	mov    %ebx,(%esp)
f0102380:	e8 ad eb ff ff       	call   f0100f32 <page_free>
	va = (void*)(PGSIZE * NPDENTRIES + PGSIZE);
	ptep = pgdir_walk(kern_pgdir, va, 1);
f0102385:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010238c:	00 
f010238d:	c7 44 24 04 00 10 40 	movl   $0x401000,0x4(%esp)
f0102394:	00 
f0102395:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f010239a:	89 04 24             	mov    %eax,(%esp)
f010239d:	e8 c8 eb ff ff       	call   f0100f6a <pgdir_walk>
f01023a2:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f01023a5:	8b 0d c8 cf 17 f0    	mov    0xf017cfc8,%ecx
f01023ab:	8b 51 04             	mov    0x4(%ecx),%edx
f01023ae:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01023b4:	8b 3d c4 cf 17 f0    	mov    0xf017cfc4,%edi
f01023ba:	89 d6                	mov    %edx,%esi
f01023bc:	c1 ee 0c             	shr    $0xc,%esi
f01023bf:	39 fe                	cmp    %edi,%esi
f01023c1:	72 20                	jb     f01023e3 <mem_init+0x1203>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01023c3:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01023c7:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f01023ce:	f0 
f01023cf:	c7 44 24 04 9d 03 00 	movl   $0x39d,0x4(%esp)
f01023d6:	00 
f01023d7:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01023de:	e8 db dc ff ff       	call   f01000be <_panic>
	assert(ptep == ptep1 + PTX(va));
f01023e3:	81 ea fc ff ff 0f    	sub    $0xffffffc,%edx
f01023e9:	39 d0                	cmp    %edx,%eax
f01023eb:	74 24                	je     f0102411 <mem_init+0x1231>
f01023ed:	c7 44 24 0c 33 58 10 	movl   $0xf0105833,0xc(%esp)
f01023f4:	f0 
f01023f5:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01023fc:	f0 
f01023fd:	c7 44 24 04 9e 03 00 	movl   $0x39e,0x4(%esp)
f0102404:	00 
f0102405:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010240c:	e8 ad dc ff ff       	call   f01000be <_panic>
	kern_pgdir[PDX(va)] = 0;
f0102411:	c7 41 04 00 00 00 00 	movl   $0x0,0x4(%ecx)
	pp0->pp_ref = 0;
f0102418:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010241e:	89 d8                	mov    %ebx,%eax
f0102420:	2b 05 cc cf 17 f0    	sub    0xf017cfcc,%eax
f0102426:	c1 f8 03             	sar    $0x3,%eax
f0102429:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010242c:	89 c2                	mov    %eax,%edx
f010242e:	c1 ea 0c             	shr    $0xc,%edx
f0102431:	39 d7                	cmp    %edx,%edi
f0102433:	77 20                	ja     f0102455 <mem_init+0x1275>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102435:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102439:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f0102440:	f0 
f0102441:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102448:	00 
f0102449:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f0102450:	e8 69 dc ff ff       	call   f01000be <_panic>

	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
f0102455:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010245c:	00 
f010245d:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
f0102464:	00 
	return (void *)(pa + KERNBASE);
f0102465:	2d 00 00 00 10       	sub    $0x10000000,%eax
f010246a:	89 04 24             	mov    %eax,(%esp)
f010246d:	e8 e7 1f 00 00       	call   f0104459 <memset>
	page_free(pp0);
f0102472:	89 1c 24             	mov    %ebx,(%esp)
f0102475:	e8 b8 ea ff ff       	call   f0100f32 <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f010247a:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0102481:	00 
f0102482:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0102489:	00 
f010248a:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f010248f:	89 04 24             	mov    %eax,(%esp)
f0102492:	e8 d3 ea ff ff       	call   f0100f6a <pgdir_walk>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102497:	89 da                	mov    %ebx,%edx
f0102499:	2b 15 cc cf 17 f0    	sub    0xf017cfcc,%edx
f010249f:	c1 fa 03             	sar    $0x3,%edx
f01024a2:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01024a5:	89 d0                	mov    %edx,%eax
f01024a7:	c1 e8 0c             	shr    $0xc,%eax
f01024aa:	3b 05 c4 cf 17 f0    	cmp    0xf017cfc4,%eax
f01024b0:	72 20                	jb     f01024d2 <mem_init+0x12f2>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01024b2:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01024b6:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f01024bd:	f0 
f01024be:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01024c5:	00 
f01024c6:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f01024cd:	e8 ec db ff ff       	call   f01000be <_panic>
	return (void *)(pa + KERNBASE);
f01024d2:	8d 82 00 00 00 f0    	lea    -0x10000000(%edx),%eax
	ptep = (pte_t *) page2kva(pp0);
f01024d8:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	for(i=0; i<NPTENTRIES; i++)
		assert((ptep[i] & PTE_P) == 0);
f01024db:	f6 82 00 00 00 f0 01 	testb  $0x1,-0x10000000(%edx)
f01024e2:	75 13                	jne    f01024f7 <mem_init+0x1317>
f01024e4:	8d 82 04 00 00 f0    	lea    -0xffffffc(%edx),%eax
f01024ea:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f01024f0:	8b 38                	mov    (%eax),%edi
f01024f2:	83 e7 01             	and    $0x1,%edi
f01024f5:	74 24                	je     f010251b <mem_init+0x133b>
f01024f7:	c7 44 24 0c 4b 58 10 	movl   $0xf010584b,0xc(%esp)
f01024fe:	f0 
f01024ff:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102506:	f0 
f0102507:	c7 44 24 04 a8 03 00 	movl   $0x3a8,0x4(%esp)
f010250e:	00 
f010250f:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102516:	e8 a3 db ff ff       	call   f01000be <_panic>
f010251b:	83 c0 04             	add    $0x4,%eax
	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
	page_free(pp0);
	pgdir_walk(kern_pgdir, 0x0, 1);
	ptep = (pte_t *) page2kva(pp0);
	for(i=0; i<NPTENTRIES; i++)
f010251e:	39 d0                	cmp    %edx,%eax
f0102520:	75 ce                	jne    f01024f0 <mem_init+0x1310>
		assert((ptep[i] & PTE_P) == 0);
	kern_pgdir[0] = 0;
f0102522:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0102527:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f010252d:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// give free list back
	page_free_list = fl;
f0102533:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0102536:	a3 fc c2 17 f0       	mov    %eax,0xf017c2fc

	// free the pages we took
	page_free(pp0);
f010253b:	89 1c 24             	mov    %ebx,(%esp)
f010253e:	e8 ef e9 ff ff       	call   f0100f32 <page_free>
	page_free(pp1);
f0102543:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102546:	89 04 24             	mov    %eax,(%esp)
f0102549:	e8 e4 e9 ff ff       	call   f0100f32 <page_free>
	page_free(pp2);
f010254e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102551:	89 04 24             	mov    %eax,(%esp)
f0102554:	e8 d9 e9 ff ff       	call   f0100f32 <page_free>

	cprintf("check_page() succeeded!\n");
f0102559:	c7 04 24 62 58 10 f0 	movl   $0xf0105862,(%esp)
f0102560:	e8 d5 0e 00 00       	call   f010343a <cprintf>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f0102565:	8b 0d c4 cf 17 f0    	mov    0xf017cfc4,%ecx
f010256b:	8d 04 cd ff 0f 00 00 	lea    0xfff(,%ecx,8),%eax
f0102572:	89 c2                	mov    %eax,%edx
f0102574:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
f010257a:	39 c2                	cmp    %eax,%edx
f010257c:	0f 84 16 09 00 00    	je     f0102e98 <mem_init+0x1cb8>
		page_insert(kern_pgdir, pa2page(PADDR(pages) + i), (void *)(UPAGES + i), PTE_U);
f0102582:	a1 cc cf 17 f0       	mov    0xf017cfcc,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102587:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010258c:	76 21                	jbe    f01025af <mem_init+0x13cf>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f010258e:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102594:	c1 ea 0c             	shr    $0xc,%edx
f0102597:	39 ca                	cmp    %ecx,%edx
f0102599:	72 62                	jb     f01025fd <mem_init+0x141d>
f010259b:	eb 44                	jmp    f01025e1 <mem_init+0x1401>
f010259d:	8d bb 00 10 00 ef    	lea    -0x10fff000(%ebx),%edi
f01025a3:	a1 cc cf 17 f0       	mov    0xf017cfcc,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01025a8:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01025ad:	77 20                	ja     f01025cf <mem_init+0x13ef>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01025af:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01025b3:	c7 44 24 08 14 50 10 	movl   $0xf0105014,0x8(%esp)
f01025ba:	f0 
f01025bb:	c7 44 24 04 bc 00 00 	movl   $0xbc,0x4(%esp)
f01025c2:	00 
f01025c3:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01025ca:	e8 ef da ff ff       	call   f01000be <_panic>
f01025cf:	8d 94 18 00 10 00 10 	lea    0x10001000(%eax,%ebx,1),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01025d6:	c1 ea 0c             	shr    $0xc,%edx
f01025d9:	39 d6                	cmp    %edx,%esi
f01025db:	76 04                	jbe    f01025e1 <mem_init+0x1401>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f01025dd:	89 cb                	mov    %ecx,%ebx
f01025df:	eb 2b                	jmp    f010260c <mem_init+0x142c>
		panic("pa2page called with invalid pa");
f01025e1:	c7 44 24 08 b8 4f 10 	movl   $0xf0104fb8,0x8(%esp)
f01025e8:	f0 
f01025e9:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01025f0:	00 
f01025f1:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f01025f8:	e8 c1 da ff ff       	call   f01000be <_panic>
		page_insert(kern_pgdir, pa2page(PADDR(pages) + i), (void *)(UPAGES + i), PTE_U);
f01025fd:	b9 00 00 00 ef       	mov    $0xef000000,%ecx
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f0102602:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102607:	89 7d d4             	mov    %edi,-0x2c(%ebp)
f010260a:	89 cf                	mov    %ecx,%edi
		page_insert(kern_pgdir, pa2page(PADDR(pages) + i), (void *)(UPAGES + i), PTE_U);
f010260c:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f0102613:	00 
f0102614:	89 7c 24 08          	mov    %edi,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102618:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f010261b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010261f:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0102624:	89 04 24             	mov    %eax,(%esp)
f0102627:	e8 f3 ea ff ff       	call   f010111f <page_insert>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f010262c:	8d 8b 00 10 00 00    	lea    0x1000(%ebx),%ecx
f0102632:	8b 35 c4 cf 17 f0    	mov    0xf017cfc4,%esi
f0102638:	8d 04 f5 ff 0f 00 00 	lea    0xfff(,%esi,8),%eax
f010263f:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102644:	39 c8                	cmp    %ecx,%eax
f0102646:	0f 87 51 ff ff ff    	ja     f010259d <mem_init+0x13bd>
f010264c:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f010264f:	e9 44 08 00 00       	jmp    f0102e98 <mem_init+0x1cb8>
static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102654:	b8 00 00 11 00       	mov    $0x110000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102659:	c1 e8 0c             	shr    $0xc,%eax
f010265c:	39 05 c4 cf 17 f0    	cmp    %eax,0xf017cfc4
f0102662:	0f 87 63 08 00 00    	ja     f0102ecb <mem_init+0x1ceb>
f0102668:	eb 39                	jmp    f01026a3 <mem_init+0x14c3>
f010266a:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010266d:	8d 14 18             	lea    (%eax,%ebx,1),%edx
f0102670:	89 d8                	mov    %ebx,%eax
f0102672:	c1 e8 0c             	shr    $0xc,%eax
f0102675:	3b 05 c4 cf 17 f0    	cmp    0xf017cfc4,%eax
f010267b:	72 42                	jb     f01026bf <mem_init+0x14df>
f010267d:	eb 24                	jmp    f01026a3 <mem_init+0x14c3>

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010267f:	c7 44 24 0c 00 00 11 	movl   $0xf0110000,0xc(%esp)
f0102686:	f0 
f0102687:	c7 44 24 08 14 50 10 	movl   $0xf0105014,0x8(%esp)
f010268e:	f0 
f010268f:	c7 44 24 04 d2 00 00 	movl   $0xd2,0x4(%esp)
f0102696:	00 
f0102697:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010269e:	e8 1b da ff ff       	call   f01000be <_panic>

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
f01026a3:	c7 44 24 08 b8 4f 10 	movl   $0xf0104fb8,0x8(%esp)
f01026aa:	f0 
f01026ab:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01026b2:	00 
f01026b3:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f01026ba:	e8 ff d9 ff ff       	call   f01000be <_panic>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		page_insert(kern_pgdir, pa2page(PADDR(bootstack) + i), (void *)(KSTACKTOP-KSTKSIZE + i), PTE_W);
f01026bf:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01026c6:	00 
f01026c7:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f01026cb:	8b 15 cc cf 17 f0    	mov    0xf017cfcc,%edx
f01026d1:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01026d4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01026d8:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f01026dd:	89 04 24             	mov    %eax,(%esp)
f01026e0:	e8 3a ea ff ff       	call   f010111f <page_insert>
f01026e5:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	//     * [KSTACKTOP-PTSIZE, KSTACKTOP-KSTKSIZE) -- not backed; so if
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
f01026eb:	39 f3                	cmp    %esi,%ebx
f01026ed:	0f 85 77 ff ff ff    	jne    f010266a <mem_init+0x148a>
f01026f3:	e9 b5 07 00 00       	jmp    f0102ead <mem_init+0x1ccd>
f01026f8:	8d b3 00 10 00 f0    	lea    -0xffff000(%ebx),%esi
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W);
f01026fe:	8b 1d c4 cf 17 f0    	mov    0xf017cfc4,%ebx
f0102704:	89 df                	mov    %ebx,%edi
f0102706:	c1 e7 0c             	shl    $0xc,%edi
f0102709:	89 c8                	mov    %ecx,%eax
f010270b:	ba 00 00 00 00       	mov    $0x0,%edx
f0102710:	f7 f7                	div    %edi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102712:	c1 ea 0c             	shr    $0xc,%edx
f0102715:	39 d3                	cmp    %edx,%ebx
f0102717:	77 1c                	ja     f0102735 <mem_init+0x1555>
		panic("pa2page called with invalid pa");
f0102719:	c7 44 24 08 b8 4f 10 	movl   $0xf0104fb8,0x8(%esp)
f0102720:	f0 
f0102721:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102728:	00 
f0102729:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f0102730:	e8 89 d9 ff ff       	call   f01000be <_panic>
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
f0102735:	89 cb                	mov    %ecx,%ebx
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W);
f0102737:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f010273e:	00 
f010273f:	89 74 24 08          	mov    %esi,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102743:	a1 cc cf 17 f0       	mov    0xf017cfcc,%eax
f0102748:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f010274b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010274f:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0102754:	89 04 24             	mov    %eax,(%esp)
f0102757:	e8 c3 e9 ff ff       	call   f010111f <page_insert>
		pa2page(i % (npages*PGSIZE))->pp_ref--;                 //this statement is to keep pp_ref == 0 in page_free_list
f010275c:	8b 0d c4 cf 17 f0    	mov    0xf017cfc4,%ecx
f0102762:	89 ce                	mov    %ecx,%esi
f0102764:	c1 e6 0c             	shl    $0xc,%esi
f0102767:	89 d8                	mov    %ebx,%eax
f0102769:	ba 00 00 00 00       	mov    $0x0,%edx
f010276e:	f7 f6                	div    %esi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102770:	c1 ea 0c             	shr    $0xc,%edx
f0102773:	39 d1                	cmp    %edx,%ecx
f0102775:	77 1c                	ja     f0102793 <mem_init+0x15b3>
		panic("pa2page called with invalid pa");
f0102777:	c7 44 24 08 b8 4f 10 	movl   $0xf0104fb8,0x8(%esp)
f010277e:	f0 
f010277f:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102786:	00 
f0102787:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f010278e:	e8 2b d9 ff ff       	call   f01000be <_panic>
	return &pages[PGNUM(pa)];
f0102793:	a1 cc cf 17 f0       	mov    0xf017cfcc,%eax
f0102798:	66 83 6c d0 04 01    	subw   $0x1,0x4(%eax,%edx,8)
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
f010279e:	8d 8b 00 10 00 00    	lea    0x1000(%ebx),%ecx
f01027a4:	81 f9 00 00 00 10    	cmp    $0x10000000,%ecx
f01027aa:	0f 85 48 ff ff ff    	jne    f01026f8 <mem_init+0x1518>
check_kern_pgdir(void)
{
	uint32_t i, n;
	pde_t *pgdir;

	pgdir = kern_pgdir;
f01027b0:	8b 35 c8 cf 17 f0    	mov    0xf017cfc8,%esi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
f01027b6:	a1 c4 cf 17 f0       	mov    0xf017cfc4,%eax
f01027bb:	89 45 d0             	mov    %eax,-0x30(%ebp)
f01027be:	8d 04 c5 ff 0f 00 00 	lea    0xfff(,%eax,8),%eax
	for (i = 0; i < n; i += PGSIZE)
f01027c5:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01027ca:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01027cd:	75 30                	jne    f01027ff <mem_init+0x161f>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f01027cf:	8b 1d 08 c3 17 f0    	mov    0xf017c308,%ebx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01027d5:	89 df                	mov    %ebx,%edi
f01027d7:	ba 00 00 c0 ee       	mov    $0xeec00000,%edx
f01027dc:	89 f0                	mov    %esi,%eax
f01027de:	e8 11 e2 ff ff       	call   f01009f4 <check_va2pa>
f01027e3:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f01027e9:	0f 86 94 00 00 00    	jbe    f0102883 <mem_init+0x16a3>
f01027ef:	bb 00 00 c0 ee       	mov    $0xeec00000,%ebx
f01027f4:	81 c7 00 00 40 21    	add    $0x21400000,%edi
f01027fa:	e9 a4 00 00 00       	jmp    f01028a3 <mem_init+0x16c3>
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f01027ff:	8b 1d cc cf 17 f0    	mov    0xf017cfcc,%ebx
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102805:	8d bb 00 00 00 10    	lea    0x10000000(%ebx),%edi
f010280b:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f0102810:	89 f0                	mov    %esi,%eax
f0102812:	e8 dd e1 ff ff       	call   f01009f4 <check_va2pa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102817:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f010281d:	77 20                	ja     f010283f <mem_init+0x165f>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010281f:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102823:	c7 44 24 08 14 50 10 	movl   $0xf0105014,0x8(%esp)
f010282a:	f0 
f010282b:	c7 44 24 04 ef 02 00 	movl   $0x2ef,0x4(%esp)
f0102832:	00 
f0102833:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010283a:	e8 7f d8 ff ff       	call   f01000be <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f010283f:	ba 00 00 00 00       	mov    $0x0,%edx
f0102844:	8d 0c 17             	lea    (%edi,%edx,1),%ecx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102847:	39 c1                	cmp    %eax,%ecx
f0102849:	74 24                	je     f010286f <mem_init+0x168f>
f010284b:	c7 44 24 0c 24 54 10 	movl   $0xf0105424,0xc(%esp)
f0102852:	f0 
f0102853:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f010285a:	f0 
f010285b:	c7 44 24 04 ef 02 00 	movl   $0x2ef,0x4(%esp)
f0102862:	00 
f0102863:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010286a:	e8 4f d8 ff ff       	call   f01000be <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f010286f:	8d 9a 00 10 00 00    	lea    0x1000(%edx),%ebx
f0102875:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f0102878:	0f 87 d0 06 00 00    	ja     f0102f4e <mem_init+0x1d6e>
f010287e:	e9 4c ff ff ff       	jmp    f01027cf <mem_init+0x15ef>
f0102883:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102887:	c7 44 24 08 14 50 10 	movl   $0xf0105014,0x8(%esp)
f010288e:	f0 
f010288f:	c7 44 24 04 f4 02 00 	movl   $0x2f4,0x4(%esp)
f0102896:	00 
f0102897:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010289e:	e8 1b d8 ff ff       	call   f01000be <_panic>
f01028a3:	8d 14 1f             	lea    (%edi,%ebx,1),%edx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f01028a6:	39 c2                	cmp    %eax,%edx
f01028a8:	74 24                	je     f01028ce <mem_init+0x16ee>
f01028aa:	c7 44 24 0c 58 54 10 	movl   $0xf0105458,0xc(%esp)
f01028b1:	f0 
f01028b2:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01028b9:	f0 
f01028ba:	c7 44 24 04 f4 02 00 	movl   $0x2f4,0x4(%esp)
f01028c1:	00 
f01028c2:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01028c9:	e8 f0 d7 ff ff       	call   f01000be <_panic>
f01028ce:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f01028d4:	81 fb 00 80 c1 ee    	cmp    $0xeec18000,%ebx
f01028da:	0f 85 60 06 00 00    	jne    f0102f40 <mem_init+0x1d60>
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f01028e0:	8b 7d d0             	mov    -0x30(%ebp),%edi
f01028e3:	c1 e7 0c             	shl    $0xc,%edi
f01028e6:	85 ff                	test   %edi,%edi
f01028e8:	0f 84 31 06 00 00    	je     f0102f1f <mem_init+0x1d3f>
f01028ee:	bb 00 00 00 00       	mov    $0x0,%ebx
f01028f3:	8d 93 00 00 00 f0    	lea    -0x10000000(%ebx),%edx
		assert(check_va2pa(pgdir, KERNBASE + i) == i);
f01028f9:	89 f0                	mov    %esi,%eax
f01028fb:	e8 f4 e0 ff ff       	call   f01009f4 <check_va2pa>
f0102900:	39 c3                	cmp    %eax,%ebx
f0102902:	74 24                	je     f0102928 <mem_init+0x1748>
f0102904:	c7 44 24 0c 8c 54 10 	movl   $0xf010548c,0xc(%esp)
f010290b:	f0 
f010290c:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102913:	f0 
f0102914:	c7 44 24 04 f8 02 00 	movl   $0x2f8,0x4(%esp)
f010291b:	00 
f010291c:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102923:	e8 96 d7 ff ff       	call   f01000be <_panic>
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102928:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f010292e:	39 fb                	cmp    %edi,%ebx
f0102930:	72 c1                	jb     f01028f3 <mem_init+0x1713>
f0102932:	e9 e8 05 00 00       	jmp    f0102f1f <mem_init+0x1d3f>
f0102937:	8d 14 1f             	lea    (%edi,%ebx,1),%edx
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check kernel stack
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
f010293a:	39 d0                	cmp    %edx,%eax
f010293c:	74 24                	je     f0102962 <mem_init+0x1782>
f010293e:	c7 44 24 0c b4 54 10 	movl   $0xf01054b4,0xc(%esp)
f0102945:	f0 
f0102946:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f010294d:	f0 
f010294e:	c7 44 24 04 fc 02 00 	movl   $0x2fc,0x4(%esp)
f0102955:	00 
f0102956:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f010295d:	e8 5c d7 ff ff       	call   f01000be <_panic>
f0102962:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check kernel stack
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102968:	81 fb 00 00 c0 ef    	cmp    $0xefc00000,%ebx
f010296e:	0f 85 9d 05 00 00    	jne    f0102f11 <mem_init+0x1d31>
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
	assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);
f0102974:	ba 00 00 80 ef       	mov    $0xef800000,%edx
f0102979:	89 f0                	mov    %esi,%eax
f010297b:	e8 74 e0 ff ff       	call   f01009f4 <check_va2pa>
f0102980:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102983:	74 24                	je     f01029a9 <mem_init+0x17c9>
f0102985:	c7 44 24 0c fc 54 10 	movl   $0xf01054fc,0xc(%esp)
f010298c:	f0 
f010298d:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102994:	f0 
f0102995:	c7 44 24 04 fd 02 00 	movl   $0x2fd,0x4(%esp)
f010299c:	00 
f010299d:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01029a4:	e8 15 d7 ff ff       	call   f01000be <_panic>
f01029a9:	b8 00 00 00 00       	mov    $0x0,%eax

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
		switch (i) {
f01029ae:	8d 90 45 fc ff ff    	lea    -0x3bb(%eax),%edx
f01029b4:	83 fa 03             	cmp    $0x3,%edx
f01029b7:	77 2e                	ja     f01029e7 <mem_init+0x1807>
		case PDX(UVPT):
		case PDX(KSTACKTOP-1):
		case PDX(UPAGES):
		case PDX(UENVS):
			assert(pgdir[i] & PTE_P);
f01029b9:	f6 04 86 01          	testb  $0x1,(%esi,%eax,4)
f01029bd:	0f 85 aa 00 00 00    	jne    f0102a6d <mem_init+0x188d>
f01029c3:	c7 44 24 0c 7b 58 10 	movl   $0xf010587b,0xc(%esp)
f01029ca:	f0 
f01029cb:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01029d2:	f0 
f01029d3:	c7 44 24 04 06 03 00 	movl   $0x306,0x4(%esp)
f01029da:	00 
f01029db:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f01029e2:	e8 d7 d6 ff ff       	call   f01000be <_panic>
			break;
		default:
			if (i >= PDX(KERNBASE)) {
f01029e7:	3d bf 03 00 00       	cmp    $0x3bf,%eax
f01029ec:	76 55                	jbe    f0102a43 <mem_init+0x1863>
				assert(pgdir[i] & PTE_P);
f01029ee:	8b 14 86             	mov    (%esi,%eax,4),%edx
f01029f1:	f6 c2 01             	test   $0x1,%dl
f01029f4:	75 24                	jne    f0102a1a <mem_init+0x183a>
f01029f6:	c7 44 24 0c 7b 58 10 	movl   $0xf010587b,0xc(%esp)
f01029fd:	f0 
f01029fe:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102a05:	f0 
f0102a06:	c7 44 24 04 0a 03 00 	movl   $0x30a,0x4(%esp)
f0102a0d:	00 
f0102a0e:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102a15:	e8 a4 d6 ff ff       	call   f01000be <_panic>
				assert(pgdir[i] & PTE_W);
f0102a1a:	f6 c2 02             	test   $0x2,%dl
f0102a1d:	75 4e                	jne    f0102a6d <mem_init+0x188d>
f0102a1f:	c7 44 24 0c 8c 58 10 	movl   $0xf010588c,0xc(%esp)
f0102a26:	f0 
f0102a27:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102a2e:	f0 
f0102a2f:	c7 44 24 04 0b 03 00 	movl   $0x30b,0x4(%esp)
f0102a36:	00 
f0102a37:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102a3e:	e8 7b d6 ff ff       	call   f01000be <_panic>
			} else
				assert(pgdir[i] == 0);
f0102a43:	83 3c 86 00          	cmpl   $0x0,(%esi,%eax,4)
f0102a47:	74 24                	je     f0102a6d <mem_init+0x188d>
f0102a49:	c7 44 24 0c 9d 58 10 	movl   $0xf010589d,0xc(%esp)
f0102a50:	f0 
f0102a51:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102a58:	f0 
f0102a59:	c7 44 24 04 0d 03 00 	movl   $0x30d,0x4(%esp)
f0102a60:	00 
f0102a61:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102a68:	e8 51 d6 ff ff       	call   f01000be <_panic>
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
	assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
f0102a6d:	83 c0 01             	add    $0x1,%eax
f0102a70:	3d 00 04 00 00       	cmp    $0x400,%eax
f0102a75:	0f 85 33 ff ff ff    	jne    f01029ae <mem_init+0x17ce>
			} else
				assert(pgdir[i] == 0);
			break;
		}
	}
	cprintf("check_kern_pgdir() succeeded!\n");
f0102a7b:	c7 04 24 2c 55 10 f0 	movl   $0xf010552c,(%esp)
f0102a82:	e8 b3 09 00 00       	call   f010343a <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f0102a87:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102a8c:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102a91:	77 20                	ja     f0102ab3 <mem_init+0x18d3>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102a93:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102a97:	c7 44 24 08 14 50 10 	movl   $0xf0105014,0x8(%esp)
f0102a9e:	f0 
f0102a9f:	c7 44 24 04 eb 00 00 	movl   $0xeb,0x4(%esp)
f0102aa6:	00 
f0102aa7:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102aae:	e8 0b d6 ff ff       	call   f01000be <_panic>
	return (physaddr_t)kva - KERNBASE;
f0102ab3:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0102ab8:	0f 22 d8             	mov    %eax,%cr3

	check_page_free_list(0);
f0102abb:	b8 00 00 00 00       	mov    $0x0,%eax
f0102ac0:	e8 9e df ff ff       	call   f0100a63 <check_page_free_list>

static __inline uint32_t
rcr0(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr0,%0" : "=r" (val));
f0102ac5:	0f 20 c0             	mov    %cr0,%eax

	// entry.S set the really important flags in cr0 (including enabling
	// paging).  Here we configure the rest of the flags that we care about.
	cr0 = rcr0();
	cr0 |= CR0_PE|CR0_PG|CR0_AM|CR0_WP|CR0_NE|CR0_MP;
	cr0 &= ~(CR0_TS|CR0_EM);
f0102ac8:	83 e0 f3             	and    $0xfffffff3,%eax
f0102acb:	0d 23 00 05 80       	or     $0x80050023,%eax
}

static __inline void
lcr0(uint32_t val)
{
	__asm __volatile("movl %0,%%cr0" : : "r" (val));
f0102ad0:	0f 22 c0             	mov    %eax,%cr0
	uintptr_t va;
	int i;

	// check that we can read and write installed pages
	pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0102ad3:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102ada:	e8 ce e3 ff ff       	call   f0100ead <page_alloc>
f0102adf:	89 c3                	mov    %eax,%ebx
f0102ae1:	85 c0                	test   %eax,%eax
f0102ae3:	75 24                	jne    f0102b09 <mem_init+0x1929>
f0102ae5:	c7 44 24 0c ba 56 10 	movl   $0xf01056ba,0xc(%esp)
f0102aec:	f0 
f0102aed:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102af4:	f0 
f0102af5:	c7 44 24 04 c3 03 00 	movl   $0x3c3,0x4(%esp)
f0102afc:	00 
f0102afd:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102b04:	e8 b5 d5 ff ff       	call   f01000be <_panic>
	assert((pp1 = page_alloc(0)));
f0102b09:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102b10:	e8 98 e3 ff ff       	call   f0100ead <page_alloc>
f0102b15:	89 c7                	mov    %eax,%edi
f0102b17:	85 c0                	test   %eax,%eax
f0102b19:	75 24                	jne    f0102b3f <mem_init+0x195f>
f0102b1b:	c7 44 24 0c d0 56 10 	movl   $0xf01056d0,0xc(%esp)
f0102b22:	f0 
f0102b23:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102b2a:	f0 
f0102b2b:	c7 44 24 04 c4 03 00 	movl   $0x3c4,0x4(%esp)
f0102b32:	00 
f0102b33:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102b3a:	e8 7f d5 ff ff       	call   f01000be <_panic>
	assert((pp2 = page_alloc(0)));
f0102b3f:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102b46:	e8 62 e3 ff ff       	call   f0100ead <page_alloc>
f0102b4b:	89 c6                	mov    %eax,%esi
f0102b4d:	85 c0                	test   %eax,%eax
f0102b4f:	75 24                	jne    f0102b75 <mem_init+0x1995>
f0102b51:	c7 44 24 0c e6 56 10 	movl   $0xf01056e6,0xc(%esp)
f0102b58:	f0 
f0102b59:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102b60:	f0 
f0102b61:	c7 44 24 04 c5 03 00 	movl   $0x3c5,0x4(%esp)
f0102b68:	00 
f0102b69:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102b70:	e8 49 d5 ff ff       	call   f01000be <_panic>
	page_free(pp0);
f0102b75:	89 1c 24             	mov    %ebx,(%esp)
f0102b78:	e8 b5 e3 ff ff       	call   f0100f32 <page_free>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102b7d:	89 f8                	mov    %edi,%eax
f0102b7f:	2b 05 cc cf 17 f0    	sub    0xf017cfcc,%eax
f0102b85:	c1 f8 03             	sar    $0x3,%eax
f0102b88:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102b8b:	89 c2                	mov    %eax,%edx
f0102b8d:	c1 ea 0c             	shr    $0xc,%edx
f0102b90:	3b 15 c4 cf 17 f0    	cmp    0xf017cfc4,%edx
f0102b96:	72 20                	jb     f0102bb8 <mem_init+0x19d8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102b98:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102b9c:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f0102ba3:	f0 
f0102ba4:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102bab:	00 
f0102bac:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f0102bb3:	e8 06 d5 ff ff       	call   f01000be <_panic>
	memset(page2kva(pp1), 1, PGSIZE);
f0102bb8:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102bbf:	00 
f0102bc0:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f0102bc7:	00 
	return (void *)(pa + KERNBASE);
f0102bc8:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102bcd:	89 04 24             	mov    %eax,(%esp)
f0102bd0:	e8 84 18 00 00       	call   f0104459 <memset>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102bd5:	89 f0                	mov    %esi,%eax
f0102bd7:	2b 05 cc cf 17 f0    	sub    0xf017cfcc,%eax
f0102bdd:	c1 f8 03             	sar    $0x3,%eax
f0102be0:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102be3:	89 c2                	mov    %eax,%edx
f0102be5:	c1 ea 0c             	shr    $0xc,%edx
f0102be8:	3b 15 c4 cf 17 f0    	cmp    0xf017cfc4,%edx
f0102bee:	72 20                	jb     f0102c10 <mem_init+0x1a30>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102bf0:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102bf4:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f0102bfb:	f0 
f0102bfc:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102c03:	00 
f0102c04:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f0102c0b:	e8 ae d4 ff ff       	call   f01000be <_panic>
	memset(page2kva(pp2), 2, PGSIZE);
f0102c10:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102c17:	00 
f0102c18:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102c1f:	00 
	return (void *)(pa + KERNBASE);
f0102c20:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102c25:	89 04 24             	mov    %eax,(%esp)
f0102c28:	e8 2c 18 00 00       	call   f0104459 <memset>
	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f0102c2d:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102c34:	00 
f0102c35:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102c3c:	00 
f0102c3d:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102c41:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0102c46:	89 04 24             	mov    %eax,(%esp)
f0102c49:	e8 d1 e4 ff ff       	call   f010111f <page_insert>
	assert(pp1->pp_ref == 1);
f0102c4e:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0102c53:	74 24                	je     f0102c79 <mem_init+0x1a99>
f0102c55:	c7 44 24 0c b7 57 10 	movl   $0xf01057b7,0xc(%esp)
f0102c5c:	f0 
f0102c5d:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102c64:	f0 
f0102c65:	c7 44 24 04 ca 03 00 	movl   $0x3ca,0x4(%esp)
f0102c6c:	00 
f0102c6d:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102c74:	e8 45 d4 ff ff       	call   f01000be <_panic>
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
f0102c79:	81 3d 00 10 00 00 01 	cmpl   $0x1010101,0x1000
f0102c80:	01 01 01 
f0102c83:	74 24                	je     f0102ca9 <mem_init+0x1ac9>
f0102c85:	c7 44 24 0c 4c 55 10 	movl   $0xf010554c,0xc(%esp)
f0102c8c:	f0 
f0102c8d:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102c94:	f0 
f0102c95:	c7 44 24 04 cb 03 00 	movl   $0x3cb,0x4(%esp)
f0102c9c:	00 
f0102c9d:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102ca4:	e8 15 d4 ff ff       	call   f01000be <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f0102ca9:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102cb0:	00 
f0102cb1:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102cb8:	00 
f0102cb9:	89 74 24 04          	mov    %esi,0x4(%esp)
f0102cbd:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0102cc2:	89 04 24             	mov    %eax,(%esp)
f0102cc5:	e8 55 e4 ff ff       	call   f010111f <page_insert>
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
f0102cca:	81 3d 00 10 00 00 02 	cmpl   $0x2020202,0x1000
f0102cd1:	02 02 02 
f0102cd4:	74 24                	je     f0102cfa <mem_init+0x1b1a>
f0102cd6:	c7 44 24 0c 70 55 10 	movl   $0xf0105570,0xc(%esp)
f0102cdd:	f0 
f0102cde:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102ce5:	f0 
f0102ce6:	c7 44 24 04 cd 03 00 	movl   $0x3cd,0x4(%esp)
f0102ced:	00 
f0102cee:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102cf5:	e8 c4 d3 ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 1);
f0102cfa:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0102cff:	74 24                	je     f0102d25 <mem_init+0x1b45>
f0102d01:	c7 44 24 0c d9 57 10 	movl   $0xf01057d9,0xc(%esp)
f0102d08:	f0 
f0102d09:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102d10:	f0 
f0102d11:	c7 44 24 04 ce 03 00 	movl   $0x3ce,0x4(%esp)
f0102d18:	00 
f0102d19:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102d20:	e8 99 d3 ff ff       	call   f01000be <_panic>
	assert(pp1->pp_ref == 0);
f0102d25:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f0102d2a:	74 24                	je     f0102d50 <mem_init+0x1b70>
f0102d2c:	c7 44 24 0c 22 58 10 	movl   $0xf0105822,0xc(%esp)
f0102d33:	f0 
f0102d34:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102d3b:	f0 
f0102d3c:	c7 44 24 04 cf 03 00 	movl   $0x3cf,0x4(%esp)
f0102d43:	00 
f0102d44:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102d4b:	e8 6e d3 ff ff       	call   f01000be <_panic>
	*(uint32_t *)PGSIZE = 0x03030303U;
f0102d50:	c7 05 00 10 00 00 03 	movl   $0x3030303,0x1000
f0102d57:	03 03 03 
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102d5a:	89 f0                	mov    %esi,%eax
f0102d5c:	2b 05 cc cf 17 f0    	sub    0xf017cfcc,%eax
f0102d62:	c1 f8 03             	sar    $0x3,%eax
f0102d65:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102d68:	89 c2                	mov    %eax,%edx
f0102d6a:	c1 ea 0c             	shr    $0xc,%edx
f0102d6d:	3b 15 c4 cf 17 f0    	cmp    0xf017cfc4,%edx
f0102d73:	72 20                	jb     f0102d95 <mem_init+0x1bb5>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102d75:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102d79:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f0102d80:	f0 
f0102d81:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102d88:	00 
f0102d89:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f0102d90:	e8 29 d3 ff ff       	call   f01000be <_panic>
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
f0102d95:	81 b8 00 00 00 f0 03 	cmpl   $0x3030303,-0x10000000(%eax)
f0102d9c:	03 03 03 
f0102d9f:	74 24                	je     f0102dc5 <mem_init+0x1be5>
f0102da1:	c7 44 24 0c 94 55 10 	movl   $0xf0105594,0xc(%esp)
f0102da8:	f0 
f0102da9:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102db0:	f0 
f0102db1:	c7 44 24 04 d1 03 00 	movl   $0x3d1,0x4(%esp)
f0102db8:	00 
f0102db9:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102dc0:	e8 f9 d2 ff ff       	call   f01000be <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f0102dc5:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102dcc:	00 
f0102dcd:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0102dd2:	89 04 24             	mov    %eax,(%esp)
f0102dd5:	e8 07 e3 ff ff       	call   f01010e1 <page_remove>
	assert(pp2->pp_ref == 0);
f0102dda:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f0102ddf:	74 24                	je     f0102e05 <mem_init+0x1c25>
f0102de1:	c7 44 24 0c 11 58 10 	movl   $0xf0105811,0xc(%esp)
f0102de8:	f0 
f0102de9:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102df0:	f0 
f0102df1:	c7 44 24 04 d3 03 00 	movl   $0x3d3,0x4(%esp)
f0102df8:	00 
f0102df9:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102e00:	e8 b9 d2 ff ff       	call   f01000be <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102e05:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0102e0a:	8b 08                	mov    (%eax),%ecx
f0102e0c:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102e12:	89 da                	mov    %ebx,%edx
f0102e14:	2b 15 cc cf 17 f0    	sub    0xf017cfcc,%edx
f0102e1a:	c1 fa 03             	sar    $0x3,%edx
f0102e1d:	c1 e2 0c             	shl    $0xc,%edx
f0102e20:	39 d1                	cmp    %edx,%ecx
f0102e22:	74 24                	je     f0102e48 <mem_init+0x1c68>
f0102e24:	c7 44 24 0c 10 51 10 	movl   $0xf0105110,0xc(%esp)
f0102e2b:	f0 
f0102e2c:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102e33:	f0 
f0102e34:	c7 44 24 04 d6 03 00 	movl   $0x3d6,0x4(%esp)
f0102e3b:	00 
f0102e3c:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102e43:	e8 76 d2 ff ff       	call   f01000be <_panic>
	kern_pgdir[0] = 0;
f0102e48:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f0102e4e:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102e53:	74 24                	je     f0102e79 <mem_init+0x1c99>
f0102e55:	c7 44 24 0c c8 57 10 	movl   $0xf01057c8,0xc(%esp)
f0102e5c:	f0 
f0102e5d:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0102e64:	f0 
f0102e65:	c7 44 24 04 d8 03 00 	movl   $0x3d8,0x4(%esp)
f0102e6c:	00 
f0102e6d:	c7 04 24 e9 55 10 f0 	movl   $0xf01055e9,(%esp)
f0102e74:	e8 45 d2 ff ff       	call   f01000be <_panic>
	pp0->pp_ref = 0;
f0102e79:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// free the pages we took
	page_free(pp0);
f0102e7f:	89 1c 24             	mov    %ebx,(%esp)
f0102e82:	e8 ab e0 ff ff       	call   f0100f32 <page_free>

	cprintf("check_page_installed_pgdir() succeeded!\n");
f0102e87:	c7 04 24 c0 55 10 f0 	movl   $0xf01055c0,(%esp)
f0102e8e:	e8 a7 05 00 00       	call   f010343a <cprintf>
f0102e93:	e9 ca 00 00 00       	jmp    f0102f62 <mem_init+0x1d82>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102e98:	b8 00 00 11 f0       	mov    $0xf0110000,%eax
f0102e9d:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102ea2:	0f 86 d7 f7 ff ff    	jbe    f010267f <mem_init+0x149f>
f0102ea8:	e9 a7 f7 ff ff       	jmp    f0102654 <mem_init+0x1474>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102ead:	83 3d c4 cf 17 f0 00 	cmpl   $0x0,0xf017cfc4
f0102eb4:	0f 84 5f f8 ff ff    	je     f0102719 <mem_init+0x1539>
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W);
f0102eba:	be 00 00 00 f0       	mov    $0xf0000000,%esi
f0102ebf:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102ec4:	89 fa                	mov    %edi,%edx
f0102ec6:	e9 6c f8 ff ff       	jmp    f0102737 <mem_init+0x1557>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		page_insert(kern_pgdir, pa2page(PADDR(bootstack) + i), (void *)(KSTACKTOP-KSTKSIZE + i), PTE_W);
f0102ecb:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102ed2:	00 
f0102ed3:	c7 44 24 08 00 80 bf 	movl   $0xefbf8000,0x8(%esp)
f0102eda:	ef 
		panic("pa2page called with invalid pa");
	return &pages[PGNUM(pa)];
f0102edb:	8b 15 cc cf 17 f0    	mov    0xf017cfcc,%edx
f0102ee1:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102ee4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102ee8:	a1 c8 cf 17 f0       	mov    0xf017cfc8,%eax
f0102eed:	89 04 24             	mov    %eax,(%esp)
f0102ef0:	e8 2a e2 ff ff       	call   f010111f <page_insert>
f0102ef5:	bb 00 10 11 00       	mov    $0x111000,%ebx
f0102efa:	be 00 80 11 00       	mov    $0x118000,%esi
f0102eff:	b8 00 80 bf df       	mov    $0xdfbf8000,%eax
f0102f04:	2d 00 00 11 f0       	sub    $0xf0110000,%eax
f0102f09:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0102f0c:	e9 59 f7 ff ff       	jmp    f010266a <mem_init+0x148a>
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check kernel stack
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
f0102f11:	89 da                	mov    %ebx,%edx
f0102f13:	89 f0                	mov    %esi,%eax
f0102f15:	e8 da da ff ff       	call   f01009f4 <check_va2pa>
f0102f1a:	e9 18 fa ff ff       	jmp    f0102937 <mem_init+0x1757>
f0102f1f:	ba 00 80 bf ef       	mov    $0xefbf8000,%edx
f0102f24:	89 f0                	mov    %esi,%eax
f0102f26:	e8 c9 da ff ff       	call   f01009f4 <check_va2pa>
f0102f2b:	bb 00 80 bf ef       	mov    $0xefbf8000,%ebx
f0102f30:	b9 00 00 11 f0       	mov    $0xf0110000,%ecx
f0102f35:	8d b9 00 80 40 20    	lea    0x20408000(%ecx),%edi
f0102f3b:	e9 f7 f9 ff ff       	jmp    f0102937 <mem_init+0x1757>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102f40:	89 da                	mov    %ebx,%edx
f0102f42:	89 f0                	mov    %esi,%eax
f0102f44:	e8 ab da ff ff       	call   f01009f4 <check_va2pa>
f0102f49:	e9 55 f9 ff ff       	jmp    f01028a3 <mem_init+0x16c3>
f0102f4e:	81 ea 00 f0 ff 10    	sub    $0x10fff000,%edx
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102f54:	89 f0                	mov    %esi,%eax
f0102f56:	e8 99 da ff ff       	call   f01009f4 <check_va2pa>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102f5b:	89 da                	mov    %ebx,%edx
f0102f5d:	e9 e2 f8 ff ff       	jmp    f0102844 <mem_init+0x1664>
	cr0 &= ~(CR0_TS|CR0_EM);
	lcr0(cr0);

	// Some more checks, only possible after kern_pgdir is installed.
	check_page_installed_pgdir();
}
f0102f62:	83 c4 3c             	add    $0x3c,%esp
f0102f65:	5b                   	pop    %ebx
f0102f66:	5e                   	pop    %esi
f0102f67:	5f                   	pop    %edi
f0102f68:	5d                   	pop    %ebp
f0102f69:	c3                   	ret    

f0102f6a <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f0102f6a:	55                   	push   %ebp
f0102f6b:	89 e5                	mov    %esp,%ebp
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f0102f6d:	8b 45 0c             	mov    0xc(%ebp),%eax
f0102f70:	0f 01 38             	invlpg (%eax)
	// Flush the entry only if we're modifying the current address space.
	// For now, there is only one address space, so always invalidate.
	invlpg(va);
}
f0102f73:	5d                   	pop    %ebp
f0102f74:	c3                   	ret    

f0102f75 <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f0102f75:	55                   	push   %ebp
f0102f76:	89 e5                	mov    %esp,%ebp
	// LAB 3: Your code here.

	return 0;
}
f0102f78:	b8 00 00 00 00       	mov    $0x0,%eax
f0102f7d:	5d                   	pop    %ebp
f0102f7e:	c3                   	ret    

f0102f7f <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f0102f7f:	55                   	push   %ebp
f0102f80:	89 e5                	mov    %esp,%ebp
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
		cprintf("[%08x] user_mem_check assertion failure for "
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
	}
}
f0102f82:	5d                   	pop    %ebp
f0102f83:	c3                   	ret    

f0102f84 <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f0102f84:	55                   	push   %ebp
f0102f85:	89 e5                	mov    %esp,%ebp
f0102f87:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f0102f8a:	85 c0                	test   %eax,%eax
f0102f8c:	75 11                	jne    f0102f9f <envid2env+0x1b>
		*env_store = curenv;
f0102f8e:	a1 04 c3 17 f0       	mov    0xf017c304,%eax
f0102f93:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0102f96:	89 01                	mov    %eax,(%ecx)
		return 0;
f0102f98:	b8 00 00 00 00       	mov    $0x0,%eax
f0102f9d:	eb 60                	jmp    f0102fff <envid2env+0x7b>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f0102f9f:	89 c2                	mov    %eax,%edx
f0102fa1:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f0102fa7:	8d 14 52             	lea    (%edx,%edx,2),%edx
f0102faa:	c1 e2 05             	shl    $0x5,%edx
f0102fad:	03 15 08 c3 17 f0    	add    0xf017c308,%edx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f0102fb3:	83 7a 54 00          	cmpl   $0x0,0x54(%edx)
f0102fb7:	74 05                	je     f0102fbe <envid2env+0x3a>
f0102fb9:	39 42 48             	cmp    %eax,0x48(%edx)
f0102fbc:	74 10                	je     f0102fce <envid2env+0x4a>
		*env_store = 0;
f0102fbe:	8b 45 0c             	mov    0xc(%ebp),%eax
f0102fc1:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f0102fc7:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0102fcc:	eb 31                	jmp    f0102fff <envid2env+0x7b>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f0102fce:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f0102fd2:	74 21                	je     f0102ff5 <envid2env+0x71>
f0102fd4:	a1 04 c3 17 f0       	mov    0xf017c304,%eax
f0102fd9:	39 c2                	cmp    %eax,%edx
f0102fdb:	74 18                	je     f0102ff5 <envid2env+0x71>
f0102fdd:	8b 40 48             	mov    0x48(%eax),%eax
f0102fe0:	39 42 4c             	cmp    %eax,0x4c(%edx)
f0102fe3:	74 10                	je     f0102ff5 <envid2env+0x71>
		*env_store = 0;
f0102fe5:	8b 45 0c             	mov    0xc(%ebp),%eax
f0102fe8:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f0102fee:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0102ff3:	eb 0a                	jmp    f0102fff <envid2env+0x7b>
	}

	*env_store = e;
f0102ff5:	8b 45 0c             	mov    0xc(%ebp),%eax
f0102ff8:	89 10                	mov    %edx,(%eax)
	return 0;
f0102ffa:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0102fff:	5d                   	pop    %ebp
f0103000:	c3                   	ret    

f0103001 <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f0103001:	55                   	push   %ebp
f0103002:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f0103004:	b8 00 a3 11 f0       	mov    $0xf011a300,%eax
f0103009:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f010300c:	b8 23 00 00 00       	mov    $0x23,%eax
f0103011:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f0103013:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f0103015:	b0 10                	mov    $0x10,%al
f0103017:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f0103019:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f010301b:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f010301d:	ea 24 30 10 f0 08 00 	ljmp   $0x8,$0xf0103024
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f0103024:	b0 00                	mov    $0x0,%al
f0103026:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f0103029:	5d                   	pop    %ebp
f010302a:	c3                   	ret    

f010302b <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f010302b:	55                   	push   %ebp
f010302c:	89 e5                	mov    %esp,%ebp
	// Set up envs array
	// LAB 3: Your code here.

	// Per-CPU part of the initialization
	env_init_percpu();
f010302e:	e8 ce ff ff ff       	call   f0103001 <env_init_percpu>
}
f0103033:	5d                   	pop    %ebp
f0103034:	c3                   	ret    

f0103035 <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f0103035:	55                   	push   %ebp
f0103036:	89 e5                	mov    %esp,%ebp
f0103038:	53                   	push   %ebx
f0103039:	83 ec 14             	sub    $0x14,%esp
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
f010303c:	8b 1d 0c c3 17 f0    	mov    0xf017c30c,%ebx
f0103042:	85 db                	test   %ebx,%ebx
f0103044:	0f 84 08 01 00 00    	je     f0103152 <env_alloc+0x11d>
{
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f010304a:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0103051:	e8 57 de ff ff       	call   f0100ead <page_alloc>
f0103056:	85 c0                	test   %eax,%eax
f0103058:	0f 84 fb 00 00 00    	je     f0103159 <env_alloc+0x124>

	// LAB 3: Your code here.

	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f010305e:	8b 43 5c             	mov    0x5c(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103061:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103066:	77 20                	ja     f0103088 <env_alloc+0x53>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103068:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010306c:	c7 44 24 08 14 50 10 	movl   $0xf0105014,0x8(%esp)
f0103073:	f0 
f0103074:	c7 44 24 04 b9 00 00 	movl   $0xb9,0x4(%esp)
f010307b:	00 
f010307c:	c7 04 24 e2 58 10 f0 	movl   $0xf01058e2,(%esp)
f0103083:	e8 36 d0 ff ff       	call   f01000be <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103088:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f010308e:	83 ca 05             	or     $0x5,%edx
f0103091:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate and set up the page directory for this environment.
	if ((r = env_setup_vm(e)) < 0)
		return r;

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f0103097:	8b 43 48             	mov    0x48(%ebx),%eax
f010309a:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f010309f:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f01030a4:	ba 00 10 00 00       	mov    $0x1000,%edx
f01030a9:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f01030ac:	89 da                	mov    %ebx,%edx
f01030ae:	2b 15 08 c3 17 f0    	sub    0xf017c308,%edx
f01030b4:	c1 fa 05             	sar    $0x5,%edx
f01030b7:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f01030bd:	09 d0                	or     %edx,%eax
f01030bf:	89 43 48             	mov    %eax,0x48(%ebx)

	// Set the basic status variables.
	e->env_parent_id = parent_id;
f01030c2:	8b 45 0c             	mov    0xc(%ebp),%eax
f01030c5:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f01030c8:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f01030cf:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
	e->env_runs = 0;
f01030d6:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f01030dd:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f01030e4:	00 
f01030e5:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01030ec:	00 
f01030ed:	89 1c 24             	mov    %ebx,(%esp)
f01030f0:	e8 64 13 00 00       	call   f0104459 <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f01030f5:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f01030fb:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f0103101:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f0103107:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f010310e:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)
	// You will set e->env_tf.tf_eip later.

	// commit the allocation
	env_free_list = e->env_link;
f0103114:	8b 43 44             	mov    0x44(%ebx),%eax
f0103117:	a3 0c c3 17 f0       	mov    %eax,0xf017c30c
	*newenv_store = e;
f010311c:	8b 45 08             	mov    0x8(%ebp),%eax
f010311f:	89 18                	mov    %ebx,(%eax)

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0103121:	8b 53 48             	mov    0x48(%ebx),%edx
f0103124:	a1 04 c3 17 f0       	mov    0xf017c304,%eax
f0103129:	85 c0                	test   %eax,%eax
f010312b:	74 05                	je     f0103132 <env_alloc+0xfd>
f010312d:	8b 40 48             	mov    0x48(%eax),%eax
f0103130:	eb 05                	jmp    f0103137 <env_alloc+0x102>
f0103132:	b8 00 00 00 00       	mov    $0x0,%eax
f0103137:	89 54 24 08          	mov    %edx,0x8(%esp)
f010313b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010313f:	c7 04 24 ed 58 10 f0 	movl   $0xf01058ed,(%esp)
f0103146:	e8 ef 02 00 00       	call   f010343a <cprintf>
	return 0;
f010314b:	b8 00 00 00 00       	mov    $0x0,%eax
f0103150:	eb 0c                	jmp    f010315e <env_alloc+0x129>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
		return -E_NO_FREE_ENV;
f0103152:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f0103157:	eb 05                	jmp    f010315e <env_alloc+0x129>
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f0103159:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	env_free_list = e->env_link;
	*newenv_store = e;

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}
f010315e:	83 c4 14             	add    $0x14,%esp
f0103161:	5b                   	pop    %ebx
f0103162:	5d                   	pop    %ebp
f0103163:	c3                   	ret    

f0103164 <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f0103164:	55                   	push   %ebp
f0103165:	89 e5                	mov    %esp,%ebp
	// LAB 3: Your code here.
}
f0103167:	5d                   	pop    %ebp
f0103168:	c3                   	ret    

f0103169 <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0103169:	55                   	push   %ebp
f010316a:	89 e5                	mov    %esp,%ebp
f010316c:	57                   	push   %edi
f010316d:	56                   	push   %esi
f010316e:	53                   	push   %ebx
f010316f:	83 ec 2c             	sub    $0x2c,%esp
f0103172:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f0103175:	a1 04 c3 17 f0       	mov    0xf017c304,%eax
f010317a:	39 c7                	cmp    %eax,%edi
f010317c:	75 37                	jne    f01031b5 <env_free+0x4c>
		lcr3(PADDR(kern_pgdir));
f010317e:	8b 15 c8 cf 17 f0    	mov    0xf017cfc8,%edx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103184:	81 fa ff ff ff ef    	cmp    $0xefffffff,%edx
f010318a:	77 20                	ja     f01031ac <env_free+0x43>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010318c:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0103190:	c7 44 24 08 14 50 10 	movl   $0xf0105014,0x8(%esp)
f0103197:	f0 
f0103198:	c7 44 24 04 68 01 00 	movl   $0x168,0x4(%esp)
f010319f:	00 
f01031a0:	c7 04 24 e2 58 10 f0 	movl   $0xf01058e2,(%esp)
f01031a7:	e8 12 cf ff ff       	call   f01000be <_panic>
	return (physaddr_t)kva - KERNBASE;
f01031ac:	81 c2 00 00 00 10    	add    $0x10000000,%edx
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f01031b2:	0f 22 da             	mov    %edx,%cr3

	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f01031b5:	8b 57 48             	mov    0x48(%edi),%edx
f01031b8:	85 c0                	test   %eax,%eax
f01031ba:	74 05                	je     f01031c1 <env_free+0x58>
f01031bc:	8b 40 48             	mov    0x48(%eax),%eax
f01031bf:	eb 05                	jmp    f01031c6 <env_free+0x5d>
f01031c1:	b8 00 00 00 00       	mov    $0x0,%eax
f01031c6:	89 54 24 08          	mov    %edx,0x8(%esp)
f01031ca:	89 44 24 04          	mov    %eax,0x4(%esp)
f01031ce:	c7 04 24 02 59 10 f0 	movl   $0xf0105902,(%esp)
f01031d5:	e8 60 02 00 00       	call   f010343a <cprintf>

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f01031da:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f01031e1:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f01031e4:	89 c8                	mov    %ecx,%eax
f01031e6:	c1 e0 02             	shl    $0x2,%eax
f01031e9:	89 45 dc             	mov    %eax,-0x24(%ebp)

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f01031ec:	8b 47 5c             	mov    0x5c(%edi),%eax
f01031ef:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f01031f2:	f7 c6 01 00 00 00    	test   $0x1,%esi
f01031f8:	0f 84 b7 00 00 00    	je     f01032b5 <env_free+0x14c>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f01031fe:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103204:	89 f0                	mov    %esi,%eax
f0103206:	c1 e8 0c             	shr    $0xc,%eax
f0103209:	89 45 d8             	mov    %eax,-0x28(%ebp)
f010320c:	3b 05 c4 cf 17 f0    	cmp    0xf017cfc4,%eax
f0103212:	72 20                	jb     f0103234 <env_free+0xcb>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103214:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0103218:	c7 44 24 08 d0 4e 10 	movl   $0xf0104ed0,0x8(%esp)
f010321f:	f0 
f0103220:	c7 44 24 04 77 01 00 	movl   $0x177,0x4(%esp)
f0103227:	00 
f0103228:	c7 04 24 e2 58 10 f0 	movl   $0xf01058e2,(%esp)
f010322f:	e8 8a ce ff ff       	call   f01000be <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103234:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103237:	c1 e0 16             	shl    $0x16,%eax
f010323a:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f010323d:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f0103242:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f0103249:	01 
f010324a:	74 17                	je     f0103263 <env_free+0xfa>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f010324c:	89 d8                	mov    %ebx,%eax
f010324e:	c1 e0 0c             	shl    $0xc,%eax
f0103251:	0b 45 e4             	or     -0x1c(%ebp),%eax
f0103254:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103258:	8b 47 5c             	mov    0x5c(%edi),%eax
f010325b:	89 04 24             	mov    %eax,(%esp)
f010325e:	e8 7e de ff ff       	call   f01010e1 <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103263:	83 c3 01             	add    $0x1,%ebx
f0103266:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f010326c:	75 d4                	jne    f0103242 <env_free+0xd9>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f010326e:	8b 47 5c             	mov    0x5c(%edi),%eax
f0103271:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103274:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010327b:	8b 45 d8             	mov    -0x28(%ebp),%eax
f010327e:	3b 05 c4 cf 17 f0    	cmp    0xf017cfc4,%eax
f0103284:	72 1c                	jb     f01032a2 <env_free+0x139>
		panic("pa2page called with invalid pa");
f0103286:	c7 44 24 08 b8 4f 10 	movl   $0xf0104fb8,0x8(%esp)
f010328d:	f0 
f010328e:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103295:	00 
f0103296:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f010329d:	e8 1c ce ff ff       	call   f01000be <_panic>
	return &pages[PGNUM(pa)];
f01032a2:	a1 cc cf 17 f0       	mov    0xf017cfcc,%eax
f01032a7:	8b 55 d8             	mov    -0x28(%ebp),%edx
f01032aa:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f01032ad:	89 04 24             	mov    %eax,(%esp)
f01032b0:	e8 92 dc ff ff       	call   f0100f47 <page_decref>
	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f01032b5:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f01032b9:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f01032c0:	0f 85 1b ff ff ff    	jne    f01031e1 <env_free+0x78>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f01032c6:	8b 47 5c             	mov    0x5c(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01032c9:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01032ce:	77 20                	ja     f01032f0 <env_free+0x187>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01032d0:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01032d4:	c7 44 24 08 14 50 10 	movl   $0xf0105014,0x8(%esp)
f01032db:	f0 
f01032dc:	c7 44 24 04 85 01 00 	movl   $0x185,0x4(%esp)
f01032e3:	00 
f01032e4:	c7 04 24 e2 58 10 f0 	movl   $0xf01058e2,(%esp)
f01032eb:	e8 ce cd ff ff       	call   f01000be <_panic>
	e->env_pgdir = 0;
f01032f0:	c7 47 5c 00 00 00 00 	movl   $0x0,0x5c(%edi)
	return (physaddr_t)kva - KERNBASE;
f01032f7:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01032fc:	c1 e8 0c             	shr    $0xc,%eax
f01032ff:	3b 05 c4 cf 17 f0    	cmp    0xf017cfc4,%eax
f0103305:	72 1c                	jb     f0103323 <env_free+0x1ba>
		panic("pa2page called with invalid pa");
f0103307:	c7 44 24 08 b8 4f 10 	movl   $0xf0104fb8,0x8(%esp)
f010330e:	f0 
f010330f:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103316:	00 
f0103317:	c7 04 24 f5 55 10 f0 	movl   $0xf01055f5,(%esp)
f010331e:	e8 9b cd ff ff       	call   f01000be <_panic>
	return &pages[PGNUM(pa)];
f0103323:	8b 15 cc cf 17 f0    	mov    0xf017cfcc,%edx
f0103329:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f010332c:	89 04 24             	mov    %eax,(%esp)
f010332f:	e8 13 dc ff ff       	call   f0100f47 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f0103334:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f010333b:	a1 0c c3 17 f0       	mov    0xf017c30c,%eax
f0103340:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f0103343:	89 3d 0c c3 17 f0    	mov    %edi,0xf017c30c
}
f0103349:	83 c4 2c             	add    $0x2c,%esp
f010334c:	5b                   	pop    %ebx
f010334d:	5e                   	pop    %esi
f010334e:	5f                   	pop    %edi
f010334f:	5d                   	pop    %ebp
f0103350:	c3                   	ret    

f0103351 <env_destroy>:
//
// Frees environment e.
//
void
env_destroy(struct Env *e)
{
f0103351:	55                   	push   %ebp
f0103352:	89 e5                	mov    %esp,%ebp
f0103354:	83 ec 18             	sub    $0x18,%esp
	env_free(e);
f0103357:	8b 45 08             	mov    0x8(%ebp),%eax
f010335a:	89 04 24             	mov    %eax,(%esp)
f010335d:	e8 07 fe ff ff       	call   f0103169 <env_free>

	cprintf("Destroyed the only environment - nothing more to do!\n");
f0103362:	c7 04 24 ac 58 10 f0 	movl   $0xf01058ac,(%esp)
f0103369:	e8 cc 00 00 00       	call   f010343a <cprintf>
	while (1)
		monitor(NULL);
f010336e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0103375:	e8 b8 d4 ff ff       	call   f0100832 <monitor>
f010337a:	eb f2                	jmp    f010336e <env_destroy+0x1d>

f010337c <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f010337c:	55                   	push   %ebp
f010337d:	89 e5                	mov    %esp,%ebp
f010337f:	83 ec 18             	sub    $0x18,%esp
	__asm __volatile("movl %0,%%esp\n"
f0103382:	8b 65 08             	mov    0x8(%ebp),%esp
f0103385:	61                   	popa   
f0103386:	07                   	pop    %es
f0103387:	1f                   	pop    %ds
f0103388:	83 c4 08             	add    $0x8,%esp
f010338b:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f010338c:	c7 44 24 08 18 59 10 	movl   $0xf0105918,0x8(%esp)
f0103393:	f0 
f0103394:	c7 44 24 04 ad 01 00 	movl   $0x1ad,0x4(%esp)
f010339b:	00 
f010339c:	c7 04 24 e2 58 10 f0 	movl   $0xf01058e2,(%esp)
f01033a3:	e8 16 cd ff ff       	call   f01000be <_panic>

f01033a8 <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f01033a8:	55                   	push   %ebp
f01033a9:	89 e5                	mov    %esp,%ebp
f01033ab:	83 ec 18             	sub    $0x18,%esp
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.

	// LAB 3: Your code here.

	panic("env_run not yet implemented");
f01033ae:	c7 44 24 08 24 59 10 	movl   $0xf0105924,0x8(%esp)
f01033b5:	f0 
f01033b6:	c7 44 24 04 cc 01 00 	movl   $0x1cc,0x4(%esp)
f01033bd:	00 
f01033be:	c7 04 24 e2 58 10 f0 	movl   $0xf01058e2,(%esp)
f01033c5:	e8 f4 cc ff ff       	call   f01000be <_panic>

f01033ca <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f01033ca:	55                   	push   %ebp
f01033cb:	89 e5                	mov    %esp,%ebp
f01033cd:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01033d1:	ba 70 00 00 00       	mov    $0x70,%edx
f01033d6:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01033d7:	b2 71                	mov    $0x71,%dl
f01033d9:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f01033da:	0f b6 c0             	movzbl %al,%eax
}
f01033dd:	5d                   	pop    %ebp
f01033de:	c3                   	ret    

f01033df <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f01033df:	55                   	push   %ebp
f01033e0:	89 e5                	mov    %esp,%ebp
f01033e2:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01033e6:	ba 70 00 00 00       	mov    $0x70,%edx
f01033eb:	ee                   	out    %al,(%dx)
f01033ec:	b2 71                	mov    $0x71,%dl
f01033ee:	8b 45 0c             	mov    0xc(%ebp),%eax
f01033f1:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f01033f2:	5d                   	pop    %ebp
f01033f3:	c3                   	ret    

f01033f4 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f01033f4:	55                   	push   %ebp
f01033f5:	89 e5                	mov    %esp,%ebp
f01033f7:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f01033fa:	8b 45 08             	mov    0x8(%ebp),%eax
f01033fd:	89 04 24             	mov    %eax,(%esp)
f0103400:	e8 2f d2 ff ff       	call   f0100634 <cputchar>
	*cnt++;
}
f0103405:	c9                   	leave  
f0103406:	c3                   	ret    

f0103407 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0103407:	55                   	push   %ebp
f0103408:	89 e5                	mov    %esp,%ebp
f010340a:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f010340d:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0103414:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103417:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010341b:	8b 45 08             	mov    0x8(%ebp),%eax
f010341e:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103422:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0103425:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103429:	c7 04 24 f4 33 10 f0 	movl   $0xf01033f4,(%esp)
f0103430:	e8 df 08 00 00       	call   f0103d14 <vprintfmt>
	return cnt;
}
f0103435:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0103438:	c9                   	leave  
f0103439:	c3                   	ret    

f010343a <cprintf>:

int
cprintf(const char *fmt, ...)
{
f010343a:	55                   	push   %ebp
f010343b:	89 e5                	mov    %esp,%ebp
f010343d:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0103440:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0103443:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103447:	8b 45 08             	mov    0x8(%ebp),%eax
f010344a:	89 04 24             	mov    %eax,(%esp)
f010344d:	e8 b5 ff ff ff       	call   f0103407 <vcprintf>
	va_end(ap);

	return cnt;
}
f0103452:	c9                   	leave  
f0103453:	c3                   	ret    

f0103454 <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f0103454:	55                   	push   %ebp
f0103455:	89 e5                	mov    %esp,%ebp
	// Setup a TSS so that we get the right stack
	// when we trap to the kernel.
	ts.ts_esp0 = KSTACKTOP;
f0103457:	c7 05 44 cb 17 f0 00 	movl   $0xefc00000,0xf017cb44
f010345e:	00 c0 ef 
	ts.ts_ss0 = GD_KD;
f0103461:	66 c7 05 48 cb 17 f0 	movw   $0x10,0xf017cb48
f0103468:	10 00 

	// Initialize the TSS slot of the gdt.
	gdt[GD_TSS0 >> 3] = SEG16(STS_T32A, (uint32_t) (&ts),
f010346a:	66 c7 05 48 a3 11 f0 	movw   $0x68,0xf011a348
f0103471:	68 00 
f0103473:	b8 40 cb 17 f0       	mov    $0xf017cb40,%eax
f0103478:	66 a3 4a a3 11 f0    	mov    %ax,0xf011a34a
f010347e:	89 c2                	mov    %eax,%edx
f0103480:	c1 ea 10             	shr    $0x10,%edx
f0103483:	88 15 4c a3 11 f0    	mov    %dl,0xf011a34c
f0103489:	c6 05 4e a3 11 f0 40 	movb   $0x40,0xf011a34e
f0103490:	c1 e8 18             	shr    $0x18,%eax
f0103493:	a2 4f a3 11 f0       	mov    %al,0xf011a34f
					sizeof(struct Taskstate), 0);
	gdt[GD_TSS0 >> 3].sd_s = 0;
f0103498:	c6 05 4d a3 11 f0 89 	movb   $0x89,0xf011a34d
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f010349f:	b8 28 00 00 00       	mov    $0x28,%eax
f01034a4:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f01034a7:	b8 50 a3 11 f0       	mov    $0xf011a350,%eax
f01034ac:	0f 01 18             	lidtl  (%eax)
	// bottom three bits are special; we leave them 0)
	ltr(GD_TSS0);

	// Load the IDT
	lidt(&idt_pd);
}
f01034af:	5d                   	pop    %ebp
f01034b0:	c3                   	ret    

f01034b1 <trap_init>:
}


void
trap_init(void)
{
f01034b1:	55                   	push   %ebp
f01034b2:	89 e5                	mov    %esp,%ebp
	extern struct Segdesc gdt[];

	// LAB 3: Your code here.

	// Per-CPU setup 
	trap_init_percpu();
f01034b4:	e8 9b ff ff ff       	call   f0103454 <trap_init_percpu>
}
f01034b9:	5d                   	pop    %ebp
f01034ba:	c3                   	ret    

f01034bb <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f01034bb:	55                   	push   %ebp
f01034bc:	89 e5                	mov    %esp,%ebp
f01034be:	53                   	push   %ebx
f01034bf:	83 ec 14             	sub    $0x14,%esp
f01034c2:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f01034c5:	8b 03                	mov    (%ebx),%eax
f01034c7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01034cb:	c7 04 24 40 59 10 f0 	movl   $0xf0105940,(%esp)
f01034d2:	e8 63 ff ff ff       	call   f010343a <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f01034d7:	8b 43 04             	mov    0x4(%ebx),%eax
f01034da:	89 44 24 04          	mov    %eax,0x4(%esp)
f01034de:	c7 04 24 4f 59 10 f0 	movl   $0xf010594f,(%esp)
f01034e5:	e8 50 ff ff ff       	call   f010343a <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f01034ea:	8b 43 08             	mov    0x8(%ebx),%eax
f01034ed:	89 44 24 04          	mov    %eax,0x4(%esp)
f01034f1:	c7 04 24 5e 59 10 f0 	movl   $0xf010595e,(%esp)
f01034f8:	e8 3d ff ff ff       	call   f010343a <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f01034fd:	8b 43 0c             	mov    0xc(%ebx),%eax
f0103500:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103504:	c7 04 24 6d 59 10 f0 	movl   $0xf010596d,(%esp)
f010350b:	e8 2a ff ff ff       	call   f010343a <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f0103510:	8b 43 10             	mov    0x10(%ebx),%eax
f0103513:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103517:	c7 04 24 7c 59 10 f0 	movl   $0xf010597c,(%esp)
f010351e:	e8 17 ff ff ff       	call   f010343a <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0103523:	8b 43 14             	mov    0x14(%ebx),%eax
f0103526:	89 44 24 04          	mov    %eax,0x4(%esp)
f010352a:	c7 04 24 8b 59 10 f0 	movl   $0xf010598b,(%esp)
f0103531:	e8 04 ff ff ff       	call   f010343a <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f0103536:	8b 43 18             	mov    0x18(%ebx),%eax
f0103539:	89 44 24 04          	mov    %eax,0x4(%esp)
f010353d:	c7 04 24 9a 59 10 f0 	movl   $0xf010599a,(%esp)
f0103544:	e8 f1 fe ff ff       	call   f010343a <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f0103549:	8b 43 1c             	mov    0x1c(%ebx),%eax
f010354c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103550:	c7 04 24 a9 59 10 f0 	movl   $0xf01059a9,(%esp)
f0103557:	e8 de fe ff ff       	call   f010343a <cprintf>
}
f010355c:	83 c4 14             	add    $0x14,%esp
f010355f:	5b                   	pop    %ebx
f0103560:	5d                   	pop    %ebp
f0103561:	c3                   	ret    

f0103562 <print_trapframe>:
	lidt(&idt_pd);
}

void
print_trapframe(struct Trapframe *tf)
{
f0103562:	55                   	push   %ebp
f0103563:	89 e5                	mov    %esp,%ebp
f0103565:	56                   	push   %esi
f0103566:	53                   	push   %ebx
f0103567:	83 ec 10             	sub    $0x10,%esp
f010356a:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p\n", tf);
f010356d:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103571:	c7 04 24 df 5a 10 f0 	movl   $0xf0105adf,(%esp)
f0103578:	e8 bd fe ff ff       	call   f010343a <cprintf>
	print_regs(&tf->tf_regs);
f010357d:	89 1c 24             	mov    %ebx,(%esp)
f0103580:	e8 36 ff ff ff       	call   f01034bb <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f0103585:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f0103589:	89 44 24 04          	mov    %eax,0x4(%esp)
f010358d:	c7 04 24 fa 59 10 f0 	movl   $0xf01059fa,(%esp)
f0103594:	e8 a1 fe ff ff       	call   f010343a <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f0103599:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f010359d:	89 44 24 04          	mov    %eax,0x4(%esp)
f01035a1:	c7 04 24 0d 5a 10 f0 	movl   $0xf0105a0d,(%esp)
f01035a8:	e8 8d fe ff ff       	call   f010343a <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f01035ad:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f01035b0:	83 f8 13             	cmp    $0x13,%eax
f01035b3:	77 09                	ja     f01035be <print_trapframe+0x5c>
		return excnames[trapno];
f01035b5:	8b 14 85 c0 5c 10 f0 	mov    -0xfefa340(,%eax,4),%edx
f01035bc:	eb 10                	jmp    f01035ce <print_trapframe+0x6c>
	if (trapno == T_SYSCALL)
		return "System call";
f01035be:	83 f8 30             	cmp    $0x30,%eax
f01035c1:	ba b8 59 10 f0       	mov    $0xf01059b8,%edx
f01035c6:	b9 c4 59 10 f0       	mov    $0xf01059c4,%ecx
f01035cb:	0f 45 d1             	cmovne %ecx,%edx
{
	cprintf("TRAP frame at %p\n", tf);
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f01035ce:	89 54 24 08          	mov    %edx,0x8(%esp)
f01035d2:	89 44 24 04          	mov    %eax,0x4(%esp)
f01035d6:	c7 04 24 20 5a 10 f0 	movl   $0xf0105a20,(%esp)
f01035dd:	e8 58 fe ff ff       	call   f010343a <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f01035e2:	3b 1d 20 cb 17 f0    	cmp    0xf017cb20,%ebx
f01035e8:	75 19                	jne    f0103603 <print_trapframe+0xa1>
f01035ea:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f01035ee:	75 13                	jne    f0103603 <print_trapframe+0xa1>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f01035f0:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f01035f3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01035f7:	c7 04 24 32 5a 10 f0 	movl   $0xf0105a32,(%esp)
f01035fe:	e8 37 fe ff ff       	call   f010343a <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f0103603:	8b 43 2c             	mov    0x2c(%ebx),%eax
f0103606:	89 44 24 04          	mov    %eax,0x4(%esp)
f010360a:	c7 04 24 41 5a 10 f0 	movl   $0xf0105a41,(%esp)
f0103611:	e8 24 fe ff ff       	call   f010343a <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f0103616:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f010361a:	75 51                	jne    f010366d <print_trapframe+0x10b>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f010361c:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f010361f:	89 c2                	mov    %eax,%edx
f0103621:	83 e2 01             	and    $0x1,%edx
f0103624:	ba d3 59 10 f0       	mov    $0xf01059d3,%edx
f0103629:	b9 de 59 10 f0       	mov    $0xf01059de,%ecx
f010362e:	0f 45 ca             	cmovne %edx,%ecx
f0103631:	89 c2                	mov    %eax,%edx
f0103633:	83 e2 02             	and    $0x2,%edx
f0103636:	ba ea 59 10 f0       	mov    $0xf01059ea,%edx
f010363b:	be f0 59 10 f0       	mov    $0xf01059f0,%esi
f0103640:	0f 44 d6             	cmove  %esi,%edx
f0103643:	83 e0 04             	and    $0x4,%eax
f0103646:	b8 f5 59 10 f0       	mov    $0xf01059f5,%eax
f010364b:	be 0a 5b 10 f0       	mov    $0xf0105b0a,%esi
f0103650:	0f 44 c6             	cmove  %esi,%eax
f0103653:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0103657:	89 54 24 08          	mov    %edx,0x8(%esp)
f010365b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010365f:	c7 04 24 4f 5a 10 f0 	movl   $0xf0105a4f,(%esp)
f0103666:	e8 cf fd ff ff       	call   f010343a <cprintf>
f010366b:	eb 0c                	jmp    f0103679 <print_trapframe+0x117>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f010366d:	c7 04 24 79 58 10 f0 	movl   $0xf0105879,(%esp)
f0103674:	e8 c1 fd ff ff       	call   f010343a <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f0103679:	8b 43 30             	mov    0x30(%ebx),%eax
f010367c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103680:	c7 04 24 5e 5a 10 f0 	movl   $0xf0105a5e,(%esp)
f0103687:	e8 ae fd ff ff       	call   f010343a <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f010368c:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f0103690:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103694:	c7 04 24 6d 5a 10 f0 	movl   $0xf0105a6d,(%esp)
f010369b:	e8 9a fd ff ff       	call   f010343a <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f01036a0:	8b 43 38             	mov    0x38(%ebx),%eax
f01036a3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01036a7:	c7 04 24 80 5a 10 f0 	movl   $0xf0105a80,(%esp)
f01036ae:	e8 87 fd ff ff       	call   f010343a <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f01036b3:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f01036b7:	74 27                	je     f01036e0 <print_trapframe+0x17e>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f01036b9:	8b 43 3c             	mov    0x3c(%ebx),%eax
f01036bc:	89 44 24 04          	mov    %eax,0x4(%esp)
f01036c0:	c7 04 24 8f 5a 10 f0 	movl   $0xf0105a8f,(%esp)
f01036c7:	e8 6e fd ff ff       	call   f010343a <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f01036cc:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f01036d0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01036d4:	c7 04 24 9e 5a 10 f0 	movl   $0xf0105a9e,(%esp)
f01036db:	e8 5a fd ff ff       	call   f010343a <cprintf>
	}
}
f01036e0:	83 c4 10             	add    $0x10,%esp
f01036e3:	5b                   	pop    %ebx
f01036e4:	5e                   	pop    %esi
f01036e5:	5d                   	pop    %ebp
f01036e6:	c3                   	ret    

f01036e7 <trap>:
	}
}

void
trap(struct Trapframe *tf)
{
f01036e7:	55                   	push   %ebp
f01036e8:	89 e5                	mov    %esp,%ebp
f01036ea:	57                   	push   %edi
f01036eb:	56                   	push   %esi
f01036ec:	83 ec 10             	sub    $0x10,%esp
f01036ef:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f01036f2:	fc                   	cld    

static __inline uint32_t
read_eflags(void)
{
        uint32_t eflags;
        __asm __volatile("pushfl; popl %0" : "=r" (eflags));
f01036f3:	9c                   	pushf  
f01036f4:	58                   	pop    %eax

	// Check that interrupts are disabled.  If this assertion
	// fails, DO NOT be tempted to fix it by inserting a "cli" in
	// the interrupt path.
	assert(!(read_eflags() & FL_IF));
f01036f5:	f6 c4 02             	test   $0x2,%ah
f01036f8:	74 24                	je     f010371e <trap+0x37>
f01036fa:	c7 44 24 0c b1 5a 10 	movl   $0xf0105ab1,0xc(%esp)
f0103701:	f0 
f0103702:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0103709:	f0 
f010370a:	c7 44 24 04 a7 00 00 	movl   $0xa7,0x4(%esp)
f0103711:	00 
f0103712:	c7 04 24 ca 5a 10 f0 	movl   $0xf0105aca,(%esp)
f0103719:	e8 a0 c9 ff ff       	call   f01000be <_panic>

	cprintf("Incoming TRAP frame at %p\n", tf);
f010371e:	89 74 24 04          	mov    %esi,0x4(%esp)
f0103722:	c7 04 24 d6 5a 10 f0 	movl   $0xf0105ad6,(%esp)
f0103729:	e8 0c fd ff ff       	call   f010343a <cprintf>

	if ((tf->tf_cs & 3) == 3) {
f010372e:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f0103732:	83 e0 03             	and    $0x3,%eax
f0103735:	66 83 f8 03          	cmp    $0x3,%ax
f0103739:	75 3c                	jne    f0103777 <trap+0x90>
		// Trapped from user mode.
		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		assert(curenv);
f010373b:	a1 04 c3 17 f0       	mov    0xf017c304,%eax
f0103740:	85 c0                	test   %eax,%eax
f0103742:	75 24                	jne    f0103768 <trap+0x81>
f0103744:	c7 44 24 0c f1 5a 10 	movl   $0xf0105af1,0xc(%esp)
f010374b:	f0 
f010374c:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f0103753:	f0 
f0103754:	c7 44 24 04 b0 00 00 	movl   $0xb0,0x4(%esp)
f010375b:	00 
f010375c:	c7 04 24 ca 5a 10 f0 	movl   $0xf0105aca,(%esp)
f0103763:	e8 56 c9 ff ff       	call   f01000be <_panic>
		curenv->env_tf = *tf;
f0103768:	b9 11 00 00 00       	mov    $0x11,%ecx
f010376d:	89 c7                	mov    %eax,%edi
f010376f:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f0103771:	8b 35 04 c3 17 f0    	mov    0xf017c304,%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f0103777:	89 35 20 cb 17 f0    	mov    %esi,0xf017cb20
{
	// Handle processor exceptions.
	// LAB 3: Your code here.

	// Unexpected trap: The user process or the kernel has a bug.
	print_trapframe(tf);
f010377d:	89 34 24             	mov    %esi,(%esp)
f0103780:	e8 dd fd ff ff       	call   f0103562 <print_trapframe>
	if (tf->tf_cs == GD_KT)
f0103785:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f010378a:	75 1c                	jne    f01037a8 <trap+0xc1>
		panic("unhandled trap in kernel");
f010378c:	c7 44 24 08 f8 5a 10 	movl   $0xf0105af8,0x8(%esp)
f0103793:	f0 
f0103794:	c7 44 24 04 96 00 00 	movl   $0x96,0x4(%esp)
f010379b:	00 
f010379c:	c7 04 24 ca 5a 10 f0 	movl   $0xf0105aca,(%esp)
f01037a3:	e8 16 c9 ff ff       	call   f01000be <_panic>
	else {
		env_destroy(curenv);
f01037a8:	a1 04 c3 17 f0       	mov    0xf017c304,%eax
f01037ad:	89 04 24             	mov    %eax,(%esp)
f01037b0:	e8 9c fb ff ff       	call   f0103351 <env_destroy>

	// Dispatch based on what type of trap occurred
	trap_dispatch(tf);

	// Return to the current environment, which should be running.
	assert(curenv && curenv->env_status == ENV_RUNNING);
f01037b5:	a1 04 c3 17 f0       	mov    0xf017c304,%eax
f01037ba:	85 c0                	test   %eax,%eax
f01037bc:	74 06                	je     f01037c4 <trap+0xdd>
f01037be:	83 78 54 02          	cmpl   $0x2,0x54(%eax)
f01037c2:	74 24                	je     f01037e8 <trap+0x101>
f01037c4:	c7 44 24 0c 54 5c 10 	movl   $0xf0105c54,0xc(%esp)
f01037cb:	f0 
f01037cc:	c7 44 24 08 0f 56 10 	movl   $0xf010560f,0x8(%esp)
f01037d3:	f0 
f01037d4:	c7 44 24 04 be 00 00 	movl   $0xbe,0x4(%esp)
f01037db:	00 
f01037dc:	c7 04 24 ca 5a 10 f0 	movl   $0xf0105aca,(%esp)
f01037e3:	e8 d6 c8 ff ff       	call   f01000be <_panic>
	env_run(curenv);
f01037e8:	89 04 24             	mov    %eax,(%esp)
f01037eb:	e8 b8 fb ff ff       	call   f01033a8 <env_run>

f01037f0 <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f01037f0:	55                   	push   %ebp
f01037f1:	89 e5                	mov    %esp,%ebp
f01037f3:	53                   	push   %ebx
f01037f4:	83 ec 14             	sub    $0x14,%esp
f01037f7:	8b 5d 08             	mov    0x8(%ebp),%ebx

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f01037fa:	0f 20 d0             	mov    %cr2,%eax

	// We've already handled kernel-mode exceptions, so if we get here,
	// the page fault happened in user mode.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f01037fd:	8b 53 30             	mov    0x30(%ebx),%edx
f0103800:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0103804:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103808:	a1 04 c3 17 f0       	mov    0xf017c304,%eax
f010380d:	8b 40 48             	mov    0x48(%eax),%eax
f0103810:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103814:	c7 04 24 80 5c 10 f0 	movl   $0xf0105c80,(%esp)
f010381b:	e8 1a fc ff ff       	call   f010343a <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
	print_trapframe(tf);
f0103820:	89 1c 24             	mov    %ebx,(%esp)
f0103823:	e8 3a fd ff ff       	call   f0103562 <print_trapframe>
	env_destroy(curenv);
f0103828:	a1 04 c3 17 f0       	mov    0xf017c304,%eax
f010382d:	89 04 24             	mov    %eax,(%esp)
f0103830:	e8 1c fb ff ff       	call   f0103351 <env_destroy>
}
f0103835:	83 c4 14             	add    $0x14,%esp
f0103838:	5b                   	pop    %ebx
f0103839:	5d                   	pop    %ebp
f010383a:	c3                   	ret    

f010383b <syscall>:
f010383b:	55                   	push   %ebp
f010383c:	89 e5                	mov    %esp,%ebp
f010383e:	83 ec 18             	sub    $0x18,%esp
f0103841:	c7 44 24 08 10 5d 10 	movl   $0xf0105d10,0x8(%esp)
f0103848:	f0 
f0103849:	c7 44 24 04 49 00 00 	movl   $0x49,0x4(%esp)
f0103850:	00 
f0103851:	c7 04 24 28 5d 10 f0 	movl   $0xf0105d28,(%esp)
f0103858:	e8 61 c8 ff ff       	call   f01000be <_panic>
f010385d:	66 90                	xchg   %ax,%ax
f010385f:	90                   	nop

f0103860 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0103860:	55                   	push   %ebp
f0103861:	89 e5                	mov    %esp,%ebp
f0103863:	57                   	push   %edi
f0103864:	56                   	push   %esi
f0103865:	53                   	push   %ebx
f0103866:	83 ec 14             	sub    $0x14,%esp
f0103869:	89 45 ec             	mov    %eax,-0x14(%ebp)
f010386c:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f010386f:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0103872:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0103875:	8b 1a                	mov    (%edx),%ebx
f0103877:	8b 01                	mov    (%ecx),%eax
f0103879:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f010387c:	39 c3                	cmp    %eax,%ebx
f010387e:	0f 8f 9a 00 00 00    	jg     f010391e <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f0103884:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f010388b:	8b 45 f0             	mov    -0x10(%ebp),%eax
f010388e:	01 d8                	add    %ebx,%eax
f0103890:	89 c7                	mov    %eax,%edi
f0103892:	c1 ef 1f             	shr    $0x1f,%edi
f0103895:	01 c7                	add    %eax,%edi
f0103897:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0103899:	39 df                	cmp    %ebx,%edi
f010389b:	0f 8c c4 00 00 00    	jl     f0103965 <stab_binsearch+0x105>
f01038a1:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f01038a4:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f01038a7:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f01038aa:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f01038ae:	39 f0                	cmp    %esi,%eax
f01038b0:	0f 84 b4 00 00 00    	je     f010396a <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f01038b6:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f01038b8:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f01038bb:	39 d8                	cmp    %ebx,%eax
f01038bd:	0f 8c a2 00 00 00    	jl     f0103965 <stab_binsearch+0x105>
f01038c3:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f01038c7:	83 ea 0c             	sub    $0xc,%edx
f01038ca:	39 f1                	cmp    %esi,%ecx
f01038cc:	75 ea                	jne    f01038b8 <stab_binsearch+0x58>
f01038ce:	e9 99 00 00 00       	jmp    f010396c <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f01038d3:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f01038d6:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f01038d8:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01038db:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01038e2:	eb 2b                	jmp    f010390f <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f01038e4:	3b 55 0c             	cmp    0xc(%ebp),%edx
f01038e7:	76 14                	jbe    f01038fd <stab_binsearch+0x9d>
			*region_right = m - 1;
f01038e9:	83 e8 01             	sub    $0x1,%eax
f01038ec:	89 45 f0             	mov    %eax,-0x10(%ebp)
f01038ef:	8b 7d e0             	mov    -0x20(%ebp),%edi
f01038f2:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01038f4:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01038fb:	eb 12                	jmp    f010390f <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f01038fd:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0103900:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f0103902:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f0103906:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0103908:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f010390f:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0103912:	0f 8e 73 ff ff ff    	jle    f010388b <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0103918:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f010391c:	75 0f                	jne    f010392d <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f010391e:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103921:	8b 00                	mov    (%eax),%eax
f0103923:	83 e8 01             	sub    $0x1,%eax
f0103926:	8b 75 e0             	mov    -0x20(%ebp),%esi
f0103929:	89 06                	mov    %eax,(%esi)
f010392b:	eb 57                	jmp    f0103984 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f010392d:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103930:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0103932:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0103935:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0103937:	39 c8                	cmp    %ecx,%eax
f0103939:	7e 23                	jle    f010395e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f010393b:	8d 14 40             	lea    (%eax,%eax,2),%edx
f010393e:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0103941:	8d 14 97             	lea    (%edi,%edx,4),%edx
f0103944:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f0103948:	39 f3                	cmp    %esi,%ebx
f010394a:	74 12                	je     f010395e <stab_binsearch+0xfe>
		     l--)
f010394c:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f010394f:	39 c8                	cmp    %ecx,%eax
f0103951:	7e 0b                	jle    f010395e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0103953:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f0103957:	83 ea 0c             	sub    $0xc,%edx
f010395a:	39 f3                	cmp    %esi,%ebx
f010395c:	75 ee                	jne    f010394c <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f010395e:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0103961:	89 06                	mov    %eax,(%esi)
f0103963:	eb 1f                	jmp    f0103984 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0103965:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0103968:	eb a5                	jmp    f010390f <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f010396a:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f010396c:	8d 14 40             	lea    (%eax,%eax,2),%edx
f010396f:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0103972:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0103976:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0103979:	0f 82 54 ff ff ff    	jb     f01038d3 <stab_binsearch+0x73>
f010397f:	e9 60 ff ff ff       	jmp    f01038e4 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0103984:	83 c4 14             	add    $0x14,%esp
f0103987:	5b                   	pop    %ebx
f0103988:	5e                   	pop    %esi
f0103989:	5f                   	pop    %edi
f010398a:	5d                   	pop    %ebp
f010398b:	c3                   	ret    

f010398c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f010398c:	55                   	push   %ebp
f010398d:	89 e5                	mov    %esp,%ebp
f010398f:	57                   	push   %edi
f0103990:	56                   	push   %esi
f0103991:	53                   	push   %ebx
f0103992:	83 ec 3c             	sub    $0x3c,%esp
f0103995:	8b 7d 08             	mov    0x8(%ebp),%edi
f0103998:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f010399b:	c7 06 37 5d 10 f0    	movl   $0xf0105d37,(%esi)
	info->eip_line = 0;
f01039a1:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f01039a8:	c7 46 08 37 5d 10 f0 	movl   $0xf0105d37,0x8(%esi)
	info->eip_fn_namelen = 9;
f01039af:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f01039b6:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f01039b9:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f01039c0:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f01039c6:	77 21                	ja     f01039e9 <debuginfo_eip+0x5d>

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.

		stabs = usd->stabs;
f01039c8:	a1 00 00 20 00       	mov    0x200000,%eax
f01039cd:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f01039d0:	a1 04 00 20 00       	mov    0x200004,%eax
		stabstr = usd->stabstr;
f01039d5:	8b 1d 08 00 20 00    	mov    0x200008,%ebx
f01039db:	89 5d d0             	mov    %ebx,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f01039de:	8b 1d 0c 00 20 00    	mov    0x20000c,%ebx
f01039e4:	89 5d cc             	mov    %ebx,-0x34(%ebp)
f01039e7:	eb 1a                	jmp    f0103a03 <debuginfo_eip+0x77>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f01039e9:	c7 45 cc 85 fd 10 f0 	movl   $0xf010fd85,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f01039f0:	c7 45 d0 bd d4 10 f0 	movl   $0xf010d4bd,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f01039f7:	b8 bc d4 10 f0       	mov    $0xf010d4bc,%eax
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f01039fc:	c7 45 d4 50 5f 10 f0 	movl   $0xf0105f50,-0x2c(%ebp)
		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0103a03:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0103a06:	39 4d d0             	cmp    %ecx,-0x30(%ebp)
f0103a09:	0f 83 57 01 00 00    	jae    f0103b66 <debuginfo_eip+0x1da>
f0103a0f:	80 79 ff 00          	cmpb   $0x0,-0x1(%ecx)
f0103a13:	0f 85 54 01 00 00    	jne    f0103b6d <debuginfo_eip+0x1e1>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0103a19:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0103a20:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0103a23:	29 d8                	sub    %ebx,%eax
f0103a25:	c1 f8 02             	sar    $0x2,%eax
f0103a28:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
f0103a2e:	83 e8 01             	sub    $0x1,%eax
f0103a31:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0103a34:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103a38:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0103a3f:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0103a42:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0103a45:	89 d8                	mov    %ebx,%eax
f0103a47:	e8 14 fe ff ff       	call   f0103860 <stab_binsearch>
	if (lfile == 0)
f0103a4c:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103a4f:	85 c0                	test   %eax,%eax
f0103a51:	0f 84 1d 01 00 00    	je     f0103b74 <debuginfo_eip+0x1e8>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0103a57:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0103a5a:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103a5d:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0103a60:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103a64:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0103a6b:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0103a6e:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0103a71:	89 d8                	mov    %ebx,%eax
f0103a73:	e8 e8 fd ff ff       	call   f0103860 <stab_binsearch>

	if (lfun <= rfun) {
f0103a78:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f0103a7b:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f0103a7e:	7f 23                	jg     f0103aa3 <debuginfo_eip+0x117>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0103a80:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0103a83:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0103a86:	8d 04 87             	lea    (%edi,%eax,4),%eax
f0103a89:	8b 10                	mov    (%eax),%edx
f0103a8b:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0103a8e:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f0103a91:	39 ca                	cmp    %ecx,%edx
f0103a93:	73 06                	jae    f0103a9b <debuginfo_eip+0x10f>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0103a95:	03 55 d0             	add    -0x30(%ebp),%edx
f0103a98:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f0103a9b:	8b 40 08             	mov    0x8(%eax),%eax
f0103a9e:	89 46 10             	mov    %eax,0x10(%esi)
f0103aa1:	eb 06                	jmp    f0103aa9 <debuginfo_eip+0x11d>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0103aa3:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f0103aa6:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0103aa9:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0103ab0:	00 
f0103ab1:	8b 46 08             	mov    0x8(%esi),%eax
f0103ab4:	89 04 24             	mov    %eax,(%esp)
f0103ab7:	e8 73 09 00 00       	call   f010442f <strfind>
f0103abc:	2b 46 08             	sub    0x8(%esi),%eax
f0103abf:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0103ac2:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0103ac5:	39 fb                	cmp    %edi,%ebx
f0103ac7:	7c 5d                	jl     f0103b26 <debuginfo_eip+0x19a>
	       && stabs[lline].n_type != N_SOL
f0103ac9:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0103acc:	c1 e0 02             	shl    $0x2,%eax
f0103acf:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0103ad2:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f0103ad5:	89 55 c8             	mov    %edx,-0x38(%ebp)
f0103ad8:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f0103adc:	80 fa 84             	cmp    $0x84,%dl
f0103adf:	74 2d                	je     f0103b0e <debuginfo_eip+0x182>
f0103ae1:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f0103ae5:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0103ae8:	eb 15                	jmp    f0103aff <debuginfo_eip+0x173>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0103aea:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0103aed:	39 fb                	cmp    %edi,%ebx
f0103aef:	7c 35                	jl     f0103b26 <debuginfo_eip+0x19a>
	       && stabs[lline].n_type != N_SOL
f0103af1:	89 c1                	mov    %eax,%ecx
f0103af3:	83 e8 0c             	sub    $0xc,%eax
f0103af6:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0103afa:	80 fa 84             	cmp    $0x84,%dl
f0103afd:	74 0f                	je     f0103b0e <debuginfo_eip+0x182>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0103aff:	80 fa 64             	cmp    $0x64,%dl
f0103b02:	75 e6                	jne    f0103aea <debuginfo_eip+0x15e>
f0103b04:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f0103b08:	74 e0                	je     f0103aea <debuginfo_eip+0x15e>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0103b0a:	39 df                	cmp    %ebx,%edi
f0103b0c:	7f 18                	jg     f0103b26 <debuginfo_eip+0x19a>
f0103b0e:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0103b11:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0103b14:	8b 04 87             	mov    (%edi,%eax,4),%eax
f0103b17:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0103b1a:	2b 55 d0             	sub    -0x30(%ebp),%edx
f0103b1d:	39 d0                	cmp    %edx,%eax
f0103b1f:	73 05                	jae    f0103b26 <debuginfo_eip+0x19a>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0103b21:	03 45 d0             	add    -0x30(%ebp),%eax
f0103b24:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0103b26:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103b29:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0103b2c:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0103b31:	39 ca                	cmp    %ecx,%edx
f0103b33:	7d 60                	jge    f0103b95 <debuginfo_eip+0x209>
		for (lline = lfun + 1;
f0103b35:	8d 42 01             	lea    0x1(%edx),%eax
f0103b38:	39 c1                	cmp    %eax,%ecx
f0103b3a:	7e 3f                	jle    f0103b7b <debuginfo_eip+0x1ef>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0103b3c:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0103b3f:	c1 e2 02             	shl    $0x2,%edx
f0103b42:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0103b45:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f0103b4a:	75 36                	jne    f0103b82 <debuginfo_eip+0x1f6>
f0103b4c:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f0103b50:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0103b54:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0103b57:	39 c1                	cmp    %eax,%ecx
f0103b59:	7e 2e                	jle    f0103b89 <debuginfo_eip+0x1fd>
f0103b5b:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0103b5e:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0103b62:	74 ec                	je     f0103b50 <debuginfo_eip+0x1c4>
f0103b64:	eb 2a                	jmp    f0103b90 <debuginfo_eip+0x204>
		// LAB 3: Your code here.
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0103b66:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0103b6b:	eb 28                	jmp    f0103b95 <debuginfo_eip+0x209>
f0103b6d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0103b72:	eb 21                	jmp    f0103b95 <debuginfo_eip+0x209>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0103b74:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0103b79:	eb 1a                	jmp    f0103b95 <debuginfo_eip+0x209>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0103b7b:	b8 00 00 00 00       	mov    $0x0,%eax
f0103b80:	eb 13                	jmp    f0103b95 <debuginfo_eip+0x209>
f0103b82:	b8 00 00 00 00       	mov    $0x0,%eax
f0103b87:	eb 0c                	jmp    f0103b95 <debuginfo_eip+0x209>
f0103b89:	b8 00 00 00 00       	mov    $0x0,%eax
f0103b8e:	eb 05                	jmp    f0103b95 <debuginfo_eip+0x209>
f0103b90:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0103b95:	83 c4 3c             	add    $0x3c,%esp
f0103b98:	5b                   	pop    %ebx
f0103b99:	5e                   	pop    %esi
f0103b9a:	5f                   	pop    %edi
f0103b9b:	5d                   	pop    %ebp
f0103b9c:	c3                   	ret    
f0103b9d:	66 90                	xchg   %ax,%ax
f0103b9f:	90                   	nop

f0103ba0 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0103ba0:	55                   	push   %ebp
f0103ba1:	89 e5                	mov    %esp,%ebp
f0103ba3:	57                   	push   %edi
f0103ba4:	56                   	push   %esi
f0103ba5:	53                   	push   %ebx
f0103ba6:	83 ec 3c             	sub    $0x3c,%esp
f0103ba9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0103bac:	89 d7                	mov    %edx,%edi
f0103bae:	8b 45 08             	mov    0x8(%ebp),%eax
f0103bb1:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0103bb4:	8b 75 0c             	mov    0xc(%ebp),%esi
f0103bb7:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f0103bba:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0103bbd:	b9 00 00 00 00       	mov    $0x0,%ecx
f0103bc2:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103bc5:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0103bc8:	39 f1                	cmp    %esi,%ecx
f0103bca:	72 14                	jb     f0103be0 <printnum+0x40>
f0103bcc:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f0103bcf:	76 0f                	jbe    f0103be0 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0103bd1:	8b 45 14             	mov    0x14(%ebp),%eax
f0103bd4:	8d 70 ff             	lea    -0x1(%eax),%esi
f0103bd7:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0103bda:	85 f6                	test   %esi,%esi
f0103bdc:	7f 60                	jg     f0103c3e <printnum+0x9e>
f0103bde:	eb 72                	jmp    f0103c52 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0103be0:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0103be3:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0103be7:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0103bea:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0103bed:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0103bf1:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103bf5:	8b 44 24 08          	mov    0x8(%esp),%eax
f0103bf9:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0103bfd:	89 c3                	mov    %eax,%ebx
f0103bff:	89 d6                	mov    %edx,%esi
f0103c01:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103c04:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0103c07:	89 54 24 08          	mov    %edx,0x8(%esp)
f0103c0b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0103c0f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103c12:	89 04 24             	mov    %eax,(%esp)
f0103c15:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0103c18:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c1c:	e8 6f 0a 00 00       	call   f0104690 <__udivdi3>
f0103c21:	89 d9                	mov    %ebx,%ecx
f0103c23:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0103c27:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0103c2b:	89 04 24             	mov    %eax,(%esp)
f0103c2e:	89 54 24 04          	mov    %edx,0x4(%esp)
f0103c32:	89 fa                	mov    %edi,%edx
f0103c34:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103c37:	e8 64 ff ff ff       	call   f0103ba0 <printnum>
f0103c3c:	eb 14                	jmp    f0103c52 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f0103c3e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103c42:	8b 45 18             	mov    0x18(%ebp),%eax
f0103c45:	89 04 24             	mov    %eax,(%esp)
f0103c48:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0103c4a:	83 ee 01             	sub    $0x1,%esi
f0103c4d:	75 ef                	jne    f0103c3e <printnum+0x9e>
f0103c4f:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0103c52:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103c56:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0103c5a:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103c5d:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103c60:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103c64:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0103c68:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103c6b:	89 04 24             	mov    %eax,(%esp)
f0103c6e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0103c71:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c75:	e8 46 0b 00 00       	call   f01047c0 <__umoddi3>
f0103c7a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103c7e:	0f be 80 41 5d 10 f0 	movsbl -0xfefa2bf(%eax),%eax
f0103c85:	89 04 24             	mov    %eax,(%esp)
f0103c88:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103c8b:	ff d0                	call   *%eax
}
f0103c8d:	83 c4 3c             	add    $0x3c,%esp
f0103c90:	5b                   	pop    %ebx
f0103c91:	5e                   	pop    %esi
f0103c92:	5f                   	pop    %edi
f0103c93:	5d                   	pop    %ebp
f0103c94:	c3                   	ret    

f0103c95 <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0103c95:	55                   	push   %ebp
f0103c96:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0103c98:	83 fa 01             	cmp    $0x1,%edx
f0103c9b:	7e 0e                	jle    f0103cab <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f0103c9d:	8b 10                	mov    (%eax),%edx
f0103c9f:	8d 4a 08             	lea    0x8(%edx),%ecx
f0103ca2:	89 08                	mov    %ecx,(%eax)
f0103ca4:	8b 02                	mov    (%edx),%eax
f0103ca6:	8b 52 04             	mov    0x4(%edx),%edx
f0103ca9:	eb 22                	jmp    f0103ccd <getuint+0x38>
	else if (lflag)
f0103cab:	85 d2                	test   %edx,%edx
f0103cad:	74 10                	je     f0103cbf <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f0103caf:	8b 10                	mov    (%eax),%edx
f0103cb1:	8d 4a 04             	lea    0x4(%edx),%ecx
f0103cb4:	89 08                	mov    %ecx,(%eax)
f0103cb6:	8b 02                	mov    (%edx),%eax
f0103cb8:	ba 00 00 00 00       	mov    $0x0,%edx
f0103cbd:	eb 0e                	jmp    f0103ccd <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f0103cbf:	8b 10                	mov    (%eax),%edx
f0103cc1:	8d 4a 04             	lea    0x4(%edx),%ecx
f0103cc4:	89 08                	mov    %ecx,(%eax)
f0103cc6:	8b 02                	mov    (%edx),%eax
f0103cc8:	ba 00 00 00 00       	mov    $0x0,%edx
}
f0103ccd:	5d                   	pop    %ebp
f0103cce:	c3                   	ret    

f0103ccf <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0103ccf:	55                   	push   %ebp
f0103cd0:	89 e5                	mov    %esp,%ebp
f0103cd2:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0103cd5:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0103cd9:	8b 10                	mov    (%eax),%edx
f0103cdb:	3b 50 04             	cmp    0x4(%eax),%edx
f0103cde:	73 0a                	jae    f0103cea <sprintputch+0x1b>
		*b->buf++ = ch;
f0103ce0:	8d 4a 01             	lea    0x1(%edx),%ecx
f0103ce3:	89 08                	mov    %ecx,(%eax)
f0103ce5:	8b 45 08             	mov    0x8(%ebp),%eax
f0103ce8:	88 02                	mov    %al,(%edx)
}
f0103cea:	5d                   	pop    %ebp
f0103ceb:	c3                   	ret    

f0103cec <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0103cec:	55                   	push   %ebp
f0103ced:	89 e5                	mov    %esp,%ebp
f0103cef:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0103cf2:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0103cf5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103cf9:	8b 45 10             	mov    0x10(%ebp),%eax
f0103cfc:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103d00:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103d03:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d07:	8b 45 08             	mov    0x8(%ebp),%eax
f0103d0a:	89 04 24             	mov    %eax,(%esp)
f0103d0d:	e8 02 00 00 00       	call   f0103d14 <vprintfmt>
	va_end(ap);
}
f0103d12:	c9                   	leave  
f0103d13:	c3                   	ret    

f0103d14 <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f0103d14:	55                   	push   %ebp
f0103d15:	89 e5                	mov    %esp,%ebp
f0103d17:	57                   	push   %edi
f0103d18:	56                   	push   %esi
f0103d19:	53                   	push   %ebx
f0103d1a:	83 ec 3c             	sub    $0x3c,%esp
f0103d1d:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0103d20:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0103d23:	eb 18                	jmp    f0103d3d <vprintfmt+0x29>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f0103d25:	85 c0                	test   %eax,%eax
f0103d27:	0f 84 c3 03 00 00    	je     f01040f0 <vprintfmt+0x3dc>
				return;
			putch(ch, putdat);
f0103d2d:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103d31:	89 04 24             	mov    %eax,(%esp)
f0103d34:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0103d37:	89 f3                	mov    %esi,%ebx
f0103d39:	eb 02                	jmp    f0103d3d <vprintfmt+0x29>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f0103d3b:	89 f3                	mov    %esi,%ebx
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0103d3d:	8d 73 01             	lea    0x1(%ebx),%esi
f0103d40:	0f b6 03             	movzbl (%ebx),%eax
f0103d43:	83 f8 25             	cmp    $0x25,%eax
f0103d46:	75 dd                	jne    f0103d25 <vprintfmt+0x11>
f0103d48:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f0103d4c:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0103d53:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f0103d5a:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0103d61:	ba 00 00 00 00       	mov    $0x0,%edx
f0103d66:	eb 1d                	jmp    f0103d85 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103d68:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f0103d6a:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f0103d6e:	eb 15                	jmp    f0103d85 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103d70:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0103d72:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f0103d76:	eb 0d                	jmp    f0103d85 <vprintfmt+0x71>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0103d78:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0103d7b:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0103d7e:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103d85:	8d 5e 01             	lea    0x1(%esi),%ebx
f0103d88:	0f b6 06             	movzbl (%esi),%eax
f0103d8b:	0f b6 c8             	movzbl %al,%ecx
f0103d8e:	83 e8 23             	sub    $0x23,%eax
f0103d91:	3c 55                	cmp    $0x55,%al
f0103d93:	0f 87 2f 03 00 00    	ja     f01040c8 <vprintfmt+0x3b4>
f0103d99:	0f b6 c0             	movzbl %al,%eax
f0103d9c:	ff 24 85 cc 5d 10 f0 	jmp    *-0xfefa234(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0103da3:	8d 41 d0             	lea    -0x30(%ecx),%eax
f0103da6:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0103da9:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f0103dad:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0103db0:	83 f9 09             	cmp    $0x9,%ecx
f0103db3:	77 50                	ja     f0103e05 <vprintfmt+0xf1>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103db5:	89 de                	mov    %ebx,%esi
f0103db7:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f0103dba:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f0103dbd:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0103dc0:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0103dc4:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0103dc7:	8d 58 d0             	lea    -0x30(%eax),%ebx
f0103dca:	83 fb 09             	cmp    $0x9,%ebx
f0103dcd:	76 eb                	jbe    f0103dba <vprintfmt+0xa6>
f0103dcf:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0103dd2:	eb 33                	jmp    f0103e07 <vprintfmt+0xf3>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0103dd4:	8b 45 14             	mov    0x14(%ebp),%eax
f0103dd7:	8d 48 04             	lea    0x4(%eax),%ecx
f0103dda:	89 4d 14             	mov    %ecx,0x14(%ebp)
f0103ddd:	8b 00                	mov    (%eax),%eax
f0103ddf:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103de2:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0103de4:	eb 21                	jmp    f0103e07 <vprintfmt+0xf3>
f0103de6:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0103de9:	85 c9                	test   %ecx,%ecx
f0103deb:	b8 00 00 00 00       	mov    $0x0,%eax
f0103df0:	0f 49 c1             	cmovns %ecx,%eax
f0103df3:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103df6:	89 de                	mov    %ebx,%esi
f0103df8:	eb 8b                	jmp    f0103d85 <vprintfmt+0x71>
f0103dfa:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0103dfc:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f0103e03:	eb 80                	jmp    f0103d85 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103e05:	89 de                	mov    %ebx,%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0103e07:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0103e0b:	0f 89 74 ff ff ff    	jns    f0103d85 <vprintfmt+0x71>
f0103e11:	e9 62 ff ff ff       	jmp    f0103d78 <vprintfmt+0x64>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0103e16:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103e19:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f0103e1b:	e9 65 ff ff ff       	jmp    f0103d85 <vprintfmt+0x71>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f0103e20:	8b 45 14             	mov    0x14(%ebp),%eax
f0103e23:	8d 50 04             	lea    0x4(%eax),%edx
f0103e26:	89 55 14             	mov    %edx,0x14(%ebp)
f0103e29:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103e2d:	8b 00                	mov    (%eax),%eax
f0103e2f:	89 04 24             	mov    %eax,(%esp)
f0103e32:	ff 55 08             	call   *0x8(%ebp)
			break;
f0103e35:	e9 03 ff ff ff       	jmp    f0103d3d <vprintfmt+0x29>

		// error message
		case 'e':
			err = va_arg(ap, int);
f0103e3a:	8b 45 14             	mov    0x14(%ebp),%eax
f0103e3d:	8d 50 04             	lea    0x4(%eax),%edx
f0103e40:	89 55 14             	mov    %edx,0x14(%ebp)
f0103e43:	8b 00                	mov    (%eax),%eax
f0103e45:	99                   	cltd   
f0103e46:	31 d0                	xor    %edx,%eax
f0103e48:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0103e4a:	83 f8 06             	cmp    $0x6,%eax
f0103e4d:	7f 0b                	jg     f0103e5a <vprintfmt+0x146>
f0103e4f:	8b 14 85 24 5f 10 f0 	mov    -0xfefa0dc(,%eax,4),%edx
f0103e56:	85 d2                	test   %edx,%edx
f0103e58:	75 20                	jne    f0103e7a <vprintfmt+0x166>
				printfmt(putch, putdat, "error %d", err);
f0103e5a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103e5e:	c7 44 24 08 59 5d 10 	movl   $0xf0105d59,0x8(%esp)
f0103e65:	f0 
f0103e66:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103e6a:	8b 45 08             	mov    0x8(%ebp),%eax
f0103e6d:	89 04 24             	mov    %eax,(%esp)
f0103e70:	e8 77 fe ff ff       	call   f0103cec <printfmt>
f0103e75:	e9 c3 fe ff ff       	jmp    f0103d3d <vprintfmt+0x29>
			else
				printfmt(putch, putdat, "%s", p);
f0103e7a:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0103e7e:	c7 44 24 08 21 56 10 	movl   $0xf0105621,0x8(%esp)
f0103e85:	f0 
f0103e86:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103e8a:	8b 45 08             	mov    0x8(%ebp),%eax
f0103e8d:	89 04 24             	mov    %eax,(%esp)
f0103e90:	e8 57 fe ff ff       	call   f0103cec <printfmt>
f0103e95:	e9 a3 fe ff ff       	jmp    f0103d3d <vprintfmt+0x29>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103e9a:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0103e9d:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0103ea0:	8b 45 14             	mov    0x14(%ebp),%eax
f0103ea3:	8d 50 04             	lea    0x4(%eax),%edx
f0103ea6:	89 55 14             	mov    %edx,0x14(%ebp)
f0103ea9:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f0103eab:	85 c0                	test   %eax,%eax
f0103ead:	ba 52 5d 10 f0       	mov    $0xf0105d52,%edx
f0103eb2:	0f 45 d0             	cmovne %eax,%edx
f0103eb5:	89 55 d0             	mov    %edx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f0103eb8:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f0103ebc:	74 04                	je     f0103ec2 <vprintfmt+0x1ae>
f0103ebe:	85 f6                	test   %esi,%esi
f0103ec0:	7f 19                	jg     f0103edb <vprintfmt+0x1c7>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0103ec2:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103ec5:	8d 70 01             	lea    0x1(%eax),%esi
f0103ec8:	0f b6 10             	movzbl (%eax),%edx
f0103ecb:	0f be c2             	movsbl %dl,%eax
f0103ece:	85 c0                	test   %eax,%eax
f0103ed0:	0f 85 95 00 00 00    	jne    f0103f6b <vprintfmt+0x257>
f0103ed6:	e9 85 00 00 00       	jmp    f0103f60 <vprintfmt+0x24c>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0103edb:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0103edf:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103ee2:	89 04 24             	mov    %eax,(%esp)
f0103ee5:	e8 88 03 00 00       	call   f0104272 <strnlen>
f0103eea:	29 c6                	sub    %eax,%esi
f0103eec:	89 f0                	mov    %esi,%eax
f0103eee:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0103ef1:	85 f6                	test   %esi,%esi
f0103ef3:	7e cd                	jle    f0103ec2 <vprintfmt+0x1ae>
					putch(padc, putdat);
f0103ef5:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0103ef9:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0103efc:	89 c3                	mov    %eax,%ebx
f0103efe:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103f02:	89 34 24             	mov    %esi,(%esp)
f0103f05:	ff 55 08             	call   *0x8(%ebp)
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0103f08:	83 eb 01             	sub    $0x1,%ebx
f0103f0b:	75 f1                	jne    f0103efe <vprintfmt+0x1ea>
f0103f0d:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0103f10:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0103f13:	eb ad                	jmp    f0103ec2 <vprintfmt+0x1ae>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f0103f15:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0103f19:	74 1e                	je     f0103f39 <vprintfmt+0x225>
f0103f1b:	0f be d2             	movsbl %dl,%edx
f0103f1e:	83 ea 20             	sub    $0x20,%edx
f0103f21:	83 fa 5e             	cmp    $0x5e,%edx
f0103f24:	76 13                	jbe    f0103f39 <vprintfmt+0x225>
					putch('?', putdat);
f0103f26:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103f29:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103f2d:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f0103f34:	ff 55 08             	call   *0x8(%ebp)
f0103f37:	eb 0d                	jmp    f0103f46 <vprintfmt+0x232>
				else
					putch(ch, putdat);
f0103f39:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0103f3c:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0103f40:	89 04 24             	mov    %eax,(%esp)
f0103f43:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0103f46:	83 ef 01             	sub    $0x1,%edi
f0103f49:	83 c6 01             	add    $0x1,%esi
f0103f4c:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f0103f50:	0f be c2             	movsbl %dl,%eax
f0103f53:	85 c0                	test   %eax,%eax
f0103f55:	75 20                	jne    f0103f77 <vprintfmt+0x263>
f0103f57:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f0103f5a:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0103f5d:	8b 5d 10             	mov    0x10(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0103f60:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0103f64:	7f 25                	jg     f0103f8b <vprintfmt+0x277>
f0103f66:	e9 d2 fd ff ff       	jmp    f0103d3d <vprintfmt+0x29>
f0103f6b:	89 7d 0c             	mov    %edi,0xc(%ebp)
f0103f6e:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0103f71:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0103f74:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0103f77:	85 db                	test   %ebx,%ebx
f0103f79:	78 9a                	js     f0103f15 <vprintfmt+0x201>
f0103f7b:	83 eb 01             	sub    $0x1,%ebx
f0103f7e:	79 95                	jns    f0103f15 <vprintfmt+0x201>
f0103f80:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f0103f83:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0103f86:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0103f89:	eb d5                	jmp    f0103f60 <vprintfmt+0x24c>
f0103f8b:	8b 75 08             	mov    0x8(%ebp),%esi
f0103f8e:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0103f91:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0103f94:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103f98:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f0103f9f:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0103fa1:	83 eb 01             	sub    $0x1,%ebx
f0103fa4:	75 ee                	jne    f0103f94 <vprintfmt+0x280>
f0103fa6:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0103fa9:	e9 8f fd ff ff       	jmp    f0103d3d <vprintfmt+0x29>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f0103fae:	83 fa 01             	cmp    $0x1,%edx
f0103fb1:	7e 16                	jle    f0103fc9 <vprintfmt+0x2b5>
		return va_arg(*ap, long long);
f0103fb3:	8b 45 14             	mov    0x14(%ebp),%eax
f0103fb6:	8d 50 08             	lea    0x8(%eax),%edx
f0103fb9:	89 55 14             	mov    %edx,0x14(%ebp)
f0103fbc:	8b 50 04             	mov    0x4(%eax),%edx
f0103fbf:	8b 00                	mov    (%eax),%eax
f0103fc1:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103fc4:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0103fc7:	eb 32                	jmp    f0103ffb <vprintfmt+0x2e7>
	else if (lflag)
f0103fc9:	85 d2                	test   %edx,%edx
f0103fcb:	74 18                	je     f0103fe5 <vprintfmt+0x2d1>
		return va_arg(*ap, long);
f0103fcd:	8b 45 14             	mov    0x14(%ebp),%eax
f0103fd0:	8d 50 04             	lea    0x4(%eax),%edx
f0103fd3:	89 55 14             	mov    %edx,0x14(%ebp)
f0103fd6:	8b 30                	mov    (%eax),%esi
f0103fd8:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0103fdb:	89 f0                	mov    %esi,%eax
f0103fdd:	c1 f8 1f             	sar    $0x1f,%eax
f0103fe0:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0103fe3:	eb 16                	jmp    f0103ffb <vprintfmt+0x2e7>
	else
		return va_arg(*ap, int);
f0103fe5:	8b 45 14             	mov    0x14(%ebp),%eax
f0103fe8:	8d 50 04             	lea    0x4(%eax),%edx
f0103feb:	89 55 14             	mov    %edx,0x14(%ebp)
f0103fee:	8b 30                	mov    (%eax),%esi
f0103ff0:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0103ff3:	89 f0                	mov    %esi,%eax
f0103ff5:	c1 f8 1f             	sar    $0x1f,%eax
f0103ff8:	89 45 dc             	mov    %eax,-0x24(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f0103ffb:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103ffe:	8b 55 dc             	mov    -0x24(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f0104001:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0104006:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f010400a:	0f 89 80 00 00 00    	jns    f0104090 <vprintfmt+0x37c>
				putch('-', putdat);
f0104010:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104014:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f010401b:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f010401e:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0104021:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0104024:	f7 d8                	neg    %eax
f0104026:	83 d2 00             	adc    $0x0,%edx
f0104029:	f7 da                	neg    %edx
			}
			base = 10;
f010402b:	b9 0a 00 00 00       	mov    $0xa,%ecx
f0104030:	eb 5e                	jmp    f0104090 <vprintfmt+0x37c>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f0104032:	8d 45 14             	lea    0x14(%ebp),%eax
f0104035:	e8 5b fc ff ff       	call   f0103c95 <getuint>
			base = 10;
f010403a:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f010403f:	eb 4f                	jmp    f0104090 <vprintfmt+0x37c>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			//putch('X', putdat);
			num = getuint(&ap, lflag);
f0104041:	8d 45 14             	lea    0x14(%ebp),%eax
f0104044:	e8 4c fc ff ff       	call   f0103c95 <getuint>
			base = 8;
f0104049:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f010404e:	eb 40                	jmp    f0104090 <vprintfmt+0x37c>
			//putch('X', putdat);
			//break;

		// pointer
		case 'p':
			putch('0', putdat);
f0104050:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104054:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f010405b:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f010405e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104062:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f0104069:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f010406c:	8b 45 14             	mov    0x14(%ebp),%eax
f010406f:	8d 50 04             	lea    0x4(%eax),%edx
f0104072:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f0104075:	8b 00                	mov    (%eax),%eax
f0104077:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f010407c:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f0104081:	eb 0d                	jmp    f0104090 <vprintfmt+0x37c>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f0104083:	8d 45 14             	lea    0x14(%ebp),%eax
f0104086:	e8 0a fc ff ff       	call   f0103c95 <getuint>
			base = 16;
f010408b:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f0104090:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0104094:	89 74 24 10          	mov    %esi,0x10(%esp)
f0104098:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f010409b:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010409f:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01040a3:	89 04 24             	mov    %eax,(%esp)
f01040a6:	89 54 24 04          	mov    %edx,0x4(%esp)
f01040aa:	89 fa                	mov    %edi,%edx
f01040ac:	8b 45 08             	mov    0x8(%ebp),%eax
f01040af:	e8 ec fa ff ff       	call   f0103ba0 <printnum>
			break;
f01040b4:	e9 84 fc ff ff       	jmp    f0103d3d <vprintfmt+0x29>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f01040b9:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01040bd:	89 0c 24             	mov    %ecx,(%esp)
f01040c0:	ff 55 08             	call   *0x8(%ebp)
			break;
f01040c3:	e9 75 fc ff ff       	jmp    f0103d3d <vprintfmt+0x29>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f01040c8:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01040cc:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f01040d3:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f01040d6:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f01040da:	0f 84 5b fc ff ff    	je     f0103d3b <vprintfmt+0x27>
f01040e0:	89 f3                	mov    %esi,%ebx
f01040e2:	83 eb 01             	sub    $0x1,%ebx
f01040e5:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f01040e9:	75 f7                	jne    f01040e2 <vprintfmt+0x3ce>
f01040eb:	e9 4d fc ff ff       	jmp    f0103d3d <vprintfmt+0x29>
				/* do nothing */;
			break;
		}
	}
}
f01040f0:	83 c4 3c             	add    $0x3c,%esp
f01040f3:	5b                   	pop    %ebx
f01040f4:	5e                   	pop    %esi
f01040f5:	5f                   	pop    %edi
f01040f6:	5d                   	pop    %ebp
f01040f7:	c3                   	ret    

f01040f8 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f01040f8:	55                   	push   %ebp
f01040f9:	89 e5                	mov    %esp,%ebp
f01040fb:	83 ec 28             	sub    $0x28,%esp
f01040fe:	8b 45 08             	mov    0x8(%ebp),%eax
f0104101:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0104104:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0104107:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f010410b:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f010410e:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0104115:	85 c0                	test   %eax,%eax
f0104117:	74 30                	je     f0104149 <vsnprintf+0x51>
f0104119:	85 d2                	test   %edx,%edx
f010411b:	7e 2c                	jle    f0104149 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f010411d:	8b 45 14             	mov    0x14(%ebp),%eax
f0104120:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104124:	8b 45 10             	mov    0x10(%ebp),%eax
f0104127:	89 44 24 08          	mov    %eax,0x8(%esp)
f010412b:	8d 45 ec             	lea    -0x14(%ebp),%eax
f010412e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104132:	c7 04 24 cf 3c 10 f0 	movl   $0xf0103ccf,(%esp)
f0104139:	e8 d6 fb ff ff       	call   f0103d14 <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f010413e:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0104141:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0104144:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0104147:	eb 05                	jmp    f010414e <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f0104149:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f010414e:	c9                   	leave  
f010414f:	c3                   	ret    

f0104150 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f0104150:	55                   	push   %ebp
f0104151:	89 e5                	mov    %esp,%ebp
f0104153:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0104156:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f0104159:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010415d:	8b 45 10             	mov    0x10(%ebp),%eax
f0104160:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104164:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104167:	89 44 24 04          	mov    %eax,0x4(%esp)
f010416b:	8b 45 08             	mov    0x8(%ebp),%eax
f010416e:	89 04 24             	mov    %eax,(%esp)
f0104171:	e8 82 ff ff ff       	call   f01040f8 <vsnprintf>
	va_end(ap);

	return rc;
}
f0104176:	c9                   	leave  
f0104177:	c3                   	ret    
f0104178:	66 90                	xchg   %ax,%ax
f010417a:	66 90                	xchg   %ax,%ax
f010417c:	66 90                	xchg   %ax,%ax
f010417e:	66 90                	xchg   %ax,%ax

f0104180 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0104180:	55                   	push   %ebp
f0104181:	89 e5                	mov    %esp,%ebp
f0104183:	57                   	push   %edi
f0104184:	56                   	push   %esi
f0104185:	53                   	push   %ebx
f0104186:	83 ec 1c             	sub    $0x1c,%esp
f0104189:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f010418c:	85 c0                	test   %eax,%eax
f010418e:	74 10                	je     f01041a0 <readline+0x20>
		cprintf("%s", prompt);
f0104190:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104194:	c7 04 24 21 56 10 f0 	movl   $0xf0105621,(%esp)
f010419b:	e8 9a f2 ff ff       	call   f010343a <cprintf>

	i = 0;
	echoing = iscons(0);
f01041a0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01041a7:	e8 a9 c4 ff ff       	call   f0100655 <iscons>
f01041ac:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f01041ae:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f01041b3:	e8 8c c4 ff ff       	call   f0100644 <getchar>
f01041b8:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f01041ba:	85 c0                	test   %eax,%eax
f01041bc:	79 17                	jns    f01041d5 <readline+0x55>
			cprintf("read error: %e\n", c);
f01041be:	89 44 24 04          	mov    %eax,0x4(%esp)
f01041c2:	c7 04 24 40 5f 10 f0 	movl   $0xf0105f40,(%esp)
f01041c9:	e8 6c f2 ff ff       	call   f010343a <cprintf>
			return NULL;
f01041ce:	b8 00 00 00 00       	mov    $0x0,%eax
f01041d3:	eb 6d                	jmp    f0104242 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f01041d5:	83 f8 7f             	cmp    $0x7f,%eax
f01041d8:	74 05                	je     f01041df <readline+0x5f>
f01041da:	83 f8 08             	cmp    $0x8,%eax
f01041dd:	75 19                	jne    f01041f8 <readline+0x78>
f01041df:	85 f6                	test   %esi,%esi
f01041e1:	7e 15                	jle    f01041f8 <readline+0x78>
			if (echoing)
f01041e3:	85 ff                	test   %edi,%edi
f01041e5:	74 0c                	je     f01041f3 <readline+0x73>
				cputchar('\b');
f01041e7:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f01041ee:	e8 41 c4 ff ff       	call   f0100634 <cputchar>
			i--;
f01041f3:	83 ee 01             	sub    $0x1,%esi
f01041f6:	eb bb                	jmp    f01041b3 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f01041f8:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f01041fe:	7f 1c                	jg     f010421c <readline+0x9c>
f0104200:	83 fb 1f             	cmp    $0x1f,%ebx
f0104203:	7e 17                	jle    f010421c <readline+0x9c>
			if (echoing)
f0104205:	85 ff                	test   %edi,%edi
f0104207:	74 08                	je     f0104211 <readline+0x91>
				cputchar(c);
f0104209:	89 1c 24             	mov    %ebx,(%esp)
f010420c:	e8 23 c4 ff ff       	call   f0100634 <cputchar>
			buf[i++] = c;
f0104211:	88 9e c0 cb 17 f0    	mov    %bl,-0xfe83440(%esi)
f0104217:	8d 76 01             	lea    0x1(%esi),%esi
f010421a:	eb 97                	jmp    f01041b3 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f010421c:	83 fb 0d             	cmp    $0xd,%ebx
f010421f:	74 05                	je     f0104226 <readline+0xa6>
f0104221:	83 fb 0a             	cmp    $0xa,%ebx
f0104224:	75 8d                	jne    f01041b3 <readline+0x33>
			if (echoing)
f0104226:	85 ff                	test   %edi,%edi
f0104228:	74 0c                	je     f0104236 <readline+0xb6>
				cputchar('\n');
f010422a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0104231:	e8 fe c3 ff ff       	call   f0100634 <cputchar>
			buf[i] = 0;
f0104236:	c6 86 c0 cb 17 f0 00 	movb   $0x0,-0xfe83440(%esi)
			return buf;
f010423d:	b8 c0 cb 17 f0       	mov    $0xf017cbc0,%eax
		}
	}
}
f0104242:	83 c4 1c             	add    $0x1c,%esp
f0104245:	5b                   	pop    %ebx
f0104246:	5e                   	pop    %esi
f0104247:	5f                   	pop    %edi
f0104248:	5d                   	pop    %ebp
f0104249:	c3                   	ret    
f010424a:	66 90                	xchg   %ax,%ax
f010424c:	66 90                	xchg   %ax,%ax
f010424e:	66 90                	xchg   %ax,%ax

f0104250 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0104250:	55                   	push   %ebp
f0104251:	89 e5                	mov    %esp,%ebp
f0104253:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0104256:	80 3a 00             	cmpb   $0x0,(%edx)
f0104259:	74 10                	je     f010426b <strlen+0x1b>
f010425b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f0104260:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0104263:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0104267:	75 f7                	jne    f0104260 <strlen+0x10>
f0104269:	eb 05                	jmp    f0104270 <strlen+0x20>
f010426b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0104270:	5d                   	pop    %ebp
f0104271:	c3                   	ret    

f0104272 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0104272:	55                   	push   %ebp
f0104273:	89 e5                	mov    %esp,%ebp
f0104275:	53                   	push   %ebx
f0104276:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0104279:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010427c:	85 c9                	test   %ecx,%ecx
f010427e:	74 1c                	je     f010429c <strnlen+0x2a>
f0104280:	80 3b 00             	cmpb   $0x0,(%ebx)
f0104283:	74 1e                	je     f01042a3 <strnlen+0x31>
f0104285:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f010428a:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010428c:	39 ca                	cmp    %ecx,%edx
f010428e:	74 18                	je     f01042a8 <strnlen+0x36>
f0104290:	83 c2 01             	add    $0x1,%edx
f0104293:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0104298:	75 f0                	jne    f010428a <strnlen+0x18>
f010429a:	eb 0c                	jmp    f01042a8 <strnlen+0x36>
f010429c:	b8 00 00 00 00       	mov    $0x0,%eax
f01042a1:	eb 05                	jmp    f01042a8 <strnlen+0x36>
f01042a3:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f01042a8:	5b                   	pop    %ebx
f01042a9:	5d                   	pop    %ebp
f01042aa:	c3                   	ret    

f01042ab <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f01042ab:	55                   	push   %ebp
f01042ac:	89 e5                	mov    %esp,%ebp
f01042ae:	53                   	push   %ebx
f01042af:	8b 45 08             	mov    0x8(%ebp),%eax
f01042b2:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f01042b5:	89 c2                	mov    %eax,%edx
f01042b7:	83 c2 01             	add    $0x1,%edx
f01042ba:	83 c1 01             	add    $0x1,%ecx
f01042bd:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f01042c1:	88 5a ff             	mov    %bl,-0x1(%edx)
f01042c4:	84 db                	test   %bl,%bl
f01042c6:	75 ef                	jne    f01042b7 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f01042c8:	5b                   	pop    %ebx
f01042c9:	5d                   	pop    %ebp
f01042ca:	c3                   	ret    

f01042cb <strcat>:

char *
strcat(char *dst, const char *src)
{
f01042cb:	55                   	push   %ebp
f01042cc:	89 e5                	mov    %esp,%ebp
f01042ce:	53                   	push   %ebx
f01042cf:	83 ec 08             	sub    $0x8,%esp
f01042d2:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f01042d5:	89 1c 24             	mov    %ebx,(%esp)
f01042d8:	e8 73 ff ff ff       	call   f0104250 <strlen>
	strcpy(dst + len, src);
f01042dd:	8b 55 0c             	mov    0xc(%ebp),%edx
f01042e0:	89 54 24 04          	mov    %edx,0x4(%esp)
f01042e4:	01 d8                	add    %ebx,%eax
f01042e6:	89 04 24             	mov    %eax,(%esp)
f01042e9:	e8 bd ff ff ff       	call   f01042ab <strcpy>
	return dst;
}
f01042ee:	89 d8                	mov    %ebx,%eax
f01042f0:	83 c4 08             	add    $0x8,%esp
f01042f3:	5b                   	pop    %ebx
f01042f4:	5d                   	pop    %ebp
f01042f5:	c3                   	ret    

f01042f6 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f01042f6:	55                   	push   %ebp
f01042f7:	89 e5                	mov    %esp,%ebp
f01042f9:	56                   	push   %esi
f01042fa:	53                   	push   %ebx
f01042fb:	8b 75 08             	mov    0x8(%ebp),%esi
f01042fe:	8b 55 0c             	mov    0xc(%ebp),%edx
f0104301:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0104304:	85 db                	test   %ebx,%ebx
f0104306:	74 17                	je     f010431f <strncpy+0x29>
f0104308:	01 f3                	add    %esi,%ebx
f010430a:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f010430c:	83 c1 01             	add    $0x1,%ecx
f010430f:	0f b6 02             	movzbl (%edx),%eax
f0104312:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f0104315:	80 3a 01             	cmpb   $0x1,(%edx)
f0104318:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f010431b:	39 d9                	cmp    %ebx,%ecx
f010431d:	75 ed                	jne    f010430c <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f010431f:	89 f0                	mov    %esi,%eax
f0104321:	5b                   	pop    %ebx
f0104322:	5e                   	pop    %esi
f0104323:	5d                   	pop    %ebp
f0104324:	c3                   	ret    

f0104325 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f0104325:	55                   	push   %ebp
f0104326:	89 e5                	mov    %esp,%ebp
f0104328:	57                   	push   %edi
f0104329:	56                   	push   %esi
f010432a:	53                   	push   %ebx
f010432b:	8b 7d 08             	mov    0x8(%ebp),%edi
f010432e:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0104331:	8b 75 10             	mov    0x10(%ebp),%esi
f0104334:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0104336:	85 f6                	test   %esi,%esi
f0104338:	74 34                	je     f010436e <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f010433a:	83 fe 01             	cmp    $0x1,%esi
f010433d:	74 26                	je     f0104365 <strlcpy+0x40>
f010433f:	0f b6 0b             	movzbl (%ebx),%ecx
f0104342:	84 c9                	test   %cl,%cl
f0104344:	74 23                	je     f0104369 <strlcpy+0x44>
f0104346:	83 ee 02             	sub    $0x2,%esi
f0104349:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f010434e:	83 c0 01             	add    $0x1,%eax
f0104351:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0104354:	39 f2                	cmp    %esi,%edx
f0104356:	74 13                	je     f010436b <strlcpy+0x46>
f0104358:	83 c2 01             	add    $0x1,%edx
f010435b:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f010435f:	84 c9                	test   %cl,%cl
f0104361:	75 eb                	jne    f010434e <strlcpy+0x29>
f0104363:	eb 06                	jmp    f010436b <strlcpy+0x46>
f0104365:	89 f8                	mov    %edi,%eax
f0104367:	eb 02                	jmp    f010436b <strlcpy+0x46>
f0104369:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f010436b:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f010436e:	29 f8                	sub    %edi,%eax
}
f0104370:	5b                   	pop    %ebx
f0104371:	5e                   	pop    %esi
f0104372:	5f                   	pop    %edi
f0104373:	5d                   	pop    %ebp
f0104374:	c3                   	ret    

f0104375 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f0104375:	55                   	push   %ebp
f0104376:	89 e5                	mov    %esp,%ebp
f0104378:	8b 4d 08             	mov    0x8(%ebp),%ecx
f010437b:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f010437e:	0f b6 01             	movzbl (%ecx),%eax
f0104381:	84 c0                	test   %al,%al
f0104383:	74 15                	je     f010439a <strcmp+0x25>
f0104385:	3a 02                	cmp    (%edx),%al
f0104387:	75 11                	jne    f010439a <strcmp+0x25>
		p++, q++;
f0104389:	83 c1 01             	add    $0x1,%ecx
f010438c:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f010438f:	0f b6 01             	movzbl (%ecx),%eax
f0104392:	84 c0                	test   %al,%al
f0104394:	74 04                	je     f010439a <strcmp+0x25>
f0104396:	3a 02                	cmp    (%edx),%al
f0104398:	74 ef                	je     f0104389 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f010439a:	0f b6 c0             	movzbl %al,%eax
f010439d:	0f b6 12             	movzbl (%edx),%edx
f01043a0:	29 d0                	sub    %edx,%eax
}
f01043a2:	5d                   	pop    %ebp
f01043a3:	c3                   	ret    

f01043a4 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f01043a4:	55                   	push   %ebp
f01043a5:	89 e5                	mov    %esp,%ebp
f01043a7:	56                   	push   %esi
f01043a8:	53                   	push   %ebx
f01043a9:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01043ac:	8b 55 0c             	mov    0xc(%ebp),%edx
f01043af:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f01043b2:	85 f6                	test   %esi,%esi
f01043b4:	74 29                	je     f01043df <strncmp+0x3b>
f01043b6:	0f b6 03             	movzbl (%ebx),%eax
f01043b9:	84 c0                	test   %al,%al
f01043bb:	74 30                	je     f01043ed <strncmp+0x49>
f01043bd:	3a 02                	cmp    (%edx),%al
f01043bf:	75 2c                	jne    f01043ed <strncmp+0x49>
f01043c1:	8d 43 01             	lea    0x1(%ebx),%eax
f01043c4:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f01043c6:	89 c3                	mov    %eax,%ebx
f01043c8:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f01043cb:	39 f0                	cmp    %esi,%eax
f01043cd:	74 17                	je     f01043e6 <strncmp+0x42>
f01043cf:	0f b6 08             	movzbl (%eax),%ecx
f01043d2:	84 c9                	test   %cl,%cl
f01043d4:	74 17                	je     f01043ed <strncmp+0x49>
f01043d6:	83 c0 01             	add    $0x1,%eax
f01043d9:	3a 0a                	cmp    (%edx),%cl
f01043db:	74 e9                	je     f01043c6 <strncmp+0x22>
f01043dd:	eb 0e                	jmp    f01043ed <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f01043df:	b8 00 00 00 00       	mov    $0x0,%eax
f01043e4:	eb 0f                	jmp    f01043f5 <strncmp+0x51>
f01043e6:	b8 00 00 00 00       	mov    $0x0,%eax
f01043eb:	eb 08                	jmp    f01043f5 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f01043ed:	0f b6 03             	movzbl (%ebx),%eax
f01043f0:	0f b6 12             	movzbl (%edx),%edx
f01043f3:	29 d0                	sub    %edx,%eax
}
f01043f5:	5b                   	pop    %ebx
f01043f6:	5e                   	pop    %esi
f01043f7:	5d                   	pop    %ebp
f01043f8:	c3                   	ret    

f01043f9 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f01043f9:	55                   	push   %ebp
f01043fa:	89 e5                	mov    %esp,%ebp
f01043fc:	53                   	push   %ebx
f01043fd:	8b 45 08             	mov    0x8(%ebp),%eax
f0104400:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0104403:	0f b6 18             	movzbl (%eax),%ebx
f0104406:	84 db                	test   %bl,%bl
f0104408:	74 1d                	je     f0104427 <strchr+0x2e>
f010440a:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f010440c:	38 d3                	cmp    %dl,%bl
f010440e:	75 06                	jne    f0104416 <strchr+0x1d>
f0104410:	eb 1a                	jmp    f010442c <strchr+0x33>
f0104412:	38 ca                	cmp    %cl,%dl
f0104414:	74 16                	je     f010442c <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0104416:	83 c0 01             	add    $0x1,%eax
f0104419:	0f b6 10             	movzbl (%eax),%edx
f010441c:	84 d2                	test   %dl,%dl
f010441e:	75 f2                	jne    f0104412 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0104420:	b8 00 00 00 00       	mov    $0x0,%eax
f0104425:	eb 05                	jmp    f010442c <strchr+0x33>
f0104427:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010442c:	5b                   	pop    %ebx
f010442d:	5d                   	pop    %ebp
f010442e:	c3                   	ret    

f010442f <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f010442f:	55                   	push   %ebp
f0104430:	89 e5                	mov    %esp,%ebp
f0104432:	53                   	push   %ebx
f0104433:	8b 45 08             	mov    0x8(%ebp),%eax
f0104436:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0104439:	0f b6 18             	movzbl (%eax),%ebx
f010443c:	84 db                	test   %bl,%bl
f010443e:	74 16                	je     f0104456 <strfind+0x27>
f0104440:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0104442:	38 d3                	cmp    %dl,%bl
f0104444:	75 06                	jne    f010444c <strfind+0x1d>
f0104446:	eb 0e                	jmp    f0104456 <strfind+0x27>
f0104448:	38 ca                	cmp    %cl,%dl
f010444a:	74 0a                	je     f0104456 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f010444c:	83 c0 01             	add    $0x1,%eax
f010444f:	0f b6 10             	movzbl (%eax),%edx
f0104452:	84 d2                	test   %dl,%dl
f0104454:	75 f2                	jne    f0104448 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f0104456:	5b                   	pop    %ebx
f0104457:	5d                   	pop    %ebp
f0104458:	c3                   	ret    

f0104459 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f0104459:	55                   	push   %ebp
f010445a:	89 e5                	mov    %esp,%ebp
f010445c:	57                   	push   %edi
f010445d:	56                   	push   %esi
f010445e:	53                   	push   %ebx
f010445f:	8b 7d 08             	mov    0x8(%ebp),%edi
f0104462:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0104465:	85 c9                	test   %ecx,%ecx
f0104467:	74 36                	je     f010449f <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f0104469:	f7 c7 03 00 00 00    	test   $0x3,%edi
f010446f:	75 28                	jne    f0104499 <memset+0x40>
f0104471:	f6 c1 03             	test   $0x3,%cl
f0104474:	75 23                	jne    f0104499 <memset+0x40>
		c &= 0xFF;
f0104476:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f010447a:	89 d3                	mov    %edx,%ebx
f010447c:	c1 e3 08             	shl    $0x8,%ebx
f010447f:	89 d6                	mov    %edx,%esi
f0104481:	c1 e6 18             	shl    $0x18,%esi
f0104484:	89 d0                	mov    %edx,%eax
f0104486:	c1 e0 10             	shl    $0x10,%eax
f0104489:	09 f0                	or     %esi,%eax
f010448b:	09 c2                	or     %eax,%edx
f010448d:	89 d0                	mov    %edx,%eax
f010448f:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f0104491:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0104494:	fc                   	cld    
f0104495:	f3 ab                	rep stos %eax,%es:(%edi)
f0104497:	eb 06                	jmp    f010449f <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0104499:	8b 45 0c             	mov    0xc(%ebp),%eax
f010449c:	fc                   	cld    
f010449d:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f010449f:	89 f8                	mov    %edi,%eax
f01044a1:	5b                   	pop    %ebx
f01044a2:	5e                   	pop    %esi
f01044a3:	5f                   	pop    %edi
f01044a4:	5d                   	pop    %ebp
f01044a5:	c3                   	ret    

f01044a6 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f01044a6:	55                   	push   %ebp
f01044a7:	89 e5                	mov    %esp,%ebp
f01044a9:	57                   	push   %edi
f01044aa:	56                   	push   %esi
f01044ab:	8b 45 08             	mov    0x8(%ebp),%eax
f01044ae:	8b 75 0c             	mov    0xc(%ebp),%esi
f01044b1:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f01044b4:	39 c6                	cmp    %eax,%esi
f01044b6:	73 35                	jae    f01044ed <memmove+0x47>
f01044b8:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f01044bb:	39 d0                	cmp    %edx,%eax
f01044bd:	73 2e                	jae    f01044ed <memmove+0x47>
		s += n;
		d += n;
f01044bf:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f01044c2:	89 d6                	mov    %edx,%esi
f01044c4:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f01044c6:	f7 c6 03 00 00 00    	test   $0x3,%esi
f01044cc:	75 13                	jne    f01044e1 <memmove+0x3b>
f01044ce:	f6 c1 03             	test   $0x3,%cl
f01044d1:	75 0e                	jne    f01044e1 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f01044d3:	83 ef 04             	sub    $0x4,%edi
f01044d6:	8d 72 fc             	lea    -0x4(%edx),%esi
f01044d9:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f01044dc:	fd                   	std    
f01044dd:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f01044df:	eb 09                	jmp    f01044ea <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f01044e1:	83 ef 01             	sub    $0x1,%edi
f01044e4:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f01044e7:	fd                   	std    
f01044e8:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f01044ea:	fc                   	cld    
f01044eb:	eb 1d                	jmp    f010450a <memmove+0x64>
f01044ed:	89 f2                	mov    %esi,%edx
f01044ef:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f01044f1:	f6 c2 03             	test   $0x3,%dl
f01044f4:	75 0f                	jne    f0104505 <memmove+0x5f>
f01044f6:	f6 c1 03             	test   $0x3,%cl
f01044f9:	75 0a                	jne    f0104505 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f01044fb:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f01044fe:	89 c7                	mov    %eax,%edi
f0104500:	fc                   	cld    
f0104501:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0104503:	eb 05                	jmp    f010450a <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0104505:	89 c7                	mov    %eax,%edi
f0104507:	fc                   	cld    
f0104508:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f010450a:	5e                   	pop    %esi
f010450b:	5f                   	pop    %edi
f010450c:	5d                   	pop    %ebp
f010450d:	c3                   	ret    

f010450e <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f010450e:	55                   	push   %ebp
f010450f:	89 e5                	mov    %esp,%ebp
f0104511:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0104514:	8b 45 10             	mov    0x10(%ebp),%eax
f0104517:	89 44 24 08          	mov    %eax,0x8(%esp)
f010451b:	8b 45 0c             	mov    0xc(%ebp),%eax
f010451e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104522:	8b 45 08             	mov    0x8(%ebp),%eax
f0104525:	89 04 24             	mov    %eax,(%esp)
f0104528:	e8 79 ff ff ff       	call   f01044a6 <memmove>
}
f010452d:	c9                   	leave  
f010452e:	c3                   	ret    

f010452f <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f010452f:	55                   	push   %ebp
f0104530:	89 e5                	mov    %esp,%ebp
f0104532:	57                   	push   %edi
f0104533:	56                   	push   %esi
f0104534:	53                   	push   %ebx
f0104535:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0104538:	8b 75 0c             	mov    0xc(%ebp),%esi
f010453b:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f010453e:	8d 78 ff             	lea    -0x1(%eax),%edi
f0104541:	85 c0                	test   %eax,%eax
f0104543:	74 36                	je     f010457b <memcmp+0x4c>
		if (*s1 != *s2)
f0104545:	0f b6 03             	movzbl (%ebx),%eax
f0104548:	0f b6 0e             	movzbl (%esi),%ecx
f010454b:	ba 00 00 00 00       	mov    $0x0,%edx
f0104550:	38 c8                	cmp    %cl,%al
f0104552:	74 1c                	je     f0104570 <memcmp+0x41>
f0104554:	eb 10                	jmp    f0104566 <memcmp+0x37>
f0104556:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f010455b:	83 c2 01             	add    $0x1,%edx
f010455e:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f0104562:	38 c8                	cmp    %cl,%al
f0104564:	74 0a                	je     f0104570 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f0104566:	0f b6 c0             	movzbl %al,%eax
f0104569:	0f b6 c9             	movzbl %cl,%ecx
f010456c:	29 c8                	sub    %ecx,%eax
f010456e:	eb 10                	jmp    f0104580 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0104570:	39 fa                	cmp    %edi,%edx
f0104572:	75 e2                	jne    f0104556 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f0104574:	b8 00 00 00 00       	mov    $0x0,%eax
f0104579:	eb 05                	jmp    f0104580 <memcmp+0x51>
f010457b:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0104580:	5b                   	pop    %ebx
f0104581:	5e                   	pop    %esi
f0104582:	5f                   	pop    %edi
f0104583:	5d                   	pop    %ebp
f0104584:	c3                   	ret    

f0104585 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0104585:	55                   	push   %ebp
f0104586:	89 e5                	mov    %esp,%ebp
f0104588:	53                   	push   %ebx
f0104589:	8b 45 08             	mov    0x8(%ebp),%eax
f010458c:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f010458f:	89 c2                	mov    %eax,%edx
f0104591:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0104594:	39 d0                	cmp    %edx,%eax
f0104596:	73 13                	jae    f01045ab <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f0104598:	89 d9                	mov    %ebx,%ecx
f010459a:	38 18                	cmp    %bl,(%eax)
f010459c:	75 06                	jne    f01045a4 <memfind+0x1f>
f010459e:	eb 0b                	jmp    f01045ab <memfind+0x26>
f01045a0:	38 08                	cmp    %cl,(%eax)
f01045a2:	74 07                	je     f01045ab <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f01045a4:	83 c0 01             	add    $0x1,%eax
f01045a7:	39 d0                	cmp    %edx,%eax
f01045a9:	75 f5                	jne    f01045a0 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f01045ab:	5b                   	pop    %ebx
f01045ac:	5d                   	pop    %ebp
f01045ad:	c3                   	ret    

f01045ae <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f01045ae:	55                   	push   %ebp
f01045af:	89 e5                	mov    %esp,%ebp
f01045b1:	57                   	push   %edi
f01045b2:	56                   	push   %esi
f01045b3:	53                   	push   %ebx
f01045b4:	8b 55 08             	mov    0x8(%ebp),%edx
f01045b7:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f01045ba:	0f b6 0a             	movzbl (%edx),%ecx
f01045bd:	80 f9 09             	cmp    $0x9,%cl
f01045c0:	74 05                	je     f01045c7 <strtol+0x19>
f01045c2:	80 f9 20             	cmp    $0x20,%cl
f01045c5:	75 10                	jne    f01045d7 <strtol+0x29>
		s++;
f01045c7:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f01045ca:	0f b6 0a             	movzbl (%edx),%ecx
f01045cd:	80 f9 09             	cmp    $0x9,%cl
f01045d0:	74 f5                	je     f01045c7 <strtol+0x19>
f01045d2:	80 f9 20             	cmp    $0x20,%cl
f01045d5:	74 f0                	je     f01045c7 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f01045d7:	80 f9 2b             	cmp    $0x2b,%cl
f01045da:	75 0a                	jne    f01045e6 <strtol+0x38>
		s++;
f01045dc:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f01045df:	bf 00 00 00 00       	mov    $0x0,%edi
f01045e4:	eb 11                	jmp    f01045f7 <strtol+0x49>
f01045e6:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f01045eb:	80 f9 2d             	cmp    $0x2d,%cl
f01045ee:	75 07                	jne    f01045f7 <strtol+0x49>
		s++, neg = 1;
f01045f0:	83 c2 01             	add    $0x1,%edx
f01045f3:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f01045f7:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f01045fc:	75 15                	jne    f0104613 <strtol+0x65>
f01045fe:	80 3a 30             	cmpb   $0x30,(%edx)
f0104601:	75 10                	jne    f0104613 <strtol+0x65>
f0104603:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0104607:	75 0a                	jne    f0104613 <strtol+0x65>
		s += 2, base = 16;
f0104609:	83 c2 02             	add    $0x2,%edx
f010460c:	b8 10 00 00 00       	mov    $0x10,%eax
f0104611:	eb 10                	jmp    f0104623 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f0104613:	85 c0                	test   %eax,%eax
f0104615:	75 0c                	jne    f0104623 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0104617:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0104619:	80 3a 30             	cmpb   $0x30,(%edx)
f010461c:	75 05                	jne    f0104623 <strtol+0x75>
		s++, base = 8;
f010461e:	83 c2 01             	add    $0x1,%edx
f0104621:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f0104623:	bb 00 00 00 00       	mov    $0x0,%ebx
f0104628:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f010462b:	0f b6 0a             	movzbl (%edx),%ecx
f010462e:	8d 71 d0             	lea    -0x30(%ecx),%esi
f0104631:	89 f0                	mov    %esi,%eax
f0104633:	3c 09                	cmp    $0x9,%al
f0104635:	77 08                	ja     f010463f <strtol+0x91>
			dig = *s - '0';
f0104637:	0f be c9             	movsbl %cl,%ecx
f010463a:	83 e9 30             	sub    $0x30,%ecx
f010463d:	eb 20                	jmp    f010465f <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f010463f:	8d 71 9f             	lea    -0x61(%ecx),%esi
f0104642:	89 f0                	mov    %esi,%eax
f0104644:	3c 19                	cmp    $0x19,%al
f0104646:	77 08                	ja     f0104650 <strtol+0xa2>
			dig = *s - 'a' + 10;
f0104648:	0f be c9             	movsbl %cl,%ecx
f010464b:	83 e9 57             	sub    $0x57,%ecx
f010464e:	eb 0f                	jmp    f010465f <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f0104650:	8d 71 bf             	lea    -0x41(%ecx),%esi
f0104653:	89 f0                	mov    %esi,%eax
f0104655:	3c 19                	cmp    $0x19,%al
f0104657:	77 16                	ja     f010466f <strtol+0xc1>
			dig = *s - 'A' + 10;
f0104659:	0f be c9             	movsbl %cl,%ecx
f010465c:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f010465f:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f0104662:	7d 0f                	jge    f0104673 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f0104664:	83 c2 01             	add    $0x1,%edx
f0104667:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f010466b:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f010466d:	eb bc                	jmp    f010462b <strtol+0x7d>
f010466f:	89 d8                	mov    %ebx,%eax
f0104671:	eb 02                	jmp    f0104675 <strtol+0xc7>
f0104673:	89 d8                	mov    %ebx,%eax

	if (endptr)
f0104675:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0104679:	74 05                	je     f0104680 <strtol+0xd2>
		*endptr = (char *) s;
f010467b:	8b 75 0c             	mov    0xc(%ebp),%esi
f010467e:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f0104680:	f7 d8                	neg    %eax
f0104682:	85 ff                	test   %edi,%edi
f0104684:	0f 44 c3             	cmove  %ebx,%eax
}
f0104687:	5b                   	pop    %ebx
f0104688:	5e                   	pop    %esi
f0104689:	5f                   	pop    %edi
f010468a:	5d                   	pop    %ebp
f010468b:	c3                   	ret    
f010468c:	66 90                	xchg   %ax,%ax
f010468e:	66 90                	xchg   %ax,%ax

f0104690 <__udivdi3>:
f0104690:	55                   	push   %ebp
f0104691:	57                   	push   %edi
f0104692:	56                   	push   %esi
f0104693:	83 ec 0c             	sub    $0xc,%esp
f0104696:	8b 44 24 28          	mov    0x28(%esp),%eax
f010469a:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f010469e:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f01046a2:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01046a6:	85 c0                	test   %eax,%eax
f01046a8:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01046ac:	89 ea                	mov    %ebp,%edx
f01046ae:	89 0c 24             	mov    %ecx,(%esp)
f01046b1:	75 2d                	jne    f01046e0 <__udivdi3+0x50>
f01046b3:	39 e9                	cmp    %ebp,%ecx
f01046b5:	77 61                	ja     f0104718 <__udivdi3+0x88>
f01046b7:	85 c9                	test   %ecx,%ecx
f01046b9:	89 ce                	mov    %ecx,%esi
f01046bb:	75 0b                	jne    f01046c8 <__udivdi3+0x38>
f01046bd:	b8 01 00 00 00       	mov    $0x1,%eax
f01046c2:	31 d2                	xor    %edx,%edx
f01046c4:	f7 f1                	div    %ecx
f01046c6:	89 c6                	mov    %eax,%esi
f01046c8:	31 d2                	xor    %edx,%edx
f01046ca:	89 e8                	mov    %ebp,%eax
f01046cc:	f7 f6                	div    %esi
f01046ce:	89 c5                	mov    %eax,%ebp
f01046d0:	89 f8                	mov    %edi,%eax
f01046d2:	f7 f6                	div    %esi
f01046d4:	89 ea                	mov    %ebp,%edx
f01046d6:	83 c4 0c             	add    $0xc,%esp
f01046d9:	5e                   	pop    %esi
f01046da:	5f                   	pop    %edi
f01046db:	5d                   	pop    %ebp
f01046dc:	c3                   	ret    
f01046dd:	8d 76 00             	lea    0x0(%esi),%esi
f01046e0:	39 e8                	cmp    %ebp,%eax
f01046e2:	77 24                	ja     f0104708 <__udivdi3+0x78>
f01046e4:	0f bd e8             	bsr    %eax,%ebp
f01046e7:	83 f5 1f             	xor    $0x1f,%ebp
f01046ea:	75 3c                	jne    f0104728 <__udivdi3+0x98>
f01046ec:	8b 74 24 04          	mov    0x4(%esp),%esi
f01046f0:	39 34 24             	cmp    %esi,(%esp)
f01046f3:	0f 86 9f 00 00 00    	jbe    f0104798 <__udivdi3+0x108>
f01046f9:	39 d0                	cmp    %edx,%eax
f01046fb:	0f 82 97 00 00 00    	jb     f0104798 <__udivdi3+0x108>
f0104701:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0104708:	31 d2                	xor    %edx,%edx
f010470a:	31 c0                	xor    %eax,%eax
f010470c:	83 c4 0c             	add    $0xc,%esp
f010470f:	5e                   	pop    %esi
f0104710:	5f                   	pop    %edi
f0104711:	5d                   	pop    %ebp
f0104712:	c3                   	ret    
f0104713:	90                   	nop
f0104714:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0104718:	89 f8                	mov    %edi,%eax
f010471a:	f7 f1                	div    %ecx
f010471c:	31 d2                	xor    %edx,%edx
f010471e:	83 c4 0c             	add    $0xc,%esp
f0104721:	5e                   	pop    %esi
f0104722:	5f                   	pop    %edi
f0104723:	5d                   	pop    %ebp
f0104724:	c3                   	ret    
f0104725:	8d 76 00             	lea    0x0(%esi),%esi
f0104728:	89 e9                	mov    %ebp,%ecx
f010472a:	8b 3c 24             	mov    (%esp),%edi
f010472d:	d3 e0                	shl    %cl,%eax
f010472f:	89 c6                	mov    %eax,%esi
f0104731:	b8 20 00 00 00       	mov    $0x20,%eax
f0104736:	29 e8                	sub    %ebp,%eax
f0104738:	89 c1                	mov    %eax,%ecx
f010473a:	d3 ef                	shr    %cl,%edi
f010473c:	89 e9                	mov    %ebp,%ecx
f010473e:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0104742:	8b 3c 24             	mov    (%esp),%edi
f0104745:	09 74 24 08          	or     %esi,0x8(%esp)
f0104749:	89 d6                	mov    %edx,%esi
f010474b:	d3 e7                	shl    %cl,%edi
f010474d:	89 c1                	mov    %eax,%ecx
f010474f:	89 3c 24             	mov    %edi,(%esp)
f0104752:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0104756:	d3 ee                	shr    %cl,%esi
f0104758:	89 e9                	mov    %ebp,%ecx
f010475a:	d3 e2                	shl    %cl,%edx
f010475c:	89 c1                	mov    %eax,%ecx
f010475e:	d3 ef                	shr    %cl,%edi
f0104760:	09 d7                	or     %edx,%edi
f0104762:	89 f2                	mov    %esi,%edx
f0104764:	89 f8                	mov    %edi,%eax
f0104766:	f7 74 24 08          	divl   0x8(%esp)
f010476a:	89 d6                	mov    %edx,%esi
f010476c:	89 c7                	mov    %eax,%edi
f010476e:	f7 24 24             	mull   (%esp)
f0104771:	39 d6                	cmp    %edx,%esi
f0104773:	89 14 24             	mov    %edx,(%esp)
f0104776:	72 30                	jb     f01047a8 <__udivdi3+0x118>
f0104778:	8b 54 24 04          	mov    0x4(%esp),%edx
f010477c:	89 e9                	mov    %ebp,%ecx
f010477e:	d3 e2                	shl    %cl,%edx
f0104780:	39 c2                	cmp    %eax,%edx
f0104782:	73 05                	jae    f0104789 <__udivdi3+0xf9>
f0104784:	3b 34 24             	cmp    (%esp),%esi
f0104787:	74 1f                	je     f01047a8 <__udivdi3+0x118>
f0104789:	89 f8                	mov    %edi,%eax
f010478b:	31 d2                	xor    %edx,%edx
f010478d:	e9 7a ff ff ff       	jmp    f010470c <__udivdi3+0x7c>
f0104792:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0104798:	31 d2                	xor    %edx,%edx
f010479a:	b8 01 00 00 00       	mov    $0x1,%eax
f010479f:	e9 68 ff ff ff       	jmp    f010470c <__udivdi3+0x7c>
f01047a4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01047a8:	8d 47 ff             	lea    -0x1(%edi),%eax
f01047ab:	31 d2                	xor    %edx,%edx
f01047ad:	83 c4 0c             	add    $0xc,%esp
f01047b0:	5e                   	pop    %esi
f01047b1:	5f                   	pop    %edi
f01047b2:	5d                   	pop    %ebp
f01047b3:	c3                   	ret    
f01047b4:	66 90                	xchg   %ax,%ax
f01047b6:	66 90                	xchg   %ax,%ax
f01047b8:	66 90                	xchg   %ax,%ax
f01047ba:	66 90                	xchg   %ax,%ax
f01047bc:	66 90                	xchg   %ax,%ax
f01047be:	66 90                	xchg   %ax,%ax

f01047c0 <__umoddi3>:
f01047c0:	55                   	push   %ebp
f01047c1:	57                   	push   %edi
f01047c2:	56                   	push   %esi
f01047c3:	83 ec 14             	sub    $0x14,%esp
f01047c6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01047ca:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01047ce:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f01047d2:	89 c7                	mov    %eax,%edi
f01047d4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01047d8:	8b 44 24 30          	mov    0x30(%esp),%eax
f01047dc:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f01047e0:	89 34 24             	mov    %esi,(%esp)
f01047e3:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01047e7:	85 c0                	test   %eax,%eax
f01047e9:	89 c2                	mov    %eax,%edx
f01047eb:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01047ef:	75 17                	jne    f0104808 <__umoddi3+0x48>
f01047f1:	39 fe                	cmp    %edi,%esi
f01047f3:	76 4b                	jbe    f0104840 <__umoddi3+0x80>
f01047f5:	89 c8                	mov    %ecx,%eax
f01047f7:	89 fa                	mov    %edi,%edx
f01047f9:	f7 f6                	div    %esi
f01047fb:	89 d0                	mov    %edx,%eax
f01047fd:	31 d2                	xor    %edx,%edx
f01047ff:	83 c4 14             	add    $0x14,%esp
f0104802:	5e                   	pop    %esi
f0104803:	5f                   	pop    %edi
f0104804:	5d                   	pop    %ebp
f0104805:	c3                   	ret    
f0104806:	66 90                	xchg   %ax,%ax
f0104808:	39 f8                	cmp    %edi,%eax
f010480a:	77 54                	ja     f0104860 <__umoddi3+0xa0>
f010480c:	0f bd e8             	bsr    %eax,%ebp
f010480f:	83 f5 1f             	xor    $0x1f,%ebp
f0104812:	75 5c                	jne    f0104870 <__umoddi3+0xb0>
f0104814:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0104818:	39 3c 24             	cmp    %edi,(%esp)
f010481b:	0f 87 e7 00 00 00    	ja     f0104908 <__umoddi3+0x148>
f0104821:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0104825:	29 f1                	sub    %esi,%ecx
f0104827:	19 c7                	sbb    %eax,%edi
f0104829:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f010482d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0104831:	8b 44 24 08          	mov    0x8(%esp),%eax
f0104835:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0104839:	83 c4 14             	add    $0x14,%esp
f010483c:	5e                   	pop    %esi
f010483d:	5f                   	pop    %edi
f010483e:	5d                   	pop    %ebp
f010483f:	c3                   	ret    
f0104840:	85 f6                	test   %esi,%esi
f0104842:	89 f5                	mov    %esi,%ebp
f0104844:	75 0b                	jne    f0104851 <__umoddi3+0x91>
f0104846:	b8 01 00 00 00       	mov    $0x1,%eax
f010484b:	31 d2                	xor    %edx,%edx
f010484d:	f7 f6                	div    %esi
f010484f:	89 c5                	mov    %eax,%ebp
f0104851:	8b 44 24 04          	mov    0x4(%esp),%eax
f0104855:	31 d2                	xor    %edx,%edx
f0104857:	f7 f5                	div    %ebp
f0104859:	89 c8                	mov    %ecx,%eax
f010485b:	f7 f5                	div    %ebp
f010485d:	eb 9c                	jmp    f01047fb <__umoddi3+0x3b>
f010485f:	90                   	nop
f0104860:	89 c8                	mov    %ecx,%eax
f0104862:	89 fa                	mov    %edi,%edx
f0104864:	83 c4 14             	add    $0x14,%esp
f0104867:	5e                   	pop    %esi
f0104868:	5f                   	pop    %edi
f0104869:	5d                   	pop    %ebp
f010486a:	c3                   	ret    
f010486b:	90                   	nop
f010486c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0104870:	8b 04 24             	mov    (%esp),%eax
f0104873:	be 20 00 00 00       	mov    $0x20,%esi
f0104878:	89 e9                	mov    %ebp,%ecx
f010487a:	29 ee                	sub    %ebp,%esi
f010487c:	d3 e2                	shl    %cl,%edx
f010487e:	89 f1                	mov    %esi,%ecx
f0104880:	d3 e8                	shr    %cl,%eax
f0104882:	89 e9                	mov    %ebp,%ecx
f0104884:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104888:	8b 04 24             	mov    (%esp),%eax
f010488b:	09 54 24 04          	or     %edx,0x4(%esp)
f010488f:	89 fa                	mov    %edi,%edx
f0104891:	d3 e0                	shl    %cl,%eax
f0104893:	89 f1                	mov    %esi,%ecx
f0104895:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104899:	8b 44 24 10          	mov    0x10(%esp),%eax
f010489d:	d3 ea                	shr    %cl,%edx
f010489f:	89 e9                	mov    %ebp,%ecx
f01048a1:	d3 e7                	shl    %cl,%edi
f01048a3:	89 f1                	mov    %esi,%ecx
f01048a5:	d3 e8                	shr    %cl,%eax
f01048a7:	89 e9                	mov    %ebp,%ecx
f01048a9:	09 f8                	or     %edi,%eax
f01048ab:	8b 7c 24 10          	mov    0x10(%esp),%edi
f01048af:	f7 74 24 04          	divl   0x4(%esp)
f01048b3:	d3 e7                	shl    %cl,%edi
f01048b5:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01048b9:	89 d7                	mov    %edx,%edi
f01048bb:	f7 64 24 08          	mull   0x8(%esp)
f01048bf:	39 d7                	cmp    %edx,%edi
f01048c1:	89 c1                	mov    %eax,%ecx
f01048c3:	89 14 24             	mov    %edx,(%esp)
f01048c6:	72 2c                	jb     f01048f4 <__umoddi3+0x134>
f01048c8:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f01048cc:	72 22                	jb     f01048f0 <__umoddi3+0x130>
f01048ce:	8b 44 24 0c          	mov    0xc(%esp),%eax
f01048d2:	29 c8                	sub    %ecx,%eax
f01048d4:	19 d7                	sbb    %edx,%edi
f01048d6:	89 e9                	mov    %ebp,%ecx
f01048d8:	89 fa                	mov    %edi,%edx
f01048da:	d3 e8                	shr    %cl,%eax
f01048dc:	89 f1                	mov    %esi,%ecx
f01048de:	d3 e2                	shl    %cl,%edx
f01048e0:	89 e9                	mov    %ebp,%ecx
f01048e2:	d3 ef                	shr    %cl,%edi
f01048e4:	09 d0                	or     %edx,%eax
f01048e6:	89 fa                	mov    %edi,%edx
f01048e8:	83 c4 14             	add    $0x14,%esp
f01048eb:	5e                   	pop    %esi
f01048ec:	5f                   	pop    %edi
f01048ed:	5d                   	pop    %ebp
f01048ee:	c3                   	ret    
f01048ef:	90                   	nop
f01048f0:	39 d7                	cmp    %edx,%edi
f01048f2:	75 da                	jne    f01048ce <__umoddi3+0x10e>
f01048f4:	8b 14 24             	mov    (%esp),%edx
f01048f7:	89 c1                	mov    %eax,%ecx
f01048f9:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f01048fd:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0104901:	eb cb                	jmp    f01048ce <__umoddi3+0x10e>
f0104903:	90                   	nop
f0104904:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0104908:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f010490c:	0f 82 0f ff ff ff    	jb     f0104821 <__umoddi3+0x61>
f0104912:	e9 1a ff ff ff       	jmp    f0104831 <__umoddi3+0x71>
