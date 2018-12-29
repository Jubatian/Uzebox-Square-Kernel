/*
 *  Uzebox Square Kernel - Audio patch processor
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
; This file is meant to be included by sq_auvid.s
;

;
; Processes patches using the Mixer structures (see kernel.s, Mixer structure
; fields).
;
; Patch commands take 3 bytes each, describing the envelope and other
; properties of the instrument to play. They are mostly parallell to the
; original Uzebox kernel's spacifications with some extensions for driving AM
; on Channel 2 and logarithmic frequency slides.
;
; byte 0: Delta in 60Hz ticks to previous patch. 0: No delta.
; byte 1: Patch command.
; byte 2: Patch parameter.
;
; The patches are in a patch set pointed by sq_patchset_ptr. Up to 255
; individual patch commands may exist within the set.
;
; Patch commands:
;
; Same as Original Uzebox kernel:
;
; 0x00: Adjust envelope volume per tick by param, 2's complement, -128/+127
; 0x01: (Unused, Noise channel in Original Uzebox kernel)
; 0x02: Set waveform to param. 0 is a sine wave, rest in: SQ_SECTION_WAVESET
; 0x03: Note up, increases Note by param
; 0x04: Note down, decrease Note by param
; 0x05: End of note. Sets Env. volume to 0 and halts patch advancement
; 0x06: Note hold. Halts patch advancement until Note Off is received
; 0x07: Set envelope volume to param
; 0x08: Set note. Cancels a frequency slide if one was in progress
; 0x09: Set tremolo level to param
; 0x0A: Set tremolo rate to param
; 0x0B: (Unused, Linear pitch slide in Original Uzebox kernel)
; 0x0C: (Unused, Linear pitch slide in Original Uzebox kernel)
; 0x0D: Loop start, loop count times (up to 15)
; 0x0E: Loop end
;
; New commands:
;
; 0x20: Release. Parameter is an adjust to envelope volume, halts patch adv.
; 0x21: Set pitch slide fraction (1/256th note / tick)
; 0x22: Set pitch slide whole, 2's complement, -128/+127, in Notes
; 0x23: Set coarse pitch slide, 2's complement 1.7 (1/128th note / tick)
; 0x24: Set AM level (Ch2 only)
; 0x25: Set AM waveform
; 0x26: Set AM note, 2's complement relative to Note by default
; 0x27: Set AM params. Param Bit 0 is used, 1: AM note is independent
; 0x28: Unconditional relative jump to 2's complement param
;
; Notes for loops and jumps:
;
; The Loop end command requests a backwards search for a Loop start after
; checking & decrementing the loop count. It scans back up to 16 commands or
; to the patch base index or to the beginning of the patch set (if current
; patch index where it is found is before the patch base index for this
; channel due to an earlier jump).
;
; The loop can not backtrack through an earlier jump.
;
; Command 0x05 is essentially a 0x07 (set envelope volume) to 0 combined with
; an unconditional jump to itself.
;
; Command 0x20 is essentially a 0x00 (adjust env. volume) to param combined
; with an unconditional jump to itself.
;
; Channel 2 by default is in Tremolo mode. Setting AM parameters cancel any
; Tremolo on it favoring AM. However it is possible to apply Tremolo on it
; after setting up AM (at least one tick later).
;
; Channel 2 has smooth (3KHz) volume sweeps, so for instruments relying on
; fine sweeps should be played on it if possible.
;
; Patches are always processed at the end of VBlank (not at the point of
; calling the related functions) ensuring a consistent audio experience.
;



.section .text



;
; Process patches for the 3 channels
;
sq_patch_proc:

	ldi   YL,      lo8(sq_ch0_struct)
	ldi   YH,      hi8(sq_ch0_struct)
	lds   r0,      sq_patchset_ptr + 0
	lds   r1,      sq_patchset_ptr + 1
	rcall sq_patch_ch_proc
	adiw  YL,      16
	rcall sq_patch_ch_proc
	adiw  YL,      16
	rjmp  sq_patch_ch_proc



;
; Process current patches for a channel. Note that all channels are identical,
; it is just Ch2 which acts differently on certain patches (supporting AM).
;
; Inputs:
;  YH: YL: Channel structure
;  r0: r1: Patch set pointer
; Clobbers:
; r22, r23, r24, r25, ZL, ZH, T
;
sq_patch_ch_proc:

	; Check whether it is time to process a patch

	ldd   r22,     Y + chs_prem_tim
	subi  r22,     1
	brcc  0f
	std   Y + chs_prem_tim, r22
	ret                    ; Not yet
0:

	; Load patch index

	ldd   r24,     Y + chs_pcur_idx
	cpi   r24,     0xFF
	brne  0f
	ret                    ; No patch to process, do nothing
0:
	ldi   r25,     0

	; Patch process loop

	clt                    ; Ignore first delta (already waited for it)
0:
	movw  ZL,      r0
	add   ZL,      r24
	adc   ZH,      r25
	add   ZL,      r24
	adc   ZH,      r25
	add   ZL,      r24
	adc   ZH,      r25     ; Patch data pointer

	lpm   r22,     Z+      ; Delta
	brtc  1f               ; Ignore?
	cpi   r22,     0
	breq  1f               ; No delta, go on
	dec   r22
	std   Y + chs_prem_tim, r22
	rjmp  2f
1:
	set                    ; Delta will no longer be ignored

	lpm   r22,     Z+      ; Command
	lpm   r23,     Z       ; Data
	mov   ZL,      r22
	ldi   ZH,      0
	cpi   ZL,      0x2F
	brcs  .+2
	ldi   ZL,      0x2F
	subi  ZL,      lo8(-(pm(sq_patch_ch_proc_tb)))
	sbci  ZH,      hi8(-(pm(sq_patch_ch_proc_tb)))
	ijmp

sq_patch_ch_proc_tb:

	rjmp  pt00
	rjmp  pt01
	rjmp  pt02
	rjmp  pt03
	rjmp  pt04
	rjmp  pt05
	rjmp  pt06
	rjmp  pt07
	rjmp  pt08
	rjmp  pt09
	rjmp  pt0a
	rjmp  pt0b
	rjmp  pt0c
	rjmp  pt0d
	rjmp  pt0e
	rjmp  pt0f
	rjmp  pt10
	rjmp  pt11
	rjmp  pt12
	rjmp  pt13
	rjmp  pt14
	rjmp  pt15
	rjmp  pt16
	rjmp  pt17
	rjmp  pt18
	rjmp  pt19
	rjmp  pt1a
	rjmp  pt1b
	rjmp  pt1c
	rjmp  pt1d
	rjmp  pt1e
	rjmp  pt1f
	rjmp  pt20
	rjmp  pt21
	rjmp  pt22
	rjmp  pt23
	rjmp  pt24
	rjmp  pt25
	rjmp  pt26
	rjmp  pt27
	rjmp  pt28
	rjmp  pt29
	rjmp  pt2a
	rjmp  pt2b
	rjmp  pt2c
	rjmp  pt2d
	rjmp  pt2e
	rjmp  pt2f

pt00:
	; 0x00:
	; Adjust envelope volume per tick by param, 2's complement, -128/+127

	std   Y + chs_evol_adj, r23
	rjmp  3f

pt02:
	; 0x02:
	; Set waveform to param. 0 is a sine wave, rest in: SQ_SECTION_WAVESET

	subi  r23,     hi8(-(sq_waveset))
	std   Y + chs_wave, r23
	rjmp  3f

pt03:
	; 0x03:
	; Note up, increases Note by param

	ldd   r22,     Y + chs_note
	add   r22,     r23
	brpl  .+2
	ldi   r22,     127
	std   Y + chs_note, r22
	rjmp  3f

pt04:
	; 0x04:
	; Note down, decrease Note by param

	ldd   r22,     Y + chs_note
	sub   r22,     r23
	brpl  .+2
	ldi   r22,     0
	std   Y + chs_note, r22
	rjmp  3f

pt05:
	; 0x05:
	; End of note. Sets Env. volume to 0 and halts patch advancement

	std   Y + chs_evol, r25
	rjmp  2f

pt06:
	; 0x06:
	; Note hold. Halts patch advancement until Note Off is received

	ldd   r22,     Y + chs_flags
	sbrs  r22,     0
	rjmp  3f               ; Note OFF, go on with Release
	rjmp  2f               ; Still Note ON, halt here

pt07:
	; 0x07:
	; Set envelope volume to param

	std   Y + chs_evol, r23
	rjmp  3f

pt08:
	; 0x08:
	; Set note. Cancels a frequency slide if one was in progress

	std   Y + chs_note, r23
	std   Y + chs_note_frac, r25
	std   Y + chs_note_adjf, r25
	std   Y + chs_note_adj,  r25
	rjmp  3f

pt09:
	; 0x09:
	; Set tremolo level to param

	ldd   r22,     Y + chs_flags
	andi  r22,     0xF7    ; In Tremolo mode
	std   Y + chs_flags, r22
	std   Y + chs_tr_level, r23
	rjmp  3f

pt0a:
	; 0x0A:
	; Set tremolo rate to param

	ldd   r22,     Y + chs_flags
	andi  r22,     0xF7    ; In Tremolo mode
	std   Y + chs_flags, r22
	std   Y + chs_tr_rate, r23
	rjmp  3f

pt0d:
	; 0x0D:
	; Loop start, loop count times (up to 15)

	ldd   r22,     Y + chs_flags
	andi  r22,     0x0F
	andi  r23,     0x0F
	swap  r23
	or    r22,     r23
	std   Y + chs_flags, r22
	rjmp  3f

pt0e:
	; 0x0E:
	; Loop end

	ldd   r22,     Y + chs_flags
	subi  r22,     0x10
	brcc  .+2
	rjmp  3f               ; No looping
	std   Y + chs_flags, r22
	ldd   r22,     Y + chs_pbase_idx
	movw  ZL,      r0
	add   ZL,      r24
	adc   ZH,      r25
	add   ZL,      r24
	adc   ZH,      r25
	add   ZL,      r24
	adc   ZH,      r25     ; Patch data pointer
	adiw  ZL,      1       ; Position at commands so Loop start will be seen
	cpi   r24,     0
	brne  6f
	rjmp  4f               ; Process patch where it landed (beginning)
9:
	sbiw  ZL,      3
	lpm   r23,     Z
	cpi   r23,     0x0D
	breq  7f               ; At loop start
6:
	cp    r24,     r22
	breq  8f               ; At the beginning of the patch set for this ch.
	dec   r24
	brne  9b               ; At the beginning of the patch set
8:
	rjmp  4f               ; Process patch where it landed (beginning)
7:
	rjmp  3f               ; Advance from Loop start patch is necessary

pt20:
	; 0x20:
	; Release. Parameter is an adjust to envelope volume, halts patch adv.

	std   Y + chs_evol_adj, r23
	rjmp  2f

pt21:
	; 0x21:
	; Set pitch slide fraction (1/256th note / tick)

	std   Y + chs_note_adjf, r23
	rjmp  3f

pt22:
	; 0x22:
	; Set pitch slide whole, 2's complement, -128/+127, in Notes

	std   Y + chs_note_adj, r23
	rjmp  3f

pt23:
	; 0x23:
	; Set coarse pitch slide, 2's complement 1.7 (1/128th note / tick)

	lsl   r23
	ldi   r22,     0
	brcc  .+2
	ldi   r22,     0xFF
	std   Y + chs_note_adjf, r23
	std   Y + chs_note_adj, r22
	rjmp  3f

pt24:
	; 0x24:
	; Set AM level (Ch2 only)

	ldd   r22,     Y + chs_flags
	ori   r22,     0x08    ; In AM mode
	std   Y + chs_flags, r22
	std   Y + chs_am_level, r23
	rjmp  3f

pt25:
	; 0x25:
	; Set AM waveform

	ldd   r22,     Y + chs_flags
	ori   r22,     0x08    ; In AM mode
	std   Y + chs_flags, r22
	subi  r23,     hi8(-(sq_waveset))
	std   Y + chs_am_wave, r23
	rjmp  3f

pt26:
	; 0x26:
	; Set AM note, 2's complement relative to Note by default

	ldd   r22,     Y + chs_flags
	ori   r22,     0x08    ; In AM mode
	std   Y + chs_flags, r22
	std   Y + chs_am_note, r23
	rjmp  3f

pt27:
	; 0x27:
	; Set AM params. Param Bit 0 is used, 1: AM note is independent

	ldd   r22,     Y + chs_flags
	ori   r22,     0x0C    ; In AM mode & AM note independent
	sbrs  r23,     0
	andi  r22,     0xFB    ; AM note is relative to Note
	std   Y + chs_flags, r22
	rjmp  3f

pt28:
	; 0x28:
	; Unconditional relative jump to 2's complement param

	add   r24,     r23
	rjmp  3f

pt01:
pt0b:
pt0c:
pt0f:
pt10:
pt11:
pt12:
pt13:
pt14:
pt15:
pt16:
pt17:
pt18:
pt19:
pt1a:
pt1b:
pt1c:
pt1d:
pt1e:
pt1f:
pt29:
pt2a:
pt2b:
pt2c:
pt2d:
pt2e:
pt2f:

3:
	inc   r24              ; Next patch
4:
	rjmp  0b               ; Next iteration

	; Done, store patch index to process next time and return (delta
	; aleady set up if it had to be set up).

2:
	std   Y + chs_pcur_idx, r24
	ret
