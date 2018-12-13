/*
 *  Uzebox Square Kernel - Video Mode 0, Functions
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
; Video Mode 0 User functions
;



;
; Set tileset parameters.
;
; void SQ_SetTileset(uint8_t const* tileset, uint8_t const* maskset, uint8_t const* maskdata);
;
; r25:r24: Tileset pointer
; r23:r22: Mask index set pointer
; r21:r20: Mask data pointer
;
.global SQ_SetTileset
.section .text.SQ_SetTileset
SQ_SetTileset:

	sts   sq_tileset_pth, r25
	sts   sq_maskset_pth, r23
	sts   sq_maskdat_pth, r21
	ret



;
; Set tile row descriptor.
;
; void SQ_SetTileRowDesc(uint8_t row, uint16_t bgoff, uint8_t flags);
;
;     r24: row
; r23:r22: bgoff
;     r20: flags
;
.global SQ_SetTileRowDesc
.section .text.SQ_SetTileRowDesc
SQ_SetTileRowDesc:

	cpi   r24,     26
	brcs  .+2
	ret                    ; Invalid row
	lsl   r24
	lsl   r24
	ldi   ZH,      hi8(sq_tile_rows + 1)
	ldi   ZL,      lo8(sq_tile_rows + 1)
	add   ZL,      r24
	st    Z+,      r20
	st    Z+,      r22
	st    Z+,      r23
	ret



;
; Set background row start offset and pixel position.
;
; void SQ_SetTileRowBGOff(uint8_t row, uint16_t bgoff, uint16_t xpos, uint8_t flags);
;
;     r24: row
; r23:r22: bgoff
; r21:r20: xpos
;     r18: flags
;
.global SQ_SetTileRowBGOff
.section .text.SQ_SetTileRowBGOff
SQ_SetTileRowBGOff:

	cpi   r24,     26
	brcs  .+2
	ret                    ; Invalid row
	lsl   r24
	lsl   r24
	ldi   ZH,      hi8(sq_tile_rows + 1)
	ldi   ZL,      lo8(sq_tile_rows + 1)
	add   ZL,      r24
	mov   r24,     r18
	andi  r24,     0xF8    ; Mask off current X shift
	mov   r25,     r20
	andi  r25,     0x07    ; Mask new X shift
	or    r24,     r25
	st    Z+,      r24     ; New X shift stored
	lsr   r21
	ror   r20
	lsr   r21
	ror   r20
	lsr   r21
	ror   r20              ; xshift to tile coordinate
	add   r22,     r20
	adc   r23,     r21     ; Adjusted bg. offset with it for horizontal scroll
	st    Z+,      r22
	st    Z+,      r23
	ret



;
; Set all tiled row descriptors.
;
; void SQ_SetTileDesc(uint16_t bgoff, uint16_t width, uint8_t flags);
;
; r25:r24: bgoff
; r23:r22: width
;     r20: flags
;
.global SQ_SetTileDesc
.section .text.SQ_SetTileDesc
SQ_SetTileDesc:

	clr   r1
	sts   sq_video_yshift, r1 ; Zero Y shift just for consistence

	ldi   ZH,      hi8(sq_tile_rows)
	ldi   ZL,      lo8(sq_tile_rows)
0:
	adiw  ZL,      1
	st    Z+,      r20
	st    Z+,      r24
	st    Z+,      r25
	add   r24,     r22
	adc   r25,     r23     ; Next row
	cpi   ZL,      lo8(sq_tile_rows + (26 * 4))
	brne  0b
	ret



;
; Set background parameters and scroll in one.
;
; void SQ_SetTileBGOff(uint16_t bgoff, uint16_t width, uint16_t xpos, uint16_t ypos, uint8_t flags);
;
; r25:r24: bgoff
; r23:r22: width
; r21:r20: xpos
; r19:r18: ypos
;     r16: flags
;
.global SQ_SetTileBGOff
.section .text.SQ_SetTileBGOff
SQ_SetTileBGOff:

	mov   XL,      r18
	andi  XL,      7
	sts   sq_video_yshift, XL ; Y shift for this Y position
	lsr   r19
	ror   r18
	lsr   r19
	ror   r18
	lsr   r19
	ror   r18              ; Tile position, now multiply with width to get offset
	mul   r18,     r22
	movw  XL,      r0
	mul   r19,     r22
	add   XH,      r0
	mul   r18,     r23
	add   XH,      r0      ; XH:XL: offset addition
	add   r24,     XL
	adc   r25,     XH      ; Add to background offset to get first row's offset
	clr   r1

	mov   XL,      r20
	andi  XL,      7       ; X shift
	lsr   r21
	ror   r20
	lsr   r21
	ror   r20
	lsr   r21
	ror   r20              ; Tile coordinate from X position
	add   r24,     r20
	adc   r25,     r21     ; Add to background offset

	ldi   ZH,      hi8(sq_tile_rows)
	ldi   ZL,      lo8(sq_tile_rows)
0:
	adiw  ZL,      1
	mov   r20,     r16
	andi  r20,     0xF8    ; Mask off current X shift
	or    r20,     XL      ; Add new X shift
	st    Z+,      r20     ; New X shift stored
	st    Z+,      r24
	st    Z+,      r25
	add   r24,     r22
	adc   r25,     r23     ; Next row
	cpi   ZL,      lo8(sq_tile_rows + (26 * 4))
	brne  0b
	ret



;
; Set screen split point, also clearing Superwide.
;
; void SQ_SetScreenSplit(uint8_t split);
;
;     r24: split
;
.global SQ_SetScreenSplit
.section .text.SQ_SetScreenSplit
SQ_SetScreenSplit:

	sbis  _SFR_IO_ADDR(GPIOR0), 5 ; Superwide?
	rjmp  0f
	cbi   _SFR_IO_ADDR(GPIOR0), 5 ; Superwide OFF

	; Switching back from Superwide mode: reset the Tiled mode's
	; overridden variables to sane defaults.

	; Clean up rows, so no RAM tiles show until starting actually using
	; the sprite engine (this is not done by just setting tile row
	; configs)

	ldi   ZL,      0
	ldi   ZH,      hi8(sq_ramt_list_ent)
	clr   r1
1:
	st    Z+,      r1
	cpi   ZL,      26
	brne  1b

	; Also set RAM tiles for the sprite engine free.

	sts   sq_sptile_nfr, r1

	; Reset Y shift (row by row initialization skips this)

	sts   sq_video_yshift, r1

	; Done

0:
	sts   sq_video_split, r24
	jmp   SQ_ComputeActiveLines



;
; Set screen shrink amount. Should be called at the frame's beginning.
;
; void SQ_SetScreenShrink(uint8_t shrink);
;
;     r24: shrink
;
.global SQ_SetScreenShrink
.section .text.SQ_SetScreenShrink
SQ_SetScreenShrink:

	cpi   r24,     99
	brcs  .+2
	ldi   r24,     99
	sts   sq_video_shrink, r24
	jmp   SQ_ComputeActiveLines



;
; Set Y shift for fine Y scrolling
;
; void SQ_SetYShift(uint8_t yshift);
;
;     r24: yshift
;
.global SQ_SetYShift
.section .text.SQ_SetYShift
SQ_SetYShift:

	andi  r24,     7
	sts   sq_video_yshift, r24
	ret



;
; Internal: Prepares Active tile line count
;
.section .text.SQ_ComputeActiveLines
SQ_ComputeActiveLines:

	lds   ZL,      sq_video_split
	ldi   ZH,      200
	lds   r0,      sq_video_shrink
	sub   ZH,      r0
	sub   ZH,      r0
	cp    ZL,      ZH
	brcs  .+2
	mov   ZL,      ZH
	sts   sq_video_alines, ZL
	ret



;
; Set superwide bitmap mode
;
; void SQ_SetWideBitmap(void);
;
.global SQ_SetWideBitmap
.section .text.SQ_SetWideBitmap
SQ_SetWideBitmap:

	sbi   _SFR_IO_ADDR(GPIOR0), 5 ; Superwide ON
	ret



;
; Enable / Disable Color 0 reloading in SPI Bitmap modes (applies to Superwide
; too, although good luck finding 200 bytes to spare there!).
;
; void SQ_SetBitmapC0Reload(uint8_t ena);
;
;     r24: If set, enables, otherwise disables Color 0 reloading.
;
.global SQ_SetBitmapC0Reload
.section .text.SQ_SetBitmapC0Reload
SQ_SetBitmapC0Reload:

	cpi   r24,     0
	breq  .+4
	sbi   _SFR_IO_ADDR(GPIOR0), 6
	ret
	cbi   _SFR_IO_ADDR(GPIOR0), 6
	ret



;
; Enable / Disable Color 0 reloading in Tiled mode.
;
; void SQ_SetTiledC0Reload(uint8_t ena);
;
;     r24: If set, enables, otherwise disables Color 0 reloading.
;
.global SQ_SetTiledC0Reload
.section .text.SQ_SetTiledC0Reload
SQ_SetTiledC0Reload:

	cpi   r24,     0
	breq  .+4
	sbi   _SFR_IO_ADDR(GPIOR0), 4
	ret
	cbi   _SFR_IO_ADDR(GPIOR0), 4
	ret



;
; Rearranges a straight bitmap (high nybble corresponding to left pixels) to
; the normal SPI bitmap format. This operation requires 100 bytes of work RAM.
;
; void SQ_PrepBitmap(uint8_t dstbank, uint16_t dstoff,
;                    uint8_t srcbank, uint16_t srcoff,
;                    uint16_t rowcnt, void* workram);
;
;     r24: Destination bank
; r23:r22: Destination offset
;     r20: Source bank
; r19:r18: Source offset
; r17:r16: Row count
; r15:r14: Work RAM pointer
;
.global SQ_PrepBitmap
.section .text.SQ_PrepBitmap
SQ_PrepBitmap:

	push  r17
	push  r16
	push  r13
	push  r12
	push  r11
	push  r10
	push  r9
	push  r8
	push  r7
	push  YH
	push  YL

	mov   r8,      r24     ; r8: Dst. bank
	mov   r9,      r20     ; r9: Src. bank
	movw  r10,     r22     ; r10: Dst. offset
	movw  r12,     r18     ; r12: Src. offset

0:
	mov   r24,     r9
	movw  r22,     r12
	movw  r20,     r14
	ldi   r18,     100
	ldi   r19,     0
	call  XRAM_ReadInto
	mov   r24,     r8
	movw  r22,     r10
	call  XRAM_SeqWriteStart

	movw  YL,      r14
	ldi   ZL,      50
	mov   r7,      ZL
1:
	ld    r24,     Y
	adiw  YL,      2
	call  XRAM_SeqWriteU8
	dec   r7
	brne  1b

	movw  YL,      r14
	adiw  YL,      1
	ldi   ZL,      50
	mov   r7,      ZL
1:
	ld    r24,     Y
	adiw  YL,      2
	call  XRAM_SeqWriteU8
	dec   r7
	brne  1b

	call  XRAM_SeqWriteEnd
	clr   r1
	ldi   ZL,      100
	add   r12,     ZL
	adc   r13,     r1
	adc   r9,      r1
	add   r10,     ZL
	adc   r11,     r1
	adc   r8,      r1
	subi  r16,     1
	sbci  r17,     0
	brne  0b

	pop   YL
	pop   YH
	pop   r7
	pop   r8
	pop   r9
	pop   r10
	pop   r11
	pop   r12
	pop   r13
	pop   r16
	pop   r17
	ret



;
; Rearranges a straight bitmap (high nybble corresponding to left pixels) to
; the wide SPI bitmap format, 200 rows fixed.
;
; void SQ_PrepWideBitmap(uint8_t dstbank, uint16_t dstoff,
;                        uint8_t srcbank, uint16_t srcoff);
;
;     r24: Destination bank
; r23:r22: Destination offset
;     r20: Source bank
; r19:r18: Source offset
;
.global SQ_PrepWideBitmap
.section .text.SQ_PrepWideBitmap
SQ_PrepWideBitmap:

	push  r17
	push  r16
	push  r13
	push  r12
	push  r11
	push  r10
	push  r9
	push  r8
	push  YH
	push  YL

	mov   r8,      r24     ; r8: Dst. bank
	mov   r9,      r20     ; r9: Src. bank
	movw  r10,     r22     ; r10: Dst. offset
	movw  r12,     r18     ; r12: Src. offset

	; SPI RAM based portion

	ldi   r17,     200
0:
	mov   r24,     r9
	movw  r22,     r12
	ldi   r20,     lo8(sq_ramtiles_base)
	ldi   r21,     hi8(sq_ramtiles_base)
	ldi   r18,     116
	ldi   r19,     0
	call  XRAM_ReadInto
	mov   r24,     r8
	movw  r22,     r10
	call  XRAM_SeqWriteStart

	ldi   YL,      lo8(sq_ramtiles_base + 16)
	ldi   YH,      hi8(sq_ramtiles_base + 16)
	ldi   r16,     42
1:
	ld    r24,     Y
	adiw  YL,      2
	call  XRAM_SeqWriteU8
	dec   r16
	brne  1b

	ldi   YL,      lo8(sq_ramtiles_base + 1)
	ldi   YH,      hi8(sq_ramtiles_base + 1)
	ldi   r16,     58
1:
	ld    r24,     Y
	adiw  YL,      2
	call  XRAM_SeqWriteU8
	dec   r16
	brne  1b

	call  XRAM_SeqWriteEnd
	clr   r1
	ldi   ZL,      116
	add   r12,     ZL
	adc   r13,     r1
	adc   r9,      r1
	ldi   ZL,      100
	add   r10,     ZL
	adc   r11,     r1
	adc   r8,      r1
	subi  r17,     1
	brne  0b

	; Rewind

	ldi   ZL,      lo8(116 * 200)
	ldi   ZH,      hi8(116 * 200)
	sub   r12,     ZL
	sbc   r13,     ZH
	sbc   r9,      r1

	; RAM based portion

	ldi   r17,     200
	ldi   YL,      lo8(sq_ramtiles_base)
	ldi   YH,      hi8(sq_ramtiles_base)
0:
	mov   r24,     r9
	movw  r22,     r12
	call  XRAM_SeqReadStart

	ldi   r16,     8
1:
	call  XRAM_SeqReadU8
	st    Y+,      r24
	call  XRAM_SeqReadU8
	dec   r16
	brne  1b

	call  XRAM_SeqReadEnd
	mov   r24,     r9
	movw  r22,     r12
	subi  r22,     lo8(-(100))
	sbci  r23,     hi8(-(100))
	sbci  r24,     0xFF
	call  XRAM_SeqReadStart

	ldi   r16,     8
1:
	call  XRAM_SeqReadU8
	st    Y+,      r24
	call  XRAM_SeqReadU8
	dec   r16
	brne  1b

	call  XRAM_SeqReadEnd
	clr   r1
	ldi   ZL,      116
	add   r12,     ZL
	adc   r13,     r1
	adc   r9,      r1
	subi  r17,     1
	brne  0b

	pop   YL
	pop   YH
	pop   r8
	pop   r9
	pop   r10
	pop   r11
	pop   r12
	pop   r13
	pop   r16
	pop   r17
	ret



;
; Sets tiled palette from XRAM.
;
; void SQ_XRAM_SetTiledPal8(uint8_t srcbank, uint16_t srcoff);
;
;     r24: Source bank
; r23:r22: Source offset
;
.global SQ_XRAM_SetTiledPal8
.section .text.SQ_XRAM_SetTiledPal8
SQ_XRAM_SetTiledPal8:

	ldi   r20,     lo8(sq_pal_tiled)
	ldi   r21,     hi8(sq_pal_tiled)
	ldi   r18,     16
	ldi   r19,     0
	jmp   XRAM_ReadInto



;
; Sets bitmap palette from XRAM.
;
; void SQ_XRAM_SetBitmapPal8(uint8_t srcbank, uint16_t srcoff);
;
;     r24: Source bank
; r23:r22: Source offset
;
.global SQ_XRAM_SetBitmapPal8
.section .text.SQ_XRAM_SetBitmapPal8
SQ_XRAM_SetBitmapPal8:

	ldi   r20,     lo8(sq_pal_bitmap)
	ldi   r21,     hi8(sq_pal_bitmap)
	ldi   r18,     16
	ldi   r19,     0
	jmp   XRAM_ReadInto



;
; Sets tiled palette from memory (ROM / RAM).
;
; void SQ_MEM_SetTiledPal8(uint8_t const* ptr);
;
; r25:r24: Source pointer
;
.global SQ_MEM_SetTiledPal8
.section .text.SQ_MEM_SetTiledPal8
SQ_MEM_SetTiledPal8:

	ldi   XL,      lo8(sq_pal_tiled)
	ldi   XH,      hi8(sq_pal_tiled)

SQ_MEM_SetTiledPal8_comm:

	movw  ZL,      r24
	ldi   r24,     16
	cpi   ZH,      0x11
	brcc  1f

	; <  0x1100: RAM source

0:
	ld    r25,     Z+
	st    X+,      r25
	dec   r24
	brne  0b
	ret

1:
	; >= 0x1100: ROM source

0:
	lpm   r25,     Z+
	st    X+,      r25
	dec   r24
	brne  0b
	ret



;
; Sets bitmap palette from memory (ROM / RAM).
;
; void SQ_MEM_SetBitmapPal8(uint8_t const* ptr);
;
; r25:r24: Source pointer
;
.global SQ_MEM_SetBitmapPal8
.section .text.SQ_MEM_SetBitmapPal8
SQ_MEM_SetBitmapPal8:

	ldi   XL,      lo8(sq_pal_bitmap)
	ldi   XH,      hi8(sq_pal_bitmap)
	jmp   SQ_MEM_SetTiledPal8_comm



;
; Blits to bitmap, 1bpp ROM/RAM source with transparency
;
; void SQ_MEM_BitmapBlit1(uint8_t xpos, uint8_t ypos,
;                         uint8_t width, uint8_t height,
;                         uint8_t const* ptr, uint16_t colmap);
;
;     r24: X pixel position
;     r22: Y pixel position
;     r20: Source width
;     r18: Source height
; r17:r16: Source data pointer
; r15:r14: Color map (bits 4-7: Color 1)
;
.global SQ_MEM_BitmapBlit1
.section .text.SQ_MEM_BitmapBlit1
SQ_MEM_BitmapBlit1:

	push  r17
	push  r16
	push  r15
	push  r14
	push  r13
	push  r4
	push  r3
	push  r2

	; Prepare color

	mov   ZL,      r14
	andi  ZL,      0xF0
	mov   r15,     ZL
	swap  ZL
	mov   r14,     ZL

	; Prepare bitmap address

	clr   r1
	lds   r2,      sq_bitmap_ptr + 0
	lds   r3,      sq_bitmap_ptr + 1
	lds   r4,      sq_bitmap_bank
	sbis  _SFR_IO_ADDR(GPIOR0), 5 ; 232px?
	rjmp  0f
	ldi   ZL,      8
	sub   r2,      ZL
	sbc   r3,      r1
	sbc   r4,      r1      ; Fake displacement for RAM based bytes
0:

	; Prepare output loop

	movw  ZL,      r16     ; Source pointer
	                       ; Source width OK in r20
	mov   r21,     r18     ; Source height (no. of rows to produce)
	mov   r13,     r24     ; X start position

	; Main render loop, rows

SQ_MEM_BitmapBlit1_loop:

	mov   r24,     r13
	mov   XH,      r24
	andi  XH,      7       ; Initial pixels to skip
	mov   XL,      r20     ; Count of pixels to produce
	rcall SQ_MEM_BitmapBlit1_rmem

	; Main render loop, X

9:
	call  SQ_Bitmap_ReadSec
	cpi   XH,      1
	brcs  0f
	breq  1f
	cpi   XH,      3
	brcs  2f
	breq  3f
	cpi   XH,      5
	brcs  4f
	breq  5f
	cpi   XH,      7
	brcs  .+2
	rjmp  7f
	rjmp  6f
8:
	rjmp  8f
0:
	lsl   r25
	brcc  .+4
	andi  r19,     0x0F
	or    r19,     r15
	dec   XL
	breq  8b
	dec   r23
	brne  .+2
	rcall SQ_MEM_BitmapBlit1_rmem
1:
	lsl   r25
	brcc  .+4
	andi  r19,     0xF0
	or    r19,     r14
	dec   XL
	breq  8f
	dec   r23
	brne  .+2
	rcall SQ_MEM_BitmapBlit1_rmem
2:
	lsl   r25
	brcc  .+4
	andi  r18,     0x0F
	or    r18,     r15
	dec   XL
	breq  8f
	dec   r23
	brne  .+2
	rcall SQ_MEM_BitmapBlit1_rmem
3:
	lsl   r25
	brcc  .+4
	andi  r18,     0xF0
	or    r18,     r14
	dec   XL
	breq  8f
	dec   r23
	brne  .+2
	rcall SQ_MEM_BitmapBlit1_rmem
4:
	lsl   r25
	brcc  .+4
	andi  r17,     0x0F
	or    r17,     r15
	dec   XL
	breq  8f
	dec   r23
	brne  .+2
	rcall SQ_MEM_BitmapBlit1_rmem
5:
	lsl   r25
	brcc  .+4
	andi  r17,     0xF0
	or    r17,     r14
	dec   XL
	breq  8f
	dec   r23
	brne  .+2
	rcall SQ_MEM_BitmapBlit1_rmem
6:
	lsl   r25
	brcc  .+4
	andi  r16,     0x0F
	or    r16,     r15
	dec   XL
	breq  8f
	dec   r23
	brne  .+2
	rcall SQ_MEM_BitmapBlit1_rmem
7:
	lsl   r25
	brcc  .+4
	andi  r16,     0xF0
	or    r16,     r14
	dec   XL
	breq  8f
	dec   r23
	brne  .+2
	rcall SQ_MEM_BitmapBlit1_rmem
8:
	call  SQ_Bitmap_WriteSec
	subi  r24,     0xF8
	ldi   XH,      0
	cpi   XL,      0
	breq  .+2
	rjmp  9b

	; Onto next row

	inc   r22
	dec   r21
	breq  .+2
	rjmp  SQ_MEM_BitmapBlit1_loop

	; All done

	pop   r2
	pop   r3
	pop   r4
	pop   r13
	pop   r14
	pop   r15
	pop   r16
	pop   r17
	ret

SQ_MEM_BitmapBlit1_rmem:

	; Mini-function to read next memory byte & reset bit counter

	ldi   r23,     8
	cpi   ZH,      0x11
	brcs  .+4
	lpm   r25,     Z+
	ret
	ld    r25,     Z+
	ret



;
; Blits to bitmap, 2bpp ROM/RAM source with transparency
;
; void SQ_MEM_BitmapBlit2(uint8_t xpos, uint8_t ypos,
;                         uint8_t width, uint8_t height,
;                         uint8_t const* ptr, uint16_t colmap);
;
;     r24: X pixel position
;     r22: Y pixel position
;     r20: Source width
;     r18: Source height
; r17:r16: Source data pointer
; r15:r14: Color map (bits 4-7: Color 1, bits 8-11: Color 2, bits 12-15: Color 3)
;
.global SQ_MEM_BitmapBlit2
.section .text.SQ_MEM_BitmapBlit2
SQ_MEM_BitmapBlit2:

	push  r17
	push  r16
	push  r15
	push  r14
	push  r13
	push  r12
	push  r4
	push  r3
	push  r2

	; Prepare colors

	mov   ZL,      r14
	andi  ZL,      0xF0
	swap  ZL
	mov   r14,     ZL      ; r14: Color 1
	mov   ZL,      r15
	mov   ZH,      r15
	andi  ZL,      0x0F
	mov   r15,     ZL      ; r15: Color 2
	andi  ZH,      0xF0
	swap  ZH
	mov   r12,     ZH      ; r12: Color 3

	; Prepare bitmap address

	clr   r1
	lds   r2,      sq_bitmap_ptr + 0
	lds   r3,      sq_bitmap_ptr + 1
	lds   r4,      sq_bitmap_bank
	sbis  _SFR_IO_ADDR(GPIOR0), 5 ; 232px?
	rjmp  0f
	ldi   ZL,      8
	sub   r2,      ZL
	sbc   r3,      r1
	sbc   r4,      r1      ; Fake displacement for RAM based bytes
0:

	; Prepare output loop

	movw  ZL,      r16     ; Source pointer
	                       ; Source width OK in r20
	mov   r21,     r18     ; Source height (no. of rows to produce)
	mov   r13,     r24     ; X start position

	; Main render loop, rows

SQ_MEM_BitmapBlit2_loop:

	mov   r24,     r13
	mov   XH,      r24
	andi  XH,      7       ; Initial pixels to skip
	mov   XL,      r20     ; Count of pixels to produce
	rcall SQ_MEM_BitmapBlit2_rmem

	; Main render loop, X

9:
	call  SQ_Bitmap_ReadSec
	cpi   XH,      1
	brcs  0f
	breq  1f
	cpi   XH,      3
	brcs  2f
	breq  3f
	cpi   XH,      5
	brcs  4f
	breq  5f
	cpi   XH,      7
	brcs  .+2
	rjmp  7f
	rjmp  6f
8:
	rjmp  8f
0:
	rcall SQ_MEM_BitmapBlit2_selcol
	brcc  .+6
	swap  r0
	andi  r19,     0x0F
	or    r19,     r0
	dec   XL
	breq  8b
	subi  r23,     2
	brne  .+2
	rcall SQ_MEM_BitmapBlit2_rmem
1:
	rcall SQ_MEM_BitmapBlit2_selcol
	brcc  .+4
	andi  r19,     0xF0
	or    r19,     r0
	dec   XL
	breq  8f
	subi  r23,     2
	brne  .+2
	rcall SQ_MEM_BitmapBlit2_rmem
2:
	rcall SQ_MEM_BitmapBlit2_selcol
	brcc  .+6
	swap  r0
	andi  r18,     0x0F
	or    r18,     r0
	dec   XL
	breq  8f
	subi  r23,     2
	brne  .+2
	rcall SQ_MEM_BitmapBlit2_rmem
3:
	rcall SQ_MEM_BitmapBlit2_selcol
	brcc  .+4
	andi  r18,     0xF0
	or    r18,     r0
	dec   XL
	breq  8f
	subi  r23,     2
	brne  .+2
	rcall SQ_MEM_BitmapBlit2_rmem
4:
	rcall SQ_MEM_BitmapBlit2_selcol
	brcc  .+6
	swap  r0
	andi  r17,     0x0F
	or    r17,     r0
	dec   XL
	breq  8f
	subi  r23,     2
	brne  .+2
	rcall SQ_MEM_BitmapBlit2_rmem
5:
	rcall SQ_MEM_BitmapBlit2_selcol
	brcc  .+4
	andi  r17,     0xF0
	or    r17,     r0
	dec   XL
	breq  8f
	subi  r23,     2
	brne  .+2
	rcall SQ_MEM_BitmapBlit2_rmem
6:
	rcall SQ_MEM_BitmapBlit2_selcol
	brcc  .+6
	swap  r0
	andi  r16,     0x0F
	or    r16,     r0
	dec   XL
	breq  8f
	subi  r23,     2
	brne  .+2
	rcall SQ_MEM_BitmapBlit2_rmem
7:
	rcall SQ_MEM_BitmapBlit2_selcol
	brcc  .+4
	andi  r16,     0xF0
	or    r16,     r0
	dec   XL
	breq  8f
	subi  r23,     2
	brne  .+2
	rcall SQ_MEM_BitmapBlit2_rmem
8:
	call  SQ_Bitmap_WriteSec
	subi  r24,     0xF8
	ldi   XH,      0
	cpi   XL,      0
	breq  .+2
	rjmp  9b

	; Onto next row

	inc   r22
	dec   r21
	breq  .+2
	rjmp  SQ_MEM_BitmapBlit2_loop

	; All done

	pop   r2
	pop   r3
	pop   r4
	pop   r12
	pop   r13
	pop   r14
	pop   r15
	pop   r16
	pop   r17
	ret

SQ_MEM_BitmapBlit2_rmem:

	; Mini-function to read next memory byte & reset bit counter

	ldi   r23,     8
	cpi   ZH,      0x11
	brcs  .+4
	lpm   r25,     Z+
	ret
	ld    r25,     Z+
	ret

SQ_MEM_BitmapBlit2_selcol:

	; Mini-function to calculate color into r0. Clears C flag if transparent

	lsl   r25
	brcc  0f
	lsl   r25
	brcs  1f
	sec
	mov   r0,      r15     ; Color 2
	ret
1:
	mov   r0,      r12     ; Color 3
	ret
0:
	lsl   r25
	brcc  1f
	mov   r0,      r14     ; Color 1
	ret
1:
	ret



;
; Block copies to bitmap from SPI RAM. No transparency, 8px horizontal
; boundary constraint, this is useful for creating simple bitmap effects.
;
; void SQ_XRAM_BitmapCopy(uint8_t xpos, uint8_t ypos,
;                         uint8_t width, uint8_t height,
;                         uint8_t xrambank, uint16_t xramoff);
;
;     r24: X pixel position (low 3 bits ignored)
;     r22: Y pixel position
;     r20: Source width (low 3 bits ignored)
;     r18: Source height
;     r16: Source bank
; r15:r14: Source offset
;
.global SQ_XRAM_BitmapCopy
.section .text.SQ_XRAM_BitmapCopy
SQ_XRAM_BitmapCopy:

	push  r17
	push  r16
	push  r4
	push  r3
	push  r2

	; Prepare bitmap address

	clr   r1
	lds   r2,      sq_bitmap_ptr + 0
	lds   r3,      sq_bitmap_ptr + 1
	lds   r4,      sq_bitmap_bank
	sbis  _SFR_IO_ADDR(GPIOR0), 5 ; 232px?
	rjmp  0f
	ldi   ZL,      8
	sub   r2,      ZL
	sbc   r3,      r1
	sbc   r4,      r1      ; Fake displacement for RAM based bytes
0:

	; Prepare output loop

	mov   r23,     r16     ; Source bank
	movw  ZL,      r14     ; Source offset
	andi  r20,     0xF8    ; Source width
	mov   r21,     r18     ; Source height (no. of rows to produce)
	mov   XH,      r24     ; X start position

	; Main render loop, rows

SQ_XRAM_BitmapCopy_loop:

	mov   r24,     XH
	mov   XL,      r20     ; Count of pixels to produce

	; Main render loop, X

9:
	call  SQ_Bitmap_Read8px
	call  SQ_Bitmap_WriteSec
	subi  ZL,      0xFC
	sbci  ZH,      0xFF
	sbci  r23,     0xFF
	subi  r24,     0xF8
	subi  XL,      8
	brne  9b

	; Onto next row

	inc   r22
	dec   r21
	breq  .+2
	rjmp  SQ_XRAM_BitmapCopy_loop

	; All done

	pop   r2
	pop   r3
	pop   r4
	pop   r16
	pop   r17
	ret



;
; Scheduled bitmap ops.
;
; void SQ_MEM_BitmapBlit1Sched(uint8_t xpos, uint8_t ypos, uint8_t width, uint8_t height, uint8_t const* ptr, uint16_t colmap);
; void SQ_MEM_BitmapBlit2Sched(uint8_t xpos, uint8_t ypos, uint8_t width, uint8_t height, uint8_t const* ptr, uint16_t colmap);
; void SQ_XRAM_BitmapCopySched(uint8_t xpos, uint8_t ypos, uint8_t width, uint8_t height, uint8_t xrambank, uint16_t xramoff);
;
; Always successful, overrides previous op. if any is in progress.
;
.global SQ_MEM_BitmapBlit1Sched
.global SQ_MEM_BitmapBlit2Sched
.global SQ_XRAM_BitmapCopySched
.section .text.SQ_BitmapSched
SQ_MEM_BitmapBlit1Sched:

	ldi   r25,     0
	rjmp  SQ_BitmapSchedComm

SQ_MEM_BitmapBlit2Sched:

	ldi   r25,     1
	rjmp  SQ_BitmapSchedComm

SQ_XRAM_BitmapCopySched:

	ldi   r25,     2

SQ_BitmapSchedComm:

	ldi   ZL,      lo8(bops_xpos)
	ldi   ZH,      hi8(bops_xpos)
	std   Z + 0,   r24     ; bops_xpos
	std   Z + 1,   r22     ; bops_ypos
	std   Z + 2,   r20     ; bops_width
	std   Z + 3,   r18     ; bops_height
	std   Z + 4,   r17     ; bops_addrcmap + 0
	std   Z + 5,   r16     ; bops_addrcmap + 1
	std   Z + 6,   r15     ; bops_addrcmap + 2
	std   Z + 7,   r14     ; bops_addrcmap + 3
	std   Z + 8,   r25     ; bops_flags
	ret



;
; Checks whether a scheduled bitmap op. is in progress.
;
; uint8_t SQ_IsBitmapOpScheduled(void);
;
; Returns:
;     r24: Nonzero if scheduled bitmap op. is in progress.
;
.global SQ_IsBitmapOpScheduled
.section .text.SQ_IsBitmapOpScheduled
SQ_IsBitmapOpScheduled:

	lds   r24,     bops_height
	clr   r1
	cpse  r24,     r1
	ldi   r24,     1
	ret




.section .text.SQ_BitmapBlitCommon

;
; Internal section reader for 200 / 232 px bitmaps.
;
; Reads an 8 pixels wide section from the bitmap which can then be used to
; combine pixel data over it.
;
;     r24: X pixel position, low 3 bits ignored.
;     r22: Y pixel position
;      r4: sq_bitmap_bank
;  r3: r2: sq_bitmap_ptr, needs a -8 displacement for 232px
; Returns:
; r19 -> r16: Pixel data.
; Clobbers:
; r0, r1 (zero)
;
0:
	ret

SQ_Bitmap_ReadSec:

	cpi   r24,     200
	sbic  _SFR_IO_ADDR(GPIOR0), 5 ; 232px?
	cpi   r24,     232
	brcc  0b               ; Just drop if X position is too large
	cpi   r22,     200
	brcc  0b               ; Just drop if Y position is not in the max. 200 rows

	cbi   _SFR_IO_ADDR(PORTA), PA4 ; Chip select
	push  r25
	ldi   r25,     0x03    ; Read from SPI RAM
	out   _SFR_IO_ADDR(SPDR), r25
	push  r24
	push  r23
	push  r22
	push  XH
	push  XL
	andi  r24,     0xF8
	lsr   r24
	lsr   r24
	mov   XL,      r24
	mov   XH,      r22

	ldi   r23,     100
	mul   r22,     r23
	mov   r22,     r24
	ldi   r23,     0
	add   r22,     r0
	adc   r23,     r1      ; r23:r22: Offset of first byte in image
	ldi   r24,     0
	clr   r1
	add   r22,     r2
	adc   r23,     r3
	adc   r24,     r4

	sbis  _SFR_IO_ADDR(GPIOR0), 5 ; 232px?
	rjmp  2f

	; Read even bytes from RAM on the sides of a 232px image

	cpi   XL,      8
	brcs  1f
	cpi   XL,      50
	brcs  2f
	subi  XL,      42
1:
	ldi   r25,     16
	mul   XH,      r25
	ldi   XH,      0
	add   r0,      XL
	adc   r1,      XH
	movw  XL,      r0
	clr   r1
	subi  XL,      lo8(-(sq_ramtiles_base))
	sbci  XH,      hi8(-(sq_ramtiles_base))
	ld    r19,     X+
	ld    r17,     X+      ; Data was in RAM for a 232px image
	rjmp  3f

	; Read even bytes (these are the prefetched bytes on scanlines)
2:
	rcall SQ_Bitmap_SPIAddr
	out   _SFR_IO_ADDR(SPDR), r22 ; Dummy out to get 1st byte
	rcall SQ_Bitmap_SPIWait16
	in    r19,     _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r19
	rcall SQ_Bitmap_SPIWait16
	in    r17,     _SFR_IO_ADDR(SPDR)
	sbi   _SFR_IO_ADDR(PORTA), PA4 ; Chip deselect
	lpm   r0,      Z
	lpm   r0,      Z
	cbi   _SFR_IO_ADDR(PORTA), PA4 ; Chip select
	ldi   r25,     0x03    ; Read from SPI RAM
	out   _SFR_IO_ADDR(SPDR), r25
	lpm   r0,      Z
	lpm   r0,      Z
	lpm   r0,      Z
	rjmp  .

	; Position address at odd bytes
3:
	subi  r22,     -50     ; On both 200px and 232px this relation is the same
	sbci  r23,     0xFF
	sbci  r24,     0xFF

	; Read odd bytes (these are streamed directly on scanlines)

	rcall SQ_Bitmap_SPIAddr
	out   _SFR_IO_ADDR(SPDR), r22 ; Dummy out to get 1st byte
	rcall SQ_Bitmap_SPIWait16
	in    r18,     _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r18
	pop   XL
	pop   XH
	pop   r22
	pop   r23
	pop   r24
	pop   r25
	rjmp  .
	rjmp  .
	in    r16,     _SFR_IO_ADDR(SPDR)
	sbi   _SFR_IO_ADDR(PORTA), PA4 ; Chip deselect

	; Done

	ret



;
; Internal section writer for 200 / 232 px bitmaps.
;
; Writes an 8 pixels wide section into the bitmap.
;
;     r24: X pixel position, low 3 bits ignored.
;     r22: Y pixel position
;      r4: sq_bitmap_bank
;  r3: r2: sq_bitmap_ptr, needs a -8 displacement for 232px
; r19 -> r16: Pixel data.
; Clobbers:
; r0, r1 (zero)
;
0:
	ret

SQ_Bitmap_WriteSec:

	cpi   r24,     200
	sbic  _SFR_IO_ADDR(GPIOR0), 5 ; 232px?
	cpi   r24,     232
	brcc  0b               ; Just drop if X position is too large
	cpi   r22,     200
	brcc  0b               ; Just drop if Y position is not in the max. 200 rows

	cbi   _SFR_IO_ADDR(PORTA), PA4 ; Chip select
	push  r25
	ldi   r25,     0x02    ; Write into SPI RAM
	out   _SFR_IO_ADDR(SPDR), r25
	push  r24
	push  r23
	push  r22
	push  XH
	push  XL
	andi  r24,     0xF8
	lsr   r24
	lsr   r24
	mov   XL,      r24
	mov   XH,      r22

	ldi   r23,     100
	mul   r22,     r23
	mov   r22,     r24
	ldi   r23,     0
	add   r22,     r0
	adc   r23,     r1      ; r23:r22: Offset of first byte in image
	ldi   r24,     0
	clr   r1
	add   r22,     r2
	adc   r23,     r3
	adc   r24,     r4

	sbis  _SFR_IO_ADDR(GPIOR0), 5 ; 232px?
	rjmp  2f

	; Write even bytes into RAM on the sides of a 232px image

	cpi   XL,      8
	brcs  1f
	cpi   XL,      50
	brcs  2f
	subi  XL,      42
1:
	ldi   r25,     16
	mul   XH,      r25
	ldi   XH,      0
	add   r0,      XL
	adc   r1,      XH
	movw  XL,      r0
	clr   r1
	subi  XL,      lo8(-(sq_ramtiles_base))
	sbci  XH,      hi8(-(sq_ramtiles_base))
	st    X+,      r19
	st    X+,      r17     ; Data goes in RAM for a 232px image
	rjmp  3f

	; Write even bytes (these are the prefetched bytes on scanlines)
2:
	rcall SQ_Bitmap_SPIAddr
	out   _SFR_IO_ADDR(SPDR), r19
	rcall SQ_Bitmap_SPIWait17
	out   _SFR_IO_ADDR(SPDR), r17
	rcall SQ_Bitmap_SPIWait17
	sbi   _SFR_IO_ADDR(PORTA), PA4 ; Chip deselect
	lpm   r0,      Z
	lpm   r0,      Z
	cbi   _SFR_IO_ADDR(PORTA), PA4 ; Chip select
	ldi   r25,     0x02    ; Write into SPI RAM
	out   _SFR_IO_ADDR(SPDR), r25
	lpm   r0,      Z
	lpm   r0,      Z
	lpm   r0,      Z
	rjmp  .

	; Position address at odd bytes
3:
	subi  r22,     -50     ; On both 200px and 232px this relation is the same
	sbci  r23,     0xFF
	sbci  r24,     0xFF

	; Write odd bytes (these are streamed directly on scanlines)

	rcall SQ_Bitmap_SPIAddr
	out   _SFR_IO_ADDR(SPDR), r18
	rcall SQ_Bitmap_SPIWait17
	out   _SFR_IO_ADDR(SPDR), r16
	pop   XL
	pop   XH
	pop   r22
	pop   r23
	pop   r24
	pop   r25
	rjmp  .
	lpm   r0,      Z
	sbi   _SFR_IO_ADDR(PORTA), PA4 ; Chip deselect

	; Done

	ret



;
; Internal 8 pixel segment reader (arbitrary normally laid out source)
;
;     r23: Source bank
;  ZH: ZL: Source offset
; Returns:
; r19 -> r16: Pixel data.
; Clobbers:
; r0, r1 (zero)
;
SQ_Bitmap_Read8px:

	cbi   _SFR_IO_ADDR(PORTA), PA4 ; Chip select
	push  r25
	ldi   r25,     0x03    ; Read from SPI RAM
	out   _SFR_IO_ADDR(SPDR), r25
	rcall SQ_Bitmap_SPIWait17
	out   _SFR_IO_ADDR(SPDR), r23
	rcall SQ_Bitmap_SPIWait17
	out   _SFR_IO_ADDR(SPDR), ZH
	rcall SQ_Bitmap_SPIWait17
	out   _SFR_IO_ADDR(SPDR), ZL
	rcall SQ_Bitmap_SPIWait17
	out   _SFR_IO_ADDR(SPDR), ZL ; Dummy out to get 1st byte
	rcall SQ_Bitmap_SPIWait16
	in    r19,     _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r19
	rcall SQ_Bitmap_SPIWait16
	in    r18,     _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r18
	rcall SQ_Bitmap_SPIWait16
	in    r17,     _SFR_IO_ADDR(SPDR)
	out   _SFR_IO_ADDR(SPDR), r17
	rcall SQ_Bitmap_SPIWait16
	in    r16,     _SFR_IO_ADDR(SPDR)
	pop   r25
	sbi   _SFR_IO_ADDR(PORTA), PA4 ; Chip deselect
	ret



;
; Internal SPI RAM address set-up
; r24:r23:r22 for address, r25 clobbered
;
SQ_Bitmap_SPIAddr:
	out   _SFR_IO_ADDR(SPDR), r24
	rcall SQ_Bitmap_SPIWait17
	out   _SFR_IO_ADDR(SPDR), r23
	rcall SQ_Bitmap_SPIWait17
	out   _SFR_IO_ADDR(SPDR), r22
	lpm   r25,     Z
SQ_Bitmap_SPIWait17:
	nop
SQ_Bitmap_SPIWait16:
	ldi   r25,     3
	dec   r25
	brne  .-4
	ret



;
; Internal: Bitmap Operation Scheduler, called in spare frame time.
; This must be present (SQ_End calls it).
;
SQ_BOPScheduler:

	ldi   ZL,      0xFF    ; Empty stack, there will be no return
	out   _SFR_IO_ADDR(SPL), ZL

	ldi   YL,      lo8(bops_xpos)
	ldi   YH,      hi8(bops_xpos)
	ldd   r18,     Y + 3   ; bops_height
	cpi   r18,     0
	breq  8f               ; Zero height?

9:
	ldd   r24,     Y + 0   ; bops_xpos
	ldd   r22,     Y + 1   ; bops_ypos
	ldd   r20,     Y + 2   ; bops_width
	ldd   r17,     Y + 4   ; bops_addrcmap + 0
	ldd   r16,     Y + 5   ; bops_addrcmap + 1
	ldd   r15,     Y + 6   ; bops_addrcmap + 2
	ldd   r14,     Y + 7   ; bops_addrcmap + 3
	ldd   r25,     Y + 8   ; bops_flags

	mov   r23,     r18
	dec   r23
	add   r22,     r23     ; Bottom to up, so only height needs updating
	ldi   r18,     1       ; Output 1 row in one pass

	cpi   r25,     1
	brcs  0f
	breq  1f

	mov   r21,     r20
	andi  r21,     0xF8
	lsr   r21
	mul   r21,     r23
	add   r14,     r0
	adc   r15,     r1
	eor   r1,      r1
	adc   r16,     r1      ; Displace source by currently drawn row
	call  SQ_XRAM_BitmapCopy
	rjmp  7f
1:

	mov   r21,     r20
	subi  r21,     0xFD    ; +3
	lsr   r21
	lsr   r21
	mul   r21,     r23
	add   r16,     r0
	adc   r17,     r1
	clr   r1               ; Displace source by currently drawn row
	call  SQ_MEM_BitmapBlit2
	rjmp  7f
0:

	mov   r21,     r20
	subi  r21,     0xF9    ; +7
	lsr   r21
	lsr   r21
	lsr   r21
	mul   r21,     r23
	add   r16,     r0
	adc   r17,     r1
	clr   r1               ; Displace source by currently drawn row
	call  SQ_MEM_BitmapBlit1
7:

	ldd   r18,     Y + 3   ; bops_height
	dec   r18
	std   Y + 3,   r18     ; bops_height, graphics op. finalized
	brne  9b
8:
	rjmp  .-2              ; Zero height: Nothing sequenced, done
