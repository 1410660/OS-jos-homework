#操作系统第二次大作业
## 代码链接 
### [lab3](https://github.com/stoneboat/OS-jos-homework/tree/lab3)
## 小组介绍
### 小组成员
信安 卫煜  1410657   信安 郭晓杰  1410644  信安 杨旭东  1410658
### 分工及比例
卫煜  书面问题1 上机作业3  上机作业4                       比例30% <br>
郭晓杰          上机作业1  上机作业2                       比例30%  <br>
杨旭东 书面问题2  上机作业5 上机作业6 上机作业7 上机作业8  比例40%<br>
## 书面作业目录
[书面问题1](#problem1) <br>
[书面问题2](#problem2)  <br>
<span id="catalog"></span>
## 上机作业目录
[上机作业1](#work1) <br>
[上机作业2](#work2)  <br>
[上机作业3](#work3) <br>
[上机作业4](#work4) <br>
[上机作业5](#work5) <br>
[上机作业6](#work6) <br>
[上机作业7](#work7) <br>
[上机作业8](#work8) <br>
[上机作业9](#work9) <br>
---
<span id="problem1"></span>
## 1.1
首先中断和异常的概念不同，所以不能用相同的程序处理。中断(interupt)是处理器相应外设同步事件触发的陷入内核的动作，异常(trap,fault,abort)是处理器在处理指令时检测自身发现指令不能执行。
其次中断和异常触发权限不同，有些用户可以触发，但是有些只有内核可以触发，所以处理不同的终端或异常之前，需要具有不同特点的程序处理。
最后也是最重要的，不同的异常和中断执行的实体响应动作不同，比如断点异常需要陷入内核检测器观察，而缺页异常则需要查看是否需要分配新的页和检测故障原因。
## 1.2
因为缺页异常只有内核可以触发，如果设置权限为该异常用户也可以触发，从根本上讲，用户可以不断产生缺页异常然后申请新的物理页，内核丧失对资源的绝对掌握权，整个资源分配系统被颠覆。从程序实现上来讲，缺页异常的处理程序是由TRAPHANDLER宏生成的，其需要压入错误码，这个用户在调用时没有办法提供，直接会使栈的参数读取出错，进而造成栈错误，系统崩溃。
### 跳回目录 [目录](#catalog)
---
<span id="problem2"></span>
##2.1
设置断点中断描述符表IDT的DPL为3即可让用户直接调用，一般为断点调试，允许用户态直接使用int指令访问；而0一般为硬件中断或者CPU异常，不允许用户态直接使用int指令访问。<br>
DPL参考Linux一些信息，将breakpoint,overflow,以及system call设置为3。
##2.2
这些机制的目的是保护操作系统，防止了恶意程序或者有bug的程序任意调用指令，因为硬件级别并不能提供这种保护机制，所以要操作系统自己来实现这种保护。
### 跳回目录 [目录](#catalog)
<span id="work1"></span>
## 上机作业问题1
这里的代码是为了创建可分配的用户环境数组envs[]，并调整page_init()对空闲物理页框的初始化，并将envs[]映射到虚拟地址UENV上
### 添加代码内容
#### 创建用户环境数组envs[] 
```c
envs = (struct Env *)boot_alloc(NENV * sizeof(struct Env));
```
>kern\pmap.c

#### 修改page_init()函数，将envs[]数组对应的物理页框从page_free_list上去掉
```c
//remove continuous pages from page_free_list
extern char end[];
struct Page *ppg_start = pa2page((physaddr_t)IOPHYSMEM);
struct Page *ppg_end = pa2page((physaddr_t)((end - KERNBASE) + PGSIZE + sizeof(struct Page)*npages + sizeof(struct Env)*NENV));
ppg_start--;    ppg_end++;
ppg_end->pp_link = ppg_start;
```
>kern\pmap.c

#### 将envs[]映射到虚拟地址UENV上
```c
for (i = 0; i < ROUNDUP(NENV*sizeof(struct Env), PGSIZE); i += PGSIZE)
        page_insert(kern_pgdir, pa2page(PADDR(envs) + i), (void *)(UENVS + i), PTE_U);
```
>kern\pmap.c

### 代码说明
此处使用和lab2中创建pages[]数组一样的方法为envs[]数组分配相应的空间，由于为envs[]数组分配的空间对应的物理页框不能作为空闲物理页框进行分配，所以需要修改page_init()函数把这部分页框也从page_free_list上拆下来。这之后还需要用page_insert()函数建立envs[]数组到UENV的映射。

### 测试效果
由于此处的代码不能独立运行，所以此处代码的效果可以在后续代码的运行结果中进行检验。

### 跳回目录 [目录](#catalog)
---
<span id="work2"></span>
## 上机作业问题2
这里的代码是为了完成和用户环境初始化和运行的一系列函数。
### 添加代码内容
#### 实现env_init()函数
```c
void env_init(void)
{
    // Set up envs array
    // LAB 3: Your code here.
    env_free_list = envs;
    
    size_t i = 0;
    for (; i < NENV - 1; i++) {
        envs[i].env_id = 0;
        envs[i].env_link = &envs[i + 1];
    }
    envs[i].env_id = 0;
    envs[i].env_link = NULL;

    // Per-CPU part of the initialization
    env_init_percpu();
}
```
>kern\env.c

#### 实现env_setup_vm()函数
```c
static int env_setup_vm(struct Env *e)
{
    int i;
    struct Page *p = NULL;

    // Allocate a page for the page directory
    if (!(p = page_alloc(ALLOC_ZERO)))
        return -E_NO_MEM;

    e->env_pgdir = page2kva(p);
    for (i = PDX(UTOP); i < 1024; i++) {
        e->env_pgdir[i] = kern_pgdir[i];        //data above UTOP(UENV) is shared and identical
    }
    p->pp_ref++;

    // UVPT maps the env's own page table read-only.
    // Permissions: kernel R, user R
    e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;

    return 0;
}
```
>kern\env.c

#### 实现region_alloc()函数
```c
static void region_alloc(struct Env *e, void *va, size_t len)
{
    for (size_t i = ROUNDDOWN((uint32_t)va, PGSIZE); i < ROUNDUP((uint32_t)(va + len), PGSIZE); i += PGSIZE) {
        struct Page *page = (struct Page*)page_alloc(1);
        if (page == NULL)
            panic("ran out of memory!");
        
        page_insert(e->env_pgdir, page, i, PTE_W | PTE_U);
    }
}
```
>kern\env.c

#### 实现load_icode()函数
```c
static void load_icode(struct Env *e, uint8_t *binary, size_t size)
{
    lcr3(PADDR(e->env_pgdir));
    struct Elf *ELFHDR = (struct Elf *)binary;
    if (ELFHDR->e_magic != ELF_MAGIC)
        panic("invalid ELF format!");
    
    struct Proghdr *ph, *eph;
    ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
    eph = ph + ELFHDR->e_phnum;
    for (; ph < eph; ph++) {
        if (ph->p_type == ELF_PROG_LOAD) {
            region_alloc(e, (void *)(ph->p_va), ph->p_memsz);
            
            if (ph->p_filesz > ph->p_memsz)
                panic("invalid ELF header!");
                
            char *va = (char *)(ph->p_va);
            for (size_t i = 0; i < ph->p_filesz; i++)
                va[i] = binary[ph->p_offset + i];
        }
    }
    e->env_tf.tf_eip = ELFHDR->e_entry;

    struct Page *page = page_alloc(1);
    if (page == NULL)
        panic("ran out of memory!");
        
    page_insert(e->env_pgdir, page, (void *)(USTACKTOP - PGSIZE), PTE_W | PTE_U);
    lcr3(PADDR(kern_pgdir));
}
```
>kern\env.c

#### 实现env_create()函数
```c
void env_create(uint8_t *binary, size_t size, enum EnvType type)
{
    struct Env *env;
    if (env_alloc(&env, 0) < 0)
        panic("environment alloc failed!");
        
    env->env_type = type;   
    load_icode(env, binary, size);
}
```
>kern\env.c

#### 实现env_run()函数
```c
void
env_run(struct Env *e)
{
    if (curenv != NULL && curenv->env_status == ENV_RUNNING)
        curenv->env_status = ENV_RUNNABLE;
        
    curenv = e;
    e->env_status = ENV_RUNNING;
    e->env_runs++;
    lcr3(PADDR(e->env_pgdir));
    env_pop_tf(&(e->env_tf));

    //panic("env_run not yet implemented");
}
```
>kern\env.c

### 代码说明
这部分的代码是实现和用户环境初始化相关的函数，而各函数的功能描述如下
#### env_init()
该函数负责将pmap.c中创建的envs[]数组串接到env_free_list上，然后调用env_init_percpu()进行各段寄存器的初始化。
#### env_setup_vm()
该函数负责为用户环境e分配其页目录所需的物理页框。因为在UTOP之上的内核部分的页目录表项是共享的，所以将内核页目录的相应部分拷贝到环境页目录的相应部分，然后设置用户环境的页目录表中UVPT对应项的权限。
#### region_alloc()
该函数负责为用户环境e分配以页为单位的物理内存（实际上是物理页框）,然后将分配的物理页框用page_insert()映射到该环境e中的虚拟地址va上。
#### load_icode()
该函数负责解析binary指针指向的ELF文件，并利用ELF头中的相应信息，把该ELF文件的各程序段读入到相应Proghdr结构指向的虚拟地址。拷贝完成后，需要将该环境e下的eip寄存器设置为ELF头指定的入口地址，让CPU取该地址的指令执行。eip设置完成后，还需要分配一个物理页框供用户环境作为初始栈使用，并把该页映射到USTACKTOP - PGSISE处。
#### env_create()
该函数负责调用env_alloc()函数从env_free_list上分配一个空闲的env块，然后设置相应的环境类型，最后用load_icode()向该环境中载入binary指针指向的ELF文件。值得注意的是，该函数只在内核初始化时被调用。
#### env_run()
该函数负责用户环境之间的切换。具体来说，该函数将当前环境curenv切换成指定的用户环境e，如果原先有正在运行的用户环境则将其挂起，然后将新的用户环境设置为当前环境，并增加该环境的调用次数。最后负责将页目录切换为当前环境的页目录，并恢复该环境的相应寄存器。
### 效果测试
由于此处的代码不能独立运行，所以此处代码的效果可以在后续代码的运行结果中进行检验。
### 跳回目录 [目录](#catalog)
---
<span id="work3"></span>
## 上机作业问题3  
这里的代码是为了生成和配置处理各种基本异常和中断的函数，并在idt中注册他们。
### 添加代码内容  
#### 声明异常和中断函数 
```c
void dividezero_handler();
void nmi_handler();
void breakpoint_handler();
void overflow_handler();
void bdrgeexceed_handler();
void invalidop_handler();
void nomathcopro_handler();
void dbfault_handler();
void invalidTSS_handler();
void sgmtnotpresent_handler();
void stacksgmtfault_handler();
void pagefault_handler();
void generalprotection_handler();
void FPUerror_handler();
void alignmentcheck_handler();
void machinecheck_handler();
void SIMDFPexception_handler();
void systemcall_handler();
```
>kern\trap.c
#### 利用宏TRAPHANDLER，TRAPHANDLER_NOEC来生成以上基本异常和中断的函数入口
```c
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
TRAPHANDLER_NOEC(nmi_handler, 0x2)
TRAPHANDLER_NOEC(breakpoint_handler, 0x3)
TRAPHANDLER_NOEC(overflow_handler, 0x4)
TRAPHANDLER_NOEC(bdrgeexceed_handler, 0x5)
TRAPHANDLER_NOEC(invalidop_handler, 0x6)
TRAPHANDLER_NOEC(nomathcopro_handler, 0x7)
TRAPHANDLER(dbfault_handler, 0x8)
TRAPHANDLER(invalidTSS_handler, 0xA)
TRAPHANDLER(sgmtnotpresent_handler, 0xB)
TRAPHANDLER(stacksgmtfault_handler,0xC)
TRAPHANDLER(generalprotection_handler, 0xD)
TRAPHANDLER(pagefault_handler, 0xE)
TRAPHANDLER_NOEC(FPUerror_handler, 0x10)
TRAPHANDLER(alignmentcheck_handler, 0x11)
TRAPHANDLER_NOEC(machinecheck_handler, 0x12)
TRAPHANDLER_NOEC(SIMDFPexception_handler, 0x13)
TRAPHANDLER_NOEC(systemcall_handler, 0x30)
```
>kern\trapentry.S
#### 完成_alltraps代码段，实现完整的以上异常和中断函数的引导
```asm
    pushw $0
    pushw %ds
    pushw $0
    pushw %es
    pushal
    pushl %esp
    movw $(GD_KD),%ax
    movw %ax,%ds
    movw %ax,%es
    call trap
```
>kern\trapentry.S
#### 利用setegate宏在idt中注册这些异常处理函数
```c
    SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);
    SETGATE(idt[2], 0, GD_KT, nmi_handler, 0);
    SETGATE(idt[3], 1, GD_KT, breakpoint_handler, 3);
    SETGATE(idt[4], 1, GD_KT, overflow_handler, 3);
    SETGATE(idt[5], 1, GD_KT, bdrgeexceed_handler, 3);
    SETGATE(idt[6], 1, GD_KT, invalidop_handler, 0);
    SETGATE(idt[7], 1, GD_KT, nomathcopro_handler, 0);
    SETGATE(idt[8], 1, GD_KT, dbfault_handler, 0);
    SETGATE(idt[10], 1, GD_KT, invalidTSS_handler, 0);
    SETGATE(idt[11], 1, GD_KT, sgmtnotpresent_handler, 0);
    SETGATE(idt[12], 1, GD_KT, stacksgmtfault_handler, 0);
    SETGATE(idt[14], 1, GD_KT, pagefault_handler, 0);
    SETGATE(idt[13], 1, GD_KT, generalprotection_handler, 0);
    SETGATE(idt[16], 1, GD_KT, FPUerror_handler, 0);
    SETGATE(idt[17], 1, GD_KT, alignmentcheck_handler, 0);
    SETGATE(idt[18],1, GD_KT, machinecheck_handler, 0);
    SETGATE(idt[19], 1, GD_KT, SIMDFPexception_handler, 0);
    SETGATE(idt[48], 0, GD_KT, systemcall_handler, 3);
```
### 代码说明      
下面以一个完整的零异常来说明整个中断函数生成，配置与注册过程
#### 在中断引导入口文件 trapentry.S中 TRAPHANDLER宏定义实现了中断和异常函数的统一生成引导

```asm
#define TRAPHANDLER(name, num)                      \
    .globl name;        /* 定义了全局连接符号 'name' */   \
    .type name, @function;  /* 定义了连接符号name的类型是函数 */       \
    .align 2;       /* 对其该函数 */     \
    name:           /* 'name'函数 入口地址 */      \
    pushl $(num);   /* 中断或异常编号压栈 */         \
    jmp _alltraps
```
>TRAPHANDLER_NOEC 和其区别是 cpu 不会压入错误码到栈中，宏TRAPHANDLER_NOEC自己在栈中压入0，保持两个函数生成同样的栈 结构
####  _alltraps 实现调用trap函数，向栈中压入trap函数的参数trapframe

```asm
_alltraps:
    pushw $0
    pushw %ds
    pushw $0
    pushw %es
    pushal
    pushl %esp
    movw $(GD_KD),%ax
    movw %ax,%ds
    movw %ax,%es
    call trap
```
>结合之前的TRAPHANDLER_NOEC或TRAPHANDLER宏定义将trapframe完整参数压入栈中
![](readmeResource\work3_illustrate01.jpg)
>下面代码是程式中对应的trapframe结构

```c
struct Trapframe {
    struct PushRegs tf_regs;
    uint16_t tf_es;
    uint16_t tf_padding1;
    uint16_t tf_ds;
    uint16_t tf_padding2;
    uint32_t tf_trapno;
    /* below here defined by x86 hardware */
    uint32_t tf_err;
    uintptr_t tf_eip;
    uint16_t tf_cs;
    uint16_t tf_padding3;
    uint32_t tf_eflags;
    /* below here only when crossing rings, such as from user to kernel */
    uintptr_t tf_esp;
    uint16_t tf_ss;
    uint16_t tf_padding4;
} __attribute__((packed));
struct PushRegs {
    /* registers as pushed by pusha */
    uint32_t reg_edi;
    uint32_t reg_esi;
    uint32_t reg_ebp;
    uint32_t reg_oesp;      /* Useless */
    uint32_t reg_ebx;
    uint32_t reg_edx;
    uint32_t reg_ecx;
    uint32_t reg_eax;
} __attribute__((packed));
```
#### 有了统一的入口生成汇编代码，在trapentry.S中使用它们构造实际的入口码
```c
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
```
这句话利用上面说明的代码在 trapentry.S 生成除零错误的入口函数，其中dividezero_handler是全局链接变量，函数名，0x0是异常处理的编号。<br>
当然这个函数需要声明，我们在trap.c中声明它`void dividezero_handler();`

#### 在idt中注册以上异常函数，以便cpu在捕获异常或中断后，在idt中查表触发函数入口
>注册使用主要依靠这个宏，向其传递 参数 描述符表内项的偏移虚地址（gate，这里是idt[i],idt是interupt descriptor table），类型（中断还是异常，这两者差别已在书面问题1中解释），段选择器（sel，终端或异常的处理函数代码所在的程式段），段内偏移地址（即函数名连接符），权限（dpl ，0是内核，3是普通用户）
```c
#define SETGATE(gate, istrap, sel, off, dpl)            \
{                               \
    (gate).gd_off_15_0 = (uint32_t) (off) & 0xffff;     \
    (gate).gd_sel = (sel);                  \
    (gate).gd_args = 0;                 \
    (gate).gd_rsv1 = 0;                 \
    (gate).gd_type = (istrap) ? STS_TG32 : STS_IG32;    \
    (gate).gd_s = 0;                    \
    (gate).gd_dpl = (dpl);                  \
    (gate).gd_p = 1;                    \
    (gate).gd_off_31_16 = (uint32_t) (off) >> 16;       \
}
```
有以上宏，在trap_init 中很容易为一个中断或异常注册 `SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);`

#### 至于查看中断或异常cpu是否有给它压入错误码，即选择TRAPHANDLER_NOEC或TRAPHANDLER宏定义；判断异常或中断的权限；判断错误的种类是异常还是中断；了解中断或异常的编号；
>总而言之解决以上函数的具体实现，参考下图

![](readmeResource\work3_illustrate02.png)
### 测试效果
![](readmeResource\work3_illustrate03.png)  
### 跳回目录 [目录](#catalog)
---
<span id="work4"></span>
## 上机作业问题4  
### 添加代码内容   源代码在这里添加
```c
if(tf->tf_trapno==T_PGFLT)
    {
        page_fault_handler(tf);
        return;
    }
```
>kern\trap.c\trap_dispatch  
### 代码说明  
依上一问，在所有中断和异常统一调用trap函数后，trap函数必然通过`trap_dispatch(tf);`调用trap_dispatch函数分别处理，原因已经在书面作业1中说明
之后，在该函数中利用中断编号判断错误类型，调用缺页异常的后续处理函数   
### 测试效果
![](readmeResource\work3_illustrate04.png)  
### 跳回目录 [目录](#catalog)
---
<span id="work5"></span>
## 上机作业问题5
### trap_dispatch 代码
```c
static void
trap_dispatch(struct Trapframe *tf)
{
	// Handle processor exceptions.
	// LAB 3: Your code here.
	if(tf->tf_trapno==T_PGFLT)
	{
		page_fault_handler(tf);
		return;
	}
	if(tf->tf_trapno==T_BRKPT)
	{
		monitor(tf);
		return;
	}
	if(tf->tf_trapno==T_SYSCALL)
	{
		tf->tf_regs.reg_eax=syscall(tf->tf_regs.reg_eax,tf->tf_regs.reg_edx,tf->tf_regs.reg_ecx,tf->tf_regs.reg_ebx,tf->tf_regs.reg_edi,tf->tf_regs.reg_esi);
	    return;
	}
	// Unexpected trap: The user process or the kernel has a bug.
	print_trapframe(tf);
	if (tf->tf_cs == GD_KT)
		panic("unhandled trap in kernel");
	else 
	{
		env_destroy(curenv);
		return;
	}
}
```
>kern/trap.c/trap_dispatch
### 代码说明
trap_dispatch()中第二个if判断即为断点异常中断，根据题目要求，发生断点异常后调用内核监视器monitor。此时可通过breakpoint测试（如图）：<br>

### 测试效果
![](.\readmeResource\breakpoint.png) 
### 跳回目录 [目录](#catalog)
---
<span id="work6"></span>
## 上机作业问题6
###6.1
####trap_init 代码
```c
void
trap_init(void)
{
	extern struct Segdesc gdt[];

	// LAB 3: Your code here.
	SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);
	SETGATE(idt[1], 0, GD_KT, dbg_handler, 0);
	SETGATE(idt[2], 0, GD_KT, nmi_handler, 0);
	SETGATE(idt[3], 1, GD_KT, breakpoint_handler, 3);
	SETGATE(idt[4], 1, GD_KT, overflow_handler, 3);
	SETGATE(idt[5], 1, GD_KT, bdrgeexceed_handler, 3);
	SETGATE(idt[6], 1, GD_KT, invalidop_handler, 0);
	SETGATE(idt[7], 1, GD_KT, nomathcopro_handler, 0);
	SETGATE(idt[8], 1, GD_KT, dbfault_handler, 0);
	SETGATE(idt[10], 1, GD_KT, invalidTSS_handler, 0);

	SETGATE(idt[11], 1, GD_KT, sgmtnotpresent_handler, 0);
	SETGATE(idt[12], 1, GD_KT, stacksgmtfault_handler, 0);
	SETGATE(idt[14], 1, GD_KT, pagefault_handler, 0);
	SETGATE(idt[13], 1, GD_KT, generalprotection_handler, 0);
	SETGATE(idt[16], 1, GD_KT, FPUerror_handler, 0);
	SETGATE(idt[17], 1, GD_KT, alignmentcheck_handler, 0);
	SETGATE(idt[18], 1, GD_KT, machinecheck_handler, 0);
	SETGATE(idt[19], 1, GD_KT, SIMDFPexception_handler, 0);
	SETGATE(idt[48], 0, GD_KT, systemcall_handler, 3);
	// Per-CPU setup 
	trap_init_percpu();
}
```
>kern/trap.c/trap_init
####代码说明
trap_init()利用SETGATE(gate, istrap, sel, off, dpl)宏定义以及之前在trapentry.S中的内容在idt中注册中断响应函数

###6.2
####trap_dispatch 代码
```c
static void
trap_dispatch(struct Trapframe *tf)
{
	// Handle processor exceptions.
	// LAB 3: Your code here.
	if(tf->tf_trapno==T_PGFLT)
	{
		page_fault_handler(tf);
		return;
	}
	if(tf->tf_trapno==T_BRKPT)
	{
		monitor(tf);
		return;
	}
	if(tf->tf_trapno==T_SYSCALL)
	{
		tf->tf_regs.reg_eax=syscall(tf->tf_regs.reg_eax,tf->tf_regs.reg_edx,tf->tf_regs.reg_ecx,tf->tf_regs.reg_ebx,tf->tf_regs.reg_edi,tf->tf_regs.reg_esi);
	    return;
	}
	// Unexpected trap: The user process or the kernel has a bug.
	print_trapframe(tf);
	if (tf->tf_cs == GD_KT)
		panic("unhandled trap in kernel");
	else 
	{
		env_destroy(curenv);
		return;
	}
}
```
>kern/trap.c/trap_dispatch
####代码说明
trap_dispatch()中第三个if判断即为系统调用中断，调用syscall()函数。根据前问提示，系统调用的编号在%eax中，参数(最5个)则依次保存在%edx、%ecx、 %ebx、%edi 和%esi中，将返回值再写回%eax，填写syscall()函数参数。

###6.3
####syscall 代码
```c
// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
	switch (syscallno)
	{
		case SYS_cputs:
	    {
		    sys_cputs((const char*)a1, a2);
		    return 0;
	    }
		case SYS_cgetc:
		{

			return sys_cgetc();
		}
		case SYS_getenvid:
		{

			return sys_getenvid();
		}
		case SYS_env_destroy:
		{

			return sys_env_destroy(a1);
		}
		default:
		{
			panic("invalid syscall num!");
			return -E_INVAL;
		}
	}
}
```
>kern/syscall.c/syscall
####代码说明
kern/syscall.c中预先定义了四个函数:<br>
```c
static void
sys_cputs(const char *s, size_t len)
{
	user_mem_assert(curenv,s,len,PTE_U);
	cprintf("%.*s", len, s);
}
static int
sys_cgetc(void)
{
	return cons_getc();
}
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
}
static int
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
		return r;
	if (e == curenv)
		cprintf("[%08x] exiting gracefully\n", curenv->env_id);
	else
		cprintf("[%08x] destroying %08x\n", curenv->env_id, e->env_id);
	env_destroy(e);
	return 0;
}
```
而kern/syscall.h定义了枚举结构
```c
enum {
	SYS_cputs = 0,
	SYS_cgetc,
	SYS_getenvid,
	SYS_env_destroy,
	NSYSCALLS
};
```
调用号与函数一一对应，根据不同的调用号执行相应的系统调用函数。syscall()函数据此填写，若调用号无效返回-E_INVAL。

###6.3
####运行user/hello
####测试效果
输出`hello,world`（如图）<br>
![](.\readmeResource\helloworld1.png)
### 跳回目录 [目录](#catalog)
---
<span id="work7"></span>
## 上机作业问题7
###7.1
####trap_dispatch 代码
```c
void
libmain(int argc, char **argv)
{
	// set thisenv to point at our Env structure in envs[].
	// LAB 3: Your code here.
	thisenv = 0;
	
	int index=sys_getenvid();
	thisenv=&envs[ENVX(index)];
	// save the name of the program so that panic() can use it
	if (argc > 0)
		binaryname = argv[0];

	// call user main routine
	umain(argc, argv);

	// exit gracefully
	exit();
}
```
>lib/libmain.c/libmain
####代码说明
先利用sys_getenvid()函数得到当前进程号，利用ENVX(index)宏定义得到当前的进程在envs[]中的位置，从而得到当前的进程指针赋值给thisenv。

###7.2
####运行user/hello
####测试效果
输出`hello,world`以及`i am environment 00001000`，并且调用sys_env_destroy()函数会输出`sys_env_destroy()`（如图）<br>
![](.\readmeResource\helloworld2.png)<br>
此时可通过hello测试（如图）：<br>
![](.\readmeResource\hello.png)
### 跳回目录 [目录](#catalog)
---
<span id="work8"></span>
## 上机作业问题8
###8.1
####page_fault_handler 代码
```c
void
page_fault_handler(struct Trapframe *tf)
{
	uint32_t fault_va;

	// Read processor's CR2 register to find the faulting address
	fault_va = rcr2();

	// Handle kernel-mode page faults.

	// LAB 3: Your code here.
	if((tf->tf_cs & 3)==0)
	{
		panic("kernel mode page faults!!");
	}
	// We've already handled kernel-mode exceptions, so if we get here,
	// the page fault happened in user mode.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
		curenv->env_id, fault_va, tf->tf_eip);
	print_trapframe(tf);
	env_destroy(curenv);
}
```
>kern/trap.c/page_fault_handler
####代码说明
当发生缺页中断时会调用此函数，tf_cs的最低几位如果等于3则可确定发生在内核中，终止内核并提示信息。

###8.2
####user_mem_check 代码
```c
static uintptr_t user_mem_check_addr;

int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
	// LAB 3: Your code here.

	    int i=0;
		int flag=0;
		int t=(int)va;
		for(i=t;i<(t+len);i+=PGSIZE)
		{
			pte_t* store=0;
			struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
			if(store!=NULL)
			{
				//cprintf("pte!=NULL %08x\r\n",*store);
			   if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
			   {
				//cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
				break;
			   }
			}
			else
			{
				//cprintf("no pte!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
				break;
			}
		    i=ROUNDDOWN(i,PGSIZE);
		}

		return flag;
}
```
>kern/pmap.c/user_mem_check
####代码说明
当前进程所需的页表是否有映射以及是否有read权限，遍历page table，查看其页表项的PTE_P和PTE_U位即可，如果通不过检测，就把这个进程panic掉。可以到达则返回0，否则返回-E_FAULT。

###8.3
####sys_cputs 代码
```c
static void
sys_cputs(const char *s, size_t len)
{
	// Check that the user has permission to read memory [s, s+len).
	// Destroy the environment if not.

	// LAB 3: Your code here.
	user_mem_assert(curenv,s,len,PTE_U);
	// Print the string supplied by the user.
	cprintf("%.*s", len, s);
}
```
>kern/syscall.c/sys_cputs
####代码说明
此函数中要去检查用户传入的字符串所处的内存是否有映射以及是否有read权限，调用`user_mem_assert(curenv,s,len,PTE_U);`来检查传递给内核的参数，在这个函数中用到了之前定义的user_mem_check()。

###8.4
####运行 user/buggyhello
####测试效果
![](.\readmeResource\buggyhello.png)

###8.5
####debuginfo_eip 需要填充部分代码
```c
		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, usd, sizeof(*usd),PTE_U) <0 )  
        	return -1;

		stabs = usd->stabs;
		stab_end = usd->stab_end;
		stabstr = usd->stabstr;
		stabstr_end = usd->stabstr_end;

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, stabs, stab_end-stabs,PTE_U) <0 ||  
        user_mem_check(curenv, stabstr, stabstr_end-stabstr,PTE_U) <0)  
            return -1; 
```
>kern/kdebug.c/debuginfo_eip
####代码说明
调用user_mem_check()检查，确保usd、stabs、stabstr有效，否则返回-1。

###8.6
####运行user/breakpoint
####测试效果
在内核中运行backtrace。<br>
![](.\readmeResource\runbreakpoint.png)<br>
### 跳回目录 [目录](#catalog)
---
<span id="work9"></span>
## 上机作业问题9
###运行user/evilhello
###测试效果<br>
![](.\readmeResource\evilhello.png)
### 跳回目录 [目录](#catalog)
---
## 参考资料 备注的参考资料，按照相同格式，依次顺序列明
- [IA32-3A 64位处理器和软件体系架构] (https://pdos.csail.mit.edu/6.828/2011/readings/ia32/IA32-3A.pdf)
- [中断和异常] (https://pdos.csail.mit.edu/6.828/2011/readings/i386/c09.html)
- [idt注册和宏选择] (https://pdos.csail.mit.edu/6.828/2011/lec/x86_idt.pdf)
