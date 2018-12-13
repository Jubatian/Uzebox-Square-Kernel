/*
 *  Uzebox Square Kernel - Audio mid-level driver
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



.section .sq_tiny_text1


;
; Process a channel's 60Hz tasks, updating the interrupt side of the audio
; engine. Needs r0, r1, r22 - r25, X, Y, Z and SREG available. Only does the
; parts common to all 3 channels. Doesn't clear the reset position flag (so
; ch3 can still use it for resetting AM position).
;
; Y: Source channel structure (preserved)
; Z: Destination channel structure (preserved)
;
; Returns volume in r1 which should go in chx_curvol. XH contains the flags on
; return. 133 cycles (rcall)
;
sq_proc_channel_60:

	; Waveform (4 cy)

	ldd   r0,      Y + chs_wave
	std   Z + 2,   r0      ; IT side, chx_wave

	; Note to step value (48 cy)

	movw  r22,     ZL
	ldd   ZL,      Y + chs_note
	andi  ZL,      0x7F
	mov   r25,     ZL
	ldi   ZH,      0
	lsl   ZL
	rol   ZH               ; ( 8)
	subi  ZL,      lo8(-(sq_steptb))
	sbci  ZH,      hi8(-(sq_steptb))
	lpm   XL,      Z+
	lpm   XH,      Z+
	lpm   r0,      Z+
	lpm   r1,      Z+      ; (22)
	movw  ZL,      r0
	ldd   r24,     Y + chs_note_frac
	mul   ZL,      r24
	mov   ZL,      r1
	mul   ZH,      r24
	add   r0,      ZL
	movw  ZL,      r0
	neg   r24
	brne  .+8              ; (35 - branch)
	rjmp  .
	rjmp  .
	movw  r0,      XL
	rjmp  .+8              ; (41)
	mul   XL,      r24
	mov   XL,      r1
	mul   XH,      r24
	add   r0,      XL      ; (41)
	add   r0,      ZL
	adc   r1,      ZH
	movw  ZL,      r22
	std   Z + 4,   r0      ; (46) IT side, chx_step
	std   Z + 5,   r1

	; Frequency sweep (20 cy)

	ldd   r24,     Y + chs_note_frac
	ldd   XL,      Y + chs_note_adjf
	ldd   XH,      Y + chs_note_adj
	add   r24,     XL
	adc   r25,     XH
	sbrc  XH,      7
	rjmp  .+10
	brcc  .+2
	ldi   r24,     255
	brcc  .+2
	ldi   r25,     127     ; Increment, saturate at note max.
	rjmp  .+10
	brcs  .+2
	ldi   r24,     0
	brcs  .+2
	ldi   r25,     0       ; Decrement, saturate at note min.
	nop
	std   Y + chs_note_frac, r24
	std   Y + chs_note, r25

	; Envelope volume ramp (14 cy)

	ldd   r24,     Y + chs_evol
	ldd   r25,     Y + chs_evol_adj
	mov   XL,      r24
	add   r24,     r25
	sbrc  r25,     7
	rjmp  .+6
	brcc  .+2
	ldi   r24,     255     ; Increment, saturate at unsigned max.
	rjmp  .+6
	brcs  .+2
	ldi   r24,     0       ; Decrement, saturate at unsigned min.
	nop
	std   Y + chs_evol, r24

	; Tremolo (unless AM) (24 cy)

	ldd   XH,      Y + chs_flags
	sbrs  XH,      3
	rjmp  .+16             ; Tremolo enabled (not AM)
	mov   r1,      XL
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	nop
	rjmp  .+20
	ldd   r24,     Y + chs_tr_level
	ldd   r25,     Y + chs_tr_rate
	ldd   ZL,      Y + chs_tr_pos
	ldi   ZH,      hi8(sq_sinewave)
	lpm   r0,      Z
	add   ZL,      r25
	std   Y + chs_tr_pos, ZL
	mul   r0,      r24
	com   r1
	mul   r1,      XL
	movw  ZL,      r22

	; Combine volumes (8 cy)

	ldd   r24,     Y + chs_nvol
	mul   r1,      r24
	ldd   r24,     Y + chs_cvol
	mul   r1,      r24

	; Reset position if requested so (8 cy)

	sbrc  XH,      4
	rjmp  .+6              ; Reset position request
	rjmp  .
	rjmp  .
	rjmp  .+6
	ldi   r24,     0
	std   Z + 0,   r24
	std   Z + 1,   r24

	ret



.section .sq_video_core


;
; Process all 3 channels' 60Hz tasks, updating the interrupt side of the audio
; engine. Needs r0, r1, r22 - r25, X, Y, Z and SREG available.
;
; 527 cycles with rcall.
;
sq_proc_audio_60:

	; Process common tasks (429 = 30 + 3 * 133 cycles)

	ldi   YL,      lo8(sq_ch0_struct)
	ldi   YH,      hi8(sq_ch0_struct)
	ldi   ZL,      lo8(ch0_pos)
	ldi   ZH,      hi8(ch0_pos)
	rcall sq_proc_channel_60
	mov   r24,     r1
	cpi   r24,     128
	brcs  .+2
	ldi   r24,     128     ; Ch0 volume max. is 128
	std   Z + 3,   r24     ; Obtained volume into ch0_curvol
	andi  XH,      0xEF    ; Clear reset position flag
	std   Y + chs_flags, XH
	adiw  ZL,      6
	adiw  YL,      16
	rcall sq_proc_channel_60
	mov   r24,     r1
	cpi   r24,     128
	brcs  .+2
	ldi   r24,     128     ; Ch1 volume max. is 128
	std   Z + 3,   r24     ; Obtained volume into ch1_curvol
	andi  XH,      0xEF    ; Clear reset position flag
	std   Y + chs_flags, XH
	adiw  ZL,      6
	adiw  YL,      16
	rcall sq_proc_channel_60

	; Process Channel 2 specifics (19 cy)

	ldd   r24,     Z + 3   ; ch2_curvol
	std   Z + 12,  r24     ; ch2_prvvol
	std   Z + 3,   r1      ; Obtained volume into ch1_curvol
	sbrc  XH,      4
	rjmp  .+6              ; Reset position request
	lpm   r24,     Z
	lpm   r24,     Z
	rjmp  .+8
	ldi   r24,     0
	std   Z + 6,   r24     ; Also reset AM position
	std   Z + 7,   r24
	std   Z + 9,   r24     ; Clear AM strength, too
	andi  XH,      0xEF    ; Clear reset position flag
	std   Y + chs_flags, XH

	; Process Channel 2 AM (69 cy)

	sbrc  XH,      3
	rjmp  0f               ; AM enabled (not Tremolo). If Tremolo is enabled, keep AM as-is
	ldi   r24,     21
	dec   r24
	brne  .-4
	rjmp  .
	rjmp  1f
0:

	; Note to step value ((58 cy))

	movw  r22,     ZL
	ldd   ZH,      Y + chs_am_note
	sbrs  XH,      2
	rjmp  .+12             ; ( 6) AM note depends on Note
	mov   ZL,      ZH
	andi  ZL,      0x7F
	lpm   r24,     Z
	lpm   r24,     Z
	ldi   r24,     0
	rjmp  .+16             ; (16)
	ldd   ZL,      Y + chs_note
	ldd   r24,     Y + chs_note_frac
	andi  ZH,      0x7F
	add   ZL,      ZL
	brvc  .+2
	ldi   ZL,      127     ; (14) Positive overflow - saturate
	brpl  .+2
	ldi   ZL,      0       ; (16) Negative - saturate to 0
	mov   r25,     ZL
	ldi   ZH,      0
	lsl   ZL
	rol   ZH
	subi  ZL,      lo8(-(sq_steptb))
	sbci  ZH,      hi8(-(sq_steptb))
	lpm   XL,      Z+      ; (25)
	lpm   XH,      Z+
	lpm   r0,      Z+
	lpm   r1,      Z+      ; (34)
	movw  ZL,      r0
	mul   ZL,      r24
	mov   ZL,      r1
	mul   ZH,      r24     ; (40)
	add   r0,      ZL
	movw  ZL,      r0
	neg   r24
	brne  .+8
	rjmp  .
	rjmp  .
	movw  r0,      XL
	rjmp  .+8              ; (51)
	mul   XL,      r24
	mov   XL,      r1
	mul   XH,      r24
	add   r0,      XL      ; (51)
	add   r0,      ZL
	adc   r1,      ZH
	movw  ZL,      r22
	std   Z + 10,  r0      ; IT side, chx_amstep
	std   Z + 11,  r1

	; Apply AM level and waveform ((8 cy))

	ldd   r1,      Y + chs_am_level
	std   Z + 9,   r1
	ldd   r1,      Y + chs_am_wave
	std   Z + 8,   r1
1:

	; Reset volume ramp for new frame (3 cy)

	ldi   r24,     0
	sts   sq_mix_vramp, r24

	ret
