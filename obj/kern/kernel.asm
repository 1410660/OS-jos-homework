
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
	# until we set up our real page table in i386_vm_init in lab 2.

	# Load the physical address of entry_pgdir into cr3.  entry_pgdir
	# is defined in entrypgdir.c.
	movl	$(RELOC(entry_pgdir)), %eax
f0100015:	b8 00 00 11 00       	mov    $0x110000,%eax
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
f0100034:	bc 00 00 11 f0       	mov    $0xf0110000,%esp

	# now to C code
	call	i386_init
f0100039:	e8 5f 00 00 00       	call   f010009d <i386_init>

f010003e <spin>:

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <test_backtrace>:
#include <kern/console.h>

// Test the stack backtrace function (lab 1 only)
void
test_backtrace(int x)
{
f0100040:	55                   	push   %ebp
f0100041:	89 e5                	mov    %esp,%ebp
f0100043:	53                   	push   %ebx
f0100044:	83 ec 14             	sub    $0x14,%esp
f0100047:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("entering test_backtrace %d\n", x);
f010004a:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010004e:	c7 04 24 c0 19 10 f0 	movl   $0xf01019c0,(%esp)
f0100055:	e8 f5 08 00 00       	call   f010094f <cprintf>
	if (x > 0)
f010005a:	85 db                	test   %ebx,%ebx
f010005c:	7e 0d                	jle    f010006b <test_backtrace+0x2b>
		test_backtrace(x-1);
f010005e:	8d 43 ff             	lea    -0x1(%ebx),%eax
f0100061:	89 04 24             	mov    %eax,(%esp)
f0100064:	e8 d7 ff ff ff       	call   f0100040 <test_backtrace>
f0100069:	eb 1c                	jmp    f0100087 <test_backtrace+0x47>
	else
		mon_backtrace(0, 0, 0);
f010006b:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0100072:	00 
f0100073:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010007a:	00 
f010007b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0100082:	e8 27 07 00 00       	call   f01007ae <mon_backtrace>
	cprintf("leaving test_backtrace %d\n", x);
f0100087:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010008b:	c7 04 24 dc 19 10 f0 	movl   $0xf01019dc,(%esp)
f0100092:	e8 b8 08 00 00       	call   f010094f <cprintf>
}
f0100097:	83 c4 14             	add    $0x14,%esp
f010009a:	5b                   	pop    %ebx
f010009b:	5d                   	pop    %ebp
f010009c:	c3                   	ret    

f010009d <i386_init>:

void
i386_init(void)
{
f010009d:	55                   	push   %ebp
f010009e:	89 e5                	mov    %esp,%ebp
f01000a0:	83 ec 18             	sub    $0x18,%esp
	extern char edata[], end[];

	// Before doing anything else, complete the ELF loading process.
	// Clear the uninitialized global data (BSS) section of our program.
	// This ensures that all static/global variables start out zero.
	memset(edata, 0, end - edata);
f01000a3:	b8 60 29 11 f0       	mov    $0xf0112960,%eax
f01000a8:	2d 00 23 11 f0       	sub    $0xf0112300,%eax
f01000ad:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000b1:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01000b8:	00 
f01000b9:	c7 04 24 00 23 11 f0 	movl   $0xf0112300,(%esp)
f01000c0:	e8 2a 14 00 00       	call   f01014ef <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000c5:	e8 a5 04 00 00       	call   f010056f <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000ca:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000d1:	00 
f01000d2:	c7 04 24 f7 19 10 f0 	movl   $0xf01019f7,(%esp)
f01000d9:	e8 71 08 00 00       	call   f010094f <cprintf>

	// Test the stack backtrace function (lab 1 only)
	test_backtrace(5);
f01000de:	c7 04 24 05 00 00 00 	movl   $0x5,(%esp)
f01000e5:	e8 56 ff ff ff       	call   f0100040 <test_backtrace>

	// Drop into the kernel monitor.
	while (1)
		monitor(NULL);
f01000ea:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000f1:	e8 c2 06 00 00       	call   f01007b8 <monitor>
f01000f6:	eb f2                	jmp    f01000ea <i386_init+0x4d>

f01000f8 <_panic>:
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void
_panic(const char *file, int line, const char *fmt,...)
{
f01000f8:	55                   	push   %ebp
f01000f9:	89 e5                	mov    %esp,%ebp
f01000fb:	56                   	push   %esi
f01000fc:	53                   	push   %ebx
f01000fd:	83 ec 10             	sub    $0x10,%esp
f0100100:	8b 75 10             	mov    0x10(%ebp),%esi
	va_list ap;

	if (panicstr)
f0100103:	83 3d 00 23 11 f0 00 	cmpl   $0x0,0xf0112300
f010010a:	75 3d                	jne    f0100149 <_panic+0x51>
		goto dead;
	panicstr = fmt;
f010010c:	89 35 00 23 11 f0    	mov    %esi,0xf0112300

	// Be extra sure that the machine is in as reasonable state
	__asm __volatile("cli; cld");
f0100112:	fa                   	cli    
f0100113:	fc                   	cld    

	va_start(ap, fmt);
f0100114:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic at %s:%d: ", file, line);
f0100117:	8b 45 0c             	mov    0xc(%ebp),%eax
f010011a:	89 44 24 08          	mov    %eax,0x8(%esp)
f010011e:	8b 45 08             	mov    0x8(%ebp),%eax
f0100121:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100125:	c7 04 24 12 1a 10 f0 	movl   $0xf0101a12,(%esp)
f010012c:	e8 1e 08 00 00       	call   f010094f <cprintf>
	vcprintf(fmt, ap);
f0100131:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100135:	89 34 24             	mov    %esi,(%esp)
f0100138:	e8 df 07 00 00       	call   f010091c <vcprintf>
	cprintf("\n");
f010013d:	c7 04 24 4e 1a 10 f0 	movl   $0xf0101a4e,(%esp)
f0100144:	e8 06 08 00 00       	call   f010094f <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f0100149:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0100150:	e8 63 06 00 00       	call   f01007b8 <monitor>
f0100155:	eb f2                	jmp    f0100149 <_panic+0x51>

f0100157 <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f0100157:	55                   	push   %ebp
f0100158:	89 e5                	mov    %esp,%ebp
f010015a:	53                   	push   %ebx
f010015b:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f010015e:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f0100161:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100164:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100168:	8b 45 08             	mov    0x8(%ebp),%eax
f010016b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010016f:	c7 04 24 2a 1a 10 f0 	movl   $0xf0101a2a,(%esp)
f0100176:	e8 d4 07 00 00       	call   f010094f <cprintf>
	vcprintf(fmt, ap);
f010017b:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010017f:	8b 45 10             	mov    0x10(%ebp),%eax
f0100182:	89 04 24             	mov    %eax,(%esp)
f0100185:	e8 92 07 00 00       	call   f010091c <vcprintf>
	cprintf("\n");
f010018a:	c7 04 24 4e 1a 10 f0 	movl   $0xf0101a4e,(%esp)
f0100191:	e8 b9 07 00 00       	call   f010094f <cprintf>
	va_end(ap);
}
f0100196:	83 c4 14             	add    $0x14,%esp
f0100199:	5b                   	pop    %ebx
f010019a:	5d                   	pop    %ebp
f010019b:	c3                   	ret    
f010019c:	66 90                	xchg   %ax,%ax
f010019e:	66 90                	xchg   %ax,%ax

f01001a0 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f01001a0:	55                   	push   %ebp
f01001a1:	89 e5                	mov    %esp,%ebp

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01001a3:	ba fd 03 00 00       	mov    $0x3fd,%edx
f01001a8:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f01001a9:	a8 01                	test   $0x1,%al
f01001ab:	74 08                	je     f01001b5 <serial_proc_data+0x15>
f01001ad:	b2 f8                	mov    $0xf8,%dl
f01001af:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f01001b0:	0f b6 c0             	movzbl %al,%eax
f01001b3:	eb 05                	jmp    f01001ba <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f01001b5:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f01001ba:	5d                   	pop    %ebp
f01001bb:	c3                   	ret    

f01001bc <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f01001bc:	55                   	push   %ebp
f01001bd:	89 e5                	mov    %esp,%ebp
f01001bf:	53                   	push   %ebx
f01001c0:	83 ec 04             	sub    $0x4,%esp
f01001c3:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f01001c5:	eb 2a                	jmp    f01001f1 <cons_intr+0x35>
		if (c == 0)
f01001c7:	85 d2                	test   %edx,%edx
f01001c9:	74 26                	je     f01001f1 <cons_intr+0x35>
			continue;
		cons.buf[cons.wpos++] = c;
f01001cb:	a1 44 25 11 f0       	mov    0xf0112544,%eax
f01001d0:	8d 48 01             	lea    0x1(%eax),%ecx
f01001d3:	89 0d 44 25 11 f0    	mov    %ecx,0xf0112544
f01001d9:	88 90 40 23 11 f0    	mov    %dl,-0xfeedcc0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f01001df:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f01001e5:	75 0a                	jne    f01001f1 <cons_intr+0x35>
			cons.wpos = 0;
f01001e7:	c7 05 44 25 11 f0 00 	movl   $0x0,0xf0112544
f01001ee:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f01001f1:	ff d3                	call   *%ebx
f01001f3:	89 c2                	mov    %eax,%edx
f01001f5:	83 f8 ff             	cmp    $0xffffffff,%eax
f01001f8:	75 cd                	jne    f01001c7 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f01001fa:	83 c4 04             	add    $0x4,%esp
f01001fd:	5b                   	pop    %ebx
f01001fe:	5d                   	pop    %ebp
f01001ff:	c3                   	ret    

f0100200 <kbd_proc_data>:
f0100200:	ba 64 00 00 00       	mov    $0x64,%edx
f0100205:	ec                   	in     (%dx),%al
{
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
f0100206:	a8 01                	test   $0x1,%al
f0100208:	0f 84 ef 00 00 00    	je     f01002fd <kbd_proc_data+0xfd>
f010020e:	b2 60                	mov    $0x60,%dl
f0100210:	ec                   	in     (%dx),%al
f0100211:	89 c2                	mov    %eax,%edx
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f0100213:	3c e0                	cmp    $0xe0,%al
f0100215:	75 0d                	jne    f0100224 <kbd_proc_data+0x24>
		// E0 escape character
		shift |= E0ESC;
f0100217:	83 0d 20 23 11 f0 40 	orl    $0x40,0xf0112320
		return 0;
f010021e:	b8 00 00 00 00       	mov    $0x0,%eax
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100223:	c3                   	ret    
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f0100224:	55                   	push   %ebp
f0100225:	89 e5                	mov    %esp,%ebp
f0100227:	53                   	push   %ebx
f0100228:	83 ec 14             	sub    $0x14,%esp

	if (data == 0xE0) {
		// E0 escape character
		shift |= E0ESC;
		return 0;
	} else if (data & 0x80) {
f010022b:	84 c0                	test   %al,%al
f010022d:	79 37                	jns    f0100266 <kbd_proc_data+0x66>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f010022f:	8b 0d 20 23 11 f0    	mov    0xf0112320,%ecx
f0100235:	89 cb                	mov    %ecx,%ebx
f0100237:	83 e3 40             	and    $0x40,%ebx
f010023a:	83 e0 7f             	and    $0x7f,%eax
f010023d:	85 db                	test   %ebx,%ebx
f010023f:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f0100242:	0f b6 d2             	movzbl %dl,%edx
f0100245:	0f b6 82 a0 1b 10 f0 	movzbl -0xfefe460(%edx),%eax
f010024c:	83 c8 40             	or     $0x40,%eax
f010024f:	0f b6 c0             	movzbl %al,%eax
f0100252:	f7 d0                	not    %eax
f0100254:	21 c1                	and    %eax,%ecx
f0100256:	89 0d 20 23 11 f0    	mov    %ecx,0xf0112320
		return 0;
f010025c:	b8 00 00 00 00       	mov    $0x0,%eax
f0100261:	e9 9d 00 00 00       	jmp    f0100303 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f0100266:	8b 0d 20 23 11 f0    	mov    0xf0112320,%ecx
f010026c:	f6 c1 40             	test   $0x40,%cl
f010026f:	74 0e                	je     f010027f <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f0100271:	83 c8 80             	or     $0xffffff80,%eax
f0100274:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f0100276:	83 e1 bf             	and    $0xffffffbf,%ecx
f0100279:	89 0d 20 23 11 f0    	mov    %ecx,0xf0112320
	}

	shift |= shiftcode[data];
f010027f:	0f b6 d2             	movzbl %dl,%edx
f0100282:	0f b6 82 a0 1b 10 f0 	movzbl -0xfefe460(%edx),%eax
f0100289:	0b 05 20 23 11 f0    	or     0xf0112320,%eax
	shift ^= togglecode[data];
f010028f:	0f b6 8a a0 1a 10 f0 	movzbl -0xfefe560(%edx),%ecx
f0100296:	31 c8                	xor    %ecx,%eax
f0100298:	a3 20 23 11 f0       	mov    %eax,0xf0112320

	c = charcode[shift & (CTL | SHIFT)][data];
f010029d:	89 c1                	mov    %eax,%ecx
f010029f:	83 e1 03             	and    $0x3,%ecx
f01002a2:	8b 0c 8d 80 1a 10 f0 	mov    -0xfefe580(,%ecx,4),%ecx
f01002a9:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f01002ad:	0f b6 da             	movzbl %dl,%ebx
	if (shift & CAPSLOCK) {
f01002b0:	a8 08                	test   $0x8,%al
f01002b2:	74 1b                	je     f01002cf <kbd_proc_data+0xcf>
		if ('a' <= c && c <= 'z')
f01002b4:	89 da                	mov    %ebx,%edx
f01002b6:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f01002b9:	83 f9 19             	cmp    $0x19,%ecx
f01002bc:	77 05                	ja     f01002c3 <kbd_proc_data+0xc3>
			c += 'A' - 'a';
f01002be:	83 eb 20             	sub    $0x20,%ebx
f01002c1:	eb 0c                	jmp    f01002cf <kbd_proc_data+0xcf>
		else if ('A' <= c && c <= 'Z')
f01002c3:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f01002c6:	8d 4b 20             	lea    0x20(%ebx),%ecx
f01002c9:	83 fa 19             	cmp    $0x19,%edx
f01002cc:	0f 46 d9             	cmovbe %ecx,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f01002cf:	f7 d0                	not    %eax
f01002d1:	89 c2                	mov    %eax,%edx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f01002d3:	89 d8                	mov    %ebx,%eax
			c += 'a' - 'A';
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f01002d5:	f6 c2 06             	test   $0x6,%dl
f01002d8:	75 29                	jne    f0100303 <kbd_proc_data+0x103>
f01002da:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f01002e0:	75 21                	jne    f0100303 <kbd_proc_data+0x103>
		cprintf("Rebooting!\n");
f01002e2:	c7 04 24 44 1a 10 f0 	movl   $0xf0101a44,(%esp)
f01002e9:	e8 61 06 00 00       	call   f010094f <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01002ee:	ba 92 00 00 00       	mov    $0x92,%edx
f01002f3:	b8 03 00 00 00       	mov    $0x3,%eax
f01002f8:	ee                   	out    %al,(%dx)
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f01002f9:	89 d8                	mov    %ebx,%eax
f01002fb:	eb 06                	jmp    f0100303 <kbd_proc_data+0x103>
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
		return -1;
f01002fd:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100302:	c3                   	ret    
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100303:	83 c4 14             	add    $0x14,%esp
f0100306:	5b                   	pop    %ebx
f0100307:	5d                   	pop    %ebp
f0100308:	c3                   	ret    

f0100309 <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f0100309:	55                   	push   %ebp
f010030a:	89 e5                	mov    %esp,%ebp
f010030c:	57                   	push   %edi
f010030d:	56                   	push   %esi
f010030e:	53                   	push   %ebx
f010030f:	83 ec 1c             	sub    $0x1c,%esp
f0100312:	89 c7                	mov    %eax,%edi

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100314:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100319:	ec                   	in     (%dx),%al
static void
serial_putc(int c)
{
	int i;
	
	for (i = 0;
f010031a:	a8 20                	test   $0x20,%al
f010031c:	75 21                	jne    f010033f <cons_putc+0x36>
f010031e:	bb 00 32 00 00       	mov    $0x3200,%ebx
f0100323:	b9 84 00 00 00       	mov    $0x84,%ecx
f0100328:	be fd 03 00 00       	mov    $0x3fd,%esi
f010032d:	89 ca                	mov    %ecx,%edx
f010032f:	ec                   	in     (%dx),%al
f0100330:	ec                   	in     (%dx),%al
f0100331:	ec                   	in     (%dx),%al
f0100332:	ec                   	in     (%dx),%al
f0100333:	89 f2                	mov    %esi,%edx
f0100335:	ec                   	in     (%dx),%al
f0100336:	a8 20                	test   $0x20,%al
f0100338:	75 05                	jne    f010033f <cons_putc+0x36>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f010033a:	83 eb 01             	sub    $0x1,%ebx
f010033d:	75 ee                	jne    f010032d <cons_putc+0x24>
	     i++)
		delay();
	
	outb(COM1 + COM_TX, c);
f010033f:	89 f8                	mov    %edi,%eax
f0100341:	0f b6 c0             	movzbl %al,%eax
f0100344:	89 45 e4             	mov    %eax,-0x1c(%ebp)
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100347:	ba f8 03 00 00       	mov    $0x3f8,%edx
f010034c:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010034d:	b2 79                	mov    $0x79,%dl
f010034f:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f0100350:	84 c0                	test   %al,%al
f0100352:	78 21                	js     f0100375 <cons_putc+0x6c>
f0100354:	bb 00 32 00 00       	mov    $0x3200,%ebx
f0100359:	b9 84 00 00 00       	mov    $0x84,%ecx
f010035e:	be 79 03 00 00       	mov    $0x379,%esi
f0100363:	89 ca                	mov    %ecx,%edx
f0100365:	ec                   	in     (%dx),%al
f0100366:	ec                   	in     (%dx),%al
f0100367:	ec                   	in     (%dx),%al
f0100368:	ec                   	in     (%dx),%al
f0100369:	89 f2                	mov    %esi,%edx
f010036b:	ec                   	in     (%dx),%al
f010036c:	84 c0                	test   %al,%al
f010036e:	78 05                	js     f0100375 <cons_putc+0x6c>
f0100370:	83 eb 01             	sub    $0x1,%ebx
f0100373:	75 ee                	jne    f0100363 <cons_putc+0x5a>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100375:	ba 78 03 00 00       	mov    $0x378,%edx
f010037a:	0f b6 45 e4          	movzbl -0x1c(%ebp),%eax
f010037e:	ee                   	out    %al,(%dx)
f010037f:	b2 7a                	mov    $0x7a,%dl
f0100381:	b8 0d 00 00 00       	mov    $0xd,%eax
f0100386:	ee                   	out    %al,(%dx)
f0100387:	b8 08 00 00 00       	mov    $0x8,%eax
f010038c:	ee                   	out    %al,(%dx)

static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f010038d:	89 fa                	mov    %edi,%edx
f010038f:	81 e2 00 ff ff ff    	and    $0xffffff00,%edx
		c |= 0x0700;
f0100395:	89 f8                	mov    %edi,%eax
f0100397:	80 cc 07             	or     $0x7,%ah
f010039a:	85 d2                	test   %edx,%edx
f010039c:	0f 44 f8             	cmove  %eax,%edi

	switch (c & 0xff) {
f010039f:	89 f8                	mov    %edi,%eax
f01003a1:	0f b6 c0             	movzbl %al,%eax
f01003a4:	83 f8 09             	cmp    $0x9,%eax
f01003a7:	74 79                	je     f0100422 <cons_putc+0x119>
f01003a9:	83 f8 09             	cmp    $0x9,%eax
f01003ac:	7f 0a                	jg     f01003b8 <cons_putc+0xaf>
f01003ae:	83 f8 08             	cmp    $0x8,%eax
f01003b1:	74 19                	je     f01003cc <cons_putc+0xc3>
f01003b3:	e9 9e 00 00 00       	jmp    f0100456 <cons_putc+0x14d>
f01003b8:	83 f8 0a             	cmp    $0xa,%eax
f01003bb:	90                   	nop
f01003bc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01003c0:	74 3a                	je     f01003fc <cons_putc+0xf3>
f01003c2:	83 f8 0d             	cmp    $0xd,%eax
f01003c5:	74 3d                	je     f0100404 <cons_putc+0xfb>
f01003c7:	e9 8a 00 00 00       	jmp    f0100456 <cons_putc+0x14d>
	case '\b':
		if (crt_pos > 0) {
f01003cc:	0f b7 05 48 25 11 f0 	movzwl 0xf0112548,%eax
f01003d3:	66 85 c0             	test   %ax,%ax
f01003d6:	0f 84 e5 00 00 00    	je     f01004c1 <cons_putc+0x1b8>
			crt_pos--;
f01003dc:	83 e8 01             	sub    $0x1,%eax
f01003df:	66 a3 48 25 11 f0    	mov    %ax,0xf0112548
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f01003e5:	0f b7 c0             	movzwl %ax,%eax
f01003e8:	66 81 e7 00 ff       	and    $0xff00,%di
f01003ed:	83 cf 20             	or     $0x20,%edi
f01003f0:	8b 15 4c 25 11 f0    	mov    0xf011254c,%edx
f01003f6:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f01003fa:	eb 78                	jmp    f0100474 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f01003fc:	66 83 05 48 25 11 f0 	addw   $0x50,0xf0112548
f0100403:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f0100404:	0f b7 05 48 25 11 f0 	movzwl 0xf0112548,%eax
f010040b:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100411:	c1 e8 16             	shr    $0x16,%eax
f0100414:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0100417:	c1 e0 04             	shl    $0x4,%eax
f010041a:	66 a3 48 25 11 f0    	mov    %ax,0xf0112548
f0100420:	eb 52                	jmp    f0100474 <cons_putc+0x16b>
		break;
	case '\t':
		cons_putc(' ');
f0100422:	b8 20 00 00 00       	mov    $0x20,%eax
f0100427:	e8 dd fe ff ff       	call   f0100309 <cons_putc>
		cons_putc(' ');
f010042c:	b8 20 00 00 00       	mov    $0x20,%eax
f0100431:	e8 d3 fe ff ff       	call   f0100309 <cons_putc>
		cons_putc(' ');
f0100436:	b8 20 00 00 00       	mov    $0x20,%eax
f010043b:	e8 c9 fe ff ff       	call   f0100309 <cons_putc>
		cons_putc(' ');
f0100440:	b8 20 00 00 00       	mov    $0x20,%eax
f0100445:	e8 bf fe ff ff       	call   f0100309 <cons_putc>
		cons_putc(' ');
f010044a:	b8 20 00 00 00       	mov    $0x20,%eax
f010044f:	e8 b5 fe ff ff       	call   f0100309 <cons_putc>
f0100454:	eb 1e                	jmp    f0100474 <cons_putc+0x16b>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f0100456:	0f b7 05 48 25 11 f0 	movzwl 0xf0112548,%eax
f010045d:	8d 50 01             	lea    0x1(%eax),%edx
f0100460:	66 89 15 48 25 11 f0 	mov    %dx,0xf0112548
f0100467:	0f b7 c0             	movzwl %ax,%eax
f010046a:	8b 15 4c 25 11 f0    	mov    0xf011254c,%edx
f0100470:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f0100474:	66 81 3d 48 25 11 f0 	cmpw   $0x7cf,0xf0112548
f010047b:	cf 07 
f010047d:	76 42                	jbe    f01004c1 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f010047f:	a1 4c 25 11 f0       	mov    0xf011254c,%eax
f0100484:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010048b:	00 
f010048c:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100492:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100496:	89 04 24             	mov    %eax,(%esp)
f0100499:	e8 9e 10 00 00       	call   f010153c <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010049e:	8b 15 4c 25 11 f0    	mov    0xf011254c,%edx
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f01004a4:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f01004a9:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f01004af:	83 c0 01             	add    $0x1,%eax
f01004b2:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f01004b7:	75 f0                	jne    f01004a9 <cons_putc+0x1a0>
			crt_buf[i] = 0x0700 | ' ';
		crt_pos -= CRT_COLS;
f01004b9:	66 83 2d 48 25 11 f0 	subw   $0x50,0xf0112548
f01004c0:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f01004c1:	8b 0d 50 25 11 f0    	mov    0xf0112550,%ecx
f01004c7:	b8 0e 00 00 00       	mov    $0xe,%eax
f01004cc:	89 ca                	mov    %ecx,%edx
f01004ce:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f01004cf:	0f b7 1d 48 25 11 f0 	movzwl 0xf0112548,%ebx
f01004d6:	8d 71 01             	lea    0x1(%ecx),%esi
f01004d9:	89 d8                	mov    %ebx,%eax
f01004db:	66 c1 e8 08          	shr    $0x8,%ax
f01004df:	89 f2                	mov    %esi,%edx
f01004e1:	ee                   	out    %al,(%dx)
f01004e2:	b8 0f 00 00 00       	mov    $0xf,%eax
f01004e7:	89 ca                	mov    %ecx,%edx
f01004e9:	ee                   	out    %al,(%dx)
f01004ea:	89 d8                	mov    %ebx,%eax
f01004ec:	89 f2                	mov    %esi,%edx
f01004ee:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f01004ef:	83 c4 1c             	add    $0x1c,%esp
f01004f2:	5b                   	pop    %ebx
f01004f3:	5e                   	pop    %esi
f01004f4:	5f                   	pop    %edi
f01004f5:	5d                   	pop    %ebp
f01004f6:	c3                   	ret    

f01004f7 <serial_intr>:
}

void
serial_intr(void)
{
	if (serial_exists)
f01004f7:	83 3d 54 25 11 f0 00 	cmpl   $0x0,0xf0112554
f01004fe:	74 11                	je     f0100511 <serial_intr+0x1a>
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f0100500:	55                   	push   %ebp
f0100501:	89 e5                	mov    %esp,%ebp
f0100503:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
		cons_intr(serial_proc_data);
f0100506:	b8 a0 01 10 f0       	mov    $0xf01001a0,%eax
f010050b:	e8 ac fc ff ff       	call   f01001bc <cons_intr>
}
f0100510:	c9                   	leave  
f0100511:	f3 c3                	repz ret 

f0100513 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f0100513:	55                   	push   %ebp
f0100514:	89 e5                	mov    %esp,%ebp
f0100516:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f0100519:	b8 00 02 10 f0       	mov    $0xf0100200,%eax
f010051e:	e8 99 fc ff ff       	call   f01001bc <cons_intr>
}
f0100523:	c9                   	leave  
f0100524:	c3                   	ret    

f0100525 <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f0100525:	55                   	push   %ebp
f0100526:	89 e5                	mov    %esp,%ebp
f0100528:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f010052b:	e8 c7 ff ff ff       	call   f01004f7 <serial_intr>
	kbd_intr();
f0100530:	e8 de ff ff ff       	call   f0100513 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f0100535:	a1 40 25 11 f0       	mov    0xf0112540,%eax
f010053a:	3b 05 44 25 11 f0    	cmp    0xf0112544,%eax
f0100540:	74 26                	je     f0100568 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f0100542:	8d 50 01             	lea    0x1(%eax),%edx
f0100545:	89 15 40 25 11 f0    	mov    %edx,0xf0112540
f010054b:	0f b6 88 40 23 11 f0 	movzbl -0xfeedcc0(%eax),%ecx
		if (cons.rpos == CONSBUFSIZE)
			cons.rpos = 0;
		return c;
f0100552:	89 c8                	mov    %ecx,%eax
	kbd_intr();

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
		c = cons.buf[cons.rpos++];
		if (cons.rpos == CONSBUFSIZE)
f0100554:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f010055a:	75 11                	jne    f010056d <cons_getc+0x48>
			cons.rpos = 0;
f010055c:	c7 05 40 25 11 f0 00 	movl   $0x0,0xf0112540
f0100563:	00 00 00 
f0100566:	eb 05                	jmp    f010056d <cons_getc+0x48>
		return c;
	}
	return 0;
f0100568:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010056d:	c9                   	leave  
f010056e:	c3                   	ret    

f010056f <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f010056f:	55                   	push   %ebp
f0100570:	89 e5                	mov    %esp,%ebp
f0100572:	57                   	push   %edi
f0100573:	56                   	push   %esi
f0100574:	53                   	push   %ebx
f0100575:	83 ec 1c             	sub    $0x1c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f0100578:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f010057f:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f0100586:	5a a5 
	if (*cp != 0xA55A) {
f0100588:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f010058f:	66 3d 5a a5          	cmp    $0xa55a,%ax
f0100593:	74 11                	je     f01005a6 <cons_init+0x37>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f0100595:	c7 05 50 25 11 f0 b4 	movl   $0x3b4,0xf0112550
f010059c:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f010059f:	bf 00 00 0b f0       	mov    $0xf00b0000,%edi
f01005a4:	eb 16                	jmp    f01005bc <cons_init+0x4d>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f01005a6:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f01005ad:	c7 05 50 25 11 f0 d4 	movl   $0x3d4,0xf0112550
f01005b4:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f01005b7:	bf 00 80 0b f0       	mov    $0xf00b8000,%edi
		*cp = was;
		addr_6845 = CGA_BASE;
	}
	
	/* Extract cursor location */
	outb(addr_6845, 14);
f01005bc:	8b 0d 50 25 11 f0    	mov    0xf0112550,%ecx
f01005c2:	b8 0e 00 00 00       	mov    $0xe,%eax
f01005c7:	89 ca                	mov    %ecx,%edx
f01005c9:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f01005ca:	8d 59 01             	lea    0x1(%ecx),%ebx

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01005cd:	89 da                	mov    %ebx,%edx
f01005cf:	ec                   	in     (%dx),%al
f01005d0:	0f b6 f0             	movzbl %al,%esi
f01005d3:	c1 e6 08             	shl    $0x8,%esi
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01005d6:	b8 0f 00 00 00       	mov    $0xf,%eax
f01005db:	89 ca                	mov    %ecx,%edx
f01005dd:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01005de:	89 da                	mov    %ebx,%edx
f01005e0:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f01005e1:	89 3d 4c 25 11 f0    	mov    %edi,0xf011254c
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f01005e7:	0f b6 d8             	movzbl %al,%ebx
f01005ea:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f01005ec:	66 89 35 48 25 11 f0 	mov    %si,0xf0112548
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01005f3:	be fa 03 00 00       	mov    $0x3fa,%esi
f01005f8:	b8 00 00 00 00       	mov    $0x0,%eax
f01005fd:	89 f2                	mov    %esi,%edx
f01005ff:	ee                   	out    %al,(%dx)
f0100600:	b2 fb                	mov    $0xfb,%dl
f0100602:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f0100607:	ee                   	out    %al,(%dx)
f0100608:	bb f8 03 00 00       	mov    $0x3f8,%ebx
f010060d:	b8 0c 00 00 00       	mov    $0xc,%eax
f0100612:	89 da                	mov    %ebx,%edx
f0100614:	ee                   	out    %al,(%dx)
f0100615:	b2 f9                	mov    $0xf9,%dl
f0100617:	b8 00 00 00 00       	mov    $0x0,%eax
f010061c:	ee                   	out    %al,(%dx)
f010061d:	b2 fb                	mov    $0xfb,%dl
f010061f:	b8 03 00 00 00       	mov    $0x3,%eax
f0100624:	ee                   	out    %al,(%dx)
f0100625:	b2 fc                	mov    $0xfc,%dl
f0100627:	b8 00 00 00 00       	mov    $0x0,%eax
f010062c:	ee                   	out    %al,(%dx)
f010062d:	b2 f9                	mov    $0xf9,%dl
f010062f:	b8 01 00 00 00       	mov    $0x1,%eax
f0100634:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100635:	b2 fd                	mov    $0xfd,%dl
f0100637:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f0100638:	3c ff                	cmp    $0xff,%al
f010063a:	0f 95 c1             	setne  %cl
f010063d:	0f b6 c9             	movzbl %cl,%ecx
f0100640:	89 0d 54 25 11 f0    	mov    %ecx,0xf0112554
f0100646:	89 f2                	mov    %esi,%edx
f0100648:	ec                   	in     (%dx),%al
f0100649:	89 da                	mov    %ebx,%edx
f010064b:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f010064c:	85 c9                	test   %ecx,%ecx
f010064e:	75 0c                	jne    f010065c <cons_init+0xed>
		cprintf("Serial port does not exist!\n");
f0100650:	c7 04 24 50 1a 10 f0 	movl   $0xf0101a50,(%esp)
f0100657:	e8 f3 02 00 00       	call   f010094f <cprintf>
}
f010065c:	83 c4 1c             	add    $0x1c,%esp
f010065f:	5b                   	pop    %ebx
f0100660:	5e                   	pop    %esi
f0100661:	5f                   	pop    %edi
f0100662:	5d                   	pop    %ebp
f0100663:	c3                   	ret    

f0100664 <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f0100664:	55                   	push   %ebp
f0100665:	89 e5                	mov    %esp,%ebp
f0100667:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f010066a:	8b 45 08             	mov    0x8(%ebp),%eax
f010066d:	e8 97 fc ff ff       	call   f0100309 <cons_putc>
}
f0100672:	c9                   	leave  
f0100673:	c3                   	ret    

f0100674 <getchar>:

int
getchar(void)
{
f0100674:	55                   	push   %ebp
f0100675:	89 e5                	mov    %esp,%ebp
f0100677:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f010067a:	e8 a6 fe ff ff       	call   f0100525 <cons_getc>
f010067f:	85 c0                	test   %eax,%eax
f0100681:	74 f7                	je     f010067a <getchar+0x6>
		/* do nothing */;
	return c;
}
f0100683:	c9                   	leave  
f0100684:	c3                   	ret    

f0100685 <iscons>:

int
iscons(int fdnum)
{
f0100685:	55                   	push   %ebp
f0100686:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f0100688:	b8 01 00 00 00       	mov    $0x1,%eax
f010068d:	5d                   	pop    %ebp
f010068e:	c3                   	ret    
f010068f:	90                   	nop

f0100690 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100690:	55                   	push   %ebp
f0100691:	89 e5                	mov    %esp,%ebp
f0100693:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < NCOMMANDS; i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100696:	c7 44 24 08 a0 1c 10 	movl   $0xf0101ca0,0x8(%esp)
f010069d:	f0 
f010069e:	c7 44 24 04 be 1c 10 	movl   $0xf0101cbe,0x4(%esp)
f01006a5:	f0 
f01006a6:	c7 04 24 c3 1c 10 f0 	movl   $0xf0101cc3,(%esp)
f01006ad:	e8 9d 02 00 00       	call   f010094f <cprintf>
f01006b2:	c7 44 24 08 44 1d 10 	movl   $0xf0101d44,0x8(%esp)
f01006b9:	f0 
f01006ba:	c7 44 24 04 cc 1c 10 	movl   $0xf0101ccc,0x4(%esp)
f01006c1:	f0 
f01006c2:	c7 04 24 c3 1c 10 f0 	movl   $0xf0101cc3,(%esp)
f01006c9:	e8 81 02 00 00       	call   f010094f <cprintf>
	return 0;
}
f01006ce:	b8 00 00 00 00       	mov    $0x0,%eax
f01006d3:	c9                   	leave  
f01006d4:	c3                   	ret    

f01006d5 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f01006d5:	55                   	push   %ebp
f01006d6:	89 e5                	mov    %esp,%ebp
f01006d8:	83 ec 18             	sub    $0x18,%esp
	extern char entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f01006db:	c7 04 24 d5 1c 10 f0 	movl   $0xf0101cd5,(%esp)
f01006e2:	e8 68 02 00 00       	call   f010094f <cprintf>
	cprintf(" this is work 1 insert:\n");
f01006e7:	c7 04 24 ee 1c 10 f0 	movl   $0xf0101cee,(%esp)
f01006ee:	e8 5c 02 00 00       	call   f010094f <cprintf>
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
f01006f3:	c7 44 24 08 0f 00 00 	movl   $0xf,0x8(%esp)
f01006fa:	00 
f01006fb:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
f0100702:	00 
f0100703:	c7 04 24 6c 1d 10 f0 	movl   $0xf0101d6c,(%esp)
f010070a:	e8 40 02 00 00       	call   f010094f <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
f010070f:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f0100716:	00 
f0100717:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f010071e:	f0 
f010071f:	c7 04 24 a4 1d 10 f0 	movl   $0xf0101da4,(%esp)
f0100726:	e8 24 02 00 00       	call   f010094f <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f010072b:	c7 44 24 08 b7 19 10 	movl   $0x1019b7,0x8(%esp)
f0100732:	00 
f0100733:	c7 44 24 04 b7 19 10 	movl   $0xf01019b7,0x4(%esp)
f010073a:	f0 
f010073b:	c7 04 24 cc 1d 10 f0 	movl   $0xf0101dcc,(%esp)
f0100742:	e8 08 02 00 00       	call   f010094f <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f0100747:	c7 44 24 08 00 23 11 	movl   $0x112300,0x8(%esp)
f010074e:	00 
f010074f:	c7 44 24 04 00 23 11 	movl   $0xf0112300,0x4(%esp)
f0100756:	f0 
f0100757:	c7 04 24 f0 1d 10 f0 	movl   $0xf0101df0,(%esp)
f010075e:	e8 ec 01 00 00       	call   f010094f <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f0100763:	c7 44 24 08 60 29 11 	movl   $0x112960,0x8(%esp)
f010076a:	00 
f010076b:	c7 44 24 04 60 29 11 	movl   $0xf0112960,0x4(%esp)
f0100772:	f0 
f0100773:	c7 04 24 14 1e 10 f0 	movl   $0xf0101e14,(%esp)
f010077a:	e8 d0 01 00 00       	call   f010094f <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f010077f:	b8 5f 2d 11 f0       	mov    $0xf0112d5f,%eax
f0100784:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f0100789:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f010078f:	85 c0                	test   %eax,%eax
f0100791:	0f 48 c2             	cmovs  %edx,%eax
f0100794:	c1 f8 0a             	sar    $0xa,%eax
f0100797:	89 44 24 04          	mov    %eax,0x4(%esp)
f010079b:	c7 04 24 38 1e 10 f0 	movl   $0xf0101e38,(%esp)
f01007a2:	e8 a8 01 00 00       	call   f010094f <cprintf>
		(end-entry+1023)/1024);
	return 0;
}
f01007a7:	b8 00 00 00 00       	mov    $0x0,%eax
f01007ac:	c9                   	leave  
f01007ad:	c3                   	ret    

f01007ae <mon_backtrace>:

int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f01007ae:	55                   	push   %ebp
f01007af:	89 e5                	mov    %esp,%ebp
	// Your code here.
	return 0;
}
f01007b1:	b8 00 00 00 00       	mov    $0x0,%eax
f01007b6:	5d                   	pop    %ebp
f01007b7:	c3                   	ret    

f01007b8 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f01007b8:	55                   	push   %ebp
f01007b9:	89 e5                	mov    %esp,%ebp
f01007bb:	57                   	push   %edi
f01007bc:	56                   	push   %esi
f01007bd:	53                   	push   %ebx
f01007be:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f01007c1:	c7 04 24 64 1e 10 f0 	movl   $0xf0101e64,(%esp)
f01007c8:	e8 82 01 00 00       	call   f010094f <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f01007cd:	c7 04 24 88 1e 10 f0 	movl   $0xf0101e88,(%esp)
f01007d4:	e8 76 01 00 00       	call   f010094f <cprintf>


	while (1) {
		buf = readline("K> ");
f01007d9:	c7 04 24 07 1d 10 f0 	movl   $0xf0101d07,(%esp)
f01007e0:	e8 5b 0a 00 00       	call   f0101240 <readline>
f01007e5:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f01007e7:	85 c0                	test   %eax,%eax
f01007e9:	74 ee                	je     f01007d9 <monitor+0x21>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f01007eb:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f01007f2:	be 00 00 00 00       	mov    $0x0,%esi
f01007f7:	eb 0a                	jmp    f0100803 <monitor+0x4b>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f01007f9:	c6 03 00             	movb   $0x0,(%ebx)
f01007fc:	89 f7                	mov    %esi,%edi
f01007fe:	8d 5b 01             	lea    0x1(%ebx),%ebx
f0100801:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f0100803:	0f b6 03             	movzbl (%ebx),%eax
f0100806:	84 c0                	test   %al,%al
f0100808:	74 6a                	je     f0100874 <monitor+0xbc>
f010080a:	0f be c0             	movsbl %al,%eax
f010080d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100811:	c7 04 24 0b 1d 10 f0 	movl   $0xf0101d0b,(%esp)
f0100818:	e8 71 0c 00 00       	call   f010148e <strchr>
f010081d:	85 c0                	test   %eax,%eax
f010081f:	75 d8                	jne    f01007f9 <monitor+0x41>
			*buf++ = 0;
		if (*buf == 0)
f0100821:	80 3b 00             	cmpb   $0x0,(%ebx)
f0100824:	74 4e                	je     f0100874 <monitor+0xbc>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f0100826:	83 fe 0f             	cmp    $0xf,%esi
f0100829:	75 16                	jne    f0100841 <monitor+0x89>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f010082b:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f0100832:	00 
f0100833:	c7 04 24 10 1d 10 f0 	movl   $0xf0101d10,(%esp)
f010083a:	e8 10 01 00 00       	call   f010094f <cprintf>
f010083f:	eb 98                	jmp    f01007d9 <monitor+0x21>
			return 0;
		}
		argv[argc++] = buf;
f0100841:	8d 7e 01             	lea    0x1(%esi),%edi
f0100844:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f0100848:	0f b6 03             	movzbl (%ebx),%eax
f010084b:	84 c0                	test   %al,%al
f010084d:	75 0c                	jne    f010085b <monitor+0xa3>
f010084f:	eb b0                	jmp    f0100801 <monitor+0x49>
			buf++;
f0100851:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f0100854:	0f b6 03             	movzbl (%ebx),%eax
f0100857:	84 c0                	test   %al,%al
f0100859:	74 a6                	je     f0100801 <monitor+0x49>
f010085b:	0f be c0             	movsbl %al,%eax
f010085e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100862:	c7 04 24 0b 1d 10 f0 	movl   $0xf0101d0b,(%esp)
f0100869:	e8 20 0c 00 00       	call   f010148e <strchr>
f010086e:	85 c0                	test   %eax,%eax
f0100870:	74 df                	je     f0100851 <monitor+0x99>
f0100872:	eb 8d                	jmp    f0100801 <monitor+0x49>
			buf++;
	}
	argv[argc] = 0;
f0100874:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f010087b:	00 

	// Lookup and invoke the command
	if (argc == 0)
f010087c:	85 f6                	test   %esi,%esi
f010087e:	0f 84 55 ff ff ff    	je     f01007d9 <monitor+0x21>
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f0100884:	c7 44 24 04 be 1c 10 	movl   $0xf0101cbe,0x4(%esp)
f010088b:	f0 
f010088c:	8b 45 a8             	mov    -0x58(%ebp),%eax
f010088f:	89 04 24             	mov    %eax,(%esp)
f0100892:	e8 73 0b 00 00       	call   f010140a <strcmp>
f0100897:	85 c0                	test   %eax,%eax
f0100899:	74 1b                	je     f01008b6 <monitor+0xfe>
f010089b:	c7 44 24 04 cc 1c 10 	movl   $0xf0101ccc,0x4(%esp)
f01008a2:	f0 
f01008a3:	8b 45 a8             	mov    -0x58(%ebp),%eax
f01008a6:	89 04 24             	mov    %eax,(%esp)
f01008a9:	e8 5c 0b 00 00       	call   f010140a <strcmp>
f01008ae:	85 c0                	test   %eax,%eax
f01008b0:	75 2f                	jne    f01008e1 <monitor+0x129>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
f01008b2:	b0 01                	mov    $0x1,%al
f01008b4:	eb 05                	jmp    f01008bb <monitor+0x103>
		if (strcmp(argv[0], commands[i].name) == 0)
f01008b6:	b8 00 00 00 00       	mov    $0x0,%eax
			return commands[i].func(argc, argv, tf);
f01008bb:	8d 14 00             	lea    (%eax,%eax,1),%edx
f01008be:	01 d0                	add    %edx,%eax
f01008c0:	8b 4d 08             	mov    0x8(%ebp),%ecx
f01008c3:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01008c7:	8d 55 a8             	lea    -0x58(%ebp),%edx
f01008ca:	89 54 24 04          	mov    %edx,0x4(%esp)
f01008ce:	89 34 24             	mov    %esi,(%esp)
f01008d1:	ff 14 85 b8 1e 10 f0 	call   *-0xfefe148(,%eax,4)


	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f01008d8:	85 c0                	test   %eax,%eax
f01008da:	78 1d                	js     f01008f9 <monitor+0x141>
f01008dc:	e9 f8 fe ff ff       	jmp    f01007d9 <monitor+0x21>
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f01008e1:	8b 45 a8             	mov    -0x58(%ebp),%eax
f01008e4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01008e8:	c7 04 24 2d 1d 10 f0 	movl   $0xf0101d2d,(%esp)
f01008ef:	e8 5b 00 00 00       	call   f010094f <cprintf>
f01008f4:	e9 e0 fe ff ff       	jmp    f01007d9 <monitor+0x21>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f01008f9:	83 c4 5c             	add    $0x5c,%esp
f01008fc:	5b                   	pop    %ebx
f01008fd:	5e                   	pop    %esi
f01008fe:	5f                   	pop    %edi
f01008ff:	5d                   	pop    %ebp
f0100900:	c3                   	ret    

f0100901 <read_eip>:
// return EIP of caller.
// does not work if inlined.
// putting at the end of the file seems to prevent inlining.
unsigned
read_eip()
{
f0100901:	55                   	push   %ebp
f0100902:	89 e5                	mov    %esp,%ebp
	uint32_t callerpc;
	__asm __volatile("movl 4(%%ebp), %0" : "=r" (callerpc));
f0100904:	8b 45 04             	mov    0x4(%ebp),%eax
	return callerpc;
}
f0100907:	5d                   	pop    %ebp
f0100908:	c3                   	ret    

f0100909 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0100909:	55                   	push   %ebp
f010090a:	89 e5                	mov    %esp,%ebp
f010090c:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f010090f:	8b 45 08             	mov    0x8(%ebp),%eax
f0100912:	89 04 24             	mov    %eax,(%esp)
f0100915:	e8 4a fd ff ff       	call   f0100664 <cputchar>
	*cnt++;
}
f010091a:	c9                   	leave  
f010091b:	c3                   	ret    

f010091c <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f010091c:	55                   	push   %ebp
f010091d:	89 e5                	mov    %esp,%ebp
f010091f:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0100922:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0100929:	8b 45 0c             	mov    0xc(%ebp),%eax
f010092c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100930:	8b 45 08             	mov    0x8(%ebp),%eax
f0100933:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100937:	8d 45 f4             	lea    -0xc(%ebp),%eax
f010093a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010093e:	c7 04 24 09 09 10 f0 	movl   $0xf0100909,(%esp)
f0100945:	e8 8a 04 00 00       	call   f0100dd4 <vprintfmt>
	return cnt;
}
f010094a:	8b 45 f4             	mov    -0xc(%ebp),%eax
f010094d:	c9                   	leave  
f010094e:	c3                   	ret    

f010094f <cprintf>:

int
cprintf(const char *fmt, ...)
{
f010094f:	55                   	push   %ebp
f0100950:	89 e5                	mov    %esp,%ebp
f0100952:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0100955:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0100958:	89 44 24 04          	mov    %eax,0x4(%esp)
f010095c:	8b 45 08             	mov    0x8(%ebp),%eax
f010095f:	89 04 24             	mov    %eax,(%esp)
f0100962:	e8 b5 ff ff ff       	call   f010091c <vcprintf>
	va_end(ap);

	return cnt;
}
f0100967:	c9                   	leave  
f0100968:	c3                   	ret    
f0100969:	66 90                	xchg   %ax,%ax
f010096b:	66 90                	xchg   %ax,%ax
f010096d:	66 90                	xchg   %ax,%ax
f010096f:	90                   	nop

f0100970 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0100970:	55                   	push   %ebp
f0100971:	89 e5                	mov    %esp,%ebp
f0100973:	57                   	push   %edi
f0100974:	56                   	push   %esi
f0100975:	53                   	push   %ebx
f0100976:	83 ec 10             	sub    $0x10,%esp
f0100979:	89 c6                	mov    %eax,%esi
f010097b:	89 55 e8             	mov    %edx,-0x18(%ebp)
f010097e:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
f0100981:	8b 7d 08             	mov    0x8(%ebp),%edi
	int l = *region_left, r = *region_right, any_matches = 0;
f0100984:	8b 1a                	mov    (%edx),%ebx
f0100986:	8b 01                	mov    (%ecx),%eax
f0100988:	89 45 f0             	mov    %eax,-0x10(%ebp)
f010098b:	c7 45 ec 00 00 00 00 	movl   $0x0,-0x14(%ebp)
	
	while (l <= r) {
f0100992:	eb 77                	jmp    f0100a0b <stab_binsearch+0x9b>
		int true_m = (l + r) / 2, m = true_m;
f0100994:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0100997:	01 d8                	add    %ebx,%eax
f0100999:	b9 02 00 00 00       	mov    $0x2,%ecx
f010099e:	99                   	cltd   
f010099f:	f7 f9                	idiv   %ecx
f01009a1:	89 c1                	mov    %eax,%ecx
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f01009a3:	eb 01                	jmp    f01009a6 <stab_binsearch+0x36>
			m--;
f01009a5:	49                   	dec    %ecx
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f01009a6:	39 d9                	cmp    %ebx,%ecx
f01009a8:	7c 1d                	jl     f01009c7 <stab_binsearch+0x57>
f01009aa:	6b d1 0c             	imul   $0xc,%ecx,%edx
f01009ad:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f01009b2:	39 fa                	cmp    %edi,%edx
f01009b4:	75 ef                	jne    f01009a5 <stab_binsearch+0x35>
f01009b6:	89 4d ec             	mov    %ecx,-0x14(%ebp)
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f01009b9:	6b d1 0c             	imul   $0xc,%ecx,%edx
f01009bc:	8b 54 16 08          	mov    0x8(%esi,%edx,1),%edx
f01009c0:	3b 55 0c             	cmp    0xc(%ebp),%edx
f01009c3:	73 18                	jae    f01009dd <stab_binsearch+0x6d>
f01009c5:	eb 05                	jmp    f01009cc <stab_binsearch+0x5c>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f01009c7:	8d 58 01             	lea    0x1(%eax),%ebx
			continue;
f01009ca:	eb 3f                	jmp    f0100a0b <stab_binsearch+0x9b>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f01009cc:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f01009cf:	89 0b                	mov    %ecx,(%ebx)
			l = true_m + 1;
f01009d1:	8d 58 01             	lea    0x1(%eax),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01009d4:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f01009db:	eb 2e                	jmp    f0100a0b <stab_binsearch+0x9b>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f01009dd:	39 55 0c             	cmp    %edx,0xc(%ebp)
f01009e0:	73 15                	jae    f01009f7 <stab_binsearch+0x87>
			*region_right = m - 1;
f01009e2:	8b 45 ec             	mov    -0x14(%ebp),%eax
f01009e5:	48                   	dec    %eax
f01009e6:	89 45 f0             	mov    %eax,-0x10(%ebp)
f01009e9:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f01009ec:	89 01                	mov    %eax,(%ecx)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01009ee:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f01009f5:	eb 14                	jmp    f0100a0b <stab_binsearch+0x9b>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f01009f7:	8b 45 e8             	mov    -0x18(%ebp),%eax
f01009fa:	8b 5d ec             	mov    -0x14(%ebp),%ebx
f01009fd:	89 18                	mov    %ebx,(%eax)
			l = m;
			addr++;
f01009ff:	ff 45 0c             	incl   0xc(%ebp)
f0100a02:	89 cb                	mov    %ecx,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100a04:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f0100a0b:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0100a0e:	7e 84                	jle    f0100994 <stab_binsearch+0x24>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0100a10:	83 7d ec 00          	cmpl   $0x0,-0x14(%ebp)
f0100a14:	75 0d                	jne    f0100a23 <stab_binsearch+0xb3>
		*region_right = *region_left - 1;
f0100a16:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0100a19:	8b 00                	mov    (%eax),%eax
f0100a1b:	48                   	dec    %eax
f0100a1c:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0100a1f:	89 07                	mov    %eax,(%edi)
f0100a21:	eb 22                	jmp    f0100a45 <stab_binsearch+0xd5>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100a23:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100a26:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0100a28:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f0100a2b:	8b 0b                	mov    (%ebx),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100a2d:	eb 01                	jmp    f0100a30 <stab_binsearch+0xc0>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
f0100a2f:	48                   	dec    %eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100a30:	39 c1                	cmp    %eax,%ecx
f0100a32:	7d 0c                	jge    f0100a40 <stab_binsearch+0xd0>
f0100a34:	6b d0 0c             	imul   $0xc,%eax,%edx
		     l > *region_left && stabs[l].n_type != type;
f0100a37:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f0100a3c:	39 fa                	cmp    %edi,%edx
f0100a3e:	75 ef                	jne    f0100a2f <stab_binsearch+0xbf>
		     l--)
			/* do nothing */;
		*region_left = l;
f0100a40:	8b 7d e8             	mov    -0x18(%ebp),%edi
f0100a43:	89 07                	mov    %eax,(%edi)
	}
}
f0100a45:	83 c4 10             	add    $0x10,%esp
f0100a48:	5b                   	pop    %ebx
f0100a49:	5e                   	pop    %esi
f0100a4a:	5f                   	pop    %edi
f0100a4b:	5d                   	pop    %ebp
f0100a4c:	c3                   	ret    

f0100a4d <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0100a4d:	55                   	push   %ebp
f0100a4e:	89 e5                	mov    %esp,%ebp
f0100a50:	57                   	push   %edi
f0100a51:	56                   	push   %esi
f0100a52:	53                   	push   %ebx
f0100a53:	83 ec 2c             	sub    $0x2c,%esp
f0100a56:	8b 75 08             	mov    0x8(%ebp),%esi
f0100a59:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0100a5c:	c7 03 c8 1e 10 f0    	movl   $0xf0101ec8,(%ebx)
	info->eip_line = 0;
f0100a62:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
	info->eip_fn_name = "<unknown>";
f0100a69:	c7 43 08 c8 1e 10 f0 	movl   $0xf0101ec8,0x8(%ebx)
	info->eip_fn_namelen = 9;
f0100a70:	c7 43 0c 09 00 00 00 	movl   $0x9,0xc(%ebx)
	info->eip_fn_addr = addr;
f0100a77:	89 73 10             	mov    %esi,0x10(%ebx)
	info->eip_fn_narg = 0;
f0100a7a:	c7 43 14 00 00 00 00 	movl   $0x0,0x14(%ebx)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0100a81:	81 fe ff ff 7f ef    	cmp    $0xef7fffff,%esi
f0100a87:	76 12                	jbe    f0100a9b <debuginfo_eip+0x4e>
		// Can't search for user-level addresses yet!
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100a89:	b8 eb 72 10 f0       	mov    $0xf01072eb,%eax
f0100a8e:	3d 95 59 10 f0       	cmp    $0xf0105995,%eax
f0100a93:	0f 86 8b 01 00 00    	jbe    f0100c24 <debuginfo_eip+0x1d7>
f0100a99:	eb 1c                	jmp    f0100ab7 <debuginfo_eip+0x6a>
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
	} else {
		// Can't search for user-level addresses yet!
  	        panic("User address");
f0100a9b:	c7 44 24 08 d2 1e 10 	movl   $0xf0101ed2,0x8(%esp)
f0100aa2:	f0 
f0100aa3:	c7 44 24 04 7f 00 00 	movl   $0x7f,0x4(%esp)
f0100aaa:	00 
f0100aab:	c7 04 24 df 1e 10 f0 	movl   $0xf0101edf,(%esp)
f0100ab2:	e8 41 f6 ff ff       	call   f01000f8 <_panic>
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100ab7:	80 3d ea 72 10 f0 00 	cmpb   $0x0,0xf01072ea
f0100abe:	0f 85 67 01 00 00    	jne    f0100c2b <debuginfo_eip+0x1de>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0100ac4:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0100acb:	b8 94 59 10 f0       	mov    $0xf0105994,%eax
f0100ad0:	2d 00 21 10 f0       	sub    $0xf0102100,%eax
f0100ad5:	c1 f8 02             	sar    $0x2,%eax
f0100ad8:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
f0100ade:	83 e8 01             	sub    $0x1,%eax
f0100ae1:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0100ae4:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100ae8:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0100aef:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0100af2:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0100af5:	b8 00 21 10 f0       	mov    $0xf0102100,%eax
f0100afa:	e8 71 fe ff ff       	call   f0100970 <stab_binsearch>
	if (lfile == 0)
f0100aff:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100b02:	85 c0                	test   %eax,%eax
f0100b04:	0f 84 28 01 00 00    	je     f0100c32 <debuginfo_eip+0x1e5>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0100b0a:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0100b0d:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100b10:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0100b13:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100b17:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0100b1e:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0100b21:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100b24:	b8 00 21 10 f0       	mov    $0xf0102100,%eax
f0100b29:	e8 42 fe ff ff       	call   f0100970 <stab_binsearch>

	if (lfun <= rfun) {
f0100b2e:	8b 7d dc             	mov    -0x24(%ebp),%edi
f0100b31:	3b 7d d8             	cmp    -0x28(%ebp),%edi
f0100b34:	7f 2e                	jg     f0100b64 <debuginfo_eip+0x117>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0100b36:	6b c7 0c             	imul   $0xc,%edi,%eax
f0100b39:	8d 90 00 21 10 f0    	lea    -0xfefdf00(%eax),%edx
f0100b3f:	8b 80 00 21 10 f0    	mov    -0xfefdf00(%eax),%eax
f0100b45:	b9 eb 72 10 f0       	mov    $0xf01072eb,%ecx
f0100b4a:	81 e9 95 59 10 f0    	sub    $0xf0105995,%ecx
f0100b50:	39 c8                	cmp    %ecx,%eax
f0100b52:	73 08                	jae    f0100b5c <debuginfo_eip+0x10f>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0100b54:	05 95 59 10 f0       	add    $0xf0105995,%eax
f0100b59:	89 43 08             	mov    %eax,0x8(%ebx)
		info->eip_fn_addr = stabs[lfun].n_value;
f0100b5c:	8b 42 08             	mov    0x8(%edx),%eax
f0100b5f:	89 43 10             	mov    %eax,0x10(%ebx)
f0100b62:	eb 06                	jmp    f0100b6a <debuginfo_eip+0x11d>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0100b64:	89 73 10             	mov    %esi,0x10(%ebx)
		lline = lfile;
f0100b67:	8b 7d e4             	mov    -0x1c(%ebp),%edi
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0100b6a:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0100b71:	00 
f0100b72:	8b 43 08             	mov    0x8(%ebx),%eax
f0100b75:	89 04 24             	mov    %eax,(%esp)
f0100b78:	e8 47 09 00 00       	call   f01014c4 <strfind>
f0100b7d:	2b 43 08             	sub    0x8(%ebx),%eax
f0100b80:	89 43 0c             	mov    %eax,0xc(%ebx)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0100b83:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0100b86:	39 cf                	cmp    %ecx,%edi
f0100b88:	7c 5c                	jl     f0100be6 <debuginfo_eip+0x199>
	       && stabs[lline].n_type != N_SOL
f0100b8a:	6b c7 0c             	imul   $0xc,%edi,%eax
f0100b8d:	8d b0 00 21 10 f0    	lea    -0xfefdf00(%eax),%esi
f0100b93:	0f b6 56 04          	movzbl 0x4(%esi),%edx
f0100b97:	80 fa 84             	cmp    $0x84,%dl
f0100b9a:	74 2b                	je     f0100bc7 <debuginfo_eip+0x17a>
f0100b9c:	05 f4 20 10 f0       	add    $0xf01020f4,%eax
f0100ba1:	eb 15                	jmp    f0100bb8 <debuginfo_eip+0x16b>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0100ba3:	83 ef 01             	sub    $0x1,%edi
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0100ba6:	39 cf                	cmp    %ecx,%edi
f0100ba8:	7c 3c                	jl     f0100be6 <debuginfo_eip+0x199>
	       && stabs[lline].n_type != N_SOL
f0100baa:	89 c6                	mov    %eax,%esi
f0100bac:	83 e8 0c             	sub    $0xc,%eax
f0100baf:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0100bb3:	80 fa 84             	cmp    $0x84,%dl
f0100bb6:	74 0f                	je     f0100bc7 <debuginfo_eip+0x17a>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0100bb8:	80 fa 64             	cmp    $0x64,%dl
f0100bbb:	75 e6                	jne    f0100ba3 <debuginfo_eip+0x156>
f0100bbd:	83 7e 08 00          	cmpl   $0x0,0x8(%esi)
f0100bc1:	74 e0                	je     f0100ba3 <debuginfo_eip+0x156>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0100bc3:	39 f9                	cmp    %edi,%ecx
f0100bc5:	7f 1f                	jg     f0100be6 <debuginfo_eip+0x199>
f0100bc7:	6b ff 0c             	imul   $0xc,%edi,%edi
f0100bca:	8b 87 00 21 10 f0    	mov    -0xfefdf00(%edi),%eax
f0100bd0:	ba eb 72 10 f0       	mov    $0xf01072eb,%edx
f0100bd5:	81 ea 95 59 10 f0    	sub    $0xf0105995,%edx
f0100bdb:	39 d0                	cmp    %edx,%eax
f0100bdd:	73 07                	jae    f0100be6 <debuginfo_eip+0x199>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0100bdf:	05 95 59 10 f0       	add    $0xf0105995,%eax
f0100be4:	89 03                	mov    %eax,(%ebx)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100be6:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100be9:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0100bec:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100bf1:	39 ca                	cmp    %ecx,%edx
f0100bf3:	7d 5e                	jge    f0100c53 <debuginfo_eip+0x206>
		for (lline = lfun + 1;
f0100bf5:	8d 42 01             	lea    0x1(%edx),%eax
f0100bf8:	39 c1                	cmp    %eax,%ecx
f0100bfa:	7e 3d                	jle    f0100c39 <debuginfo_eip+0x1ec>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0100bfc:	6b d0 0c             	imul   $0xc,%eax,%edx
f0100bff:	80 ba 04 21 10 f0 a0 	cmpb   $0xa0,-0xfefdefc(%edx)
f0100c06:	75 38                	jne    f0100c40 <debuginfo_eip+0x1f3>
f0100c08:	81 c2 f4 20 10 f0    	add    $0xf01020f4,%edx
		     lline++)
			info->eip_fn_narg++;
f0100c0e:	83 43 14 01          	addl   $0x1,0x14(%ebx)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0100c12:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0100c15:	39 c1                	cmp    %eax,%ecx
f0100c17:	7e 2e                	jle    f0100c47 <debuginfo_eip+0x1fa>
f0100c19:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0100c1c:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0100c20:	74 ec                	je     f0100c0e <debuginfo_eip+0x1c1>
f0100c22:	eb 2a                	jmp    f0100c4e <debuginfo_eip+0x201>
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0100c24:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100c29:	eb 28                	jmp    f0100c53 <debuginfo_eip+0x206>
f0100c2b:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100c30:	eb 21                	jmp    f0100c53 <debuginfo_eip+0x206>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0100c32:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100c37:	eb 1a                	jmp    f0100c53 <debuginfo_eip+0x206>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0100c39:	b8 00 00 00 00       	mov    $0x0,%eax
f0100c3e:	eb 13                	jmp    f0100c53 <debuginfo_eip+0x206>
f0100c40:	b8 00 00 00 00       	mov    $0x0,%eax
f0100c45:	eb 0c                	jmp    f0100c53 <debuginfo_eip+0x206>
f0100c47:	b8 00 00 00 00       	mov    $0x0,%eax
f0100c4c:	eb 05                	jmp    f0100c53 <debuginfo_eip+0x206>
f0100c4e:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0100c53:	83 c4 2c             	add    $0x2c,%esp
f0100c56:	5b                   	pop    %ebx
f0100c57:	5e                   	pop    %esi
f0100c58:	5f                   	pop    %edi
f0100c59:	5d                   	pop    %ebp
f0100c5a:	c3                   	ret    
f0100c5b:	66 90                	xchg   %ax,%ax
f0100c5d:	66 90                	xchg   %ax,%ax
f0100c5f:	90                   	nop

f0100c60 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0100c60:	55                   	push   %ebp
f0100c61:	89 e5                	mov    %esp,%ebp
f0100c63:	57                   	push   %edi
f0100c64:	56                   	push   %esi
f0100c65:	53                   	push   %ebx
f0100c66:	83 ec 3c             	sub    $0x3c,%esp
f0100c69:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0100c6c:	89 d7                	mov    %edx,%edi
f0100c6e:	8b 45 08             	mov    0x8(%ebp),%eax
f0100c71:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0100c74:	8b 75 0c             	mov    0xc(%ebp),%esi
f0100c77:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f0100c7a:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0100c7d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0100c82:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0100c85:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0100c88:	39 f1                	cmp    %esi,%ecx
f0100c8a:	72 14                	jb     f0100ca0 <printnum+0x40>
f0100c8c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f0100c8f:	76 0f                	jbe    f0100ca0 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0100c91:	8b 45 14             	mov    0x14(%ebp),%eax
f0100c94:	8d 70 ff             	lea    -0x1(%eax),%esi
f0100c97:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0100c9a:	85 f6                	test   %esi,%esi
f0100c9c:	7f 60                	jg     f0100cfe <printnum+0x9e>
f0100c9e:	eb 72                	jmp    f0100d12 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0100ca0:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0100ca3:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0100ca7:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0100caa:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0100cad:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100cb1:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100cb5:	8b 44 24 08          	mov    0x8(%esp),%eax
f0100cb9:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0100cbd:	89 c3                	mov    %eax,%ebx
f0100cbf:	89 d6                	mov    %edx,%esi
f0100cc1:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0100cc4:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0100cc7:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100ccb:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0100ccf:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100cd2:	89 04 24             	mov    %eax,(%esp)
f0100cd5:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100cd8:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100cdc:	e8 4f 0a 00 00       	call   f0101730 <__udivdi3>
f0100ce1:	89 d9                	mov    %ebx,%ecx
f0100ce3:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0100ce7:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0100ceb:	89 04 24             	mov    %eax,(%esp)
f0100cee:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100cf2:	89 fa                	mov    %edi,%edx
f0100cf4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100cf7:	e8 64 ff ff ff       	call   f0100c60 <printnum>
f0100cfc:	eb 14                	jmp    f0100d12 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f0100cfe:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100d02:	8b 45 18             	mov    0x18(%ebp),%eax
f0100d05:	89 04 24             	mov    %eax,(%esp)
f0100d08:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0100d0a:	83 ee 01             	sub    $0x1,%esi
f0100d0d:	75 ef                	jne    f0100cfe <printnum+0x9e>
f0100d0f:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0100d12:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100d16:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0100d1a:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100d1d:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100d20:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100d24:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100d28:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100d2b:	89 04 24             	mov    %eax,(%esp)
f0100d2e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100d31:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100d35:	e8 26 0b 00 00       	call   f0101860 <__umoddi3>
f0100d3a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100d3e:	0f be 80 ed 1e 10 f0 	movsbl -0xfefe113(%eax),%eax
f0100d45:	89 04 24             	mov    %eax,(%esp)
f0100d48:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100d4b:	ff d0                	call   *%eax
}
f0100d4d:	83 c4 3c             	add    $0x3c,%esp
f0100d50:	5b                   	pop    %ebx
f0100d51:	5e                   	pop    %esi
f0100d52:	5f                   	pop    %edi
f0100d53:	5d                   	pop    %ebp
f0100d54:	c3                   	ret    

f0100d55 <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0100d55:	55                   	push   %ebp
f0100d56:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0100d58:	83 fa 01             	cmp    $0x1,%edx
f0100d5b:	7e 0e                	jle    f0100d6b <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f0100d5d:	8b 10                	mov    (%eax),%edx
f0100d5f:	8d 4a 08             	lea    0x8(%edx),%ecx
f0100d62:	89 08                	mov    %ecx,(%eax)
f0100d64:	8b 02                	mov    (%edx),%eax
f0100d66:	8b 52 04             	mov    0x4(%edx),%edx
f0100d69:	eb 22                	jmp    f0100d8d <getuint+0x38>
	else if (lflag)
f0100d6b:	85 d2                	test   %edx,%edx
f0100d6d:	74 10                	je     f0100d7f <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f0100d6f:	8b 10                	mov    (%eax),%edx
f0100d71:	8d 4a 04             	lea    0x4(%edx),%ecx
f0100d74:	89 08                	mov    %ecx,(%eax)
f0100d76:	8b 02                	mov    (%edx),%eax
f0100d78:	ba 00 00 00 00       	mov    $0x0,%edx
f0100d7d:	eb 0e                	jmp    f0100d8d <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f0100d7f:	8b 10                	mov    (%eax),%edx
f0100d81:	8d 4a 04             	lea    0x4(%edx),%ecx
f0100d84:	89 08                	mov    %ecx,(%eax)
f0100d86:	8b 02                	mov    (%edx),%eax
f0100d88:	ba 00 00 00 00       	mov    $0x0,%edx
}
f0100d8d:	5d                   	pop    %ebp
f0100d8e:	c3                   	ret    

f0100d8f <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0100d8f:	55                   	push   %ebp
f0100d90:	89 e5                	mov    %esp,%ebp
f0100d92:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0100d95:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0100d99:	8b 10                	mov    (%eax),%edx
f0100d9b:	3b 50 04             	cmp    0x4(%eax),%edx
f0100d9e:	73 0a                	jae    f0100daa <sprintputch+0x1b>
		*b->buf++ = ch;
f0100da0:	8d 4a 01             	lea    0x1(%edx),%ecx
f0100da3:	89 08                	mov    %ecx,(%eax)
f0100da5:	8b 45 08             	mov    0x8(%ebp),%eax
f0100da8:	88 02                	mov    %al,(%edx)
}
f0100daa:	5d                   	pop    %ebp
f0100dab:	c3                   	ret    

f0100dac <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0100dac:	55                   	push   %ebp
f0100dad:	89 e5                	mov    %esp,%ebp
f0100daf:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0100db2:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0100db5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100db9:	8b 45 10             	mov    0x10(%ebp),%eax
f0100dbc:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100dc0:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100dc3:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100dc7:	8b 45 08             	mov    0x8(%ebp),%eax
f0100dca:	89 04 24             	mov    %eax,(%esp)
f0100dcd:	e8 02 00 00 00       	call   f0100dd4 <vprintfmt>
	va_end(ap);
}
f0100dd2:	c9                   	leave  
f0100dd3:	c3                   	ret    

f0100dd4 <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f0100dd4:	55                   	push   %ebp
f0100dd5:	89 e5                	mov    %esp,%ebp
f0100dd7:	57                   	push   %edi
f0100dd8:	56                   	push   %esi
f0100dd9:	53                   	push   %ebx
f0100dda:	83 ec 3c             	sub    $0x3c,%esp
f0100ddd:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0100de0:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0100de3:	eb 18                	jmp    f0100dfd <vprintfmt+0x29>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f0100de5:	85 c0                	test   %eax,%eax
f0100de7:	0f 84 c3 03 00 00    	je     f01011b0 <vprintfmt+0x3dc>
				return;
			putch(ch, putdat);
f0100ded:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100df1:	89 04 24             	mov    %eax,(%esp)
f0100df4:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0100df7:	89 f3                	mov    %esi,%ebx
f0100df9:	eb 02                	jmp    f0100dfd <vprintfmt+0x29>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f0100dfb:	89 f3                	mov    %esi,%ebx
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0100dfd:	8d 73 01             	lea    0x1(%ebx),%esi
f0100e00:	0f b6 03             	movzbl (%ebx),%eax
f0100e03:	83 f8 25             	cmp    $0x25,%eax
f0100e06:	75 dd                	jne    f0100de5 <vprintfmt+0x11>
f0100e08:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f0100e0c:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0100e13:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f0100e1a:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0100e21:	ba 00 00 00 00       	mov    $0x0,%edx
f0100e26:	eb 1d                	jmp    f0100e45 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100e28:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f0100e2a:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f0100e2e:	eb 15                	jmp    f0100e45 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100e30:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0100e32:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f0100e36:	eb 0d                	jmp    f0100e45 <vprintfmt+0x71>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0100e38:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100e3b:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0100e3e:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100e45:	8d 5e 01             	lea    0x1(%esi),%ebx
f0100e48:	0f b6 06             	movzbl (%esi),%eax
f0100e4b:	0f b6 c8             	movzbl %al,%ecx
f0100e4e:	83 e8 23             	sub    $0x23,%eax
f0100e51:	3c 55                	cmp    $0x55,%al
f0100e53:	0f 87 2f 03 00 00    	ja     f0101188 <vprintfmt+0x3b4>
f0100e59:	0f b6 c0             	movzbl %al,%eax
f0100e5c:	ff 24 85 7c 1f 10 f0 	jmp    *-0xfefe084(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0100e63:	8d 41 d0             	lea    -0x30(%ecx),%eax
f0100e66:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0100e69:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f0100e6d:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0100e70:	83 f9 09             	cmp    $0x9,%ecx
f0100e73:	77 50                	ja     f0100ec5 <vprintfmt+0xf1>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100e75:	89 de                	mov    %ebx,%esi
f0100e77:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f0100e7a:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f0100e7d:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0100e80:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0100e84:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0100e87:	8d 58 d0             	lea    -0x30(%eax),%ebx
f0100e8a:	83 fb 09             	cmp    $0x9,%ebx
f0100e8d:	76 eb                	jbe    f0100e7a <vprintfmt+0xa6>
f0100e8f:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0100e92:	eb 33                	jmp    f0100ec7 <vprintfmt+0xf3>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0100e94:	8b 45 14             	mov    0x14(%ebp),%eax
f0100e97:	8d 48 04             	lea    0x4(%eax),%ecx
f0100e9a:	89 4d 14             	mov    %ecx,0x14(%ebp)
f0100e9d:	8b 00                	mov    (%eax),%eax
f0100e9f:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100ea2:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0100ea4:	eb 21                	jmp    f0100ec7 <vprintfmt+0xf3>
f0100ea6:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0100ea9:	85 c9                	test   %ecx,%ecx
f0100eab:	b8 00 00 00 00       	mov    $0x0,%eax
f0100eb0:	0f 49 c1             	cmovns %ecx,%eax
f0100eb3:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100eb6:	89 de                	mov    %ebx,%esi
f0100eb8:	eb 8b                	jmp    f0100e45 <vprintfmt+0x71>
f0100eba:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0100ebc:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f0100ec3:	eb 80                	jmp    f0100e45 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100ec5:	89 de                	mov    %ebx,%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0100ec7:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0100ecb:	0f 89 74 ff ff ff    	jns    f0100e45 <vprintfmt+0x71>
f0100ed1:	e9 62 ff ff ff       	jmp    f0100e38 <vprintfmt+0x64>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0100ed6:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100ed9:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f0100edb:	e9 65 ff ff ff       	jmp    f0100e45 <vprintfmt+0x71>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f0100ee0:	8b 45 14             	mov    0x14(%ebp),%eax
f0100ee3:	8d 50 04             	lea    0x4(%eax),%edx
f0100ee6:	89 55 14             	mov    %edx,0x14(%ebp)
f0100ee9:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100eed:	8b 00                	mov    (%eax),%eax
f0100eef:	89 04 24             	mov    %eax,(%esp)
f0100ef2:	ff 55 08             	call   *0x8(%ebp)
			break;
f0100ef5:	e9 03 ff ff ff       	jmp    f0100dfd <vprintfmt+0x29>

		// error message
		case 'e':
			err = va_arg(ap, int);
f0100efa:	8b 45 14             	mov    0x14(%ebp),%eax
f0100efd:	8d 50 04             	lea    0x4(%eax),%edx
f0100f00:	89 55 14             	mov    %edx,0x14(%ebp)
f0100f03:	8b 00                	mov    (%eax),%eax
f0100f05:	99                   	cltd   
f0100f06:	31 d0                	xor    %edx,%eax
f0100f08:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0100f0a:	83 f8 06             	cmp    $0x6,%eax
f0100f0d:	7f 0b                	jg     f0100f1a <vprintfmt+0x146>
f0100f0f:	8b 14 85 d4 20 10 f0 	mov    -0xfefdf2c(,%eax,4),%edx
f0100f16:	85 d2                	test   %edx,%edx
f0100f18:	75 20                	jne    f0100f3a <vprintfmt+0x166>
				printfmt(putch, putdat, "error %d", err);
f0100f1a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100f1e:	c7 44 24 08 05 1f 10 	movl   $0xf0101f05,0x8(%esp)
f0100f25:	f0 
f0100f26:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100f2a:	8b 45 08             	mov    0x8(%ebp),%eax
f0100f2d:	89 04 24             	mov    %eax,(%esp)
f0100f30:	e8 77 fe ff ff       	call   f0100dac <printfmt>
f0100f35:	e9 c3 fe ff ff       	jmp    f0100dfd <vprintfmt+0x29>
			else
				printfmt(putch, putdat, "%s", p);
f0100f3a:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100f3e:	c7 44 24 08 0e 1f 10 	movl   $0xf0101f0e,0x8(%esp)
f0100f45:	f0 
f0100f46:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100f4a:	8b 45 08             	mov    0x8(%ebp),%eax
f0100f4d:	89 04 24             	mov    %eax,(%esp)
f0100f50:	e8 57 fe ff ff       	call   f0100dac <printfmt>
f0100f55:	e9 a3 fe ff ff       	jmp    f0100dfd <vprintfmt+0x29>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100f5a:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0100f5d:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0100f60:	8b 45 14             	mov    0x14(%ebp),%eax
f0100f63:	8d 50 04             	lea    0x4(%eax),%edx
f0100f66:	89 55 14             	mov    %edx,0x14(%ebp)
f0100f69:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f0100f6b:	85 c0                	test   %eax,%eax
f0100f6d:	ba fe 1e 10 f0       	mov    $0xf0101efe,%edx
f0100f72:	0f 45 d0             	cmovne %eax,%edx
f0100f75:	89 55 d0             	mov    %edx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f0100f78:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f0100f7c:	74 04                	je     f0100f82 <vprintfmt+0x1ae>
f0100f7e:	85 f6                	test   %esi,%esi
f0100f80:	7f 19                	jg     f0100f9b <vprintfmt+0x1c7>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0100f82:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0100f85:	8d 70 01             	lea    0x1(%eax),%esi
f0100f88:	0f b6 10             	movzbl (%eax),%edx
f0100f8b:	0f be c2             	movsbl %dl,%eax
f0100f8e:	85 c0                	test   %eax,%eax
f0100f90:	0f 85 95 00 00 00    	jne    f010102b <vprintfmt+0x257>
f0100f96:	e9 85 00 00 00       	jmp    f0101020 <vprintfmt+0x24c>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0100f9b:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100f9f:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0100fa2:	89 04 24             	mov    %eax,(%esp)
f0100fa5:	e8 88 03 00 00       	call   f0101332 <strnlen>
f0100faa:	29 c6                	sub    %eax,%esi
f0100fac:	89 f0                	mov    %esi,%eax
f0100fae:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0100fb1:	85 f6                	test   %esi,%esi
f0100fb3:	7e cd                	jle    f0100f82 <vprintfmt+0x1ae>
					putch(padc, putdat);
f0100fb5:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0100fb9:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0100fbc:	89 c3                	mov    %eax,%ebx
f0100fbe:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100fc2:	89 34 24             	mov    %esi,(%esp)
f0100fc5:	ff 55 08             	call   *0x8(%ebp)
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0100fc8:	83 eb 01             	sub    $0x1,%ebx
f0100fcb:	75 f1                	jne    f0100fbe <vprintfmt+0x1ea>
f0100fcd:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0100fd0:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0100fd3:	eb ad                	jmp    f0100f82 <vprintfmt+0x1ae>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f0100fd5:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0100fd9:	74 1e                	je     f0100ff9 <vprintfmt+0x225>
f0100fdb:	0f be d2             	movsbl %dl,%edx
f0100fde:	83 ea 20             	sub    $0x20,%edx
f0100fe1:	83 fa 5e             	cmp    $0x5e,%edx
f0100fe4:	76 13                	jbe    f0100ff9 <vprintfmt+0x225>
					putch('?', putdat);
f0100fe6:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100fe9:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100fed:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f0100ff4:	ff 55 08             	call   *0x8(%ebp)
f0100ff7:	eb 0d                	jmp    f0101006 <vprintfmt+0x232>
				else
					putch(ch, putdat);
f0100ff9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0100ffc:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0101000:	89 04 24             	mov    %eax,(%esp)
f0101003:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0101006:	83 ef 01             	sub    $0x1,%edi
f0101009:	83 c6 01             	add    $0x1,%esi
f010100c:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f0101010:	0f be c2             	movsbl %dl,%eax
f0101013:	85 c0                	test   %eax,%eax
f0101015:	75 20                	jne    f0101037 <vprintfmt+0x263>
f0101017:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f010101a:	8b 7d 0c             	mov    0xc(%ebp),%edi
f010101d:	8b 5d 10             	mov    0x10(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0101020:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0101024:	7f 25                	jg     f010104b <vprintfmt+0x277>
f0101026:	e9 d2 fd ff ff       	jmp    f0100dfd <vprintfmt+0x29>
f010102b:	89 7d 0c             	mov    %edi,0xc(%ebp)
f010102e:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0101031:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0101034:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0101037:	85 db                	test   %ebx,%ebx
f0101039:	78 9a                	js     f0100fd5 <vprintfmt+0x201>
f010103b:	83 eb 01             	sub    $0x1,%ebx
f010103e:	79 95                	jns    f0100fd5 <vprintfmt+0x201>
f0101040:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f0101043:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0101046:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0101049:	eb d5                	jmp    f0101020 <vprintfmt+0x24c>
f010104b:	8b 75 08             	mov    0x8(%ebp),%esi
f010104e:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0101051:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0101054:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101058:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f010105f:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0101061:	83 eb 01             	sub    $0x1,%ebx
f0101064:	75 ee                	jne    f0101054 <vprintfmt+0x280>
f0101066:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0101069:	e9 8f fd ff ff       	jmp    f0100dfd <vprintfmt+0x29>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010106e:	83 fa 01             	cmp    $0x1,%edx
f0101071:	7e 16                	jle    f0101089 <vprintfmt+0x2b5>
		return va_arg(*ap, long long);
f0101073:	8b 45 14             	mov    0x14(%ebp),%eax
f0101076:	8d 50 08             	lea    0x8(%eax),%edx
f0101079:	89 55 14             	mov    %edx,0x14(%ebp)
f010107c:	8b 50 04             	mov    0x4(%eax),%edx
f010107f:	8b 00                	mov    (%eax),%eax
f0101081:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0101084:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0101087:	eb 32                	jmp    f01010bb <vprintfmt+0x2e7>
	else if (lflag)
f0101089:	85 d2                	test   %edx,%edx
f010108b:	74 18                	je     f01010a5 <vprintfmt+0x2d1>
		return va_arg(*ap, long);
f010108d:	8b 45 14             	mov    0x14(%ebp),%eax
f0101090:	8d 50 04             	lea    0x4(%eax),%edx
f0101093:	89 55 14             	mov    %edx,0x14(%ebp)
f0101096:	8b 30                	mov    (%eax),%esi
f0101098:	89 75 d8             	mov    %esi,-0x28(%ebp)
f010109b:	89 f0                	mov    %esi,%eax
f010109d:	c1 f8 1f             	sar    $0x1f,%eax
f01010a0:	89 45 dc             	mov    %eax,-0x24(%ebp)
f01010a3:	eb 16                	jmp    f01010bb <vprintfmt+0x2e7>
	else
		return va_arg(*ap, int);
f01010a5:	8b 45 14             	mov    0x14(%ebp),%eax
f01010a8:	8d 50 04             	lea    0x4(%eax),%edx
f01010ab:	89 55 14             	mov    %edx,0x14(%ebp)
f01010ae:	8b 30                	mov    (%eax),%esi
f01010b0:	89 75 d8             	mov    %esi,-0x28(%ebp)
f01010b3:	89 f0                	mov    %esi,%eax
f01010b5:	c1 f8 1f             	sar    $0x1f,%eax
f01010b8:	89 45 dc             	mov    %eax,-0x24(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f01010bb:	8b 45 d8             	mov    -0x28(%ebp),%eax
f01010be:	8b 55 dc             	mov    -0x24(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f01010c1:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f01010c6:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f01010ca:	0f 89 80 00 00 00    	jns    f0101150 <vprintfmt+0x37c>
				putch('-', putdat);
f01010d0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01010d4:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f01010db:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f01010de:	8b 45 d8             	mov    -0x28(%ebp),%eax
f01010e1:	8b 55 dc             	mov    -0x24(%ebp),%edx
f01010e4:	f7 d8                	neg    %eax
f01010e6:	83 d2 00             	adc    $0x0,%edx
f01010e9:	f7 da                	neg    %edx
			}
			base = 10;
f01010eb:	b9 0a 00 00 00       	mov    $0xa,%ecx
f01010f0:	eb 5e                	jmp    f0101150 <vprintfmt+0x37c>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f01010f2:	8d 45 14             	lea    0x14(%ebp),%eax
f01010f5:	e8 5b fc ff ff       	call   f0100d55 <getuint>
			base = 10;
f01010fa:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f01010ff:	eb 4f                	jmp    f0101150 <vprintfmt+0x37c>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			//putch('X', putdat);
			num = getuint(&ap, lflag);
f0101101:	8d 45 14             	lea    0x14(%ebp),%eax
f0101104:	e8 4c fc ff ff       	call   f0100d55 <getuint>
			base = 8;
f0101109:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f010110e:	eb 40                	jmp    f0101150 <vprintfmt+0x37c>
			//putch('X', putdat);
			//break;

		// pointer
		case 'p':
			putch('0', putdat);
f0101110:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101114:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f010111b:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f010111e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101122:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f0101129:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f010112c:	8b 45 14             	mov    0x14(%ebp),%eax
f010112f:	8d 50 04             	lea    0x4(%eax),%edx
f0101132:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f0101135:	8b 00                	mov    (%eax),%eax
f0101137:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f010113c:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f0101141:	eb 0d                	jmp    f0101150 <vprintfmt+0x37c>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f0101143:	8d 45 14             	lea    0x14(%ebp),%eax
f0101146:	e8 0a fc ff ff       	call   f0100d55 <getuint>
			base = 16;
f010114b:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f0101150:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0101154:	89 74 24 10          	mov    %esi,0x10(%esp)
f0101158:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f010115b:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010115f:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101163:	89 04 24             	mov    %eax,(%esp)
f0101166:	89 54 24 04          	mov    %edx,0x4(%esp)
f010116a:	89 fa                	mov    %edi,%edx
f010116c:	8b 45 08             	mov    0x8(%ebp),%eax
f010116f:	e8 ec fa ff ff       	call   f0100c60 <printnum>
			break;
f0101174:	e9 84 fc ff ff       	jmp    f0100dfd <vprintfmt+0x29>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0101179:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010117d:	89 0c 24             	mov    %ecx,(%esp)
f0101180:	ff 55 08             	call   *0x8(%ebp)
			break;
f0101183:	e9 75 fc ff ff       	jmp    f0100dfd <vprintfmt+0x29>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0101188:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010118c:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0101193:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f0101196:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f010119a:	0f 84 5b fc ff ff    	je     f0100dfb <vprintfmt+0x27>
f01011a0:	89 f3                	mov    %esi,%ebx
f01011a2:	83 eb 01             	sub    $0x1,%ebx
f01011a5:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f01011a9:	75 f7                	jne    f01011a2 <vprintfmt+0x3ce>
f01011ab:	e9 4d fc ff ff       	jmp    f0100dfd <vprintfmt+0x29>
				/* do nothing */;
			break;
		}
	}
}
f01011b0:	83 c4 3c             	add    $0x3c,%esp
f01011b3:	5b                   	pop    %ebx
f01011b4:	5e                   	pop    %esi
f01011b5:	5f                   	pop    %edi
f01011b6:	5d                   	pop    %ebp
f01011b7:	c3                   	ret    

f01011b8 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f01011b8:	55                   	push   %ebp
f01011b9:	89 e5                	mov    %esp,%ebp
f01011bb:	83 ec 28             	sub    $0x28,%esp
f01011be:	8b 45 08             	mov    0x8(%ebp),%eax
f01011c1:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f01011c4:	89 45 ec             	mov    %eax,-0x14(%ebp)
f01011c7:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f01011cb:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f01011ce:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f01011d5:	85 c0                	test   %eax,%eax
f01011d7:	74 30                	je     f0101209 <vsnprintf+0x51>
f01011d9:	85 d2                	test   %edx,%edx
f01011db:	7e 2c                	jle    f0101209 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f01011dd:	8b 45 14             	mov    0x14(%ebp),%eax
f01011e0:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01011e4:	8b 45 10             	mov    0x10(%ebp),%eax
f01011e7:	89 44 24 08          	mov    %eax,0x8(%esp)
f01011eb:	8d 45 ec             	lea    -0x14(%ebp),%eax
f01011ee:	89 44 24 04          	mov    %eax,0x4(%esp)
f01011f2:	c7 04 24 8f 0d 10 f0 	movl   $0xf0100d8f,(%esp)
f01011f9:	e8 d6 fb ff ff       	call   f0100dd4 <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f01011fe:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0101201:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0101204:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101207:	eb 05                	jmp    f010120e <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f0101209:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f010120e:	c9                   	leave  
f010120f:	c3                   	ret    

f0101210 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f0101210:	55                   	push   %ebp
f0101211:	89 e5                	mov    %esp,%ebp
f0101213:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0101216:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f0101219:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010121d:	8b 45 10             	mov    0x10(%ebp),%eax
f0101220:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101224:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101227:	89 44 24 04          	mov    %eax,0x4(%esp)
f010122b:	8b 45 08             	mov    0x8(%ebp),%eax
f010122e:	89 04 24             	mov    %eax,(%esp)
f0101231:	e8 82 ff ff ff       	call   f01011b8 <vsnprintf>
	va_end(ap);

	return rc;
}
f0101236:	c9                   	leave  
f0101237:	c3                   	ret    
f0101238:	66 90                	xchg   %ax,%ax
f010123a:	66 90                	xchg   %ax,%ax
f010123c:	66 90                	xchg   %ax,%ax
f010123e:	66 90                	xchg   %ax,%ax

f0101240 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0101240:	55                   	push   %ebp
f0101241:	89 e5                	mov    %esp,%ebp
f0101243:	57                   	push   %edi
f0101244:	56                   	push   %esi
f0101245:	53                   	push   %ebx
f0101246:	83 ec 1c             	sub    $0x1c,%esp
f0101249:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f010124c:	85 c0                	test   %eax,%eax
f010124e:	74 10                	je     f0101260 <readline+0x20>
		cprintf("%s", prompt);
f0101250:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101254:	c7 04 24 0e 1f 10 f0 	movl   $0xf0101f0e,(%esp)
f010125b:	e8 ef f6 ff ff       	call   f010094f <cprintf>

	i = 0;
	echoing = iscons(0);
f0101260:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101267:	e8 19 f4 ff ff       	call   f0100685 <iscons>
f010126c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f010126e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0101273:	e8 fc f3 ff ff       	call   f0100674 <getchar>
f0101278:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f010127a:	85 c0                	test   %eax,%eax
f010127c:	79 17                	jns    f0101295 <readline+0x55>
			cprintf("read error: %e\n", c);
f010127e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101282:	c7 04 24 f0 20 10 f0 	movl   $0xf01020f0,(%esp)
f0101289:	e8 c1 f6 ff ff       	call   f010094f <cprintf>
			return NULL;
f010128e:	b8 00 00 00 00       	mov    $0x0,%eax
f0101293:	eb 6d                	jmp    f0101302 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0101295:	83 f8 7f             	cmp    $0x7f,%eax
f0101298:	74 05                	je     f010129f <readline+0x5f>
f010129a:	83 f8 08             	cmp    $0x8,%eax
f010129d:	75 19                	jne    f01012b8 <readline+0x78>
f010129f:	85 f6                	test   %esi,%esi
f01012a1:	7e 15                	jle    f01012b8 <readline+0x78>
			if (echoing)
f01012a3:	85 ff                	test   %edi,%edi
f01012a5:	74 0c                	je     f01012b3 <readline+0x73>
				cputchar('\b');
f01012a7:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f01012ae:	e8 b1 f3 ff ff       	call   f0100664 <cputchar>
			i--;
f01012b3:	83 ee 01             	sub    $0x1,%esi
f01012b6:	eb bb                	jmp    f0101273 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f01012b8:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f01012be:	7f 1c                	jg     f01012dc <readline+0x9c>
f01012c0:	83 fb 1f             	cmp    $0x1f,%ebx
f01012c3:	7e 17                	jle    f01012dc <readline+0x9c>
			if (echoing)
f01012c5:	85 ff                	test   %edi,%edi
f01012c7:	74 08                	je     f01012d1 <readline+0x91>
				cputchar(c);
f01012c9:	89 1c 24             	mov    %ebx,(%esp)
f01012cc:	e8 93 f3 ff ff       	call   f0100664 <cputchar>
			buf[i++] = c;
f01012d1:	88 9e 60 25 11 f0    	mov    %bl,-0xfeedaa0(%esi)
f01012d7:	8d 76 01             	lea    0x1(%esi),%esi
f01012da:	eb 97                	jmp    f0101273 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f01012dc:	83 fb 0d             	cmp    $0xd,%ebx
f01012df:	74 05                	je     f01012e6 <readline+0xa6>
f01012e1:	83 fb 0a             	cmp    $0xa,%ebx
f01012e4:	75 8d                	jne    f0101273 <readline+0x33>
			if (echoing)
f01012e6:	85 ff                	test   %edi,%edi
f01012e8:	74 0c                	je     f01012f6 <readline+0xb6>
				cputchar('\n');
f01012ea:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f01012f1:	e8 6e f3 ff ff       	call   f0100664 <cputchar>
			buf[i] = 0;
f01012f6:	c6 86 60 25 11 f0 00 	movb   $0x0,-0xfeedaa0(%esi)
			return buf;
f01012fd:	b8 60 25 11 f0       	mov    $0xf0112560,%eax
		}
	}
}
f0101302:	83 c4 1c             	add    $0x1c,%esp
f0101305:	5b                   	pop    %ebx
f0101306:	5e                   	pop    %esi
f0101307:	5f                   	pop    %edi
f0101308:	5d                   	pop    %ebp
f0101309:	c3                   	ret    
f010130a:	66 90                	xchg   %ax,%ax
f010130c:	66 90                	xchg   %ax,%ax
f010130e:	66 90                	xchg   %ax,%ax

f0101310 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0101310:	55                   	push   %ebp
f0101311:	89 e5                	mov    %esp,%ebp
f0101313:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0101316:	80 3a 00             	cmpb   $0x0,(%edx)
f0101319:	74 10                	je     f010132b <strlen+0x1b>
f010131b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f0101320:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0101323:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0101327:	75 f7                	jne    f0101320 <strlen+0x10>
f0101329:	eb 05                	jmp    f0101330 <strlen+0x20>
f010132b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0101330:	5d                   	pop    %ebp
f0101331:	c3                   	ret    

f0101332 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0101332:	55                   	push   %ebp
f0101333:	89 e5                	mov    %esp,%ebp
f0101335:	53                   	push   %ebx
f0101336:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0101339:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010133c:	85 c9                	test   %ecx,%ecx
f010133e:	74 1c                	je     f010135c <strnlen+0x2a>
f0101340:	80 3b 00             	cmpb   $0x0,(%ebx)
f0101343:	74 1e                	je     f0101363 <strnlen+0x31>
f0101345:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f010134a:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010134c:	39 ca                	cmp    %ecx,%edx
f010134e:	74 18                	je     f0101368 <strnlen+0x36>
f0101350:	83 c2 01             	add    $0x1,%edx
f0101353:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0101358:	75 f0                	jne    f010134a <strnlen+0x18>
f010135a:	eb 0c                	jmp    f0101368 <strnlen+0x36>
f010135c:	b8 00 00 00 00       	mov    $0x0,%eax
f0101361:	eb 05                	jmp    f0101368 <strnlen+0x36>
f0101363:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0101368:	5b                   	pop    %ebx
f0101369:	5d                   	pop    %ebp
f010136a:	c3                   	ret    

f010136b <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f010136b:	55                   	push   %ebp
f010136c:	89 e5                	mov    %esp,%ebp
f010136e:	53                   	push   %ebx
f010136f:	8b 45 08             	mov    0x8(%ebp),%eax
f0101372:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0101375:	89 c2                	mov    %eax,%edx
f0101377:	83 c2 01             	add    $0x1,%edx
f010137a:	83 c1 01             	add    $0x1,%ecx
f010137d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0101381:	88 5a ff             	mov    %bl,-0x1(%edx)
f0101384:	84 db                	test   %bl,%bl
f0101386:	75 ef                	jne    f0101377 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0101388:	5b                   	pop    %ebx
f0101389:	5d                   	pop    %ebp
f010138a:	c3                   	ret    

f010138b <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f010138b:	55                   	push   %ebp
f010138c:	89 e5                	mov    %esp,%ebp
f010138e:	56                   	push   %esi
f010138f:	53                   	push   %ebx
f0101390:	8b 75 08             	mov    0x8(%ebp),%esi
f0101393:	8b 55 0c             	mov    0xc(%ebp),%edx
f0101396:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0101399:	85 db                	test   %ebx,%ebx
f010139b:	74 17                	je     f01013b4 <strncpy+0x29>
f010139d:	01 f3                	add    %esi,%ebx
f010139f:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f01013a1:	83 c1 01             	add    $0x1,%ecx
f01013a4:	0f b6 02             	movzbl (%edx),%eax
f01013a7:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f01013aa:	80 3a 01             	cmpb   $0x1,(%edx)
f01013ad:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f01013b0:	39 d9                	cmp    %ebx,%ecx
f01013b2:	75 ed                	jne    f01013a1 <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f01013b4:	89 f0                	mov    %esi,%eax
f01013b6:	5b                   	pop    %ebx
f01013b7:	5e                   	pop    %esi
f01013b8:	5d                   	pop    %ebp
f01013b9:	c3                   	ret    

f01013ba <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f01013ba:	55                   	push   %ebp
f01013bb:	89 e5                	mov    %esp,%ebp
f01013bd:	57                   	push   %edi
f01013be:	56                   	push   %esi
f01013bf:	53                   	push   %ebx
f01013c0:	8b 7d 08             	mov    0x8(%ebp),%edi
f01013c3:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01013c6:	8b 75 10             	mov    0x10(%ebp),%esi
f01013c9:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f01013cb:	85 f6                	test   %esi,%esi
f01013cd:	74 34                	je     f0101403 <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f01013cf:	83 fe 01             	cmp    $0x1,%esi
f01013d2:	74 26                	je     f01013fa <strlcpy+0x40>
f01013d4:	0f b6 0b             	movzbl (%ebx),%ecx
f01013d7:	84 c9                	test   %cl,%cl
f01013d9:	74 23                	je     f01013fe <strlcpy+0x44>
f01013db:	83 ee 02             	sub    $0x2,%esi
f01013de:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f01013e3:	83 c0 01             	add    $0x1,%eax
f01013e6:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f01013e9:	39 f2                	cmp    %esi,%edx
f01013eb:	74 13                	je     f0101400 <strlcpy+0x46>
f01013ed:	83 c2 01             	add    $0x1,%edx
f01013f0:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f01013f4:	84 c9                	test   %cl,%cl
f01013f6:	75 eb                	jne    f01013e3 <strlcpy+0x29>
f01013f8:	eb 06                	jmp    f0101400 <strlcpy+0x46>
f01013fa:	89 f8                	mov    %edi,%eax
f01013fc:	eb 02                	jmp    f0101400 <strlcpy+0x46>
f01013fe:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f0101400:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f0101403:	29 f8                	sub    %edi,%eax
}
f0101405:	5b                   	pop    %ebx
f0101406:	5e                   	pop    %esi
f0101407:	5f                   	pop    %edi
f0101408:	5d                   	pop    %ebp
f0101409:	c3                   	ret    

f010140a <strcmp>:

int
strcmp(const char *p, const char *q)
{
f010140a:	55                   	push   %ebp
f010140b:	89 e5                	mov    %esp,%ebp
f010140d:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0101410:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f0101413:	0f b6 01             	movzbl (%ecx),%eax
f0101416:	84 c0                	test   %al,%al
f0101418:	74 15                	je     f010142f <strcmp+0x25>
f010141a:	3a 02                	cmp    (%edx),%al
f010141c:	75 11                	jne    f010142f <strcmp+0x25>
		p++, q++;
f010141e:	83 c1 01             	add    $0x1,%ecx
f0101421:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f0101424:	0f b6 01             	movzbl (%ecx),%eax
f0101427:	84 c0                	test   %al,%al
f0101429:	74 04                	je     f010142f <strcmp+0x25>
f010142b:	3a 02                	cmp    (%edx),%al
f010142d:	74 ef                	je     f010141e <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f010142f:	0f b6 c0             	movzbl %al,%eax
f0101432:	0f b6 12             	movzbl (%edx),%edx
f0101435:	29 d0                	sub    %edx,%eax
}
f0101437:	5d                   	pop    %ebp
f0101438:	c3                   	ret    

f0101439 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0101439:	55                   	push   %ebp
f010143a:	89 e5                	mov    %esp,%ebp
f010143c:	56                   	push   %esi
f010143d:	53                   	push   %ebx
f010143e:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0101441:	8b 55 0c             	mov    0xc(%ebp),%edx
f0101444:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f0101447:	85 f6                	test   %esi,%esi
f0101449:	74 29                	je     f0101474 <strncmp+0x3b>
f010144b:	0f b6 03             	movzbl (%ebx),%eax
f010144e:	84 c0                	test   %al,%al
f0101450:	74 30                	je     f0101482 <strncmp+0x49>
f0101452:	3a 02                	cmp    (%edx),%al
f0101454:	75 2c                	jne    f0101482 <strncmp+0x49>
f0101456:	8d 43 01             	lea    0x1(%ebx),%eax
f0101459:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f010145b:	89 c3                	mov    %eax,%ebx
f010145d:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f0101460:	39 f0                	cmp    %esi,%eax
f0101462:	74 17                	je     f010147b <strncmp+0x42>
f0101464:	0f b6 08             	movzbl (%eax),%ecx
f0101467:	84 c9                	test   %cl,%cl
f0101469:	74 17                	je     f0101482 <strncmp+0x49>
f010146b:	83 c0 01             	add    $0x1,%eax
f010146e:	3a 0a                	cmp    (%edx),%cl
f0101470:	74 e9                	je     f010145b <strncmp+0x22>
f0101472:	eb 0e                	jmp    f0101482 <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f0101474:	b8 00 00 00 00       	mov    $0x0,%eax
f0101479:	eb 0f                	jmp    f010148a <strncmp+0x51>
f010147b:	b8 00 00 00 00       	mov    $0x0,%eax
f0101480:	eb 08                	jmp    f010148a <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f0101482:	0f b6 03             	movzbl (%ebx),%eax
f0101485:	0f b6 12             	movzbl (%edx),%edx
f0101488:	29 d0                	sub    %edx,%eax
}
f010148a:	5b                   	pop    %ebx
f010148b:	5e                   	pop    %esi
f010148c:	5d                   	pop    %ebp
f010148d:	c3                   	ret    

f010148e <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f010148e:	55                   	push   %ebp
f010148f:	89 e5                	mov    %esp,%ebp
f0101491:	53                   	push   %ebx
f0101492:	8b 45 08             	mov    0x8(%ebp),%eax
f0101495:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0101498:	0f b6 18             	movzbl (%eax),%ebx
f010149b:	84 db                	test   %bl,%bl
f010149d:	74 1d                	je     f01014bc <strchr+0x2e>
f010149f:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f01014a1:	38 d3                	cmp    %dl,%bl
f01014a3:	75 06                	jne    f01014ab <strchr+0x1d>
f01014a5:	eb 1a                	jmp    f01014c1 <strchr+0x33>
f01014a7:	38 ca                	cmp    %cl,%dl
f01014a9:	74 16                	je     f01014c1 <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f01014ab:	83 c0 01             	add    $0x1,%eax
f01014ae:	0f b6 10             	movzbl (%eax),%edx
f01014b1:	84 d2                	test   %dl,%dl
f01014b3:	75 f2                	jne    f01014a7 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f01014b5:	b8 00 00 00 00       	mov    $0x0,%eax
f01014ba:	eb 05                	jmp    f01014c1 <strchr+0x33>
f01014bc:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01014c1:	5b                   	pop    %ebx
f01014c2:	5d                   	pop    %ebp
f01014c3:	c3                   	ret    

f01014c4 <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f01014c4:	55                   	push   %ebp
f01014c5:	89 e5                	mov    %esp,%ebp
f01014c7:	53                   	push   %ebx
f01014c8:	8b 45 08             	mov    0x8(%ebp),%eax
f01014cb:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f01014ce:	0f b6 18             	movzbl (%eax),%ebx
f01014d1:	84 db                	test   %bl,%bl
f01014d3:	74 17                	je     f01014ec <strfind+0x28>
f01014d5:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f01014d7:	38 d3                	cmp    %dl,%bl
f01014d9:	75 07                	jne    f01014e2 <strfind+0x1e>
f01014db:	eb 0f                	jmp    f01014ec <strfind+0x28>
f01014dd:	38 ca                	cmp    %cl,%dl
f01014df:	90                   	nop
f01014e0:	74 0a                	je     f01014ec <strfind+0x28>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f01014e2:	83 c0 01             	add    $0x1,%eax
f01014e5:	0f b6 10             	movzbl (%eax),%edx
f01014e8:	84 d2                	test   %dl,%dl
f01014ea:	75 f1                	jne    f01014dd <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f01014ec:	5b                   	pop    %ebx
f01014ed:	5d                   	pop    %ebp
f01014ee:	c3                   	ret    

f01014ef <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f01014ef:	55                   	push   %ebp
f01014f0:	89 e5                	mov    %esp,%ebp
f01014f2:	57                   	push   %edi
f01014f3:	56                   	push   %esi
f01014f4:	53                   	push   %ebx
f01014f5:	8b 7d 08             	mov    0x8(%ebp),%edi
f01014f8:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f01014fb:	85 c9                	test   %ecx,%ecx
f01014fd:	74 36                	je     f0101535 <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f01014ff:	f7 c7 03 00 00 00    	test   $0x3,%edi
f0101505:	75 28                	jne    f010152f <memset+0x40>
f0101507:	f6 c1 03             	test   $0x3,%cl
f010150a:	75 23                	jne    f010152f <memset+0x40>
		c &= 0xFF;
f010150c:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f0101510:	89 d3                	mov    %edx,%ebx
f0101512:	c1 e3 08             	shl    $0x8,%ebx
f0101515:	89 d6                	mov    %edx,%esi
f0101517:	c1 e6 18             	shl    $0x18,%esi
f010151a:	89 d0                	mov    %edx,%eax
f010151c:	c1 e0 10             	shl    $0x10,%eax
f010151f:	09 f0                	or     %esi,%eax
f0101521:	09 c2                	or     %eax,%edx
f0101523:	89 d0                	mov    %edx,%eax
f0101525:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f0101527:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f010152a:	fc                   	cld    
f010152b:	f3 ab                	rep stos %eax,%es:(%edi)
f010152d:	eb 06                	jmp    f0101535 <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f010152f:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101532:	fc                   	cld    
f0101533:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f0101535:	89 f8                	mov    %edi,%eax
f0101537:	5b                   	pop    %ebx
f0101538:	5e                   	pop    %esi
f0101539:	5f                   	pop    %edi
f010153a:	5d                   	pop    %ebp
f010153b:	c3                   	ret    

f010153c <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f010153c:	55                   	push   %ebp
f010153d:	89 e5                	mov    %esp,%ebp
f010153f:	57                   	push   %edi
f0101540:	56                   	push   %esi
f0101541:	8b 45 08             	mov    0x8(%ebp),%eax
f0101544:	8b 75 0c             	mov    0xc(%ebp),%esi
f0101547:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f010154a:	39 c6                	cmp    %eax,%esi
f010154c:	73 35                	jae    f0101583 <memmove+0x47>
f010154e:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0101551:	39 d0                	cmp    %edx,%eax
f0101553:	73 2e                	jae    f0101583 <memmove+0x47>
		s += n;
		d += n;
f0101555:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0101558:	89 d6                	mov    %edx,%esi
f010155a:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f010155c:	f7 c6 03 00 00 00    	test   $0x3,%esi
f0101562:	75 13                	jne    f0101577 <memmove+0x3b>
f0101564:	f6 c1 03             	test   $0x3,%cl
f0101567:	75 0e                	jne    f0101577 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0101569:	83 ef 04             	sub    $0x4,%edi
f010156c:	8d 72 fc             	lea    -0x4(%edx),%esi
f010156f:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f0101572:	fd                   	std    
f0101573:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0101575:	eb 09                	jmp    f0101580 <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0101577:	83 ef 01             	sub    $0x1,%edi
f010157a:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f010157d:	fd                   	std    
f010157e:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0101580:	fc                   	cld    
f0101581:	eb 1d                	jmp    f01015a0 <memmove+0x64>
f0101583:	89 f2                	mov    %esi,%edx
f0101585:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0101587:	f6 c2 03             	test   $0x3,%dl
f010158a:	75 0f                	jne    f010159b <memmove+0x5f>
f010158c:	f6 c1 03             	test   $0x3,%cl
f010158f:	75 0a                	jne    f010159b <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0101591:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f0101594:	89 c7                	mov    %eax,%edi
f0101596:	fc                   	cld    
f0101597:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0101599:	eb 05                	jmp    f01015a0 <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f010159b:	89 c7                	mov    %eax,%edi
f010159d:	fc                   	cld    
f010159e:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f01015a0:	5e                   	pop    %esi
f01015a1:	5f                   	pop    %edi
f01015a2:	5d                   	pop    %ebp
f01015a3:	c3                   	ret    

f01015a4 <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f01015a4:	55                   	push   %ebp
f01015a5:	89 e5                	mov    %esp,%ebp
f01015a7:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f01015aa:	8b 45 10             	mov    0x10(%ebp),%eax
f01015ad:	89 44 24 08          	mov    %eax,0x8(%esp)
f01015b1:	8b 45 0c             	mov    0xc(%ebp),%eax
f01015b4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01015b8:	8b 45 08             	mov    0x8(%ebp),%eax
f01015bb:	89 04 24             	mov    %eax,(%esp)
f01015be:	e8 79 ff ff ff       	call   f010153c <memmove>
}
f01015c3:	c9                   	leave  
f01015c4:	c3                   	ret    

f01015c5 <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f01015c5:	55                   	push   %ebp
f01015c6:	89 e5                	mov    %esp,%ebp
f01015c8:	57                   	push   %edi
f01015c9:	56                   	push   %esi
f01015ca:	53                   	push   %ebx
f01015cb:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01015ce:	8b 75 0c             	mov    0xc(%ebp),%esi
f01015d1:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01015d4:	8d 78 ff             	lea    -0x1(%eax),%edi
f01015d7:	85 c0                	test   %eax,%eax
f01015d9:	74 36                	je     f0101611 <memcmp+0x4c>
		if (*s1 != *s2)
f01015db:	0f b6 03             	movzbl (%ebx),%eax
f01015de:	0f b6 0e             	movzbl (%esi),%ecx
f01015e1:	ba 00 00 00 00       	mov    $0x0,%edx
f01015e6:	38 c8                	cmp    %cl,%al
f01015e8:	74 1c                	je     f0101606 <memcmp+0x41>
f01015ea:	eb 10                	jmp    f01015fc <memcmp+0x37>
f01015ec:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f01015f1:	83 c2 01             	add    $0x1,%edx
f01015f4:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f01015f8:	38 c8                	cmp    %cl,%al
f01015fa:	74 0a                	je     f0101606 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f01015fc:	0f b6 c0             	movzbl %al,%eax
f01015ff:	0f b6 c9             	movzbl %cl,%ecx
f0101602:	29 c8                	sub    %ecx,%eax
f0101604:	eb 10                	jmp    f0101616 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0101606:	39 fa                	cmp    %edi,%edx
f0101608:	75 e2                	jne    f01015ec <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f010160a:	b8 00 00 00 00       	mov    $0x0,%eax
f010160f:	eb 05                	jmp    f0101616 <memcmp+0x51>
f0101611:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0101616:	5b                   	pop    %ebx
f0101617:	5e                   	pop    %esi
f0101618:	5f                   	pop    %edi
f0101619:	5d                   	pop    %ebp
f010161a:	c3                   	ret    

f010161b <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f010161b:	55                   	push   %ebp
f010161c:	89 e5                	mov    %esp,%ebp
f010161e:	53                   	push   %ebx
f010161f:	8b 45 08             	mov    0x8(%ebp),%eax
f0101622:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f0101625:	89 c2                	mov    %eax,%edx
f0101627:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f010162a:	39 d0                	cmp    %edx,%eax
f010162c:	73 14                	jae    f0101642 <memfind+0x27>
		if (*(const unsigned char *) s == (unsigned char) c)
f010162e:	89 d9                	mov    %ebx,%ecx
f0101630:	38 18                	cmp    %bl,(%eax)
f0101632:	75 06                	jne    f010163a <memfind+0x1f>
f0101634:	eb 0c                	jmp    f0101642 <memfind+0x27>
f0101636:	38 08                	cmp    %cl,(%eax)
f0101638:	74 08                	je     f0101642 <memfind+0x27>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f010163a:	83 c0 01             	add    $0x1,%eax
f010163d:	39 d0                	cmp    %edx,%eax
f010163f:	90                   	nop
f0101640:	75 f4                	jne    f0101636 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f0101642:	5b                   	pop    %ebx
f0101643:	5d                   	pop    %ebp
f0101644:	c3                   	ret    

f0101645 <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f0101645:	55                   	push   %ebp
f0101646:	89 e5                	mov    %esp,%ebp
f0101648:	57                   	push   %edi
f0101649:	56                   	push   %esi
f010164a:	53                   	push   %ebx
f010164b:	8b 55 08             	mov    0x8(%ebp),%edx
f010164e:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0101651:	0f b6 0a             	movzbl (%edx),%ecx
f0101654:	80 f9 09             	cmp    $0x9,%cl
f0101657:	74 05                	je     f010165e <strtol+0x19>
f0101659:	80 f9 20             	cmp    $0x20,%cl
f010165c:	75 10                	jne    f010166e <strtol+0x29>
		s++;
f010165e:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0101661:	0f b6 0a             	movzbl (%edx),%ecx
f0101664:	80 f9 09             	cmp    $0x9,%cl
f0101667:	74 f5                	je     f010165e <strtol+0x19>
f0101669:	80 f9 20             	cmp    $0x20,%cl
f010166c:	74 f0                	je     f010165e <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f010166e:	80 f9 2b             	cmp    $0x2b,%cl
f0101671:	75 0a                	jne    f010167d <strtol+0x38>
		s++;
f0101673:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f0101676:	bf 00 00 00 00       	mov    $0x0,%edi
f010167b:	eb 11                	jmp    f010168e <strtol+0x49>
f010167d:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f0101682:	80 f9 2d             	cmp    $0x2d,%cl
f0101685:	75 07                	jne    f010168e <strtol+0x49>
		s++, neg = 1;
f0101687:	83 c2 01             	add    $0x1,%edx
f010168a:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f010168e:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f0101693:	75 15                	jne    f01016aa <strtol+0x65>
f0101695:	80 3a 30             	cmpb   $0x30,(%edx)
f0101698:	75 10                	jne    f01016aa <strtol+0x65>
f010169a:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f010169e:	75 0a                	jne    f01016aa <strtol+0x65>
		s += 2, base = 16;
f01016a0:	83 c2 02             	add    $0x2,%edx
f01016a3:	b8 10 00 00 00       	mov    $0x10,%eax
f01016a8:	eb 10                	jmp    f01016ba <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f01016aa:	85 c0                	test   %eax,%eax
f01016ac:	75 0c                	jne    f01016ba <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f01016ae:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f01016b0:	80 3a 30             	cmpb   $0x30,(%edx)
f01016b3:	75 05                	jne    f01016ba <strtol+0x75>
		s++, base = 8;
f01016b5:	83 c2 01             	add    $0x1,%edx
f01016b8:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f01016ba:	bb 00 00 00 00       	mov    $0x0,%ebx
f01016bf:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f01016c2:	0f b6 0a             	movzbl (%edx),%ecx
f01016c5:	8d 71 d0             	lea    -0x30(%ecx),%esi
f01016c8:	89 f0                	mov    %esi,%eax
f01016ca:	3c 09                	cmp    $0x9,%al
f01016cc:	77 08                	ja     f01016d6 <strtol+0x91>
			dig = *s - '0';
f01016ce:	0f be c9             	movsbl %cl,%ecx
f01016d1:	83 e9 30             	sub    $0x30,%ecx
f01016d4:	eb 20                	jmp    f01016f6 <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f01016d6:	8d 71 9f             	lea    -0x61(%ecx),%esi
f01016d9:	89 f0                	mov    %esi,%eax
f01016db:	3c 19                	cmp    $0x19,%al
f01016dd:	77 08                	ja     f01016e7 <strtol+0xa2>
			dig = *s - 'a' + 10;
f01016df:	0f be c9             	movsbl %cl,%ecx
f01016e2:	83 e9 57             	sub    $0x57,%ecx
f01016e5:	eb 0f                	jmp    f01016f6 <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f01016e7:	8d 71 bf             	lea    -0x41(%ecx),%esi
f01016ea:	89 f0                	mov    %esi,%eax
f01016ec:	3c 19                	cmp    $0x19,%al
f01016ee:	77 16                	ja     f0101706 <strtol+0xc1>
			dig = *s - 'A' + 10;
f01016f0:	0f be c9             	movsbl %cl,%ecx
f01016f3:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f01016f6:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f01016f9:	7d 0f                	jge    f010170a <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f01016fb:	83 c2 01             	add    $0x1,%edx
f01016fe:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f0101702:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f0101704:	eb bc                	jmp    f01016c2 <strtol+0x7d>
f0101706:	89 d8                	mov    %ebx,%eax
f0101708:	eb 02                	jmp    f010170c <strtol+0xc7>
f010170a:	89 d8                	mov    %ebx,%eax

	if (endptr)
f010170c:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0101710:	74 05                	je     f0101717 <strtol+0xd2>
		*endptr = (char *) s;
f0101712:	8b 75 0c             	mov    0xc(%ebp),%esi
f0101715:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f0101717:	f7 d8                	neg    %eax
f0101719:	85 ff                	test   %edi,%edi
f010171b:	0f 44 c3             	cmove  %ebx,%eax
}
f010171e:	5b                   	pop    %ebx
f010171f:	5e                   	pop    %esi
f0101720:	5f                   	pop    %edi
f0101721:	5d                   	pop    %ebp
f0101722:	c3                   	ret    
f0101723:	66 90                	xchg   %ax,%ax
f0101725:	66 90                	xchg   %ax,%ax
f0101727:	66 90                	xchg   %ax,%ax
f0101729:	66 90                	xchg   %ax,%ax
f010172b:	66 90                	xchg   %ax,%ax
f010172d:	66 90                	xchg   %ax,%ax
f010172f:	90                   	nop

f0101730 <__udivdi3>:
f0101730:	55                   	push   %ebp
f0101731:	57                   	push   %edi
f0101732:	56                   	push   %esi
f0101733:	83 ec 0c             	sub    $0xc,%esp
f0101736:	8b 44 24 28          	mov    0x28(%esp),%eax
f010173a:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f010173e:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f0101742:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0101746:	85 c0                	test   %eax,%eax
f0101748:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010174c:	89 ea                	mov    %ebp,%edx
f010174e:	89 0c 24             	mov    %ecx,(%esp)
f0101751:	75 2d                	jne    f0101780 <__udivdi3+0x50>
f0101753:	39 e9                	cmp    %ebp,%ecx
f0101755:	77 61                	ja     f01017b8 <__udivdi3+0x88>
f0101757:	85 c9                	test   %ecx,%ecx
f0101759:	89 ce                	mov    %ecx,%esi
f010175b:	75 0b                	jne    f0101768 <__udivdi3+0x38>
f010175d:	b8 01 00 00 00       	mov    $0x1,%eax
f0101762:	31 d2                	xor    %edx,%edx
f0101764:	f7 f1                	div    %ecx
f0101766:	89 c6                	mov    %eax,%esi
f0101768:	31 d2                	xor    %edx,%edx
f010176a:	89 e8                	mov    %ebp,%eax
f010176c:	f7 f6                	div    %esi
f010176e:	89 c5                	mov    %eax,%ebp
f0101770:	89 f8                	mov    %edi,%eax
f0101772:	f7 f6                	div    %esi
f0101774:	89 ea                	mov    %ebp,%edx
f0101776:	83 c4 0c             	add    $0xc,%esp
f0101779:	5e                   	pop    %esi
f010177a:	5f                   	pop    %edi
f010177b:	5d                   	pop    %ebp
f010177c:	c3                   	ret    
f010177d:	8d 76 00             	lea    0x0(%esi),%esi
f0101780:	39 e8                	cmp    %ebp,%eax
f0101782:	77 24                	ja     f01017a8 <__udivdi3+0x78>
f0101784:	0f bd e8             	bsr    %eax,%ebp
f0101787:	83 f5 1f             	xor    $0x1f,%ebp
f010178a:	75 3c                	jne    f01017c8 <__udivdi3+0x98>
f010178c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0101790:	39 34 24             	cmp    %esi,(%esp)
f0101793:	0f 86 9f 00 00 00    	jbe    f0101838 <__udivdi3+0x108>
f0101799:	39 d0                	cmp    %edx,%eax
f010179b:	0f 82 97 00 00 00    	jb     f0101838 <__udivdi3+0x108>
f01017a1:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f01017a8:	31 d2                	xor    %edx,%edx
f01017aa:	31 c0                	xor    %eax,%eax
f01017ac:	83 c4 0c             	add    $0xc,%esp
f01017af:	5e                   	pop    %esi
f01017b0:	5f                   	pop    %edi
f01017b1:	5d                   	pop    %ebp
f01017b2:	c3                   	ret    
f01017b3:	90                   	nop
f01017b4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01017b8:	89 f8                	mov    %edi,%eax
f01017ba:	f7 f1                	div    %ecx
f01017bc:	31 d2                	xor    %edx,%edx
f01017be:	83 c4 0c             	add    $0xc,%esp
f01017c1:	5e                   	pop    %esi
f01017c2:	5f                   	pop    %edi
f01017c3:	5d                   	pop    %ebp
f01017c4:	c3                   	ret    
f01017c5:	8d 76 00             	lea    0x0(%esi),%esi
f01017c8:	89 e9                	mov    %ebp,%ecx
f01017ca:	8b 3c 24             	mov    (%esp),%edi
f01017cd:	d3 e0                	shl    %cl,%eax
f01017cf:	89 c6                	mov    %eax,%esi
f01017d1:	b8 20 00 00 00       	mov    $0x20,%eax
f01017d6:	29 e8                	sub    %ebp,%eax
f01017d8:	89 c1                	mov    %eax,%ecx
f01017da:	d3 ef                	shr    %cl,%edi
f01017dc:	89 e9                	mov    %ebp,%ecx
f01017de:	89 7c 24 08          	mov    %edi,0x8(%esp)
f01017e2:	8b 3c 24             	mov    (%esp),%edi
f01017e5:	09 74 24 08          	or     %esi,0x8(%esp)
f01017e9:	89 d6                	mov    %edx,%esi
f01017eb:	d3 e7                	shl    %cl,%edi
f01017ed:	89 c1                	mov    %eax,%ecx
f01017ef:	89 3c 24             	mov    %edi,(%esp)
f01017f2:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01017f6:	d3 ee                	shr    %cl,%esi
f01017f8:	89 e9                	mov    %ebp,%ecx
f01017fa:	d3 e2                	shl    %cl,%edx
f01017fc:	89 c1                	mov    %eax,%ecx
f01017fe:	d3 ef                	shr    %cl,%edi
f0101800:	09 d7                	or     %edx,%edi
f0101802:	89 f2                	mov    %esi,%edx
f0101804:	89 f8                	mov    %edi,%eax
f0101806:	f7 74 24 08          	divl   0x8(%esp)
f010180a:	89 d6                	mov    %edx,%esi
f010180c:	89 c7                	mov    %eax,%edi
f010180e:	f7 24 24             	mull   (%esp)
f0101811:	39 d6                	cmp    %edx,%esi
f0101813:	89 14 24             	mov    %edx,(%esp)
f0101816:	72 30                	jb     f0101848 <__udivdi3+0x118>
f0101818:	8b 54 24 04          	mov    0x4(%esp),%edx
f010181c:	89 e9                	mov    %ebp,%ecx
f010181e:	d3 e2                	shl    %cl,%edx
f0101820:	39 c2                	cmp    %eax,%edx
f0101822:	73 05                	jae    f0101829 <__udivdi3+0xf9>
f0101824:	3b 34 24             	cmp    (%esp),%esi
f0101827:	74 1f                	je     f0101848 <__udivdi3+0x118>
f0101829:	89 f8                	mov    %edi,%eax
f010182b:	31 d2                	xor    %edx,%edx
f010182d:	e9 7a ff ff ff       	jmp    f01017ac <__udivdi3+0x7c>
f0101832:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0101838:	31 d2                	xor    %edx,%edx
f010183a:	b8 01 00 00 00       	mov    $0x1,%eax
f010183f:	e9 68 ff ff ff       	jmp    f01017ac <__udivdi3+0x7c>
f0101844:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101848:	8d 47 ff             	lea    -0x1(%edi),%eax
f010184b:	31 d2                	xor    %edx,%edx
f010184d:	83 c4 0c             	add    $0xc,%esp
f0101850:	5e                   	pop    %esi
f0101851:	5f                   	pop    %edi
f0101852:	5d                   	pop    %ebp
f0101853:	c3                   	ret    
f0101854:	66 90                	xchg   %ax,%ax
f0101856:	66 90                	xchg   %ax,%ax
f0101858:	66 90                	xchg   %ax,%ax
f010185a:	66 90                	xchg   %ax,%ax
f010185c:	66 90                	xchg   %ax,%ax
f010185e:	66 90                	xchg   %ax,%ax

f0101860 <__umoddi3>:
f0101860:	55                   	push   %ebp
f0101861:	57                   	push   %edi
f0101862:	56                   	push   %esi
f0101863:	83 ec 14             	sub    $0x14,%esp
f0101866:	8b 44 24 28          	mov    0x28(%esp),%eax
f010186a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f010186e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0101872:	89 c7                	mov    %eax,%edi
f0101874:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101878:	8b 44 24 30          	mov    0x30(%esp),%eax
f010187c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0101880:	89 34 24             	mov    %esi,(%esp)
f0101883:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101887:	85 c0                	test   %eax,%eax
f0101889:	89 c2                	mov    %eax,%edx
f010188b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f010188f:	75 17                	jne    f01018a8 <__umoddi3+0x48>
f0101891:	39 fe                	cmp    %edi,%esi
f0101893:	76 4b                	jbe    f01018e0 <__umoddi3+0x80>
f0101895:	89 c8                	mov    %ecx,%eax
f0101897:	89 fa                	mov    %edi,%edx
f0101899:	f7 f6                	div    %esi
f010189b:	89 d0                	mov    %edx,%eax
f010189d:	31 d2                	xor    %edx,%edx
f010189f:	83 c4 14             	add    $0x14,%esp
f01018a2:	5e                   	pop    %esi
f01018a3:	5f                   	pop    %edi
f01018a4:	5d                   	pop    %ebp
f01018a5:	c3                   	ret    
f01018a6:	66 90                	xchg   %ax,%ax
f01018a8:	39 f8                	cmp    %edi,%eax
f01018aa:	77 54                	ja     f0101900 <__umoddi3+0xa0>
f01018ac:	0f bd e8             	bsr    %eax,%ebp
f01018af:	83 f5 1f             	xor    $0x1f,%ebp
f01018b2:	75 5c                	jne    f0101910 <__umoddi3+0xb0>
f01018b4:	8b 7c 24 08          	mov    0x8(%esp),%edi
f01018b8:	39 3c 24             	cmp    %edi,(%esp)
f01018bb:	0f 87 e7 00 00 00    	ja     f01019a8 <__umoddi3+0x148>
f01018c1:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01018c5:	29 f1                	sub    %esi,%ecx
f01018c7:	19 c7                	sbb    %eax,%edi
f01018c9:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01018cd:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01018d1:	8b 44 24 08          	mov    0x8(%esp),%eax
f01018d5:	8b 54 24 0c          	mov    0xc(%esp),%edx
f01018d9:	83 c4 14             	add    $0x14,%esp
f01018dc:	5e                   	pop    %esi
f01018dd:	5f                   	pop    %edi
f01018de:	5d                   	pop    %ebp
f01018df:	c3                   	ret    
f01018e0:	85 f6                	test   %esi,%esi
f01018e2:	89 f5                	mov    %esi,%ebp
f01018e4:	75 0b                	jne    f01018f1 <__umoddi3+0x91>
f01018e6:	b8 01 00 00 00       	mov    $0x1,%eax
f01018eb:	31 d2                	xor    %edx,%edx
f01018ed:	f7 f6                	div    %esi
f01018ef:	89 c5                	mov    %eax,%ebp
f01018f1:	8b 44 24 04          	mov    0x4(%esp),%eax
f01018f5:	31 d2                	xor    %edx,%edx
f01018f7:	f7 f5                	div    %ebp
f01018f9:	89 c8                	mov    %ecx,%eax
f01018fb:	f7 f5                	div    %ebp
f01018fd:	eb 9c                	jmp    f010189b <__umoddi3+0x3b>
f01018ff:	90                   	nop
f0101900:	89 c8                	mov    %ecx,%eax
f0101902:	89 fa                	mov    %edi,%edx
f0101904:	83 c4 14             	add    $0x14,%esp
f0101907:	5e                   	pop    %esi
f0101908:	5f                   	pop    %edi
f0101909:	5d                   	pop    %ebp
f010190a:	c3                   	ret    
f010190b:	90                   	nop
f010190c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101910:	8b 04 24             	mov    (%esp),%eax
f0101913:	be 20 00 00 00       	mov    $0x20,%esi
f0101918:	89 e9                	mov    %ebp,%ecx
f010191a:	29 ee                	sub    %ebp,%esi
f010191c:	d3 e2                	shl    %cl,%edx
f010191e:	89 f1                	mov    %esi,%ecx
f0101920:	d3 e8                	shr    %cl,%eax
f0101922:	89 e9                	mov    %ebp,%ecx
f0101924:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101928:	8b 04 24             	mov    (%esp),%eax
f010192b:	09 54 24 04          	or     %edx,0x4(%esp)
f010192f:	89 fa                	mov    %edi,%edx
f0101931:	d3 e0                	shl    %cl,%eax
f0101933:	89 f1                	mov    %esi,%ecx
f0101935:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101939:	8b 44 24 10          	mov    0x10(%esp),%eax
f010193d:	d3 ea                	shr    %cl,%edx
f010193f:	89 e9                	mov    %ebp,%ecx
f0101941:	d3 e7                	shl    %cl,%edi
f0101943:	89 f1                	mov    %esi,%ecx
f0101945:	d3 e8                	shr    %cl,%eax
f0101947:	89 e9                	mov    %ebp,%ecx
f0101949:	09 f8                	or     %edi,%eax
f010194b:	8b 7c 24 10          	mov    0x10(%esp),%edi
f010194f:	f7 74 24 04          	divl   0x4(%esp)
f0101953:	d3 e7                	shl    %cl,%edi
f0101955:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0101959:	89 d7                	mov    %edx,%edi
f010195b:	f7 64 24 08          	mull   0x8(%esp)
f010195f:	39 d7                	cmp    %edx,%edi
f0101961:	89 c1                	mov    %eax,%ecx
f0101963:	89 14 24             	mov    %edx,(%esp)
f0101966:	72 2c                	jb     f0101994 <__umoddi3+0x134>
f0101968:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f010196c:	72 22                	jb     f0101990 <__umoddi3+0x130>
f010196e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0101972:	29 c8                	sub    %ecx,%eax
f0101974:	19 d7                	sbb    %edx,%edi
f0101976:	89 e9                	mov    %ebp,%ecx
f0101978:	89 fa                	mov    %edi,%edx
f010197a:	d3 e8                	shr    %cl,%eax
f010197c:	89 f1                	mov    %esi,%ecx
f010197e:	d3 e2                	shl    %cl,%edx
f0101980:	89 e9                	mov    %ebp,%ecx
f0101982:	d3 ef                	shr    %cl,%edi
f0101984:	09 d0                	or     %edx,%eax
f0101986:	89 fa                	mov    %edi,%edx
f0101988:	83 c4 14             	add    $0x14,%esp
f010198b:	5e                   	pop    %esi
f010198c:	5f                   	pop    %edi
f010198d:	5d                   	pop    %ebp
f010198e:	c3                   	ret    
f010198f:	90                   	nop
f0101990:	39 d7                	cmp    %edx,%edi
f0101992:	75 da                	jne    f010196e <__umoddi3+0x10e>
f0101994:	8b 14 24             	mov    (%esp),%edx
f0101997:	89 c1                	mov    %eax,%ecx
f0101999:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f010199d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f01019a1:	eb cb                	jmp    f010196e <__umoddi3+0x10e>
f01019a3:	90                   	nop
f01019a4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01019a8:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f01019ac:	0f 82 0f ff ff ff    	jb     f01018c1 <__umoddi3+0x61>
f01019b2:	e9 1a ff ff ff       	jmp    f01018d1 <__umoddi3+0x71>
