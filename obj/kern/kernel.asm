
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
f0100015:	b8 00 90 11 00       	mov    $0x119000,%eax
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
f0100034:	bc 00 90 11 f0       	mov    $0xf0119000,%esp

	# now to C code
	call	i386_init
f0100039:	e8 02 00 00 00       	call   f0100040 <i386_init>

f010003e <spin>:

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <i386_init>:
#include <kern/env.h>
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
f0100046:	b8 d0 df 17 f0       	mov    $0xf017dfd0,%eax
f010004b:	2d a1 d0 17 f0       	sub    $0xf017d0a1,%eax
f0100050:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100054:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010005b:	00 
f010005c:	c7 04 24 a1 d0 17 f0 	movl   $0xf017d0a1,(%esp)
f0100063:	e8 b1 4b 00 00       	call   f0104c19 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f0100068:	e8 d2 04 00 00       	call   f010053f <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f010006d:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f0100074:	00 
f0100075:	c7 04 24 e0 50 10 f0 	movl   $0xf01050e0,(%esp)
f010007c:	e8 cc 37 00 00       	call   f010384d <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f0100081:	e8 5a 11 00 00       	call   f01011e0 <mem_init>

	// Lab 3 user environment initialization functions
	env_init();
f0100086:	e8 ab 30 00 00       	call   f0103136 <env_init>
	trap_init();
f010008b:	90                   	nop
f010008c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100090:	e8 2f 38 00 00       	call   f01038c4 <trap_init>
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
f01000a5:	c7 04 24 56 b3 11 f0 	movl   $0xf011b356,(%esp)
f01000ac:	e8 5c 32 00 00       	call   f010330d <env_create>
#endif // TEST*
	// We only have one user environment for now, so just run it.
	env_run(&envs[0]);
f01000b1:	a1 08 d3 17 f0       	mov    0xf017d308,%eax
f01000b6:	89 04 24             	mov    %eax,(%esp)
f01000b9:	e8 b3 36 00 00       	call   f0103771 <env_run>

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
f01000c9:	83 3d c0 df 17 f0 00 	cmpl   $0x0,0xf017dfc0
f01000d0:	75 3d                	jne    f010010f <_panic+0x51>
		goto dead;
	panicstr = fmt;
f01000d2:	89 35 c0 df 17 f0    	mov    %esi,0xf017dfc0

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
f01000eb:	c7 04 24 fb 50 10 f0 	movl   $0xf01050fb,(%esp)
f01000f2:	e8 56 37 00 00       	call   f010384d <cprintf>
	vcprintf(fmt, ap);
f01000f7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01000fb:	89 34 24             	mov    %esi,(%esp)
f01000fe:	e8 17 37 00 00       	call   f010381a <vcprintf>
	cprintf("\n");
f0100103:	c7 04 24 39 60 10 f0 	movl   $0xf0106039,(%esp)
f010010a:	e8 3e 37 00 00       	call   f010384d <cprintf>
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
f0100135:	c7 04 24 13 51 10 f0 	movl   $0xf0105113,(%esp)
f010013c:	e8 0c 37 00 00       	call   f010384d <cprintf>
	vcprintf(fmt, ap);
f0100141:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100145:	8b 45 10             	mov    0x10(%ebp),%eax
f0100148:	89 04 24             	mov    %eax,(%esp)
f010014b:	e8 ca 36 00 00       	call   f010381a <vcprintf>
	cprintf("\n");
f0100150:	c7 04 24 39 60 10 f0 	movl   $0xf0106039,(%esp)
f0100157:	e8 f1 36 00 00       	call   f010384d <cprintf>
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
f010019b:	a1 e4 d2 17 f0       	mov    0xf017d2e4,%eax
f01001a0:	8d 48 01             	lea    0x1(%eax),%ecx
f01001a3:	89 0d e4 d2 17 f0    	mov    %ecx,0xf017d2e4
f01001a9:	88 90 e0 d0 17 f0    	mov    %dl,-0xfe82f20(%eax)
		if (cons.wpos == CONSBUFSIZE)
f01001af:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f01001b5:	75 0a                	jne    f01001c1 <cons_intr+0x35>
			cons.wpos = 0;
f01001b7:	c7 05 e4 d2 17 f0 00 	movl   $0x0,0xf017d2e4
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
f01001e7:	83 0d c0 d0 17 f0 40 	orl    $0x40,0xf017d0c0
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
f01001ff:	8b 0d c0 d0 17 f0    	mov    0xf017d0c0,%ecx
f0100205:	89 cb                	mov    %ecx,%ebx
f0100207:	83 e3 40             	and    $0x40,%ebx
f010020a:	83 e0 7f             	and    $0x7f,%eax
f010020d:	85 db                	test   %ebx,%ebx
f010020f:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f0100212:	0f b6 d2             	movzbl %dl,%edx
f0100215:	0f b6 82 80 52 10 f0 	movzbl -0xfefad80(%edx),%eax
f010021c:	83 c8 40             	or     $0x40,%eax
f010021f:	0f b6 c0             	movzbl %al,%eax
f0100222:	f7 d0                	not    %eax
f0100224:	21 c1                	and    %eax,%ecx
f0100226:	89 0d c0 d0 17 f0    	mov    %ecx,0xf017d0c0
		return 0;
f010022c:	b8 00 00 00 00       	mov    $0x0,%eax
f0100231:	e9 9d 00 00 00       	jmp    f01002d3 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f0100236:	8b 0d c0 d0 17 f0    	mov    0xf017d0c0,%ecx
f010023c:	f6 c1 40             	test   $0x40,%cl
f010023f:	74 0e                	je     f010024f <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f0100241:	83 c8 80             	or     $0xffffff80,%eax
f0100244:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f0100246:	83 e1 bf             	and    $0xffffffbf,%ecx
f0100249:	89 0d c0 d0 17 f0    	mov    %ecx,0xf017d0c0
	}

	shift |= shiftcode[data];
f010024f:	0f b6 d2             	movzbl %dl,%edx
f0100252:	0f b6 82 80 52 10 f0 	movzbl -0xfefad80(%edx),%eax
f0100259:	0b 05 c0 d0 17 f0    	or     0xf017d0c0,%eax
	shift ^= togglecode[data];
f010025f:	0f b6 8a 80 51 10 f0 	movzbl -0xfefae80(%edx),%ecx
f0100266:	31 c8                	xor    %ecx,%eax
f0100268:	a3 c0 d0 17 f0       	mov    %eax,0xf017d0c0

	c = charcode[shift & (CTL | SHIFT)][data];
f010026d:	89 c1                	mov    %eax,%ecx
f010026f:	83 e1 03             	and    $0x3,%ecx
f0100272:	8b 0c 8d 60 51 10 f0 	mov    -0xfefaea0(,%ecx,4),%ecx
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
f01002b2:	c7 04 24 2d 51 10 f0 	movl   $0xf010512d,(%esp)
f01002b9:	e8 8f 35 00 00       	call   f010384d <cprintf>
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
f010039c:	0f b7 05 e8 d2 17 f0 	movzwl 0xf017d2e8,%eax
f01003a3:	66 85 c0             	test   %ax,%ax
f01003a6:	0f 84 e5 00 00 00    	je     f0100491 <cons_putc+0x1b8>
			crt_pos--;
f01003ac:	83 e8 01             	sub    $0x1,%eax
f01003af:	66 a3 e8 d2 17 f0    	mov    %ax,0xf017d2e8
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f01003b5:	0f b7 c0             	movzwl %ax,%eax
f01003b8:	66 81 e7 00 ff       	and    $0xff00,%di
f01003bd:	83 cf 20             	or     $0x20,%edi
f01003c0:	8b 15 ec d2 17 f0    	mov    0xf017d2ec,%edx
f01003c6:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f01003ca:	eb 78                	jmp    f0100444 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f01003cc:	66 83 05 e8 d2 17 f0 	addw   $0x50,0xf017d2e8
f01003d3:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f01003d4:	0f b7 05 e8 d2 17 f0 	movzwl 0xf017d2e8,%eax
f01003db:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f01003e1:	c1 e8 16             	shr    $0x16,%eax
f01003e4:	8d 04 80             	lea    (%eax,%eax,4),%eax
f01003e7:	c1 e0 04             	shl    $0x4,%eax
f01003ea:	66 a3 e8 d2 17 f0    	mov    %ax,0xf017d2e8
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
f0100426:	0f b7 05 e8 d2 17 f0 	movzwl 0xf017d2e8,%eax
f010042d:	8d 50 01             	lea    0x1(%eax),%edx
f0100430:	66 89 15 e8 d2 17 f0 	mov    %dx,0xf017d2e8
f0100437:	0f b7 c0             	movzwl %ax,%eax
f010043a:	8b 15 ec d2 17 f0    	mov    0xf017d2ec,%edx
f0100440:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f0100444:	66 81 3d e8 d2 17 f0 	cmpw   $0x7cf,0xf017d2e8
f010044b:	cf 07 
f010044d:	76 42                	jbe    f0100491 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f010044f:	a1 ec d2 17 f0       	mov    0xf017d2ec,%eax
f0100454:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010045b:	00 
f010045c:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100462:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100466:	89 04 24             	mov    %eax,(%esp)
f0100469:	e8 f8 47 00 00       	call   f0104c66 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010046e:	8b 15 ec d2 17 f0    	mov    0xf017d2ec,%edx
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
f0100489:	66 83 2d e8 d2 17 f0 	subw   $0x50,0xf017d2e8
f0100490:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100491:	8b 0d f0 d2 17 f0    	mov    0xf017d2f0,%ecx
f0100497:	b8 0e 00 00 00       	mov    $0xe,%eax
f010049c:	89 ca                	mov    %ecx,%edx
f010049e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010049f:	0f b7 1d e8 d2 17 f0 	movzwl 0xf017d2e8,%ebx
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
f01004c7:	83 3d f4 d2 17 f0 00 	cmpl   $0x0,0xf017d2f4
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
f0100505:	a1 e0 d2 17 f0       	mov    0xf017d2e0,%eax
f010050a:	3b 05 e4 d2 17 f0    	cmp    0xf017d2e4,%eax
f0100510:	74 26                	je     f0100538 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f0100512:	8d 50 01             	lea    0x1(%eax),%edx
f0100515:	89 15 e0 d2 17 f0    	mov    %edx,0xf017d2e0
f010051b:	0f b6 88 e0 d0 17 f0 	movzbl -0xfe82f20(%eax),%ecx
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
f010052c:	c7 05 e0 d2 17 f0 00 	movl   $0x0,0xf017d2e0
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
f0100565:	c7 05 f0 d2 17 f0 b4 	movl   $0x3b4,0xf017d2f0
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
f010057d:	c7 05 f0 d2 17 f0 d4 	movl   $0x3d4,0xf017d2f0
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
f010058c:	8b 0d f0 d2 17 f0    	mov    0xf017d2f0,%ecx
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
f01005b1:	89 3d ec d2 17 f0    	mov    %edi,0xf017d2ec
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f01005b7:	0f b6 d8             	movzbl %al,%ebx
f01005ba:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f01005bc:	66 89 35 e8 d2 17 f0 	mov    %si,0xf017d2e8
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
f0100610:	89 0d f4 d2 17 f0    	mov    %ecx,0xf017d2f4
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
f0100620:	c7 04 24 39 51 10 f0 	movl   $0xf0105139,(%esp)
f0100627:	e8 21 32 00 00       	call   f010384d <cprintf>
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
f0100666:	c7 44 24 08 80 53 10 	movl   $0xf0105380,0x8(%esp)
f010066d:	f0 
f010066e:	c7 44 24 04 9e 53 10 	movl   $0xf010539e,0x4(%esp)
f0100675:	f0 
f0100676:	c7 04 24 a3 53 10 f0 	movl   $0xf01053a3,(%esp)
f010067d:	e8 cb 31 00 00       	call   f010384d <cprintf>
f0100682:	c7 44 24 08 40 54 10 	movl   $0xf0105440,0x8(%esp)
f0100689:	f0 
f010068a:	c7 44 24 04 ac 53 10 	movl   $0xf01053ac,0x4(%esp)
f0100691:	f0 
f0100692:	c7 04 24 a3 53 10 f0 	movl   $0xf01053a3,(%esp)
f0100699:	e8 af 31 00 00       	call   f010384d <cprintf>
f010069e:	c7 44 24 08 68 54 10 	movl   $0xf0105468,0x8(%esp)
f01006a5:	f0 
f01006a6:	c7 44 24 04 b5 53 10 	movl   $0xf01053b5,0x4(%esp)
f01006ad:	f0 
f01006ae:	c7 04 24 a3 53 10 f0 	movl   $0xf01053a3,(%esp)
f01006b5:	e8 93 31 00 00       	call   f010384d <cprintf>
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
f01006c7:	c7 04 24 bf 53 10 f0 	movl   $0xf01053bf,(%esp)
f01006ce:	e8 7a 31 00 00       	call   f010384d <cprintf>
	cprintf(" this is work 1 insert:\n");
f01006d3:	c7 04 24 d8 53 10 f0 	movl   $0xf01053d8,(%esp)
f01006da:	e8 6e 31 00 00       	call   f010384d <cprintf>
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
f01006df:	c7 44 24 08 0f 00 00 	movl   $0xf,0x8(%esp)
f01006e6:	00 
f01006e7:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
f01006ee:	00 
f01006ef:	c7 04 24 94 54 10 f0 	movl   $0xf0105494,(%esp)
f01006f6:	e8 52 31 00 00       	call   f010384d <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
f01006fb:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f0100702:	00 
f0100703:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f010070a:	f0 
f010070b:	c7 04 24 cc 54 10 f0 	movl   $0xf01054cc,(%esp)
f0100712:	e8 36 31 00 00       	call   f010384d <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f0100717:	c7 44 24 08 d7 50 10 	movl   $0x1050d7,0x8(%esp)
f010071e:	00 
f010071f:	c7 44 24 04 d7 50 10 	movl   $0xf01050d7,0x4(%esp)
f0100726:	f0 
f0100727:	c7 04 24 f4 54 10 f0 	movl   $0xf01054f4,(%esp)
f010072e:	e8 1a 31 00 00       	call   f010384d <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f0100733:	c7 44 24 08 a1 d0 17 	movl   $0x17d0a1,0x8(%esp)
f010073a:	00 
f010073b:	c7 44 24 04 a1 d0 17 	movl   $0xf017d0a1,0x4(%esp)
f0100742:	f0 
f0100743:	c7 04 24 18 55 10 f0 	movl   $0xf0105518,(%esp)
f010074a:	e8 fe 30 00 00       	call   f010384d <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f010074f:	c7 44 24 08 d0 df 17 	movl   $0x17dfd0,0x8(%esp)
f0100756:	00 
f0100757:	c7 44 24 04 d0 df 17 	movl   $0xf017dfd0,0x4(%esp)
f010075e:	f0 
f010075f:	c7 04 24 3c 55 10 f0 	movl   $0xf010553c,(%esp)
f0100766:	e8 e2 30 00 00       	call   f010384d <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f010076b:	b8 cf e3 17 f0       	mov    $0xf017e3cf,%eax
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
f0100787:	c7 04 24 60 55 10 f0 	movl   $0xf0105560,(%esp)
f010078e:	e8 ba 30 00 00       	call   f010384d <cprintf>
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
f01007a2:	c7 04 24 f1 53 10 f0 	movl   $0xf01053f1,(%esp)
f01007a9:	e8 9f 30 00 00       	call   f010384d <cprintf>
	cprintf("\n");
f01007ae:	c7 04 24 39 60 10 f0 	movl   $0xf0106039,(%esp)
f01007b5:	e8 93 30 00 00       	call   f010384d <cprintf>

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
f0100811:	c7 04 24 8c 55 10 f0 	movl   $0xf010558c,(%esp)
f0100818:	e8 30 30 00 00       	call   f010384d <cprintf>
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
f010083b:	c7 04 24 c8 55 10 f0 	movl   $0xf01055c8,(%esp)
f0100842:	e8 06 30 00 00       	call   f010384d <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f0100847:	c7 04 24 ec 55 10 f0 	movl   $0xf01055ec,(%esp)
f010084e:	e8 fa 2f 00 00       	call   f010384d <cprintf>

	if (tf != NULL)
f0100853:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f0100857:	74 0b                	je     f0100864 <monitor+0x32>
		print_trapframe(tf);
f0100859:	8b 45 08             	mov    0x8(%ebp),%eax
f010085c:	89 04 24             	mov    %eax,(%esp)
f010085f:	e8 42 34 00 00       	call   f0103ca6 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f0100864:	c7 04 24 02 54 10 f0 	movl   $0xf0105402,(%esp)
f010086b:	e8 d0 40 00 00       	call   f0104940 <readline>
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
f010089c:	c7 04 24 06 54 10 f0 	movl   $0xf0105406,(%esp)
f01008a3:	e8 11 43 00 00       	call   f0104bb9 <strchr>
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
f01008be:	c7 04 24 0b 54 10 f0 	movl   $0xf010540b,(%esp)
f01008c5:	e8 83 2f 00 00       	call   f010384d <cprintf>
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
f01008ed:	c7 04 24 06 54 10 f0 	movl   $0xf0105406,(%esp)
f01008f4:	e8 c0 42 00 00       	call   f0104bb9 <strchr>
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
f0100917:	8b 04 85 20 56 10 f0 	mov    -0xfefa9e0(,%eax,4),%eax
f010091e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100922:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100925:	89 04 24             	mov    %eax,(%esp)
f0100928:	e8 08 42 00 00       	call   f0104b35 <strcmp>
f010092d:	85 c0                	test   %eax,%eax
f010092f:	75 24                	jne    f0100955 <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100931:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100934:	8b 55 08             	mov    0x8(%ebp),%edx
f0100937:	89 54 24 08          	mov    %edx,0x8(%esp)
f010093b:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f010093e:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100942:	89 34 24             	mov    %esi,(%esp)
f0100945:	ff 14 85 28 56 10 f0 	call   *-0xfefa9d8(,%eax,4)
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
f0100964:	c7 04 24 28 54 10 f0 	movl   $0xf0105428,(%esp)
f010096b:	e8 dd 2e 00 00       	call   f010384d <cprintf>
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
f0100997:	83 3d f8 d2 17 f0 00 	cmpl   $0x0,0xf017d2f8
f010099e:	75 36                	jne    f01009d6 <boot_alloc+0x46>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f01009a0:	ba cf ef 17 f0       	mov    $0xf017efcf,%edx
f01009a5:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f01009ab:	89 15 f8 d2 17 f0    	mov    %edx,0xf017d2f8
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f01009b1:	85 c0                	test   %eax,%eax
f01009b3:	74 19                	je     f01009ce <boot_alloc+0x3e>
                      result = nextfree;
f01009b5:	8b 1d f8 d2 17 f0    	mov    0xf017d2f8,%ebx
                      nextfree += ROUNDUP(n, PGSIZE);
f01009bb:	05 ff 0f 00 00       	add    $0xfff,%eax
f01009c0:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01009c5:	01 d8                	add    %ebx,%eax
f01009c7:	a3 f8 d2 17 f0       	mov    %eax,0xf017d2f8
f01009cc:	eb 0e                	jmp    f01009dc <boot_alloc+0x4c>
               } else if (n == 0)
                      result = nextfree;
f01009ce:	8b 1d f8 d2 17 f0    	mov    0xf017d2f8,%ebx
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
f01009e0:	c7 04 24 44 56 10 f0 	movl   $0xf0105644,(%esp)
f01009e7:	e8 61 2e 00 00       	call   f010384d <cprintf>
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
f0100a0a:	3b 0d c4 df 17 f0    	cmp    0xf017dfc4,%ecx
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
f0100a1c:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f0100a23:	f0 
f0100a24:	c7 44 24 04 22 03 00 	movl   $0x322,0x4(%esp)
f0100a2b:	00 
f0100a2c:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
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
f0100a79:	c7 44 24 08 b4 56 10 	movl   $0xf01056b4,0x8(%esp)
f0100a80:	f0 
f0100a81:	c7 44 24 04 60 02 00 	movl   $0x260,0x4(%esp)
f0100a88:	00 
f0100a89:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
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
f0100aa3:	2b 15 cc df 17 f0    	sub    0xf017dfcc,%edx
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
f0100ad9:	a3 fc d2 17 f0       	mov    %eax,0xf017d2fc
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
f0100aeb:	2b 05 cc df 17 f0    	sub    0xf017dfcc,%eax
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
f0100b05:	3b 15 c4 df 17 f0    	cmp    0xf017dfc4,%edx
f0100b0b:	72 20                	jb     f0100b2d <check_page_free_list+0xca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100b0d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100b11:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f0100b18:	f0 
f0100b19:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100b20:	00 
f0100b21:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f0100b28:	e8 91 f5 ff ff       	call   f01000be <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100b2d:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100b34:	00 
f0100b35:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100b3c:	00 
	return (void *)(pa + KERNBASE);
f0100b3d:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100b42:	89 04 24             	mov    %eax,(%esp)
f0100b45:	e8 cf 40 00 00       	call   f0104c19 <memset>
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
f0100b5d:	8b 15 fc d2 17 f0    	mov    0xf017d2fc,%edx
f0100b63:	85 d2                	test   %edx,%edx
f0100b65:	0f 84 f2 01 00 00    	je     f0100d5d <check_page_free_list+0x2fa>
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100b6b:	8b 1d cc df 17 f0    	mov    0xf017dfcc,%ebx
f0100b71:	39 da                	cmp    %ebx,%edx
f0100b73:	72 3f                	jb     f0100bb4 <check_page_free_list+0x151>
		assert(pp < pages + npages);
f0100b75:	a1 c4 df 17 f0       	mov    0xf017dfc4,%eax
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
f0100bb4:	c7 44 24 0c c3 5d 10 	movl   $0xf0105dc3,0xc(%esp)
f0100bbb:	f0 
f0100bbc:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0100bc3:	f0 
f0100bc4:	c7 44 24 04 7a 02 00 	movl   $0x27a,0x4(%esp)
f0100bcb:	00 
f0100bcc:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0100bd3:	e8 e6 f4 ff ff       	call   f01000be <_panic>
		assert(pp < pages + npages);
f0100bd8:	3b 55 d4             	cmp    -0x2c(%ebp),%edx
f0100bdb:	72 24                	jb     f0100c01 <check_page_free_list+0x19e>
f0100bdd:	c7 44 24 0c e4 5d 10 	movl   $0xf0105de4,0xc(%esp)
f0100be4:	f0 
f0100be5:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0100bec:	f0 
f0100bed:	c7 44 24 04 7b 02 00 	movl   $0x27b,0x4(%esp)
f0100bf4:	00 
f0100bf5:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0100bfc:	e8 bd f4 ff ff       	call   f01000be <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100c01:	89 d0                	mov    %edx,%eax
f0100c03:	2b 45 d0             	sub    -0x30(%ebp),%eax
f0100c06:	a8 07                	test   $0x7,%al
f0100c08:	74 24                	je     f0100c2e <check_page_free_list+0x1cb>
f0100c0a:	c7 44 24 0c d8 56 10 	movl   $0xf01056d8,0xc(%esp)
f0100c11:	f0 
f0100c12:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0100c19:	f0 
f0100c1a:	c7 44 24 04 7c 02 00 	movl   $0x27c,0x4(%esp)
f0100c21:	00 
f0100c22:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0100c29:	e8 90 f4 ff ff       	call   f01000be <_panic>
f0100c2e:	c1 f8 03             	sar    $0x3,%eax
f0100c31:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100c34:	85 c0                	test   %eax,%eax
f0100c36:	75 24                	jne    f0100c5c <check_page_free_list+0x1f9>
f0100c38:	c7 44 24 0c f8 5d 10 	movl   $0xf0105df8,0xc(%esp)
f0100c3f:	f0 
f0100c40:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0100c47:	f0 
f0100c48:	c7 44 24 04 7f 02 00 	movl   $0x27f,0x4(%esp)
f0100c4f:	00 
f0100c50:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0100c57:	e8 62 f4 ff ff       	call   f01000be <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100c5c:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100c61:	75 2e                	jne    f0100c91 <check_page_free_list+0x22e>
f0100c63:	c7 44 24 0c 09 5e 10 	movl   $0xf0105e09,0xc(%esp)
f0100c6a:	f0 
f0100c6b:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0100c72:	f0 
f0100c73:	c7 44 24 04 80 02 00 	movl   $0x280,0x4(%esp)
f0100c7a:	00 
f0100c7b:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
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
f0100c98:	c7 44 24 0c 0c 57 10 	movl   $0xf010570c,0xc(%esp)
f0100c9f:	f0 
f0100ca0:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0100ca7:	f0 
f0100ca8:	c7 44 24 04 81 02 00 	movl   $0x281,0x4(%esp)
f0100caf:	00 
f0100cb0:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0100cb7:	e8 02 f4 ff ff       	call   f01000be <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100cbc:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100cc1:	75 24                	jne    f0100ce7 <check_page_free_list+0x284>
f0100cc3:	c7 44 24 0c 22 5e 10 	movl   $0xf0105e22,0xc(%esp)
f0100cca:	f0 
f0100ccb:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0100cd2:	f0 
f0100cd3:	c7 44 24 04 82 02 00 	movl   $0x282,0x4(%esp)
f0100cda:	00 
f0100cdb:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
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
f0100cfc:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f0100d03:	f0 
f0100d04:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100d0b:	00 
f0100d0c:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f0100d13:	e8 a6 f3 ff ff       	call   f01000be <_panic>
	return (void *)(pa + KERNBASE);
f0100d18:	81 e9 00 00 00 10    	sub    $0x10000000,%ecx
f0100d1e:	39 4d cc             	cmp    %ecx,-0x34(%ebp)
f0100d21:	76 29                	jbe    f0100d4c <check_page_free_list+0x2e9>
f0100d23:	c7 44 24 0c 30 57 10 	movl   $0xf0105730,0xc(%esp)
f0100d2a:	f0 
f0100d2b:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0100d32:	f0 
f0100d33:	c7 44 24 04 83 02 00 	movl   $0x283,0x4(%esp)
f0100d3a:	00 
f0100d3b:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
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
f0100d5d:	c7 44 24 0c 3c 5e 10 	movl   $0xf0105e3c,0xc(%esp)
f0100d64:	f0 
f0100d65:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0100d6c:	f0 
f0100d6d:	c7 44 24 04 8b 02 00 	movl   $0x28b,0x4(%esp)
f0100d74:	00 
f0100d75:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0100d7c:	e8 3d f3 ff ff       	call   f01000be <_panic>
	assert(nfree_extmem > 0);
f0100d81:	85 f6                	test   %esi,%esi
f0100d83:	7f 53                	jg     f0100dd8 <check_page_free_list+0x375>
f0100d85:	c7 44 24 0c 4e 5e 10 	movl   $0xf0105e4e,0xc(%esp)
f0100d8c:	f0 
f0100d8d:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0100d94:	f0 
f0100d95:	c7 44 24 04 8c 02 00 	movl   $0x28c,0x4(%esp)
f0100d9c:	00 
f0100d9d:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0100da4:	e8 15 f3 ff ff       	call   f01000be <_panic>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100da9:	a1 fc d2 17 f0       	mov    0xf017d2fc,%eax
f0100dae:	85 c0                	test   %eax,%eax
f0100db0:	0f 85 df fc ff ff    	jne    f0100a95 <check_page_free_list+0x32>
f0100db6:	e9 be fc ff ff       	jmp    f0100a79 <check_page_free_list+0x16>
f0100dbb:	83 3d fc d2 17 f0 00 	cmpl   $0x0,0xf017d2fc
f0100dc2:	0f 84 b1 fc ff ff    	je     f0100a79 <check_page_free_list+0x16>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100dc8:	8b 1d fc d2 17 f0    	mov    0xf017d2fc,%ebx
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
f0100de7:	83 3d c4 df 17 f0 00 	cmpl   $0x0,0xf017dfc4
f0100dee:	0f 84 a5 00 00 00    	je     f0100e99 <page_init+0xb9>
f0100df4:	8b 1d fc d2 17 f0    	mov    0xf017d2fc,%ebx
f0100dfa:	b8 00 00 00 00       	mov    $0x0,%eax
f0100dff:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
		pages[i].pp_ref = 0;
f0100e06:	89 d1                	mov    %edx,%ecx
f0100e08:	03 0d cc df 17 f0    	add    0xf017dfcc,%ecx
f0100e0e:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0100e14:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f0100e16:	03 15 cc df 17 f0    	add    0xf017dfcc,%edx
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100e1c:	83 c0 01             	add    $0x1,%eax
f0100e1f:	8b 0d c4 df 17 f0    	mov    0xf017dfc4,%ecx
f0100e25:	39 c1                	cmp    %eax,%ecx
f0100e27:	76 04                	jbe    f0100e2d <page_init+0x4d>
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f0100e29:	89 d3                	mov    %edx,%ebx
f0100e2b:	eb d2                	jmp    f0100dff <page_init+0x1f>
f0100e2d:	89 15 fc d2 17 f0    	mov    %edx,0xf017d2fc
	}

	//remove physical page 0 from page_free_list
             pages[1].pp_link = NULL;
f0100e33:	a1 cc df 17 f0       	mov    0xf017dfcc,%eax
f0100e38:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100e3f:	81 f9 a0 00 00 00    	cmp    $0xa0,%ecx
f0100e45:	77 1c                	ja     f0100e63 <page_init+0x83>
		panic("pa2page called with invalid pa");
f0100e47:	c7 44 24 08 78 57 10 	movl   $0xf0105778,0x8(%esp)
f0100e4e:	f0 
f0100e4f:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0100e56:	00 
f0100e57:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f0100e5e:	e8 5b f2 ff ff       	call   f01000be <_panic>

              //remove continuous pages from page_free_list
              extern char end[];                        //this is an *virtual* address
              struct Page *ppg_start = pa2page((physaddr_t)IOPHYSMEM);                                                //at low *physical* address
              struct Page *ppg_end = pa2page((physaddr_t)((end - KERNBASE) + PGSIZE + sizeof(struct Page)*npages)+sizeof(struct Env)*NENV);    //at high *physical* address
f0100e63:	8d 14 cd d0 6f 19 00 	lea    0x196fd0(,%ecx,8),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100e6a:	c1 ea 0c             	shr    $0xc,%edx
f0100e6d:	39 d1                	cmp    %edx,%ecx
f0100e6f:	77 1c                	ja     f0100e8d <page_init+0xad>
		panic("pa2page called with invalid pa");
f0100e71:	c7 44 24 08 78 57 10 	movl   $0xf0105778,0x8(%esp)
f0100e78:	f0 
f0100e79:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0100e80:	00 
f0100e81:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
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
f0100e99:	a1 cc df 17 f0       	mov    0xf017dfcc,%eax
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
f0100eb4:	8b 1d fc d2 17 f0    	mov    0xf017d2fc,%ebx
f0100eba:	85 db                	test   %ebx,%ebx
f0100ebc:	74 69                	je     f0100f27 <page_alloc+0x7a>
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
f0100ebe:	8b 03                	mov    (%ebx),%eax
f0100ec0:	a3 fc d2 17 f0       	mov    %eax,0xf017d2fc
    
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
f0100ecd:	2b 05 cc df 17 f0    	sub    0xf017dfcc,%eax
f0100ed3:	c1 f8 03             	sar    $0x3,%eax
f0100ed6:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100ed9:	89 c2                	mov    %eax,%edx
f0100edb:	c1 ea 0c             	shr    $0xc,%edx
f0100ede:	3b 15 c4 df 17 f0    	cmp    0xf017dfc4,%edx
f0100ee4:	72 20                	jb     f0100f06 <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100ee6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100eea:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f0100ef1:	f0 
f0100ef2:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100ef9:	00 
f0100efa:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f0100f01:	e8 b8 f1 ff ff       	call   f01000be <_panic>
                    memset(page2kva(result), 0, PGSIZE);
f0100f06:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0100f0d:	00 
f0100f0e:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0100f15:	00 
	return (void *)(pa + KERNBASE);
f0100f16:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100f1b:	89 04 24             	mov    %eax,(%esp)
f0100f1e:	e8 f6 3c 00 00       	call   f0104c19 <memset>
        
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
f0100f38:	8b 15 fc d2 17 f0    	mov    0xf017d2fc,%edx
f0100f3e:	89 10                	mov    %edx,(%eax)
              page_free_list = pp;
f0100f40:	a3 fc d2 17 f0       	mov    %eax,0xf017d2fc
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
f0100fab:	2b 15 cc df 17 f0    	sub    0xf017dfcc,%edx
f0100fb1:	c1 fa 03             	sar    $0x3,%edx
f0100fb4:	c1 e2 0c             	shl    $0xc,%edx
                                                  pgdir[PDX(va)] = page2pa(tmp) | PTE_P | PTE_W |PTE_U;    //save the physical address of newly allocated page in page dir
f0100fb7:	83 ca 07             	or     $0x7,%edx
f0100fba:	89 16                	mov    %edx,(%esi)
f0100fbc:	2b 05 cc df 17 f0    	sub    0xf017dfcc,%eax
f0100fc2:	c1 f8 03             	sar    $0x3,%eax
f0100fc5:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100fc8:	89 c2                	mov    %eax,%edx
f0100fca:	c1 ea 0c             	shr    $0xc,%edx
f0100fcd:	3b 15 c4 df 17 f0    	cmp    0xf017dfc4,%edx
f0100fd3:	72 20                	jb     f0100ff5 <pgdir_walk+0x8b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100fd5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100fd9:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f0100fe0:	f0 
f0100fe1:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100fe8:	00 
f0100fe9:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
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
f0100fff:	8b 15 c4 df 17 f0    	mov    0xf017dfc4,%edx
f0101005:	39 d0                	cmp    %edx,%eax
f0101007:	72 1c                	jb     f0101025 <pgdir_walk+0xbb>
		panic("pa2page called with invalid pa");
f0101009:	c7 44 24 08 78 57 10 	movl   $0xf0105778,0x8(%esp)
f0101010:	f0 
f0101011:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101018:	00 
f0101019:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
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
f0101032:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f0101039:	f0 
f010103a:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101041:	00 
f0101042:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
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
f01010a7:	3b 05 c4 df 17 f0    	cmp    0xf017dfc4,%eax
f01010ad:	72 1c                	jb     f01010cb <page_lookup+0x57>
		panic("pa2page called with invalid pa");
f01010af:	c7 44 24 08 78 57 10 	movl   $0xf0105778,0x8(%esp)
f01010b6:	f0 
f01010b7:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01010be:	00 
f01010bf:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f01010c6:	e8 f3 ef ff ff       	call   f01000be <_panic>
	return &pages[PGNUM(pa)];
f01010cb:	8b 15 cc df 17 f0    	mov    0xf017dfcc,%edx
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
f0101168:	2b 3d cc df 17 f0    	sub    0xf017dfcc,%edi
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
f01011b7:	2b 15 cc df 17 f0    	sub    0xf017dfcc,%edx
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
f01011f0:	e8 e8 25 00 00       	call   f01037dd <mc146818_read>
f01011f5:	89 c3                	mov    %eax,%ebx
f01011f7:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f01011fe:	e8 da 25 00 00       	call   f01037dd <mc146818_read>
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
f010121b:	a3 00 d3 17 f0       	mov    %eax,0xf017d300
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0101220:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f0101227:	e8 b1 25 00 00       	call   f01037dd <mc146818_read>
f010122c:	89 c3                	mov    %eax,%ebx
f010122e:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f0101235:	e8 a3 25 00 00       	call   f01037dd <mc146818_read>
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
f010125c:	89 15 c4 df 17 f0    	mov    %edx,0xf017dfc4
f0101262:	eb 0c                	jmp    f0101270 <mem_init+0x90>
	else
		npages = npages_basemem;
f0101264:	8b 15 00 d3 17 f0    	mov    0xf017d300,%edx
f010126a:	89 15 c4 df 17 f0    	mov    %edx,0xf017dfc4

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
f010127a:	a1 00 d3 17 f0       	mov    0xf017d300,%eax
f010127f:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101282:	c1 e8 0a             	shr    $0xa,%eax
f0101285:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f0101289:	a1 c4 df 17 f0       	mov    0xf017dfc4,%eax
f010128e:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101291:	c1 e8 0a             	shr    $0xa,%eax
f0101294:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101298:	c7 04 24 98 57 10 f0 	movl   $0xf0105798,(%esp)
f010129f:	e8 a9 25 00 00       	call   f010384d <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);  // first_level pagedir
f01012a4:	b8 00 10 00 00       	mov    $0x1000,%eax
f01012a9:	e8 e2 f6 ff ff       	call   f0100990 <boot_alloc>
f01012ae:	a3 c8 df 17 f0       	mov    %eax,0xf017dfc8
	memset(kern_pgdir, 0, PGSIZE);
f01012b3:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01012ba:	00 
f01012bb:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01012c2:	00 
f01012c3:	89 04 24             	mov    %eax,(%esp)
f01012c6:	e8 4e 39 00 00       	call   f0104c19 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f01012cb:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01012d0:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01012d5:	77 20                	ja     f01012f7 <mem_init+0x117>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01012d7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01012db:	c7 44 24 08 d4 57 10 	movl   $0xf01057d4,0x8(%esp)
f01012e2:	f0 
f01012e3:	c7 44 24 04 94 00 00 	movl   $0x94,0x4(%esp)
f01012ea:	00 
f01012eb:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
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
f0101306:	a1 c4 df 17 f0       	mov    0xf017dfc4,%eax
f010130b:	c1 e0 03             	shl    $0x3,%eax
f010130e:	e8 7d f6 ff ff       	call   f0100990 <boot_alloc>
f0101313:	a3 cc df 17 f0       	mov    %eax,0xf017dfcc


	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.
	envs =  (struct Env *)boot_alloc(NENV * sizeof(struct Env));
f0101318:	b8 00 80 01 00       	mov    $0x18000,%eax
f010131d:	e8 6e f6 ff ff       	call   f0100990 <boot_alloc>
f0101322:	a3 08 d3 17 f0       	mov    %eax,0xf017d308
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f0101327:	e8 b4 fa ff ff       	call   f0100de0 <page_init>

	check_page_free_list(1);
f010132c:	b8 01 00 00 00       	mov    $0x1,%eax
f0101331:	e8 2d f7 ff ff       	call   f0100a63 <check_page_free_list>
	int nfree;
	struct Page *fl;
	char *c;
	int i;

	if (!pages)
f0101336:	83 3d cc df 17 f0 00 	cmpl   $0x0,0xf017dfcc
f010133d:	75 1c                	jne    f010135b <mem_init+0x17b>
		panic("'pages' is a null pointer!");
f010133f:	c7 44 24 08 5f 5e 10 	movl   $0xf0105e5f,0x8(%esp)
f0101346:	f0 
f0101347:	c7 44 24 04 9d 02 00 	movl   $0x29d,0x4(%esp)
f010134e:	00 
f010134f:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101356:	e8 63 ed ff ff       	call   f01000be <_panic>

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010135b:	a1 fc d2 17 f0       	mov    0xf017d2fc,%eax
f0101360:	85 c0                	test   %eax,%eax
f0101362:	74 10                	je     f0101374 <mem_init+0x194>
f0101364:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;
f0101369:	83 c3 01             	add    $0x1,%ebx

	if (!pages)
		panic("'pages' is a null pointer!");

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010136c:	8b 00                	mov    (%eax),%eax
f010136e:	85 c0                	test   %eax,%eax
f0101370:	75 f7                	jne    f0101369 <mem_init+0x189>
f0101372:	eb 05                	jmp    f0101379 <mem_init+0x199>
f0101374:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101379:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101380:	e8 28 fb ff ff       	call   f0100ead <page_alloc>
f0101385:	89 c7                	mov    %eax,%edi
f0101387:	85 c0                	test   %eax,%eax
f0101389:	75 24                	jne    f01013af <mem_init+0x1cf>
f010138b:	c7 44 24 0c 7a 5e 10 	movl   $0xf0105e7a,0xc(%esp)
f0101392:	f0 
f0101393:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f010139a:	f0 
f010139b:	c7 44 24 04 a5 02 00 	movl   $0x2a5,0x4(%esp)
f01013a2:	00 
f01013a3:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01013aa:	e8 0f ed ff ff       	call   f01000be <_panic>
	assert((pp1 = page_alloc(0)));
f01013af:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01013b6:	e8 f2 fa ff ff       	call   f0100ead <page_alloc>
f01013bb:	89 c6                	mov    %eax,%esi
f01013bd:	85 c0                	test   %eax,%eax
f01013bf:	75 24                	jne    f01013e5 <mem_init+0x205>
f01013c1:	c7 44 24 0c 90 5e 10 	movl   $0xf0105e90,0xc(%esp)
f01013c8:	f0 
f01013c9:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f01013d0:	f0 
f01013d1:	c7 44 24 04 a6 02 00 	movl   $0x2a6,0x4(%esp)
f01013d8:	00 
f01013d9:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01013e0:	e8 d9 ec ff ff       	call   f01000be <_panic>
	assert((pp2 = page_alloc(0)));
f01013e5:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01013ec:	e8 bc fa ff ff       	call   f0100ead <page_alloc>
f01013f1:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01013f4:	85 c0                	test   %eax,%eax
f01013f6:	75 24                	jne    f010141c <mem_init+0x23c>
f01013f8:	c7 44 24 0c a6 5e 10 	movl   $0xf0105ea6,0xc(%esp)
f01013ff:	f0 
f0101400:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101407:	f0 
f0101408:	c7 44 24 04 a7 02 00 	movl   $0x2a7,0x4(%esp)
f010140f:	00 
f0101410:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101417:	e8 a2 ec ff ff       	call   f01000be <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f010141c:	39 f7                	cmp    %esi,%edi
f010141e:	75 24                	jne    f0101444 <mem_init+0x264>
f0101420:	c7 44 24 0c bc 5e 10 	movl   $0xf0105ebc,0xc(%esp)
f0101427:	f0 
f0101428:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f010142f:	f0 
f0101430:	c7 44 24 04 aa 02 00 	movl   $0x2aa,0x4(%esp)
f0101437:	00 
f0101438:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f010143f:	e8 7a ec ff ff       	call   f01000be <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101444:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101447:	39 c6                	cmp    %eax,%esi
f0101449:	74 04                	je     f010144f <mem_init+0x26f>
f010144b:	39 c7                	cmp    %eax,%edi
f010144d:	75 24                	jne    f0101473 <mem_init+0x293>
f010144f:	c7 44 24 0c f8 57 10 	movl   $0xf01057f8,0xc(%esp)
f0101456:	f0 
f0101457:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f010145e:	f0 
f010145f:	c7 44 24 04 ab 02 00 	movl   $0x2ab,0x4(%esp)
f0101466:	00 
f0101467:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f010146e:	e8 4b ec ff ff       	call   f01000be <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101473:	8b 15 cc df 17 f0    	mov    0xf017dfcc,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f0101479:	a1 c4 df 17 f0       	mov    0xf017dfc4,%eax
f010147e:	c1 e0 0c             	shl    $0xc,%eax
f0101481:	89 f9                	mov    %edi,%ecx
f0101483:	29 d1                	sub    %edx,%ecx
f0101485:	c1 f9 03             	sar    $0x3,%ecx
f0101488:	c1 e1 0c             	shl    $0xc,%ecx
f010148b:	39 c1                	cmp    %eax,%ecx
f010148d:	72 24                	jb     f01014b3 <mem_init+0x2d3>
f010148f:	c7 44 24 0c ce 5e 10 	movl   $0xf0105ece,0xc(%esp)
f0101496:	f0 
f0101497:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f010149e:	f0 
f010149f:	c7 44 24 04 ac 02 00 	movl   $0x2ac,0x4(%esp)
f01014a6:	00 
f01014a7:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01014ae:	e8 0b ec ff ff       	call   f01000be <_panic>
f01014b3:	89 f1                	mov    %esi,%ecx
f01014b5:	29 d1                	sub    %edx,%ecx
f01014b7:	c1 f9 03             	sar    $0x3,%ecx
f01014ba:	c1 e1 0c             	shl    $0xc,%ecx
	assert(page2pa(pp1) < npages*PGSIZE);
f01014bd:	39 c8                	cmp    %ecx,%eax
f01014bf:	77 24                	ja     f01014e5 <mem_init+0x305>
f01014c1:	c7 44 24 0c eb 5e 10 	movl   $0xf0105eeb,0xc(%esp)
f01014c8:	f0 
f01014c9:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f01014d0:	f0 
f01014d1:	c7 44 24 04 ad 02 00 	movl   $0x2ad,0x4(%esp)
f01014d8:	00 
f01014d9:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01014e0:	e8 d9 eb ff ff       	call   f01000be <_panic>
f01014e5:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01014e8:	29 d1                	sub    %edx,%ecx
f01014ea:	89 ca                	mov    %ecx,%edx
f01014ec:	c1 fa 03             	sar    $0x3,%edx
f01014ef:	c1 e2 0c             	shl    $0xc,%edx
	assert(page2pa(pp2) < npages*PGSIZE);
f01014f2:	39 d0                	cmp    %edx,%eax
f01014f4:	77 24                	ja     f010151a <mem_init+0x33a>
f01014f6:	c7 44 24 0c 08 5f 10 	movl   $0xf0105f08,0xc(%esp)
f01014fd:	f0 
f01014fe:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101505:	f0 
f0101506:	c7 44 24 04 ae 02 00 	movl   $0x2ae,0x4(%esp)
f010150d:	00 
f010150e:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101515:	e8 a4 eb ff ff       	call   f01000be <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f010151a:	a1 fc d2 17 f0       	mov    0xf017d2fc,%eax
f010151f:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101522:	c7 05 fc d2 17 f0 00 	movl   $0x0,0xf017d2fc
f0101529:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f010152c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101533:	e8 75 f9 ff ff       	call   f0100ead <page_alloc>
f0101538:	85 c0                	test   %eax,%eax
f010153a:	74 24                	je     f0101560 <mem_init+0x380>
f010153c:	c7 44 24 0c 25 5f 10 	movl   $0xf0105f25,0xc(%esp)
f0101543:	f0 
f0101544:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f010154b:	f0 
f010154c:	c7 44 24 04 b5 02 00 	movl   $0x2b5,0x4(%esp)
f0101553:	00 
f0101554:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f010155b:	e8 5e eb ff ff       	call   f01000be <_panic>

	// free and re-allocate?
	page_free(pp0);
f0101560:	89 3c 24             	mov    %edi,(%esp)
f0101563:	e8 ca f9 ff ff       	call   f0100f32 <page_free>
	page_free(pp1);
f0101568:	89 34 24             	mov    %esi,(%esp)
f010156b:	e8 c2 f9 ff ff       	call   f0100f32 <page_free>
	page_free(pp2);
f0101570:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101573:	89 04 24             	mov    %eax,(%esp)
f0101576:	e8 b7 f9 ff ff       	call   f0100f32 <page_free>
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f010157b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101582:	e8 26 f9 ff ff       	call   f0100ead <page_alloc>
f0101587:	89 c6                	mov    %eax,%esi
f0101589:	85 c0                	test   %eax,%eax
f010158b:	75 24                	jne    f01015b1 <mem_init+0x3d1>
f010158d:	c7 44 24 0c 7a 5e 10 	movl   $0xf0105e7a,0xc(%esp)
f0101594:	f0 
f0101595:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f010159c:	f0 
f010159d:	c7 44 24 04 bc 02 00 	movl   $0x2bc,0x4(%esp)
f01015a4:	00 
f01015a5:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01015ac:	e8 0d eb ff ff       	call   f01000be <_panic>
	assert((pp1 = page_alloc(0)));
f01015b1:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01015b8:	e8 f0 f8 ff ff       	call   f0100ead <page_alloc>
f01015bd:	89 c7                	mov    %eax,%edi
f01015bf:	85 c0                	test   %eax,%eax
f01015c1:	75 24                	jne    f01015e7 <mem_init+0x407>
f01015c3:	c7 44 24 0c 90 5e 10 	movl   $0xf0105e90,0xc(%esp)
f01015ca:	f0 
f01015cb:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f01015d2:	f0 
f01015d3:	c7 44 24 04 bd 02 00 	movl   $0x2bd,0x4(%esp)
f01015da:	00 
f01015db:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01015e2:	e8 d7 ea ff ff       	call   f01000be <_panic>
	assert((pp2 = page_alloc(0)));
f01015e7:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01015ee:	e8 ba f8 ff ff       	call   f0100ead <page_alloc>
f01015f3:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01015f6:	85 c0                	test   %eax,%eax
f01015f8:	75 24                	jne    f010161e <mem_init+0x43e>
f01015fa:	c7 44 24 0c a6 5e 10 	movl   $0xf0105ea6,0xc(%esp)
f0101601:	f0 
f0101602:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101609:	f0 
f010160a:	c7 44 24 04 be 02 00 	movl   $0x2be,0x4(%esp)
f0101611:	00 
f0101612:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101619:	e8 a0 ea ff ff       	call   f01000be <_panic>
	assert(pp0);
	assert(pp1 && pp1 != pp0);
f010161e:	39 fe                	cmp    %edi,%esi
f0101620:	75 24                	jne    f0101646 <mem_init+0x466>
f0101622:	c7 44 24 0c bc 5e 10 	movl   $0xf0105ebc,0xc(%esp)
f0101629:	f0 
f010162a:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101631:	f0 
f0101632:	c7 44 24 04 c0 02 00 	movl   $0x2c0,0x4(%esp)
f0101639:	00 
f010163a:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101641:	e8 78 ea ff ff       	call   f01000be <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101646:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101649:	39 c7                	cmp    %eax,%edi
f010164b:	74 04                	je     f0101651 <mem_init+0x471>
f010164d:	39 c6                	cmp    %eax,%esi
f010164f:	75 24                	jne    f0101675 <mem_init+0x495>
f0101651:	c7 44 24 0c f8 57 10 	movl   $0xf01057f8,0xc(%esp)
f0101658:	f0 
f0101659:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101660:	f0 
f0101661:	c7 44 24 04 c1 02 00 	movl   $0x2c1,0x4(%esp)
f0101668:	00 
f0101669:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101670:	e8 49 ea ff ff       	call   f01000be <_panic>
	assert(!page_alloc(0));
f0101675:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010167c:	e8 2c f8 ff ff       	call   f0100ead <page_alloc>
f0101681:	85 c0                	test   %eax,%eax
f0101683:	74 24                	je     f01016a9 <mem_init+0x4c9>
f0101685:	c7 44 24 0c 25 5f 10 	movl   $0xf0105f25,0xc(%esp)
f010168c:	f0 
f010168d:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101694:	f0 
f0101695:	c7 44 24 04 c2 02 00 	movl   $0x2c2,0x4(%esp)
f010169c:	00 
f010169d:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01016a4:	e8 15 ea ff ff       	call   f01000be <_panic>
f01016a9:	89 f0                	mov    %esi,%eax
f01016ab:	2b 05 cc df 17 f0    	sub    0xf017dfcc,%eax
f01016b1:	c1 f8 03             	sar    $0x3,%eax
f01016b4:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01016b7:	89 c2                	mov    %eax,%edx
f01016b9:	c1 ea 0c             	shr    $0xc,%edx
f01016bc:	3b 15 c4 df 17 f0    	cmp    0xf017dfc4,%edx
f01016c2:	72 20                	jb     f01016e4 <mem_init+0x504>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01016c4:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01016c8:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f01016cf:	f0 
f01016d0:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01016d7:	00 
f01016d8:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f01016df:	e8 da e9 ff ff       	call   f01000be <_panic>

	// test flags
	memset(page2kva(pp0), 1, PGSIZE);
f01016e4:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01016eb:	00 
f01016ec:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f01016f3:	00 
	return (void *)(pa + KERNBASE);
f01016f4:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01016f9:	89 04 24             	mov    %eax,(%esp)
f01016fc:	e8 18 35 00 00       	call   f0104c19 <memset>
	page_free(pp0);
f0101701:	89 34 24             	mov    %esi,(%esp)
f0101704:	e8 29 f8 ff ff       	call   f0100f32 <page_free>
	assert((pp = page_alloc(ALLOC_ZERO)));
f0101709:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101710:	e8 98 f7 ff ff       	call   f0100ead <page_alloc>
f0101715:	85 c0                	test   %eax,%eax
f0101717:	75 24                	jne    f010173d <mem_init+0x55d>
f0101719:	c7 44 24 0c 34 5f 10 	movl   $0xf0105f34,0xc(%esp)
f0101720:	f0 
f0101721:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101728:	f0 
f0101729:	c7 44 24 04 c7 02 00 	movl   $0x2c7,0x4(%esp)
f0101730:	00 
f0101731:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101738:	e8 81 e9 ff ff       	call   f01000be <_panic>
	assert(pp && pp0 == pp);
f010173d:	39 c6                	cmp    %eax,%esi
f010173f:	74 24                	je     f0101765 <mem_init+0x585>
f0101741:	c7 44 24 0c 52 5f 10 	movl   $0xf0105f52,0xc(%esp)
f0101748:	f0 
f0101749:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101750:	f0 
f0101751:	c7 44 24 04 c8 02 00 	movl   $0x2c8,0x4(%esp)
f0101758:	00 
f0101759:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101760:	e8 59 e9 ff ff       	call   f01000be <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101765:	89 f2                	mov    %esi,%edx
f0101767:	2b 15 cc df 17 f0    	sub    0xf017dfcc,%edx
f010176d:	c1 fa 03             	sar    $0x3,%edx
f0101770:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101773:	89 d0                	mov    %edx,%eax
f0101775:	c1 e8 0c             	shr    $0xc,%eax
f0101778:	3b 05 c4 df 17 f0    	cmp    0xf017dfc4,%eax
f010177e:	72 20                	jb     f01017a0 <mem_init+0x5c0>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101780:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101784:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f010178b:	f0 
f010178c:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101793:	00 
f0101794:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f010179b:	e8 1e e9 ff ff       	call   f01000be <_panic>
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
		assert(c[i] == 0);
f01017a0:	80 ba 00 00 00 f0 00 	cmpb   $0x0,-0x10000000(%edx)
f01017a7:	75 11                	jne    f01017ba <mem_init+0x5da>
f01017a9:	8d 82 01 00 00 f0    	lea    -0xfffffff(%edx),%eax
f01017af:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f01017b5:	80 38 00             	cmpb   $0x0,(%eax)
f01017b8:	74 24                	je     f01017de <mem_init+0x5fe>
f01017ba:	c7 44 24 0c 62 5f 10 	movl   $0xf0105f62,0xc(%esp)
f01017c1:	f0 
f01017c2:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f01017c9:	f0 
f01017ca:	c7 44 24 04 cb 02 00 	movl   $0x2cb,0x4(%esp)
f01017d1:	00 
f01017d2:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01017d9:	e8 e0 e8 ff ff       	call   f01000be <_panic>
f01017de:	83 c0 01             	add    $0x1,%eax
	memset(page2kva(pp0), 1, PGSIZE);
	page_free(pp0);
	assert((pp = page_alloc(ALLOC_ZERO)));
	assert(pp && pp0 == pp);
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
f01017e1:	39 d0                	cmp    %edx,%eax
f01017e3:	75 d0                	jne    f01017b5 <mem_init+0x5d5>
		assert(c[i] == 0);

	// give free list back
	page_free_list = fl;
f01017e5:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01017e8:	a3 fc d2 17 f0       	mov    %eax,0xf017d2fc

	// free the pages we took
	page_free(pp0);
f01017ed:	89 34 24             	mov    %esi,(%esp)
f01017f0:	e8 3d f7 ff ff       	call   f0100f32 <page_free>
	page_free(pp1);
f01017f5:	89 3c 24             	mov    %edi,(%esp)
f01017f8:	e8 35 f7 ff ff       	call   f0100f32 <page_free>
	page_free(pp2);
f01017fd:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101800:	89 04 24             	mov    %eax,(%esp)
f0101803:	e8 2a f7 ff ff       	call   f0100f32 <page_free>

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101808:	a1 fc d2 17 f0       	mov    0xf017d2fc,%eax
f010180d:	85 c0                	test   %eax,%eax
f010180f:	74 09                	je     f010181a <mem_init+0x63a>
		--nfree;
f0101811:	83 eb 01             	sub    $0x1,%ebx
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101814:	8b 00                	mov    (%eax),%eax
f0101816:	85 c0                	test   %eax,%eax
f0101818:	75 f7                	jne    f0101811 <mem_init+0x631>
		--nfree;
	assert(nfree == 0);
f010181a:	85 db                	test   %ebx,%ebx
f010181c:	74 24                	je     f0101842 <mem_init+0x662>
f010181e:	c7 44 24 0c 6c 5f 10 	movl   $0xf0105f6c,0xc(%esp)
f0101825:	f0 
f0101826:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f010182d:	f0 
f010182e:	c7 44 24 04 d8 02 00 	movl   $0x2d8,0x4(%esp)
f0101835:	00 
f0101836:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f010183d:	e8 7c e8 ff ff       	call   f01000be <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f0101842:	c7 04 24 18 58 10 f0 	movl   $0xf0105818,(%esp)
f0101849:	e8 ff 1f 00 00       	call   f010384d <cprintf>
	int i;
	extern pde_t entry_pgdir[];

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f010184e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101855:	e8 53 f6 ff ff       	call   f0100ead <page_alloc>
f010185a:	89 c3                	mov    %eax,%ebx
f010185c:	85 c0                	test   %eax,%eax
f010185e:	75 24                	jne    f0101884 <mem_init+0x6a4>
f0101860:	c7 44 24 0c 7a 5e 10 	movl   $0xf0105e7a,0xc(%esp)
f0101867:	f0 
f0101868:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f010186f:	f0 
f0101870:	c7 44 24 04 36 03 00 	movl   $0x336,0x4(%esp)
f0101877:	00 
f0101878:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f010187f:	e8 3a e8 ff ff       	call   f01000be <_panic>
	assert((pp1 = page_alloc(0)));
f0101884:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010188b:	e8 1d f6 ff ff       	call   f0100ead <page_alloc>
f0101890:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0101893:	85 c0                	test   %eax,%eax
f0101895:	75 24                	jne    f01018bb <mem_init+0x6db>
f0101897:	c7 44 24 0c 90 5e 10 	movl   $0xf0105e90,0xc(%esp)
f010189e:	f0 
f010189f:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f01018a6:	f0 
f01018a7:	c7 44 24 04 37 03 00 	movl   $0x337,0x4(%esp)
f01018ae:	00 
f01018af:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01018b6:	e8 03 e8 ff ff       	call   f01000be <_panic>
	assert((pp2 = page_alloc(0)));
f01018bb:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018c2:	e8 e6 f5 ff ff       	call   f0100ead <page_alloc>
f01018c7:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01018ca:	85 c0                	test   %eax,%eax
f01018cc:	75 24                	jne    f01018f2 <mem_init+0x712>
f01018ce:	c7 44 24 0c a6 5e 10 	movl   $0xf0105ea6,0xc(%esp)
f01018d5:	f0 
f01018d6:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f01018dd:	f0 
f01018de:	c7 44 24 04 38 03 00 	movl   $0x338,0x4(%esp)
f01018e5:	00 
f01018e6:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01018ed:	e8 cc e7 ff ff       	call   f01000be <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f01018f2:	3b 5d d0             	cmp    -0x30(%ebp),%ebx
f01018f5:	75 24                	jne    f010191b <mem_init+0x73b>
f01018f7:	c7 44 24 0c bc 5e 10 	movl   $0xf0105ebc,0xc(%esp)
f01018fe:	f0 
f01018ff:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101906:	f0 
f0101907:	c7 44 24 04 3b 03 00 	movl   $0x33b,0x4(%esp)
f010190e:	00 
f010190f:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101916:	e8 a3 e7 ff ff       	call   f01000be <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f010191b:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010191e:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0101921:	74 04                	je     f0101927 <mem_init+0x747>
f0101923:	39 c3                	cmp    %eax,%ebx
f0101925:	75 24                	jne    f010194b <mem_init+0x76b>
f0101927:	c7 44 24 0c f8 57 10 	movl   $0xf01057f8,0xc(%esp)
f010192e:	f0 
f010192f:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101936:	f0 
f0101937:	c7 44 24 04 3c 03 00 	movl   $0x33c,0x4(%esp)
f010193e:	00 
f010193f:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101946:	e8 73 e7 ff ff       	call   f01000be <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f010194b:	a1 fc d2 17 f0       	mov    0xf017d2fc,%eax
f0101950:	89 45 cc             	mov    %eax,-0x34(%ebp)
	page_free_list = 0;
f0101953:	c7 05 fc d2 17 f0 00 	movl   $0x0,0xf017d2fc
f010195a:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f010195d:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101964:	e8 44 f5 ff ff       	call   f0100ead <page_alloc>
f0101969:	85 c0                	test   %eax,%eax
f010196b:	74 24                	je     f0101991 <mem_init+0x7b1>
f010196d:	c7 44 24 0c 25 5f 10 	movl   $0xf0105f25,0xc(%esp)
f0101974:	f0 
f0101975:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f010197c:	f0 
f010197d:	c7 44 24 04 43 03 00 	movl   $0x343,0x4(%esp)
f0101984:	00 
f0101985:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f010198c:	e8 2d e7 ff ff       	call   f01000be <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f0101991:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101994:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101998:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010199f:	00 
f01019a0:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f01019a5:	89 04 24             	mov    %eax,(%esp)
f01019a8:	e8 c7 f6 ff ff       	call   f0101074 <page_lookup>
f01019ad:	85 c0                	test   %eax,%eax
f01019af:	74 24                	je     f01019d5 <mem_init+0x7f5>
f01019b1:	c7 44 24 0c 38 58 10 	movl   $0xf0105838,0xc(%esp)
f01019b8:	f0 
f01019b9:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f01019c0:	f0 
f01019c1:	c7 44 24 04 46 03 00 	movl   $0x346,0x4(%esp)
f01019c8:	00 
f01019c9:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01019d0:	e8 e9 e6 ff ff       	call   f01000be <_panic>

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);
f01019d5:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01019dc:	00 
f01019dd:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01019e4:	00 
f01019e5:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01019e8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01019ec:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f01019f1:	89 04 24             	mov    %eax,(%esp)
f01019f4:	e8 26 f7 ff ff       	call   f010111f <page_insert>
f01019f9:	85 c0                	test   %eax,%eax
f01019fb:	78 24                	js     f0101a21 <mem_init+0x841>
f01019fd:	c7 44 24 0c 70 58 10 	movl   $0xf0105870,0xc(%esp)
f0101a04:	f0 
f0101a05:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101a0c:	f0 
f0101a0d:	c7 44 24 04 49 03 00 	movl   $0x349,0x4(%esp)
f0101a14:	00 
f0101a15:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101a1c:	e8 9d e6 ff ff       	call   f01000be <_panic>

	// free pp0 and try again: pp0 should be used for page table
	page_free(pp0);
f0101a21:	89 1c 24             	mov    %ebx,(%esp)
f0101a24:	e8 09 f5 ff ff       	call   f0100f32 <page_free>
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) == 0);
f0101a29:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101a30:	00 
f0101a31:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101a38:	00 
f0101a39:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101a3c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101a40:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0101a45:	89 04 24             	mov    %eax,(%esp)
f0101a48:	e8 d2 f6 ff ff       	call   f010111f <page_insert>
f0101a4d:	85 c0                	test   %eax,%eax
f0101a4f:	74 24                	je     f0101a75 <mem_init+0x895>
f0101a51:	c7 44 24 0c a0 58 10 	movl   $0xf01058a0,0xc(%esp)
f0101a58:	f0 
f0101a59:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101a60:	f0 
f0101a61:	c7 44 24 04 4d 03 00 	movl   $0x34d,0x4(%esp)
f0101a68:	00 
f0101a69:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101a70:	e8 49 e6 ff ff       	call   f01000be <_panic>
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101a75:	8b 35 c8 df 17 f0    	mov    0xf017dfc8,%esi
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101a7b:	8b 3d cc df 17 f0    	mov    0xf017dfcc,%edi
f0101a81:	8b 16                	mov    (%esi),%edx
f0101a83:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0101a89:	89 d8                	mov    %ebx,%eax
f0101a8b:	29 f8                	sub    %edi,%eax
f0101a8d:	c1 f8 03             	sar    $0x3,%eax
f0101a90:	c1 e0 0c             	shl    $0xc,%eax
f0101a93:	39 c2                	cmp    %eax,%edx
f0101a95:	74 24                	je     f0101abb <mem_init+0x8db>
f0101a97:	c7 44 24 0c d0 58 10 	movl   $0xf01058d0,0xc(%esp)
f0101a9e:	f0 
f0101a9f:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101aa6:	f0 
f0101aa7:	c7 44 24 04 4e 03 00 	movl   $0x34e,0x4(%esp)
f0101aae:	00 
f0101aaf:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101ab6:	e8 03 e6 ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, 0x0) == page2pa(pp1));
f0101abb:	ba 00 00 00 00       	mov    $0x0,%edx
f0101ac0:	89 f0                	mov    %esi,%eax
f0101ac2:	e8 2d ef ff ff       	call   f01009f4 <check_va2pa>
f0101ac7:	8b 55 d0             	mov    -0x30(%ebp),%edx
f0101aca:	29 fa                	sub    %edi,%edx
f0101acc:	c1 fa 03             	sar    $0x3,%edx
f0101acf:	c1 e2 0c             	shl    $0xc,%edx
f0101ad2:	39 d0                	cmp    %edx,%eax
f0101ad4:	74 24                	je     f0101afa <mem_init+0x91a>
f0101ad6:	c7 44 24 0c f8 58 10 	movl   $0xf01058f8,0xc(%esp)
f0101add:	f0 
f0101ade:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101ae5:	f0 
f0101ae6:	c7 44 24 04 4f 03 00 	movl   $0x34f,0x4(%esp)
f0101aed:	00 
f0101aee:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101af5:	e8 c4 e5 ff ff       	call   f01000be <_panic>
	assert(pp1->pp_ref == 1);
f0101afa:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101afd:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101b02:	74 24                	je     f0101b28 <mem_init+0x948>
f0101b04:	c7 44 24 0c 77 5f 10 	movl   $0xf0105f77,0xc(%esp)
f0101b0b:	f0 
f0101b0c:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101b13:	f0 
f0101b14:	c7 44 24 04 50 03 00 	movl   $0x350,0x4(%esp)
f0101b1b:	00 
f0101b1c:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101b23:	e8 96 e5 ff ff       	call   f01000be <_panic>
	assert(pp0->pp_ref == 1);
f0101b28:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0101b2d:	74 24                	je     f0101b53 <mem_init+0x973>
f0101b2f:	c7 44 24 0c 88 5f 10 	movl   $0xf0105f88,0xc(%esp)
f0101b36:	f0 
f0101b37:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101b3e:	f0 
f0101b3f:	c7 44 24 04 51 03 00 	movl   $0x351,0x4(%esp)
f0101b46:	00 
f0101b47:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101b4e:	e8 6b e5 ff ff       	call   f01000be <_panic>

	// should be able to map pp2 at PGSIZE because pp0 is already allocated for page table
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101b53:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101b5a:	00 
f0101b5b:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101b62:	00 
f0101b63:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101b66:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101b6a:	89 34 24             	mov    %esi,(%esp)
f0101b6d:	e8 ad f5 ff ff       	call   f010111f <page_insert>
f0101b72:	85 c0                	test   %eax,%eax
f0101b74:	74 24                	je     f0101b9a <mem_init+0x9ba>
f0101b76:	c7 44 24 0c 28 59 10 	movl   $0xf0105928,0xc(%esp)
f0101b7d:	f0 
f0101b7e:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101b85:	f0 
f0101b86:	c7 44 24 04 54 03 00 	movl   $0x354,0x4(%esp)
f0101b8d:	00 
f0101b8e:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101b95:	e8 24 e5 ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101b9a:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101b9f:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0101ba4:	e8 4b ee ff ff       	call   f01009f4 <check_va2pa>
f0101ba9:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101bac:	2b 15 cc df 17 f0    	sub    0xf017dfcc,%edx
f0101bb2:	c1 fa 03             	sar    $0x3,%edx
f0101bb5:	c1 e2 0c             	shl    $0xc,%edx
f0101bb8:	39 d0                	cmp    %edx,%eax
f0101bba:	74 24                	je     f0101be0 <mem_init+0xa00>
f0101bbc:	c7 44 24 0c 64 59 10 	movl   $0xf0105964,0xc(%esp)
f0101bc3:	f0 
f0101bc4:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101bcb:	f0 
f0101bcc:	c7 44 24 04 55 03 00 	movl   $0x355,0x4(%esp)
f0101bd3:	00 
f0101bd4:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101bdb:	e8 de e4 ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 1);
f0101be0:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101be3:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101be8:	74 24                	je     f0101c0e <mem_init+0xa2e>
f0101bea:	c7 44 24 0c 99 5f 10 	movl   $0xf0105f99,0xc(%esp)
f0101bf1:	f0 
f0101bf2:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101bf9:	f0 
f0101bfa:	c7 44 24 04 56 03 00 	movl   $0x356,0x4(%esp)
f0101c01:	00 
f0101c02:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101c09:	e8 b0 e4 ff ff       	call   f01000be <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0101c0e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101c15:	e8 93 f2 ff ff       	call   f0100ead <page_alloc>
f0101c1a:	85 c0                	test   %eax,%eax
f0101c1c:	74 24                	je     f0101c42 <mem_init+0xa62>
f0101c1e:	c7 44 24 0c 25 5f 10 	movl   $0xf0105f25,0xc(%esp)
f0101c25:	f0 
f0101c26:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101c2d:	f0 
f0101c2e:	c7 44 24 04 59 03 00 	movl   $0x359,0x4(%esp)
f0101c35:	00 
f0101c36:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101c3d:	e8 7c e4 ff ff       	call   f01000be <_panic>

	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101c42:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101c49:	00 
f0101c4a:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101c51:	00 
f0101c52:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101c55:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101c59:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0101c5e:	89 04 24             	mov    %eax,(%esp)
f0101c61:	e8 b9 f4 ff ff       	call   f010111f <page_insert>
f0101c66:	85 c0                	test   %eax,%eax
f0101c68:	74 24                	je     f0101c8e <mem_init+0xaae>
f0101c6a:	c7 44 24 0c 28 59 10 	movl   $0xf0105928,0xc(%esp)
f0101c71:	f0 
f0101c72:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101c79:	f0 
f0101c7a:	c7 44 24 04 5c 03 00 	movl   $0x35c,0x4(%esp)
f0101c81:	00 
f0101c82:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101c89:	e8 30 e4 ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101c8e:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101c93:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0101c98:	e8 57 ed ff ff       	call   f01009f4 <check_va2pa>
f0101c9d:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101ca0:	2b 15 cc df 17 f0    	sub    0xf017dfcc,%edx
f0101ca6:	c1 fa 03             	sar    $0x3,%edx
f0101ca9:	c1 e2 0c             	shl    $0xc,%edx
f0101cac:	39 d0                	cmp    %edx,%eax
f0101cae:	74 24                	je     f0101cd4 <mem_init+0xaf4>
f0101cb0:	c7 44 24 0c 64 59 10 	movl   $0xf0105964,0xc(%esp)
f0101cb7:	f0 
f0101cb8:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101cbf:	f0 
f0101cc0:	c7 44 24 04 5d 03 00 	movl   $0x35d,0x4(%esp)
f0101cc7:	00 
f0101cc8:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101ccf:	e8 ea e3 ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 1);
f0101cd4:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101cd7:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101cdc:	74 24                	je     f0101d02 <mem_init+0xb22>
f0101cde:	c7 44 24 0c 99 5f 10 	movl   $0xf0105f99,0xc(%esp)
f0101ce5:	f0 
f0101ce6:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101ced:	f0 
f0101cee:	c7 44 24 04 5e 03 00 	movl   $0x35e,0x4(%esp)
f0101cf5:	00 
f0101cf6:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101cfd:	e8 bc e3 ff ff       	call   f01000be <_panic>

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));
f0101d02:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101d09:	e8 9f f1 ff ff       	call   f0100ead <page_alloc>
f0101d0e:	85 c0                	test   %eax,%eax
f0101d10:	74 24                	je     f0101d36 <mem_init+0xb56>
f0101d12:	c7 44 24 0c 25 5f 10 	movl   $0xf0105f25,0xc(%esp)
f0101d19:	f0 
f0101d1a:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101d21:	f0 
f0101d22:	c7 44 24 04 62 03 00 	movl   $0x362,0x4(%esp)
f0101d29:	00 
f0101d2a:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101d31:	e8 88 e3 ff ff       	call   f01000be <_panic>

	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f0101d36:	8b 15 c8 df 17 f0    	mov    0xf017dfc8,%edx
f0101d3c:	8b 02                	mov    (%edx),%eax
f0101d3e:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101d43:	89 c1                	mov    %eax,%ecx
f0101d45:	c1 e9 0c             	shr    $0xc,%ecx
f0101d48:	3b 0d c4 df 17 f0    	cmp    0xf017dfc4,%ecx
f0101d4e:	72 20                	jb     f0101d70 <mem_init+0xb90>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101d50:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101d54:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f0101d5b:	f0 
f0101d5c:	c7 44 24 04 65 03 00 	movl   $0x365,0x4(%esp)
f0101d63:	00 
f0101d64:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101d6b:	e8 4e e3 ff ff       	call   f01000be <_panic>
	return (void *)(pa + KERNBASE);
f0101d70:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101d75:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	assert(pgdir_walk(kern_pgdir, (void*)PGSIZE, 0) == ptep+PTX(PGSIZE));
f0101d78:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101d7f:	00 
f0101d80:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0101d87:	00 
f0101d88:	89 14 24             	mov    %edx,(%esp)
f0101d8b:	e8 da f1 ff ff       	call   f0100f6a <pgdir_walk>
f0101d90:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0101d93:	8d 51 04             	lea    0x4(%ecx),%edx
f0101d96:	39 d0                	cmp    %edx,%eax
f0101d98:	74 24                	je     f0101dbe <mem_init+0xbde>
f0101d9a:	c7 44 24 0c 94 59 10 	movl   $0xf0105994,0xc(%esp)
f0101da1:	f0 
f0101da2:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101da9:	f0 
f0101daa:	c7 44 24 04 66 03 00 	movl   $0x366,0x4(%esp)
f0101db1:	00 
f0101db2:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101db9:	e8 00 e3 ff ff       	call   f01000be <_panic>

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
f0101dbe:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0101dc5:	00 
f0101dc6:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101dcd:	00 
f0101dce:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101dd1:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101dd5:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0101dda:	89 04 24             	mov    %eax,(%esp)
f0101ddd:	e8 3d f3 ff ff       	call   f010111f <page_insert>
f0101de2:	85 c0                	test   %eax,%eax
f0101de4:	74 24                	je     f0101e0a <mem_init+0xc2a>
f0101de6:	c7 44 24 0c d4 59 10 	movl   $0xf01059d4,0xc(%esp)
f0101ded:	f0 
f0101dee:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101df5:	f0 
f0101df6:	c7 44 24 04 69 03 00 	movl   $0x369,0x4(%esp)
f0101dfd:	00 
f0101dfe:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101e05:	e8 b4 e2 ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101e0a:	8b 35 c8 df 17 f0    	mov    0xf017dfc8,%esi
f0101e10:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101e15:	89 f0                	mov    %esi,%eax
f0101e17:	e8 d8 eb ff ff       	call   f01009f4 <check_va2pa>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101e1c:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101e1f:	2b 15 cc df 17 f0    	sub    0xf017dfcc,%edx
f0101e25:	c1 fa 03             	sar    $0x3,%edx
f0101e28:	c1 e2 0c             	shl    $0xc,%edx
f0101e2b:	39 d0                	cmp    %edx,%eax
f0101e2d:	74 24                	je     f0101e53 <mem_init+0xc73>
f0101e2f:	c7 44 24 0c 64 59 10 	movl   $0xf0105964,0xc(%esp)
f0101e36:	f0 
f0101e37:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101e3e:	f0 
f0101e3f:	c7 44 24 04 6a 03 00 	movl   $0x36a,0x4(%esp)
f0101e46:	00 
f0101e47:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101e4e:	e8 6b e2 ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 1);
f0101e53:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101e56:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101e5b:	74 24                	je     f0101e81 <mem_init+0xca1>
f0101e5d:	c7 44 24 0c 99 5f 10 	movl   $0xf0105f99,0xc(%esp)
f0101e64:	f0 
f0101e65:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101e6c:	f0 
f0101e6d:	c7 44 24 04 6b 03 00 	movl   $0x36b,0x4(%esp)
f0101e74:	00 
f0101e75:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101e7c:	e8 3d e2 ff ff       	call   f01000be <_panic>
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U);
f0101e81:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101e88:	00 
f0101e89:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0101e90:	00 
f0101e91:	89 34 24             	mov    %esi,(%esp)
f0101e94:	e8 d1 f0 ff ff       	call   f0100f6a <pgdir_walk>
f0101e99:	f6 00 04             	testb  $0x4,(%eax)
f0101e9c:	75 24                	jne    f0101ec2 <mem_init+0xce2>
f0101e9e:	c7 44 24 0c 14 5a 10 	movl   $0xf0105a14,0xc(%esp)
f0101ea5:	f0 
f0101ea6:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101ead:	f0 
f0101eae:	c7 44 24 04 6c 03 00 	movl   $0x36c,0x4(%esp)
f0101eb5:	00 
f0101eb6:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101ebd:	e8 fc e1 ff ff       	call   f01000be <_panic>
	assert(kern_pgdir[0] & PTE_U);
f0101ec2:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0101ec7:	f6 00 04             	testb  $0x4,(%eax)
f0101eca:	75 24                	jne    f0101ef0 <mem_init+0xd10>
f0101ecc:	c7 44 24 0c aa 5f 10 	movl   $0xf0105faa,0xc(%esp)
f0101ed3:	f0 
f0101ed4:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101edb:	f0 
f0101edc:	c7 44 24 04 6d 03 00 	movl   $0x36d,0x4(%esp)
f0101ee3:	00 
f0101ee4:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101eeb:	e8 ce e1 ff ff       	call   f01000be <_panic>

	// should not be able to map at PTSIZE because need free page for page table
	assert(page_insert(kern_pgdir, pp0, (void*) PTSIZE, PTE_W) < 0);
f0101ef0:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101ef7:	00 
f0101ef8:	c7 44 24 08 00 00 40 	movl   $0x400000,0x8(%esp)
f0101eff:	00 
f0101f00:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101f04:	89 04 24             	mov    %eax,(%esp)
f0101f07:	e8 13 f2 ff ff       	call   f010111f <page_insert>
f0101f0c:	85 c0                	test   %eax,%eax
f0101f0e:	78 24                	js     f0101f34 <mem_init+0xd54>
f0101f10:	c7 44 24 0c 48 5a 10 	movl   $0xf0105a48,0xc(%esp)
f0101f17:	f0 
f0101f18:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101f1f:	f0 
f0101f20:	c7 44 24 04 70 03 00 	movl   $0x370,0x4(%esp)
f0101f27:	00 
f0101f28:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101f2f:	e8 8a e1 ff ff       	call   f01000be <_panic>

	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
f0101f34:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101f3b:	00 
f0101f3c:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101f43:	00 
f0101f44:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101f47:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101f4b:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0101f50:	89 04 24             	mov    %eax,(%esp)
f0101f53:	e8 c7 f1 ff ff       	call   f010111f <page_insert>
f0101f58:	85 c0                	test   %eax,%eax
f0101f5a:	74 24                	je     f0101f80 <mem_init+0xda0>
f0101f5c:	c7 44 24 0c 80 5a 10 	movl   $0xf0105a80,0xc(%esp)
f0101f63:	f0 
f0101f64:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101f6b:	f0 
f0101f6c:	c7 44 24 04 73 03 00 	movl   $0x373,0x4(%esp)
f0101f73:	00 
f0101f74:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101f7b:	e8 3e e1 ff ff       	call   f01000be <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f0101f80:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101f87:	00 
f0101f88:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0101f8f:	00 
f0101f90:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0101f95:	89 04 24             	mov    %eax,(%esp)
f0101f98:	e8 cd ef ff ff       	call   f0100f6a <pgdir_walk>
f0101f9d:	f6 00 04             	testb  $0x4,(%eax)
f0101fa0:	74 24                	je     f0101fc6 <mem_init+0xde6>
f0101fa2:	c7 44 24 0c bc 5a 10 	movl   $0xf0105abc,0xc(%esp)
f0101fa9:	f0 
f0101faa:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101fb1:	f0 
f0101fb2:	c7 44 24 04 74 03 00 	movl   $0x374,0x4(%esp)
f0101fb9:	00 
f0101fba:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0101fc1:	e8 f8 e0 ff ff       	call   f01000be <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f0101fc6:	8b 3d c8 df 17 f0    	mov    0xf017dfc8,%edi
f0101fcc:	ba 00 00 00 00       	mov    $0x0,%edx
f0101fd1:	89 f8                	mov    %edi,%eax
f0101fd3:	e8 1c ea ff ff       	call   f01009f4 <check_va2pa>
f0101fd8:	89 c6                	mov    %eax,%esi
f0101fda:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101fdd:	2b 05 cc df 17 f0    	sub    0xf017dfcc,%eax
f0101fe3:	c1 f8 03             	sar    $0x3,%eax
f0101fe6:	c1 e0 0c             	shl    $0xc,%eax
f0101fe9:	39 c6                	cmp    %eax,%esi
f0101feb:	74 24                	je     f0102011 <mem_init+0xe31>
f0101fed:	c7 44 24 0c f4 5a 10 	movl   $0xf0105af4,0xc(%esp)
f0101ff4:	f0 
f0101ff5:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0101ffc:	f0 
f0101ffd:	c7 44 24 04 77 03 00 	movl   $0x377,0x4(%esp)
f0102004:	00 
f0102005:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f010200c:	e8 ad e0 ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102011:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102016:	89 f8                	mov    %edi,%eax
f0102018:	e8 d7 e9 ff ff       	call   f01009f4 <check_va2pa>
f010201d:	39 c6                	cmp    %eax,%esi
f010201f:	74 24                	je     f0102045 <mem_init+0xe65>
f0102021:	c7 44 24 0c 20 5b 10 	movl   $0xf0105b20,0xc(%esp)
f0102028:	f0 
f0102029:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102030:	f0 
f0102031:	c7 44 24 04 78 03 00 	movl   $0x378,0x4(%esp)
f0102038:	00 
f0102039:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102040:	e8 79 e0 ff ff       	call   f01000be <_panic>
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
f0102045:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102048:	66 83 78 04 02       	cmpw   $0x2,0x4(%eax)
f010204d:	74 24                	je     f0102073 <mem_init+0xe93>
f010204f:	c7 44 24 0c c0 5f 10 	movl   $0xf0105fc0,0xc(%esp)
f0102056:	f0 
f0102057:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f010205e:	f0 
f010205f:	c7 44 24 04 7a 03 00 	movl   $0x37a,0x4(%esp)
f0102066:	00 
f0102067:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f010206e:	e8 4b e0 ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 0);
f0102073:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102076:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f010207b:	74 24                	je     f01020a1 <mem_init+0xec1>
f010207d:	c7 44 24 0c d1 5f 10 	movl   $0xf0105fd1,0xc(%esp)
f0102084:	f0 
f0102085:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f010208c:	f0 
f010208d:	c7 44 24 04 7b 03 00 	movl   $0x37b,0x4(%esp)
f0102094:	00 
f0102095:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f010209c:	e8 1d e0 ff ff       	call   f01000be <_panic>

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);
f01020a1:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01020a8:	e8 00 ee ff ff       	call   f0100ead <page_alloc>
f01020ad:	85 c0                	test   %eax,%eax
f01020af:	74 05                	je     f01020b6 <mem_init+0xed6>
f01020b1:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f01020b4:	74 24                	je     f01020da <mem_init+0xefa>
f01020b6:	c7 44 24 0c 50 5b 10 	movl   $0xf0105b50,0xc(%esp)
f01020bd:	f0 
f01020be:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f01020c5:	f0 
f01020c6:	c7 44 24 04 7e 03 00 	movl   $0x37e,0x4(%esp)
f01020cd:	00 
f01020ce:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01020d5:	e8 e4 df ff ff       	call   f01000be <_panic>

	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f01020da:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01020e1:	00 
f01020e2:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f01020e7:	89 04 24             	mov    %eax,(%esp)
f01020ea:	e8 f2 ef ff ff       	call   f01010e1 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01020ef:	8b 35 c8 df 17 f0    	mov    0xf017dfc8,%esi
f01020f5:	ba 00 00 00 00       	mov    $0x0,%edx
f01020fa:	89 f0                	mov    %esi,%eax
f01020fc:	e8 f3 e8 ff ff       	call   f01009f4 <check_va2pa>
f0102101:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102104:	74 24                	je     f010212a <mem_init+0xf4a>
f0102106:	c7 44 24 0c 74 5b 10 	movl   $0xf0105b74,0xc(%esp)
f010210d:	f0 
f010210e:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102115:	f0 
f0102116:	c7 44 24 04 82 03 00 	movl   $0x382,0x4(%esp)
f010211d:	00 
f010211e:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102125:	e8 94 df ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f010212a:	ba 00 10 00 00       	mov    $0x1000,%edx
f010212f:	89 f0                	mov    %esi,%eax
f0102131:	e8 be e8 ff ff       	call   f01009f4 <check_va2pa>
f0102136:	8b 55 d0             	mov    -0x30(%ebp),%edx
f0102139:	2b 15 cc df 17 f0    	sub    0xf017dfcc,%edx
f010213f:	c1 fa 03             	sar    $0x3,%edx
f0102142:	c1 e2 0c             	shl    $0xc,%edx
f0102145:	39 d0                	cmp    %edx,%eax
f0102147:	74 24                	je     f010216d <mem_init+0xf8d>
f0102149:	c7 44 24 0c 20 5b 10 	movl   $0xf0105b20,0xc(%esp)
f0102150:	f0 
f0102151:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102158:	f0 
f0102159:	c7 44 24 04 83 03 00 	movl   $0x383,0x4(%esp)
f0102160:	00 
f0102161:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102168:	e8 51 df ff ff       	call   f01000be <_panic>
	assert(pp1->pp_ref == 1);
f010216d:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102170:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0102175:	74 24                	je     f010219b <mem_init+0xfbb>
f0102177:	c7 44 24 0c 77 5f 10 	movl   $0xf0105f77,0xc(%esp)
f010217e:	f0 
f010217f:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102186:	f0 
f0102187:	c7 44 24 04 84 03 00 	movl   $0x384,0x4(%esp)
f010218e:	00 
f010218f:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102196:	e8 23 df ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 0);
f010219b:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010219e:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f01021a3:	74 24                	je     f01021c9 <mem_init+0xfe9>
f01021a5:	c7 44 24 0c d1 5f 10 	movl   $0xf0105fd1,0xc(%esp)
f01021ac:	f0 
f01021ad:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f01021b4:	f0 
f01021b5:	c7 44 24 04 85 03 00 	movl   $0x385,0x4(%esp)
f01021bc:	00 
f01021bd:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01021c4:	e8 f5 de ff ff       	call   f01000be <_panic>

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
f01021c9:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01021d0:	00 
f01021d1:	89 34 24             	mov    %esi,(%esp)
f01021d4:	e8 08 ef ff ff       	call   f01010e1 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01021d9:	8b 35 c8 df 17 f0    	mov    0xf017dfc8,%esi
f01021df:	ba 00 00 00 00       	mov    $0x0,%edx
f01021e4:	89 f0                	mov    %esi,%eax
f01021e6:	e8 09 e8 ff ff       	call   f01009f4 <check_va2pa>
f01021eb:	83 f8 ff             	cmp    $0xffffffff,%eax
f01021ee:	74 24                	je     f0102214 <mem_init+0x1034>
f01021f0:	c7 44 24 0c 74 5b 10 	movl   $0xf0105b74,0xc(%esp)
f01021f7:	f0 
f01021f8:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f01021ff:	f0 
f0102200:	c7 44 24 04 89 03 00 	movl   $0x389,0x4(%esp)
f0102207:	00 
f0102208:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f010220f:	e8 aa de ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
f0102214:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102219:	89 f0                	mov    %esi,%eax
f010221b:	e8 d4 e7 ff ff       	call   f01009f4 <check_va2pa>
f0102220:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102223:	74 24                	je     f0102249 <mem_init+0x1069>
f0102225:	c7 44 24 0c 98 5b 10 	movl   $0xf0105b98,0xc(%esp)
f010222c:	f0 
f010222d:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102234:	f0 
f0102235:	c7 44 24 04 8a 03 00 	movl   $0x38a,0x4(%esp)
f010223c:	00 
f010223d:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102244:	e8 75 de ff ff       	call   f01000be <_panic>
	assert(pp1->pp_ref == 0);
f0102249:	8b 45 d0             	mov    -0x30(%ebp),%eax
f010224c:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102251:	74 24                	je     f0102277 <mem_init+0x1097>
f0102253:	c7 44 24 0c e2 5f 10 	movl   $0xf0105fe2,0xc(%esp)
f010225a:	f0 
f010225b:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102262:	f0 
f0102263:	c7 44 24 04 8b 03 00 	movl   $0x38b,0x4(%esp)
f010226a:	00 
f010226b:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102272:	e8 47 de ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 0);
f0102277:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010227a:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f010227f:	74 24                	je     f01022a5 <mem_init+0x10c5>
f0102281:	c7 44 24 0c d1 5f 10 	movl   $0xf0105fd1,0xc(%esp)
f0102288:	f0 
f0102289:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102290:	f0 
f0102291:	c7 44 24 04 8c 03 00 	movl   $0x38c,0x4(%esp)
f0102298:	00 
f0102299:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01022a0:	e8 19 de ff ff       	call   f01000be <_panic>

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);
f01022a5:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01022ac:	e8 fc eb ff ff       	call   f0100ead <page_alloc>
f01022b1:	85 c0                	test   %eax,%eax
f01022b3:	74 05                	je     f01022ba <mem_init+0x10da>
f01022b5:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f01022b8:	74 24                	je     f01022de <mem_init+0x10fe>
f01022ba:	c7 44 24 0c c0 5b 10 	movl   $0xf0105bc0,0xc(%esp)
f01022c1:	f0 
f01022c2:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f01022c9:	f0 
f01022ca:	c7 44 24 04 8f 03 00 	movl   $0x38f,0x4(%esp)
f01022d1:	00 
f01022d2:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01022d9:	e8 e0 dd ff ff       	call   f01000be <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f01022de:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01022e5:	e8 c3 eb ff ff       	call   f0100ead <page_alloc>
f01022ea:	85 c0                	test   %eax,%eax
f01022ec:	74 24                	je     f0102312 <mem_init+0x1132>
f01022ee:	c7 44 24 0c 25 5f 10 	movl   $0xf0105f25,0xc(%esp)
f01022f5:	f0 
f01022f6:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f01022fd:	f0 
f01022fe:	c7 44 24 04 92 03 00 	movl   $0x392,0x4(%esp)
f0102305:	00 
f0102306:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f010230d:	e8 ac dd ff ff       	call   f01000be <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102312:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0102317:	8b 08                	mov    (%eax),%ecx
f0102319:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f010231f:	89 da                	mov    %ebx,%edx
f0102321:	2b 15 cc df 17 f0    	sub    0xf017dfcc,%edx
f0102327:	c1 fa 03             	sar    $0x3,%edx
f010232a:	c1 e2 0c             	shl    $0xc,%edx
f010232d:	39 d1                	cmp    %edx,%ecx
f010232f:	74 24                	je     f0102355 <mem_init+0x1175>
f0102331:	c7 44 24 0c d0 58 10 	movl   $0xf01058d0,0xc(%esp)
f0102338:	f0 
f0102339:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102340:	f0 
f0102341:	c7 44 24 04 95 03 00 	movl   $0x395,0x4(%esp)
f0102348:	00 
f0102349:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102350:	e8 69 dd ff ff       	call   f01000be <_panic>
	kern_pgdir[0] = 0;
f0102355:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f010235b:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102360:	74 24                	je     f0102386 <mem_init+0x11a6>
f0102362:	c7 44 24 0c 88 5f 10 	movl   $0xf0105f88,0xc(%esp)
f0102369:	f0 
f010236a:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102371:	f0 
f0102372:	c7 44 24 04 97 03 00 	movl   $0x397,0x4(%esp)
f0102379:	00 
f010237a:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102381:	e8 38 dd ff ff       	call   f01000be <_panic>
	pp0->pp_ref = 0;
f0102386:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// check pointer arithmetic in pgdir_walk
	page_free(pp0);
f010238c:	89 1c 24             	mov    %ebx,(%esp)
f010238f:	e8 9e eb ff ff       	call   f0100f32 <page_free>
	va = (void*)(PGSIZE * NPDENTRIES + PGSIZE);
	ptep = pgdir_walk(kern_pgdir, va, 1);
f0102394:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010239b:	00 
f010239c:	c7 44 24 04 00 10 40 	movl   $0x401000,0x4(%esp)
f01023a3:	00 
f01023a4:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f01023a9:	89 04 24             	mov    %eax,(%esp)
f01023ac:	e8 b9 eb ff ff       	call   f0100f6a <pgdir_walk>
f01023b1:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f01023b4:	8b 0d c8 df 17 f0    	mov    0xf017dfc8,%ecx
f01023ba:	8b 51 04             	mov    0x4(%ecx),%edx
f01023bd:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01023c3:	8b 3d c4 df 17 f0    	mov    0xf017dfc4,%edi
f01023c9:	89 d6                	mov    %edx,%esi
f01023cb:	c1 ee 0c             	shr    $0xc,%esi
f01023ce:	39 fe                	cmp    %edi,%esi
f01023d0:	72 20                	jb     f01023f2 <mem_init+0x1212>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01023d2:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01023d6:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f01023dd:	f0 
f01023de:	c7 44 24 04 9e 03 00 	movl   $0x39e,0x4(%esp)
f01023e5:	00 
f01023e6:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01023ed:	e8 cc dc ff ff       	call   f01000be <_panic>
	assert(ptep == ptep1 + PTX(va));
f01023f2:	81 ea fc ff ff 0f    	sub    $0xffffffc,%edx
f01023f8:	39 d0                	cmp    %edx,%eax
f01023fa:	74 24                	je     f0102420 <mem_init+0x1240>
f01023fc:	c7 44 24 0c f3 5f 10 	movl   $0xf0105ff3,0xc(%esp)
f0102403:	f0 
f0102404:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f010240b:	f0 
f010240c:	c7 44 24 04 9f 03 00 	movl   $0x39f,0x4(%esp)
f0102413:	00 
f0102414:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f010241b:	e8 9e dc ff ff       	call   f01000be <_panic>
	kern_pgdir[PDX(va)] = 0;
f0102420:	c7 41 04 00 00 00 00 	movl   $0x0,0x4(%ecx)
	pp0->pp_ref = 0;
f0102427:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010242d:	89 d8                	mov    %ebx,%eax
f010242f:	2b 05 cc df 17 f0    	sub    0xf017dfcc,%eax
f0102435:	c1 f8 03             	sar    $0x3,%eax
f0102438:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010243b:	89 c2                	mov    %eax,%edx
f010243d:	c1 ea 0c             	shr    $0xc,%edx
f0102440:	39 d7                	cmp    %edx,%edi
f0102442:	77 20                	ja     f0102464 <mem_init+0x1284>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102444:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102448:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f010244f:	f0 
f0102450:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102457:	00 
f0102458:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f010245f:	e8 5a dc ff ff       	call   f01000be <_panic>

	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
f0102464:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010246b:	00 
f010246c:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
f0102473:	00 
	return (void *)(pa + KERNBASE);
f0102474:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102479:	89 04 24             	mov    %eax,(%esp)
f010247c:	e8 98 27 00 00       	call   f0104c19 <memset>
	page_free(pp0);
f0102481:	89 1c 24             	mov    %ebx,(%esp)
f0102484:	e8 a9 ea ff ff       	call   f0100f32 <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f0102489:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0102490:	00 
f0102491:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0102498:	00 
f0102499:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f010249e:	89 04 24             	mov    %eax,(%esp)
f01024a1:	e8 c4 ea ff ff       	call   f0100f6a <pgdir_walk>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01024a6:	89 da                	mov    %ebx,%edx
f01024a8:	2b 15 cc df 17 f0    	sub    0xf017dfcc,%edx
f01024ae:	c1 fa 03             	sar    $0x3,%edx
f01024b1:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01024b4:	89 d0                	mov    %edx,%eax
f01024b6:	c1 e8 0c             	shr    $0xc,%eax
f01024b9:	3b 05 c4 df 17 f0    	cmp    0xf017dfc4,%eax
f01024bf:	72 20                	jb     f01024e1 <mem_init+0x1301>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01024c1:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01024c5:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f01024cc:	f0 
f01024cd:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01024d4:	00 
f01024d5:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f01024dc:	e8 dd db ff ff       	call   f01000be <_panic>
	return (void *)(pa + KERNBASE);
f01024e1:	8d 82 00 00 00 f0    	lea    -0x10000000(%edx),%eax
	ptep = (pte_t *) page2kva(pp0);
f01024e7:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	for(i=0; i<NPTENTRIES; i++)
		assert((ptep[i] & PTE_P) == 0);
f01024ea:	f6 82 00 00 00 f0 01 	testb  $0x1,-0x10000000(%edx)
f01024f1:	75 13                	jne    f0102506 <mem_init+0x1326>
f01024f3:	8d 82 04 00 00 f0    	lea    -0xffffffc(%edx),%eax
f01024f9:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f01024ff:	8b 38                	mov    (%eax),%edi
f0102501:	83 e7 01             	and    $0x1,%edi
f0102504:	74 24                	je     f010252a <mem_init+0x134a>
f0102506:	c7 44 24 0c 0b 60 10 	movl   $0xf010600b,0xc(%esp)
f010250d:	f0 
f010250e:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102515:	f0 
f0102516:	c7 44 24 04 a9 03 00 	movl   $0x3a9,0x4(%esp)
f010251d:	00 
f010251e:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102525:	e8 94 db ff ff       	call   f01000be <_panic>
f010252a:	83 c0 04             	add    $0x4,%eax
	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
	page_free(pp0);
	pgdir_walk(kern_pgdir, 0x0, 1);
	ptep = (pte_t *) page2kva(pp0);
	for(i=0; i<NPTENTRIES; i++)
f010252d:	39 d0                	cmp    %edx,%eax
f010252f:	75 ce                	jne    f01024ff <mem_init+0x131f>
		assert((ptep[i] & PTE_P) == 0);
	kern_pgdir[0] = 0;
f0102531:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0102536:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f010253c:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// give free list back
	page_free_list = fl;
f0102542:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0102545:	a3 fc d2 17 f0       	mov    %eax,0xf017d2fc

	// free the pages we took
	page_free(pp0);
f010254a:	89 1c 24             	mov    %ebx,(%esp)
f010254d:	e8 e0 e9 ff ff       	call   f0100f32 <page_free>
	page_free(pp1);
f0102552:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102555:	89 04 24             	mov    %eax,(%esp)
f0102558:	e8 d5 e9 ff ff       	call   f0100f32 <page_free>
	page_free(pp2);
f010255d:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102560:	89 04 24             	mov    %eax,(%esp)
f0102563:	e8 ca e9 ff ff       	call   f0100f32 <page_free>

	cprintf("check_page() succeeded!\n");
f0102568:	c7 04 24 22 60 10 f0 	movl   $0xf0106022,(%esp)
f010256f:	e8 d9 12 00 00       	call   f010384d <cprintf>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f0102574:	8b 0d c4 df 17 f0    	mov    0xf017dfc4,%ecx
f010257a:	8d 04 cd ff 0f 00 00 	lea    0xfff(,%ecx,8),%eax
f0102581:	89 c2                	mov    %eax,%edx
f0102583:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
f0102589:	39 d0                	cmp    %edx,%eax
f010258b:	0f 84 c9 09 00 00    	je     f0102f5a <mem_init+0x1d7a>
		page_insert(kern_pgdir, pa2page(PADDR(pages) + i), (void *)(UPAGES + i), PTE_U);
f0102591:	a1 cc df 17 f0       	mov    0xf017dfcc,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102596:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010259b:	76 21                	jbe    f01025be <mem_init+0x13de>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f010259d:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01025a3:	c1 ea 0c             	shr    $0xc,%edx
f01025a6:	39 d1                	cmp    %edx,%ecx
f01025a8:	77 62                	ja     f010260c <mem_init+0x142c>
f01025aa:	eb 44                	jmp    f01025f0 <mem_init+0x1410>
f01025ac:	8d bb 00 10 00 ef    	lea    -0x10fff000(%ebx),%edi
f01025b2:	a1 cc df 17 f0       	mov    0xf017dfcc,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01025b7:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01025bc:	77 20                	ja     f01025de <mem_init+0x13fe>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01025be:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01025c2:	c7 44 24 08 d4 57 10 	movl   $0xf01057d4,0x8(%esp)
f01025c9:	f0 
f01025ca:	c7 44 24 04 bc 00 00 	movl   $0xbc,0x4(%esp)
f01025d1:	00 
f01025d2:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01025d9:	e8 e0 da ff ff       	call   f01000be <_panic>
f01025de:	8d 94 18 00 10 00 10 	lea    0x10001000(%eax,%ebx,1),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01025e5:	c1 ea 0c             	shr    $0xc,%edx
f01025e8:	39 d6                	cmp    %edx,%esi
f01025ea:	76 04                	jbe    f01025f0 <mem_init+0x1410>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f01025ec:	89 cb                	mov    %ecx,%ebx
f01025ee:	eb 2b                	jmp    f010261b <mem_init+0x143b>
		panic("pa2page called with invalid pa");
f01025f0:	c7 44 24 08 78 57 10 	movl   $0xf0105778,0x8(%esp)
f01025f7:	f0 
f01025f8:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01025ff:	00 
f0102600:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f0102607:	e8 b2 da ff ff       	call   f01000be <_panic>
		page_insert(kern_pgdir, pa2page(PADDR(pages) + i), (void *)(UPAGES + i), PTE_U);
f010260c:	b9 00 00 00 ef       	mov    $0xef000000,%ecx
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f0102611:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102616:	89 7d d4             	mov    %edi,-0x2c(%ebp)
f0102619:	89 cf                	mov    %ecx,%edi
		page_insert(kern_pgdir, pa2page(PADDR(pages) + i), (void *)(UPAGES + i), PTE_U);
f010261b:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f0102622:	00 
f0102623:	89 7c 24 08          	mov    %edi,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102627:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f010262a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010262e:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0102633:	89 04 24             	mov    %eax,(%esp)
f0102636:	e8 e4 ea ff ff       	call   f010111f <page_insert>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f010263b:	8d 8b 00 10 00 00    	lea    0x1000(%ebx),%ecx
f0102641:	8b 35 c4 df 17 f0    	mov    0xf017dfc4,%esi
f0102647:	8d 04 f5 ff 0f 00 00 	lea    0xfff(,%esi,8),%eax
f010264e:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102653:	39 c8                	cmp    %ecx,%eax
f0102655:	0f 87 51 ff ff ff    	ja     f01025ac <mem_init+0x13cc>
f010265b:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f010265e:	e9 f7 08 00 00       	jmp    f0102f5a <mem_init+0x1d7a>
static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102663:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102668:	c1 e8 0c             	shr    $0xc,%eax
f010266b:	3b 05 c4 df 17 f0    	cmp    0xf017dfc4,%eax
f0102671:	0f 82 71 09 00 00    	jb     f0102fe8 <mem_init+0x1e08>
f0102677:	eb 44                	jmp    f01026bd <mem_init+0x14dd>
f0102679:	8d 93 00 00 c0 ee    	lea    -0x11400000(%ebx),%edx
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		page_insert(kern_pgdir,pa2page(PADDR(envs)+i),(void *)(UENVS + i),PTE_U);
f010267f:	a1 08 d3 17 f0       	mov    0xf017d308,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102684:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102689:	77 20                	ja     f01026ab <mem_init+0x14cb>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010268b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010268f:	c7 44 24 08 d4 57 10 	movl   $0xf01057d4,0x8(%esp)
f0102696:	f0 
f0102697:	c7 44 24 04 c6 00 00 	movl   $0xc6,0x4(%esp)
f010269e:	00 
f010269f:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01026a6:	e8 13 da ff ff       	call   f01000be <_panic>
f01026ab:	8d 84 18 00 00 00 10 	lea    0x10000000(%eax,%ebx,1),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01026b2:	c1 e8 0c             	shr    $0xc,%eax
f01026b5:	3b 05 c4 df 17 f0    	cmp    0xf017dfc4,%eax
f01026bb:	72 1c                	jb     f01026d9 <mem_init+0x14f9>
		panic("pa2page called with invalid pa");
f01026bd:	c7 44 24 08 78 57 10 	movl   $0xf0105778,0x8(%esp)
f01026c4:	f0 
f01026c5:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01026cc:	00 
f01026cd:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f01026d4:	e8 e5 d9 ff ff       	call   f01000be <_panic>
f01026d9:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f01026e0:	00 
f01026e1:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f01026e5:	8b 15 cc df 17 f0    	mov    0xf017dfcc,%edx
f01026eb:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01026ee:	89 44 24 04          	mov    %eax,0x4(%esp)
f01026f2:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f01026f7:	89 04 24             	mov    %eax,(%esp)
f01026fa:	e8 20 ea ff ff       	call   f010111f <page_insert>
	// (ie. perm = PTE_U | PTE_P).
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f01026ff:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102705:	81 fb 00 80 01 00    	cmp    $0x18000,%ebx
f010270b:	0f 85 68 ff ff ff    	jne    f0102679 <mem_init+0x1499>
f0102711:	e9 59 08 00 00       	jmp    f0102f6f <mem_init+0x1d8f>
static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102716:	b8 00 10 11 00       	mov    $0x111000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010271b:	c1 e8 0c             	shr    $0xc,%eax
f010271e:	3b 05 c4 df 17 f0    	cmp    0xf017dfc4,%eax
f0102724:	0f 82 78 08 00 00    	jb     f0102fa2 <mem_init+0x1dc2>
f010272a:	eb 39                	jmp    f0102765 <mem_init+0x1585>
f010272c:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010272f:	8d 14 18             	lea    (%eax,%ebx,1),%edx
f0102732:	89 d8                	mov    %ebx,%eax
f0102734:	c1 e8 0c             	shr    $0xc,%eax
f0102737:	3b 05 c4 df 17 f0    	cmp    0xf017dfc4,%eax
f010273d:	72 42                	jb     f0102781 <mem_init+0x15a1>
f010273f:	eb 24                	jmp    f0102765 <mem_init+0x1585>

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102741:	c7 44 24 0c 00 10 11 	movl   $0xf0111000,0xc(%esp)
f0102748:	f0 
f0102749:	c7 44 24 08 d4 57 10 	movl   $0xf01057d4,0x8(%esp)
f0102750:	f0 
f0102751:	c7 44 24 04 d3 00 00 	movl   $0xd3,0x4(%esp)
f0102758:	00 
f0102759:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102760:	e8 59 d9 ff ff       	call   f01000be <_panic>

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
f0102765:	c7 44 24 08 78 57 10 	movl   $0xf0105778,0x8(%esp)
f010276c:	f0 
f010276d:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102774:	00 
f0102775:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f010277c:	e8 3d d9 ff ff       	call   f01000be <_panic>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		page_insert(kern_pgdir, pa2page(PADDR(bootstack) + i), (void *)(KSTACKTOP-KSTKSIZE + i), PTE_W);
f0102781:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102788:	00 
f0102789:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f010278d:	8b 15 cc df 17 f0    	mov    0xf017dfcc,%edx
f0102793:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102796:	89 44 24 04          	mov    %eax,0x4(%esp)
f010279a:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f010279f:	89 04 24             	mov    %eax,(%esp)
f01027a2:	e8 78 e9 ff ff       	call   f010111f <page_insert>
f01027a7:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	//     * [KSTACKTOP-PTSIZE, KSTACKTOP-KSTKSIZE) -- not backed; so if
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
f01027ad:	39 f3                	cmp    %esi,%ebx
f01027af:	0f 85 77 ff ff ff    	jne    f010272c <mem_init+0x154c>
f01027b5:	e9 ca 07 00 00       	jmp    f0102f84 <mem_init+0x1da4>
f01027ba:	8d b3 00 10 00 f0    	lea    -0xffff000(%ebx),%esi
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W);
f01027c0:	8b 1d c4 df 17 f0    	mov    0xf017dfc4,%ebx
f01027c6:	89 df                	mov    %ebx,%edi
f01027c8:	c1 e7 0c             	shl    $0xc,%edi
f01027cb:	89 c8                	mov    %ecx,%eax
f01027cd:	ba 00 00 00 00       	mov    $0x0,%edx
f01027d2:	f7 f7                	div    %edi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01027d4:	c1 ea 0c             	shr    $0xc,%edx
f01027d7:	39 d3                	cmp    %edx,%ebx
f01027d9:	77 1c                	ja     f01027f7 <mem_init+0x1617>
		panic("pa2page called with invalid pa");
f01027db:	c7 44 24 08 78 57 10 	movl   $0xf0105778,0x8(%esp)
f01027e2:	f0 
f01027e3:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01027ea:	00 
f01027eb:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f01027f2:	e8 c7 d8 ff ff       	call   f01000be <_panic>
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
f01027f7:	89 cb                	mov    %ecx,%ebx
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W);
f01027f9:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102800:	00 
f0102801:	89 74 24 08          	mov    %esi,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102805:	a1 cc df 17 f0       	mov    0xf017dfcc,%eax
f010280a:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f010280d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102811:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0102816:	89 04 24             	mov    %eax,(%esp)
f0102819:	e8 01 e9 ff ff       	call   f010111f <page_insert>
		pa2page(i % (npages*PGSIZE))->pp_ref--;                 //this statement is to keep pp_ref == 0 in page_free_list
f010281e:	8b 0d c4 df 17 f0    	mov    0xf017dfc4,%ecx
f0102824:	89 ce                	mov    %ecx,%esi
f0102826:	c1 e6 0c             	shl    $0xc,%esi
f0102829:	89 d8                	mov    %ebx,%eax
f010282b:	ba 00 00 00 00       	mov    $0x0,%edx
f0102830:	f7 f6                	div    %esi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102832:	c1 ea 0c             	shr    $0xc,%edx
f0102835:	39 d1                	cmp    %edx,%ecx
f0102837:	77 1c                	ja     f0102855 <mem_init+0x1675>
		panic("pa2page called with invalid pa");
f0102839:	c7 44 24 08 78 57 10 	movl   $0xf0105778,0x8(%esp)
f0102840:	f0 
f0102841:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102848:	00 
f0102849:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f0102850:	e8 69 d8 ff ff       	call   f01000be <_panic>
	return &pages[PGNUM(pa)];
f0102855:	a1 cc df 17 f0       	mov    0xf017dfcc,%eax
f010285a:	66 83 6c d0 04 01    	subw   $0x1,0x4(%eax,%edx,8)
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
f0102860:	8d 8b 00 10 00 00    	lea    0x1000(%ebx),%ecx
f0102866:	81 f9 00 00 00 10    	cmp    $0x10000000,%ecx
f010286c:	0f 85 48 ff ff ff    	jne    f01027ba <mem_init+0x15da>
check_kern_pgdir(void)
{
	uint32_t i, n;
	pde_t *pgdir;

	pgdir = kern_pgdir;
f0102872:	8b 35 c8 df 17 f0    	mov    0xf017dfc8,%esi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
f0102878:	a1 c4 df 17 f0       	mov    0xf017dfc4,%eax
f010287d:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0102880:	8d 04 c5 ff 0f 00 00 	lea    0xfff(,%eax,8),%eax
	for (i = 0; i < n; i += PGSIZE)
f0102887:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f010288c:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f010288f:	75 30                	jne    f01028c1 <mem_init+0x16e1>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102891:	8b 1d 08 d3 17 f0    	mov    0xf017d308,%ebx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102897:	89 df                	mov    %ebx,%edi
f0102899:	ba 00 00 c0 ee       	mov    $0xeec00000,%edx
f010289e:	89 f0                	mov    %esi,%eax
f01028a0:	e8 4f e1 ff ff       	call   f01009f4 <check_va2pa>
f01028a5:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f01028ab:	0f 86 94 00 00 00    	jbe    f0102945 <mem_init+0x1765>
f01028b1:	bb 00 00 c0 ee       	mov    $0xeec00000,%ebx
f01028b6:	81 c7 00 00 40 21    	add    $0x21400000,%edi
f01028bc:	e9 a4 00 00 00       	jmp    f0102965 <mem_init+0x1785>
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f01028c1:	8b 1d cc df 17 f0    	mov    0xf017dfcc,%ebx
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f01028c7:	8d bb 00 00 00 10    	lea    0x10000000(%ebx),%edi
f01028cd:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f01028d2:	89 f0                	mov    %esi,%eax
f01028d4:	e8 1b e1 ff ff       	call   f01009f4 <check_va2pa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01028d9:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f01028df:	77 20                	ja     f0102901 <mem_init+0x1721>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01028e1:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f01028e5:	c7 44 24 08 d4 57 10 	movl   $0xf01057d4,0x8(%esp)
f01028ec:	f0 
f01028ed:	c7 44 24 04 f0 02 00 	movl   $0x2f0,0x4(%esp)
f01028f4:	00 
f01028f5:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01028fc:	e8 bd d7 ff ff       	call   f01000be <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102901:	ba 00 00 00 00       	mov    $0x0,%edx
f0102906:	8d 0c 17             	lea    (%edi,%edx,1),%ecx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102909:	39 c1                	cmp    %eax,%ecx
f010290b:	74 24                	je     f0102931 <mem_init+0x1751>
f010290d:	c7 44 24 0c e4 5b 10 	movl   $0xf0105be4,0xc(%esp)
f0102914:	f0 
f0102915:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f010291c:	f0 
f010291d:	c7 44 24 04 f0 02 00 	movl   $0x2f0,0x4(%esp)
f0102924:	00 
f0102925:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f010292c:	e8 8d d7 ff ff       	call   f01000be <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102931:	8d 9a 00 10 00 00    	lea    0x1000(%edx),%ebx
f0102937:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f010293a:	0f 87 19 07 00 00    	ja     f0103059 <mem_init+0x1e79>
f0102940:	e9 4c ff ff ff       	jmp    f0102891 <mem_init+0x16b1>
f0102945:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102949:	c7 44 24 08 d4 57 10 	movl   $0xf01057d4,0x8(%esp)
f0102950:	f0 
f0102951:	c7 44 24 04 f5 02 00 	movl   $0x2f5,0x4(%esp)
f0102958:	00 
f0102959:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102960:	e8 59 d7 ff ff       	call   f01000be <_panic>
f0102965:	8d 14 1f             	lea    (%edi,%ebx,1),%edx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102968:	39 c2                	cmp    %eax,%edx
f010296a:	74 24                	je     f0102990 <mem_init+0x17b0>
f010296c:	c7 44 24 0c 18 5c 10 	movl   $0xf0105c18,0xc(%esp)
f0102973:	f0 
f0102974:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f010297b:	f0 
f010297c:	c7 44 24 04 f5 02 00 	movl   $0x2f5,0x4(%esp)
f0102983:	00 
f0102984:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f010298b:	e8 2e d7 ff ff       	call   f01000be <_panic>
f0102990:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102996:	81 fb 00 80 c1 ee    	cmp    $0xeec18000,%ebx
f010299c:	0f 85 a9 06 00 00    	jne    f010304b <mem_init+0x1e6b>
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f01029a2:	8b 7d d0             	mov    -0x30(%ebp),%edi
f01029a5:	c1 e7 0c             	shl    $0xc,%edi
f01029a8:	85 ff                	test   %edi,%edi
f01029aa:	0f 84 7a 06 00 00    	je     f010302a <mem_init+0x1e4a>
f01029b0:	bb 00 00 00 00       	mov    $0x0,%ebx
f01029b5:	8d 93 00 00 00 f0    	lea    -0x10000000(%ebx),%edx
		assert(check_va2pa(pgdir, KERNBASE + i) == i);
f01029bb:	89 f0                	mov    %esi,%eax
f01029bd:	e8 32 e0 ff ff       	call   f01009f4 <check_va2pa>
f01029c2:	39 c3                	cmp    %eax,%ebx
f01029c4:	74 24                	je     f01029ea <mem_init+0x180a>
f01029c6:	c7 44 24 0c 4c 5c 10 	movl   $0xf0105c4c,0xc(%esp)
f01029cd:	f0 
f01029ce:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f01029d5:	f0 
f01029d6:	c7 44 24 04 f9 02 00 	movl   $0x2f9,0x4(%esp)
f01029dd:	00 
f01029de:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f01029e5:	e8 d4 d6 ff ff       	call   f01000be <_panic>
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f01029ea:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f01029f0:	39 fb                	cmp    %edi,%ebx
f01029f2:	72 c1                	jb     f01029b5 <mem_init+0x17d5>
f01029f4:	e9 31 06 00 00       	jmp    f010302a <mem_init+0x1e4a>
f01029f9:	8d 14 1f             	lea    (%edi,%ebx,1),%edx
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check kernel stack
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
f01029fc:	39 d0                	cmp    %edx,%eax
f01029fe:	74 24                	je     f0102a24 <mem_init+0x1844>
f0102a00:	c7 44 24 0c 74 5c 10 	movl   $0xf0105c74,0xc(%esp)
f0102a07:	f0 
f0102a08:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102a0f:	f0 
f0102a10:	c7 44 24 04 fd 02 00 	movl   $0x2fd,0x4(%esp)
f0102a17:	00 
f0102a18:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102a1f:	e8 9a d6 ff ff       	call   f01000be <_panic>
f0102a24:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check kernel stack
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102a2a:	81 fb 00 00 c0 ef    	cmp    $0xefc00000,%ebx
f0102a30:	0f 85 e6 05 00 00    	jne    f010301c <mem_init+0x1e3c>
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
	assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);
f0102a36:	ba 00 00 80 ef       	mov    $0xef800000,%edx
f0102a3b:	89 f0                	mov    %esi,%eax
f0102a3d:	e8 b2 df ff ff       	call   f01009f4 <check_va2pa>
f0102a42:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102a45:	74 24                	je     f0102a6b <mem_init+0x188b>
f0102a47:	c7 44 24 0c bc 5c 10 	movl   $0xf0105cbc,0xc(%esp)
f0102a4e:	f0 
f0102a4f:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102a56:	f0 
f0102a57:	c7 44 24 04 fe 02 00 	movl   $0x2fe,0x4(%esp)
f0102a5e:	00 
f0102a5f:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102a66:	e8 53 d6 ff ff       	call   f01000be <_panic>
f0102a6b:	b8 00 00 00 00       	mov    $0x0,%eax

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
		switch (i) {
f0102a70:	8d 90 45 fc ff ff    	lea    -0x3bb(%eax),%edx
f0102a76:	83 fa 03             	cmp    $0x3,%edx
f0102a79:	77 2e                	ja     f0102aa9 <mem_init+0x18c9>
		case PDX(UVPT):
		case PDX(KSTACKTOP-1):
		case PDX(UPAGES):
		case PDX(UENVS):
			assert(pgdir[i] & PTE_P);
f0102a7b:	f6 04 86 01          	testb  $0x1,(%esi,%eax,4)
f0102a7f:	0f 85 aa 00 00 00    	jne    f0102b2f <mem_init+0x194f>
f0102a85:	c7 44 24 0c 3b 60 10 	movl   $0xf010603b,0xc(%esp)
f0102a8c:	f0 
f0102a8d:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102a94:	f0 
f0102a95:	c7 44 24 04 07 03 00 	movl   $0x307,0x4(%esp)
f0102a9c:	00 
f0102a9d:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102aa4:	e8 15 d6 ff ff       	call   f01000be <_panic>
			break;
		default:
			if (i >= PDX(KERNBASE)) {
f0102aa9:	3d bf 03 00 00       	cmp    $0x3bf,%eax
f0102aae:	76 55                	jbe    f0102b05 <mem_init+0x1925>
				assert(pgdir[i] & PTE_P);
f0102ab0:	8b 14 86             	mov    (%esi,%eax,4),%edx
f0102ab3:	f6 c2 01             	test   $0x1,%dl
f0102ab6:	75 24                	jne    f0102adc <mem_init+0x18fc>
f0102ab8:	c7 44 24 0c 3b 60 10 	movl   $0xf010603b,0xc(%esp)
f0102abf:	f0 
f0102ac0:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102ac7:	f0 
f0102ac8:	c7 44 24 04 0b 03 00 	movl   $0x30b,0x4(%esp)
f0102acf:	00 
f0102ad0:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102ad7:	e8 e2 d5 ff ff       	call   f01000be <_panic>
				assert(pgdir[i] & PTE_W);
f0102adc:	f6 c2 02             	test   $0x2,%dl
f0102adf:	75 4e                	jne    f0102b2f <mem_init+0x194f>
f0102ae1:	c7 44 24 0c 4c 60 10 	movl   $0xf010604c,0xc(%esp)
f0102ae8:	f0 
f0102ae9:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102af0:	f0 
f0102af1:	c7 44 24 04 0c 03 00 	movl   $0x30c,0x4(%esp)
f0102af8:	00 
f0102af9:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102b00:	e8 b9 d5 ff ff       	call   f01000be <_panic>
			} else
				assert(pgdir[i] == 0);
f0102b05:	83 3c 86 00          	cmpl   $0x0,(%esi,%eax,4)
f0102b09:	74 24                	je     f0102b2f <mem_init+0x194f>
f0102b0b:	c7 44 24 0c 5d 60 10 	movl   $0xf010605d,0xc(%esp)
f0102b12:	f0 
f0102b13:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102b1a:	f0 
f0102b1b:	c7 44 24 04 0e 03 00 	movl   $0x30e,0x4(%esp)
f0102b22:	00 
f0102b23:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102b2a:	e8 8f d5 ff ff       	call   f01000be <_panic>
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
	assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
f0102b2f:	83 c0 01             	add    $0x1,%eax
f0102b32:	3d 00 04 00 00       	cmp    $0x400,%eax
f0102b37:	0f 85 33 ff ff ff    	jne    f0102a70 <mem_init+0x1890>
			} else
				assert(pgdir[i] == 0);
			break;
		}
	}
	cprintf("check_kern_pgdir() succeeded!\n");
f0102b3d:	c7 04 24 ec 5c 10 f0 	movl   $0xf0105cec,(%esp)
f0102b44:	e8 04 0d 00 00       	call   f010384d <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f0102b49:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102b4e:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102b53:	77 20                	ja     f0102b75 <mem_init+0x1995>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102b55:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102b59:	c7 44 24 08 d4 57 10 	movl   $0xf01057d4,0x8(%esp)
f0102b60:	f0 
f0102b61:	c7 44 24 04 ec 00 00 	movl   $0xec,0x4(%esp)
f0102b68:	00 
f0102b69:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102b70:	e8 49 d5 ff ff       	call   f01000be <_panic>
	return (physaddr_t)kva - KERNBASE;
f0102b75:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0102b7a:	0f 22 d8             	mov    %eax,%cr3

	check_page_free_list(0);
f0102b7d:	b8 00 00 00 00       	mov    $0x0,%eax
f0102b82:	e8 dc de ff ff       	call   f0100a63 <check_page_free_list>

static __inline uint32_t
rcr0(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr0,%0" : "=r" (val));
f0102b87:	0f 20 c0             	mov    %cr0,%eax

	// entry.S set the really important flags in cr0 (including enabling
	// paging).  Here we configure the rest of the flags that we care about.
	cr0 = rcr0();
	cr0 |= CR0_PE|CR0_PG|CR0_AM|CR0_WP|CR0_NE|CR0_MP;
	cr0 &= ~(CR0_TS|CR0_EM);
f0102b8a:	83 e0 f3             	and    $0xfffffff3,%eax
f0102b8d:	0d 23 00 05 80       	or     $0x80050023,%eax
}

static __inline void
lcr0(uint32_t val)
{
	__asm __volatile("movl %0,%%cr0" : : "r" (val));
f0102b92:	0f 22 c0             	mov    %eax,%cr0
	uintptr_t va;
	int i;

	// check that we can read and write installed pages
	pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0102b95:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102b9c:	e8 0c e3 ff ff       	call   f0100ead <page_alloc>
f0102ba1:	89 c3                	mov    %eax,%ebx
f0102ba3:	85 c0                	test   %eax,%eax
f0102ba5:	75 24                	jne    f0102bcb <mem_init+0x19eb>
f0102ba7:	c7 44 24 0c 7a 5e 10 	movl   $0xf0105e7a,0xc(%esp)
f0102bae:	f0 
f0102baf:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102bb6:	f0 
f0102bb7:	c7 44 24 04 c4 03 00 	movl   $0x3c4,0x4(%esp)
f0102bbe:	00 
f0102bbf:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102bc6:	e8 f3 d4 ff ff       	call   f01000be <_panic>
	assert((pp1 = page_alloc(0)));
f0102bcb:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102bd2:	e8 d6 e2 ff ff       	call   f0100ead <page_alloc>
f0102bd7:	89 c7                	mov    %eax,%edi
f0102bd9:	85 c0                	test   %eax,%eax
f0102bdb:	75 24                	jne    f0102c01 <mem_init+0x1a21>
f0102bdd:	c7 44 24 0c 90 5e 10 	movl   $0xf0105e90,0xc(%esp)
f0102be4:	f0 
f0102be5:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102bec:	f0 
f0102bed:	c7 44 24 04 c5 03 00 	movl   $0x3c5,0x4(%esp)
f0102bf4:	00 
f0102bf5:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102bfc:	e8 bd d4 ff ff       	call   f01000be <_panic>
	assert((pp2 = page_alloc(0)));
f0102c01:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102c08:	e8 a0 e2 ff ff       	call   f0100ead <page_alloc>
f0102c0d:	89 c6                	mov    %eax,%esi
f0102c0f:	85 c0                	test   %eax,%eax
f0102c11:	75 24                	jne    f0102c37 <mem_init+0x1a57>
f0102c13:	c7 44 24 0c a6 5e 10 	movl   $0xf0105ea6,0xc(%esp)
f0102c1a:	f0 
f0102c1b:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102c22:	f0 
f0102c23:	c7 44 24 04 c6 03 00 	movl   $0x3c6,0x4(%esp)
f0102c2a:	00 
f0102c2b:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102c32:	e8 87 d4 ff ff       	call   f01000be <_panic>
	page_free(pp0);
f0102c37:	89 1c 24             	mov    %ebx,(%esp)
f0102c3a:	e8 f3 e2 ff ff       	call   f0100f32 <page_free>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102c3f:	89 f8                	mov    %edi,%eax
f0102c41:	2b 05 cc df 17 f0    	sub    0xf017dfcc,%eax
f0102c47:	c1 f8 03             	sar    $0x3,%eax
f0102c4a:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102c4d:	89 c2                	mov    %eax,%edx
f0102c4f:	c1 ea 0c             	shr    $0xc,%edx
f0102c52:	3b 15 c4 df 17 f0    	cmp    0xf017dfc4,%edx
f0102c58:	72 20                	jb     f0102c7a <mem_init+0x1a9a>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102c5a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102c5e:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f0102c65:	f0 
f0102c66:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102c6d:	00 
f0102c6e:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f0102c75:	e8 44 d4 ff ff       	call   f01000be <_panic>
	memset(page2kva(pp1), 1, PGSIZE);
f0102c7a:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102c81:	00 
f0102c82:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f0102c89:	00 
	return (void *)(pa + KERNBASE);
f0102c8a:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102c8f:	89 04 24             	mov    %eax,(%esp)
f0102c92:	e8 82 1f 00 00       	call   f0104c19 <memset>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102c97:	89 f0                	mov    %esi,%eax
f0102c99:	2b 05 cc df 17 f0    	sub    0xf017dfcc,%eax
f0102c9f:	c1 f8 03             	sar    $0x3,%eax
f0102ca2:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102ca5:	89 c2                	mov    %eax,%edx
f0102ca7:	c1 ea 0c             	shr    $0xc,%edx
f0102caa:	3b 15 c4 df 17 f0    	cmp    0xf017dfc4,%edx
f0102cb0:	72 20                	jb     f0102cd2 <mem_init+0x1af2>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102cb2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102cb6:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f0102cbd:	f0 
f0102cbe:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102cc5:	00 
f0102cc6:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f0102ccd:	e8 ec d3 ff ff       	call   f01000be <_panic>
	memset(page2kva(pp2), 2, PGSIZE);
f0102cd2:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102cd9:	00 
f0102cda:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102ce1:	00 
	return (void *)(pa + KERNBASE);
f0102ce2:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102ce7:	89 04 24             	mov    %eax,(%esp)
f0102cea:	e8 2a 1f 00 00       	call   f0104c19 <memset>
	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f0102cef:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102cf6:	00 
f0102cf7:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102cfe:	00 
f0102cff:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102d03:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0102d08:	89 04 24             	mov    %eax,(%esp)
f0102d0b:	e8 0f e4 ff ff       	call   f010111f <page_insert>
	assert(pp1->pp_ref == 1);
f0102d10:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0102d15:	74 24                	je     f0102d3b <mem_init+0x1b5b>
f0102d17:	c7 44 24 0c 77 5f 10 	movl   $0xf0105f77,0xc(%esp)
f0102d1e:	f0 
f0102d1f:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102d26:	f0 
f0102d27:	c7 44 24 04 cb 03 00 	movl   $0x3cb,0x4(%esp)
f0102d2e:	00 
f0102d2f:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102d36:	e8 83 d3 ff ff       	call   f01000be <_panic>
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
f0102d3b:	81 3d 00 10 00 00 01 	cmpl   $0x1010101,0x1000
f0102d42:	01 01 01 
f0102d45:	74 24                	je     f0102d6b <mem_init+0x1b8b>
f0102d47:	c7 44 24 0c 0c 5d 10 	movl   $0xf0105d0c,0xc(%esp)
f0102d4e:	f0 
f0102d4f:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102d56:	f0 
f0102d57:	c7 44 24 04 cc 03 00 	movl   $0x3cc,0x4(%esp)
f0102d5e:	00 
f0102d5f:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102d66:	e8 53 d3 ff ff       	call   f01000be <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f0102d6b:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102d72:	00 
f0102d73:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102d7a:	00 
f0102d7b:	89 74 24 04          	mov    %esi,0x4(%esp)
f0102d7f:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0102d84:	89 04 24             	mov    %eax,(%esp)
f0102d87:	e8 93 e3 ff ff       	call   f010111f <page_insert>
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
f0102d8c:	81 3d 00 10 00 00 02 	cmpl   $0x2020202,0x1000
f0102d93:	02 02 02 
f0102d96:	74 24                	je     f0102dbc <mem_init+0x1bdc>
f0102d98:	c7 44 24 0c 30 5d 10 	movl   $0xf0105d30,0xc(%esp)
f0102d9f:	f0 
f0102da0:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102da7:	f0 
f0102da8:	c7 44 24 04 ce 03 00 	movl   $0x3ce,0x4(%esp)
f0102daf:	00 
f0102db0:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102db7:	e8 02 d3 ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 1);
f0102dbc:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0102dc1:	74 24                	je     f0102de7 <mem_init+0x1c07>
f0102dc3:	c7 44 24 0c 99 5f 10 	movl   $0xf0105f99,0xc(%esp)
f0102dca:	f0 
f0102dcb:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102dd2:	f0 
f0102dd3:	c7 44 24 04 cf 03 00 	movl   $0x3cf,0x4(%esp)
f0102dda:	00 
f0102ddb:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102de2:	e8 d7 d2 ff ff       	call   f01000be <_panic>
	assert(pp1->pp_ref == 0);
f0102de7:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f0102dec:	74 24                	je     f0102e12 <mem_init+0x1c32>
f0102dee:	c7 44 24 0c e2 5f 10 	movl   $0xf0105fe2,0xc(%esp)
f0102df5:	f0 
f0102df6:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102dfd:	f0 
f0102dfe:	c7 44 24 04 d0 03 00 	movl   $0x3d0,0x4(%esp)
f0102e05:	00 
f0102e06:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102e0d:	e8 ac d2 ff ff       	call   f01000be <_panic>
	*(uint32_t *)PGSIZE = 0x03030303U;
f0102e12:	c7 05 00 10 00 00 03 	movl   $0x3030303,0x1000
f0102e19:	03 03 03 
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102e1c:	89 f0                	mov    %esi,%eax
f0102e1e:	2b 05 cc df 17 f0    	sub    0xf017dfcc,%eax
f0102e24:	c1 f8 03             	sar    $0x3,%eax
f0102e27:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102e2a:	89 c2                	mov    %eax,%edx
f0102e2c:	c1 ea 0c             	shr    $0xc,%edx
f0102e2f:	3b 15 c4 df 17 f0    	cmp    0xf017dfc4,%edx
f0102e35:	72 20                	jb     f0102e57 <mem_init+0x1c77>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102e37:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102e3b:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f0102e42:	f0 
f0102e43:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102e4a:	00 
f0102e4b:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f0102e52:	e8 67 d2 ff ff       	call   f01000be <_panic>
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
f0102e57:	81 b8 00 00 00 f0 03 	cmpl   $0x3030303,-0x10000000(%eax)
f0102e5e:	03 03 03 
f0102e61:	74 24                	je     f0102e87 <mem_init+0x1ca7>
f0102e63:	c7 44 24 0c 54 5d 10 	movl   $0xf0105d54,0xc(%esp)
f0102e6a:	f0 
f0102e6b:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102e72:	f0 
f0102e73:	c7 44 24 04 d2 03 00 	movl   $0x3d2,0x4(%esp)
f0102e7a:	00 
f0102e7b:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102e82:	e8 37 d2 ff ff       	call   f01000be <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f0102e87:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102e8e:	00 
f0102e8f:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0102e94:	89 04 24             	mov    %eax,(%esp)
f0102e97:	e8 45 e2 ff ff       	call   f01010e1 <page_remove>
	assert(pp2->pp_ref == 0);
f0102e9c:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f0102ea1:	74 24                	je     f0102ec7 <mem_init+0x1ce7>
f0102ea3:	c7 44 24 0c d1 5f 10 	movl   $0xf0105fd1,0xc(%esp)
f0102eaa:	f0 
f0102eab:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102eb2:	f0 
f0102eb3:	c7 44 24 04 d4 03 00 	movl   $0x3d4,0x4(%esp)
f0102eba:	00 
f0102ebb:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102ec2:	e8 f7 d1 ff ff       	call   f01000be <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102ec7:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0102ecc:	8b 08                	mov    (%eax),%ecx
f0102ece:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102ed4:	89 da                	mov    %ebx,%edx
f0102ed6:	2b 15 cc df 17 f0    	sub    0xf017dfcc,%edx
f0102edc:	c1 fa 03             	sar    $0x3,%edx
f0102edf:	c1 e2 0c             	shl    $0xc,%edx
f0102ee2:	39 d1                	cmp    %edx,%ecx
f0102ee4:	74 24                	je     f0102f0a <mem_init+0x1d2a>
f0102ee6:	c7 44 24 0c d0 58 10 	movl   $0xf01058d0,0xc(%esp)
f0102eed:	f0 
f0102eee:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102ef5:	f0 
f0102ef6:	c7 44 24 04 d7 03 00 	movl   $0x3d7,0x4(%esp)
f0102efd:	00 
f0102efe:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102f05:	e8 b4 d1 ff ff       	call   f01000be <_panic>
	kern_pgdir[0] = 0;
f0102f0a:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f0102f10:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102f15:	74 24                	je     f0102f3b <mem_init+0x1d5b>
f0102f17:	c7 44 24 0c 88 5f 10 	movl   $0xf0105f88,0xc(%esp)
f0102f1e:	f0 
f0102f1f:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0102f26:	f0 
f0102f27:	c7 44 24 04 d9 03 00 	movl   $0x3d9,0x4(%esp)
f0102f2e:	00 
f0102f2f:	c7 04 24 a9 5d 10 f0 	movl   $0xf0105da9,(%esp)
f0102f36:	e8 83 d1 ff ff       	call   f01000be <_panic>
	pp0->pp_ref = 0;
f0102f3b:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// free the pages we took
	page_free(pp0);
f0102f41:	89 1c 24             	mov    %ebx,(%esp)
f0102f44:	e8 e9 df ff ff       	call   f0100f32 <page_free>

	cprintf("check_page_installed_pgdir() succeeded!\n");
f0102f49:	c7 04 24 80 5d 10 f0 	movl   $0xf0105d80,(%esp)
f0102f50:	e8 f8 08 00 00       	call   f010384d <cprintf>
f0102f55:	e9 13 01 00 00       	jmp    f010306d <mem_init+0x1e8d>
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		page_insert(kern_pgdir,pa2page(PADDR(envs)+i),(void *)(UENVS + i),PTE_U);
f0102f5a:	a1 08 d3 17 f0       	mov    0xf017d308,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102f5f:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102f64:	0f 87 f9 f6 ff ff    	ja     f0102663 <mem_init+0x1483>
f0102f6a:	e9 1c f7 ff ff       	jmp    f010268b <mem_init+0x14ab>
f0102f6f:	b8 00 10 11 f0       	mov    $0xf0111000,%eax
f0102f74:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102f79:	0f 86 c2 f7 ff ff    	jbe    f0102741 <mem_init+0x1561>
f0102f7f:	e9 92 f7 ff ff       	jmp    f0102716 <mem_init+0x1536>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102f84:	83 3d c4 df 17 f0 00 	cmpl   $0x0,0xf017dfc4
f0102f8b:	0f 84 4a f8 ff ff    	je     f01027db <mem_init+0x15fb>
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W);
f0102f91:	be 00 00 00 f0       	mov    $0xf0000000,%esi
f0102f96:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102f9b:	89 fa                	mov    %edi,%edx
f0102f9d:	e9 57 f8 ff ff       	jmp    f01027f9 <mem_init+0x1619>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		page_insert(kern_pgdir, pa2page(PADDR(bootstack) + i), (void *)(KSTACKTOP-KSTKSIZE + i), PTE_W);
f0102fa2:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102fa9:	00 
f0102faa:	c7 44 24 08 00 80 bf 	movl   $0xefbf8000,0x8(%esp)
f0102fb1:	ef 
		panic("pa2page called with invalid pa");
	return &pages[PGNUM(pa)];
f0102fb2:	8b 15 cc df 17 f0    	mov    0xf017dfcc,%edx
f0102fb8:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102fbb:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102fbf:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f0102fc4:	89 04 24             	mov    %eax,(%esp)
f0102fc7:	e8 53 e1 ff ff       	call   f010111f <page_insert>
f0102fcc:	bb 00 20 11 00       	mov    $0x112000,%ebx
f0102fd1:	be 00 90 11 00       	mov    $0x119000,%esi
f0102fd6:	b8 00 80 bf df       	mov    $0xdfbf8000,%eax
f0102fdb:	2d 00 10 11 f0       	sub    $0xf0111000,%eax
f0102fe0:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0102fe3:	e9 44 f7 ff ff       	jmp    f010272c <mem_init+0x154c>
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		page_insert(kern_pgdir,pa2page(PADDR(envs)+i),(void *)(UENVS + i),PTE_U);
f0102fe8:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f0102fef:	00 
f0102ff0:	c7 44 24 08 00 00 c0 	movl   $0xeec00000,0x8(%esp)
f0102ff7:	ee 
f0102ff8:	8b 15 cc df 17 f0    	mov    0xf017dfcc,%edx
f0102ffe:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0103001:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103005:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
f010300a:	89 04 24             	mov    %eax,(%esp)
f010300d:	e8 0d e1 ff ff       	call   f010111f <page_insert>
	// (ie. perm = PTE_U | PTE_P).
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f0103012:	bb 00 10 00 00       	mov    $0x1000,%ebx
f0103017:	e9 5d f6 ff ff       	jmp    f0102679 <mem_init+0x1499>
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check kernel stack
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
f010301c:	89 da                	mov    %ebx,%edx
f010301e:	89 f0                	mov    %esi,%eax
f0103020:	e8 cf d9 ff ff       	call   f01009f4 <check_va2pa>
f0103025:	e9 cf f9 ff ff       	jmp    f01029f9 <mem_init+0x1819>
f010302a:	ba 00 80 bf ef       	mov    $0xefbf8000,%edx
f010302f:	89 f0                	mov    %esi,%eax
f0103031:	e8 be d9 ff ff       	call   f01009f4 <check_va2pa>
f0103036:	bb 00 80 bf ef       	mov    $0xefbf8000,%ebx
f010303b:	b9 00 10 11 f0       	mov    $0xf0111000,%ecx
f0103040:	8d b9 00 80 40 20    	lea    0x20408000(%ecx),%edi
f0103046:	e9 ae f9 ff ff       	jmp    f01029f9 <mem_init+0x1819>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f010304b:	89 da                	mov    %ebx,%edx
f010304d:	89 f0                	mov    %esi,%eax
f010304f:	e8 a0 d9 ff ff       	call   f01009f4 <check_va2pa>
f0103054:	e9 0c f9 ff ff       	jmp    f0102965 <mem_init+0x1785>
f0103059:	81 ea 00 f0 ff 10    	sub    $0x10fff000,%edx
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f010305f:	89 f0                	mov    %esi,%eax
f0103061:	e8 8e d9 ff ff       	call   f01009f4 <check_va2pa>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0103066:	89 da                	mov    %ebx,%edx
f0103068:	e9 99 f8 ff ff       	jmp    f0102906 <mem_init+0x1726>
	cr0 &= ~(CR0_TS|CR0_EM);
	lcr0(cr0);

	// Some more checks, only possible after kern_pgdir is installed.
	check_page_installed_pgdir();
}
f010306d:	83 c4 3c             	add    $0x3c,%esp
f0103070:	5b                   	pop    %ebx
f0103071:	5e                   	pop    %esi
f0103072:	5f                   	pop    %edi
f0103073:	5d                   	pop    %ebp
f0103074:	c3                   	ret    

f0103075 <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f0103075:	55                   	push   %ebp
f0103076:	89 e5                	mov    %esp,%ebp
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f0103078:	8b 45 0c             	mov    0xc(%ebp),%eax
f010307b:	0f 01 38             	invlpg (%eax)
	// Flush the entry only if we're modifying the current address space.
	// For now, there is only one address space, so always invalidate.
	invlpg(va);
}
f010307e:	5d                   	pop    %ebp
f010307f:	c3                   	ret    

f0103080 <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f0103080:	55                   	push   %ebp
f0103081:	89 e5                	mov    %esp,%ebp
	// LAB 3: Your code here.

	return 0;
}
f0103083:	b8 00 00 00 00       	mov    $0x0,%eax
f0103088:	5d                   	pop    %ebp
f0103089:	c3                   	ret    

f010308a <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f010308a:	55                   	push   %ebp
f010308b:	89 e5                	mov    %esp,%ebp
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
		cprintf("[%08x] user_mem_check assertion failure for "
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
	}
}
f010308d:	5d                   	pop    %ebp
f010308e:	c3                   	ret    

f010308f <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f010308f:	55                   	push   %ebp
f0103090:	89 e5                	mov    %esp,%ebp
f0103092:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f0103095:	85 c0                	test   %eax,%eax
f0103097:	75 11                	jne    f01030aa <envid2env+0x1b>
		*env_store = curenv;
f0103099:	a1 04 d3 17 f0       	mov    0xf017d304,%eax
f010309e:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01030a1:	89 01                	mov    %eax,(%ecx)
		return 0;
f01030a3:	b8 00 00 00 00       	mov    $0x0,%eax
f01030a8:	eb 60                	jmp    f010310a <envid2env+0x7b>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f01030aa:	89 c2                	mov    %eax,%edx
f01030ac:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f01030b2:	8d 14 52             	lea    (%edx,%edx,2),%edx
f01030b5:	c1 e2 05             	shl    $0x5,%edx
f01030b8:	03 15 08 d3 17 f0    	add    0xf017d308,%edx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f01030be:	83 7a 54 00          	cmpl   $0x0,0x54(%edx)
f01030c2:	74 05                	je     f01030c9 <envid2env+0x3a>
f01030c4:	39 42 48             	cmp    %eax,0x48(%edx)
f01030c7:	74 10                	je     f01030d9 <envid2env+0x4a>
		*env_store = 0;
f01030c9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01030cc:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f01030d2:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01030d7:	eb 31                	jmp    f010310a <envid2env+0x7b>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f01030d9:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f01030dd:	74 21                	je     f0103100 <envid2env+0x71>
f01030df:	a1 04 d3 17 f0       	mov    0xf017d304,%eax
f01030e4:	39 c2                	cmp    %eax,%edx
f01030e6:	74 18                	je     f0103100 <envid2env+0x71>
f01030e8:	8b 40 48             	mov    0x48(%eax),%eax
f01030eb:	39 42 4c             	cmp    %eax,0x4c(%edx)
f01030ee:	74 10                	je     f0103100 <envid2env+0x71>
		*env_store = 0;
f01030f0:	8b 45 0c             	mov    0xc(%ebp),%eax
f01030f3:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f01030f9:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01030fe:	eb 0a                	jmp    f010310a <envid2env+0x7b>
	}

	*env_store = e;
f0103100:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103103:	89 10                	mov    %edx,(%eax)
	return 0;
f0103105:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010310a:	5d                   	pop    %ebp
f010310b:	c3                   	ret    

f010310c <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f010310c:	55                   	push   %ebp
f010310d:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f010310f:	b8 00 b3 11 f0       	mov    $0xf011b300,%eax
f0103114:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f0103117:	b8 23 00 00 00       	mov    $0x23,%eax
f010311c:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f010311e:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f0103120:	b0 10                	mov    $0x10,%al
f0103122:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f0103124:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f0103126:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f0103128:	ea 2f 31 10 f0 08 00 	ljmp   $0x8,$0xf010312f
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f010312f:	b0 00                	mov    $0x0,%al
f0103131:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f0103134:	5d                   	pop    %ebp
f0103135:	c3                   	ret    

f0103136 <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f0103136:	55                   	push   %ebp
f0103137:	89 e5                	mov    %esp,%ebp
f0103139:	53                   	push   %ebx
f010313a:	8b 0d 0c d3 17 f0    	mov    0xf017d30c,%ecx
f0103140:	a1 08 d3 17 f0       	mov    0xf017d308,%eax
	// Set up envs array
	// LAB 3: Your code here.
	size_t i;
	for (i = 0; i < NENV; i++) {
		envs[i].env_id = 0;
f0103145:	ba 00 04 00 00       	mov    $0x400,%edx
f010314a:	89 c3                	mov    %eax,%ebx
f010314c:	c7 40 48 00 00 00 00 	movl   $0x0,0x48(%eax)
		envs[i].env_link = env_free_list;
f0103153:	89 48 44             	mov    %ecx,0x44(%eax)
f0103156:	83 c0 60             	add    $0x60,%eax
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
	size_t i;
	for (i = 0; i < NENV; i++) {
f0103159:	83 ea 01             	sub    $0x1,%edx
f010315c:	74 04                	je     f0103162 <env_init+0x2c>
		envs[i].env_id = 0;
		envs[i].env_link = env_free_list;
		env_free_list = &envs[i];
f010315e:	89 d9                	mov    %ebx,%ecx
f0103160:	eb e8                	jmp    f010314a <env_init+0x14>
	}
	env_free_list = envs; // this line of code changing like this ugly looks just fit fuck grade sh,too useless
f0103162:	a1 08 d3 17 f0       	mov    0xf017d308,%eax
f0103167:	a3 0c d3 17 f0       	mov    %eax,0xf017d30c
	// Per-CPU part of the initialization
	env_init_percpu();
f010316c:	e8 9b ff ff ff       	call   f010310c <env_init_percpu>
}
f0103171:	5b                   	pop    %ebx
f0103172:	5d                   	pop    %ebp
f0103173:	c3                   	ret    

f0103174 <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f0103174:	55                   	push   %ebp
f0103175:	89 e5                	mov    %esp,%ebp
f0103177:	56                   	push   %esi
f0103178:	53                   	push   %ebx
f0103179:	83 ec 10             	sub    $0x10,%esp
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
f010317c:	8b 1d 0c d3 17 f0    	mov    0xf017d30c,%ebx
f0103182:	85 db                	test   %ebx,%ebx
f0103184:	0f 84 70 01 00 00    	je     f01032fa <env_alloc+0x186>
{
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f010318a:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0103191:	e8 17 dd ff ff       	call   f0100ead <page_alloc>
f0103196:	85 c0                	test   %eax,%eax
f0103198:	0f 84 63 01 00 00    	je     f0103301 <env_alloc+0x18d>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010319e:	89 c2                	mov    %eax,%edx
f01031a0:	2b 15 cc df 17 f0    	sub    0xf017dfcc,%edx
f01031a6:	c1 fa 03             	sar    $0x3,%edx
f01031a9:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01031ac:	89 d1                	mov    %edx,%ecx
f01031ae:	c1 e9 0c             	shr    $0xc,%ecx
f01031b1:	3b 0d c4 df 17 f0    	cmp    0xf017dfc4,%ecx
f01031b7:	72 20                	jb     f01031d9 <env_alloc+0x65>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01031b9:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01031bd:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f01031c4:	f0 
f01031c5:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01031cc:	00 
f01031cd:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f01031d4:	e8 e5 ce ff ff       	call   f01000be <_panic>
	return (void *)(pa + KERNBASE);
f01031d9:	81 ea 00 00 00 10    	sub    $0x10000000,%edx
f01031df:	89 53 5c             	mov    %edx,0x5c(%ebx)
	//	is an exception -- you need to increment env_pgdir's
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
f01031e2:	ba ec 0e 00 00       	mov    $0xeec,%edx
	for(i=PDX(UTOP);i<1024;i++){
		e->env_pgdir[i] = kern_pgdir[i];
f01031e7:	8b 0d c8 df 17 f0    	mov    0xf017dfc8,%ecx
f01031ed:	8b 34 11             	mov    (%ecx,%edx,1),%esi
f01031f0:	8b 4b 5c             	mov    0x5c(%ebx),%ecx
f01031f3:	89 34 11             	mov    %esi,(%ecx,%edx,1)
f01031f6:	83 c2 04             	add    $0x4,%edx
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
	for(i=PDX(UTOP);i<1024;i++){
f01031f9:	81 fa 00 10 00 00    	cmp    $0x1000,%edx
f01031ff:	75 e6                	jne    f01031e7 <env_alloc+0x73>
		e->env_pgdir[i] = kern_pgdir[i];
	}
	p->pp_ref++;
f0103201:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f0103206:	8b 43 5c             	mov    0x5c(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103209:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010320e:	77 20                	ja     f0103230 <env_alloc+0xbc>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103210:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103214:	c7 44 24 08 d4 57 10 	movl   $0xf01057d4,0x8(%esp)
f010321b:	f0 
f010321c:	c7 44 24 04 c3 00 00 	movl   $0xc3,0x4(%esp)
f0103223:	00 
f0103224:	c7 04 24 a2 60 10 f0 	movl   $0xf01060a2,(%esp)
f010322b:	e8 8e ce ff ff       	call   f01000be <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103230:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f0103236:	83 ca 05             	or     $0x5,%edx
f0103239:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate and set up the page directory for this environment.
	if ((r = env_setup_vm(e)) < 0)
		return r;

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f010323f:	8b 43 48             	mov    0x48(%ebx),%eax
f0103242:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f0103247:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f010324c:	ba 00 10 00 00       	mov    $0x1000,%edx
f0103251:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f0103254:	89 da                	mov    %ebx,%edx
f0103256:	2b 15 08 d3 17 f0    	sub    0xf017d308,%edx
f010325c:	c1 fa 05             	sar    $0x5,%edx
f010325f:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f0103265:	09 d0                	or     %edx,%eax
f0103267:	89 43 48             	mov    %eax,0x48(%ebx)

	// Set the basic status variables.
	e->env_parent_id = parent_id;
f010326a:	8b 45 0c             	mov    0xc(%ebp),%eax
f010326d:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f0103270:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f0103277:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
	e->env_runs = 0;
f010327e:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f0103285:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f010328c:	00 
f010328d:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0103294:	00 
f0103295:	89 1c 24             	mov    %ebx,(%esp)
f0103298:	e8 7c 19 00 00       	call   f0104c19 <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f010329d:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f01032a3:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f01032a9:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f01032af:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f01032b6:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)
	// You will set e->env_tf.tf_eip later.

	// commit the allocation
	env_free_list = e->env_link;
f01032bc:	8b 43 44             	mov    0x44(%ebx),%eax
f01032bf:	a3 0c d3 17 f0       	mov    %eax,0xf017d30c
	*newenv_store = e;
f01032c4:	8b 45 08             	mov    0x8(%ebp),%eax
f01032c7:	89 18                	mov    %ebx,(%eax)

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f01032c9:	8b 53 48             	mov    0x48(%ebx),%edx
f01032cc:	a1 04 d3 17 f0       	mov    0xf017d304,%eax
f01032d1:	85 c0                	test   %eax,%eax
f01032d3:	74 05                	je     f01032da <env_alloc+0x166>
f01032d5:	8b 40 48             	mov    0x48(%eax),%eax
f01032d8:	eb 05                	jmp    f01032df <env_alloc+0x16b>
f01032da:	b8 00 00 00 00       	mov    $0x0,%eax
f01032df:	89 54 24 08          	mov    %edx,0x8(%esp)
f01032e3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01032e7:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
f01032ee:	e8 5a 05 00 00       	call   f010384d <cprintf>
	return 0;
f01032f3:	b8 00 00 00 00       	mov    $0x0,%eax
f01032f8:	eb 0c                	jmp    f0103306 <env_alloc+0x192>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
		return -E_NO_FREE_ENV;
f01032fa:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f01032ff:	eb 05                	jmp    f0103306 <env_alloc+0x192>
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f0103301:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	env_free_list = e->env_link;
	*newenv_store = e;

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}
f0103306:	83 c4 10             	add    $0x10,%esp
f0103309:	5b                   	pop    %ebx
f010330a:	5e                   	pop    %esi
f010330b:	5d                   	pop    %ebp
f010330c:	c3                   	ret    

f010330d <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f010330d:	55                   	push   %ebp
f010330e:	89 e5                	mov    %esp,%ebp
f0103310:	57                   	push   %edi
f0103311:	56                   	push   %esi
f0103312:	53                   	push   %ebx
f0103313:	83 ec 3c             	sub    $0x3c,%esp
	// LAB 3: Your code here.
	struct Env * env;
	if(env_alloc(&env,0)==0){
f0103316:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010331d:	00 
f010331e:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0103321:	89 04 24             	mov    %eax,(%esp)
f0103324:	e8 4b fe ff ff       	call   f0103174 <env_alloc>
f0103329:	85 c0                	test   %eax,%eax
f010332b:	0f 85 dd 01 00 00    	jne    f010350e <env_create+0x201>
		load_icode(env,binary,size);
f0103331:	8b 7d e4             	mov    -0x1c(%ebp),%edi
	//  You must also do something with the program's entry point,
	//  to make sure that the environment starts executing there.
	//  What?  (See env_run() and env_pop_tf() below.)

	// LAB 3: Your code here.
	lcr3(PADDR(e->env_pgdir));
f0103334:	8b 47 5c             	mov    0x5c(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103337:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010333c:	77 20                	ja     f010335e <env_create+0x51>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010333e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103342:	c7 44 24 08 d4 57 10 	movl   $0xf01057d4,0x8(%esp)
f0103349:	f0 
f010334a:	c7 44 24 04 58 01 00 	movl   $0x158,0x4(%esp)
f0103351:	00 
f0103352:	c7 04 24 a2 60 10 f0 	movl   $0xf01060a2,(%esp)
f0103359:	e8 60 cd ff ff       	call   f01000be <_panic>
	return (physaddr_t)kva - KERNBASE;
f010335e:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0103363:	0f 22 d8             	mov    %eax,%cr3
	struct Elf* ELFHDR = (struct Elf *) binary;
	if(ELFHDR->e_magic != ELF_MAGIC)
f0103366:	8b 45 08             	mov    0x8(%ebp),%eax
f0103369:	81 38 7f 45 4c 46    	cmpl   $0x464c457f,(%eax)
f010336f:	74 1c                	je     f010338d <env_create+0x80>
		panic("Invalid ELF format !");
f0103371:	c7 44 24 08 c2 60 10 	movl   $0xf01060c2,0x8(%esp)
f0103378:	f0 
f0103379:	c7 44 24 04 5b 01 00 	movl   $0x15b,0x4(%esp)
f0103380:	00 
f0103381:	c7 04 24 a2 60 10 f0 	movl   $0xf01060a2,(%esp)
f0103388:	e8 31 cd ff ff       	call   f01000be <_panic>

	struct Proghdr *ph,*eph;
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
f010338d:	8b 45 08             	mov    0x8(%ebp),%eax
f0103390:	89 c6                	mov    %eax,%esi
f0103392:	03 70 1c             	add    0x1c(%eax),%esi
	eph = ph + ELFHDR->e_phnum;
f0103395:	0f b7 40 2c          	movzwl 0x2c(%eax),%eax
f0103399:	c1 e0 05             	shl    $0x5,%eax
f010339c:	01 f0                	add    %esi,%eax
f010339e:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	for (; ph < eph; ph++) {
f01033a1:	39 c6                	cmp    %eax,%esi
f01033a3:	0f 83 d2 00 00 00    	jae    f010347b <env_create+0x16e>
		if (ph->p_type == ELF_PROG_LOAD) {
f01033a9:	83 3e 01             	cmpl   $0x1,(%esi)
f01033ac:	0f 85 bd 00 00 00    	jne    f010346f <env_create+0x162>
			if (ph->p_filesz > ph->p_memsz)
f01033b2:	8b 56 14             	mov    0x14(%esi),%edx
f01033b5:	39 56 10             	cmp    %edx,0x10(%esi)
f01033b8:	76 1c                	jbe    f01033d6 <env_create+0xc9>
				panic("invalid ELF proGhdr header!");
f01033ba:	c7 44 24 08 d7 60 10 	movl   $0xf01060d7,0x8(%esp)
f01033c1:	f0 
f01033c2:	c7 44 24 04 63 01 00 	movl   $0x163,0x4(%esp)
f01033c9:	00 
f01033ca:	c7 04 24 a2 60 10 f0 	movl   $0xf01060a2,(%esp)
f01033d1:	e8 e8 cc ff ff       	call   f01000be <_panic>

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
f01033d6:	8b 46 08             	mov    0x8(%esi),%eax
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f01033d9:	89 c3                	mov    %eax,%ebx
f01033db:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f01033e1:	8d 84 02 ff 0f 00 00 	lea    0xfff(%edx,%eax,1),%eax
f01033e8:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01033ed:	39 c3                	cmp    %eax,%ebx
f01033ef:	73 59                	jae    f010344a <env_create+0x13d>
f01033f1:	89 75 d0             	mov    %esi,-0x30(%ebp)
f01033f4:	89 c6                	mov    %eax,%esi
		p = (struct Page*)page_alloc(1);
f01033f6:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01033fd:	e8 ab da ff ff       	call   f0100ead <page_alloc>
		if(p==NULL)
f0103402:	85 c0                	test   %eax,%eax
f0103404:	75 1c                	jne    f0103422 <env_create+0x115>
			panic("Memory out!");
f0103406:	c7 44 24 08 f3 60 10 	movl   $0xf01060f3,0x8(%esp)
f010340d:	f0 
f010340e:	c7 44 24 04 1d 01 00 	movl   $0x11d,0x4(%esp)
f0103415:	00 
f0103416:	c7 04 24 a2 60 10 f0 	movl   $0xf01060a2,(%esp)
f010341d:	e8 9c cc ff ff       	call   f01000be <_panic>
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
f0103422:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0103429:	00 
f010342a:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f010342e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103432:	8b 47 5c             	mov    0x5c(%edi),%eax
f0103435:	89 04 24             	mov    %eax,(%esp)
f0103438:	e8 e2 dc ff ff       	call   f010111f <page_insert>
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f010343d:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0103443:	39 f3                	cmp    %esi,%ebx
f0103445:	72 af                	jb     f01033f6 <env_create+0xe9>
f0103447:	8b 75 d0             	mov    -0x30(%ebp),%esi
			if (ph->p_filesz > ph->p_memsz)
				panic("invalid ELF proGhdr header!");

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
			//copy to va
			char *va = (char *)(ph->p_va);
f010344a:	8b 4e 08             	mov    0x8(%esi),%ecx
			size_t i;
			for (i = 0; i < ph->p_filesz; i++)
f010344d:	83 7e 10 00          	cmpl   $0x0,0x10(%esi)
f0103451:	74 1c                	je     f010346f <env_create+0x162>
f0103453:	b8 00 00 00 00       	mov    $0x0,%eax
f0103458:	8b 5d 08             	mov    0x8(%ebp),%ebx
				va[i] = binary[ph->p_offset + i];
f010345b:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f010345e:	03 56 04             	add    0x4(%esi),%edx
f0103461:	0f b6 12             	movzbl (%edx),%edx
f0103464:	88 14 08             	mov    %dl,(%eax,%ecx,1)

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
			//copy to va
			char *va = (char *)(ph->p_va);
			size_t i;
			for (i = 0; i < ph->p_filesz; i++)
f0103467:	83 c0 01             	add    $0x1,%eax
f010346a:	3b 46 10             	cmp    0x10(%esi),%eax
f010346d:	72 ec                	jb     f010345b <env_create+0x14e>
		panic("Invalid ELF format !");

	struct Proghdr *ph,*eph;
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
	eph = ph + ELFHDR->e_phnum;
	for (; ph < eph; ph++) {
f010346f:	83 c6 20             	add    $0x20,%esi
f0103472:	39 75 d4             	cmp    %esi,-0x2c(%ebp)
f0103475:	0f 87 2e ff ff ff    	ja     f01033a9 <env_create+0x9c>
			for (i = 0; i < ph->p_filesz; i++)
				va[i] = binary[ph->p_offset + i];
		}
	}
	//set programe entry
	e->env_tf.tf_eip = ELFHDR->e_entry;
f010347b:	8b 45 08             	mov    0x8(%ebp),%eax
f010347e:	8b 40 18             	mov    0x18(%eax),%eax
f0103481:	89 47 30             	mov    %eax,0x30(%edi)
	// Now map one page for the program's initial stack
	// at virtual address USTACKTOP - PGSIZE.

	// LAB 3: Your code here.
	struct Page* stackPage = (struct Page*)page_alloc(1);
f0103484:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f010348b:	e8 1d da ff ff       	call   f0100ead <page_alloc>
	if(stackPage == NULL)
f0103490:	85 c0                	test   %eax,%eax
f0103492:	75 1c                	jne    f01034b0 <env_create+0x1a3>
		panic("Out of memory!");
f0103494:	c7 44 24 08 ff 60 10 	movl   $0xf01060ff,0x8(%esp)
f010349b:	f0 
f010349c:	c7 44 24 04 75 01 00 	movl   $0x175,0x4(%esp)
f01034a3:	00 
f01034a4:	c7 04 24 a2 60 10 f0 	movl   $0xf01060a2,(%esp)
f01034ab:	e8 0e cc ff ff       	call   f01000be <_panic>
	page_insert(e->env_pgdir,stackPage,(void*)USTACKTOP - PGSIZE,PTE_U|PTE_W);
f01034b0:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01034b7:	00 
f01034b8:	c7 44 24 08 00 d0 bf 	movl   $0xeebfd000,0x8(%esp)
f01034bf:	ee 
f01034c0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01034c4:	8b 47 5c             	mov    0x5c(%edi),%eax
f01034c7:	89 04 24             	mov    %eax,(%esp)
f01034ca:	e8 50 dc ff ff       	call   f010111f <page_insert>
	lcr3(PADDR(kern_pgdir));
f01034cf:	a1 c8 df 17 f0       	mov    0xf017dfc8,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01034d4:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01034d9:	77 20                	ja     f01034fb <env_create+0x1ee>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01034db:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01034df:	c7 44 24 08 d4 57 10 	movl   $0xf01057d4,0x8(%esp)
f01034e6:	f0 
f01034e7:	c7 44 24 04 77 01 00 	movl   $0x177,0x4(%esp)
f01034ee:	00 
f01034ef:	c7 04 24 a2 60 10 f0 	movl   $0xf01060a2,(%esp)
f01034f6:	e8 c3 cb ff ff       	call   f01000be <_panic>
	return (physaddr_t)kva - KERNBASE;
f01034fb:	05 00 00 00 10       	add    $0x10000000,%eax
f0103500:	0f 22 d8             	mov    %eax,%cr3
{
	// LAB 3: Your code here.
	struct Env * env;
	if(env_alloc(&env,0)==0){
		load_icode(env,binary,size);
		env->env_type = type;
f0103503:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103506:	8b 55 10             	mov    0x10(%ebp),%edx
f0103509:	89 50 50             	mov    %edx,0x50(%eax)
f010350c:	eb 1c                	jmp    f010352a <env_create+0x21d>
	}else{
		panic("create env fails !");
f010350e:	c7 44 24 08 0e 61 10 	movl   $0xf010610e,0x8(%esp)
f0103515:	f0 
f0103516:	c7 44 24 04 8a 01 00 	movl   $0x18a,0x4(%esp)
f010351d:	00 
f010351e:	c7 04 24 a2 60 10 f0 	movl   $0xf01060a2,(%esp)
f0103525:	e8 94 cb ff ff       	call   f01000be <_panic>
	}
}
f010352a:	83 c4 3c             	add    $0x3c,%esp
f010352d:	5b                   	pop    %ebx
f010352e:	5e                   	pop    %esi
f010352f:	5f                   	pop    %edi
f0103530:	5d                   	pop    %ebp
f0103531:	c3                   	ret    

f0103532 <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0103532:	55                   	push   %ebp
f0103533:	89 e5                	mov    %esp,%ebp
f0103535:	57                   	push   %edi
f0103536:	56                   	push   %esi
f0103537:	53                   	push   %ebx
f0103538:	83 ec 2c             	sub    $0x2c,%esp
f010353b:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f010353e:	a1 04 d3 17 f0       	mov    0xf017d304,%eax
f0103543:	39 c7                	cmp    %eax,%edi
f0103545:	75 37                	jne    f010357e <env_free+0x4c>
		lcr3(PADDR(kern_pgdir));
f0103547:	8b 15 c8 df 17 f0    	mov    0xf017dfc8,%edx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010354d:	81 fa ff ff ff ef    	cmp    $0xefffffff,%edx
f0103553:	77 20                	ja     f0103575 <env_free+0x43>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103555:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0103559:	c7 44 24 08 d4 57 10 	movl   $0xf01057d4,0x8(%esp)
f0103560:	f0 
f0103561:	c7 44 24 04 9c 01 00 	movl   $0x19c,0x4(%esp)
f0103568:	00 
f0103569:	c7 04 24 a2 60 10 f0 	movl   $0xf01060a2,(%esp)
f0103570:	e8 49 cb ff ff       	call   f01000be <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103575:	81 c2 00 00 00 10    	add    $0x10000000,%edx
f010357b:	0f 22 da             	mov    %edx,%cr3

	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f010357e:	8b 57 48             	mov    0x48(%edi),%edx
f0103581:	85 c0                	test   %eax,%eax
f0103583:	74 05                	je     f010358a <env_free+0x58>
f0103585:	8b 40 48             	mov    0x48(%eax),%eax
f0103588:	eb 05                	jmp    f010358f <env_free+0x5d>
f010358a:	b8 00 00 00 00       	mov    $0x0,%eax
f010358f:	89 54 24 08          	mov    %edx,0x8(%esp)
f0103593:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103597:	c7 04 24 21 61 10 f0 	movl   $0xf0106121,(%esp)
f010359e:	e8 aa 02 00 00       	call   f010384d <cprintf>

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f01035a3:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f01035aa:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f01035ad:	89 c8                	mov    %ecx,%eax
f01035af:	c1 e0 02             	shl    $0x2,%eax
f01035b2:	89 45 dc             	mov    %eax,-0x24(%ebp)

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f01035b5:	8b 47 5c             	mov    0x5c(%edi),%eax
f01035b8:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f01035bb:	f7 c6 01 00 00 00    	test   $0x1,%esi
f01035c1:	0f 84 b7 00 00 00    	je     f010367e <env_free+0x14c>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f01035c7:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01035cd:	89 f0                	mov    %esi,%eax
f01035cf:	c1 e8 0c             	shr    $0xc,%eax
f01035d2:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01035d5:	3b 05 c4 df 17 f0    	cmp    0xf017dfc4,%eax
f01035db:	72 20                	jb     f01035fd <env_free+0xcb>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01035dd:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01035e1:	c7 44 24 08 90 56 10 	movl   $0xf0105690,0x8(%esp)
f01035e8:	f0 
f01035e9:	c7 44 24 04 ab 01 00 	movl   $0x1ab,0x4(%esp)
f01035f0:	00 
f01035f1:	c7 04 24 a2 60 10 f0 	movl   $0xf01060a2,(%esp)
f01035f8:	e8 c1 ca ff ff       	call   f01000be <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f01035fd:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103600:	c1 e0 16             	shl    $0x16,%eax
f0103603:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103606:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f010360b:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f0103612:	01 
f0103613:	74 17                	je     f010362c <env_free+0xfa>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103615:	89 d8                	mov    %ebx,%eax
f0103617:	c1 e0 0c             	shl    $0xc,%eax
f010361a:	0b 45 e4             	or     -0x1c(%ebp),%eax
f010361d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103621:	8b 47 5c             	mov    0x5c(%edi),%eax
f0103624:	89 04 24             	mov    %eax,(%esp)
f0103627:	e8 b5 da ff ff       	call   f01010e1 <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f010362c:	83 c3 01             	add    $0x1,%ebx
f010362f:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f0103635:	75 d4                	jne    f010360b <env_free+0xd9>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f0103637:	8b 47 5c             	mov    0x5c(%edi),%eax
f010363a:	8b 55 dc             	mov    -0x24(%ebp),%edx
f010363d:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103644:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103647:	3b 05 c4 df 17 f0    	cmp    0xf017dfc4,%eax
f010364d:	72 1c                	jb     f010366b <env_free+0x139>
		panic("pa2page called with invalid pa");
f010364f:	c7 44 24 08 78 57 10 	movl   $0xf0105778,0x8(%esp)
f0103656:	f0 
f0103657:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010365e:	00 
f010365f:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f0103666:	e8 53 ca ff ff       	call   f01000be <_panic>
	return &pages[PGNUM(pa)];
f010366b:	a1 cc df 17 f0       	mov    0xf017dfcc,%eax
f0103670:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103673:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0103676:	89 04 24             	mov    %eax,(%esp)
f0103679:	e8 c9 d8 ff ff       	call   f0100f47 <page_decref>
	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f010367e:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f0103682:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f0103689:	0f 85 1b ff ff ff    	jne    f01035aa <env_free+0x78>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f010368f:	8b 47 5c             	mov    0x5c(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103692:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103697:	77 20                	ja     f01036b9 <env_free+0x187>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103699:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010369d:	c7 44 24 08 d4 57 10 	movl   $0xf01057d4,0x8(%esp)
f01036a4:	f0 
f01036a5:	c7 44 24 04 b9 01 00 	movl   $0x1b9,0x4(%esp)
f01036ac:	00 
f01036ad:	c7 04 24 a2 60 10 f0 	movl   $0xf01060a2,(%esp)
f01036b4:	e8 05 ca ff ff       	call   f01000be <_panic>
	e->env_pgdir = 0;
f01036b9:	c7 47 5c 00 00 00 00 	movl   $0x0,0x5c(%edi)
	return (physaddr_t)kva - KERNBASE;
f01036c0:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01036c5:	c1 e8 0c             	shr    $0xc,%eax
f01036c8:	3b 05 c4 df 17 f0    	cmp    0xf017dfc4,%eax
f01036ce:	72 1c                	jb     f01036ec <env_free+0x1ba>
		panic("pa2page called with invalid pa");
f01036d0:	c7 44 24 08 78 57 10 	movl   $0xf0105778,0x8(%esp)
f01036d7:	f0 
f01036d8:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01036df:	00 
f01036e0:	c7 04 24 b5 5d 10 f0 	movl   $0xf0105db5,(%esp)
f01036e7:	e8 d2 c9 ff ff       	call   f01000be <_panic>
	return &pages[PGNUM(pa)];
f01036ec:	8b 15 cc df 17 f0    	mov    0xf017dfcc,%edx
f01036f2:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f01036f5:	89 04 24             	mov    %eax,(%esp)
f01036f8:	e8 4a d8 ff ff       	call   f0100f47 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f01036fd:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f0103704:	a1 0c d3 17 f0       	mov    0xf017d30c,%eax
f0103709:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f010370c:	89 3d 0c d3 17 f0    	mov    %edi,0xf017d30c
}
f0103712:	83 c4 2c             	add    $0x2c,%esp
f0103715:	5b                   	pop    %ebx
f0103716:	5e                   	pop    %esi
f0103717:	5f                   	pop    %edi
f0103718:	5d                   	pop    %ebp
f0103719:	c3                   	ret    

f010371a <env_destroy>:
//
// Frees environment e.
//
void
env_destroy(struct Env *e)
{
f010371a:	55                   	push   %ebp
f010371b:	89 e5                	mov    %esp,%ebp
f010371d:	83 ec 18             	sub    $0x18,%esp
	env_free(e);
f0103720:	8b 45 08             	mov    0x8(%ebp),%eax
f0103723:	89 04 24             	mov    %eax,(%esp)
f0103726:	e8 07 fe ff ff       	call   f0103532 <env_free>

	cprintf("Destroyed the only environment - nothing more to do!\n");
f010372b:	c7 04 24 6c 60 10 f0 	movl   $0xf010606c,(%esp)
f0103732:	e8 16 01 00 00       	call   f010384d <cprintf>
	while (1)
		monitor(NULL);
f0103737:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010373e:	e8 ef d0 ff ff       	call   f0100832 <monitor>
f0103743:	eb f2                	jmp    f0103737 <env_destroy+0x1d>

f0103745 <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f0103745:	55                   	push   %ebp
f0103746:	89 e5                	mov    %esp,%ebp
f0103748:	83 ec 18             	sub    $0x18,%esp
	__asm __volatile("movl %0,%%esp\n"
f010374b:	8b 65 08             	mov    0x8(%ebp),%esp
f010374e:	61                   	popa   
f010374f:	07                   	pop    %es
f0103750:	1f                   	pop    %ds
f0103751:	83 c4 08             	add    $0x8,%esp
f0103754:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f0103755:	c7 44 24 08 37 61 10 	movl   $0xf0106137,0x8(%esp)
f010375c:	f0 
f010375d:	c7 44 24 04 e1 01 00 	movl   $0x1e1,0x4(%esp)
f0103764:	00 
f0103765:	c7 04 24 a2 60 10 f0 	movl   $0xf01060a2,(%esp)
f010376c:	e8 4d c9 ff ff       	call   f01000be <_panic>

f0103771 <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0103771:	55                   	push   %ebp
f0103772:	89 e5                	mov    %esp,%ebp
f0103774:	83 ec 18             	sub    $0x18,%esp
f0103777:	8b 45 08             	mov    0x8(%ebp),%eax

	// Hint: This function loads the new environment's state from
	//	e->env_tf.  Go back through the code you wrote above
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.
	if(curenv!=NULL&& curenv->env_status==ENV_RUNNING)
f010377a:	8b 15 04 d3 17 f0    	mov    0xf017d304,%edx
f0103780:	85 d2                	test   %edx,%edx
f0103782:	74 0d                	je     f0103791 <env_run+0x20>
f0103784:	83 7a 54 02          	cmpl   $0x2,0x54(%edx)
f0103788:	75 07                	jne    f0103791 <env_run+0x20>
		curenv->env_status = ENV_RUNNABLE;
f010378a:	c7 42 54 01 00 00 00 	movl   $0x1,0x54(%edx)

	curenv = e;
f0103791:	a3 04 d3 17 f0       	mov    %eax,0xf017d304
	int zero = 0;
	e->env_status = ENV_RUNNING;
f0103796:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)
	e->env_runs++;
f010379d:	83 40 58 01          	addl   $0x1,0x58(%eax)
	lcr3(PADDR(e->env_pgdir));
f01037a1:	8b 50 5c             	mov    0x5c(%eax),%edx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01037a4:	81 fa ff ff ff ef    	cmp    $0xefffffff,%edx
f01037aa:	77 20                	ja     f01037cc <env_run+0x5b>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01037ac:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01037b0:	c7 44 24 08 d4 57 10 	movl   $0xf01057d4,0x8(%esp)
f01037b7:	f0 
f01037b8:	c7 44 24 04 04 02 00 	movl   $0x204,0x4(%esp)
f01037bf:	00 
f01037c0:	c7 04 24 a2 60 10 f0 	movl   $0xf01060a2,(%esp)
f01037c7:	e8 f2 c8 ff ff       	call   f01000be <_panic>
	return (physaddr_t)kva - KERNBASE;
f01037cc:	81 c2 00 00 00 10    	add    $0x10000000,%edx
f01037d2:	0f 22 da             	mov    %edx,%cr3
	env_pop_tf(&e->env_tf);
f01037d5:	89 04 24             	mov    %eax,(%esp)
f01037d8:	e8 68 ff ff ff       	call   f0103745 <env_pop_tf>

f01037dd <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f01037dd:	55                   	push   %ebp
f01037de:	89 e5                	mov    %esp,%ebp
f01037e0:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01037e4:	ba 70 00 00 00       	mov    $0x70,%edx
f01037e9:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01037ea:	b2 71                	mov    $0x71,%dl
f01037ec:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f01037ed:	0f b6 c0             	movzbl %al,%eax
}
f01037f0:	5d                   	pop    %ebp
f01037f1:	c3                   	ret    

f01037f2 <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f01037f2:	55                   	push   %ebp
f01037f3:	89 e5                	mov    %esp,%ebp
f01037f5:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01037f9:	ba 70 00 00 00       	mov    $0x70,%edx
f01037fe:	ee                   	out    %al,(%dx)
f01037ff:	b2 71                	mov    $0x71,%dl
f0103801:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103804:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0103805:	5d                   	pop    %ebp
f0103806:	c3                   	ret    

f0103807 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0103807:	55                   	push   %ebp
f0103808:	89 e5                	mov    %esp,%ebp
f010380a:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f010380d:	8b 45 08             	mov    0x8(%ebp),%eax
f0103810:	89 04 24             	mov    %eax,(%esp)
f0103813:	e8 1c ce ff ff       	call   f0100634 <cputchar>
	*cnt++;
}
f0103818:	c9                   	leave  
f0103819:	c3                   	ret    

f010381a <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f010381a:	55                   	push   %ebp
f010381b:	89 e5                	mov    %esp,%ebp
f010381d:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0103820:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0103827:	8b 45 0c             	mov    0xc(%ebp),%eax
f010382a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010382e:	8b 45 08             	mov    0x8(%ebp),%eax
f0103831:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103835:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0103838:	89 44 24 04          	mov    %eax,0x4(%esp)
f010383c:	c7 04 24 07 38 10 f0 	movl   $0xf0103807,(%esp)
f0103843:	e8 8c 0c 00 00       	call   f01044d4 <vprintfmt>
	return cnt;
}
f0103848:	8b 45 f4             	mov    -0xc(%ebp),%eax
f010384b:	c9                   	leave  
f010384c:	c3                   	ret    

f010384d <cprintf>:

int
cprintf(const char *fmt, ...)
{
f010384d:	55                   	push   %ebp
f010384e:	89 e5                	mov    %esp,%ebp
f0103850:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0103853:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0103856:	89 44 24 04          	mov    %eax,0x4(%esp)
f010385a:	8b 45 08             	mov    0x8(%ebp),%eax
f010385d:	89 04 24             	mov    %eax,(%esp)
f0103860:	e8 b5 ff ff ff       	call   f010381a <vcprintf>
	va_end(ap);

	return cnt;
}
f0103865:	c9                   	leave  
f0103866:	c3                   	ret    

f0103867 <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f0103867:	55                   	push   %ebp
f0103868:	89 e5                	mov    %esp,%ebp
	// Setup a TSS so that we get the right stack
	// when we trap to the kernel.
	ts.ts_esp0 = KSTACKTOP;
f010386a:	c7 05 44 db 17 f0 00 	movl   $0xefc00000,0xf017db44
f0103871:	00 c0 ef 
	ts.ts_ss0 = GD_KD;
f0103874:	66 c7 05 48 db 17 f0 	movw   $0x10,0xf017db48
f010387b:	10 00 

	// Initialize the TSS slot of the gdt.
	gdt[GD_TSS0 >> 3] = SEG16(STS_T32A, (uint32_t) (&ts),
f010387d:	66 c7 05 48 b3 11 f0 	movw   $0x68,0xf011b348
f0103884:	68 00 
f0103886:	b8 40 db 17 f0       	mov    $0xf017db40,%eax
f010388b:	66 a3 4a b3 11 f0    	mov    %ax,0xf011b34a
f0103891:	89 c2                	mov    %eax,%edx
f0103893:	c1 ea 10             	shr    $0x10,%edx
f0103896:	88 15 4c b3 11 f0    	mov    %dl,0xf011b34c
f010389c:	c6 05 4e b3 11 f0 40 	movb   $0x40,0xf011b34e
f01038a3:	c1 e8 18             	shr    $0x18,%eax
f01038a6:	a2 4f b3 11 f0       	mov    %al,0xf011b34f
					sizeof(struct Taskstate), 0);
	gdt[GD_TSS0 >> 3].sd_s = 0;
f01038ab:	c6 05 4d b3 11 f0 89 	movb   $0x89,0xf011b34d
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f01038b2:	b8 28 00 00 00       	mov    $0x28,%eax
f01038b7:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f01038ba:	b8 50 b3 11 f0       	mov    $0xf011b350,%eax
f01038bf:	0f 01 18             	lidtl  (%eax)
	// bottom three bits are special; we leave them 0)
	ltr(GD_TSS0);

	// Load the IDT
	lidt(&idt_pd);
}
f01038c2:	5d                   	pop    %ebp
f01038c3:	c3                   	ret    

f01038c4 <trap_init>:
}


void
trap_init(void)
{
f01038c4:	55                   	push   %ebp
f01038c5:	89 e5                	mov    %esp,%ebp
	extern struct Segdesc gdt[];
	SETGATE(idt[0],1,GD_KD,Divide_error,0);
f01038c7:	b8 80 3f 10 f0       	mov    $0xf0103f80,%eax
f01038cc:	66 a3 20 d3 17 f0    	mov    %ax,0xf017d320
f01038d2:	66 c7 05 22 d3 17 f0 	movw   $0x10,0xf017d322
f01038d9:	10 00 
f01038db:	c6 05 24 d3 17 f0 00 	movb   $0x0,0xf017d324
f01038e2:	c6 05 25 d3 17 f0 8f 	movb   $0x8f,0xf017d325
f01038e9:	c1 e8 10             	shr    $0x10,%eax
f01038ec:	66 a3 26 d3 17 f0    	mov    %ax,0xf017d326
	SETGATE(idt[1],0,GD_KD,Debug,3);
f01038f2:	b8 86 3f 10 f0       	mov    $0xf0103f86,%eax
f01038f7:	66 a3 28 d3 17 f0    	mov    %ax,0xf017d328
f01038fd:	66 c7 05 2a d3 17 f0 	movw   $0x10,0xf017d32a
f0103904:	10 00 
f0103906:	c6 05 2c d3 17 f0 00 	movb   $0x0,0xf017d32c
f010390d:	c6 05 2d d3 17 f0 ee 	movb   $0xee,0xf017d32d
f0103914:	c1 e8 10             	shr    $0x10,%eax
f0103917:	66 a3 2e d3 17 f0    	mov    %ax,0xf017d32e
	SETGATE(idt[2],1,GD_KD,Non_MaskableInterrupt,0);
f010391d:	b8 8c 3f 10 f0       	mov    $0xf0103f8c,%eax
f0103922:	66 a3 30 d3 17 f0    	mov    %ax,0xf017d330
f0103928:	66 c7 05 32 d3 17 f0 	movw   $0x10,0xf017d332
f010392f:	10 00 
f0103931:	c6 05 34 d3 17 f0 00 	movb   $0x0,0xf017d334
f0103938:	c6 05 35 d3 17 f0 8f 	movb   $0x8f,0xf017d335
f010393f:	c1 e8 10             	shr    $0x10,%eax
f0103942:	66 a3 36 d3 17 f0    	mov    %ax,0xf017d336
	SETGATE(idt[3],0,GD_KD,Breakpoint,0);
f0103948:	b8 92 3f 10 f0       	mov    $0xf0103f92,%eax
f010394d:	66 a3 38 d3 17 f0    	mov    %ax,0xf017d338
f0103953:	66 c7 05 3a d3 17 f0 	movw   $0x10,0xf017d33a
f010395a:	10 00 
f010395c:	c6 05 3c d3 17 f0 00 	movb   $0x0,0xf017d33c
f0103963:	c6 05 3d d3 17 f0 8e 	movb   $0x8e,0xf017d33d
f010396a:	c1 e8 10             	shr    $0x10,%eax
f010396d:	66 a3 3e d3 17 f0    	mov    %ax,0xf017d33e
	SETGATE(idt[4],0,GD_KD,Overflow,0);
f0103973:	b8 98 3f 10 f0       	mov    $0xf0103f98,%eax
f0103978:	66 a3 40 d3 17 f0    	mov    %ax,0xf017d340
f010397e:	66 c7 05 42 d3 17 f0 	movw   $0x10,0xf017d342
f0103985:	10 00 
f0103987:	c6 05 44 d3 17 f0 00 	movb   $0x0,0xf017d344
f010398e:	c6 05 45 d3 17 f0 8e 	movb   $0x8e,0xf017d345
f0103995:	c1 e8 10             	shr    $0x10,%eax
f0103998:	66 a3 46 d3 17 f0    	mov    %ax,0xf017d346
	SETGATE(idt[5],1,GD_KD,BOUND_Range_Exceeded,0);
f010399e:	b8 9e 3f 10 f0       	mov    $0xf0103f9e,%eax
f01039a3:	66 a3 48 d3 17 f0    	mov    %ax,0xf017d348
f01039a9:	66 c7 05 4a d3 17 f0 	movw   $0x10,0xf017d34a
f01039b0:	10 00 
f01039b2:	c6 05 4c d3 17 f0 00 	movb   $0x0,0xf017d34c
f01039b9:	c6 05 4d d3 17 f0 8f 	movb   $0x8f,0xf017d34d
f01039c0:	c1 e8 10             	shr    $0x10,%eax
f01039c3:	66 a3 4e d3 17 f0    	mov    %ax,0xf017d34e
	SETGATE(idt[6],0,GD_KD,Invalid_Opcode,0);
f01039c9:	b8 a4 3f 10 f0       	mov    $0xf0103fa4,%eax
f01039ce:	66 a3 50 d3 17 f0    	mov    %ax,0xf017d350
f01039d4:	66 c7 05 52 d3 17 f0 	movw   $0x10,0xf017d352
f01039db:	10 00 
f01039dd:	c6 05 54 d3 17 f0 00 	movb   $0x0,0xf017d354
f01039e4:	c6 05 55 d3 17 f0 8e 	movb   $0x8e,0xf017d355
f01039eb:	c1 e8 10             	shr    $0x10,%eax
f01039ee:	66 a3 56 d3 17 f0    	mov    %ax,0xf017d356
	SETGATE(idt[7],1,GD_KD,Device_Not_Available,0);
f01039f4:	b8 aa 3f 10 f0       	mov    $0xf0103faa,%eax
f01039f9:	66 a3 58 d3 17 f0    	mov    %ax,0xf017d358
f01039ff:	66 c7 05 5a d3 17 f0 	movw   $0x10,0xf017d35a
f0103a06:	10 00 
f0103a08:	c6 05 5c d3 17 f0 00 	movb   $0x0,0xf017d35c
f0103a0f:	c6 05 5d d3 17 f0 8f 	movb   $0x8f,0xf017d35d
f0103a16:	c1 e8 10             	shr    $0x10,%eax
f0103a19:	66 a3 5e d3 17 f0    	mov    %ax,0xf017d35e
	SETGATE(idt[8],1,GD_KD,Double_Fault,0);
f0103a1f:	b8 b0 3f 10 f0       	mov    $0xf0103fb0,%eax
f0103a24:	66 a3 60 d3 17 f0    	mov    %ax,0xf017d360
f0103a2a:	66 c7 05 62 d3 17 f0 	movw   $0x10,0xf017d362
f0103a31:	10 00 
f0103a33:	c6 05 64 d3 17 f0 00 	movb   $0x0,0xf017d364
f0103a3a:	c6 05 65 d3 17 f0 8f 	movb   $0x8f,0xf017d365
f0103a41:	c1 e8 10             	shr    $0x10,%eax
f0103a44:	66 a3 66 d3 17 f0    	mov    %ax,0xf017d366
	SETGATE(idt[10],1,GD_KD,Invalid_TSS,0);
f0103a4a:	b8 b4 3f 10 f0       	mov    $0xf0103fb4,%eax
f0103a4f:	66 a3 70 d3 17 f0    	mov    %ax,0xf017d370
f0103a55:	66 c7 05 72 d3 17 f0 	movw   $0x10,0xf017d372
f0103a5c:	10 00 
f0103a5e:	c6 05 74 d3 17 f0 00 	movb   $0x0,0xf017d374
f0103a65:	c6 05 75 d3 17 f0 8f 	movb   $0x8f,0xf017d375
f0103a6c:	c1 e8 10             	shr    $0x10,%eax
f0103a6f:	66 a3 76 d3 17 f0    	mov    %ax,0xf017d376
	SETGATE(idt[11],1,GD_KD,Segment_Not_Present,0);
f0103a75:	b8 b8 3f 10 f0       	mov    $0xf0103fb8,%eax
f0103a7a:	66 a3 78 d3 17 f0    	mov    %ax,0xf017d378
f0103a80:	66 c7 05 7a d3 17 f0 	movw   $0x10,0xf017d37a
f0103a87:	10 00 
f0103a89:	c6 05 7c d3 17 f0 00 	movb   $0x0,0xf017d37c
f0103a90:	c6 05 7d d3 17 f0 8f 	movb   $0x8f,0xf017d37d
f0103a97:	c1 e8 10             	shr    $0x10,%eax
f0103a9a:	66 a3 7e d3 17 f0    	mov    %ax,0xf017d37e
	SETGATE(idt[12],1,GD_KD,Stack_Fault,0);
f0103aa0:	b8 bc 3f 10 f0       	mov    $0xf0103fbc,%eax
f0103aa5:	66 a3 80 d3 17 f0    	mov    %ax,0xf017d380
f0103aab:	66 c7 05 82 d3 17 f0 	movw   $0x10,0xf017d382
f0103ab2:	10 00 
f0103ab4:	c6 05 84 d3 17 f0 00 	movb   $0x0,0xf017d384
f0103abb:	c6 05 85 d3 17 f0 8f 	movb   $0x8f,0xf017d385
f0103ac2:	c1 e8 10             	shr    $0x10,%eax
f0103ac5:	66 a3 86 d3 17 f0    	mov    %ax,0xf017d386
	SETGATE(idt[13],1,GD_KD,General_Protection,0);
f0103acb:	b8 c0 3f 10 f0       	mov    $0xf0103fc0,%eax
f0103ad0:	66 a3 88 d3 17 f0    	mov    %ax,0xf017d388
f0103ad6:	66 c7 05 8a d3 17 f0 	movw   $0x10,0xf017d38a
f0103add:	10 00 
f0103adf:	c6 05 8c d3 17 f0 00 	movb   $0x0,0xf017d38c
f0103ae6:	c6 05 8d d3 17 f0 8f 	movb   $0x8f,0xf017d38d
f0103aed:	c1 e8 10             	shr    $0x10,%eax
f0103af0:	66 a3 8e d3 17 f0    	mov    %ax,0xf017d38e
	SETGATE(idt[14],1,GD_KD,Page_Fault,0);
f0103af6:	b8 c4 3f 10 f0       	mov    $0xf0103fc4,%eax
f0103afb:	66 a3 90 d3 17 f0    	mov    %ax,0xf017d390
f0103b01:	66 c7 05 92 d3 17 f0 	movw   $0x10,0xf017d392
f0103b08:	10 00 
f0103b0a:	c6 05 94 d3 17 f0 00 	movb   $0x0,0xf017d394
f0103b11:	c6 05 95 d3 17 f0 8f 	movb   $0x8f,0xf017d395
f0103b18:	c1 e8 10             	shr    $0x10,%eax
f0103b1b:	66 a3 96 d3 17 f0    	mov    %ax,0xf017d396
	SETGATE(idt[16],1,GD_KD,FPU_Floating_Point_Error,0);
f0103b21:	b8 c8 3f 10 f0       	mov    $0xf0103fc8,%eax
f0103b26:	66 a3 a0 d3 17 f0    	mov    %ax,0xf017d3a0
f0103b2c:	66 c7 05 a2 d3 17 f0 	movw   $0x10,0xf017d3a2
f0103b33:	10 00 
f0103b35:	c6 05 a4 d3 17 f0 00 	movb   $0x0,0xf017d3a4
f0103b3c:	c6 05 a5 d3 17 f0 8f 	movb   $0x8f,0xf017d3a5
f0103b43:	c1 e8 10             	shr    $0x10,%eax
f0103b46:	66 a3 a6 d3 17 f0    	mov    %ax,0xf017d3a6
	SETGATE(idt[17],1,GD_KD,Alignment_Check,0);
f0103b4c:	b8 ce 3f 10 f0       	mov    $0xf0103fce,%eax
f0103b51:	66 a3 a8 d3 17 f0    	mov    %ax,0xf017d3a8
f0103b57:	66 c7 05 aa d3 17 f0 	movw   $0x10,0xf017d3aa
f0103b5e:	10 00 
f0103b60:	c6 05 ac d3 17 f0 00 	movb   $0x0,0xf017d3ac
f0103b67:	c6 05 ad d3 17 f0 8f 	movb   $0x8f,0xf017d3ad
f0103b6e:	c1 e8 10             	shr    $0x10,%eax
f0103b71:	66 a3 ae d3 17 f0    	mov    %ax,0xf017d3ae
	SETGATE(idt[18],1,GD_KD,Machine_Check,0);
f0103b77:	b8 d2 3f 10 f0       	mov    $0xf0103fd2,%eax
f0103b7c:	66 a3 b0 d3 17 f0    	mov    %ax,0xf017d3b0
f0103b82:	66 c7 05 b2 d3 17 f0 	movw   $0x10,0xf017d3b2
f0103b89:	10 00 
f0103b8b:	c6 05 b4 d3 17 f0 00 	movb   $0x0,0xf017d3b4
f0103b92:	c6 05 b5 d3 17 f0 8f 	movb   $0x8f,0xf017d3b5
f0103b99:	c1 e8 10             	shr    $0x10,%eax
f0103b9c:	66 a3 b6 d3 17 f0    	mov    %ax,0xf017d3b6
	SETGATE(idt[19],1,GD_KD,SIMD_Floating_Point_Exception,0);
f0103ba2:	b8 d8 3f 10 f0       	mov    $0xf0103fd8,%eax
f0103ba7:	66 a3 b8 d3 17 f0    	mov    %ax,0xf017d3b8
f0103bad:	66 c7 05 ba d3 17 f0 	movw   $0x10,0xf017d3ba
f0103bb4:	10 00 
f0103bb6:	c6 05 bc d3 17 f0 00 	movb   $0x0,0xf017d3bc
f0103bbd:	c6 05 bd d3 17 f0 8f 	movb   $0x8f,0xf017d3bd
f0103bc4:	c1 e8 10             	shr    $0x10,%eax
f0103bc7:	66 a3 be d3 17 f0    	mov    %ax,0xf017d3be
	SETGATE(idt[48],0,GD_KD,systemcall_handler,3);
f0103bcd:	b8 de 3f 10 f0       	mov    $0xf0103fde,%eax
f0103bd2:	66 a3 a0 d4 17 f0    	mov    %ax,0xf017d4a0
f0103bd8:	66 c7 05 a2 d4 17 f0 	movw   $0x10,0xf017d4a2
f0103bdf:	10 00 
f0103be1:	c6 05 a4 d4 17 f0 00 	movb   $0x0,0xf017d4a4
f0103be8:	c6 05 a5 d4 17 f0 ee 	movb   $0xee,0xf017d4a5
f0103bef:	c1 e8 10             	shr    $0x10,%eax
f0103bf2:	66 a3 a6 d4 17 f0    	mov    %ax,0xf017d4a6
	
	// LAB 3: Your code here.

	// Per-CPU setup 
	trap_init_percpu();
f0103bf8:	e8 6a fc ff ff       	call   f0103867 <trap_init_percpu>
}
f0103bfd:	5d                   	pop    %ebp
f0103bfe:	c3                   	ret    

f0103bff <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f0103bff:	55                   	push   %ebp
f0103c00:	89 e5                	mov    %esp,%ebp
f0103c02:	53                   	push   %ebx
f0103c03:	83 ec 14             	sub    $0x14,%esp
f0103c06:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f0103c09:	8b 03                	mov    (%ebx),%eax
f0103c0b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c0f:	c7 04 24 43 61 10 f0 	movl   $0xf0106143,(%esp)
f0103c16:	e8 32 fc ff ff       	call   f010384d <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f0103c1b:	8b 43 04             	mov    0x4(%ebx),%eax
f0103c1e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c22:	c7 04 24 52 61 10 f0 	movl   $0xf0106152,(%esp)
f0103c29:	e8 1f fc ff ff       	call   f010384d <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f0103c2e:	8b 43 08             	mov    0x8(%ebx),%eax
f0103c31:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c35:	c7 04 24 61 61 10 f0 	movl   $0xf0106161,(%esp)
f0103c3c:	e8 0c fc ff ff       	call   f010384d <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f0103c41:	8b 43 0c             	mov    0xc(%ebx),%eax
f0103c44:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c48:	c7 04 24 70 61 10 f0 	movl   $0xf0106170,(%esp)
f0103c4f:	e8 f9 fb ff ff       	call   f010384d <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f0103c54:	8b 43 10             	mov    0x10(%ebx),%eax
f0103c57:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c5b:	c7 04 24 7f 61 10 f0 	movl   $0xf010617f,(%esp)
f0103c62:	e8 e6 fb ff ff       	call   f010384d <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0103c67:	8b 43 14             	mov    0x14(%ebx),%eax
f0103c6a:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c6e:	c7 04 24 8e 61 10 f0 	movl   $0xf010618e,(%esp)
f0103c75:	e8 d3 fb ff ff       	call   f010384d <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f0103c7a:	8b 43 18             	mov    0x18(%ebx),%eax
f0103c7d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c81:	c7 04 24 9d 61 10 f0 	movl   $0xf010619d,(%esp)
f0103c88:	e8 c0 fb ff ff       	call   f010384d <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f0103c8d:	8b 43 1c             	mov    0x1c(%ebx),%eax
f0103c90:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c94:	c7 04 24 ac 61 10 f0 	movl   $0xf01061ac,(%esp)
f0103c9b:	e8 ad fb ff ff       	call   f010384d <cprintf>
}
f0103ca0:	83 c4 14             	add    $0x14,%esp
f0103ca3:	5b                   	pop    %ebx
f0103ca4:	5d                   	pop    %ebp
f0103ca5:	c3                   	ret    

f0103ca6 <print_trapframe>:
	lidt(&idt_pd);
}

void
print_trapframe(struct Trapframe *tf)
{
f0103ca6:	55                   	push   %ebp
f0103ca7:	89 e5                	mov    %esp,%ebp
f0103ca9:	56                   	push   %esi
f0103caa:	53                   	push   %ebx
f0103cab:	83 ec 10             	sub    $0x10,%esp
f0103cae:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p\n", tf);
f0103cb1:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103cb5:	c7 04 24 e2 62 10 f0 	movl   $0xf01062e2,(%esp)
f0103cbc:	e8 8c fb ff ff       	call   f010384d <cprintf>
	print_regs(&tf->tf_regs);
f0103cc1:	89 1c 24             	mov    %ebx,(%esp)
f0103cc4:	e8 36 ff ff ff       	call   f0103bff <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f0103cc9:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f0103ccd:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103cd1:	c7 04 24 fd 61 10 f0 	movl   $0xf01061fd,(%esp)
f0103cd8:	e8 70 fb ff ff       	call   f010384d <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f0103cdd:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f0103ce1:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103ce5:	c7 04 24 10 62 10 f0 	movl   $0xf0106210,(%esp)
f0103cec:	e8 5c fb ff ff       	call   f010384d <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0103cf1:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f0103cf4:	83 f8 13             	cmp    $0x13,%eax
f0103cf7:	77 09                	ja     f0103d02 <print_trapframe+0x5c>
		return excnames[trapno];
f0103cf9:	8b 14 85 c0 64 10 f0 	mov    -0xfef9b40(,%eax,4),%edx
f0103d00:	eb 10                	jmp    f0103d12 <print_trapframe+0x6c>
	if (trapno == T_SYSCALL)
		return "System call";
f0103d02:	83 f8 30             	cmp    $0x30,%eax
f0103d05:	ba bb 61 10 f0       	mov    $0xf01061bb,%edx
f0103d0a:	b9 c7 61 10 f0       	mov    $0xf01061c7,%ecx
f0103d0f:	0f 45 d1             	cmovne %ecx,%edx
{
	cprintf("TRAP frame at %p\n", tf);
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0103d12:	89 54 24 08          	mov    %edx,0x8(%esp)
f0103d16:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d1a:	c7 04 24 23 62 10 f0 	movl   $0xf0106223,(%esp)
f0103d21:	e8 27 fb ff ff       	call   f010384d <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f0103d26:	3b 1d 20 db 17 f0    	cmp    0xf017db20,%ebx
f0103d2c:	75 19                	jne    f0103d47 <print_trapframe+0xa1>
f0103d2e:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0103d32:	75 13                	jne    f0103d47 <print_trapframe+0xa1>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f0103d34:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f0103d37:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d3b:	c7 04 24 35 62 10 f0 	movl   $0xf0106235,(%esp)
f0103d42:	e8 06 fb ff ff       	call   f010384d <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f0103d47:	8b 43 2c             	mov    0x2c(%ebx),%eax
f0103d4a:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d4e:	c7 04 24 44 62 10 f0 	movl   $0xf0106244,(%esp)
f0103d55:	e8 f3 fa ff ff       	call   f010384d <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f0103d5a:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0103d5e:	75 51                	jne    f0103db1 <print_trapframe+0x10b>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f0103d60:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f0103d63:	89 c2                	mov    %eax,%edx
f0103d65:	83 e2 01             	and    $0x1,%edx
f0103d68:	ba d6 61 10 f0       	mov    $0xf01061d6,%edx
f0103d6d:	b9 e1 61 10 f0       	mov    $0xf01061e1,%ecx
f0103d72:	0f 45 ca             	cmovne %edx,%ecx
f0103d75:	89 c2                	mov    %eax,%edx
f0103d77:	83 e2 02             	and    $0x2,%edx
f0103d7a:	ba ed 61 10 f0       	mov    $0xf01061ed,%edx
f0103d7f:	be f3 61 10 f0       	mov    $0xf01061f3,%esi
f0103d84:	0f 44 d6             	cmove  %esi,%edx
f0103d87:	83 e0 04             	and    $0x4,%eax
f0103d8a:	b8 f8 61 10 f0       	mov    $0xf01061f8,%eax
f0103d8f:	be 0d 63 10 f0       	mov    $0xf010630d,%esi
f0103d94:	0f 44 c6             	cmove  %esi,%eax
f0103d97:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0103d9b:	89 54 24 08          	mov    %edx,0x8(%esp)
f0103d9f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103da3:	c7 04 24 52 62 10 f0 	movl   $0xf0106252,(%esp)
f0103daa:	e8 9e fa ff ff       	call   f010384d <cprintf>
f0103daf:	eb 0c                	jmp    f0103dbd <print_trapframe+0x117>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f0103db1:	c7 04 24 39 60 10 f0 	movl   $0xf0106039,(%esp)
f0103db8:	e8 90 fa ff ff       	call   f010384d <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f0103dbd:	8b 43 30             	mov    0x30(%ebx),%eax
f0103dc0:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103dc4:	c7 04 24 61 62 10 f0 	movl   $0xf0106261,(%esp)
f0103dcb:	e8 7d fa ff ff       	call   f010384d <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f0103dd0:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f0103dd4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103dd8:	c7 04 24 70 62 10 f0 	movl   $0xf0106270,(%esp)
f0103ddf:	e8 69 fa ff ff       	call   f010384d <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f0103de4:	8b 43 38             	mov    0x38(%ebx),%eax
f0103de7:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103deb:	c7 04 24 83 62 10 f0 	movl   $0xf0106283,(%esp)
f0103df2:	e8 56 fa ff ff       	call   f010384d <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f0103df7:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f0103dfb:	74 27                	je     f0103e24 <print_trapframe+0x17e>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f0103dfd:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0103e00:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e04:	c7 04 24 92 62 10 f0 	movl   $0xf0106292,(%esp)
f0103e0b:	e8 3d fa ff ff       	call   f010384d <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f0103e10:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f0103e14:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e18:	c7 04 24 a1 62 10 f0 	movl   $0xf01062a1,(%esp)
f0103e1f:	e8 29 fa ff ff       	call   f010384d <cprintf>
	}
}
f0103e24:	83 c4 10             	add    $0x10,%esp
f0103e27:	5b                   	pop    %ebx
f0103e28:	5e                   	pop    %esi
f0103e29:	5d                   	pop    %ebp
f0103e2a:	c3                   	ret    

f0103e2b <trap>:
	}
}

void
trap(struct Trapframe *tf)
{
f0103e2b:	55                   	push   %ebp
f0103e2c:	89 e5                	mov    %esp,%ebp
f0103e2e:	57                   	push   %edi
f0103e2f:	56                   	push   %esi
f0103e30:	83 ec 10             	sub    $0x10,%esp
f0103e33:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f0103e36:	fc                   	cld    

static __inline uint32_t
read_eflags(void)
{
        uint32_t eflags;
        __asm __volatile("pushfl; popl %0" : "=r" (eflags));
f0103e37:	9c                   	pushf  
f0103e38:	58                   	pop    %eax

	// Check that interrupts are disabled.  If this assertion
	// fails, DO NOT be tempted to fix it by inserting a "cli" in
	// the interrupt path.
	assert(!(read_eflags() & FL_IF));
f0103e39:	f6 c4 02             	test   $0x2,%ah
f0103e3c:	74 24                	je     f0103e62 <trap+0x37>
f0103e3e:	c7 44 24 0c b4 62 10 	movl   $0xf01062b4,0xc(%esp)
f0103e45:	f0 
f0103e46:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0103e4d:	f0 
f0103e4e:	c7 44 24 04 ce 00 00 	movl   $0xce,0x4(%esp)
f0103e55:	00 
f0103e56:	c7 04 24 cd 62 10 f0 	movl   $0xf01062cd,(%esp)
f0103e5d:	e8 5c c2 ff ff       	call   f01000be <_panic>

	cprintf("Incoming TRAP frame at %p\n", tf);
f0103e62:	89 74 24 04          	mov    %esi,0x4(%esp)
f0103e66:	c7 04 24 d9 62 10 f0 	movl   $0xf01062d9,(%esp)
f0103e6d:	e8 db f9 ff ff       	call   f010384d <cprintf>

	if ((tf->tf_cs & 3) == 3) {
f0103e72:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f0103e76:	83 e0 03             	and    $0x3,%eax
f0103e79:	66 83 f8 03          	cmp    $0x3,%ax
f0103e7d:	75 3c                	jne    f0103ebb <trap+0x90>
		// Trapped from user mode.
		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		assert(curenv);
f0103e7f:	a1 04 d3 17 f0       	mov    0xf017d304,%eax
f0103e84:	85 c0                	test   %eax,%eax
f0103e86:	75 24                	jne    f0103eac <trap+0x81>
f0103e88:	c7 44 24 0c f4 62 10 	movl   $0xf01062f4,0xc(%esp)
f0103e8f:	f0 
f0103e90:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0103e97:	f0 
f0103e98:	c7 44 24 04 d7 00 00 	movl   $0xd7,0x4(%esp)
f0103e9f:	00 
f0103ea0:	c7 04 24 cd 62 10 f0 	movl   $0xf01062cd,(%esp)
f0103ea7:	e8 12 c2 ff ff       	call   f01000be <_panic>
		curenv->env_tf = *tf;
f0103eac:	b9 11 00 00 00       	mov    $0x11,%ecx
f0103eb1:	89 c7                	mov    %eax,%edi
f0103eb3:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f0103eb5:	8b 35 04 d3 17 f0    	mov    0xf017d304,%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f0103ebb:	89 35 20 db 17 f0    	mov    %esi,0xf017db20
{
	// Handle processor exceptions.
	// LAB 3: Your code here.

	// Unexpected trap: The user process or the kernel has a bug.
	print_trapframe(tf);
f0103ec1:	89 34 24             	mov    %esi,(%esp)
f0103ec4:	e8 dd fd ff ff       	call   f0103ca6 <print_trapframe>
	if (tf->tf_cs == GD_KT)
f0103ec9:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f0103ece:	75 1c                	jne    f0103eec <trap+0xc1>
		panic("unhandled trap in kernel");
f0103ed0:	c7 44 24 08 fb 62 10 	movl   $0xf01062fb,0x8(%esp)
f0103ed7:	f0 
f0103ed8:	c7 44 24 04 bd 00 00 	movl   $0xbd,0x4(%esp)
f0103edf:	00 
f0103ee0:	c7 04 24 cd 62 10 f0 	movl   $0xf01062cd,(%esp)
f0103ee7:	e8 d2 c1 ff ff       	call   f01000be <_panic>
	else {
		env_destroy(curenv);
f0103eec:	a1 04 d3 17 f0       	mov    0xf017d304,%eax
f0103ef1:	89 04 24             	mov    %eax,(%esp)
f0103ef4:	e8 21 f8 ff ff       	call   f010371a <env_destroy>

	// Dispatch based on what type of trap occurred
	trap_dispatch(tf);

	// Return to the current environment, which should be running.
	assert(curenv && curenv->env_status == ENV_RUNNING);
f0103ef9:	a1 04 d3 17 f0       	mov    0xf017d304,%eax
f0103efe:	85 c0                	test   %eax,%eax
f0103f00:	74 06                	je     f0103f08 <trap+0xdd>
f0103f02:	83 78 54 02          	cmpl   $0x2,0x54(%eax)
f0103f06:	74 24                	je     f0103f2c <trap+0x101>
f0103f08:	c7 44 24 0c 58 64 10 	movl   $0xf0106458,0xc(%esp)
f0103f0f:	f0 
f0103f10:	c7 44 24 08 cf 5d 10 	movl   $0xf0105dcf,0x8(%esp)
f0103f17:	f0 
f0103f18:	c7 44 24 04 e5 00 00 	movl   $0xe5,0x4(%esp)
f0103f1f:	00 
f0103f20:	c7 04 24 cd 62 10 f0 	movl   $0xf01062cd,(%esp)
f0103f27:	e8 92 c1 ff ff       	call   f01000be <_panic>
	env_run(curenv);
f0103f2c:	89 04 24             	mov    %eax,(%esp)
f0103f2f:	e8 3d f8 ff ff       	call   f0103771 <env_run>

f0103f34 <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f0103f34:	55                   	push   %ebp
f0103f35:	89 e5                	mov    %esp,%ebp
f0103f37:	53                   	push   %ebx
f0103f38:	83 ec 14             	sub    $0x14,%esp
f0103f3b:	8b 5d 08             	mov    0x8(%ebp),%ebx

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f0103f3e:	0f 20 d0             	mov    %cr2,%eax

	// We've already handled kernel-mode exceptions, so if we get here,
	// the page fault happened in user mode.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0103f41:	8b 53 30             	mov    0x30(%ebx),%edx
f0103f44:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0103f48:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103f4c:	a1 04 d3 17 f0       	mov    0xf017d304,%eax
f0103f51:	8b 40 48             	mov    0x48(%eax),%eax
f0103f54:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103f58:	c7 04 24 84 64 10 f0 	movl   $0xf0106484,(%esp)
f0103f5f:	e8 e9 f8 ff ff       	call   f010384d <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
	print_trapframe(tf);
f0103f64:	89 1c 24             	mov    %ebx,(%esp)
f0103f67:	e8 3a fd ff ff       	call   f0103ca6 <print_trapframe>
	env_destroy(curenv);
f0103f6c:	a1 04 d3 17 f0       	mov    0xf017d304,%eax
f0103f71:	89 04 24             	mov    %eax,(%esp)
f0103f74:	e8 a1 f7 ff ff       	call   f010371a <env_destroy>
}
f0103f79:	83 c4 14             	add    $0x14,%esp
f0103f7c:	5b                   	pop    %ebx
f0103f7d:	5d                   	pop    %ebp
f0103f7e:	c3                   	ret    
f0103f7f:	90                   	nop

f0103f80 <Divide_error>:
.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
TRAPHANDLER_NOEC(Divide_error,T_DIVIDE);
f0103f80:	6a 00                	push   $0x0
f0103f82:	6a 00                	push   $0x0
f0103f84:	eb 5e                	jmp    f0103fe4 <_alltraps>

f0103f86 <Debug>:
TRAPHANDLER_NOEC(Debug,T_DEBUG);
f0103f86:	6a 00                	push   $0x0
f0103f88:	6a 01                	push   $0x1
f0103f8a:	eb 58                	jmp    f0103fe4 <_alltraps>

f0103f8c <Non_MaskableInterrupt>:
TRAPHANDLER_NOEC(Non_MaskableInterrupt,T_NMI );
f0103f8c:	6a 00                	push   $0x0
f0103f8e:	6a 02                	push   $0x2
f0103f90:	eb 52                	jmp    f0103fe4 <_alltraps>

f0103f92 <Breakpoint>:
TRAPHANDLER_NOEC(Breakpoint,T_BRKPT );
f0103f92:	6a 00                	push   $0x0
f0103f94:	6a 03                	push   $0x3
f0103f96:	eb 4c                	jmp    f0103fe4 <_alltraps>

f0103f98 <Overflow>:
TRAPHANDLER_NOEC(Overflow,4);
f0103f98:	6a 00                	push   $0x0
f0103f9a:	6a 04                	push   $0x4
f0103f9c:	eb 46                	jmp    f0103fe4 <_alltraps>

f0103f9e <BOUND_Range_Exceeded>:
TRAPHANDLER_NOEC(BOUND_Range_Exceeded,5);
f0103f9e:	6a 00                	push   $0x0
f0103fa0:	6a 05                	push   $0x5
f0103fa2:	eb 40                	jmp    f0103fe4 <_alltraps>

f0103fa4 <Invalid_Opcode>:
TRAPHANDLER_NOEC(Invalid_Opcode,6);
f0103fa4:	6a 00                	push   $0x0
f0103fa6:	6a 06                	push   $0x6
f0103fa8:	eb 3a                	jmp    f0103fe4 <_alltraps>

f0103faa <Device_Not_Available>:
TRAPHANDLER_NOEC(Device_Not_Available,7);
f0103faa:	6a 00                	push   $0x0
f0103fac:	6a 07                	push   $0x7
f0103fae:	eb 34                	jmp    f0103fe4 <_alltraps>

f0103fb0 <Double_Fault>:
TRAPHANDLER(Double_Fault,8);
f0103fb0:	6a 08                	push   $0x8
f0103fb2:	eb 30                	jmp    f0103fe4 <_alltraps>

f0103fb4 <Invalid_TSS>:
TRAPHANDLER(Invalid_TSS,10);
f0103fb4:	6a 0a                	push   $0xa
f0103fb6:	eb 2c                	jmp    f0103fe4 <_alltraps>

f0103fb8 <Segment_Not_Present>:
TRAPHANDLER(Segment_Not_Present,11);
f0103fb8:	6a 0b                	push   $0xb
f0103fba:	eb 28                	jmp    f0103fe4 <_alltraps>

f0103fbc <Stack_Fault>:
TRAPHANDLER(Stack_Fault,12);
f0103fbc:	6a 0c                	push   $0xc
f0103fbe:	eb 24                	jmp    f0103fe4 <_alltraps>

f0103fc0 <General_Protection>:
TRAPHANDLER(General_Protection,13);
f0103fc0:	6a 0d                	push   $0xd
f0103fc2:	eb 20                	jmp    f0103fe4 <_alltraps>

f0103fc4 <Page_Fault>:
TRAPHANDLER(Page_Fault,14);
f0103fc4:	6a 0e                	push   $0xe
f0103fc6:	eb 1c                	jmp    f0103fe4 <_alltraps>

f0103fc8 <FPU_Floating_Point_Error>:
TRAPHANDLER_NOEC(FPU_Floating_Point_Error,16);
f0103fc8:	6a 00                	push   $0x0
f0103fca:	6a 10                	push   $0x10
f0103fcc:	eb 16                	jmp    f0103fe4 <_alltraps>

f0103fce <Alignment_Check>:
TRAPHANDLER(Alignment_Check,17);
f0103fce:	6a 11                	push   $0x11
f0103fd0:	eb 12                	jmp    f0103fe4 <_alltraps>

f0103fd2 <Machine_Check>:
TRAPHANDLER_NOEC(Machine_Check,18);
f0103fd2:	6a 00                	push   $0x0
f0103fd4:	6a 12                	push   $0x12
f0103fd6:	eb 0c                	jmp    f0103fe4 <_alltraps>

f0103fd8 <SIMD_Floating_Point_Exception>:
TRAPHANDLER_NOEC(SIMD_Floating_Point_Exception,19);
f0103fd8:	6a 00                	push   $0x0
f0103fda:	6a 13                	push   $0x13
f0103fdc:	eb 06                	jmp    f0103fe4 <_alltraps>

f0103fde <systemcall_handler>:
TRAPHANDLER_NOEC(systemcall_handler,48)
f0103fde:	6a 00                	push   $0x0
f0103fe0:	6a 30                	push   $0x30
f0103fe2:	eb 00                	jmp    f0103fe4 <_alltraps>

f0103fe4 <_alltraps>:

/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
	pushw $0x0
f0103fe4:	66 6a 00             	pushw  $0x0
	pushw %ds
f0103fe7:	66 1e                	pushw  %ds
	pushw $0x0
f0103fe9:	66 6a 00             	pushw  $0x0
	pushw %es 
f0103fec:	66 06                	pushw  %es
	
	
	pushal
f0103fee:	60                   	pusha  
	pushl %esp
f0103fef:	54                   	push   %esp
	movw $(GD_KD),%ax
f0103ff0:	66 b8 10 00          	mov    $0x10,%ax
	movw %ax,%ds
f0103ff4:	8e d8                	mov    %eax,%ds
	movw %ax,%es
f0103ff6:	8e c0                	mov    %eax,%es
	call trap
f0103ff8:	e8 2e fe ff ff       	call   f0103e2b <trap>

f0103ffd <syscall>:
}

// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
f0103ffd:	55                   	push   %ebp
f0103ffe:	89 e5                	mov    %esp,%ebp
f0104000:	83 ec 18             	sub    $0x18,%esp
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.

	panic("syscall not implemented");
f0104003:	c7 44 24 08 10 65 10 	movl   $0xf0106510,0x8(%esp)
f010400a:	f0 
f010400b:	c7 44 24 04 49 00 00 	movl   $0x49,0x4(%esp)
f0104012:	00 
f0104013:	c7 04 24 28 65 10 f0 	movl   $0xf0106528,(%esp)
f010401a:	e8 9f c0 ff ff       	call   f01000be <_panic>
f010401f:	90                   	nop

f0104020 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0104020:	55                   	push   %ebp
f0104021:	89 e5                	mov    %esp,%ebp
f0104023:	57                   	push   %edi
f0104024:	56                   	push   %esi
f0104025:	53                   	push   %ebx
f0104026:	83 ec 14             	sub    $0x14,%esp
f0104029:	89 45 ec             	mov    %eax,-0x14(%ebp)
f010402c:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f010402f:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0104032:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0104035:	8b 1a                	mov    (%edx),%ebx
f0104037:	8b 01                	mov    (%ecx),%eax
f0104039:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f010403c:	39 c3                	cmp    %eax,%ebx
f010403e:	0f 8f 9a 00 00 00    	jg     f01040de <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f0104044:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f010404b:	8b 45 f0             	mov    -0x10(%ebp),%eax
f010404e:	01 d8                	add    %ebx,%eax
f0104050:	89 c7                	mov    %eax,%edi
f0104052:	c1 ef 1f             	shr    $0x1f,%edi
f0104055:	01 c7                	add    %eax,%edi
f0104057:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0104059:	39 df                	cmp    %ebx,%edi
f010405b:	0f 8c c4 00 00 00    	jl     f0104125 <stab_binsearch+0x105>
f0104061:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0104064:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104067:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f010406a:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f010406e:	39 f0                	cmp    %esi,%eax
f0104070:	0f 84 b4 00 00 00    	je     f010412a <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104076:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f0104078:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f010407b:	39 d8                	cmp    %ebx,%eax
f010407d:	0f 8c a2 00 00 00    	jl     f0104125 <stab_binsearch+0x105>
f0104083:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f0104087:	83 ea 0c             	sub    $0xc,%edx
f010408a:	39 f1                	cmp    %esi,%ecx
f010408c:	75 ea                	jne    f0104078 <stab_binsearch+0x58>
f010408e:	e9 99 00 00 00       	jmp    f010412c <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0104093:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0104096:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f0104098:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f010409b:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01040a2:	eb 2b                	jmp    f01040cf <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f01040a4:	3b 55 0c             	cmp    0xc(%ebp),%edx
f01040a7:	76 14                	jbe    f01040bd <stab_binsearch+0x9d>
			*region_right = m - 1;
f01040a9:	83 e8 01             	sub    $0x1,%eax
f01040ac:	89 45 f0             	mov    %eax,-0x10(%ebp)
f01040af:	8b 7d e0             	mov    -0x20(%ebp),%edi
f01040b2:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01040b4:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01040bb:	eb 12                	jmp    f01040cf <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f01040bd:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01040c0:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f01040c2:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f01040c6:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01040c8:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f01040cf:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f01040d2:	0f 8e 73 ff ff ff    	jle    f010404b <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f01040d8:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f01040dc:	75 0f                	jne    f01040ed <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f01040de:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01040e1:	8b 00                	mov    (%eax),%eax
f01040e3:	83 e8 01             	sub    $0x1,%eax
f01040e6:	8b 75 e0             	mov    -0x20(%ebp),%esi
f01040e9:	89 06                	mov    %eax,(%esi)
f01040eb:	eb 57                	jmp    f0104144 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f01040ed:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01040f0:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f01040f2:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01040f5:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f01040f7:	39 c8                	cmp    %ecx,%eax
f01040f9:	7e 23                	jle    f010411e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f01040fb:	8d 14 40             	lea    (%eax,%eax,2),%edx
f01040fe:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0104101:	8d 14 97             	lea    (%edi,%edx,4),%edx
f0104104:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f0104108:	39 f3                	cmp    %esi,%ebx
f010410a:	74 12                	je     f010411e <stab_binsearch+0xfe>
		     l--)
f010410c:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f010410f:	39 c8                	cmp    %ecx,%eax
f0104111:	7e 0b                	jle    f010411e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0104113:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f0104117:	83 ea 0c             	sub    $0xc,%edx
f010411a:	39 f3                	cmp    %esi,%ebx
f010411c:	75 ee                	jne    f010410c <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f010411e:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0104121:	89 06                	mov    %eax,(%esi)
f0104123:	eb 1f                	jmp    f0104144 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0104125:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0104128:	eb a5                	jmp    f01040cf <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f010412a:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f010412c:	8d 14 40             	lea    (%eax,%eax,2),%edx
f010412f:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104132:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0104136:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0104139:	0f 82 54 ff ff ff    	jb     f0104093 <stab_binsearch+0x73>
f010413f:	e9 60 ff ff ff       	jmp    f01040a4 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0104144:	83 c4 14             	add    $0x14,%esp
f0104147:	5b                   	pop    %ebx
f0104148:	5e                   	pop    %esi
f0104149:	5f                   	pop    %edi
f010414a:	5d                   	pop    %ebp
f010414b:	c3                   	ret    

f010414c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f010414c:	55                   	push   %ebp
f010414d:	89 e5                	mov    %esp,%ebp
f010414f:	57                   	push   %edi
f0104150:	56                   	push   %esi
f0104151:	53                   	push   %ebx
f0104152:	83 ec 3c             	sub    $0x3c,%esp
f0104155:	8b 7d 08             	mov    0x8(%ebp),%edi
f0104158:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f010415b:	c7 06 37 65 10 f0    	movl   $0xf0106537,(%esi)
	info->eip_line = 0;
f0104161:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0104168:	c7 46 08 37 65 10 f0 	movl   $0xf0106537,0x8(%esi)
	info->eip_fn_namelen = 9;
f010416f:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0104176:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0104179:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0104180:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f0104186:	77 21                	ja     f01041a9 <debuginfo_eip+0x5d>

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.

		stabs = usd->stabs;
f0104188:	a1 00 00 20 00       	mov    0x200000,%eax
f010418d:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f0104190:	a1 04 00 20 00       	mov    0x200004,%eax
		stabstr = usd->stabstr;
f0104195:	8b 1d 08 00 20 00    	mov    0x200008,%ebx
f010419b:	89 5d d0             	mov    %ebx,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f010419e:	8b 1d 0c 00 20 00    	mov    0x20000c,%ebx
f01041a4:	89 5d cc             	mov    %ebx,-0x34(%ebp)
f01041a7:	eb 1a                	jmp    f01041c3 <debuginfo_eip+0x77>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f01041a9:	c7 45 cc e8 0d 11 f0 	movl   $0xf0110de8,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f01041b0:	c7 45 d0 c1 e4 10 f0 	movl   $0xf010e4c1,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f01041b7:	b8 c0 e4 10 f0       	mov    $0xf010e4c0,%eax
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f01041bc:	c7 45 d4 50 67 10 f0 	movl   $0xf0106750,-0x2c(%ebp)
		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f01041c3:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f01041c6:	39 4d d0             	cmp    %ecx,-0x30(%ebp)
f01041c9:	0f 83 57 01 00 00    	jae    f0104326 <debuginfo_eip+0x1da>
f01041cf:	80 79 ff 00          	cmpb   $0x0,-0x1(%ecx)
f01041d3:	0f 85 54 01 00 00    	jne    f010432d <debuginfo_eip+0x1e1>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f01041d9:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f01041e0:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f01041e3:	29 d8                	sub    %ebx,%eax
f01041e5:	c1 f8 02             	sar    $0x2,%eax
f01041e8:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
f01041ee:	83 e8 01             	sub    $0x1,%eax
f01041f1:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f01041f4:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01041f8:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f01041ff:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0104202:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0104205:	89 d8                	mov    %ebx,%eax
f0104207:	e8 14 fe ff ff       	call   f0104020 <stab_binsearch>
	if (lfile == 0)
f010420c:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010420f:	85 c0                	test   %eax,%eax
f0104211:	0f 84 1d 01 00 00    	je     f0104334 <debuginfo_eip+0x1e8>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0104217:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f010421a:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010421d:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0104220:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104224:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f010422b:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f010422e:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0104231:	89 d8                	mov    %ebx,%eax
f0104233:	e8 e8 fd ff ff       	call   f0104020 <stab_binsearch>

	if (lfun <= rfun) {
f0104238:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f010423b:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f010423e:	7f 23                	jg     f0104263 <debuginfo_eip+0x117>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0104240:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104243:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104246:	8d 04 87             	lea    (%edi,%eax,4),%eax
f0104249:	8b 10                	mov    (%eax),%edx
f010424b:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f010424e:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f0104251:	39 ca                	cmp    %ecx,%edx
f0104253:	73 06                	jae    f010425b <debuginfo_eip+0x10f>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0104255:	03 55 d0             	add    -0x30(%ebp),%edx
f0104258:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f010425b:	8b 40 08             	mov    0x8(%eax),%eax
f010425e:	89 46 10             	mov    %eax,0x10(%esi)
f0104261:	eb 06                	jmp    f0104269 <debuginfo_eip+0x11d>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0104263:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f0104266:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0104269:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0104270:	00 
f0104271:	8b 46 08             	mov    0x8(%esi),%eax
f0104274:	89 04 24             	mov    %eax,(%esp)
f0104277:	e8 73 09 00 00       	call   f0104bef <strfind>
f010427c:	2b 46 08             	sub    0x8(%esi),%eax
f010427f:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0104282:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104285:	39 fb                	cmp    %edi,%ebx
f0104287:	7c 5d                	jl     f01042e6 <debuginfo_eip+0x19a>
	       && stabs[lline].n_type != N_SOL
f0104289:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f010428c:	c1 e0 02             	shl    $0x2,%eax
f010428f:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0104292:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f0104295:	89 55 c8             	mov    %edx,-0x38(%ebp)
f0104298:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f010429c:	80 fa 84             	cmp    $0x84,%dl
f010429f:	74 2d                	je     f01042ce <debuginfo_eip+0x182>
f01042a1:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f01042a5:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f01042a8:	eb 15                	jmp    f01042bf <debuginfo_eip+0x173>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f01042aa:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f01042ad:	39 fb                	cmp    %edi,%ebx
f01042af:	7c 35                	jl     f01042e6 <debuginfo_eip+0x19a>
	       && stabs[lline].n_type != N_SOL
f01042b1:	89 c1                	mov    %eax,%ecx
f01042b3:	83 e8 0c             	sub    $0xc,%eax
f01042b6:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f01042ba:	80 fa 84             	cmp    $0x84,%dl
f01042bd:	74 0f                	je     f01042ce <debuginfo_eip+0x182>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f01042bf:	80 fa 64             	cmp    $0x64,%dl
f01042c2:	75 e6                	jne    f01042aa <debuginfo_eip+0x15e>
f01042c4:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f01042c8:	74 e0                	je     f01042aa <debuginfo_eip+0x15e>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f01042ca:	39 df                	cmp    %ebx,%edi
f01042cc:	7f 18                	jg     f01042e6 <debuginfo_eip+0x19a>
f01042ce:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f01042d1:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f01042d4:	8b 04 87             	mov    (%edi,%eax,4),%eax
f01042d7:	8b 55 cc             	mov    -0x34(%ebp),%edx
f01042da:	2b 55 d0             	sub    -0x30(%ebp),%edx
f01042dd:	39 d0                	cmp    %edx,%eax
f01042df:	73 05                	jae    f01042e6 <debuginfo_eip+0x19a>
		info->eip_file = stabstr + stabs[lline].n_strx;
f01042e1:	03 45 d0             	add    -0x30(%ebp),%eax
f01042e4:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f01042e6:	8b 55 dc             	mov    -0x24(%ebp),%edx
f01042e9:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f01042ec:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f01042f1:	39 ca                	cmp    %ecx,%edx
f01042f3:	7d 60                	jge    f0104355 <debuginfo_eip+0x209>
		for (lline = lfun + 1;
f01042f5:	8d 42 01             	lea    0x1(%edx),%eax
f01042f8:	39 c1                	cmp    %eax,%ecx
f01042fa:	7e 3f                	jle    f010433b <debuginfo_eip+0x1ef>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f01042fc:	8d 14 40             	lea    (%eax,%eax,2),%edx
f01042ff:	c1 e2 02             	shl    $0x2,%edx
f0104302:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104305:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f010430a:	75 36                	jne    f0104342 <debuginfo_eip+0x1f6>
f010430c:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f0104310:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0104314:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0104317:	39 c1                	cmp    %eax,%ecx
f0104319:	7e 2e                	jle    f0104349 <debuginfo_eip+0x1fd>
f010431b:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f010431e:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0104322:	74 ec                	je     f0104310 <debuginfo_eip+0x1c4>
f0104324:	eb 2a                	jmp    f0104350 <debuginfo_eip+0x204>
		// LAB 3: Your code here.
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0104326:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f010432b:	eb 28                	jmp    f0104355 <debuginfo_eip+0x209>
f010432d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104332:	eb 21                	jmp    f0104355 <debuginfo_eip+0x209>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0104334:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104339:	eb 1a                	jmp    f0104355 <debuginfo_eip+0x209>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f010433b:	b8 00 00 00 00       	mov    $0x0,%eax
f0104340:	eb 13                	jmp    f0104355 <debuginfo_eip+0x209>
f0104342:	b8 00 00 00 00       	mov    $0x0,%eax
f0104347:	eb 0c                	jmp    f0104355 <debuginfo_eip+0x209>
f0104349:	b8 00 00 00 00       	mov    $0x0,%eax
f010434e:	eb 05                	jmp    f0104355 <debuginfo_eip+0x209>
f0104350:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0104355:	83 c4 3c             	add    $0x3c,%esp
f0104358:	5b                   	pop    %ebx
f0104359:	5e                   	pop    %esi
f010435a:	5f                   	pop    %edi
f010435b:	5d                   	pop    %ebp
f010435c:	c3                   	ret    
f010435d:	66 90                	xchg   %ax,%ax
f010435f:	90                   	nop

f0104360 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0104360:	55                   	push   %ebp
f0104361:	89 e5                	mov    %esp,%ebp
f0104363:	57                   	push   %edi
f0104364:	56                   	push   %esi
f0104365:	53                   	push   %ebx
f0104366:	83 ec 3c             	sub    $0x3c,%esp
f0104369:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010436c:	89 d7                	mov    %edx,%edi
f010436e:	8b 45 08             	mov    0x8(%ebp),%eax
f0104371:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0104374:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104377:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f010437a:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f010437d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0104382:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0104385:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0104388:	39 f1                	cmp    %esi,%ecx
f010438a:	72 14                	jb     f01043a0 <printnum+0x40>
f010438c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f010438f:	76 0f                	jbe    f01043a0 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0104391:	8b 45 14             	mov    0x14(%ebp),%eax
f0104394:	8d 70 ff             	lea    -0x1(%eax),%esi
f0104397:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f010439a:	85 f6                	test   %esi,%esi
f010439c:	7f 60                	jg     f01043fe <printnum+0x9e>
f010439e:	eb 72                	jmp    f0104412 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f01043a0:	8b 4d 18             	mov    0x18(%ebp),%ecx
f01043a3:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f01043a7:	8b 4d 14             	mov    0x14(%ebp),%ecx
f01043aa:	8d 51 ff             	lea    -0x1(%ecx),%edx
f01043ad:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01043b1:	89 44 24 08          	mov    %eax,0x8(%esp)
f01043b5:	8b 44 24 08          	mov    0x8(%esp),%eax
f01043b9:	8b 54 24 0c          	mov    0xc(%esp),%edx
f01043bd:	89 c3                	mov    %eax,%ebx
f01043bf:	89 d6                	mov    %edx,%esi
f01043c1:	8b 55 d8             	mov    -0x28(%ebp),%edx
f01043c4:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f01043c7:	89 54 24 08          	mov    %edx,0x8(%esp)
f01043cb:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01043cf:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01043d2:	89 04 24             	mov    %eax,(%esp)
f01043d5:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01043d8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01043dc:	e8 6f 0a 00 00       	call   f0104e50 <__udivdi3>
f01043e1:	89 d9                	mov    %ebx,%ecx
f01043e3:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01043e7:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01043eb:	89 04 24             	mov    %eax,(%esp)
f01043ee:	89 54 24 04          	mov    %edx,0x4(%esp)
f01043f2:	89 fa                	mov    %edi,%edx
f01043f4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01043f7:	e8 64 ff ff ff       	call   f0104360 <printnum>
f01043fc:	eb 14                	jmp    f0104412 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f01043fe:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104402:	8b 45 18             	mov    0x18(%ebp),%eax
f0104405:	89 04 24             	mov    %eax,(%esp)
f0104408:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f010440a:	83 ee 01             	sub    $0x1,%esi
f010440d:	75 ef                	jne    f01043fe <printnum+0x9e>
f010440f:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0104412:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104416:	8b 7c 24 04          	mov    0x4(%esp),%edi
f010441a:	8b 45 d8             	mov    -0x28(%ebp),%eax
f010441d:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0104420:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104424:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0104428:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010442b:	89 04 24             	mov    %eax,(%esp)
f010442e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0104431:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104435:	e8 46 0b 00 00       	call   f0104f80 <__umoddi3>
f010443a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010443e:	0f be 80 41 65 10 f0 	movsbl -0xfef9abf(%eax),%eax
f0104445:	89 04 24             	mov    %eax,(%esp)
f0104448:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010444b:	ff d0                	call   *%eax
}
f010444d:	83 c4 3c             	add    $0x3c,%esp
f0104450:	5b                   	pop    %ebx
f0104451:	5e                   	pop    %esi
f0104452:	5f                   	pop    %edi
f0104453:	5d                   	pop    %ebp
f0104454:	c3                   	ret    

f0104455 <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0104455:	55                   	push   %ebp
f0104456:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0104458:	83 fa 01             	cmp    $0x1,%edx
f010445b:	7e 0e                	jle    f010446b <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f010445d:	8b 10                	mov    (%eax),%edx
f010445f:	8d 4a 08             	lea    0x8(%edx),%ecx
f0104462:	89 08                	mov    %ecx,(%eax)
f0104464:	8b 02                	mov    (%edx),%eax
f0104466:	8b 52 04             	mov    0x4(%edx),%edx
f0104469:	eb 22                	jmp    f010448d <getuint+0x38>
	else if (lflag)
f010446b:	85 d2                	test   %edx,%edx
f010446d:	74 10                	je     f010447f <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f010446f:	8b 10                	mov    (%eax),%edx
f0104471:	8d 4a 04             	lea    0x4(%edx),%ecx
f0104474:	89 08                	mov    %ecx,(%eax)
f0104476:	8b 02                	mov    (%edx),%eax
f0104478:	ba 00 00 00 00       	mov    $0x0,%edx
f010447d:	eb 0e                	jmp    f010448d <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f010447f:	8b 10                	mov    (%eax),%edx
f0104481:	8d 4a 04             	lea    0x4(%edx),%ecx
f0104484:	89 08                	mov    %ecx,(%eax)
f0104486:	8b 02                	mov    (%edx),%eax
f0104488:	ba 00 00 00 00       	mov    $0x0,%edx
}
f010448d:	5d                   	pop    %ebp
f010448e:	c3                   	ret    

f010448f <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f010448f:	55                   	push   %ebp
f0104490:	89 e5                	mov    %esp,%ebp
f0104492:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0104495:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0104499:	8b 10                	mov    (%eax),%edx
f010449b:	3b 50 04             	cmp    0x4(%eax),%edx
f010449e:	73 0a                	jae    f01044aa <sprintputch+0x1b>
		*b->buf++ = ch;
f01044a0:	8d 4a 01             	lea    0x1(%edx),%ecx
f01044a3:	89 08                	mov    %ecx,(%eax)
f01044a5:	8b 45 08             	mov    0x8(%ebp),%eax
f01044a8:	88 02                	mov    %al,(%edx)
}
f01044aa:	5d                   	pop    %ebp
f01044ab:	c3                   	ret    

f01044ac <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f01044ac:	55                   	push   %ebp
f01044ad:	89 e5                	mov    %esp,%ebp
f01044af:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f01044b2:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f01044b5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01044b9:	8b 45 10             	mov    0x10(%ebp),%eax
f01044bc:	89 44 24 08          	mov    %eax,0x8(%esp)
f01044c0:	8b 45 0c             	mov    0xc(%ebp),%eax
f01044c3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01044c7:	8b 45 08             	mov    0x8(%ebp),%eax
f01044ca:	89 04 24             	mov    %eax,(%esp)
f01044cd:	e8 02 00 00 00       	call   f01044d4 <vprintfmt>
	va_end(ap);
}
f01044d2:	c9                   	leave  
f01044d3:	c3                   	ret    

f01044d4 <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f01044d4:	55                   	push   %ebp
f01044d5:	89 e5                	mov    %esp,%ebp
f01044d7:	57                   	push   %edi
f01044d8:	56                   	push   %esi
f01044d9:	53                   	push   %ebx
f01044da:	83 ec 3c             	sub    $0x3c,%esp
f01044dd:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01044e0:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01044e3:	eb 18                	jmp    f01044fd <vprintfmt+0x29>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f01044e5:	85 c0                	test   %eax,%eax
f01044e7:	0f 84 c3 03 00 00    	je     f01048b0 <vprintfmt+0x3dc>
				return;
			putch(ch, putdat);
f01044ed:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01044f1:	89 04 24             	mov    %eax,(%esp)
f01044f4:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01044f7:	89 f3                	mov    %esi,%ebx
f01044f9:	eb 02                	jmp    f01044fd <vprintfmt+0x29>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f01044fb:	89 f3                	mov    %esi,%ebx
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01044fd:	8d 73 01             	lea    0x1(%ebx),%esi
f0104500:	0f b6 03             	movzbl (%ebx),%eax
f0104503:	83 f8 25             	cmp    $0x25,%eax
f0104506:	75 dd                	jne    f01044e5 <vprintfmt+0x11>
f0104508:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f010450c:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0104513:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f010451a:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0104521:	ba 00 00 00 00       	mov    $0x0,%edx
f0104526:	eb 1d                	jmp    f0104545 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104528:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f010452a:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f010452e:	eb 15                	jmp    f0104545 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104530:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0104532:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f0104536:	eb 0d                	jmp    f0104545 <vprintfmt+0x71>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0104538:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010453b:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010453e:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104545:	8d 5e 01             	lea    0x1(%esi),%ebx
f0104548:	0f b6 06             	movzbl (%esi),%eax
f010454b:	0f b6 c8             	movzbl %al,%ecx
f010454e:	83 e8 23             	sub    $0x23,%eax
f0104551:	3c 55                	cmp    $0x55,%al
f0104553:	0f 87 2f 03 00 00    	ja     f0104888 <vprintfmt+0x3b4>
f0104559:	0f b6 c0             	movzbl %al,%eax
f010455c:	ff 24 85 cc 65 10 f0 	jmp    *-0xfef9a34(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0104563:	8d 41 d0             	lea    -0x30(%ecx),%eax
f0104566:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0104569:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f010456d:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0104570:	83 f9 09             	cmp    $0x9,%ecx
f0104573:	77 50                	ja     f01045c5 <vprintfmt+0xf1>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104575:	89 de                	mov    %ebx,%esi
f0104577:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f010457a:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f010457d:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0104580:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0104584:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0104587:	8d 58 d0             	lea    -0x30(%eax),%ebx
f010458a:	83 fb 09             	cmp    $0x9,%ebx
f010458d:	76 eb                	jbe    f010457a <vprintfmt+0xa6>
f010458f:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0104592:	eb 33                	jmp    f01045c7 <vprintfmt+0xf3>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0104594:	8b 45 14             	mov    0x14(%ebp),%eax
f0104597:	8d 48 04             	lea    0x4(%eax),%ecx
f010459a:	89 4d 14             	mov    %ecx,0x14(%ebp)
f010459d:	8b 00                	mov    (%eax),%eax
f010459f:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01045a2:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f01045a4:	eb 21                	jmp    f01045c7 <vprintfmt+0xf3>
f01045a6:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f01045a9:	85 c9                	test   %ecx,%ecx
f01045ab:	b8 00 00 00 00       	mov    $0x0,%eax
f01045b0:	0f 49 c1             	cmovns %ecx,%eax
f01045b3:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01045b6:	89 de                	mov    %ebx,%esi
f01045b8:	eb 8b                	jmp    f0104545 <vprintfmt+0x71>
f01045ba:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f01045bc:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f01045c3:	eb 80                	jmp    f0104545 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01045c5:	89 de                	mov    %ebx,%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f01045c7:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01045cb:	0f 89 74 ff ff ff    	jns    f0104545 <vprintfmt+0x71>
f01045d1:	e9 62 ff ff ff       	jmp    f0104538 <vprintfmt+0x64>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f01045d6:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01045d9:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f01045db:	e9 65 ff ff ff       	jmp    f0104545 <vprintfmt+0x71>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f01045e0:	8b 45 14             	mov    0x14(%ebp),%eax
f01045e3:	8d 50 04             	lea    0x4(%eax),%edx
f01045e6:	89 55 14             	mov    %edx,0x14(%ebp)
f01045e9:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01045ed:	8b 00                	mov    (%eax),%eax
f01045ef:	89 04 24             	mov    %eax,(%esp)
f01045f2:	ff 55 08             	call   *0x8(%ebp)
			break;
f01045f5:	e9 03 ff ff ff       	jmp    f01044fd <vprintfmt+0x29>

		// error message
		case 'e':
			err = va_arg(ap, int);
f01045fa:	8b 45 14             	mov    0x14(%ebp),%eax
f01045fd:	8d 50 04             	lea    0x4(%eax),%edx
f0104600:	89 55 14             	mov    %edx,0x14(%ebp)
f0104603:	8b 00                	mov    (%eax),%eax
f0104605:	99                   	cltd   
f0104606:	31 d0                	xor    %edx,%eax
f0104608:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f010460a:	83 f8 06             	cmp    $0x6,%eax
f010460d:	7f 0b                	jg     f010461a <vprintfmt+0x146>
f010460f:	8b 14 85 24 67 10 f0 	mov    -0xfef98dc(,%eax,4),%edx
f0104616:	85 d2                	test   %edx,%edx
f0104618:	75 20                	jne    f010463a <vprintfmt+0x166>
				printfmt(putch, putdat, "error %d", err);
f010461a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010461e:	c7 44 24 08 59 65 10 	movl   $0xf0106559,0x8(%esp)
f0104625:	f0 
f0104626:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010462a:	8b 45 08             	mov    0x8(%ebp),%eax
f010462d:	89 04 24             	mov    %eax,(%esp)
f0104630:	e8 77 fe ff ff       	call   f01044ac <printfmt>
f0104635:	e9 c3 fe ff ff       	jmp    f01044fd <vprintfmt+0x29>
			else
				printfmt(putch, putdat, "%s", p);
f010463a:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010463e:	c7 44 24 08 e1 5d 10 	movl   $0xf0105de1,0x8(%esp)
f0104645:	f0 
f0104646:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010464a:	8b 45 08             	mov    0x8(%ebp),%eax
f010464d:	89 04 24             	mov    %eax,(%esp)
f0104650:	e8 57 fe ff ff       	call   f01044ac <printfmt>
f0104655:	e9 a3 fe ff ff       	jmp    f01044fd <vprintfmt+0x29>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010465a:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f010465d:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0104660:	8b 45 14             	mov    0x14(%ebp),%eax
f0104663:	8d 50 04             	lea    0x4(%eax),%edx
f0104666:	89 55 14             	mov    %edx,0x14(%ebp)
f0104669:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f010466b:	85 c0                	test   %eax,%eax
f010466d:	ba 52 65 10 f0       	mov    $0xf0106552,%edx
f0104672:	0f 45 d0             	cmovne %eax,%edx
f0104675:	89 55 d0             	mov    %edx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f0104678:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f010467c:	74 04                	je     f0104682 <vprintfmt+0x1ae>
f010467e:	85 f6                	test   %esi,%esi
f0104680:	7f 19                	jg     f010469b <vprintfmt+0x1c7>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0104682:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0104685:	8d 70 01             	lea    0x1(%eax),%esi
f0104688:	0f b6 10             	movzbl (%eax),%edx
f010468b:	0f be c2             	movsbl %dl,%eax
f010468e:	85 c0                	test   %eax,%eax
f0104690:	0f 85 95 00 00 00    	jne    f010472b <vprintfmt+0x257>
f0104696:	e9 85 00 00 00       	jmp    f0104720 <vprintfmt+0x24c>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f010469b:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f010469f:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01046a2:	89 04 24             	mov    %eax,(%esp)
f01046a5:	e8 88 03 00 00       	call   f0104a32 <strnlen>
f01046aa:	29 c6                	sub    %eax,%esi
f01046ac:	89 f0                	mov    %esi,%eax
f01046ae:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f01046b1:	85 f6                	test   %esi,%esi
f01046b3:	7e cd                	jle    f0104682 <vprintfmt+0x1ae>
					putch(padc, putdat);
f01046b5:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f01046b9:	89 5d 10             	mov    %ebx,0x10(%ebp)
f01046bc:	89 c3                	mov    %eax,%ebx
f01046be:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01046c2:	89 34 24             	mov    %esi,(%esp)
f01046c5:	ff 55 08             	call   *0x8(%ebp)
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f01046c8:	83 eb 01             	sub    $0x1,%ebx
f01046cb:	75 f1                	jne    f01046be <vprintfmt+0x1ea>
f01046cd:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f01046d0:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01046d3:	eb ad                	jmp    f0104682 <vprintfmt+0x1ae>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f01046d5:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f01046d9:	74 1e                	je     f01046f9 <vprintfmt+0x225>
f01046db:	0f be d2             	movsbl %dl,%edx
f01046de:	83 ea 20             	sub    $0x20,%edx
f01046e1:	83 fa 5e             	cmp    $0x5e,%edx
f01046e4:	76 13                	jbe    f01046f9 <vprintfmt+0x225>
					putch('?', putdat);
f01046e6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01046e9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046ed:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f01046f4:	ff 55 08             	call   *0x8(%ebp)
f01046f7:	eb 0d                	jmp    f0104706 <vprintfmt+0x232>
				else
					putch(ch, putdat);
f01046f9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01046fc:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0104700:	89 04 24             	mov    %eax,(%esp)
f0104703:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0104706:	83 ef 01             	sub    $0x1,%edi
f0104709:	83 c6 01             	add    $0x1,%esi
f010470c:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f0104710:	0f be c2             	movsbl %dl,%eax
f0104713:	85 c0                	test   %eax,%eax
f0104715:	75 20                	jne    f0104737 <vprintfmt+0x263>
f0104717:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f010471a:	8b 7d 0c             	mov    0xc(%ebp),%edi
f010471d:	8b 5d 10             	mov    0x10(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0104720:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0104724:	7f 25                	jg     f010474b <vprintfmt+0x277>
f0104726:	e9 d2 fd ff ff       	jmp    f01044fd <vprintfmt+0x29>
f010472b:	89 7d 0c             	mov    %edi,0xc(%ebp)
f010472e:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104731:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0104734:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0104737:	85 db                	test   %ebx,%ebx
f0104739:	78 9a                	js     f01046d5 <vprintfmt+0x201>
f010473b:	83 eb 01             	sub    $0x1,%ebx
f010473e:	79 95                	jns    f01046d5 <vprintfmt+0x201>
f0104740:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f0104743:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0104746:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0104749:	eb d5                	jmp    f0104720 <vprintfmt+0x24c>
f010474b:	8b 75 08             	mov    0x8(%ebp),%esi
f010474e:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0104751:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0104754:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104758:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f010475f:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0104761:	83 eb 01             	sub    $0x1,%ebx
f0104764:	75 ee                	jne    f0104754 <vprintfmt+0x280>
f0104766:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0104769:	e9 8f fd ff ff       	jmp    f01044fd <vprintfmt+0x29>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010476e:	83 fa 01             	cmp    $0x1,%edx
f0104771:	7e 16                	jle    f0104789 <vprintfmt+0x2b5>
		return va_arg(*ap, long long);
f0104773:	8b 45 14             	mov    0x14(%ebp),%eax
f0104776:	8d 50 08             	lea    0x8(%eax),%edx
f0104779:	89 55 14             	mov    %edx,0x14(%ebp)
f010477c:	8b 50 04             	mov    0x4(%eax),%edx
f010477f:	8b 00                	mov    (%eax),%eax
f0104781:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0104784:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0104787:	eb 32                	jmp    f01047bb <vprintfmt+0x2e7>
	else if (lflag)
f0104789:	85 d2                	test   %edx,%edx
f010478b:	74 18                	je     f01047a5 <vprintfmt+0x2d1>
		return va_arg(*ap, long);
f010478d:	8b 45 14             	mov    0x14(%ebp),%eax
f0104790:	8d 50 04             	lea    0x4(%eax),%edx
f0104793:	89 55 14             	mov    %edx,0x14(%ebp)
f0104796:	8b 30                	mov    (%eax),%esi
f0104798:	89 75 d8             	mov    %esi,-0x28(%ebp)
f010479b:	89 f0                	mov    %esi,%eax
f010479d:	c1 f8 1f             	sar    $0x1f,%eax
f01047a0:	89 45 dc             	mov    %eax,-0x24(%ebp)
f01047a3:	eb 16                	jmp    f01047bb <vprintfmt+0x2e7>
	else
		return va_arg(*ap, int);
f01047a5:	8b 45 14             	mov    0x14(%ebp),%eax
f01047a8:	8d 50 04             	lea    0x4(%eax),%edx
f01047ab:	89 55 14             	mov    %edx,0x14(%ebp)
f01047ae:	8b 30                	mov    (%eax),%esi
f01047b0:	89 75 d8             	mov    %esi,-0x28(%ebp)
f01047b3:	89 f0                	mov    %esi,%eax
f01047b5:	c1 f8 1f             	sar    $0x1f,%eax
f01047b8:	89 45 dc             	mov    %eax,-0x24(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f01047bb:	8b 45 d8             	mov    -0x28(%ebp),%eax
f01047be:	8b 55 dc             	mov    -0x24(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f01047c1:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f01047c6:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f01047ca:	0f 89 80 00 00 00    	jns    f0104850 <vprintfmt+0x37c>
				putch('-', putdat);
f01047d0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01047d4:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f01047db:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f01047de:	8b 45 d8             	mov    -0x28(%ebp),%eax
f01047e1:	8b 55 dc             	mov    -0x24(%ebp),%edx
f01047e4:	f7 d8                	neg    %eax
f01047e6:	83 d2 00             	adc    $0x0,%edx
f01047e9:	f7 da                	neg    %edx
			}
			base = 10;
f01047eb:	b9 0a 00 00 00       	mov    $0xa,%ecx
f01047f0:	eb 5e                	jmp    f0104850 <vprintfmt+0x37c>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f01047f2:	8d 45 14             	lea    0x14(%ebp),%eax
f01047f5:	e8 5b fc ff ff       	call   f0104455 <getuint>
			base = 10;
f01047fa:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f01047ff:	eb 4f                	jmp    f0104850 <vprintfmt+0x37c>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			//putch('X', putdat);
			num = getuint(&ap, lflag);
f0104801:	8d 45 14             	lea    0x14(%ebp),%eax
f0104804:	e8 4c fc ff ff       	call   f0104455 <getuint>
			base = 8;
f0104809:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f010480e:	eb 40                	jmp    f0104850 <vprintfmt+0x37c>
			//putch('X', putdat);
			//break;

		// pointer
		case 'p':
			putch('0', putdat);
f0104810:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104814:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f010481b:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f010481e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104822:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f0104829:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f010482c:	8b 45 14             	mov    0x14(%ebp),%eax
f010482f:	8d 50 04             	lea    0x4(%eax),%edx
f0104832:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f0104835:	8b 00                	mov    (%eax),%eax
f0104837:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f010483c:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f0104841:	eb 0d                	jmp    f0104850 <vprintfmt+0x37c>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f0104843:	8d 45 14             	lea    0x14(%ebp),%eax
f0104846:	e8 0a fc ff ff       	call   f0104455 <getuint>
			base = 16;
f010484b:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f0104850:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0104854:	89 74 24 10          	mov    %esi,0x10(%esp)
f0104858:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f010485b:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010485f:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104863:	89 04 24             	mov    %eax,(%esp)
f0104866:	89 54 24 04          	mov    %edx,0x4(%esp)
f010486a:	89 fa                	mov    %edi,%edx
f010486c:	8b 45 08             	mov    0x8(%ebp),%eax
f010486f:	e8 ec fa ff ff       	call   f0104360 <printnum>
			break;
f0104874:	e9 84 fc ff ff       	jmp    f01044fd <vprintfmt+0x29>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0104879:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010487d:	89 0c 24             	mov    %ecx,(%esp)
f0104880:	ff 55 08             	call   *0x8(%ebp)
			break;
f0104883:	e9 75 fc ff ff       	jmp    f01044fd <vprintfmt+0x29>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0104888:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010488c:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0104893:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f0104896:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f010489a:	0f 84 5b fc ff ff    	je     f01044fb <vprintfmt+0x27>
f01048a0:	89 f3                	mov    %esi,%ebx
f01048a2:	83 eb 01             	sub    $0x1,%ebx
f01048a5:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f01048a9:	75 f7                	jne    f01048a2 <vprintfmt+0x3ce>
f01048ab:	e9 4d fc ff ff       	jmp    f01044fd <vprintfmt+0x29>
				/* do nothing */;
			break;
		}
	}
}
f01048b0:	83 c4 3c             	add    $0x3c,%esp
f01048b3:	5b                   	pop    %ebx
f01048b4:	5e                   	pop    %esi
f01048b5:	5f                   	pop    %edi
f01048b6:	5d                   	pop    %ebp
f01048b7:	c3                   	ret    

f01048b8 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f01048b8:	55                   	push   %ebp
f01048b9:	89 e5                	mov    %esp,%ebp
f01048bb:	83 ec 28             	sub    $0x28,%esp
f01048be:	8b 45 08             	mov    0x8(%ebp),%eax
f01048c1:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f01048c4:	89 45 ec             	mov    %eax,-0x14(%ebp)
f01048c7:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f01048cb:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f01048ce:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f01048d5:	85 c0                	test   %eax,%eax
f01048d7:	74 30                	je     f0104909 <vsnprintf+0x51>
f01048d9:	85 d2                	test   %edx,%edx
f01048db:	7e 2c                	jle    f0104909 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f01048dd:	8b 45 14             	mov    0x14(%ebp),%eax
f01048e0:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01048e4:	8b 45 10             	mov    0x10(%ebp),%eax
f01048e7:	89 44 24 08          	mov    %eax,0x8(%esp)
f01048eb:	8d 45 ec             	lea    -0x14(%ebp),%eax
f01048ee:	89 44 24 04          	mov    %eax,0x4(%esp)
f01048f2:	c7 04 24 8f 44 10 f0 	movl   $0xf010448f,(%esp)
f01048f9:	e8 d6 fb ff ff       	call   f01044d4 <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f01048fe:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0104901:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0104904:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0104907:	eb 05                	jmp    f010490e <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f0104909:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f010490e:	c9                   	leave  
f010490f:	c3                   	ret    

f0104910 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f0104910:	55                   	push   %ebp
f0104911:	89 e5                	mov    %esp,%ebp
f0104913:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0104916:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f0104919:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010491d:	8b 45 10             	mov    0x10(%ebp),%eax
f0104920:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104924:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104927:	89 44 24 04          	mov    %eax,0x4(%esp)
f010492b:	8b 45 08             	mov    0x8(%ebp),%eax
f010492e:	89 04 24             	mov    %eax,(%esp)
f0104931:	e8 82 ff ff ff       	call   f01048b8 <vsnprintf>
	va_end(ap);

	return rc;
}
f0104936:	c9                   	leave  
f0104937:	c3                   	ret    
f0104938:	66 90                	xchg   %ax,%ax
f010493a:	66 90                	xchg   %ax,%ax
f010493c:	66 90                	xchg   %ax,%ax
f010493e:	66 90                	xchg   %ax,%ax

f0104940 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0104940:	55                   	push   %ebp
f0104941:	89 e5                	mov    %esp,%ebp
f0104943:	57                   	push   %edi
f0104944:	56                   	push   %esi
f0104945:	53                   	push   %ebx
f0104946:	83 ec 1c             	sub    $0x1c,%esp
f0104949:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f010494c:	85 c0                	test   %eax,%eax
f010494e:	74 10                	je     f0104960 <readline+0x20>
		cprintf("%s", prompt);
f0104950:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104954:	c7 04 24 e1 5d 10 f0 	movl   $0xf0105de1,(%esp)
f010495b:	e8 ed ee ff ff       	call   f010384d <cprintf>

	i = 0;
	echoing = iscons(0);
f0104960:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0104967:	e8 e9 bc ff ff       	call   f0100655 <iscons>
f010496c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f010496e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0104973:	e8 cc bc ff ff       	call   f0100644 <getchar>
f0104978:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f010497a:	85 c0                	test   %eax,%eax
f010497c:	79 17                	jns    f0104995 <readline+0x55>
			cprintf("read error: %e\n", c);
f010497e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104982:	c7 04 24 40 67 10 f0 	movl   $0xf0106740,(%esp)
f0104989:	e8 bf ee ff ff       	call   f010384d <cprintf>
			return NULL;
f010498e:	b8 00 00 00 00       	mov    $0x0,%eax
f0104993:	eb 6d                	jmp    f0104a02 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0104995:	83 f8 7f             	cmp    $0x7f,%eax
f0104998:	74 05                	je     f010499f <readline+0x5f>
f010499a:	83 f8 08             	cmp    $0x8,%eax
f010499d:	75 19                	jne    f01049b8 <readline+0x78>
f010499f:	85 f6                	test   %esi,%esi
f01049a1:	7e 15                	jle    f01049b8 <readline+0x78>
			if (echoing)
f01049a3:	85 ff                	test   %edi,%edi
f01049a5:	74 0c                	je     f01049b3 <readline+0x73>
				cputchar('\b');
f01049a7:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f01049ae:	e8 81 bc ff ff       	call   f0100634 <cputchar>
			i--;
f01049b3:	83 ee 01             	sub    $0x1,%esi
f01049b6:	eb bb                	jmp    f0104973 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f01049b8:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f01049be:	7f 1c                	jg     f01049dc <readline+0x9c>
f01049c0:	83 fb 1f             	cmp    $0x1f,%ebx
f01049c3:	7e 17                	jle    f01049dc <readline+0x9c>
			if (echoing)
f01049c5:	85 ff                	test   %edi,%edi
f01049c7:	74 08                	je     f01049d1 <readline+0x91>
				cputchar(c);
f01049c9:	89 1c 24             	mov    %ebx,(%esp)
f01049cc:	e8 63 bc ff ff       	call   f0100634 <cputchar>
			buf[i++] = c;
f01049d1:	88 9e c0 db 17 f0    	mov    %bl,-0xfe82440(%esi)
f01049d7:	8d 76 01             	lea    0x1(%esi),%esi
f01049da:	eb 97                	jmp    f0104973 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f01049dc:	83 fb 0d             	cmp    $0xd,%ebx
f01049df:	74 05                	je     f01049e6 <readline+0xa6>
f01049e1:	83 fb 0a             	cmp    $0xa,%ebx
f01049e4:	75 8d                	jne    f0104973 <readline+0x33>
			if (echoing)
f01049e6:	85 ff                	test   %edi,%edi
f01049e8:	74 0c                	je     f01049f6 <readline+0xb6>
				cputchar('\n');
f01049ea:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f01049f1:	e8 3e bc ff ff       	call   f0100634 <cputchar>
			buf[i] = 0;
f01049f6:	c6 86 c0 db 17 f0 00 	movb   $0x0,-0xfe82440(%esi)
			return buf;
f01049fd:	b8 c0 db 17 f0       	mov    $0xf017dbc0,%eax
		}
	}
}
f0104a02:	83 c4 1c             	add    $0x1c,%esp
f0104a05:	5b                   	pop    %ebx
f0104a06:	5e                   	pop    %esi
f0104a07:	5f                   	pop    %edi
f0104a08:	5d                   	pop    %ebp
f0104a09:	c3                   	ret    
f0104a0a:	66 90                	xchg   %ax,%ax
f0104a0c:	66 90                	xchg   %ax,%ax
f0104a0e:	66 90                	xchg   %ax,%ax

f0104a10 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0104a10:	55                   	push   %ebp
f0104a11:	89 e5                	mov    %esp,%ebp
f0104a13:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0104a16:	80 3a 00             	cmpb   $0x0,(%edx)
f0104a19:	74 10                	je     f0104a2b <strlen+0x1b>
f0104a1b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f0104a20:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0104a23:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0104a27:	75 f7                	jne    f0104a20 <strlen+0x10>
f0104a29:	eb 05                	jmp    f0104a30 <strlen+0x20>
f0104a2b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0104a30:	5d                   	pop    %ebp
f0104a31:	c3                   	ret    

f0104a32 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0104a32:	55                   	push   %ebp
f0104a33:	89 e5                	mov    %esp,%ebp
f0104a35:	53                   	push   %ebx
f0104a36:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0104a39:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0104a3c:	85 c9                	test   %ecx,%ecx
f0104a3e:	74 1c                	je     f0104a5c <strnlen+0x2a>
f0104a40:	80 3b 00             	cmpb   $0x0,(%ebx)
f0104a43:	74 1e                	je     f0104a63 <strnlen+0x31>
f0104a45:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f0104a4a:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0104a4c:	39 ca                	cmp    %ecx,%edx
f0104a4e:	74 18                	je     f0104a68 <strnlen+0x36>
f0104a50:	83 c2 01             	add    $0x1,%edx
f0104a53:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0104a58:	75 f0                	jne    f0104a4a <strnlen+0x18>
f0104a5a:	eb 0c                	jmp    f0104a68 <strnlen+0x36>
f0104a5c:	b8 00 00 00 00       	mov    $0x0,%eax
f0104a61:	eb 05                	jmp    f0104a68 <strnlen+0x36>
f0104a63:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0104a68:	5b                   	pop    %ebx
f0104a69:	5d                   	pop    %ebp
f0104a6a:	c3                   	ret    

f0104a6b <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f0104a6b:	55                   	push   %ebp
f0104a6c:	89 e5                	mov    %esp,%ebp
f0104a6e:	53                   	push   %ebx
f0104a6f:	8b 45 08             	mov    0x8(%ebp),%eax
f0104a72:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0104a75:	89 c2                	mov    %eax,%edx
f0104a77:	83 c2 01             	add    $0x1,%edx
f0104a7a:	83 c1 01             	add    $0x1,%ecx
f0104a7d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0104a81:	88 5a ff             	mov    %bl,-0x1(%edx)
f0104a84:	84 db                	test   %bl,%bl
f0104a86:	75 ef                	jne    f0104a77 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0104a88:	5b                   	pop    %ebx
f0104a89:	5d                   	pop    %ebp
f0104a8a:	c3                   	ret    

f0104a8b <strcat>:

char *
strcat(char *dst, const char *src)
{
f0104a8b:	55                   	push   %ebp
f0104a8c:	89 e5                	mov    %esp,%ebp
f0104a8e:	53                   	push   %ebx
f0104a8f:	83 ec 08             	sub    $0x8,%esp
f0104a92:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f0104a95:	89 1c 24             	mov    %ebx,(%esp)
f0104a98:	e8 73 ff ff ff       	call   f0104a10 <strlen>
	strcpy(dst + len, src);
f0104a9d:	8b 55 0c             	mov    0xc(%ebp),%edx
f0104aa0:	89 54 24 04          	mov    %edx,0x4(%esp)
f0104aa4:	01 d8                	add    %ebx,%eax
f0104aa6:	89 04 24             	mov    %eax,(%esp)
f0104aa9:	e8 bd ff ff ff       	call   f0104a6b <strcpy>
	return dst;
}
f0104aae:	89 d8                	mov    %ebx,%eax
f0104ab0:	83 c4 08             	add    $0x8,%esp
f0104ab3:	5b                   	pop    %ebx
f0104ab4:	5d                   	pop    %ebp
f0104ab5:	c3                   	ret    

f0104ab6 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f0104ab6:	55                   	push   %ebp
f0104ab7:	89 e5                	mov    %esp,%ebp
f0104ab9:	56                   	push   %esi
f0104aba:	53                   	push   %ebx
f0104abb:	8b 75 08             	mov    0x8(%ebp),%esi
f0104abe:	8b 55 0c             	mov    0xc(%ebp),%edx
f0104ac1:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0104ac4:	85 db                	test   %ebx,%ebx
f0104ac6:	74 17                	je     f0104adf <strncpy+0x29>
f0104ac8:	01 f3                	add    %esi,%ebx
f0104aca:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f0104acc:	83 c1 01             	add    $0x1,%ecx
f0104acf:	0f b6 02             	movzbl (%edx),%eax
f0104ad2:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f0104ad5:	80 3a 01             	cmpb   $0x1,(%edx)
f0104ad8:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0104adb:	39 d9                	cmp    %ebx,%ecx
f0104add:	75 ed                	jne    f0104acc <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f0104adf:	89 f0                	mov    %esi,%eax
f0104ae1:	5b                   	pop    %ebx
f0104ae2:	5e                   	pop    %esi
f0104ae3:	5d                   	pop    %ebp
f0104ae4:	c3                   	ret    

f0104ae5 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f0104ae5:	55                   	push   %ebp
f0104ae6:	89 e5                	mov    %esp,%ebp
f0104ae8:	57                   	push   %edi
f0104ae9:	56                   	push   %esi
f0104aea:	53                   	push   %ebx
f0104aeb:	8b 7d 08             	mov    0x8(%ebp),%edi
f0104aee:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0104af1:	8b 75 10             	mov    0x10(%ebp),%esi
f0104af4:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0104af6:	85 f6                	test   %esi,%esi
f0104af8:	74 34                	je     f0104b2e <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f0104afa:	83 fe 01             	cmp    $0x1,%esi
f0104afd:	74 26                	je     f0104b25 <strlcpy+0x40>
f0104aff:	0f b6 0b             	movzbl (%ebx),%ecx
f0104b02:	84 c9                	test   %cl,%cl
f0104b04:	74 23                	je     f0104b29 <strlcpy+0x44>
f0104b06:	83 ee 02             	sub    $0x2,%esi
f0104b09:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f0104b0e:	83 c0 01             	add    $0x1,%eax
f0104b11:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0104b14:	39 f2                	cmp    %esi,%edx
f0104b16:	74 13                	je     f0104b2b <strlcpy+0x46>
f0104b18:	83 c2 01             	add    $0x1,%edx
f0104b1b:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f0104b1f:	84 c9                	test   %cl,%cl
f0104b21:	75 eb                	jne    f0104b0e <strlcpy+0x29>
f0104b23:	eb 06                	jmp    f0104b2b <strlcpy+0x46>
f0104b25:	89 f8                	mov    %edi,%eax
f0104b27:	eb 02                	jmp    f0104b2b <strlcpy+0x46>
f0104b29:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f0104b2b:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f0104b2e:	29 f8                	sub    %edi,%eax
}
f0104b30:	5b                   	pop    %ebx
f0104b31:	5e                   	pop    %esi
f0104b32:	5f                   	pop    %edi
f0104b33:	5d                   	pop    %ebp
f0104b34:	c3                   	ret    

f0104b35 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f0104b35:	55                   	push   %ebp
f0104b36:	89 e5                	mov    %esp,%ebp
f0104b38:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0104b3b:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f0104b3e:	0f b6 01             	movzbl (%ecx),%eax
f0104b41:	84 c0                	test   %al,%al
f0104b43:	74 15                	je     f0104b5a <strcmp+0x25>
f0104b45:	3a 02                	cmp    (%edx),%al
f0104b47:	75 11                	jne    f0104b5a <strcmp+0x25>
		p++, q++;
f0104b49:	83 c1 01             	add    $0x1,%ecx
f0104b4c:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f0104b4f:	0f b6 01             	movzbl (%ecx),%eax
f0104b52:	84 c0                	test   %al,%al
f0104b54:	74 04                	je     f0104b5a <strcmp+0x25>
f0104b56:	3a 02                	cmp    (%edx),%al
f0104b58:	74 ef                	je     f0104b49 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f0104b5a:	0f b6 c0             	movzbl %al,%eax
f0104b5d:	0f b6 12             	movzbl (%edx),%edx
f0104b60:	29 d0                	sub    %edx,%eax
}
f0104b62:	5d                   	pop    %ebp
f0104b63:	c3                   	ret    

f0104b64 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0104b64:	55                   	push   %ebp
f0104b65:	89 e5                	mov    %esp,%ebp
f0104b67:	56                   	push   %esi
f0104b68:	53                   	push   %ebx
f0104b69:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0104b6c:	8b 55 0c             	mov    0xc(%ebp),%edx
f0104b6f:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f0104b72:	85 f6                	test   %esi,%esi
f0104b74:	74 29                	je     f0104b9f <strncmp+0x3b>
f0104b76:	0f b6 03             	movzbl (%ebx),%eax
f0104b79:	84 c0                	test   %al,%al
f0104b7b:	74 30                	je     f0104bad <strncmp+0x49>
f0104b7d:	3a 02                	cmp    (%edx),%al
f0104b7f:	75 2c                	jne    f0104bad <strncmp+0x49>
f0104b81:	8d 43 01             	lea    0x1(%ebx),%eax
f0104b84:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f0104b86:	89 c3                	mov    %eax,%ebx
f0104b88:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f0104b8b:	39 f0                	cmp    %esi,%eax
f0104b8d:	74 17                	je     f0104ba6 <strncmp+0x42>
f0104b8f:	0f b6 08             	movzbl (%eax),%ecx
f0104b92:	84 c9                	test   %cl,%cl
f0104b94:	74 17                	je     f0104bad <strncmp+0x49>
f0104b96:	83 c0 01             	add    $0x1,%eax
f0104b99:	3a 0a                	cmp    (%edx),%cl
f0104b9b:	74 e9                	je     f0104b86 <strncmp+0x22>
f0104b9d:	eb 0e                	jmp    f0104bad <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f0104b9f:	b8 00 00 00 00       	mov    $0x0,%eax
f0104ba4:	eb 0f                	jmp    f0104bb5 <strncmp+0x51>
f0104ba6:	b8 00 00 00 00       	mov    $0x0,%eax
f0104bab:	eb 08                	jmp    f0104bb5 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f0104bad:	0f b6 03             	movzbl (%ebx),%eax
f0104bb0:	0f b6 12             	movzbl (%edx),%edx
f0104bb3:	29 d0                	sub    %edx,%eax
}
f0104bb5:	5b                   	pop    %ebx
f0104bb6:	5e                   	pop    %esi
f0104bb7:	5d                   	pop    %ebp
f0104bb8:	c3                   	ret    

f0104bb9 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f0104bb9:	55                   	push   %ebp
f0104bba:	89 e5                	mov    %esp,%ebp
f0104bbc:	53                   	push   %ebx
f0104bbd:	8b 45 08             	mov    0x8(%ebp),%eax
f0104bc0:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0104bc3:	0f b6 18             	movzbl (%eax),%ebx
f0104bc6:	84 db                	test   %bl,%bl
f0104bc8:	74 1d                	je     f0104be7 <strchr+0x2e>
f0104bca:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0104bcc:	38 d3                	cmp    %dl,%bl
f0104bce:	75 06                	jne    f0104bd6 <strchr+0x1d>
f0104bd0:	eb 1a                	jmp    f0104bec <strchr+0x33>
f0104bd2:	38 ca                	cmp    %cl,%dl
f0104bd4:	74 16                	je     f0104bec <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0104bd6:	83 c0 01             	add    $0x1,%eax
f0104bd9:	0f b6 10             	movzbl (%eax),%edx
f0104bdc:	84 d2                	test   %dl,%dl
f0104bde:	75 f2                	jne    f0104bd2 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0104be0:	b8 00 00 00 00       	mov    $0x0,%eax
f0104be5:	eb 05                	jmp    f0104bec <strchr+0x33>
f0104be7:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0104bec:	5b                   	pop    %ebx
f0104bed:	5d                   	pop    %ebp
f0104bee:	c3                   	ret    

f0104bef <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f0104bef:	55                   	push   %ebp
f0104bf0:	89 e5                	mov    %esp,%ebp
f0104bf2:	53                   	push   %ebx
f0104bf3:	8b 45 08             	mov    0x8(%ebp),%eax
f0104bf6:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0104bf9:	0f b6 18             	movzbl (%eax),%ebx
f0104bfc:	84 db                	test   %bl,%bl
f0104bfe:	74 16                	je     f0104c16 <strfind+0x27>
f0104c00:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0104c02:	38 d3                	cmp    %dl,%bl
f0104c04:	75 06                	jne    f0104c0c <strfind+0x1d>
f0104c06:	eb 0e                	jmp    f0104c16 <strfind+0x27>
f0104c08:	38 ca                	cmp    %cl,%dl
f0104c0a:	74 0a                	je     f0104c16 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f0104c0c:	83 c0 01             	add    $0x1,%eax
f0104c0f:	0f b6 10             	movzbl (%eax),%edx
f0104c12:	84 d2                	test   %dl,%dl
f0104c14:	75 f2                	jne    f0104c08 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f0104c16:	5b                   	pop    %ebx
f0104c17:	5d                   	pop    %ebp
f0104c18:	c3                   	ret    

f0104c19 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f0104c19:	55                   	push   %ebp
f0104c1a:	89 e5                	mov    %esp,%ebp
f0104c1c:	57                   	push   %edi
f0104c1d:	56                   	push   %esi
f0104c1e:	53                   	push   %ebx
f0104c1f:	8b 7d 08             	mov    0x8(%ebp),%edi
f0104c22:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0104c25:	85 c9                	test   %ecx,%ecx
f0104c27:	74 36                	je     f0104c5f <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f0104c29:	f7 c7 03 00 00 00    	test   $0x3,%edi
f0104c2f:	75 28                	jne    f0104c59 <memset+0x40>
f0104c31:	f6 c1 03             	test   $0x3,%cl
f0104c34:	75 23                	jne    f0104c59 <memset+0x40>
		c &= 0xFF;
f0104c36:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f0104c3a:	89 d3                	mov    %edx,%ebx
f0104c3c:	c1 e3 08             	shl    $0x8,%ebx
f0104c3f:	89 d6                	mov    %edx,%esi
f0104c41:	c1 e6 18             	shl    $0x18,%esi
f0104c44:	89 d0                	mov    %edx,%eax
f0104c46:	c1 e0 10             	shl    $0x10,%eax
f0104c49:	09 f0                	or     %esi,%eax
f0104c4b:	09 c2                	or     %eax,%edx
f0104c4d:	89 d0                	mov    %edx,%eax
f0104c4f:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f0104c51:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0104c54:	fc                   	cld    
f0104c55:	f3 ab                	rep stos %eax,%es:(%edi)
f0104c57:	eb 06                	jmp    f0104c5f <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0104c59:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104c5c:	fc                   	cld    
f0104c5d:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f0104c5f:	89 f8                	mov    %edi,%eax
f0104c61:	5b                   	pop    %ebx
f0104c62:	5e                   	pop    %esi
f0104c63:	5f                   	pop    %edi
f0104c64:	5d                   	pop    %ebp
f0104c65:	c3                   	ret    

f0104c66 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0104c66:	55                   	push   %ebp
f0104c67:	89 e5                	mov    %esp,%ebp
f0104c69:	57                   	push   %edi
f0104c6a:	56                   	push   %esi
f0104c6b:	8b 45 08             	mov    0x8(%ebp),%eax
f0104c6e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104c71:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0104c74:	39 c6                	cmp    %eax,%esi
f0104c76:	73 35                	jae    f0104cad <memmove+0x47>
f0104c78:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0104c7b:	39 d0                	cmp    %edx,%eax
f0104c7d:	73 2e                	jae    f0104cad <memmove+0x47>
		s += n;
		d += n;
f0104c7f:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0104c82:	89 d6                	mov    %edx,%esi
f0104c84:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0104c86:	f7 c6 03 00 00 00    	test   $0x3,%esi
f0104c8c:	75 13                	jne    f0104ca1 <memmove+0x3b>
f0104c8e:	f6 c1 03             	test   $0x3,%cl
f0104c91:	75 0e                	jne    f0104ca1 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0104c93:	83 ef 04             	sub    $0x4,%edi
f0104c96:	8d 72 fc             	lea    -0x4(%edx),%esi
f0104c99:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f0104c9c:	fd                   	std    
f0104c9d:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0104c9f:	eb 09                	jmp    f0104caa <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0104ca1:	83 ef 01             	sub    $0x1,%edi
f0104ca4:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0104ca7:	fd                   	std    
f0104ca8:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0104caa:	fc                   	cld    
f0104cab:	eb 1d                	jmp    f0104cca <memmove+0x64>
f0104cad:	89 f2                	mov    %esi,%edx
f0104caf:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0104cb1:	f6 c2 03             	test   $0x3,%dl
f0104cb4:	75 0f                	jne    f0104cc5 <memmove+0x5f>
f0104cb6:	f6 c1 03             	test   $0x3,%cl
f0104cb9:	75 0a                	jne    f0104cc5 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0104cbb:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f0104cbe:	89 c7                	mov    %eax,%edi
f0104cc0:	fc                   	cld    
f0104cc1:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0104cc3:	eb 05                	jmp    f0104cca <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0104cc5:	89 c7                	mov    %eax,%edi
f0104cc7:	fc                   	cld    
f0104cc8:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f0104cca:	5e                   	pop    %esi
f0104ccb:	5f                   	pop    %edi
f0104ccc:	5d                   	pop    %ebp
f0104ccd:	c3                   	ret    

f0104cce <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f0104cce:	55                   	push   %ebp
f0104ccf:	89 e5                	mov    %esp,%ebp
f0104cd1:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0104cd4:	8b 45 10             	mov    0x10(%ebp),%eax
f0104cd7:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104cdb:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104cde:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104ce2:	8b 45 08             	mov    0x8(%ebp),%eax
f0104ce5:	89 04 24             	mov    %eax,(%esp)
f0104ce8:	e8 79 ff ff ff       	call   f0104c66 <memmove>
}
f0104ced:	c9                   	leave  
f0104cee:	c3                   	ret    

f0104cef <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f0104cef:	55                   	push   %ebp
f0104cf0:	89 e5                	mov    %esp,%ebp
f0104cf2:	57                   	push   %edi
f0104cf3:	56                   	push   %esi
f0104cf4:	53                   	push   %ebx
f0104cf5:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0104cf8:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104cfb:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0104cfe:	8d 78 ff             	lea    -0x1(%eax),%edi
f0104d01:	85 c0                	test   %eax,%eax
f0104d03:	74 36                	je     f0104d3b <memcmp+0x4c>
		if (*s1 != *s2)
f0104d05:	0f b6 03             	movzbl (%ebx),%eax
f0104d08:	0f b6 0e             	movzbl (%esi),%ecx
f0104d0b:	ba 00 00 00 00       	mov    $0x0,%edx
f0104d10:	38 c8                	cmp    %cl,%al
f0104d12:	74 1c                	je     f0104d30 <memcmp+0x41>
f0104d14:	eb 10                	jmp    f0104d26 <memcmp+0x37>
f0104d16:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f0104d1b:	83 c2 01             	add    $0x1,%edx
f0104d1e:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f0104d22:	38 c8                	cmp    %cl,%al
f0104d24:	74 0a                	je     f0104d30 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f0104d26:	0f b6 c0             	movzbl %al,%eax
f0104d29:	0f b6 c9             	movzbl %cl,%ecx
f0104d2c:	29 c8                	sub    %ecx,%eax
f0104d2e:	eb 10                	jmp    f0104d40 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0104d30:	39 fa                	cmp    %edi,%edx
f0104d32:	75 e2                	jne    f0104d16 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f0104d34:	b8 00 00 00 00       	mov    $0x0,%eax
f0104d39:	eb 05                	jmp    f0104d40 <memcmp+0x51>
f0104d3b:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0104d40:	5b                   	pop    %ebx
f0104d41:	5e                   	pop    %esi
f0104d42:	5f                   	pop    %edi
f0104d43:	5d                   	pop    %ebp
f0104d44:	c3                   	ret    

f0104d45 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0104d45:	55                   	push   %ebp
f0104d46:	89 e5                	mov    %esp,%ebp
f0104d48:	53                   	push   %ebx
f0104d49:	8b 45 08             	mov    0x8(%ebp),%eax
f0104d4c:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f0104d4f:	89 c2                	mov    %eax,%edx
f0104d51:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0104d54:	39 d0                	cmp    %edx,%eax
f0104d56:	73 13                	jae    f0104d6b <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f0104d58:	89 d9                	mov    %ebx,%ecx
f0104d5a:	38 18                	cmp    %bl,(%eax)
f0104d5c:	75 06                	jne    f0104d64 <memfind+0x1f>
f0104d5e:	eb 0b                	jmp    f0104d6b <memfind+0x26>
f0104d60:	38 08                	cmp    %cl,(%eax)
f0104d62:	74 07                	je     f0104d6b <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f0104d64:	83 c0 01             	add    $0x1,%eax
f0104d67:	39 d0                	cmp    %edx,%eax
f0104d69:	75 f5                	jne    f0104d60 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f0104d6b:	5b                   	pop    %ebx
f0104d6c:	5d                   	pop    %ebp
f0104d6d:	c3                   	ret    

f0104d6e <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f0104d6e:	55                   	push   %ebp
f0104d6f:	89 e5                	mov    %esp,%ebp
f0104d71:	57                   	push   %edi
f0104d72:	56                   	push   %esi
f0104d73:	53                   	push   %ebx
f0104d74:	8b 55 08             	mov    0x8(%ebp),%edx
f0104d77:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0104d7a:	0f b6 0a             	movzbl (%edx),%ecx
f0104d7d:	80 f9 09             	cmp    $0x9,%cl
f0104d80:	74 05                	je     f0104d87 <strtol+0x19>
f0104d82:	80 f9 20             	cmp    $0x20,%cl
f0104d85:	75 10                	jne    f0104d97 <strtol+0x29>
		s++;
f0104d87:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0104d8a:	0f b6 0a             	movzbl (%edx),%ecx
f0104d8d:	80 f9 09             	cmp    $0x9,%cl
f0104d90:	74 f5                	je     f0104d87 <strtol+0x19>
f0104d92:	80 f9 20             	cmp    $0x20,%cl
f0104d95:	74 f0                	je     f0104d87 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f0104d97:	80 f9 2b             	cmp    $0x2b,%cl
f0104d9a:	75 0a                	jne    f0104da6 <strtol+0x38>
		s++;
f0104d9c:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f0104d9f:	bf 00 00 00 00       	mov    $0x0,%edi
f0104da4:	eb 11                	jmp    f0104db7 <strtol+0x49>
f0104da6:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f0104dab:	80 f9 2d             	cmp    $0x2d,%cl
f0104dae:	75 07                	jne    f0104db7 <strtol+0x49>
		s++, neg = 1;
f0104db0:	83 c2 01             	add    $0x1,%edx
f0104db3:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0104db7:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f0104dbc:	75 15                	jne    f0104dd3 <strtol+0x65>
f0104dbe:	80 3a 30             	cmpb   $0x30,(%edx)
f0104dc1:	75 10                	jne    f0104dd3 <strtol+0x65>
f0104dc3:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0104dc7:	75 0a                	jne    f0104dd3 <strtol+0x65>
		s += 2, base = 16;
f0104dc9:	83 c2 02             	add    $0x2,%edx
f0104dcc:	b8 10 00 00 00       	mov    $0x10,%eax
f0104dd1:	eb 10                	jmp    f0104de3 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f0104dd3:	85 c0                	test   %eax,%eax
f0104dd5:	75 0c                	jne    f0104de3 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0104dd7:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0104dd9:	80 3a 30             	cmpb   $0x30,(%edx)
f0104ddc:	75 05                	jne    f0104de3 <strtol+0x75>
		s++, base = 8;
f0104dde:	83 c2 01             	add    $0x1,%edx
f0104de1:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f0104de3:	bb 00 00 00 00       	mov    $0x0,%ebx
f0104de8:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f0104deb:	0f b6 0a             	movzbl (%edx),%ecx
f0104dee:	8d 71 d0             	lea    -0x30(%ecx),%esi
f0104df1:	89 f0                	mov    %esi,%eax
f0104df3:	3c 09                	cmp    $0x9,%al
f0104df5:	77 08                	ja     f0104dff <strtol+0x91>
			dig = *s - '0';
f0104df7:	0f be c9             	movsbl %cl,%ecx
f0104dfa:	83 e9 30             	sub    $0x30,%ecx
f0104dfd:	eb 20                	jmp    f0104e1f <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f0104dff:	8d 71 9f             	lea    -0x61(%ecx),%esi
f0104e02:	89 f0                	mov    %esi,%eax
f0104e04:	3c 19                	cmp    $0x19,%al
f0104e06:	77 08                	ja     f0104e10 <strtol+0xa2>
			dig = *s - 'a' + 10;
f0104e08:	0f be c9             	movsbl %cl,%ecx
f0104e0b:	83 e9 57             	sub    $0x57,%ecx
f0104e0e:	eb 0f                	jmp    f0104e1f <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f0104e10:	8d 71 bf             	lea    -0x41(%ecx),%esi
f0104e13:	89 f0                	mov    %esi,%eax
f0104e15:	3c 19                	cmp    $0x19,%al
f0104e17:	77 16                	ja     f0104e2f <strtol+0xc1>
			dig = *s - 'A' + 10;
f0104e19:	0f be c9             	movsbl %cl,%ecx
f0104e1c:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f0104e1f:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f0104e22:	7d 0f                	jge    f0104e33 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f0104e24:	83 c2 01             	add    $0x1,%edx
f0104e27:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f0104e2b:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f0104e2d:	eb bc                	jmp    f0104deb <strtol+0x7d>
f0104e2f:	89 d8                	mov    %ebx,%eax
f0104e31:	eb 02                	jmp    f0104e35 <strtol+0xc7>
f0104e33:	89 d8                	mov    %ebx,%eax

	if (endptr)
f0104e35:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0104e39:	74 05                	je     f0104e40 <strtol+0xd2>
		*endptr = (char *) s;
f0104e3b:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104e3e:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f0104e40:	f7 d8                	neg    %eax
f0104e42:	85 ff                	test   %edi,%edi
f0104e44:	0f 44 c3             	cmove  %ebx,%eax
}
f0104e47:	5b                   	pop    %ebx
f0104e48:	5e                   	pop    %esi
f0104e49:	5f                   	pop    %edi
f0104e4a:	5d                   	pop    %ebp
f0104e4b:	c3                   	ret    
f0104e4c:	66 90                	xchg   %ax,%ax
f0104e4e:	66 90                	xchg   %ax,%ax

f0104e50 <__udivdi3>:
f0104e50:	55                   	push   %ebp
f0104e51:	57                   	push   %edi
f0104e52:	56                   	push   %esi
f0104e53:	83 ec 0c             	sub    $0xc,%esp
f0104e56:	8b 44 24 28          	mov    0x28(%esp),%eax
f0104e5a:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f0104e5e:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f0104e62:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0104e66:	85 c0                	test   %eax,%eax
f0104e68:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104e6c:	89 ea                	mov    %ebp,%edx
f0104e6e:	89 0c 24             	mov    %ecx,(%esp)
f0104e71:	75 2d                	jne    f0104ea0 <__udivdi3+0x50>
f0104e73:	39 e9                	cmp    %ebp,%ecx
f0104e75:	77 61                	ja     f0104ed8 <__udivdi3+0x88>
f0104e77:	85 c9                	test   %ecx,%ecx
f0104e79:	89 ce                	mov    %ecx,%esi
f0104e7b:	75 0b                	jne    f0104e88 <__udivdi3+0x38>
f0104e7d:	b8 01 00 00 00       	mov    $0x1,%eax
f0104e82:	31 d2                	xor    %edx,%edx
f0104e84:	f7 f1                	div    %ecx
f0104e86:	89 c6                	mov    %eax,%esi
f0104e88:	31 d2                	xor    %edx,%edx
f0104e8a:	89 e8                	mov    %ebp,%eax
f0104e8c:	f7 f6                	div    %esi
f0104e8e:	89 c5                	mov    %eax,%ebp
f0104e90:	89 f8                	mov    %edi,%eax
f0104e92:	f7 f6                	div    %esi
f0104e94:	89 ea                	mov    %ebp,%edx
f0104e96:	83 c4 0c             	add    $0xc,%esp
f0104e99:	5e                   	pop    %esi
f0104e9a:	5f                   	pop    %edi
f0104e9b:	5d                   	pop    %ebp
f0104e9c:	c3                   	ret    
f0104e9d:	8d 76 00             	lea    0x0(%esi),%esi
f0104ea0:	39 e8                	cmp    %ebp,%eax
f0104ea2:	77 24                	ja     f0104ec8 <__udivdi3+0x78>
f0104ea4:	0f bd e8             	bsr    %eax,%ebp
f0104ea7:	83 f5 1f             	xor    $0x1f,%ebp
f0104eaa:	75 3c                	jne    f0104ee8 <__udivdi3+0x98>
f0104eac:	8b 74 24 04          	mov    0x4(%esp),%esi
f0104eb0:	39 34 24             	cmp    %esi,(%esp)
f0104eb3:	0f 86 9f 00 00 00    	jbe    f0104f58 <__udivdi3+0x108>
f0104eb9:	39 d0                	cmp    %edx,%eax
f0104ebb:	0f 82 97 00 00 00    	jb     f0104f58 <__udivdi3+0x108>
f0104ec1:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0104ec8:	31 d2                	xor    %edx,%edx
f0104eca:	31 c0                	xor    %eax,%eax
f0104ecc:	83 c4 0c             	add    $0xc,%esp
f0104ecf:	5e                   	pop    %esi
f0104ed0:	5f                   	pop    %edi
f0104ed1:	5d                   	pop    %ebp
f0104ed2:	c3                   	ret    
f0104ed3:	90                   	nop
f0104ed4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0104ed8:	89 f8                	mov    %edi,%eax
f0104eda:	f7 f1                	div    %ecx
f0104edc:	31 d2                	xor    %edx,%edx
f0104ede:	83 c4 0c             	add    $0xc,%esp
f0104ee1:	5e                   	pop    %esi
f0104ee2:	5f                   	pop    %edi
f0104ee3:	5d                   	pop    %ebp
f0104ee4:	c3                   	ret    
f0104ee5:	8d 76 00             	lea    0x0(%esi),%esi
f0104ee8:	89 e9                	mov    %ebp,%ecx
f0104eea:	8b 3c 24             	mov    (%esp),%edi
f0104eed:	d3 e0                	shl    %cl,%eax
f0104eef:	89 c6                	mov    %eax,%esi
f0104ef1:	b8 20 00 00 00       	mov    $0x20,%eax
f0104ef6:	29 e8                	sub    %ebp,%eax
f0104ef8:	89 c1                	mov    %eax,%ecx
f0104efa:	d3 ef                	shr    %cl,%edi
f0104efc:	89 e9                	mov    %ebp,%ecx
f0104efe:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0104f02:	8b 3c 24             	mov    (%esp),%edi
f0104f05:	09 74 24 08          	or     %esi,0x8(%esp)
f0104f09:	89 d6                	mov    %edx,%esi
f0104f0b:	d3 e7                	shl    %cl,%edi
f0104f0d:	89 c1                	mov    %eax,%ecx
f0104f0f:	89 3c 24             	mov    %edi,(%esp)
f0104f12:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0104f16:	d3 ee                	shr    %cl,%esi
f0104f18:	89 e9                	mov    %ebp,%ecx
f0104f1a:	d3 e2                	shl    %cl,%edx
f0104f1c:	89 c1                	mov    %eax,%ecx
f0104f1e:	d3 ef                	shr    %cl,%edi
f0104f20:	09 d7                	or     %edx,%edi
f0104f22:	89 f2                	mov    %esi,%edx
f0104f24:	89 f8                	mov    %edi,%eax
f0104f26:	f7 74 24 08          	divl   0x8(%esp)
f0104f2a:	89 d6                	mov    %edx,%esi
f0104f2c:	89 c7                	mov    %eax,%edi
f0104f2e:	f7 24 24             	mull   (%esp)
f0104f31:	39 d6                	cmp    %edx,%esi
f0104f33:	89 14 24             	mov    %edx,(%esp)
f0104f36:	72 30                	jb     f0104f68 <__udivdi3+0x118>
f0104f38:	8b 54 24 04          	mov    0x4(%esp),%edx
f0104f3c:	89 e9                	mov    %ebp,%ecx
f0104f3e:	d3 e2                	shl    %cl,%edx
f0104f40:	39 c2                	cmp    %eax,%edx
f0104f42:	73 05                	jae    f0104f49 <__udivdi3+0xf9>
f0104f44:	3b 34 24             	cmp    (%esp),%esi
f0104f47:	74 1f                	je     f0104f68 <__udivdi3+0x118>
f0104f49:	89 f8                	mov    %edi,%eax
f0104f4b:	31 d2                	xor    %edx,%edx
f0104f4d:	e9 7a ff ff ff       	jmp    f0104ecc <__udivdi3+0x7c>
f0104f52:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0104f58:	31 d2                	xor    %edx,%edx
f0104f5a:	b8 01 00 00 00       	mov    $0x1,%eax
f0104f5f:	e9 68 ff ff ff       	jmp    f0104ecc <__udivdi3+0x7c>
f0104f64:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0104f68:	8d 47 ff             	lea    -0x1(%edi),%eax
f0104f6b:	31 d2                	xor    %edx,%edx
f0104f6d:	83 c4 0c             	add    $0xc,%esp
f0104f70:	5e                   	pop    %esi
f0104f71:	5f                   	pop    %edi
f0104f72:	5d                   	pop    %ebp
f0104f73:	c3                   	ret    
f0104f74:	66 90                	xchg   %ax,%ax
f0104f76:	66 90                	xchg   %ax,%ax
f0104f78:	66 90                	xchg   %ax,%ax
f0104f7a:	66 90                	xchg   %ax,%ax
f0104f7c:	66 90                	xchg   %ax,%ax
f0104f7e:	66 90                	xchg   %ax,%ax

f0104f80 <__umoddi3>:
f0104f80:	55                   	push   %ebp
f0104f81:	57                   	push   %edi
f0104f82:	56                   	push   %esi
f0104f83:	83 ec 14             	sub    $0x14,%esp
f0104f86:	8b 44 24 28          	mov    0x28(%esp),%eax
f0104f8a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0104f8e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0104f92:	89 c7                	mov    %eax,%edi
f0104f94:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104f98:	8b 44 24 30          	mov    0x30(%esp),%eax
f0104f9c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0104fa0:	89 34 24             	mov    %esi,(%esp)
f0104fa3:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104fa7:	85 c0                	test   %eax,%eax
f0104fa9:	89 c2                	mov    %eax,%edx
f0104fab:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0104faf:	75 17                	jne    f0104fc8 <__umoddi3+0x48>
f0104fb1:	39 fe                	cmp    %edi,%esi
f0104fb3:	76 4b                	jbe    f0105000 <__umoddi3+0x80>
f0104fb5:	89 c8                	mov    %ecx,%eax
f0104fb7:	89 fa                	mov    %edi,%edx
f0104fb9:	f7 f6                	div    %esi
f0104fbb:	89 d0                	mov    %edx,%eax
f0104fbd:	31 d2                	xor    %edx,%edx
f0104fbf:	83 c4 14             	add    $0x14,%esp
f0104fc2:	5e                   	pop    %esi
f0104fc3:	5f                   	pop    %edi
f0104fc4:	5d                   	pop    %ebp
f0104fc5:	c3                   	ret    
f0104fc6:	66 90                	xchg   %ax,%ax
f0104fc8:	39 f8                	cmp    %edi,%eax
f0104fca:	77 54                	ja     f0105020 <__umoddi3+0xa0>
f0104fcc:	0f bd e8             	bsr    %eax,%ebp
f0104fcf:	83 f5 1f             	xor    $0x1f,%ebp
f0104fd2:	75 5c                	jne    f0105030 <__umoddi3+0xb0>
f0104fd4:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0104fd8:	39 3c 24             	cmp    %edi,(%esp)
f0104fdb:	0f 87 e7 00 00 00    	ja     f01050c8 <__umoddi3+0x148>
f0104fe1:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0104fe5:	29 f1                	sub    %esi,%ecx
f0104fe7:	19 c7                	sbb    %eax,%edi
f0104fe9:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104fed:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0104ff1:	8b 44 24 08          	mov    0x8(%esp),%eax
f0104ff5:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0104ff9:	83 c4 14             	add    $0x14,%esp
f0104ffc:	5e                   	pop    %esi
f0104ffd:	5f                   	pop    %edi
f0104ffe:	5d                   	pop    %ebp
f0104fff:	c3                   	ret    
f0105000:	85 f6                	test   %esi,%esi
f0105002:	89 f5                	mov    %esi,%ebp
f0105004:	75 0b                	jne    f0105011 <__umoddi3+0x91>
f0105006:	b8 01 00 00 00       	mov    $0x1,%eax
f010500b:	31 d2                	xor    %edx,%edx
f010500d:	f7 f6                	div    %esi
f010500f:	89 c5                	mov    %eax,%ebp
f0105011:	8b 44 24 04          	mov    0x4(%esp),%eax
f0105015:	31 d2                	xor    %edx,%edx
f0105017:	f7 f5                	div    %ebp
f0105019:	89 c8                	mov    %ecx,%eax
f010501b:	f7 f5                	div    %ebp
f010501d:	eb 9c                	jmp    f0104fbb <__umoddi3+0x3b>
f010501f:	90                   	nop
f0105020:	89 c8                	mov    %ecx,%eax
f0105022:	89 fa                	mov    %edi,%edx
f0105024:	83 c4 14             	add    $0x14,%esp
f0105027:	5e                   	pop    %esi
f0105028:	5f                   	pop    %edi
f0105029:	5d                   	pop    %ebp
f010502a:	c3                   	ret    
f010502b:	90                   	nop
f010502c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0105030:	8b 04 24             	mov    (%esp),%eax
f0105033:	be 20 00 00 00       	mov    $0x20,%esi
f0105038:	89 e9                	mov    %ebp,%ecx
f010503a:	29 ee                	sub    %ebp,%esi
f010503c:	d3 e2                	shl    %cl,%edx
f010503e:	89 f1                	mov    %esi,%ecx
f0105040:	d3 e8                	shr    %cl,%eax
f0105042:	89 e9                	mov    %ebp,%ecx
f0105044:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105048:	8b 04 24             	mov    (%esp),%eax
f010504b:	09 54 24 04          	or     %edx,0x4(%esp)
f010504f:	89 fa                	mov    %edi,%edx
f0105051:	d3 e0                	shl    %cl,%eax
f0105053:	89 f1                	mov    %esi,%ecx
f0105055:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105059:	8b 44 24 10          	mov    0x10(%esp),%eax
f010505d:	d3 ea                	shr    %cl,%edx
f010505f:	89 e9                	mov    %ebp,%ecx
f0105061:	d3 e7                	shl    %cl,%edi
f0105063:	89 f1                	mov    %esi,%ecx
f0105065:	d3 e8                	shr    %cl,%eax
f0105067:	89 e9                	mov    %ebp,%ecx
f0105069:	09 f8                	or     %edi,%eax
f010506b:	8b 7c 24 10          	mov    0x10(%esp),%edi
f010506f:	f7 74 24 04          	divl   0x4(%esp)
f0105073:	d3 e7                	shl    %cl,%edi
f0105075:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0105079:	89 d7                	mov    %edx,%edi
f010507b:	f7 64 24 08          	mull   0x8(%esp)
f010507f:	39 d7                	cmp    %edx,%edi
f0105081:	89 c1                	mov    %eax,%ecx
f0105083:	89 14 24             	mov    %edx,(%esp)
f0105086:	72 2c                	jb     f01050b4 <__umoddi3+0x134>
f0105088:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f010508c:	72 22                	jb     f01050b0 <__umoddi3+0x130>
f010508e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0105092:	29 c8                	sub    %ecx,%eax
f0105094:	19 d7                	sbb    %edx,%edi
f0105096:	89 e9                	mov    %ebp,%ecx
f0105098:	89 fa                	mov    %edi,%edx
f010509a:	d3 e8                	shr    %cl,%eax
f010509c:	89 f1                	mov    %esi,%ecx
f010509e:	d3 e2                	shl    %cl,%edx
f01050a0:	89 e9                	mov    %ebp,%ecx
f01050a2:	d3 ef                	shr    %cl,%edi
f01050a4:	09 d0                	or     %edx,%eax
f01050a6:	89 fa                	mov    %edi,%edx
f01050a8:	83 c4 14             	add    $0x14,%esp
f01050ab:	5e                   	pop    %esi
f01050ac:	5f                   	pop    %edi
f01050ad:	5d                   	pop    %ebp
f01050ae:	c3                   	ret    
f01050af:	90                   	nop
f01050b0:	39 d7                	cmp    %edx,%edi
f01050b2:	75 da                	jne    f010508e <__umoddi3+0x10e>
f01050b4:	8b 14 24             	mov    (%esp),%edx
f01050b7:	89 c1                	mov    %eax,%ecx
f01050b9:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f01050bd:	1b 54 24 04          	sbb    0x4(%esp),%edx
f01050c1:	eb cb                	jmp    f010508e <__umoddi3+0x10e>
f01050c3:	90                   	nop
f01050c4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01050c8:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f01050cc:	0f 82 0f ff ff ff    	jb     f0104fe1 <__umoddi3+0x61>
f01050d2:	e9 1a ff ff ff       	jmp    f0104ff1 <__umoddi3+0x71>
