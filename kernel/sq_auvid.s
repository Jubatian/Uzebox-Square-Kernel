/*
 *  Uzebox Square Kernel - Audio-Video driver
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
; Global assembly delay macro for 0 to 1535 cycles
; Parameters: reg = Registerto use in inner loop (will be destroyed)
;             clocks = CPU clocks to wait
;
.macro WAIT reg, clocks
.if     (\clocks) >= 768
	ldi   \reg,    0
	dec   \reg
	brne  .-4
.endif
.if     ((\clocks) % 768) >= 9
	ldi   \reg,    ((\clocks) % 768) / 3
	dec   \reg
	brne  .-4
.if     ((\clocks) % 3) == 2
	rjmp  .
.elseif ((\clocks) % 3) == 1
	nop
.endif
.elseif ((\clocks) % 768) == 8
	lpm   \reg,    Z
	lpm   \reg,    Z
	rjmp  .
.elseif ((\clocks) % 768) == 7
	lpm   \reg,    Z
	rjmp  .
	rjmp  .
.elseif ((\clocks) % 768) == 6
	lpm   \reg,    Z
	lpm   \reg,    Z
.elseif ((\clocks) % 768) == 5
	lpm   \reg,    Z
	rjmp  .
.elseif ((\clocks) % 768) == 4
	rjmp  .
	rjmp  .
.elseif ((\clocks) % 768) == 3
	lpm   \reg,    Z
.elseif ((\clocks) % 768) == 2
	rjmp  .
.elseif ((\clocks) % 768) == 1
	nop
.endif
.endm



.section .sq_video_core


;
; Video sync generation, Sync for normal 262p video:
;
;   0 - 252: 253 x (136cy LOW, 1684cy HIGH)
;       253: 68cy LOW, 842cy HIGH, 68cy LOW, 842cy HIGH,
;       254: 68cy LOW, 842cy HIGH, 68cy LOW, 842cy HIGH,
;       255: 68cy LOW, 842cy HIGH, 68cy LOW, 842cy HIGH,
;       256: 774cy LOW, 136cy HIGH, 774cy LOW, 136cy HIGH,
;       257: 774cy LOW, 136cy HIGH, 774cy LOW, 136cy HIGH,
;       258: 774cy LOW, 136cy HIGH, 774cy LOW, 136cy HIGH,
;       259: 68cy LOW, 842cy HIGH, 68cy LOW, 842cy HIGH,
;       260: 68cy LOW, 842cy HIGH, 68cy LOW, 842cy HIGH,
;       261: 68cy LOW, 842cy HIGH, 68cy LOW, 842cy HIGH,
;
; Task layout for the lines:
;
;   0 -  29: Sample 171 - 200, 30 * 5 samples into  45 - 194
;        30: Sample       201,  1 * 5 samples into 195 - 199, 2 samples into 200 - 201
;        31: Sample         0, Display lead-in
;  32 - 231: Sample   1 - 200, Display frame
;       232: Sample       201,  1 * 5 samples into 142 - 146
; 233 - 243: Sample 142 - 152, 11 * 5 samples into 147 - 201
; 244 - 252: Sample 153 - 161,  9 * 5 samples into   0 -  44
;       253: Sample       162, Controller latch, bit 0 read
;       254: Sample       163, Controller bits 1, 2 read
;       255: Sample       164, Controller bits 3, 4 read
;       256: Sample       165, Controller bits 5, 6 read
;       257: Sample       166, Controller bits 7, 8 read
;       258: Sample       167, Controller bits 9, 10 read
;       259: Sample       168, Controller bits 11 read
;       260: Sample       169, Controller bits 12, 13 read
;       261: Sample       170, Controller bits 14, 15 read
;
; Line 30: The Mixer's internal state is also updated here to prevent IT
; hazards.
;

;
; Video generation entry table:
;
; The sync interrupt, after a jitter compensation, branches off using a jump
; table. This is as follows:
;
;       0: Line          0, sq_sline_0, set for 1820cy
;  1 - 29: Lines   1 -  29, sq_sline_1
;      30: Line         30, sq_sline_30
;      31: Line         31, sq_sline_31, display lead-in
;      32: Lines  32 - 231, sq_sline_32, used when display is off (CPU free for user)
;      33: Line        232, sq_sline_232, prepares for VBlank samples
; 34 - 43: Lines 233 - 242, sq_sline_1
;      44: Line        243, sq_sline_243, prepares for Display samples
; 45 - 52: Lines 244 - 251, sq_sline_1
;      53: Line        252, sq_sline_252, transition to VSync, controller latch on
;      54: Line        253, sq_sline_253a, controller latch off
;      55: Line        253, sq_sline_253b
;      56: Line        254, sq_sline_254a
;      57: Line        254, sq_sline_253b
;      58: Line        255, sq_sline_254a
;      59: Line        255, sq_sline_253b
;      60: Line        256, sq_sline_256a, no controller bit, just set for 774cy
;      61: Line        256, sq_sline_256b, back to 910cy
;      62: Line        256, sq_sline_256c
;      63: Line        257, sq_sline_257a
;      64: Line        257, sq_sline_256c
;      65: Line        258, sq_sline_257a
;      66: Line        258, sq_sline_258b, also line 259's low, set for 1046cy
;      67: Line        259, sq_sline_259b, back to 910cy
;      68: Line        260, sq_sline_254a
;      69: Line        260, sq_sline_253b
;      70: Line        261, sq_sline_254a
;      71: Line        261, sq_sline_261b
;
; Actual numbers are adjusted to the table's position (just above the IT
; vector table)
;

;
; GPIO register usage:
;
; GPIOR0, bit 0: Set if Video display is disabled (no frame reset, all CPU time is user)
; GPIOR0, bit 1: Set if Display frame happened (only used when display is OFF, for timing)
; GPIOR0, bit 2: Set to request wasting CPU time.
; GPIOR1: ZL temp store
; GPIOR2: ZH temp store
;
; Wasting CPU time: The FS library in the bootloader is designed with the
; assumption that the video generation runs all the time. To prevent it giving
; too little time for an SD card to initialize, this has to be provided, to
; allow for purposely slowing down the system during FS initialization.
;

;
; Sync generation uses only COMPA. The COMPB vector is used for the video mode
; itself, to terminate scanlines by timer.
;



.section .sq_tiny_text0

;
; OCR1A Interrupt entry
;
; Timer is always reset to zero, so begin with jitter compensation
; accordingly.
;
TIMER1_COMPA_vect:

	; (3 cy IT entry latency)
	; (2 cy RJMP)

	out   _SFR_IO_ADDR(GPIOR1), ZL
	out   _SFR_IO_ADDR(GPIOR2), ZH
	lds   ZH,      _SFR_MEM_ADDR(TCNT1L) ; Timer: 0x08 - 0x0D (5cy jitter)

	sbrc  ZH,      2
	rjmp  .+8              ; 0x0D ( 5) or 0x0C ( 6)
	sbrc  ZH,      1
	rjmp  .+4              ; 0x0B ( 7) or 0x0A ( 8)
	nop
	rjmp  .                ; 0x09 ( 9) or 0x08 (10)
	sbrs  ZH,      0
	rjmp  .

	; An lds of TCNT1L here would result 0x14

	lds   ZL,      video_jtab_lo ; ( 2) Jump Table entry point
	ldi   ZH,      hi8(pm(video_jtab)) ; ( 3)
	ijmp                   ; ( 5)



;
; This is just above the IT vectors, the point is that it has to reside in one
; 256 word memory bank, so a fixed ZH can access it. ZL is the address within
; the bank, initialized to the beginning of the table.
;

.section .sq_video_vsync_jtb

video_jtab:

	rjmp  sq_sline_0       ;  0
	rjmp  sq_sline_1       ;  1
	rjmp  sq_sline_1       ;  2
	rjmp  sq_sline_1       ;  3
	rjmp  sq_sline_1       ;  4
	rjmp  sq_sline_1       ;  5
	rjmp  sq_sline_1       ;  6
	rjmp  sq_sline_1       ;  7
	rjmp  sq_sline_1       ;  8
	rjmp  sq_sline_1       ;  9
	rjmp  sq_sline_1       ; 10
	rjmp  sq_sline_1       ; 11
	rjmp  sq_sline_1       ; 12
	rjmp  sq_sline_1       ; 13
	rjmp  sq_sline_1       ; 14
	rjmp  sq_sline_1       ; 15
	rjmp  sq_sline_1       ; 16
	rjmp  sq_sline_1       ; 17
	rjmp  sq_sline_1       ; 18
	rjmp  sq_sline_1       ; 19
	rjmp  sq_sline_1       ; 20
	rjmp  sq_sline_1       ; 21
	rjmp  sq_sline_1       ; 22
	rjmp  sq_sline_1       ; 23
	rjmp  sq_sline_1       ; 24
	rjmp  sq_sline_1       ; 25
	rjmp  sq_sline_1       ; 26
	rjmp  sq_sline_1       ; 27
	rjmp  sq_sline_1       ; 28
	rjmp  sq_sline_1       ; 29
	rjmp  sq_sline_30      ; 30
	rjmp  sq_sline_31      ; 31
	rjmp  sq_sline_32      ; 32
	rjmp  sq_sline_232     ; 33
	rjmp  sq_sline_1       ; 34
	rjmp  sq_sline_1       ; 35
	rjmp  sq_sline_1       ; 36
	rjmp  sq_sline_1       ; 37
	rjmp  sq_sline_1       ; 38
	rjmp  sq_sline_1       ; 39
	rjmp  sq_sline_1       ; 40
	rjmp  sq_sline_1       ; 41
	rjmp  sq_sline_1       ; 42
	rjmp  sq_sline_1       ; 43
	rjmp  sq_sline_243     ; 44
	rjmp  sq_sline_1       ; 45
	rjmp  sq_sline_1       ; 46
	rjmp  sq_sline_1       ; 47
	rjmp  sq_sline_1       ; 48
	rjmp  sq_sline_1       ; 49
	rjmp  sq_sline_1       ; 50
	rjmp  sq_sline_1       ; 51
	rjmp  sq_sline_1       ; 52
	rjmp  sq_sline_252     ; 53
	rjmp  sq_sline_253a    ; 54
	rjmp  sq_sline_253b    ; 55
	rjmp  sq_sline_254a    ; 56
	rjmp  sq_sline_253b    ; 57
	rjmp  sq_sline_254a    ; 58
	rjmp  sq_sline_253b    ; 59
	rjmp  sq_sline_256a    ; 60
	rjmp  sq_sline_256b    ; 61
	rjmp  sq_sline_256c    ; 62
	rjmp  sq_sline_257a    ; 63
	rjmp  sq_sline_256c    ; 64
	rjmp  sq_sline_257a    ; 65
	rjmp  sq_sline_258b    ; 66
	rjmp  sq_sline_259b    ; 67
	rjmp  sq_sline_254a    ; 68
	rjmp  sq_sline_253b    ; 69
	rjmp  sq_sline_254a    ; 70
	rjmp  sq_sline_261b    ; 71
	rjmp  sq_sline_32st    ; 72 (shrink top lines)
	rjmp  sq_sline_32sb    ; 73 (shrink bottom lines)



.section .sq_video_core



sq_sline_0:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	lds   ZL,      sq_mix_buf_rd
	ldi   ZH,      hi8(sq_mix_buf)
	push  r0
	ld    r0,      Z+
	sts   sq_mix_buf_rd, ZL
	sts   _SFR_MEM_ADDR(OCR2A), r0 ; (20) Output sound sample
	push  r1
	in    r1,      _SFR_IO_ADDR(SREG)
	push  r1               ; (25)
	rcall sq_mix_5sample   ; End of precise timing

	; Set timer for normal lines

	ldi   ZH,      hi8(1819)
	ldi   ZL,      lo8(1819)
	sts   _SFR_MEM_ADDR(OCR1AH), ZH
	sts   _SFR_MEM_ADDR(OCR1AL), ZL

	; Done

	rjmp  sq_sline_common_ret


sq_sline_1:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	lds   ZL,      sq_mix_buf_rd
	ldi   ZH,      hi8(sq_mix_buf)
	push  r0
	ld    r0,      Z+
	sts   sq_mix_buf_rd, ZL
	sts   _SFR_MEM_ADDR(OCR2A), r0 ; (20) Output sound sample
	push  r1
	in    r1,      _SFR_IO_ADDR(SREG)
	push  r1               ; (25)
	rcall sq_mix_5sample   ; End of precise timing

sq_sline_common_ret:

	lds   ZL,      video_jtab_lo
	inc   ZL               ; Next jump table entry point
	sts   video_jtab_lo, ZL
	pop   r1
	out   _SFR_IO_ADDR(SREG), r1
	pop   r1
	pop   r0
	in    ZH,      _SFR_IO_ADDR(GPIOR2)
	in    ZL,      _SFR_IO_ADDR(GPIOR1)
	reti


sq_sline_30:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	lds   ZL,      sq_mix_buf_rd
	ldi   ZH,      hi8(sq_mix_buf)
	push  r0
	ld    r0,      Z+
	sts   sq_mix_buf_rd, ZL
	sts   _SFR_MEM_ADDR(OCR2A), r0 ; (20) Output sound sample
	push  r1
	in    r1,      _SFR_IO_ADDR(SREG)
	push  r1               ; (25)
	rcall sq_mix_5sample   ; End of precise timing
	rcall sq_mix_2sample

	; Mixer writes go to 142 for VBlank's samples

	ldi   ZL,      lo8(sq_mix_buf + 142)
	sts   sq_mix_buf_wr, ZL

	; Patches are done here so latency is kept as low as reasonably
	; possible with this architecture. Not terribly good when shrinking
	; the screen, but audio should not be left for so long (at this point
	; typically only interruptible render should be running).

	push  YL
	push  YH
	push  r22
	push  r23
	push  r24
	push  r25
	call  sq_patch_proc
	pop   r25
	pop   r24
	pop   r23
	pop   r22
	pop   YH
	pop   YL

	; Done

	rjmp  sq_sline_common_ret


sq_sline_31:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	push  r0
	lds   r0,      sq_mix_buf + 0
	ldi   ZL,      lo8(sq_mix_buf + 0)
	sts   sq_mix_buf_rd, ZL
	push  r1
	sts   _SFR_MEM_ADDR(OCR2A), r0 ; (20) Output sound sample
	in    r1,      _SFR_IO_ADDR(SREG)
	push  r1               ; (23)

	; Check for screen shrinking. If screen shrinking is present, then
	; entering the display region happens only later.

	lpm   ZL,      Z       ; (26) Nop
	lds   ZL,      sq_video_shrink
	cpi   ZL,      0
	breq  sq_video_leadin  ; (30 / 31)
	sts   video_doff_lctr, ZL
	ldi   ZL,      72      ; Next jump table entry point, sq_sline_32st; Shrink top
	sts   video_jtab_lo, ZL  ; ( 35)
	WAIT  ZL,      95      ; (130)
	rjmp  sq_sline_shrink_comm

sq_video_leadin:

	; Update frame counter

	lds   ZL,      sq_frame_counter
	inc   ZL
	sts   sq_frame_counter, ZL ; (36)

	; Update controller state from the bits read in last VSync

	lds   ZL,      joypad1_stat_t + 0
	sts   sq_joypad1_stat + 0, ZL
	lds   ZL,      joypad1_stat_t + 1
	sts   sq_joypad1_stat + 1, ZL
	lds   ZL,      joypad2_stat_t + 0
	sts   sq_joypad2_stat + 0, ZL
	lds   ZL,      joypad2_stat_t + 1
	sts   sq_joypad2_stat + 1, ZL ; (52)

	; Prepare for updating mixer. This is done regardless of whether
	; display is ON or OFF (audio may keep playing when screen is blank),
	; so the registers have to be saved & possibly restored.

	push  r22
	push  r23
	push  r24
	push  r25
	push  XL
	push  XH
	push  YL
	push  YH               ; (68)

	; Check for soft reset keycombo (Start + Select + Y + B), if this is
	; present, then trigger a soft reset using the watchdog.

	ldi   r25,     0
	lds   ZL,      sq_joypad1_stat + 0
	andi  ZL,      0x0F
	cpi   ZL,      0x0F    ; (73) Start + Select + Y + B down on P1
	brne  .+2
	ldi   r25,     1
	lds   ZL,      sq_joypad2_stat + 0
	andi  ZL,      0x0F
	cpi   ZL,      0x0F    ; (79) Start + Select + Y + B down on P2
	brne  .+2
	ldi   r25,     1       ; (81)
	ldi   ZL,      lo8(_SFR_MEM_ADDR(WDTCSR))
	ldi   ZH,      hi8(_SFR_MEM_ADDR(WDTCSR))
	ld    r24,     Z
	sbrc  r24,     WDE     ; (86 / 87) WD already enabled?
	ldi   r25,     0       ; (87) If enabled, do nothing, so it can time out
	sbrc  r25,     0
	rjmp  .+6
	lpm   r24,     Z
	rjmp  .
	rjmp  .+8              ; (96)
	ldi   r24,     (1 << WDCE) | (1 << WDE)
	ldi   r25,     (1 << WDE) ; Enable Watchdog, 16ms timeout
	st    Z,       r24
	st    Z,       r25     ; (96)

	; Wait for sync low end

	WAIT  ZL,      47      ; (143)
	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; (145)

	; Update mixer

	rcall sq_proc_audio_60 ; (672)

	; Note: Display ON / OFF difference: When the display is ON, the
	; stack is discarded (at the end of the frame a specific entry point
	; will be called). When it is OFF, the interrupt returns as normal.

	; Check whether display is ON. If display is ON, then the display
	; frame should begin, otherwise display will remain blank, all the
	; CPU time belongs to the user, having only sample outputs.

	sbis  _SFR_IO_ADDR(GPIOR0), 0
	rjmp  vm0_leadin       ; (675) Go on to Video Mode lead-in

	; If display is OFF, set Display frame flag (so 60Hz timing can be
	; maintained even then, for example for playing music).

	sbi   _SFR_IO_ADDR(GPIOR0), 1

	; Done, go on with Display OFF

	ldi   ZL,      200     ; 200 scanlines where the display should normally be
	sts   video_doff_lctr, ZL

	pop   YH
	pop   YL
	pop   XH
	pop   XL
	pop   r25
	pop   r24
	pop   r23
	pop   r22

	rjmp  sq_sline_common_ret

sq_video_exit:

	; Video mode exit point, tidy up, call frame routine

	ldi   ZL,      0xFF    ; Empty stack
	out   _SFR_IO_ADDR(SPL), ZL
	clr   r1               ; r1 zero for C
	sbi   _SFR_IO_ADDR(GPIOR0), 0 ; Disable display
	cbi   _SFR_IO_ADDR(GPIOR0), 1 ; Clear display frame flag
	lds   ZH,      sq_video_shrink
	sts   video_doff_lctr, ZH
	cpi   ZH,      0
	ldi   ZL,      33      ; Next jump table entry point, skipping Display Off lines
	breq  .+2
	ldi   ZL,      73      ; Next jump table entry point, sq_sline_32sb; Shrink bottom
	sts   video_jtab_lo, ZL
	rcall .+4              ; Simple solution so returning from frame function would enter an infinite loop
	jmp   SQ_End           ; A proper end upon return (jmp: 2 words)
	lds   ZL,      sq_frame_func + 0
	lds   ZH,      sq_frame_func + 1
	sei                    ; No reti, just enable ITs and go (OK on an ATmega)
	ijmp


sq_sline_32st:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	lds   ZL,      sq_mix_buf_rd
	ldi   ZH,      hi8(sq_mix_buf)
	push  r0
	ld    r0,      Z+
	sts   sq_mix_buf_rd, ZL
	sts   _SFR_MEM_ADDR(OCR2A), r0 ; (20) Output sound sample
	push  r1
	in    r1,      _SFR_IO_ADDR(SREG)
	push  r1               ; (25)

	; Count down remaining shrinked lines

	lds   ZL,      video_doff_lctr
	dec   ZL
	brne  .+2
	rjmp  sq_video_leadin  ; (31)
	sts   video_doff_lctr, ZL

	; Just waste line

	WAIT  ZL,      100     ; (132)

sq_sline_shrink_comm:

	pop   r0               ; (134) SREG restored into r0
	pop   r1               ; (136)
	rjmp  sq_sline_sync_end  ; (138)


sq_sline_32sb:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	lds   ZL,      sq_mix_buf_rd
	ldi   ZH,      hi8(sq_mix_buf)
	push  r0
	ld    r0,      Z+
	sts   sq_mix_buf_rd, ZL
	sts   _SFR_MEM_ADDR(OCR2A), r0 ; (20) Output sound sample

	; Count down remaining lines of the Display OFF display region

	in    r0,      _SFR_IO_ADDR(SREG)
	lds   ZL,      video_doff_lctr
	dec   ZL
	sts   video_doff_lctr, ZL
	ldi   ZL,      33      ; Next jump table entry point
	breq  .+2
	ldi   ZL,      32      ; Only when coundown reaches zero
	sts   video_jtab_lo, ZL  ; (31)

	; Wait to get 136 cycle Sync LOW pulse

	WAIT  ZL,      105     ; (136)
	rjmp  sq_sline_sync_end  ; (138)


sq_sline_32:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	lds   ZL,      sq_mix_buf_rd
	ldi   ZH,      hi8(sq_mix_buf)
	push  r0
	ld    r0,      Z+
	sts   sq_mix_buf_rd, ZL
	sts   _SFR_MEM_ADDR(OCR2A), r0 ; (20) Output sound sample

	; Count down remaining lines of the Display OFF display region

	in    r0,      _SFR_IO_ADDR(SREG)
	lds   ZL,      video_doff_lctr
	dec   ZL
	sts   video_doff_lctr, ZL
	ldi   ZL,      33      ; Next jump table entry point
	breq  .+2
	ldi   ZL,      32      ; Only when coundown reaches zero
	sts   video_jtab_lo, ZL  ; (31)

	; Wait to get 136 cycle Sync LOW pulse

	WAIT  ZL,      105     ; (136)

	; Do we need wasting cycles? (For bootloader FS library)

	sbic  _SFR_IO_ADDR(GPIOR0), 2
	rjmp  sq_sline_32_waste

	; End, clean up

sq_sline_sync_end:

	out   _SFR_IO_ADDR(SREG), r0
	pop   r0
	in    ZH,      _SFR_IO_ADDR(GPIOR2)
	in    ZL,      _SFR_IO_ADDR(GPIOR1)
	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; (145)
	reti

sq_sline_32_waste:

	rjmp  .
	rjmp  .
	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; (145)
	WAIT  ZL,      1535
	WAIT  ZL,       111
	out   _SFR_IO_ADDR(SREG), r0
	pop   r0
	in    ZH,      _SFR_IO_ADDR(GPIOR2)
	in    ZL,      _SFR_IO_ADDR(GPIOR1)
	reti


sq_sline_232:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	lds   ZL,      sq_mix_buf_rd
	ldi   ZH,      hi8(sq_mix_buf)
	push  r0
	ld    r0,      Z+
	sts   sq_mix_buf_rd, ZL
	sts   _SFR_MEM_ADDR(OCR2A), r0 ; (20) Output sound sample
	push  r1
	in    r1,      _SFR_IO_ADDR(SREG)
	push  r1               ; (25)
	rcall sq_mix_5sample   ; End of precise timing

	; Mixer reads begin at 142 for VBlank's samples

	ldi   ZL,      lo8(sq_mix_buf + 142)
	sts   sq_mix_buf_rd, ZL

	; Done

	rjmp  sq_sline_common_ret


sq_sline_243:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	lds   ZL,      sq_mix_buf_rd
	ldi   ZH,      hi8(sq_mix_buf)
	push  r0
	ld    r0,      Z+
	sts   sq_mix_buf_rd, ZL
	sts   _SFR_MEM_ADDR(OCR2A), r0 ; (20) Output sound sample
	push  r1
	in    r1,      _SFR_IO_ADDR(SREG)
	push  r1               ; (25)
	rcall sq_mix_5sample   ; End of precise timing

	; Mixer writes go to 0 for Display frame's samples

	ldi   ZL,      lo8(sq_mix_buf + 0)
	sts   sq_mix_buf_wr, ZL

	; Done

	rjmp  sq_sline_common_ret


sq_sline_252:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	lds   ZL,      sq_mix_buf_rd
	ldi   ZH,      hi8(sq_mix_buf)
	push  r0
	ld    r0,      Z+
	sts   sq_mix_buf_rd, ZL
	sts   _SFR_MEM_ADDR(OCR2A), r0 ; (20) Output sound sample
	push  r1
	in    r1,      _SFR_IO_ADDR(SREG)
	push  r1               ; (25)
	rcall sq_mix_5sample   ; End of precise timing

	; Controller latch ON

	sbi   _SFR_IO_ADDR(JOYPAD_OUT_PORT), JOYPAD_LATCH_PIN

	; Done

	rjmp  sq_sline_common_ret


sq_sline_253a:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	lds   ZL,      sq_mix_buf_rd
	ldi   ZH,      hi8(sq_mix_buf)
	push  r0
	ld    r0,      Z+
	sts   sq_mix_buf_rd, ZL
	sts   _SFR_MEM_ADDR(OCR2A), r0 ; (20) Output sound sample

	; Controller latch OFF

	cbi   _SFR_IO_ADDR(JOYPAD_OUT_PORT), JOYPAD_LATCH_PIN

	; Set up 910 cycles between Sync pulses

	ldi   ZH,      hi8(909)
	ldi   ZL,      lo8(909)
	sts   _SFR_MEM_ADDR(OCR1AH), ZH
	sts   _SFR_MEM_ADDR(OCR1AL), ZL ; (28)

	; Delay to make a 68 cycle pulse

	in    ZH,      _SFR_IO_ADDR(SREG)
	WAIT  ZL,      36
	out   _SFR_IO_ADDR(SREG), ZH ; (66)

	ldi   ZL,      55      ; Next jump table entry point
	sts   video_jtab_lo, ZL
	pop   r0               ; (71)
	in    ZH,      _SFR_IO_ADDR(GPIOR2)
	in    ZL,      _SFR_IO_ADDR(GPIOR1)

	; High -> Low on Controller clock

	cbi   _SFR_IO_ADDR(JOYPAD_OUT_PORT), JOYPAD_CLOCK_PIN ; (75)

	; 68 cy Sync pulse end

	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; (77)

	; Done

	reti


sq_sline_253b:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	lpm   ZL,      Z       ; (12)
	lpm   ZL,      Z       ; (15)
	nop                    ; (16)
	push  r0               ; (18)
	rjmp  sq_sline_254com  ; (20)


sq_sline_254a:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	lds   ZL,      sq_mix_buf_rd
	ldi   ZH,      hi8(sq_mix_buf)
	push  r0
	ld    r0,      Z+
	sts   sq_mix_buf_rd, ZL
	sts   _SFR_MEM_ADDR(OCR2A), r0 ; (20) Output sound sample

sq_sline_254com:

	push  r1
	in    r1,      _SFR_IO_ADDR(SREG)
	push  r1               ; (25)

	; Read controller bit

	rcall sq_sline_cread   ; (61)

	; Clean up

	lds   ZL,      video_jtab_lo
	inc   ZL               ; Next jump table entry point
	sts   video_jtab_lo, ZL
	pop   r1
	out   _SFR_IO_ADDR(SREG), r1
	pop   r1
	pop   r0
	in    ZH,      _SFR_IO_ADDR(GPIOR2)
	in    ZL,      _SFR_IO_ADDR(GPIOR1)

	; Sync pulse and end

	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; (77)
	cbi   _SFR_IO_ADDR(JOYPAD_OUT_PORT), JOYPAD_CLOCK_PIN
	reti


sq_sline_256a:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	lds   ZL,      sq_mix_buf_rd
	ldi   ZH,      hi8(sq_mix_buf)
	push  r0
	ld    r0,      Z+
	sts   sq_mix_buf_rd, ZL
	sts   _SFR_MEM_ADDR(OCR2A), r0 ; (20) Output sound sample

	; Set up 774 cycles until Sync HIGH pulse

	ldi   ZH,      hi8(773)
	ldi   ZL,      lo8(773)
	sts   _SFR_MEM_ADDR(OCR1AH), ZH
	sts   _SFR_MEM_ADDR(OCR1AL), ZL ; (26)

	; Done, end

	ldi   ZL,      61      ; Next jump table entry point
	sts   video_jtab_lo, ZL
	pop   r0
	in    ZH,      _SFR_IO_ADDR(GPIOR2)
	in    ZL,      _SFR_IO_ADDR(GPIOR1)
	reti


sq_sline_256b:

	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)

	; Set up 910 cycles between Sync HIGH pulses

	ldi   ZH,      hi8(909)
	ldi   ZL,      lo8(909)
	sts   _SFR_MEM_ADDR(OCR1AH), ZH
	sts   _SFR_MEM_ADDR(OCR1AL), ZL ; (15)

sq_line_256com:

	push  r0
	push  r1
	in    r1,      _SFR_IO_ADDR(SREG)
	push  r1               ; (22)

	; Read controller bit

	rcall sq_sline_cread   ; (58)

	; Wait to get 136 cycle HIGH pulse

	WAIT  ZL,      69      ; (127)

	; End without sound sample

	lds   ZL,      video_jtab_lo
	inc   ZL               ; Next jump table entry point
	sts   video_jtab_lo, ZL
	pop   r1               ; (134)
	out   _SFR_IO_ADDR(SREG), r1
	pop   r1
	pop   r0
	in    ZH,      _SFR_IO_ADDR(GPIOR2)
	in    ZL,      _SFR_IO_ADDR(GPIOR1)
	cbi   _SFR_IO_ADDR(JOYPAD_OUT_PORT), JOYPAD_CLOCK_PIN
	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; (145)
	reti


sq_sline_256c:

	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	push  r0
	push  r1
	in    r1,      _SFR_IO_ADDR(SREG)
	push  r1               ; (16)

	; Read controller bit

	rcall sq_sline_cread   ; (52)

	; Wait to get 136 cycle HIGH pulse

	WAIT  ZL,      77      ; (129)

	; End along with producing sound sample

	lds   ZL,      video_jtab_lo
	inc   ZL               ; Next jump table entry point
	sts   video_jtab_lo, ZL
	pop   r1               ; (136)
	out   _SFR_IO_ADDR(SREG), r1
	pop   r1
	cbi   _SFR_IO_ADDR(JOYPAD_OUT_PORT), JOYPAD_CLOCK_PIN
	lds   ZL,      sq_mix_buf_rd
	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; (145)
	ldi   ZH,      hi8(sq_mix_buf)
	ld    r0,      Z+
	sts   sq_mix_buf_rd, ZL
	mov   ZL,      r0
	pop   r0
	in    ZH,      _SFR_IO_ADDR(GPIOR2)
	sts   _SFR_MEM_ADDR(OCR2A), ZL ; (156) Output sound sample
	in    ZL,      _SFR_IO_ADDR(GPIOR1)
	reti


sq_sline_257a:

	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)

	rjmp  .
	rjmp  .
	rjmp  sq_line_256com   ; (15)


sq_sline_258b:

	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)
	push  r0
	push  r1
	in    r1,      _SFR_IO_ADDR(SREG)
	push  r1               ; (16)

	; Read controller bit

	rcall sq_sline_cread   ; (52)

	; Wait to get 136 cycle HIGH pulse

	WAIT  ZL,      89      ; (141)

	; End Sync HIGH along with producing sound sample

	cbi   _SFR_IO_ADDR(JOYPAD_OUT_PORT), JOYPAD_CLOCK_PIN
	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; (145)
	lds   ZL,      sq_mix_buf_rd
	ldi   ZH,      hi8(sq_mix_buf)
	rjmp  .
	ld    r0,      Z+
	sts   sq_mix_buf_rd, ZL
	sts   _SFR_MEM_ADDR(OCR2A), r0 ; (156) Output sound sample

	; Compensate back to generating normal Sync LOW pulses by a 1046cy timeout

	ldi   ZH,      hi8(1045)
	ldi   ZL,      lo8(1045)
	sts   _SFR_MEM_ADDR(OCR1AH), ZH
	sts   _SFR_MEM_ADDR(OCR1AL), ZL ; (162)

	; Wait to get 68 cycle LOW pulse

	WAIT  ZL,      37      ; (199)

	; End with Sync driven HIGH again.

	ldi   ZL,      67      ; Next jump table entry point
	sts   video_jtab_lo, ZL
	pop   r1               ; (204)
	out   _SFR_IO_ADDR(SREG), r1
	pop   r1
	pop   r0
	in    ZH,      _SFR_IO_ADDR(GPIOR2)
	in    ZL,      _SFR_IO_ADDR(GPIOR1)
	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; (213)
	reti


sq_sline_259b:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)

	; Set up 910 cycles between Sync pulses

	ldi   ZH,      hi8(909)
	ldi   ZL,      lo8(909)
	sts   _SFR_MEM_ADDR(OCR1AH), ZH
	sts   _SFR_MEM_ADDR(OCR1AL), ZL ; (15)

	nop                    ; (16)
	push  r0               ; (18)
	rjmp  sq_sline_254com  ; (20)


sq_sline_261b:

	cbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; ( 9)

	; Jump table entry point wraps around

	ldi   ZL,      0
	sts   video_jtab_lo, ZL

	; Finish, controller clock remains high at the end

	push  r0
	push  r1
	in    r1,      _SFR_IO_ADDR(SREG)
	push  r1               ; (19)

	; Read controller bit

	rcall sq_sline_cread   ; (55)

	; Wait some

	lpm   ZL,      Z
	lpm   ZL,      Z
	lpm   ZL,      Z
	rjmp  .

	; Clean up

	pop   r1
	out   _SFR_IO_ADDR(SREG), r1
	pop   r1
	pop   r0
	in    ZH,      _SFR_IO_ADDR(GPIOR2)
	in    ZL,      _SFR_IO_ADDR(GPIOR1)

	; Sync pulse and end

	sbi   _SFR_IO_ADDR(SYNC_PORT), SYNC_PIN ; (77)
	reti



.section .sq_tiny_text0

;
; Read a controller data bit pair and flip clock for next.
; 36 cycles assuming an rcall.
;

sq_sline_cread:

	ldi   ZL,      0
	sbis  _SFR_IO_ADDR(JOYPAD_IN_PORT), JOYPAD_DATA1_PIN
	ori   ZL,      1
	sbis  _SFR_IO_ADDR(JOYPAD_IN_PORT), JOYPAD_DATA2_PIN
	ori   ZL,      2
	sbi   _SFR_IO_ADDR(JOYPAD_OUT_PORT), JOYPAD_CLOCK_PIN
	lds   r0,      joypad1_stat_t + 0
	lds   r1,      joypad1_stat_t + 1
	lsr   ZL
	ror   r1
	ror   r0
	sts   joypad1_stat_t + 0, r0
	sts   joypad1_stat_t + 1, r1
	lds   r0,      joypad2_stat_t + 0
	lds   r1,      joypad2_stat_t + 1
	lsr   ZL
	ror   r1
	ror   r0
	sts   joypad2_stat_t + 0, r0
	sts   joypad2_stat_t + 1, r1
	ret            ; (33)



; Include components

#include "sq_mixer.s"
#include "sq_audio.s"
#include "sq_patchproc.s"
