
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
f0100015:	b8 00 50 11 00       	mov    $0x115000,%eax
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
f0100034:	bc 00 50 11 f0       	mov    $0xf0115000,%esp

	# now to C code
	call	i386_init
f0100039:	e8 02 00 00 00       	call   f0100040 <i386_init>

f010003e <spin>:

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <i386_init>:
#include <kern/kclock.h>


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
f0100046:	b8 8c 79 11 f0       	mov    $0xf011798c,%eax
f010004b:	2d 00 73 11 f0       	sub    $0xf0117300,%eax
f0100050:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100054:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010005b:	00 
f010005c:	c7 04 24 00 73 11 f0 	movl   $0xf0117300,(%esp)
f0100063:	e8 37 3a 00 00       	call   f0103a9f <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f0100068:	e8 a2 04 00 00       	call   f010050f <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f010006d:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f0100074:	00 
f0100075:	c7 04 24 80 3f 10 f0 	movl   $0xf0103f80,(%esp)
f010007c:	e8 84 2e 00 00       	call   f0102f05 <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f0100081:	e8 1a 11 00 00       	call   f01011a0 <mem_init>

	// Drop into the kernel monitor.
	while (1)
		monitor(NULL);
f0100086:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010008d:	e8 70 07 00 00       	call   f0100802 <monitor>
f0100092:	eb f2                	jmp    f0100086 <i386_init+0x46>

f0100094 <_panic>:
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void
_panic(const char *file, int line, const char *fmt,...)
{
f0100094:	55                   	push   %ebp
f0100095:	89 e5                	mov    %esp,%ebp
f0100097:	56                   	push   %esi
f0100098:	53                   	push   %ebx
f0100099:	83 ec 10             	sub    $0x10,%esp
f010009c:	8b 75 10             	mov    0x10(%ebp),%esi
	va_list ap;

	if (panicstr)
f010009f:	83 3d 00 73 11 f0 00 	cmpl   $0x0,0xf0117300
f01000a6:	75 3d                	jne    f01000e5 <_panic+0x51>
		goto dead;
	panicstr = fmt;
f01000a8:	89 35 00 73 11 f0    	mov    %esi,0xf0117300

	// Be extra sure that the machine is in as reasonable state
	__asm __volatile("cli; cld");
f01000ae:	fa                   	cli    
f01000af:	fc                   	cld    

	va_start(ap, fmt);
f01000b0:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic at %s:%d: ", file, line);
f01000b3:	8b 45 0c             	mov    0xc(%ebp),%eax
f01000b6:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000ba:	8b 45 08             	mov    0x8(%ebp),%eax
f01000bd:	89 44 24 04          	mov    %eax,0x4(%esp)
f01000c1:	c7 04 24 9b 3f 10 f0 	movl   $0xf0103f9b,(%esp)
f01000c8:	e8 38 2e 00 00       	call   f0102f05 <cprintf>
	vcprintf(fmt, ap);
f01000cd:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01000d1:	89 34 24             	mov    %esi,(%esp)
f01000d4:	e8 f9 2d 00 00       	call   f0102ed2 <vcprintf>
	cprintf("\n");
f01000d9:	c7 04 24 a8 4e 10 f0 	movl   $0xf0104ea8,(%esp)
f01000e0:	e8 20 2e 00 00       	call   f0102f05 <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f01000e5:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000ec:	e8 11 07 00 00       	call   f0100802 <monitor>
f01000f1:	eb f2                	jmp    f01000e5 <_panic+0x51>

f01000f3 <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f01000f3:	55                   	push   %ebp
f01000f4:	89 e5                	mov    %esp,%ebp
f01000f6:	53                   	push   %ebx
f01000f7:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f01000fa:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f01000fd:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100100:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100104:	8b 45 08             	mov    0x8(%ebp),%eax
f0100107:	89 44 24 04          	mov    %eax,0x4(%esp)
f010010b:	c7 04 24 b3 3f 10 f0 	movl   $0xf0103fb3,(%esp)
f0100112:	e8 ee 2d 00 00       	call   f0102f05 <cprintf>
	vcprintf(fmt, ap);
f0100117:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010011b:	8b 45 10             	mov    0x10(%ebp),%eax
f010011e:	89 04 24             	mov    %eax,(%esp)
f0100121:	e8 ac 2d 00 00       	call   f0102ed2 <vcprintf>
	cprintf("\n");
f0100126:	c7 04 24 a8 4e 10 f0 	movl   $0xf0104ea8,(%esp)
f010012d:	e8 d3 2d 00 00       	call   f0102f05 <cprintf>
	va_end(ap);
}
f0100132:	83 c4 14             	add    $0x14,%esp
f0100135:	5b                   	pop    %ebx
f0100136:	5d                   	pop    %ebp
f0100137:	c3                   	ret    
f0100138:	66 90                	xchg   %ax,%ax
f010013a:	66 90                	xchg   %ax,%ax
f010013c:	66 90                	xchg   %ax,%ax
f010013e:	66 90                	xchg   %ax,%ax

f0100140 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f0100140:	55                   	push   %ebp
f0100141:	89 e5                	mov    %esp,%ebp

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100143:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100148:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f0100149:	a8 01                	test   $0x1,%al
f010014b:	74 08                	je     f0100155 <serial_proc_data+0x15>
f010014d:	b2 f8                	mov    $0xf8,%dl
f010014f:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f0100150:	0f b6 c0             	movzbl %al,%eax
f0100153:	eb 05                	jmp    f010015a <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f0100155:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f010015a:	5d                   	pop    %ebp
f010015b:	c3                   	ret    

f010015c <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f010015c:	55                   	push   %ebp
f010015d:	89 e5                	mov    %esp,%ebp
f010015f:	53                   	push   %ebx
f0100160:	83 ec 04             	sub    $0x4,%esp
f0100163:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f0100165:	eb 2a                	jmp    f0100191 <cons_intr+0x35>
		if (c == 0)
f0100167:	85 d2                	test   %edx,%edx
f0100169:	74 26                	je     f0100191 <cons_intr+0x35>
			continue;
		cons.buf[cons.wpos++] = c;
f010016b:	a1 44 75 11 f0       	mov    0xf0117544,%eax
f0100170:	8d 48 01             	lea    0x1(%eax),%ecx
f0100173:	89 0d 44 75 11 f0    	mov    %ecx,0xf0117544
f0100179:	88 90 40 73 11 f0    	mov    %dl,-0xfee8cc0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f010017f:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100185:	75 0a                	jne    f0100191 <cons_intr+0x35>
			cons.wpos = 0;
f0100187:	c7 05 44 75 11 f0 00 	movl   $0x0,0xf0117544
f010018e:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f0100191:	ff d3                	call   *%ebx
f0100193:	89 c2                	mov    %eax,%edx
f0100195:	83 f8 ff             	cmp    $0xffffffff,%eax
f0100198:	75 cd                	jne    f0100167 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f010019a:	83 c4 04             	add    $0x4,%esp
f010019d:	5b                   	pop    %ebx
f010019e:	5d                   	pop    %ebp
f010019f:	c3                   	ret    

f01001a0 <kbd_proc_data>:
f01001a0:	ba 64 00 00 00       	mov    $0x64,%edx
f01001a5:	ec                   	in     (%dx),%al
{
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
f01001a6:	a8 01                	test   $0x1,%al
f01001a8:	0f 84 ef 00 00 00    	je     f010029d <kbd_proc_data+0xfd>
f01001ae:	b2 60                	mov    $0x60,%dl
f01001b0:	ec                   	in     (%dx),%al
f01001b1:	89 c2                	mov    %eax,%edx
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f01001b3:	3c e0                	cmp    $0xe0,%al
f01001b5:	75 0d                	jne    f01001c4 <kbd_proc_data+0x24>
		// E0 escape character
		shift |= E0ESC;
f01001b7:	83 0d 20 73 11 f0 40 	orl    $0x40,0xf0117320
		return 0;
f01001be:	b8 00 00 00 00       	mov    $0x0,%eax
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f01001c3:	c3                   	ret    
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f01001c4:	55                   	push   %ebp
f01001c5:	89 e5                	mov    %esp,%ebp
f01001c7:	53                   	push   %ebx
f01001c8:	83 ec 14             	sub    $0x14,%esp

	if (data == 0xE0) {
		// E0 escape character
		shift |= E0ESC;
		return 0;
	} else if (data & 0x80) {
f01001cb:	84 c0                	test   %al,%al
f01001cd:	79 37                	jns    f0100206 <kbd_proc_data+0x66>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f01001cf:	8b 0d 20 73 11 f0    	mov    0xf0117320,%ecx
f01001d5:	89 cb                	mov    %ecx,%ebx
f01001d7:	83 e3 40             	and    $0x40,%ebx
f01001da:	83 e0 7f             	and    $0x7f,%eax
f01001dd:	85 db                	test   %ebx,%ebx
f01001df:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f01001e2:	0f b6 d2             	movzbl %dl,%edx
f01001e5:	0f b6 82 20 41 10 f0 	movzbl -0xfefbee0(%edx),%eax
f01001ec:	83 c8 40             	or     $0x40,%eax
f01001ef:	0f b6 c0             	movzbl %al,%eax
f01001f2:	f7 d0                	not    %eax
f01001f4:	21 c1                	and    %eax,%ecx
f01001f6:	89 0d 20 73 11 f0    	mov    %ecx,0xf0117320
		return 0;
f01001fc:	b8 00 00 00 00       	mov    $0x0,%eax
f0100201:	e9 9d 00 00 00       	jmp    f01002a3 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f0100206:	8b 0d 20 73 11 f0    	mov    0xf0117320,%ecx
f010020c:	f6 c1 40             	test   $0x40,%cl
f010020f:	74 0e                	je     f010021f <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f0100211:	83 c8 80             	or     $0xffffff80,%eax
f0100214:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f0100216:	83 e1 bf             	and    $0xffffffbf,%ecx
f0100219:	89 0d 20 73 11 f0    	mov    %ecx,0xf0117320
	}

	shift |= shiftcode[data];
f010021f:	0f b6 d2             	movzbl %dl,%edx
f0100222:	0f b6 82 20 41 10 f0 	movzbl -0xfefbee0(%edx),%eax
f0100229:	0b 05 20 73 11 f0    	or     0xf0117320,%eax
	shift ^= togglecode[data];
f010022f:	0f b6 8a 20 40 10 f0 	movzbl -0xfefbfe0(%edx),%ecx
f0100236:	31 c8                	xor    %ecx,%eax
f0100238:	a3 20 73 11 f0       	mov    %eax,0xf0117320

	c = charcode[shift & (CTL | SHIFT)][data];
f010023d:	89 c1                	mov    %eax,%ecx
f010023f:	83 e1 03             	and    $0x3,%ecx
f0100242:	8b 0c 8d 00 40 10 f0 	mov    -0xfefc000(,%ecx,4),%ecx
f0100249:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f010024d:	0f b6 da             	movzbl %dl,%ebx
	if (shift & CAPSLOCK) {
f0100250:	a8 08                	test   $0x8,%al
f0100252:	74 1b                	je     f010026f <kbd_proc_data+0xcf>
		if ('a' <= c && c <= 'z')
f0100254:	89 da                	mov    %ebx,%edx
f0100256:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f0100259:	83 f9 19             	cmp    $0x19,%ecx
f010025c:	77 05                	ja     f0100263 <kbd_proc_data+0xc3>
			c += 'A' - 'a';
f010025e:	83 eb 20             	sub    $0x20,%ebx
f0100261:	eb 0c                	jmp    f010026f <kbd_proc_data+0xcf>
		else if ('A' <= c && c <= 'Z')
f0100263:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f0100266:	8d 4b 20             	lea    0x20(%ebx),%ecx
f0100269:	83 fa 19             	cmp    $0x19,%edx
f010026c:	0f 46 d9             	cmovbe %ecx,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f010026f:	f7 d0                	not    %eax
f0100271:	89 c2                	mov    %eax,%edx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100273:	89 d8                	mov    %ebx,%eax
			c += 'a' - 'A';
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f0100275:	f6 c2 06             	test   $0x6,%dl
f0100278:	75 29                	jne    f01002a3 <kbd_proc_data+0x103>
f010027a:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f0100280:	75 21                	jne    f01002a3 <kbd_proc_data+0x103>
		cprintf("Rebooting!\n");
f0100282:	c7 04 24 cd 3f 10 f0 	movl   $0xf0103fcd,(%esp)
f0100289:	e8 77 2c 00 00       	call   f0102f05 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010028e:	ba 92 00 00 00       	mov    $0x92,%edx
f0100293:	b8 03 00 00 00       	mov    $0x3,%eax
f0100298:	ee                   	out    %al,(%dx)
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100299:	89 d8                	mov    %ebx,%eax
f010029b:	eb 06                	jmp    f01002a3 <kbd_proc_data+0x103>
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
		return -1;
f010029d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01002a2:	c3                   	ret    
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f01002a3:	83 c4 14             	add    $0x14,%esp
f01002a6:	5b                   	pop    %ebx
f01002a7:	5d                   	pop    %ebp
f01002a8:	c3                   	ret    

f01002a9 <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f01002a9:	55                   	push   %ebp
f01002aa:	89 e5                	mov    %esp,%ebp
f01002ac:	57                   	push   %edi
f01002ad:	56                   	push   %esi
f01002ae:	53                   	push   %ebx
f01002af:	83 ec 1c             	sub    $0x1c,%esp
f01002b2:	89 c7                	mov    %eax,%edi

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01002b4:	ba fd 03 00 00       	mov    $0x3fd,%edx
f01002b9:	ec                   	in     (%dx),%al
static void
serial_putc(int c)
{
	int i;
	
	for (i = 0;
f01002ba:	a8 20                	test   $0x20,%al
f01002bc:	75 21                	jne    f01002df <cons_putc+0x36>
f01002be:	bb 00 32 00 00       	mov    $0x3200,%ebx
f01002c3:	b9 84 00 00 00       	mov    $0x84,%ecx
f01002c8:	be fd 03 00 00       	mov    $0x3fd,%esi
f01002cd:	89 ca                	mov    %ecx,%edx
f01002cf:	ec                   	in     (%dx),%al
f01002d0:	ec                   	in     (%dx),%al
f01002d1:	ec                   	in     (%dx),%al
f01002d2:	ec                   	in     (%dx),%al
f01002d3:	89 f2                	mov    %esi,%edx
f01002d5:	ec                   	in     (%dx),%al
f01002d6:	a8 20                	test   $0x20,%al
f01002d8:	75 05                	jne    f01002df <cons_putc+0x36>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f01002da:	83 eb 01             	sub    $0x1,%ebx
f01002dd:	75 ee                	jne    f01002cd <cons_putc+0x24>
	     i++)
		delay();
	
	outb(COM1 + COM_TX, c);
f01002df:	89 f8                	mov    %edi,%eax
f01002e1:	0f b6 c0             	movzbl %al,%eax
f01002e4:	89 45 e4             	mov    %eax,-0x1c(%ebp)
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01002e7:	ba f8 03 00 00       	mov    $0x3f8,%edx
f01002ec:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01002ed:	b2 79                	mov    $0x79,%dl
f01002ef:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f01002f0:	84 c0                	test   %al,%al
f01002f2:	78 21                	js     f0100315 <cons_putc+0x6c>
f01002f4:	bb 00 32 00 00       	mov    $0x3200,%ebx
f01002f9:	b9 84 00 00 00       	mov    $0x84,%ecx
f01002fe:	be 79 03 00 00       	mov    $0x379,%esi
f0100303:	89 ca                	mov    %ecx,%edx
f0100305:	ec                   	in     (%dx),%al
f0100306:	ec                   	in     (%dx),%al
f0100307:	ec                   	in     (%dx),%al
f0100308:	ec                   	in     (%dx),%al
f0100309:	89 f2                	mov    %esi,%edx
f010030b:	ec                   	in     (%dx),%al
f010030c:	84 c0                	test   %al,%al
f010030e:	78 05                	js     f0100315 <cons_putc+0x6c>
f0100310:	83 eb 01             	sub    $0x1,%ebx
f0100313:	75 ee                	jne    f0100303 <cons_putc+0x5a>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100315:	ba 78 03 00 00       	mov    $0x378,%edx
f010031a:	0f b6 45 e4          	movzbl -0x1c(%ebp),%eax
f010031e:	ee                   	out    %al,(%dx)
f010031f:	b2 7a                	mov    $0x7a,%dl
f0100321:	b8 0d 00 00 00       	mov    $0xd,%eax
f0100326:	ee                   	out    %al,(%dx)
f0100327:	b8 08 00 00 00       	mov    $0x8,%eax
f010032c:	ee                   	out    %al,(%dx)

static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f010032d:	89 fa                	mov    %edi,%edx
f010032f:	81 e2 00 ff ff ff    	and    $0xffffff00,%edx
		c |= 0x0700;
f0100335:	89 f8                	mov    %edi,%eax
f0100337:	80 cc 07             	or     $0x7,%ah
f010033a:	85 d2                	test   %edx,%edx
f010033c:	0f 44 f8             	cmove  %eax,%edi

	switch (c & 0xff) {
f010033f:	89 f8                	mov    %edi,%eax
f0100341:	0f b6 c0             	movzbl %al,%eax
f0100344:	83 f8 09             	cmp    $0x9,%eax
f0100347:	74 79                	je     f01003c2 <cons_putc+0x119>
f0100349:	83 f8 09             	cmp    $0x9,%eax
f010034c:	7f 0a                	jg     f0100358 <cons_putc+0xaf>
f010034e:	83 f8 08             	cmp    $0x8,%eax
f0100351:	74 19                	je     f010036c <cons_putc+0xc3>
f0100353:	e9 9e 00 00 00       	jmp    f01003f6 <cons_putc+0x14d>
f0100358:	83 f8 0a             	cmp    $0xa,%eax
f010035b:	90                   	nop
f010035c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100360:	74 3a                	je     f010039c <cons_putc+0xf3>
f0100362:	83 f8 0d             	cmp    $0xd,%eax
f0100365:	74 3d                	je     f01003a4 <cons_putc+0xfb>
f0100367:	e9 8a 00 00 00       	jmp    f01003f6 <cons_putc+0x14d>
	case '\b':
		if (crt_pos > 0) {
f010036c:	0f b7 05 48 75 11 f0 	movzwl 0xf0117548,%eax
f0100373:	66 85 c0             	test   %ax,%ax
f0100376:	0f 84 e5 00 00 00    	je     f0100461 <cons_putc+0x1b8>
			crt_pos--;
f010037c:	83 e8 01             	sub    $0x1,%eax
f010037f:	66 a3 48 75 11 f0    	mov    %ax,0xf0117548
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100385:	0f b7 c0             	movzwl %ax,%eax
f0100388:	66 81 e7 00 ff       	and    $0xff00,%di
f010038d:	83 cf 20             	or     $0x20,%edi
f0100390:	8b 15 4c 75 11 f0    	mov    0xf011754c,%edx
f0100396:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f010039a:	eb 78                	jmp    f0100414 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f010039c:	66 83 05 48 75 11 f0 	addw   $0x50,0xf0117548
f01003a3:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f01003a4:	0f b7 05 48 75 11 f0 	movzwl 0xf0117548,%eax
f01003ab:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f01003b1:	c1 e8 16             	shr    $0x16,%eax
f01003b4:	8d 04 80             	lea    (%eax,%eax,4),%eax
f01003b7:	c1 e0 04             	shl    $0x4,%eax
f01003ba:	66 a3 48 75 11 f0    	mov    %ax,0xf0117548
f01003c0:	eb 52                	jmp    f0100414 <cons_putc+0x16b>
		break;
	case '\t':
		cons_putc(' ');
f01003c2:	b8 20 00 00 00       	mov    $0x20,%eax
f01003c7:	e8 dd fe ff ff       	call   f01002a9 <cons_putc>
		cons_putc(' ');
f01003cc:	b8 20 00 00 00       	mov    $0x20,%eax
f01003d1:	e8 d3 fe ff ff       	call   f01002a9 <cons_putc>
		cons_putc(' ');
f01003d6:	b8 20 00 00 00       	mov    $0x20,%eax
f01003db:	e8 c9 fe ff ff       	call   f01002a9 <cons_putc>
		cons_putc(' ');
f01003e0:	b8 20 00 00 00       	mov    $0x20,%eax
f01003e5:	e8 bf fe ff ff       	call   f01002a9 <cons_putc>
		cons_putc(' ');
f01003ea:	b8 20 00 00 00       	mov    $0x20,%eax
f01003ef:	e8 b5 fe ff ff       	call   f01002a9 <cons_putc>
f01003f4:	eb 1e                	jmp    f0100414 <cons_putc+0x16b>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f01003f6:	0f b7 05 48 75 11 f0 	movzwl 0xf0117548,%eax
f01003fd:	8d 50 01             	lea    0x1(%eax),%edx
f0100400:	66 89 15 48 75 11 f0 	mov    %dx,0xf0117548
f0100407:	0f b7 c0             	movzwl %ax,%eax
f010040a:	8b 15 4c 75 11 f0    	mov    0xf011754c,%edx
f0100410:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f0100414:	66 81 3d 48 75 11 f0 	cmpw   $0x7cf,0xf0117548
f010041b:	cf 07 
f010041d:	76 42                	jbe    f0100461 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f010041f:	a1 4c 75 11 f0       	mov    0xf011754c,%eax
f0100424:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010042b:	00 
f010042c:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100432:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100436:	89 04 24             	mov    %eax,(%esp)
f0100439:	e8 ae 36 00 00       	call   f0103aec <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010043e:	8b 15 4c 75 11 f0    	mov    0xf011754c,%edx
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f0100444:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f0100449:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f010044f:	83 c0 01             	add    $0x1,%eax
f0100452:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f0100457:	75 f0                	jne    f0100449 <cons_putc+0x1a0>
			crt_buf[i] = 0x0700 | ' ';
		crt_pos -= CRT_COLS;
f0100459:	66 83 2d 48 75 11 f0 	subw   $0x50,0xf0117548
f0100460:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100461:	8b 0d 50 75 11 f0    	mov    0xf0117550,%ecx
f0100467:	b8 0e 00 00 00       	mov    $0xe,%eax
f010046c:	89 ca                	mov    %ecx,%edx
f010046e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010046f:	0f b7 1d 48 75 11 f0 	movzwl 0xf0117548,%ebx
f0100476:	8d 71 01             	lea    0x1(%ecx),%esi
f0100479:	89 d8                	mov    %ebx,%eax
f010047b:	66 c1 e8 08          	shr    $0x8,%ax
f010047f:	89 f2                	mov    %esi,%edx
f0100481:	ee                   	out    %al,(%dx)
f0100482:	b8 0f 00 00 00       	mov    $0xf,%eax
f0100487:	89 ca                	mov    %ecx,%edx
f0100489:	ee                   	out    %al,(%dx)
f010048a:	89 d8                	mov    %ebx,%eax
f010048c:	89 f2                	mov    %esi,%edx
f010048e:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f010048f:	83 c4 1c             	add    $0x1c,%esp
f0100492:	5b                   	pop    %ebx
f0100493:	5e                   	pop    %esi
f0100494:	5f                   	pop    %edi
f0100495:	5d                   	pop    %ebp
f0100496:	c3                   	ret    

f0100497 <serial_intr>:
}

void
serial_intr(void)
{
	if (serial_exists)
f0100497:	83 3d 54 75 11 f0 00 	cmpl   $0x0,0xf0117554
f010049e:	74 11                	je     f01004b1 <serial_intr+0x1a>
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f01004a0:	55                   	push   %ebp
f01004a1:	89 e5                	mov    %esp,%ebp
f01004a3:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
		cons_intr(serial_proc_data);
f01004a6:	b8 40 01 10 f0       	mov    $0xf0100140,%eax
f01004ab:	e8 ac fc ff ff       	call   f010015c <cons_intr>
}
f01004b0:	c9                   	leave  
f01004b1:	f3 c3                	repz ret 

f01004b3 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f01004b3:	55                   	push   %ebp
f01004b4:	89 e5                	mov    %esp,%ebp
f01004b6:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f01004b9:	b8 a0 01 10 f0       	mov    $0xf01001a0,%eax
f01004be:	e8 99 fc ff ff       	call   f010015c <cons_intr>
}
f01004c3:	c9                   	leave  
f01004c4:	c3                   	ret    

f01004c5 <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f01004c5:	55                   	push   %ebp
f01004c6:	89 e5                	mov    %esp,%ebp
f01004c8:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f01004cb:	e8 c7 ff ff ff       	call   f0100497 <serial_intr>
	kbd_intr();
f01004d0:	e8 de ff ff ff       	call   f01004b3 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f01004d5:	a1 40 75 11 f0       	mov    0xf0117540,%eax
f01004da:	3b 05 44 75 11 f0    	cmp    0xf0117544,%eax
f01004e0:	74 26                	je     f0100508 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f01004e2:	8d 50 01             	lea    0x1(%eax),%edx
f01004e5:	89 15 40 75 11 f0    	mov    %edx,0xf0117540
f01004eb:	0f b6 88 40 73 11 f0 	movzbl -0xfee8cc0(%eax),%ecx
		if (cons.rpos == CONSBUFSIZE)
			cons.rpos = 0;
		return c;
f01004f2:	89 c8                	mov    %ecx,%eax
	kbd_intr();

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
		c = cons.buf[cons.rpos++];
		if (cons.rpos == CONSBUFSIZE)
f01004f4:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f01004fa:	75 11                	jne    f010050d <cons_getc+0x48>
			cons.rpos = 0;
f01004fc:	c7 05 40 75 11 f0 00 	movl   $0x0,0xf0117540
f0100503:	00 00 00 
f0100506:	eb 05                	jmp    f010050d <cons_getc+0x48>
		return c;
	}
	return 0;
f0100508:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010050d:	c9                   	leave  
f010050e:	c3                   	ret    

f010050f <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f010050f:	55                   	push   %ebp
f0100510:	89 e5                	mov    %esp,%ebp
f0100512:	57                   	push   %edi
f0100513:	56                   	push   %esi
f0100514:	53                   	push   %ebx
f0100515:	83 ec 1c             	sub    $0x1c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f0100518:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f010051f:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f0100526:	5a a5 
	if (*cp != 0xA55A) {
f0100528:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f010052f:	66 3d 5a a5          	cmp    $0xa55a,%ax
f0100533:	74 11                	je     f0100546 <cons_init+0x37>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f0100535:	c7 05 50 75 11 f0 b4 	movl   $0x3b4,0xf0117550
f010053c:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f010053f:	bf 00 00 0b f0       	mov    $0xf00b0000,%edi
f0100544:	eb 16                	jmp    f010055c <cons_init+0x4d>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f0100546:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f010054d:	c7 05 50 75 11 f0 d4 	movl   $0x3d4,0xf0117550
f0100554:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f0100557:	bf 00 80 0b f0       	mov    $0xf00b8000,%edi
		*cp = was;
		addr_6845 = CGA_BASE;
	}
	
	/* Extract cursor location */
	outb(addr_6845, 14);
f010055c:	8b 0d 50 75 11 f0    	mov    0xf0117550,%ecx
f0100562:	b8 0e 00 00 00       	mov    $0xe,%eax
f0100567:	89 ca                	mov    %ecx,%edx
f0100569:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f010056a:	8d 59 01             	lea    0x1(%ecx),%ebx

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010056d:	89 da                	mov    %ebx,%edx
f010056f:	ec                   	in     (%dx),%al
f0100570:	0f b6 f0             	movzbl %al,%esi
f0100573:	c1 e6 08             	shl    $0x8,%esi
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100576:	b8 0f 00 00 00       	mov    $0xf,%eax
f010057b:	89 ca                	mov    %ecx,%edx
f010057d:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010057e:	89 da                	mov    %ebx,%edx
f0100580:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f0100581:	89 3d 4c 75 11 f0    	mov    %edi,0xf011754c
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f0100587:	0f b6 d8             	movzbl %al,%ebx
f010058a:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f010058c:	66 89 35 48 75 11 f0 	mov    %si,0xf0117548
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100593:	be fa 03 00 00       	mov    $0x3fa,%esi
f0100598:	b8 00 00 00 00       	mov    $0x0,%eax
f010059d:	89 f2                	mov    %esi,%edx
f010059f:	ee                   	out    %al,(%dx)
f01005a0:	b2 fb                	mov    $0xfb,%dl
f01005a2:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f01005a7:	ee                   	out    %al,(%dx)
f01005a8:	bb f8 03 00 00       	mov    $0x3f8,%ebx
f01005ad:	b8 0c 00 00 00       	mov    $0xc,%eax
f01005b2:	89 da                	mov    %ebx,%edx
f01005b4:	ee                   	out    %al,(%dx)
f01005b5:	b2 f9                	mov    $0xf9,%dl
f01005b7:	b8 00 00 00 00       	mov    $0x0,%eax
f01005bc:	ee                   	out    %al,(%dx)
f01005bd:	b2 fb                	mov    $0xfb,%dl
f01005bf:	b8 03 00 00 00       	mov    $0x3,%eax
f01005c4:	ee                   	out    %al,(%dx)
f01005c5:	b2 fc                	mov    $0xfc,%dl
f01005c7:	b8 00 00 00 00       	mov    $0x0,%eax
f01005cc:	ee                   	out    %al,(%dx)
f01005cd:	b2 f9                	mov    $0xf9,%dl
f01005cf:	b8 01 00 00 00       	mov    $0x1,%eax
f01005d4:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01005d5:	b2 fd                	mov    $0xfd,%dl
f01005d7:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f01005d8:	3c ff                	cmp    $0xff,%al
f01005da:	0f 95 c1             	setne  %cl
f01005dd:	0f b6 c9             	movzbl %cl,%ecx
f01005e0:	89 0d 54 75 11 f0    	mov    %ecx,0xf0117554
f01005e6:	89 f2                	mov    %esi,%edx
f01005e8:	ec                   	in     (%dx),%al
f01005e9:	89 da                	mov    %ebx,%edx
f01005eb:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f01005ec:	85 c9                	test   %ecx,%ecx
f01005ee:	75 0c                	jne    f01005fc <cons_init+0xed>
		cprintf("Serial port does not exist!\n");
f01005f0:	c7 04 24 d9 3f 10 f0 	movl   $0xf0103fd9,(%esp)
f01005f7:	e8 09 29 00 00       	call   f0102f05 <cprintf>
}
f01005fc:	83 c4 1c             	add    $0x1c,%esp
f01005ff:	5b                   	pop    %ebx
f0100600:	5e                   	pop    %esi
f0100601:	5f                   	pop    %edi
f0100602:	5d                   	pop    %ebp
f0100603:	c3                   	ret    

f0100604 <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f0100604:	55                   	push   %ebp
f0100605:	89 e5                	mov    %esp,%ebp
f0100607:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f010060a:	8b 45 08             	mov    0x8(%ebp),%eax
f010060d:	e8 97 fc ff ff       	call   f01002a9 <cons_putc>
}
f0100612:	c9                   	leave  
f0100613:	c3                   	ret    

f0100614 <getchar>:

int
getchar(void)
{
f0100614:	55                   	push   %ebp
f0100615:	89 e5                	mov    %esp,%ebp
f0100617:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f010061a:	e8 a6 fe ff ff       	call   f01004c5 <cons_getc>
f010061f:	85 c0                	test   %eax,%eax
f0100621:	74 f7                	je     f010061a <getchar+0x6>
		/* do nothing */;
	return c;
}
f0100623:	c9                   	leave  
f0100624:	c3                   	ret    

f0100625 <iscons>:

int
iscons(int fdnum)
{
f0100625:	55                   	push   %ebp
f0100626:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f0100628:	b8 01 00 00 00       	mov    $0x1,%eax
f010062d:	5d                   	pop    %ebp
f010062e:	c3                   	ret    
f010062f:	90                   	nop

f0100630 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100630:	55                   	push   %ebp
f0100631:	89 e5                	mov    %esp,%ebp
f0100633:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < NCOMMANDS; i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100636:	c7 44 24 08 20 42 10 	movl   $0xf0104220,0x8(%esp)
f010063d:	f0 
f010063e:	c7 44 24 04 3e 42 10 	movl   $0xf010423e,0x4(%esp)
f0100645:	f0 
f0100646:	c7 04 24 43 42 10 f0 	movl   $0xf0104243,(%esp)
f010064d:	e8 b3 28 00 00       	call   f0102f05 <cprintf>
f0100652:	c7 44 24 08 e0 42 10 	movl   $0xf01042e0,0x8(%esp)
f0100659:	f0 
f010065a:	c7 44 24 04 4c 42 10 	movl   $0xf010424c,0x4(%esp)
f0100661:	f0 
f0100662:	c7 04 24 43 42 10 f0 	movl   $0xf0104243,(%esp)
f0100669:	e8 97 28 00 00       	call   f0102f05 <cprintf>
f010066e:	c7 44 24 08 08 43 10 	movl   $0xf0104308,0x8(%esp)
f0100675:	f0 
f0100676:	c7 44 24 04 55 42 10 	movl   $0xf0104255,0x4(%esp)
f010067d:	f0 
f010067e:	c7 04 24 43 42 10 f0 	movl   $0xf0104243,(%esp)
f0100685:	e8 7b 28 00 00       	call   f0102f05 <cprintf>
	return 0;
}
f010068a:	b8 00 00 00 00       	mov    $0x0,%eax
f010068f:	c9                   	leave  
f0100690:	c3                   	ret    

f0100691 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f0100691:	55                   	push   %ebp
f0100692:	89 e5                	mov    %esp,%ebp
f0100694:	83 ec 18             	sub    $0x18,%esp
	extern char entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f0100697:	c7 04 24 5f 42 10 f0 	movl   $0xf010425f,(%esp)
f010069e:	e8 62 28 00 00       	call   f0102f05 <cprintf>
	cprintf(" this is work 1 insert:\n");
f01006a3:	c7 04 24 78 42 10 f0 	movl   $0xf0104278,(%esp)
f01006aa:	e8 56 28 00 00       	call   f0102f05 <cprintf>
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
f01006af:	c7 44 24 08 0f 00 00 	movl   $0xf,0x8(%esp)
f01006b6:	00 
f01006b7:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
f01006be:	00 
f01006bf:	c7 04 24 34 43 10 f0 	movl   $0xf0104334,(%esp)
f01006c6:	e8 3a 28 00 00       	call   f0102f05 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
f01006cb:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f01006d2:	00 
f01006d3:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f01006da:	f0 
f01006db:	c7 04 24 6c 43 10 f0 	movl   $0xf010436c,(%esp)
f01006e2:	e8 1e 28 00 00       	call   f0102f05 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01006e7:	c7 44 24 08 67 3f 10 	movl   $0x103f67,0x8(%esp)
f01006ee:	00 
f01006ef:	c7 44 24 04 67 3f 10 	movl   $0xf0103f67,0x4(%esp)
f01006f6:	f0 
f01006f7:	c7 04 24 94 43 10 f0 	movl   $0xf0104394,(%esp)
f01006fe:	e8 02 28 00 00       	call   f0102f05 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f0100703:	c7 44 24 08 00 73 11 	movl   $0x117300,0x8(%esp)
f010070a:	00 
f010070b:	c7 44 24 04 00 73 11 	movl   $0xf0117300,0x4(%esp)
f0100712:	f0 
f0100713:	c7 04 24 b8 43 10 f0 	movl   $0xf01043b8,(%esp)
f010071a:	e8 e6 27 00 00       	call   f0102f05 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f010071f:	c7 44 24 08 8c 79 11 	movl   $0x11798c,0x8(%esp)
f0100726:	00 
f0100727:	c7 44 24 04 8c 79 11 	movl   $0xf011798c,0x4(%esp)
f010072e:	f0 
f010072f:	c7 04 24 dc 43 10 f0 	movl   $0xf01043dc,(%esp)
f0100736:	e8 ca 27 00 00       	call   f0102f05 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f010073b:	b8 8b 7d 11 f0       	mov    $0xf0117d8b,%eax
f0100740:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f0100745:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f010074b:	85 c0                	test   %eax,%eax
f010074d:	0f 48 c2             	cmovs  %edx,%eax
f0100750:	c1 f8 0a             	sar    $0xa,%eax
f0100753:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100757:	c7 04 24 00 44 10 f0 	movl   $0xf0104400,(%esp)
f010075e:	e8 a2 27 00 00       	call   f0102f05 <cprintf>
		(end-entry+1023)/1024);
	return 0;
}
f0100763:	b8 00 00 00 00       	mov    $0x0,%eax
f0100768:	c9                   	leave  
f0100769:	c3                   	ret    

f010076a <mon_backtrace>:
int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f010076a:	55                   	push   %ebp
f010076b:	89 e5                	mov    %esp,%ebp
f010076d:	56                   	push   %esi
f010076e:	53                   	push   %ebx
f010076f:	83 ec 40             	sub    $0x40,%esp
	// Your code here
	cprintf("start backtrace\n");
f0100772:	c7 04 24 91 42 10 f0 	movl   $0xf0104291,(%esp)
f0100779:	e8 87 27 00 00       	call   f0102f05 <cprintf>
	cprintf("\n");
f010077e:	c7 04 24 a8 4e 10 f0 	movl   $0xf0104ea8,(%esp)
f0100785:	e8 7b 27 00 00       	call   f0102f05 <cprintf>

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f010078a:	89 e8                	mov    %ebp,%eax
f010078c:	89 c1                	mov    %eax,%ecx
	uint32_t eip;
	uint32_t ebp = read_ebp();
	uint32_t esp;
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
f010078e:	83 f8 ff             	cmp    $0xffffffff,%eax
f0100791:	74 63                	je     f01007f6 <mon_backtrace+0x8c>
		esp = ebp+8;
		eip = *(uint32_t*)(ebp+4);
f0100793:	8b 71 04             	mov    0x4(%ecx),%esi
		if(ebp==0){
			ebp = -1;
f0100796:	bb ff ff ff ff       	mov    $0xffffffff,%ebx
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
		esp = ebp+8;
		eip = *(uint32_t*)(ebp+4);
		if(ebp==0){
f010079b:	85 c9                	test   %ecx,%ecx
f010079d:	74 02                	je     f01007a1 <mon_backtrace+0x37>
			ebp = -1;
		}else{
			ebp = *(uint32_t*)(ebp);
f010079f:	8b 19                	mov    (%ecx),%ebx
		}
		for(i=0;i<5;i++){
f01007a1:	b8 00 00 00 00       	mov    $0x0,%eax
		args[i] = *(uint32_t*)(esp+i*4);
f01007a6:	8b 54 81 08          	mov    0x8(%ecx,%eax,4),%edx
f01007aa:	89 54 85 e4          	mov    %edx,-0x1c(%ebp,%eax,4)
		if(ebp==0){
			ebp = -1;
		}else{
			ebp = *(uint32_t*)(ebp);
		}
		for(i=0;i<5;i++){
f01007ae:	83 c0 01             	add    $0x1,%eax
f01007b1:	83 f8 05             	cmp    $0x5,%eax
f01007b4:	75 f0                	jne    f01007a6 <mon_backtrace+0x3c>
		args[i] = *(uint32_t*)(esp+i*4);
	        }
                            cprintf("ebp  %08x   eip %08x   args  %08x  %08x  %08x  %08x  %08x\n",ebp,eip,args[0],args[1],args[2],args[3],args[4]);
f01007b6:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01007b9:	89 44 24 1c          	mov    %eax,0x1c(%esp)
f01007bd:	8b 45 f0             	mov    -0x10(%ebp),%eax
f01007c0:	89 44 24 18          	mov    %eax,0x18(%esp)
f01007c4:	8b 45 ec             	mov    -0x14(%ebp),%eax
f01007c7:	89 44 24 14          	mov    %eax,0x14(%esp)
f01007cb:	8b 45 e8             	mov    -0x18(%ebp),%eax
f01007ce:	89 44 24 10          	mov    %eax,0x10(%esp)
f01007d2:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01007d5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01007d9:	89 74 24 08          	mov    %esi,0x8(%esp)
f01007dd:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01007e1:	c7 04 24 2c 44 10 f0 	movl   $0xf010442c,(%esp)
f01007e8:	e8 18 27 00 00       	call   f0102f05 <cprintf>
	uint32_t eip;
	uint32_t ebp = read_ebp();
	uint32_t esp;
	uint32_t args[5];
	uint32_t i = 0;
	while(ebp!=-1){
f01007ed:	83 fb ff             	cmp    $0xffffffff,%ebx
f01007f0:	74 04                	je     f01007f6 <mon_backtrace+0x8c>
f01007f2:	89 d9                	mov    %ebx,%ecx
f01007f4:	eb 9d                	jmp    f0100793 <mon_backtrace+0x29>
                            cprintf("ebp  %08x   eip %08x   args  %08x  %08x  %08x  %08x  %08x\n",ebp,eip,args[0],args[1],args[2],args[3],args[4]);

	}
	
	return 0;
}
f01007f6:	b8 00 00 00 00       	mov    $0x0,%eax
f01007fb:	83 c4 40             	add    $0x40,%esp
f01007fe:	5b                   	pop    %ebx
f01007ff:	5e                   	pop    %esi
f0100800:	5d                   	pop    %ebp
f0100801:	c3                   	ret    

f0100802 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f0100802:	55                   	push   %ebp
f0100803:	89 e5                	mov    %esp,%ebp
f0100805:	57                   	push   %edi
f0100806:	56                   	push   %esi
f0100807:	53                   	push   %ebx
f0100808:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f010080b:	c7 04 24 68 44 10 f0 	movl   $0xf0104468,(%esp)
f0100812:	e8 ee 26 00 00       	call   f0102f05 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f0100817:	c7 04 24 8c 44 10 f0 	movl   $0xf010448c,(%esp)
f010081e:	e8 e2 26 00 00       	call   f0102f05 <cprintf>


	while (1) {
		buf = readline("K> ");
f0100823:	c7 04 24 a2 42 10 f0 	movl   $0xf01042a2,(%esp)
f010082a:	e8 c1 2f 00 00       	call   f01037f0 <readline>
f010082f:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f0100831:	85 c0                	test   %eax,%eax
f0100833:	74 ee                	je     f0100823 <monitor+0x21>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f0100835:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f010083c:	be 00 00 00 00       	mov    $0x0,%esi
f0100841:	eb 0a                	jmp    f010084d <monitor+0x4b>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f0100843:	c6 03 00             	movb   $0x0,(%ebx)
f0100846:	89 f7                	mov    %esi,%edi
f0100848:	8d 5b 01             	lea    0x1(%ebx),%ebx
f010084b:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f010084d:	0f b6 03             	movzbl (%ebx),%eax
f0100850:	84 c0                	test   %al,%al
f0100852:	74 6a                	je     f01008be <monitor+0xbc>
f0100854:	0f be c0             	movsbl %al,%eax
f0100857:	89 44 24 04          	mov    %eax,0x4(%esp)
f010085b:	c7 04 24 a6 42 10 f0 	movl   $0xf01042a6,(%esp)
f0100862:	e8 d7 31 00 00       	call   f0103a3e <strchr>
f0100867:	85 c0                	test   %eax,%eax
f0100869:	75 d8                	jne    f0100843 <monitor+0x41>
			*buf++ = 0;
		if (*buf == 0)
f010086b:	80 3b 00             	cmpb   $0x0,(%ebx)
f010086e:	74 4e                	je     f01008be <monitor+0xbc>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f0100870:	83 fe 0f             	cmp    $0xf,%esi
f0100873:	75 16                	jne    f010088b <monitor+0x89>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f0100875:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f010087c:	00 
f010087d:	c7 04 24 ab 42 10 f0 	movl   $0xf01042ab,(%esp)
f0100884:	e8 7c 26 00 00       	call   f0102f05 <cprintf>
f0100889:	eb 98                	jmp    f0100823 <monitor+0x21>
			return 0;
		}
		argv[argc++] = buf;
f010088b:	8d 7e 01             	lea    0x1(%esi),%edi
f010088e:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f0100892:	0f b6 03             	movzbl (%ebx),%eax
f0100895:	84 c0                	test   %al,%al
f0100897:	75 0c                	jne    f01008a5 <monitor+0xa3>
f0100899:	eb b0                	jmp    f010084b <monitor+0x49>
			buf++;
f010089b:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f010089e:	0f b6 03             	movzbl (%ebx),%eax
f01008a1:	84 c0                	test   %al,%al
f01008a3:	74 a6                	je     f010084b <monitor+0x49>
f01008a5:	0f be c0             	movsbl %al,%eax
f01008a8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01008ac:	c7 04 24 a6 42 10 f0 	movl   $0xf01042a6,(%esp)
f01008b3:	e8 86 31 00 00       	call   f0103a3e <strchr>
f01008b8:	85 c0                	test   %eax,%eax
f01008ba:	74 df                	je     f010089b <monitor+0x99>
f01008bc:	eb 8d                	jmp    f010084b <monitor+0x49>
			buf++;
	}
	argv[argc] = 0;
f01008be:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f01008c5:	00 

	// Lookup and invoke the command
	if (argc == 0)
f01008c6:	85 f6                	test   %esi,%esi
f01008c8:	0f 84 55 ff ff ff    	je     f0100823 <monitor+0x21>
f01008ce:	bb 00 00 00 00       	mov    $0x0,%ebx
f01008d3:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f01008d6:	8b 04 85 c0 44 10 f0 	mov    -0xfefbb40(,%eax,4),%eax
f01008dd:	89 44 24 04          	mov    %eax,0x4(%esp)
f01008e1:	8b 45 a8             	mov    -0x58(%ebp),%eax
f01008e4:	89 04 24             	mov    %eax,(%esp)
f01008e7:	e8 ce 30 00 00       	call   f01039ba <strcmp>
f01008ec:	85 c0                	test   %eax,%eax
f01008ee:	75 24                	jne    f0100914 <monitor+0x112>
			return commands[i].func(argc, argv, tf);
f01008f0:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f01008f3:	8b 55 08             	mov    0x8(%ebp),%edx
f01008f6:	89 54 24 08          	mov    %edx,0x8(%esp)
f01008fa:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f01008fd:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100901:	89 34 24             	mov    %esi,(%esp)
f0100904:	ff 14 85 c8 44 10 f0 	call   *-0xfefbb38(,%eax,4)


	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f010090b:	85 c0                	test   %eax,%eax
f010090d:	78 25                	js     f0100934 <monitor+0x132>
f010090f:	e9 0f ff ff ff       	jmp    f0100823 <monitor+0x21>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
f0100914:	83 c3 01             	add    $0x1,%ebx
f0100917:	83 fb 03             	cmp    $0x3,%ebx
f010091a:	75 b7                	jne    f01008d3 <monitor+0xd1>
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f010091c:	8b 45 a8             	mov    -0x58(%ebp),%eax
f010091f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100923:	c7 04 24 c8 42 10 f0 	movl   $0xf01042c8,(%esp)
f010092a:	e8 d6 25 00 00       	call   f0102f05 <cprintf>
f010092f:	e9 ef fe ff ff       	jmp    f0100823 <monitor+0x21>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f0100934:	83 c4 5c             	add    $0x5c,%esp
f0100937:	5b                   	pop    %ebx
f0100938:	5e                   	pop    %esi
f0100939:	5f                   	pop    %edi
f010093a:	5d                   	pop    %ebp
f010093b:	c3                   	ret    

f010093c <read_eip>:
// return EIP of caller.
// does not work if inlined.
// putting at the end of the file seems to prevent inlining.
unsigned
read_eip()
{
f010093c:	55                   	push   %ebp
f010093d:	89 e5                	mov    %esp,%ebp
	uint32_t callerpc;
	__asm __volatile("movl 4(%%ebp), %0" : "=r" (callerpc));
f010093f:	8b 45 04             	mov    0x4(%ebp),%eax
	return callerpc;
}
f0100942:	5d                   	pop    %ebp
f0100943:	c3                   	ret    
f0100944:	66 90                	xchg   %ax,%ax
f0100946:	66 90                	xchg   %ax,%ax
f0100948:	66 90                	xchg   %ax,%ax
f010094a:	66 90                	xchg   %ax,%ax
f010094c:	66 90                	xchg   %ax,%ax
f010094e:	66 90                	xchg   %ax,%ax

f0100950 <boot_alloc>:
// If we're out of memory, boot_alloc should panic.
// This function may ONLY be used during initialization,
// before the page_free_list list has been set up.
static void *
boot_alloc(uint32_t n)
{
f0100950:	55                   	push   %ebp
f0100951:	89 e5                	mov    %esp,%ebp
f0100953:	53                   	push   %ebx
f0100954:	83 ec 14             	sub    $0x14,%esp
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f0100957:	83 3d 58 75 11 f0 00 	cmpl   $0x0,0xf0117558
f010095e:	75 36                	jne    f0100996 <boot_alloc+0x46>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100960:	ba 8b 89 11 f0       	mov    $0xf011898b,%edx
f0100965:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f010096b:	89 15 58 75 11 f0    	mov    %edx,0xf0117558
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f0100971:	85 c0                	test   %eax,%eax
f0100973:	74 19                	je     f010098e <boot_alloc+0x3e>
                      result = nextfree;
f0100975:	8b 1d 58 75 11 f0    	mov    0xf0117558,%ebx
                      nextfree += ROUNDUP(n, PGSIZE);
f010097b:	05 ff 0f 00 00       	add    $0xfff,%eax
f0100980:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100985:	01 d8                	add    %ebx,%eax
f0100987:	a3 58 75 11 f0       	mov    %eax,0xf0117558
f010098c:	eb 0e                	jmp    f010099c <boot_alloc+0x4c>
               } else if (n == 0)
                      result = nextfree;
f010098e:	8b 1d 58 75 11 f0    	mov    0xf0117558,%ebx
f0100994:	eb 06                	jmp    f010099c <boot_alloc+0x4c>
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f0100996:	85 c0                	test   %eax,%eax
f0100998:	74 f4                	je     f010098e <boot_alloc+0x3e>
f010099a:	eb d9                	jmp    f0100975 <boot_alloc+0x25>
                      nextfree += ROUNDUP(n, PGSIZE);
               } else if (n == 0)
                      result = nextfree;
              else
                      result = NULL;
              cprintf(">>  boot_alloc() was called! Entry(virtual address) of new page is: %x\n\n", (int)result);
f010099c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01009a0:	c7 04 24 e4 44 10 f0 	movl   $0xf01044e4,(%esp)
f01009a7:	e8 59 25 00 00       	call   f0102f05 <cprintf>
              return result;
   
	//return NULL;
}
f01009ac:	89 d8                	mov    %ebx,%eax
f01009ae:	83 c4 14             	add    $0x14,%esp
f01009b1:	5b                   	pop    %ebx
f01009b2:	5d                   	pop    %ebp
f01009b3:	c3                   	ret    

f01009b4 <check_va2pa>:
static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
f01009b4:	89 d1                	mov    %edx,%ecx
f01009b6:	c1 e9 16             	shr    $0x16,%ecx
	if (!(*pgdir & PTE_P))
f01009b9:	8b 04 88             	mov    (%eax,%ecx,4),%eax
f01009bc:	a8 01                	test   $0x1,%al
f01009be:	74 5d                	je     f0100a1d <check_va2pa+0x69>
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
f01009c0:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01009c5:	89 c1                	mov    %eax,%ecx
f01009c7:	c1 e9 0c             	shr    $0xc,%ecx
f01009ca:	3b 0d 80 79 11 f0    	cmp    0xf0117980,%ecx
f01009d0:	72 26                	jb     f01009f8 <check_va2pa+0x44>
// this functionality for us!  We define our own version to help check
// the check_kern_pgdir() function; it shouldn't be used elsewhere.

static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
f01009d2:	55                   	push   %ebp
f01009d3:	89 e5                	mov    %esp,%ebp
f01009d5:	83 ec 18             	sub    $0x18,%esp
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01009d8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01009dc:	c7 44 24 08 30 45 10 	movl   $0xf0104530,0x8(%esp)
f01009e3:	f0 
f01009e4:	c7 44 24 04 e2 02 00 	movl   $0x2e2,0x4(%esp)
f01009eb:	00 
f01009ec:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01009f3:	e8 9c f6 ff ff       	call   f0100094 <_panic>

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
f01009f8:	c1 ea 0c             	shr    $0xc,%edx
f01009fb:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f0100a01:	8b 84 90 00 00 00 f0 	mov    -0x10000000(%eax,%edx,4),%eax
f0100a08:	89 c2                	mov    %eax,%edx
f0100a0a:	83 e2 01             	and    $0x1,%edx
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
f0100a0d:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100a12:	85 d2                	test   %edx,%edx
f0100a14:	ba ff ff ff ff       	mov    $0xffffffff,%edx
f0100a19:	0f 44 c2             	cmove  %edx,%eax
f0100a1c:	c3                   	ret    
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
f0100a1d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
}
f0100a22:	c3                   	ret    

f0100a23 <check_page_free_list>:
//
// Check that the pages on the page_free_list are reasonable.
//
static void
check_page_free_list(bool only_low_memory)
{
f0100a23:	55                   	push   %ebp
f0100a24:	89 e5                	mov    %esp,%ebp
f0100a26:	57                   	push   %edi
f0100a27:	56                   	push   %esi
f0100a28:	53                   	push   %ebx
f0100a29:	83 ec 3c             	sub    $0x3c,%esp
	struct Page *pp;
	int pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100a2c:	85 c0                	test   %eax,%eax
f0100a2e:	0f 85 35 03 00 00    	jne    f0100d69 <check_page_free_list+0x346>
f0100a34:	e9 42 03 00 00       	jmp    f0100d7b <check_page_free_list+0x358>
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
		panic("'page_free_list' is a null pointer!");
f0100a39:	c7 44 24 08 54 45 10 	movl   $0xf0104554,0x8(%esp)
f0100a40:	f0 
f0100a41:	c7 44 24 04 25 02 00 	movl   $0x225,0x4(%esp)
f0100a48:	00 
f0100a49:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0100a50:	e8 3f f6 ff ff       	call   f0100094 <_panic>

	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
f0100a55:	8d 55 d8             	lea    -0x28(%ebp),%edx
f0100a58:	89 55 e0             	mov    %edx,-0x20(%ebp)
f0100a5b:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100a5e:	89 55 e4             	mov    %edx,-0x1c(%ebp)
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100a61:	89 c2                	mov    %eax,%edx
f0100a63:	2b 15 88 79 11 f0    	sub    0xf0117988,%edx
		for (pp = page_free_list; pp; pp = pp->pp_link) {
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
f0100a69:	f7 c2 00 e0 7f 00    	test   $0x7fe000,%edx
f0100a6f:	0f 95 c2             	setne  %dl
f0100a72:	0f b6 d2             	movzbl %dl,%edx
			*tp[pagetype] = pp;
f0100a75:	8b 4c 95 e0          	mov    -0x20(%ebp,%edx,4),%ecx
f0100a79:	89 01                	mov    %eax,(%ecx)
			tp[pagetype] = &pp->pp_link;
f0100a7b:	89 44 95 e0          	mov    %eax,-0x20(%ebp,%edx,4)
	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
		for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100a7f:	8b 00                	mov    (%eax),%eax
f0100a81:	85 c0                	test   %eax,%eax
f0100a83:	75 dc                	jne    f0100a61 <check_page_free_list+0x3e>
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
			*tp[pagetype] = pp;
			tp[pagetype] = &pp->pp_link;
		}
		*tp[1] = 0;
f0100a85:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100a88:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		*tp[0] = pp2;
f0100a8e:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100a91:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100a94:	89 10                	mov    %edx,(%eax)
		page_free_list = pp1;
f0100a96:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100a99:	a3 5c 75 11 f0       	mov    %eax,0xf011755c
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100a9e:	89 c3                	mov    %eax,%ebx
f0100aa0:	85 c0                	test   %eax,%eax
f0100aa2:	74 6c                	je     f0100b10 <check_page_free_list+0xed>
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	int pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100aa4:	be 01 00 00 00       	mov    $0x1,%esi
f0100aa9:	89 d8                	mov    %ebx,%eax
f0100aab:	2b 05 88 79 11 f0    	sub    0xf0117988,%eax
f0100ab1:	c1 f8 03             	sar    $0x3,%eax
f0100ab4:	c1 e0 0c             	shl    $0xc,%eax
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
f0100ab7:	89 c2                	mov    %eax,%edx
f0100ab9:	c1 ea 16             	shr    $0x16,%edx
f0100abc:	39 f2                	cmp    %esi,%edx
f0100abe:	73 4a                	jae    f0100b0a <check_page_free_list+0xe7>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100ac0:	89 c2                	mov    %eax,%edx
f0100ac2:	c1 ea 0c             	shr    $0xc,%edx
f0100ac5:	3b 15 80 79 11 f0    	cmp    0xf0117980,%edx
f0100acb:	72 20                	jb     f0100aed <check_page_free_list+0xca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100acd:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100ad1:	c7 44 24 08 30 45 10 	movl   $0xf0104530,0x8(%esp)
f0100ad8:	f0 
f0100ad9:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f0100ae0:	00 
f0100ae1:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f0100ae8:	e8 a7 f5 ff ff       	call   f0100094 <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100aed:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100af4:	00 
f0100af5:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100afc:	00 
	return (void *)(pa + KERNBASE);
f0100afd:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100b02:	89 04 24             	mov    %eax,(%esp)
f0100b05:	e8 95 2f 00 00       	call   f0103a9f <memset>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100b0a:	8b 1b                	mov    (%ebx),%ebx
f0100b0c:	85 db                	test   %ebx,%ebx
f0100b0e:	75 99                	jne    f0100aa9 <check_page_free_list+0x86>
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
f0100b10:	b8 00 00 00 00       	mov    $0x0,%eax
f0100b15:	e8 36 fe ff ff       	call   f0100950 <boot_alloc>
f0100b1a:	89 45 cc             	mov    %eax,-0x34(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100b1d:	8b 15 5c 75 11 f0    	mov    0xf011755c,%edx
f0100b23:	85 d2                	test   %edx,%edx
f0100b25:	0f 84 f2 01 00 00    	je     f0100d1d <check_page_free_list+0x2fa>
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100b2b:	8b 1d 88 79 11 f0    	mov    0xf0117988,%ebx
f0100b31:	39 da                	cmp    %ebx,%edx
f0100b33:	72 3f                	jb     f0100b74 <check_page_free_list+0x151>
		assert(pp < pages + npages);
f0100b35:	a1 80 79 11 f0       	mov    0xf0117980,%eax
f0100b3a:	89 45 c8             	mov    %eax,-0x38(%ebp)
f0100b3d:	8d 04 c3             	lea    (%ebx,%eax,8),%eax
f0100b40:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100b43:	39 c2                	cmp    %eax,%edx
f0100b45:	73 56                	jae    f0100b9d <check_page_free_list+0x17a>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100b47:	89 5d d0             	mov    %ebx,-0x30(%ebp)
f0100b4a:	89 d0                	mov    %edx,%eax
f0100b4c:	29 d8                	sub    %ebx,%eax
f0100b4e:	a8 07                	test   $0x7,%al
f0100b50:	75 78                	jne    f0100bca <check_page_free_list+0x1a7>
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100b52:	c1 f8 03             	sar    $0x3,%eax
f0100b55:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100b58:	85 c0                	test   %eax,%eax
f0100b5a:	0f 84 98 00 00 00    	je     f0100bf8 <check_page_free_list+0x1d5>
		assert(page2pa(pp) != IOPHYSMEM);
f0100b60:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100b65:	0f 85 dc 00 00 00    	jne    f0100c47 <check_page_free_list+0x224>
f0100b6b:	e9 b3 00 00 00       	jmp    f0100c23 <check_page_free_list+0x200>
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100b70:	39 d3                	cmp    %edx,%ebx
f0100b72:	76 24                	jbe    f0100b98 <check_page_free_list+0x175>
f0100b74:	c7 44 24 0c 32 4c 10 	movl   $0xf0104c32,0xc(%esp)
f0100b7b:	f0 
f0100b7c:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0100b83:	f0 
f0100b84:	c7 44 24 04 3f 02 00 	movl   $0x23f,0x4(%esp)
f0100b8b:	00 
f0100b8c:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0100b93:	e8 fc f4 ff ff       	call   f0100094 <_panic>
		assert(pp < pages + npages);
f0100b98:	3b 55 d4             	cmp    -0x2c(%ebp),%edx
f0100b9b:	72 24                	jb     f0100bc1 <check_page_free_list+0x19e>
f0100b9d:	c7 44 24 0c 53 4c 10 	movl   $0xf0104c53,0xc(%esp)
f0100ba4:	f0 
f0100ba5:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0100bac:	f0 
f0100bad:	c7 44 24 04 40 02 00 	movl   $0x240,0x4(%esp)
f0100bb4:	00 
f0100bb5:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0100bbc:	e8 d3 f4 ff ff       	call   f0100094 <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100bc1:	89 d0                	mov    %edx,%eax
f0100bc3:	2b 45 d0             	sub    -0x30(%ebp),%eax
f0100bc6:	a8 07                	test   $0x7,%al
f0100bc8:	74 24                	je     f0100bee <check_page_free_list+0x1cb>
f0100bca:	c7 44 24 0c 78 45 10 	movl   $0xf0104578,0xc(%esp)
f0100bd1:	f0 
f0100bd2:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0100bd9:	f0 
f0100bda:	c7 44 24 04 41 02 00 	movl   $0x241,0x4(%esp)
f0100be1:	00 
f0100be2:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0100be9:	e8 a6 f4 ff ff       	call   f0100094 <_panic>
f0100bee:	c1 f8 03             	sar    $0x3,%eax
f0100bf1:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100bf4:	85 c0                	test   %eax,%eax
f0100bf6:	75 24                	jne    f0100c1c <check_page_free_list+0x1f9>
f0100bf8:	c7 44 24 0c 67 4c 10 	movl   $0xf0104c67,0xc(%esp)
f0100bff:	f0 
f0100c00:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0100c07:	f0 
f0100c08:	c7 44 24 04 44 02 00 	movl   $0x244,0x4(%esp)
f0100c0f:	00 
f0100c10:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0100c17:	e8 78 f4 ff ff       	call   f0100094 <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100c1c:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100c21:	75 2e                	jne    f0100c51 <check_page_free_list+0x22e>
f0100c23:	c7 44 24 0c 78 4c 10 	movl   $0xf0104c78,0xc(%esp)
f0100c2a:	f0 
f0100c2b:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0100c32:	f0 
f0100c33:	c7 44 24 04 45 02 00 	movl   $0x245,0x4(%esp)
f0100c3a:	00 
f0100c3b:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0100c42:	e8 4d f4 ff ff       	call   f0100094 <_panic>
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	int pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
f0100c47:	be 00 00 00 00       	mov    $0x0,%esi
f0100c4c:	bf 00 00 00 00       	mov    $0x0,%edi
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
f0100c51:	3d 00 f0 0f 00       	cmp    $0xff000,%eax
f0100c56:	75 24                	jne    f0100c7c <check_page_free_list+0x259>
f0100c58:	c7 44 24 0c ac 45 10 	movl   $0xf01045ac,0xc(%esp)
f0100c5f:	f0 
f0100c60:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0100c67:	f0 
f0100c68:	c7 44 24 04 46 02 00 	movl   $0x246,0x4(%esp)
f0100c6f:	00 
f0100c70:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0100c77:	e8 18 f4 ff ff       	call   f0100094 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100c7c:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100c81:	75 24                	jne    f0100ca7 <check_page_free_list+0x284>
f0100c83:	c7 44 24 0c 91 4c 10 	movl   $0xf0104c91,0xc(%esp)
f0100c8a:	f0 
f0100c8b:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0100c92:	f0 
f0100c93:	c7 44 24 04 47 02 00 	movl   $0x247,0x4(%esp)
f0100c9a:	00 
f0100c9b:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0100ca2:	e8 ed f3 ff ff       	call   f0100094 <_panic>
f0100ca7:	89 c1                	mov    %eax,%ecx
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
f0100ca9:	3d ff ff 0f 00       	cmp    $0xfffff,%eax
f0100cae:	76 57                	jbe    f0100d07 <check_page_free_list+0x2e4>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100cb0:	c1 e8 0c             	shr    $0xc,%eax
f0100cb3:	39 45 c8             	cmp    %eax,-0x38(%ebp)
f0100cb6:	77 20                	ja     f0100cd8 <check_page_free_list+0x2b5>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100cb8:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0100cbc:	c7 44 24 08 30 45 10 	movl   $0xf0104530,0x8(%esp)
f0100cc3:	f0 
f0100cc4:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f0100ccb:	00 
f0100ccc:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f0100cd3:	e8 bc f3 ff ff       	call   f0100094 <_panic>
	return (void *)(pa + KERNBASE);
f0100cd8:	81 e9 00 00 00 10    	sub    $0x10000000,%ecx
f0100cde:	39 4d cc             	cmp    %ecx,-0x34(%ebp)
f0100ce1:	76 29                	jbe    f0100d0c <check_page_free_list+0x2e9>
f0100ce3:	c7 44 24 0c d0 45 10 	movl   $0xf01045d0,0xc(%esp)
f0100cea:	f0 
f0100ceb:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0100cf2:	f0 
f0100cf3:	c7 44 24 04 48 02 00 	movl   $0x248,0x4(%esp)
f0100cfa:	00 
f0100cfb:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0100d02:	e8 8d f3 ff ff       	call   f0100094 <_panic>

		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
f0100d07:	83 c7 01             	add    $0x1,%edi
f0100d0a:	eb 03                	jmp    f0100d0f <check_page_free_list+0x2ec>
		else
			++nfree_extmem;
f0100d0c:	83 c6 01             	add    $0x1,%esi
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100d0f:	8b 12                	mov    (%edx),%edx
f0100d11:	85 d2                	test   %edx,%edx
f0100d13:	0f 85 57 fe ff ff    	jne    f0100b70 <check_page_free_list+0x14d>
			++nfree_basemem;
		else
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
f0100d19:	85 ff                	test   %edi,%edi
f0100d1b:	7f 24                	jg     f0100d41 <check_page_free_list+0x31e>
f0100d1d:	c7 44 24 0c ab 4c 10 	movl   $0xf0104cab,0xc(%esp)
f0100d24:	f0 
f0100d25:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0100d2c:	f0 
f0100d2d:	c7 44 24 04 50 02 00 	movl   $0x250,0x4(%esp)
f0100d34:	00 
f0100d35:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0100d3c:	e8 53 f3 ff ff       	call   f0100094 <_panic>
	assert(nfree_extmem > 0);
f0100d41:	85 f6                	test   %esi,%esi
f0100d43:	7f 53                	jg     f0100d98 <check_page_free_list+0x375>
f0100d45:	c7 44 24 0c bd 4c 10 	movl   $0xf0104cbd,0xc(%esp)
f0100d4c:	f0 
f0100d4d:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0100d54:	f0 
f0100d55:	c7 44 24 04 51 02 00 	movl   $0x251,0x4(%esp)
f0100d5c:	00 
f0100d5d:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0100d64:	e8 2b f3 ff ff       	call   f0100094 <_panic>
	struct Page *pp;
	int pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100d69:	a1 5c 75 11 f0       	mov    0xf011755c,%eax
f0100d6e:	85 c0                	test   %eax,%eax
f0100d70:	0f 85 df fc ff ff    	jne    f0100a55 <check_page_free_list+0x32>
f0100d76:	e9 be fc ff ff       	jmp    f0100a39 <check_page_free_list+0x16>
f0100d7b:	83 3d 5c 75 11 f0 00 	cmpl   $0x0,0xf011755c
f0100d82:	0f 84 b1 fc ff ff    	je     f0100a39 <check_page_free_list+0x16>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100d88:	8b 1d 5c 75 11 f0    	mov    0xf011755c,%ebx
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	int pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100d8e:	be 00 04 00 00       	mov    $0x400,%esi
f0100d93:	e9 11 fd ff ff       	jmp    f0100aa9 <check_page_free_list+0x86>
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
	assert(nfree_extmem > 0);
}
f0100d98:	83 c4 3c             	add    $0x3c,%esp
f0100d9b:	5b                   	pop    %ebx
f0100d9c:	5e                   	pop    %esi
f0100d9d:	5f                   	pop    %edi
f0100d9e:	5d                   	pop    %ebp
f0100d9f:	c3                   	ret    

f0100da0 <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0100da0:	55                   	push   %ebp
f0100da1:	89 e5                	mov    %esp,%ebp
f0100da3:	53                   	push   %ebx
f0100da4:	83 ec 14             	sub    $0x14,%esp
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100da7:	83 3d 80 79 11 f0 00 	cmpl   $0x0,0xf0117980
f0100dae:	0f 84 a5 00 00 00    	je     f0100e59 <page_init+0xb9>
f0100db4:	8b 1d 5c 75 11 f0    	mov    0xf011755c,%ebx
f0100dba:	b8 00 00 00 00       	mov    $0x0,%eax
f0100dbf:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
		pages[i].pp_ref = 0;
f0100dc6:	89 d1                	mov    %edx,%ecx
f0100dc8:	03 0d 88 79 11 f0    	add    0xf0117988,%ecx
f0100dce:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0100dd4:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f0100dd6:	03 15 88 79 11 f0    	add    0xf0117988,%edx
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100ddc:	83 c0 01             	add    $0x1,%eax
f0100ddf:	8b 0d 80 79 11 f0    	mov    0xf0117980,%ecx
f0100de5:	39 c1                	cmp    %eax,%ecx
f0100de7:	76 04                	jbe    f0100ded <page_init+0x4d>
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f0100de9:	89 d3                	mov    %edx,%ebx
f0100deb:	eb d2                	jmp    f0100dbf <page_init+0x1f>
f0100ded:	89 15 5c 75 11 f0    	mov    %edx,0xf011755c
	}

	//remove physical page 0 from page_free_list
             pages[1].pp_link = NULL;
f0100df3:	a1 88 79 11 f0       	mov    0xf0117988,%eax
f0100df8:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100dff:	81 f9 a0 00 00 00    	cmp    $0xa0,%ecx
f0100e05:	77 1c                	ja     f0100e23 <page_init+0x83>
		panic("pa2page called with invalid pa");
f0100e07:	c7 44 24 08 18 46 10 	movl   $0xf0104618,0x8(%esp)
f0100e0e:	f0 
f0100e0f:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
f0100e16:	00 
f0100e17:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f0100e1e:	e8 71 f2 ff ff       	call   f0100094 <_panic>

              //remove continuous pages from page_free_list
              extern char end[];                        //this is an *virtual* address
              struct Page *ppg_start = pa2page((physaddr_t)IOPHYSMEM);                                                //at low *physical* address
              struct Page *ppg_end = pa2page((physaddr_t)((end - KERNBASE) + PGSIZE + sizeof(struct Page)*npages));    //at high *physical* address
f0100e23:	8d 14 cd 8c 89 11 00 	lea    0x11898c(,%ecx,8),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100e2a:	c1 ea 0c             	shr    $0xc,%edx
f0100e2d:	39 d1                	cmp    %edx,%ecx
f0100e2f:	77 1c                	ja     f0100e4d <page_init+0xad>
		panic("pa2page called with invalid pa");
f0100e31:	c7 44 24 08 18 46 10 	movl   $0xf0104618,0x8(%esp)
f0100e38:	f0 
f0100e39:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
f0100e40:	00 
f0100e41:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f0100e48:	e8 47 f2 ff ff       	call   f0100094 <_panic>

              //test output
             //cprintf(">>  ppg_start: %x\tppg_end: %x\n", (int)ppg_start, (int)ppg_end);

               ppg_start--;    ppg_end++;
f0100e4d:	8d 88 f8 04 00 00    	lea    0x4f8(%eax),%ecx
f0100e53:	89 4c d0 08          	mov    %ecx,0x8(%eax,%edx,8)
f0100e57:	eb 0e                	jmp    f0100e67 <page_init+0xc7>
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
	}

	//remove physical page 0 from page_free_list
             pages[1].pp_link = NULL;
f0100e59:	a1 88 79 11 f0       	mov    0xf0117988,%eax
f0100e5e:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
f0100e65:	eb a0                	jmp    f0100e07 <page_init+0x67>
              //test output
             //cprintf(">>  ppg_start: %x\tppg_end: %x\n", (int)ppg_start, (int)ppg_end);

               ppg_start--;    ppg_end++;
               ppg_end->pp_link = ppg_start;
}
f0100e67:	83 c4 14             	add    $0x14,%esp
f0100e6a:	5b                   	pop    %ebx
f0100e6b:	5d                   	pop    %ebp
f0100e6c:	c3                   	ret    

f0100e6d <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
f0100e6d:	55                   	push   %ebp
f0100e6e:	89 e5                	mov    %esp,%ebp
f0100e70:	53                   	push   %ebx
f0100e71:	83 ec 14             	sub    $0x14,%esp
	//test output
              //cprintf(">>  page_alloc() was called!\n");

             if (page_free_list == NULL)
f0100e74:	8b 1d 5c 75 11 f0    	mov    0xf011755c,%ebx
f0100e7a:	85 db                	test   %ebx,%ebx
f0100e7c:	74 69                	je     f0100ee7 <page_alloc+0x7a>
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
f0100e7e:	8b 03                	mov    (%ebx),%eax
f0100e80:	a3 5c 75 11 f0       	mov    %eax,0xf011755c
    
             if (alloc_flags & ALLOC_ZERO)
                    memset(page2kva(result), 0, PGSIZE);
        
             return result;
f0100e85:	89 d8                	mov    %ebx,%eax
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
    
             if (alloc_flags & ALLOC_ZERO)
f0100e87:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f0100e8b:	74 5f                	je     f0100eec <page_alloc+0x7f>
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100e8d:	2b 05 88 79 11 f0    	sub    0xf0117988,%eax
f0100e93:	c1 f8 03             	sar    $0x3,%eax
f0100e96:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100e99:	89 c2                	mov    %eax,%edx
f0100e9b:	c1 ea 0c             	shr    $0xc,%edx
f0100e9e:	3b 15 80 79 11 f0    	cmp    0xf0117980,%edx
f0100ea4:	72 20                	jb     f0100ec6 <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100ea6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100eaa:	c7 44 24 08 30 45 10 	movl   $0xf0104530,0x8(%esp)
f0100eb1:	f0 
f0100eb2:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f0100eb9:	00 
f0100eba:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f0100ec1:	e8 ce f1 ff ff       	call   f0100094 <_panic>
                    memset(page2kva(result), 0, PGSIZE);
f0100ec6:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0100ecd:	00 
f0100ece:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0100ed5:	00 
	return (void *)(pa + KERNBASE);
f0100ed6:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100edb:	89 04 24             	mov    %eax,(%esp)
f0100ede:	e8 bc 2b 00 00       	call   f0103a9f <memset>
        
             return result;
f0100ee3:	89 d8                	mov    %ebx,%eax
f0100ee5:	eb 05                	jmp    f0100eec <page_alloc+0x7f>
{
	//test output
              //cprintf(">>  page_alloc() was called!\n");

             if (page_free_list == NULL)
                             return NULL;
f0100ee7:	b8 00 00 00 00       	mov    $0x0,%eax
    
             if (alloc_flags & ALLOC_ZERO)
                    memset(page2kva(result), 0, PGSIZE);
        
             return result;
}
f0100eec:	83 c4 14             	add    $0x14,%esp
f0100eef:	5b                   	pop    %ebx
f0100ef0:	5d                   	pop    %ebp
f0100ef1:	c3                   	ret    

f0100ef2 <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct Page *pp)
{
f0100ef2:	55                   	push   %ebp
f0100ef3:	89 e5                	mov    %esp,%ebp
f0100ef5:	8b 45 08             	mov    0x8(%ebp),%eax
	pp->pp_link = page_free_list;
f0100ef8:	8b 15 5c 75 11 f0    	mov    0xf011755c,%edx
f0100efe:	89 10                	mov    %edx,(%eax)
              page_free_list = pp;
f0100f00:	a3 5c 75 11 f0       	mov    %eax,0xf011755c
	// Fill this function in
}
f0100f05:	5d                   	pop    %ebp
f0100f06:	c3                   	ret    

f0100f07 <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct Page* pp)
{
f0100f07:	55                   	push   %ebp
f0100f08:	89 e5                	mov    %esp,%ebp
f0100f0a:	83 ec 04             	sub    $0x4,%esp
f0100f0d:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f0100f10:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f0100f14:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0100f17:	66 89 50 04          	mov    %dx,0x4(%eax)
f0100f1b:	66 85 d2             	test   %dx,%dx
f0100f1e:	75 08                	jne    f0100f28 <page_decref+0x21>
		page_free(pp);
f0100f20:	89 04 24             	mov    %eax,(%esp)
f0100f23:	e8 ca ff ff ff       	call   f0100ef2 <page_free>
}
f0100f28:	c9                   	leave  
f0100f29:	c3                   	ret    

f0100f2a <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f0100f2a:	55                   	push   %ebp
f0100f2b:	89 e5                	mov    %esp,%ebp
f0100f2d:	56                   	push   %esi
f0100f2e:	53                   	push   %ebx
f0100f2f:	83 ec 10             	sub    $0x10,%esp
f0100f32:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	// Fill this function in
	//test output
              //cprintf(">>  pgdir_walk() was called!\n");

             pte_t *result;
            if (pgdir[PDX(va)] == (pte_t)NULL) {            //yet to create
f0100f35:	89 de                	mov    %ebx,%esi
f0100f37:	c1 ee 16             	shr    $0x16,%esi
f0100f3a:	c1 e6 02             	shl    $0x2,%esi
f0100f3d:	03 75 08             	add    0x8(%ebp),%esi
f0100f40:	8b 06                	mov    (%esi),%eax
f0100f42:	85 c0                	test   %eax,%eax
f0100f44:	75 76                	jne    f0100fbc <pgdir_walk+0x92>
                      if (create == 0)
f0100f46:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f0100f4a:	0f 84 d1 00 00 00    	je     f0101021 <pgdir_walk+0xf7>
                                        return NULL;
                     else {
                                        struct Page *tmp = page_alloc(ALLOC_ZERO);
f0100f50:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0100f57:	e8 11 ff ff ff       	call   f0100e6d <page_alloc>
                                        if (tmp == NULL)
f0100f5c:	85 c0                	test   %eax,%eax
f0100f5e:	0f 84 c4 00 00 00    	je     f0101028 <pgdir_walk+0xfe>
                                                  return NULL;                        //failed to alloc
                                        else {
                                                  tmp->pp_ref++;
f0100f64:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100f69:	89 c2                	mov    %eax,%edx
f0100f6b:	2b 15 88 79 11 f0    	sub    0xf0117988,%edx
f0100f71:	c1 fa 03             	sar    $0x3,%edx
f0100f74:	c1 e2 0c             	shl    $0xc,%edx
                                                  pgdir[PDX(va)] = page2pa(tmp) | PTE_P | PTE_W |PTE_U;    //save the physical address of newly allocated page in page dir
f0100f77:	83 ca 07             	or     $0x7,%edx
f0100f7a:	89 16                	mov    %edx,(%esi)
f0100f7c:	2b 05 88 79 11 f0    	sub    0xf0117988,%eax
f0100f82:	c1 f8 03             	sar    $0x3,%eax
f0100f85:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100f88:	89 c2                	mov    %eax,%edx
f0100f8a:	c1 ea 0c             	shr    $0xc,%edx
f0100f8d:	3b 15 80 79 11 f0    	cmp    0xf0117980,%edx
f0100f93:	72 20                	jb     f0100fb5 <pgdir_walk+0x8b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100f95:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100f99:	c7 44 24 08 30 45 10 	movl   $0xf0104530,0x8(%esp)
f0100fa0:	f0 
f0100fa1:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f0100fa8:	00 
f0100fa9:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f0100fb0:	e8 df f0 ff ff       	call   f0100094 <_panic>
	return (void *)(pa + KERNBASE);
f0100fb5:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100fba:	eb 58                	jmp    f0101014 <pgdir_walk+0xea>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100fbc:	c1 e8 0c             	shr    $0xc,%eax
f0100fbf:	8b 15 80 79 11 f0    	mov    0xf0117980,%edx
f0100fc5:	39 d0                	cmp    %edx,%eax
f0100fc7:	72 1c                	jb     f0100fe5 <pgdir_walk+0xbb>
		panic("pa2page called with invalid pa");
f0100fc9:	c7 44 24 08 18 46 10 	movl   $0xf0104618,0x8(%esp)
f0100fd0:	f0 
f0100fd1:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
f0100fd8:	00 
f0100fd9:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f0100fe0:	e8 af f0 ff ff       	call   f0100094 <_panic>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100fe5:	89 c1                	mov    %eax,%ecx
f0100fe7:	c1 e1 0c             	shl    $0xc,%ecx
f0100fea:	39 d0                	cmp    %edx,%eax
f0100fec:	72 20                	jb     f010100e <pgdir_walk+0xe4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100fee:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0100ff2:	c7 44 24 08 30 45 10 	movl   $0xf0104530,0x8(%esp)
f0100ff9:	f0 
f0100ffa:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f0101001:	00 
f0101002:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f0101009:	e8 86 f0 ff ff       	call   f0100094 <_panic>
	return (void *)(pa + KERNBASE);
f010100e:	8d 81 00 00 00 f0    	lea    -0x10000000(%ecx),%eax
                                  }
                 }
               else                        
               result = page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
        
               return &result[PTX(va)];
f0101014:	c1 eb 0a             	shr    $0xa,%ebx
f0101017:	81 e3 fc 0f 00 00    	and    $0xffc,%ebx
f010101d:	01 d8                	add    %ebx,%eax
f010101f:	eb 0c                	jmp    f010102d <pgdir_walk+0x103>
              //cprintf(">>  pgdir_walk() was called!\n");

             pte_t *result;
            if (pgdir[PDX(va)] == (pte_t)NULL) {            //yet to create
                      if (create == 0)
                                        return NULL;
f0101021:	b8 00 00 00 00       	mov    $0x0,%eax
f0101026:	eb 05                	jmp    f010102d <pgdir_walk+0x103>
                     else {
                                        struct Page *tmp = page_alloc(ALLOC_ZERO);
                                        if (tmp == NULL)
                                                  return NULL;                        //failed to alloc
f0101028:	b8 00 00 00 00       	mov    $0x0,%eax
                 }
               else                        
               result = page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
        
               return &result[PTX(va)];
}
f010102d:	83 c4 10             	add    $0x10,%esp
f0101030:	5b                   	pop    %ebx
f0101031:	5e                   	pop    %esi
f0101032:	5d                   	pop    %ebp
f0101033:	c3                   	ret    

f0101034 <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f0101034:	55                   	push   %ebp
f0101035:	89 e5                	mov    %esp,%ebp
f0101037:	53                   	push   %ebx
f0101038:	83 ec 14             	sub    $0x14,%esp
f010103b:	8b 5d 10             	mov    0x10(%ebp),%ebx
	// Fill this function in
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
f010103e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101045:	00 
f0101046:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101049:	89 44 24 04          	mov    %eax,0x4(%esp)
f010104d:	8b 45 08             	mov    0x8(%ebp),%eax
f0101050:	89 04 24             	mov    %eax,(%esp)
f0101053:	e8 d2 fe ff ff       	call   f0100f2a <pgdir_walk>
              if (pte == NULL)
f0101058:	85 c0                	test   %eax,%eax
f010105a:	74 3a                	je     f0101096 <page_lookup+0x62>
                       return NULL;

             if (pte_store != 0)
f010105c:	85 db                	test   %ebx,%ebx
f010105e:	74 02                	je     f0101062 <page_lookup+0x2e>
                     *pte_store = pte;
f0101060:	89 03                	mov    %eax,(%ebx)

             return pa2page(PTE_ADDR(pte[0]));
f0101062:	8b 00                	mov    (%eax),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101064:	c1 e8 0c             	shr    $0xc,%eax
f0101067:	3b 05 80 79 11 f0    	cmp    0xf0117980,%eax
f010106d:	72 1c                	jb     f010108b <page_lookup+0x57>
		panic("pa2page called with invalid pa");
f010106f:	c7 44 24 08 18 46 10 	movl   $0xf0104618,0x8(%esp)
f0101076:	f0 
f0101077:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
f010107e:	00 
f010107f:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f0101086:	e8 09 f0 ff ff       	call   f0100094 <_panic>
	return &pages[PGNUM(pa)];
f010108b:	8b 15 88 79 11 f0    	mov    0xf0117988,%edx
f0101091:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0101094:	eb 05                	jmp    f010109b <page_lookup+0x67>
	//test output
              //cprintf(">>  page_lookup() was called!\n");
    
             pte_t *pte = pgdir_walk(pgdir, va, 0);
              if (pte == NULL)
                       return NULL;
f0101096:	b8 00 00 00 00       	mov    $0x0,%eax

             if (pte_store != 0)
                     *pte_store = pte;

             return pa2page(PTE_ADDR(pte[0]));
}
f010109b:	83 c4 14             	add    $0x14,%esp
f010109e:	5b                   	pop    %ebx
f010109f:	5d                   	pop    %ebp
f01010a0:	c3                   	ret    

f01010a1 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f01010a1:	55                   	push   %ebp
f01010a2:	89 e5                	mov    %esp,%ebp
f01010a4:	53                   	push   %ebx
f01010a5:	83 ec 24             	sub    $0x24,%esp
f01010a8:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	// Fill this function in
	//test output
               //cprintf(">>  page_remove() was called!\n");
    
              pte_t *pte;
              struct Page *page = page_lookup(pgdir, va, &pte);
f01010ab:	8d 45 f4             	lea    -0xc(%ebp),%eax
f01010ae:	89 44 24 08          	mov    %eax,0x8(%esp)
f01010b2:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01010b6:	8b 45 08             	mov    0x8(%ebp),%eax
f01010b9:	89 04 24             	mov    %eax,(%esp)
f01010bc:	e8 73 ff ff ff       	call   f0101034 <page_lookup>
    
              if (page != NULL)
f01010c1:	85 c0                	test   %eax,%eax
f01010c3:	74 08                	je     f01010cd <page_remove+0x2c>
                         page_decref(page);
f01010c5:	89 04 24             	mov    %eax,(%esp)
f01010c8:	e8 3a fe ff ff       	call   f0100f07 <page_decref>
        
              pte[0] = 0;
f01010cd:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01010d0:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f01010d6:	0f 01 3b             	invlpg (%ebx)
              tlb_invalidate(pgdir, va);
}
f01010d9:	83 c4 24             	add    $0x24,%esp
f01010dc:	5b                   	pop    %ebx
f01010dd:	5d                   	pop    %ebp
f01010de:	c3                   	ret    

f01010df <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
{
f01010df:	55                   	push   %ebp
f01010e0:	89 e5                	mov    %esp,%ebp
f01010e2:	57                   	push   %edi
f01010e3:	56                   	push   %esi
f01010e4:	53                   	push   %ebx
f01010e5:	83 ec 1c             	sub    $0x1c,%esp
f01010e8:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01010eb:	8b 75 10             	mov    0x10(%ebp),%esi
	// Fill this function in
	//test output
                                //cprintf(">>  page_insert() was called!\n");
    
               struct Page *page = page_lookup(pgdir, va, NULL);
f01010ee:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01010f5:	00 
f01010f6:	89 74 24 04          	mov    %esi,0x4(%esp)
f01010fa:	8b 45 08             	mov    0x8(%ebp),%eax
f01010fd:	89 04 24             	mov    %eax,(%esp)
f0101100:	e8 2f ff ff ff       	call   f0101034 <page_lookup>
f0101105:	89 c7                	mov    %eax,%edi
               pte_t *pte;
    
              if (page == pp) {                       //re-insert into the same place
f0101107:	39 d8                	cmp    %ebx,%eax
f0101109:	75 36                	jne    f0101141 <page_insert+0x62>
                            pte = pgdir_walk(pgdir, va, 0);
f010110b:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101112:	00 
f0101113:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101117:	8b 45 08             	mov    0x8(%ebp),%eax
f010111a:	89 04 24             	mov    %eax,(%esp)
f010111d:	e8 08 fe ff ff       	call   f0100f2a <pgdir_walk>
                            pte[0] = page2pa(pp) | perm | PTE_P;
f0101122:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0101125:	83 c9 01             	or     $0x1,%ecx
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101128:	2b 3d 88 79 11 f0    	sub    0xf0117988,%edi
f010112e:	c1 ff 03             	sar    $0x3,%edi
f0101131:	c1 e7 0c             	shl    $0xc,%edi
f0101134:	89 fa                	mov    %edi,%edx
f0101136:	09 ca                	or     %ecx,%edx
f0101138:	89 10                	mov    %edx,(%eax)
                            return 0;
f010113a:	b8 00 00 00 00       	mov    $0x0,%eax
f010113f:	eb 57                	jmp    f0101198 <page_insert+0xb9>
                          }
    
               if (page != NULL)                       //remove original page if existed
f0101141:	85 c0                	test   %eax,%eax
f0101143:	74 0f                	je     f0101154 <page_insert+0x75>
                        page_remove(pgdir, va);
f0101145:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101149:	8b 45 08             	mov    0x8(%ebp),%eax
f010114c:	89 04 24             	mov    %eax,(%esp)
f010114f:	e8 4d ff ff ff       	call   f01010a1 <page_remove>
        
              pte = pgdir_walk(pgdir, va, 1);
f0101154:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010115b:	00 
f010115c:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101160:	8b 45 08             	mov    0x8(%ebp),%eax
f0101163:	89 04 24             	mov    %eax,(%esp)
f0101166:	e8 bf fd ff ff       	call   f0100f2a <pgdir_walk>
              if (pte == NULL)
f010116b:	85 c0                	test   %eax,%eax
f010116d:	74 24                	je     f0101193 <page_insert+0xb4>
                       return -E_NO_MEM;

              pte[0] = page2pa(pp) | perm | PTE_P;
f010116f:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0101172:	83 c9 01             	or     $0x1,%ecx
f0101175:	89 da                	mov    %ebx,%edx
f0101177:	2b 15 88 79 11 f0    	sub    0xf0117988,%edx
f010117d:	c1 fa 03             	sar    $0x3,%edx
f0101180:	c1 e2 0c             	shl    $0xc,%edx
f0101183:	09 ca                	or     %ecx,%edx
f0101185:	89 10                	mov    %edx,(%eax)
               pp->pp_ref++;
f0101187:	66 83 43 04 01       	addw   $0x1,0x4(%ebx)

	return 0; 
f010118c:	b8 00 00 00 00       	mov    $0x0,%eax
f0101191:	eb 05                	jmp    f0101198 <page_insert+0xb9>
               if (page != NULL)                       //remove original page if existed
                        page_remove(pgdir, va);
        
              pte = pgdir_walk(pgdir, va, 1);
              if (pte == NULL)
                       return -E_NO_MEM;
f0101193:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax

              pte[0] = page2pa(pp) | perm | PTE_P;
               pp->pp_ref++;

	return 0; 
}
f0101198:	83 c4 1c             	add    $0x1c,%esp
f010119b:	5b                   	pop    %ebx
f010119c:	5e                   	pop    %esi
f010119d:	5f                   	pop    %edi
f010119e:	5d                   	pop    %ebp
f010119f:	c3                   	ret    

f01011a0 <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f01011a0:	55                   	push   %ebp
f01011a1:	89 e5                	mov    %esp,%ebp
f01011a3:	57                   	push   %edi
f01011a4:	56                   	push   %esi
f01011a5:	53                   	push   %ebx
f01011a6:	83 ec 3c             	sub    $0x3c,%esp
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01011a9:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f01011b0:	e8 e0 1c 00 00       	call   f0102e95 <mc146818_read>
f01011b5:	89 c3                	mov    %eax,%ebx
f01011b7:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f01011be:	e8 d2 1c 00 00       	call   f0102e95 <mc146818_read>
f01011c3:	c1 e0 08             	shl    $0x8,%eax
f01011c6:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f01011c8:	89 d8                	mov    %ebx,%eax
f01011ca:	c1 e0 0a             	shl    $0xa,%eax
f01011cd:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f01011d3:	85 c0                	test   %eax,%eax
f01011d5:	0f 48 c2             	cmovs  %edx,%eax
f01011d8:	c1 f8 0c             	sar    $0xc,%eax
f01011db:	a3 60 75 11 f0       	mov    %eax,0xf0117560
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01011e0:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f01011e7:	e8 a9 1c 00 00       	call   f0102e95 <mc146818_read>
f01011ec:	89 c3                	mov    %eax,%ebx
f01011ee:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f01011f5:	e8 9b 1c 00 00       	call   f0102e95 <mc146818_read>
f01011fa:	c1 e0 08             	shl    $0x8,%eax
f01011fd:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f01011ff:	89 d8                	mov    %ebx,%eax
f0101201:	c1 e0 0a             	shl    $0xa,%eax
f0101204:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f010120a:	85 c0                	test   %eax,%eax
f010120c:	0f 48 c2             	cmovs  %edx,%eax
f010120f:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f0101212:	85 c0                	test   %eax,%eax
f0101214:	74 0e                	je     f0101224 <mem_init+0x84>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f0101216:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f010121c:	89 15 80 79 11 f0    	mov    %edx,0xf0117980
f0101222:	eb 0c                	jmp    f0101230 <mem_init+0x90>
	else
		npages = npages_basemem;
f0101224:	8b 15 60 75 11 f0    	mov    0xf0117560,%edx
f010122a:	89 15 80 79 11 f0    	mov    %edx,0xf0117980

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f0101230:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101233:	c1 e8 0a             	shr    $0xa,%eax
f0101236:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f010123a:	a1 60 75 11 f0       	mov    0xf0117560,%eax
f010123f:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101242:	c1 e8 0a             	shr    $0xa,%eax
f0101245:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f0101249:	a1 80 79 11 f0       	mov    0xf0117980,%eax
f010124e:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101251:	c1 e8 0a             	shr    $0xa,%eax
f0101254:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101258:	c7 04 24 38 46 10 f0 	movl   $0xf0104638,(%esp)
f010125f:	e8 a1 1c 00 00       	call   f0102f05 <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);  // first_level pagedir
f0101264:	b8 00 10 00 00       	mov    $0x1000,%eax
f0101269:	e8 e2 f6 ff ff       	call   f0100950 <boot_alloc>
f010126e:	a3 84 79 11 f0       	mov    %eax,0xf0117984
	memset(kern_pgdir, 0, PGSIZE);
f0101273:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010127a:	00 
f010127b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101282:	00 
f0101283:	89 04 24             	mov    %eax,(%esp)
f0101286:	e8 14 28 00 00       	call   f0103a9f <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f010128b:	a1 84 79 11 f0       	mov    0xf0117984,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101290:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101295:	77 20                	ja     f01012b7 <mem_init+0x117>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101297:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010129b:	c7 44 24 08 74 46 10 	movl   $0xf0104674,0x8(%esp)
f01012a2:	f0 
f01012a3:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
f01012aa:	00 
f01012ab:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01012b2:	e8 dd ed ff ff       	call   f0100094 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01012b7:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f01012bd:	83 ca 05             	or     $0x5,%edx
f01012c0:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct Page in this
	// array.  'npages' is the number of physical pages in memory.
	// Your code goes here:

	pages = (struct Page *)boot_alloc(npages * sizeof(struct Page)); // allocate npages to record all physical pages in memort using condition
f01012c6:	a1 80 79 11 f0       	mov    0xf0117980,%eax
f01012cb:	c1 e0 03             	shl    $0x3,%eax
f01012ce:	e8 7d f6 ff ff       	call   f0100950 <boot_alloc>
f01012d3:	a3 88 79 11 f0       	mov    %eax,0xf0117988
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f01012d8:	e8 c3 fa ff ff       	call   f0100da0 <page_init>

	check_page_free_list(1);
f01012dd:	b8 01 00 00 00       	mov    $0x1,%eax
f01012e2:	e8 3c f7 ff ff       	call   f0100a23 <check_page_free_list>
	int nfree;
	struct Page *fl;
	char *c;
	int i;

	if (!pages)
f01012e7:	83 3d 88 79 11 f0 00 	cmpl   $0x0,0xf0117988
f01012ee:	75 1c                	jne    f010130c <mem_init+0x16c>
		panic("'pages' is a null pointer!");
f01012f0:	c7 44 24 08 ce 4c 10 	movl   $0xf0104cce,0x8(%esp)
f01012f7:	f0 
f01012f8:	c7 44 24 04 62 02 00 	movl   $0x262,0x4(%esp)
f01012ff:	00 
f0101300:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101307:	e8 88 ed ff ff       	call   f0100094 <_panic>

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010130c:	a1 5c 75 11 f0       	mov    0xf011755c,%eax
f0101311:	85 c0                	test   %eax,%eax
f0101313:	74 10                	je     f0101325 <mem_init+0x185>
f0101315:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;
f010131a:	83 c3 01             	add    $0x1,%ebx

	if (!pages)
		panic("'pages' is a null pointer!");

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010131d:	8b 00                	mov    (%eax),%eax
f010131f:	85 c0                	test   %eax,%eax
f0101321:	75 f7                	jne    f010131a <mem_init+0x17a>
f0101323:	eb 05                	jmp    f010132a <mem_init+0x18a>
f0101325:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f010132a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101331:	e8 37 fb ff ff       	call   f0100e6d <page_alloc>
f0101336:	89 c7                	mov    %eax,%edi
f0101338:	85 c0                	test   %eax,%eax
f010133a:	75 24                	jne    f0101360 <mem_init+0x1c0>
f010133c:	c7 44 24 0c e9 4c 10 	movl   $0xf0104ce9,0xc(%esp)
f0101343:	f0 
f0101344:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f010134b:	f0 
f010134c:	c7 44 24 04 6a 02 00 	movl   $0x26a,0x4(%esp)
f0101353:	00 
f0101354:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010135b:	e8 34 ed ff ff       	call   f0100094 <_panic>
	assert((pp1 = page_alloc(0)));
f0101360:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101367:	e8 01 fb ff ff       	call   f0100e6d <page_alloc>
f010136c:	89 c6                	mov    %eax,%esi
f010136e:	85 c0                	test   %eax,%eax
f0101370:	75 24                	jne    f0101396 <mem_init+0x1f6>
f0101372:	c7 44 24 0c ff 4c 10 	movl   $0xf0104cff,0xc(%esp)
f0101379:	f0 
f010137a:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101381:	f0 
f0101382:	c7 44 24 04 6b 02 00 	movl   $0x26b,0x4(%esp)
f0101389:	00 
f010138a:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101391:	e8 fe ec ff ff       	call   f0100094 <_panic>
	assert((pp2 = page_alloc(0)));
f0101396:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010139d:	e8 cb fa ff ff       	call   f0100e6d <page_alloc>
f01013a2:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01013a5:	85 c0                	test   %eax,%eax
f01013a7:	75 24                	jne    f01013cd <mem_init+0x22d>
f01013a9:	c7 44 24 0c 15 4d 10 	movl   $0xf0104d15,0xc(%esp)
f01013b0:	f0 
f01013b1:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01013b8:	f0 
f01013b9:	c7 44 24 04 6c 02 00 	movl   $0x26c,0x4(%esp)
f01013c0:	00 
f01013c1:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01013c8:	e8 c7 ec ff ff       	call   f0100094 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f01013cd:	39 f7                	cmp    %esi,%edi
f01013cf:	75 24                	jne    f01013f5 <mem_init+0x255>
f01013d1:	c7 44 24 0c 2b 4d 10 	movl   $0xf0104d2b,0xc(%esp)
f01013d8:	f0 
f01013d9:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01013e0:	f0 
f01013e1:	c7 44 24 04 6f 02 00 	movl   $0x26f,0x4(%esp)
f01013e8:	00 
f01013e9:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01013f0:	e8 9f ec ff ff       	call   f0100094 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f01013f5:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01013f8:	39 c6                	cmp    %eax,%esi
f01013fa:	74 04                	je     f0101400 <mem_init+0x260>
f01013fc:	39 c7                	cmp    %eax,%edi
f01013fe:	75 24                	jne    f0101424 <mem_init+0x284>
f0101400:	c7 44 24 0c 98 46 10 	movl   $0xf0104698,0xc(%esp)
f0101407:	f0 
f0101408:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f010140f:	f0 
f0101410:	c7 44 24 04 70 02 00 	movl   $0x270,0x4(%esp)
f0101417:	00 
f0101418:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010141f:	e8 70 ec ff ff       	call   f0100094 <_panic>
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101424:	8b 15 88 79 11 f0    	mov    0xf0117988,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f010142a:	a1 80 79 11 f0       	mov    0xf0117980,%eax
f010142f:	c1 e0 0c             	shl    $0xc,%eax
f0101432:	89 f9                	mov    %edi,%ecx
f0101434:	29 d1                	sub    %edx,%ecx
f0101436:	c1 f9 03             	sar    $0x3,%ecx
f0101439:	c1 e1 0c             	shl    $0xc,%ecx
f010143c:	39 c1                	cmp    %eax,%ecx
f010143e:	72 24                	jb     f0101464 <mem_init+0x2c4>
f0101440:	c7 44 24 0c 3d 4d 10 	movl   $0xf0104d3d,0xc(%esp)
f0101447:	f0 
f0101448:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f010144f:	f0 
f0101450:	c7 44 24 04 71 02 00 	movl   $0x271,0x4(%esp)
f0101457:	00 
f0101458:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010145f:	e8 30 ec ff ff       	call   f0100094 <_panic>
f0101464:	89 f1                	mov    %esi,%ecx
f0101466:	29 d1                	sub    %edx,%ecx
f0101468:	c1 f9 03             	sar    $0x3,%ecx
f010146b:	c1 e1 0c             	shl    $0xc,%ecx
	assert(page2pa(pp1) < npages*PGSIZE);
f010146e:	39 c8                	cmp    %ecx,%eax
f0101470:	77 24                	ja     f0101496 <mem_init+0x2f6>
f0101472:	c7 44 24 0c 5a 4d 10 	movl   $0xf0104d5a,0xc(%esp)
f0101479:	f0 
f010147a:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101481:	f0 
f0101482:	c7 44 24 04 72 02 00 	movl   $0x272,0x4(%esp)
f0101489:	00 
f010148a:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101491:	e8 fe eb ff ff       	call   f0100094 <_panic>
f0101496:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0101499:	29 d1                	sub    %edx,%ecx
f010149b:	89 ca                	mov    %ecx,%edx
f010149d:	c1 fa 03             	sar    $0x3,%edx
f01014a0:	c1 e2 0c             	shl    $0xc,%edx
	assert(page2pa(pp2) < npages*PGSIZE);
f01014a3:	39 d0                	cmp    %edx,%eax
f01014a5:	77 24                	ja     f01014cb <mem_init+0x32b>
f01014a7:	c7 44 24 0c 77 4d 10 	movl   $0xf0104d77,0xc(%esp)
f01014ae:	f0 
f01014af:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01014b6:	f0 
f01014b7:	c7 44 24 04 73 02 00 	movl   $0x273,0x4(%esp)
f01014be:	00 
f01014bf:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01014c6:	e8 c9 eb ff ff       	call   f0100094 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f01014cb:	a1 5c 75 11 f0       	mov    0xf011755c,%eax
f01014d0:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f01014d3:	c7 05 5c 75 11 f0 00 	movl   $0x0,0xf011755c
f01014da:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f01014dd:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01014e4:	e8 84 f9 ff ff       	call   f0100e6d <page_alloc>
f01014e9:	85 c0                	test   %eax,%eax
f01014eb:	74 24                	je     f0101511 <mem_init+0x371>
f01014ed:	c7 44 24 0c 94 4d 10 	movl   $0xf0104d94,0xc(%esp)
f01014f4:	f0 
f01014f5:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01014fc:	f0 
f01014fd:	c7 44 24 04 7a 02 00 	movl   $0x27a,0x4(%esp)
f0101504:	00 
f0101505:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010150c:	e8 83 eb ff ff       	call   f0100094 <_panic>

	// free and re-allocate?
	page_free(pp0);
f0101511:	89 3c 24             	mov    %edi,(%esp)
f0101514:	e8 d9 f9 ff ff       	call   f0100ef2 <page_free>
	page_free(pp1);
f0101519:	89 34 24             	mov    %esi,(%esp)
f010151c:	e8 d1 f9 ff ff       	call   f0100ef2 <page_free>
	page_free(pp2);
f0101521:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101524:	89 04 24             	mov    %eax,(%esp)
f0101527:	e8 c6 f9 ff ff       	call   f0100ef2 <page_free>
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f010152c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101533:	e8 35 f9 ff ff       	call   f0100e6d <page_alloc>
f0101538:	89 c6                	mov    %eax,%esi
f010153a:	85 c0                	test   %eax,%eax
f010153c:	75 24                	jne    f0101562 <mem_init+0x3c2>
f010153e:	c7 44 24 0c e9 4c 10 	movl   $0xf0104ce9,0xc(%esp)
f0101545:	f0 
f0101546:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f010154d:	f0 
f010154e:	c7 44 24 04 81 02 00 	movl   $0x281,0x4(%esp)
f0101555:	00 
f0101556:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010155d:	e8 32 eb ff ff       	call   f0100094 <_panic>
	assert((pp1 = page_alloc(0)));
f0101562:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101569:	e8 ff f8 ff ff       	call   f0100e6d <page_alloc>
f010156e:	89 c7                	mov    %eax,%edi
f0101570:	85 c0                	test   %eax,%eax
f0101572:	75 24                	jne    f0101598 <mem_init+0x3f8>
f0101574:	c7 44 24 0c ff 4c 10 	movl   $0xf0104cff,0xc(%esp)
f010157b:	f0 
f010157c:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101583:	f0 
f0101584:	c7 44 24 04 82 02 00 	movl   $0x282,0x4(%esp)
f010158b:	00 
f010158c:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101593:	e8 fc ea ff ff       	call   f0100094 <_panic>
	assert((pp2 = page_alloc(0)));
f0101598:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010159f:	e8 c9 f8 ff ff       	call   f0100e6d <page_alloc>
f01015a4:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01015a7:	85 c0                	test   %eax,%eax
f01015a9:	75 24                	jne    f01015cf <mem_init+0x42f>
f01015ab:	c7 44 24 0c 15 4d 10 	movl   $0xf0104d15,0xc(%esp)
f01015b2:	f0 
f01015b3:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01015ba:	f0 
f01015bb:	c7 44 24 04 83 02 00 	movl   $0x283,0x4(%esp)
f01015c2:	00 
f01015c3:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01015ca:	e8 c5 ea ff ff       	call   f0100094 <_panic>
	assert(pp0);
	assert(pp1 && pp1 != pp0);
f01015cf:	39 fe                	cmp    %edi,%esi
f01015d1:	75 24                	jne    f01015f7 <mem_init+0x457>
f01015d3:	c7 44 24 0c 2b 4d 10 	movl   $0xf0104d2b,0xc(%esp)
f01015da:	f0 
f01015db:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01015e2:	f0 
f01015e3:	c7 44 24 04 85 02 00 	movl   $0x285,0x4(%esp)
f01015ea:	00 
f01015eb:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01015f2:	e8 9d ea ff ff       	call   f0100094 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f01015f7:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01015fa:	39 c7                	cmp    %eax,%edi
f01015fc:	74 04                	je     f0101602 <mem_init+0x462>
f01015fe:	39 c6                	cmp    %eax,%esi
f0101600:	75 24                	jne    f0101626 <mem_init+0x486>
f0101602:	c7 44 24 0c 98 46 10 	movl   $0xf0104698,0xc(%esp)
f0101609:	f0 
f010160a:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101611:	f0 
f0101612:	c7 44 24 04 86 02 00 	movl   $0x286,0x4(%esp)
f0101619:	00 
f010161a:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101621:	e8 6e ea ff ff       	call   f0100094 <_panic>
	assert(!page_alloc(0));
f0101626:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010162d:	e8 3b f8 ff ff       	call   f0100e6d <page_alloc>
f0101632:	85 c0                	test   %eax,%eax
f0101634:	74 24                	je     f010165a <mem_init+0x4ba>
f0101636:	c7 44 24 0c 94 4d 10 	movl   $0xf0104d94,0xc(%esp)
f010163d:	f0 
f010163e:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101645:	f0 
f0101646:	c7 44 24 04 87 02 00 	movl   $0x287,0x4(%esp)
f010164d:	00 
f010164e:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101655:	e8 3a ea ff ff       	call   f0100094 <_panic>
f010165a:	89 f0                	mov    %esi,%eax
f010165c:	2b 05 88 79 11 f0    	sub    0xf0117988,%eax
f0101662:	c1 f8 03             	sar    $0x3,%eax
f0101665:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101668:	89 c2                	mov    %eax,%edx
f010166a:	c1 ea 0c             	shr    $0xc,%edx
f010166d:	3b 15 80 79 11 f0    	cmp    0xf0117980,%edx
f0101673:	72 20                	jb     f0101695 <mem_init+0x4f5>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101675:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101679:	c7 44 24 08 30 45 10 	movl   $0xf0104530,0x8(%esp)
f0101680:	f0 
f0101681:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f0101688:	00 
f0101689:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f0101690:	e8 ff e9 ff ff       	call   f0100094 <_panic>

	// test flags
	memset(page2kva(pp0), 1, PGSIZE);
f0101695:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010169c:	00 
f010169d:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f01016a4:	00 
	return (void *)(pa + KERNBASE);
f01016a5:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01016aa:	89 04 24             	mov    %eax,(%esp)
f01016ad:	e8 ed 23 00 00       	call   f0103a9f <memset>
	page_free(pp0);
f01016b2:	89 34 24             	mov    %esi,(%esp)
f01016b5:	e8 38 f8 ff ff       	call   f0100ef2 <page_free>
	assert((pp = page_alloc(ALLOC_ZERO)));
f01016ba:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01016c1:	e8 a7 f7 ff ff       	call   f0100e6d <page_alloc>
f01016c6:	85 c0                	test   %eax,%eax
f01016c8:	75 24                	jne    f01016ee <mem_init+0x54e>
f01016ca:	c7 44 24 0c a3 4d 10 	movl   $0xf0104da3,0xc(%esp)
f01016d1:	f0 
f01016d2:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01016d9:	f0 
f01016da:	c7 44 24 04 8c 02 00 	movl   $0x28c,0x4(%esp)
f01016e1:	00 
f01016e2:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01016e9:	e8 a6 e9 ff ff       	call   f0100094 <_panic>
	assert(pp && pp0 == pp);
f01016ee:	39 c6                	cmp    %eax,%esi
f01016f0:	74 24                	je     f0101716 <mem_init+0x576>
f01016f2:	c7 44 24 0c c1 4d 10 	movl   $0xf0104dc1,0xc(%esp)
f01016f9:	f0 
f01016fa:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101701:	f0 
f0101702:	c7 44 24 04 8d 02 00 	movl   $0x28d,0x4(%esp)
f0101709:	00 
f010170a:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101711:	e8 7e e9 ff ff       	call   f0100094 <_panic>
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101716:	89 f2                	mov    %esi,%edx
f0101718:	2b 15 88 79 11 f0    	sub    0xf0117988,%edx
f010171e:	c1 fa 03             	sar    $0x3,%edx
f0101721:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101724:	89 d0                	mov    %edx,%eax
f0101726:	c1 e8 0c             	shr    $0xc,%eax
f0101729:	3b 05 80 79 11 f0    	cmp    0xf0117980,%eax
f010172f:	72 20                	jb     f0101751 <mem_init+0x5b1>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101731:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101735:	c7 44 24 08 30 45 10 	movl   $0xf0104530,0x8(%esp)
f010173c:	f0 
f010173d:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f0101744:	00 
f0101745:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f010174c:	e8 43 e9 ff ff       	call   f0100094 <_panic>
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
		assert(c[i] == 0);
f0101751:	80 ba 00 00 00 f0 00 	cmpb   $0x0,-0x10000000(%edx)
f0101758:	75 11                	jne    f010176b <mem_init+0x5cb>
f010175a:	8d 82 01 00 00 f0    	lea    -0xfffffff(%edx),%eax
f0101760:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0101766:	80 38 00             	cmpb   $0x0,(%eax)
f0101769:	74 24                	je     f010178f <mem_init+0x5ef>
f010176b:	c7 44 24 0c d1 4d 10 	movl   $0xf0104dd1,0xc(%esp)
f0101772:	f0 
f0101773:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f010177a:	f0 
f010177b:	c7 44 24 04 90 02 00 	movl   $0x290,0x4(%esp)
f0101782:	00 
f0101783:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010178a:	e8 05 e9 ff ff       	call   f0100094 <_panic>
f010178f:	83 c0 01             	add    $0x1,%eax
	memset(page2kva(pp0), 1, PGSIZE);
	page_free(pp0);
	assert((pp = page_alloc(ALLOC_ZERO)));
	assert(pp && pp0 == pp);
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
f0101792:	39 d0                	cmp    %edx,%eax
f0101794:	75 d0                	jne    f0101766 <mem_init+0x5c6>
		assert(c[i] == 0);

	// give free list back
	page_free_list = fl;
f0101796:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101799:	a3 5c 75 11 f0       	mov    %eax,0xf011755c

	// free the pages we took
	page_free(pp0);
f010179e:	89 34 24             	mov    %esi,(%esp)
f01017a1:	e8 4c f7 ff ff       	call   f0100ef2 <page_free>
	page_free(pp1);
f01017a6:	89 3c 24             	mov    %edi,(%esp)
f01017a9:	e8 44 f7 ff ff       	call   f0100ef2 <page_free>
	page_free(pp2);
f01017ae:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01017b1:	89 04 24             	mov    %eax,(%esp)
f01017b4:	e8 39 f7 ff ff       	call   f0100ef2 <page_free>

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f01017b9:	a1 5c 75 11 f0       	mov    0xf011755c,%eax
f01017be:	85 c0                	test   %eax,%eax
f01017c0:	74 09                	je     f01017cb <mem_init+0x62b>
		--nfree;
f01017c2:	83 eb 01             	sub    $0x1,%ebx
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f01017c5:	8b 00                	mov    (%eax),%eax
f01017c7:	85 c0                	test   %eax,%eax
f01017c9:	75 f7                	jne    f01017c2 <mem_init+0x622>
		--nfree;
	assert(nfree == 0);
f01017cb:	85 db                	test   %ebx,%ebx
f01017cd:	74 24                	je     f01017f3 <mem_init+0x653>
f01017cf:	c7 44 24 0c db 4d 10 	movl   $0xf0104ddb,0xc(%esp)
f01017d6:	f0 
f01017d7:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01017de:	f0 
f01017df:	c7 44 24 04 9d 02 00 	movl   $0x29d,0x4(%esp)
f01017e6:	00 
f01017e7:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01017ee:	e8 a1 e8 ff ff       	call   f0100094 <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f01017f3:	c7 04 24 b8 46 10 f0 	movl   $0xf01046b8,(%esp)
f01017fa:	e8 06 17 00 00       	call   f0102f05 <cprintf>
	int i;
	extern pde_t entry_pgdir[];

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f01017ff:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101806:	e8 62 f6 ff ff       	call   f0100e6d <page_alloc>
f010180b:	89 c3                	mov    %eax,%ebx
f010180d:	85 c0                	test   %eax,%eax
f010180f:	75 24                	jne    f0101835 <mem_init+0x695>
f0101811:	c7 44 24 0c e9 4c 10 	movl   $0xf0104ce9,0xc(%esp)
f0101818:	f0 
f0101819:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101820:	f0 
f0101821:	c7 44 24 04 f6 02 00 	movl   $0x2f6,0x4(%esp)
f0101828:	00 
f0101829:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101830:	e8 5f e8 ff ff       	call   f0100094 <_panic>
	assert((pp1 = page_alloc(0)));
f0101835:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010183c:	e8 2c f6 ff ff       	call   f0100e6d <page_alloc>
f0101841:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0101844:	85 c0                	test   %eax,%eax
f0101846:	75 24                	jne    f010186c <mem_init+0x6cc>
f0101848:	c7 44 24 0c ff 4c 10 	movl   $0xf0104cff,0xc(%esp)
f010184f:	f0 
f0101850:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101857:	f0 
f0101858:	c7 44 24 04 f7 02 00 	movl   $0x2f7,0x4(%esp)
f010185f:	00 
f0101860:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101867:	e8 28 e8 ff ff       	call   f0100094 <_panic>
	assert((pp2 = page_alloc(0)));
f010186c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101873:	e8 f5 f5 ff ff       	call   f0100e6d <page_alloc>
f0101878:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f010187b:	85 c0                	test   %eax,%eax
f010187d:	75 24                	jne    f01018a3 <mem_init+0x703>
f010187f:	c7 44 24 0c 15 4d 10 	movl   $0xf0104d15,0xc(%esp)
f0101886:	f0 
f0101887:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f010188e:	f0 
f010188f:	c7 44 24 04 f8 02 00 	movl   $0x2f8,0x4(%esp)
f0101896:	00 
f0101897:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010189e:	e8 f1 e7 ff ff       	call   f0100094 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f01018a3:	3b 5d d0             	cmp    -0x30(%ebp),%ebx
f01018a6:	75 24                	jne    f01018cc <mem_init+0x72c>
f01018a8:	c7 44 24 0c 2b 4d 10 	movl   $0xf0104d2b,0xc(%esp)
f01018af:	f0 
f01018b0:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01018b7:	f0 
f01018b8:	c7 44 24 04 fb 02 00 	movl   $0x2fb,0x4(%esp)
f01018bf:	00 
f01018c0:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01018c7:	e8 c8 e7 ff ff       	call   f0100094 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f01018cc:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01018cf:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f01018d2:	74 04                	je     f01018d8 <mem_init+0x738>
f01018d4:	39 c3                	cmp    %eax,%ebx
f01018d6:	75 24                	jne    f01018fc <mem_init+0x75c>
f01018d8:	c7 44 24 0c 98 46 10 	movl   $0xf0104698,0xc(%esp)
f01018df:	f0 
f01018e0:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01018e7:	f0 
f01018e8:	c7 44 24 04 fc 02 00 	movl   $0x2fc,0x4(%esp)
f01018ef:	00 
f01018f0:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01018f7:	e8 98 e7 ff ff       	call   f0100094 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f01018fc:	a1 5c 75 11 f0       	mov    0xf011755c,%eax
f0101901:	89 45 cc             	mov    %eax,-0x34(%ebp)
	page_free_list = 0;
f0101904:	c7 05 5c 75 11 f0 00 	movl   $0x0,0xf011755c
f010190b:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f010190e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101915:	e8 53 f5 ff ff       	call   f0100e6d <page_alloc>
f010191a:	85 c0                	test   %eax,%eax
f010191c:	74 24                	je     f0101942 <mem_init+0x7a2>
f010191e:	c7 44 24 0c 94 4d 10 	movl   $0xf0104d94,0xc(%esp)
f0101925:	f0 
f0101926:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f010192d:	f0 
f010192e:	c7 44 24 04 03 03 00 	movl   $0x303,0x4(%esp)
f0101935:	00 
f0101936:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010193d:	e8 52 e7 ff ff       	call   f0100094 <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f0101942:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101945:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101949:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101950:	00 
f0101951:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f0101956:	89 04 24             	mov    %eax,(%esp)
f0101959:	e8 d6 f6 ff ff       	call   f0101034 <page_lookup>
f010195e:	85 c0                	test   %eax,%eax
f0101960:	74 24                	je     f0101986 <mem_init+0x7e6>
f0101962:	c7 44 24 0c d8 46 10 	movl   $0xf01046d8,0xc(%esp)
f0101969:	f0 
f010196a:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101971:	f0 
f0101972:	c7 44 24 04 06 03 00 	movl   $0x306,0x4(%esp)
f0101979:	00 
f010197a:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101981:	e8 0e e7 ff ff       	call   f0100094 <_panic>

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);
f0101986:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f010198d:	00 
f010198e:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101995:	00 
f0101996:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101999:	89 44 24 04          	mov    %eax,0x4(%esp)
f010199d:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f01019a2:	89 04 24             	mov    %eax,(%esp)
f01019a5:	e8 35 f7 ff ff       	call   f01010df <page_insert>
f01019aa:	85 c0                	test   %eax,%eax
f01019ac:	78 24                	js     f01019d2 <mem_init+0x832>
f01019ae:	c7 44 24 0c 10 47 10 	movl   $0xf0104710,0xc(%esp)
f01019b5:	f0 
f01019b6:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01019bd:	f0 
f01019be:	c7 44 24 04 09 03 00 	movl   $0x309,0x4(%esp)
f01019c5:	00 
f01019c6:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01019cd:	e8 c2 e6 ff ff       	call   f0100094 <_panic>

	// free pp0 and try again: pp0 should be used for page table
	page_free(pp0);
f01019d2:	89 1c 24             	mov    %ebx,(%esp)
f01019d5:	e8 18 f5 ff ff       	call   f0100ef2 <page_free>
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) == 0);
f01019da:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01019e1:	00 
f01019e2:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01019e9:	00 
f01019ea:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01019ed:	89 44 24 04          	mov    %eax,0x4(%esp)
f01019f1:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f01019f6:	89 04 24             	mov    %eax,(%esp)
f01019f9:	e8 e1 f6 ff ff       	call   f01010df <page_insert>
f01019fe:	85 c0                	test   %eax,%eax
f0101a00:	74 24                	je     f0101a26 <mem_init+0x886>
f0101a02:	c7 44 24 0c 40 47 10 	movl   $0xf0104740,0xc(%esp)
f0101a09:	f0 
f0101a0a:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101a11:	f0 
f0101a12:	c7 44 24 04 0d 03 00 	movl   $0x30d,0x4(%esp)
f0101a19:	00 
f0101a1a:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101a21:	e8 6e e6 ff ff       	call   f0100094 <_panic>
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101a26:	8b 35 84 79 11 f0    	mov    0xf0117984,%esi
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101a2c:	8b 3d 88 79 11 f0    	mov    0xf0117988,%edi
f0101a32:	8b 16                	mov    (%esi),%edx
f0101a34:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0101a3a:	89 d8                	mov    %ebx,%eax
f0101a3c:	29 f8                	sub    %edi,%eax
f0101a3e:	c1 f8 03             	sar    $0x3,%eax
f0101a41:	c1 e0 0c             	shl    $0xc,%eax
f0101a44:	39 c2                	cmp    %eax,%edx
f0101a46:	74 24                	je     f0101a6c <mem_init+0x8cc>
f0101a48:	c7 44 24 0c 70 47 10 	movl   $0xf0104770,0xc(%esp)
f0101a4f:	f0 
f0101a50:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101a57:	f0 
f0101a58:	c7 44 24 04 0e 03 00 	movl   $0x30e,0x4(%esp)
f0101a5f:	00 
f0101a60:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101a67:	e8 28 e6 ff ff       	call   f0100094 <_panic>
	assert(check_va2pa(kern_pgdir, 0x0) == page2pa(pp1));
f0101a6c:	ba 00 00 00 00       	mov    $0x0,%edx
f0101a71:	89 f0                	mov    %esi,%eax
f0101a73:	e8 3c ef ff ff       	call   f01009b4 <check_va2pa>
f0101a78:	8b 55 d0             	mov    -0x30(%ebp),%edx
f0101a7b:	29 fa                	sub    %edi,%edx
f0101a7d:	c1 fa 03             	sar    $0x3,%edx
f0101a80:	c1 e2 0c             	shl    $0xc,%edx
f0101a83:	39 d0                	cmp    %edx,%eax
f0101a85:	74 24                	je     f0101aab <mem_init+0x90b>
f0101a87:	c7 44 24 0c 98 47 10 	movl   $0xf0104798,0xc(%esp)
f0101a8e:	f0 
f0101a8f:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101a96:	f0 
f0101a97:	c7 44 24 04 0f 03 00 	movl   $0x30f,0x4(%esp)
f0101a9e:	00 
f0101a9f:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101aa6:	e8 e9 e5 ff ff       	call   f0100094 <_panic>
	assert(pp1->pp_ref == 1);
f0101aab:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101aae:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101ab3:	74 24                	je     f0101ad9 <mem_init+0x939>
f0101ab5:	c7 44 24 0c e6 4d 10 	movl   $0xf0104de6,0xc(%esp)
f0101abc:	f0 
f0101abd:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101ac4:	f0 
f0101ac5:	c7 44 24 04 10 03 00 	movl   $0x310,0x4(%esp)
f0101acc:	00 
f0101acd:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101ad4:	e8 bb e5 ff ff       	call   f0100094 <_panic>
	assert(pp0->pp_ref == 1);
f0101ad9:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0101ade:	74 24                	je     f0101b04 <mem_init+0x964>
f0101ae0:	c7 44 24 0c f7 4d 10 	movl   $0xf0104df7,0xc(%esp)
f0101ae7:	f0 
f0101ae8:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101aef:	f0 
f0101af0:	c7 44 24 04 11 03 00 	movl   $0x311,0x4(%esp)
f0101af7:	00 
f0101af8:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101aff:	e8 90 e5 ff ff       	call   f0100094 <_panic>

	// should be able to map pp2 at PGSIZE because pp0 is already allocated for page table
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101b04:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101b0b:	00 
f0101b0c:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101b13:	00 
f0101b14:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101b17:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101b1b:	89 34 24             	mov    %esi,(%esp)
f0101b1e:	e8 bc f5 ff ff       	call   f01010df <page_insert>
f0101b23:	85 c0                	test   %eax,%eax
f0101b25:	74 24                	je     f0101b4b <mem_init+0x9ab>
f0101b27:	c7 44 24 0c c8 47 10 	movl   $0xf01047c8,0xc(%esp)
f0101b2e:	f0 
f0101b2f:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101b36:	f0 
f0101b37:	c7 44 24 04 14 03 00 	movl   $0x314,0x4(%esp)
f0101b3e:	00 
f0101b3f:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101b46:	e8 49 e5 ff ff       	call   f0100094 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101b4b:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101b50:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f0101b55:	e8 5a ee ff ff       	call   f01009b4 <check_va2pa>
f0101b5a:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101b5d:	2b 15 88 79 11 f0    	sub    0xf0117988,%edx
f0101b63:	c1 fa 03             	sar    $0x3,%edx
f0101b66:	c1 e2 0c             	shl    $0xc,%edx
f0101b69:	39 d0                	cmp    %edx,%eax
f0101b6b:	74 24                	je     f0101b91 <mem_init+0x9f1>
f0101b6d:	c7 44 24 0c 04 48 10 	movl   $0xf0104804,0xc(%esp)
f0101b74:	f0 
f0101b75:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101b7c:	f0 
f0101b7d:	c7 44 24 04 15 03 00 	movl   $0x315,0x4(%esp)
f0101b84:	00 
f0101b85:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101b8c:	e8 03 e5 ff ff       	call   f0100094 <_panic>
	assert(pp2->pp_ref == 1);
f0101b91:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101b94:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101b99:	74 24                	je     f0101bbf <mem_init+0xa1f>
f0101b9b:	c7 44 24 0c 08 4e 10 	movl   $0xf0104e08,0xc(%esp)
f0101ba2:	f0 
f0101ba3:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101baa:	f0 
f0101bab:	c7 44 24 04 16 03 00 	movl   $0x316,0x4(%esp)
f0101bb2:	00 
f0101bb3:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101bba:	e8 d5 e4 ff ff       	call   f0100094 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0101bbf:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101bc6:	e8 a2 f2 ff ff       	call   f0100e6d <page_alloc>
f0101bcb:	85 c0                	test   %eax,%eax
f0101bcd:	74 24                	je     f0101bf3 <mem_init+0xa53>
f0101bcf:	c7 44 24 0c 94 4d 10 	movl   $0xf0104d94,0xc(%esp)
f0101bd6:	f0 
f0101bd7:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101bde:	f0 
f0101bdf:	c7 44 24 04 19 03 00 	movl   $0x319,0x4(%esp)
f0101be6:	00 
f0101be7:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101bee:	e8 a1 e4 ff ff       	call   f0100094 <_panic>

	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101bf3:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101bfa:	00 
f0101bfb:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101c02:	00 
f0101c03:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101c06:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101c0a:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f0101c0f:	89 04 24             	mov    %eax,(%esp)
f0101c12:	e8 c8 f4 ff ff       	call   f01010df <page_insert>
f0101c17:	85 c0                	test   %eax,%eax
f0101c19:	74 24                	je     f0101c3f <mem_init+0xa9f>
f0101c1b:	c7 44 24 0c c8 47 10 	movl   $0xf01047c8,0xc(%esp)
f0101c22:	f0 
f0101c23:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101c2a:	f0 
f0101c2b:	c7 44 24 04 1c 03 00 	movl   $0x31c,0x4(%esp)
f0101c32:	00 
f0101c33:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101c3a:	e8 55 e4 ff ff       	call   f0100094 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101c3f:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101c44:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f0101c49:	e8 66 ed ff ff       	call   f01009b4 <check_va2pa>
f0101c4e:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101c51:	2b 15 88 79 11 f0    	sub    0xf0117988,%edx
f0101c57:	c1 fa 03             	sar    $0x3,%edx
f0101c5a:	c1 e2 0c             	shl    $0xc,%edx
f0101c5d:	39 d0                	cmp    %edx,%eax
f0101c5f:	74 24                	je     f0101c85 <mem_init+0xae5>
f0101c61:	c7 44 24 0c 04 48 10 	movl   $0xf0104804,0xc(%esp)
f0101c68:	f0 
f0101c69:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101c70:	f0 
f0101c71:	c7 44 24 04 1d 03 00 	movl   $0x31d,0x4(%esp)
f0101c78:	00 
f0101c79:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101c80:	e8 0f e4 ff ff       	call   f0100094 <_panic>
	assert(pp2->pp_ref == 1);
f0101c85:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101c88:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101c8d:	74 24                	je     f0101cb3 <mem_init+0xb13>
f0101c8f:	c7 44 24 0c 08 4e 10 	movl   $0xf0104e08,0xc(%esp)
f0101c96:	f0 
f0101c97:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101c9e:	f0 
f0101c9f:	c7 44 24 04 1e 03 00 	movl   $0x31e,0x4(%esp)
f0101ca6:	00 
f0101ca7:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101cae:	e8 e1 e3 ff ff       	call   f0100094 <_panic>

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));
f0101cb3:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101cba:	e8 ae f1 ff ff       	call   f0100e6d <page_alloc>
f0101cbf:	85 c0                	test   %eax,%eax
f0101cc1:	74 24                	je     f0101ce7 <mem_init+0xb47>
f0101cc3:	c7 44 24 0c 94 4d 10 	movl   $0xf0104d94,0xc(%esp)
f0101cca:	f0 
f0101ccb:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101cd2:	f0 
f0101cd3:	c7 44 24 04 22 03 00 	movl   $0x322,0x4(%esp)
f0101cda:	00 
f0101cdb:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101ce2:	e8 ad e3 ff ff       	call   f0100094 <_panic>

	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f0101ce7:	8b 15 84 79 11 f0    	mov    0xf0117984,%edx
f0101ced:	8b 02                	mov    (%edx),%eax
f0101cef:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101cf4:	89 c1                	mov    %eax,%ecx
f0101cf6:	c1 e9 0c             	shr    $0xc,%ecx
f0101cf9:	3b 0d 80 79 11 f0    	cmp    0xf0117980,%ecx
f0101cff:	72 20                	jb     f0101d21 <mem_init+0xb81>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101d01:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101d05:	c7 44 24 08 30 45 10 	movl   $0xf0104530,0x8(%esp)
f0101d0c:	f0 
f0101d0d:	c7 44 24 04 25 03 00 	movl   $0x325,0x4(%esp)
f0101d14:	00 
f0101d15:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101d1c:	e8 73 e3 ff ff       	call   f0100094 <_panic>
	return (void *)(pa + KERNBASE);
f0101d21:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101d26:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	assert(pgdir_walk(kern_pgdir, (void*)PGSIZE, 0) == ptep+PTX(PGSIZE));
f0101d29:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101d30:	00 
f0101d31:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0101d38:	00 
f0101d39:	89 14 24             	mov    %edx,(%esp)
f0101d3c:	e8 e9 f1 ff ff       	call   f0100f2a <pgdir_walk>
f0101d41:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0101d44:	8d 51 04             	lea    0x4(%ecx),%edx
f0101d47:	39 d0                	cmp    %edx,%eax
f0101d49:	74 24                	je     f0101d6f <mem_init+0xbcf>
f0101d4b:	c7 44 24 0c 34 48 10 	movl   $0xf0104834,0xc(%esp)
f0101d52:	f0 
f0101d53:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101d5a:	f0 
f0101d5b:	c7 44 24 04 26 03 00 	movl   $0x326,0x4(%esp)
f0101d62:	00 
f0101d63:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101d6a:	e8 25 e3 ff ff       	call   f0100094 <_panic>

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
f0101d6f:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0101d76:	00 
f0101d77:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101d7e:	00 
f0101d7f:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101d82:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101d86:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f0101d8b:	89 04 24             	mov    %eax,(%esp)
f0101d8e:	e8 4c f3 ff ff       	call   f01010df <page_insert>
f0101d93:	85 c0                	test   %eax,%eax
f0101d95:	74 24                	je     f0101dbb <mem_init+0xc1b>
f0101d97:	c7 44 24 0c 74 48 10 	movl   $0xf0104874,0xc(%esp)
f0101d9e:	f0 
f0101d9f:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101da6:	f0 
f0101da7:	c7 44 24 04 29 03 00 	movl   $0x329,0x4(%esp)
f0101dae:	00 
f0101daf:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101db6:	e8 d9 e2 ff ff       	call   f0100094 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101dbb:	8b 35 84 79 11 f0    	mov    0xf0117984,%esi
f0101dc1:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101dc6:	89 f0                	mov    %esi,%eax
f0101dc8:	e8 e7 eb ff ff       	call   f01009b4 <check_va2pa>
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101dcd:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101dd0:	2b 15 88 79 11 f0    	sub    0xf0117988,%edx
f0101dd6:	c1 fa 03             	sar    $0x3,%edx
f0101dd9:	c1 e2 0c             	shl    $0xc,%edx
f0101ddc:	39 d0                	cmp    %edx,%eax
f0101dde:	74 24                	je     f0101e04 <mem_init+0xc64>
f0101de0:	c7 44 24 0c 04 48 10 	movl   $0xf0104804,0xc(%esp)
f0101de7:	f0 
f0101de8:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101def:	f0 
f0101df0:	c7 44 24 04 2a 03 00 	movl   $0x32a,0x4(%esp)
f0101df7:	00 
f0101df8:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101dff:	e8 90 e2 ff ff       	call   f0100094 <_panic>
	assert(pp2->pp_ref == 1);
f0101e04:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101e07:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101e0c:	74 24                	je     f0101e32 <mem_init+0xc92>
f0101e0e:	c7 44 24 0c 08 4e 10 	movl   $0xf0104e08,0xc(%esp)
f0101e15:	f0 
f0101e16:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101e1d:	f0 
f0101e1e:	c7 44 24 04 2b 03 00 	movl   $0x32b,0x4(%esp)
f0101e25:	00 
f0101e26:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101e2d:	e8 62 e2 ff ff       	call   f0100094 <_panic>
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U);
f0101e32:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101e39:	00 
f0101e3a:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0101e41:	00 
f0101e42:	89 34 24             	mov    %esi,(%esp)
f0101e45:	e8 e0 f0 ff ff       	call   f0100f2a <pgdir_walk>
f0101e4a:	f6 00 04             	testb  $0x4,(%eax)
f0101e4d:	75 24                	jne    f0101e73 <mem_init+0xcd3>
f0101e4f:	c7 44 24 0c b4 48 10 	movl   $0xf01048b4,0xc(%esp)
f0101e56:	f0 
f0101e57:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101e5e:	f0 
f0101e5f:	c7 44 24 04 2c 03 00 	movl   $0x32c,0x4(%esp)
f0101e66:	00 
f0101e67:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101e6e:	e8 21 e2 ff ff       	call   f0100094 <_panic>
	assert(kern_pgdir[0] & PTE_U);
f0101e73:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f0101e78:	f6 00 04             	testb  $0x4,(%eax)
f0101e7b:	75 24                	jne    f0101ea1 <mem_init+0xd01>
f0101e7d:	c7 44 24 0c 19 4e 10 	movl   $0xf0104e19,0xc(%esp)
f0101e84:	f0 
f0101e85:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101e8c:	f0 
f0101e8d:	c7 44 24 04 2d 03 00 	movl   $0x32d,0x4(%esp)
f0101e94:	00 
f0101e95:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101e9c:	e8 f3 e1 ff ff       	call   f0100094 <_panic>

	// should not be able to map at PTSIZE because need free page for page table
	assert(page_insert(kern_pgdir, pp0, (void*) PTSIZE, PTE_W) < 0);
f0101ea1:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101ea8:	00 
f0101ea9:	c7 44 24 08 00 00 40 	movl   $0x400000,0x8(%esp)
f0101eb0:	00 
f0101eb1:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101eb5:	89 04 24             	mov    %eax,(%esp)
f0101eb8:	e8 22 f2 ff ff       	call   f01010df <page_insert>
f0101ebd:	85 c0                	test   %eax,%eax
f0101ebf:	78 24                	js     f0101ee5 <mem_init+0xd45>
f0101ec1:	c7 44 24 0c e8 48 10 	movl   $0xf01048e8,0xc(%esp)
f0101ec8:	f0 
f0101ec9:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101ed0:	f0 
f0101ed1:	c7 44 24 04 30 03 00 	movl   $0x330,0x4(%esp)
f0101ed8:	00 
f0101ed9:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101ee0:	e8 af e1 ff ff       	call   f0100094 <_panic>

	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
f0101ee5:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101eec:	00 
f0101eed:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101ef4:	00 
f0101ef5:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101ef8:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101efc:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f0101f01:	89 04 24             	mov    %eax,(%esp)
f0101f04:	e8 d6 f1 ff ff       	call   f01010df <page_insert>
f0101f09:	85 c0                	test   %eax,%eax
f0101f0b:	74 24                	je     f0101f31 <mem_init+0xd91>
f0101f0d:	c7 44 24 0c 20 49 10 	movl   $0xf0104920,0xc(%esp)
f0101f14:	f0 
f0101f15:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101f1c:	f0 
f0101f1d:	c7 44 24 04 33 03 00 	movl   $0x333,0x4(%esp)
f0101f24:	00 
f0101f25:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101f2c:	e8 63 e1 ff ff       	call   f0100094 <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f0101f31:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101f38:	00 
f0101f39:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0101f40:	00 
f0101f41:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f0101f46:	89 04 24             	mov    %eax,(%esp)
f0101f49:	e8 dc ef ff ff       	call   f0100f2a <pgdir_walk>
f0101f4e:	f6 00 04             	testb  $0x4,(%eax)
f0101f51:	74 24                	je     f0101f77 <mem_init+0xdd7>
f0101f53:	c7 44 24 0c 5c 49 10 	movl   $0xf010495c,0xc(%esp)
f0101f5a:	f0 
f0101f5b:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101f62:	f0 
f0101f63:	c7 44 24 04 34 03 00 	movl   $0x334,0x4(%esp)
f0101f6a:	00 
f0101f6b:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101f72:	e8 1d e1 ff ff       	call   f0100094 <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f0101f77:	8b 3d 84 79 11 f0    	mov    0xf0117984,%edi
f0101f7d:	ba 00 00 00 00       	mov    $0x0,%edx
f0101f82:	89 f8                	mov    %edi,%eax
f0101f84:	e8 2b ea ff ff       	call   f01009b4 <check_va2pa>
f0101f89:	89 c6                	mov    %eax,%esi
f0101f8b:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101f8e:	2b 05 88 79 11 f0    	sub    0xf0117988,%eax
f0101f94:	c1 f8 03             	sar    $0x3,%eax
f0101f97:	c1 e0 0c             	shl    $0xc,%eax
f0101f9a:	39 c6                	cmp    %eax,%esi
f0101f9c:	74 24                	je     f0101fc2 <mem_init+0xe22>
f0101f9e:	c7 44 24 0c 94 49 10 	movl   $0xf0104994,0xc(%esp)
f0101fa5:	f0 
f0101fa6:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101fad:	f0 
f0101fae:	c7 44 24 04 37 03 00 	movl   $0x337,0x4(%esp)
f0101fb5:	00 
f0101fb6:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101fbd:	e8 d2 e0 ff ff       	call   f0100094 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0101fc2:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101fc7:	89 f8                	mov    %edi,%eax
f0101fc9:	e8 e6 e9 ff ff       	call   f01009b4 <check_va2pa>
f0101fce:	39 c6                	cmp    %eax,%esi
f0101fd0:	74 24                	je     f0101ff6 <mem_init+0xe56>
f0101fd2:	c7 44 24 0c c0 49 10 	movl   $0xf01049c0,0xc(%esp)
f0101fd9:	f0 
f0101fda:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0101fe1:	f0 
f0101fe2:	c7 44 24 04 38 03 00 	movl   $0x338,0x4(%esp)
f0101fe9:	00 
f0101fea:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0101ff1:	e8 9e e0 ff ff       	call   f0100094 <_panic>
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
f0101ff6:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101ff9:	66 83 78 04 02       	cmpw   $0x2,0x4(%eax)
f0101ffe:	74 24                	je     f0102024 <mem_init+0xe84>
f0102000:	c7 44 24 0c 2f 4e 10 	movl   $0xf0104e2f,0xc(%esp)
f0102007:	f0 
f0102008:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f010200f:	f0 
f0102010:	c7 44 24 04 3a 03 00 	movl   $0x33a,0x4(%esp)
f0102017:	00 
f0102018:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010201f:	e8 70 e0 ff ff       	call   f0100094 <_panic>
	assert(pp2->pp_ref == 0);
f0102024:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102027:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f010202c:	74 24                	je     f0102052 <mem_init+0xeb2>
f010202e:	c7 44 24 0c 40 4e 10 	movl   $0xf0104e40,0xc(%esp)
f0102035:	f0 
f0102036:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f010203d:	f0 
f010203e:	c7 44 24 04 3b 03 00 	movl   $0x33b,0x4(%esp)
f0102045:	00 
f0102046:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010204d:	e8 42 e0 ff ff       	call   f0100094 <_panic>

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);
f0102052:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102059:	e8 0f ee ff ff       	call   f0100e6d <page_alloc>
f010205e:	85 c0                	test   %eax,%eax
f0102060:	74 05                	je     f0102067 <mem_init+0xec7>
f0102062:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f0102065:	74 24                	je     f010208b <mem_init+0xeeb>
f0102067:	c7 44 24 0c f0 49 10 	movl   $0xf01049f0,0xc(%esp)
f010206e:	f0 
f010206f:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102076:	f0 
f0102077:	c7 44 24 04 3e 03 00 	movl   $0x33e,0x4(%esp)
f010207e:	00 
f010207f:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102086:	e8 09 e0 ff ff       	call   f0100094 <_panic>

	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f010208b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0102092:	00 
f0102093:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f0102098:	89 04 24             	mov    %eax,(%esp)
f010209b:	e8 01 f0 ff ff       	call   f01010a1 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01020a0:	8b 35 84 79 11 f0    	mov    0xf0117984,%esi
f01020a6:	ba 00 00 00 00       	mov    $0x0,%edx
f01020ab:	89 f0                	mov    %esi,%eax
f01020ad:	e8 02 e9 ff ff       	call   f01009b4 <check_va2pa>
f01020b2:	83 f8 ff             	cmp    $0xffffffff,%eax
f01020b5:	74 24                	je     f01020db <mem_init+0xf3b>
f01020b7:	c7 44 24 0c 14 4a 10 	movl   $0xf0104a14,0xc(%esp)
f01020be:	f0 
f01020bf:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01020c6:	f0 
f01020c7:	c7 44 24 04 42 03 00 	movl   $0x342,0x4(%esp)
f01020ce:	00 
f01020cf:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01020d6:	e8 b9 df ff ff       	call   f0100094 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f01020db:	ba 00 10 00 00       	mov    $0x1000,%edx
f01020e0:	89 f0                	mov    %esi,%eax
f01020e2:	e8 cd e8 ff ff       	call   f01009b4 <check_va2pa>
f01020e7:	8b 55 d0             	mov    -0x30(%ebp),%edx
f01020ea:	2b 15 88 79 11 f0    	sub    0xf0117988,%edx
f01020f0:	c1 fa 03             	sar    $0x3,%edx
f01020f3:	c1 e2 0c             	shl    $0xc,%edx
f01020f6:	39 d0                	cmp    %edx,%eax
f01020f8:	74 24                	je     f010211e <mem_init+0xf7e>
f01020fa:	c7 44 24 0c c0 49 10 	movl   $0xf01049c0,0xc(%esp)
f0102101:	f0 
f0102102:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102109:	f0 
f010210a:	c7 44 24 04 43 03 00 	movl   $0x343,0x4(%esp)
f0102111:	00 
f0102112:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102119:	e8 76 df ff ff       	call   f0100094 <_panic>
	assert(pp1->pp_ref == 1);
f010211e:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102121:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0102126:	74 24                	je     f010214c <mem_init+0xfac>
f0102128:	c7 44 24 0c e6 4d 10 	movl   $0xf0104de6,0xc(%esp)
f010212f:	f0 
f0102130:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102137:	f0 
f0102138:	c7 44 24 04 44 03 00 	movl   $0x344,0x4(%esp)
f010213f:	00 
f0102140:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102147:	e8 48 df ff ff       	call   f0100094 <_panic>
	assert(pp2->pp_ref == 0);
f010214c:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010214f:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102154:	74 24                	je     f010217a <mem_init+0xfda>
f0102156:	c7 44 24 0c 40 4e 10 	movl   $0xf0104e40,0xc(%esp)
f010215d:	f0 
f010215e:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102165:	f0 
f0102166:	c7 44 24 04 45 03 00 	movl   $0x345,0x4(%esp)
f010216d:	00 
f010216e:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102175:	e8 1a df ff ff       	call   f0100094 <_panic>

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
f010217a:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102181:	00 
f0102182:	89 34 24             	mov    %esi,(%esp)
f0102185:	e8 17 ef ff ff       	call   f01010a1 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f010218a:	8b 35 84 79 11 f0    	mov    0xf0117984,%esi
f0102190:	ba 00 00 00 00       	mov    $0x0,%edx
f0102195:	89 f0                	mov    %esi,%eax
f0102197:	e8 18 e8 ff ff       	call   f01009b4 <check_va2pa>
f010219c:	83 f8 ff             	cmp    $0xffffffff,%eax
f010219f:	74 24                	je     f01021c5 <mem_init+0x1025>
f01021a1:	c7 44 24 0c 14 4a 10 	movl   $0xf0104a14,0xc(%esp)
f01021a8:	f0 
f01021a9:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01021b0:	f0 
f01021b1:	c7 44 24 04 49 03 00 	movl   $0x349,0x4(%esp)
f01021b8:	00 
f01021b9:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01021c0:	e8 cf de ff ff       	call   f0100094 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
f01021c5:	ba 00 10 00 00       	mov    $0x1000,%edx
f01021ca:	89 f0                	mov    %esi,%eax
f01021cc:	e8 e3 e7 ff ff       	call   f01009b4 <check_va2pa>
f01021d1:	83 f8 ff             	cmp    $0xffffffff,%eax
f01021d4:	74 24                	je     f01021fa <mem_init+0x105a>
f01021d6:	c7 44 24 0c 38 4a 10 	movl   $0xf0104a38,0xc(%esp)
f01021dd:	f0 
f01021de:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01021e5:	f0 
f01021e6:	c7 44 24 04 4a 03 00 	movl   $0x34a,0x4(%esp)
f01021ed:	00 
f01021ee:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01021f5:	e8 9a de ff ff       	call   f0100094 <_panic>
	assert(pp1->pp_ref == 0);
f01021fa:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01021fd:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102202:	74 24                	je     f0102228 <mem_init+0x1088>
f0102204:	c7 44 24 0c 51 4e 10 	movl   $0xf0104e51,0xc(%esp)
f010220b:	f0 
f010220c:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102213:	f0 
f0102214:	c7 44 24 04 4b 03 00 	movl   $0x34b,0x4(%esp)
f010221b:	00 
f010221c:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102223:	e8 6c de ff ff       	call   f0100094 <_panic>
	assert(pp2->pp_ref == 0);
f0102228:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010222b:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102230:	74 24                	je     f0102256 <mem_init+0x10b6>
f0102232:	c7 44 24 0c 40 4e 10 	movl   $0xf0104e40,0xc(%esp)
f0102239:	f0 
f010223a:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102241:	f0 
f0102242:	c7 44 24 04 4c 03 00 	movl   $0x34c,0x4(%esp)
f0102249:	00 
f010224a:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102251:	e8 3e de ff ff       	call   f0100094 <_panic>

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);
f0102256:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010225d:	e8 0b ec ff ff       	call   f0100e6d <page_alloc>
f0102262:	85 c0                	test   %eax,%eax
f0102264:	74 05                	je     f010226b <mem_init+0x10cb>
f0102266:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0102269:	74 24                	je     f010228f <mem_init+0x10ef>
f010226b:	c7 44 24 0c 60 4a 10 	movl   $0xf0104a60,0xc(%esp)
f0102272:	f0 
f0102273:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f010227a:	f0 
f010227b:	c7 44 24 04 4f 03 00 	movl   $0x34f,0x4(%esp)
f0102282:	00 
f0102283:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010228a:	e8 05 de ff ff       	call   f0100094 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f010228f:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102296:	e8 d2 eb ff ff       	call   f0100e6d <page_alloc>
f010229b:	85 c0                	test   %eax,%eax
f010229d:	74 24                	je     f01022c3 <mem_init+0x1123>
f010229f:	c7 44 24 0c 94 4d 10 	movl   $0xf0104d94,0xc(%esp)
f01022a6:	f0 
f01022a7:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01022ae:	f0 
f01022af:	c7 44 24 04 52 03 00 	movl   $0x352,0x4(%esp)
f01022b6:	00 
f01022b7:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01022be:	e8 d1 dd ff ff       	call   f0100094 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f01022c3:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f01022c8:	8b 08                	mov    (%eax),%ecx
f01022ca:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f01022d0:	89 da                	mov    %ebx,%edx
f01022d2:	2b 15 88 79 11 f0    	sub    0xf0117988,%edx
f01022d8:	c1 fa 03             	sar    $0x3,%edx
f01022db:	c1 e2 0c             	shl    $0xc,%edx
f01022de:	39 d1                	cmp    %edx,%ecx
f01022e0:	74 24                	je     f0102306 <mem_init+0x1166>
f01022e2:	c7 44 24 0c 70 47 10 	movl   $0xf0104770,0xc(%esp)
f01022e9:	f0 
f01022ea:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01022f1:	f0 
f01022f2:	c7 44 24 04 55 03 00 	movl   $0x355,0x4(%esp)
f01022f9:	00 
f01022fa:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102301:	e8 8e dd ff ff       	call   f0100094 <_panic>
	kern_pgdir[0] = 0;
f0102306:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f010230c:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102311:	74 24                	je     f0102337 <mem_init+0x1197>
f0102313:	c7 44 24 0c f7 4d 10 	movl   $0xf0104df7,0xc(%esp)
f010231a:	f0 
f010231b:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102322:	f0 
f0102323:	c7 44 24 04 57 03 00 	movl   $0x357,0x4(%esp)
f010232a:	00 
f010232b:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102332:	e8 5d dd ff ff       	call   f0100094 <_panic>
	pp0->pp_ref = 0;
f0102337:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// check pointer arithmetic in pgdir_walk
	page_free(pp0);
f010233d:	89 1c 24             	mov    %ebx,(%esp)
f0102340:	e8 ad eb ff ff       	call   f0100ef2 <page_free>
	va = (void*)(PGSIZE * NPDENTRIES + PGSIZE);
	ptep = pgdir_walk(kern_pgdir, va, 1);
f0102345:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010234c:	00 
f010234d:	c7 44 24 04 00 10 40 	movl   $0x401000,0x4(%esp)
f0102354:	00 
f0102355:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f010235a:	89 04 24             	mov    %eax,(%esp)
f010235d:	e8 c8 eb ff ff       	call   f0100f2a <pgdir_walk>
f0102362:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f0102365:	8b 0d 84 79 11 f0    	mov    0xf0117984,%ecx
f010236b:	8b 51 04             	mov    0x4(%ecx),%edx
f010236e:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102374:	8b 3d 80 79 11 f0    	mov    0xf0117980,%edi
f010237a:	89 d6                	mov    %edx,%esi
f010237c:	c1 ee 0c             	shr    $0xc,%esi
f010237f:	39 fe                	cmp    %edi,%esi
f0102381:	72 20                	jb     f01023a3 <mem_init+0x1203>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102383:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0102387:	c7 44 24 08 30 45 10 	movl   $0xf0104530,0x8(%esp)
f010238e:	f0 
f010238f:	c7 44 24 04 5e 03 00 	movl   $0x35e,0x4(%esp)
f0102396:	00 
f0102397:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010239e:	e8 f1 dc ff ff       	call   f0100094 <_panic>
	assert(ptep == ptep1 + PTX(va));
f01023a3:	81 ea fc ff ff 0f    	sub    $0xffffffc,%edx
f01023a9:	39 d0                	cmp    %edx,%eax
f01023ab:	74 24                	je     f01023d1 <mem_init+0x1231>
f01023ad:	c7 44 24 0c 62 4e 10 	movl   $0xf0104e62,0xc(%esp)
f01023b4:	f0 
f01023b5:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01023bc:	f0 
f01023bd:	c7 44 24 04 5f 03 00 	movl   $0x35f,0x4(%esp)
f01023c4:	00 
f01023c5:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01023cc:	e8 c3 dc ff ff       	call   f0100094 <_panic>
	kern_pgdir[PDX(va)] = 0;
f01023d1:	c7 41 04 00 00 00 00 	movl   $0x0,0x4(%ecx)
	pp0->pp_ref = 0;
f01023d8:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01023de:	89 d8                	mov    %ebx,%eax
f01023e0:	2b 05 88 79 11 f0    	sub    0xf0117988,%eax
f01023e6:	c1 f8 03             	sar    $0x3,%eax
f01023e9:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01023ec:	89 c2                	mov    %eax,%edx
f01023ee:	c1 ea 0c             	shr    $0xc,%edx
f01023f1:	39 d7                	cmp    %edx,%edi
f01023f3:	77 20                	ja     f0102415 <mem_init+0x1275>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01023f5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01023f9:	c7 44 24 08 30 45 10 	movl   $0xf0104530,0x8(%esp)
f0102400:	f0 
f0102401:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f0102408:	00 
f0102409:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f0102410:	e8 7f dc ff ff       	call   f0100094 <_panic>

	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
f0102415:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010241c:	00 
f010241d:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
f0102424:	00 
	return (void *)(pa + KERNBASE);
f0102425:	2d 00 00 00 10       	sub    $0x10000000,%eax
f010242a:	89 04 24             	mov    %eax,(%esp)
f010242d:	e8 6d 16 00 00       	call   f0103a9f <memset>
	page_free(pp0);
f0102432:	89 1c 24             	mov    %ebx,(%esp)
f0102435:	e8 b8 ea ff ff       	call   f0100ef2 <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f010243a:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0102441:	00 
f0102442:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0102449:	00 
f010244a:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f010244f:	89 04 24             	mov    %eax,(%esp)
f0102452:	e8 d3 ea ff ff       	call   f0100f2a <pgdir_walk>
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102457:	89 da                	mov    %ebx,%edx
f0102459:	2b 15 88 79 11 f0    	sub    0xf0117988,%edx
f010245f:	c1 fa 03             	sar    $0x3,%edx
f0102462:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102465:	89 d0                	mov    %edx,%eax
f0102467:	c1 e8 0c             	shr    $0xc,%eax
f010246a:	3b 05 80 79 11 f0    	cmp    0xf0117980,%eax
f0102470:	72 20                	jb     f0102492 <mem_init+0x12f2>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102472:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0102476:	c7 44 24 08 30 45 10 	movl   $0xf0104530,0x8(%esp)
f010247d:	f0 
f010247e:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f0102485:	00 
f0102486:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f010248d:	e8 02 dc ff ff       	call   f0100094 <_panic>
	return (void *)(pa + KERNBASE);
f0102492:	8d 82 00 00 00 f0    	lea    -0x10000000(%edx),%eax
	ptep = (pte_t *) page2kva(pp0);
f0102498:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	for(i=0; i<NPTENTRIES; i++)
		assert((ptep[i] & PTE_P) == 0);
f010249b:	f6 82 00 00 00 f0 01 	testb  $0x1,-0x10000000(%edx)
f01024a2:	75 13                	jne    f01024b7 <mem_init+0x1317>
f01024a4:	8d 82 04 00 00 f0    	lea    -0xffffffc(%edx),%eax
f01024aa:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f01024b0:	8b 38                	mov    (%eax),%edi
f01024b2:	83 e7 01             	and    $0x1,%edi
f01024b5:	74 24                	je     f01024db <mem_init+0x133b>
f01024b7:	c7 44 24 0c 7a 4e 10 	movl   $0xf0104e7a,0xc(%esp)
f01024be:	f0 
f01024bf:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01024c6:	f0 
f01024c7:	c7 44 24 04 69 03 00 	movl   $0x369,0x4(%esp)
f01024ce:	00 
f01024cf:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01024d6:	e8 b9 db ff ff       	call   f0100094 <_panic>
f01024db:	83 c0 04             	add    $0x4,%eax
	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
	page_free(pp0);
	pgdir_walk(kern_pgdir, 0x0, 1);
	ptep = (pte_t *) page2kva(pp0);
	for(i=0; i<NPTENTRIES; i++)
f01024de:	39 d0                	cmp    %edx,%eax
f01024e0:	75 ce                	jne    f01024b0 <mem_init+0x1310>
		assert((ptep[i] & PTE_P) == 0);
	kern_pgdir[0] = 0;
f01024e2:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f01024e7:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f01024ed:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// give free list back
	page_free_list = fl;
f01024f3:	8b 45 cc             	mov    -0x34(%ebp),%eax
f01024f6:	a3 5c 75 11 f0       	mov    %eax,0xf011755c

	// free the pages we took
	page_free(pp0);
f01024fb:	89 1c 24             	mov    %ebx,(%esp)
f01024fe:	e8 ef e9 ff ff       	call   f0100ef2 <page_free>
	page_free(pp1);
f0102503:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102506:	89 04 24             	mov    %eax,(%esp)
f0102509:	e8 e4 e9 ff ff       	call   f0100ef2 <page_free>
	page_free(pp2);
f010250e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102511:	89 04 24             	mov    %eax,(%esp)
f0102514:	e8 d9 e9 ff ff       	call   f0100ef2 <page_free>

	cprintf("check_page() succeeded!\n");
f0102519:	c7 04 24 91 4e 10 f0 	movl   $0xf0104e91,(%esp)
f0102520:	e8 e0 09 00 00       	call   f0102f05 <cprintf>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f0102525:	8b 0d 80 79 11 f0    	mov    0xf0117980,%ecx
f010252b:	8d 04 cd ff 0f 00 00 	lea    0xfff(,%ecx,8),%eax
f0102532:	89 c2                	mov    %eax,%edx
f0102534:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
f010253a:	39 d0                	cmp    %edx,%eax
f010253c:	0f 84 84 08 00 00    	je     f0102dc6 <mem_init+0x1c26>
		page_insert(kern_pgdir, pa2page(PADDR(pages) + i), (void *)(UPAGES + i), PTE_U);
f0102542:	a1 88 79 11 f0       	mov    0xf0117988,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102547:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010254c:	76 21                	jbe    f010256f <mem_init+0x13cf>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f010254e:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102554:	c1 ea 0c             	shr    $0xc,%edx
f0102557:	39 ca                	cmp    %ecx,%edx
f0102559:	72 62                	jb     f01025bd <mem_init+0x141d>
f010255b:	eb 44                	jmp    f01025a1 <mem_init+0x1401>
f010255d:	8d bb 00 10 00 ef    	lea    -0x10fff000(%ebx),%edi
f0102563:	a1 88 79 11 f0       	mov    0xf0117988,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102568:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010256d:	77 20                	ja     f010258f <mem_init+0x13ef>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010256f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102573:	c7 44 24 08 74 46 10 	movl   $0xf0104674,0x8(%esp)
f010257a:	f0 
f010257b:	c7 44 24 04 b7 00 00 	movl   $0xb7,0x4(%esp)
f0102582:	00 
f0102583:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010258a:	e8 05 db ff ff       	call   f0100094 <_panic>
f010258f:	8d 94 18 00 10 00 10 	lea    0x10001000(%eax,%ebx,1),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102596:	c1 ea 0c             	shr    $0xc,%edx
f0102599:	39 d6                	cmp    %edx,%esi
f010259b:	76 04                	jbe    f01025a1 <mem_init+0x1401>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f010259d:	89 cb                	mov    %ecx,%ebx
f010259f:	eb 2b                	jmp    f01025cc <mem_init+0x142c>
		panic("pa2page called with invalid pa");
f01025a1:	c7 44 24 08 18 46 10 	movl   $0xf0104618,0x8(%esp)
f01025a8:	f0 
f01025a9:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
f01025b0:	00 
f01025b1:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f01025b8:	e8 d7 da ff ff       	call   f0100094 <_panic>
		page_insert(kern_pgdir, pa2page(PADDR(pages) + i), (void *)(UPAGES + i), PTE_U);
f01025bd:	b9 00 00 00 ef       	mov    $0xef000000,%ecx
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f01025c2:	bb 00 00 00 00       	mov    $0x0,%ebx
f01025c7:	89 7d d4             	mov    %edi,-0x2c(%ebp)
f01025ca:	89 cf                	mov    %ecx,%edi
		page_insert(kern_pgdir, pa2page(PADDR(pages) + i), (void *)(UPAGES + i), PTE_U);
f01025cc:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f01025d3:	00 
f01025d4:	89 7c 24 08          	mov    %edi,0x8(%esp)
	return &pages[PGNUM(pa)];
f01025d8:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f01025db:	89 44 24 04          	mov    %eax,0x4(%esp)
f01025df:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f01025e4:	89 04 24             	mov    %eax,(%esp)
f01025e7:	e8 f3 ea ff ff       	call   f01010df <page_insert>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f01025ec:	8d 8b 00 10 00 00    	lea    0x1000(%ebx),%ecx
f01025f2:	8b 35 80 79 11 f0    	mov    0xf0117980,%esi
f01025f8:	8d 04 f5 ff 0f 00 00 	lea    0xfff(,%esi,8),%eax
f01025ff:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102604:	39 c8                	cmp    %ecx,%eax
f0102606:	0f 87 51 ff ff ff    	ja     f010255d <mem_init+0x13bd>
f010260c:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f010260f:	e9 b2 07 00 00       	jmp    f0102dc6 <mem_init+0x1c26>
static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102614:	b8 00 d0 10 00       	mov    $0x10d000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102619:	c1 e8 0c             	shr    $0xc,%eax
f010261c:	3b 05 80 79 11 f0    	cmp    0xf0117980,%eax
f0102622:	0f 82 d1 07 00 00    	jb     f0102df9 <mem_init+0x1c59>
f0102628:	eb 39                	jmp    f0102663 <mem_init+0x14c3>
f010262a:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010262d:	8d 14 18             	lea    (%eax,%ebx,1),%edx
f0102630:	89 d8                	mov    %ebx,%eax
f0102632:	c1 e8 0c             	shr    $0xc,%eax
f0102635:	3b 05 80 79 11 f0    	cmp    0xf0117980,%eax
f010263b:	72 42                	jb     f010267f <mem_init+0x14df>
f010263d:	eb 24                	jmp    f0102663 <mem_init+0x14c3>

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010263f:	c7 44 24 0c 00 d0 10 	movl   $0xf010d000,0xc(%esp)
f0102646:	f0 
f0102647:	c7 44 24 08 74 46 10 	movl   $0xf0104674,0x8(%esp)
f010264e:	f0 
f010264f:	c7 44 24 04 c5 00 00 	movl   $0xc5,0x4(%esp)
f0102656:	00 
f0102657:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010265e:	e8 31 da ff ff       	call   f0100094 <_panic>

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
f0102663:	c7 44 24 08 18 46 10 	movl   $0xf0104618,0x8(%esp)
f010266a:	f0 
f010266b:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
f0102672:	00 
f0102673:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f010267a:	e8 15 da ff ff       	call   f0100094 <_panic>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		page_insert(kern_pgdir, pa2page(PADDR(bootstack) + i), (void *)(KSTACKTOP-KSTKSIZE + i), PTE_W);
f010267f:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102686:	00 
f0102687:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f010268b:	8b 15 88 79 11 f0    	mov    0xf0117988,%edx
f0102691:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102694:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102698:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f010269d:	89 04 24             	mov    %eax,(%esp)
f01026a0:	e8 3a ea ff ff       	call   f01010df <page_insert>
f01026a5:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	//     * [KSTACKTOP-PTSIZE, KSTACKTOP-KSTKSIZE) -- not backed; so if
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
f01026ab:	39 f3                	cmp    %esi,%ebx
f01026ad:	0f 85 77 ff ff ff    	jne    f010262a <mem_init+0x148a>
f01026b3:	e9 23 07 00 00       	jmp    f0102ddb <mem_init+0x1c3b>
f01026b8:	8d b3 00 10 00 f0    	lea    -0xffff000(%ebx),%esi
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W);
f01026be:	8b 1d 80 79 11 f0    	mov    0xf0117980,%ebx
f01026c4:	89 df                	mov    %ebx,%edi
f01026c6:	c1 e7 0c             	shl    $0xc,%edi
f01026c9:	89 c8                	mov    %ecx,%eax
f01026cb:	ba 00 00 00 00       	mov    $0x0,%edx
f01026d0:	f7 f7                	div    %edi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01026d2:	c1 ea 0c             	shr    $0xc,%edx
f01026d5:	39 d3                	cmp    %edx,%ebx
f01026d7:	77 1c                	ja     f01026f5 <mem_init+0x1555>
		panic("pa2page called with invalid pa");
f01026d9:	c7 44 24 08 18 46 10 	movl   $0xf0104618,0x8(%esp)
f01026e0:	f0 
f01026e1:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
f01026e8:	00 
f01026e9:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f01026f0:	e8 9f d9 ff ff       	call   f0100094 <_panic>
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
f01026f5:	89 cb                	mov    %ecx,%ebx
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W);
f01026f7:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01026fe:	00 
f01026ff:	89 74 24 08          	mov    %esi,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102703:	a1 88 79 11 f0       	mov    0xf0117988,%eax
f0102708:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f010270b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010270f:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f0102714:	89 04 24             	mov    %eax,(%esp)
f0102717:	e8 c3 e9 ff ff       	call   f01010df <page_insert>
		pa2page(i % (npages*PGSIZE))->pp_ref--;                 //this statement is to keep pp_ref == 0 in page_free_list
f010271c:	8b 0d 80 79 11 f0    	mov    0xf0117980,%ecx
f0102722:	89 ce                	mov    %ecx,%esi
f0102724:	c1 e6 0c             	shl    $0xc,%esi
f0102727:	89 d8                	mov    %ebx,%eax
f0102729:	ba 00 00 00 00       	mov    $0x0,%edx
f010272e:	f7 f6                	div    %esi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102730:	c1 ea 0c             	shr    $0xc,%edx
f0102733:	39 d1                	cmp    %edx,%ecx
f0102735:	77 1c                	ja     f0102753 <mem_init+0x15b3>
		panic("pa2page called with invalid pa");
f0102737:	c7 44 24 08 18 46 10 	movl   $0xf0104618,0x8(%esp)
f010273e:	f0 
f010273f:	c7 44 24 04 4b 00 00 	movl   $0x4b,0x4(%esp)
f0102746:	00 
f0102747:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f010274e:	e8 41 d9 ff ff       	call   f0100094 <_panic>
	return &pages[PGNUM(pa)];
f0102753:	a1 88 79 11 f0       	mov    0xf0117988,%eax
f0102758:	66 83 6c d0 04 01    	subw   $0x1,0x4(%eax,%edx,8)
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
f010275e:	8d 8b 00 10 00 00    	lea    0x1000(%ebx),%ecx
f0102764:	81 f9 00 00 00 10    	cmp    $0x10000000,%ecx
f010276a:	0f 85 48 ff ff ff    	jne    f01026b8 <mem_init+0x1518>
check_kern_pgdir(void)
{
	uint32_t i, n;
	pde_t *pgdir;

	pgdir = kern_pgdir;
f0102770:	8b 35 84 79 11 f0    	mov    0xf0117984,%esi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
f0102776:	a1 80 79 11 f0       	mov    0xf0117980,%eax
f010277b:	89 45 d0             	mov    %eax,-0x30(%ebp)
f010277e:	8d 04 c5 ff 0f 00 00 	lea    0xfff(,%eax,8),%eax
	for (i = 0; i < n; i += PGSIZE)
f0102785:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f010278a:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f010278d:	74 7f                	je     f010280e <mem_init+0x166e>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f010278f:	8b 1d 88 79 11 f0    	mov    0xf0117988,%ebx
static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102795:	8d bb 00 00 00 10    	lea    0x10000000(%ebx),%edi
f010279b:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f01027a0:	89 f0                	mov    %esi,%eax
f01027a2:	e8 0d e2 ff ff       	call   f01009b4 <check_va2pa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01027a7:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f01027ad:	77 20                	ja     f01027cf <mem_init+0x162f>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01027af:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f01027b3:	c7 44 24 08 74 46 10 	movl   $0xf0104674,0x8(%esp)
f01027ba:	f0 
f01027bb:	c7 44 24 04 b5 02 00 	movl   $0x2b5,0x4(%esp)
f01027c2:	00 
f01027c3:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01027ca:	e8 c5 d8 ff ff       	call   f0100094 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f01027cf:	ba 00 00 00 00       	mov    $0x0,%edx
f01027d4:	8d 0c 17             	lea    (%edi,%edx,1),%ecx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f01027d7:	39 c8                	cmp    %ecx,%eax
f01027d9:	74 24                	je     f01027ff <mem_init+0x165f>
f01027db:	c7 44 24 0c 84 4a 10 	movl   $0xf0104a84,0xc(%esp)
f01027e2:	f0 
f01027e3:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01027ea:	f0 
f01027eb:	c7 44 24 04 b5 02 00 	movl   $0x2b5,0x4(%esp)
f01027f2:	00 
f01027f3:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01027fa:	e8 95 d8 ff ff       	call   f0100094 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f01027ff:	8d 9a 00 10 00 00    	lea    0x1000(%edx),%ebx
f0102805:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f0102808:	0f 87 60 06 00 00    	ja     f0102e6e <mem_init+0x1cce>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);


	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f010280e:	8b 7d d0             	mov    -0x30(%ebp),%edi
f0102811:	c1 e7 0c             	shl    $0xc,%edi
f0102814:	85 ff                	test   %edi,%edi
f0102816:	0f 84 31 06 00 00    	je     f0102e4d <mem_init+0x1cad>
f010281c:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102821:	8d 93 00 00 00 f0    	lea    -0x10000000(%ebx),%edx
		assert(check_va2pa(pgdir, KERNBASE + i) == i);
f0102827:	89 f0                	mov    %esi,%eax
f0102829:	e8 86 e1 ff ff       	call   f01009b4 <check_va2pa>
f010282e:	39 c3                	cmp    %eax,%ebx
f0102830:	74 24                	je     f0102856 <mem_init+0x16b6>
f0102832:	c7 44 24 0c b8 4a 10 	movl   $0xf0104ab8,0xc(%esp)
f0102839:	f0 
f010283a:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102841:	f0 
f0102842:	c7 44 24 04 ba 02 00 	movl   $0x2ba,0x4(%esp)
f0102849:	00 
f010284a:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102851:	e8 3e d8 ff ff       	call   f0100094 <_panic>
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);


	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102856:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f010285c:	39 fb                	cmp    %edi,%ebx
f010285e:	72 c1                	jb     f0102821 <mem_init+0x1681>
f0102860:	e9 e8 05 00 00       	jmp    f0102e4d <mem_init+0x1cad>
f0102865:	8d 14 1f             	lea    (%edi,%ebx,1),%edx
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check kernel stack
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
f0102868:	39 d0                	cmp    %edx,%eax
f010286a:	74 24                	je     f0102890 <mem_init+0x16f0>
f010286c:	c7 44 24 0c e0 4a 10 	movl   $0xf0104ae0,0xc(%esp)
f0102873:	f0 
f0102874:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f010287b:	f0 
f010287c:	c7 44 24 04 be 02 00 	movl   $0x2be,0x4(%esp)
f0102883:	00 
f0102884:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010288b:	e8 04 d8 ff ff       	call   f0100094 <_panic>
f0102890:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check kernel stack
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102896:	81 fb 00 00 c0 ef    	cmp    $0xefc00000,%ebx
f010289c:	0f 85 9d 05 00 00    	jne    f0102e3f <mem_init+0x1c9f>
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
	assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);
f01028a2:	ba 00 00 80 ef       	mov    $0xef800000,%edx
f01028a7:	89 f0                	mov    %esi,%eax
f01028a9:	e8 06 e1 ff ff       	call   f01009b4 <check_va2pa>
f01028ae:	83 f8 ff             	cmp    $0xffffffff,%eax
f01028b1:	74 24                	je     f01028d7 <mem_init+0x1737>
f01028b3:	c7 44 24 0c 28 4b 10 	movl   $0xf0104b28,0xc(%esp)
f01028ba:	f0 
f01028bb:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f01028c2:	f0 
f01028c3:	c7 44 24 04 bf 02 00 	movl   $0x2bf,0x4(%esp)
f01028ca:	00 
f01028cb:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01028d2:	e8 bd d7 ff ff       	call   f0100094 <_panic>
f01028d7:	b8 00 00 00 00       	mov    $0x0,%eax

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
		switch (i) {
f01028dc:	8d 90 44 fc ff ff    	lea    -0x3bc(%eax),%edx
f01028e2:	83 fa 02             	cmp    $0x2,%edx
f01028e5:	77 2e                	ja     f0102915 <mem_init+0x1775>
		case PDX(UVPT):
		case PDX(KSTACKTOP-1):
		case PDX(UPAGES):
			assert(pgdir[i] & PTE_P);
f01028e7:	f6 04 86 01          	testb  $0x1,(%esi,%eax,4)
f01028eb:	0f 85 aa 00 00 00    	jne    f010299b <mem_init+0x17fb>
f01028f1:	c7 44 24 0c aa 4e 10 	movl   $0xf0104eaa,0xc(%esp)
f01028f8:	f0 
f01028f9:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102900:	f0 
f0102901:	c7 44 24 04 c7 02 00 	movl   $0x2c7,0x4(%esp)
f0102908:	00 
f0102909:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102910:	e8 7f d7 ff ff       	call   f0100094 <_panic>
			break;
		default:
			if (i >= PDX(KERNBASE)) {
f0102915:	3d bf 03 00 00       	cmp    $0x3bf,%eax
f010291a:	76 55                	jbe    f0102971 <mem_init+0x17d1>
				assert(pgdir[i] & PTE_P);
f010291c:	8b 14 86             	mov    (%esi,%eax,4),%edx
f010291f:	f6 c2 01             	test   $0x1,%dl
f0102922:	75 24                	jne    f0102948 <mem_init+0x17a8>
f0102924:	c7 44 24 0c aa 4e 10 	movl   $0xf0104eaa,0xc(%esp)
f010292b:	f0 
f010292c:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102933:	f0 
f0102934:	c7 44 24 04 cb 02 00 	movl   $0x2cb,0x4(%esp)
f010293b:	00 
f010293c:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102943:	e8 4c d7 ff ff       	call   f0100094 <_panic>
				assert(pgdir[i] & PTE_W);
f0102948:	f6 c2 02             	test   $0x2,%dl
f010294b:	75 4e                	jne    f010299b <mem_init+0x17fb>
f010294d:	c7 44 24 0c bb 4e 10 	movl   $0xf0104ebb,0xc(%esp)
f0102954:	f0 
f0102955:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f010295c:	f0 
f010295d:	c7 44 24 04 cc 02 00 	movl   $0x2cc,0x4(%esp)
f0102964:	00 
f0102965:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f010296c:	e8 23 d7 ff ff       	call   f0100094 <_panic>
			} else
				assert(pgdir[i] == 0);
f0102971:	83 3c 86 00          	cmpl   $0x0,(%esi,%eax,4)
f0102975:	74 24                	je     f010299b <mem_init+0x17fb>
f0102977:	c7 44 24 0c cc 4e 10 	movl   $0xf0104ecc,0xc(%esp)
f010297e:	f0 
f010297f:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102986:	f0 
f0102987:	c7 44 24 04 ce 02 00 	movl   $0x2ce,0x4(%esp)
f010298e:	00 
f010298f:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102996:	e8 f9 d6 ff ff       	call   f0100094 <_panic>
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
	assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
f010299b:	83 c0 01             	add    $0x1,%eax
f010299e:	3d 00 04 00 00       	cmp    $0x400,%eax
f01029a3:	0f 85 33 ff ff ff    	jne    f01028dc <mem_init+0x173c>
			} else
				assert(pgdir[i] == 0);
			break;
		}
	}
	cprintf("check_kern_pgdir() succeeded!\n");
f01029a9:	c7 04 24 58 4b 10 f0 	movl   $0xf0104b58,(%esp)
f01029b0:	e8 50 05 00 00       	call   f0102f05 <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f01029b5:	a1 84 79 11 f0       	mov    0xf0117984,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01029ba:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01029bf:	77 20                	ja     f01029e1 <mem_init+0x1841>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01029c1:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01029c5:	c7 44 24 08 74 46 10 	movl   $0xf0104674,0x8(%esp)
f01029cc:	f0 
f01029cd:	c7 44 24 04 de 00 00 	movl   $0xde,0x4(%esp)
f01029d4:	00 
f01029d5:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f01029dc:	e8 b3 d6 ff ff       	call   f0100094 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01029e1:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f01029e6:	0f 22 d8             	mov    %eax,%cr3

	check_page_free_list(0);
f01029e9:	b8 00 00 00 00       	mov    $0x0,%eax
f01029ee:	e8 30 e0 ff ff       	call   f0100a23 <check_page_free_list>

static __inline uint32_t
rcr0(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr0,%0" : "=r" (val));
f01029f3:	0f 20 c0             	mov    %cr0,%eax

	// entry.S set the really important flags in cr0 (including enabling
	// paging).  Here we configure the rest of the flags that we care about.
	cr0 = rcr0();
	cr0 |= CR0_PE|CR0_PG|CR0_AM|CR0_WP|CR0_NE|CR0_MP;
	cr0 &= ~(CR0_TS|CR0_EM);
f01029f6:	83 e0 f3             	and    $0xfffffff3,%eax
f01029f9:	0d 23 00 05 80       	or     $0x80050023,%eax
}

static __inline void
lcr0(uint32_t val)
{
	__asm __volatile("movl %0,%%cr0" : : "r" (val));
f01029fe:	0f 22 c0             	mov    %eax,%cr0
	uintptr_t va;
	int i;

	// check that we can read and write installed pages
	pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0102a01:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102a08:	e8 60 e4 ff ff       	call   f0100e6d <page_alloc>
f0102a0d:	89 c3                	mov    %eax,%ebx
f0102a0f:	85 c0                	test   %eax,%eax
f0102a11:	75 24                	jne    f0102a37 <mem_init+0x1897>
f0102a13:	c7 44 24 0c e9 4c 10 	movl   $0xf0104ce9,0xc(%esp)
f0102a1a:	f0 
f0102a1b:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102a22:	f0 
f0102a23:	c7 44 24 04 84 03 00 	movl   $0x384,0x4(%esp)
f0102a2a:	00 
f0102a2b:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102a32:	e8 5d d6 ff ff       	call   f0100094 <_panic>
	assert((pp1 = page_alloc(0)));
f0102a37:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102a3e:	e8 2a e4 ff ff       	call   f0100e6d <page_alloc>
f0102a43:	89 c7                	mov    %eax,%edi
f0102a45:	85 c0                	test   %eax,%eax
f0102a47:	75 24                	jne    f0102a6d <mem_init+0x18cd>
f0102a49:	c7 44 24 0c ff 4c 10 	movl   $0xf0104cff,0xc(%esp)
f0102a50:	f0 
f0102a51:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102a58:	f0 
f0102a59:	c7 44 24 04 85 03 00 	movl   $0x385,0x4(%esp)
f0102a60:	00 
f0102a61:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102a68:	e8 27 d6 ff ff       	call   f0100094 <_panic>
	assert((pp2 = page_alloc(0)));
f0102a6d:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102a74:	e8 f4 e3 ff ff       	call   f0100e6d <page_alloc>
f0102a79:	89 c6                	mov    %eax,%esi
f0102a7b:	85 c0                	test   %eax,%eax
f0102a7d:	75 24                	jne    f0102aa3 <mem_init+0x1903>
f0102a7f:	c7 44 24 0c 15 4d 10 	movl   $0xf0104d15,0xc(%esp)
f0102a86:	f0 
f0102a87:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102a8e:	f0 
f0102a8f:	c7 44 24 04 86 03 00 	movl   $0x386,0x4(%esp)
f0102a96:	00 
f0102a97:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102a9e:	e8 f1 d5 ff ff       	call   f0100094 <_panic>
	page_free(pp0);
f0102aa3:	89 1c 24             	mov    %ebx,(%esp)
f0102aa6:	e8 47 e4 ff ff       	call   f0100ef2 <page_free>
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102aab:	89 f8                	mov    %edi,%eax
f0102aad:	2b 05 88 79 11 f0    	sub    0xf0117988,%eax
f0102ab3:	c1 f8 03             	sar    $0x3,%eax
f0102ab6:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102ab9:	89 c2                	mov    %eax,%edx
f0102abb:	c1 ea 0c             	shr    $0xc,%edx
f0102abe:	3b 15 80 79 11 f0    	cmp    0xf0117980,%edx
f0102ac4:	72 20                	jb     f0102ae6 <mem_init+0x1946>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102ac6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102aca:	c7 44 24 08 30 45 10 	movl   $0xf0104530,0x8(%esp)
f0102ad1:	f0 
f0102ad2:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f0102ad9:	00 
f0102ada:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f0102ae1:	e8 ae d5 ff ff       	call   f0100094 <_panic>
	memset(page2kva(pp1), 1, PGSIZE);
f0102ae6:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102aed:	00 
f0102aee:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f0102af5:	00 
	return (void *)(pa + KERNBASE);
f0102af6:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102afb:	89 04 24             	mov    %eax,(%esp)
f0102afe:	e8 9c 0f 00 00       	call   f0103a9f <memset>
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102b03:	89 f0                	mov    %esi,%eax
f0102b05:	2b 05 88 79 11 f0    	sub    0xf0117988,%eax
f0102b0b:	c1 f8 03             	sar    $0x3,%eax
f0102b0e:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102b11:	89 c2                	mov    %eax,%edx
f0102b13:	c1 ea 0c             	shr    $0xc,%edx
f0102b16:	3b 15 80 79 11 f0    	cmp    0xf0117980,%edx
f0102b1c:	72 20                	jb     f0102b3e <mem_init+0x199e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102b1e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102b22:	c7 44 24 08 30 45 10 	movl   $0xf0104530,0x8(%esp)
f0102b29:	f0 
f0102b2a:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f0102b31:	00 
f0102b32:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f0102b39:	e8 56 d5 ff ff       	call   f0100094 <_panic>
	memset(page2kva(pp2), 2, PGSIZE);
f0102b3e:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102b45:	00 
f0102b46:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102b4d:	00 
	return (void *)(pa + KERNBASE);
f0102b4e:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102b53:	89 04 24             	mov    %eax,(%esp)
f0102b56:	e8 44 0f 00 00       	call   f0103a9f <memset>
	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f0102b5b:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102b62:	00 
f0102b63:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102b6a:	00 
f0102b6b:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102b6f:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f0102b74:	89 04 24             	mov    %eax,(%esp)
f0102b77:	e8 63 e5 ff ff       	call   f01010df <page_insert>
	assert(pp1->pp_ref == 1);
f0102b7c:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0102b81:	74 24                	je     f0102ba7 <mem_init+0x1a07>
f0102b83:	c7 44 24 0c e6 4d 10 	movl   $0xf0104de6,0xc(%esp)
f0102b8a:	f0 
f0102b8b:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102b92:	f0 
f0102b93:	c7 44 24 04 8b 03 00 	movl   $0x38b,0x4(%esp)
f0102b9a:	00 
f0102b9b:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102ba2:	e8 ed d4 ff ff       	call   f0100094 <_panic>
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
f0102ba7:	81 3d 00 10 00 00 01 	cmpl   $0x1010101,0x1000
f0102bae:	01 01 01 
f0102bb1:	74 24                	je     f0102bd7 <mem_init+0x1a37>
f0102bb3:	c7 44 24 0c 78 4b 10 	movl   $0xf0104b78,0xc(%esp)
f0102bba:	f0 
f0102bbb:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102bc2:	f0 
f0102bc3:	c7 44 24 04 8c 03 00 	movl   $0x38c,0x4(%esp)
f0102bca:	00 
f0102bcb:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102bd2:	e8 bd d4 ff ff       	call   f0100094 <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f0102bd7:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102bde:	00 
f0102bdf:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102be6:	00 
f0102be7:	89 74 24 04          	mov    %esi,0x4(%esp)
f0102beb:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f0102bf0:	89 04 24             	mov    %eax,(%esp)
f0102bf3:	e8 e7 e4 ff ff       	call   f01010df <page_insert>
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
f0102bf8:	81 3d 00 10 00 00 02 	cmpl   $0x2020202,0x1000
f0102bff:	02 02 02 
f0102c02:	74 24                	je     f0102c28 <mem_init+0x1a88>
f0102c04:	c7 44 24 0c 9c 4b 10 	movl   $0xf0104b9c,0xc(%esp)
f0102c0b:	f0 
f0102c0c:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102c13:	f0 
f0102c14:	c7 44 24 04 8e 03 00 	movl   $0x38e,0x4(%esp)
f0102c1b:	00 
f0102c1c:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102c23:	e8 6c d4 ff ff       	call   f0100094 <_panic>
	assert(pp2->pp_ref == 1);
f0102c28:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0102c2d:	74 24                	je     f0102c53 <mem_init+0x1ab3>
f0102c2f:	c7 44 24 0c 08 4e 10 	movl   $0xf0104e08,0xc(%esp)
f0102c36:	f0 
f0102c37:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102c3e:	f0 
f0102c3f:	c7 44 24 04 8f 03 00 	movl   $0x38f,0x4(%esp)
f0102c46:	00 
f0102c47:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102c4e:	e8 41 d4 ff ff       	call   f0100094 <_panic>
	assert(pp1->pp_ref == 0);
f0102c53:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f0102c58:	74 24                	je     f0102c7e <mem_init+0x1ade>
f0102c5a:	c7 44 24 0c 51 4e 10 	movl   $0xf0104e51,0xc(%esp)
f0102c61:	f0 
f0102c62:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102c69:	f0 
f0102c6a:	c7 44 24 04 90 03 00 	movl   $0x390,0x4(%esp)
f0102c71:	00 
f0102c72:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102c79:	e8 16 d4 ff ff       	call   f0100094 <_panic>
	*(uint32_t *)PGSIZE = 0x03030303U;
f0102c7e:	c7 05 00 10 00 00 03 	movl   $0x3030303,0x1000
f0102c85:	03 03 03 
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102c88:	89 f0                	mov    %esi,%eax
f0102c8a:	2b 05 88 79 11 f0    	sub    0xf0117988,%eax
f0102c90:	c1 f8 03             	sar    $0x3,%eax
f0102c93:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102c96:	89 c2                	mov    %eax,%edx
f0102c98:	c1 ea 0c             	shr    $0xc,%edx
f0102c9b:	3b 15 80 79 11 f0    	cmp    0xf0117980,%edx
f0102ca1:	72 20                	jb     f0102cc3 <mem_init+0x1b23>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102ca3:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102ca7:	c7 44 24 08 30 45 10 	movl   $0xf0104530,0x8(%esp)
f0102cae:	f0 
f0102caf:	c7 44 24 04 52 00 00 	movl   $0x52,0x4(%esp)
f0102cb6:	00 
f0102cb7:	c7 04 24 24 4c 10 f0 	movl   $0xf0104c24,(%esp)
f0102cbe:	e8 d1 d3 ff ff       	call   f0100094 <_panic>
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
f0102cc3:	81 b8 00 00 00 f0 03 	cmpl   $0x3030303,-0x10000000(%eax)
f0102cca:	03 03 03 
f0102ccd:	74 24                	je     f0102cf3 <mem_init+0x1b53>
f0102ccf:	c7 44 24 0c c0 4b 10 	movl   $0xf0104bc0,0xc(%esp)
f0102cd6:	f0 
f0102cd7:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102cde:	f0 
f0102cdf:	c7 44 24 04 92 03 00 	movl   $0x392,0x4(%esp)
f0102ce6:	00 
f0102ce7:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102cee:	e8 a1 d3 ff ff       	call   f0100094 <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f0102cf3:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102cfa:	00 
f0102cfb:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f0102d00:	89 04 24             	mov    %eax,(%esp)
f0102d03:	e8 99 e3 ff ff       	call   f01010a1 <page_remove>
	assert(pp2->pp_ref == 0);
f0102d08:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f0102d0d:	74 24                	je     f0102d33 <mem_init+0x1b93>
f0102d0f:	c7 44 24 0c 40 4e 10 	movl   $0xf0104e40,0xc(%esp)
f0102d16:	f0 
f0102d17:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102d1e:	f0 
f0102d1f:	c7 44 24 04 94 03 00 	movl   $0x394,0x4(%esp)
f0102d26:	00 
f0102d27:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102d2e:	e8 61 d3 ff ff       	call   f0100094 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102d33:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f0102d38:	8b 08                	mov    (%eax),%ecx
f0102d3a:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	tlb_invalidate(pde_t *pgdir, void *va);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102d40:	89 da                	mov    %ebx,%edx
f0102d42:	2b 15 88 79 11 f0    	sub    0xf0117988,%edx
f0102d48:	c1 fa 03             	sar    $0x3,%edx
f0102d4b:	c1 e2 0c             	shl    $0xc,%edx
f0102d4e:	39 d1                	cmp    %edx,%ecx
f0102d50:	74 24                	je     f0102d76 <mem_init+0x1bd6>
f0102d52:	c7 44 24 0c 70 47 10 	movl   $0xf0104770,0xc(%esp)
f0102d59:	f0 
f0102d5a:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102d61:	f0 
f0102d62:	c7 44 24 04 97 03 00 	movl   $0x397,0x4(%esp)
f0102d69:	00 
f0102d6a:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102d71:	e8 1e d3 ff ff       	call   f0100094 <_panic>
	kern_pgdir[0] = 0;
f0102d76:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f0102d7c:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102d81:	74 24                	je     f0102da7 <mem_init+0x1c07>
f0102d83:	c7 44 24 0c f7 4d 10 	movl   $0xf0104df7,0xc(%esp)
f0102d8a:	f0 
f0102d8b:	c7 44 24 08 3e 4c 10 	movl   $0xf0104c3e,0x8(%esp)
f0102d92:	f0 
f0102d93:	c7 44 24 04 99 03 00 	movl   $0x399,0x4(%esp)
f0102d9a:	00 
f0102d9b:	c7 04 24 18 4c 10 f0 	movl   $0xf0104c18,(%esp)
f0102da2:	e8 ed d2 ff ff       	call   f0100094 <_panic>
	pp0->pp_ref = 0;
f0102da7:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// free the pages we took
	page_free(pp0);
f0102dad:	89 1c 24             	mov    %ebx,(%esp)
f0102db0:	e8 3d e1 ff ff       	call   f0100ef2 <page_free>

	cprintf("check_page_installed_pgdir() succeeded!\n");
f0102db5:	c7 04 24 ec 4b 10 f0 	movl   $0xf0104bec,(%esp)
f0102dbc:	e8 44 01 00 00       	call   f0102f05 <cprintf>
f0102dc1:	e9 bc 00 00 00       	jmp    f0102e82 <mem_init+0x1ce2>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102dc6:	b8 00 d0 10 f0       	mov    $0xf010d000,%eax
f0102dcb:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102dd0:	0f 86 69 f8 ff ff    	jbe    f010263f <mem_init+0x149f>
f0102dd6:	e9 39 f8 ff ff       	jmp    f0102614 <mem_init+0x1474>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102ddb:	83 3d 80 79 11 f0 00 	cmpl   $0x0,0xf0117980
f0102de2:	0f 84 f1 f8 ff ff    	je     f01026d9 <mem_init+0x1539>
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < 0xFFFFFFFF - KERNBASE; i += PGSIZE) {
		page_insert(kern_pgdir, pa2page(i % (npages*PGSIZE)), (void *)(KERNBASE + i), PTE_W);
f0102de8:	be 00 00 00 f0       	mov    $0xf0000000,%esi
f0102ded:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102df2:	89 fa                	mov    %edi,%edx
f0102df4:	e9 fe f8 ff ff       	jmp    f01026f7 <mem_init+0x1557>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		page_insert(kern_pgdir, pa2page(PADDR(bootstack) + i), (void *)(KSTACKTOP-KSTKSIZE + i), PTE_W);
f0102df9:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102e00:	00 
f0102e01:	c7 44 24 08 00 80 bf 	movl   $0xefbf8000,0x8(%esp)
f0102e08:	ef 
		panic("pa2page called with invalid pa");
	return &pages[PGNUM(pa)];
f0102e09:	8b 15 88 79 11 f0    	mov    0xf0117988,%edx
f0102e0f:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102e12:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102e16:	a1 84 79 11 f0       	mov    0xf0117984,%eax
f0102e1b:	89 04 24             	mov    %eax,(%esp)
f0102e1e:	e8 bc e2 ff ff       	call   f01010df <page_insert>
f0102e23:	bb 00 e0 10 00       	mov    $0x10e000,%ebx
f0102e28:	be 00 50 11 00       	mov    $0x115000,%esi
f0102e2d:	b8 00 80 bf df       	mov    $0xdfbf8000,%eax
f0102e32:	2d 00 d0 10 f0       	sub    $0xf010d000,%eax
f0102e37:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0102e3a:	e9 eb f7 ff ff       	jmp    f010262a <mem_init+0x148a>
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check kernel stack
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
f0102e3f:	89 da                	mov    %ebx,%edx
f0102e41:	89 f0                	mov    %esi,%eax
f0102e43:	e8 6c db ff ff       	call   f01009b4 <check_va2pa>
f0102e48:	e9 18 fa ff ff       	jmp    f0102865 <mem_init+0x16c5>
f0102e4d:	ba 00 80 bf ef       	mov    $0xefbf8000,%edx
f0102e52:	89 f0                	mov    %esi,%eax
f0102e54:	e8 5b db ff ff       	call   f01009b4 <check_va2pa>
f0102e59:	bb 00 80 bf ef       	mov    $0xefbf8000,%ebx
f0102e5e:	b9 00 d0 10 f0       	mov    $0xf010d000,%ecx
f0102e63:	8d b9 00 80 40 20    	lea    0x20408000(%ecx),%edi
f0102e69:	e9 f7 f9 ff ff       	jmp    f0102865 <mem_init+0x16c5>
f0102e6e:	81 ea 00 f0 ff 10    	sub    $0x10fff000,%edx
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102e74:	89 f0                	mov    %esi,%eax
f0102e76:	e8 39 db ff ff       	call   f01009b4 <check_va2pa>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102e7b:	89 da                	mov    %ebx,%edx
f0102e7d:	e9 52 f9 ff ff       	jmp    f01027d4 <mem_init+0x1634>
	cr0 &= ~(CR0_TS|CR0_EM);
	lcr0(cr0);

	// Some more checks, only possible after kern_pgdir is installed.
	check_page_installed_pgdir();
}
f0102e82:	83 c4 3c             	add    $0x3c,%esp
f0102e85:	5b                   	pop    %ebx
f0102e86:	5e                   	pop    %esi
f0102e87:	5f                   	pop    %edi
f0102e88:	5d                   	pop    %ebp
f0102e89:	c3                   	ret    

f0102e8a <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f0102e8a:	55                   	push   %ebp
f0102e8b:	89 e5                	mov    %esp,%ebp
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f0102e8d:	8b 45 0c             	mov    0xc(%ebp),%eax
f0102e90:	0f 01 38             	invlpg (%eax)
	// Flush the entry only if we're modifying the current address space.
	// For now, there is only one address space, so always invalidate.
	invlpg(va);
}
f0102e93:	5d                   	pop    %ebp
f0102e94:	c3                   	ret    

f0102e95 <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0102e95:	55                   	push   %ebp
f0102e96:	89 e5                	mov    %esp,%ebp
f0102e98:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0102e9c:	ba 70 00 00 00       	mov    $0x70,%edx
f0102ea1:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0102ea2:	b2 71                	mov    $0x71,%dl
f0102ea4:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0102ea5:	0f b6 c0             	movzbl %al,%eax
}
f0102ea8:	5d                   	pop    %ebp
f0102ea9:	c3                   	ret    

f0102eaa <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0102eaa:	55                   	push   %ebp
f0102eab:	89 e5                	mov    %esp,%ebp
f0102ead:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0102eb1:	ba 70 00 00 00       	mov    $0x70,%edx
f0102eb6:	ee                   	out    %al,(%dx)
f0102eb7:	b2 71                	mov    $0x71,%dl
f0102eb9:	8b 45 0c             	mov    0xc(%ebp),%eax
f0102ebc:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0102ebd:	5d                   	pop    %ebp
f0102ebe:	c3                   	ret    

f0102ebf <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0102ebf:	55                   	push   %ebp
f0102ec0:	89 e5                	mov    %esp,%ebp
f0102ec2:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0102ec5:	8b 45 08             	mov    0x8(%ebp),%eax
f0102ec8:	89 04 24             	mov    %eax,(%esp)
f0102ecb:	e8 34 d7 ff ff       	call   f0100604 <cputchar>
	*cnt++;
}
f0102ed0:	c9                   	leave  
f0102ed1:	c3                   	ret    

f0102ed2 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0102ed2:	55                   	push   %ebp
f0102ed3:	89 e5                	mov    %esp,%ebp
f0102ed5:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0102ed8:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0102edf:	8b 45 0c             	mov    0xc(%ebp),%eax
f0102ee2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102ee6:	8b 45 08             	mov    0x8(%ebp),%eax
f0102ee9:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102eed:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0102ef0:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102ef4:	c7 04 24 bf 2e 10 f0 	movl   $0xf0102ebf,(%esp)
f0102efb:	e8 84 04 00 00       	call   f0103384 <vprintfmt>
	return cnt;
}
f0102f00:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0102f03:	c9                   	leave  
f0102f04:	c3                   	ret    

f0102f05 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0102f05:	55                   	push   %ebp
f0102f06:	89 e5                	mov    %esp,%ebp
f0102f08:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0102f0b:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0102f0e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102f12:	8b 45 08             	mov    0x8(%ebp),%eax
f0102f15:	89 04 24             	mov    %eax,(%esp)
f0102f18:	e8 b5 ff ff ff       	call   f0102ed2 <vcprintf>
	va_end(ap);

	return cnt;
}
f0102f1d:	c9                   	leave  
f0102f1e:	c3                   	ret    
f0102f1f:	90                   	nop

f0102f20 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0102f20:	55                   	push   %ebp
f0102f21:	89 e5                	mov    %esp,%ebp
f0102f23:	57                   	push   %edi
f0102f24:	56                   	push   %esi
f0102f25:	53                   	push   %ebx
f0102f26:	83 ec 10             	sub    $0x10,%esp
f0102f29:	89 c6                	mov    %eax,%esi
f0102f2b:	89 55 e8             	mov    %edx,-0x18(%ebp)
f0102f2e:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
f0102f31:	8b 7d 08             	mov    0x8(%ebp),%edi
	int l = *region_left, r = *region_right, any_matches = 0;
f0102f34:	8b 1a                	mov    (%edx),%ebx
f0102f36:	8b 01                	mov    (%ecx),%eax
f0102f38:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0102f3b:	c7 45 ec 00 00 00 00 	movl   $0x0,-0x14(%ebp)
	
	while (l <= r) {
f0102f42:	eb 77                	jmp    f0102fbb <stab_binsearch+0x9b>
		int true_m = (l + r) / 2, m = true_m;
f0102f44:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0102f47:	01 d8                	add    %ebx,%eax
f0102f49:	b9 02 00 00 00       	mov    $0x2,%ecx
f0102f4e:	99                   	cltd   
f0102f4f:	f7 f9                	idiv   %ecx
f0102f51:	89 c1                	mov    %eax,%ecx
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0102f53:	eb 01                	jmp    f0102f56 <stab_binsearch+0x36>
			m--;
f0102f55:	49                   	dec    %ecx
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0102f56:	39 d9                	cmp    %ebx,%ecx
f0102f58:	7c 1d                	jl     f0102f77 <stab_binsearch+0x57>
f0102f5a:	6b d1 0c             	imul   $0xc,%ecx,%edx
f0102f5d:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f0102f62:	39 fa                	cmp    %edi,%edx
f0102f64:	75 ef                	jne    f0102f55 <stab_binsearch+0x35>
f0102f66:	89 4d ec             	mov    %ecx,-0x14(%ebp)
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0102f69:	6b d1 0c             	imul   $0xc,%ecx,%edx
f0102f6c:	8b 54 16 08          	mov    0x8(%esi,%edx,1),%edx
f0102f70:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0102f73:	73 18                	jae    f0102f8d <stab_binsearch+0x6d>
f0102f75:	eb 05                	jmp    f0102f7c <stab_binsearch+0x5c>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0102f77:	8d 58 01             	lea    0x1(%eax),%ebx
			continue;
f0102f7a:	eb 3f                	jmp    f0102fbb <stab_binsearch+0x9b>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0102f7c:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f0102f7f:	89 0b                	mov    %ecx,(%ebx)
			l = true_m + 1;
f0102f81:	8d 58 01             	lea    0x1(%eax),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0102f84:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f0102f8b:	eb 2e                	jmp    f0102fbb <stab_binsearch+0x9b>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0102f8d:	39 55 0c             	cmp    %edx,0xc(%ebp)
f0102f90:	73 15                	jae    f0102fa7 <stab_binsearch+0x87>
			*region_right = m - 1;
f0102f92:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0102f95:	48                   	dec    %eax
f0102f96:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0102f99:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0102f9c:	89 01                	mov    %eax,(%ecx)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0102f9e:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f0102fa5:	eb 14                	jmp    f0102fbb <stab_binsearch+0x9b>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0102fa7:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0102faa:	8b 5d ec             	mov    -0x14(%ebp),%ebx
f0102fad:	89 18                	mov    %ebx,(%eax)
			l = m;
			addr++;
f0102faf:	ff 45 0c             	incl   0xc(%ebp)
f0102fb2:	89 cb                	mov    %ecx,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0102fb4:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f0102fbb:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0102fbe:	7e 84                	jle    f0102f44 <stab_binsearch+0x24>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0102fc0:	83 7d ec 00          	cmpl   $0x0,-0x14(%ebp)
f0102fc4:	75 0d                	jne    f0102fd3 <stab_binsearch+0xb3>
		*region_right = *region_left - 1;
f0102fc6:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0102fc9:	8b 00                	mov    (%eax),%eax
f0102fcb:	48                   	dec    %eax
f0102fcc:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0102fcf:	89 07                	mov    %eax,(%edi)
f0102fd1:	eb 22                	jmp    f0102ff5 <stab_binsearch+0xd5>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0102fd3:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0102fd6:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0102fd8:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f0102fdb:	8b 0b                	mov    (%ebx),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0102fdd:	eb 01                	jmp    f0102fe0 <stab_binsearch+0xc0>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
f0102fdf:	48                   	dec    %eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0102fe0:	39 c1                	cmp    %eax,%ecx
f0102fe2:	7d 0c                	jge    f0102ff0 <stab_binsearch+0xd0>
f0102fe4:	6b d0 0c             	imul   $0xc,%eax,%edx
		     l > *region_left && stabs[l].n_type != type;
f0102fe7:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f0102fec:	39 fa                	cmp    %edi,%edx
f0102fee:	75 ef                	jne    f0102fdf <stab_binsearch+0xbf>
		     l--)
			/* do nothing */;
		*region_left = l;
f0102ff0:	8b 7d e8             	mov    -0x18(%ebp),%edi
f0102ff3:	89 07                	mov    %eax,(%edi)
	}
}
f0102ff5:	83 c4 10             	add    $0x10,%esp
f0102ff8:	5b                   	pop    %ebx
f0102ff9:	5e                   	pop    %esi
f0102ffa:	5f                   	pop    %edi
f0102ffb:	5d                   	pop    %ebp
f0102ffc:	c3                   	ret    

f0102ffd <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0102ffd:	55                   	push   %ebp
f0102ffe:	89 e5                	mov    %esp,%ebp
f0103000:	57                   	push   %edi
f0103001:	56                   	push   %esi
f0103002:	53                   	push   %ebx
f0103003:	83 ec 2c             	sub    $0x2c,%esp
f0103006:	8b 75 08             	mov    0x8(%ebp),%esi
f0103009:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f010300c:	c7 03 da 4e 10 f0    	movl   $0xf0104eda,(%ebx)
	info->eip_line = 0;
f0103012:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
	info->eip_fn_name = "<unknown>";
f0103019:	c7 43 08 da 4e 10 f0 	movl   $0xf0104eda,0x8(%ebx)
	info->eip_fn_namelen = 9;
f0103020:	c7 43 0c 09 00 00 00 	movl   $0x9,0xc(%ebx)
	info->eip_fn_addr = addr;
f0103027:	89 73 10             	mov    %esi,0x10(%ebx)
	info->eip_fn_narg = 0;
f010302a:	c7 43 14 00 00 00 00 	movl   $0x0,0x14(%ebx)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0103031:	81 fe ff ff 7f ef    	cmp    $0xef7fffff,%esi
f0103037:	76 12                	jbe    f010304b <debuginfo_eip+0x4e>
		// Can't search for user-level addresses yet!
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0103039:	b8 3a cd 10 f0       	mov    $0xf010cd3a,%eax
f010303e:	3d 2d b0 10 f0       	cmp    $0xf010b02d,%eax
f0103043:	0f 86 8b 01 00 00    	jbe    f01031d4 <debuginfo_eip+0x1d7>
f0103049:	eb 1c                	jmp    f0103067 <debuginfo_eip+0x6a>
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
	} else {
		// Can't search for user-level addresses yet!
  	        panic("User address");
f010304b:	c7 44 24 08 e4 4e 10 	movl   $0xf0104ee4,0x8(%esp)
f0103052:	f0 
f0103053:	c7 44 24 04 7f 00 00 	movl   $0x7f,0x4(%esp)
f010305a:	00 
f010305b:	c7 04 24 f1 4e 10 f0 	movl   $0xf0104ef1,(%esp)
f0103062:	e8 2d d0 ff ff       	call   f0100094 <_panic>
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0103067:	80 3d 39 cd 10 f0 00 	cmpb   $0x0,0xf010cd39
f010306e:	0f 85 67 01 00 00    	jne    f01031db <debuginfo_eip+0x1de>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0103074:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f010307b:	b8 2c b0 10 f0       	mov    $0xf010b02c,%eax
f0103080:	2d 10 51 10 f0       	sub    $0xf0105110,%eax
f0103085:	c1 f8 02             	sar    $0x2,%eax
f0103088:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
f010308e:	83 e8 01             	sub    $0x1,%eax
f0103091:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0103094:	89 74 24 04          	mov    %esi,0x4(%esp)
f0103098:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f010309f:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f01030a2:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f01030a5:	b8 10 51 10 f0       	mov    $0xf0105110,%eax
f01030aa:	e8 71 fe ff ff       	call   f0102f20 <stab_binsearch>
	if (lfile == 0)
f01030af:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01030b2:	85 c0                	test   %eax,%eax
f01030b4:	0f 84 28 01 00 00    	je     f01031e2 <debuginfo_eip+0x1e5>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f01030ba:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f01030bd:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01030c0:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f01030c3:	89 74 24 04          	mov    %esi,0x4(%esp)
f01030c7:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f01030ce:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f01030d1:	8d 55 dc             	lea    -0x24(%ebp),%edx
f01030d4:	b8 10 51 10 f0       	mov    $0xf0105110,%eax
f01030d9:	e8 42 fe ff ff       	call   f0102f20 <stab_binsearch>

	if (lfun <= rfun) {
f01030de:	8b 7d dc             	mov    -0x24(%ebp),%edi
f01030e1:	3b 7d d8             	cmp    -0x28(%ebp),%edi
f01030e4:	7f 2e                	jg     f0103114 <debuginfo_eip+0x117>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f01030e6:	6b c7 0c             	imul   $0xc,%edi,%eax
f01030e9:	8d 90 10 51 10 f0    	lea    -0xfefaef0(%eax),%edx
f01030ef:	8b 80 10 51 10 f0    	mov    -0xfefaef0(%eax),%eax
f01030f5:	b9 3a cd 10 f0       	mov    $0xf010cd3a,%ecx
f01030fa:	81 e9 2d b0 10 f0    	sub    $0xf010b02d,%ecx
f0103100:	39 c8                	cmp    %ecx,%eax
f0103102:	73 08                	jae    f010310c <debuginfo_eip+0x10f>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0103104:	05 2d b0 10 f0       	add    $0xf010b02d,%eax
f0103109:	89 43 08             	mov    %eax,0x8(%ebx)
		info->eip_fn_addr = stabs[lfun].n_value;
f010310c:	8b 42 08             	mov    0x8(%edx),%eax
f010310f:	89 43 10             	mov    %eax,0x10(%ebx)
f0103112:	eb 06                	jmp    f010311a <debuginfo_eip+0x11d>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0103114:	89 73 10             	mov    %esi,0x10(%ebx)
		lline = lfile;
f0103117:	8b 7d e4             	mov    -0x1c(%ebp),%edi
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f010311a:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0103121:	00 
f0103122:	8b 43 08             	mov    0x8(%ebx),%eax
f0103125:	89 04 24             	mov    %eax,(%esp)
f0103128:	e8 47 09 00 00       	call   f0103a74 <strfind>
f010312d:	2b 43 08             	sub    0x8(%ebx),%eax
f0103130:	89 43 0c             	mov    %eax,0xc(%ebx)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0103133:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0103136:	39 cf                	cmp    %ecx,%edi
f0103138:	7c 5c                	jl     f0103196 <debuginfo_eip+0x199>
	       && stabs[lline].n_type != N_SOL
f010313a:	6b c7 0c             	imul   $0xc,%edi,%eax
f010313d:	8d b0 10 51 10 f0    	lea    -0xfefaef0(%eax),%esi
f0103143:	0f b6 56 04          	movzbl 0x4(%esi),%edx
f0103147:	80 fa 84             	cmp    $0x84,%dl
f010314a:	74 2b                	je     f0103177 <debuginfo_eip+0x17a>
f010314c:	05 04 51 10 f0       	add    $0xf0105104,%eax
f0103151:	eb 15                	jmp    f0103168 <debuginfo_eip+0x16b>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0103153:	83 ef 01             	sub    $0x1,%edi
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0103156:	39 cf                	cmp    %ecx,%edi
f0103158:	7c 3c                	jl     f0103196 <debuginfo_eip+0x199>
	       && stabs[lline].n_type != N_SOL
f010315a:	89 c6                	mov    %eax,%esi
f010315c:	83 e8 0c             	sub    $0xc,%eax
f010315f:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0103163:	80 fa 84             	cmp    $0x84,%dl
f0103166:	74 0f                	je     f0103177 <debuginfo_eip+0x17a>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0103168:	80 fa 64             	cmp    $0x64,%dl
f010316b:	75 e6                	jne    f0103153 <debuginfo_eip+0x156>
f010316d:	83 7e 08 00          	cmpl   $0x0,0x8(%esi)
f0103171:	74 e0                	je     f0103153 <debuginfo_eip+0x156>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0103173:	39 f9                	cmp    %edi,%ecx
f0103175:	7f 1f                	jg     f0103196 <debuginfo_eip+0x199>
f0103177:	6b ff 0c             	imul   $0xc,%edi,%edi
f010317a:	8b 87 10 51 10 f0    	mov    -0xfefaef0(%edi),%eax
f0103180:	ba 3a cd 10 f0       	mov    $0xf010cd3a,%edx
f0103185:	81 ea 2d b0 10 f0    	sub    $0xf010b02d,%edx
f010318b:	39 d0                	cmp    %edx,%eax
f010318d:	73 07                	jae    f0103196 <debuginfo_eip+0x199>
		info->eip_file = stabstr + stabs[lline].n_strx;
f010318f:	05 2d b0 10 f0       	add    $0xf010b02d,%eax
f0103194:	89 03                	mov    %eax,(%ebx)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0103196:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103199:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f010319c:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f01031a1:	39 ca                	cmp    %ecx,%edx
f01031a3:	7d 5e                	jge    f0103203 <debuginfo_eip+0x206>
		for (lline = lfun + 1;
f01031a5:	8d 42 01             	lea    0x1(%edx),%eax
f01031a8:	39 c1                	cmp    %eax,%ecx
f01031aa:	7e 3d                	jle    f01031e9 <debuginfo_eip+0x1ec>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f01031ac:	6b d0 0c             	imul   $0xc,%eax,%edx
f01031af:	80 ba 14 51 10 f0 a0 	cmpb   $0xa0,-0xfefaeec(%edx)
f01031b6:	75 38                	jne    f01031f0 <debuginfo_eip+0x1f3>
f01031b8:	81 c2 04 51 10 f0    	add    $0xf0105104,%edx
		     lline++)
			info->eip_fn_narg++;
f01031be:	83 43 14 01          	addl   $0x1,0x14(%ebx)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f01031c2:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f01031c5:	39 c1                	cmp    %eax,%ecx
f01031c7:	7e 2e                	jle    f01031f7 <debuginfo_eip+0x1fa>
f01031c9:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f01031cc:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f01031d0:	74 ec                	je     f01031be <debuginfo_eip+0x1c1>
f01031d2:	eb 2a                	jmp    f01031fe <debuginfo_eip+0x201>
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f01031d4:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01031d9:	eb 28                	jmp    f0103203 <debuginfo_eip+0x206>
f01031db:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01031e0:	eb 21                	jmp    f0103203 <debuginfo_eip+0x206>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f01031e2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01031e7:	eb 1a                	jmp    f0103203 <debuginfo_eip+0x206>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f01031e9:	b8 00 00 00 00       	mov    $0x0,%eax
f01031ee:	eb 13                	jmp    f0103203 <debuginfo_eip+0x206>
f01031f0:	b8 00 00 00 00       	mov    $0x0,%eax
f01031f5:	eb 0c                	jmp    f0103203 <debuginfo_eip+0x206>
f01031f7:	b8 00 00 00 00       	mov    $0x0,%eax
f01031fc:	eb 05                	jmp    f0103203 <debuginfo_eip+0x206>
f01031fe:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0103203:	83 c4 2c             	add    $0x2c,%esp
f0103206:	5b                   	pop    %ebx
f0103207:	5e                   	pop    %esi
f0103208:	5f                   	pop    %edi
f0103209:	5d                   	pop    %ebp
f010320a:	c3                   	ret    
f010320b:	66 90                	xchg   %ax,%ax
f010320d:	66 90                	xchg   %ax,%ax
f010320f:	90                   	nop

f0103210 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0103210:	55                   	push   %ebp
f0103211:	89 e5                	mov    %esp,%ebp
f0103213:	57                   	push   %edi
f0103214:	56                   	push   %esi
f0103215:	53                   	push   %ebx
f0103216:	83 ec 3c             	sub    $0x3c,%esp
f0103219:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010321c:	89 d7                	mov    %edx,%edi
f010321e:	8b 45 08             	mov    0x8(%ebp),%eax
f0103221:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0103224:	8b 75 0c             	mov    0xc(%ebp),%esi
f0103227:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f010322a:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f010322d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0103232:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103235:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0103238:	39 f1                	cmp    %esi,%ecx
f010323a:	72 14                	jb     f0103250 <printnum+0x40>
f010323c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f010323f:	76 0f                	jbe    f0103250 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0103241:	8b 45 14             	mov    0x14(%ebp),%eax
f0103244:	8d 70 ff             	lea    -0x1(%eax),%esi
f0103247:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f010324a:	85 f6                	test   %esi,%esi
f010324c:	7f 60                	jg     f01032ae <printnum+0x9e>
f010324e:	eb 72                	jmp    f01032c2 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0103250:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0103253:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0103257:	8b 4d 14             	mov    0x14(%ebp),%ecx
f010325a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f010325d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0103261:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103265:	8b 44 24 08          	mov    0x8(%esp),%eax
f0103269:	8b 54 24 0c          	mov    0xc(%esp),%edx
f010326d:	89 c3                	mov    %eax,%ebx
f010326f:	89 d6                	mov    %edx,%esi
f0103271:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103274:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0103277:	89 54 24 08          	mov    %edx,0x8(%esp)
f010327b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f010327f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103282:	89 04 24             	mov    %eax,(%esp)
f0103285:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0103288:	89 44 24 04          	mov    %eax,0x4(%esp)
f010328c:	e8 4f 0a 00 00       	call   f0103ce0 <__udivdi3>
f0103291:	89 d9                	mov    %ebx,%ecx
f0103293:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0103297:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010329b:	89 04 24             	mov    %eax,(%esp)
f010329e:	89 54 24 04          	mov    %edx,0x4(%esp)
f01032a2:	89 fa                	mov    %edi,%edx
f01032a4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01032a7:	e8 64 ff ff ff       	call   f0103210 <printnum>
f01032ac:	eb 14                	jmp    f01032c2 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f01032ae:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01032b2:	8b 45 18             	mov    0x18(%ebp),%eax
f01032b5:	89 04 24             	mov    %eax,(%esp)
f01032b8:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f01032ba:	83 ee 01             	sub    $0x1,%esi
f01032bd:	75 ef                	jne    f01032ae <printnum+0x9e>
f01032bf:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f01032c2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01032c6:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01032ca:	8b 45 d8             	mov    -0x28(%ebp),%eax
f01032cd:	8b 55 dc             	mov    -0x24(%ebp),%edx
f01032d0:	89 44 24 08          	mov    %eax,0x8(%esp)
f01032d4:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01032d8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01032db:	89 04 24             	mov    %eax,(%esp)
f01032de:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01032e1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01032e5:	e8 26 0b 00 00       	call   f0103e10 <__umoddi3>
f01032ea:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01032ee:	0f be 80 ff 4e 10 f0 	movsbl -0xfefb101(%eax),%eax
f01032f5:	89 04 24             	mov    %eax,(%esp)
f01032f8:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01032fb:	ff d0                	call   *%eax
}
f01032fd:	83 c4 3c             	add    $0x3c,%esp
f0103300:	5b                   	pop    %ebx
f0103301:	5e                   	pop    %esi
f0103302:	5f                   	pop    %edi
f0103303:	5d                   	pop    %ebp
f0103304:	c3                   	ret    

f0103305 <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0103305:	55                   	push   %ebp
f0103306:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0103308:	83 fa 01             	cmp    $0x1,%edx
f010330b:	7e 0e                	jle    f010331b <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f010330d:	8b 10                	mov    (%eax),%edx
f010330f:	8d 4a 08             	lea    0x8(%edx),%ecx
f0103312:	89 08                	mov    %ecx,(%eax)
f0103314:	8b 02                	mov    (%edx),%eax
f0103316:	8b 52 04             	mov    0x4(%edx),%edx
f0103319:	eb 22                	jmp    f010333d <getuint+0x38>
	else if (lflag)
f010331b:	85 d2                	test   %edx,%edx
f010331d:	74 10                	je     f010332f <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f010331f:	8b 10                	mov    (%eax),%edx
f0103321:	8d 4a 04             	lea    0x4(%edx),%ecx
f0103324:	89 08                	mov    %ecx,(%eax)
f0103326:	8b 02                	mov    (%edx),%eax
f0103328:	ba 00 00 00 00       	mov    $0x0,%edx
f010332d:	eb 0e                	jmp    f010333d <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f010332f:	8b 10                	mov    (%eax),%edx
f0103331:	8d 4a 04             	lea    0x4(%edx),%ecx
f0103334:	89 08                	mov    %ecx,(%eax)
f0103336:	8b 02                	mov    (%edx),%eax
f0103338:	ba 00 00 00 00       	mov    $0x0,%edx
}
f010333d:	5d                   	pop    %ebp
f010333e:	c3                   	ret    

f010333f <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f010333f:	55                   	push   %ebp
f0103340:	89 e5                	mov    %esp,%ebp
f0103342:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0103345:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0103349:	8b 10                	mov    (%eax),%edx
f010334b:	3b 50 04             	cmp    0x4(%eax),%edx
f010334e:	73 0a                	jae    f010335a <sprintputch+0x1b>
		*b->buf++ = ch;
f0103350:	8d 4a 01             	lea    0x1(%edx),%ecx
f0103353:	89 08                	mov    %ecx,(%eax)
f0103355:	8b 45 08             	mov    0x8(%ebp),%eax
f0103358:	88 02                	mov    %al,(%edx)
}
f010335a:	5d                   	pop    %ebp
f010335b:	c3                   	ret    

f010335c <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f010335c:	55                   	push   %ebp
f010335d:	89 e5                	mov    %esp,%ebp
f010335f:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0103362:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0103365:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103369:	8b 45 10             	mov    0x10(%ebp),%eax
f010336c:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103370:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103373:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103377:	8b 45 08             	mov    0x8(%ebp),%eax
f010337a:	89 04 24             	mov    %eax,(%esp)
f010337d:	e8 02 00 00 00       	call   f0103384 <vprintfmt>
	va_end(ap);
}
f0103382:	c9                   	leave  
f0103383:	c3                   	ret    

f0103384 <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f0103384:	55                   	push   %ebp
f0103385:	89 e5                	mov    %esp,%ebp
f0103387:	57                   	push   %edi
f0103388:	56                   	push   %esi
f0103389:	53                   	push   %ebx
f010338a:	83 ec 3c             	sub    $0x3c,%esp
f010338d:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0103390:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0103393:	eb 18                	jmp    f01033ad <vprintfmt+0x29>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f0103395:	85 c0                	test   %eax,%eax
f0103397:	0f 84 c3 03 00 00    	je     f0103760 <vprintfmt+0x3dc>
				return;
			putch(ch, putdat);
f010339d:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01033a1:	89 04 24             	mov    %eax,(%esp)
f01033a4:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01033a7:	89 f3                	mov    %esi,%ebx
f01033a9:	eb 02                	jmp    f01033ad <vprintfmt+0x29>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f01033ab:	89 f3                	mov    %esi,%ebx
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01033ad:	8d 73 01             	lea    0x1(%ebx),%esi
f01033b0:	0f b6 03             	movzbl (%ebx),%eax
f01033b3:	83 f8 25             	cmp    $0x25,%eax
f01033b6:	75 dd                	jne    f0103395 <vprintfmt+0x11>
f01033b8:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f01033bc:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f01033c3:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f01033ca:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f01033d1:	ba 00 00 00 00       	mov    $0x0,%edx
f01033d6:	eb 1d                	jmp    f01033f5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01033d8:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f01033da:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f01033de:	eb 15                	jmp    f01033f5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01033e0:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f01033e2:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f01033e6:	eb 0d                	jmp    f01033f5 <vprintfmt+0x71>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f01033e8:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01033eb:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01033ee:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01033f5:	8d 5e 01             	lea    0x1(%esi),%ebx
f01033f8:	0f b6 06             	movzbl (%esi),%eax
f01033fb:	0f b6 c8             	movzbl %al,%ecx
f01033fe:	83 e8 23             	sub    $0x23,%eax
f0103401:	3c 55                	cmp    $0x55,%al
f0103403:	0f 87 2f 03 00 00    	ja     f0103738 <vprintfmt+0x3b4>
f0103409:	0f b6 c0             	movzbl %al,%eax
f010340c:	ff 24 85 8c 4f 10 f0 	jmp    *-0xfefb074(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0103413:	8d 41 d0             	lea    -0x30(%ecx),%eax
f0103416:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0103419:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f010341d:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0103420:	83 f9 09             	cmp    $0x9,%ecx
f0103423:	77 50                	ja     f0103475 <vprintfmt+0xf1>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103425:	89 de                	mov    %ebx,%esi
f0103427:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f010342a:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f010342d:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0103430:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0103434:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0103437:	8d 58 d0             	lea    -0x30(%eax),%ebx
f010343a:	83 fb 09             	cmp    $0x9,%ebx
f010343d:	76 eb                	jbe    f010342a <vprintfmt+0xa6>
f010343f:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0103442:	eb 33                	jmp    f0103477 <vprintfmt+0xf3>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0103444:	8b 45 14             	mov    0x14(%ebp),%eax
f0103447:	8d 48 04             	lea    0x4(%eax),%ecx
f010344a:	89 4d 14             	mov    %ecx,0x14(%ebp)
f010344d:	8b 00                	mov    (%eax),%eax
f010344f:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103452:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0103454:	eb 21                	jmp    f0103477 <vprintfmt+0xf3>
f0103456:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0103459:	85 c9                	test   %ecx,%ecx
f010345b:	b8 00 00 00 00       	mov    $0x0,%eax
f0103460:	0f 49 c1             	cmovns %ecx,%eax
f0103463:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103466:	89 de                	mov    %ebx,%esi
f0103468:	eb 8b                	jmp    f01033f5 <vprintfmt+0x71>
f010346a:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f010346c:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f0103473:	eb 80                	jmp    f01033f5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103475:	89 de                	mov    %ebx,%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0103477:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f010347b:	0f 89 74 ff ff ff    	jns    f01033f5 <vprintfmt+0x71>
f0103481:	e9 62 ff ff ff       	jmp    f01033e8 <vprintfmt+0x64>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0103486:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103489:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f010348b:	e9 65 ff ff ff       	jmp    f01033f5 <vprintfmt+0x71>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f0103490:	8b 45 14             	mov    0x14(%ebp),%eax
f0103493:	8d 50 04             	lea    0x4(%eax),%edx
f0103496:	89 55 14             	mov    %edx,0x14(%ebp)
f0103499:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010349d:	8b 00                	mov    (%eax),%eax
f010349f:	89 04 24             	mov    %eax,(%esp)
f01034a2:	ff 55 08             	call   *0x8(%ebp)
			break;
f01034a5:	e9 03 ff ff ff       	jmp    f01033ad <vprintfmt+0x29>

		// error message
		case 'e':
			err = va_arg(ap, int);
f01034aa:	8b 45 14             	mov    0x14(%ebp),%eax
f01034ad:	8d 50 04             	lea    0x4(%eax),%edx
f01034b0:	89 55 14             	mov    %edx,0x14(%ebp)
f01034b3:	8b 00                	mov    (%eax),%eax
f01034b5:	99                   	cltd   
f01034b6:	31 d0                	xor    %edx,%eax
f01034b8:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f01034ba:	83 f8 06             	cmp    $0x6,%eax
f01034bd:	7f 0b                	jg     f01034ca <vprintfmt+0x146>
f01034bf:	8b 14 85 e4 50 10 f0 	mov    -0xfefaf1c(,%eax,4),%edx
f01034c6:	85 d2                	test   %edx,%edx
f01034c8:	75 20                	jne    f01034ea <vprintfmt+0x166>
				printfmt(putch, putdat, "error %d", err);
f01034ca:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01034ce:	c7 44 24 08 17 4f 10 	movl   $0xf0104f17,0x8(%esp)
f01034d5:	f0 
f01034d6:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01034da:	8b 45 08             	mov    0x8(%ebp),%eax
f01034dd:	89 04 24             	mov    %eax,(%esp)
f01034e0:	e8 77 fe ff ff       	call   f010335c <printfmt>
f01034e5:	e9 c3 fe ff ff       	jmp    f01033ad <vprintfmt+0x29>
			else
				printfmt(putch, putdat, "%s", p);
f01034ea:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01034ee:	c7 44 24 08 50 4c 10 	movl   $0xf0104c50,0x8(%esp)
f01034f5:	f0 
f01034f6:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01034fa:	8b 45 08             	mov    0x8(%ebp),%eax
f01034fd:	89 04 24             	mov    %eax,(%esp)
f0103500:	e8 57 fe ff ff       	call   f010335c <printfmt>
f0103505:	e9 a3 fe ff ff       	jmp    f01033ad <vprintfmt+0x29>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010350a:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f010350d:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0103510:	8b 45 14             	mov    0x14(%ebp),%eax
f0103513:	8d 50 04             	lea    0x4(%eax),%edx
f0103516:	89 55 14             	mov    %edx,0x14(%ebp)
f0103519:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f010351b:	85 c0                	test   %eax,%eax
f010351d:	ba 10 4f 10 f0       	mov    $0xf0104f10,%edx
f0103522:	0f 45 d0             	cmovne %eax,%edx
f0103525:	89 55 d0             	mov    %edx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f0103528:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f010352c:	74 04                	je     f0103532 <vprintfmt+0x1ae>
f010352e:	85 f6                	test   %esi,%esi
f0103530:	7f 19                	jg     f010354b <vprintfmt+0x1c7>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0103532:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103535:	8d 70 01             	lea    0x1(%eax),%esi
f0103538:	0f b6 10             	movzbl (%eax),%edx
f010353b:	0f be c2             	movsbl %dl,%eax
f010353e:	85 c0                	test   %eax,%eax
f0103540:	0f 85 95 00 00 00    	jne    f01035db <vprintfmt+0x257>
f0103546:	e9 85 00 00 00       	jmp    f01035d0 <vprintfmt+0x24c>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f010354b:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f010354f:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103552:	89 04 24             	mov    %eax,(%esp)
f0103555:	e8 88 03 00 00       	call   f01038e2 <strnlen>
f010355a:	29 c6                	sub    %eax,%esi
f010355c:	89 f0                	mov    %esi,%eax
f010355e:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0103561:	85 f6                	test   %esi,%esi
f0103563:	7e cd                	jle    f0103532 <vprintfmt+0x1ae>
					putch(padc, putdat);
f0103565:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0103569:	89 5d 10             	mov    %ebx,0x10(%ebp)
f010356c:	89 c3                	mov    %eax,%ebx
f010356e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103572:	89 34 24             	mov    %esi,(%esp)
f0103575:	ff 55 08             	call   *0x8(%ebp)
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0103578:	83 eb 01             	sub    $0x1,%ebx
f010357b:	75 f1                	jne    f010356e <vprintfmt+0x1ea>
f010357d:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0103580:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0103583:	eb ad                	jmp    f0103532 <vprintfmt+0x1ae>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f0103585:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0103589:	74 1e                	je     f01035a9 <vprintfmt+0x225>
f010358b:	0f be d2             	movsbl %dl,%edx
f010358e:	83 ea 20             	sub    $0x20,%edx
f0103591:	83 fa 5e             	cmp    $0x5e,%edx
f0103594:	76 13                	jbe    f01035a9 <vprintfmt+0x225>
					putch('?', putdat);
f0103596:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103599:	89 44 24 04          	mov    %eax,0x4(%esp)
f010359d:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f01035a4:	ff 55 08             	call   *0x8(%ebp)
f01035a7:	eb 0d                	jmp    f01035b6 <vprintfmt+0x232>
				else
					putch(ch, putdat);
f01035a9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01035ac:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01035b0:	89 04 24             	mov    %eax,(%esp)
f01035b3:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01035b6:	83 ef 01             	sub    $0x1,%edi
f01035b9:	83 c6 01             	add    $0x1,%esi
f01035bc:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f01035c0:	0f be c2             	movsbl %dl,%eax
f01035c3:	85 c0                	test   %eax,%eax
f01035c5:	75 20                	jne    f01035e7 <vprintfmt+0x263>
f01035c7:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f01035ca:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01035cd:	8b 5d 10             	mov    0x10(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01035d0:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01035d4:	7f 25                	jg     f01035fb <vprintfmt+0x277>
f01035d6:	e9 d2 fd ff ff       	jmp    f01033ad <vprintfmt+0x29>
f01035db:	89 7d 0c             	mov    %edi,0xc(%ebp)
f01035de:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01035e1:	89 5d 10             	mov    %ebx,0x10(%ebp)
f01035e4:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01035e7:	85 db                	test   %ebx,%ebx
f01035e9:	78 9a                	js     f0103585 <vprintfmt+0x201>
f01035eb:	83 eb 01             	sub    $0x1,%ebx
f01035ee:	79 95                	jns    f0103585 <vprintfmt+0x201>
f01035f0:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f01035f3:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01035f6:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01035f9:	eb d5                	jmp    f01035d0 <vprintfmt+0x24c>
f01035fb:	8b 75 08             	mov    0x8(%ebp),%esi
f01035fe:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0103601:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0103604:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103608:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f010360f:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0103611:	83 eb 01             	sub    $0x1,%ebx
f0103614:	75 ee                	jne    f0103604 <vprintfmt+0x280>
f0103616:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0103619:	e9 8f fd ff ff       	jmp    f01033ad <vprintfmt+0x29>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010361e:	83 fa 01             	cmp    $0x1,%edx
f0103621:	7e 16                	jle    f0103639 <vprintfmt+0x2b5>
		return va_arg(*ap, long long);
f0103623:	8b 45 14             	mov    0x14(%ebp),%eax
f0103626:	8d 50 08             	lea    0x8(%eax),%edx
f0103629:	89 55 14             	mov    %edx,0x14(%ebp)
f010362c:	8b 50 04             	mov    0x4(%eax),%edx
f010362f:	8b 00                	mov    (%eax),%eax
f0103631:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103634:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0103637:	eb 32                	jmp    f010366b <vprintfmt+0x2e7>
	else if (lflag)
f0103639:	85 d2                	test   %edx,%edx
f010363b:	74 18                	je     f0103655 <vprintfmt+0x2d1>
		return va_arg(*ap, long);
f010363d:	8b 45 14             	mov    0x14(%ebp),%eax
f0103640:	8d 50 04             	lea    0x4(%eax),%edx
f0103643:	89 55 14             	mov    %edx,0x14(%ebp)
f0103646:	8b 30                	mov    (%eax),%esi
f0103648:	89 75 d8             	mov    %esi,-0x28(%ebp)
f010364b:	89 f0                	mov    %esi,%eax
f010364d:	c1 f8 1f             	sar    $0x1f,%eax
f0103650:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0103653:	eb 16                	jmp    f010366b <vprintfmt+0x2e7>
	else
		return va_arg(*ap, int);
f0103655:	8b 45 14             	mov    0x14(%ebp),%eax
f0103658:	8d 50 04             	lea    0x4(%eax),%edx
f010365b:	89 55 14             	mov    %edx,0x14(%ebp)
f010365e:	8b 30                	mov    (%eax),%esi
f0103660:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0103663:	89 f0                	mov    %esi,%eax
f0103665:	c1 f8 1f             	sar    $0x1f,%eax
f0103668:	89 45 dc             	mov    %eax,-0x24(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f010366b:	8b 45 d8             	mov    -0x28(%ebp),%eax
f010366e:	8b 55 dc             	mov    -0x24(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f0103671:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0103676:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f010367a:	0f 89 80 00 00 00    	jns    f0103700 <vprintfmt+0x37c>
				putch('-', putdat);
f0103680:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103684:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f010368b:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f010368e:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103691:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103694:	f7 d8                	neg    %eax
f0103696:	83 d2 00             	adc    $0x0,%edx
f0103699:	f7 da                	neg    %edx
			}
			base = 10;
f010369b:	b9 0a 00 00 00       	mov    $0xa,%ecx
f01036a0:	eb 5e                	jmp    f0103700 <vprintfmt+0x37c>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f01036a2:	8d 45 14             	lea    0x14(%ebp),%eax
f01036a5:	e8 5b fc ff ff       	call   f0103305 <getuint>
			base = 10;
f01036aa:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f01036af:	eb 4f                	jmp    f0103700 <vprintfmt+0x37c>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			//putch('X', putdat);
			num = getuint(&ap, lflag);
f01036b1:	8d 45 14             	lea    0x14(%ebp),%eax
f01036b4:	e8 4c fc ff ff       	call   f0103305 <getuint>
			base = 8;
f01036b9:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f01036be:	eb 40                	jmp    f0103700 <vprintfmt+0x37c>
			//putch('X', putdat);
			//break;

		// pointer
		case 'p':
			putch('0', putdat);
f01036c0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01036c4:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f01036cb:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f01036ce:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01036d2:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f01036d9:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f01036dc:	8b 45 14             	mov    0x14(%ebp),%eax
f01036df:	8d 50 04             	lea    0x4(%eax),%edx
f01036e2:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f01036e5:	8b 00                	mov    (%eax),%eax
f01036e7:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f01036ec:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f01036f1:	eb 0d                	jmp    f0103700 <vprintfmt+0x37c>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f01036f3:	8d 45 14             	lea    0x14(%ebp),%eax
f01036f6:	e8 0a fc ff ff       	call   f0103305 <getuint>
			base = 16;
f01036fb:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f0103700:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0103704:	89 74 24 10          	mov    %esi,0x10(%esp)
f0103708:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f010370b:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010370f:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0103713:	89 04 24             	mov    %eax,(%esp)
f0103716:	89 54 24 04          	mov    %edx,0x4(%esp)
f010371a:	89 fa                	mov    %edi,%edx
f010371c:	8b 45 08             	mov    0x8(%ebp),%eax
f010371f:	e8 ec fa ff ff       	call   f0103210 <printnum>
			break;
f0103724:	e9 84 fc ff ff       	jmp    f01033ad <vprintfmt+0x29>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0103729:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010372d:	89 0c 24             	mov    %ecx,(%esp)
f0103730:	ff 55 08             	call   *0x8(%ebp)
			break;
f0103733:	e9 75 fc ff ff       	jmp    f01033ad <vprintfmt+0x29>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0103738:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010373c:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0103743:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f0103746:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f010374a:	0f 84 5b fc ff ff    	je     f01033ab <vprintfmt+0x27>
f0103750:	89 f3                	mov    %esi,%ebx
f0103752:	83 eb 01             	sub    $0x1,%ebx
f0103755:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f0103759:	75 f7                	jne    f0103752 <vprintfmt+0x3ce>
f010375b:	e9 4d fc ff ff       	jmp    f01033ad <vprintfmt+0x29>
				/* do nothing */;
			break;
		}
	}
}
f0103760:	83 c4 3c             	add    $0x3c,%esp
f0103763:	5b                   	pop    %ebx
f0103764:	5e                   	pop    %esi
f0103765:	5f                   	pop    %edi
f0103766:	5d                   	pop    %ebp
f0103767:	c3                   	ret    

f0103768 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0103768:	55                   	push   %ebp
f0103769:	89 e5                	mov    %esp,%ebp
f010376b:	83 ec 28             	sub    $0x28,%esp
f010376e:	8b 45 08             	mov    0x8(%ebp),%eax
f0103771:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0103774:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0103777:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f010377b:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f010377e:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0103785:	85 c0                	test   %eax,%eax
f0103787:	74 30                	je     f01037b9 <vsnprintf+0x51>
f0103789:	85 d2                	test   %edx,%edx
f010378b:	7e 2c                	jle    f01037b9 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f010378d:	8b 45 14             	mov    0x14(%ebp),%eax
f0103790:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103794:	8b 45 10             	mov    0x10(%ebp),%eax
f0103797:	89 44 24 08          	mov    %eax,0x8(%esp)
f010379b:	8d 45 ec             	lea    -0x14(%ebp),%eax
f010379e:	89 44 24 04          	mov    %eax,0x4(%esp)
f01037a2:	c7 04 24 3f 33 10 f0 	movl   $0xf010333f,(%esp)
f01037a9:	e8 d6 fb ff ff       	call   f0103384 <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f01037ae:	8b 45 ec             	mov    -0x14(%ebp),%eax
f01037b1:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f01037b4:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01037b7:	eb 05                	jmp    f01037be <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f01037b9:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f01037be:	c9                   	leave  
f01037bf:	c3                   	ret    

f01037c0 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f01037c0:	55                   	push   %ebp
f01037c1:	89 e5                	mov    %esp,%ebp
f01037c3:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f01037c6:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f01037c9:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01037cd:	8b 45 10             	mov    0x10(%ebp),%eax
f01037d0:	89 44 24 08          	mov    %eax,0x8(%esp)
f01037d4:	8b 45 0c             	mov    0xc(%ebp),%eax
f01037d7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01037db:	8b 45 08             	mov    0x8(%ebp),%eax
f01037de:	89 04 24             	mov    %eax,(%esp)
f01037e1:	e8 82 ff ff ff       	call   f0103768 <vsnprintf>
	va_end(ap);

	return rc;
}
f01037e6:	c9                   	leave  
f01037e7:	c3                   	ret    
f01037e8:	66 90                	xchg   %ax,%ax
f01037ea:	66 90                	xchg   %ax,%ax
f01037ec:	66 90                	xchg   %ax,%ax
f01037ee:	66 90                	xchg   %ax,%ax

f01037f0 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f01037f0:	55                   	push   %ebp
f01037f1:	89 e5                	mov    %esp,%ebp
f01037f3:	57                   	push   %edi
f01037f4:	56                   	push   %esi
f01037f5:	53                   	push   %ebx
f01037f6:	83 ec 1c             	sub    $0x1c,%esp
f01037f9:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f01037fc:	85 c0                	test   %eax,%eax
f01037fe:	74 10                	je     f0103810 <readline+0x20>
		cprintf("%s", prompt);
f0103800:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103804:	c7 04 24 50 4c 10 f0 	movl   $0xf0104c50,(%esp)
f010380b:	e8 f5 f6 ff ff       	call   f0102f05 <cprintf>

	i = 0;
	echoing = iscons(0);
f0103810:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0103817:	e8 09 ce ff ff       	call   f0100625 <iscons>
f010381c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f010381e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0103823:	e8 ec cd ff ff       	call   f0100614 <getchar>
f0103828:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f010382a:	85 c0                	test   %eax,%eax
f010382c:	79 17                	jns    f0103845 <readline+0x55>
			cprintf("read error: %e\n", c);
f010382e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103832:	c7 04 24 00 51 10 f0 	movl   $0xf0105100,(%esp)
f0103839:	e8 c7 f6 ff ff       	call   f0102f05 <cprintf>
			return NULL;
f010383e:	b8 00 00 00 00       	mov    $0x0,%eax
f0103843:	eb 6d                	jmp    f01038b2 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0103845:	83 f8 7f             	cmp    $0x7f,%eax
f0103848:	74 05                	je     f010384f <readline+0x5f>
f010384a:	83 f8 08             	cmp    $0x8,%eax
f010384d:	75 19                	jne    f0103868 <readline+0x78>
f010384f:	85 f6                	test   %esi,%esi
f0103851:	7e 15                	jle    f0103868 <readline+0x78>
			if (echoing)
f0103853:	85 ff                	test   %edi,%edi
f0103855:	74 0c                	je     f0103863 <readline+0x73>
				cputchar('\b');
f0103857:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f010385e:	e8 a1 cd ff ff       	call   f0100604 <cputchar>
			i--;
f0103863:	83 ee 01             	sub    $0x1,%esi
f0103866:	eb bb                	jmp    f0103823 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0103868:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f010386e:	7f 1c                	jg     f010388c <readline+0x9c>
f0103870:	83 fb 1f             	cmp    $0x1f,%ebx
f0103873:	7e 17                	jle    f010388c <readline+0x9c>
			if (echoing)
f0103875:	85 ff                	test   %edi,%edi
f0103877:	74 08                	je     f0103881 <readline+0x91>
				cputchar(c);
f0103879:	89 1c 24             	mov    %ebx,(%esp)
f010387c:	e8 83 cd ff ff       	call   f0100604 <cputchar>
			buf[i++] = c;
f0103881:	88 9e 80 75 11 f0    	mov    %bl,-0xfee8a80(%esi)
f0103887:	8d 76 01             	lea    0x1(%esi),%esi
f010388a:	eb 97                	jmp    f0103823 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f010388c:	83 fb 0d             	cmp    $0xd,%ebx
f010388f:	74 05                	je     f0103896 <readline+0xa6>
f0103891:	83 fb 0a             	cmp    $0xa,%ebx
f0103894:	75 8d                	jne    f0103823 <readline+0x33>
			if (echoing)
f0103896:	85 ff                	test   %edi,%edi
f0103898:	74 0c                	je     f01038a6 <readline+0xb6>
				cputchar('\n');
f010389a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f01038a1:	e8 5e cd ff ff       	call   f0100604 <cputchar>
			buf[i] = 0;
f01038a6:	c6 86 80 75 11 f0 00 	movb   $0x0,-0xfee8a80(%esi)
			return buf;
f01038ad:	b8 80 75 11 f0       	mov    $0xf0117580,%eax
		}
	}
}
f01038b2:	83 c4 1c             	add    $0x1c,%esp
f01038b5:	5b                   	pop    %ebx
f01038b6:	5e                   	pop    %esi
f01038b7:	5f                   	pop    %edi
f01038b8:	5d                   	pop    %ebp
f01038b9:	c3                   	ret    
f01038ba:	66 90                	xchg   %ax,%ax
f01038bc:	66 90                	xchg   %ax,%ax
f01038be:	66 90                	xchg   %ax,%ax

f01038c0 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f01038c0:	55                   	push   %ebp
f01038c1:	89 e5                	mov    %esp,%ebp
f01038c3:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f01038c6:	80 3a 00             	cmpb   $0x0,(%edx)
f01038c9:	74 10                	je     f01038db <strlen+0x1b>
f01038cb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f01038d0:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f01038d3:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f01038d7:	75 f7                	jne    f01038d0 <strlen+0x10>
f01038d9:	eb 05                	jmp    f01038e0 <strlen+0x20>
f01038db:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f01038e0:	5d                   	pop    %ebp
f01038e1:	c3                   	ret    

f01038e2 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f01038e2:	55                   	push   %ebp
f01038e3:	89 e5                	mov    %esp,%ebp
f01038e5:	53                   	push   %ebx
f01038e6:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01038e9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01038ec:	85 c9                	test   %ecx,%ecx
f01038ee:	74 1c                	je     f010390c <strnlen+0x2a>
f01038f0:	80 3b 00             	cmpb   $0x0,(%ebx)
f01038f3:	74 1e                	je     f0103913 <strnlen+0x31>
f01038f5:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f01038fa:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01038fc:	39 ca                	cmp    %ecx,%edx
f01038fe:	74 18                	je     f0103918 <strnlen+0x36>
f0103900:	83 c2 01             	add    $0x1,%edx
f0103903:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0103908:	75 f0                	jne    f01038fa <strnlen+0x18>
f010390a:	eb 0c                	jmp    f0103918 <strnlen+0x36>
f010390c:	b8 00 00 00 00       	mov    $0x0,%eax
f0103911:	eb 05                	jmp    f0103918 <strnlen+0x36>
f0103913:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0103918:	5b                   	pop    %ebx
f0103919:	5d                   	pop    %ebp
f010391a:	c3                   	ret    

f010391b <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f010391b:	55                   	push   %ebp
f010391c:	89 e5                	mov    %esp,%ebp
f010391e:	53                   	push   %ebx
f010391f:	8b 45 08             	mov    0x8(%ebp),%eax
f0103922:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0103925:	89 c2                	mov    %eax,%edx
f0103927:	83 c2 01             	add    $0x1,%edx
f010392a:	83 c1 01             	add    $0x1,%ecx
f010392d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0103931:	88 5a ff             	mov    %bl,-0x1(%edx)
f0103934:	84 db                	test   %bl,%bl
f0103936:	75 ef                	jne    f0103927 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0103938:	5b                   	pop    %ebx
f0103939:	5d                   	pop    %ebp
f010393a:	c3                   	ret    

f010393b <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f010393b:	55                   	push   %ebp
f010393c:	89 e5                	mov    %esp,%ebp
f010393e:	56                   	push   %esi
f010393f:	53                   	push   %ebx
f0103940:	8b 75 08             	mov    0x8(%ebp),%esi
f0103943:	8b 55 0c             	mov    0xc(%ebp),%edx
f0103946:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0103949:	85 db                	test   %ebx,%ebx
f010394b:	74 17                	je     f0103964 <strncpy+0x29>
f010394d:	01 f3                	add    %esi,%ebx
f010394f:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f0103951:	83 c1 01             	add    $0x1,%ecx
f0103954:	0f b6 02             	movzbl (%edx),%eax
f0103957:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f010395a:	80 3a 01             	cmpb   $0x1,(%edx)
f010395d:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0103960:	39 d9                	cmp    %ebx,%ecx
f0103962:	75 ed                	jne    f0103951 <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f0103964:	89 f0                	mov    %esi,%eax
f0103966:	5b                   	pop    %ebx
f0103967:	5e                   	pop    %esi
f0103968:	5d                   	pop    %ebp
f0103969:	c3                   	ret    

f010396a <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f010396a:	55                   	push   %ebp
f010396b:	89 e5                	mov    %esp,%ebp
f010396d:	57                   	push   %edi
f010396e:	56                   	push   %esi
f010396f:	53                   	push   %ebx
f0103970:	8b 7d 08             	mov    0x8(%ebp),%edi
f0103973:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0103976:	8b 75 10             	mov    0x10(%ebp),%esi
f0103979:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f010397b:	85 f6                	test   %esi,%esi
f010397d:	74 34                	je     f01039b3 <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f010397f:	83 fe 01             	cmp    $0x1,%esi
f0103982:	74 26                	je     f01039aa <strlcpy+0x40>
f0103984:	0f b6 0b             	movzbl (%ebx),%ecx
f0103987:	84 c9                	test   %cl,%cl
f0103989:	74 23                	je     f01039ae <strlcpy+0x44>
f010398b:	83 ee 02             	sub    $0x2,%esi
f010398e:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f0103993:	83 c0 01             	add    $0x1,%eax
f0103996:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0103999:	39 f2                	cmp    %esi,%edx
f010399b:	74 13                	je     f01039b0 <strlcpy+0x46>
f010399d:	83 c2 01             	add    $0x1,%edx
f01039a0:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f01039a4:	84 c9                	test   %cl,%cl
f01039a6:	75 eb                	jne    f0103993 <strlcpy+0x29>
f01039a8:	eb 06                	jmp    f01039b0 <strlcpy+0x46>
f01039aa:	89 f8                	mov    %edi,%eax
f01039ac:	eb 02                	jmp    f01039b0 <strlcpy+0x46>
f01039ae:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f01039b0:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f01039b3:	29 f8                	sub    %edi,%eax
}
f01039b5:	5b                   	pop    %ebx
f01039b6:	5e                   	pop    %esi
f01039b7:	5f                   	pop    %edi
f01039b8:	5d                   	pop    %ebp
f01039b9:	c3                   	ret    

f01039ba <strcmp>:

int
strcmp(const char *p, const char *q)
{
f01039ba:	55                   	push   %ebp
f01039bb:	89 e5                	mov    %esp,%ebp
f01039bd:	8b 4d 08             	mov    0x8(%ebp),%ecx
f01039c0:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f01039c3:	0f b6 01             	movzbl (%ecx),%eax
f01039c6:	84 c0                	test   %al,%al
f01039c8:	74 15                	je     f01039df <strcmp+0x25>
f01039ca:	3a 02                	cmp    (%edx),%al
f01039cc:	75 11                	jne    f01039df <strcmp+0x25>
		p++, q++;
f01039ce:	83 c1 01             	add    $0x1,%ecx
f01039d1:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f01039d4:	0f b6 01             	movzbl (%ecx),%eax
f01039d7:	84 c0                	test   %al,%al
f01039d9:	74 04                	je     f01039df <strcmp+0x25>
f01039db:	3a 02                	cmp    (%edx),%al
f01039dd:	74 ef                	je     f01039ce <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f01039df:	0f b6 c0             	movzbl %al,%eax
f01039e2:	0f b6 12             	movzbl (%edx),%edx
f01039e5:	29 d0                	sub    %edx,%eax
}
f01039e7:	5d                   	pop    %ebp
f01039e8:	c3                   	ret    

f01039e9 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f01039e9:	55                   	push   %ebp
f01039ea:	89 e5                	mov    %esp,%ebp
f01039ec:	56                   	push   %esi
f01039ed:	53                   	push   %ebx
f01039ee:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01039f1:	8b 55 0c             	mov    0xc(%ebp),%edx
f01039f4:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f01039f7:	85 f6                	test   %esi,%esi
f01039f9:	74 29                	je     f0103a24 <strncmp+0x3b>
f01039fb:	0f b6 03             	movzbl (%ebx),%eax
f01039fe:	84 c0                	test   %al,%al
f0103a00:	74 30                	je     f0103a32 <strncmp+0x49>
f0103a02:	3a 02                	cmp    (%edx),%al
f0103a04:	75 2c                	jne    f0103a32 <strncmp+0x49>
f0103a06:	8d 43 01             	lea    0x1(%ebx),%eax
f0103a09:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f0103a0b:	89 c3                	mov    %eax,%ebx
f0103a0d:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f0103a10:	39 f0                	cmp    %esi,%eax
f0103a12:	74 17                	je     f0103a2b <strncmp+0x42>
f0103a14:	0f b6 08             	movzbl (%eax),%ecx
f0103a17:	84 c9                	test   %cl,%cl
f0103a19:	74 17                	je     f0103a32 <strncmp+0x49>
f0103a1b:	83 c0 01             	add    $0x1,%eax
f0103a1e:	3a 0a                	cmp    (%edx),%cl
f0103a20:	74 e9                	je     f0103a0b <strncmp+0x22>
f0103a22:	eb 0e                	jmp    f0103a32 <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f0103a24:	b8 00 00 00 00       	mov    $0x0,%eax
f0103a29:	eb 0f                	jmp    f0103a3a <strncmp+0x51>
f0103a2b:	b8 00 00 00 00       	mov    $0x0,%eax
f0103a30:	eb 08                	jmp    f0103a3a <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f0103a32:	0f b6 03             	movzbl (%ebx),%eax
f0103a35:	0f b6 12             	movzbl (%edx),%edx
f0103a38:	29 d0                	sub    %edx,%eax
}
f0103a3a:	5b                   	pop    %ebx
f0103a3b:	5e                   	pop    %esi
f0103a3c:	5d                   	pop    %ebp
f0103a3d:	c3                   	ret    

f0103a3e <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f0103a3e:	55                   	push   %ebp
f0103a3f:	89 e5                	mov    %esp,%ebp
f0103a41:	53                   	push   %ebx
f0103a42:	8b 45 08             	mov    0x8(%ebp),%eax
f0103a45:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0103a48:	0f b6 18             	movzbl (%eax),%ebx
f0103a4b:	84 db                	test   %bl,%bl
f0103a4d:	74 1d                	je     f0103a6c <strchr+0x2e>
f0103a4f:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0103a51:	38 d3                	cmp    %dl,%bl
f0103a53:	75 06                	jne    f0103a5b <strchr+0x1d>
f0103a55:	eb 1a                	jmp    f0103a71 <strchr+0x33>
f0103a57:	38 ca                	cmp    %cl,%dl
f0103a59:	74 16                	je     f0103a71 <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0103a5b:	83 c0 01             	add    $0x1,%eax
f0103a5e:	0f b6 10             	movzbl (%eax),%edx
f0103a61:	84 d2                	test   %dl,%dl
f0103a63:	75 f2                	jne    f0103a57 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0103a65:	b8 00 00 00 00       	mov    $0x0,%eax
f0103a6a:	eb 05                	jmp    f0103a71 <strchr+0x33>
f0103a6c:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0103a71:	5b                   	pop    %ebx
f0103a72:	5d                   	pop    %ebp
f0103a73:	c3                   	ret    

f0103a74 <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f0103a74:	55                   	push   %ebp
f0103a75:	89 e5                	mov    %esp,%ebp
f0103a77:	53                   	push   %ebx
f0103a78:	8b 45 08             	mov    0x8(%ebp),%eax
f0103a7b:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0103a7e:	0f b6 18             	movzbl (%eax),%ebx
f0103a81:	84 db                	test   %bl,%bl
f0103a83:	74 17                	je     f0103a9c <strfind+0x28>
f0103a85:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0103a87:	38 d3                	cmp    %dl,%bl
f0103a89:	75 07                	jne    f0103a92 <strfind+0x1e>
f0103a8b:	eb 0f                	jmp    f0103a9c <strfind+0x28>
f0103a8d:	38 ca                	cmp    %cl,%dl
f0103a8f:	90                   	nop
f0103a90:	74 0a                	je     f0103a9c <strfind+0x28>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f0103a92:	83 c0 01             	add    $0x1,%eax
f0103a95:	0f b6 10             	movzbl (%eax),%edx
f0103a98:	84 d2                	test   %dl,%dl
f0103a9a:	75 f1                	jne    f0103a8d <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f0103a9c:	5b                   	pop    %ebx
f0103a9d:	5d                   	pop    %ebp
f0103a9e:	c3                   	ret    

f0103a9f <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f0103a9f:	55                   	push   %ebp
f0103aa0:	89 e5                	mov    %esp,%ebp
f0103aa2:	57                   	push   %edi
f0103aa3:	56                   	push   %esi
f0103aa4:	53                   	push   %ebx
f0103aa5:	8b 7d 08             	mov    0x8(%ebp),%edi
f0103aa8:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0103aab:	85 c9                	test   %ecx,%ecx
f0103aad:	74 36                	je     f0103ae5 <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f0103aaf:	f7 c7 03 00 00 00    	test   $0x3,%edi
f0103ab5:	75 28                	jne    f0103adf <memset+0x40>
f0103ab7:	f6 c1 03             	test   $0x3,%cl
f0103aba:	75 23                	jne    f0103adf <memset+0x40>
		c &= 0xFF;
f0103abc:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f0103ac0:	89 d3                	mov    %edx,%ebx
f0103ac2:	c1 e3 08             	shl    $0x8,%ebx
f0103ac5:	89 d6                	mov    %edx,%esi
f0103ac7:	c1 e6 18             	shl    $0x18,%esi
f0103aca:	89 d0                	mov    %edx,%eax
f0103acc:	c1 e0 10             	shl    $0x10,%eax
f0103acf:	09 f0                	or     %esi,%eax
f0103ad1:	09 c2                	or     %eax,%edx
f0103ad3:	89 d0                	mov    %edx,%eax
f0103ad5:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f0103ad7:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0103ada:	fc                   	cld    
f0103adb:	f3 ab                	rep stos %eax,%es:(%edi)
f0103add:	eb 06                	jmp    f0103ae5 <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0103adf:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103ae2:	fc                   	cld    
f0103ae3:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f0103ae5:	89 f8                	mov    %edi,%eax
f0103ae7:	5b                   	pop    %ebx
f0103ae8:	5e                   	pop    %esi
f0103ae9:	5f                   	pop    %edi
f0103aea:	5d                   	pop    %ebp
f0103aeb:	c3                   	ret    

f0103aec <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0103aec:	55                   	push   %ebp
f0103aed:	89 e5                	mov    %esp,%ebp
f0103aef:	57                   	push   %edi
f0103af0:	56                   	push   %esi
f0103af1:	8b 45 08             	mov    0x8(%ebp),%eax
f0103af4:	8b 75 0c             	mov    0xc(%ebp),%esi
f0103af7:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0103afa:	39 c6                	cmp    %eax,%esi
f0103afc:	73 35                	jae    f0103b33 <memmove+0x47>
f0103afe:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0103b01:	39 d0                	cmp    %edx,%eax
f0103b03:	73 2e                	jae    f0103b33 <memmove+0x47>
		s += n;
		d += n;
f0103b05:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0103b08:	89 d6                	mov    %edx,%esi
f0103b0a:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0103b0c:	f7 c6 03 00 00 00    	test   $0x3,%esi
f0103b12:	75 13                	jne    f0103b27 <memmove+0x3b>
f0103b14:	f6 c1 03             	test   $0x3,%cl
f0103b17:	75 0e                	jne    f0103b27 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0103b19:	83 ef 04             	sub    $0x4,%edi
f0103b1c:	8d 72 fc             	lea    -0x4(%edx),%esi
f0103b1f:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f0103b22:	fd                   	std    
f0103b23:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0103b25:	eb 09                	jmp    f0103b30 <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0103b27:	83 ef 01             	sub    $0x1,%edi
f0103b2a:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0103b2d:	fd                   	std    
f0103b2e:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0103b30:	fc                   	cld    
f0103b31:	eb 1d                	jmp    f0103b50 <memmove+0x64>
f0103b33:	89 f2                	mov    %esi,%edx
f0103b35:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0103b37:	f6 c2 03             	test   $0x3,%dl
f0103b3a:	75 0f                	jne    f0103b4b <memmove+0x5f>
f0103b3c:	f6 c1 03             	test   $0x3,%cl
f0103b3f:	75 0a                	jne    f0103b4b <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0103b41:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f0103b44:	89 c7                	mov    %eax,%edi
f0103b46:	fc                   	cld    
f0103b47:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0103b49:	eb 05                	jmp    f0103b50 <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0103b4b:	89 c7                	mov    %eax,%edi
f0103b4d:	fc                   	cld    
f0103b4e:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f0103b50:	5e                   	pop    %esi
f0103b51:	5f                   	pop    %edi
f0103b52:	5d                   	pop    %ebp
f0103b53:	c3                   	ret    

f0103b54 <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f0103b54:	55                   	push   %ebp
f0103b55:	89 e5                	mov    %esp,%ebp
f0103b57:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0103b5a:	8b 45 10             	mov    0x10(%ebp),%eax
f0103b5d:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103b61:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103b64:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103b68:	8b 45 08             	mov    0x8(%ebp),%eax
f0103b6b:	89 04 24             	mov    %eax,(%esp)
f0103b6e:	e8 79 ff ff ff       	call   f0103aec <memmove>
}
f0103b73:	c9                   	leave  
f0103b74:	c3                   	ret    

f0103b75 <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f0103b75:	55                   	push   %ebp
f0103b76:	89 e5                	mov    %esp,%ebp
f0103b78:	57                   	push   %edi
f0103b79:	56                   	push   %esi
f0103b7a:	53                   	push   %ebx
f0103b7b:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0103b7e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0103b81:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0103b84:	8d 78 ff             	lea    -0x1(%eax),%edi
f0103b87:	85 c0                	test   %eax,%eax
f0103b89:	74 36                	je     f0103bc1 <memcmp+0x4c>
		if (*s1 != *s2)
f0103b8b:	0f b6 03             	movzbl (%ebx),%eax
f0103b8e:	0f b6 0e             	movzbl (%esi),%ecx
f0103b91:	ba 00 00 00 00       	mov    $0x0,%edx
f0103b96:	38 c8                	cmp    %cl,%al
f0103b98:	74 1c                	je     f0103bb6 <memcmp+0x41>
f0103b9a:	eb 10                	jmp    f0103bac <memcmp+0x37>
f0103b9c:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f0103ba1:	83 c2 01             	add    $0x1,%edx
f0103ba4:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f0103ba8:	38 c8                	cmp    %cl,%al
f0103baa:	74 0a                	je     f0103bb6 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f0103bac:	0f b6 c0             	movzbl %al,%eax
f0103baf:	0f b6 c9             	movzbl %cl,%ecx
f0103bb2:	29 c8                	sub    %ecx,%eax
f0103bb4:	eb 10                	jmp    f0103bc6 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0103bb6:	39 fa                	cmp    %edi,%edx
f0103bb8:	75 e2                	jne    f0103b9c <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f0103bba:	b8 00 00 00 00       	mov    $0x0,%eax
f0103bbf:	eb 05                	jmp    f0103bc6 <memcmp+0x51>
f0103bc1:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0103bc6:	5b                   	pop    %ebx
f0103bc7:	5e                   	pop    %esi
f0103bc8:	5f                   	pop    %edi
f0103bc9:	5d                   	pop    %ebp
f0103bca:	c3                   	ret    

f0103bcb <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0103bcb:	55                   	push   %ebp
f0103bcc:	89 e5                	mov    %esp,%ebp
f0103bce:	53                   	push   %ebx
f0103bcf:	8b 45 08             	mov    0x8(%ebp),%eax
f0103bd2:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f0103bd5:	89 c2                	mov    %eax,%edx
f0103bd7:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0103bda:	39 d0                	cmp    %edx,%eax
f0103bdc:	73 14                	jae    f0103bf2 <memfind+0x27>
		if (*(const unsigned char *) s == (unsigned char) c)
f0103bde:	89 d9                	mov    %ebx,%ecx
f0103be0:	38 18                	cmp    %bl,(%eax)
f0103be2:	75 06                	jne    f0103bea <memfind+0x1f>
f0103be4:	eb 0c                	jmp    f0103bf2 <memfind+0x27>
f0103be6:	38 08                	cmp    %cl,(%eax)
f0103be8:	74 08                	je     f0103bf2 <memfind+0x27>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f0103bea:	83 c0 01             	add    $0x1,%eax
f0103bed:	39 d0                	cmp    %edx,%eax
f0103bef:	90                   	nop
f0103bf0:	75 f4                	jne    f0103be6 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f0103bf2:	5b                   	pop    %ebx
f0103bf3:	5d                   	pop    %ebp
f0103bf4:	c3                   	ret    

f0103bf5 <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f0103bf5:	55                   	push   %ebp
f0103bf6:	89 e5                	mov    %esp,%ebp
f0103bf8:	57                   	push   %edi
f0103bf9:	56                   	push   %esi
f0103bfa:	53                   	push   %ebx
f0103bfb:	8b 55 08             	mov    0x8(%ebp),%edx
f0103bfe:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0103c01:	0f b6 0a             	movzbl (%edx),%ecx
f0103c04:	80 f9 09             	cmp    $0x9,%cl
f0103c07:	74 05                	je     f0103c0e <strtol+0x19>
f0103c09:	80 f9 20             	cmp    $0x20,%cl
f0103c0c:	75 10                	jne    f0103c1e <strtol+0x29>
		s++;
f0103c0e:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0103c11:	0f b6 0a             	movzbl (%edx),%ecx
f0103c14:	80 f9 09             	cmp    $0x9,%cl
f0103c17:	74 f5                	je     f0103c0e <strtol+0x19>
f0103c19:	80 f9 20             	cmp    $0x20,%cl
f0103c1c:	74 f0                	je     f0103c0e <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f0103c1e:	80 f9 2b             	cmp    $0x2b,%cl
f0103c21:	75 0a                	jne    f0103c2d <strtol+0x38>
		s++;
f0103c23:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f0103c26:	bf 00 00 00 00       	mov    $0x0,%edi
f0103c2b:	eb 11                	jmp    f0103c3e <strtol+0x49>
f0103c2d:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f0103c32:	80 f9 2d             	cmp    $0x2d,%cl
f0103c35:	75 07                	jne    f0103c3e <strtol+0x49>
		s++, neg = 1;
f0103c37:	83 c2 01             	add    $0x1,%edx
f0103c3a:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0103c3e:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f0103c43:	75 15                	jne    f0103c5a <strtol+0x65>
f0103c45:	80 3a 30             	cmpb   $0x30,(%edx)
f0103c48:	75 10                	jne    f0103c5a <strtol+0x65>
f0103c4a:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0103c4e:	75 0a                	jne    f0103c5a <strtol+0x65>
		s += 2, base = 16;
f0103c50:	83 c2 02             	add    $0x2,%edx
f0103c53:	b8 10 00 00 00       	mov    $0x10,%eax
f0103c58:	eb 10                	jmp    f0103c6a <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f0103c5a:	85 c0                	test   %eax,%eax
f0103c5c:	75 0c                	jne    f0103c6a <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0103c5e:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0103c60:	80 3a 30             	cmpb   $0x30,(%edx)
f0103c63:	75 05                	jne    f0103c6a <strtol+0x75>
		s++, base = 8;
f0103c65:	83 c2 01             	add    $0x1,%edx
f0103c68:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f0103c6a:	bb 00 00 00 00       	mov    $0x0,%ebx
f0103c6f:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f0103c72:	0f b6 0a             	movzbl (%edx),%ecx
f0103c75:	8d 71 d0             	lea    -0x30(%ecx),%esi
f0103c78:	89 f0                	mov    %esi,%eax
f0103c7a:	3c 09                	cmp    $0x9,%al
f0103c7c:	77 08                	ja     f0103c86 <strtol+0x91>
			dig = *s - '0';
f0103c7e:	0f be c9             	movsbl %cl,%ecx
f0103c81:	83 e9 30             	sub    $0x30,%ecx
f0103c84:	eb 20                	jmp    f0103ca6 <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f0103c86:	8d 71 9f             	lea    -0x61(%ecx),%esi
f0103c89:	89 f0                	mov    %esi,%eax
f0103c8b:	3c 19                	cmp    $0x19,%al
f0103c8d:	77 08                	ja     f0103c97 <strtol+0xa2>
			dig = *s - 'a' + 10;
f0103c8f:	0f be c9             	movsbl %cl,%ecx
f0103c92:	83 e9 57             	sub    $0x57,%ecx
f0103c95:	eb 0f                	jmp    f0103ca6 <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f0103c97:	8d 71 bf             	lea    -0x41(%ecx),%esi
f0103c9a:	89 f0                	mov    %esi,%eax
f0103c9c:	3c 19                	cmp    $0x19,%al
f0103c9e:	77 16                	ja     f0103cb6 <strtol+0xc1>
			dig = *s - 'A' + 10;
f0103ca0:	0f be c9             	movsbl %cl,%ecx
f0103ca3:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f0103ca6:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f0103ca9:	7d 0f                	jge    f0103cba <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f0103cab:	83 c2 01             	add    $0x1,%edx
f0103cae:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f0103cb2:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f0103cb4:	eb bc                	jmp    f0103c72 <strtol+0x7d>
f0103cb6:	89 d8                	mov    %ebx,%eax
f0103cb8:	eb 02                	jmp    f0103cbc <strtol+0xc7>
f0103cba:	89 d8                	mov    %ebx,%eax

	if (endptr)
f0103cbc:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0103cc0:	74 05                	je     f0103cc7 <strtol+0xd2>
		*endptr = (char *) s;
f0103cc2:	8b 75 0c             	mov    0xc(%ebp),%esi
f0103cc5:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f0103cc7:	f7 d8                	neg    %eax
f0103cc9:	85 ff                	test   %edi,%edi
f0103ccb:	0f 44 c3             	cmove  %ebx,%eax
}
f0103cce:	5b                   	pop    %ebx
f0103ccf:	5e                   	pop    %esi
f0103cd0:	5f                   	pop    %edi
f0103cd1:	5d                   	pop    %ebp
f0103cd2:	c3                   	ret    
f0103cd3:	66 90                	xchg   %ax,%ax
f0103cd5:	66 90                	xchg   %ax,%ax
f0103cd7:	66 90                	xchg   %ax,%ax
f0103cd9:	66 90                	xchg   %ax,%ax
f0103cdb:	66 90                	xchg   %ax,%ax
f0103cdd:	66 90                	xchg   %ax,%ax
f0103cdf:	90                   	nop

f0103ce0 <__udivdi3>:
f0103ce0:	55                   	push   %ebp
f0103ce1:	57                   	push   %edi
f0103ce2:	56                   	push   %esi
f0103ce3:	83 ec 0c             	sub    $0xc,%esp
f0103ce6:	8b 44 24 28          	mov    0x28(%esp),%eax
f0103cea:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f0103cee:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f0103cf2:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0103cf6:	85 c0                	test   %eax,%eax
f0103cf8:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103cfc:	89 ea                	mov    %ebp,%edx
f0103cfe:	89 0c 24             	mov    %ecx,(%esp)
f0103d01:	75 2d                	jne    f0103d30 <__udivdi3+0x50>
f0103d03:	39 e9                	cmp    %ebp,%ecx
f0103d05:	77 61                	ja     f0103d68 <__udivdi3+0x88>
f0103d07:	85 c9                	test   %ecx,%ecx
f0103d09:	89 ce                	mov    %ecx,%esi
f0103d0b:	75 0b                	jne    f0103d18 <__udivdi3+0x38>
f0103d0d:	b8 01 00 00 00       	mov    $0x1,%eax
f0103d12:	31 d2                	xor    %edx,%edx
f0103d14:	f7 f1                	div    %ecx
f0103d16:	89 c6                	mov    %eax,%esi
f0103d18:	31 d2                	xor    %edx,%edx
f0103d1a:	89 e8                	mov    %ebp,%eax
f0103d1c:	f7 f6                	div    %esi
f0103d1e:	89 c5                	mov    %eax,%ebp
f0103d20:	89 f8                	mov    %edi,%eax
f0103d22:	f7 f6                	div    %esi
f0103d24:	89 ea                	mov    %ebp,%edx
f0103d26:	83 c4 0c             	add    $0xc,%esp
f0103d29:	5e                   	pop    %esi
f0103d2a:	5f                   	pop    %edi
f0103d2b:	5d                   	pop    %ebp
f0103d2c:	c3                   	ret    
f0103d2d:	8d 76 00             	lea    0x0(%esi),%esi
f0103d30:	39 e8                	cmp    %ebp,%eax
f0103d32:	77 24                	ja     f0103d58 <__udivdi3+0x78>
f0103d34:	0f bd e8             	bsr    %eax,%ebp
f0103d37:	83 f5 1f             	xor    $0x1f,%ebp
f0103d3a:	75 3c                	jne    f0103d78 <__udivdi3+0x98>
f0103d3c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0103d40:	39 34 24             	cmp    %esi,(%esp)
f0103d43:	0f 86 9f 00 00 00    	jbe    f0103de8 <__udivdi3+0x108>
f0103d49:	39 d0                	cmp    %edx,%eax
f0103d4b:	0f 82 97 00 00 00    	jb     f0103de8 <__udivdi3+0x108>
f0103d51:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0103d58:	31 d2                	xor    %edx,%edx
f0103d5a:	31 c0                	xor    %eax,%eax
f0103d5c:	83 c4 0c             	add    $0xc,%esp
f0103d5f:	5e                   	pop    %esi
f0103d60:	5f                   	pop    %edi
f0103d61:	5d                   	pop    %ebp
f0103d62:	c3                   	ret    
f0103d63:	90                   	nop
f0103d64:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0103d68:	89 f8                	mov    %edi,%eax
f0103d6a:	f7 f1                	div    %ecx
f0103d6c:	31 d2                	xor    %edx,%edx
f0103d6e:	83 c4 0c             	add    $0xc,%esp
f0103d71:	5e                   	pop    %esi
f0103d72:	5f                   	pop    %edi
f0103d73:	5d                   	pop    %ebp
f0103d74:	c3                   	ret    
f0103d75:	8d 76 00             	lea    0x0(%esi),%esi
f0103d78:	89 e9                	mov    %ebp,%ecx
f0103d7a:	8b 3c 24             	mov    (%esp),%edi
f0103d7d:	d3 e0                	shl    %cl,%eax
f0103d7f:	89 c6                	mov    %eax,%esi
f0103d81:	b8 20 00 00 00       	mov    $0x20,%eax
f0103d86:	29 e8                	sub    %ebp,%eax
f0103d88:	89 c1                	mov    %eax,%ecx
f0103d8a:	d3 ef                	shr    %cl,%edi
f0103d8c:	89 e9                	mov    %ebp,%ecx
f0103d8e:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0103d92:	8b 3c 24             	mov    (%esp),%edi
f0103d95:	09 74 24 08          	or     %esi,0x8(%esp)
f0103d99:	89 d6                	mov    %edx,%esi
f0103d9b:	d3 e7                	shl    %cl,%edi
f0103d9d:	89 c1                	mov    %eax,%ecx
f0103d9f:	89 3c 24             	mov    %edi,(%esp)
f0103da2:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0103da6:	d3 ee                	shr    %cl,%esi
f0103da8:	89 e9                	mov    %ebp,%ecx
f0103daa:	d3 e2                	shl    %cl,%edx
f0103dac:	89 c1                	mov    %eax,%ecx
f0103dae:	d3 ef                	shr    %cl,%edi
f0103db0:	09 d7                	or     %edx,%edi
f0103db2:	89 f2                	mov    %esi,%edx
f0103db4:	89 f8                	mov    %edi,%eax
f0103db6:	f7 74 24 08          	divl   0x8(%esp)
f0103dba:	89 d6                	mov    %edx,%esi
f0103dbc:	89 c7                	mov    %eax,%edi
f0103dbe:	f7 24 24             	mull   (%esp)
f0103dc1:	39 d6                	cmp    %edx,%esi
f0103dc3:	89 14 24             	mov    %edx,(%esp)
f0103dc6:	72 30                	jb     f0103df8 <__udivdi3+0x118>
f0103dc8:	8b 54 24 04          	mov    0x4(%esp),%edx
f0103dcc:	89 e9                	mov    %ebp,%ecx
f0103dce:	d3 e2                	shl    %cl,%edx
f0103dd0:	39 c2                	cmp    %eax,%edx
f0103dd2:	73 05                	jae    f0103dd9 <__udivdi3+0xf9>
f0103dd4:	3b 34 24             	cmp    (%esp),%esi
f0103dd7:	74 1f                	je     f0103df8 <__udivdi3+0x118>
f0103dd9:	89 f8                	mov    %edi,%eax
f0103ddb:	31 d2                	xor    %edx,%edx
f0103ddd:	e9 7a ff ff ff       	jmp    f0103d5c <__udivdi3+0x7c>
f0103de2:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0103de8:	31 d2                	xor    %edx,%edx
f0103dea:	b8 01 00 00 00       	mov    $0x1,%eax
f0103def:	e9 68 ff ff ff       	jmp    f0103d5c <__udivdi3+0x7c>
f0103df4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0103df8:	8d 47 ff             	lea    -0x1(%edi),%eax
f0103dfb:	31 d2                	xor    %edx,%edx
f0103dfd:	83 c4 0c             	add    $0xc,%esp
f0103e00:	5e                   	pop    %esi
f0103e01:	5f                   	pop    %edi
f0103e02:	5d                   	pop    %ebp
f0103e03:	c3                   	ret    
f0103e04:	66 90                	xchg   %ax,%ax
f0103e06:	66 90                	xchg   %ax,%ax
f0103e08:	66 90                	xchg   %ax,%ax
f0103e0a:	66 90                	xchg   %ax,%ax
f0103e0c:	66 90                	xchg   %ax,%ax
f0103e0e:	66 90                	xchg   %ax,%ax

f0103e10 <__umoddi3>:
f0103e10:	55                   	push   %ebp
f0103e11:	57                   	push   %edi
f0103e12:	56                   	push   %esi
f0103e13:	83 ec 14             	sub    $0x14,%esp
f0103e16:	8b 44 24 28          	mov    0x28(%esp),%eax
f0103e1a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0103e1e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0103e22:	89 c7                	mov    %eax,%edi
f0103e24:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e28:	8b 44 24 30          	mov    0x30(%esp),%eax
f0103e2c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0103e30:	89 34 24             	mov    %esi,(%esp)
f0103e33:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0103e37:	85 c0                	test   %eax,%eax
f0103e39:	89 c2                	mov    %eax,%edx
f0103e3b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0103e3f:	75 17                	jne    f0103e58 <__umoddi3+0x48>
f0103e41:	39 fe                	cmp    %edi,%esi
f0103e43:	76 4b                	jbe    f0103e90 <__umoddi3+0x80>
f0103e45:	89 c8                	mov    %ecx,%eax
f0103e47:	89 fa                	mov    %edi,%edx
f0103e49:	f7 f6                	div    %esi
f0103e4b:	89 d0                	mov    %edx,%eax
f0103e4d:	31 d2                	xor    %edx,%edx
f0103e4f:	83 c4 14             	add    $0x14,%esp
f0103e52:	5e                   	pop    %esi
f0103e53:	5f                   	pop    %edi
f0103e54:	5d                   	pop    %ebp
f0103e55:	c3                   	ret    
f0103e56:	66 90                	xchg   %ax,%ax
f0103e58:	39 f8                	cmp    %edi,%eax
f0103e5a:	77 54                	ja     f0103eb0 <__umoddi3+0xa0>
f0103e5c:	0f bd e8             	bsr    %eax,%ebp
f0103e5f:	83 f5 1f             	xor    $0x1f,%ebp
f0103e62:	75 5c                	jne    f0103ec0 <__umoddi3+0xb0>
f0103e64:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0103e68:	39 3c 24             	cmp    %edi,(%esp)
f0103e6b:	0f 87 e7 00 00 00    	ja     f0103f58 <__umoddi3+0x148>
f0103e71:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0103e75:	29 f1                	sub    %esi,%ecx
f0103e77:	19 c7                	sbb    %eax,%edi
f0103e79:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0103e7d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0103e81:	8b 44 24 08          	mov    0x8(%esp),%eax
f0103e85:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0103e89:	83 c4 14             	add    $0x14,%esp
f0103e8c:	5e                   	pop    %esi
f0103e8d:	5f                   	pop    %edi
f0103e8e:	5d                   	pop    %ebp
f0103e8f:	c3                   	ret    
f0103e90:	85 f6                	test   %esi,%esi
f0103e92:	89 f5                	mov    %esi,%ebp
f0103e94:	75 0b                	jne    f0103ea1 <__umoddi3+0x91>
f0103e96:	b8 01 00 00 00       	mov    $0x1,%eax
f0103e9b:	31 d2                	xor    %edx,%edx
f0103e9d:	f7 f6                	div    %esi
f0103e9f:	89 c5                	mov    %eax,%ebp
f0103ea1:	8b 44 24 04          	mov    0x4(%esp),%eax
f0103ea5:	31 d2                	xor    %edx,%edx
f0103ea7:	f7 f5                	div    %ebp
f0103ea9:	89 c8                	mov    %ecx,%eax
f0103eab:	f7 f5                	div    %ebp
f0103ead:	eb 9c                	jmp    f0103e4b <__umoddi3+0x3b>
f0103eaf:	90                   	nop
f0103eb0:	89 c8                	mov    %ecx,%eax
f0103eb2:	89 fa                	mov    %edi,%edx
f0103eb4:	83 c4 14             	add    $0x14,%esp
f0103eb7:	5e                   	pop    %esi
f0103eb8:	5f                   	pop    %edi
f0103eb9:	5d                   	pop    %ebp
f0103eba:	c3                   	ret    
f0103ebb:	90                   	nop
f0103ebc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0103ec0:	8b 04 24             	mov    (%esp),%eax
f0103ec3:	be 20 00 00 00       	mov    $0x20,%esi
f0103ec8:	89 e9                	mov    %ebp,%ecx
f0103eca:	29 ee                	sub    %ebp,%esi
f0103ecc:	d3 e2                	shl    %cl,%edx
f0103ece:	89 f1                	mov    %esi,%ecx
f0103ed0:	d3 e8                	shr    %cl,%eax
f0103ed2:	89 e9                	mov    %ebp,%ecx
f0103ed4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103ed8:	8b 04 24             	mov    (%esp),%eax
f0103edb:	09 54 24 04          	or     %edx,0x4(%esp)
f0103edf:	89 fa                	mov    %edi,%edx
f0103ee1:	d3 e0                	shl    %cl,%eax
f0103ee3:	89 f1                	mov    %esi,%ecx
f0103ee5:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103ee9:	8b 44 24 10          	mov    0x10(%esp),%eax
f0103eed:	d3 ea                	shr    %cl,%edx
f0103eef:	89 e9                	mov    %ebp,%ecx
f0103ef1:	d3 e7                	shl    %cl,%edi
f0103ef3:	89 f1                	mov    %esi,%ecx
f0103ef5:	d3 e8                	shr    %cl,%eax
f0103ef7:	89 e9                	mov    %ebp,%ecx
f0103ef9:	09 f8                	or     %edi,%eax
f0103efb:	8b 7c 24 10          	mov    0x10(%esp),%edi
f0103eff:	f7 74 24 04          	divl   0x4(%esp)
f0103f03:	d3 e7                	shl    %cl,%edi
f0103f05:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0103f09:	89 d7                	mov    %edx,%edi
f0103f0b:	f7 64 24 08          	mull   0x8(%esp)
f0103f0f:	39 d7                	cmp    %edx,%edi
f0103f11:	89 c1                	mov    %eax,%ecx
f0103f13:	89 14 24             	mov    %edx,(%esp)
f0103f16:	72 2c                	jb     f0103f44 <__umoddi3+0x134>
f0103f18:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f0103f1c:	72 22                	jb     f0103f40 <__umoddi3+0x130>
f0103f1e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0103f22:	29 c8                	sub    %ecx,%eax
f0103f24:	19 d7                	sbb    %edx,%edi
f0103f26:	89 e9                	mov    %ebp,%ecx
f0103f28:	89 fa                	mov    %edi,%edx
f0103f2a:	d3 e8                	shr    %cl,%eax
f0103f2c:	89 f1                	mov    %esi,%ecx
f0103f2e:	d3 e2                	shl    %cl,%edx
f0103f30:	89 e9                	mov    %ebp,%ecx
f0103f32:	d3 ef                	shr    %cl,%edi
f0103f34:	09 d0                	or     %edx,%eax
f0103f36:	89 fa                	mov    %edi,%edx
f0103f38:	83 c4 14             	add    $0x14,%esp
f0103f3b:	5e                   	pop    %esi
f0103f3c:	5f                   	pop    %edi
f0103f3d:	5d                   	pop    %ebp
f0103f3e:	c3                   	ret    
f0103f3f:	90                   	nop
f0103f40:	39 d7                	cmp    %edx,%edi
f0103f42:	75 da                	jne    f0103f1e <__umoddi3+0x10e>
f0103f44:	8b 14 24             	mov    (%esp),%edx
f0103f47:	89 c1                	mov    %eax,%ecx
f0103f49:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f0103f4d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0103f51:	eb cb                	jmp    f0103f1e <__umoddi3+0x10e>
f0103f53:	90                   	nop
f0103f54:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0103f58:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f0103f5c:	0f 82 0f ff ff ff    	jb     f0103e71 <__umoddi3+0x61>
f0103f62:	e9 1a ff ff ff       	jmp    f0103e81 <__umoddi3+0x71>
