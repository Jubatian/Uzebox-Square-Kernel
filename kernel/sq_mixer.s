/*
 *  Uzebox Square Kernel - Audio mixer
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
; This is the audio mixer, called within the audio-video processing interrupt.
; Most of the mixing is done in 5 sample blocks, generating the HSync pulse,
; however 2 extra samples have to be provided at some point to make up the 262
; samples.
;
; Channels:
;
; Channel 0 and 1:
;
; These are simple wave channels using a 256 byte ROM waveform, their volume
; may range from 0 - 128.
;
; Channel 2:
;
; This channel has smooth volume ramping and Amplitude Modulation in addition
; to Ch. 0 and 1's features, and its volume can range from 0 - 255.
;

;
; sq_mix_5sample
; sq_mix_2sample
;
; Mixer routines. They clobber r0, r1, ZL and ZH.
;

;
; sq_mix_buf_wr
;
; Mix buffer write position, low byte (high is fixed, hi8(sq_mix_buf))
;

;
; Internal channel structures:
;
; - byte 0:  ch(x)_pos + 0;  Wave position, low
; - byte 1:  ch(x)_pos + 1;  Wave position, high
; - byte 2:  ch(x)_wave;     Waveform selection (256 byte bank in ROM)
; - byte 3:  ch(x)_curvol;   Current volume (0 - 128 or 0 - 255 for Ch. 3)
; - byte 4:  ch(x)_step + 0; Step size, low (playing frequency)
; - byte 5:  ch(x)_step + 1; Step size, high (playing frequency)
;
; Extras for Channel 2:
;
; - byte 6:  ch2_ampos + 0;  AM wave position, low
; - byte 7:  ch2_ampos + 1;  AM wave position, high
; - byte 8:  ch2_amwave;     AM waveform selection (256 byte bank in ROM)
; - byte 9:  ch2_amstr;      AM strength
; - byte 10: ch2_amstep + 0; AM step size, low (AM frequency)
; - byte 11: ch2_amstep + 1; AM step size, high (AM frequency)
; - byte 12: ch2_prvvol;     Volume to ramp from
;

;
; sq_mix_vramp
;
; Volume ramp, reset to 0 to start a volume ramp on ch2 to next frame along
; with setting ch2_prvvol to the start point of the ramp (so preferably do
; this just before setting ch2_curvol).
;



.section .sq_audio_mixer



sq_mix_5sample:

	; At cycle 28 here (enter by rcall), sbi for SYNC need to complete at 145

	; Prepare (20 cy; 48 at end)

	push  r2
	push  r4
	push  r5
	push  r16
	push  r17
	push  r18
	push  r19
	push  r20
	push  r21
	push  r22

	; Channel 0 (56 cy; 104 at end)

	lds   r2,      ch0_pos + 0
	lds   ZL,      ch0_pos + 1
	lds   ZH,      ch0_wave
	lds   r16,     ch0_curvol ; 0 - 128
	lds   r4,      ch0_step + 0
	lds   r5,      ch0_step + 1

	lpm   r17,     Z
	mulsu r17,     r16
	mov   r18,     r1      ; Ch0, Sample 0
	add   r2,      r4
	adc   ZL,      r5

	lpm   r17,     Z
	mulsu r17,     r16
	mov   r19,     r1      ; Ch0, Sample 1
	add   r2,      r4
	adc   ZL,      r5

	lpm   r17,     Z
	mulsu r17,     r16
	mov   r20,     r1      ; Ch0, Sample 2
	add   r2,      r4
	adc   ZL,      r5

	lpm   r17,     Z
	mulsu r17,     r16
	mov   r21,     r1      ; Ch0, Sample 3
	add   r2,      r4
	adc   ZL,      r5

	lpm   r17,     Z
	mulsu r17,     r16
	mov   r22,     r1      ; Ch0, Sample 4
	add   r2,      r4
	adc   ZL,      r5

	sts   ch0_pos + 0, r2
	sts   ch0_pos + 1, ZL

	; Channel 1 (56 cy + 2)

	lds   r2,      ch1_pos + 0
	lds   ZL,      ch1_pos + 1
	lds   ZH,      ch1_wave
	lds   r16,     ch1_curvol ; 0 - 128
	lds   r4,      ch1_step + 0
	lds   r5,      ch1_step + 1

	lpm   r17,     Z
	mulsu r17,     r16
	add   r18,     r1      ; Ch1, Sample 0
	add   r2,      r4
	adc   ZL,      r5

	lpm   r17,     Z
	mulsu r17,     r16
	add   r19,     r1      ; Ch1, Sample 1
	add   r2,      r4
	adc   ZL,      r5

	lpm   r17,     Z
	mulsu r17,     r16
	add   r20,     r1      ; Ch1, Sample 2
	add   r2,      r4
	adc   ZL,      r5

	lpm   r17,     Z
	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; (145)
	mulsu r17,     r16
	add   r21,     r1      ; Ch1, Sample 3
	add   r2,      r4
	adc   ZL,      r5

	lpm   r17,     Z
	mulsu r17,     r16
	add   r22,     r1      ; Ch1, Sample 4
	add   r2,      r4
	adc   ZL,      r5

	sts   ch1_pos + 0, r2
	sts   ch1_pos + 1, ZL

	; Channel 2, AM (32 cy)

	lds   r2,      ch2_ampos + 0
	lds   ZL,      ch2_ampos + 1
	lds   ZH,      ch2_amwave
	lds   r16,     ch2_amstr
	lds   r4,      ch2_amstep + 0
	lds   r5,      ch2_amstep + 1

	lpm   r17,     Z
	subi  r17,     128     ; For AM, unsigned sample is required
	mul   r17,     r16
	ldi   ZH,      255
	sub   ZH,      r1      ; AM multiplier for Volume
	add   r2,      r4
	adc   ZL,      r5
	lsl   r4
	rol   r5
	lsl   r4
	rol   r5
	add   r2,      r4
	adc   ZL,      r5      ; Added 5x step

	sts   ch2_ampos + 0, r2
	sts   ch2_ampos + 1, ZL

	; Channel 2, Volume (21 cy)

	lds   r16,     ch2_curvol
	lds   ZL,      ch2_prvvol
	lds   r17,     sq_mix_vramp

	subi  r17,     251     ; Add 5 to volume ramp
	brcs  .+2
	ldi   r17,     255     ; Saturate

	sts   sq_mix_vramp, r17

	mul   r16,     r17
	mov   r16,     r1
	com   r17
	mul   ZL,      r17
	add   r16,     r1      ; Ramped volume

	mul   r16,     ZH
	mov   r16,     r1      ; Applied AM on it

	; Channel 2, processing (no fixed cycle count)

	lds   r2,      ch2_pos + 0
	lds   ZL,      ch2_pos + 1
	lds   ZH,      ch2_wave
	lds   r4,      ch2_step + 0
	lds   r5,      ch2_step + 1

	lpm   r17,     Z
	mulsu r17,     r16
	add   r18,     r1      ; Ch2, Sample 0
	brvc  .+6
	ldi   r18,     127     ; Positive overflow, saturation (+127)
	brmi  .+2
	ldi   r18,     128     ; Negative overflow, saturation (-128)
	add   r2,      r4
	adc   ZL,      r5

	lpm   r17,     Z
	mulsu r17,     r16
	add   r19,     r1      ; Ch2, Sample 1
	brvc  .+6
	ldi   r19,     127     ; Positive overflow, saturation (+127)
	brmi  .+2
	ldi   r19,     128     ; Negative overflow, saturation (-128)
	add   r2,      r4
	adc   ZL,      r5

	lpm   r17,     Z
	mulsu r17,     r16
	add   r20,     r1      ; Ch2, Sample 2
	brvc  .+6
	ldi   r20,     127     ; Positive overflow, saturation (+127)
	brmi  .+2
	ldi   r20,     128     ; Negative overflow, saturation (-128)
	add   r2,      r4
	adc   ZL,      r5

	lpm   r17,     Z
	mulsu r17,     r16
	add   r21,     r1      ; Ch2, Sample 3
	brvc  .+6
	ldi   r21,     127     ; Positive overflow, saturation (+127)
	brmi  .+2
	ldi   r21,     128     ; Negative overflow, saturation (-128)
	add   r2,      r4
	adc   ZL,      r5

	lpm   r17,     Z
	mulsu r17,     r16
	add   r22,     r1      ; Ch2, Sample 4
	brvc  .+6
	ldi   r22,     127     ; Positive overflow, saturation (+127)
	brmi  .+2
	ldi   r22,     128     ; Negative overflow, saturation (-128)
	add   r2,      r4
	adc   ZL,      r5

	sts   ch2_pos + 0, r2
	sts   ch2_pos + 1, ZL

	; Send samples to mix buffer

	lds   ZL,      sq_mix_buf_wr
	ldi   ZH,      hi8(sq_mix_buf)

	subi  r18,     128
	st    Z+,      r18
	subi  r19,     128
	st    Z+,      r19
	subi  r20,     128
	st    Z+,      r20
	subi  r21,     128
	st    Z+,      r21
	subi  r22,     128
	st    Z+,      r22

	sts   sq_mix_buf_wr, ZL

	; Done (20 cy)

	pop   r22
	pop   r21
	pop   r20
	pop   r19
	pop   r18
	pop   r17
	pop   r16
	pop   r5
	pop   r4
	pop   r2

	ret



sq_mix_2sample:

	; Prepare (14 cy)

	push  r2
	push  r4
	push  r5
	push  r16
	push  r17
	push  r18
	push  r19

	; Channel 0 (32 cy)

	lds   r2,      ch0_pos + 0
	lds   ZL,      ch0_pos + 1
	lds   ZH,      ch0_wave
	lds   r16,     ch0_curvol ; 0 - 128
	lds   r4,      ch0_step + 0
	lds   r5,      ch0_step + 1

	lpm   r17,     Z
	mulsu r17,     r16
	mov   r18,     r1      ; Ch0, Sample 0
	add   r2,      r4
	adc   ZL,      r5

	lpm   r17,     Z
	mulsu r17,     r16
	mov   r19,     r1      ; Ch0, Sample 1
	add   r2,      r4
	adc   ZL,      r5

	sts   ch0_pos + 0, r2
	sts   ch0_pos + 1, ZL

	; Channel 1 (32 cy)

	lds   r2,      ch1_pos + 0
	lds   ZL,      ch1_pos + 1
	lds   ZH,      ch1_wave
	lds   r16,     ch1_curvol ; 0 - 128
	lds   r4,      ch1_step + 0
	lds   r5,      ch1_step + 1

	lpm   r17,     Z
	mulsu r17,     r16
	add   r18,     r1      ; Ch1, Sample 0
	add   r2,      r4
	adc   ZL,      r5

	lpm   r17,     Z
	mulsu r17,     r16
	add   r19,     r1      ; Ch1, Sample 1
	add   r2,      r4
	adc   ZL,      r5

	sts   ch1_pos + 0, r2
	sts   ch1_pos + 1, ZL

	; Channel 2, AM (28 cy)

	lds   r2,      ch2_ampos + 0
	lds   ZL,      ch2_ampos + 1
	lds   ZH,      ch2_amwave
	lds   r16,     ch2_amstr
	lds   r4,      ch2_amstep + 0
	lds   r5,      ch2_amstep + 1

	lpm   r17,     Z
	subi  r17,     128     ; For AM, unsigned sample is required
	mul   r17,     r16
	ldi   ZH,      255
	sub   ZH,      r1      ; AM multiplier for Volume
	add   r2,      r4
	adc   ZL,      r5
	add   r2,      r4
	adc   ZL,      r5      ; Added 2x step

	sts   ch2_ampos + 0, r2
	sts   ch2_ampos + 1, ZL

	; Channel 2, Volume (21 cy)

	lds   r16,     ch2_curvol
	lds   ZL,      ch2_prvvol
	lds   r17,     sq_mix_vramp

	subi  r17,     254     ; Add 2 to volume ramp
	brcs  .+2
	ldi   r17,     255     ; Saturate

	sts   sq_mix_vramp, r17

	mul   r16,     r17
	mov   r16,     r1
	com   r17
	mul   ZL,      r17
	add   r16,     r1      ; Ramped volume

	mul   r16,     ZH
	mov   r16,     r1      ; Applied AM on it

	; Channel 2, processing (no fixed cycle count)

	lds   r2,      ch2_pos + 0
	lds   ZL,      ch2_pos + 1
	lds   ZH,      ch2_wave
	lds   r4,      ch2_step + 0
	lds   r5,      ch2_step + 1

	lpm   r17,     Z
	mulsu r17,     r16
	add   r18,     r1      ; Ch2, Sample 0
	brvc  .+6              ; If cycle count has to be maintained, branch & jump back
	ldi   r18,     127     ; Positive overflow, saturation (+127)
	brmi  .+2
	ldi   r18,     128     ; Negative overflow, saturation (-128)
	add   r2,      r4
	adc   ZL,      r5

	lpm   r17,     Z
	mulsu r17,     r16
	add   r19,     r1      ; Ch2, Sample 1
	brvc  .+6              ; If cycle count has to be maintained, branch & jump back
	ldi   r19,     127     ; Positive overflow, saturation (+127)
	brmi  .+2
	ldi   r19,     128     ; Negative overflow, saturation (-128)
	add   r2,      r4
	adc   ZL,      r5

	sts   ch2_pos + 0, r2
	sts   ch2_pos + 1, ZL

	; Send samples to mix buffer

	lds   ZL,      sq_mix_buf_wr
	ldi   ZH,      hi8(sq_mix_buf)

	subi  r18,     128
	st    Z+,      r18
	subi  r19,     128
	st    Z+,      r19

	sts   sq_mix_buf_wr, ZL

	; Done (14 cy)

	pop   r19
	pop   r18
	pop   r17
	pop   r16
	pop   r5
	pop   r4
	pop   r2

	ret
