// implement fork from user space

#include <inc/string.h>
#include <inc/lib.h>

// PTE_COW marks copy-on-write page table entries.
// It is one of the bits explicitly allocated to user processes (PTE_AVAIL).
#define PTE_COW		0x800

//
// Custom page fault handler - if faulting page is copy-on-write,
// map in our own private writable copy.
//
static void
pgfault(struct UTrapframe *utf)
{
	void *addr = (void *) utf->utf_fault_va;
	uint32_t err = utf->utf_err;
	int r;
	int envid = sys_getenvid();
	// Check that the faulting access was (1) a write, and (2) to a
	// copy-on-write page.  If not, panic.
	// Hint:
	//   Use the read-only page table mappings at vpt
	//   (see <inc/memlayout.h>).

	// LAB 4: Your code here.
	if((err & FEC_WR) == 0 || (vpt[PGNUM(addr)] & PTE_COW) == 0)
		panic("pgfault(): not a write nor a cow page\n");
	// Allocate a new page, map it at a temporary location (PFTEMP),
	// copy the data from the old page to the new page, then move the new
	// page to the old page's address.
	// Hint:
	//   You should make three system calls.
	//   No need to explicitly delete the old page's mapping.
	if( (r = sys_page_alloc(envid , (void*)PFTEMP, PTE_U | PTE_W | PTE_P)) < 0)
		panic("pgfault(): failed %e\n", r);

	addr = ROUNDDOWN(addr, PGSIZE);
	memmove(PFTEMP, addr, PGSIZE);

	if ((r = sys_page_map(envid , PFTEMP, envid , addr, PTE_U | PTE_P | PTE_W)) < 0)
		panic ("pgfault(): page mapping failed: %e\n", r);

	// LAB 4: Your code here.

	//panic("pgfault not implemented");
}

//
// Map our virtual page pn (address pn*PGSIZE) into the target envid
// at the same virtual address.  If the page is writable or copy-on-write,
// the new mapping must be created copy-on-write, and then our mapping must be
// marked copy-on-write as well.  (Exercise: Why do we need to mark ours
// copy-on-write again if it was already copy-on-write at the beginning of
// this function?)
//
// Returns: 0 on success, < 0 on error.
// It is also OK to panic on error.
//
static int
duppage(envid_t envid, unsigned pn)
{
	int r;

	int now_evid = sys_getenvid();
	void* addr = (void*)(pn * PGSIZE);

	pte_t pte = vpt[pn];

	if((pte & PTE_W) != 0 || (pte & PTE_COW) != 0)
	{
		if((r = sys_page_map(now_evid, addr, envid, addr, PTE_U | PTE_P | PTE_COW)) < 0)
			panic("duppage(): failed... mapping page into envid %e\n", r);
		if((r = sys_page_map(now_evid, addr, now_evid, addr, PTE_U | PTE_P | PTE_COW)) < 0)
			panic("duppage(): failed... mapping page into self: %e\n", r);
	}
	else
	{
		if((r = sys_page_map(now_evid, addr, envid, addr, PTE_U | PTE_P)) < 0)
			panic("duppage(): failed... no cow needed: %e\n", r);	
	}

	return 0;
	// LAB 4: Your code here.
	//panic("duppage not implemented");
}

//
// User-level fork with copy-on-write.
// Set up our page fault handler appropriately.
// Create a child.
// Copy our address space and page fault handler setup to the child.
// Then mark the child as runnable and return.
//
// Returns: child's envid to the parent, 0 to the child, < 0 on error.
// It is also OK to panic on error.
//
// Hint:
//   Use vpd, vpt, and duppage.
//   Remember to fix "thisenv" in the child process.
//   Neither user exception stack should ever be marked copy-on-write,
//   so you must allocate a new page for the child's user exception stack.
//
extern void _pgfault_upcall(void);
envid_t
fork(void)
{	// Setup handler
	set_pgfault_handler(pgfault);

	// Create Child
	envid_t envid = sys_exofork();
	if(envid < 0)
		cprintf("fork(): create child failed\n");
	if(envid == 0)
	{
		//cprintf("child done here\n");
		// fix thisenv
		thisenv = &envs[ENVX(sys_getenvid())];
		return 0;
	}

	// Copy address space 
	int i,j,pn;
	i=j=pn=0;
	for (i = 0; i < PDX(UTOP); i++) {
		if (vpd[i] & PTE_P) {
			for (j = 0; j < NPTENTRIES; j++) {
				pn = i* NPTENTRIES + j;
				if (pn == PGNUM(UXSTACKTOP - PGSIZE)) {
					break;
				}
				if (vpt[pn] & PTE_P) {
					duppage(envid, pn);
				}
			}
		}
	}
	
	int r;
	// new page for user exception stack
	if ((r = sys_page_alloc (envid, (void *)(UXSTACKTOP - PGSIZE), PTE_W | PTE_U | PTE_P)) != 0)
		panic("fork(): uxstk failed: %e", r);

	sys_env_set_pgfault_upcall (envid, _pgfault_upcall);

	if ((r = sys_env_set_status(envid, ENV_RUNNABLE)) < 0)
		panic("fork(): setting child status failed: %e", r);
	// LAB 4: Your code here.
	return envid;
	//panic("fork not implemented");
}

// Challenge!
int
sfork(void)
{
	panic("sfork not implemented");
	return -E_INVAL;
}
