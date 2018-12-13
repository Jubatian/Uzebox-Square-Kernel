/*
 *  SPI RAM basic interface functions
 *  Copyright (C) 2017 Sandor Zsuga (Jubatian)
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/



/*
**  Important: Before using the functions of this library, you have to
**  initialize the SD card (otherwise it will interfere with the SPI RAM, so
**  doing an SPI init is not sufficient!). The routines assume that the SPI
**  is set up for a data rate of 14MHz (maximal speed on the UzeBox).
*/



#include <avr/io.h>



#define  SR_PORT _SFR_IO_ADDR(PORTA)
#define  SR_PIN  PA4
#define  SR_DR   _SFR_IO_ADDR(SPDR)



/*
** void XRAM_Init(void);
**
** Initializes SPI RAM.
**
** Clobbers:
** r19, r20, r21, r22, r23, r24, r25
*/
.global XRAM_Init
.section .text.XRAM_Init
XRAM_Init:

	; Set up SPI, max speed for SPI RAM.

	ldi   r25,     (1 << SPE) | (1 << MSTR) ; SPI Master mode
	out   _SFR_IO_ADDR(SPCR), r25
	ldi   r25,     (1 << SPI2X)
	out   _SFR_IO_ADDR(SPSR), r25
	sbi   _SFR_IO_ADDR(DDRB), PB7
	sbi   _SFR_IO_ADDR(DDRB), PB5
	sbi   _SFR_IO_ADDR(PORTA), PA4
	sbi   _SFR_IO_ADDR(DDRA), PA4 ; SPI RAM CS pin

	ret



/*
** u8 XRAM_ReadU8(u8 bank, u16 addr);
** s8 XRAM_ReadS8(u8 bank, u16 addr);
**
** Reads unsigned or signed 8 bit value from SPI RAM.
**
** Inputs:
**     r24: Bank (low bit used to select low / high 64K)
** r23:r22: Address
** Outputs:
** r25:r24: Byte read (r25: zero)
** Clobbers:
** (Nothing)
*/
.global XRAM_ReadU8
.global XRAM_ReadS8
.section .text.XRAM_ReadS8
XRAM_ReadS8:
	jmp   XRAM_ReadU8
.section .text.XRAM_ReadU8
XRAM_ReadU8:

	cbi   SR_PORT, SR_PIN  ; Select SPI RAM
	ldi   r25,     0x03    ; Read from SPI RAM
	out   SR_DR,   r25     ; Send read command
	call  spiram_address
	ldi   r25,     4       ; ( 5)
	dec   r25
	brne  .-4              ; (16)
	ldi   r25,     0xFF    ; (17) Dummy for the read
	out   SR_DR,   r25
	ldi   r25,     5       ; ( 1)
	dec   r25
	brne  .-4              ; (15)
	ldi   r25,     0       ; (16)
	in    r24,     SR_DR   ; (17)
	sbi   SR_PORT, SR_PIN  ; Deselect SPI RAM
	ret



/*
** void XRAM_WriteU8(u8 bank, u16 addr, u8 val);
** void XRAM_WriteS8(u8 bank, u16 addr, s8 val);
**
** Writes unsigned or signed 8 bit value to SPI RAM.
**
** Inputs:
**     r24: Bank (low bit used to select low / high 64K)
** r23:r22: Address
**     r20: Value
** Clobbers:
** r25
*/
.global XRAM_WriteU8
.global XRAM_WriteS8
.section .text.XRAM_WriteS8
XRAM_WriteS8:
	jmp   XRAM_WriteU8
.section .text.XRAM_WriteU8
XRAM_WriteU8:

	cbi   SR_PORT, SR_PIN  ; Select SPI RAM
	ldi   r25,     0x02    ; Write to SPI RAM
	out   SR_DR,   r25     ; Send write command
	call  spiram_address
	ldi   r25,     4       ; ( 5)
	dec   r25
	brne  .-4              ; (16)
	nop                    ; (17)
	out   SR_DR,   r20
	ldi   r25,     5       ; ( 1)
	dec   r25
	brne  .-4              ; (15)
	rjmp  .                ; (17) Data certainly clocked out
	sbi   SR_PORT, SR_PIN  ; Deselect SPI RAM
	ret



/*
** u16 XRAM_ReadU16(u8 bank, u16 addr);
** s16 XRAM_ReadS16(u8 bank, u16 addr);
**
** Reads unsigned or signed 16 bit value from SPI RAM.
**
** Inputs:
**     r24: Bank (low bit used to select low / high 64K)
** r23:r22: Address
** Outputs:
** r25:r24: Word read
** Clobbers:
** (Nothing)
*/
.global XRAM_ReadU16
.global XRAM_ReadS16
.section .text.XRAM_ReadS16
XRAM_ReadS16:
	jmp   XRAM_ReadU16
.section .text.XRAM_ReadU16
XRAM_ReadU16:

	cbi   SR_PORT, SR_PIN  ; Select SPI RAM
	ldi   r25,     0x03    ; Read from SPI RAM
	out   SR_DR,   r25     ; Send read command
	call  spiram_address
	ldi   r25,     4       ; ( 5)
	dec   r25
	brne  .-4              ; (16)
	ldi   r25,     0xFF    ; (17) Dummy for the read
	out   SR_DR,   r25
	ldi   r25,     5       ; ( 1)
	dec   r25
	brne  .-4              ; (15)
	ldi   r25,     0xFF    ; (16) Dummy for the read
	in    r24,     SR_DR   ; (17)
	out   SR_DR,   r25
	ldi   r25,     5       ; ( 1)
	dec   r25
	brne  .-4              ; (15)
	nop                    ; (16)
	in    r25,     SR_DR   ; (17)
	sbi   SR_PORT, SR_PIN  ; Deselect SPI RAM
	ret



/*
** void XRAM_WriteU16(u8 bank, u16 addr, u16 val);
** void XRAM_WriteS16(u8 bank, u16 addr, s16 val);
**
** Writes unsigned or signed 16 bit value to SPI RAM.
**
** Inputs:
**     r24: Bank (low bit used to select low / high 64K)
** r23:r22: Address
** r21:r20: Value
** Clobbers:
** r25
*/
.global XRAM_WriteU16
.global XRAM_WriteS16
.section .text.XRAM_WriteS16
XRAM_WriteS16:
	jmp   XRAM_WriteU16
.section .text.XRAM_WriteU16
XRAM_WriteU16:

	cbi   SR_PORT, SR_PIN  ; Select SPI RAM
	ldi   r25,     0x02    ; Write to SPI RAM
	out   SR_DR,   r25     ; Send write command
	call  spiram_address
	ldi   r25,     2       ; ( 5)
	rcall spiramwriteu16_wxx
	out   SR_DR,   r20
	rcall spiramwriteu16_w17
	out   SR_DR,   r21
	rcall spiramwriteu16_w17
	sbi   SR_PORT, SR_PIN  ; Deselect SPI RAM
	ret

spiramwriteu16_w17:
	nop
	ldi   r25,     3
spiramwriteu16_wxx:
	dec   r25
	brne  .-4
	ret                    ; (17) With rcall



/*
** u32 XRAM_ReadU32(u8 bank, u16 addr);
** s32 XRAM_ReadS32(u8 bank, u16 addr);
**
** Reads unsigned or signed 32 bit value from SPI RAM.
**
** Inputs:
**     r24: Bank (low bit used to select low / high 64K)
** r23:r22: Address
** Outputs:
** r25:r24:r23:r22: 32bit read
** Clobbers:
** (Nothing)
*/
.global XRAM_ReadU32
.global XRAM_ReadS32
.section .text.XRAM_ReadS32
XRAM_ReadS32:
	jmp   XRAM_ReadU32
.section .text.XRAM_ReadU32
XRAM_ReadU32:

	cbi   SR_PORT, SR_PIN  ; Select SPI RAM
	ldi   r25,     0x03    ; Read from SPI RAM
	out   SR_DR,   r25     ; Send read command
	call  spiram_address
	rcall spiramreadu32_w12
	ldi   r25,     0xFF    ; (17) Dummy for the read
	out   SR_DR,   r25
	rcall spiramreadu32_w16
	in    r22,     SR_DR   ; (17)
	out   SR_DR,   r25
	rcall spiramreadu32_w16
	in    r23,     SR_DR   ; (17)
	out   SR_DR,   r25
	rcall spiramreadu32_w16
	in    r24,     SR_DR   ; (17)
	out   SR_DR,   r25
	rcall spiramreadu32_w16
	in    r25,     SR_DR   ; (17)
	sbi   SR_PORT, SR_PIN  ; Deselect SPI RAM
	ret

spiramreadu32_w16:
	rjmp  .
	rjmp  .
spiramreadu32_w12:
	rjmp  .
	lpm   r25,     Z
	ret                    ; (16) With rcall



/*
** void XRAM_WriteU32(u8 bank, u16 addr, u32 val);
** void XRAM_WriteS32(u8 bank, u16 addr, s32 val);
**
** Writes unsigned or signed 32 bit value to SPI RAM.
**
** Inputs:
**     r24: Bank (low bit used to select low / high 64K)
** r23:r22: Address
** r21:r20:r19:r18: Value
** Clobbers:
** r25
*/
.global XRAM_WriteU32
.global XRAM_WriteS32
.section .text.XRAM_WriteS32
XRAM_WriteS32:
	jmp   XRAM_WriteU32
.section .text.XRAM_WriteU32
XRAM_WriteU32:

	cbi   SR_PORT, SR_PIN  ; Select SPI RAM
	ldi   r25,     0x02    ; Write to SPI RAM
	out   SR_DR,   r25     ; Send write command
	call  spiram_address
	ldi   r25,     2       ; ( 5)
	rcall spiramwriteu32_wxx
	out   SR_DR,   r18
	rcall spiramwriteu32_w17
	out   SR_DR,   r19
	rcall spiramwriteu32_w17
	out   SR_DR,   r20
	rcall spiramwriteu32_w17
	out   SR_DR,   r21
	rcall spiramwriteu32_w17
	sbi   SR_PORT, SR_PIN  ; Deselect SPI RAM
	ret

spiramwriteu32_w17:
	nop
	ldi   r25,     3
spiramwriteu32_wxx:
	dec   r25
	brne  .-4
	ret                    ; (17) With rcall



/*
** void XRAM_ReadInto(u8 bank, u16 addr, void* dst, u16 len);
**
** Reads into RAM from SPI RAM.
**
** Inputs:
**     r24: Bank (low bit used to select low / high 64K)
** r23:r22: Address
** r21:r20: Destination (pointer)
** r19:r18: Count of bytes to read (must be nonzero)
** Clobbers:
** X, r25, r24, r19, r18
*/
.global XRAM_ReadInto
.section .text.XRAM_ReadInto
XRAM_ReadInto:

	cbi   SR_PORT, SR_PIN  ; Select SPI RAM
	ldi   r25,     0x03    ; Read from SPI RAM
	out   SR_DR,   r25     ; Send read command
	call  spiram_address
	ldi   r25,     4       ; ( 5)
	dec   r25
	brne  .-4              ; (16)
	ldi   r25,     0xFF    ; (17) Dummy for the reads
	out   SR_DR,   r25
	movw  XL,      r20     ; ( 1)
	nop                    ; ( 2)
	rjmp  .                ; ( 4)
spiramri_loop:
	subi  r18,     1       ; ( 5)
	sbci  r19,     0       ; ( 6)
	breq  spiramri_endl    ; ( 7 /  8)
	ldi   r24,     3
	dec   r24
	brne  .-4              ; (16)
	in    r24,     SR_DR   ; (17)
	out   SR_DR,   r25     ; (18 = 0)
	st    X+,      r24     ; ( 2)
	rjmp  spiramri_loop    ; ( 4)
spiramri_endl:
	lpm   r24,     Z       ; (11)
	lpm   r24,     Z       ; (14)
	rjmp  .                ; (16)
	in    r24,     SR_DR   ; (17)
	st    X+,      r24     ;
	sbi   SR_PORT, SR_PIN  ; Deselect SPI RAM
	ret



/*
** void XRAM_WriteFrom(u8 bank, u16 addr, void* src, u16 len);
**
** Writes from RAM to SPI RAM.
**
** Inputs:
**     r24: Bank (low bit used to select low / high 64K)
** r23:r22: Address
** r21:r20: Source (pointer)
** r19:r18: Count of bytes to write (must be nonzero)
** Clobbers:
** X, r25, r19, r18
*/
.global XRAM_WriteFrom
.section .text.XRAM_WriteFrom
XRAM_WriteFrom:

	cbi   SR_PORT, SR_PIN  ; Select SPI RAM
	ldi   r25,     0x02    ; Write to SPI RAM
	out   SR_DR,   r25     ; Send write command
	call  spiram_address
	movw  XL,      r20     ; ( 5)
spiramwf_loop:
	ldi   r25,     3       ; ( 6)
	dec   r25
	brne  .-4              ; (14)
	nop                    ; (15)
	ld    r25,     X+      ; (17)
	out   SR_DR,   r25
	subi  r18,     1       ; ( 1)
	sbci  r19,     0       ; ( 2)
	nop                    ; ( 3)
	brne  spiramwf_loop    ; ( 4 /  5)
	ldi   r25,     4       ; ( 6)
	dec   r25
	brne  .-4              ; (17) Data certainly clocked out
	sbi   SR_PORT, SR_PIN  ; Deselect SPI RAM
	ret



/*
** void XRAM_SeqReadStart(u8 bank, u16 addr);
**
** Starts a sequential read from SPI RAM.
**
** Inputs:
**     r24: Bank (low bit used to select low / high 64K)
** r23:r22: Address
** Clobbers:
** r25
*/
.global XRAM_SeqReadStart
.section .text.XRAM_SeqReadStart
XRAM_SeqReadStart:

	cbi   SR_PORT, SR_PIN  ; Select SPI RAM
	ldi   r25,     0x03    ; Read from SPI RAM
	out   SR_DR,   r25     ; Send read command
	call  spiram_address
	ldi   r25,     4       ; ( 5)
	dec   r25
	brne  .-4              ; (16)
	ldi   r25,     0xFF    ; (17) Dummy for the read
	out   SR_DR,   r25
	ret                    ; ( 4)



/*
** u8 XRAM_SeqReadU8(void);
** s8 XRAM_SeqReadS8(void);
**
** Sequentially reads unsigned or signed 8 bit value from SPI RAM.
**
** Outputs:
** r25:r24: Byte read (r25: zero)
** Clobbers:
** (Nothing)
*/
.global XRAM_SeqReadU8
.global XRAM_SeqReadS8
.section .text.XRAM_SeqReadS8
XRAM_SeqReadS8:
	jmp   XRAM_SeqReadU8
.section .text.XRAM_SeqReadU8
XRAM_SeqReadU8:

	ldi   r25,     2       ; ( 9) (assume ret + call before)
	dec   r25
	brne  .-4              ; (14)
	rjmp  .                ; (16)
	in    r24,     SR_DR
	out   SR_DR,   r25
	ret                    ; ( 4)



/*
** u16 XRAM_SeqReadU16(void);
** s16 XRAM_SeqReadS16(void);
**
** Sequentially reads unsigned or signed 16 bit value from SPI RAM.
**
** Outputs:
** r25:r24: Word read
** Clobbers:
** (Nothing)
*/
.global XRAM_SeqReadU16
.global XRAM_SeqReadS16
.section .text.XRAM_SeqReadS16
XRAM_SeqReadS16:
	jmp   XRAM_SeqReadU16
.section .text.XRAM_SeqReadU16
XRAM_SeqReadU16:

	ldi   r25,     0       ; ( 9) (assume ret + call before)
	rcall spiramsr16_w7    ; (16)
	in    r24,     SR_DR
	out   SR_DR,   r25
	rcall spiramsr16_w16
	in    r25,     SR_DR   ; (17)
	out   SR_DR,   r25
	ret                    ; ( 4)

spiramsr16_w16:
	ldi   r25,     3
	dec   r25
	brne  .-4
spiramsr16_w7:
	ret                    ; (16) With rcall



/*
** u32 XRAM_SeqReadU32(void);
** s32 XRAM_SeqReadS32(void);
**
** Sequentially reads unsigned or signed 32 bit value from SPI RAM.
**
** Outputs:
** r25:r24:r23:r22: 32 bit read
** Clobbers:
** (Nothing)
*/
.global XRAM_SeqReadU32
.global XRAM_SeqReadS32
.section .text.XRAM_SeqReadS32
XRAM_SeqReadS32:
	jmp   XRAM_SeqReadU32
.section .text.XRAM_SeqReadU32
XRAM_SeqReadU32:

	ldi   r25,     0       ; ( 9) (assume ret + call before)
	rcall spiramsr32_w7    ; (16)
	in    r22,     SR_DR
	out   SR_DR,   r25
	rcall spiramsr32_w16
	in    r23,     SR_DR   ; (17)
	out   SR_DR,   r25
	rcall spiramsr32_w16
	in    r24,     SR_DR   ; (17)
	out   SR_DR,   r25
	rcall spiramsr32_w16
	in    r25,     SR_DR   ; (17)
	out   SR_DR,   r25
	ret                    ; ( 4)

spiramsr32_w16:
	ldi   r25,     3
	dec   r25
	brne  .-4
spiramsr32_w7:
	ret                    ; (16) With rcall



/*
** void XRAM_SeqReadInto(void* dst, u16 len);
**
** Sequentally reads into RAM from SPI RAM.
**
** Inputs:
** r25:r24: Destination (pointer)
** r23:r22: Count of bytes to read (must be nonzero)
** Clobbers:
** X, r25, r24, r23, r22
*/
.global XRAM_SeqReadInto
.section .text.XRAM_SeqReadInto
XRAM_SeqReadInto:

	movw  XL,      r24     ; ( 9) (assume ret + call before)
	ldi   r25,     0       ; (10)
	rjmp  spiramsri_w      ; (12)
spiramsri_loop:
	subi  r22,     1       ; (15)
	sbci  r23,     0       ; (16)
	in    r24,     SR_DR   ; (17)
	out   SR_DR,   r25     ; (18 = 0)
	st    X+,      r24     ; ( 2)
	brne  .+2              ; ( 3 /  4)
	ret                    ; ( 7)
	lpm   r24,     Z       ; ( 7)
	lpm   r24,     Z       ; (10)
	rjmp  .                ; (12)
spiramsri_w:
	rjmp  spiramsri_loop   ; (14)



/*
** void XRAM_SeqReadEnd(void);
**
** Terminates sequential SPI RAM read.
**
** Clobbers:
** r25
*/
.global XRAM_SeqReadEnd
.section .text.XRAM_SeqReadEnd
XRAM_SeqReadEnd:

	ldi   r25,     3       ; ( 9) (assume ret + call before)
	dec   r25
	brne  .-4              ; (17) Last out should be completed at this point
	sbi   SR_PORT, SR_PIN  ; Deselect SPI RAM
	ret                    ; ( 4)



/*
** void XRAM_SeqWriteStart(u8 bank, u16 addr);
**
** Starts a sequential write to SPI RAM.
**
** Inputs:
**     r24: Bank (low bit used to select low / high 64K)
** r23:r22: Address
** Clobbers:
** r25
*/
.global XRAM_SeqWriteStart
.section .text.XRAM_SeqWriteStart
XRAM_SeqWriteStart:

	cbi   SR_PORT, SR_PIN  ; Select SPI RAM
	ldi   r25,     0x02    ; Write to SPI RAM
	out   SR_DR,   r25     ; Send write command
	nop                    ; ( 1)
	jmp   spiram_address   ; ( 4)



/*
** void XRAM_SeqWriteU8(u8 val);
** void XRAM_SeqWriteS8(s8 val);
**
** Sequentially writes unsigned or signed 8 bit value to SPI RAM.
**
** Inputs:
**     r24: Value
** Clobbers:
** r25
*/
.global XRAM_SeqWriteU8
.global XRAM_SeqWriteS8
.section .text.XRAM_SeqWriteS8
XRAM_SeqWriteS8:
	jmp   XRAM_SeqWriteU8
.section .text.XRAM_SeqWriteU8
XRAM_SeqWriteU8:

	ldi   r25,     3       ; ( 9) (assume ret + call before)
	dec   r25
	brne  .-4              ; (17)
	out   SR_DR,   r24
	ret                    ; ( 4)



/*
** void XRAM_SeqWriteU16(u16 val);
** void XRAM_SeqWriteS16(s16 val);
**
** Sequentially writes unsigned or signed 16 bit value to SPI RAM.
**
** Inputs:
** r25:r24: Value
** Clobbers:
** r23
*/
.global XRAM_SeqWriteU16
.global XRAM_SeqWriteS16
.section .text.XRAM_SeqWriteS16
XRAM_SeqWriteS16:
	jmp   XRAM_SeqWriteU16
.section .text.XRAM_SeqWriteU16
XRAM_SeqWriteU16:

	ldi   r23,     3       ; ( 9) (assume ret + call before)
	dec   r23
	brne  .-4              ; (17)
	out   SR_DR,   r24
	ldi   r23,     5
	dec   r23
	brne  .-4              ; (15)
	rjmp  .                ; (17)
	out   SR_DR,   r25
	ret                    ; ( 4)



/*
** void XRAM_SeqWriteU32(u32 val);
** void XRAM_SeqWriteS32(s32 val);
**
** Sequentially writes unsigned or signed 32 bit value to SPI RAM.
**
** Inputs:
** r25:r24:r23:r22 Value
** Clobbers:
** r21
*/
.global XRAM_SeqWriteU32
.global XRAM_SeqWriteS32
.section .text.XRAM_SeqWriteS32
XRAM_SeqWriteS32:
	jmp   XRAM_SeqWriteU32
.section .text.XRAM_SeqWriteU32
XRAM_SeqWriteU32:

	nop                    ; ( 9) (assume ret + call before)
	rcall spiramsw32_w8
	out   SR_DR,   r22
	rcall spiramsw32_w17
	out   SR_DR,   r23
	rcall spiramsw32_w17
	out   SR_DR,   r24
	rcall spiramsw32_w17
	out   SR_DR,   r25
	ret                    ; ( 4)

spiramsw32_w17:
	ldi   r21,     3
	dec   r21
	brne  .-4
spiramsw32_w8:
	nop
	ret                    ; (17) With rcall



/*
** void XRAM_SeqWriteFrom(void* src, u16 len);
**
** Sequentally writes from RAM to SPI RAM.
**
** Inputs:
** r25:r24: Source (pointer)
** r23:r22: Count of bytes to write (must be nonzero)
** Clobbers:
** X, r25, r24, r23, r22
*/
.global XRAM_SeqWriteFrom
.section .text.XRAM_SeqWriteFrom
XRAM_SeqWriteFrom:

	movw  XL,      r24     ; ( 9) (assume ret + call before)
	rjmp  .                ; (11)
	rjmp  spiramswf_w      ; (13)
spiramswf_loop:
	subi  r22,     1       ; (14)
	sbci  r23,     0       ; (15)
	ld    r24,     X+      ; (17)
	out   SR_DR,   r24     ; (18 = 0)
	brne  .+2              ; ( 1 /  2)
	ret                    ; ( 5)
	ldi   r24,     3       ; ( 3)
	dec   r24
	brne  .-4              ; (11)
spiramswf_w:
	rjmp  spiramswf_loop   ; (13)



/*
** void XRAM_SeqWriteEnd(void);
**
** Terminates sequential SPI RAM write.
**
** Clobbers:
** r25
*/
.global XRAM_SeqWriteEnd
.section .text.XRAM_SeqWriteEnd
XRAM_SeqWriteEnd:
	jmp   XRAM_SeqReadEnd



/*
** Internal function to perform an address write to the SPI RAM.
** Enters 4 cycles after the command out.
** Returns 4 cycles after the last address out.
**
** Inputs:
**     r24: Bank (low bit used to select low / high 64K)
** r23:r22: Address
** Clobbers:
** r25
*/
.section .text.spiram_address
spiram_address:

	ldi   r25,     2       ; ( 5)
	rcall spiram_address_wxx
	out   SR_DR,   r24     ; Address bits 16 - 23
	rcall spiram_address_w17
	out   SR_DR,   r23     ; Address bits 8 - 15
	rcall spiram_address_w17
	out   SR_DR,   r22     ; Address bits 0 - 7
	ret                    ; ( 4)

spiram_address_w17:
	nop
	ldi   r25,     3
spiram_address_wxx:
	dec   r25
	brne  .-4
	ret                    ; (17) With rcall
