/*
 *  Uzebox Square Kernel - Video Mode 0
 *  Copyright (C) 2018 Sandor Zsuga (Jubatian)
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
 *
 *  Uzebox is a reserved trade mark
*/


;
; Video Mode 0 for the Square Kernel is the SPI RAM 4bpp video mode.
;
; GPIOR0: bit 7: Internal: SPI RAM bitmap (1) / Tiled (0)
; GPIOR0: bit 6: If set, SPI RAM bitmap uses Color 0 replace
; GPIOR0: bit 5: If set, superwide mode (232 x 200 bitmap)
; GPIOR0: bit 4: If set, Tiled mode uses Color 0 replace
;


.section .text



;
; Lead-in code, preparing for video mode display
;
; Enters in cycle 681
;

vm0_leadin:

	; Discard stack as return will happen to a designated frame routine
	; (whatever the display frame interrupted is cut off completely).
	;
	; 2 cycles; at 681

	ldi   ZL,     0xFF
	out   _SFR_IO_ADDR(SPL), ZL

	; Set up COMPB to generate line end interrupts. Superwide mode has it
	; 72 clocks (2 tiles) later.
	;
	; 16 cycles; at 683

	ldi   ZL,      lo8(1497)
	ldi   ZH,      hi8(1497)
	sbic  _SFR_IO_ADDR(GPIOR0), 5
	ldi   ZL,      lo8(1497 + 72)
	sbic  _SFR_IO_ADDR(GPIOR0), 5
	ldi   ZH,      hi8(1497 + 72)
	sts   _SFR_MEM_ADDR(OCR1BH), ZH
	sts   _SFR_MEM_ADDR(OCR1BL), ZL
	ldi   ZL,      (1 << OCF1B) ; Clear COMPB IT flag
	sts   _SFR_MEM_ADDR(TIFR1), ZL
	ldi   ZL,      (1 << OCIE1B) ; Generate IT on match, but no longer for COMPA
	sts   _SFR_MEM_ADDR(TIMSK1), ZL

	; If an SPI RAM operation was halted, then just deselect the chip, so
	; a new operation can be started.
	;
	; 2 cycles; at 699

	sbi   _SFR_IO_ADDR(PORTA), PA4 ; Deselect SPI RAM

	; Calculate split regions
	;
	; 13 cycles; at 701

	lds   r24,     sq_video_split
	sbic  _SFR_IO_ADDR(GPIOR0), 5
	ldi   r24,     0       ; Superwide: Force full screen SPI bitmap
	lds   r0,      sq_video_shrink
	ldi   r25,     200
	sub   r25,     r0
	sub   r25,     r0
	cp    r24,     r25
	brcs  .+2
	mov   r24,     r25
	sub   r25,     r24

	; Init the RAM tile list, masking out high bits of column addresses.
	; This allows for using the high 3 bits for other stuff such as tile
	; importance.
	;
	; 453 cycles; at 714

	cpi   r24,     0
	brne  0f
	WAIT  ZL,      449
	rjmp  1f
0:
	ldi   ZL,      0
	ldi   ZH,      hi8(sq_ramt_list)
	ldi   XL,      255
	st    Z+,      XL

	ldi   XL,      5
0:
	ldd   r18,     Z + 0
	andi  r18,     0x1F
	std   Z + 0,   r18
	ldd   r18,     Z + 3
	andi  r18,     0x1F
	std   Z + 3,   r18
	ldd   r18,     Z + 6
	andi  r18,     0x1F
	std   Z + 6,   r18
	ldd   r18,     Z + 9
	andi  r18,     0x1F
	std   Z + 9,   r18
	ldd   r18,     Z + 12
	andi  r18,     0x1F
	std   Z + 12,  r18
	ldd   r18,     Z + 15
	andi  r18,     0x1F
	std   Z + 15,  r18
	ldd   r18,     Z + 18
	andi  r18,     0x1F
	std   Z + 18,  r18
	ldd   r18,     Z + 21
	andi  r18,     0x1F
	std   Z + 21,  r18
	ldd   r18,     Z + 24
	andi  r18,     0x1F
	std   Z + 24,  r18
	ldd   r18,     Z + 27
	andi  r18,     0x1F
	std   Z + 27,  r18
	ldd   r18,     Z + 30
	andi  r18,     0x1F
	std   Z + 30,  r18
	ldd   r18,     Z + 33
	andi  r18,     0x1F
	std   Z + 33,  r18
	ldd   r18,     Z + 36
	andi  r18,     0x1F
	std   Z + 36,  r18
	ldd   r18,     Z + 39
	andi  r18,     0x1F
	std   Z + 39,  r18
	ldd   r18,     Z + 42
	andi  r18,     0x1F
	std   Z + 42,  r18
	ldd   r18,     Z + 45
	andi  r18,     0x1F
	std   Z + 45,  r18
	ldd   r18,     Z + 48
	andi  r18,     0x1F
	std   Z + 48,  r18
	subi  ZL,      -51
	dec   XL
	brne  0b
1:

	; Load tiled palette (dummy in full screen SPI RAM bitmap modes, no
	; problem).
	;
	; 34 + 2 cycles; at 1167

	cbi   _SFR_IO_ADDR(PORTA), PA4 ; Select SPI RAM

	ldi   ZL,      lo8(sq_pal_tiled)
	ldi   ZH,      hi8(sq_pal_tiled)
	ld    r2,      Z+
	ld    r3,      Z+
	ld    r4,      Z+
	ld    r5,      Z+
	ld    r6,      Z+
	ld    r7,      Z+
	ld    r8,      Z+
	ld    r9,      Z+
	ld    r10,     Z+
	ld    r11,     Z+
	ld    r12,     Z+
	ld    r13,     Z+
	ld    r14,     Z+
	ld    r15,     Z+
	ld    r16,     Z+
	ld    r17,     Z+

	; Prepare Color 0 replace
	;
	; 8 cycles; at 1203

	lds   r0,      sq_color0_ptr + 0
	sts   vm_col0_ptr + 0, r0
	lds   r0,      sq_color0_ptr + 1
	sts   vm_col0_ptr + 1, r0

	; Prepare some common items
	;
	; 3 + 2 cycles; at 1211

	ldi   r19,     32      ; For tile size in multiplies

	ldi   XL,      0x03    ; SPI RAM: Read from it
	out   _SFR_IO_ADDR(SPDR), XL ; SPI RAM: Read command

	ldi   XH,      hi8(sq_ramt_list)
	ldi   YH,      hi8(sq_video_lbuf)

	; Branch off for appropriate preparation. If there are no tiled lines,
	; then SPI bitmap has to be prepared, otherwise tiled.

	cpi   r24,     0
	brne  .+2
	rjmp  vm0_leadin_spi

	; Prepare for tiled

	ldi   r22,     0       ; Begin with 1st tile row (always as Y shift is only 0 - 7)
	lds   YL,      sq_ramt_list_ent ; 1st RAM tile in list (0 if no RAM tiles)
	sts   vm_tmp0, YL      ; Store 1st RAM tile away to start row preloading with it
	ldi   ZH,      hi8(sq_tile_rows)
	ldi   ZL,      lo8(sq_tile_rows)
	ldd   r23,     Z + 1
	clr   r0
	sbrc  r23,     7
	inc   r0
	out   _SFR_IO_ADDR(SPDR), r0 ; SPI RAM: Address bank
	lds   r21,     sq_video_yshift
	andi  r21,     7
	lsl   r21
	lsl   r21              ; Initial row select by Y shift
	lds   r20,     sq_tileset_pth
	ldd   r0,      Z + 2
	ldd   r1,      Z + 3
	lpm   ZL,      Z
	lpm   ZL,      Z
	out   _SFR_IO_ADDR(SPDR), r1 ; SPI RAM: Address high
	cbi   _SFR_IO_ADDR(GPIOR0), 7 ; Start in tiled mode

vm0_leadin_comm:

	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	out   _SFR_IO_ADDR(SPDR), r0 ; SPI RAM: Address low
	rjmp  .
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	out   _SFR_IO_ADDR(SPDR), r1 ; SPI RAM: Dummy to fetch first data

	; Superwide mode: Init X to image RAM begin

	sbic  _SFR_IO_ADDR(GPIOR0), 5
	ldi   XL,      lo8(sq_ramtiles_base)
	sbic  _SFR_IO_ADDR(GPIOR0), 5
	ldi   XH,      hi8(sq_ramtiles_base)

	; Wait, then let IT happen to start display
	;
	; at 1273

	sei                          ; Enter scanline by a COMPB interrupt
	nop
	rjmp  .-2                    ; This is aligned right for IT

vm0_leadin_spi:

	; Prepare for SPI bitmap

	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	lds   r0,      sq_bitmap_bank
	out   _SFR_IO_ADDR(SPDR), r0 ; SPI RAM: Address bank
	sbi   _SFR_IO_ADDR(GPIOR0), 7 ; Start in SPI RAM Bitmap mode
	lds   r0,      sq_bitmap_ptr + 0
	lds   r1,      sq_bitmap_ptr + 1
	rjmp  .
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	out   _SFR_IO_ADDR(SPDR), r1 ; SPI RAM: Address high
	rjmp  vm0_leadin_comm



;
; Lead-out code, cleaning up after display
;

vm0_leadout:

	; Set up COMPA to generate the usual HSync interrupts.

	ldi   ZL,      (1 << OCF1A) ; Clear COMPA IT flag
	sts   _SFR_MEM_ADDR(TIFR1), ZL
	ldi   ZL,      (1 << OCIE1A) ; Generate IT on match, but no longer for COMPB
	sts   _SFR_MEM_ADDR(TIMSK1), ZL
	sbi   _SFR_IO_ADDR(PORTA), PA4 ; Deselect SPI RAM

	; Return

	rjmp  sq_video_exit



;
; In-scanline register usage:
;
;  r0: r1: Temporary (multiplication, etc)
;  r2-r17: 16 colors, r2 is the background (Color 0 replacement)
;     r18: Column counter in preload, Jump target in visual part
;     r19: 32, used for multiplication of tile address
;     r20: ROM tileset base
;     r21: Row select (0, 4, 8, 12, 16, 20, 24, 28)
;     r22: Row counter to access row descriptors (increments by 4)
;     r23: Preloaded flags to use for current line tasks
;     r24: Remaining Tiled scanlines
;     r25: Remaining SPI Bitmap scanlines
;       X: Used to scan the RAM tile list (XH fixed to this bank)
;       Y: Used to write & read the line buffer (YH fixed to this bank)
;       Z: Used for progmem access, jumping & others
;


;
; Macro for a column's tile preloader (31 cycles)
;
.macro TILE_BLOCK tno
	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	cpi   r18,     \tno    ; ( 3) Column compare
	breq  0f
	mul   r0,      r19     ; ( 6) r19 = 32
	movw  ZL,      r0
	add   ZH,      r20     ; ( 8) r20: ROM tileset base
	add   ZL,      r21     ; ( 9) r21: Row select
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	rjmp  1f               ; (31)
0:
	ld    r0,      X+      ; ( 7)
	ld    XL,      X
	ld    r18,     X+
	mul   r0,      r19     ; (13) r19 = 32
	movw  ZL,      r0
	add   ZL,      r21     ; (15) r21: Row select
	ld    r0,      Z+
	st    Y+,      r0
	ld    r0,      Z+
	st    Y+,      r0
	ld    r0,      Z+
	st    Y+,      r0
	ld    r0,      Z+
	st    Y+,      r0
1:
.endm



sq_vm0_scanline:

	; Entry at 1488

	ldi   ZL,     0xFF     ; Discard stack
	out   _SFR_IO_ADDR(SPL), ZL
	sbic  _SFR_IO_ADDR(GPIOR0), 7
	rjmp  vm0_spibmp       ; (1493)

;
; Top tiled mode, each tile row scrolling independently
;

	ldi   YL,      lo8(sq_video_lbuf) ; Line buffer at its beginning
	lds   XL,      vm_tmp0 ; 1st RAM tile in list (0 if no RAM tiles)
	ld    r18,     X+      ; 1st RAM tile's column (255 is loaded there if no RAM tiles)

	; 1497; Column 0 (31cy)

	TILE_BLOCK     0x00

	; 1528; Column 1 (31cy)

	TILE_BLOCK     0x01

	; 1559; Column 2 (31cy)

	TILE_BLOCK     0x02

	; 1590; Column 3 (31cy)

	TILE_BLOCK     0x03

	; 1621; Column 4 (31cy)

	TILE_BLOCK     0x04

	; 1652; Column 5 (31cy)

	TILE_BLOCK     0x05

	; 1683; Column 6 (31cy)

	TILE_BLOCK     0x06

	; 1714; Column 7 (31cy)

	TILE_BLOCK     0x07

	; 1745; Column 8 (31cy)

	TILE_BLOCK     0x08

	; 1776; Column 9 (31cy)

	TILE_BLOCK     0x09

	; 1807; Column 10 (31cy + 12)

	nop
	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	cpi   r18,     0x0A    ; ( 3) Column compare
	breq  0f
	mul   r0,      r19     ; ( 6) r19 = 32
	movw  ZL,      r0
	add   ZH,      r20     ; ( 8) r20: ROM tileset base
	add   ZL,      r21     ; ( 9) r21: Row select
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; At cy 9
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	rjmp  1f               ; (31)
0:
	ld    r0,      X+      ; ( 7)
	ld    XL,      X
	ld    r18,     X+
	mul   r0,      r19     ; (13) r19 = 32
	movw  ZL,      r0
	add   ZL,      r21     ; (15) r21: Row select
	ld    r0,      Z+
	st    Y+,      r0
	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; At cy 9
	ld    r0,      Z+
	st    Y+,      r0
	ld    r0,      Z+
	st    Y+,      r0
	ld    r0,      Z+
	st    Y+,      r0
1:
	lds   ZL,      sq_mix_buf_rd
	ldi   ZH,      hi8(sq_mix_buf)
	ld    r1,      Z+
	sts   _SFR_MEM_ADDR(OCR2A), r1 ; At cy 29; Output sound sample
	sts   sq_mix_buf_rd, ZL

	;   30; Column 11 (31cy)

	TILE_BLOCK     0x0B

	;   61; Column 12 (31cy)

	TILE_BLOCK     0x0C

	;   92; Column 13 (31cy)

	TILE_BLOCK     0x0D

	;  123; Column 14 (31cy + 3)

	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	cpi   r18,     0x0E    ; ( 3) Column compare
	breq  0f
	mul   r0,      r19     ; ( 6) r19 = 32
	movw  ZL,      r0
	add   ZH,      r20     ; ( 8) r20: ROM tileset base
	add   ZL,      r21     ; ( 9) r21: Row select
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	nop
	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; At cy 145
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	rjmp  1f               ; (31)
0:
	ld    r0,      X+      ; ( 7)
	ld    XL,      X
	ld    r18,     X+
	mul   r0,      r19     ; (13) r19 = 32
	movw  ZL,      r0
	add   ZL,      r21     ; (15) r21: Row select
	ld    r0,      Z+
	st    Y+,      r0
	nop
	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; At cy 145
	ld    r0,      Z+
	st    Y+,      r0
	ld    r0,      Z+
	st    Y+,      r0
	ld    r0,      Z+
	st    Y+,      r0
1:

	;  157; Column 15 (31cy)

	TILE_BLOCK     0x0F

	;  188; Column 16 (31cy)

	TILE_BLOCK     0x10

	;  219; Column 17 (31cy)

	TILE_BLOCK     0x11

	;  250; Column 18 (31cy)

	TILE_BLOCK     0x12

	;  281; Column 19 (31cy)

	TILE_BLOCK     0x13

	;  312; Column 20 (31cy)

	TILE_BLOCK     0x14

	;  343; Column 21 (31cy)

	TILE_BLOCK     0x15

	;  374; Column 22 (31cy)

	TILE_BLOCK     0x16

	;  405; Column 23 (31cy)

	TILE_BLOCK     0x17

	;  436; Column 24 (31cy)

	TILE_BLOCK     0x18

	;  467; Column 25

	in    r0,      _SFR_IO_ADDR(SPDR)
	sbi   _SFR_IO_ADDR(PORTA), PA4 ; (+1) Deselect SPI RAM
	cpi   r18,     0x19    ; ( 3) Column 25
	brne  0f
	ld    r0,      X+      ; ( 6)
	rjmp  .
	mul   r0,      r19     ; (10) r19 = 32
	movw  ZL,      r0
	add   ZL,      r21     ; (12) r21: Row select
	ld    r0,      Z+
	st    Y+,      r0
	ld    r0,      Z+
	st    Y+,      r0
	cbi   _SFR_IO_ADDR(PORTA), PA4 ; (+2) Select SPI RAM
	ld    r0,      Z+
	st    Y+,      r0
	ld    r0,      Z+
	st    Y+,      r0
	rjmp  1f               ; (30)
0:
	mul   r0,      r19     ; ( 7) r19 = 32
	movw  ZL,      r0
	add   ZH,      r20     ; ( 9) r20: ROM tileset base
	add   ZL,      r21     ; (10) r21: Row select
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	cbi   _SFR_IO_ADDR(PORTA), PA4 ; (+2) Select SPI RAM
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0      ; (30)
1:

	;  500; Prepare next scanline

	sei                    ; Enable interrupts for next line end
	ldi   XL,      0x03    ; SPI RAM: Read from it
	out   _SFR_IO_ADDR(SPDR), XL ; ( 503) SPI RAM: Read command
	dec   r24              ; Remaining Tiled scanlines
	brne  vm0_preptiled    ; There are more, go for preparing those

;
; Transition to SPI RAM bitmap.
;

	lpm   ZL,      Z
	lpm   ZL,      Z
	nop
	lds   YL,      sq_bitmap_bank
	lds   r1,      sq_bitmap_ptr + 1
	lds   r0,      sq_bitmap_ptr + 0
	sbi   _SFR_IO_ADDR(GPIOR0), 7 ; Transitioned to SPI RAM Bitmap
	out   _SFR_IO_ADDR(SPDR), YL ; ( 521) SPI RAM: Address bank
	ldi   ZL,      5
	dec   ZL
	brne  .-4
	rjmp  vm0_tiled_comm

;
; Prepare next tile row.
;

vm0_preptiled:

	nop                    ; ( 507)
	subi  r21,     0xFC    ; ( 508) Row selector
	cpi   r21,     0x20
	brne  .+2
	subi  r22,     0xFC    ; ( 511) Tile row counter & low pointer increments
	andi  r21,     0x1F
	ldi   ZH,      hi8(sq_tile_rows)
	ldi   ZL,      lo8(sq_tile_rows)
	add   ZL,      r22
	ldd   XL,      Z + 1
	clr   r0
	sbrc  XL,      7
	inc   r0
	out   _SFR_IO_ADDR(SPDR), r0 ; ( 521) SPI RAM: Address bank
	movw  r0,      ZL
	mov   ZL,      r22     ; Prepare next row's fetches
	lsr   ZL
	lsr   ZL               ; Row select
	subi  ZL,      lo8(-(sq_ramt_list_ent))
	ldi   ZH,      hi8(  sq_ramt_list_ent )
	ld    YL,      Z       ; 1st RAM tile in list (0 if no RAM tiles)
	sts   vm_tmp0, YL      ; Store 1st RAM tile away to start row preloading with it
	movw  ZL,      r0
	rjmp  .                ; (Tileset for row was loaded here)
	ldd   r0,      Z + 2
	ldd   r1,      Z + 3

vm0_tiled_comm:

	out   _SFR_IO_ADDR(SPDR), r1 ; ( 539) SPI RAM: Address high
	lds   ZL,      vm_col0_ptr + 0
	lds   ZH,      vm_col0_ptr + 1
	sbic  _SFR_IO_ADDR(GPIOR0), 4
	ld    r2,      Z+      ; Color 0 replaced
	sbis  _SFR_IO_ADDR(GPIOR0), 4
	adiw  ZL,      1       ; No replacement, just increment pointer
	sts   vm_col0_ptr + 0, ZL
	sts   vm_col0_ptr + 1, ZH
	ldi   ZH,      5
	mov   YL,      r23
	mov   r23,     XL      ; Next scanline's horizontal shift
	andi  YL,      7
	out   _SFR_IO_ADDR(SPDR), r0 ; ( 557) SPI RAM: Address low
	ldi   r18,     hi8(pm(vm0_ram_jtab))
	lsr   YL
	brcc  1f
	subi  YL,      lo8(-(sq_video_lbuf))
	ld    ZL,      Y+
	mul   ZL,      ZH
	movw  ZL,      r0
	adiw  ZL,      1       ; Odd X shifts (1, 3, 5 and 7)
0:
	lpm   r0,      Z
	lpm   r0,      Z
	out   _SFR_IO_ADDR(SPDR), r1 ; ( 575 - ODD) SPI RAM: Dummy to clock in first read
	subi  ZH,      hi8(-(pm(vm0_ram_blocks)))
	rjmp  .
	ijmp                   ; ( 580 - ODD; 584 - EVEN)
1:
	subi  YL,      lo8(-(sq_video_lbuf))
	ld    ZL,      Y+
	mul   ZL,      ZH
	movw  ZL,      r0
	lpm   r0,      Z
	rjmp  0b               ; Even X shifts (0, 2, 4 and 6)

;
; First pixel is normally generated at 585 (total width is 900 cycles for the
; 200 pixels). Pixel width order is 4-5-4-5-...-4-5. On odd shifts the first
; pixel has to be output 1 cycle early as the order then is 5-4-...-5-4-5-5
; (due to the interrupt termination the last pixel is always 5 clocks wide).
; On odd pixels 3 extra cycles above this is also necessary so the code block
; can load the next byte & ZH for the next jump.
;



;
; SPI RAM bitmap. Enters in 1493 or 1565 in Superwide.
;
; Registers r18 - r23 may be used for temporaries.
;

vm0_spibmp_end:

	rjmp  vm0_leadout

vm0_spibmp:

	subi  r25,     1
	brcs  vm0_spibmp_end

	; 1495; Loads 0 - 4

	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	ldi   ZL,      lo8(sq_pal_bitmap)
	ldi   ZH,      hi8(sq_pal_bitmap)
	ld    r2,      Z+      ; Load palette
	ld    r3,      Z+
	ld    r4,      Z+
	ld    r5,      Z+
	ld    r6,      Z+
	ld    r7,      Z+
	ld    r8,      Z+
	in    r1,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r1
	ld    r9,      Z+
	ld    r10,     Z+
	ld    r11,     Z+
	ld    r12,     Z+
	ld    r13,     Z+
	ld    r14,     Z+
	ld    r15,     Z+
	ld    r16,     Z+
	in    r18,     _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r18
	ld    r17,     Z+
	lds   ZL,      vm_col0_ptr + 0
	lds   ZH,      vm_col0_ptr + 1
	sbic  _SFR_IO_ADDR(GPIOR0), 6
	ld    r2,      Z+      ; Color 0 replaced
	sbis  _SFR_IO_ADDR(GPIOR0), 6
	adiw  ZL,      1       ; No replacement, just increment pointer
	sts   vm_col0_ptr + 0, ZL
	sts   vm_col0_ptr + 1, ZH
	sei                    ; Enable interrupts for next line end
	in    r19,     _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r19
	ldi   YL,      lo8(sq_video_lbuf)
	sbic  _SFR_IO_ADDR(GPIOR0), 5
	rjmp  vm0_superwide    ; To superwide mode (+72 cycles there)
	st    Y+,      r0
	st    Y+,      r1
	st    Y+,      r18
	st    Y+,      r19
	lpm   ZL,      Z
	rjmp  .
	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	st    Y+,      r0
	rjmp  .

	; 1573; Loads 5 - 18

	ldi   ZH,      14
0:
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	rjmp  .
	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	st    Y+,      r0
	dec   ZH
	brne  0b

	;    5; Loads 19

	rjmp  .
	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; At cy 9
	nop
	ldi   ZH,      hi8(sq_mix_buf)
	lds   ZL,      sq_mix_buf_rd
	ld    r1,      Z+
	sts   sq_mix_buf_rd, ZL
	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	sts   _SFR_MEM_ADDR(OCR2A), r1 ; At cy 21; Output sound sample
	st    Y+,      r0

	;   23; Loads 20 - 25

	ldi   ZH,      6
0:
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	rjmp  .
	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	st    Y+,      r0
	dec   ZH
	brne  0b

	;  131; Loads 26

	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z       ; +2, aligning sync
	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; At cy 145
	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	st    Y+,      r0
	rjmp  .

	;  151; Loads 27 - 49

	ldi   ZH,      23
0:
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	rjmp  .
	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	st    Y+,      r0
	dec   ZH
	brne  0b

	;  565; Transfer to display

	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	nop
	ldi   r18,     hi8(pm(vm0_spi_jtab))
	ldi   YL,      lo8(sq_video_lbuf)
	ld    ZL,      Y+
	mov   ZH,      r18
	ijmp                   ; ( 582)



vm0_superwide:

	ld    ZL,      X+
	st    Y+,      ZL
	ld    ZL,      X+
	st    Y+,      ZL
	ld    ZL,      X+
	st    Y+,      ZL
	in    r20,     _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r20
	ld    ZL,      X+
	st    Y+,      ZL
	ld    ZL,      X+
	st    Y+,      ZL
	ld    ZL,      X+
	st    Y+,      ZL
	ld    ZL,      X+
	st    Y+,      ZL
	in    r21,     _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r21
	ld    ZL,      X+
	st    Y+,      ZL
	st    Y+,      r0
	st    Y+,      r1
	st    Y+,      r18
	st    Y+,      r19
	st    Y+,      r20
	st    Y+,      r21
	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	st    Y+,      r0
	rjmp  .

	; 1681; Loads 7 - 14

	ldi   ZH,      8
0:
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	rjmp  .
	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	st    Y+,      r0
	dec   ZH
	brne  0b

	;    5; Loads 15

	rjmp  .
	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; At cy 9
	nop
	ldi   ZH,      hi8(sq_mix_buf)
	lds   ZL,      sq_mix_buf_rd
	ld    r1,      Z+
	sts   sq_mix_buf_rd, ZL
	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	sts   _SFR_MEM_ADDR(OCR2A), r1 ; At cy 21; Output sound sample
	st    Y+,      r0

	;   23; Loads 16 - 21

	ldi   ZH,      6
0:
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	rjmp  .
	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	st    Y+,      r0
	dec   ZH
	brne  0b

	;  131; Loads 22

	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z       ; +2, aligning sync
	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; At cy 145
	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	st    Y+,      r0
	rjmp  .

	;  151; Loads 23 - 39

	ldi   ZH,      17
0:
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	rjmp  .
	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	st    Y+,      r0
	dec   ZH
	brne  0b

	;  457; Loads 40 - 41

	adiw  YL,      2
	ld    ZL,      X+
	st    Y+,      ZL
	ld    ZL,      X+
	st    Y+,      ZL
	ld    ZL,      X+
	in    r0,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r0
	st    Y+,      ZL
	ld    ZL,      X+
	st    Y+,      ZL
	ld    ZL,      X+
	st    Y+,      ZL
	ld    ZL,      X+
	st    Y+,      ZL
	ld    ZL,      X+
	in    r1,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r1
	st    Y+,      ZL
	ld    ZL,      X+
	st    Y+,      ZL
	sbiw  YL,      10
	st    Y+,      r0
	st    Y+,      r1

	;  501; Transfer to display

	rjmp  .
	ldi   r18,     hi8(pm(vm0_spi_jtab))
	ldi   YL,      lo8(sq_video_lbuf)
	ld    ZL,      Y+
	mov   ZH,      r18
	ijmp                   ; ( 510)



;
; Scanline display loop
;

;
; Loading from buffer:
;
; r2 - r17: Colors of pixels (px0, px1)
; r18:      Jump table location, high, should be hi8(pm(vm0_ram_jtab))
; Y:        Buffer pointer
; Z:        Used for jumping
;
.macro RAM_BLOCK px0, px1
	out   PIXOUT,  \px0
	ld    ZL,      Y+
	mov   ZH,      r18
	out   PIXOUT,  \px1
	ijmp
.endm

;
; Loading from SPI RAM:
;
; r2 - r17: Colors of pixels (px0, px1)
; r18:      Jump table location, high, should be hi8(pm(vm0_spi_jtab))
; Y:        Buffer pointer
; Z:        Used for jumping
;
.macro SPI_BLOCK px0, px1
	out   PIXOUT,  \px0
	in    ZL,      _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), ZL
	ldi   ZH,      hi8(pm(vm0_ram_jtab))
	out   PIXOUT,  \px1
	ijmp
.endm


.section .text512


vm0_ram_blocks:
vm0_ram_00: RAM_BLOCK r2,  r2
vm0_ram_01: RAM_BLOCK r2,  r3
vm0_ram_02: RAM_BLOCK r2,  r4
vm0_ram_03: RAM_BLOCK r2,  r5
vm0_ram_04: RAM_BLOCK r2,  r6
vm0_ram_05: RAM_BLOCK r2,  r7
vm0_ram_06: RAM_BLOCK r2,  r8
vm0_ram_07: RAM_BLOCK r2,  r9
vm0_ram_08: RAM_BLOCK r2,  r10
vm0_ram_09: RAM_BLOCK r2,  r11
vm0_ram_0A: RAM_BLOCK r2,  r12
vm0_ram_0B: RAM_BLOCK r2,  r13
vm0_ram_0C: RAM_BLOCK r2,  r14
vm0_ram_0D: RAM_BLOCK r2,  r15
vm0_ram_0E: RAM_BLOCK r2,  r16
vm0_ram_0F: RAM_BLOCK r2,  r17
vm0_ram_10: RAM_BLOCK r3,  r2
vm0_ram_11: RAM_BLOCK r3,  r3
vm0_ram_12: RAM_BLOCK r3,  r4
vm0_ram_13: RAM_BLOCK r3,  r5
vm0_ram_14: RAM_BLOCK r3,  r6
vm0_ram_15: RAM_BLOCK r3,  r7
vm0_ram_16: RAM_BLOCK r3,  r8
vm0_ram_17: RAM_BLOCK r3,  r9
vm0_ram_18: RAM_BLOCK r3,  r10
vm0_ram_19: RAM_BLOCK r3,  r11
vm0_ram_1A: RAM_BLOCK r3,  r12
vm0_ram_1B: RAM_BLOCK r3,  r13
vm0_ram_1C: RAM_BLOCK r3,  r14
vm0_ram_1D: RAM_BLOCK r3,  r15
vm0_ram_1E: RAM_BLOCK r3,  r16
vm0_ram_1F: RAM_BLOCK r3,  r17
vm0_ram_20: RAM_BLOCK r4,  r2
vm0_ram_21: RAM_BLOCK r4,  r3
vm0_ram_22: RAM_BLOCK r4,  r4
vm0_ram_23: RAM_BLOCK r4,  r5
vm0_ram_24: RAM_BLOCK r4,  r6
vm0_ram_25: RAM_BLOCK r4,  r7
vm0_ram_26: RAM_BLOCK r4,  r8
vm0_ram_27: RAM_BLOCK r4,  r9
vm0_ram_28: RAM_BLOCK r4,  r10
vm0_ram_29: RAM_BLOCK r4,  r11
vm0_ram_2A: RAM_BLOCK r4,  r12
vm0_ram_2B: RAM_BLOCK r4,  r13
vm0_ram_2C: RAM_BLOCK r4,  r14
vm0_ram_2D: RAM_BLOCK r4,  r15
vm0_ram_2E: RAM_BLOCK r4,  r16
vm0_ram_2F: RAM_BLOCK r4,  r17
vm0_ram_30: RAM_BLOCK r5,  r2
vm0_ram_31: RAM_BLOCK r5,  r3
vm0_ram_32: RAM_BLOCK r5,  r4
vm0_ram_33: RAM_BLOCK r5,  r5
vm0_ram_34: RAM_BLOCK r5,  r6
vm0_ram_35: RAM_BLOCK r5,  r7
vm0_ram_36: RAM_BLOCK r5,  r8
vm0_ram_37: RAM_BLOCK r5,  r9
vm0_ram_38: RAM_BLOCK r5,  r10
vm0_ram_39: RAM_BLOCK r5,  r11
vm0_ram_3A: RAM_BLOCK r5,  r12
vm0_ram_3B: RAM_BLOCK r5,  r13
vm0_ram_3C: RAM_BLOCK r5,  r14
vm0_ram_3D: RAM_BLOCK r5,  r15
vm0_ram_3E: RAM_BLOCK r5,  r16
vm0_ram_3F: RAM_BLOCK r5,  r17
vm0_ram_40: RAM_BLOCK r6,  r2
vm0_ram_41: RAM_BLOCK r6,  r3
vm0_ram_42: RAM_BLOCK r6,  r4
vm0_ram_43: RAM_BLOCK r6,  r5
vm0_ram_44: RAM_BLOCK r6,  r6
vm0_ram_45: RAM_BLOCK r6,  r7
vm0_ram_46: RAM_BLOCK r6,  r8
vm0_ram_47: RAM_BLOCK r6,  r9
vm0_ram_48: RAM_BLOCK r6,  r10
vm0_ram_49: RAM_BLOCK r6,  r11
vm0_ram_4A: RAM_BLOCK r6,  r12
vm0_ram_4B: RAM_BLOCK r6,  r13
vm0_ram_4C: RAM_BLOCK r6,  r14
vm0_ram_4D: RAM_BLOCK r6,  r15
vm0_ram_4E: RAM_BLOCK r6,  r16
vm0_ram_4F: RAM_BLOCK r6,  r17
vm0_ram_50: RAM_BLOCK r7,  r2
vm0_ram_51: RAM_BLOCK r7,  r3
vm0_ram_52: RAM_BLOCK r7,  r4
vm0_ram_53: RAM_BLOCK r7,  r5
vm0_ram_54: RAM_BLOCK r7,  r6
vm0_ram_55: RAM_BLOCK r7,  r7
vm0_ram_56: RAM_BLOCK r7,  r8
vm0_ram_57: RAM_BLOCK r7,  r9
vm0_ram_58: RAM_BLOCK r7,  r10
vm0_ram_59: RAM_BLOCK r7,  r11
vm0_ram_5A: RAM_BLOCK r7,  r12
vm0_ram_5B: RAM_BLOCK r7,  r13
vm0_ram_5C: RAM_BLOCK r7,  r14
vm0_ram_5D: RAM_BLOCK r7,  r15
vm0_ram_5E: RAM_BLOCK r7,  r16
vm0_ram_5F: RAM_BLOCK r7,  r17
vm0_ram_60: RAM_BLOCK r8,  r2
vm0_ram_61: RAM_BLOCK r8,  r3
vm0_ram_62: RAM_BLOCK r8,  r4
vm0_ram_63: RAM_BLOCK r8,  r5
vm0_ram_64: RAM_BLOCK r8,  r6
vm0_ram_65: RAM_BLOCK r8,  r7
vm0_ram_66: RAM_BLOCK r8,  r8
vm0_ram_67: RAM_BLOCK r8,  r9
vm0_ram_68: RAM_BLOCK r8,  r10
vm0_ram_69: RAM_BLOCK r8,  r11
vm0_ram_6A: RAM_BLOCK r8,  r12
vm0_ram_6B: RAM_BLOCK r8,  r13
vm0_ram_6C: RAM_BLOCK r8,  r14
vm0_ram_6D: RAM_BLOCK r8,  r15
vm0_ram_6E: RAM_BLOCK r8,  r16
vm0_ram_6F: RAM_BLOCK r8,  r17
vm0_ram_70: RAM_BLOCK r9,  r2
vm0_ram_71: RAM_BLOCK r9,  r3
vm0_ram_72: RAM_BLOCK r9,  r4
vm0_ram_73: RAM_BLOCK r9,  r5
vm0_ram_74: RAM_BLOCK r9,  r6
vm0_ram_75: RAM_BLOCK r9,  r7
vm0_ram_76: RAM_BLOCK r9,  r8
vm0_ram_77: RAM_BLOCK r9,  r9
vm0_ram_78: RAM_BLOCK r9,  r10
vm0_ram_79: RAM_BLOCK r9,  r11
vm0_ram_7A: RAM_BLOCK r9,  r12
vm0_ram_7B: RAM_BLOCK r9,  r13
vm0_ram_7C: RAM_BLOCK r9,  r14
vm0_ram_7D: RAM_BLOCK r9,  r15
vm0_ram_7E: RAM_BLOCK r9,  r16
vm0_ram_7F: RAM_BLOCK r9,  r17
vm0_ram_80: RAM_BLOCK r10, r2
vm0_ram_81: RAM_BLOCK r10, r3
vm0_ram_82: RAM_BLOCK r10, r4
vm0_ram_83: RAM_BLOCK r10, r5
vm0_ram_84: RAM_BLOCK r10, r6
vm0_ram_85: RAM_BLOCK r10, r7
vm0_ram_86: RAM_BLOCK r10, r8
vm0_ram_87: RAM_BLOCK r10, r9
vm0_ram_88: RAM_BLOCK r10, r10
vm0_ram_89: RAM_BLOCK r10, r11
vm0_ram_8A: RAM_BLOCK r10, r12
vm0_ram_8B: RAM_BLOCK r10, r13
vm0_ram_8C: RAM_BLOCK r10, r14
vm0_ram_8D: RAM_BLOCK r10, r15
vm0_ram_8E: RAM_BLOCK r10, r16
vm0_ram_8F: RAM_BLOCK r10, r17
vm0_ram_90: RAM_BLOCK r11, r2
vm0_ram_91: RAM_BLOCK r11, r3
vm0_ram_92: RAM_BLOCK r11, r4
vm0_ram_93: RAM_BLOCK r11, r5
vm0_ram_94: RAM_BLOCK r11, r6
vm0_ram_95: RAM_BLOCK r11, r7
vm0_ram_96: RAM_BLOCK r11, r8
vm0_ram_97: RAM_BLOCK r11, r9
vm0_ram_98: RAM_BLOCK r11, r10
vm0_ram_99: RAM_BLOCK r11, r11
vm0_ram_9A: RAM_BLOCK r11, r12
vm0_ram_9B: RAM_BLOCK r11, r13
vm0_ram_9C: RAM_BLOCK r11, r14
vm0_ram_9D: RAM_BLOCK r11, r15
vm0_ram_9E: RAM_BLOCK r11, r16
vm0_ram_9F: RAM_BLOCK r11, r17
vm0_ram_A0: RAM_BLOCK r12, r2
vm0_ram_A1: RAM_BLOCK r12, r3
vm0_ram_A2: RAM_BLOCK r12, r4
vm0_ram_A3: RAM_BLOCK r12, r5
vm0_ram_A4: RAM_BLOCK r12, r6
vm0_ram_A5: RAM_BLOCK r12, r7
vm0_ram_A6: RAM_BLOCK r12, r8
vm0_ram_A7: RAM_BLOCK r12, r9
vm0_ram_A8: RAM_BLOCK r12, r10
vm0_ram_A9: RAM_BLOCK r12, r11
vm0_ram_AA: RAM_BLOCK r12, r12
vm0_ram_AB: RAM_BLOCK r12, r13
vm0_ram_AC: RAM_BLOCK r12, r14
vm0_ram_AD: RAM_BLOCK r12, r15
vm0_ram_AE: RAM_BLOCK r12, r16
vm0_ram_AF: RAM_BLOCK r12, r17
vm0_ram_B0: RAM_BLOCK r13, r2
vm0_ram_B1: RAM_BLOCK r13, r3
vm0_ram_B2: RAM_BLOCK r13, r4
vm0_ram_B3: RAM_BLOCK r13, r5
vm0_ram_B4: RAM_BLOCK r13, r6
vm0_ram_B5: RAM_BLOCK r13, r7
vm0_ram_B6: RAM_BLOCK r13, r8
vm0_ram_B7: RAM_BLOCK r13, r9
vm0_ram_B8: RAM_BLOCK r13, r10
vm0_ram_B9: RAM_BLOCK r13, r11
vm0_ram_BA: RAM_BLOCK r13, r12
vm0_ram_BB: RAM_BLOCK r13, r13
vm0_ram_BC: RAM_BLOCK r13, r14
vm0_ram_BD: RAM_BLOCK r13, r15
vm0_ram_BE: RAM_BLOCK r13, r16
vm0_ram_BF: RAM_BLOCK r13, r17
vm0_ram_C0: RAM_BLOCK r14, r2
vm0_ram_C1: RAM_BLOCK r14, r3
vm0_ram_C2: RAM_BLOCK r14, r4
vm0_ram_C3: RAM_BLOCK r14, r5
vm0_ram_C4: RAM_BLOCK r14, r6
vm0_ram_C5: RAM_BLOCK r14, r7
vm0_ram_C6: RAM_BLOCK r14, r8
vm0_ram_C7: RAM_BLOCK r14, r9
vm0_ram_C8: RAM_BLOCK r14, r10
vm0_ram_C9: RAM_BLOCK r14, r11
vm0_ram_CA: RAM_BLOCK r14, r12
vm0_ram_CB: RAM_BLOCK r14, r13
vm0_ram_CC: RAM_BLOCK r14, r14
vm0_ram_CD: RAM_BLOCK r14, r15
vm0_ram_CE: RAM_BLOCK r14, r16
vm0_ram_CF: RAM_BLOCK r14, r17
vm0_ram_D0: RAM_BLOCK r15, r2
vm0_ram_D1: RAM_BLOCK r15, r3
vm0_ram_D2: RAM_BLOCK r15, r4
vm0_ram_D3: RAM_BLOCK r15, r5
vm0_ram_D4: RAM_BLOCK r15, r6
vm0_ram_D5: RAM_BLOCK r15, r7
vm0_ram_D6: RAM_BLOCK r15, r8
vm0_ram_D7: RAM_BLOCK r15, r9
vm0_ram_D8: RAM_BLOCK r15, r10
vm0_ram_D9: RAM_BLOCK r15, r11
vm0_ram_DA: RAM_BLOCK r15, r12
vm0_ram_DB: RAM_BLOCK r15, r13
vm0_ram_DC: RAM_BLOCK r15, r14
vm0_ram_DD: RAM_BLOCK r15, r15
vm0_ram_DE: RAM_BLOCK r15, r16
vm0_ram_DF: RAM_BLOCK r15, r17
vm0_ram_E0: RAM_BLOCK r16, r2
vm0_ram_E1: RAM_BLOCK r16, r3
vm0_ram_E2: RAM_BLOCK r16, r4
vm0_ram_E3: RAM_BLOCK r16, r5
vm0_ram_E4: RAM_BLOCK r16, r6
vm0_ram_E5: RAM_BLOCK r16, r7
vm0_ram_E6: RAM_BLOCK r16, r8
vm0_ram_E7: RAM_BLOCK r16, r9
vm0_ram_E8: RAM_BLOCK r16, r10
vm0_ram_E9: RAM_BLOCK r16, r11
vm0_ram_EA: RAM_BLOCK r16, r12
vm0_ram_EB: RAM_BLOCK r16, r13
vm0_ram_EC: RAM_BLOCK r16, r14
vm0_ram_ED: RAM_BLOCK r16, r15
vm0_ram_EE: RAM_BLOCK r16, r16
vm0_ram_EF: RAM_BLOCK r16, r17
vm0_ram_F0: RAM_BLOCK r17, r2
vm0_ram_F1: RAM_BLOCK r17, r3
vm0_ram_F2: RAM_BLOCK r17, r4
vm0_ram_F3: RAM_BLOCK r17, r5
vm0_ram_F4: RAM_BLOCK r17, r6
vm0_ram_F5: RAM_BLOCK r17, r7
vm0_ram_F6: RAM_BLOCK r17, r8
vm0_ram_F7: RAM_BLOCK r17, r9
vm0_ram_F8: RAM_BLOCK r17, r10
vm0_ram_F9: RAM_BLOCK r17, r11
vm0_ram_FA: RAM_BLOCK r17, r12
vm0_ram_FB: RAM_BLOCK r17, r13
vm0_ram_FC: RAM_BLOCK r17, r14
vm0_ram_FD: RAM_BLOCK r17, r15
vm0_ram_FE: RAM_BLOCK r17, r16
vm0_ram_FF: RAM_BLOCK r17, r17

vm0_ram_jtab:
	rjmp  vm0_ram_00
	rjmp  vm0_ram_01
	rjmp  vm0_ram_02
	rjmp  vm0_ram_03
	rjmp  vm0_ram_04
	rjmp  vm0_ram_05
	rjmp  vm0_ram_06
	rjmp  vm0_ram_07
	rjmp  vm0_ram_08
	rjmp  vm0_ram_09
	rjmp  vm0_ram_0A
	rjmp  vm0_ram_0B
	rjmp  vm0_ram_0C
	rjmp  vm0_ram_0D
	rjmp  vm0_ram_0E
	rjmp  vm0_ram_0F
	rjmp  vm0_ram_10
	rjmp  vm0_ram_11
	rjmp  vm0_ram_12
	rjmp  vm0_ram_13
	rjmp  vm0_ram_14
	rjmp  vm0_ram_15
	rjmp  vm0_ram_16
	rjmp  vm0_ram_17
	rjmp  vm0_ram_18
	rjmp  vm0_ram_19
	rjmp  vm0_ram_1A
	rjmp  vm0_ram_1B
	rjmp  vm0_ram_1C
	rjmp  vm0_ram_1D
	rjmp  vm0_ram_1E
	rjmp  vm0_ram_1F
	rjmp  vm0_ram_20
	rjmp  vm0_ram_21
	rjmp  vm0_ram_22
	rjmp  vm0_ram_23
	rjmp  vm0_ram_24
	rjmp  vm0_ram_25
	rjmp  vm0_ram_26
	rjmp  vm0_ram_27
	rjmp  vm0_ram_28
	rjmp  vm0_ram_29
	rjmp  vm0_ram_2A
	rjmp  vm0_ram_2B
	rjmp  vm0_ram_2C
	rjmp  vm0_ram_2D
	rjmp  vm0_ram_2E
	rjmp  vm0_ram_2F
	rjmp  vm0_ram_30
	rjmp  vm0_ram_31
	rjmp  vm0_ram_32
	rjmp  vm0_ram_33
	rjmp  vm0_ram_34
	rjmp  vm0_ram_35
	rjmp  vm0_ram_36
	rjmp  vm0_ram_37
	rjmp  vm0_ram_38
	rjmp  vm0_ram_39
	rjmp  vm0_ram_3A
	rjmp  vm0_ram_3B
	rjmp  vm0_ram_3C
	rjmp  vm0_ram_3D
	rjmp  vm0_ram_3E
	rjmp  vm0_ram_3F
	rjmp  vm0_ram_40
	rjmp  vm0_ram_41
	rjmp  vm0_ram_42
	rjmp  vm0_ram_43
	rjmp  vm0_ram_44
	rjmp  vm0_ram_45
	rjmp  vm0_ram_46
	rjmp  vm0_ram_47
	rjmp  vm0_ram_48
	rjmp  vm0_ram_49
	rjmp  vm0_ram_4A
	rjmp  vm0_ram_4B
	rjmp  vm0_ram_4C
	rjmp  vm0_ram_4D
	rjmp  vm0_ram_4E
	rjmp  vm0_ram_4F
	rjmp  vm0_ram_50
	rjmp  vm0_ram_51
	rjmp  vm0_ram_52
	rjmp  vm0_ram_53
	rjmp  vm0_ram_54
	rjmp  vm0_ram_55
	rjmp  vm0_ram_56
	rjmp  vm0_ram_57
	rjmp  vm0_ram_58
	rjmp  vm0_ram_59
	rjmp  vm0_ram_5A
	rjmp  vm0_ram_5B
	rjmp  vm0_ram_5C
	rjmp  vm0_ram_5D
	rjmp  vm0_ram_5E
	rjmp  vm0_ram_5F
	rjmp  vm0_ram_60
	rjmp  vm0_ram_61
	rjmp  vm0_ram_62
	rjmp  vm0_ram_63
	rjmp  vm0_ram_64
	rjmp  vm0_ram_65
	rjmp  vm0_ram_66
	rjmp  vm0_ram_67
	rjmp  vm0_ram_68
	rjmp  vm0_ram_69
	rjmp  vm0_ram_6A
	rjmp  vm0_ram_6B
	rjmp  vm0_ram_6C
	rjmp  vm0_ram_6D
	rjmp  vm0_ram_6E
	rjmp  vm0_ram_6F
	rjmp  vm0_ram_70
	rjmp  vm0_ram_71
	rjmp  vm0_ram_72
	rjmp  vm0_ram_73
	rjmp  vm0_ram_74
	rjmp  vm0_ram_75
	rjmp  vm0_ram_76
	rjmp  vm0_ram_77
	rjmp  vm0_ram_78
	rjmp  vm0_ram_79
	rjmp  vm0_ram_7A
	rjmp  vm0_ram_7B
	rjmp  vm0_ram_7C
	rjmp  vm0_ram_7D
	rjmp  vm0_ram_7E
	rjmp  vm0_ram_7F
	rjmp  vm0_ram_80
	rjmp  vm0_ram_81
	rjmp  vm0_ram_82
	rjmp  vm0_ram_83
	rjmp  vm0_ram_84
	rjmp  vm0_ram_85
	rjmp  vm0_ram_86
	rjmp  vm0_ram_87
	rjmp  vm0_ram_88
	rjmp  vm0_ram_89
	rjmp  vm0_ram_8A
	rjmp  vm0_ram_8B
	rjmp  vm0_ram_8C
	rjmp  vm0_ram_8D
	rjmp  vm0_ram_8E
	rjmp  vm0_ram_8F
	rjmp  vm0_ram_90
	rjmp  vm0_ram_91
	rjmp  vm0_ram_92
	rjmp  vm0_ram_93
	rjmp  vm0_ram_94
	rjmp  vm0_ram_95
	rjmp  vm0_ram_96
	rjmp  vm0_ram_97
	rjmp  vm0_ram_98
	rjmp  vm0_ram_99
	rjmp  vm0_ram_9A
	rjmp  vm0_ram_9B
	rjmp  vm0_ram_9C
	rjmp  vm0_ram_9D
	rjmp  vm0_ram_9E
	rjmp  vm0_ram_9F
	rjmp  vm0_ram_A0
	rjmp  vm0_ram_A1
	rjmp  vm0_ram_A2
	rjmp  vm0_ram_A3
	rjmp  vm0_ram_A4
	rjmp  vm0_ram_A5
	rjmp  vm0_ram_A6
	rjmp  vm0_ram_A7
	rjmp  vm0_ram_A8
	rjmp  vm0_ram_A9
	rjmp  vm0_ram_AA
	rjmp  vm0_ram_AB
	rjmp  vm0_ram_AC
	rjmp  vm0_ram_AD
	rjmp  vm0_ram_AE
	rjmp  vm0_ram_AF
	rjmp  vm0_ram_B0
	rjmp  vm0_ram_B1
	rjmp  vm0_ram_B2
	rjmp  vm0_ram_B3
	rjmp  vm0_ram_B4
	rjmp  vm0_ram_B5
	rjmp  vm0_ram_B6
	rjmp  vm0_ram_B7
	rjmp  vm0_ram_B8
	rjmp  vm0_ram_B9
	rjmp  vm0_ram_BA
	rjmp  vm0_ram_BB
	rjmp  vm0_ram_BC
	rjmp  vm0_ram_BD
	rjmp  vm0_ram_BE
	rjmp  vm0_ram_BF
	rjmp  vm0_ram_C0
	rjmp  vm0_ram_C1
	rjmp  vm0_ram_C2
	rjmp  vm0_ram_C3
	rjmp  vm0_ram_C4
	rjmp  vm0_ram_C5
	rjmp  vm0_ram_C6
	rjmp  vm0_ram_C7
	rjmp  vm0_ram_C8
	rjmp  vm0_ram_C9
	rjmp  vm0_ram_CA
	rjmp  vm0_ram_CB
	rjmp  vm0_ram_CC
	rjmp  vm0_ram_CD
	rjmp  vm0_ram_CE
	rjmp  vm0_ram_CF
	rjmp  vm0_ram_D0
	rjmp  vm0_ram_D1
	rjmp  vm0_ram_D2
	rjmp  vm0_ram_D3
	rjmp  vm0_ram_D4
	rjmp  vm0_ram_D5
	rjmp  vm0_ram_D6
	rjmp  vm0_ram_D7
	rjmp  vm0_ram_D8
	rjmp  vm0_ram_D9
	rjmp  vm0_ram_DA
	rjmp  vm0_ram_DB
	rjmp  vm0_ram_DC
	rjmp  vm0_ram_DD
	rjmp  vm0_ram_DE
	rjmp  vm0_ram_DF
	rjmp  vm0_ram_E0
	rjmp  vm0_ram_E1
	rjmp  vm0_ram_E2
	rjmp  vm0_ram_E3
	rjmp  vm0_ram_E4
	rjmp  vm0_ram_E5
	rjmp  vm0_ram_E6
	rjmp  vm0_ram_E7
	rjmp  vm0_ram_E8
	rjmp  vm0_ram_E9
	rjmp  vm0_ram_EA
	rjmp  vm0_ram_EB
	rjmp  vm0_ram_EC
	rjmp  vm0_ram_ED
	rjmp  vm0_ram_EE
	rjmp  vm0_ram_EF
	rjmp  vm0_ram_F0
	rjmp  vm0_ram_F1
	rjmp  vm0_ram_F2
	rjmp  vm0_ram_F3
	rjmp  vm0_ram_F4
	rjmp  vm0_ram_F5
	rjmp  vm0_ram_F6
	rjmp  vm0_ram_F7
	rjmp  vm0_ram_F8
	rjmp  vm0_ram_F9
	rjmp  vm0_ram_FA
	rjmp  vm0_ram_FB
	rjmp  vm0_ram_FC
	rjmp  vm0_ram_FD
	rjmp  vm0_ram_FE
	rjmp  vm0_ram_FF

vm0_spi_00: SPI_BLOCK r2,  r2
vm0_spi_01: SPI_BLOCK r2,  r3
vm0_spi_02: SPI_BLOCK r2,  r4
vm0_spi_03: SPI_BLOCK r2,  r5
vm0_spi_04: SPI_BLOCK r2,  r6
vm0_spi_05: SPI_BLOCK r2,  r7
vm0_spi_06: SPI_BLOCK r2,  r8
vm0_spi_07: SPI_BLOCK r2,  r9
vm0_spi_08: SPI_BLOCK r2,  r10
vm0_spi_09: SPI_BLOCK r2,  r11
vm0_spi_0A: SPI_BLOCK r2,  r12
vm0_spi_0B: SPI_BLOCK r2,  r13
vm0_spi_0C: SPI_BLOCK r2,  r14
vm0_spi_0D: SPI_BLOCK r2,  r15
vm0_spi_0E: SPI_BLOCK r2,  r16
vm0_spi_0F: SPI_BLOCK r2,  r17
vm0_spi_10: SPI_BLOCK r3,  r2
vm0_spi_11: SPI_BLOCK r3,  r3
vm0_spi_12: SPI_BLOCK r3,  r4
vm0_spi_13: SPI_BLOCK r3,  r5
vm0_spi_14: SPI_BLOCK r3,  r6
vm0_spi_15: SPI_BLOCK r3,  r7
vm0_spi_16: SPI_BLOCK r3,  r8
vm0_spi_17: SPI_BLOCK r3,  r9
vm0_spi_18: SPI_BLOCK r3,  r10
vm0_spi_19: SPI_BLOCK r3,  r11
vm0_spi_1A: SPI_BLOCK r3,  r12
vm0_spi_1B: SPI_BLOCK r3,  r13
vm0_spi_1C: SPI_BLOCK r3,  r14
vm0_spi_1D: SPI_BLOCK r3,  r15
vm0_spi_1E: SPI_BLOCK r3,  r16
vm0_spi_1F: SPI_BLOCK r3,  r17
vm0_spi_20: SPI_BLOCK r4,  r2
vm0_spi_21: SPI_BLOCK r4,  r3
vm0_spi_22: SPI_BLOCK r4,  r4
vm0_spi_23: SPI_BLOCK r4,  r5
vm0_spi_24: SPI_BLOCK r4,  r6
vm0_spi_25: SPI_BLOCK r4,  r7
vm0_spi_26: SPI_BLOCK r4,  r8
vm0_spi_27: SPI_BLOCK r4,  r9
vm0_spi_28: SPI_BLOCK r4,  r10
vm0_spi_29: SPI_BLOCK r4,  r11
vm0_spi_2A: SPI_BLOCK r4,  r12
vm0_spi_2B: SPI_BLOCK r4,  r13
vm0_spi_2C: SPI_BLOCK r4,  r14
vm0_spi_2D: SPI_BLOCK r4,  r15
vm0_spi_2E: SPI_BLOCK r4,  r16
vm0_spi_2F: SPI_BLOCK r4,  r17
vm0_spi_30: SPI_BLOCK r5,  r2
vm0_spi_31: SPI_BLOCK r5,  r3
vm0_spi_32: SPI_BLOCK r5,  r4
vm0_spi_33: SPI_BLOCK r5,  r5
vm0_spi_34: SPI_BLOCK r5,  r6
vm0_spi_35: SPI_BLOCK r5,  r7
vm0_spi_36: SPI_BLOCK r5,  r8
vm0_spi_37: SPI_BLOCK r5,  r9
vm0_spi_38: SPI_BLOCK r5,  r10
vm0_spi_39: SPI_BLOCK r5,  r11
vm0_spi_3A: SPI_BLOCK r5,  r12
vm0_spi_3B: SPI_BLOCK r5,  r13
vm0_spi_3C: SPI_BLOCK r5,  r14
vm0_spi_3D: SPI_BLOCK r5,  r15
vm0_spi_3E: SPI_BLOCK r5,  r16
vm0_spi_3F: SPI_BLOCK r5,  r17
vm0_spi_40: SPI_BLOCK r6,  r2
vm0_spi_41: SPI_BLOCK r6,  r3
vm0_spi_42: SPI_BLOCK r6,  r4
vm0_spi_43: SPI_BLOCK r6,  r5
vm0_spi_44: SPI_BLOCK r6,  r6
vm0_spi_45: SPI_BLOCK r6,  r7
vm0_spi_46: SPI_BLOCK r6,  r8
vm0_spi_47: SPI_BLOCK r6,  r9
vm0_spi_48: SPI_BLOCK r6,  r10
vm0_spi_49: SPI_BLOCK r6,  r11
vm0_spi_4A: SPI_BLOCK r6,  r12
vm0_spi_4B: SPI_BLOCK r6,  r13
vm0_spi_4C: SPI_BLOCK r6,  r14
vm0_spi_4D: SPI_BLOCK r6,  r15
vm0_spi_4E: SPI_BLOCK r6,  r16
vm0_spi_4F: SPI_BLOCK r6,  r17
vm0_spi_50: SPI_BLOCK r7,  r2
vm0_spi_51: SPI_BLOCK r7,  r3
vm0_spi_52: SPI_BLOCK r7,  r4
vm0_spi_53: SPI_BLOCK r7,  r5
vm0_spi_54: SPI_BLOCK r7,  r6
vm0_spi_55: SPI_BLOCK r7,  r7
vm0_spi_56: SPI_BLOCK r7,  r8
vm0_spi_57: SPI_BLOCK r7,  r9
vm0_spi_58: SPI_BLOCK r7,  r10
vm0_spi_59: SPI_BLOCK r7,  r11
vm0_spi_5A: SPI_BLOCK r7,  r12
vm0_spi_5B: SPI_BLOCK r7,  r13
vm0_spi_5C: SPI_BLOCK r7,  r14
vm0_spi_5D: SPI_BLOCK r7,  r15
vm0_spi_5E: SPI_BLOCK r7,  r16
vm0_spi_5F: SPI_BLOCK r7,  r17
vm0_spi_60: SPI_BLOCK r8,  r2
vm0_spi_61: SPI_BLOCK r8,  r3
vm0_spi_62: SPI_BLOCK r8,  r4
vm0_spi_63: SPI_BLOCK r8,  r5
vm0_spi_64: SPI_BLOCK r8,  r6
vm0_spi_65: SPI_BLOCK r8,  r7
vm0_spi_66: SPI_BLOCK r8,  r8
vm0_spi_67: SPI_BLOCK r8,  r9
vm0_spi_68: SPI_BLOCK r8,  r10
vm0_spi_69: SPI_BLOCK r8,  r11
vm0_spi_6A: SPI_BLOCK r8,  r12
vm0_spi_6B: SPI_BLOCK r8,  r13
vm0_spi_6C: SPI_BLOCK r8,  r14
vm0_spi_6D: SPI_BLOCK r8,  r15
vm0_spi_6E: SPI_BLOCK r8,  r16
vm0_spi_6F: SPI_BLOCK r8,  r17
vm0_spi_70: SPI_BLOCK r9,  r2
vm0_spi_71: SPI_BLOCK r9,  r3
vm0_spi_72: SPI_BLOCK r9,  r4
vm0_spi_73: SPI_BLOCK r9,  r5
vm0_spi_74: SPI_BLOCK r9,  r6
vm0_spi_75: SPI_BLOCK r9,  r7
vm0_spi_76: SPI_BLOCK r9,  r8
vm0_spi_77: SPI_BLOCK r9,  r9
vm0_spi_78: SPI_BLOCK r9,  r10
vm0_spi_79: SPI_BLOCK r9,  r11
vm0_spi_7A: SPI_BLOCK r9,  r12
vm0_spi_7B: SPI_BLOCK r9,  r13
vm0_spi_7C: SPI_BLOCK r9,  r14
vm0_spi_7D: SPI_BLOCK r9,  r15
vm0_spi_7E: SPI_BLOCK r9,  r16
vm0_spi_7F: SPI_BLOCK r9,  r17
vm0_spi_80: SPI_BLOCK r10, r2
vm0_spi_81: SPI_BLOCK r10, r3
vm0_spi_82: SPI_BLOCK r10, r4
vm0_spi_83: SPI_BLOCK r10, r5
vm0_spi_84: SPI_BLOCK r10, r6
vm0_spi_85: SPI_BLOCK r10, r7
vm0_spi_86: SPI_BLOCK r10, r8
vm0_spi_87: SPI_BLOCK r10, r9
vm0_spi_88: SPI_BLOCK r10, r10
vm0_spi_89: SPI_BLOCK r10, r11
vm0_spi_8A: SPI_BLOCK r10, r12
vm0_spi_8B: SPI_BLOCK r10, r13
vm0_spi_8C: SPI_BLOCK r10, r14
vm0_spi_8D: SPI_BLOCK r10, r15
vm0_spi_8E: SPI_BLOCK r10, r16
vm0_spi_8F: SPI_BLOCK r10, r17
vm0_spi_90: SPI_BLOCK r11, r2
vm0_spi_91: SPI_BLOCK r11, r3
vm0_spi_92: SPI_BLOCK r11, r4
vm0_spi_93: SPI_BLOCK r11, r5
vm0_spi_94: SPI_BLOCK r11, r6
vm0_spi_95: SPI_BLOCK r11, r7
vm0_spi_96: SPI_BLOCK r11, r8
vm0_spi_97: SPI_BLOCK r11, r9
vm0_spi_98: SPI_BLOCK r11, r10
vm0_spi_99: SPI_BLOCK r11, r11
vm0_spi_9A: SPI_BLOCK r11, r12
vm0_spi_9B: SPI_BLOCK r11, r13
vm0_spi_9C: SPI_BLOCK r11, r14
vm0_spi_9D: SPI_BLOCK r11, r15
vm0_spi_9E: SPI_BLOCK r11, r16
vm0_spi_9F: SPI_BLOCK r11, r17
vm0_spi_A0: SPI_BLOCK r12, r2
vm0_spi_A1: SPI_BLOCK r12, r3
vm0_spi_A2: SPI_BLOCK r12, r4
vm0_spi_A3: SPI_BLOCK r12, r5
vm0_spi_A4: SPI_BLOCK r12, r6
vm0_spi_A5: SPI_BLOCK r12, r7
vm0_spi_A6: SPI_BLOCK r12, r8
vm0_spi_A7: SPI_BLOCK r12, r9
vm0_spi_A8: SPI_BLOCK r12, r10
vm0_spi_A9: SPI_BLOCK r12, r11
vm0_spi_AA: SPI_BLOCK r12, r12
vm0_spi_AB: SPI_BLOCK r12, r13
vm0_spi_AC: SPI_BLOCK r12, r14
vm0_spi_AD: SPI_BLOCK r12, r15
vm0_spi_AE: SPI_BLOCK r12, r16
vm0_spi_AF: SPI_BLOCK r12, r17
vm0_spi_B0: SPI_BLOCK r13, r2
vm0_spi_B1: SPI_BLOCK r13, r3
vm0_spi_B2: SPI_BLOCK r13, r4
vm0_spi_B3: SPI_BLOCK r13, r5
vm0_spi_B4: SPI_BLOCK r13, r6
vm0_spi_B5: SPI_BLOCK r13, r7
vm0_spi_B6: SPI_BLOCK r13, r8
vm0_spi_B7: SPI_BLOCK r13, r9
vm0_spi_B8: SPI_BLOCK r13, r10
vm0_spi_B9: SPI_BLOCK r13, r11
vm0_spi_BA: SPI_BLOCK r13, r12
vm0_spi_BB: SPI_BLOCK r13, r13
vm0_spi_BC: SPI_BLOCK r13, r14
vm0_spi_BD: SPI_BLOCK r13, r15
vm0_spi_BE: SPI_BLOCK r13, r16
vm0_spi_BF: SPI_BLOCK r13, r17
vm0_spi_C0: SPI_BLOCK r14, r2
vm0_spi_C1: SPI_BLOCK r14, r3
vm0_spi_C2: SPI_BLOCK r14, r4
vm0_spi_C3: SPI_BLOCK r14, r5
vm0_spi_C4: SPI_BLOCK r14, r6
vm0_spi_C5: SPI_BLOCK r14, r7
vm0_spi_C6: SPI_BLOCK r14, r8
vm0_spi_C7: SPI_BLOCK r14, r9
vm0_spi_C8: SPI_BLOCK r14, r10
vm0_spi_C9: SPI_BLOCK r14, r11
vm0_spi_CA: SPI_BLOCK r14, r12
vm0_spi_CB: SPI_BLOCK r14, r13
vm0_spi_CC: SPI_BLOCK r14, r14
vm0_spi_CD: SPI_BLOCK r14, r15
vm0_spi_CE: SPI_BLOCK r14, r16
vm0_spi_CF: SPI_BLOCK r14, r17
vm0_spi_D0: SPI_BLOCK r15, r2
vm0_spi_D1: SPI_BLOCK r15, r3
vm0_spi_D2: SPI_BLOCK r15, r4
vm0_spi_D3: SPI_BLOCK r15, r5
vm0_spi_D4: SPI_BLOCK r15, r6
vm0_spi_D5: SPI_BLOCK r15, r7
vm0_spi_D6: SPI_BLOCK r15, r8
vm0_spi_D7: SPI_BLOCK r15, r9
vm0_spi_D8: SPI_BLOCK r15, r10
vm0_spi_D9: SPI_BLOCK r15, r11
vm0_spi_DA: SPI_BLOCK r15, r12
vm0_spi_DB: SPI_BLOCK r15, r13
vm0_spi_DC: SPI_BLOCK r15, r14
vm0_spi_DD: SPI_BLOCK r15, r15
vm0_spi_DE: SPI_BLOCK r15, r16
vm0_spi_DF: SPI_BLOCK r15, r17
vm0_spi_E0: SPI_BLOCK r16, r2
vm0_spi_E1: SPI_BLOCK r16, r3
vm0_spi_E2: SPI_BLOCK r16, r4
vm0_spi_E3: SPI_BLOCK r16, r5
vm0_spi_E4: SPI_BLOCK r16, r6
vm0_spi_E5: SPI_BLOCK r16, r7
vm0_spi_E6: SPI_BLOCK r16, r8
vm0_spi_E7: SPI_BLOCK r16, r9
vm0_spi_E8: SPI_BLOCK r16, r10
vm0_spi_E9: SPI_BLOCK r16, r11
vm0_spi_EA: SPI_BLOCK r16, r12
vm0_spi_EB: SPI_BLOCK r16, r13
vm0_spi_EC: SPI_BLOCK r16, r14
vm0_spi_ED: SPI_BLOCK r16, r15
vm0_spi_EE: SPI_BLOCK r16, r16
vm0_spi_EF: SPI_BLOCK r16, r17
vm0_spi_F0: SPI_BLOCK r17, r2
vm0_spi_F1: SPI_BLOCK r17, r3
vm0_spi_F2: SPI_BLOCK r17, r4
vm0_spi_F3: SPI_BLOCK r17, r5
vm0_spi_F4: SPI_BLOCK r17, r6
vm0_spi_F5: SPI_BLOCK r17, r7
vm0_spi_F6: SPI_BLOCK r17, r8
vm0_spi_F7: SPI_BLOCK r17, r9
vm0_spi_F8: SPI_BLOCK r17, r10
vm0_spi_F9: SPI_BLOCK r17, r11
vm0_spi_FA: SPI_BLOCK r17, r12
vm0_spi_FB: SPI_BLOCK r17, r13
vm0_spi_FC: SPI_BLOCK r17, r14
vm0_spi_FD: SPI_BLOCK r17, r15
vm0_spi_FE: SPI_BLOCK r17, r16
vm0_spi_FF: SPI_BLOCK r17, r17

vm0_spi_jtab:
	rjmp  vm0_spi_00
	rjmp  vm0_spi_01
	rjmp  vm0_spi_02
	rjmp  vm0_spi_03
	rjmp  vm0_spi_04
	rjmp  vm0_spi_05
	rjmp  vm0_spi_06
	rjmp  vm0_spi_07
	rjmp  vm0_spi_08
	rjmp  vm0_spi_09
	rjmp  vm0_spi_0A
	rjmp  vm0_spi_0B
	rjmp  vm0_spi_0C
	rjmp  vm0_spi_0D
	rjmp  vm0_spi_0E
	rjmp  vm0_spi_0F
	rjmp  vm0_spi_10
	rjmp  vm0_spi_11
	rjmp  vm0_spi_12
	rjmp  vm0_spi_13
	rjmp  vm0_spi_14
	rjmp  vm0_spi_15
	rjmp  vm0_spi_16
	rjmp  vm0_spi_17
	rjmp  vm0_spi_18
	rjmp  vm0_spi_19
	rjmp  vm0_spi_1A
	rjmp  vm0_spi_1B
	rjmp  vm0_spi_1C
	rjmp  vm0_spi_1D
	rjmp  vm0_spi_1E
	rjmp  vm0_spi_1F
	rjmp  vm0_spi_20
	rjmp  vm0_spi_21
	rjmp  vm0_spi_22
	rjmp  vm0_spi_23
	rjmp  vm0_spi_24
	rjmp  vm0_spi_25
	rjmp  vm0_spi_26
	rjmp  vm0_spi_27
	rjmp  vm0_spi_28
	rjmp  vm0_spi_29
	rjmp  vm0_spi_2A
	rjmp  vm0_spi_2B
	rjmp  vm0_spi_2C
	rjmp  vm0_spi_2D
	rjmp  vm0_spi_2E
	rjmp  vm0_spi_2F
	rjmp  vm0_spi_30
	rjmp  vm0_spi_31
	rjmp  vm0_spi_32
	rjmp  vm0_spi_33
	rjmp  vm0_spi_34
	rjmp  vm0_spi_35
	rjmp  vm0_spi_36
	rjmp  vm0_spi_37
	rjmp  vm0_spi_38
	rjmp  vm0_spi_39
	rjmp  vm0_spi_3A
	rjmp  vm0_spi_3B
	rjmp  vm0_spi_3C
	rjmp  vm0_spi_3D
	rjmp  vm0_spi_3E
	rjmp  vm0_spi_3F
	rjmp  vm0_spi_40
	rjmp  vm0_spi_41
	rjmp  vm0_spi_42
	rjmp  vm0_spi_43
	rjmp  vm0_spi_44
	rjmp  vm0_spi_45
	rjmp  vm0_spi_46
	rjmp  vm0_spi_47
	rjmp  vm0_spi_48
	rjmp  vm0_spi_49
	rjmp  vm0_spi_4A
	rjmp  vm0_spi_4B
	rjmp  vm0_spi_4C
	rjmp  vm0_spi_4D
	rjmp  vm0_spi_4E
	rjmp  vm0_spi_4F
	rjmp  vm0_spi_50
	rjmp  vm0_spi_51
	rjmp  vm0_spi_52
	rjmp  vm0_spi_53
	rjmp  vm0_spi_54
	rjmp  vm0_spi_55
	rjmp  vm0_spi_56
	rjmp  vm0_spi_57
	rjmp  vm0_spi_58
	rjmp  vm0_spi_59
	rjmp  vm0_spi_5A
	rjmp  vm0_spi_5B
	rjmp  vm0_spi_5C
	rjmp  vm0_spi_5D
	rjmp  vm0_spi_5E
	rjmp  vm0_spi_5F
	rjmp  vm0_spi_60
	rjmp  vm0_spi_61
	rjmp  vm0_spi_62
	rjmp  vm0_spi_63
	rjmp  vm0_spi_64
	rjmp  vm0_spi_65
	rjmp  vm0_spi_66
	rjmp  vm0_spi_67
	rjmp  vm0_spi_68
	rjmp  vm0_spi_69
	rjmp  vm0_spi_6A
	rjmp  vm0_spi_6B
	rjmp  vm0_spi_6C
	rjmp  vm0_spi_6D
	rjmp  vm0_spi_6E
	rjmp  vm0_spi_6F
	rjmp  vm0_spi_70
	rjmp  vm0_spi_71
	rjmp  vm0_spi_72
	rjmp  vm0_spi_73
	rjmp  vm0_spi_74
	rjmp  vm0_spi_75
	rjmp  vm0_spi_76
	rjmp  vm0_spi_77
	rjmp  vm0_spi_78
	rjmp  vm0_spi_79
	rjmp  vm0_spi_7A
	rjmp  vm0_spi_7B
	rjmp  vm0_spi_7C
	rjmp  vm0_spi_7D
	rjmp  vm0_spi_7E
	rjmp  vm0_spi_7F
	rjmp  vm0_spi_80
	rjmp  vm0_spi_81
	rjmp  vm0_spi_82
	rjmp  vm0_spi_83
	rjmp  vm0_spi_84
	rjmp  vm0_spi_85
	rjmp  vm0_spi_86
	rjmp  vm0_spi_87
	rjmp  vm0_spi_88
	rjmp  vm0_spi_89
	rjmp  vm0_spi_8A
	rjmp  vm0_spi_8B
	rjmp  vm0_spi_8C
	rjmp  vm0_spi_8D
	rjmp  vm0_spi_8E
	rjmp  vm0_spi_8F
	rjmp  vm0_spi_90
	rjmp  vm0_spi_91
	rjmp  vm0_spi_92
	rjmp  vm0_spi_93
	rjmp  vm0_spi_94
	rjmp  vm0_spi_95
	rjmp  vm0_spi_96
	rjmp  vm0_spi_97
	rjmp  vm0_spi_98
	rjmp  vm0_spi_99
	rjmp  vm0_spi_9A
	rjmp  vm0_spi_9B
	rjmp  vm0_spi_9C
	rjmp  vm0_spi_9D
	rjmp  vm0_spi_9E
	rjmp  vm0_spi_9F
	rjmp  vm0_spi_A0
	rjmp  vm0_spi_A1
	rjmp  vm0_spi_A2
	rjmp  vm0_spi_A3
	rjmp  vm0_spi_A4
	rjmp  vm0_spi_A5
	rjmp  vm0_spi_A6
	rjmp  vm0_spi_A7
	rjmp  vm0_spi_A8
	rjmp  vm0_spi_A9
	rjmp  vm0_spi_AA
	rjmp  vm0_spi_AB
	rjmp  vm0_spi_AC
	rjmp  vm0_spi_AD
	rjmp  vm0_spi_AE
	rjmp  vm0_spi_AF
	rjmp  vm0_spi_B0
	rjmp  vm0_spi_B1
	rjmp  vm0_spi_B2
	rjmp  vm0_spi_B3
	rjmp  vm0_spi_B4
	rjmp  vm0_spi_B5
	rjmp  vm0_spi_B6
	rjmp  vm0_spi_B7
	rjmp  vm0_spi_B8
	rjmp  vm0_spi_B9
	rjmp  vm0_spi_BA
	rjmp  vm0_spi_BB
	rjmp  vm0_spi_BC
	rjmp  vm0_spi_BD
	rjmp  vm0_spi_BE
	rjmp  vm0_spi_BF
	rjmp  vm0_spi_C0
	rjmp  vm0_spi_C1
	rjmp  vm0_spi_C2
	rjmp  vm0_spi_C3
	rjmp  vm0_spi_C4
	rjmp  vm0_spi_C5
	rjmp  vm0_spi_C6
	rjmp  vm0_spi_C7
	rjmp  vm0_spi_C8
	rjmp  vm0_spi_C9
	rjmp  vm0_spi_CA
	rjmp  vm0_spi_CB
	rjmp  vm0_spi_CC
	rjmp  vm0_spi_CD
	rjmp  vm0_spi_CE
	rjmp  vm0_spi_CF
	rjmp  vm0_spi_D0
	rjmp  vm0_spi_D1
	rjmp  vm0_spi_D2
	rjmp  vm0_spi_D3
	rjmp  vm0_spi_D4
	rjmp  vm0_spi_D5
	rjmp  vm0_spi_D6
	rjmp  vm0_spi_D7
	rjmp  vm0_spi_D8
	rjmp  vm0_spi_D9
	rjmp  vm0_spi_DA
	rjmp  vm0_spi_DB
	rjmp  vm0_spi_DC
	rjmp  vm0_spi_DD
	rjmp  vm0_spi_DE
	rjmp  vm0_spi_DF
	rjmp  vm0_spi_E0
	rjmp  vm0_spi_E1
	rjmp  vm0_spi_E2
	rjmp  vm0_spi_E3
	rjmp  vm0_spi_E4
	rjmp  vm0_spi_E5
	rjmp  vm0_spi_E6
	rjmp  vm0_spi_E7
	rjmp  vm0_spi_E8
	rjmp  vm0_spi_E9
	rjmp  vm0_spi_EA
	rjmp  vm0_spi_EB
	rjmp  vm0_spi_EC
	rjmp  vm0_spi_ED
	rjmp  vm0_spi_EE
	rjmp  vm0_spi_EF
	rjmp  vm0_spi_F0
	rjmp  vm0_spi_F1
	rjmp  vm0_spi_F2
	rjmp  vm0_spi_F3
	rjmp  vm0_spi_F4
	rjmp  vm0_spi_F5
	rjmp  vm0_spi_F6
	rjmp  vm0_spi_F7
	rjmp  vm0_spi_F8
	rjmp  vm0_spi_F9
	rjmp  vm0_spi_FA
	rjmp  vm0_spi_FB
	rjmp  vm0_spi_FC
	rjmp  vm0_spi_FD
	rjmp  vm0_spi_FE
	rjmp  vm0_spi_FF
