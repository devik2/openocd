/***************************************************************************
 *   Copyright (C) 2010 by Spencer Oliver                                  *
 *   spen@spen-soft.co.uk                                                  *
 *                                                                         *
 *   Copyright (C) 2011 Øyvind Harboe                                      *
 *   oyvind.harboe@zylin.com                                               *
 *                                                                         *
 *   Copyright (C) 2015 Uwe Bonnes                                         *
 *   bon@elektron.ikp.physik.tu-darmstadt.de                               *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.                                        *
 ***************************************************************************/

	.text
	.syntax unified
	.cpu cortex-m0
	.thumb

/*
 * Params :
 * r0 = workarea start, status (out)
 * r1 = workarea end
 * r2 = target address
 * r3 = count (64bit words)
 * r4 = flash base
 *
 * Clobbered:
 * r5   - rp
 * r6   - temp
 */

#define STM32_FLASH_CR_OFFSET	0x14	/* offset of CR register in FLASH struct */
#define STM32_FLASH_SR_OFFSET	0x10	/* offset of SR register in FLASH struct */

#define STM32_PROG	 0x1	/* PG */

	.macro txa v
	movs	r6, #0x20 * \v
	str	r6, [r7, #0x14]
	.endm
	.thumb_func
	.global _start
_start:
	b	run
test:	ldr	r4, =#0x40022000
	ldr	r0, =#0x20000200
	ldr	r1, =#0x20004200
	ldr	r2, =#0x08000010
	mov	r6, r0
	adds	r6, #8
	str	r6, [r0]
	str	r6, [r0,#4]
	movs	r3, #2
	ldr	r6, [r4, #STM32_FLASH_CR_OFFSET]
	lsrs	r6, #32
	bcc	run
	ldr	r6, =#0x45670123
	str	r6, [r4, #8]
	ldr	r6, =#0xCDEF89AB
	str	r6, [r4, #8]
run:
	ldr	r6, =#0x40021000	/* RCC */
	movs	r5, #15
	str	r5, [r6,#0x34]		/* en gpios */
	ldr	r7, =#0x50000000	/* GPIOA base */
	ldr	r5, =#0xEBFFF7FF	@ PA5 out
	str	r5, [r7]
wait_fifo:
	ldr 	r6, [r0, #0]	/* read wp */
	cmp 	r6, #0		/* abort if wp == 0 */
	beq 	exit
	ldr 	r5, [r0, #4]	/* read rp */
	subs	r6, r6, r5	/* number of bytes available for read in r6*/
	bpl	no_wrap
	add	r6, r1          /* if wrapped around*/
	subs	r6, r0          /* add size of buffer */
no_wrap:
	cmp 	r6, #8		/* wait until 8 bytes are available */
	bcc 	wait_fifo

	ldr	r6, =STM32_PROG
	str	r6, [r4, #STM32_FLASH_CR_OFFSET]
	dsb
	ldr 	r6, [r5]	/* read one word from src */
	str 	r6, [r2]	/* write one word to dst */
	dsb
	ldr 	r6, [r5,#4]
	str 	r6, [r2,#4]
	dsb
	txa 1
	adds	r5, #8		/* inc pointers */
	adds	r2, #8
@	ldr	r6, =#100	/* delay needed (reason unknown) */
@wait:	subs	r6, #1
@	bne wait
busy:
	ldr 	r6, [r4, #STM32_FLASH_SR_OFFSET]
	lsrs	r6, #17		/* BSY (bit16) == 1 => operation in progress */
	bcs 	busy		/* wait more... */
	txa 0
	mov	r10, r5
	movs	r5, #0xfa	/* PGSERR | PGPERR | PGAERR | WRPERR | PROGERR*/
	ldr 	r6, [r4, #STM32_FLASH_SR_OFFSET]
	tst	r6, r5
	mov	r5, r10
	bne	error		/* fail... */

	cmp 	r5, r1		/* wrap rp at end of buffer */
	bcc	no_wrap2
	mov	r5, r0
	adds	r5, #8		/* skip loader args */
no_wrap2:
	str 	r5, [r0, #4]	/* store rp */
	subs	r3, r3, #1	/* decrement dword count */
	beq	exit		
	b	wait_fifo	/* loop if not done */
error:
	txa 1
	txa 0
	txa 1
	txa 0
	txa 1
	txa 0
	movs	r1, #0
	str	r1, [r0, #4]	/* set rp = 0 on error */
exit:
	txa 1
	txa 0
	txa 1
	txa 0
	mov	r0, r6		/* return status in r0 */
	bkpt	#0x00

	.pool

