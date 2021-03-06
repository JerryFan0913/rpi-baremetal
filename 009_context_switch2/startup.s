// startup
  .align

.global _start
_start:
// IRQ/FIQ disabled, Thumb disabled, initialize stack in IRQ mode
	ldr	r0, =0x000000d2
  #move ARM register to system register
	msr	cpsr, r0
	ldr	sp, =0x00008000

// IRQ/FIQ disabled, Thumb disabled, initialize stack in SVC mode
  ldr r0, =0x000000d3
  msr cpsr, r0
  ldr sp, =0x06400000

  b main
  b .

.global _hangup
_hangup:
	ldr	r0, =0x000000d3
	msr	cpsr, r0
	b .

_IRQ_iterrupt:
  //-- irq mode
  sub lr, lr, #4 // in IRQ mode, r14_irq(lr_irq) points to PC+#4 in user mode
  // save context
  push {r0-r12, lr} // save user mode registers

  mrs r0, spsr // spsr -> r0
  cps #0x13
  //-- svc mode
  mov r1, sp
  mov r2, lr

  cps #0x12
  //-- irq mode
  push {r0-r2} // save spsr, user mode sp, lr

  // call IRQ_hander(user-mode-sp)
  mov r0, r2
	bl	IRQ_handler
  cmp r0, #0
  bne _IRQ_interrupt_context_switch

  pop {r0-r2} // restore spsr, user mode sp, lr
  msr spsr, r0 // r0 -> spsr
  cps #0x13
  //-- svc mode
  mov sp, r1 // restore sp
  mov lr, r2 // restore lr

  cps #0x12
  //-- irq mode
  pop  {r0-r12,lr}
  movs pc, lr

_IRQ_interrupt_context_switch:
  //-- irq mode
  // r0 is next thread's SP

  pop {r1-r3} // restore spsr, user mode sp, lr

  // save registers in user mode stack
  // r1: user mode cpsr
  // r2: user mode sp
  // r3: user mode lr
  sub r2, r2, #4
  str r1, [r2] // spsr

  ldr r4, [r13, #4*13]
  sub r2, r2, #4
  str r4, [r2] // user mode pc (r14_irq)

  sub r2, r2, #4
  str r3, [r2] // user mode lr

  ldr r4, [r13, #4*12]
  sub r2, r2, #4
  str r4, [r2] // user mode r12

  ldr r4, [r13, #4*11]
  sub r2, r2, #4
  str r4, [r2] // user mode r11

  ldr r4, [r13, #4*10]
  sub r2, r2, #4
  str r4, [r2] // user mode r10

  ldr r4, [r13, #4*9]
  sub r2, r2, #4
  str r4, [r2] // user mode r9

  ldr r4, [r13, #4*8]
  sub r2, r2, #4
  str r4, [r2] // user mode r8

  ldr r4, [r13, #4*7]
  sub r2, r2, #4
  str r4, [r2] // user mode r7

  ldr r4, [r13, #4*6]
  sub r2, r2, #4
  str r4, [r2] // user mode r6

  ldr r4, [r13, #4*5]
  sub r2, r2, #4
  str r4, [r2] // user mode r5

  ldr r4, [r13, #4*4]
  sub r2, r2, #4
  str r4, [r2] // user mode r4

  ldr r4, [r13, #4*3]
  sub r2, r2, #4
  str r4, [r2] // user mode r3

  ldr r4, [r13, #4*2]
  sub r2, r2, #4
  str r4, [r2] // user mode r2

  ldr r4, [r13, #4*1]
  sub r2, r2, #4
  str r4, [r2] // user mode r1

  ldr r4, [r13]
  sub r2, r2, #4
  str r4, [r2] // user mode r0

  mov r4, sp // r4 <- r13_irq

  msr spsr, r1 // r1 -> spsr
  cps #0x13          //@ svc mode
  //-- svc mode
  // change user mode stack to next thread's stack
  mov sp, r0
  // push into r13_irq (r4)
  ldr r2, [sp, #4*14] // user mode pc
  sub r4, r4, #4
  str r2, [r4]
  ldr r2, [sp, #4*15] // spsr
  sub r4, r4, #4
  str r2, [r4]
  // restore registers
  pop {r0-r12,lr}
  add sp, sp, #4*2 // pop pc, spsr

  cps #0x12          //@ irq mode
  //-- irq mode
  sub sp, sp, #4*2
  pop {lr}
  // enable irq and restore spsr
  bic lr, lr, #0x80
  msr spsr, lr // lr -> spsr
  // restore lr (user mode pc)
  pop {lr}
  // discard pushed registers
  add r13, r13, #4*14
  // movs pc, * ... mov's' pc restores status register
  movs pc, lr


.global _enable_IRQ
_enable_IRQ:
  // move system to ARM register
	mrs	r0, cpsr
	bic r0, r0, #0x80
	msr cpsr_c,r0
	bx lr

.global _disable_IRQ
_disable_IRQ:
	mrs	r0, cpsr
	ldr	r1,	=0x80
	orr r0, r0, r1
	msr	cpsr_c, r0
	bx lr

.global _getmode
_getmode:
	mrs	r0, cpsr
	bx lr

.global  _initialize_vector_start
_initialize_vector_start:
	ldr	pc, _vec_Reset
	ldr	pc, _vec_Undef
	ldr	pc, _vec_SWI
	ldr	pc, _vec_PrefAbort
	ldr	pc, _vec_DataAbort
	ldr	pc, _vec_Reserved
	ldr	pc, _vec_IRQ
	ldr	pc, _vec_FIQ
_vec_Reset:		.word	_start
_vec_Undef:		.word	_hangup
_vec_SWI:		.word	_hangup
_vec_PrefAbort:	.word	_hangup
_vec_DataAbort:	.word	_hangup
_vec_Reserved:	.word	_hangup
_vec_IRQ:		.word	_IRQ_iterrupt
_vec_FIQ:		.word	_hangup
	.global  _initialize_vector_end
_initialize_vector_end:
// dummy instruction to keep initialize_vector_end label
	mov r0,r0

.global _init_vector_table
_init_vector_table:
  ldr r0, =0x0
  ldr r1, =_initialize_vector_start
  ldr r3, =_initialize_vector_end
  cmp r1, r3
  bxeq lr
  _init_vector_table_loop:
  ldr r2, [r1]
  str r2, [r0]
  add r1, r1, #4
  add r0, r0, #4
  cmp r1, r3
  bne _init_vector_table_loop
  bx lr

.global _get_stack_pointer
_get_stack_pointer:
  mov r0, r13
  bx lr

.global _write_memory
_write_memory:
  bx lr

.global _wfi
_wfi:
  wfi
	bx lr

// http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.dht0008a/ch01s03s02.html
.equ  locked,   1
.equ  unlocked, 0

// BUG: lock_mutex hangs
// LDREX doesn't work when MMU is disabled. Don't use this.
// Declare for use from C as extern void lock_mutex(void * mutex);
.global _lock_mutex_mmu
_lock_mutex_mmu:
  LDR     r1, =locked
1:
  LDREX   r2, [r0]
  CMP     r2, r1        // Test if mutex is locked or unlocked
  BEQ     2f
  STREXNE r2, r1, [r0]  // Not locked, attempt to lock it
  CMPNE   r2, #1        // Check if Store-Exclusive failed
  BEQ     1b           // Failed - retry from 1
  // Lock acquired
  DMB                   // Required before accessing protected resource
  BX      lr
2:
// Take appropriate action while waiting for mutex to become unlocked
  //wfi
  nop
  B       1b           // Retry from 1


// BUG: unlock_mutex
// Declare for use from C as extern void unlock_mutex(void * mutex);
.global _unlock_mutex_mmu
_unlock_mutex_mmu:
    LDR     r1, =unlocked
    DMB                   // Required before releasing protected resource
    STR     r1, [r0]      // Unlock mutex
    // SIGNAL_UPDATE: none
    BX      lr


// BUG: SWP version
// http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.dht0008a/CJHBGBBJ.html
// still hangs
.global _lock_mutex_swp
_lock_mutex_swp:
    LDR r2, =locked
    SWP r1, r2, [r0]       // Swap R2 with location [R0], [R0] value placed in R1
    CMP r1, r2             // Check if memory value was ‘locked’
    BEQ _lock_mutex_swp     // If so, retry immediately
    BX  lr                 // If not, lock successful, return

// BUG: not really excusive when context swithes after ldr befor str
.global _lock_mutex_simple
_lock_mutex_simple:
  ldr r1, =unlocked
  ldr r3, =locked
  ldr r2, [r0]
  cmp r2, r3
  beq _lock_mutex_simple
  str r1, [r0]
  bx lr

.global _unlock_mutex_simple
_unlock_mutex_simple:
    LDR r1, =unlocked
    STR r1, [r0]           // Write value ‘unlocked’ to location [R0]
    BX  lr


