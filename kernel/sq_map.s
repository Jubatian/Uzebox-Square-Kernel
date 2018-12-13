;
; Uzebox Square Kernel - High level maps
; Copyright (C) 2018 Sandor Zsuga (Jubatian)
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
; Provides high-level map abstraction which can be used to easily manage an
; XRAM based map, and blit sprites over it, automatically performing the
; transition between map and screen coordinates. So it is possible to simply
; blit sprites onto the map's coordinate space, and this will manage them.
;


.section .text.SQ_Map


;
; void SQ_MAP_Init(uint8_t xrambank, uint16_t xramoff, uint16_t width, uint16_t height);
;
; Initializes a map. Doesn't have effect on the output (use SQ_MAP_MoveTo()).
; The map dimensions should be at least 25x25 (one screen), height might be
; less when using narrower tiled display.
;
;     r24: XRAM bank of the map
; r23:r22: XRAM offset of the map
; r21:r20: Width of map in tiles
; r19:r18: Height of map in tiles
;
.global SQ_MAP_Init
SQ_MAP_Init:

	sts   sq_map_bank, r24
	sts   sq_map_ptr + 0, r22
	sts   sq_map_ptr + 1, r23
	sts   sq_map_width + 0, r20
	sts   sq_map_width + 1, r21
	sts   sq_map_height + 0, r18
	sts   sq_map_height + 1, r19
	ret



;
; void SQ_MAP_MoveTo(int16_t xpos, int16_t ypos);
;
; Moves to the given location on the map, setting up the display for this.
; It also clears the sprite engine, so you can start blitting sprites right
; away.
;
; The positions are clipped to map edges so only actual map area is displayed
; (Y is clipped according to the current Y split).
;
; r25:r24: X position
; r23:r22: Y position
;
.global SQ_MAP_MoveTo
SQ_MAP_MoveTo:

	; Clip position to display edges

	lds   XL,      sq_map_width + 0
	lds   XH,      sq_map_width + 1

	sbrc  r25,     7
	rjmp  0f
	movw  r18,     XL      ; X will keep it for SetTileBGOff
	lsl   r18
	rol   r19
	lsl   r18
	rol   r19
	lsl   r18
	rol   r19              ; Width in pixel units
	subi  r18,     lo8(200)
	sbci  r19,     hi8(200)
	cp    r24,     r18
	cpc   r25,     r19
	brcs  .+2
	movw  r24,     r18     ; Clip to right edge
0:

	sbrc  r23,     7
	rjmp  0f
	lds   r18,     sq_map_height + 0
	lds   r19,     sq_map_height + 1
	lsl   r18
	rol   r19
	lsl   r18
	rol   r19
	lsl   r18
	rol   r19              ; Width in pixel units
	lds   ZL,      sq_video_alines
	sub   r18,     ZL
	sbci  r19,     0
	cp    r22,     r18
	cpc   r23,     r19
	brcs  .+2
	movw  r22,     r18     ; Clip to bottom edge
0:

	sbrc  r25,     7       ; X position negative?
	ldi   r24,     0
	sbrc  r25,     7       ; X position negative?
	ldi   r25,     0       ; Clip to zero
	sbrc  r23,     7       ; Y position negative?
	ldi   r22,     0
	sbrc  r23,     7       ; Y position negative?
	ldi   r23,     0       ; Clip to zero

	; Save it

	sts   sq_map_xpos + 0, r24
	sts   sq_map_xpos + 1, r25
	sts   sq_map_ypos + 0, r22
	sts   sq_map_ypos + 1, r23

	; Set background to this position

	movw  r18,     r22     ; ypos
	movw  r20,     r24     ; xpos
	movw  r22,     XL      ; width
	push  r16
	lds   r24,     sq_map_ptr + 0
	lds   r25,     sq_map_ptr + 1
	lds   r16,     sq_map_bank
	call  SQ_SetTileBGOff
	pop   r16

	; Clear sprite engine

	jmp   SQ_ClearSprites



;
; void SQ_MAP_BlitSprite(uint16_t xramoff, int16_t xpos, int16_t ypos, uint8_t flags);
;
; Blit sprite by map coordinates, upper-left corner. See SQ_BlitSprite().
;
.global SQ_MAP_BlitSprite
SQ_MAP_BlitSprite:

	ldi   ZL,      lo8(pm(SQ_BlitSprite))
	ldi   ZH,      hi8(pm(SQ_BlitSprite))
	rjmp  sq_map_blitcomm



;
; void SQ_MAP_BlitSpriteCol(uint16_t xramoff, int16_t xpos, int16_t ypos, uint8_t flags);
;
; Blit sprite by map coordinates, upper-left corner. See SQ_BlitSpriteCol().
;
.global SQ_MAP_BlitSpriteCol
SQ_MAP_BlitSpriteCol:

	ldi   ZL,      lo8(pm(SQ_BlitSpriteCol))
	ldi   ZH,      hi8(pm(SQ_BlitSpriteCol))
sq_map_blitcomm:
	lds   XL,      sq_map_xpos + 0
	lds   XH,      sq_map_xpos + 1
	sub   r22,     XL
	sbc   r23,     XH
	subi  r22,     lo8(-(8))
	sbci  r23,     hi8(-(8))
	cpi   r23,     0
	brne  sq_map_commret   ; Not on display area
	lds   XL,      sq_map_ypos + 0
	lds   XH,      sq_map_ypos + 1
	sub   r20,     XL
	sbc   r21,     XH
	subi  r20,     lo8(-(8))
	sbci  r21,     hi8(-(8))
	cpi   r21,     0
	brne  sq_map_commret   ; Not on display area
	ijmp
sq_map_commret:
	ret



;
; void SQ_MAP_SpritePixel(uint8_t col, int16_t xpos, int16_t ypos, uint8_t flags);
;
; Places pixel by map coordinates. See SQ_SpritePixel().
;
.global SQ_MAP_SpritePixel
SQ_MAP_SpritePixel:

	ldi   ZL,      lo8(pm(SQ_SpritePixel))
	ldi   ZH,      hi8(pm(SQ_SpritePixel))
	rjmp  sq_map_blitcomm
