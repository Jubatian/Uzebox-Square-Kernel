;
; Uzebox Square Kernel - Sprite output
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
; This part manages the output of sprites including the necessary RAM tile
; allocations and tile copies.
;
; It uses the 26 tile rows, also checking for the split point and Y shift to
; limit blits onto the actually visible rows (so applications need not be
; concerned by precise clipping to save RAM tiles). Since there is no logical
; scanline concept in this kernel and mode, sprite output works as normal, 0:0
; being the upper-left corner of the screen.
;
; The maximal count of RAM tiles used for sprites may be specified. Sprites
; will take RAM tiles decrementally beginning with 0x6B (at 0x0D60) until
; hitting the limit when further allocations will be ignored (this lacks the
; importance system which Mode 74 has). RAM tiles outside of the bounds of the
; sprite allocator are free for any usage.
;
; The description of mask support:
;
; For every 4bpp ROM tile there is a corresponding mask index in the mask set.
; The mask index selects the mask to use from the mask pool. Its values are to
; be interpreted as follows:
;
; 0x00 - 0xFD: Indexes masks in the mask data.
; 0xFE: Zero mask (all sprite pixels are shown).
; 0xFF: Full mask (no sprite pixels visible; no RAM tile allocation happens).
;
; Of course these only apply if the sprite was requested to be blit with mask,
; and the mask index set is present (non-NULL).
;



;
; void SQ_ClearSprites(void);
;
; Clears sprite engine state, removing all sprites from the screen, freeing up
; the RAM tiles.
;
.global SQ_ClearSprites

;
; void SQ_BlitSprite(uint16_t xramoff, uint8_t xpos, uint8_t ypos,
;                    uint8_t flg);
;
; Blits a 8x8 sprite.
;
; xpos and ypos specifies locations by the sprite's lower right corner (so
; location 0:0 produces no sprite, 1:1 would make the lower right corner pixel
; visible).
;
; The sprite has fixed 8x8 pixel layout, 4 bytes per line, 32 bytes total,
; high nybble first for pixels. Color index 0 is transparent.
;
; Color table index zero is used, so normally this should be filled for
; straight color mapping (0, 1, 2 ... 15).
;
; The flags:
; bit0: If set, flip horizontally (SQ_SPR_FLIPX)
; bit1: Address line 16 for XRAM (SQ_SPR_HIGHBANK)
; bit2: If set, flip vertically (SQ_SPR_FLIPY)
; bit4: If set, mask is used (SQ_SPR_MASK)
;
.global SQ_BlitSprite

;
; void SQ_BlitSpriteCol(uint16_t xramoff, uint8_t xpos, uint8_t ypos,
;                       uint8_t flg, uint8_t coltabidx);
;
; Blits a 8x8 sprite with recoloring.
;
; The coltabidx parameter selects the recolor table. 0 should produce no
; recoloring (straight mapping).
;
.global SQ_BlitSpriteCol

;
; void SQ_SpritePixel(uint8_t col, uint8_t xpos, uint8_t ypos, uint8_t flg);
;
; Plots a single pixel in the tiled region. Slow stuff.
;
; The flags:
; bit4: If set, mask is used (SQ_SPR_MASK)
;
.global SQ_SpritePixel

;
; void SQ_SetSpriteColMaps(uint8_t const* ptr);
;
; Set sprite color maps. Must be aligned (SQ_SECTION_TILESET for example).
; NULL restores the default color map (no remapping).
;
.global SQ_SetSpriteColMaps

;
; void SQ_SetMaxSpriteTiles(uint8_t count);
;
; Sets the maximal number of RAM tiles used for sprite render. By default this
; is 85, the maximum possible number of tiles.
;
.global SQ_SetMaxSpriteTiles



#define SR_PORT _SFR_IO_ADDR(PORTA)
#define SR_PIN  PA4
#define SR_DR   _SFR_IO_ADDR(SPDR)



.section .text.SpriteEngine



;
; void SQ_ClearSprites(void);
;
; Clears sprite engine state, removing all sprites from the screen, freeing up
; the RAM tiles.
;
; Clobbered registers:
; r23, r24, r25, XL, XH, ZL, ZH
;
SQ_ClearSprites:

	; Clean up rows, so no sprites show

	ldi   ZL,      0
	ldi   ZH,      hi8(sq_ramt_list_ent)
	clr   r1
clrsp_loop:
	st    Z+,      r1
	cpi   ZL,      26
	brne  clrsp_loop

	; Free up RAM tiles

	sts   sq_sptile_nfr, r1

	ret



;
; void SQ_SetSpriteColMaps(uint8_t const* ptr);
;
; Set sprite color maps. Must be aligned (SQ_SECTION_TILESET for example).
; NULL restores the default color map (no remapping).
;
; r25:r24: Pointer to color maps (only r25 used)
;
SQ_SetSpriteColMaps:

	cpi   r25,     0
	brne  .+2
	ldi   r25,     hi8(sq_coltab_default)
	sts   sq_coltab_pth, r25
	ret



;
; void SQ_SetMaxSpriteTiles(uint8_t count);
;
; Sets the maximal number of RAM tiles used for sprite render. By default this
; is 85, the maximum possible number of tiles.
;
;     r24: Max. count of sprite tiles
;
SQ_SetMaxSpriteTiles:

	cpi   r24,     85
	brcs  .+2
	ldi   r24,     85
	sts   sq_sptile_max, r24
	ret



;
; void SQ_TiledPixel(uint8_t col, uint8_t xpos, uint8_t ypos, uint8_t flg);
;
; Plots a single pixel in the tiled region. Slow stuff.
;
; The flags:
; bit4: If set, mask is used (SQ_SPR_MASK)
;
;     r24: Pixel color (only low 4 bits used)
;     r22: X location
;     r20: Y location
;     r18: Flags
; Clobbered registers:
; r0, r1 (set zero), r18, r19, r20, r21, r22, r23, r24, r25, XL, XH, ZL, ZH, T
;
sq_spritepixel_nodisp:

	ret

SQ_SpritePixel:

	sbi   SR_PORT, SR_PIN  ; Deselect SPI RAM (if anything was going on)

	; Check coarse limits (max. possible displayed location is 207:207 as
	; 8:8 is the upper left corner). This is useful if no high level
	; clipping is applied on a large set of spread out sprites where a lot
	; of those may not be in the display region.

	; Adjust for 8:8 offset and check bounds

	subi  r22,     8
	cpi   r22,     200
	brcc  sq_spritepixel_nodisp
	lds   ZL,      sq_video_alines
	subi  r20,     8
	cp    r20,     ZL
	brcc  sq_spritepixel_nodisp

	; Prepare X:Y locations

	lds   ZH,      sq_video_yshift
	add   r20,     ZH      ; Y shift adjust on YPos
	mov   r23,     r20     ; Y into r23 to keep it clear from the RAM tile allocator
	mov   r19,     r23
	lsr   r19
	lsr   r19
	lsr   r19              ; Tile Y location on VRAM
	mov   r18,     r22
	lsr   r18
	lsr   r18
	lsr   r18              ; Tile X location on VRAM

	; Startup

	push  r14
	push  r15
	push  r16
	push  r17
	push  YL
	push  YH
	clr   r1               ; Make sure it is zero
	mov   r16,     r18     ; Flags into r16 for the RAM tile allocator
	andi  r16,     0xDF    ; Not a sprite (internal flag for RAM tile allocator)

	; Prepare for RAM tile allocation

	mov   XL,      r19
	lsl   XL
	lsl   XL
	subi  XL,      lo8(-(sq_tile_rows + 1))
	ldi   XH,      hi8(sq_tile_rows)
	ld    r17,     X
	andi  r17,     0x07    ; X shift
	add   r22,     r17
	andi  r23,     0x07
	andi  r22,     0x07

	; Allocate RAM tile

	rcall sq_ramtilealloc
	brtc  bpixe            ; No RAM tile

	; Plot pixel
	; From RAM tile allocation:
	; r14:r15: Mask offset (only set up if masking remined enabled)
	;     r16: Flags updated:
	;          bit4 cleared if backround's mask is zero (no masking)
	;       Y: Allocated RAM tile's data address

	sbrs  r16,     4
	rjmp  bpixnm           ; No mask: pixel will be produced
	add   r14,     r23
	adc   r15,     r1      ; Set up mask source adding Y
	movw  ZL,      r14
	lpm   r17,     Z       ; ROM mask source
	sbrc  r22,     2
	swap  r17
	bst   r22,     1
	brtc  .+4
	lsl   r17
	lsl   r17
	sbrc  r22,     0
	lsl   r17
	sbrc  r17,     7
	rjmp  bpixe            ; Pixel masked off
bpixnm:
	lsl   r23
	lsl   r23
	ldi   r19,     0xF0    ; Preserve mask on target
	andi  r24,     0x0F    ; Pixel color
	lsr   r22              ; X offset
	brcs  .+4
	swap  r19
	swap  r24              ; Align pixel in byte to high for even offsets
	add   r23,     r22
	add   YL,      r23     ; Target pixel pair offset in RAM tile
	ld    r0,      Y
	and   r0,      r19
	or    r0,      r24
	st    Y,       r0      ; Pixel completed

bpixe:

	; Done

	sbi   SR_PORT, SR_PIN  ; Deselect SPI RAM (the RAM tile allocator could have selected it)
	pop   YH
	pop   YL
	pop   r17
	pop   r16
	pop   r15
	pop   r14
	ret




;
; void SQ_BlitSprite(uint16_t xramoff, uint8_t xpos, uint8_t ypos,
;                    uint8_t flg);
;
; Blits a 8x8 sprite.
;
; xpos and ypos specifies locations by the sprite's lower right corner (so
; location 0:0 produces no sprite, 1:1 would make the lower right corner pixel
; visible).
;
; The sprite has fixed 8x8 pixel layout, 4 bytes per line, 32 bytes total,
; high nybble first for pixels. Color index 0 is transparent.
;
; Color table index zero is used, so normally this should be filled for
; straight color mapping (0, 1, 2 ... 15).
;
; The flags:
; bit0: If set, flip horizontally (SQ_SPR_FLIPX)
; bit1: Address line 16 for XRAM (SQ_SPR_HIGHBANK)
; bit2: If set, flip vertically (SQ_SPR_FLIPY)
; bit4: If set, mask is used (SQ_SPR_MASK)
;
; r25:r24: Source 8x8 sprite start address
;     r22: X location (right side)
;     r20: Y location (bottom)
;     r18: Flags
; Clobbered registers:
; r0, r1 (set zero), r18, r19, r20, r21, r22, r23, r24, r25, XL, XH, ZL, ZH, T
;
SQ_BlitSprite:
	push  r16
	clr   r16              ; Default recolor
	rjmp  sq_blitsprite_entry

;
; void SQ_BlitSpriteCol(uint16_t xramoff, uint8_t xpos, uint8_t ypos,
;                       uint8_t flg, uint8_t coltabidx);
;
; Blits a 8x8 sprite with recoloring.
;
; The coltabidx parameter selects the recolor table. 0 should produce no
; recoloring (straight mapping).
;
; r25:r24: Source 8x8 sprite start address
;     r22: X location (right side)
;     r20: Y location (bottom)
;     r18: Flags
;     r16: Recolor table index, 0: Recoloring is off (default).
; Clobbered registers:
; r0, r1 (set zero), r18, r19, r20, r21, r22, r23, r24, r25, XL, XH, ZL, ZH, T
;
sq_blitsprite_nodisp:

	pop   r16
	ret

SQ_BlitSpriteCol:

	push  r16
sq_blitsprite_entry:

	sbi   SR_PORT, SR_PIN  ; Deselect SPI RAM (if anything was going on)

	; Check coarse limits (max. possible displayed location is 207:207 as
	; 8:8 is the upper left corner). This is useful if no high level
	; clipping is applied on a large set of spread out sprites where a lot
	; of those may not be in the display region.
	;
	; Note that when 0 lines are available, sprites may still attempt to
	; blit if they are in the Y = 0 - 7 range. A minor shortcoming, but
	; shouldn't be a problem (unless user tried to reuse RAM while letting
	; the sprite engine attempting to do stuff).

	cpi   r22,     208
	brcc  sq_blitsprite_nodisp
	lds   ZL,      sq_video_alines
	subi  ZL,      0xF8    ; Adds 8
	cp    r20,     ZL
	brcc  sq_blitsprite_nodisp

	; Startup

	push  r11
	push  r4
	push  r5
	push  r6
	push  r7
	push  r8
	push  r9
	push  r14
	push  r15
	push  r17
	push  YL
	push  YH

	lds   ZH,      sq_video_yshift
	add   r20,     ZH      ; Y shift adjust on YPos
	mov   r11,     r16     ; Recolor index will stay in r11
	mov   r16,     r18     ; Flags will stay in r16
	ori   r16,     0x20    ; Sprite blitting (internal flag for RAM tile allocator)
	clr   r1               ; Make sure it is zero

	; Prepare Y location

	mov   r23,     r20     ; Y into r23
	mov   r5,      r23
	lsr   r5
	lsr   r5
	lsr   r5               ; Tile Y location on VRAM
	andi  r23,     0x07    ; Location within tile on Y
	breq  bsplle           ; Sprite is Y aligned, so no lower row

	; Prepare for lower row

	mov   XL,      r5
	cpi   XL,      26
	brcc  bsplle           ; Lower row is off the existing tile rows
	push  r22
	subi  r23,     8
	lsl   XL
	lsl   XL
	subi  XL,      lo8(-(sq_tile_rows + 1))
	ldi   XH,      hi8(sq_tile_rows)
	ld    r17,     X
	andi  r17,     0x07    ; X shift
	add   r22,     r17
	mov   r4,      r22
	lsr   r4
	lsr   r4
	lsr   r4               ; Tile X location on VRAM
	andi  r22,     0x07
	movw  r6,      r22     ; r7:r6, r23:r22, Location within tile
	breq  bsplre           ; Sprite is X aligned, so no right part

	; Generate lower right sprite part

	subi  r22,     8
	movw  r8,      XL      ; Save tile row
	rcall sq_blitspriteptprep
	movw  XL,      r8      ; Restore tile row
	movw  r22,     r6      ; r23:r22, r7:r6
bsplre:

	; Generate lower left sprite part

	dec   r4
	rcall sq_blitspriteptprep
	movw  r22,     r6      ; r23:r22, r7:r6
	subi  r23,     0xF8    ; Restore Y loc. within tile
	pop   r22
bsplle:

	; Prepare for upper row

	dec   r5
	mov   XL,      r5
	cpi   XL,      26
	brcc  bspule           ; Upper row is off the existing tile rows
	lsl   XL
	lsl   XL
	subi  XL,      lo8(-(sq_tile_rows + 1))
	ldi   XH,      hi8(sq_tile_rows)
	ld    r17,     X
	andi  r17,     0x07    ; X shift
	add   r22,     r17
	mov   r4,      r22
	lsr   r4
	lsr   r4
	lsr   r4               ; Tile X location on VRAM
	andi  r22,     0x07
	breq  bspure           ; Sprite is X aligned, so no right part

	; Generate upper right sprite part

	movw  r6,      r22     ; r7:r6, r23:r22, Location within tile
	subi  r22,     8
	movw  r8,      XL      ; Save VRAM row
	rcall sq_blitspriteptprep
	movw  XL,      r8      ; Restore VRAM row
	movw  r22,     r6      ; r23:r22, r7:r6
bspure:

	; Generate upper left sprite part

	dec   r4
	rcall sq_blitspriteptprep
bspule:

	; Done

	pop   YH
	pop   YL
	pop   r17
	pop   r15
	pop   r14
	pop   r9
	pop   r8
	pop   r7
	pop   r6
	pop   r5
	pop   r4
	pop   r11
	pop   r16
	ret



;
; Blits a sprite part including the allocation and management of RAM tiles
; for this.
;
; r25:r24: Source 8x8 sprite start address
;     r23: Y location on tile (2's complement; 0xF9 - 0x07 inclusive)
;     r22: X location on tile (2's complement; 0xF9 - 0x07 inclusive)
;     r16: Flags
;          bit0: If set, flip horizontally
;          bit1: If set, sprite source is in high bank of SPI RAM
;          bit2: If set, flip vertically
;          bit3: Free to accept original "mask is used" flag
;          bit4: If set, mask is used
;          bit5: (1) - Indicates blitting sprite for the RAM tile allocator
;          bit6-7: Reserved for Sprite importance (larger: higher)
;     r11: Color table index
;      r4: Column (X) on VRAM
;      r5: Row (Y) on VRAM
;      r1: Zero
;       X: VRAM row (at row flags)
; Return:
; Clobbered registers:
; r0, r14, r15, r17, r18, r19, r20, r21, r22, r23, XL, XH, YL, YH, ZL, ZH, T
;
bsppexit:

	ret

sq_blitspriteptprep:

	; Allocate the RAM tile and calculate necessary address data

	movw  r18,     r4      ; Column (X) & Row (Y) offsets
	cpi   r18,     26
	brcc  bsppexit         ; Out of VRAM on X

	; Nasty trick follows: Fall through onto the RAM tile allocator! Bit 5
	; of the flags indicate that a sprite will follow, so in this manner
	; it can chain to it. The goal of the trick is trimming cycles by
	; interleaving sprite set-up with the end of the ROM->RAM copy for new
	; RAM tile allocations (otherwise staying on the ordinary path).

;	rcall sq_ramtilealloc
;	brtc  bsppexit0        ; No RAM tile
;
;	; Call the sprite part blitter. It will exit properly.
;
;	rjmp  sq_blitspritept
;
;bsppexit0:
;	bst   r16,     3
;	bld   r16,     4       ; Restore mask usage flag (was only cleared, so OK)
;bsppexit1:
;	ret



;
; RAM tile allocator. This is responsible for managing the allocation of RAM
; tiles and filling them up with the proper contents from the source ROM or
; RAM tile. It also returns the necessary parameters for blitting.
;
; A small trick of starting an SPI RAM read is included on the path returning
; a valid RAM tile. This is exploited by the sprite blitter to trim some
; cycles.
;
;     r16: Flags
;          bit3: Free to accept original "mask is used" flag
;          bit4: If set, mask is used
;     r18: Column (X) on VRAM, between 0 and 25 inclusive.
;     r19: Row (Y) on VRAM, between 0 and 25 inclusive.
;      r1: Zero
;       X: VRAM row (at row flags)
; Return:
;       T: Set if sprite can render, clear if it can't
; r14:r15: Mask offset (only set up if masking remined enabled)
;     r16: Flags updated:
;          bit3 contains original r16 bit4
;          bit4 cleared if backround's mask is zero (no masking)
;       Y: Allocated RAM tile's data address
; Clobbered registers:
; r0, r17, r18, r19, r20, r21, XL, XH, ZL, ZH
;
sq_ramtilealloc:

	; Some notes on algorithm:
	;
	; The background tile index almost always have to be loaded (that is
	; even for blits on top of tiles already containing sprite parts) as
	; the mask index can only be retrieved by it. So start an SPI access
	; right away, which might be cut off at some point if it proves to be
	; unnecessary (optimizing the most common path).
	;
	; Determining whether there is a RAM tile at a given location is
	; somewhat tricky as it needs scanning the RAM tile allocation list
	; for the row. This operation also locates where the new RAM tile
	; needs to be inserted in this list.
	;
	; sq_ramt_list_ent contains the entry points for the rows, aligned
	; sq_ramt_list is the list, index 0 is reserved for end of list.
	; b0: Column to match
	; b1: RAM tile index at this column
	; b2: Next list entry address
	;
	; 0 either as an entry point or next list entry indicates end of list.

	; Start with setting up the SPI RAM for reading the bg. tile index

	cbi   SR_PORT, SR_PIN  ; Select SPI RAM
	ldi   r17,     0x03    ; Read
	out   SR_DR,   r17
	bst   r16,     4       ; Load the mask used setting into the 'T' flag,
	bld   r16,     3       ; also setting bit 3 of flags as required.
	ld    r17,     X+      ; VRAM row: configuration
	ldi   YH,      0x00
	sbrc  r17,     7       ; Address bit 16
	ldi   YH,      0x01
	ld    r17,     X+      ; VRAM row: Bg. address low
	ld    YL,      X+      ; VRAM row: Bg. address high
	add   r17,     r18
	adc   YL,      r1
	adc   YH,      r1      ; (14) Address of tile calculated (r1 is zero)

	; Check whether there are further free RAM tiles

	lds   r21,     sq_sptile_nfr
	mov   r0,      r21
	out   SR_DR,   YH      ; SPI RAM: Address high
	lsl   r0
	add   r0,      r21     ; Next free in RAM tile list address
	inc   r0               ; (Note: Index 0 is reserved for end of list marker)
	lds   ZL,      sq_sptile_max
	cp    r21,     ZL
	brcs  .+2
	clr   r0               ; 0 indicates no more free RAM tiles
	subi  r21,     0x6B
	neg   r21              ; (10) RAM tile index

	; Find the RAM tile at this row & column. Note that details are only
	; saved at this point as this may be running with cutoff by video
	; frame enabled. So first the RAM tile has to be built to prevent any
	; distruptive display artifact on an interrupted render. The detail
	; saved is simply the location & value to be written to link in the
	; new list element (the list element is prepared). r15:r14 saves the
	; address, r18 the value to write.

	ldi   ZH,      hi8(sq_ramt_list)
	ldi   YH,      hi8(sq_ramt_list)
	ldi   ZL,      0
	ldi   XL,      255     ; Prepare "too big" column value at index 0
	st    Z,       XL      ; This makes end of list chaining a lot easier.
	ldi   XH,      hi8(sq_ramt_list_ent)
	out   SR_DR,   YL      ; SPI RAM: Address mid
	mov   XL,      r19     ; Entry point for row
	ld    ZL,      X
	ld    YL,      Z       ; Column to match
	cp    YL,      r18
	brcc  rta_s0           ; ( 7 /  8) Either found or needs new entry
	ldd   YL,      Z + 2
	ld    XH,      Y       ; Column to match
	cp    XH,      r18
	brcc  rta_s1           ; (13 / 14) Either found or needs to insert before it
	ldd   ZL,      Y + 2
	ld    XH,      Z       ; Column to match
	out   SR_DR,   r17     ; SPI RAM: Address low
	cp    XH,      r18
	brcc  rta_s2           ; ( 2 /  3)
rta_sloop:
	ldd   YL,      Z + 2
	ld    XH,      Y       ; Column to match
	cp    XH,      r18
	brcc  rta_s3           ; ( 8 /  9)
	ldd   ZL,      Y + 2
	ld    XH,      Z       ; Column to match
	cp    XH,      r18
	brcs  rta_sloop
	breq  rta_sfoundz      ; Found RAM tile, ID at Z
	rjmp  rta_sinsy        ; Needs to insert new entry at YL + 2 before ZL

rta_s0:
	lpm   r20,     Z       ; (11)
	lpm   r20,     Z       ; (14)
	lpm   r20,     Z       ; (17)
	out   SR_DR,   r17     ; SPI RAM: Address low
	lpm   r20,     Z       ; ( 3)
	lpm   r20,     Z       ; ( 6)
	nop                    ; ( 7)
	breq  rta_sfoundz      ; ( 8 /  9) Found RAM tile, ID at Z
	rjmp  rta_sinsf        ; (10) Needs to insert new entry on front before ZL
rta_s1:
	lpm   r20,     Z       ; (17)
	out   SR_DR,   r17     ; SPI RAM: Address low
	lpm   r20,     Z       ; ( 3)
	lpm   r20,     Z       ; ( 6)
	brne  rta_sinsz        ; ( 7 /  8) Needs to insert new entry at ZL + 2 before YL
	rjmp  rta_sfoundy      ; ( 9) Found RAM tile, ID at Y
rta_s2:
	lpm   r20,     Z       ; ( 6)
	nop                    ; ( 7)
	breq  rta_sfoundz      ; ( 8 /  9) Found RAM tile, ID at Z
	rjmp  rta_sinsy        ; (10) Needs to insert new entry at YL + 2 before ZL
rta_s3:
	breq  rta_sfoundy      ; Found RAM tile, ID at Y
;	rjmp  rta_sinsz        ; Needs to insert new entry at ZL + 2 before YL

rta_sinsz:
	cp    r0,      r1      ; ( 9) No free RAM tiles (r1 is zero)
	breq  rta_drop
	ldi   XH,      hi8(sq_ramt_list)
	mov   XL,      r0
	st    X+,      r18     ; (14) Column (current)
	st    X+,      r21     ; (16) RAM tile index as prepared
	subi  ZL,      0xFE
	out   SR_DR,   r17     ; SPI RAM: Dummy to clock in the data byte
	st    X,       YL      ; ( 2) Next element: Chain
	movw  r14,     ZL
	rjmp  rta_scomm        ; ( 5)

rta_sinsf:
	cp    r0,      r1      ; (11) No free RAM tiles (r1 is zero)
	breq  rta_drop
	mov   YL,      r0
	st    Y+,      r18     ; (15) Column (current)
	st    Y+,      r21     ; (17) RAM tile index as prepared
	out   SR_DR,   r17     ; SPI RAM: Dummy to clock in the data byte
	st    Y,       ZL      ; ( 2) Next element: Chain
	movw  r14,     XL
	rjmp  rta_scomm        ; ( 5)

rta_sfoundz:
	ldd   r21,     Z + 1   ; (11) RAM tile address to use
	rjmp  rta_scommw       ; (13)

rta_sfoundy:
	ldd   r21,     Y + 1   ; (11) RAM tile address to use
	rjmp  rta_scommw       ; (13)

rta_scommw:
	set                    ; T: Using already allocated RAM tile
	lpm   r20,     Z
	out   SR_DR,   r17     ; SPI RAM: Dummy to clock in the data byte
	lpm   r20,     Z
	rjmp  .
	rjmp  rta_scommf       ; ( 7)

rta_drop:
	lpm   r20,     Z
	lpm   r20,     Z       ; Make sure transaction finishes
	sbi   SR_PORT, SR_PIN  ; Deselect SPI RAM
rta_drop_ns:
	clt                    ; Sprite tile can not be rendered
	ret

rta_sinsy:
	cp    r0,      r1      ; (11) No free RAM tiles (r1 is zero)
	breq  rta_drop
	ldi   XH,      hi8(sq_ramt_list)
	mov   XL,      r0
	st    X+,      r18     ; (16) Column (current)
	subi  YL,      0xFE
	out   SR_DR,   r17     ; SPI RAM: Dummy to clock in the data byte
	st    X+,      r21     ; ( 2) RAM tile index as prepared
	st    X,       ZL      ; ( 4) Next element: Chain
	movw  r14,     YL      ; ( 5)

rta_scomm:
	mov   r18,     r0
	clt                    ; ( 7) T: Indicate new RAM tile (r21: Index)
rta_scommf:

	; RAM tile to use is ready. Allocation is not finalized, so it may
	; still be discarded (by simply returning, no destructive change
	; happened so far). Allocation can be finalized by incrementing
	; sp_stile_nfr and then chaining in the prepared tile.
	; Registers:
	; r16: Flags
	;      bit3: Original "mask is used" flag
	;      bit4: If set, mask is used (same as original so far)
	;  r1: Zero
	; r21: RAM tile index to use
	;   T: Set when already allocated RAM tile is used, clear otherwise
	; r15:r14: Saved chain-in address (if T clear, new RAM tile)
	; r18: Saved chain-in value (if T clear, new RAM tile)

	; Calculate RAM tile address

	ldi   XL,      32
	mul   r21,     XL
	movw  YL,      r0
	clr   r1

	; Preload mask set & data pointers

	lds   ZH,      sq_maskset_pth
	lds   r20,     sq_maskdat_pth

	; Now to get anywhere further, the ROM tile index is needed.

	in    r17,     SR_DR   ; Finally, the ROM tile index
	sbi   SR_PORT, SR_PIN  ; Deselect SPI RAM

	; Check background mask if necessary

	sbrs  r16,     4       ; Mask used?
	rjmp  rta_mno0
	mov   ZL,      r17
	ld    r19,     Z       ; Mask index for ROM tile
	cpi   r19,     0xFE
	brcs  rta_mno0         ; No mask (0xFE) or Full mask (0xFF)
	brne  rta_drop_ns      ; 0xFF: Full mask: Tile dropped
	andi  r16,     0xEF    ; Clear bit 4 of flags (no mask)
rta_mno0:

	; Start an SPI RAM read for later sprite blitter operation

	cbi   SR_PORT, SR_PIN  ; Select SPI RAM
	ldi   ZH,      0x03    ; Read from SPI RAM
	out   SR_DR,   ZH      ; Send command

	; If it is a new RAM tile, then fill it up with ROM tile data, and
	; finally chain it in (as a nasty display artifact is now eliminated
	; by filling it up).

	brtc  rta_newtile
rta_retcomm:

	; Calculate mask data address (r19 still has the mask index, and r20
	; the mask data pointer high)

	sbrs  r16,     4       ; Mask used?
	rjmp  rta_mno1
	ldi   XL,      8
	mul   r19,     XL
	movw  r14,     r0
	clr   r1
	add   r15,     r20
rta_mno1:

	; All calculated OK, tile is allocated proper.

	set                    ; T set for Allocated
	sbrs  r16,     5       ; Still here for sprite blitting?
	ret                    ; (10) Relative to SPI RAM read start (Normal ret)
	lpm   ZL,      Z       ; (10) Sprite blitting
	rjmp  sq_blitspritept  ; (12)

rta_newtile:

	; Calculate source ROM tile address

	lds   ZH,      sq_tileset_pth
	mul   r17,     XL      ; XL is still 32
	mov   ZL,      r0
	add   ZH,      r1
	clr   r1

	; Copy ROM tile data

	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+

	sbrc  r16,     5       ; Still here for sprite blitting?
	rjmp  rta_shortcut     ; If so, enter shortcut path into blitter

	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0

	; Rewind RAM tile pointer for return

	sbiw  YL,      32

	; Fix allocation & chain tile in

	lds   r0,      sq_sptile_nfr
	inc   r0
	sts   sq_sptile_nfr, r0
	movw  XL,      r14
	st    X,       r18

	rjmp  rta_retcomm



;
; This is an unstructured optimization hack: The RAM tile allocator, if it is
; a new sprite, branches off from the ROM -> RAM copy to start preloading
; sprite data, then it jumps into the sprite blitter, thus eliminating idle
; waits for SPI data.
;
; The structure of the functions are mostly preserved, removing the branchoff
; point the code would still work (just slower).
;

rta_shortcut:

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

	movw  XL,      r14     ; (17) Preload for finalizing allocation

	out   SR_DR,   r7      ; SPI: Address mid

	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0

	out   SR_DR,   r6      ; SPI: Address low

	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	lpm   r0,      Z+
	st    Y+,      r0
	sbiw  YL,      32      ; Rewind RAM tile pointer for return

	out   SR_DR,   r6      ; SPI: Dummy byte to begin data fetches

	; Fix allocation & chain tile in

	lds   r0,      sq_sptile_nfr
	inc   r0
	sts   sq_sptile_nfr, r0
	st    X,       r18

	; Calculate mask data address (r19 still has the mask index, and r20
	; the mask data pointer high)

	sbrs  r16,     4       ; Mask used?
	rjmp  sq_blitspritept_short ; (10)
	ldi   XL,      8
	mul   r19,     XL
	movw  r14,     r0
	clr   r1
	add   r15,     r20
	rjmp  sq_blitspritept_short



;
; Add the blitter, to the same section
;
#include "sq_spblitter.s"
