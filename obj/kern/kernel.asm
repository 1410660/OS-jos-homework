
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
f010004e:	c7 04 24 60 1a 10 f0 	movl   $0xf0101a60,(%esp)
f0100055:	e8 86 09 00 00       	call   f01009e0 <cprintf>
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
f0100082:	e8 43 07 00 00       	call   f01007ca <mon_backtrace>
	cprintf("leaving test_backtrace %d\n", x);
f0100087:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010008b:	c7 04 24 7c 1a 10 f0 	movl   $0xf0101a7c,(%esp)
f0100092:	e8 49 09 00 00       	call   f01009e0 <cprintf>
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
f01000c0:	e8 ba 14 00 00       	call   f010157f <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000c5:	e8 a5 04 00 00       	call   f010056f <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000ca:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000d1:	00 
f01000d2:	c7 04 24 97 1a 10 f0 	movl   $0xf0101a97,(%esp)
f01000d9:	e8 02 09 00 00       	call   f01009e0 <cprintf>

	// Test the stack backtrace function (lab 1 only)
	test_backtrace(5);
f01000de:	c7 04 24 05 00 00 00 	movl   $0x5,(%esp)
f01000e5:	e8 56 ff ff ff       	call   f0100040 <test_backtrace>

	// Drop into the kernel monitor.
	while (1)
		monitor(NULL);
f01000ea:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000f1:	e8 60 07 00 00       	call   f0100856 <monitor>
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
f0100125:	c7 04 24 b2 1a 10 f0 	movl   $0xf0101ab2,(%esp)
f010012c:	e8 af 08 00 00       	call   f01009e0 <cprintf>
	vcprintf(fmt, ap);
f0100131:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100135:	89 34 24             	mov    %esi,(%esp)
f0100138:	e8 70 08 00 00       	call   f01009ad <vcprintf>
	cprintf("\n");
f010013d:	c7 04 24 ee 1a 10 f0 	movl   $0xf0101aee,(%esp)
f0100144:	e8 97 08 00 00       	call   f01009e0 <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f0100149:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0100150:	e8 01 07 00 00       	call   f0100856 <monitor>
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
f010016f:	c7 04 24 ca 1a 10 f0 	movl   $0xf0101aca,(%esp)
f0100176:	e8 65 08 00 00       	call   f01009e0 <cprintf>
	vcprintf(fmt, ap);
f010017b:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010017f:	8b 45 10             	mov    0x10(%ebp),%eax
f0100182:	89 04 24             	mov    %eax,(%esp)
f0100185:	e8 23 08 00 00       	call   f01009ad <vcprintf>
	cprintf("\n");
f010018a:	c7 04 24 ee 1a 10 f0 	movl   $0xf0101aee,(%esp)
f0100191:	e8 4a 08 00 00       	call   f01009e0 <cprintf>
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
f0100245:	0f b6 82 40 1c 10 f0 	movzbl -0xfefe3c0(%edx),%eax
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
f0100282:	0f b6 82 40 1c 10 f0 	movzbl -0xfefe3c0(%edx),%eax
f0100289:	0b 05 20 23 11 f0    	or     0xf0112320,%eax
	shift ^= togglecode[data];
f010028f:	0f b6 8a 40 1b 10 f0 	movzbl -0xfefe4c0(%edx),%ecx
f0100296:	31 c8                	xor    %ecx,%eax
f0100298:	a3 20 23 11 f0       	mov    %eax,0xf0112320

	c = charcode[shift & (CTL | SHIFT)][data];
f010029d:	89 c1                	mov    %eax,%ecx
f010029f:	83 e1 03             	and    $0x3,%ecx
f01002a2:	8b 0c 8d 20 1b 10 f0 	mov    -0xfefe4e0(,%ecx,4),%ecx
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
f01002e2:	c7 04 24 e4 1a 10 f0 	movl   $0xf0101ae4,(%esp)
f01002e9:	e8 f2 06 00 00       	call   f01009e0 <cprintf>
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
f0100499:	e8 2e 11 00 00       	call   f01015cc <memmove>
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
f0100650:	c7 04 24 f0 1a 10 f0 	movl   $0xf0101af0,(%esp)
f0100657:	e8 84 03 00 00       	call   f01009e0 <cprintf>
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
f0100696:	c7 44 24 08 40 1d 10 	movl   $0xf0101d40,0x8(%esp)
f010069d:	f0 
f010069e:	c7 44 24 04 5e 1d 10 	movl   $0xf0101d5e,0x4(%esp)
f01006a5:	f0 
f01006a6:	c7 04 24 63 1d 10 f0 	movl   $0xf0101d63,(%esp)
f01006ad:	e8 2e 03 00 00       	call   f01009e0 <cprintf>
f01006b2:	c7 44 24 08 00 1e 10 	movl   $0xf0101e00,0x8(%esp)
f01006b9:	f0 
f01006ba:	c7 44 24 04 6c 1d 10 	movl   $0xf0101d6c,0x4(%esp)
f01006c1:	f0 
f01006c2:	c7 04 24 63 1d 10 f0 	movl   $0xf0101d63,(%esp)
f01006c9:	e8 12 03 00 00       	call   f01009e0 <cprintf>
f01006ce:	c7 44 24 08 28 1e 10 	movl   $0xf0101e28,0x8(%esp)
f01006d5:	f0 
f01006d6:	c7 44 24 04 75 1d 10 	movl   $0xf0101d75,0x4(%esp)
f01006dd:	f0 
f01006de:	c7 04 24 63 1d 10 f0 	movl   $0xf0101d63,(%esp)
f01006e5:	e8 f6 02 00 00       	call   f01009e0 <cprintf>
	return 0;
}
f01006ea:	b8 00 00 00 00       	mov    $0x0,%eax
f01006ef:	c9                   	leave  
f01006f0:	c3                   	ret    

f01006f1 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f01006f1:	55                   	push   %ebp
f01006f2:	89 e5                	mov    %esp,%ebp
f01006f4:	83 ec 18             	sub    $0x18,%esp
	extern char entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f01006f7:	c7 04 24 7f 1d 10 f0 	movl   $0xf0101d7f,(%esp)
f01006fe:	e8 dd 02 00 00       	call   f01009e0 <cprintf>
	cprintf(" this is work 1 insert:\n");
f0100703:	c7 04 24 98 1d 10 f0 	movl   $0xf0101d98,(%esp)
f010070a:	e8 d1 02 00 00       	call   f01009e0 <cprintf>
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
f010070f:	c7 44 24 08 0f 00 00 	movl   $0xf,0x8(%esp)
f0100716:	00 
f0100717:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
f010071e:	00 
f010071f:	c7 04 24 54 1e 10 f0 	movl   $0xf0101e54,(%esp)
f0100726:	e8 b5 02 00 00       	call   f01009e0 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
f010072b:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f0100732:	00 
f0100733:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f010073a:	f0 
f010073b:	c7 04 24 8c 1e 10 f0 	movl   $0xf0101e8c,(%esp)
f0100742:	e8 99 02 00 00       	call   f01009e0 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f0100747:	c7 44 24 08 47 1a 10 	movl   $0x101a47,0x8(%esp)
f010074e:	00 
f010074f:	c7 44 24 04 47 1a 10 	movl   $0xf0101a47,0x4(%esp)
f0100756:	f0 
f0100757:	c7 04 24 b4 1e 10 f0 	movl   $0xf0101eb4,(%esp)
f010075e:	e8 7d 02 00 00       	call   f01009e0 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f0100763:	c7 44 24 08 00 23 11 	movl   $0x112300,0x8(%esp)
f010076a:	00 
f010076b:	c7 44 24 04 00 23 11 	movl   $0xf0112300,0x4(%esp)
f0100772:	f0 
f0100773:	c7 04 24 d8 1e 10 f0 	movl   $0xf0101ed8,(%esp)
f010077a:	e8 61 02 00 00       	call   f01009e0 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f010077f:	c7 44 24 08 60 29 11 	movl   $0x112960,0x8(%esp)
f0100786:	00 
f0100787:	c7 44 24 04 60 29 11 	movl   $0xf0112960,0x4(%esp)
f010078e:	f0 
f010078f:	c7 04 24 fc 1e 10 f0 	movl   $0xf0101efc,(%esp)
f0100796:	e8 45 02 00 00       	call   f01009e0 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f010079b:	b8 5f 2d 11 f0       	mov    $0xf0112d5f,%eax
f01007a0:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f01007a5:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f01007ab:	85 c0                	test   %eax,%eax
f01007ad:	0f 48 c2             	cmovs  %edx,%eax
f01007b0:	c1 f8 0a             	sar    $0xa,%eax
f01007b3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01007b7:	c7 04 24 20 1f 10 f0 	movl   $0xf0101f20,(%esp)
f01007be:	e8 1d 02 00 00       	call   f01009e0 <cprintf>
		(end-entry+1023)/1024);
	return 0;
}
f01007c3:	b8 00 00 00 00       	mov    $0x0,%eax
f01007c8:	c9                   	leave  
f01007c9:	c3                   	ret    

f01007ca <mon_backtrace>:

int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f01007ca:	55                   	push   %ebp
f01007cb:	89 e5                	mov    %esp,%ebp
f01007cd:	56                   	push   %esi
f01007ce:	53                   	push   %ebx
f01007cf:	83 ec 40             	sub    $0x40,%esp
	// Your code here.
	cprintf("start backtrace\n");
f01007d2:	c7 04 24 b1 1d 10 f0 	movl   $0xf0101db1,(%esp)
f01007d9:	e8 02 02 00 00       	call   f01009e0 <cprintf>

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f01007de:	89 e8                	mov    %ebp,%eax
f01007e0:	89 c1                	mov    %eax,%ecx
	uint32_t eip;
	uint32_t ebp = read_ebp();
	uint32_t esp;
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
f01007e2:	83 f8 ff             	cmp    $0xffffffff,%eax
f01007e5:	74 63                	je     f010084a <mon_backtrace+0x80>
		esp = ebp+8;
		eip = *(uint32_t*)(ebp+4);
f01007e7:	8b 71 04             	mov    0x4(%ecx),%esi
		if(ebp==0){
			ebp = -1;
f01007ea:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
		esp = ebp+8;
		eip = *(uint32_t*)(ebp+4);
		if(ebp==0){
f01007ef:	85 c9                	test   %ecx,%ecx
f01007f1:	74 02                	je     f01007f5 <mon_backtrace+0x2b>
			ebp = -1;
		}else{
			ebp = *(uint32_t*)(ebp);
f01007f3:	8b 19                	mov    (%ecx),%ebx
		}
		for(i=0;i<5;i++){
f01007f5:	b8 00 00 00 00       	mov    $0x0,%eax
		args[i] = *(uint32_t*)(esp+i*4);
f01007fa:	8b 54 81 08          	mov    0x8(%ecx,%eax,4),%edx
f01007fe:	89 54 85 e4          	mov    %edx,-0x1c(%ebp,%eax,4)
		if(ebp==0){
			ebp = -1;
		}else{
			ebp = *(uint32_t*)(ebp);
		}
		for(i=0;i<5;i++){
f0100802:	83 c0 01             	add    $0x1,%eax
f0100805:	83 f8 05             	cmp    $0x5,%eax
f0100808:	75 f0                	jne    f01007fa <mon_backtrace+0x30>
		args[i] = *(uint32_t*)(esp+i*4);
	        }
                            cprintf("ebp  %08x   eip %08x   args  %08x  %08x  %08x  %08x  %08x\n",ebp,eip,args[0],args[1],args[2],args[3],args[4]);
f010080a:	8b 45 f4             	mov    -0xc(%ebp),%eax
f010080d:	89 44 24 1c          	mov    %eax,0x1c(%esp)
f0100811:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0100814:	89 44 24 18          	mov    %eax,0x18(%esp)
f0100818:	8b 45 ec             	mov    -0x14(%ebp),%eax
f010081b:	89 44 24 14          	mov    %eax,0x14(%esp)
f010081f:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0100822:	89 44 24 10          	mov    %eax,0x10(%esp)
f0100826:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100829:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010082d:	89 74 24 08          	mov    %esi,0x8(%esp)
f0100831:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100835:	c7 04 24 4c 1f 10 f0 	movl   $0xf0101f4c,(%esp)
f010083c:	e8 9f 01 00 00       	call   f01009e0 <cprintf>
	uint32_t eip;
	uint32_t ebp = read_ebp();
	uint32_t esp;
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
f0100841:	83 fb ff             	cmp    $0xffffffff,%ebx
f0100844:	74 04                	je     f010084a <mon_backtrace+0x80>
f0100846:	89 d9                	mov    %ebx,%ecx
f0100848:	eb 9d                	jmp    f01007e7 <mon_backtrace+0x1d>
                            cprintf("ebp  %08x   eip %08x   args  %08x  %08x  %08x  %08x  %08x\n",ebp,eip,args[0],args[1],args[2],args[3],args[4]);

	}
	
	return 0;
}
f010084a:	b8 00 00 00 00       	mov    $0x0,%eax
f010084f:	83 c4 40             	add    $0x40,%esp
f0100852:	5b                   	pop    %ebx
f0100853:	5e                   	pop    %esi
f0100854:	5d                   	pop    %ebp
f0100855:	c3                   	ret    

f0100856 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f0100856:	55                   	push   %ebp
f0100857:	89 e5                	mov    %esp,%ebp
f0100859:	57                   	push   %edi
f010085a:	56                   	push   %esi
f010085b:	53                   	push   %ebx
f010085c:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f010085f:	c7 04 24 88 1f 10 f0 	movl   $0xf0101f88,(%esp)
f0100866:	e8 75 01 00 00       	call   f01009e0 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f010086b:	c7 04 24 ac 1f 10 f0 	movl   $0xf0101fac,(%esp)
f0100872:	e8 69 01 00 00       	call   f01009e0 <cprintf>


	while (1) {
		buf = readline("K> ");
f0100877:	c7 04 24 c2 1d 10 f0 	movl   $0xf0101dc2,(%esp)
f010087e:	e8 4d 0a 00 00       	call   f01012d0 <readline>
f0100883:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f0100885:	85 c0                	test   %eax,%eax
f0100887:	74 ee                	je     f0100877 <monitor+0x21>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f0100889:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f0100890:	be 00 00 00 00       	mov    $0x0,%esi
f0100895:	eb 0a                	jmp    f01008a1 <monitor+0x4b>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f0100897:	c6 03 00             	movb   $0x0,(%ebx)
f010089a:	89 f7                	mov    %esi,%edi
f010089c:	8d 5b 01             	lea    0x1(%ebx),%ebx
f010089f:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f01008a1:	0f b6 03             	movzbl (%ebx),%eax
f01008a4:	84 c0                	test   %al,%al
f01008a6:	74 6a                	je     f0100912 <monitor+0xbc>
f01008a8:	0f be c0             	movsbl %al,%eax
f01008ab:	89 44 24 04          	mov    %eax,0x4(%esp)
f01008af:	c7 04 24 c6 1d 10 f0 	movl   $0xf0101dc6,(%esp)
f01008b6:	e8 63 0c 00 00       	call   f010151e <strchr>
f01008bb:	85 c0                	test   %eax,%eax
f01008bd:	75 d8                	jne    f0100897 <monitor+0x41>
			*buf++ = 0;
		if (*buf == 0)
f01008bf:	80 3b 00             	cmpb   $0x0,(%ebx)
f01008c2:	74 4e                	je     f0100912 <monitor+0xbc>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f01008c4:	83 fe 0f             	cmp    $0xf,%esi
f01008c7:	75 16                	jne    f01008df <monitor+0x89>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f01008c9:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f01008d0:	00 
f01008d1:	c7 04 24 cb 1d 10 f0 	movl   $0xf0101dcb,(%esp)
f01008d8:	e8 03 01 00 00       	call   f01009e0 <cprintf>
f01008dd:	eb 98                	jmp    f0100877 <monitor+0x21>
			return 0;
		}
		argv[argc++] = buf;
f01008df:	8d 7e 01             	lea    0x1(%esi),%edi
f01008e2:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f01008e6:	0f b6 03             	movzbl (%ebx),%eax
f01008e9:	84 c0                	test   %al,%al
f01008eb:	75 0c                	jne    f01008f9 <monitor+0xa3>
f01008ed:	eb b0                	jmp    f010089f <monitor+0x49>
			buf++;
f01008ef:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f01008f2:	0f b6 03             	movzbl (%ebx),%eax
f01008f5:	84 c0                	test   %al,%al
f01008f7:	74 a6                	je     f010089f <monitor+0x49>
f01008f9:	0f be c0             	movsbl %al,%eax
f01008fc:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100900:	c7 04 24 c6 1d 10 f0 	movl   $0xf0101dc6,(%esp)
f0100907:	e8 12 0c 00 00       	call   f010151e <strchr>
f010090c:	85 c0                	test   %eax,%eax
f010090e:	74 df                	je     f01008ef <monitor+0x99>
f0100910:	eb 8d                	jmp    f010089f <monitor+0x49>
			buf++;
	}
	argv[argc] = 0;
f0100912:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f0100919:	00 

	// Lookup and invoke the command
	if (argc == 0)
f010091a:	85 f6                	test   %esi,%esi
f010091c:	0f 84 55 ff ff ff    	je     f0100877 <monitor+0x21>
f0100922:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100927:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f010092a:	8b 04 85 e0 1f 10 f0 	mov    -0xfefe020(,%eax,4),%eax
f0100931:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100935:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100938:	89 04 24             	mov    %eax,(%esp)
f010093b:	e8 5a 0b 00 00       	call   f010149a <strcmp>
f0100940:	85 c0                	test   %eax,%eax
f0100942:	75 24                	jne    f0100968 <monitor+0x112>
			return commands[i].func(argc, argv, tf);
f0100944:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100947:	8b 55 08             	mov    0x8(%ebp),%edx
f010094a:	89 54 24 08          	mov    %edx,0x8(%esp)
f010094e:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100951:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100955:	89 34 24             	mov    %esi,(%esp)
f0100958:	ff 14 85 e8 1f 10 f0 	call   *-0xfefe018(,%eax,4)


	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f010095f:	85 c0                	test   %eax,%eax
f0100961:	78 27                	js     f010098a <monitor+0x134>
f0100963:	e9 0f ff ff ff       	jmp    f0100877 <monitor+0x21>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
f0100968:	83 c3 01             	add    $0x1,%ebx
f010096b:	83 fb 03             	cmp    $0x3,%ebx
f010096e:	66 90                	xchg   %ax,%ax
f0100970:	75 b5                	jne    f0100927 <monitor+0xd1>
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f0100972:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100975:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100979:	c7 04 24 e8 1d 10 f0 	movl   $0xf0101de8,(%esp)
f0100980:	e8 5b 00 00 00       	call   f01009e0 <cprintf>
f0100985:	e9 ed fe ff ff       	jmp    f0100877 <monitor+0x21>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f010098a:	83 c4 5c             	add    $0x5c,%esp
f010098d:	5b                   	pop    %ebx
f010098e:	5e                   	pop    %esi
f010098f:	5f                   	pop    %edi
f0100990:	5d                   	pop    %ebp
f0100991:	c3                   	ret    

f0100992 <read_eip>:
// return EIP of caller.
// does not work if inlined.
// putting at the end of the file seems to prevent inlining.
unsigned
read_eip()
{
f0100992:	55                   	push   %ebp
f0100993:	89 e5                	mov    %esp,%ebp
	uint32_t callerpc;
	__asm __volatile("movl 4(%%ebp), %0" : "=r" (callerpc));
f0100995:	8b 45 04             	mov    0x4(%ebp),%eax
	return callerpc;
}
f0100998:	5d                   	pop    %ebp
f0100999:	c3                   	ret    

f010099a <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f010099a:	55                   	push   %ebp
f010099b:	89 e5                	mov    %esp,%ebp
f010099d:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f01009a0:	8b 45 08             	mov    0x8(%ebp),%eax
f01009a3:	89 04 24             	mov    %eax,(%esp)
f01009a6:	e8 b9 fc ff ff       	call   f0100664 <cputchar>
	*cnt++;
}
f01009ab:	c9                   	leave  
f01009ac:	c3                   	ret    

f01009ad <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f01009ad:	55                   	push   %ebp
f01009ae:	89 e5                	mov    %esp,%ebp
f01009b0:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f01009b3:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f01009ba:	8b 45 0c             	mov    0xc(%ebp),%eax
f01009bd:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01009c1:	8b 45 08             	mov    0x8(%ebp),%eax
f01009c4:	89 44 24 08          	mov    %eax,0x8(%esp)
f01009c8:	8d 45 f4             	lea    -0xc(%ebp),%eax
f01009cb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01009cf:	c7 04 24 9a 09 10 f0 	movl   $0xf010099a,(%esp)
f01009d6:	e8 89 04 00 00       	call   f0100e64 <vprintfmt>
	return cnt;
}
f01009db:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01009de:	c9                   	leave  
f01009df:	c3                   	ret    

f01009e0 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f01009e0:	55                   	push   %ebp
f01009e1:	89 e5                	mov    %esp,%ebp
f01009e3:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f01009e6:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f01009e9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01009ed:	8b 45 08             	mov    0x8(%ebp),%eax
f01009f0:	89 04 24             	mov    %eax,(%esp)
f01009f3:	e8 b5 ff ff ff       	call   f01009ad <vcprintf>
	va_end(ap);

	return cnt;
}
f01009f8:	c9                   	leave  
f01009f9:	c3                   	ret    
f01009fa:	66 90                	xchg   %ax,%ax
f01009fc:	66 90                	xchg   %ax,%ax
f01009fe:	66 90                	xchg   %ax,%ax

f0100a00 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0100a00:	55                   	push   %ebp
f0100a01:	89 e5                	mov    %esp,%ebp
f0100a03:	57                   	push   %edi
f0100a04:	56                   	push   %esi
f0100a05:	53                   	push   %ebx
f0100a06:	83 ec 10             	sub    $0x10,%esp
f0100a09:	89 c6                	mov    %eax,%esi
f0100a0b:	89 55 e8             	mov    %edx,-0x18(%ebp)
f0100a0e:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
f0100a11:	8b 7d 08             	mov    0x8(%ebp),%edi
	int l = *region_left, r = *region_right, any_matches = 0;
f0100a14:	8b 1a                	mov    (%edx),%ebx
f0100a16:	8b 01                	mov    (%ecx),%eax
f0100a18:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0100a1b:	c7 45 ec 00 00 00 00 	movl   $0x0,-0x14(%ebp)
	
	while (l <= r) {
f0100a22:	eb 77                	jmp    f0100a9b <stab_binsearch+0x9b>
		int true_m = (l + r) / 2, m = true_m;
f0100a24:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0100a27:	01 d8                	add    %ebx,%eax
f0100a29:	b9 02 00 00 00       	mov    $0x2,%ecx
f0100a2e:	99                   	cltd   
f0100a2f:	f7 f9                	idiv   %ecx
f0100a31:	89 c1                	mov    %eax,%ecx
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0100a33:	eb 01                	jmp    f0100a36 <stab_binsearch+0x36>
			m--;
f0100a35:	49                   	dec    %ecx
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0100a36:	39 d9                	cmp    %ebx,%ecx
f0100a38:	7c 1d                	jl     f0100a57 <stab_binsearch+0x57>
f0100a3a:	6b d1 0c             	imul   $0xc,%ecx,%edx
f0100a3d:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f0100a42:	39 fa                	cmp    %edi,%edx
f0100a44:	75 ef                	jne    f0100a35 <stab_binsearch+0x35>
f0100a46:	89 4d ec             	mov    %ecx,-0x14(%ebp)
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0100a49:	6b d1 0c             	imul   $0xc,%ecx,%edx
f0100a4c:	8b 54 16 08          	mov    0x8(%esi,%edx,1),%edx
f0100a50:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0100a53:	73 18                	jae    f0100a6d <stab_binsearch+0x6d>
f0100a55:	eb 05                	jmp    f0100a5c <stab_binsearch+0x5c>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0100a57:	8d 58 01             	lea    0x1(%eax),%ebx
			continue;
f0100a5a:	eb 3f                	jmp    f0100a9b <stab_binsearch+0x9b>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0100a5c:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f0100a5f:	89 0b                	mov    %ecx,(%ebx)
			l = true_m + 1;
f0100a61:	8d 58 01             	lea    0x1(%eax),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100a64:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f0100a6b:	eb 2e                	jmp    f0100a9b <stab_binsearch+0x9b>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0100a6d:	39 55 0c             	cmp    %edx,0xc(%ebp)
f0100a70:	73 15                	jae    f0100a87 <stab_binsearch+0x87>
			*region_right = m - 1;
f0100a72:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0100a75:	48                   	dec    %eax
f0100a76:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0100a79:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0100a7c:	89 01                	mov    %eax,(%ecx)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100a7e:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f0100a85:	eb 14                	jmp    f0100a9b <stab_binsearch+0x9b>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0100a87:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0100a8a:	8b 5d ec             	mov    -0x14(%ebp),%ebx
f0100a8d:	89 18                	mov    %ebx,(%eax)
			l = m;
			addr++;
f0100a8f:	ff 45 0c             	incl   0xc(%ebp)
f0100a92:	89 cb                	mov    %ecx,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100a94:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f0100a9b:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0100a9e:	7e 84                	jle    f0100a24 <stab_binsearch+0x24>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0100aa0:	83 7d ec 00          	cmpl   $0x0,-0x14(%ebp)
f0100aa4:	75 0d                	jne    f0100ab3 <stab_binsearch+0xb3>
		*region_right = *region_left - 1;
f0100aa6:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0100aa9:	8b 00                	mov    (%eax),%eax
f0100aab:	48                   	dec    %eax
f0100aac:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0100aaf:	89 07                	mov    %eax,(%edi)
f0100ab1:	eb 22                	jmp    f0100ad5 <stab_binsearch+0xd5>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100ab3:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100ab6:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0100ab8:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f0100abb:	8b 0b                	mov    (%ebx),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100abd:	eb 01                	jmp    f0100ac0 <stab_binsearch+0xc0>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
f0100abf:	48                   	dec    %eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100ac0:	39 c1                	cmp    %eax,%ecx
f0100ac2:	7d 0c                	jge    f0100ad0 <stab_binsearch+0xd0>
f0100ac4:	6b d0 0c             	imul   $0xc,%eax,%edx
		     l > *region_left && stabs[l].n_type != type;
f0100ac7:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f0100acc:	39 fa                	cmp    %edi,%edx
f0100ace:	75 ef                	jne    f0100abf <stab_binsearch+0xbf>
		     l--)
			/* do nothing */;
		*region_left = l;
f0100ad0:	8b 7d e8             	mov    -0x18(%ebp),%edi
f0100ad3:	89 07                	mov    %eax,(%edi)
	}
}
f0100ad5:	83 c4 10             	add    $0x10,%esp
f0100ad8:	5b                   	pop    %ebx
f0100ad9:	5e                   	pop    %esi
f0100ada:	5f                   	pop    %edi
f0100adb:	5d                   	pop    %ebp
f0100adc:	c3                   	ret    

f0100add <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0100add:	55                   	push   %ebp
f0100ade:	89 e5                	mov    %esp,%ebp
f0100ae0:	57                   	push   %edi
f0100ae1:	56                   	push   %esi
f0100ae2:	53                   	push   %ebx
f0100ae3:	83 ec 2c             	sub    $0x2c,%esp
f0100ae6:	8b 75 08             	mov    0x8(%ebp),%esi
f0100ae9:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0100aec:	c7 03 04 20 10 f0    	movl   $0xf0102004,(%ebx)
	info->eip_line = 0;
f0100af2:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
	info->eip_fn_name = "<unknown>";
f0100af9:	c7 43 08 04 20 10 f0 	movl   $0xf0102004,0x8(%ebx)
	info->eip_fn_namelen = 9;
f0100b00:	c7 43 0c 09 00 00 00 	movl   $0x9,0xc(%ebx)
	info->eip_fn_addr = addr;
f0100b07:	89 73 10             	mov    %esi,0x10(%ebx)
	info->eip_fn_narg = 0;
f0100b0a:	c7 43 14 00 00 00 00 	movl   $0x0,0x14(%ebx)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0100b11:	81 fe ff ff 7f ef    	cmp    $0xef7fffff,%esi
f0100b17:	76 12                	jbe    f0100b2b <debuginfo_eip+0x4e>
		// Can't search for user-level addresses yet!
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100b19:	b8 32 75 10 f0       	mov    $0xf0107532,%eax
f0100b1e:	3d a9 5b 10 f0       	cmp    $0xf0105ba9,%eax
f0100b23:	0f 86 8b 01 00 00    	jbe    f0100cb4 <debuginfo_eip+0x1d7>
f0100b29:	eb 1c                	jmp    f0100b47 <debuginfo_eip+0x6a>
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
	} else {
		// Can't search for user-level addresses yet!
  	        panic("User address");
f0100b2b:	c7 44 24 08 0e 20 10 	movl   $0xf010200e,0x8(%esp)
f0100b32:	f0 
f0100b33:	c7 44 24 04 7f 00 00 	movl   $0x7f,0x4(%esp)
f0100b3a:	00 
f0100b3b:	c7 04 24 1b 20 10 f0 	movl   $0xf010201b,(%esp)
f0100b42:	e8 b1 f5 ff ff       	call   f01000f8 <_panic>
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100b47:	80 3d 31 75 10 f0 00 	cmpb   $0x0,0xf0107531
f0100b4e:	0f 85 67 01 00 00    	jne    f0100cbb <debuginfo_eip+0x1de>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0100b54:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0100b5b:	b8 a8 5b 10 f0       	mov    $0xf0105ba8,%eax
f0100b60:	2d 3c 22 10 f0       	sub    $0xf010223c,%eax
f0100b65:	c1 f8 02             	sar    $0x2,%eax
f0100b68:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
f0100b6e:	83 e8 01             	sub    $0x1,%eax
f0100b71:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0100b74:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100b78:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0100b7f:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0100b82:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0100b85:	b8 3c 22 10 f0       	mov    $0xf010223c,%eax
f0100b8a:	e8 71 fe ff ff       	call   f0100a00 <stab_binsearch>
	if (lfile == 0)
f0100b8f:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100b92:	85 c0                	test   %eax,%eax
f0100b94:	0f 84 28 01 00 00    	je     f0100cc2 <debuginfo_eip+0x1e5>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0100b9a:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0100b9d:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100ba0:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0100ba3:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100ba7:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0100bae:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0100bb1:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100bb4:	b8 3c 22 10 f0       	mov    $0xf010223c,%eax
f0100bb9:	e8 42 fe ff ff       	call   f0100a00 <stab_binsearch>

	if (lfun <= rfun) {
f0100bbe:	8b 7d dc             	mov    -0x24(%ebp),%edi
f0100bc1:	3b 7d d8             	cmp    -0x28(%ebp),%edi
f0100bc4:	7f 2e                	jg     f0100bf4 <debuginfo_eip+0x117>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0100bc6:	6b c7 0c             	imul   $0xc,%edi,%eax
f0100bc9:	8d 90 3c 22 10 f0    	lea    -0xfefddc4(%eax),%edx
f0100bcf:	8b 80 3c 22 10 f0    	mov    -0xfefddc4(%eax),%eax
f0100bd5:	b9 32 75 10 f0       	mov    $0xf0107532,%ecx
f0100bda:	81 e9 a9 5b 10 f0    	sub    $0xf0105ba9,%ecx
f0100be0:	39 c8                	cmp    %ecx,%eax
f0100be2:	73 08                	jae    f0100bec <debuginfo_eip+0x10f>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0100be4:	05 a9 5b 10 f0       	add    $0xf0105ba9,%eax
f0100be9:	89 43 08             	mov    %eax,0x8(%ebx)
		info->eip_fn_addr = stabs[lfun].n_value;
f0100bec:	8b 42 08             	mov    0x8(%edx),%eax
f0100bef:	89 43 10             	mov    %eax,0x10(%ebx)
f0100bf2:	eb 06                	jmp    f0100bfa <debuginfo_eip+0x11d>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0100bf4:	89 73 10             	mov    %esi,0x10(%ebx)
		lline = lfile;
f0100bf7:	8b 7d e4             	mov    -0x1c(%ebp),%edi
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0100bfa:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0100c01:	00 
f0100c02:	8b 43 08             	mov    0x8(%ebx),%eax
f0100c05:	89 04 24             	mov    %eax,(%esp)
f0100c08:	e8 47 09 00 00       	call   f0101554 <strfind>
f0100c0d:	2b 43 08             	sub    0x8(%ebx),%eax
f0100c10:	89 43 0c             	mov    %eax,0xc(%ebx)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0100c13:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0100c16:	39 cf                	cmp    %ecx,%edi
f0100c18:	7c 5c                	jl     f0100c76 <debuginfo_eip+0x199>
	       && stabs[lline].n_type != N_SOL
f0100c1a:	6b c7 0c             	imul   $0xc,%edi,%eax
f0100c1d:	8d b0 3c 22 10 f0    	lea    -0xfefddc4(%eax),%esi
f0100c23:	0f b6 56 04          	movzbl 0x4(%esi),%edx
f0100c27:	80 fa 84             	cmp    $0x84,%dl
f0100c2a:	74 2b                	je     f0100c57 <debuginfo_eip+0x17a>
f0100c2c:	05 30 22 10 f0       	add    $0xf0102230,%eax
f0100c31:	eb 15                	jmp    f0100c48 <debuginfo_eip+0x16b>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0100c33:	83 ef 01             	sub    $0x1,%edi
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0100c36:	39 cf                	cmp    %ecx,%edi
f0100c38:	7c 3c                	jl     f0100c76 <debuginfo_eip+0x199>
	       && stabs[lline].n_type != N_SOL
f0100c3a:	89 c6                	mov    %eax,%esi
f0100c3c:	83 e8 0c             	sub    $0xc,%eax
f0100c3f:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0100c43:	80 fa 84             	cmp    $0x84,%dl
f0100c46:	74 0f                	je     f0100c57 <debuginfo_eip+0x17a>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0100c48:	80 fa 64             	cmp    $0x64,%dl
f0100c4b:	75 e6                	jne    f0100c33 <debuginfo_eip+0x156>
f0100c4d:	83 7e 08 00          	cmpl   $0x0,0x8(%esi)
f0100c51:	74 e0                	je     f0100c33 <debuginfo_eip+0x156>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0100c53:	39 f9                	cmp    %edi,%ecx
f0100c55:	7f 1f                	jg     f0100c76 <debuginfo_eip+0x199>
f0100c57:	6b ff 0c             	imul   $0xc,%edi,%edi
f0100c5a:	8b 87 3c 22 10 f0    	mov    -0xfefddc4(%edi),%eax
f0100c60:	ba 32 75 10 f0       	mov    $0xf0107532,%edx
f0100c65:	81 ea a9 5b 10 f0    	sub    $0xf0105ba9,%edx
f0100c6b:	39 d0                	cmp    %edx,%eax
f0100c6d:	73 07                	jae    f0100c76 <debuginfo_eip+0x199>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0100c6f:	05 a9 5b 10 f0       	add    $0xf0105ba9,%eax
f0100c74:	89 03                	mov    %eax,(%ebx)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100c76:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100c79:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0100c7c:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100c81:	39 ca                	cmp    %ecx,%edx
f0100c83:	7d 5e                	jge    f0100ce3 <debuginfo_eip+0x206>
		for (lline = lfun + 1;
f0100c85:	8d 42 01             	lea    0x1(%edx),%eax
f0100c88:	39 c1                	cmp    %eax,%ecx
f0100c8a:	7e 3d                	jle    f0100cc9 <debuginfo_eip+0x1ec>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0100c8c:	6b d0 0c             	imul   $0xc,%eax,%edx
f0100c8f:	80 ba 40 22 10 f0 a0 	cmpb   $0xa0,-0xfefddc0(%edx)
f0100c96:	75 38                	jne    f0100cd0 <debuginfo_eip+0x1f3>
f0100c98:	81 c2 30 22 10 f0    	add    $0xf0102230,%edx
		     lline++)
			info->eip_fn_narg++;
f0100c9e:	83 43 14 01          	addl   $0x1,0x14(%ebx)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0100ca2:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0100ca5:	39 c1                	cmp    %eax,%ecx
f0100ca7:	7e 2e                	jle    f0100cd7 <debuginfo_eip+0x1fa>
f0100ca9:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0100cac:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0100cb0:	74 ec                	je     f0100c9e <debuginfo_eip+0x1c1>
f0100cb2:	eb 2a                	jmp    f0100cde <debuginfo_eip+0x201>
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0100cb4:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100cb9:	eb 28                	jmp    f0100ce3 <debuginfo_eip+0x206>
f0100cbb:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100cc0:	eb 21                	jmp    f0100ce3 <debuginfo_eip+0x206>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0100cc2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100cc7:	eb 1a                	jmp    f0100ce3 <debuginfo_eip+0x206>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0100cc9:	b8 00 00 00 00       	mov    $0x0,%eax
f0100cce:	eb 13                	jmp    f0100ce3 <debuginfo_eip+0x206>
f0100cd0:	b8 00 00 00 00       	mov    $0x0,%eax
f0100cd5:	eb 0c                	jmp    f0100ce3 <debuginfo_eip+0x206>
f0100cd7:	b8 00 00 00 00       	mov    $0x0,%eax
f0100cdc:	eb 05                	jmp    f0100ce3 <debuginfo_eip+0x206>
f0100cde:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0100ce3:	83 c4 2c             	add    $0x2c,%esp
f0100ce6:	5b                   	pop    %ebx
f0100ce7:	5e                   	pop    %esi
f0100ce8:	5f                   	pop    %edi
f0100ce9:	5d                   	pop    %ebp
f0100cea:	c3                   	ret    
f0100ceb:	66 90                	xchg   %ax,%ax
f0100ced:	66 90                	xchg   %ax,%ax
f0100cef:	90                   	nop

f0100cf0 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0100cf0:	55                   	push   %ebp
f0100cf1:	89 e5                	mov    %esp,%ebp
f0100cf3:	57                   	push   %edi
f0100cf4:	56                   	push   %esi
f0100cf5:	53                   	push   %ebx
f0100cf6:	83 ec 3c             	sub    $0x3c,%esp
f0100cf9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0100cfc:	89 d7                	mov    %edx,%edi
f0100cfe:	8b 45 08             	mov    0x8(%ebp),%eax
f0100d01:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0100d04:	8b 75 0c             	mov    0xc(%ebp),%esi
f0100d07:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f0100d0a:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0100d0d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0100d12:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0100d15:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0100d18:	39 f1                	cmp    %esi,%ecx
f0100d1a:	72 14                	jb     f0100d30 <printnum+0x40>
f0100d1c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f0100d1f:	76 0f                	jbe    f0100d30 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0100d21:	8b 45 14             	mov    0x14(%ebp),%eax
f0100d24:	8d 70 ff             	lea    -0x1(%eax),%esi
f0100d27:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0100d2a:	85 f6                	test   %esi,%esi
f0100d2c:	7f 60                	jg     f0100d8e <printnum+0x9e>
f0100d2e:	eb 72                	jmp    f0100da2 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0100d30:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0100d33:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0100d37:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0100d3a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0100d3d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100d41:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100d45:	8b 44 24 08          	mov    0x8(%esp),%eax
f0100d49:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0100d4d:	89 c3                	mov    %eax,%ebx
f0100d4f:	89 d6                	mov    %edx,%esi
f0100d51:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0100d54:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0100d57:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100d5b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0100d5f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100d62:	89 04 24             	mov    %eax,(%esp)
f0100d65:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100d68:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100d6c:	e8 4f 0a 00 00       	call   f01017c0 <__udivdi3>
f0100d71:	89 d9                	mov    %ebx,%ecx
f0100d73:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0100d77:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0100d7b:	89 04 24             	mov    %eax,(%esp)
f0100d7e:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100d82:	89 fa                	mov    %edi,%edx
f0100d84:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100d87:	e8 64 ff ff ff       	call   f0100cf0 <printnum>
f0100d8c:	eb 14                	jmp    f0100da2 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f0100d8e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100d92:	8b 45 18             	mov    0x18(%ebp),%eax
f0100d95:	89 04 24             	mov    %eax,(%esp)
f0100d98:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0100d9a:	83 ee 01             	sub    $0x1,%esi
f0100d9d:	75 ef                	jne    f0100d8e <printnum+0x9e>
f0100d9f:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0100da2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100da6:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0100daa:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100dad:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100db0:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100db4:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100db8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100dbb:	89 04 24             	mov    %eax,(%esp)
f0100dbe:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100dc1:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100dc5:	e8 26 0b 00 00       	call   f01018f0 <__umoddi3>
f0100dca:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100dce:	0f be 80 29 20 10 f0 	movsbl -0xfefdfd7(%eax),%eax
f0100dd5:	89 04 24             	mov    %eax,(%esp)
f0100dd8:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100ddb:	ff d0                	call   *%eax
}
f0100ddd:	83 c4 3c             	add    $0x3c,%esp
f0100de0:	5b                   	pop    %ebx
f0100de1:	5e                   	pop    %esi
f0100de2:	5f                   	pop    %edi
f0100de3:	5d                   	pop    %ebp
f0100de4:	c3                   	ret    

f0100de5 <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0100de5:	55                   	push   %ebp
f0100de6:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0100de8:	83 fa 01             	cmp    $0x1,%edx
f0100deb:	7e 0e                	jle    f0100dfb <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f0100ded:	8b 10                	mov    (%eax),%edx
f0100def:	8d 4a 08             	lea    0x8(%edx),%ecx
f0100df2:	89 08                	mov    %ecx,(%eax)
f0100df4:	8b 02                	mov    (%edx),%eax
f0100df6:	8b 52 04             	mov    0x4(%edx),%edx
f0100df9:	eb 22                	jmp    f0100e1d <getuint+0x38>
	else if (lflag)
f0100dfb:	85 d2                	test   %edx,%edx
f0100dfd:	74 10                	je     f0100e0f <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f0100dff:	8b 10                	mov    (%eax),%edx
f0100e01:	8d 4a 04             	lea    0x4(%edx),%ecx
f0100e04:	89 08                	mov    %ecx,(%eax)
f0100e06:	8b 02                	mov    (%edx),%eax
f0100e08:	ba 00 00 00 00       	mov    $0x0,%edx
f0100e0d:	eb 0e                	jmp    f0100e1d <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f0100e0f:	8b 10                	mov    (%eax),%edx
f0100e11:	8d 4a 04             	lea    0x4(%edx),%ecx
f0100e14:	89 08                	mov    %ecx,(%eax)
f0100e16:	8b 02                	mov    (%edx),%eax
f0100e18:	ba 00 00 00 00       	mov    $0x0,%edx
}
f0100e1d:	5d                   	pop    %ebp
f0100e1e:	c3                   	ret    

f0100e1f <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0100e1f:	55                   	push   %ebp
f0100e20:	89 e5                	mov    %esp,%ebp
f0100e22:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0100e25:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0100e29:	8b 10                	mov    (%eax),%edx
f0100e2b:	3b 50 04             	cmp    0x4(%eax),%edx
f0100e2e:	73 0a                	jae    f0100e3a <sprintputch+0x1b>
		*b->buf++ = ch;
f0100e30:	8d 4a 01             	lea    0x1(%edx),%ecx
f0100e33:	89 08                	mov    %ecx,(%eax)
f0100e35:	8b 45 08             	mov    0x8(%ebp),%eax
f0100e38:	88 02                	mov    %al,(%edx)
}
f0100e3a:	5d                   	pop    %ebp
f0100e3b:	c3                   	ret    

f0100e3c <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0100e3c:	55                   	push   %ebp
f0100e3d:	89 e5                	mov    %esp,%ebp
f0100e3f:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0100e42:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0100e45:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100e49:	8b 45 10             	mov    0x10(%ebp),%eax
f0100e4c:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100e50:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100e53:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100e57:	8b 45 08             	mov    0x8(%ebp),%eax
f0100e5a:	89 04 24             	mov    %eax,(%esp)
f0100e5d:	e8 02 00 00 00       	call   f0100e64 <vprintfmt>
	va_end(ap);
}
f0100e62:	c9                   	leave  
f0100e63:	c3                   	ret    

f0100e64 <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f0100e64:	55                   	push   %ebp
f0100e65:	89 e5                	mov    %esp,%ebp
f0100e67:	57                   	push   %edi
f0100e68:	56                   	push   %esi
f0100e69:	53                   	push   %ebx
f0100e6a:	83 ec 3c             	sub    $0x3c,%esp
f0100e6d:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0100e70:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0100e73:	eb 18                	jmp    f0100e8d <vprintfmt+0x29>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f0100e75:	85 c0                	test   %eax,%eax
f0100e77:	0f 84 c3 03 00 00    	je     f0101240 <vprintfmt+0x3dc>
				return;
			putch(ch, putdat);
f0100e7d:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100e81:	89 04 24             	mov    %eax,(%esp)
f0100e84:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0100e87:	89 f3                	mov    %esi,%ebx
f0100e89:	eb 02                	jmp    f0100e8d <vprintfmt+0x29>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f0100e8b:	89 f3                	mov    %esi,%ebx
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0100e8d:	8d 73 01             	lea    0x1(%ebx),%esi
f0100e90:	0f b6 03             	movzbl (%ebx),%eax
f0100e93:	83 f8 25             	cmp    $0x25,%eax
f0100e96:	75 dd                	jne    f0100e75 <vprintfmt+0x11>
f0100e98:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f0100e9c:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0100ea3:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f0100eaa:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0100eb1:	ba 00 00 00 00       	mov    $0x0,%edx
f0100eb6:	eb 1d                	jmp    f0100ed5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100eb8:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f0100eba:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f0100ebe:	eb 15                	jmp    f0100ed5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100ec0:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0100ec2:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f0100ec6:	eb 0d                	jmp    f0100ed5 <vprintfmt+0x71>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0100ec8:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100ecb:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0100ece:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100ed5:	8d 5e 01             	lea    0x1(%esi),%ebx
f0100ed8:	0f b6 06             	movzbl (%esi),%eax
f0100edb:	0f b6 c8             	movzbl %al,%ecx
f0100ede:	83 e8 23             	sub    $0x23,%eax
f0100ee1:	3c 55                	cmp    $0x55,%al
f0100ee3:	0f 87 2f 03 00 00    	ja     f0101218 <vprintfmt+0x3b4>
f0100ee9:	0f b6 c0             	movzbl %al,%eax
f0100eec:	ff 24 85 b8 20 10 f0 	jmp    *-0xfefdf48(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0100ef3:	8d 41 d0             	lea    -0x30(%ecx),%eax
f0100ef6:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0100ef9:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f0100efd:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0100f00:	83 f9 09             	cmp    $0x9,%ecx
f0100f03:	77 50                	ja     f0100f55 <vprintfmt+0xf1>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100f05:	89 de                	mov    %ebx,%esi
f0100f07:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f0100f0a:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f0100f0d:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0100f10:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0100f14:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0100f17:	8d 58 d0             	lea    -0x30(%eax),%ebx
f0100f1a:	83 fb 09             	cmp    $0x9,%ebx
f0100f1d:	76 eb                	jbe    f0100f0a <vprintfmt+0xa6>
f0100f1f:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0100f22:	eb 33                	jmp    f0100f57 <vprintfmt+0xf3>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0100f24:	8b 45 14             	mov    0x14(%ebp),%eax
f0100f27:	8d 48 04             	lea    0x4(%eax),%ecx
f0100f2a:	89 4d 14             	mov    %ecx,0x14(%ebp)
f0100f2d:	8b 00                	mov    (%eax),%eax
f0100f2f:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100f32:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0100f34:	eb 21                	jmp    f0100f57 <vprintfmt+0xf3>
f0100f36:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0100f39:	85 c9                	test   %ecx,%ecx
f0100f3b:	b8 00 00 00 00       	mov    $0x0,%eax
f0100f40:	0f 49 c1             	cmovns %ecx,%eax
f0100f43:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100f46:	89 de                	mov    %ebx,%esi
f0100f48:	eb 8b                	jmp    f0100ed5 <vprintfmt+0x71>
f0100f4a:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0100f4c:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f0100f53:	eb 80                	jmp    f0100ed5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100f55:	89 de                	mov    %ebx,%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0100f57:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0100f5b:	0f 89 74 ff ff ff    	jns    f0100ed5 <vprintfmt+0x71>
f0100f61:	e9 62 ff ff ff       	jmp    f0100ec8 <vprintfmt+0x64>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0100f66:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100f69:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f0100f6b:	e9 65 ff ff ff       	jmp    f0100ed5 <vprintfmt+0x71>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f0100f70:	8b 45 14             	mov    0x14(%ebp),%eax
f0100f73:	8d 50 04             	lea    0x4(%eax),%edx
f0100f76:	89 55 14             	mov    %edx,0x14(%ebp)
f0100f79:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100f7d:	8b 00                	mov    (%eax),%eax
f0100f7f:	89 04 24             	mov    %eax,(%esp)
f0100f82:	ff 55 08             	call   *0x8(%ebp)
			break;
f0100f85:	e9 03 ff ff ff       	jmp    f0100e8d <vprintfmt+0x29>

		// error message
		case 'e':
			err = va_arg(ap, int);
f0100f8a:	8b 45 14             	mov    0x14(%ebp),%eax
f0100f8d:	8d 50 04             	lea    0x4(%eax),%edx
f0100f90:	89 55 14             	mov    %edx,0x14(%ebp)
f0100f93:	8b 00                	mov    (%eax),%eax
f0100f95:	99                   	cltd   
f0100f96:	31 d0                	xor    %edx,%eax
f0100f98:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0100f9a:	83 f8 06             	cmp    $0x6,%eax
f0100f9d:	7f 0b                	jg     f0100faa <vprintfmt+0x146>
f0100f9f:	8b 14 85 10 22 10 f0 	mov    -0xfefddf0(,%eax,4),%edx
f0100fa6:	85 d2                	test   %edx,%edx
f0100fa8:	75 20                	jne    f0100fca <vprintfmt+0x166>
				printfmt(putch, putdat, "error %d", err);
f0100faa:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100fae:	c7 44 24 08 41 20 10 	movl   $0xf0102041,0x8(%esp)
f0100fb5:	f0 
f0100fb6:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100fba:	8b 45 08             	mov    0x8(%ebp),%eax
f0100fbd:	89 04 24             	mov    %eax,(%esp)
f0100fc0:	e8 77 fe ff ff       	call   f0100e3c <printfmt>
f0100fc5:	e9 c3 fe ff ff       	jmp    f0100e8d <vprintfmt+0x29>
			else
				printfmt(putch, putdat, "%s", p);
f0100fca:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100fce:	c7 44 24 08 4a 20 10 	movl   $0xf010204a,0x8(%esp)
f0100fd5:	f0 
f0100fd6:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100fda:	8b 45 08             	mov    0x8(%ebp),%eax
f0100fdd:	89 04 24             	mov    %eax,(%esp)
f0100fe0:	e8 57 fe ff ff       	call   f0100e3c <printfmt>
f0100fe5:	e9 a3 fe ff ff       	jmp    f0100e8d <vprintfmt+0x29>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100fea:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0100fed:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0100ff0:	8b 45 14             	mov    0x14(%ebp),%eax
f0100ff3:	8d 50 04             	lea    0x4(%eax),%edx
f0100ff6:	89 55 14             	mov    %edx,0x14(%ebp)
f0100ff9:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f0100ffb:	85 c0                	test   %eax,%eax
f0100ffd:	ba 3a 20 10 f0       	mov    $0xf010203a,%edx
f0101002:	0f 45 d0             	cmovne %eax,%edx
f0101005:	89 55 d0             	mov    %edx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f0101008:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f010100c:	74 04                	je     f0101012 <vprintfmt+0x1ae>
f010100e:	85 f6                	test   %esi,%esi
f0101010:	7f 19                	jg     f010102b <vprintfmt+0x1c7>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0101012:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101015:	8d 70 01             	lea    0x1(%eax),%esi
f0101018:	0f b6 10             	movzbl (%eax),%edx
f010101b:	0f be c2             	movsbl %dl,%eax
f010101e:	85 c0                	test   %eax,%eax
f0101020:	0f 85 95 00 00 00    	jne    f01010bb <vprintfmt+0x257>
f0101026:	e9 85 00 00 00       	jmp    f01010b0 <vprintfmt+0x24c>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f010102b:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f010102f:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101032:	89 04 24             	mov    %eax,(%esp)
f0101035:	e8 88 03 00 00       	call   f01013c2 <strnlen>
f010103a:	29 c6                	sub    %eax,%esi
f010103c:	89 f0                	mov    %esi,%eax
f010103e:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0101041:	85 f6                	test   %esi,%esi
f0101043:	7e cd                	jle    f0101012 <vprintfmt+0x1ae>
					putch(padc, putdat);
f0101045:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0101049:	89 5d 10             	mov    %ebx,0x10(%ebp)
f010104c:	89 c3                	mov    %eax,%ebx
f010104e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101052:	89 34 24             	mov    %esi,(%esp)
f0101055:	ff 55 08             	call   *0x8(%ebp)
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0101058:	83 eb 01             	sub    $0x1,%ebx
f010105b:	75 f1                	jne    f010104e <vprintfmt+0x1ea>
f010105d:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0101060:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0101063:	eb ad                	jmp    f0101012 <vprintfmt+0x1ae>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f0101065:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0101069:	74 1e                	je     f0101089 <vprintfmt+0x225>
f010106b:	0f be d2             	movsbl %dl,%edx
f010106e:	83 ea 20             	sub    $0x20,%edx
f0101071:	83 fa 5e             	cmp    $0x5e,%edx
f0101074:	76 13                	jbe    f0101089 <vprintfmt+0x225>
					putch('?', putdat);
f0101076:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101079:	89 44 24 04          	mov    %eax,0x4(%esp)
f010107d:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f0101084:	ff 55 08             	call   *0x8(%ebp)
f0101087:	eb 0d                	jmp    f0101096 <vprintfmt+0x232>
				else
					putch(ch, putdat);
f0101089:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f010108c:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0101090:	89 04 24             	mov    %eax,(%esp)
f0101093:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0101096:	83 ef 01             	sub    $0x1,%edi
f0101099:	83 c6 01             	add    $0x1,%esi
f010109c:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f01010a0:	0f be c2             	movsbl %dl,%eax
f01010a3:	85 c0                	test   %eax,%eax
f01010a5:	75 20                	jne    f01010c7 <vprintfmt+0x263>
f01010a7:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f01010aa:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01010ad:	8b 5d 10             	mov    0x10(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01010b0:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01010b4:	7f 25                	jg     f01010db <vprintfmt+0x277>
f01010b6:	e9 d2 fd ff ff       	jmp    f0100e8d <vprintfmt+0x29>
f01010bb:	89 7d 0c             	mov    %edi,0xc(%ebp)
f01010be:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01010c1:	89 5d 10             	mov    %ebx,0x10(%ebp)
f01010c4:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01010c7:	85 db                	test   %ebx,%ebx
f01010c9:	78 9a                	js     f0101065 <vprintfmt+0x201>
f01010cb:	83 eb 01             	sub    $0x1,%ebx
f01010ce:	79 95                	jns    f0101065 <vprintfmt+0x201>
f01010d0:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f01010d3:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01010d6:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01010d9:	eb d5                	jmp    f01010b0 <vprintfmt+0x24c>
f01010db:	8b 75 08             	mov    0x8(%ebp),%esi
f01010de:	89 5d 10             	mov    %ebx,0x10(%ebp)
f01010e1:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f01010e4:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01010e8:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f01010ef:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01010f1:	83 eb 01             	sub    $0x1,%ebx
f01010f4:	75 ee                	jne    f01010e4 <vprintfmt+0x280>
f01010f6:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01010f9:	e9 8f fd ff ff       	jmp    f0100e8d <vprintfmt+0x29>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f01010fe:	83 fa 01             	cmp    $0x1,%edx
f0101101:	7e 16                	jle    f0101119 <vprintfmt+0x2b5>
		return va_arg(*ap, long long);
f0101103:	8b 45 14             	mov    0x14(%ebp),%eax
f0101106:	8d 50 08             	lea    0x8(%eax),%edx
f0101109:	89 55 14             	mov    %edx,0x14(%ebp)
f010110c:	8b 50 04             	mov    0x4(%eax),%edx
f010110f:	8b 00                	mov    (%eax),%eax
f0101111:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0101114:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0101117:	eb 32                	jmp    f010114b <vprintfmt+0x2e7>
	else if (lflag)
f0101119:	85 d2                	test   %edx,%edx
f010111b:	74 18                	je     f0101135 <vprintfmt+0x2d1>
		return va_arg(*ap, long);
f010111d:	8b 45 14             	mov    0x14(%ebp),%eax
f0101120:	8d 50 04             	lea    0x4(%eax),%edx
f0101123:	89 55 14             	mov    %edx,0x14(%ebp)
f0101126:	8b 30                	mov    (%eax),%esi
f0101128:	89 75 d8             	mov    %esi,-0x28(%ebp)
f010112b:	89 f0                	mov    %esi,%eax
f010112d:	c1 f8 1f             	sar    $0x1f,%eax
f0101130:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0101133:	eb 16                	jmp    f010114b <vprintfmt+0x2e7>
	else
		return va_arg(*ap, int);
f0101135:	8b 45 14             	mov    0x14(%ebp),%eax
f0101138:	8d 50 04             	lea    0x4(%eax),%edx
f010113b:	89 55 14             	mov    %edx,0x14(%ebp)
f010113e:	8b 30                	mov    (%eax),%esi
f0101140:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0101143:	89 f0                	mov    %esi,%eax
f0101145:	c1 f8 1f             	sar    $0x1f,%eax
f0101148:	89 45 dc             	mov    %eax,-0x24(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f010114b:	8b 45 d8             	mov    -0x28(%ebp),%eax
f010114e:	8b 55 dc             	mov    -0x24(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f0101151:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0101156:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f010115a:	0f 89 80 00 00 00    	jns    f01011e0 <vprintfmt+0x37c>
				putch('-', putdat);
f0101160:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101164:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f010116b:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f010116e:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0101171:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0101174:	f7 d8                	neg    %eax
f0101176:	83 d2 00             	adc    $0x0,%edx
f0101179:	f7 da                	neg    %edx
			}
			base = 10;
f010117b:	b9 0a 00 00 00       	mov    $0xa,%ecx
f0101180:	eb 5e                	jmp    f01011e0 <vprintfmt+0x37c>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f0101182:	8d 45 14             	lea    0x14(%ebp),%eax
f0101185:	e8 5b fc ff ff       	call   f0100de5 <getuint>
			base = 10;
f010118a:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f010118f:	eb 4f                	jmp    f01011e0 <vprintfmt+0x37c>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			//putch('X', putdat);
			num = getuint(&ap, lflag);
f0101191:	8d 45 14             	lea    0x14(%ebp),%eax
f0101194:	e8 4c fc ff ff       	call   f0100de5 <getuint>
			base = 8;
f0101199:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f010119e:	eb 40                	jmp    f01011e0 <vprintfmt+0x37c>
			//putch('X', putdat);
			//break;

		// pointer
		case 'p':
			putch('0', putdat);
f01011a0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01011a4:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f01011ab:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f01011ae:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01011b2:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f01011b9:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f01011bc:	8b 45 14             	mov    0x14(%ebp),%eax
f01011bf:	8d 50 04             	lea    0x4(%eax),%edx
f01011c2:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f01011c5:	8b 00                	mov    (%eax),%eax
f01011c7:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f01011cc:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f01011d1:	eb 0d                	jmp    f01011e0 <vprintfmt+0x37c>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f01011d3:	8d 45 14             	lea    0x14(%ebp),%eax
f01011d6:	e8 0a fc ff ff       	call   f0100de5 <getuint>
			base = 16;
f01011db:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f01011e0:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f01011e4:	89 74 24 10          	mov    %esi,0x10(%esp)
f01011e8:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f01011eb:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01011ef:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01011f3:	89 04 24             	mov    %eax,(%esp)
f01011f6:	89 54 24 04          	mov    %edx,0x4(%esp)
f01011fa:	89 fa                	mov    %edi,%edx
f01011fc:	8b 45 08             	mov    0x8(%ebp),%eax
f01011ff:	e8 ec fa ff ff       	call   f0100cf0 <printnum>
			break;
f0101204:	e9 84 fc ff ff       	jmp    f0100e8d <vprintfmt+0x29>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0101209:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010120d:	89 0c 24             	mov    %ecx,(%esp)
f0101210:	ff 55 08             	call   *0x8(%ebp)
			break;
f0101213:	e9 75 fc ff ff       	jmp    f0100e8d <vprintfmt+0x29>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0101218:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010121c:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0101223:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f0101226:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f010122a:	0f 84 5b fc ff ff    	je     f0100e8b <vprintfmt+0x27>
f0101230:	89 f3                	mov    %esi,%ebx
f0101232:	83 eb 01             	sub    $0x1,%ebx
f0101235:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f0101239:	75 f7                	jne    f0101232 <vprintfmt+0x3ce>
f010123b:	e9 4d fc ff ff       	jmp    f0100e8d <vprintfmt+0x29>
				/* do nothing */;
			break;
		}
	}
}
f0101240:	83 c4 3c             	add    $0x3c,%esp
f0101243:	5b                   	pop    %ebx
f0101244:	5e                   	pop    %esi
f0101245:	5f                   	pop    %edi
f0101246:	5d                   	pop    %ebp
f0101247:	c3                   	ret    

f0101248 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0101248:	55                   	push   %ebp
f0101249:	89 e5                	mov    %esp,%ebp
f010124b:	83 ec 28             	sub    $0x28,%esp
f010124e:	8b 45 08             	mov    0x8(%ebp),%eax
f0101251:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0101254:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0101257:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f010125b:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f010125e:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0101265:	85 c0                	test   %eax,%eax
f0101267:	74 30                	je     f0101299 <vsnprintf+0x51>
f0101269:	85 d2                	test   %edx,%edx
f010126b:	7e 2c                	jle    f0101299 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f010126d:	8b 45 14             	mov    0x14(%ebp),%eax
f0101270:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101274:	8b 45 10             	mov    0x10(%ebp),%eax
f0101277:	89 44 24 08          	mov    %eax,0x8(%esp)
f010127b:	8d 45 ec             	lea    -0x14(%ebp),%eax
f010127e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101282:	c7 04 24 1f 0e 10 f0 	movl   $0xf0100e1f,(%esp)
f0101289:	e8 d6 fb ff ff       	call   f0100e64 <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f010128e:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0101291:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0101294:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101297:	eb 05                	jmp    f010129e <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f0101299:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f010129e:	c9                   	leave  
f010129f:	c3                   	ret    

f01012a0 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f01012a0:	55                   	push   %ebp
f01012a1:	89 e5                	mov    %esp,%ebp
f01012a3:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f01012a6:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f01012a9:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01012ad:	8b 45 10             	mov    0x10(%ebp),%eax
f01012b0:	89 44 24 08          	mov    %eax,0x8(%esp)
f01012b4:	8b 45 0c             	mov    0xc(%ebp),%eax
f01012b7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01012bb:	8b 45 08             	mov    0x8(%ebp),%eax
f01012be:	89 04 24             	mov    %eax,(%esp)
f01012c1:	e8 82 ff ff ff       	call   f0101248 <vsnprintf>
	va_end(ap);

	return rc;
}
f01012c6:	c9                   	leave  
f01012c7:	c3                   	ret    
f01012c8:	66 90                	xchg   %ax,%ax
f01012ca:	66 90                	xchg   %ax,%ax
f01012cc:	66 90                	xchg   %ax,%ax
f01012ce:	66 90                	xchg   %ax,%ax

f01012d0 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f01012d0:	55                   	push   %ebp
f01012d1:	89 e5                	mov    %esp,%ebp
f01012d3:	57                   	push   %edi
f01012d4:	56                   	push   %esi
f01012d5:	53                   	push   %ebx
f01012d6:	83 ec 1c             	sub    $0x1c,%esp
f01012d9:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f01012dc:	85 c0                	test   %eax,%eax
f01012de:	74 10                	je     f01012f0 <readline+0x20>
		cprintf("%s", prompt);
f01012e0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01012e4:	c7 04 24 4a 20 10 f0 	movl   $0xf010204a,(%esp)
f01012eb:	e8 f0 f6 ff ff       	call   f01009e0 <cprintf>

	i = 0;
	echoing = iscons(0);
f01012f0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01012f7:	e8 89 f3 ff ff       	call   f0100685 <iscons>
f01012fc:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f01012fe:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0101303:	e8 6c f3 ff ff       	call   f0100674 <getchar>
f0101308:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f010130a:	85 c0                	test   %eax,%eax
f010130c:	79 17                	jns    f0101325 <readline+0x55>
			cprintf("read error: %e\n", c);
f010130e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101312:	c7 04 24 2c 22 10 f0 	movl   $0xf010222c,(%esp)
f0101319:	e8 c2 f6 ff ff       	call   f01009e0 <cprintf>
			return NULL;
f010131e:	b8 00 00 00 00       	mov    $0x0,%eax
f0101323:	eb 6d                	jmp    f0101392 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0101325:	83 f8 7f             	cmp    $0x7f,%eax
f0101328:	74 05                	je     f010132f <readline+0x5f>
f010132a:	83 f8 08             	cmp    $0x8,%eax
f010132d:	75 19                	jne    f0101348 <readline+0x78>
f010132f:	85 f6                	test   %esi,%esi
f0101331:	7e 15                	jle    f0101348 <readline+0x78>
			if (echoing)
f0101333:	85 ff                	test   %edi,%edi
f0101335:	74 0c                	je     f0101343 <readline+0x73>
				cputchar('\b');
f0101337:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f010133e:	e8 21 f3 ff ff       	call   f0100664 <cputchar>
			i--;
f0101343:	83 ee 01             	sub    $0x1,%esi
f0101346:	eb bb                	jmp    f0101303 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0101348:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f010134e:	7f 1c                	jg     f010136c <readline+0x9c>
f0101350:	83 fb 1f             	cmp    $0x1f,%ebx
f0101353:	7e 17                	jle    f010136c <readline+0x9c>
			if (echoing)
f0101355:	85 ff                	test   %edi,%edi
f0101357:	74 08                	je     f0101361 <readline+0x91>
				cputchar(c);
f0101359:	89 1c 24             	mov    %ebx,(%esp)
f010135c:	e8 03 f3 ff ff       	call   f0100664 <cputchar>
			buf[i++] = c;
f0101361:	88 9e 60 25 11 f0    	mov    %bl,-0xfeedaa0(%esi)
f0101367:	8d 76 01             	lea    0x1(%esi),%esi
f010136a:	eb 97                	jmp    f0101303 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f010136c:	83 fb 0d             	cmp    $0xd,%ebx
f010136f:	74 05                	je     f0101376 <readline+0xa6>
f0101371:	83 fb 0a             	cmp    $0xa,%ebx
f0101374:	75 8d                	jne    f0101303 <readline+0x33>
			if (echoing)
f0101376:	85 ff                	test   %edi,%edi
f0101378:	74 0c                	je     f0101386 <readline+0xb6>
				cputchar('\n');
f010137a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0101381:	e8 de f2 ff ff       	call   f0100664 <cputchar>
			buf[i] = 0;
f0101386:	c6 86 60 25 11 f0 00 	movb   $0x0,-0xfeedaa0(%esi)
			return buf;
f010138d:	b8 60 25 11 f0       	mov    $0xf0112560,%eax
		}
	}
}
f0101392:	83 c4 1c             	add    $0x1c,%esp
f0101395:	5b                   	pop    %ebx
f0101396:	5e                   	pop    %esi
f0101397:	5f                   	pop    %edi
f0101398:	5d                   	pop    %ebp
f0101399:	c3                   	ret    
f010139a:	66 90                	xchg   %ax,%ax
f010139c:	66 90                	xchg   %ax,%ax
f010139e:	66 90                	xchg   %ax,%ax

f01013a0 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f01013a0:	55                   	push   %ebp
f01013a1:	89 e5                	mov    %esp,%ebp
f01013a3:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f01013a6:	80 3a 00             	cmpb   $0x0,(%edx)
f01013a9:	74 10                	je     f01013bb <strlen+0x1b>
f01013ab:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f01013b0:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f01013b3:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f01013b7:	75 f7                	jne    f01013b0 <strlen+0x10>
f01013b9:	eb 05                	jmp    f01013c0 <strlen+0x20>
f01013bb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f01013c0:	5d                   	pop    %ebp
f01013c1:	c3                   	ret    

f01013c2 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f01013c2:	55                   	push   %ebp
f01013c3:	89 e5                	mov    %esp,%ebp
f01013c5:	53                   	push   %ebx
f01013c6:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01013c9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01013cc:	85 c9                	test   %ecx,%ecx
f01013ce:	74 1c                	je     f01013ec <strnlen+0x2a>
f01013d0:	80 3b 00             	cmpb   $0x0,(%ebx)
f01013d3:	74 1e                	je     f01013f3 <strnlen+0x31>
f01013d5:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f01013da:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01013dc:	39 ca                	cmp    %ecx,%edx
f01013de:	74 18                	je     f01013f8 <strnlen+0x36>
f01013e0:	83 c2 01             	add    $0x1,%edx
f01013e3:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f01013e8:	75 f0                	jne    f01013da <strnlen+0x18>
f01013ea:	eb 0c                	jmp    f01013f8 <strnlen+0x36>
f01013ec:	b8 00 00 00 00       	mov    $0x0,%eax
f01013f1:	eb 05                	jmp    f01013f8 <strnlen+0x36>
f01013f3:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f01013f8:	5b                   	pop    %ebx
f01013f9:	5d                   	pop    %ebp
f01013fa:	c3                   	ret    

f01013fb <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f01013fb:	55                   	push   %ebp
f01013fc:	89 e5                	mov    %esp,%ebp
f01013fe:	53                   	push   %ebx
f01013ff:	8b 45 08             	mov    0x8(%ebp),%eax
f0101402:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0101405:	89 c2                	mov    %eax,%edx
f0101407:	83 c2 01             	add    $0x1,%edx
f010140a:	83 c1 01             	add    $0x1,%ecx
f010140d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0101411:	88 5a ff             	mov    %bl,-0x1(%edx)
f0101414:	84 db                	test   %bl,%bl
f0101416:	75 ef                	jne    f0101407 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0101418:	5b                   	pop    %ebx
f0101419:	5d                   	pop    %ebp
f010141a:	c3                   	ret    

f010141b <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f010141b:	55                   	push   %ebp
f010141c:	89 e5                	mov    %esp,%ebp
f010141e:	56                   	push   %esi
f010141f:	53                   	push   %ebx
f0101420:	8b 75 08             	mov    0x8(%ebp),%esi
f0101423:	8b 55 0c             	mov    0xc(%ebp),%edx
f0101426:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0101429:	85 db                	test   %ebx,%ebx
f010142b:	74 17                	je     f0101444 <strncpy+0x29>
f010142d:	01 f3                	add    %esi,%ebx
f010142f:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f0101431:	83 c1 01             	add    $0x1,%ecx
f0101434:	0f b6 02             	movzbl (%edx),%eax
f0101437:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f010143a:	80 3a 01             	cmpb   $0x1,(%edx)
f010143d:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0101440:	39 d9                	cmp    %ebx,%ecx
f0101442:	75 ed                	jne    f0101431 <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f0101444:	89 f0                	mov    %esi,%eax
f0101446:	5b                   	pop    %ebx
f0101447:	5e                   	pop    %esi
f0101448:	5d                   	pop    %ebp
f0101449:	c3                   	ret    

f010144a <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f010144a:	55                   	push   %ebp
f010144b:	89 e5                	mov    %esp,%ebp
f010144d:	57                   	push   %edi
f010144e:	56                   	push   %esi
f010144f:	53                   	push   %ebx
f0101450:	8b 7d 08             	mov    0x8(%ebp),%edi
f0101453:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0101456:	8b 75 10             	mov    0x10(%ebp),%esi
f0101459:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f010145b:	85 f6                	test   %esi,%esi
f010145d:	74 34                	je     f0101493 <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f010145f:	83 fe 01             	cmp    $0x1,%esi
f0101462:	74 26                	je     f010148a <strlcpy+0x40>
f0101464:	0f b6 0b             	movzbl (%ebx),%ecx
f0101467:	84 c9                	test   %cl,%cl
f0101469:	74 23                	je     f010148e <strlcpy+0x44>
f010146b:	83 ee 02             	sub    $0x2,%esi
f010146e:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f0101473:	83 c0 01             	add    $0x1,%eax
f0101476:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0101479:	39 f2                	cmp    %esi,%edx
f010147b:	74 13                	je     f0101490 <strlcpy+0x46>
f010147d:	83 c2 01             	add    $0x1,%edx
f0101480:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f0101484:	84 c9                	test   %cl,%cl
f0101486:	75 eb                	jne    f0101473 <strlcpy+0x29>
f0101488:	eb 06                	jmp    f0101490 <strlcpy+0x46>
f010148a:	89 f8                	mov    %edi,%eax
f010148c:	eb 02                	jmp    f0101490 <strlcpy+0x46>
f010148e:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f0101490:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f0101493:	29 f8                	sub    %edi,%eax
}
f0101495:	5b                   	pop    %ebx
f0101496:	5e                   	pop    %esi
f0101497:	5f                   	pop    %edi
f0101498:	5d                   	pop    %ebp
f0101499:	c3                   	ret    

f010149a <strcmp>:

int
strcmp(const char *p, const char *q)
{
f010149a:	55                   	push   %ebp
f010149b:	89 e5                	mov    %esp,%ebp
f010149d:	8b 4d 08             	mov    0x8(%ebp),%ecx
f01014a0:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f01014a3:	0f b6 01             	movzbl (%ecx),%eax
f01014a6:	84 c0                	test   %al,%al
f01014a8:	74 15                	je     f01014bf <strcmp+0x25>
f01014aa:	3a 02                	cmp    (%edx),%al
f01014ac:	75 11                	jne    f01014bf <strcmp+0x25>
		p++, q++;
f01014ae:	83 c1 01             	add    $0x1,%ecx
f01014b1:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f01014b4:	0f b6 01             	movzbl (%ecx),%eax
f01014b7:	84 c0                	test   %al,%al
f01014b9:	74 04                	je     f01014bf <strcmp+0x25>
f01014bb:	3a 02                	cmp    (%edx),%al
f01014bd:	74 ef                	je     f01014ae <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f01014bf:	0f b6 c0             	movzbl %al,%eax
f01014c2:	0f b6 12             	movzbl (%edx),%edx
f01014c5:	29 d0                	sub    %edx,%eax
}
f01014c7:	5d                   	pop    %ebp
f01014c8:	c3                   	ret    

f01014c9 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f01014c9:	55                   	push   %ebp
f01014ca:	89 e5                	mov    %esp,%ebp
f01014cc:	56                   	push   %esi
f01014cd:	53                   	push   %ebx
f01014ce:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01014d1:	8b 55 0c             	mov    0xc(%ebp),%edx
f01014d4:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f01014d7:	85 f6                	test   %esi,%esi
f01014d9:	74 29                	je     f0101504 <strncmp+0x3b>
f01014db:	0f b6 03             	movzbl (%ebx),%eax
f01014de:	84 c0                	test   %al,%al
f01014e0:	74 30                	je     f0101512 <strncmp+0x49>
f01014e2:	3a 02                	cmp    (%edx),%al
f01014e4:	75 2c                	jne    f0101512 <strncmp+0x49>
f01014e6:	8d 43 01             	lea    0x1(%ebx),%eax
f01014e9:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f01014eb:	89 c3                	mov    %eax,%ebx
f01014ed:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f01014f0:	39 f0                	cmp    %esi,%eax
f01014f2:	74 17                	je     f010150b <strncmp+0x42>
f01014f4:	0f b6 08             	movzbl (%eax),%ecx
f01014f7:	84 c9                	test   %cl,%cl
f01014f9:	74 17                	je     f0101512 <strncmp+0x49>
f01014fb:	83 c0 01             	add    $0x1,%eax
f01014fe:	3a 0a                	cmp    (%edx),%cl
f0101500:	74 e9                	je     f01014eb <strncmp+0x22>
f0101502:	eb 0e                	jmp    f0101512 <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f0101504:	b8 00 00 00 00       	mov    $0x0,%eax
f0101509:	eb 0f                	jmp    f010151a <strncmp+0x51>
f010150b:	b8 00 00 00 00       	mov    $0x0,%eax
f0101510:	eb 08                	jmp    f010151a <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f0101512:	0f b6 03             	movzbl (%ebx),%eax
f0101515:	0f b6 12             	movzbl (%edx),%edx
f0101518:	29 d0                	sub    %edx,%eax
}
f010151a:	5b                   	pop    %ebx
f010151b:	5e                   	pop    %esi
f010151c:	5d                   	pop    %ebp
f010151d:	c3                   	ret    

f010151e <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f010151e:	55                   	push   %ebp
f010151f:	89 e5                	mov    %esp,%ebp
f0101521:	53                   	push   %ebx
f0101522:	8b 45 08             	mov    0x8(%ebp),%eax
f0101525:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0101528:	0f b6 18             	movzbl (%eax),%ebx
f010152b:	84 db                	test   %bl,%bl
f010152d:	74 1d                	je     f010154c <strchr+0x2e>
f010152f:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0101531:	38 d3                	cmp    %dl,%bl
f0101533:	75 06                	jne    f010153b <strchr+0x1d>
f0101535:	eb 1a                	jmp    f0101551 <strchr+0x33>
f0101537:	38 ca                	cmp    %cl,%dl
f0101539:	74 16                	je     f0101551 <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f010153b:	83 c0 01             	add    $0x1,%eax
f010153e:	0f b6 10             	movzbl (%eax),%edx
f0101541:	84 d2                	test   %dl,%dl
f0101543:	75 f2                	jne    f0101537 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0101545:	b8 00 00 00 00       	mov    $0x0,%eax
f010154a:	eb 05                	jmp    f0101551 <strchr+0x33>
f010154c:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0101551:	5b                   	pop    %ebx
f0101552:	5d                   	pop    %ebp
f0101553:	c3                   	ret    

f0101554 <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f0101554:	55                   	push   %ebp
f0101555:	89 e5                	mov    %esp,%ebp
f0101557:	53                   	push   %ebx
f0101558:	8b 45 08             	mov    0x8(%ebp),%eax
f010155b:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f010155e:	0f b6 18             	movzbl (%eax),%ebx
f0101561:	84 db                	test   %bl,%bl
f0101563:	74 17                	je     f010157c <strfind+0x28>
f0101565:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0101567:	38 d3                	cmp    %dl,%bl
f0101569:	75 07                	jne    f0101572 <strfind+0x1e>
f010156b:	eb 0f                	jmp    f010157c <strfind+0x28>
f010156d:	38 ca                	cmp    %cl,%dl
f010156f:	90                   	nop
f0101570:	74 0a                	je     f010157c <strfind+0x28>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f0101572:	83 c0 01             	add    $0x1,%eax
f0101575:	0f b6 10             	movzbl (%eax),%edx
f0101578:	84 d2                	test   %dl,%dl
f010157a:	75 f1                	jne    f010156d <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f010157c:	5b                   	pop    %ebx
f010157d:	5d                   	pop    %ebp
f010157e:	c3                   	ret    

f010157f <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f010157f:	55                   	push   %ebp
f0101580:	89 e5                	mov    %esp,%ebp
f0101582:	57                   	push   %edi
f0101583:	56                   	push   %esi
f0101584:	53                   	push   %ebx
f0101585:	8b 7d 08             	mov    0x8(%ebp),%edi
f0101588:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f010158b:	85 c9                	test   %ecx,%ecx
f010158d:	74 36                	je     f01015c5 <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f010158f:	f7 c7 03 00 00 00    	test   $0x3,%edi
f0101595:	75 28                	jne    f01015bf <memset+0x40>
f0101597:	f6 c1 03             	test   $0x3,%cl
f010159a:	75 23                	jne    f01015bf <memset+0x40>
		c &= 0xFF;
f010159c:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f01015a0:	89 d3                	mov    %edx,%ebx
f01015a2:	c1 e3 08             	shl    $0x8,%ebx
f01015a5:	89 d6                	mov    %edx,%esi
f01015a7:	c1 e6 18             	shl    $0x18,%esi
f01015aa:	89 d0                	mov    %edx,%eax
f01015ac:	c1 e0 10             	shl    $0x10,%eax
f01015af:	09 f0                	or     %esi,%eax
f01015b1:	09 c2                	or     %eax,%edx
f01015b3:	89 d0                	mov    %edx,%eax
f01015b5:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f01015b7:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f01015ba:	fc                   	cld    
f01015bb:	f3 ab                	rep stos %eax,%es:(%edi)
f01015bd:	eb 06                	jmp    f01015c5 <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f01015bf:	8b 45 0c             	mov    0xc(%ebp),%eax
f01015c2:	fc                   	cld    
f01015c3:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f01015c5:	89 f8                	mov    %edi,%eax
f01015c7:	5b                   	pop    %ebx
f01015c8:	5e                   	pop    %esi
f01015c9:	5f                   	pop    %edi
f01015ca:	5d                   	pop    %ebp
f01015cb:	c3                   	ret    

f01015cc <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f01015cc:	55                   	push   %ebp
f01015cd:	89 e5                	mov    %esp,%ebp
f01015cf:	57                   	push   %edi
f01015d0:	56                   	push   %esi
f01015d1:	8b 45 08             	mov    0x8(%ebp),%eax
f01015d4:	8b 75 0c             	mov    0xc(%ebp),%esi
f01015d7:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f01015da:	39 c6                	cmp    %eax,%esi
f01015dc:	73 35                	jae    f0101613 <memmove+0x47>
f01015de:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f01015e1:	39 d0                	cmp    %edx,%eax
f01015e3:	73 2e                	jae    f0101613 <memmove+0x47>
		s += n;
		d += n;
f01015e5:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f01015e8:	89 d6                	mov    %edx,%esi
f01015ea:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f01015ec:	f7 c6 03 00 00 00    	test   $0x3,%esi
f01015f2:	75 13                	jne    f0101607 <memmove+0x3b>
f01015f4:	f6 c1 03             	test   $0x3,%cl
f01015f7:	75 0e                	jne    f0101607 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f01015f9:	83 ef 04             	sub    $0x4,%edi
f01015fc:	8d 72 fc             	lea    -0x4(%edx),%esi
f01015ff:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f0101602:	fd                   	std    
f0101603:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0101605:	eb 09                	jmp    f0101610 <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0101607:	83 ef 01             	sub    $0x1,%edi
f010160a:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f010160d:	fd                   	std    
f010160e:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0101610:	fc                   	cld    
f0101611:	eb 1d                	jmp    f0101630 <memmove+0x64>
f0101613:	89 f2                	mov    %esi,%edx
f0101615:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0101617:	f6 c2 03             	test   $0x3,%dl
f010161a:	75 0f                	jne    f010162b <memmove+0x5f>
f010161c:	f6 c1 03             	test   $0x3,%cl
f010161f:	75 0a                	jne    f010162b <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0101621:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f0101624:	89 c7                	mov    %eax,%edi
f0101626:	fc                   	cld    
f0101627:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0101629:	eb 05                	jmp    f0101630 <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f010162b:	89 c7                	mov    %eax,%edi
f010162d:	fc                   	cld    
f010162e:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f0101630:	5e                   	pop    %esi
f0101631:	5f                   	pop    %edi
f0101632:	5d                   	pop    %ebp
f0101633:	c3                   	ret    

f0101634 <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f0101634:	55                   	push   %ebp
f0101635:	89 e5                	mov    %esp,%ebp
f0101637:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f010163a:	8b 45 10             	mov    0x10(%ebp),%eax
f010163d:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101641:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101644:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101648:	8b 45 08             	mov    0x8(%ebp),%eax
f010164b:	89 04 24             	mov    %eax,(%esp)
f010164e:	e8 79 ff ff ff       	call   f01015cc <memmove>
}
f0101653:	c9                   	leave  
f0101654:	c3                   	ret    

f0101655 <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f0101655:	55                   	push   %ebp
f0101656:	89 e5                	mov    %esp,%ebp
f0101658:	57                   	push   %edi
f0101659:	56                   	push   %esi
f010165a:	53                   	push   %ebx
f010165b:	8b 5d 08             	mov    0x8(%ebp),%ebx
f010165e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0101661:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0101664:	8d 78 ff             	lea    -0x1(%eax),%edi
f0101667:	85 c0                	test   %eax,%eax
f0101669:	74 36                	je     f01016a1 <memcmp+0x4c>
		if (*s1 != *s2)
f010166b:	0f b6 03             	movzbl (%ebx),%eax
f010166e:	0f b6 0e             	movzbl (%esi),%ecx
f0101671:	ba 00 00 00 00       	mov    $0x0,%edx
f0101676:	38 c8                	cmp    %cl,%al
f0101678:	74 1c                	je     f0101696 <memcmp+0x41>
f010167a:	eb 10                	jmp    f010168c <memcmp+0x37>
f010167c:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f0101681:	83 c2 01             	add    $0x1,%edx
f0101684:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f0101688:	38 c8                	cmp    %cl,%al
f010168a:	74 0a                	je     f0101696 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f010168c:	0f b6 c0             	movzbl %al,%eax
f010168f:	0f b6 c9             	movzbl %cl,%ecx
f0101692:	29 c8                	sub    %ecx,%eax
f0101694:	eb 10                	jmp    f01016a6 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0101696:	39 fa                	cmp    %edi,%edx
f0101698:	75 e2                	jne    f010167c <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f010169a:	b8 00 00 00 00       	mov    $0x0,%eax
f010169f:	eb 05                	jmp    f01016a6 <memcmp+0x51>
f01016a1:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01016a6:	5b                   	pop    %ebx
f01016a7:	5e                   	pop    %esi
f01016a8:	5f                   	pop    %edi
f01016a9:	5d                   	pop    %ebp
f01016aa:	c3                   	ret    

f01016ab <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f01016ab:	55                   	push   %ebp
f01016ac:	89 e5                	mov    %esp,%ebp
f01016ae:	53                   	push   %ebx
f01016af:	8b 45 08             	mov    0x8(%ebp),%eax
f01016b2:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f01016b5:	89 c2                	mov    %eax,%edx
f01016b7:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f01016ba:	39 d0                	cmp    %edx,%eax
f01016bc:	73 14                	jae    f01016d2 <memfind+0x27>
		if (*(const unsigned char *) s == (unsigned char) c)
f01016be:	89 d9                	mov    %ebx,%ecx
f01016c0:	38 18                	cmp    %bl,(%eax)
f01016c2:	75 06                	jne    f01016ca <memfind+0x1f>
f01016c4:	eb 0c                	jmp    f01016d2 <memfind+0x27>
f01016c6:	38 08                	cmp    %cl,(%eax)
f01016c8:	74 08                	je     f01016d2 <memfind+0x27>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f01016ca:	83 c0 01             	add    $0x1,%eax
f01016cd:	39 d0                	cmp    %edx,%eax
f01016cf:	90                   	nop
f01016d0:	75 f4                	jne    f01016c6 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f01016d2:	5b                   	pop    %ebx
f01016d3:	5d                   	pop    %ebp
f01016d4:	c3                   	ret    

f01016d5 <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f01016d5:	55                   	push   %ebp
f01016d6:	89 e5                	mov    %esp,%ebp
f01016d8:	57                   	push   %edi
f01016d9:	56                   	push   %esi
f01016da:	53                   	push   %ebx
f01016db:	8b 55 08             	mov    0x8(%ebp),%edx
f01016de:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f01016e1:	0f b6 0a             	movzbl (%edx),%ecx
f01016e4:	80 f9 09             	cmp    $0x9,%cl
f01016e7:	74 05                	je     f01016ee <strtol+0x19>
f01016e9:	80 f9 20             	cmp    $0x20,%cl
f01016ec:	75 10                	jne    f01016fe <strtol+0x29>
		s++;
f01016ee:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f01016f1:	0f b6 0a             	movzbl (%edx),%ecx
f01016f4:	80 f9 09             	cmp    $0x9,%cl
f01016f7:	74 f5                	je     f01016ee <strtol+0x19>
f01016f9:	80 f9 20             	cmp    $0x20,%cl
f01016fc:	74 f0                	je     f01016ee <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f01016fe:	80 f9 2b             	cmp    $0x2b,%cl
f0101701:	75 0a                	jne    f010170d <strtol+0x38>
		s++;
f0101703:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f0101706:	bf 00 00 00 00       	mov    $0x0,%edi
f010170b:	eb 11                	jmp    f010171e <strtol+0x49>
f010170d:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f0101712:	80 f9 2d             	cmp    $0x2d,%cl
f0101715:	75 07                	jne    f010171e <strtol+0x49>
		s++, neg = 1;
f0101717:	83 c2 01             	add    $0x1,%edx
f010171a:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f010171e:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f0101723:	75 15                	jne    f010173a <strtol+0x65>
f0101725:	80 3a 30             	cmpb   $0x30,(%edx)
f0101728:	75 10                	jne    f010173a <strtol+0x65>
f010172a:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f010172e:	75 0a                	jne    f010173a <strtol+0x65>
		s += 2, base = 16;
f0101730:	83 c2 02             	add    $0x2,%edx
f0101733:	b8 10 00 00 00       	mov    $0x10,%eax
f0101738:	eb 10                	jmp    f010174a <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f010173a:	85 c0                	test   %eax,%eax
f010173c:	75 0c                	jne    f010174a <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f010173e:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0101740:	80 3a 30             	cmpb   $0x30,(%edx)
f0101743:	75 05                	jne    f010174a <strtol+0x75>
		s++, base = 8;
f0101745:	83 c2 01             	add    $0x1,%edx
f0101748:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f010174a:	bb 00 00 00 00       	mov    $0x0,%ebx
f010174f:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f0101752:	0f b6 0a             	movzbl (%edx),%ecx
f0101755:	8d 71 d0             	lea    -0x30(%ecx),%esi
f0101758:	89 f0                	mov    %esi,%eax
f010175a:	3c 09                	cmp    $0x9,%al
f010175c:	77 08                	ja     f0101766 <strtol+0x91>
			dig = *s - '0';
f010175e:	0f be c9             	movsbl %cl,%ecx
f0101761:	83 e9 30             	sub    $0x30,%ecx
f0101764:	eb 20                	jmp    f0101786 <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f0101766:	8d 71 9f             	lea    -0x61(%ecx),%esi
f0101769:	89 f0                	mov    %esi,%eax
f010176b:	3c 19                	cmp    $0x19,%al
f010176d:	77 08                	ja     f0101777 <strtol+0xa2>
			dig = *s - 'a' + 10;
f010176f:	0f be c9             	movsbl %cl,%ecx
f0101772:	83 e9 57             	sub    $0x57,%ecx
f0101775:	eb 0f                	jmp    f0101786 <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f0101777:	8d 71 bf             	lea    -0x41(%ecx),%esi
f010177a:	89 f0                	mov    %esi,%eax
f010177c:	3c 19                	cmp    $0x19,%al
f010177e:	77 16                	ja     f0101796 <strtol+0xc1>
			dig = *s - 'A' + 10;
f0101780:	0f be c9             	movsbl %cl,%ecx
f0101783:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f0101786:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f0101789:	7d 0f                	jge    f010179a <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f010178b:	83 c2 01             	add    $0x1,%edx
f010178e:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f0101792:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f0101794:	eb bc                	jmp    f0101752 <strtol+0x7d>
f0101796:	89 d8                	mov    %ebx,%eax
f0101798:	eb 02                	jmp    f010179c <strtol+0xc7>
f010179a:	89 d8                	mov    %ebx,%eax

	if (endptr)
f010179c:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f01017a0:	74 05                	je     f01017a7 <strtol+0xd2>
		*endptr = (char *) s;
f01017a2:	8b 75 0c             	mov    0xc(%ebp),%esi
f01017a5:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f01017a7:	f7 d8                	neg    %eax
f01017a9:	85 ff                	test   %edi,%edi
f01017ab:	0f 44 c3             	cmove  %ebx,%eax
}
f01017ae:	5b                   	pop    %ebx
f01017af:	5e                   	pop    %esi
f01017b0:	5f                   	pop    %edi
f01017b1:	5d                   	pop    %ebp
f01017b2:	c3                   	ret    
f01017b3:	66 90                	xchg   %ax,%ax
f01017b5:	66 90                	xchg   %ax,%ax
f01017b7:	66 90                	xchg   %ax,%ax
f01017b9:	66 90                	xchg   %ax,%ax
f01017bb:	66 90                	xchg   %ax,%ax
f01017bd:	66 90                	xchg   %ax,%ax
f01017bf:	90                   	nop

f01017c0 <__udivdi3>:
f01017c0:	55                   	push   %ebp
f01017c1:	57                   	push   %edi
f01017c2:	56                   	push   %esi
f01017c3:	83 ec 0c             	sub    $0xc,%esp
f01017c6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01017ca:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f01017ce:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f01017d2:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01017d6:	85 c0                	test   %eax,%eax
f01017d8:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01017dc:	89 ea                	mov    %ebp,%edx
f01017de:	89 0c 24             	mov    %ecx,(%esp)
f01017e1:	75 2d                	jne    f0101810 <__udivdi3+0x50>
f01017e3:	39 e9                	cmp    %ebp,%ecx
f01017e5:	77 61                	ja     f0101848 <__udivdi3+0x88>
f01017e7:	85 c9                	test   %ecx,%ecx
f01017e9:	89 ce                	mov    %ecx,%esi
f01017eb:	75 0b                	jne    f01017f8 <__udivdi3+0x38>
f01017ed:	b8 01 00 00 00       	mov    $0x1,%eax
f01017f2:	31 d2                	xor    %edx,%edx
f01017f4:	f7 f1                	div    %ecx
f01017f6:	89 c6                	mov    %eax,%esi
f01017f8:	31 d2                	xor    %edx,%edx
f01017fa:	89 e8                	mov    %ebp,%eax
f01017fc:	f7 f6                	div    %esi
f01017fe:	89 c5                	mov    %eax,%ebp
f0101800:	89 f8                	mov    %edi,%eax
f0101802:	f7 f6                	div    %esi
f0101804:	89 ea                	mov    %ebp,%edx
f0101806:	83 c4 0c             	add    $0xc,%esp
f0101809:	5e                   	pop    %esi
f010180a:	5f                   	pop    %edi
f010180b:	5d                   	pop    %ebp
f010180c:	c3                   	ret    
f010180d:	8d 76 00             	lea    0x0(%esi),%esi
f0101810:	39 e8                	cmp    %ebp,%eax
f0101812:	77 24                	ja     f0101838 <__udivdi3+0x78>
f0101814:	0f bd e8             	bsr    %eax,%ebp
f0101817:	83 f5 1f             	xor    $0x1f,%ebp
f010181a:	75 3c                	jne    f0101858 <__udivdi3+0x98>
f010181c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0101820:	39 34 24             	cmp    %esi,(%esp)
f0101823:	0f 86 9f 00 00 00    	jbe    f01018c8 <__udivdi3+0x108>
f0101829:	39 d0                	cmp    %edx,%eax
f010182b:	0f 82 97 00 00 00    	jb     f01018c8 <__udivdi3+0x108>
f0101831:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101838:	31 d2                	xor    %edx,%edx
f010183a:	31 c0                	xor    %eax,%eax
f010183c:	83 c4 0c             	add    $0xc,%esp
f010183f:	5e                   	pop    %esi
f0101840:	5f                   	pop    %edi
f0101841:	5d                   	pop    %ebp
f0101842:	c3                   	ret    
f0101843:	90                   	nop
f0101844:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101848:	89 f8                	mov    %edi,%eax
f010184a:	f7 f1                	div    %ecx
f010184c:	31 d2                	xor    %edx,%edx
f010184e:	83 c4 0c             	add    $0xc,%esp
f0101851:	5e                   	pop    %esi
f0101852:	5f                   	pop    %edi
f0101853:	5d                   	pop    %ebp
f0101854:	c3                   	ret    
f0101855:	8d 76 00             	lea    0x0(%esi),%esi
f0101858:	89 e9                	mov    %ebp,%ecx
f010185a:	8b 3c 24             	mov    (%esp),%edi
f010185d:	d3 e0                	shl    %cl,%eax
f010185f:	89 c6                	mov    %eax,%esi
f0101861:	b8 20 00 00 00       	mov    $0x20,%eax
f0101866:	29 e8                	sub    %ebp,%eax
f0101868:	89 c1                	mov    %eax,%ecx
f010186a:	d3 ef                	shr    %cl,%edi
f010186c:	89 e9                	mov    %ebp,%ecx
f010186e:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0101872:	8b 3c 24             	mov    (%esp),%edi
f0101875:	09 74 24 08          	or     %esi,0x8(%esp)
f0101879:	89 d6                	mov    %edx,%esi
f010187b:	d3 e7                	shl    %cl,%edi
f010187d:	89 c1                	mov    %eax,%ecx
f010187f:	89 3c 24             	mov    %edi,(%esp)
f0101882:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0101886:	d3 ee                	shr    %cl,%esi
f0101888:	89 e9                	mov    %ebp,%ecx
f010188a:	d3 e2                	shl    %cl,%edx
f010188c:	89 c1                	mov    %eax,%ecx
f010188e:	d3 ef                	shr    %cl,%edi
f0101890:	09 d7                	or     %edx,%edi
f0101892:	89 f2                	mov    %esi,%edx
f0101894:	89 f8                	mov    %edi,%eax
f0101896:	f7 74 24 08          	divl   0x8(%esp)
f010189a:	89 d6                	mov    %edx,%esi
f010189c:	89 c7                	mov    %eax,%edi
f010189e:	f7 24 24             	mull   (%esp)
f01018a1:	39 d6                	cmp    %edx,%esi
f01018a3:	89 14 24             	mov    %edx,(%esp)
f01018a6:	72 30                	jb     f01018d8 <__udivdi3+0x118>
f01018a8:	8b 54 24 04          	mov    0x4(%esp),%edx
f01018ac:	89 e9                	mov    %ebp,%ecx
f01018ae:	d3 e2                	shl    %cl,%edx
f01018b0:	39 c2                	cmp    %eax,%edx
f01018b2:	73 05                	jae    f01018b9 <__udivdi3+0xf9>
f01018b4:	3b 34 24             	cmp    (%esp),%esi
f01018b7:	74 1f                	je     f01018d8 <__udivdi3+0x118>
f01018b9:	89 f8                	mov    %edi,%eax
f01018bb:	31 d2                	xor    %edx,%edx
f01018bd:	e9 7a ff ff ff       	jmp    f010183c <__udivdi3+0x7c>
f01018c2:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f01018c8:	31 d2                	xor    %edx,%edx
f01018ca:	b8 01 00 00 00       	mov    $0x1,%eax
f01018cf:	e9 68 ff ff ff       	jmp    f010183c <__udivdi3+0x7c>
f01018d4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01018d8:	8d 47 ff             	lea    -0x1(%edi),%eax
f01018db:	31 d2                	xor    %edx,%edx
f01018dd:	83 c4 0c             	add    $0xc,%esp
f01018e0:	5e                   	pop    %esi
f01018e1:	5f                   	pop    %edi
f01018e2:	5d                   	pop    %ebp
f01018e3:	c3                   	ret    
f01018e4:	66 90                	xchg   %ax,%ax
f01018e6:	66 90                	xchg   %ax,%ax
f01018e8:	66 90                	xchg   %ax,%ax
f01018ea:	66 90                	xchg   %ax,%ax
f01018ec:	66 90                	xchg   %ax,%ax
f01018ee:	66 90                	xchg   %ax,%ax

f01018f0 <__umoddi3>:
f01018f0:	55                   	push   %ebp
f01018f1:	57                   	push   %edi
f01018f2:	56                   	push   %esi
f01018f3:	83 ec 14             	sub    $0x14,%esp
f01018f6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01018fa:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01018fe:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0101902:	89 c7                	mov    %eax,%edi
f0101904:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101908:	8b 44 24 30          	mov    0x30(%esp),%eax
f010190c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0101910:	89 34 24             	mov    %esi,(%esp)
f0101913:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101917:	85 c0                	test   %eax,%eax
f0101919:	89 c2                	mov    %eax,%edx
f010191b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f010191f:	75 17                	jne    f0101938 <__umoddi3+0x48>
f0101921:	39 fe                	cmp    %edi,%esi
f0101923:	76 4b                	jbe    f0101970 <__umoddi3+0x80>
f0101925:	89 c8                	mov    %ecx,%eax
f0101927:	89 fa                	mov    %edi,%edx
f0101929:	f7 f6                	div    %esi
f010192b:	89 d0                	mov    %edx,%eax
f010192d:	31 d2                	xor    %edx,%edx
f010192f:	83 c4 14             	add    $0x14,%esp
f0101932:	5e                   	pop    %esi
f0101933:	5f                   	pop    %edi
f0101934:	5d                   	pop    %ebp
f0101935:	c3                   	ret    
f0101936:	66 90                	xchg   %ax,%ax
f0101938:	39 f8                	cmp    %edi,%eax
f010193a:	77 54                	ja     f0101990 <__umoddi3+0xa0>
f010193c:	0f bd e8             	bsr    %eax,%ebp
f010193f:	83 f5 1f             	xor    $0x1f,%ebp
f0101942:	75 5c                	jne    f01019a0 <__umoddi3+0xb0>
f0101944:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0101948:	39 3c 24             	cmp    %edi,(%esp)
f010194b:	0f 87 e7 00 00 00    	ja     f0101a38 <__umoddi3+0x148>
f0101951:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0101955:	29 f1                	sub    %esi,%ecx
f0101957:	19 c7                	sbb    %eax,%edi
f0101959:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f010195d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0101961:	8b 44 24 08          	mov    0x8(%esp),%eax
f0101965:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0101969:	83 c4 14             	add    $0x14,%esp
f010196c:	5e                   	pop    %esi
f010196d:	5f                   	pop    %edi
f010196e:	5d                   	pop    %ebp
f010196f:	c3                   	ret    
f0101970:	85 f6                	test   %esi,%esi
f0101972:	89 f5                	mov    %esi,%ebp
f0101974:	75 0b                	jne    f0101981 <__umoddi3+0x91>
f0101976:	b8 01 00 00 00       	mov    $0x1,%eax
f010197b:	31 d2                	xor    %edx,%edx
f010197d:	f7 f6                	div    %esi
f010197f:	89 c5                	mov    %eax,%ebp
f0101981:	8b 44 24 04          	mov    0x4(%esp),%eax
f0101985:	31 d2                	xor    %edx,%edx
f0101987:	f7 f5                	div    %ebp
f0101989:	89 c8                	mov    %ecx,%eax
f010198b:	f7 f5                	div    %ebp
f010198d:	eb 9c                	jmp    f010192b <__umoddi3+0x3b>
f010198f:	90                   	nop
f0101990:	89 c8                	mov    %ecx,%eax
f0101992:	89 fa                	mov    %edi,%edx
f0101994:	83 c4 14             	add    $0x14,%esp
f0101997:	5e                   	pop    %esi
f0101998:	5f                   	pop    %edi
f0101999:	5d                   	pop    %ebp
f010199a:	c3                   	ret    
f010199b:	90                   	nop
f010199c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01019a0:	8b 04 24             	mov    (%esp),%eax
f01019a3:	be 20 00 00 00       	mov    $0x20,%esi
f01019a8:	89 e9                	mov    %ebp,%ecx
f01019aa:	29 ee                	sub    %ebp,%esi
f01019ac:	d3 e2                	shl    %cl,%edx
f01019ae:	89 f1                	mov    %esi,%ecx
f01019b0:	d3 e8                	shr    %cl,%eax
f01019b2:	89 e9                	mov    %ebp,%ecx
f01019b4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01019b8:	8b 04 24             	mov    (%esp),%eax
f01019bb:	09 54 24 04          	or     %edx,0x4(%esp)
f01019bf:	89 fa                	mov    %edi,%edx
f01019c1:	d3 e0                	shl    %cl,%eax
f01019c3:	89 f1                	mov    %esi,%ecx
f01019c5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01019c9:	8b 44 24 10          	mov    0x10(%esp),%eax
f01019cd:	d3 ea                	shr    %cl,%edx
f01019cf:	89 e9                	mov    %ebp,%ecx
f01019d1:	d3 e7                	shl    %cl,%edi
f01019d3:	89 f1                	mov    %esi,%ecx
f01019d5:	d3 e8                	shr    %cl,%eax
f01019d7:	89 e9                	mov    %ebp,%ecx
f01019d9:	09 f8                	or     %edi,%eax
f01019db:	8b 7c 24 10          	mov    0x10(%esp),%edi
f01019df:	f7 74 24 04          	divl   0x4(%esp)
f01019e3:	d3 e7                	shl    %cl,%edi
f01019e5:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01019e9:	89 d7                	mov    %edx,%edi
f01019eb:	f7 64 24 08          	mull   0x8(%esp)
f01019ef:	39 d7                	cmp    %edx,%edi
f01019f1:	89 c1                	mov    %eax,%ecx
f01019f3:	89 14 24             	mov    %edx,(%esp)
f01019f6:	72 2c                	jb     f0101a24 <__umoddi3+0x134>
f01019f8:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f01019fc:	72 22                	jb     f0101a20 <__umoddi3+0x130>
f01019fe:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0101a02:	29 c8                	sub    %ecx,%eax
f0101a04:	19 d7                	sbb    %edx,%edi
f0101a06:	89 e9                	mov    %ebp,%ecx
f0101a08:	89 fa                	mov    %edi,%edx
f0101a0a:	d3 e8                	shr    %cl,%eax
f0101a0c:	89 f1                	mov    %esi,%ecx
f0101a0e:	d3 e2                	shl    %cl,%edx
f0101a10:	89 e9                	mov    %ebp,%ecx
f0101a12:	d3 ef                	shr    %cl,%edi
f0101a14:	09 d0                	or     %edx,%eax
f0101a16:	89 fa                	mov    %edi,%edx
f0101a18:	83 c4 14             	add    $0x14,%esp
f0101a1b:	5e                   	pop    %esi
f0101a1c:	5f                   	pop    %edi
f0101a1d:	5d                   	pop    %ebp
f0101a1e:	c3                   	ret    
f0101a1f:	90                   	nop
f0101a20:	39 d7                	cmp    %edx,%edi
f0101a22:	75 da                	jne    f01019fe <__umoddi3+0x10e>
f0101a24:	8b 14 24             	mov    (%esp),%edx
f0101a27:	89 c1                	mov    %eax,%ecx
f0101a29:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f0101a2d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0101a31:	eb cb                	jmp    f01019fe <__umoddi3+0x10e>
f0101a33:	90                   	nop
f0101a34:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101a38:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f0101a3c:	0f 82 0f ff ff ff    	jb     f0101951 <__umoddi3+0x61>
f0101a42:	e9 1a ff ff ff       	jmp    f0101961 <__umoddi3+0x71>
