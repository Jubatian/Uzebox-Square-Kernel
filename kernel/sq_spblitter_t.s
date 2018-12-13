;
; Uzebox Square Kernel - Sprite blitter (SPI RAM source)
; Copyright (C) 2015 - 2018 Sandor Zsuga (Jubatian)
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.
;
; Uzebox is a reserved trade mark
;



;
; Note: No section specification here! (.section .text)
; This is because this component belongs to the sprite engine, sitting in its
; section.
;



;
; Blits a sprite onto a 8x8 4bpp RAM tile
;
; Outputs the appropriate fraction of a sprite on a RAM tile. The sprite has
; fixed 8x8 pixel layout, 4 bytes per line, 32 bytes total, high nybble first
; for pixels. Color index 0 is transparent.
;
; Worst case should be around 900 cycles. For rendering a complete 8x8 sprite
; (onto 4 RAM tiles) it should take 1400 cycles (worst case). For masked
; sprites, around 1100 cycles, for complete sprite, around 1800 cycles (if all
; sprite pixels are rendered, that is, the mask has no effect).
;
; An SPI RAM read has to be started 10 cycles before entry.
;
; r25:r24: Source 8x8 sprite start address
;       Y: Target RAM tile address
;     r23: Y location on tile (2's complement; 0xF9 - 0x07)
;     r22: X location on tile (2's complement; 0xF9 - 0x07)
;     r16: Flags
;          bit0: If set, flip horizontally
;          bit1: If set, sprite source is in high bank of SPI RAM
;          bit2: If set, flip vertically
;          bit3: Original mask usage flag to be restored on exit
;          bit4: If set, mask is used
;     r11: Recolor table select
;     r1:  Zero
; r15:r14: Mask source offset (8 bytes). Only used if r16 bit4 is set
; Clobbered registers:
; r0, r14, r15, r17, r18, r19, r20, r21, r22, r23, XL, XH, YL, YH, ZL, ZH, T
;
sq_blitspritept:

	; Save a few registers to have something to work with

	push  r12              ; (14) Will be used for loop counter
	mov   XL,      r16
	lsr   XL
	andi  XL,      1       ; (17)
	out   SR_DR,   XL      ; SPI: Address high
	push  r6
	push  r7               ; ( 4) Will be used for loading from SPI RAM

	; Calculate source start offset & send it

	movw  r6,      r24     ; ( 5) Source offset (in SPI RAM)
	sbrs  r16,     2
	rjmp  0f               ; ( 8) No vertical flipping
	sbrc  r23,     7
	rjmp  2f               ; (10) Y loc. negative: Source address OK
	mov   r21,     r23     ; (10) Number of lines to adjust source
	rjmp  1f               ; (12)
2:
	nop
3:
	lpm   r12,     Z       ; (14) Dummy load (nop)
	rjmp  4f               ; (16)
0:
	sbrs  r23,     7
	rjmp  3b               ; (11) Y loc. positive: Source address OK
	mov   r21,     r23
	neg   r21              ; (12) Number of lines to adjust source
1:
	lsl   r21
	lsl   r21
	add   r6,      r21
	adc   r7,      r1      ; (16)
4:

	nop
	out   SR_DR,   r7      ; SPI: Address mid
	rcall splw17
	out   SR_DR,   r6      ; SPI: Address low
	rcall splw17
	out   SR_DR,   r6      ; SPI: Dummy byte to begin data fetches
	rcall splw10

	; Shortcut entry point, used by an interleaving hack in the RAM tile
	; allocator to eliminate the SPI waits by interleaving the ROM->RAM
	; copy with the address preparation.

sq_blitspritept_short:

	; Save some more registers

	push  r8
	push  r9

	; Calculate no. of lines to generate & dest. / mask start offsets

	ldi   r20,     8       ; (15) Normally 8 lines are generated
	mov   r12,     r20
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	sbrs  r23,     7
	rjmp  spbd0            ; Y location positive (moving down)
	add   r12,     r23     ; Negative Y location: add to line count
	lpm   r0,      Z
	rjmp  spbd1            ; ( 8)
spbd0:
	sub   r12,     r23     ; Positive Y location: subtract from line count
	add   r14,     r23     ; Add to mask source
	lsl   r23
	lsl   r23
	add   YL,      r23     ; ( 8) Add to destination location (4 bytes / row)
spbd1:

	; Prepare color remapping table

	lds   r19,     sq_coltab_pth ; (10)

	; Adjust for vertical flipping

	sbrc  r16,     2
	rjmp  spbd2            ; Vertical flipping present
	ldi   XL,      0x04    ; Add to destination (Offset within RAM tile)
	ldi   XH,      0x01    ; Add to mask (if any)
	rjmp  .
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	lpm   r21,     Z
	rjmp  spbd3            ; ( 5)
spbd2:
	mov   r21,     r12     ; Get no. of lines to draw - 1
	dec   r21
	ldi   XL,      0xFC    ; Add to destination (Offset within RAM tile)
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	ldi   XH,      0xFF    ; Add to mask (if any)
	add   r14,     r21     ; First mask line when flipped
	lsl   r21
	lsl   r21
	add   YL,      r21     ; ( 5) First dest. line when flipped
spbd3:

	; Calculate jump target by X alignment & flip into r1:r0

	subi  r22,     0xF9    ; Add 7; 0xF9 - 0x07 becomes 0x00 - 0x0E
	sbrc  r16,     0       ; Flipped?
	subi  r22,     0xF1    ; Add 15 to reach flipped jump table
	lsl   r22
	ldi   ZL,      lo8(spllineentry)
	ldi   ZH,      hi8(spllineentry)
	add   ZL,      r22
	adc   ZH,      r1
	lpm   r0,      Z+
	in    r7,      SR_DR   ; SPI, byte 2
	out   SR_DR,   r7      ; SPI, byte 2
	lpm   r1,      Z+      ; ( 3) From now r1 is not zero

	; Render the sprite part (two separate loops: one with masking and
	; one without)

	nop                    ; ( 4)
	sbrc  r16,     4       ; ( 5 /  6) Has mask?
	rjmp  spbml            ; ( 7) Enter render loop with mask
	rjmp  .
	rjmp  .
	clr   r17              ; (11) Use zero for mask
	rjmp  spbl             ; (13) No mask, enter maskless render loop
spblret:
	dec   r12              ; (11)
	breq  spbex
	add   YL,      XL      ; (13) Destination adjustment
spbl:
	movw  ZL,      r0      ; (14) Load jump target
	ijmp                   ; (16)
spbmlret:
	dec   r12              ; ( 6)
	breq  spbex
	add   YL,      XL      ; ( 8) Destination adjustment
spbml:
	movw  ZL,      r14     ; ( 9) Load mask offset
	lpm   r17,     Z       ; (12) ROM mask source (no RAM masks in SQ kernel)
	add   r14,     XH      ; (13) Mask adjustment
	movw  ZL,      r0      ; (14) Load jump target
	ijmp                   ; (16)

	; Done, clean up and return (at this point a last SPI transmission is
	; still in progress, but will finish during the pops).

spbex:
	pop   r9
	pop   r8
	pop   r7
	pop   r6
	pop   r12
	clr   r1
	bst   r16,     3
	bld   r16,     4       ; Restore mask usage flag
	sbi   SR_PORT, SR_PIN  ; Done with SPI RAM
	ret



;
; Blits a single 8px wide sprite line onto a tile
;
; Outputs a single 8 pixels wide sprite line from a source 4bpp buffer onto a
; target 4bpp tile line using color index 0 transparency. Number of pixels
; generated depends on the alignment.
;
; The SPI data (4 bytes) is loaded into r9:r8:r7:r6, last "in" (for r6)
; performed upon entry.
;
; Y:       Destination start address. Preserved.
; r11:     Color remapping table index
; r16:     bit4: If set, has mask
; r17:     Mask: set bits inhibit sprite pixel output.
; r19:     Color remapping table high
; Clobbered registers:
; r17 (bits only cleared), r18, r20, r21, r22, r23, ZL, ZH
;
spllineentry:
	.word pm(splr7)        ; S0000000
	.word pm(splr6)        ; SS000000
	.word pm(splr5)        ; SSS00000
	.word pm(splr4)        ; SSSS0000
	.word pm(splr3)        ; SSSSS000
	.word pm(splr2)        ; SSSSSS00
	.word pm(splr1)        ; SSSSSSS0
	.word pm(spla0)        ; SSSSSSSS
	.word pm(spll1)        ; 0SSSSSSS
	.word pm(spll2)        ; 00SSSSSS
	.word pm(spll3)        ; 000SSSSS
	.word pm(spll4)        ; 0000SSSS
	.word pm(spll5)        ; 00000SSS
	.word pm(spll6)        ; 000000SS
	.word pm(spll7)        ; 0000000S
	.word pm(splr7f)       ; S0000000
	.word pm(splr6f)       ; SS000000
	.word pm(splr5f)       ; SSS00000
	.word pm(splr4f)       ; SSSS0000
	.word pm(splr3f)       ; SSSSS000
	.word pm(splr2f)       ; SSSSSS00
	.word pm(splr1f)       ; SSSSSSS0
	.word pm(spla0f)       ; SSSSSSSS
	.word pm(spll1f)       ; 0SSSSSSS
	.word pm(spll2f)       ; 00SSSSSS
	.word pm(spll3f)       ; 000SSSSS
	.word pm(spll4f)       ; 0000SSSS
	.word pm(spll5f)       ; 00000SSS
	.word pm(spll6f)       ; 000000SS
	.word pm(spll7f)       ; 0000000S


	; S0000000

splr7:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   ZL,      r6
	rjmp  splr7c
splr7f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   ZL,      r9
	swap  ZL
	nop
splr7c:
	andi  ZL,      0x0F
	mov   ZH,      r19
	add   ZL,      r11
	lpm   r20,     Z
	swap  r20
	sbrc  r17,     7       ; Process mask
	andi  r20,     0x0F
	rjmp  .
	rjmp  .
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	rcall splw16
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	rjmp  .
	rjmp  splpxre

	; SS000000

splr6:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r20,     r6
	rjmp  splr6c
splr6f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r20,     r9
	swap  r20
	nop
splr6c:
	mov   ZH,      r19
	mov   ZL,      r20
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r20
	andi  ZL,      0x0F
	add   ZL,      r11
	nop
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	lpm   r20,     Z
	or    r20,     r18
	sbrc  r17,     7       ; Process mask
	andi  r20,     0x0F
	sbrc  r17,     6
	andi  r20,     0xF0
	rcall splw8
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	rjmp  .
	rjmp  splpxre

	; SSS00000

splr5:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r20,     r7
	mov   r21,     r6
	rjmp  splr5c
splr5f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r21,     r9
	mov   r20,     r8
	swap  r20
	swap  r21
splr5c:
	mov   ZH,      r19
	mov   ZL,      r20
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r20,     Z
	swap  r20
	mov   ZL,      r21
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	lpm   r18,     Z
	or    r20,     r18
	mov   ZL,      r21
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r21,     Z
	swap  r21
	clr   r22
	clr   r23
	lpm   r8,      Z
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	rjmp  .
	rjmp  .
	nop
	rjmp  splr5me          ; Process mask

	; SSSS0000

splr4:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r20,     r7
	mov   r21,     r6
	rjmp  splr4c
splr4f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r21,     r9
	mov   r20,     r8
	swap  r20
	swap  r21
splr4c:
	mov   ZH,      r19
	mov   ZL,      r20
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r20
	andi  ZL,      0x0F
	add   ZL,      r11
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	lpm   r20,     Z
	or    r20,     r18
	mov   ZL,      r21
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r21
	andi  ZL,      0x0F
	add   ZL,      r11
	clr   r22
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	lpm   r21,     Z
	or    r21,     r18
	clr   r23
	rjmp  splr4me          ; Process mask

	; Masking block

splr3me:
	sbrc  r17,     3
	andi  r22,     0x0F
splr4me:
	sbrc  r17,     4
	andi  r21,     0xF0
splr5me:
	sbrc  r17,     7
	andi  r20,     0x0F
	sbrc  r17,     6
	andi  r20,     0xF0
	sbrc  r17,     5
	andi  r21,     0x0F
	rjmp  splpxe8

	; SSSSS000

splr3f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r22,     r9
	mov   r21,     r8
	mov   r20,     r7
	swap  r20
	swap  r21
	swap  r22
splr3c:
	mov   ZH,      r19
	mov   ZL,      r20
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r20,     Z
	swap  r20
	mov   ZL,      r21
	swap  ZL
	andi  ZL,      0x0F
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	add   ZL,      r11
	lpm   r18,     Z
	or    r20,     r18
	mov   ZL,      r21
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r21,     Z
	swap  r21
	mov   ZL,      r22
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	lpm   r18,     Z
	or    r21,     r18
	mov   ZL,      r22
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r22,     Z
	swap  r22
	clr   r23
	andi  r17,     0xF8    ; Process mask
	brne  splr3me
	rjmp  splpxe8
splr3:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r20,     r8
	mov   r21,     r7
	mov   r22,     r6
	rjmp  splr3c

	; SSSSSS00

splr2:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r20,     r8
	mov   r21,     r7
	mov   r22,     r6
	rjmp  splr2c
splr2f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r22,     r9
	mov   r21,     r8
	mov   r20,     r7
	swap  r20
	swap  r21
	swap  r22
splr2c:
	mov   ZH,      r19
	mov   ZL,      r20
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r20
	andi  ZL,      0x0F
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	add   ZL,      r11
	lpm   r20,     Z
	or    r20,     r18
	mov   ZL,      r21
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r21
	andi  ZL,      0x0F
	add   ZL,      r11
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	lpm   r21,     Z
	or    r21,     r18
	mov   ZL,      r22
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r22
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r22,     Z
	or    r22,     r18
	clr   r23
	andi  r17,     0xFC    ; Process mask
	brne  splr2me
	rjmp  splpxe8

	; SSSSSSS0

splr1:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   ZH,      r19
	mov   ZL,      r9
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r8
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r20,     Z
	or    r20,     r18
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	mov   ZL,      r8
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r7
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r21,     Z
	or    r21,     r18
	mov   ZL,      r7
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r6
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r22,     Z
	or    r22,     r18
	mov   ZL,      r6
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r23,     Z
	swap  r23
	andi  r17,     0xFE    ; Process mask
	brne  splr1me
	rjmp  splpxe8

splr1f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   ZH,      r19
	mov   ZL,      r9
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r23,     Z
	swap  r23
	mov   ZL,      r9
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	mov   ZL,      r8
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r22,     Z
	swap  r22
	or    r22,     r18
	mov   ZL,      r8
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	mov   ZL,      r7
	andi  ZL,      0x0F
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	add   ZL,      r11
	lpm   r21,     Z
	swap  r21
	or    r21,     r18
	mov   ZL,      r7
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	mov   ZL,      r6
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r20,     Z
	swap  r20
	or    r20,     r18
	andi  r17,     0xFE    ; Process mask
	brne  splr1me
	rjmp  splpxe8


splr1f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	movw  r22,     r8
	movw  r20,     r6
	swap  r20
	swap  r21
	swap  r22
	swap  r23
splr1c:
	mov   ZH,      r19
	mov   ZL,      r20
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r20,     Z
	swap  r20
	mov   ZL,      r21
	swap  ZL
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	or    r20,     r18
	mov   ZL,      r21
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r21,     Z
	swap  r21
	mov   ZL,      r22
	swap  ZL
	andi  ZL,      0x0F
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	add   ZL,      r11
	lpm   r18,     Z
	or    r21,     r18
	mov   ZL,      r22
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r22,     Z
	swap  r22
	mov   ZL,      r23
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	or    r22,     r18
	mov   ZL,      r23
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r23,     Z
	swap  r23
	andi  r17,     0xFE    ; Process mask
	brne  splr1me
	rjmp  splpxe8

	; Masking block

splr1me:
	sbrc  r17,     1
	andi  r23,     0x0F
splr2me:
	sbrc  r17,     7
	andi  r20,     0x0F
	sbrc  r17,     6
	andi  r20,     0xF0
	sbrc  r17,     5
	andi  r21,     0x0F
	sbrc  r17,     4
	andi  r21,     0xF0
	sbrc  r17,     3
	andi  r22,     0x0F
	sbrc  r17,     2
	andi  r22,     0xF0
	rjmp  splpxe8

splr1:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r20,     r9
	mov   r21,     r8
	mov   r22,     r7
	mov   r23,     r6
	rjmp  splr1c

	; SSSSSSSS

spla0:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   ZH,      r19
	mov   ZL,      r9
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r9
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r20,     Z
	or    r20,     r18
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	mov   ZL,      r8
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r8
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r21,     Z
	or    r21,     r18
	mov   ZL,      r7
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r7
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r22,     Z
	or    r22,     r18
	mov   ZL,      r6
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r6
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r23,     Z
	or    r23,     r18
	andi  r17,     0xFF    ; Process mask
	brne  spla0me
	rjmp  splpxe8

spla0f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   ZH,      r19
	mov   ZL,      r9
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r9
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r23,     Z
	or    r23,     r18
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	mov   ZL,      r8
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r8
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r22,     Z
	or    r22,     r18
	mov   ZL,      r7
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r7
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r21,     Z
	or    r21,     r18
	mov   ZL,      r6
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r6
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r20,     Z
	or    r20,     r18
	andi  r17,     0xFF    ; Process mask
	brne  spla0me
	rjmp  splpxe8

	; Masking block

spla0me:
	sbrc  r17,     7
	andi  r20,     0x0F
	sbrc  r17,     6
	andi  r20,     0xF0
	sbrc  r17,     5
	andi  r21,     0x0F
	sbrc  r17,     4
	andi  r21,     0xF0
	sbrc  r17,     3
	andi  r22,     0x0F
	sbrc  r17,     2
	andi  r22,     0xF0
	sbrc  r17,     1
	andi  r23,     0x0F
	sbrc  r17,     0
	andi  r23,     0xF0
	rjmp  splpxe8

	; 0SSSSSSS

spll1:


spll1:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r20,     r9
	mov   r21,     r8
	mov   r22,     r7
	mov   r23,     r6
	rjmp  spll1c
spll1f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	movw  r22,     r8
	movw  r20,     r6
	swap  r20
	swap  r21
	swap  r22
	swap  r23
spll1c:
	mov   ZH,      r19
	mov   ZL,      r23
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r23,     Z
	mov   ZL,      r22
	andi  ZL,      0x0F
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	or    r23,     r18
	mov   ZL,      r22
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r22,     Z
	mov   ZL,      r21
	andi  ZL,      0x0F
	add   ZL,      r11
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	lpm   r18,     Z
	swap  r18
	or    r22,     r18
	mov   ZL,      r21
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r21,     Z
	mov   ZL,      r20
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	or    r21,     r18
	mov   ZL,      r20
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r20,     Z
	andi  r17,     0x7F    ; Process mask
	brne  spll1me
	rjmp  splpxe8

	; Masking block

spll1me:
	sbrc  r17,     6
	andi  r20,     0xF0
spll2me:
	sbrc  r17,     5
	andi  r21,     0x0F
	sbrc  r17,     4
	andi  r21,     0xF0
	sbrc  r17,     3
	andi  r22,     0x0F
	sbrc  r17,     2
	andi  r22,     0xF0
	sbrc  r17,     1
	andi  r23,     0x0F
	sbrc  r17,     0
	andi  r23,     0xF0
	rjmp  splpxe8

	; 00SSSSSS

spll2f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r23,     r8
	mov   r22,     r7
	mov   r21,     r6
	swap  r21
	swap  r22
	swap  r23
spll2c:
	mov   ZH,      r19
	mov   ZL,      r21
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r21
	andi  ZL,      0x0F
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	add   ZL,      r11
	lpm   r21,     Z
	or    r21,     r18
	mov   ZL,      r22
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r22
	andi  ZL,      0x0F
	add   ZL,      r11
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	lpm   r22,     Z
	or    r22,     r18
	mov   ZL,      r23
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r23
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r23,     Z
	or    r23,     r18
	clr   r20
	andi  r17,     0x3F    ; Process mask
	brne  spll2me
	rjmp  splpxe8
spll2:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r21,     r9
	mov   r22,     r8
	mov   r23,     r7
	rjmp  spll2c

	; 000SSSSS

spll3:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r21,     r9
	mov   r22,     r8
	mov   r23,     r7
	nop
	rjmp  spll3c
spll3f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r23,     r8
	mov   r22,     r7
	mov   r21,     r6
	swap  r21
	swap  r22
	swap  r23
spll3c:
	mov   ZH,      r19
	mov   ZL,      r23
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r23,     Z
	mov   ZL,      r22
	andi  ZL,      0x0F
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	or    r23,     r18
	mov   ZL,      r22
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r22,     Z
	mov   ZL,      r21
	andi  ZL,      0x0F
	add   ZL,      r11
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	lpm   r18,     Z
	swap  r18
	or    r22,     r18
	mov   ZL,      r21
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r21,     Z
	clr   r20
	andi  r17,     0x1F    ; Process mask
	brne  spll3me
	rjmp  splpxe8

	; 0000SSSS

spll4:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r22,     r9
	mov   r23,     r8
	rjmp  spll4c
spll4f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r23,     r7
	mov   r22,     r6
	swap  r22
	swap  r23
spll4c:
	mov   ZH,      r19
	mov   ZL,      r22
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r22
	andi  ZL,      0x0F
	add   ZL,      r11
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	lpm   r22,     Z
	or    r22,     r18
	mov   ZL,      r23
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r23
	andi  ZL,      0x0F
	add   ZL,      r11
	clr   r20
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	lpm   r23,     Z
	or    r23,     r18
	clr   r21
	rjmp  spll4me          ; Process mask

	; Masking block

spll3me:
	sbrc  r17,     4
	andi  r21,     0xF0
spll4me:
	sbrc  r17,     3
	andi  r22,     0x0F
spll5me:
	sbrc  r17,     2
	andi  r22,     0xF0
	sbrc  r17,     1
	andi  r23,     0x0F
	sbrc  r17,     0
	andi  r23,     0xF0
	rjmp  splpxe8

	; 00000SSS

spll5:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r22,     r9
	mov   r23,     r8
	rjmp  spll5c
spll5f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r23,     r7
	movw  r22,     r6
	swap  r22
	swap  r23
spll5c:
	mov   ZH,      r19
	mov   ZL,      r23
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r23,     Z
	mov   ZL,      r22
	andi  ZL,      0x0F
	add   ZL,      r11
	nop
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	lpm   r18,     Z
	swap  r18
	or    r23,     r18
	mov   ZL,      r22
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r22,     Z
	clr   r20
	clr   r21
	rjmp  .
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	rjmp  .
	rjmp  .
	nop
	rjmp  spll5me          ; Process mask

	; 000000SS

spll6:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r23,     r9
	rjmp  spll6c
spll6f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   r23,     r6
	swap  r23
	nop
spll6c:
	mov   ZH,      r19
	mov   ZL,      r23
	swap  ZL
	andi  ZL,      0x0F
	add   ZL,      r11
	lpm   r18,     Z
	swap  r18
	mov   ZL,      r23
	andi  ZL,      0x0F
	add   ZL,      r11
	nop
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	lpm   r23,     Z
	or    r23,     r18
	sbrc  r17,     1       ; Process mask
	andi  r23,     0x0F
	sbrc  r17,     0
	andi  r23,     0xF0
	rcall splw8
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	rjmp  .
	rjmp  splpxle

	; 0000000S

spll7:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   ZL,      r9
	swap  ZL
	rjmp  spll7c
spll7f:
	in    r6,      SR_DR   ; SPI, byte 3
	out   SR_DR,   r6      ; SPI, byte 3
	mov   ZL,      r6
	nop
	rjmp  .
spll7c:
	andi  ZL,      0x0F
	mov   ZH,      r19
	add   ZL,      r11
	lpm   r23,     Z
	sbrc  r17,     0       ; Process mask
	andi  r23,     0xF0
	rjmp  .
	rjmp  .
	in    r9,      SR_DR   ; SPI, byte 0
	out   SR_DR,   r9      ; SPI, byte 0
	rcall splw16
	in    r8,      SR_DR   ; SPI, byte 1
	out   SR_DR,   r8      ; SPI, byte 1
	rjmp  .
	rjmp  splpxle


	; Waits (for SPI timing), to be called with rcall

splw17:
	nop
splw16:
	nop
splw15:
	nop
splw14:
	nop
splw13:
	nop
splw12:
	nop
splw11:
	nop
splw10:
	nop
splw9:
	nop
splw8:
	nop
splw7:
	ret


	; Pixel blitting. The fastest path through this is 11 cycles (without
	; the SPI access, no sprite content). The main entry point is splpxe8
	; (other entry points are not used since they provide minimal boost in
	; the ordinary blitter, here they are omitted to get the 11 cycle
	; minimum for timing SPI accesses).
	;
	; After SPI, byte 2 there are at least 10 cycles, while there are
	; enough cycles outside (in the main loop) to pad for the next SPI
	; byte access.

splpx6x:
	cpi   r21,     0x01
	brcc  splpx4n          ; ( 4; fast path)
splpx4x:
	cpi   r22,     0x01
	brcc  splpx2n          ; ( 6; fast path)
splpx2x:
	cpi   r23,     0x01
	brcc  splpx0n          ; ( 8; fast path)
splpx0x:
	sbrs  r16,     4       ; ( 9 / 10) Has mask?
	rjmp  spblret          ; (11) No mask return
	rjmp  spbmlret         ; (12) Has mask return
splpxe8:
	cpi   r20,     0x01
	in    r7,      SR_DR   ; SPI, byte 2
	out   SR_DR,   r7      ; SPI, byte 2
splpx6n:
	brcs  splpx6x          ; ( 2; fast path)
splpx6h:
	brhs  splpx6l
	cpi   r20,     0x10
	brcc  .+6
	ldd   r18,     Y + 0
	andi  r18,     0xF0
	or    r20,     r18
	std   Y + 0,   r20
splpxe6:
	cpi   r21,     0x01
	brcs  splpx4x
splpx4n:
	brhs  splpx4l
splpx4h:
	cpi   r21,     0x10
	brcc  .+6
	ldd   r18,     Y + 1
	andi  r18,     0xF0
	or    r21,     r18
	std   Y + 1,   r21
splpxe4:
	cpi   r22,     0x01
	brcs  splpx2x
splpx2n:
	brhs  splpx2l
splpx2h:
	cpi   r22,     0x10
	brcc  .+6
	ldd   r18,     Y + 2
	andi  r18,     0xF0
	or    r22,     r18
	std   Y + 2,   r22
splpxe2:
	cpi   r23,     0x01
	brcs  splpx0x
splpx0n:
	brhs  splpx0l
splpx0h:
	cpi   r23,     0x10
	brcc  .+6
	ldd   r18,     Y + 3
	andi  r18,     0xF0
	or    r23,     r18
	std   Y + 3,   r23
splexit:
	sbrs  r16,     4       ; Has mask?
	rjmp  spblret          ; No mask return
	rjmp  spbmlret         ; Has mask return
splpx6l:
	ldd   r18,     Y + 0
	andi  r18,     0x0F
	or    r20,     r18
	std   Y + 0,   r20
	cpi   r21,     0x01
	brcs  splpx4x
	brhc  splpx4h
splpx4l:
	ldd   r18,     Y + 1
	andi  r18,     0x0F
	or    r21,     r18
	std   Y + 1,   r21
	cpi   r22,     0x01
	brcs  splpx2x
	brhc  splpx2h
splpx2l:
	ldd   r18,     Y + 2
	andi  r18,     0x0F
	or    r22,     r18
	std   Y + 2,   r22
	cpi   r23,     0x01
	brcs  splpx0x
	brhc  splpx0h
splpx0l:
	ldd   r18,     Y + 3
	andi  r18,     0x0F
	or    r23,     r18
	std   Y + 3,   r23
	sbrs  r16,     4       ; Has mask?
	rjmp  spblret          ; No mask return
	rjmp  spbmlret         ; Has mask return



	; Pixel blitting for the S0000000 and SS000000 cases.
	; The blitter paths are equalized to interleave better with SPI loads,
	; optimizing for best usage on the worst case path. Only r20 might
	; contain valid (nonzero) pixels here.
	;
	; Assuming an rjmp is used to enter, 2 cycles are needed after
	; fetching SPI, byte 1 before the "rjmp splpxre".

splpxre:
	cpi   r20,     0x01
	brcs  splpxrx          ; ( 2 /  3)
	brhs  splpxrl          ; ( 3 /  4)
	cpi   r20,     0x10
	brcc  splpxrf          ; ( 5 /  6)
	nop
	ldd   r18,     Y + 0
	andi  r18,     0xF0
	or    r20,     r18     ; (10)
splpxrw:
	std   Y + 0,   r20     ; (12)
	in    r7,      SR_DR   ; SPI, byte 2
	out   SR_DR,   r7      ; SPI, byte 2
	rjmp  .
	sbrc  r16,     4       ; ( 3 / 4) Has mask?
	rjmp  spbmlret         ; ( 5) Has mask return
	rjmp  splpxee          ; ( 6)
splpxee:
	rjmp  .                ; ( 8)
	rjmp  spblret          ; (10) No mask return
splpxrl:
	ldd   r18,     Y + 0
	andi  r18,     0x0F
	or    r20,     r18
	rjmp  splpxrw          ; (10)
splpxrx:
	nop
	ldd   r20,     Y + 0
splpxrf:
	rjmp  .
	rjmp  splpxrw          ; (10)



	; Pixel blitting for the 000000SS and 0000000S cases.
	; The blitter paths are equalized to interleave better with SPI loads,
	; optimizing for best usage on the worst case path. Only r23 might
	; contain valid (nonzero) pixels here.
	;
	; Assuming an rjmp is used to enter, 2 cycles are needed after
	; fetching SPI, byte 1 before the "rjmp splpxle".

splpxle:
	cpi   r23,     0x01
	brcs  splpxlx          ; ( 2 /  3)
	brhs  splpxll          ; ( 3 /  4)
	cpi   r23,     0x10
	brcc  splpxlf          ; ( 5 /  6)
	nop
	ldd   r18,     Y + 3
	andi  r18,     0xF0
	or    r23,     r18     ; (10)
splpxlw:
	std   Y + 3,   r23     ; (12)
	in    r7,      SR_DR   ; SPI, byte 2
	out   SR_DR,   r7      ; SPI, byte 2
	rjmp  .
	sbrc  r16,     4       ; ( 3 / 4) Has mask?
	rjmp  spbmlret         ; ( 5) Has mask return
	rjmp  splpxee          ; ( 6)
splpxll:
	ldd   r18,     Y + 3
	andi  r18,     0x0F
	or    r23,     r18
	rjmp  splpxlw          ; (10)
splpxlx:
	nop
	ldd   r23,     Y + 3
splpxlf:
	rjmp  .
	rjmp  splpxlw          ; (10)
