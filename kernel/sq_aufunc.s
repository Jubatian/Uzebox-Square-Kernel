/*
 *  Uzebox Square Kernel - Audio functions
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
; This file is meant to be included by sq_kernel.s
;



;
; Small default patch set to have something to play with even without proper
; setup
;
.section .sq_tiny_text1

sq_defpatches:

	.byte 0x00, 0x00, 0x40 ; Envelope up by 0x40 per frame
	.byte 0x04, 0x06, 0x00 ; Note hold
	.byte 0x00, 0x20, 0xFC ; Release; envelope down by 0x04 per frame



;
; The following three are in .text as the kernel init uses them
;
.section .text



;
; void SQ_ChannelCutOff(uint8_t chan);
;
; Silences a channel. Effect is immediate, no release stage or anything.
;
;     r24: Channel to silence (0 - 2)
;
.global SQ_ChannelCutOff
SQ_ChannelCutOff:

	cpi   r24,     3
	brcs  .+2
	ret
	swap  r24
	mov   ZL,      r24
	ldi   ZH,      0
	subi  ZL,      lo8(-(sq_ch0_struct))
	sbci  ZH,      hi8(-(sq_ch0_struct))

	ldi   r25,     0xFF
	std   Z + chs_pcur_idx, r25
	ldi   r25,     0
	std   Z + chs_evol, r25
	std   Z + chs_evol_adj, r25
	ldi   r25,     hi8(sq_waveset)
	std   Z + chs_wave, r25

	ret



;
; void SQ_AudioCutOff(void);
;
; Silences all channels. Effect is immediate, no release stage or anything.
;
.global SQ_AudioCutOff
SQ_AudioCutOff:

	ldi   r24,     0
	rcall SQ_ChannelCutOff
	ldi   r24,     1
	rcall SQ_ChannelCutOff
	ldi   r24,     2
	rjmp  SQ_ChannelCutOff



;
; void SQ_SetPatchSet(void const* psetptr);
;
; Set patch set to use. Turns audio Off.
;
; r25:r24: Patch set pointer
;
.global SQ_SetPatchSet
SQ_SetPatchSet:

	sts   sq_patchset_ptr + 0, r24
	sts   sq_patchset_ptr + 1, r25
	ldi   r25,     0       ; Reset channel instruments to zero
	ldi   ZL,      lo8(sq_ch0_struct)
	ldi   ZH,      hi8(sq_ch0_struct)
	std   Z +  0 + chs_pbase_idx, r25
	std   Z + 16 + chs_pbase_idx, r25
	std   Z + 32 + chs_pbase_idx, r25
	rjmp  SQ_AudioCutOff



;
; void SQ_SetChannelVolume(uint8_t chan, uint8_t vol);
;
; Set channel volume. Note that Ch0 and Ch1 can only have at most 128 for
; volume.
;
;     r24: Channel to set volume for (0 - 2)
;     r22: Volume to set for the channel
;
.global SQ_SetChannelVolume
.section .text.SQ_SetChannelVolume
SQ_SetChannelVolume:

	cpi   r24,     3
	brcs  .+2
	ret
	swap  r24
	mov   ZL,      r24
	ldi   ZH,      0
	subi  ZL,      lo8(-(sq_ch0_struct))
	sbci  ZH,      hi8(-(sq_ch0_struct))

	cpi   r24,     0x20
	brcs  0f
	cpi   r22,     128
	brcs  .+2
	ldi   r22,     128     ; Ch0 and Ch1 is limited to 0-128 volume
0:

	std   Z + chs_cvol, r22
	ret



;
; void SQ_SetChannelInstrument(uint8_t chan, uint8_t ins);
;
; Set instrument for the channel. This is actually an index into the patch set
; where the instrument's patch sequence starts.
;
;     r24: Channel to set instrument for (0 - 2)
;     r22: Patch index where instrument starts
;
.global SQ_SetChannelInstrument
.section .text.SQ_SetChannelInstrument
SQ_SetChannelInstrument:

	cpi   r24,     3
	brcs  .+2
	ret
	swap  r24
	mov   ZL,      r24
	ldi   ZH,      0
	subi  ZL,      lo8(-(sq_ch0_struct))
	sbci  ZH,      hi8(-(sq_ch0_struct))

	std   Z + chs_pbase_idx, r22
	ret



;
; void SQ_NoteOn(uint8_t chan, uint8_t note, uint8_t nvol);
;
; Send Note ON to channel. Note is the Midi note, nvol is the note volume
; (roughly the velocity).
;
; Setting Bit 7 of Note asks for a smooth retrigger. This means any previous
; note which was playing isn't cut off, the new note takes over from wherever
; the previous one left off, joining envelopes. This only has effect if the
; current playing envelope is nonzero (so there is something still playing on
; the channel).
;
;     r24: Channel to send note on to (0 - 2)
;     r22: Midi note. Bit 7 asks for smooth retrigger if set
;     r20: Note volume or velocity
;
.global SQ_NoteOn
.section .text.SQ_NoteOn
SQ_NoteOn:

	cpi   r24,     3
	brcs  .+2
	ret
	swap  r24
	mov   ZL,      r24
	ldi   ZH,      0
	subi  ZL,      lo8(-(sq_ch0_struct))
	sbci  ZH,      hi8(-(sq_ch0_struct))

	; Check for smooth or hard retrigger

	sbrs  r22,     7
	rjmp  0f               ; No smooth retrigger asked: Hard retrigger
	ldd   r25,     Z + chs_evol
	cpi   r25,     0
	breq  0f               ; Current envelope is at zero: Hard retrigger
	rjmp  1f               ; Smooth retrigger otherwise

	; Hard retrigger
0:
	ldi   r25,     0
	std   Z + chs_evol, r25
	ldd   r25,     Z + chs_flags
	ori   r25,     0x02    ; Ask for resetting positions
	std   Z + chs_flags, r25

	; Smooth retrigger
1:
	ldd   r25,     Z + chs_flags
	ori   r25,     0x01    ; Note ON
	andi  r25,     0x03    ; Clear all expect Reset
	std   Z + chs_flags, r25
	ldd   r25,     Z + chs_pbase_idx
	std   Z + chs_pcur_idx, r25  ; Patch restarts
	ldi   r25,     0
	std   Z + chs_prem_tim, r25  ; No current patch time remaining
	std   Z + chs_evol_adj, r25  ; No envelope volume adjustment
	std   Z + chs_note_frac, r25 ; No fractional part for Note
	std   Z + chs_note_adjf, r25 ; No frequency sweep
	std   Z + chs_note_adj, r25  ; No frequency sweep
	std   Z + chs_tr_level, r25  ; Tremolo Off
	std   Z + chs_tr_rate, r25   ; Tremolo rate also Off
	std   Z + chs_tr_pos, r25    ; Tremolo restarts
	ldi   r25,     hi8(sq_waveset)
	std   Z + chs_wave, r25      ; Waveform by default is Sine (it is the first waveform in sq_waveset)

	; Apply note and note volume

	andi  r22,     0x7F
	std   Z + chs_note, r22
	std   Z + chs_nvol, r20
	ret



;
; void SQ_NoteOff(uint8_t chan);
;
; Send Note OFF to channel.
;
;     r24: Channel to send note off to (0 - 2)
;
.global SQ_NoteOff
.section .text.SQ_NoteOff
SQ_NoteOff:

	cpi   r24,     3
	brcs  .+2
	ret
	swap  r24
	mov   ZL,      r24
	ldi   ZH,      0
	subi  ZL,      lo8(-(sq_ch0_struct))
	sbci  ZH,      hi8(-(sq_ch0_struct))

	ldd   r22,     Z + chs_flags
	andi  r22,     0xFE    ; Note OFF (allowing for Release stage for held notes)
	std   Z + chs_flags, r22
	ret



;
; void SQ_SweepStart(uint8_t chan, int16_t sweep);
;
; Starts a frequency sweep. The sweep parameter is a 8.8 fixed point value
; specifying the sweep in whole notes per 60Hz tick (so the smallest sweep is
; 1/256th of a note per tick).
;
; Note that it can not be applied on instruments (patches) already containing
; frequency sweeps.
;
;     r24: Channel to start sweep on (0 - 2)
; r23:r22: Sweep amount / tick, 8.8 fixed point 2's complement
;
.global SQ_SweepStart
.section .text.SQ_SweepStart
SQ_SweepStart:

	cpi   r24,     3
	brcs  .+2
	ret
	swap  r24
	mov   ZL,      r24
	ldi   ZH,      0
	subi  ZL,      lo8(-(sq_ch0_struct))
	sbci  ZH,      hi8(-(sq_ch0_struct))

	std   Z + chs_note_adjf, r22
	std   Z + chs_note_adj,  r23
	ret



;
; void SQ_SweepStop(uint8_t chan);
;
; Stops a frequency sweep rounding the note to the nearest whole note.
;
;     r24: Channel to end sweep on (0 - 2)
;
.global SQ_SweepStop
.section .text.SQ_SweepStop
SQ_SweepStop:

	cpi   r24,     3
	brcs  .+2
	ret
	swap  r24
	mov   ZL,      r24
	ldi   ZH,      0
	subi  ZL,      lo8(-(sq_ch0_struct))
	sbci  ZH,      hi8(-(sq_ch0_struct))

	ldd   r24,     Z + chs_note_frac
	ldd   r25,     Z + chs_note
	sbrc  r24,     7
	inc   r25              ; Round to nearest whole note
	std   Z + chs_note, r25

	ldi   r24,     0
	std   Z + chs_note_adjf, r24
	std   Z + chs_note_adj,  r24
	std   Z + chs_note_frac, r24
	ret



;
; uint8_t SQ_GetChannelImportance(uint8_t chan);
;
; Returns an importance value calculated for the current channel. This can be
; used for implementing dynamic channel allocation schemes. The higher the
; return value is, the more important is the playing note on the channel. It
; roughly tranlates to a peak volume the the note would achieve on the
; channel.
;
;     r24: Channel to query (0 - 2)
; Returns:
;     r24: Importance value (volume)
;
.global SQ_GetChannelImportance
.section .text.SQ_GetChannelImportance
SQ_GetChannelImportance:

	cpi   r24,     3
	brcs  .+2
	ret
	swap  r24
	mov   ZL,      r24
	ldi   ZH,      0
	subi  ZL,      lo8(-(sq_ch0_struct))
	sbci  ZH,      hi8(-(sq_ch0_struct))

	ldd   r24,     Z + chs_nvol ; By default importance is the note volume
	ldi   r25,     0

	ldd   r23,     Z + chs_flags
	sbrs  r23,     0       ; Note ON?
	rjmp  0f               ; For Note OFF, assume release stage (even if envelope is steady)

	ldd   r23,     Z + chs_evol_adj
	sbrs  r23,     7
	ret                    ; Envelope is rising or steady: assume reaching Note Volume

0:
	ldd   r23,     Z + chs_evol
	mul   r23,     r24
	mov   r24,     r1
	clr   r1
	ret                    ; Decaying envelope or Release: Return current volume
