
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
f0100046:	b8 d0 ef 17 f0       	mov    $0xf017efd0,%eax
f010004b:	2d a1 e0 17 f0       	sub    $0xf017e0a1,%eax
f0100050:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100054:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010005b:	00 
f010005c:	c7 04 24 a1 e0 17 f0 	movl   $0xf017e0a1,(%esp)
f0100063:	e8 61 4e 00 00       	call   f0104ec9 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f0100068:	e8 d2 04 00 00       	call   f010053f <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f010006d:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f0100074:	00 
f0100075:	c7 04 24 a0 53 10 f0 	movl   $0xf01053a0,(%esp)
f010007c:	e8 b4 38 00 00       	call   f0103935 <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f0100081:	e8 5a 11 00 00       	call   f01011e0 <mem_init>

	// Lab 3 user environment initialization functions
	env_init();
f0100086:	e8 93 31 00 00       	call   f010321e <env_init>
	trap_init();
f010008b:	90                   	nop
f010008c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100090:	e8 18 39 00 00       	call   f01039ad <trap_init>

#if defined(TEST)
	// Don't touch -- used by grading script!
	ENV_CREATE(TEST, ENV_TYPE_USER);
f0100095:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f010009c:	00 
f010009d:	c7 44 24 04 62 78 00 	movl   $0x7862,0x4(%esp)
f01000a4:	00 
f01000a5:	c7 04 24 95 2c 13 f0 	movl   $0xf0132c95,(%esp)
f01000ac:	e8 44 33 00 00       	call   f01033f5 <env_create>
#else
	// Touch all you want.	
	ENV_CREATE(user_hello, ENV_TYPE_USER);
#endif // TEST*
	// We only have one user environment for now, so just run it.
	env_run(&envs[0]);
f01000b1:	a1 0c e3 17 f0       	mov    0xf017e30c,%eax
f01000b6:	89 04 24             	mov    %eax,(%esp)
f01000b9:	e8 9b 37 00 00       	call   f0103859 <env_run>

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
f01000c9:	83 3d c0 ef 17 f0 00 	cmpl   $0x0,0xf017efc0
f01000d0:	75 3d                	jne    f010010f <_panic+0x51>
		goto dead;
	panicstr = fmt;
f01000d2:	89 35 c0 ef 17 f0    	mov    %esi,0xf017efc0

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
f01000eb:	c7 04 24 bb 53 10 f0 	movl   $0xf01053bb,(%esp)
f01000f2:	e8 3e 38 00 00       	call   f0103935 <cprintf>
	vcprintf(fmt, ap);
f01000f7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01000fb:	89 34 24             	mov    %esi,(%esp)
f01000fe:	e8 ff 37 00 00       	call   f0103902 <vcprintf>
	cprintf("\n");
f0100103:	c7 04 24 31 63 10 f0 	movl   $0xf0106331,(%esp)
f010010a:	e8 26 38 00 00       	call   f0103935 <cprintf>
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
f0100135:	c7 04 24 d3 53 10 f0 	movl   $0xf01053d3,(%esp)
f010013c:	e8 f4 37 00 00       	call   f0103935 <cprintf>
	vcprintf(fmt, ap);
f0100141:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100145:	8b 45 10             	mov    0x10(%ebp),%eax
f0100148:	89 04 24             	mov    %eax,(%esp)
f010014b:	e8 b2 37 00 00       	call   f0103902 <vcprintf>
	cprintf("\n");
f0100150:	c7 04 24 31 63 10 f0 	movl   $0xf0106331,(%esp)
f0100157:	e8 d9 37 00 00       	call   f0103935 <cprintf>
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
f010019b:	a1 e4 e2 17 f0       	mov    0xf017e2e4,%eax
f01001a0:	8d 48 01             	lea    0x1(%eax),%ecx
f01001a3:	89 0d e4 e2 17 f0    	mov    %ecx,0xf017e2e4
f01001a9:	88 90 e0 e0 17 f0    	mov    %dl,-0xfe81f20(%eax)
		if (cons.wpos == CONSBUFSIZE)
f01001af:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f01001b5:	75 0a                	jne    f01001c1 <cons_intr+0x35>
			cons.wpos = 0;
f01001b7:	c7 05 e4 e2 17 f0 00 	movl   $0x0,0xf017e2e4
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
f01001e7:	83 0d c0 e0 17 f0 40 	orl    $0x40,0xf017e0c0
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
f01001ff:	8b 0d c0 e0 17 f0    	mov    0xf017e0c0,%ecx
f0100205:	89 cb                	mov    %ecx,%ebx
f0100207:	83 e3 40             	and    $0x40,%ebx
f010020a:	83 e0 7f             	and    $0x7f,%eax
f010020d:	85 db                	test   %ebx,%ebx
f010020f:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f0100212:	0f b6 d2             	movzbl %dl,%edx
f0100215:	0f b6 82 40 55 10 f0 	movzbl -0xfefaac0(%edx),%eax
f010021c:	83 c8 40             	or     $0x40,%eax
f010021f:	0f b6 c0             	movzbl %al,%eax
f0100222:	f7 d0                	not    %eax
f0100224:	21 c1                	and    %eax,%ecx
f0100226:	89 0d c0 e0 17 f0    	mov    %ecx,0xf017e0c0
		return 0;
f010022c:	b8 00 00 00 00       	mov    $0x0,%eax
f0100231:	e9 9d 00 00 00       	jmp    f01002d3 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f0100236:	8b 0d c0 e0 17 f0    	mov    0xf017e0c0,%ecx
f010023c:	f6 c1 40             	test   $0x40,%cl
f010023f:	74 0e                	je     f010024f <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f0100241:	83 c8 80             	or     $0xffffff80,%eax
f0100244:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f0100246:	83 e1 bf             	and    $0xffffffbf,%ecx
f0100249:	89 0d c0 e0 17 f0    	mov    %ecx,0xf017e0c0
	}

	shift |= shiftcode[data];
f010024f:	0f b6 d2             	movzbl %dl,%edx
f0100252:	0f b6 82 40 55 10 f0 	movzbl -0xfefaac0(%edx),%eax
f0100259:	0b 05 c0 e0 17 f0    	or     0xf017e0c0,%eax
	shift ^= togglecode[data];
f010025f:	0f b6 8a 40 54 10 f0 	movzbl -0xfefabc0(%edx),%ecx
f0100266:	31 c8                	xor    %ecx,%eax
f0100268:	a3 c0 e0 17 f0       	mov    %eax,0xf017e0c0

	c = charcode[shift & (CTL | SHIFT)][data];
f010026d:	89 c1                	mov    %eax,%ecx
f010026f:	83 e1 03             	and    $0x3,%ecx
f0100272:	8b 0c 8d 20 54 10 f0 	mov    -0xfefabe0(,%ecx,4),%ecx
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
f01002b2:	c7 04 24 ed 53 10 f0 	movl   $0xf01053ed,(%esp)
f01002b9:	e8 77 36 00 00       	call   f0103935 <cprintf>
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
f010039c:	0f b7 05 e8 e2 17 f0 	movzwl 0xf017e2e8,%eax
f01003a3:	66 85 c0             	test   %ax,%ax
f01003a6:	0f 84 e5 00 00 00    	je     f0100491 <cons_putc+0x1b8>
			crt_pos--;
f01003ac:	83 e8 01             	sub    $0x1,%eax
f01003af:	66 a3 e8 e2 17 f0    	mov    %ax,0xf017e2e8
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f01003b5:	0f b7 c0             	movzwl %ax,%eax
f01003b8:	66 81 e7 00 ff       	and    $0xff00,%di
f01003bd:	83 cf 20             	or     $0x20,%edi
f01003c0:	8b 15 ec e2 17 f0    	mov    0xf017e2ec,%edx
f01003c6:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f01003ca:	eb 78                	jmp    f0100444 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f01003cc:	66 83 05 e8 e2 17 f0 	addw   $0x50,0xf017e2e8
f01003d3:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f01003d4:	0f b7 05 e8 e2 17 f0 	movzwl 0xf017e2e8,%eax
f01003db:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f01003e1:	c1 e8 16             	shr    $0x16,%eax
f01003e4:	8d 04 80             	lea    (%eax,%eax,4),%eax
f01003e7:	c1 e0 04             	shl    $0x4,%eax
f01003ea:	66 a3 e8 e2 17 f0    	mov    %ax,0xf017e2e8
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
f0100426:	0f b7 05 e8 e2 17 f0 	movzwl 0xf017e2e8,%eax
f010042d:	8d 50 01             	lea    0x1(%eax),%edx
f0100430:	66 89 15 e8 e2 17 f0 	mov    %dx,0xf017e2e8
f0100437:	0f b7 c0             	movzwl %ax,%eax
f010043a:	8b 15 ec e2 17 f0    	mov    0xf017e2ec,%edx
f0100440:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f0100444:	66 81 3d e8 e2 17 f0 	cmpw   $0x7cf,0xf017e2e8
f010044b:	cf 07 
f010044d:	76 42                	jbe    f0100491 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f010044f:	a1 ec e2 17 f0       	mov    0xf017e2ec,%eax
f0100454:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010045b:	00 
f010045c:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100462:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100466:	89 04 24             	mov    %eax,(%esp)
f0100469:	e8 a8 4a 00 00       	call   f0104f16 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010046e:	8b 15 ec e2 17 f0    	mov    0xf017e2ec,%edx
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
f0100489:	66 83 2d e8 e2 17 f0 	subw   $0x50,0xf017e2e8
f0100490:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100491:	8b 0d f0 e2 17 f0    	mov    0xf017e2f0,%ecx
f0100497:	b8 0e 00 00 00       	mov    $0xe,%eax
f010049c:	89 ca                	mov    %ecx,%edx
f010049e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010049f:	0f b7 1d e8 e2 17 f0 	movzwl 0xf017e2e8,%ebx
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
f01004c7:	83 3d f4 e2 17 f0 00 	cmpl   $0x0,0xf017e2f4
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
f0100505:	a1 e0 e2 17 f0       	mov    0xf017e2e0,%eax
f010050a:	3b 05 e4 e2 17 f0    	cmp    0xf017e2e4,%eax
f0100510:	74 26                	je     f0100538 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f0100512:	8d 50 01             	lea    0x1(%eax),%edx
f0100515:	89 15 e0 e2 17 f0    	mov    %edx,0xf017e2e0
f010051b:	0f b6 88 e0 e0 17 f0 	movzbl -0xfe81f20(%eax),%ecx
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
f010052c:	c7 05 e0 e2 17 f0 00 	movl   $0x0,0xf017e2e0
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
f0100565:	c7 05 f0 e2 17 f0 b4 	movl   $0x3b4,0xf017e2f0
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
f010057d:	c7 05 f0 e2 17 f0 d4 	movl   $0x3d4,0xf017e2f0
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
f010058c:	8b 0d f0 e2 17 f0    	mov    0xf017e2f0,%ecx
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
f01005b1:	89 3d ec e2 17 f0    	mov    %edi,0xf017e2ec
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f01005b7:	0f b6 d8             	movzbl %al,%ebx
f01005ba:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f01005bc:	66 89 35 e8 e2 17 f0 	mov    %si,0xf017e2e8
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
f0100610:	89 0d f4 e2 17 f0    	mov    %ecx,0xf017e2f4
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
f0100620:	c7 04 24 f9 53 10 f0 	movl   $0xf01053f9,(%esp)
f0100627:	e8 09 33 00 00       	call   f0103935 <cprintf>
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
f0100666:	c7 44 24 08 40 56 10 	movl   $0xf0105640,0x8(%esp)
f010066d:	f0 
f010066e:	c7 44 24 04 5e 56 10 	movl   $0xf010565e,0x4(%esp)
f0100675:	f0 
f0100676:	c7 04 24 63 56 10 f0 	movl   $0xf0105663,(%esp)
f010067d:	e8 b3 32 00 00       	call   f0103935 <cprintf>
f0100682:	c7 44 24 08 00 57 10 	movl   $0xf0105700,0x8(%esp)
f0100689:	f0 
f010068a:	c7 44 24 04 6c 56 10 	movl   $0xf010566c,0x4(%esp)
f0100691:	f0 
f0100692:	c7 04 24 63 56 10 f0 	movl   $0xf0105663,(%esp)
f0100699:	e8 97 32 00 00       	call   f0103935 <cprintf>
f010069e:	c7 44 24 08 28 57 10 	movl   $0xf0105728,0x8(%esp)
f01006a5:	f0 
f01006a6:	c7 44 24 04 75 56 10 	movl   $0xf0105675,0x4(%esp)
f01006ad:	f0 
f01006ae:	c7 04 24 63 56 10 f0 	movl   $0xf0105663,(%esp)
f01006b5:	e8 7b 32 00 00       	call   f0103935 <cprintf>
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
f01006c7:	c7 04 24 7f 56 10 f0 	movl   $0xf010567f,(%esp)
f01006ce:	e8 62 32 00 00       	call   f0103935 <cprintf>
	cprintf(" this is work 1 insert:\n");
f01006d3:	c7 04 24 98 56 10 f0 	movl   $0xf0105698,(%esp)
f01006da:	e8 56 32 00 00       	call   f0103935 <cprintf>
	cprintf(" this is hex number %02x  and this is oct number %02o \n" , 15,15);
f01006df:	c7 44 24 08 0f 00 00 	movl   $0xf,0x8(%esp)
f01006e6:	00 
f01006e7:	c7 44 24 04 0f 00 00 	movl   $0xf,0x4(%esp)
f01006ee:	00 
f01006ef:	c7 04 24 54 57 10 f0 	movl   $0xf0105754,(%esp)
f01006f6:	e8 3a 32 00 00       	call   f0103935 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys) \n ", entry, entry - KERNBASE);
f01006fb:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f0100702:	00 
f0100703:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f010070a:	f0 
f010070b:	c7 04 24 8c 57 10 f0 	movl   $0xf010578c,(%esp)
f0100712:	e8 1e 32 00 00       	call   f0103935 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f0100717:	c7 44 24 08 87 53 10 	movl   $0x105387,0x8(%esp)
f010071e:	00 
f010071f:	c7 44 24 04 87 53 10 	movl   $0xf0105387,0x4(%esp)
f0100726:	f0 
f0100727:	c7 04 24 b4 57 10 f0 	movl   $0xf01057b4,(%esp)
f010072e:	e8 02 32 00 00       	call   f0103935 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f0100733:	c7 44 24 08 a1 e0 17 	movl   $0x17e0a1,0x8(%esp)
f010073a:	00 
f010073b:	c7 44 24 04 a1 e0 17 	movl   $0xf017e0a1,0x4(%esp)
f0100742:	f0 
f0100743:	c7 04 24 d8 57 10 f0 	movl   $0xf01057d8,(%esp)
f010074a:	e8 e6 31 00 00       	call   f0103935 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f010074f:	c7 44 24 08 d0 ef 17 	movl   $0x17efd0,0x8(%esp)
f0100756:	00 
f0100757:	c7 44 24 04 d0 ef 17 	movl   $0xf017efd0,0x4(%esp)
f010075e:	f0 
f010075f:	c7 04 24 fc 57 10 f0 	movl   $0xf01057fc,(%esp)
f0100766:	e8 ca 31 00 00       	call   f0103935 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f010076b:	b8 cf f3 17 f0       	mov    $0xf017f3cf,%eax
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
f0100787:	c7 04 24 20 58 10 f0 	movl   $0xf0105820,(%esp)
f010078e:	e8 a2 31 00 00       	call   f0103935 <cprintf>
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
f01007a2:	c7 04 24 b1 56 10 f0 	movl   $0xf01056b1,(%esp)
f01007a9:	e8 87 31 00 00       	call   f0103935 <cprintf>
	cprintf("\n");
f01007ae:	c7 04 24 31 63 10 f0 	movl   $0xf0106331,(%esp)
f01007b5:	e8 7b 31 00 00       	call   f0103935 <cprintf>

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
f0100811:	c7 04 24 4c 58 10 f0 	movl   $0xf010584c,(%esp)
f0100818:	e8 18 31 00 00       	call   f0103935 <cprintf>
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
f010083b:	c7 04 24 88 58 10 f0 	movl   $0xf0105888,(%esp)
f0100842:	e8 ee 30 00 00       	call   f0103935 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f0100847:	c7 04 24 ac 58 10 f0 	movl   $0xf01058ac,(%esp)
f010084e:	e8 e2 30 00 00       	call   f0103935 <cprintf>

	if (tf != NULL)
f0100853:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f0100857:	74 0b                	je     f0100864 <monitor+0x32>
		print_trapframe(tf);
f0100859:	8b 45 08             	mov    0x8(%ebp),%eax
f010085c:	89 04 24             	mov    %eax,(%esp)
f010085f:	e8 00 35 00 00       	call   f0103d64 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f0100864:	c7 04 24 c2 56 10 f0 	movl   $0xf01056c2,(%esp)
f010086b:	e8 80 43 00 00       	call   f0104bf0 <readline>
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
f010089c:	c7 04 24 c6 56 10 f0 	movl   $0xf01056c6,(%esp)
f01008a3:	e8 c1 45 00 00       	call   f0104e69 <strchr>
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
f01008be:	c7 04 24 cb 56 10 f0 	movl   $0xf01056cb,(%esp)
f01008c5:	e8 6b 30 00 00       	call   f0103935 <cprintf>
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
f01008ed:	c7 04 24 c6 56 10 f0 	movl   $0xf01056c6,(%esp)
f01008f4:	e8 70 45 00 00       	call   f0104e69 <strchr>
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
f0100917:	8b 04 85 e0 58 10 f0 	mov    -0xfefa720(,%eax,4),%eax
f010091e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100922:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100925:	89 04 24             	mov    %eax,(%esp)
f0100928:	e8 b8 44 00 00       	call   f0104de5 <strcmp>
f010092d:	85 c0                	test   %eax,%eax
f010092f:	75 24                	jne    f0100955 <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100931:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100934:	8b 55 08             	mov    0x8(%ebp),%edx
f0100937:	89 54 24 08          	mov    %edx,0x8(%esp)
f010093b:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f010093e:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100942:	89 34 24             	mov    %esi,(%esp)
f0100945:	ff 14 85 e8 58 10 f0 	call   *-0xfefa718(,%eax,4)
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
f0100964:	c7 04 24 e8 56 10 f0 	movl   $0xf01056e8,(%esp)
f010096b:	e8 c5 2f 00 00       	call   f0103935 <cprintf>
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
f0100997:	83 3d f8 e2 17 f0 00 	cmpl   $0x0,0xf017e2f8
f010099e:	75 36                	jne    f01009d6 <boot_alloc+0x46>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f01009a0:	ba cf ff 17 f0       	mov    $0xf017ffcf,%edx
f01009a5:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f01009ab:	89 15 f8 e2 17 f0    	mov    %edx,0xf017e2f8
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	 if (n > 0) {
f01009b1:	85 c0                	test   %eax,%eax
f01009b3:	74 19                	je     f01009ce <boot_alloc+0x3e>
                      result = nextfree;
f01009b5:	8b 1d f8 e2 17 f0    	mov    0xf017e2f8,%ebx
                      nextfree += ROUNDUP(n, PGSIZE);
f01009bb:	05 ff 0f 00 00       	add    $0xfff,%eax
f01009c0:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01009c5:	01 d8                	add    %ebx,%eax
f01009c7:	a3 f8 e2 17 f0       	mov    %eax,0xf017e2f8
f01009cc:	eb 0e                	jmp    f01009dc <boot_alloc+0x4c>
               } else if (n == 0)
                      result = nextfree;
f01009ce:	8b 1d f8 e2 17 f0    	mov    0xf017e2f8,%ebx
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
f01009e0:	c7 04 24 04 59 10 f0 	movl   $0xf0105904,(%esp)
f01009e7:	e8 49 2f 00 00       	call   f0103935 <cprintf>
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
f0100a0a:	3b 0d c4 ef 17 f0    	cmp    0xf017efc4,%ecx
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
f0100a1c:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f0100a23:	f0 
f0100a24:	c7 44 24 04 3e 03 00 	movl   $0x33e,0x4(%esp)
f0100a2b:	00 
f0100a2c:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0100a79:	c7 44 24 08 74 59 10 	movl   $0xf0105974,0x8(%esp)
f0100a80:	f0 
f0100a81:	c7 44 24 04 7c 02 00 	movl   $0x27c,0x4(%esp)
f0100a88:	00 
f0100a89:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0100aa3:	2b 15 cc ef 17 f0    	sub    0xf017efcc,%edx
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
f0100ad9:	a3 00 e3 17 f0       	mov    %eax,0xf017e300
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
f0100aeb:	2b 05 cc ef 17 f0    	sub    0xf017efcc,%eax
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
f0100b05:	3b 15 c4 ef 17 f0    	cmp    0xf017efc4,%edx
f0100b0b:	72 20                	jb     f0100b2d <check_page_free_list+0xca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100b0d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100b11:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f0100b18:	f0 
f0100b19:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100b20:	00 
f0100b21:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
f0100b28:	e8 91 f5 ff ff       	call   f01000be <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100b2d:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100b34:	00 
f0100b35:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100b3c:	00 
	return (void *)(pa + KERNBASE);
f0100b3d:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100b42:	89 04 24             	mov    %eax,(%esp)
f0100b45:	e8 7f 43 00 00       	call   f0104ec9 <memset>
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
f0100b5d:	8b 15 00 e3 17 f0    	mov    0xf017e300,%edx
f0100b63:	85 d2                	test   %edx,%edx
f0100b65:	0f 84 f2 01 00 00    	je     f0100d5d <check_page_free_list+0x2fa>
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100b6b:	8b 1d cc ef 17 f0    	mov    0xf017efcc,%ebx
f0100b71:	39 da                	cmp    %ebx,%edx
f0100b73:	72 3f                	jb     f0100bb4 <check_page_free_list+0x151>
		assert(pp < pages + npages);
f0100b75:	a1 c4 ef 17 f0       	mov    0xf017efc4,%eax
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
f0100bb4:	c7 44 24 0c bb 60 10 	movl   $0xf01060bb,0xc(%esp)
f0100bbb:	f0 
f0100bbc:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0100bc3:	f0 
f0100bc4:	c7 44 24 04 96 02 00 	movl   $0x296,0x4(%esp)
f0100bcb:	00 
f0100bcc:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0100bd3:	e8 e6 f4 ff ff       	call   f01000be <_panic>
		assert(pp < pages + npages);
f0100bd8:	3b 55 d4             	cmp    -0x2c(%ebp),%edx
f0100bdb:	72 24                	jb     f0100c01 <check_page_free_list+0x19e>
f0100bdd:	c7 44 24 0c dc 60 10 	movl   $0xf01060dc,0xc(%esp)
f0100be4:	f0 
f0100be5:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0100bec:	f0 
f0100bed:	c7 44 24 04 97 02 00 	movl   $0x297,0x4(%esp)
f0100bf4:	00 
f0100bf5:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0100bfc:	e8 bd f4 ff ff       	call   f01000be <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100c01:	89 d0                	mov    %edx,%eax
f0100c03:	2b 45 d0             	sub    -0x30(%ebp),%eax
f0100c06:	a8 07                	test   $0x7,%al
f0100c08:	74 24                	je     f0100c2e <check_page_free_list+0x1cb>
f0100c0a:	c7 44 24 0c 98 59 10 	movl   $0xf0105998,0xc(%esp)
f0100c11:	f0 
f0100c12:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0100c19:	f0 
f0100c1a:	c7 44 24 04 98 02 00 	movl   $0x298,0x4(%esp)
f0100c21:	00 
f0100c22:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0100c29:	e8 90 f4 ff ff       	call   f01000be <_panic>
f0100c2e:	c1 f8 03             	sar    $0x3,%eax
f0100c31:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100c34:	85 c0                	test   %eax,%eax
f0100c36:	75 24                	jne    f0100c5c <check_page_free_list+0x1f9>
f0100c38:	c7 44 24 0c f0 60 10 	movl   $0xf01060f0,0xc(%esp)
f0100c3f:	f0 
f0100c40:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0100c47:	f0 
f0100c48:	c7 44 24 04 9b 02 00 	movl   $0x29b,0x4(%esp)
f0100c4f:	00 
f0100c50:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0100c57:	e8 62 f4 ff ff       	call   f01000be <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100c5c:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100c61:	75 2e                	jne    f0100c91 <check_page_free_list+0x22e>
f0100c63:	c7 44 24 0c 01 61 10 	movl   $0xf0106101,0xc(%esp)
f0100c6a:	f0 
f0100c6b:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0100c72:	f0 
f0100c73:	c7 44 24 04 9c 02 00 	movl   $0x29c,0x4(%esp)
f0100c7a:	00 
f0100c7b:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0100c98:	c7 44 24 0c cc 59 10 	movl   $0xf01059cc,0xc(%esp)
f0100c9f:	f0 
f0100ca0:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0100ca7:	f0 
f0100ca8:	c7 44 24 04 9d 02 00 	movl   $0x29d,0x4(%esp)
f0100caf:	00 
f0100cb0:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0100cb7:	e8 02 f4 ff ff       	call   f01000be <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100cbc:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100cc1:	75 24                	jne    f0100ce7 <check_page_free_list+0x284>
f0100cc3:	c7 44 24 0c 1a 61 10 	movl   $0xf010611a,0xc(%esp)
f0100cca:	f0 
f0100ccb:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0100cd2:	f0 
f0100cd3:	c7 44 24 04 9e 02 00 	movl   $0x29e,0x4(%esp)
f0100cda:	00 
f0100cdb:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0100cfc:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f0100d03:	f0 
f0100d04:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100d0b:	00 
f0100d0c:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
f0100d13:	e8 a6 f3 ff ff       	call   f01000be <_panic>
	return (void *)(pa + KERNBASE);
f0100d18:	81 e9 00 00 00 10    	sub    $0x10000000,%ecx
f0100d1e:	39 4d cc             	cmp    %ecx,-0x34(%ebp)
f0100d21:	76 29                	jbe    f0100d4c <check_page_free_list+0x2e9>
f0100d23:	c7 44 24 0c f0 59 10 	movl   $0xf01059f0,0xc(%esp)
f0100d2a:	f0 
f0100d2b:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0100d32:	f0 
f0100d33:	c7 44 24 04 9f 02 00 	movl   $0x29f,0x4(%esp)
f0100d3a:	00 
f0100d3b:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0100d5d:	c7 44 24 0c 34 61 10 	movl   $0xf0106134,0xc(%esp)
f0100d64:	f0 
f0100d65:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0100d6c:	f0 
f0100d6d:	c7 44 24 04 a7 02 00 	movl   $0x2a7,0x4(%esp)
f0100d74:	00 
f0100d75:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0100d7c:	e8 3d f3 ff ff       	call   f01000be <_panic>
	assert(nfree_extmem > 0);
f0100d81:	85 f6                	test   %esi,%esi
f0100d83:	7f 53                	jg     f0100dd8 <check_page_free_list+0x375>
f0100d85:	c7 44 24 0c 46 61 10 	movl   $0xf0106146,0xc(%esp)
f0100d8c:	f0 
f0100d8d:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0100d94:	f0 
f0100d95:	c7 44 24 04 a8 02 00 	movl   $0x2a8,0x4(%esp)
f0100d9c:	00 
f0100d9d:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0100da4:	e8 15 f3 ff ff       	call   f01000be <_panic>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100da9:	a1 00 e3 17 f0       	mov    0xf017e300,%eax
f0100dae:	85 c0                	test   %eax,%eax
f0100db0:	0f 85 df fc ff ff    	jne    f0100a95 <check_page_free_list+0x32>
f0100db6:	e9 be fc ff ff       	jmp    f0100a79 <check_page_free_list+0x16>
f0100dbb:	83 3d 00 e3 17 f0 00 	cmpl   $0x0,0xf017e300
f0100dc2:	0f 84 b1 fc ff ff    	je     f0100a79 <check_page_free_list+0x16>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100dc8:	8b 1d 00 e3 17 f0    	mov    0xf017e300,%ebx
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
f0100de7:	83 3d c4 ef 17 f0 00 	cmpl   $0x0,0xf017efc4
f0100dee:	0f 84 a5 00 00 00    	je     f0100e99 <page_init+0xb9>
f0100df4:	8b 1d 00 e3 17 f0    	mov    0xf017e300,%ebx
f0100dfa:	b8 00 00 00 00       	mov    $0x0,%eax
f0100dff:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
		pages[i].pp_ref = 0;
f0100e06:	89 d1                	mov    %edx,%ecx
f0100e08:	03 0d cc ef 17 f0    	add    0xf017efcc,%ecx
f0100e0e:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0100e14:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f0100e16:	03 15 cc ef 17 f0    	add    0xf017efcc,%edx
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100e1c:	83 c0 01             	add    $0x1,%eax
f0100e1f:	8b 0d c4 ef 17 f0    	mov    0xf017efc4,%ecx
f0100e25:	39 c1                	cmp    %eax,%ecx
f0100e27:	76 04                	jbe    f0100e2d <page_init+0x4d>
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f0100e29:	89 d3                	mov    %edx,%ebx
f0100e2b:	eb d2                	jmp    f0100dff <page_init+0x1f>
f0100e2d:	89 15 00 e3 17 f0    	mov    %edx,0xf017e300
	}

	//remove physical page 0 from page_free_list
             pages[1].pp_link = NULL;
f0100e33:	a1 cc ef 17 f0       	mov    0xf017efcc,%eax
f0100e38:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100e3f:	81 f9 a0 00 00 00    	cmp    $0xa0,%ecx
f0100e45:	77 1c                	ja     f0100e63 <page_init+0x83>
		panic("pa2page called with invalid pa");
f0100e47:	c7 44 24 08 38 5a 10 	movl   $0xf0105a38,0x8(%esp)
f0100e4e:	f0 
f0100e4f:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0100e56:	00 
f0100e57:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
f0100e5e:	e8 5b f2 ff ff       	call   f01000be <_panic>

              //remove continuous pages from page_free_list
              extern char end[];                        //this is an *virtual* address
              struct Page *ppg_start = pa2page((physaddr_t)IOPHYSMEM);                                                //at low *physical* address
              struct Page *ppg_end = pa2page((physaddr_t)((end - KERNBASE) + PGSIZE + sizeof(struct Page)*npages)+sizeof(struct Env)*NENV);    //at high *physical* address
f0100e63:	8d 14 cd d0 7f 19 00 	lea    0x197fd0(,%ecx,8),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100e6a:	c1 ea 0c             	shr    $0xc,%edx
f0100e6d:	39 d1                	cmp    %edx,%ecx
f0100e6f:	77 1c                	ja     f0100e8d <page_init+0xad>
		panic("pa2page called with invalid pa");
f0100e71:	c7 44 24 08 38 5a 10 	movl   $0xf0105a38,0x8(%esp)
f0100e78:	f0 
f0100e79:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0100e80:	00 
f0100e81:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
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
f0100e99:	a1 cc ef 17 f0       	mov    0xf017efcc,%eax
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
f0100eb4:	8b 1d 00 e3 17 f0    	mov    0xf017e300,%ebx
f0100eba:	85 db                	test   %ebx,%ebx
f0100ebc:	74 69                	je     f0100f27 <page_alloc+0x7a>
                             return NULL;

             struct Page *result = page_free_list;
             page_free_list = page_free_list->pp_link;
f0100ebe:	8b 03                	mov    (%ebx),%eax
f0100ec0:	a3 00 e3 17 f0       	mov    %eax,0xf017e300
    
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
f0100ecd:	2b 05 cc ef 17 f0    	sub    0xf017efcc,%eax
f0100ed3:	c1 f8 03             	sar    $0x3,%eax
f0100ed6:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100ed9:	89 c2                	mov    %eax,%edx
f0100edb:	c1 ea 0c             	shr    $0xc,%edx
f0100ede:	3b 15 c4 ef 17 f0    	cmp    0xf017efc4,%edx
f0100ee4:	72 20                	jb     f0100f06 <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100ee6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100eea:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f0100ef1:	f0 
f0100ef2:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100ef9:	00 
f0100efa:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
f0100f01:	e8 b8 f1 ff ff       	call   f01000be <_panic>
                    memset(page2kva(result), 0, PGSIZE);
f0100f06:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0100f0d:	00 
f0100f0e:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0100f15:	00 
	return (void *)(pa + KERNBASE);
f0100f16:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100f1b:	89 04 24             	mov    %eax,(%esp)
f0100f1e:	e8 a6 3f 00 00       	call   f0104ec9 <memset>
        
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
f0100f38:	8b 15 00 e3 17 f0    	mov    0xf017e300,%edx
f0100f3e:	89 10                	mov    %edx,(%eax)
              page_free_list = pp;
f0100f40:	a3 00 e3 17 f0       	mov    %eax,0xf017e300
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
f0100fab:	2b 15 cc ef 17 f0    	sub    0xf017efcc,%edx
f0100fb1:	c1 fa 03             	sar    $0x3,%edx
f0100fb4:	c1 e2 0c             	shl    $0xc,%edx
                                                  pgdir[PDX(va)] = page2pa(tmp) | PTE_P | PTE_W |PTE_U;    //save the physical address of newly allocated page in page dir
f0100fb7:	83 ca 07             	or     $0x7,%edx
f0100fba:	89 16                	mov    %edx,(%esi)
f0100fbc:	2b 05 cc ef 17 f0    	sub    0xf017efcc,%eax
f0100fc2:	c1 f8 03             	sar    $0x3,%eax
f0100fc5:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100fc8:	89 c2                	mov    %eax,%edx
f0100fca:	c1 ea 0c             	shr    $0xc,%edx
f0100fcd:	3b 15 c4 ef 17 f0    	cmp    0xf017efc4,%edx
f0100fd3:	72 20                	jb     f0100ff5 <pgdir_walk+0x8b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100fd5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100fd9:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f0100fe0:	f0 
f0100fe1:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100fe8:	00 
f0100fe9:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
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
f0100fff:	8b 15 c4 ef 17 f0    	mov    0xf017efc4,%edx
f0101005:	39 d0                	cmp    %edx,%eax
f0101007:	72 1c                	jb     f0101025 <pgdir_walk+0xbb>
		panic("pa2page called with invalid pa");
f0101009:	c7 44 24 08 38 5a 10 	movl   $0xf0105a38,0x8(%esp)
f0101010:	f0 
f0101011:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101018:	00 
f0101019:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
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
f0101032:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f0101039:	f0 
f010103a:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101041:	00 
f0101042:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
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
f01010a7:	3b 05 c4 ef 17 f0    	cmp    0xf017efc4,%eax
f01010ad:	72 1c                	jb     f01010cb <page_lookup+0x57>
		panic("pa2page called with invalid pa");
f01010af:	c7 44 24 08 38 5a 10 	movl   $0xf0105a38,0x8(%esp)
f01010b6:	f0 
f01010b7:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01010be:	00 
f01010bf:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
f01010c6:	e8 f3 ef ff ff       	call   f01000be <_panic>
	return &pages[PGNUM(pa)];
f01010cb:	8b 15 cc ef 17 f0    	mov    0xf017efcc,%edx
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
f0101168:	2b 3d cc ef 17 f0    	sub    0xf017efcc,%edi
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
f01011b7:	2b 15 cc ef 17 f0    	sub    0xf017efcc,%edx
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
f01011f0:	e8 d0 26 00 00       	call   f01038c5 <mc146818_read>
f01011f5:	89 c3                	mov    %eax,%ebx
f01011f7:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f01011fe:	e8 c2 26 00 00       	call   f01038c5 <mc146818_read>
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
f010121b:	a3 04 e3 17 f0       	mov    %eax,0xf017e304
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0101220:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f0101227:	e8 99 26 00 00       	call   f01038c5 <mc146818_read>
f010122c:	89 c3                	mov    %eax,%ebx
f010122e:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f0101235:	e8 8b 26 00 00       	call   f01038c5 <mc146818_read>
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
f010125c:	89 15 c4 ef 17 f0    	mov    %edx,0xf017efc4
f0101262:	eb 0c                	jmp    f0101270 <mem_init+0x90>
	else
		npages = npages_basemem;
f0101264:	8b 15 04 e3 17 f0    	mov    0xf017e304,%edx
f010126a:	89 15 c4 ef 17 f0    	mov    %edx,0xf017efc4

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
f010127a:	a1 04 e3 17 f0       	mov    0xf017e304,%eax
f010127f:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101282:	c1 e8 0a             	shr    $0xa,%eax
f0101285:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f0101289:	a1 c4 ef 17 f0       	mov    0xf017efc4,%eax
f010128e:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101291:	c1 e8 0a             	shr    $0xa,%eax
f0101294:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101298:	c7 04 24 58 5a 10 f0 	movl   $0xf0105a58,(%esp)
f010129f:	e8 91 26 00 00       	call   f0103935 <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);  // first_level pagedir
f01012a4:	b8 00 10 00 00       	mov    $0x1000,%eax
f01012a9:	e8 e2 f6 ff ff       	call   f0100990 <boot_alloc>
f01012ae:	a3 c8 ef 17 f0       	mov    %eax,0xf017efc8
	memset(kern_pgdir, 0, PGSIZE);
f01012b3:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01012ba:	00 
f01012bb:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01012c2:	00 
f01012c3:	89 04 24             	mov    %eax,(%esp)
f01012c6:	e8 fe 3b 00 00       	call   f0104ec9 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f01012cb:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01012d0:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01012d5:	77 20                	ja     f01012f7 <mem_init+0x117>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01012d7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01012db:	c7 44 24 08 94 5a 10 	movl   $0xf0105a94,0x8(%esp)
f01012e2:	f0 
f01012e3:	c7 44 24 04 94 00 00 	movl   $0x94,0x4(%esp)
f01012ea:	00 
f01012eb:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0101306:	a1 c4 ef 17 f0       	mov    0xf017efc4,%eax
f010130b:	c1 e0 03             	shl    $0x3,%eax
f010130e:	e8 7d f6 ff ff       	call   f0100990 <boot_alloc>
f0101313:	a3 cc ef 17 f0       	mov    %eax,0xf017efcc


	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.
	envs =  (struct Env *)boot_alloc(NENV * sizeof(struct Env));
f0101318:	b8 00 80 01 00       	mov    $0x18000,%eax
f010131d:	e8 6e f6 ff ff       	call   f0100990 <boot_alloc>
f0101322:	a3 0c e3 17 f0       	mov    %eax,0xf017e30c
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
f0101336:	83 3d cc ef 17 f0 00 	cmpl   $0x0,0xf017efcc
f010133d:	75 1c                	jne    f010135b <mem_init+0x17b>
		panic("'pages' is a null pointer!");
f010133f:	c7 44 24 08 57 61 10 	movl   $0xf0106157,0x8(%esp)
f0101346:	f0 
f0101347:	c7 44 24 04 b9 02 00 	movl   $0x2b9,0x4(%esp)
f010134e:	00 
f010134f:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101356:	e8 63 ed ff ff       	call   f01000be <_panic>

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010135b:	a1 00 e3 17 f0       	mov    0xf017e300,%eax
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
f010138b:	c7 44 24 0c 72 61 10 	movl   $0xf0106172,0xc(%esp)
f0101392:	f0 
f0101393:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f010139a:	f0 
f010139b:	c7 44 24 04 c1 02 00 	movl   $0x2c1,0x4(%esp)
f01013a2:	00 
f01013a3:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01013aa:	e8 0f ed ff ff       	call   f01000be <_panic>
	assert((pp1 = page_alloc(0)));
f01013af:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01013b6:	e8 f2 fa ff ff       	call   f0100ead <page_alloc>
f01013bb:	89 c6                	mov    %eax,%esi
f01013bd:	85 c0                	test   %eax,%eax
f01013bf:	75 24                	jne    f01013e5 <mem_init+0x205>
f01013c1:	c7 44 24 0c 88 61 10 	movl   $0xf0106188,0xc(%esp)
f01013c8:	f0 
f01013c9:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f01013d0:	f0 
f01013d1:	c7 44 24 04 c2 02 00 	movl   $0x2c2,0x4(%esp)
f01013d8:	00 
f01013d9:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01013e0:	e8 d9 ec ff ff       	call   f01000be <_panic>
	assert((pp2 = page_alloc(0)));
f01013e5:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01013ec:	e8 bc fa ff ff       	call   f0100ead <page_alloc>
f01013f1:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01013f4:	85 c0                	test   %eax,%eax
f01013f6:	75 24                	jne    f010141c <mem_init+0x23c>
f01013f8:	c7 44 24 0c 9e 61 10 	movl   $0xf010619e,0xc(%esp)
f01013ff:	f0 
f0101400:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101407:	f0 
f0101408:	c7 44 24 04 c3 02 00 	movl   $0x2c3,0x4(%esp)
f010140f:	00 
f0101410:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101417:	e8 a2 ec ff ff       	call   f01000be <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f010141c:	39 f7                	cmp    %esi,%edi
f010141e:	75 24                	jne    f0101444 <mem_init+0x264>
f0101420:	c7 44 24 0c b4 61 10 	movl   $0xf01061b4,0xc(%esp)
f0101427:	f0 
f0101428:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f010142f:	f0 
f0101430:	c7 44 24 04 c6 02 00 	movl   $0x2c6,0x4(%esp)
f0101437:	00 
f0101438:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f010143f:	e8 7a ec ff ff       	call   f01000be <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101444:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101447:	39 c6                	cmp    %eax,%esi
f0101449:	74 04                	je     f010144f <mem_init+0x26f>
f010144b:	39 c7                	cmp    %eax,%edi
f010144d:	75 24                	jne    f0101473 <mem_init+0x293>
f010144f:	c7 44 24 0c b8 5a 10 	movl   $0xf0105ab8,0xc(%esp)
f0101456:	f0 
f0101457:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f010145e:	f0 
f010145f:	c7 44 24 04 c7 02 00 	movl   $0x2c7,0x4(%esp)
f0101466:	00 
f0101467:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f010146e:	e8 4b ec ff ff       	call   f01000be <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101473:	8b 15 cc ef 17 f0    	mov    0xf017efcc,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f0101479:	a1 c4 ef 17 f0       	mov    0xf017efc4,%eax
f010147e:	c1 e0 0c             	shl    $0xc,%eax
f0101481:	89 f9                	mov    %edi,%ecx
f0101483:	29 d1                	sub    %edx,%ecx
f0101485:	c1 f9 03             	sar    $0x3,%ecx
f0101488:	c1 e1 0c             	shl    $0xc,%ecx
f010148b:	39 c1                	cmp    %eax,%ecx
f010148d:	72 24                	jb     f01014b3 <mem_init+0x2d3>
f010148f:	c7 44 24 0c c6 61 10 	movl   $0xf01061c6,0xc(%esp)
f0101496:	f0 
f0101497:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f010149e:	f0 
f010149f:	c7 44 24 04 c8 02 00 	movl   $0x2c8,0x4(%esp)
f01014a6:	00 
f01014a7:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01014ae:	e8 0b ec ff ff       	call   f01000be <_panic>
f01014b3:	89 f1                	mov    %esi,%ecx
f01014b5:	29 d1                	sub    %edx,%ecx
f01014b7:	c1 f9 03             	sar    $0x3,%ecx
f01014ba:	c1 e1 0c             	shl    $0xc,%ecx
	assert(page2pa(pp1) < npages*PGSIZE);
f01014bd:	39 c8                	cmp    %ecx,%eax
f01014bf:	77 24                	ja     f01014e5 <mem_init+0x305>
f01014c1:	c7 44 24 0c e3 61 10 	movl   $0xf01061e3,0xc(%esp)
f01014c8:	f0 
f01014c9:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f01014d0:	f0 
f01014d1:	c7 44 24 04 c9 02 00 	movl   $0x2c9,0x4(%esp)
f01014d8:	00 
f01014d9:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01014e0:	e8 d9 eb ff ff       	call   f01000be <_panic>
f01014e5:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01014e8:	29 d1                	sub    %edx,%ecx
f01014ea:	89 ca                	mov    %ecx,%edx
f01014ec:	c1 fa 03             	sar    $0x3,%edx
f01014ef:	c1 e2 0c             	shl    $0xc,%edx
	assert(page2pa(pp2) < npages*PGSIZE);
f01014f2:	39 d0                	cmp    %edx,%eax
f01014f4:	77 24                	ja     f010151a <mem_init+0x33a>
f01014f6:	c7 44 24 0c 00 62 10 	movl   $0xf0106200,0xc(%esp)
f01014fd:	f0 
f01014fe:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101505:	f0 
f0101506:	c7 44 24 04 ca 02 00 	movl   $0x2ca,0x4(%esp)
f010150d:	00 
f010150e:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101515:	e8 a4 eb ff ff       	call   f01000be <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f010151a:	a1 00 e3 17 f0       	mov    0xf017e300,%eax
f010151f:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101522:	c7 05 00 e3 17 f0 00 	movl   $0x0,0xf017e300
f0101529:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f010152c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101533:	e8 75 f9 ff ff       	call   f0100ead <page_alloc>
f0101538:	85 c0                	test   %eax,%eax
f010153a:	74 24                	je     f0101560 <mem_init+0x380>
f010153c:	c7 44 24 0c 1d 62 10 	movl   $0xf010621d,0xc(%esp)
f0101543:	f0 
f0101544:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f010154b:	f0 
f010154c:	c7 44 24 04 d1 02 00 	movl   $0x2d1,0x4(%esp)
f0101553:	00 
f0101554:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f010158d:	c7 44 24 0c 72 61 10 	movl   $0xf0106172,0xc(%esp)
f0101594:	f0 
f0101595:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f010159c:	f0 
f010159d:	c7 44 24 04 d8 02 00 	movl   $0x2d8,0x4(%esp)
f01015a4:	00 
f01015a5:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01015ac:	e8 0d eb ff ff       	call   f01000be <_panic>
	assert((pp1 = page_alloc(0)));
f01015b1:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01015b8:	e8 f0 f8 ff ff       	call   f0100ead <page_alloc>
f01015bd:	89 c7                	mov    %eax,%edi
f01015bf:	85 c0                	test   %eax,%eax
f01015c1:	75 24                	jne    f01015e7 <mem_init+0x407>
f01015c3:	c7 44 24 0c 88 61 10 	movl   $0xf0106188,0xc(%esp)
f01015ca:	f0 
f01015cb:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f01015d2:	f0 
f01015d3:	c7 44 24 04 d9 02 00 	movl   $0x2d9,0x4(%esp)
f01015da:	00 
f01015db:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01015e2:	e8 d7 ea ff ff       	call   f01000be <_panic>
	assert((pp2 = page_alloc(0)));
f01015e7:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01015ee:	e8 ba f8 ff ff       	call   f0100ead <page_alloc>
f01015f3:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01015f6:	85 c0                	test   %eax,%eax
f01015f8:	75 24                	jne    f010161e <mem_init+0x43e>
f01015fa:	c7 44 24 0c 9e 61 10 	movl   $0xf010619e,0xc(%esp)
f0101601:	f0 
f0101602:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101609:	f0 
f010160a:	c7 44 24 04 da 02 00 	movl   $0x2da,0x4(%esp)
f0101611:	00 
f0101612:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101619:	e8 a0 ea ff ff       	call   f01000be <_panic>
	assert(pp0);
	assert(pp1 && pp1 != pp0);
f010161e:	39 fe                	cmp    %edi,%esi
f0101620:	75 24                	jne    f0101646 <mem_init+0x466>
f0101622:	c7 44 24 0c b4 61 10 	movl   $0xf01061b4,0xc(%esp)
f0101629:	f0 
f010162a:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101631:	f0 
f0101632:	c7 44 24 04 dc 02 00 	movl   $0x2dc,0x4(%esp)
f0101639:	00 
f010163a:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101641:	e8 78 ea ff ff       	call   f01000be <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101646:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101649:	39 c7                	cmp    %eax,%edi
f010164b:	74 04                	je     f0101651 <mem_init+0x471>
f010164d:	39 c6                	cmp    %eax,%esi
f010164f:	75 24                	jne    f0101675 <mem_init+0x495>
f0101651:	c7 44 24 0c b8 5a 10 	movl   $0xf0105ab8,0xc(%esp)
f0101658:	f0 
f0101659:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101660:	f0 
f0101661:	c7 44 24 04 dd 02 00 	movl   $0x2dd,0x4(%esp)
f0101668:	00 
f0101669:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101670:	e8 49 ea ff ff       	call   f01000be <_panic>
	assert(!page_alloc(0));
f0101675:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010167c:	e8 2c f8 ff ff       	call   f0100ead <page_alloc>
f0101681:	85 c0                	test   %eax,%eax
f0101683:	74 24                	je     f01016a9 <mem_init+0x4c9>
f0101685:	c7 44 24 0c 1d 62 10 	movl   $0xf010621d,0xc(%esp)
f010168c:	f0 
f010168d:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101694:	f0 
f0101695:	c7 44 24 04 de 02 00 	movl   $0x2de,0x4(%esp)
f010169c:	00 
f010169d:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01016a4:	e8 15 ea ff ff       	call   f01000be <_panic>
f01016a9:	89 f0                	mov    %esi,%eax
f01016ab:	2b 05 cc ef 17 f0    	sub    0xf017efcc,%eax
f01016b1:	c1 f8 03             	sar    $0x3,%eax
f01016b4:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01016b7:	89 c2                	mov    %eax,%edx
f01016b9:	c1 ea 0c             	shr    $0xc,%edx
f01016bc:	3b 15 c4 ef 17 f0    	cmp    0xf017efc4,%edx
f01016c2:	72 20                	jb     f01016e4 <mem_init+0x504>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01016c4:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01016c8:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f01016cf:	f0 
f01016d0:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01016d7:	00 
f01016d8:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
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
f01016fc:	e8 c8 37 00 00       	call   f0104ec9 <memset>
	page_free(pp0);
f0101701:	89 34 24             	mov    %esi,(%esp)
f0101704:	e8 29 f8 ff ff       	call   f0100f32 <page_free>
	assert((pp = page_alloc(ALLOC_ZERO)));
f0101709:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101710:	e8 98 f7 ff ff       	call   f0100ead <page_alloc>
f0101715:	85 c0                	test   %eax,%eax
f0101717:	75 24                	jne    f010173d <mem_init+0x55d>
f0101719:	c7 44 24 0c 2c 62 10 	movl   $0xf010622c,0xc(%esp)
f0101720:	f0 
f0101721:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101728:	f0 
f0101729:	c7 44 24 04 e3 02 00 	movl   $0x2e3,0x4(%esp)
f0101730:	00 
f0101731:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101738:	e8 81 e9 ff ff       	call   f01000be <_panic>
	assert(pp && pp0 == pp);
f010173d:	39 c6                	cmp    %eax,%esi
f010173f:	74 24                	je     f0101765 <mem_init+0x585>
f0101741:	c7 44 24 0c 4a 62 10 	movl   $0xf010624a,0xc(%esp)
f0101748:	f0 
f0101749:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101750:	f0 
f0101751:	c7 44 24 04 e4 02 00 	movl   $0x2e4,0x4(%esp)
f0101758:	00 
f0101759:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101760:	e8 59 e9 ff ff       	call   f01000be <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101765:	89 f2                	mov    %esi,%edx
f0101767:	2b 15 cc ef 17 f0    	sub    0xf017efcc,%edx
f010176d:	c1 fa 03             	sar    $0x3,%edx
f0101770:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101773:	89 d0                	mov    %edx,%eax
f0101775:	c1 e8 0c             	shr    $0xc,%eax
f0101778:	3b 05 c4 ef 17 f0    	cmp    0xf017efc4,%eax
f010177e:	72 20                	jb     f01017a0 <mem_init+0x5c0>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101780:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101784:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f010178b:	f0 
f010178c:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101793:	00 
f0101794:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
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
f01017ba:	c7 44 24 0c 5a 62 10 	movl   $0xf010625a,0xc(%esp)
f01017c1:	f0 
f01017c2:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f01017c9:	f0 
f01017ca:	c7 44 24 04 e7 02 00 	movl   $0x2e7,0x4(%esp)
f01017d1:	00 
f01017d2:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f01017e8:	a3 00 e3 17 f0       	mov    %eax,0xf017e300

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
f0101808:	a1 00 e3 17 f0       	mov    0xf017e300,%eax
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
f010181e:	c7 44 24 0c 64 62 10 	movl   $0xf0106264,0xc(%esp)
f0101825:	f0 
f0101826:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f010182d:	f0 
f010182e:	c7 44 24 04 f4 02 00 	movl   $0x2f4,0x4(%esp)
f0101835:	00 
f0101836:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f010183d:	e8 7c e8 ff ff       	call   f01000be <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f0101842:	c7 04 24 d8 5a 10 f0 	movl   $0xf0105ad8,(%esp)
f0101849:	e8 e7 20 00 00       	call   f0103935 <cprintf>
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
f0101860:	c7 44 24 0c 72 61 10 	movl   $0xf0106172,0xc(%esp)
f0101867:	f0 
f0101868:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f010186f:	f0 
f0101870:	c7 44 24 04 52 03 00 	movl   $0x352,0x4(%esp)
f0101877:	00 
f0101878:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f010187f:	e8 3a e8 ff ff       	call   f01000be <_panic>
	assert((pp1 = page_alloc(0)));
f0101884:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010188b:	e8 1d f6 ff ff       	call   f0100ead <page_alloc>
f0101890:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0101893:	85 c0                	test   %eax,%eax
f0101895:	75 24                	jne    f01018bb <mem_init+0x6db>
f0101897:	c7 44 24 0c 88 61 10 	movl   $0xf0106188,0xc(%esp)
f010189e:	f0 
f010189f:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f01018a6:	f0 
f01018a7:	c7 44 24 04 53 03 00 	movl   $0x353,0x4(%esp)
f01018ae:	00 
f01018af:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01018b6:	e8 03 e8 ff ff       	call   f01000be <_panic>
	assert((pp2 = page_alloc(0)));
f01018bb:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018c2:	e8 e6 f5 ff ff       	call   f0100ead <page_alloc>
f01018c7:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01018ca:	85 c0                	test   %eax,%eax
f01018cc:	75 24                	jne    f01018f2 <mem_init+0x712>
f01018ce:	c7 44 24 0c 9e 61 10 	movl   $0xf010619e,0xc(%esp)
f01018d5:	f0 
f01018d6:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f01018dd:	f0 
f01018de:	c7 44 24 04 54 03 00 	movl   $0x354,0x4(%esp)
f01018e5:	00 
f01018e6:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01018ed:	e8 cc e7 ff ff       	call   f01000be <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f01018f2:	3b 5d d0             	cmp    -0x30(%ebp),%ebx
f01018f5:	75 24                	jne    f010191b <mem_init+0x73b>
f01018f7:	c7 44 24 0c b4 61 10 	movl   $0xf01061b4,0xc(%esp)
f01018fe:	f0 
f01018ff:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101906:	f0 
f0101907:	c7 44 24 04 57 03 00 	movl   $0x357,0x4(%esp)
f010190e:	00 
f010190f:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101916:	e8 a3 e7 ff ff       	call   f01000be <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f010191b:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010191e:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0101921:	74 04                	je     f0101927 <mem_init+0x747>
f0101923:	39 c3                	cmp    %eax,%ebx
f0101925:	75 24                	jne    f010194b <mem_init+0x76b>
f0101927:	c7 44 24 0c b8 5a 10 	movl   $0xf0105ab8,0xc(%esp)
f010192e:	f0 
f010192f:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101936:	f0 
f0101937:	c7 44 24 04 58 03 00 	movl   $0x358,0x4(%esp)
f010193e:	00 
f010193f:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101946:	e8 73 e7 ff ff       	call   f01000be <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f010194b:	a1 00 e3 17 f0       	mov    0xf017e300,%eax
f0101950:	89 45 cc             	mov    %eax,-0x34(%ebp)
	page_free_list = 0;
f0101953:	c7 05 00 e3 17 f0 00 	movl   $0x0,0xf017e300
f010195a:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f010195d:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101964:	e8 44 f5 ff ff       	call   f0100ead <page_alloc>
f0101969:	85 c0                	test   %eax,%eax
f010196b:	74 24                	je     f0101991 <mem_init+0x7b1>
f010196d:	c7 44 24 0c 1d 62 10 	movl   $0xf010621d,0xc(%esp)
f0101974:	f0 
f0101975:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f010197c:	f0 
f010197d:	c7 44 24 04 5f 03 00 	movl   $0x35f,0x4(%esp)
f0101984:	00 
f0101985:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f010198c:	e8 2d e7 ff ff       	call   f01000be <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f0101991:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101994:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101998:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010199f:	00 
f01019a0:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f01019a5:	89 04 24             	mov    %eax,(%esp)
f01019a8:	e8 c7 f6 ff ff       	call   f0101074 <page_lookup>
f01019ad:	85 c0                	test   %eax,%eax
f01019af:	74 24                	je     f01019d5 <mem_init+0x7f5>
f01019b1:	c7 44 24 0c f8 5a 10 	movl   $0xf0105af8,0xc(%esp)
f01019b8:	f0 
f01019b9:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f01019c0:	f0 
f01019c1:	c7 44 24 04 62 03 00 	movl   $0x362,0x4(%esp)
f01019c8:	00 
f01019c9:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01019d0:	e8 e9 e6 ff ff       	call   f01000be <_panic>

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);
f01019d5:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01019dc:	00 
f01019dd:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01019e4:	00 
f01019e5:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01019e8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01019ec:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f01019f1:	89 04 24             	mov    %eax,(%esp)
f01019f4:	e8 26 f7 ff ff       	call   f010111f <page_insert>
f01019f9:	85 c0                	test   %eax,%eax
f01019fb:	78 24                	js     f0101a21 <mem_init+0x841>
f01019fd:	c7 44 24 0c 30 5b 10 	movl   $0xf0105b30,0xc(%esp)
f0101a04:	f0 
f0101a05:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101a0c:	f0 
f0101a0d:	c7 44 24 04 65 03 00 	movl   $0x365,0x4(%esp)
f0101a14:	00 
f0101a15:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0101a40:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0101a45:	89 04 24             	mov    %eax,(%esp)
f0101a48:	e8 d2 f6 ff ff       	call   f010111f <page_insert>
f0101a4d:	85 c0                	test   %eax,%eax
f0101a4f:	74 24                	je     f0101a75 <mem_init+0x895>
f0101a51:	c7 44 24 0c 60 5b 10 	movl   $0xf0105b60,0xc(%esp)
f0101a58:	f0 
f0101a59:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101a60:	f0 
f0101a61:	c7 44 24 04 69 03 00 	movl   $0x369,0x4(%esp)
f0101a68:	00 
f0101a69:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101a70:	e8 49 e6 ff ff       	call   f01000be <_panic>
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101a75:	8b 35 c8 ef 17 f0    	mov    0xf017efc8,%esi
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101a7b:	8b 3d cc ef 17 f0    	mov    0xf017efcc,%edi
f0101a81:	8b 16                	mov    (%esi),%edx
f0101a83:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0101a89:	89 d8                	mov    %ebx,%eax
f0101a8b:	29 f8                	sub    %edi,%eax
f0101a8d:	c1 f8 03             	sar    $0x3,%eax
f0101a90:	c1 e0 0c             	shl    $0xc,%eax
f0101a93:	39 c2                	cmp    %eax,%edx
f0101a95:	74 24                	je     f0101abb <mem_init+0x8db>
f0101a97:	c7 44 24 0c 90 5b 10 	movl   $0xf0105b90,0xc(%esp)
f0101a9e:	f0 
f0101a9f:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101aa6:	f0 
f0101aa7:	c7 44 24 04 6a 03 00 	movl   $0x36a,0x4(%esp)
f0101aae:	00 
f0101aaf:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0101ad6:	c7 44 24 0c b8 5b 10 	movl   $0xf0105bb8,0xc(%esp)
f0101add:	f0 
f0101ade:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101ae5:	f0 
f0101ae6:	c7 44 24 04 6b 03 00 	movl   $0x36b,0x4(%esp)
f0101aed:	00 
f0101aee:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101af5:	e8 c4 e5 ff ff       	call   f01000be <_panic>
	assert(pp1->pp_ref == 1);
f0101afa:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101afd:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101b02:	74 24                	je     f0101b28 <mem_init+0x948>
f0101b04:	c7 44 24 0c 6f 62 10 	movl   $0xf010626f,0xc(%esp)
f0101b0b:	f0 
f0101b0c:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101b13:	f0 
f0101b14:	c7 44 24 04 6c 03 00 	movl   $0x36c,0x4(%esp)
f0101b1b:	00 
f0101b1c:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101b23:	e8 96 e5 ff ff       	call   f01000be <_panic>
	assert(pp0->pp_ref == 1);
f0101b28:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0101b2d:	74 24                	je     f0101b53 <mem_init+0x973>
f0101b2f:	c7 44 24 0c 80 62 10 	movl   $0xf0106280,0xc(%esp)
f0101b36:	f0 
f0101b37:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101b3e:	f0 
f0101b3f:	c7 44 24 04 6d 03 00 	movl   $0x36d,0x4(%esp)
f0101b46:	00 
f0101b47:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0101b76:	c7 44 24 0c e8 5b 10 	movl   $0xf0105be8,0xc(%esp)
f0101b7d:	f0 
f0101b7e:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101b85:	f0 
f0101b86:	c7 44 24 04 70 03 00 	movl   $0x370,0x4(%esp)
f0101b8d:	00 
f0101b8e:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101b95:	e8 24 e5 ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101b9a:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101b9f:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0101ba4:	e8 4b ee ff ff       	call   f01009f4 <check_va2pa>
f0101ba9:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101bac:	2b 15 cc ef 17 f0    	sub    0xf017efcc,%edx
f0101bb2:	c1 fa 03             	sar    $0x3,%edx
f0101bb5:	c1 e2 0c             	shl    $0xc,%edx
f0101bb8:	39 d0                	cmp    %edx,%eax
f0101bba:	74 24                	je     f0101be0 <mem_init+0xa00>
f0101bbc:	c7 44 24 0c 24 5c 10 	movl   $0xf0105c24,0xc(%esp)
f0101bc3:	f0 
f0101bc4:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101bcb:	f0 
f0101bcc:	c7 44 24 04 71 03 00 	movl   $0x371,0x4(%esp)
f0101bd3:	00 
f0101bd4:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101bdb:	e8 de e4 ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 1);
f0101be0:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101be3:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101be8:	74 24                	je     f0101c0e <mem_init+0xa2e>
f0101bea:	c7 44 24 0c 91 62 10 	movl   $0xf0106291,0xc(%esp)
f0101bf1:	f0 
f0101bf2:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101bf9:	f0 
f0101bfa:	c7 44 24 04 72 03 00 	movl   $0x372,0x4(%esp)
f0101c01:	00 
f0101c02:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101c09:	e8 b0 e4 ff ff       	call   f01000be <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0101c0e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101c15:	e8 93 f2 ff ff       	call   f0100ead <page_alloc>
f0101c1a:	85 c0                	test   %eax,%eax
f0101c1c:	74 24                	je     f0101c42 <mem_init+0xa62>
f0101c1e:	c7 44 24 0c 1d 62 10 	movl   $0xf010621d,0xc(%esp)
f0101c25:	f0 
f0101c26:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101c2d:	f0 
f0101c2e:	c7 44 24 04 75 03 00 	movl   $0x375,0x4(%esp)
f0101c35:	00 
f0101c36:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101c3d:	e8 7c e4 ff ff       	call   f01000be <_panic>

	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101c42:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101c49:	00 
f0101c4a:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101c51:	00 
f0101c52:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101c55:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101c59:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0101c5e:	89 04 24             	mov    %eax,(%esp)
f0101c61:	e8 b9 f4 ff ff       	call   f010111f <page_insert>
f0101c66:	85 c0                	test   %eax,%eax
f0101c68:	74 24                	je     f0101c8e <mem_init+0xaae>
f0101c6a:	c7 44 24 0c e8 5b 10 	movl   $0xf0105be8,0xc(%esp)
f0101c71:	f0 
f0101c72:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101c79:	f0 
f0101c7a:	c7 44 24 04 78 03 00 	movl   $0x378,0x4(%esp)
f0101c81:	00 
f0101c82:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101c89:	e8 30 e4 ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101c8e:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101c93:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0101c98:	e8 57 ed ff ff       	call   f01009f4 <check_va2pa>
f0101c9d:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101ca0:	2b 15 cc ef 17 f0    	sub    0xf017efcc,%edx
f0101ca6:	c1 fa 03             	sar    $0x3,%edx
f0101ca9:	c1 e2 0c             	shl    $0xc,%edx
f0101cac:	39 d0                	cmp    %edx,%eax
f0101cae:	74 24                	je     f0101cd4 <mem_init+0xaf4>
f0101cb0:	c7 44 24 0c 24 5c 10 	movl   $0xf0105c24,0xc(%esp)
f0101cb7:	f0 
f0101cb8:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101cbf:	f0 
f0101cc0:	c7 44 24 04 79 03 00 	movl   $0x379,0x4(%esp)
f0101cc7:	00 
f0101cc8:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101ccf:	e8 ea e3 ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 1);
f0101cd4:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101cd7:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101cdc:	74 24                	je     f0101d02 <mem_init+0xb22>
f0101cde:	c7 44 24 0c 91 62 10 	movl   $0xf0106291,0xc(%esp)
f0101ce5:	f0 
f0101ce6:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101ced:	f0 
f0101cee:	c7 44 24 04 7a 03 00 	movl   $0x37a,0x4(%esp)
f0101cf5:	00 
f0101cf6:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101cfd:	e8 bc e3 ff ff       	call   f01000be <_panic>

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));
f0101d02:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101d09:	e8 9f f1 ff ff       	call   f0100ead <page_alloc>
f0101d0e:	85 c0                	test   %eax,%eax
f0101d10:	74 24                	je     f0101d36 <mem_init+0xb56>
f0101d12:	c7 44 24 0c 1d 62 10 	movl   $0xf010621d,0xc(%esp)
f0101d19:	f0 
f0101d1a:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101d21:	f0 
f0101d22:	c7 44 24 04 7e 03 00 	movl   $0x37e,0x4(%esp)
f0101d29:	00 
f0101d2a:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101d31:	e8 88 e3 ff ff       	call   f01000be <_panic>

	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f0101d36:	8b 15 c8 ef 17 f0    	mov    0xf017efc8,%edx
f0101d3c:	8b 02                	mov    (%edx),%eax
f0101d3e:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101d43:	89 c1                	mov    %eax,%ecx
f0101d45:	c1 e9 0c             	shr    $0xc,%ecx
f0101d48:	3b 0d c4 ef 17 f0    	cmp    0xf017efc4,%ecx
f0101d4e:	72 20                	jb     f0101d70 <mem_init+0xb90>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101d50:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101d54:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f0101d5b:	f0 
f0101d5c:	c7 44 24 04 81 03 00 	movl   $0x381,0x4(%esp)
f0101d63:	00 
f0101d64:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0101d9a:	c7 44 24 0c 54 5c 10 	movl   $0xf0105c54,0xc(%esp)
f0101da1:	f0 
f0101da2:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101da9:	f0 
f0101daa:	c7 44 24 04 82 03 00 	movl   $0x382,0x4(%esp)
f0101db1:	00 
f0101db2:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101db9:	e8 00 e3 ff ff       	call   f01000be <_panic>

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
f0101dbe:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0101dc5:	00 
f0101dc6:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101dcd:	00 
f0101dce:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101dd1:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101dd5:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0101dda:	89 04 24             	mov    %eax,(%esp)
f0101ddd:	e8 3d f3 ff ff       	call   f010111f <page_insert>
f0101de2:	85 c0                	test   %eax,%eax
f0101de4:	74 24                	je     f0101e0a <mem_init+0xc2a>
f0101de6:	c7 44 24 0c 94 5c 10 	movl   $0xf0105c94,0xc(%esp)
f0101ded:	f0 
f0101dee:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101df5:	f0 
f0101df6:	c7 44 24 04 85 03 00 	movl   $0x385,0x4(%esp)
f0101dfd:	00 
f0101dfe:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101e05:	e8 b4 e2 ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101e0a:	8b 35 c8 ef 17 f0    	mov    0xf017efc8,%esi
f0101e10:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101e15:	89 f0                	mov    %esi,%eax
f0101e17:	e8 d8 eb ff ff       	call   f01009f4 <check_va2pa>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101e1c:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101e1f:	2b 15 cc ef 17 f0    	sub    0xf017efcc,%edx
f0101e25:	c1 fa 03             	sar    $0x3,%edx
f0101e28:	c1 e2 0c             	shl    $0xc,%edx
f0101e2b:	39 d0                	cmp    %edx,%eax
f0101e2d:	74 24                	je     f0101e53 <mem_init+0xc73>
f0101e2f:	c7 44 24 0c 24 5c 10 	movl   $0xf0105c24,0xc(%esp)
f0101e36:	f0 
f0101e37:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101e3e:	f0 
f0101e3f:	c7 44 24 04 86 03 00 	movl   $0x386,0x4(%esp)
f0101e46:	00 
f0101e47:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101e4e:	e8 6b e2 ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 1);
f0101e53:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101e56:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101e5b:	74 24                	je     f0101e81 <mem_init+0xca1>
f0101e5d:	c7 44 24 0c 91 62 10 	movl   $0xf0106291,0xc(%esp)
f0101e64:	f0 
f0101e65:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101e6c:	f0 
f0101e6d:	c7 44 24 04 87 03 00 	movl   $0x387,0x4(%esp)
f0101e74:	00 
f0101e75:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0101e9e:	c7 44 24 0c d4 5c 10 	movl   $0xf0105cd4,0xc(%esp)
f0101ea5:	f0 
f0101ea6:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101ead:	f0 
f0101eae:	c7 44 24 04 88 03 00 	movl   $0x388,0x4(%esp)
f0101eb5:	00 
f0101eb6:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101ebd:	e8 fc e1 ff ff       	call   f01000be <_panic>
	assert(kern_pgdir[0] & PTE_U);
f0101ec2:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0101ec7:	f6 00 04             	testb  $0x4,(%eax)
f0101eca:	75 24                	jne    f0101ef0 <mem_init+0xd10>
f0101ecc:	c7 44 24 0c a2 62 10 	movl   $0xf01062a2,0xc(%esp)
f0101ed3:	f0 
f0101ed4:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101edb:	f0 
f0101edc:	c7 44 24 04 89 03 00 	movl   $0x389,0x4(%esp)
f0101ee3:	00 
f0101ee4:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0101f10:	c7 44 24 0c 08 5d 10 	movl   $0xf0105d08,0xc(%esp)
f0101f17:	f0 
f0101f18:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101f1f:	f0 
f0101f20:	c7 44 24 04 8c 03 00 	movl   $0x38c,0x4(%esp)
f0101f27:	00 
f0101f28:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101f2f:	e8 8a e1 ff ff       	call   f01000be <_panic>

	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
f0101f34:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101f3b:	00 
f0101f3c:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101f43:	00 
f0101f44:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101f47:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101f4b:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0101f50:	89 04 24             	mov    %eax,(%esp)
f0101f53:	e8 c7 f1 ff ff       	call   f010111f <page_insert>
f0101f58:	85 c0                	test   %eax,%eax
f0101f5a:	74 24                	je     f0101f80 <mem_init+0xda0>
f0101f5c:	c7 44 24 0c 40 5d 10 	movl   $0xf0105d40,0xc(%esp)
f0101f63:	f0 
f0101f64:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101f6b:	f0 
f0101f6c:	c7 44 24 04 8f 03 00 	movl   $0x38f,0x4(%esp)
f0101f73:	00 
f0101f74:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101f7b:	e8 3e e1 ff ff       	call   f01000be <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f0101f80:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101f87:	00 
f0101f88:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0101f8f:	00 
f0101f90:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0101f95:	89 04 24             	mov    %eax,(%esp)
f0101f98:	e8 cd ef ff ff       	call   f0100f6a <pgdir_walk>
f0101f9d:	f6 00 04             	testb  $0x4,(%eax)
f0101fa0:	74 24                	je     f0101fc6 <mem_init+0xde6>
f0101fa2:	c7 44 24 0c 7c 5d 10 	movl   $0xf0105d7c,0xc(%esp)
f0101fa9:	f0 
f0101faa:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101fb1:	f0 
f0101fb2:	c7 44 24 04 90 03 00 	movl   $0x390,0x4(%esp)
f0101fb9:	00 
f0101fba:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0101fc1:	e8 f8 e0 ff ff       	call   f01000be <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f0101fc6:	8b 3d c8 ef 17 f0    	mov    0xf017efc8,%edi
f0101fcc:	ba 00 00 00 00       	mov    $0x0,%edx
f0101fd1:	89 f8                	mov    %edi,%eax
f0101fd3:	e8 1c ea ff ff       	call   f01009f4 <check_va2pa>
f0101fd8:	89 c6                	mov    %eax,%esi
f0101fda:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101fdd:	2b 05 cc ef 17 f0    	sub    0xf017efcc,%eax
f0101fe3:	c1 f8 03             	sar    $0x3,%eax
f0101fe6:	c1 e0 0c             	shl    $0xc,%eax
f0101fe9:	39 c6                	cmp    %eax,%esi
f0101feb:	74 24                	je     f0102011 <mem_init+0xe31>
f0101fed:	c7 44 24 0c b4 5d 10 	movl   $0xf0105db4,0xc(%esp)
f0101ff4:	f0 
f0101ff5:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0101ffc:	f0 
f0101ffd:	c7 44 24 04 93 03 00 	movl   $0x393,0x4(%esp)
f0102004:	00 
f0102005:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f010200c:	e8 ad e0 ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102011:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102016:	89 f8                	mov    %edi,%eax
f0102018:	e8 d7 e9 ff ff       	call   f01009f4 <check_va2pa>
f010201d:	39 c6                	cmp    %eax,%esi
f010201f:	74 24                	je     f0102045 <mem_init+0xe65>
f0102021:	c7 44 24 0c e0 5d 10 	movl   $0xf0105de0,0xc(%esp)
f0102028:	f0 
f0102029:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102030:	f0 
f0102031:	c7 44 24 04 94 03 00 	movl   $0x394,0x4(%esp)
f0102038:	00 
f0102039:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102040:	e8 79 e0 ff ff       	call   f01000be <_panic>
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
f0102045:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102048:	66 83 78 04 02       	cmpw   $0x2,0x4(%eax)
f010204d:	74 24                	je     f0102073 <mem_init+0xe93>
f010204f:	c7 44 24 0c b8 62 10 	movl   $0xf01062b8,0xc(%esp)
f0102056:	f0 
f0102057:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f010205e:	f0 
f010205f:	c7 44 24 04 96 03 00 	movl   $0x396,0x4(%esp)
f0102066:	00 
f0102067:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f010206e:	e8 4b e0 ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 0);
f0102073:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102076:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f010207b:	74 24                	je     f01020a1 <mem_init+0xec1>
f010207d:	c7 44 24 0c c9 62 10 	movl   $0xf01062c9,0xc(%esp)
f0102084:	f0 
f0102085:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f010208c:	f0 
f010208d:	c7 44 24 04 97 03 00 	movl   $0x397,0x4(%esp)
f0102094:	00 
f0102095:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f010209c:	e8 1d e0 ff ff       	call   f01000be <_panic>

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);
f01020a1:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01020a8:	e8 00 ee ff ff       	call   f0100ead <page_alloc>
f01020ad:	85 c0                	test   %eax,%eax
f01020af:	74 05                	je     f01020b6 <mem_init+0xed6>
f01020b1:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f01020b4:	74 24                	je     f01020da <mem_init+0xefa>
f01020b6:	c7 44 24 0c 10 5e 10 	movl   $0xf0105e10,0xc(%esp)
f01020bd:	f0 
f01020be:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f01020c5:	f0 
f01020c6:	c7 44 24 04 9a 03 00 	movl   $0x39a,0x4(%esp)
f01020cd:	00 
f01020ce:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01020d5:	e8 e4 df ff ff       	call   f01000be <_panic>

	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f01020da:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01020e1:	00 
f01020e2:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f01020e7:	89 04 24             	mov    %eax,(%esp)
f01020ea:	e8 f2 ef ff ff       	call   f01010e1 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01020ef:	8b 35 c8 ef 17 f0    	mov    0xf017efc8,%esi
f01020f5:	ba 00 00 00 00       	mov    $0x0,%edx
f01020fa:	89 f0                	mov    %esi,%eax
f01020fc:	e8 f3 e8 ff ff       	call   f01009f4 <check_va2pa>
f0102101:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102104:	74 24                	je     f010212a <mem_init+0xf4a>
f0102106:	c7 44 24 0c 34 5e 10 	movl   $0xf0105e34,0xc(%esp)
f010210d:	f0 
f010210e:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102115:	f0 
f0102116:	c7 44 24 04 9e 03 00 	movl   $0x39e,0x4(%esp)
f010211d:	00 
f010211e:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102125:	e8 94 df ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f010212a:	ba 00 10 00 00       	mov    $0x1000,%edx
f010212f:	89 f0                	mov    %esi,%eax
f0102131:	e8 be e8 ff ff       	call   f01009f4 <check_va2pa>
f0102136:	8b 55 d0             	mov    -0x30(%ebp),%edx
f0102139:	2b 15 cc ef 17 f0    	sub    0xf017efcc,%edx
f010213f:	c1 fa 03             	sar    $0x3,%edx
f0102142:	c1 e2 0c             	shl    $0xc,%edx
f0102145:	39 d0                	cmp    %edx,%eax
f0102147:	74 24                	je     f010216d <mem_init+0xf8d>
f0102149:	c7 44 24 0c e0 5d 10 	movl   $0xf0105de0,0xc(%esp)
f0102150:	f0 
f0102151:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102158:	f0 
f0102159:	c7 44 24 04 9f 03 00 	movl   $0x39f,0x4(%esp)
f0102160:	00 
f0102161:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102168:	e8 51 df ff ff       	call   f01000be <_panic>
	assert(pp1->pp_ref == 1);
f010216d:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102170:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0102175:	74 24                	je     f010219b <mem_init+0xfbb>
f0102177:	c7 44 24 0c 6f 62 10 	movl   $0xf010626f,0xc(%esp)
f010217e:	f0 
f010217f:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102186:	f0 
f0102187:	c7 44 24 04 a0 03 00 	movl   $0x3a0,0x4(%esp)
f010218e:	00 
f010218f:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102196:	e8 23 df ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 0);
f010219b:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010219e:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f01021a3:	74 24                	je     f01021c9 <mem_init+0xfe9>
f01021a5:	c7 44 24 0c c9 62 10 	movl   $0xf01062c9,0xc(%esp)
f01021ac:	f0 
f01021ad:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f01021b4:	f0 
f01021b5:	c7 44 24 04 a1 03 00 	movl   $0x3a1,0x4(%esp)
f01021bc:	00 
f01021bd:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01021c4:	e8 f5 de ff ff       	call   f01000be <_panic>

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
f01021c9:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01021d0:	00 
f01021d1:	89 34 24             	mov    %esi,(%esp)
f01021d4:	e8 08 ef ff ff       	call   f01010e1 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01021d9:	8b 35 c8 ef 17 f0    	mov    0xf017efc8,%esi
f01021df:	ba 00 00 00 00       	mov    $0x0,%edx
f01021e4:	89 f0                	mov    %esi,%eax
f01021e6:	e8 09 e8 ff ff       	call   f01009f4 <check_va2pa>
f01021eb:	83 f8 ff             	cmp    $0xffffffff,%eax
f01021ee:	74 24                	je     f0102214 <mem_init+0x1034>
f01021f0:	c7 44 24 0c 34 5e 10 	movl   $0xf0105e34,0xc(%esp)
f01021f7:	f0 
f01021f8:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f01021ff:	f0 
f0102200:	c7 44 24 04 a5 03 00 	movl   $0x3a5,0x4(%esp)
f0102207:	00 
f0102208:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f010220f:	e8 aa de ff ff       	call   f01000be <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
f0102214:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102219:	89 f0                	mov    %esi,%eax
f010221b:	e8 d4 e7 ff ff       	call   f01009f4 <check_va2pa>
f0102220:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102223:	74 24                	je     f0102249 <mem_init+0x1069>
f0102225:	c7 44 24 0c 58 5e 10 	movl   $0xf0105e58,0xc(%esp)
f010222c:	f0 
f010222d:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102234:	f0 
f0102235:	c7 44 24 04 a6 03 00 	movl   $0x3a6,0x4(%esp)
f010223c:	00 
f010223d:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102244:	e8 75 de ff ff       	call   f01000be <_panic>
	assert(pp1->pp_ref == 0);
f0102249:	8b 45 d0             	mov    -0x30(%ebp),%eax
f010224c:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102251:	74 24                	je     f0102277 <mem_init+0x1097>
f0102253:	c7 44 24 0c da 62 10 	movl   $0xf01062da,0xc(%esp)
f010225a:	f0 
f010225b:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102262:	f0 
f0102263:	c7 44 24 04 a7 03 00 	movl   $0x3a7,0x4(%esp)
f010226a:	00 
f010226b:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102272:	e8 47 de ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 0);
f0102277:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010227a:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f010227f:	74 24                	je     f01022a5 <mem_init+0x10c5>
f0102281:	c7 44 24 0c c9 62 10 	movl   $0xf01062c9,0xc(%esp)
f0102288:	f0 
f0102289:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102290:	f0 
f0102291:	c7 44 24 04 a8 03 00 	movl   $0x3a8,0x4(%esp)
f0102298:	00 
f0102299:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01022a0:	e8 19 de ff ff       	call   f01000be <_panic>

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);
f01022a5:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01022ac:	e8 fc eb ff ff       	call   f0100ead <page_alloc>
f01022b1:	85 c0                	test   %eax,%eax
f01022b3:	74 05                	je     f01022ba <mem_init+0x10da>
f01022b5:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f01022b8:	74 24                	je     f01022de <mem_init+0x10fe>
f01022ba:	c7 44 24 0c 80 5e 10 	movl   $0xf0105e80,0xc(%esp)
f01022c1:	f0 
f01022c2:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f01022c9:	f0 
f01022ca:	c7 44 24 04 ab 03 00 	movl   $0x3ab,0x4(%esp)
f01022d1:	00 
f01022d2:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01022d9:	e8 e0 dd ff ff       	call   f01000be <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f01022de:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01022e5:	e8 c3 eb ff ff       	call   f0100ead <page_alloc>
f01022ea:	85 c0                	test   %eax,%eax
f01022ec:	74 24                	je     f0102312 <mem_init+0x1132>
f01022ee:	c7 44 24 0c 1d 62 10 	movl   $0xf010621d,0xc(%esp)
f01022f5:	f0 
f01022f6:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f01022fd:	f0 
f01022fe:	c7 44 24 04 ae 03 00 	movl   $0x3ae,0x4(%esp)
f0102305:	00 
f0102306:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f010230d:	e8 ac dd ff ff       	call   f01000be <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102312:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0102317:	8b 08                	mov    (%eax),%ecx
f0102319:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f010231f:	89 da                	mov    %ebx,%edx
f0102321:	2b 15 cc ef 17 f0    	sub    0xf017efcc,%edx
f0102327:	c1 fa 03             	sar    $0x3,%edx
f010232a:	c1 e2 0c             	shl    $0xc,%edx
f010232d:	39 d1                	cmp    %edx,%ecx
f010232f:	74 24                	je     f0102355 <mem_init+0x1175>
f0102331:	c7 44 24 0c 90 5b 10 	movl   $0xf0105b90,0xc(%esp)
f0102338:	f0 
f0102339:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102340:	f0 
f0102341:	c7 44 24 04 b1 03 00 	movl   $0x3b1,0x4(%esp)
f0102348:	00 
f0102349:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102350:	e8 69 dd ff ff       	call   f01000be <_panic>
	kern_pgdir[0] = 0;
f0102355:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f010235b:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102360:	74 24                	je     f0102386 <mem_init+0x11a6>
f0102362:	c7 44 24 0c 80 62 10 	movl   $0xf0106280,0xc(%esp)
f0102369:	f0 
f010236a:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102371:	f0 
f0102372:	c7 44 24 04 b3 03 00 	movl   $0x3b3,0x4(%esp)
f0102379:	00 
f010237a:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f01023a4:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f01023a9:	89 04 24             	mov    %eax,(%esp)
f01023ac:	e8 b9 eb ff ff       	call   f0100f6a <pgdir_walk>
f01023b1:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f01023b4:	8b 0d c8 ef 17 f0    	mov    0xf017efc8,%ecx
f01023ba:	8b 51 04             	mov    0x4(%ecx),%edx
f01023bd:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01023c3:	8b 3d c4 ef 17 f0    	mov    0xf017efc4,%edi
f01023c9:	89 d6                	mov    %edx,%esi
f01023cb:	c1 ee 0c             	shr    $0xc,%esi
f01023ce:	39 fe                	cmp    %edi,%esi
f01023d0:	72 20                	jb     f01023f2 <mem_init+0x1212>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01023d2:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01023d6:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f01023dd:	f0 
f01023de:	c7 44 24 04 ba 03 00 	movl   $0x3ba,0x4(%esp)
f01023e5:	00 
f01023e6:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01023ed:	e8 cc dc ff ff       	call   f01000be <_panic>
	assert(ptep == ptep1 + PTX(va));
f01023f2:	81 ea fc ff ff 0f    	sub    $0xffffffc,%edx
f01023f8:	39 d0                	cmp    %edx,%eax
f01023fa:	74 24                	je     f0102420 <mem_init+0x1240>
f01023fc:	c7 44 24 0c eb 62 10 	movl   $0xf01062eb,0xc(%esp)
f0102403:	f0 
f0102404:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f010240b:	f0 
f010240c:	c7 44 24 04 bb 03 00 	movl   $0x3bb,0x4(%esp)
f0102413:	00 
f0102414:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f010242f:	2b 05 cc ef 17 f0    	sub    0xf017efcc,%eax
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
f0102448:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f010244f:	f0 
f0102450:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102457:	00 
f0102458:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
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
f010247c:	e8 48 2a 00 00       	call   f0104ec9 <memset>
	page_free(pp0);
f0102481:	89 1c 24             	mov    %ebx,(%esp)
f0102484:	e8 a9 ea ff ff       	call   f0100f32 <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f0102489:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0102490:	00 
f0102491:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0102498:	00 
f0102499:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f010249e:	89 04 24             	mov    %eax,(%esp)
f01024a1:	e8 c4 ea ff ff       	call   f0100f6a <pgdir_walk>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01024a6:	89 da                	mov    %ebx,%edx
f01024a8:	2b 15 cc ef 17 f0    	sub    0xf017efcc,%edx
f01024ae:	c1 fa 03             	sar    $0x3,%edx
f01024b1:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01024b4:	89 d0                	mov    %edx,%eax
f01024b6:	c1 e8 0c             	shr    $0xc,%eax
f01024b9:	3b 05 c4 ef 17 f0    	cmp    0xf017efc4,%eax
f01024bf:	72 20                	jb     f01024e1 <mem_init+0x1301>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01024c1:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01024c5:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f01024cc:	f0 
f01024cd:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01024d4:	00 
f01024d5:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
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
f0102506:	c7 44 24 0c 03 63 10 	movl   $0xf0106303,0xc(%esp)
f010250d:	f0 
f010250e:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102515:	f0 
f0102516:	c7 44 24 04 c5 03 00 	movl   $0x3c5,0x4(%esp)
f010251d:	00 
f010251e:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0102531:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0102536:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f010253c:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// give free list back
	page_free_list = fl;
f0102542:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0102545:	a3 00 e3 17 f0       	mov    %eax,0xf017e300

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
f0102568:	c7 04 24 1a 63 10 f0 	movl   $0xf010631a,(%esp)
f010256f:	e8 c1 13 00 00       	call   f0103935 <cprintf>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f0102574:	8b 0d c4 ef 17 f0    	mov    0xf017efc4,%ecx
f010257a:	8d 04 cd ff 0f 00 00 	lea    0xfff(,%ecx,8),%eax
f0102581:	89 c2                	mov    %eax,%edx
f0102583:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
f0102589:	39 d0                	cmp    %edx,%eax
f010258b:	0f 84 c9 09 00 00    	je     f0102f5a <mem_init+0x1d7a>
		page_insert(kern_pgdir, pa2page(PADDR(pages) + i), (void *)(UPAGES + i), PTE_U);
f0102591:	a1 cc ef 17 f0       	mov    0xf017efcc,%eax
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
f01025b2:	a1 cc ef 17 f0       	mov    0xf017efcc,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01025b7:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01025bc:	77 20                	ja     f01025de <mem_init+0x13fe>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01025be:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01025c2:	c7 44 24 08 94 5a 10 	movl   $0xf0105a94,0x8(%esp)
f01025c9:	f0 
f01025ca:	c7 44 24 04 bc 00 00 	movl   $0xbc,0x4(%esp)
f01025d1:	00 
f01025d2:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f01025f0:	c7 44 24 08 38 5a 10 	movl   $0xf0105a38,0x8(%esp)
f01025f7:	f0 
f01025f8:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01025ff:	00 
f0102600:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
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
f010262e:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0102633:	89 04 24             	mov    %eax,(%esp)
f0102636:	e8 e4 ea ff ff       	call   f010111f <page_insert>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	size_t i;
	for (i = 0; i < ROUNDUP(npages*sizeof(struct Page), PGSIZE); i += PGSIZE)
f010263b:	8d 8b 00 10 00 00    	lea    0x1000(%ebx),%ecx
f0102641:	8b 35 c4 ef 17 f0    	mov    0xf017efc4,%esi
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
f010266b:	3b 05 c4 ef 17 f0    	cmp    0xf017efc4,%eax
f0102671:	0f 82 71 09 00 00    	jb     f0102fe8 <mem_init+0x1e08>
f0102677:	eb 44                	jmp    f01026bd <mem_init+0x14dd>
f0102679:	8d 93 00 00 c0 ee    	lea    -0x11400000(%ebx),%edx
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		page_insert(kern_pgdir,pa2page(PADDR(envs)+i),(void *)(UENVS + i),PTE_U);
f010267f:	a1 0c e3 17 f0       	mov    0xf017e30c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102684:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102689:	77 20                	ja     f01026ab <mem_init+0x14cb>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010268b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010268f:	c7 44 24 08 94 5a 10 	movl   $0xf0105a94,0x8(%esp)
f0102696:	f0 
f0102697:	c7 44 24 04 c6 00 00 	movl   $0xc6,0x4(%esp)
f010269e:	00 
f010269f:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f01026a6:	e8 13 da ff ff       	call   f01000be <_panic>
f01026ab:	8d 84 18 00 00 00 10 	lea    0x10000000(%eax,%ebx,1),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01026b2:	c1 e8 0c             	shr    $0xc,%eax
f01026b5:	3b 05 c4 ef 17 f0    	cmp    0xf017efc4,%eax
f01026bb:	72 1c                	jb     f01026d9 <mem_init+0x14f9>
		panic("pa2page called with invalid pa");
f01026bd:	c7 44 24 08 38 5a 10 	movl   $0xf0105a38,0x8(%esp)
f01026c4:	f0 
f01026c5:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01026cc:	00 
f01026cd:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
f01026d4:	e8 e5 d9 ff ff       	call   f01000be <_panic>
f01026d9:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f01026e0:	00 
f01026e1:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f01026e5:	8b 15 cc ef 17 f0    	mov    0xf017efcc,%edx
f01026eb:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01026ee:	89 44 24 04          	mov    %eax,0x4(%esp)
f01026f2:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
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
f0102716:	b8 00 20 11 00       	mov    $0x112000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010271b:	c1 e8 0c             	shr    $0xc,%eax
f010271e:	3b 05 c4 ef 17 f0    	cmp    0xf017efc4,%eax
f0102724:	0f 82 78 08 00 00    	jb     f0102fa2 <mem_init+0x1dc2>
f010272a:	eb 39                	jmp    f0102765 <mem_init+0x1585>
f010272c:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010272f:	8d 14 18             	lea    (%eax,%ebx,1),%edx
f0102732:	89 d8                	mov    %ebx,%eax
f0102734:	c1 e8 0c             	shr    $0xc,%eax
f0102737:	3b 05 c4 ef 17 f0    	cmp    0xf017efc4,%eax
f010273d:	72 42                	jb     f0102781 <mem_init+0x15a1>
f010273f:	eb 24                	jmp    f0102765 <mem_init+0x1585>

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102741:	c7 44 24 0c 00 20 11 	movl   $0xf0112000,0xc(%esp)
f0102748:	f0 
f0102749:	c7 44 24 08 94 5a 10 	movl   $0xf0105a94,0x8(%esp)
f0102750:	f0 
f0102751:	c7 44 24 04 d3 00 00 	movl   $0xd3,0x4(%esp)
f0102758:	00 
f0102759:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102760:	e8 59 d9 ff ff       	call   f01000be <_panic>

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
f0102765:	c7 44 24 08 38 5a 10 	movl   $0xf0105a38,0x8(%esp)
f010276c:	f0 
f010276d:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102774:	00 
f0102775:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
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
f010278d:	8b 15 cc ef 17 f0    	mov    0xf017efcc,%edx
f0102793:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102796:	89 44 24 04          	mov    %eax,0x4(%esp)
f010279a:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
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
f01027c0:	8b 1d c4 ef 17 f0    	mov    0xf017efc4,%ebx
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
f01027db:	c7 44 24 08 38 5a 10 	movl   $0xf0105a38,0x8(%esp)
f01027e2:	f0 
f01027e3:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01027ea:	00 
f01027eb:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
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
f0102805:	a1 cc ef 17 f0       	mov    0xf017efcc,%eax
f010280a:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f010280d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102811:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0102816:	89 04 24             	mov    %eax,(%esp)
f0102819:	e8 01 e9 ff ff       	call   f010111f <page_insert>
		pa2page(i % (npages*PGSIZE))->pp_ref--;                 //this statement is to keep pp_ref == 0 in page_free_list
f010281e:	8b 0d c4 ef 17 f0    	mov    0xf017efc4,%ecx
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
f0102839:	c7 44 24 08 38 5a 10 	movl   $0xf0105a38,0x8(%esp)
f0102840:	f0 
f0102841:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102848:	00 
f0102849:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
f0102850:	e8 69 d8 ff ff       	call   f01000be <_panic>
	return &pages[PGNUM(pa)];
f0102855:	a1 cc ef 17 f0       	mov    0xf017efcc,%eax
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
f0102872:	8b 35 c8 ef 17 f0    	mov    0xf017efc8,%esi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
f0102878:	a1 c4 ef 17 f0       	mov    0xf017efc4,%eax
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
f0102891:	8b 1d 0c e3 17 f0    	mov    0xf017e30c,%ebx
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
f01028c1:	8b 1d cc ef 17 f0    	mov    0xf017efcc,%ebx
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
f01028e5:	c7 44 24 08 94 5a 10 	movl   $0xf0105a94,0x8(%esp)
f01028ec:	f0 
f01028ed:	c7 44 24 04 0c 03 00 	movl   $0x30c,0x4(%esp)
f01028f4:	00 
f01028f5:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f010290d:	c7 44 24 0c a4 5e 10 	movl   $0xf0105ea4,0xc(%esp)
f0102914:	f0 
f0102915:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f010291c:	f0 
f010291d:	c7 44 24 04 0c 03 00 	movl   $0x30c,0x4(%esp)
f0102924:	00 
f0102925:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0102949:	c7 44 24 08 94 5a 10 	movl   $0xf0105a94,0x8(%esp)
f0102950:	f0 
f0102951:	c7 44 24 04 11 03 00 	movl   $0x311,0x4(%esp)
f0102958:	00 
f0102959:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102960:	e8 59 d7 ff ff       	call   f01000be <_panic>
f0102965:	8d 14 1f             	lea    (%edi,%ebx,1),%edx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102968:	39 c2                	cmp    %eax,%edx
f010296a:	74 24                	je     f0102990 <mem_init+0x17b0>
f010296c:	c7 44 24 0c d8 5e 10 	movl   $0xf0105ed8,0xc(%esp)
f0102973:	f0 
f0102974:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f010297b:	f0 
f010297c:	c7 44 24 04 11 03 00 	movl   $0x311,0x4(%esp)
f0102983:	00 
f0102984:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f01029c6:	c7 44 24 0c 0c 5f 10 	movl   $0xf0105f0c,0xc(%esp)
f01029cd:	f0 
f01029ce:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f01029d5:	f0 
f01029d6:	c7 44 24 04 15 03 00 	movl   $0x315,0x4(%esp)
f01029dd:	00 
f01029de:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0102a00:	c7 44 24 0c 34 5f 10 	movl   $0xf0105f34,0xc(%esp)
f0102a07:	f0 
f0102a08:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102a0f:	f0 
f0102a10:	c7 44 24 04 19 03 00 	movl   $0x319,0x4(%esp)
f0102a17:	00 
f0102a18:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0102a47:	c7 44 24 0c 7c 5f 10 	movl   $0xf0105f7c,0xc(%esp)
f0102a4e:	f0 
f0102a4f:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102a56:	f0 
f0102a57:	c7 44 24 04 1a 03 00 	movl   $0x31a,0x4(%esp)
f0102a5e:	00 
f0102a5f:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0102a85:	c7 44 24 0c 33 63 10 	movl   $0xf0106333,0xc(%esp)
f0102a8c:	f0 
f0102a8d:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102a94:	f0 
f0102a95:	c7 44 24 04 23 03 00 	movl   $0x323,0x4(%esp)
f0102a9c:	00 
f0102a9d:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0102ab8:	c7 44 24 0c 33 63 10 	movl   $0xf0106333,0xc(%esp)
f0102abf:	f0 
f0102ac0:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102ac7:	f0 
f0102ac8:	c7 44 24 04 27 03 00 	movl   $0x327,0x4(%esp)
f0102acf:	00 
f0102ad0:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102ad7:	e8 e2 d5 ff ff       	call   f01000be <_panic>
				assert(pgdir[i] & PTE_W);
f0102adc:	f6 c2 02             	test   $0x2,%dl
f0102adf:	75 4e                	jne    f0102b2f <mem_init+0x194f>
f0102ae1:	c7 44 24 0c 44 63 10 	movl   $0xf0106344,0xc(%esp)
f0102ae8:	f0 
f0102ae9:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102af0:	f0 
f0102af1:	c7 44 24 04 28 03 00 	movl   $0x328,0x4(%esp)
f0102af8:	00 
f0102af9:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102b00:	e8 b9 d5 ff ff       	call   f01000be <_panic>
			} else
				assert(pgdir[i] == 0);
f0102b05:	83 3c 86 00          	cmpl   $0x0,(%esi,%eax,4)
f0102b09:	74 24                	je     f0102b2f <mem_init+0x194f>
f0102b0b:	c7 44 24 0c 55 63 10 	movl   $0xf0106355,0xc(%esp)
f0102b12:	f0 
f0102b13:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102b1a:	f0 
f0102b1b:	c7 44 24 04 2a 03 00 	movl   $0x32a,0x4(%esp)
f0102b22:	00 
f0102b23:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0102b3d:	c7 04 24 ac 5f 10 f0 	movl   $0xf0105fac,(%esp)
f0102b44:	e8 ec 0d 00 00       	call   f0103935 <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f0102b49:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102b4e:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102b53:	77 20                	ja     f0102b75 <mem_init+0x1995>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102b55:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102b59:	c7 44 24 08 94 5a 10 	movl   $0xf0105a94,0x8(%esp)
f0102b60:	f0 
f0102b61:	c7 44 24 04 ec 00 00 	movl   $0xec,0x4(%esp)
f0102b68:	00 
f0102b69:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0102ba7:	c7 44 24 0c 72 61 10 	movl   $0xf0106172,0xc(%esp)
f0102bae:	f0 
f0102baf:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102bb6:	f0 
f0102bb7:	c7 44 24 04 e0 03 00 	movl   $0x3e0,0x4(%esp)
f0102bbe:	00 
f0102bbf:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102bc6:	e8 f3 d4 ff ff       	call   f01000be <_panic>
	assert((pp1 = page_alloc(0)));
f0102bcb:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102bd2:	e8 d6 e2 ff ff       	call   f0100ead <page_alloc>
f0102bd7:	89 c7                	mov    %eax,%edi
f0102bd9:	85 c0                	test   %eax,%eax
f0102bdb:	75 24                	jne    f0102c01 <mem_init+0x1a21>
f0102bdd:	c7 44 24 0c 88 61 10 	movl   $0xf0106188,0xc(%esp)
f0102be4:	f0 
f0102be5:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102bec:	f0 
f0102bed:	c7 44 24 04 e1 03 00 	movl   $0x3e1,0x4(%esp)
f0102bf4:	00 
f0102bf5:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102bfc:	e8 bd d4 ff ff       	call   f01000be <_panic>
	assert((pp2 = page_alloc(0)));
f0102c01:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102c08:	e8 a0 e2 ff ff       	call   f0100ead <page_alloc>
f0102c0d:	89 c6                	mov    %eax,%esi
f0102c0f:	85 c0                	test   %eax,%eax
f0102c11:	75 24                	jne    f0102c37 <mem_init+0x1a57>
f0102c13:	c7 44 24 0c 9e 61 10 	movl   $0xf010619e,0xc(%esp)
f0102c1a:	f0 
f0102c1b:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102c22:	f0 
f0102c23:	c7 44 24 04 e2 03 00 	movl   $0x3e2,0x4(%esp)
f0102c2a:	00 
f0102c2b:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0102c41:	2b 05 cc ef 17 f0    	sub    0xf017efcc,%eax
f0102c47:	c1 f8 03             	sar    $0x3,%eax
f0102c4a:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102c4d:	89 c2                	mov    %eax,%edx
f0102c4f:	c1 ea 0c             	shr    $0xc,%edx
f0102c52:	3b 15 c4 ef 17 f0    	cmp    0xf017efc4,%edx
f0102c58:	72 20                	jb     f0102c7a <mem_init+0x1a9a>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102c5a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102c5e:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f0102c65:	f0 
f0102c66:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102c6d:	00 
f0102c6e:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
f0102c75:	e8 44 d4 ff ff       	call   f01000be <_panic>
	memset(page2kva(pp1), 1, PGSIZE);
f0102c7a:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102c81:	00 
f0102c82:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f0102c89:	00 
	return (void *)(pa + KERNBASE);
f0102c8a:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102c8f:	89 04 24             	mov    %eax,(%esp)
f0102c92:	e8 32 22 00 00       	call   f0104ec9 <memset>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102c97:	89 f0                	mov    %esi,%eax
f0102c99:	2b 05 cc ef 17 f0    	sub    0xf017efcc,%eax
f0102c9f:	c1 f8 03             	sar    $0x3,%eax
f0102ca2:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102ca5:	89 c2                	mov    %eax,%edx
f0102ca7:	c1 ea 0c             	shr    $0xc,%edx
f0102caa:	3b 15 c4 ef 17 f0    	cmp    0xf017efc4,%edx
f0102cb0:	72 20                	jb     f0102cd2 <mem_init+0x1af2>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102cb2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102cb6:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f0102cbd:	f0 
f0102cbe:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102cc5:	00 
f0102cc6:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
f0102ccd:	e8 ec d3 ff ff       	call   f01000be <_panic>
	memset(page2kva(pp2), 2, PGSIZE);
f0102cd2:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102cd9:	00 
f0102cda:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102ce1:	00 
	return (void *)(pa + KERNBASE);
f0102ce2:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102ce7:	89 04 24             	mov    %eax,(%esp)
f0102cea:	e8 da 21 00 00       	call   f0104ec9 <memset>
	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f0102cef:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102cf6:	00 
f0102cf7:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102cfe:	00 
f0102cff:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102d03:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0102d08:	89 04 24             	mov    %eax,(%esp)
f0102d0b:	e8 0f e4 ff ff       	call   f010111f <page_insert>
	assert(pp1->pp_ref == 1);
f0102d10:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0102d15:	74 24                	je     f0102d3b <mem_init+0x1b5b>
f0102d17:	c7 44 24 0c 6f 62 10 	movl   $0xf010626f,0xc(%esp)
f0102d1e:	f0 
f0102d1f:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102d26:	f0 
f0102d27:	c7 44 24 04 e7 03 00 	movl   $0x3e7,0x4(%esp)
f0102d2e:	00 
f0102d2f:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102d36:	e8 83 d3 ff ff       	call   f01000be <_panic>
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
f0102d3b:	81 3d 00 10 00 00 01 	cmpl   $0x1010101,0x1000
f0102d42:	01 01 01 
f0102d45:	74 24                	je     f0102d6b <mem_init+0x1b8b>
f0102d47:	c7 44 24 0c cc 5f 10 	movl   $0xf0105fcc,0xc(%esp)
f0102d4e:	f0 
f0102d4f:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102d56:	f0 
f0102d57:	c7 44 24 04 e8 03 00 	movl   $0x3e8,0x4(%esp)
f0102d5e:	00 
f0102d5f:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102d66:	e8 53 d3 ff ff       	call   f01000be <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f0102d6b:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102d72:	00 
f0102d73:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102d7a:	00 
f0102d7b:	89 74 24 04          	mov    %esi,0x4(%esp)
f0102d7f:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0102d84:	89 04 24             	mov    %eax,(%esp)
f0102d87:	e8 93 e3 ff ff       	call   f010111f <page_insert>
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
f0102d8c:	81 3d 00 10 00 00 02 	cmpl   $0x2020202,0x1000
f0102d93:	02 02 02 
f0102d96:	74 24                	je     f0102dbc <mem_init+0x1bdc>
f0102d98:	c7 44 24 0c f0 5f 10 	movl   $0xf0105ff0,0xc(%esp)
f0102d9f:	f0 
f0102da0:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102da7:	f0 
f0102da8:	c7 44 24 04 ea 03 00 	movl   $0x3ea,0x4(%esp)
f0102daf:	00 
f0102db0:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102db7:	e8 02 d3 ff ff       	call   f01000be <_panic>
	assert(pp2->pp_ref == 1);
f0102dbc:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0102dc1:	74 24                	je     f0102de7 <mem_init+0x1c07>
f0102dc3:	c7 44 24 0c 91 62 10 	movl   $0xf0106291,0xc(%esp)
f0102dca:	f0 
f0102dcb:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102dd2:	f0 
f0102dd3:	c7 44 24 04 eb 03 00 	movl   $0x3eb,0x4(%esp)
f0102dda:	00 
f0102ddb:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102de2:	e8 d7 d2 ff ff       	call   f01000be <_panic>
	assert(pp1->pp_ref == 0);
f0102de7:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f0102dec:	74 24                	je     f0102e12 <mem_init+0x1c32>
f0102dee:	c7 44 24 0c da 62 10 	movl   $0xf01062da,0xc(%esp)
f0102df5:	f0 
f0102df6:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102dfd:	f0 
f0102dfe:	c7 44 24 04 ec 03 00 	movl   $0x3ec,0x4(%esp)
f0102e05:	00 
f0102e06:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
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
f0102e1e:	2b 05 cc ef 17 f0    	sub    0xf017efcc,%eax
f0102e24:	c1 f8 03             	sar    $0x3,%eax
f0102e27:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102e2a:	89 c2                	mov    %eax,%edx
f0102e2c:	c1 ea 0c             	shr    $0xc,%edx
f0102e2f:	3b 15 c4 ef 17 f0    	cmp    0xf017efc4,%edx
f0102e35:	72 20                	jb     f0102e57 <mem_init+0x1c77>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102e37:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102e3b:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f0102e42:	f0 
f0102e43:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102e4a:	00 
f0102e4b:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
f0102e52:	e8 67 d2 ff ff       	call   f01000be <_panic>
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
f0102e57:	81 b8 00 00 00 f0 03 	cmpl   $0x3030303,-0x10000000(%eax)
f0102e5e:	03 03 03 
f0102e61:	74 24                	je     f0102e87 <mem_init+0x1ca7>
f0102e63:	c7 44 24 0c 14 60 10 	movl   $0xf0106014,0xc(%esp)
f0102e6a:	f0 
f0102e6b:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102e72:	f0 
f0102e73:	c7 44 24 04 ee 03 00 	movl   $0x3ee,0x4(%esp)
f0102e7a:	00 
f0102e7b:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102e82:	e8 37 d2 ff ff       	call   f01000be <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f0102e87:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102e8e:	00 
f0102e8f:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0102e94:	89 04 24             	mov    %eax,(%esp)
f0102e97:	e8 45 e2 ff ff       	call   f01010e1 <page_remove>
	assert(pp2->pp_ref == 0);
f0102e9c:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f0102ea1:	74 24                	je     f0102ec7 <mem_init+0x1ce7>
f0102ea3:	c7 44 24 0c c9 62 10 	movl   $0xf01062c9,0xc(%esp)
f0102eaa:	f0 
f0102eab:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102eb2:	f0 
f0102eb3:	c7 44 24 04 f0 03 00 	movl   $0x3f0,0x4(%esp)
f0102eba:	00 
f0102ebb:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102ec2:	e8 f7 d1 ff ff       	call   f01000be <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102ec7:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0102ecc:	8b 08                	mov    (%eax),%ecx
f0102ece:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102ed4:	89 da                	mov    %ebx,%edx
f0102ed6:	2b 15 cc ef 17 f0    	sub    0xf017efcc,%edx
f0102edc:	c1 fa 03             	sar    $0x3,%edx
f0102edf:	c1 e2 0c             	shl    $0xc,%edx
f0102ee2:	39 d1                	cmp    %edx,%ecx
f0102ee4:	74 24                	je     f0102f0a <mem_init+0x1d2a>
f0102ee6:	c7 44 24 0c 90 5b 10 	movl   $0xf0105b90,0xc(%esp)
f0102eed:	f0 
f0102eee:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102ef5:	f0 
f0102ef6:	c7 44 24 04 f3 03 00 	movl   $0x3f3,0x4(%esp)
f0102efd:	00 
f0102efe:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102f05:	e8 b4 d1 ff ff       	call   f01000be <_panic>
	kern_pgdir[0] = 0;
f0102f0a:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f0102f10:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102f15:	74 24                	je     f0102f3b <mem_init+0x1d5b>
f0102f17:	c7 44 24 0c 80 62 10 	movl   $0xf0106280,0xc(%esp)
f0102f1e:	f0 
f0102f1f:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0102f26:	f0 
f0102f27:	c7 44 24 04 f5 03 00 	movl   $0x3f5,0x4(%esp)
f0102f2e:	00 
f0102f2f:	c7 04 24 a1 60 10 f0 	movl   $0xf01060a1,(%esp)
f0102f36:	e8 83 d1 ff ff       	call   f01000be <_panic>
	pp0->pp_ref = 0;
f0102f3b:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// free the pages we took
	page_free(pp0);
f0102f41:	89 1c 24             	mov    %ebx,(%esp)
f0102f44:	e8 e9 df ff ff       	call   f0100f32 <page_free>

	cprintf("check_page_installed_pgdir() succeeded!\n");
f0102f49:	c7 04 24 40 60 10 f0 	movl   $0xf0106040,(%esp)
f0102f50:	e8 e0 09 00 00       	call   f0103935 <cprintf>
f0102f55:	e9 13 01 00 00       	jmp    f010306d <mem_init+0x1e8d>
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	for(i = 0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		page_insert(kern_pgdir,pa2page(PADDR(envs)+i),(void *)(UENVS + i),PTE_U);
f0102f5a:	a1 0c e3 17 f0       	mov    0xf017e30c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102f5f:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102f64:	0f 87 f9 f6 ff ff    	ja     f0102663 <mem_init+0x1483>
f0102f6a:	e9 1c f7 ff ff       	jmp    f010268b <mem_init+0x14ab>
f0102f6f:	b8 00 20 11 f0       	mov    $0xf0112000,%eax
f0102f74:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102f79:	0f 86 c2 f7 ff ff    	jbe    f0102741 <mem_init+0x1561>
f0102f7f:	e9 92 f7 ff ff       	jmp    f0102716 <mem_init+0x1536>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102f84:	83 3d c4 ef 17 f0 00 	cmpl   $0x0,0xf017efc4
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
f0102fb2:	8b 15 cc ef 17 f0    	mov    0xf017efcc,%edx
f0102fb8:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102fbb:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102fbf:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
f0102fc4:	89 04 24             	mov    %eax,(%esp)
f0102fc7:	e8 53 e1 ff ff       	call   f010111f <page_insert>
f0102fcc:	bb 00 30 11 00       	mov    $0x113000,%ebx
f0102fd1:	be 00 a0 11 00       	mov    $0x11a000,%esi
f0102fd6:	b8 00 80 bf df       	mov    $0xdfbf8000,%eax
f0102fdb:	2d 00 20 11 f0       	sub    $0xf0112000,%eax
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
f0102ff8:	8b 15 cc ef 17 f0    	mov    0xf017efcc,%edx
f0102ffe:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0103001:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103005:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
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
f010303b:	b9 00 20 11 f0       	mov    $0xf0112000,%ecx
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
f0103083:	57                   	push   %edi
f0103084:	56                   	push   %esi
f0103085:	53                   	push   %ebx
f0103086:	83 ec 3c             	sub    $0x3c,%esp
f0103089:	8b 7d 08             	mov    0x8(%ebp),%edi
f010308c:	8b 45 0c             	mov    0xc(%ebp),%eax

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
f010308f:	89 c2                	mov    %eax,%edx
f0103091:	03 55 10             	add    0x10(%ebp),%edx
f0103094:	89 55 d0             	mov    %edx,-0x30(%ebp)
f0103097:	39 d0                	cmp    %edx,%eax
f0103099:	73 70                	jae    f010310b <user_mem_check+0x8b>
f010309b:	89 c3                	mov    %eax,%ebx
f010309d:	89 c6                	mov    %eax,%esi
		pte_t* store=0;
		struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
		if(store!=NULL)
		{
			//cprintf("pte!=NULL %08x\r\n",*store);
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f010309f:	8b 45 14             	mov    0x14(%ebp),%eax
f01030a2:	83 c8 01             	or     $0x1,%eax
f01030a5:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
	{
		pte_t* store=0;
f01030a8:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
		struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
f01030af:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f01030b2:	89 44 24 08          	mov    %eax,0x8(%esp)
f01030b6:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01030ba:	8b 47 5c             	mov    0x5c(%edi),%eax
f01030bd:	89 04 24             	mov    %eax,(%esp)
f01030c0:	e8 af df ff ff       	call   f0101074 <page_lookup>
		if(store!=NULL)
f01030c5:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01030c8:	85 c0                	test   %eax,%eax
f01030ca:	74 1b                	je     f01030e7 <user_mem_check+0x67>
		{
			//cprintf("pte!=NULL %08x\r\n",*store);
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f01030cc:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01030cf:	89 ca                	mov    %ecx,%edx
f01030d1:	23 10                	and    (%eax),%edx
f01030d3:	39 d1                	cmp    %edx,%ecx
f01030d5:	75 08                	jne    f01030df <user_mem_check+0x5f>
f01030d7:	81 fe 00 00 80 ef    	cmp    $0xef800000,%esi
f01030dd:	76 10                	jbe    f01030ef <user_mem_check+0x6f>
			   {
				//cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f01030df:	89 35 fc e2 17 f0    	mov    %esi,0xf017e2fc
				break;
f01030e5:	eb 1d                	jmp    f0103104 <user_mem_check+0x84>
			}
			else
			{
				//cprintf("no pte!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f01030e7:	89 35 fc e2 17 f0    	mov    %esi,0xf017e2fc
				break;
f01030ed:	eb 15                	jmp    f0103104 <user_mem_check+0x84>
			}
		    i=ROUNDDOWN(i,PGSIZE);
f01030ef:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
	int t=(int)va;
	for(i=t;i<(t+len);i+=PGSIZE)
f01030f5:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f01030fb:	89 de                	mov    %ebx,%esi
f01030fd:	3b 5d d0             	cmp    -0x30(%ebp),%ebx
f0103100:	72 a6                	jb     f01030a8 <user_mem_check+0x28>
f0103102:	eb 0e                	jmp    f0103112 <user_mem_check+0x92>
			  if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
			   {
				//cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
				break;
f0103104:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f0103109:	eb 0c                	jmp    f0103117 <user_mem_check+0x97>
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{

	// LAB 3: Your code here.
	 int i=0;
	int flag=0;
f010310b:	b8 00 00 00 00       	mov    $0x0,%eax
f0103110:	eb 05                	jmp    f0103117 <user_mem_check+0x97>
f0103112:	b8 00 00 00 00       	mov    $0x0,%eax
			}
		    i=ROUNDDOWN(i,PGSIZE);
		}

	return flag;
}
f0103117:	83 c4 3c             	add    $0x3c,%esp
f010311a:	5b                   	pop    %ebx
f010311b:	5e                   	pop    %esi
f010311c:	5f                   	pop    %edi
f010311d:	5d                   	pop    %ebp
f010311e:	c3                   	ret    

f010311f <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f010311f:	55                   	push   %ebp
f0103120:	89 e5                	mov    %esp,%ebp
f0103122:	53                   	push   %ebx
f0103123:	83 ec 14             	sub    $0x14,%esp
f0103126:	8b 5d 08             	mov    0x8(%ebp),%ebx
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
f0103129:	8b 45 14             	mov    0x14(%ebp),%eax
f010312c:	83 c8 04             	or     $0x4,%eax
f010312f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103133:	8b 45 10             	mov    0x10(%ebp),%eax
f0103136:	89 44 24 08          	mov    %eax,0x8(%esp)
f010313a:	8b 45 0c             	mov    0xc(%ebp),%eax
f010313d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103141:	89 1c 24             	mov    %ebx,(%esp)
f0103144:	e8 37 ff ff ff       	call   f0103080 <user_mem_check>
f0103149:	85 c0                	test   %eax,%eax
f010314b:	79 24                	jns    f0103171 <user_mem_assert+0x52>
		cprintf(".%08x. user_mem_check assertion failure for "
f010314d:	a1 fc e2 17 f0       	mov    0xf017e2fc,%eax
f0103152:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103156:	8b 43 48             	mov    0x48(%ebx),%eax
f0103159:	89 44 24 04          	mov    %eax,0x4(%esp)
f010315d:	c7 04 24 6c 60 10 f0 	movl   $0xf010606c,(%esp)
f0103164:	e8 cc 07 00 00       	call   f0103935 <cprintf>
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
f0103169:	89 1c 24             	mov    %ebx,(%esp)
f010316c:	e8 91 06 00 00       	call   f0103802 <env_destroy>
	}
}
f0103171:	83 c4 14             	add    $0x14,%esp
f0103174:	5b                   	pop    %ebx
f0103175:	5d                   	pop    %ebp
f0103176:	c3                   	ret    

f0103177 <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f0103177:	55                   	push   %ebp
f0103178:	89 e5                	mov    %esp,%ebp
f010317a:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f010317d:	85 c0                	test   %eax,%eax
f010317f:	75 11                	jne    f0103192 <envid2env+0x1b>
		*env_store = curenv;
f0103181:	a1 08 e3 17 f0       	mov    0xf017e308,%eax
f0103186:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0103189:	89 01                	mov    %eax,(%ecx)
		return 0;
f010318b:	b8 00 00 00 00       	mov    $0x0,%eax
f0103190:	eb 60                	jmp    f01031f2 <envid2env+0x7b>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f0103192:	89 c2                	mov    %eax,%edx
f0103194:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f010319a:	8d 14 52             	lea    (%edx,%edx,2),%edx
f010319d:	c1 e2 05             	shl    $0x5,%edx
f01031a0:	03 15 0c e3 17 f0    	add    0xf017e30c,%edx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f01031a6:	83 7a 54 00          	cmpl   $0x0,0x54(%edx)
f01031aa:	74 05                	je     f01031b1 <envid2env+0x3a>
f01031ac:	39 42 48             	cmp    %eax,0x48(%edx)
f01031af:	74 10                	je     f01031c1 <envid2env+0x4a>
		*env_store = 0;
f01031b1:	8b 45 0c             	mov    0xc(%ebp),%eax
f01031b4:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f01031ba:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01031bf:	eb 31                	jmp    f01031f2 <envid2env+0x7b>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f01031c1:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f01031c5:	74 21                	je     f01031e8 <envid2env+0x71>
f01031c7:	a1 08 e3 17 f0       	mov    0xf017e308,%eax
f01031cc:	39 c2                	cmp    %eax,%edx
f01031ce:	74 18                	je     f01031e8 <envid2env+0x71>
f01031d0:	8b 40 48             	mov    0x48(%eax),%eax
f01031d3:	39 42 4c             	cmp    %eax,0x4c(%edx)
f01031d6:	74 10                	je     f01031e8 <envid2env+0x71>
		*env_store = 0;
f01031d8:	8b 45 0c             	mov    0xc(%ebp),%eax
f01031db:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f01031e1:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01031e6:	eb 0a                	jmp    f01031f2 <envid2env+0x7b>
	}

	*env_store = e;
f01031e8:	8b 45 0c             	mov    0xc(%ebp),%eax
f01031eb:	89 10                	mov    %edx,(%eax)
	return 0;
f01031ed:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01031f2:	5d                   	pop    %ebp
f01031f3:	c3                   	ret    

f01031f4 <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f01031f4:	55                   	push   %ebp
f01031f5:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f01031f7:	b8 00 c3 11 f0       	mov    $0xf011c300,%eax
f01031fc:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f01031ff:	b8 23 00 00 00       	mov    $0x23,%eax
f0103204:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f0103206:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f0103208:	b0 10                	mov    $0x10,%al
f010320a:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f010320c:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f010320e:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f0103210:	ea 17 32 10 f0 08 00 	ljmp   $0x8,$0xf0103217
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f0103217:	b0 00                	mov    $0x0,%al
f0103219:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f010321c:	5d                   	pop    %ebp
f010321d:	c3                   	ret    

f010321e <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f010321e:	55                   	push   %ebp
f010321f:	89 e5                	mov    %esp,%ebp
f0103221:	53                   	push   %ebx
f0103222:	8b 0d 10 e3 17 f0    	mov    0xf017e310,%ecx
f0103228:	a1 0c e3 17 f0       	mov    0xf017e30c,%eax
	// Set up envs array
	// LAB 3: Your code here.
	size_t i;
	for (i = 0; i < NENV; i++) {
		envs[i].env_id = 0;
f010322d:	ba 00 04 00 00       	mov    $0x400,%edx
f0103232:	89 c3                	mov    %eax,%ebx
f0103234:	c7 40 48 00 00 00 00 	movl   $0x0,0x48(%eax)
		envs[i].env_link = env_free_list;
f010323b:	89 48 44             	mov    %ecx,0x44(%eax)
f010323e:	83 c0 60             	add    $0x60,%eax
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
	size_t i;
	for (i = 0; i < NENV; i++) {
f0103241:	83 ea 01             	sub    $0x1,%edx
f0103244:	74 04                	je     f010324a <env_init+0x2c>
		envs[i].env_id = 0;
		envs[i].env_link = env_free_list;
		env_free_list = &envs[i];
f0103246:	89 d9                	mov    %ebx,%ecx
f0103248:	eb e8                	jmp    f0103232 <env_init+0x14>
	}
	env_free_list = envs; // this line of code changing like this ugly looks just fit fuck grade sh,too useless
f010324a:	a1 0c e3 17 f0       	mov    0xf017e30c,%eax
f010324f:	a3 10 e3 17 f0       	mov    %eax,0xf017e310
	// Per-CPU part of the initialization
	env_init_percpu();
f0103254:	e8 9b ff ff ff       	call   f01031f4 <env_init_percpu>
}
f0103259:	5b                   	pop    %ebx
f010325a:	5d                   	pop    %ebp
f010325b:	c3                   	ret    

f010325c <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f010325c:	55                   	push   %ebp
f010325d:	89 e5                	mov    %esp,%ebp
f010325f:	56                   	push   %esi
f0103260:	53                   	push   %ebx
f0103261:	83 ec 10             	sub    $0x10,%esp
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
f0103264:	8b 1d 10 e3 17 f0    	mov    0xf017e310,%ebx
f010326a:	85 db                	test   %ebx,%ebx
f010326c:	0f 84 70 01 00 00    	je     f01033e2 <env_alloc+0x186>
{
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f0103272:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0103279:	e8 2f dc ff ff       	call   f0100ead <page_alloc>
f010327e:	85 c0                	test   %eax,%eax
f0103280:	0f 84 63 01 00 00    	je     f01033e9 <env_alloc+0x18d>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103286:	89 c2                	mov    %eax,%edx
f0103288:	2b 15 cc ef 17 f0    	sub    0xf017efcc,%edx
f010328e:	c1 fa 03             	sar    $0x3,%edx
f0103291:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103294:	89 d1                	mov    %edx,%ecx
f0103296:	c1 e9 0c             	shr    $0xc,%ecx
f0103299:	3b 0d c4 ef 17 f0    	cmp    0xf017efc4,%ecx
f010329f:	72 20                	jb     f01032c1 <env_alloc+0x65>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01032a1:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01032a5:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f01032ac:	f0 
f01032ad:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01032b4:	00 
f01032b5:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
f01032bc:	e8 fd cd ff ff       	call   f01000be <_panic>
	return (void *)(pa + KERNBASE);
f01032c1:	81 ea 00 00 00 10    	sub    $0x10000000,%edx
f01032c7:	89 53 5c             	mov    %edx,0x5c(%ebx)
	//	is an exception -- you need to increment env_pgdir's
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
f01032ca:	ba ec 0e 00 00       	mov    $0xeec,%edx
	for(i=PDX(UTOP);i<1024;i++){
		e->env_pgdir[i] = kern_pgdir[i];
f01032cf:	8b 0d c8 ef 17 f0    	mov    0xf017efc8,%ecx
f01032d5:	8b 34 11             	mov    (%ecx,%edx,1),%esi
f01032d8:	8b 4b 5c             	mov    0x5c(%ebx),%ecx
f01032db:	89 34 11             	mov    %esi,(%ecx,%edx,1)
f01032de:	83 c2 04             	add    $0x4,%edx
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
	e->env_pgdir = page2kva(p);
	for(i=PDX(UTOP);i<1024;i++){
f01032e1:	81 fa 00 10 00 00    	cmp    $0x1000,%edx
f01032e7:	75 e6                	jne    f01032cf <env_alloc+0x73>
		e->env_pgdir[i] = kern_pgdir[i];
	}
	p->pp_ref++;
f01032e9:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f01032ee:	8b 43 5c             	mov    0x5c(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01032f1:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01032f6:	77 20                	ja     f0103318 <env_alloc+0xbc>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01032f8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01032fc:	c7 44 24 08 94 5a 10 	movl   $0xf0105a94,0x8(%esp)
f0103303:	f0 
f0103304:	c7 44 24 04 c3 00 00 	movl   $0xc3,0x4(%esp)
f010330b:	00 
f010330c:	c7 04 24 9a 63 10 f0 	movl   $0xf010639a,(%esp)
f0103313:	e8 a6 cd ff ff       	call   f01000be <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103318:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f010331e:	83 ca 05             	or     $0x5,%edx
f0103321:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate and set up the page directory for this environment.
	if ((r = env_setup_vm(e)) < 0)
		return r;

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f0103327:	8b 43 48             	mov    0x48(%ebx),%eax
f010332a:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f010332f:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f0103334:	ba 00 10 00 00       	mov    $0x1000,%edx
f0103339:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f010333c:	89 da                	mov    %ebx,%edx
f010333e:	2b 15 0c e3 17 f0    	sub    0xf017e30c,%edx
f0103344:	c1 fa 05             	sar    $0x5,%edx
f0103347:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f010334d:	09 d0                	or     %edx,%eax
f010334f:	89 43 48             	mov    %eax,0x48(%ebx)

	// Set the basic status variables.
	e->env_parent_id = parent_id;
f0103352:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103355:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f0103358:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f010335f:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
	e->env_runs = 0;
f0103366:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f010336d:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f0103374:	00 
f0103375:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010337c:	00 
f010337d:	89 1c 24             	mov    %ebx,(%esp)
f0103380:	e8 44 1b 00 00       	call   f0104ec9 <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f0103385:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f010338b:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f0103391:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f0103397:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f010339e:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)
	// You will set e->env_tf.tf_eip later.

	// commit the allocation
	env_free_list = e->env_link;
f01033a4:	8b 43 44             	mov    0x44(%ebx),%eax
f01033a7:	a3 10 e3 17 f0       	mov    %eax,0xf017e310
	*newenv_store = e;
f01033ac:	8b 45 08             	mov    0x8(%ebp),%eax
f01033af:	89 18                	mov    %ebx,(%eax)

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f01033b1:	8b 53 48             	mov    0x48(%ebx),%edx
f01033b4:	a1 08 e3 17 f0       	mov    0xf017e308,%eax
f01033b9:	85 c0                	test   %eax,%eax
f01033bb:	74 05                	je     f01033c2 <env_alloc+0x166>
f01033bd:	8b 40 48             	mov    0x48(%eax),%eax
f01033c0:	eb 05                	jmp    f01033c7 <env_alloc+0x16b>
f01033c2:	b8 00 00 00 00       	mov    $0x0,%eax
f01033c7:	89 54 24 08          	mov    %edx,0x8(%esp)
f01033cb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01033cf:	c7 04 24 a5 63 10 f0 	movl   $0xf01063a5,(%esp)
f01033d6:	e8 5a 05 00 00       	call   f0103935 <cprintf>
	return 0;
f01033db:	b8 00 00 00 00       	mov    $0x0,%eax
f01033e0:	eb 0c                	jmp    f01033ee <env_alloc+0x192>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
		return -E_NO_FREE_ENV;
f01033e2:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f01033e7:	eb 05                	jmp    f01033ee <env_alloc+0x192>
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f01033e9:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	env_free_list = e->env_link;
	*newenv_store = e;

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}
f01033ee:	83 c4 10             	add    $0x10,%esp
f01033f1:	5b                   	pop    %ebx
f01033f2:	5e                   	pop    %esi
f01033f3:	5d                   	pop    %ebp
f01033f4:	c3                   	ret    

f01033f5 <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f01033f5:	55                   	push   %ebp
f01033f6:	89 e5                	mov    %esp,%ebp
f01033f8:	57                   	push   %edi
f01033f9:	56                   	push   %esi
f01033fa:	53                   	push   %ebx
f01033fb:	83 ec 3c             	sub    $0x3c,%esp
	// LAB 3: Your code here.
	struct Env * env;
	if(env_alloc(&env,0)==0){
f01033fe:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0103405:	00 
f0103406:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0103409:	89 04 24             	mov    %eax,(%esp)
f010340c:	e8 4b fe ff ff       	call   f010325c <env_alloc>
f0103411:	85 c0                	test   %eax,%eax
f0103413:	0f 85 dd 01 00 00    	jne    f01035f6 <env_create+0x201>
		load_icode(env,binary,size);
f0103419:	8b 7d e4             	mov    -0x1c(%ebp),%edi
	//  You must also do something with the program's entry point,
	//  to make sure that the environment starts executing there.
	//  What?  (See env_run() and env_pop_tf() below.)

	// LAB 3: Your code here.
	lcr3(PADDR(e->env_pgdir));
f010341c:	8b 47 5c             	mov    0x5c(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010341f:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103424:	77 20                	ja     f0103446 <env_create+0x51>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103426:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010342a:	c7 44 24 08 94 5a 10 	movl   $0xf0105a94,0x8(%esp)
f0103431:	f0 
f0103432:	c7 44 24 04 58 01 00 	movl   $0x158,0x4(%esp)
f0103439:	00 
f010343a:	c7 04 24 9a 63 10 f0 	movl   $0xf010639a,(%esp)
f0103441:	e8 78 cc ff ff       	call   f01000be <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103446:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f010344b:	0f 22 d8             	mov    %eax,%cr3
	struct Elf* ELFHDR = (struct Elf *) binary;
	if(ELFHDR->e_magic != ELF_MAGIC)
f010344e:	8b 45 08             	mov    0x8(%ebp),%eax
f0103451:	81 38 7f 45 4c 46    	cmpl   $0x464c457f,(%eax)
f0103457:	74 1c                	je     f0103475 <env_create+0x80>
		panic("Invalid ELF format !");
f0103459:	c7 44 24 08 ba 63 10 	movl   $0xf01063ba,0x8(%esp)
f0103460:	f0 
f0103461:	c7 44 24 04 5b 01 00 	movl   $0x15b,0x4(%esp)
f0103468:	00 
f0103469:	c7 04 24 9a 63 10 f0 	movl   $0xf010639a,(%esp)
f0103470:	e8 49 cc ff ff       	call   f01000be <_panic>

	struct Proghdr *ph,*eph;
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
f0103475:	8b 45 08             	mov    0x8(%ebp),%eax
f0103478:	89 c6                	mov    %eax,%esi
f010347a:	03 70 1c             	add    0x1c(%eax),%esi
	eph = ph + ELFHDR->e_phnum;
f010347d:	0f b7 40 2c          	movzwl 0x2c(%eax),%eax
f0103481:	c1 e0 05             	shl    $0x5,%eax
f0103484:	01 f0                	add    %esi,%eax
f0103486:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	for (; ph < eph; ph++) {
f0103489:	39 c6                	cmp    %eax,%esi
f010348b:	0f 83 d2 00 00 00    	jae    f0103563 <env_create+0x16e>
		if (ph->p_type == ELF_PROG_LOAD) {
f0103491:	83 3e 01             	cmpl   $0x1,(%esi)
f0103494:	0f 85 bd 00 00 00    	jne    f0103557 <env_create+0x162>
			if (ph->p_filesz > ph->p_memsz)
f010349a:	8b 56 14             	mov    0x14(%esi),%edx
f010349d:	39 56 10             	cmp    %edx,0x10(%esi)
f01034a0:	76 1c                	jbe    f01034be <env_create+0xc9>
				panic("invalid ELF proGhdr header!");
f01034a2:	c7 44 24 08 cf 63 10 	movl   $0xf01063cf,0x8(%esp)
f01034a9:	f0 
f01034aa:	c7 44 24 04 63 01 00 	movl   $0x163,0x4(%esp)
f01034b1:	00 
f01034b2:	c7 04 24 9a 63 10 f0 	movl   $0xf010639a,(%esp)
f01034b9:	e8 00 cc ff ff       	call   f01000be <_panic>

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
f01034be:	8b 46 08             	mov    0x8(%esi),%eax
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f01034c1:	89 c3                	mov    %eax,%ebx
f01034c3:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f01034c9:	8d 84 02 ff 0f 00 00 	lea    0xfff(%edx,%eax,1),%eax
f01034d0:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01034d5:	39 c3                	cmp    %eax,%ebx
f01034d7:	73 59                	jae    f0103532 <env_create+0x13d>
f01034d9:	89 75 d0             	mov    %esi,-0x30(%ebp)
f01034dc:	89 c6                	mov    %eax,%esi
		p = (struct Page*)page_alloc(1);
f01034de:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01034e5:	e8 c3 d9 ff ff       	call   f0100ead <page_alloc>
		if(p==NULL)
f01034ea:	85 c0                	test   %eax,%eax
f01034ec:	75 1c                	jne    f010350a <env_create+0x115>
			panic("Memory out!");
f01034ee:	c7 44 24 08 eb 63 10 	movl   $0xf01063eb,0x8(%esp)
f01034f5:	f0 
f01034f6:	c7 44 24 04 1d 01 00 	movl   $0x11d,0x4(%esp)
f01034fd:	00 
f01034fe:	c7 04 24 9a 63 10 f0 	movl   $0xf010639a,(%esp)
f0103505:	e8 b4 cb ff ff       	call   f01000be <_panic>
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
f010350a:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0103511:	00 
f0103512:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103516:	89 44 24 04          	mov    %eax,0x4(%esp)
f010351a:	8b 47 5c             	mov    0x5c(%edi),%eax
f010351d:	89 04 24             	mov    %eax,(%esp)
f0103520:	e8 fa db ff ff       	call   f010111f <page_insert>
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i ;
	struct Page* p=NULL;
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE){
f0103525:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f010352b:	39 f3                	cmp    %esi,%ebx
f010352d:	72 af                	jb     f01034de <env_create+0xe9>
f010352f:	8b 75 d0             	mov    -0x30(%ebp),%esi
			if (ph->p_filesz > ph->p_memsz)
				panic("invalid ELF proGhdr header!");

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
			//copy to va
			char *va = (char *)(ph->p_va);
f0103532:	8b 4e 08             	mov    0x8(%esi),%ecx
			size_t i;
			for (i = 0; i < ph->p_filesz; i++)
f0103535:	83 7e 10 00          	cmpl   $0x0,0x10(%esi)
f0103539:	74 1c                	je     f0103557 <env_create+0x162>
f010353b:	b8 00 00 00 00       	mov    $0x0,%eax
f0103540:	8b 5d 08             	mov    0x8(%ebp),%ebx
				va[i] = binary[ph->p_offset + i];
f0103543:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f0103546:	03 56 04             	add    0x4(%esi),%edx
f0103549:	0f b6 12             	movzbl (%edx),%edx
f010354c:	88 14 08             	mov    %dl,(%eax,%ecx,1)

			region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
			//copy to va
			char *va = (char *)(ph->p_va);
			size_t i;
			for (i = 0; i < ph->p_filesz; i++)
f010354f:	83 c0 01             	add    $0x1,%eax
f0103552:	3b 46 10             	cmp    0x10(%esi),%eax
f0103555:	72 ec                	jb     f0103543 <env_create+0x14e>
		panic("Invalid ELF format !");

	struct Proghdr *ph,*eph;
	ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
	eph = ph + ELFHDR->e_phnum;
	for (; ph < eph; ph++) {
f0103557:	83 c6 20             	add    $0x20,%esi
f010355a:	39 75 d4             	cmp    %esi,-0x2c(%ebp)
f010355d:	0f 87 2e ff ff ff    	ja     f0103491 <env_create+0x9c>
			for (i = 0; i < ph->p_filesz; i++)
				va[i] = binary[ph->p_offset + i];
		}
	}
	//set programe entry
	e->env_tf.tf_eip = ELFHDR->e_entry;
f0103563:	8b 45 08             	mov    0x8(%ebp),%eax
f0103566:	8b 40 18             	mov    0x18(%eax),%eax
f0103569:	89 47 30             	mov    %eax,0x30(%edi)
	// Now map one page for the program's initial stack
	// at virtual address USTACKTOP - PGSIZE.

	// LAB 3: Your code here.
	struct Page* stackPage = (struct Page*)page_alloc(1);
f010356c:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0103573:	e8 35 d9 ff ff       	call   f0100ead <page_alloc>
	if(stackPage == NULL)
f0103578:	85 c0                	test   %eax,%eax
f010357a:	75 1c                	jne    f0103598 <env_create+0x1a3>
		panic("Out of memory!");
f010357c:	c7 44 24 08 f7 63 10 	movl   $0xf01063f7,0x8(%esp)
f0103583:	f0 
f0103584:	c7 44 24 04 75 01 00 	movl   $0x175,0x4(%esp)
f010358b:	00 
f010358c:	c7 04 24 9a 63 10 f0 	movl   $0xf010639a,(%esp)
f0103593:	e8 26 cb ff ff       	call   f01000be <_panic>
	page_insert(e->env_pgdir,stackPage,(void*)USTACKTOP - PGSIZE,PTE_U|PTE_W);
f0103598:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f010359f:	00 
f01035a0:	c7 44 24 08 00 d0 bf 	movl   $0xeebfd000,0x8(%esp)
f01035a7:	ee 
f01035a8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01035ac:	8b 47 5c             	mov    0x5c(%edi),%eax
f01035af:	89 04 24             	mov    %eax,(%esp)
f01035b2:	e8 68 db ff ff       	call   f010111f <page_insert>
	lcr3(PADDR(kern_pgdir));
f01035b7:	a1 c8 ef 17 f0       	mov    0xf017efc8,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01035bc:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01035c1:	77 20                	ja     f01035e3 <env_create+0x1ee>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01035c3:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01035c7:	c7 44 24 08 94 5a 10 	movl   $0xf0105a94,0x8(%esp)
f01035ce:	f0 
f01035cf:	c7 44 24 04 77 01 00 	movl   $0x177,0x4(%esp)
f01035d6:	00 
f01035d7:	c7 04 24 9a 63 10 f0 	movl   $0xf010639a,(%esp)
f01035de:	e8 db ca ff ff       	call   f01000be <_panic>
	return (physaddr_t)kva - KERNBASE;
f01035e3:	05 00 00 00 10       	add    $0x10000000,%eax
f01035e8:	0f 22 d8             	mov    %eax,%cr3
{
	// LAB 3: Your code here.
	struct Env * env;
	if(env_alloc(&env,0)==0){
		load_icode(env,binary,size);
		env->env_type = type;
f01035eb:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01035ee:	8b 55 10             	mov    0x10(%ebp),%edx
f01035f1:	89 50 50             	mov    %edx,0x50(%eax)
f01035f4:	eb 1c                	jmp    f0103612 <env_create+0x21d>
	}else{
		panic("create env fails !");
f01035f6:	c7 44 24 08 06 64 10 	movl   $0xf0106406,0x8(%esp)
f01035fd:	f0 
f01035fe:	c7 44 24 04 8a 01 00 	movl   $0x18a,0x4(%esp)
f0103605:	00 
f0103606:	c7 04 24 9a 63 10 f0 	movl   $0xf010639a,(%esp)
f010360d:	e8 ac ca ff ff       	call   f01000be <_panic>
	}
}
f0103612:	83 c4 3c             	add    $0x3c,%esp
f0103615:	5b                   	pop    %ebx
f0103616:	5e                   	pop    %esi
f0103617:	5f                   	pop    %edi
f0103618:	5d                   	pop    %ebp
f0103619:	c3                   	ret    

f010361a <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f010361a:	55                   	push   %ebp
f010361b:	89 e5                	mov    %esp,%ebp
f010361d:	57                   	push   %edi
f010361e:	56                   	push   %esi
f010361f:	53                   	push   %ebx
f0103620:	83 ec 2c             	sub    $0x2c,%esp
f0103623:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f0103626:	a1 08 e3 17 f0       	mov    0xf017e308,%eax
f010362b:	39 c7                	cmp    %eax,%edi
f010362d:	75 37                	jne    f0103666 <env_free+0x4c>
		lcr3(PADDR(kern_pgdir));
f010362f:	8b 15 c8 ef 17 f0    	mov    0xf017efc8,%edx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103635:	81 fa ff ff ff ef    	cmp    $0xefffffff,%edx
f010363b:	77 20                	ja     f010365d <env_free+0x43>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010363d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0103641:	c7 44 24 08 94 5a 10 	movl   $0xf0105a94,0x8(%esp)
f0103648:	f0 
f0103649:	c7 44 24 04 9c 01 00 	movl   $0x19c,0x4(%esp)
f0103650:	00 
f0103651:	c7 04 24 9a 63 10 f0 	movl   $0xf010639a,(%esp)
f0103658:	e8 61 ca ff ff       	call   f01000be <_panic>
	return (physaddr_t)kva - KERNBASE;
f010365d:	81 c2 00 00 00 10    	add    $0x10000000,%edx
f0103663:	0f 22 da             	mov    %edx,%cr3

	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0103666:	8b 57 48             	mov    0x48(%edi),%edx
f0103669:	85 c0                	test   %eax,%eax
f010366b:	74 05                	je     f0103672 <env_free+0x58>
f010366d:	8b 40 48             	mov    0x48(%eax),%eax
f0103670:	eb 05                	jmp    f0103677 <env_free+0x5d>
f0103672:	b8 00 00 00 00       	mov    $0x0,%eax
f0103677:	89 54 24 08          	mov    %edx,0x8(%esp)
f010367b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010367f:	c7 04 24 19 64 10 f0 	movl   $0xf0106419,(%esp)
f0103686:	e8 aa 02 00 00       	call   f0103935 <cprintf>

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f010368b:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0103692:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0103695:	89 c8                	mov    %ecx,%eax
f0103697:	c1 e0 02             	shl    $0x2,%eax
f010369a:	89 45 dc             	mov    %eax,-0x24(%ebp)

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f010369d:	8b 47 5c             	mov    0x5c(%edi),%eax
f01036a0:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f01036a3:	f7 c6 01 00 00 00    	test   $0x1,%esi
f01036a9:	0f 84 b7 00 00 00    	je     f0103766 <env_free+0x14c>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f01036af:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01036b5:	89 f0                	mov    %esi,%eax
f01036b7:	c1 e8 0c             	shr    $0xc,%eax
f01036ba:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01036bd:	3b 05 c4 ef 17 f0    	cmp    0xf017efc4,%eax
f01036c3:	72 20                	jb     f01036e5 <env_free+0xcb>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01036c5:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01036c9:	c7 44 24 08 50 59 10 	movl   $0xf0105950,0x8(%esp)
f01036d0:	f0 
f01036d1:	c7 44 24 04 ab 01 00 	movl   $0x1ab,0x4(%esp)
f01036d8:	00 
f01036d9:	c7 04 24 9a 63 10 f0 	movl   $0xf010639a,(%esp)
f01036e0:	e8 d9 c9 ff ff       	call   f01000be <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f01036e5:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01036e8:	c1 e0 16             	shl    $0x16,%eax
f01036eb:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f01036ee:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f01036f3:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f01036fa:	01 
f01036fb:	74 17                	je     f0103714 <env_free+0xfa>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f01036fd:	89 d8                	mov    %ebx,%eax
f01036ff:	c1 e0 0c             	shl    $0xc,%eax
f0103702:	0b 45 e4             	or     -0x1c(%ebp),%eax
f0103705:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103709:	8b 47 5c             	mov    0x5c(%edi),%eax
f010370c:	89 04 24             	mov    %eax,(%esp)
f010370f:	e8 cd d9 ff ff       	call   f01010e1 <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103714:	83 c3 01             	add    $0x1,%ebx
f0103717:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f010371d:	75 d4                	jne    f01036f3 <env_free+0xd9>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f010371f:	8b 47 5c             	mov    0x5c(%edi),%eax
f0103722:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103725:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010372c:	8b 45 d8             	mov    -0x28(%ebp),%eax
f010372f:	3b 05 c4 ef 17 f0    	cmp    0xf017efc4,%eax
f0103735:	72 1c                	jb     f0103753 <env_free+0x139>
		panic("pa2page called with invalid pa");
f0103737:	c7 44 24 08 38 5a 10 	movl   $0xf0105a38,0x8(%esp)
f010373e:	f0 
f010373f:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103746:	00 
f0103747:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
f010374e:	e8 6b c9 ff ff       	call   f01000be <_panic>
	return &pages[PGNUM(pa)];
f0103753:	a1 cc ef 17 f0       	mov    0xf017efcc,%eax
f0103758:	8b 55 d8             	mov    -0x28(%ebp),%edx
f010375b:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f010375e:	89 04 24             	mov    %eax,(%esp)
f0103761:	e8 e1 d7 ff ff       	call   f0100f47 <page_decref>
	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103766:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f010376a:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f0103771:	0f 85 1b ff ff ff    	jne    f0103692 <env_free+0x78>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f0103777:	8b 47 5c             	mov    0x5c(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010377a:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010377f:	77 20                	ja     f01037a1 <env_free+0x187>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103781:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103785:	c7 44 24 08 94 5a 10 	movl   $0xf0105a94,0x8(%esp)
f010378c:	f0 
f010378d:	c7 44 24 04 b9 01 00 	movl   $0x1b9,0x4(%esp)
f0103794:	00 
f0103795:	c7 04 24 9a 63 10 f0 	movl   $0xf010639a,(%esp)
f010379c:	e8 1d c9 ff ff       	call   f01000be <_panic>
	e->env_pgdir = 0;
f01037a1:	c7 47 5c 00 00 00 00 	movl   $0x0,0x5c(%edi)
	return (physaddr_t)kva - KERNBASE;
f01037a8:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01037ad:	c1 e8 0c             	shr    $0xc,%eax
f01037b0:	3b 05 c4 ef 17 f0    	cmp    0xf017efc4,%eax
f01037b6:	72 1c                	jb     f01037d4 <env_free+0x1ba>
		panic("pa2page called with invalid pa");
f01037b8:	c7 44 24 08 38 5a 10 	movl   $0xf0105a38,0x8(%esp)
f01037bf:	f0 
f01037c0:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01037c7:	00 
f01037c8:	c7 04 24 ad 60 10 f0 	movl   $0xf01060ad,(%esp)
f01037cf:	e8 ea c8 ff ff       	call   f01000be <_panic>
	return &pages[PGNUM(pa)];
f01037d4:	8b 15 cc ef 17 f0    	mov    0xf017efcc,%edx
f01037da:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f01037dd:	89 04 24             	mov    %eax,(%esp)
f01037e0:	e8 62 d7 ff ff       	call   f0100f47 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f01037e5:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f01037ec:	a1 10 e3 17 f0       	mov    0xf017e310,%eax
f01037f1:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f01037f4:	89 3d 10 e3 17 f0    	mov    %edi,0xf017e310
}
f01037fa:	83 c4 2c             	add    $0x2c,%esp
f01037fd:	5b                   	pop    %ebx
f01037fe:	5e                   	pop    %esi
f01037ff:	5f                   	pop    %edi
f0103800:	5d                   	pop    %ebp
f0103801:	c3                   	ret    

f0103802 <env_destroy>:
//
// Frees environment e.
//
void
env_destroy(struct Env *e)
{
f0103802:	55                   	push   %ebp
f0103803:	89 e5                	mov    %esp,%ebp
f0103805:	83 ec 18             	sub    $0x18,%esp
	env_free(e);
f0103808:	8b 45 08             	mov    0x8(%ebp),%eax
f010380b:	89 04 24             	mov    %eax,(%esp)
f010380e:	e8 07 fe ff ff       	call   f010361a <env_free>

	cprintf("Destroyed the only environment - nothing more to do!\n");
f0103813:	c7 04 24 64 63 10 f0 	movl   $0xf0106364,(%esp)
f010381a:	e8 16 01 00 00       	call   f0103935 <cprintf>
	while (1)
		monitor(NULL);
f010381f:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0103826:	e8 07 d0 ff ff       	call   f0100832 <monitor>
f010382b:	eb f2                	jmp    f010381f <env_destroy+0x1d>

f010382d <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f010382d:	55                   	push   %ebp
f010382e:	89 e5                	mov    %esp,%ebp
f0103830:	83 ec 18             	sub    $0x18,%esp
	__asm __volatile("movl %0,%%esp\n"
f0103833:	8b 65 08             	mov    0x8(%ebp),%esp
f0103836:	61                   	popa   
f0103837:	07                   	pop    %es
f0103838:	1f                   	pop    %ds
f0103839:	83 c4 08             	add    $0x8,%esp
f010383c:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f010383d:	c7 44 24 08 2f 64 10 	movl   $0xf010642f,0x8(%esp)
f0103844:	f0 
f0103845:	c7 44 24 04 e1 01 00 	movl   $0x1e1,0x4(%esp)
f010384c:	00 
f010384d:	c7 04 24 9a 63 10 f0 	movl   $0xf010639a,(%esp)
f0103854:	e8 65 c8 ff ff       	call   f01000be <_panic>

f0103859 <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0103859:	55                   	push   %ebp
f010385a:	89 e5                	mov    %esp,%ebp
f010385c:	83 ec 18             	sub    $0x18,%esp
f010385f:	8b 45 08             	mov    0x8(%ebp),%eax

	// Hint: This function loads the new environment's state from
	//	e->env_tf.  Go back through the code you wrote above
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.
	if(curenv!=NULL&& curenv->env_status==ENV_RUNNING)
f0103862:	8b 15 08 e3 17 f0    	mov    0xf017e308,%edx
f0103868:	85 d2                	test   %edx,%edx
f010386a:	74 0d                	je     f0103879 <env_run+0x20>
f010386c:	83 7a 54 02          	cmpl   $0x2,0x54(%edx)
f0103870:	75 07                	jne    f0103879 <env_run+0x20>
		curenv->env_status = ENV_RUNNABLE;
f0103872:	c7 42 54 01 00 00 00 	movl   $0x1,0x54(%edx)

	curenv = e;
f0103879:	a3 08 e3 17 f0       	mov    %eax,0xf017e308
	int zero = 0;
	e->env_status = ENV_RUNNING;
f010387e:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)
	e->env_runs++;
f0103885:	83 40 58 01          	addl   $0x1,0x58(%eax)
	lcr3(PADDR(e->env_pgdir));
f0103889:	8b 50 5c             	mov    0x5c(%eax),%edx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010388c:	81 fa ff ff ff ef    	cmp    $0xefffffff,%edx
f0103892:	77 20                	ja     f01038b4 <env_run+0x5b>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103894:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0103898:	c7 44 24 08 94 5a 10 	movl   $0xf0105a94,0x8(%esp)
f010389f:	f0 
f01038a0:	c7 44 24 04 04 02 00 	movl   $0x204,0x4(%esp)
f01038a7:	00 
f01038a8:	c7 04 24 9a 63 10 f0 	movl   $0xf010639a,(%esp)
f01038af:	e8 0a c8 ff ff       	call   f01000be <_panic>
	return (physaddr_t)kva - KERNBASE;
f01038b4:	81 c2 00 00 00 10    	add    $0x10000000,%edx
f01038ba:	0f 22 da             	mov    %edx,%cr3
	env_pop_tf(&e->env_tf);
f01038bd:	89 04 24             	mov    %eax,(%esp)
f01038c0:	e8 68 ff ff ff       	call   f010382d <env_pop_tf>

f01038c5 <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f01038c5:	55                   	push   %ebp
f01038c6:	89 e5                	mov    %esp,%ebp
f01038c8:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01038cc:	ba 70 00 00 00       	mov    $0x70,%edx
f01038d1:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01038d2:	b2 71                	mov    $0x71,%dl
f01038d4:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f01038d5:	0f b6 c0             	movzbl %al,%eax
}
f01038d8:	5d                   	pop    %ebp
f01038d9:	c3                   	ret    

f01038da <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f01038da:	55                   	push   %ebp
f01038db:	89 e5                	mov    %esp,%ebp
f01038dd:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01038e1:	ba 70 00 00 00       	mov    $0x70,%edx
f01038e6:	ee                   	out    %al,(%dx)
f01038e7:	b2 71                	mov    $0x71,%dl
f01038e9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01038ec:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f01038ed:	5d                   	pop    %ebp
f01038ee:	c3                   	ret    

f01038ef <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f01038ef:	55                   	push   %ebp
f01038f0:	89 e5                	mov    %esp,%ebp
f01038f2:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f01038f5:	8b 45 08             	mov    0x8(%ebp),%eax
f01038f8:	89 04 24             	mov    %eax,(%esp)
f01038fb:	e8 34 cd ff ff       	call   f0100634 <cputchar>
	*cnt++;
}
f0103900:	c9                   	leave  
f0103901:	c3                   	ret    

f0103902 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0103902:	55                   	push   %ebp
f0103903:	89 e5                	mov    %esp,%ebp
f0103905:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0103908:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f010390f:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103912:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103916:	8b 45 08             	mov    0x8(%ebp),%eax
f0103919:	89 44 24 08          	mov    %eax,0x8(%esp)
f010391d:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0103920:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103924:	c7 04 24 ef 38 10 f0 	movl   $0xf01038ef,(%esp)
f010392b:	e8 54 0e 00 00       	call   f0104784 <vprintfmt>
	return cnt;
}
f0103930:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0103933:	c9                   	leave  
f0103934:	c3                   	ret    

f0103935 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0103935:	55                   	push   %ebp
f0103936:	89 e5                	mov    %esp,%ebp
f0103938:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f010393b:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f010393e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103942:	8b 45 08             	mov    0x8(%ebp),%eax
f0103945:	89 04 24             	mov    %eax,(%esp)
f0103948:	e8 b5 ff ff ff       	call   f0103902 <vcprintf>
	va_end(ap);

	return cnt;
}
f010394d:	c9                   	leave  
f010394e:	c3                   	ret    
f010394f:	90                   	nop

f0103950 <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f0103950:	55                   	push   %ebp
f0103951:	89 e5                	mov    %esp,%ebp
	// Setup a TSS so that we get the right stack
	// when we trap to the kernel.
	ts.ts_esp0 = KSTACKTOP;
f0103953:	c7 05 44 eb 17 f0 00 	movl   $0xefc00000,0xf017eb44
f010395a:	00 c0 ef 
	ts.ts_ss0 = GD_KD;
f010395d:	66 c7 05 48 eb 17 f0 	movw   $0x10,0xf017eb48
f0103964:	10 00 

	// Initialize the TSS slot of the gdt.
	gdt[GD_TSS0 >> 3] = SEG16(STS_T32A, (uint32_t) (&ts),
f0103966:	66 c7 05 48 c3 11 f0 	movw   $0x68,0xf011c348
f010396d:	68 00 
f010396f:	b8 40 eb 17 f0       	mov    $0xf017eb40,%eax
f0103974:	66 a3 4a c3 11 f0    	mov    %ax,0xf011c34a
f010397a:	89 c2                	mov    %eax,%edx
f010397c:	c1 ea 10             	shr    $0x10,%edx
f010397f:	88 15 4c c3 11 f0    	mov    %dl,0xf011c34c
f0103985:	c6 05 4e c3 11 f0 40 	movb   $0x40,0xf011c34e
f010398c:	c1 e8 18             	shr    $0x18,%eax
f010398f:	a2 4f c3 11 f0       	mov    %al,0xf011c34f
					sizeof(struct Taskstate), 0);
	gdt[GD_TSS0 >> 3].sd_s = 0;
f0103994:	c6 05 4d c3 11 f0 89 	movb   $0x89,0xf011c34d
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f010399b:	b8 28 00 00 00       	mov    $0x28,%eax
f01039a0:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f01039a3:	b8 50 c3 11 f0       	mov    $0xf011c350,%eax
f01039a8:	0f 01 18             	lidtl  (%eax)
	// bottom three bits are special; we leave them 0)
	ltr(GD_TSS0);

	// Load the IDT
	lidt(&idt_pd);
}
f01039ab:	5d                   	pop    %ebp
f01039ac:	c3                   	ret    

f01039ad <trap_init>:
}


void
trap_init(void)
{
f01039ad:	55                   	push   %ebp
f01039ae:	89 e5                	mov    %esp,%ebp
	extern struct Segdesc gdt[];
	SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);
f01039b0:	b8 aa 40 10 f0       	mov    $0xf01040aa,%eax
f01039b5:	66 a3 20 e3 17 f0    	mov    %ax,0xf017e320
f01039bb:	66 c7 05 22 e3 17 f0 	movw   $0x8,0xf017e322
f01039c2:	08 00 
f01039c4:	c6 05 24 e3 17 f0 00 	movb   $0x0,0xf017e324
f01039cb:	c6 05 25 e3 17 f0 8f 	movb   $0x8f,0xf017e325
f01039d2:	c1 e8 10             	shr    $0x10,%eax
f01039d5:	66 a3 26 e3 17 f0    	mov    %ax,0xf017e326
	SETGATE(idt[2], 0, GD_KT, nmi_handler, 0);
f01039db:	b8 b0 40 10 f0       	mov    $0xf01040b0,%eax
f01039e0:	66 a3 30 e3 17 f0    	mov    %ax,0xf017e330
f01039e6:	66 c7 05 32 e3 17 f0 	movw   $0x8,0xf017e332
f01039ed:	08 00 
f01039ef:	c6 05 34 e3 17 f0 00 	movb   $0x0,0xf017e334
f01039f6:	c6 05 35 e3 17 f0 8e 	movb   $0x8e,0xf017e335
f01039fd:	c1 e8 10             	shr    $0x10,%eax
f0103a00:	66 a3 36 e3 17 f0    	mov    %ax,0xf017e336
	SETGATE(idt[3], 1, GD_KT, breakpoint_handler, 3);
f0103a06:	b8 b6 40 10 f0       	mov    $0xf01040b6,%eax
f0103a0b:	66 a3 38 e3 17 f0    	mov    %ax,0xf017e338
f0103a11:	66 c7 05 3a e3 17 f0 	movw   $0x8,0xf017e33a
f0103a18:	08 00 
f0103a1a:	c6 05 3c e3 17 f0 00 	movb   $0x0,0xf017e33c
f0103a21:	c6 05 3d e3 17 f0 ef 	movb   $0xef,0xf017e33d
f0103a28:	c1 e8 10             	shr    $0x10,%eax
f0103a2b:	66 a3 3e e3 17 f0    	mov    %ax,0xf017e33e
	SETGATE(idt[4], 1, GD_KT, overflow_handler, 3);
f0103a31:	b8 bc 40 10 f0       	mov    $0xf01040bc,%eax
f0103a36:	66 a3 40 e3 17 f0    	mov    %ax,0xf017e340
f0103a3c:	66 c7 05 42 e3 17 f0 	movw   $0x8,0xf017e342
f0103a43:	08 00 
f0103a45:	c6 05 44 e3 17 f0 00 	movb   $0x0,0xf017e344
f0103a4c:	c6 05 45 e3 17 f0 ef 	movb   $0xef,0xf017e345
f0103a53:	c1 e8 10             	shr    $0x10,%eax
f0103a56:	66 a3 46 e3 17 f0    	mov    %ax,0xf017e346
	SETGATE(idt[5], 1, GD_KT, bdrgeexceed_handler, 3);
f0103a5c:	b8 c2 40 10 f0       	mov    $0xf01040c2,%eax
f0103a61:	66 a3 48 e3 17 f0    	mov    %ax,0xf017e348
f0103a67:	66 c7 05 4a e3 17 f0 	movw   $0x8,0xf017e34a
f0103a6e:	08 00 
f0103a70:	c6 05 4c e3 17 f0 00 	movb   $0x0,0xf017e34c
f0103a77:	c6 05 4d e3 17 f0 ef 	movb   $0xef,0xf017e34d
f0103a7e:	c1 e8 10             	shr    $0x10,%eax
f0103a81:	66 a3 4e e3 17 f0    	mov    %ax,0xf017e34e
	SETGATE(idt[6], 1, GD_KT, invalidop_handler, 0);
f0103a87:	b8 c8 40 10 f0       	mov    $0xf01040c8,%eax
f0103a8c:	66 a3 50 e3 17 f0    	mov    %ax,0xf017e350
f0103a92:	66 c7 05 52 e3 17 f0 	movw   $0x8,0xf017e352
f0103a99:	08 00 
f0103a9b:	c6 05 54 e3 17 f0 00 	movb   $0x0,0xf017e354
f0103aa2:	c6 05 55 e3 17 f0 8f 	movb   $0x8f,0xf017e355
f0103aa9:	c1 e8 10             	shr    $0x10,%eax
f0103aac:	66 a3 56 e3 17 f0    	mov    %ax,0xf017e356
	SETGATE(idt[7], 1, GD_KT, nomathcopro_handler, 0);
f0103ab2:	b8 ce 40 10 f0       	mov    $0xf01040ce,%eax
f0103ab7:	66 a3 58 e3 17 f0    	mov    %ax,0xf017e358
f0103abd:	66 c7 05 5a e3 17 f0 	movw   $0x8,0xf017e35a
f0103ac4:	08 00 
f0103ac6:	c6 05 5c e3 17 f0 00 	movb   $0x0,0xf017e35c
f0103acd:	c6 05 5d e3 17 f0 8f 	movb   $0x8f,0xf017e35d
f0103ad4:	c1 e8 10             	shr    $0x10,%eax
f0103ad7:	66 a3 5e e3 17 f0    	mov    %ax,0xf017e35e
	SETGATE(idt[8], 1, GD_KT, dbfault_handler, 0);
f0103add:	b8 d4 40 10 f0       	mov    $0xf01040d4,%eax
f0103ae2:	66 a3 60 e3 17 f0    	mov    %ax,0xf017e360
f0103ae8:	66 c7 05 62 e3 17 f0 	movw   $0x8,0xf017e362
f0103aef:	08 00 
f0103af1:	c6 05 64 e3 17 f0 00 	movb   $0x0,0xf017e364
f0103af8:	c6 05 65 e3 17 f0 8f 	movb   $0x8f,0xf017e365
f0103aff:	c1 e8 10             	shr    $0x10,%eax
f0103b02:	66 a3 66 e3 17 f0    	mov    %ax,0xf017e366
	SETGATE(idt[10], 1, GD_KT, invalidTSS_handler, 0);
f0103b08:	b8 d8 40 10 f0       	mov    $0xf01040d8,%eax
f0103b0d:	66 a3 70 e3 17 f0    	mov    %ax,0xf017e370
f0103b13:	66 c7 05 72 e3 17 f0 	movw   $0x8,0xf017e372
f0103b1a:	08 00 
f0103b1c:	c6 05 74 e3 17 f0 00 	movb   $0x0,0xf017e374
f0103b23:	c6 05 75 e3 17 f0 8f 	movb   $0x8f,0xf017e375
f0103b2a:	c1 e8 10             	shr    $0x10,%eax
f0103b2d:	66 a3 76 e3 17 f0    	mov    %ax,0xf017e376

	SETGATE(idt[11], 1, GD_KT, sgmtnotpresent_handler, 0);
f0103b33:	b8 dc 40 10 f0       	mov    $0xf01040dc,%eax
f0103b38:	66 a3 78 e3 17 f0    	mov    %ax,0xf017e378
f0103b3e:	66 c7 05 7a e3 17 f0 	movw   $0x8,0xf017e37a
f0103b45:	08 00 
f0103b47:	c6 05 7c e3 17 f0 00 	movb   $0x0,0xf017e37c
f0103b4e:	c6 05 7d e3 17 f0 8f 	movb   $0x8f,0xf017e37d
f0103b55:	c1 e8 10             	shr    $0x10,%eax
f0103b58:	66 a3 7e e3 17 f0    	mov    %ax,0xf017e37e
	SETGATE(idt[12], 1, GD_KT, stacksgmtfault_handler, 0);
f0103b5e:	b8 e0 40 10 f0       	mov    $0xf01040e0,%eax
f0103b63:	66 a3 80 e3 17 f0    	mov    %ax,0xf017e380
f0103b69:	66 c7 05 82 e3 17 f0 	movw   $0x8,0xf017e382
f0103b70:	08 00 
f0103b72:	c6 05 84 e3 17 f0 00 	movb   $0x0,0xf017e384
f0103b79:	c6 05 85 e3 17 f0 8f 	movb   $0x8f,0xf017e385
f0103b80:	c1 e8 10             	shr    $0x10,%eax
f0103b83:	66 a3 86 e3 17 f0    	mov    %ax,0xf017e386
	SETGATE(idt[14], 1, GD_KT, pagefault_handler, 0);
f0103b89:	b8 e8 40 10 f0       	mov    $0xf01040e8,%eax
f0103b8e:	66 a3 90 e3 17 f0    	mov    %ax,0xf017e390
f0103b94:	66 c7 05 92 e3 17 f0 	movw   $0x8,0xf017e392
f0103b9b:	08 00 
f0103b9d:	c6 05 94 e3 17 f0 00 	movb   $0x0,0xf017e394
f0103ba4:	c6 05 95 e3 17 f0 8f 	movb   $0x8f,0xf017e395
f0103bab:	c1 e8 10             	shr    $0x10,%eax
f0103bae:	66 a3 96 e3 17 f0    	mov    %ax,0xf017e396
	SETGATE(idt[13], 1, GD_KT, generalprotection_handler, 0);
f0103bb4:	b8 e4 40 10 f0       	mov    $0xf01040e4,%eax
f0103bb9:	66 a3 88 e3 17 f0    	mov    %ax,0xf017e388
f0103bbf:	66 c7 05 8a e3 17 f0 	movw   $0x8,0xf017e38a
f0103bc6:	08 00 
f0103bc8:	c6 05 8c e3 17 f0 00 	movb   $0x0,0xf017e38c
f0103bcf:	c6 05 8d e3 17 f0 8f 	movb   $0x8f,0xf017e38d
f0103bd6:	c1 e8 10             	shr    $0x10,%eax
f0103bd9:	66 a3 8e e3 17 f0    	mov    %ax,0xf017e38e
	SETGATE(idt[16], 1, GD_KT, FPUerror_handler, 0);
f0103bdf:	b8 ec 40 10 f0       	mov    $0xf01040ec,%eax
f0103be4:	66 a3 a0 e3 17 f0    	mov    %ax,0xf017e3a0
f0103bea:	66 c7 05 a2 e3 17 f0 	movw   $0x8,0xf017e3a2
f0103bf1:	08 00 
f0103bf3:	c6 05 a4 e3 17 f0 00 	movb   $0x0,0xf017e3a4
f0103bfa:	c6 05 a5 e3 17 f0 8f 	movb   $0x8f,0xf017e3a5
f0103c01:	c1 e8 10             	shr    $0x10,%eax
f0103c04:	66 a3 a6 e3 17 f0    	mov    %ax,0xf017e3a6
	SETGATE(idt[17], 1, GD_KT, alignmentcheck_handler, 0);
f0103c0a:	b8 f2 40 10 f0       	mov    $0xf01040f2,%eax
f0103c0f:	66 a3 a8 e3 17 f0    	mov    %ax,0xf017e3a8
f0103c15:	66 c7 05 aa e3 17 f0 	movw   $0x8,0xf017e3aa
f0103c1c:	08 00 
f0103c1e:	c6 05 ac e3 17 f0 00 	movb   $0x0,0xf017e3ac
f0103c25:	c6 05 ad e3 17 f0 8f 	movb   $0x8f,0xf017e3ad
f0103c2c:	c1 e8 10             	shr    $0x10,%eax
f0103c2f:	66 a3 ae e3 17 f0    	mov    %ax,0xf017e3ae
	SETGATE(idt[18],1, GD_KT, machinecheck_handler, 0);
f0103c35:	b8 f6 40 10 f0       	mov    $0xf01040f6,%eax
f0103c3a:	66 a3 b0 e3 17 f0    	mov    %ax,0xf017e3b0
f0103c40:	66 c7 05 b2 e3 17 f0 	movw   $0x8,0xf017e3b2
f0103c47:	08 00 
f0103c49:	c6 05 b4 e3 17 f0 00 	movb   $0x0,0xf017e3b4
f0103c50:	c6 05 b5 e3 17 f0 8f 	movb   $0x8f,0xf017e3b5
f0103c57:	c1 e8 10             	shr    $0x10,%eax
f0103c5a:	66 a3 b6 e3 17 f0    	mov    %ax,0xf017e3b6
	SETGATE(idt[19], 1, GD_KT, SIMDFPexception_handler, 0);
f0103c60:	b8 fc 40 10 f0       	mov    $0xf01040fc,%eax
f0103c65:	66 a3 b8 e3 17 f0    	mov    %ax,0xf017e3b8
f0103c6b:	66 c7 05 ba e3 17 f0 	movw   $0x8,0xf017e3ba
f0103c72:	08 00 
f0103c74:	c6 05 bc e3 17 f0 00 	movb   $0x0,0xf017e3bc
f0103c7b:	c6 05 bd e3 17 f0 8f 	movb   $0x8f,0xf017e3bd
f0103c82:	c1 e8 10             	shr    $0x10,%eax
f0103c85:	66 a3 be e3 17 f0    	mov    %ax,0xf017e3be
	SETGATE(idt[48], 0, GD_KT, systemcall_handler, 3);
f0103c8b:	b8 02 41 10 f0       	mov    $0xf0104102,%eax
f0103c90:	66 a3 a0 e4 17 f0    	mov    %ax,0xf017e4a0
f0103c96:	66 c7 05 a2 e4 17 f0 	movw   $0x8,0xf017e4a2
f0103c9d:	08 00 
f0103c9f:	c6 05 a4 e4 17 f0 00 	movb   $0x0,0xf017e4a4
f0103ca6:	c6 05 a5 e4 17 f0 ee 	movb   $0xee,0xf017e4a5
f0103cad:	c1 e8 10             	shr    $0x10,%eax
f0103cb0:	66 a3 a6 e4 17 f0    	mov    %ax,0xf017e4a6
	// LAB 3: Your code here.

	// Per-CPU setup 
	trap_init_percpu();
f0103cb6:	e8 95 fc ff ff       	call   f0103950 <trap_init_percpu>
}
f0103cbb:	5d                   	pop    %ebp
f0103cbc:	c3                   	ret    

f0103cbd <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f0103cbd:	55                   	push   %ebp
f0103cbe:	89 e5                	mov    %esp,%ebp
f0103cc0:	53                   	push   %ebx
f0103cc1:	83 ec 14             	sub    $0x14,%esp
f0103cc4:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f0103cc7:	8b 03                	mov    (%ebx),%eax
f0103cc9:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103ccd:	c7 04 24 3b 64 10 f0 	movl   $0xf010643b,(%esp)
f0103cd4:	e8 5c fc ff ff       	call   f0103935 <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f0103cd9:	8b 43 04             	mov    0x4(%ebx),%eax
f0103cdc:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103ce0:	c7 04 24 4a 64 10 f0 	movl   $0xf010644a,(%esp)
f0103ce7:	e8 49 fc ff ff       	call   f0103935 <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f0103cec:	8b 43 08             	mov    0x8(%ebx),%eax
f0103cef:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103cf3:	c7 04 24 59 64 10 f0 	movl   $0xf0106459,(%esp)
f0103cfa:	e8 36 fc ff ff       	call   f0103935 <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f0103cff:	8b 43 0c             	mov    0xc(%ebx),%eax
f0103d02:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d06:	c7 04 24 68 64 10 f0 	movl   $0xf0106468,(%esp)
f0103d0d:	e8 23 fc ff ff       	call   f0103935 <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f0103d12:	8b 43 10             	mov    0x10(%ebx),%eax
f0103d15:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d19:	c7 04 24 77 64 10 f0 	movl   $0xf0106477,(%esp)
f0103d20:	e8 10 fc ff ff       	call   f0103935 <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0103d25:	8b 43 14             	mov    0x14(%ebx),%eax
f0103d28:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d2c:	c7 04 24 86 64 10 f0 	movl   $0xf0106486,(%esp)
f0103d33:	e8 fd fb ff ff       	call   f0103935 <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f0103d38:	8b 43 18             	mov    0x18(%ebx),%eax
f0103d3b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d3f:	c7 04 24 95 64 10 f0 	movl   $0xf0106495,(%esp)
f0103d46:	e8 ea fb ff ff       	call   f0103935 <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f0103d4b:	8b 43 1c             	mov    0x1c(%ebx),%eax
f0103d4e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d52:	c7 04 24 a4 64 10 f0 	movl   $0xf01064a4,(%esp)
f0103d59:	e8 d7 fb ff ff       	call   f0103935 <cprintf>
}
f0103d5e:	83 c4 14             	add    $0x14,%esp
f0103d61:	5b                   	pop    %ebx
f0103d62:	5d                   	pop    %ebp
f0103d63:	c3                   	ret    

f0103d64 <print_trapframe>:
	lidt(&idt_pd);
}

void
print_trapframe(struct Trapframe *tf)
{
f0103d64:	55                   	push   %ebp
f0103d65:	89 e5                	mov    %esp,%ebp
f0103d67:	56                   	push   %esi
f0103d68:	53                   	push   %ebx
f0103d69:	83 ec 10             	sub    $0x10,%esp
f0103d6c:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p\n", tf);
f0103d6f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103d73:	c7 04 24 f4 65 10 f0 	movl   $0xf01065f4,(%esp)
f0103d7a:	e8 b6 fb ff ff       	call   f0103935 <cprintf>
	print_regs(&tf->tf_regs);
f0103d7f:	89 1c 24             	mov    %ebx,(%esp)
f0103d82:	e8 36 ff ff ff       	call   f0103cbd <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f0103d87:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f0103d8b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d8f:	c7 04 24 f5 64 10 f0 	movl   $0xf01064f5,(%esp)
f0103d96:	e8 9a fb ff ff       	call   f0103935 <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f0103d9b:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f0103d9f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103da3:	c7 04 24 08 65 10 f0 	movl   $0xf0106508,(%esp)
f0103daa:	e8 86 fb ff ff       	call   f0103935 <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0103daf:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f0103db2:	83 f8 13             	cmp    $0x13,%eax
f0103db5:	77 09                	ja     f0103dc0 <print_trapframe+0x5c>
		return excnames[trapno];
f0103db7:	8b 14 85 c0 67 10 f0 	mov    -0xfef9840(,%eax,4),%edx
f0103dbe:	eb 10                	jmp    f0103dd0 <print_trapframe+0x6c>
	if (trapno == T_SYSCALL)
		return "System call";
f0103dc0:	83 f8 30             	cmp    $0x30,%eax
f0103dc3:	ba b3 64 10 f0       	mov    $0xf01064b3,%edx
f0103dc8:	b9 bf 64 10 f0       	mov    $0xf01064bf,%ecx
f0103dcd:	0f 45 d1             	cmovne %ecx,%edx
{
	cprintf("TRAP frame at %p\n", tf);
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0103dd0:	89 54 24 08          	mov    %edx,0x8(%esp)
f0103dd4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103dd8:	c7 04 24 1b 65 10 f0 	movl   $0xf010651b,(%esp)
f0103ddf:	e8 51 fb ff ff       	call   f0103935 <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f0103de4:	3b 1d 20 eb 17 f0    	cmp    0xf017eb20,%ebx
f0103dea:	75 19                	jne    f0103e05 <print_trapframe+0xa1>
f0103dec:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0103df0:	75 13                	jne    f0103e05 <print_trapframe+0xa1>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f0103df2:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f0103df5:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103df9:	c7 04 24 2d 65 10 f0 	movl   $0xf010652d,(%esp)
f0103e00:	e8 30 fb ff ff       	call   f0103935 <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f0103e05:	8b 43 2c             	mov    0x2c(%ebx),%eax
f0103e08:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e0c:	c7 04 24 3c 65 10 f0 	movl   $0xf010653c,(%esp)
f0103e13:	e8 1d fb ff ff       	call   f0103935 <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f0103e18:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0103e1c:	75 51                	jne    f0103e6f <print_trapframe+0x10b>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f0103e1e:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f0103e21:	89 c2                	mov    %eax,%edx
f0103e23:	83 e2 01             	and    $0x1,%edx
f0103e26:	ba ce 64 10 f0       	mov    $0xf01064ce,%edx
f0103e2b:	b9 d9 64 10 f0       	mov    $0xf01064d9,%ecx
f0103e30:	0f 45 ca             	cmovne %edx,%ecx
f0103e33:	89 c2                	mov    %eax,%edx
f0103e35:	83 e2 02             	and    $0x2,%edx
f0103e38:	ba e5 64 10 f0       	mov    $0xf01064e5,%edx
f0103e3d:	be eb 64 10 f0       	mov    $0xf01064eb,%esi
f0103e42:	0f 44 d6             	cmove  %esi,%edx
f0103e45:	83 e0 04             	and    $0x4,%eax
f0103e48:	b8 f0 64 10 f0       	mov    $0xf01064f0,%eax
f0103e4d:	be 1f 66 10 f0       	mov    $0xf010661f,%esi
f0103e52:	0f 44 c6             	cmove  %esi,%eax
f0103e55:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0103e59:	89 54 24 08          	mov    %edx,0x8(%esp)
f0103e5d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e61:	c7 04 24 4a 65 10 f0 	movl   $0xf010654a,(%esp)
f0103e68:	e8 c8 fa ff ff       	call   f0103935 <cprintf>
f0103e6d:	eb 0c                	jmp    f0103e7b <print_trapframe+0x117>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f0103e6f:	c7 04 24 31 63 10 f0 	movl   $0xf0106331,(%esp)
f0103e76:	e8 ba fa ff ff       	call   f0103935 <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f0103e7b:	8b 43 30             	mov    0x30(%ebx),%eax
f0103e7e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e82:	c7 04 24 59 65 10 f0 	movl   $0xf0106559,(%esp)
f0103e89:	e8 a7 fa ff ff       	call   f0103935 <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f0103e8e:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f0103e92:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103e96:	c7 04 24 68 65 10 f0 	movl   $0xf0106568,(%esp)
f0103e9d:	e8 93 fa ff ff       	call   f0103935 <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f0103ea2:	8b 43 38             	mov    0x38(%ebx),%eax
f0103ea5:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103ea9:	c7 04 24 7b 65 10 f0 	movl   $0xf010657b,(%esp)
f0103eb0:	e8 80 fa ff ff       	call   f0103935 <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f0103eb5:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f0103eb9:	74 27                	je     f0103ee2 <print_trapframe+0x17e>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f0103ebb:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0103ebe:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103ec2:	c7 04 24 8a 65 10 f0 	movl   $0xf010658a,(%esp)
f0103ec9:	e8 67 fa ff ff       	call   f0103935 <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f0103ece:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f0103ed2:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103ed6:	c7 04 24 99 65 10 f0 	movl   $0xf0106599,(%esp)
f0103edd:	e8 53 fa ff ff       	call   f0103935 <cprintf>
	}
}
f0103ee2:	83 c4 10             	add    $0x10,%esp
f0103ee5:	5b                   	pop    %ebx
f0103ee6:	5e                   	pop    %esi
f0103ee7:	5d                   	pop    %ebp
f0103ee8:	c3                   	ret    

f0103ee9 <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f0103ee9:	55                   	push   %ebp
f0103eea:	89 e5                	mov    %esp,%ebp
f0103eec:	83 ec 18             	sub    $0x18,%esp
f0103eef:	8b 45 08             	mov    0x8(%ebp),%eax
f0103ef2:	0f 20 d2             	mov    %cr2,%edx
	uint32_t fault_va;

	// Read processor's CR2 register to find the faulting address
	fault_va = rcr2();
	if((tf->tf_cs & 3)==0) // last three bits 000 means DPL_Kern
f0103ef5:	f6 40 34 03          	testb  $0x3,0x34(%eax)
f0103ef9:	75 1c                	jne    f0103f17 <page_fault_handler+0x2e>
	{
		panic("kernel mode page faults!!");
f0103efb:	c7 44 24 08 ac 65 10 	movl   $0xf01065ac,0x8(%esp)
f0103f02:	f0 
f0103f03:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
f0103f0a:	00 
f0103f0b:	c7 04 24 c6 65 10 f0 	movl   $0xf01065c6,(%esp)
f0103f12:	e8 a7 c1 ff ff       	call   f01000be <_panic>

	// We've already handled kernel-mode exceptions, so if we get here,
	// the page fault happened in user mode.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0103f17:	8b 40 30             	mov    0x30(%eax),%eax
f0103f1a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103f1e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0103f22:	a1 08 e3 17 f0       	mov    0xf017e308,%eax
f0103f27:	8b 40 48             	mov    0x48(%eax),%eax
f0103f2a:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103f2e:	c7 04 24 6c 67 10 f0 	movl   $0xf010676c,(%esp)
f0103f35:	e8 fb f9 ff ff       	call   f0103935 <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
	//print_trapframe(tf);
	env_destroy(curenv);
f0103f3a:	a1 08 e3 17 f0       	mov    0xf017e308,%eax
f0103f3f:	89 04 24             	mov    %eax,(%esp)
f0103f42:	e8 bb f8 ff ff       	call   f0103802 <env_destroy>
f0103f47:	c9                   	leave  
f0103f48:	c3                   	ret    

f0103f49 <trap>:



void
trap(struct Trapframe *tf)
{
f0103f49:	55                   	push   %ebp
f0103f4a:	89 e5                	mov    %esp,%ebp
f0103f4c:	57                   	push   %edi
f0103f4d:	56                   	push   %esi
f0103f4e:	83 ec 20             	sub    $0x20,%esp
f0103f51:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f0103f54:	fc                   	cld    

static __inline uint32_t
read_eflags(void)
{
        uint32_t eflags;
        __asm __volatile("pushfl; popl %0" : "=r" (eflags));
f0103f55:	9c                   	pushf  
f0103f56:	58                   	pop    %eax

	// Check that interrupts are disabled.  If this assertion
	// fails, DO NOT be tempted to fix it by inserting a "cli" in
	// the interrupt path.
	assert(!(read_eflags() & FL_IF));
f0103f57:	f6 c4 02             	test   $0x2,%ah
f0103f5a:	74 24                	je     f0103f80 <trap+0x37>
f0103f5c:	c7 44 24 0c d2 65 10 	movl   $0xf01065d2,0xc(%esp)
f0103f63:	f0 
f0103f64:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0103f6b:	f0 
f0103f6c:	c7 44 24 04 da 00 00 	movl   $0xda,0x4(%esp)
f0103f73:	00 
f0103f74:	c7 04 24 c6 65 10 f0 	movl   $0xf01065c6,(%esp)
f0103f7b:	e8 3e c1 ff ff       	call   f01000be <_panic>
   // panic("trap called!");
	cprintf("Incoming TRAP frame at %p\n", tf);
f0103f80:	89 74 24 04          	mov    %esi,0x4(%esp)
f0103f84:	c7 04 24 eb 65 10 f0 	movl   $0xf01065eb,(%esp)
f0103f8b:	e8 a5 f9 ff ff       	call   f0103935 <cprintf>

	if ((tf->tf_cs & 3) == 3) {
f0103f90:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f0103f94:	83 e0 03             	and    $0x3,%eax
f0103f97:	66 83 f8 03          	cmp    $0x3,%ax
f0103f9b:	75 3c                	jne    f0103fd9 <trap+0x90>
		// Trapped from user mode.
		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		assert(curenv);
f0103f9d:	a1 08 e3 17 f0       	mov    0xf017e308,%eax
f0103fa2:	85 c0                	test   %eax,%eax
f0103fa4:	75 24                	jne    f0103fca <trap+0x81>
f0103fa6:	c7 44 24 0c 06 66 10 	movl   $0xf0106606,0xc(%esp)
f0103fad:	f0 
f0103fae:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f0103fb5:	f0 
f0103fb6:	c7 44 24 04 e3 00 00 	movl   $0xe3,0x4(%esp)
f0103fbd:	00 
f0103fbe:	c7 04 24 c6 65 10 f0 	movl   $0xf01065c6,(%esp)
f0103fc5:	e8 f4 c0 ff ff       	call   f01000be <_panic>
		curenv->env_tf = *tf;
f0103fca:	b9 11 00 00 00       	mov    $0x11,%ecx
f0103fcf:	89 c7                	mov    %eax,%edi
f0103fd1:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f0103fd3:	8b 35 08 e3 17 f0    	mov    0xf017e308,%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f0103fd9:	89 35 20 eb 17 f0    	mov    %esi,0xf017eb20
}
static void
trap_dispatch(struct Trapframe *tf)
{
	// Handle processor exceptions.
	print_trapframe(tf);
f0103fdf:	89 34 24             	mov    %esi,(%esp)
f0103fe2:	e8 7d fd ff ff       	call   f0103d64 <print_trapframe>
	// LAB 3: Your code here.
	if(tf->tf_trapno==T_PGFLT)
f0103fe7:	8b 46 28             	mov    0x28(%esi),%eax
f0103fea:	83 f8 0e             	cmp    $0xe,%eax
f0103fed:	75 0a                	jne    f0103ff9 <trap+0xb0>
	{
		page_fault_handler(tf);
f0103fef:	89 34 24             	mov    %esi,(%esp)
f0103ff2:	e8 f2 fe ff ff       	call   f0103ee9 <page_fault_handler>
f0103ff7:	eb 76                	jmp    f010406f <trap+0x126>
		return;
	}
	if(tf->tf_trapno==T_BRKPT)
f0103ff9:	83 f8 03             	cmp    $0x3,%eax
f0103ffc:	75 0a                	jne    f0104008 <trap+0xbf>
	{
		monitor(tf);
f0103ffe:	89 34 24             	mov    %esi,(%esp)
f0104001:	e8 2c c8 ff ff       	call   f0100832 <monitor>
f0104006:	eb 67                	jmp    f010406f <trap+0x126>
		return;
	}
	if(tf->tf_trapno==T_SYSCALL)
f0104008:	83 f8 30             	cmp    $0x30,%eax
f010400b:	75 32                	jne    f010403f <trap+0xf6>
	{
		tf->tf_regs.reg_eax=syscall(tf->tf_regs.reg_eax,tf->tf_regs.reg_edx,tf->tf_regs.reg_ecx,tf->tf_regs.reg_ebx,tf->tf_regs.reg_edi,tf->tf_regs.reg_esi);
f010400d:	8b 46 04             	mov    0x4(%esi),%eax
f0104010:	89 44 24 14          	mov    %eax,0x14(%esp)
f0104014:	8b 06                	mov    (%esi),%eax
f0104016:	89 44 24 10          	mov    %eax,0x10(%esp)
f010401a:	8b 46 10             	mov    0x10(%esi),%eax
f010401d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104021:	8b 46 18             	mov    0x18(%esi),%eax
f0104024:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104028:	8b 46 14             	mov    0x14(%esi),%eax
f010402b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010402f:	8b 46 1c             	mov    0x1c(%esi),%eax
f0104032:	89 04 24             	mov    %eax,(%esp)
f0104035:	e8 f6 00 00 00       	call   f0104130 <syscall>
f010403a:	89 46 1c             	mov    %eax,0x1c(%esi)
f010403d:	eb 30                	jmp    f010406f <trap+0x126>
	    return;
	}
	// Unexpected trap: The user process or the kernel has a bug.

	if (tf->tf_cs == GD_KT)
f010403f:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f0104044:	75 1c                	jne    f0104062 <trap+0x119>
		panic("unhandled trap in kernel");
f0104046:	c7 44 24 08 0d 66 10 	movl   $0xf010660d,0x8(%esp)
f010404d:	f0 
f010404e:	c7 44 24 04 c7 00 00 	movl   $0xc7,0x4(%esp)
f0104055:	00 
f0104056:	c7 04 24 c6 65 10 f0 	movl   $0xf01065c6,(%esp)
f010405d:	e8 5c c0 ff ff       	call   f01000be <_panic>
	else {
		env_destroy(curenv);
f0104062:	a1 08 e3 17 f0       	mov    0xf017e308,%eax
f0104067:	89 04 24             	mov    %eax,(%esp)
f010406a:	e8 93 f7 ff ff       	call   f0103802 <env_destroy>

	// Dispatch based on what type of trap occurred
	trap_dispatch(tf);

	// Return to the current environment, which should be running.
	assert(curenv && curenv->env_status == ENV_RUNNING);
f010406f:	a1 08 e3 17 f0       	mov    0xf017e308,%eax
f0104074:	85 c0                	test   %eax,%eax
f0104076:	74 06                	je     f010407e <trap+0x135>
f0104078:	83 78 54 02          	cmpl   $0x2,0x54(%eax)
f010407c:	74 24                	je     f01040a2 <trap+0x159>
f010407e:	c7 44 24 0c 90 67 10 	movl   $0xf0106790,0xc(%esp)
f0104085:	f0 
f0104086:	c7 44 24 08 c7 60 10 	movl   $0xf01060c7,0x8(%esp)
f010408d:	f0 
f010408e:	c7 44 24 04 f1 00 00 	movl   $0xf1,0x4(%esp)
f0104095:	00 
f0104096:	c7 04 24 c6 65 10 f0 	movl   $0xf01065c6,(%esp)
f010409d:	e8 1c c0 ff ff       	call   f01000be <_panic>
	env_run(curenv);
f01040a2:	89 04 24             	mov    %eax,(%esp)
f01040a5:	e8 af f7 ff ff       	call   f0103859 <env_run>

f01040aa <dividezero_handler>:
.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
f01040aa:	6a 00                	push   $0x0
f01040ac:	6a 00                	push   $0x0
f01040ae:	eb 58                	jmp    f0104108 <_alltraps>

f01040b0 <nmi_handler>:
TRAPHANDLER_NOEC(nmi_handler, 0x2)
f01040b0:	6a 00                	push   $0x0
f01040b2:	6a 02                	push   $0x2
f01040b4:	eb 52                	jmp    f0104108 <_alltraps>

f01040b6 <breakpoint_handler>:
TRAPHANDLER_NOEC(breakpoint_handler, 0x3)
f01040b6:	6a 00                	push   $0x0
f01040b8:	6a 03                	push   $0x3
f01040ba:	eb 4c                	jmp    f0104108 <_alltraps>

f01040bc <overflow_handler>:
TRAPHANDLER_NOEC(overflow_handler, 0x4)
f01040bc:	6a 00                	push   $0x0
f01040be:	6a 04                	push   $0x4
f01040c0:	eb 46                	jmp    f0104108 <_alltraps>

f01040c2 <bdrgeexceed_handler>:
TRAPHANDLER_NOEC(bdrgeexceed_handler, 0x5)
f01040c2:	6a 00                	push   $0x0
f01040c4:	6a 05                	push   $0x5
f01040c6:	eb 40                	jmp    f0104108 <_alltraps>

f01040c8 <invalidop_handler>:
TRAPHANDLER_NOEC(invalidop_handler, 0x6)
f01040c8:	6a 00                	push   $0x0
f01040ca:	6a 06                	push   $0x6
f01040cc:	eb 3a                	jmp    f0104108 <_alltraps>

f01040ce <nomathcopro_handler>:
TRAPHANDLER_NOEC(nomathcopro_handler, 0x7)
f01040ce:	6a 00                	push   $0x0
f01040d0:	6a 07                	push   $0x7
f01040d2:	eb 34                	jmp    f0104108 <_alltraps>

f01040d4 <dbfault_handler>:
TRAPHANDLER(dbfault_handler, 0x8)
f01040d4:	6a 08                	push   $0x8
f01040d6:	eb 30                	jmp    f0104108 <_alltraps>

f01040d8 <invalidTSS_handler>:
TRAPHANDLER(invalidTSS_handler, 0xA)
f01040d8:	6a 0a                	push   $0xa
f01040da:	eb 2c                	jmp    f0104108 <_alltraps>

f01040dc <sgmtnotpresent_handler>:
TRAPHANDLER(sgmtnotpresent_handler, 0xB)
f01040dc:	6a 0b                	push   $0xb
f01040de:	eb 28                	jmp    f0104108 <_alltraps>

f01040e0 <stacksgmtfault_handler>:
TRAPHANDLER(stacksgmtfault_handler,0xC)
f01040e0:	6a 0c                	push   $0xc
f01040e2:	eb 24                	jmp    f0104108 <_alltraps>

f01040e4 <generalprotection_handler>:
TRAPHANDLER(generalprotection_handler, 0xD)
f01040e4:	6a 0d                	push   $0xd
f01040e6:	eb 20                	jmp    f0104108 <_alltraps>

f01040e8 <pagefault_handler>:
TRAPHANDLER(pagefault_handler, 0xE)
f01040e8:	6a 0e                	push   $0xe
f01040ea:	eb 1c                	jmp    f0104108 <_alltraps>

f01040ec <FPUerror_handler>:
TRAPHANDLER_NOEC(FPUerror_handler, 0x10)
f01040ec:	6a 00                	push   $0x0
f01040ee:	6a 10                	push   $0x10
f01040f0:	eb 16                	jmp    f0104108 <_alltraps>

f01040f2 <alignmentcheck_handler>:
TRAPHANDLER(alignmentcheck_handler, 0x11)
f01040f2:	6a 11                	push   $0x11
f01040f4:	eb 12                	jmp    f0104108 <_alltraps>

f01040f6 <machinecheck_handler>:
TRAPHANDLER_NOEC(machinecheck_handler, 0x12)
f01040f6:	6a 00                	push   $0x0
f01040f8:	6a 12                	push   $0x12
f01040fa:	eb 0c                	jmp    f0104108 <_alltraps>

f01040fc <SIMDFPexception_handler>:
TRAPHANDLER_NOEC(SIMDFPexception_handler, 0x13)
f01040fc:	6a 00                	push   $0x0
f01040fe:	6a 13                	push   $0x13
f0104100:	eb 06                	jmp    f0104108 <_alltraps>

f0104102 <systemcall_handler>:
TRAPHANDLER_NOEC(systemcall_handler, 0x30)
f0104102:	6a 00                	push   $0x0
f0104104:	6a 30                	push   $0x30
f0104106:	eb 00                	jmp    f0104108 <_alltraps>

f0104108 <_alltraps>:
/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
	pushw $0
f0104108:	66 6a 00             	pushw  $0x0
	pushw %ds
f010410b:	66 1e                	pushw  %ds
	pushw $0
f010410d:	66 6a 00             	pushw  $0x0
	pushw %es
f0104110:	66 06                	pushw  %es
	pushal
f0104112:	60                   	pusha  
	pushl %esp
f0104113:	54                   	push   %esp
	movw $(GD_KD),%ax
f0104114:	66 b8 10 00          	mov    $0x10,%ax
	movw %ax,%ds
f0104118:	8e d8                	mov    %eax,%ds
	movw %ax,%es
f010411a:	8e c0                	mov    %eax,%es
f010411c:	e8 28 fe ff ff       	call   f0103f49 <trap>
f0104121:	66 90                	xchg   %ax,%ax
f0104123:	66 90                	xchg   %ax,%ax
f0104125:	66 90                	xchg   %ax,%ax
f0104127:	66 90                	xchg   %ax,%ax
f0104129:	66 90                	xchg   %ax,%ax
f010412b:	66 90                	xchg   %ax,%ax
f010412d:	66 90                	xchg   %ax,%ax
f010412f:	90                   	nop

f0104130 <syscall>:
}

// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
f0104130:	55                   	push   %ebp
f0104131:	89 e5                	mov    %esp,%ebp
f0104133:	83 ec 28             	sub    $0x28,%esp
f0104136:	8b 45 08             	mov    0x8(%ebp),%eax
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
	switch(syscallno){
f0104139:	83 f8 01             	cmp    $0x1,%eax
f010413c:	74 5e                	je     f010419c <syscall+0x6c>
f010413e:	83 f8 01             	cmp    $0x1,%eax
f0104141:	72 12                	jb     f0104155 <syscall+0x25>
f0104143:	83 f8 02             	cmp    $0x2,%eax
f0104146:	74 5b                	je     f01041a3 <syscall+0x73>
f0104148:	83 f8 03             	cmp    $0x3,%eax
f010414b:	74 60                	je     f01041ad <syscall+0x7d>
f010414d:	8d 76 00             	lea    0x0(%esi),%esi
f0104150:	e9 c4 00 00 00       	jmp    f0104219 <syscall+0xe9>
static void
sys_cputs(const char *s, size_t len)
{
	// Check that the user has permission to read memory [s, s+len).
	// Destroy the environment if not.
	user_mem_assert(curenv,s,len,0);
f0104155:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f010415c:	00 
f010415d:	8b 45 10             	mov    0x10(%ebp),%eax
f0104160:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104164:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104167:	89 44 24 04          	mov    %eax,0x4(%esp)
f010416b:	a1 08 e3 17 f0       	mov    0xf017e308,%eax
f0104170:	89 04 24             	mov    %eax,(%esp)
f0104173:	e8 a7 ef ff ff       	call   f010311f <user_mem_assert>
	// LAB 3: Your code here.
	// Print the string supplied by the user.
	cprintf("%.*s", len, s);
f0104178:	8b 45 0c             	mov    0xc(%ebp),%eax
f010417b:	89 44 24 08          	mov    %eax,0x8(%esp)
f010417f:	8b 45 10             	mov    0x10(%ebp),%eax
f0104182:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104186:	c7 04 24 10 68 10 f0 	movl   $0xf0106810,(%esp)
f010418d:	e8 a3 f7 ff ff       	call   f0103935 <cprintf>
	// Return any appropriate return value.
	// LAB 3: Your code here.
	switch(syscallno){
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
f0104192:	b8 00 00 00 00       	mov    $0x0,%eax
f0104197:	e9 82 00 00 00       	jmp    f010421e <syscall+0xee>
// Read a character from the system console without blocking.
// Returns the character, or 0 if there is no input waiting.
static int
sys_cgetc(void)
{
	return cons_getc();
f010419c:	e8 54 c3 ff ff       	call   f01004f5 <cons_getc>
	switch(syscallno){
		case(SYS_cputs):
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case(SYS_cgetc):
			return sys_cgetc();
f01041a1:	eb 7b                	jmp    f010421e <syscall+0xee>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f01041a3:	a1 08 e3 17 f0       	mov    0xf017e308,%eax
f01041a8:	8b 40 48             	mov    0x48(%eax),%eax
			sys_cputs((const char*)a1,(size_t)a2);
			return 0;
		case(SYS_cgetc):
			return sys_cgetc();
		case(SYS_getenvid):
			return sys_getenvid();
f01041ab:	eb 71                	jmp    f010421e <syscall+0xee>
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f01041ad:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01041b4:	00 
f01041b5:	8d 45 f4             	lea    -0xc(%ebp),%eax
f01041b8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01041bc:	8b 45 0c             	mov    0xc(%ebp),%eax
f01041bf:	89 04 24             	mov    %eax,(%esp)
f01041c2:	e8 b0 ef ff ff       	call   f0103177 <envid2env>
f01041c7:	85 c0                	test   %eax,%eax
f01041c9:	78 53                	js     f010421e <syscall+0xee>
		return r;
	if (e == curenv)
f01041cb:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01041ce:	8b 15 08 e3 17 f0    	mov    0xf017e308,%edx
f01041d4:	39 d0                	cmp    %edx,%eax
f01041d6:	75 15                	jne    f01041ed <syscall+0xbd>
		cprintf("[%08x] exiting gracefully\n", curenv->env_id);
f01041d8:	8b 40 48             	mov    0x48(%eax),%eax
f01041db:	89 44 24 04          	mov    %eax,0x4(%esp)
f01041df:	c7 04 24 15 68 10 f0 	movl   $0xf0106815,(%esp)
f01041e6:	e8 4a f7 ff ff       	call   f0103935 <cprintf>
f01041eb:	eb 1a                	jmp    f0104207 <syscall+0xd7>
	else
		cprintf("[%08x] destroying %08x\n", curenv->env_id, e->env_id);
f01041ed:	8b 40 48             	mov    0x48(%eax),%eax
f01041f0:	89 44 24 08          	mov    %eax,0x8(%esp)
f01041f4:	8b 42 48             	mov    0x48(%edx),%eax
f01041f7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01041fb:	c7 04 24 30 68 10 f0 	movl   $0xf0106830,(%esp)
f0104202:	e8 2e f7 ff ff       	call   f0103935 <cprintf>
	env_destroy(e);
f0104207:	8b 45 f4             	mov    -0xc(%ebp),%eax
f010420a:	89 04 24             	mov    %eax,(%esp)
f010420d:	e8 f0 f5 ff ff       	call   f0103802 <env_destroy>
	return 0;
f0104212:	b8 00 00 00 00       	mov    $0x0,%eax
f0104217:	eb 05                	jmp    f010421e <syscall+0xee>
		case(SYS_getenvid):
			return sys_getenvid();
		case(SYS_env_destroy):
			return sys_env_destroy((envid_t) a1);
		default:
			return -E_INVAL;
f0104219:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
	}
	//panic("syscall not implemented");
}
f010421e:	c9                   	leave  
f010421f:	c3                   	ret    

f0104220 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0104220:	55                   	push   %ebp
f0104221:	89 e5                	mov    %esp,%ebp
f0104223:	57                   	push   %edi
f0104224:	56                   	push   %esi
f0104225:	53                   	push   %ebx
f0104226:	83 ec 14             	sub    $0x14,%esp
f0104229:	89 45 ec             	mov    %eax,-0x14(%ebp)
f010422c:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f010422f:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0104232:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0104235:	8b 1a                	mov    (%edx),%ebx
f0104237:	8b 01                	mov    (%ecx),%eax
f0104239:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f010423c:	39 c3                	cmp    %eax,%ebx
f010423e:	0f 8f 9a 00 00 00    	jg     f01042de <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f0104244:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f010424b:	8b 45 f0             	mov    -0x10(%ebp),%eax
f010424e:	01 d8                	add    %ebx,%eax
f0104250:	89 c7                	mov    %eax,%edi
f0104252:	c1 ef 1f             	shr    $0x1f,%edi
f0104255:	01 c7                	add    %eax,%edi
f0104257:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0104259:	39 df                	cmp    %ebx,%edi
f010425b:	0f 8c c4 00 00 00    	jl     f0104325 <stab_binsearch+0x105>
f0104261:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0104264:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104267:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f010426a:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f010426e:	39 f0                	cmp    %esi,%eax
f0104270:	0f 84 b4 00 00 00    	je     f010432a <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104276:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f0104278:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f010427b:	39 d8                	cmp    %ebx,%eax
f010427d:	0f 8c a2 00 00 00    	jl     f0104325 <stab_binsearch+0x105>
f0104283:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f0104287:	83 ea 0c             	sub    $0xc,%edx
f010428a:	39 f1                	cmp    %esi,%ecx
f010428c:	75 ea                	jne    f0104278 <stab_binsearch+0x58>
f010428e:	e9 99 00 00 00       	jmp    f010432c <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0104293:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0104296:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f0104298:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f010429b:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01042a2:	eb 2b                	jmp    f01042cf <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f01042a4:	3b 55 0c             	cmp    0xc(%ebp),%edx
f01042a7:	76 14                	jbe    f01042bd <stab_binsearch+0x9d>
			*region_right = m - 1;
f01042a9:	83 e8 01             	sub    $0x1,%eax
f01042ac:	89 45 f0             	mov    %eax,-0x10(%ebp)
f01042af:	8b 7d e0             	mov    -0x20(%ebp),%edi
f01042b2:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01042b4:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f01042bb:	eb 12                	jmp    f01042cf <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f01042bd:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01042c0:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f01042c2:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f01042c6:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01042c8:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f01042cf:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f01042d2:	0f 8e 73 ff ff ff    	jle    f010424b <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f01042d8:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f01042dc:	75 0f                	jne    f01042ed <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f01042de:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01042e1:	8b 00                	mov    (%eax),%eax
f01042e3:	83 e8 01             	sub    $0x1,%eax
f01042e6:	8b 75 e0             	mov    -0x20(%ebp),%esi
f01042e9:	89 06                	mov    %eax,(%esi)
f01042eb:	eb 57                	jmp    f0104344 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f01042ed:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01042f0:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f01042f2:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01042f5:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f01042f7:	39 c8                	cmp    %ecx,%eax
f01042f9:	7e 23                	jle    f010431e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f01042fb:	8d 14 40             	lea    (%eax,%eax,2),%edx
f01042fe:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0104301:	8d 14 97             	lea    (%edi,%edx,4),%edx
f0104304:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f0104308:	39 f3                	cmp    %esi,%ebx
f010430a:	74 12                	je     f010431e <stab_binsearch+0xfe>
		     l--)
f010430c:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f010430f:	39 c8                	cmp    %ecx,%eax
f0104311:	7e 0b                	jle    f010431e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0104313:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f0104317:	83 ea 0c             	sub    $0xc,%edx
f010431a:	39 f3                	cmp    %esi,%ebx
f010431c:	75 ee                	jne    f010430c <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f010431e:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0104321:	89 06                	mov    %eax,(%esi)
f0104323:	eb 1f                	jmp    f0104344 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0104325:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0104328:	eb a5                	jmp    f01042cf <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f010432a:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f010432c:	8d 14 40             	lea    (%eax,%eax,2),%edx
f010432f:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104332:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0104336:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0104339:	0f 82 54 ff ff ff    	jb     f0104293 <stab_binsearch+0x73>
f010433f:	e9 60 ff ff ff       	jmp    f01042a4 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0104344:	83 c4 14             	add    $0x14,%esp
f0104347:	5b                   	pop    %ebx
f0104348:	5e                   	pop    %esi
f0104349:	5f                   	pop    %edi
f010434a:	5d                   	pop    %ebp
f010434b:	c3                   	ret    

f010434c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f010434c:	55                   	push   %ebp
f010434d:	89 e5                	mov    %esp,%ebp
f010434f:	57                   	push   %edi
f0104350:	56                   	push   %esi
f0104351:	53                   	push   %ebx
f0104352:	83 ec 3c             	sub    $0x3c,%esp
f0104355:	8b 7d 08             	mov    0x8(%ebp),%edi
f0104358:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f010435b:	c7 06 48 68 10 f0    	movl   $0xf0106848,(%esi)
	info->eip_line = 0;
f0104361:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0104368:	c7 46 08 48 68 10 f0 	movl   $0xf0106848,0x8(%esi)
	info->eip_fn_namelen = 9;
f010436f:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0104376:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0104379:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0104380:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f0104386:	0f 87 ae 00 00 00    	ja     f010443a <debuginfo_eip+0xee>
		const struct UserStabData *usd = (const struct UserStabData *) USTABDATA;

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
f010438c:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104393:	00 
f0104394:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
f010439b:	00 
f010439c:	c7 44 24 04 00 00 20 	movl   $0x200000,0x4(%esp)
f01043a3:	00 
f01043a4:	a1 08 e3 17 f0       	mov    0xf017e308,%eax
f01043a9:	89 04 24             	mov    %eax,(%esp)
f01043ac:	e8 cf ec ff ff       	call   f0103080 <user_mem_check>
f01043b1:	85 c0                	test   %eax,%eax
f01043b3:	0f 85 01 02 00 00    	jne    f01045ba <debuginfo_eip+0x26e>
			return -1;
		stabs = usd->stabs;
f01043b9:	a1 00 00 20 00       	mov    0x200000,%eax
f01043be:	89 c1                	mov    %eax,%ecx
f01043c0:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f01043c3:	8b 1d 04 00 20 00    	mov    0x200004,%ebx
		stabstr = usd->stabstr;
f01043c9:	a1 08 00 20 00       	mov    0x200008,%eax
f01043ce:	89 45 d0             	mov    %eax,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f01043d1:	8b 15 0c 00 20 00    	mov    0x20000c,%edx
f01043d7:	89 55 cc             	mov    %edx,-0x34(%ebp)

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
f01043da:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f01043e1:	00 
f01043e2:	89 d8                	mov    %ebx,%eax
f01043e4:	29 c8                	sub    %ecx,%eax
f01043e6:	c1 f8 02             	sar    $0x2,%eax
f01043e9:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
f01043ef:	89 44 24 08          	mov    %eax,0x8(%esp)
f01043f3:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01043f7:	a1 08 e3 17 f0       	mov    0xf017e308,%eax
f01043fc:	89 04 24             	mov    %eax,(%esp)
f01043ff:	e8 7c ec ff ff       	call   f0103080 <user_mem_check>
f0104404:	85 c0                	test   %eax,%eax
f0104406:	0f 85 b5 01 00 00    	jne    f01045c1 <debuginfo_eip+0x275>
f010440c:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104413:	00 
f0104414:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0104417:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f010441a:	29 ca                	sub    %ecx,%edx
f010441c:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104420:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0104424:	a1 08 e3 17 f0       	mov    0xf017e308,%eax
f0104429:	89 04 24             	mov    %eax,(%esp)
f010442c:	e8 4f ec ff ff       	call   f0103080 <user_mem_check>
f0104431:	85 c0                	test   %eax,%eax
f0104433:	74 1f                	je     f0104454 <debuginfo_eip+0x108>
f0104435:	e9 8e 01 00 00       	jmp    f01045c8 <debuginfo_eip+0x27c>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f010443a:	c7 45 cc 5b 14 11 f0 	movl   $0xf011145b,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f0104441:	c7 45 d0 c5 ea 10 f0 	movl   $0xf010eac5,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f0104448:	bb c4 ea 10 f0       	mov    $0xf010eac4,%ebx
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f010444d:	c7 45 d4 60 6a 10 f0 	movl   $0xf0106a60,-0x2c(%ebp)
		    return -1;
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0104454:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0104457:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f010445a:	0f 83 6f 01 00 00    	jae    f01045cf <debuginfo_eip+0x283>
f0104460:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f0104464:	0f 85 6c 01 00 00    	jne    f01045d6 <debuginfo_eip+0x28a>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f010446a:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0104471:	2b 5d d4             	sub    -0x2c(%ebp),%ebx
f0104474:	c1 fb 02             	sar    $0x2,%ebx
f0104477:	69 c3 ab aa aa aa    	imul   $0xaaaaaaab,%ebx,%eax
f010447d:	83 e8 01             	sub    $0x1,%eax
f0104480:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0104483:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104487:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f010448e:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0104491:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0104494:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0104497:	89 d8                	mov    %ebx,%eax
f0104499:	e8 82 fd ff ff       	call   f0104220 <stab_binsearch>
	if (lfile == 0)
f010449e:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01044a1:	85 c0                	test   %eax,%eax
f01044a3:	0f 84 34 01 00 00    	je     f01045dd <debuginfo_eip+0x291>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f01044a9:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f01044ac:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01044af:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f01044b2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01044b6:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f01044bd:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f01044c0:	8d 55 dc             	lea    -0x24(%ebp),%edx
f01044c3:	89 d8                	mov    %ebx,%eax
f01044c5:	e8 56 fd ff ff       	call   f0104220 <stab_binsearch>

	if (lfun <= rfun) {
f01044ca:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f01044cd:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f01044d0:	7f 23                	jg     f01044f5 <debuginfo_eip+0x1a9>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f01044d2:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f01044d5:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f01044d8:	8d 04 87             	lea    (%edi,%eax,4),%eax
f01044db:	8b 10                	mov    (%eax),%edx
f01044dd:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f01044e0:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f01044e3:	39 ca                	cmp    %ecx,%edx
f01044e5:	73 06                	jae    f01044ed <debuginfo_eip+0x1a1>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f01044e7:	03 55 d0             	add    -0x30(%ebp),%edx
f01044ea:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f01044ed:	8b 40 08             	mov    0x8(%eax),%eax
f01044f0:	89 46 10             	mov    %eax,0x10(%esi)
f01044f3:	eb 06                	jmp    f01044fb <debuginfo_eip+0x1af>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f01044f5:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f01044f8:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f01044fb:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0104502:	00 
f0104503:	8b 46 08             	mov    0x8(%esi),%eax
f0104506:	89 04 24             	mov    %eax,(%esp)
f0104509:	e8 91 09 00 00       	call   f0104e9f <strfind>
f010450e:	2b 46 08             	sub    0x8(%esi),%eax
f0104511:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0104514:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104517:	39 fb                	cmp    %edi,%ebx
f0104519:	7c 5f                	jl     f010457a <debuginfo_eip+0x22e>
	       && stabs[lline].n_type != N_SOL
f010451b:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f010451e:	c1 e0 02             	shl    $0x2,%eax
f0104521:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0104524:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f0104527:	89 55 c8             	mov    %edx,-0x38(%ebp)
f010452a:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f010452e:	80 fa 84             	cmp    $0x84,%dl
f0104531:	74 2f                	je     f0104562 <debuginfo_eip+0x216>
f0104533:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f0104537:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f010453a:	eb 15                	jmp    f0104551 <debuginfo_eip+0x205>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f010453c:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f010453f:	39 fb                	cmp    %edi,%ebx
f0104541:	7c 37                	jl     f010457a <debuginfo_eip+0x22e>
	       && stabs[lline].n_type != N_SOL
f0104543:	89 c1                	mov    %eax,%ecx
f0104545:	83 e8 0c             	sub    $0xc,%eax
f0104548:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f010454c:	80 fa 84             	cmp    $0x84,%dl
f010454f:	74 11                	je     f0104562 <debuginfo_eip+0x216>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0104551:	80 fa 64             	cmp    $0x64,%dl
f0104554:	75 e6                	jne    f010453c <debuginfo_eip+0x1f0>
f0104556:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f010455a:	74 e0                	je     f010453c <debuginfo_eip+0x1f0>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f010455c:	39 df                	cmp    %ebx,%edi
f010455e:	66 90                	xchg   %ax,%ax
f0104560:	7f 18                	jg     f010457a <debuginfo_eip+0x22e>
f0104562:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104565:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104568:	8b 04 87             	mov    (%edi,%eax,4),%eax
f010456b:	8b 55 cc             	mov    -0x34(%ebp),%edx
f010456e:	2b 55 d0             	sub    -0x30(%ebp),%edx
f0104571:	39 d0                	cmp    %edx,%eax
f0104573:	73 05                	jae    f010457a <debuginfo_eip+0x22e>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0104575:	03 45 d0             	add    -0x30(%ebp),%eax
f0104578:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f010457a:	8b 55 dc             	mov    -0x24(%ebp),%edx
f010457d:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0104580:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0104585:	39 ca                	cmp    %ecx,%edx
f0104587:	7d 75                	jge    f01045fe <debuginfo_eip+0x2b2>
		for (lline = lfun + 1;
f0104589:	8d 42 01             	lea    0x1(%edx),%eax
f010458c:	39 c1                	cmp    %eax,%ecx
f010458e:	7e 54                	jle    f01045e4 <debuginfo_eip+0x298>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0104590:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104593:	c1 e2 02             	shl    $0x2,%edx
f0104596:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104599:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f010459e:	75 4b                	jne    f01045eb <debuginfo_eip+0x29f>
f01045a0:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f01045a4:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f01045a8:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f01045ab:	39 c1                	cmp    %eax,%ecx
f01045ad:	7e 43                	jle    f01045f2 <debuginfo_eip+0x2a6>
f01045af:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f01045b2:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f01045b6:	74 ec                	je     f01045a4 <debuginfo_eip+0x258>
f01045b8:	eb 3f                	jmp    f01045f9 <debuginfo_eip+0x2ad>

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if ( user_mem_check(curenv,(void *)usd,sizeof(struct UserStabData),0)!=0)
			return -1;
f01045ba:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01045bf:	eb 3d                	jmp    f01045fe <debuginfo_eip+0x2b2>

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) != 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) !=0)
		 {
		    return -1;
f01045c1:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01045c6:	eb 36                	jmp    f01045fe <debuginfo_eip+0x2b2>
f01045c8:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01045cd:	eb 2f                	jmp    f01045fe <debuginfo_eip+0x2b2>
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f01045cf:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01045d4:	eb 28                	jmp    f01045fe <debuginfo_eip+0x2b2>
f01045d6:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01045db:	eb 21                	jmp    f01045fe <debuginfo_eip+0x2b2>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f01045dd:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01045e2:	eb 1a                	jmp    f01045fe <debuginfo_eip+0x2b2>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f01045e4:	b8 00 00 00 00       	mov    $0x0,%eax
f01045e9:	eb 13                	jmp    f01045fe <debuginfo_eip+0x2b2>
f01045eb:	b8 00 00 00 00       	mov    $0x0,%eax
f01045f0:	eb 0c                	jmp    f01045fe <debuginfo_eip+0x2b2>
f01045f2:	b8 00 00 00 00       	mov    $0x0,%eax
f01045f7:	eb 05                	jmp    f01045fe <debuginfo_eip+0x2b2>
f01045f9:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01045fe:	83 c4 3c             	add    $0x3c,%esp
f0104601:	5b                   	pop    %ebx
f0104602:	5e                   	pop    %esi
f0104603:	5f                   	pop    %edi
f0104604:	5d                   	pop    %ebp
f0104605:	c3                   	ret    
f0104606:	66 90                	xchg   %ax,%ax
f0104608:	66 90                	xchg   %ax,%ax
f010460a:	66 90                	xchg   %ax,%ax
f010460c:	66 90                	xchg   %ax,%ax
f010460e:	66 90                	xchg   %ax,%ax

f0104610 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0104610:	55                   	push   %ebp
f0104611:	89 e5                	mov    %esp,%ebp
f0104613:	57                   	push   %edi
f0104614:	56                   	push   %esi
f0104615:	53                   	push   %ebx
f0104616:	83 ec 3c             	sub    $0x3c,%esp
f0104619:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010461c:	89 d7                	mov    %edx,%edi
f010461e:	8b 45 08             	mov    0x8(%ebp),%eax
f0104621:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0104624:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104627:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f010462a:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f010462d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0104632:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0104635:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0104638:	39 f1                	cmp    %esi,%ecx
f010463a:	72 14                	jb     f0104650 <printnum+0x40>
f010463c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f010463f:	76 0f                	jbe    f0104650 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0104641:	8b 45 14             	mov    0x14(%ebp),%eax
f0104644:	8d 70 ff             	lea    -0x1(%eax),%esi
f0104647:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f010464a:	85 f6                	test   %esi,%esi
f010464c:	7f 60                	jg     f01046ae <printnum+0x9e>
f010464e:	eb 72                	jmp    f01046c2 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0104650:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0104653:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0104657:	8b 4d 14             	mov    0x14(%ebp),%ecx
f010465a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f010465d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0104661:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104665:	8b 44 24 08          	mov    0x8(%esp),%eax
f0104669:	8b 54 24 0c          	mov    0xc(%esp),%edx
f010466d:	89 c3                	mov    %eax,%ebx
f010466f:	89 d6                	mov    %edx,%esi
f0104671:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0104674:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0104677:	89 54 24 08          	mov    %edx,0x8(%esp)
f010467b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f010467f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104682:	89 04 24             	mov    %eax,(%esp)
f0104685:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0104688:	89 44 24 04          	mov    %eax,0x4(%esp)
f010468c:	e8 6f 0a 00 00       	call   f0105100 <__udivdi3>
f0104691:	89 d9                	mov    %ebx,%ecx
f0104693:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104697:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010469b:	89 04 24             	mov    %eax,(%esp)
f010469e:	89 54 24 04          	mov    %edx,0x4(%esp)
f01046a2:	89 fa                	mov    %edi,%edx
f01046a4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01046a7:	e8 64 ff ff ff       	call   f0104610 <printnum>
f01046ac:	eb 14                	jmp    f01046c2 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f01046ae:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01046b2:	8b 45 18             	mov    0x18(%ebp),%eax
f01046b5:	89 04 24             	mov    %eax,(%esp)
f01046b8:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f01046ba:	83 ee 01             	sub    $0x1,%esi
f01046bd:	75 ef                	jne    f01046ae <printnum+0x9e>
f01046bf:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f01046c2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01046c6:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01046ca:	8b 45 d8             	mov    -0x28(%ebp),%eax
f01046cd:	8b 55 dc             	mov    -0x24(%ebp),%edx
f01046d0:	89 44 24 08          	mov    %eax,0x8(%esp)
f01046d4:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01046d8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01046db:	89 04 24             	mov    %eax,(%esp)
f01046de:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01046e1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046e5:	e8 46 0b 00 00       	call   f0105230 <__umoddi3>
f01046ea:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01046ee:	0f be 80 52 68 10 f0 	movsbl -0xfef97ae(%eax),%eax
f01046f5:	89 04 24             	mov    %eax,(%esp)
f01046f8:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01046fb:	ff d0                	call   *%eax
}
f01046fd:	83 c4 3c             	add    $0x3c,%esp
f0104700:	5b                   	pop    %ebx
f0104701:	5e                   	pop    %esi
f0104702:	5f                   	pop    %edi
f0104703:	5d                   	pop    %ebp
f0104704:	c3                   	ret    

f0104705 <getuint>:

// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
f0104705:	55                   	push   %ebp
f0104706:	89 e5                	mov    %esp,%ebp
	if (lflag >= 2)
f0104708:	83 fa 01             	cmp    $0x1,%edx
f010470b:	7e 0e                	jle    f010471b <getuint+0x16>
		return va_arg(*ap, unsigned long long);
f010470d:	8b 10                	mov    (%eax),%edx
f010470f:	8d 4a 08             	lea    0x8(%edx),%ecx
f0104712:	89 08                	mov    %ecx,(%eax)
f0104714:	8b 02                	mov    (%edx),%eax
f0104716:	8b 52 04             	mov    0x4(%edx),%edx
f0104719:	eb 22                	jmp    f010473d <getuint+0x38>
	else if (lflag)
f010471b:	85 d2                	test   %edx,%edx
f010471d:	74 10                	je     f010472f <getuint+0x2a>
		return va_arg(*ap, unsigned long);
f010471f:	8b 10                	mov    (%eax),%edx
f0104721:	8d 4a 04             	lea    0x4(%edx),%ecx
f0104724:	89 08                	mov    %ecx,(%eax)
f0104726:	8b 02                	mov    (%edx),%eax
f0104728:	ba 00 00 00 00       	mov    $0x0,%edx
f010472d:	eb 0e                	jmp    f010473d <getuint+0x38>
	else
		return va_arg(*ap, unsigned int);
f010472f:	8b 10                	mov    (%eax),%edx
f0104731:	8d 4a 04             	lea    0x4(%edx),%ecx
f0104734:	89 08                	mov    %ecx,(%eax)
f0104736:	8b 02                	mov    (%edx),%eax
f0104738:	ba 00 00 00 00       	mov    $0x0,%edx
}
f010473d:	5d                   	pop    %ebp
f010473e:	c3                   	ret    

f010473f <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f010473f:	55                   	push   %ebp
f0104740:	89 e5                	mov    %esp,%ebp
f0104742:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0104745:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0104749:	8b 10                	mov    (%eax),%edx
f010474b:	3b 50 04             	cmp    0x4(%eax),%edx
f010474e:	73 0a                	jae    f010475a <sprintputch+0x1b>
		*b->buf++ = ch;
f0104750:	8d 4a 01             	lea    0x1(%edx),%ecx
f0104753:	89 08                	mov    %ecx,(%eax)
f0104755:	8b 45 08             	mov    0x8(%ebp),%eax
f0104758:	88 02                	mov    %al,(%edx)
}
f010475a:	5d                   	pop    %ebp
f010475b:	c3                   	ret    

f010475c <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f010475c:	55                   	push   %ebp
f010475d:	89 e5                	mov    %esp,%ebp
f010475f:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0104762:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0104765:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104769:	8b 45 10             	mov    0x10(%ebp),%eax
f010476c:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104770:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104773:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104777:	8b 45 08             	mov    0x8(%ebp),%eax
f010477a:	89 04 24             	mov    %eax,(%esp)
f010477d:	e8 02 00 00 00       	call   f0104784 <vprintfmt>
	va_end(ap);
}
f0104782:	c9                   	leave  
f0104783:	c3                   	ret    

f0104784 <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f0104784:	55                   	push   %ebp
f0104785:	89 e5                	mov    %esp,%ebp
f0104787:	57                   	push   %edi
f0104788:	56                   	push   %esi
f0104789:	53                   	push   %ebx
f010478a:	83 ec 3c             	sub    $0x3c,%esp
f010478d:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0104790:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0104793:	eb 18                	jmp    f01047ad <vprintfmt+0x29>
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
			if (ch == '\0')
f0104795:	85 c0                	test   %eax,%eax
f0104797:	0f 84 c3 03 00 00    	je     f0104b60 <vprintfmt+0x3dc>
				return;
			putch(ch, putdat);
f010479d:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01047a1:	89 04 24             	mov    %eax,(%esp)
f01047a4:	ff 55 08             	call   *0x8(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01047a7:	89 f3                	mov    %esi,%ebx
f01047a9:	eb 02                	jmp    f01047ad <vprintfmt+0x29>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f01047ab:	89 f3                	mov    %esi,%ebx
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01047ad:	8d 73 01             	lea    0x1(%ebx),%esi
f01047b0:	0f b6 03             	movzbl (%ebx),%eax
f01047b3:	83 f8 25             	cmp    $0x25,%eax
f01047b6:	75 dd                	jne    f0104795 <vprintfmt+0x11>
f01047b8:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f01047bc:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f01047c3:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f01047ca:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f01047d1:	ba 00 00 00 00       	mov    $0x0,%edx
f01047d6:	eb 1d                	jmp    f01047f5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01047d8:	89 de                	mov    %ebx,%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f01047da:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f01047de:	eb 15                	jmp    f01047f5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01047e0:	89 de                	mov    %ebx,%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f01047e2:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f01047e6:	eb 0d                	jmp    f01047f5 <vprintfmt+0x71>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f01047e8:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01047eb:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01047ee:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01047f5:	8d 5e 01             	lea    0x1(%esi),%ebx
f01047f8:	0f b6 06             	movzbl (%esi),%eax
f01047fb:	0f b6 c8             	movzbl %al,%ecx
f01047fe:	83 e8 23             	sub    $0x23,%eax
f0104801:	3c 55                	cmp    $0x55,%al
f0104803:	0f 87 2f 03 00 00    	ja     f0104b38 <vprintfmt+0x3b4>
f0104809:	0f b6 c0             	movzbl %al,%eax
f010480c:	ff 24 85 dc 68 10 f0 	jmp    *-0xfef9724(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0104813:	8d 41 d0             	lea    -0x30(%ecx),%eax
f0104816:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0104819:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f010481d:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0104820:	83 f9 09             	cmp    $0x9,%ecx
f0104823:	77 50                	ja     f0104875 <vprintfmt+0xf1>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104825:	89 de                	mov    %ebx,%esi
f0104827:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f010482a:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f010482d:	8d 0c 89             	lea    (%ecx,%ecx,4),%ecx
f0104830:	8d 4c 48 d0          	lea    -0x30(%eax,%ecx,2),%ecx
				ch = *fmt;
f0104834:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0104837:	8d 58 d0             	lea    -0x30(%eax),%ebx
f010483a:	83 fb 09             	cmp    $0x9,%ebx
f010483d:	76 eb                	jbe    f010482a <vprintfmt+0xa6>
f010483f:	89 4d d4             	mov    %ecx,-0x2c(%ebp)
f0104842:	eb 33                	jmp    f0104877 <vprintfmt+0xf3>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0104844:	8b 45 14             	mov    0x14(%ebp),%eax
f0104847:	8d 48 04             	lea    0x4(%eax),%ecx
f010484a:	89 4d 14             	mov    %ecx,0x14(%ebp)
f010484d:	8b 00                	mov    (%eax),%eax
f010484f:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104852:	89 de                	mov    %ebx,%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0104854:	eb 21                	jmp    f0104877 <vprintfmt+0xf3>
f0104856:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0104859:	85 c9                	test   %ecx,%ecx
f010485b:	b8 00 00 00 00       	mov    $0x0,%eax
f0104860:	0f 49 c1             	cmovns %ecx,%eax
f0104863:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104866:	89 de                	mov    %ebx,%esi
f0104868:	eb 8b                	jmp    f01047f5 <vprintfmt+0x71>
f010486a:	89 de                	mov    %ebx,%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f010486c:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f0104873:	eb 80                	jmp    f01047f5 <vprintfmt+0x71>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104875:	89 de                	mov    %ebx,%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0104877:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f010487b:	0f 89 74 ff ff ff    	jns    f01047f5 <vprintfmt+0x71>
f0104881:	e9 62 ff ff ff       	jmp    f01047e8 <vprintfmt+0x64>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0104886:	83 c2 01             	add    $0x1,%edx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0104889:	89 de                	mov    %ebx,%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f010488b:	e9 65 ff ff ff       	jmp    f01047f5 <vprintfmt+0x71>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f0104890:	8b 45 14             	mov    0x14(%ebp),%eax
f0104893:	8d 50 04             	lea    0x4(%eax),%edx
f0104896:	89 55 14             	mov    %edx,0x14(%ebp)
f0104899:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010489d:	8b 00                	mov    (%eax),%eax
f010489f:	89 04 24             	mov    %eax,(%esp)
f01048a2:	ff 55 08             	call   *0x8(%ebp)
			break;
f01048a5:	e9 03 ff ff ff       	jmp    f01047ad <vprintfmt+0x29>

		// error message
		case 'e':
			err = va_arg(ap, int);
f01048aa:	8b 45 14             	mov    0x14(%ebp),%eax
f01048ad:	8d 50 04             	lea    0x4(%eax),%edx
f01048b0:	89 55 14             	mov    %edx,0x14(%ebp)
f01048b3:	8b 00                	mov    (%eax),%eax
f01048b5:	99                   	cltd   
f01048b6:	31 d0                	xor    %edx,%eax
f01048b8:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f01048ba:	83 f8 06             	cmp    $0x6,%eax
f01048bd:	7f 0b                	jg     f01048ca <vprintfmt+0x146>
f01048bf:	8b 14 85 34 6a 10 f0 	mov    -0xfef95cc(,%eax,4),%edx
f01048c6:	85 d2                	test   %edx,%edx
f01048c8:	75 20                	jne    f01048ea <vprintfmt+0x166>
				printfmt(putch, putdat, "error %d", err);
f01048ca:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01048ce:	c7 44 24 08 6a 68 10 	movl   $0xf010686a,0x8(%esp)
f01048d5:	f0 
f01048d6:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01048da:	8b 45 08             	mov    0x8(%ebp),%eax
f01048dd:	89 04 24             	mov    %eax,(%esp)
f01048e0:	e8 77 fe ff ff       	call   f010475c <printfmt>
f01048e5:	e9 c3 fe ff ff       	jmp    f01047ad <vprintfmt+0x29>
			else
				printfmt(putch, putdat, "%s", p);
f01048ea:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01048ee:	c7 44 24 08 d9 60 10 	movl   $0xf01060d9,0x8(%esp)
f01048f5:	f0 
f01048f6:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01048fa:	8b 45 08             	mov    0x8(%ebp),%eax
f01048fd:	89 04 24             	mov    %eax,(%esp)
f0104900:	e8 57 fe ff ff       	call   f010475c <printfmt>
f0104905:	e9 a3 fe ff ff       	jmp    f01047ad <vprintfmt+0x29>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010490a:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f010490d:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0104910:	8b 45 14             	mov    0x14(%ebp),%eax
f0104913:	8d 50 04             	lea    0x4(%eax),%edx
f0104916:	89 55 14             	mov    %edx,0x14(%ebp)
f0104919:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f010491b:	85 c0                	test   %eax,%eax
f010491d:	ba 63 68 10 f0       	mov    $0xf0106863,%edx
f0104922:	0f 45 d0             	cmovne %eax,%edx
f0104925:	89 55 d0             	mov    %edx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f0104928:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f010492c:	74 04                	je     f0104932 <vprintfmt+0x1ae>
f010492e:	85 f6                	test   %esi,%esi
f0104930:	7f 19                	jg     f010494b <vprintfmt+0x1c7>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0104932:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0104935:	8d 70 01             	lea    0x1(%eax),%esi
f0104938:	0f b6 10             	movzbl (%eax),%edx
f010493b:	0f be c2             	movsbl %dl,%eax
f010493e:	85 c0                	test   %eax,%eax
f0104940:	0f 85 95 00 00 00    	jne    f01049db <vprintfmt+0x257>
f0104946:	e9 85 00 00 00       	jmp    f01049d0 <vprintfmt+0x24c>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f010494b:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f010494f:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0104952:	89 04 24             	mov    %eax,(%esp)
f0104955:	e8 88 03 00 00       	call   f0104ce2 <strnlen>
f010495a:	29 c6                	sub    %eax,%esi
f010495c:	89 f0                	mov    %esi,%eax
f010495e:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0104961:	85 f6                	test   %esi,%esi
f0104963:	7e cd                	jle    f0104932 <vprintfmt+0x1ae>
					putch(padc, putdat);
f0104965:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0104969:	89 5d 10             	mov    %ebx,0x10(%ebp)
f010496c:	89 c3                	mov    %eax,%ebx
f010496e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104972:	89 34 24             	mov    %esi,(%esp)
f0104975:	ff 55 08             	call   *0x8(%ebp)
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0104978:	83 eb 01             	sub    $0x1,%ebx
f010497b:	75 f1                	jne    f010496e <vprintfmt+0x1ea>
f010497d:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0104980:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0104983:	eb ad                	jmp    f0104932 <vprintfmt+0x1ae>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f0104985:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0104989:	74 1e                	je     f01049a9 <vprintfmt+0x225>
f010498b:	0f be d2             	movsbl %dl,%edx
f010498e:	83 ea 20             	sub    $0x20,%edx
f0104991:	83 fa 5e             	cmp    $0x5e,%edx
f0104994:	76 13                	jbe    f01049a9 <vprintfmt+0x225>
					putch('?', putdat);
f0104996:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104999:	89 44 24 04          	mov    %eax,0x4(%esp)
f010499d:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f01049a4:	ff 55 08             	call   *0x8(%ebp)
f01049a7:	eb 0d                	jmp    f01049b6 <vprintfmt+0x232>
				else
					putch(ch, putdat);
f01049a9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01049ac:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01049b0:	89 04 24             	mov    %eax,(%esp)
f01049b3:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01049b6:	83 ef 01             	sub    $0x1,%edi
f01049b9:	83 c6 01             	add    $0x1,%esi
f01049bc:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f01049c0:	0f be c2             	movsbl %dl,%eax
f01049c3:	85 c0                	test   %eax,%eax
f01049c5:	75 20                	jne    f01049e7 <vprintfmt+0x263>
f01049c7:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f01049ca:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01049cd:	8b 5d 10             	mov    0x10(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01049d0:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01049d4:	7f 25                	jg     f01049fb <vprintfmt+0x277>
f01049d6:	e9 d2 fd ff ff       	jmp    f01047ad <vprintfmt+0x29>
f01049db:	89 7d 0c             	mov    %edi,0xc(%ebp)
f01049de:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01049e1:	89 5d 10             	mov    %ebx,0x10(%ebp)
f01049e4:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01049e7:	85 db                	test   %ebx,%ebx
f01049e9:	78 9a                	js     f0104985 <vprintfmt+0x201>
f01049eb:	83 eb 01             	sub    $0x1,%ebx
f01049ee:	79 95                	jns    f0104985 <vprintfmt+0x201>
f01049f0:	89 7d e4             	mov    %edi,-0x1c(%ebp)
f01049f3:	8b 7d 0c             	mov    0xc(%ebp),%edi
f01049f6:	8b 5d 10             	mov    0x10(%ebp),%ebx
f01049f9:	eb d5                	jmp    f01049d0 <vprintfmt+0x24c>
f01049fb:	8b 75 08             	mov    0x8(%ebp),%esi
f01049fe:	89 5d 10             	mov    %ebx,0x10(%ebp)
f0104a01:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0104a04:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104a08:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f0104a0f:	ff d6                	call   *%esi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0104a11:	83 eb 01             	sub    $0x1,%ebx
f0104a14:	75 ee                	jne    f0104a04 <vprintfmt+0x280>
f0104a16:	8b 5d 10             	mov    0x10(%ebp),%ebx
f0104a19:	e9 8f fd ff ff       	jmp    f01047ad <vprintfmt+0x29>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f0104a1e:	83 fa 01             	cmp    $0x1,%edx
f0104a21:	7e 16                	jle    f0104a39 <vprintfmt+0x2b5>
		return va_arg(*ap, long long);
f0104a23:	8b 45 14             	mov    0x14(%ebp),%eax
f0104a26:	8d 50 08             	lea    0x8(%eax),%edx
f0104a29:	89 55 14             	mov    %edx,0x14(%ebp)
f0104a2c:	8b 50 04             	mov    0x4(%eax),%edx
f0104a2f:	8b 00                	mov    (%eax),%eax
f0104a31:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0104a34:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0104a37:	eb 32                	jmp    f0104a6b <vprintfmt+0x2e7>
	else if (lflag)
f0104a39:	85 d2                	test   %edx,%edx
f0104a3b:	74 18                	je     f0104a55 <vprintfmt+0x2d1>
		return va_arg(*ap, long);
f0104a3d:	8b 45 14             	mov    0x14(%ebp),%eax
f0104a40:	8d 50 04             	lea    0x4(%eax),%edx
f0104a43:	89 55 14             	mov    %edx,0x14(%ebp)
f0104a46:	8b 30                	mov    (%eax),%esi
f0104a48:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0104a4b:	89 f0                	mov    %esi,%eax
f0104a4d:	c1 f8 1f             	sar    $0x1f,%eax
f0104a50:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0104a53:	eb 16                	jmp    f0104a6b <vprintfmt+0x2e7>
	else
		return va_arg(*ap, int);
f0104a55:	8b 45 14             	mov    0x14(%ebp),%eax
f0104a58:	8d 50 04             	lea    0x4(%eax),%edx
f0104a5b:	89 55 14             	mov    %edx,0x14(%ebp)
f0104a5e:	8b 30                	mov    (%eax),%esi
f0104a60:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0104a63:	89 f0                	mov    %esi,%eax
f0104a65:	c1 f8 1f             	sar    $0x1f,%eax
f0104a68:	89 45 dc             	mov    %eax,-0x24(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f0104a6b:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0104a6e:	8b 55 dc             	mov    -0x24(%ebp),%edx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f0104a71:	b9 0a 00 00 00       	mov    $0xa,%ecx
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0104a76:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f0104a7a:	0f 89 80 00 00 00    	jns    f0104b00 <vprintfmt+0x37c>
				putch('-', putdat);
f0104a80:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104a84:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f0104a8b:	ff 55 08             	call   *0x8(%ebp)
				num = -(long long) num;
f0104a8e:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0104a91:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0104a94:	f7 d8                	neg    %eax
f0104a96:	83 d2 00             	adc    $0x0,%edx
f0104a99:	f7 da                	neg    %edx
			}
			base = 10;
f0104a9b:	b9 0a 00 00 00       	mov    $0xa,%ecx
f0104aa0:	eb 5e                	jmp    f0104b00 <vprintfmt+0x37c>
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
f0104aa2:	8d 45 14             	lea    0x14(%ebp),%eax
f0104aa5:	e8 5b fc ff ff       	call   f0104705 <getuint>
			base = 10;
f0104aaa:	b9 0a 00 00 00       	mov    $0xa,%ecx
			goto number;
f0104aaf:	eb 4f                	jmp    f0104b00 <vprintfmt+0x37c>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			//putch('X', putdat);
			num = getuint(&ap, lflag);
f0104ab1:	8d 45 14             	lea    0x14(%ebp),%eax
f0104ab4:	e8 4c fc ff ff       	call   f0104705 <getuint>
			base = 8;
f0104ab9:	b9 08 00 00 00       	mov    $0x8,%ecx
			goto number;
f0104abe:	eb 40                	jmp    f0104b00 <vprintfmt+0x37c>
			//putch('X', putdat);
			//break;

		// pointer
		case 'p':
			putch('0', putdat);
f0104ac0:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104ac4:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f0104acb:	ff 55 08             	call   *0x8(%ebp)
			putch('x', putdat);
f0104ace:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104ad2:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f0104ad9:	ff 55 08             	call   *0x8(%ebp)
			num = (unsigned long long)
				(uintptr_t) va_arg(ap, void *);
f0104adc:	8b 45 14             	mov    0x14(%ebp),%eax
f0104adf:	8d 50 04             	lea    0x4(%eax),%edx
f0104ae2:	89 55 14             	mov    %edx,0x14(%ebp)

		// pointer
		case 'p':
			putch('0', putdat);
			putch('x', putdat);
			num = (unsigned long long)
f0104ae5:	8b 00                	mov    (%eax),%eax
f0104ae7:	ba 00 00 00 00       	mov    $0x0,%edx
				(uintptr_t) va_arg(ap, void *);
			base = 16;
f0104aec:	b9 10 00 00 00       	mov    $0x10,%ecx
			goto number;
f0104af1:	eb 0d                	jmp    f0104b00 <vprintfmt+0x37c>

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
f0104af3:	8d 45 14             	lea    0x14(%ebp),%eax
f0104af6:	e8 0a fc ff ff       	call   f0104705 <getuint>
			base = 16;
f0104afb:	b9 10 00 00 00       	mov    $0x10,%ecx
		number:
			printnum(putch, putdat, num, base, width, padc);
f0104b00:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0104b04:	89 74 24 10          	mov    %esi,0x10(%esp)
f0104b08:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0104b0b:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0104b0f:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104b13:	89 04 24             	mov    %eax,(%esp)
f0104b16:	89 54 24 04          	mov    %edx,0x4(%esp)
f0104b1a:	89 fa                	mov    %edi,%edx
f0104b1c:	8b 45 08             	mov    0x8(%ebp),%eax
f0104b1f:	e8 ec fa ff ff       	call   f0104610 <printnum>
			break;
f0104b24:	e9 84 fc ff ff       	jmp    f01047ad <vprintfmt+0x29>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0104b29:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104b2d:	89 0c 24             	mov    %ecx,(%esp)
f0104b30:	ff 55 08             	call   *0x8(%ebp)
			break;
f0104b33:	e9 75 fc ff ff       	jmp    f01047ad <vprintfmt+0x29>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0104b38:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104b3c:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0104b43:	ff 55 08             	call   *0x8(%ebp)
			for (fmt--; fmt[-1] != '%'; fmt--)
f0104b46:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f0104b4a:	0f 84 5b fc ff ff    	je     f01047ab <vprintfmt+0x27>
f0104b50:	89 f3                	mov    %esi,%ebx
f0104b52:	83 eb 01             	sub    $0x1,%ebx
f0104b55:	80 7b ff 25          	cmpb   $0x25,-0x1(%ebx)
f0104b59:	75 f7                	jne    f0104b52 <vprintfmt+0x3ce>
f0104b5b:	e9 4d fc ff ff       	jmp    f01047ad <vprintfmt+0x29>
				/* do nothing */;
			break;
		}
	}
}
f0104b60:	83 c4 3c             	add    $0x3c,%esp
f0104b63:	5b                   	pop    %ebx
f0104b64:	5e                   	pop    %esi
f0104b65:	5f                   	pop    %edi
f0104b66:	5d                   	pop    %ebp
f0104b67:	c3                   	ret    

f0104b68 <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0104b68:	55                   	push   %ebp
f0104b69:	89 e5                	mov    %esp,%ebp
f0104b6b:	83 ec 28             	sub    $0x28,%esp
f0104b6e:	8b 45 08             	mov    0x8(%ebp),%eax
f0104b71:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0104b74:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0104b77:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f0104b7b:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f0104b7e:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0104b85:	85 c0                	test   %eax,%eax
f0104b87:	74 30                	je     f0104bb9 <vsnprintf+0x51>
f0104b89:	85 d2                	test   %edx,%edx
f0104b8b:	7e 2c                	jle    f0104bb9 <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f0104b8d:	8b 45 14             	mov    0x14(%ebp),%eax
f0104b90:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104b94:	8b 45 10             	mov    0x10(%ebp),%eax
f0104b97:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104b9b:	8d 45 ec             	lea    -0x14(%ebp),%eax
f0104b9e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104ba2:	c7 04 24 3f 47 10 f0 	movl   $0xf010473f,(%esp)
f0104ba9:	e8 d6 fb ff ff       	call   f0104784 <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0104bae:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0104bb1:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0104bb4:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0104bb7:	eb 05                	jmp    f0104bbe <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f0104bb9:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f0104bbe:	c9                   	leave  
f0104bbf:	c3                   	ret    

f0104bc0 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f0104bc0:	55                   	push   %ebp
f0104bc1:	89 e5                	mov    %esp,%ebp
f0104bc3:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0104bc6:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f0104bc9:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104bcd:	8b 45 10             	mov    0x10(%ebp),%eax
f0104bd0:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104bd4:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104bd7:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104bdb:	8b 45 08             	mov    0x8(%ebp),%eax
f0104bde:	89 04 24             	mov    %eax,(%esp)
f0104be1:	e8 82 ff ff ff       	call   f0104b68 <vsnprintf>
	va_end(ap);

	return rc;
}
f0104be6:	c9                   	leave  
f0104be7:	c3                   	ret    
f0104be8:	66 90                	xchg   %ax,%ax
f0104bea:	66 90                	xchg   %ax,%ax
f0104bec:	66 90                	xchg   %ax,%ax
f0104bee:	66 90                	xchg   %ax,%ax

f0104bf0 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0104bf0:	55                   	push   %ebp
f0104bf1:	89 e5                	mov    %esp,%ebp
f0104bf3:	57                   	push   %edi
f0104bf4:	56                   	push   %esi
f0104bf5:	53                   	push   %ebx
f0104bf6:	83 ec 1c             	sub    $0x1c,%esp
f0104bf9:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f0104bfc:	85 c0                	test   %eax,%eax
f0104bfe:	74 10                	je     f0104c10 <readline+0x20>
		cprintf("%s", prompt);
f0104c00:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104c04:	c7 04 24 d9 60 10 f0 	movl   $0xf01060d9,(%esp)
f0104c0b:	e8 25 ed ff ff       	call   f0103935 <cprintf>

	i = 0;
	echoing = iscons(0);
f0104c10:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0104c17:	e8 39 ba ff ff       	call   f0100655 <iscons>
f0104c1c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f0104c1e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0104c23:	e8 1c ba ff ff       	call   f0100644 <getchar>
f0104c28:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f0104c2a:	85 c0                	test   %eax,%eax
f0104c2c:	79 17                	jns    f0104c45 <readline+0x55>
			cprintf("read error: %e\n", c);
f0104c2e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104c32:	c7 04 24 50 6a 10 f0 	movl   $0xf0106a50,(%esp)
f0104c39:	e8 f7 ec ff ff       	call   f0103935 <cprintf>
			return NULL;
f0104c3e:	b8 00 00 00 00       	mov    $0x0,%eax
f0104c43:	eb 6d                	jmp    f0104cb2 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0104c45:	83 f8 7f             	cmp    $0x7f,%eax
f0104c48:	74 05                	je     f0104c4f <readline+0x5f>
f0104c4a:	83 f8 08             	cmp    $0x8,%eax
f0104c4d:	75 19                	jne    f0104c68 <readline+0x78>
f0104c4f:	85 f6                	test   %esi,%esi
f0104c51:	7e 15                	jle    f0104c68 <readline+0x78>
			if (echoing)
f0104c53:	85 ff                	test   %edi,%edi
f0104c55:	74 0c                	je     f0104c63 <readline+0x73>
				cputchar('\b');
f0104c57:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f0104c5e:	e8 d1 b9 ff ff       	call   f0100634 <cputchar>
			i--;
f0104c63:	83 ee 01             	sub    $0x1,%esi
f0104c66:	eb bb                	jmp    f0104c23 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0104c68:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f0104c6e:	7f 1c                	jg     f0104c8c <readline+0x9c>
f0104c70:	83 fb 1f             	cmp    $0x1f,%ebx
f0104c73:	7e 17                	jle    f0104c8c <readline+0x9c>
			if (echoing)
f0104c75:	85 ff                	test   %edi,%edi
f0104c77:	74 08                	je     f0104c81 <readline+0x91>
				cputchar(c);
f0104c79:	89 1c 24             	mov    %ebx,(%esp)
f0104c7c:	e8 b3 b9 ff ff       	call   f0100634 <cputchar>
			buf[i++] = c;
f0104c81:	88 9e c0 eb 17 f0    	mov    %bl,-0xfe81440(%esi)
f0104c87:	8d 76 01             	lea    0x1(%esi),%esi
f0104c8a:	eb 97                	jmp    f0104c23 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f0104c8c:	83 fb 0d             	cmp    $0xd,%ebx
f0104c8f:	74 05                	je     f0104c96 <readline+0xa6>
f0104c91:	83 fb 0a             	cmp    $0xa,%ebx
f0104c94:	75 8d                	jne    f0104c23 <readline+0x33>
			if (echoing)
f0104c96:	85 ff                	test   %edi,%edi
f0104c98:	74 0c                	je     f0104ca6 <readline+0xb6>
				cputchar('\n');
f0104c9a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0104ca1:	e8 8e b9 ff ff       	call   f0100634 <cputchar>
			buf[i] = 0;
f0104ca6:	c6 86 c0 eb 17 f0 00 	movb   $0x0,-0xfe81440(%esi)
			return buf;
f0104cad:	b8 c0 eb 17 f0       	mov    $0xf017ebc0,%eax
		}
	}
}
f0104cb2:	83 c4 1c             	add    $0x1c,%esp
f0104cb5:	5b                   	pop    %ebx
f0104cb6:	5e                   	pop    %esi
f0104cb7:	5f                   	pop    %edi
f0104cb8:	5d                   	pop    %ebp
f0104cb9:	c3                   	ret    
f0104cba:	66 90                	xchg   %ax,%ax
f0104cbc:	66 90                	xchg   %ax,%ax
f0104cbe:	66 90                	xchg   %ax,%ax

f0104cc0 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0104cc0:	55                   	push   %ebp
f0104cc1:	89 e5                	mov    %esp,%ebp
f0104cc3:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0104cc6:	80 3a 00             	cmpb   $0x0,(%edx)
f0104cc9:	74 10                	je     f0104cdb <strlen+0x1b>
f0104ccb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f0104cd0:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0104cd3:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0104cd7:	75 f7                	jne    f0104cd0 <strlen+0x10>
f0104cd9:	eb 05                	jmp    f0104ce0 <strlen+0x20>
f0104cdb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0104ce0:	5d                   	pop    %ebp
f0104ce1:	c3                   	ret    

f0104ce2 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0104ce2:	55                   	push   %ebp
f0104ce3:	89 e5                	mov    %esp,%ebp
f0104ce5:	53                   	push   %ebx
f0104ce6:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0104ce9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0104cec:	85 c9                	test   %ecx,%ecx
f0104cee:	74 1c                	je     f0104d0c <strnlen+0x2a>
f0104cf0:	80 3b 00             	cmpb   $0x0,(%ebx)
f0104cf3:	74 1e                	je     f0104d13 <strnlen+0x31>
f0104cf5:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f0104cfa:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0104cfc:	39 ca                	cmp    %ecx,%edx
f0104cfe:	74 18                	je     f0104d18 <strnlen+0x36>
f0104d00:	83 c2 01             	add    $0x1,%edx
f0104d03:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0104d08:	75 f0                	jne    f0104cfa <strnlen+0x18>
f0104d0a:	eb 0c                	jmp    f0104d18 <strnlen+0x36>
f0104d0c:	b8 00 00 00 00       	mov    $0x0,%eax
f0104d11:	eb 05                	jmp    f0104d18 <strnlen+0x36>
f0104d13:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0104d18:	5b                   	pop    %ebx
f0104d19:	5d                   	pop    %ebp
f0104d1a:	c3                   	ret    

f0104d1b <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f0104d1b:	55                   	push   %ebp
f0104d1c:	89 e5                	mov    %esp,%ebp
f0104d1e:	53                   	push   %ebx
f0104d1f:	8b 45 08             	mov    0x8(%ebp),%eax
f0104d22:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0104d25:	89 c2                	mov    %eax,%edx
f0104d27:	83 c2 01             	add    $0x1,%edx
f0104d2a:	83 c1 01             	add    $0x1,%ecx
f0104d2d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0104d31:	88 5a ff             	mov    %bl,-0x1(%edx)
f0104d34:	84 db                	test   %bl,%bl
f0104d36:	75 ef                	jne    f0104d27 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0104d38:	5b                   	pop    %ebx
f0104d39:	5d                   	pop    %ebp
f0104d3a:	c3                   	ret    

f0104d3b <strcat>:

char *
strcat(char *dst, const char *src)
{
f0104d3b:	55                   	push   %ebp
f0104d3c:	89 e5                	mov    %esp,%ebp
f0104d3e:	53                   	push   %ebx
f0104d3f:	83 ec 08             	sub    $0x8,%esp
f0104d42:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f0104d45:	89 1c 24             	mov    %ebx,(%esp)
f0104d48:	e8 73 ff ff ff       	call   f0104cc0 <strlen>
	strcpy(dst + len, src);
f0104d4d:	8b 55 0c             	mov    0xc(%ebp),%edx
f0104d50:	89 54 24 04          	mov    %edx,0x4(%esp)
f0104d54:	01 d8                	add    %ebx,%eax
f0104d56:	89 04 24             	mov    %eax,(%esp)
f0104d59:	e8 bd ff ff ff       	call   f0104d1b <strcpy>
	return dst;
}
f0104d5e:	89 d8                	mov    %ebx,%eax
f0104d60:	83 c4 08             	add    $0x8,%esp
f0104d63:	5b                   	pop    %ebx
f0104d64:	5d                   	pop    %ebp
f0104d65:	c3                   	ret    

f0104d66 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f0104d66:	55                   	push   %ebp
f0104d67:	89 e5                	mov    %esp,%ebp
f0104d69:	56                   	push   %esi
f0104d6a:	53                   	push   %ebx
f0104d6b:	8b 75 08             	mov    0x8(%ebp),%esi
f0104d6e:	8b 55 0c             	mov    0xc(%ebp),%edx
f0104d71:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0104d74:	85 db                	test   %ebx,%ebx
f0104d76:	74 17                	je     f0104d8f <strncpy+0x29>
f0104d78:	01 f3                	add    %esi,%ebx
f0104d7a:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f0104d7c:	83 c1 01             	add    $0x1,%ecx
f0104d7f:	0f b6 02             	movzbl (%edx),%eax
f0104d82:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f0104d85:	80 3a 01             	cmpb   $0x1,(%edx)
f0104d88:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0104d8b:	39 d9                	cmp    %ebx,%ecx
f0104d8d:	75 ed                	jne    f0104d7c <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f0104d8f:	89 f0                	mov    %esi,%eax
f0104d91:	5b                   	pop    %ebx
f0104d92:	5e                   	pop    %esi
f0104d93:	5d                   	pop    %ebp
f0104d94:	c3                   	ret    

f0104d95 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f0104d95:	55                   	push   %ebp
f0104d96:	89 e5                	mov    %esp,%ebp
f0104d98:	57                   	push   %edi
f0104d99:	56                   	push   %esi
f0104d9a:	53                   	push   %ebx
f0104d9b:	8b 7d 08             	mov    0x8(%ebp),%edi
f0104d9e:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0104da1:	8b 75 10             	mov    0x10(%ebp),%esi
f0104da4:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0104da6:	85 f6                	test   %esi,%esi
f0104da8:	74 34                	je     f0104dde <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f0104daa:	83 fe 01             	cmp    $0x1,%esi
f0104dad:	74 26                	je     f0104dd5 <strlcpy+0x40>
f0104daf:	0f b6 0b             	movzbl (%ebx),%ecx
f0104db2:	84 c9                	test   %cl,%cl
f0104db4:	74 23                	je     f0104dd9 <strlcpy+0x44>
f0104db6:	83 ee 02             	sub    $0x2,%esi
f0104db9:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f0104dbe:	83 c0 01             	add    $0x1,%eax
f0104dc1:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0104dc4:	39 f2                	cmp    %esi,%edx
f0104dc6:	74 13                	je     f0104ddb <strlcpy+0x46>
f0104dc8:	83 c2 01             	add    $0x1,%edx
f0104dcb:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f0104dcf:	84 c9                	test   %cl,%cl
f0104dd1:	75 eb                	jne    f0104dbe <strlcpy+0x29>
f0104dd3:	eb 06                	jmp    f0104ddb <strlcpy+0x46>
f0104dd5:	89 f8                	mov    %edi,%eax
f0104dd7:	eb 02                	jmp    f0104ddb <strlcpy+0x46>
f0104dd9:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f0104ddb:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f0104dde:	29 f8                	sub    %edi,%eax
}
f0104de0:	5b                   	pop    %ebx
f0104de1:	5e                   	pop    %esi
f0104de2:	5f                   	pop    %edi
f0104de3:	5d                   	pop    %ebp
f0104de4:	c3                   	ret    

f0104de5 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f0104de5:	55                   	push   %ebp
f0104de6:	89 e5                	mov    %esp,%ebp
f0104de8:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0104deb:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f0104dee:	0f b6 01             	movzbl (%ecx),%eax
f0104df1:	84 c0                	test   %al,%al
f0104df3:	74 15                	je     f0104e0a <strcmp+0x25>
f0104df5:	3a 02                	cmp    (%edx),%al
f0104df7:	75 11                	jne    f0104e0a <strcmp+0x25>
		p++, q++;
f0104df9:	83 c1 01             	add    $0x1,%ecx
f0104dfc:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f0104dff:	0f b6 01             	movzbl (%ecx),%eax
f0104e02:	84 c0                	test   %al,%al
f0104e04:	74 04                	je     f0104e0a <strcmp+0x25>
f0104e06:	3a 02                	cmp    (%edx),%al
f0104e08:	74 ef                	je     f0104df9 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f0104e0a:	0f b6 c0             	movzbl %al,%eax
f0104e0d:	0f b6 12             	movzbl (%edx),%edx
f0104e10:	29 d0                	sub    %edx,%eax
}
f0104e12:	5d                   	pop    %ebp
f0104e13:	c3                   	ret    

f0104e14 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0104e14:	55                   	push   %ebp
f0104e15:	89 e5                	mov    %esp,%ebp
f0104e17:	56                   	push   %esi
f0104e18:	53                   	push   %ebx
f0104e19:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0104e1c:	8b 55 0c             	mov    0xc(%ebp),%edx
f0104e1f:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f0104e22:	85 f6                	test   %esi,%esi
f0104e24:	74 29                	je     f0104e4f <strncmp+0x3b>
f0104e26:	0f b6 03             	movzbl (%ebx),%eax
f0104e29:	84 c0                	test   %al,%al
f0104e2b:	74 30                	je     f0104e5d <strncmp+0x49>
f0104e2d:	3a 02                	cmp    (%edx),%al
f0104e2f:	75 2c                	jne    f0104e5d <strncmp+0x49>
f0104e31:	8d 43 01             	lea    0x1(%ebx),%eax
f0104e34:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f0104e36:	89 c3                	mov    %eax,%ebx
f0104e38:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f0104e3b:	39 f0                	cmp    %esi,%eax
f0104e3d:	74 17                	je     f0104e56 <strncmp+0x42>
f0104e3f:	0f b6 08             	movzbl (%eax),%ecx
f0104e42:	84 c9                	test   %cl,%cl
f0104e44:	74 17                	je     f0104e5d <strncmp+0x49>
f0104e46:	83 c0 01             	add    $0x1,%eax
f0104e49:	3a 0a                	cmp    (%edx),%cl
f0104e4b:	74 e9                	je     f0104e36 <strncmp+0x22>
f0104e4d:	eb 0e                	jmp    f0104e5d <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f0104e4f:	b8 00 00 00 00       	mov    $0x0,%eax
f0104e54:	eb 0f                	jmp    f0104e65 <strncmp+0x51>
f0104e56:	b8 00 00 00 00       	mov    $0x0,%eax
f0104e5b:	eb 08                	jmp    f0104e65 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f0104e5d:	0f b6 03             	movzbl (%ebx),%eax
f0104e60:	0f b6 12             	movzbl (%edx),%edx
f0104e63:	29 d0                	sub    %edx,%eax
}
f0104e65:	5b                   	pop    %ebx
f0104e66:	5e                   	pop    %esi
f0104e67:	5d                   	pop    %ebp
f0104e68:	c3                   	ret    

f0104e69 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f0104e69:	55                   	push   %ebp
f0104e6a:	89 e5                	mov    %esp,%ebp
f0104e6c:	53                   	push   %ebx
f0104e6d:	8b 45 08             	mov    0x8(%ebp),%eax
f0104e70:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0104e73:	0f b6 18             	movzbl (%eax),%ebx
f0104e76:	84 db                	test   %bl,%bl
f0104e78:	74 1d                	je     f0104e97 <strchr+0x2e>
f0104e7a:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0104e7c:	38 d3                	cmp    %dl,%bl
f0104e7e:	75 06                	jne    f0104e86 <strchr+0x1d>
f0104e80:	eb 1a                	jmp    f0104e9c <strchr+0x33>
f0104e82:	38 ca                	cmp    %cl,%dl
f0104e84:	74 16                	je     f0104e9c <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0104e86:	83 c0 01             	add    $0x1,%eax
f0104e89:	0f b6 10             	movzbl (%eax),%edx
f0104e8c:	84 d2                	test   %dl,%dl
f0104e8e:	75 f2                	jne    f0104e82 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0104e90:	b8 00 00 00 00       	mov    $0x0,%eax
f0104e95:	eb 05                	jmp    f0104e9c <strchr+0x33>
f0104e97:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0104e9c:	5b                   	pop    %ebx
f0104e9d:	5d                   	pop    %ebp
f0104e9e:	c3                   	ret    

f0104e9f <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f0104e9f:	55                   	push   %ebp
f0104ea0:	89 e5                	mov    %esp,%ebp
f0104ea2:	53                   	push   %ebx
f0104ea3:	8b 45 08             	mov    0x8(%ebp),%eax
f0104ea6:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0104ea9:	0f b6 18             	movzbl (%eax),%ebx
f0104eac:	84 db                	test   %bl,%bl
f0104eae:	74 16                	je     f0104ec6 <strfind+0x27>
f0104eb0:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0104eb2:	38 d3                	cmp    %dl,%bl
f0104eb4:	75 06                	jne    f0104ebc <strfind+0x1d>
f0104eb6:	eb 0e                	jmp    f0104ec6 <strfind+0x27>
f0104eb8:	38 ca                	cmp    %cl,%dl
f0104eba:	74 0a                	je     f0104ec6 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f0104ebc:	83 c0 01             	add    $0x1,%eax
f0104ebf:	0f b6 10             	movzbl (%eax),%edx
f0104ec2:	84 d2                	test   %dl,%dl
f0104ec4:	75 f2                	jne    f0104eb8 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f0104ec6:	5b                   	pop    %ebx
f0104ec7:	5d                   	pop    %ebp
f0104ec8:	c3                   	ret    

f0104ec9 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f0104ec9:	55                   	push   %ebp
f0104eca:	89 e5                	mov    %esp,%ebp
f0104ecc:	57                   	push   %edi
f0104ecd:	56                   	push   %esi
f0104ece:	53                   	push   %ebx
f0104ecf:	8b 7d 08             	mov    0x8(%ebp),%edi
f0104ed2:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0104ed5:	85 c9                	test   %ecx,%ecx
f0104ed7:	74 36                	je     f0104f0f <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f0104ed9:	f7 c7 03 00 00 00    	test   $0x3,%edi
f0104edf:	75 28                	jne    f0104f09 <memset+0x40>
f0104ee1:	f6 c1 03             	test   $0x3,%cl
f0104ee4:	75 23                	jne    f0104f09 <memset+0x40>
		c &= 0xFF;
f0104ee6:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f0104eea:	89 d3                	mov    %edx,%ebx
f0104eec:	c1 e3 08             	shl    $0x8,%ebx
f0104eef:	89 d6                	mov    %edx,%esi
f0104ef1:	c1 e6 18             	shl    $0x18,%esi
f0104ef4:	89 d0                	mov    %edx,%eax
f0104ef6:	c1 e0 10             	shl    $0x10,%eax
f0104ef9:	09 f0                	or     %esi,%eax
f0104efb:	09 c2                	or     %eax,%edx
f0104efd:	89 d0                	mov    %edx,%eax
f0104eff:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f0104f01:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0104f04:	fc                   	cld    
f0104f05:	f3 ab                	rep stos %eax,%es:(%edi)
f0104f07:	eb 06                	jmp    f0104f0f <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0104f09:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104f0c:	fc                   	cld    
f0104f0d:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f0104f0f:	89 f8                	mov    %edi,%eax
f0104f11:	5b                   	pop    %ebx
f0104f12:	5e                   	pop    %esi
f0104f13:	5f                   	pop    %edi
f0104f14:	5d                   	pop    %ebp
f0104f15:	c3                   	ret    

f0104f16 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0104f16:	55                   	push   %ebp
f0104f17:	89 e5                	mov    %esp,%ebp
f0104f19:	57                   	push   %edi
f0104f1a:	56                   	push   %esi
f0104f1b:	8b 45 08             	mov    0x8(%ebp),%eax
f0104f1e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104f21:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0104f24:	39 c6                	cmp    %eax,%esi
f0104f26:	73 35                	jae    f0104f5d <memmove+0x47>
f0104f28:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0104f2b:	39 d0                	cmp    %edx,%eax
f0104f2d:	73 2e                	jae    f0104f5d <memmove+0x47>
		s += n;
		d += n;
f0104f2f:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0104f32:	89 d6                	mov    %edx,%esi
f0104f34:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0104f36:	f7 c6 03 00 00 00    	test   $0x3,%esi
f0104f3c:	75 13                	jne    f0104f51 <memmove+0x3b>
f0104f3e:	f6 c1 03             	test   $0x3,%cl
f0104f41:	75 0e                	jne    f0104f51 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0104f43:	83 ef 04             	sub    $0x4,%edi
f0104f46:	8d 72 fc             	lea    -0x4(%edx),%esi
f0104f49:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f0104f4c:	fd                   	std    
f0104f4d:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0104f4f:	eb 09                	jmp    f0104f5a <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0104f51:	83 ef 01             	sub    $0x1,%edi
f0104f54:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0104f57:	fd                   	std    
f0104f58:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0104f5a:	fc                   	cld    
f0104f5b:	eb 1d                	jmp    f0104f7a <memmove+0x64>
f0104f5d:	89 f2                	mov    %esi,%edx
f0104f5f:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0104f61:	f6 c2 03             	test   $0x3,%dl
f0104f64:	75 0f                	jne    f0104f75 <memmove+0x5f>
f0104f66:	f6 c1 03             	test   $0x3,%cl
f0104f69:	75 0a                	jne    f0104f75 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0104f6b:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f0104f6e:	89 c7                	mov    %eax,%edi
f0104f70:	fc                   	cld    
f0104f71:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0104f73:	eb 05                	jmp    f0104f7a <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0104f75:	89 c7                	mov    %eax,%edi
f0104f77:	fc                   	cld    
f0104f78:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f0104f7a:	5e                   	pop    %esi
f0104f7b:	5f                   	pop    %edi
f0104f7c:	5d                   	pop    %ebp
f0104f7d:	c3                   	ret    

f0104f7e <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f0104f7e:	55                   	push   %ebp
f0104f7f:	89 e5                	mov    %esp,%ebp
f0104f81:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0104f84:	8b 45 10             	mov    0x10(%ebp),%eax
f0104f87:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104f8b:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104f8e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104f92:	8b 45 08             	mov    0x8(%ebp),%eax
f0104f95:	89 04 24             	mov    %eax,(%esp)
f0104f98:	e8 79 ff ff ff       	call   f0104f16 <memmove>
}
f0104f9d:	c9                   	leave  
f0104f9e:	c3                   	ret    

f0104f9f <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f0104f9f:	55                   	push   %ebp
f0104fa0:	89 e5                	mov    %esp,%ebp
f0104fa2:	57                   	push   %edi
f0104fa3:	56                   	push   %esi
f0104fa4:	53                   	push   %ebx
f0104fa5:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0104fa8:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104fab:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0104fae:	8d 78 ff             	lea    -0x1(%eax),%edi
f0104fb1:	85 c0                	test   %eax,%eax
f0104fb3:	74 36                	je     f0104feb <memcmp+0x4c>
		if (*s1 != *s2)
f0104fb5:	0f b6 03             	movzbl (%ebx),%eax
f0104fb8:	0f b6 0e             	movzbl (%esi),%ecx
f0104fbb:	ba 00 00 00 00       	mov    $0x0,%edx
f0104fc0:	38 c8                	cmp    %cl,%al
f0104fc2:	74 1c                	je     f0104fe0 <memcmp+0x41>
f0104fc4:	eb 10                	jmp    f0104fd6 <memcmp+0x37>
f0104fc6:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f0104fcb:	83 c2 01             	add    $0x1,%edx
f0104fce:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f0104fd2:	38 c8                	cmp    %cl,%al
f0104fd4:	74 0a                	je     f0104fe0 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f0104fd6:	0f b6 c0             	movzbl %al,%eax
f0104fd9:	0f b6 c9             	movzbl %cl,%ecx
f0104fdc:	29 c8                	sub    %ecx,%eax
f0104fde:	eb 10                	jmp    f0104ff0 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0104fe0:	39 fa                	cmp    %edi,%edx
f0104fe2:	75 e2                	jne    f0104fc6 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f0104fe4:	b8 00 00 00 00       	mov    $0x0,%eax
f0104fe9:	eb 05                	jmp    f0104ff0 <memcmp+0x51>
f0104feb:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0104ff0:	5b                   	pop    %ebx
f0104ff1:	5e                   	pop    %esi
f0104ff2:	5f                   	pop    %edi
f0104ff3:	5d                   	pop    %ebp
f0104ff4:	c3                   	ret    

f0104ff5 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0104ff5:	55                   	push   %ebp
f0104ff6:	89 e5                	mov    %esp,%ebp
f0104ff8:	53                   	push   %ebx
f0104ff9:	8b 45 08             	mov    0x8(%ebp),%eax
f0104ffc:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f0104fff:	89 c2                	mov    %eax,%edx
f0105001:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0105004:	39 d0                	cmp    %edx,%eax
f0105006:	73 13                	jae    f010501b <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f0105008:	89 d9                	mov    %ebx,%ecx
f010500a:	38 18                	cmp    %bl,(%eax)
f010500c:	75 06                	jne    f0105014 <memfind+0x1f>
f010500e:	eb 0b                	jmp    f010501b <memfind+0x26>
f0105010:	38 08                	cmp    %cl,(%eax)
f0105012:	74 07                	je     f010501b <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f0105014:	83 c0 01             	add    $0x1,%eax
f0105017:	39 d0                	cmp    %edx,%eax
f0105019:	75 f5                	jne    f0105010 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f010501b:	5b                   	pop    %ebx
f010501c:	5d                   	pop    %ebp
f010501d:	c3                   	ret    

f010501e <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f010501e:	55                   	push   %ebp
f010501f:	89 e5                	mov    %esp,%ebp
f0105021:	57                   	push   %edi
f0105022:	56                   	push   %esi
f0105023:	53                   	push   %ebx
f0105024:	8b 55 08             	mov    0x8(%ebp),%edx
f0105027:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010502a:	0f b6 0a             	movzbl (%edx),%ecx
f010502d:	80 f9 09             	cmp    $0x9,%cl
f0105030:	74 05                	je     f0105037 <strtol+0x19>
f0105032:	80 f9 20             	cmp    $0x20,%cl
f0105035:	75 10                	jne    f0105047 <strtol+0x29>
		s++;
f0105037:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f010503a:	0f b6 0a             	movzbl (%edx),%ecx
f010503d:	80 f9 09             	cmp    $0x9,%cl
f0105040:	74 f5                	je     f0105037 <strtol+0x19>
f0105042:	80 f9 20             	cmp    $0x20,%cl
f0105045:	74 f0                	je     f0105037 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f0105047:	80 f9 2b             	cmp    $0x2b,%cl
f010504a:	75 0a                	jne    f0105056 <strtol+0x38>
		s++;
f010504c:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f010504f:	bf 00 00 00 00       	mov    $0x0,%edi
f0105054:	eb 11                	jmp    f0105067 <strtol+0x49>
f0105056:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f010505b:	80 f9 2d             	cmp    $0x2d,%cl
f010505e:	75 07                	jne    f0105067 <strtol+0x49>
		s++, neg = 1;
f0105060:	83 c2 01             	add    $0x1,%edx
f0105063:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0105067:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f010506c:	75 15                	jne    f0105083 <strtol+0x65>
f010506e:	80 3a 30             	cmpb   $0x30,(%edx)
f0105071:	75 10                	jne    f0105083 <strtol+0x65>
f0105073:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0105077:	75 0a                	jne    f0105083 <strtol+0x65>
		s += 2, base = 16;
f0105079:	83 c2 02             	add    $0x2,%edx
f010507c:	b8 10 00 00 00       	mov    $0x10,%eax
f0105081:	eb 10                	jmp    f0105093 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f0105083:	85 c0                	test   %eax,%eax
f0105085:	75 0c                	jne    f0105093 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0105087:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0105089:	80 3a 30             	cmpb   $0x30,(%edx)
f010508c:	75 05                	jne    f0105093 <strtol+0x75>
		s++, base = 8;
f010508e:	83 c2 01             	add    $0x1,%edx
f0105091:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f0105093:	bb 00 00 00 00       	mov    $0x0,%ebx
f0105098:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f010509b:	0f b6 0a             	movzbl (%edx),%ecx
f010509e:	8d 71 d0             	lea    -0x30(%ecx),%esi
f01050a1:	89 f0                	mov    %esi,%eax
f01050a3:	3c 09                	cmp    $0x9,%al
f01050a5:	77 08                	ja     f01050af <strtol+0x91>
			dig = *s - '0';
f01050a7:	0f be c9             	movsbl %cl,%ecx
f01050aa:	83 e9 30             	sub    $0x30,%ecx
f01050ad:	eb 20                	jmp    f01050cf <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f01050af:	8d 71 9f             	lea    -0x61(%ecx),%esi
f01050b2:	89 f0                	mov    %esi,%eax
f01050b4:	3c 19                	cmp    $0x19,%al
f01050b6:	77 08                	ja     f01050c0 <strtol+0xa2>
			dig = *s - 'a' + 10;
f01050b8:	0f be c9             	movsbl %cl,%ecx
f01050bb:	83 e9 57             	sub    $0x57,%ecx
f01050be:	eb 0f                	jmp    f01050cf <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f01050c0:	8d 71 bf             	lea    -0x41(%ecx),%esi
f01050c3:	89 f0                	mov    %esi,%eax
f01050c5:	3c 19                	cmp    $0x19,%al
f01050c7:	77 16                	ja     f01050df <strtol+0xc1>
			dig = *s - 'A' + 10;
f01050c9:	0f be c9             	movsbl %cl,%ecx
f01050cc:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f01050cf:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f01050d2:	7d 0f                	jge    f01050e3 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f01050d4:	83 c2 01             	add    $0x1,%edx
f01050d7:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f01050db:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f01050dd:	eb bc                	jmp    f010509b <strtol+0x7d>
f01050df:	89 d8                	mov    %ebx,%eax
f01050e1:	eb 02                	jmp    f01050e5 <strtol+0xc7>
f01050e3:	89 d8                	mov    %ebx,%eax

	if (endptr)
f01050e5:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f01050e9:	74 05                	je     f01050f0 <strtol+0xd2>
		*endptr = (char *) s;
f01050eb:	8b 75 0c             	mov    0xc(%ebp),%esi
f01050ee:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f01050f0:	f7 d8                	neg    %eax
f01050f2:	85 ff                	test   %edi,%edi
f01050f4:	0f 44 c3             	cmove  %ebx,%eax
}
f01050f7:	5b                   	pop    %ebx
f01050f8:	5e                   	pop    %esi
f01050f9:	5f                   	pop    %edi
f01050fa:	5d                   	pop    %ebp
f01050fb:	c3                   	ret    
f01050fc:	66 90                	xchg   %ax,%ax
f01050fe:	66 90                	xchg   %ax,%ax

f0105100 <__udivdi3>:
f0105100:	55                   	push   %ebp
f0105101:	57                   	push   %edi
f0105102:	56                   	push   %esi
f0105103:	83 ec 0c             	sub    $0xc,%esp
f0105106:	8b 44 24 28          	mov    0x28(%esp),%eax
f010510a:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f010510e:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f0105112:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0105116:	85 c0                	test   %eax,%eax
f0105118:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010511c:	89 ea                	mov    %ebp,%edx
f010511e:	89 0c 24             	mov    %ecx,(%esp)
f0105121:	75 2d                	jne    f0105150 <__udivdi3+0x50>
f0105123:	39 e9                	cmp    %ebp,%ecx
f0105125:	77 61                	ja     f0105188 <__udivdi3+0x88>
f0105127:	85 c9                	test   %ecx,%ecx
f0105129:	89 ce                	mov    %ecx,%esi
f010512b:	75 0b                	jne    f0105138 <__udivdi3+0x38>
f010512d:	b8 01 00 00 00       	mov    $0x1,%eax
f0105132:	31 d2                	xor    %edx,%edx
f0105134:	f7 f1                	div    %ecx
f0105136:	89 c6                	mov    %eax,%esi
f0105138:	31 d2                	xor    %edx,%edx
f010513a:	89 e8                	mov    %ebp,%eax
f010513c:	f7 f6                	div    %esi
f010513e:	89 c5                	mov    %eax,%ebp
f0105140:	89 f8                	mov    %edi,%eax
f0105142:	f7 f6                	div    %esi
f0105144:	89 ea                	mov    %ebp,%edx
f0105146:	83 c4 0c             	add    $0xc,%esp
f0105149:	5e                   	pop    %esi
f010514a:	5f                   	pop    %edi
f010514b:	5d                   	pop    %ebp
f010514c:	c3                   	ret    
f010514d:	8d 76 00             	lea    0x0(%esi),%esi
f0105150:	39 e8                	cmp    %ebp,%eax
f0105152:	77 24                	ja     f0105178 <__udivdi3+0x78>
f0105154:	0f bd e8             	bsr    %eax,%ebp
f0105157:	83 f5 1f             	xor    $0x1f,%ebp
f010515a:	75 3c                	jne    f0105198 <__udivdi3+0x98>
f010515c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0105160:	39 34 24             	cmp    %esi,(%esp)
f0105163:	0f 86 9f 00 00 00    	jbe    f0105208 <__udivdi3+0x108>
f0105169:	39 d0                	cmp    %edx,%eax
f010516b:	0f 82 97 00 00 00    	jb     f0105208 <__udivdi3+0x108>
f0105171:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0105178:	31 d2                	xor    %edx,%edx
f010517a:	31 c0                	xor    %eax,%eax
f010517c:	83 c4 0c             	add    $0xc,%esp
f010517f:	5e                   	pop    %esi
f0105180:	5f                   	pop    %edi
f0105181:	5d                   	pop    %ebp
f0105182:	c3                   	ret    
f0105183:	90                   	nop
f0105184:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0105188:	89 f8                	mov    %edi,%eax
f010518a:	f7 f1                	div    %ecx
f010518c:	31 d2                	xor    %edx,%edx
f010518e:	83 c4 0c             	add    $0xc,%esp
f0105191:	5e                   	pop    %esi
f0105192:	5f                   	pop    %edi
f0105193:	5d                   	pop    %ebp
f0105194:	c3                   	ret    
f0105195:	8d 76 00             	lea    0x0(%esi),%esi
f0105198:	89 e9                	mov    %ebp,%ecx
f010519a:	8b 3c 24             	mov    (%esp),%edi
f010519d:	d3 e0                	shl    %cl,%eax
f010519f:	89 c6                	mov    %eax,%esi
f01051a1:	b8 20 00 00 00       	mov    $0x20,%eax
f01051a6:	29 e8                	sub    %ebp,%eax
f01051a8:	89 c1                	mov    %eax,%ecx
f01051aa:	d3 ef                	shr    %cl,%edi
f01051ac:	89 e9                	mov    %ebp,%ecx
f01051ae:	89 7c 24 08          	mov    %edi,0x8(%esp)
f01051b2:	8b 3c 24             	mov    (%esp),%edi
f01051b5:	09 74 24 08          	or     %esi,0x8(%esp)
f01051b9:	89 d6                	mov    %edx,%esi
f01051bb:	d3 e7                	shl    %cl,%edi
f01051bd:	89 c1                	mov    %eax,%ecx
f01051bf:	89 3c 24             	mov    %edi,(%esp)
f01051c2:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01051c6:	d3 ee                	shr    %cl,%esi
f01051c8:	89 e9                	mov    %ebp,%ecx
f01051ca:	d3 e2                	shl    %cl,%edx
f01051cc:	89 c1                	mov    %eax,%ecx
f01051ce:	d3 ef                	shr    %cl,%edi
f01051d0:	09 d7                	or     %edx,%edi
f01051d2:	89 f2                	mov    %esi,%edx
f01051d4:	89 f8                	mov    %edi,%eax
f01051d6:	f7 74 24 08          	divl   0x8(%esp)
f01051da:	89 d6                	mov    %edx,%esi
f01051dc:	89 c7                	mov    %eax,%edi
f01051de:	f7 24 24             	mull   (%esp)
f01051e1:	39 d6                	cmp    %edx,%esi
f01051e3:	89 14 24             	mov    %edx,(%esp)
f01051e6:	72 30                	jb     f0105218 <__udivdi3+0x118>
f01051e8:	8b 54 24 04          	mov    0x4(%esp),%edx
f01051ec:	89 e9                	mov    %ebp,%ecx
f01051ee:	d3 e2                	shl    %cl,%edx
f01051f0:	39 c2                	cmp    %eax,%edx
f01051f2:	73 05                	jae    f01051f9 <__udivdi3+0xf9>
f01051f4:	3b 34 24             	cmp    (%esp),%esi
f01051f7:	74 1f                	je     f0105218 <__udivdi3+0x118>
f01051f9:	89 f8                	mov    %edi,%eax
f01051fb:	31 d2                	xor    %edx,%edx
f01051fd:	e9 7a ff ff ff       	jmp    f010517c <__udivdi3+0x7c>
f0105202:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0105208:	31 d2                	xor    %edx,%edx
f010520a:	b8 01 00 00 00       	mov    $0x1,%eax
f010520f:	e9 68 ff ff ff       	jmp    f010517c <__udivdi3+0x7c>
f0105214:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0105218:	8d 47 ff             	lea    -0x1(%edi),%eax
f010521b:	31 d2                	xor    %edx,%edx
f010521d:	83 c4 0c             	add    $0xc,%esp
f0105220:	5e                   	pop    %esi
f0105221:	5f                   	pop    %edi
f0105222:	5d                   	pop    %ebp
f0105223:	c3                   	ret    
f0105224:	66 90                	xchg   %ax,%ax
f0105226:	66 90                	xchg   %ax,%ax
f0105228:	66 90                	xchg   %ax,%ax
f010522a:	66 90                	xchg   %ax,%ax
f010522c:	66 90                	xchg   %ax,%ax
f010522e:	66 90                	xchg   %ax,%ax

f0105230 <__umoddi3>:
f0105230:	55                   	push   %ebp
f0105231:	57                   	push   %edi
f0105232:	56                   	push   %esi
f0105233:	83 ec 14             	sub    $0x14,%esp
f0105236:	8b 44 24 28          	mov    0x28(%esp),%eax
f010523a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f010523e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0105242:	89 c7                	mov    %eax,%edi
f0105244:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105248:	8b 44 24 30          	mov    0x30(%esp),%eax
f010524c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0105250:	89 34 24             	mov    %esi,(%esp)
f0105253:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0105257:	85 c0                	test   %eax,%eax
f0105259:	89 c2                	mov    %eax,%edx
f010525b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f010525f:	75 17                	jne    f0105278 <__umoddi3+0x48>
f0105261:	39 fe                	cmp    %edi,%esi
f0105263:	76 4b                	jbe    f01052b0 <__umoddi3+0x80>
f0105265:	89 c8                	mov    %ecx,%eax
f0105267:	89 fa                	mov    %edi,%edx
f0105269:	f7 f6                	div    %esi
f010526b:	89 d0                	mov    %edx,%eax
f010526d:	31 d2                	xor    %edx,%edx
f010526f:	83 c4 14             	add    $0x14,%esp
f0105272:	5e                   	pop    %esi
f0105273:	5f                   	pop    %edi
f0105274:	5d                   	pop    %ebp
f0105275:	c3                   	ret    
f0105276:	66 90                	xchg   %ax,%ax
f0105278:	39 f8                	cmp    %edi,%eax
f010527a:	77 54                	ja     f01052d0 <__umoddi3+0xa0>
f010527c:	0f bd e8             	bsr    %eax,%ebp
f010527f:	83 f5 1f             	xor    $0x1f,%ebp
f0105282:	75 5c                	jne    f01052e0 <__umoddi3+0xb0>
f0105284:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0105288:	39 3c 24             	cmp    %edi,(%esp)
f010528b:	0f 87 e7 00 00 00    	ja     f0105378 <__umoddi3+0x148>
f0105291:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0105295:	29 f1                	sub    %esi,%ecx
f0105297:	19 c7                	sbb    %eax,%edi
f0105299:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f010529d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01052a1:	8b 44 24 08          	mov    0x8(%esp),%eax
f01052a5:	8b 54 24 0c          	mov    0xc(%esp),%edx
f01052a9:	83 c4 14             	add    $0x14,%esp
f01052ac:	5e                   	pop    %esi
f01052ad:	5f                   	pop    %edi
f01052ae:	5d                   	pop    %ebp
f01052af:	c3                   	ret    
f01052b0:	85 f6                	test   %esi,%esi
f01052b2:	89 f5                	mov    %esi,%ebp
f01052b4:	75 0b                	jne    f01052c1 <__umoddi3+0x91>
f01052b6:	b8 01 00 00 00       	mov    $0x1,%eax
f01052bb:	31 d2                	xor    %edx,%edx
f01052bd:	f7 f6                	div    %esi
f01052bf:	89 c5                	mov    %eax,%ebp
f01052c1:	8b 44 24 04          	mov    0x4(%esp),%eax
f01052c5:	31 d2                	xor    %edx,%edx
f01052c7:	f7 f5                	div    %ebp
f01052c9:	89 c8                	mov    %ecx,%eax
f01052cb:	f7 f5                	div    %ebp
f01052cd:	eb 9c                	jmp    f010526b <__umoddi3+0x3b>
f01052cf:	90                   	nop
f01052d0:	89 c8                	mov    %ecx,%eax
f01052d2:	89 fa                	mov    %edi,%edx
f01052d4:	83 c4 14             	add    $0x14,%esp
f01052d7:	5e                   	pop    %esi
f01052d8:	5f                   	pop    %edi
f01052d9:	5d                   	pop    %ebp
f01052da:	c3                   	ret    
f01052db:	90                   	nop
f01052dc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01052e0:	8b 04 24             	mov    (%esp),%eax
f01052e3:	be 20 00 00 00       	mov    $0x20,%esi
f01052e8:	89 e9                	mov    %ebp,%ecx
f01052ea:	29 ee                	sub    %ebp,%esi
f01052ec:	d3 e2                	shl    %cl,%edx
f01052ee:	89 f1                	mov    %esi,%ecx
f01052f0:	d3 e8                	shr    %cl,%eax
f01052f2:	89 e9                	mov    %ebp,%ecx
f01052f4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01052f8:	8b 04 24             	mov    (%esp),%eax
f01052fb:	09 54 24 04          	or     %edx,0x4(%esp)
f01052ff:	89 fa                	mov    %edi,%edx
f0105301:	d3 e0                	shl    %cl,%eax
f0105303:	89 f1                	mov    %esi,%ecx
f0105305:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105309:	8b 44 24 10          	mov    0x10(%esp),%eax
f010530d:	d3 ea                	shr    %cl,%edx
f010530f:	89 e9                	mov    %ebp,%ecx
f0105311:	d3 e7                	shl    %cl,%edi
f0105313:	89 f1                	mov    %esi,%ecx
f0105315:	d3 e8                	shr    %cl,%eax
f0105317:	89 e9                	mov    %ebp,%ecx
f0105319:	09 f8                	or     %edi,%eax
f010531b:	8b 7c 24 10          	mov    0x10(%esp),%edi
f010531f:	f7 74 24 04          	divl   0x4(%esp)
f0105323:	d3 e7                	shl    %cl,%edi
f0105325:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0105329:	89 d7                	mov    %edx,%edi
f010532b:	f7 64 24 08          	mull   0x8(%esp)
f010532f:	39 d7                	cmp    %edx,%edi
f0105331:	89 c1                	mov    %eax,%ecx
f0105333:	89 14 24             	mov    %edx,(%esp)
f0105336:	72 2c                	jb     f0105364 <__umoddi3+0x134>
f0105338:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f010533c:	72 22                	jb     f0105360 <__umoddi3+0x130>
f010533e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0105342:	29 c8                	sub    %ecx,%eax
f0105344:	19 d7                	sbb    %edx,%edi
f0105346:	89 e9                	mov    %ebp,%ecx
f0105348:	89 fa                	mov    %edi,%edx
f010534a:	d3 e8                	shr    %cl,%eax
f010534c:	89 f1                	mov    %esi,%ecx
f010534e:	d3 e2                	shl    %cl,%edx
f0105350:	89 e9                	mov    %ebp,%ecx
f0105352:	d3 ef                	shr    %cl,%edi
f0105354:	09 d0                	or     %edx,%eax
f0105356:	89 fa                	mov    %edi,%edx
f0105358:	83 c4 14             	add    $0x14,%esp
f010535b:	5e                   	pop    %esi
f010535c:	5f                   	pop    %edi
f010535d:	5d                   	pop    %ebp
f010535e:	c3                   	ret    
f010535f:	90                   	nop
f0105360:	39 d7                	cmp    %edx,%edi
f0105362:	75 da                	jne    f010533e <__umoddi3+0x10e>
f0105364:	8b 14 24             	mov    (%esp),%edx
f0105367:	89 c1                	mov    %eax,%ecx
f0105369:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f010536d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0105371:	eb cb                	jmp    f010533e <__umoddi3+0x10e>
f0105373:	90                   	nop
f0105374:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0105378:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f010537c:	0f 82 0f ff ff ff    	jb     f0105291 <__umoddi3+0x61>
f0105382:	e9 1a ff ff ff       	jmp    f01052a1 <__umoddi3+0x71>
